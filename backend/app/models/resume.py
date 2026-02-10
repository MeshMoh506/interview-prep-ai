from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Float, JSON
from sqlalchemy.orm import relationship
from app.database import Base
import datetime

class Resume(Base):
    """Resume model for storing uploaded resumes and parsed data"""
    __tablename__ = "resumes"
    
    # Primary Key
    id = Column(Integer, primary_key=True, index=True) # index for faster lookups
    
    # Foreign Key to User
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # File Information
    title = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)
    file_type = Column(String(10), nullable=False)  # pdf, docx
    file_size = Column(Integer)  # in bytes
    
    # Add these columns after 'skills':
    certifications = Column(JSON)  # Certifications/courses
    projects = Column(JSON)        # Projects

    # Parsed Content
    parsed_content = Column(Text)  # Raw text extracted from file
    
    # Structured Data (JSON)
    contact_info = Column(JSON)  # {email, phone, linkedin, github}
    education = Column(JSON)     # [{degree, school, year, gpa}]
    experience = Column(JSON)    # [{title, company, duration, description}]
    skills = Column(JSON)        # [{name, category, proficiency}]
    
    # AI Analysis Results
    analysis_score = Column(Float)  # Overall score 0-10
    analysis_feedback = Column(JSON)  # {strengths, weaknesses, suggestions} 
    ats_score = Column(Float)  # ATS compatibility score 0-10
    
    # Status
    is_parsed = Column(Integer, default=0)  # 0=not parsed, 1=parsed
    is_analyzed = Column(Integer, default=0)  # 0=not analyzed, 1=analyzed
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
    
    # Relationship to User 
    user = relationship("User", back_populates="resumes")
    
    def __repr__(self):
        return f"<Resume(id={self.id}, title={self.title}, user_id={self.user_id})>"
