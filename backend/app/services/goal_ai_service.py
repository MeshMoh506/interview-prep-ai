# app/services/goal_ai_service.py
import os
import json
import re
from groq import Groq

_client = Groq(api_key=os.getenv("GROQ_API_KEY", ""))
_MODEL  = "llama-3.3-70b-versatile"


def generate_coach_tip(
    target_role: str,
    language: str,
    recent_scores: list[float],          # last 3 interview scores
    radar_dimensions: dict | None,       # from resume radar score
    interviews_done: int,
    weekly_target: int,
    current_week_count: int,
    roadmap_progress: float | None,
) -> str:
    """
    Generates a single, smart, personalized AI coach tip combining:
    - Recent interview performance trend
    - Weakest radar skill dimension (if available)
    - Weekly progress toward target
    Returns a short tip (2–3 sentences max).
    """
    lang_instruction = (
        "Respond entirely in Arabic (Modern Standard Arabic). No English."
        if language == "ar"
        else "Respond in English."
    )

    # Build context
    avg_recent = round(sum(recent_scores) / len(recent_scores), 1) if recent_scores else None
    weakest_dim = None
    if radar_dimensions:
        dims = {k: v.get("score", 0) for k, v in radar_dimensions.items() if isinstance(v, dict)}
        if dims:
            weakest_dim = min(dims, key=dims.get)
            weakest_label = radar_dimensions[weakest_dim].get("label", weakest_dim)
        else:
            weakest_label = None
    else:
        weakest_label = None

    context_parts = []
    if avg_recent is not None:
        context_parts.append(f"Recent interview average score: {avg_recent}/100")
    if weakest_label:
        context_parts.append(f"Weakest resume skill dimension: {weakest_label}")
    if weekly_target > 0:
        context_parts.append(
            f"Weekly interview goal: {current_week_count}/{weekly_target} done this week"
        )
    if roadmap_progress is not None:
        context_parts.append(f"Roadmap progress: {roadmap_progress:.0f}%")

    context_str = "\n".join(context_parts) if context_parts else "User is just getting started."

    prompt = (
        f"{lang_instruction}\n\n"
        f"You are an AI career coach. The user's goal is to become a {target_role}.\n\n"
        f"Their current status:\n{context_str}\n\n"
        f"Write ONE short, specific, actionable coaching tip (2–3 sentences) "
        f"that will most help them this week. "
        f"Be encouraging but honest. Focus on the most impactful thing they can do right now. "
        f"Do NOT use bullet points. Do NOT start with 'Based on'. Just speak to them directly."
    )

    try:
        r = _client.chat.completions.create(
            model=_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7,
            max_tokens=150,
        )
        tip = r.choices[0].message.content.strip()
        # Strip CJK leak
        tip = re.sub(
            r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af]+',
            '', tip
        ).strip()
        return tip
    except Exception as e:
        # Fallback tip
        if language == "ar":
            return f"استمر في التدريب اليومي نحو هدفك كـ {target_role}. الثبات هو مفتاح النجاح."
        return f"Stay consistent with your daily practice toward becoming a {target_role}. Small steps every day add up fast."