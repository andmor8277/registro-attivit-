# AGENTS.md

## Stack
Vue 3 + Vite (frontend) | FastAPI + SQLAlchemy (backend) | PostgreSQL 16 | Docker Compose

## Commands
```bash
./start_dev.sh        # Dev: local PG (port 5433) + uvicorn (8000) + vite (5173)
./deploy.sh           # Prod: SSH → git reset --hard → build --no-cache → up
./release.sh minor "desc"   # Tag + commit + copy to releases/vX.X.X/
```

## Structure
```
backend/app/main.py          # FastAPI entry, middleware, router mounts, auto-migrations
backend/app/routers/         # 11 routers (auth, persone, registro, categorie, etc.)
backend/app/database.py      # SessionLocal, reads DATABASE_URL
backend/app/rate_limit.py    # slowapi limiter (in-memory, per-worker)
backend/migrations/          # .sql files, copied by deploy.sh
backend/uploads/             # File uploads, served at /uploads/

frontend/src/main.js         # → App.vue → vue-router
frontend/src/views/          # 13 views (one per page)
frontend/src/api/index.js    # Axios instance, all API calls
frontend/src/store.js        # Global state (token, user, societa)
frontend/nginx.conf          # Proxies /api/ and /uploads/ to backend:8000
frontend/vite.config.js      # Dev proxy to localhost:8000, PWA config
```

## Environment
- `.env` at root: `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `SECRET_KEY`, `ENCRYPTION_KEY`, `DEFAULT_PASSWORD`
- `VITE_API_URL` is a Docker build ARG (`docker-compose.yml`), NOT from `.env`
- **Never commit `.env`** (root, `backend/.env`, `frontend/.env` all gitignored)

## Dev vs Prod
- **Dev**: vite proxies `/api` and `/uploads` to `localhost:8000`. Single uvicorn process. Local PG on port 5433.
- **Prod**: nginx in frontend container proxies to `backend:8000`. 4 uvicorn workers, no `--reload`. Host nginx on `:3000` (frontend) and `:8000` (backend).
- **Frontend changes require full rebuild** — `dist/` baked into nginx image.

## Migrations
- **No Alembic.** Auto-migrations in `main.py:run_migrations()` run on every startup.
- SQL files in `backend/migrations/*.sql` are also run by `deploy.sh`.
- `init.sql` seeds `gruppi` and `codici` tables on first DB init.
- New migrations: add to BOTH `run_migrations()` and `backend/migrations/`.

## Security
- `slowapi` limits are **per-worker** (4 workers = 4x effective limit).
- Public PII endpoints (`/persone/`) have `5/minute` rate limit + Pydantic validation.
- File uploads validate MIME magic bytes, not just extension.
- `TrustedHostMiddleware` intentionally removed — Docker network handles isolation.
- CORS: `https://thof.crickethouse.mywire.org`, `localhost:5173`, `localhost:3000`.
- Security headers middleware: strips `Server`, sets CSP, HSTS, X-Frame-Options.

## Testing
- **No test suite.** Verify manually or check prod logs:
  `ssh root@192.168.178.132 "docker compose -f /opt/registro_presenze/docker-compose.yml logs -f"`

## Conventions
- Italian language in UI and codebase.
- Roles: `super_admin` (all società), `admin` (own società), `mister` (assigned categorie), `dirigente` (read-only).
- UI label "Responsabile" = admin locale.
- No linting or type-checking configured.
- `Allenamenti.vue` is ~3000 lines, single-file canvas-based tactical board.
