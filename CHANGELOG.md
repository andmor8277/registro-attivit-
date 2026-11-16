# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-01

### Added
- **Lavagna Tattica** (Allenamenti)
  - Campo da calcio realistico con percentuali (aree, penalty, cerchio centrale)
  - Libreria oggetti sportivi completi (3 set):
    - Set 1: Palloni (calcio, blue, red), Coni (arancione, small, striped), Paletti (red, yellow, white), Bandierine (red, yellow), Dischi (orange, blue, yellow), Anelli (red, blue, yellow)
    - Set 2: Ostacoli, Telai, Attrezzi fitness (dumbbell, trampoline, materasso), Palloni sport (tennis, volley, basket, futsal, hockey, football US, rugby, golf)
    - Set 3: Barre, Griglie, Piattaforme
  - **5 Frecce tattiche calcio**:
    - Passaggio (linea continua)
    - Conduzione palla (tratteggiata)
    - Combinazione a muro (bidirezionale)
    - Tiro in porta (linea spessa)
    - Movimento senza palla (termina con pallino)
  - Frecce ruotabili, allungabili, ondulabili
  - Personalizzazione colore (nero di default, cambiabile)
- **Protezione GDPR** per dati sensibili
  - Password per visualizzare CF, telefono, data nascita
  - Pulsante sblocco nella toolbar di Dati Matricole
- **Inizio/Fine Stagione** globali
  - Spostati da configurazione categoria a "Imposta Stagione"
  - Valgono per tutte le categorie
- Badge colorati per ruoli:
  - Mister: rosso (#dc2626)
  - Dirigente: blu (#2563eb)
- Pulsanti header in Dati Matricole:
  - Sblocca Dati Sensibili (admin)
  - Aggiungi Giocatore (admin/mister)
- Anno nella toolbar Allenamenti

### Fixed
- Bug visualizzazione data (giorno sbagliato di 1)
- Formattazione data con parseInt per evitare problemi fuso orario

### Removed
- Integrazione Google Drive
- Google Drive Folder ID dalle categorie

### Tech Stack
- Vue 3 + Vite (Frontend)
- FastAPI + PostgreSQL (Backend)
- Docker Compose
- Multi-società con isolamento dati

---

## [0.0.0] - 2025-xx-xx

### Added
- Sistema base di gestione presenze
- Registro presenze con codici (X, P, R, A, AG, AI)
- Gestione categorie e stagioni
- Convocazioni con export PDF
- Multi-società
- Tema dinamico per società

## [1.1.0] - 2026-04-01

### Added
- Hide Reportistica from dirigenti

## [2.1.0] - 2026-04-29

### Added
- Funzionalità minori

## [4.0.0] - 2026-05-23

### Added
- **Lavagna Tattica Riscritta (TacticalBoard.vue)**
  - Componente dedicato con sistema coordinate percentuali (0-100) per layout responsive
  - 3 modalità campo: intero, metà campo, vuoto
  - Pannello modifica con cambio colore elemento selezionato
  - Undo/Redo completo con storico
  - Drag & drop per tutti gli elementi
  - Resize frecce con handle interattivi
  - Pulsante eliminazione elemento selezionato
  - Selezione preservata dopo sync server
  - Auto-switch a tool "select" dopo piazzamento oggetto
- **Catalogo Esercizi con Anteprima Campo**
  - Miniatura campo da calcio con elementi visualizzati negli esercizi del catalogo
  - Descrizione e dettagli per ogni esercizio
- **Segreteria Panoramica**
  - Nuova pagina panoramica per categoria con statistiche
  - Pagina dettagli iscritti con tutti i dati
- **Autorizzazione Backend Allenamenti**
  - Controllo permessi su save_allenamento (admin/super_admin/mister)
- **Layout Full-Width**
  - Pagine Allenamenti e Catalogo occupano tutta la larghezza disponibile

### Changed
- **Frontend Ristrutturato**
  - Allenamenti.vue: template e CSS completamente riscritti per performance e manutenibilità
  - Sistema coordinate da pixel a percentuali per compatibilità multi-dispositivo
  - Pannello laterale strumenti con icone SVG dedicate
  - Pannello destra con colore, dimensione e modalità campo

### Fixed
- **TacticalBoard**: primo oggetto piazzabile modificabile (selection preservata dopo sync server)
- **TacticalBoard**: tool automaticamente resettato a "select" dopo piazzamento
- **TacticalBoard**: frecce resize con hitResult preservato tra iterazioni loop
- **TacticalBoard**: gomma elimina tutti i tipi di elemento (non solo free)
- **Allenamenti.vue**: click su day chip funzionante (pointer-events: none su pseudo-elemento)
- **Docker**: container frontend esposto su 0.0.0.0 per proxy nginx esterno
- **Deploy Dev**: script deploy_dev.sh con tar+ssh per server senza internet
- **CORS**: configurazione corretta per dev server (192.168.178.133:3000)
- **VITE_API_URL**: configurazione /api per dev server (nginx internal proxy)
- **bcrypt**: fix dummy hash per autenticazione

### Security
- Rimozione TrustedHostMiddleware che bloccava richieste Docker interne
- Fix MutableHeaders (nessun metodo pop)
- Rate limiting con SlowAPIMiddleware corretto

## [3.0.0] - 2026-04-29

### Added
- **Sistema Pagamenti Completo**
  - Tabella pagamenti in Segreteria: Totale, Iscrizione, Rata 1-4, Saldo, Rimane
  - Campi editabili inline con salvataggio immediato
  - Calcolo automatico "Rimane da pagare" (verde se saldo <= 0)
- **Scheda Giocatore**
  - Vista completa con tutti i dati personali, contatti, genitori, anamnesi, equipaggiamento
  - Sezione pagamenti con totale da pagare e quote
  - Stampa PDF ottimizzata
- **Form Preiscrizione Online**
  - Segretario crea preiscrizione (nome + cognome) → genera link
  - Genitore apre link e compila form completo con dati precompilati
  - Sezione dati genitori (nome, professione, tel papà/mamma)
  - Nome e cognome non modificabili nel form online
- **Eliminazione Giocatori**
  - Bottone cestino in tabella Segreteria con conferma
- **Miglioramenti Backend**
  - Aggiornamento parziale: solo i campi inviati vengono modificati
  - Campi vuoti gestiti correttamente come NULL

### Fixed
- Salvataggio scheda giocatore con campi rate
- Form online che non salvava con campi vuoti

## [5.1.0] - 2026-06-11

### Added
- Security hardening: cross-tenant isolation, Pydantic models, XSS sanitization, CSP, CORS cleanup, GDPR sessionStorage, password policy, token 60min, axios 401 interceptor, viewport accessibility, noopener, model_dump, ruoli da /auth/me, codice_fiscale rimosso, SW cache fix, super_admin multi-società

## [5.2.0] - 2026-06-18

### Added
- Infortuni DB-backed con auto-scadenza, storico permanente, eliminazione, Infermeria hub, conteggio attivi

## [5.3.0] - 2026-06-24

### Added
- Open Day completo, campi a metà, planning eventi, redirect login per ruolo, settimana tipo, stagione persistente

## [5.4.0] - 2026-07-28

### Added
- Report Individuale in Reportistica, non_presente in Convocazioni, stagione dinamica da DB, parent categories escluse, Renaming Gestione Squadre

## [5.5.0] - 2026-07-31

### Added
- Fix bug medi: sicurezza multi-tenant societa/auth, esclusioni convocazioni, upsert registro/presenze_allenatori, migrazioni idempotenti, validazioni frontend

## [6.1.0] - 2026-08-12

### Added
- Accesso con Google OAuth, inviti email e relay SMTP Gmail

## [7.0.0] - 2026-08-31

### Added
- Design system light, titoli a doppio colore leggibili, Panoramica Prossima gara unificata, Convocazioni attivo/storico/mister, Scheda Allenamento per gruppo Agonistica, GDPR CF

## [7.1.0] - 2026-08-31

### Added
- Generazione automatica codice fiscale, campo Sesso, certificati da verificare in Home

## [7.2.0] - 2026-08-31

### Added
- Dati&Matricole e Liste Tornei: campi anagrafici completi (sesso, comune nascita, residenza, via) + generazione CF

## [7.3.0] - 2026-09-23

### Added
- Robustezza, isolamento multi-tenant, indici DB e ottimizzazioni performance

## [7.4.0] - 2026-09-24

### Added
- App Android nativa (APK), Convocazioni avanzate (box non convocati, filtri gruppo, PDF 1 pagina) e workflow Dev-First

## [7.5.0] - 2026-11-16

### Added
- Avviso di aggiornamento APK dentro l'app (GitHub Releases) e correzioni UI: testi invisibili sui menu a tendina

## [7.5.1] - 2026-11-16

### Fixed
- L'update check non riconosceva il numero di build: la Release API di GitHub non espone un campo versionCode, quindi una rebuild ripubblicata sotto lo stesso tag non veniva mai proposta. Il numero di build passa nel body della release come commento HTML e, in assenza, viene letto dal manifest version.json
- build_android_apk.sh scrive il numero di build in un sidecar accanto all'APK e publish_android_apk.sh lo usa: pubblicare dopo un nuovo commit non dichiara piu un build number diverso da quello impresso nell'APK

## [7.5.2] - 2026-11-16

### Fixed
- Le note dell'avviso di aggiornamento mostravano anche il commento HTML `<!-- thof-versionCode: NNN -->`: il body della release viene renderizzato come testo, quindi il marcatore va rimosso prima di mostrarlo

## [Unreleased] - 2026-11-16

### Security
- **Il rate limit del login non è mai stato attivo**: con `@limiter.limit` sopra `@router.post` FastAPI registrava nella rotta la funzione non avvolta dal limiter. 30 tentativi di password producevano zero 429. Corretto l'ordine anche sul reset password
- **Ogni rate limit era aggirabile con un header**: `--forwarded-allow-ips=*` faceva accettare `X-Forwarded-For` da chiunque, e openresty accorpa l'header invece di sostituirlo. Ora ci si fida solo dei proxy Docker
- **Documentazione API esposta**: `/docs`, `/redoc` e `/openapi.json` rispondevano 200 pubblici, con la mappa completa dell'API. Disattivati
- **APK esposto a intercettazione**: `network_security_config.xml` si fidava delle CA installate dall'utente (`src="user"`) e permetteva il traffico in chiaro. Ora solo CA di sistema, cleartext vietato
- **`authlib` rimossa** da `requirements.txt`: mai importata da nessuna parte, portava ~20 CVE nell'immagine
- **`.env` protetti**: portati da 0644 a 600 sui server (contengono `DEFAULT_PASSWORD`)

### Documentato
- Regola sull'ordine dei decorator del limiter e sul perché `--forwarded-allow-ips` non deve essere `*`, nel capitolo Security di AGENTS.md

### Security
- **Chiuso l'accesso anonimo alle anagrafiche nel form d'iscrizione**: `GET`/`PUT /persone/public/{id}` chiedevano come unica credenziale l'ID della persona, che e' sequenziale. Da internet bastava scorrere gli ID per leggere e sovrascrivere anagrafiche, indirizzi, email e anamnesi di qualsiasi tesserato (verificato: `PUT /api/persone/public/3` senza token rispondeva `{"ok":true}`). Gli endpoint sono sostituiti da `/persone/public/by-token/{token}`, dove il token e' coniato dalla segreteria con `POST /persone/{id}/public-link`: 32 byte casuali, scadenza a 30 giorni (`PUBLIC_LINK_GIORNI`), revocabile rigenerandolo. Il link del form passa da `?id=123` a `?t=<token>`. Testato end-to-end: 20/20

### Security
- **Scritture di presenze cross-societa'**: `POST /registro/` confrontava i dati della richiesta con la societa' dell'utente solo in parte. `persona_id` non veniva mai verificato, e la `DELETE` interna (che scatta quando un portiere viene registrato da una categoria non Portieri) usava `categoria_id` senza filtro di societa': si potevano scrivere presenze per tesserati di un'altra societa' e cancellare le righe reali altrui, con parametri tutti enumerabili. Ora persona e categoria devono appartenere alla societa' dell'utente (403), la DELETE e' filtrata per `societa_id`, e i riferimenti inesistenti danno 404 invece di essere ignorati in silenzio. Il `super_admin` resta escluso dai controlli perche' `registro.py` usa un proprio `get_societa_filter` che per lui torna `None`. Testato end-to-end su DEV: 14/14

### Changed
- **Registro presenze: rimontaggio del componente al cambio squadra** (`App.vue`): `<router-view :key="$route.path" />`. Passando da una squadra all'altra la rotta cambia solo nel parametro (`/registro/5` -> `/registro/7`), quindi Vue riutilizzava lo stesso componente tenendo in memoria lo stato della categoria precedente, con il rischio di registrare presenze sulla squadra sbagliata. Si usa `path` e non `fullPath` perche' alcuni form riscrivono la propria query stringa con `router.replace`, e un rimontaggio in quel momento cancellerebbe la conferma "salvato" appena mostrata

### Documentato
- Perche' su `POST /registro/` **non** si applica il controllo di assegnazione categorie (`utente_categorie`) presente invece in `allenamenti.py`: la lista che il mister clicca in `Scelta.vue` arriva da `GET /categorie/by-stagione`, che filtra solo per societa', quindi oggi i mister usano legittimamente tutte le categorie della propria societa' avendo in media una sola assegnazione formale. Scelta del titolare 2026-11-16. Per stringere in futuro: completare le assegnazioni in Admin, allineare `by-stagione`, poi riattivare il controllo

### Fixed
- **L'ora di presentazione si azzerava da sola** (`partite.py` + `ProgrammazionePartite.vue`): il form di Programmazione Gare non prevedeva affatto il campo, `apriModal` non lo caricava e `PUT /partite/{id}` riscrive tutta la riga, quindi ogni salvataggio di una partita scriveva `ora_presentazione = NULL`. Ora il PUT distingue "campo non mandato" (si conserva il valore salvato) da "campo mandato vuoto" (si azzera per scelta), usando `model_fields_set`
- **`PUT /persone/{id}` non permetteva di svuotare un campo**: con `p.dict(exclude_none=True)` un telefono o un codice fiscale cancellati nel form restavano in database. Non bastava togliere `exclude_none` perche' la rotta e' chiamata anche con payload parziali (`{rata1: null}`, `{pagamenti_in_regola: value}`) e si sarebbero azzerati nome, CF e telefoni a ogni modifica di una rata. Ora si applicano solo i campi davvero presenti nel payload, `null` compreso
- **`PUT /infortuni/{id}`: campi non svuotabili e data fine incoerente**: ogni campo era protetto da `if x is not None`, quindi `giorni_assenza` non si poteva azzerare e le note cancellare. Inoltre `data_fine` veniva ricalcolata solo quando arrivava `giorni_assenza`, cosi' correggendo la sola data di inizio la scheda restava con un periodo che non tornava. Ora i campi presenti nel payload vengono applicati (vuoti compresi) e `data_fine` viene ricalcolata ogni volta che cambia `data_inizio` o `giorni_assenza`
- **11 cancellazioni fallivano in silenzio** in 10 file (`Admin`, `Societa`, `SchedaAllenamento`, `Allenatori`, `Spogliatoi`, `Convocazioni`, `ListeTornei`, `ProgrammazionePartite` x2, `Openday`, `DatiMatricole`): la chiamata API non era protetta da `try/catch`, o il catch faceva solo `console.error`. L'utente confermava "Eliminare?", l'errore non compariva e la riga restava a schermo. Ora mostrano il `detail` restituito dal backend. Escluse perche' gia' corrette: `eliminaInvitoUtente` (usa `invitoMsg`) e le due di `Scouting.vue` (usano `dettaglioErrore`, renderizzato a schermo)
- **Presenze allenatori: il modal si chiudeva anche su errore** (`PresenzeAllenatori.vue`): `editModal.show = false` stava fuori dal `catch`, quindi una presenza non registrata sembrava registrata. Ora il modal resta aperto e l'errore viene mostrato
- **`PUT`/`DELETE /infortuni/{id}` rispondevano 403 alle righe inesistenti**: allineati alla convenzione del resto del progetto (404 se non esiste, 403 se e' di un'altra societa')

### Added
- **Ora di presentazione precompilata**: 45 minuti prima dell'inizio gara in casa, 60 in trasferta. E' una precompilazione, non un vincolo: il campo e' ora visibile e modificabile nel form di Programmazione Gare, e viene ricalcolato solo finche' il Responsabile non lo tocca a mano. In creazione la precompilazione avviene anche lato backend, cosi' il valore non dipende dal client
- **Scritture cross-societa' chiuse in `categorie.py`**: `PUT /categorie/{id}/utenti` cancellava tutte le assegnazioni di una categoria senza verificare che fosse della societa' dell'admin, ne' che gli utenti lo fossero (svuotando le assegnazioni di un'altra societa' i mister smettevano di vedere la squadra, perche' `GET /categorie` filtra per assegnazione); `POST /categorie/importa-giocatori/{id}` copiava nome, cognome e gruppo da categorie archiviate senza filtro di societa'. Ora entrambi sono confinati alla societa' dell'utente, `super_admin` escluso

### Test
- `scripts/test/test_orario_presentazione.sh` (10 asserzioni end-to-end) e `test_orario_presentazione_unit.py` (14 sulla funzione di calcolo), `scripts/test/test_fix_a2_a8_a9.sh` (34 asserzioni su A2/A8/A9). Tutti i test DEV creano solo oggetti di prova marcati e li rimuovono
