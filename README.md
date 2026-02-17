# Interview Prep AI

> **An AI-powered career platform** — practice interviews, optimize resumes, and build your career roadmap.

[![FastAPI](https://img.shields.io/badge/FastAPI-0.109-009688?style=flat-square&logo=fastapi)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Groq](https://img.shields.io/badge/Groq-llama--3.3--70b-F54E42?style=flat-square)](https://groq.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=flat-square&logo=postgresql)](https://postgresql.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

---

## What It Does

| Feature | Description |
|---|---|
| **AI Resume Analysis** | Upload PDF/DOCX → parse, score, ATS-check, and get rewrite suggestions |
| **AI Interview Simulator** | Real-time chat with an AI interviewer — text or voice, English or Arabic |
| **Skill Roadmaps** | Personalised learning paths based on your resume and target role |
| **Career Dashboard** | Live stats, recent activity, skill gaps, and progress tracking |

---

## Tech Stack

### Backend
| Layer | Technology |
|---|---|
| Framework | Python 3.11 + FastAPI |
| Database | PostgreSQL (Supabase) |
| ORM | SQLAlchemy + Alembic |
| Auth | JWT (python-jose) + bcrypt |
| AI — Chat | Groq `llama-3.3-70b-versatile` |
| AI — Voice | Groq `whisper-large-v3` (Arabic + English) |
| Resume Parsing | PyPDF2 + python-docx + spaCy |
| File Storage | Local filesystem (upgradeable to S3) |

### Frontend
| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Web + Mobile) |
| State | Riverpod 2 |
| Navigation | GoRouter 13 |
| HTTP | Dio 5 |
| Charts | fl_chart |
| Animations | Lottie + Shimmer |

---

## Project Structure

```
interview-prep-ai-1/
├── backend/
│   ├── app/
│   │   ├── main.py                  # FastAPI app + routers
│   │   ├── config.py                # Settings (env vars)
│   │   ├── database.py              # SQLAlchemy engine
│   │   ├── models/                  # DB models
│   │   │   ├── user.py
│   │   │   ├── resume.py
│   │   │   └── interview.py
│   │   ├── routers/                 # API endpoints
│   │   │   ├── auth.py              # /api/v1/auth
│   │   │   ├── users.py             # /api/v1/users
│   │   │   ├── resumes.py           # /api/v1/resumes
│   │   │   └── interviews.py        # /api/v1/interviews
│   │   └── services/                # Business logic
│   │       ├── interview_ai_service.py   # Groq chat + Whisper
│   │       ├── ai_analysis_service.py    # Resume scoring
│   │       ├── ai_resume_parser.py       # AI-powered parsing
│   │       ├── job_matcher_service.py    # JD matching
│   │       ├── achievement_rewriter_service.py
│   │       ├── format_checker_service.py
│   │       └── resume_template_service.py
│   ├── requirements.txt
│   └── .env
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── theme/app_theme.dart      # Design system (indigo/cyan)
│   │   │   ├── constants/api_constants.dart
│   │   │   └── router/app_router.dart
│   │   ├── features/
│   │   │   ├── auth/                     # Login + Register screens
│   │   │   ├── home/                     # Dashboard with live stats
│   │   │   ├── resume/                   # List + Detail + Analysis
│   │   │   └── interview/                # Setup + Chat + History
│   │   ├── services/                     # API layer (Dio)
│   │   └── shared/widgets/              # Reusable components
│   └── pubspec.yaml
│
└── docs/
    └── PROJECT_DOCUMENTATION.docx
```

---

## API Reference

### Authentication  `/api/v1/auth`
| Method | Endpoint | Description |
|---|---|---|
| POST | `/register` | Create account |
| POST | `/login` | Get JWT token |
| POST | `/logout` | Invalidate session |

### Users  `/api/v1/users`
| Method | Endpoint | Description |
|---|---|---|
| GET | `/me` | Get profile |
| PUT | `/me` | Update profile |
| DELETE | `/me` | Delete account |

### Resumes  `/api/v1/resumes`
| Method | Endpoint | Description |
|---|---|---|
| POST | `/upload` | Upload PDF/DOCX |
| POST | `/{id}/parse` | Rule-based parsing |
| POST | `/{id}/parse-ai` | AI-powered parsing |
| POST | `/{id}/analyze` | AI analysis + score |
| POST | `/{id}/check-format` | ATS format check |
| POST | `/{id}/match-job` | Match to job description |
| POST | `/{id}/rewrite-achievements` | AI bullet point rewriter |
| POST | `/{id}/generate` | Generate formatted DOCX |
| GET | `/{id}/download` | Download resume file |
| GET | `/` | List all resumes |
| GET | `/{id}` | Get single resume |
| PUT | `/{id}` | Update resume data |
| DELETE | `/{id}` | Delete resume |
| GET | `/templates` | List resume templates |
| GET | `/power-verbs` | Get action verb list |

### Interviews  `/api/v1/interviews`
| Method | Endpoint | Description |
|---|---|---|
| POST | `/` | Start new interview |
| POST | `/{id}/message` | Send text message |
| POST | `/{id}/voice` | Send voice (Whisper STT) |
| POST | `/{id}/end` | End + generate report |
| GET | `/` | List all interviews |
| GET | `/{id}` | Get with full transcript |
| DELETE | `/{id}` | Delete interview |

---

## Getting Started

### Prerequisites
- Python 3.11+
- Flutter 3.x SDK
- PostgreSQL (or Supabase account)
- Groq API key — free at [console.groq.com](https://console.groq.com)

### Backend Setup

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate

pip install -r requirements.txt
```

Create `backend/.env`:
```env
DATABASE_URL=postgresql://user:password@host:5432/interview_prep
SECRET_KEY=your-secret-key-min-32-chars
GROQ_API_KEY=gsk_your_groq_key_here
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

Run migrations and start:
```bash
alembic upgrade head
uvicorn app.main:app --reload
# API docs at http://localhost:8000/docs
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Update `lib/core/constants/api_constants.dart` if your backend runs on a different port:
```dart
static const String baseUrl = 'http://localhost:8000';
```

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | ✅ | PostgreSQL connection string |
| `SECRET_KEY` | ✅ | JWT signing key (32+ chars) |
| `GROQ_API_KEY` | ✅ | Groq API key (free tier available) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | ❌ | JWT TTL, default `30` |
| `UPLOAD_DIR` | ❌ | File storage path, default `uploads/resumes` |
| `MAX_FILE_SIZE` | ❌ | Max upload bytes, default `5242880` (5 MB) |

---

## Key Design Decisions

**Why Groq instead of OpenAI?**
Groq's inference is 10-20× faster than OpenAI for the same model class. `llama-3.3-70b-versatile` matches GPT-4o quality on interview conversation tasks at a fraction of the cost, and `whisper-large-v3` provides first-class Arabic support which was a hard requirement.

**Why Flutter Web?**
Single codebase that runs in the browser today and compiles to iOS/Android later with minimal changes. Riverpod gives clean separation between UI and business logic.

**Multi-user data isolation**
All Riverpod providers that hold user-specific data (`interviewHistoryProvider`, `resumeProvider`, `dashboardProvider`) are invalidated on both login and logout — ensuring user A never sees user B's data within the same browser session.

---

## Roadmap

- [ ] Skill Roadmap module (learning paths + milestones)
- [ ] Real-time interview TTS (AI speaks the questions aloud)
- [ ] Mobile build (iOS + Android)
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Production deployment (Railway + Vercel)
- [ ] User analytics dashboard (admin view)

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m "feat: your feature description"`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request

---

## License

MIT © 2026 — see [LICENSE](LICENSE) for details.
