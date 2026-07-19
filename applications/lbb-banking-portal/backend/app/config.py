import os
class Settings:
    ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
    DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://lbb_admin:password@localhost:5432/lbb_portal")
    JWT_SECRET = os.environ.get("JWT_SECRET", "dev-jwt-secret")
    PAYMENT_SERVICE_URL = os.environ.get("PAYMENT_SERVICE_URL", "http://localhost:8002")
    INTERNAL_API_KEY = os.environ.get("INTERNAL_API_KEY", "dev-internal-key")
    ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "http://localhost:3000").split(",")
settings = Settings()
