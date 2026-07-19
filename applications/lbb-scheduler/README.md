# Life Beyond the Books Scheduler (LBBS)

Scheduling application for a Tucson-based non-profit that pairs community professionals with 8th-grade students for experiential life skills classes. Built for **SFWE 402/502** (architecture, ConOps alignment, MVP delivery, and DevSecOps practices).

## Technology stack

| Layer | Choice |
|--------|--------|
| Frontend | React 18, Vite, Tailwind CSS |
| Backend | Python 3.13, FastAPI |
| Database | PostgreSQL 16, SQLAlchemy |
| Local run | Docker Compose |
| Auth | JWT, bcrypt, role-based access (`lbb_admin`, `it_support`, `school_admin`, `volunteer`) |

## Run locally (Docker)

**Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) running.

1. Clone the repository and open the **project root** (the directory that contains `docker-compose.yml`, often `sfwe-group4-lbbs-project-main`).

2. Build and start services:

   ```bash
   docker compose up -d --build
   ```

3. **Development admin login** — With the default Compose file, the backend sets **`SEED_DEV_ADMIN=true`** and **`APP_ENV=development`**, so on **first startup** it creates **`admin` / `admin123`** (`lbb_admin`, active) if that user does not exist. You do **not** need to run a seed script for normal Docker use.

   To create the same user manually (e.g. after restoring a DB without that row), run:

   ```bash
   docker compose exec backend python create_dev_admin.py
   ```

4. Open the app:

   | Service | URL |
   |---------|-----|
   | Frontend | http://localhost:5173 |
   | API docs (Swagger) | http://localhost:8000/docs |
   | Health | http://localhost:8000/health |

5. **Optional — catch outbound email in dev**  
   Compose includes Mailcatcher. With the default backend env (`SMTP_HOST=mailcatcher`, `SMTP_PORT=1025`), messages appear at **http://localhost:1080**. If `SMTP_HOST` is unset, the API still runs and **logs** intended outbound mail instead of sending (see backend logs).

   **School record confirmation (Req 6.5.12 / MVP1):** After an LBB admin creates a school under **Admin → Schools**, a confirmation email is sent to the school’s POC email (`poc_email`). To turn this off in testing, set **`EMAIL_SCHOOL_CREATE_CONFIRMATION=false`** on the backend.  
   **Manual check:** create a school with a real-looking POC email → open **http://localhost:1080** and confirm the message (school name, POC name, date, login + schedule links). You can use the same SMTP settings with **Mailtrap** (or any SMTP sink) by pointing `SMTP_HOST` / `SMTP_PORT` at your provider instead of Mailcatcher.

   **MVP1 demo checklist (school registration confirmation):**

   1. Confirm MailCatcher UI loads at **http://localhost:1080** (after `docker compose up`).
   2. Sign in as LBB admin → **Admin → Schools** → create a school with POC email filled in.
   3. Refresh MailCatcher: message should appear (no passwords or tokens in body).
   4. Optional: watch backend logs for `[email disabled]` if SMTP is not configured.

   **Security review (MVP1):** Confirmation template does not include passwords, reset tokens, or secrets—only public links (`/login`, `/school/schedule`) and school/POC display names.

## Admin reports API (LBB admin only)

Report JSON lives under **`/api/v1/reports/`** (see Swagger). Examples:

| Endpoint | Purpose |
|----------|---------|
| `GET /reports/donations` | Donation totals for optional `start_date` / `end_date` |
| `GET /reports/events` | Event rows in optional date range |
| `GET /reports/mvp2` | Bundled MVP2 aggregates; `format=csv` downloads CSV |
| `GET /reports/attendance` | Events + school registration + volunteer signup counts; CSV supported |

The **Admin → Reports** page calls these endpoints for preview and export.

## User registration

New self-registrations are **inactive** until an administrator activates them (ConOps 6.5.1). Use the `admin` account above to approve users under **Admin → Users**.

## Automated tests

**Backend** (from repo root, requires DB up or use the test client as configured in `backend/tests/conftest.py`):

```bash
docker compose run --rm backend pytest tests/ -q
```

**Frontend:**

```bash
cd frontend
npm ci
npm run test
npm run lint
```

After changing backend Python dependencies or application code, rebuild the backend image before running tests in a container:

```bash
docker compose build backend
```

## DevSecOps and CI

Pipeline layout, local tooling, and database notes for schema changes are described in **[DEVSECOPS.md](./DEVSECOPS.md)**.

## Project layout

```
├── backend/          # FastAPI app, pytest suite, create_dev_admin.py
├── frontend/         # Vite + React
├── docker-compose.yml
└── DEVSECOPS.md
```

## For instructors / evaluators

1. Start Docker Desktop before `docker compose up`.
2. Run `create_dev_admin.py` once the stack is healthy, then sign in at http://localhost:5173/login.
3. Rebuild images (`docker compose build` or `up --build`) after pulling changes that affect Dockerfiles or `requirements.txt`.
