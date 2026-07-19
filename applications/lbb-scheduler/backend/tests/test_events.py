"""
Event Scheduling Endpoint Tests
==================================
Tests for: POST  /api/v1/events/years
           GET   /api/v1/events/years
           POST  /api/v1/events
           GET   /api/v1/events
           GET   /api/v1/events/{id}
           PATCH /api/v1/events/{id}
           DELETE /api/v1/events/{id}
           POST  /api/v1/events/{id}/register
           POST  /api/v1/events/{id}/signup

Test IDs: EVT-001 through EVT-010
"""

from app.models.school import School
import uuid


# academic_year and test_school fixtures: see tests/conftest.py


# =============================================================
# EVT-001: Create Academic Year
# =============================================================
def test_create_academic_year(client, admin_user):
    """Valid year is created with start/end dates."""
    user, token = admin_user

    response = client.post(
        "/api/v1/events/years",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "2025-2026",
            "start_date": "2025-07-01",
            "end_date": "2026-06-30",
            "is_active": True,
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "2025-2026"


# =============================================================
# EVT-002: Academic Year Invalid Dates
# =============================================================
def test_create_year_invalid_dates(client, admin_user):
    """End date before start date returns 400."""
    user, token = admin_user

    response = client.post(
        "/api/v1/events/years",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Bad Year",
            "start_date": "2026-06-30",
            "end_date": "2025-07-01",
            "is_active": True,
        }
    )

    assert response.status_code == 400


# =============================================================
# EVT-003: Create Event
# =============================================================
def test_create_event(client, admin_user, academic_year):
    """Event created with available status."""
    user, token = admin_user

    response = client.post(
        "/api/v1/events",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "event_date": "2025-10-15",
            "event_time": "09:00",
            "notes": "Fall event",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "available"
    assert data["event_date"] == "2025-10-15"


# =============================================================
# EVT-004: Event Date Outside Academic Year Range
# =============================================================
def test_create_event_outside_range(client, admin_user, academic_year):
    """Date outside year range returns 400."""
    user, token = admin_user

    response = client.post(
        "/api/v1/events",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "event_date": "2024-01-01",
            "notes": "Date before year starts",
        }
    )

    assert response.status_code == 400


# =============================================================
# EVT-005: Valid Status Transition
# =============================================================
def test_event_status_transition(client, admin_user, academic_year, test_school):
    """Valid transition: available → reserved via school registration."""
    user, token = admin_user

    # Create event
    create_resp = client.post(
        "/api/v1/events",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "event_date": "2025-11-15",
        }
    )
    event_id = create_resp.json()["id"]

    # Register school → should change status to reserved
    reg_resp = client.post(
        f"/api/v1/events/{event_id}/register",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "school_id": str(test_school.id),
            "anticipated_students": 30,
        }
    )
    assert reg_resp.status_code == 201

    # Verify status changed
    get_resp = client.get(
        f"/api/v1/events/{event_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert get_resp.json()["status"] == "reserved"


# =============================================================
# EVT-006: Invalid Status Transition
# =============================================================
def test_event_invalid_transition(client, admin_user, academic_year):
    """Invalid transition: available → completed returns 400."""
    user, token = admin_user

    # Create event (status: available)
    create_resp = client.post(
        "/api/v1/events",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "event_date": "2025-12-01",
        }
    )
    event_id = create_resp.json()["id"]

    # Try invalid transition: available → completed
    update_resp = client.patch(
        f"/api/v1/events/{event_id}",
        headers={"Authorization": f"Bearer {token}"},
        json={"status": "completed"}
    )

    assert update_resp.status_code == 400


# =============================================================
# EVT-007: Register School for Event
# =============================================================
def test_register_school_for_event(client, admin_user, academic_year, test_school):
    """School registers, status becomes reserved."""
    user, token = admin_user

    # Create event
    create_resp = client.post(
        "/api/v1/events",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "event_date": "2026-01-20",
        }
    )
    event_id = create_resp.json()["id"]

    # Register school
    response = client.post(
        f"/api/v1/events/{event_id}/register",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "school_id": str(test_school.id),
            "anticipated_students": 25,
            "requested_time": "10:00:00",
            "special_requests": "Need wheelchair access",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["school_id"] == str(test_school.id)


# =============================================================
# EVT-008: Second School Registration Blocked
# =============================================================
def test_register_second_school_blocked(client, admin_user, academic_year, test_school, db_session):
    """One school per event — ConOps 6.7.1."""
    user, token = admin_user

    # Create second school
    school2 = School(
        id=str(uuid.uuid4()),
        school_name="Second School",
        school_district="Tucson Unified",
        school_address="456 Other St",
        poc_name="John Smith",
        poc_phone="520-555-5678",
        poc_email="john@test.com",
        admin_user_id=str(user.id),
    )
    db_session.add(school2)
    db_session.commit()

    # Create event
    create_resp = client.post(
        "/api/v1/events",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "event_date": "2026-02-15",
        }
    )
    event_id = create_resp.json()["id"]

    # Register first school — should work
    client.post(
        f"/api/v1/events/{event_id}/register",
        headers={"Authorization": f"Bearer {token}"},
        json={"school_id": str(test_school.id), "anticipated_students": 20},
    )

    # Register second school — should be blocked (one school per event date)
    response = client.post(
        f"/api/v1/events/{event_id}/register",
        headers={"Authorization": f"Bearer {token}"},
        json={"school_id": str(school2.id), "anticipated_students": 15},
    )
    assert response.status_code == 400


# =============================================================
# EVT-009: Volunteer — list my signups (empty)
# =============================================================
def test_volunteer_my_signups_empty(client, volunteer_user):
    """Volunteer with no signups gets an empty list."""
    user, token = volunteer_user
    response = client.get(
        "/api/v1/events/my-volunteer-signups",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert response.json() == []


# =============================================================
# EVT-010: Volunteer — signup and list includes event
# =============================================================
def test_volunteer_signup_and_list_my_signups(
    client, admin_user, volunteer_user, academic_year
):
    """Volunteer can POST signup; my-volunteer-signups returns the row."""
    admin, admin_token = admin_user
    vol, vol_token = volunteer_user

    create_resp = client.post(
        "/api/v1/events",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "academic_year_id": str(academic_year.id),
            "event_date": "2026-03-10",
            "event_time": "09:00:00",
            "notes": "Spring session",
        },
    )
    assert create_resp.status_code == 201
    event_id = create_resp.json()["id"]

    signup_resp = client.post(
        f"/api/v1/events/{event_id}/signup",
        headers={"Authorization": f"Bearer {vol_token}"},
        json={},
    )
    assert signup_resp.status_code == 201
    assert signup_resp.json()["volunteer_id"] == str(vol.id)

    list_resp = client.get(
        "/api/v1/events/my-volunteer-signups",
        headers={"Authorization": f"Bearer {vol_token}"},
    )
    assert list_resp.status_code == 200
    rows = list_resp.json()
    assert len(rows) == 1
    assert rows[0]["event_id"] == event_id
    assert rows[0]["event_date"] == "2026-03-10"
