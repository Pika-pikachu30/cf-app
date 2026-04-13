from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal, get_db
from models import User
from schemas import UserCreate, UserLogin
from auth import hash_password, verify_password, create_token
from pydantic import BaseModel
import predictor

router = APIRouter()

class PredictionRequest(BaseModel):
    currentRating: int
    rank: int
    division: str

@router.post("/predict-rating")
def predict_rating_api(req: PredictionRequest):
    try:
        user_delta = predictor.predict_from_latest_contest(req.currentRating, req.rank, req.division)
        er = req.currentRating if req.currentRating > 0 else 1500
        return {
            "delta": user_delta,
            "performance": er + user_delta,
            "newRating": er + user_delta
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/register")
def register(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(400, "User already exists")

    new_user = User(
        email=user.email,
        password=hash_password(user.password)
    )
    db.add(new_user)
    db.commit()
    return {"message": "User created"}

@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()

    if not db_user or not verify_password(user.password, db_user.password):
        raise HTTPException(401, "Invalid credentials")

    token = create_token(db_user.email)
    
    # Include the handle in the response so Flutter can see it
    return {
        "token": token,
        "handle": db_user.codeforces_handle  # Ensure this matches your User model field name
    }

@router.post("/save_handle")
def save_handle(data: dict, db: Session = Depends(get_db)):
    email = data.get("email")
    handle = data.get("handle")
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.codeforces_handle = handle
    db.commit()
    return {"message": "Handle saved"}
