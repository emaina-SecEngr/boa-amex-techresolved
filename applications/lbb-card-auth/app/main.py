"""
LBB Card Authorization Service
================================
Mimics Bank of America / AmEx card authorization engine.

When a customer swipes their card:
  Merchant → Payment Network (Visa/MC) → THIS SERVICE
  → Validates card → Checks balance → Fraud check
  → Returns APPROVE/DENY in under 100ms

Deployed in: Amex-PCI-CDE account (827064972376)
Security: Isolated VPC, no internet, PrivateLink only
Encryption: CloudHSM for PAN, KMS for data at rest
"""
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import time
import os

from app.models import AuthorizationRequest, AuthorizationResponse, TransactionLog
from app.tokenizer import Tokenizer
from app.fraud_check import FraudChecker
from app.database import get_db, init_db
from app.auth import verify_api_key
from app.config import settings

logger = logging.getLogger("lbb-card-auth")
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database and services on startup"""
    logger.info("LBB Card Authorization Service starting...")
    await init_db()
    logger.info("Database initialized")
    yield
    logger.info("LBB Card Authorization Service shutting down")


app = FastAPI(
    title="LBB Card Authorization Service",
    description="PCI-DSS compliant card authorization engine for BOA-AMEX-TechResolved",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url=None,
)

# CORS — restricted in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_methods=["POST"],
    allow_headers=["Authorization", "Content-Type"],
)

tokenizer = Tokenizer()
fraud_checker = FraudChecker()


@app.post(
    "/api/v1/authorize",
    response_model=AuthorizationResponse,
    dependencies=[Depends(verify_api_key)],
    summary="Authorize a card transaction",
    description="Receives authorization request from payment network, validates card, checks balance, runs fraud check, returns approve/deny"
)
async def authorize_transaction(
    request: AuthorizationRequest,
    http_request: Request,
    db=Depends(get_db)
):
    """
    Card Authorization Flow:
    1. Receive PAN + amount + merchant from payment network
    2. Tokenize PAN immediately (clear PAN never stored)
    3. Look up account by token
    4. Check card status (active, frozen, expired)
    5. Check available balance
    6. Run fraud scoring
    7. Apply authorization decision
    8. Log transaction (with token, never PAN)
    9. Return approve/deny with auth code
    """
    start_time = time.time()
    source_ip = http_request.client.host

    # Step 1: Tokenize PAN immediately — clear PAN never stored
    token = tokenizer.tokenize(request.pan)
    logger.info(f"Authorization request: token={token[:8]}..., amount={request.amount}, merchant={request.merchant_id}")

    # Step 2: Look up account by token
    account = await db.fetch_one(
        "SELECT * FROM card_accounts WHERE card_token = :token AND status = 'ACTIVE'",
        {"token": token}
    )

    if not account:
        return _build_response(
            token=token,
            status="DENIED",
            reason="CARD_NOT_FOUND",
            amount=request.amount,
            processing_time=time.time() - start_time
        )

    # Step 3: Check card status
    if account["card_status"] == "FROZEN":
        await _log_transaction(db, token, request, "DENIED", "CARD_FROZEN", source_ip)
        return _build_response(
            token=token,
            status="DENIED",
            reason="CARD_FROZEN",
            amount=request.amount,
            processing_time=time.time() - start_time
        )

    if account["card_status"] == "EXPIRED":
        await _log_transaction(db, token, request, "DENIED", "CARD_EXPIRED", source_ip)
        return _build_response(
            token=token,
            status="DENIED",
            reason="CARD_EXPIRED",
            amount=request.amount,
            processing_time=time.time() - start_time
        )

    # Step 4: Check available balance
    available_balance = float(account["available_balance"])
    if request.amount > available_balance:
        await _log_transaction(db, token, request, "DENIED", "INSUFFICIENT_FUNDS", source_ip)
        return _build_response(
            token=token,
            status="DENIED",
            reason="INSUFFICIENT_FUNDS",
            amount=request.amount,
            processing_time=time.time() - start_time
        )

    # Step 5: Run fraud scoring
    fraud_result = await fraud_checker.check(
        token=token,
        amount=request.amount,
        merchant_id=request.merchant_id,
        merchant_category=request.merchant_category_code,
        source_ip=source_ip,
        country=request.country_code,
        account_history=account
    )

    if fraud_result.score >= 80:
        await _log_transaction(db, token, request, "DENIED", f"FRAUD_SCORE_{fraud_result.score}", source_ip)
        return _build_response(
            token=token,
            status="DENIED",
            reason="FRAUD_SUSPECTED",
            fraud_score=fraud_result.score,
            amount=request.amount,
            processing_time=time.time() - start_time
        )

    if fraud_result.score >= 50:
        await _log_transaction(db, token, request, "STEP_UP", f"FRAUD_SCORE_{fraud_result.score}", source_ip)
        return _build_response(
            token=token,
            status="STEP_UP_REQUIRED",
            reason="ADDITIONAL_VERIFICATION_NEEDED",
            fraud_score=fraud_result.score,
            amount=request.amount,
            processing_time=time.time() - start_time
        )

    # Step 6: Approve — deduct from available balance
    new_balance = available_balance - request.amount
    await db.execute(
        "UPDATE card_accounts SET available_balance = :balance, last_transaction_at = NOW() WHERE card_token = :token",
        {"balance": new_balance, "token": token}
    )

    # Step 7: Log approved transaction
    auth_code = tokenizer.generate_auth_code()
    await _log_transaction(db, token, request, "APPROVED", auth_code, source_ip)

    processing_time = time.time() - start_time
    logger.info(f"APPROVED: token={token[:8]}..., amount={request.amount}, auth_code={auth_code}, time={processing_time:.3f}s")

    return _build_response(
        token=token,
        status="APPROVED",
        reason="TRANSACTION_APPROVED",
        auth_code=auth_code,
        fraud_score=fraud_result.score,
        amount=request.amount,
        remaining_balance=new_balance,
        processing_time=processing_time
    )


@app.post(
    "/api/v1/tokenize",
    dependencies=[Depends(verify_api_key)],
    summary="Tokenize a PAN",
    description="Replaces card number with irreversible token. Only this service can reverse the tokenization."
)
async def tokenize_pan(request: dict):
    """Tokenize a PAN — returns token, never stores clear PAN"""
    pan = request.get("pan", "")
    if not pan or len(pan) < 13 or len(pan) > 19:
        raise HTTPException(status_code=400, detail="Invalid PAN length")

    token = tokenizer.tokenize(pan)
    last_four = pan[-4:]

    return {
        "token": token,
        "last_four": last_four,
        "token_type": "PCI_TOKEN",
        "message": "PAN tokenized successfully. Clear PAN not stored."
    }


@app.get(
    "/api/v1/health",
    summary="Health check",
    description="Returns service health status for ALB health checks"
)
async def health_check():
    return {
        "status": "healthy",
        "service": "lbb-card-auth",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT
    }


@app.get(
    "/api/v1/metrics",
    dependencies=[Depends(verify_api_key)],
    summary="Service metrics",
    description="Returns transaction metrics for monitoring"
)
async def metrics(db=Depends(get_db)):
    """Returns transaction metrics for CloudWatch/Sentinel"""
    stats = await db.fetch_one("""
        SELECT 
            COUNT(*) as total_transactions,
            COUNT(CASE WHEN status = 'APPROVED' THEN 1 END) as approved,
            COUNT(CASE WHEN status = 'DENIED' THEN 1 END) as denied,
            COUNT(CASE WHEN status = 'STEP_UP_REQUIRED' THEN 1 END) as step_up,
            AVG(processing_time_ms) as avg_processing_time,
            MAX(processing_time_ms) as max_processing_time
        FROM transaction_log
        WHERE created_at > NOW() - INTERVAL '1 hour'
    """)
    return {
        "period": "last_1_hour",
        "total_transactions": stats["total_transactions"],
        "approved": stats["approved"],
        "denied": stats["denied"],
        "step_up_required": stats["step_up"],
        "approval_rate": f"{(stats['approved'] / max(stats['total_transactions'], 1)) * 100:.1f}%",
        "avg_processing_time_ms": f"{stats['avg_processing_time']:.1f}",
        "max_processing_time_ms": f"{stats['max_processing_time']:.1f}",
        "sla_target_ms": 100
    }


def _build_response(token, status, reason, amount, processing_time, 
                     auth_code=None, fraud_score=None, remaining_balance=None):
    """Build standardized authorization response"""
    return AuthorizationResponse(
        token=token,
        status=status,
        reason=reason,
        auth_code=auth_code or "",
        fraud_score=fraud_score,
        amount=amount,
        remaining_balance=remaining_balance,
        processing_time_ms=round(processing_time * 1000, 2),
        timestamp=time.time()
    )


async def _log_transaction(db, token, request, status, reason, source_ip):
    """Log transaction to immutable audit trail"""
    await db.execute("""
        INSERT INTO transaction_log 
        (card_token, amount, currency, merchant_id, merchant_category_code,
         country_code, status, reason, source_ip, processing_time_ms)
        VALUES (:token, :amount, :currency, :merchant_id, :mcc,
                :country, :status, :reason, :source_ip, :time_ms)
    """, {
        "token": token,
        "amount": request.amount,
        "currency": request.currency,
        "merchant_id": request.merchant_id,
        "mcc": request.merchant_category_code,
        "country": request.country_code,
        "status": status,
        "reason": reason,
        "source_ip": source_ip,
        "time_ms": 0
    })