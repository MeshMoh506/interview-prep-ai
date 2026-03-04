# backend/app/routers/resumes.py - COMPLETE WITH POWER FEATURES
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
import os
from fastapi.responses import StreamingResponse
import io
from fastapi.responses import StreamingResponse
from app.services.pdf_resume_generator import PDFResumeGenerator

from app.database import get_db
from app.models.user import User
from app.models.resume import Resume
from app.schemas.resume import (
    ResumeCreate,
    ResumeUpdate,
    ResumeListResponse,
    ResumeResponse
)
from app.routers.auth import get_current_user
from app.services.resume_parser import ResumeParser as ResumeParserService
from app.services.ai_resume_parser import AIResumeParser as AIResumeParserService
from app.services.ai_analysis_service import AIAnalysisService
from app.services.job_matcher_service import JobMatcherService
from app.services.achievement_rewriter_service import AchievementRewriterService
from app.services.format_checker_service import FormatCheckerService
from app.services.resume_template_service import ResumeTemplateService
from app.services.resume_power_service import ResumePowerService   # ← NEW

router = APIRouter(prefix="/api/v1/resumes", tags=["resumes"])

# ── Service instances ──────────────────────────────────────────────────────────
parser_service          = ResumeParserService()
ai_parser_service       = AIResumeParserService()
analysis_service        = AIAnalysisService()
job_matcher_service     = JobMatcherService()
achievement_service     = AchievementRewriterService()
format_checker_service  = FormatCheckerService()
template_service        = ResumeTemplateService()
power_service           = ResumePowerService()                   
pdf_generator           = PDFResumeGenerator()


# ── Helpers ───────────────────────────────────────────────────────────────────
ALLOWED_EXTENSIONS = {".pdf", ".docx"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
UPLOAD_DIR = "uploads/resumes"
os.makedirs(UPLOAD_DIR, exist_ok=True)


def validate_file(file: UploadFile):
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, f"Only PDF and DOCX files are allowed. Got: {ext}")


def get_unique_filename(user_id: int, filename: str):
    import uuid
    ext = os.path.splitext(filename)[1].lower()
    unique = f"{user_id}_{uuid.uuid4().hex}{ext}"
    path = os.path.join(UPLOAD_DIR, unique)
    return unique, path


def save_upload_file(file: UploadFile, path: str) -> int:
    content = file.file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(400, "File too large. Max 10MB.")
    with open(path, "wb") as f:
        f.write(content)
    return len(content)


# ── Power Feature Schemas ─────────────────────────────────────────────────────
class TailorRequest(BaseModel):
    job_description: str
    target_role: str

class PredictRequest(BaseModel):
    target_role: str

class RadarRequest(BaseModel):
    target_role: Optional[str] = None

class BuildResumeRequest(BaseModel):
    """Used by the manual builder — user sends their own data."""
    template_id: str = "professional"
    resume_data: dict  # Full resume data from Flutter form


class AIBuildResumeRequest(BaseModel):
    """Used by the AI builder — AI rewrites the stored parsed data."""
    target_role: str
    tone: str = "professional"   # professional | aggressive | technical
    template_id: str = "professional"

class JobMatchRequest(BaseModel):
    job_description: str
class GenerateWithDataRequest(BaseModel):
    template_id: str = "professional"
    resume_data: dict  # Full resume data from Flutter editor

# ─────────────────────────────────────────────────────────────────────────────
# EXISTING ENDPOINTS (unchanged)
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/upload", response_model=ResumeResponse, status_code=status.HTTP_201_CREATED)
async def upload_resume(
    file: UploadFile = File(..., description="Resume file (PDF or DOCX)"),
    title: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    validate_file(file)
    unique_filename, file_path = get_unique_filename(current_user.id, file.filename)
    file_size = save_upload_file(file, file_path)
    resume_title = title if title else file.filename
    ext = os.path.splitext(file.filename)[1].lower().lstrip(".")

    resume = Resume(
        user_id=current_user.id,
        title=resume_title,
        file_path=file_path,
        file_type=ext,
        file_size=file_size,
    )
    db.add(resume)
    db.commit()
    db.refresh(resume)
    return resume


@router.post("/{resume_id}/parse", response_model=ResumeResponse)
def parse_resume(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    file_path = resume.file_path
    if resume.file_type == "pdf":
        raw_text = parser_service.extract_text_from_pdf(str(file_path))
    else:
        raw_text = parser_service.extract_text_from_docx(str(file_path))

    resume.parsed_content = raw_text
    resume.is_parsed = 1
    db.commit()
    db.refresh(resume)
    return resume


@router.post("/{resume_id}/parse-ai", response_model=ResumeResponse)
def parse_resume_ai(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    file_path = resume.file_path
    if resume.file_type == "pdf":
        raw_text = parser_service.extract_text_from_pdf(str(file_path))
    else:
        raw_text = parser_service.extract_text_from_docx(str(file_path))

    result = ai_parser_service.parse_resume_with_ai(raw_text)

    if not result["success"]:
        raise HTTPException(500, f"AI parsing failed: {result.get('error', 'Unknown')}")

    parsed = result.get("parsed_data", {})
    resume.parsed_content = raw_text
    resume.contact_info = parsed.get("contact_info")
    resume.education = parsed.get("education")
    resume.experience = parsed.get("experience")
    resume.skills = parsed.get("skills")
    resume.certifications = parsed.get("certifications")
    resume.projects = parsed.get("projects")
    resume.is_parsed = 1
    db.commit()
    db.refresh(resume)
    return resume


@router.post("/{resume_id}/analyze")
def analyze_resume(
    resume_id: int,
    target_role: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    result = analysis_service.analyze_resume(resume.parsed_content, target_role)
    resume.analysis_score = result.get("overall_score")
    resume.analysis_feedback = result
    resume.is_analyzed = 1
    db.commit()
    return result


@router.post("/{resume_id}/check-format")
def check_format(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    result = format_checker_service.check_format(resume.parsed_content)
    resume.ats_score = result.get("format_report", {}).get("format_score")
    db.commit()
    return result



@router.post("/{resume_id}/match-job")
def match_job(
    resume_id: int,
    request: JobMatchRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Match resume to job description using AI - accepts JSON body."""
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    # FIX: Inline Groq-based job matching (JobMatcherService.match_resume_to_job missing)
    import os, json
    from groq import Groq
    client = Groq(api_key=os.getenv("GROQ_API_KEY"))
    prompt = f"""You are an expert resume analyzer. Compare this resume to the job description.

RESUME:
{resume.parsed_content[:3000]}

JOB DESCRIPTION:
{request.job_description[:2000]}

Return ONLY valid JSON:
{{
  "match_score": <0-100>,
  "match_level": "<Poor|Fair|Good|Excellent>",
  "matched_keywords": ["keyword1", "keyword2"],
  "missing_keywords": ["keyword1", "keyword2"],
  "strengths": ["strength1", "strength2"],
  "gaps": ["gap1", "gap2"],
  "recommendation": "brief recommendation"
}}"""

    try:
        resp = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3, max_tokens=1000
        )
        raw = resp.choices[0].message.content.strip()
        start = raw.find("{"); end = raw.rfind("}") + 1
        result = json.loads(raw[start:end])
        return {"success": True, "match_analysis": result}
    except Exception as e:
        raise HTTPException(500, f"AI matching failed: {str(e)}")


@router.post("/{resume_id}/rewrite-achievements")
def rewrite_achievements(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    return achievement_service.rewrite_achievements(resume.parsed_content)


@router.get("/power-verbs")
def get_power_verbs():
    return {"power_verbs": achievement_service.get_power_verbs() if hasattr(achievement_service, "get_power_verbs") else []}


@router.get("/templates")
def get_resume_templates():
    return {
        "templates": template_service.get_templates(),
        "total": len(template_service.get_templates())
    }


@router.post("/{resume_id}/generate")
def generate_resume_document(
    resume_id: int,
    template_id: str = "professional",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    contact = resume.contact_info or {}
    # FIX: extract name from contact_info for template rendering
    resume_data = {
        "name": contact.get("name") or contact.get("full_name") or resume.title or "Your Name",
        "contact_info": contact,
        "email": contact.get("email", ""),
        "phone": contact.get("phone", ""),
        "location": contact.get("location", ""),
        "linkedin": contact.get("linkedin", ""),
        "summary": contact.get("summary") or resume.parsed_content[:300] if resume.parsed_content else "",
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
        "certifications": resume.certifications or [],
    }

    result = template_service.generate_resume(
        resume_data=resume_data, template_id=template_id, user_id=current_user.id
    )
    if not result["success"]:
        raise HTTPException(500, result["error"])

    return {
        "success": True,
        "message": "Resume generated successfully!",
        "filename": result["filename"],
        "template_used": result["template_used"],
        "download_url": f"/api/v1/resumes/{resume_id}/download?template_id={template_id}",
    }


@router.get("/{resume_id}/download")
def download_resume(
    resume_id: int,
    template_id: str = "professional",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    contact = resume.contact_info or {}
    resume_data = {
        "name": contact.get("name") or contact.get("full_name") or resume.title or "Your Name",
        "contact_info": contact,
        "email": contact.get("email", ""),
        "phone": contact.get("phone", ""),
        "location": contact.get("location", ""),
        "linkedin": contact.get("linkedin", ""),
        "summary": contact.get("summary") or (resume.parsed_content[:300] if resume.parsed_content else ""),
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
        "certifications": resume.certifications or [],
    }

    result = template_service.generate_resume(
        resume_data=resume_data, template_id=template_id, user_id=current_user.id
    )
    if not result["success"]:
        raise HTTPException(500, result["error"])

    file_path = result["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, "Generated file not found")

    return FileResponse(
        path=file_path,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        filename=f"resume_{template_id}.docx",
    )


# ─────────────────────────────────────────────────────────────────────────────
# NEW POWER ENDPOINTS
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/{resume_id}/tailor")
def tailor_resume(
    resume_id: int,
    request: TailorRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """AI rewrites entire resume to match a specific job description."""
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    resume_data = {
        "contact_info": resume.contact_info or {},
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
    }

    result = power_service.tailor_resume(
        resume_data=resume_data,
        job_description=request.job_description,
        target_role=request.target_role,
    )
    if not result["success"]:
        raise HTTPException(500, result.get("error", "Tailoring failed"))

    return result

@router.post("/{resume_id}/build-docx")
def build_resume_docx(
    resume_id: int,
    request: BuildResumeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Manual builder: generate DOCX from user-edited data.
    Returns the file as bytes directly.
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    data = request.resume_data
    contact = data.get("contact_info") or {}
    if not data.get("name"):
        data["name"] = (
            contact.get("name") or contact.get("full_name")
            or resume.title or "Your Name"
        )

    result = template_service.generate_resume(
        resume_data=data,
        template_id=request.template_id,
        user_id=current_user.id,
    )
    if not result["success"]:
        raise HTTPException(500, result.get("error", "DOCX generation failed"))

    file_path = result["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, "Generated file not found")

    with open(file_path, "rb") as f:
        content = f.read()

    safe_name = data.get("name", "resume").replace(" ", "_").lower()
    filename = f"{safe_name}_{request.template_id}.docx"

    return StreamingResponse(
        io.BytesIO(content),
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/{resume_id}/build-pdf")
def build_resume_pdf(
    resume_id: int,
    request: BuildResumeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Manual builder: generate PDF from user-edited data.
    Returns the file as bytes directly.
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    data = request.resume_data
    contact = data.get("contact_info") or {}
    if not data.get("name"):
        data["name"] = (
            contact.get("name") or contact.get("full_name")
            or resume.title or "Your Name"
        )

    result = pdf_generator.generate_pdf(
        resume_data=data,
        template_id=request.template_id,
        user_id=current_user.id,
    )
    if not result["success"]:
        raise HTTPException(500, result.get("error", "PDF generation failed"))

    file_path = result["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, "Generated file not found")

    with open(file_path, "rb") as f:
        content = f.read()

    safe_name = data.get("name", "resume").replace(" ", "_").lower()
    filename = f"{safe_name}_{request.template_id}.pdf"

    return StreamingResponse(
        io.BytesIO(content),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/{resume_id}/ai-build-docx")
def ai_build_resume_docx(
    resume_id: int,
    request: AIBuildResumeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    AI builder: reads parsed resume, rewrites it for a target role/tone,
    then generates a DOCX. Returns bytes directly.
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first before AI generation")

    # Build resume_data from stored parsed fields
    contact = resume.contact_info or {}
    resume_data = {
        "contact_info": contact,
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
        "certifications": resume.certifications or [],
    }

    # Run AI tailoring to get rewritten content
    tailored = power_service.tailor_resume(
        resume_data=resume_data,
        job_description=f"Target role: {request.target_role}. Tone: {request.tone}.",
        target_role=request.target_role,
    )

    # Merge AI output back into resume_data
    if tailored.get("success") and tailored.get("data"):
        ai_data = tailored["data"]
        # Override with AI-written fields
        if ai_data.get("summary"):
            resume_data["summary"] = ai_data["summary"]
        if ai_data.get("tailored_experience"):
            resume_data["experience"] = ai_data["tailored_experience"]
        if ai_data.get("highlighted_skills"):
            resume_data["skills"] = ai_data["highlighted_skills"]

    # Ensure name is set
    resume_data["name"] = (
        contact.get("name") or contact.get("full_name")
        or resume.title or "Your Name"
    )

    result = template_service.generate_resume(
        resume_data=resume_data,
        template_id=request.template_id,
        user_id=current_user.id,
    )
    if not result["success"]:
        raise HTTPException(500, result.get("error", "DOCX generation failed"))

    file_path = result["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, "Generated file not found")

    with open(file_path, "rb") as f:
        content = f.read()

    safe_name = resume_data["name"].replace(" ", "_").lower()
    filename = f"{safe_name}_{request.tone}_{request.template_id}.docx"

    return StreamingResponse(
        io.BytesIO(content),
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/{resume_id}/ai-build-pdf")
def ai_build_resume_pdf(
    resume_id: int,
    request: AIBuildResumeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    AI builder: reads parsed resume, rewrites it for a target role/tone,
    then generates a PDF. Returns bytes directly.
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first before AI generation")

    contact = resume.contact_info or {}
    resume_data = {
        "contact_info": contact,
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
        "certifications": resume.certifications or [],
    }

    tailored = power_service.tailor_resume(
        resume_data=resume_data,
        job_description=f"Target role: {request.target_role}. Tone: {request.tone}.",
        target_role=request.target_role,
    )

    if tailored.get("success") and tailored.get("data"):
        ai_data = tailored["data"]
        if ai_data.get("summary"):
            resume_data["summary"] = ai_data["summary"]
        if ai_data.get("tailored_experience"):
            resume_data["experience"] = ai_data["tailored_experience"]
        if ai_data.get("highlighted_skills"):
            resume_data["skills"] = ai_data["highlighted_skills"]

    resume_data["name"] = (
        contact.get("name") or contact.get("full_name")
        or resume.title or "Your Name"
    )

    result = pdf_generator.generate_pdf(
        resume_data=resume_data,
        template_id=request.template_id,
        user_id=current_user.id,
    )
    if not result["success"]:
        raise HTTPException(500, result.get("error", "PDF generation failed"))

    file_path = result["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, "Generated file not found")

    with open(file_path, "rb") as f:
        content = f.read()

    safe_name = resume_data["name"].replace(" ", "_").lower()
    filename = f"{safe_name}_{request.tone}_{request.template_id}.pdf"

    return StreamingResponse(
        io.BytesIO(content),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )



@router.post("/{resume_id}/predict-questions")
def predict_questions(
    resume_id: int,
    request: PredictRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Predict interview questions based on THIS specific resume."""
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    resume_data = {
        "contact_info": resume.contact_info or {},
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
    }

    result = power_service.predict_interview_questions(
        resume_data=resume_data,
        target_role=request.target_role,
    )
    if not result["success"]:
        raise HTTPException(500, result.get("error", "Prediction failed"))

    return result


@router.post("/{resume_id}/radar-score")
def radar_score(
    resume_id: int,
    request: RadarRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """6-dimension visual radar score for the resume."""
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    resume_data = {
        "contact_info": resume.contact_info or {},
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
        "certifications": resume.certifications or [],
    }

    result = power_service.get_radar_score(
        resume_data=resume_data,
        target_role=request.target_role,
    )
    if not result["success"]:
        raise HTTPException(500, result.get("error", "Scoring failed"))

    return result


@router.post("/{resume_id}/generate-with-data")
def generate_resume_with_data(
    resume_id: int,
    request: GenerateWithDataRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Generate a resume DOCX using EDITED data sent from the Flutter editor.
    Bypasses the stored parsed data — uses whatever the user typed/edited.
    Returns the DOCX file directly as bytes (no temp download URL needed).
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    resume_data = request.resume_data

    # Ensure name is set — fall back gracefully
    contact = resume_data.get("contact_info") or {}
    if not resume_data.get("name"):
        resume_data["name"] = (
            contact.get("name")
            or contact.get("full_name")
            or resume.title
            or "Your Name"
        )

    result = template_service.generate_resume(
        resume_data=resume_data,
        template_id=request.template_id,
        user_id=current_user.id,
    )

    if not result["success"]:
        raise HTTPException(500, result.get("error", "Generation failed"))

    file_path = result["file_path"]
    if not os.path.exists(file_path):
        raise HTTPException(404, "Generated file not found")

    # Read and return file as streaming bytes
    with open(file_path, "rb") as f:
        content = f.read()

    safe_name = (
        resume_data.get("name", "resume")
        .replace(" ", "_")
        .lower()
    )
    filename = f"{safe_name}_{request.template_id}.docx"

    return StreamingResponse(
        io.BytesIO(content),
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )

















@router.post("/{resume_id}/variants")
def generate_variants(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Generate 3 resume tone variants: Aggressive, Conservative, Technical."""
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    if not resume.parsed_content:
        raise HTTPException(400, "Parse resume first")

    resume_data = {
        "contact_info": resume.contact_info or {},
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
    }

    result = power_service.generate_variants(
        resume_data=resume_data,
        user_id=current_user.id,
    )
    if not result["success"]:
        raise HTTPException(500, result.get("error", "Variant generation failed"))

    return {
        "success": True,
        "variants_data": result["variants_data"],
        "files": result["files"],
        "download_urls": {
            k: f"/api/v1/resumes/{resume_id}/variants/{k}/download"
            for k in result["files"].keys()
        },
    }


@router.get("/{resume_id}/variants/{variant}/download")
def download_variant(
    resume_id: int,
    variant: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Download a specific resume variant DOCX."""
    if variant not in ["aggressive", "conservative", "technical"]:
        raise HTTPException(400, "Invalid variant. Use: aggressive, conservative, technical")

    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    file_path = f"generated_resumes/resume_{variant}_{current_user.id}.docx"
    if not os.path.exists(file_path):
        raise HTTPException(404, "Variant not generated yet. Call POST /variants first.")

    return FileResponse(
        path=file_path,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        filename=f"resume_{variant}.docx",
    )


# ─────────────────────────────────────────────────────────────────────────────
# STANDARD CRUD (unchanged)
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/", response_model=List[ResumeListResponse])
def get_user_resumes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Resume).filter(Resume.user_id == current_user.id).all()


@router.get("/{resume_id}", response_model=ResumeResponse)
def get_resume(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")
    return resume


@router.put("/{resume_id}", response_model=ResumeResponse)
def update_resume(
    resume_id: int,
    resume_update: ResumeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    for field, value in resume_update.model_dump(exclude_none=True).items():
        setattr(resume, field, value)
    db.commit()
    db.refresh(resume)
    return resume


@router.delete("/{resume_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_resume(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    resume = db.query(Resume).filter(
        Resume.id == resume_id, Resume.user_id == current_user.id
    ).first()
    if not resume:
        raise HTTPException(404, "Resume not found")

    if resume.file_path and os.path.exists(resume.file_path):
        os.remove(resume.file_path)

    db.delete(resume)
    db.commit()
    return None