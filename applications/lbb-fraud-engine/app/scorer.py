"""LBB Fraud Scorer — ML + rules-based scoring"""
import os
import json
import logging
from app.models import FraudScoringRequest, FraudScoringResult

logger = logging.getLogger("lbb-scorer")

HIGH_RISK_MCC = {"5967", "7995", "4829", "6051", "6211"}
HIGH_RISK_COUNTRIES = {"NG", "GH", "RO", "UA", "RU", "KP", "IR", "SY"}


class FraudScorer:
    def __init__(self):
        self.sagemaker_endpoint = os.environ.get("SAGEMAKER_ENDPOINT", "")
        self.use_ml = bool(self.sagemaker_endpoint)

    async def score(self, request: FraudScoringRequest) -> FraudScoringResult:
        if self.use_ml:
            try:
                return await self._ml_score(request)
            except Exception as e:
                logger.error(f"ML scoring failed: {e}. Falling back to rules.")
        return self._rule_score(request)

    def _rule_score(self, req: FraudScoringRequest) -> FraudScoringResult:
        score = 0
        factors = []

        if req.amount > req.avg_transaction_amount * 5:
            score += 25
            factors.append(f"Amount {req.amount/max(req.avg_transaction_amount,1):.0f}x above average")
        elif req.amount > req.avg_transaction_amount * 3:
            score += 15
            factors.append("Amount elevated above average")

        if req.merchant_category in HIGH_RISK_MCC:
            score += 20
            factors.append("High-risk merchant category")

        if req.country_code in HIGH_RISK_COUNTRIES:
            score += 30
            factors.append(f"High-risk country: {req.country_code}")
        elif req.is_international:
            score += 10
            factors.append("International transaction")

        if 1 <= req.hour_of_day <= 5:
            score += 10
            factors.append("Late night transaction")

        if req.transactions_last_hour > 10:
            score += 25
            factors.append(f"High velocity: {req.transactions_last_hour} txns/hour")
        elif req.transactions_last_hour > 5:
            score += 10
            factors.append("Elevated transaction velocity")

        if not req.pin_verified and req.amount > 500:
            score += 10
            factors.append("High value without PIN verification")

        score = min(score, 100)
        rec = "DENY" if score >= 80 else "STEP_UP" if score >= 50 else "APPROVE"

        return FraudScoringResult(
            score=score, recommendation=rec,
            factors=factors, model_version="rules-v1.0"
        )

    async def _ml_score(self, req: FraudScoringRequest) -> FraudScoringResult:
        import boto3
        sagemaker = boto3.client("sagemaker-runtime")
        features = {
            "amount": req.amount, "mcc": req.merchant_category,
            "country": req.country_code, "hour": req.hour_of_day,
            "day": req.day_of_week, "avg_amount": req.avg_transaction_amount,
            "velocity": req.transactions_last_hour,
            "is_intl": 1 if req.is_international else 0,
            "high_risk_mcc": 1 if req.merchant_category in HIGH_RISK_MCC else 0,
            "high_risk_country": 1 if req.country_code in HIGH_RISK_COUNTRIES else 0,
        }
        response = sagemaker.invoke_endpoint(
            EndpointName=self.sagemaker_endpoint,
            ContentType="application/json",
            Body=json.dumps(features)
        )
        result = json.loads(response["Body"].read().decode())
        ml_score = float(result.get("score", 0)) * 100
        rec = "DENY" if ml_score >= 80 else "STEP_UP" if ml_score >= 50 else "APPROVE"
        return FraudScoringResult(
            score=ml_score, recommendation=rec,
            factors=result.get("factors", ["ML prediction"]),
            model_version=result.get("model_version", "xgboost-v1.0")
        )
