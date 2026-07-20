# model/dns_classifier.py
import numpy as np
import math
from collections import Counter

class DNSAnomalyClassifier:
    """
    Detects malicious DNS patterns:
    - DNS tunneling (encoded data in queries)
    - DGA domains (randomly generated C2 domains)
    - DNS beaconing (periodic C2 check-ins)
    """
    
    def analyze_query(self, domain, query_log_context=None):
        """Analyze a single DNS query for anomalies"""
        features = self._extract_features(domain)
        
        results = {
            'domain': domain,
            'risk_score': 0,
            'threats': [],
            'features': features
        }
        
        # Check for DNS tunneling
        if features['subdomain_length'] > 30:
            results['risk_score'] += 40
            results['threats'].append('POSSIBLE_DNS_TUNNELING')
        
        # Check for DGA (randomly generated domain)
        if features['entropy'] > 3.5 and features['consonant_ratio'] > 0.7:
            results['risk_score'] += 35
            results['threats'].append('POSSIBLE_DGA_DOMAIN')
        
        # Check for encoded data (base64 in subdomain)
        if features['has_base64_pattern']:
            results['risk_score'] += 50
            results['threats'].append('ENCODED_DATA_IN_DNS')
        
        # Check query frequency (beaconing)
        if query_log_context:
            beacon_score = self._detect_beaconing(domain, query_log_context)
            if beacon_score > 0.7:
                results['risk_score'] += 30
                results['threats'].append('DNS_BEACONING_PATTERN')
        
        results['risk_score'] = min(results['risk_score'], 100)
        results['is_malicious'] = results['risk_score'] > 60
        
        return results
    
    def _extract_features(self, domain):
        """Extract features from domain name"""
        parts = domain.split('.')
        subdomain = parts[0] if len(parts) > 2 else ''
        
        return {
            'domain_length': len(domain),
            'subdomain_length': len(subdomain),
            'label_count': len(parts),
            'entropy': self._shannon_entropy(domain),
            'consonant_ratio': self._consonant_ratio(domain),
            'digit_ratio': sum(c.isdigit() for c in domain) / max(len(domain), 1),
            'has_base64_pattern': self._has_base64(subdomain),
            'max_label_length': max(len(p) for p in parts),
            'has_hex_pattern': bool(all(c in '0123456789abcdef' for c in subdomain.lower()) and len(subdomain) > 10),
        }
    
    def _shannon_entropy(self, text):
        """Calculate Shannon entropy — high entropy = random/encoded"""
        if not text:
            return 0
        counts = Counter(text.lower())
        length = len(text)
        return -sum(
            (count/length) * math.log2(count/length)
            for count in counts.values()
        )
    
    def _consonant_ratio(self, text):
        """High consonant ratio suggests randomly generated"""
        consonants = set('bcdfghjklmnpqrstvwxyz')
        alpha = [c for c in text.lower() if c.isalpha()]
        if not alpha:
            return 0
        return sum(1 for c in alpha if c in consonants) / len(alpha)
    
    def _has_base64(self, text):
        """Check if text looks like base64 encoded data"""
        import re
        return bool(re.match(r'^[A-Za-z0-9+/]{20,}={0,2}$', text))
    
    def _detect_beaconing(self, domain, query_logs):
        """Detect periodic DNS queries (C2 beaconing)"""
        # Get timestamps of queries to this domain
        timestamps = [
            log['timestamp'] for log in query_logs
            if domain in log.get('query_name', '')
        ]
        
        if len(timestamps) < 5:
            return 0
        
        # Calculate intervals between queries
        intervals = [
            timestamps[i+1] - timestamps[i]
            for i in range(len(timestamps)-1)
        ]
        
        # Low variance in intervals = beaconing
        if not intervals:
            return 0
        mean_interval = np.mean(intervals)
        std_interval = np.std(intervals)
        
        # Coefficient of variation — low = regular pattern
        cv = std_interval / max(mean_interval, 1)
        
        # CV < 0.3 with regular intervals = beaconing
        return max(0, 1 - cv) if cv < 1 else 0