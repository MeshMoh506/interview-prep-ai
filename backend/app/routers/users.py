# app/routers/users.py
"""
User profile endpoints — all require authentication.

Routes:
  GET    /api/v1/users/me                  — full profile
  PUT    /api/v1/users/me                  — update profile fields
  POST   /api/v1/users/me/change-password  — verify current + set new password
  DELETE /api/v1/users/me                  — cascade delete all user data
  GET    /api/v1/users/me/stats            — interview stats
  GET    /api/v1/users/me/ai-profile       — read AI memory profile
  PUT    /api/v1/users/me/ai-profile       — update AI memory profile (used by AI tasks)
"""
import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.routers.auth import get_current_user
from app.utils.security import verify_password, hash_password

router = APIRouter(prefix="/api/v1/users", tags=["users"])


# ══════════════════════════════════════════════════════════════════
# PYDANTIC SCHEMAS
# ══════════════════════════════════════════════════════════════════
class UserProfileOut(BaseModel):
    id:                  int
    email:               str
    full_name:           Optional[str]
    job_title:           Optional[str]
    bio:                 Optional[str]
    location:            Optional[str]
    phone:               Optional[str]
    linkedin_url:        Optional[str]
    github_url:          Optional[str]
    portfolio_url:       Optional[str]
    avatar_url:          Optional[str]
    preferred_language:  str
    email_notifications: bool
    interview_reminders: bool
    total_interviews:    int
    avg_score:           Optional[float]
    best_score:          Optional[float]
    is_verified:         bool
    created_at:          datetime.datetime

    class Config:
        from_attributes = True


class ProfileUpdateIn(BaseModel):
    full_name:           Optional[str] = None
    job_title:           Optional[str] = None
    bio:                 Optional[str] = None
    location:            Optional[str] = None
    phone:               Optional[str] = None
    linkedin_url:        Optional[str] = None
    github_url:          Optional[str] = None
    portfolio_url:       Optional[str] = None
    avatar_url:          Optional[str] = None
    preferred_language:  Optional[str] = None
    email_notifications: Optional[bool] = None
    interview_reminders: Optional[bool] = None


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password:     str


class AiProfileIn(BaseModel):
    ai_profile: str  # JSON string or plain text report


class StatsOut(BaseModel):
    total_interviews: int
    avg_score:        Optional[float]
    best_score:       Optional[float]


# ══════════════════════════════════════════════════════════════════
# GET /me — full profile
# ══════════════════════════════════════════════════════════════════
@router.get("/me", response_model=UserProfileOut)
def get_profile(current_user: User = Depends(get_current_user)):
    """Get full profile of the authenticated user."""
    return current_user


# ══════════════════════════════════════════════════════════════════
# PUT /me — update profile fields
# ══════════════════════════════════════════════════════════════════
@router.put("/me", response_model=UserProfileOut)
def update_profile(
    body:         ProfileUpdateIn,
    current_user: User    = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    """
    Update any subset of profile fields.
    Only provided (non-None) fields are updated.
    """
    updatable = {
        "full_name", "job_title", "bio", "location", "phone",
        "linkedin_url", "github_url", "portfolio_url", "avatar_url",
        "preferred_language", "email_notifications", "interview_reminders",
    }
    updated = False
    for field, value in body.model_dump(exclude_none=True).items():
        if field in updatable:
            setattr(current_user, field, value)
            updated = True

    if updated:
        current_user.updated_at = datetime.datetime.utcnow()
        db.commit()
        db.refresh(current_user)

    return current_user


# ══════════════════════════════════════════════════════════════════
# POST /me/change-password
# ══════════════════════════════════════════════════════════════════
@router.post("/me/change-password")
def change_password(
    body:         ChangePasswordIn,
    current_user: User    = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    """
    Change password. Verifies current password before updating.
    Returns 400 if current_password is wrong.
    """
    if not verify_password(body.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )

    if len(body.new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 8 characters",
        )

    if body.current_password == body.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from current password",
        )

    current_user.hashed_password = hash_password(body.new_password)
    current_user.updated_at      = datetime.datetime.utcnow()
    db.commit()

    return {"message": "Password updated successfully"}


# ══════════════════════════════════════════════════════════════════
# DELETE /me — delete account + all data
# ══════════════════════════════════════════════════════════════════
@router.delete("/me")
def delete_account(
    current_user: User    = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    """
    Permanently delete the account and all associated data.
    Cascade rules on the User model handle related rows.
    """
    db.delete(current_user)
    db.commit()
    return {"message": "Account deleted successfully"}


# ══════════════════════════════════════════════════════════════════
# GET /me/stats — interview stats
# ══════════════════════════════════════════════════════════════════
@router.get("/me/stats", response_model=StatsOut)
def get_stats(current_user: User = Depends(get_current_user)):
    """Return the user's interview stats."""
    return StatsOut(
        total_interviews=current_user.total_interviews or 0,
        avg_score=current_user.avg_score,
        best_score=current_user.best_score,
    )


# ══════════════════════════════════════════════════════════════════
# AI MEMORY PROFILE — read and write
# Used by background tasks after each interview/practice session
# ══════════════════════════════════════════════════════════════════
@router.get("/me/ai-profile")
def get_ai_profile(current_user: User = Depends(get_current_user)):
    """
    Read the user's AI memory profile.
    Returns the living text/JSON report the AI uses as context.
    """
    return {
        "ai_profile": current_user.ai_profile or "",
        "has_profile": current_user.ai_profile is not None and len(current_user.ai_profile) > 0,
    }


@router.put("/me/ai-profile")
def update_ai_profile(
    body:         AiProfileIn,
    current_user: User    = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    """
    Update the user's AI memory profile.
    Called by background tasks after sessions end.
    The AI merges session insights into the existing profile text.
    """
    if len(body.ai_profile) > 10000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="AI profile too long (max 10,000 characters)",
        )
    current_user.ai_profile = body.ai_profile
    current_user.updated_at = datetime.datetime.utcnow()
    db.commit()
    return {"message": "AI profile updated", "length": len(body.ai_profile)}