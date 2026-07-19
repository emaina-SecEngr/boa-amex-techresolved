# LBBS DevSecOps (MVP2)

This document summarizes tooling, local usage, and how the GitLab pipeline enforces quality for the Life Beyond the Books Scheduler.

## Stack

| Area | Tooling |
|------|---------|
| Backend language | Python 3.13 |
| Backend framework | FastAPI |
| Backend tests | `pytest` (`backend/tests/`) |
| Backend lint | Flake8 (see `.gitlab-ci.yml`) |
| Backend security | Bandit (SAST), pip-audit (SCA), etc. (see CI) |
| Frontend | React 18 + Vite |
| Frontend lint | ESLint |
| Frontend tests | Vitest + Testing Library (`frontend/src/*.test.jsx`) |
| Containers | Docker / Docker Compose |

## Local development

### Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
pytest tests/ -q
```

Docker (API + Postgres + Mailcatcher):

```bash
docker compose up -d --build
docker compose run --rm backend pytest tests/ -q
```

### Frontend

```bash
cd frontend
npm ci
npm run lint
npm run test
npm run dev
```

### Email (optional)

When `SMTP_HOST` and `EMAIL_FROM` are set (e.g. Mailcatcher in `docker-compose.yml`), the API sends real SMTP messages. If SMTP is unset, outbound email calls are **logged** instead of raising (see `app/utils/email.py`).

## GitLab CI

Pipeline stages are defined in `.gitlab-ci.yml`:

1. **lint** — Flake8 (backend), `npm run lint` (frontend). Currently `allow_failure: true` until legacy style issues in older modules are cleaned up; flip to `false` to enforce gates repo-wide.
2. **test** — Backend `pytest` (required pass, no skip fallback); frontend `npm run test` (Vitest).
3. **security** — Bandit, dependency scans, secrets detection, etc.
4. **build** — Image/build verification.

**Database note:** New columns (e.g. `volunteer_profiles.background_check_status`) are applied on fresh databases via `create_all`. Existing PostgreSQL deployments may need a manual `ALTER TABLE` or a migration tool when you introduce schema changes.

## Secrets

Never commit API keys, database passwords, or production SMTP credentials. Use CI/CD variables and local `.env` files (gitignored).

## MVP2 demo video

Record a 10–15 minute walkthrough covering: core workflows (auth, admin, school, volunteer), reports/surveys as implemented, and this pipeline (lint, tests, security scans).
