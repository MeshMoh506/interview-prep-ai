# backend/app/routers/interviews.py
# KEY CHANGES vs original:
#   1. StartInterviewRequest now accepts goal_id (optional)
#   2. start_interview() builds goal_context from previous goal interviews
#      and injects it into the AI system prompt
#   3. All message endpoints pass goal_context to ai.process_message()
#   4. On interview completion, increment_goal_week_count() is called
#   5. _serialize() now includes goal_id field

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

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/interviews", tags=["interviews"])
ai = InterviewAIService()

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
    goal_id:         Optional[int] = None   # ← NEW: links interview to a goal

class SendMessageRequest(BaseModel):
    content: str


# ═══════════════════════════════════════════════════════════════════
# GOAL CONTEXT BUILDER
# ═══════════════════════════════════════════════════════════════════

def _build_goal_context(goal_id: int, user_id: int, db: Session, language: str = "en") -> str:
    """
    Build a rich goal-context string injected into the AI system prompt.
    Fetches: goal details, all previous completed interviews under this goal,
    last session's feedback (weaknesses), score trend, week progress.
    """
    try:
        from app.models.goal import Goal

        goal = db.query(Goal).filter(
            Goal.id      == goal_id,
            Goal.user_id == user_id,
        ).first()
        if not goal:
            return ""

        # All completed interviews for this goal, ordered oldest→newest
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

        session_number = len(prev_interviews) + 1  # this is session N
        scores = [i.score for i in prev_interviews if i.score is not None]
        avg_score = round(sum(scores) / len(scores), 1) if scores else None
        best_score = round(max(scores), 1) if scores else None

        # Extract weak areas from last session's feedback
        last_weaknesses: list[str] = []
        last_strengths:  list[str] = []
        last_score = None
        if prev_interviews:
            last = prev_interviews[-1]
            last_score = last.score
            if last.feedback and isinstance(last.feedback, dict):
                raw_imp = last.feedback.get("areas_for_improvement") or \
                          last.feedback.get("improvements") or []
                raw_str = last.feedback.get("strengths") or []
                last_weaknesses = [str(x) for x in raw_imp[:3]]
                last_strengths  = [str(x) for x in raw_str[:2]]

        # Score trend: improving / declining / stable
        trend = "no previous data"
        if len(scores) >= 2:
            diff = scores[-1] - scores[-2]
            if diff > 3:   trend = f"improving (last two sessions: {scores[-2]:.0f}% → {scores[-1]:.0f}%)"
            elif diff < -3: trend = f"declined (last two sessions: {scores[-2]:.0f}% → {scores[-1]:.0f}%)"
            else:           trend = f"stable (~{scores[-1]:.0f}%)"

        # Week progress
        week_done   = goal.current_week_count or 0
        week_target = goal.weekly_interview_target or 3
        weeks_left  = goal.weeks_remaining  # computed property on model

        if language == "ar":
            lines = [
                f"═══ سياق هدف المرشح ═══",
                f"الدور المستهدف: {goal.target_role}",
            ]
            if goal.target_company:
                lines.append(f"الشركة المستهدفة: {goal.target_company}")
            lines += [
                f"هذه الجلسة رقم: {session_number} في رحلة التحضير",
                f"المقابلات هذا الأسبوع: {week_done}/{week_target}",
            ]
            if weeks_left is not None:
                lines.append(f"أسابيع متبقية حتى الهدف: {weeks_left}")
            if avg_score:
                lines.append(f"متوسط النتائج السابقة: {avg_score}%")
            if last_score:
                lines.append(f"نتيجة الجلسة الأخيرة: {last_score:.0f}%")
            if len(scores) >= 2:
                lines.append(f"اتجاه الأداء: {trend}")
            if last_weaknesses:
                lines.append(f"نقاط الضعف من الجلسة الأخيرة (ركّز عليها):")
                for w in last_weaknesses:
                    lines.append(f"  • {w}")
            if last_strengths:
                lines.append(f"نقاط القوة المُثبتة:")
                for s in last_strengths:
                    lines.append(f"  • {s}")
            lines += [
                "═══ تعليمات للمحاور ═══",
                "- ركّز على نقاط الضعف المذكورة أعلاه في أسئلتك.",
                "- استشهد بتقدم المرشح عبر الجلسات إذا كان ذا صلة.",
                "- اضبط مستوى الصعوبة بناءً على أداء الجلسات السابقة.",
                "- ساعد المرشح على التحسن نحو هدفه المحدد.",
            ]
        else:
            lines = [
                f"═══ CANDIDATE GOAL CONTEXT ═══",
                f"Target Role: {goal.target_role}",
            ]
            if goal.target_company:
                lines.append(f"Target Company: {goal.target_company}")
            lines += [
                f"This is session #{session_number} in their preparation journey.",
                f"Interviews this week: {week_done}/{week_target}",
            ]
            if weeks_left is not None:
                lines.append(f"Weeks remaining until goal deadline: {weeks_left}")
            if avg_score:
                lines.append(f"Average score across past sessions: {avg_score}%")
            if last_score:
                lines.append(f"Last session score: {last_score:.0f}%")
            if len(scores) >= 2:
                lines.append(f"Performance trend: {trend}")
            if last_weaknesses:
                lines.append(f"Weak areas from last session (FOCUS ON THESE):")
                for w in last_weaknesses:
                    lines.append(f"  • {w}")
            if last_strengths:
                lines.append(f"Confirmed strengths:")
                for s in last_strengths:
                    lines.append(f"  • {s}")
            lines += [
                "═══ INTERVIEWER INSTRUCTIONS ═══",
                "- Probe the weak areas listed above with targeted follow-up questions.",
                "- Reference the candidate's progress across sessions when relevant.",
                "- Calibrate difficulty based on their trend — push harder if improving.",
                "- Your goal is to prepare them specifically for a real interview at their target company.",
                "- At the end, give concrete actionable advice for their next session.",
            ]

        return "\n".join(lines)

    except Exception as e:
        logger.warning(f"_build_goal_context failed for goal {goal_id}: {e}")
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
        "goal_id":          getattr(i, "goal_id", None),   # ← NEW
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
        Interview.id      == interview_id,
        Interview.user_id == user_id,
    ).first()
    if not i:
        raise HTTPException(status_code=404, detail="Interview not found")
    if i.status == "completed":
        raise HTTPException(status_code=400, detail="Interview already completed")
    return i


def _on_interview_complete(interview: Interview, db: Session):
    """Called whenever an interview transitions to 'completed'. Updates goal counter."""
    goal_id = getattr(interview, "goal_id", None)
    if goal_id:
        try:
            from app.routers.goals import increment_goal_week_count
            increment_goal_week_count(goal_id, db)
            logger.info(f"Incremented week count for goal {goal_id}")
        except Exception as e:
            logger.warning(f"Could not increment goal week count: {e}")


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
        lang = getattr(interview, "language", "en") or "en"
        goal_id  = getattr(interview, "goal_id", None)
        goal_ctx = _build_goal_context(goal_id, interview.user_id, db, lang) if goal_id else ""
        fb = ai.generate_final_feedback(
            history=history, job_role=interview.job_role, language=lang,
            goal_context=goal_ctx,
        )
        feedback_data          = fb.get("feedback", {})
        score                  = fb.get("score", 70)
        interview.status       = "completed"
        interview.score        = score
        interview.feedback     = feedback_data
        interview.completed_at = datetime.utcnow()
        interview_status       = "completed"
        _on_interview_complete(interview, db)   # ← goal counter

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
    lang         = getattr(interview, "language", "en") or "en"
    goal_id      = getattr(interview, "goal_id", None)
    goal_ctx     = _build_goal_context(goal_id, interview.user_id, db, lang) if goal_id else ""
    fb   = ai.generate_final_feedback(
        history=history, job_role=interview.job_role, language=lang,
        goal_context=goal_ctx)
    score = fb.get("score", 70)
    interview.status       = "completed"
    interview.score        = score
    interview.feedback     = fb.get("feedback", {})
    interview.completed_at = datetime.utcnow()
    db.commit()
    _on_interview_complete(interview, db)   # ← goal counter
    return {"success": True, "score": score, "feedback": fb.get("feedback", {})}


# ═══════════════════════════════════════════════════════════════════
# QUESTIONS & ROLES  (unchanged)
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
                    if 'experience' in parsed:
                        for exp in parsed['experience']:
                            if isinstance(exp, dict):
                                t = exp.get('title', '').strip()
                                if t and len(t) > 2: roles.add(t)
                    if 'education' in parsed:
                        for edu in parsed['education']:
                            if isinstance(edu, dict):
                                f = edu.get('field_of_study', '').strip()
                                if f:
                                    roles.add(f"{f} Graduate")
                                    roles.add(f"{f} Professional")
            except Exception as e:
                logger.error(f"Error parsing resume {resume.id}: {e}")
    if not roles:
        roles = {"Custom Role (Type Your Own)"}
    clean  = {r.strip() for r in roles if r and 3 < len(r.strip()) < 100}
    sorted_roles = sorted(list(clean))[:20]
    return {"roles": sorted_roles if sorted_roles else ["Your Target Role"]}


@router.get("/questions")
def get_questions(
    job_role:   Optional[str] = None,
    category:   Optional[str] = None,
    difficulty: Optional[str] = None,
    limit:      int = 10,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    question = db.query(InterviewQuestion).filter(InterviewQuestion.id == question_id).first()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")
    if vote == "up":      question.upvotes   += 1
    elif vote == "down":  question.downvotes += 1
    else: raise HTTPException(status_code=400, detail="Invalid vote")
    db.commit()
    return {"success": True, "upvotes": question.upvotes, "downvotes": question.downvotes}


@router.get("/avatars")
async def get_avatars():
    return await _avatar_service.get_available_avatars()


# ═══════════════════════════════════════════════════════════════════
# START INTERVIEW — now goal-aware
# ═══════════════════════════════════════════════════════════════════

@router.post("/", status_code=status.HTTP_201_CREATED)
def start_interview(
    req: StartInterviewRequest,
    db:  Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        # ── 1. Resume text ───────────────────────────────────────────
        resume_text = ""
        if req.resume_id:
            resume = db.query(Resume).filter(
                Resume.id      == req.resume_id,
                Resume.user_id == current_user.id,
            ).first()
            if resume and resume.parsed_content:
                resume_text = str(resume.parsed_content)

        # ── 2. Goal context (empty string for general interviews) ────
        goal_context = ""
        if req.goal_id:
            goal_context = _build_goal_context(
                goal_id=req.goal_id,
                user_id=current_user.id,
                db=db,
                language=req.language,
            )
            logger.info(f"Goal context built for goal {req.goal_id}, "
                        f"length={len(goal_context)}")

        # ── 3. Interview row ─────────────────────────────────────────
        from sqlalchemy import inspect as sa_inspect
        col_names = {c.key for c in sa_inspect(Interview).mapper.column_attrs}

        interview_kwargs: dict = {
            "user_id":       current_user.id,
            "job_role":      req.job_role,
            "difficulty":    req.difficulty,
            "interview_type": req.interview_type,
            "status":        "in_progress",
            "started_at":    datetime.utcnow(),
        }
        if "language"        in col_names: interview_kwargs["language"]        = req.language
        if "resume_id"       in col_names: interview_kwargs["resume_id"]       = req.resume_id
        if "job_description" in col_names: interview_kwargs["job_description"] = req.job_description
        if "message_count"   in col_names: interview_kwargs["message_count"]   = 0
        if "user_msg_count"  in col_names: interview_kwargs["user_msg_count"]  = 0
        if "goal_id"         in col_names: interview_kwargs["goal_id"]         = req.goal_id  # ← NEW

        interview = Interview(**interview_kwargs)
        db.add(interview)
        db.commit()
        db.refresh(interview)

        # ── 4. First AI question — with goal context ─────────────────
        lang = getattr(interview, "language", None) or req.language or "en"
        result = ai.start_interview(
            job_role=req.job_role,
            difficulty=req.difficulty,
            interview_type=req.interview_type,
            language=lang,
            resume_text=resume_text,
            job_description=req.job_description or "",
            goal_context=goal_context,          # ← NEW
        )

        if not result.get("success"):
            raise HTTPException(status_code=500, detail="AI service error")

        msg = InterviewMessage(
            interview_id=interview.id, role="assistant", content=result["message"])
        db.add(msg)
        if "message_count" in col_names:
            interview.message_count = 1
        db.commit()
        db.refresh(msg)

        return {
            "interview_id": interview.id,
            "session_id":   interview.id,       # alias Flutter uses
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
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (db.query(Interview)
              .filter(Interview.user_id == current_user.id)
              .order_by(Interview.created_at.desc()).all())
    return [_serialize(i) for i in rows]


@router.get("/history")
def get_interview_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = 20,
    offset: int = 0,
):
    """Returns the user's interview history sorted by most recent."""
    interviews = (
        db.query(Interview)
        .filter(Interview.user_id == current_user.id)
        .order_by(Interview.started_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
 
    return {
        "interviews": [
            {
                "id":           i.id,
                "job_role":     i.job_role,
                "difficulty":   i.difficulty,
                "interview_type": i.interview_type,
                "status":       i.status,
                "score":        i.score,
                "grade":        (i.feedback or {}).get("grade", ""),
                "recommendation": (i.feedback or {}).get("recommendation", ""),
                "language":     i.language,
                "duration_minutes": i.duration_minutes,
                "message_count": len(i.messages) if i.messages else 0,
                "started_at":   i.started_at.isoformat() if i.started_at else None,
                "completed_at": i.completed_at.isoformat() if i.completed_at else None,
            }
            for i in interviews
        ],
        "total": db.query(Interview).filter(Interview.user_id == current_user.id).count(),
    }


@router.get("/{interview_id}")
def get_interview(
    interview_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _serialize(_get_interview(interview_id, current_user.id, db), include_messages=True)


@router.delete("/{interview_id}", status_code=204)
def delete_interview(
    interview_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    interview = db.query(Interview).filter(
        Interview.id      == interview_id,
        Interview.user_id == current_user.id,
    ).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")
    db.delete(interview); db.commit()


# ═══════════════════════════════════════════════════════════════════
# MESSAGES — all pass goal_context to process_message
# ═══════════════════════════════════════════════════════════════════

def _get_goal_context_for_interview(interview: Interview, db: Session) -> str:
    """Load goal context for an in-progress interview if it has a goal_id."""
    goal_id = getattr(interview, "goal_id", None)
    if not goal_id:
        return ""
    lang = getattr(interview, "language", "en") or "en"
    return _build_goal_context(goal_id, interview.user_id, db, lang)


@router.post("/{interview_id}/message")
def send_message(
    interview_id: int,
    req: SendMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)
    user_msg  = InterviewMessage(
        interview_id=interview_id, role="user", content=req.content)
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    goal_context = _get_goal_context_for_interview(interview, db)

    result = ai.process_message(
        history=history[:-1], user_message=req.content,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type,
        language=getattr(interview, "language", "en") or "en",
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=goal_context,          # ← NEW
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
    interview_id: int,
    message: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview    = _get_interview(interview_id, current_user.id, db)
    user_message = message.get("content", "").strip()
    use_avatar   = message.get("use_avatar", False)
    avatar_id    = message.get("avatar_id", "professional_female")
    lang         = getattr(interview, "language", "en") or "en"

    if not user_message:
        raise HTTPException(400, "Message content required")

    user_msg = InterviewMessage(
        interview_id=interview_id, role="user", content=user_message)
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    goal_context = _get_goal_context_for_interview(interview, db)

    result = ai.process_message(
        history=history[:-1], user_message=user_message,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=goal_context,          # ← NEW
    )
    response_text = result.get("message", "")

    ai_msg = InterviewMessage(
        interview_id=interview_id, role="assistant", content=response_text)
    db.add(ai_msg)
    interview.message_count = (getattr(interview, "message_count", 0) or 0) + 1
    db.commit()

    # Check completion
    if result.get("should_end"):
        _finish_interview(interview, _build_history(
            db.query(InterviewMessage)
              .filter(InterviewMessage.interview_id == interview_id)
              .order_by(InterviewMessage.id).all()
        ), db)

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
    audio:    UploadFile = File(...),
    language: str        = Form(default="en"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview   = _get_interview(interview_id, current_user.id, db)
    audio_bytes = await audio.read()
    filename    = audio.filename or f"voice_{interview_id}.webm"

    try:
        transcript = transcribe_audio(
            audio_bytes, filename=filename,
            language=language if language in ("ar", "en") else None,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription error: {e}")

    if not transcript.strip():
        raise HTTPException(422, "No speech detected. Please try again.")

    user_msg = InterviewMessage(
        interview_id=interview_id, role="user",
        content=transcript.strip(),
        **{k: v for k, v in
           {"is_voice": True, "transcript_language": language}.items()
           if hasattr(InterviewMessage, k)},
    )
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    if hasattr(interview, "voice_used"):
        interview.voice_used = True
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    lang = getattr(interview, "language", None) or language
    goal_context = _get_goal_context_for_interview(interview, db)

    result = ai.process_message(
        history=history[:-1], user_message=transcript.strip(),
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=goal_context,          # ← NEW
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
    audio:      UploadFile = File(...),
    language:   str        = Form(default="en"),
    avatar_id:  str        = Form(default="professional_female"),
    source_url: str        = Form(default=""),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)
    lang      = getattr(interview, "language", None) or language

    audio_bytes = await audio.read()
    filename    = audio.filename or f"voice_{interview_id}.webm"
    try:
        transcript = transcribe_audio(
            audio_bytes, filename=filename,
            language=language if language in ("ar", "en") else None,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription error: {e}")

    if not transcript.strip():
        raise HTTPException(422, "No speech detected. Please speak clearly.")

    user_msg = InterviewMessage(
        interview_id=interview_id, role="user",
        content=transcript.strip(),
        **{k: v for k, v in
           {"is_voice": True, "transcript_language": language}.items()
           if hasattr(InterviewMessage, k)},
    )
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    if hasattr(interview, "voice_used"):
        interview.voice_used = True
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    goal_context = _get_goal_context_for_interview(interview, db)

    result = ai.process_message(
        history=history[:-1], user_message=transcript.strip(),
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=goal_context,          # ← NEW
    )
    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]; db.commit()

    reply   = _save_ai_reply(interview, result, db)
    ai_text = reply["ai_message"]["content"]

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
        "transcription":    transcript.strip(),
        "success":          True,
        "response": {
            "text":      ai_text,
            "video_url": video_url,
            "talk_id":   talk_id,
        },
        "interview_status": reply["interview_status"],
        "score":            reply["score"],
        "feedback":         reply["feedback"],
        "evaluation":       reply["evaluation"],
    }


@router.post("/{interview_id}/voice-avatar-async")
async def voice_avatar_async(
    interview_id:     int,
    background_tasks: BackgroundTasks,
    audio:            UploadFile = File(...),
    avatar_id:        str        = Form("professional_female"),
    source_url:       str        = Form(""),
    language:         str        = Form("en"),
    current_user:     User       = Depends(get_current_user),
    db:               Session    = Depends(get_db),
):
    interview = db.query(Interview).filter(
        Interview.id      == interview_id,
        Interview.user_id == current_user.id,
    ).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")

    audio_bytes   = await audio.read()
    transcription = ""
    try:
        transcription = transcribe_audio(
            audio_bytes,
            filename=audio.filename or "audio.webm",
            language=language if language in ("ar", "en") else None,
        ).strip()
    except Exception as e:
        logger.error(f"STT error: {e}")

    if not transcription:
        return {
            "success":       False,
            "error":         "Could not transcribe audio",
            "transcription": "",
            "response":      {"text": "", "clip_id": None, "video_url": None},
        }

    user_msg = InterviewMessage(
        interview_id=interview_id, role="user", content=transcription,
        **{k: v for k, v in
           {"is_voice": True, "transcript_language": language}.items()
           if hasattr(InterviewMessage, k)},
    )
    db.add(user_msg)
    interview.user_msg_count = (getattr(interview, "user_msg_count", 0) or 0) + 1
    interview.message_count  = (getattr(interview, "message_count",  0) or 0) + 1
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    lang = getattr(interview, "language", None) or language
    goal_context = _get_goal_context_for_interview(interview, db)

    result = ai.process_message(
        history=history[:-1], user_message=transcription,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=getattr(interview, "job_description", "") or "",
        user_msg_count=getattr(interview, "user_msg_count", 1),
        goal_context=goal_context,          # ← NEW
    )
    reply            = _save_ai_reply(interview, result, db)
    response_text    = reply["ai_message"]["content"]
    interview_status = reply["interview_status"]
    score            = reply["score"]
    feedback         = reply["feedback"]

    clip_tracking_id = f"pending_{uuid.uuid4().hex[:12]}"
    _clip_store[clip_tracking_id] = {"status": "pending", "video_url": None}

    async def _generate_video_bg():
        try:
            res = await _avatar_service.create_talking_avatar(
                text=response_text, avatar_id=avatar_id,
                language=lang, source_url=source_url or None,
            )
            if res.get("success") and res.get("video_url"):
                _clip_store[clip_tracking_id] = {
                    "status": "done", "video_url": res["video_url"],
                    "talk_id": res.get("talk_id"),
                }
            else:
                _clip_store[clip_tracking_id] = {
                    "status": "error", "video_url": None,
                    "error": res.get("error", "D-ID failed"),
                }
        except Exception as e:
            logger.error(f"Background D-ID error: {e}")
            _clip_store[clip_tracking_id] = {"status": "error", "video_url": None}

    background_tasks.add_task(_generate_video_bg)

    return {
        "success":          True,
        "transcription":    transcription,
        "response": {
            "text":      response_text,
            "clip_id":   clip_tracking_id,
            "video_url": None,
        },
        "interview_status": interview_status,
        "score":            score,
        "feedback":         feedback,
    }


@router.get("/clip-status/{clip_id}")
async def get_clip_status(
    clip_id:      str,
    current_user: User = Depends(get_current_user),
):
    entry = _clip_store.get(clip_id)
    if not entry:
        return {"status": "not_found", "video_url": None}
    if entry["status"] in ("done", "error"):
        _clip_store.pop(clip_id, None)
    return {
        "status":    entry["status"],
        "video_url": entry.get("video_url"),
        "talk_id":   entry.get("talk_id"),
    }


# ═══════════════════════════════════════════════════════════════════
# END INTERVIEW
# ═══════════════════════════════════════════════════════════════════

@router.post("/{interview_id}/end")
def end_interview(
    interview_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)
    history   = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    return _finish_interview(interview, history, db)


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
        avatar_id="professional_female", language="en",
    )