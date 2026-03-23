<div align="center">

# خطوة · Katwah
### AI-Powered Interview Preparation Platform
**Bilingual (Arabic / English) · Flutter Web + FastAPI · Production-Ready**

[![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Python-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Groq](https://img.shields.io/badge/AI-Groq_Llama_3.3_70B-orange)](https://groq.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

---

## What is Katwah?

**Katwah (خطوة — Arabic for "a step")** is a full-stack AI interview preparation platform that helps job seekers practice real interviews, analyze their resumes, and build skill roadmaps — all powered by state-of-the-art AI. It is fully bilingual (Arabic RTL + English LTR) and works on web and mobile.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter Web (Dart), Riverpod state management, GoRouter |
| **Backend** | FastAPI (Python), SQLAlchemy, Alembic, Supabase PostgreSQL |
| **AI — Interviews** | Groq Llama 3.3 70B Versatile |
| **AI — Speech-to-Text** | Groq Whisper Large v3 |
| **AI — Text-to-Speech** | OpenAI TTS |
| **AI — Avatar Video** | D-ID Talks API (v3) |
| **Auth** | JWT + Supabase Auth |
| **Storage** | Supabase Storage (resume files) |
| **Deployment (planned)** | Railway (backend) + Firebase Hosting (frontend) |

---

## Features Built

### 🎤 AI Interview Simulation
- **Text mode** — Type answers, get AI responses in real time
- **Voice mode** — Hold-to-record mic, WhatsApp-style voice bubbles with animated waveform, Whisper transcription, OpenAI TTS playback
- **Live Avatar / Video mode** — D-ID talking avatar with async video rendering (text response shown immediately while video renders in background), poll-for-video mechanism
- 7-question sessions with per-answer evaluation
- Animated score ring (counts 0→score over 1.4s), score breakdown bars
- ⭐ Star rating widget (1–5 stars, animated scale, optional text feedback, elastic checkmark on submit)
- Final feedback: Summary, Strengths, Areas to Improve, Communication/Technical/Confidence scores

### 📄 Resume Module
- PDF/DOCX upload with AI parsing (contact info, experience, education, skills, projects)
- 7-tab detail page: INFO · ANALYSIS · ATS · MATCH · DESIGN · AI POWER · PREDICT
- Animated score cards (circular progress + linear bar)
- ATS compatibility checker with grade (A–F), critical issues, warnings, passed checks
- Job description matching with keyword diff
- AI question predictor (technical, behavioral, situational, gap, strength questions)
- Radar chart (skill analytics)
- **DESIGN tab** — 3-step wizard (choose template → edit data → download):
  - Manual mode: pre-filled from parsed resume, edit all fields, download DOCX
  - AI mode: enter target role + tone (Professional/Aggressive/Technical), AI rewrites entire resume
- **Resume Builder page** — standalone builder with DOCX + PDF export

### 🗺️ Skill Roadmaps
- AI-generated personalized learning roadmaps
- Stage cards with task checklists, progress bars, unlock system
- Per-task resources (video/course/docs/article links)
- Study time logger with timer sheet
- Journey analytics modal (per-stage progress, logged hours)

### 👤 Profile & Settings
- Beautiful profile hero (gradient avatar pill, stats row, job title badge)
- Pill-style segmented tab bar (General · Settings · Security)
- General tab: full profile edit (name, job title, location, bio, LinkedIn, GitHub)
- Settings tab:
  - **Animated sun↔moon theme toggle** (slides with icon inside thumb)
  - **Language toggle** (Arabic/English, full RTL/LTR switch)
  - Notification settings (coming soon tiles)
- Security tab: change password (full validation, confirm field), delete account with confirmation

### 🌐 Arabic / English Localization
- Complete bilingual system via `AppStrings` class — 389+ string getters
- Full RTL layout support (`Directionality` wrapper in `main.dart`)
- Language toggle updates entire app instantly via `localeProvider`
- CJK garbage character filter (backend `_sanitize()` + Flutter `TextUtils.sanitize()`)
- Every page localized: auth, home, interview (list/setup/chat/history/video), resume (list/detail/design/builder), roadmap (list/create/journey), profile, onboarding

### 🏠 Home Dashboard
- Glassmorphism header with **gradient avatar pill**, animated **time-of-day dot** (changes color: indigo/amber/emerald/rose/violet by hour), boxed theme button
- Hero card (avg score circular indicator, interview/resume/roadmap counts)
- Progress strip (streak days, weekly sessions with progress bar, avg score)
- Quick-start banner (gradient, navigates to last role)
- Performance sparkline chart with cubic bezier curves
- Quick action grid (4 cards with gradient icons)
- Active roadmap card + recent activity feed
- Pull-to-refresh, staggered animation on scroll

### ✨ UX Polish (applied globally)
- **Shimmer skeleton** loaders on all list pages (resume list, interview history)
- **Route transitions**: fadeSlideUp (home), fadeSlideRight (drill-down), scale (modals), fade (tabs)
- **TapScale** micro-interaction on all tappable cards
- **ShakeWidget** validation feedback on setup page start button
- `_StaggeredItem` stagger-in animations on list items
- `if (!mounted) return` async guards everywhere

### 🔧 Technical Fixes Applied
- **CJK leak bug** — Llama 3.3 70B multilingual training causes Chinese/Korean characters in Arabic responses → fixed with 3-layer defense: strong system prompt, enforcement injection before every Groq call, regex sanitizer post-response
- **API contract mismatches** — `ai_message` vs `response`, `transcription` vs `text` field names — all aligned
- **Base URL `/api/v1` prefix** — fixed across all service files
- **D-ID URL validation** — Unsplash URLs with query params rejected → backend controls `source_url=None`
- **Groq retry logic** — 3-attempt exponential backoff for connection drops
- **`app_strings.dart` class scope bug** — `>> append` added strings outside class brace; rebuilt as single self-contained class (389 lines)
- **`withOpacity` deprecated** → replaced with `withValues(alpha:)` throughout

---

## Project Structure

```
interview-prep-ai-1/
├── frontend/                          # Flutter Web app
│   └── lib/
│       ├── core/
│       │   ├── locale/
│       │   │   ├── app_strings.dart   # 389+ bilingual string getters
│       │   │   └── locale_provider.dart
│       │   ├── router/app_router.dart
│       │   ├── theme/
│       │   │   ├── app_colors.dart
│       │   │   └── theme_provider.dart
│       │   └── utils/text_utils.dart  # CJK sanitizer
│       ├── features/
│       │   ├── auth/
│       │   ├── dashboard/
│       │   ├── home/screens/home_screen.dart
│       │   ├── interview/
│       │   │   ├── pages/
│       │   │   │   ├── interview_list_page.dart
│       │   │   │   ├── interview_setup_page.dart
│       │   │   │   ├── interview_chat_page.dart    # text+voice+feedback+star rating
│       │   │   │   ├── interview_history_page.dart
│       │   │   │   └── interview_video_page.dart   # avatar mode
│       │   │   ├── providers/interview_provider.dart
│       │   │   └── services/interview_service.dart
│       │   ├── onboarding/
│       │   │   ├── onboarding_screen.dart
│       │   │   ├── profile_setup_screen.dart
│       │   │   └── splash_screen.dart
│       │   ├── profile/
│       │   │   ├── pages/profile_page.dart
│       │   │   ├── providers/profile_provider.dart
│       │   │   └── services/profile_service.dart
│       │   ├── resume/
│       │   │   └── presentation/pages/
│       │   │       ├── resume_list_page.dart
│       │   │       ├── resume_detail_page.dart
│       │   │       ├── resume_design_tab.dart
│       │   │       └── resume_builder_page.dart
│       │   └── roadmap/
│       │       ├── pages/
│       │       │   ├── roadmap_list_page.dart
│       │       │   ├── roadmap_create_page.dart
│       │       │   └── roadmap_journey_page.dart
│       │       ├── providers/roadmap_provider.dart
│       │       └── services/roadmap_service.dart
│       └── shared/widgets/
│           ├── app_bottom_nav.dart
│           ├── background_painter.dart
│           ├── lang_toggle_button.dart
│           ├── skeleton_widgets.dart
│           ├── theme_toggle_button.dart
│           └── transitions.dart        # TapScale, ShakeWidget, AppTransitions
│
└── backend/                           # FastAPI app
    └── app/
        ├── routers/
        │   ├── auth.py
        │   ├── interviews.py
        │   ├── resumes.py
        │   ├── roadmaps.py
        │   └── users.py
        ├── services/
        │   ├── interview_ai_service.py # Groq + CJK sanitizer + enforcement
        │   └── avatar_service.py       # D-ID Talks v3
        └── config.py
```

---

## Environment Variables

**Backend `.env`:**
```env
GROQ_API_KEY=your_groq_key
OPENAI_API_KEY=your_openai_key
D_ID_API_KEY=your_did_key
DATABASE_URL=postgresql://...
SECRET_KEY=your_jwt_secret
SUPABASE_URL=https://...
SUPABASE_KEY=your_supabase_key
```

**Frontend — update `ApiService` base URL:**
```dart
// lib/services/api_service.dart
static const String baseUrl = 'http://localhost:8000'; // dev
// → 'https://your-railway-app.railway.app'           // prod
```

---

## Running Locally

```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# Frontend
cd frontend
flutter pub get
flutter run -d chrome --web-port 3000
```

---

## Deployment Plan (Next)

### Backend → Railway
1. Add `Dockerfile` + `railway.json` to backend root
2. Set env vars in Railway dashboard
3. Point `DATABASE_URL` to Supabase production DB
4. Set CORS origin to Firebase hosting URL

### Frontend → Firebase Hosting
1. `flutter build web --release`
2. Update `ApiService.baseUrl` to Railway URL
3. `firebase init hosting` → `firebase deploy`

---

## What's Next

See `PROJECT_STATUS.md` for the full current state and next steps.

---

## License

MIT © 2026 Meshari — خطوة / Katwah
