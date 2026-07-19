"""
SCIM 2.0 Routes — Automated User Provisioning
=================================================
Okta calls these endpoints to automatically create, update,
and deactivate users in LBBS when changes happen in Okta.

  GET    /scim/v2/Users                    -> List users
  POST   /scim/v2/Users                    -> Create user
  GET    /scim/v2/Users/{user_id}          -> Get user
  PATCH  /scim/v2/Users/{user_id}          -> Update user
  DELETE /scim/v2/Users/{user_id}          -> Deactivate user
  GET    /scim/v2/ServiceProviderConfig    -> SCIM capabilities
  GET    /scim/v2/Schemas                  -> User schema
  GET    /scim/v2/ResourceTypes            -> Resource types
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import hash_password
from app.models.user import User

router = APIRouter(prefix="/scim/v2", tags=["SCIM 2.0 — User Provisioning"])

SCIM_SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:User"
SCIM_LIST_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:ListResponse"
SCIM_PATCH_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:PatchOp"
SCIM_SP_CONFIG_SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"


def user_to_scim(user: User) -> dict:
    """Convert our User model to SCIM format."""
    return {
        "schemas": [SCIM_SCHEMA],
        "id": str(user.id),
        "userName": user.username,
        "name": {
            "givenName": user.first_name or "",
            "familyName": user.last_name or "",
            "formatted": f"{user.first_name or ''} {user.last_name or ''}".strip(),
        },
        "emails": [
            {"value": user.email, "primary": True, "type": "work"}
        ] if user.email else [],
        "active": user.is_active,
        "displayName": f"{user.first_name or ''} {user.last_name or ''}".strip(),
        "meta": {
            "resourceType": "User",
            "created": str(user.created_at) if user.created_at else None,
            "lastModified": str(user.updated_at) if user.updated_at else None,
        },
    }


# -------------------------------------------------------
# User CRUD
# -------------------------------------------------------

@router.get("/Users", summary="List users (SCIM)")
async def scim_list_users(
    startIndex: int = Query(1, alias="startIndex"),
    count: int = Query(100, alias="count"),
    filter: str = Query(None),
    db: Session = Depends(get_db),
):
    """
    List users in SCIM format.
    Okta calls this to sync user lists.
    Supports filter by userName: filter=userName eq "john@example.com"
    """
    query = db.query(User)

    if filter and "userName eq" in filter:
        username = filter.split('"')[1] if '"' in filter else ""
        query = query.filter(User.username == username)

    total = query.count()
    users = query.offset(startIndex - 1).limit(count).all()

    return {
        "schemas": [SCIM_LIST_SCHEMA],
        "totalResults": total,
        "startIndex": startIndex,
        "itemsPerPage": len(users),
        "Resources": [user_to_scim(u) for u in users],
    }


@router.post("/Users", status_code=status.HTTP_201_CREATED, summary="Create user (SCIM)")
async def scim_create_user(request: Request, db: Session = Depends(get_db)):
    """
    Create a new user from Okta SCIM provisioning.
    Called automatically when a user is assigned to LBBS in Okta.
    """
    data = await request.json()

    username = data.get("userName", "")
    emails = data.get("emails", [])
    email = emails[0]["value"] if emails else username
    name = data.get("name", {})
    first_name = name.get("givenName", "")
    last_name = name.get("familyName", "")
    active = data.get("active", True)

    # Check for existing user
    existing = db.query(User).filter(User.username == username).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "schemas": ["urn:ietf:params:scim:api:messages:2.0:Error"],
                "detail": f"User {username} already exists",
                "status": 409,
            }
        )

    # Determine role from groups
    groups = data.get("groups", [])
    group_names = [g.get("display", g.get("value", "")) for g in groups]
    role = "volunteer"  # default
    for g in group_names:
        if "admin" in g.lower():
            role = "lbb_admin"
            break
        elif "school" in g.lower():
            role = "school_admin"
            break
        elif "support" in g.lower():
            role = "it_support"
            break

    # Determine district from groups
    affiliation = None
    excluded = ("lbbs-admin", "lbbs-volunteer", "lbbs-school-admin", "lbbs-it-support")
    for g in group_names:
        if g.startswith("lbbs-") and g not in excluded:
            affiliation = g.replace("lbbs-", "")
            break

    user = User(
        id=uuid.uuid4(),
        username=username,
        email=email,
        first_name=first_name,
        last_name=last_name,
        password_hash=hash_password("OktaSSO-NoPassword-" + str(uuid.uuid4())[:8]),
        role=role,
        affiliation=affiliation,
        is_active=active,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user_to_scim(user)


@router.get("/Users/{user_id}", summary="Get user (SCIM)")
async def scim_get_user(user_id: str, db: Session = Depends(get_db)):
    """Get a single user by ID in SCIM format."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user_to_scim(user)


@router.patch("/Users/{user_id}", summary="Update user (SCIM)")
async def scim_update_user(user_id: str, request: Request, db: Session = Depends(get_db)):
    """
    Update a user from Okta SCIM.
    Called when user attributes change in Okta or user is deactivated.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    data = await request.json()
    operations = data.get("Operations", [])

    for op in operations:
        operation = op.get("op", "").lower()
        path = op.get("path", "")
        value = op.get("value", None)

        if operation == "replace":
            if path == "active" or (isinstance(value, dict) and "active" in value):
                active_val = value if isinstance(value, bool) else value.get("active", True)
                user.is_active = active_val

            if path == "name" or (isinstance(value, dict) and "name" in value):
                name_data = value if "givenName" in str(value) else value.get("name", {})
                if isinstance(name_data, dict):
                    if "givenName" in name_data:
                        user.first_name = name_data["givenName"]
                    if "familyName" in name_data:
                        user.last_name = name_data["familyName"]

            if path == "emails" or (isinstance(value, dict) and "emails" in value):
                emails = value if isinstance(value, list) else value.get("emails", [])
                if emails and isinstance(emails, list):
                    user.email = emails[0].get("value", user.email)

    db.commit()
    db.refresh(user)
    return user_to_scim(user)


@router.delete("/Users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete user (SCIM)")
async def scim_delete_user(user_id: str, db: Session = Depends(get_db)):
    """
    Soft-delete (deactivate) a user.
    Called when user is unassigned from LBBS in Okta.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.is_active = False
    db.commit()


# -------------------------------------------------------
# SCIM Discovery Endpoints
# -------------------------------------------------------

@router.get("/ServiceProviderConfig", summary="SCIM capabilities")
async def scim_service_provider_config():
    """
    Tells Okta what SCIM features our endpoint supports.
    Okta reads this to know how to provision users.
    """
    return {
        "schemas": [SCIM_SP_CONFIG_SCHEMA],
        "documentationUri": "https://lbbs.lifebeyondthebooksaz.org/docs",
        "patch": {"supported": True},
        "bulk": {"supported": False, "maxOperations": 0, "maxPayloadSize": 0},
        "filter": {"supported": True, "maxResults": 200},
        "changePassword": {"supported": False},
        "sort": {"supported": False},
        "etag": {"supported": False},
        "authenticationSchemes": [
            {
                "type": "oauthbearertoken",
                "name": "OAuth Bearer Token",
                "description": "Authentication using OAuth 2.0 Bearer Token",
            }
        ],
    }


@router.get("/Schemas", summary="SCIM user schema")
async def scim_schemas():
    """Returns the SCIM schema describing user attributes."""
    return {
        "schemas": ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
        "totalResults": 1,
        "Resources": [
            {
                "id": SCIM_SCHEMA,
                "name": "User",
                "description": "LBBS User Account",
                "attributes": [
                    {"name": "userName", "type": "string", "required": True, "uniqueness": "server"},
                    {"name": "name", "type": "complex", "subAttributes": [
                        {"name": "givenName", "type": "string"},
                        {"name": "familyName", "type": "string"},
                    ]},
                    {"name": "emails", "type": "complex", "multiValued": True},
                    {"name": "active", "type": "boolean", "required": True},
                    {"name": "groups", "type": "complex", "multiValued": True},
                ],
            }
        ],
    }


@router.get("/ResourceTypes", summary="SCIM resource types")
async def scim_resource_types():
    """Returns the types of SCIM resources we support."""
    return {
        "schemas": ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
        "totalResults": 1,
        "Resources": [
            {
                "schemas": ["urn:ietf:params:scim:schemas:core:2.0:ResourceType"],
                "id": "User",
                "name": "User",
                "endpoint": "/scim/v2/Users",
                "schema": SCIM_SCHEMA,
            }
        ],
    }
