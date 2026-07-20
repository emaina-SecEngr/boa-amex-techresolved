# model/phishing_detector.py
import xgboost as xgb
import pandas as pd
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
import re

class PhishingDetector:
    """
    Detects phishing emails using content analysis + metadata.
    Trained on labeled phishing/legitimate email corpus.
    """
    
    def __init__(self):
        self.model = xgb.XGBClassifier(
            n_estimators=300,
            max_depth=8,
            learning_rate=0.1,
            scale_pos_weight=5,  # phishing is minority class
            use_label_encoder=False,
            eval_metric='aucpr'
        )
        self.tfidf = TfidfVectorizer(max_features=500)
        
        # Phishing indicator words
        self.urgency_words = [
            'urgent', 'immediately', 'suspend', 'verify',
            'confirm', 'expire', 'locked', 'unauthorized',
            'alert', 'action required', 'within 24 hours'
        ]
    
    def extract_features(self, email):
        """Extract features from email for classification"""
        features = {}
        
        # Domain analysis
        sender_domain = email.get('sender', '').split('@')[-1]
        features['sender_domain_age_days'] = self._get_domain_age(sender_domain)
        features['sender_domain_reputation'] = self._get_domain_reputation(sender_domain)
        
        # URL analysis
        urls = re.findall(r'https?://\S+', email.get('body', ''))
        features['url_count'] = len(urls)
        features['has_url'] = 1 if urls else 0
        features['url_domain_mismatch'] = self._check_url_mismatch(email.get('body', ''), urls)
        
        # Content analysis
        body = email.get('body', '').lower()
        features['urgency_score'] = sum(1 for w in self.urgency_words if w in body) / len(self.urgency_words)
        features['contains_password_request'] = 1 if any(w in body for w in ['password', 'credential', 'login']) else 0
        features['body_length'] = len(body)
        features['grammar_errors'] = self._count_grammar_errors(body)
        
        # Authentication checks
        features['spf_pass'] = 1 if email.get('spf_result') == 'pass' else 0
        features['dkim_pass'] = 1 if email.get('dkim_result') == 'pass' else 0
        features['dmarc_pass'] = 1 if email.get('dmarc_result') == 'pass' else 0
        
        # Attachment analysis
        features['has_attachment'] = 1 if email.get('attachments') else 0
        features['attachment_is_executable'] = self._is_dangerous_attachment(email.get('attachments', []))
        
        # Impersonation detection
        features['sender_name_similarity'] = self._check_impersonation(
            email.get('sender_display_name', ''),
            email.get('known_executives', [])
        )
        
        # Reply-to mismatch
        features['reply_to_mismatch'] = 1 if email.get('reply_to', '') != email.get('sender', '') else 0
        
        return features
    
    def predict(self, email):
        """Score email for phishing probability"""
        features = self.extract_features(email)
        X = pd.DataFrame([features])
        
        probability = self.model.predict_proba(X)[0][1]  # probability of phishing
        
        # Get top risk factors
        importance = self.model.feature_importances_
        feature_names = list(features.keys())
        top_factors = sorted(
            zip(feature_names, importance, [features[f] for f in feature_names]),
            key=lambda x: x[1] * abs(x[2]),  # importance * feature value
            reverse=True
        )[:5]
        
        return {
            'phishing_score': round(probability * 100, 2),
            'is_phishing': probability > 0.7,
            'confidence': round(probability, 4),
            'risk_factors': [
                f"{name}: {value}" for name, imp, value in top_factors
            ],
            'recommendation': 'BLOCK' if probability > 0.8 else 'QUARANTINE' if probability > 0.5 else 'DELIVER'
        }