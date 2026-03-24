# app/models/interview.py
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Text, JSON, Boolean
from sqlalchemy.orm import relationship
from app.database import Base
import datetime


class Interview(Base):
    __tablename__ = "interviews"

    id               = Column(Integer, primary_key=True, index=True)
    user_id          = Column(Integer, ForeignKey("users.id",    ondelete="CASCADE"))
    resume_id        = Column(Integer, ForeignKey("resumes.id",  ondelete="SET NULL"), nullable=True)

    # ── Goal link (NEW) ────────────────────────────────────────────
    goal_id          = Column(Integer, ForeignKey("goals.id", ondelete="SET NULL"), nullable=True)

    # ── Session configuration ──────────────────────────────────────
    job_role         = Column(String(255))
    difficulty       = Column(String(50),  default="medium")
    interview_type   = Column(String(50),  default="mixed")
    language         = Column(String(10),  default="en")
    job_description  = Column(Text,        nullable=True)

    # ── Voice / TTS flags ─────────────────────────────────────────
    voice_used       = Column(Boolean, default=False)
    tts_used         = Column(Boolean, default=False)

    # ── State ──────────────────────────────────────────────────────
    status           = Column(String(50), default="in_progress")
    message_count    = Column(Integer,  default=0)
    user_msg_count   = Column(Integer,  default=0)

    # ── Scoring ────────────────────────────────────────────────────
    score            = Column(Float,    nullable=True)
    feedback         = Column(JSON,     nullable=True)

    # ── Timestamps ────────────────────────────────────────────────
    created_at       = Column(DateTime, default=datetime.datetime.utcnow)
    started_at       = Column(DateTime, default=datetime.datetime.utcnow)
    completed_at     = Column(DateTime, nullable=True)
    duration_minutes = Column(Integer,  nullable=True)

    # ── Relationships ─────────────────────────────────────────────
    user     = relationship("User",             back_populates="interviews")
    messages = relationship("InterviewMessage", back_populates="interview",
                            cascade="all, delete-orphan",
                            order_by="InterviewMessage.id")
    goal     = relationship("Goal", back_populates="interviews",
                            foreign_keys=[goal_id])

    @property
    def is_complete(self) -> bool:
        return self.status == "completed"

    @property
    def duration_seconds(self) -> int | None:
        if self.started_at and self.completed_at:
            return int((self.completed_at - self.started_at).total_seconds())
        return None


class InterviewMessage(Base):
    __tablename__ = "interview_messages"

    id           = Column(Integer, primary_key=True, index=True)
    interview_id = Column(Integer, ForeignKey("interviews.id", ondelete="CASCADE"))

    role         = Column(String(20))
    content      = Column(Text)
    timestamp    = Column(DateTime, default=datetime.datetime.utcnow)

    is_voice            = Column(Boolean, default=False)
    transcript_language = Column(String(10), nullable=True)
    evaluation          = Column(JSON, nullable=True)

    interview    = relationship("Interview", back_populates="messages")