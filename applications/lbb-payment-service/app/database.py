"""LBB Payment Service — Database"""
import databases
from app.config import settings

database = databases.Database(settings.DATABASE_URL)

async def init_db():
    await database.connect()
    await database.execute("""
        CREATE TABLE IF NOT EXISTS accounts (
            id SERIAL PRIMARY KEY,
            account_number VARCHAR(20) UNIQUE NOT NULL,
            account_holder VARCHAR(100) NOT NULL,
            account_type VARCHAR(20) DEFAULT 'CHECKING',
            available_balance DECIMAL(12,2) DEFAULT 0.00,
            status VARCHAR(20) DEFAULT 'ACTIVE',
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    await database.execute("""
        CREATE TABLE IF NOT EXISTS payment_log (
            id SERIAL PRIMARY KEY,
            transaction_id VARCHAR(36) UNIQUE NOT NULL,
            sender_account VARCHAR(20),
            receiver_account VARCHAR(20),
            amount DECIMAL(12,2) NOT NULL,
            currency VARCHAR(3) DEFAULT 'USD',
            status VARCHAR(20) NOT NULL,
            reason VARCHAR(255),
            transaction_type VARCHAR(20),
            memo VARCHAR(255),
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)

async def get_db():
    return database
