"""
Survey Models — ConOps Sections 6.5.13, 6.5.14, 6.5.15
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Text, ForeignKey

from app.core.database import Base, GUID
from app.models.constants import USERS_ID, ACADEMIC_YEARS_ID, LBB_EVENTS_ID, SCHOOLS_ID


class VolunteerSurvey(Base):
    __tablename__ = "volunteer_surveys"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    volunteer_id = Column(GUID(), ForeignKey(USERS_ID), nullable=False)
    academic_year_id = Column(GUID(), ForeignKey(ACADEMIC_YEARS_ID), nullable=False)
    event_id = Column(GUID(), ForeignKey(LBB_EVENTS_ID), nullable=True)

    q1_participate_next_year = Column(String(10), nullable=True)
    q2_recruit_contacts = Column(Text, nullable=True)
    q3_time_feedback = Column(String(20), nullable=True)
    q4_take_home_items = Column(String(10), nullable=True)
    q5_hands_on_satisfaction = Column(Text, nullable=True)
    q6_comments = Column(Text, nullable=True)

    submitted_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    def __repr__(self) -> str:
        return f"<VolunteerSurvey(volunteer={self.volunteer_id})>"


class StudentSurvey(Base):
    __tablename__ = "student_surveys"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    academic_year_id = Column(GUID(), ForeignKey(ACADEMIC_YEARS_ID), nullable=False)
    event_id = Column(GUID(), ForeignKey(LBB_EVENTS_ID), nullable=True)
    school_id = Column(GUID(), ForeignKey(SCHOOLS_ID), nullable=True)

    q1_learned_new_skill = Column(String(5), nullable=True)
    q2_speaker_engaging = Column(String(10), nullable=True)
    q3_share_with_family = Column(String(10), nullable=True)
    q4_sessions_attended = Column(Text, nullable=True)
    q5_favorite_session = Column(String(100), nullable=True)
    q6_improvement_suggestions = Column(Text, nullable=True)

    entered_by = Column(GUID(), ForeignKey(USERS_ID), nullable=True)
    entered_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    def __repr__(self) -> str:
        return f"<StudentSurvey(id={self.id}, school={self.school_id})>"


class SchoolSurvey(Base):
    __tablename__ = "school_surveys"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    academic_year_id = Column(GUID(), ForeignKey(ACADEMIC_YEARS_ID), nullable=False)
    school_id = Column(GUID(), ForeignKey(SCHOOLS_ID), nullable=True)

    q1_school_name = Column(String(255), nullable=True)
    q2_role = Column(String(100), nullable=True)
    q3_fills_gap = Column(String(5), nullable=True)
    q4_improvements = Column(Text, nullable=True)
    q5_additional_comments = Column(Text, nullable=True)

    entered_by = Column(GUID(), ForeignKey(USERS_ID), nullable=True)
    entered_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    def __repr__(self) -> str:
        return f"<SchoolSurvey(id={self.id}, school={self.q1_school_name})>"
