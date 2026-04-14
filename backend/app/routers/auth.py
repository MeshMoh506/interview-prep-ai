# app/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from typing import Optional
import httpx

from app.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse, Token, GoogleAuthRequest
from app.utils.security import hash_password, verify_password, create_access_token, decode_access_token
from app.config import settings

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/auth/login")


# ══════════════════════════════════════════════════════════════════
# DEPENDENCY — reused by all protected routers
# ══════════════════════════════════════════════════════════════════
async def get_current_user(
    token: str    = Depends(oauth2_scheme),
    db:    Session = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception

    email: Optional[str] = payload.get("sub")
    if email is None:
        raise credentials_exception

    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive",
        )
    return user


# ══════════════════════════════════════════════════════════════════
# REGISTER
# ══════════════════════════════════════════════════════════════════
@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user_data.email.lower()).first()
    if existing:
        raise HTTPException(status_code=400,
            detail="Email already registered. Please use a different email or login.")

    if len(user_data.password) < 8:
        raise HTTPException(status_code=400,
            detail="Password must be at least 8 characters long")

    if not user_data.full_name or len(user_data.full_name.strip()) < 2:
        raise HTTPException(status_code=400,
            detail="Full name must be at least 2 characters")

    user = User(
        email=user_data.email.lower(),
        hashed_password=hash_password(user_data.password),
        full_name=user_data.full_name.strip(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# ══════════════════════════════════════════════════════════════════
# LOGIN
# ══════════════════════════════════════════════════════════════════
@router.post("/login", response_model=Token)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db:        Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == form_data.username.lower()).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password. Please try again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(status_code=403,
            detail="Your account has been deactivated. Please contact support.")

    expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES or 10080)
    token   = create_access_token(data={"sub": user.email}, expires_delta=expires)
    return {"access_token": token, "token_type": "bearer"}


# ══════════════════════════════════════════════════════════════════
# GOOGLE OAUTH
# FIX: is_verified now exists on the User model — no longer crashes
# ══════════════════════════════════════════════════════════════════
@router.post("/google", response_model=Token)
async def google_auth(auth_data: GoogleAuthRequest, db: Session = Depends(get_db)):
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"https://oauth2.googleapis.com/tokeninfo?id_token={auth_data.id_token}"
            )
            if resp.status_code != 200:
                raise HTTPException(status_code=401, detail="Invalid Google token")

            data  = resp.json()
            email = data.get("email", "").lower()
            name  = data.get("name", "Google User")

            if not email:
                raise HTTPException(status_code=400, detail="Email not provided by Google")

    except httpx.RequestError:
        raise HTTPException(status_code=503,
            detail="Unable to verify Google token. Please try again.")

    user = db.query(User).filter(User.email == email).first()
    if not user:
        user = User(
            email=email,
            hashed_password=hash_password(f"google_oauth_{email}"),
            full_name=name,
            is_verified=True,   # Google emails are pre-verified
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Your account has been deactivated")

    expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES or 10080)
    token   = create_access_token(data={"sub": user.email}, expires_delta=expires)
    return {"access_token": token, "token_type": "bearer"}


# ══════════════════════════════════════════════════════════════════
# GET CURRENT USER  (kept here for /auth/me backward compat)
# Full profile available at GET /api/v1/users/me
# ══════════════════════════════════════════════════════════════════
@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


# ══════════════════════════════════════════════════════════════════
# LOGOUT  (client-side token deletion)
# ══════════════════════════════════════════════════════════════════
@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)):
    return {
        "message": f"Successfully logged out {current_user.email}",
        "action":  "Please delete your access token from local storage",
    }