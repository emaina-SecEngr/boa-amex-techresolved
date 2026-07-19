import databases
from app.config import settings
database = databases.Database(settings.DATABASE_URL)
async def init_db():
    await database.connect()
    await database.execute("""
        CREATE TABLE IF NOT EXISTS report_log (
            id SERIAL PRIMARY KEY, report_id VARCHAR(20) UNIQUE NOT NULL,
            report_type VARCHAR(30), period VARCHAR(20), status VARCHAR(20),
            requested_by VARCHAR(50), report_data TEXT, error TEXT,
            created_at TIMESTAMP DEFAULT NOW(), completed_at TIMESTAMP
        )
    """)
    await database.execute("""
        CREATE TABLE IF NOT EXISTS ctr_filings (
            id SERIAL PRIMARY KEY, filing_id VARCHAR(20) UNIQUE NOT NULL,
            transaction_amount DECIMAL(12,2), filing_date DATE,
            filer_name VARCHAR(100), subject_name VARCHAR(100),
            status VARCHAR(20) DEFAULT 'FILED', created_at TIMESTAMP DEFAULT NOW()
        )
    """)
async def get_db():
    return database
