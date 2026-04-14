# app/services/ai_memory_service.py
"""
AI Memory Service — living user profile that grows smarter over time.

After every interview or practice session, this service:
1. Reads the user's current ai_profile (plain text, max 800 chars)
2. Reads the session results (score, feedback, strengths, weaknesses, mode)
3. Calls Groq Llama to intelligently MERGE the new info into the profile
4. Writes the updated profile back to the database

The profile is then injected into every AI system prompt across the app,
making all AI features aware of what the user is good at and what they need
to work on — without repeating it in every conversation.

Profile format (English or Arabic based on user preference):
"User is preparing for [role].
 Strengths: [list]
 Weaknesses: [list — cleared when user shows improvement]
 Improving: [list]
 Stats: N interviews, avg X%, best Y%
 Last session: [brief summary]
 Practice patterns: [modes used, topics]"
"""

import logging
import os
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)

# ── Groq client (reuse the app-level one if available) ────────────
try:
    from groq import Groq
    _groq = Groq(api_key=os.getenv("GROQ_API_KEY", ""))
    _MODEL = "llama-3.3-70b-versatile"
except Exception:
    _groq = None
    _MODEL = None

_MAX_PROFILE_CHARS = 900   # keep profile concise — fits in any system prompt
_MAX_RETRIES       = 2


def _call_groq(system: str, user: str) -> Optional[str]:
    """Call Groq with retry. Returns text or None on failure."""
    if _groq is None:
        return None
    for attempt in range(_MAX_RETRIES):
        try:
            completion = _groq.chat.completions.create(
                model=_MODEL,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user",   "content": user},
                ],
                max_tokens=400,
                temperature=0.3,   # low temp — we want factual merging, not creativity
            )
            return (completion.choices[0].message.content or "").strip()
        except Exception as e:
            logger.warning(f"[AIMemory] Groq attempt {attempt+1} failed: {e}")
    return None


# ══════════════════════════════════════════════════════════════════
# UPDATE AFTER INTERVIEW
# ══════════════════════════════════════════════════════════════════
def update_after_interview(
    user,          # SQLAlchemy User model instance
    interview,     # SQLAlchemy Interview model instance
    db,            # SQLAlchemy Session
) -> None:
    """
    Called by _on_interview_complete() in interviews.py.
    Runs as a background task — any failure is logged and silently ignored.
    The interview must have status='completed' and score set.
    """
    try:
        current_profile = (user.ai_profile or "").strip()
        score           = interview.score
        job_role        = interview.job_role or "Unknown Role"
        difficulty      = interview.difficulty or "medium"
        lang            = getattr(interview, "language", "en") or "en"
        feedback        = interview.feedback or {}

        # Extract strengths and weaknesses from feedback dict
        strengths    = _extract_list(feedback, ["strengths", "strong_points"])
        weaknesses   = _extract_list(feedback, ["areas_for_improvement", "improvements", "weak_points"])
        grade        = feedback.get("grade", "")
        recommendation = feedback.get("recommendation", "")

        session_summary = (
            f"Interview: {job_role} ({difficulty}), "
            f"score={score:.0f}%{', grade=' + grade if grade else ''}"
        )
        if recommendation:
            session_summary += f", recommendation='{recommendation[:80]}'"

        user_msg = _build_interview_update_prompt(
            current_profile=current_profile,
            session_summary=session_summary,
            job_role=job_role,
            score=score,
            strengths=strengths,
            weaknesses=weaknesses,
            language=lang,
        )

        system_msg = _profile_merge_system_prompt(lang)
        updated = _call_groq(system_msg, user_msg)

        if updated:
            _write_profile(user, updated[:_MAX_PROFILE_CHARS], db)
            logger.info(f"[AIMemory] Updated profile for user {user.id} "
                        f"after interview {interview.id} (score={score:.0f}%)")
        else:
            # Fallback: append a simple line without AI merge
            fallback = _fallback_interview_line(current_profile, session_summary)
            _write_profile(user, fallback, db)
            logger.info(f"[AIMemory] Fallback update for user {user.id}")

    except Exception as e:
        logger.warning(f"[AIMemory] update_after_interview failed for user "
                       f"{getattr(user, 'id', '?')}: {e}")


# ══════════════════════════════════════════════════════════════════
# UPDATE AFTER PRACTICE SESSION
# ══════════════════════════════════════════════════════════════════
def update_after_practice(
    user,
    mode:          str,
    mode_context:  Optional[str],
    message_count: int,
    db,
) -> None:
    """
    Called by save_session() in practice.py after a session is saved.
    Practice sessions don't have a score — we track patterns instead.
    """
    try:
        current_profile = (user.ai_profile or "").strip()
        lang            = getattr(user, "preferred_language", "en") or "en"

        mode_labels = {
            "qa":           "Q&A coaching",
            "taskPractice": "task practice",
            "rolePlay":     "role-play mock interview",
            "cvQuestions":  "CV question prediction",
        }
        mode_label   = mode_labels.get(mode, mode)
        context_note = f" on '{mode_context}'" if mode_context else ""
        session_note = (
            f"Practice session: {mode_label}{context_note}, "
            f"{message_count} messages exchanged."
        )

        user_msg = _build_practice_update_prompt(
            current_profile=current_profile,
            session_note=session_note,
            mode=mode,
            language=lang,
        )

        system_msg = _profile_merge_system_prompt(lang)
        updated    = _call_groq(system_msg, user_msg)

        if updated:
            _write_profile(user, updated[:_MAX_PROFILE_CHARS], db)
            logger.info(f"[AIMemory] Updated profile for user {user.id} "
                        f"after practice session (mode={mode})")
        # For practice sessions, skip fallback — no score to note if Groq fails

    except Exception as e:
        logger.warning(f"[AIMemory] update_after_practice failed for user "
                       f"{getattr(user, 'id', '?')}: {e}")


# ══════════════════════════════════════════════════════════════════
# PROFILE READER — used by every AI endpoint as system prompt prefix
# ══════════════════════════════════════════════════════════════════
def get_profile_context(user, language: str = "en") -> str:
    """
    Returns the ai_profile formatted as a system prompt prefix.
    Empty string if no profile exists yet.
    """
    profile = (getattr(user, "ai_profile", None) or "").strip()
    if not profile:
        return ""

    if language == "ar":
        return f"═══ ملف المستخدم الذكي ═══\n{profile}\n═══════════════════════════\n"
    return f"═══ USER AI PROFILE ═══\n{profile}\n═══════════════════════\n"


# ══════════════════════════════════════════════════════════════════
# INTERNAL HELPERS
# ══════════════════════════════════════════════════════════════════
def _write_profile(user, text: str, db) -> None:
    """Direct DB write — no HTTP call needed since we're in the same process."""
    user.ai_profile = text
    user.updated_at = datetime.utcnow()
    db.commit()


def _extract_list(feedback: dict, keys: list[str]) -> list[str]:
    """Try multiple keys to find a list in the feedback dict."""
    for key in keys:
        val = feedback.get(key)
        if isinstance(val, list) and val:
            return [str(x) for x in val[:4]]   # max 4 items
        if isinstance(val, str) and val:
            return [val[:120]]
    return []


def _profile_merge_system_prompt(language: str) -> str:
    if language == "ar":
        return """أنت نظام ذكاء اصطناعي مسؤول عن تحديث ملف المستخدم.
مهمتك: دمج معلومات الجلسة الجديدة في الملف الحالي بذكاء.

قواعد صارمة:
- اكتب بأسلوب موجز ومنظم (نقاط قصيرة)
- لا تتجاوز 900 حرف إجمالاً
- إذا تحسن المستخدم في نقطة ضعف → احذفها أو حوّلها إلى نقطة قوة
- إذا ظهرت نقطة ضعف جديدة → أضفها
- احتفظ بالإحصائيات دائماً (عدد الجلسات، المتوسط، الأفضل)
- لا تكرر نفس المعلومة مرتين
- اكتب بصيغة "المستخدم" وليس "أنت"
أخرج فقط الملف المحدث بدون أي تعليق."""
    return """You are an AI system responsible for updating a user's persistent profile.
Your task: intelligently merge new session data into the existing profile.

Strict rules:
- Write in concise bullet-point style
- Max 900 characters total
- If user IMPROVED on a weakness → remove it or move to strengths
- If a new weakness appeared → add it
- Always keep stats (session count, avg score, best score)
- Never repeat the same info twice
- Write in third-person ("User is..." not "You are...")
- Output ONLY the updated profile, no commentary."""


def _build_interview_update_prompt(
    current_profile: str,
    session_summary: str,
    job_role: str,
    score: float,
    strengths: list[str],
    weaknesses: list[str],
    language: str,
) -> str:
    parts = []

    if current_profile:
        parts.append(f"CURRENT PROFILE:\n{current_profile}")
    else:
        parts.append("CURRENT PROFILE: (empty — this is the first session)")

    parts.append(f"\nNEW SESSION DATA:\n{session_summary}")

    if strengths:
        parts.append("Strengths shown: " + "; ".join(strengths))
    if weaknesses:
        parts.append("Weaknesses shown: " + "; ".join(weaknesses))

    # Score guidance
    if score >= 85:
        parts.append("Performance note: Excellent session — reinforce strengths, remove any matching weaknesses.")
    elif score >= 70:
        parts.append("Performance note: Good session — note improvements, keep weaknesses that weren't addressed.")
    else:
        parts.append("Performance note: Needs work — add/emphasize weaknesses shown, note what to practice.")

    parts.append(f"\nUpdate the profile to reflect this new session. Target role: {job_role}.")
    return "\n".join(parts)


def _build_practice_update_prompt(
    current_profile: str,
    session_note: str,
    mode: str,
    language: str,
) -> str:
    parts = []

    if current_profile:
        parts.append(f"CURRENT PROFILE:\n{current_profile}")
    else:
        parts.append("CURRENT PROFILE: (empty — this is the first session)")

    parts.append(f"\nNEW PRACTICE SESSION:\n{session_note}")
    parts.append("Update the practice patterns section of the profile to note this activity. "
                 "Do not remove interview scores or strengths/weaknesses. "
                 "Keep changes minimal — just update the practice activity line.")
    return "\n".join(parts)


def _fallback_interview_line(current_profile: str, session_summary: str) -> str:
    """Simple append when Groq is unavailable."""
    lines = [l.strip() for l in current_profile.split("\n") if l.strip()]
    # Replace or add "Last session" line
    lines = [l for l in lines if not l.startswith("Last session:")]
    lines.append(f"Last session: {session_summary}")
    result = "\n".join(lines)
    return result[:_MAX_PROFILE_CHARS]