from app.database import engine, Base
from app.models.user import User
from app.models.resume import Resume
from sqlalchemy import text

def upgrade_db():
    """Add new columns to resumes table"""
    print("Upgrading database...")
    
    with engine.connect() as conn:
        # Add certifications column if it doesn't exist
        try:
            conn.execute(text("ALTER TABLE resumes ADD COLUMN certifications JSON"))
            print("✅ Added certifications column")
        except Exception as e:
            print(f"⚠️ certifications column might already exist: {e}")
        
        # Add projects column if it doesn't exist
        try:
            conn.execute(text("ALTER TABLE resumes ADD COLUMN projects JSON"))
            print("✅ Added projects column")
        except Exception as e:
            print(f"⚠️ projects column might already exist: {e}")
        
        conn.commit()
    
    print("✅ Database upgrade complete!")

if __name__ == "__main__":
    upgrade_db()
