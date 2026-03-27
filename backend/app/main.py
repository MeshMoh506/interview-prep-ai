# app/main.py — updated to include behavior router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers.goals import router as goals_router
from app.routers import auth, users, resumes
from app.routers.interviews import router as interviews_router
from app.routers.roadmaps import router as roadmaps_router
from app.routers.audio import router as audio_router
from app.routers.dashboard import router as dashboard_router
from app.routers.behavior import router as behavior_router          # ← NEW

from app.database import engine, Base
from app.models import user, resume, interview, roadmap

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Interview Prep AI API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(resumes.router)
app.include_router(interviews_router)
app.include_router(roadmaps_router)
app.include_router(audio_router)
app.include_router(dashboard_router)
app.include_router(goals_router)
app.include_router(behavior_router)                                  # ← NEW

@app.get("/")
def root():
    return {"message": "Interview Prep AI API", "version": "1.0.0", "docs": "/docs"}

@app.get("/health")
def health():
    return {"status": "healthy"}