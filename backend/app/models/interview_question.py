# app/models/interview_question.py
from sqlalchemy import Column, Integer, String, Text, JSON, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.database import Base
import datetime


class InterviewQuestion(Base):
    """Community-driven question bank for interviews"""
    __tablename__ = "interview_questions"

    id = Column(Integer, primary_key=True, index=True)
    
    # Question content
    question = Column(Text, nullable=False)
    category = Column(String(50))  # behavioral, technical, mixed
    difficulty = Column(String(20))  # easy, medium, hard
    job_role = Column(String(255))  # software_engineer, product_manager, etc
    
    # Question metadata
    follow_ups = Column(JSON)  # ["What would you do differently?", ...]
    tips = Column(Text)  # What interviewers look for
    sample_answer = Column(Text, nullable=True)  # Example good answer
    
    # Community features
    is_community = Column(Boolean, default=False)  # User-submitted?
    submitted_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    upvotes = Column(Integer, default=0)
    downvotes = Column(Integer, default=0)
    
    # Tags for filtering
    tags = Column(JSON)  # ["STAR", "leadership", "conflict-resolution"]
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, 
                        onupdate=datetime.datetime.utcnow)
    
    # Relationships
    submitter = relationship("User", foreign_keys=[submitted_by])
    
    def to_dict(self):
        return {
            "id": self.id,
            "question": self.question,
            "category": self.category,
            "difficulty": self.difficulty,
            "job_role": self.job_role,
            "follow_ups": self.follow_ups or [],
            "tips": self.tips,
            "sample_answer": self.sample_answer,
            "is_community": self.is_community,
            "upvotes": self.upvotes,
            "downvotes": self.downvotes,
            "tags": self.tags or [],
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
