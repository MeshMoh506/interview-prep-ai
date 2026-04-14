# app/models/user.py
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, Float
from sqlalchemy.orm import relationship
from app.database import Base
import datetime


class User(Base):
    __tablename__ = "users"

    id              = Column(Integer, primary_key=True, index=True)
    email           = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name       = Column(String(255))
    is_active       = Column(Boolean, default=True)
    is_verified     = Column(Boolean, default=False)   # FIX: was missing, used in google_auth
    created_at      = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at      = Column(DateTime, default=datetime.datetime.utcnow,
                             onupdate=datetime.datetime.utcnow)

    # ── Profile Fields ───────────────────────────────────────────────
    bio                = Column(Text, nullable=True)
    location           = Column(String(255), nullable=True)
    phone              = Column(String(50), nullable=True)
    linkedin_url       = Column(String(500), nullable=True)
    github_url         = Column(String(500), nullable=True)
    portfolio_url      = Column(String(500), nullable=True)
    avatar_url         = Column(String(500), nullable=True)
    preferred_language = Column(String(10), default='en')
    job_title          = Column(String(255), nullable=True)

    # ── Preferences ──────────────────────────────────────────────────
    email_notifications = Column(Boolean, default=True)
    interview_reminders = Column(Boolean, default=True)

    # ── Stats ─────────────────────────────────────────────────────────
    total_interviews = Column(Integer, default=0)
    avg_score        = Column(Float, nullable=True)
    best_score       = Column(Float, nullable=True)

    # ── AI Memory Profile ─────────────────────────────────────────────
    # Living text report: "Strong in X, weak in Y, improving in Z"
    # AI reads this before every session and updates it after.
    # Format: JSON string or plain text — updated by background tasks.
    ai_profile = Column(Text, nullable=True)

    # ── Relationships ─────────────────────────────────────────────────
    # FIX: removed duplicate goals relationship (was defined twice → mapper error)
    resumes    = relationship("Resume",    back_populates="user", cascade="all, delete-orphan")
    interviews = relationship("Interview", back_populates="user", cascade="all, delete-orphan")
    roadmaps   = relationship("Roadmap",   back_populates="user", cascade="all, delete-orphan")
    goals      = relationship("Goal",      back_populates="user", cascade="all, delete-orphan")
    practice_sessions  = relationship("PracticeSession",  back_populates="user", cascade="all, delete-orphan")
    practice_bookmarks = relationship("PracticeBookmark", back_populates="user", cascade="all, delete-orphan")