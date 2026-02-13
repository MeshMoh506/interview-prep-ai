# app/routers/roadmaps.py
import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel

from app.database import get_db
from app.models.roadmap import Roadmap, Milestone, LearningResource, DailyGoal
from app.models.resume import Resume
from app.models.user import User
from app.routers.auth import get_current_user
from app.services.roadmap_ai_service import roadmap_ai_service

router = APIRouter(prefix="/api/v1/roadmaps", tags=["roadmaps"])


# ── Schemas ──────────────────────────────────────────────────────
class RoadmapCreate(BaseModel):
    target_role:    str
    current_role:   Optional[str] = None
    current_skills: Optional[List[str]] = []
    language:       str = "en"
    resume_id:      Optional[int] = None

class MilestoneProgressUpdate(BaseModel):
    progress:   float           # 0–100
    status:     Optional[str] = None

class ResourceCompleteUpdate(BaseModel):
    is_completed: bool

class GoalCreate(BaseModel):
    roadmap_id:     int
    title:          str
    target_minutes: int = 30

class GoalComplete(BaseModel):
    is_completed: bool


# ── Helpers ──────────────────────────────────────────────────────
def _resource_dict(r: LearningResource) -> dict:
    return {"id": r.id, "title": r.title, "url": r.url, "resource_type": r.resource_type,
            "platform": r.platform, "is_free": r.is_free, "est_hours": r.est_hours,
            "difficulty": r.difficulty, "is_completed": r.is_completed}

def _milestone_dict(m: Milestone) -> dict:
    return {"id": m.id, "roadmap_id": m.roadmap_id, "title": m.title,
            "description": m.description, "skill_focus": m.skill_focus,
            "order_index": m.order_index, "status": m.status,
            "difficulty": m.difficulty, "est_hours": m.est_hours,
            "progress": m.progress, "completed_at": m.completed_at.isoformat() if m.completed_at else None,
            "resources": [_resource_dict(r) for r in m.resources]}

def _roadmap_dict(rv: Roadmap, include_milestones=True) -> dict:
    d = {"id": rv.id, "user_id": rv.user_id, "title": rv.title,
         "target_role": rv.target_role, "current_role": rv.current_role,
         "current_skills": rv.current_skills, "target_skills": rv.target_skills,
         "missing_skills": rv.missing_skills, "language": rv.language,
         "status": rv.status, "overall_progress": rv.overall_progress,
         "streak_days": rv.streak_days,
         "last_activity": rv.last_activity.isoformat() if rv.last_activity else None,
         "created_at": rv.created_at.isoformat()}
    if include_milestones:
        d["milestones"] = [_milestone_dict(m) for m in rv.milestones]
    else:
        d["milestone_count"] = len(rv.milestones)
        d["completed_milestones"] = sum(1 for m in rv.milestones if m.status == "completed")
    return d

def _recalc_progress(roadmap: Roadmap):
    if not roadmap.milestones:
        roadmap.overall_progress = 0.0
        return
    total = sum(m.progress for m in roadmap.milestones)
    roadmap.overall_progress = round(total / len(roadmap.milestones), 1)

def _update_streak(roadmap: Roadmap):
    now = datetime.datetime.utcnow()
    if roadmap.last_activity:
        diff = (now.date() - roadmap.last_activity.date()).days
        if diff == 0:
            return  # already active today
        elif diff == 1:
            roadmap.streak_days += 1
        else:
            roadmap.streak_days = 1  # streak broken
    else:
        roadmap.streak_days = 1
    roadmap.last_activity = now


# ── POST / — Create roadmap ───────────────────────────────────────
@router.post("/", status_code=status.HTTP_201_CREATED)
def create_roadmap(body: RoadmapCreate, db: Session = Depends(get_db),
                   current_user: User = Depends(get_current_user)):
    # Pull skills from resume if available
    current_skills = list(body.current_skills or [])
    resume_text = ""
    if body.resume_id:
        resume = db.query(Resume).filter(Resume.id == body.resume_id,
                                         Resume.user_id == current_user.id).first()
    else:
        resume = (db.query(Resume).filter(Resume.user_id == current_user.id,
                  Resume.parsed_content.isnot(None)).order_by(Resume.updated_at.desc()).first())
    if resume:
        if resume.skills:
            extra = [s.get("name", str(s)) if isinstance(s, dict) else str(s)
                     for s in resume.skills[:20]]
            current_skills = list(set(current_skills + extra))
        if resume.parsed_content:
            resume_text = resume.parsed_content[:1500]

    # Skill gap analysis
    gap = roadmap_ai_service.analyze_skill_gap(
        body.target_role, current_skills, resume_text, language=body.language)
    if not gap["success"]:
        raise HTTPException(500, f"Skill gap analysis failed: {gap['error']}")
    analysis = gap["analysis"]

    missing   = analysis.get("missing_skills", [])
    existing  = analysis.get("existing_skills", current_skills)

    # Generate roadmap
    gen = roadmap_ai_service.generate_roadmap(
        body.target_role, missing, body.current_role or "", language=body.language)
    if not gen["success"]:
        raise HTTPException(500, f"Roadmap generation failed: {gen['error']}")
    data = gen["roadmap"]

    # Save roadmap
    rv = Roadmap(
        user_id=current_user.id, title=data.get("title", f"Roadmap to {body.target_role}"),
        target_role=body.target_role, current_role=body.current_role,
        current_skills=existing, target_skills=analysis.get("required_skills", []),
        missing_skills=missing, language=body.language,
        status="active", overall_progress=0.0, streak_days=0,
        last_activity=datetime.datetime.utcnow())
    db.add(rv); db.commit(); db.refresh(rv)

    # Save milestones + resources
    for ms_data in data.get("milestones", []):
        ms = Milestone(
            roadmap_id=rv.id, title=ms_data.get("title", ""),
            description=ms_data.get("description", ""),
            skill_focus=ms_data.get("skill_focus", ""),
            order_index=ms_data.get("order_index", 0),
            difficulty=ms_data.get("difficulty", "medium"),
            est_hours=ms_data.get("est_hours", 10),
            status="not_started" if ms_data.get("order_index", 0) > 0 else "in_progress",
            progress=0.0)
        db.add(ms); db.flush()
        for r_data in ms_data.get("resources", []):
            res = LearningResource(
                milestone_id=ms.id, title=r_data.get("title", ""),
                url=r_data.get("url"), resource_type=r_data.get("resource_type", "article"),
                platform=r_data.get("platform"), is_free=r_data.get("is_free", True),
                est_hours=r_data.get("est_hours", 2),
                difficulty=r_data.get("difficulty", "beginner"))
            db.add(res)

    db.commit(); db.refresh(rv)
    result = _roadmap_dict(rv)
    result["gap_analysis"] = analysis
    return result


# ── GET / — List roadmaps ────────────────────────────────────────
@router.get("/")
def list_roadmaps(db: Session = Depends(get_db),
                  current_user: User = Depends(get_current_user)):
    rvs = (db.query(Roadmap).filter(Roadmap.user_id == current_user.id)
           .order_by(Roadmap.updated_at.desc()).all())
    return [_roadmap_dict(rv, include_milestones=False) for rv in rvs]


# ── GET /{id} — Full roadmap ─────────────────────────────────────
@router.get("/{roadmap_id}")
def get_roadmap(roadmap_id: int, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    rv = db.query(Roadmap).filter(Roadmap.id == roadmap_id,
                                  Roadmap.user_id == current_user.id).first()
    if not rv: raise HTTPException(404, "Roadmap not found")
    return _roadmap_dict(rv)


# ── PATCH /{id}/milestones/{mid}/progress ────────────────────────
@router.patch("/{roadmap_id}/milestones/{milestone_id}/progress")
def update_milestone_progress(roadmap_id: int, milestone_id: int,
                               body: MilestoneProgressUpdate,
                               db: Session = Depends(get_db),
                               current_user: User = Depends(get_current_user)):
    rv = db.query(Roadmap).filter(Roadmap.id == roadmap_id,
                                  Roadmap.user_id == current_user.id).first()
    if not rv: raise HTTPException(404, "Roadmap not found")
    ms = db.query(Milestone).filter(Milestone.id == milestone_id,
                                    Milestone.roadmap_id == roadmap_id).first()
    if not ms: raise HTTPException(404, "Milestone not found")

    ms.progress = min(100.0, max(0.0, body.progress))
    if body.status:
        ms.status = body.status
    elif ms.progress >= 100:
        ms.status       = "completed"
        ms.completed_at = datetime.datetime.utcnow()
        # Auto-start next milestone
        next_ms = (db.query(Milestone)
                   .filter(Milestone.roadmap_id == roadmap_id,
                           Milestone.order_index == ms.order_index + 1,
                           Milestone.status == "not_started").first())
        if next_ms:
            next_ms.status = "in_progress"
    elif ms.progress > 0:
        ms.status = "in_progress"

    _recalc_progress(rv); _update_streak(rv)
    db.commit(); db.refresh(rv)
    return {"milestone": _milestone_dict(ms), "roadmap_progress": rv.overall_progress,
            "streak_days": rv.streak_days}


# ── PATCH /{id}/resources/{rid}/complete ────────────────────────
@router.patch("/{roadmap_id}/resources/{resource_id}/complete")
def complete_resource(roadmap_id: int, resource_id: int, body: ResourceCompleteUpdate,
                      db: Session = Depends(get_db),
                      current_user: User = Depends(get_current_user)):
    rv = db.query(Roadmap).filter(Roadmap.id == roadmap_id,
                                  Roadmap.user_id == current_user.id).first()
    if not rv: raise HTTPException(404, "Roadmap not found")
    res = (db.query(LearningResource)
           .join(Milestone).filter(LearningResource.id == resource_id,
                                   Milestone.roadmap_id == roadmap_id).first())
    if not res: raise HTTPException(404, "Resource not found")
    res.is_completed = body.is_completed
    ms = res.milestone
    total = len(ms.resources)
    done  = sum(1 for r in ms.resources if r.is_completed)
    if total > 0:
        ms.progress = round(done / total * 100, 1)
        if ms.progress >= 100:
            ms.status = "completed"; ms.completed_at = datetime.datetime.utcnow()
        elif ms.progress > 0:
            ms.status = "in_progress"
    _recalc_progress(rv); _update_streak(rv)
    db.commit()
    return {"resource_id": resource_id, "is_completed": body.is_completed,
            "milestone_progress": ms.progress, "roadmap_progress": rv.overall_progress}


# ── POST /{id}/goals ────────────────────────────────────────────
@router.post("/{roadmap_id}/goals", status_code=status.HTTP_201_CREATED)
def create_goal(roadmap_id: int, body: GoalCreate, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    rv = db.query(Roadmap).filter(Roadmap.id == roadmap_id,
                                  Roadmap.user_id == current_user.id).first()
    if not rv: raise HTTPException(404, "Roadmap not found")
    goal = DailyGoal(roadmap_id=roadmap_id, user_id=current_user.id,
                     title=body.title, target_minutes=body.target_minutes)
    db.add(goal); db.commit(); db.refresh(goal)
    return {"id": goal.id, "title": goal.title,
            "target_minutes": goal.target_minutes, "is_completed": goal.is_completed}


# ── PATCH /goals/{id}/complete ────────────────────────────────
@router.patch("/goals/{goal_id}/complete")
def complete_goal(goal_id: int, body: GoalComplete, db: Session = Depends(get_db),
                  current_user: User = Depends(get_current_user)):
    goal = db.query(DailyGoal).filter(DailyGoal.id == goal_id,
                                      DailyGoal.user_id == current_user.id).first()
    if not goal: raise HTTPException(404, "Goal not found")
    goal.is_completed = body.is_completed
    rv = goal.roadmap
    if rv: _update_streak(rv)
    db.commit()
    return {"id": goal.id, "is_completed": goal.is_completed,
            "streak_days": rv.streak_days if rv else 0}


# ── GET /{id}/suggest-goals ──────────────────────────────────
@router.get("/{roadmap_id}/suggest-goals")
def suggest_goals(roadmap_id: int, minutes: int = 60,
                  db: Session = Depends(get_db),
                  current_user: User = Depends(get_current_user)):
    rv = db.query(Roadmap).filter(Roadmap.id == roadmap_id,
                                  Roadmap.user_id == current_user.id).first()
    if not rv: raise HTTPException(404, "Not found")
    active_ms = next((m for m in rv.milestones if m.status == "in_progress"), None)
    ms_title  = active_ms.title if active_ms else rv.target_role
    result    = roadmap_ai_service.suggest_daily_goals(
        rv.title, ms_title, minutes, language=rv.language)
    return result


# ── GET /{id}/feedback ───────────────────────────────────────
@router.get("/{roadmap_id}/feedback")
def get_feedback(roadmap_id: int, db: Session = Depends(get_db),
                 current_user: User = Depends(get_current_user)):
    rv = db.query(Roadmap).filter(Roadmap.id == roadmap_id,
                                  Roadmap.user_id == current_user.id).first()
    if not rv: raise HTTPException(404, "Not found")
    completed = sum(1 for m in rv.milestones if m.status == "completed")
    total     = len(rv.milestones)
    result    = roadmap_ai_service.get_progress_feedback(
        rv.title, rv.overall_progress, completed, total, rv.streak_days, rv.language)
    return result


# ── DELETE /{id} ────────────────────────────────────────────
@router.delete("/{roadmap_id}")
def delete_roadmap(roadmap_id: int, db: Session = Depends(get_db),
                   current_user: User = Depends(get_current_user)):
    rv = db.query(Roadmap).filter(Roadmap.id == roadmap_id,
                                  Roadmap.user_id == current_user.id).first()
    if not rv: raise HTTPException(404, "Not found")
    db.delete(rv); db.commit()
    return {"message": "Deleted"}


# ── GET /stats/summary ───────────────────────────────────────
@router.get("/stats/summary")
def get_stats(db: Session = Depends(get_db),
              current_user: User = Depends(get_current_user)):
    from app.models.interview import Interview
    roadmaps   = db.query(Roadmap).filter(Roadmap.user_id == current_user.id).all()
    resumes    = db.query(Resume).filter(Resume.user_id == current_user.id).all()
    interviews = db.query(Interview).filter(Interview.user_id == current_user.id).all()
    completed_ivs = [iv for iv in interviews if iv.status == "completed"]
    avg_score = (sum(iv.score for iv in completed_ivs if iv.score) / len(completed_ivs)
                 if completed_ivs else None)
    best_streak = max((rv.streak_days for rv in roadmaps), default=0)
    active_roadmap = next((rv for rv in roadmaps if rv.status == "active"), None)
    return {
        "resumes_count":      len(resumes),
        "interviews_count":   len(interviews),
        "interviews_completed": len(completed_ivs),
        "avg_interview_score": round(avg_score, 1) if avg_score else None,
        "roadmaps_count":     len(roadmaps),
        "active_roadmap":     _roadmap_dict(active_roadmap, include_milestones=False) if active_roadmap else None,
        "best_streak":        best_streak,
    }