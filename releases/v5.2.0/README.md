# The Home of Football (THOF)

Sistema di gestione multi-società per società sportive dilettantistiche (calcio)

## Stack Tecnologico

- **Frontend**: Vue 3 + Vite
- **Backend**: FastAPI (Python)
- **Database**: PostgreSQL
- **Container**: Docker Compose

## Struttura del Progetto

```
registro_presenze/
├── frontend/           # Frontend Vue 3
│   ├── src/
│   │   ├── views/     # Pagine dell'applicazione
│   │   ├── api/       # Chiamate API
│   │   └── store.js   # State management
│   └── public/        # Asset statici
├── backend/           # Backend FastAPI
│   └── app/
│       ├── routers/   # API routes
│       ├── models.py  # Modelli database
│       └── main.py    # Entry point
├── migrations/        # Script migrazione database
├── db_backup/         # Dump database per ambiente dev
├── docker-compose.yml
├── start_dev.sh       # Script avvio ambiente dev
└── deploy.sh          # Script deploy produzione
```

## Setup Locale

### Requisiti

- Node.js 18+
- Python 3.14+ (per backend locale)
- Docker (per il server)

### Sviluppo Locale

```bash
# Avvia l'ambiente dev (PostgreSQL + Backend + Frontend)
./start_dev.sh
```

- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:8000

### Deploy in Produzione

```bash
./deploy.sh
```

## Accesso

- **Produzione**: https://thof.crickethouse.mywire.org
- **Locale**: http://localhost:5173

## 📦 Release

<!-- RELEASE_INFO -->
La versione attuale è **v5.0.0**.

Leggi il [CHANGELOG](CHANGELOG.md) per tutte le novità delle release.

### Novità v5.0.0

- **Convocazioni Redesign Completo**: Nuova griglia giocatori 7 colonne con slot cliccabili, player picker modale con ricerca in tempo reale, contatore assegnati per gara
- **PDF Convocazioni Editorial Style**: Layout match-day program con header dark, card gare con ombre, griglia info a 2 colonne, righe giocatori con badge numerati, sezione note amber, footer stagione
- **Fix Gruppo Pigna**: Risolto bug che mostrava gruppi senza categoria in tutte le categorie (filtro backend corretto)
- **Weekend Gare**: Sidebar con weekend disponibili, creazione convocazione da weekend con partite pre-caricate

### Novità v4.0.0

- **Lavagna Tattica Riscritta**: TacticalBoard.vue dedicato con coordinate percentuali (0-100), 3 modalità campo (intero, metà, vuoto), undo/redo completo, drag & drop, resize frecce con handle, pannello modifica colore, auto-switch tool dopo piazzamento
- **Catalogo Esercizi con Anteprima**: Miniatura campo da calcio con elementi visualizzati per ogni esercizio
- **Segreteria Panoramica**: Nuova pagina panoramica categoria con statistiche e pagina dettagli iscritti
- **Autorizzazione Backend**: Controllo permessi su save_allenamento (admin/super_admin/mister)
- **Layout Full-Width**: Pagine Allenamenti e Catalogo occupano tutta la larghezza
- **Bug Fix**: Primo oggetto modificabile, click day chip funzionante, gomma elimina tutti i tipi, frecce resize corretto

### Novità v3.1.0

- **Sistema Pagamenti Completo**: Tabella pagamenti in Segreteria (Totale, Iscrizione, Rate 1-4, Saldo, Rimane), campi editabili inline con calcolo automatico
- **Scheda Giocatore**: Vista completa con dati personali, contatti, genitori, anamnesi, equipaggiamento, pagamenti e stampa PDF
- **Form Preiscrizione Online**: Il segretario genera un link precompilato che i genitori possono compilare online
- **Eliminazione Giocatori**: Bottone cestino in Segreteria con conferma
- **Aggiornamento Parziale Backend**: Solo i campi inviati vengono modificati, campi vuoti gestiti come NULL

### Novità v2.1.0

- **Catalogo Esercizi**: Nuovo sistema per salvare e riutilizzare esercizi
- **Dialog Selezione Multipla**: Possibilità di scegliere quali esercizi salvare nel catalogo
- **Permessi**: SuperAdmin può eliminare tutti gli esercizi, utenti normali solo i propri
- **Pulsante "Salva nel Catalogo"**: Nuovo pulsante nella toolbar per salvare esercizi

### Novità v2.0.0

- **Mobile Optimizations**: Menu hamburger responsive, scroll automatico, messaggio rotazione dispositivo
- **PDF Export**: Nuovo sistema con header due loghi, categoria in oro, ottimizzato per smartphone
- **Security**: Rimozione file sensibili (.env) dal repository Git
- **Bug Fixes**: Grafica coni aggiornata, elementi mancanti nell'export PDF

---

**Come creare una release:**

```bash
# Minor release (es. 1.0.0 → 1.1.0)
./release.sh minor "Descrizione novità"

# Major release (es. 1.0.0 → 2.0.0)
./release.sh major "Grandi novità"
```

Le release vengono salvate nella cartella `releases/vX.X.X/` per i rollback.

---

## Credenziali

Le credenziali sono configurate nel database. Contattare l'amministratore per l'accesso.

## Funzionalità

### Gestione Categorie
- ✅ Creazione/modifica/eliminazione categorie
- ✅ Campo anno di nascita (es. 2014)
- ✅ Campo stagione calcistica (es. 2025 per 2025/2026)
- ✅ Giorni di allenamento
- ✅ Categoria speciale **Portieri** (cross-year)
- ✅ Colori distintivi per Mister (rosso) e Dirigenti (blu)

### Registro Presenze
- ✅ Registro con codici: X (presente), P (permesso), R (recupero), A (assente), AG (assente giustificato), AI (infortunio)
- ✅ Statistiche mensili e totali
- ✅ Raggruppamento per gruppi di allenamento

### Dati & Matricole
- ✅ Tabella giocatori completa (nome, cognome, nr. maglia, data nascita, codice fiscale, telefono, matricola, scadenza certificato, gruppo)
- ✅ Ricerca per nome, cognome o matricola
- ✅ Filtro per gruppo di allenamento
- ✅ CRUD completo: creare, modificare, eliminare giocatori
- ✅ Evidenziazione righe con certificato scaduto (arancione)
- ✅ Protezione **GDPR**: dati sensibili (CF, telefono, data nascita) nascosti dietro password

### Allenamenti (Lavagna Tattica)
- ✅ Campo da calcio realistico con percentuali
- ✅ **Libreria oggetti sportivi** (3 set):
  - Set 1: Palloni, Coni, Paletti, Bandierine, Dischi, Anelli, Scale, Porte
  - Set 2: Ostacoli, Telai, Attrezzi fitness, Palloni sport vari
  - Set 3: Barre, Griglie, Piattaforme
- ✅ **Frecce tattiche calcio** (5 tipi):
  - Passaggio (linea continua)
  - Conduzione palla (tratteggiata)
  - Combinazione a muro (bidirezionale)
  - Tiro in porta (spessa)
  - Movimento senza palla (termina con pallino)
- ✅ Frecce ruotabili, allungabili, ondolabili
- ✅ Personalizzazione colore frecce
- ✅ **Catalogo Esercizi**: Salva, riutilizza e condividi esercizi tra allenatori
- ✅ **Filtro Focus**: Filtra esercizi per tipo (tecnica, tattica, fisico, ecc.)

### Convocazioni
- ✅ Creazione e gestione convocazioni multiple per evento
- ✅ Assegnazione giocatori con posizione in lista
- ✅ Dettagli gara (data, ora, campo, indirizzo, appuntamento)
- ✅ Dati mister con cellulare
- ✅ Note per la convocazione
- ✅ **Esportazione PDF** professionale

### Stagioni Calcistiche
- ✅ Impostazione stagione corrente per tutte le categorie
- ✅ **Inizio/Fine Stagione** globali (valgono per tutte le categorie)
- ✅ Stagione corrente visualizzata nella navbar
- ✅ Archiviazione stagione a fine anno
- ✅ Visualizzazione stagioni passate (solo admin)
- ✅ Ripristino stagione archiviata

### Amministrazione
- ✅ Gestione utenti e permessi
- ✅ Assegnazione categorie agli utenti (mister/dirigente/admin)
- ✅ Ruolo admin con funzionalità avanzate

## Database

### Schema Categorie

```sql
categorie (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(100),
  anno INTEGER,
  stagione INTEGER,
  giorni VARCHAR(20),
  is_portieri INTEGER DEFAULT 0,
  is_archiviata INTEGER DEFAULT 0,
  data_inizio_stagione DATE,
  data_fine_stagione DATE,
  societa_id INTEGER REFERENCES societa(id)
)
```

### Schema Persone

```sql
persone (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(100),
  cognome VARCHAR(100),
  gruppo_id INTEGER,
  categoria_id INTEGER,
  data_nascita DATE,
  codice_fiscale VARCHAR(16),
  tel_papa TEXT,
  tel_mamma TEXT,
  matricola VARCHAR(50),
  numero_maglia INTEGER,
  scadenza_certificato DATE
)
```

## API Endpoints

### Auth
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| POST | `/auth/token` | Login |
| GET | `/auth/me` | Info utente corrente |
| GET | `/auth/utenti` | Lista utenti (admin) |
| POST | `/auth/utenti` | Crea utente (admin) |
| PUT | `/auth/utenti/:id` | Modifica utente (admin) |
| DELETE | `/auth/utenti/:id` | Elimina utente (admin) |

### Categorie
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/categorie/` | Lista categorie attive |
| POST | `/categorie/` | Crea categoria |
| PUT | `/categorie/:id` | Modifica categoria |
| DELETE | `/categorie/:id` | Elimina categoria |

### Persone
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/persone/` | Lista persone per categoria |
| POST | `/persone/` | Crea persona |
| PUT | `/persone/:id` | Modifica persona |
| DELETE | `/persone/:id` | Elimina persona |

### Registro
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/registro/mese/:catId/:anno/:mese` | Presenze mese |
| POST | `/registro/` | Inserisci/modifica presenza |

### Allenamenti
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/allenamenti/` | Lista allenamenti |
| GET | `/allenamenti/giorno/:catId/:data` | Dettagli giorno |
| POST | `/allenamenti/` | Salva allenamenti |
| GET | `/allenamenti/catalogo-new` | Lista esercizi dal catalogo |
| POST | `/allenamenti/catalogo-new` | Salva esercizio nel catalogo |
| DELETE | `/allenamenti/catalogo-new/:id` | Elimina esercizio (con permessi) |
| GET | `/allenamenti/focus-list` | Lista focus disponibili |

### Convocazioni
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/convocazioni/` | Lista convocazioni |
| GET | `/convocazioni/:id` | Dettagli |
| POST | `/convocazioni/` | Crea |
| PUT | `/convocazioni/:id` | Modifica |
| DELETE | `/convocazioni/:id` | Elimina |

### Società
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/societa/` | Lista società |
| GET | `/societa/:id` | Dettagli |
| POST | `/societa/` | Crea (super_admin) |
| PUT | `/societa/:id` | Modifica |

## Multi-Società

Il sistema supporta la **gestione di più società sportive** con dati isolati.

### Ruoli Utente

| Ruolo | Descrizione |
|-------|-------------|
| super_admin | Accesso completo a TUTTE le società |
| admin | Accesso alla propria società assegnata |
| mister | Accesso alle proprie categorie assegnate |
| dirigente | Accesso in sola lettura alle statistiche |

### Funzionalità

- ✅ **SuperAdmin**: crea/modifica tutte le società
- ✅ **Admin locale**: modifica solo la propria società
- ✅ **Isolamento dati**: utenti, categorie, giocatori associati a società
- ✅ **Tema dinamico**: colori società applicati a tutte le pagine

## Workflow Stagioni

1. **Inizio stagione** (settembre): Admin clicca "Imposta Stagione" (anno + date inizio/fine)
2. **Durante stagione**: utilizzo normale
3. **Fine stagione** (giugno): Admin clicca "Archivia Stagione"
4. Le categorie passano in "Stagioni Passate"
5. Ricomincia da 1 con la nuova stagione

## Licenza

MIT
