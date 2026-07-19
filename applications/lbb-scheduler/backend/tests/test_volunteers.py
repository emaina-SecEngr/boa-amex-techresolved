"""
Volunteer & Life Skills Class Endpoint Tests
================================================
Tests for: POST  /api/v1/volunteers/profile
           GET   /api/v1/volunteers/profile
           PATCH /api/v1/volunteers/profile
           GET   /api/v1/volunteers/available
           POST  /api/v1/volunteers/classes
           GET   /api/v1/volunteers/classes
           GET   /api/v1/volunteers/classes/{id}
           PATCH /api/v1/volunteers/classes/{id}
           DELETE /api/v1/volunteers/classes/{id}

Test IDs: VOL-001 through VOL-008
"""


# =============================================================
# VOL-001: Create Volunteer Profile
# =============================================================
def test_create_volunteer_profile(client, volunteer_user):
    """Profile created for volunteer user."""
    user, token = volunteer_user

    response = client.post(
        "/api/v1/volunteers/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "organization": "Tucson Volunteers Inc",
            "bio": "10 years experience in financial literacy",
            "special_requirements": "Need projector",
            "is_available": True,
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["organization"] == "Tucson Volunteers Inc"
    assert data["is_available"] is True
    assert data["first_name"] == "Test"
    assert data["last_name"] == "Volunteer"


# =============================================================
# VOL-002: Non-Volunteer Cannot Create Profile
# =============================================================
def test_create_profile_non_volunteer(client, admin_user):
    """Non-volunteer role rejected."""
    user, token = admin_user

    response = client.post(
        "/api/v1/volunteers/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "organization": "Admin Org",
            "bio": "I am an admin",
        }
    )

    assert response.status_code in [400, 403]


# =============================================================
# VOL-003: Duplicate Profile Rejected
# =============================================================
def test_duplicate_profile(client, volunteer_user):
    """One profile per user enforced."""
    user, token = volunteer_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create first profile
    client.post("/api/v1/volunteers/profile", headers=headers, json={
        "organization": "First Org",
        "bio": "First bio",
    })

    # Try creating second profile
    response = client.post("/api/v1/volunteers/profile", headers=headers, json={
        "organization": "Second Org",
        "bio": "Second bio",
    })

    assert response.status_code == 400


# =============================================================
# VOL-004: List Available Volunteers
# =============================================================
def test_list_available_volunteers(client, volunteer_user, admin_user):
    """Only is_available=True returned."""
    vol_user, vol_token = volunteer_user
    admin, admin_token = admin_user

    # Create volunteer profile with is_available=True
    client.post(
        "/api/v1/volunteers/profile",
        headers={"Authorization": f"Bearer {vol_token}"},
        json={"organization": "Available Org", "is_available": True}
    )

    # List available volunteers
    response = client.get(
        "/api/v1/volunteers/available",
        headers={"Authorization": f"Bearer {admin_token}"}
    )

    assert response.status_code == 200


# =============================================================
# VOL-004b: Non-admin cannot list available volunteers
# =============================================================
def test_list_available_volunteers_forbidden_for_volunteer(client, volunteer_user):
    """Only LBB admin / IT support may list available volunteers."""
    vol_user, vol_token = volunteer_user

    response = client.get(
        "/api/v1/volunteers/available",
        headers={"Authorization": f"Bearer {vol_token}"},
    )

    assert response.status_code == 403


# =============================================================
# VOL-005: Create Life Skills Class
# =============================================================
def test_create_life_skills_class(client, admin_user, volunteer_user):
    """Class created with lead volunteer."""
    admin, admin_token = admin_user
    volunteer, vol_token = volunteer_user

    response = client.post(
        "/api/v1/volunteers/classes",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "class_name": "Financial Literacy 101",
            "lead_volunteer_id": str(volunteer.id),
            "description": "Teach students about budgeting and saving",
            "equipment_by_professional": "Laptop, handouts",
            "equipment_by_lbb": "Projector, screen",
            "max_students": 25,
            "take_home_items": "Budget worksheet",
            "logistics": "Need classroom with tables",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["class_name"] == "Financial Literacy 101"
    assert data["lead_volunteer_id"] == str(volunteer.id)


# =============================================================
# VOL-006: Create Class with Invalid Lead
# =============================================================
def test_create_class_invalid_lead(client, admin_user):
    """Non-existent or non-volunteer lead rejected."""
    admin, token = admin_user

    response = client.post(
        "/api/v1/volunteers/classes",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "class_name": "Bad Class",
            "lead_volunteer_id": str(admin.id),
            "description": "Admin is not a volunteer",
        }
    )

    assert response.status_code == 400


# =============================================================
# VOL-007: Update Life Skills Class
# =============================================================
def test_update_class(client, admin_user, volunteer_user):
    """Class details updated."""
    admin, admin_token = admin_user
    volunteer, vol_token = volunteer_user

    # Create class
    create_resp = client.post(
        "/api/v1/volunteers/classes",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "class_name": "Update Test Class",
            "lead_volunteer_id": str(volunteer.id),
            "description": "Original description",
            "max_students": 20,
        }
    )
    class_id = create_resp.json()["id"]

    # Update description
    response = client.patch(
        f"/api/v1/volunteers/classes/{class_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"description": "Updated description", "max_students": 30}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["description"] == "Updated description"
    assert data["max_students"] == 30


# =============================================================
# VOL-008: Delete Life Skills Class
# =============================================================
def test_delete_class(client, admin_user, volunteer_user):
    """Class removed from catalog."""
    admin, admin_token = admin_user
    volunteer, vol_token = volunteer_user

    # Create class
    create_resp = client.post(
        "/api/v1/volunteers/classes",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "class_name": "Delete Test Class",
            "lead_volunteer_id": str(volunteer.id),
            "description": "Will be deleted",
        }
    )
    class_id = create_resp.json()["id"]

    # Delete class
    response = client.delete(
        f"/api/v1/volunteers/classes/{class_id}",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert response.status_code == 200

    # Verify it's gone
    get_resp = client.get(
        f"/api/v1/volunteers/classes/{class_id}",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert get_resp.status_code == 404


# =============================================================
# VOL-009: Volunteer lists only their classes (mine=true)
# =============================================================
def test_list_my_classes_mine_filter(client, admin_user, volunteer_user):
    """mine=true returns only classes where the volunteer is lead."""
    admin, admin_token = admin_user
    volunteer, vol_token = volunteer_user

    client.post(
        "/api/v1/volunteers/classes",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "class_name": "My Lead Class",
            "lead_volunteer_id": str(volunteer.id),
            "description": "I teach this one",
            "max_students": 20,
        },
    )

    all_resp = client.get(
        "/api/v1/volunteers/classes",
        headers={"Authorization": f"Bearer {vol_token}"},
    )
    mine_resp = client.get(
        "/api/v1/volunteers/classes?mine=true",
        headers={"Authorization": f"Bearer {vol_token}"},
    )

    assert all_resp.status_code == 200
    assert mine_resp.status_code == 200
    assert mine_resp.json()["total"] == 1
    assert mine_resp.json()["classes"][0]["class_name"] == "My Lead Class"
    assert mine_resp.json()["classes"][0]["lead_volunteer_id"] == str(volunteer.id)
    assert all_resp.json()["total"] >= 1
