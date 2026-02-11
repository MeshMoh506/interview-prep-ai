# Complete API Endpoints Summary

GET  /                              → Health check
GET  /health                        → Server status

# Authentication
POST /api/v1/auth/register          → Create account
POST /api/v1/auth/login             → Get JWT token

# Users  
GET  /api/v1/users/me               → Get profile
PUT  /api/v1/users/me               → Update profile
DELETE /api/v1/users/me             → Delete account

# Resumes - CRUD
POST /api/v1/resumes/upload         → Upload resume (PDF/DOCX)
GET  /api/v1/resumes/               → List all resumes
GET  /api/v1/resumes/{id}           → Get resume details
PUT  /api/v1/resumes/{id}           → Update resume
DELETE /api/v1/resumes/{id}         → Delete resume

# Resumes - Parsing
POST /api/v1/resumes/{id}/parse     → Rule-based parse (90% accuracy)
POST /api/v1/resumes/{id}/parse-ai  → AI parse (95%+ accuracy)

# Resumes - AI Analysis (Day 7)
POST /api/v1/resumes/{id}/analyze   → Full AI analysis + scoring

# Resumes - ATS Optimization (Day 8)
POST /api/v1/resumes/{id}/check-format          → ATS format check
POST /api/v1/resumes/{id}/match-job             → Job description matcher
POST /api/v1/resumes/{id}/rewrite-achievements  → STAR format rewriter
GET  /api/v1/resumes/power-verbs                → Get power verbs list

TOTAL: 19 endpoints ✅
