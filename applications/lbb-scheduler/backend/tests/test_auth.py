"""
Authentication Endpoint Tests
================================
Test IDs: AUTH-001 through AUTH-011
"""


def test_register_success(client):
    """AUTH-001: New user registration creates account."""
    response = client.post("/api/v1/auth/register", json={
        "username": "newuser",
        "email": "newuser@test.com",
        "password": "SecurePass123!",
        "role": "volunteer",
        "first_name": "New",
        "last_name": "User",
        "phone_number": "520-555-9999",
        "affiliation": "Test Org",
        "security_question_1": "What is your pet name?",
        "security_answer_1": "fluffy",
        "security_question_2": "What city were you born?",
        "security_answer_2": "tucson",
    })
    assert response.status_code == 201


def test_register_duplicate_username(client):
    """AUTH-002: Duplicate username returns 409."""
    user_data = {
        "username": "duplicateuser",
        "email": "first@test.com",
        "password": "SecurePass123!",
        "role": "volunteer",
        "first_name": "First",
        "last_name": "User",
        "phone_number": "520-555-0001",
        "affiliation": "Test Org",
        "security_question_1": "What is your pet name?",
        "security_answer_1": "fluffy",
        "security_question_2": "What city were you born?",
        "security_answer_2": "tucson",
    }
    client.post("/api/v1/auth/register", json=user_data)
    user_data["email"] = "second@test.com"
    response = client.post("/api/v1/auth/register", json=user_data)
    assert response.status_code == 409


def test_register_duplicate_email(client):
    """AUTH-003: Duplicate email returns 409."""
    user_data = {
        "username": "user_one",
        "email": "same@test.com",
        "password": "SecurePass123!",
        "role": "volunteer",
        "first_name": "User",
        "last_name": "One",
        "phone_number": "520-555-0001",
        "affiliation": "Test Org",
        "security_question_1": "What is your pet name?",
        "security_answer_1": "fluffy",
        "security_question_2": "What city were you born?",
        "security_answer_2": "tucson",
    }
    client.post("/api/v1/auth/register", json=user_data)
    user_data["username"] = "user_two"
    response = client.post("/api/v1/auth/register", json=user_data)
    assert response.status_code == 409


def test_login_success(client, admin_user):
    """AUTH-004: Valid credentials return tokens."""
    response = client.post("/api/v1/auth/login", data={
        "username": "testadmin",
        "password": "AdminPass123!",
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data


def test_login_invalid_password(client, admin_user):
    """AUTH-005: Wrong password returns 401."""
    response = client.post("/api/v1/auth/login", data={
        "username": "testadmin",
        "password": "WrongPassword!",
    })
    assert response.status_code == 401


def test_login_inactive_account(client, inactive_user):
    """AUTH-006: Pending account returns 401."""
    response = client.post("/api/v1/auth/login", data={
        "username": "pendinguser",
        "password": "PendingPass123!",
    })
    assert response.status_code == 401


def test_token_refresh(client, admin_user):
    """AUTH-007: Valid refresh token returns new access token."""
    login_response = client.post("/api/v1/auth/login", data={
        "username": "testadmin",
        "password": "AdminPass123!",
    })
    refresh_token = login_response.json()["refresh_token"]

    response = client.post("/api/v1/auth/refresh", json={
        "refresh_token": refresh_token,
    })
    assert response.status_code == 200
    assert "access_token" in response.json()


def test_expired_token_rejected(client):
    """AUTH-008: Invalid token returns 401."""
    response = client.get(
        "/api/v1/users",
        headers={"Authorization": "Bearer invalid.fake.token"}
    )
    assert response.status_code == 401


def test_password_reset_verify(client, admin_user):
    """AUTH-009: Correct security answers return reset token."""
    response = client.post("/api/v1/auth/verify", json={
        "username": "testadmin",
        "security_answer_1": "fluffy",
        "security_answer_2": "tucson",
    })
    assert response.status_code == 200
    assert "reset_token" in response.json()


def test_password_reset_wrong_answers(client, admin_user):
    """AUTH-010: Wrong answers return 400."""
    response = client.post("/api/v1/auth/verify", json={
        "username": "testadmin",
        "security_answer_1": "wrong_answer",
        "security_answer_2": "wrong_answer",
    })
    assert response.status_code == 400


def test_password_reset_complete(client, admin_user):
    """AUTH-011: Full reset flow works."""
    verify_response = client.post("/api/v1/auth/verify", json={
        "username": "testadmin",
        "security_answer_1": "fluffy",
        "security_answer_2": "tucson",
    })
    reset_token = verify_response.json()["reset_token"]

    reset_response = client.post("/api/v1/auth/reset", json={
        "reset_token": reset_token,
        "new_password": "BrandNewPass456!",
    })
    assert reset_response.status_code == 200

    login_response = client.post("/api/v1/auth/login", data={
        "username": "testadmin",
        "password": "BrandNewPass456!",
    })
    assert login_response.status_code == 200
