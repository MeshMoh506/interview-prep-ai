# app/models/cover_letter.py
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Float, JSON
from sqlalchemy.orm import relationship
from app.database import Base
import datetime


class CoverLetter(Base):
    __tablename__ = "cover_letters"

    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    resume_id   = Column(Integer, ForeignKey("resumes.id", ondelete="SET NULL"), nullable=True)

    # ── Job details ──────────────────────────────────────────────
    job_title       = Column(String(255), nullable=False)
    company_name    = Column(String(255), nullable=True)
    job_description = Column(Text, nullable=True)

    # ── Generation settings ──────────────────────────────────────
    tone            = Column(String(50), default="professional")
    # professional | enthusiastic | concise | creative
    language        = Column(String(10), default="en")

    # ── Output ───────────────────────────────────────────────────
    content         = Column(Text, nullable=True)   # Generated letter
    word_count      = Column(Integer, nullable=True)
    match_score     = Column(Float, nullable=True)  # 0-100 match with JD

    # ── Timestamps ───────────────────────────────────────────────
    created_at  = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at  = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # ── Relationships ─────────────────────────────────────────────
    user   = relationship("User",   foreign_keys=[user_id])
    resume = relationship("Resume", foreign_keys=[resume_id])

    def to_dict(self) -> dict:
        return {
            "id":               self.id,
            "user_id":          self.user_id,
            "resume_id":        self.resume_id,
            "job_title":        self.job_title,
            "company_name":     self.company_name,
            "job_description":  self.job_description,
            "tone":             self.tone,
            "language":         self.language,
            "content":          self.content,
            "word_count":       self.word_count,
            "match_score":      self.match_score,
            "created_at":       self.created_at.isoformat() if self.created_at else None,
            "updated_at":       self.updated_at.isoformat() if self.updated_at else None,
        }