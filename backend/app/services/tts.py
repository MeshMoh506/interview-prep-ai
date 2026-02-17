# app/services/tts.py
import logging
from app.config import settings

logger = logging.getLogger(__name__)


def synthesize_question_audio(text: str, language: str = "en") -> bytes:
    backend = settings.TTS_BACKEND.split("#")[0].strip().lower()
    logger.info(f"TTS backend='{backend}' language='{language}' text_len={len(text)}")

    if backend == "openai":
        return _synthesize_openai(text, language)
    else:
        raise RuntimeError(
            f"TTS_BACKEND='{backend}' is not 'openai'. "
            "Check your .env file — set TTS_BACKEND=openai"
        )


def _synthesize_openai(text: str, language: str) -> bytes:
    from openai import OpenAI

    key = settings.OPENAI_API_KEY
    logger.info(f"OpenAI key present: {bool(key)}, starts with: {str(key)[:8] if key else 'MISSING'}")

    if not key:
        raise RuntimeError("OPENAI_API_KEY is not set in .env")

    client = OpenAI(api_key=key)
    voice  = "shimmer" if language == "ar" else "echo"

    logger.info(f"Calling OpenAI TTS: model=gpt-4o-mini-tts voice={voice}")

    response = client.audio.speech.create(
        model="gpt-4o-mini-tts",
        voice=voice,
        input=text,
        response_format="mp3",
    )

    logger.info(f"TTS success, bytes={len(response.content)}")
    return response.content