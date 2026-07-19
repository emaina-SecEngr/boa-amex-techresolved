"""LBB Payment Service — Configuration"""
import os

class Settings:
    ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
    DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://lbb_admin:password@localhost:5432/lbb_payments")
    API_KEY = os.environ.get("API_KEY", "dev-api-key")
    ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "http://localhost:3000").split(",")

settings = Settings()
