"""
School Management Routes — API Endpoints
============================================
CRUD for schools, principals, and photo restrictions.

  GET    /api/v1/schools                          → List schools
  POST   /api/v1/schools                          → Create school
  GET    /api/v1/schools/{id}                     → Get school details
  PATCH  /api/v1/schools/{id}                     → Update school
  DELETE /api/v1/schools/{id}                     → Delete school
  POST   /api/v1/schools/{id}/principals          → Add principal
  DELETE /api/v1/schools/{id}/principals/{pid}    → Remove principal
  POST   /api/v1/schools/{id}/photo-restrictions  → Add restriction
  DELETE /api/v1/schools/{id}/photo-restrictions/{rid} → Remove restriction
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, require_roles
from app.models.user import User
from app.schemas.school import (
    SchoolCreate,
    SchoolUpdate,
    SchoolResponse,
    SchoolListResponse,
    PrincipalCreate,
    PrincipalResponse,
    PhotoRestrictionCreate,
    PhotoRestrictionResponse,
)
from app.schemas.auth import MessageResponse
from app.services.school_service import (
    create_school,
    list_schools,
    get_school_by_id,
    update_school,
    delete_school,
    add_principal,
    remove_principal,
    add_photo_restriction,
    remove_photo_restriction,
)


router = APIRouter(prefix="/schools", tags=["School Management"])


# ===============================================================
# School CRUD
# ===============================================================

@router.post(
    "",
    response_model=SchoolResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create school",
    description="Register a new school. (Admin only)",
)
def create_new_school(
    data: SchoolCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        school = create_school(db, data)
        return school
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "",
    response_model=SchoolListResponse,
    summary="List schools",
    description="List all schools with optional district filter.",
)
def get_schools(
    district: str = Query(default=None, description="Filter by district"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role == "school_admin":
        return list_schools(db, school_admin_user_id=str(current_user.id))
    return list_schools(db, district=district)


@router.get(
    "/{school_id}",
    response_model=SchoolResponse,
    summary="Get school details",
    description="Returns school with principals and photo restrictions.",
)
def get_school(
    school_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        school = get_school_by_id(db, school_id)
        return school
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.patch(
    "/{school_id}",
    response_model=SchoolResponse,
    summary="Update school",
    description="Partial update of school fields. (Admin or School Admin)",
)
def patch_school(
    school_id: str,
    data: SchoolUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        school = update_school(db, school_id, data)
        return school
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.delete(
    "/{school_id}",
    response_model=MessageResponse,
    summary="Delete school",
    description="Permanently removes school and all related data. (Admin only)",
)
def remove_school(
    school_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        school = delete_school(db, school_id)
        return MessageResponse(message=f"School '{school.school_name}' deleted")
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


# ===============================================================
# Principal Management
# ===============================================================

@router.post(
    "/{school_id}/principals",
    response_model=PrincipalResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add principal",
    description="Add a principal to a school.",
)
def create_principal(
    school_id: str,
    data: PrincipalCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        principal = add_principal(db, school_id, data)
        return principal
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.delete(
    "/{school_id}/principals/{principal_id}",
    response_model=MessageResponse,
    summary="Remove principal",
    description="Remove a principal from a school.",
)
def delete_principal(
    school_id: str,
    principal_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        remove_principal(db, principal_id)
        return MessageResponse(message="Principal removed")
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


# ===============================================================
# Photo Restrictions
# ===============================================================

@router.post(
    "/{school_id}/photo-restrictions",
    response_model=PhotoRestrictionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add photo restriction",
    description="Add a student to the no-photo list for this school.",
)
def create_photo_restriction(
    school_id: str,
    data: PhotoRestrictionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        restriction = add_photo_restriction(db, school_id, data)
        return restriction
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.delete(
    "/{school_id}/photo-restrictions/{restriction_id}",
    response_model=MessageResponse,
    summary="Remove photo restriction",
    description="Remove a student from the no-photo list.",
)
def delete_photo_restriction(
    school_id: str,
    restriction_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        remove_photo_restriction(db, restriction_id)
        return MessageResponse(message="Photo restriction removed")
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
