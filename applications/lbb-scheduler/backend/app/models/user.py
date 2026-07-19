"""
User Model — ConOps Sections 5.1, 6.5.1, 6.6.1
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.orm import relationship

from app.core.database import Base, GUID


class User(Base):
    __tablename__ = "users"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    username = Column(String(50), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)

    security_question_1 = Column(String(255), nullable=False)
    security_answer_1 = Column(String(255), nullable=False)
    security_question_2 = Column(String(255), nullable=False)
    security_answer_2 = Column(String(255), nullable=False)

    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    phone_number = Column(String(20), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)

    role = Column(String(20), nullable=False)
    is_active = Column(Boolean, default=False, nullable=False)

    affiliation = Column(String(255), nullable=True)
    totp_secret = Column(String(32), nullable=True)

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

    volunteer_profile = relationship(
        "VolunteerProfile",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
    classes_taught = relationship(
        "LifeSkillsClass",
        back_populates="lead_volunteer",
        foreign_keys="LifeSkillsClass.lead_volunteer_id",
    )

    def __repr__(self):
        return f"<User(id={self.id}, username={self.username}, role={self.role})>"
