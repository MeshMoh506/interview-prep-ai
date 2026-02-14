# app/routers/interviews.py
# Full interview router — uses InterviewAIService (Groq Whisper + llama-3.3-70b)
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
import json

from app.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.interview import Interview, InterviewMessage
from app.models.resume import Resume
from app.services.interview_ai_service import InterviewAIService

router = APIRouter(prefix="/api/v1/interviews", tags=["interviews"])
ai = InterviewAIService()


# ── Schemas ───────────────────────────────────────────────────────
class StartInterviewRequest(BaseModel):
    job_role:       str
    difficulty:     str = "medium"   # easy | medium | hard
    interview_type: str = "mixed"    # behavioral | technical | mixed
    language:       str = "en"       # en | ar
    resume_id:      Optional[int] = None
    job_description: Optional[str] = None

class SendMessageRequest(BaseModel):
    content: str


# ── Helper: build history list from DB messages ───────────────────
def _build_history(messages: List[InterviewMessage]) -> List[dict]:
    return [{"role": m.role, "content": m.content} for m in messages]


# ── POST /  → start interview ─────────────────────────────────────
@router.post("/", status_code=status.HTTP_201_CREATED)
def start_interview(
    req: StartInterviewRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Optionally load resume text
    resume_text = ""
    if req.resume_id:
        resume = db.query(Resume).filter(
            Resume.id == req.resume_id,
            Resume.user_id == current_user.id,
        ).first()
        if resume and resume.parsed_content:
            resume_text = resume.parsed_content

    # Create interview row
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
    )
    db.add(interview)
    db.commit()
    db.refresh(interview)

    # Get opening message from AI
    result = ai.start_interview(
        job_role=req.job_role,
        difficulty=req.difficulty,
        interview_type=req.interview_type,
        language=req.language,
        resume_text=resume_text,
        job_description=req.job_description or "",
    )
    if not result["success"]:
        raise HTTPException(status_code=500, detail="AI service error")

    ai_text = result["message"]

    # Save first AI message
    msg = InterviewMessage(
        interview_id=interview.id,
        role="assistant",
        content=ai_text,
    )
    db.add(msg)
    db.commit()

    return {
        "interview_id": interview.id,
        "ai_message": {
            "id": msg.id,
            "interview_id": interview.id,
            "role": "assistant",
            "content": ai_text,
        },
    }


# ── POST /{id}/message → send text message ────────────────────────
@router.post("/{interview_id}/message")
def send_message(
    interview_id: int,
    req: SendMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = db.query(Interview).filter(
        Interview.id == interview_id,
        Interview.user_id == current_user.id,
    ).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")
    if interview.status == "completed":
        raise HTTPException(status_code=400, detail="Interview already completed")

    # Save user message
    user_msg = InterviewMessage(
        interview_id=interview_id,
        role="user",
        content=req.content,
    )
    db.add(user_msg)
    db.commit()

    # Build history (all messages before this one)
    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id)
          .all()
    )

    # Count user messages for auto-end detection
    user_count = sum(1 for m in history if m["role"] == "user")

    result = ai.process_message(
        history=history[:-1],   # exclude the one we just added
        user_message=req.content,
        job_role=interview.job_role,
        difficulty=interview.difficulty,
        interview_type=interview.interview_type,
        language=interview.language or "en",
        job_description=interview.job_description or "",
        message_count=len(history),
    )

    # Save evaluation on user message
    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]
        db.commit()

    ai_text = result["message"]

    # Check if interview should end
    interview_status = "in_progress"
    feedback_data = None
    score = None

    if result.get("should_end"):
        feedback_result = ai.generate_final_feedback(
            history=history,
            job_role=interview.job_role,
            language=interview.language or "en",
        )
        feedback_data = feedback_result.get("feedback", {})
        score = feedback_result.get("score", 70)
        interview.status = "completed"
        interview.score = score
        interview.feedback = feedback_data
        interview.completed_at = datetime.utcnow()
        interview_status = "completed"

    # Save AI message
    ai_msg = InterviewMessage(
        interview_id=interview_id,
        role="assistant",
        content=ai_text,
    )
    db.add(ai_msg)
    db.commit()
    db.refresh(ai_msg)

    return {
        "ai_message": {
            "id": ai_msg.id,
            "role": "assistant",
            "content": ai_text,
        },
        "evaluation": result.get("evaluation"),
        "interview_status": interview_status,
        "feedback": feedback_data,
        "score": score,
    }


# ── POST /{id}/voice → voice message (Groq Whisper) ───────────────
@router.post("/{interview_id}/voice")
async def send_voice(
    interview_id: int,
    audio: UploadFile = File(...),
    language: str = Form(default="en"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = db.query(Interview).filter(
        Interview.id == interview_id,
        Interview.user_id == current_user.id,
    ).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")

    audio_bytes = await audio.read()
    filename = audio.filename or f"audio_{interview_id}.webm"

    # Transcribe with Groq Whisper-large-v3
    tr = ai.transcribe_audio(
        audio_bytes=audio_bytes,
        filename=filename,
        language=language,
    )
    if not tr["success"] or not tr["transcript"].strip():
        raise HTTPException(
            status_code=422,
            detail=tr.get("error", "Could not transcribe audio. Please try again."),
        )

    transcript = tr["transcript"].strip()

    # Save user voice message
    user_msg = InterviewMessage(
        interview_id=interview_id,
        role="user",
        content=transcript,
    )
    db.add(user_msg)
    db.commit()

    # Build history
    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id)
          .all()
    )

    result = ai.process_message(
        history=history[:-1],
        user_message=transcript,
        job_role=interview.job_role,
        difficulty=interview.difficulty,
        interview_type=interview.interview_type,
        language=interview.language or language,
        job_description=interview.job_description or "",
        message_count=len(history),
    )

    if result.get("evaluation"):
        user_msg.evaluation = result["evaluation"]
        db.commit()

    ai_text = result["message"]
    interview_status = "in_progress"
    feedback_data = None
    score = None

    if result.get("should_end"):
        feedback_result = ai.generate_final_feedback(
            history=history,
            job_role=interview.job_role,
            language=interview.language or language,
        )
        feedback_data = feedback_result.get("feedback", {})
        score = feedback_result.get("score", 70)
        interview.status = "completed"
        interview.score = score
        interview.feedback = feedback_data
        interview.completed_at = datetime.utcnow()
        interview_status = "completed"

    ai_msg = InterviewMessage(
        interview_id=interview_id,
        role="assistant",
        content=ai_text,
    )
    db.add(ai_msg)
    db.commit()
    db.refresh(ai_msg)

    return {
        "transcript": transcript,
        "ai_message": {"id": ai_msg.id, "role": "assistant", "content": ai_text},
        "evaluation": result.get("evaluation"),
        "interview_status": interview_status,
        "feedback": feedback_data,
        "score": score,
    }


# ── POST /{id}/end → force end ────────────────────────────────────
@router.post("/{interview_id}/end")
def end_interview(
    interview_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = db.query(Interview).filter(
        Interview.id == interview_id,
        Interview.user_id == current_user.id,
    ).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Interview not found")

    history = _build_history(
        db.query(InterviewMessage)
          .filter(InterviewMessage.interview_id == interview_id)
          .order_by(InterviewMessage.id)
          .all()
    )

    feedback_result = ai.generate_final_feedback(
        history=history,
        job_role=interview.job_role,
        language=interview.language or "en",
    )
    feedback_data = feedback_result.get("feedback", {})
    score = feedback_result.get("score", 70)

    interview.status = "completed"
    interview.score = score
    interview.feedback = feedback_data
    interview.completed_at = datetime.utcnow()
    db.commit()

    return {"success": True, "score": score, "feedback": feedback_data}


# ── GET / → list user's interviews ───────────────────────────────
@router.get("/")
def list_interviews(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interviews = (
        db.query(Interview)
          .filter(Interview.user_id == current_user.id)
          .order_by(Interview.created_at.desc())
          .all()
    )
    return [_serialize(i) for i in interviews]


# ── GET /{id} → single interview ─────────────────────────────────
@router.get("/{interview_id}")
def get_interview(
    interview_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = db.query(Interview).filter(
        Interview.id == interview_id,
        Interview.user_id == current_user.id,
    ).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Not found")
    return _serialize(interview, include_messages=True)


# ── DELETE /{id} ──────────────────────────────────────────────────
@router.delete("/{interview_id}")
def delete_interview(
    interview_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    interview = db.query(Interview).filter(
        Interview.id == interview_id,
        Interview.user_id == current_user.id,
    ).first()
    if not interview:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(interview)
    db.commit()
    return {"success": True}


# ── Serializer ────────────────────────────────────────────────────
def _serialize(i: Interview, include_messages: bool = False) -> dict:
    data = {
        "id":             i.id,
        "job_role":       i.job_role,
        "difficulty":     i.difficulty,
        "interview_type": i.interview_type,
        "language":       i.language,
        "status":         i.status,
        "score":          i.score,
        "feedback":       i.feedback,
        "created_at":     i.created_at.isoformat() if i.created_at else None,
        "started_at":     i.started_at.isoformat() if i.started_at else None,
        "completed_at":   i.completed_at.isoformat() if i.completed_at else None,
    }
    if include_messages:
        data["messages"] = [
            {
                "id":         m.id,
                "role":       m.role,
                "content":    m.content,
                "evaluation": m.evaluation,
                "timestamp":  m.timestamp.isoformat() if m.timestamp else None,
            }
            for m in i.messages
        ]
    return data