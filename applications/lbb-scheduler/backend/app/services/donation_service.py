"""
Donation Service — Donation Tracking Business Logic
======================================================
Handles all donation operations:
  - Record new donations (cash and in-kind)
  - List and filter donations
  - Mark thank you letters as sent
  - Generate donation summaries for reporting

ConOps references:
  5.9: Cash and in-kind donation tracking
  6.5.8: Admin records donations
  6.6.6: Thank you letter tracking
"""

from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy.orm import Session

from app.models.donation import Donation
from app.schemas.donation import DonationCreate, DonationUpdate


# Centralized error messages (SonarQube python:S1192)
DONATION_NOT_FOUND = "Donation not found"


# ===============================================================
# Donation CRUD
# ===============================================================

def create_donation(
    db: Session, data: DonationCreate, recorded_by_id: str
) -> Donation:
    """Record a new donation."""
    donation = Donation(
        donor_name=data.donor_name,
        donor_email=data.donor_email,
        donor_phone=data.donor_phone,
        donor_organization=data.donor_organization,
        amount=data.amount,
        donation_date=data.donation_date,
        donation_kind=data.donation_kind,
        description=data.description,
        academic_year_id=data.academic_year_id,
        recorded_by=recorded_by_id,
        letter_sent=False,
    )

    db.add(donation)
    db.commit()
    db.refresh(donation)
    return donation


def list_donations(
    db: Session,
    academic_year_id: str = None,
    donation_kind: str = None,
    letter_sent: bool = None,
) -> dict:
    """List donations with optional filters."""
    query = db.query(Donation)

    if academic_year_id:
        query = query.filter(Donation.academic_year_id == academic_year_id)
    if donation_kind:
        query = query.filter(Donation.donation_kind == donation_kind)
    if letter_sent is not None:
        query = query.filter(Donation.letter_sent == letter_sent)

    donations = query.order_by(Donation.donation_date.desc()).all()

    total_amount = sum(d.amount for d in donations) if donations else Decimal("0.00")

    return {
        "donations": donations,
        "total": len(donations),
        "total_amount": total_amount,
    }


def get_donation_by_id(db: Session, donation_id: str) -> Donation:
    """Get a single donation by ID."""
    donation = db.query(Donation).filter(Donation.id == donation_id).first()
    if not donation:
        raise ValueError(DONATION_NOT_FOUND)
    return donation


def update_donation(
    db: Session, donation_id: str, data: DonationUpdate
) -> Donation:
    """Partial update of a donation record."""
    donation = db.query(Donation).filter(Donation.id == donation_id).first()
    if not donation:
        raise ValueError(DONATION_NOT_FOUND)

    update_data = data.model_dump(exclude_unset=True)

    # If marking letter as sent, record the timestamp
    if "letter_sent" in update_data and update_data["letter_sent"] is True:
        donation.letter_sent_at = datetime.now(timezone.utc)

    for field, value in update_data.items():
        setattr(donation, field, value)

    db.commit()
    db.refresh(donation)
    return donation


def delete_donation(db: Session, donation_id: str) -> Donation:
    """Delete a donation record."""
    donation = db.query(Donation).filter(Donation.id == donation_id).first()
    if not donation:
        raise ValueError(DONATION_NOT_FOUND)

    db.delete(donation)
    db.commit()
    return donation


# ===============================================================
# Donation Reporting
# ===============================================================

def get_donation_summary(
    db: Session, academic_year_id: str = None
) -> dict:
    """
    Generate donation summary statistics.
    Used for admin reporting dashboard.
    """
    query = db.query(Donation)
    if academic_year_id:
        query = query.filter(Donation.academic_year_id == academic_year_id)

    donations = query.all()

    total_cash = sum(
        d.amount for d in donations if d.donation_kind == "cash"
    ) if donations else Decimal("0.00")

    total_in_kind = sum(
        d.amount for d in donations if d.donation_kind == "in_kind"
    ) if donations else Decimal("0.00")

    letters_sent = sum(1 for d in donations if d.letter_sent)
    letters_pending = sum(1 for d in donations if not d.letter_sent)

    return {
        "total_donations": len(donations),
        "total_cash": total_cash,
        "total_in_kind": total_in_kind,
        "total_amount": total_cash + total_in_kind,
        "letters_sent": letters_sent,
        "letters_pending": letters_pending,
    }
