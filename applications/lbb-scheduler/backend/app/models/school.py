"""
School Model — ConOps Sections 5.2, 6.5.10, 6.6.3
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship

from app.core.database import Base, GUID
from app.models.constants import USERS_ID, ACADEMIC_YEARS_ID, SCHOOLS_ID, CASCADE_ALL_DELETE_ORPHAN


class School(Base):
    __tablename__ = "schools"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    school_name = Column(String(255), nullable=False, index=True)
    school_district = Column(String(255), nullable=False)
    school_address = Column(Text, nullable=False)

    poc_name = Column(String(255), nullable=False)
    poc_phone = Column(String(20), nullable=False)
    poc_email = Column(String(255), nullable=False)

    comments = Column(Text, nullable=True)

    admin_user_id = Column(GUID(), ForeignKey(USERS_ID), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    principals = relationship("SchoolPrincipal", back_populates="school", cascade=CASCADE_ALL_DELETE_ORPHAN)
    event_registrations = relationship("EventRegistration", back_populates="school", cascade=CASCADE_ALL_DELETE_ORPHAN)
    photo_restrictions = relationship("PhotoRestriction", back_populates="school", cascade=CASCADE_ALL_DELETE_ORPHAN)

    def __repr__(self) -> str:
        return f"<School(id={self.id}, name={self.school_name})>"


class SchoolPrincipal(Base):
    __tablename__ = "school_principals"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    school_id = Column(GUID(), ForeignKey(SCHOOLS_ID, ondelete="CASCADE"), nullable=False)
    name = Column(String(255), nullable=False)
    title = Column(String(100), nullable=True)

    school = relationship("School", back_populates="principals")


class PhotoRestriction(Base):
    __tablename__ = "photo_restrictions"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    school_id = Column(GUID(), ForeignKey(SCHOOLS_ID, ondelete="CASCADE"), nullable=False)
    student_name = Column(String(255), nullable=False)
    class_assignment = Column(String(255), nullable=True)
    academic_year_id = Column(GUID(), ForeignKey(ACADEMIC_YEARS_ID), nullable=True)

    school = relationship("School", back_populates="photo_restrictions")
