# app/services/roadmap_ai_service.py
from groq import Groq
import json
import os
import re


class RoadmapAIService:
    def __init__(self):
        self.client = Groq(api_key=os.getenv("GROQ_API_KEY"))
        self.model = "llama-3.3-70b-versatile"

    def generate_roadmap(
        self,
        target_role: str,
        difficulty: str = "intermediate",
        path_type: str = "balanced",        # "certification" | "project" | "balanced"
        include_capstone: bool = True,
        hours_per_week: int = 10,
        target_weeks: int = 8,
        current_resume: dict = None,        # kept for backward compat
        resume_context: str = None,
    ):
        """Generate personalized learning roadmap using AI"""

        # ── Resume context ───────────────────────────────────
        res_ctx = ""
        if resume_context:
            res_ctx = f"\nUser resume context:\n{resume_context[:800]}\n"
        elif current_resume:
            res_ctx = f"""
Current Skills: {', '.join(current_resume.get('skills', []))}
Experience: {current_resume.get('experience_years', 0)} years
Education: {current_resume.get('education', 'Not specified')}
"""

        # ── Path type instruction ────────────────────────────
        path_instructions = {
            "certification": (
                "Focus heavily on CERTIFICATIONS and structured courses. "
                "Each milestone should include a specific certificate or exam to pursue. "
                "Minimize project work — keep tasks theory and exam-oriented."
            ),
            "project": (
                "Focus on HANDS-ON PROJECTS and practical experience. "
                "Each milestone should involve building something real. "
                "Minimize certification tasks — keep tasks project-based. "
                f"{'Include a final Capstone project as the last milestone.' if include_capstone else ''}"
            ),
            "balanced": (
                "Balance certifications with practical projects equally. "
                "Alternate between learning/cert tasks and build tasks. "
                f"{'Include a final Capstone project as the last milestone.' if include_capstone else ''}"
            ),
        }
        path_ctx = path_instructions.get(path_type, path_instructions["balanced"])

        # ── Time context ─────────────────────────────────────
        time_ctx = (
            f"The user can commit {hours_per_week} hours per week "
            f"and wants to complete this in approximately {target_weeks} weeks. "
            f"Scale the number of tasks and estimated hours accordingly — "
            f"total estimated hours across all tasks should be roughly {hours_per_week * target_weeks}h."
        )

        prompt = f"""You are a career development expert. Create a detailed learning roadmap for someone who wants to become a {target_role}.
{res_ctx}
Difficulty Level: {difficulty}
Path Type: {path_type}
{path_ctx}
{time_ctx}

Return ONLY a valid JSON object with this exact structure:
{{
  "title": "Roadmap title",
  "description": "Brief description",
  "estimated_weeks": {target_weeks},
  "category": "technology",
  "tags": ["tag1", "tag2"],
  "stages": [
    {{
      "title": "Stage title",
      "description": "Stage description",
      "order": 1,
      "color": "#8B5CF6",
      "icon": "📚",
      "estimated_hours": 20,
      "difficulty": "{difficulty}",
      "tasks": [
        {{
          "title": "Task title",
          "description": "Task description",
          "order": 1,
          "estimated_hours": 4,
          "resources": [
            {{
              "title": "Resource name",
              "url": "https://example.com",
              "type": "video",
              "description": "Brief description"
            }}
          ]
        }}
      ]
    }}
  ]
}}

Rules:
- Create 4-6 stages appropriate for {target_weeks} weeks
- Each stage should have 3-6 tasks
- Resource types: "video", "article", "course", "docs"
- Colors: use varied hex colors per stage
- Icons: use relevant emojis
- All tasks and resources must be realistic and specific to {target_role}
- Do NOT include any text outside the JSON"""

        try:
            response = self.client.chat.completions.create(
                messages=[{"role": "user", "content": prompt}],
                model=self.model,
                temperature=0.4,
                max_tokens=4000,
            )

            text = response.choices[0].message.content.strip()

            # Clean JSON
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0]
            elif "```" in text:
                text = text.split("```")[1].split("```")[0]

            j_start = text.find('{')
            j_end = text.rfind('}') + 1
            if j_start != -1 and j_end > j_start:
                text = text[j_start:j_end]

            return json.loads(text.strip())

        except Exception as e:
            # Fallback minimal roadmap so it never crashes
            return {
                "title": f"{target_role} Roadmap",
                "description": f"Learning path for {target_role}",
                "estimated_weeks": target_weeks,
                "category": "technology",
                "tags": [target_role.lower()],
                "stages": [
                    {
                        "title": "Foundation",
                        "description": "Core fundamentals",
                        "order": 1,
                        "color": "#8B5CF6",
                        "icon": "📚",
                        "estimated_hours": hours_per_week * 2,
                        "difficulty": difficulty,
                        "tasks": [
                            {
                                "title": f"Learn {target_role} basics",
                                "description": "Start with the fundamentals",
                                "order": 1,
                                "estimated_hours": hours_per_week,
                                "resources": [],
                            }
                        ],
                    }
                ],
            }