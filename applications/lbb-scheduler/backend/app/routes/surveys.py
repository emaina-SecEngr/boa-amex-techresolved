"""
Survey Routes — API Endpoints
=================================
  POST   /api/v1/surveys/volunteer           → Submit volunteer survey
  GET    /api/v1/surveys/volunteer           → List volunteer surveys
  GET    /api/v1/surveys/volunteer/{id}      → Get volunteer survey

  POST   /api/v1/surveys/student             → Enter student survey
  GET    /api/v1/surveys/student             → List student surveys
  GET    /api/v1/surveys/student/{id}        → Get student survey

  POST   /api/v1/surveys/school              → Enter school survey
  GET    /api/v1/surveys/school              → List school surveys
  GET    /api/v1/surveys/school/{id}         → Get school survey
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import require_roles
from app.models.user import User
from app.schemas.survey import (
    VolunteerSurveyCreate,
    VolunteerSurveyResponse,
    VolunteerSurveyListResponse,
    StudentSurveyCreate,
    StudentSurveyResponse,
    StudentSurveyListResponse,
    SchoolSurveyCreate,
    SchoolSurveyResponse,
    SchoolSurveyListResponse,
)
from app.services.survey_service import (
    create_volunteer_survey,
    list_volunteer_surveys,
    get_volunteer_survey,
    create_student_survey,
    list_student_surveys,
    get_student_survey,
    create_school_survey,
    list_school_surveys,
    get_school_survey,
)


router = APIRouter(prefix="/surveys", tags=["Surveys"])
# Centralized string constants (SonarQube python:S1192)
FILTER_BY_ACADEMIC_YEAR = "Filter by academic year"


# ===============================================================
# Volunteer Surveys
# ===============================================================

@router.post(
    "/volunteer",
    response_model=VolunteerSurveyResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit volunteer survey",
    description="Volunteer submits their post-event feedback.",
)
def submit_volunteer_survey(
    data: VolunteerSurveyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["volunteer", "lbb_admin"])),
):
    try:
        survey = create_volunteer_survey(db, str(current_user.id), data)
        return survey
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "/volunteer",
    response_model=VolunteerSurveyListResponse,
    summary="List volunteer surveys",
    description="List all volunteer surveys. (Admin only)",
)
def get_volunteer_surveys(
    academic_year_id: str = Query(default=None, description=FILTER_BY_ACADEMIC_YEAR),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    return list_volunteer_surveys(db, academic_year_id=academic_year_id)


@router.get(
    "/volunteer/{survey_id}",
    response_model=VolunteerSurveyResponse,
    summary="Get volunteer survey",
    description="Returns a single volunteer survey by ID.",
)
def get_single_volunteer_survey(
    survey_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "volunteer"])),
):
    try:
        survey = get_volunteer_survey(db, survey_id)
        return survey
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


# ===============================================================
# Student Surveys
# ===============================================================

@router.post(
    "/student",
    response_model=StudentSurveyResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Enter student survey",
    description="Admin enters student survey data from paper forms.",
)
def enter_student_survey(
    data: StudentSurveyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        survey = create_student_survey(db, str(current_user.id), data)
        return survey
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "/student",
    response_model=StudentSurveyListResponse,
    summary="List student surveys",
    description="List student surveys with optional filters.",
)
def get_student_surveys(
    academic_year_id: str = Query(default=None, description=FILTER_BY_ACADEMIC_YEAR),
    school_id: str = Query(default=None, description="Filter by school"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    return list_student_surveys(
        db, academic_year_id=academic_year_id, school_id=school_id
    )


@router.get(
    "/student/{survey_id}",
    response_model=StudentSurveyResponse,
    summary="Get student survey",
    description="Returns a single student survey by ID.",
)
def get_single_student_survey(
    survey_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        survey = get_student_survey(db, survey_id)
        return survey
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


# ===============================================================
# School Surveys
# ===============================================================

@router.post(
    "/school",
    response_model=SchoolSurveyResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Enter school survey",
    description="Admin enters school administrator feedback.",
)
def enter_school_survey(
    data: SchoolSurveyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        survey = create_school_survey(db, str(current_user.id), data)
        return survey
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "/school",
    response_model=SchoolSurveyListResponse,
    summary="List school surveys",
    description="List school surveys with optional year filter.",
)
def get_school_surveys(
    academic_year_id: str = Query(default=None, description=FILTER_BY_ACADEMIC_YEAR),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin"])),
):
    return list_school_surveys(db, academic_year_id=academic_year_id)


@router.get(
    "/school/{survey_id}",
    response_model=SchoolSurveyResponse,
    summary="Get school survey",
    description="Returns a single school survey by ID.",
)
def get_single_school_survey(
    survey_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(["lbb_admin", "school_admin"])),
):
    try:
        survey = get_school_survey(db, survey_id)
        return survey
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
