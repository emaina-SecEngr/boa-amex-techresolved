"""
Donation Routes — API Endpoints
==================================
  POST   /api/v1/donations              → Record donation
  GET    /api/v1/donations              → List donations
  GET    /api/v1/donations/summary      → Donation summary stats
  GET    /api/v1/donations/{id}         → Get donation details
  PATCH  /api/v1/donations/{id}         → Update donation
  DELETE /api/v1/donations/{id}         → Delete donation
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import require_roles
from app.models.user import User
from app.schemas.donation import (
    DonationCreate,
    DonationUpdate,
    DonationResponse,
    DonationListResponse,
    DonationSummary,
)
from app.schemas.auth import MessageResponse
from app.services.donation_service import (
    create_donation,
    list_donations,
    get_donation_by_id,
    update_donation,
    delete_donation,
    get_donation_summary,
)


router = APIRouter(prefix="/donations", tags=["Donations"])


@router.post(
    "",
    response_model=DonationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record donation",
    description="Record a new cash or in-kind donation. (Admin only)",
)
def create_new_donation(
    data: DonationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        donation = create_donation(db, data, recorded_by_id=str(current_user.id))
        return donation
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "",
    response_model=DonationListResponse,
    summary="List donations",
    description="List donations with optional filters.",
)
def get_donations(
    academic_year_id: str = Query(default=None, description="Filter by academic year"),
    donation_kind: str = Query(default=None, description="Filter: cash or in_kind"),
    letter_sent: bool = Query(default=None, description="Filter by letter status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    return list_donations(
        db,
        academic_year_id=academic_year_id,
        donation_kind=donation_kind,
        letter_sent=letter_sent,
    )


@router.get(
    "/summary",
    response_model=DonationSummary,
    summary="Donation summary",
    description="Get donation statistics for reporting. (Admin only)",
)
def donation_summary(
    academic_year_id: str = Query(default=None, description="Filter by academic year"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    return get_donation_summary(db, academic_year_id=academic_year_id)


@router.get(
    "/{donation_id}",
    response_model=DonationResponse,
    summary="Get donation details",
    description="Returns a single donation by ID. (Admin only)",
)
def get_donation(
    donation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        donation = get_donation_by_id(db, donation_id)
        return donation
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.patch(
    "/{donation_id}",
    response_model=DonationResponse,
    summary="Update donation",
    description="Partial update of a donation. Use to mark thank you letter sent. (Admin only)",
)
def patch_donation(
    donation_id: str,
    data: DonationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        donation = update_donation(db, donation_id, data)
        return donation
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.delete(
    "/{donation_id}",
    response_model=MessageResponse,
    summary="Delete donation",
    description="Permanently remove a donation record. (Admin only)",
)
def remove_donation(
    donation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    try:
        donation = delete_donation(db, donation_id)
        return MessageResponse(
            message=f"Donation from '{donation.donor_name}' deleted"
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
