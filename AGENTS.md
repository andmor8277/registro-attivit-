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
./scripts/ops/cifra_cf.sh dev|prod [--applica]  # Cifra i CF rimasti in chiaro su persone: backup verificato -> dry-run -> (solo con --applica) scrittura -> test. Senz'altro non scrive nulla
./scripts/ops/verifica_worker_riavvio.sh dev [drop] [cicli]  # Riavvia il backend N volte (con drop delle tabelle tornei) e asserisce che nessun worker muore: e' la prova della corsa di create_all
./scripts/ops/gen_passphrase.sh     # Passphrase comunicabile per DEFAULT_PASSWORD (5 parole + 3 cifre, ~44 bit)
./scripts/ops/confronta_env.sh      # Confronta i segreti DEV<->PROD per hash, senza stamparli
./scripts/ops/silenzia_mail_prove.sh dev|prod [--dry-run]  # Fa scartare a postfix i destinatari di prova (x.local, test.local, example.com) invece di smistarli alla Gmail: senza, ogni suite DEV lascia due bounce "Indirizzo non trovato" nella casella del titolare
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

## Backend Routers (24)
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
| `liste_tornei.py` | `/liste-torneo` | login (letture: tutti i ruoli; scritture: admin/`mister`/`segreteria`; cancellazione lista: solo admin) |
| `tornei.py` | `/tornei` | login (letture: tutti i ruoli della societa'; tornei, gare e iscrizioni categorie: solo admin/super_admin) |

## Frontend Structure
- `frontend/src/core/router.js` — route e guard
- `frontend/src/core/api/` — `client.js`, `auth.js`, `admin.js`, `anagrafica.js`, `presenze.js`, `allenamenti.js`, `partite.js`, `segreteria.js`, `infermeria.js`, `scouting.js`, `inviti.js`, `public.js`
- `frontend/src/features/auth/` — Login, Registrazione, FormOnlineIscrizione
- `frontend/src/features/home/` — Home, Scelta
- `frontend/src/features/presenze/` — Registro
- `frontend/src/features/allenatori/` — Allenatori, Responsabili, ResponsabiliCategoria, PresenzeAllenatori
- `frontend/src/features/partite/` — ProgrammazionePartite, Convocazioni, ListeTornei, Spogliatoi, Tornei
- `frontend/src/features/allenamenti/` — Allenamenti, SchedaAllenamento
- `frontend/src/features/segreteria/` — Segreteria, SegreteriaCategoria, SchedaGiocatore, Openday, PresenzeSegreteria, Valutazioni, DatiMatricole
- `frontend/src/features/infermeria/` — Infermeria, CertificatoMedico, Infortunati
- `frontend/src/features/scouting/` — Scouting
- `frontend/src/features/reportistica/` — Reportistica
- `frontend/src/features/admin/` — Admin, Societa

## DB Models (33)
`Societa`, `Categoria` (+`parent_id` self-referencing FK), `Gruppo`, `Persona`, `CodicePresenza`, `Registro`, `Utente`, `UtenteCategoria`, `Invito`, `Convocazione`, `ConvocazioneGara`, `ConvocazioneGiocatore`, `Torneo` (+`categoria_id` nullable = la "prima" categoria iscritta), `TorneoCategoria` (l'iscrizione categoria↔torneo: `UNIQUE (torneo_id, categoria_id)`, la vera fonte delle categorie di un torneo), `TorneoGara` (+`categoria_id` nullable), `ListaTorneo` (+`torneo_id` nullable, UNIQUE parziale: un foglio per `(torneo_id, categoria_id)`), `ListaTorneoGiocatore`, `Allenatore`, `Allenamento`, `AllenamentoMese`, `AllenamentoSettimana`, `AllenamentoGiorno`, `AllenamentoEsercizio`, `AllenamentoElemento`, `PresenzaAllenatore`, `CatalogoEsercizio`, `Valutazione`, `Infortunio`, `Openday`, `PlanningEvento`, `SchedaAllenamento`, `ScoutingSegnalazione`, `ScoutingGiocatore`

## Route Map
```
/login                            → Login.vue
/                                 → Home.vue (dashboard)
/allenatori                       → Allenatori.vue (categories CRUD, accordion parent/child)
/responsabili                     → Responsabili.vue
/responsabili/categorie           → ResponsabiliCategoria.vue
/responsabili/partite             → ProgrammazionePartite.vue
/responsabili/spogliatoi          → Spogliatoi.vue
/responsabili/tornei              → Tornei.vue (Programmazione Tornei; admin/super_admin)
/responsabili/presenze-allenatori → PresenzeAllenatori.vue
/scelta/:id                       → Scelta.vue (action picker per category)
/registro/:id                     → Registro.vue (attendance calendar)
/allenamenti/:id                  → Allenamenti.vue (tactical board, catalog)
/scheda-allenamento/:id           → SchedaAllenamento.vue (GPS metrics dashboard + table)
/convocazioni/:id                 → Convocazioni.vue
/liste-tornei/:id                 → ListeTornei.vue
/tornei/:id                       → Tornei.vue (stessa componente di /responsabili/tornei: "Convocazioni Tornei" per i mister, in sola lettura perche' il livello di modifica lo decide il ruolo e non la rotta)
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
- **Dev Server** (192.168.178.133): `deploy_dev.sh` → tar+ssh sync, build with `VITE_API_URL=/api`. **Il server ha accesso a internet** (la vecchia nota "senza internet" è obsoleta), ma la strategia tar resta valida. Dopo il sync allinea anche il clone DEV al commit deployato (`fetch` + `reset --hard`), perche' il tar esclude `.git` e un clone che rinvecchia rende `git status` bugiardo e un `git reset` di manutenzione riporterebbe i file a una versione vecchia. **Si ferma da solo se il working tree locale e' sporco**: in quel caso i file copiati non sono nel commit target e il reset disferebbe in silenzio il deploy appena fatto; il deploy prosegue e viene detto perche' non ha allineato
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
- **Tornei non usano la tabella `partite`**: il calendario dei tornei sta in `tornei_gare`. `partite` e' impastata con `weekend_id`, `risultato`, `goal_punti`, `mister_id` e `convocazioni.py` la interroga con `WHERE categoria_id AND data_partite` per generare le convocazioni: mischiarci le gare di torneo falserebbe il calendario di campionato e la generazione automatica. `ora`/`ora_appuntamento` sono `VARCHAR(20)` e non TIME, come `ConvocazioneGara.appuntamento`, per registrare l'orario cosi' come l'organizzatore lo comunica
- **Un torneo iscrive N categorie, e il foglio da consegnare e' uno per categoria**: la verita' sta in `tornei_categorie`, **non** in `tornei.categoria_id`, che e' rimasta come "prima categoria" solo per il badge della card, il filtro e l'ingresso da Scelta.vue. `POST /tornei` accetta `categorie_id` (lista) e continua ad accettare `categoria_id` (singolo) per retrocompatibilita'; `POST /tornei/{id}/categorie` iscrive dopo e `DELETE /tornei/{id}/categorie/{cid}` scioglie. `PUT /tornei/{id}` **ignora le categorie di proposito**: rimuoverne una significa gestire il foglio di quella categoria, che puo' avere giocatori dentro, e quella decisione ha una rotta e una regola sue. Il filtro `GET /tornei/?categoria_id=` usa `EXISTS` su `tornei_categorie`: filtrare su `tornei.categoria_id` mostrerebbe al mister della seconda categoria un torneo inesistente
- **La categoria della gara di torneo non si deduce quando le iscritte sono piu' d'una**: `tornei_gare.categoria_id` e' nullable solo per non farla scegliere ogni volta a chi ha un torneo mono-categoria. Con due o piu' iscritte, una richiesta senza `categoria_id` riceve **400** invece di vedersene assegnata una a caso: finirebbe nel foglio sbagliato, cioe' si consegnerebbe all'organizzatore un calendario plausibile e falso
- **La Lista Tornei nasce col torneo** (`POST /tornei` crea torneo + un foglio per categoria nello stesso transaction, `liste_torneo` UNIQUE parziale su `(torneo_id, categoria_id)`): se dipendesse da un passaggio manuale del mister il file da consegnare non verrebbe prodotto (in produzione, in due anni, di liste ce n'era **una**). Cancellare il torneo si porta dietro i suoi fogli; le liste create a mano (`torneo_id` NULL) no, e **rimuovere l'iscrizione di una categoria non cancella il foglio**: lo distacca (`torneo_id` NULL) e lo lascia in Liste Tornei, perche' chi ci ha messo i giocatori non li perde perche' il responsabile ha cambiato idea. Le gare gia' in calendario bloccano la rimozione con un 400. Il nome del foglio porta torneo **e** categoria (`Winter Cup - 2016 - Pulcini`) e segue il rinomino del torneo: due fogli chiamati entrambi "Winter Cup" non dicono quali sono i Pulcini. Nessuno "stato di blocco": il PDF esportato da `ListeTornei.vue` **e** il documento finale, e quell'export non e' stato toccato
- **I tornei hanno DUE export PDF, e le colonne del foglio devono restare le stesse in entrambi**: quello di `ListeTornei.vue` (foglio della categoria) e quello di `Tornei.vue` (calendario + foglio, per singola categoria o per tutte). Entrambi stampano `#`, `Cognome`, `Nome`. Non aggiungere colonne al secondo senza pensare al lucchetto GDPR: data di nascita, CF e telefoni in `ListeTornei.vue` sono dietro `verifyGdpr` (`colonneDisponibili` con `gdpr: true`), quindi un export che li stampasse senza sblocco sarebbe la scorciatoia per portarli fuori, e quel file finisce condiviso con l'organizzatore. Serve anche `import 'jspdf-autotable'` in **ogni** pagina che usa `doc.autoTable`: le pagine sono chunk caricati al bisogno, e senza import la chiamata cade dentro il `try/catch` dell'export lasciando solo "Errore nella generazione del PDF"
- **Le liste torneo hanno due livelli di difesa sul tenant**, e servono entrambi: `add_giocatore_lista` valida che la `persona` sia della societa' di chi scrive, **e** `GET /{id}/giocatori` filtra `p.societa_id` sulla JOIN con `persone`. Il secondo costa zero e copre le righe gia' presenti nel DB o un bug futuro nella scrittura. Le scritture sono riservate a `RUOLI_GESTIONE_LISTA = ("mister","segreteria")` + admin, la cancellazione a solo admin: prima bastava un token valido, quindi `dirigente` e `scouting` (sola lettura nel resto dell'app) potevano riscrivere e cancellare la lista consegnata all'organizzatore
- **I tornei NON filtrano per `utente_categorie`**: il titolare ha deciso che i mister vedono e usano legittimamente tutte le categorie della propria societa' (in media hanno una sola riga di assegnazione, `registro.py:112`). Filtrare per assegnazione li terrebbe fuori. Conseguenza sul frontend: le etichette delle categorie devono venire da `getAllCategorie`, perche' `getCategorie` per un mister restituisce solo le assegnate
- **I menu a tendina delle categorie vanno ordinati e filtrati**, non lasciati all'ordine della query: `/categorie/all` ordina `anno DESC` e Postgres mette i NULL per primi, quindi la prima voce (e la preselezione dei modal) cade su una categoria senza anno, "Portieri Scuola Calcio". Usare `isParentCategory` per escludere i gruppi ("Agonistica", "Scuola Calcio") e l'etichetta `anno - nome`: senza anno le due "Esordienti" (2014 e 2015) sembrano la stessa voce
- **La pagina Tornei ha la categoria come primo livello, non il torneo**: le sezioni `2016 - Pulcini` sono costruite client-side da `sezioniPerCategoria`, e un torneo iscritto a piu' categorie compare **ripetuto** in ciascuna, come `weekendPartiteGrouped` in ProgrammazionePartite. Non e' una scelta cosmetica da annullare "perche' il torneo e' uno solo": le azioni (Modifica/Elimina) restano del torneo intero, quindi la card dichiara le altre categorie coinvolte e la conferma di eliminazione le nomina. Il badge delle gare **deve** leggere `t.gare_per_categoria[catId]` e non `t.gare`: il totale nella sezione di una categoria e' falso quando le iscritte sono piu' d'una. Il calendario si apre con la chiave `torneo:categoria`, non `torneo`, perche' la stessa card sta in due sezioni. `GET /tornei/` espone `gare_per_categoria` (oggetto indicizzato per id-categoria, assente per le categorie senza gare: il frontend cosi' non stampa "0 gare") e `gare_orfane`, che conta **sia** le gare con `categoria_id` NULL **sia** quelle puntate a una categoria non piu' iscritta: contarle solo come NULL darebbe "0 senza categoria" accanto a una gara che la pagina elenca comunque sotto "Senza categoria"
- **`Base.metadata.create_all` deve stare dentro `run_migrations()`, NON in `main.py`**: stava in `main.py` all'import, quindi ognuno dei 4 worker uvicorn (`--workers 4` nel Dockerfile) lo eseguiva per conto proprio, fuori dalla `pg_advisory_lock(84729103)`. Con le tabelle esistenti e' inerte e non si vede mai, ma alla **prima creazione** di una tabella nuova i 4 corrono sulla stessa sequenza: su PROD, al deploy dei tornei del 2026-11-20, tre `SpawnProcess` sono morti con `UniqueViolation ... "pg_class_relname_nsp_index"` su `tornei_id_seq` e uvicorn li ha respawnti, partiti puliti perche' la tabella ormai c'era (nessun downtime, esito sano, ma il difetto tornava a ogni tabella nuova). Ora e' la prima cosa dentro `run_migrations()` e passa `conn`, **non** `engine`: le advisory lock sono di SESSIONE, quindi con una connessione diversa dal pool sarebbe di nuovo fuori dalla lock che dovrebbe proteggerlo. Provato su DEV droppando `tornei`/`tornei_gare` e riavviando: **2 crash su 4 cicli prima, 0 su 14 dopo**, con `scripts/ops/verifica_worker_riavvio.sh`
  - **`create_all` dentro `run_migrations()` dipende dagli import**: `Base.metadata` si popola quando i moduli dei modelli vengono importati, quindi la chiamata deve stare DOPO `from .routers import ...` in `main.py` (verificato: 32 tabelle registrate; chiamato a modelli non importati e' un no-op silenzioso). C'e' un print di attenzione che lo dice, perche' altrimenti l'errore si vedrebbe solo dopo, come una tabella mai nata
  - **`create_all` non aggiunge vincoli alle tabelle che esistono gia'**: dopo un `DROP TABLE tornei CASCADE` ricrea `tornei` e `tornei_gare` con la loro FK, ma **non** `liste_torneo_torneo_id_fkey`, perche' `liste_torneo` esiste gia' e viene saltata. E il blocco `ALTER TABLE liste_torneo ADD COLUMN IF NOT EXISTS torneo_id INTEGER REFERENCES ...` e' un no-op quando la colonna esiste, quindi nemmeno lui la rimette su. Per questo `run.py` controlla `pg_constraint` e fa `ADD CONSTRAINT` esplicito se manca (`ADD CONSTRAINT` non ha IF NOT EXISTS). Misurato: senza quel blocco la colonna restava orfana in 4 cicli su 4
  - **I log delle migrazioni non sono una prova affidabile al volo**: le `print("Migration: ...")` vanno su stdout, che Python bufferizza a blocchi quando non c'e' un TTY, quindi possono comparire nel log minuti dopo o dopo la finestra che stai leggendo. I traceback invece vanno su stderr, non bufferizzato. `verifica_worker_riavvio.sh` infatti asserisce solo su stderr (traceback, `UniqueViolation`, processi morti) e riporta i contatori `Migration:` come informazione

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
- **Accesso locale vs accesso Google**: un account con `password_hash IS NULL` entra **solo** con Google, e **nessun ruolo puo' dargli una password locale** — il `reset_password` lo rifiuta con 403 anche per il `super_admin`. Se un utente perde l'accesso Google si disattiva e gli si rifà l'invito: non deve esistere nessuna strada, nemmeno quella deliberata, che trasformi un account Google in un account con password. Sugli account che hanno già una password locale il reset genera una **password casuale monouso** (`genera_password_temporanea`), mostrata una volta sola all'admin, con `deve_cambiare_password = TRUE`. `PUT /auth/utenti/{uid}/password` e' riservato al **titolare**: non puo' essere usato da un admin su un altro utente, nemmeno super_admin. `get_current_user` applica il vincolo rispondendo `403` con `detail.code = "PASSWORD_DA_CAMBIARE"` su ogni rotta tranne `/auth/me`, `/auth/logout` e il cambio password sul proprio id — **non** fidarsi del solo frontend per aprire il modal. In `Admin.vue` il pulsante Reset compare solo con `accesso_locale`, quindi nemmeno il super_admin lo vede su un account Google
- **`POST /auth/utenti` non accetta `password`, e non la restituisce mai**: `UtenteCreate` non ha quel campo (Pydantic scarta i campi non dichiarati, quindi un client che lo manda viene ignorato in silenzio). Il server genera la password iniziale e la consegna **solo via mail** all'interessato con `costruisci_email_password_iniziale`; la risposta porta `email_inviata` e, se la mail non parte, un `avviso` che rimanda al Reset. Se non c'e' un indirizzo email deducibile da `email` o da `username` la creazione da' **400**: non creare un account e' meglio che crearne uno con una password che nessuno conosce. Non re-introdurre il campo `password`: ridarebbe a chi crea l'account una credenziale valida per quell'account
- **`DEFAULT_PASSWORD` non si usa piu'**: dal 2026-11-16 i reset generano una password per il singolo utente. La variabile resta in `security.py` e nei `.env` per compatibilita' (non fa piu' fallire l'avvio se assente), ma non va piu' comunicata a nessuno: non apre piu' nessun account
- **`google_sub` si prende dal campo `id` di `userinfo`, non da `sub`**: `exchange_google_code` chiama `https://www.googleapis.com/oauth2/v2/userinfo`, che restituisce l'identificativo come `id`. Leggere solo `sub` (nome dell'`id_token`) lo lasciava vuoto, quindi il match per `google_sub` in `google/callback` non veniva mai eseguito e l'utente veniva trovato solo per email. Non tornare indietro: senza `google_sub` l'identita' dell'accesso Google dipende solo dal confronto `lower(username) == google_email`. **Diagnosi rapida**: il callback stampa `Google OAuth: callback ... sub_len=N` — `N=0` significa che il campo non viene letto (bug originario), `N~21` e' un identificativo Google reale. Controllare anche `SELECT count(*) FROM utenti WHERE google_sub IS NOT NULL`
- **`ENCRYPTION_KEY` NON si ruota a mano**: e' la chiave pgcrypto di CF e telefoni; cambiarla rende illeggibili i dati gia' cifrati. La rotta documentata qui prima, `POST /persone/reencrypt`, **non esiste**: l'unica e' `PUT /persone/encryption-key?reencrypt=true` (solo super_admin) ed e' un endpoint di **rotazione chiave**, non di cifratura, con una strada di perdita dati vera — `safe_decrypt_with_key` rende `None` per qualunque valore sotto i 32 caratteri o non esadecimale (`encryption.py:57`), quindi un CF in chiaro **non si decifra mai**; la riga 426 di `persone.py` pero' fa `UPDATE` su tutti e tre i campi appena **uno** decifra, scrivendo `NULL` negli altri due. Chiamarla sulla chiave attuale per "cifrare i CF rimasti in chiaro" cancella i CF delle righe che hanno anche un telefono cifrato. Per cifrare dati ancora in chiaro serve un'operazione ristretta che tocchi solo quelle righe, non questo endpoint. `SECRET_KEY` e `DEFAULT_PASSWORD` si possono invece ruotare (sloggano solo le sessioni) con `scripts/ops/ruota_segreti.sh dev|prod`: genera i valori **sul server**, non li stampa e si rifiuta di partire senza backup del `.env` gia' esistente. Dopo la modifica del `.env` serve **`docker compose up -d`**, non basta `restart`: la compose passa le variabili con `environment: ${VAR}`, quindi il valore viene fissato alla **creazione** del container. Su PROD la compose va invocata con **`-f docker-compose.yml -f docker-compose.prod.yml`**, altrimenti si rialza con i settings sbagliati. `SECRET_KEY` **non deve mai essere lo stesso valore su DEV e PROD**: condividendo la chiave, un JWT coniato su DEV e' accettato da PROD. Verifica con `scripts/ops/confronta_env.sh`
- **`authlib` rimossa** da `requirements.txt`: era dichiarata ma mai importata, e portava ~20 CVE nell'immagine.
- Public PII endpoints: `5/minute` rate limit + Pydantic validation.
- File uploads: magic bytes validation, max 5MB, controlled extensions.
- CORS: `thof.crickethouse.mywire.org`, `localhost:5173`, `localhost:3000`.
- pgcrypto AES encryption for CF, tel_papa, tel_mamma. **`persone.codice_fiscale` e' `varchar(255)`** (il modello dice `String(16)`, la colonna reale e' stata allargata da una migrazione: `create_all` non altera le colonne esistenti, quindi il modello non rispecchia il DB). L'invariante "zero CF in chiaro" e' verificata da `scripts/test/test_cifratura_cf.sh`; per recuperarne uno sfuggito, `scripts/ops/cifra_cf.sh`
- **Le password iniziali dei tesserati passano (e restano) nella Gmail di relay — apertura accettata dal titolare (2026-11-20)**: `POST /auth/utenti` genera la password, non la mostra all'admin e la consegna **solo via mail** con `costruisci_email_password_iniziale`, che la scrive **in chiaro nel corpo**. Il postfix fa relay autenticandosi a `smtp.gmail.com:587` con l'account del titolare, e Gmail conserva una copia di ogni messaggio inviato: quindi **ogni password iniziale di ogni nuovo tesserato finisce nella posta inviata di quell'account**, leggibile da chi ci ha accesso. L'invariante "nessuno tranne l'interessato conosce la password iniziale" regge contro l'admin, non contro il Gmail di relay. Il titolare ha scelto di lasciar cosi': il sistema e suo, il Gmail e suo, i dati sono della sua societa'. Se un giorno si vuole chiudere, le strade in ordine di costo sono: disattivare "salva una copia dei messaggi inviati" in quell'account (un minuto, ma dipende da un'opzione che si puo' riaccendere), usare un account Gmail di servizio solo per la SMTP (separa la Sent del relay dalla posta personale), o sostituire la mail-password con un link a token dove l'utente sceglie la sua password (il flusso `inviti.py` con token esiste gia', ma e' lavoro vero: migrazione, schermata nuova, e le mail di creazione cambiano). **Correlato**: `scripts/ops/silenzia_mail_prove.sh` esiste perche' lo stesso relay, senza quella regola, scaricava nella casella del titolare anche i bounce dei destinatari di prova
- **`utenti.codice_fiscale` NON e' cifrato, e' un apertura PII nota e accettata**: i CF del personale (11 su 13 utenti su PROD) sono in chiaro. Non e' una distrazione da correggere con un `safe_encrypt` in scrittura: la colonna e' `varchar(16)`, quindi un cipher da 32+ caratteri non ci sta, e `verify_gdpr` (`auth.py:399`) confronta il CF **in chiaro** con quello che digita l'utente, quindi cifrandolo quella verifica smette di funzionare. Servono migrazione della colonna a 255, cifratura in scrittura, decifratura in lettura e un confronto che decifri prima di confrontare. Non fatto: va deciso dal titolare
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
- **Suite in `scripts/test/`** (asserzioni bash, puntano a DEV via SSH + API): `bash scripts/ops/run_suite_dev.sh` le scopre e le somma da solo, e conta come "rotto" uno script che non stampa il riepilogo. Prima di deployare su DEV verificare, dopo aver deployato riverificare. Gli `*_prod.sh` si lanciano a parte contro produzione
  - `test_creazione_utente.sh` (30) — la password non la sceglie e non la vede chi crea l'account
  - `test_reset_password.sh` (44) — reset monouso, blocco `PASSWORD_DA_CAMBIARE`, niente via locale agli account Google
  - `test_login_guard.sh` (28), `test_fix_a2_a8_a9.sh` (34), `test_pii_accessi.sh` (29), `test_registro_tenant.sh` (14), `test_token_pubblico.sh` (20), `test_orario_presentazione.sh` (10) + l'unit `.py` (14) nel container backend
  - `test_tornei.sh` (112) — tornei: scrittura riservata all'admin, Lista Tornei auto-creata e collegata, calendario CRUD, isolamento fra societa', `persona_id` di altra societa' rifiutato, `dirigente`/`scouting`/`infermeria` in sola lettura sulle liste. **Provato che sa fallire**: indebolendo `get_gestore_lista` + `get_responsabile_tornei` nel container diventano rosse 41 asserzioni; indebolendo solo il filtro di societa' su `persona_id` ne diventano rosse 2 (verifica separata, perche' altrimenti la seconda sarebbe rossa per cascata e non per sua colpa)
  - `test_tornei_categorie.sh` (60) — il modello a categorie multiple: due categorie iscritte e i due fogli che nascono da soli con nomi distinti, il filtro per categoria che non lascia fuori la seconda (legge `tornei_categorie`, non `tornei.categoria_id`), la gara senza categoria rifiutata con due iscritte e accettata con una, il doppio click che non produce un secondo foglio, il DB che rifiuta l'iscrizione duplicata (provato con l'`INSERT` diretto: contare che il vincolo "esista" non dimostra che funzioni), il foglio distaccato e non cancellato, il confine fra le societa'. **Provato che sa fallire**: indebolendo nel container le tre regole nuove (gara che deve dichiarare la categoria, foglio che nasce da solo, filtro che legge le iscrizioni) diventano rosse 21 asserzioni; ripristinato il codice, 60/60 verdi di nuovo. Attenzione a `ck`: due valori vuoti **non** sono un "ok", e gli username di prova vanno scritti per esteso perche' in bash `$U_adm` viene letto come la variabile `U_adm`
  - `test_tornei_sezioni.sh` (26) — il contratto dati della pagina suddivisa per categorie: `gare_per_categoria` e `gare_orfane` di `GET /tornei/`. Il conteggio e' per categoria e non il totale (l'asserzione "la sezione a non mostra il totale" esiste per quello), una categoria iscritta senza gare non ha chiave, `gare_per_categoria` resta un oggetto perche' il frontend lo indicizza, le orfane sono contate sia da `categoria_id IS NULL` sia da categoria non iscritta — le due righe create **via SQL**, perche' dall'API una gara senza categoria con tre iscritte non puo' nascere (400). **Provato che sa fallire**: 2 rosse indebolendo il conteggio delle orfane a solo `NULL`, 5 rosse sostituendo il conteggio per categoria con il totale del torneo; ripristinato, 26/26 verdi
  - **Verifica visiva della pagina Tornei**: `bash scripts/test/verifica_ui_tornei.sh` (NON nella suite: vuole Google Chrome, `pdftotext` e crea dati di prova con nome e categorie vere, si lancia a mano). Chrome headless pilotato in CDP fa login come responsabile, apre le sezioni, apre i calendari, preme "+ Aggiungi gara" ed "Elimina" con `confirm` intercettato, **scarica davvero i due PDF dell'export e ne legge il testo**, e riporta cosa c'e' a schermo piu' gli errori in console. 52 asserzioni, con tre **controlli negativi** in coda che rompono il DOM (badge "4 gare" ovunque, "foglio assente" rimosso, "anche ..." rimosso) e verificano che il file se ne accorga. E' l'unico modo che c'e' per vedere le classi di difetti che nessun altro test vede: un helper citato dal template e non definito (**pagina bianca, non 500**), i colori sbagliati a schermo, un export che sembra funzionare e sforna un documento vuoto o con le colonne GDPR dentro. Due dettagli non ovvi: il click va dispatchato con `Input.dispatchMouseEvent` perche' **Chrome blocca il download se non c'e' un gesto utente reale** (`el.click()` non lo e', e l'export sembrava non fare niente, senza errori in console), e le sezioni si agganciano **per titolo e non per indice** perche' l'ordine reale e' per anno crescente, quindi "2015 - Esordienti" viene prima di "2016 - Pulcini" — dare per scontato il contrario aveva prodotto 14 rossi che non misuravano niente
  - **Un componente non eredita nessun CSS**: gli stili sono `scoped` e non esiste un foglio condiviso, quindi ogni pagina si definisce le sue classi (`.modal`, `.btn-azione`, `.badge`...). Conseguenza: i colori **vanno presi da `global.css`**, che e' l'unica fonte del tema, e l'app ha **un solo tema, chiaro** (`--color-surface: #ffffff`). Scrivere letterali pensati per un tema scuro (`#d4d4d4` su `rgba(255,255,255,0.06)`, `#facc15`, `#171717` nelle `option`) non produce un errore da nessuna parte: la pagina funziona, i dati sono giusti, e a schermo i bottoni sono grigio chiarissimo su bianco. E' successo davvero in `Tornei.vue`, trovato solo guardando lo screenshot
  - `ck` di `test_tornei.sh` **rifiuta due valori vuoti** come "ok", e il test si ferma se manca un token o l'id del torneo: con i token vuoti (es. `tok` chiamato con un solo argomento) le asserzioni confrontavano `''` con `''` e dicevano ok. Un test che perde i prerequisiti deve fermarsi, non stampare un verde che non ha misurato niente. `POST /persone/` scrive il `cognome` in MAIUSCOLO: i dati di prova creati via SQL devono essere maiuscoli o i confronti sul cognome falliscono per la forma
  - `test_cifratura_cf.sh` (9 su DEV, 10 con `PERSONE_ATTESE`) — invariante "nessun CF in chiaro su `persone`" + il percorso HTTP: l'amministrazione riceve CF leggibili, mai il cipher esadecimale, e un mister senza assegnazione non ne riceve nessuno. **Provato che sa fallire**: con un CF scritto in chiaro via SQL diventa rosso (8/1). Attenzione pero' a come si fa il negative test: il primo tentativo che ho fatto era un `UPDATE` con l'escaping annidato dentro `ssh`, che non e' mai partito; il test era verde e lo sembrava anche del dato, perche' non avevo confrontato il conteggio "prima" con quello "dopo". Un negative test che non cambia nessun output non ha testato niente percio' i test che fanno molti login devono gestire il 429 (non e' un 401); le password generate contengono `& % #` e vanno passate con `--data-urlencode`; la soglia di blocco login e' 10 tentativi per username; ripulire sempre `utenti` **e** `login_bloccaggi` dei propri utenti di prova
  - Insidie note: `/auth/token` ha `@limiter.limit("10/minute")` percio' i test che fanno molti login devono gestire il 429 (non e' un 401); le password generate contengono `& % #` e vanno passate con `--data-urlencode`; la soglia di blocco login e' 10 tentativi per username; ripulire sempre `utenti` **e** `login_bloccaggi` dei propri utenti di prova
  - **I test PROD non devono contenere conteggi scritti a mano**: `test_login_guard_prod.sh`, `test_post_deploy_prod.sh` e `test_pii_prod.sh` confrontavano `registro = 2961`, `persone = 127`, `utenti = 13`, `giocatori lista 3 = 11`, numeri di una sera di novembre copiati nel file. Quattro giorni di presenze reali hanno portato il registro a 3154 e i test sono diventati rossi da soli, senza che fosse rotto niente. Ora la baseline si cattura all'inizio di ogni esecuzione (`PRIMA_*`) e si confronta con quella; **in piu'** ci sono i minimi assoluti di `ckmin` (registro >= 1000, persone >= 50, categorie >= 10, utenti >= 10, liste >= 1),che sono le uniche soglie che possono restare fisse perche' non inseguono la crescita: servono a intercettare un DB svuotato, che la sola invarianza non vede (una baseline catturata gia' vuota sarebbe verde per il motivo sbagliato). Vale anche per gli id: la lista torneo "vera" di `test_pii_prod.sh` non e' piu' la numero 3, si sceglie a runtime fra quelle con giocatori, e se non c'e' il test si ferma
- **Verifica manuale o log** per cio' che i test non coprono (UI, accesso Google):
  - Prod: `ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f"`
  - Dev: `ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 "cd /opt/registro_presenze && docker compose logs -f"`
  - postfix su DEV **non** scrive in `/var/log/mail.log`: registra in journald (`journalctl | grep postfix`). Per una mail inviata cercare `status=sent` — **ma non per i domini di prova**: `x.local`, `test.local` e `example.com` sono messi in `discard:` da `scripts/ops/silenzia_mail_prove.sh` e registrano anch'essi `status=sent`, con `relay=none` e `postfix/discard` invece di `postfix/smtp`. La riga giusta da guardare e' quella: `relay=smtp.gmail.com` vuol dire che la mail e' davvero uscita, `relay=none` vuol dire che e' stata buttata via. **Non rimuovere quella regola pensando a un avanzo**: prima di essa ogni esecuzione della suite DEV smistava due destinatari inesistenti alla Gmail del titolare, che si ritrovava in casella due bounce "Indirizzo non trovato / NXDOMAIN" (24 in quattordici giorni, piu' due su PROD). Il backend consegna al postfix locale e alza `email_inviata` appena postfix **accetta**: il relay a Gmail e' un passo successivo, tutto di postfix, quindi silenziarlo non toglie niente a cio' che i test misurano. La prova end-to-end di credenziali Gmail e relay va fatta con un invio **voluto** a un indirizzo reale che il titolare legge, non di sfuggita dietro alla suite
