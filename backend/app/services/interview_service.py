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


def _chat(messages, temperature=0.7, max_tokens=600) -> str:
    if not _USE_GROQ or not _client:
        return "AI unavailable — set GROQ_API_KEY in .env"
    r = _client.chat.completions.create(
        model=_MODEL, messages=messages,
        temperature=temperature, max_tokens=max_tokens)
    return r.choices[0].message.content.strip()


def _sys(job_role, difficulty, interview_type, language, ctx=""):
    ar = language == "ar"
    li = ("IMPORTANT: You MUST respond entirely in Arabic. All text must be Arabic."
          if ar else "Respond in English.")
    dm = {"easy": "friendly entry-level", "medium": "standard professional",
          "hard": "challenging senior-level with probing follow-ups"}
    tm = {"behavioral": "STAR-method behavioral questions",
          "technical":  "technical knowledge and problem-solving",
          "mixed":      "a mix of behavioral and technical questions"}
    c  = f"\n\nCANDIDATE PROFILE:\n{ctx}" if ctx else ""
    return (
        f"You are a professional {job_role} interviewer.\n{li}\n\n"
        f"Difficulty: {dm.get(difficulty,'standard')}\n"
        f"Focus: {tm.get(interview_type,'mixed')}{c}\n\n"
        "Rules:\n"
        "- Ask ONE question at a time.\n"
        "- After 6-8 candidate responses, naturally wrap up and say you will provide feedback.\n"
        "- When wrapping up, end your message with exactly: [INTERVIEW_COMPLETE]\n"
        "- Be professional and encouraging.\n"
    )


def _parse_json(raw: str) -> dict:
    return json.loads(re.sub(r"```(?:json)?|```", "", raw).strip())


class InterviewAIService:

    def start_interview(self, job_role, difficulty, interview_type,
                        language="en", user_context="") -> Dict:
        try:
            p = ("ابدأ المقابلة. قدم نفسك واطرح سؤالك الأول."
                 if language == "ar"
                 else "Begin the interview. Introduce yourself briefly and ask your first question.")
            msg = _chat([{"role": "system", "content": _sys(job_role, difficulty, interview_type, language, user_context)},
                         {"role": "user",   "content": p}])
            return {"success": True, "message": msg}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def get_next_question(self, job_role, difficulty, interview_type,
                          history, language="en", user_context="") -> Dict:
        try:
            msgs = [{"role": "system", "content": _sys(job_role, difficulty, interview_type, language, user_context)}] + history
            msg  = _chat(msgs, max_tokens=500)
            done = "[INTERVIEW_COMPLETE]" in msg
            return {"success": True, "message": msg.replace("[INTERVIEW_COMPLETE]", "").strip(), "is_done": done}
        except Exception as e:
            return {"success": False, "error": str(e), "is_done": False}

    def evaluate_answer(self, question, answer, job_role, difficulty, language="en") -> Dict:
        try:
            li = "Respond in Arabic." if language == "ar" else "Respond in English."
            raw = _chat([{"role": "user", "content":
                f"{li}\nEvaluate this {job_role} interview answer ({difficulty} level).\n"
                f"Question: {question}\nAnswer: {answer}\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"score":<1-10>,"strengths":["..."],"improvements":["..."],"brief_feedback":"..."}'}],
                temperature=0.3, max_tokens=350)
            return {"success": True, "evaluation": _parse_json(raw)}
        except Exception:
            return {"success": True, "evaluation": {"score": 5, "strengths": [], "improvements": [], "brief_feedback": "Noted."}}

    def generate_final_feedback(self, job_role, difficulty, interview_type,
                                 qa_pairs, language="en") -> Dict:
        try:
            li = "Respond entirely in Arabic." if language == "ar" else "Respond in English."
            summary = "\n".join(
                f"Q{i+1}: {p['question'][:100]}\nA: {p['answer'][:180]}\nScore: {p.get('score','?')}/10"
                for i, p in enumerate(qa_pairs[:8]))
            raw = _chat([{"role": "user", "content":
                f"{li}\nGenerate final feedback for {job_role} ({difficulty} {interview_type}).\n\n"
                f"{summary}\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"overall_score":<0-100>,"grade":"A|B|C|D|F","summary":"...","top_strengths":["..."],'
                '"areas_to_improve":["..."],"action_items":["..."],"recommendation":"Ready to hire|Needs practice|Not ready"}'}],
                temperature=0.4, max_tokens=700)
            return {"success": True, "feedback": _parse_json(raw)}
        except Exception:
            return {"success": True, "feedback": {
                "overall_score": 50, "grade": "C", "summary": "Interview completed.",
                "top_strengths": [], "areas_to_improve": [], "action_items": [],
                "recommendation": "Needs practice"}}

    def transcribe_audio(self, file_path: str, language: Optional[str] = None) -> Dict:
        try:
            if not _USE_GROQ or not _client:
                return {"success": False, "error": "Groq not configured — set GROQ_API_KEY"}
            kw = {"model": _WHISPER, "response_format": "json"}
            if language:
                kw["language"] = language
            with open(file_path, "rb") as f:
                result = _client.audio.transcriptions.create(file=f, **kw)
            return {"success": True, "text": (result.text or "").strip()}
        except Exception as e:
            return {"success": False, "error": str(e)}


interview_ai_service = InterviewAIService()