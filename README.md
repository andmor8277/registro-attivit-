# Red Tigers Home

Sistema di gestione presenze per la squadra Red Tigers.

## Stack Tecnologico

- **Frontend**: Vue 3 + Vite
- **Backend**: FastAPI (Python)
- **Database**: PostgreSQL
- **Container**: Docker Compose

## Struttura del Progetto

```
registro_presenze/
├── frontend/          # Frontend Vue 3
│   ├── src/
│   │   ├── views/    # Pagine dell'applicazione
│   │   ├── components/  # Componenti riutilizzabili
│   │   ├── api/      # Chiamate API
│   │   └── store.js  # State management
│   ├── public/       # Asset statici
│   └── mock-server.js # Server mock per sviluppo locale
├── backend/          # Backend FastAPI
│   └── app/
│       ├── routers/  # API routes
│       ├── models.py # Modelli database
│       └── schemas.py # Pydantic schemas
└── docker-compose.yml
```

## Setup Locale

### Requisiti

- Node.js 18+
- npm o yarn
- Docker (per il server di produzione)

### Installazione

```bash
# Clona il repository
git clone https://github.com/andmor8277/registro-attivit-.git
cd registro-attivit-

# Installa dipendenze frontend
cd frontend
npm install
```

### Sviluppo Locale (con Mock API)

```bash
# Avvia il server di sviluppo con API mock (senza bisogno di VPN)
./dev.sh
```

Accedi a http://localhost:5173
- Login: `admin` / `admin123`

### Setup Produzione

```bash
# Deploy sul server
./deploy.sh
```

Questo comando:
1. Fa pull delle ultime modifiche
2. Ricostruisce i container Docker
3. Riavvia i servizi

## Accesso

- **Produzione**: https://presenzered.crickethouse.mywire.org
- **Locale**: http://localhost:5173

## Credenziali

| Utente | Password | Ruolo |
|--------|---------|-------|
| admin | admin123 | Amministratore |

## Funzionalità

- ✅ Gestione categorie (annuali, squadre)
- ✅ Registro presenze con codici (X, P, R, A, AG, AI)
- ✅ Gestione persone/giocatori
- ✅ Raggruppamento per gruppi di allenamento
- ✅ Statistiche mensili e totali
- ✅ Gestione utenti e permessi
- ✅ Convocazioni

## API Endpoints

### Auth
- `POST /auth/token` - Login
- `GET /auth/me` - Info utente corrente
- `GET /auth/utenti` - Lista utenti (admin)
- `POST /auth/utenti` - Crea utente (admin)

### Categorie
- `GET /categorie/` - Lista categorie
- `POST /categorie/` - Crea categoria
- `PUT /categorie/:id` - Modifica categoria
- `DELETE /categorie/:id` - Elimina categoria

### Registro
- `GET /registro/mese/:catId/:anno/:mese` - Presenze mese
- `POST /registro/` - Inserisci/modifica presenza

## Licenza

MIT
