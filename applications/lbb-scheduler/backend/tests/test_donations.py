"""
Donation Endpoint Tests
==========================
Tests for: POST  /api/v1/donations
           GET   /api/v1/donations
           GET   /api/v1/donations/summary
           GET   /api/v1/donations/{id}
           PATCH /api/v1/donations/{id}
           DELETE /api/v1/donations/{id}

Test IDs: DON-001 through DON-006
"""


# =============================================================
# DON-001: Record Cash Donation
# =============================================================
def test_create_cash_donation(client, admin_user):
    """Cash donation recorded with correct amount."""
    user, token = admin_user

    response = client.post(
        "/api/v1/donations",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "donor_name": "John Smith",
            "donor_email": "john@example.com",
            "donor_phone": "520-555-1234",
            "organization": "Smith Foundation",
            "amount": 500.00,
            "donation_date": "2025-10-15",
            "donation_kind": "cash",
            "description": "Annual contribution",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["donor_name"] == "John Smith"
    assert float(data["amount"]) == 500.00
    assert data["donation_kind"] == "cash"
    assert data["letter_sent"] is False


# =============================================================
# DON-002: Record In-Kind Donation
# =============================================================
def test_create_inkind_donation(client, admin_user):
    """In-kind donation recorded with description."""
    user, token = admin_user

    response = client.post(
        "/api/v1/donations",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "donor_name": "ABC Company",
            "amount": 250.00,
            "donation_date": "2025-11-01",
            "donation_kind": "in_kind",
            "description": "50 notebooks and 50 pens for students",
        }
    )

    assert response.status_code == 201
    data = response.json()
    assert data["donation_kind"] == "in_kind"
    assert "notebooks" in data["description"]


# =============================================================
# DON-003: List Donations with Filter
# =============================================================
def test_list_donations_filter_kind(client, admin_user):
    """Filter by cash/in_kind works."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create one cash and one in-kind
    client.post("/api/v1/donations", headers=headers, json={
        "donor_name": "Cash Donor",
        "amount": 100.00,
        "donation_date": "2025-10-01",
        "donation_kind": "cash",
    })
    client.post("/api/v1/donations", headers=headers, json={
        "donor_name": "InKind Donor",
        "amount": 200.00,
        "donation_date": "2025-10-02",
        "donation_kind": "in_kind",
        "description": "Supplies",
    })

    # Filter for cash only
    response = client.get(
        "/api/v1/donations?donation_kind=cash",
        headers=headers
    )

    assert response.status_code == 200
    data = response.json()
    for donation in data["donations"]:
        assert donation["donation_kind"] == "cash"


# =============================================================
# DON-004: Mark Thank You Letter Sent
# =============================================================
def test_mark_letter_sent(client, admin_user):
    """letter_sent=True sets letter_sent_at timestamp."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create donation
    create_resp = client.post("/api/v1/donations", headers=headers, json={
        "donor_name": "Letter Test Donor",
        "amount": 300.00,
        "donation_date": "2025-10-15",
        "donation_kind": "cash",
    })
    donation_id = create_resp.json()["id"]

    # Verify letter_sent starts as False
    assert create_resp.json()["letter_sent"] is False

    # Mark letter as sent
    response = client.patch(
        f"/api/v1/donations/{donation_id}",
        headers=headers,
        json={"letter_sent": True}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["letter_sent"] is True
    assert data["letter_sent_at"] is not None


# =============================================================
# DON-005: Donation Summary Report
# =============================================================
def test_donation_summary(client, admin_user):
    """Aggregates total_cash, total_in_kind, letters_pending."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create multiple donations
    client.post("/api/v1/donations", headers=headers, json={
        "donor_name": "Donor A",
        "amount": 100.00,
        "donation_date": "2025-10-01",
        "donation_kind": "cash",
    })
    client.post("/api/v1/donations", headers=headers, json={
        "donor_name": "Donor B",
        "amount": 200.00,
        "donation_date": "2025-10-02",
        "donation_kind": "cash",
    })
    client.post("/api/v1/donations", headers=headers, json={
        "donor_name": "Donor C",
        "amount": 150.00,
        "donation_date": "2025-10-03",
        "donation_kind": "in_kind",
        "description": "Supplies",
    })

    # Get summary
    response = client.get(
        "/api/v1/donations/summary",
        headers=headers
    )

    assert response.status_code == 200
    data = response.json()
    assert data["total_donations"] == 3
    assert float(data["total_cash"]) == 300.00
    assert float(data["total_in_kind"]) == 150.00
    assert data["letters_pending"] == 3


# =============================================================
# DON-006: Delete Donation
# =============================================================
def test_delete_donation(client, admin_user):
    """Donation permanently removed."""
    user, token = admin_user
    headers = {"Authorization": f"Bearer {token}"}

    # Create donation
    create_resp = client.post("/api/v1/donations", headers=headers, json={
        "donor_name": "Delete Test Donor",
        "amount": 50.00,
        "donation_date": "2025-10-15",
        "donation_kind": "cash",
    })
    donation_id = create_resp.json()["id"]

    # Delete it
    response = client.delete(
        f"/api/v1/donations/{donation_id}",
        headers=headers
    )
    assert response.status_code == 200

    # Verify it's gone
    get_resp = client.get(
        f"/api/v1/donations/{donation_id}",
        headers=headers
    )
    assert get_resp.status_code == 404


# =============================================================
# DON-007: Volunteer Cannot Access Donations
# =============================================================
def test_volunteer_cannot_access_donations(client, volunteer_user):
    """Volunteer gets 403 on donation endpoints."""
    user, token = volunteer_user

    response = client.get(
        "/api/v1/donations",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 403
