"""
LBB Fraud Check Engine
=======================
Rules-based fraud scoring for card authorization.
In production: calls SageMaker endpoint for ML scoring.
In development: uses rule-based scoring.

Scoring:
  0-49:  LOW risk    → APPROVE
  50-79: MEDIUM risk → STEP_UP (request OTP from cardholder)
  80-100: HIGH risk  → DENY

Risk factors analyzed:
  Transaction amount vs account average
  Merchant category risk level
  Geographic anomaly (country mismatch)
  Time of day (late night = higher risk)
  Transaction velocity (many transactions in short time)
"""
from app.models import FraudResult
from datetime import datetime
import os
import logging

logger = logging.getLogger("lbb-fraud-check")

# High-risk merchant categories (MCC codes)
HIGH_RISK_MCC = {
    "5967": "Direct Marketing",
    "5966": "Direct Marketing - Outbound",
    "7995": "Gambling",
    "5912": "Drug Stores",
    "4829": "Wire Transfer",
    "6051": "Cryptocurrency",
    "6211": "Securities/Brokers",
}

# High-risk countries
HIGH_RISK_COUNTRIES = {
    "NG", "GH", "RO", "UA", "RU", "CN", "KP", "IR", "SY", "VE"
}


class FraudChecker:
    """Rule-based fraud scoring engine"""

    def __init__(self):
        self.sagemaker_endpoint = os.environ.get("SAGEMAKER_FRAUD_ENDPOINT", "")
        self.use_ml = bool(self.sagemaker_endpoint)

    async def check(self, token: str, amount: float, merchant_id: str,
                    merchant_category: str, source_ip: str, country: str,
                    account_history: dict) -> FraudResult:
        """
        Score transaction for fraud risk.
        Returns FraudResult with score 0-100 and risk factors.
        """
        if self.use_ml:
            return await self._ml_score(
                token, amount, merchant_id, merchant_category,
                source_ip, country, account_history
            )
        return await self._rule_score(
            token, amount, merchant_id, merchant_category,
            source_ip, country, account_history
        )

    async def _rule_score(self, token, amount, merchant_id,
                          merchant_category, source_ip, country,
                          account_history) -> FraudResult:
        """Rule-based scoring for development"""
        score = 0
        factors = []

        # Rule 1: Amount anomaly
        avg_transaction = float(account_history.get("avg_transaction_amount", 50))
        if amount > avg_transaction * 5:
            score += 25
            factors.append(f"Amount ${amount} is {amount/max(avg_transaction,1):.0f}x average ${avg_transaction}")
        elif amount > avg_transaction * 3:
            score += 15
            factors.append(f"Amount ${amount} is {amount/max(avg_transaction,1):.0f}x average")
        elif amount > 5000:
            score += 10
            factors.append(f"High value transaction: ${amount}")

        # Rule 2: High-risk merchant category
        if merchant_category in HIGH_RISK_MCC:
            score += 20
            factors.append(f"High-risk merchant category: {HIGH_RISK_MCC[merchant_category]}")

        # Rule 3: Geographic anomaly
        account_country = account_history.get("home_country", "US")
        if country != account_country:
            if country in HIGH_RISK_COUNTRIES:
                score += 30
                factors.append(f"Transaction from high-risk country: {country}")
            else:
                score += 10
                factors.append(f"International transaction: {country} (home: {account_country})")

        # Rule 4: Late night transaction (higher risk)
        current_hour = datetime.utcnow().hour
        if 1 <= current_hour <= 5:
            score += 10
            factors.append(f"Late night transaction: {current_hour}:00 UTC")

        # Rule 5: Card not present (e-commerce)
        # Higher risk than chip/contactless
        if not account_history.get("pin_verified", False):
            score += 5
            factors.append("Card-not-present or PIN not verified")

        # Rule 6: Transaction velocity
        recent_count = int(account_history.get("transactions_last_hour", 0))
        if recent_count > 10:
            score += 25
            factors.append(f"High velocity: {recent_count} transactions in last hour")
        elif recent_count > 5:
            score += 10
            factors.append(f"Elevated velocity: {recent_count} transactions in last hour")

        # Cap score at 100
        score = min(score, 100)

        # Determine recommendation
        if score >= 80:
            recommendation = "DENY"
        elif score >= 50:
            recommendation = "STEP_UP"
        else:
            recommendation = "APPROVE"

        logger.info(f"Fraud check: token={token[:8]}..., score={score}, recommendation={recommendation}, factors={len(factors)}")

        return FraudResult(
            score=score,
            factors=factors,
            recommendation=recommendation
        )

    async def _ml_score(self, token, amount, merchant_id,
                        merchant_category, source_ip, country,
                        account_history) -> FraudResult:
        """
        ML-based scoring via SageMaker endpoint.
        In production: calls real SageMaker inference endpoint.
        Model: XGBoost trained on historical transaction data.
        """
        import boto3
        import json

        try:
            sagemaker = boto3.client("sagemaker-runtime")

            features = {
                "amount": amount,
                "merchant_category": merchant_category,
                "country": country,
                "hour_of_day": datetime.utcnow().hour,
                "day_of_week": datetime.utcnow().weekday(),
                "avg_transaction": float(account_history.get("avg_transaction_amount", 50)),
                "transactions_last_hour": int(account_history.get("transactions_last_hour", 0)),
                "is_international": 1 if country != account_history.get("home_country", "US") else 0,
                "is_high_risk_mcc": 1 if merchant_category in HIGH_RISK_MCC else 0,
                "is_high_risk_country": 1 if country in HIGH_RISK_COUNTRIES else 0,
            }

            response = sagemaker.invoke_endpoint(
                EndpointName=self.sagemaker_endpoint,
                ContentType="application/json",
                Body=json.dumps(features)
            )

            result = json.loads(response["Body"].read().decode())
            score = float(result.get("score", 0)) * 100

            if score >= 80:
                recommendation = "DENY"
            elif score >= 50:
                recommendation = "STEP_UP"
            else:
                recommendation = "APPROVE"

            return FraudResult(
                score=score,
                factors=result.get("factors", ["ML model prediction"]),
                recommendation=recommendation
            )

        except Exception as e:
            logger.error(f"SageMaker scoring failed: {e}. Falling back to rules.")
            return await self._rule_score(
                token, amount, merchant_id, merchant_category,
                source_ip, country, account_history
            )