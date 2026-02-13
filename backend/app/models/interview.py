from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Text, JSON
from sqlalchemy.orm import relationship
from app.database import Base
import datetime


class Interview(Base):
    __tablename__ = "interviews"

    id               = Column(Integer, primary_key=True, index=True)
    user_id          = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    job_role         = Column(String(255))
    difficulty       = Column(String(50), default="medium")
    interview_type   = Column(String(50), default="mixed")
    language         = Column(String(10), default="en")
    job_description  = Column(Text, nullable=True)
    resume_id        = Column(Integer, ForeignKey("resumes.id", ondelete="SET NULL"), nullable=True)
    status           = Column(String(50), default="in_progress")
    score            = Column(Float, nullable=True)
    feedback         = Column(JSON, nullable=True)
    created_at       = Column(DateTime, default=datetime.datetime.utcnow)
    started_at       = Column(DateTime, default=datetime.datetime.utcnow)
    completed_at     = Column(DateTime, nullable=True)
    duration_minutes = Column(Integer, nullable=True)

    user     = relationship("User", back_populates="interviews")
    messages = relationship("InterviewMessage", back_populates="interview",
                            cascade="all, delete-orphan",
                            order_by="InterviewMessage.id")


class InterviewMessage(Base):
    __tablename__ = "interview_messages"

    id           = Column(Integer, primary_key=True, index=True)
    interview_id = Column(Integer, ForeignKey("interviews.id", ondelete="CASCADE"))
    role         = Column(String(20))
    content      = Column(Text)
    timestamp    = Column(DateTime, default=datetime.datetime.utcnow)
    evaluation   = Column(JSON, nullable=True)

    interview = relationship("Interview", back_populates="messages")