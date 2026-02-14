# app/services/interview_ai_service.py
# Uses Groq:
#   - llama-3.3-70b-versatile  → interview conversation (Arabic + English)
#   - whisper-large-v3          → voice transcription (best Arabic support)
import os
import io
import json
import tempfile
from groq import Groq
from typing import Dict, List, Optional

client = Groq(api_key=os.getenv("GROQ_API_KEY"))

CHAT_MODEL  = "llama-3.3-70b-versatile"
VOICE_MODEL = "whisper-large-v3"          # Best multilingual model on Groq


# ── System prompt factory ────────────────────────────────────────
def _system_prompt(job_role: str, difficulty: str,
                   interview_type: str, language: str,
                   resume_text: str = "", job_description: str = "") -> str:

    lang_instruction = (
        "You MUST respond ONLY in Arabic (Modern Standard Arabic). "
        "Ask all questions in Arabic. Give all feedback in Arabic."
        if language == "ar"
        else
        "Respond in clear, professional English."
    )

    difficulty_map = {
        "easy":   "Ask straightforward, entry-level questions. Be encouraging and patient.",
        "medium": "Ask standard interview questions. Maintain professional expectations.",
        "hard":   "Ask challenging questions. Probe deeply. Ask sharp follow-ups.",
    }

    type_map = {
        "behavioral":  "Focus on behavioral questions (STAR method). Ask about past experiences.",
        "technical":   f"Focus on technical questions specific to {job_role}.",
        "mixed":       "Mix behavioral and technical questions naturally.",
    }

    resume_section = (
        f"\n\nCANDIDATE RESUME:\n{resume_text[:2000]}" if resume_text else ""
    )
    jd_section = (
        f"\n\nJOB DESCRIPTION:\n{job_description[:1000]}" if job_description else ""
    )

    return f"""You are an expert {job_role} interviewer conducting a {difficulty} {interview_type} interview.

LANGUAGE: {lang_instruction}

DIFFICULTY: {difficulty_map.get(difficulty, difficulty_map['medium'])}

INTERVIEW TYPE: {type_map.get(interview_type, type_map['mixed'])}

YOUR BEHAVIOUR:
- Be professional but human and conversational.
- Ask ONE question at a time. Never ask multiple questions in one message.
- Listen carefully and ask relevant follow-up questions based on answers.
- If an answer is weak, probe gently: "Can you elaborate?" or "Can you give a specific example?"
- After 6-8 questions, naturally wrap up the interview.
- Never break character. You are the interviewer, not an AI assistant.{resume_section}{jd_section}

Start with a warm greeting and your FIRST question immediately."""


# ── Evaluate a single answer ──────────────────────────────────────
def _evaluate_answer(question: str, answer: str,
                     job_role: str, language: str) -> Dict:
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
        text = r.choices[0].message.content.strip()
        # Strip markdown fences if present
        text = text.replace("```json", "").replace("```", "").strip()
        return json.loads(text)
    except Exception:
        return {"score": 5, "strengths": [], "improvements": [], "tip": ""}


# ── Main service class ────────────────────────────────────────────
class InterviewAIService:

    def start_interview(self, job_role: str, difficulty: str,
                        interview_type: str, language: str = "en",
                        resume_text: str = "",
                        job_description: str = "") -> Dict:
        """Generate the opening message and first question."""
        system = _system_prompt(
            job_role, difficulty, interview_type, language,
            resume_text, job_description
        )
        r = client.chat.completions.create(
            model=CHAT_MODEL,
            messages=[
                {"role": "system", "content": system},
                {"role": "user",   "content": "Begin the interview now."},
            ],
            temperature=0.7,
            max_tokens=400,
        )
        return {"success": True, "message": r.choices[0].message.content.strip()}

    def process_message(self, history: List[Dict], user_message: str,
                        job_role: str, difficulty: str,
                        interview_type: str, language: str = "en",
                        resume_text: str = "",
                        job_description: str = "",
                        message_count: int = 0) -> Dict:
        """
        Process a user message and return the next AI message + evaluation.
        history: list of {"role": "user"/"assistant", "content": "..."}
        """
        system = _system_prompt(
            job_role, difficulty, interview_type, language,
            resume_text, job_description
        )

        # Evaluate the user's last answer against the previous AI question
        evaluation = None
        if history:
            last_ai = next(
                (m["content"] for m in reversed(history)
                 if m["role"] == "assistant"), ""
            )
            if last_ai:
                evaluation = _evaluate_answer(
                    last_ai, user_message, job_role, language)

        # Decide if interview should end (after ~7 exchanges)
        should_end = message_count >= 14  # 7 user + 7 ai

        if should_end:
            close_instruction = (
                "الآن أنهِ المقابلة بلطف، وشكر المرشح، وقدم ملاحظاتك العامة باختصار."
                if language == "ar"
                else
                "Now gracefully close the interview, thank the candidate, and give brief overall feedback."
            )
            messages = [
                {"role": "system", "content": system},
                *history,
                {"role": "user",   "content": user_message},
                {"role": "user",   "content": close_instruction},
            ]
        else:
            messages = [
                {"role": "system", "content": system},
                *history,
                {"role": "user",   "content": user_message},
            ]

        r = client.chat.completions.create(
            model=CHAT_MODEL,
            messages=messages,
            temperature=0.7,
            max_tokens=500,
        )
        ai_reply = r.choices[0].message.content.strip()

        return {
            "success": True,
            "message": ai_reply,
            "evaluation": evaluation,
            "should_end": should_end,
        }

    def transcribe_audio(self, audio_bytes: bytes,
                         filename: str = "audio.webm",
                         language: str = "en") -> Dict:
        """
        Transcribe audio using Groq Whisper-large-v3.
        Supports Arabic and English natively — best open model for both.
        language: 'ar' or 'en'
        """
        # Groq Whisper accepts: mp3, mp4, mpeg, mpga, m4a, wav, webm, ogg
        # Map our language code to Whisper language hint
        whisper_lang = "ar" if language == "ar" else "en"
        try:
            # Groq requires a file-like object with a name
            audio_file = io.BytesIO(audio_bytes)
            audio_file.name = filename

            transcription = client.audio.transcriptions.create(
                model=VOICE_MODEL,
                file=audio_file,
                language=whisper_lang,
                response_format="text",
            )
            # response_format="text" returns a plain string
            text = transcription if isinstance(transcription, str) else transcription.text
            return {"success": True, "transcript": text.strip()}
        except Exception as e:
            return {"success": False, "error": str(e), "transcript": ""}

    def generate_final_feedback(self, history: List[Dict],
                                job_role: str, language: str = "en",
                                score: Optional[float] = None) -> Dict:
        """Generate final interview report."""
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
  "strengths": ["<strength>", "..."],
  "areas_for_improvement": ["<area>", "..."],
  "communication_score": <0-100>,
  "technical_score": <0-100>,
  "confidence_score": <0-100>,
  "recommended_resources": ["<resource>", "..."],
  "next_steps": ["<action>", "..."]
}}"""
        try:
            r = client.chat.completions.create(
                model=CHAT_MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=800,
            )
            text = r.choices[0].message.content.strip()
            text = text.replace("```json", "").replace("```", "").strip()
            feedback = json.loads(text)
            return {"success": True, "feedback": feedback,
                    "score": feedback.get("overall_score", score or 70)}
        except Exception as e:
            return {"success": False, "error": str(e),
                    "feedback": {}, "score": score or 70}