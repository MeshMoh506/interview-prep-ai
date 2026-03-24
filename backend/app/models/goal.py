# app/models/goal.py
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, JSON, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base


class Goal(Base):
    __tablename__ = "goals"

    id                      = Column(Integer, primary_key=True, index=True)
    user_id                 = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # ── Core definition ────────────────────────────────────────────
    title                   = Column(String(255), nullable=False)        # "Land a Senior Flutter Dev job"
    target_role             = Column(String(255), nullable=False)        # "Senior Flutter Developer"
    target_company          = Column(String(255), nullable=True)         # optional
    deadline                = Column(DateTime,    nullable=True)         # target date

    # ── Status ─────────────────────────────────────────────────────
    status                  = Column(String(50),  default="active")
    # active | achieved | paused | abandoned

    # ── Weekly interview schedule ──────────────────────────────────
    weekly_interview_target = Column(Integer,     default=3)            # e.g. 3 sessions/week
    current_week_count      = Column(Integer,     default=0)            # auto-updated on interview completion
    current_week_start      = Column(DateTime,    nullable=True)        # start of current tracking week

    # ── Linked resources ───────────────────────────────────────────
    roadmap_id              = Column(Integer, ForeignKey("roadmaps.id", ondelete="SET NULL"), nullable=True)
    resume_id               = Column(Integer, ForeignKey("resumes.id",  ondelete="SET NULL"), nullable=True)

    # ── AI coach cache ─────────────────────────────────────────────
    coach_tip               = Column(Text,        nullable=True)        # latest AI tip (cached)
    coach_tip_updated_at    = Column(DateTime,    nullable=True)

    # ── Timestamps ─────────────────────────────────────────────────
    created_at              = Column(DateTime, default=datetime.utcnow)
    updated_at              = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    achieved_at             = Column(DateTime, nullable=True)

    # ── Relationships ──────────────────────────────────────────────
    user        = relationship("User",    back_populates="goals")
    roadmap     = relationship("Roadmap", foreign_keys=[roadmap_id])
    resume      = relationship("Resume",  foreign_keys=[resume_id])
    interviews  = relationship("Interview", back_populates="goal",
                               cascade="all, delete-orphan",
                               foreign_keys="Interview.goal_id")

    # ── Helpers ────────────────────────────────────────────────────
    @property
    def weeks_remaining(self) -> int | None:
        if not self.deadline:
            return None
        delta = self.deadline - datetime.utcnow()
        weeks = delta.days // 7
        return max(0, weeks)

    @property
    def is_active(self) -> bool:
        return self.status == "active"

    def to_dict(self) -> dict:
        return {
            "id":                       self.id,
            "user_id":                  self.user_id,
            "title":                    self.title,
            "target_role":              self.target_role,
            "target_company":           self.target_company,
            "deadline":                 self.deadline.isoformat() if self.deadline else None,
            "status":                   self.status,
            "weekly_interview_target":  self.weekly_interview_target,
            "current_week_count":       self.current_week_count,
            "roadmap_id":               self.roadmap_id,
            "resume_id":                self.resume_id,
            "coach_tip":                self.coach_tip,
            "weeks_remaining":          self.weeks_remaining,
            "created_at":               self.created_at.isoformat() if self.created_at else None,
            "achieved_at":              self.achieved_at.isoformat() if self.achieved_at else None,
        }