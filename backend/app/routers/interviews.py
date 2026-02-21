# app/routers/interviews.py
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from app.models.interview_question import InterviewQuestion
from app.models.interview_question import InterviewQuestion
from app.models.resume import Resume

from app.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.interview import Interview, InterviewMessage
from app.models.resume import Resume
from app.services.interview_ai_service import InterviewAIService
from app.services.stt import transcribe_audio   # ← clean import from dedicated service

router = APIRouter(prefix="/api/v1/interviews", tags=["interviews"])
ai = InterviewAIService()


# backend/app/routers/interviews.py - UNIVERSAL SOLUTION
# Works for ANY field: Law, Medicine, Engineering, Business, Art, EVERYTHING!

@router.get("/questions/roles")
def get_available_roles(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get job roles from user's ACTUAL resume.
    NO HARDCODING - works for any field automatically!
    """
    
    roles = set()
    
    # Get user's parsed resumes
    resumes = db.query(Resume).filter(Resume.user_id == current_user.id).all()
    
    for resume in resumes:
        if resume.parsed_content:
            try:
                import json
                parsed = json.loads(resume.parsed_content) if isinstance(resume.parsed_content, str) else resume.parsed_content
                
                if isinstance(parsed, dict):
                    
                    # 1. Job title from contact info
                    if 'contact_info' in parsed and isinstance(parsed['contact_info'], dict):
                        job_title = parsed['contact_info'].get('job_title', '').strip()
                        if job_title:
                            roles.add(job_title)
                    
                    # 2. ALL job titles from work experience (most important!)
                    if 'experience' in parsed and isinstance(parsed['experience'], list):
                        for exp in parsed['experience']:
                            if isinstance(exp, dict):
                                title = exp.get('title', '').strip()
                                if title and len(title) > 2:  # Valid title
                                    roles.add(title)
                                    
                                # Also get company name for "X at Company" format
                                company = exp.get('company', '').strip()
                                if title and company:
                                    roles.add(f"{title}")  # Just the title
                    
                    # 3. Field from education (for students without experience)
                    if 'education' in parsed and isinstance(parsed['education'], list):
                        for edu in parsed['education']:
                            if isinstance(edu, dict):
                                degree = edu.get('degree', '').strip()
                                field = edu.get('field_of_study', '').strip()
                                
                                # Extract field name and suggest entry-level role
                                if field:
                                    # "Computer Science" → "Computer Science Graduate"
                                    roles.add(f"{field} Graduate")
                                    # Also add just the field
                                    roles.add(f"{field} Professional")
                                
                                if degree:
                                    # "Bachelor of Law" → "Law Graduate"
                                    # Extract the subject from degree
                                    degree_lower = degree.lower()
                                    for word in degree.split():
                                        if len(word) > 4 and word.lower() not in ['bachelor', 'master', 'degree', 'science', 'arts']:
                                            roles.add(f"{word.title()} Professional")
                    
                    # 4. Skills (for additional role suggestions)
                    if 'skills' in parsed and isinstance(parsed['skills'], list):
                        # Group skills to suggest roles
                        skills_text = ' '.join(parsed['skills']).lower()
                        
                        # Don't suggest roles from skills - too unreliable
                        # Just use for context
                        pass
                        
            except Exception as e:
                print(f"Error parsing resume {resume.id}: {e}")
                continue
    
    # If still no roles, suggest based on what user can enter themselves
    if not roles:
        roles = {
            "Custom Role (Type Your Own)",
        }
    
    # Clean and sort roles
    # Remove duplicates, very long titles, or invalid ones
    clean_roles = set()
    for role in roles:
        role = role.strip()
        if role and 3 < len(role) < 100:  # Reasonable length
            clean_roles.add(role)
    
    # Sort alphabetically
    sorted_roles = sorted(list(clean_roles))
    
    # Limit to top 20 most relevant (if too many)
    if len(sorted_roles) > 20:
        sorted_roles = sorted_roles[:20]
    
    return {"roles": sorted_roles if sorted_roles else ["Your Target Role"]}

@router.post("/questions")
def add_community_question(
    question: str,
    category: str,
    difficulty: str,
    job_role: str,
    tips: Optional[str] = None,
    tags: Optional[List[str]] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Add community question"""
    
    new_q = InterviewQuestion(
        question=question,
        category=category,
        difficulty=difficulty,
        job_role=job_role,
        tips=tips,
        tags=tags or [],
        is_community=True,
        submitted_by=current_user.id,
    )
    db.add(new_q)
    db.commit()
    db.refresh(new_q)
    
    return {"success": True, "question": new_q.to_dict()}


@router.get("/questions")
def get_questions(
    job_role: Optional[str] = None,
    category: Optional[str] = None,
    difficulty: Optional[str] = None,
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get interview questions"""
    
    query = db.query(InterviewQuestion)
    
    if job_role:
        query = query.filter(InterviewQuestion.job_role == job_role)
    if category:
        query = query.filter(InterviewQuestion.category == category)
    if difficulty:
        query = query.filter(InterviewQuestion.difficulty == difficulty)
    
    questions = query.order_by(
        InterviewQuestion.upvotes.desc()
    ).limit(limit).all()
    
    return {"questions": [q.to_dict() for q in questions]}


@router.post("/questions/{question_id}/vote")
def vote_question(
    question_id: int,
    vote: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Vote on question"""
    
    question = db.query(InterviewQuestion).filter(
        InterviewQuestion.id == question_id
    ).first()
    
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")
    
    if vote == "up":
        question.upvotes += 1
    elif vote == "down":
        question.downvotes += 1
    else:
        raise HTTPException(status_code=400, detail="Invalid vote")
    
    db.commit()
    
    return {
        "success": True,
        "upvotes": question.upvotes,
        "downvotes": question.downvotes
    }




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