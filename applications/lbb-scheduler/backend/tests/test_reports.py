"""Report endpoints and reminder trigger tests."""


def test_donations_report_json(client, admin_user):
    _, token = admin_user
    response = client.get(
        "/api/v1/reports/donations-summary",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert "kpis" in body
    assert "total_amount" in body["kpis"]


def test_events_report_json(client, admin_user):
    _, token = admin_user
    response = client.get(
        "/api/v1/reports/events-summary",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert "kpis" in body
    assert "by_status" in body
    assert "total_events" in body["kpis"]


def test_donations_report_no_records_in_far_future_range(client, admin_user):
    """Edge case: empty range returns zeros, not an error."""
    _, token = admin_user
    response = client.get(
        "/api/v1/reports/donations-summary",
        headers={"Authorization": f"Bearer {token}"},
        params={"start_date": "2099-01-01", "end_date": "2099-12-31"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["kpis"]["total_donations"] == 0
    assert float(body["kpis"]["total_amount"]) == 0.0


def test_mvp2_report_json(client, admin_user):
    """Events summary serves as the primary aggregate report."""
    _, token = admin_user
    response = client.get(
        "/api/v1/reports/events-summary",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert "kpis" in body
    assert body["kpis"]["total_events"] >= 0


def test_attendance_report_json(client, admin_user):
    """Volunteer engagement serves as the attendance report."""
    _, token = admin_user
    response = client.get(
        "/api/v1/reports/volunteer-engagement",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert "kpis" in body
    assert "signups_by_month" in body


def test_mvp2_report_forbidden_for_volunteer(client, volunteer_user):
    _, token = volunteer_user
    response = client.get(
        "/api/v1/reports/events-summary",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 403


def test_attendance_report_forbidden_for_volunteer(client, volunteer_user):
    _, token = volunteer_user
    response = client.get(
        "/api/v1/reports/volunteer-engagement",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 403


def test_donations_report_forbidden_for_volunteer(client, volunteer_user):
    _, token = volunteer_user
    response = client.get(
        "/api/v1/reports/donations-summary",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 403


def test_events_report_forbidden_for_volunteer(client, volunteer_user):
    _, token = volunteer_user
    response = client.get(
        "/api/v1/reports/events-summary",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 403


def test_run_volunteer_reminders_admin(client, admin_user):
    _, token = admin_user
    response = client.post(
        "/api/v1/events/reminders/run",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "reminder_14d_emails_sent" in data
    assert "reminder_4d_emails_sent" in data
