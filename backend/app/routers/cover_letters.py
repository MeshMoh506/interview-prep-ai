# app/routers/cover_letters.py
"""
S5 — Cover Letter Generator API
Endpoints:
  POST /api/v1/cover-letters/generate  — generate + save
  GET  /api/v1/cover-letters/          — list user's letters
  GET  /api/v1/cover-letters/{id}      — get single letter
  PUT  /api/v1/cover-letters/{id}      — update content manually
  DELETE /api/v1/cover-letters/{id}    — delete
"""

import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.resume import Resume
from app.models.cover_letter import CoverLetter
from app.routers.auth import get_current_user
from app.services.cover_letter_service import generate_cover_letter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/cover-letters", tags=["cover-letters"])


# ── Request / Response schemas ────────────────────────────────────

class GenerateRequest(BaseModel):
    job_title:       str
    company_name:    Optional[str] = ""
    job_description: Optional[str] = ""
    tone:            Optional[str] = "professional"  # professional|enthusiastic|concise|creative
    language:        Optional[str] = "en"
    resume_id:       Optional[int] = None  # if None → uses latest parsed resume


class UpdateRequest(BaseModel):
    content:      Optional[str] = None
    job_title:    Optional[str] = None
    company_name: Optional[str] = None


# ── Endpoints ─────────────────────────────────────────────────────

@router.post("/generate", status_code=status.HTTP_201_CREATED)
def generate(
    req: GenerateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Generate a cover letter using AI and save it.
    Uses the user's latest parsed resume unless resume_id is specified.
    """
    uid = current_user.id

    # ── Fetch resume data ─────────────────────────────────────────
    resume = None
    if req.resume_id:
        resume = db.query(Resume).filter(
            Resume.id == req.resume_id,
            Resume.user_id == uid,
        ).first()
        if not resume:
            raise HTTPException(status_code=404, detail="Resume not found")
    else:
        # Use latest parsed resume
        resume = (
            db.query(Resume)
            .filter(Resume.user_id == uid, Resume.is_parsed == 1)
            .order_by(Resume.updated_at.desc())
            .first()
        )

    resume_data = {}
    if resume:
        resume_data = {
            "parsed_content": resume.parsed_content,
            "contact_info":   resume.contact_info,
            "experience":     resume.experience,
            "skills":         resume.skills,
            "education":      resume.education,
            "certifications": resume.certifications,
            "projects":       resume.projects,
        }

    # ── Generate via AI ───────────────────────────────────────────
    try:
        result = generate_cover_letter(
            job_title=req.job_title,
            company_name=req.company_name or "",
            job_description=req.job_description or "",
            tone=req.tone or "professional",
            language=req.language or "en",
            resume_data=resume_data,
        )
    except Exception as e:
        logger.error(f"Cover letter generation error: {e}")
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

    # ── Save to DB ────────────────────────────────────────────────
    cl = CoverLetter(
        user_id=uid,
        resume_id=resume.id if resume else None,
        job_title=req.job_title,
        company_name=req.company_name or "",
        job_description=req.job_description or "",
        tone=req.tone or "professional",
        language=req.language or "en",
        content=result["content"],
        word_count=result["word_count"],
        match_score=result["match_score"],
    )
    db.add(cl)
    db.commit()
    db.refresh(cl)

    return cl.to_dict()


@router.get("/")
def list_cover_letters(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all cover letters for the current user."""
    letters = (
        db.query(CoverLetter)
        .filter(CoverLetter.user_id == current_user.id)
        .order_by(CoverLetter.created_at.desc())
        .all()
    )
    return [cl.to_dict() for cl in letters]


@router.get("/{cover_letter_id}")
def get_cover_letter(
    cover_letter_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a single cover letter."""
    cl = db.query(CoverLetter).filter(
        CoverLetter.id == cover_letter_id,
        CoverLetter.user_id == current_user.id,
    ).first()
    if not cl:
        raise HTTPException(status_code=404, detail="Cover letter not found")
    return cl.to_dict()


@router.put("/{cover_letter_id}")
def update_cover_letter(
    cover_letter_id: int,
    req: UpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Manually edit cover letter content."""
    cl = db.query(CoverLetter).filter(
        CoverLetter.id == cover_letter_id,
        CoverLetter.user_id == current_user.id,
    ).first()
    if not cl:
        raise HTTPException(status_code=404, detail="Cover letter not found")

    if req.content is not None:
        cl.content = req.content
        cl.word_count = len(req.content.split())
    if req.job_title is not None:
        cl.job_title = req.job_title
    if req.company_name is not None:
        cl.company_name = req.company_name

    db.commit()
    db.refresh(cl)
    return cl.to_dict()


@router.delete("/{cover_letter_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_cover_letter(
    cover_letter_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a cover letter."""
    cl = db.query(CoverLetter).filter(
        CoverLetter.id == cover_letter_id,
        CoverLetter.user_id == current_user.id,
    ).first()
    if not cl:
        raise HTTPException(status_code=404, detail="Cover letter not found")
    db.delete(cl)
    db.commit()