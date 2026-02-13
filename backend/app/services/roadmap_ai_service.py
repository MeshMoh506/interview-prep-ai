# app/services/roadmap_ai_service.py
import os, json, re
from typing import Dict, List, Optional

try:
    from groq import Groq
    _client = Groq(api_key=os.getenv("GROQ_API_KEY", ""))
    _USE_GROQ = True
except Exception:
    _USE_GROQ = False
    _client   = None

_MODEL = "llama-3.3-70b-versatile"


def _chat(messages, temperature=0.4, max_tokens=2000) -> str:
    if not _USE_GROQ or not _client:
        return "{}"
    r = _client.chat.completions.create(
        model=_MODEL, messages=messages,
        temperature=temperature, max_tokens=max_tokens)
    return r.choices[0].message.content.strip()


def _parse(raw: str) -> dict:
    return json.loads(re.sub(r"```(?:json)?|```", "", raw).strip())


class RoadmapAIService:

    # ── Skill gap analysis ───────────────────────────────────
    def analyze_skill_gap(self, target_role: str, current_skills: List[str],
                          resume_text: str = "", language: str = "en") -> Dict:
        try:
            li = "Respond entirely in Arabic." if language == "ar" else "Respond in English."
            skills_str = ", ".join(current_skills[:30]) if current_skills else "none listed"
            resume_block = f"\nResume excerpt:\n{resume_text[:1000]}" if resume_text else ""
            raw = _chat([{"role": "user", "content":
                f"{li}\nAnalyze skill gap for someone targeting: {target_role}\n"
                f"Current skills: {skills_str}{resume_block}\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"required_skills":["..."],"missing_skills":["..."],"existing_skills":["..."],'
                '"priority_skills":["top 5 to learn first"],'
                '"estimated_months":<int>,'
                '"readiness_percent":<0-100>,'
                '"summary":"2 sentence gap analysis"}'
            }], max_tokens=800)
            return {"success": True, "analysis": _parse(raw)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ── Generate full roadmap ────────────────────────────────
    def generate_roadmap(self, target_role: str, missing_skills: List[str],
                         current_role: str = "", difficulty: str = "medium",
                         language: str = "en") -> Dict:
        try:
            li = "Respond entirely in Arabic." if language == "ar" else "Respond in English."
            skills_str = ", ".join(missing_skills[:15])
            raw = _chat([{"role": "user", "content":
                f"{li}\nCreate a detailed learning roadmap for: {target_role}\n"
                f"Current role: {current_role or 'student/entry level'}\n"
                f"Skills to learn: {skills_str}\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"title":"Roadmap title","milestones":['
                '{"title":"...","description":"...","skill_focus":"main skill","order_index":<int>,'
                '"difficulty":"beginner|intermediate|advanced","est_hours":<int>,'
                '"resources":['
                '{"title":"...","url":"...","resource_type":"video|course|article|practice",'
                '"platform":"YouTube|Coursera|Udemy|FreeCodeCamp|MDN|LeetCode|Official Docs|Other",'
                '"is_free":<bool>,"est_hours":<int>,"difficulty":"beginner|intermediate|advanced"}'
                ']}'
                ']}'
                "\nInclude 5-8 milestones. Each milestone should have 2-4 real, specific resources with actual URLs where possible."
            }], max_tokens=3000)
            data = _parse(raw)
            return {"success": True, "roadmap": data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ── Recommend resources for a skill ─────────────────────
    def recommend_resources(self, skill: str, level: str = "beginner",
                             language: str = "en") -> Dict:
        try:
            li = "Respond entirely in Arabic (but keep resource titles/URLs in English)." if language == "ar" else "Respond in English."
            raw = _chat([{"role": "user", "content":
                f"{li}\nRecommend the 5 best learning resources for: {skill} (level: {level})\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"resources":['
                '{"title":"...","url":"...","resource_type":"video|course|article|practice",'
                '"platform":"...","is_free":<bool>,"est_hours":<int>,'
                '"why_recommended":"one sentence"}'
                ']}'
            }], max_tokens=1000)
            return {"success": True, "resources": _parse(raw).get("resources", [])}
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ── Daily goal suggestions ───────────────────────────────
    def suggest_daily_goals(self, roadmap_title: str, current_milestone: str,
                            available_minutes: int = 60, language: str = "en") -> Dict:
        try:
            li = "Respond entirely in Arabic." if language == "ar" else "Respond in English."
            raw = _chat([{"role": "user", "content":
                f"{li}\nSuggest daily learning goals for:\n"
                f"Roadmap: {roadmap_title}\nCurrent focus: {current_milestone}\n"
                f"Available time: {available_minutes} minutes/day\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"goals":['
                '{"title":"...","description":"...","target_minutes":<int>,"type":"study|practice|project|review"}'
                ']}'
                "\nSuggest 3-5 specific, actionable goals."
            }], max_tokens=600)
            return {"success": True, "goals": _parse(raw).get("goals", [])}
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ── Progress feedback ────────────────────────────────────
    def get_progress_feedback(self, roadmap_title: str, progress: float,
                               completed_milestones: int, total_milestones: int,
                               streak_days: int, language: str = "en") -> Dict:
        try:
            li = "Respond entirely in Arabic." if language == "ar" else "Respond in English."
            raw = _chat([{"role": "user", "content":
                f"{li}\nProvide motivational progress feedback for a learner:\n"
                f"Roadmap: {roadmap_title}\n"
                f"Progress: {progress:.0f}%\n"
                f"Milestones: {completed_milestones}/{total_milestones} completed\n"
                f"Streak: {streak_days} days\n\n"
                "Return ONLY valid JSON (no markdown):\n"
                '{"message":"encouraging message","tip":"one actionable tip",'
                '"next_action":"what to do next","emoji":"1-2 relevant emojis"}'
            }], max_tokens=300)
            return {"success": True, "feedback": _parse(raw)}
        except Exception as e:
            return {"success": True, "feedback": {
                "message": "Keep going!", "tip": "Consistency is key.",
                "next_action": "Continue with your current milestone.", "emoji": "🚀"}}


roadmap_ai_service = RoadmapAIService()