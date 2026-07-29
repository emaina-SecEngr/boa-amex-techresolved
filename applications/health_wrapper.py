"""
Health-only wrapper for Azure Container Apps demo.
Apps run without PostgreSQL — health and API docs work.
Database-dependent endpoints return demo data.
"""
from fastapi import FastAPI
import os

app_name = os.environ.get("APP_NAME", "lbb-service")
app = FastAPI(title=f"LBB {app_name}", version="1.0.0")

@app.get("/api/v1/health")
async def health():
    return {
        "status": "healthy",
        "service": app_name,
        "version": "1.0.0",
        "environment": "azure-demo",
        "platform": "Azure Container Apps"
    }

@app.get("/api/v1/metrics")
async def metrics():
    return {
        "service": app_name,
        "requests_total": 0,
        "errors_total": 0,
        "uptime_seconds": 0,
        "platform": "Azure Container Apps"
    }

@app.get("/")
async def root():
    return {
        "service": app_name,
        "status": "running",
        "docs": "/docs",
        "health": "/api/v1/health"
    }
