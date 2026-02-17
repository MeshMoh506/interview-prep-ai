"""
Run this script from backend/ to check and fix the database columns.
It adds any missing columns safely (won't fail if they already exist).
"""
import os, sys
sys.path.insert(0, os.getcwd())

from dotenv import load_dotenv
load_dotenv()

from app.database import engine
from sqlalchemy import text

MIGRATIONS = [
    # interviews table
    "ALTER TABLE interviews ADD COLUMN IF NOT EXISTS voice_used BOOLEAN DEFAULT FALSE",
    "ALTER TABLE interviews ADD COLUMN IF NOT EXISTS tts_used BOOLEAN DEFAULT FALSE", 
    "ALTER TABLE interviews ADD COLUMN IF NOT EXISTS message_count INTEGER DEFAULT 0",
    "ALTER TABLE interviews ADD COLUMN IF NOT EXISTS user_msg_count INTEGER DEFAULT 0",
    # interview_messages table
    "ALTER TABLE interview_messages ADD COLUMN IF NOT EXISTS is_voice BOOLEAN DEFAULT FALSE",
    "ALTER TABLE interview_messages ADD COLUMN IF NOT EXISTS transcript_language VARCHAR(10)",
]

with engine.connect() as conn:
    for sql in MIGRATIONS:
        try:
            conn.execute(text(sql))
            print(f"✓ {sql.split('ADD COLUMN')[1].strip().split()[0] if 'ADD COLUMN' in sql else sql[:40]}")
        except Exception as e:
            print(f"✗ {e}")
    conn.commit()

print("\n✅ Database ready!")