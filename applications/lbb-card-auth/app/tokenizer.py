"""
LBB Card Tokenizer
===================
Replaces PAN (card number) with irreversible token.
In production: uses CloudHSM for key management.
In development: uses HMAC-SHA256.

PCI-DSS Requirement 3.4:
  "Render PAN unreadable anywhere it is stored"

After tokenization:
  4111-1111-1111-1111 → tok_a7f3b2c9d8e1f456
  Only THIS service can reverse the token
  All other services work with tokens only
  Reduces PCI scope dramatically
"""
import hashlib
import hmac
import secrets
import os


class Tokenizer:
    """PAN tokenization service — PCI-DSS compliant"""

    def __init__(self):
        # In production: key from CloudHSM via PKCS#11
        # In development: key from environment variable
        self.key = os.environ.get(
            "TOKENIZATION_KEY",
            "dev-only-key-replace-with-cloudhsm-in-production"
        ).encode()

    def tokenize(self, pan: str) -> str:
        """
        Convert PAN to token.
        Uses HMAC-SHA256 — same PAN always produces same token.
        Token cannot be reversed to PAN without the key.

        In production with CloudHSM:
          Key never leaves HSM hardware
          HMAC computed inside HSM
          Even root on EC2 cannot access the key
        """
        clean_pan = "".join(c for c in pan if c.isdigit())

        token_hash = hmac.new(
            self.key,
            clean_pan.encode(),
            hashlib.sha256
        ).hexdigest()[:32]

        return f"tok_{token_hash}"

    def detokenize(self, token: str) -> str:
        """
        Reverse token to PAN — only this service can do this.
        In production: lookup table in encrypted RDS.
        NEVER called by other services.
        Used only for: chargebacks, disputes, regulatory requests.
        Every detokenization is logged and alerted.
        """
        raise NotImplementedError(
            "Detokenization requires CloudHSM key + audit approval. "
            "Not available in development mode."
        )

    def generate_auth_code(self) -> str:
        """Generate 6-digit authorization code"""
        return str(secrets.randbelow(900000) + 100000)

    def mask_pan(self, pan: str) -> str:
        """
        Mask PAN for display: 4111-XXXX-XXXX-1111
        PCI-DSS allows showing first 6 and last 4
        """
        clean = "".join(c for c in pan if c.isdigit())
        if len(clean) < 13:
            return "XXXX-XXXX-XXXX-XXXX"
        return f"{clean[:4]}-XXXX-XXXX-{clean[-4:]}"