"""
Survey Endpoint Tests
========================
Tests for: POST /api/v1/surveys/volunteer
           GET  /api/v1/surveys/volunteer
           GET  /api/v1/surveys/volunteer/{id}
           POST /api/v1/surveys/student
           GET  /api/v1/surveys/student
           GET  /api/v1/surveys/student/{id}
           POST /api/v1/surveys/school
           GET  /api/v1/surveys/school
           GET  /api/v1/surveys/school/{id}

Test IDs: SRV-001 through SRV-006
"""

import pytest
from datetime import date
from app.models.event import AcademicYear
import uuid


@pytest.fixture
def academic_year(db_session):
    """Create a test academic year for surveys."""
    year = AcademicYear(
        id=str(uuid.uuid4()),
        name="2025-2026",
        start_date=date(2025, 7, 1),
        end_date=date(2026, 6, 30),
        is_active=True,
    )
    db_session.add(year)
    db_session.commit()
    db_session.refresh(year)
    return year


# =============================================================
# SRV-001: Submit Volunteer Survey
# =============================================================
def test_submit_volunteer_survey(client, volunteer_user, academic_year):
    """Volunteer submits post-event feedback."""
    user, token = volunteer_user

    response = client.post(
        "/api/v1/surveys/volunteer",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "q1_participate_next_year": "yes",
            "q2_recruit_contacts": "I can bring 3 colleagues",
            "q3_time_feedback": "just_right",
            "q4_take_home_items": "yes",
            "q5_hands_on_satisfaction": "Students were very engaged",
            "q6_comments": "Great experience overall!",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["q1_participate_next_year"] == "yes"
    assert data["q3_time_feedback"] == "just_right"


# =============================================================
# SRV-002: Enter Student Survey
# =============================================================
def test_submit_student_survey(client, admin_user, academic_year):
    """Admin enters student paper survey."""
    user, token = admin_user

    response = client.post(
        "/api/v1/surveys/student",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "q1_learned_new_skill": "yes",
            "q2_speaker_engaging": "very",
            "q3_share_with_family": "yes",
            "q4_sessions_attended": "3",
            "q5_favorite_session": "Financial Literacy",
            "q6_improvement_suggestions": "More hands-on activities",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["q1_learned_new_skill"] == "yes"
    assert data["q2_speaker_engaging"] == "very"


# =============================================================
# SRV-003: Enter School Survey
# =============================================================
def test_submit_school_survey(client, admin_user, academic_year):
    """Admin enters school admin feedback."""
    user, token = admin_user

    response = client.post(
        "/api/v1/surveys/school",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "q1_school_name": "Tucson Magnet High",
            "q2_role": "Principal",
            "q3_fills_gap": "yes",
            "q4_improvements": "Would love more session options",
            "q5_additional_comments": "Students really enjoyed it",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["q1_school_name"] == "Tucson Magnet High"
    assert data["q3_fills_gap"] == "yes"


# =============================================================
# SRV-004: List Surveys with Academic Year Filter
# =============================================================
def test_list_surveys_filter_year(client, admin_user, volunteer_user, academic_year):
    """Academic year filter works across all survey types."""
    admin, admin_token = admin_user
    volunteer, vol_token = volunteer_user

    # Submit a volunteer survey
    client.post(
        "/api/v1/surveys/volunteer",
        headers={"Authorization": f"Bearer {vol_token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "q1_participate_next_year": "maybe",
            "q3_time_feedback": "too_short",
        }
    )

    # List volunteer surveys filtered by year
    response = client.get(
        f"/api/v1/surveys/volunteer?academic_year_id={str(academic_year.id)}",
        headers={"Authorization": f"Bearer {admin_token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1


# =============================================================
# SRV-005: Survey Tracks entered_by
# =============================================================
def test_survey_entered_by_tracking(client, admin_user, academic_year):
    """entered_by matches current user JWT."""
    user, token = admin_user

    # Enter student survey as admin
    create_resp = client.post(
        "/api/v1/surveys/student",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "q1_learned_new_skill": "yes",
            "q2_speaker_engaging": "somewhat",
        }
    )

    assert create_resp.status_code == 201
    data = create_resp.json()
    assert data["entered_by"] == str(user.id)


# =============================================================
# SRV-006: Volunteer Cannot Submit Student Survey
# =============================================================
def test_volunteer_survey_unauthorized(client, volunteer_user, academic_year):
    """Volunteer cannot submit student survey (admin only)."""
    user, token = volunteer_user

    response = client.post(
        "/api/v1/surveys/student",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "q1_learned_new_skill": "yes",
            "q2_speaker_engaging": "very",
        }
    )

    assert response.status_code == 403
