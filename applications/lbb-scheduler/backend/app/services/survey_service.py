"""
Survey Service — Feedback Collection Business Logic
======================================================
Handles all three survey types:
  - Volunteer surveys (submitted by volunteers)
  - Student surveys (entered by school/LBB admins)
  - School surveys (entered by school/LBB admins)

ConOps references:
  6.5.13: Volunteer survey questions
  6.5.14: Student survey questions
  6.5.15: School survey questions
"""

from sqlalchemy.orm import Session

from app.models.survey import VolunteerSurvey, StudentSurvey, SchoolSurvey
from app.schemas.survey import (
    VolunteerSurveyCreate,
    StudentSurveyCreate,
    SchoolSurveyCreate,
)


# ===============================================================
# Volunteer Surveys
# ===============================================================

def create_volunteer_survey(
    db: Session, volunteer_id: str, data: VolunteerSurveyCreate
) -> VolunteerSurvey:
    """Volunteer submits their post-event survey."""
    survey = VolunteerSurvey(
        volunteer_id=volunteer_id,
        academic_year_id=data.academic_year_id,
        event_id=data.event_id,
        q1_participate_next_year=data.q1_participate_next_year,
        q2_recruit_contacts=data.q2_recruit_contacts,
        q3_time_feedback=data.q3_time_feedback,
        q4_take_home_items=data.q4_take_home_items,
        q5_hands_on_satisfaction=data.q5_hands_on_satisfaction,
        q6_comments=data.q6_comments,
    )

    db.add(survey)
    db.commit()
    db.refresh(survey)
    return survey


def list_volunteer_surveys(
    db: Session, academic_year_id: str = None
) -> dict:
    """List volunteer surveys with optional year filter."""
    query = db.query(VolunteerSurvey)
    if academic_year_id:
        query = query.filter(
            VolunteerSurvey.academic_year_id == academic_year_id
        )
    surveys = query.order_by(VolunteerSurvey.submitted_at.desc()).all()
    return {"surveys": surveys, "total": len(surveys)}


def get_volunteer_survey(db: Session, survey_id: str) -> VolunteerSurvey:
    """Get a single volunteer survey by ID."""
    survey = db.query(VolunteerSurvey).filter(
        VolunteerSurvey.id == survey_id
    ).first()
    if not survey:
        raise ValueError("Volunteer survey not found")
    return survey


# ===============================================================
# Student Surveys
# ===============================================================

def create_student_survey(
    db: Session, entered_by_id: str, data: StudentSurveyCreate
) -> StudentSurvey:
    """Admin enters a student survey from paper forms."""
    survey = StudentSurvey(
        academic_year_id=data.academic_year_id,
        event_id=data.event_id,
        school_id=data.school_id,
        q1_learned_new_skill=data.q1_learned_new_skill,
        q2_speaker_engaging=data.q2_speaker_engaging,
        q3_share_with_family=data.q3_share_with_family,
        q4_sessions_attended=data.q4_sessions_attended,
        q5_favorite_session=data.q5_favorite_session,
        q6_improvement_suggestions=data.q6_improvement_suggestions,
        entered_by=entered_by_id,
    )

    db.add(survey)
    db.commit()
    db.refresh(survey)
    return survey


def list_student_surveys(
    db: Session,
    academic_year_id: str = None,
    school_id: str = None,
) -> dict:
    """List student surveys with optional filters."""
    query = db.query(StudentSurvey)
    if academic_year_id:
        query = query.filter(
            StudentSurvey.academic_year_id == academic_year_id
        )
    if school_id:
        query = query.filter(StudentSurvey.school_id == school_id)
    surveys = query.order_by(StudentSurvey.entered_at.desc()).all()
    return {"surveys": surveys, "total": len(surveys)}


def get_student_survey(db: Session, survey_id: str) -> StudentSurvey:
    """Get a single student survey by ID."""
    survey = db.query(StudentSurvey).filter(
        StudentSurvey.id == survey_id
    ).first()
    if not survey:
        raise ValueError("Student survey not found")
    return survey


# ===============================================================
# School Surveys
# ===============================================================

def create_school_survey(
    db: Session, entered_by_id: str, data: SchoolSurveyCreate
) -> SchoolSurvey:
    """Admin enters a school administrator's survey."""
    survey = SchoolSurvey(
        academic_year_id=data.academic_year_id,
        school_id=data.school_id,
        q1_school_name=data.q1_school_name,
        q2_role=data.q2_role,
        q3_fills_gap=data.q3_fills_gap,
        q4_improvements=data.q4_improvements,
        q5_additional_comments=data.q5_additional_comments,
        entered_by=entered_by_id,
    )

    db.add(survey)
    db.commit()
    db.refresh(survey)
    return survey


def list_school_surveys(
    db: Session, academic_year_id: str = None
) -> dict:
    """List school surveys with optional year filter."""
    query = db.query(SchoolSurvey)
    if academic_year_id:
        query = query.filter(
            SchoolSurvey.academic_year_id == academic_year_id
        )
    surveys = query.order_by(SchoolSurvey.entered_at.desc()).all()
    return {"surveys": surveys, "total": len(surveys)}


def get_school_survey(db: Session, survey_id: str) -> SchoolSurvey:
    """Get a single school survey by ID."""
    survey = db.query(SchoolSurvey).filter(
        SchoolSurvey.id == survey_id
    ).first()
    if not survey:
        raise ValueError("School survey not found")
    return survey
