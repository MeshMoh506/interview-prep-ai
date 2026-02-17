# app/config.py  (app/core/config.py if you use that layout)
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
from pathlib import Path


class Settings(BaseSettings):
    # ── Database ──────────────────────────────────────────────────
    DATABASE_URL: str = "postgresql://user:password@localhost:5432/interview_prep"

    # ── Auth ──────────────────────────────────────────────────────
    SECRET_KEY: str    = "dev-secret-key-change-in-production"
    ALGORITHM:  str    = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # ── AI keys ───────────────────────────────────────────────────
    # Groq — used for: llama-3.3-70b (chat) + whisper-large-v3 (STT)
    # Free tier at https://console.groq.com
    GROQ_API_KEY: Optional[str] = None

    # OpenAI — used for: whisper-1 (STT alt) + TTS (gpt-4o-mini-tts)
    # Only needed if USE_OPENAI_VOICE = True
    OPENAI_API_KEY: Optional[str] = None

    # ── Voice routing ─────────────────────────────────────────────
    # "groq"   → whisper-large-v3 via Groq  (default, free, best Arabic)
    # "openai" → whisper-1 via OpenAI       (your friend's implementation)
    STT_BACKEND: str = "groq"

    # "openai" → gpt-4o-mini-tts  (high quality)
    # "none"   → TTS disabled
    TTS_BACKEND: str = "openai"

    # ── Legacy (unused, kept for backward compat) ─────────────────
    HUGGINGFACE_TOKEN: Optional[str] = None

    # ── File uploads ──────────────────────────────────────────────
    UPLOAD_DIR:         Path = Path("uploads/resumes")
    MAX_FILE_SIZE:      int  = 5 * 1024 * 1024     # 5 MB
    ALLOWED_EXTENSIONS: set  = {".pdf", ".docx"}

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()

# Ensure upload directory exists at startup
settings.UPLOAD_DIR.mkdir(parents=True, exist_ok=True)