import logging
from dataclasses import dataclass
from datetime import date, datetime, time
from pathlib import Path
from typing import Any

import emails  # type: ignore
from jinja2 import Template

from app.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# backend/ (contains main.py, email-templates/)
_BACKEND_ROOT = Path(__file__).resolve().parents[2]


@dataclass
class EmailData:
    html_content: str
    subject: str


def render_email_template(*, template_name: str, context: dict[str, Any]) -> str:
    path = _BACKEND_ROOT / "email-templates" / template_name
    template_str = path.read_text(encoding="utf-8")
    html_content = Template(template_str).render(context)
    return html_content


def send_email(
    *,
    email_to: str,
    subject: str = "",
    html_content: str = "",
) -> None:
    if not settings.emails_enabled:
        raise RuntimeError("SMTP not configured (set SMTP_HOST and EMAIL_FROM)")
    message = emails.Message(
        subject=subject,
        html=html_content,
        mail_from=(settings.EMAIL_FROM_NAME, settings.EMAIL_FROM),
    )
    smtp_options = {"host": settings.SMTP_HOST, "port": settings.SMTP_PORT}
    if settings.SMTP_TLS:
        smtp_options["tls"] = True
    elif settings.SMTP_SSL:
        smtp_options["ssl"] = True
    if settings.SMTP_USER:
        smtp_options["user"] = settings.SMTP_USER
    if settings.SMTP_PASSWORD:
        smtp_options["password"] = settings.SMTP_PASSWORD
    response = message.send(to=email_to, smtp=smtp_options)
    logger.info(f"send email result: {response}")


def send_email_optional(
    *,
    email_to: str,
    subject: str,
    html_content: str,
) -> bool:
    """
    Send email when SMTP is configured; otherwise log and return False.
    """
    if not settings.emails_enabled:
        logger.info(
            "[email disabled] would send to %s — %s",
            email_to,
            subject,
        )
        return False
    try:
        send_email(email_to=email_to, subject=subject, html_content=html_content)
        return True
    except Exception:
        logger.exception("Failed to send email to %s", email_to)
        return False


def notify_school_event_registration_email(
    *,
    poc_email: str,
    school_name: str,
    event_date: date,
    event_time: time | None,
    anticipated_students: int,
) -> bool:
    """Confirmation after a school successfully registers for an event date."""
    time_s = event_time.strftime("%H:%M") if event_time else "TBD"
    subject = f"{settings.APP_NAME} — School registration confirmed ({event_date})"
    html_content = render_email_template(
        template_name="school_registration_confirmation.html",
        context={
            "project_name": settings.APP_NAME,
            "school_name": school_name,
            "event_date": str(event_date),
            "event_time": time_s,
            "anticipated_students": anticipated_students,
        },
    )
    return send_email_optional(
        email_to=poc_email, subject=subject, html_content=html_content
    )


def notify_school_record_created_email(
    *,
    poc_email: str,
    school_name: str,
    poc_name: str,
    registered_at: datetime,
    frontend_base_url: str,
) -> bool:
    """
    Confirmation after an LBB admin successfully creates a school record (not event signup).
    """
    # Strip trailing slash for clean joins
    base = frontend_base_url.rstrip("/")
    login_url = f"{base}/login"
    schedule_url = f"{base}/school/schedule"
    registered_str = registered_at.strftime("%Y-%m-%d %H:%M UTC")
    subject = f"{settings.APP_NAME} — {school_name} added to the scheduler"
    html_content = render_email_template(
        template_name="school_record_created_confirmation.html",
        context={
            "project_name": settings.APP_NAME,
            "school_name": school_name,
            "poc_name": poc_name,
            "registered_at": registered_str,
            "login_url": login_url,
            "schedule_url": schedule_url,
        },
    )
    return send_email_optional(
        email_to=poc_email, subject=subject, html_content=html_content
    )


def notify_volunteer_signup_confirmation_email(
    *,
    volunteer_email: str,
    volunteer_name: str,
    event_date: date,
    event_time: time | None,
) -> bool:
    subject = f"{settings.APP_NAME} — Volunteer signup confirmed ({event_date})"
    time_s = event_time.strftime("%H:%M") if event_time else "TBD"
    html_content = render_email_template(
        template_name="volunteer_signup_confirmation.html",
        context={
            "project_name": settings.APP_NAME,
            "volunteer_name": volunteer_name,
            "event_date": str(event_date),
            "event_time": time_s,
        },
    )
    return send_email_optional(
        email_to=volunteer_email, subject=subject, html_content=html_content
    )


def notify_volunteer_event_reminder_email(
    *,
    volunteer_email: str,
    volunteer_name: str,
    event_date: date,
    event_time: time | None,
    reminder_kind: str,
) -> bool:
    """reminder_kind: '14d' or '4d'."""
    label = "two weeks" if reminder_kind == "14d" else "four days"
    subject = (
        f"{settings.APP_NAME} — Reminder: LBB event in {label} ({event_date})"
    )
    time_s = event_time.strftime("%H:%M") if event_time else "TBD"
    html_content = render_email_template(
        template_name="volunteer_event_reminder.html",
        context={
            "project_name": settings.APP_NAME,
            "volunteer_name": volunteer_name,
            "event_date": str(event_date),
            "event_time": time_s,
            "reminder_label": label,
        },
    )
    return send_email_optional(
        email_to=volunteer_email, subject=subject, html_content=html_content
    )


def generate_test_email(email_to: str) -> EmailData:
    project_name = settings.APP_NAME
    subject = f"{project_name} - Test email"
    html_content = render_email_template(
        template_name="test_email.html",
        context={"project_name": settings.APP_NAME, "email": email_to},
    )
    return EmailData(html_content=html_content, subject=subject)


def generate_reset_password_email(email_to: str, email: str, token: str) -> EmailData:
    project_name = settings.APP_NAME
    subject = f"{project_name} - Password recovery for user {email}"
    link = f"{settings.FRONTEND_HOST}/reset-password?token={token}"
    html_content = render_email_template(
        template_name="reset_password.html",
        context={
            "project_name": settings.APP_NAME,
            "username": email,
            "email": email_to,
            "valid_hours": settings.EMAIL_RESET_TOKEN_EXPIRE_HOURS,
            "link": link,
        },
    )
    return EmailData(html_content=html_content, subject=subject)


def generate_new_account_email(
    email_to: str, username: str, password: str
) -> EmailData:
    project_name = settings.APP_NAME
    subject = f"{project_name} - New account for user {username}"
    html_content = render_email_template(
        template_name="new_account.html",
        context={
            "project_name": settings.APP_NAME,
            "username": username,
            "password": password,
            "email": email_to,
            "link": settings.FRONTEND_HOST,
        },
    )
    return EmailData(html_content=html_content, subject=subject)
