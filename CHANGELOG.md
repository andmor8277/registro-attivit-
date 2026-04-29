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
