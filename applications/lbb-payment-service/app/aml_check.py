"""
LBB AML/Sanctions Screening
==============================
Anti-Money Laundering and sanctions screening
for every payment transaction.

BSA/AML Requirements:
  Screen against OFAC SDN list (sanctions)
  Flag transactions > $10,000 for CTR
  Detect structuring (splitting to avoid CTR)
  Monitor for suspicious activity patterns
  File SARs for suspicious transactions

In production: calls external AML vendor API
  (Actimize, Fircosoft, World-Check)
In development: rules-based screening
"""
from pydantic import BaseModel
from typing import Optional
import logging

logger = logging.getLogger("lbb-aml")

# OFAC Specially Designated Nationals (SDN) — sample list
# In production: full OFAC list updated daily
SANCTIONED_ENTITIES = {
    "NORTH KOREA", "DPIK", "IRGC", "HEZBOLLAH",
    "AL-QAEDA", "ISIS", "TALIBAN"
}

# High-risk countries for wire transfers
HIGH_RISK_COUNTRIES = {
    "KP": "North Korea", "IR": "Iran", "SY": "Syria",
    "CU": "Cuba", "RU": "Russia", "MM": "Myanmar",
    "VE": "Venezuela", "SD": "Sudan", "SO": "Somalia"
}

# Structuring detection threshold
CTR_THRESHOLD = 10000
STRUCTURING_THRESHOLD = 8000  # Suspiciously close to $10K


class AMLResult(BaseModel):
    blocked: bool = False
    review_required: bool = False
    reason: str = ""
    risk_score: float = 0
    flags: list[str] = []


class AMLScreener:

    async def screen(self, sender_name: str, receiver_name: str,
                     amount: float, country: str) -> AMLResult:
        """Standard AML screening for domestic transfers"""
        flags = []
        risk_score = 0

        # Check sanctions list
        for entity in SANCTIONED_ENTITIES:
            if entity.lower() in sender_name.lower() or entity.lower() in receiver_name.lower():
                logger.warning(f"SANCTIONS HIT: {sender_name} or {receiver_name} matches {entity}")
                return AMLResult(
                    blocked=True,
                    reason=f"OFAC sanctions match: {entity}",
                    risk_score=100,
                    flags=["OFAC_SDN_MATCH"]
                )

        # CTR threshold
        if amount >= CTR_THRESHOLD:
            flags.append("CTR_THRESHOLD_EXCEEDED")
            risk_score += 30

        # Structuring detection
        if STRUCTURING_THRESHOLD <= amount < CTR_THRESHOLD:
            flags.append("POSSIBLE_STRUCTURING")
            risk_score += 20

        # High-risk country
        if country in HIGH_RISK_COUNTRIES:
            flags.append(f"HIGH_RISK_COUNTRY_{country}")
            risk_score += 25

        # Large round amounts (common in laundering)
        if amount >= 5000 and amount == int(amount):
            flags.append("LARGE_ROUND_AMOUNT")
            risk_score += 10

        review_required = risk_score >= 40

        return AMLResult(
            blocked=False,
            review_required=review_required,
            reason="; ".join(flags) if flags else "CLEAR",
            risk_score=min(risk_score, 100),
            flags=flags
        )

    async def screen_enhanced(self, sender_name: str, receiver_name: str,
                               amount: float, sender_country: str,
                               receiver_country: str,
                               receiver_bank_swift: str) -> AMLResult:
        """Enhanced AML screening for wire transfers"""
        # Run standard screening first
        result = await self.screen(sender_name, receiver_name, amount, receiver_country)

        if result.blocked:
            return result

        additional_flags = list(result.flags)
        additional_score = result.risk_score

        # International wire to high-risk country
        if receiver_country in HIGH_RISK_COUNTRIES:
            additional_flags.append(f"WIRE_TO_HIGH_RISK_{HIGH_RISK_COUNTRIES[receiver_country]}")
            additional_score += 30

        # Large international wire
        if amount > 50000 and receiver_country != sender_country:
            additional_flags.append("LARGE_INTERNATIONAL_WIRE")
            additional_score += 15

        # Wire to non-FATF country (simplified check)
        non_fatf = {"KP", "IR", "MM", "SO"}
        if receiver_country in non_fatf:
            additional_flags.append("NON_FATF_JURISDICTION")
            additional_score += 40
            return AMLResult(
                blocked=True,
                reason=f"Wire to non-FATF jurisdiction: {receiver_country}",
                risk_score=100,
                flags=additional_flags
            )

        review_required = additional_score >= 40

        return AMLResult(
            blocked=False,
            review_required=review_required,
            reason="; ".join(additional_flags) if additional_flags else "CLEAR",
            risk_score=min(additional_score, 100),
            flags=additional_flags
        )