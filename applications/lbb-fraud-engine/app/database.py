import databases
from app.config import settings
database = databases.Database(settings.DATABASE_URL)
async def init_db():
    await database.connect()
    await database.execute("""
        CREATE TABLE IF NOT EXISTS scoring_log (
            id SERIAL PRIMARY KEY,
            scoring_id VARCHAR(36) UNIQUE NOT NULL,
            card_token VARCHAR(64),
            amount DECIMAL(12,2),
            merchant_id VARCHAR(50),
            merchant_category VARCHAR(4),
            country_code VARCHAR(2),
            fraud_score DECIMAL(5,2),
            recommendation VARCHAR(20),
            model_version VARCHAR(20),
            processing_time_ms DECIMAL(10,2),
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    await database.execute("""
        CREATE TABLE IF NOT EXISTS fraud_cases (
            id SERIAL PRIMARY KEY,
            case_id VARCHAR(20) UNIQUE NOT NULL,
            scoring_id VARCHAR(36),
            card_token VARCHAR(64),
            fraud_score DECIMAL(5,2),
            amount DECIMAL(12,2),
            merchant_id VARCHAR(50),
            factors TEXT,
            status VARCHAR(20) DEFAULT 'OPEN',
            assigned_analyst VARCHAR(50),
            notes TEXT,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        )
    """)
async def get_db():
    return database
