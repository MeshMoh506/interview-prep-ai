# app/routers/audio.py
# Dedicated audio router — clean separation of voice concerns from interview logic.
# Adapted from your friend's pattern, extended with:
#   - language hint support
#   - TTS language-aware voice selection
#   - proper error handling

from fastapi import APIRouter, File, UploadFile, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from io import BytesIO

from app.routers.auth import get_current_user
from app.models.user import User
from app.services.stt import transcribe_audio
from app.services.tts import synthesize_question_audio
from app.config import settings

router = APIRouter(prefix="/api/v1/audio", tags=["audio"])


# ── POST /transcribe ──────────────────────────────────────────────
@router.post("/transcribe")
async def transcribe(
    audio:        UploadFile = File(...),
    language:     str        = Query(default="en", description="ISO-639-1 hint: 'en' or 'ar'"),
    current_user: User       = Depends(get_current_user),
):
    """
    Transcribe an audio file to text.

    - Accepts: webm, wav, mp3, mp4, m4a, ogg
    - Default backend: Groq whisper-large-v3
    - Alt backend: OpenAI whisper-1 (set STT_BACKEND=openai in .env)
    - Pass language='ar' for better Arabic accuracy

    Returns: { "transcript": "..." }
    """
    if not audio.content_type or "audio" not in audio.content_type:
        raise HTTPException(
            status_code=400,
            detail="Please upload an audio file (webm, wav, mp3, mp4, m4a)",
        )

    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio file is empty")

    try:
        text = transcribe_audio(
            audio_bytes,
            filename=audio.filename or "audio.webm",
            language=language if language in ("ar", "en") else None,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Transcription failed: {str(e)}",
        )

    if not text.strip():
        raise HTTPException(
            status_code=422,
            detail="Could not detect speech. Please try again in a quieter environment.",
        )

    return {"transcript": text.strip(), "language": language, "backend": settings.STT_BACKEND}


# ── GET /prompt-audio ─────────────────────────────────────────────
@router.get(
    "/prompt-audio",
    responses={200: {"content": {"audio/mpeg": {}}}},
    summary="Convert interviewer question to speech (MP3)",
)
def prompt_audio(
    text:         str  = Query(...,          description="Text to speak aloud"),
    language:     str  = Query(default="en", description="'en' or 'ar' — selects voice"),
    current_user: User = Depends(get_current_user),
):
    """
    Text-to-speech for AI interviewer questions.

    - English → voice: echo (clear, professional)
    - Arabic  → voice: shimmer (calm, warm, Arabic-capable)
    - Returns audio/mpeg (MP3) stream

    Frontend usage:
        GET /api/v1/audio/prompt-audio?text=Tell+me+about+yourself&language=en
    """
    if settings.TTS_BACKEND == "none":
        raise HTTPException(
            status_code=501,
            detail="TTS is disabled. Set TTS_BACKEND=openai in .env to enable.",
        )

    if not text.strip():
        raise HTTPException(status_code=400, detail="text cannot be empty")

    # Limit length to avoid abuse / runaway costs
    if len(text) > 1000:
        raise HTTPException(
            status_code=400,
            detail="Text too long. Maximum 1000 characters per request.",
        )

    try:
        audio_bytes = synthesize_question_audio(text, language=language)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS failed: {str(e)}")

    return StreamingResponse(
        BytesIO(audio_bytes),
        media_type="audio/mpeg",
        headers={"Content-Disposition": "inline; filename=question.mp3"},
    )