from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from pathlib import Path
from app.services.ai_analysis_service import AIAnalysisService
from app.services.job_matcher_service import JobMatcherService
from app.services.achievement_rewriter_service import AchievementRewriterService
from app.services.format_checker_service import FormatCheckerService
from fastapi.responses import FileResponse
from app.services.resume_template_service import ResumeTemplateService

import os
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
from app.utils.file_utils import validate_file, get_unique_filename, save_upload_file, delete_file
from app.services.resume_parser import ResumeParser
from app.services.ai_resume_parser import AIResumeParser

router = APIRouter(prefix="/api/v1/resumes", tags=["Resumes"])

# Initialize parsers normal which will be skiped, and AI-based and other services for analysis, job matching, and achievement rewriting. We can easily swap out the AI model or service in the future without changing the router logic.
parser_service = ResumeParser()
ai_parser_service = AIResumeParser()
ai_analyzer_service = AIAnalysisService()
job_matcher_service = JobMatcherService()
achievement_service = AchievementRewriterService()
format_checker_service = FormatCheckerService()
template_service = ResumeTemplateService()


@router.post("/upload", response_model=ResumeResponse, status_code=status.HTTP_201_CREATED)
async def upload_resume(
    file: UploadFile = File(..., description="Resume file (PDF or DOCX)"),
    title: Optional[str] = Form(None, description="Resume title (optional)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Upload a new resume file"""
    validate_file(file)
    unique_filename, file_path = get_unique_filename(current_user.id, file.filename)
    file_size = save_upload_file(file, file_path)
    
    resume_title = title if title else file.filename
    file_ext = file_path.suffix.lower().replace(".", "")
    
    new_resume = Resume(
        user_id=current_user.id,
        title=resume_title,
        file_path=str(file_path),
        file_type=file_ext,
        file_size=file_size,
        is_parsed=0,
        is_analyzed=0
    )
    
    db.add(new_resume)
    db.commit()
    db.refresh(new_resume)
    
    return new_resume

@router.post("/{resume_id}/parse", response_model=ResumeResponse)
def parse_resume_rule_based(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Parse resume using rule-based parser (fast, ~90% accuracy)
    
    Good for:
    - Quick parsing
    - Standard resume formats
    - Lower API costs
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resume not found"
        )
    
    file_path = Path(resume.file_path)
    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resume file not found on server"
        )
    
    try:
        parsed_data = parser_service.parse_resume(
            str(file_path),
            resume.file_type
        )
        
        resume.parsed_content = parsed_data['raw_text']
        resume.contact_info = parsed_data['contact_info']
        resume.education = parsed_data['education']
        resume.experience = parsed_data['experience']
        resume.skills = parsed_data['skills']
        resume.certifications = parsed_data.get('certifications', [])
        resume.projects = parsed_data.get('projects', [])
        resume.is_parsed = 1
        
        db.commit()
        db.refresh(resume)
        
        return resume
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to parse resume: {str(e)}"
        )

@router.post("/{resume_id}/parse-ai", response_model=ResumeResponse)
def parse_resume_with_ai(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Parse resume using AI (Groq/Llama 3.1, ~95% accuracy)
    
    Benefits:
    - Higher accuracy (95%+)
    - Works with any format
    - Better skill extraction
    - Context understanding
    
    Takes 2-5 seconds
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resume not found"
        )
    
    file_path = Path(resume.file_path)
    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resume file not found on server"
        )
    
    try:
        # Extract text
        if resume.file_type == 'pdf':
            raw_text = parser_service.extract_text_from_pdf(str(file_path))
        else:
            raw_text = parser_service.extract_text_from_docx(str(file_path))
        
        # Parse with AI
        result = ai_parser_service.parse_resume_with_ai(raw_text)
        
        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"AI parsing failed: {result.get('error', 'Unknown error')}"
            )
        
        parsed_data = result['data']
        
        # Update resume
        resume.parsed_content = raw_text
        resume.contact_info = parsed_data.get('contact_info', {})
        resume.education = parsed_data.get('education', [])
        resume.experience = parsed_data.get('experience', [])
        resume.skills = parsed_data.get('skills', [])
        resume.projects = parsed_data.get('projects', [])
        resume.certifications = parsed_data.get('certifications', [])
        resume.is_parsed = 1
        
        db.commit()
        db.refresh(resume)
        
        return resume
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to parse resume: {str(e)}"
        )

@router.post("/{resume_id}/analyze")
def analyze_resume_with_ai(
    resume_id: int,
    target_role: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Analyze resume with AI and get detailed feedback
    
    Returns:
    - Overall quality score (1-10)
    - Strengths and weaknesses
    - ATS compatibility score
    - Specific improvement suggestions
    - Keyword recommendations
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resume not found"
        )
    
    if not resume.parsed_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Resume must be parsed first. Call /parse-ai or /parse endpoint first."
        )
    
    try:
        result = ai_analyzer_service.analyze_resume(
            resume.parsed_content,
            target_role=target_role
        )
        
        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get('error', 'Analysis failed')
            )
        
        analysis = result['analysis']
        
        # Save analysis to database
        resume.analysis_score = analysis.get('overall_score')
        resume.analysis_feedback = analysis
        resume.ats_score = analysis.get('ats_score')
        resume.is_analyzed = 1
        
        db.commit()
        db.refresh(resume)
        
        return {
            'resume_id': resume_id,
            'analysis': analysis,
            'tokens_used': result.get('tokens_used', 0)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Analysis failed: {str(e)}"
        )

@router.post("/{resume_id}/check-format")
def check_resume_format(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Check resume for ATS formatting issues
    
    Checks:
    - Resume length (word count)
    - Contact information completeness
    - Essential sections presence
    - Keyword density
    - Action verb strength
    - Quantifiable achievements
    
    Returns format score and specific fixes
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(status_code=404, detail="Resume not found")
    
    if not resume.parsed_content:
        raise HTTPException(
            status_code=400,
            detail="Resume must be parsed first"
        )
    
    try:
        format_report = format_checker_service.check_format(resume.parsed_content)
        
        return {
            'resume_id': resume_id,
            'format_report': format_report
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



@router.post("/{resume_id}/match-job")
def match_resume_to_job(
    resume_id: int,
    job_description: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Compare resume to job description
    
    Returns:
    - Match score (0-100)
    - Matching keywords
    - Missing keywords
    - Specific recommendations
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(status_code=404, detail="Resume not found")
    
    if not resume.parsed_content:
        raise HTTPException(status_code=400, detail="Resume must be parsed first")
    
    try:
        result = job_matcher_service.match_to_job(
            resume.parsed_content,
            job_description
        )
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result['error'])
        
        return {
            'resume_id': resume_id,
            'match_analysis': result['match_data'],
            'tokens_used': result.get('tokens_used', 0)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{resume_id}/rewrite-achievements")
def rewrite_resume_achievements(
    resume_id: int,
    bullet_points: List[str],
    job_context: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Rewrite weak bullet points into powerful STAR-format achievements
    
    Input: List of bullet points to rewrite, and optional job context for tailoring
    Returns: Rewritten achievements with metrics and impact
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(status_code=404, detail="Resume not found")
    
    try:
        result = achievement_service.rewrite_bullet_points(
            bullet_points,
            job_context
        )
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result['error'])
        
        return {
            'resume_id': resume_id,
            'rewrites': result['rewrite_data'],
            'tokens_used': result.get('tokens_used', 0)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/power-verbs")
def get_power_verbs(category: Optional[str] = None):
    """
    Get list of powerful action verbs for resume writing
    
    Categories: leadership, achievement, creation, improvement, 
                analysis, communication, problem_solving, growth, reduction
    """
    verbs = achievement_service.get_power_verbs(category)
    return {
        'category': category or 'all',
        'power_verbs': verbs
    }
@router.get("/templates")
def get_resume_templates():
    """Get all available resume templates"""
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
    """
    Generate a formatted resume DOCX document
    
    Templates:
    - professional: Clean corporate style
    - modern: Contemporary tech style  
    - minimal: Simple ATS-friendly
    
    Returns: Download link for generated DOCX
    """
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(status_code=404, detail="Resume not found")
    
    if not resume.parsed_content:
        raise HTTPException(
            status_code=400,
            detail="Parse resume first using /parse-ai endpoint"
        )
    
    resume_data = {
        "contact_info": resume.contact_info or {},
        "summary": None,
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
        "certifications": resume.certifications or []
    }
    
    result = template_service.generate_resume(
        resume_data=resume_data,
        template_id=template_id,
        user_id=current_user.id
    )
    
    if not result["success"]:
        raise HTTPException(status_code=500, detail=result["error"])
    
    return {
        "success": True,
        "message": "Resume generated successfully!",
        "filename": result["filename"],
        "template_used": result["template_used"],
        "download_url": f"/api/v1/resumes/{resume_id}/download?template_id={template_id}"
    }

@router.get("/{resume_id}/download")
def download_resume(
    resume_id: int,
    template_id: str = "professional",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Download generated resume as DOCX file"""
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(status_code=404, detail="Resume not found")
    
    # Generate fresh document
    resume_data = {
        "contact_info": resume.contact_info or {},
        "summary": None,
        "experience": resume.experience or [],
        "education": resume.education or [],
        "skills": resume.skills or [],
        "projects": resume.projects or [],
        "certifications": resume.certifications or []
    }
    
    result = template_service.generate_resume(
        resume_data=resume_data,
        template_id=template_id,
        user_id=current_user.id
    )
    
    if not result["success"]:
        raise HTTPException(status_code=500, detail=result["error"])
    
    file_path = result["file_path"]
    
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Generated file not found")
    
    return FileResponse(
        path=file_path,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        filename=f"resume_{template_id}.docx"
    )

@router.get("/", response_model=List[ResumeListResponse])
def get_user_resumes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all resumes for current user"""
    resumes = db.query(Resume).filter(
        Resume.user_id == current_user.id
    ).order_by(Resume.created_at.desc()).all()
    
    return resumes

@router.get("/{resume_id}", response_model=ResumeResponse)
def get_resume(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get specific resume by ID"""
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resume not found"
        )
    
    return resume

@router.put("/{resume_id}", response_model=ResumeResponse)
def update_resume(
    resume_id: int,
    resume_update: ResumeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update resume metadata"""
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resume not found"
        )
    
    if resume_update.title:
        resume.title = resume_update.title
    
    db.commit()
    db.refresh(resume)
    
    return resume

@router.delete("/{resume_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_resume(
    resume_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete resume and associated file"""
    resume = db.query(Resume).filter(
        Resume.id == resume_id,
        Resume.user_id == current_user.id
    ).first()
    
    if not resume:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Resume not found"
        )
    
    delete_file(resume.file_path)
    db.delete(resume)
    db.commit()
    
    return None
