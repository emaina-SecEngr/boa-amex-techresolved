"""
User Management Routes
============================================
  GET    /api/v1/users/me                -> Get my profile (any user)
  PATCH  /api/v1/users/me                -> Update my profile (any user)
  POST   /api/v1/users/me/change-password -> Change my password (any user)
  GET    /api/v1/users                   -> List all users (admin)
  GET    /api/v1/users/{id}              -> Get single user (admin)
  PATCH  /api/v1/users/{id}              -> Update user fields (admin)
  DELETE /api/v1/users/{id}              -> Deactivate user (admin)
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, require_roles, hash_password, verify_password
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate, UserListResponse
from app.schemas.auth import MessageResponse
from app.services.user_service import (
    list_users,
    get_user_by_id,
    update_user,
    deactivate_user,
)


router = APIRouter(prefix="/users", tags=["User Management"])


# ---------------------------------------------------------------
# GET /users/me — Get my own profile (any authenticated user)
# MUST be before /{user_id} to avoid "me" being parsed as a UUID
# ---------------------------------------------------------------
@router.get("/me", summary="Get my profile")
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the currently logged-in user's profile."""
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": str(user.id),
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "phone_number": user.phone_number,
        "email": user.email,
        "role": user.role,
        "affiliation": user.affiliation,
        "is_active": user.is_active,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "updated_at": user.updated_at.isoformat() if user.updated_at else None,
    }


# ---------------------------------------------------------------
# PATCH /users/me — Update my own profile (any authenticated user)
# ---------------------------------------------------------------
@router.patch("/me", summary="Update my profile")
async def update_my_profile(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the currently logged-in user's personal information."""
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    allowed_fields = [
        "first_name", "last_name", "phone_number", "email", "affiliation",
    ]
    for field in allowed_fields:
        if field in data:
            setattr(user, field, data[field])

    db.commit()
    db.refresh(user)
    return {
        "id": str(user.id),
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "phone_number": user.phone_number,
        "email": user.email,
        "role": user.role,
        "affiliation": user.affiliation,
        "is_active": user.is_active,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "updated_at": user.updated_at.isoformat() if user.updated_at else None,
    }


# ---------------------------------------------------------------
# POST /users/me/change-password — Change my password
# ---------------------------------------------------------------
@router.post("/me/change-password", summary="Change my password")
async def change_my_password(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change the currently logged-in user's password."""
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    current_password = data.get("current_password", "")
    new_password = data.get("new_password", "")

    if not current_password or not new_password:
        raise HTTPException(
            status_code=400,
            detail="Both current and new passwords required",
        )
    if not verify_password(current_password, user.password_hash):
        raise HTTPException(
            status_code=400,
            detail="Current password is incorrect",
        )
    if len(new_password) < 8:
        raise HTTPException(
            status_code=400,
            detail="Password must be at least 8 characters",
        )

    user.password_hash = hash_password(new_password)
    db.commit()
    return {"message": "Password changed successfully"}


# ---------------------------------------------------------------
# GET /users — List all users (admin only)
# ---------------------------------------------------------------
@router.get(
    "",
    response_model=UserListResponse,
    summary="List all users",
    description="Paginated user list with optional filters. Admin only.",
)
def get_users(
    page: int = Query(default=1, ge=1, description="Page number"),
    per_page: int = Query(default=20, ge=1, le=100, description="Results per page"),
    role: str = Query(default=None, description="Filter by role"),
    is_active: bool = Query(default=None, description="Filter by active status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "it_support"])),
):
    result = list_users(db, page=page, per_page=per_page, role=role, is_active=is_active)
    return result


# ---------------------------------------------------------------
# GET /users/{user_id} — Get single user (admin only)
# ---------------------------------------------------------------
@router.get(
    "/{user_id}",
    response_model=UserResponse,
    summary="Get user by ID",
    description="Returns full user profile. Admin only.",
)
def get_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "it_support"])),
):
    try:
        user = get_user_by_id(db, user_id)
        return user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


# ---------------------------------------------------------------
# PATCH /users/{user_id} — Update user (admin only)
# ---------------------------------------------------------------
@router.patch(
    "/{user_id}",
    response_model=UserResponse,
    summary="Update user",
    description="Partial update — only send fields you want to change. Admin only.",
)
def patch_user(
    user_id: str,
    data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "it_support"])),
):
    try:
        user = update_user(db, user_id, data)
        return user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


# ---------------------------------------------------------------
# DELETE /users/{user_id} — Deactivate user (admin only)
# ---------------------------------------------------------------
@router.delete(
    "/{user_id}",
    response_model=MessageResponse,
    summary="Deactivate user",
    description="Soft-deletes a user (sets is_active=False). Data is preserved.",
)
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "it_support"])),
):
    try:
        user = deactivate_user(db, user_id)
        return MessageResponse(
            message=f"User '{user.username}' has been deactivated",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
