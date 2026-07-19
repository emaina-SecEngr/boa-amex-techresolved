"""
User Schemas — CRUD Operations
=================================
These schemas handle user management endpoints:
  GET    /users         → List[UserResponse]
  GET    /users/{id}    → UserResponse
  PATCH  /users/{id}    → UserUpdate (in) → UserResponse (out)
  DELETE /users/{id}    → MessageResponse
Separate schemas for different operations ensure:
- Admins can update roles but not passwords through this endpoint
- Responses never include password hashes
- Optional fields in updates don't require sending unchanged data
"""
from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
from datetime import datetime
from uuid import UUID


# ---------------------------------------------------------------
# User Response — What the API returns
# ---------------------------------------------------------------
class UserResponse(BaseModel):
    """
    Full user profile returned by GET endpoints.
    Notice what's MISSING: password_hash, security answers,
    totp_secret. These are intentionally excluded.
    This is why schemas exist separately from models — the
    model has all fields for the database, the schema only
    exposes what's safe for the API.
    """
    id: str
    username: str
    email: str
    first_name: str
    last_name: str
    phone_number: str
    role: str
    is_active: bool
    affiliation: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    @field_validator("id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        """Convert UUID objects to strings for JSON serialization."""
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# User Update — What admins can change
# ---------------------------------------------------------------
class UserUpdate(BaseModel):
    """
    Fields an admin can update on a user account.
    ALL fields are optional — the admin only sends what
    they want to change.
    Example: To approve an account, send just:
      { "is_active": true }
    Example: To change a role, send just:
      { "role": "school_admin" }
    Fields NOT here (and can't be changed through this endpoint):
    - username (immutable after creation)
    - password_hash (use password reset endpoint instead)
    - security questions (use separate endpoint)
    """
    email: Optional[EmailStr] = None
    first_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, max_length=100)
    phone_number: Optional[str] = Field(None, max_length=20)
    role: Optional[str] = Field(
        None,
        pattern="^(lbb_admin|school_admin|volunteer|it_support)$",
        description="Admins can assign any role"
    )
    is_active: Optional[bool] = Field(
        None,
        description="True = approved, False = deactivated"
    )
    affiliation: Optional[str] = Field(None, max_length=255)


# ---------------------------------------------------------------
# User List — Paginated response
# ---------------------------------------------------------------
class UserListResponse(BaseModel):
    """
    Paginated list of users for the admin dashboard.
    Includes total count so the frontend can display pagination.
    """
    users: list[UserResponse]
    total: int
    page: int
    per_page: int
