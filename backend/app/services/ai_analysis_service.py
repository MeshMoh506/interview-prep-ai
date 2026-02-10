import os
from typing import Dict
from groq import Groq
from dotenv import load_dotenv
import json

load_dotenv()

class AIAnalysisService:
    """AI-powered resume analysis and scoring"""
    
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY not found")
        
        self.client = Groq(api_key=api_key)
        self.model = "llama-3.3-70b-versatile"
    
    def analyze_resume(self, resume_text: str, target_role: str = None) -> Dict:
        """
        Analyze resume and provide comprehensive feedback
        
        Returns:
        - overall_score (1-10)
        - strengths (list)
        - weaknesses (list)
        - ats_score (1-10)
        - improvement_suggestions (list)
        - missing_sections (list)
        """
        
        system_prompt = """You are an expert resume reviewer and career coach with 20+ years of experience 
                           You provide honest, actionable feedback to help job seekers improve their resumes ,Please don't flatter; the truth hurts, but it teaches and helps you grow."""

        user_prompt = f"""Analyze this resume and provide detailed feedback. Return ONLY a valid JSON object:

{{
  "overall_score": <number 1-10>,
  "summary": "<2-3 sentence overall assessment>",
  "strengths": [
    "<specific strength with evidence>",
    "<another strength>",
    "<etc - 5 total>"
  ],
  "weaknesses": [
    "<specific weakness with example>",
    "<another weakness>",
    "<etc - 5 total>"
  ],
  "ats_score": <number 1-10 for ATS compatibility>,
  "ats_issues": [
    "<ATS compatibility issue>",
    "<another issue>",
    "<etc>"
  ],
  "missing_sections": [
    "<important missing section>",
    "<etc>"
  ],
  "improvement_suggestions": [
    {{
      "section": "<section name>",
      "issue": "<what's wrong>",
      "suggestion": "<how to fix>",
      "priority": "high|medium|low",
      "example": "<good example if applicable>"
    }}
  ],
  "keyword_recommendations": [
    "<relevant keyword to add>",
    "<etc - 10-15 keywords>"
  ]
}}

{f"Target Role: {target_role}" if target_role else ""}

Resume text:
{resume_text}

Be specific, constructive, and actionable."""

        try:
            print("🤖 Analyzing resume with AI...")
            
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
            
            # Clean and parse JSON
            if response_text.startswith("```json"):
                response_text = response_text[7:]
            if response_text.startswith("```"):
                response_text = response_text[3:]
            if response_text.endswith("```"):
                response_text = response_text[:-3]
            
            response_text = response_text.strip()
            
            # Find JSON
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            # Sometimes AI adds text before/after the JSON, so we extract just the JSON part
            if json_start != -1 and json_end > json_start:
                response_text = response_text[json_start:json_end]
            
            analysis = json.loads(response_text)
            
            return {
                'success': True,
                'analysis': analysis,
                'tokens_used': response.usage.total_tokens
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f"Analysis failed: {str(e)}"
            }
