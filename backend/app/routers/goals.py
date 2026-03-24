# app/routers/goals.py
import logging
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.goal import Goal
from app.models.interview import Interview
from app.models.roadmap import Roadmap
from app.models.resume import Resume
from app.models.user import User
from app.routers.auth import get_current_user
from app.services.goal_ai_service import generate_coach_tip
from app.services.roadmap_ai_service import RoadmapAIService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/goals", tags=["goals"])
_roadmap_ai = RoadmapAIService()


# ═══════════════════════════════════════════════════════════════════
# SCHEMAS
# ═══════════════════════════════════════════════════════════════════

class GoalCreate(BaseModel):
    title:                   str
    target_role:             str
    target_company:          Optional[str] = None
    deadline:                Optional[str] = None   # ISO date string "2026-09-01"
    weekly_interview_target: int           = 3
    resume_id:               Optional[int] = None
    difficulty:              str           = "intermediate"
    language:                str           = "en"
    auto_generate_roadmap:   bool          = True

class GoalUpdate(BaseModel):
    title:                   Optional[str] = None
    target_role:             Optional[str] = None
    target_company:          Optional[str] = None
    deadline:                Optional[str] = None
    weekly_interview_target: Optional[int] = None
    status:                  Optional[str] = None


# ═══════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════

def _get_goal(goal_id: int, user_id: int, db: Session) -> Goal:
    g = db.query(Goal).filter(Goal.id == goal_id, Goal.user_id == user_id).first()
    if not g:
        raise HTTPException(status_code=404, detail="Goal not found")
    return g


def _reset_week_if_needed(goal: Goal, db: Session):
    """Reset current_week_count if we've entered a new week."""
    now = datetime.utcnow()
    if goal.current_week_start is None or (now - goal.current_week_start).days >= 7:
        goal.current_week_start  = now
        goal.current_week_count  = 0
        db.commit()


def _build_progress(goal: Goal, db: Session) -> dict:
    """Compute full progress stats for a goal."""
    _reset_week_if_needed(goal, db)

    # Interview stats
    interviews = db.query(Interview).filter(
        Interview.user_id == goal.user_id,
        Interview.goal_id == goal.id,
        Interview.status  == "completed",
    ).order_by(Interview.created_at.desc()).all()

    scores = [i.score for i in interviews if i.score is not None]
    avg_score   = round(sum(scores) / len(scores), 1) if scores else None
    recent_scores = scores[:3]

    # Roadmap progress
    roadmap_progress = None
    if goal.roadmap_id:
        rm = db.query(Roadmap).filter(Roadmap.id == goal.roadmap_id).first()
        if rm:
            roadmap_progress = rm.overall_progress

    # Resume match (last ats_score if resume linked)
    resume_match = None
    if goal.resume_id:
        rv = db.query(Resume).filter(Resume.id == goal.resume_id).first()
        if rv and rv.ats_score:
            resume_match = rv.ats_score

    # Weeks remaining
    weeks_left = goal.weeks_remaining

    return {
        "interviews_done":    len(interviews),
        "avg_score":          avg_score,
        "best_score":         round(max(scores), 1) if scores else None,
        "recent_scores":      recent_scores,
        "roadmap_progress":   roadmap_progress,
        "resume_match":       resume_match,
        "weeks_remaining":    weeks_left,
        "this_week_done":     goal.current_week_count,
        "this_week_target":   goal.weekly_interview_target,
        "on_track":           goal.current_week_count >= goal.weekly_interview_target
                              if goal.weekly_interview_target > 0 else True,
    }


# ═══════════════════════════════════════════════════════════════════
# ROUTES
# ═══════════════════════════════════════════════════════════════════

# ── 1. List all goals ─────────────────────────────────────────────
@router.get("/")
def list_goals(
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goals = db.query(Goal).filter(Goal.user_id == current_user.id)\
               .order_by(Goal.created_at.desc()).all()
    return [g.to_dict() for g in goals]


# ── 2. Create goal (+ optional auto-roadmap) ─────────────────────
@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_goal(
    req:          GoalCreate,
    db:           Session    = Depends(get_db),
    current_user: User       = Depends(get_current_user),
):
    # Parse deadline
    deadline_dt = None
    if req.deadline:
        try:
            deadline_dt = datetime.fromisoformat(req.deadline)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid deadline format. Use ISO: 2026-09-01")

    goal = Goal(
        user_id                 = current_user.id,
        title                   = req.title,
        target_role             = req.target_role,
        target_company          = req.target_company,
        deadline                = deadline_dt,
        weekly_interview_target = req.weekly_interview_target,
        current_week_start      = datetime.utcnow(),
        current_week_count      = 0,
        resume_id               = req.resume_id,
        status                  = "active",
    )
    db.add(goal)
    db.flush()   # get goal.id before commit

    # Auto-generate roadmap
    if req.auto_generate_roadmap:
        try:
            roadmap_data = await _roadmap_ai.generate_roadmap(
                target_role=req.target_role,
                difficulty=req.difficulty,
            )
            from app.models.roadmap import Roadmap as RoadmapModel, RoadmapStage, RoadmapTask
            roadmap = RoadmapModel(
                user_id         = current_user.id,
                goal_id         = goal.id,
                title           = roadmap_data.get("title", f"Path to {req.target_role}"),
                description     = roadmap_data.get("description", ""),
                target_role     = req.target_role,
                difficulty      = req.difficulty,
                estimated_weeks = roadmap_data.get("estimated_weeks", 12),
                is_ai_generated = True,
                category        = roadmap_data.get("category", "technology"),
                tags            = roadmap_data.get("tags", []),
            )
            db.add(roadmap)
            db.flush()

            for i, stage_data in enumerate(roadmap_data.get("stages", [])):
                stage = RoadmapStage(
                    roadmap_id      = roadmap.id,
                    order           = i + 1,
                    title           = stage_data["title"],
                    description     = stage_data.get("description", ""),
                    color           = stage_data.get("color", "#8B5CF6"),
                    icon            = stage_data.get("icon", "📚"),
                    estimated_hours = stage_data.get("estimated_hours", 10),
                    difficulty      = stage_data.get("difficulty", req.difficulty),
                    is_unlocked     = (i == 0),
                )
                db.add(stage)
                db.flush()
                for j, task_data in enumerate(stage_data.get("tasks", [])):
                    db.add(RoadmapTask(
                        stage_id        = stage.id,
                        order           = j + 1,
                        title           = task_data["title"],
                        description     = task_data.get("description", ""),
                        estimated_hours = task_data.get("estimated_hours", 2),
                        resources       = task_data.get("resources", []),
                    ))

            goal.roadmap_id = roadmap.id
        except Exception as e:
            logger.warning(f"Auto-roadmap generation failed for goal {goal.id}: {e}")
            # Don't fail the whole goal creation

    db.commit()
    db.refresh(goal)
    return goal.to_dict()


# ── 3. Get single goal ────────────────────────────────────────────
@router.get("/{goal_id}")
def get_goal(
    goal_id:      int,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    return _get_goal(goal_id, current_user.id, db).to_dict()


# ── 4. Update goal ────────────────────────────────────────────────
@router.put("/{goal_id}")
def update_goal(
    goal_id: int,
    req:     GoalUpdate,
    db:      Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    goal = _get_goal(goal_id, current_user.id, db)
    if req.title:                   goal.title                   = req.title
    if req.target_role:             goal.target_role             = req.target_role
    if req.target_company is not None: goal.target_company       = req.target_company
    if req.weekly_interview_target: goal.weekly_interview_target = req.weekly_interview_target
    if req.status:                  goal.status                  = req.status
    if req.deadline:
        try:
            goal.deadline = datetime.fromisoformat(req.deadline)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid deadline format")
    db.commit()
    db.refresh(goal)
    return goal.to_dict()


# ── 5. Delete goal ────────────────────────────────────────────────
@router.delete("/{goal_id}", status_code=204)
def delete_goal(
    goal_id:      int,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goal = _get_goal(goal_id, current_user.id, db)
    db.delete(goal)
    db.commit()


# ── 6. Mark goal as achieved 🎉 ───────────────────────────────────
@router.post("/{goal_id}/achieve")
def achieve_goal(
    goal_id:      int,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goal             = _get_goal(goal_id, current_user.id, db)
    goal.status      = "achieved"
    goal.achieved_at = datetime.utcnow()
    db.commit()
    db.refresh(goal)
    return {"success": True, "goal": goal.to_dict()}


# ── 7. Get full progress report ───────────────────────────────────
@router.get("/{goal_id}/progress")
def get_progress(
    goal_id:      int,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goal     = _get_goal(goal_id, current_user.id, db)
    progress = _build_progress(goal, db)
    return {**goal.to_dict(), "progress": progress}


# ── 8. Refresh AI coach tip ───────────────────────────────────────
@router.post("/{goal_id}/coach-tip")
def refresh_coach_tip(
    goal_id:      int,
    language:     str     = "en",
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goal     = _get_goal(goal_id, current_user.id, db)
    progress = _build_progress(goal, db)

    # Get radar dimensions from resume if linked
    radar_dimensions = None
    if goal.resume_id:
        resume = db.query(Resume).filter(Resume.id == goal.resume_id).first()
        if resume and resume.analysis_feedback:
            radar_dimensions = resume.analysis_feedback.get("dimensions")

    tip = generate_coach_tip(
        target_role         = goal.target_role,
        language            = language,
        recent_scores       = progress["recent_scores"],
        radar_dimensions    = radar_dimensions,
        interviews_done     = progress["interviews_done"],
        weekly_target       = goal.weekly_interview_target,
        current_week_count  = goal.current_week_count,
        roadmap_progress    = progress["roadmap_progress"],
    )

    goal.coach_tip            = tip
    goal.coach_tip_updated_at = datetime.utcnow()
    db.commit()

    return {"coach_tip": tip}


# ── Internal helper: increment weekly count after interview ───────
def increment_goal_week_count(goal_id: int, db: Session):
    """Call this from interviews router when an interview is completed."""
    goal = db.query(Goal).filter(Goal.id == goal_id).first()
    if not goal or not goal.is_active:
        return
    _reset_week_if_needed(goal, db)
    goal.current_week_count += 1
    db.commit()