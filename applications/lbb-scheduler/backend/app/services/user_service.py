"""
User Service — CRUD Business Logic
"""

from sqlalchemy.orm import Session

from app.models.user import User
from app.schemas.user import UserUpdate

# Centralized error messages (resolves SonarQube python:S1192)
USER_NOT_FOUND = "User not found"


def list_users(
    db: Session,
    page: int = 1,
    per_page: int = 20,
    role: str = None,
    is_active: bool = None,
) -> dict:
    """Get a paginated list of users with optional filters."""
    query = db.query(User)

    if role:
        query = query.filter(User.role == role)
    if is_active is not None:
        query = query.filter(User.is_active == is_active)

    total = query.count()

    offset = (page - 1) * per_page
    users = query.order_by(User.created_at.desc()).offset(offset).limit(per_page).all()

    return {
        "users": users,
        "total": total,
        "page": page,
        "per_page": per_page,
    }


def get_user_by_id(db: Session, user_id: str) -> User:
    """Look up a single user by their UUID."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError(USER_NOT_FOUND)
    return user


def update_user(db: Session, user_id: str, data: UserUpdate) -> User:
    """Update specific fields on a user account."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError(USER_NOT_FOUND)

    update_data = data.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        setattr(user, field, value)

    db.commit()
    db.refresh(user)

    return user


def deactivate_user(db: Session, user_id: str) -> User:
    """Soft-delete a user by setting is_active=False."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError(USER_NOT_FOUND)

    user.is_active = False
    db.commit()
    db.refresh(user)

    return user
