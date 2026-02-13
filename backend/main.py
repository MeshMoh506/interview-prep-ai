from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, users, resumes, interviews
from app.database import engine, Base

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Interview Prep AI API",
    description="AI-powered interview preparation and resume optimization",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
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
app.include_router(interviews.router)

@app.get("/")
def root():
    return {
        "message": "Welcome to Interview Prep AI API",
        "version": "2.0.0",
        "docs": "/docs",
        "endpoints": {
            "auth":       "/api/v1/auth",
            "users":      "/api/v1/users",
            "resumes":    "/api/v1/resumes",
            "interviews": "/api/v1/interviews"
        }
    }

@app.get("/health")
def health():
    return {"status": "healthy", "features": ["auth", "resumes", "interviews"]}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
