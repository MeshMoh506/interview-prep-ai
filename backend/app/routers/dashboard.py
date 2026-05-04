# app/routers/dashboard.py - S3 UPDATED
import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.resume import Resume
from app.models.interview import Interview
from app.models.roadmap import Roadmap
from app.routers.auth import get_current_user
from app.services.insights_service import build_insights  # ← S3

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])


def _roadmap_summary(rv: Roadmap) -> dict:
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
    uid = current_user.id

    # ── Resumes ────────────────────────────────────────────────────
    resumes = db.query(Resume).filter(Resume.user_id == uid).all()
    resume_count = len(resumes)
    analyzed_count = sum(1 for r in resumes if r.parsed_content)
    latest_resume = max(resumes, key=lambda r: r.created_at) if resumes else None

    # ── Interviews ─────────────────────────────────────────────────
    interviews = (
        db.query(Interview)
        .filter(Interview.user_id == uid)
        .order_by(Interview.created_at.desc())
        .all()
    )
    interview_count = len(interviews)
    completed_ivs = [iv for iv in interviews if iv.status == "completed"]
    scores = [iv.score for iv in completed_ivs if iv.score is not None]
    avg_score = round(sum(scores) / len(scores), 1) if scores else None
    best_score = round(max(scores), 1) if scores else None
    recent_interviews = [_interview_summary(iv) for iv in interviews[:5]]

    # Score trend (last 10 completed)
    score_trend = [
        {"label": f"#{i+1}", "score": round(iv.score, 1)}
        for i, iv in enumerate(reversed(completed_ivs[-10:]))
        if iv.score is not None
    ]

    # Role breakdown
    role_counts = {}
    for iv in completed_ivs:
        role_counts[iv.job_role] = role_counts.get(iv.job_role, 0) + 1
    role_breakdown = [
        {"role": k, "count": v}
        for k, v in sorted(role_counts.items(), key=lambda x: -x[1])[:5]
    ]

    # ── Roadmaps ───────────────────────────────────────────────────
    roadmaps = (
        db.query(Roadmap)
        .filter(Roadmap.user_id == uid)
        .order_by(Roadmap.updated_at.desc())
        .all()
    )
    roadmap_count = len(roadmaps)
    active_roadmap = next(
        (rv for rv in roadmaps if rv.overall_progress < 100), None
    )

    # ── Activity feed ──────────────────────────────────────────────
    activity = []
    for iv in interviews[:5]:
        activity.append({
            "type": "interview",
            "icon": "mic",
            "title": f"Interview: {iv.job_role}",
            "subtitle": f"Score: {iv.score:.0f}/100" if iv.score else iv.status.title(),
            "time": iv.created_at.isoformat(),
            "color": "purple",
        })
    for rv in resumes[:3]:
        activity.append({
            "type": "resume",
            "icon": "description",
            "title": f"Resume: {rv.title or 'Untitled'}",
            "subtitle": "Parsed & analyzed" if rv.parsed_content else "Uploaded",
            "time": rv.created_at.isoformat(),
            "color": "blue",
        })
    for roadmap in roadmaps[:3]:
        activity.append({
            "type": "roadmap",
            "icon": "map",
            "title": f"Roadmap: {roadmap.target_role}",
            "subtitle": f"{roadmap.overall_progress:.0f}% complete",
            "time": roadmap.created_at.isoformat(),
            "color": "green",
        })
    activity.sort(key=lambda x: x["time"], reverse=True)
    activity = activity[:10]

    tip = _get_tip(interview_count, avg_score, roadmap_count)

    # ── S3: Smart Insights ─────────────────────────────────────────
    insights = build_insights(current_user, db)

    return {
        # User
        "user_name": current_user.full_name or current_user.email.split('@')[0],
        "user_email": current_user.email,

        # Resume
        "resume_count": resume_count,
        "resume_analyzed": analyzed_count,
        "latest_resume_title": latest_resume.title if latest_resume else None,

        # Interviews
        "interview_count": interview_count,
        "interviews_completed": len(completed_ivs),
        "avg_score": avg_score,
        "best_score": best_score,
        "score_trend": score_trend,
        "role_breakdown": role_breakdown,
        "recent_interviews": recent_interviews,

        # Roadmaps
        "roadmap_count": roadmap_count,
        "active_roadmap": _roadmap_summary(active_roadmap) if active_roadmap else None,

        # Activity
        "activity_feed": activity,

        # Tip
        "tip": tip,

        # ── S3 Insights (new fields — no breaking changes) ────────
        "weak_skills":           insights["weak_skills"],
        "strong_skills":         insights["strong_skills"],
        "performance_by_role":   insights["performance_by_role"],
        "streak_days":           insights["streak_days"],
        "weekly_summary":        insights["weekly_summary"],
        "coach_stats":           insights["coach_stats"],
        "next_action":           insights["next_action"],
        "improvement_velocity":  insights["improvement_velocity"],
    }


def _get_tip(interviews: int, avg: float | None, roadmaps: int) -> dict:
    if interviews == 0:
        return {"emoji": "🚀", "title": "Start Practicing!", "body": "Try your first AI interview session."}
    if avg is not None and avg < 60:
        return {"emoji": "💡", "title": "Keep Practicing", "body": "Focus on clear, structured answers."}
    if roadmaps == 0:
        return {"emoji": "🗺️", "title": "Create a Roadmap", "body": "Get a personalized learning path."}
    if avg is not None and avg >= 80:
        return {"emoji": "🌟", "title": "Excellent!", "body": "Your scores are impressive!"}
    return {"emoji": "💪", "title": "Stay Consistent", "body": "Daily practice is key!"}