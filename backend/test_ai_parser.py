import sys
sys.path.append("app")

from services.ai_resume_parser import AIResumeParser
from services.resume_parser import ResumeParser

def test_ai_parsing():
    """Test AI resume parser"""
    
    print("=" * 60)
    print("AI RESUME PARSER TEST")
    print("=" * 60)
    
    # Initialize parsers
    basic_parser = ResumeParser()
    ai_parser = AIResumeParser()
    
    # Test resume path (use your uploaded resume)
    resume_path = "uploads/resumes/2/Meshari Mohammed CV updated_20260209_193426.pdf"
    
    print("\n1. Extracting text from PDF...")
    raw_text = basic_parser.extract_text_from_pdf(resume_path)
    print(f"✅ Extracted {len(raw_text)} characters")
    
    print("\n2. Parsing with AI...")
    print("⏳ This may take 10-30 seconds...")
    
    result = ai_parser.parse_resume_with_ai(raw_text)
    
    if result['success']:
        print("✅ AI parsing successful!")
        
        data = result['data']
        
        print("\n" + "=" * 60)
        print("PARSED DATA")
        print("=" * 60)
        
        # Contact Info
        print("\n📧 CONTACT INFO:")
        contact = data.get('contact_info', {})
        for key, value in contact.items():
            print(f"  {key}: {value}")
        
        # Education
        print(f"\n🎓 EDUCATION ({len(data.get('education', []))} entries):")
        for i, edu in enumerate(data.get('education', []), 1):
            print(f"  {i}. {edu.get('degree', 'N/A')} - {edu.get('institution', 'N/A')}")
        
        # Experience
        print(f"\n💼 EXPERIENCE ({len(data.get('experience', []))} entries):")
        for i, exp in enumerate(data.get('experience', []), 1):
            print(f"  {i}. {exp.get('title', 'N/A')} at {exp.get('company', 'N/A')}")
        
        # Skills
        print(f"\n🔧 SKILLS ({len(data.get('skills', []))} found):")
        skills_by_cat = {}
        for skill in data.get('skills', []):
            cat = skill.get('category', 'Other')
            if cat not in skills_by_cat:
                skills_by_cat[cat] = []
            skills_by_cat[cat].append(skill.get('name'))
        
        for cat, skills in skills_by_cat.items():
            print(f"\n  {cat}:")
            print(f"    {', '.join(skills[:10])}")  # Show first 10
        
        # Projects
        print(f"\n📁 PROJECTS ({len(data.get('projects', []))} found):")
        for i, proj in enumerate(data.get('projects', []), 1):
            print(f"  {i}. {proj.get('name', 'N/A')}")
        
        # Certifications
        print(f"\n📜 CERTIFICATIONS ({len(data.get('certifications', []))} found):")
        for i, cert in enumerate(data.get('certifications', []), 1):
            print(f"  {i}. {cert.get('name', 'N/A')}")
        
        print("\n" + "=" * 60)
        print("TEST COMPLETED SUCCESSFULLY! ✅")
        print("=" * 60)
        
    else:
        print(f"❌ AI parsing failed: {result['error']}")
        if result.get('raw_response'):
            print(f"\nRaw response:\n{result['raw_response'][:500]}...")

if __name__ == "__main__":
    try:
        test_ai_parsing()
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
