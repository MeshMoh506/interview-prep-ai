# Run once: python init_db.py
from app.database import engine, Base
from app.models import user, resume, interview, roadmap  # noqa

def init():
    print("Creating all tables...")
    Base.metadata.create_all(bind=engine)
    print("✅ Done!")

if __name__ == "__main__":
    init()