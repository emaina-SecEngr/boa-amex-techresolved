# ADR-001: Azure Container Apps for LBB Banking Services

## Status
APPROVED — ARB Review 2026-07-29

## Context
LBB banking microservices need a hosting platform in Azure
that supports containerized workloads with auto-scaling,
HTTPS, and native Sentinel integration.

## Decision
Use Azure Container Apps (serverless containers).

## Alternatives Considered
| Option | Pros | Cons |
|--------|------|------|
| Container Apps | Serverless, auto-scale to zero, built-in HTTPS, lowest cost | Less control than AKS |
| AKS (Kubernetes) | Full control, industry standard | Complex, minimum 3 nodes always running, higher cost |
| App Service | Simple, managed | No container orchestration |
| VMs | Full control | Manual patching, no auto-scale |

## Consequences
- Cost: ~$10/month (scales to zero when idle)
- Operations: minimal — no cluster management
- Security: Defender for Containers provides runtime protection
- Monitoring: native Log Analytics + Sentinel integration
- Compliance: SOC 2, PCI-DSS, HIPAA certified platform

## Compliance Review
- PCI-DSS: Container Apps environment is PCI-certified
- OCC: Meets cloud hosting requirements
- SOX: Audit trail via Azure Activity Logs + Sentinel
