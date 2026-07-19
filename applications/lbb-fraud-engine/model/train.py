"""
LBB Fraud Model Training Script
=================================
Runs on SageMaker Training Job.
Trains XGBoost model on historical transaction data.

Usage:
  sagemaker.estimator.Estimator(
      entry_point="train.py",
      framework_version="1.7-1",
      instance_type="ml.m5.xlarge",
      ...
  )
"""
import argparse
import os
import json
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.metrics import precision_score, recall_score, f1_score, roc_auc_score
import xgboost as xgb
import joblib
import logging

logger = logging.getLogger(__name__)

def train(args):
    logger.info("Loading training data...")
    train_data = pd.read_csv(os.path.join(args.train, "transactions.csv"))
    
    features = [
        "amount", "mcc_risk", "country_risk", "hour_of_day",
        "day_of_week", "amount_ratio", "velocity_1h",
        "is_international", "is_high_risk_mcc", "is_high_risk_country",
        "pin_verified", "entry_mode_encoded"
    ]
    target = "is_fraud"
    
    X = train_data[features]
    y = train_data[target]
    
    X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    logger.info(f"Training set: {len(X_train)} samples, Fraud rate: {y_train.mean():.4f}")
    logger.info(f"Validation set: {len(X_val)} samples, Fraud rate: {y_val.mean():.4f}")
    
    model = xgb.XGBClassifier(
        n_estimators=args.n_estimators,
        max_depth=args.max_depth,
        learning_rate=args.learning_rate,
        scale_pos_weight=len(y_train[y_train==0]) / max(len(y_train[y_train==1]), 1),
        use_label_encoder=False,
        eval_metric="aucpr"
    )
    
    model.fit(X_train, y_train, eval_set=[(X_val, y_val)], verbose=True)
    
    y_pred = model.predict(X_val)
    y_proba = model.predict_proba(X_val)[:, 1]
    
    metrics = {
        "precision": precision_score(y_val, y_pred),
        "recall": recall_score(y_val, y_pred),
        "f1": f1_score(y_val, y_pred),
        "auc_roc": roc_auc_score(y_val, y_proba),
    }
    
    logger.info(f"Model metrics: {json.dumps(metrics, indent=2)}")
    
    model_path = os.path.join(args.model_dir, "fraud_model.joblib")
    joblib.dump(model, model_path)
    
    with open(os.path.join(args.model_dir, "metrics.json"), "w") as f:
        json.dump(metrics, f)
    
    logger.info(f"Model saved to {model_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-estimators", type=int, default=200)
    parser.add_argument("--max-depth", type=int, default=6)
    parser.add_argument("--learning-rate", type=float, default=0.1)
    parser.add_argument("--model-dir", type=str, default=os.environ.get("SM_MODEL_DIR", "/opt/ml/model"))
    parser.add_argument("--train", type=str, default=os.environ.get("SM_CHANNEL_TRAIN", "/opt/ml/input/data/train"))
    args = parser.parse_args()
    train(args)
