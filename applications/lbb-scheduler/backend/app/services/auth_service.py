"""
Authentication Service — Business Logic Layer
================================================
Contains all authentication logic:
  - register_user(): Create new account (inactive until admin approves)
  - authenticate_user(): Verify credentials and return JWT tokens
  - refresh_access_token(): Issue new access token from refresh token
  - verify_security_questions(): Validate answers for password reset
  - reset_password(): Change password after verification

WHY A SERVICE LAYER?
Routes handle HTTP (request/response). Services handle logic.
This separation means:
  - Business rules are in ONE place (not scattered across routes)
  - Services can be reused (CLI tools, background jobs, tests)
  - Routes stay thin and readable
  - Testing is easier (test services without HTTP)

FLOW:
  Route receives request → Validates with Pydantic schema
    → Calls service function → Service queries database
      → Returns result → Route formats response
"""

from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.models.user import User
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
)
from app.schemas.auth import RegisterRequest
from jose import jwt, JWTError
from app.core.config import settings


# ---------------------------------------------------------------
# Registration
# ---------------------------------------------------------------
def register_user(db: Session, data: RegisterRequest) -> User:
    """
    Create a new user account.

    Steps:
    1. Check if username or email already exists
    2. Hash the password and security answers
    3. Create User record with is_active=False
    4. Save to database

    ConOps 6.5.1: Account is NOT active until admin approves.

    Args:
        db: Database session (from get_db dependency)
        data: Validated registration data (from Pydantic schema)

    Returns:
        The created User object

    Raises:
        ValueError: If username or email already exists
    """
    # Check for duplicate username or email
    existing = db.query(User).filter(
        or_(
            User.username == data.username,
            User.email == data.email,
        )
    ).first()

    if existing:
        if existing.username == data.username:
            raise ValueError("Username already taken")
        raise ValueError("Email already registered")

    # Create user with hashed credentials
    # NEVER store plaintext passwords or security answers
    user = User(
        username=data.username,
        email=data.email,
        password_hash=hash_password(data.password),
        security_question_1=data.security_question_1,
        security_answer_1=hash_password(data.security_answer_1.lower().strip()),
        security_question_2=data.security_question_2,
        security_answer_2=hash_password(data.security_answer_2.lower().strip()),
        first_name=data.first_name,
        last_name=data.last_name,
        phone_number=data.phone_number,
        role=data.role,
        affiliation=data.affiliation,
        is_active=False,  # ConOps 6.5.1: Admin must approve
    )

    db.add(user)
    db.commit()
    db.refresh(user)  # Reload to get the generated id and timestamps

    return user


# ---------------------------------------------------------------
# Login / Authentication
# ---------------------------------------------------------------
def authenticate_user(db: Session, username: str, password: str) -> dict:
    """
    Verify credentials and return JWT tokens + user info.

    Steps:
    1. Find user by username
    2. Verify password against stored hash
    3. Check if account is active (admin-approved)
    4. Generate access + refresh tokens
    5. Return tokens and basic user info

    Args:
        username: From login form
        password: Plaintext password from login form

    Returns:
        Dict with access_token, refresh_token, token_type, user

    Raises:
        ValueError: If credentials are invalid or account inactive
    """
    # Step 1: Find the user
    user = db.query(User).filter(User.username == username).first()

    # Step 2: Verify password
    # We check both conditions with the same error message to avoid
    # revealing whether the username exists (security best practice)
    if not user or not verify_password(password, user.password_hash):
        raise ValueError("Invalid username or password")

    # Step 3: Check if admin has approved this account
    if not user.is_active:
        raise ValueError("Account is pending admin approval")

    # Step 4: Generate JWT tokens
    # The "sub" (subject) claim identifies who this token belongs to
    token_data = {"sub": str(user.id), "role": user.role}
    access_token = create_access_token(data=token_data)
    refresh_token = create_refresh_token(data=token_data)

    # Step 5: Return everything the frontend needs
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": {
            "id": str(user.id),
            "username": user.username,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "role": user.role,
        },
    }


# ---------------------------------------------------------------
# Token Refresh
# ---------------------------------------------------------------
def refresh_access_token(db: Session, refresh_token: str) -> dict:
    """
    Issue a new access token using a valid refresh token.

    WHY REFRESH TOKENS?
    Access tokens expire quickly (30 min) for security.
    Refresh tokens last longer (7 days) for convenience.
    When the access token expires, the frontend sends the
    refresh token to get a new access token without making
    the user type their password again.

    Args:
        refresh_token: The refresh token from the original login

    Returns:
        Dict with new access_token, same refresh_token, user info

    Raises:
        ValueError: If refresh token is invalid or expired
    """
    try:
        # Decode and validate the refresh token
        payload = jwt.decode(
            refresh_token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        user_id = payload.get("sub")
        if not user_id:
            raise ValueError("Invalid refresh token")

    except JWTError:
        raise ValueError("Refresh token expired or invalid")

    # Find the user (they might have been deactivated since login)
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        raise ValueError("User not found or deactivated")

    # Generate new access token (refresh token stays the same)
    token_data = {"sub": str(user.id), "role": user.role}
    new_access_token = create_access_token(data=token_data)

    return {
        "access_token": new_access_token,
        "refresh_token": refresh_token,  # Reuse the same refresh token
        "token_type": "bearer",
        "user": {
            "id": str(user.id),
            "username": user.username,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "role": user.role,
        },
    }


# ---------------------------------------------------------------
# Password Reset — Security Question Verification
# ---------------------------------------------------------------
def verify_security_questions(
    db: Session, username: str, answer_1: str, answer_2: str
) -> str:
    """
    Step 1 of password reset: Verify the user's security answers.

    We hash the provided answers and compare against stored hashes,
    same as password verification. Answers are lowercased and
    stripped to be forgiving of minor formatting differences.

    Args:
        username: The account to reset
        answer_1: Answer to security question 1
        answer_2: Answer to security question 2

    Returns:
        A short-lived JWT reset token (5 min expiry)

    Raises:
        ValueError: If username not found or answers don't match
    """
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise ValueError("Invalid username or security answers")

    # Verify both answers (lowercased + stripped for consistency)
    answer_1_valid = verify_password(
        answer_1.lower().strip(), user.security_answer_1
    )
    answer_2_valid = verify_password(
        answer_2.lower().strip(), user.security_answer_2
    )

    if not answer_1_valid or not answer_2_valid:
        raise ValueError("Invalid username or security answers")

    # Generate a short-lived reset token (5 minutes)
    from datetime import timedelta
    reset_token = create_access_token(
        data={"sub": str(user.id), "purpose": "password_reset"},
        expires_delta=timedelta(minutes=5),
    )

    return reset_token


# ---------------------------------------------------------------
# Password Reset — Change Password
# ---------------------------------------------------------------
def reset_password(db: Session, reset_token: str, new_password: str) -> None:
    """
    Step 2 of password reset: Change the password using the reset token.

    Args:
        reset_token: Token from verify_security_questions (5 min expiry)
        new_password: The new password (already validated by Pydantic)

    Raises:
        ValueError: If reset token is invalid, expired, or wrong purpose
    """
    try:
        payload = jwt.decode(
            reset_token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )

        # Ensure this token was issued for password reset
        if payload.get("purpose") != "password_reset":
            raise ValueError("Invalid reset token")

        user_id = payload.get("sub")
        if not user_id:
            raise ValueError("Invalid reset token")

    except JWTError:
        raise ValueError("Reset token expired or invalid")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError("User not found")

    # Update the password
    user.password_hash = hash_password(new_password)
    db.commit()
