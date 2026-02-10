from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List, Dict, Any

# Request Schemas
class ResumeCreate(BaseModel):
    """Schema for creating a resume (just title, file comes separately)"""
    title: str = Field(..., min_length=1, max_length=255, description="Resume title")

class ResumeUpdate(BaseModel):
    """Schema for updating resume metadata"""
    title: Optional[str] = Field(None, min_length=1, max_length=255)

# Response Schemas
class ResumeListResponse(BaseModel):
    """Minimal resume info for list view"""
    id: int
    title: str
    file_type: str
    file_size: Optional[int]
    is_parsed: int
    is_analyzed: int
    created_at: datetime
    
    class Config:
        from_attributes = True

class ResumeResponse(BaseModel):
    """Complete resume data"""
    id: int
    user_id: int
    title: str
    file_path: str
    file_type: str
    file_size: Optional[int]
    parsed_content: Optional[str]
    contact_info: Optional[Dict[str, Any]]
    education: Optional[List[Dict[str, Any]]]
    experience: Optional[List[Dict[str, Any]]]
    skills: Optional[List[Dict[str, Any]]]
    analysis_score: Optional[float]
    analysis_feedback: Optional[Dict[str, Any]]
    ats_score: Optional[float]
    is_parsed: int
    is_analyzed: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class ResumeAnalysisResponse(BaseModel):
    """Resume analysis results"""
    resume_id: int
    analysis_score: float
    ats_score: float
    feedback: Dict[str, Any]
    
    class Config:
        from_attributes = True
