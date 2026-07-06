# BOA-AMEX-TechResolved

## Multi-Cloud Security Platform | AWS + Azure + On-Premise

**OCC-regulated | PCI-DSS v4.0 | NIST 800-53 | Zero Trust**

Consultant: Eliud Maina | Abuhari Consulting Services

---

## Architecture Overview

Production-grade, systematically-built AWS Organization security
architecture integrated with Microsoft Security Copilot, CrowdStrike,
Palo Alto Networks, and Wiz Cloud Security.

This repository is built in strict phase order. Each phase must be
complete and verified before the next phase begins. No exceptions.

---

## Account Structure

| Account | ID | Purpose |
|---|---|---|
| Management | 682391277575 | Governance only — SCPs, Identity Center, billing |
| Security Tooling | 368351959735 | All security infrastructure |
| PCI-CDE | TBD | Cardholder data workloads |
| Core Banking | TBD | Payment processing workloads |
| Dev | TBD | Non-production environments |
| Pipeline/CI-CD | TBD | Terraform Cloud, Checkov, SAST |

---

## Build Phases

### Phase 1 — AWS Organization Foundation (IN PROGRESS)
- [ ] modules/aws-organization/
- [ ] modules/management-baseline/
- [ ] modules/iam-identity-center/

### Phase 2 — Security Tooling (NOT STARTED)
- [ ] modules/log-archive/
- [ ] modules/security-hub/
- [ ] modules/guardduty/
- [ ] modules/detective/
- [ ] modules/security-lake/
- [ ] modules/wiz/

### Phase 3 — Extended Detection + Network (NOT STARTED)
- [ ] modules/crowdstrike/
- [ ] modules/palo-alto/
- [ ] modules/sentinel/
- [ ] modules/secrets-pki/
- [ ] modules/network-perimeter/

### Phase 4 — Unified SOAR (NOT STARTED)
- [ ] modules/soar/

### Phase 5 — Workload Accounts (NOT STARTED)
- [ ] environments/pci-cde/
- [ ] environments/core-banking/
- [ ] environments/dev/
- [ ] environments/pipeline-cicd/

### Phase 6 — Compliance and Governance (NOT STARTED)
- [ ] Config conformance packs
- [ ] Audit account
- [ ] Tag governance

---

## Reference Repository

amex-log-archive contains the learning and reference implementation.
This repository is the production-correct systematic build.
