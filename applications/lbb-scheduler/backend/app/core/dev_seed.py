"""
Development bootstrap: optional default admin user (admin / admin123).

Used by FastAPI startup when SEED_DEV_ADMIN is enabled, and by create_dev_admin.py.
Do not enable in production.
"""

import logging
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.user import User

logger = logging.getLogger(__name__)


def ensure_dev_admin_user(db: Session) -> str:
    """
    Create admin@lifebeyondthebooksaz.org with username 'admin' if missing.

    Returns a short status message for logs or CLI.
    """
    if db.query(User).filter(User.username == "admin").first():
        return "dev admin user already present (admin)"

    user = User(
        username="admin",
        email="admin@lifebeyondthebooksaz.org",
        password_hash=hash_password("admin123"),
        security_question_1="Bootstrap",
        security_answer_1=hash_password("bootstrap"),
        security_question_2="Bootstrap",
        security_answer_2=hash_password("bootstrap"),
        first_name="School",
        last_name="Administrator",
        phone_number="0000000000",
        role="lbb_admin",
        affiliation="Life Beyond the Books",
        is_active=True,
    )
    db.add(user)
    db.commit()
    return "created dev admin user (admin / admin123, lbb_admin)"
