"""
LBBS Application Configuration
================================
Loads all configuration from environment variables (.env file).
Uses Pydantic Settings for validation — if a required variable
is missing, the app won't start (fail-fast principle).

Usage:
    from app.core.config import settings
    print(settings.DATABASE_URL)
"""

from pydantic import (
    EmailStr,
    computed_field,
    model_validator,
)
from pydantic_settings import BaseSettings
from typing import List
from typing_extensions import Self


class Settings(BaseSettings):
    """
    Central configuration class.
    All values are loaded from environment variables or .env file.
    """

    # --- Application ---
    APP_NAME: str = "Life Beyond the Books Scheduler"
    APP_ENV: str = "development"  # development | staging | production
    DEBUG: bool = True

    # When True with APP_ENV=development, create admin/admin123 on startup if missing.
    # Docker Compose sets this for local dev. Keep False for production and for tests.
    SEED_DEV_ADMIN: bool = False

    # --- Database ---
    # Format: postgresql://user:password@host:port/dbname
    DATABASE_URL: str = "postgresql://lbbs_user:password@localhost:5432/lbbs_db"

    # --- JWT Authentication ---
    SECRET_KEY: str = "change-this-to-a-random-secret-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # --- CORS (Cross-Origin Resource Sharing) ---
    # Allows the React frontend to call the FastAPI backend
    ALLOWED_ORIGINS: str = "http://localhost:5173,http://localhost:3000"
    FRONTEND_HOST: str = "http://localhost:5173"

    @property
    def cors_origins(self) -> List[str]:
        """Parse comma-separated CORS origins into a list."""
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]

    # --- Email (SendGrid) ---
    SENDGRID_API_KEY: str = ""
    EMAIL_FROM: str = "noreply@lifebeyondthebooksaz.org"
    EMAIL_FROM_NAME: str = "Life Beyond the Books"

    # --- Email (Local MailCatcher configuration) ---
    SMTP_TLS: bool = True
    SMTP_SSL: bool = False
    SMTP_PORT: int = 587
    SMTP_HOST: str | None = None
    SMTP_USER: str | None = None
    SMTP_PASSWORD: str | None = None

    @model_validator(mode="after")
    def _set_default_emails_from(self) -> Self:
        if not self.EMAIL_FROM_NAME:
            self.EMAIL_FROM_NAME = self.APP_NAME
        return self

    EMAIL_RESET_TOKEN_EXPIRE_HOURS: int = 48

    # When True, send POC confirmation after LBB admin creates a school record (Req 6.5.12).
    # Set False in tests or if you only want event-registration emails.
    EMAIL_SCHOOL_CREATE_CONFIRMATION: bool = True

    @computed_field  # type: ignore[prop-decorator]
    @property
    def emails_enabled(self) -> bool:
        return bool(self.SMTP_HOST and self.EMAIL_FROM)

    EMAIL_TEST_USER: EmailStr = "test@example.com"

    # --- Admin Defaults ---
    ADMIN_DEFAULT_EMAIL: str = "admin@lifebeyondthebooksaz.org"
    ADMIN_DEFAULT_PASSWORD: str = "change-this-immediately"

    # --- Server ---
    PORT: int = 8000

    class Config:
        # Tell Pydantic to read from .env file
        env_file = ".env"
        env_file_encoding = "utf-8"
        # Allow extra fields in .env without raising errors
        extra = "ignore"


# ---------------------------------------------------------------
# Singleton instance — import this everywhere in the application
# ---------------------------------------------------------------
settings = Settings()
