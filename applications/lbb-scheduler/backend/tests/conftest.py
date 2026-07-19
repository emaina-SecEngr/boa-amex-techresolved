"""
Test Configuration & Shared Fixtures
======================================
"""

from datetime import date

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.core.security import hash_password, create_access_token
from app.models.event import AcademicYear
from app.models.school import School
from app.models.user import User
from main import app

import uuid

# In-memory SQLite shared across connections (no file — works in Docker as non-root and locally)
engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def academic_year(db_session):
    """Shared academic year for event + school integration tests."""
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


@pytest.fixture
def test_school(db_session, admin_user):
    """ORM school row for event registration tests."""
    user, _token = admin_user
    school = School(
        id=str(uuid.uuid4()),
        school_name="Test Elementary",
        school_district="Tucson Unified",
        school_address="123 Test Ave, Tucson AZ",
        poc_name="Jane Doe",
        poc_phone="520-555-1234",
        poc_email="jane@test.com",
        admin_user_id=str(user.id),
    )
    db_session.add(school)
    db_session.commit()
    db_session.refresh(school)
    return school


@pytest.fixture
def admin_user(db_session):
    user = User(
        id=str(uuid.uuid4()),
        username="testadmin",
        email="admin@test.com",
        password_hash=hash_password("AdminPass123!"),
        role="lbb_admin",
        is_active=True,
        first_name="Test",
        last_name="Admin",
        phone_number="520-555-0001",
        affiliation="LBB Test",
        security_question_1="What is your pet name?",
        security_answer_1=hash_password("fluffy"),
        security_question_2="What city were you born?",
        security_answer_2=hash_password("tucson"),
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role})
    return user, token


@pytest.fixture
def volunteer_user(db_session):
    user = User(
        id=str(uuid.uuid4()),
        username="testvolunteer",
        email="volunteer@test.com",
        password_hash=hash_password("VolunteerPass123!"),
        role="volunteer",
        is_active=True,
        first_name="Test",
        last_name="Volunteer",
        phone_number="520-555-0002",
        affiliation="Volunteer Org",
        security_question_1="What is your pet name?",
        security_answer_1=hash_password("buddy"),
        security_question_2="What city were you born?",
        security_answer_2=hash_password("phoenix"),
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role})
    return user, token


@pytest.fixture
def school_admin_user(db_session):
    user = User(
        id=str(uuid.uuid4()),
        username="testschooladmin",
        email="schooladmin@test.com",
        password_hash=hash_password("SchoolPass123!"),
        role="school_admin",
        is_active=True,
        first_name="Test",
        last_name="SchoolAdmin",
        phone_number="520-555-0003",
        affiliation="Test School District",
        security_question_1="What is your pet name?",
        security_answer_1=hash_password("rex"),
        security_question_2="What city were you born?",
        security_answer_2=hash_password("flagstaff"),
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role})
    return user, token


@pytest.fixture
def inactive_user(db_session):
    user = User(
        id=str(uuid.uuid4()),
        username="pendinguser",
        email="pending@test.com",
        password_hash=hash_password("PendingPass123!"),
        role="volunteer",
        is_active=False,
        first_name="Pending",
        last_name="User",
        phone_number="520-555-0004",
        affiliation="Pending Org",
        security_question_1="What is your pet name?",
        security_answer_1=hash_password("spot"),
        security_question_2="What city were you born?",
        security_answer_2=hash_password("mesa"),
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user
