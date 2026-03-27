# app/services/behavior_analysis_service.py
"""
Comprehensive interview behavior analysis combining:
  1. Camera frames  → facial/body language signals
  2. Voice audio    → tone, confidence, filler words  
  3. Answer quality → already scored by interview AI

Final output: one unified behavior + performance report.
"""

import json
import base64
import asyncio
from typing import Optional
from groq import AsyncGroq
from app.config import settings

_client = AsyncGroq(api_key=settings.GROQ_API_KEY)


# ═══════════════════════════════════════════════════════════════════
# 1. CAMERA FRAME ANALYSIS
# ═══════════════════════════════════════════════════════════════════

_VISION_PROMPT = """You are an expert interview coach analyzing a live video interview frame.
Look at the interviewee's face, posture, and hands carefully.

Score each 0-100:
- face_confidence: steady gaze, calm expression, upright posture
- face_nervousness: tense jaw, averted eyes, rapid blinking, furrowed brow
- face_engagement: eye contact with camera, attentive expression
- hands_nervousness: fidgeting, clasping, touching face
- posture_score: upright, stable, professional position

Also identify:
- dominant_emotion: one of "confident" | "nervous" | "calm" | "distracted" | "focused" | "uncertain"
- face_visible: true/false
- hands_visible: true/false
- brief_note: one observation (max 10 words)

Respond ONLY in raw JSON:
{"face_confidence":0,"face_nervousness":0,"face_engagement":0,"hands_nervousness":0,"posture_score":0,"dominant_emotion":"calm","face_visible":true,"hands_visible":false,"brief_note":""}"""


async def analyze_video_frame(frame_b64: str, mime: str = "image/jpeg") -> Optional[dict]:
    """Analyze one camera frame for behavioral signals."""
    try:
        r = await _client.chat.completions.create(
            model="llama-3.2-11b-vision-preview",
            messages=[{"role": "user", "content": [
                {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{frame_b64}"}},
                {"type": "text", "text": _VISION_PROMPT},
            ]}],
            max_tokens=200,
            temperature=0.1,
        )
        raw = r.choices[0].message.content.strip().replace("```json", "").replace("```", "").strip()
        return json.loads(raw)
    except Exception as e:
        print(f"[Behavior/Vision] frame error: {e}")
        return None


# ═══════════════════════════════════════════════════════════════════
# 2. VOICE TONE ANALYSIS
# ═══════════════════════════════════════════════════════════════════

_VOICE_PROMPT = """You are an expert interviewer analyzing a transcribed voice answer.
Evaluate the TONE and DELIVERY, not just the content.

Look for:
- Confidence signals: clear statements, no excessive hedging
- Nervousness signals: filler words (um, uh, like, you know), very short answers, trailing off
- Pace: too fast (nervous), too slow (hesitant), appropriate
- Clarity: organized thoughts vs rambling

Score 0-100:
- voice_confidence: how confident they sound
- voice_clarity: clear, organized delivery  
- voice_pace_score: 100=perfect pace, lower if too fast/slow
- filler_word_count: estimated number of filler words (um, uh, like, you know, basically)

Also:
- pace_assessment: "too_fast" | "appropriate" | "too_slow"
- key_filler_words: list of filler words detected (max 5)
- voice_note: one observation (max 10 words)

Transcription: "{transcription}"

Respond ONLY in raw JSON:
{"voice_confidence":0,"voice_clarity":0,"voice_pace_score":0,"filler_word_count":0,"pace_assessment":"appropriate","key_filler_words":[],"voice_note":""}"""


async def analyze_voice_tone(transcription: str) -> Optional[dict]:
    """Analyze voice/speech delivery from transcription text."""
    if not transcription or len(transcription.strip()) < 5:
        return None
    try:
        r = await _client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": _VOICE_PROMPT.format(transcription=transcription)}],
            max_tokens=200,
            temperature=0.1,
        )
        raw = r.choices[0].message.content.strip().replace("```json", "").replace("```", "").strip()
        return json.loads(raw)
    except Exception as e:
        print(f"[Behavior/Voice] analysis error: {e}")
        return None


# ═══════════════════════════════════════════════════════════════════
# 3. UNIFIED SESSION AGGREGATION
# ═══════════════════════════════════════════════════════════════════

def aggregate_behavior_session(
    video_frames: list[dict],       # from analyze_video_frame()
    voice_analyses: list[dict],     # from analyze_voice_tone()
    interview_score: float,         # 0-100, from interview AI
    answer_count: int,
    language: str = "en",
) -> dict:
    """
    Combine camera + voice + answer quality into one final report.
    This runs when the interview ends.
    """

    # ── Camera aggregation ─────────────────────────────────────────
    valid_frames = [f for f in video_frames if f and f.get("face_visible")]
    cam_data = _aggregate_camera(valid_frames)

    # ── Voice aggregation ──────────────────────────────────────────
    valid_voice = [v for v in voice_analyses if v]
    voice_data  = _aggregate_voice(valid_voice)

    # ── Combined score ─────────────────────────────────────────────
    # Weights: camera 35% + voice 30% + answer quality 35%
    cam_score   = cam_data["camera_performance_score"]
    voice_score = voice_data["voice_performance_score"]

    overall = (
        cam_score   * 0.35 +
        voice_score * 0.30 +
        interview_score * 0.35
    )
    overall = round(max(0, min(100, overall)), 1)

    # ── Dominant signal ────────────────────────────────────────────
    emotions = [f.get("dominant_emotion", "calm") for f in valid_frames]
    dominant = max(set(emotions), key=emotions.count) if emotions else "unknown"

    # ── Verdict ───────────────────────────────────────────────────
    verdict, verdict_ar = _build_verdict(overall, cam_data, voice_data)

    # ── Tips ──────────────────────────────────────────────────────
    tips = _build_tips(cam_data, voice_data, language)

    return {
        # Overall
        "overall_score":          overall,
        "interview_answer_score": round(interview_score, 1),
        "camera_score":           round(cam_score, 1),
        "voice_score":            round(voice_score, 1),

        # Camera breakdown
        "camera": {
            "face_confidence":    cam_data["face_confidence"],
            "face_nervousness":   cam_data["face_nervousness"],
            "face_engagement":    cam_data["face_engagement"],
            "hands_nervousness":  cam_data["hands_nervousness"],
            "posture_score":      cam_data["posture_score"],
            "dominant_emotion":   dominant,
            "frames_analyzed":    len(valid_frames),
            "hands_visible_pct":  cam_data["hands_visible_pct"],
        },

        # Voice breakdown
        "voice": {
            "voice_confidence":   voice_data["voice_confidence"],
            "voice_clarity":      voice_data["voice_clarity"],
            "voice_pace_score":   voice_data["voice_pace_score"],
            "avg_filler_words":   voice_data["avg_filler_words"],
            "pace_assessment":    voice_data["pace_assessment"],
            "common_fillers":     voice_data["common_fillers"],
            "answers_analyzed":   len(valid_voice),
        },

        # Summary
        "verdict":     verdict,
        "verdict_ar":  verdict_ar,
        "tips":        tips,
        "answer_count": answer_count,
    }


def _aggregate_camera(frames: list[dict]) -> dict:
    if not frames:
        return {
            "camera_performance_score": 50,
            "face_confidence": 0, "face_nervousness": 0,
            "face_engagement": 0, "hands_nervousness": 0,
            "posture_score": 0, "hands_visible_pct": 0,
        }
    n = len(frames)
    avg = lambda k: round(sum(f.get(k, 50) for f in frames) / n, 1)

    conf  = avg("face_confidence")
    nerv  = avg("face_nervousness")
    eng   = avg("face_engagement")
    hands = avg("hands_nervousness")
    post  = avg("posture_score")
    hands_pct = round(sum(1 for f in frames if f.get("hands_visible")) / n * 100, 1)

    # Camera score: confidence + engagement + posture, penalize nervousness
    cam_score = (conf * 0.40 + eng * 0.30 + post * 0.30) - (nerv * 0.15) - (hands * 0.05)
    cam_score = max(0, min(100, cam_score))

    return {
        "camera_performance_score": round(cam_score, 1),
        "face_confidence": conf, "face_nervousness": nerv,
        "face_engagement": eng, "hands_nervousness": hands,
        "posture_score": post, "hands_visible_pct": hands_pct,
    }


def _aggregate_voice(analyses: list[dict]) -> dict:
    if not analyses:
        return {
            "voice_performance_score": 50,
            "voice_confidence": 0, "voice_clarity": 0,
            "voice_pace_score": 0, "avg_filler_words": 0,
            "pace_assessment": "unknown", "common_fillers": [],
        }
    n = len(analyses)
    avg = lambda k: round(sum(a.get(k, 50) for a in analyses) / n, 1)

    conf  = avg("voice_confidence")
    clar  = avg("voice_clarity")
    pace  = avg("voice_pace_score")
    fills = round(sum(a.get("filler_word_count", 0) for a in analyses) / n, 1)

    # Collect all filler words
    all_fillers: dict[str, int] = {}
    for a in analyses:
        for fw in a.get("key_filler_words", []):
            all_fillers[fw] = all_fillers.get(fw, 0) + 1
    top_fillers = sorted(all_fillers, key=all_fillers.get, reverse=True)[:5]

    pace_counts = {}
    for a in analyses:
        p = a.get("pace_assessment", "appropriate")
        pace_counts[p] = pace_counts.get(p, 0) + 1
    dominant_pace = max(pace_counts, key=pace_counts.get) if pace_counts else "appropriate"

    voice_score = (conf * 0.45 + clar * 0.35 + pace * 0.20) - min(fills * 3, 20)
    voice_score = max(0, min(100, voice_score))

    return {
        "voice_performance_score": round(voice_score, 1),
        "voice_confidence": conf, "voice_clarity": clar,
        "voice_pace_score": pace, "avg_filler_words": fills,
        "pace_assessment": dominant_pace, "common_fillers": top_fillers,
    }


def _build_verdict(score: float, cam: dict, voice: dict) -> tuple[str, str]:
    if score >= 80:
        en = "Outstanding performance. You presented yourself with confidence and clarity."
        ar = "أداء ممتاز. قدمت نفسك بثقة ووضوح كبيرين."
    elif score >= 65:
        en = "Good performance. You communicated effectively with some room to improve."
        ar = "أداء جيد. تواصلت بفعالية مع بعض المجال للتطوير."
    elif score >= 50:
        en = "Decent effort. Focus on reducing nervousness and improving answer structure."
        ar = "جهد جيد. ركز على تقليل التوتر وتحسين بنية الإجابات."
    else:
        en = "Keep practicing. Interview skills improve significantly with repetition."
        ar = "استمر في التدريب. مهارات المقابلة تتحسن بشكل ملحوظ مع التكرار."
    return en, ar


def _build_tips(cam: dict, voice: dict, lang: str) -> list[dict]:
    """Return localized tips based on weakest areas."""
    tips = []
    is_ar = lang == "ar"

    if cam["face_nervousness"] > 55:
        tips.append({
            "icon": "😮‍💨",
            "en": "Take a slow breath before each answer — it visibly reduces tension.",
            "ar": "خذ نفساً هادئاً قبل كل إجابة — يقلل التوتر بشكل واضح.",
            "area": "nervousness",
        })
    if cam["face_confidence"] < 50:
        tips.append({
            "icon": "🧍",
            "en": "Sit up straight and keep your shoulders relaxed to project confidence.",
            "ar": "اجلس مستقيماً مع إرخاء كتفيك لتظهر بثقة.",
            "area": "posture",
        })
    if cam["face_engagement"] < 55:
        tips.append({
            "icon": "👁️",
            "en": "Look directly into the camera lens — it reads as eye contact to the interviewer.",
            "ar": "انظر مباشرة إلى عدسة الكاميرا — يُقرأ كتواصل بصري للمحاور.",
            "area": "eye_contact",
        })
    if cam["hands_visible_pct"] < 50:
        tips.append({
            "icon": "🤲",
            "en": "Keep your hands visible and use them naturally — it signals openness.",
            "ar": "أبقِ يديك مرئيتين واستخدمهما بشكل طبيعي — يُشير إلى الانفتاح.",
            "area": "hands",
        })
    if voice["avg_filler_words"] > 4:
        fillers = ", ".join(voice["common_fillers"][:3]) if voice["common_fillers"] else "um, uh"
        tips.append({
            "icon": "🗣️",
            "en": f"Reduce filler words like '{fillers}'. Pause silently instead.",
            "ar": f"قلل كلمات الحشو مثل '{fillers}'. توقف بصمت بدلاً منها.",
            "area": "filler_words",
        })
    if voice["voice_clarity"] < 55:
        tips.append({
            "icon": "📋",
            "en": "Structure answers: Situation → Action → Result (STAR method).",
            "ar": "نظّم إجاباتك: الموقف ← الإجراء ← النتيجة (طريقة STAR).",
            "area": "clarity",
        })
    if voice["pace_assessment"] == "too_fast":
        tips.append({
            "icon": "⏱️",
            "en": "You spoke quickly — slow down slightly. Pauses show confidence, not weakness.",
            "ar": "تحدثت بسرعة — تمهّل قليلاً. التوقفات تُظهر الثقة لا الضعف.",
            "area": "pace",
        })
    if not tips:
        tips.append({
            "icon": "🌟",
            "en": "Excellent all-around performance. Keep this consistency.",
            "ar": "أداء ممتاز في جميع المجالات. حافظ على هذا الاتساق.",
            "area": "general",
        })

    # Localize
    for tip in tips:
        tip["text"] = tip["ar"] if is_ar else tip["en"]

    return tips