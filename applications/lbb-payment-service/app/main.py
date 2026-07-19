"""
LBB Payment Service
=====================
Mimics BofA/AmEx payment processing engine.

Handles:
  P2P transfers (like Zelle)
  Bill payments
  Wire transfers
  ACH processing
  AML/sanctions screening on every transaction

Deployed in: Amex-Core-Banking account (640252939043)
Security: Private VPC, encrypted RDS, Secrets Manager
"""
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import time
import uuid
import os

from app.models import (
    PaymentRequest, PaymentResponse, PaymentStatus,
    TransferRequest, TransferResponse,
    WireTransferRequest, BillPaymentRequest
)
from app.aml_check import AMLScreener
from app.processor import PaymentProcessor
from app.database import get_db, init_db
from app.auth import verify_api_key
from app.config import settings

logger = logging.getLogger("lbb-payment-service")
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("LBB Payment Service starting...")
    await init_db()
    yield
    logger.info("LBB Payment Service shutting down")


app = FastAPI(
    title="LBB Payment Service",
    description="PCI-DSS compliant payment processing for BOA-AMEX-TechResolved",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_methods=["POST", "GET"],
    allow_headers=["Authorization", "Content-Type"],
)

aml_screener = AMLScreener()
payment_processor = PaymentProcessor()


@app.post(
    "/api/v1/transfer",
    response_model=TransferResponse,
    dependencies=[Depends(verify_api_key)],
    summary="P2P money transfer (Zelle-like)",
)
async def transfer_money(
    request: TransferRequest,
    background_tasks: BackgroundTasks,
    db=Depends(get_db)
):
    """
    P2P Transfer Flow:
    1. Validate sender and receiver accounts
    2. AML/sanctions screening
    3. Check sender balance
    4. Debit sender, credit receiver
    5. Generate confirmation
    6. Log for regulatory reporting
    """
    start_time = time.time()
    transaction_id = str(uuid.uuid4())

    logger.info(f"Transfer request: {transaction_id}, from={request.sender_account}, to={request.receiver_account}, amount={request.amount}")

    # Step 1: Validate accounts
    sender = await db.fetch_one(
        "SELECT * FROM accounts WHERE account_number = :acct AND status = 'ACTIVE'",
        {"acct": request.sender_account}
    )
    if not sender:
        raise HTTPException(status_code=404, detail="Sender account not found or inactive")

    receiver = await db.fetch_one(
        "SELECT * FROM accounts WHERE account_number = :acct AND status = 'ACTIVE'",
        {"acct": request.receiver_account}
    )
    if not receiver:
        raise HTTPException(status_code=404, detail="Receiver account not found or inactive")

    # Step 2: AML/Sanctions screening
    aml_result = await aml_screener.screen(
        sender_name=sender["account_holder"],
        receiver_name=receiver["account_holder"],
        amount=request.amount,
        country=request.country_code
    )

    if aml_result.blocked:
        await _log_payment(db, transaction_id, request, "BLOCKED", aml_result.reason)
        return TransferResponse(
            transaction_id=transaction_id,
            status=PaymentStatus.BLOCKED,
            reason=f"AML screening failed: {aml_result.reason}",
            amount=request.amount,
            processing_time_ms=round((time.time() - start_time) * 1000, 2)
        )

    if aml_result.review_required:
        await _log_payment(db, transaction_id, request, "PENDING_REVIEW", aml_result.reason)
        return TransferResponse(
            transaction_id=transaction_id,
            status=PaymentStatus.PENDING_REVIEW,
            reason=f"AML review required: {aml_result.reason}",
            amount=request.amount,
            processing_time_ms=round((time.time() - start_time) * 1000, 2)
        )

    # Step 3: Check balance
    if float(sender["available_balance"]) < request.amount:
        await _log_payment(db, transaction_id, request, "DENIED", "INSUFFICIENT_FUNDS")
        raise HTTPException(status_code=400, detail="Insufficient funds")

    # Step 4: Execute transfer
    result = await payment_processor.execute_transfer(
        db=db,
        transaction_id=transaction_id,
        sender_account=request.sender_account,
        receiver_account=request.receiver_account,
        amount=request.amount,
        currency=request.currency,
        memo=request.memo
    )

    # Step 5: Background — generate confirmation + regulatory log
    background_tasks.add_task(
        _send_confirmation, request.sender_account, transaction_id, request.amount
    )
    background_tasks.add_task(
        _regulatory_log, transaction_id, request, aml_result
    )

    processing_time = round((time.time() - start_time) * 1000, 2)
    logger.info(f"Transfer COMPLETED: {transaction_id}, time={processing_time}ms")

    return TransferResponse(
        transaction_id=transaction_id,
        status=PaymentStatus.COMPLETED,
        reason="Transfer completed successfully",
        amount=request.amount,
        sender_new_balance=result["sender_balance"],
        receiver_new_balance=result["receiver_balance"],
        confirmation_number=result["confirmation"],
        processing_time_ms=processing_time
    )


@app.post(
    "/api/v1/bill-payment",
    response_model=PaymentResponse,
    dependencies=[Depends(verify_api_key)],
    summary="Bill payment processing",
)
async def pay_bill(request: BillPaymentRequest, db=Depends(get_db)):
    """Process bill payment — utility, credit card, mortgage"""
    transaction_id = str(uuid.uuid4())
    start_time = time.time()

    # Validate payer account
    payer = await db.fetch_one(
        "SELECT * FROM accounts WHERE account_number = :acct AND status = 'ACTIVE'",
        {"acct": request.payer_account}
    )
    if not payer:
        raise HTTPException(status_code=404, detail="Payer account not found")

    if float(payer["available_balance"]) < request.amount:
        raise HTTPException(status_code=400, detail="Insufficient funds")

    # AML screening
    aml_result = await aml_screener.screen(
        sender_name=payer["account_holder"],
        receiver_name=request.biller_name,
        amount=request.amount,
        country="US"
    )

    if aml_result.blocked:
        return PaymentResponse(
            transaction_id=transaction_id,
            status=PaymentStatus.BLOCKED,
            reason=f"AML: {aml_result.reason}",
            amount=request.amount,
            processing_time_ms=round((time.time() - start_time) * 1000, 2)
        )

    # Process payment
    await db.execute(
        "UPDATE accounts SET available_balance = available_balance - :amount WHERE account_number = :acct",
        {"amount": request.amount, "acct": request.payer_account}
    )

    await _log_payment(db, transaction_id, request, "COMPLETED", "Bill payment processed")

    return PaymentResponse(
        transaction_id=transaction_id,
        status=PaymentStatus.COMPLETED,
        reason="Bill payment processed successfully",
        amount=request.amount,
        biller_name=request.biller_name,
        confirmation_number=f"BP-{uuid.uuid4().hex[:8].upper()}",
        processing_time_ms=round((time.time() - start_time) * 1000, 2)
    )


@app.post(
    "/api/v1/wire-transfer",
    response_model=PaymentResponse,
    dependencies=[Depends(verify_api_key)],
    summary="Wire transfer processing",
)
async def wire_transfer(request: WireTransferRequest, db=Depends(get_db)):
    """Process wire transfer — domestic and international"""
    transaction_id = str(uuid.uuid4())
    start_time = time.time()

    # Wire transfers get enhanced AML screening
    aml_result = await aml_screener.screen_enhanced(
        sender_name=request.sender_name,
        receiver_name=request.receiver_name,
        amount=request.amount,
        sender_country="US",
        receiver_country=request.receiver_country,
        receiver_bank_swift=request.swift_code
    )

    if aml_result.blocked:
        await _log_payment(db, transaction_id, request, "BLOCKED", aml_result.reason)
        logger.warning(f"Wire BLOCKED by AML: {transaction_id}, reason={aml_result.reason}")
        return PaymentResponse(
            transaction_id=transaction_id,
            status=PaymentStatus.BLOCKED,
            reason=f"AML screening: {aml_result.reason}",
            amount=request.amount,
            processing_time_ms=round((time.time() - start_time) * 1000, 2)
        )

    # Wire transfers always require manual review for amounts > $10,000
    # BSA/AML Currency Transaction Report (CTR) threshold
    if request.amount >= 10000:
        await _log_payment(db, transaction_id, request, "PENDING_REVIEW", "CTR threshold exceeded")
        logger.info(f"Wire PENDING review (CTR): {transaction_id}, amount=${request.amount}")
        return PaymentResponse(
            transaction_id=transaction_id,
            status=PaymentStatus.PENDING_REVIEW,
            reason="Amount exceeds CTR threshold ($10,000). Manual review required per BSA/AML.",
            amount=request.amount,
            processing_time_ms=round((time.time() - start_time) * 1000, 2)
        )

    await _log_payment(db, transaction_id, request, "COMPLETED", "Wire transfer processed")

    return PaymentResponse(
        transaction_id=transaction_id,
        status=PaymentStatus.COMPLETED,
        reason="Wire transfer submitted for processing",
        amount=request.amount,
        confirmation_number=f"WT-{uuid.uuid4().hex[:8].upper()}",
        processing_time_ms=round((time.time() - start_time) * 1000, 2)
    )


@app.get("/api/v1/transactions/{account_number}",
         dependencies=[Depends(verify_api_key)])
async def get_transactions(account_number: str, limit: int = 50, db=Depends(get_db)):
    """Get transaction history for an account"""
    transactions = await db.fetch_all(
        """SELECT transaction_id, amount, currency, status, reason, 
                  transaction_type, created_at
           FROM payment_log 
           WHERE sender_account = :acct OR receiver_account = :acct
           ORDER BY created_at DESC LIMIT :limit""",
        {"acct": account_number, "limit": limit}
    )
    return {"account": account_number, "transactions": [dict(t) for t in transactions]}


@app.get("/api/v1/health")
async def health_check():
    return {"status": "healthy", "service": "lbb-payment-service", "version": "1.0.0"}


async def _log_payment(db, transaction_id, request, status, reason):
    """Immutable payment audit log — BSA/AML requirement"""
    sender = getattr(request, 'sender_account', getattr(request, 'payer_account', 'N/A'))
    receiver = getattr(request, 'receiver_account', getattr(request, 'biller_name', 'N/A'))
    tx_type = "TRANSFER" if hasattr(request, 'receiver_account') else "BILL_PAY" if hasattr(request, 'biller_name') else "WIRE"

    await db.execute("""
        INSERT INTO payment_log
        (transaction_id, sender_account, receiver_account, amount, currency,
         status, reason, transaction_type)
        VALUES (:tx_id, :sender, :receiver, :amount, :currency, :status, :reason, :type)
    """, {
        "tx_id": transaction_id, "sender": sender, "receiver": receiver,
        "amount": request.amount, "currency": getattr(request, 'currency', 'USD'),
        "status": status, "reason": reason, "type": tx_type
    })


async def _send_confirmation(account, transaction_id, amount):
    """Background: send confirmation notification"""
    logger.info(f"Confirmation sent: account={account}, tx={transaction_id}, amount=${amount}")


async def _regulatory_log(transaction_id, request, aml_result):
    """Background: log for BSA/AML regulatory reporting"""
    logger.info(f"Regulatory log: tx={transaction_id}, aml_score={aml_result.risk_score}")