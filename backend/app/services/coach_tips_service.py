# app/services/coach_tips_service.py
# Generates personalized AI coach tips based on the user's behavior analysis data.
# Uses stress, confidence, nervousness, voice clarity — all from behavior_analysis_service.
# Called after session-summary is ready.

import json
import re
from typing import Optional
from groq import Groq
from app.config import settings

client = Groq(api_key=settings.GROQ_API_KEY)
MODEL  = "llama-3.3-70b-versatile"


def generate_coach_tips(
    behavior_report: dict,
    job_role:        str,
    language:        str = "en",
    goal_context:    str = "",
) -> list[dict]:
    """
    Generate 3-5 personalized coach tips based on the user's
    actual behavioral data: confidence, stress/nervousness,
    voice clarity, pace, filler words, engagement, posture.

    Returns a list of tip dicts:
      [{"icon": "💪", "category": "confidence", "title": "...", "detail": "..."}]
    """
    is_ar = language == "ar"
    lang  = "Arabic" if is_ar else "English"

    # Extract all behavioral signals
    cam   = behavior_report.get("camera", {})
    voice = behavior_report.get("voice",  {})

    conf        = cam.get("face_confidence",   0)
    nerv        = cam.get("face_nervousness",  0)
    eng         = cam.get("face_engagement",   0)
    posture     = cam.get("posture_score",     0)
    emotion     = cam.get("dominant_emotion",  "unknown")
    hands_pct   = cam.get("hands_visible_pct", 0)

    v_conf      = voice.get("voice_confidence",  0)
    v_clar      = voice.get("voice_clarity",     0)
    v_pace      = voice.get("voice_pace_score",  0)
    fillers     = voice.get("avg_filler_words",  0)
    pace        = voice.get("pace_assessment",   "appropriate")
    top_fillers = voice.get("common_fillers",    [])

    overall     = behavior_report.get("overall_score", 0)
    cam_score   = behavior_report.get("camera_score",  0)
    voice_score = behavior_report.get("voice_score",   0)

    goal_line = f"\nGoal context: {goal_context[:200]}" if goal_context else ""

    prompt = f"""You are an expert interview coach. Based on this candidate's REAL behavioral data 
from their video interview, generate 4-5 highly personalized coaching tips.

Candidate data:
- Job Role: {job_role}
- Overall behavior score: {overall}/100
- Camera/Body: confidence={conf}%, nervousness={nerv}%, engagement={eng}%, posture={posture}%
- Dominant emotion during interview: {emotion}
- Hands visible: {hands_pct}% of the time
- Voice: confidence={v_conf}%, clarity={v_clar}%, pace_score={v_pace}%
- Average filler words per answer: {fillers}
- Pace assessment: {pace}
- Most common filler words: {", ".join(top_fillers) if top_fillers else "none detected"}
- Camera score: {cam_score}/100, Voice score: {voice_score}/100
{goal_line}

RULES:
- Tips must be SPECIFIC to this person's actual data, not generic.
- Reference their exact numbers where it helps (e.g. "You averaged {fillers} filler words per answer")
- Prioritize the 2-3 WEAKEST areas first
- Each tip must have a concrete, actionable technique to improve
- Tone: warm, encouraging coach — not harsh
- Respond in {lang}

Return ONLY valid JSON array (no markdown):
[
  {{
    "icon": "<single emoji>",
    "category": "<confidence|nervousness|voice|pace|posture|engagement|eye_contact|filler_words>",
    "title": "<short tip title, max 6 words>",
    "detail": "<2-3 sentences: what was observed + concrete technique to improve>",
    "priority": <1-5, 1=most urgent>
  }}
]"""

    try:
        r = client.chat.completions.create(
            model=MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.4,
            max_tokens=900,
        )
        raw   = r.choices[0].message.content.strip()
        clean = re.sub(r"```(?:json)?|```", "", raw).strip()
        tips  = json.loads(clean)
        # Sort by priority
        tips.sort(key=lambda t: t.get("priority", 5))
        return tips[:5]
    except Exception as e:
        print(f"[CoachTips] error: {e}")
        return _fallback_tips(conf, nerv, v_conf, fillers, pace, is_ar)


def _fallback_tips(conf, nerv, v_conf, fillers, pace, is_ar: bool) -> list[dict]:
    tips = []
    if nerv > 55:
        tips.append({
            "icon": "😮‍💨",
            "category": "nervousness",
            "title": "تقليل التوتر الظاهر" if is_ar else "Reduce visible tension",
            "detail": ("خذ نفساً عميقاً قبل الإجابة. التوقف المؤقت يُظهر الثقة لا الضعف."
                       if is_ar else
                       "Take one slow breath before each answer. Brief pauses read as confidence, not weakness."),
            "priority": 1,
        })
    if fillers > 3:
        tips.append({
            "icon": "🗣️",
            "category": "filler_words",
            "title": "تقليل كلمات الحشو" if is_ar else "Cut filler words",
            "detail": (f"استبدل كلمات الحشو بصمت مؤقت."
                       if is_ar else
                       f"Replace filler words with a silent pause. Practice answering questions aloud at home."),
            "priority": 2,
        })
    if conf < 55:
        tips.append({
            "icon": "🧍",
            "category": "posture",
            "title": "وضعية جسم أفضل" if is_ar else "Stronger body posture",
            "detail": ("اجلس مستقيماً مع إرخاء الكتفين. الوضعية الجيدة ترفع تقييم الثقة فوراً."
                       if is_ar else
                       "Sit tall with shoulders back and relaxed. Good posture instantly boosts perceived confidence."),
            "priority": 3,
        })
    if not tips:
        tips.append({
            "icon": "🌟",
            "category": "general",
            "title": "حافظ على هذا المستوى" if is_ar else "Maintain this level",
            "detail": ("أداؤك ممتاز. استمر في الممارسة للحفاظ على هذا المستوى."
                       if is_ar else
                       "Excellent performance. Keep practicing regularly to maintain this level."),
            "priority": 1,
        })
    return tips