# app/services/coach_context_service.py
"""
S4 — Goals Integration Audit
Improvements:
  1. Reads actual interview feedback content (weak areas, strengths, topics)
  2. Reads ALL completed interviews, not just counts
  3. Fixed Goal.is_active bug (was comparing bool to column)
  4. ai_profile is now built and written after each interview
"""

import json
import logging
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def build_coach_context(user, db: Session, language: str = "en") -> str:
    """
    Build a rich context string the Coach LLM reads before every response.
    Reads: ai_profile, user info, active goal, roadmap, interview feedback, resume skills.
    """
    parts = []

    # ── 1. AI Memory Profile ─────────────────────────────────────────
    # Written by update_user_ai_profile() after each interview
    if user.ai_profile:
        parts.append(f"[User AI Profile]\n{user.ai_profile}")

    # ── 2. Basic user info ───────────────────────────────────────────
    info = []
    if user.full_name:
        info.append(f"Name: {user.full_name}")
    if user.job_title:
        info.append(f"Current role: {user.job_title}")
    if info:
        parts.append("[User Info]\n" + ", ".join(info))

    # ── 3. Active Goal ───────────────────────────────────────────────
    try:
        from app.models.goal import Goal
        active_goal = (
            db.query(Goal)
            .filter(Goal.user_id == user.id, Goal.status == "active")  # FIX: was is_active==True
            .first()
        )
        if active_goal:
            goal_lines = [
                f"Target role: {active_goal.target_role}",
                f"Weekly interview target: {active_goal.weekly_interview_target}",
                f"Completed this week: {active_goal.current_week_count}",
            ]
            if active_goal.target_company:
                goal_lines.append(f"Target company: {active_goal.target_company}")
            if active_goal.deadline:
                goal_lines.append(f"Deadline: {active_goal.deadline.strftime('%Y-%m-%d')}")
            parts.append("[Active Goal]\n" + "\n".join(goal_lines))
    except Exception as e:
        logger.debug(f"Goal context error: {e}")

    # ── 4. Active Roadmap Progress ───────────────────────────────────
    try:
        from app.models.roadmap import Roadmap, RoadmapStage, RoadmapTask
        roadmap = (
            db.query(Roadmap)
            .filter(Roadmap.user_id == user.id, Roadmap.overall_progress < 100)
            .order_by(Roadmap.updated_at.desc())
            .first()
        )
        if roadmap:
            total = len(roadmap.stages) if roadmap.stages else 0
            done = sum(1 for s in roadmap.stages if s.is_completed) if roadmap.stages else 0

            # Find current task
            current_task = None
            for stage in roadmap.stages:
                if not stage.is_completed and stage.is_unlocked:
                    for task in stage.tasks:
                        if not task.is_completed:
                            current_task = task.title
                            break
                if current_task:
                    break

            roadmap_lines = [
                f"Roadmap: {roadmap.title}",
                f"Progress: {roadmap.overall_progress:.0f}% ({done}/{total} stages)",
            ]
            if current_task:
                roadmap_lines.append(f"Current task: {current_task}")
            parts.append("[Roadmap Progress]\n" + "\n".join(roadmap_lines))
    except Exception as e:
        logger.debug(f"Roadmap context error: {e}")

    # ── 5. Interview Performance + Feedback ─────────────────────────
    # S4 improvement: reads actual feedback content, not just scores
    try:
        from app.models.interview import Interview
        recent = (
            db.query(Interview)
            .filter(
                Interview.user_id == user.id,
                Interview.status == "completed",
            )
            .order_by(Interview.completed_at.desc())
            .limit(8)
            .all()
        )
        if recent:
            scores = [iv.score for iv in recent if iv.score is not None]
            avg = round(sum(scores) / len(scores)) if scores else 0

            perf_lines = [
                f"Total completed: {len(recent)} interviews",
                f"Average score: {avg}/100",
            ]
            if recent:
                perf_lines.append(f"Last role practiced: {recent[0].job_role}")

            # Extract weak areas and strengths from feedback JSON
            weak_areas: list[str] = []
            strengths: list[str] = []
            for iv in recent:
                if not iv.feedback:
                    continue
                fb = iv.feedback if isinstance(iv.feedback, dict) else {}
                for area in fb.get("weak_areas", []):
                    if isinstance(area, str) and area not in weak_areas:
                        weak_areas.append(area)
                for strength in fb.get("strengths", []):
                    if isinstance(strength, str) and strength not in strengths:
                        strengths.append(strength)
                # Also check topics dict
                topics = fb.get("topics", {})
                if isinstance(topics, dict):
                    for topic, score in topics.items():
                        if isinstance(score, (int, float)):
                            if score < 55 and topic not in weak_areas:
                                weak_areas.append(topic)
                            elif score >= 75 and topic not in strengths:
                                strengths.append(topic)

            if weak_areas:
                perf_lines.append(f"Weak areas: {', '.join(weak_areas[:5])}")
            if strengths:
                perf_lines.append(f"Strong areas: {', '.join(strengths[:5])}")

            # Score trend
            if len(scores) >= 3:
                recent_avg = sum(scores[:3]) / 3
                older_avg = sum(scores[3:6]) / len(scores[3:6]) if len(scores) > 3 else recent_avg
                delta = recent_avg - older_avg
                if delta >= 5:
                    perf_lines.append(f"Trend: Improving (+{delta:.1f} pts)")
                elif delta <= -5:
                    perf_lines.append(f"Trend: Declining ({delta:.1f} pts) — needs focus")
                else:
                    perf_lines.append("Trend: Stable")

            parts.append("[Interview Performance]\n" + "\n".join(perf_lines))
    except Exception as e:
        logger.debug(f"Interview context error: {e}")

    # ── 6. Resume Skills ─────────────────────────────────────────────
    try:
        from app.models.resume import Resume
        resume = (
            db.query(Resume)
            .filter(Resume.user_id == user.id)
            .order_by(Resume.updated_at.desc())
            .first()
        )
        if resume and resume.skills:
            skills_data = resume.skills if isinstance(resume.skills, list) else []
            if skills_data:
                skill_names = [
                    s.get("name", s) if isinstance(s, dict) else str(s)
                    for s in skills_data[:15]
                ]
                parts.append(f"[Resume Skills]\n{', '.join(skill_names)}")
    except Exception as e:
        logger.debug(f"Resume context error: {e}")

    if not parts:
        return ""

    header = (
        "أنت تعرف المعلومات التالية عن المستخدم. استخدمها لتخصيص ردودك."
        if language == "ar"
        else "You know the following about this user. Use it to personalize your responses and give specific, targeted advice."
    )

    return header + "\n\n" + "\n\n".join(parts)


def build_task_context(task_title: str, task_description: str = "", language: str = "en") -> str:
    """Build context when Coach is opened from a specific roadmap task."""
    if language == "ar":
        return (
            f"[سياق المهمة]\n"
            f"المستخدم يسأل عن مهمة من خارطة الطريق: {task_title}\n"
            f"{task_description[:500] if task_description else ''}\n"
            f"ساعده على فهم هذه المهمة وإكمالها خطوة بخطوة."
        )
    return (
        f"[Task Context]\n"
        f"The user is asking about a roadmap task: {task_title}\n"
        f"{task_description[:500] if task_description else ''}\n"
        f"Help them understand and complete this task step by step."
    )


# ══════════════════════════════════════════════════════════════════
# AI PROFILE WRITER
# Called from _on_interview_complete in interviews.py
# Builds a living text summary of the user and saves to user.ai_profile
# ══════════════════════════════════════════════════════════════════
def update_user_ai_profile(user, db: Session) -> None:
    """
    Rebuild user.ai_profile from all available data.
    Called after each interview completion.
    Safe — never raises.
    """
    try:
        from app.models.interview import Interview
        from app.models.goal import Goal

        interviews = (
            db.query(Interview)
            .filter(Interview.user_id == user.id, Interview.status == "completed")
            .order_by(Interview.completed_at.desc())
            .limit(20)
            .all()
        )

        scores = [iv.score for iv in interviews if iv.score is not None]
        avg = round(sum(scores) / len(scores)) if scores else None

        # Roles practiced
        roles = list({iv.job_role for iv in interviews if iv.job_role})

        # Aggregate feedback
        all_weak: dict[str, int] = {}
        all_strong: dict[str, int] = {}
        for iv in interviews:
            fb = iv.feedback if isinstance(iv.feedback, dict) else {}
            for area in fb.get("weak_areas", []):
                if isinstance(area, str):
                    all_weak[area] = all_weak.get(area, 0) + 1
            for strength in fb.get("strengths", []):
                if isinstance(strength, str):
                    all_strong[strength] = all_strong.get(strength, 0) + 1
            topics = fb.get("topics", {})
            if isinstance(topics, dict):
                for topic, score in topics.items():
                    if isinstance(score, (int, float)):
                        if score < 55:
                            all_weak[topic] = all_weak.get(topic, 0) + 1
                        elif score >= 75:
                            all_strong[topic] = all_strong.get(topic, 0) + 1

        # Top weak/strong (sorted by frequency)
        top_weak = sorted(all_weak, key=lambda x: -all_weak[x])[:5]
        top_strong = sorted(all_strong, key=lambda x: -all_strong[x])[:5]

        # Score trend
        trend = "not enough data"
        if len(scores) >= 4:
            recent_avg = sum(scores[:3]) / 3
            older_avg = sum(scores[3:6]) / len(scores[3:6])
            delta = recent_avg - older_avg
            trend = "improving" if delta >= 5 else "declining" if delta <= -5 else "stable"

        # Active goal
        active_goal = (
            db.query(Goal)
            .filter(Goal.user_id == user.id, Goal.status == "active")
            .first()
        )

        # Build profile text
        lines = [f"Total interviews completed: {len(interviews)}"]
        if avg is not None:
            lines.append(f"Average score: {avg}/100")
        if roles:
            lines.append(f"Roles practiced: {', '.join(roles[:5])}")
        if top_weak:
            lines.append(f"Weak areas (needs focus): {', '.join(top_weak)}")
        if top_strong:
            lines.append(f"Strong areas: {', '.join(top_strong)}")
        if trend != "not enough data":
            lines.append(f"Performance trend: {trend}")
        if active_goal:
            lines.append(f"Current goal: {active_goal.target_role}")

        user.ai_profile = "\n".join(lines)
        db.commit()
        logger.info(f"Updated ai_profile for user {user.id}")

    except Exception as e:
        logger.error(f"update_user_ai_profile failed for user {user.id}: {e}")