"""
Event & Scheduling Models — ConOps Sections 6.5.7, 6.7.x
"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column, String, Integer, DateTime, Date, Time, Text,
    ForeignKey, Boolean, UniqueConstraint
)
from sqlalchemy.orm import relationship

from app.core.database import Base, GUID
from app.models.constants import (
    USERS_ID, LBB_EVENTS_ID, ACADEMIC_YEARS_ID,
    SCHOOLS_ID, LIFE_SKILLS_CLASSES_ID,
)


class AcademicYear(Base):
    __tablename__ = "academic_years"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    name = Column(String(20), unique=True, nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    events = relationship("LBBEvent", back_populates="academic_year")

    def __repr__(self) -> str:
        return f"<AcademicYear(name={self.name}, active={self.is_active})>"


class LBBEvent(Base):
    __tablename__ = "lbb_events"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    academic_year_id = Column(GUID(), ForeignKey(ACADEMIC_YEARS_ID), nullable=False)
    event_date = Column(Date, nullable=False, index=True)
    event_time = Column(Time, nullable=True)
    status = Column(String(20), default="available", nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    __table_args__ = (
        UniqueConstraint("academic_year_id", "event_date", name="uq_one_event_per_date_per_year"),
    )

    academic_year = relationship("AcademicYear", back_populates="events")
    registration = relationship("EventRegistration", back_populates="event", uselist=False)
    volunteer_signups = relationship("VolunteerEventSignup", back_populates="event")

    def __repr__(self) -> str:
        return f"<LBBEvent(date={self.event_date}, status={self.status})>"


class EventRegistration(Base):
    __tablename__ = "event_registrations"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    event_id = Column(GUID(), ForeignKey(LBB_EVENTS_ID), unique=True, nullable=False)
    school_id = Column(GUID(), ForeignKey(SCHOOLS_ID), nullable=False)

    anticipated_students = Column(Integer, nullable=False)
    requested_time = Column(Time, nullable=True)
    special_requests = Column(Text, nullable=True)

    confirmation_sent = Column(Boolean, default=False)
    confirmation_sent_at = Column(DateTime(timezone=True), nullable=True)

    registered_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    registered_by = Column(GUID(), ForeignKey(USERS_ID), nullable=True)

    event = relationship("LBBEvent", back_populates="registration")
    school = relationship("School", back_populates="event_registrations")

    def __repr__(self) -> str:
        return f"<EventRegistration(event={self.event_id}, school={self.school_id})>"


class VolunteerEventSignup(Base):
    __tablename__ = "volunteer_event_signups"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    event_id = Column(GUID(), ForeignKey(LBB_EVENTS_ID), nullable=False)
    volunteer_id = Column(GUID(), ForeignKey(USERS_ID), nullable=False)
    class_id = Column(GUID(), ForeignKey(LIFE_SKILLS_CLASSES_ID), nullable=True)

    confirmation_sent = Column(Boolean, default=False)
    reminder_14d_sent = Column(Boolean, default=False)
    reminder_4d_sent = Column(Boolean, default=False)

    signed_up_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("event_id", "volunteer_id", name="uq_one_signup_per_volunteer_per_event"),
    )

    event = relationship("LBBEvent", back_populates="volunteer_signups")

    def __repr__(self) -> str:
        return f"<VolunteerSignup(event={self.event_id}, volunteer={self.volunteer_id})>"
