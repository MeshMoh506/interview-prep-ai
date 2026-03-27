# app/routers/behavior.py
# FIXED: prefix changed to /api/v1/behavior so it matches what the frontend sends
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from app.routers.auth import get_current_user
from app.models.user import User
from app.services.behavior_analysis_service import (
    analyze_video_frame,
    analyze_voice_tone,
    aggregate_behavior_session,
)
from app.services.coach_tips_service import generate_coach_tips

router = APIRouter(prefix="/api/v1/behavior", tags=["behavior"])   # ← FIXED prefix


class FrameRequest(BaseModel):
    frame_base64: str = Field(...)
    mime_type: str    = Field("image/jpeg")

class VoiceAnalysisRequest(BaseModel):
    transcription: str = Field(...)

@router.post("/analyze-frame")
async def analyze_frame_endpoint(
    req: FrameRequest,
    current_user: User = Depends(get_current_user),
):
    if not req.frame_base64:
        raise HTTPException(400, "frame_base64 required")
    result = await analyze_video_frame(req.frame_base64, req.mime_type)
    return result or {
        "face_confidence": 50, "face_nervousness": 50, "face_engagement": 50,
        "hands_nervousness": 50, "posture_score": 50,
        "dominant_emotion": "unknown", "face_visible": False,
        "hands_visible": False, "brief_note": "Analysis unavailable",
    }


@router.post("/analyze-voice")
async def analyze_voice_endpoint(
    req: VoiceAnalysisRequest,
    current_user: User = Depends(get_current_user),
):
    if not req.transcription.strip():
        raise HTTPException(400, "transcription required")
    result = await analyze_voice_tone(req.transcription)
    return result or {
        "voice_confidence": 50, "voice_clarity": 50, "voice_pace_score": 50,
        "filler_word_count": 0, "pace_assessment": "appropriate",
        "key_filler_words": [], "voice_note": "Analysis unavailable",
    }


class SessionSummaryRequest(BaseModel):
    video_frames:    list[dict] = Field(default_factory=list)
    voice_analyses:  list[dict] = Field(default_factory=list)
    interview_score: float      = Field(50.0, ge=0, le=100)
    answer_count:    int        = Field(0)
    language:        str        = Field("en")
    job_role:        str        = Field("")     # ← for coach tips
    goal_context:    str        = Field("")     # ← for goal-aware tips


@router.post("/session-summary")
async def session_summary_endpoint(
    req: SessionSummaryRequest,
    current_user: User = Depends(get_current_user),
):
    # 1. Aggregate behavior scores
    report = aggregate_behavior_session(
        video_frames=req.video_frames,
        voice_analyses=req.voice_analyses,
        interview_score=req.interview_score,
        answer_count=req.answer_count,
        language=req.language,
    )

    # 2. Generate personalized coach tips from the behavior data
    try:
        coach_tips = generate_coach_tips(
            behavior_report=report,
            job_role=req.job_role or "professional",
            language=req.language,
            goal_context=req.goal_context,
        )
        report["coach_tips"] = coach_tips
    except Exception as e:
        print(f"[CoachTips] skipped: {e}")
        report["coach_tips"] = []

    return report


@router.post("/coach-tips")
async def get_coach_tips(
    behavior_report: dict,
    job_role:        str = "",
    language:        str = "en",
    goal_context:    str = "",
    current_user:    User = Depends(get_current_user),
):
    """Standalone endpoint — regenerate coach tips for an existing behavior report."""
    tips = generate_coach_tips(
        behavior_report=behavior_report,
        job_role=job_role or "professional",
        language=language,
        goal_context=goal_context,
    )
    return {"coach_tips": tips}