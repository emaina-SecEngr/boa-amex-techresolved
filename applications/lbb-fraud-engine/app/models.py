"""LBB Fraud Engine — Data Models"""
from pydantic import BaseModel, Field
from typing import Optional


class FraudScoringRequest(BaseModel):
    card_token: str = Field(..., description="Tokenized card identifier")
    amount: float = Field(..., gt=0)
    merchant_id: str = Field(...)
    merchant_category: str = Field(default="5999")
    country_code: str = Field(default="US")
    entry_mode: str = Field(default="CHIP")
    hour_of_day: int = Field(default=12, ge=0, le=23)
    day_of_week: int = Field(default=1, ge=0, le=6)
    avg_transaction_amount: float = Field(default=50.0)
    transactions_last_hour: int = Field(default=0)
    is_international: bool = Field(default=False)
    pin_verified: bool = Field(default=False)


class FraudScoringResult(BaseModel):
    score: float = Field(..., ge=0, le=100)
    recommendation: str
    factors: list[str] = []
    model_version: str = "rules-v1.0"


class FraudScoringResponse(BaseModel):
    scoring_id: str
    score: float
    recommendation: str
    factors: list[str]
    model_version: str
    processing_time_ms: float


class BatchScoringRequest(BaseModel):
    transactions: list[FraudScoringRequest]


class FraudAlert(BaseModel):
    alert_id: str
    card_token: str
    score: float
    amount: float
    factors: list[str]


class FraudCase(BaseModel):
    case_id: str
    card_token: str
    fraud_score: float
    amount: float
    status: str


class CaseStatus(BaseModel):
    status: str
    notes: Optional[str] = None


class ModelMetrics(BaseModel):
    total_scorings_24h: int
    avg_score: float
    high_risk_24h: int
    medium_risk_24h: int
    low_risk_24h: int
    avg_latency_ms: float
    model_precision: float
    model_recall: float
    model_f1: float
    false_positive_rate: float
