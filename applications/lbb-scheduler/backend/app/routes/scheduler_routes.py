"""
Scheduler Routes — Monitor and Trigger Cron Jobs
===================================================
  GET  /api/v1/scheduler/status     → View all jobs
  POST /api/v1/scheduler/trigger    → Manually run a job
"""

from fastapi import APIRouter, Depends, HTTPException
from app.core.security import get_current_user
from app.models.user import User
from app.scheduler.engine import get_scheduler_status
from app.scheduler.jobs import (
    send_14_day_reminders,
    send_4_day_reminders,
    send_post_event_survey_reminders,
    send_donation_thank_you_reminders,
    send_pending_approval_reminders,
    expire_jit_access,
    revoke_expired_checkouts,
    generate_daily_health_report,
)

router = APIRouter(
    prefix="/scheduler",
    tags=["Scheduler — Cron Jobs"],
)

JOB_MAP = {
    "14_day_reminders": send_14_day_reminders,
    "4_day_reminders": send_4_day_reminders,
    "survey_reminders": send_post_event_survey_reminders,
    "donation_reminders": send_donation_thank_you_reminders,
    "pending_approvals": send_pending_approval_reminders,
    "jit_expiration": expire_jit_access,
    "checkout_revocation": revoke_expired_checkouts,
    "daily_health_report": generate_daily_health_report,
}


@router.get("/status", summary="View all scheduled jobs")
async def scheduler_status(
    current_user: User = Depends(get_current_user),
):
    """Returns the status of all cron jobs including next run time."""
    if current_user.role not in ("lbb_admin", "it_support"):
        raise HTTPException(status_code=403, detail="Admin access required")

    return get_scheduler_status()


@router.post("/trigger", summary="Manually trigger a cron job")
async def trigger_job(
    data: dict,
    current_user: User = Depends(get_current_user),
):
    """
    Manually trigger a scheduled job for testing.
    Pass {"job_id": "14_day_reminders"} to run immediately.
    """
    if current_user.role not in ("lbb_admin", "it_support"):
        raise HTTPException(status_code=403, detail="Admin access required")

    job_id = data.get("job_id", "")
    if job_id not in JOB_MAP:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown job. Valid: {list(JOB_MAP.keys())}",
        )

    result = JOB_MAP[job_id]()
    return {
        "message": f"Job '{job_id}' executed",
        "result": result,
    }
