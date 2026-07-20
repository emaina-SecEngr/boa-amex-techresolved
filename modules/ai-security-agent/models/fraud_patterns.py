"""
Fraud Transaction Pattern Detector
Advanced fraud patterns beyond basic scoring:
  Card testing detection
  Fraud ring identification
  Structuring detection (BSA/AML)
  Velocity abuse patterns
"""
from collections import defaultdict
from datetime import datetime, timedelta
import numpy as np

class FraudPatternDetector:
    """
    Detects complex fraud patterns that simple scoring misses.
    Analyzes transaction sequences, not individual transactions.
    """
    
    def __init__(self):
        self.card_history = defaultdict(list)
        self.merchant_history = defaultdict(list)
        self.ip_history = defaultdict(list)
    
    def analyze_pattern(self, transaction):
        """Analyze transaction in context of history"""
        card = transaction.get('card_token', '')
        merchant = transaction.get('merchant_id', '')
        ip = transaction.get('source_ip', '')
        amount = transaction.get('amount', 0)
        
        # Track history
        self.card_history[card].append(transaction)
        self.merchant_history[merchant].append(transaction)
        self.ip_history[ip].append(transaction)
        
        patterns = []
        
        # Pattern 1: Card Testing
        # Small transactions to verify stolen card works
        card_txns = self.card_history[card][-20:]
        small_txns = [t for t in card_txns if t.get('amount', 0) < 5.00]
        if len(small_txns) >= 3 and len(card_txns) <= 10:
            patterns.append({
                'type': 'CARD_TESTING',
                'confidence': min(len(small_txns) / 5, 1.0),
                'detail': f'{len(small_txns)} small transactions (<$5) — possible card testing',
                'severity': 'HIGH',
                'recommended_action': 'BLOCK_CARD'
            })
        
        # Pattern 2: Velocity Abuse
        # Many transactions in short time
        recent_txns = [
            t for t in card_txns
            if isinstance(t.get('timestamp'), (int, float)) and
            t['timestamp'] > datetime.utcnow().timestamp() - 3600
        ]
        if len(recent_txns) > 10:
            patterns.append({
                'type': 'VELOCITY_ABUSE',
                'confidence': min(len(recent_txns) / 20, 1.0),
                'detail': f'{len(recent_txns)} transactions in 1 hour',
                'severity': 'HIGH',
                'recommended_action': 'STEP_UP_AUTH'
            })
        
        # Pattern 3: Structuring (BSA/AML)
        # Multiple transactions just under $10,000 CTR threshold
        ctr_threshold = 10000
        suspicious_amounts = [
            t for t in card_txns
            if 8000 <= t.get('amount', 0) < ctr_threshold
        ]
        if len(suspicious_amounts) >= 2:
            total = sum(t['amount'] for t in suspicious_amounts)
            if total > ctr_threshold:
                patterns.append({
                    'type': 'STRUCTURING',
                    'confidence': 0.85,
                    'detail': f'{len(suspicious_amounts)} transactions totaling ${total:.2f} — possible CTR avoidance',
                    'severity': 'CRITICAL',
                    'recommended_action': 'FILE_SAR',
                    'bsa_aml_flag': True
                })
        
        # Pattern 4: Geographic Hopping
        # Transactions from multiple countries in short time
        countries = [t.get('country', 'US') for t in card_txns[-10:]]
        unique_countries = set(countries)
        if len(unique_countries) > 3:
            patterns.append({
                'type': 'GEOGRAPHIC_HOPPING',
                'confidence': min(len(unique_countries) / 5, 1.0),
                'detail': f'Transactions from {len(unique_countries)} countries: {", ".join(unique_countries)}',
                'severity': 'HIGH',
                'recommended_action': 'BLOCK_AND_VERIFY'
            })
        
        # Pattern 5: Merchant Concentration
        # Same merchant getting many different cards (compromised terminal)
        merchant_cards = set(
            t.get('card_token', '') for t in self.merchant_history[merchant][-100:]
        )
        if len(merchant_cards) > 20:
            patterns.append({
                'type': 'COMPROMISED_MERCHANT',
                'confidence': min(len(merchant_cards) / 50, 1.0),
                'detail': f'Merchant {merchant} processed {len(merchant_cards)} unique cards recently',
                'severity': 'CRITICAL',
                'recommended_action': 'ALERT_FRAUD_TEAM'
            })
        
        # Pattern 6: Round Amount Laundering
        # Multiple round-number transactions (common in money laundering)
        round_amounts = [t for t in card_txns if t.get('amount', 0) == int(t.get('amount', 0)) and t.get('amount', 0) >= 1000]
        if len(round_amounts) >= 3:
            patterns.append({
                'type': 'ROUND_AMOUNT_PATTERN',
                'confidence': min(len(round_amounts) / 5, 1.0),
                'detail': f'{len(round_amounts)} round-number transactions >= $1000',
                'severity': 'MEDIUM',
                'recommended_action': 'AML_REVIEW'
            })
        
        return {
            'card_token': card,
            'patterns_detected': len(patterns),
            'patterns': patterns,
            'overall_risk': 'CRITICAL' if any(p['severity'] == 'CRITICAL' for p in patterns) else
                           'HIGH' if any(p['severity'] == 'HIGH' for p in patterns) else
                           'MEDIUM' if patterns else 'LOW',
            'sar_required': any(p.get('bsa_aml_flag') for p in patterns)
        }
