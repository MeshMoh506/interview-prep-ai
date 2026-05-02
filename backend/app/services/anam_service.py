# app/services/anam_service.py
"""
Anam.ai Real-Time Avatar Service.

Architecture:
  1. Backend creates a session token via Anam REST API
  2. Token includes: avatarId (your custom Arabic/English avatar),
     our interview system prompt, llmId="CUSTOMER_CLIENT_V1" (uses our Groq brain)
  3. Flutter embeds Anam JS SDK in a WebView using this token
  4. Anam handles: WebRTC, STT, face rendering, lip sync, audio
  5. When user speaks → Anam sends transcript → our /anam-chat endpoint → Groq Llama → reply
  6. Avatar speaks the reply in real-time (<180ms)

Avatars:
  Arabic Male  (shemagh):  7b3722fb-35f3-42ab-a3e9-f81d5025520c
  English Male (suit):     30fa96d0-26c4-4e55-94a0-517025942e18  (Cara default)
  English Female (suit):   use Anam lab to create and add ID here

Voice IDs (from Anam lab — voiceId field):
  English default:  6bfbe25a-979d-40f3-a92b-5394170af54b
  Arabic: set languageCode="ar" — Anam auto-selects native Arabic voice
  OR use a specific Arabic voice ID from lab.anam.ai/voices
"""

import os
import logging
from typing import Optional
import httpx

logger = logging.getLogger(__name__)

# ── Avatar IDs ───────────────────────────────────────────────────
AVATARS = {
    # Your custom Arabic male avatar (shemagh)
    "arabic_male": {
        "id":          "7b3722fb-35f3-42ab-a3e9-f81d5025520c",
        "name":        "أحمد",
        "description": "مدير التوظيف",
        "language":    "ar",
        "gender":      "male",
        "style":       "professional",
    },
    # Anam default — use until you create more custom avatars
    "english_male": {
        "id":          "30fa96d0-26c4-4e55-94a0-517025942e18",
        "name":        "Alex",
        "description": "Hiring Manager",
        "language":    "en",
        "gender":      "male",
        "style":       "professional",
    },
    # Add more after creating in Anam lab:
    # "arabic_female": { "id": "...", ... },
    # "english_female": { "id": "...", ... },
}

# ── Voice IDs ─────────────────────────────────────────────────────
# Get yours from lab.anam.ai/voices
# Default Anam voice works for English. For Arabic, set languageCode.
_VOICE_EN = "6bfbe25a-979d-40f3-a92b-5394170af54b"  # default Cara voice
_VOICE_AR = "c11d6262-221c-4b64-bc98-d39cb2b1ebb5"  # 

# ── LLM ID ───────────────────────────────────────────────────────
# "CUSTOMER_CLIENT_V1" = use our own backend for LLM (Groq Llama)
# This means our interview AI, goal context, and AI memory all work
_LLM_CUSTOM = "CUSTOMER_CLIENT_V1"

# ── Anam API ─────────────────────────────────────────────────────
_ANAM_API = "https://api.anam.ai/v1"


class AnamService:
    def __init__(self):
        self.api_key = os.getenv("ANAM_API_KEY", "")
        if not self.api_key:
            logger.warning("ANAM_API_KEY not set — video interview will not work")

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type":  "application/json",
        }

    def get_available_avatars(self) -> list[dict]:
        """Return the list of available avatars for the Flutter avatar picker."""
        return [
            {
                "id":          avatar_id,
                "anam_id":     info["id"],
                "name":        info["name"],
                "description": info["description"],
                "language":    info["language"],
                "gender":      info["gender"],
                "style":       info["style"],
            }
            for avatar_id, info in AVATARS.items()
        ]

    def _build_system_prompt(
        self,
        job_role:     str,
        difficulty:   str,
        interview_type: str,
        language:     str,
        goal_context: str = "",
        resume_text:  str = "",
    ) -> str:
        """
        Build the full interview system prompt injected into Anam.
        Includes goal context + AI memory profile — same as our text interview.
        IMPORTANT: Anam docs recommend natural speech without formatting.
        """
        # Style instruction for natural avatar speech
        style = (
            "[أسلوب] تحدث بشكل طبيعي وواضح بدون تنسيق أو نقاط. أضف توقفات قصيرة بين الجمل."
            if language == "ar" else
            "[STYLE] Reply in natural conversational speech. No bullet points, no formatting. "
            "Add natural pauses with '...' between sentences."
        )

        if language == "ar":
            base = f"""{style}

أنت مقابِل خبير لدور {job_role}.
مستوى الصعوبة: {difficulty}
نوع المقابلة: {interview_type}

تعليمات:
- اطرح سؤالاً واحداً في كل مرة
- استمع للإجابة وأعطِ تعليقاً موجزاً قبل السؤال التالي
- قيّم: الوضوح، الهيكل، والعمق التقني
- بعد 6-8 أسئلة، أنهِ المقابلة وأخبر المرشح أنك ستشارك التقييم
- ابدأ بترحيب ودي وسؤالك الأول مباشرة"""
        else:
            base = f"""{style}

You are an expert interviewer for the role of {job_role}.
Difficulty: {difficulty}
Interview type: {interview_type}

Instructions:
- Ask one question at a time
- Listen to the answer and give brief feedback before moving on
- Evaluate: clarity, structure, and technical depth
- After 6-8 questions, wrap up the interview and tell the candidate you'll share their score
- Start with a warm greeting and your first question immediately"""

        parts = [base]

        if goal_context:
            parts.append(goal_context)

        if resume_text:
            preview = resume_text[:800]
            label = "ملخص السيرة الذاتية:" if language == "ar" else "Resume context:"
            parts.append(f"{label}\n{preview}")

        return "\n\n".join(parts)

    async def create_session_token(
        self,
        avatar_id:      str,
        job_role:       str,
        difficulty:     str,
        interview_type: str,
        language:       str,
        goal_context:   str = "",
        resume_text:    str = "",
    ) -> dict:
        """
        Create an Anam session token.
        Returns: { success, session_token, avatar_name, avatar_language }
        """
        if not self.api_key:
            return {"success": False, "error": "ANAM_API_KEY not configured"}

        # Look up avatar config
        avatar_config = AVATARS.get(avatar_id)
        if not avatar_config:
            # fallback to english_male
            avatar_config = AVATARS["english_male"]
            avatar_id     = "english_male"

        anam_avatar_id = avatar_config["id"]
        avatar_language = avatar_config["language"]
        voice_id = _VOICE_AR if avatar_language == "ar" else _VOICE_EN

        system_prompt = self._build_system_prompt(
            job_role=job_role, difficulty=difficulty,
            interview_type=interview_type, language=language,
            goal_context=goal_context, resume_text=resume_text,
        )

        payload = {
            "personaConfig": {
                "name":        avatar_config["name"],
                "avatarId":    anam_avatar_id,
                "avatarModel": "cara-3",        # latest model
                "voiceId":     voice_id,
                "llmId":       _LLM_CUSTOM,     # our Groq brain handles LLM
                "systemPrompt": system_prompt,
                "maxSessionLengthSeconds": 1800,  # 30 min max
                "skipGreeting": False,
                # Language for STT — Anam uses this for speech recognition
                **({"languageCode": "ar"} if avatar_language == "ar" else {}),
            },
        }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                r = await client.post(
                    f"{_ANAM_API}/auth/session-token",
                    headers=self._headers(),
                    json=payload,
                )
                logger.info(f"Anam session token: {r.status_code}")

                if r.status_code in (200, 201):
                    data = r.json()
                    return {
                        "success":         True,
                        "session_token":   data.get("sessionToken") or data.get("session_token"),
                        "avatar_name":     avatar_config["name"],
                        "avatar_language": avatar_language,
                        "avatar_id":       avatar_id,
                    }
                else:
                    logger.error(f"Anam error: {r.status_code} — {r.text[:300]}")
                    return {"success": False, "error": f"Anam API error {r.status_code}"}

        except Exception as e:
            logger.error(f"Anam create_session_token error: {e}")
            return {"success": False, "error": str(e)}

    async def process_anam_message(
        self,
        messages:       list[dict],
        job_role:       str,
        difficulty:     str,
        interview_type: str,
        language:       str,
        user_msg_count: int,
        goal_context:   str = "",
    ) -> dict:
        """
        Called by /anam-chat endpoint when Anam sends MESSAGE_HISTORY_UPDATED.
        Runs our Groq Llama interview AI and returns the reply text.
        Anam's JS SDK then calls anamClient.talk(reply) to make the avatar speak.
        """
        from app.services.interview_ai_service import InterviewAIService
        ai = InterviewAIService()

        # Convert Anam message format to our format
        # Anam messages: [{ role: "user"|"assistant", content: "..." }]
        history = []
        user_count = 0
        for m in messages[:-1]:  # all except the last (current user message)
            role = m.get("role", "user")
            if role == "persona":
                role = "assistant"
            history.append({"role": role, "content": m.get("content", "")})

        last_msg = messages[-1] if messages else {}
        user_message = last_msg.get("content", "")

        result = ai.process_message(
            history=history,
            user_message=user_message,
            job_role=job_role,
            difficulty=difficulty,
            interview_type=interview_type,
            language=language,
            job_description="",
            user_msg_count=user_msg_count,
            goal_context=goal_context,
        )

        return {
            "reply":       result.get("message", ""),
            "should_end":  result.get("should_end", False),
            "evaluation":  result.get("evaluation"),
        }