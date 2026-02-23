# backend/app/services/avatar_service.py
"""
D-ID Avatar Service - Generate talking head videos
Complete integration for AI interview avatars
"""

import os
import httpx
import asyncio
from typing import Dict, Optional
import logging

logger = logging.getLogger(__name__)

class AvatarService:
    """
    D-ID API Integration for AI Avatar Generation
    Generates realistic talking head videos from text
    """
    
    def __init__(self):
        self.api_key = os.getenv("DID_API_KEY")
        if not self.api_key:
            logger.warning("DID_API_KEY not found in environment variables")
        
        self.base_url = "https://api.d-id.com"
        
        # Available professional avatars
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
        
    async def create_talking_avatar(
        self,
        text: str,
        avatar_id: str = "professional_female",
        language: str = "en"
    ) -> Dict:
        """
        Create a talking avatar video from text
        
        Args:
            text: What the avatar should say
            avatar_id: Which avatar to use
            language: 'en' or 'ar'
            
        Returns:
            {
                "success": True/False,
                "talk_id": "did_talk_xxx",
                "video_url": "https://...",
                "status": "done"/"processing"/"error"
            }
        """
        
        if not self.api_key:
            return {
                "success": False,
                "error": "D-ID API key not configured"
            }
        
        # Get avatar config
        avatar_config = self.avatars.get(avatar_id, self.avatars["professional_female"])
        
        # Get voice for language
        voice_id = self._get_voice_id(language, avatar_id)
        
        # Prepare headers
        headers = {
            "Authorization": f"{self.api_key}",
            "Content-Type": "application/json"
        }
        
        # Prepare payload
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
            # Use D-ID stock presenter
            "presenter_id": avatar_config["presenter_id"]
        }
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Create talk
                response = await client.post(
                    f"{self.base_url}/talks",
                    headers=headers,
                    json=payload
                )
                
                if response.status_code == 201:
                    result = response.json()
                    talk_id = result.get("id")
                    
                    # Wait for video to be ready (max 60 seconds)
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
                else:
                    logger.error(f"D-ID API error: {response.status_code} - {response.text}")
                    return {
                        "success": False,
                        "error": f"D-ID API error: {response.status_code}",
                        "details": response.text
                    }
                    
        except Exception as e:
            logger.error(f"Avatar creation error: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def _wait_for_video(
        self,
        talk_id: str,
        headers: Dict,
        max_wait: int = 60
    ) -> Optional[str]:
        """
        Poll D-ID API until video is ready
        Usually takes 10-30 seconds
        """
        
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
                            logger.info(f"Video ready: {talk_id}")
                            return video_url
                        elif status == "error":
                            logger.error(f"Video generation error: {data.get('error')}")
                            return None
                        
                        # Still processing, wait 1 second
                        await asyncio.sleep(1)
                    else:
                        logger.error(f"Status check error: {response.status_code}")
                        return None
                        
                except Exception as e:
                    logger.error(f"Polling error: {e}")
                    return None
            
            # Timeout
            logger.warning(f"Video generation timeout for {talk_id}")
            return None
    
    def _get_voice_id(self, language: str, avatar_id: str) -> str:
        """
        Get appropriate voice ID based on language and avatar
        """
        
        # English voices
        if language == "en":
            if "female" in avatar_id:
                return "en-US-JennyNeural"
            else:
                return "en-US-GuyNeural"
        
        # Arabic voices
        elif language == "ar":
            if "female" in avatar_id:
                return "ar-SA-ZariyahNeural"
            else:
                return "ar-SA-HamedNeural"
        
        # Default
        return "en-US-JennyNeural"
    
    def get_available_avatars(self) -> Dict:
        """
        Return list of available avatars
        """
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