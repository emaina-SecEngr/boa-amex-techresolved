"""
Donation Schemas — Donation Tracking Validation
===================================================
Request/response schemas for managing donations:
  - Cash and in-kind donations
  - Thank you letter tracking
  - Donation reporting by academic year

ConOps references:
  5.9: Donation entity (cash and in-kind)
  6.5.8: Admin records and tracks donations
  6.6.6: Thank you letter generation
"""

from uuid import UUID
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import date, datetime
from decimal import Decimal


# ---------------------------------------------------------------
# Donation
# ---------------------------------------------------------------
class DonationCreate(BaseModel):
    """Record a new donation (cash or in-kind)."""
    donor_name: str = Field(..., min_length=1, max_length=255)
    donor_email: Optional[str] = Field(None, max_length=255)
    donor_phone: Optional[str] = Field(None, max_length=20)
    donor_organization: Optional[str] = Field(None, max_length=255)
    amount: Decimal = Field(..., ge=0, description="Dollar value of donation")
    donation_date: date = Field(..., description="Date donation was received")
    donation_kind: str = Field(
        ...,
        pattern="^(cash|in_kind)$",
        description="Type: cash or in_kind"
    )
    description: Optional[str] = Field(None, max_length=1000)
    academic_year_id: Optional[str] = None


class DonationUpdate(BaseModel):
    """Partial update for a donation record."""
    donor_name: Optional[str] = Field(None, max_length=255)
    donor_email: Optional[str] = Field(None, max_length=255)
    donor_phone: Optional[str] = Field(None, max_length=20)
    donor_organization: Optional[str] = Field(None, max_length=255)
    amount: Optional[Decimal] = Field(None, ge=0)
    donation_date: Optional[date] = None
    donation_kind: Optional[str] = Field(
        None,
        pattern="^(cash|in_kind)$"
    )
    description: Optional[str] = Field(None, max_length=1000)
    letter_sent: Optional[bool] = None
    academic_year_id: Optional[str] = None


class DonationResponse(BaseModel):
    id: str
    donor_name: str
    donor_email: Optional[str] = None
    donor_phone: Optional[str] = None
    donor_organization: Optional[str] = None
    amount: Decimal
    donation_date: date
    donation_kind: str
    description: Optional[str] = None
    letter_sent: bool
    letter_sent_at: Optional[datetime] = None
    academic_year_id: Optional[str] = None
    recorded_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    @field_validator("id", "academic_year_id", "recorded_by", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


class DonationListResponse(BaseModel):
    donations: list[DonationResponse]
    total: int
    total_amount: Decimal


class DonationSummary(BaseModel):
    """Summary statistics for donation reporting."""
    total_donations: int
    total_cash: Decimal
    total_in_kind: Decimal
    total_amount: Decimal
    letters_sent: int
    letters_pending: int
