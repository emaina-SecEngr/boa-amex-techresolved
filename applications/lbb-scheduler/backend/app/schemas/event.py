"""
Event Schemas — Scheduling Validation
========================================
Request/response schemas for:
  - Academic years (July 1 - June 30 cycles)
  - LBB Events (available dates for schools)
  - Event registration (school signs up for event)
  - Volunteer signup (volunteer joins an event)

ConOps references:
  6.5.7: Admin creates available event dates
  6.7.1: One school per event date
  6.7.3: Confirmation emails after registration
  6.7.6: 14-day and 4-day volunteer reminders
"""


from uuid import UUID
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import date, time, datetime


# ---------------------------------------------------------------
# Academic Year
# ---------------------------------------------------------------
class AcademicYearCreate(BaseModel):
    """
    Create a new academic year (e.g., "2025-2026").
    Runs July 1 to June 30 per ConOps.
    """
    name: str = Field(
        ...,
        min_length=1,
        max_length=20,
        description="e.g., '2025-2026'"
    )
    start_date: date = Field(..., description="Typically July 1")
    end_date: date = Field(..., description="Typically June 30")
    is_active: bool = Field(default=True)


class AcademicYearResponse(BaseModel):
    id: str
    name: str
    start_date: date
    end_date: date
    is_active: bool
    created_at: datetime

    @field_validator("id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# LBB Event (available date slots)
# ---------------------------------------------------------------
class EventCreate(BaseModel):
    """
    Admin creates an available event date.
    Status starts as 'available' and changes to 'reserved'
    when a school registers.
    """
    academic_year_id: str = Field(..., description="UUID of the academic year")

    @field_validator("academic_year_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    event_date: date = Field(..., description="The date of the event")
    event_time: Optional[time] = Field(None, description="Optional start time")
    notes: Optional[str] = Field(None, max_length=500)


class EventUpdate(BaseModel):
    """Partial update for an event."""
    event_date: Optional[date] = None
    event_time: Optional[time] = None
    status: Optional[str] = Field(
        None,
        pattern="^(available|reserved|completed|cancelled)$",
        description="Event status"
    )
    notes: Optional[str] = Field(None, max_length=500)


class EventResponse(BaseModel):
    id: str
    academic_year_id: str

    @field_validator("id", "academic_year_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v
    event_date: date
    event_time: Optional[time] = None
    status: str
    notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class EventListResponse(BaseModel):
    events: list[EventResponse]
    total: int


class MySchoolRegistrationItem(BaseModel):
    """School admin: one row per event the school has registered for."""

    registration_id: str
    event_id: str
    event_date: date
    event_time: Optional[time] = None
    event_status: str
    anticipated_students: int
    requested_time: Optional[time] = None
    special_requests: Optional[str] = None
    registered_at: datetime

    @field_validator("registration_id", "event_id", mode="before")
    @classmethod
    def uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v


class MyVolunteerSignupItem(BaseModel):
    """Volunteer: one row per event the volunteer has signed up for."""

    signup_id: str
    event_id: str
    event_date: date
    event_time: Optional[time] = None
    event_status: str
    signed_up_at: datetime

    @field_validator("signup_id", "event_id", mode="before")
    @classmethod
    def uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v


# ---------------------------------------------------------------
# Event Registration (school signs up for an event)
# ---------------------------------------------------------------
class EventRegistrationCreate(BaseModel):
    """
    A school registers for an event date.
    ConOps 6.7.1: Only ONE school per event date.
    """
    school_id: str = Field(..., description="UUID of the school")

    @field_validator("school_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v
    anticipated_students: int = Field(
        ...,
        ge=1,
        le=500,
        description="Expected number of students"
    )
    requested_time: Optional[time] = Field(
        None, description="Preferred start time")
    special_requests: Optional[str] = Field(None, max_length=500)


class EventRegistrationResponse(BaseModel):
    id: str
    event_id: str
    school_id: str

    @field_validator("id", "event_id", "school_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v
    anticipated_students: int
    requested_time: Optional[time] = None
    special_requests: Optional[str] = None
    confirmation_sent: bool
    registered_at: datetime

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# Volunteer Signup
# ---------------------------------------------------------------
class VolunteerSignupCreate(BaseModel):
    """
    A volunteer signs up for an event.
    ConOps 6.7.6: Reminders sent at 14 days and 4 days before.
    """
    class_id: Optional[str] = Field(
        None,
        description="UUID of the life skills class to teach (optional)"
    )


class VolunteerSignupResponse(BaseModel):
    id: str
    event_id: str
    volunteer_id: str

    @field_validator("id", "event_id", "volunteer_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v
    class_id: Optional[str] = None
    confirmation_sent: bool
    reminder_14d_sent: bool
    reminder_4d_sent: bool
    signed_up_at: datetime

    class Config:
        from_attributes = True
