# backend/app/routers/users.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from pydantic import BaseModel, EmailStr
from typing import Optional
from app.database import get_db
from app.models.user import User
from app.models.interview import Interview
from app.models.resume import Resume
from app.routers.auth import get_current_user
from app.utils.security import hash_password, verify_password
import datetime

router = APIRouter(prefix="/api/v1/users", tags=["Users"])


# ── Schemas ──────────────────────────────────────────────────────────────────

class UserProfileResponse(BaseModel):
    id: int
    email: str
    full_name: Optional[str]
    bio: Optional[str]
    location: Optional[str]
    phone: Optional[str]
    linkedin_url: Optional[str]
    github_url: Optional[str]
    portfolio_url: Optional[str]
    avatar_url: Optional[str]
    preferred_language: str
    job_title: Optional[str]
    email_notifications: bool
    interview_reminders: bool
    total_interviews: int
    avg_score: Optional[float]
    best_score: Optional[float]
    is_active: bool
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class ProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    bio: Optional[str] = None
    location: Optional[str] = None
    phone: Optional[str] = None
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None
    job_title: Optional[str] = None
    preferred_language: Optional[str] = None


class PreferencesUpdate(BaseModel):
    email_notifications: Optional[bool] = None
    interview_reminders: Optional[bool] = None
    preferred_language: Optional[str] = None


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class StatsResponse(BaseModel):
    total_interviews: int
    completed_interviews: int
    avg_score: Optional[float]
    best_score: Optional[float]
    total_resumes: int
    member_since_days: int


# ── Helpers ───────────────────────────────────────────────────────────────────

def _sync_stats(user: User, db: Session):
    """Recompute and save user stats from DB."""
    interviews = db.query(Interview).filter(
        Interview.user_id == user.id,
        Interview.status == "completed"
    ).all()

    scores = [i.score for i in interviews if i.score is not None]
    user.total_interviews = len(interviews)
    user.avg_score = round(sum(scores) / len(scores), 1) if scores else None
    user.best_score = round(max(scores), 1) if scores else None
    db.commit()


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get("/me", response_model=UserProfileResponse)
def get_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get full profile of current user."""
    _sync_stats(current_user, db)
    db.refresh(current_user)
    return current_user


@router.put("/me", response_model=UserProfileResponse)
def update_profile(
    data: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update profile fields."""
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.put("/me/preferences", response_model=UserProfileResponse)
def update_preferences(
    data: PreferencesUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update notification and language preferences."""
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/me/change-password")
def change_password(
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change password after verifying current one."""
    if not verify_password(data.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    if len(data.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 6 characters"
        )
    current_user.hashed_password = hash_password(data.new_password)
    db.commit()
    return {"message": "Password changed successfully"}


@router.get("/me/stats", response_model=StatsResponse)
def get_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get user statistics."""
    _sync_stats(current_user, db)
    db.refresh(current_user)

    total_resumes = db.query(Resume).filter(Resume.user_id == current_user.id).count()
    completed = db.query(Interview).filter(
        Interview.user_id == current_user.id,
        Interview.status == "completed"
    ).count()

    member_days = (datetime.datetime.utcnow() - current_user.created_at).days

    return StatsResponse(
        total_interviews=current_user.total_interviews,
        completed_interviews=completed,
        avg_score=current_user.avg_score,
        best_score=current_user.best_score,
        total_resumes=total_resumes,
        member_since_days=member_days,
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Permanently delete account and all data."""
    db.delete(current_user)
    db.commit()
    return None