# app/services/insights_service.py
"""
S3 — Smart Insights Layer
Analyzes real user data across interviews, roadmaps, coach sessions, goals
to produce actionable intelligence that feeds all parts of the app.

Adds to the dashboard response (zero breaking changes):
  - weak_skills       → topics the user scores lowest on
  - strong_skills     → topics the user scores highest on
  - streak_days       → consecutive days with any activity
  - weekly_summary    → this week vs last week comparison
  - coach_stats       → coach session count + topics
  - next_action       → AI-free rule-based "what to do next"
  - performance_by_role → avg score per job role
"""

import json
import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


# ══════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT
# ══════════════════════════════════════════════════════════════════
def build_insights(user, db: Session) -> dict:
    """
    Build all insights for a user. Called from dashboard.py.
    Returns a dict that gets merged into the dashboard response.
    Safe — never raises, always returns valid dict.
    """
    try:
        from app.models.interview import Interview
        from app.models.roadmap import Roadmap
        from app.models.practice import PracticeSession

        uid = user.id

        interviews = (
            db.query(Interview)
            .filter(Interview.user_id == uid)
            .order_by(Interview.created_at.desc())
            .all()
        )
        completed = [iv for iv in interviews if iv.status == "completed"]

        roadmaps = (
            db.query(Roadmap)
            .filter(Roadmap.user_id == uid)
            .all()
        )

        coach_sessions = []
        try:
            coach_sessions = (
                db.query(PracticeSession)
                .filter(PracticeSession.user_id == uid)
                .all()
            )
        except Exception:
            pass

        return {
            "weak_skills":          _weak_skills(completed),
            "strong_skills":        _strong_skills(completed),
            "performance_by_role":  _performance_by_role(completed),
            "streak_days":          _streak(interviews, roadmaps, coach_sessions),
            "weekly_summary":       _weekly_summary(interviews, roadmaps),
            "coach_stats":          _coach_stats(coach_sessions),
            "next_action":          _next_action(completed, roadmaps, coach_sessions, user),
            "improvement_velocity": _velocity(completed),
        }

    except Exception as e:
        logger.error(f"Insights error for user {user.id}: {e}")
        return _empty_insights()


# ══════════════════════════════════════════════════════════════════
# WEAK / STRONG SKILLS
# Extracted from interview feedback JSON field.
# feedback can be: {"weak_areas": [...], "strengths": [...], "topics": {...}}
# or a list of dicts with "topic" and "score" keys
# ══════════════════════════════════════════════════════════════════
def _weak_skills(completed: list) -> list[dict]:
    """
    Returns top 5 weakest skill areas with avg score.
    Looks inside interview.feedback for skill data.
    """
    topic_scores = defaultdict(list)

    for iv in completed:
        if not iv.feedback:
            continue
        fb = iv.feedback if isinstance(iv.feedback, dict) else {}

        # Pattern 1: {"topics": {"Python": 60, "SQL": 40}}
        topics = fb.get("topics", {})
        if isinstance(topics, dict):
            for topic, score in topics.items():
                if isinstance(score, (int, float)):
                    topic_scores[topic].append(float(score))

        # Pattern 2: {"weak_areas": ["Communication", "System Design"]}
        weak = fb.get("weak_areas", [])
        if isinstance(weak, list):
            for area in weak:
                if isinstance(area, str):
                    topic_scores[area].append(40.0)  # penalize

        # Pattern 3: {"scores": [{"topic": "Python", "score": 55}]}
        scores_list = fb.get("scores", [])
        if isinstance(scores_list, list):
            for item in scores_list:
                if isinstance(item, dict):
                    t = item.get("topic") or item.get("skill") or ""
                    s = item.get("score") or item.get("value") or 0
                    if t and isinstance(s, (int, float)):
                        topic_scores[t].append(float(s))

        # Pattern 4: role-level score as proxy
        if iv.score is not None and iv.job_role:
            topic_scores[iv.job_role].append(float(iv.score))

    if not topic_scores:
        return []

    avg_scores = {
        t: round(sum(s) / len(s), 1)
        for t, s in topic_scores.items()
        if len(s) >= 1
    }

    # Weakest = lowest avg score
    sorted_weak = sorted(avg_scores.items(), key=lambda x: x[1])[:5]
    return [{"skill": t, "avg_score": s, "sessions": len(topic_scores[t])}
            for t, s in sorted_weak if s < 75]


def _strong_skills(completed: list) -> list[dict]:
    topic_scores = defaultdict(list)
    for iv in completed:
        if iv.score and iv.job_role:
            topic_scores[iv.job_role].append(float(iv.score))
        fb = iv.feedback if isinstance(iv.feedback, dict) else {}
        topics = fb.get("topics", {})
        if isinstance(topics, dict):
            for topic, score in topics.items():
                if isinstance(score, (int, float)):
                    topic_scores[topic].append(float(score))
        strengths = fb.get("strengths", [])
        if isinstance(strengths, list):
            for area in strengths:
                if isinstance(area, str):
                    topic_scores[area].append(85.0)

    if not topic_scores:
        return []

    avg_scores = {
        t: round(sum(s) / len(s), 1)
        for t, s in topic_scores.items()
        if len(s) >= 1
    }
    sorted_strong = sorted(avg_scores.items(), key=lambda x: -x[1])[:3]
    return [{"skill": t, "avg_score": s}
            for t, s in sorted_strong if s >= 70]


# ══════════════════════════════════════════════════════════════════
# PERFORMANCE BY ROLE
# ══════════════════════════════════════════════════════════════════
def _performance_by_role(completed: list) -> list[dict]:
    role_data = defaultdict(list)
    for iv in completed:
        if iv.score is not None and iv.job_role:
            role_data[iv.job_role].append(float(iv.score))

    result = []
    for role, scores in role_data.items():
        result.append({
            "role": role,
            "avg_score": round(sum(scores) / len(scores), 1),
            "sessions": len(scores),
            "best": round(max(scores), 1),
        })
    return sorted(result, key=lambda x: -x["sessions"])[:6]


# ══════════════════════════════════════════════════════════════════
# STREAK — consecutive days with any activity
# ══════════════════════════════════════════════════════════════════
def _streak(interviews: list, roadmaps: list, coach_sessions: list) -> int:
    """
    Count consecutive days (ending today) where the user did something.
    Activity = interview created OR coach session OR roadmap updated.
    """
    activity_dates = set()

    for iv in interviews:
        if iv.created_at:
            activity_dates.add(iv.created_at.date())

    for cs in coach_sessions:
        if hasattr(cs, "started_at") and cs.started_at:
            activity_dates.add(cs.started_at.date())

    if not activity_dates:
        return 0

    today = datetime.utcnow().date()
    streak = 0
    check = today

    # If no activity today, check if yesterday was the last day
    if check not in activity_dates:
        check = today - timedelta(days=1)
        if check not in activity_dates:
            return 0

    while check in activity_dates:
        streak += 1
        check -= timedelta(days=1)

    return streak


# ══════════════════════════════════════════════════════════════════
# WEEKLY SUMMARY — this week vs last week
# ══════════════════════════════════════════════════════════════════
def _weekly_summary(interviews: list, roadmaps: list) -> dict:
    now = datetime.utcnow()
    week_start = now - timedelta(days=now.weekday())  # Monday
    last_week_start = week_start - timedelta(days=7)

    def in_this_week(dt):
        return dt and week_start.date() <= dt.date() <= now.date()

    def in_last_week(dt):
        return dt and last_week_start.date() <= dt.date() < week_start.date()

    this_ivs = [iv for iv in interviews if in_this_week(iv.created_at)]
    last_ivs = [iv for iv in interviews if in_last_week(iv.created_at)]

    this_scores = [iv.score for iv in this_ivs
                   if iv.score and iv.status == "completed"]
    last_scores = [iv.score for iv in last_ivs
                   if iv.score and iv.status == "completed"]

    this_avg = round(sum(this_scores) / len(this_scores), 1) if this_scores else None
    last_avg = round(sum(last_scores) / len(last_scores), 1) if last_scores else None

    score_delta = None
    if this_avg is not None and last_avg is not None:
        score_delta = round(this_avg - last_avg, 1)

    return {
        "this_week_interviews": len(this_ivs),
        "last_week_interviews": len(last_ivs),
        "this_week_avg_score": this_avg,
        "last_week_avg_score": last_avg,
        "score_delta": score_delta,
        "interviews_delta": len(this_ivs) - len(last_ivs),
    }


# ══════════════════════════════════════════════════════════════════
# COACH STATS
# ══════════════════════════════════════════════════════════════════
def _coach_stats(coach_sessions: list) -> dict:
    if not coach_sessions:
        return {"total_sessions": 0, "total_messages": 0, "topics": []}

    total = len(coach_sessions)
    total_msgs = 0
    topics = defaultdict(int)

    for cs in coach_sessions:
        # Count messages
        try:
            msgs = json.loads(cs.messages_json or "[]")
            total_msgs += len(msgs)
        except Exception:
            pass

        # Extract topic from mode_context
        ctx = cs.mode_context or cs.mode or "General"
        topics[ctx] += 1

    top_topics = sorted(topics.items(), key=lambda x: -x[1])[:5]

    return {
        "total_sessions": total,
        "total_messages": total_msgs,
        "topics": [{"topic": t, "count": c} for t, c in top_topics],
    }


# ══════════════════════════════════════════════════════════════════
# NEXT ACTION — rule-based "what should I do next"
# No AI needed — just smart rules based on real data
# ══════════════════════════════════════════════════════════════════
def _next_action(completed: list, roadmaps: list, coach_sessions: list, user) -> dict:
    """
    Single most impactful action for the user right now.
    Priority order:
    1. If no interviews → do first interview
    2. If avg score < 60 → practice weak skill
    3. If has roadmap with tasks → do next task
    4. If no roadmap → create one
    5. If score improving → keep going
    6. Default → practice
    """
    scores = [iv.score for iv in completed if iv.score]
    avg = sum(scores) / len(scores) if scores else None

    if not completed:
        return {
            "type": "interview",
            "title": "Start Your First Interview",
            "title_ar": "ابدأ أول مقابلة",
            "subtitle": "Practice makes perfect — begin now!",
            "subtitle_ar": "التدريب يصنع الفارق — ابدأ الآن!",
            "icon": "mic",
            "color": "violet",
            "route": "/interview",
        }

    # Check weak skills
    weak = _weak_skills(completed)
    if avg is not None and avg < 65 and weak:
        worst = weak[0]["skill"]
        return {
            "type": "practice",
            "title": f"Improve: {worst}",
            "title_ar": f"تحسين: {worst}",
            "subtitle": f"Your avg score is {round(avg)}% — focus on {worst}",
            "subtitle_ar": f"متوسطك {round(avg)}% — ركز على {worst}",
            "icon": "trending_up",
            "color": "amber",
            "route": "/coach/chat",
            "context": f"Help me improve my {worst} skills for interviews",
        }

    # Check roadmap tasks
    active_roadmap = None
    for rm in roadmaps:
        if rm.overall_progress < 100:
            active_roadmap = rm
            break

    if active_roadmap:
        # Find first incomplete task
        next_task = None
        for stage in active_roadmap.stages:
            if not stage.is_completed and stage.is_unlocked:
                for task in stage.tasks:
                    if not task.is_completed:
                        next_task = task.title
                        break
            if next_task:
                break

        if next_task:
            return {
                "type": "roadmap",
                "title": f"Continue: {active_roadmap.title}",
                "title_ar": f"تابع: {active_roadmap.title}",
                "subtitle": next_task,
                "subtitle_ar": next_task,
                "icon": "map",
                "color": "emerald",
                "route": f"/roadmap/{active_roadmap.id}",
            }

    if not roadmaps:
        return {
            "type": "roadmap",
            "title": "Create Your Learning Path",
            "title_ar": "أنشئ مسار التعلم",
            "subtitle": "Get a personalized AI roadmap",
            "subtitle_ar": "احصل على خارطة طريق مخصصة بالذكاء",
            "icon": "add_road",
            "color": "cyan",
            "route": "/roadmap/create",
        }

    # Score improving? Keep momentum
    if len(scores) >= 3:
        recent_avg = sum(scores[:3]) / 3
        older_avg = sum(scores[3:6]) / len(scores[3:6]) if len(scores) > 3 else recent_avg
        if recent_avg > older_avg + 5:
            return {
                "type": "interview",
                "title": "You're Improving! 🔥",
                "title_ar": "أنت تتحسن! 🔥",
                "subtitle": f"Up {round(recent_avg - older_avg, 1)} points — keep going",
                "subtitle_ar": f"تقدمت {round(recent_avg - older_avg, 1)} نقطة — استمر",
                "icon": "local_fire_department",
                "color": "emerald",
                "route": "/interview",
            }

    return {
        "type": "interview",
        "title": "Keep Practicing",
        "title_ar": "استمر في التدريب",
        "subtitle": "Consistency is the key to success",
        "subtitle_ar": "الاستمرار هو مفتاح النجاح",
        "icon": "mic",
        "color": "violet",
        "route": "/interview",
    }


# ══════════════════════════════════════════════════════════════════
# IMPROVEMENT VELOCITY — how fast is the user improving?
# ══════════════════════════════════════════════════════════════════
def _velocity(completed: list) -> dict:
    """
    Compare last 3 sessions vs previous 3.
    Returns: improving / declining / stable
    """
    scores = [iv.score for iv in completed if iv.score is not None]
    if len(scores) < 4:
        return {"trend": "not_enough_data", "delta": 0}

    recent = sum(scores[:3]) / 3
    previous = sum(scores[3:6]) / len(scores[3:6])
    delta = round(recent - previous, 1)

    trend = "stable"
    if delta >= 5:
        trend = "improving"
    elif delta <= -5:
        trend = "declining"

    return {"trend": trend, "delta": delta, "recent_avg": round(recent, 1)}


# ══════════════════════════════════════════════════════════════════
# EMPTY FALLBACK
# ══════════════════════════════════════════════════════════════════
def _empty_insights() -> dict:
    return {
        "weak_skills": [],
        "strong_skills": [],
        "performance_by_role": [],
        "streak_days": 0,
        "weekly_summary": {
            "this_week_interviews": 0,
            "last_week_interviews": 0,
            "this_week_avg_score": None,
            "last_week_avg_score": None,
            "score_delta": None,
            "interviews_delta": 0,
        },
        "coach_stats": {"total_sessions": 0, "total_messages": 0, "topics": []},
        "next_action": {
            "type": "interview",
            "title": "Start Practicing",
            "title_ar": "ابدأ التدريب",
            "subtitle": "Begin your first AI interview",
            "subtitle_ar": "ابدأ أول مقابلة بالذكاء الاصطناعي",
            "icon": "mic",
            "color": "violet",
            "route": "/interview",
        },
        "improvement_velocity": {"trend": "not_enough_data", "delta": 0},
    }