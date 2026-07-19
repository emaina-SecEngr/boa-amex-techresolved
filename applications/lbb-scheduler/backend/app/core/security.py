"""
LBBS Security Module
======================
Handles all authentication and authorization logic:
- Password hashing (bcrypt) — never store plaintext passwords
- JWT token creation and validation
- Role-Based Access Control (RBAC) decorators
- 2FA support for admin users (TOTP)

SECURITY FLOW:
1. User sends username + password to /auth/login
2. Server verifies password hash → issues JWT token
3. Client stores JWT and sends it in Authorization header
4. Server validates JWT on every request → extracts user role
5. RBAC middleware checks if user's role is allowed for the endpoint
"""

from datetime import datetime, timedelta, timezone
from typing import Optional, List

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db


# ---------------------------------------------------------------
# Password Hashing
# ---------------------------------------------------------------
# bcrypt is the industry standard for password hashing.
# It automatically handles salting (adding random data before
# hashing) so two users with the same password get different hashes.
pwd_context = CryptContext(
    schemes=["bcrypt"],  # Use bcrypt algorithm
    deprecated="auto",   # Auto-upgrade old hash schemes
)


def hash_password(plain_password: str) -> str:
    """
    Hash a plaintext password using bcrypt.

    Args:
        plain_password: The user's plaintext password

    Returns:
        A bcrypt hash string (e.g., '$2b$12$...')

    Example:
        hashed = hash_password("mypassword123")
        # Returns: '$2b$12$LJ3m4ys...' (60 chars, unique every time)
    """
    return pwd_context.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a plaintext password against a stored bcrypt hash.

    Args:
        plain_password: What the user typed in the login form
        hashed_password: What's stored in the database

    Returns:
        True if password matches, False otherwise

    Example:
        is_valid = verify_password("mypassword123", stored_hash)
    """
    return pwd_context.verify(plain_password, hashed_password)


# ---------------------------------------------------------------
# JWT Token Management
# ---------------------------------------------------------------
# OAuth2PasswordBearer tells FastAPI where to find the token.
# The client sends: Authorization: Bearer <token>
# tokenUrl is the endpoint where the client obtains the token.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def create_access_token(
    data: dict,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Create a JWT access token containing user information.

    The token is signed with the SECRET_KEY so the server can
    verify it hasn't been tampered with on subsequent requests.

    Args:
        data: Dictionary with claims to encode
              (e.g., {"sub": user_id, "role": "admin"})
        expires_delta: How long the token is valid
                       (default: 30 minutes from config)

    Returns:
        Encoded JWT string

    Example:
        token = create_access_token(
            data={"sub": "user_123", "role": "volunteer"}
        )
        # Returns: "eyJhbGciOiJIUzI1NiJ9.eyJzd..."
    """
    # Make a copy so we don't modify the original dictionary
    to_encode = data.copy()

    # Set expiration time
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )

    # Add expiration and issued-at timestamps to the payload
    to_encode.update({
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    })

    # Sign and encode the token using our SECRET_KEY
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )
    return encoded_jwt


def create_refresh_token(data: dict) -> str:
    """
    Create a longer-lived refresh token.

    WHY TWO TOKEN TYPES?
    - Access token: Short-lived (30 min). Used for every API request.
      If stolen, attacker only has 30 minutes of access.
    - Refresh token: Long-lived (7 days). Used ONLY to get a new
      access token without re-entering username/password.

    This is an industry-standard pattern. The user logs in once,
    gets both tokens. When the access token expires, the frontend
    silently uses the refresh token to get a new access token.
    The user never notices.

    Args:
        data: Dictionary with claims (typically just {"sub": user_id})

    Returns:
        Encoded JWT string with longer expiration
    """
    expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    return create_access_token(data, expires_delta=expires_delta)


# ---------------------------------------------------------------
# Token Validation & Current User Extraction
# ---------------------------------------------------------------
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    """
    FastAPI dependency that extracts and validates the current user
    from the JWT token in the Authorization header.

    This runs automatically on every protected endpoint.

    Flow:
    1. Extract token from Authorization: Bearer <token>
    2. Decode and verify the JWT signature
    3. Extract user_id from the 'sub' claim
    4. Look up the user in the database
    5. Return the user object (or raise 401 if anything fails)

    Usage:
        @router.get("/me")
        def get_profile(current_user: User = Depends(get_current_user)):
            return current_user
    """
    # Standard 401 error for failed authentication
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # Decode the JWT token and verify its signature
        # If the token was tampered with or expired, this throws JWTError
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )

        # Extract the user ID from the 'sub' (subject) claim
        # This is the same user_id we put in when creating the token
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception

    except JWTError:
        # Token is invalid, expired, or tampered with
        raise credentials_exception

    # Import here to avoid circular imports
    # (user.py imports from database.py, database.py doesn't import
    #  from security.py, but if we imported User at the top of this
    #  file, it could create a circular chain)
    from app.models.user import User

    # Look up the user in the database using the ID from the token
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception

    # Check if the account is active (approved by admin per ConOps 6.5.1)
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is pending approval or has been deactivated",
        )

    return user


# ---------------------------------------------------------------
# Role-Based Access Control (RBAC)
# ---------------------------------------------------------------
# These are the four roles defined in the ConOps document.
# Each maps to different levels of system access.
class UserRole:
    """
    Constants for user roles matching ConOps Section 5.1.

    LBB_ADMIN:     Full access to all features, reports, metrics
    SCHOOL_ADMIN:  Manage own school's registration and schedule
    VOLUNTEER:     Manage own profile and event signups
    IT_SUPPORT:    System administration and account management

    WHY USE CONSTANTS INSTEAD OF RAW STRINGS?
    If you type "lbb_admin" in 20 places and misspell it once
    as "lbb_adm1n", you get a silent bug that's hard to find.
    Using UserRole.LBB_ADMIN means Python catches typos immediately
    with an AttributeError.
    """
    LBB_ADMIN = "lbb_admin"
    SCHOOL_ADMIN = "school_admin"
    VOLUNTEER = "volunteer"
    IT_SUPPORT = "it_support"

    ALL_ROLES = [LBB_ADMIN, SCHOOL_ADMIN, VOLUNTEER, IT_SUPPORT]
    ADMIN_ROLES = [LBB_ADMIN, IT_SUPPORT]


def require_roles(allowed_roles: List[str]):
    """
    Factory function that creates a FastAPI dependency to enforce
    role-based access control on an endpoint.

    HOW IT WORKS:
    1. get_current_user runs first (validates JWT, gets user)
    2. This function then checks if the user's role is in
       the allowed_roles list
    3. If not, raises a 403 Forbidden error

    Args:
        allowed_roles: List of role strings that can access the endpoint

    Usage:
        # Only LBB admins can create events
        @router.post("/events")
        def create_event(
            current_user: User = Depends(
                require_roles([UserRole.LBB_ADMIN])
            ),
        ):
            ...

        # Both admins and school admins can view schedules
        @router.get("/schedules")
        def view_schedule(
            current_user: User = Depends(
                require_roles([UserRole.LBB_ADMIN, UserRole.SCHOOL_ADMIN])
            ),
        ):
            ...
    """
    async def role_checker(
        current_user=Depends(get_current_user),
    ):
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"Access denied. Required role(s): "
                    f"{', '.join(allowed_roles)}. "
                    f"Your role: {current_user.role}"
                ),
            )
        return current_user

    return role_checker
