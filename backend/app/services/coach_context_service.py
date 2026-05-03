# app/services/coach_context_service.py
"""
Gathers user context from across the app for the Coach.
The Coach reads this before every response so it knows:
  - Who the user is (AI memory profile)
  - What they're working toward (active goal)
  - Where they are in their learning (active roadmap progress)
  - How they've been performing (recent interview scores)
  - What they've been practicing (recent coach sessions)

This makes the Coach feel like it truly knows the user.
"""

import json
import logging
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def build_coach_context(user, db: Session, language: str = "en") -> str:
    """
    Build a context string the Coach LLM reads before responding.
    Returns a concise summary — not the raw data.
    """
    parts = []

    # ── 1. AI Memory Profile ────────────────────────────────────
    if user.ai_profile:
        parts.append(f"[User Profile]\n{user.ai_profile}")

    # ── 2. Basic user info ──────────────────────────────────────
    info = []
    if user.full_name:
        info.append(f"Name: {user.full_name}")
    if user.job_title:
        info.append(f"Current role: {user.job_title}")
    if info:
        parts.append("[User Info]\n" + ", ".join(info))

    # ── 3. Active Goal ──────────────────────────────────────────
    try:
        from app.models.goal import Goal
        active_goal = (
            db.query(Goal)
            .filter(Goal.user_id == user.id, Goal.is_active == True)
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
            if active_goal.motivation:
                goal_lines.append(f"Motivation: {active_goal.motivation[:200]}")
            parts.append("[Active Goal]\n" + "\n".join(goal_lines))
    except Exception as e:
        logger.debug(f"Goal context error: {e}")

    # ── 4. Active Roadmap Progress ──────────────────────────────
    try:
        from app.models.roadmap import Roadmap
        roadmap = (
            db.query(Roadmap)
            .filter(Roadmap.user_id == user.id)
            .order_by(Roadmap.created_at.desc())
            .first()
        )
        if roadmap:
            content = {}
            if roadmap.content:
                try:
                    content = json.loads(roadmap.content) if isinstance(roadmap.content, str) else roadmap.content
                except:
                    pass

            milestones = content.get("milestones", [])
            total = len(milestones)
            done = sum(1 for m in milestones if m.get("completed"))
            progress = round(done / total * 100) if total > 0 else 0

            # Find current task (first incomplete)
            current_task = None
            for m in milestones:
                tasks = m.get("tasks", [])
                for t in tasks:
                    if not t.get("completed"):
                        current_task = t.get("title", "")
                        break
                if current_task:
                    break

            roadmap_lines = [
                f"Roadmap: {roadmap.title}",
                f"Progress: {progress}% ({done}/{total} milestones)",
            ]
            if current_task:
                roadmap_lines.append(f"Current task: {current_task}")
            parts.append("[Roadmap Progress]\n" + "\n".join(roadmap_lines))
    except Exception as e:
        logger.debug(f"Roadmap context error: {e}")

    # ── 5. Recent Interview Performance ─────────────────────────
    try:
        from app.models.interview import Interview
        recent = (
            db.query(Interview)
            .filter(
                Interview.user_id == user.id,
                Interview.status == "completed",
                Interview.score.isnot(None),
            )
            .order_by(Interview.completed_at.desc())
            .limit(5)
            .all()
        )
        if recent:
            scores = [iv.score for iv in recent if iv.score and iv.score > 0]
            avg = round(sum(scores) / len(scores)) if scores else 0
            last_role = recent[0].job_role if recent else ""
            perf_lines = [
                f"Recent interviews: {len(recent)} completed",
                f"Average score: {avg}/100",
            ]
            if last_role:
                perf_lines.append(f"Last practiced role: {last_role}")
            parts.append("[Interview Performance]\n" + "\n".join(perf_lines))
    except Exception as e:
        logger.debug(f"Interview context error: {e}")

    # ── 6. Resume Skills ────────────────────────────────────────
    try:
        from app.models.resume import Resume
        resume = (
            db.query(Resume)
            .filter(Resume.user_id == user.id, Resume.is_parsed == 1)
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
        else "You know the following about this user. Use it to personalize your responses."
    )

    return header + "\n\n" + "\n\n".join(parts)


def build_task_context(task_title: str, task_description: str = "", language: str = "en") -> str:
    """
    Build context when Coach is opened from a specific roadmap task.
    """
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