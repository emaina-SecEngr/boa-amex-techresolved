"""
Event Service — Scheduling Business Logic
=============================================
Handles all event scheduling operations:
  - Academic year CRUD
  - Event date management with status transitions
  - School registration (one school per event)
  - Volunteer signup with duplicate prevention

STATUS FLOW:
  available -> reserved (when school registers)
  reserved -> completed (after event happens)
  reserved -> cancelled (if event is cancelled)
  available -> cancelled (if event is cancelled before registration)
"""

from datetime import date, datetime, timezone

from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_

from app.models.user import User
from app.models.school import School
from app.models.event import (
    AcademicYear,
    LBBEvent,
    EventRegistration,
    VolunteerEventSignup,
)
from app.utils.email import (
    notify_school_event_registration_email,
    notify_volunteer_event_reminder_email,
    notify_volunteer_signup_confirmation_email,
)
from app.schemas.event import (
    AcademicYearCreate,
    EventCreate,
    EventUpdate,
    EventRegistrationCreate,
    VolunteerSignupCreate,
)
from app.scheduler.jobs import _send_email

# Centralized error messages (SonarQube python:S1192)
EVENT_NOT_FOUND = "Event not found"


# ===============================================================
# Academic Year Operations
# ===============================================================

def create_academic_year(db: Session, data: AcademicYearCreate) -> AcademicYear:
    """
    Create a new academic year (e.g., 2025-2026).
    Validates that end_date is after start_date.
    """
    if data.end_date <= data.start_date:
        raise ValueError("End date must be after start date")

    existing = db.query(AcademicYear).filter(
        AcademicYear.name == data.name
    ).first()
    if existing:
        raise ValueError(f"Academic year '{data.name}' already exists")

    year = AcademicYear(
        name=data.name,
        start_date=data.start_date,
        end_date=data.end_date,
        is_active=data.is_active,
    )

    db.add(year)
    db.commit()
    db.refresh(year)
    return year


def list_academic_years(db: Session) -> list:
    """Return all academic years, most recent first."""
    return db.query(AcademicYear).order_by(
        AcademicYear.start_date.desc()
    ).all()


# ===============================================================
# Event Operations
# ===============================================================

def create_event(db: Session, data: EventCreate) -> LBBEvent:
    """
    Create a new available event date.
    The UniqueConstraint in the model prevents duplicate
    dates within the same academic year.
    """
    year = db.query(AcademicYear).filter(
        AcademicYear.id == data.academic_year_id
    ).first()
    if not year:
        raise ValueError("Academic year not found")

    if data.event_date < year.start_date or data.event_date > year.end_date:
        raise ValueError(
            f"Event date must be between {year.start_date} and {year.end_date}"
        )

    event = LBBEvent(
        academic_year_id=data.academic_year_id,
        event_date=data.event_date,
        event_time=data.event_time,
        status="available",
        notes=data.notes,
    )

    try:
        db.add(event)
        db.commit()
        db.refresh(event)
        return event
    except Exception:
        db.rollback()
        raise ValueError(
            "An event already exists on this date for this academic year"
        )


def list_my_school_event_registrations(db: Session, user_id: str) -> list[dict]:
    """Return event registrations for the school assigned to this school admin user."""
    school = db.query(School).filter(School.admin_user_id == user_id).first()
    if not school:
        return []

    regs = (
        db.query(EventRegistration)
        .options(joinedload(EventRegistration.event))
        .filter(EventRegistration.school_id == school.id)
        .all()
    )
    out: list[dict] = []
    for r in regs:
        ev = r.event
        if not ev:
            continue
        out.append({
            "registration_id": str(r.id),
            "event_id": str(ev.id),
            "event_date": ev.event_date,
            "event_time": ev.event_time,
            "event_status": ev.status,
            "anticipated_students": r.anticipated_students,
            "requested_time": r.requested_time,
            "special_requests": r.special_requests,
            "registered_at": r.registered_at,
        })
    out.sort(key=lambda row: row["event_date"])
    return out


def list_my_volunteer_event_signups(db: Session, volunteer_id: str) -> list[dict]:
    """Return volunteer event signups for the given user (volunteer)."""
    signups = (
        db.query(VolunteerEventSignup)
        .options(joinedload(VolunteerEventSignup.event))
        .filter(VolunteerEventSignup.volunteer_id == volunteer_id)
        .all()
    )
    out: list[dict] = []
    for s in signups:
        ev = s.event
        if not ev:
            continue
        out.append({
            "signup_id": str(s.id),
            "event_id": str(ev.id),
            "event_date": ev.event_date,
            "event_time": ev.event_time,
            "event_status": ev.status,
            "signed_up_at": s.signed_up_at,
        })
    out.sort(key=lambda row: row["event_date"])
    return out


def list_events(db: Session, academic_year_id: str = None, status: str = None) -> dict:
    """List events with optional filters."""
    query = db.query(LBBEvent)
    if academic_year_id:
        query = query.filter(LBBEvent.academic_year_id == academic_year_id)
    if status:
        query = query.filter(LBBEvent.status == status)
    events = query.order_by(LBBEvent.event_date.asc()).all()
    return {"events": events, "total": len(events)}


def get_event_by_id(db: Session, event_id: str) -> LBBEvent:
    """Get a single event by ID."""
    event = db.query(LBBEvent).filter(LBBEvent.id == event_id).first()
    if not event:
        raise ValueError(EVENT_NOT_FOUND)
    return event


def update_event(db: Session, event_id: str, data: EventUpdate) -> LBBEvent:
    """Update event fields. Validates status transitions."""
    event = db.query(LBBEvent).filter(LBBEvent.id == event_id).first()
    if not event:
        raise ValueError(EVENT_NOT_FOUND)

    update_data = data.model_dump(exclude_unset=True)

    if "status" in update_data:
        valid_transitions = {
            "available": ["reserved", "cancelled"],
            "reserved": ["completed", "cancelled"],
            "completed": [],
            "cancelled": [],
        }
        new_status = update_data["status"]
        allowed = valid_transitions.get(event.status, [])
        if new_status != event.status and new_status not in allowed:
            raise ValueError(
                f"Cannot change status from '{event.status}' to "
                f"'{new_status}'. Allowed: {allowed}"
            )

    for field, value in update_data.items():
        setattr(event, field, value)

    db.commit()
    db.refresh(event)

    # Notify affected parties of admin override (ConOps 6.7.2)
    if update_data:
        signups = db.query(VolunteerEventSignup).filter(
            VolunteerEventSignup.event_id == event.id
        ).all()
        for signup in signups:
            vol = db.query(User).filter(User.id == signup.volunteer_id).first()
            if vol and vol.email:
                _send_email(
                    to=vol.email,
                    subject="LBB Event Update",
                    body=(
                        f"Hi {vol.first_name}, an event on "
                        f"{event.event_date} was updated."
                    ),
                )

    return event


def delete_event(db: Session, event_id: str) -> LBBEvent:
    """Cancel an event (set status to cancelled)."""
    event = db.query(LBBEvent).filter(LBBEvent.id == event_id).first()
    if not event:
        raise ValueError(EVENT_NOT_FOUND)
    if event.status == "completed":
        raise ValueError("Cannot cancel a completed event")

    event.status = "cancelled"
    db.commit()
    db.refresh(event)
    return event


# ===============================================================
# School Registration
# ===============================================================

def register_school_for_event(
    db: Session,
    event_id: str,
    data: EventRegistrationCreate,
    registered_by_id: str,
) -> EventRegistration:
    """
    Register a school for an event date.
    ConOps 6.7.1: Only ONE school per event.
    """
    event = db.query(LBBEvent).filter(LBBEvent.id == event_id).first()
    if not event:
        raise ValueError(EVENT_NOT_FOUND)
    if event.status != "available":
        raise ValueError(f"Event is not available (current status: {event.status})")

    existing = db.query(EventRegistration).filter(
        EventRegistration.event_id == event_id
    ).first()
    if existing:
        raise ValueError("Another school is already registered for this event")

    registration = EventRegistration(
        event_id=event_id,
        school_id=data.school_id,
        anticipated_students=data.anticipated_students,
        requested_time=data.requested_time,
        special_requests=data.special_requests,
        registered_by=registered_by_id,
    )

    event.status = "reserved"

    db.add(registration)
    db.commit()
    db.refresh(registration)

    school = db.query(School).filter(School.id == data.school_id).first()
    if school and school.poc_email:
        notify_school_event_registration_email(
            poc_email=school.poc_email,
            school_name=school.school_name,
            event_date=event.event_date,
            event_time=event.event_time,
            anticipated_students=data.anticipated_students,
        )
    registration.confirmation_sent = True
    registration.confirmation_sent_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(registration)
    return registration


# ===============================================================
# Volunteer Signup
# ===============================================================

def signup_volunteer_for_event(
    db: Session,
    event_id: str,
    volunteer_id: str,
    data: VolunteerSignupCreate,
) -> VolunteerEventSignup:
    """
    Sign up a volunteer for an event.
    UniqueConstraint (event_id, volunteer_id) prevents double signups.
    """
    event = db.query(LBBEvent).filter(LBBEvent.id == event_id).first()
    if not event:
        raise ValueError(EVENT_NOT_FOUND)
    if event.status not in ("available", "reserved"):
        raise ValueError(f"Cannot sign up for event (status: {event.status})")

    existing = db.query(VolunteerEventSignup).filter(
        and_(
            VolunteerEventSignup.event_id == event_id,
            VolunteerEventSignup.volunteer_id == volunteer_id,
        )
    ).first()
    if existing:
        raise ValueError("You are already signed up for this event")

    signup = VolunteerEventSignup(
        event_id=event_id,
        volunteer_id=volunteer_id,
        class_id=data.class_id,
    )

    db.add(signup)
    db.commit()
    db.refresh(signup)

    # Send confirmation email
    vol = db.query(User).filter(User.id == volunteer_id).first()
    if vol and vol.email:
        notify_volunteer_signup_confirmation_email(
            volunteer_email=vol.email,
            volunteer_name=(
                f"{vol.first_name or ''} {vol.last_name or ''}".strip()
                or vol.username
            ),
            event_date=event.event_date,
            event_time=event.event_time,
        )
        signup.confirmation_sent = True
        db.commit()
        db.refresh(signup)

    return signup


# ===============================================================
# Volunteer event reminders (14-day / 4-day windows)
# ===============================================================

def process_volunteer_event_reminders(db: Session) -> dict:
    """
    Send reminder emails for upcoming volunteer signups.
    - 14-day window: event is 5-14 days away and reminder_14d_sent is False
    - 4-day window: event is 0-4 days away and reminder_4d_sent is False
    """
    today = date.today()
    sent_14 = 0
    sent_4 = 0

    signups = (
        db.query(VolunteerEventSignup)
        .options(joinedload(VolunteerEventSignup.event))
        .all()
    )

    for su in signups:
        ev = su.event
        if not ev or ev.status == "cancelled":
            continue
        if ev.event_date < today:
            continue

        days = (ev.event_date - today).days
        vol = db.query(User).filter(User.id == su.volunteer_id).first()
        if not vol or not vol.email:
            continue

        name = f"{vol.first_name or ''} {vol.last_name or ''}".strip() or vol.username

        if days <= 14 and days > 4 and not su.reminder_14d_sent:
            notify_volunteer_event_reminder_email(
                volunteer_email=vol.email,
                volunteer_name=name,
                event_date=ev.event_date,
                event_time=ev.event_time,
                reminder_kind="14d",
            )
            su.reminder_14d_sent = True
            sent_14 += 1
        elif 0 <= days <= 4 and not su.reminder_4d_sent:
            notify_volunteer_event_reminder_email(
                volunteer_email=vol.email,
                volunteer_name=name,
                event_date=ev.event_date,
                event_time=ev.event_time,
                reminder_kind="4d",
            )
            su.reminder_4d_sent = True
            sent_4 += 1

    db.commit()
    return {
        "reminder_14d_emails_sent": sent_14,
        "reminder_4d_emails_sent": sent_4,
    }
