# app/routers/goals.py
# CHANGES vs original:
#   1. Added POST /{goal_id}/generate-roadmap  — auto-create roadmap for goal
#   2. Added GET  /{goal_id}/next-step         — personalized next action
#   3. Added POST /{goal_id}/link-resume       — link existing resume to goal
#   Everything else unchanged.

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
    deadline:                Optional[str] = None
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

class LinkResumeRequest(BaseModel):
    resume_id: int


# ═══════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════

def _get_goal(goal_id: int, user_id: int, db: Session) -> Goal:
    g = db.query(Goal).filter(Goal.id == goal_id, Goal.user_id == user_id).first()
    if not g:
        raise HTTPException(status_code=404, detail="Goal not found")
    return g


def _reset_week_if_needed(goal: Goal, db: Session):
    now = datetime.utcnow()
    if goal.current_week_start is None or (now - goal.current_week_start).days >= 7:
        goal.current_week_start = now
        goal.current_week_count = 0
        db.commit()


def _build_progress(goal: Goal, db: Session) -> dict:
    _reset_week_if_needed(goal, db)

    interviews = db.query(Interview).filter(
        Interview.user_id == goal.user_id,
        Interview.goal_id == goal.id,
        Interview.status  == "completed",
    ).order_by(Interview.created_at.desc()).all()

    scores        = [i.score for i in interviews if i.score is not None]
    avg_score     = round(sum(scores) / len(scores), 1) if scores else None
    recent_scores = scores[:3]

    roadmap_progress = None
    if goal.roadmap_id:
        rm = db.query(Roadmap).filter(Roadmap.id == goal.roadmap_id).first()
        if rm:
            roadmap_progress = rm.overall_progress

    resume_match = None
    if goal.resume_id:
        rv = db.query(Resume).filter(Resume.id == goal.resume_id).first()
        if rv and rv.ats_score:
            resume_match = rv.ats_score

    return {
        "interviews_done":  len(interviews),
        "avg_score":        avg_score,
        "best_score":       round(max(scores), 1) if scores else None,
        "recent_scores":    recent_scores,
        "roadmap_progress": roadmap_progress,
        "resume_match":     resume_match,
        "weeks_remaining":  goal.weeks_remaining,
        "this_week_done":   goal.current_week_count,
        "this_week_target": goal.weekly_interview_target,
        "on_track":         goal.current_week_count >= goal.weekly_interview_target
                            if goal.weekly_interview_target > 0 else True,
    }


async def _create_roadmap_for_goal(goal: Goal, db: Session) -> Optional[int]:
    """
    Generate and persist a roadmap for a goal.
    Returns the new roadmap_id or None on failure.
    Works whether RoadmapAIService.generate_roadmap is sync OR async,
    and whether it takes (target_role, difficulty) or just (target_role).
    """
    try:
        import inspect, asyncio
        difficulty  = getattr(goal, "difficulty", None) or "intermediate"
        target_role = goal.target_role

        gen_fn = getattr(_roadmap_ai, "generate_roadmap", None)
        if gen_fn is None:
            raise AttributeError("RoadmapAIService has no generate_roadmap method")

        roadmap_data = None

        # Build call attempts: kwargs with difficulty, kwargs without, positional
        attempts = [
            {"target_role": target_role, "difficulty": difficulty},
            {"target_role": target_role},
            (target_role,),
        ]

        for attempt in attempts:
            try:
                if isinstance(attempt, dict):
                    result = gen_fn(**attempt)
                else:
                    result = gen_fn(*attempt)

                # Handle if the function returned a coroutine (is actually async)
                if inspect.isawaitable(result):
                    result = await result

                if result and isinstance(result, dict):
                    roadmap_data = result
                    break
            except TypeError:
                continue

        if not roadmap_data:
            raise ValueError(
                f"generate_roadmap returned no data for '{target_role}'"
            )
        from app.models.roadmap import Roadmap as RoadmapModel, RoadmapStage, RoadmapTask

        roadmap = RoadmapModel(
            user_id         = goal.user_id,
            goal_id         = goal.id,
            title           = roadmap_data.get("title", f"Path to {goal.target_role}"),
            description     = roadmap_data.get("description", ""),
            target_role     = goal.target_role,
            difficulty      = getattr(goal, "difficulty", "intermediate"),
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
                difficulty      = stage_data.get("difficulty", "intermediate"),
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
        db.commit()
        return roadmap.id

    except Exception as e:
        logger.error(f"_create_roadmap_for_goal failed for goal {goal.id}: {e}")
        db.rollback()
        return None


# ═══════════════════════════════════════════════════════════════════
# ROUTES
# ═══════════════════════════════════════════════════════════════════

@router.get("/")
def list_goals(
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goals = db.query(Goal).filter(Goal.user_id == current_user.id)\
               .order_by(Goal.created_at.desc()).all()
    return [g.to_dict() for g in goals]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_goal(
    req:          GoalCreate,
    db:           Session    = Depends(get_db),
    current_user: User       = Depends(get_current_user),
):
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
    db.flush()

    if req.auto_generate_roadmap:
        await _create_roadmap_for_goal(goal, db)

    db.commit()
    db.refresh(goal)
    return goal.to_dict()


@router.get("/{goal_id}")
def get_goal(
    goal_id:      int,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    return _get_goal(goal_id, current_user.id, db).to_dict()


@router.put("/{goal_id}")
def update_goal(
    goal_id:      int,
    req:          GoalUpdate,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
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


@router.delete("/{goal_id}", status_code=204)
def delete_goal(
    goal_id:      int,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goal = _get_goal(goal_id, current_user.id, db)
    db.delete(goal)
    db.commit()


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


@router.get("/{goal_id}/progress")
def get_progress(
    goal_id:      int,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goal     = _get_goal(goal_id, current_user.id, db)
    progress = _build_progress(goal, db)
    return {**goal.to_dict(), "progress": progress}


@router.post("/{goal_id}/coach-tip")
def refresh_coach_tip(
    goal_id:      int,
    language:     str     = "en",
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    goal     = _get_goal(goal_id, current_user.id, db)
    progress = _build_progress(goal, db)

    radar_dimensions = None
    if goal.resume_id:
        resume = db.query(Resume).filter(Resume.id == goal.resume_id).first()
        if resume and resume.analysis_feedback:
            radar_dimensions = resume.analysis_feedback.get("dimensions")

    tip = generate_coach_tip(
        target_role        = goal.target_role,
        language           = language,
        recent_scores      = progress["recent_scores"],
        radar_dimensions   = radar_dimensions,
        interviews_done    = progress["interviews_done"],
        weekly_target      = goal.weekly_interview_target,
        current_week_count = goal.current_week_count,
        roadmap_progress   = progress["roadmap_progress"],
    )
    goal.coach_tip            = tip
    goal.coach_tip_updated_at = datetime.utcnow()
    db.commit()
    return {"coach_tip": tip}


# ── NEW: Auto-generate roadmap for an existing goal ───────────────
@router.post("/{goal_id}/generate-roadmap", status_code=status.HTTP_201_CREATED)
async def generate_roadmap_for_goal(
    goal_id:      int,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    """
    Auto-generate a roadmap for an existing goal.
    Called from the frontend when user taps "Add Roadmap" inside goal detail
    — no setup screen needed.
    """
    goal = _get_goal(goal_id, current_user.id, db)

    if goal.roadmap_id:
        # Roadmap already exists — just return it
        roadmap = db.query(Roadmap).filter(Roadmap.id == goal.roadmap_id).first()
        return {
            "success":    True,
            "roadmap_id": goal.roadmap_id,
            "message":    "Roadmap already exists",
            "roadmap":    roadmap.to_dict() if roadmap else None,
        }

    roadmap_id = await _create_roadmap_for_goal(goal, db)
    if not roadmap_id:
        raise HTTPException(
            status_code=500,
            detail=(
                f"Failed to generate roadmap for '{goal.target_role}'. "
                "The AI service may be temporarily unavailable. Please try again."
            ),
        )

    roadmap = db.query(Roadmap).filter(Roadmap.id == roadmap_id).first()
    return {
        "success":    True,
        "roadmap_id": roadmap_id,
        "message":    f"Roadmap created for {goal.target_role}",
        "roadmap":    roadmap.to_dict() if roadmap else None,
    }


# ── NEW: Link existing resume to goal ────────────────────────────
@router.post("/{goal_id}/link-resume")
def link_resume_to_goal(
    goal_id:      int,
    req:          LinkResumeRequest,
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    """
    Link an uploaded resume to this goal.
    Called after file upload completes from goal detail page.
    """
    goal = _get_goal(goal_id, current_user.id, db)

    # Verify resume belongs to this user
    resume = db.query(Resume).filter(
        Resume.id      == req.resume_id,
        Resume.user_id == current_user.id,
    ).first()
    if not resume:
        raise HTTPException(status_code=404, detail="Resume not found")

    goal.resume_id = req.resume_id
    db.commit()
    db.refresh(goal)
    return {"success": True, "goal": goal.to_dict()}


# ── NEW: Next step toward goal ────────────────────────────────────
@router.get("/{goal_id}/next-step")
def get_next_step(
    goal_id:      int,
    language:     str     = "en",
    db:           Session = Depends(get_db),
    current_user: User    = Depends(get_current_user),
):
    """
    Returns a personalized "next step" for the user toward their goal.
    Considers: roadmap stage, weekly interview count, score trend, resume status.
    """
    goal     = _get_goal(goal_id, current_user.id, db)
    progress = _build_progress(goal, db)
    is_ar    = language == "ar"

    steps = []
    priority_action = None

    # ── Check 1: weekly interview target ─────────────────────────
    week_done   = progress["this_week_done"]
    week_target = progress["this_week_target"]
    remaining   = max(0, week_target - week_done)

    if remaining > 0:
        if is_ar:
            priority_action = {
                "type":        "interview",
                "icon":        "🎯",
                "title":       f"أجرِ {remaining} مقابلة هذا الأسبوع",
                "description": f"أنجزت {week_done} من {week_target} — واصل التقدم!",
                "action":      "start_interview",
                "goal_id":     goal_id,
                "urgent":      True,
            }
        else:
            priority_action = {
                "type":        "interview",
                "icon":        "🎯",
                "title":       f"Do {remaining} more interview{'s' if remaining > 1 else ''} this week",
                "description": f"{week_done}/{week_target} done this week — keep going!",
                "action":      "start_interview",
                "goal_id":     goal_id,
                "urgent":      True,
            }
    else:
        if is_ar:
            steps.append({
                "type":        "done_this_week",
                "icon":        "✅",
                "title":       "أتممت هدفك الأسبوعي!",
                "description": f"{week_done}/{week_target} مقابلات مكتملة هذا الأسبوع",
                "action":      None,
                "urgent":      False,
            })
        else:
            steps.append({
                "type":        "done_this_week",
                "icon":        "✅",
                "title":       "Weekly goal complete!",
                "description": f"{week_done}/{week_target} interviews done this week",
                "action":      None,
                "urgent":      False,
            })

    # ── Check 2: roadmap next task ────────────────────────────────
    roadmap_step = None
    if goal.roadmap_id:
        roadmap = db.query(Roadmap).filter(Roadmap.id == goal.roadmap_id).first()
        if roadmap:
            # Find current unlocked, incomplete stage
            from app.models.roadmap import RoadmapStage, RoadmapTask
            current_stage = (
                db.query(RoadmapStage)
                .filter(
                    RoadmapStage.roadmap_id == roadmap.id,
                    RoadmapStage.is_unlocked == True,
                )
                .order_by(RoadmapStage.order.asc())
                .first()
            )
            if current_stage and not current_stage.is_completed:
                # Find next incomplete task in this stage
                next_task = (
                    db.query(RoadmapTask)
                    .filter(
                        RoadmapTask.stage_id    == current_stage.id,
                        RoadmapTask.is_completed == False,
                    )
                    .order_by(RoadmapTask.order.asc())
                    .first()
                )
                if next_task:
                    if is_ar:
                        roadmap_step = {
                            "type":        "roadmap_task",
                            "icon":        "📚",
                            "title":       f"أكمل: {next_task.title}",
                            "description": f"المرحلة {current_stage.order}: {current_stage.title}",
                            "action":      "open_roadmap",
                            "roadmap_id":  roadmap.id,
                            "urgent":      False,
                        }
                    else:
                        roadmap_step = {
                            "type":        "roadmap_task",
                            "icon":        "📚",
                            "title":       f"Complete: {next_task.title}",
                            "description": f"Stage {current_stage.order}: {current_stage.title}",
                            "action":      "open_roadmap",
                            "roadmap_id":  roadmap.id,
                            "urgent":      False,
                        }
    else:
        if is_ar:
            roadmap_step = {
                "type":        "create_roadmap",
                "icon":        "🗺️",
                "title":       "أنشئ خارطة تعلمك",
                "description": f"خارطة مخصصة لدور {goal.target_role}",
                "action":      "generate_roadmap",
                "goal_id":     goal_id,
                "urgent":      False,
            }
        else:
            roadmap_step = {
                "type":        "create_roadmap",
                "icon":        "🗺️",
                "title":       "Create your learning roadmap",
                "description": f"A personalized path to {goal.target_role}",
                "action":      "generate_roadmap",
                "goal_id":     goal_id,
                "urgent":      False,
            }

    if roadmap_step:
        steps.append(roadmap_step)

    # ── Check 3: resume ───────────────────────────────────────────
    if not goal.resume_id:
        if is_ar:
            steps.append({
                "type":        "add_resume",
                "icon":        "📄",
                "title":       "أضف سيرتك الذاتية",
                "description": "تحليل السيرة الذاتية يُحسّن جودة المقابلات",
                "action":      "upload_resume",
                "goal_id":     goal_id,
                "urgent":      False,
            })
        else:
            steps.append({
                "type":        "add_resume",
                "icon":        "📄",
                "title":       "Upload your resume",
                "description": "Resume analysis improves interview question targeting",
                "action":      "upload_resume",
                "goal_id":     goal_id,
                "urgent":      False,
            })

    # ── Check 4: score trend advice ───────────────────────────────
    recent = progress.get("recent_scores", [])
    if len(recent) >= 2:
        trend_diff = recent[0] - recent[-1]   # recent[0] = latest
        if trend_diff < -5:
            tip_text = (
                "أداؤك في تراجع — ركّز على نقاط الضعف وراجع الإجابات السابقة"
                if is_ar else
                "Your scores are declining — review your past feedback and focus on weak areas"
            )
            steps.append({
                "type":        "score_tip",
                "icon":        "📉",
                "title":       "نصيحة الأداء" if is_ar else "Performance tip",
                "description": tip_text,
                "action":      "view_history",
                "urgent":      False,
            })
        elif trend_diff > 5:
            steps.append({
                "type":        "score_tip",
                "icon":        "📈",
                "title":       "أداؤك يتحسن! 🚀" if is_ar else "You're improving! 🚀",
                "description": (f"ارتفع متوسطك {abs(trend_diff):.0f} نقطة — واصل!"
                                if is_ar else
                                f"Up {abs(trend_diff):.0f}pts — keep the momentum!"),
                "action":      None,
                "urgent":      False,
            })

    # ── Weeks remaining warning ───────────────────────────────────
    weeks_left = progress.get("weeks_remaining")
    if weeks_left is not None and weeks_left <= 2 and goal.is_active:
        steps.append({
            "type":        "deadline_warning",
            "icon":        "⏰",
            "title":       f"{'أسبوعان' if weeks_left == 2 else 'أسبوع'} {'متبقيان' if weeks_left == 2 else 'متبقٍ'}!" if is_ar
                           else f"Only {weeks_left} week{'s' if weeks_left > 1 else ''} left!",
            "description": "قرّب إيقاع مقابلاتك" if is_ar
                           else "Increase your interview frequency now",
            "action":      "start_interview",
            "goal_id":     goal_id,
            "urgent":      True,
        })

    return {
        "goal_id":         goal_id,
        "priority_action": priority_action,
        "steps":           steps,
        "progress_summary": {
            "interviews_done":  progress["interviews_done"],
            "avg_score":        progress["avg_score"],
            "this_week_done":   week_done,
            "this_week_target": week_target,
            "roadmap_progress": progress["roadmap_progress"],
            "on_track":         progress["on_track"],
        },
    }


# ── Internal helper ───────────────────────────────────────────────
def increment_goal_week_count(goal_id: int, db: Session):
    goal = db.query(Goal).filter(Goal.id == goal_id).first()
    if not goal or not goal.is_active:
        return
    _reset_week_if_needed(goal, db)
    goal.current_week_count += 1
    db.commit()