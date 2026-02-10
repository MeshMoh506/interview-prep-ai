# interview-prep-ai
Ai Capstone Project : 



Backend: 
  - FastAPI (Advanced) ⚡
  - PostgreSQL
  - Hugging Face Inference API
  - PyPDF2, python-docx, spaCy

Frontend: 
  - Flutter (Start simple, grow skills)
  - Riverpod (State management)
  - Clean, functional UI (not fancy at first)

AI/ML: 
  - Hugging Face Inference API (No GPU needed!)
  - Models: Mistral-7B, Llama-2-13B
  - Start with API, optimize later

Deployment: (Free tier everything 🆓)
  - Backend: Render.com or Railway.app
  - Frontend: Vercel
  - Database: Supabase (Free PostgreSQL)
  - Version Control: GitHub
```

---

## 📦 **PROJECT STRUCTURE**
```
interview-prep-ai/
├── backend/                 # FastAPI (Python) - YOUR STRENGTH
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── models/         # SQLAlchemy models
│   │   ├── schemas/        # Pydantic schemas
│   │   ├── routers/        # API endpoints
│   │   ├── services/       # Business logic
│   │   │   ├── ai_service.py          # HuggingFace integration
│   │   │   ├── resume_parser.py       # PDF/DOCX parsing
│   │   │   ├── skill_extractor.py     # NLP skill extraction
│   │   │   └── interview_service.py   # Interview logic
│   │   └── utils/          # Helper functions
│   ├── tests/
│   ├── requirements.txt
│   └── .env
│
├── frontend/               # Flutter (Dart) - WE'LL LEARN
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/          # Theme, constants, router
│   │   ├── features/      # Auth, Resume, Interview, Roadmap
│   │   ├── services/      # API calls
│   │   └── shared/        # Reusable widgets
│   └── pubspec.yaml
│
├── docs/                   # Documentation
├── .github/                # GitHub Actions (CI/CD)
└── README.md
