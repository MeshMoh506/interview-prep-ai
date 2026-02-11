# This service handles the core logic of matching resumes to job descriptions and providing optimization suggestions.
import os
from typing import Dict, List
from groq import Groq
from dotenv import load_dotenv
import json
import re

load_dotenv()

class JobMatcherService:
    """Match resume to job descriptions and provide optimization suggestions"""
    
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY not found")
        
        self.client = Groq(api_key=api_key)
        self.model = "llama-3.3-70b-versatile"
    
    def match_to_job(self, resume_text: str, job_description: str) -> Dict: # Compare resume to job description and provide match analysis
        """
        Compare resume to job description and provide match analysis
        
        Returns:
        - match_score (0-100)
        - matching_keywords
        - missing_keywords
        - suggestions for improvement 
        """
        
        system_prompt = """You are an expert ATS (Applicant Tracking System) analyzer and career coach. 
You help job seekers optimize their resumes to match specific job descriptions and improve their chances of getting hired."""

        user_prompt = f"""Compare this resume to the job description and provide detailed matching analysis.

RESUME:
{resume_text[:4000]}

JOB DESCRIPTION:
{job_description[:2000]} 

Return ONLY a valid JSON object:

{{
  "match_score": <0-100, how well resume matches job>,
  "summary": "<2-3 sentence overall assessment>",
  "matching_keywords": [
    {{"keyword": "Python", "found_in_resume": true, "importance": "critical"}},
    {{"keyword": "React", "found_in_resume": true, "importance": "high"}}
  ],
  "missing_keywords": [
    {{"keyword": "AWS", "importance": "critical", "suggestion": "Add cloud deployment experience"}},
    {{"keyword": "Docker", "importance": "high", "suggestion": "Mention containerization skills"}}
  ],
  "skills_gap": [
    "Required: 5+ years experience (Resume shows: 2 years)",
    "Required: Team leadership (Not mentioned in resume)"
  ],
  "strengths": [
    "Strong technical skills match",
    "Relevant project experience",
    "Education aligns with requirements"
  ],
  "recommendations": [
    {{
      "priority": "critical",
      "action": "Add AWS/Cloud experience to skills section",
      "impact": "Will increase match score by 15 points"
    }},
    {{
      "priority": "high",
      "action": "Quantify achievements with metrics",
      "impact": "Will make resume more competitive"
    }}
  ],
  "sections_to_emphasize": [
    "Technical Skills - matches 80% of job requirements",
    "Projects - demonstrate practical experience"
  ],
  "ats_compatibility": {{
    "score": 85,
    "issues": ["Use standard section headers", "Add more keywords"],
    "optimizations": ["Move skills to top", "Add keyword-rich summary"]
  }}
}}

Be specific and actionable. Focus on what will actually improve their chances and make them more competitive."""

        try:
            print("🤖 Analyzing job match with AI...")
            
            response = self.client.chat.completions.create(
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                model=self.model,
                temperature=0.2,
                max_tokens=3000,
                top_p=0.9
            )
            # this is the response from the AI, we need to extract the content and parse it as JSON
            response_text = response.choices[0].message.content.strip()
            
            # Clean JSON
            response_text = self._clean_json(response_text)
            
            # Parse
            match_data = json.loads(response_text)
            
            return {
                'success': True,
                'match_data': match_data,
                'tokens_used': response.usage.total_tokens
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f"Job matching failed: {str(e)}"
            }
    
    def extract_job_keywords(self, job_description: str) -> Dict:
        """
        Extract key requirements and keywords from job description
        """
        
        system_prompt = """You are an expert at analyzing job descriptions and extracting key requirements."""

        user_prompt = f"""Extract key information from this job description:

{job_description}

Return ONLY valid JSON:

{{
  "job_title": "exact job title",
  "company": "company name or null",
  "required_skills": [
    {{"skill": "Python", "category": "Programming", "priority": "critical"}},
    {{"skill": "React", "category": "Frontend", "priority": "high"}}
  ],
  "preferred_skills": [
    {{"skill": "AWS", "category": "Cloud", "priority": "medium"}}
  ],
  "experience_required": "X years" or null,
  "education_required": "degree requirement" or null,
  "keywords": ["keyword1", "keyword2", ...],
  "responsibilities": ["main responsibility 1", "main responsibility 2"],
  "key_phrases": ["phrases to include in resume"]
}}"""

        try:
            response = self.client.chat.completions.create(
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                model=self.model,
                temperature=0.1,
                max_tokens=2000
            )
            
            response_text = self._clean_json(response.choices[0].message.content.strip())
            extracted = json.loads(response_text)
            
            return {
                'success': True,
                'job_data': extracted
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def _clean_json(self, text: str) -> str:
        """Clean JSON response from AI"""
        # Remove markdown
        if text.startswith("```json"):
            text = text[7:]
        if text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]
        
        text = text.strip()
        
        # Extract JSON object
        json_start = text.find('{')
        json_end = text.rfind('}') + 1
        
        if json_start != -1 and json_end > json_start:
            text = text[json_start:json_end]
        
        return text
