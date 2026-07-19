"""
School Schemas — School Management Validation
=================================================
Request/response schemas for:
  - Schools (CRUD)
  - School Principals
  - Photo Restrictions (students who cannot be photographed)

ConOps references:
  5.2: School entity with POC info
  6.5.10: Admin manages school records
  6.6.3: School admin manages their school info
"""

from uuid import UUID
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


# ---------------------------------------------------------------
# School Principal
# ---------------------------------------------------------------
class PrincipalCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    title: Optional[str] = Field(None, max_length=100)


class PrincipalResponse(BaseModel):
    id: str
    school_id: str
    name: str
    title: Optional[str] = None

    @field_validator("id", "school_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# Photo Restriction
# ---------------------------------------------------------------
class PhotoRestrictionCreate(BaseModel):
    """Students who cannot be photographed during events."""
    student_name: str = Field(..., min_length=1, max_length=255)
    class_assignment: Optional[str] = Field(None, max_length=255)
    academic_year_id: Optional[str] = None

    @field_validator("academic_year_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v


class PhotoRestrictionResponse(BaseModel):
    id: str
    school_id: str
    student_name: str
    class_assignment: Optional[str] = None
    academic_year_id: Optional[str] = None

    @field_validator("id", "school_id", "academic_year_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# School
# ---------------------------------------------------------------
class SchoolCreate(BaseModel):
    """Create a new school record."""
    school_name: str = Field(..., min_length=1, max_length=255)
    school_district: str = Field(..., min_length=1, max_length=255)
    school_address: str = Field(..., min_length=1)
    poc_name: str = Field(..., min_length=1, max_length=255)
    poc_phone: str = Field(..., min_length=1, max_length=20)
    poc_email: str = Field(..., min_length=1, max_length=255)
    comments: Optional[str] = None
    admin_user_id: Optional[str] = None


class SchoolUpdate(BaseModel):
    """Partial update for a school."""
    school_name: Optional[str] = Field(None, max_length=255)
    school_district: Optional[str] = Field(None, max_length=255)
    school_address: Optional[str] = None
    poc_name: Optional[str] = Field(None, max_length=255)
    poc_phone: Optional[str] = Field(None, max_length=20)
    poc_email: Optional[str] = Field(None, max_length=255)
    comments: Optional[str] = None
    admin_user_id: Optional[str] = None


class SchoolResponse(BaseModel):
    id: str
    school_name: str
    school_district: str
    school_address: str
    poc_name: str
    poc_phone: str
    poc_email: str
    comments: Optional[str] = None
    admin_user_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    principals: list[PrincipalResponse] = []
    photo_restrictions: list[PhotoRestrictionResponse] = []

    @field_validator("id", "admin_user_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


class SchoolListResponse(BaseModel):
    schools: list[SchoolResponse]
    total: int
