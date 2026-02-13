import os
import json
from groq import Groq
from typing import List, Dict, Optional


class InterviewAIService:
    def __init__(self):
        self.client = Groq(api_key=os.getenv("GROQ_API_KEY"))
        self.model  = "llama-3.3-70b-versatile"

    def _system_prompt(self, job_role: str, difficulty: str, interview_type: str,
                       language: str = "en", user_context: str = "") -> str:
        diff = {
            "easy":   "Ask simple, beginner-friendly questions. Be very encouraging.",
            "medium": "Ask standard interview questions. Include some follow-ups.",
            "hard":   "Ask challenging, senior-level questions. Probe answers deeply.",
        }
        itype = {
            "behavioral": "Focus on past experiences using the STAR method (Situation, Task, Action, Result).",
            "technical":  "Focus on technical knowledge, problem-solving, and practical skills.",
            "mixed":      "Balance behavioral and technical questions equally.",
        }
        lang_instruction = ""
        if language == "ar":
            lang_instruction = """
IMPORTANT LANGUAGE RULE: You MUST respond in Arabic (العربية) throughout the entire interview.
Greet in Arabic, ask all questions in Arabic, give all feedback in Arabic.
If the candidate answers in English, politely continue in Arabic.
Use formal Arabic (الفصحى) mixed with professional tone."""
        else:
            lang_instruction = """
LANGUAGE RULE: Respond in English. If the candidate writes in Arabic, 
detect it and switch to Arabic for that response, then ask if they prefer to continue in Arabic."""

        context_section = ""
        if user_context:
            context_section = f"""
CANDIDATE PROFILE (use this to personalize the interview):
{user_context}

Use this information to:
- Greet the candidate by name if available
- Ask about specific experiences from their resume
- Tailor difficulty to their experience level
- Reference their skills when asking technical questions
"""

        return f"""You are a professional {job_role} interviewer.
Interview difficulty: {difficulty} — {diff.get(difficulty, '')}
Interview type: {interview_type} — {itype.get(interview_type, '')}
{lang_instruction}
{context_section}
YOUR STRICT RULES:
1. Start with a warm personal greeting (use candidate name if known).
2. Ask 1-2 warm-up personal questions first (background, motivation).
3. Then transition to role-specific interview questions.
4. Ask ONE question at a time ONLY. Never ask multiple questions.
5. After each answer: acknowledge briefly (1 sentence) then next question.
6. After 6-8 questions total, say: "That concludes our interview. Thank you!"
7. Keep each response under 4 sentences.
8. NEVER reveal scores or evaluations during the interview."""

    def start_interview(self, job_role: str, difficulty: str, interview_type: str,
                        language: str = "en", user_context: str = "") -> Dict:
        try:
            r = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": self._system_prompt(
                        job_role, difficulty, interview_type, language, user_context)},
                    {"role": "user", "content": "Begin the interview now."},
                ],
                temperature=0.7, max_tokens=400,
            )
            return {"success": True, "message": r.choices[0].message.content.strip()}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def get_next_question(self, job_role: str, difficulty: str, interview_type: str,
                          history: List[Dict], language: str = "en",
                          user_context: str = "") -> Dict:
        try:
            messages = [{"role": "system", "content": self._system_prompt(
                job_role, difficulty, interview_type, language, user_context)}] + history
            r = self.client.chat.completions.create(
                model=self.model, messages=messages, temperature=0.7, max_tokens=500,
            )
            msg     = r.choices[0].message.content.strip()
            is_done = "concludes our interview" in msg.lower() or \
                      "thank you for your time" in msg.lower() or \
                      "انتهت المقابلة" in msg or "شكراً لك" in msg
            return {"success": True, "message": msg, "is_done": is_done}
        except Exception as e:
            return {"success": False, "error": str(e), "is_done": False}

    def transcribe_audio(self, audio_file_path: str, language: str = None) -> Dict:
        """Transcribe audio using Groq Whisper — supports Arabic and English"""
        try:
            with open(audio_file_path, "rb") as f:
                params = {
                    "file": (audio_file_path, f, "audio/webm"),
                    "model": "whisper-large-v3",
                    "response_format": "json",
                    "temperature": 0.0,
                }
                if language:
                    params["language"] = language  # "ar" or "en"
                transcription = self.client.audio.transcriptions.create(**params)
            return {"success": True, "text": transcription.text.strip()}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def evaluate_answer(self, question: str, answer: str, job_role: str,
                        difficulty: str, language: str = "en") -> Dict:
        lang_note = "Respond in Arabic (JSON keys in English, values in Arabic)." if language == "ar" else ""
        prompt = f"""Evaluate this {difficulty} {job_role} interview answer. {lang_note}
QUESTION: {question}
ANSWER: {answer}
Return ONLY valid JSON (no markdown):
{{"score": <1-10>, "summary": "<one sentence>", "strengths": ["<s1>", "<s2>"], "improvements": ["<i1>", "<i2>"], "keywords_used": ["<k1>"], "keywords_missing": ["<k1>"], "star_method_used": <true|false>}}"""
        try:
            r   = self.client.chat.completions.create(
                model=self.model, messages=[{"role": "user", "content": prompt}],
                temperature=0.2, max_tokens=500,
            )
            raw = r.choices[0].message.content.strip().replace("```json","").replace("```","").strip()
            return {"success": True, "evaluation": json.loads(raw)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def generate_final_feedback(self, job_role: str, difficulty: str, interview_type: str,
                                qa_pairs: List[Dict], language: str = "en") -> Dict:
        lang_note = "Write all text values in Arabic. Keep JSON keys in English." if language == "ar" else ""
        qa_text = "\n\n".join([
            f"Q{i+1}: {q['question']}\nA{i+1}: {q['answer']}\nScore: {q.get('score','N/A')}/10"
            for i, q in enumerate(qa_pairs)
        ])
        prompt = f"""Final report for {difficulty} {job_role} interview ({interview_type}). {lang_note}
{qa_text}
Return ONLY valid JSON:
{{"overall_score": <0-100>, "grade": "<A|B|C|D|F>", "summary": "<2-3 sentences>",
"top_strengths": ["<s1>","<s2>","<s3>"], "areas_to_improve": ["<a1>","<a2>","<a3>"],
"best_answer": "<question text>", "weakest_answer": "<question text>",
"recommendation": "<Hire|Consider|Reject>", "action_items": ["<item1>","<item2>"]}}"""
        try:
            r   = self.client.chat.completions.create(
                model=self.model, messages=[{"role": "user", "content": prompt}],
                temperature=0.3, max_tokens=800,
            )
            raw = r.choices[0].message.content.strip().replace("```json","").replace("```","").strip()
            return {"success": True, "feedback": json.loads(raw)}
        except Exception as e:
            return {"success": False, "error": str(e)}


interview_ai_service = InterviewAIService()
