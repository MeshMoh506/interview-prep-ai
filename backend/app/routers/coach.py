# app/routers/coach.py
"""
Coach — AI-powered personal mentor.
  - Handles work, study, life, career — And more ! 
  - Context-aware: reads user's goals, roadmap, interview history
  - Single unified chat 
  - Supports text, images (Llama 4 Scout vision), and file analysis
  - Session history + bookmarks preserved (same DB tables)

Endpoints (backward-compatible with old /practice paths):
  POST /api/v1/coach/chat          → text chat
  POST /api/v1/coach/chat-vision   → image analysis
  GET  /api/v1/coach/sessions      → list saved sessions
  POST /api/v1/coach/sessions      → save a session
  DELETE /api/v1/coach/sessions/{id}
  GET  /api/v1/coach/bookmarks
  POST /api/v1/coach/bookmarks
  DELETE /api/v1/coach/bookmarks/{id}
"""

import base64
import json
import os
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.practice import PracticeSession, PracticeBookmark
from app.models.user import User
from app.routers.auth import get_current_user
from app.services.ai_memory_service import (
    update_after_practice,
    get_profile_context,
)
from app.services.coach_context_service import (
    build_coach_context,
    build_task_context,
)

router = APIRouter(prefix="/api/v1/coach", tags=["coach"])

# ── Groq client ──────────────────────────────────────────────────
try:
    from groq import Groq
    _groq = Groq(api_key=os.getenv("GROQ_API_KEY", ""))
except Exception:
    _groq = None

_TEXT_MODEL   = "llama-3.3-70b-versatile"
_VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

# ── Coach system prompt ──────────────────────────────────────────
_COACH_SYSTEM_EN = """You are Coach — a personal AI mentor inside the Katwah (خطوة) app.

Your role:
- Help with career development, interview prep, studying, projects, and professional growth
- Give specific, actionable advice — not generic platitudes
- When the user shares code, review it thoroughly
- When they share a CV/resume image, analyze it and suggest improvements
- When they ask about a roadmap task, guide them step by step
- Adapt your depth: quick answers for simple questions, deep dives when needed
- Be encouraging but honest — sugar-coating doesn't help growth

Style:
- Conversational and warm, like a senior colleague who genuinely cares
- Use examples and analogies
- If you don't know something, say so honestly
- Respond in the same language the user writes in (Arabic or English)
- Keep responses focused — no unnecessary padding"""

_COACH_SYSTEM_AR = """أنت المدرب — مرشد شخصي ذكي داخل تطبيق خطوة.

دورك:
- المساعدة في التطوير المهني، التحضير للمقابلات، الدراسة، المشاريع، والنمو المهني
- تقديم نصائح محددة وعملية — وليس كلاماً عاماً
- عندما يشارك المستخدم كود، راجعه بعناية
- عندما يشارك صورة سيرة ذاتية، حللها واقترح تحسينات
- عندما يسأل عن مهمة من خارطة الطريق، أرشده خطوة بخطوة
- تكيّف مع العمق: إجابات سريعة للأسئلة البسيطة، وشرح مفصل عند الحاجة
- كن مشجعاً لكن صادقاً — المجاملة لا تساعد على النمو

الأسلوب:
- محادثة ودية، كزميل أقدم يهتم فعلاً
- استخدم أمثلة وتشبيهات
- إذا لم تعرف شيئاً، قل ذلك بصراحة
- رد بنفس اللغة التي يكتب بها المستخدم
- اجعل الردود مركزة — بدون حشو"""


# ══════════════════════════════════════════════════════════════════
# SCHEMAS
# ══════════════════════════════════════════════════════════════════
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    task_context: str | None = None  # From roadmap task button

class ChatResponse(BaseModel):
    response: str

class VisionRequest(BaseModel):
    image_b64: str
    image_mime: str = "image/jpeg"
    prompt: str = "Please analyze this image and provide helpful insights."
    context: str = ""

class SessionIn(BaseModel):
    mode: str = "coach"  # kept for backward compat
    mode_context: str | None = None
    messages: list[dict[str, Any]] = []
    title: str | None = None
    started_at: str | None = None
    ended_at: str | None = None

class SessionOut(BaseModel):
    id: int
    mode: str
    mode_context: str | None
    messages: list[dict[str, Any]]
    title: str | None
    started_at: str
    ended_at: str | None

class BookmarkIn(BaseModel):
    question: str
    answer: str
    mode: str = "coach"
    saved_at: str | None = None

class BookmarkOut(BaseModel):
    id: int
    question: str
    answer: str
    mode: str
    saved_at: str


# ══════════════════════════════════════════════════════════════════
# TEXT CHAT
# ══════════════════════════════════════════════════════════════════
@router.post("/chat", response_model=ChatResponse)
async def coach_chat(
    req: ChatRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if _groq is None:
        raise HTTPException(status_code=503, detail="AI unavailable")

    try:
        # Detect language from recent messages
        lang = "ar" if any(
            ord(c) > 0x0600
            for m in req.messages[-3:]
            for c in m.content[:80]
        ) else "en"

        # Build rich context from user's app data
        user_context = build_coach_context(user=current_user, db=db, language=lang)

        # Task context (if opened from roadmap task)
        task_ctx = ""
        if req.task_context:
            task_ctx = build_task_context(req.task_context, language=lang)

        # Select system prompt
        system_prompt = _COACH_SYSTEM_AR if lang == "ar" else _COACH_SYSTEM_EN

        # Combine: system prompt + user context + task context
        full_system = system_prompt
        if user_context:
            full_system += "\n\n" + user_context
        if task_ctx:
            full_system += "\n\n" + task_ctx

        # Build messages for Groq
        messages = [{"role": "system", "content": full_system}]
        for m in req.messages[-20:]:
            messages.append({"role": m.role, "content": m.content})

        completion = _groq.chat.completions.create(
            model=_TEXT_MODEL,
            messages=messages,
            max_tokens=1200,
            temperature=0.7,
        )
        return ChatResponse(
            response=completion.choices[0].message.content or ""
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"AI error: {str(exc)}")


# ══════════════════════════════════════════════════════════════════
# VISION CHAT
# ══════════════════════════════════════════════════════════════════
@router.post("/chat-vision", response_model=ChatResponse)
async def coach_chat_vision(
    req: VisionRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if _groq is None:
        raise HTTPException(status_code=503, detail="AI unavailable")

    try:
        image_data = req.image_b64
        if "," in image_data:
            image_data = image_data.split(",", 1)[1]
        base64.b64decode(image_data, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image data")

    # Build context-aware vision prompt
    user_context = build_coach_context(user=current_user, db=db, language="en")

    system_prompt = """You are Coach — a personal AI mentor.
The user shared an image. Analyze it carefully and provide helpful, actionable feedback.
- If it's a CV/resume: extract key info, suggest improvements, predict interview questions
- If it's code or a diagram: explain, review, suggest improvements
- If it's a screenshot of an error: diagnose and suggest fixes
- If it's anything else: provide relevant career/learning insights
Respond in the same language visible in the image or that the user writes in."""

    if user_context:
        system_prompt += "\n\n" + user_context

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": [
            {"type": "text", "text": req.prompt or "Please analyze this image."},
            {"type": "image_url",
             "image_url": {"url": f"data:{req.image_mime};base64,{image_data}"}},
        ]},
    ]

    try:
        completion = _groq.chat.completions.create(
            model=_VISION_MODEL,
            messages=messages,
            max_tokens=1500,
            temperature=0.6,
        )
        return ChatResponse(
            response=completion.choices[0].message.content or ""
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Vision AI error: {str(exc)}")


# ══════════════════════════════════════════════════════════════════
# SESSIONS — same DB tables, same endpoints
# ══════════════════════════════════════════════════════════════════
@router.get("/sessions", response_model=list[SessionOut])
async def list_sessions(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(PracticeSession)
        .filter(PracticeSession.user_id == current_user.id)
        .order_by(PracticeSession.started_at.desc())
        .limit(50)
        .all()
    )
    return [_session_out(r) for r in rows]


@router.post("/sessions", response_model=SessionOut, status_code=201)
async def save_session(
    body: SessionIn,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = PracticeSession(
        user_id=current_user.id,
        mode=body.mode,
        mode_context=body.mode_context,
        messages_json=json.dumps(body.messages, ensure_ascii=False),
        title=body.title,
        started_at=_parse_dt(body.started_at),
        ended_at=_parse_dt(body.ended_at) if body.ended_at else None,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    # Update AI memory after coach session
    update_after_practice(
        user=current_user,
        mode=body.mode,
        mode_context=body.mode_context,
        message_count=len(body.messages),
        db=db,
    )

    return _session_out(row)


@router.delete("/sessions/{session_id}")
async def delete_session(
    session_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = (
        db.query(PracticeSession)
        .filter(
            PracticeSession.id == session_id,
            PracticeSession.user_id == current_user.id,
        )
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Session not found")
    db.delete(row)
    db.commit()
    return {"ok": True}


# ══════════════════════════════════════════════════════════════════
# BOOKMARKS
# ══════════════════════════════════════════════════════════════════
@router.get("/bookmarks", response_model=list[BookmarkOut])
async def list_bookmarks(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(PracticeBookmark)
        .filter(PracticeBookmark.user_id == current_user.id)
        .order_by(PracticeBookmark.saved_at.desc())
        .limit(100)
        .all()
    )
    return [_bookmark_out(r) for r in rows]


@router.post("/bookmarks", response_model=BookmarkOut, status_code=201)
async def add_bookmark(
    body: BookmarkIn,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = PracticeBookmark(
        user_id=current_user.id,
        question=body.question,
        answer=body.answer,
        mode=body.mode,
        saved_at=_parse_dt(body.saved_at) if body.saved_at else datetime.utcnow(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _bookmark_out(row)


@router.delete("/bookmarks/{bookmark_id}")
async def remove_bookmark(
    bookmark_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = (
        db.query(PracticeBookmark)
        .filter(
            PracticeBookmark.id == bookmark_id,
            PracticeBookmark.user_id == current_user.id,
        )
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Bookmark not found")
    db.delete(row)
    db.commit()
    return {"ok": True}


# ══════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════
def _parse_dt(s: str | None) -> datetime:
    if not s:
        return datetime.utcnow()
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return datetime.utcnow()


def _session_out(r: PracticeSession) -> dict:
    try:
        msgs = json.loads(r.messages_json or "[]")
    except Exception:
        msgs = []
    return {
        "id": r.id,
        "mode": r.mode,
        "mode_context": r.mode_context,
        "messages": msgs,
        "title": r.title,
        "started_at": r.started_at.isoformat() if r.started_at else "",
        "ended_at": r.ended_at.isoformat() if r.ended_at else None,
    }


def _bookmark_out(r: PracticeBookmark) -> dict:
    return {
        "id": r.id,
        "question": r.question,
        "answer": r.answer,
        "mode": r.mode,
        "saved_at": r.saved_at.isoformat() if r.saved_at else "",
    }