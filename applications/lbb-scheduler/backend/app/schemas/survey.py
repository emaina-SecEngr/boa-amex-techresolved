"""
Survey Schemas — Feedback Collection Validation
===================================================
Request/response schemas for three survey types:
  - Volunteer surveys (post-event feedback from volunteers)
  - Student surveys (collected by school admins from students)
  - School surveys (feedback from school administrators)

ConOps references:
  6.5.13: Volunteer survey questions
  6.5.14: Student survey questions
  6.5.15: School survey questions
"""

from uuid import UUID
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime

# Centralized string constants (SonarQube python:S1192)
ACADEMIC_YEAR_UUID_DESC = "UUID of the academic year"
YES_NO_PATTERN = "^(yes|no)$"
# ---------------------------------------------------------------
# Volunteer Survey (ConOps 6.5.13)
# ---------------------------------------------------------------


class VolunteerSurveyCreate(BaseModel):
    """
    Post-event survey filled out by volunteers.
    Questions map directly to ConOps 6.5.13.
    """
    academic_year_id: str = Field(..., description=ACADEMIC_YEAR_UUID_DESC)
    event_id: Optional[str] = Field(
        None, description="UUID of the specific event")
    q1_participate_next_year: Optional[str] = Field(
        None, pattern="^(yes|no|maybe)$",
        description="Would you participate again next year?"
    )
    q2_recruit_contacts: Optional[str] = Field(
        None, max_length=1000,
        description="Names/contacts of people you could recruit"
    )
    q3_time_feedback: Optional[str] = Field(
        None, pattern="^(too_short|just_right|too_long)$",
        description="How was the time allotted?"
    )
    q4_take_home_items: Optional[str] = Field(
        None, pattern=YES_NO_PATTERN,
        description="Were take-home items appropriate?"
    )
    q5_hands_on_satisfaction: Optional[str] = Field(
        None, max_length=1000,
        description="Satisfaction with hands-on activities"
    )
    q6_comments: Optional[str] = Field(
        None, max_length=2000,
        description="Additional comments"
    )

    @field_validator("event_id", "academic_year_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v


class VolunteerSurveyResponse(BaseModel):
    id: str
    volunteer_id: str
    academic_year_id: str
    event_id: Optional[str] = None
    q1_participate_next_year: Optional[str] = None
    q2_recruit_contacts: Optional[str] = None
    q3_time_feedback: Optional[str] = None
    q4_take_home_items: Optional[str] = None
    q5_hands_on_satisfaction: Optional[str] = None
    q6_comments: Optional[str] = None
    submitted_at: datetime

    @field_validator(
        "event_id",
        "id",
        "volunteer_id",
        "academic_year_id",
        mode="before"
    )
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# Student Survey (ConOps 6.5.14)
# ---------------------------------------------------------------
class StudentSurveyCreate(BaseModel):
    """
    Student feedback entered by school admin or LBB admin.
    Students fill out paper forms; admins enter the data.
    """
    academic_year_id: str = Field(..., description="ACADEMIC_YEAR_UUID_DESC")
    event_id: Optional[str] = None
    school_id: Optional[str] = None
    q1_learned_new_skill: Optional[str] = Field(
        None, pattern=YES_NO_PATTERN,
        description="Did you learn a new skill?"
    )
    q2_speaker_engaging: Optional[str] = Field(
        None, pattern="^(very|somewhat|not_really)$",
        description="Was the speaker engaging?"
    )
    q3_share_with_family: Optional[str] = Field(
        None, pattern="^(yes|no|maybe)$",
        description="Will you share what you learned with family?"
    )
    q4_sessions_attended: Optional[str] = Field(
        None, max_length=500,
        description="Which sessions did you attend?"
    )
    q5_favorite_session: Optional[str] = Field(
        None, max_length=100,
        description="What was your favorite session?"
    )
    q6_improvement_suggestions: Optional[str] = Field(
        None, max_length=2000,
        description="What could be improved?"
    )

    @field_validator("event_id", "academic_year_id", "school_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v


class StudentSurveyResponse(BaseModel):
    id: str
    academic_year_id: str
    event_id: Optional[str] = None
    school_id: Optional[str] = None
    q1_learned_new_skill: Optional[str] = None
    q2_speaker_engaging: Optional[str] = None
    q3_share_with_family: Optional[str] = None
    q4_sessions_attended: Optional[str] = None
    q5_favorite_session: Optional[str] = None
    q6_improvement_suggestions: Optional[str] = None
    entered_by: Optional[str] = None
    entered_at: datetime

    @field_validator(
        "id",
        "school_id",
        "event_id",
        "academic_year_id",
        "entered_by",
        mode="before"
    )
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# School Survey (ConOps 6.5.15)
# ---------------------------------------------------------------
class SchoolSurveyCreate(BaseModel):
    """
    Feedback from school administrators about the LBB program.
    """
    academic_year_id: str = Field(..., description="ACADEMIC_YEAR_UUID_DESC")
    school_id: Optional[str] = None
    q1_school_name: Optional[str] = Field(None, max_length=255)
    q2_role: Optional[str] = Field(
        None, max_length=100,
        description="Role at the school"
    )
    q3_fills_gap: Optional[str] = Field(
        None, pattern=YES_NO_PATTERN,
        description="Does LBB fill a gap in your curriculum?"
    )
    q4_improvements: Optional[str] = Field(
        None, max_length=2000,
        description="Suggestions for improvement"
    )
    q5_additional_comments: Optional[str] = Field(
        None, max_length=2000,
        description="Any additional comments"
    )

    @field_validator("school_id", "academic_year_id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v


class SchoolSurveyResponse(BaseModel):
    id: str
    academic_year_id: str
    school_id: Optional[str] = None
    q1_school_name: Optional[str] = None
    q2_role: Optional[str] = None
    q3_fills_gap: Optional[str] = None
    q4_improvements: Optional[str] = None
    q5_additional_comments: Optional[str] = None
    entered_by: Optional[str] = None
    entered_at: datetime

    @field_validator(
        "id", "school_id", "academic_year_id", "entered_by", mode="before"
    )
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True


# ---------------------------------------------------------------
# Survey List Responses
# ---------------------------------------------------------------
class VolunteerSurveyListResponse(BaseModel):
    surveys: list[VolunteerSurveyResponse]
    total: int


class StudentSurveyListResponse(BaseModel):
    surveys: list[StudentSurveyResponse]
    total: int


class SchoolSurveyListResponse(BaseModel):
    surveys: list[SchoolSurveyResponse]
    total: int
