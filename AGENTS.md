# AGENTS.md — The Home of Football (THOF)

## Panoramica
Sistema di gestione multi-società per società sportive dilettantistiche (calcio).
- **Dev server**: 192.168.178.133 (root, key `~/.ssh/id_ed25519_dev`)
- **Prod server**: 192.168.178.132 (root, key `~/.ssh/id_ed25519_prod`)
- **URL prod**: https://thof.crickethouse.mywire.org
- **Path remoto**: `/opt/registro_presenze/`

## Stack
Vue 3 + Vite (frontend) | FastAPI + SQLAlchemy (backend) | PostgreSQL 16 | Docker Compose

## Commands
```bash
./start_dev.sh        # Local dev: PG (5433) + uvicorn (8000) + vite (5173) via tmux
./deploy.sh           # Prod (192.168.178.132): git fetch → build --no-cache → up
./deploy_dev.sh       # Dev (192.168.178.133): tar+ssh sync → VITE_API_URL=/api build → up
./release.sh minor "desc"   # Tag + commit + copy to releases/vX.X.X/
```

## Entry Points
- `backend/app/main.py` — FastAPI entry, middleware, router mounts, auto-migrations
- `frontend/src/main.js` — Router, auth guard, all route registrations
- `frontend/src/store.js` — Global state (token, user, societa, categoria as Vue refs)
- `frontend/src/api/index.js` — Axios instance (`api` + `apiPublic`), all API calls

## Backend Routers (20)
| Router | Prefix | Auth |
|--------|--------|------|
| `auth.py` | `/auth` | vari (login pubblico, resto JWT) |
| `societa.py` | `/societa` | admin |
| `persone.py` | `/persone` | vari (endpoint pubblici PII rate-limitati) |
| `registro.py` | `/registro` | login |
| `codici.py` | `/codici` | login |
| `categorie.py` | `/categorie` | login |
| `convocazioni.py` | `/convocazioni` | login |
| `allenatori.py` | `/allenatori` | login |
| `allenamenti.py` | `/allenamenti` | login |
| `gruppi.py` | `/gruppi` | login |
| `partite.py` | `/partite` | login |
| `weekend.py` | `/weekend` | login |
| `spogliatoi.py` | `/spogliatoi` | login |
| `campi.py` | `/campi` | login |
| `presenze_allenatori.py` | `/presenze-allenatori` | login |
| `valutazioni.py` | `/valutazioni` | login |
| `infortuni.py` | `/infortuni` | login |
| `openday.py` | `/openday` | login |
| `planning_eventi.py` | `/planning-eventi` | login |
| `schede_allenamento.py` | `/schede-allenamento` | login |

## DB Models (25)
`Societa`, `Categoria` (+`parent_id` self-referencing FK), `Gruppo`, `Persona`, `CodicePresenza`, `Registro`, `Utente`, `UtenteCategoria`, `Convocazione`, `ConvocazioneGara`, `ConvocazioneGiocatore`, `Allenatore`, `Allenamento`, `AllenamentoMese`, `AllenamentoSettimana`, `AllenamentoGiorno`, `AllenamentoEsercizio`, `AllenamentoElemento`, `PresenzaAllenatore`, `CatalogoEsercizio`, `Valutazione`, `Infortunio`, `Openday`, `PlanningEvento`, `SchedaAllenamento`

## Route Map
```
/login                            → Login.vue
/                                 → Home.vue (dashboard)
/allenatori                       → Allenatori.vue (categories CRUD, accordion parent/child)
/responsabili                     → Responsabili.vue
/responsabili/categorie           → ResponsabiliCategoria.vue
/responsabili/partite             → ProgrammazionePartite.vue
/responsabili/spogliatoi          → Spogliatoi.vue
/responsabili/presenze-allenatori → PresenzeAllenatori.vue
/scelta/:id                       → Scelta.vue (action picker per category)
/registro/:id                     → Registro.vue (attendance calendar)
/allenamenti/:id                  → Allenamenti.vue (tactical board, catalog)
/scheda-allenamento/:id           → SchedaAllenamento.vue (GPS metrics dashboard + table)
/convocazioni/:id                 → Convocazioni.vue
/dati/:id                         → DatiMatricole.vue
/reportistica/:id                 → Reportistica.vue
/segreteria                       → Segreteria.vue
/segreteria/scheda/:id            → SchedaGiocatore.vue (player detail)
/segreteria/:id                   → SegreteriaCategoria.vue
/segreteria/openday               → Openday.vue
/valutazioni/:id                  → Valutazioni.vue
/infermeria                       → Infermeria.vue (hub)
/infermeria/certificati           → CertificatoMedico.vue
/infermeria/infortunati           → Infortunati.vue
/admin                            → Admin.vue
/admin/societa                    → Societa.vue
/form-iscrizione                  → FormOnlineIscrizione.vue (public, no auth)
```
**CRITICAL**: `/segreteria/scheda/:id` MUST be BEFORE `/segreteria/:id` in main.js.
**CRITICAL**: `/infermeria/infortunati` routes to `Infortunati.vue` (not `Infermeria.vue`).

## Environment
- `.env` at root: `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `SECRET_KEY`, `ENCRYPTION_KEY`, `DEFAULT_PASSWORD`
- `VITE_API_URL` is a Docker build ARG. Prod: `https://thof.crickethouse.mywire.org/api`, dev: `/api`
- **NEVER commit `.env`** files (root, `backend/.env`, `frontend/.env` all gitignored)

## Dev vs Prod
- **Local Dev**: `start_dev.sh` → tmux panes `registro_backend` / `registro_frontend`. Vite proxies `/api` and `/uploads` to `localhost:8000`. PG on 5433, socket `/tmp/pgsocket`, data in `/tmp/pgdata`.
- **Dev Server** (192.168.178.133): `deploy_dev.sh` → tar+ssh sync, build with `VITE_API_URL=/api`.
- **Prod** (192.168.178.132): `deploy.sh` → git fetch+reset, build --no-cache. External nginx on host. 4 uvicorn workers.

## Migrations
- **NO Alembic.** All migrations in `main.py:run_migrations()`, run on backend startup.
- `init.sql` seeds `gruppi` and `codici` tables.
- To add a new table/column: append idempotent block to `run_migrations()`.

## Architecture Gotchas
- **Multi-tenant**: every query filters by `societa_id` from the current user.
- **Portieri cross-category**: `is_portieri=1` categories read attendance across all categories.
- **Category hierarchy**: `parent_id` self-referencing FK on `categorie`. "Agonistica" and "Scuola Calcio" are parent groups. Under categories belong to Agonistica.
- **Catalogo esercizi visibility**: `visibilita` ('pubblico'/'societa') + `societa_id` for row-level filtering.
- **SchedaAllenamento**: GPS training metrics. Backend stats endpoints at `/schede-allenamento/stats/{trend|summary|team|player-trend}` accept `period` (week|month|season).
- **SchedaAllenamento charts**: Chart.js, dark theme, destroyed on unmount.

## Security
- `slowapi` limits are **per-worker** (4 workers = 4× effective limit).
- Public PII endpoints: `5/minute` rate limit + Pydantic validation.
- File uploads: magic bytes validation, max 5MB, controlled extensions.
- CORS: `thof.crickethouse.mywire.org`, `localhost:5173`, `localhost:3000`.
- pgcrypto AES encryption for CF, tel_papa, tel_mamma.

## ⚠️ Production Deploy Checklist
- **External nginx** on host proxies to containers.
- Frontend port: `0.0.0.0:3000:80` — **NEVER `127.0.0.1:3000:80`** (502 error).
- Backend port: `0.0.0.0:8000:8000` — must be `0.0.0.0`.
- Frontend changes require **full rebuild** (`docker compose build --no-cache`).
- Service Worker caches aggressively — users may need hard refresh (Ctrl+Shift+R).

## Conventions
- Italian language in UI and code.
- Roles: `super_admin` (all societies), `admin` (own society), `mister` (assigned categories), `dirigente` (read-only), `segreteria`, `infermeria`.
- No linting or type-checking configured.
- Tactical board logic: `composables/useTacticalBoard.js` + `components/TacticalBoard.vue`.

## Testing
- **No test suite.** Manual verification or logs:
  - Prod: `ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose logs -f"`
  - Dev: `ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 "cd /opt/registro_presenze && docker compose logs -f"`
