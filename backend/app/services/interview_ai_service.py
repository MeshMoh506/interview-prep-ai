# app/services/interview_ai_service.py
import json
import os
import time
from groq import Groq
from typing import Dict, List, Optional

from app.config import settings

client = Groq(
    api_key=settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", ""),
    max_retries=3,
    timeout=30.0,
)
CHAT_MODEL = "llama-3.3-70b-versatile"


# ── System prompt ────────────────────────────────────────────────
def _system_prompt(job_role: str, difficulty: str, interview_type: str,
                   language: str, resume_text: str = "", job_description: str = "") -> str:

    lang_instruction = (
        "You MUST respond ONLY in Arabic (Modern Standard Arabic). "
        "Ask all questions in Arabic. Give all feedback in Arabic."
        if language == "ar"
        else "Respond in clear, professional English."
    )
    difficulty_map = {
        "easy":   "Ask straightforward, entry-level questions. Be encouraging and patient.",
        "medium": "Ask standard interview questions. Maintain professional expectations.",
        "hard":   "Ask challenging questions. Probe deeply. Ask sharp follow-ups.",
    }
    type_map = {
        "behavioral": "Focus on behavioral questions (STAR method). Ask about past experiences.",
        "technical":  f"Focus on technical questions specific to {job_role}.",
        "mixed":      "Mix behavioral and technical questions naturally.",
    }
    resume_section = f"\n\nCANDIDATE RESUME:\n{resume_text[:2000]}" if resume_text else ""
    jd_section     = f"\n\nJOB DESCRIPTION:\n{job_description[:1000]}" if job_description else ""

    return f"""You are an expert {job_role} interviewer conducting a real {difficulty} {interview_type} interview.

LANGUAGE: {lang_instruction}

DIFFICULTY: {difficulty_map.get(difficulty, difficulty_map['medium'])}

INTERVIEW TYPE: {type_map.get(interview_type, type_map['mixed'])}

YOUR BEHAVIOUR:
- Be professional but human and conversational.
- Ask ONE question at a time. Never ask multiple questions in one message.
- Listen carefully and ask relevant follow-up questions based on answers.
- If an answer is weak, probe gently with a follow-up question.
- After 7 questions, naturally wrap up the interview.
- Never break character. You are the interviewer, not an AI assistant.

CRITICAL - VOICE AWARENESS:
- This is a REAL spoken interview. Your text responses are automatically converted to voice and played aloud to the candidate.
- The candidate speaks to you using their microphone and you hear their voice.
- NEVER mention text, typing, writing, or any technical limitations.
- NEVER say you cannot speak, cannot do voice, or that this is text-only.
- NEVER refer to yourself as an AI or chatbot.
- Just speak naturally as a real human interviewer would in a face-to-face interview.{resume_section}{jd_section}

Start with a warm greeting and your FIRST question immediately."""


# ── Per-answer evaluation ────────────────────────────────────────
def _evaluate_answer(question: str, answer: str, job_role: str, language: str) -> Dict:
    lang = "Arabic" if language == "ar" else "English"
    prompt = f"""Evaluate this interview answer briefly.

Job Role: {job_role}
Question: {question}
Answer: {answer}

Return ONLY valid JSON (no markdown):
{{
  "score": <1-10>,
  "strengths": ["<point>"],
  "improvements": ["<point>"],
  "tip": "<one actionable tip in {lang}>"
}}"""
    try:
        r = client.chat.completions.create(
            model=CHAT_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            max_tokens=300,
        )
        text = r.choices[0].message.content.strip().replace("```json", "").replace("```", "").strip()
        return json.loads(text)
    except Exception:
        return {"score": 5, "strengths": [], "improvements": [], "tip": ""}


# ── Retry wrapper ────────────────────────────────────────────────
def _chat(messages: list, temperature: float = 0.7, max_tokens: int = 500) -> str:
    last_error = None
    for attempt in range(3):
        try:
            r = client.chat.completions.create(
                model=CHAT_MODEL,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
            )
            return r.choices[0].message.content.strip()
        except Exception as e:
            last_error = e
            if attempt < 2:
                time.sleep(1.5 * (attempt + 1))
    raise last_error


class InterviewAIService:

    def start_interview(self, job_role: str, difficulty: str, interview_type: str,
                        language: str = "en", resume_text: str = "",
                        job_description: str = "") -> Dict:
        system = _system_prompt(job_role, difficulty, interview_type, language,
                                resume_text, job_description)
        try:
            message = _chat(
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user",   "content": "Begin the interview now."},
                ],
                temperature=0.7,
                max_tokens=400,
            )
            return {"success": True, "message": message}
        except Exception as e:
            return {"success": False, "error": str(e), "message": ""}

    def process_message(self, history: List[Dict], user_message: str,
                        job_role: str, difficulty: str, interview_type: str,
                        language: str = "en", resume_text: str = "",
                        job_description: str = "",
                        user_msg_count: int = 0) -> Dict:
        system = _system_prompt(job_role, difficulty, interview_type, language,
                                resume_text, job_description)

        evaluation: Optional[Dict] = None
        if history:
            last_ai_q = next(
                (m["content"] for m in reversed(history) if m["role"] == "assistant"), ""
            )
            if last_ai_q:
                try:
                    evaluation = _evaluate_answer(last_ai_q, user_message, job_role, language)
                except Exception:
                    evaluation = None

        should_end = user_msg_count >= 7

        if should_end:
            close = (
                "أنهِ المقابلة الآن بلطف، شكر المرشح، وقدم تقييمًا موجزًا."
                if language == "ar"
                else "Now gracefully close the interview, thank the candidate, and give brief overall feedback."
            )
            messages = [
                {"role": "system", "content": system},
                *history,
                {"role": "user",   "content": user_message},
                {"role": "user",   "content": close},
            ]
        else:
            messages = [
                {"role": "system", "content": system},
                *history,
                {"role": "user",   "content": user_message},
            ]

        try:
            message = _chat(messages=messages, temperature=0.7, max_tokens=500)
            return {
                "success":    True,
                "message":    message,
                "evaluation": evaluation,
                "should_end": should_end,
            }
        except Exception as e:
            return {
                "success":    False,
                "error":      str(e),
                "message":    "",
                "evaluation": evaluation,
                "should_end": False,
            }

    def generate_final_feedback(self, history: List[Dict], job_role: str,
                                language: str = "en",
                                score: Optional[float] = None) -> Dict:
        lang = "Arabic" if language == "ar" else "English"
        conversation = "\n".join(
            f"{m['role'].upper()}: {m['content']}" for m in history
        )
        prompt = f"""Analyze this complete {job_role} interview and give a detailed report in {lang}.

CONVERSATION:
{conversation[:3000]}

Return ONLY valid JSON (no markdown):
{{
  "overall_score": <0-100>,
  "summary": "<2-3 sentence overall assessment in {lang}>",
  "strengths": ["<strength>"],
  "areas_for_improvement": ["<area>"],
  "communication_score": <0-100>,
  "technical_score": <0-100>,
  "confidence_score": <0-100>,
  "recommended_resources": ["<resource>"],
  "next_steps": ["<action>"]
}}"""
        try:
            text = _chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=800,
            )
            text = text.replace("```json", "").replace("```", "").strip()
            feedback = json.loads(text)
            return {"success": True, "feedback": feedback,
                    "score": feedback.get("overall_score", score or 70)}
        except Exception as e:
            return {"success": False, "error": str(e), "feedback": {}, "score": score or 70}