import os, datetime, tempfile
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel

from app.database import get_db
from app.models.interview import Interview, InterviewMessage
from app.models.resume import Resume
from app.models.user import User
from app.routers.auth import get_current_user
from app.services.interview_ai_service import interview_ai_service

router = APIRouter(prefix="/api/v1/interviews", tags=["interviews"])


# ── Schemas ──────────────────────────────────────────────────────
class InterviewCreate(BaseModel):
    job_role:        str
    difficulty:      str = "medium"
    interview_type:  str = "mixed"
    language:        str = "en"
    resume_id:       Optional[int] = None
    job_description: Optional[str] = None

class SendMessage(BaseModel):
    content: str


# ── Helpers ──────────────────────────────────────────────────────
def _msg_dict(m: InterviewMessage) -> dict:
    return {"id": m.id, "interview_id": m.interview_id, "role": m.role,
            "content": m.content, "timestamp": m.timestamp.isoformat(),
            "evaluation": m.evaluation}

def _interview_dict(iv: Interview) -> dict:
    return {"id": iv.id, "user_id": iv.user_id, "job_role": iv.job_role,
            "difficulty": iv.difficulty, "interview_type": iv.interview_type,
            "language": iv.language or "en", "status": iv.status,
            "score": iv.score, "feedback": iv.feedback,
            "created_at": iv.created_at.isoformat(),
            "duration_minutes": iv.duration_minutes,
            "messages": [_msg_dict(m) for m in iv.messages]}

def _reply(iv, user_msg, ai_msg, evaluation, int_status) -> dict:
    r = {"interview_id": iv.id, "interview_status": int_status,
         "user_message": _msg_dict(user_msg) if user_msg else None,
         "ai_message": _msg_dict(ai_msg), "evaluation": evaluation}
    if int_status == "completed":
        r["score"] = iv.score; r["feedback"] = iv.feedback
    return r

def _get_resume(db, user_id, resume_id=None):
    if resume_id:
        return db.query(Resume).filter(Resume.id == resume_id, Resume.user_id == user_id).first()
    return (db.query(Resume).filter(Resume.user_id == user_id,
            Resume.parsed_content.isnot(None)).order_by(Resume.updated_at.desc()).first())

def _build_context(user, resume=None, job_desc=None) -> str:
    parts = [f"Candidate: {user.full_name}"]
    if resume and resume.parsed_content:
        if resume.skills:
            names = [s.get("name", str(s)) if isinstance(s, dict) else str(s) for s in resume.skills[:15]]
            parts.append(f"Skills: {', '.join(names)}")
        if resume.experience:
            exp = [f"{e.get('title','?')} at {e.get('company','?')}" for e in resume.experience[:3] if isinstance(e, dict)]
            if exp: parts.append(f"Experience: {'; '.join(exp)}")
    if job_desc:
        parts.append(f"\nTarget Role:\n{job_desc[:800]}")
    return "\n".join(parts)

def _history(messages):
    return [{"role": m.role, "content": m.content} for m in messages]

def _qa_pairs(messages):
    pairs, ai_q = [], []
    for m in messages:
        if m.role == "assistant": ai_q.append(m.content)
        elif m.role == "user" and ai_q:
            pairs.append({"question": ai_q[-1], "answer": m.content,
                          "score": (m.evaluation or {}).get("score")})
    return pairs

def _maybe_complete(iv, ai_res, db) -> str:
    if not ai_res.get("is_done"): return "in_progress"
    iv.status = "completed"
    iv.completed_at = datetime.datetime.utcnow()
    iv.duration_minutes = max(1, int((iv.completed_at - iv.started_at).total_seconds() / 60))
    fb = interview_ai_service.generate_final_feedback(
        iv.job_role, iv.difficulty, iv.interview_type,
        _qa_pairs(iv.messages), language=iv.language or "en")
    if fb["success"]:
        iv.feedback = fb["feedback"]
        iv.score = fb["feedback"].get("overall_score", 0)
    db.commit()
    return "completed"


# ── POST / ───────────────────────────────────────────────────────
@router.post("/", status_code=status.HTTP_201_CREATED)
def start_interview(body: InterviewCreate, db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    resume  = _get_resume(db, current_user.id, body.resume_id)
    context = _build_context(current_user, resume, body.job_description)
    iv = Interview(user_id=current_user.id, job_role=body.job_role,
                   difficulty=body.difficulty, interview_type=body.interview_type,
                   language=body.language, job_description=body.job_description,
                   resume_id=resume.id if resume else None,
                   status="in_progress", started_at=datetime.datetime.utcnow())
    db.add(iv); db.commit(); db.refresh(iv)
    result = interview_ai_service.start_interview(
        body.job_role, body.difficulty, body.interview_type,
        language=body.language, user_context=context)
    if not result["success"]:
        db.delete(iv); db.commit()
        raise HTTPException(500, result["error"])
    ai_msg = InterviewMessage(interview_id=iv.id, role="assistant", content=result["message"])
    db.add(ai_msg); db.commit(); db.refresh(ai_msg)
    return {"interview_id": iv.id, "interview_status": "in_progress",
            "user_message": None, "ai_message": _msg_dict(ai_msg), "evaluation": None}


# ── POST /{id}/message ───────────────────────────────────────────
@router.post("/{interview_id}/message")
def send_message(interview_id: int, body: SendMessage,
                 db: Session = Depends(get_db),
                 current_user: User = Depends(get_current_user)):
    iv = db.query(Interview).filter(Interview.id == interview_id,
                                    Interview.user_id == current_user.id).first()
    if not iv: raise HTTPException(404, "Not found")
    if iv.status != "in_progress": raise HTTPException(400, "Already completed")
    user_msg = InterviewMessage(interview_id=iv.id, role="user", content=body.content)
    db.add(user_msg); db.commit(); db.refresh(user_msg)
    ai_qs  = [m for m in iv.messages if m.role == "assistant"]
    last_q = ai_qs[-1].content if ai_qs else "Tell me about yourself."
    ev = interview_ai_service.evaluate_answer(
        last_q, body.content, iv.job_role, iv.difficulty, language=iv.language or "en")
    if ev["success"]:
        user_msg.evaluation = ev["evaluation"]; db.commit(); db.refresh(user_msg)
    resume  = _get_resume(db, current_user.id, iv.resume_id)
    context = _build_context(current_user, resume, iv.job_description)
    ai_res  = interview_ai_service.get_next_question(
        iv.job_role, iv.difficulty, iv.interview_type,
        _history(iv.messages), language=iv.language or "en", user_context=context)
    if not ai_res["success"]: raise HTTPException(500, ai_res["error"])
    ai_msg = InterviewMessage(interview_id=iv.id, role="assistant", content=ai_res["message"])
    db.add(ai_msg)
    int_status = _maybe_complete(iv, ai_res, db)
    db.commit(); db.refresh(ai_msg)
    return _reply(iv, user_msg, ai_msg, user_msg.evaluation, int_status)


# ── POST /{id}/voice ─────────────────────────────────────────────
@router.post("/{interview_id}/voice")
async def send_voice(interview_id: int, audio: UploadFile = File(...),
                     language: Optional[str] = Form(None),
                     db: Session = Depends(get_db),
                     current_user: User = Depends(get_current_user)):
    iv = db.query(Interview).filter(Interview.id == interview_id,
                                    Interview.user_id == current_user.id).first()
    if not iv: raise HTTPException(404, "Not found")
    if iv.status != "in_progress": raise HTTPException(400, "Already completed")
    suffix = os.path.splitext(audio.filename or "a.webm")[1] or ".webm"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await audio.read()); tmp_path = tmp.name
    try:
        tr = interview_ai_service.transcribe_audio(tmp_path, language=language or iv.language or None)
    finally:
        try: os.unlink(tmp_path)
        except: pass
    if not tr["success"]: raise HTTPException(500, f"Transcription failed: {tr['error']}")
    text = tr["text"].strip()
    if not text: raise HTTPException(400, "Could not understand audio. Please try again.")
    user_msg = InterviewMessage(interview_id=iv.id, role="user", content=text)
    db.add(user_msg); db.commit(); db.refresh(user_msg)
    ai_qs  = [m for m in iv.messages if m.role == "assistant"]
    last_q = ai_qs[-1].content if ai_qs else "Tell me about yourself."
    ev = interview_ai_service.evaluate_answer(
        last_q, text, iv.job_role, iv.difficulty, language=iv.language or "en")
    if ev["success"]:
        user_msg.evaluation = ev["evaluation"]; db.commit(); db.refresh(user_msg)
    resume  = _get_resume(db, current_user.id, iv.resume_id)
    context = _build_context(current_user, resume, iv.job_description)
    ai_res  = interview_ai_service.get_next_question(
        iv.job_role, iv.difficulty, iv.interview_type,
        _history(iv.messages), language=iv.language or "en", user_context=context)
    if not ai_res["success"]: raise HTTPException(500, ai_res["error"])
    ai_msg = InterviewMessage(interview_id=iv.id, role="assistant", content=ai_res["message"])
    db.add(ai_msg)
    int_status = _maybe_complete(iv, ai_res, db)
    db.commit(); db.refresh(ai_msg)
    r = _reply(iv, user_msg, ai_msg, user_msg.evaluation, int_status)
    r["transcript"] = text
    return r


# ── POST /{id}/end ───────────────────────────────────────────────
@router.post("/{interview_id}/end")
def end_interview(interview_id: int, db: Session = Depends(get_db),
                  current_user: User = Depends(get_current_user)):
    iv = db.query(Interview).filter(Interview.id == interview_id,
                                    Interview.user_id == current_user.id).first()
    if not iv: raise HTTPException(404, "Not found")
    if iv.status != "completed" and iv.messages:
        iv.status = "completed"
        iv.completed_at = datetime.datetime.utcnow()
        iv.duration_minutes = max(1, int((iv.completed_at - iv.started_at).total_seconds() / 60))
        fb = interview_ai_service.generate_final_feedback(
            iv.job_role, iv.difficulty, iv.interview_type,
            _qa_pairs(iv.messages), language=iv.language or "en")
        if fb["success"]:
            iv.feedback = fb["feedback"]
            iv.score = fb["feedback"].get("overall_score", 0)
        db.commit(); db.refresh(iv)
    return {"interview_id": iv.id, "interview_status": iv.status,
            "score": iv.score, "feedback": iv.feedback}


# ── GET / ────────────────────────────────────────────────────────
@router.get("/")
def list_interviews(db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    ivs = (db.query(Interview).filter(Interview.user_id == current_user.id)
           .order_by(Interview.created_at.desc()).all())
    return [_interview_dict(iv) for iv in ivs]


# ── GET /{id} ────────────────────────────────────────────────────
@router.get("/{interview_id}")
def get_interview(interview_id: int, db: Session = Depends(get_db),
                  current_user: User = Depends(get_current_user)):
    iv = db.query(Interview).filter(Interview.id == interview_id,
                                    Interview.user_id == current_user.id).first()
    if not iv: raise HTTPException(404, "Not found")
    return _interview_dict(iv)


# ── DELETE /{id} ─────────────────────────────────────────────────
@router.delete("/{interview_id}")
def delete_interview(interview_id: int, db: Session = Depends(get_db),
                     current_user: User = Depends(get_current_user)):
    iv = db.query(Interview).filter(Interview.id == interview_id,
                                    Interview.user_id == current_user.id).first()
    if not iv: raise HTTPException(404, "Not found")
    db.delete(iv); db.commit()
    return {"message": "Deleted"}