# app/services/cover_letter_service.py
"""
S5 — Cover Letter Generator
Uses Groq Llama 3.3 70B to generate personalized cover letters
from the user's parsed resume + job details.
"""

import os
import json
import logging
from groq import Groq

logger = logging.getLogger(__name__)

_client = Groq(api_key=os.getenv("GROQ_API_KEY", ""))


def generate_cover_letter(
    job_title: str,
    company_name: str = "",
    job_description: str = "",
    tone: str = "professional",
    language: str = "en",
    resume_data: dict = None,
) -> dict:
    """
    Generate a cover letter using Groq LLM.
    Returns: {"content": str, "word_count": int, "match_score": float}
    """
    resume_data = resume_data or {}

    # ── Build resume summary for prompt ──────────────────────────
    resume_ctx = _build_resume_context(resume_data)

    # ── Tone instruction ─────────────────────────────────────────
    tone_map = {
        "professional": "formal, confident, and results-oriented",
        "enthusiastic": "warm, energetic, and passionate about the role",
        "concise":      "brief and to the point — maximum 250 words",
        "creative":     "engaging and memorable, showing personality",
    }
    tone_desc = tone_map.get(tone, tone_map["professional"])

    # ── Language instruction ──────────────────────────────────────
    lang_instruction = "Write in Arabic." if language == "ar" else "Write in English."

    # ── Prompt ───────────────────────────────────────────────────
    system = (
        "You are an expert career coach and professional writer. "
        "Write compelling, personalized cover letters that get interviews. "
        "Never use generic filler phrases. Be specific and quantify achievements when possible."
    )

    user_msg = f"""Write a cover letter for this candidate.

JOB DETAILS:
- Position: {job_title}
- Company: {company_name or 'the company'}
- Job Description: {job_description[:1500] if job_description else 'Not provided'}

CANDIDATE BACKGROUND:
{resume_ctx}

REQUIREMENTS:
- Tone: {tone_desc}
- {lang_instruction}
- 3-4 paragraphs (opening, 1-2 body, closing)
- Address the hiring manager professionally
- Connect candidate's experience directly to the role
- End with a clear call to action
- Return ONLY the cover letter text, no extra commentary
"""

    try:
        response = _client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_msg},
            ],
            temperature=0.7,
            max_tokens=1000,
        )
        content = response.choices[0].message.content.strip()
        word_count = len(content.split())

        # ── Calculate match score ─────────────────────────────────
        match_score = _calculate_match_score(
            content=content,
            job_description=job_description,
            skills=resume_data.get("skills", []),
        )

        return {
            "content":     content,
            "word_count":  word_count,
            "match_score": match_score,
        }

    except Exception as e:
        logger.error(f"Cover letter generation failed: {e}")
        raise


def _build_resume_context(resume_data: dict) -> str:
    """Build a concise resume summary for the prompt."""
    lines = []

    # Name / contact
    contact = resume_data.get("contact_info") or {}
    if isinstance(contact, str):
        try:
            contact = json.loads(contact)
        except Exception:
            contact = {}

    # Experience
    experience = resume_data.get("experience") or []
    if isinstance(experience, str):
        try:
            experience = json.loads(experience)
        except Exception:
            experience = []
    if experience:
        lines.append("Experience:")
        for exp in experience[:4]:
            if isinstance(exp, dict):
                title = exp.get("title", "")
                company = exp.get("company", "")
                duration = exp.get("duration", "")
                desc = exp.get("description", "")[:200]
                lines.append(f"  - {title} at {company} ({duration}): {desc}")

    # Skills
    skills = resume_data.get("skills") or []
    if isinstance(skills, str):
        try:
            skills = json.loads(skills)
        except Exception:
            skills = []
    if skills:
        skill_names = [
            s.get("name", s) if isinstance(s, dict) else str(s)
            for s in skills[:15]
        ]
        lines.append(f"Skills: {', '.join(skill_names)}")

    # Education
    education = resume_data.get("education") or []
    if isinstance(education, str):
        try:
            education = json.loads(education)
        except Exception:
            education = []
    if education:
        lines.append("Education:")
        for edu in education[:2]:
            if isinstance(edu, dict):
                degree = edu.get("degree", "")
                school = edu.get("school", "")
                year = edu.get("year", "")
                lines.append(f"  - {degree} from {school} ({year})")

    # Parsed content fallback
    if not lines and resume_data.get("parsed_content"):
        lines.append(resume_data["parsed_content"][:800])

    return "\n".join(lines) if lines else "Resume not available — write a general strong cover letter."


def _calculate_match_score(
    content: str,
    job_description: str,
    skills: list,
) -> float:
    """
    Simple keyword-based match score between cover letter and JD.
    Returns 0-100.
    """
    if not job_description:
        return 75.0  # Default when no JD provided

    content_lower = content.lower()
    jd_lower = job_description.lower()

    # Extract meaningful words from JD (4+ chars)
    jd_words = set(w.strip(".,!?;:()") for w in jd_lower.split() if len(w) >= 4)

    if not jd_words:
        return 75.0

    # Count how many JD words appear in the cover letter
    matches = sum(1 for word in jd_words if word in content_lower)
    keyword_score = min(100, (matches / len(jd_words)) * 200)  # Scale up

    # Bonus for skill mentions
    skill_names = [
        s.get("name", s).lower() if isinstance(s, dict) else str(s).lower()
        for s in (skills or [])
    ]
    skill_matches = sum(1 for skill in skill_names if skill in content_lower)
    skill_bonus = min(20, skill_matches * 4)

    final = min(100, round(keyword_score * 0.8 + skill_bonus + 20, 1))
    return final