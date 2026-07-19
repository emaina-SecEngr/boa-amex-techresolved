"""
Scheduled Jobs — All Cron Job Implementations
=================================================
"""

import logging
import uuid
from datetime import datetime, timezone, timedelta

from app.core.database import SessionLocal
from app.models.user import User
from app.models.event import (
    LBBEvent,
    EventRegistration,
    VolunteerEventSignup,
)
from app.models.donation import Donation

logger = logging.getLogger(__name__)


def get_db():
    """Create a standalone database session for cron jobs."""
    db = SessionLocal()
    try:
        return db
    except Exception:
        db.close()
        raise


def send_14_day_reminders():
    """Runs daily at 8:00 AM. Sends 14-day pre-event reminders."""
    logger.info("CRON: Running 14-day event reminder job")
    db = get_db()
    try:
        target_date = (datetime.now(timezone.utc) + timedelta(days=14)).date()
        events = (
            db.query(LBBEvent)
            .filter(LBBEvent.event_date == target_date)
            .filter(LBBEvent.status.in_(["available", "reserved"]))
            .all()
        )
        if not events:
            logger.info("CRON: No events in 14 days — skipping")
            return {"events_processed": 0, "emails_sent": 0}

        total_emails = 0
        for event in events:
            signups = (
                db.query(VolunteerEventSignup)
                .filter(VolunteerEventSignup.event_id == event.id,
                        VolunteerEventSignup.reminder_14d_sent.is_(False))
                .all()
            )
            for signup in signups:
                volunteer = db.query(User).filter(User.id == signup.volunteer_id).first()
                if volunteer and volunteer.email:
                    _send_email(
                        to=volunteer.email,
                        subject="LBB Event Reminder — 14 Days Away",
                        body=(
                            f"Hi {volunteer.first_name},\n\n"
                            f"Reminder: you are signed up for an LBB event on "
                            f"{event.event_date.strftime('%B %d, %Y')}.\n\n"
                            f"— LBB Scheduler"
                        ),
                    )
                    signup.reminder_14d_sent = True
                    total_emails += 1

            regs = db.query(EventRegistration).filter(EventRegistration.event_id == event.id).all()
            for reg in regs:
                from app.models.school import School
                school = db.query(School).filter(School.id == reg.school_id).first()
                if school and school.poc_email:
                    _send_email(
                        to=school.poc_email,
                        subject="LBB Event Reminder — 14 Days Away",
                        body=(
                            f"Dear {school.poc_name},\n\n"
                            f"Reminder: {school.school_name} is registered for an LBB event on "
                            f"{event.event_date.strftime('%B %d, %Y')}.\n\n"
                            f"— LBB Scheduler"
                        ),
                    )
                    total_emails += 1

        db.commit()
        logger.info(f"CRON: 14-day reminders — {len(events)} events, {total_emails} emails sent")
        return {"events_processed": len(events), "emails_sent": total_emails}
    except Exception as e:
        db.rollback()
        logger.error(f"CRON: 14-day reminder failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()


def send_4_day_reminders():
    """Runs daily at 8:00 AM. Sends 4-day pre-event reminders."""
    logger.info("CRON: Running 4-day event reminder job")
    db = get_db()
    try:
        target_date = (datetime.now(timezone.utc) + timedelta(days=4)).date()
        events = (
            db.query(LBBEvent)
            .filter(LBBEvent.event_date == target_date)
            .filter(LBBEvent.status.in_(["available", "reserved"]))
            .all()
        )
        if not events:
            logger.info("CRON: No events in 4 days — skipping")
            return {"events_processed": 0, "emails_sent": 0}

        total_emails = 0
        for event in events:
            signups = (
                db.query(VolunteerEventSignup)
                .filter(VolunteerEventSignup.event_id == event.id,
                        VolunteerEventSignup.reminder_4d_sent.is_(False))
                .all()
            )
            for signup in signups:
                volunteer = db.query(User).filter(User.id == signup.volunteer_id).first()
                if volunteer and volunteer.email:
                    _send_email(
                        to=volunteer.email,
                        subject="LBB Event — This Week! Final Reminder (4 Days)",
                        body=(
                            f"Hi {volunteer.first_name},\n\n"
                            f"Your LBB event is THIS WEEK on "
                            f"{event.event_date.strftime('%A, %B %d')}.\n\n"
                            f"Time: {event.event_time or 'See schedule'}\n"
                            f"Notes: {event.notes or 'None'}\n\n"
                            f"— LBB Scheduler"
                        ),
                    )
                    signup.reminder_4d_sent = True
                    total_emails += 1

        db.commit()
        logger.info(f"CRON: 4-day reminders — {len(events)} events, {total_emails} emails sent")
        return {"events_processed": len(events), "emails_sent": total_emails}
    except Exception as e:
        db.rollback()
        logger.error(f"CRON: 4-day reminder failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()


def send_post_event_survey_reminders():
    """Runs daily at 9:00 AM. Sends survey links after events."""
    logger.info("CRON: Running post-event survey reminder job")
    db = get_db()
    try:
        yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).date()
        events = db.query(LBBEvent).filter(LBBEvent.event_date == yesterday).all()
        total_emails = 0

        for event in events:
            signups = db.query(VolunteerEventSignup).filter(
                VolunteerEventSignup.event_id == event.id
            ).all()
            for signup in signups:
                volunteer = db.query(User).filter(User.id == signup.volunteer_id).first()
                if volunteer and volunteer.email:
                    _send_email(
                        to=volunteer.email,
                        subject="Thank You! Please Complete Your LBB Volunteer Survey",
                        body=(
                            f"Hi {volunteer.first_name},\n\n"
                            f"Thank you for volunteering! Please complete your feedback survey.\n\n"
                            f"— LBB Scheduler"
                        ),
                    )
                    total_emails += 1

        db.commit()
        logger.info(f"CRON: Survey reminders — {len(events)} events, {total_emails} emails sent")
        return {"events_processed": len(events), "emails_sent": total_emails}
    except Exception as e:
        db.rollback()
        logger.error(f"CRON: Survey reminder failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()


def send_donation_thank_you_reminders():
    """Runs weekly on Monday at 9:00 AM. Notifies admins of pending thank-you letters."""
    logger.info("CRON: Running donation thank-you reminder job")
    db = get_db()
    try:
        pending = db.query(Donation).filter(Donation.letter_sent.is_(False)).all()
        if not pending:
            logger.info("CRON: No pending thank-you letters")
            return {"pending_letters": 0}

        admins = db.query(User).filter(User.role == "lbb_admin", User.is_active.is_(True)).all()
        donor_list = "\n".join(
            f"  - {d.donor_name}: ${float(d.amount):,.2f} ({d.donation_kind})"
            for d in pending
        )
        for admin in admins:
            if admin.email:
                _send_email(
                    to=admin.email,
                    subject=f"LBB Action Required: {len(pending)} Thank-You Letters Pending",
                    body=(
                        f"Hi {admin.first_name},\n\n"
                        f"{len(pending)} donor(s) need letters:\n\n"
                        f"{donor_list}\n\n"
                        f"— LBB Scheduler"
                    ),
                )

        logger.info(f"CRON: Thank-you reminders — {len(pending)} pending, notified {len(admins)} admins")
        return {"pending_letters": len(pending), "admins_notified": len(admins)}
    except Exception as e:
        logger.error(f"CRON: Thank-you reminder failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()


def send_pending_approval_reminders():
    """Runs daily at 8:30 AM. Notifies admins of stale pending accounts."""
    logger.info("CRON: Running pending approval reminder job")
    db = get_db()
    try:
        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        pending_users = db.query(User).filter(User.is_active.is_(False), User.created_at < cutoff).all()
        if not pending_users:
            logger.info("CRON: No stale pending approvals")
            return {"pending_users": 0}

        admins = db.query(User).filter(User.role == "lbb_admin", User.is_active.is_(True)).all()
        user_list = "\n".join(
            f"  - {u.first_name} {u.last_name} (@{u.username}, {u.role})"
            for u in pending_users
        )
        for admin in admins:
            if admin.email:
                _send_email(
                    to=admin.email,
                    subject=f"LBB: {len(pending_users)} Account(s) Awaiting Approval (>24h)",
                    body=f"Hi {admin.first_name},\n\nPending accounts:\n\n{user_list}\n\n— LBB Scheduler",
                )

        logger.info(f"CRON: Approval reminders — {len(pending_users)} pending, notified {len(admins)} admins")
        return {"pending_users": len(pending_users), "admins_notified": len(admins)}
    except Exception as e:
        logger.error(f"CRON: Approval reminder failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()


def expire_jit_access():
    """Runs every hour. Revokes expired JIT access requests."""
    logger.info("CRON: Running JIT access expiration job")
    try:
        from app.routes.cyberark import _jit_requests, _audit_log
    except ImportError:
        logger.warning("CRON: CyberArk routes not available")
        return {"expired": 0}

    now = datetime.now(timezone.utc)
    expired_count = 0
    for req in _jit_requests:
        if req["status"] == "approved" and req.get("expires_at"):
            expires = datetime.fromisoformat(req["expires_at"].replace("Z", "+00:00"))
            if now > expires:
                req["status"] = "expired"
                req["expired_at"] = now.isoformat()
                _audit_log.append({
                    "id": str(uuid.uuid4()),
                    "action": "JIT_ACCESS_AUTO_EXPIRED",
                    "user": "SYSTEM (cron)",
                    "target": f"{req['access_type']} for {req['requested_by_name']}",
                    "timestamp": now.isoformat(),
                })
                expired_count += 1

    logger.info(f"CRON: JIT expiration — {expired_count} revoked")
    return {"expired": expired_count}


def revoke_expired_checkouts():
    """Runs every hour. Auto-revokes expired credential checkouts."""
    logger.info("CRON: Running credential checkout expiration job")
    try:
        from app.routes.cyberark import _active_checkouts, _audit_log
    except ImportError:
        logger.warning("CRON: CyberArk routes not available")
        return {"revoked": 0}

    now = datetime.now(timezone.utc)
    revoked_count = 0
    for checkout in _active_checkouts:
        if checkout["status"] == "active" and checkout.get("expires_at"):
            expires = datetime.fromisoformat(checkout["expires_at"].replace("Z", "+00:00"))
            if now > expires:
                checkout["status"] = "auto_revoked"
                _audit_log.append({
                    "id": str(uuid.uuid4()),
                    "action": "CREDENTIAL_AUTO_REVOKED",
                    "user": "SYSTEM (cron)",
                    "target": f"{checkout['safe_name']}/{checkout['account_name']}",
                    "timestamp": now.isoformat(),
                })
                revoked_count += 1

    logger.info(f"CRON: Checkout expiration — {revoked_count} revoked")
    return {"revoked": revoked_count}


def generate_daily_health_report():
    """Runs daily at 7:00 AM. Sends system health summary to admins."""
    logger.info("CRON: Running daily health report job")
    db = get_db()
    try:
        total_users = db.query(User).count()
        active_users = db.query(User).filter(User.is_active.is_(True)).count()
        pending_users = db.query(User).filter(User.is_active.is_(False)).count()
        upcoming_events = (
            db.query(LBBEvent)
            .filter(LBBEvent.event_date >= datetime.now(timezone.utc).date())
            .filter(LBBEvent.status != "cancelled")
            .count()
        )
        pending_letters = db.query(Donation).filter(Donation.letter_sent.is_(False)).count()
        admins = db.query(User).filter(User.role == "lbb_admin", User.is_active.is_(True)).all()

        report = (
            f"LBBS Daily Health Report — {datetime.now(timezone.utc).strftime('%B %d, %Y')}\n"
            f"{'=' * 50}\n\n"
            f"Users: {total_users} total | {active_users} active | {pending_users} pending\n"
            f"Upcoming Events: {upcoming_events}\n"
            f"Pending Thank-You Letters: {pending_letters}\n\n"
            f"All systems operational.\n\n— LBB Scheduler"
        )
        for admin in admins:
            if admin.email:
                _send_email(
                    to=admin.email,
                    subject=f"LBB Daily Report — {datetime.now(timezone.utc).strftime('%m/%d/%Y')}",
                    body=report,
                )

        logger.info("CRON: Daily health report sent")
        return {"total_users": total_users, "upcoming_events": upcoming_events, "admins_notified": len(admins)}
    except Exception as e:
        logger.error(f"CRON: Health report failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()


def _send_email(to: str, subject: str, body: str):
    """Send email via SMTP in production, or log in development."""
    import os
    smtp_host = os.getenv("SMTP_HOST", "")
    if smtp_host:
        try:
            import smtplib
            from email.mime.text import MIMEText
            from email.mime.multipart import MIMEMultipart
            smtp_port = int(os.getenv("SMTP_PORT", "587"))
            smtp_user = os.getenv("SMTP_USER", "")
            smtp_pass = os.getenv("SMTP_PASSWORD", "")
            from_addr = os.getenv("SMTP_FROM", "noreply@lifebeyondthebooksaz.org")
            msg = MIMEMultipart()
            msg["From"] = from_addr
            msg["To"] = to
            msg["Subject"] = subject
            msg.attach(MIMEText(body, "plain"))
            with smtplib.SMTP(smtp_host, smtp_port) as server:
                server.starttls()
                if smtp_user:
                    server.login(smtp_user, smtp_pass)
                server.sendmail(from_addr, to, msg.as_string())
            logger.info(f"EMAIL SENT: {subject} -> {to}")
        except Exception as e:
            logger.error(f"EMAIL FAILED: {subject} -> {to}: {e}")
    else:
        logger.info(f"EMAIL (dev mode): To={to} Subject={subject}")
