"""
LBBS Database Configuration
=============================
Sets up the SQLAlchemy engine, session factory, and base class
for all ORM models.
"""

import uuid as uuid_pkg
import logging

from sqlalchemy import String, create_engine, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy.types import TypeDecorator

from app.core.config import settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------
# Cross-Database UUID Type
# ---------------------------------------------------------------
# PostgreSQL has a native UUID column type, but SQLite doesn't.
# This custom type stores UUIDs as 36-character strings (works
# everywhere) but converts them to Python UUID objects automatically.
class GUID(TypeDecorator):
    """Platform-independent UUID type.
    Uses String(36) for storage, works on both PostgreSQL and SQLite.
    """
    impl = String(36)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        """Convert UUID to string before saving to database."""
        if value is not None:
            return str(value)

    def process_result_value(self, value, dialect):
        """Convert string back to UUID when reading from database."""
        if value is not None:
            return uuid_pkg.UUID(value)


# ---------------------------------------------------------------
# Database Engine
# ---------------------------------------------------------------
connect_args = {}
if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    echo=settings.DEBUG,
    connect_args=connect_args,
)


def apply_schema_patches() -> None:
    """
    `Base.metadata.create_all()` does not ALTER existing tables. Dev DBs
    created before a new column was added will error on ORM queries until
    the column exists. Patch known additive columns for PostgreSQL.
    """
    if not settings.DATABASE_URL.startswith("postgresql"):
        return
    try:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE volunteer_profiles ADD COLUMN IF NOT EXISTS "
                    "background_check_status VARCHAR(32)"
                )
            )
        logger.info("Schema patch: volunteer_profiles.background_check_status OK")
    except Exception:
        logger.exception("Schema patch for volunteer_profiles failed")


# ---------------------------------------------------------------
# Session Factory
# ---------------------------------------------------------------
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


# ---------------------------------------------------------------
# Declarative Base
# ---------------------------------------------------------------
class Base(DeclarativeBase):
    pass


# ---------------------------------------------------------------
# Dependency Injection for FastAPI
# ---------------------------------------------------------------
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
