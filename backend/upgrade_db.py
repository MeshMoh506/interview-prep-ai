from app.database import engine, Base
from app.models.user import User
from app.models.resume import Resume
from app.models.interview import Interview, InterviewMessage
from sqlalchemy import inspect, text

def upgrade_db():
    print("Upgrading database...")
    Base.metadata.create_all(bind=engine)
    inspector = inspect(engine)
    with engine.connect() as conn:
        interview_cols = [c["name"] for c in inspector.get_columns("interviews")]
        for col, dtype, default in [
            ("language",        "VARCHAR(10)", "'en'"),
            ("job_description", "TEXT",        "NULL"),
            ("resume_id",       "INTEGER",     "NULL"),
        ]:
            if col not in interview_cols:
                try:
                    conn.execute(text(f"ALTER TABLE interviews ADD COLUMN {col} {dtype} DEFAULT {default}"))
                    print(f"OK added interviews.{col}")
                except Exception as e:
                    print(f"  skip {col}: {e}")
        conn.commit()
    print("Done:", inspect(engine).get_table_names())

if __name__ == "__main__":
    upgrade_db()
