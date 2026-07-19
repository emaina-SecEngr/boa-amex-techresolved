"""
Reports Service — Complete Analytics (ConOps 6.5.16, 6.6.12, 6.6.13)
======================================================================
"""

from datetime import datetime, timezone
from collections import defaultdict

from app.models.user import User
from app.models.event import (
    LBBEvent,
    EventRegistration,
    VolunteerEventSignup,
)
from app.models.school import School
from app.models.donation import Donation
from app.models.life_skills_class import LifeSkillsClass


def events_summary_report(db, academic_year_id=None, start_date=None, end_date=None):
    """Events summary with KPIs and breakdowns."""
    query = db.query(LBBEvent)
    if academic_year_id:
        query = query.filter(LBBEvent.academic_year_id == academic_year_id)
    if start_date:
        query = query.filter(LBBEvent.event_date >= start_date)
    if end_date:
        query = query.filter(LBBEvent.event_date <= end_date)

    events = query.all()
    total = len(events)
    status_counts = defaultdict(int)
    for e in events:
        status_counts[e.status] += 1

    by_month = defaultdict(int)
    for e in events:
        if e.event_date:
            by_month[e.event_date.strftime("%Y-%m")] += 1

    regs = (
        db.query(EventRegistration, School)
        .join(School, EventRegistration.school_id == School.id)
        .all()
    )
    event_ids = {str(e.id) for e in events}
    relevant = [(r, s) for r, s in regs if str(r.event_id) in event_ids]

    district_counts = defaultdict(int)
    school_counts = defaultdict(int)
    total_students = 0
    for reg, school in relevant:
        district_counts[school.district or "Unspecified"] += 1
        school_counts[school.school_name] += 1
        total_students += reg.anticipated_students or 0

    top_schools = sorted(
        [{"school": k, "events": v} for k, v in school_counts.items()],
        key=lambda x: x["events"], reverse=True,
    )[:10]

    avail_or_used = status_counts["available"] + status_counts["reserved"] + status_counts["completed"]
    registered = status_counts["reserved"] + status_counts["completed"]
    fill_rate = (registered / avail_or_used * 100) if avail_or_used > 0 else 0
    avg_students = (total_students / len(relevant)) if relevant else 0

    return {
        "report_type": "events_summary",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "filters": _filters(academic_year_id, start_date, end_date),
        "kpis": {
            "total_events": total, "registered_events": registered,
            "available_events": status_counts["available"],
            "completed_events": status_counts["completed"],
            "cancelled_events": status_counts["cancelled"],
            "fill_rate_pct": round(fill_rate, 1),
            "total_students_served": total_students,
            "avg_students_per_event": round(avg_students, 1),
            "districts_participating": len(district_counts),
            "schools_participating": len(school_counts),
        },
        "by_status": [{"status": k, "count": v} for k, v in status_counts.items()],
        "by_month": [{"month": m, "events": c} for m, c in sorted(by_month.items())],
        "by_district": [
            {"district": k, "events": v}
            for k, v in sorted(district_counts.items(), key=lambda x: x[1], reverse=True)
        ],
        "top_schools": top_schools,
    }


def volunteer_engagement_report(db, academic_year_id=None, start_date=None, end_date=None):
    """Volunteer engagement metrics."""
    sq = (
        db.query(VolunteerEventSignup, LBBEvent, User)
        .join(LBBEvent, VolunteerEventSignup.event_id == LBBEvent.id)
        .join(User, VolunteerEventSignup.volunteer_id == User.id)
    )
    if academic_year_id:
        sq = sq.filter(LBBEvent.academic_year_id == academic_year_id)
    if start_date:
        sq = sq.filter(LBBEvent.event_date >= start_date)
    if end_date:
        sq = sq.filter(LBBEvent.event_date <= end_date)

    signups = sq.all()
    vol_ids = set()
    vol_counts = defaultdict(int)
    vol_names = {}
    vol_districts = defaultdict(int)
    by_month = defaultdict(int)

    for signup, event, vol in signups:
        vol_ids.add(str(vol.id))
        vol_counts[str(vol.id)] += 1
        vol_names[str(vol.id)] = (
            f"{vol.first_name or ''} {vol.last_name or ''}".strip() or vol.username
        )
        vol_districts[vol.affiliation or "Unspecified"] += 1
        if event.event_date:
            by_month[event.event_date.strftime("%Y-%m")] += 1

    top = sorted(
        [{"volunteer_id": v, "name": vol_names[v], "events_signed_up": c}
         for v, c in vol_counts.items()],
        key=lambda x: x["events_signed_up"], reverse=True,
    )[:10]

    total_active = db.query(User).filter(
        User.role == "volunteer", User.is_active.is_(True)
    ).count()
    avg = (len(signups) / len(vol_ids)) if vol_ids else 0
    pct = (len(vol_ids) / total_active * 100) if total_active > 0 else 0

    return {
        "report_type": "volunteer_engagement",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "filters": _filters(academic_year_id, start_date, end_date),
        "kpis": {
            "total_active_volunteers": total_active,
            "volunteers_who_signed_up": len(vol_ids),
            "total_signups": len(signups),
            "avg_events_per_volunteer": round(avg, 1),
            "participation_rate_pct": round(pct, 1),
            "districts_represented": len(vol_districts),
        },
        "signups_by_month": [{"month": m, "signups": c} for m, c in sorted(by_month.items())],
        "top_volunteers": top,
        "by_district": [
            {"district": k, "signups": v}
            for k, v in sorted(vol_districts.items(), key=lambda x: x[1], reverse=True)
        ],
    }


def open_slots_report(db, academic_year_id=None):
    """Events with unfilled volunteer slots."""
    query = db.query(LBBEvent).filter(LBBEvent.status.in_(["available", "reserved"]))
    if academic_year_id:
        query = query.filter(LBBEvent.academic_year_id == academic_year_id)

    events = query.order_by(LBBEvent.event_date.asc()).all()
    total_classes = db.query(LifeSkillsClass).count()
    slots = []

    for event in events:
        signup_count = (
            db.query(VolunteerEventSignup)
            .filter(VolunteerEventSignup.event_id == event.id)
            .count()
        )
        unfilled = max(0, total_classes - signup_count)
        if unfilled > 0 or signup_count == 0:
            reg = db.query(EventRegistration).filter(
                EventRegistration.event_id == event.id
            ).first()
            school_name = "No school registered"
            if reg:
                s = db.query(School).filter(School.id == reg.school_id).first()
                school_name = s.school_name if s else "Unknown"
            slots.append({
                "event_date": event.event_date.isoformat() if event.event_date else None,
                "status": event.status, "school": school_name,
                "volunteer_signups": signup_count, "unfilled_slots": unfilled,
            })

    return {
        "report_type": "open_slots",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_events_with_open_slots": len(slots),
        "events": slots,
    }


def class_frequency_report(db, academic_year_id=None):
    """How often each life skills class is taught."""
    classes = db.query(LifeSkillsClass).all()
    freq = []
    for cls in classes:
        sq = db.query(VolunteerEventSignup).filter(
            VolunteerEventSignup.class_id == cls.id
        )
        if academic_year_id:
            sq = sq.join(LBBEvent, VolunteerEventSignup.event_id == LBBEvent.id).filter(
                LBBEvent.academic_year_id == academic_year_id
            )
        count = sq.count()
        lead = db.query(User).filter(User.id == cls.lead_volunteer_id).first()
        lead_name = ""
        if lead:
            lead_name = f"{lead.first_name or ''} {lead.last_name or ''}".strip() or lead.username
        freq.append({
            "class_name": cls.class_name, "lead_volunteer": lead_name,
            "times_scheduled": count, "max_students": cls.max_students,
            "take_home_items": cls.take_home_items or "",
        })
    freq.sort(key=lambda x: x["times_scheduled"], reverse=True)
    return {
        "report_type": "class_frequency",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_classes": len(freq), "classes": freq,
    }


def volunteer_lists_report(db):
    """Active and inactive volunteer lists."""
    vols = db.query(User).filter(User.role == "volunteer").all()
    active, inactive = [], []
    for v in vols:
        entry = {
            "name": f"{v.first_name or ''} {v.last_name or ''}".strip() or v.username,
            "email": v.email, "phone": v.phone_number,
            "affiliation": v.affiliation or "",
            "member_since": v.created_at.isoformat() if v.created_at else None,
        }
        (active if v.is_active else inactive).append(entry)
    return {
        "report_type": "volunteer_lists",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_active": len(active), "total_inactive": len(inactive),
        "active_volunteers": active, "inactive_volunteers": inactive,
    }


def donation_summary_report(db, start_date=None, end_date=None):
    """Donation totals by kind, month, and top donors."""
    query = db.query(Donation)
    if start_date:
        query = query.filter(Donation.donation_date >= start_date)
    if end_date:
        query = query.filter(Donation.donation_date <= end_date)

    donations = query.all()
    total_amount = 0.0
    by_kind = defaultdict(float)
    by_month = defaultdict(float)
    donor_totals = defaultdict(float)
    letters_pending = 0

    for d in donations:
        amt = float(d.amount) if d.amount else 0.0
        total_amount += amt
        by_kind[d.donation_kind or "unspecified"] += amt
        if d.donation_date:
            by_month[d.donation_date.strftime("%Y-%m")] += amt
        donor_totals[d.donor_name or "Anonymous"] += amt
        if not d.letter_sent:
            letters_pending += 1

    top_donors = sorted(
        [{"donor": k, "total": round(v, 2)} for k, v in donor_totals.items()],
        key=lambda x: x["total"], reverse=True,
    )[:10]

    return {
        "report_type": "donation_summary",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "kpis": {
            "total_donations": len(donations),
            "total_amount": round(total_amount, 2),
            "cash_donations": round(by_kind.get("cash", 0), 2),
            "in_kind_donations": round(by_kind.get("in-kind", 0), 2),
            "letters_pending": letters_pending,
            "unique_donors": len(donor_totals),
        },
        "by_kind": [{"kind": k, "amount": round(v, 2)} for k, v in by_kind.items()],
        "by_month": [
            {"month": m, "amount": round(v, 2)} for m, v in sorted(by_month.items())
        ],
        "top_donors": top_donors,
    }


def generate_thank_you_pdf(donation) -> bytes:
    """Generate a thank-you letter PDF for a donation."""
    import io
    from reportlab.lib.pagesizes import letter
    from reportlab.lib import colors
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer

    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=letter, leftMargin=inch, rightMargin=inch,
                            topMargin=inch, bottomMargin=inch)
    styles = getSampleStyleSheet()
    title_s = ParagraphStyle("T", parent=styles["Title"], fontSize=20,
                             textColor=colors.HexColor("#1F4E79"), spaceAfter=20)
    body_s = ParagraphStyle("B", parent=styles["Normal"], fontSize=12,
                            leading=18, spaceAfter=12)
    story = []
    story.append(Paragraph("Life Beyond the Books", title_s))
    story.append(Paragraph("Thank You for Your Generous Donation", ParagraphStyle(
        "Sub", parent=styles["Heading2"], textColor=colors.HexColor("#2E86AB"),
        spaceAfter=24)))
    story.append(Spacer(1, 0.3 * inch))

    date_str = ""
    if donation.donation_date:
        date_str = donation.donation_date.strftime("%B %d, %Y")

    story.append(Paragraph(f"Dear {donation.donor_name or 'Valued Donor'},", body_s))
    story.append(Paragraph(
        f"On behalf of Life Beyond the Books, we want to express our sincere gratitude "
        f"for your generous {donation.donation_kind or 'monetary'} donation"
        f"{' of $' + str(float(donation.amount)) if donation.amount else ''}"
        f"{' on ' + date_str if date_str else ''}. "
        f"Your support helps us continue our mission of preparing students "
        f"for life through experiential learning.", body_s))
    story.append(Paragraph(
        "Your contribution directly supports our programs in the Amphitheater "
        "and Flowing Wells School Districts, where community professionals "
        "volunteer to teach essential life skills to 8th grade students.", body_s))
    story.append(Paragraph(
        "This letter serves as your official acknowledgment of this "
        "tax-deductible donation. Please keep this for your records.", body_s))
    story.append(Spacer(1, 0.3 * inch))

    story.append(Paragraph("Donation Details:", ParagraphStyle(
        "DH", parent=body_s, fontSize=12, textColor=colors.HexColor("#1F4E79"), bold=True)))
    details = [
        f"Donor: {donation.donor_name or 'N/A'}",
        f"Amount: ${float(donation.amount):,.2f}" if donation.amount else "Amount: N/A",
        f"Type: {donation.donation_kind or 'N/A'}",
        f"Date: {date_str or 'N/A'}",
        f"Organization: {donation.donor_organization or 'N/A'}",
    ]
    for d in details:
        story.append(Paragraph(f"    {d}", body_s))
    story.append(Spacer(1, 0.4 * inch))

    story.append(Paragraph("With gratitude,", body_s))
    story.append(Paragraph("Life Beyond the Books Program", ParagraphStyle(
        "Sig", parent=body_s, textColor=colors.HexColor("#1F4E79"))))
    story.append(Paragraph("Tucson, Arizona", ParagraphStyle(
        "City", parent=body_s, fontSize=10, textColor=colors.grey)))
    story.append(Paragraph("EIN: XX-XXXXXXX", ParagraphStyle(
        "EIN", parent=body_s, fontSize=9, textColor=colors.grey)))

    doc.build(story)
    buf.seek(0)
    return buf.getvalue()


def _filters(year_id, start, end):
    return {
        "academic_year_id": year_id,
        "start_date": start.isoformat() if start else None,
        "end_date": end.isoformat() if end else None,
    }
