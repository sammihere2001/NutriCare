from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timedelta
from app import schemas, crud_auth, auth_utils
from app.config import settings
from app.database import get_db
from app.models import User
from jose import jwt, JWTError
import hashlib
from sqlalchemy import select

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=schemas.TokenResponse)
async def register(payload: schemas.UserCreate, db: AsyncSession = Depends(get_db)):
    existing = await crud_auth.get_user_by_email(db, payload.email)
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = await crud_auth.create_user(
        db,
        payload.email,
        payload.first_name,
        payload.last_name,
        payload.password
    )

    if user is None:
        raise HTTPException(
            status_code=500,
            detail="User creation failed (DB error)"
        )

    access_token = auth_utils.create_access_token(subject=user.user_id)
    raw_refresh, token_hash = auth_utils.generate_refresh_token_pair()

    expires_at = datetime.utcnow() + timedelta(days=30)
    await crud_auth.create_refresh_token(db, user.user_id, token_hash, expires_at)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": raw_refresh,
        "expires_at": expires_at.isoformat(),
        "user": {
            "user_id": user.user_id,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
        }
    }


@router.post("/login", response_model=schemas.TokenResponse)
async def login(payload: schemas.LoginRequest, db: AsyncSession = Depends(get_db)):
    user = await crud_auth.get_user_by_email(db, payload.email)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if not auth_utils.verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    access_token = auth_utils.create_access_token(subject=user.user_id)
    raw_refresh, token_hash = auth_utils.generate_refresh_token_pair()
    expires_at = datetime.utcnow() + timedelta(days=30)
    await crud_auth.create_refresh_token(db, user.user_id, token_hash, expires_at)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": raw_refresh,
        "expires_at": expires_at.isoformat(),
        "user": {
            "user_id": user.user_id,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
        }
    }


# app/routers/auth.py - Fix the refresh endpoint

@router.post("/refresh", response_model=schemas.TokenResponse)
async def refresh(req: schemas.RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hashlib.sha256(req.refresh_token.encode("utf-8")).hexdigest()
    rt = await crud_auth.get_refresh_token_by_hash(db, token_hash)

    if not rt:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    if rt.revoked:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token revoked")

    # FIX: Make both datetimes timezone-aware for comparison
    from datetime import timezone
    now_utc = datetime.now(timezone.utc)

    # If expires_at is naive, make it aware
    if rt.expires_at.tzinfo is None:
        expires_at = rt.expires_at.replace(tzinfo=timezone.utc)
    else:
        expires_at = rt.expires_at

    if expires_at < now_utc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token expired")

    access_token = auth_utils.create_access_token(subject=rt.user_id)
    user = await crud_auth.get_user_by_id(db, rt.user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": req.refresh_token,
        "expires_at": expires_at.isoformat(),
        "user": {
            "user_id": user.user_id,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
        } if user else None
    }

@router.post("/logout")
async def logout(req: schemas.RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hashlib.sha256(req.refresh_token.encode("utf-8")).hexdigest()
    rt = await crud_auth.get_refresh_token_by_hash(db, token_hash)
    if not rt:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid refresh token")
    await crud_auth.revoke_refresh_token(db, rt.token_id)
    return {"detail": "logged out"}


@router.get("/users/me")
async def get_current_user_info(current_user: User = Depends(auth_utils.get_current_user)):
    return {
        "user_id": current_user.user_id,
        "email": current_user.email,
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
    }
