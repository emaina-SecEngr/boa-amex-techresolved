"""LBB Payment Service — Data Models"""
from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


class PaymentStatus(str, Enum):
    COMPLETED = "COMPLETED"
    PENDING_REVIEW = "PENDING_REVIEW"
    BLOCKED = "BLOCKED"
    DENIED = "DENIED"
    ERROR = "ERROR"


class TransferRequest(BaseModel):
    sender_account: str = Field(..., description="Sender account number")
    receiver_account: str = Field(..., description="Receiver account number")
    amount: float = Field(..., gt=0, le=250000, description="Transfer amount")
    currency: str = Field(default="USD")
    memo: Optional[str] = Field(default=None, max_length=255)
    country_code: str = Field(default="US")


class TransferResponse(BaseModel):
    transaction_id: str
    status: PaymentStatus
    reason: str
    amount: float
    sender_new_balance: Optional[float] = None
    receiver_new_balance: Optional[float] = None
    confirmation_number: Optional[str] = None
    processing_time_ms: float


class BillPaymentRequest(BaseModel):
    payer_account: str = Field(..., description="Payer account number")
    biller_name: str = Field(..., description="Biller name")
    biller_account: str = Field(..., description="Biller account/reference number")
    amount: float = Field(..., gt=0, le=100000)
    payment_date: Optional[str] = Field(default=None, description="Scheduled date YYYY-MM-DD")


class WireTransferRequest(BaseModel):
    sender_account: str = Field(...)
    sender_name: str = Field(...)
    receiver_name: str = Field(...)
    receiver_account: str = Field(...)
    receiver_bank_name: str = Field(...)
    swift_code: str = Field(..., min_length=8, max_length=11)
    receiver_country: str = Field(..., min_length=2, max_length=2)
    amount: float = Field(..., gt=0, le=1000000)
    currency: str = Field(default="USD")
    purpose: str = Field(..., description="Purpose of wire transfer")


class PaymentResponse(BaseModel):
    transaction_id: str
    status: PaymentStatus
    reason: str
    amount: float
    biller_name: Optional[str] = None
    confirmation_number: Optional[str] = None
    processing_time_ms: float