"""
Event Scheduling Routes — API Endpoints
==========================================
Manages academic years, event dates, school registration,
and volunteer signups.

ConOps references:
  6.5.7: Admin creates available event dates
  6.7.1: One school per event date
  6.7.3: Confirmation after registration
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from typing import Any
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, require_roles
from app.models.user import User
from app.schemas.event import (
    AcademicYearCreate,
    AcademicYearResponse,
    EventCreate,
    EventUpdate,
    EventResponse,
    EventListResponse,
    MySchoolRegistrationItem,
    MyVolunteerSignupItem,
    EventRegistrationCreate,
    EventRegistrationResponse,
    VolunteerSignupCreate,
    VolunteerSignupResponse,
)
from app.schemas.auth import MessageResponse
from app.services.event_service import (
    create_academic_year,
    list_academic_years,
    create_event,
    list_events,
    get_event_by_id,
    update_event,
    delete_event,
    list_my_school_event_registrations,
    list_my_volunteer_event_signups,
    register_school_for_event,
    signup_volunteer_for_event,
    process_volunteer_event_reminders,
)


router = APIRouter(prefix="/events", tags=["Event Scheduling"])


# ===============================================================
# Academic Year Endpoints
# ===============================================================

@router.post(
    "/years",
    response_model=AcademicYearResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create academic year",
    description="Admin creates a new academic year cycle. (Admin only)",
)
def create_year(
    data: AcademicYearCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        year = create_academic_year(db, data)
        return year
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "/years",
    response_model=list[AcademicYearResponse],
    summary="List academic years",
    description="Returns all academic years, most recent first.",
)
def get_years(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_academic_years(db)


# ===============================================================
# Event Endpoints
# ===============================================================

@router.post(
    "",
    response_model=EventResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create event date",
    description="Admin creates an available event date. (Admin only)",
)
def create_new_event(
    data: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        event = create_event(db, data)
        return event
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "",
    response_model=EventListResponse,
    summary="List events",
    description="List events with optional filters for academic year and status.",
)
def get_events(
    academic_year_id: str = Query(default=None, description="Filter by academic year"),
    event_status: str = Query(default=None, description="Filter by status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = list_events(db, academic_year_id=academic_year_id, status=event_status)
    return result


@router.get(
    "/my-school-registrations",
    response_model=list[MySchoolRegistrationItem],
    summary="My school's event registrations",
    description="School admin: lists events your school has registered for.",
)
def get_my_school_registrations(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["school_admin"])),
):
    rows = list_my_school_event_registrations(db, str(current_user.id))
    return rows


@router.get(
    "/my-volunteer-signups",
    response_model=list[MyVolunteerSignupItem],
    summary="My volunteer event signups",
    description="Volunteer: lists events you have signed up to help with.",
)
def get_my_volunteer_signups(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["volunteer"])),
):
    rows = list_my_volunteer_event_signups(db, str(current_user.id))
    return rows


@router.post(
    "/reminders/run",
    summary="Send volunteer event reminders",
    description=(
        "Processes 14-day and 4-day reminder emails for volunteer signups. "
        "Intended for cron or manual admin trigger (MVP2)."
    ),
)
def run_volunteer_reminders(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
) -> dict[str, Any]:
    return process_volunteer_event_reminders(db)


@router.get(
    "/{event_id}",
    response_model=EventResponse,
    summary="Get event details",
    description="Returns a single event by ID.",
)
def get_event(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        event = get_event_by_id(db, event_id)
        return event
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.patch(
    "/{event_id}",
    response_model=EventResponse,
    summary="Update event",
    description="Partial update of event fields. Validates status transitions. (Admin only)",
)
def patch_event(
    event_id: str,
    data: EventUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        event = update_event(db, event_id, data)
        return event
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.delete(
    "/{event_id}",
    response_model=MessageResponse,
    summary="Cancel event",
    description="Sets event status to cancelled. (Admin only)",
)
def cancel_event(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        event = delete_event(db, event_id)
        return MessageResponse(message=f"Event on {event.event_date} cancelled")
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ===============================================================
# School Registration
# ===============================================================

@router.post(
    "/{event_id}/register",
    response_model=EventRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register school for event",
    description="School admin registers their school for an event date.",
)
def register_for_event(
    event_id: str,
    data: EventRegistrationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        registration = register_school_for_event(
            db, event_id, data, registered_by_id=str(current_user.id)
        )
        return registration
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ===============================================================
# Volunteer Signup
# ===============================================================

@router.post(
    "/{event_id}/signup",
    response_model=VolunteerSignupResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Volunteer signs up for event",
    description="Volunteer signs up to participate in an event.",
)
def signup_for_event(
    event_id: str,
    data: VolunteerSignupCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "volunteer"])),
):
    try:
        signup = signup_volunteer_for_event(
            db, event_id, str(current_user.id), data
        )
        return signup
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
