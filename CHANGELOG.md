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
- **Un admin poteva entrare nell'account di chiunque nella propria società**: due porte, entrambe verificate in esecuzione e non solo leggendo il codice. La prima è `reset_password`, che assegnava la `DEFAULT_PASSWORD` unica e condivisa: azzerando la password di un utente, chiunque conoscesse quel valore poteva entrarci. La seconda era più diretta: `PUT /auth/utenti/{uid}/password` chiedeva la password precedente **solo a chi non era admin**, quindi un admin qualsiasi ne impostava una a sua scelta su un utente della propria società e ci entrava con quel nome utente (verificato: `200`, poi login come la vittima, poi `GET /persone/` che restituisce anagrafiche reali). Colpiva anche gli altri admin, perché il controllo non distingueva i ruoli. Ora il reset **rifiuta gli account che entrano con Google** (`password_hash IS NULL`) e per gli account locali genera una **password casuale propria**, mostrata una volta sola all'admin; il cambio password è riservato al titolare dell'account, admin incluso. **Nessun ruolo, super_admin compreso, può attribuire una via locale a un account Google**: se un utente perde l'accesso Google si disattiva e gli si rifà l'invito. Deciso dal titolare il 2026-11-16 dopo aver visto il pulsante comparire sul mister Marco Rassu in quanto super_admin, con la conferma "oggi accede solo con Google" che permetteva comunque di procedere
- **La password temporanea non è un suggerimento**: `get_current_user` risponde `403 PASSWORD_DA_CAMBIARE` a qualsiasi rotta finché non viene sostituita, con una lista breve di percorsi consentiti (`/auth/me`, `/auth/logout` e il cambio password stesso sul proprio id). Aprire il modal nel frontend è la comodità, l'applicazione del vincolo sta nel backend
- **`google_sub` non è mai stato salvato, quindi il riconoscimento via Google dipendeva solo dall'email**: `exchange_google_code` legge l'identità da `.../oauth2/v2/userinfo`, che restituisce l'identificativo nel campo `id`, mentre il codice leggeva `sub` (nome usato nell'`id_token`, che qui non viene mai letto). Il valore restava sempre stringa vuota, quindi il ramo "match utente per google_sub prima, poi per email" non è mai stato eseguito: l'account veniva trovato **solo** perché `lower(username) == google_email`. Questo spiega anche perché `google_sub` fosse `NULL` su tutti e 13 gli utenti di PROD, cosa che sembrava indicare che nessuno usasse Google. Corretto leggendo `id` con fallback su `sub`
- **Chi creava un account ne conosceva la password**: `POST /auth/utenti` prendeva `password` dal body, quindi l'amministratore che creava l'utente aveva una credenziale valida per quel conto e poteva entrarci. Il flag `deve_cambiare_password` messo a `TRUE` alla creazione chiudeva la finestra solo dopo il primo accesso dell'interessato. Ora `UtenteCreate` **non ha piu' il campo `password`**: il server ne genera una con `genera_password_temporanea()` e la consegna **solo via mail** all'interessato (`costruisci_email_password_iniziale`), mentre la risposta contiene `ok`/`id`/`username`/`email_inviata` e mai la password. Un client che la invia comunque viene scartato da Pydantic (verificato: login con quel valore → 401). Se l'email non e' deducibile da `email` o da `username`, la creazione viene **rifiutata con 400**: meglio un account non creato che un account con una password che nessuno conosce
- **Il rate limit del login non è mai stato attivo**: con `@limiter.limit` sopra `@router.post` FastAPI registrava nella rotta la funzione non avvolta dal limiter. 30 tentativi di password producevano zero 429. Corretto l'ordine anche sul reset password
- **Ogni rate limit era aggirabile con un header**: `--forwarded-allow-ips=*` faceva accettare `X-Forwarded-For` da chiunque, e openresty accorpa l'header invece di sostituirlo. Ora ci si fida solo dei proxy Docker
- **Documentazione API esposta**: `/docs`, `/redoc` e `/openapi.json` rispondevano 200 pubblici, con la mappa completa dell'API. Disattivati
- **APK esposto a intercettazione**: `network_security_config.xml` si fidava delle CA installate dall'utente (`src="user"`) e permetteva il traffico in chiaro. Ora solo CA di sistema, cleartext vietato
- **`authlib` rimossa** da `requirements.txt`: mai importata da nessuna parte, portava ~20 CVE nell'immagine
- **`.env` protetti**: portati da 0644 a 600 sui server (contengono `DEFAULT_PASSWORD`)
- **`SECRET_KEY` e `DEFAULT_PASSWORD` non erano piu' condivisi tra DEV e PROD**: i due server avevano `SECRET_KEY`, `DEFAULT_PASSWORD`, `ENCRYPTION_KEY`, `DB_USER`, `DB_PASSWORD` e `DB_NAME` **identici**, verificato confrontandone gli sha256 senza mai stampare i valori. Oltre al rischio generico, `SECRET_KEY` in comune rendeva **valido su PROD un JWT coniato su DEV**: chi legge il `.env` di DEV, raggiungibile dalla rete locale, poteva autenticarsi in produzione. Ruotate entrambe su entrambi gli ambienti con `scripts/ops/ruota_segreti.sh`, che genera i valori nuovi **sul server** e non li stampa mai. Restano identici fra i due ambienti `ENCRYPTION_KEY` e le credenziali DB: ruotare quella richiede `POST /persone/reencrypt`, le altre vanno decise insieme
- **La rotazione di `SECRET_KEY` non tocca le password**: dimostrato prima e dopo su ciascun ambiente, un token coniato prima della rotazione viene rifiutato (401) mentre la password dell'utente continua a funzionare, perche' gli hash restano in database. Il costo e' che le sessioni in corso vengono disconnesse tutte insieme (`ACCESS_TOKEN_EXPIRE_MINUTES` e' di 30 giorni)

- **Chiuso l'accesso anonimo alle anagrafiche nel form d'iscrizione**: `GET`/`PUT /persone/public/{id}` chiedevano come unica credenziale l'ID della persona, che e' sequenziale. Da internet bastava scorrere gli ID per leggere e sovrascrivere anagrafiche, indirizzi, email e anamnesi di qualsiasi tesserato (verificato: `PUT /api/persone/public/3` senza token rispondeva `{"ok":true}`). Gli endpoint sono sostituiti da `/persone/public/by-token/{token}`, dove il token e' coniato dalla segreteria con `POST /persone/{id}/public-link`: 32 byte casuali, scadenza a 30 giorni (`PUBLIC_LINK_GIORNI`), revocabile rigenerandolo. Il link del form passa da `?id=123` a `?t=<token>`
- **Scritture di presenze cross-societa'**: `POST /registro/` confrontava i dati della richiesta con la societa' dell'utente solo in parte. `persona_id` non veniva mai verificato, e la `DELETE` interna (che scatta quando un portiere viene registrato da una categoria non Portieri) usava `categoria_id` senza filtro di societa': si potevano scrivere presenze per tesserati di un'altra societa' e cancellare le righe reali altrui, con parametri tutti enumerabili. Ora persona e categoria devono appartenere alla societa' dell'utente (403), la DELETE e' filtrata per `societa_id`, e i riferimenti inesistenti danno 404 invece di essere ignorati in silenzio. Il `super_admin` resta escluso dai controlli perche' `registro.py` usa un proprio `get_societa_filter` che per lui torna `None`
- **CF e telefoni dei minori uscivano gia' decifrati da `GET /liste-torneo/{lista_id}/giocatori`**: la rotta richiedeva solo `get_current_user` (qualsiasi ruolo autenticato) e rispondeva `codice_fiscale`, `tel_papa`, `tel_mamma`, `email1`, `data_nascita` e `scadenza_certificato` gia' decifrati, con `lista_id` sequenziale quindi enumerabile. In `ListeTornei.vue` quelle colonne sono dietro un lucchetto che chiede il codice fiscale dell'operatore, ma il lucchetto era solo visivo: bastavano gli strumenti del browser per leggere tutto senza inserire nulla. Ora la rotta applica la stessa policy gia' usata da `GET /persone` e da `POST /auth/verify-gdpr`: admin, super_admin, segreteria e infermeria vedono i campi sensibili, il mister solo se assegnato alla categoria della lista, gli altri li ricevono `null`. I campi non sensibili (nome, cognome, sesso, gruppo, ordine) restano disponibili a chiunque, perche' la pagina e il PDF ne hanno bisogno
- **Note cliniche visibili a tutti in `GET /infortuni/`**: `tipo_infortunio` e `note` sono dati sulla salute (art. 9 GDPR) e la rotta, aperta a qualsiasi ruolo, li restituiva a chiunque fosse loggato. Le note, che sono descrizioni cliniche in testo libero e non sono usate da nessuna pagina fuori dall'infermeria, ora escono `null` per i ruoli che non se ne occupano (infermeria, admin, segreteria le continuano a vedere)
- **Nota su un claim d'audit risultato falso**: `GET /infortuni/` non esponeva codice fiscale ne' telefoni. La tabella `infortuni` non contiene quei campi e la query seleziona da `persone` solo nome, cognome e numero di maglia. Resta la questione delle note, trattata sopra, e quella del `tipo_infortunio`, visibile anche ai ruoli non sanitari perche' `Scelta.vue` lo mostra: e' una scelta di prodotto da valutare, non una correzione automatica

### Changed
- **Registro presenze: rimontaggio del componente al cambio squadra** (`App.vue`): `<router-view :key="$route.path" />`. Passando da una squadra all'altra la rotta cambia solo nel parametro (`/registro/5` -> `/registro/7`), quindi Vue riutilizzava lo stesso componente tenendo in memoria lo stato della categoria precedente, con il rischio di registrare presenze sulla squadra sbagliata. Si usa `path` e non `fullPath` perche' alcuni form riscrivono la propria query stringa con `router.replace`, e un rimontaggio in quel momento cancellerebbe la conferma "salvato" appena mostrata
- **`DEFAULT_PASSWORD` non è più usata dall'applicazione**: il reset genera una password casuale per il singolo utente (`genera_password_temporanea` in `core/security.py`, alfabeto senza i caratteri ambigui O/0, I/l/1 e con una classe garantita per tipo). La variabile resta letta per non far fallire l'avvio sui `.env` che la contengono, ma non va più distribuita a nessuno: non è più la chiave per entrare in un account resettato
- **Admin, reset password**: il pulsante non mostra più un generico `alert('Password resettata!')`. Mostra la password temporanea accanto alla riga dell'utente, con pulsante Copia e l'avviso che andrà cambiata, e **mostra l'errore** se il backend rifiuta (prima la chiamata non aveva `try/catch`: su 403 l'admin vedeva comunque "Password resettata!"). Gli account che entrano con Google mostrano un badge "Google" e **non hanno il pulsante Reset per nessun ruolo**, super_admin incluso. `GET /auth/utenti` espone `accesso_locale` proprio per questo, senza esporre `password_hash`
- **Cambio password obbligatorio nell'app**: `App.vue` apre il modal quando il profilo porta `deve_cambiare_password`, e il modal non si può chiudere (né con Annulla, né cliccando fuori, né col tasto indietro su Android). `core/api/client.js` intercetta il `403 PASSWORD_DA_CAMBIARE` e rilancia un evento che fa rileggere il profilo: serve a chi aveva la sessione già aperta prima del reset, che ha in memoria un profilo senza il flag. Allineati anche i requisiti di password del client a quelli del backend, che erano 4 caratteri contro 8 + classi
- **Creazione utente: la password viaggia in mail, non sullo schermo dell'admin**. `POST /auth/utenti` accetta `email` (e usa `username` come destinatario se e' gia' un indirizzo) e risponde `email_inviata`. Se la mail non parte l'account viene comunque creato, con un `avviso` che dice di usare Reset per generarne una da comunicare a voce: e' la via di recupero, perche' `send_email` non solleva mai eccezioni e un guasto SMTP non deve bloccare la creazione. La validazione dell'indirizzo usa lo stesso criterio di `inviti.py` (`@` e `.`), non una regex diversa: due regole per la stessa cosa avrebbero prodotto account creabili ma non raggiungibili (`App.vue`): `<router-view :key="$route.path" />`. Passando da una squadra all'altra la rotta cambia solo nel parametro (`/registro/5` -> `/registro/7`), quindi Vue riutilizzava lo stesso componente tenendo in memoria lo stato della categoria precedente, con il rischio di registrare presenze sulla squadra sbagliata. Si usa `path` e non `fullPath` perche' alcuni form riscrivono la propria query stringa con `router.replace`, e un rimontaggio in quel momento cancellerebbe la conferma "salvato" appena mostrata

### Fixed
- **L'ora di presentazione si azzerava da sola** (`partite.py` + `ProgrammazionePartite.vue`): il form di Programmazione Gare non prevedeva affatto il campo, `apriModal` non lo caricava e `PUT /partite/{id}` riscrive tutta la riga, quindi ogni salvataggio di una partita scriveva `ora_presentazione = NULL`. Ora il PUT distingue "campo non mandato" (si conserva il valore salvato) da "campo mandato vuoto" (si azzera per scelta), usando `model_fields_set`
- **`PUT /persone/{id}` non permetteva di svuotare un campo**: con `p.dict(exclude_none=True)` un telefono o un codice fiscale cancellati nel form restavano in database. Non bastava togliere `exclude_none` perche' la rotta e' chiamata anche con payload parziali (`{rata1: null}`, `{pagamenti_in_regola: value}`) e si sarebbero azzerati nome, CF e telefoni a ogni modifica di una rata. Ora si applicano solo i campi davvero presenti nel payload, `null` compreso
- **`PUT /infortuni/{id}`: campi non svuotabili e data fine incoerente**: ogni campo era protetto da `if x is not None`, quindi `giorni_assenza` non si poteva azzerare e le note cancellare. Inoltre `data_fine` veniva ricalcolata solo quando arrivava `giorni_assenza`, cosi' correggendo la sola data di inizio la scheda restava con un periodo che non tornava. Ora i campi presenti nel payload vengono applicati (vuoti compresi) e `data_fine` viene ricalcolata ogni volta che cambia `data_inizio` o `giorni_assenza`
- **11 cancellazioni fallivano in silenzio** in 10 file (`Admin`, `Societa`, `SchedaAllenamento`, `Allenatori`, `Spogliatoi`, `Convocazioni`, `ListeTornei`, `ProgrammazionePartite` x2, `Openday`, `DatiMatricole`): la chiamata API non era protetta da `try/catch`, o il catch faceva solo `console.error`. L'utente confermava "Eliminare?", l'errore non compariva e la riga restava a schermo. Ora mostrano il `detail` restituito dal backend. Escluse perche' gia' corrette: `eliminaInvitoUtente` (usa `invitoMsg`) e le due di `Scouting.vue` (usano `dettaglioErrore`, renderizzato a schermo)
- **Presenze allenatori: il modal si chiudeva anche su errore** (`PresenzeAllenatori.vue`): `editModal.show = false` stava fuori dal `catch`, quindi una presenza non registrata sembrava registrata. Ora il modal resta aperto e l'errore viene mostrato
- **`PUT`/`DELETE /infortuni/{id}` rispondevano 403 alle righe inesistenti**: allineati alla convenzione del resto del progetto (404 se non esiste, 403 se e' di un'altra societa')

### Added
- **Ora di presentazione precompilata**: 45 minuti prima dell'inizio gara in casa, 60 in trasferta. E' una precompilazione, non un vincolo: il campo e' ora visibile e modificabile nel form di Programmazione Gare, e viene ricalcolato solo finche' il Responsabile non lo tocca a mano. In creazione la precompilazione avviene anche lato backend, cosi' il valore non dipende dal client
- **Blocco dei tentativi di login sul singolo username** (`backend/app/core/login_guard.py`, tabella `login_bloccaggi` creata all'avvio da `migrations/run.py`): il limiter slowapi conta per indirizzo, ma openresty sul router **accorpa** `X-Forwarded-For` invece di sostituirlo, quindi chi attacca si attribuisce un IP diverso a ogni richiesta e il conteggio per IP non lo ferma mai. Ora si conta sull'username, che chi prova a indovinare una password non puo' cambiare: 10 tentativi errati in 15 minuti bloccano l'username per 15 minuti, con `Retry-After` e messaggio distinto da quello del limiter. Soglie regolabili via env (`LOGIN_MAX_TENTATIVI`, `LOGIN_FINESTRA_MINUTI`, `LOGIN_BLOCCO_MINUTI`) senza toccare il codice. Il contatore si azzera a ogni login riuscito, le maiuscole e gli spazi non creano contatori separati, le righe piu' vecchie della finestra vengono ripulite per non far crescere la tabella all'infinito
- **Il blocco login non puo' diventare un disservizio**: se la tabella manca o una query fallisce, il login passa comunque invece di rispondere 500 (verificato: senza questo accorgimento, senza tabella ogni accesso falliva). Serve anche il `rollback` della sessione, perche' dopo una query fallita SQLAlchemy lascia la transazione in stato "aborted" e la query successiva della rotta esploderebbe comunque. L'episodio finisce su stderr con `flush=True`, perche' `print` su stdout in un container senza TTY e' bufferizzato e l'avviso non comparirebbe mai in `docker compose logs`
- **Scritture cross-societa' chiuse in `categorie.py`**: `PUT /categorie/{id}/utenti` cancellava tutte le assegnazioni di una categoria senza verificare che fosse della societa' dell'admin, ne' che gli utenti lo fossero (svuotando le assegnazioni di un'altra societa' i mister smettevano di vedere la squadra, perche' `GET /categorie` filtra per assegnazione); `POST /categorie/importa-giocatori/{id}` copiava nome, cognome e gruppo da categorie archiviate senza filtro di societa'. Ora entrambi sono confinati alla societa' dell'utente, `super_admin` escluso
- **Colonna `deve_cambiare_password` su `utenti`** (`models/auth.py` + migrazione idempotente in `migrations/run.py`): marca le password temporanee. La migrazione azzera il flag dove `password_hash` è `NULL`, perché un flag "devi cambiare la password" su un account che la password non ce l'ha non significa niente e bloccherebbe l'accesso Google
- **`scripts/ops/`, gli strumenti di gestione dei segreti**: `ruota_segreti.sh dev|prod` ruota `SECRET_KEY` (e per compatibilità anche `DEFAULT_PASSWORD`) con prova prima/dopo e **si ferma se il backup del `.env` non esiste**, ripristinandolo se il nuovo `.env` risulta invalido; `gen_passphrase.sh` genera una passphrase comunicabile a voce (5 parole + 3 cifre, ~44 bit); `confronta_env.sh` confronta DEV e PROD per hash senza stampare nulla; `run_suite_dev.sh` esegue tutta la suite DEV e somma i risultati. Le sue asserzioni sul reset sono state riscritte: provano che il reset **non** restituisce la `DEFAULT_PASSWORD`, mentre prima verificavano il contrario
- **`scripts/test/test_reset_password.sh`** (44 asserzioni): copre il rifiuto del reset sugli account Google **da parte di admin e di super_admin** (la seconda era l'eccezione poi tolta), la casualità del reset (due reset dello stesso utente danno due password diverse, prova che non è un valore fisso), il blocco `403` con la temporanea, lo sblocco dopo il cambio, il rifiuto del cambio password altrui anche per admin e super_admin, il flag nella risposta del login e `accesso_locale` nella lista utenti

### Documentato
- **`google_sub` provato end-to-end su DEV e su PROD**: il titolare ha fatto accessi reali con Google su entrambi. Su DEV `utenti.google_sub` e' risultato valorizzato (primo valore non-NULL in quel database), su PROD lo stesso: `andmor1982@gmail.com` ha `google_sub` di 21 caratteri e `password_hash IS NULL`, e nei log del backend compare `Google OAuth: callback email_domain=gmail.com sub_len=21` — prima quel valore era sempre `sub_len=0`, che era il sintomo del bug. L'identita' dell'accesso Google non dipende piu' solo dal confronto `lower(username) == google_email`. Gli altri utenti si popoleranno al loro primo accesso Google: controllare che il conteggio salga e' il modo per accorgersi se qualcuno passa da un ramo diverso
- **La UI del cambio password obbligatorio non e' mai stata vista in un browser**: il vincolo lo applica il backend ed e' testato (con il flag attivo ogni rotta risponde 403, `/auth/me` passa, il cambio sblocca tutto), ma l'aspetto del modal — che si apra e che Annulla / cliccare fuori / tasto indietro su Android non lo chiudano — non e' mai stato guardato. Il peggio possibile e' un'esperienza confusa, non un accesso non autorizzato
- **`createUtente` in `frontend/src/core/api/auth.js` e' codice morto**: esportato, mai chiamato da nessun `.vue`. Gli account reali nascono tutti da invito → Google. Passa `data` cosi' com'e', quindi funziona anche col nuovo contratto, ma se qualcuno lo collegasse a un form dovrebbe sapere che il campo `password` viene scartato dal server
- **Rischio accettato del blocco login**: sbagliando di proposito la password su un username noto si blocca l'accesso dell'utente legittimo per 15 minuti. E' il prezzo di un blocco indipendente dall'IP, scelto perche' l'alternativa (contare per IP) non funziona affatto su questa infrastruttura. Soglie alte e blocco breve, tutto configurabile via env
- Regola sull'ordine dei decorator del limiter e sul perché `--forwarded-allow-ips` non deve essere `*`, nel capitolo Security di AGENTS.md
- Perche' su `POST /registro/` **non** si applica il controllo di assegnazione categorie (`utente_categorie`) presente invece in `allenamenti.py`: la lista che il mister clicca in `Scelta.vue` arriva da `GET /categorie/by-stagione`, che filtra solo per societa', quindi oggi i mister usano legittimamente tutte le categorie della propria societa' avendo in media una sola assegnazione formale. Scelta del titolare 2026-11-16. Per stringere in futuro: completare le assegnazioni in Admin, allineare `by-stagione`, poi riattivare il controllo
- **Rischio aperto, non risolto dalla rotazione: il reset password e' una via d'accesso laterale**. `PUT /auth/utenti/{uid}/reset-password` assegna a chiunque la `DEFAULT_PASSWORD`, che **unica e condivisa**, e **non esiste un cambio obbligatorio al primo accesso** (nessun campo `must_change_password` nel modello). Quindi un admin puo' resettare la password di un altro utente e **entrare al posto suo**, e il ripristino di un account Google le aggiunge una `password_hash` che prima non aveva, aprendo anche la via locale. Su PROD 10 utenti su 13 non hanno `password_hash` (entrano solo con Google, sono tutti account `@gmail.com`) e 3 si. La correzione vera sarebbe generare una password casuale **per singolo reset**, mostrarla all'admin e imporre il cambio al primo login: codice + UI, da fare dev-first su decisione del titolare
- **`[ -s /dev/stdin ]` non funziona attraverso `ssh`**: lo stdin di una sessione ssh e una pipe, che per `test -s` ha dimensione zero, quindi il ramo "vero" non viene mai eseguito. Il primo `ruota_segreti.sh` cosi' **non installava mai la passphrase** passata con `PASSFILE`, scivolando sul valore casuale, e le asserzioni non lo rilevavano perche' confrontavano il `.env` con se stesse. Ora la scelta la fa lo script locale passando un flag, e c'e' un'asserzione che paragona il valore nel `.env` con quello fornito da un file separato

### Test
- `scripts/test/test_login_guard.sh` con `scripts/test/login_probe.py` (28 asserzioni). Le richieste partono dal server DEV verso l'app nel container con un `X-Forwarded-For` diverso a ogni tentativo, che e' esattamente lo scenario in cui il limiter per IP e' inutile: senza distinzione tra i due 429 ("Rate limit exceeded" di slowapi contro "Troppi tentativi di accesso per questo utente") il test avrebbe potuto passare senza dimostrare nulla. Copre anche il fail-open senza tabella e la pulizia delle righe vecchie
- `scripts/test/test_orario_presentazione.sh` (10 asserzioni end-to-end) e `test_orario_presentazione_unit.py` (14 sulla funzione di calcolo), `scripts/test/test_fix_a2_a8_a9.sh` (34 asserzioni su A2/A8/A9)
- `scripts/test/test_pii_accessi.sh` (29 asserzioni su DEV), `scripts/test/test_pii_prod.sh` (29 su PROD) e `scripts/test/test_post_deploy_prod.sh` (47 su PROD). Tutti i test DEV creano solo oggetti di prova marcati e li rimuovono
- `scripts/ops/ruota_segreti.sh` porta la propria verifica (19 asserzioni): passata prima e dopo su DEV e su PROD, entrambe verdi. `scripts/ops/run_suite_dev.sh` aveva un contatore bugiardo, sommaria solo i passati delle prime cinque suite e stampa "0 rosse" anche con un fallimento in corso: ora accumula tutti e sette i risultati, e' stato verificato proprio sul fallimento che nascondeva (le righe `login_bloccaggi` dei propri utenti di prova, non ripulite, facevano fallire il test del blocco login)
- **Rilasciato su PROD il 2026-11-16** (`017910b` → `33789c5` → `ac529fe`), con backup del DB prima di ogni passo (sha256 verificato locale/remoto, 44 tabelle) e conteggi ricontrollati alla baseline. **`deploy.sh` costa circa 50 secondi di interruzione**: `docker compose down` avviene **prima** di `build --no-cache`, quindi il downtime reale e' build + riavvio, non il solo riavvio. Misurato due volte con due metodi indipendenti e concordi: sondaggio a 0,211 s (50,1 s) e, la seconda volta, differenza tra l'evento docker `destroy` e `Application startup complete` nei log del container (50,1 s). Se serve un downtime piu' corto, la strada e' costruire l'immagine nuova e solo dopo fare `down` + `up`
- `scripts/ops/run_suite_dev.sh` ora **scopre da se'** gli `test_*.sh` in `scripts/test` (esclusi i `*_prod.sh`) e conta come "rotto" uno script che non stampa il riepilogo: un elenco scritto a mano e' lo stesso errore che si era gia' presentato, cioe' un test nuovo che nessuno conta. Suite DEV completa: **223 asserzioni verdi** su nove file
- **`scripts/test/test_creazione_utente.sh`** (30 asserzioni): senza email la creazione da' 400 e **non crea niente**, un indirizzo malformato non basta, il campo `password` mandato dal client viene ignorato (login con quel valore → 401), la risposta ha solo le chiavi `ok`/`id`/`username`/`email_inviata` e **nessun suo valore testuale apre l'account** (provato tentando il login con ciascuno, non cercando una stringa nel body), l'account nasce con `password_hash NOT NULL` e `deve_cambiare_password TRUE`, e i controlli di autorizzazione preesistenti (username duplicato, cross-societa', mister, super_admin abusivo) sono ancora verdi. La via di recupero e' coperta forzando il ramo "mail guasta" dentro il container con un double di `send_email`: l'account viene creato comunque, l'`avviso` compare, e il Reset gli genera una password funzionante. Avvertenza per chi riusesse il file: la soglia di blocco login e' 10 tentativi, il test ne fa 2-3 per account
- **La consegna della mail e' stata verificata, non data per scontata**: `email_inviata = true` da sola dimostra solo che `smtplib` non ha sollevato. Controllando postfix su DEV, le due mail di prova risultano `dsn=2.0.0, status=sent (250 2.0.0 OK)` con relay a `smtp.gmail.com:587`. Nota per chi cerchera' le prove: postfix su DEV **non** scrive in `/var/log/mail.log`, registra in journald (`journalctl | grep postfix`)
- Due falsi negativi trovati e corretti in `test_reset_password.sh`, entrambi colpa del test e non dell'app: le password temporanee contengono `&`, `%` e `#`, quindi vanno passate con `--data-urlencode` (passandole grezze arrivava al server una password troncata, 13 asserzioni rosse senza motivo), e `/auth/token` ha `@limiter.limit("10/minute")` percio' le venti chiamate del test si presentavano come 429 scambiati per 401/403. Verificato sperimentalmente: dall'11ª richiesta ravvicinata in poi il container risponde 429
