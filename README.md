<div align="center">

<img src="screenshots/logo.jpg" width="140" alt="خطوة Logo"/>

# خطوة (Katwah) — AI Interview Prep Platform

**Practice smarter. Interview better. Land the job.**

A full-stack, bilingual (Arabic/English) AI-powered job seeking preparation platform.  
Built with Flutter Web & Mobile + FastAPI.

[![Flutter](https://img.shields.io/badge/Flutter-3.41.2-blue?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Python-green?logo=fastapi)](https://fastapi.tiangolo.com)
[![Groq](https://img.shields.io/badge/AI-Groq%20Llama%203.3%2070B-orange)](https://groq.com)
[![License](https://img.shields.io/badge/License-MIT-purple)](LICENSE)

</div>

---

## 📱 Screenshots

<div align="center">

| Login | Home (EN) | Home (AR) |
|:-----:|:---------:|:---------:|
| <img src="screenshots/login.png" width="180"/> | <img src="screenshots/home.png" width="180"/> | <img src="screenshots/home_Arabic.png" width="180"/> |

| Goals | Roadmap | Profile |
|:-----:|:-------:|:-------:|
| <img src="screenshots/goals.png" width="180"/> | <img src="screenshots/roadmap.png" width="180"/> | <img src="screenshots/profile.png" width="180"/> |

| Interview Chat | Live Avatar Interview | AI Feedback & Behavior |
|:--------------:|:--------------------:|:----------------------:|
| <img src="screenshots/interview_chat.png" width="180"/> | <img src="screenshots/interview.png" width="180"/> | <img src="screenshots/feedback.png" width="180"/> |

</div>

---

## ✨ Features

### 🎯 AI Interview Simulation
- **Text Mode** — Type answers, get instant AI feedback
- **Voice Mode** — Speak naturally using device microphone (Groq Whisper STT)
- **Live Avatar Mode** — Full video interview with a D-ID AI avatar that speaks and responds in real time
- **Behavior Analysis** — Real-time analysis of interviewee confidence, nervousness, eye contact, and posture using face and hand detection during live video interviews

### 📊 Rich Feedback & Behavior Report
- Animated score ring with grade badge (A/B/C/D/F) and recommendation label
- Score breakdown: Communication, Technical, Confidence
- Per-question analysis with best/weakest answer markers
- Camera analysis: confidence, nervousness, engagement, posture scores
- Voice analysis: clarity, pace, filler word detection
- **Personal AI Coach Tips** — personalized tips based on assessed stress levels, confidence, and behavioral data
- Bilingual feedback (Arabic/English) with star rating system

### 📄 Resume Intelligence
- Upload PDF/DOCX resumes
- 7-tab deep analysis: Overview, Analysis, ATS Score, Job Match, Design, AI Power, Question Predictor
- AI-powered resume builder (manual + AI-written modes)
- Radar chart skill visualization
- Resume variants (Professional / Aggressive / Technical tones)

### 🎯 Goals System
- Create career goals with target role, company, and deadline
- Weekly interview targets with streak tracking
- Auto-generate learning roadmaps tied to goals
- Link resumes to goals for targeted analysis
- Goal-aware AI interviews — questions tailored to your specific role
- Next-step AI recommendations based on progress

### 🗺️ Learning Roadmaps
- AI-generated personalized learning paths
- Stage-by-stage task tracking with completion
- Resource links per task
- Progress visualization

### 👤 Profile & Settings
- Full profile management (name, target role, industry)
- Performance stats (avg score, interviews done, streaks)
- Dark / Light theme toggle
- Arabic / English language toggle (full RTL support)

### 🔐 Authentication
- Email/password login & registration
- Google Sign-In
- JWT-secured sessions

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.41.2 (Web + Android + iOS) |
| **State Management** | Riverpod |
| **Navigation** | GoRouter |
| **Backend** | FastAPI (Python) |
| **Database** | PostgreSQL + SQLAlchemy |
| **AI — Interviews** | Groq Llama 3.3 70B |
| **AI — Vision/Behavior** | Groq Llama 3.2 11B Vision |
| **AI — Speech to Text** | Groq Whisper Large v3 |
| **AI — Text to Speech** | OpenAI TTS |
| **AI — Avatar Video** | D-ID Talks API |
| **HTTP Client** | Dio |
| **Auth** | JWT + Google OAuth |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.41+
- Python 3.10+
- PostgreSQL
- API keys: Groq, OpenAI, D-ID

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: .\venv\Scripts\Activate
pip install -r requirements.txt

# Copy and fill in your keys
cp .env.example .env

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend

```bash
cd frontend
flutter pub get

# Run on Chrome
flutter run -d chrome

# Run on Android emulator
flutter run
```

---

## 🌐 Bilingual Support

خطوة is fully bilingual with complete RTL layout support for Arabic.

- All UI strings translated (AR/EN)
- RTL-aware layouts using `Directionality`
- AI responses in the user's selected language
- Arabic-first design philosophy

---

## 📊 Behavior Analysis

During live video interviews, خطوة analyzes the interviewee in real time:

- **Confidence scoring** — posture, head position, eye contact (camera)
- **Nervousness detection** — hand movement, facial micro-expressions (camera)
- **Voice analysis** — clarity, pace, filler word detection (Groq Whisper + LLM)
- **Personal AI Coach Tips** — generated from real behavioral data (stress level, confidence, pace)
- **Post-interview report** — full behavior breakdown alongside AI answer feedback
- Camera frames analyzed every 4 seconds using Groq vision LLM
- Combined score: Camera 35% + Voice 30% + Answer Quality 35%

---

## 🗂 Project Structure

```
interview-prep-ai/
├── backend/
│   ├── app/
│   │   ├── models/          # SQLAlchemy models
│   │   ├── routers/         # API endpoints
│   │   ├── services/        # AI service layer
│   │   └── main.py
│   └── requirements.txt
└── frontend/
    └── lib/
        ├── core/            # Theme, routing, constants
        ├── features/        # Auth, Interview, Resume, Goals, Roadmap, Profile
        ├── services/        # API, TTS, Audio, Behavior
        └── shared/          # Widgets, animations
```

---

## 📋 Roadmap

- [x] Authentication (email + Google)
- [x] Resume upload & 7-tab AI analysis
- [x] AI interview simulation (text + voice)
- [x] Live avatar video interviews (D-ID)
- [x] Goals system with goal-aware AI
- [x] Learning roadmaps
- [x] Profile & settings
- [x] Bilingual Arabic/English
- [x] Android mobile support
- [x] Behavior analysis (camera + voice + coach tips)
- [x] Rich feedback with per-question breakdown
- [ ] iOS App Store release
- [ ] Production deployment
- [ ] Push notifications

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

Built with ❤️ in Saudi Arabia 🇸🇦

**خطوة** — Every journey starts with a single step.

</div>
