# backend/app/services/avatar_service.py
"""
D-ID Avatar Service - Generate talking head videos
"""

import os
import httpx
import asyncio
from typing import Dict, Optional
import logging

logger = logging.getLogger(__name__)

class AvatarService:
    def __init__(self):
        self.api_key = os.getenv("DID_API_KEY")
        if not self.api_key:
            logger.warning("DID_API_KEY not found in environment variables")

        self.base_url = "https://api.d-id.com"

        self.avatars = {
            "professional_female": {
                "presenter_id": "amy-jcwCkr1grs",
                "name": "Professional Female",
                "description": "Experienced HR professional"
            },
            "professional_male": {
                "presenter_id": "josh_lite3_20230714",
                "name": "Professional Male",
                "description": "Senior hiring manager"
            },
            "casual_female": {
                "presenter_id": "anna-ZOqKGRoXmVw",
                "name": "Casual Female",
                "description": "Startup vibe, friendly"
            },
            "casual_male": {
                "presenter_id": "mark_lite3_20230714",
                "name": "Casual Male",
                "description": "Tech lead, relaxed"
            },
            "tech_female": {
                "presenter_id": "ava_lite3_20230714",
                "name": "Technical Female",
                "description": "Senior engineer focus"
            }
        }

    def _get_headers(self) -> Dict:
        # D-ID requires "Basic <base64(email:key)>"
        # The DID_API_KEY in .env should already be the base64 value
        return {
            "Authorization": f"Basic {self.api_key}",
            "Content-Type": "application/json",
            "accept": "application/json",
        }

    async def create_talking_avatar(
        self,
        text: str,
        avatar_id: str = "professional_female",
        language: str = "en"
    ) -> Dict:
        if not self.api_key:
            return {"success": False, "error": "D-ID API key not configured"}

        avatar_config = self.avatars.get(avatar_id, self.avatars["professional_female"])
        voice_id = self._get_voice_id(language, avatar_id)
        headers = self._get_headers()

        payload = {
            "script": {
                "type": "text",
                "input": text,
                "provider": {
                    "type": "microsoft",
                    "voice_id": voice_id
                }
            },
            "config": {
                "fluent": True,
                "pad_audio": 0.0,
                "stitch": True
            },
            "presenter_id": avatar_config["presenter_id"]
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.base_url}/talks",
                    headers=headers,
                    json=payload
                )

                logger.info(f"D-ID create talk response: {response.status_code} - {response.text[:200]}")

                if response.status_code in (200, 201):
                    result = response.json()
                    talk_id = result.get("id")

                    video_url = await self._wait_for_video(talk_id, headers)

                    if video_url:
                        return {
                            "success": True,
                            "talk_id": talk_id,
                            "video_url": video_url,
                            "status": "done"
                        }
                    else:
                        return {
                            "success": False,
                            "error": "Video generation timeout",
                            "talk_id": talk_id
                        }
                elif response.status_code == 401:
                    logger.error("D-ID 401 Unauthorized - check DID_API_KEY format in .env")
                    return {
                        "success": False,
                        "error": "D-ID authentication failed. Check DID_API_KEY in .env"
                    }
                else:
                    logger.error(f"D-ID API error: {response.status_code} - {response.text}")
                    return {
                        "success": False,
                        "error": f"D-ID API error: {response.status_code}",
                        "details": response.text
                    }

        except Exception as e:
            logger.error(f"Avatar creation error: {str(e)}")
            return {"success": False, "error": str(e)}

    async def _wait_for_video(
        self,
        talk_id: str,
        headers: Dict,
        max_wait: int = 60
    ) -> Optional[str]:
        async with httpx.AsyncClient(timeout=30.0) as client:
            for i in range(max_wait):
                try:
                    response = await client.get(
                        f"{self.base_url}/talks/{talk_id}",
                        headers=headers
                    )

                    if response.status_code == 200:
                        data = response.json()
                        status = data.get("status")

                        if status == "done":
                            video_url = data.get("result_url")
                            logger.info(f"Video ready: {talk_id} -> {video_url}")
                            return video_url
                        elif status == "error":
                            logger.error(f"D-ID video error: {data.get('error')}")
                            return None

                        await asyncio.sleep(1)
                    else:
                        logger.error(f"Status check error: {response.status_code}")
                        return None

                except Exception as e:
                    logger.error(f"Polling error: {e}")
                    return None

            logger.warning(f"Video generation timeout for {talk_id}")
            return None

    def _get_voice_id(self, language: str, avatar_id: str) -> str:
        if language == "en":
            return "en-US-JennyNeural" if "female" in avatar_id else "en-US-GuyNeural"
        elif language == "ar":
            return "ar-SA-ZariyahNeural" if "female" in avatar_id else "ar-SA-HamedNeural"
        return "en-US-JennyNeural"

    def get_available_avatars(self) -> Dict:
        return {
            "avatars": [
                {
                    "id": avatar_id,
                    "name": config["name"],
                    "description": config["description"]
                }
                for avatar_id, config in self.avatars.items()
            ]
        }