# app/services/roadmap_ai_service.py - FIXED VERSION
from groq import Groq
import json
import os
import re


class RoadmapAIService:
    def __init__(self):
        self.client = Groq(api_key=os.getenv("GROQ_API_KEY"))
        self.model = "llama-3.3-70b-versatile"
    
    def generate_roadmap(self, target_role: str, current_resume: dict = None, difficulty: str = "intermediate"):
        """Generate personalized learning roadmap using AI"""
        
        # Build context from resume
        resume_context = ""
        if current_resume:
            resume_context = f"""
Current Skills: {', '.join(current_resume.get('skills', []))}
Experience: {current_resume.get('experience_years', 0)} years
Education: {current_resume.get('education', 'Not specified')}
"""
        
        prompt = f"""You are a career development expert. Create a detailed learning roadmap for someone who wants to become a {target_role}.

{resume_context if resume_context else ''}

Difficulty Level: {difficulty}

Create a roadmap with 5 stages. Each stage should have 3 tasks.

CRITICAL: Return ONLY valid JSON. No markdown, no explanations, ONLY the JSON object.

{{
  "title": "Path to {target_role}",
  "description": "Learning path for {target_role}",
  "estimated_weeks": 12,
  "category": "Technology",
  "tags": ["skill1", "skill2"],
  "stages": [
    {{
      "order": 1,
      "title": "Foundation",
      "description": "Learn basics",
      "color": "#E91E63",
      "icon": "🎯",
      "estimated_hours": 40,
      "difficulty": "easy",
      "tasks": [
        {{
          "order": 1,
          "title": "Learn X",
          "description": "Study X basics",
          "estimated_hours": 10,
          "resources": [{{"type": "course", "title": "Course", "url": "https://example.com"}}]
        }}
      ]
    }}
  ]
}}

Stage colors: #E91E63, #2196F3, #00BCD4, #FFC107, #8B5CF6
Return ONLY valid JSON."""

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.5,
                max_tokens=3000,
            )
            
            content = response.choices[0].message.content.strip()
            
            # Clean markdown
            content = content.replace("```json", "").replace("```", "").strip()
            
            # Fix trailing commas
            content = re.sub(r',(\s*[}\]])', r'\1', content)
            
            roadmap_data = json.loads(content)
            return roadmap_data
                
        except Exception as e:
            print(f"AI Error: {e}")
            return self._get_fallback_roadmap(target_role)
    
    def _get_fallback_roadmap(self, target_role: str):
        """Fallback roadmap if AI fails"""
        return {
            "title": f"Path to {target_role}",
            "description": f"Learning guide for {target_role}",
            "estimated_weeks": 12,
            "category": "Technology",
            "tags": ["learning"],
            "stages": [
                {
                    "order": 1,
                    "title": "Foundation",
                    "description": "Build basics",
                    "color": "#E91E63",
                    "icon": "🎯",
                    "estimated_hours": 40,
                    "difficulty": "easy",
                    "tasks": [
                        {"order": 1, "title": "Learn basics", "description": "Start here", "estimated_hours": 20, "resources": []},
                        {"order": 2, "title": "Practice", "description": "Daily practice", "estimated_hours": 20, "resources": []}
                    ]
                },
                {
                    "order": 2,
                    "title": "Skills",
                    "description": "Core skills",
                    "color": "#2196F3",
                    "icon": "📚",
                    "estimated_hours": 60,
                    "difficulty": "medium",
                    "tasks": [
                        {"order": 1, "title": "Projects", "description": "Build projects", "estimated_hours": 30, "resources": []},
                        {"order": 2, "title": "Tools", "description": "Learn tools", "estimated_hours": 30, "resources": []}
                    ]
                },
                {
                    "order": 3,
                    "title": "Advanced",
                    "description": "Advanced topics",
                    "color": "#00BCD4",
                    "icon": "💡",
                    "estimated_hours": 80,
                    "difficulty": "hard",
                    "tasks": [
                        {"order": 1, "title": "Architecture", "description": "Design systems", "estimated_hours": 40, "resources": []},
                        {"order": 2, "title": "Practice", "description": "Real projects", "estimated_hours": 40, "resources": []}
                    ]
                }
            ]
        }