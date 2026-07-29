# Security Design Review — LBB Banking Platform

## STRIDE Threat Model

### Spoofing
- **Threat**: Attacker impersonates a legitimate service
- **Mitigation**: OAuth 2.0 client credentials with Entra ID, JWT validation on every API call
- **Evidence**: Token contains appid claim verified against registered apps

### Tampering
- **Threat**: Data modified in transit between services
- **Mitigation**: TLS 1.3 enforced on all Container Apps, HMAC signatures on payment data
- **Evidence**: Container Apps enforce HTTPS by default

### Repudiation
- **Threat**: User denies performing an action
- **Mitigation**: All API calls logged to App Insights → Sentinel, Entra ID sign-in logs capture every authentication
- **Evidence**: Immutable audit trail in Log Analytics (30-day retention)

### Information Disclosure
- **Threat**: Sensitive data exposed (PAN, SSN)
- **Mitigation**: PAN tokenization in CardAuth service, no PII in logs, Key Vault for secrets
- **Evidence**: Defender for Containers monitors for sensitive data exposure

### Denial of Service
- **Threat**: Service overwhelmed by traffic
- **Mitigation**: Container Apps auto-scaling 0-10 replicas, Azure DDoS Protection
- **Evidence**: Scaling policies configured per app

### Elevation of Privilege
- **Threat**: User gains unauthorized access
- **Mitigation**: Entra ID RBAC with group-based access, Conditional Access policies, MFA enforced
- **Evidence**: Role-App-Operator cannot access Role-App-Admin functions

## OWASP Top 10 Coverage
| # | Vulnerability | Mitigation | Tool |
|---|--------------|------------|------|
| A01 | Broken Access Control | Entra ID RBAC + OAuth | Defender CSPM |
| A02 | Cryptographic Failures | TLS 1.3 + Key Vault | Defender for Key Vault |
| A03 | Injection | Parameterized queries | Bandit SAST |
| A04 | Insecure Design | STRIDE threat model | ARB review |
| A05 | Security Misconfiguration | Defender CSPM scanning | Secure Score |
| A06 | Vulnerable Components | Container image scanning | Defender for Containers |
| A07 | Auth Failures | MFA + token validation | Entra ID Protection |
| A08 | Data Integrity | HMAC + code signing | Cosign |
| A09 | Logging Failures | Sentinel + App Insights | Defender XDR |
| A10 | SSRF | Private networking | Network policies |
