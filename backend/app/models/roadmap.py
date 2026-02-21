# app/models/roadmap.py - FINAL FIXED VERSION (Ambiguous FK resolved)
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, JSON, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base


class Roadmap(Base):
    __tablename__ = "roadmaps"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    target_role = Column(String(255))
    difficulty = Column(String(50))
    estimated_weeks = Column(Integer)
    
    # Metadata
    is_ai_generated = Column(Boolean, default=False)
    is_public = Column(Boolean, default=False)
    category = Column(String(100))
    tags = Column(JSON)
    
    # Progress
    overall_progress = Column(Float, default=0.0)
    current_stage_id = Column(Integer, nullable=True)  # REMOVED ForeignKey - this was causing the ambiguity!
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    
    # Relationships - FIXED with foreign_keys parameter
    user = relationship("User", back_populates="roadmaps")
    stages = relationship(
        "RoadmapStage", 
        back_populates="roadmap", 
        cascade="all, delete-orphan", 
        order_by="RoadmapStage.order",
        foreign_keys="RoadmapStage.roadmap_id"  # Explicitly specify which FK to use
    )
    
    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "title": self.title,
            "description": self.description,
            "target_role": self.target_role,
            "difficulty": self.difficulty,
            "estimated_weeks": self.estimated_weeks,
            "is_ai_generated": self.is_ai_generated,
            "is_public": self.is_public,
            "category": self.category,
            "tags": self.tags,
            "overall_progress": self.overall_progress,
            "current_stage_id": self.current_stage_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "stages": [stage.to_dict() for stage in self.stages] if self.stages else [],
        }


class RoadmapStage(Base):
    __tablename__ = "roadmap_stages"
    
    id = Column(Integer, primary_key=True, index=True)
    roadmap_id = Column(Integer, ForeignKey("roadmaps.id"), nullable=False)
    order = Column(Integer, nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    
    # Visual
    color = Column(String(7), default="#8B5CF6")
    icon = Column(String(50))
    
    # Progress
    progress = Column(Float, default=0.0)
    is_unlocked = Column(Boolean, default=False)
    is_completed = Column(Boolean, default=False)
    
    # Metadata
    estimated_hours = Column(Integer)
    difficulty = Column(String(50))
    
    # Timestamps
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    
    # Relationships
    roadmap = relationship("Roadmap", back_populates="stages")
    tasks = relationship("RoadmapTask", back_populates="stage", cascade="all, delete-orphan", order_by="RoadmapTask.order")
    
    def to_dict(self):
        return {
            "id": self.id,
            "roadmap_id": self.roadmap_id,
            "order": self.order,
            "title": self.title,
            "description": self.description,
            "color": self.color,
            "icon": self.icon,
            "progress": self.progress,
            "is_unlocked": self.is_unlocked,
            "is_completed": self.is_completed,
            "estimated_hours": self.estimated_hours,
            "difficulty": self.difficulty,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "tasks": [t.to_dict() for t in self.tasks] if self.tasks else [],
        }


class RoadmapTask(Base):
    __tablename__ = "roadmap_tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    stage_id = Column(Integer, ForeignKey("roadmap_stages.id"), nullable=False)
    order = Column(Integer, nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    
    # Task properties
    is_completed = Column(Boolean, default=False)
    estimated_hours = Column(Integer)
    
    # Resources
    resources = Column(JSON)
    
    # Timestamps
    completed_at = Column(DateTime, nullable=True)
    
    # Relationships
    stage = relationship("RoadmapStage", back_populates="tasks")
    
    def to_dict(self):
        return {
            "id": self.id,
            "stage_id": self.stage_id,
            "order": self.order,
            "title": self.title,
            "description": self.description,
            "is_completed": self.is_completed,
            "estimated_hours": self.estimated_hours,
            "resources": self.resources,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }