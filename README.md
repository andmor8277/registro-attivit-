# Red Tigers - Registro Presenze

Sistema di gestione presenze per la squadra Red Tigers.

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
│   │   ├── components/ # Componenti riutilizzabili
│   │   ├── api/       # Chiamate API
│   │   └── store.js   # State management
│   ├── public/        # Asset statici
│   └── mock-server.js  # Server mock per sviluppo locale
├── backend/           # Backend FastAPI
│   └── app/
│       ├── routers/   # API routes
│       ├── models.py  # Modelli database
│       └── schemas.py # Pydantic schemas
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

- **Produzione**: https://presenzored.crickethouse.mywire.org
- **Locale**: http://localhost:5173

## Credenziali

| Utente | Password | Ruolo |
|--------|---------|-------|
| admin | admin123 | Amministratore |

## Funzionalità

### Gestione Categorie
- ✅ Creazione/modifica/eliminazione categorie
- ✅ Campo anno di nascita (es. 2014)
- ✅ Campo stagione calcistica (es. 2025 per 2025/2026)
- ✅ Giorni di allenamento
- ✅ Categoria speciale **Portieri** (cross-year)

### Stagioni Calcistiche
- ✅ Impostazione stagione corrente per tutte le categorie
- ✅ Stagione corrente visualizzata nella navbar
- ✅ Archiviazione stagione a fine anno
- ✅ Visualizzazione stagioni passate (solo admin)
- ✅ Ripristino stagione archiviata

### Registro Presenze
- ✅ Registro con codici: X (presente), P (permesso), R (recupero), A (assente), AG (assente giustificato), AI (infortunio)
- ✅ Statistiche mensili e totali
- ✅ Gestione persone/giocatori
- ✅ Raggruppamento per gruppi di allenamento

### Convocazioni
- ✅ Creazione e gestione convocazioni
- ✅ Assegnazione giocatori
- ✅ Dettagli gara (data, ora, campo, appuntamento)

### Amministrazione
- ✅ Gestione utenti e permessi
- ✅ Assegnazione categorie agli utenti
- ✅ Ruolo admin con funzionalità avanzate

## Database

### Schema Categorie

```sql
categorie (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(100),           -- Es. "Esordienti"
  anno INTEGER,               -- Anno di nascita (es. 2014), NULL per portieri
  stagione INTEGER,            -- Anno inizio stagione (es. 2025 per 2025/2026)
  giorni VARCHAR(20),         -- Giorni allenamento (es. "1,3,5" = Lun,Mer,Ven)
  is_portieri INTEGER DEFAULT 0,  -- 1 = portieri (cross-year)
  is_archiviata INTEGER DEFAULT 0  -- 1 = stagione archiviata
)
```

### Migrazioni

Le migrazioni vengono eseguite automaticamente durante il deploy. Per eseguirle manualmente:

```bash
# Sul server LXC
cd /opt/registro_presenze
docker compose exec -T db psql -U registro_user -d registro -f migrations/add_stagione_fields.sql
```

## API Endpoints

### Auth
| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| POST | `/auth/token` | Login |
| GET | `/auth/me` | Info utente corrente |
| GET | `/auth/utenti` | Lista utenti (admin) |
| POST | `/auth/utenti` | Crea utente (admin) |
| DELETE | `/auth/utenti/:id` | Elimina utente (admin) |
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

## Workflow Stagioni

1. **Inizio stagione** (settembre): Admin clicca "Imposta Stagione" e inserisce l'anno (es. 2025)
2. **Durante stagione**:正常使用
3. **Fine stagione** (giugno/luglio): Admin clicca "Archivia Stagione"
4. Le categorie passano in "Stagioni Passate" e non sono più visibili nella home
5. Ricomincia da 1 con la nuova stagione

## Licenza

MIT
