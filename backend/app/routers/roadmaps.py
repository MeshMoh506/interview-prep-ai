# app/routers/roadmaps.py - FIXED VERSION
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from app.database import get_db
from app.models.user import User
from app.models.roadmap import Roadmap, RoadmapStage, RoadmapTask
from app.models.resume import Resume
from app.services.roadmap_ai_service import RoadmapAIService
from app.routers.auth import get_current_user

router = APIRouter(prefix="/roadmaps", tags=["roadmaps"])


# ══════════════════════════════════════════════════════════════════════════
# GET /roadmaps - List all user roadmaps
# ══════════════════════════════════════════════════════════════════════════

@router.get("/")
def get_roadmaps(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all roadmaps for current user"""
    roadmaps = db.query(Roadmap).filter(
        Roadmap.user_id == current_user.id
    ).order_by(Roadmap.created_at.desc()).all()
    
    return [r.to_dict() for r in roadmaps]


# ══════════════════════════════════════════════════════════════════════════
# GET /roadmaps/{id} - Get single roadmap with full details
# ══════════════════════════════════════════════════════════════════════════

@router.get("/{roadmap_id}")
def get_roadmap(
    roadmap_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get roadmap details"""
    roadmap = db.query(Roadmap).filter(
        Roadmap.id == roadmap_id,
        Roadmap.user_id == current_user.id
    ).first()
    
    if not roadmap:
        raise HTTPException(status_code=404, detail="Roadmap not found")
    
    return roadmap.to_dict()


# ══════════════════════════════════════════════════════════════════════════
# POST /roadmaps/generate - AI Generate Roadmap
# ══════════════════════════════════════════════════════════════════════════

@router.post("/generate")
def generate_roadmap(
    target_role: str,
    difficulty: str = "intermediate",
    resume_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate AI-powered roadmap"""
    
    # Get resume context if provided
    resume_context = None
    if resume_id:
        resume = db.query(Resume).filter(
            Resume.id == resume_id,
            Resume.user_id == current_user.id
        ).first()
        
        if resume and resume.parsed_content:
            try:
                import json
                resume_context = json.loads(resume.parsed_content) if isinstance(resume.parsed_content, str) else resume.parsed_content
            except:
                pass
    
    # Generate roadmap with AI
    ai_service = RoadmapAIService()
    roadmap_data = ai_service.generate_roadmap(
        target_role=target_role,
        current_resume=resume_context,
        difficulty=difficulty
    )
    
    # Create roadmap in database
    roadmap = Roadmap(
        user_id=current_user.id,
        title=roadmap_data.get("title", f"Path to {target_role}"),
        description=roadmap_data.get("description", ""),
        target_role=target_role,
        difficulty=difficulty,
        estimated_weeks=roadmap_data.get("estimated_weeks", 12),
        is_ai_generated=True,
        category=roadmap_data.get("category", "Technology"),
        tags=roadmap_data.get("tags", []),
        overall_progress=0.0,
    )
    db.add(roadmap)
    db.flush()
    
    # Create stages
    for stage_data in roadmap_data.get("stages", []):
        stage = RoadmapStage(
            roadmap_id=roadmap.id,
            order=stage_data.get("order", 1),
            title=stage_data.get("title", "Stage"),
            description=stage_data.get("description", ""),
            color=stage_data.get("color", "#8B5CF6"),
            icon=stage_data.get("icon", "📍"),
            estimated_hours=stage_data.get("estimated_hours", 40),
            difficulty=stage_data.get("difficulty", "medium"),
            is_unlocked=(stage_data.get("order") == 1),  # Unlock first stage
            progress=0.0,
        )
        db.add(stage)
        db.flush()
        
        # Create tasks (was milestones)
        for task_data in stage_data.get("tasks", []):
            task = RoadmapTask(
                stage_id=stage.id,
                order=task_data.get("order", 1),
                title=task_data.get("title", "Task"),
                description=task_data.get("description", ""),
                estimated_hours=task_data.get("estimated_hours", 8),
                resources=task_data.get("resources", []),
                is_completed=False,
            )
            db.add(task)
    
    # Set current stage to first stage
    first_stage = db.query(RoadmapStage).filter(
        RoadmapStage.roadmap_id == roadmap.id,
        RoadmapStage.order == 1
    ).first()
    if first_stage:
        roadmap.current_stage_id = first_stage.id
    
    db.commit()
    db.refresh(roadmap)
    
    return roadmap.to_dict()


# ══════════════════════════════════════════════════════════════════════════
# POST /roadmaps/{id}/tasks/{task_id}/complete - Mark task complete
# ══════════════════════════════════════════════════════════════════════════

@router.post("/{roadmap_id}/tasks/{task_id}/complete")
def complete_task(
    roadmap_id: int,
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark task as complete and update progress"""
    
    # Verify roadmap ownership
    roadmap = db.query(Roadmap).filter(
        Roadmap.id == roadmap_id,
        Roadmap.user_id == current_user.id
    ).first()
    
    if not roadmap:
        raise HTTPException(status_code=404, detail="Roadmap not found")
    
    # Get task
    task = db.query(RoadmapTask).filter(
        RoadmapTask.id == task_id
    ).first()
    
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Mark complete
    task.is_completed = True
    task.completed_at = datetime.utcnow()
    
    # Recalculate stage progress
    stage = task.stage
    total_tasks = len(stage.tasks)
    completed_tasks = sum(1 for t in stage.tasks if t.is_completed)
    stage.progress = (completed_tasks / total_tasks * 100) if total_tasks > 0 else 0
    
    # Check if stage is complete
    if stage.progress >= 100:
        stage.is_completed = True
        stage.completed_at = datetime.utcnow()
        
        # Unlock next stage
        next_stage = db.query(RoadmapStage).filter(
            RoadmapStage.roadmap_id == roadmap_id,
            RoadmapStage.order == stage.order + 1
        ).first()
        if next_stage:
            next_stage.is_unlocked = True
            roadmap.current_stage_id = next_stage.id
    
    # Recalculate overall progress
    total_stages = len(roadmap.stages)
    completed_stages = sum(1 for s in roadmap.stages if s.is_completed)
    roadmap.overall_progress = (completed_stages / total_stages * 100) if total_stages > 0 else 0
    
    # Check if roadmap complete
    if roadmap.overall_progress >= 100:
        roadmap.completed_at = datetime.utcnow()
    
    db.commit()
    
    return {
        "success": True,
        "stage_progress": stage.progress,
        "overall_progress": roadmap.overall_progress,
        "stage_completed": stage.is_completed,
        "roadmap_completed": roadmap.completed_at is not None,
    }


# ══════════════════════════════════════════════════════════════════════════
# DELETE /roadmaps/{id} - Delete roadmap
# ══════════════════════════════════════════════════════════════════════════

@router.delete("/{roadmap_id}")
def delete_roadmap(
    roadmap_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete roadmap"""
    roadmap = db.query(Roadmap).filter(
        Roadmap.id == roadmap_id,
        Roadmap.user_id == current_user.id
    ).first()
    
    if not roadmap:
        raise HTTPException(status_code=404, detail="Roadmap not found")
    
    db.delete(roadmap)
    db.commit()
    
    return {"success": True, "message": "Roadmap deleted"}