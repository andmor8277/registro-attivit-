# AGENTS.md

## Stack
Vue 3 + Vite (frontend) | FastAPI + SQLAlchemy (backend) | PostgreSQL 16 | Docker Compose

## Commands
```bash
./start_dev.sh        # Local dev: PG (5433) + uvicorn (8000) + vite (5173) via tmux
./deploy.sh           # Prod (192.168.178.132): git fetch → build --no-cache → up
./deploy_dev.sh       # Dev (192.168.178.133): tar+ssh sync → VITE_API_URL=/api build → up
./release.sh minor "desc"   # Tag + commit + copy to releases/vX.X.X/
```

## Structure
```
backend/app/main.py          # FastAPI entry, middleware, router mounts, auto-migrations
backend/app/routers/         # 13 routers: auth, persone, registro, categorie, convocazioni,
                             #   allenatori, societa, allenamenti, partite, gruppi, codici,
                             #   weekend, spogliatoi
backend/app/database.py      # SessionLocal, reads DATABASE_URL from env
backend/app/models.py        # SQLAlchemy models (Societa, Categoria, Persona, Utente, etc.)
backend/app/rate_limit.py    # slowapi limiter (in-memory, per-worker)
backend/uploads/             # File uploads, served at /uploads/

frontend/src/main.js         # Router, auth guard, all route registrations
frontend/src/views/          # 19 views (see Route Map)
frontend/src/api/index.js    # Axios instance (api + apiPublic), all API calls
frontend/src/store.js        # Global state: token, user, societa, categoria (Vue refs)
frontend/src/composables/useTacticalBoard.js  # Tactical board logic extracted from Allenamenti.vue
frontend/src/components/TacticalBoard.vue     # Dedicated tactical board canvas component
frontend/nginx.conf          # Proxies /api/ and /uploads/ to backend:8000
frontend/vite.config.js      # Dev proxy to localhost:8000, PWA config
```

## Route Map
```
/login              → Login.vue
/                   → Home.vue (dashboard)
/allenatori         → Allenatori.vue (planning + categories CRUD)
/responsabili       → Responsabili.vue (assign mister/dirigente to categories)
/responsabili/categorie → ResponsabiliCategoria.vue
/responsabili/partite → ProgrammazionePartite.vue
/segreteria         → Segreteria.vue (category overview with stats)
/segreteria/scheda/:id → SchedaGiocatore.vue (player detail)
/segreteria/:id     → SegreteriaCategoria.vue (per-category player table)
/scelta/:id         → Scelta.vue (action picker per category)
/registro/:id       → Registro.vue (attendance)
/allenamenti/:id    → Allenamenti.vue (uses TacticalBoard.vue component)
/convocazioni/:id   → Convocazioni.vue
/dati/:id           → DatiMatricole.vue
/reportistica/:id   → Reportistica.vue
/admin              → Admin.vue (user CRUD, encryption key)
/admin/societa      → Societa.vue (multi-society management)
/form-iscrizione    → FormOnlineIscrizione.vue (public, no auth)
```
**Route order matters** — `/segreteria/scheda/:id` MUST come BEFORE `/segreteria/:id` or `:id` captures "scheda".

**Unrouted views:** `Spogliatoi.vue` exists in `views/` but has no route in `main.js` yet.

## Environment
- `.env` at root: `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `SECRET_KEY`, `ENCRYPTION_KEY`, `DEFAULT_PASSWORD`
- `VITE_API_URL` is a Docker build ARG (`docker-compose.yml`). Default: `https://thof.crickethouse.mywire.org/api`
- **Dev server**: `VITE_API_URL=/api` (nginx internal proxy, no CORS). Set via env var before build.
- **Never commit `.env`** (root, `backend/.env`, `frontend/.env` all gitignored)

## Dev vs Prod
- **Local Dev**: `start_dev.sh` → tmux sessions `registro_backend` / `registro_frontend`. Vite proxies `/api` and `/uploads` to `localhost:8000`. Single uvicorn process, no `--reload`. Local PG on port 5433, socket `/tmp/pgsocket`, data in `/tmp/pgdata`.
- **Local Dev DB sync**: `start_dev.sh` dumps full schema+data from prod (192.168.178.132) only on first run (when `persone` table is empty). Local changes preserved thereafter.
- **Dev Server** (192.168.178.133): `deploy_dev.sh` → tar+ssh sync (no rsync, no git on remote). Builds with `VITE_API_URL=/api`. SSH key: `~/.ssh/id_ed25519_dev`.
- **Prod** (192.168.178.132): `deploy.sh` → git fetch+reset, build --no-cache. External nginx on host proxies to containers. 4 uvicorn workers, no `--reload`.
- **Frontend changes require full rebuild** — `dist/` baked into nginx image.

## Migrations
- **No Alembic.** Auto-migrations in `main.py:run_migrations()` run on every backend startup.
- `deploy.sh` and `deploy_dev.sh` also attempt to run SQL files from `migrations/` at project root (currently none exist — all migrations are in `run_migrations()`).
- `init.sql` seeds `gruppi` and `codici` tables on first DB init (mounted to docker-entrypoint-initdb.d).
- New migrations: add to `run_migrations()` in `main.py`. If you also need a standalone SQL file, place it in `migrations/` at project root and add it to both deploy scripts.

## Security
- `slowapi` limits are **per-worker** (4 workers = 4x effective limit).
- Public PII endpoints (`/persone/`) have `5/minute` rate limit + Pydantic validation.
- File uploads validate MIME magic bytes, not just extension.
- `TrustedHostMiddleware` intentionally removed — Docker network handles isolation.
- CORS origins: `thof.crickethouse.mywire.org`, `localhost:5173`, `localhost:3000`, `192.168.178.133:3000`.
- Security headers middleware: strips `Server`, sets CSP, HSTS, X-Frame-Options.

## Testing
- **No test suite.** Verify manually or check logs:
  - Prod: `ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose logs -f"`
  - Dev: `ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 "cd /opt/registro_presenze && docker compose logs -f"`

## Conventions
- Italian language in UI and codebase.
- Roles: `super_admin` (all società), `admin` (own società), `mister` (assigned categorie), `dirigente` (read-only), `segreteria`, `infermeria`.
- No linting or type-checking configured.
- Tactical board logic is in `composables/useTacticalBoard.js` + `components/TacticalBoard.vue`, not inline in `Allenamenti.vue`.
- `Infermeria.vue` does NOT exist yet — Home.vue card is commented out.
- `release.sh` references `dev.sh` (line 77) which doesn't exist — it should be `start_dev.sh`.

## ⚠️ Production Deploy Checklist

### Critical: External Nginx Proxy
**Prod has an EXTERNAL nginx on the host that proxies to Docker containers.**
- Frontend: `0.0.0.0:3000:80` — **NEVER use `127.0.0.1:3000:80`** (external nginx can't reach → 502)
- Backend: `0.0.0.0:8000:8000` — must be `0.0.0.0` not `127.0.0.1`
- Verify: `curl -s -o /dev/null -w '%{http_code}' http://192.168.178.132:3000/` → 200

### Frontend Changes
- Require **full rebuild** (`docker compose build --no-cache`) — `dist/` baked into nginx image
- Service Worker caches aggressively — users may need hard refresh (Ctrl+Shift+R)
