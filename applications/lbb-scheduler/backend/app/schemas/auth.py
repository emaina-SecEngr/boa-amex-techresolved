"""
Authentication Schemas — Request/Response Validation
======================================================
These schemas validate data flowing through the auth endpoints:
  POST /auth/register  → RegisterRequest (in) → UserResponse (out)
  POST /auth/login     → LoginRequest (in)    → TokenResponse (out)
  POST /auth/refresh   → RefreshRequest (in)  → TokenResponse (out)

Pydantic validates every field automatically:
- Wrong type? → 422 error with details
- Missing required field? → 422 error
- Email not valid? → 422 error
- Password too short? → 422 error

The developer doesn't write any validation code — Pydantic does it
based on the type hints and Field() constraints below.

KEY CONCEPT: Request schemas (what the client sends) are DIFFERENT
from response schemas (what the server returns). You never want to
accidentally expose password hashes or internal IDs.
"""

from uuid import UUID
from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional


# ---------------------------------------------------------------
# Registration
# ---------------------------------------------------------------
class RegisterRequest(BaseModel):
    """
    What the frontend sends when a new user fills out the
    registration form (RegisterPage.jsx).

    Every field here maps to a form input. Pydantic ensures:
    - username is 3-50 chars
    - email is valid format
    - password is at least 8 chars
    - both security questions are provided
    - required personal info is present
    """
    # Account credentials
    username: str = Field(
        ...,                    # ... means REQUIRED (no default)
        min_length=3,
        max_length=50,
        description="Unique username for login"
    )
    email: EmailStr = Field(
        ...,
        description="Valid email address"
    )
    password: str = Field(
        ...,
        min_length=8,
        max_length=128,
        description="Password (min 8 characters)"
    )

    # Security questions for password recovery (ConOps 6.5.3)
    security_question_1: str = Field(..., min_length=1)
    security_answer_1: str = Field(..., min_length=1)
    security_question_2: str = Field(..., min_length=1)
    security_answer_2: str = Field(..., min_length=1)

    # Personal information
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    phone_number: str = Field(..., min_length=1, max_length=20)
    role: str = Field(
        ...,
        pattern="^(volunteer|school_admin)$",
        description="Only volunteer and school_admin can self-register"
    )
    affiliation: Optional[str] = Field(
        None,                   # None means OPTIONAL (defaults to None)
        max_length=255,
        description="School name or professional organization"
    )


# ---------------------------------------------------------------
# Login
# ---------------------------------------------------------------
class TokenResponse(BaseModel):
    """
    What the server returns after successful login.

    The frontend stores access_token in localStorage and sends
    it with every subsequent API request via the Axios interceptor.
    """
    access_token: str = Field(..., description="JWT access token (30 min)")
    refresh_token: str = Field(..., description="JWT refresh token (7 days)")
    token_type: str = Field(default="bearer", description="Always 'bearer'")
    user: "UserBrief" = Field(...,
                              description="Basic user info for the frontend")


class UserBrief(BaseModel):
    """
    Minimal user info returned with the login token.
    The frontend stores this to display the user's name and role
    in the Navbar without making an extra API call.

    NOTE: No password_hash, no security answers, no totp_secret.
    Only what the frontend NEEDS to display the UI.
    """
    id: str
    username: str
    first_name: str
    last_name: str
    email: str
    role: str

    @field_validator("id", mode="before")
    @classmethod
    def convert_uuid_to_str(cls, v):
        if isinstance(v, UUID):
            return str(v)
        return v

    class Config:
        from_attributes = True  # Allows creating from SQLAlchemy model


# Fix forward reference (TokenResponse references UserBrief)
TokenResponse.model_rebuild()


# ---------------------------------------------------------------
# Token Refresh
# ---------------------------------------------------------------
class RefreshRequest(BaseModel):
    """
    Sent when the access token expires and the frontend needs
    a new one without making the user log in again.
    """
    refresh_token: str = Field(..., description="The refresh token from login")


# ---------------------------------------------------------------
# Password Reset (ConOps 6.5.3)
# ---------------------------------------------------------------
class PasswordResetVerifyRequest(BaseModel):
    """
    Step 1 of password reset: User provides username and answers
    to their security questions. If answers match, they get a
    one-time reset token.
    """
    username: str = Field(..., min_length=1)
    security_answer_1: str = Field(..., min_length=1)
    security_answer_2: str = Field(..., min_length=1)


class PasswordResetRequest(BaseModel):
    """
    Step 2 of password reset: User provides the reset token
    and their new password.
    """
    reset_token: str = Field(..., description="Token from verify step")
    new_password: str = Field(..., min_length=8, max_length=128)


class MessageResponse(BaseModel):
    """
    Generic response for actions that don't return data.
    Used for: registration success, password reset, account approval, etc.
    """
    message: str
    detail: Optional[str] = None
