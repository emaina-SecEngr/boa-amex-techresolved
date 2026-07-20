"""
Log Anomaly Detector — Autoencoder (Deep Learning)
Detects unusual patterns in CloudWatch/Security Lake logs.
Autoencoder learns to reconstruct NORMAL log patterns.
High reconstruction error = anomaly.
"""
import numpy as np
import json
import logging
from collections import Counter
from datetime import datetime

logger = logging.getLogger("log-anomaly")

class LogAnomalyDetector:
    """
    Autoencoder-based log anomaly detection.
    
    How it works:
      1. Encoder compresses log features into small vector
      2. Decoder reconstructs features from compressed vector
      3. Trained on NORMAL logs — learns normal patterns
      4. Anomalous logs have HIGH reconstruction error
         (autoencoder can't reconstruct what it hasn't seen)
    
    In production: PyTorch/TensorFlow autoencoder on SageMaker
    In development: statistical approximation
    """
    
    def __init__(self):
        self.baselines = {}  # per-service baselines
        self.trained = False
    
    def train(self, log_data):
        """
        Train on historical log data to learn baselines.
        
        Args:
            log_data: list of log entries with features
        """
        for entry in log_data:
            service = entry.get('service', 'unknown')
            if service not in self.baselines:
                self.baselines[service] = {
                    'event_counts': Counter(),
                    'hourly_volumes': [0] * 24,
                    'error_rates': [],
                    'avg_message_length': [],
                    'total_entries': 0
                }
            
            baseline = self.baselines[service]
            baseline['event_counts'][entry.get('event_type', 'unknown')] += 1
            
            hour = entry.get('hour', 0)
            baseline['hourly_volumes'][hour] += 1
            
            baseline['error_rates'].append(1 if entry.get('is_error') else 0)
            baseline['avg_message_length'].append(len(entry.get('message', '')))
            baseline['total_entries'] += 1
        
        # Calculate statistical baselines
        for service, baseline in self.baselines.items():
            n = max(baseline['total_entries'], 1)
            baseline['mean_error_rate'] = sum(baseline['error_rates']) / n
            baseline['std_error_rate'] = np.std(baseline['error_rates']) if baseline['error_rates'] else 0
            baseline['mean_msg_length'] = sum(baseline['avg_message_length']) / n
            baseline['std_msg_length'] = np.std(baseline['avg_message_length']) if baseline['avg_message_length'] else 0
            baseline['mean_hourly_volume'] = sum(baseline['hourly_volumes']) / 24
            baseline['std_hourly_volume'] = np.std(baseline['hourly_volumes'])
        
        self.trained = True
        logger.info(f"Trained on {len(self.baselines)} services")
    
    def detect(self, log_entry):
        """
        Score a log entry for anomaly.
        Returns reconstruction error as anomaly score.
        """
        service = log_entry.get('service', 'unknown')
        
        if not self.trained or service not in self.baselines:
            return {
                'anomaly_score': 0,
                'is_anomaly': False,
                'reason': 'No baseline for this service yet',
                'service': service
            }
        
        baseline = self.baselines[service]
        anomaly_scores = []
        reasons = []
        
        # Check 1: Event type frequency
        event_type = log_entry.get('event_type', 'unknown')
        total = sum(baseline['event_counts'].values())
        event_frequency = baseline['event_counts'].get(event_type, 0) / max(total, 1)
        if event_frequency < 0.001:  # very rare event
            anomaly_scores.append(0.8)
            reasons.append(f"Rare event type: {event_type} (frequency: {event_frequency:.4f})")
        elif event_frequency < 0.01:
            anomaly_scores.append(0.4)
            reasons.append(f"Uncommon event type: {event_type}")
        
        # Check 2: Volume anomaly (for this hour)
        hour = log_entry.get('hour', datetime.utcnow().hour)
        expected_volume = baseline['hourly_volumes'][hour]
        current_volume = log_entry.get('current_hour_volume', 0)
        if baseline['std_hourly_volume'] > 0:
            z_score = abs(current_volume - baseline['mean_hourly_volume']) / baseline['std_hourly_volume']
            if z_score > 3:
                anomaly_scores.append(0.9)
                reasons.append(f"Volume {z_score:.1f} standard deviations from mean")
            elif z_score > 2:
                anomaly_scores.append(0.5)
                reasons.append(f"Elevated volume: {z_score:.1f} std devs")
        
        # Check 3: Error rate spike
        is_error = log_entry.get('is_error', False)
        if is_error and baseline['mean_error_rate'] < 0.05:
            anomaly_scores.append(0.6)
            reasons.append(f"Error in low-error service (baseline rate: {baseline['mean_error_rate']:.2%})")
        
        # Check 4: Message length anomaly
        msg_length = len(log_entry.get('message', ''))
        if baseline['std_msg_length'] > 0:
            z_score = abs(msg_length - baseline['mean_msg_length']) / baseline['std_msg_length']
            if z_score > 4:
                anomaly_scores.append(0.7)
                reasons.append(f"Unusual message length: {msg_length} chars (z={z_score:.1f})")
        
        # Combined anomaly score
        overall_score = max(anomaly_scores) if anomaly_scores else 0
        
        return {
            'anomaly_score': round(overall_score, 4),
            'is_anomaly': overall_score > 0.7,
            'reasons': reasons,
            'service': service,
            'event_type': event_type,
            'model_version': 'log-anomaly-v1.0'
        }
