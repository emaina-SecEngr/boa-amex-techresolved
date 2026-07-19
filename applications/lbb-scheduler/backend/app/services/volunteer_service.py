"""
Volunteer & Life Skills Class Service
"""

from sqlalchemy.orm import Session
from sqlalchemy.orm import joinedload

from app.models.user import User
from app.models.life_skills_class import VolunteerProfile, LifeSkillsClass
from app.schemas.volunteer import (
    VolunteerProfileCreate,
    VolunteerProfileUpdate,
    VolunteerProfileResponse,
    LifeSkillsClassCreate,
    LifeSkillsClassUpdate,
)

# Centralized error messages (resolves SonarQube python:S1192)
CLASS_NOT_FOUND = "Life skills class not found"
VOLUNTEER_PROFILE_NOT_FOUND = "Volunteer profile not found"
LEAD_VOLUNTEER_NOT_FOUND = "Lead volunteer not found"


def volunteer_profile_to_response(profile: VolunteerProfile) -> VolunteerProfileResponse:
    """Map ORM profile + linked User into API response."""
    u = profile.user
    return VolunteerProfileResponse(
        id=str(profile.id),
        user_id=str(profile.user_id),
        organization=profile.organization,
        bio=profile.bio,
        special_requirements=profile.special_requirements,
        background_check_status=profile.background_check_status,
        is_available=profile.is_available,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
        first_name=u.first_name if u else None,
        last_name=u.last_name if u else None,
        email=u.email if u else None,
    )


def create_volunteer_profile(
    db: Session, user_id: str, data: VolunteerProfileCreate
) -> VolunteerProfile:
    """Create a volunteer profile for a user."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError("User not found")
    if str(user.role).strip().lower() != "volunteer":
        raise ValueError("Only volunteers can have volunteer profiles")

    existing = db.query(VolunteerProfile).filter(
        VolunteerProfile.user_id == user_id
    ).first()
    if existing:
        raise ValueError("Volunteer profile already exists for this user")

    profile = VolunteerProfile(
        user_id=user_id,
        organization=data.organization,
        bio=data.bio,
        special_requirements=data.special_requirements,
        is_available=data.is_available,
        background_check_status=data.background_check_status,
    )

    db.add(profile)
    db.commit()
    db.refresh(profile)
    profile = (
        db.query(VolunteerProfile)
        .options(joinedload(VolunteerProfile.user))
        .filter(VolunteerProfile.id == profile.id)
        .first()
    )
    return profile


def get_volunteer_profile(db: Session, user_id: str) -> VolunteerProfile:
    """Get a volunteer's profile by their user ID (User relationship loaded)."""
    profile = (
        db.query(VolunteerProfile)
        .options(joinedload(VolunteerProfile.user))
        .filter(VolunteerProfile.user_id == user_id)
        .first()
    )
    if not profile:
        raise ValueError(VOLUNTEER_PROFILE_NOT_FOUND)
    return profile


def update_volunteer_profile(
    db: Session, user_id: str, data: VolunteerProfileUpdate
) -> VolunteerProfile:
    """Update a volunteer's profile. Only sent fields are changed."""
    profile = db.query(VolunteerProfile).filter(
        VolunteerProfile.user_id == user_id
    ).first()
    if not profile:
        raise ValueError(VOLUNTEER_PROFILE_NOT_FOUND)

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(profile, field, value)

    db.commit()
    db.refresh(profile)
    profile = (
        db.query(VolunteerProfile)
        .options(joinedload(VolunteerProfile.user))
        .filter(VolunteerProfile.id == profile.id)
        .first()
    )
    return profile


def list_available_volunteers(db: Session):
    """List all volunteers who are available."""
    return (
        db.query(VolunteerProfile)
        .join(VolunteerProfile.user)
        .options(joinedload(VolunteerProfile.user))
        .filter(
            VolunteerProfile.is_available.is_(True),
            User.role == "volunteer"
        )
        .all()
    )


def create_life_skills_class(
    db: Session, data: LifeSkillsClassCreate
) -> LifeSkillsClass:
    """Create a new life skills class in the catalog."""
    volunteer = db.query(User).filter(
        User.id == data.lead_volunteer_id
    ).first()
    if not volunteer:
        raise ValueError(LEAD_VOLUNTEER_NOT_FOUND)
    if volunteer.role != "volunteer":
        raise ValueError("Lead must have the volunteer role")

    existing = db.query(LifeSkillsClass).filter(
        LifeSkillsClass.class_name == data.class_name
    ).first()
    if existing:
        raise ValueError(f"Class '{data.class_name}' already exists")

    lsc = LifeSkillsClass(
        class_name=data.class_name,
        lead_volunteer_id=data.lead_volunteer_id,
        description=data.description,
        other_volunteers=data.other_volunteers,
        special_logistics=data.special_logistics,
        equipment_by_professional=data.equipment_by_professional,
        equipment_by_lbb=data.equipment_by_lbb,
        max_students=data.max_students,
        recommended_take_home_item=data.recommended_take_home_item,
        volunteer_take_home_item=data.volunteer_take_home_item,
        other_requirements=data.other_requirements,
    )

    db.add(lsc)
    db.commit()
    db.refresh(lsc)
    return lsc


def list_life_skills_classes(
    db: Session, lead_volunteer_id: str | None = None
) -> dict:
    """List life skills classes, optionally filtered to one lead volunteer."""
    query = db.query(LifeSkillsClass).order_by(LifeSkillsClass.class_name.asc())
    if lead_volunteer_id:
        query = query.filter(
            LifeSkillsClass.lead_volunteer_id == lead_volunteer_id
        )
    classes = query.all()
    return {"classes": classes, "total": len(classes)}


def get_life_skills_class(db: Session, class_id: str) -> LifeSkillsClass:
    """Get a single life skills class by ID."""
    lsc = db.query(LifeSkillsClass).filter(
        LifeSkillsClass.id == class_id
    ).first()
    if not lsc:
        raise ValueError(CLASS_NOT_FOUND)
    return lsc


def update_life_skills_class(
    db: Session, class_id: str, data: LifeSkillsClassUpdate
) -> LifeSkillsClass:
    """Partial update of a life skills class."""
    lsc = db.query(LifeSkillsClass).filter(
        LifeSkillsClass.id == class_id
    ).first()
    if not lsc:
        raise ValueError(CLASS_NOT_FOUND)

    update_data = data.model_dump(exclude_unset=True)

    if "lead_volunteer_id" in update_data:
        volunteer = db.query(User).filter(
            User.id == update_data["lead_volunteer_id"]
        ).first()
        if not volunteer:
            raise ValueError(LEAD_VOLUNTEER_NOT_FOUND)
        if volunteer.role != "volunteer":
            raise ValueError("Lead must have the volunteer role")

    for field, value in update_data.items():
        setattr(lsc, field, value)

    db.commit()
    db.refresh(lsc)
    return lsc


def delete_life_skills_class(db: Session, class_id: str) -> LifeSkillsClass:
    """Delete a life skills class from the catalog."""
    lsc = db.query(LifeSkillsClass).filter(
        LifeSkillsClass.id == class_id
    ).first()
    if not lsc:
        raise ValueError(CLASS_NOT_FOUND)

    name = lsc.class_name
    db.delete(lsc)
    db.commit()
    lsc.class_name = name
    return lsc
