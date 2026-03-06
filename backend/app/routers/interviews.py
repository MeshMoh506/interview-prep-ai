# backend/app/routers/interviews.py - COMPLETE FIXED VERSION

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

from app.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.interview import Interview, InterviewMessage
from app.models.interview_question import InterviewQuestion
from app.models.resume import Resume
from app.services.interview_ai_service import InterviewAIService
from app.services.avatar_service import AvatarService
from app.services.stt import transcribe_audio

router = APIRouter(prefix="/api/v1/interviews", tags=["interviews"])
ai = InterviewAIService()

# ── SINGLE shared AvatarService instance so the presenter cache
#    is populated once and reused by ALL endpoints ──────────────────
_avatar_service = AvatarService()


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

class SendMessageRequest(BaseModel):
    content: str


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
        "language":         i.language,
        "status":           i.status,
        "score":            i.score,
        "feedback":         i.feedback,
        "message_count":    i.message_count,
        "user_msg_count":   i.user_msg_count,
        "voice_used":       i.voice_used,
        "tts_used":         i.tts_used,
        "duration_seconds": i.duration_seconds,
        "created_at":       i.created_at.isoformat()  if i.created_at   else None,
        "started_at":       i.started_at.isoformat()  if i.started_at   else None,
        "completed_at":     i.completed_at.isoformat() if i.completed_at else None,
    }
    if include_messages:
        data["messages"] = [
            {
                "id":                  m.id,
                "role":                m.role,
                "content":             m.content,
                "is_voice":            m.is_voice,
                "evaluation":          m.evaluation,
                "transcript_language": m.transcript_language,
                "timestamp":           m.timestamp.isoformat() if m.timestamp else None,
            }
            for m in i.messages
        ]
    return data

def _get_interview(interview_id: int, user_id: int, db: Session) -> Interview:
    i = db.query(Interview).filter(
        Interview.id == interview_id,
        Interview.user_id == user_id,
    ).first()
    if not i:
        raise HTTPException(status_code=404, detail="Interview not found")
    if i.status == "completed":
        raise HTTPException(status_code=400, detail="Interview already completed")
    return i

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
        fb = ai.generate_final_feedback(
            history=history, job_role=interview.job_role,
            language=interview.language or "en",
        )
        feedback_data          = fb.get("feedback", {})
        score                  = fb.get("score", 70)
        interview.status       = "completed"
        interview.score        = score
        interview.feedback     = feedback_data
        interview.completed_at = datetime.utcnow()
        interview_status       = "completed"

    ai_msg = InterviewMessage(
        interview_id=interview.id, role="assistant", content=ai_text)
    db.add(ai_msg)
    interview.message_count = (interview.message_count or 0) + 1
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
    fb    = ai.generate_final_feedback(
        history=history, job_role=interview.job_role,
        language=interview.language or "en")
    score = fb.get("score", 70)
    interview.status       = "completed"
    interview.score        = score
    interview.feedback     = fb.get("feedback", {})
    interview.completed_at = datetime.utcnow()
    db.commit()
    return {"success": True, "score": score, "feedback": fb.get("feedback", {})}


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
                parsed = json.loads(resume.parsed_content) if isinstance(resume.parsed_content, str) else resume.parsed_content
                if isinstance(parsed, dict):
                    if 'contact_info' in parsed and isinstance(parsed['contact_info'], dict):
                        job_title = parsed['contact_info'].get('job_title', '').strip()
                        if job_title:
                            roles.add(job_title)
                    if 'experience' in parsed and isinstance(parsed['experience'], list):
                        for exp in parsed['experience']:
                            if isinstance(exp, dict):
                                title = exp.get('title', '').strip()
                                if title and len(title) > 2:
                                    roles.add(title)
                    if 'education' in parsed and isinstance(parsed['education'], list):
                        for edu in parsed['education']:
                            if isinstance(edu, dict):
                                field = edu.get('field_of_study', '').strip()
                                if field:
                                    roles.add(f"{field} Graduate")
                                    roles.add(f"{field} Professional")
            except Exception as e:
                print(f"Error parsing resume {resume.id}: {e}")
                continue

    if not roles:
        roles = {"Custom Role (Type Your Own)"}
    clean_roles  = {r.strip() for r in roles if r and 3 < len(r.strip()) < 100}
    sorted_roles = sorted(list(clean_roles))[:20]
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
    if vote == "up":   question.upvotes   += 1
    elif vote == "down": question.downvotes += 1
    else: raise HTTPException(status_code=400, detail="Invalid vote")
    db.commit()
    return {"success": True, "upvotes": question.upvotes, "downvotes": question.downvotes}


# ═══════════════════════════════════════════════════════════════════
# AVATARS
# ═══════════════════════════════════════════════════════════════════

@router.get("/avatars")
async def get_avatars():
    """
    Returns avatar list with real D-ID thumbnail URLs.
    Also warms up the presenter cache so video generation works immediately.
    """
    return await _avatar_service.get_available_avatars()


# ═══════════════════════════════════════════════════════════════════
# INTERVIEW MANAGEMENT
# ═══════════════════════════════════════════════════════════════════

@router.post("/", status_code=status.HTTP_201_CREATED)
def start_interview(
    req: StartInterviewRequest,
    db:  Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    resume_text = ""
    if req.resume_id:
        resume = db.query(Resume).filter(
            Resume.id == req.resume_id,
            Resume.user_id == current_user.id,
        ).first()
        if resume and resume.parsed_content:
            resume_text = resume.parsed_content

    interview = Interview(
        user_id=current_user.id,
        job_role=req.job_role,
        difficulty=req.difficulty,
        interview_type=req.interview_type,
        language=req.language,
        status="in_progress",
        started_at=datetime.utcnow(),
        resume_id=req.resume_id,
        job_description=req.job_description,
        message_count=0,
        user_msg_count=0,
    )
    db.add(interview); db.commit(); db.refresh(interview)

    result = ai.start_interview(
        job_role=req.job_role, difficulty=req.difficulty,
        interview_type=req.interview_type, language=req.language,
        resume_text=resume_text, job_description=req.job_description or "",
    )
    if not result["success"]:
        raise HTTPException(status_code=500, detail="AI service error")

    msg = InterviewMessage(
        interview_id=interview.id, role="assistant", content=result["message"])
    db.add(msg)
    interview.message_count = 1
    db.commit()

    return {
        "interview_id": interview.id,
        "ai_message": {
            "id": msg.id, "interview_id": interview.id,
            "role": "assistant", "content": result["message"],
        },
    }


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
def get_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        interviews = db.query(Interview).filter(
            Interview.user_id == current_user.id
        ).order_by(Interview.created_at.desc()).all()
        return {
            "interviews": [
                {
                    "id": i.id, "job_role": i.job_role,
                    "difficulty": i.difficulty, "status": i.status,
                    "score": i.score,
                    "created_at": i.created_at.isoformat() if i.created_at else None,
                }
                for i in interviews
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


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
        Interview.id == interview_id,
        Interview.user_id == current_user.id,
    ).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")
    db.delete(interview); db.commit()


# ═══════════════════════════════════════════════════════════════════
# MESSAGES
# ═══════════════════════════════════════════════════════════════════

@router.post("/{interview_id}/message")
def send_message(
    interview_id: int,
    req: SendMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)
    user_msg  = InterviewMessage(interview_id=interview_id, role="user", content=req.content)
    db.add(user_msg)
    interview.user_msg_count = (interview.user_msg_count or 0) + 1
    interview.message_count  = (interview.message_count  or 0) + 1
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    result = ai.process_message(
        history=history[:-1], user_message=req.content,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type,
        language=interview.language or "en",
        job_description=interview.job_description or "",
        user_msg_count=interview.user_msg_count,
    )
    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]; db.commit()

    # Return shape Flutter expects: response as a Map with 'text'
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
    lang         = interview.language or "en"

    if not user_message:
        raise HTTPException(400, "Message content required")

    user_msg = InterviewMessage(interview_id=interview_id, role="user", content=user_message)
    db.add(user_msg)
    interview.user_msg_count = (interview.user_msg_count or 0) + 1
    interview.message_count  = (interview.message_count  or 0) + 1
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    result = ai.process_message(
        history=history[:-1], user_message=user_message,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=interview.job_description or "",
        user_msg_count=interview.user_msg_count,
    )
    response_text = result.get("message", "")

    ai_msg = InterviewMessage(interview_id=interview_id, role="assistant", content=response_text)
    db.add(ai_msg)
    interview.message_count = (interview.message_count or 0) + 1
    db.commit()

    response_data = {"message_id": ai_msg.id, "response": {"text": response_text}}

    if use_avatar and response_text:
        try:
            # Cache is already warm from /avatars call
            avatar_result = await _avatar_service.create_talking_avatar(
                text=response_text[:500],
                avatar_id=avatar_id,
                language=lang,
            )
            if avatar_result.get("success"):
                response_data["response"]["video_url"] = avatar_result.get("video_url")
                response_data["response"]["talk_id"]   = avatar_result.get("talk_id")
        except Exception as e:
            print(f"Avatar generation error: {e}")

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
        content=transcript.strip(), is_voice=True,
        transcript_language=language,
    )
    db.add(user_msg)
    interview.user_msg_count = (interview.user_msg_count or 0) + 1
    interview.message_count  = (interview.message_count  or 0) + 1
    interview.voice_used     = True
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )
    result = ai.process_message(
        history=history[:-1], user_message=transcript.strip(),
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type,
        language=interview.language or language,
        job_description=interview.job_description or "",
        user_msg_count=interview.user_msg_count,
    )
    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]; db.commit()

    reply = _save_ai_reply(interview, result, db)

    # Return shape Flutter expects: response as a Map with 'text'
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
    source_url: str        = Form(default=""),   # accepted but unused
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)
    lang      = interview.language or language

    # ── Step 1: STT ─────────────────────────────────────────────────
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
        raise HTTPException(422, "No speech detected. Please speak clearly and try again.")

    # ── Step 2: Save user message ───────────────────────────────────
    user_msg = InterviewMessage(
        interview_id=interview_id, role="user",
        content=transcript.strip(), is_voice=True,
        transcript_language=language,
    )
    db.add(user_msg)
    interview.user_msg_count = (interview.user_msg_count or 0) + 1
    interview.message_count  = (interview.message_count  or 0) + 1
    interview.voice_used     = True
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )

    # ── Step 3: AI response ─────────────────────────────────────────
    result = ai.process_message(
        history=history[:-1], user_message=transcript.strip(),
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=lang,
        job_description=interview.job_description or "",
        user_msg_count=interview.user_msg_count,
    )
    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]; db.commit()

    reply   = _save_ai_reply(interview, result, db)
    ai_text = reply["ai_message"]["content"]

    # ── Step 4: D-ID video (uses shared singleton — cache already warm) ──
    video_url: str | None = None
    talk_id:   str | None = None
    try:
        avatar_result = await _avatar_service.create_talking_avatar(
            text=ai_text[:500],
            avatar_id=avatar_id,
            language=lang,
        )
        if avatar_result.get("success"):
            video_url = avatar_result.get("video_url")
            talk_id   = avatar_result.get("talk_id")
        else:
            import logging
            logging.getLogger(__name__).warning(
                f"D-ID video failed: {avatar_result.get('error')}")
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"Avatar generation skipped: {e}")

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
# DEBUG / TEST
# ═══════════════════════════════════════════════════════════════════

@router.get("/test-avatar")
async def test_avatar_connection(current_user: User = Depends(get_current_user)):
    return await _avatar_service.test_connection()


@router.post("/test-avatar-generate")
async def test_avatar_generate(current_user: User = Depends(get_current_user)):
    return await _avatar_service.create_talking_avatar(
        text="Hello! I am your AI interviewer. Let's begin.",
        avatar_id="professional_female",
        language="en",
    )