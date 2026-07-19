"""
School Management Endpoint Tests
====================================
Tests for: POST   /api/v1/schools
           GET    /api/v1/schools
           GET    /api/v1/schools/{id}
           PATCH  /api/v1/schools/{id}
           DELETE /api/v1/schools/{id}
           POST   /api/v1/schools/{id}/principals
           DELETE /api/v1/schools/{id}/principals/{pid}
           POST   /api/v1/schools/{id}/photo-restrictions
           DELETE /api/v1/schools/{id}/photo-restrictions/{rid}

Test IDs: SCH-001 through SCH-009
"""

import uuid
from unittest.mock import patch

from app.models.event import EventRegistration
from app.models.school import PhotoRestriction, SchoolPrincipal


# =============================================================
# SCH-001: Create School
# =============================================================
def test_create_school(client, admin_user):
    """School created with all required fields."""
    user, token = admin_user

    response = client.post(
        "/api/v1/schools",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "school_name": "Tucson Magnet High",
            "school_district": "Tucson Unified",
            "school_address": "400 N 2nd Ave, Tucson AZ",
            "poc_name": "Maria Garcia",
            "poc_phone": "520-555-1111",
            "poc_email": "maria@tucsonusd.org",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["school_name"] == "Tucson Magnet High"
    assert data["school_district"] == "Tucson Unified"


@patch("app.services.school_service.notify_school_record_created_email")
def test_school_record_confirmation_email_triggers_on_success(mock_notify, client, admin_user):
    """Req 6.5.12 / MVP1: confirmation runs after successful school record creation."""
    user, token = admin_user
    mock_notify.return_value = True

    response = client.post(
        "/api/v1/schools",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "school_name": "Confirmation Email Test School",
            "school_district": "Tucson Unified",
            "school_address": "1 Test Ave, Tucson AZ",
            "poc_name": "Pat Admin",
            "poc_phone": "520-555-9999",
            "poc_email": "pat.confirm@test.com",
        },
    )

    assert response.status_code == 201
    mock_notify.assert_called_once()
    kwargs = mock_notify.call_args.kwargs
    assert kwargs["poc_email"] == "pat.confirm@test.com"
    assert kwargs["school_name"] == "Confirmation Email Test School"
    assert kwargs["poc_name"] == "Pat Admin"


@patch("app.services.school_service.notify_school_record_created_email")
def test_school_record_confirmation_email_not_on_failure(mock_notify, client, admin_user):
    """No confirmation when registration fails (duplicate name)."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}
    school_data = {
        "school_name": "Duplicate For Email Test",
        "school_district": "Tucson Unified",
        "school_address": "200 Dup St",
        "poc_name": "Dup User",
        "poc_phone": "520-555-8888",
        "poc_email": "dup@test.com",
    }

    first = client.post("/api/v1/schools", headers=headers, json=school_data)
    assert first.status_code == 201
    mock_notify.assert_called_once()
    mock_notify.reset_mock()

    dup = client.post("/api/v1/schools", headers=headers, json=school_data)
    assert dup.status_code == 400
    mock_notify.assert_not_called()


# =============================================================
# SCH-002: Duplicate School Name Rejected
# =============================================================
def test_create_school_duplicate_name(client, admin_user):
    """Duplicate school name returns 400."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    school_data = {
        "school_name": "Duplicate School",
        "school_district": "Tucson Unified",
        "school_address": "100 Main St",
        "poc_name": "John Doe",
        "poc_phone": "520-555-2222",
        "poc_email": "john@test.com",
    }

    # Create first — should work
    client.post("/api/v1/schools", headers=headers, json=school_data)

    # Create duplicate — should fail
    response = client.post("/api/v1/schools", headers=headers, json=school_data)

    assert response.status_code == 400


# =============================================================
# SCH-003: List Schools with District Filter
# =============================================================
def test_list_schools_filter_district(client, admin_user):
    """District filter returns correct subset."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create schools in two districts
    client.post("/api/v1/schools", headers=headers, json={
        "school_name": "School A",
        "school_district": "Tucson Unified",
        "school_address": "111 A St",
        "poc_name": "A", "poc_phone": "520-555-0001", "poc_email": "a@test.com",
    })
    client.post("/api/v1/schools", headers=headers, json={
        "school_name": "School B",
        "school_district": "Sunnyside",
        "school_address": "222 B St",
        "poc_name": "B", "poc_phone": "520-555-0002", "poc_email": "b@test.com",
    })

    # Filter by Tucson Unified
    response = client.get(
        "/api/v1/schools?district=Tucson Unified",
        headers=headers
    )

    assert response.status_code == 200
    data = response.json()
    for school in data["schools"]:
        assert school["school_district"] == "Tucson Unified"


# =============================================================
# SCH-004: Partial Update School
# =============================================================
def test_update_school_partial(client, admin_user):
    """PATCH updates only sent fields."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create school
    create_resp = client.post("/api/v1/schools", headers=headers, json={
        "school_name": "Update Test School",
        "school_district": "Tucson Unified",
        "school_address": "333 Old St",
        "poc_name": "Old Name",
        "poc_phone": "520-555-0000",
        "poc_email": "old@test.com",
    })
    school_id = create_resp.json()["id"]

    # Update ONLY the phone
    response = client.patch(
        f"/api/v1/schools/{school_id}",
        headers=headers,
        json={"poc_phone": "520-555-9999"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["poc_phone"] == "520-555-9999"
    # Other fields unchanged
    assert data["poc_name"] == "Old Name"
    assert data["school_address"] == "333 Old St"


# =============================================================
# SCH-005: Delete School with CASCADE
# =============================================================
def test_delete_school_cascade(client, admin_user):
    """Delete removes school and associated principals."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create school
    create_resp = client.post("/api/v1/schools", headers=headers, json={
        "school_name": "Delete Test School",
        "school_district": "Tucson Unified",
        "school_address": "444 Gone St",
        "poc_name": "Bye", "poc_phone": "520-555-0000", "poc_email": "bye@test.com",
    })
    school_id = create_resp.json()["id"]

    # Add a principal
    client.post(
        f"/api/v1/schools/{school_id}/principals",
        headers=headers,
        json={"name": "Principal Smith", "title": "Head Principal"}
    )

    # Delete school
    response = client.delete(
        f"/api/v1/schools/{school_id}",
        headers=headers
    )
    assert response.status_code == 200

    # Verify school is gone
    get_resp = client.get(
        f"/api/v1/schools/{school_id}",
        headers=headers
    )
    assert get_resp.status_code == 404


def test_delete_school_returns_confirmation_with_school_name(client, admin_user):
    """DELETE response message includes the school name."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}
    name = "Named Delete School XYZ"
    create_resp = client.post(
        "/api/v1/schools",
        headers=headers,
        json={
            "school_name": name,
            "school_district": "Tucson Unified",
            "school_address": "1 Main St",
            "poc_name": "N",
            "poc_phone": "520-555-0000",
            "poc_email": "n@test.com",
        },
    )
    school_id = create_resp.json()["id"]
    response = client.delete(f"/api/v1/schools/{school_id}", headers=headers)
    assert response.status_code == 200
    assert name in response.json()["message"]


def test_delete_school_not_found_returns_404(client, admin_user):
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}
    fake_id = str(uuid.uuid4())
    response = client.delete(f"/api/v1/schools/{fake_id}", headers=headers)
    assert response.status_code == 404


def test_delete_school_forbidden_for_school_admin(client, admin_user, school_admin_user):
    _, admin_token = admin_user
    _, school_token = school_admin_user
    h_admin = {"Authorization": f"Bearer {admin_token}"}
    create_resp = client.post(
        "/api/v1/schools",
        headers=h_admin,
        json={
            "school_name": "School Admin Cannot Delete",
            "school_district": "Tucson Unified",
            "school_address": "2 Main St",
            "poc_name": "P",
            "poc_phone": "520-555-0000",
            "poc_email": "p@test.com",
        },
    )
    school_id = create_resp.json()["id"]
    response = client.delete(
        f"/api/v1/schools/{school_id}",
        headers={"Authorization": f"Bearer {school_token}"},
    )
    assert response.status_code == 403


def test_delete_school_cascade_removes_principals_photo_and_event_registrations(
    client, admin_user, academic_year, test_school, db_session
):
    """CASCADE removes principals, photo restrictions, and event registrations."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}
    school_id = str(test_school.id)

    client.post(
        f"/api/v1/schools/{school_id}/principals",
        headers=headers,
        json={"name": "Cascade Principal"},
    )
    client.post(
        f"/api/v1/schools/{school_id}/photo-restrictions",
        headers=headers,
        json={"student_name": "Cascade Student"},
    )
    assert db_session.query(SchoolPrincipal).filter_by(school_id=school_id).count() >= 1
    assert db_session.query(PhotoRestriction).filter_by(school_id=school_id).count() >= 1

    ev = client.post(
        "/api/v1/events",
        headers=headers,
        json={
            "academic_year_id": str(academic_year.id),
            "event_date": "2026-04-01",
        },
    )
    assert ev.status_code == 201
    event_id = ev.json()["id"]
    reg = client.post(
        f"/api/v1/events/{event_id}/register",
        headers=headers,
        json={"school_id": school_id, "anticipated_students": 12},
    )
    assert reg.status_code == 201
    assert db_session.query(EventRegistration).filter_by(school_id=school_id).count() == 1

    del_resp = client.delete(f"/api/v1/schools/{school_id}", headers=headers)
    assert del_resp.status_code == 200
    assert "Test Elementary" in del_resp.json()["message"]

    assert db_session.query(SchoolPrincipal).filter_by(school_id=school_id).count() == 0
    assert db_session.query(PhotoRestriction).filter_by(school_id=school_id).count() == 0
    assert db_session.query(EventRegistration).filter_by(school_id=school_id).count() == 0


# =============================================================
# SCH-006: Add Principal to School
# =============================================================
def test_add_principal(client, admin_user):
    """Principal added to school."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create school
    create_resp = client.post("/api/v1/schools", headers=headers, json={
        "school_name": "Principal Test School",
        "school_district": "Tucson Unified",
        "school_address": "555 Lead St",
        "poc_name": "Test", "poc_phone": "520-555-0000", "poc_email": "test@test.com",
    })
    school_id = create_resp.json()["id"]

    # Add principal
    response = client.post(
        f"/api/v1/schools/{school_id}/principals",
        headers=headers,
        json={"name": "Dr. Johnson", "title": "Principal"}
    )

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Dr. Johnson"


# =============================================================
# SCH-007: Remove Principal
# =============================================================
def test_remove_principal(client, admin_user):
    """Principal removed from school."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create school
    create_resp = client.post("/api/v1/schools", headers=headers, json={
        "school_name": "Remove Principal School",
        "school_district": "Tucson Unified",
        "school_address": "666 Remove St",
        "poc_name": "Test", "poc_phone": "520-555-0000", "poc_email": "rm@test.com",
    })
    school_id = create_resp.json()["id"]

    # Add principal
    add_resp = client.post(
        f"/api/v1/schools/{school_id}/principals",
        headers=headers,
        json={"name": "Leaving Principal"}
    )
    principal_id = add_resp.json()["id"]

    # Remove principal
    response = client.delete(
        f"/api/v1/schools/{school_id}/principals/{principal_id}",
        headers=headers
    )

    assert response.status_code == 200


# =============================================================
# SCH-008: Add Photo Restriction
# =============================================================
def test_add_photo_restriction(client, admin_user):
    """Student added to no-photo list."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create school
    create_resp = client.post("/api/v1/schools", headers=headers, json={
        "school_name": "Photo Test School",
        "school_district": "Tucson Unified",
        "school_address": "777 Photo St",
        "poc_name": "Test", "poc_phone": "520-555-0000", "poc_email": "photo@test.com",
    })
    school_id = create_resp.json()["id"]

    # Add photo restriction
    response = client.post(
        f"/api/v1/schools/{school_id}/photo-restrictions",
        headers=headers,
        json={
            "student_name": "Jane Student",
            "class_assignment": "8th Grade - Room 101",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["student_name"] == "Jane Student"


# =============================================================
# SCH-009: Remove Photo Restriction
# =============================================================
def test_remove_photo_restriction(client, admin_user):
    """Student removed from no-photo list."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create school
    create_resp = client.post("/api/v1/schools", headers=headers, json={
        "school_name": "Remove Photo School",
        "school_district": "Tucson Unified",
        "school_address": "888 Remove St",
        "poc_name": "Test", "poc_phone": "520-555-0000", "poc_email": "rp@test.com",
    })
    school_id = create_resp.json()["id"]

    # Add photo restriction
    add_resp = client.post(
        f"/api/v1/schools/{school_id}/photo-restrictions",
        headers=headers,
        json={"student_name": "Remove Student"}
    )
    restriction_id = add_resp.json()["id"]

    # Remove restriction
    response = client.delete(
        f"/api/v1/schools/{school_id}/photo-restrictions/{restriction_id}",
        headers=headers
    )

    assert response.status_code == 200
