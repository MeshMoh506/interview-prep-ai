# app/routers/interviews.py
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

from app.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.interview import Interview, InterviewMessage
from app.models.resume import Resume
from app.services.interview_ai_service import InterviewAIService
from app.services.stt import transcribe_audio   # ← clean import from dedicated service

router = APIRouter(prefix="/api/v1/interviews", tags=["interviews"])
ai = InterviewAIService()


# ── Schemas ──────────────────────────────────────────────────────
class StartInterviewRequest(BaseModel):
    job_role:        str
    difficulty:      str           = "medium"
    interview_type:  str           = "mixed"
    language:        str           = "en"
    resume_id:       Optional[int] = None
    job_description: Optional[str] = None

class SendMessageRequest(BaseModel):
    content: str


# ── Helpers ──────────────────────────────────────────────────────
def _build_history(messages: List[InterviewMessage]) -> List[dict]:
    return [{"role": m.role, "content": m.content} for m in messages]

def _serialize(i: Interview, include_messages: bool = False) -> dict:
    data = {
        "id":              i.id,
        "job_role":        i.job_role,
        "difficulty":      i.difficulty,
        "interview_type":  i.interview_type,
        "language":        i.language,
        "status":          i.status,
        "score":           i.score,
        "feedback":        i.feedback,
        "message_count":   i.message_count,
        "user_msg_count":  i.user_msg_count,
        "voice_used":      i.voice_used,
        "tts_used":        i.tts_used,
        "duration_seconds": i.duration_seconds,
        "created_at":      i.created_at.isoformat()  if i.created_at   else None,
        "started_at":      i.started_at.isoformat()  if i.started_at   else None,
        "completed_at":    i.completed_at.isoformat() if i.completed_at else None,
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


# ── POST /  — start interview ────────────────────────────────────
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


# ── POST /{id}/message — text message ────────────────────────────
@router.post("/{interview_id}/message")
def send_message(
    interview_id: int,
    req:  SendMessageRequest,
    db:   Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)

    # Save user message
    user_msg = InterviewMessage(
        interview_id=interview_id, role="user", content=req.content)
    db.add(user_msg)
    interview.user_msg_count  = (interview.user_msg_count or 0) + 1
    interview.message_count   = (interview.message_count  or 0) + 1
    db.commit()

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id).all()
    )

    result = ai.process_message(
        history=history[:-1], user_message=req.content,
        job_role=interview.job_role, difficulty=interview.difficulty,
        interview_type=interview.interview_type, language=interview.language or "en",
        job_description=interview.job_description or "",
        user_msg_count=interview.user_msg_count,
    )

    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]
        db.commit()

    return _save_ai_reply(interview, result, db)


# ── POST /{id}/voice — voice message (STT via stt.py) ─────────────
@router.post("/{interview_id}/voice")
async def send_voice(
    interview_id: int,
    audio:    UploadFile = File(...),
    language: str        = Form(default="en"),
    db:       Session    = Depends(get_db),
    current_user: User   = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)

    audio_bytes = await audio.read()
    filename    = audio.filename or f"voice_{interview_id}.webm"

    # ── Transcribe via stt.py (Groq or OpenAI, configured in .env) ──
    try:
        transcript = transcribe_audio(
            audio_bytes,
            filename=filename,
            language=language if language in ("ar", "en") else None,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription error: {e}")

    if not transcript.strip():
        raise HTTPException(
            status_code=422,
            detail="No speech detected. Please try again.",
        )

    # Save user voice message
    user_msg = InterviewMessage(
        interview_id=interview_id,
        role="user",
        content=transcript.strip(),
        is_voice=True,
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
        interview_type=interview.interview_type, language=interview.language or language,
        job_description=interview.job_description or "",
        user_msg_count=interview.user_msg_count,
    )

    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]
        db.commit()

    reply = _save_ai_reply(interview, result, db)
    reply["transcript"] = transcript.strip()
    return reply


# ── POST /{id}/end — force end ────────────────────────────────────
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


# ── GET /  — list ─────────────────────────────────────────────────
@router.get("/")
def list_interviews(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (db.query(Interview)
              .filter(Interview.user_id == current_user.id)
              .order_by(Interview.created_at.desc())
              .all())
    return [_serialize(i) for i in rows]


# ── GET /{id} ─────────────────────────────────────────────────────
@router.get("/{interview_id}")
def get_interview(
    interview_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _serialize(_get_interview(interview_id, current_user.id, db),
                      include_messages=True)


# ── DELETE /{id} ──────────────────────────────────────────────────
@router.delete("/{interview_id}")
def delete_interview(
    interview_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = _get_interview(interview_id, current_user.id, db)
    db.delete(interview); db.commit()
    return {"success": True}


# ── Private helpers ───────────────────────────────────────────────
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
    """Save the AI reply message and optionally close the interview."""
    ai_text = result["message"]
    interview_status = "in_progress"
    feedback_data: dict | None = None
    score: float | None = None

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
        feedback_data = fb.get("feedback", {})
        score         = fb.get("score", 70)
        interview.status       = "completed"
        interview.score        = score
        interview.feedback     = feedback_data
        interview.completed_at = datetime.utcnow()
        interview_status       = "completed"

    ai_msg = InterviewMessage(
        interview_id=interview.id, role="assistant", content=ai_text)
    db.add(ai_msg)
    interview.message_count = (interview.message_count or 0) + 1
    db.commit(); db.refresh(ai_msg)

    return {
        "ai_message":       {"id": ai_msg.id, "role": "assistant", "content": ai_text},
        "evaluation":       result.get("evaluation"),
        "interview_status": interview_status,
        "feedback":         feedback_data,
        "score":            score,
    }

def _finish_interview(interview: Interview, history: list, db: Session) -> dict:
    fb    = ai.generate_final_feedback(history=history, job_role=interview.job_role,
                                       language=interview.language or "en")
    score = fb.get("score", 70)
    interview.status       = "completed"
    interview.score        = score
    interview.feedback     = fb.get("feedback", {})
    interview.completed_at = datetime.utcnow()
    db.commit()
    return {"success": True, "score": score, "feedback": fb.get("feedback", {})}