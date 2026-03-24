<div align="center">

# خطوة · Katwah
### AI-Powered Interview Preparation App
**Bilingual Arabic / English · Flutter Mobile · iOS & Android**

[![Flutter](https://img.shields.io/badge/Flutter-Mobile-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Python-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Groq](https://img.shields.io/badge/Groq-Llama_3.3_70B-F54E42?logoColor=white)](https://groq.com)
[![Platform](https://img.shields.io/badge/Platform-iOS_%7C_Android-lightgrey?logo=apple)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-22C55E)](LICENSE)

<br/>

> **خطوة** — Arabic for *"a step"*.  
> Every interview, every resume, every roadmap — one step closer to your dream job.

<br/>

<table>
  <tr>
    <td><img src="screenshots/home.png" width="180" alt="Home"/></td>
    <td><img src="screenshots/interview.png" width="180" alt="Interview"/></td>
    <td><img src="screenshots/resume.png" width="180" alt="Resume"/></td>
    <td><img src="screenshots/roadmap.png" width="180" alt="Roadmap"/></td>
    <td><img src="screenshots/profile.png" width="180" alt="Profile"/></td>
  </tr>
  <tr>
    <td align="center"><b>Home</b></td>
    <td align="center"><b>Interview</b></td>
    <td align="center"><b>Resume</b></td>
    <td align="center"><b>Roadmap</b></td>
    <td align="center"><b>Profile</b></td>
  </tr>
</table>

<br/>

https://github.com/MeshMoh506/interview-prep-ai/assets/YOUR_GITHUB_USER_ID/katwah-demo.mp4

</div>

---

## 📱 About

**Katwah** is a native mobile app (iOS & Android) built with Flutter that helps Arabic and English-speaking job seekers land their dream job through AI-powered practice.

- 🎤 Practice mock interviews with an AI interviewer — text, voice, or a talking avatar
- 📄 Upload your resume and get a full AI analysis in seconds
- 🗺️ Generate a personalized learning roadmap for any job role
- 📊 Track your scores and improvement over time
- 🌐 Fully bilingual — Arabic (RTL) and English (LTR), toggle with one tap

---

## ⚙️ Tech Stack

| Layer | Technology |
|---|---|
| **Mobile App** | Flutter (Dart), Riverpod, GoRouter |
| **Backend API** | FastAPI (Python 3.11), SQLAlchemy, Alembic |
| **Database** | PostgreSQL / Supabase |
| **AI — Interviews** | Groq Llama 3.3 70B Versatile |
| **AI — Speech Recognition** | Groq Whisper Large v3 |
| **AI — Text to Speech** | OpenAI TTS (tts-1) |
| **AI — Talking Avatar** | D-ID Talks API v3 |
| **Auth** | JWT + bcrypt |
| **Deployment** | Railway (backend) · App Store / Google Play (app) |

---

## ✨ Features

### 🎤 AI Interview Simulation

Practice real interviews with an AI interviewer that adapts to your role, difficulty, and language.

- **Text mode** — Type your answers and get AI questions back in real time
- **Voice mode** — Hold the mic button to speak. Your answer is transcribed live by Whisper STT, and the AI reads the next question out loud via TTS
- **Live Avatar mode** — A D-ID talking presenter reads the question on video. AI text appears instantly while the video clip renders in the background
- Sessions are 7 questions long with a per-answer score (1–10)
- Final report: overall score, strengths, areas to improve, communication/technical/confidence breakdown
- ⭐ Rate each session 1–5 stars with optional written feedback
- Full practice history with expandable AI feedback per session

---

### 📄 Resume Module

Upload once — get a full AI-powered analysis across 7 tabs.

| Tab | What it does |
|---|---|
| **INFO** | File details, parse & analyze actions |
| **ANALYSIS** | Overall score, strengths, weaknesses, keyword recommendations |
| **ATS** | ATS compatibility grade (A–F), critical issues, passed checks |
| **MATCH** | Paste any job description → match score + missing keywords |
| **DESIGN** | Edit your resume data inline and download as DOCX |
| **AI POWER** | Radar chart across 6 skill dimensions + 3 tone variant DOCXs |
| **PREDICT** | Predicts the exact questions an interviewer would ask based on YOUR resume |

**Resume Builder** — Build a resume from scratch in 5 sections (Contact / Experience / Education / Skills / Projects). Download as DOCX or PDF.  
**AI Builder** — Enter your target role + tone (Professional / Aggressive / Technical) and the AI rewrites your entire resume.

---

### 🗺️ Skill Roadmaps

Get a personalized AI learning path for any job role in seconds.

- Stage-by-stage milestone cards with task checklists
- Complete a task → progress bar updates → next stage unlocks automatically
- Each task has curated resources (video / course / article / docs)
- Log your study time per task with a built-in timer
- Analytics modal: total hours studied, per-stage breakdown, overall completion

---

### 👤 Profile & Settings

- Edit name, job title, location, bio, LinkedIn, GitHub
- Animated **dark ↔ light mode** toggle — persisted between sessions
- **Arabic ↔ English** toggle — entire app flips direction instantly (RTL/LTR)
- Change password with full validation
- Delete account

---

### 🏠 Home Dashboard

- Personalized greeting with animated time-of-day indicator
- Average score card + interview/resume/roadmap counts
- Quick-start banner to jump straight into a practice session
- Performance sparkline chart (last 10 sessions)
- Active roadmap progress card
- Recent activity feed

---

## 🌍 Bilingual — Arabic & English

Every screen, every label, every AI response works in both languages.  
Toggle from **Profile → Settings → Language**.

| | Arabic | English |
|---|---|---|
| Direction | ← RTL | LTR → |
| TTS Voice | `ar-SA-ZariyahNeural` | `en-US-JennyNeural` |
| AI Prompt | Arabic-enforced system prompt | Standard English |

---

## 🚀 Running Locally

### Prerequisites
- Flutter SDK 3.x · Dart 3.x
- Python 3.11+
- PostgreSQL

### Backend
```bash
cd backend
cp .env.example .env      # fill in your API keys
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

### Mobile App
```bash
cd frontend
flutter pub get
flutter run               # auto-detects connected device / emulator
```

### Environment Variables (`backend/.env`)
```env
DATABASE_URL=postgresql://user:password@localhost:5432/interview_prep
SECRET_KEY=your-secret-key
ACCESS_TOKEN_EXPIRE_MINUTES=10080
GROQ_API_KEY=gsk_...
OPENAI_API_KEY=sk-...
D_ID_API_KEY=your_did_key
STT_BACKEND=groq
TTS_BACKEND=openai
```

---

## 📁 Project Structure

```
interview-prep-ai-1/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── models/          user · interview · resume · roadmap
│   │   ├── routers/         auth · users · interviews · resumes · roadmaps · audio · dashboard
│   │   └── services/        interview_ai · avatar · resume_power · stt · tts · pdf_generator
│   └── alembic/
│
└── frontend/
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── locale/      app_strings.dart (389+ bilingual getters)
        │   ├── router/      app_router.dart
        │   ├── theme/       app_colors · app_theme · theme_provider
        │   └── utils/       text_utils.dart (CJK sanitizer)
        ├── features/
        │   ├── auth/        login · register
        │   ├── onboarding/  splash · onboarding · profile_setup
        │   ├── home/        dashboard
        │   ├── interview/   list · setup · chat · history · video
        │   ├── profile/     profile · settings · security
        │   ├── resume/      list · detail (7 tabs) · builder
        │   └── roadmap/     list · create · journey
        └── shared/widgets/
            app_bottom_nav · background_painter · lang_toggle_button
            skeleton_widgets · theme_toggle_button · transitions
```

---

## 🚢 Deployment

### Backend → Railway
```bash
# Add Dockerfile + railway.json to /backend
# Connect repo in railway.app, set env vars, deploy
```

### Mobile → App Stores
```bash
# iOS
flutter build ipa --release

# Android
flutter build appbundle --release
```

---

## 📄 License

MIT © 2026 Meshari — خطوة / Katwah
