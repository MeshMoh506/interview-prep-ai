# Run this ONCE after deploying the new interview model to add the new columns.
# Usage: python upgrade_interview_model.py
#
# If you use Alembic, run: alembic revision --autogenerate -m "interview_voice_fields"
#                          alembic upgrade head
#
# If you manage migrations manually, run this script directly.

import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)

ALTER_STATEMENTS = [
    # Interview table — new columns
    "ALTER TABLE interviews ADD COLUMN IF NOT EXISTS voice_used      BOOLEAN DEFAULT FALSE",
    "ALTER TABLE interviews ADD COLUMN IF NOT EXISTS tts_used        BOOLEAN DEFAULT FALSE",
    "ALTER TABLE interviews ADD COLUMN IF NOT EXISTS message_count   INTEGER DEFAULT 0",
    "ALTER TABLE interviews ADD COLUMN IF NOT EXISTS user_msg_count  INTEGER DEFAULT 0",

    # InterviewMessage table — new columns
    "ALTER TABLE interview_messages ADD COLUMN IF NOT EXISTS is_voice            BOOLEAN DEFAULT FALSE",
    "ALTER TABLE interview_messages ADD COLUMN IF NOT EXISTS transcript_language VARCHAR(10)",
]

with engine.connect() as conn:
    for stmt in ALTER_STATEMENTS:
        print(f"Running: {stmt}")
        conn.execute(text(stmt))
    conn.commit()

print("\n✅ Interview model migration complete!")