import databases
from app.config import settings
database = databases.Database(settings.DATABASE_URL)
async def init_db():
    await database.connect()
    await database.execute("""
        CREATE TABLE IF NOT EXISTS dashboard_snapshots (
            id SERIAL PRIMARY KEY, dashboard_type VARCHAR(30),
            snapshot_data TEXT, created_at TIMESTAMP DEFAULT NOW()
        )
    """)
async def get_db():
    return database
