import os
class Settings:
    ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
    DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://lbb_admin:password@localhost:5432/lbb_fraud")
    API_KEY = os.environ.get("API_KEY", "dev-api-key")
    SAGEMAKER_ENDPOINT = os.environ.get("SAGEMAKER_ENDPOINT", "")
settings = Settings()
