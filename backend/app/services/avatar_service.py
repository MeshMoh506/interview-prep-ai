# backend/app/services/avatar_service.py
"""
D-ID Avatar Service.

Change vs previous version:
  _resolve_avatar() now includes `idle_video_url` in the returned dict.
  Flutter reads this and passes it to AvatarVideoPlayer(idleVideoUrl: ...).
"""

import os
import httpx
import asyncio
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)

# ── Module-level cache (shared across all requests) ───────────────────────────
_presenters_cache: List[Dict] = []
_cache_loaded = False
_name_to_presenters: Dict[str, List[Dict]] = {}


def _dicebear(seed: str) -> str:
    return f"https://api.dicebear.com/7.x/personas/svg?seed={seed}&backgroundColor=4f46e5,7c3aed"


_SLOTS = [
    # English Female
    {"id": "professional_female",  "did_name": "Amy",    "gender": "female", "name": "Amy",     "description": "HR Director",        "style": "professional", "language": "en"},
    {"id": "casual_female",        "did_name": "Anna",   "gender": "female", "name": "Anna",    "description": "Startup recruiter",  "style": "casual",        "language": "en"},
    {"id": "tech_female",          "did_name": "Ava",    "gender": "female", "name": "Ava",     "description": "Senior engineer",    "style": "professional", "language": "en"},
    {"id": "executive_female",     "did_name": "Ella",   "gender": "female", "name": "Sarah",   "description": "VP of Engineering",  "style": "professional", "language": "en"},
    {"id": "friendly_female",      "did_name": "Fiona",  "gender": "female", "name": "Emma",    "description": "Talent acquisition", "style": "casual",        "language": "en"},
    {"id": "casual_female_2",      "did_name": "Alyssa", "gender": "female", "name": "Alyssa",  "description": "Product recruiter",  "style": "casual",        "language": "en"},
    # English Male
    {"id": "professional_male",    "did_name": "Josh",   "gender": "male",   "name": "Josh",    "description": "Hiring manager",     "style": "professional", "language": "en"},
    {"id": "casual_male",          "did_name": "Mark",   "gender": "male",   "name": "Mark",    "description": "Tech lead",          "style": "casual",        "language": "en"},
    {"id": "executive_male",       "did_name": "Ethan",  "gender": "male",   "name": "David",   "description": "CTO interviewer",    "style": "professional", "language": "en"},
    {"id": "friendly_male",        "did_name": "Dylan",  "gender": "male",   "name": "Ryan",    "description": "Product manager",    "style": "casual",        "language": "en"},
    {"id": "senior_male",          "did_name": "Adam",   "gender": "male",   "name": "Michael", "description": "Senior director",    "style": "professional", "language": "en"},
    {"id": "casual_male_2",        "did_name": "Arran",  "gender": "male",   "name": "Arran",   "description": "Startup engineer",   "style": "casual",        "language": "en"},
    # Arabic Female
    {"id": "arabic_female",        "did_name": "Amy",    "gender": "female", "name": "سارة",    "description": "مديرة موارد بشرية", "style": "professional", "language": "ar"},
    {"id": "arabic_female_casual", "did_name": "Anna",   "gender": "female", "name": "ليلى",    "description": "مسؤولة التوظيف",    "style": "casual",        "language": "ar"},
    # Arabic Male
    {"id": "arabic_male",          "did_name": "Josh",   "gender": "male",   "name": "أحمد",    "description": "مدير التوظيف",       "style": "professional", "language": "ar"},
    {"id": "arabic_male_casual",   "did_name": "Adam",   "gender": "male",   "name": "خالد",    "description": "قائد تقني",          "style": "casual",        "language": "ar"},
]


class AvatarService:
    def __init__(self):
        self.api_key  = os.getenv("DID_API_KEY")
        if not self.api_key:
            logger.warning("DID_API_KEY not set")
        self.base_url = "https://api.d-id.com"

    def _headers(self) -> Dict:
        return {
            "Authorization": f"Basic {self.api_key}",
            "Content-Type":  "application/json",
            "accept":        "application/json",
        }

    def _voice_id(self, language: str, avatar_id: str) -> str:
        if language == "ar":
            return "ar-SA-ZariyahNeural" if "female" in avatar_id else "ar-SA-HamedNeural"
        return "en-US-JennyNeural" if "female" in avatar_id else "en-US-GuyNeural"

    # ── Cache ──────────────────────────────────────────────────────────────────

    async def _ensure_cache(self) -> None:
        global _cache_loaded, _presenters_cache, _name_to_presenters
        if _cache_loaded:
            return
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                r = await client.get(
                    f"{self.base_url}/clips/presenters",
                    headers=self._headers(),
                )
                if r.status_code == 200:
                    data = r.json()
                    _presenters_cache = data if isinstance(data, list) else data.get("presenters", [])
                    logger.info(f"Loaded {len(_presenters_cache)} D-ID presenters")
                    _name_to_presenters.clear()
                    for p in _presenters_cache:
                        name = (p.get("name") or "").strip().lower()
                        _name_to_presenters.setdefault(name, []).append(p)
                else:
                    logger.warning(f"D-ID /clips/presenters → {r.status_code}")
        except Exception as e:
            logger.error(f"Failed to load D-ID presenters: {e}")
        finally:
            _cache_loaded = True

    def _best_presenter(self, did_name: str) -> Optional[Dict]:
        candidates = _name_to_presenters.get(did_name.lower(), [])
        if not candidates:
            return None
        preferred = [
            p for p in candidates
            if not p.get("is_greenscreen", False)
            and "nohands" not in (p.get("presenter_id") or "").lower()
        ]
        return (preferred or candidates)[0]

    # ── Avatar list ────────────────────────────────────────────────────────────

    def _resolve_avatar(self, slot: Dict) -> Dict:
        presenter      = self._best_presenter(slot["did_name"])
        thumbnail_url  = _dicebear(slot["id"])
        idle_video_url: Optional[str] = None
        presenter_id   = ""

        if presenter:
            presenter_id  = presenter.get("presenter_id", "")
            thumbnail_url = (
                presenter.get("thumbnail_url")
                or presenter.get("image_url")
                or _dicebear(slot["id"])
            )
            # ── KEY FIELD: D-ID idle.mp4 for this presenter ──────────
            idle_video_url = presenter.get("idle_video")   # e.g. "https://clips-presenters.d-id.com/.../idle.mp4?..."

        return {
            "id":             slot["id"],
            "name":           slot["name"],
            "description":    slot["description"],
            "gender":         slot["gender"],
            "style":          slot["style"],
            "language":       slot["language"],
            "thumbnail_url":  thumbnail_url,
            "source_url":     thumbnail_url,
            "idle_video_url": idle_video_url,   # ← Flutter reads this
            "_presenter_id":  presenter_id,
        }

    async def get_available_avatars(self) -> Dict:
        await self._ensure_cache()
        return {"avatars": [self._resolve_avatar(s) for s in _SLOTS]}

    # ── Presenter ID lookup ────────────────────────────────────────────────────

    def _presenter_id_for(self, avatar_id: str) -> str:
        slot = next((s for s in _SLOTS if s["id"] == avatar_id), None)
        if not slot:
            return ""
        p = self._best_presenter(slot["did_name"])
        return p.get("presenter_id", "") if p else ""

    # ── Create talking avatar clip ─────────────────────────────────────────────

    async def create_talking_avatar(
        self,
        text:       str,
        avatar_id:  str = "professional_female",
        language:   str = "en",
        source_url: Optional[str] = None,
    ) -> Dict:
        if not self.api_key:
            return {"success": False, "error": "D-ID API key not configured"}

        await self._ensure_cache()

        presenter_id = self._presenter_id_for(avatar_id)
        if not presenter_id:
            return {"success": False, "error": f"No D-ID presenter for '{avatar_id}'"}

        payload = {
            "script": {
                "type":     "text",
                "input":    text,
                "provider": {"type": "microsoft", "voice_id": self._voice_id(language, avatar_id)},
            },
            "config":       {"fluent": True, "pad_audio": 0.0, "stitch": True},
            "presenter_id": presenter_id,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(f"{self.base_url}/clips", headers=self._headers(), json=payload)
                logger.info(f"D-ID create clip: {r.status_code}")
                if r.status_code in (200, 201):
                    data     = r.json()
                    talk_id  = data.get("id")
                    video_url = await self._poll_clip(talk_id)
                    if video_url:
                        return {"success": True, "talk_id": talk_id, "video_url": video_url}
                    return {"success": False, "error": "Clip generation timed out", "talk_id": talk_id}
                elif r.status_code == 401:
                    return {"success": False, "error": "D-ID authentication failed"}
                else:
                    logger.error(f"D-ID error body: {r.text[:400]}")
                    return {"success": False, "error": f"D-ID API error {r.status_code}"}
        except Exception as e:
            logger.error(f"create_talking_avatar error: {e}")
            return {"success": False, "error": str(e)}

    async def _poll_clip(self, clip_id: str, max_wait: int = 120) -> Optional[str]:
        """Poll every 2 seconds for up to max_wait seconds (default 120s)."""
        iterations = max_wait // 2
        async with httpx.AsyncClient(timeout=30.0) as client:
            for i in range(iterations):
                try:
                    r = await client.get(
                        f"{self.base_url}/clips/{clip_id}", headers=self._headers())
                    if r.status_code == 200:
                        data   = r.json()
                        status = data.get("status")
                        logger.info(f"D-ID clip {clip_id} status: {status} ({i*2}s elapsed)")
                        if status == "done":
                            return data.get("result_url")
                        if status == "error":
                            logger.error(f"D-ID clip error: {data}")
                            return None
                        # still "created" or "started" — keep waiting
                    else:
                        logger.warning(f"D-ID poll returned {r.status_code}")
                    await asyncio.sleep(2)
                except Exception as e:
                    logger.error(f"D-ID poll exception: {e}")
                    return None
        logger.error(f"D-ID clip {clip_id} timed out after {max_wait}s")
        return None

    async def test_connection(self) -> Dict:
        if not self.api_key:
            return {"success": False, "error": "DID_API_KEY not set"}
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                r = await client.get(
                    f"{self.base_url}/clips/presenters", headers=self._headers())
                return {"success": r.status_code == 200, "status_code": r.status_code}
        except Exception as e:
            return {"success": False, "error": str(e)}