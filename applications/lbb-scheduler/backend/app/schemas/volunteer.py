"""
Volunteer & Life Skills Class Schemas
========================================
Request/response schemas for:
  - Volunteer profiles (bio, organization, availability)
  - Life skills classes (curriculum taught by volunteers)

ConOps references:
  5.3: Volunteer entity
  5.5: Life skills class entity
  6.5.9: Admin manages class catalog
  6.6.5: Volunteer manages their own profile
"""

from uuid import UUID
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


# ---------------------------------------------------------------
# Volunteer Profile
# ---------------------------------------------------------------
class VolunteerProfileCreate(BaseModel):
    """Create or update a volunteer's extended profile."""
    organization: Optional[str] = Field(None, max_length=255)
    bio: Optional[str] = Field(None, max_length=2000)
    special_requirements: Optional[str] = Field(None, max_length=500)
    is_available: bool = Field(default=True)
    background_check_status: Optional[str] = Field(
        None,
        pattern="^(pending|cleared|expired|not_applicable)$",
        description="Screening status for scheduling decisions",
    )


class VolunteerProfileUpdate(BaseModel):
    """Partial update for volunteer profile."""
    organization: Optional[str] = Field(None, max_length=255)
    bio: Optional[str] = Field(None, max_length=2000)
    special_requirements: Optional[str] = Field(None, max_length=500)
    is_available: Optional[bool] = None
    background_check_status: Optional[str] = Field(
        None,
        pattern="^(pending|cleared|expired|not_applicable)$",
    )


class VolunteerProfileResponse(BaseModel):
    id: str
    user_id: str
    organization: Optional[str] = None
    bio: Optional[str] = None
    special_requirements: Optional[str] = None
    background_check_status: Optional[str] = None
    is_available: bool
    created_at: datetime
    updated_at: datetime
    # Joined from User for admin lists and profile display
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None

    @field_validator("id", "user_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# Life Skills Class
# ---------------------------------------------------------------
class LifeSkillsClassCreate(BaseModel):
    """
    Create a new life skills class in the catalog.
    Lead volunteer is the professional teaching the class.
    """
    class_name: str = Field(..., min_length=1, max_length=255)
    lead_volunteer_id: str = Field(...,
                                   description="UUID of the lead volunteer")
    description: str = Field(..., min_length=1)
    other_volunteers: Optional[str] = None
    special_logistics: Optional[str] = None
    equipment_by_professional: Optional[str] = None
    equipment_by_lbb: Optional[str] = None
    max_students: Optional[int] = Field(None, ge=1, le=200)
    recommended_take_home_item: Optional[str] = Field(None, max_length=255)
    volunteer_take_home_item: Optional[str] = Field(None, max_length=255)
    other_requirements: Optional[str] = None

    @field_validator("lead_volunteer_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v


class LifeSkillsClassUpdate(BaseModel):
    """Partial update for a life skills class."""
    class_name: Optional[str] = Field(None, max_length=255)
    lead_volunteer_id: Optional[str] = None
    description: Optional[str] = None
    other_volunteers: Optional[str] = None
    special_logistics: Optional[str] = None
    equipment_by_professional: Optional[str] = None
    equipment_by_lbb: Optional[str] = None
    max_students: Optional[int] = Field(None, ge=1, le=200)
    recommended_take_home_item: Optional[str] = Field(None, max_length=255)
    volunteer_take_home_item: Optional[str] = Field(None, max_length=255)
    other_requirements: Optional[str] = None


class LifeSkillsClassResponse(BaseModel):
    id: str
    class_name: str
    lead_volunteer_id: str
    description: str
    other_volunteers: Optional[str] = None
    special_logistics: Optional[str] = None
    equipment_by_professional: Optional[str] = None
    equipment_by_lbb: Optional[str] = None
    max_students: Optional[int] = None
    recommended_take_home_item: Optional[str] = None
    volunteer_take_home_item: Optional[str] = None
    other_requirements: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    @field_validator("id", "lead_volunteer_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


class LifeSkillsClassListResponse(BaseModel):
    classes: list[LifeSkillsClassResponse]
    total: int
