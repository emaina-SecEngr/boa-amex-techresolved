"""
Scheduler Engine — APScheduler Integration
=============================================
Manages all cron jobs using APScheduler.
Started automatically when the FastAPI app boots.

Schedule:
  07:00 daily   → Daily health report
  08:00 daily   → 14-day event reminders
  08:00 daily   → 4-day event reminders
  08:30 daily   → Pending approval reminders
  09:00 daily   → Post-event survey reminders
  09:00 Monday  → Donation thank-you reminders
  Every hour    → JIT access expiration
  Every hour    → Credential checkout auto-revoke
"""

import logging

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

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

logger = logging.getLogger(__name__)

scheduler = BackgroundScheduler()


def start_scheduler():
    """Register all cron jobs and start the scheduler."""
    if scheduler.running:
        logger.warning("Scheduler already running")
        return

    # 07:00 daily — System health report
    scheduler.add_job(
        generate_daily_health_report,
        CronTrigger(hour=7, minute=0),
        id="daily_health_report",
        name="Daily Health Report",
        replace_existing=True,
    )

    # 08:00 daily — 14-day pre-event reminders
    scheduler.add_job(
        send_14_day_reminders,
        CronTrigger(hour=8, minute=0),
        id="14_day_reminders",
        name="14-Day Event Reminders",
        replace_existing=True,
    )

    # 08:00 daily — 4-day pre-event reminders
    scheduler.add_job(
        send_4_day_reminders,
        CronTrigger(hour=8, minute=0),
        id="4_day_reminders",
        name="4-Day Event Reminders",
        replace_existing=True,
    )

    # 08:30 daily — Pending account approval reminders
    scheduler.add_job(
        send_pending_approval_reminders,
        CronTrigger(hour=8, minute=30),
        id="pending_approvals",
        name="Pending Approval Reminders",
        replace_existing=True,
    )

    # 09:00 daily — Post-event survey reminders
    scheduler.add_job(
        send_post_event_survey_reminders,
        CronTrigger(hour=9, minute=0),
        id="survey_reminders",
        name="Post-Event Survey Reminders",
        replace_existing=True,
    )

    # 09:00 Monday — Donation thank-you letter digest
    scheduler.add_job(
        send_donation_thank_you_reminders,
        CronTrigger(day_of_week="mon", hour=9, minute=0),
        id="donation_reminders",
        name="Donation Thank-You Reminders",
        replace_existing=True,
    )

    # Every hour — JIT access auto-expiration
    scheduler.add_job(
        expire_jit_access,
        IntervalTrigger(hours=1),
        id="jit_expiration",
        name="JIT Access Expiration",
        replace_existing=True,
    )

    # Every hour — Credential checkout auto-revoke
    scheduler.add_job(
        revoke_expired_checkouts,
        IntervalTrigger(hours=1),
        id="checkout_revocation",
        name="Credential Checkout Revocation",
        replace_existing=True,
    )

    scheduler.start()
    logger.info(
        f"SCHEDULER: Started with {len(scheduler.get_jobs())} jobs"
    )

    for job in scheduler.get_jobs():
        logger.info(
            f"  REGISTERED: {job.name} — {job.trigger}"
        )


def stop_scheduler():
    """Gracefully shut down the scheduler."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("SCHEDULER: Stopped")


def get_scheduler_status():
    """Return current status of all scheduled jobs."""
    jobs = []
    for job in scheduler.get_jobs():
        jobs.append({
            "id": job.id,
            "name": job.name,
            "trigger": str(job.trigger),
            "next_run": (
                job.next_run_time.isoformat()
                if job.next_run_time
                else None
            ),
        })
    return {
        "running": scheduler.running,
        "total_jobs": len(jobs),
        "jobs": jobs,
    }
