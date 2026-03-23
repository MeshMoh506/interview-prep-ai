<div align="center">

<img src="assets/logo.png" alt="Katwah Logo" width="120" height="120" />

# خطوة · Katwah
### AI-Powered Interview Preparation App
**Bilingual (Arabic / English) · Flutter Mobile + FastAPI**

[![Flutter](https://img.shields.io/badge/Flutter-Mobile-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Python-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Groq](https://img.shields.io/badge/Groq-Llama_3.3_70B-F54E42?logo=groq&logoColor=white)](https://groq.com)
[![Platform](https://img.shields.io/badge/Platform-iOS_%7C_Android-lightgrey?logo=apple)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-22C55E)](LICENSE)

> **خطوة** (Katwah) — Arabic for *"a step"*.  
> Every interview, every resume, every roadmap — one step closer to your dream job.

---

<!-- Replace the path below with your actual screenshot once uploaded to the repo -->
<!-- Recommended: Add 3–5 portrait screenshots in a row using HTML table -->

<table>
  <tr>
    <td><img src="screenshots/home.png" width="200" alt="Home Screen"/></td>
    <td><img src="screenshots/interview.png" width="200" alt="Interview Screen"/></td>
    <td><img src="screenshots/resume.png" width="200" alt="Resume Screen"/></td>
    <td><img src="screenshots/roadmap.png" width="200" alt="Roadmap Screen"/></td>
    <td><img src="screenshots/profile.png" width="200" alt="Profile Screen"/></td>
  </tr>
  <tr>
    <td align="center">Home</td>
    <td align="center">Interview</td>
    <td align="center">Resume</td>
    <td align="center">Roadmap</td>
    <td align="center">Profile</td>
  </tr>
</table>

---

<!-- Optional: Add a short demo video. GitHub supports .mp4 in READMEs (max 10MB) -->
<!-- Uncomment and replace path when ready: -->
<!--
### 🎬 Demo
https://user-images.githubusercontent.com/YOUR_ID/katwah-demo.mp4
-->

</div>

---

## 📱 About

**Katwah** is a native mobile app (iOS + Android) built with Flutter that helps Arabic and English-speaking job seekers:

- 🎤 Practice AI-powered mock interviews (text, voice, or talking avatar)
- 📄 Upload and analyze their resumes with AI
- 🗺️ Get personalized AI-generated skill roadmaps
- 👤 Track their progress and improvement over time

Everything works in **Arabic (RTL) and English (LTR)** with a single tap.

---

## ⚙️ Tech Stack

| Layer | Technology |
|---|---|
| **Mobile App** | Flutter (Dart), Riverpod, GoRouter |
| **Backend API** | FastAPI (Python 3.11+), SQLAlchemy, Alembic |
| **Database** | PostgreSQL (dev) / Supabase (production) |
| **AI — Interviews** | Groq Llama 3.3 70B Versatile |
| **AI — Speech-to-Text** | Groq Whisper Large v3 |
| **AI — Text-to-Speech** | OpenAI TTS (tts-1) |
| **AI — Talking Avatar** | D-ID Talks API v3 |
| **Auth** | JWT + bcrypt |
| **Deployment** | Railway (backend) + App Store / Google Play (app) |

---

## ✨ Features

### 🎤 AI Interview Simulation

<!-- Add screenshot here -->
<!-- <img src="screenshots/interview_voice.png" width="250" align="right" /> -->

- **Text mode** — Type your answers, get AI interviewer questions in real time
- **Voice mode** — Hold mic to record, see your answer transcribed live (Whisper STT), hear AI read back the question (OpenAI TTS)
- **Live Avatar mode** — A D-ID talking presenter reads the question out loud on video. AI text appears instantly while video renders in the background
- 7-question sessions with per-answer scoring
- Final report: overall score (0–100), strengths, areas to improve, communication/technical/confidence breakdown
- ⭐ Session rating widget (1–5 stars + optional written feedback)
- Practice history with expandable AI feedback per session

---

### 📄 Resume Module

<!-- Add screenshot here -->
<!-- <img src="screenshots/resume_analysis.png" width="250" align="right" /> -->

- Upload PDF or DOCX resume from your phone
- AI parses: contact info, experience, education, skills, projects, certifications
- **7-tab analysis:**
  - **INFO** — File details + parse/analyze actions
  - **ANALYSIS** — Overall score, strengths, weaknesses, improvement suggestions
  - **ATS** — ATS compatibility grade (A–F), critical issues, passed checks
  - **MATCH** — Paste a job description → keyword match score + missing keywords
  - **DESIGN** — Edit your resume data and download as DOCX
  - **AI POWER** — Radar chart (6 skill dimensions) + 3 tone variants
  - **PREDICT** — Predicts the exact interview questions an interviewer would ask YOU based on your resume
- **Resume Builder** — Build from scratch in 5 steps (Contact / Experience / Education / Skills / Projects), download DOCX or PDF
- AI Builder mode — Enter target role + tone (Professional / Aggressive / Technical), AI rewrites the entire resume

---

### 🗺️ Skill Roadmaps

<!-- Add screenshot here -->
<!-- <img src="screenshots/roadmap_journey.png" width="250" align="right" /> -->

- Generate a personalized AI learning roadmap for any job role
- Stage-by-stage milestone cards with task checklists
- Tap a task to complete it — progress unlocks the next stage automatically
- Per-task learning resources (video / course / docs / article links)
- Study time logger (log minutes per task with a timer sheet)
- Analytics modal: per-stage progress, total hours studied, overall completion

---

### 👤 Profile & Settings

- Edit full name, job title, location, bio, LinkedIn, GitHub
- Animated **sun ↔ moon theme toggle** (dark / light mode, persisted)
- **Arabic ↔ English language toggle** — entire app flips direction instantly (RTL/LTR)
- Change password with full validation
- Delete account with confirmation

---

### 🏠 Home Dashboard

- Personalized greeting with animated time-of-day indicator
- Hero card: average interview score, session counts
- Quick-start banner to resume last interview role
- Performance sparkline chart (last 10 sessions)
- Active roadmap progress card
- Recent activity feed

---

## 🌍 Bilingual (Arabic + English)

The app is fully localized. Every single string has both an Arabic and English version. Toggle language from the Profile → Settings tab.

| | Arabic | English |
|---|---|---|
| Direction | RTL ← | LTR → |
| Voice | `ar-SA-ZariyahNeural` | `en-US-JennyNeural` |
| STT hint | `language: "ar"` | `language: "en"` |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x
- Dart 3.x
- Python 3.11+
- PostgreSQL

### Run locally

```bash
# ── Backend ───────────────────────────────────────────────
git clone https://github.com/MeshMoh506/interview-prep-ai
cd interview-prep-ai-1/backend

# Create .env (see Environment Variables section below)
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --port 8000

# ── Mobile App ────────────────────────────────────────────
cd ../frontend
flutter pub get

# Run on connected device or emulator
flutter run                           # auto-detects device
flutter run -d "iPhone 15"            # iOS
flutter run -d emulator-5554          # Android
```

> API docs available at `http://localhost:8000/docs`

### Environment Variables (`backend/.env`)

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/interview_prep

# Auth
SECRET_KEY=your-secret-key-change-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# AI Keys
GROQ_API_KEY=gsk_...
OPENAI_API_KEY=sk-...
D_ID_API_KEY=your_did_key_base64

# Voice backends
STT_BACKEND=groq        # groq | openai
TTS_BACKEND=openai      # openai | none
```

Update `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl = 'http://localhost:8000';  // dev
// → 'https://your-app.railway.app'                     // prod
```

---

## 📁 Project Structure

```
interview-prep-ai-1/
├── backend/                           # FastAPI server
│   ├── app/
│   │   ├── main.py                    # App entry, CORS, router registration
│   │   ├── config.py                  # Settings (env vars)
│   │   ├── database.py                # SQLAlchemy setup
│   │   ├── models/                    # SQLAlchemy models
│   │   │   ├── user.py
│   │   │   ├── interview.py           # Interview + InterviewMessage
│   │   │   ├── resume.py
│   │   │   └── roadmap.py             # Roadmap + Stage + Task
│   │   ├── routers/                   # API endpoints
│   │   │   ├── auth.py                # /api/v1/auth
│   │   │   ├── users.py               # /api/v1/users
│   │   │   ├── interviews.py          # /api/v1/interviews
│   │   │   ├── resumes.py             # /api/v1/resumes
│   │   │   ├── roadmaps.py            # /api/v1/roadmaps
│   │   │   ├── audio.py               # /api/v1/audio (STT + TTS)
│   │   │   └── dashboard.py           # /api/v1/dashboard
│   │   └── services/                  # Business logic + AI
│   │       ├── interview_ai_service.py  # Groq Llama (CJK fix, retry)
│   │       ├── avatar_service.py        # D-ID Talks v3
│   │       ├── resume_power_service.py  # AI tailor, predict, radar
│   │       ├── resume_template_service.py  # DOCX generation
│   │       ├── pdf_resume_generator.py     # ReportLab PDF
│   │       ├── stt.py                   # STT router
│   │       └── tts.py                   # TTS router
│   └── alembic/                       # DB migrations
│
└── frontend/                          # Flutter mobile app
    └── lib/
        ├── main.dart                  # App entry + Directionality + localization
        ├── core/
        │   ├── constants/api_constants.dart
        │   ├── locale/
        │   │   ├── app_strings.dart   # 389+ bilingual string getters
        │   │   └── locale_provider.dart
        │   ├── router/app_router.dart
        │   ├── theme/
        │   │   ├── app_colors.dart
        │   │   ├── app_theme.dart
        │   │   └── theme_provider.dart
        │   └── utils/text_utils.dart  # CJK character sanitizer
        ├── features/
        │   ├── auth/                  # Login, Register
        │   ├── onboarding/            # Splash, Onboarding, Profile Setup
        │   ├── home/                  # Dashboard
        │   ├── interview/             # List, Setup, Chat, History, Video
        │   ├── profile/               # Profile, Settings, Security
        │   ├── resume/                # List, Detail (7 tabs), Builder
        │   └── roadmap/               # List, Create, Journey
        └── shared/widgets/
            ├── app_bottom_nav.dart
            ├── background_painter.dart
            ├── lang_toggle_button.dart
            ├── skeleton_widgets.dart
            ├── theme_toggle_button.dart
            └── transitions.dart
```

---

## 📸 Adding Screenshots to This README

To add your own screenshots:

1. Take screenshots on your device (iOS: Side + Volume Up / Android: Power + Volume Down)
2. Create a `screenshots/` folder in the repo root
3. Add your images there and update the `<img>` tags at the top of this file

**Recommended sizes:**
- Portrait screenshots: crop to ~390×844px (iPhone 14 size)
- Use a tool like [Mockuphone](https://mockuphone.com) or [Previewed](https://previewed.app) to add a phone frame

**To add a demo video:**
- Record a screen recording on your device
- Export as `.mp4` (keep under 10MB for GitHub)
- Drag and drop the `.mp4` directly into a GitHub issue, copy the URL, then paste it in the README like:
```
https://github.com/MeshMoh506/interview-prep-ai/assets/YOUR_ID/katwah-demo.mp4
```

---

## 🔧 Known Issues & Decisions

| Issue | Resolution |
|---|---|
| Groq Llama bleeds CJK chars in Arabic mode | 3-layer fix: Arabic system prompt + `_enforce()` injection + `_sanitize_arabic()` regex |
| `ThemeNotifier.toggle()` requires `BuildContext` | Call as `ref.read(themeProvider.notifier).toggle(context)` |
| D-ID rejects Unsplash URLs with query params | Backend controls `source_url`, never pass Flutter-supplied URLs |
| `PUT /api/v1/auth/me` returns 405 | Use `PUT /api/v1/users/me` instead |
| Voice STT requires HTTPS on real devices | Must use production HTTPS URL — localhost works only on simulators |

---

## 🚢 Deployment

### Backend → Railway
```bash
# In /backend:
# 1. Add Dockerfile + railway.json (see PROJECT_STATUS.md)
# 2. Push to GitHub
# 3. Connect repo in railway.app
# 4. Set env vars in Railway dashboard
```

### Mobile App → App Stores
```bash
# iOS (requires Mac + Apple Developer account)
flutter build ipa --release
# Upload via Xcode Organizer or Transporter

# Android
flutter build appbundle --release
# Upload .aab to Google Play Console
```

---

## 📄 License

MIT © 2026 Meshari — خطوة / Katwah
