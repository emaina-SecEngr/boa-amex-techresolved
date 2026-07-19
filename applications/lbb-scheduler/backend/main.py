"""
LBBS Application Entry Point
===============================
To run:
    uvicorn main:app --reload --port 8000
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import Base, SessionLocal, apply_schema_patches, engine
from app.core.dev_seed import ensure_dev_admin_user

# Import all models so SQLAlchemy discovers them and creates tables
from app.models.user import User  # noqa: F401
from app.models.school import School, SchoolPrincipal, PhotoRestriction  # noqa: F401
from app.models.event import (  # noqa: F401
    AcademicYear, LBBEvent, EventRegistration, VolunteerEventSignup,
)
from app.models.life_skills_class import VolunteerProfile, LifeSkillsClass  # noqa: F401
from app.models.survey import VolunteerSurvey, StudentSurvey, SchoolSurvey  # noqa: F401
from app.models.donation import Donation  # noqa: F401

# Import route handlers
from app.routes.auth import router as auth_router
from app.routes.users import router as users_router
from app.routes.scheduler_routes import router as scheduler_router
from app.routes.events import router as events_router
from app.routes.schools import router as schools_router
from app.routes.volunteers import router as volunteers_router
from app.routes.donations import router as donations_router
from app.routes.surveys import router as surveys_router
from app.routes.reports import router as reports_router
from app.routes.sso import router as sso_router
from app.routes.scim import router as scim_router
from app.routes.cyberark import router as cyberark_router
from app.routes.community import router as community_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Life Beyond the Books Scheduler...")
    logger.info(f"Environment: {settings.APP_ENV}")
    logger.info(f"Database: {settings.DATABASE_URL[:50]}...")

    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created/verified")
    apply_schema_patches()

    if settings.SEED_DEV_ADMIN and settings.APP_ENV == "development":
        db = SessionLocal()
        try:
            msg = ensure_dev_admin_user(db)
            logger.info("Dev seed: %s", msg)
        except Exception:
            logger.exception("Dev admin seed failed")
        finally:
            db.close()

    # Start the background scheduler
    try:
        from app.scheduler.engine import start_scheduler
        start_scheduler()
    except Exception as e:
        logger.warning(f"Scheduler start failed: {e}")

    logger.info(f"API docs available at: http://localhost:{settings.PORT}/docs")

    yield

    # Stop the scheduler on shutdown
    try:
        from app.scheduler.engine import stop_scheduler
        stop_scheduler()
    except Exception:
        pass

    logger.info("Shutting down LBBS...")


app = FastAPI(
    title=settings.APP_NAME,
    description="Scheduling application for Life Beyond the Books, "
                "a Tucson-based non-profit that pairs community professionals "
                "with 8th grade students for experiential life skills classes.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register Route Handlers
app.include_router(auth_router, prefix="/api/v1")
app.include_router(users_router, prefix="/api/v1")
app.include_router(events_router, prefix="/api/v1")
app.include_router(schools_router, prefix="/api/v1")
app.include_router(volunteers_router, prefix="/api/v1")
app.include_router(donations_router, prefix="/api/v1")
app.include_router(surveys_router, prefix="/api/v1")
app.include_router(reports_router, prefix="/api/v1")
app.include_router(sso_router)
app.include_router(scim_router)
app.include_router(community_router, prefix="/api/v1")
app.include_router(cyberark_router, prefix="/api/v1")
app.include_router(scheduler_router, prefix="/api/v1")


@app.get("/", tags=["Status"])
def root():
    return {
        "message": f"Welcome to {settings.APP_NAME}",
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/health", tags=["Status"])
def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "environment": settings.APP_ENV,
        "database": "connected",
    }
