"""LBB Card Auth — Configuration"""
import os


class Settings:
    ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
    DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://lbb_admin:password@localhost:5432/lbb_card_auth")
    API_KEY = os.environ.get("API_KEY", "dev-api-key-replace-in-production")
    TOKENIZATION_KEY = os.environ.get("TOKENIZATION_KEY", "dev-only-key")
    SAGEMAKER_FRAUD_ENDPOINT = os.environ.get("SAGEMAKER_FRAUD_ENDPOINT", "")
    ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "http://localhost:3000").split(",")
    LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")


settings = Settings()