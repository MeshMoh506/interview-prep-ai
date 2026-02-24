# backend/migrate_profile.py
# Run this once: python migrate_profile.py
# Adds new profile columns to existing users table

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import engine
from sqlalchemy import text

def migrate():
    columns = [
        ("bio",                  "TEXT"),
        ("location",             "VARCHAR(255)"),
        ("phone",                "VARCHAR(50)"),
        ("linkedin_url",         "VARCHAR(500)"),
        ("github_url",           "VARCHAR(500)"),
        ("portfolio_url",        "VARCHAR(500)"),
        ("avatar_url",           "VARCHAR(500)"),
        ("preferred_language",   "VARCHAR(10) DEFAULT 'en'"),
        ("job_title",            "VARCHAR(255)"),
        ("email_notifications",  "BOOLEAN DEFAULT TRUE"),
        ("interview_reminders",  "BOOLEAN DEFAULT TRUE"),
        ("total_interviews",     "INTEGER DEFAULT 0"),
        ("avg_score",            "FLOAT"),
        ("best_score",           "FLOAT"),
    ]

    with engine.connect() as conn:
        for col_name, col_type in columns:
            try:
                conn.execute(text(
                    f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {col_name} {col_type}"
                ))
                print(f"✅ Added column: {col_name}")
            except Exception as e:
                print(f"⚠️  {col_name}: {e}")
        conn.commit()
    print("\n✅ Migration complete!")

if __name__ == "__main__":
    migrate()