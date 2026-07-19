"""
Volunteer & Life Skills Class Routes
========================================
  GET    /api/v1/volunteers/profile              → Get my profile
  POST   /api/v1/volunteers/profile              → Create my profile
  PATCH  /api/v1/volunteers/profile              → Update my profile
  GET    /api/v1/volunteers/available             → List available volunteers

  POST   /api/v1/volunteers/classes               → Create class
  GET    /api/v1/volunteers/classes               → List all classes
  GET    /api/v1/volunteers/classes/{id}          → Get class details
  PATCH  /api/v1/volunteers/classes/{id}          → Update class
  DELETE /api/v1/volunteers/classes/{id}          → Delete class
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, require_roles
from app.models.user import User
from app.schemas.volunteer import (
    VolunteerProfileCreate,
    VolunteerProfileUpdate,
    VolunteerProfileResponse,
    LifeSkillsClassCreate,
    LifeSkillsClassUpdate,
    LifeSkillsClassResponse,
    LifeSkillsClassListResponse,
)
from app.schemas.auth import MessageResponse
from app.services.volunteer_service import (
    create_volunteer_profile,
    get_volunteer_profile,
    update_volunteer_profile,
    list_available_volunteers,
    volunteer_profile_to_response,
    create_life_skills_class,
    list_life_skills_classes,
    get_life_skills_class,
    update_life_skills_class,
    delete_life_skills_class,
)


router = APIRouter(prefix="/volunteers", tags=["Volunteers & Classes"])


# ===============================================================
# Volunteer Profile Endpoints
# ===============================================================

@router.post(
    "/profile",
    response_model=VolunteerProfileResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create my volunteer profile",
    description="Volunteer creates their own extended profile.",
)
def create_profile(
    data: VolunteerProfileCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["volunteer"])),
):
    try:
        profile = create_volunteer_profile(db, str(current_user.id), data)
        return volunteer_profile_to_response(profile)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "/profile",
    response_model=VolunteerProfileResponse,
    summary="Get my volunteer profile",
    description="Volunteer views their own profile.",
)
def get_my_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["volunteer"])),
):
    try:
        profile = get_volunteer_profile(db, str(current_user.id))
        return volunteer_profile_to_response(profile)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.patch(
    "/profile",
    response_model=VolunteerProfileResponse,
    summary="Update my volunteer profile",
    description="Volunteer updates their own profile.",
)
def update_my_profile(
    data: VolunteerProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["volunteer"])),
):
    try:
        profile = update_volunteer_profile(db, str(current_user.id), data)
        return volunteer_profile_to_response(profile)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.get(
    "/available",
    response_model=list[VolunteerProfileResponse],
    summary="List available volunteers",
    description="Returns all volunteers who are currently available.",
)
def get_available_volunteers(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "it_support"])),
):
    profiles = list_available_volunteers(db)
    return [volunteer_profile_to_response(p) for p in profiles]


# ===============================================================
# Life Skills Class Endpoints
# ===============================================================

@router.post(
    "/classes",
    response_model=LifeSkillsClassResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create life skills class",
    description="Add a new class to the catalog. (Admin only)",
)
def create_class(
    data: LifeSkillsClassCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        lsc = create_life_skills_class(db, data)
        return lsc
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "/classes",
    response_model=LifeSkillsClassListResponse,
    summary="List all classes",
    description=(
        "Returns the life skills class catalog. "
        "Use mine=true to list only classes where you are the lead volunteer."
    ),
)
def get_classes(
    mine: bool = Query(
        False,
        description="If true, only classes you lead (current user as lead volunteer)",
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lead_id = str(current_user.id) if mine else None
    return list_life_skills_classes(db, lead_volunteer_id=lead_id)


@router.get(
    "/classes/{class_id}",
    response_model=LifeSkillsClassResponse,
    summary="Get class details",
    description="Returns a single life skills class by ID.",
)
def get_class(
    class_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        lsc = get_life_skills_class(db, class_id)
        return lsc
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.patch(
    "/classes/{class_id}",
    response_model=LifeSkillsClassResponse,
    summary="Update class",
    description="Partial update of a life skills class. (Admin only)",
)
def patch_class(
    class_id: str,
    data: LifeSkillsClassUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        lsc = update_life_skills_class(db, class_id, data)
        return lsc
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.delete(
    "/classes/{class_id}",
    response_model=MessageResponse,
    summary="Delete class",
    description="Remove a class from the catalog. (Admin only)",
)
def remove_class(
    class_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        lsc = delete_life_skills_class(db, class_id)
        return MessageResponse(message=f"Class '{lsc.class_name}' deleted")
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
