from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    DATABASE_URL: str
    SQL_ECHO: bool = False
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = ""
    FRONTEND_URL: str = "http://localhost:8000"
    PASSWORD_RESET_TOKEN_EXPIRE_MINUTES: int = 60


    # AI Model Configuration
    AI_API_URL: str = "http://localhost:8002"
    AI_API_TIMEOUT: int = 30

    OPENAI_API_KEY: str = ""
    # Explicit opt-in: an existing legacy key does not enable external requests.
    LLM_PROVIDER: str = "disabled"
    LLM_BASE_URL: str = ""
    LLM_MODEL: str = ""
    LLM_API_KEY: str = ""
    LLM_TIMEOUT: float = 30.0

    # Cloudinary individual settings
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""
    CLOUDINARY_URL: Optional[str] = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    # Make SECRET_KEY accessible as alias for JWT_SECRET
    @property
    def SECRET_KEY(self) -> str:
        return self.JWT_SECRET


settings = Settings()
