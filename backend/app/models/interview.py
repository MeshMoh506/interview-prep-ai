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

    # ── Session configuration ──────────────────────────────────────
    job_role         = Column(String(255))
    difficulty       = Column(String(50),  default="medium")   # easy | medium | hard
    interview_type   = Column(String(50),  default="mixed")    # behavioral | technical | mixed
    language         = Column(String(10),  default="en")       # en | ar
    job_description  = Column(Text,        nullable=True)

    # ── Voice / TTS flags ─────────────────────────────────────────
    # Did the user speak at least one voice message in this session?
    voice_used       = Column(Boolean, default=False)
    # Was AI text-to-speech playback used in this session?
    tts_used         = Column(Boolean, default=False)

    # ── State ──────────────────────────────────────────────────────
    status           = Column(String(50), default="in_progress")
    # in_progress | completed | abandoned
    message_count    = Column(Integer,  default=0)   # total messages (user + ai)
    user_msg_count   = Column(Integer,  default=0)   # user messages only (for auto-end)

    # ── Scoring ────────────────────────────────────────────────────
    score            = Column(Float,    nullable=True)   # 0-100 overall
    feedback         = Column(JSON,     nullable=True)   # structured final report

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

    # ── Computed helpers (not DB columns) ─────────────────────────
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

    role         = Column(String(20))   # user | assistant
    content      = Column(Text)
    timestamp    = Column(DateTime, default=datetime.datetime.utcnow)

    # ── Voice metadata ────────────────────────────────────────────
    # Was this message transcribed from audio?
    is_voice     = Column(Boolean, default=False)
    # Raw transcript confidence / detected language from Whisper (optional, useful for debug)
    transcript_language = Column(String(10), nullable=True)

    # ── Per-message evaluation (from AI) ──────────────────────────
    evaluation   = Column(JSON, nullable=True)
    # {score: 1-10, strengths: [...], improvements: [...], tip: "..."}

    interview    = relationship("Interview", back_populates="messages")