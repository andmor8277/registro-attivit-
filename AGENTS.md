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
./start_dev.sh                     # Local dev: PG (5433) + uvicorn (8000) + vite (5173) via tmux
./deploy_dev.sh                    # Dev (192.168.178.133): sync + build + test su DEV prima di prod
./deploy.sh                        # Prod (192.168.178.132): SOLO dopo aver testato su dev: git fetch → build --no-cache → up
./release.sh minor "desc"          # Tag + commit + copy to releases/vX.X.X/
./scripts/build_android_apk.sh      # Compila l'APK Android (Capacitor + Docker) in releases/apk/ (a build riuscita pubblica su GitHub; --no-publish per saltarla)
./scripts/publish_android_apk.sh    # Pubblica l'APK su GitHub Releases (andmor8277/thof-releases): da lì l'app legge l'avviso di aggiornamento
./scripts/backup_offsite_github.sh  # Backup offsite cifrato AES-256 (DB + uploads) su GitHub privato
./scripts/restore_offsite_github.sh # Disaster Recovery / ripristino da backup GitHub
./scripts/setup_backup_cron.sh      # Installa cron job automatico notturno (ore 03:00)
./sync_to_usb.sh                    # Sincronizza il progetto sulla chiavetta USB (anche auto al commit)
./aggiorna_progetto.sh              # Aggiorna il progetto all'ultimo commit (da GitHub o da USB se offline)
./scripts/clone_from_usb.sh         # Inizializza/clona il progetto da USB su una nuova postazione
./scripts/realigna_cloni.sh         # Riallinea i cloni DEV/PROD alla storia git riscritta (fetch forzato + reset + gc)
./scripts/ops/ruota_segreti.sh dev|prod  # Ruota SECRET_KEY + DEFAULT_PASSWORD con prova prima/dopo (vuole il backup del .env gia' fatto)
./scripts/ops/gen_passphrase.sh     # Passphrase comunicabile per DEFAULT_PASSWORD (5 parole + 3 cifre, ~44 bit)
./scripts/ops/confronta_env.sh      # Confronta i segreti DEV<->PROD per hash, senza stamparli
./scripts/ops/run_suite_dev.sh      # Esegue tutta la suite DEV e somma le asserzioni
```

## Flusso di Lavoro Obbligatorio (Dev-First)
1. **Modifiche al codice**: implementazione locale.
2. **Deploy su DEV** (`./deploy_dev.sh`): build e riavvio container su DEV (192.168.178.133).
3. **Test e Validazione su DEV**: test di funzionamento su `http://192.168.178.133:3000` e verifica log / endpoint.
4. **Commit & Push su Git**: dopo esito positivo dei test.
5. **Autorizzazione Utente & Deploy su PROD** (`./deploy.sh`): promozione in produzione su `https://thof.crickethouse.mywire.org` SOLO dopo autorizzazione esplicita.
⚠️ **REGOLA ASSOLUTA**: MAI rilasciare modifiche direttamente su Prod senza averle prima caricate e verificate su Dev!
⚠️ **REGOLA AUTORIZZAZIONE PROD**: MAI eseguire il deploy su PROD (`./deploy.sh`) in automatico o di propria iniziativa. Chiedere SEMPRE prima l'esplicita autorizzazione all'utente!
⚠️ **REGOLA DATABASE DEV**: NON sincronizzare o sovrascrivere MAI il database di DEV con i dati di PROD. L'ambiente DEV deve mantenere il proprio database indipendente. Il deploy su DEV (`./deploy_dev.sh`) aggiorna solo il codice sorgente ed esegue le migrazioni DDL senza toccare i dati.


## Entry Points
- `backend/app/main.py` — FastAPI entry, middleware, router mounts; calls `run_migrations()`
- `backend/app/migrations/run.py` — startup migrations, no Alembic
- `frontend/src/main.js` — app bootstrap only
- `frontend/src/core/router.js` — router, auth guard, all route registrations
- `frontend/src/store.js` — Global state (token, user, societa, categoria as Vue refs)
- `frontend/src/api/index.js` — barrel re-export of `frontend/src/core/api/*`
- `frontend/src/core/appUpdate.js` — update checker dell'APK (GitHub Releases + fallback `version.json`); UI in `frontend/src/components/AppUpdateNotice.vue`, montato in `App.vue`. Solo nativo: il web usa `versionCheck.js`

## Backend Structure
- `backend/app/core/` — `security.py`, `encryption.py`, `naming.py`, `deps.py`
- `backend/app/models/` — ORM models per dominio (`auth`, `societa`, `anagrafica`, `presenze`, `allenamenti`, `partite`, `segreteria`, `infermeria`)
- `backend/app/schemas/` — Pydantic schemas per dominio
- `backend/app/migrations/` — `run_migrations()` da `main.py`
- `backend/app/services/` — `email.py`, `invitations.py`, `oauth_google.py`
- `backend/app/routers/` — router flat, prefix API invariati

## Backend Routers (23)
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
| `scouting.py` | `/scouting` | login (creazione: mister/admin; valutazione/stato: scouting/admin) |
| `inviti.py` | `/inviti` | admin (creazione/lista/elimina/rinvia); `GET /verifica/{token}` pubblico |
| `liste_tornei.py` | `/liste-torneo` | login |

## Frontend Structure
- `frontend/src/core/router.js` — route e guard
- `frontend/src/core/api/` — `client.js`, `auth.js`, `admin.js`, `anagrafica.js`, `presenze.js`, `allenamenti.js`, `partite.js`, `segreteria.js`, `infermeria.js`, `scouting.js`, `inviti.js`, `public.js`
- `frontend/src/features/auth/` — Login, Registrazione, FormOnlineIscrizione
- `frontend/src/features/home/` — Home, Scelta
- `frontend/src/features/presenze/` — Registro
- `frontend/src/features/allenatori/` — Allenatori, Responsabili, ResponsabiliCategoria, PresenzeAllenatori
- `frontend/src/features/partite/` — ProgrammazionePartite, Convocazioni, ListeTornei, Spogliatoi
- `frontend/src/features/allenamenti/` — Allenamenti, SchedaAllenamento
- `frontend/src/features/segreteria/` — Segreteria, SegreteriaCategoria, SchedaGiocatore, Openday, PresenzeSegreteria, Valutazioni, DatiMatricole
- `frontend/src/features/infermeria/` — Infermeria, CertificatoMedico, Infortunati
- `frontend/src/features/scouting/` — Scouting
- `frontend/src/features/reportistica/` — Reportistica
- `frontend/src/features/admin/` — Admin, Societa

## DB Models (27)
`Societa`, `Categoria` (+`parent_id` self-referencing FK), `Gruppo`, `Persona`, `CodicePresenza`, `Registro`, `Utente`, `UtenteCategoria`, `Convocazione`, `ConvocazioneGara`, `ConvocazioneGiocatore`, `Allenatore`, `Allenamento`, `AllenamentoMese`, `AllenamentoSettimana`, `AllenamentoGiorno`, `AllenamentoEsercizio`, `AllenamentoElemento`, `PresenzaAllenatore`, `CatalogoEsercizio`, `Valutazione`, `Infortunio`, `Openday`, `PlanningEvento`, `SchedaAllenamento`, `ScoutingSegnalazione`, `ScoutingGiocatore`

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
/liste-tornei/:id                 → ListeTornei.vue
/dati/:id                         → DatiMatricole.vue
/reportistica/:id                 → Reportistica.vue
/segreteria                       → Segreteria.vue
/segreteria/scheda/:id            → SchedaGiocatore.vue (player detail)
/segreteria/:id                   → SegreteriaCategoria.vue
/segreteria/openday               → Openday.vue
/segreteria/presenze              → PresenzeSegreteria.vue
/valutazioni/:id                  → Valutazioni.vue
/infermeria                       → Infermeria.vue (hub)
/infermeria/certificati           → CertificatoMedico.vue
/infermeria/infortunati           → Infortunati.vue
/scouting                         → Scouting.vue
/admin                            → Admin.vue
/admin/societa                    → Societa.vue
/form-iscrizione                  → FormOnlineIscrizione.vue (public, no auth)
/registrazione                    → Registrazione.vue (public, no auth)
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
- Remote `origin` punta a `github.com/andmor8277/registro-attivit-.git` ed è l'unico remoto (il duplicato `github` è stato rimosso perché non veniva mai aggiornato). `master` traccia `origin/master`: `deploy.sh` (prod) e i push partono da lì.
- **Rilasci Android**: repo pubblico `github.com/andmor8277/thof-releases` (non questo repo). L'app legge le sue Release API, con fallback su `version.json` raw quando le API sono in rate limit (60 req/ora per IP). Lo scrive solo `scripts/publish_android_apk.sh`: non modificarlo a mano. Il `versionCode` è il numero di commit, il `versionName` il tag: a parità di tag è il `versionCode` a decidere se l'app chiede l'aggiornamento. La Release API non ha un campo versionCode, quindi `publish_android_apk.sh` lo scrive anche nel body della release come commento HTML `<!-- thof-versionCode: NNN -->` (invisibile sulla pagina, leggibile dall'API) e in `version.json`: non cancellare quel commento, senza di esso le rebuild sotto lo stesso tag non vengono annunciate. Il build number reale è anche nel sidecar `releases/apk/thof.apk.build` scritto da `build_android_apk.sh`.
- **Cache del fallback**: `raw.githubusercontent.com` ignora la query stringa nella chiave di cache (`cache-control: max-age=300`), quindi dopo una pubblicazione `version.json` può restare vecchio fino a ~5 minuti. Conseguenza pratica: **non cancellare una release subito dopo averla pubblicata**, perché il manifest in cache punterebbe ancora al suo asset, ormai 404. Per verificare il manifest reale, attendere la scadenza della cache e controllare senza parametri.
- **Storia riscritta il 2026-11-13** con `git filter-repo`: rimossi da tutti i commit `frontend/android/app/thof-release.keystore`, `frontend/mock-server.js` e la password di firma in chiaro. Gli SHA precedenti non esistono piu: i cloni vecchi (DEV, PROD, altre postazioni) vanno riallineati con `git fetch --prune origin '+refs/heads/*:refs/remotes/origin/*' && git reset --hard origin/master` o ri-clonati. Backup della storia pre-riscrittura in `.local/backup-pre-history-rewrite/`.
- **Keystore di firma esposto, rischio accettato dal titolare (2026-11-13)**: la chiave e' rimasta pubblica dal 25/09 al 13/11 e **non viene ruotata**, per non rompere gli aggiornamenti in place degli APK gia installati. Non re-introdurla mai in git: credenziali solo in `frontend/android/keystore.properties` (ignorato) o env `THOF_KEYSTORE_*`. Copia di sicurezza in `.local/backup-pre-history-rewrite/`.

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
- Firma APK: credenziali in `frontend/android/keystore.properties` (gitignored; template `keystore.properties.example`) o env `THOF_KEYSTORE_*`. Mai in chiaro in `build.gradle`. Senza credenziali il debug usa il keystore standard di Gradle, `assembleRelease` fallisce di proposito.
- `deploy_dev.sh` e `frontend/.dockerignore` escludono keystore, `.env*`, `.local/`, `client_secret_*.json`: non devono mai finire su DEV né dentro l'immagine frontend.
- `slowapi` limits are **per-worker** (4 workers = 4× effective limit).
- **Ordine decorator del limiter (NON invertire)**: `@router.get(...)` deve stare FUORI, `@limiter.limit(...)` VICINO alla funzione.
  ```python
  @router.post("/token")        # esterno: registra nella rotta la funzione GIA' avvolta
  @limiter.limit("10/minute")   # interno
  def login(request: Request, ...):
  ```
  Con `@limiter.limit` sopra, i decorator si applicano dal basso e FastAPI registra nella rotta la funzione **non avvolta**: il limite non viene mai eseguito, in silenzio. Succedeva davvero su `auth.py` login e reset-password (verificato: 30 POST su `/auth/token`, zero 429; persone.py era invece corretto e lì il 429 arrivava). Dimostrato con test isolato nelle stesse versioni di produzione.
- **`--forwarded-allow-ips` non deve essere `*`**: con `*` uvicorn crede a `X-Forwarded-For` da chiunque. openresty (sul router) **accorpa** l'header invece di sostituirlo, quindi l'attaccante si attribuisce un IP fittizio a ogni richiesta e aggira ogni rate limit. Fidati solo di `127.0.0.1,172.16.0.0/12`. Questo chiude il percorso diretto su `:8000`; il percorso proxy resta aggirabile finche' openresty non fa `proxy_set_header X-Forwarded-For $remote_addr` (sostituzione) — oppure finche' il login non ha un blocco per username indipendente dall'IP.
- **Documentazione API disattivata** in `main.py` (`docs_url=None, redoc_url=None, openapi_url=None`): prima `/api/docs`, `/api/openapi.json` e `/api/redoc` rispondevano 200 pubblici, cioe' la mappa completa dell'API a internet.
- **APK**: `network_security_config.xml` fida solo le CA di sistema e vieta il cleartext (`"cleartext": false` in `capacitor.config.json`). Non riabilitare `src="user"`: espone l'HTTPS (JWT e anagrafiche dei minori) a qualsiasi certificato radice installato sul telefono.
- **`ENCRYPTION_KEY` NON si ruota a mano**: e' la chiave pgcrypto di CF e telefoni; cambiarla rende illeggibili i dati gia' cifrati. Usare `POST /persone/reencrypt` con `reencrypt=True` (solo super_admin). `SECRET_KEY` e `DEFAULT_PASSWORD` si possono invece ruotare (sloggano solo le sessioni) con `scripts/ops/ruota_segreti.sh dev|prod`: genera i valori **sul server**, non li stampa e si rifiuta di partire senza backup del `.env` gia' esistente. Dopo la modifica del `.env` serve **`docker compose up -d`**, non basta `restart`: la compose passa le variabili con `environment: ${VAR}`, quindi il valore viene fissato alla **creazione** del container. Su PROD la compose va invocata con **`-f docker-compose.yml -f docker-compose.prod.yml`**, altrimenti si rialza con i settings sbagliati. `SECRET_KEY` **non deve mai essere lo stesso valore su DEV e PROD**: condividendo la chiave, un JWT coniato su DEV e' accettato da PROD. Verifica con `scripts/ops/confronta_env.sh`
- **`authlib` rimossa** da `requirements.txt`: era dichiarata ma mai importata, e portava ~20 CVE nell'immagine.
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
- Version Checker automatico attivo (`versionCheck.js` + `version.json` generato da Vite): ricarica automatica al cambio versione senza bisogno di refresh manuale né Service Worker (i vecchi SW vengono deregistrati automaticamente).

## Conventions
- Italian language in UI and code.
- Roles: `super_admin` (all societies), `admin` (own society), `mister` (assigned categories), `dirigente` (read-only), `segreteria`, `infermeria`, `scouting`.
- No linting or type-checking configured.
- Tactical board logic: `components/TacticalBoard.vue`.

## Testing
- **No test suite.** Manual verification or logs:
  - Prod: `ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose logs -f"`
  - Dev: `ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 "cd /opt/registro_presenze && docker compose logs -f"`
