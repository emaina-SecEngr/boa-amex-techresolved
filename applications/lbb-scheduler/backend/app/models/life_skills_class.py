"""
Volunteer & Life Skills Class Models — ConOps 5.3, 5.5, 6.5.9, 6.6.5
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column, String, Integer, DateTime, Text, ForeignKey, Boolean
)
from sqlalchemy.orm import relationship

from app.core.database import Base, GUID


class VolunteerProfile(Base):
    __tablename__ = "volunteer_profiles"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)

    organization = Column(String(255), nullable=True)
    bio = Column(Text, nullable=True)
    special_requirements = Column(Text, nullable=True)
    is_available = Column(Boolean, default=True, nullable=False)
    # pending | cleared | expired | not_applicable
    background_check_status = Column(String(32), nullable=True)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    user = relationship("User", back_populates="volunteer_profile")

    def __repr__(self):
        return f"<VolunteerProfile(user_id={self.user_id})>"


class LifeSkillsClass(Base):
    __tablename__ = "life_skills_classes"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    class_name = Column(String(255), nullable=False, index=True)
    lead_volunteer_id = Column(GUID(), ForeignKey("users.id"), nullable=False)
    description = Column(Text, nullable=False)

    other_volunteers = Column(Text, nullable=True)
    special_logistics = Column(Text, nullable=True)
    equipment_by_professional = Column(Text, nullable=True)
    equipment_by_lbb = Column(Text, nullable=True)
    max_students = Column(Integer, nullable=True)
    recommended_take_home_item = Column(String(255), nullable=True)
    volunteer_take_home_item = Column(String(255), nullable=True)
    other_requirements = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    lead_volunteer = relationship("User", back_populates="classes_taught", foreign_keys=[lead_volunteer_id])

    def __repr__(self):
        return f"<LifeSkillsClass(name={self.class_name})>"
