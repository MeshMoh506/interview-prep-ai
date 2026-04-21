# app/routers/interviews.py
# PATCHES vs original:
#   1. Import ai_memory_service
#   2. _on_interview_complete → calls memory service after goal counter (background task)
#   3. start_interview / process_message → injects user's ai_profile as extra context
#   4. get_profile_context() prepended to goal_context in all AI calls

import logging
import uuid
import asyncio
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.interview import Interview, InterviewMessage
from app.models.interview_question import InterviewQuestion
from app.models.resume import Resume
from app.models.user import User
from app.routers.auth import get_current_user
from app.services.avatar_service import AvatarService
from app.services.interview_ai_service import InterviewAIService
from app.services.stt import transcribe_audio
from app.services.anam_service import AnamService

# ── AI Memory Service ────────────────────────────────────────────
from app.services.ai_memory_service import (
    update_after_interview,
    get_profile_context,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/interviews", tags=["interviews"])
ai = InterviewAIService()
_anam_service = AnamService()

_avatar_service = AvatarService()
_clip_store: dict = {}


# ═══════════════════════════════════════════════════════════════════
# SCHEMAS
# ═══════════════════════════════════════════════════════════════════

class StartInterviewRequest(BaseModel):
    job_role:        str
    difficulty:      str           = "medium"
    interview_type:  str           = "mixed"
    language:        str           = "en"
    resume_id:       Optional[int] = None
    job_description: Optional[str] = None
    goal_id:         Optional[int] = None


class SendMessageRequest(BaseModel):
    content: str

class StartAnamRequest(BaseModel):
    job_role:        str
    difficulty:      str           = "medium"
    interview_type:  str           = "mixed"
    language:        str           = "en"
    avatar_id:       str           = "english_male"
    resume_id:       Optional[int] = None
    goal_id:         Optional[int] = None

class AnamChatRequest(BaseModel):
    interview_id:   int
    messages:       list[dict]     # Anam conversation history
    user_msg_count: int = 1
 

# ═══════════════════════════════════════════════════════════════════
# GOAL CONTEXT BUILDER
# ═══════════════════════════════════════════════════════════════════

def _build_goal_context(goal_id: int, user_id: int, db: Session, language: str = "en") -> str:
    try:
        from app.models.goal import Goal
        goal = db.query(Goal).filter(
            Goal.id == goal_id, Goal.user_id == user_id).first()
        if not goal:
            return ""

        prev_interviews = (
            db.query(Interview)
            .filter(
                Interview.user_id == user_id,
                Interview.goal_id == goal_id,
                Interview.status  == "completed",
            )
            .order_by(Interview.created_at.asc())
            .all()
        )

        session_number = len(prev_interviews) + 1
        scores         = [i.score for i in prev_interviews if i.score is not None]
        avg_score      = round(sum(scores) / len(scores), 1) if scores else None
        best_score     = round(max(scores), 1) if scores else None

        last_weaknesses: list[str] = []
        last_strengths:  list[str] = []
        last_score = None
        if prev_interviews:
            last       = prev_interviews[-1]
            last_score = last.score
            if last.feedback and isinstance(last.feedback, dict):
                raw_imp = last.feedback.get("areas_for_improvement") or \
                          last.feedback.get("improvements") or []
                raw_str = last.feedback.get("strengths") or []
                last_weaknesses = [str(x) for x in raw_imp[:3]]
                last_strengths  = [str(x) for x in raw_str[:2]]

        trend = "no previous data"
        if len(scores) >= 2:
            diff = scores[-1] - scores[-2]
            if diff > 3:   trend = f"improving ({scores[-2]:.0f}% → {scores[-1]:.0f}%)"
            elif diff < -3: trend = f"declined ({scores[-2]:.0f}% → {scores[-1]:.0f}%)"
            else:           trend = f"stable (~{scores[-1]:.0f}%)"

        week_done   = goal.current_week_count or 0
        week_target = goal.weekly_interview_target or 3
        weeks_left  = goal.weeks_remaining

        if language == "ar":
            lines = [
                f"═══ سياق هدف المرشح ═══",
                f"الدور المستهدف: {goal.target_role}",
            ]
            if goal.target_company:
                lines.append(f"الشركة المستهدفة: {goal.target_company}")
            lines += [f"هذه الجلسة رقم: {session_number}", f"المقابلات هذا الأسبوع: {week_done}/{week_target}"]
            if weeks_left: lines.append(f"أسابيع متبقية: {weeks_left}")
            if avg_score:  lines.append(f"متوسط النتائج: {avg_score}%")
            if last_score: lines.append(f"نتيجة الجلسة الأخيرة: {last_score:.0f}%")
            if len(scores) >= 2: lines.append(f"اتجاه الأداء: {trend}")
            if last_weaknesses:
                lines.append("نقاط الضعف من الجلسة الأخيرة:")
                for w in last_weaknesses: lines.append(f"  • {w}")
            if last_strengths:
                lines.append("نقاط القوة المُثبتة:")
                for s in last_strengths: lines.append(f"  • {s}")
            lines += ["═══ تعليمات ═══",
                      "- ركّز على نقاط الضعف في أسئلتك.",
                      "- اضبط مستوى الصعوبة بناءً على الأداء السابق."]
        else:
            lines = [
                f"═══ CANDIDATE GOAL CONTEXT ═══",
                f"Target Role: {goal.target_role}",
            ]
            if goal.target_company:
                lines.append(f"Target Company: {goal.target_company}")
            lines += [f"Session #{session_number}", f"Interviews this week: {week_done}/{week_target}"]
            if weeks_left: lines.append(f"Weeks remaining: {weeks_left}")
            if avg_score:  lines.append(f"Average score: {avg_score}%")
            if last_score: lines.append(f"Last session: {last_score:.0f}%")
            if len(scores) >= 2: lines.append(f"Trend: {trend}")
            if last_weaknesses:
                lines.append("Weak areas to probe:")
                for w in last_weaknesses: lines.append(f"  • {w}")
            if last_strengths:
                lines.append("Confirmed strengths:")
                for s in last_strengths: lines.append(f"  • {s}")
            lines += ["═══ INSTRUCTIONS ═══",
                      "- Probe weak areas with follow-ups.",
                      "- Calibrate difficulty based on trend."]

        return "\n".join(lines)

    except Exception as e:
        logger.warning(f"_build_goal_context failed: {e}")
        return ""


# ═══════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════

def _build_history(messages: List[InterviewMessage]) -> List[dict]:
    return [{"role": m.role, "content": m.content} for m in messages]


def _serialize(i: Interview, include_messages: bool = False) -> dict:
    data = {
        "id":               i.id,
        "job_role":         i.job_role,
        "difficulty":       i.difficulty,
        "interview_type":   i.interview_type,
        "language":         getattr(i, "language", "en"),
        "status":           i.status,
        "score":            i.score,
        "feedback":         i.feedback,
        "message_count":    getattr(i, "message_count", 0),
        "user_msg_count":   getattr(i, "user_msg_count", 0),
        "voice_used":       getattr(i, "voice_used", False),
        "tts_used":         getattr(i, "tts_used", False),
        "duration_seconds": getattr(i, "duration_seconds", None),
        "goal_id":          getattr(i, "goal_id", None),
        "created_at":       i.created_at.isoformat()   if i.created_at   else None,
        "started_at":       i.started_at.isoformat()   if i.started_at   else None,
        "completed_at":     i.completed_at.isoformat() if i.completed_at else None,
    }
    if include_messages:
        data["messages"] = [
            {
                "id":                  m.id,
                "role":                m.role,
                "content":             m.content,
                "is_voice":            getattr(m, "is_voice", False),
                "evaluation":          getattr(m, "evaluation", None),
                "transcript_language": getattr(m, "transcript_language", None),
                "timestamp":           m.timestamp.isoformat() if m.timestamp else None,
            }
            for m in i.messages
        ]
    return data


def _get_interview(interview_id: int, user_id: int, db: Session) -> Interview:
    i = db.query(Interview).filter(
        Interview.id == interview_id, Interview.user_id == user_id).first()
    if not i:
        raise HTTPException(status_code=404, detail="Interview not found")
    if i.status == "completed":
        raise HTTPException(status_code=400, detail="Interview already completed")
    return i


def _on_interview_complete(interview: Interview, db: Session):
    """
    Called whenever an interview transitions to 'completed'.
    1. Updates goal weekly counter
    2. Updates user's AI memory profile (background — never blocks response)
    """
    # ── Goal counter ─────────────────────────────────────────────
    goal_id = getattr(interview, "goal_id", None)
    if goal_id:
        try:
            from app.routers.goals import increment_goal_week_count
            increment_goal_week_count(goal_id, db)
            logger.info(f"Incremented week count for goal {goal_id}")
        except Exception as e:
            logger.warning(f"Could not increment goal week count: {e}")

    # ── AI Memory update ─────────────────────────────────────────
    # Fetch user from DB to get current ai_profile and write back
    try:
        user = db.query(User).filter(User.id == interview.user_id).first()
        if user:
            import asyncio
            try:
                loop = asyncio.get_event_loop()
                if loop.is_running():
                    # Already in async context — schedule as coroutine
                    loop.call_soon_threadsafe(
                        lambda: update_after_interview(user, interview, db))
                else:
                    update_after_interview(user, interview, db)
            except RuntimeError:
                update_after_interview(user, interview, db)
    except Exception as e:
        logger.warning(f"AI memory update skipped: {e}")


def _full_context(user, goal_id: Optional[int], user_id: int,
                  language: str, db: Session) -> str:
    """
    Combines: user's AI memory profile + goal context (if any).
    This is injected as extra context into every AI call.
    """
    parts = []

    # 1. AI memory profile (what the AI knows about this user)
    profile_ctx = get_profile_context(user, language)
    if profile_ctx:
        parts.append(profile_ctx)

    # 2. Goal context (current goal progress, weaknesses to probe)
    if goal_id:
        goal_ctx = _build_goal_context(goal_id, user_id, db, language)
        if goal_ctx:
            parts.append(goal_ctx)

    return "\n".join(parts)


def _save_ai_reply(interview: Interview, result: dict, db: Session) -> dict:
    ai_text          = result["message"]
    interview_status = "in_progress"
    feedback_data    = None
    score            = None

    if result.get("should_end"):
        history = _build_history(
            db.query(InterviewMessage)
              .filter(InterviewMessage.interview_id == interview.id)
              .order_by(InterviewMessage.id).all()
        )
        lang     = getattr(interview, "language", "en") or "en"
        goal_id  = getattr(interview, "goal_id", None)
        user     = db.query(User).filter(User.id == interview.user_id).first()
        extra_ctx = _full_context(user, goal_id, interview.user_id, lang, db) if user else ""

        fb = ai.generate_final_feedback(
            history=history, job_role=interview.job_role, language=lang,
            goal_context=extra_ctx,
        )
        feedback_data          = fb.get("feedback", {})
        score                  = fb.get("score", 70)
        interview.status       = "completed"
        interview.score        = score
        interview.feedback     = feedback_data
        interview.completed_at = datetime.utcnow()
        interview_status       = "completed"
        _on_interview_complete(interview, db)

    ai_msg = InterviewMessage(
        interview_id=interview.id, role="assistant", content=ai_text)
    db.add(ai_msg)
    interview.message_count = (getattr(interview, "message_count", 0) or 0) + 1
    db.commit()
    db.refresh(ai_msg)

    return {
        "ai_message":       {"id": ai_msg.id, "role": "assistant", "content": ai_text},
        "evaluation":       result.get("evaluation"),
        "interview_status": interview_status,
        "feedback":         feedback_data,
        "score":            score,
    }


def _finish_interview(interview: Interview, history: list, db: Session) -> dict:
    lang     = getattr(interview, "language", "en") or "en"
    goal_id  = getattr(interview, "goal_id", None)
    user     = db.query(User).filter(User.id == interview.user_id).first()
    extra_ctx = _full_context(user, goal_id, interview.user_id, lang, db) if user else ""

    fb    = ai.generate_final_feedback(
        history=history, job_role=interview.job_role, language=lang,
        goal_context=extra_ctx)
    score = fb.get("score", 70)
    interview.status       = "completed"
    interview.score        = score
    interview.feedback     = fb.get("feedback", {})
    interview.completed_at = datetime.utcnow()
    db.commit()
    _on_interview_complete(interview, db)
    return {"success": True, "score": score, "feedback": fb.get("feedback", {})}


def _get_goal_context_for_interview(interview: Interview, user, db: Session) -> str:
    """Full context (profile + goal) for in-progress messages."""
    lang    = getattr(interview, "language", "en") or "en"
    goal_id = getattr(interview, "goal_id", None)
    return _full_context(user, goal_id, interview.user_id, lang, db)


# ═══════════════════════════════════════════════════════════════════
# QUESTIONS & ROLES
# ═══════════════════════════════════════════════════════════════════

@router.get("/questions/roles")
def get_available_roles(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    roles = set()
    resumes = db.query(Resume).filter(Resume.user_id == current_user.id).all()
    for resume in resumes:
        if resume.parsed_content:
            try:
                import json
                parsed = (json.loads(resume.parsed_content)
                          if isinstance(resume.parsed_content, str)
                          else resume.parsed_content)
                if isinstance(parsed, dict):
                    if 'contact_info' in parsed and isinstance(parsed['contact_info'], dict):
                        jt = parsed['contact_info'].get('job_title', '').strip()
                        if jt: roles.add(jt)
                    for exp in parsed.get('experience', []):
                        if isinstance(exp, dict):
                            t = exp.get('title', '').strip()
                            if t and len(t) > 2: roles.add(t)
                    for edu in parsed.get('education', []):
                        if isinstance(edu, dict):
                            f = edu.get('field_of_study', '').strip()
                            if f:
                                roles.add(f"{f} Graduate")
                                roles.add(f"{f} Professional")
            except Exception as e:
                logger.error(f"Error parsing resume {resume.id}: {e}")
    if not roles:
        roles = {"Custom Role (Type Your Own)"}
    clean = {r.strip() for r in roles if r and 3 < len(r.strip()) < 100}
    sorted_roles = sorted(list(clean))[:20]
    return {"roles": sorted_roles if sorted_roles else ["Your Target Role"]}


@router.get("/questions")
def get_questions(
    job_role: Optional[str] = None, category: Optional[str] = None,
    difficulty: Optional[str] = None, limit: int = 10,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    query = db.query(InterviewQuestion)
    if job_role:   query = query.filter(InterviewQuestion.job_role   == job_role)
    if category:   query = query.filter(InterviewQuestion.category   == category)
    if difficulty: query = query.filter(InterviewQuestion.difficulty == difficulty)
    questions = query.order_by(InterviewQuestion.upvotes.desc()).limit(limit).all()
    return {"questions": [q.to_dict() for q in questions]}


@router.post("/questions")
def add_community_question(
    question: str, category: str, difficulty: str, job_role: str,
    tips: Optional[str] = None, tags: Optional[List[str]] = None,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    new_q = InterviewQuestion(
        question=question, category=category, difficulty=difficulty,
        job_role=job_role, tips=tips, tags=tags or [],
        is_community=True, submitted_by=current_user.id,
    )
    db.add(new_q); db.commit(); db.refresh(new_q)
    return {"success": True, "question": new_q.to_dict()}


@router.post("/questions/{question_id}/vote")
def vote_question(
    question_id: int, vote: str,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    question = db.query(InterviewQuestion).filter(
        InterviewQuestion.id == question_id).first()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")
    if vote == "up":     question.upvotes   += 1
    elif vote == "down": question.downvotes += 1
    else: raise HTTPException(status_code=400, detail="Invalid vote")
    db.commit()
    return {"success": True, "upvotes": question.upvotes, "downvotes": question.downvotes}


@router.get("/avatars")
async def get_avatars():
    return await _avatar_service.get_available_avatars()


# ═══════════════════════════════════════════════════════════════════
# START INTERVIEW — goal-aware + AI memory aware
# ═══════════════════════════════════════════════════════════════════

@router.post("/", status_code=status.HTTP_201_CREATED)
def start_interview(
    req: StartInterviewRequest,
    db:  Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        # ── Resume text ──────────────────────────────────────────
        resume_text = ""
        if req.resume_id:
            resume = db.query(Resume).filter(
                Resume.id == req.resume_id, Resume.user_id == current_user.id).first()
            if resume and resume.parsed_content:
                resume_text = str(resume.parsed_content)

        # ── Full context: AI memory profile + goal ───────────────
        lang     = req.language or "en"
        extra_ctx = _full_context(
            current_user, req.goal_id, current_user.id, lang, db)

        # ── Interview row ────────────────────────────────────────
        from sqlalchemy import inspect as sa_inspect
        col_names = {c.key for c in sa_inspect(Interview).mapper.column_attrs}

        interview_kwargs: dict = {
            "user_id":        current_user.id,
            "job_role":       req.job_role,
            "difficulty":     req.difficulty,
            "interview_type": req.interview_type,
            "status":         "in_progress",
            "started_at":     datetime.utcnow(),
        }
        if "language"        in col_names: interview_kwargs["language"]        = lang
        if "resume_id"       in col_names: interview_kwargs["resume_id"]       = req.resume_id
        if "job_description" in col_names: interview_kwargs["job_description"] = req.job_description
        if "message_count"   in col_names: interview_kwargs["message_count"]   = 0
        if "user_msg_count"  in col_names: interview_kwargs["user_msg_count"]  = 0
        if "goal_id"         in col_names: interview_kwargs["goal_id"]         = req.goal_id

        interview = Interview(**interview_kwargs)
        db.add(interview); db.commit(); db.refresh(interview)

        # ── First AI question — with full context ────────────────
        result = ai.start_interview(
            job_role=req.job_role, difficulty=req.difficulty,
            interview_type=req.interview_type, language=lang,
            resume_text=resume_text,
            job_description=req.job_description or "",
            goal_context=extra_ctx,   # ← AI memory + goal context
        )

        if not result.get("success"):
            raise HTTPException(status_code=500, detail="AI service error")

        msg = InterviewMessage(
            interview_id=interview.id, role="assistant", content=result["message"])
        db.add(msg)
        if "message_count" in col_names:
            interview.message_count = 1
        db.commit(); db.refresh(msg)

        return {
            "interview_id":   interview.id,
            "session_id":     interview.id,
            "first_question": result["message"],
            "ai_message": {
                "id":           msg.id,
                "interview_id": interview.id,
                "role":         "assistant",
                "content":      result["message"],
            },
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"start_interview crashed: {e}")
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")


@router.get("/")
def list_interviews(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    rows = (db.query(Interview)
              .filter(Interview.user_id == current_user.id)
              .order_by(Interview.created_at.desc()).all())
    return [_serialize(i) for i in rows]


@router.get("/history")
def get_interview_history(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
    limit: int = 20, offset: int = 0,
):
    interviews = (
        db.query(Interview)
        .filter(Interview.user_id == current_user.id)
        .order_by(Interview.started_at.desc())
        .offset(offset).limit(limit).all()
    )
    return {
        "interviews": [
            {
                "id":             i.id, "job_role": i.job_role,
                "difficulty":     i.difficulty, "interview_type": i.interview_type,
                "status":         i.status, "score": i.score,
                "grade":          (i.feedback or {}).get("grade", ""),
                "recommendation": (i.feedback or {}).get("recommendation", ""),
                "language":       i.language,
                "duration_minutes": i.duration_minutes,
                "message_count":  len(i.messages) if i.messages else 0,
                "started_at":     i.started_at.isoformat() if i.started_at else None,
                "completed_at":   i.completed_at.isoformat() if i.completed_at else None,
            }
            for i in interviews
        ],
        "total": db.query(Interview).filter(Interview.user_id == current_user.id).count(),
    }


@router.get("/{interview_id}")
def get_interview(
    interview_id: int, db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _serialize(_get_interview(interview_id, current_user.id, db), include_messages=True)


@router.delete("/{interview_id}", status_code=204)
def delete_interview(
    interview_id: int, current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    interview = db.query(Interview).filter(
        Interview.id == interview_id, Interview.user_id == current_user.id).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")
    db.delete(interview); db.commit()


# ═══════════════════════════════════════════════════════════════════
# MESSAGES — all pass full context (memory + goal)
# ═══════════════════════════════════════════════════════════════════

@router.post("/{interview_id}/message")
def send_message(
    interview_id: int, req: SendMessageRequest,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)
    user_msg  = InterviewMessage(interview_id=interview_id, role="user", content=req.content)
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    db.commit()

    history      = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all())
    extra_ctx    = _get_goal_context_for_interview(interview, current_user, db)

    result = ai.process_message(
        history=history[:-1], user_message=req.content,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type,
        language=getattr(interview, "language", "en") or "en",
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=extra_ctx,
    )
    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]; db.commit()

    reply = _save_ai_reply(interview, result, db)
    return {
        "response":         {"text": reply["ai_message"]["content"]},
        "interview_status": reply["interview_status"],
        "score":            reply["score"],
        "feedback":         reply["feedback"],
        "evaluation":       reply["evaluation"],
    }


@router.post("/{interview_id}/avatar-message")
async def send_avatar_message(
    interview_id: int, message: dict,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    interview    = _get_interview(interview_id, current_user.id, db)
    user_message = message.get("content", "").strip()
    use_avatar   = message.get("use_avatar", False)
    avatar_id    = message.get("avatar_id", "professional_female")
    lang         = getattr(interview, "language", "en") or "en"

    if not user_message:
        raise HTTPException(400, "Message content required")

    user_msg = InterviewMessage(interview_id=interview_id, role="user", content=user_message)
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    db.commit()

    history   = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all())
    extra_ctx = _get_goal_context_for_interview(interview, current_user, db)

    result = ai.process_message(
        history=history[:-1], user_message=user_message,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=extra_ctx,
    )
    response_text = result.get("message", "")
    ai_msg = InterviewMessage(interview_id=interview_id, role="assistant", content=response_text)
    db.add(ai_msg)
    interview.message_count = (getattr(interview, "message_count", 0) or 0) + 1
    db.commit()

    if result.get("should_end"):
        _finish_interview(interview, _build_history(
            db.query(InterviewMessage)
              .filter(InterviewMessage.interview_id == interview_id)
              .order_by(InterviewMessage.id).all()), db)

    response_data = {"message_id": ai_msg.id, "response": {"text": response_text}}
    if use_avatar and response_text:
        try:
            avatar_result = await _avatar_service.create_talking_avatar(
                text=response_text[:500], avatar_id=avatar_id, language=lang)
            if avatar_result.get("success"):
                response_data["response"]["video_url"] = avatar_result.get("video_url")
                response_data["response"]["talk_id"]   = avatar_result.get("talk_id")
        except Exception as e:
            logger.warning(f"Avatar generation error: {e}")
    return response_data


@router.post("/{interview_id}/voice")
async def send_voice(
    interview_id: int,
    audio: UploadFile = File(...), language: str = Form(default="en"),
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    interview   = _get_interview(interview_id, current_user.id, db)
    audio_bytes = await audio.read()
    filename    = audio.filename or f"voice_{interview_id}.webm"

    try:
        transcript = transcribe_audio(
            audio_bytes, filename=filename,
            language=language if language in ("ar", "en") else None)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription error: {e}")

    if not transcript.strip():
        raise HTTPException(422, "No speech detected. Please try again.")

    user_msg = InterviewMessage(
        interview_id=interview_id, role="user", content=transcript.strip(),
        **{k: v for k, v in
           {"is_voice": True, "transcript_language": language}.items()
           if hasattr(InterviewMessage, k)})
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    if hasattr(interview, "voice_used"): interview.voice_used = True
    db.commit()

    history   = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all())
    lang      = getattr(interview, "language", None) or language
    extra_ctx = _get_goal_context_for_interview(interview, current_user, db)

    result = ai.process_message(
        history=history[:-1], user_message=transcript.strip(),
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=extra_ctx,
    )
    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]; db.commit()

    reply = _save_ai_reply(interview, result, db)
    return {
        "transcription":    transcript.strip(),
        "response":         {"text": reply["ai_message"]["content"]},
        "interview_status": reply["interview_status"],
        "score":            reply["score"],
        "feedback":         reply["feedback"],
        "evaluation":       reply["evaluation"],
    }


@router.post("/{interview_id}/voice-avatar")
async def send_voice_with_avatar(
    interview_id: int,
    audio: UploadFile = File(...), language: str = Form(default="en"),
    avatar_id: str = Form(default="professional_female"),
    source_url: str = Form(default=""),
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    interview   = _get_interview(interview_id, current_user.id, db)
    lang        = getattr(interview, "language", None) or language
    audio_bytes = await audio.read()
    filename    = audio.filename or f"voice_{interview_id}.webm"

    try:
        transcript = transcribe_audio(
            audio_bytes, filename=filename,
            language=language if language in ("ar", "en") else None)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription error: {e}")

    if not transcript.strip():
        raise HTTPException(422, "No speech detected. Please speak clearly.")

    user_msg = InterviewMessage(
        interview_id=interview_id, role="user", content=transcript.strip(),
        **{k: v for k, v in
           {"is_voice": True, "transcript_language": language}.items()
           if hasattr(InterviewMessage, k)})
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    if hasattr(interview, "voice_used"): interview.voice_used = True
    db.commit()

    history   = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all())
    extra_ctx = _get_goal_context_for_interview(interview, current_user, db)

    result = ai.process_message(
        history=history[:-1], user_message=transcript.strip(),
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=extra_ctx,
    )
    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]; db.commit()

    reply     = _save_ai_reply(interview, result, db)
    ai_text   = reply["ai_message"]["content"]
    video_url: str | None = None
    talk_id:   str | None = None
    try:
        avatar_result = await _avatar_service.create_talking_avatar(
            text=ai_text[:500], avatar_id=avatar_id, language=lang)
        if avatar_result.get("success"):
            video_url = avatar_result.get("video_url")
            talk_id   = avatar_result.get("talk_id")
    except Exception as e:
        logger.warning(f"Avatar generation skipped: {e}")

    return {
        "transcription":    transcript.strip(), "success": True,
        "response":         {"text": ai_text, "video_url": video_url, "talk_id": talk_id},
        "interview_status": reply["interview_status"],
        "score":            reply["score"], "feedback": reply["feedback"],
        "evaluation":       reply["evaluation"],
    }


@router.post("/{interview_id}/voice-avatar-async")
async def voice_avatar_async(
    interview_id: int, background_tasks: BackgroundTasks,
    audio: UploadFile = File(...), avatar_id: str = Form("professional_female"),
    source_url: str = Form(""), language: str = Form("en"),
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db),
):
    interview = db.query(Interview).filter(
        Interview.id == interview_id, Interview.user_id == current_user.id).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")

    audio_bytes   = await audio.read()
    transcription = ""
    try:
        transcription = transcribe_audio(
            audio_bytes, filename=audio.filename or "audio.webm",
            language=language if language in ("ar", "en") else None).strip()
    except Exception as e:
        logger.error(f"STT error: {e}")

    if not transcription:
        return {"success": False, "error": "Could not transcribe audio",
                "transcription": "", "response": {"text": "", "clip_id": None, "video_url": None}}

    user_msg = InterviewMessage(
        interview_id=interview_id, role="user", content=transcription,
        **{k: v for k, v in
           {"is_voice": True, "transcript_language": language}.items()
           if hasattr(InterviewMessage, k)})
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    db.commit()

    history   = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all())
    lang      = getattr(interview, "language", None) or language
    extra_ctx = _get_goal_context_for_interview(interview, current_user, db)

    result = ai.process_message(
        history=history[:-1], user_message=transcription,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=extra_ctx,
    )
    reply            = _save_ai_reply(interview, result, db)
    response_text    = reply["ai_message"]["content"]
    clip_tracking_id = f"pending_{uuid.uuid4().hex[:12]}"
    _clip_store[clip_tracking_id] = {"status": "pending", "video_url": None}

    async def _generate_video_bg():
        try:
            res = await _avatar_service.create_talking_avatar(
                text=response_text, avatar_id=avatar_id,
                language=lang, source_url=source_url or None)
            if res.get("success") and res.get("video_url"):
                _clip_store[clip_tracking_id] = {
                    "status": "done", "video_url": res["video_url"],
                    "talk_id": res.get("talk_id")}
            else:
                _clip_store[clip_tracking_id] = {
                    "status": "error", "video_url": None,
                    "error": res.get("error", "D-ID failed")}
        except Exception as e:
            logger.error(f"Background D-ID error: {e}")
            _clip_store[clip_tracking_id] = {"status": "error", "video_url": None}

    background_tasks.add_task(_generate_video_bg)
    return {
        "success": True, "transcription": transcription,
        "response": {"text": response_text, "clip_id": clip_tracking_id, "video_url": None},
        "interview_status": reply["interview_status"],
        "score": reply["score"], "feedback": reply["feedback"],
    }


@router.get("/clip-status/{clip_id}")
async def get_clip_status(clip_id: str, current_user: User = Depends(get_current_user)):
    entry = _clip_store.get(clip_id)
    if not entry:
        return {"status": "not_found", "video_url": None}
    if entry["status"] in ("done", "error"):
        _clip_store.pop(clip_id, None)
    return {"status": entry["status"], "video_url": entry.get("video_url"),
            "talk_id": entry.get("talk_id")}


# ═══════════════════════════════════════════════════════════════════
# END INTERVIEW
# ═══════════════════════════════════════════════════════════════════

@router.post("/{interview_id}/end")
def end_interview(
    interview_id: int, db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)
    history   = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all())
    return _finish_interview(interview, history, db)


from app.services.anam_service import AnamService
_anam_service = AnamService()
 
from pydantic import BaseModel as _BaseModel
 
class StartAnamRequest(_BaseModel):
    job_role:        str
    difficulty:      str           = "medium"
    interview_type:  str           = "mixed"
    language:        str           = "en"
    avatar_id:       str           = "english_male"
    resume_id:       Optional[int] = None
    goal_id:         Optional[int] = None
 
class AnamChatRequest(_BaseModel):
    interview_id:   int
    messages:       list[dict]
    user_msg_count: int = 1
 
 
@router.get("/anam/avatars")
async def get_anam_avatars(current_user: User = Depends(get_current_user)):
    """Return list of available Anam avatars for the avatar picker UI."""
    return {"avatars": _anam_service.get_available_avatars()}
 
 
@router.post("/anam/session", status_code=201)
async def start_anam_interview(
    req: StartAnamRequest,
    db:  Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Start a real-time Anam video interview.
 
    Flow:
    1. Creates a standard Interview DB row (same as text interview)
    2. Builds the system prompt with AI memory + goal context
    3. Creates an Anam session token with our interview config
    4. Returns: { interview_id, session_token, avatar_name }
 
    Flutter uses the session_token to initialize the Anam JS SDK in a WebView.
    The avatar then conducts the interview live — STT, face, lip sync all handled by Anam.
    Our Groq Llama brain is called via /anam/chat for each user message.
    """
    try:
        # ── Resume text ──────────────────────────────────────────
        resume_text = ""
        if req.resume_id:
            resume = db.query(Resume).filter(
                Resume.id == req.resume_id,
                Resume.user_id == current_user.id,
            ).first()
            if resume and resume.parsed_content:
                resume_text = str(resume.parsed_content)[:1000]
 
        # ── AI memory + goal context ─────────────────────────────
        lang      = req.language or "en"
        extra_ctx = _full_context(current_user, req.goal_id, current_user.id, lang, db)
 
        # ── Create DB interview row ──────────────────────────────
        from sqlalchemy import inspect as sa_inspect
        col_names = {c.key for c in sa_inspect(Interview).mapper.column_attrs}
 
        interview_kwargs: dict = {
            "user_id":        current_user.id,
            "job_role":       req.job_role,
            "difficulty":     req.difficulty,
            "interview_type": req.interview_type,
            "status":         "in_progress",
            "started_at":     datetime.utcnow(),
        }
        if "language"       in col_names: interview_kwargs["language"]       = lang
        if "resume_id"      in col_names: interview_kwargs["resume_id"]      = req.resume_id
        if "message_count"  in col_names: interview_kwargs["message_count"]  = 0
        if "user_msg_count" in col_names: interview_kwargs["user_msg_count"] = 0
        if "goal_id"        in col_names: interview_kwargs["goal_id"]        = req.goal_id
 
        interview = Interview(**interview_kwargs)
        db.add(interview)
        db.commit()
        db.refresh(interview)
 
        # ── Create Anam session token ────────────────────────────
        token_result = await _anam_service.create_session_token(
            avatar_id=req.avatar_id,
            job_role=req.job_role,
            difficulty=req.difficulty,
            interview_type=req.interview_type,
            language=lang,
            goal_context=extra_ctx,
            resume_text=resume_text,
        )
 
        if not token_result.get("success"):
            # Clean up DB row if Anam fails
            db.delete(interview)
            db.commit()
            raise HTTPException(
                status_code=503,
                detail=f"Anam service error: {token_result.get('error', 'Unknown')}"
            )
 
        logger.info(f"Anam session created for interview {interview.id}, "
                    f"avatar={req.avatar_id}, lang={lang}")
 
        return {
            "interview_id":    interview.id,
            "session_id":      interview.id,
            "session_token":   token_result["session_token"],
            "avatar_name":     token_result["avatar_name"],
            "avatar_language": token_result["avatar_language"],
            "avatar_id":       req.avatar_id,
        }
 
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"start_anam_interview crashed: {e}")
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
 
 
@router.post("/anam/chat")
async def anam_chat(
    req: AnamChatRequest,
    db:  Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Called by the Anam WebView JS when MESSAGE_HISTORY_UPDATED fires.
    Receives Anam conversation history → runs Groq Llama → returns reply text.
    The JS SDK then calls anamClient.talk(reply) to make the avatar speak.
 
    Also saves messages to DB and handles interview completion.
    """
    interview = db.query(Interview).filter(
        Interview.id == req.interview_id,
        Interview.user_id == current_user.id,
    ).first()
 
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")
    if interview.status == "completed":
        raise HTTPException(status_code=400, detail="Interview already completed")
 
    # ── Save user message to DB ──────────────────────────────────
    if req.messages:
        last_msg = req.messages[-1]
        if last_msg.get("role") in ("user", "human"):
            user_text = last_msg.get("content", "")
            if user_text:
                user_db_msg = InterviewMessage(
                    interview_id=interview.id,
                    role="user",
                    content=user_text,
                )
                db.add(user_db_msg)
                interview.user_msg_count = req.user_msg_count
                interview.message_count  = (getattr(interview, "message_count", 0) or 0) + 1
                db.commit()
 
    # ── Get AI reply ─────────────────────────────────────────────
    lang      = getattr(interview, "language", "en") or "en"
    extra_ctx = _get_goal_context_for_interview(interview, current_user, db)
 
    result = await _anam_service.process_anam_message(
        messages=req.messages,
        job_role=interview.job_role,
        difficulty=interview.difficulty,
        interview_type=interview.interview_type,
        language=lang,
        user_msg_count=req.user_msg_count,
        goal_context=extra_ctx,
    )
 
    reply_text = result.get("reply", "")
    should_end = result.get("should_end", False)
 
    # ── Save AI reply to DB ──────────────────────────────────────
    if reply_text:
        ai_db_msg = InterviewMessage(
            interview_id=interview.id,
            role="assistant",
            content=reply_text,
        )
        db.add(ai_db_msg)
        interview.message_count = (getattr(interview, "message_count", 0) or 0) + 1
        db.commit()
 
    # ── Handle interview completion ──────────────────────────────
    if should_end:
        history = _build_history(
            db.query(InterviewMessage)
              .filter(InterviewMessage.interview_id == interview.id)
              .order_by(InterviewMessage.id).all()
        )
        finish = _finish_interview(interview, history, db)
        return {
            "reply":            reply_text,
            "should_end":       True,
            "interview_status": "completed",
            "score":            finish.get("score"),
            "feedback":         finish.get("feedback"),
        }
 
    return {
        "reply":            reply_text,
        "should_end":       False,
        "interview_status": "in_progress",
        "score":            None,
        "feedback":         None,
    }




# ═══════════════════════════════════════════════════════════════════
# DEBUG
# ═══════════════════════════════════════════════════════════════════

@router.get("/test-avatar")
async def test_avatar_connection(current_user: User = Depends(get_current_user)):
    return await _avatar_service.test_connection()


@router.post("/test-avatar-generate")
async def test_avatar_generate(current_user: User = Depends(get_current_user)):
    return await _avatar_service.create_talking_avatar(
        text="Hello! I am your AI interviewer. Let's begin.",
        avatar_id="professional_female", language="en")