from app.database import engine, Base
from app.models.user import User
from app.models.resume import Resume
from app.models.interview import Interview, InterviewMessage
def init_db():
    print("Creating all tables...")
    Base.metadata.create_all(bind=engine)
    print("Done: users, resumes, interviews, interview_messages")
if __name__ == "__main__":
    init_db()
