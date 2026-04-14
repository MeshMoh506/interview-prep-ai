# app/models/practice.py
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.database import Base


class PracticeSession(Base):
    __tablename__ = "practice_sessions"

    id            = Column(Integer, primary_key=True, index=True)
    user_id       = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # ── Session metadata ────────────────────────────────────────────
    mode          = Column(String(32), nullable=False, default="qa")
    # qa | taskPractice | rolePlay
    mode_context  = Column(Text, nullable=True)
    # e.g. "Google — Senior Flutter Engineer" for rolePlay
    # or "State management with Riverpod" for taskPractice

    # ── Content ─────────────────────────────────────────────────────
    messages_json = Column(Text, nullable=False, default="[]")
    # Full conversation stored as JSON string (list of message objects)
    title         = Column(Text, nullable=True)
    # Auto-generated from first user message, max ~50 chars

    # ── Timestamps ──────────────────────────────────────────────────
    started_at    = Column(DateTime, default=datetime.utcnow)
    ended_at      = Column(DateTime, nullable=True)

    # ── Relationship ─────────────────────────────────────────────────
    user          = relationship("User", back_populates="practice_sessions")

    # ── Helpers ──────────────────────────────────────────────────────
    @property
    def message_count(self) -> int:
        import json
        try:
            return len(json.loads(self.messages_json or "[]"))
        except Exception:
            return 0

    def to_dict(self) -> dict:
        import json
        try:
            messages = json.loads(self.messages_json or "[]")
        except Exception:
            messages = []
        return {
            "id":           self.id,
            "user_id":      self.user_id,
            "mode":         self.mode,
            "mode_context": self.mode_context,
            "messages":     messages,
            "title":        self.title,
            "started_at":   self.started_at.isoformat() if self.started_at else None,
            "ended_at":     self.ended_at.isoformat() if self.ended_at else None,
        }


class PracticeBookmark(Base):
    __tablename__ = "practice_bookmarks"

    id       = Column(Integer, primary_key=True, index=True)
    user_id  = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # ── Content ──────────────────────────────────────────────────────
    question = Column(Text, nullable=False)
    answer   = Column(Text, nullable=False)
    mode     = Column(String(32), nullable=False, default="qa")

    # ── Timestamps ───────────────────────────────────────────────────
    saved_at = Column(DateTime, default=datetime.utcnow)

    # ── Relationship ─────────────────────────────────────────────────
    user     = relationship("User", back_populates="practice_bookmarks")

    def to_dict(self) -> dict:
        return {
            "id":       self.id,
            "user_id":  self.user_id,
            "question": self.question,
            "answer":   self.answer,
            "mode":     self.mode,
            "saved_at": self.saved_at.isoformat() if self.saved_at else None,
        }