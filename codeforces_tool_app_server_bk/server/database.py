from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

# Use the environment variable from Render, or fallback to local for testing
DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:1344@localhost/codeforces_tool_app_DB")

# Neon/Render sometimes use 'postgres://', but SQLAlchemy requires 'postgresql://'
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()