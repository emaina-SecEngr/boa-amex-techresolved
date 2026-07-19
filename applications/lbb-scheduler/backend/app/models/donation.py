"""
Donation Model — ConOps Sections 5.9, 6.5.8, 6.6.6
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column, String, DateTime, Date, Text, ForeignKey,
    Boolean, Numeric
)

from app.core.database import Base, GUID


class Donation(Base):
    __tablename__ = "donations"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    donor_name = Column(String(255), nullable=False)
    donor_email = Column(String(255), nullable=True)
    donor_phone = Column(String(20), nullable=True)
    donor_organization = Column(String(255), nullable=True)

    amount = Column(Numeric(10, 2), nullable=False)
    donation_date = Column(Date, nullable=False)
    donation_kind = Column(String(20), nullable=False)
    description = Column(Text, nullable=True)

    letter_sent = Column(Boolean, default=False, nullable=False)
    letter_sent_at = Column(DateTime(timezone=True), nullable=True)

    academic_year_id = Column(GUID(), ForeignKey("academic_years.id"), nullable=True)
    recorded_by = Column(GUID(), ForeignKey("users.id"), nullable=True)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    def __repr__(self):
        return f"<Donation(donor={self.donor_name}, amount={self.amount}, kind={self.donation_kind})>"
