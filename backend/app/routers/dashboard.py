# app/routers/dashboard.py
"""
Single fast endpoint that returns ALL dashboard data in one call.
Fixes slow loading by eliminating multiple round-trips.
"""
import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.database import get_db
from app.models.user import User
from app.models.resume import Resume
from app.models.interview import Interview, InterviewMessage
from app.models.roadmap import Roadmap, Milestone, DailyGoal
from app.routers.auth import get_current_user

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])


def _roadmap_summary(rv: Roadmap) -> dict:
    completed = sum(1 for m in rv.milestones if m.status == "completed")
    total     = len(rv.milestones)
    active_ms = next((m for m in rv.milestones if m.status == "in_progress"), None)
    return {
        "id":               rv.id,
        "title":            rv.title,
        "target_role":      rv.target_role,
        "overall_progress": rv.overall_progress,
        "streak_days":      rv.streak_days,
        "status":           rv.status,
        "milestones_done":  completed,
        "milestones_total": total,
        "active_milestone": active_ms.title if active_ms else None,
        "last_activity":    rv.last_activity.isoformat() if rv.last_activity else None,
    }


def _interview_summary(iv: Interview) -> dict:
    return {
        "id":         iv.id,
        "job_role":   iv.job_role,
        "difficulty": iv.difficulty,
        "status":     iv.status,
        "score":      iv.score,
        "created_at": iv.created_at.isoformat(),
        "completed_at": iv.completed_at.isoformat() if iv.completed_at else None,
        "duration_minutes": iv.duration_minutes,
    }


@router.get("/")
def get_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    uid = current_user.id
    now = datetime.datetime.utcnow()

    # ── Resumes ───────────────────────────────────────────────
    resumes = db.query(Resume).filter(Resume.user_id == uid).all()
    resume_count     = len(resumes)
    analyzed_count   = sum(1 for r in resumes if r.parsed_content)
    latest_resume    = max(resumes, key=lambda r: r.created_at) if resumes else None

    # ── Interviews ────────────────────────────────────────────
    interviews       = db.query(Interview).filter(Interview.user_id == uid)\
                         .order_by(Interview.created_at.desc()).all()
    interview_count  = len(interviews)
    completed_ivs    = [iv for iv in interviews if iv.status == "completed"]
    scores           = [iv.score for iv in completed_ivs if iv.score is not None]
    avg_score        = round(sum(scores) / len(scores), 1) if scores else None
    best_score       = round(max(scores), 1) if scores else None
    recent_interviews = [_interview_summary(iv) for iv in interviews[:5]]

    # Score trend — last 10 completed interviews (oldest→newest for chart)
    score_trend = [
        {"label": f"#{i+1}", "score": round(iv.score, 1)}
        for i, iv in enumerate(reversed(completed_ivs[-10:]))
        if iv.score is not None
    ]

    # Interviews per role breakdown
    role_counts: dict = {}
    for iv in completed_ivs:
        role_counts[iv.job_role] = role_counts.get(iv.job_role, 0) + 1
    role_breakdown = [{"role": k, "count": v} for k, v in
                      sorted(role_counts.items(), key=lambda x: -x[1])[:5]]

    # ── Roadmaps ──────────────────────────────────────────────
    roadmaps        = db.query(Roadmap).filter(Roadmap.user_id == uid)\
                        .order_by(Roadmap.updated_at.desc()).all()
    roadmap_count   = len(roadmaps)
    active_roadmap  = next((rv for rv in roadmaps if rv.status == "active"), None)
    best_streak     = max((rv.streak_days for rv in roadmaps), default=0)

    # Goals today
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_goals = db.query(DailyGoal).filter(
        DailyGoal.user_id == uid,
        DailyGoal.date >= today_start
    ).all()
    goals_total     = len(today_goals)
    goals_done      = sum(1 for g in today_goals if g.is_completed)

    # ── Activity feed (last 10 events across all modules) ────
    activity = []

    for iv in interviews[:5]:
        activity.append({
            "type":    "interview",
            "icon":    "mic",
            "title":   f"Interview: {iv.job_role}",
            "subtitle": f"Score: {iv.score:.0f}/100" if iv.score else iv.status.title(),
            "time":    iv.created_at.isoformat(),
            "color":   "purple",
        })

    for rv in resumes[:3]:
        activity.append({
            "type":    "resume",
            "icon":    "description",
            "title":   f"Resume: {rv.title or 'Untitled'}",
            "subtitle": "Parsed & analyzed" if rv.parsed_content else "Uploaded",
            "time":    rv.created_at.isoformat(),
            "color":   "blue",
        })

    for roadmap in roadmaps[:3]:
        activity.append({
            "type":    "roadmap",
            "icon":    "map",
            "title":   f"Roadmap: {roadmap.target_role}",
            "subtitle": f"{roadmap.overall_progress:.0f}% complete",
            "time":    roadmap.created_at.isoformat(),
            "color":   "green",
        })

    # Sort by time descending, take top 10
    activity.sort(key=lambda x: x["time"], reverse=True)
    activity = activity[:10]

    # ── Skill highlights from roadmaps ───────────────────────
    all_missing: list = []
    all_current: list = []
    for rv in roadmaps:
        all_missing.extend(rv.missing_skills or [])
        all_current.extend(rv.current_skills or [])
    # Deduplicate, keep first 10
    skill_gaps    = list(dict.fromkeys(all_missing))[:10]
    known_skills  = list(dict.fromkeys(all_current))[:10]

    # ── Motivational tip ─────────────────────────────────────
    tip = _get_tip(interview_count, avg_score, best_streak, roadmap_count)

    return {
        # ── Counts ─────────────────────────────────────────
        "resume_count":       resume_count,
        "resume_analyzed":    analyzed_count,
        "interview_count":    interview_count,
        "interviews_completed": len(completed_ivs),
        "roadmap_count":      roadmap_count,

        # ── Scores ─────────────────────────────────────────
        "avg_score":   avg_score,
        "best_score":  best_score,
        "best_streak": best_streak,

        # ── Today ──────────────────────────────────────────
        "goals_today":  goals_total,
        "goals_done":   goals_done,

        # ── Charts ─────────────────────────────────────────
        "score_trend":     score_trend,
        "role_breakdown":  role_breakdown,

        # ── Latest data ────────────────────────────────────
        "recent_interviews":  recent_interviews,
        "active_roadmap":     _roadmap_summary(active_roadmap) if active_roadmap else None,
        "latest_resume_title": latest_resume.title if latest_resume else None,

        # ── Skills ─────────────────────────────────────────
        "skill_gaps":    skill_gaps,
        "known_skills":  known_skills,

        # ── Feed & tip ─────────────────────────────────────
        "activity_feed": activity,
        "tip":           tip,
    }


def _get_tip(interviews: int, avg: float | None, streak: int, roadmaps: int) -> dict:
    if interviews == 0:
        return {"emoji": "🎯", "title": "Start Practicing!",
                "body": "Try your first AI interview session to get personalized feedback."}
    if avg is not None and avg < 60:
        return {"emoji": "📚", "title": "Keep Practicing",
                "body": "Focus on clear, structured answers using the STAR method."}
    if streak >= 7:
        return {"emoji": "🔥", "title": f"{streak}-Day Streak!",
                "body": "Incredible consistency! You're building real momentum."}
    if roadmaps == 0:
        return {"emoji": "🗺️", "title": "Create a Roadmap",
                "body": "Get a personalized learning path tailored to your target role."}
    if avg is not None and avg >= 80:
        return {"emoji": "🌟", "title": "Excellent Performance!",
                "body": "Your interview scores are impressive. Keep pushing forward!"}
    return {"emoji": "💪", "title": "Stay Consistent",
            "body": "Daily practice is the key to interview success. You've got this!"}