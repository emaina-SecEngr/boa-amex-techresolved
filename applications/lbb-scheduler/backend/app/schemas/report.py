"""
Canonical Pydantic models for admin reports (donations, events, attendance, MVP2 bundle).

Use these types for OpenAPI and `response_model` on report routes.
"""

from datetime import date

from pydantic import BaseModel, Field


class ReportPeriod(BaseModel):
    """Inclusive date filter (strings ISO YYYY-MM-DD or None for open-ended)."""

    start_date: str | None = None
    end_date: str | None = None


class DonationReportOut(BaseModel):
    """Aggregated donation totals for a period (SQL sums, not row dump)."""

    record_count: int = Field(ge=0)
    total_cash: str
    total_in_kind: str
    total_amount: str


class DonationReportResponse(BaseModel):
    """GET /reports/donations — period + donation aggregates."""

    period: ReportPeriod
    donations: DonationReportOut


class EventSummaryOut(BaseModel):
    """One scheduled LBB event row."""

    event_id: str
    event_date: date
    status: str


class EventsReportOut(BaseModel):
    """GET /reports/events — events in range with counts (single query)."""

    period: ReportPeriod
    events_in_period: int = Field(ge=0)
    events: list[EventSummaryOut]


class SurveyReportBlock(BaseModel):
    volunteer: int
    student: int
    school: int


class MVP2ReportResponse(BaseModel):
    """Bundled MVP2 dashboard report."""

    period: ReportPeriod
    donations: DonationReportOut
    events_in_period: int
    schools_total: int
    volunteer_profiles: int
    volunteer_user_accounts: int
    life_skills_classes: int
    surveys: SurveyReportBlock


class EventAttendanceRow(BaseModel):
    """One event joined to school registration + volunteer signup count."""

    event_id: str
    event_date: date
    event_status: str
    school_name: str | None = None
    anticipated_students: int | None = None
    volunteer_signup_count: int = 0


class EventAttendanceOut(BaseModel):
    """GET /reports/attendance — full attendance-style report."""

    period: ReportPeriod
    events: list[EventAttendanceRow]


# --- Backward-compatible aliases (older imports from app.schemas.reports) ---
AttendanceEventRow = EventAttendanceRow
AttendanceReportResponse = EventAttendanceOut
DonationReportBlock = DonationReportOut
