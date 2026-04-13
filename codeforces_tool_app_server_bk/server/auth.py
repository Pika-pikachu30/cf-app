from passlib.context import CryptContext
from jose import jwt
import os
SECRET_KEY = os.environ.get("SECRET_KEY", "a-very-hard-to-guess-fallback-string")
ALGORITHM = "HS256"

pwd_context = CryptContext(schemes=["bcrypt"])

def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)

def create_token(email: str):
    return jwt.encode({"sub": email}, SECRET_KEY, algorithm=ALGORITHM)


