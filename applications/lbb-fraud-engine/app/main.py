"""
LBB Fraud Detection Engine
=============================
Mimics BofA/AmEx real-time fraud scoring platform.

Analyzes every transaction in real-time using ML:
  Score 0-49:  LOW risk    → APPROVE
  Score 50-79: MEDIUM risk → STEP_UP (OTP verification)
  Score 80-100: HIGH risk  → DENY + alert fraud team

ML Pipeline:
  Training: SageMaker Training Job (XGBoost)
  Inference: SageMaker Real-Time Endpoint
  Monitoring: SageMaker Model Monitor (drift detection)
  Fallback: rule-based scoring if ML endpoint unavailable

Deployed in: Amex-Fraud-Detection account (558567544266)
Security: Private VPC, SageMaker VPC endpoints, KMS encrypted models
"""
from fastapi import FastAPI, Depends, BackgroundTasks
from contextlib import asynccontextmanager
import logging
import time
import uuid
import os

from app.models import (
    FraudScoringRequest, FraudScoringResponse,
    FraudAlert, FraudCase, CaseStatus,
    ModelMetrics, BatchScoringRequest
)
from app.scorer import FraudScorer
from app.database import get_db, init_db
from app.auth import verify_api_key
from app.config import settings

logger = logging.getLogger("lbb-fraud-engine")
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("LBB Fraud Detection Engine starting...")
    logger.info(f"ML Endpoint: {settings.SAGEMAKER_ENDPOINT or 'rules-based fallback'}")
    await init_db()
    yield
    logger.info("LBB Fraud Detection Engine shutting down")


app = FastAPI(
    title="LBB Fraud Detection Engine",
    description="Real-time ML fraud scoring for BOA-AMEX-TechResolved",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
)

scorer = FraudScorer()


@app.post(
    "/api/v1/score",
    response_model=FraudScoringResponse,
    dependencies=[Depends(verify_api_key)],
    summary="Score a transaction for fraud risk",
    description="Real-time fraud scoring — returns risk score 0-100 with contributing factors"
)
async def score_transaction(
    request: FraudScoringRequest,
    background_tasks: BackgroundTasks,
    db=Depends(get_db)
):
    """
    Fraud Scoring Flow:
    1. Extract features from transaction
    2. Call SageMaker endpoint (or rule-based fallback)
    3. Return score + factors + recommendation
    4. Log scoring result for model monitoring
    5. If HIGH risk: create fraud case + alert team
    """
    start_time = time.time()
    scoring_id = str(uuid.uuid4())

    # Score the transaction
    result = await scorer.score(request)

    processing_time = round((time.time() - start_time) * 1000, 2)

    # Log scoring result
    background_tasks.add_task(
        _log_scoring, db, scoring_id, request, result, processing_time
    )

    # Create fraud case if HIGH risk
    if result.score >= 80:
        background_tasks.add_task(
            _create_fraud_case, db, scoring_id, request, result
        )

    logger.info(
        f"Scored: {scoring_id}, token={request.card_token[:8]}..., "
        f"score={result.score}, recommendation={result.recommendation}, "
        f"time={processing_time}ms"
    )

    return FraudScoringResponse(
        scoring_id=scoring_id,
        score=result.score,
        recommendation=result.recommendation,
        factors=result.factors,
        model_version=result.model_version,
        processing_time_ms=processing_time
    )


@app.post(
    "/api/v1/score/batch",
    dependencies=[Depends(verify_api_key)],
    summary="Batch score multiple transactions",
    description="Score multiple transactions in one call — used for historical analysis"
)
async def batch_score(request: BatchScoringRequest, db=Depends(get_db)):
    """Score multiple transactions — used for batch fraud analysis"""
    results = []
    for txn in request.transactions:
        result = await scorer.score(txn)
        results.append({
            "card_token": txn.card_token,
            "amount": txn.amount,
            "score": result.score,
            "recommendation": result.recommendation,
            "factors": result.factors
        })
    return {
        "batch_size": len(results),
        "high_risk_count": sum(1 for r in results if r["score"] >= 80),
        "medium_risk_count": sum(1 for r in results if 50 <= r["score"] < 80),
        "low_risk_count": sum(1 for r in results if r["score"] < 50),
        "results": results
    }


@app.get(
    "/api/v1/cases",
    dependencies=[Depends(verify_api_key)],
    summary="List fraud cases",
    description="Returns open fraud cases for analyst review"
)
async def list_cases(status: str = "OPEN", limit: int = 50, db=Depends(get_db)):
    """List fraud cases for analyst dashboard"""
    cases = await db.fetch_all(
        """SELECT case_id, card_token, fraud_score, amount, merchant_id,
                  status, created_at, assigned_analyst
           FROM fraud_cases
           WHERE status = :status
           ORDER BY fraud_score DESC, created_at DESC
           LIMIT :limit""",
        {"status": status, "limit": limit}
    )
    return {"cases": [dict(c) for c in cases], "total": len(cases)}


@app.patch(
    "/api/v1/cases/{case_id}",
    dependencies=[Depends(verify_api_key)],
    summary="Update fraud case status",
)
async def update_case(case_id: str, update: dict, db=Depends(get_db)):
    """Update fraud case — analyst marks as CONFIRMED, FALSE_POSITIVE, etc."""
    valid_statuses = ["OPEN", "INVESTIGATING", "CONFIRMED_FRAUD", "FALSE_POSITIVE", "CLOSED"]
    new_status = update.get("status", "")
    if new_status not in valid_statuses:
        from fastapi import HTTPException
        raise HTTPException(400, f"Invalid status. Must be one of: {valid_statuses}")

    await db.execute(
        "UPDATE fraud_cases SET status = :status, updated_at = NOW(), notes = :notes WHERE case_id = :case_id",
        {"status": new_status, "notes": update.get("notes", ""), "case_id": case_id}
    )

    logger.info(f"Fraud case {case_id} updated to {new_status}")
    return {"case_id": case_id, "status": new_status}


@app.get(
    "/api/v1/model/metrics",
    dependencies=[Depends(verify_api_key)],
    summary="Model performance metrics",
    description="Returns fraud model accuracy, precision, recall for monitoring"
)
async def model_metrics(db=Depends(get_db)):
    """Model performance metrics — fed into SageMaker Model Monitor"""
    stats = await db.fetch_one("""
        SELECT
            COUNT(*) as total_scorings,
            AVG(fraud_score) as avg_score,
            COUNT(CASE WHEN fraud_score >= 80 THEN 1 END) as high_risk,
            COUNT(CASE WHEN fraud_score >= 50 AND fraud_score < 80 THEN 1 END) as medium_risk,
            COUNT(CASE WHEN fraud_score < 50 THEN 1 END) as low_risk,
            AVG(processing_time_ms) as avg_latency_ms
        FROM scoring_log
        WHERE created_at > NOW() - INTERVAL '24 hours'
    """)

    # Calculate model accuracy from resolved cases
    accuracy = await db.fetch_one("""
        SELECT
            COUNT(*) as resolved,
            COUNT(CASE WHEN status = 'CONFIRMED_FRAUD' AND fraud_score >= 80 THEN 1 END) as true_positives,
            COUNT(CASE WHEN status = 'FALSE_POSITIVE' AND fraud_score >= 80 THEN 1 END) as false_positives,
            COUNT(CASE WHEN status = 'CONFIRMED_FRAUD' AND fraud_score < 50 THEN 1 END) as false_negatives
        FROM fraud_cases
        WHERE status IN ('CONFIRMED_FRAUD', 'FALSE_POSITIVE')
    """)

    total = max(int(accuracy["resolved"]), 1)
    tp = int(accuracy["true_positives"])
    fp = int(accuracy["false_positives"])
    fn = int(accuracy["false_negatives"])
    precision = tp / max(tp + fp, 1)
    recall = tp / max(tp + fn, 1)

    return ModelMetrics(
        total_scorings_24h=int(stats["total_scorings"]),
        avg_score=round(float(stats["avg_score"] or 0), 2),
        high_risk_24h=int(stats["high_risk"]),
        medium_risk_24h=int(stats["medium_risk"]),
        low_risk_24h=int(stats["low_risk"]),
        avg_latency_ms=round(float(stats["avg_latency_ms"] or 0), 2),
        model_precision=round(precision, 3),
        model_recall=round(recall, 3),
        model_f1=round(2 * precision * recall / max(precision + recall, 0.001), 3),
        false_positive_rate=round(fp / max(total, 1), 3)
    )


@app.get("/api/v1/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "lbb-fraud-engine",
        "version": "1.0.0",
        "ml_endpoint": settings.SAGEMAKER_ENDPOINT or "rules-based",
        "environment": settings.ENVIRONMENT
    }


async def _log_scoring(db, scoring_id, request, result, processing_time):
    """Log scoring result for model monitoring and retraining"""
    await db.execute("""
        INSERT INTO scoring_log
        (scoring_id, card_token, amount, merchant_id, merchant_category,
         country_code, fraud_score, recommendation, model_version,
         processing_time_ms)
        VALUES (:sid, :token, :amount, :merchant, :mcc, :country,
                :score, :rec, :model, :time_ms)
    """, {
        "sid": scoring_id, "token": request.card_token,
        "amount": request.amount, "merchant": request.merchant_id,
        "mcc": request.merchant_category, "country": request.country_code,
        "score": result.score, "rec": result.recommendation,
        "model": result.model_version, "time_ms": processing_time
    })


async def _create_fraud_case(db, scoring_id, request, result):
    """Create fraud case for analyst review"""
    case_id = f"FC-{uuid.uuid4().hex[:8].upper()}"
    await db.execute("""
        INSERT INTO fraud_cases
        (case_id, scoring_id, card_token, fraud_score, amount,
         merchant_id, factors, status)
        VALUES (:cid, :sid, :token, :score, :amount,
                :merchant, :factors, 'OPEN')
    """, {
        "cid": case_id, "sid": scoring_id,
        "token": request.card_token, "score": result.score,
        "amount": request.amount, "merchant": request.merchant_id,
        "factors": "; ".join(result.factors)
    })
    logger.warning(f"FRAUD CASE CREATED: {case_id}, score={result.score}, amount=${request.amount}")