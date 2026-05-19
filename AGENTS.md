# AGENTS.md

## Stack
Vue 3 + Vite (frontend) | FastAPI + SQLAlchemy (backend) | PostgreSQL 16 | Docker Compose

## Commands
```bash
./start_dev.sh        # Dev: local PG (port 5433) + uvicorn (8000) + vite (5173) via tmux
./deploy.sh           # Prod (192.168.178.132): SSH → git reset --hard → build --no-cache → up
./deploy_dev.sh       # Dev (192.168.178.133): SSH → git reset --hard → build --no-cache → up
./release.sh minor "desc"   # Tag + commit + copy to releases/vX.X.X/
```

## Structure
```
backend/app/main.py          # FastAPI entry, middleware, router mounts, auto-migrations
backend/app/routers/         # 10 routers (auth, persone, registro, categorie, etc.)
backend/app/database.py      # SessionLocal, reads DATABASE_URL
backend/app/rate_limit.py    # slowapi limiter (in-memory, per-worker)
backend/migrations/          # .sql files, copied by deploy.sh
backend/uploads/             # File uploads, served at /uploads/

frontend/src/main.js         # Router, auth guard, all route registrations
frontend/src/views/          # 16 views (see Route Map below)
frontend/src/api/index.js    # Axios instance, all API calls
frontend/src/store.js        # Global state (token, user, societa)
frontend/nginx.conf          # Proxies /api/ and /uploads/ to backend:8000
frontend/vite.config.js      # Dev proxy to localhost:8000, PWA config
```

## Route Map
```
/                   → Home.vue (dashboard: Allenatori, Segreteria, Responsabili)
/allenatori         → Allenatori.vue (planning + categories CRUD)
/responsabili       → Responsabili.vue (assign mister/dirigente to categories)
/segreteria         → Segreteria.vue (category overview with stats)
/segreteria/scheda/:id → SchedaGiocatore.vue (player detail)
/segreteria/:id     → SegreteriaCategoria.vue (per-category player table)
/scelta/:id         → Scelta.vue (action picker per category)
/registro/:id       → Registro.vue (attendance)
/allenamenti/:id    → Allenamenti.vue (~3000 lines, canvas tactical board)
/convocazioni/:id   → Convocazioni.vue
/dati/:id           → DatiMatricole.vue
/reportistica/:id   → Reportistica.vue
/admin              → Admin.vue (user CRUD, encryption key)
/admin/societa      → Societa.vue (multi-society management)
/form-iscrizione    → FormOnlineIscrizione.vue (public, no auth)
```
**Route order matters** — `/segreteria/scheda/:id` must come BEFORE `/segreteria/:id` or `:id` captures "scheda".

## Environment
- `.env` at root: `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `SECRET_KEY`, `ENCRYPTION_KEY`, `DEFAULT_PASSWORD`
- `VITE_API_URL` is a Docker build ARG (`docker-compose.yml`), NOT from `.env`
- **Never commit `.env`** (root, `backend/.env`, `frontend/.env` all gitignored)

## Dev vs Prod
- **Dev**: `start_dev.sh` → tmux sessions `registro_backend` / `registro_frontend`. Vite proxies `/api` and `/uploads` to `localhost:8000`. Single uvicorn process. Local PG on port 5433, socket `/tmp/pgsocket`, data in `/tmp/pgdata`.
- **Dev DB sync**: `start_dev.sh` dumps full schema+data from prod only on first run (when `persone` table is empty). Local changes preserved thereafter.
- **Prod**: nginx in frontend container proxies to `backend:8000`. 4 uvicorn workers, no `--reload`. Host nginx on `:3000` (frontend) and `:8000` (backend).
- **Frontend changes require full rebuild** — `dist/` baked into nginx image.

## Migrations
- **No Alembic.** Auto-migrations in `main.py:run_migrations()` run on every startup.
- SQL files in `backend/migrations/*.sql` are also run by `deploy.sh` (hardcoded in deploy.sh).
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
- Roles: `super_admin` (all società), `admin` (own società), `mister` (assigned categorie), `dirigente` (read-only), `segreteria`, `infermeria`.
- No linting or type-checking configured.
- `Allenamenti.vue` is ~3000 lines, single-file canvas-based tactical board.
- `Infermeria.vue` does NOT exist yet — Home.vue card is commented out.

## ⚠️ Production Deploy Checklist

### Critical: External Nginx Proxy
**Prod has an EXTERNAL nginx on the host that proxies to Docker containers.**
- Frontend container: `0.0.0.0:3000:80` — **NEVER use `127.0.0.1:3000:80`** (external nginx can't reach it → 502 Bad Gateway)
- Backend container: `0.0.0.0:8000:8000` — must also be `0.0.0.0` not `127.0.0.1`
- Always verify: `curl -s -o /dev/null -w '%{http_code}' http://192.168.178.132:3000/` returns 200

### Frontend Changes
- Frontend changes require **full rebuild** (`docker compose build --no-cache`) — `dist/` baked into nginx image
- Always remove images before rebuild: `docker rmi registro_presenze-frontend:latest registro_presenze-backend:latest`
- Service Worker caches aggressively — users may need hard refresh (Ctrl+Shift+R)

### docker-compose.yml Port Binding
- **Frontend port MUST be `0.0.0.0:3000:80`** (not `127.0.0.1:3000:80`)
- **Backend port MUST be `0.0.0.0:8000:8000`** (not `127.0.0.1:8000:8000`)
