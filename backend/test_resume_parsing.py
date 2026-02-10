import requests
from pathlib import Path

BASE_URL = "http://localhost:8000"

def test_resume_parsing():
    """Test resume parsing functionality"""
    
    print("=" * 60)
    print("RESUME PARSING TEST")
    print("=" * 60)
    
    # 1. Login
    print("\n1. Logging in...")
    login_response = requests.post(
        f"{BASE_URL}/api/v1/auth/login",
        data={
            "username": "test@example.com",
            "password": "test123456"
        }
    )
    
    if login_response.status_code != 200:
        print("❌ Login failed")
        return
    
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("✅ Login successful")
    
    # 2. Create test resume with realistic content
    print("\n2. Creating test resume file...")
    test_content = """
    John Doe
    john.doe@email.com | (555) 123-4567 | linkedin.com/in/johndoe | github.com/johndoe
    
    PROFESSIONAL SUMMARY
    Experienced Software Engineer with 5+ years in full-stack development
    
    EDUCATION
    Bachelor of Science in Computer Science
    University of Technology, 2018
    GPA: 3.8/4.0
    
    Master of Science in Software Engineering
    Tech University, 2020
    
    WORK EXPERIENCE
    Senior Software Engineer | Tech Corp Inc. | Jan 2021 - Present
    - Developed microservices using Python and FastAPI
    - Implemented CI/CD pipelines with GitHub Actions and Docker
    - Led team of 5 developers in agile environment
    
    Software Engineer | StartUp LLC | Jun 2018 - Dec 2020
    - Built React frontend applications with TypeScript
    - Designed RESTful APIs using Node.js and Express
    - Managed PostgreSQL databases and Redis caching
    
    TECHNICAL SKILLS
    Programming Languages: Python, JavaScript, TypeScript, Java, C++
    Web Technologies: React, Angular, Vue.js, HTML, CSS, Node.js, Express, Django, Flask, FastAPI
    Databases: PostgreSQL, MySQL, MongoDB, Redis, Elasticsearch
    Cloud & DevOps: AWS, Docker, Kubernetes, Jenkins, Git, GitHub Actions, CI/CD
    Tools: Git, Jira, Postman, VS Code
    Methodologies: Agile, Scrum, TDD, Microservices
    """
    
    test_file = Path("test_detailed_resume.pdf")
    test_file.write_text(test_content)
    print("✅ Test resume created")
    
    # 3. Upload resume
    print("\n3. Uploading resume...")
    with open(test_file, "rb") as f:
        files = {"file": ("detailed_resume.pdf", f, "application/pdf")}
        data = {"title": "Test Detailed Resume"}
        
        upload_response = requests.post(
            f"{BASE_URL}/api/v1/resumes/upload",
            files=files,
            data=data,
            headers=headers
        )
    
    if upload_response.status_code != 201:
        print(f"❌ Upload failed: {upload_response.json()}")
        return
    
    resume_id = upload_response.json()["id"]
    print(f"✅ Resume uploaded (ID: {resume_id})")
    
    # 4. Parse resume
    print(f"\n4. Parsing resume {resume_id}...")
    parse_response = requests.post(
        f"{BASE_URL}/api/v1/resumes/{resume_id}/parse",
        headers=headers
    )
    
    if parse_response.status_code != 200:
        print(f"❌ Parse failed: {parse_response.json()}")
        return
    
    parsed_data = parse_response.json()
    print("✅ Resume parsed successfully!")
    
    # 5. Display results
    print("\n" + "=" * 60)
    print("PARSING RESULTS")
    print("=" * 60)
    
    # Contact Info
    print("\n📧 CONTACT INFORMATION:")
    contact = parsed_data.get('contact_info', {})
    if contact:
        print(f"  Name: {contact.get('name', 'N/A')}")
        print(f"  Email: {contact.get('email', 'N/A')}")
        print(f"  Phone: {contact.get('phone', 'N/A')}")
        print(f"  LinkedIn: {contact.get('linkedin', 'N/A')}")
        print(f"  GitHub: {contact.get('github', 'N/A')}")
    
    # Education
    print("\n🎓 EDUCATION:")
    education = parsed_data.get('education', [])
    if education:
        for i, edu in enumerate(education, 1):
            print(f"  {i}. {edu.get('degree', edu.get('raw', 'N/A'))}")
            if 'institution' in edu:
                print(f"     {edu['institution']}")
            if 'year' in edu:
                print(f"     Year: {edu['year']}")
    else:
        print("  No education found")
    
    # Experience
    print("\n💼 WORK EXPERIENCE:")
    experience = parsed_data.get('experience', [])
    if experience:
        for i, exp in enumerate(experience, 1):
            print(f"  {i}. {exp.get('title', 'N/A')}")
            if 'company' in exp:
                print(f"     Company: {exp['company']}")
            if 'duration' in exp:
                print(f"     Duration: {exp['duration']}")
    else:
        print("  No experience found")
    
    # Skills
    print("\n🔧 SKILLS:")
    skills = parsed_data.get('skills', [])
    if skills:
        # Group by category
        skills_by_category = {}
        for skill in skills:
            category = skill.get('category', 'Other')
            if category not in skills_by_category:
                skills_by_category[category] = []
            skills_by_category[category].append(skill.get('name', 'N/A'))
        
        for category, skill_list in skills_by_category.items():
            print(f"\n  {category}:")
            print(f"    {', '.join(skill_list)}")
        
        print(f"\n  Total Skills Found: {len(skills)}")
    else:
        print("  No skills found")
    
    # Parsing status
    print(f"\n✅ Parsing Status: {'Parsed' if parsed_data.get('is_parsed') == 1 else 'Not Parsed'}")
    
    # Cleanup
    test_file.unlink()
    
    print("\n" + "=" * 60)
    print("TEST COMPLETED SUCCESSFULLY! ✅")
    print("=" * 60)

if __name__ == "__main__":
    try:
        test_resume_parsing()
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
