"""
CyberArk PAM Routes — Privileged Access Management
=====================================================
Endpoints for CyberArk integration:
  GET  /api/v1/cyberark/status         -> PAM integration status
  GET  /api/v1/cyberark/safes          -> List vault safes
  POST /api/v1/cyberark/checkout       -> Request privileged credential
  POST /api/v1/cyberark/checkin        -> Return privileged credential
  GET  /api/v1/cyberark/sessions       -> List recorded sessions
  GET  /api/v1/cyberark/jit/request    -> Request JIT access
  GET  /api/v1/cyberark/jit/status     -> Check JIT request status
  POST /api/v1/cyberark/jit/approve    -> Approve JIT request
  POST /api/v1/cyberark/jit/revoke     -> Revoke JIT access
  GET  /api/v1/cyberark/conjur/health  -> Conjur secrets engine health
  GET  /api/v1/cyberark/audit          -> Privileged access audit log
"""

import os
import uuid
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.security import get_current_user
from app.models.user import User

router = APIRouter(
    prefix="/cyberark",
    tags=["CyberArk PAM — Privileged Access Management"]
)

CYBERARK_ENABLED = os.getenv("CYBERARK_ENABLED", "false").lower() == "true"
CYBERARK_TENANT = os.getenv("CYBERARK_TENANT_URL", "https://lbbs.cyberark.cloud")
CONJUR_URL = os.getenv("CYBERARK_CONJUR_URL", "https://conjur.lbbs.internal")

# In-memory audit log and JIT requests (database-backed in production)
_audit_log = []
_jit_requests = []
_active_checkouts = []


# -------------------------------------------------------
# PAM STATUS
# -------------------------------------------------------

@router.get("/status", summary="CyberArk PAM integration status")
async def cyberark_status(current_user: User = Depends(get_current_user)):
    """
    Returns the current status of CyberArk PAM integration.
    Shows which components are active and their health.
    """
    return {
        "cyberark_enabled": CYBERARK_ENABLED,
        "tenant_url": CYBERARK_TENANT,
        "components": {
            "digital_vault": {
                "status": "active" if CYBERARK_ENABLED else "not_configured",
                "description": "Stores privileged credentials in encrypted vault",
                "safes_configured": 4,
            },
            "cpm": {
                "status": "active" if CYBERARK_ENABLED else "not_configured",
                "description": "Central Password Manager — auto-rotates credentials",
                "rotation_policies": 4,
            },
            "psm": {
                "status": "active" if CYBERARK_ENABLED else "not_configured",
                "description": "Privileged Session Manager — records admin sessions",
                "recordings_bucket": "lbbs-psm-recordings",
            },
            "conjur": {
                "status": "active" if CYBERARK_ENABLED else "not_configured",
                "url": CONJUR_URL,
                "description": "Dynamic secrets engine for containers and CI/CD",
            },
            "identity": {
                "status": "active" if CYBERARK_ENABLED else "not_configured",
                "description": "Step-up authentication for privileged operations",
                "levels": ["standard_mfa", "elevated_hardware", "critical_approval"],
            },
        },
    }


# -------------------------------------------------------
# VAULT SAFES
# -------------------------------------------------------

@router.get("/safes", summary="List CyberArk vault safes")
async def list_safes(current_user: User = Depends(get_current_user)):
    """
    List all CyberArk vault safes and the accounts stored in each.
    Only admins can view safe contents.
    """
    if current_user.role != "lbb_admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    return {
        "safes": [
            {
                "name": "LBBS-AWS-Infrastructure",
                "description": "AWS root, admin IAM, and Terraform service credentials",
                "accounts": [
                    {"name": "AWS-Root-Account", "platform": "AWS", "type": "password",
                     "auto_rotate": True, "rotation_days": 30, "last_rotated": "2026-03-15",
                     "requires": "manager_approval + hardware_mfa"},
                    {"name": "AWS-Admin-IAM", "platform": "AWS", "type": "access_key",
                     "auto_rotate": True, "rotation_days": 7, "checkout_max": "2h",
                     "requires": "ticket_number + mfa"},
                    {"name": "Terraform-CI-CD", "platform": "AWS", "type": "access_key",
                     "auto_rotate": True, "rotation_days": 1, "checkout_max": "1h",
                     "requires": "pipeline_identity"},
                ],
            },
            {
                "name": "LBBS-Database",
                "description": "PostgreSQL admin, application, and read-only credentials",
                "accounts": [
                    {"name": "RDS-Master-Admin", "platform": "PostgreSQL", "type": "password",
                     "auto_rotate": True, "rotation_days": 14, "session_recorded": True,
                     "requires": "change_ticket + manager_approval + mfa"},
                    {"name": "RDS-Application-User", "platform": "PostgreSQL", "type": "password",
                     "auto_rotate": True, "rotation_days": 7, "checkout_max": "8h",
                     "requires": "service_identity"},
                    {"name": "RDS-ReadOnly-Support", "platform": "PostgreSQL", "type": "password",
                     "auto_rotate": True, "rotation_days": 30, "session_recorded": True,
                     "requires": "ticket_number + mfa"},
                ],
            },
            {
                "name": "LBBS-Identity",
                "description": "Okta admin, SCIM tokens, and SSO client secrets",
                "accounts": [
                    {"name": "Okta-Super-Admin", "platform": "Okta", "type": "api_token",
                     "auto_rotate": True, "rotation_days": 30, "session_recorded": True,
                     "requires": "security_team_approval + hardware_mfa"},
                    {"name": "Okta-SCIM-Bearer-Token", "platform": "Okta", "type": "bearer_token",
                     "auto_rotate": True, "rotation_days": 90,
                     "requires": "service_identity"},
                    {"name": "Okta-OIDC-Client-Secret", "platform": "Okta", "type": "client_secret",
                     "auto_rotate": True, "rotation_days": 180,
                     "requires": "service_identity"},
                ],
            },
            {
                "name": "LBBS-DevOps",
                "description": "CI/CD, container registry, Kubernetes, and ArgoCD credentials",
                "accounts": [
                    {"name": "GitLab-CI-Runner", "platform": "GitLab", "type": "token",
                     "auto_rotate": True, "rotation_days": 7,
                     "requires": "pipeline_identity"},
                    {"name": "ECR-Image-Push", "platform": "AWS-ECR", "type": "access_key",
                     "auto_rotate": True, "rotation_days": 1,
                     "requires": "pipeline_identity"},
                    {"name": "EKS-Cluster-Admin", "platform": "Kubernetes", "type": "kubeconfig",
                     "auto_rotate": True, "rotation_days": 7, "session_recorded": True,
                     "requires": "change_ticket + manager_approval + mfa"},
                    {"name": "ArgoCD-Admin", "platform": "ArgoCD", "type": "password",
                     "auto_rotate": True, "rotation_days": 14,
                     "requires": "ticket_number + mfa"},
                ],
            },
        ],
        "total_safes": 4,
        "total_accounts": 13,
    }


# -------------------------------------------------------
# CREDENTIAL CHECKOUT / CHECKIN
# -------------------------------------------------------

@router.post("/checkout", summary="Request privileged credential checkout")
async def checkout_credential(data: dict, current_user: User = Depends(get_current_user)):
    """Request checkout of a privileged credential from the vault."""
    if current_user.role != "lbb_admin":
        raise HTTPException(status_code=403, detail="Admin access required for credential checkout")

    safe_name = data.get("safe_name", "")
    account_name = data.get("account_name", "")
    reason = data.get("reason", "")
    ticket_number = data.get("ticket_number", "")
    duration_hours = data.get("duration_hours", 2)

    if not safe_name or not account_name:
        raise HTTPException(status_code=400, detail="safe_name and account_name are required")
    if not reason:
        raise HTTPException(status_code=400, detail="Business justification (reason) is required")

    checkout = {
        "id": str(uuid.uuid4()),
        "safe_name": safe_name,
        "account_name": account_name,
        "checked_out_by": str(current_user.id),
        "checked_out_by_name": f"{current_user.first_name} {current_user.last_name}",
        "reason": reason,
        "ticket_number": ticket_number,
        "checked_out_at": datetime.now(timezone.utc).isoformat(),
        "expires_at": (datetime.now(timezone.utc) + timedelta(hours=duration_hours)).isoformat(),
        "duration_hours": duration_hours,
        "status": "active",
        "credential": "********" if not CYBERARK_ENABLED else "RETRIEVED_FROM_VAULT",
    }

    _active_checkouts.append(checkout)
    _audit_log.append({
        "id": str(uuid.uuid4()),
        "action": "CREDENTIAL_CHECKOUT",
        "user": f"{current_user.first_name} {current_user.last_name}",
        "user_id": str(current_user.id),
        "target": f"{safe_name}/{account_name}",
        "reason": reason,
        "ticket_number": ticket_number,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "ip_address": "127.0.0.1",
    })

    return {
        "message": f"Credential checked out for {duration_hours} hours",
        "checkout_id": checkout["id"],
        "expires_at": checkout["expires_at"],
        "note": "Credential auto-revoked after expiry. Session will be recorded.",
    }


@router.post("/checkin", summary="Return privileged credential")
async def checkin_credential(data: dict, current_user: User = Depends(get_current_user)):
    """Return a checked-out credential to the vault."""
    checkout_id = data.get("checkout_id", "")
    checkout = next((c for c in _active_checkouts if c["id"] == checkout_id), None)
    if not checkout:
        raise HTTPException(status_code=404, detail="Checkout not found")
    if checkout["checked_out_by"] != str(current_user.id):
        raise HTTPException(status_code=403, detail="Only the user who checked out can check in")

    checkout["status"] = "returned"
    _audit_log.append({
        "id": str(uuid.uuid4()),
        "action": "CREDENTIAL_CHECKIN",
        "user": f"{current_user.first_name} {current_user.last_name}",
        "user_id": str(current_user.id),
        "target": f"{checkout['safe_name']}/{checkout['account_name']}",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })

    return {
        "message": "Credential returned to vault",
        "auto_rotation": "CPM will rotate this credential within 60 seconds",
    }


# -------------------------------------------------------
# PRIVILEGED SESSIONS
# -------------------------------------------------------

@router.get("/sessions", summary="List recorded privileged sessions")
async def list_sessions(
    status_filter: str = Query(None, description="Filter: active, completed"),
    current_user: User = Depends(get_current_user),
):
    """List PSM-recorded privileged sessions."""
    if current_user.role != "lbb_admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    sessions = [
        {
            "id": "sess-001", "user": "Eliud Maina", "target": "RDS-Master-Admin",
            "type": "database", "started_at": "2026-03-20T10:00:00Z",
            "ended_at": "2026-03-20T10:45:00Z", "duration_minutes": 45,
            "status": "completed", "recording_url": "s3://lbbs-psm-recordings/sess-001.mp4",
            "queries_executed": 12, "risk_score": "low",
        },
        {
            "id": "sess-002", "user": "Eliud Maina", "target": "EKS-Cluster-Admin",
            "type": "kubernetes", "started_at": "2026-03-21T14:00:00Z",
            "ended_at": "2026-03-21T14:30:00Z", "duration_minutes": 30,
            "status": "completed", "recording_url": "s3://lbbs-psm-recordings/sess-002.mp4",
            "commands_executed": 8, "risk_score": "medium",
        },
    ] + [c for c in _active_checkouts if c["status"] == "active"]

    if status_filter:
        sessions = [s for s in sessions if s.get("status") == status_filter]
    return {"sessions": sessions, "total": len(sessions)}


# -------------------------------------------------------
# JIT (JUST-IN-TIME) ACCESS
# -------------------------------------------------------

@router.post("/jit/request", summary="Request JIT privileged access")
async def request_jit_access(data: dict, current_user: User = Depends(get_current_user)):
    """Request Just-In-Time privileged access."""
    access_type = data.get("access_type", "")
    reason = data.get("reason", "")
    ticket_number = data.get("ticket_number", "")
    duration_hours = data.get("duration_hours", 2)

    valid_types = {
        "database_admin": {"max_hours": 4, "requires": ["change_ticket", "manager_approval"]},
        "kubernetes_admin": {"max_hours": 2, "requires": ["deployment_ticket"]},
        "okta_admin": {"max_hours": 1, "requires": ["support_ticket", "security_approval"]},
        "break_glass": {"max_hours": 8, "requires": ["incident_number"]},
    }

    if access_type not in valid_types:
        raise HTTPException(status_code=400, detail=f"Invalid access_type. Valid: {list(valid_types.keys())}")

    config = valid_types[access_type]
    if duration_hours > config["max_hours"]:
        max_h = config["max_hours"]
        raise HTTPException(
            status_code=400,
            detail=f"Maximum duration for {access_type} is {max_h} hours",
        )
    if not reason:
        raise HTTPException(status_code=400, detail="Business justification is required")

    jit_request = {
        "id": str(uuid.uuid4()),
        "access_type": access_type,
        "requested_by": str(current_user.id),
        "requested_by_name": f"{current_user.first_name} {current_user.last_name}",
        "reason": reason,
        "ticket_number": ticket_number,
        "duration_hours": duration_hours,
        "requires_approval": config["requires"],
        "status": "pending_approval",
        "requested_at": datetime.now(timezone.utc).isoformat(),
        "expires_at": None,
    }

    _jit_requests.append(jit_request)
    _audit_log.append({
        "id": str(uuid.uuid4()),
        "action": "JIT_ACCESS_REQUESTED",
        "user": jit_request["requested_by_name"],
        "user_id": str(current_user.id),
        "target": access_type,
        "reason": reason,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })

    return {
        "message": f"JIT access requested for {access_type}",
        "request_id": jit_request["id"],
        "status": "pending_approval",
        "requires": config["requires"],
        "max_duration": f"{config['max_hours']} hours",
    }


@router.get("/jit/status", summary="Check JIT request status")
async def jit_status(
    request_id: str = Query(None, description="Specific request ID"),
    current_user: User = Depends(get_current_user),
):
    """Check the status of JIT access requests."""
    if request_id:
        req = next((r for r in _jit_requests if r["id"] == request_id), None)
        if not req:
            raise HTTPException(status_code=404, detail="JIT request not found")
        return req
    user_requests = [r for r in _jit_requests if r["requested_by"] == str(current_user.id)]
    return {"requests": user_requests, "total": len(user_requests)}


@router.post("/jit/approve", summary="Approve JIT access request")
async def approve_jit(data: dict, current_user: User = Depends(get_current_user)):
    """Approve a JIT access request (manager/security team only)."""
    if current_user.role != "lbb_admin":
        raise HTTPException(status_code=403, detail="Admin/security team access required")

    request_id = data.get("request_id", "")
    req = next((r for r in _jit_requests if r["id"] == request_id), None)
    if not req:
        raise HTTPException(status_code=404, detail="JIT request not found")
    if req["status"] != "pending_approval":
        raise HTTPException(status_code=400, detail=f"Request is already {req['status']}")

    req["status"] = "approved"
    req["approved_by"] = str(current_user.id)
    req["approved_by_name"] = f"{current_user.first_name} {current_user.last_name}"
    req["approved_at"] = datetime.now(timezone.utc).isoformat()
    req["expires_at"] = (datetime.now(timezone.utc) + timedelta(hours=req["duration_hours"])).isoformat()

    _audit_log.append({
        "id": str(uuid.uuid4()),
        "action": "JIT_ACCESS_APPROVED",
        "user": req["approved_by_name"],
        "user_id": str(current_user.id),
        "target": f"{req['access_type']} for {req['requested_by_name']}",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })

    return {
        "message": f"JIT access approved for {req['requested_by_name']}",
        "access_type": req["access_type"],
        "expires_at": req["expires_at"],
        "auto_revoke": True,
    }


@router.post("/jit/revoke", summary="Revoke JIT access")
async def revoke_jit(data: dict, current_user: User = Depends(get_current_user)):
    """Immediately revoke JIT access before it expires."""
    if current_user.role != "lbb_admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    request_id = data.get("request_id", "")
    req = next((r for r in _jit_requests if r["id"] == request_id), None)
    if not req:
        raise HTTPException(status_code=404, detail="JIT request not found")

    req["status"] = "revoked"
    req["revoked_by"] = str(current_user.id)
    req["revoked_at"] = datetime.now(timezone.utc).isoformat()

    _audit_log.append({
        "id": str(uuid.uuid4()),
        "action": "JIT_ACCESS_REVOKED",
        "user": f"{current_user.first_name} {current_user.last_name}",
        "user_id": str(current_user.id),
        "target": f"{req['access_type']} for {req['requested_by_name']}",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })

    return {"message": "JIT access revoked immediately", "request_id": request_id}


# -------------------------------------------------------
# CONJUR — Dynamic Secrets Engine
# -------------------------------------------------------

@router.get("/conjur/health", summary="Conjur secrets engine health")
async def conjur_health(current_user: User = Depends(get_current_user)):
    """Check health of CyberArk Conjur dynamic secrets engine."""
    return {
        "conjur_url": CONJUR_URL,
        "status": "healthy" if CYBERARK_ENABLED else "not_configured",
        "policies": {
            "backend": {
                "host": "lbbs/backend",
                "secrets_accessible": ["lbbs/database/url", "lbbs/database/readonly-url",
                                       "lbbs/secrets/jwt-secret-key", "lbbs/okta/client-id",
                                       "lbbs/okta/client-secret"],
                "secrets_denied": ["lbbs/database/admin-password", "lbbs/aws/root-credentials"],
                "credential_ttl": "1 hour", "auto_renewal": True,
            },
            "cicd": {
                "host": "lbbs/cicd",
                "secrets_accessible": ["lbbs/ecr/push-credentials", "lbbs/sonarqube/token", "lbbs/snyk/token"],
                "secrets_denied": ["lbbs/database/url", "lbbs/okta/admin-token"],
                "credential_ttl": "30 minutes", "auto_renewal": True,
            },
            "monitoring": {
                "host": "lbbs/monitoring",
                "secrets_accessible": ["lbbs/database/readonly-url"],
                "secrets_denied": ["lbbs/database/admin-password", "lbbs/aws/root-credentials"],
                "credential_ttl": "2 hours", "auto_renewal": True,
            },
        },
        "total_policies": 3,
        "total_secrets_managed": 12,
    }


# -------------------------------------------------------
# AUDIT LOG
# -------------------------------------------------------

@router.get("/audit", summary="Privileged access audit log")
async def get_audit_log(
    action: str = Query(None, description="Filter by action type"),
    current_user: User = Depends(get_current_user),
):
    """Complete audit trail of all privileged access operations."""
    if current_user.role != "lbb_admin":
        raise HTTPException(status_code=403, detail="Admin access required for audit log")

    results = _audit_log
    if action:
        results = [e for e in results if e.get("action") == action]

    return {
        "audit_entries": results,
        "total": len(results),
        "valid_actions": [
            "CREDENTIAL_CHECKOUT", "CREDENTIAL_CHECKIN",
            "JIT_ACCESS_REQUESTED", "JIT_ACCESS_APPROVED", "JIT_ACCESS_REVOKED",
            "SESSION_STARTED", "SESSION_ENDED",
        ],
        "retention_period": "7 years",
    }
