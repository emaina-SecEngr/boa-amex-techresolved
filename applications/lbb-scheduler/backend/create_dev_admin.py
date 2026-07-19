"""
One-off: create the README dev admin (admin / admin123) if missing.
Same logic as automatic startup seed when SEED_DEV_ADMIN=true.

Run inside the backend container from /app:

  docker compose exec backend python create_dev_admin.py
"""

from app.core.database import SessionLocal
from app.core.dev_seed import ensure_dev_admin_user

# Import related models so SQLAlchemy can resolve User relationships (same as main.py)
from app.models.school import School, SchoolPrincipal, PhotoRestriction  # noqa: F401
from app.models.event import (  # noqa: F401
    AcademicYear,
    LBBEvent,
    EventRegistration,
    VolunteerEventSignup,
)
from app.models.life_skills_class import VolunteerProfile, LifeSkillsClass  # noqa: F401
from app.models.survey import VolunteerSurvey, StudentSurvey, SchoolSurvey  # noqa: F401
from app.models.donation import Donation  # noqa: F401


def main() -> None:
    db = SessionLocal()
    try:
        print(ensure_dev_admin_user(db))
    finally:
        db.close()


if __name__ == "__main__":
    main()
