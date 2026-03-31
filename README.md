# The Home of Football

Sistema di gestione di una squadradi calcio dilettantistico

## Stack Tecnologico

- **Frontend**: Vue 3 + Vite
- **Backend**: FastAPI (Python)
- **Database**: PostgreSQL
- **Container**: Docker Compose
- **PDF**: jsPDF

## Struttura del Progetto

```
registro_presenze/
├── frontend/           # Frontend Vue 3
│   ├── src/
│   │   ├── views/     # Pagine dell'applicazione
│   │   ├── components/ # Componenti riutilizzabili
│   │   ├── api/       # Chiamate API
│   │   └── store.js   # State management
│   ├── public/        # Asset statici (logo, etc.)
│   └── mock-server.js # Server mock per sviluppo locale
├── backend/           # Backend FastAPI
│   └── app/
│       ├── routers/   # API routes
│       ├── models.py  # Modelli database
│       └── main.py    # Entry point FastAPI
├── migrations/        # Script di migrazione database
├── docker-compose.yml
├── dev.sh             # Script sviluppo locale
└── deploy.sh          # Script deploy produzione
```

## Setup Locale

### Requisiti

- Node.js 18+
- npm o yarn
- Docker (per il server di produzione)

### Sviluppo Locale (con Mock API)

```bash
# Avvia il server di sviluppo con API mock (senza bisogno di VPN)
./dev.sh
```

- **Frontend**: http://localhost:5173
- **API Mock**: http://localhost:8000
- **Login**: `admin` / `admin123`

### Deploy in Produzione

```bash
# Deploy sul server LXC
./deploy.sh
```

Questo comando:
1. Fa pull delle ultime modifiche dal repository
2. Esegue le migrazioni database se necessario
3. Ricostruisce i container Docker
4. Riavvia i servizi

## Accesso

- **Produzione**: https://redtigers1957.crickethouse.mywire.org
- **Locale**: http://localhost:5173

## Credenziali

Le credenziali sono configurate nel database. Contattare l'amministratore per l'accesso.

## Funzionalità

### Gestione Categorie
- ✅ Creazione/modifica/eliminazione categorie
- ✅ Campo anno di nascita (es. 2014)
- ✅ Campo stagione calcistica (es. 2025 per 2025/2026)
- ✅ Giorni di allenamento
- ✅ Categoria speciale **Portieri** (cross-year)
- ✅ **Google Drive Folder ID** per integrare la cartella allenamenti

### Registro Presenze
- ✅ Registro con codici: X (presente), P (permesso), R (recupero), A (assente), AG (assente giustificato), AI (infortunio)
- ✅ Statistiche mensili e totali
- ✅ Raggruppamento per gruppi di allenamento
- ✅ Visualizzazione nastrata per categoria

### Dati & Matricole
- ✅ Tabella giocatori completa (nome, cognome, nr. maglia, data nascita, codice fiscale, telefono, matricola, scadenza certificato, gruppo)
- ✅ Ricerca per nome, cognome o matricola
- ✅ Filtro per gruppo di allenamento
- ✅ **CRUD completo**: creare, modificare, eliminare giocatori
- ✅ Evidenziazione righe con certificato scaduto o assente (arancione)

### Allenamenti
- ✅ Integrazione **Google Drive** per la cartella allenamenti
- ✅ Iframe per visualizzare i file della cartella Drive
- ✅ Link diretto per aprire Google Drive e modificare i file

### Convocazioni
- ✅ Creazione e gestione convocazioni multiple per evento
- ✅ Assegnazione giocatori con posizione in lista
- ✅ Dettagli gara (data, ora, campo, indirizzo, appuntamento)
- ✅ Dati mister con cellulare
- ✅ Note per la convocazione
- ✅ **Esportazione PDF** con layout professionale (header rosso, dati gare, lista convocati)

### Stagioni Calcistiche
- ✅ Impostazione stagione corrente per tutte le categorie
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
  nome VARCHAR(100),              -- Es. "Esordienti"
  anno INTEGER,                   -- Anno di nascita (es. 2014), NULL per portieri
  stagione INTEGER,               -- Anno inizio stagione (es. 2025 per 2025/2026)
  giorni VARCHAR(20),              -- Giorni allenamento (es. "1,3,5" = Lun,Mer,Ven)
  is_portieri INTEGER DEFAULT 0,  -- 1 = portieri (cross-year)
  is_archiviata INTEGER DEFAULT 0,-- 1 = stagione archiviata
  drive_folder_id VARCHAR(100)    -- Google Drive folder ID
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
  telefono VARCHAR(20),
  matricola VARCHAR(50),
  numero_maglia INTEGER,
  scadenza_certificato DATE
)
```

### Migrazioni

Le migrazioni vengono eseguite automaticamente durante il deploy. Per eseguirle manualmente:

```bash
# Sul server LXC
cd /opt/registro_presenze
docker compose exec -T db psql -U registro_user -d registro -f migrations/001_add_drive_folder.sql
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
| PUT | `/auth/utenti/:id/reset-password` | Reset password |
| PUT | `/auth/utenti/:id/categorie` | Assegna categorie |

### Categorie
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/categorie/` | Lista categorie attive |
| POST | `/categorie/` | Crea categoria |
| PUT | `/categorie/:id` | Modifica categoria |
| DELETE | `/categorie/:id` | Elimina categoria (admin) |
| GET | `/categorie/stagioni` | Lista stagioni attive/archiviate |
| POST | `/categorie/archivia/:stagione` | Archivia stagione (admin) |
| POST | `/categorie/ripristina/:stagione` | Ripristina stagione (admin) |
| GET | `/categorie/archived` | Categorie archiviate (admin) |
| GET | `/categorie/by-stagione/:stagione` | Categorie per stagione |

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

### Convocazioni
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/convocazioni/` | Lista convocazioni |
| GET | `/convocazioni/:id` | Dettagli convocazione |
| POST | `/convocazioni/` | Crea convocazione |
| PUT | `/convocazioni/:id` | Modifica convocazione |
| DELETE | `/convocazioni/:id` | Elimina convocazione |

### Allenatori
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/allenatori/` | Lista allenatori |
| POST | `/allenatori/` | Crea allenatore |
| PUT | `/allenatori/:id` | Modifica allenatore |
| DELETE | `/allenatori/:id` | Elimina allenatore |

### Società
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/societa/` | Lista società |
| GET | `/societa/:id` | Dettagli società |
| POST | `/societa/` | Crea società (solo super_admin) |
| PUT | `/societa/:id` | Modifica società |
| DELETE | `/societa/:id` | Elimina società |
| POST | `/societa/upload/:tipo` | Upload logo (:tipo = logo/logosponsor) |

## Multi-Società

Il sistema supporta **multiple società sportive** con dati isolati:

### Ruoli Utente

| Ruolo | Descrizione |
|-------|-------------|
| super_admin | Accesso completo a TUTTE le società (crea società, gestisce tutto) |
| admin | Accesso alla propria società assegnata |
| mister | Accesso alle proprie categorie assegnate |
| dirigente | Accesso in sola lettura alle statistiche |

### Funzionalità Multi-Società

- ✅ **SuperAdmin**: può creare/modificare tutte le società
- ✅ **Admin locale**: può modificare solo la propria società (logo, colori)
- ✅ **Società**: ogni società ha i propri colori, logo, logo sponsor
- ✅ **Isolamento dati**: utenti, categorie, giocatori sono associati a una società
- ✅ **Tema dinamico**: i colori della società vengono applicati a tutte le pagine

### Schema Società

```sql
societa (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(100),              -- Nome completo (es. "RedTigers 1957")
  nome_breve VARCHAR(50),          -- Nome breve (es. "RedTigers")
  logo VARCHAR(255),               -- Path logo società
  logosponsor VARCHAR(255),        -- Path logo sponsor
  colore_primario VARCHAR(7),     -- Colore hex (es. "#dc2626")
  colore_secondario VARCHAR(7),   -- Colore hex secondario
  is_attiva INTEGER DEFAULT 1    -- 1 = attiva
)
```

### Schema Utenti (aggiornato)

```sql
utenti (
  ...
  societa_id INTEGER REFERENCES societa(id),  -- Società di appartenenza
  is_super_admin INTEGER DEFAULT 0            -- 1 = super admin
)
```

### Schema Categorie (aggiornato)

```sql
categorie (
  ...
  societa_id INTEGER REFERENCES societa(id)   -- Società di appartenenza
)
```

## Workflow Stagioni

1. **Inizio stagione** (settembre): Admin clicca "Imposta Stagione" e inserisce l'anno (es. 2025)
2. **Durante stagione**: Utilizzo normale del sistema
3. **Fine stagione** (giugno/luglio): Admin clicca "Archivia Stagione"
4. Le categorie passano in "Stagioni Passate" e non sono più visibili nella home
5. Ricomincia da 1 con la nuova stagione

## Integrazione Google Drive

Per abilitare la visualizzazione della cartella Drive nella pagina Allenamenti:

1. In Home, clicca su una categoria → Modifica
2. Inserisci l'ID della cartella Google Drive
3. L'ID si trova nella URL della cartella: `drive.google.com/drive/folders/`**`1a2b3c4d`**
4. Nella pagina Allenamenti apparirà la cartella embedded

## Licenza

MIT
