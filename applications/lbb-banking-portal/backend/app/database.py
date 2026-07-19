import databases
from app.config import settings
database = databases.Database(settings.DATABASE_URL)
async def init_db():
    await database.connect()
    await database.execute("""
        CREATE TABLE IF NOT EXISTS customers (
            id SERIAL PRIMARY KEY, customer_id VARCHAR(20) UNIQUE NOT NULL,
            first_name VARCHAR(50), last_name VARCHAR(50), email VARCHAR(100),
            phone VARCHAR(20), mfa_enabled BOOLEAN DEFAULT TRUE,
            last_login TIMESTAMP, created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    await database.execute("""
        CREATE TABLE IF NOT EXISTS customer_accounts (
            id SERIAL PRIMARY KEY, account_number VARCHAR(20) UNIQUE NOT NULL,
            customer_id VARCHAR(20) NOT NULL, account_type VARCHAR(20) DEFAULT 'CHECKING',
            available_balance DECIMAL(12,2) DEFAULT 0.00, pending_balance DECIMAL(12,2) DEFAULT 0.00,
            currency VARCHAR(3) DEFAULT 'USD', status VARCHAR(20) DEFAULT 'ACTIVE',
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    await database.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            id SERIAL PRIMARY KEY, transaction_id VARCHAR(36) UNIQUE NOT NULL,
            account_number VARCHAR(20), customer_id VARCHAR(20), amount DECIMAL(12,2),
            currency VARCHAR(3) DEFAULT 'USD', description VARCHAR(255),
            category VARCHAR(50), transaction_type VARCHAR(20), status VARCHAR(20),
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    await database.execute("""
        CREATE TABLE IF NOT EXISTS statements (
            id SERIAL PRIMARY KEY, statement_id VARCHAR(20) UNIQUE NOT NULL,
            account_number VARCHAR(20), customer_id VARCHAR(20), period VARCHAR(7),
            download_url VARCHAR(255), generated_at TIMESTAMP DEFAULT NOW()
        )
    """)
async def get_db():
    return database
