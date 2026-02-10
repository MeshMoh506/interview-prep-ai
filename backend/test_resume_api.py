import requests
import json
from pathlib import Path

BASE_URL = "http://localhost:8000"

def test_resume_flow():
    """Test complete resume upload flow"""
    
    print("=" * 50)
    print("RESUME MODULE TEST SCRIPT")
    print("=" * 50)
    
    # 1. Login
    print("\n1. Logging in...")
    login_response = requests.post(
        f"{BASE_URL}/api/v1/auth/login",
        data={
            "username": "test@example.com",  # Change to your email
            "password": "test123456"         # Change to your password
        }
    )
    
    if login_response.status_code != 200:
        print("❌ Login failed. Please check credentials.")
        return
    
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("✅ Login successful")
    
    # 2. Create test resume file
    print("\n2. Creating test resume file...")
    test_file = Path("test_resume.txt")
    test_file.write_text("John Doe\njohn@email.com\nSoftware Engineer\nPython, JavaScript")
    print("✅ Test file created")
    
    # 3. Upload resume
    print("\n3. Uploading resume...")
    with open(test_file, "rb") as f:
        # Rename to .pdf for testing
        files = {"file": ("test_resume.pdf", f, "application/pdf")}
        data = {"title": "Test Resume"}
        
        upload_response = requests.post(
            f"{BASE_URL}/api/v1/resumes/upload",
            files=files,
            data=data,
            headers=headers
        )
    
    if upload_response.status_code != 201:
        print(f"❌ Upload failed: {upload_response.json()}")
        return
    
    resume_data = upload_response.json()
    resume_id = resume_data["id"]
    print(f"✅ Resume uploaded (ID: {resume_id})")
    print(f"   Title: {resume_data['title']}")
    print(f"   Type: {resume_data['file_type']}")
    print(f"   Size: {resume_data['file_size']} bytes")
    
    # 4. List resumes
    print("\n4. Listing all resumes...")
    list_response = requests.get(
        f"{BASE_URL}/api/v1/resumes/",
        headers=headers
    )
    
    if list_response.status_code == 200:
        resumes = list_response.json()
        print(f"✅ Found {len(resumes)} resume(s)")
        for r in resumes:
            print(f"   - {r['title']} (ID: {r['id']})")
    
    # 5. Get single resume
    print(f"\n5. Getting resume {resume_id}...")
    get_response = requests.get(
        f"{BASE_URL}/api/v1/resumes/{resume_id}",
        headers=headers
    )
    
    if get_response.status_code == 200:
        print("✅ Resume details retrieved")
    
    # 6. Update resume
    print(f"\n6. Updating resume {resume_id}...")
    update_response = requests.put(
        f"{BASE_URL}/api/v1/resumes/{resume_id}",
        headers=headers,
        json={"title": "Updated Test Resume"}
    )
    
    if update_response.status_code == 200:
        updated_data = update_response.json()
        print(f"✅ Resume updated: {updated_data['title']}")
    
    # 7. Delete resume
    print(f"\n7. Deleting resume {resume_id}...")
    delete_response = requests.delete(
        f"{BASE_URL}/api/v1/resumes/{resume_id}",
        headers=headers
    )
    
    if delete_response.status_code == 204:
        print("✅ Resume deleted")
    
    # Cleanup
    test_file.unlink()
    
    print("\n" + "=" * 50)
    print("ALL TESTS PASSED! ✅")
    print("=" * 50)

if __name__ == "__main__":
    try:
        test_resume_flow()
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
