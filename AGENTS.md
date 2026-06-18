# AGENTS.md — The Home of Football (THOF)

## Panoramica
Sistema di gestione multi-società per società sportive dilettantistiche (calcio).
- **Dev server**: 192.168.178.133 (root, key `~/.ssh/id_ed25519_dev`)
- **Prod server**: 192.168.178.132 (root, key `~/.ssh/id_ed25519_prod`)
- **URL prod**: https://thof.crickethouse.mywire.org
- **Path remoto**: `/opt/registro_presenze/` (bare repo: `/opt/registro_presenze.git`)
- **Versione attiva**: v5.1.0

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
backend/app/routers/         # 16 routers (vedi sotto)
backend/app/database.py      # SessionLocal, reads DATABASE_URL from env
backend/app/models.py        # SQLAlchemy models (18+ classi)
backend/app/schemas.py       # Pydantic schemas
backend/app/rate_limit.py    # slowapi limiter (in-memory, per-worker)
backend/uploads/             # File uploads, served at /uploads/

frontend/src/main.js         # Router, auth guard, all route registrations
frontend/src/views/          # 19+ views
frontend/src/api/index.js    # Axios instance (api + apiPublic), all API calls
frontend/src/store.js        # Global state: token, user, societa, categoria (Vue refs)
frontend/src/composables/useTacticalBoard.js  # Tactical board logic
frontend/src/components/TacticalBoard.vue     # Tactical board canvas component
frontend/nginx.conf          # Proxies /api/ and /uploads/ to backend:8000
frontend/vite.config.js      # Dev proxy to localhost:8000, PWA config
```

## Backend Routers (16)
| Router | Prefix | Auth | Descrizione |
|--------|--------|------|-------------|
| `auth.py` | `/auth` | vari | Login, JWT, utenti CRUD, reset password, categorie utente |
| `societa.py` | `/societa` | admin | Multi-società CRUD, upload logo/sponsor |
| `persone.py` | `/persone` | vari | Giocatori CRUD, cifratura pgcrypto, endpoint pubblici |
| `registro.py` | `/registro` | login | Presenze mensili, codici (X/P/R/A/AG/AI), readthrough portieri |
| `codici.py` | `/codici` | login | Codici presenza CRUD |
| `categorie.py` | `/categorie` | login | Categorie CRUD, stagioni, archiviazione, import giocatori |
| `convocazioni.py` | `/convocazioni` | login | Convocazioni con gare e giocatori, PDF export |
| `allenatori.py` | `/allenatori` | login | Allenatori CRUD |
| `allenamenti.py` | `/allenamenti` | login | Lavagna tattica, catalogo esercizi, mese/settimana/giorno |
| `gruppi.py` | `/gruppi` | login | Gruppi per categoria (es. "Portieri") |
| `partite.py` | `/partite` | login | Partite CRUD, link con weekend |
| `weekend.py` | `/weekend` | login | Weekend gare CRUD, partite associate |
| `spogliatoi.py` | `/spogliatoi` | login | Spogliatoi + assegnazioni (giorno/settimana/weekend) |
| `campi.py` | `/campi` | login | Campi da gioco + assegnazioni (come spogliatoi) |
| `presenze_allenatori.py` | `/presenze-allenatori` | login | Presenze mister, lista mister con giorni |
| `valutazioni.py` | `/valutazioni` | login | Valutazioni giocatori (tecnica, velocità, ecc.) |
| `infortuni.py` | `/infortuni` | login | Infortuni CRUD, attivi/scaduti, chiusura, storico |

## Modelli DB (19+ tabelle)
- `societa` — multi-tenant (nome, logo, colori)
- `categorie` — anno, stagione, giorni, ora_allenamento, is_portieri, is_archiviata
- `gruppi` — sottogruppi per categoria
- `persone` — giocatori, dati cifrati (CF, tel_papa, tel_mamma con pgcrypto AES)
- `utenti` + `utente_categorie` — autenticazione, ruoli, assegnazioni
- `registro` — presenze con codici
- `codici` — codici presenza (X, P, R, A, AG, AI)
- `convocazioni` + `convocazione_gare` + `convocazione_giocatori`
- `allenatori`
- `allenamenti` + `allenamenti_mese` + `allenamenti_settimana` + `allenamenti_giorno` + `allenamenti_esercizio` + `allenamenti_elemento`
- `catalogo_esercizi` — esercizi riutilizzabili con elementi JSONB
- `partite` — partite con weekend_id, casa/fuori, risultati
- `weekend` — weekend gare con date
- `spogliatoi` + `spogliatoi_assegnazioni` — gestione spogliatoi
- `campi_da_gioco` + `campi_assegnazioni` — gestione campi
- `presenze_allenatori` — presenze mister
- `valutazioni` — tecnica, velocità, resistenza, attitudine, posizione, gioco_di_testa, tiro, passaggio, dribbling, disciplina
- `infortuni` — persona_id, categoria_id, societa_id, data_inizio, giorni_assenza, data_fine (auto-calcolata), tipo_infortunio, note, creato_il

## Route Map (Frontend)
```
/login              → Login.vue
/                   → Home.vue (dashboard)
/allenatori         → Allenatori.vue (planning + categories CRUD)
/responsabili       → Responsabili.vue
/responsabili/categorie → ResponsabiliCategoria.vue
/responsabili/partite → ProgrammazionePartite.vue
/segreteria         → Segreteria.vue (category overview with stats)
/segreteria/scheda/:id → SchedaGiocatore.vue (player detail)
/segreteria/:id     → SegreteriaCategoria.vue (per-category player table)
/scelta/:id         → Scelta.vue (action picker per category)
/registro/:id       → Registro.vue (attendance)
/allenamenti/:id    → Allenamenti.vue (uses TacticalBoard.vue)
/convocazioni/:id   → Convocazioni.vue
/dati/:id           → DatiMatricole.vue
/reportistica/:id   → Reportistica.vue
/admin              → Admin.vue (user CRUD, encryption key)
/admin/societa      → Societa.vue (multi-society management)
/infermeria          → Infermeria.vue (hub certificati + infortuni)
/infermeria/certificati → CertificatoMedico.vue
/infermeria/infortunati → Infortunati.vue (DB-backed, attivi + storico)
/form-iscrizione    → FormOnlineIscrizione.vue (public, no auth)
```
**Attenzione**: `/segreteria/scheda/:id` DEVE essere PRIMA di `/segreteria/:id`.
**Non ancora instradate**: `Spogliatoi.vue`, `PresenzeAllenatori.vue` esistono ma potrebbero non avere route.
**Route fissa**: `/infermeria/infortunati` punta a `Infortunati.vue` (non `Infermeria.vue`).

## Environment
- `.env` at root: `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `SECRET_KEY`, `ENCRYPTION_KEY`, `DEFAULT_PASSWORD`
- `VITE_API_URL` è un Docker build ARG. Default prod: `https://thof.crickethouse.mywire.org/api`, dev: `/api`
- **Mai commitare `.env`** (root, `backend/.env`, `frontend/.env` sono tutti gitignored)

## Dev vs Prod
- **Local Dev**: `start_dev.sh` → tmux `registro_backend` / `registro_frontend`. Vite proxy `/api` e `/uploads` a `localhost:8000`. PG su 5433, socket `/tmp/pgsocket`, data in `/tmp/pgdata`.
- **Local Dev DB sync**: dump da prod (192.168.178.132) solo al primo avvio (tabella `persone` vuota).
- **Dev Server** (192.168.178.133): `deploy_dev.sh` → tar+ssh sync. Build con `VITE_API_URL=/api`. SSH key: `~/.ssh/id_ed25519_dev`.
- **Prod** (192.168.178.132): `deploy.sh` → git fetch+reset, build --no-cache. Nginx esterno su host. 4 worker uvicorn.
- **Cambiamenti frontend richiedono rebuild completo** — `dist/` nel container nginx.

## Migrations
- **Niente Alembic.** Auto-migrazioni in `main.py:run_migrations()` ad ogni avvio backend.
- `init.sql` seeda `gruppi` e `codici` al primo init DB.
- Nuove migrazioni: aggiungi a `run_migrations()` in `main.py`.

## Security
- `slowapi` limits sono **per-worker** (4 worker = 4x limite effettivo).
- Endpoint pubblici PII: `5/minute` rate limit + validazione Pydantic.
- Upload file: validazione magic bytes, max 5MB, estensioni controllate.
- CORS: `thof.crickethouse.mywire.org`, `localhost:5173`, `localhost:3000`.
- Header: CSP, HSTS, X-Frame-Options DENY, X-Content-Type-Options, Permissions-Policy.
- Cifratura pgcrypto AES per CF, tel_papa, tel_mamma.

## Testing
- **Nessuna test suite.** Verifica manuale o log:
  - Prod: `ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose logs -f"`
  - Dev: `ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 "cd /opt/registro_presenze && docker compose logs -f"`

## Conventions
- Lingua italiana in UI e codice.
- Ruoli: `super_admin` (tutte società), `admin` (propria società), `mister` (categorie assegnate), `dirigente` (read-only), `segreteria`, `infermeria`.
- Nessun linting o type-checking configurato.
- Logica lavagna tattica in `composables/useTacticalBoard.js` + `components/TacticalBoard.vue`.
- `Infermeria.vue` NON esiste ancora — card in Home.vue è commentata.
- `Infortunati.vue` è ora DB-backed (tabella `infortuni`), non più localStorage. `data_fine` calcolata automaticamente.
- `release.sh` referencia `dev.sh` (riga 77) che non esiste → dovrebbe essere `start_dev.sh`.

## ⚠️ Production Deploy Checklist

### Nginx Esterno Critico
**Prod ha nginx ESTERNO sull'host che proxy verso i container.**
- Frontend: `0.0.0.0:3000:80` — **MAI usare `127.0.0.1:3000:80`** (nginx esterno non raggiunge → 502)
- Backend: `0.0.0.0:8000:8000` — deve essere `0.0.0.0` non `127.0.0.1`
- Verifica: `curl -s -o /dev/null -w '%{http_code}' http://192.168.178.132:3000/` → 200

### Cambiamenti Frontend
- Richiedono **rebuild completo** (`docker compose build --no-cache`) — `dist/` nel container nginx
- Service Worker fa cache aggressiva — utenti potrebbero bisogno di hard refresh (Ctrl+Shift+R)

## Funzionalità Principali
- **Multi-società** con isolamento dati completo per società
- **Registro presenze** con codici (X presente, P permesso, R recupero, A assente, AG assente giustificato, AI infortunio)
- **Portieri cross-category**: categoria speciale `is_portieri=1`, presenze lette attraverso tutte le categorie
- **Lavagna tattica**: campo da calcio, 3 set oggetti sportivi, 5 tipi frecce, catalogo esercizi riutilizzabili
- **Convocazioni**: multi-gara, griglia 7 colonne, player picker, PDF export editorial style
- **Weekend gare**: sidebar weekend, convocazione da weekend con partite pre-caricate
- **Spogliatoi/Campi**: assegnazioni per giorno, settimana, o weekend
- **Valutazioni giocatori**: 10 parametri (tecnica, velocità, resistenza, attitudine, posizione, gioco_di_testa, tiro, passaggio, dribbling, disciplina)
- **Infortuni**: registro persistente in DB, `data_fine` auto-calcolata da `data_inizio + giorni_assenza`, infortunio attivo finché `data_fine >= oggi`, storico permanente, chiusura manuale anticipata
- **Presenze allenatori**: tracking presenze mister con codici
- **Form preiscrizione online**: endpoint pubblici senza auth, link precompilati
- **Sistema pagamenti**: totale, iscrizione, rate 1-4, saldo, calcolo automatico
- **Scheda giocatore**: vista completa con stampa PDF
- **Stagioni calcistiche**: impostazione, archiviazione, ripristino
- **GDPR**: dati sensibili cifrati, protezione con password per visualizzazione
