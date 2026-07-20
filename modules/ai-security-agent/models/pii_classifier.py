# model/pii_classifier.py
import re
import json
from enum import Enum

class PIIType(str, Enum):
    CREDIT_CARD = "CREDIT_CARD"
    SSN = "SSN"
    EMAIL = "EMAIL"
    PHONE = "PHONE"
    ADDRESS = "ADDRESS"
    NAME = "NAME"
    DOB = "DATE_OF_BIRTH"
    BANK_ACCOUNT = "BANK_ACCOUNT"
    ROUTING_NUMBER = "ROUTING_NUMBER"

class PIIClassifier:
    """
    Detects PII in text data — files, database exports, logs.
    Used by Macie alternative and DLP policies.
    Flags PCI-DSS violations when PAN found outside CDE.
    """
    
    # Regex patterns for structured PII
    PATTERNS = {
        PIIType.CREDIT_CARD: [
            r'\b4[0-9]{12}(?:[0-9]{3})?\b',          # Visa
            r'\b5[1-5][0-9]{14}\b',                    # Mastercard
            r'\b3[47][0-9]{13}\b',                     # Amex
            r'\b6(?:011|5[0-9]{2})[0-9]{12}\b',        # Discover
        ],
        PIIType.SSN: [
            r'\b\d{3}-\d{2}-\d{4}\b',
            r'\b\d{3}\s\d{2}\s\d{4}\b',
            r'\b\d{9}\b',  # unformatted — validate context
        ],
        PIIType.EMAIL: [
            r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        ],
        PIIType.PHONE: [
            r'\b\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b',
        ],
        PIIType.BANK_ACCOUNT: [
            r'\b\d{8,17}\b',  # validate context
        ],
        PIIType.ROUTING_NUMBER: [
            r'\b\d{9}\b',  # ABA routing — validate context
        ],
    }
    
    # Context words that confirm PII type
    CONTEXT_WORDS = {
        PIIType.CREDIT_CARD: ['card', 'visa', 'mastercard', 'amex', 'pan', 'credit', 'debit'],
        PIIType.SSN: ['ssn', 'social security', 'tax id', 'tin'],
        PIIType.BANK_ACCOUNT: ['account number', 'acct', 'checking', 'savings', 'deposit'],
        PIIType.ROUTING_NUMBER: ['routing', 'aba', 'transit'],
    }
    
    def scan(self, text, source_location="unknown"):
        """
        Scan text for PII. Returns list of findings.
        
        Args:
            text: string content to scan
            source_location: S3 path or database table name
            
        Returns:
            List of PII findings with type, location, severity
        """
        findings = []
        
        for pii_type, patterns in self.PATTERNS.items():
            for pattern in patterns:
                matches = re.finditer(pattern, text)
                for match in matches:
                    # Verify with Luhn check for credit cards
                    if pii_type == PIIType.CREDIT_CARD:
                        if not self._luhn_check(match.group()):
                            continue
                    
                    # Check context to reduce false positives
                    context = text[max(0, match.start()-50):match.end()+50].lower()
                    confidence = self._calculate_confidence(pii_type, match.group(), context)
                    
                    if confidence > 0.5:
                        # Determine severity based on PII type and location
                        severity = self._assess_severity(pii_type, source_location)
                        
                        findings.append({
                            'pii_type': pii_type.value,
                            'value_masked': self._mask_value(pii_type, match.group()),
                            'position': match.start(),
                            'confidence': round(confidence, 2),
                            'severity': severity,
                            'source': source_location,
                            'context': self._mask_context(context),
                            'pci_violation': pii_type == PIIType.CREDIT_CARD and 'pci-cde' not in source_location.lower(),
                            'recommended_action': self._recommend_action(pii_type, severity, source_location)
                        })
        
        return {
            'source': source_location,
            'total_findings': len(findings),
            'critical': sum(1 for f in findings if f['severity'] == 'CRITICAL'),
            'high': sum(1 for f in findings if f['severity'] == 'HIGH'),
            'findings': findings
        }
    
    def _luhn_check(self, number):
        """Validate credit card number with Luhn algorithm"""
        digits = [int(d) for d in number if d.isdigit()]
        checksum = 0
        for i, d in enumerate(reversed(digits)):
            if i % 2 == 1:
                d *= 2
                if d > 9:
                    d -= 9
            checksum += d
        return checksum % 10 == 0
    
    def _calculate_confidence(self, pii_type, value, context):
        """Calculate confidence based on context words"""
        base_confidence = 0.6
        context_words = self.CONTEXT_WORDS.get(pii_type, [])
        
        for word in context_words:
            if word in context:
                base_confidence += 0.1
        
        # Credit cards with Luhn check pass = high confidence
        if pii_type == PIIType.CREDIT_CARD:
            base_confidence = 0.95
            
        return min(base_confidence, 1.0)
    
    def _assess_severity(self, pii_type, source_location):
        """Determine severity based on PII type and where it was found"""
        if pii_type == PIIType.CREDIT_CARD:
            if 'pci-cde' in source_location.lower():
                return 'MEDIUM'  # expected in CDE
            return 'CRITICAL'    # PAN outside CDE = PCI violation
        elif pii_type == PIIType.SSN:
            return 'CRITICAL'
        elif pii_type in [PIIType.BANK_ACCOUNT, PIIType.ROUTING_NUMBER]:
            return 'HIGH'
        else:
            return 'MEDIUM'
    
    def _mask_value(self, pii_type, value):
        """Mask PII for safe logging"""
        if pii_type == PIIType.CREDIT_CARD:
            return f"****-****-****-{value[-4:]}"
        elif pii_type == PIIType.SSN:
            return f"***-**-{value[-4:]}"
        elif pii_type == PIIType.EMAIL:
            parts = value.split('@')
            return f"{parts[0][:2]}***@{parts[1]}"
        return f"{value[:2]}***{value[-2:]}"
    
    def _mask_context(self, context):
        """Mask sensitive values in context string"""
        # Replace any remaining card numbers
        masked = re.sub(r'\b\d{13,19}\b', '****', context)
        masked = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', '***-**-****', masked)
        return masked
    
    def _recommend_action(self, pii_type, severity, source):
        """Recommend remediation action"""
        if severity == 'CRITICAL':
            return f"IMMEDIATE: Remove {pii_type.value} from {source}. Tokenize or encrypt. File PCI incident if card data."
        elif severity == 'HIGH':
            return f"URGENT: Encrypt {pii_type.value} in {source} within 24 hours."
        return f"REVIEW: Verify {pii_type.value} handling in {source} meets policy."