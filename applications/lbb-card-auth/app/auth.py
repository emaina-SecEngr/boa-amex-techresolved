"""LBB Card Auth — API Key Authentication"""
from fastapi import HTTPException, Header
from app.config import settings


async def verify_api_key(x_api_key: str = Header(..., description="API key for payment network authentication")):
    """Verify API key from payment network"""
    if x_api_key != settings.API_KEY:
        raise HTTPException(
            status_code=403,
            detail="Invalid API key. Payment network authentication failed."
        )
    return x_api_key