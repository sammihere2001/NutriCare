from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
import hashlib, uuid
from sqlalchemy import select
from .config import settings
from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models import User
from sqlalchemy.future import select

# Use JWT_SECRET consistently (SECRET_KEY is now an alias)
ALGORITHM = settings.JWT_ALGORITHM

security = HTTPBearer(auto_error=False)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=True)
auth_scheme = HTTPBearer()

pwd_context = CryptContext(schemes=["argon2", "bcrypt"], deprecated="auto")

# ======================================
# User Auth Utils
# ======================================

def hash_password(password: str) -> str:
    """Hash password with the default scheme (argon2)."""
    if pwd_context.default_scheme() == "bcrypt":
        truncated = password.encode("utf-8")[:72]
        return pwd_context.hash(truncated)
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        if hashed_password.startswith("$2a$") or hashed_password.startswith("$2b$"):
            truncated = plain_password.encode("utf-8")[:72]
            return pwd_context.verify(truncated, hashed_password)
        return pwd_context.verify(plain_password, hashed_password)
    except Exception as e:
        print("Password verify error:", e)
        return False

def create_access_token(subject: str | int, expires_minutes: int | None = None) -> str:
    now = datetime.utcnow()
    if expires_minutes is None:
        expires_minutes = settings.ACCESS_TOKEN_EXPIRE_MINUTES
    expire = now + timedelta(minutes=expires_minutes)
    payload = {"sub": str(subject), "iat": now, "exp": expire}
    token = jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    return token

def generate_refresh_token_pair():
    raw = str(uuid.uuid4())
    token_hash = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    return raw, token_hash


async def get_current_user(
        credentials: HTTPAuthorizationCredentials | None = Depends(security),
        db: AsyncSession = Depends(get_db)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if credentials is None:
        raise credentials_exception

    try:
        token = credentials.credentials
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        user_id = int(payload["sub"])
        if user_id <= 0:
            raise credentials_exception
    except (JWTError, ValueError, TypeError, KeyError):
        raise credentials_exception from None

    # Import here because crud_auth also uses the password hashing helpers.
    from app import crud_auth
    user = await crud_auth.get_user_by_id(db, user_id)
    if user is None or not user.is_active:
        raise credentials_exception
    return user

# ======================================
# Reset Pass Utils
# ======================================
def generate_password_reset_token() -> tuple[str, str]:
    """Generate a raw token and its hash for password reset"""
    raw_token = str(uuid.uuid4())
    token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
    return raw_token, token_hash

def get_password_reset_expiry() -> datetime:
    """Get expiry time for password reset token"""
    return datetime.utcnow() + timedelta(minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES)
