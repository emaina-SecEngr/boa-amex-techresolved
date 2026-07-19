"""JWT authentication for banking portal customers"""
from fastapi import HTTPException, Header
from jose import jwt, JWTError
from app.config import settings

async def get_current_user(authorization: str = Header(...)):
    try:
        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
        return {"customer_id": payload.get("sub"), "email": payload.get("email")}
    except JWTError:
        raise HTTPException(401, "Invalid authentication token")
