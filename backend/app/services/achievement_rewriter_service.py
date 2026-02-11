import os
from typing import Dict, List
from groq import Groq
from dotenv import load_dotenv
import json

load_dotenv()

class AchievementRewriterService:
    """Rewrite weak resume bullets into powerful STAR-format achievements"""
    
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY not found")
        
        self.client = Groq(api_key=api_key)
        self.model = "llama-3.3-70b-versatile"
        
        # Power verbs database for different categories of achievements - this can be expanded over time -_-
        self.power_verbs = {
            'leadership': ['Led', 'Directed', 'Managed', 'Coordinated', 'Supervised', 'Mentored', 'Guided', 'Orchestrated'],
            'achievement': ['Achieved', 'Accomplished', 'Delivered', 'Exceeded', 'Surpassed', 'Attained', 'Completed'],
            'creation': ['Developed', 'Created', 'Built', 'Designed', 'Engineered', 'Architected', 'Established', 'Launched'],
            'improvement': ['Improved', 'Enhanced', 'Optimized', 'Streamlined', 'Upgraded', 'Modernized', 'Transformed'],
            'analysis': ['Analyzed', 'Evaluated', 'Assessed', 'Researched', 'Investigated', 'Examined', 'Identified'],
            'communication': ['Presented', 'Communicated', 'Articulated', 'Collaborated', 'Negotiated', 'Facilitated'],
            'problem_solving': ['Solved', 'Resolved', 'Troubleshot', 'Debugged', 'Fixed', 'Addressed', 'Mitigated'],
            'growth': ['Increased', 'Grew', 'Expanded', 'Scaled', 'Boosted', 'Amplified', 'Accelerated'],
            'reduction': ['Reduced', 'Decreased', 'Minimized', 'Cut', 'Lowered', 'Eliminated', 'Consolidated']
        }
    
    def rewrite_bullet_points(self, bullet_points: List[str], job_context: str = None) -> Dict:
        """
        Rewrite weak bullet points into powerful STAR-format achievements
        
        STAR = Situation, Task, Action, Result
        """
        
        system_prompt = """You are an expert resume writer specializing in achievement-oriented bullet points.
You transform weak, duty-focused statements into powerful, results-driven achievements using the STAR method.

STAR Method:
- Situation: Brief context
- Task: What needed to be done
- Action: What you did
- Result: Quantifiable outcome

Rules:
1. Start with strong action verbs
2. Include specific metrics and numbers
3. Show impact and results
4. Be concise (1-2 lines max)
5. Focus on achievements, not duties"""

        bullets_text = "\n".join([f"{i+1}. {bullet}" for i, bullet in enumerate(bullet_points)])
        
        user_prompt = f"""Rewrite these resume bullet points into powerful STAR-format achievements:

ORIGINAL BULLETS:
{bullets_text}

{f"JOB CONTEXT: {job_context}" if job_context else ""}

For EACH bullet point, provide:

Return ONLY valid JSON:

{{
  "rewritten_bullets": [
    {{
      "original": "original bullet text",
      "rewritten": "Powerful achievement with metrics and impact",
      "improvements": [
        "Added quantifiable result (25% improvement)",
        "Used strong action verb (Led instead of Worked on)",
        "Included specific technology/tool"
      ],
      "power_verb_used": "Led",
      "metrics_added": ["25% improvement", "3-person team"],
      "star_elements": {{
        "situation": "Brief context",
        "task": "What needed doing",
        "action": "What you did",
        "result": "Measurable outcome"
      }},
      "strength_score": 8.5,
      "missing_elements": ["Could add timeframe"] or []
    }}
  ],
  "overall_improvements": {{
    "weak_verbs_replaced": 5,
    "metrics_added": 3,
    "average_strength_increase": "+45%"
  }},
  "power_verb_suggestions": {{
    "leadership": ["Led", "Directed", "Managed"],
    "technical": ["Developed", "Architected", "Engineered"],
    "impact": ["Increased", "Improved", "Optimized"]
  }}
}}

Make every bullet demonstrate VALUE and IMPACT."""

        try:
            print("✨ Rewriting achievements with AI...")
            
            response = self.client.chat.completions.create(
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                model=self.model,
                temperature=0.3,
                max_tokens=3000,
                top_p=0.9
            )
            
            response_text = response.choices[0].message.content.strip()
            response_text = self._clean_json(response_text)
            
            rewrite_data = json.loads(response_text)
            
            return {
                'success': True,
                'rewrite_data': rewrite_data,
                'tokens_used': response.usage.total_tokens
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f"Rewriting failed: {str(e)}"
            }
    
    def suggest_quantification(self, bullet_point: str) -> Dict:
        """Suggest how to add numbers/metrics to a bullet point"""
        
        system_prompt = """You help add quantifiable metrics to resume achievements."""
        
        user_prompt = f"""This bullet point lacks metrics: "{bullet_point}"

Suggest specific numbers/metrics to add. Return JSON:

{{
  "original": "original text",
  "suggestions": [
    {{
      "metric_type": "time_saved",
      "suggestion": "Add how much time was saved (e.g., 'reduced processing time by 40%')",
      "example": "Optimized database queries, reducing load time by 40% (from 5s to 3s)"
    }},
    {{
      "metric_type": "team_size",
      "suggestion": "Mention team size if applicable",
      "example": "Led team of 5 developers in building..."
    }}
  ],
  "questions_to_ask": [
    "How many users/customers were impacted?",
    "What percentage improvement did you achieve?",
    "How much time/money was saved?"
  ]
}}"""

        try:
            response = self.client.chat.completions.create(
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                model=self.model,
                temperature=0.2,
                max_tokens=1000
            )
            
            response_text = self._clean_json(response.choices[0].message.content.strip())
            data = json.loads(response_text)
            
            return {'success': True, 'data': data}
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_power_verbs(self, category: str = None) -> List[str]:
        """Get list of power verbs by category"""
        if category and category in self.power_verbs:
            return self.power_verbs[category]
        return self.power_verbs
    
    def _clean_json(self, text: str) -> str:
        """Clean JSON response"""
        if text.startswith("```json"):
            text = text[7:]
        if text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]
        
        text = text.strip()
        
        json_start = text.find('{')
        json_end = text.rfind('}') + 1
        
        if json_start != -1 and json_end > json_start:
            text = text[json_start:json_end]
        
        return text
