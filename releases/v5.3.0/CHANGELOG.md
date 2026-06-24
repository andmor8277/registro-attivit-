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
