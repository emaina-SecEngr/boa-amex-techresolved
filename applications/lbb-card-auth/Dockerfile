# LBB Card Authorization Service
# Deployed in: Amex-PCI-CDE account (827064972376)
# PCI-DSS compliant container build

FROM python:3.12-slim AS base

# Security: non-root user
RUN groupadd -r lbb && useradd -r -g lbb lbb

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app/ ./app/

# Security: no root, read-only filesystem where possible
USER lbb

# Health check for ECS/ALB
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/v1/health')" || exit 1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]