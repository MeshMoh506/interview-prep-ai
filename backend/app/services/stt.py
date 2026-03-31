# app/services/stt.py
# Speech-to-text service — supports two backends:
#   "groq"   → whisper-large-v3 (free, best Arabic, default)
#   "openai" → whisper-1        (your friend's implementation)
# Switch via STT_BACKEND in .env

from app.config import settings


def transcribe_audio(

    audio_bytes: bytes,
    filename:    str = "audio.webm",
    language:    str | None = None,
) -> str:
    """
    Transcribe audio bytes to text.

    Args:
        audio_bytes: Raw audio data (webm, wav, mp3, mp4, m4a supported)
        filename:    Original filename — tells the codec which container to expect
        language:    ISO-639-1 hint ("ar", "en"). None = auto-detect.

    Returns:
        Transcribed text string.
    """
    if filename and filename.lower().endswith('.aac'):
            filename = filename[:-4] + '.m4a'

    backend = settings.STT_BACKEND.lower()

    if backend == "openai":
        return _transcribe_openai(audio_bytes, filename, language)
    else:
        return _transcribe_groq(audio_bytes, filename, language)


# ── Groq backend (whisper-large-v3) ──────────────────────────────
def _transcribe_groq(audio_bytes: bytes, filename: str, language: str | None) -> str:
    """
    Uses Groq's hosted whisper-large-v3.
    - Free tier: 7,200 audio-seconds / hour
    - Best Arabic support of any hosted Whisper endpoint
    """
    import io
    from groq import Groq

    if not settings.GROQ_API_KEY:
        raise RuntimeError("GROQ_API_KEY is not set in .env")

    client = Groq(api_key=settings.GROQ_API_KEY)

    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename   # Groq needs the name attribute to detect codec

    kwargs: dict = {}
    if language in ("ar", "en"):
        kwargs["language"] = language

    resp = client.audio.transcriptions.create(
        model="whisper-large-v3",
        file=audio_file,
        response_format="text",
        **kwargs,
    )
    # response_format="text" → returns a plain string
    return resp if isinstance(resp, str) else resp.text


# ── OpenAI backend (whisper-1) ────────────────────────────────────
def _transcribe_openai(audio_bytes: bytes, filename: str, language: str | None) -> str:
    """
    Your friend's implementation — uses openai.audio.transcriptions (whisper-1).
    Requires OPENAI_API_KEY in .env.
    """
    from openai import OpenAI

    if not settings.OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY is not set in .env")

    client = OpenAI(api_key=settings.OPENAI_API_KEY)

    kwargs: dict = {}
    if language in ("ar", "en"):
        kwargs["language"] = language

    resp = client.audio.transcriptions.create(
        model="whisper-1",
        file=(filename, audio_bytes),
        **kwargs,
    )
    return resp.text