# app/routers/dashboard.py - VERIFIED & SECURED
import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.resume import Resume
from app.models.interview import Interview
from app.models.roadmap import Roadmap
from app.routers.auth import get_current_user

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])


def _roadmap_summary(rv: Roadmap) -> dict:
    # Calculate progress from stages
    total_stages = len(rv.stages) if rv.stages else 0
    completed_stages = sum(1 for s in rv.stages if s.is_completed) if rv.stages else 0
    
    return {
        "id": rv.id,
        "title": rv.title,
        "target_role": rv.target_role,
        "overall_progress": rv.overall_progress,
        "stages_done": completed_stages,
        "stages_total": total_stages,
        "created_at": rv.created_at.isoformat() if rv.created_at else None,
    }


def _interview_summary(iv: Interview) -> dict:
    return {
        "id": iv.id,
        "job_role": iv.job_role,
        "difficulty": iv.difficulty,
        "status": iv.status,
        "score": iv.score,
        "created_at": iv.created_at.isoformat(),
        "completed_at": iv.completed_at.isoformat() if iv.completed_at else None,
    }


@router.get("/")
def get_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Dashboard endpoint - Returns ONLY current user's data.
    VERIFIED: All queries filter by user_id!
    """
    uid = current_user.id

    # ✅ VERIFIED: Resumes filtered by user_id
    resumes = db.query(Resume).filter(Resume.user_id == uid).all()
    resume_count = len(resumes)
    analyzed_count = sum(1 for r in resumes if r.parsed_content)
    latest_resume = max(resumes, key=lambda r: r.created_at) if resumes else None

    # ✅ VERIFIED: Interviews filtered by user_id
    interviews = db.query(Interview).filter(Interview.user_id == uid)\
                   .order_by(Interview.created_at.desc()).all()
    interview_count = len(interviews)
    completed_ivs = [iv for iv in interviews if iv.status == "completed"]
    scores = [iv.score for iv in completed_ivs if iv.score is not None]
    avg_score = round(sum(scores) / len(scores), 1) if scores else None
    best_score = round(max(scores), 1) if scores else None
    recent_interviews = [_interview_summary(iv) for iv in interviews[:5]]

    # Score trend (last 10 completed interviews)
    score_trend = [
        {"label": f"#{i+1}", "score": round(iv.score, 1)}
        for i, iv in enumerate(reversed(completed_ivs[-10:]))
        if iv.score is not None
    ]

    # Role breakdown (top 5 most practiced roles)
    role_counts = {}
    for iv in completed_ivs:
        role_counts[iv.job_role] = role_counts.get(iv.job_role, 0) + 1
    role_breakdown = [{"role": k, "count": v} for k, v in
                      sorted(role_counts.items(), key=lambda x: -x[1])[:5]]

    # ✅ VERIFIED: Roadmaps filtered by user_id
    roadmaps = db.query(Roadmap).filter(Roadmap.user_id == uid)\
                 .order_by(Roadmap.updated_at.desc()).all()
    roadmap_count = len(roadmaps)
    
    # Get active roadmap (most recently updated incomplete one)
    active_roadmap = None
    for rv in roadmaps:
        if rv.overall_progress < 100:
            active_roadmap = rv
            break

    # Activity feed (combined timeline of recent actions)
    activity = []
    
    # Add recent interviews
    for iv in interviews[:5]:
        activity.append({
            "type": "interview",
            "icon": "mic",
            "title": f"Interview: {iv.job_role}",
            "subtitle": f"Score: {iv.score:.0f}/100" if iv.score else iv.status.title(),
            "time": iv.created_at.isoformat(),
            "color": "purple",
        })

    # Add recent resumes
    for rv in resumes[:3]:
        activity.append({
            "type": "resume",
            "icon": "description",
            "title": f"Resume: {rv.title or 'Untitled'}",
            "subtitle": "Parsed & analyzed" if rv.parsed_content else "Uploaded",
            "time": rv.created_at.isoformat(),
            "color": "blue",
        })

    # Add recent roadmaps
    for roadmap in roadmaps[:3]:
        activity.append({
            "type": "roadmap",
            "icon": "map",
            "title": f"Roadmap: {roadmap.target_role}",
            "subtitle": f"{roadmap.overall_progress:.0f}% complete",
            "time": roadmap.created_at.isoformat(),
            "color": "green",
        })

    # Sort by time and limit to 10 most recent
    activity.sort(key=lambda x: x["time"], reverse=True)
    activity = activity[:10]

    # Motivational tip based on user's progress
    tip = _get_tip(interview_count, avg_score, roadmap_count)

    return {
        # User info (for personalization)
        "user_name": current_user.full_name or current_user.email.split('@')[0],
        "user_email": current_user.email,
        
        # Resume stats
        "resume_count": resume_count,
        "resume_analyzed": analyzed_count,
        "latest_resume_title": latest_resume.title if latest_resume else None,
        
        # Interview stats
        "interview_count": interview_count,
        "interviews_completed": len(completed_ivs),
        "avg_score": avg_score,
        "best_score": best_score,
        "score_trend": score_trend,
        "role_breakdown": role_breakdown,
        "recent_interviews": recent_interviews,
        
        # Roadmap stats
        "roadmap_count": roadmap_count,
        "active_roadmap": _roadmap_summary(active_roadmap) if active_roadmap else None,
        
        # Activity
        "activity_feed": activity,
        
        # Motivation
        "tip": tip,
    }


def _get_tip(interviews: int, avg: float | None, roadmaps: int) -> dict:
    """Generate contextual tip based on user's progress"""
    if interviews == 0:
        return {
            "emoji": "🎯",
            "title": "Start Practicing!",
            "body": "Try your first AI interview session."
        }
    if avg is not None and avg < 60:
        return {
            "emoji": "📚",
            "title": "Keep Practicing",
            "body": "Focus on clear, structured answers."
        }
    if roadmaps == 0:
        return {
            "emoji": "🗺️",
            "title": "Create a Roadmap",
            "body": "Get a personalized learning path."
        }
    if avg is not None and avg >= 80:
        return {
            "emoji": "🌟",
            "title": "Excellent!",
            "body": "Your scores are impressive!"
        }
    return {
        "emoji": "💪",
        "title": "Stay Consistent",
        "body": "Daily practice is key!"
    }