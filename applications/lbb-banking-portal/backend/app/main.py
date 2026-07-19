"""
LBB Banking Portal
====================
Customer-facing banking application mimicking BofA online banking.

Features:
  Account balances and transaction history
  P2P transfers (calls LBB-PaymentService)
  Bill payments
  Statement downloads (PDF)
  Profile management

Deployed in: Amex-Customer-Portal (PENDING account creation)
Security: WAF, Shield Advanced, Cognito MFA, CloudFront
"""
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
from datetime import datetime

from app.database import get_db, init_db
from app.auth import get_current_user
from app.config import settings

logger = logging.getLogger("lbb-banking-portal")
logging.basicConfig(level=logging.INFO)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("LBB Banking Portal starting...")
    await init_db()
    yield

app = FastAPI(title="LBB Banking Portal", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "PUT"],
    allow_headers=["Authorization", "Content-Type"],
)

@app.get("/api/v1/accounts", dependencies=[Depends(get_current_user)])
async def get_accounts(user=Depends(get_current_user), db=Depends(get_db)):
    """Get all accounts for authenticated customer"""
    accounts = await db.fetch_all(
        "SELECT account_number, account_type, available_balance, currency, status FROM customer_accounts WHERE customer_id = :cid",
        {"cid": user["customer_id"]}
    )
    return {"customer_id": user["customer_id"], "accounts": [dict(a) for a in accounts]}

@app.get("/api/v1/accounts/{account_number}/balance", dependencies=[Depends(get_current_user)])
async def get_balance(account_number: str, user=Depends(get_current_user), db=Depends(get_db)):
    """Get account balance"""
    account = await db.fetch_one(
        "SELECT available_balance, pending_balance, currency FROM customer_accounts WHERE account_number = :acct AND customer_id = :cid",
        {"acct": account_number, "cid": user["customer_id"]}
    )
    if not account:
        raise HTTPException(404, "Account not found")
    return {
        "account_number": account_number,
        "available_balance": float(account["available_balance"]),
        "pending_balance": float(account["pending_balance"]),
        "currency": account["currency"],
        "as_of": datetime.utcnow().isoformat()
    }

@app.get("/api/v1/accounts/{account_number}/transactions", dependencies=[Depends(get_current_user)])
async def get_transactions(account_number: str, limit: int = 50, user=Depends(get_current_user), db=Depends(get_db)):
    """Get transaction history for an account"""
    transactions = await db.fetch_all(
        """SELECT transaction_id, amount, currency, description, category,
                  transaction_type, status, created_at
           FROM transactions
           WHERE account_number = :acct AND customer_id = :cid
           ORDER BY created_at DESC LIMIT :limit""",
        {"acct": account_number, "cid": user["customer_id"], "limit": limit}
    )
    return {"account_number": account_number, "transactions": [dict(t) for t in transactions]}

@app.post("/api/v1/transfers", dependencies=[Depends(get_current_user)])
async def initiate_transfer(request: dict, user=Depends(get_current_user), db=Depends(get_db)):
    """Initiate P2P transfer — calls LBB-PaymentService internally"""
    import httpx
    import uuid

    # Verify sender owns the account
    sender = await db.fetch_one(
        "SELECT * FROM customer_accounts WHERE account_number = :acct AND customer_id = :cid",
        {"acct": request.get("from_account"), "cid": user["customer_id"]}
    )
    if not sender:
        raise HTTPException(403, "You do not own this account")

    # Call LBB-PaymentService for actual transfer processing
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{settings.PAYMENT_SERVICE_URL}/api/v1/transfer",
                json={
                    "sender_account": request["from_account"],
                    "receiver_account": request["to_account"],
                    "amount": request["amount"],
                    "memo": request.get("memo", "")
                },
                headers={"X-API-Key": settings.INTERNAL_API_KEY},
                timeout=30
            )
            return response.json()
    except Exception as e:
        logger.error(f"Payment service call failed: {e}")
        raise HTTPException(503, "Payment service temporarily unavailable")

@app.get("/api/v1/statements/{account_number}", dependencies=[Depends(get_current_user)])
async def get_statements(account_number: str, user=Depends(get_current_user), db=Depends(get_db)):
    """List available statements for download"""
    statements = await db.fetch_all(
        """SELECT statement_id, period, generated_at, download_url
           FROM statements
           WHERE account_number = :acct AND customer_id = :cid
           ORDER BY period DESC LIMIT 12""",
        {"acct": account_number, "cid": user["customer_id"]}
    )
    return {"account_number": account_number, "statements": [dict(s) for s in statements]}

@app.get("/api/v1/profile", dependencies=[Depends(get_current_user)])
async def get_profile(user=Depends(get_current_user), db=Depends(get_db)):
    """Get customer profile"""
    profile = await db.fetch_one(
        "SELECT customer_id, first_name, last_name, email, phone, mfa_enabled, last_login FROM customers WHERE customer_id = :cid",
        {"cid": user["customer_id"]}
    )
    if not profile:
        raise HTTPException(404, "Profile not found")
    return dict(profile)

@app.get("/api/v1/health")
async def health_check():
    return {"status": "healthy", "service": "lbb-banking-portal", "version": "1.0.0"}
