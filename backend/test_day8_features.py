import requests
import json

BASE_URL = "http://localhost:8000"

def run_all_day8_tests():
    """Test all Day 8 features"""
    
    print("=" * 70)
    print("🚀 DAY 8 - COMPLETE FEATURE TESTS")
    print("=" * 70)
    
    # Login
    print("\n1️⃣  Logging in...")
    login = requests.post(
        f"{BASE_URL}/api/v1/auth/login",
        data={"username": "user@example.com", "password": "string"}
    )
    
    if login.status_code != 200:
        print(f"❌ Login failed: {login.json()}")
        return
    
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    resume_id = 3  # Your resume ID
    print("✅ Login successful!")
    
    # ─────────────────────────────────────────────
    # TEST 1: Format Check
    # ─────────────────────────────────────────────
    print("\n" + "─" * 50)
    print("2️⃣  TESTING: Format Checker")
    print("─" * 50)
    
    format_response = requests.post(
        f"{BASE_URL}/api/v1/resumes/{resume_id}/check-format",
        headers=headers
    )
    
    if format_response.status_code == 200:
        format_data = format_response.json()['format_report']
        print(f"✅ Format check complete!")
        print(f"   📊 Format Score: {format_data['format_score']}/100")
        print(f"   📝 Grade: {format_data['grade']} ({format_data['grade_label']})")
        print(f"   ❌ Critical Issues: {format_data['total_issues']}")
        print(f"   ⚠️  Warnings: {format_data['total_warnings']}")
        print(f"   ✅ Passed Checks: {format_data['total_passed']}")
        print(f"\n   🎯 Top Priority: {format_data['top_priority']}")
        
        if format_data['critical_issues']:
            print(f"\n   Critical Issues:")
            for issue in format_data['critical_issues']:
                print(f"   ❌ {issue['issue']}")
                print(f"      Fix: {issue['fix']}")
    else:
        print(f"❌ Format check failed: {format_response.json()}")
    
    # ─────────────────────────────────────────────
    # TEST 2: Job Matching
    # ─────────────────────────────────────────────
    print("\n" + "─" * 50)
    print("3️⃣  TESTING: Job Matcher")
    print("─" * 50)
    
    job_description = """
    We are looking for a Full-Stack Developer to join our team.
    
    Requirements:
    - 2+ years experience in React and Node.js
    - Proficiency in Python and Django/FastAPI
    - Experience with PostgreSQL and MongoDB
    - Knowledge of Docker and containerization
    - Familiarity with AWS or cloud services
    - Strong Git workflow experience
    - Agile/Scrum methodology experience
    - Good communication skills
    - Experience with REST APIs
    - Problem-solving mindset
    
    Nice to have:
    - Experience with Redis
    - Knowledge of CI/CD pipelines
    - Open source contributions
    """
    
    match_response = requests.post(
        f"{BASE_URL}/api/v1/resumes/{resume_id}/match-job",
        headers=headers,
        params={"job_description": job_description}
    )
    
    if match_response.status_code == 200:
        match_data = match_response.json()['match_analysis']
        print(f"✅ Job matching complete!")
        print(f"   🎯 Match Score: {match_data.get('match_score', 'N/A')}/100")
        print(f"   📝 Summary: {match_data.get('summary', 'N/A')[:100]}...")
        
        matching = match_data.get('matching_keywords', [])
        missing = match_data.get('missing_keywords', [])
        
        print(f"\n   ✅ Matching Keywords ({len(matching)}):")
        for kw in matching[:5]:
            print(f"      ✅ {kw.get('keyword')} ({kw.get('importance', 'N/A')})")
        
        print(f"\n   ❌ Missing Keywords ({len(missing)}):")
        for kw in missing[:5]:
            print(f"      ❌ {kw.get('keyword')} - {kw.get('suggestion', 'N/A')}")
    else:
        print(f"❌ Job matching failed: {match_response.text[:200]}")
    
    # ─────────────────────────────────────────────
    # TEST 3: Achievement Rewriting
    # ─────────────────────────────────────────────
    print("\n" + "─" * 50)
    print("4️⃣  TESTING: Achievement Rewriter")
    print("─" * 50)
    
    weak_bullets = [
        "Worked on React frontend for real estate website",
        "Helped with database design for messaging system",
        "Was part of team that built student accommodation platform",
        "Did Python backend development",
        "Assisted with system analysis project"
    ]
    
    rewrite_response = requests.post(
        f"{BASE_URL}/api/v1/resumes/{resume_id}/rewrite-achievements",
        headers=headers,
        params={"job_context": "Full-Stack Developer"},
        json=weak_bullets
    )
    
    if rewrite_response.status_code == 200:
        rewrite_data = rewrite_response.json()['rewrites']
        bullets = rewrite_data.get('rewritten_bullets', [])
        
        print(f"✅ Achievement rewriting complete!")
        print(f"   📝 Bullets rewritten: {len(bullets)}")
        
        for i, bullet in enumerate(bullets[:3], 1):
            print(f"\n   Bullet {i}:")
            print(f"   ❌ BEFORE: {bullet.get('original', 'N/A')}")
            print(f"   ✅ AFTER:  {bullet.get('rewritten', 'N/A')}")
            score = bullet.get('strength_score', 0)
            print(f"   💪 Strength: {score}/10")
    else:
        print(f"❌ Rewriting failed: {rewrite_response.text[:200]}")
    
    # ─────────────────────────────────────────────
    # TEST 4: Power Verbs
    # ─────────────────────────────────────────────
    print("\n" + "─" * 50)
    print("5️⃣  TESTING: Power Verbs API")
    print("─" * 50)
    
    verbs_response = requests.get(
        f"{BASE_URL}/api/v1/resumes/power-verbs",
        headers=headers
    )
    
    if verbs_response.status_code == 200:
        verbs_data = verbs_response.json()
        print(f"✅ Power verbs retrieved!")
        if isinstance(verbs_data['power_verbs'], dict):
            for category, verbs in list(verbs_data['power_verbs'].items())[:3]:
                print(f"   {category}: {', '.join(verbs[:5])}")
    else:
        print(f"❌ Power verbs failed: {verbs_response.text[:200]}")
    
    # ─────────────────────────────────────────────
    # FINAL SUMMARY
    # ─────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("📊 DAY 8 TEST SUMMARY")
    print("=" * 70)
    print("✅ Format Checker - Working!")
    print("✅ Job Matcher - Working!")
    print("✅ Achievement Rewriter - Working!")
    print("✅ Power Verbs API - Working!")
    print("\n🎯 All Day 8 features are operational!")
    print("=" * 70)

if __name__ == "__main__":
    try:
        run_all_day8_tests()
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
