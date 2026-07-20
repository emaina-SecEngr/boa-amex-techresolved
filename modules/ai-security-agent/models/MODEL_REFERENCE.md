# AI Security Agent — ML Model Reference

## Custom Models (Built on SageMaker)

| # | Model | Algorithm | Input Data | Detects |
|---|-------|-----------|------------|---------|
| 1 | CloudTrail Anomaly | Isolation Forest | CloudTrail events | Insider threats, compromised credentials |
| 2 | Phishing Detector | XGBoost | Email metadata + content | Phishing, spear-phishing, CEO fraud |
| 3 | PII Classifier | Regex + NER | S3 objects, DB exports | Credit cards, SSNs, PII outside CDE |
| 4 | DNS Classifier | Statistical + Entropy | Route 53 DNS logs | DNS tunneling, DGA, C2 beaconing |
| 5 | Network IDS | Behavioral + Rules | VPC Flow Logs | Port scans, lateral movement, exfil |
| 6 | Identity Threat | Pattern Analysis | CloudTrail auth events | Impossible travel, credential stuffing |
| 7 | Malware Classifier | Random Forest | File static features | Malware, packed executables, scripts |
| 8 | Log Anomaly | Autoencoder | CloudWatch/Security Lake | Volume spikes, rare events, error surges |
| 9 | Threat Intel Matcher | TF-IDF + Cosine | IOCs from findings | Known malicious IPs, domains, TTPs |
| 10 | Fraud Patterns | Sequence Analysis | Transaction history | Card testing, structuring, fraud rings |

## AWS Built-in ML Models (Already Active)

| Service | Models | Status |
|---------|--------|--------|
| GuardDuty | 8 models (CloudTrail, VPC, DNS, UEBA, S3, EKS, RDS, Lambda) | ACTIVE |
| Detective | 3 models (behavior graph, activity baseline, correlation) | ACTIVE |
| Security Hub | 1 model (deduplication) | ACTIVE |
| Inspector | 2 models (reachability, CVE prioritization) | TOGGLE |
| Macie | 3 models (classification, access patterns, sensitivity) | TOGGLE |
| IAM Access Analyzer | 2 models (policy analysis, unused access) | TOGGLE |
| WAF | 3 models (bot detection, ATP, fraud control) | TOGGLE |
| Bedrock Claude | 1 model (finding triage, investigation, reports) | BUILDING |

## Total AI/ML Coverage: 10 custom + 23 AWS built-in = 33 models
