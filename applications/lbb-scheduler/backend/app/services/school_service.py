"""
School Service — School Management Business Logic
=====================================================
Handles all school-related operations:
  - School CRUD (create, list, get, update, delete)
  - Principal management (add, remove)
  - Photo restrictions (add, remove)

ConOps references:
  5.2: School entity with district, address, POC
  6.5.10: Admin manages school records
  6.6.3: School admin manages their own school
"""

import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.models.school import School, SchoolPrincipal, PhotoRestriction
from app.schemas.school import (
    PrincipalCreate,
    PhotoRestrictionCreate,
    SchoolCreate,
    SchoolUpdate,
)
from app.utils.email import notify_school_record_created_email

# Centralized error messages (SonarQube python:S1192)
SCHOOL_NOT_FOUND = "School not found"

logger = logging.getLogger(__name__)

# ===============================================================
# School CRUD
# ===============================================================


def create_school(db: Session, data: SchoolCreate) -> School:
    """Create a new school record."""
    # Check for duplicate school name
    existing = db.query(School).filter(
        School.school_name == data.school_name
    ).first()
    if existing:
        raise ValueError(f"School '{data.school_name}' already exists")

    school = School(
        school_name=data.school_name,
        school_district=data.school_district,
        school_address=data.school_address,
        poc_name=data.poc_name,
        poc_phone=data.poc_phone,
        poc_email=data.poc_email,
        comments=data.comments,
        admin_user_id=data.admin_user_id,
    )

    db.add(school)
    db.commit()
    db.refresh(school)

    if settings.EMAIL_SCHOOL_CREATE_CONFIRMATION and school.poc_email:
        try:
            notify_school_record_created_email(
                poc_email=school.poc_email,
                school_name=school.school_name,
                poc_name=school.poc_name,
                registered_at=datetime.now(timezone.utc),
                frontend_base_url=settings.FRONTEND_HOST,
            )
        except Exception:
            logger.exception(
                "School create confirmation email failed; school record was saved"
            )

    return school


def list_schools(
    db: Session,
    district: str = None,
    school_admin_user_id: str = None,
) -> dict:
    """
    List schools. Optional district filter (admin).
    If school_admin_user_id is set, only that user's assigned school is returned.
    """
    query = db.query(School).options(
        selectinload(School.principals),
        selectinload(School.photo_restrictions),
    )

    if school_admin_user_id:
        query = query.filter(School.admin_user_id == school_admin_user_id)
    elif district:
        query = query.filter(School.school_district == district)

    schools = query.order_by(School.school_name.asc()).all()
    return {"schools": schools, "total": len(schools)}


def get_school_by_id(db: Session, school_id: str) -> School:
    """Get a single school with principals and photo restrictions."""
    school = db.query(School).filter(School.id == school_id).first()
    if not school:
        raise ValueError(SCHOOL_NOT_FOUND)
    return school


def update_school(db: Session, school_id: str, data: SchoolUpdate) -> School:
    """Partial update of school fields."""
    school = db.query(School).filter(School.id == school_id).first()
    if not school:
        raise ValueError(SCHOOL_NOT_FOUND)

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(school, field, value)

    db.commit()
    db.refresh(school)
    return school


def delete_school(db: Session, school_id: str) -> School:
    """
    Delete a school record.
    CASCADE delete will remove principals, photo restrictions,
    and event registrations tied to this school.
    """
    school = db.query(School).filter(School.id == school_id).first()
    if not school:
        raise ValueError(SCHOOL_NOT_FOUND)

    db.delete(school)
    db.commit()
    return school


# ===============================================================
# Principal Management
# ===============================================================

def add_principal(
    db: Session, school_id: str, data: PrincipalCreate
) -> SchoolPrincipal:
    """Add a principal to a school."""
    # Verify school exists
    school = db.query(School).filter(School.id == school_id).first()
    if not school:
        raise ValueError(SCHOOL_NOT_FOUND)

    principal = SchoolPrincipal(
        school_id=school_id,
        name=data.name,
        title=data.title,
    )

    db.add(principal)
    db.commit()
    db.refresh(principal)
    return principal


def remove_principal(db: Session, principal_id: str) -> None:
    """Remove a principal record."""
    principal = db.query(SchoolPrincipal).filter(
        SchoolPrincipal.id == principal_id
    ).first()
    if not principal:
        raise ValueError("Principal not found")

    db.delete(principal)
    db.commit()


# ===============================================================
# Photo Restrictions
# ===============================================================

def add_photo_restriction(
    db: Session, school_id: str, data: PhotoRestrictionCreate
) -> PhotoRestriction:
    """
    Add a student to the no-photo list.
    These students cannot be photographed during LBB events.
    """
    school = db.query(School).filter(School.id == school_id).first()
    if not school:
        raise ValueError(SCHOOL_NOT_FOUND)

    restriction = PhotoRestriction(
        school_id=school_id,
        student_name=data.student_name,
        class_assignment=data.class_assignment,
        academic_year_id=data.academic_year_id,
    )

    db.add(restriction)
    db.commit()
    db.refresh(restriction)
    return restriction


def remove_photo_restriction(db: Session, restriction_id: str) -> None:
    """Remove a student from the no-photo list."""
    restriction = db.query(PhotoRestriction).filter(
        PhotoRestriction.id == restriction_id
    ).first()
    if not restriction:
        raise ValueError("Photo restriction not found")

    db.delete(restriction)
    db.commit()
