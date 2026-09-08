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
- `backend/app/main.py` — FastAPI entry, middleware, router mounts; calls `run_migrations()`
- `backend/app/migrations/run.py` — startup migrations, no Alembic
- `frontend/src/main.js` — app bootstrap only
- `frontend/src/core/router.js` — router, auth guard, all route registrations
- `frontend/src/store.js` — Global state (token, user, societa, categoria as Vue refs)
- `frontend/src/api/index.js` — barrel re-export of `frontend/src/core/api/*`

## Backend Structure
- `backend/app/core/` — `security.py`, `encryption.py`, `naming.py`, `deps.py`
- `backend/app/models/` — ORM models per dominio (`auth`, `societa`, `anagrafica`, `presenze`, `allenamenti`, `partite`, `segreteria`, `infermeria`)
- `backend/app/schemas/` — Pydantic schemas per dominio
- `backend/app/migrations/` — `run_migrations()` da `main.py`
- `backend/app/services/` — `email.py`, `invitations.py`, `oauth_google.py`
- `backend/app/routers/` — router flat, prefix API invariati

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

## Frontend Structure
- `frontend/src/core/router.js` — route e guard
- `frontend/src/core/api/` — `client.js`, `auth.js`, `admin.js`, `anagrafica.js`, `presenze.js`, `allenamenti.js`, `partite.js`, `segreteria.js`, `infermeria.js`, `inviti.js`, `public.js`
- `frontend/src/features/auth/` — Login, Registrazione, FormOnlineIscrizione
- `frontend/src/features/home/` — Home, Scelta
- `frontend/src/features/presenze/` — Registro
- `frontend/src/features/allenatori/` — Allenatori, Responsabili, ResponsabiliCategoria, PresenzeAllenatori
- `frontend/src/features/partite/` — ProgrammazionePartite, Convocazioni, ListeTornei, Spogliatoi
- `frontend/src/features/allenamenti/` — Allenamenti, SchedaAllenamento
- `frontend/src/features/segreteria/` — Segreteria, SegreteriaCategoria, SchedaGiocatore, Openday, PresenzeSegreteria, Valutazioni, DatiMatricole
- `frontend/src/features/infermeria/` — Infermeria, CertificatoMedico, Infortunati
- `frontend/src/features/reportistica/` — Reportistica
- `frontend/src/features/admin/` — Admin, Societa

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
**CRITICAL**: `/segreteria/scheda/:id` MUST be BEFORE `/segreteria/:id` in `frontend/src/core/router.js`.
**CRITICAL**: `/infermeria/infortunati` routes to `Infortunati.vue` (not `Infermeria.vue`).

## Environment
- `.env` at root: `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `SECRET_KEY`, `ENCRYPTION_KEY`, `DEFAULT_PASSWORD`
- `VITE_API_URL` is a Docker build ARG. Prod: `https://thof.crickethouse.mywire.org/api`, dev: `/api`
- **NEVER commit `.env`** files (root, `backend/.env`, `frontend/.env` all gitignored)

## Dev vs Prod
- **Local Dev**: `start_dev.sh` → tmux panes `registro_backend` / `registro_frontend`. Vite proxies `/api` and `/uploads` to `localhost:8000`. PG on 5433, socket `/tmp/pgsocket`, data in `/tmp/pgdata`.
- **Dev Server** (192.168.178.133): `deploy_dev.sh` → tar+ssh sync, build with `VITE_API_URL=/api`. **Il server ha accesso a internet** (la vecchia nota "senza internet" è obsoleta), ma la strategia tar resta valida.
- **Prod** (192.168.178.132): `deploy.sh` → git fetch+reset, build --no-cache. External nginx on host. 4 uvicorn workers.

## Git & GitHub
- **Autenticazione**: HTTPS + token, memorizzato in `~/.git-credentials` (chmod 600, `credential.helper store`). **Mai** incorporare token negli URL dei remote (vedi hardening).
- L'accesso SSH verso GitHub (porte 22/443) è **bloccato** dalla rete: usare HTTPS+token.
- Remote `origin` e `github` puntano entrambi a `github.com/andmor8277/registro-attivit-.git`. `deploy.sh` (prod) e i push partono da `origin/master`.

## Migrations
- **NO Alembic.** All migrations in `backend/app/migrations/run.py:run_migrations()`, run on backend startup.
- `init.sql` seeds `gruppi` and `codici` tables.
- To add a new table/column: append idempotent block to `run_migrations()`.

## Architecture Gotchas
- **Multi-tenant**: every query filters by `societa_id` from the current user. Resource with `societa_id` enforceable by convention — `Allenatore` ora ha `societa_id` (migrato) e rispetta il filtro multi-tenant.
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
- `slowapi==0.1.9`, `passlib[bcrypt]==1.7.4` + `bcrypt==4.0.1` sono **pinati apposta** (compatibilità nota: passlib rompe con bcrypt ≥4.1; slowapi è legato alla vecchia starlette). Non alzare queste versioni senza test.
- backend deps aggiornate (2026-02): fastapi 0.115, sqlalchemy 2.0.43, pydantic 2.11, uvicorn 0.34.

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
- Tactical board logic: `components/TacticalBoard.vue`.

## Testing
- **No test suite.** Manual verification or logs:
  - Prod: `ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose logs -f"`
  - Dev: `ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 "cd /opt/registro_presenze && docker compose logs -f"`
