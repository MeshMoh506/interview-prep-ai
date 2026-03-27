# # app/services/interview_ai_service.py
# # CHANGES vs original:
# #   1. _system_prompt() accepts goal_context parameter — appended to system prompt
# #   2. start_interview() accepts goal_context parameter
# #   3. process_message() accepts goal_context parameter
# #   4. When goal_context is present, next-step coaching is appended at end of feedback
# #   Everything else (retry logic, Arabic sanitizer, evaluation) is unchanged.

# import json
# import os
# import re
# import time
# from groq import Groq
# from typing import Dict, List, Optional

# from app.config import settings

# client = Groq(
#     api_key=settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", ""),
#     max_retries=3,
#     timeout=30.0,
# )
# CHAT_MODEL = "llama-3.3-70b-versatile"


# # ── Arabic sanitizer ─────────────────────────────────────────────
# def _sanitize_arabic(text: str) -> str:
#     """Remove CJK characters that leak from multilingual LLM training data."""
#     cleaned = re.sub(
#         r'[\u4e00-\u9fff'      # CJK Unified Ideographs (Chinese)
#         r'\u3040-\u309f'       # Hiragana (Japanese)
#         r'\u30a0-\u30ff'       # Katakana (Japanese)
#         r'\uac00-\ud7af'       # Hangul (Korean)
#         r'\u3400-\u4dbf'       # CJK Extension A
#         r'\u1100-\u11ff'       # Hangul Jamo
#         r']+',
#         '', text
#     )
#     return re.sub(r'  +', ' ', cleaned).strip()


# # ── System prompt ────────────────────────────────────────────────
# def _system_prompt(
#     job_role:        str,
#     difficulty:      str,
#     interview_type:  str,
#     language:        str,
#     resume_text:     str = "",
#     job_description: str = "",
#     goal_context:    str = "",     # ← NEW: injected goal+history context
# ) -> str:

#     if language == "ar":
#         lang_instruction = (
#             "⚠️ CRITICAL LANGUAGE RULE — STRICTLY ENFORCED:\n"
#             "• You MUST write EVERY word in Arabic (Modern Standard Arabic / العربية الفصحى).\n"
#             "• Do NOT use English, Chinese, Japanese, Korean, or ANY other language.\n"
#             "• Do NOT mix languages. 100% Arabic output only.\n"
#             "• If you cannot express something in Arabic, find an Arabic equivalent.\n"
#             "• أي كلمة غير عربية في ردودك تُعدّ خطأً فادحاً."
#         )
#     else:
#         lang_instruction = "Respond exclusively in clear, professional English."

#     difficulty_map = {
#         "easy":         "Ask straightforward, entry-level questions. Be encouraging.",
#         "medium":       "Ask standard interview questions. Be professional.",
#         "intermediate": "Ask standard professional questions. Be thorough.",
#         "hard":         "Ask challenging questions. Probe deeply with follow-ups.",
#     }
#     type_map = {
#         "behavioral": "Focus on behavioral questions (STAR method).",
#         "technical":  f"Focus on technical questions for {job_role}.",
#         "mixed":      "Mix behavioral and technical questions.",
#     }

#     resume_section = (
#         f"\n\nCANDIDATE RESUME:\n{resume_text[:1500]}" if resume_text else ""
#     )
#     jd_section = (
#         f"\n\nJOB DESCRIPTION:\n{job_description[:800]}" if job_description else ""
#     )

#     # ── Goal context block ───────────────────────────────────────
#     # Injected only when interview is started from a goal.
#     # Contains: target role/company, session #, previous weaknesses,
#     # score trend, week progress. Tells AI exactly what to focus on.
#     goal_section = (
#         f"\n\n{goal_context}" if goal_context else ""
#     )

#     # ── Rules: base + extra rules if goal context is present ────
#     goal_rules = ""
#     if goal_context:
#         if language == "ar":
#             goal_rules = (
#                 "\n- هذا المرشح يتدرب لهدف محدد — ركّز على نقاط الضعف المذكورة أعلاه."
#                 "\n- اطرح أسئلة متعمقة في مجالات الضعف تحديداً."
#                 "\n- اضبط الصعوبة بناءً على اتجاه الأداء في الجلسات السابقة."
#                 "\n- في نهاية المقابلة، قدّم نصيحة واحدة ملموسة تخص هذا الهدف تحديداً."
#             )
#         else:
#             goal_rules = (
#                 "\n- This candidate is preparing for a specific goal — probe their listed weak areas."
#                 "\n- Ask targeted follow-up questions in those weak areas, not generic ones."
#                 "\n- Adjust difficulty based on their score trend across sessions."
#                 "\n- At the end, give ONE concrete actionable piece of advice specific to their goal."
#             )

#     return (
#         f"You are a {job_role} interviewer. Conduct a real {difficulty} "
#         f"{interview_type} interview.\n\n"
#         f"LANGUAGE:\n{lang_instruction}\n\n"
#         f"DIFFICULTY: {difficulty_map.get(difficulty, difficulty_map['medium'])}\n"
#         f"TYPE: {type_map.get(interview_type, type_map['mixed'])}\n\n"
#         "RULES:\n"
#         "- Ask ONE question at a time. Keep responses SHORT (2-4 sentences max).\n"
#         "- Never ask multiple questions in one turn.\n"
#         "- After 7 user answers, wrap up with brief feedback.\n"
#         "- Never break character. Never mention AI or text.\n"
#         "- This is voice — speak naturally and concisely."
#         f"{goal_rules}"
#         f"{resume_section}"
#         f"{jd_section}"
#         f"{goal_section}\n\n"
#         "Start with a brief greeting and your first question."
#     )


# # ── Reinforcement message injected before every API call ─────────
# def _lang_enforce_msg(language: str) -> Optional[Dict]:
#     if language == "ar":
#         return {
#             "role": "user",
#             "content": (
#                 "[تذكير نظام: يجب أن يكون ردك بالكامل باللغة العربية فقط. "
#                 "لا تستخدم أي لغة أخرى أبداً.]"
#             )
#         }
#     return None


# # ── Per-answer evaluation ────────────────────────────────────────
# def _evaluate_answer(question: str, answer: str,
#                      job_role: str, language: str) -> Dict:
#     lang = "Arabic" if language == "ar" else "English"
#     prompt = (
#         f"Evaluate this interview answer briefly. Respond in {lang}.\n"
#         f"Job Role: {job_role}\nQuestion: {question}\nAnswer: {answer}\n\n"
#         f"Return ONLY valid JSON (no markdown):\n"
#         '{"score":<1-10>,"strengths":["<point>"],'
#         '"improvements":["<point>"],"tip":"<one tip>"}'
#     )
#     try:
#         r = client.chat.completions.create(
#             model=CHAT_MODEL,
#             messages=[{"role": "user", "content": prompt}],
#             temperature=0.3,
#             max_tokens=200,
#         )
#         text = r.choices[0].message.content.strip()
#         text = re.sub(r"```(?:json)?|```", "", text).strip()
#         return json.loads(text)
#     except Exception:
#         return {"score": 5, "strengths": [], "improvements": [], "tip": ""}


# # ── Retry wrapper ────────────────────────────────────────────────
# def _chat(messages: list, temperature: float = 0.7,
#           max_tokens: int = 300, language: str = "en") -> str:
#     last_error = None
#     for attempt in range(3):
#         try:
#             r = client.chat.completions.create(
#                 model=CHAT_MODEL,
#                 messages=messages,
#                 temperature=temperature,
#                 max_tokens=max_tokens,
#             )
#             text = r.choices[0].message.content.strip()
#             if language == "ar":
#                 text = _sanitize_arabic(text)
#             return text
#         except Exception as e:
#             last_error = e
#             if attempt < 2:
#                 time.sleep(1.0 * (attempt + 1))
#     raise last_error


# class InterviewAIService:

#     # ── Start interview ──────────────────────────────────────────
#     def start_interview(
#         self,
#         job_role:        str,
#         difficulty:      str,
#         interview_type:  str,
#         language:        str  = "en",
#         resume_text:     str  = "",
#         job_description: str  = "",
#         goal_context:    str  = "",   # ← NEW
#     ) -> Dict:
#         """
#         Generate the opening greeting + first question.
#         When goal_context is provided, the AI is primed with the candidate's
#         goal, target company, weak areas from previous sessions, and score trend.
#         """
#         system = _system_prompt(
#             job_role, difficulty, interview_type, language,
#             resume_text, job_description,
#             goal_context=goal_context,   # ← NEW
#         )
#         messages = [
#             {"role": "system", "content": system},
#             {"role": "user",   "content": "Begin the interview."},
#         ]
#         enforce = _lang_enforce_msg(language)
#         if enforce:
#             messages.append(enforce)

#         try:
#             message = _chat(messages, temperature=0.7,
#                             max_tokens=200, language=language)
#             return {"success": True, "message": message}
#         except Exception as e:
#             return {"success": False, "error": str(e), "message": ""}

#     # ── Process message ──────────────────────────────────────────
#     def process_message(
#         self,
#         history:         List[Dict],
#         user_message:    str,
#         job_role:        str,
#         difficulty:      str,
#         interview_type:  str,
#         language:        str  = "en",
#         resume_text:     str  = "",
#         job_description: str  = "",
#         user_msg_count:  int  = 0,
#         goal_context:    str  = "",   # ← NEW
#     ) -> Dict:
#         """
#         Process one user turn and return AI response + per-answer evaluation.
#         Goal context is re-injected on every turn so the AI never forgets
#         what weak areas to probe.
#         """
#         system = _system_prompt(
#             job_role, difficulty, interview_type, language,
#             resume_text, job_description,
#             goal_context=goal_context,   # ← NEW
#         )

#         # Per-answer evaluation
#         evaluation: Optional[Dict] = None
#         if history:
#             last_ai_q = next(
#                 (m["content"] for m in reversed(history)
#                  if m["role"] == "assistant"), ""
#             )
#             if last_ai_q:
#                 try:
#                     evaluation = _evaluate_answer(
#                         last_ai_q, user_message, job_role, language)
#                 except Exception:
#                     evaluation = None

#         should_end = user_msg_count >= 7

#         messages = [
#             {"role": "system", "content": system},
#             *history,
#             {"role": "user", "content": user_message},
#         ]

#         if should_end:
#             close = (
#                 "أنهِ المقابلة بإيجاز وشكر المرشح."
#                 if language == "ar"
#                 else "Briefly close the interview and thank the candidate in 2-3 sentences."
#             )
#             messages.append({"role": "user", "content": close})

#         enforce = _lang_enforce_msg(language)
#         if enforce:
#             messages.append(enforce)

#         try:
#             message = _chat(messages, temperature=0.7,
#                             max_tokens=250, language=language)
#             return {
#                 "success":    True,
#                 "message":    message,
#                 "evaluation": evaluation,
#                 "should_end": should_end,
#             }
#         except Exception as e:
#             return {
#                 "success":    False,
#                 "error":      str(e),
#                 "message":    "",
#                 "evaluation": evaluation,
#                 "should_end": False,
#             }

#     # ── Final feedback ───────────────────────────────────────────
#     def generate_final_feedback(
#         self,
#         history:      List[Dict],
#         job_role:     str,
#         language:     str           = "en",
#         score:        Optional[float] = None,
#         goal_context: str           = "",   # ← NEW: used to add goal-specific next steps
#     ) -> Dict:
#         """
#         Generate structured end-of-session feedback.
#         When goal_context is provided, the feedback includes a dedicated
#         'goal_next_steps' field with advice specific to the user's goal.
#         """
#         lang         = "Arabic" if language == "ar" else "English"
#         conversation = "\n".join(
#             f"{m['role'].upper()}: {m['content']}" for m in history
#         )

#         # Goal-specific instruction for feedback
#         goal_feedback_instruction = ""
#         if goal_context:
#             if language == "ar":
#                 goal_feedback_instruction = (
#                     "\n\nسياق الهدف:\n" + goal_context[:600] +
#                     "\n\nبناءً على هذا الهدف، أضف حقل 'goal_next_steps' في JSON "
#                     "يحتوي على 2-3 خطوات عملية ومحددة للجلسة القادمة."
#                 )
#             else:
#                 goal_feedback_instruction = (
#                     "\n\nGoal Context:\n" + goal_context[:600] +
#                     "\n\nBased on this goal context, add a 'goal_next_steps' field "
#                     "to the JSON with 2-3 concrete, specific actions for the next session."
#                 )

#         prompt = (
#             f"Analyze this {job_role} interview. Give a report in {lang}.\n\n"
#             f"CONVERSATION:\n{conversation[:3000]}"
#             f"{goal_feedback_instruction}\n\n"
#             f"Return ONLY valid JSON (no markdown):\n"
#             '{{"overall_score":<0-100>,"summary":"<2-3 sentence assessment>",'
#             '"strengths":["<strength>"],"areas_for_improvement":["<area>"],'
#             '"communication_score":<0-100>,"technical_score":<0-100>,'
#             '"confidence_score":<0-100>,"recommended_resources":["<resource>"],'
#             '"next_steps":["<action>"],"goal_next_steps":["<goal-specific action>"]}}'
#         )
#         try:
#             text = _chat(
#                 messages=[{"role": "user", "content": prompt}],
#                 temperature=0.3,
#                 max_tokens=700,        # slightly more to fit goal_next_steps
#                 language=language,
#             )
#             text     = re.sub(r"```(?:json)?|```", "", text).strip()
#             feedback = json.loads(text)
#             return {
#                 "success":  True,
#                 "feedback": feedback,
#                 "score":    feedback.get("overall_score", score or 70),
#             }
#         except Exception as e:
#             return {
#                 "success":  False,
#                 "error":    str(e),
#                 "feedback": {},
#                 "score":    score or 70,
#             }
# app/services/interview_ai_service.py
# app/services/interview_ai_service.py
# app/services/interview_ai_service.py
# Complete version — all methods interviews.py depends on are present:
#   start_interview(), process_message(), generate_final_feedback()
# generate_final_feedback accepts both history= and qa_pairs= call styles.

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
    cleaned = re.sub(
        r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff'
        r'\uac00-\ud7af\u3400-\u4dbf\u1100-\u11ff]+',
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
    goal_context:    str = "",
) -> str:
    if language == "ar":
        lang_instruction = (
            "⚠️ CRITICAL LANGUAGE RULE — STRICTLY ENFORCED:\n"
            "• You MUST write EVERY word in Arabic (Modern Standard Arabic).\n"
            "• Do NOT use English, Chinese, Japanese, Korean, or ANY other language.\n"
            "• 100% Arabic output only. أي كلمة غير عربية تُعدّ خطأً فادحاً."
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

    goal_rules = ""
    if goal_context:
        goal_rules = (
            "\n- هذا المرشح يتدرب لهدف محدد — ركّز على نقاط الضعف المذكورة."
            if language == "ar" else
            "\n- This candidate prepares for a specific goal — probe their weak areas."
            "\n- Calibrate difficulty based on their score trend."
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
        f"{f'{chr(10)}{chr(10)}CANDIDATE RESUME:{chr(10)}{resume_text[:1500]}' if resume_text else ''}"
        f"{f'{chr(10)}{chr(10)}JOB DESCRIPTION:{chr(10)}{job_description[:800]}' if job_description else ''}"
        f"{f'{chr(10)}{chr(10)}{goal_context}' if goal_context else ''}"
        "\n\nStart with a brief greeting and your first question."
    )


def _lang_enforce_msg(language: str) -> Optional[Dict]:
    if language == "ar":
        return {"role": "user", "content":
                "[تذكير نظام: يجب أن يكون ردك بالكامل باللغة العربية فقط.]"}
    return None


def _evaluate_answer(question: str, answer: str,
                     job_role: str, language: str) -> Dict:
    lang = "Arabic" if language == "ar" else "English"
    prompt = (
        f"Evaluate this interview answer briefly. Respond in {lang}.\n"
        f"Job Role: {job_role}\nQuestion: {question}\nAnswer: {answer}\n\n"
        "Return ONLY valid JSON (no markdown):\n"
        '{"score":<1-10>,"strengths":["<point>"],"improvements":["<point>"],"tip":"<one tip>"}'
    )
    try:
        r = client.chat.completions.create(
            model=CHAT_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3, max_tokens=200,
        )
        text = re.sub(r"```(?:json)?|```", "", r.choices[0].message.content.strip()).strip()
        return json.loads(text)
    except Exception:
        return {"score": 5, "strengths": [], "improvements": [], "tip": ""}


def _chat(messages: list, temperature: float = 0.7,
          max_tokens: int = 300, language: str = "en") -> str:
    last_error = None
    for attempt in range(3):
        try:
            r = client.chat.completions.create(
                model=CHAT_MODEL, messages=messages,
                temperature=temperature, max_tokens=max_tokens,
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


def _parse_json(raw: str) -> dict:
    clean = re.sub(r"```(?:json)?|```", "", raw).strip()
    return json.loads(clean)


class InterviewAIService:

    # ── Start interview ──────────────────────────────────────────
    def start_interview(
        self,
        job_role:        str,
        difficulty:      str,
        interview_type:  str,
        language:        str = "en",
        resume_text:     str = "",
        job_description: str = "",
        goal_context:    str = "",
    ) -> Dict:
        system = _system_prompt(
            job_role, difficulty, interview_type, language,
            resume_text, job_description, goal_context=goal_context,
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
        language:        str = "en",
        resume_text:     str = "",
        job_description: str = "",
        user_msg_count:  int = 0,
        goal_context:    str = "",
    ) -> Dict:
        system = _system_prompt(
            job_role, difficulty, interview_type, language,
            resume_text, job_description, goal_context=goal_context,
        )

        evaluation: Optional[Dict] = None
        if history:
            last_ai_q = next(
                (m["content"] for m in reversed(history) if m["role"] == "assistant"), "")
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
            close = ("أنهِ المقابلة بإيجاز وشكر المرشح."
                     if language == "ar"
                     else "Briefly close the interview and thank the candidate in 2-3 sentences.")
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

    # ── Generate final feedback ──────────────────────────────────
    def generate_final_feedback(
        self,
        job_role:        str             = "",
        difficulty:      str             = "medium",
        interview_type:  str             = "mixed",
        qa_pairs:        Optional[List[Dict]] = None,
        language:        str             = "en",
        behavior_report: Optional[Dict]  = None,
        history:         Optional[List[Dict]] = None,  # ← accepts history= too
        score:           Optional[float] = None,
        goal_context:    str             = "",
    ) -> Dict:
        lang = "Write ALL text values in Arabic. Keep ALL JSON keys in English." \
               if language == "ar" else "Respond in English."

        # Convert history → qa_pairs if that's what was passed
        if qa_pairs is None and history:
            ai_msgs  = [m["content"] for m in history if m.get("role") == "assistant"]
            usr_msgs = [m["content"] for m in history if m.get("role") == "user"]
            qa_pairs = [{"question": q, "answer": a, "score": None}
                        for q, a in zip(ai_msgs, usr_msgs)]

        if not qa_pairs:
            return {"success": True, "feedback": _empty_feedback(language),
                    "score": 0}

        n = len(qa_pairs)
        qa_text = "\n\n".join(
            f"Q{i+1}: {q.get('question','')}\n"
            f"Answer: {q.get('answer','(no answer)')}\n"
            f"Score: {q.get('score','N/A')}/10"
            for i, q in enumerate(qa_pairs)
        )

        behavior_note = ""
        if behavior_report:
            cam = behavior_report.get("camera", {})
            voi = behavior_report.get("voice", {})
            behavior_note = (
                f"\nBehavior Analysis:\n"
                f"- Confidence: {cam.get('face_confidence','N/A')}%  "
                f"Nervousness: {cam.get('face_nervousness','N/A')}%\n"
                f"- Voice Confidence: {voi.get('voice_confidence','N/A')}%  "
                f"Filler words/answer: {voi.get('avg_filler_words','N/A')}\n"
                f"- Dominant emotion: {cam.get('dominant_emotion','N/A')}\n"
            )

        goal_note = f"\nGoal context:\n{goal_context[:400]}\n" if goal_context else ""

        prompt = f"""{lang}
You are a senior {job_role or 'professional'} interviewer. Generate a DETAILED, HONEST, SPECIFIC report.
Difficulty: {difficulty} | Type: {interview_type} | Questions answered: {n}
{behavior_note}{goal_note}
Interview Q&A:
{qa_text}

{"Note: Only " + str(n) + " question(s) answered — still provide honest specific feedback." if n <= 2 else ""}

Return ONLY valid JSON (no markdown):
{{
  "overall_score": <0-100>,
  "grade": "<A|B|C|D|F>",
  "grade_label": "<Excellent|Good|Average|Below Average|Poor>",
  "recommendation": "<Hire|Strong Consider|Consider|Needs Work|Not Ready>",
  "summary": "<3-4 honest sentences referencing actual answers>",
  "strengths": ["<specific with example>", "<specific>", "<specific>"],
  "areas_for_improvement": ["<specific + how to fix>", "<specific>", "<specific>"],
  "action_items": ["<concrete next step>", "<concrete>", "<concrete>"],
  "per_question_feedback": [
    {{"question_num": 1, "question": "<text>", "score": <1-10>,
      "what_was_good": "<text>", "what_to_improve": "<text>"}}
  ],
  "communication_score": <0-100>,
  "technical_score": <0-100>,
  "confidence_score": <0-100>,
  "best_answer_num": <1-{n}>,
  "weakest_answer_num": <1-{n}>,
  "overall_tip": "<one powerful tip for their next interview>"
}}"""

        try:
            raw = _chat([{"role": "user", "content": prompt}],
                        temperature=0.4, max_tokens=1500, language=language)
            fb = _parse_json(raw)
            for key in ("communication_score", "technical_score", "confidence_score"):
                if key in fb:
                    fb[key] = max(0, min(100, float(fb[key])))
            final_score = fb.get("overall_score", score or 50)
            return {"success": True, "feedback": fb, "score": final_score}
        except Exception as e:
            print(f"[Feedback] error: {e}")
            fb = _fallback_feedback(qa_pairs, language)
            return {"success": True, "feedback": fb,
                    "score": fb.get("overall_score", score or 50)}


def _empty_feedback(language: str) -> dict:
    is_ar = language == "ar"
    return {
        "overall_score": 0, "grade": "F", "grade_label": "Incomplete",
        "recommendation": "Not Ready",
        "summary": "لم يتم الإجابة على أي أسئلة." if is_ar
                   else "No questions were answered in this session.",
        "strengths": [], "areas_for_improvement": [], "action_items": [],
        "per_question_feedback": [],
        "communication_score": 0, "technical_score": 0, "confidence_score": 0,
        "best_answer_num": 1, "weakest_answer_num": 1,
        "overall_tip": "ابدأ بالإجابة على الأسئلة." if is_ar
                       else "Start by answering the questions.",
    }


def _fallback_feedback(qa_pairs: List[Dict], language: str) -> dict:
    is_ar = language == "ar"
    scores = [q.get("score", 5) for q in qa_pairs if q.get("score")]
    avg = int((sum(scores) / len(scores)) * 10) if scores else 50
    avg = max(0, min(100, avg))
    grade = "A" if avg >= 90 else "B" if avg >= 75 else "C" if avg >= 60 \
            else "D" if avg >= 50 else "F"
    return {
        "overall_score": avg, "grade": grade, "grade_label": "Average",
        "recommendation": "Consider",
        "summary": "أكمل المقابلة." if is_ar else "Interview completed.",
        "strengths": ["أكمل المقابلة" if is_ar else "Completed the interview"],
        "areas_for_improvement": ["تعمق أكثر في الإجابات" if is_ar
                                   else "Provide more detailed answers"],
        "action_items": ["مارس طريقة STAR" if is_ar else "Practice STAR method"],
        "per_question_feedback": [],
        "communication_score": 50, "technical_score": 50, "confidence_score": 50,
        "best_answer_num": 1, "weakest_answer_num": 1,
        "overall_tip": "استمر في الممارسة." if is_ar
                       else "Keep practicing consistently.",
    }


interview_ai_service = InterviewAIService()