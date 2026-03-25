# app/services/interview_ai_service.py
# CHANGES vs original:
#   1. _system_prompt() accepts goal_context parameter — appended to system prompt
#   2. start_interview() accepts goal_context parameter
#   3. process_message() accepts goal_context parameter
#   4. When goal_context is present, next-step coaching is appended at end of feedback
#   Everything else (retry logic, Arabic sanitizer, evaluation) is unchanged.

import json
import os
import re
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


# ── Arabic sanitizer ─────────────────────────────────────────────
def _sanitize_arabic(text: str) -> str:
    """Remove CJK characters that leak from multilingual LLM training data."""
    cleaned = re.sub(
        r'[\u4e00-\u9fff'      # CJK Unified Ideographs (Chinese)
        r'\u3040-\u309f'       # Hiragana (Japanese)
        r'\u30a0-\u30ff'       # Katakana (Japanese)
        r'\uac00-\ud7af'       # Hangul (Korean)
        r'\u3400-\u4dbf'       # CJK Extension A
        r'\u1100-\u11ff'       # Hangul Jamo
        r']+',
        '', text
    )
    return re.sub(r'  +', ' ', cleaned).strip()


# ── System prompt ────────────────────────────────────────────────
def _system_prompt(
    job_role:        str,
    difficulty:      str,
    interview_type:  str,
    language:        str,
    resume_text:     str = "",
    job_description: str = "",
    goal_context:    str = "",     # ← NEW: injected goal+history context
) -> str:

    if language == "ar":
        lang_instruction = (
            "⚠️ CRITICAL LANGUAGE RULE — STRICTLY ENFORCED:\n"
            "• You MUST write EVERY word in Arabic (Modern Standard Arabic / العربية الفصحى).\n"
            "• Do NOT use English, Chinese, Japanese, Korean, or ANY other language.\n"
            "• Do NOT mix languages. 100% Arabic output only.\n"
            "• If you cannot express something in Arabic, find an Arabic equivalent.\n"
            "• أي كلمة غير عربية في ردودك تُعدّ خطأً فادحاً."
        )
    else:
        lang_instruction = "Respond exclusively in clear, professional English."

    difficulty_map = {
        "easy":         "Ask straightforward, entry-level questions. Be encouraging.",
        "medium":       "Ask standard interview questions. Be professional.",
        "intermediate": "Ask standard professional questions. Be thorough.",
        "hard":         "Ask challenging questions. Probe deeply with follow-ups.",
    }
    type_map = {
        "behavioral": "Focus on behavioral questions (STAR method).",
        "technical":  f"Focus on technical questions for {job_role}.",
        "mixed":      "Mix behavioral and technical questions.",
    }

    resume_section = (
        f"\n\nCANDIDATE RESUME:\n{resume_text[:1500]}" if resume_text else ""
    )
    jd_section = (
        f"\n\nJOB DESCRIPTION:\n{job_description[:800]}" if job_description else ""
    )

    # ── Goal context block ───────────────────────────────────────
    # Injected only when interview is started from a goal.
    # Contains: target role/company, session #, previous weaknesses,
    # score trend, week progress. Tells AI exactly what to focus on.
    goal_section = (
        f"\n\n{goal_context}" if goal_context else ""
    )

    # ── Rules: base + extra rules if goal context is present ────
    goal_rules = ""
    if goal_context:
        if language == "ar":
            goal_rules = (
                "\n- هذا المرشح يتدرب لهدف محدد — ركّز على نقاط الضعف المذكورة أعلاه."
                "\n- اطرح أسئلة متعمقة في مجالات الضعف تحديداً."
                "\n- اضبط الصعوبة بناءً على اتجاه الأداء في الجلسات السابقة."
                "\n- في نهاية المقابلة، قدّم نصيحة واحدة ملموسة تخص هذا الهدف تحديداً."
            )
        else:
            goal_rules = (
                "\n- This candidate is preparing for a specific goal — probe their listed weak areas."
                "\n- Ask targeted follow-up questions in those weak areas, not generic ones."
                "\n- Adjust difficulty based on their score trend across sessions."
                "\n- At the end, give ONE concrete actionable piece of advice specific to their goal."
            )

    return (
        f"You are a {job_role} interviewer. Conduct a real {difficulty} "
        f"{interview_type} interview.\n\n"
        f"LANGUAGE:\n{lang_instruction}\n\n"
        f"DIFFICULTY: {difficulty_map.get(difficulty, difficulty_map['medium'])}\n"
        f"TYPE: {type_map.get(interview_type, type_map['mixed'])}\n\n"
        "RULES:\n"
        "- Ask ONE question at a time. Keep responses SHORT (2-4 sentences max).\n"
        "- Never ask multiple questions in one turn.\n"
        "- After 7 user answers, wrap up with brief feedback.\n"
        "- Never break character. Never mention AI or text.\n"
        "- This is voice — speak naturally and concisely."
        f"{goal_rules}"
        f"{resume_section}"
        f"{jd_section}"
        f"{goal_section}\n\n"
        "Start with a brief greeting and your first question."
    )


# ── Reinforcement message injected before every API call ─────────
def _lang_enforce_msg(language: str) -> Optional[Dict]:
    if language == "ar":
        return {
            "role": "user",
            "content": (
                "[تذكير نظام: يجب أن يكون ردك بالكامل باللغة العربية فقط. "
                "لا تستخدم أي لغة أخرى أبداً.]"
            )
        }
    return None


# ── Per-answer evaluation ────────────────────────────────────────
def _evaluate_answer(question: str, answer: str,
                     job_role: str, language: str) -> Dict:
    lang = "Arabic" if language == "ar" else "English"
    prompt = (
        f"Evaluate this interview answer briefly. Respond in {lang}.\n"
        f"Job Role: {job_role}\nQuestion: {question}\nAnswer: {answer}\n\n"
        f"Return ONLY valid JSON (no markdown):\n"
        '{"score":<1-10>,"strengths":["<point>"],'
        '"improvements":["<point>"],"tip":"<one tip>"}'
    )
    try:
        r = client.chat.completions.create(
            model=CHAT_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            max_tokens=200,
        )
        text = r.choices[0].message.content.strip()
        text = re.sub(r"```(?:json)?|```", "", text).strip()
        return json.loads(text)
    except Exception:
        return {"score": 5, "strengths": [], "improvements": [], "tip": ""}


# ── Retry wrapper ────────────────────────────────────────────────
def _chat(messages: list, temperature: float = 0.7,
          max_tokens: int = 300, language: str = "en") -> str:
    last_error = None
    for attempt in range(3):
        try:
            r = client.chat.completions.create(
                model=CHAT_MODEL,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
            )
            text = r.choices[0].message.content.strip()
            if language == "ar":
                text = _sanitize_arabic(text)
            return text
        except Exception as e:
            last_error = e
            if attempt < 2:
                time.sleep(1.0 * (attempt + 1))
    raise last_error


class InterviewAIService:

    # ── Start interview ──────────────────────────────────────────
    def start_interview(
        self,
        job_role:        str,
        difficulty:      str,
        interview_type:  str,
        language:        str  = "en",
        resume_text:     str  = "",
        job_description: str  = "",
        goal_context:    str  = "",   # ← NEW
    ) -> Dict:
        """
        Generate the opening greeting + first question.
        When goal_context is provided, the AI is primed with the candidate's
        goal, target company, weak areas from previous sessions, and score trend.
        """
        system = _system_prompt(
            job_role, difficulty, interview_type, language,
            resume_text, job_description,
            goal_context=goal_context,   # ← NEW
        )
        messages = [
            {"role": "system", "content": system},
            {"role": "user",   "content": "Begin the interview."},
        ]
        enforce = _lang_enforce_msg(language)
        if enforce:
            messages.append(enforce)

        try:
            message = _chat(messages, temperature=0.7,
                            max_tokens=200, language=language)
            return {"success": True, "message": message}
        except Exception as e:
            return {"success": False, "error": str(e), "message": ""}

    # ── Process message ──────────────────────────────────────────
    def process_message(
        self,
        history:         List[Dict],
        user_message:    str,
        job_role:        str,
        difficulty:      str,
        interview_type:  str,
        language:        str  = "en",
        resume_text:     str  = "",
        job_description: str  = "",
        user_msg_count:  int  = 0,
        goal_context:    str  = "",   # ← NEW
    ) -> Dict:
        """
        Process one user turn and return AI response + per-answer evaluation.
        Goal context is re-injected on every turn so the AI never forgets
        what weak areas to probe.
        """
        system = _system_prompt(
            job_role, difficulty, interview_type, language,
            resume_text, job_description,
            goal_context=goal_context,   # ← NEW
        )

        # Per-answer evaluation
        evaluation: Optional[Dict] = None
        if history:
            last_ai_q = next(
                (m["content"] for m in reversed(history)
                 if m["role"] == "assistant"), ""
            )
            if last_ai_q:
                try:
                    evaluation = _evaluate_answer(
                        last_ai_q, user_message, job_role, language)
                except Exception:
                    evaluation = None

        should_end = user_msg_count >= 7

        messages = [
            {"role": "system", "content": system},
            *history,
            {"role": "user", "content": user_message},
        ]

        if should_end:
            close = (
                "أنهِ المقابلة بإيجاز وشكر المرشح."
                if language == "ar"
                else "Briefly close the interview and thank the candidate in 2-3 sentences."
            )
            messages.append({"role": "user", "content": close})

        enforce = _lang_enforce_msg(language)
        if enforce:
            messages.append(enforce)

        try:
            message = _chat(messages, temperature=0.7,
                            max_tokens=250, language=language)
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

    # ── Final feedback ───────────────────────────────────────────
    def generate_final_feedback(
        self,
        history:      List[Dict],
        job_role:     str,
        language:     str           = "en",
        score:        Optional[float] = None,
        goal_context: str           = "",   # ← NEW: used to add goal-specific next steps
    ) -> Dict:
        """
        Generate structured end-of-session feedback.
        When goal_context is provided, the feedback includes a dedicated
        'goal_next_steps' field with advice specific to the user's goal.
        """
        lang         = "Arabic" if language == "ar" else "English"
        conversation = "\n".join(
            f"{m['role'].upper()}: {m['content']}" for m in history
        )

        # Goal-specific instruction for feedback
        goal_feedback_instruction = ""
        if goal_context:
            if language == "ar":
                goal_feedback_instruction = (
                    "\n\nسياق الهدف:\n" + goal_context[:600] +
                    "\n\nبناءً على هذا الهدف، أضف حقل 'goal_next_steps' في JSON "
                    "يحتوي على 2-3 خطوات عملية ومحددة للجلسة القادمة."
                )
            else:
                goal_feedback_instruction = (
                    "\n\nGoal Context:\n" + goal_context[:600] +
                    "\n\nBased on this goal context, add a 'goal_next_steps' field "
                    "to the JSON with 2-3 concrete, specific actions for the next session."
                )

        prompt = (
            f"Analyze this {job_role} interview. Give a report in {lang}.\n\n"
            f"CONVERSATION:\n{conversation[:3000]}"
            f"{goal_feedback_instruction}\n\n"
            f"Return ONLY valid JSON (no markdown):\n"
            '{{"overall_score":<0-100>,"summary":"<2-3 sentence assessment>",'
            '"strengths":["<strength>"],"areas_for_improvement":["<area>"],'
            '"communication_score":<0-100>,"technical_score":<0-100>,'
            '"confidence_score":<0-100>,"recommended_resources":["<resource>"],'
            '"next_steps":["<action>"],"goal_next_steps":["<goal-specific action>"]}}'
        )
        try:
            text = _chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=700,        # slightly more to fit goal_next_steps
                language=language,
            )
            text     = re.sub(r"```(?:json)?|```", "", text).strip()
            feedback = json.loads(text)
            return {
                "success":  True,
                "feedback": feedback,
                "score":    feedback.get("overall_score", score or 70),
            }
        except Exception as e:
            return {
                "success":  False,
                "error":    str(e),
                "feedback": {},
                "score":    score or 70,
            }