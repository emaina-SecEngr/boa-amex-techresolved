# model/cloudtrail_anomaly.py
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import joblib

class CloudTrailAnomalyDetector:
    """
    Trains on 90 days of normal CloudTrail behavior.
    Detects deviations that indicate compromise.
    """
    
    def __init__(self):
        self.model = IsolationForest(
            n_estimators=200,        # 200 random trees
            contamination=0.01,      # expect 1% anomalies
            max_features=0.8,        # use 80% of features per tree
            random_state=42
        )
        self.scaler = StandardScaler()
        self.feature_columns = [
            'api_call_count_per_hour',
            'unique_apis_per_day',
            'unique_services_per_hour',
            's3_read_count',
            's3_write_count',
            'iam_call_count',
            'sts_assume_role_count',
            'cross_account_calls',
            'hour_of_day',
            'day_of_week',
            'source_ip_count',
            'new_api_flag',
            'error_rate',
            'data_transfer_bytes',
            'console_login_flag'
        ]
    
    def engineer_features(self, cloudtrail_df):
        """Transform raw CloudTrail events into features"""
        features = cloudtrail_df.groupby(
            ['userIdentity_arn', 'hour']
        ).agg({
            'eventName': 'count',                    # api_call_count
            'eventName': 'nunique',                  # unique_apis
            'eventSource': 'nunique',                # unique_services
            'sourceIPAddress': 'nunique',            # source_ip_count
            'errorCode': lambda x: x.notna().mean(), # error_rate
        }).reset_index()
        
        # Add derived features
        features['s3_read_count'] = cloudtrail_df[
            cloudtrail_df['eventName'] == 'GetObject'
        ].groupby('userIdentity_arn').size()
        
        features['iam_call_count'] = cloudtrail_df[
            cloudtrail_df['eventSource'] == 'iam.amazonaws.com'
        ].groupby('userIdentity_arn').size()
        
        features['cross_account_calls'] = cloudtrail_df[
            cloudtrail_df['eventName'] == 'AssumeRole'
        ].groupby('userIdentity_arn').size()
        
        return features
    
    def train(self, training_data):
        """Train on 90 days of normal behavior"""
        X = training_data[self.feature_columns]
        X_scaled = self.scaler.fit_transform(X)
        self.model.fit(X_scaled)
        
    def predict(self, new_event):
        """Score new CloudTrail event — returns anomaly score 0-1"""
        X = np.array([new_event[col] for col in self.feature_columns]).reshape(1, -1)
        X_scaled = self.scaler.transform(X)
        
        # Isolation Forest returns -1 (anomaly) or 1 (normal)
        raw_score = self.model.decision_function(X_scaled)[0]
        
        # Convert to 0-1 scale (0=normal, 1=anomaly)
        anomaly_score = 1 - (raw_score - self.model.offset_) / (
            abs(self.model.offset_) * 2
        )
        anomaly_score = max(0, min(1, anomaly_score))
        
        return {
            'anomaly_score': round(anomaly_score, 4),
            'is_anomaly': anomaly_score > 0.8,
            'threshold': 0.8,
            'model_version': 'isolation-forest-v1.0'
        }