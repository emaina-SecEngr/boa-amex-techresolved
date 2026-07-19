"""
LBB Card Authorization — Data Models
PCI-DSS compliant: PAN never stored, only tokens
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from enum import Enum


class AuthorizationRequest(BaseModel):
    """Incoming authorization request from payment network"""
    pan: str = Field(
        ...,
        min_length=13,
        max_length=19,
        description="Primary Account Number (card number). Tokenized immediately, never stored."
    )
    amount: float = Field(
        ...,
        gt=0,
        le=999999.99,
        description="Transaction amount"
    )
    currency: str = Field(
        default="USD",
        min_length=3,
        max_length=3,
        description="ISO 4217 currency code"
    )
    merchant_id: str = Field(
        ...,
        min_length=1,
        max_length=50,
        description="Merchant identifier"
    )
    merchant_name: Optional[str] = Field(
        default=None,
        description="Merchant display name"
    )
    merchant_category_code: str = Field(
        default="5999",
        min_length=4,
        max_length=4,
        description="MCC — categorizes merchant type (5411=grocery, 5812=restaurant, etc.)"
    )
    country_code: str = Field(
        default="US",
        min_length=2,
        max_length=2,
        description="ISO 3166-1 alpha-2 country code"
    )
    entry_mode: str = Field(
        default="CHIP",
        description="How card was read: CHIP, SWIPE, CONTACTLESS, ECOMMERCE, MANUAL"
    )
    pin_verified: bool = Field(
        default=False,
        description="Whether PIN was verified at terminal"
    )

    @field_validator("pan")
    @classmethod
    def validate_pan(cls, v):
        """Basic Luhn check — validates card number format"""
        digits = [int(d) for d in v if d.isdigit()]
        if len(digits) < 13:
            raise ValueError("PAN too short")
        checksum = 0
        for i, d in enumerate(reversed(digits)):
            if i % 2 == 1:
                d *= 2
                if d > 9:
                    d -= 9
            checksum += d
        if checksum % 10 != 0:
            raise ValueError("Invalid PAN (Luhn check failed)")
        return v


class TransactionStatus(str, Enum):
    APPROVED = "APPROVED"
    DENIED = "DENIED"
    STEP_UP_REQUIRED = "STEP_UP_REQUIRED"
    ERROR = "ERROR"


class AuthorizationResponse(BaseModel):
    """Authorization response back to payment network"""
    token: str = Field(
        ...,
        description="Tokenized card identifier (never the PAN)"
    )
    status: TransactionStatus = Field(
        ...,
        description="Authorization decision"
    )
    reason: str = Field(
        ...,
        description="Reason for decision"
    )
    auth_code: str = Field(
        default="",
        description="6-digit authorization code (only for APPROVED)"
    )
    fraud_score: Optional[float] = Field(
        default=None,
        ge=0,
        le=100,
        description="Fraud risk score 0-100"
    )
    amount: float = Field(
        ...,
        description="Authorized amount"
    )
    remaining_balance: Optional[float] = Field(
        default=None,
        description="Remaining available balance (only for APPROVED)"
    )
    processing_time_ms: float = Field(
        ...,
        description="Processing time in milliseconds (SLA: <100ms)"
    )
    timestamp: float = Field(
        ...,
        description="Response timestamp (Unix epoch)"
    )


class FraudResult(BaseModel):
    """Fraud check result from scoring engine"""
    score: float = Field(
        ...,
        ge=0,
        le=100,
        description="Risk score: 0-49=low, 50-79=medium (step-up), 80-100=high (deny)"
    )
    factors: list[str] = Field(
        default_factory=list,
        description="Risk factors that contributed to score"
    )
    recommendation: str = Field(
        default="APPROVE",
        description="APPROVE, STEP_UP, or DENY"
    )


class TransactionLog(BaseModel):
    """Immutable transaction audit record — PCI-DSS Req 10"""
    card_token: str
    amount: float
    currency: str
    merchant_id: str
    merchant_category_code: str
    country_code: str
    status: str
    reason: str
    source_ip: str
    processing_time_ms: float