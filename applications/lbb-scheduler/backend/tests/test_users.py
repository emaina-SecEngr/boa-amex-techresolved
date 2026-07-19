"""
User Management Endpoint Tests
=================================
Test IDs: USER-001 through USER-006, SEC-006, SEC-009
"""


def test_list_users_admin(client, admin_user):
    """USER-001: Admin can list all users."""
    user, token = admin_user
    response = client.get(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "users" in data
    assert data["total"] >= 1


def test_list_users_unauthorized(client, volunteer_user):
    """USER-002: Volunteer gets 403."""
    user, token = volunteer_user
    response = client.get(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 403


def test_get_user_by_id(client, admin_user):
    """USER-003: Valid ID returns user without password."""
    user, token = admin_user
    response = client.get(
        f"/api/v1/users/{user.id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "testadmin"
    assert "password_hash" not in data
    assert "security_answer_1" not in data
    assert "security_answer_2" not in data


def test_update_user_activate(client, admin_user, inactive_user):
    """USER-004: Admin approves pending user."""
    admin, token = admin_user
    response = client.patch(
        f"/api/v1/users/{inactive_user.id}",
        headers={"Authorization": f"Bearer {token}"},
        json={"is_active": True}
    )
    assert response.status_code == 200
    assert response.json()["is_active"] is True


def test_deactivate_user(client, admin_user, volunteer_user):
    """USER-005: Admin soft-deletes user."""
    admin, admin_token = admin_user
    volunteer, vol_token = volunteer_user
    response = client.delete(
        f"/api/v1/users/{volunteer.id}",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert response.status_code == 200


def test_get_user_not_found(client, admin_user):
    """USER-006: Invalid ID returns 404."""
    user, token = admin_user
    response = client.get(
        "/api/v1/users/00000000-0000-0000-0000-000000000000",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 404


def test_school_admin_cannot_list_users(client, school_admin_user):
    """SEC-006: Non-admin gets 403."""
    user, token = school_admin_user
    response = client.get(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 403


def test_no_token_rejected(client):
    """SEC-009: No auth header returns 401."""
    response = client.get("/api/v1/users")
    assert response.status_code == 401
