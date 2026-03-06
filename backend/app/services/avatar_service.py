# backend/app/services/avatar_service.py
"""
D-ID Avatar Service.

Fetches the real presenter list from D-ID on first call, picks suitable
presenters for each avatar slot, and returns their actual thumbnail_url
(from clips-presenters.d-id.com CDN — CORS-safe for Flutter Web).
"""

import os
import httpx
import asyncio
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)

# ── In-memory cache ───────────────────────────────────────────────────────────
_presenters_cache: List[Dict] = []   # raw D-ID presenter objects
_cache_loaded = False


def _dicebear(seed: str) -> str:
    return f"https://api.dicebear.com/7.x/personas/svg?seed={seed}&backgroundColor=4f46e5,7c3aed"


# ── Avatar slots we want to fill ──────────────────────────────────────────────
# Each slot defines what kind of D-ID presenter to pick.
# `did_name` = the "name" field in D-ID's response to filter by.
# We pick the first matching presenter that is NOT greenscreen.
_SLOTS = [
    # English Female
    {"id": "professional_female", "did_name": "Amy",    "gender": "female", "name": "Amy",     "description": "HR Director",        "style": "professional", "language": "en"},
    {"id": "casual_female",       "did_name": "Anna",   "gender": "female", "name": "Anna",    "description": "Startup recruiter",  "style": "casual",        "language": "en"},
    {"id": "tech_female",         "did_name": "Ava",    "gender": "female", "name": "Ava",     "description": "Senior engineer",    "style": "professional", "language": "en"},
    {"id": "executive_female",    "did_name": "Ella",   "gender": "female", "name": "Sarah",   "description": "VP of Engineering",  "style": "professional", "language": "en"},
    {"id": "friendly_female",     "did_name": "Fiona",  "gender": "female", "name": "Emma",    "description": "Talent acquisition", "style": "casual",        "language": "en"},
    {"id": "casual_female_2",     "did_name": "Alyssa", "gender": "female", "name": "Alyssa",  "description": "Product recruiter",  "style": "casual",        "language": "en"},
    # English Male
    {"id": "professional_male",   "did_name": "Josh",   "gender": "male",   "name": "Josh",    "description": "Hiring manager",     "style": "professional", "language": "en"},
    {"id": "casual_male",         "did_name": "Mark",   "gender": "male",   "name": "Mark",    "description": "Tech lead",          "style": "casual",        "language": "en"},
    {"id": "executive_male",      "did_name": "Ethan",  "gender": "male",   "name": "David",   "description": "CTO interviewer",    "style": "professional", "language": "en"},
    {"id": "friendly_male",       "did_name": "Dylan",  "gender": "male",   "name": "Ryan",    "description": "Product manager",    "style": "casual",        "language": "en"},
    {"id": "senior_male",         "did_name": "Adam",   "gender": "male",   "name": "Michael", "description": "Senior director",    "style": "professional", "language": "en"},
    {"id": "casual_male_2",       "did_name": "Arran",  "gender": "male",   "name": "Arran",   "description": "Startup engineer",   "style": "casual",        "language": "en"},
    # Arabic Female (same faces, Arabic voice)
    {"id": "arabic_female",       "did_name": "Amy",    "gender": "female", "name": "سارة",    "description": "مديرة موارد بشرية", "style": "professional", "language": "ar"},
    {"id": "arabic_female_casual","did_name": "Anna",   "gender": "female", "name": "ليلى",    "description": "مسؤولة التوظيف",    "style": "casual",        "language": "ar"},
    # Arabic Male
    {"id": "arabic_male",         "did_name": "Josh",   "gender": "male",   "name": "أحمد",    "description": "مدير التوظيف",       "style": "professional", "language": "ar"},
    {"id": "arabic_male_casual",  "did_name": "Adam",   "gender": "male",   "name": "خالد",    "description": "قائد تقني",          "style": "casual",        "language": "ar"},
]

# Build a lookup: did_name → [presenter objects] filled after cache load
_name_to_presenters: Dict[str, List[Dict]] = {}


class AvatarService:
    def __init__(self):
        self.api_key = os.getenv("DID_API_KEY")
        if not self.api_key:
            logger.warning("DID_API_KEY not set")
        self.base_url = "https://api.d-id.com"

    def _get_headers(self) -> Dict:
        return {
            "Authorization": f"Basic {self.api_key}",
            "Content-Type":  "application/json",
            "accept":        "application/json",
        }

    def _get_voice_id(self, language: str, avatar_id: str) -> str:
        if language == "ar":
            return "ar-SA-ZariyahNeural" if "female" in avatar_id else "ar-SA-HamedNeural"
        return "en-US-JennyNeural" if "female" in avatar_id else "en-US-GuyNeural"

    # ── Load real presenters from D-ID ────────────────────────────────────────

    async def _ensure_cache(self) -> None:
        global _cache_loaded, _presenters_cache, _name_to_presenters
        if _cache_loaded:
            return

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                r = await client.get(
                    f"{self.base_url}/clips/presenters",
                    headers=self._get_headers(),
                )
                if r.status_code == 200:
                    data = r.json()
                    _presenters_cache = data if isinstance(data, list) else data.get("presenters", [])
                    logger.info(f"Loaded {len(_presenters_cache)} D-ID presenters")

                    # Build name → [presenters] map (case-insensitive)
                    _name_to_presenters.clear()
                    for p in _presenters_cache:
                        name = (p.get("name") or "").strip()
                        _name_to_presenters.setdefault(name.lower(), []).append(p)
                else:
                    logger.warning(f"D-ID /clips/presenters returned {r.status_code}: {r.text[:200]}")
        except Exception as e:
            logger.error(f"Failed to load D-ID presenters: {e}")
        finally:
            _cache_loaded = True

    def _best_presenter(self, did_name: str) -> Optional[Dict]:
        """
        Pick the best D-ID presenter for a given name:
        - Prefer non-greenscreen
        - Prefer standard (not NoHands) variants
        - Return first match otherwise
        """
        candidates = _name_to_presenters.get(did_name.lower(), [])
        if not candidates:
            return None

        # Prefer non-greenscreen, non-NoHands
        preferred = [
            p for p in candidates
            if not p.get("is_greenscreen", False)
            and "nohands" not in (p.get("presenter_id") or "").lower()
            and "nohands" not in (p.get("name") or "").lower()
        ]
        return (preferred or candidates)[0]

    def _resolve_avatar(self, slot: Dict) -> Dict:
        """Return avatar dict with real presenter_id and thumbnail_url."""
        presenter = self._best_presenter(slot["did_name"])

        if presenter:
            presenter_id  = presenter.get("presenter_id", "")
            thumbnail_url = (
                presenter.get("thumbnail_url")
                or presenter.get("image_url")
                or _dicebear(slot["id"])
            )
        else:
            presenter_id  = ""
            thumbnail_url = _dicebear(slot["id"])

        return {
            "id":            slot["id"],
            "name":          slot["name"],
            "description":   slot["description"],
            "gender":        slot["gender"],
            "style":         slot["style"],
            "language":      slot["language"],
            "thumbnail_url": thumbnail_url,
            "source_url":    thumbnail_url,
            "_presenter_id": presenter_id,   # internal use for video generation
        }

    # ── Public API ────────────────────────────────────────────────────────────

    async def get_available_avatars(self) -> Dict:
        await self._ensure_cache()
        return {"avatars": [self._resolve_avatar(s) for s in _SLOTS]}

    def _get_presenter_id_for(self, avatar_id: str) -> str:
        """Resolve avatar_id → D-ID presenter_id for video generation."""
        slot = next((s for s in _SLOTS if s["id"] == avatar_id), None)
        if not slot:
            return ""
        presenter = self._best_presenter(slot["did_name"])
        return presenter.get("presenter_id", "") if presenter else ""

    async def create_talking_avatar(
        self,
        text:        str,
        avatar_id:   str = "professional_female",
        language:    str = "en",
        source_url:  Optional[str] = None,
    ) -> Dict:
        if not self.api_key:
            return {"success": False, "error": "D-ID API key not configured"}

        await self._ensure_cache()

        presenter_id = self._get_presenter_id_for(avatar_id)
        voice_id     = self._get_voice_id(language, avatar_id)
        headers      = self._get_headers()

        if not presenter_id:
            return {"success": False, "error": f"No D-ID presenter found for avatar '{avatar_id}'"}

        payload = {
            "script": {
                "type":     "text",
                "input":    text,
                "provider": {"type": "microsoft", "voice_id": voice_id},
            },
            "config":       {"fluent": True, "pad_audio": 0.0, "stitch": True},
            "presenter_id": presenter_id,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.base_url}/clips", headers=headers, json=payload
                )
                logger.info(f"D-ID create clip: {response.status_code}")
                if response.status_code in (200, 201):
                    result    = response.json()
                    talk_id   = result.get("id")
                    video_url = await self._wait_for_clip(talk_id, headers)
                    if video_url:
                        return {"success": True, "talk_id": talk_id, "video_url": video_url}
                    return {"success": False, "error": "Video generation timeout", "talk_id": talk_id}
                elif response.status_code == 401:
                    return {"success": False, "error": "D-ID authentication failed. Check DID_API_KEY."}
                else:
                    logger.error(f"D-ID error body: {response.text[:400]}")
                    return {"success": False, "error": f"D-ID API error: {response.status_code}"}
        except Exception as e:
            logger.error(f"Avatar creation error: {e}")
            return {"success": False, "error": str(e)}

    async def _wait_for_clip(self, clip_id: str, headers: Dict, max_wait: int = 60) -> Optional[str]:
        async with httpx.AsyncClient(timeout=30.0) as client:
            for _ in range(max_wait):
                try:
                    r = await client.get(f"{self.base_url}/clips/{clip_id}", headers=headers)
                    if r.status_code == 200:
                        data   = r.json()
                        status = data.get("status")
                        if status == "done":
                            return data.get("result_url")
                        elif status == "error":
                            logger.error(f"D-ID clip error: {data}")
                            return None
                        await asyncio.sleep(1)
                    else:
                        return None
                except Exception:
                    return None
            return None

    async def test_connection(self) -> Dict:
        if not self.api_key:
            return {"success": False, "error": "DID_API_KEY not set"}
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                r = await client.get(f"{self.base_url}/clips/presenters", headers=self._get_headers())
                return {"success": r.status_code == 200, "status_code": r.status_code}
        except Exception as e:
            return {"success": False, "error": str(e)}

    @staticmethod
    async def fetch_photo_bytes(avatar_id: str) -> Optional[bytes]:
        """Proxy helper — kept for backward compat with avatar_photos router."""
        slot = next((s for s in _SLOTS if s["id"] == avatar_id), None)
        if not slot:
            return None
        presenter = AvatarService.__new__(AvatarService)._best_presenter(slot["did_name"])
        if not presenter:
            return None
        url = presenter.get("thumbnail_url") or presenter.get("image_url")
        if not url:
            return None
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                r = await client.get(url, follow_redirects=True)
                if r.status_code == 200:
                    return r.content
        except Exception as e:
            logger.error(f"Photo proxy error for {avatar_id}: {e}")
        return None