"""LBB Card Auth — Database Connection"""
import databases
from app.config import settings

database = databases.Database(settings.DATABASE_URL)


async def init_db():
    """Initialize database connection and create tables"""
    await database.connect()
    await database.execute("""
        CREATE TABLE IF NOT EXISTS card_accounts (
            id SERIAL PRIMARY KEY,
            card_token VARCHAR(64) UNIQUE NOT NULL,
            card_status VARCHAR(20) DEFAULT 'ACTIVE',
            available_balance DECIMAL(12,2) DEFAULT 0.00,
            credit_limit DECIMAL(12,2) DEFAULT 5000.00,
            home_country VARCHAR(2) DEFAULT 'US',
            avg_transaction_amount DECIMAL(10,2) DEFAULT 50.00,
            transactions_last_hour INTEGER DEFAULT 0,
            last_transaction_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    await database.execute("""
        CREATE TABLE IF NOT EXISTS transaction_log (
            id SERIAL PRIMARY KEY,
            card_token VARCHAR(64) NOT NULL,
            amount DECIMAL(12,2) NOT NULL,
            currency VARCHAR(3) DEFAULT 'USD',
            merchant_id VARCHAR(50),
            merchant_category_code VARCHAR(4),
            country_code VARCHAR(2),
            status VARCHAR(20) NOT NULL,
            reason VARCHAR(100),
            source_ip VARCHAR(45),
            processing_time_ms DECIMAL(10,2),
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    await database.execute("""
        CREATE INDEX IF NOT EXISTS idx_transaction_log_token ON transaction_log(card_token);
    """)
    await database.execute("""
        CREATE INDEX IF NOT EXISTS idx_transaction_log_created ON transaction_log(created_at);
    """)


async def get_db():
    return database