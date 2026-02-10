import os
from huggingface_hub import InferenceClient
from dotenv import load_dotenv

load_dotenv()

token = os.getenv("HUGGINGFACE_TOKEN")
print(f"Token loaded: {token[:10]}..." if token else "❌ No token found!")

# Test connection
try:
    client = InferenceClient(token=token)
    print("✅ Hugging Face connection successful!")
except Exception as e:
    print(f"❌ Connection failed: {e}")
