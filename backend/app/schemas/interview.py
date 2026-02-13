from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

class InterviewCreate(BaseModel):
    job_role:        str = Field(..., min_length=2, max_length=255)
    difficulty:      str = Field("medium", pattern="^(easy|medium|hard)$")
    interview_type:  str = Field("mixed",  pattern="^(behavioral|technical|mixed)$")
    language:        str = Field("en",     pattern="^(en|ar)$")
    resume_id:       Optional[int] = None
    job_description: Optional[str] = Field(None, max_length=5000)

class SendMessage(BaseModel):
    content: str = Field(..., min_length=1, max_length=5000)

class MessageResponse(BaseModel):
    id:         int
    role:       str
    content:    str
    timestamp:  datetime
    evaluation: Optional[Dict[str, Any]] = None
    class Config:
        from_attributes = True

class InterviewResponse(BaseModel):
    id:               int
    user_id:          int
    job_role:         str
    difficulty:       str
    interview_type:   str
    status:           str
    language:         Optional[str] = "en"
    score:            Optional[float] = None
    feedback:         Optional[Dict[str, Any]] = None
    created_at:       datetime
    started_at:       Optional[datetime] = None
    completed_at:     Optional[datetime] = None
    duration_minutes: Optional[int] = None
    class Config:
        from_attributes = True

class InterviewDetailResponse(InterviewResponse):
    messages: List[MessageResponse] = []
    class Config:
        from_attributes = True

class InterviewListResponse(BaseModel):
    id:               int
    job_role:         str
    difficulty:       str
    interview_type:   str
    status:           str
    language:         Optional[str] = "en"
    score:            Optional[float] = None
    created_at:       datetime
    duration_minutes: Optional[int] = None
    class Config:
        from_attributes = True

class AIReplyResponse(BaseModel):
    user_message:     MessageResponse
    ai_message:       MessageResponse
    evaluation:       Optional[Dict[str, Any]] = None
    interview_status: str

class VoiceTranscriptResponse(BaseModel):
    transcript:       str
    user_message:     MessageResponse
    ai_message:       MessageResponse
    evaluation:       Optional[Dict[str, Any]] = None
    interview_status: str
