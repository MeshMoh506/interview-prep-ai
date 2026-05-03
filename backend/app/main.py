# app/main.py
import os
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ── Rate limiting ─────────────────────────────────────────────────
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from app.routers import coach
# ── Sentry (optional — only if SENTRY_DSN env var is set) ────────
SENTRY_DSN = os.getenv("SENTRY_DSN", "")
if SENTRY_DSN:
    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
        sentry_sdk.init(
            dsn=SENTRY_DSN,
            environment=os.getenv("ENVIRONMENT", "development"),
            traces_sample_rate=0.1,
            integrations=[FastApiIntegration(), SqlalchemyIntegration()],
        )
        logging.getLogger(__name__).info("✅ Sentry initialized")
    except ImportError:
        logging.getLogger(__name__).warning(
            "sentry-sdk not installed — pip install sentry-sdk")

# ── Routers ───────────────────────────────────────────────────────
from app.routers.goals import router as goals_router
from app.routers import auth, users, resumes
from app.routers.interviews import router as interviews_router
from app.routers.roadmaps import router as roadmaps_router
from app.routers.audio import router as audio_router
from app.routers.dashboard import router as dashboard_router
from app.routers.behavior import router as behavior_router
from backend.app.routers.coach import router as practice_router

# ── DB / Models ───────────────────────────────────────────────────
from app.database import engine, Base
from app.models import (                    # noqa: F401
    User, Resume, Interview,
    Roadmap, RoadmapStage, RoadmapTask,
    Goal,
    PracticeSession, PracticeBookmark,
)

Base.metadata.create_all(bind=engine)

# ══════════════════════════════════════════════════════════════════
# Rate limiter — 200 req/min default, tighter limits on AI routes
# Set REDIS_URL env var in production for distributed rate limiting
# Falls back to in-memory if Redis not configured
# ══════════════════════════════════════════════════════════════════
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["200/minute"],
    storage_uri=os.getenv("REDIS_URL", "memory://"),
)

# ══════════════════════════════════════════════════════════════════
# APP
# ══════════════════════════════════════════════════════════════════
app = FastAPI(
    title="Interview Prep AI API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# ── CORS ──────────────────────────────────────────────────────────
# Production: set ALLOWED_ORIGINS=https://katwah.app,https://www.katwah.app
# Dev: defaults to * (allow all)
_raw = os.getenv("ALLOWED_ORIGINS", "")
ALLOWED_ORIGINS = (
    [o.strip() for o in _raw.split(",") if o.strip()]
    if _raw else ["*"]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(resumes.router)
app.include_router(interviews_router)
app.include_router(roadmaps_router)
app.include_router(audio_router)
app.include_router(dashboard_router)
app.include_router(goals_router)
app.include_router(behavior_router)
app.include_router(practice_router)
app.include_router(coach.router)

# ══════════════════════════════════════════════════════════════════
# ROUTES
# ══════════════════════════════════════════════════════════════════
@app.get("/")
def root():
    return {
        "message": "Interview Prep AI API",
        "version": "1.0.0",
        "docs":    "/docs",
    }


@app.api_route("/health", methods=["GET", "HEAD"])
def health():
    """UptimeRobot pings this every 5 minutes — supports GET and HEAD."""
    return {
        "status":      "healthy",
        "environment": os.getenv("ENVIRONMENT", "development"),
    }