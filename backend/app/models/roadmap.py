# app/models/roadmap.py
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Text, JSON, Boolean
from sqlalchemy.orm import relationship
from app.database import Base
import datetime


class Roadmap(Base):
    __tablename__ = "roadmaps"

    id             = Column(Integer, primary_key=True, index=True)
    user_id        = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    title          = Column(String(255))
    target_role    = Column(String(255))
    current_role   = Column(String(255), nullable=True)
    current_skills = Column(JSON, default=list)   # list of skill strings
    target_skills  = Column(JSON, default=list)   # list of skill strings
    missing_skills = Column(JSON, default=list)
    language       = Column(String(10), default="en")
    status         = Column(String(50), default="active")   # active / completed / paused
    overall_progress = Column(Float, default=0.0)           # 0-100
    streak_days    = Column(Integer, default=0)
    last_activity  = Column(DateTime, nullable=True)
    created_at     = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at     = Column(DateTime, default=datetime.datetime.utcnow,
                            onupdate=datetime.datetime.utcnow)

    user       = relationship("User", back_populates="roadmaps")
    milestones = relationship("Milestone", back_populates="roadmap",
                              cascade="all, delete-orphan", order_by="Milestone.order_index")
    goals      = relationship("DailyGoal", back_populates="roadmap",
                              cascade="all, delete-orphan")


class Milestone(Base):
    __tablename__ = "milestones"

    id           = Column(Integer, primary_key=True, index=True)
    roadmap_id   = Column(Integer, ForeignKey("roadmaps.id", ondelete="CASCADE"))
    title        = Column(String(255))
    description  = Column(Text, nullable=True)
    skill_focus  = Column(String(255))         # main skill being learned
    order_index  = Column(Integer, default=0)
    status       = Column(String(50), default="not_started")  # not_started / in_progress / completed
    difficulty   = Column(String(50), default="medium")
    est_hours    = Column(Integer, default=10)  # estimated hours to complete
    progress     = Column(Float, default=0.0)   # 0-100
    completed_at = Column(DateTime, nullable=True)
    created_at   = Column(DateTime, default=datetime.datetime.utcnow)

    roadmap   = relationship("Roadmap", back_populates="milestones")
    resources = relationship("LearningResource", back_populates="milestone",
                             cascade="all, delete-orphan")


class LearningResource(Base):
    __tablename__ = "learning_resources"

    id           = Column(Integer, primary_key=True, index=True)
    milestone_id = Column(Integer, ForeignKey("milestones.id", ondelete="CASCADE"))
    title        = Column(String(255))
    url          = Column(String(500), nullable=True)
    resource_type = Column(String(50))   # video / course / article / book / practice
    platform     = Column(String(100), nullable=True)   # YouTube / Coursera / etc
    is_free      = Column(Boolean, default=True)
    est_hours    = Column(Integer, default=2)
    difficulty   = Column(String(50), default="beginner")
    is_completed = Column(Boolean, default=False)
    created_at   = Column(DateTime, default=datetime.datetime.utcnow)

    milestone = relationship("Milestone", back_populates="resources")


class DailyGoal(Base):
    __tablename__ = "daily_goals"

    id         = Column(Integer, primary_key=True, index=True)
    roadmap_id = Column(Integer, ForeignKey("roadmaps.id", ondelete="CASCADE"))
    user_id    = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    title      = Column(String(255))
    target_minutes = Column(Integer, default=30)
    is_completed   = Column(Boolean, default=False)
    date           = Column(DateTime, default=datetime.datetime.utcnow)

    roadmap = relationship("Roadmap", back_populates="goals")