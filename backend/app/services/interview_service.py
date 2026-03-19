# app/services/interview_ai_service.py  (second file — the one with _sys/_chat)
import os, json, re
from typing import Dict, List, Optional

try:
    from groq import Groq
    _client = Groq(api_key=os.getenv("GROQ_API_KEY", ""))
    _USE_GROQ = True
except Exception:
    _USE_GROQ = False
    _client   = None

_MODEL   = "llama-3.3-70b-versatile"
_WHISPER = "whisper-large-v3"


# ── Arabic sanitizer ─────────────────────────────────────────────
def _sanitize(text: str, language: str) -> str:
    """Strip CJK characters that leak from multilingual LLM training data."""
    if language != "ar":
        return text
    cleaned = re.sub(
        r'[\u4e00-\u9fff'   # Chinese
        r'\u3040-\u309f'    # Hiragana
        r'\u30a0-\u30ff'    # Katakana
        r'\uac00-\ud7af'    # Korean Hangul
        r'\u3400-\u4dbf'    # CJK Extension A
        r'\u1100-\u11ff'    # Hangul Jamo
        r']+',
        '', text
    )
    return re.sub(r'  +', ' ', cleaned).strip()


# ── Chat wrapper ─────────────────────────────────────────────────
def _chat(messages, temperature=0.7, max_tokens=600,
          language="en") -> str:
    if not _USE_GROQ or not _client:
        return "AI unavailable — set GROQ_API_KEY in .env"
    r = _client.chat.completions.create(
        model=_MODEL, messages=messages,
        temperature=temperature, max_tokens=max_tokens)
    text = r.choices[0].message.content.strip()
    return _sanitize(text, language)


# ── System prompt ────────────────────────────────────────────────
def _sys(job_role, difficulty, interview_type, language, ctx=""):
    ar = language == "ar"
    if ar:
        li = (
            "⚠️ CRITICAL — LANGUAGE RULE (STRICTLY ENFORCED):\n"
            "• You MUST write EVERY word in Arabic (Modern Standard Arabic).\n"
            "• Do NOT use English, Chinese, Japanese, Korean, or any other script.\n"
            "• 100% Arabic output only. No exceptions.\n"
            "• أي كلمة غير عربية في ردودك تُعدّ خطأً فادحاً."
        )
    else:
        li = "Respond in English."

    dm = {
        "easy":   "friendly entry-level",
        "medium": "standard professional",
        "hard":   "challenging senior-level with probing follow-ups",
    }
    tm = {
        "behavioral": "STAR-method behavioral questions",
        "technical":  "technical knowledge and problem-solving",
        "mixed":      "a mix of behavioral and technical questions",
    }
    c = f"\n\nCANDIDATE PROFILE:\n{ctx}" if ctx else ""
    return (
        f"You are a professional {job_role} interviewer.\n\n"
        f"LANGUAGE:\n{li}\n\n"
        f"Difficulty: {dm.get(difficulty, 'standard')}\n"
        f"Focus: {tm.get(interview_type, 'mixed')}{c}\n\n"
        "Rules:\n"
        "- Ask ONE question at a time.\n"
        "- After 6-8 candidate responses, naturally wrap up.\n"
        "- When wrapping up, end your message with exactly: [INTERVIEW_COMPLETE]\n"
        "- Be professional and encouraging.\n"
    )


# ── Language enforcement injection ───────────────────────────────
def _enforce(language: str):
    """Injected before every AI call as the last message."""
    if language == "ar":
        return {
            "role": "user",
            "content": (
                "[تذكير: ردّك يجب أن يكون بالعربية فقط، "
                "لا تستخدم أي لغة أخرى.]"
            )
        }
    return None


def _parse_json(raw: str) -> dict:
    return json.loads(re.sub(r"```(?:json)?|```", "", raw).strip())


class InterviewAIService:

    def start_interview(self, job_role, difficulty, interview_type,
                        language="en", user_context="") -> Dict:
        try:
            if language == "ar":
                p = "ابدأ المقابلة. قدم نفسك واطرح سؤالك الأول باللغة العربية فقط."
            else:
                p = "Begin the interview. Introduce yourself briefly and ask your first question."

            messages = [
                {"role": "system", "content": _sys(job_role, difficulty,
                    interview_type, language, user_context)},
                {"role": "user",   "content": p},
            ]
            e = _enforce(language)
            if e: messages.append(e)

            msg = _chat(messages, language=language)
            return {"success": True, "message": msg}
        except Exception as ex:
            return {"success": False, "error": str(ex)}

    def get_next_question(self, job_role, difficulty, interview_type,
                          history, language="en", user_context="") -> Dict:
        try:
            messages = [
                {"role": "system", "content": _sys(job_role, difficulty,
                    interview_type, language, user_context)},
                *history,
            ]
            e = _enforce(language)
            if e: messages.append(e)

            msg  = _chat(messages, max_tokens=500, language=language)
            done = "[INTERVIEW_COMPLETE]" in msg
            return {
                "success":  True,
                "message":  msg.replace("[INTERVIEW_COMPLETE]", "").strip(),
                "is_done":  done,
            }
        except Exception as ex:
            return {"success": False, "error": str(ex), "is_done": False}

    def evaluate_answer(self, question, answer, job_role,
                        difficulty, language="en") -> Dict:
        try:
            li = "Respond in Arabic." if language == "ar" else "Respond in English."
            raw = _chat([{"role": "user", "content":
                f"{li}\nEvaluate this {job_role} interview answer ({difficulty} level).\n"
                f"Question: {question}\nAnswer: {answer}\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"score":<1-10>,"strengths":["..."],'
                '"improvements":["..."],"brief_feedback":"..."}'}],
                temperature=0.3, max_tokens=350, language=language)
            return {"success": True, "evaluation": _parse_json(raw)}
        except Exception:
            return {"success": True, "evaluation": {
                "score": 5, "strengths": [], "improvements": [],
                "brief_feedback": "Noted."}}

    def generate_final_feedback(self, job_role, difficulty, interview_type,
                                 qa_pairs, language="en") -> Dict:
        try:
            li = (
                "Respond entirely in Arabic (Modern Standard Arabic)."
                if language == "ar"
                else "Respond in English."
            )
            summary = "\n".join(
                f"Q{i+1}: {p['question'][:100]}\n"
                f"A: {p['answer'][:180]}\n"
                f"Score: {p.get('score','?')}/10"
                for i, p in enumerate(qa_pairs[:8])
            )
            raw = _chat([{"role": "user", "content":
                f"{li}\nGenerate final feedback for "
                f"{job_role} ({difficulty} {interview_type}).\n\n"
                f"{summary}\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"overall_score":<0-100>,"grade":"A|B|C|D|F","summary":"...",'
                '"top_strengths":["..."],"areas_to_improve":["..."],'
                '"action_items":["..."],'
                '"recommendation":"Ready to hire|Needs practice|Not ready"}'}],
                temperature=0.4, max_tokens=700, language=language)
            return {"success": True, "feedback": _parse_json(raw)}
        except Exception:
            return {"success": True, "feedback": {
                "overall_score": 50, "grade": "C",
                "summary": "Interview completed.",
                "top_strengths": [], "areas_to_improve": [],
                "action_items": [], "recommendation": "Needs practice"}}

    def transcribe_audio(self, file_path: str,
                         language: Optional[str] = None) -> Dict:
        try:
            if not _USE_GROQ or not _client:
                return {"success": False,
                        "error": "Groq not configured — set GROQ_API_KEY"}
            kw = {"model": _WHISPER, "response_format": "json"}
            if language:
                kw["language"] = language
            with open(file_path, "rb") as f:
                result = _client.audio.transcriptions.create(file=f, **kw)
            return {"success": True, "text": (result.text or "").strip()}
        except Exception as e:
            return {"success": False, "error": str(e)}


interview_ai_service = InterviewAIService()