"""
Reports Routes — Complete Analytics API (ConOps 6.5.16)
=========================================================
  GET /reports/events-summary[.csv/.pdf]
  GET /reports/volunteer-engagement[.csv/.pdf]
  GET /reports/open-slots
  GET /reports/class-frequency
  GET /reports/volunteer-lists
  GET /reports/donations[.csv]
  GET /reports/take-home-items
  GET /reports/dashboard
  GET /reports/donations/{id}/thank-you.pdf
"""

import csv
import io
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.donation import Donation
from app.services.reports_service import (
    events_summary_report,
    volunteer_engagement_report,
    open_slots_report,
    class_frequency_report,
    volunteer_lists_report,
    donation_summary_report,
    generate_thank_you_pdf,
)

router = APIRouter(prefix="/reports", tags=["Reports & Analytics"])


def _admin_check(user):
    if user.role not in ("lbb_admin", "it_support"):
        raise HTTPException(status_code=403, detail="Admin access required")


def _parse_date(value, name):
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid {name}. Use YYYY-MM-DD.")


# ---------------------------------------------------------------
# Events Summary
# ---------------------------------------------------------------
@router.get("/events-summary", summary="Events summary (JSON)")
async def get_events_summary(
    academic_year_id: str = Query(None),
    start_date: str = Query(None), end_date: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    return events_summary_report(
        db, academic_year_id, _parse_date(start_date, "start_date"),
        _parse_date(end_date, "end_date"),
    )


@router.get("/events-summary.csv", summary="Events summary (CSV)")
async def events_csv(
    academic_year_id: str = Query(None),
    start_date: str = Query(None), end_date: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    r = events_summary_report(
        db, academic_year_id, _parse_date(start_date, "start_date"),
        _parse_date(end_date, "end_date"),
    )
    return _csv_response(r, [
        ("KEY METRICS", "kpis"),
        ("EVENTS BY STATUS", "by_status", ["status", "count"]),
        ("EVENTS BY MONTH", "by_month", ["month", "events"]),
        ("TOP SCHOOLS", "top_schools", ["school", "events"]),
    ], f"lbb_events_{date.today().isoformat()}.csv")


@router.get("/events-summary.pdf", summary="Events summary (PDF)")
async def events_pdf(
    academic_year_id: str = Query(None),
    start_date: str = Query(None), end_date: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    r = events_summary_report(
        db, academic_year_id, _parse_date(start_date, "start_date"),
        _parse_date(end_date, "end_date"),
    )
    return _pdf_response(r, "LBB Events Summary", [
        ("Events by Status", "by_status", ["status", "count"]),
        ("Events by Month", "by_month", ["month", "events"]),
        ("Top Schools", "top_schools", ["school", "events"]),
    ], f"lbb_events_{date.today().isoformat()}.pdf")


# ---------------------------------------------------------------
# Volunteer Engagement
# ---------------------------------------------------------------
@router.get("/volunteer-engagement", summary="Volunteer engagement (JSON)")
async def get_volunteer_engagement(
    academic_year_id: str = Query(None),
    start_date: str = Query(None), end_date: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    return volunteer_engagement_report(
        db, academic_year_id, _parse_date(start_date, "start_date"),
        _parse_date(end_date, "end_date"),
    )


@router.get("/volunteer-engagement.csv", summary="Volunteer engagement (CSV)")
async def volunteer_csv(
    academic_year_id: str = Query(None),
    start_date: str = Query(None), end_date: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    r = volunteer_engagement_report(
        db, academic_year_id, _parse_date(start_date, "start_date"),
        _parse_date(end_date, "end_date"),
    )
    return _csv_response(r, [
        ("KEY METRICS", "kpis"),
        ("SIGNUPS BY MONTH", "signups_by_month", ["month", "signups"]),
        ("TOP VOLUNTEERS", "top_volunteers", ["name", "events_signed_up"]),
    ], f"lbb_volunteers_{date.today().isoformat()}.csv")


@router.get("/volunteer-engagement.pdf", summary="Volunteer engagement (PDF)")
async def volunteer_pdf(
    academic_year_id: str = Query(None),
    start_date: str = Query(None), end_date: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    r = volunteer_engagement_report(
        db, academic_year_id, _parse_date(start_date, "start_date"),
        _parse_date(end_date, "end_date"),
    )
    return _pdf_response(r, "LBB Volunteer Engagement", [
        ("Signups by Month", "signups_by_month", ["month", "signups"]),
        ("Top Volunteers", "top_volunteers", ["name", "events_signed_up"]),
    ], f"lbb_volunteers_{date.today().isoformat()}.pdf")


# ---------------------------------------------------------------
# Open Slots
# ---------------------------------------------------------------
@router.get("/open-slots", summary="Events with unfilled class slots")
async def get_open_slots(
    academic_year_id: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    return open_slots_report(db, academic_year_id)


# ---------------------------------------------------------------
# Class Frequency
# ---------------------------------------------------------------
@router.get("/class-frequency", summary="Class frequency report")
async def get_class_frequency(
    academic_year_id: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    return class_frequency_report(db, academic_year_id)


# ---------------------------------------------------------------
# Volunteer Lists (active/inactive)
# ---------------------------------------------------------------
@router.get("/volunteer-lists", summary="Active and inactive volunteers")
async def get_volunteer_lists(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    return volunteer_lists_report(db)


# ---------------------------------------------------------------
# Donation Summary
# ---------------------------------------------------------------
@router.get("/donations-summary", summary="Donation summary")
async def get_donation_summary(
    start_date: str = Query(None), end_date: str = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _admin_check(current_user)
    return donation_summary_report(
        db, _parse_date(start_date, "start_date"),
        _parse_date(end_date, "end_date"),
    )


# ---------------------------------------------------------------
# Thank-You Letter PDF
# ---------------------------------------------------------------
@router.get(
    "/donations/{donation_id}/thank-you.pdf",
    summary="Generate thank-you letter PDF",
)
async def get_thank_you_pdf(
    donation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate a professional thank-you letter for a donation."""
    _admin_check(current_user)
    donation = db.query(Donation).filter(Donation.id == donation_id).first()
    if not donation:
        raise HTTPException(status_code=404, detail="Donation not found")

    pdf_bytes = generate_thank_you_pdf(donation)

    # Mark letter as sent
    donation.letter_sent = True
    db.commit()

    donor = (donation.donor_name or "donor").replace(" ", "_")
    filename = f"lbb_thank_you_{donor}_{date.today().isoformat()}.pdf"
    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
def _csv_response(report, sections, filename):
    """Build CSV from report dict."""
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([report.get("report_type", "Report").replace("_", " ").title()])
    writer.writerow(["Generated", report.get("generated_at", "")])
    writer.writerow([])

    for section in sections:
        title = section[0]
        key = section[1]
        data = report.get(key, {})

        if isinstance(data, dict):
            writer.writerow([title])
            for k, v in data.items():
                writer.writerow([k.replace("_", " ").title(), v])
            writer.writerow([])
        elif isinstance(data, list) and len(section) > 2:
            cols = section[2]
            writer.writerow([title])
            writer.writerow([c.replace("_", " ").title() for c in cols])
            for row in data:
                writer.writerow([row.get(c, "") for c in cols])
            writer.writerow([])

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


def _pdf_response(report, title, sections, filename):
    """Build PDF from report dict."""
    from reportlab.lib.pagesizes import letter
    from reportlab.lib import colors
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle

    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=letter, leftMargin=0.75 * inch,
                            rightMargin=0.75 * inch, topMargin=0.75 * inch,
                            bottomMargin=0.75 * inch)
    styles = getSampleStyleSheet()
    ts = ParagraphStyle("T", parent=styles["Title"], fontSize=22,
                        textColor=colors.HexColor("#1F4E79"), spaceAfter=12)
    hs = ParagraphStyle("H", parent=styles["Heading2"], fontSize=14,
                        textColor=colors.HexColor("#1F4E79"), spaceBefore=16, spaceAfter=8)
    ms = ParagraphStyle("M", parent=styles["Normal"], fontSize=9,
                        textColor=colors.grey, spaceAfter=12)
    story = [
        Paragraph(title, ts),
        Paragraph(f"Generated: {report.get('generated_at', '')}", ms),
    ]

    # KPIs
    kpis = report.get("kpis", {})
    if kpis:
        story.append(Paragraph("Key Performance Indicators", hs))
        kpi_rows = [["Metric", "Value"]]
        for k, v in kpis.items():
            kpi_rows.append([k.replace("_", " ").title(), str(v)])
        tbl = Table(kpi_rows, colWidths=[3.5 * inch, 2 * inch])
        tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F4E79")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 10),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1),
             [colors.HexColor("#F2F7FB"), colors.white]),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CCCCCC")),
            ("TOPPADDING", (0, 0), (-1, -1), 6),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ]))
        story.append(tbl)

    for sec_title, data_key, col_keys in sections:
        data = report.get(data_key, [])
        if not data:
            continue
        story.append(Paragraph(sec_title, hs))
        headers = [c.replace("_", " ").title() for c in col_keys]
        rows = [headers] + [[str(item.get(k, "")) for k in col_keys] for item in data]
        cw = 5.5 / len(col_keys) * inch
        tbl = Table(rows, colWidths=[cw] * len(col_keys))
        tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F4E79")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1),
             [colors.HexColor("#F2F7FB"), colors.white]),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CCCCCC")),
            ("TOPPADDING", (0, 0), (-1, -1), 5),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ]))
        story.append(tbl)

    story.append(Spacer(1, 0.3 * inch))
    story.append(Paragraph("Life Beyond the Books — Confidential Internal Report",
                           ParagraphStyle("F", parent=styles["Normal"], fontSize=8,
                                          textColor=colors.grey, alignment=1)))
    doc.build(story)
    buf.seek(0)
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )
