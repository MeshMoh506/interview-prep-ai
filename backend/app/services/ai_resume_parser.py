import os
import json
from typing import Dict
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

class AIResumeParser:
    """AI-powered resume parser using Groq (fastest & most reliable)"""
    
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY not found in environment variables")
        
        self.client = Groq(api_key=api_key)
        
        # Use Llama 3.1 70B - Best balance of speed and accuracy
        self.model = "llama-3.3-70b-versatile"
        
        # Alternative models (if you want to try):
        # "llama-3.3-70b-versatile" - Newest, most accurate
        # "mixtral-8x7b-32768" - Good for long resumes
        # "llama-3.1-8b-instant" - Fastest but less accurate
    
    def create_parsing_prompt(self, resume_text: str) -> str:
        """Create structured prompt for resume parsing"""
        
        system_prompt = """You are an expert resume parser. Your task is to extract structured information from resumes and return it as valid JSON.

CRITICAL RULES:
1. Return ONLY valid JSON - no markdown, no explanations, no code blocks
2. Use null for missing fields (never omit fields)
3. Extract ALL skills mentioned with proper categorization
4. Be thorough - extract complete information
5. Follow the exact JSON structure provided"""

        user_prompt = f"""Extract information from this resume and return a JSON object with this EXACT structure:

{{
  "contact_info": {{
    "name": "string or null",
    "email": "string or null",
    "phone": "string or null",
    "linkedin": "string or null",
    "github": "string or null",
    "location": "string or null"
  }},
  "summary": "string or null",
  "education": [
    {{
      "institution": "string",
      "degree": "string",
      "field": "string or null",
      "year": "string or null",
      "gpa": "string or null",
      "description": "string or null"
    }}
  ],
  "experience": [
    {{
      "company": "string",
      "title": "string",
      "duration": "string",
      "location": "string or null",
      "description": "string"
    }}
  ],
  "skills": [
    {{
      "name": "string",
      "category": "Programming Languages|Web Frontend|Web Backend|Mobile|Databases|Cloud & DevOps|Tools & Technologies|Data Science|Other"
    }}
  ],
  "projects": [
    {{
      "name": "string",
      "description": "string",
      "technologies": ["string"] or null,
      "link": "string or null"
    }}
  ],
  "certifications": [
    {{
      "name": "string",
      "issuer": "string or null",
      "year": "string or null"
    }}
  ],
  "languages": ["string"]
}}

Resume text:
{resume_text}

Remember: Return ONLY the JSON object, nothing else."""

        return system_prompt, user_prompt
    
    def parse_resume_with_ai(self, resume_text: str) -> Dict:
        """
        Parse resume using Groq AI
        Returns structured data as dictionary
        """
        try:
            print("🤖 Calling Groq API with Llama 3.1 70B...")
            
            # Create prompts
            system_prompt, user_prompt = self.create_parsing_prompt(resume_text)
            
            # Call Groq API
            chat_completion = self.client.chat.completions.create(
                messages=[
                    {
                        "role": "system",
                        "content": system_prompt
                    },
                    {
                        "role": "user",
                        "content": user_prompt
                    }
                ],
                model=self.model,
                temperature=0.1,  # Low temperature for consistent output
                max_tokens=4096,  # Plenty of space for detailed parsing
                top_p=0.9,
                stream=False
            )
            
            # Extract response
            response_text = chat_completion.choices[0].message.content
            
            print(f"✅ Response received ({len(response_text)} chars)")
            
            # Clean response
            clean_response = response_text.strip()
            
            # Remove markdown code blocks if present
            if clean_response.startswith("```json"):
                clean_response = clean_response[7:]
            if clean_response.startswith("```"):
                clean_response = clean_response[3:]
            if clean_response.endswith("```"):
                clean_response = clean_response[:-3]
            
            clean_response = clean_response.strip()
            
            # Find JSON object (sometimes AI adds text before/after)
            json_start = clean_response.find('{')
            json_end = clean_response.rfind('}') + 1
            
            if json_start != -1 and json_end > json_start:
                clean_response = clean_response[json_start:json_end]
            
            # Parse JSON
            parsed_data = json.loads(clean_response)
            
            # Validate structure (ensure all required fields exist)
            required_fields = ['contact_info', 'education', 'experience', 'skills', 'projects', 'certifications']
            for field in required_fields:
                if field not in parsed_data:
                    parsed_data[field] = [] if field != 'contact_info' else {}
            
            return {
                'success': True,
                'data': parsed_data,
                'raw_response': response_text,
                'model_used': self.model,
                'tokens_used': chat_completion.usage.total_tokens
            }
            
        except json.JSONDecodeError as e:
            print(f"❌ JSON parsing error: {e}")
            return {
                'success': False,
                'error': f"Failed to parse JSON response: {str(e)}",
                'raw_response': response_text if 'response_text' in locals() else None
            }
        except Exception as e:
            print(f"❌ Error: {e}")
            return {
                'success': False,
                'error': f"AI parsing failed: {str(e)}"
            }
    
    def fallback_to_basic_extraction(self, resume_text: str) -> Dict:
        """
        Simple fallback if AI fails
        Uses basic regex extraction
        """
        import re
        
        # Extract email
        email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        emails = re.findall(email_pattern, resume_text)
        
        # Extract phone
        phone_pattern = r'\+966\s?5\d\s?\d{3}\s?\d{4}'
        phones = re.findall(phone_pattern, resume_text)
        
        # Extract name (first line)
        lines = [line.strip() for line in resume_text.split('\n') if line.strip()]
        name = lines[0] if lines else None
        
        return {
            'contact_info': {
                'email': emails[0] if emails else None,
                'phone': phones[0] if phones else None,
                'name': name,
                'linkedin': None,
                'github': None,
                'location': None
            },
            'summary': None,
            'education': [],
            'experience': [],
            'skills': [],
            'projects': [],
            'certifications': [],
            'languages': []
        }
