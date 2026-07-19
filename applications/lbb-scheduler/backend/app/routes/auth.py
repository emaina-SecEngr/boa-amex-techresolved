"""
Authentication Routes — API Endpoints
========================================
Maps HTTP endpoints to service functions:
  POST /api/v1/auth/register  → Create new account
  POST /api/v1/auth/login     → Get JWT tokens
  POST /api/v1/auth/refresh   → Refresh expired token
  POST /api/v1/auth/verify    → Verify security questions
  POST /api/v1/auth/reset     → Reset password

HOW FASTAPI ROUTES WORK:
1. Client sends HTTP request (e.g., POST /api/v1/auth/login)
2. FastAPI matches the URL to the right function
3. Pydantic validates the request body automatically
4. The function runs (calls service layer)
5. FastAPI converts the return value to JSON
6. Client receives the response

The route function is intentionally THIN — it handles HTTP
concerns only (status codes, error responses). All business
logic lives in the service layer.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.auth import (
    RegisterRequest,
    TokenResponse,
    RefreshRequest,
    PasswordResetVerifyRequest,
    PasswordResetRequest,
    MessageResponse,
)
from app.services.auth_service import (
    register_user,
    authenticate_user,
    refresh_access_token,
    verify_security_questions,
    reset_password,
)


# Create a router with prefix and tag
# All endpoints in this file start with /auth
# The tag groups them in Swagger UI
router = APIRouter(prefix="/auth", tags=["Authentication"])


# ---------------------------------------------------------------
# POST /auth/register — Create new account
# ---------------------------------------------------------------
@router.post(
    "/register",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Request a new account",
    description="Creates an inactive account pending admin approval (ConOps 6.5.1).",
)
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    """
    How this works:
    1. FastAPI sees `data: RegisterRequest` and automatically
       parses + validates the JSON body against our schema
    2. If validation fails, FastAPI returns 422 before this
       function even runs
    3. If validation passes, we call the service function
    4. We catch ValueError (duplicate username/email) and
       convert it to a 409 Conflict HTTP response
    """
    try:
        register_user(db, data)
        return MessageResponse(
            message="Account request submitted successfully",
            detail="An administrator will review your account. "
                   "You will be notified once approved.",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )


# ---------------------------------------------------------------
# POST /auth/login — Authenticate and get tokens
# ---------------------------------------------------------------
@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Login with username and password",
    description="Returns JWT access and refresh tokens.",
)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    """
    NOTE: This uses OAuth2PasswordRequestForm instead of a JSON body.
    That's because OAuth2 spec requires form-encoded data for the
    token endpoint. The frontend sends:
      Content-Type: application/x-www-form-urlencoded
      username=john&password=secret

    This is what our useAuth.js hook does with URLSearchParams.
    """
    try:
        result = authenticate_user(db, form_data.username, form_data.password)
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )


# ---------------------------------------------------------------
# POST /auth/refresh — Get new access token
# ---------------------------------------------------------------
@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Refresh access token",
    description="Exchange a valid refresh token for a new access token.",
)
def refresh(data: RefreshRequest, db: Session = Depends(get_db)):
    try:
        result = refresh_access_token(db, data.refresh_token)
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )


# ---------------------------------------------------------------
# POST /auth/verify — Verify security questions (password reset step 1)
# ---------------------------------------------------------------
@router.post(
    "/verify",
    summary="Verify security questions for password reset",
    description="If answers are correct, returns a short-lived reset token.",
)
def verify_questions(
    data: PasswordResetVerifyRequest, db: Session = Depends(get_db)
):
    try:
        reset_token = verify_security_questions(
            db, data.username, data.security_answer_1, data.security_answer_2
        )
        return {"reset_token": reset_token}
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ---------------------------------------------------------------
# POST /auth/reset — Reset password (step 2)
# ---------------------------------------------------------------
@router.post(
    "/reset",
    response_model=MessageResponse,
    summary="Reset password with reset token",
    description="Change password using the token from /auth/verify.",
)
def reset_pwd(data: PasswordResetRequest, db: Session = Depends(get_db)):
    try:
        reset_password(db, data.reset_token, data.new_password)
        return MessageResponse(message="Password reset successfully")
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
