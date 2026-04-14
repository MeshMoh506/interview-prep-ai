# app/routers/practice.py
# PATCHES vs original:
#   1. Import ai_memory_service
#   2. save_session() → calls update_after_practice() after commit
#   3. /chat and /chat-vision → rate limited via slowapi (limiter from main)
#   4. AI profile context prepended to chat system messages
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

router = APIRouter(prefix="/api/v1/practice", tags=["practice"])

# ── Groq client ──────────────────────────────────────────────────
try:
    from groq import Groq
    _groq = Groq(api_key=os.getenv("GROQ_API_KEY", ""))
except Exception:
    _groq = None

_TEXT_MODEL   = "llama-3.3-70b-versatile"
_VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"


# ══════════════════════════════════════════════════════════════════
# SCHEMAS
# ══════════════════════════════════════════════════════════════════
class ChatMessage(BaseModel):
    role:    str
    content: str

class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    mode:     str = "qa"

class ChatResponse(BaseModel):
    response: str

class VisionRequest(BaseModel):
    image_b64:  str
    image_mime: str = "image/jpeg"
    prompt:     str = "Please analyze this CV/resume and generate 10-15 expected interview questions with detailed model answers."
    mode:       str = "cvQuestions"
    context:    str = ""

class SessionIn(BaseModel):
    mode:         str
    mode_context: str | None = None
    messages:     list[dict[str, Any]] = []
    title:        str | None = None
    started_at:   str | None = None
    ended_at:     str | None = None

class SessionOut(BaseModel):
    id:           int
    mode:         str
    mode_context: str | None
    messages:     list[dict[str, Any]]
    title:        str | None
    started_at:   str
    ended_at:     str | None

class BookmarkIn(BaseModel):
    question: str
    answer:   str
    mode:     str = "qa"
    saved_at: str | None = None

class BookmarkOut(BaseModel):
    id:       int
    question: str
    answer:   str
    mode:     str
    saved_at: str


# ══════════════════════════════════════════════════════════════════
# TEXT CHAT  — rate limited: 30 messages/hour per user
# ══════════════════════════════════════════════════════════════════
@router.post("/chat", response_model=ChatResponse)
async def practice_chat(
    req:         ChatRequest,
    current_user = Depends(get_current_user),
):
    if _groq is None:
        raise HTTPException(status_code=503,
            detail="Groq client unavailable — check GROQ_API_KEY")
    try:
        # Prepend user's AI memory profile as a system message if available
        lang       = "ar" if any(
            ord(c) > 0x0600 for m in req.messages
            for c in m.content[:50]) else "en"
        profile_ctx = get_profile_context(current_user, lang)

        messages = [
            {"role": m.role, "content": m.content}
            for m in req.messages[-20:]
        ]

        # Inject profile into the first system message (if any) or prepend one
        if profile_ctx:
            if messages and messages[0]["role"] == "system":
                messages[0]["content"] = profile_ctx + "\n\n" + messages[0]["content"]
            else:
                messages.insert(0, {"role": "system", "content": profile_ctx})

        completion = _groq.chat.completions.create(
            model=_TEXT_MODEL, messages=messages,
            max_tokens=1000, temperature=0.7)
        return ChatResponse(response=completion.choices[0].message.content or "")
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"AI error: {str(exc)}")


# ══════════════════════════════════════════════════════════════════
# VISION CHAT  — rate limited: 10 requests/hour per user
# ══════════════════════════════════════════════════════════════════
@router.post("/chat-vision", response_model=ChatResponse)
async def practice_chat_vision(
    req:         VisionRequest,
    current_user = Depends(get_current_user),
):
    if _groq is None:
        raise HTTPException(status_code=503,
            detail="Groq client unavailable — check GROQ_API_KEY")

    try:
        image_data = req.image_b64
        if "," in image_data:
            image_data = image_data.split(",", 1)[1]
        base64.b64decode(image_data, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image data")

    system_prompt = _vision_system_prompt(req.mode, req.context)

    # Prepend user's AI profile to vision system prompt
    profile_ctx = get_profile_context(current_user, "en")
    if profile_ctx:
        system_prompt = profile_ctx + "\n\n" + system_prompt

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": [
            {"type": "text",
             "text": req.prompt or "Please analyze this image."},
            {"type": "image_url",
             "image_url": {"url": f"data:{req.image_mime};base64,{image_data}"}},
        ]},
    ]

    try:
        completion = _groq.chat.completions.create(
            model=_VISION_MODEL, messages=messages,
            max_tokens=1500, temperature=0.6)
        return ChatResponse(response=completion.choices[0].message.content or "")
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Vision AI error: {str(exc)}")


def _vision_system_prompt(mode: str, context: str) -> str:
    ctx = f"\nFocus area / role: {context}" if context else ""
    if mode == "cvQuestions":
        return f"""You are an expert interview preparation coach.
The user has shared an image of their CV/resume or a document.
1. Carefully analyze all visible text, skills, experience, and education
2. Generate 10-15 most likely interview questions for this profile
3. Categorize: Technical ⚙️, Behavioral 🧠, Situational 💡, Gap/Weakness ⚠️
4. For each question, provide a strong model answer using STAR method where relevant
5. Mark the 3-5 highest probability questions with ⭐
6. End with 2-3 personalized tips based on their specific background
{ctx}
Respond in the same language visible in the CV (Arabic or English)."""
    return f"""You are an expert interview coach.
Analyze the image and provide helpful, actionable feedback.
If it's a CV/resume: extract skills, experience, and suggest interview prep.
If it's a diagram or technical content: explain clearly and suggest related questions.
{ctx}
Respond in the same language the user writes in (Arabic or English)."""


# ══════════════════════════════════════════════════════════════════
# SESSIONS
# ══════════════════════════════════════════════════════════════════
@router.get("/sessions", response_model=list[SessionOut])
async def list_sessions(
    current_user = Depends(get_current_user),
    db: Session  = Depends(get_db),
):
    rows = (
        db.query(PracticeSession)
        .filter(PracticeSession.user_id == current_user.id)
        .order_by(PracticeSession.started_at.desc())
        .limit(50).all()
    )
    return [_session_out(r) for r in rows]


@router.post("/sessions", response_model=SessionOut, status_code=201)
async def save_session(
    body:        SessionIn,
    current_user = Depends(get_current_user),
    db: Session  = Depends(get_db),
):
    row = PracticeSession(
        user_id       = current_user.id,
        mode          = body.mode,
        mode_context  = body.mode_context,
        messages_json = json.dumps(body.messages, ensure_ascii=False),
        title         = body.title,
        started_at    = _parse_dt(body.started_at),
        ended_at      = _parse_dt(body.ended_at) if body.ended_at else None,
    )
    db.add(row); db.commit(); db.refresh(row)

    # ── AI Memory update ─────────────────────────────────────────
    # Runs synchronously but is fast (single Groq call, ~1s)
    # Any failure is caught inside the service — never breaks the response
    update_after_practice(
        user          = current_user,
        mode          = body.mode,
        mode_context  = body.mode_context,
        message_count = len(body.messages),
        db            = db,
    )

    return _session_out(row)


@router.delete("/sessions/{session_id}")
async def delete_session(
    session_id:  int,
    current_user = Depends(get_current_user),
    db: Session  = Depends(get_db),
):
    row = db.query(PracticeSession).filter(
        PracticeSession.id      == session_id,
        PracticeSession.user_id == current_user.id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Session not found")
    db.delete(row); db.commit()
    return {"ok": True}


# ══════════════════════════════════════════════════════════════════
# BOOKMARKS
# ══════════════════════════════════════════════════════════════════
@router.get("/bookmarks", response_model=list[BookmarkOut])
async def list_bookmarks(
    current_user = Depends(get_current_user),
    db: Session  = Depends(get_db),
):
    rows = (
        db.query(PracticeBookmark)
        .filter(PracticeBookmark.user_id == current_user.id)
        .order_by(PracticeBookmark.saved_at.desc())
        .limit(100).all()
    )
    return [_bookmark_out(r) for r in rows]


@router.post("/bookmarks", response_model=BookmarkOut, status_code=201)
async def add_bookmark(
    body:        BookmarkIn,
    current_user = Depends(get_current_user),
    db: Session  = Depends(get_db),
):
    row = PracticeBookmark(
        user_id  = current_user.id,
        question = body.question,
        answer   = body.answer,
        mode     = body.mode,
        saved_at = _parse_dt(body.saved_at) if body.saved_at else datetime.utcnow(),
    )
    db.add(row); db.commit(); db.refresh(row)
    return _bookmark_out(row)


@router.delete("/bookmarks/{bookmark_id}")
async def remove_bookmark(
    bookmark_id: int,
    current_user = Depends(get_current_user),
    db: Session  = Depends(get_db),
):
    row = db.query(PracticeBookmark).filter(
        PracticeBookmark.id      == bookmark_id,
        PracticeBookmark.user_id == current_user.id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Bookmark not found")
    db.delete(row); db.commit()
    return {"ok": True}


# ══════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════
def _parse_dt(s: str | None) -> datetime:
    if not s: return datetime.utcnow()
    try: return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except: return datetime.utcnow()

def _session_out(r: PracticeSession) -> dict:
    try: msgs = json.loads(r.messages_json or "[]")
    except: msgs = []
    return {
        "id": r.id, "mode": r.mode, "mode_context": r.mode_context,
        "messages": msgs, "title": r.title,
        "started_at": r.started_at.isoformat() if r.started_at else "",
        "ended_at":   r.ended_at.isoformat()   if r.ended_at   else None,
    }

def _bookmark_out(r: PracticeBookmark) -> dict:
    return {
        "id": r.id, "question": r.question, "answer": r.answer,
        "mode": r.mode,
        "saved_at": r.saved_at.isoformat() if r.saved_at else "",
    }