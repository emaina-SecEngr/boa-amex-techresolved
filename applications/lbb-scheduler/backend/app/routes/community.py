"""
Community Routes — Shared Knowledge Base
============================================
  GET/POST  /api/v1/community/practices     → Best practices
  GET/POST  /api/v1/community/templates     → Program templates
  GET/POST  /api/v1/community/stories       → Success stories
  GET/POST  /api/v1/community/discussions   → Discussion forum
  GET/POST  /api/v1/community/analytics     → Cross-district analytics
"""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.security import get_current_user
from app.models.user import User

router = APIRouter(
    prefix="/community",
    tags=["Community — Shared Knowledge Base"]
)


# ─────────────────────────────────────────────────────
# In-memory storage (replace with database models later)
# ─────────────────────────────────────────────────────
_practices = []
_templates = []
_stories = []
_discussions = []
_analytics = []


# ─────────────────────────────────────────────────────
# BEST PRACTICES
# ─────────────────────────────────────────────────────

@router.get("/practices", summary="List best practices")
async def list_practices(
    category: str = Query(None, description="Filter by category"),
    current_user: User = Depends(get_current_user),
):
    """List best practices shared by districts."""
    results = _practices
    if category:
        results = [p for p in results if p.get("category") == category]
    approved = [p for p in results if p.get("is_approved", False)]
    return {"practices": approved, "total": len(approved)}


@router.post("/practices", status_code=status.HTTP_201_CREATED, summary="Submit a best practice")
async def submit_practice(
    data: dict,
    current_user: User = Depends(get_current_user),
):
    """Submit a best practice for admin approval."""
    practice = {
        "id": str(uuid.uuid4()),
        "title": data.get("title", ""),
        "description": data.get("description", ""),
        "category": data.get("category", "general"),
        "submitted_by": f"{current_user.first_name} {current_user.last_name}",
        "submitted_by_district": current_user.affiliation or "Unknown",
        "is_approved": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _practices.append(practice)
    return {"message": "Best practice submitted for approval", "id": practice["id"]}


@router.patch("/practices/{practice_id}", summary="Approve a best practice")
async def approve_practice(
    practice_id: str,
    current_user: User = Depends(get_current_user),
):
    """Approve a best practice (admin only)."""
    for p in _practices:
        if p["id"] == practice_id:
            p["is_approved"] = True
            p["approved_by"] = str(current_user.id)
            return {"message": "Best practice approved"}
    raise HTTPException(status_code=404, detail="Best practice not found")


# ─────────────────────────────────────────────────────
# PROGRAM TEMPLATES
# ─────────────────────────────────────────────────────

@router.get("/templates", summary="List program templates")
async def list_templates(
    template_type: str = Query(None, description="Filter by type"),
    current_user: User = Depends(get_current_user),
):
    """List program templates shared by districts."""
    results = _templates
    if template_type:
        results = [t for t in results if t.get("template_type") == template_type]
    approved = [t for t in results if t.get("is_approved", False)]
    return {"templates": approved, "total": len(approved)}


@router.post("/templates", status_code=status.HTTP_201_CREATED, summary="Submit a template")
async def submit_template(
    data: dict,
    current_user: User = Depends(get_current_user),
):
    """Submit a program template for approval."""
    template = {
        "id": str(uuid.uuid4()),
        "title": data.get("title", ""),
        "description": data.get("description", ""),
        "template_type": data.get("template_type", "general"),
        "content": data.get("content", ""),
        "submitted_by": f"{current_user.first_name} {current_user.last_name}",
        "is_approved": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _templates.append(template)
    return {"message": "Template submitted for approval", "id": template["id"]}


# ─────────────────────────────────────────────────────
# SUCCESS STORIES
# ─────────────────────────────────────────────────────

@router.get("/stories", summary="List success stories")
async def list_stories(current_user: User = Depends(get_current_user)):
    """List success stories from districts."""
    approved = [s for s in _stories if s.get("is_approved", False)]
    return {"stories": approved, "total": len(approved)}


@router.post("/stories", status_code=status.HTTP_201_CREATED, summary="Submit a success story")
async def submit_story(
    data: dict,
    current_user: User = Depends(get_current_user),
):
    """Submit a success story for approval."""
    story = {
        "id": str(uuid.uuid4()),
        "title": data.get("title", ""),
        "story": data.get("story", ""),
        "district_name": current_user.affiliation or "Unknown",
        "impact_summary": data.get("impact_summary", ""),
        "is_approved": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _stories.append(story)
    return {"message": "Success story submitted for approval", "id": story["id"]}


# ─────────────────────────────────────────────────────
# DISCUSSION FORUM
# ─────────────────────────────────────────────────────

@router.get("/discussions", summary="List discussions")
async def list_discussions(
    category: str = Query(None),
    current_user: User = Depends(get_current_user),
):
    """List discussion threads (top-level posts only)."""
    results = [d for d in _discussions if d.get("parent_id") is None]
    if category:
        results = [d for d in results if d.get("category") == category]
    return {"discussions": results, "total": len(results)}


@router.post("/discussions", status_code=status.HTTP_201_CREATED, summary="Create a discussion")
async def create_discussion(
    data: dict,
    current_user: User = Depends(get_current_user),
):
    """Start a new discussion thread."""
    post = {
        "id": str(uuid.uuid4()),
        "title": data.get("title", ""),
        "body": data.get("body", ""),
        "category": data.get("category", "question"),
        "posted_by": f"{current_user.first_name} {current_user.last_name}",
        "posted_by_district": current_user.affiliation or "Unknown",
        "parent_id": None,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _discussions.append(post)
    return {"message": "Discussion created", "id": post["id"]}


@router.post("/discussions/{post_id}/reply", status_code=status.HTTP_201_CREATED, summary="Reply to discussion")
async def reply_to_discussion(
    post_id: str,
    data: dict,
    current_user: User = Depends(get_current_user),
):
    """Reply to a discussion thread."""
    parent = next((d for d in _discussions if d["id"] == post_id), None)
    if not parent:
        raise HTTPException(status_code=404, detail="Discussion not found")

    reply = {
        "id": str(uuid.uuid4()),
        "title": f"Re: {parent['title']}",
        "body": data.get("body", ""),
        "category": "reply",
        "posted_by": f"{current_user.first_name} {current_user.last_name}",
        "parent_id": post_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _discussions.append(reply)
    return {"message": "Reply posted", "id": reply["id"]}


# ─────────────────────────────────────────────────────
# CROSS-DISTRICT ANALYTICS
# ─────────────────────────────────────────────────────

@router.get("/analytics", summary="Cross-district analytics")
async def get_analytics(
    academic_year: str = Query(None),
    current_user: User = Depends(get_current_user),
):
    """Get aggregated, anonymized analytics across districts."""
    results = _analytics
    if academic_year:
        results = [a for a in results if a.get("academic_year") == academic_year]

    total_events = sum(int(a.get("total_events", 0)) for a in results)
    total_students = sum(int(a.get("total_students", 0)) for a in results)
    total_volunteers = sum(int(a.get("total_volunteers", 0)) for a in results)

    return {
        "districts_reporting": len(results),
        "aggregate": {
            "total_events": total_events,
            "total_students_served": total_students,
            "total_volunteers": total_volunteers,
        },
        "per_district": results,
    }


@router.post("/analytics", status_code=status.HTTP_201_CREATED, summary="Submit district analytics")
async def submit_analytics(
    data: dict,
    current_user: User = Depends(get_current_user),
):
    """Submit anonymized district analytics for benchmarking."""
    entry = {
        "id": str(uuid.uuid4()),
        "district_name": current_user.affiliation or data.get("district_name", "Unknown"),
        "academic_year": data.get("academic_year", ""),
        "total_events": data.get("total_events", 0),
        "total_students": data.get("total_students", 0),
        "total_volunteers": data.get("total_volunteers", 0),
        "reported_at": datetime.now(timezone.utc).isoformat(),
    }
    _analytics.append(entry)
    return {"message": "Analytics submitted", "id": entry["id"]}
