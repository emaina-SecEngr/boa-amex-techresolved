"""
Alembic Environment Configuration
====================================
This file tells Alembic how to connect to the database and
which models to track for auto-generating migrations.

HOW MIGRATIONS WORK:
1. You make changes to your SQLAlchemy models (add a column, etc.)
2. Run: alembic revision --autogenerate -m "add column to users"
3. Alembic compares your models to the database and generates
   a migration script in migrations/versions/
4. Review the generated script (always review auto-generated code!)
5. Run: alembic upgrade head (applies the migration)
"""

from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

from app.core.config import settings
from app.core.database import Base

# ---------------------------------------------------------------
# Import ALL models here so Alembic can detect them
# If you add a new model file, import it here too!
# ---------------------------------------------------------------
from app.models.user import User
from app.models.school import School, SchoolPrincipal, PhotoRestriction
from app.models.event import (
    AcademicYear, LBBEvent, EventRegistration, VolunteerEventSignup
)
from app.models.life_skills_class import VolunteerProfile, LifeSkillsClass
from app.models.survey import VolunteerSurvey, StudentSurvey, SchoolSurvey
from app.models.donation import Donation


# Alembic Config object (reads alembic.ini)
config = context.config

# Set the database URL from our application settings
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# Setup logging from alembic.ini
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Tell Alembic which metadata to compare against the database
# This is how autogenerate knows what tables/columns should exist
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """
    Run migrations in 'offline' mode.
    Generates SQL script without connecting to the database.
    Useful for generating SQL that a DBA will apply manually.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """
    Run migrations in 'online' mode.
    Connects to the database and applies changes directly.
    This is the normal mode used during development.
    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )

        with context.begin_transaction():
            context.run_migrations()


# Determine which mode to run in
if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
