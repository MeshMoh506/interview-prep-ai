# app/routers/roadmaps.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel
from app.database import get_db
from app.models.user import User
from app.models.roadmap import Roadmap, RoadmapStage, RoadmapTask
from app.models.resume import Resume
from app.routers.auth import get_current_user
from app.services.roadmap_ai_service import RoadmapAIService

router = APIRouter(prefix="/api/v1/roadmaps", tags=["roadmaps"])
ai_service = RoadmapAIService()


# ── Schemas ───────────────────────────────────────────────────────────────────

class ResourceSchema(BaseModel):
    title: str
    url: str
    type: str  # "video", "article", "course", "docs"
    description: Optional[str] = None


class TimeLogSchema(BaseModel):
    minutes: int


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_roadmap(roadmap_id: int, user_id: int, db: Session) -> Roadmap:
    r = db.query(Roadmap).filter(
        Roadmap.id == roadmap_id,
        Roadmap.user_id == user_id
    ).first()
    if not r:
        raise HTTPException(404, "Roadmap not found")
    return r


def _get_task(roadmap_id: int, task_id: int, user_id: int, db: Session) -> RoadmapTask:
    task = db.query(RoadmapTask).join(RoadmapStage).filter(
        RoadmapTask.id == task_id,
        RoadmapStage.roadmap_id == roadmap_id,
    ).first()
    if not task:
        raise HTTPException(404, "Task not found")
    # Verify ownership
    _get_roadmap(roadmap_id, user_id, db)
    return task


def _recalc_progress(roadmap: Roadmap, db: Session):
    """Recompute overall_progress and stage progress from task completion."""
    total_tasks = 0
    completed_tasks = 0

    for stage in roadmap.stages:
        stage_total = len(stage.tasks)
        stage_done = sum(1 for t in stage.tasks if t.is_completed)

        if stage_total > 0:
            stage.progress = round((stage_done / stage_total) * 100, 1)
            stage.is_completed = stage_done == stage_total
        else:
            stage.progress = 0.0

        total_tasks += stage_total
        completed_tasks += stage_done

    if total_tasks > 0:
        roadmap.overall_progress = round((completed_tasks / total_tasks) * 100, 1)

    if roadmap.overall_progress >= 100 and not roadmap.completed_at:
        roadmap.completed_at = datetime.utcnow()

    db.commit()


# ── Core Routes ───────────────────────────────────────────────────────────────

@router.get("/")
def get_roadmaps(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    roadmaps = db.query(Roadmap).filter(Roadmap.user_id == current_user.id).all()
    return [r.to_dict() for r in roadmaps]


@router.get("/{roadmap_id}")
def get_roadmap(
    roadmap_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _get_roadmap(roadmap_id, current_user.id, db).to_dict()


@router.post("/generate")
async def generate_roadmap(
    target_role: str,
    difficulty: str = "intermediate",
    resume_id: Optional[int] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    resume_text = None
    if resume_id:
        resume = db.query(Resume).filter(
            Resume.id == resume_id,
            Resume.user_id == current_user.id
        ).first()
        if resume and resume.parsed_data:
            resume_text = str(resume.parsed_data)

    roadmap_data = await ai_service.generate_roadmap(
        target_role=target_role,
        difficulty=difficulty,
        resume_text=resume_text,
    )

    roadmap = Roadmap(
        user_id=current_user.id,
        title=roadmap_data["title"],
        description=roadmap_data.get("description", ""),
        target_role=target_role,
        difficulty=difficulty,
        estimated_weeks=roadmap_data.get("estimated_weeks", 8),
        is_ai_generated=True,
        category=roadmap_data.get("category", "technology"),
        tags=roadmap_data.get("tags", []),
    )
    db.add(roadmap)
    db.flush()

    for i, stage_data in enumerate(roadmap_data.get("stages", [])):
        stage = RoadmapStage(
            roadmap_id=roadmap.id,
            order=i + 1,
            title=stage_data["title"],
            description=stage_data.get("description", ""),
            color=stage_data.get("color", "#8B5CF6"),
            icon=stage_data.get("icon", "📚"),
            estimated_hours=stage_data.get("estimated_hours", 10),
            difficulty=stage_data.get("difficulty", difficulty),
            is_unlocked=(i == 0),
        )
        db.add(stage)
        db.flush()

        for j, task_data in enumerate(stage_data.get("tasks", [])):
            task = RoadmapTask(
                stage_id=stage.id,
                order=j + 1,
                title=task_data["title"],
                description=task_data.get("description", ""),
                estimated_hours=task_data.get("estimated_hours", 2),
                resources=task_data.get("resources", []),
            )
            db.add(task)

    db.commit()
    db.refresh(roadmap)
    return roadmap.to_dict()


@router.post("/{roadmap_id}/tasks/{task_id}/complete")
def complete_task(
    roadmap_id: int,
    task_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = _get_task(roadmap_id, task_id, current_user.id, db)
    roadmap = _get_roadmap(roadmap_id, current_user.id, db)

    task.is_completed = not task.is_completed
    task.completed_at = datetime.utcnow() if task.is_completed else None

    # Unlock next stage if current stage completed
    for stage in roadmap.stages:
        if task in stage.tasks:
            all_done = all(t.is_completed for t in stage.tasks)
            if all_done:
                # Unlock next stage
                next_stage = db.query(RoadmapStage).filter(
                    RoadmapStage.roadmap_id == roadmap_id,
                    RoadmapStage.order == stage.order + 1
                ).first()
                if next_stage:
                    next_stage.is_unlocked = True

    _recalc_progress(roadmap, db)
    db.refresh(roadmap)
    return roadmap.to_dict()


@router.delete("/{roadmap_id}")
def delete_roadmap(
    roadmap_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    roadmap = _get_roadmap(roadmap_id, current_user.id, db)
    db.delete(roadmap)
    db.commit()
    return {"message": "Deleted"}


# ── Resources ─────────────────────────────────────────────────────────────────

@router.get("/{roadmap_id}/tasks/{task_id}/resources")
def get_task_resources(
    roadmap_id: int,
    task_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = _get_task(roadmap_id, task_id, current_user.id, db)
    return {"resources": task.resources or []}


@router.post("/{roadmap_id}/tasks/{task_id}/resources")
def add_task_resource(
    roadmap_id: int,
    task_id: int,
    resource: ResourceSchema,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = _get_task(roadmap_id, task_id, current_user.id, db)
    current = list(task.resources or [])
    current.append(resource.model_dump())
    task.resources = current
    db.commit()
    return {"resources": task.resources}


# ── Time Logging ──────────────────────────────────────────────────────────────

@router.put("/{roadmap_id}/tasks/{task_id}/time-log")
def log_study_time(
    roadmap_id: int,
    task_id: int,
    data: TimeLogSchema,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    task = _get_task(roadmap_id, task_id, current_user.id, db)
    # Store time in resources as a special entry or in a separate field
    # We'll use a simple approach: store logged_minutes on the task resources JSON
    resources = list(task.resources or [])
    # Find existing time log entry or create one
    time_entry = next((r for r in resources if r.get('type') == '_time_log'), None)
    if time_entry:
        time_entry['minutes'] = time_entry.get('minutes', 0) + data.minutes
    else:
        resources.append({'type': '_time_log', 'minutes': data.minutes})
    task.resources = resources
    db.commit()
    return {"logged_minutes": data.minutes, "task_id": task_id}


# ── Analytics ─────────────────────────────────────────────────────────────────

@router.get("/{roadmap_id}/analytics")
def get_roadmap_analytics(
    roadmap_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    roadmap = _get_roadmap(roadmap_id, current_user.id, db)

    total_tasks = 0
    completed_tasks = 0
    total_est_hours = 0
    total_logged_minutes = 0
    stage_stats = []

    for stage in roadmap.stages:
        s_total = len(stage.tasks)
        s_done = sum(1 for t in stage.tasks if t.is_completed)
        s_hours = sum(t.estimated_hours or 0 for t in stage.tasks)

        # Sum logged time
        for task in stage.tasks:
            for r in (task.resources or []):
                if r.get('type') == '_time_log':
                    total_logged_minutes += r.get('minutes', 0)

        stage_stats.append({
            "stage_id": stage.id,
            "title": stage.title,
            "total_tasks": s_total,
            "completed_tasks": s_done,
            "progress": stage.progress,
            "estimated_hours": s_hours,
            "color": stage.color,
        })

        total_tasks += s_total
        completed_tasks += s_done
        total_est_hours += s_hours

    return {
        "roadmap_id": roadmap_id,
        "title": roadmap.title,
        "overall_progress": roadmap.overall_progress,
        "total_tasks": total_tasks,
        "completed_tasks": completed_tasks,
        "remaining_tasks": total_tasks - completed_tasks,
        "total_estimated_hours": total_est_hours,
        "total_logged_minutes": total_logged_minutes,
        "total_logged_hours": round(total_logged_minutes / 60, 1),
        "stages": stage_stats,
        "created_at": roadmap.created_at.isoformat() if roadmap.created_at else None,
        "completed_at": roadmap.completed_at.isoformat() if roadmap.completed_at else None,
    }