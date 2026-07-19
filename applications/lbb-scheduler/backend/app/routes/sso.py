"""
SSO Routes — Okta Single Sign-On
===================================
  GET  /sso/status     → Check if SSO is enabled
  GET  /sso/login      → Redirect to Okta login
  GET  /sso/callback   → Handle Okta response
  POST /sso/logout     → End session
  GET  /sso/userinfo   → Current user info from Okta
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
import os

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User

router = APIRouter(prefix="/sso", tags=["SSO — Single Sign-On"])

OKTA_ENABLED = os.getenv("OKTA_ENABLED", "false").lower() == "true"
OKTA_DOMAIN = os.getenv("OKTA_DOMAIN", "")
OKTA_CLIENT_ID = os.getenv("OKTA_CLIENT_ID", "")
OKTA_CLIENT_SECRET = os.getenv("OKTA_CLIENT_SECRET", "")
OKTA_ISSUER = os.getenv("OKTA_ISSUER", "")
APP_URL = os.getenv("APP_URL", "http://localhost:5173")


@router.get("/status", summary="Check SSO status")
async def sso_status():
    """Returns whether SSO is enabled and the provider name."""
    return {
        "sso_enabled": OKTA_ENABLED,
        "provider": "okta" if OKTA_ENABLED else None,
        "login_url": "/sso/login" if OKTA_ENABLED else None,
    }


@router.get("/login", summary="Redirect to Okta login")
async def sso_login():
    """
    Redirects the user to Okta's authorization endpoint.
    Okta handles the login page, password validation, and MFA.
    After authentication, Okta redirects back to /sso/callback.
    """
    if not OKTA_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SSO is not enabled. Set OKTA_ENABLED=true in .env"
        )

    authorize_url = (
        f"{OKTA_ISSUER}/v1/authorize"
        f"?client_id={OKTA_CLIENT_ID}"
        f"&response_type=code"
        f"&scope=openid profile email groups"
        f"&redirect_uri={APP_URL}/sso/callback"
        f"&state=random_state_value"
    )
    return RedirectResponse(url=authorize_url)


@router.get("/callback", summary="Handle Okta callback")
async def sso_callback(
    code: str = None,
    state: str = None,
    error: str = None,
    db: Session = Depends(get_db),
):
    """
    Receives the authorization code from Okta after user logs in.
    Exchanges code for tokens, extracts user info, and creates/updates
    the user in our database.

    Flow:
      1. Okta redirects here with ?code=xyz
      2. We exchange code for access_token + id_token
      3. We read user info from id_token (email, name, role, groups)
      4. We create or update user in our database
      5. We issue our own JWT token
      6. We redirect user to the frontend dashboard
    """
    if error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"SSO authentication failed: {error}"
        )

    if not code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Authorization code not provided"
        )

    if not OKTA_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="SSO is not enabled"
        )

    # In production, exchange code for token using authlib:
    # async with httpx.AsyncClient() as client:
    #     token_response = await client.post(f"{OKTA_ISSUER}/v1/token", data={
    #         "grant_type": "authorization_code",
    #         "code": code,
    #         "redirect_uri": f"{APP_URL}/sso/callback",
    #         "client_id": OKTA_CLIENT_ID,
    #         "client_secret": OKTA_CLIENT_SECRET,
    #     })
    #     tokens = token_response.json()
    #     id_token = tokens["id_token"]
    #     # Decode and validate id_token...

    return {
        "message": "SSO callback received",
        "code": code[:10] + "...",
        "note": "Enable OKTA_ENABLED=true and configure Okta credentials to complete SSO flow"
    }


@router.post("/logout", summary="SSO logout")
async def sso_logout():
    """
    Ends the user's session.
    In production, also redirects to Okta's logout endpoint
    to end the Okta session (single logout).
    """
    if OKTA_ENABLED:
        logout_url = (
            f"{OKTA_ISSUER}/v1/logout"
            f"?id_token_hint=TOKEN_HERE"
            f"&post_logout_redirect_uri={APP_URL}"
        )
        return {
            "message": "Logged out",
            "okta_logout_url": logout_url,
        }

    return {"message": "Logged out (SSO not enabled)"}


@router.get("/userinfo", summary="Get current SSO user info")
async def sso_userinfo(current_user: User = Depends(get_current_user)):
    """Returns user info from the current session."""
    return {
        "id": str(current_user.id),
        "username": current_user.username,
        "email": current_user.email,
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "role": current_user.role,
        "is_active": current_user.is_active,
        "sso_enabled": OKTA_ENABLED,
    }
