# The Home of Football — Documentazione Tecnica del Progetto

> Sistema di gestione multi-società per club sportivi dilettantistici (calcio).
>
> **Repository**: `github.com/andmor8277/registro-attivit-`
> **URL Produzione**: `https://thof.crickethouse.mywire.org`
> **Ultimo aggiornamento**: 2026-08-07

---

## Indice

1. [Panoramica](#1-panoramica)
2. [Architettura](#2-architettura)
3. [Stack Tecnologico](#3-stack-tecnologico)
4. [Struttura del Progetto](#4-struttura-del-progetto)
5. [Backend — FastAPI](#5-backend--fastapi)
6. [Database — PostgreSQL](#6-database--postgresql)
7. [Frontend — Vue 3](#7-frontend--vue-3)
8. [Sistema di Autenticazione](#8-sistema-di-autenticazione)
9. [Crittografia PII](#9-crittografia-pii)
10. [Rate Limiting](#10-rate-limiting)
11. [Docker e Deployment](#11-docker-e-deployment)
12. [Sicurezza](#12-sicurezza)
13. [Script di Automazione](#13-script-di-automazione)
14. [Ruoli e Permessi](#14-ruoli-e-permessi)
15. [Mappe delle Rotte](#15-mappe-delle-rotte)

---

## 1. Panoramica

THOF ("The Home of Football") è un'applicazione web multi-tenant per la gestione di società sportive dilettantistiche. Ogni società ha i propri dati isolati (categorie, giocatori, presenze, allenamenti, partite), ma condivide la stessa istanza backend e database.

### Funzionalità principali

- **Gestione multi-società**: un super admin gestisce più società; ogni società ha un admin locale
- **Categorie e gruppi**: gerarchia categorie (Agonistica / Scuola Calcio) con gruppi interni
- **Registro presenze**: calendario mensile con codici presenza (X, AG, AI, I, R)
- **Convocazioni**: liste giocatori per gara con posizioni e esclusioni
- **Allenamenti**: lavagna tattica con catalogo esercizi e schede GPS
- **Partite e weekend**: programmazione gare, assegnazione spogliatoi e campi
- **Segreteria**: anagrafica giocatori, pagamenti, certificati medici
- **Infermeria**: gestione infortuni e certificati medici
- **Valutazioni**: valutazione tecnica giocatori su 10 parametri
- **Open Day**: gestione iscrizioni prove
- **Planning eventi**: sospensioni, vacanze, feste, gare
- **Schede allenamento GPS**: metriche training (distanza, velocità, accelerazioni, RPE)

---

## 2. Architettura

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENTE (Browser)                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Vue 3 + Vite (SPA) — Dark theme, responsive              │  │
│  │  · Store ref-based (no Pinia)                             │  │
│  │  · Axios con JWT interceptor                              │  │
│  │  · Chart.js per grafici GPS                               │  │
│  └──────────────────┬────────────────────────────────────────┘  │
└─────────────────────┼───────────────────────────────────────────┘
                      │ HTTPS / HTTP
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  PRODUZIONE: Nginx (host) → reverse proxy                       │
│  DEV: Vite dev server (5173) → proxy /api → localhost:8000      │
└─────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  BACKEND: FastAPI + Uvicorn (4 workers in prod)                 │
│  · Middleware: CORS, Security Headers, Rate Limiting            │
│  · 22 Routers API (auth, persone, registro, categorie, ...)    │
│  · SQLAlchemy ORM con 25+ tabelle                               │
│  · pgcrypto AES per PII encryption                              │
└─────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  DATABASE: PostgreSQL 16 (Docker volume pgdata)                 │
│  · Estensione pgcrypto per crittografia AES                     │
│  · Multi-tenant via societa_id su ogni tabella                   │
└─────────────────────────────────────────────────────────────────┘
```

### Ambiente di sviluppo locale

```
HOST MACHINE
  PostgreSQL :5433 (/tmp/pgdata)  │  Uvicorn :8000 (tmux)  │  Vite :5173 (tmux)
       ▲                               │                         │
       └───────────────────────────────┼─────────────────────────┘
                                       │ proxy /api
```

---

## 3. Stack Tecnologico

| Livello | Tecnologia | Note |
|---------|-----------|------|
| **Frontend** | Vue 3 | Composition API, script setup |
| **Build** | Vite | HMR in dev |
| **Router** | Vue Router 4 | History mode, auth guard |
| **HTTP Client** | Axios | JWT interceptor, redirect 401 |
| **Grafici** | Chart.js | Dark theme |
| **Backend** | FastAPI | Python 3, async |
| **Server** | Uvicorn | 4 workers in produzione |
| **ORM** | SQLAlchemy 2.0 | Declarative base |
| **DB** | PostgreSQL 16 | pgcrypto, JSONB |
| **Rate Limit** | slowapi 0.1.9 | Per-worker, IP-based |
| **Auth** | python-jose (JWT) | HS256, 60 min expiry |
| **Password** | passlib[bcrypt] | bcrypt 4.0.1 (pinato) |
| **Container** | Docker Compose | 3 servizi: db, backend, frontend |
| **Web Server** | Nginx | Reverse proxy (prod), static (container) |

---

## 4. Struttura del Progetto

```
registro_presenze/
├── .env                    # Variabili d'ambiente (gitignored)
├── .env.example            # Template
├── .gitignore              # Ignora .env*, __pycache__, secrets.lst
├── AGENTS.md               # Guida per AI assistant
├── CHANGELOG.md            # Storico versioni
├── guida_utente.html       # Documentazione utente v5.4.0
├── init.sql                # Seed: gruppi, codici presenza
│
├── docker-compose.yml      # Composizione base (3 servizi)
├── docker-compose.dev.yml  # Override dev
├── docker-compose.prod.yml # Override prod
│
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── main.py              # Entry point, middleware, migrations, routers
│       ├── database.py          # SQLAlchemy engine, session factory
│       ├── models.py            # 25+ ORM models
│       ├── schemas.py           # Pydantic schemas
│       ├── rate_limit.py        # slowapi limiter
│       └── routers/             # 22 API routers
│           ├── auth.py          # Login, JWT, utenti, ruoli
│           ├── persone.py       # CRUD giocatori + crittografia PII
│           ├── registro.py      # Presenze calendario
│           ├── categorie.py     # Categorie, stagioni, archiviazione
│           ├── gruppi.py        # Gruppi interni categoria
│           ├── allenamenti.py   # Allenamenti, lavagna tattica, catalogo
│           ├── convocazioni.py  # Convocazioni gare
│           ├── partite.py       # Programmazione partite
│           ├── weekend.py       # Weekend torneistici
│           ├── spogliatoi.py    # Assegnazione spogliatoi
│           ├── campi.py         # Assegnazione campi
│           ├── allenatori.py    # Gestione allenatori
│           ├── societa.py       # CRUD società
│           ├── valutazioni.py   # Valutazioni tecniche
│           ├── infortuni.py     # Gestione infortuni
│           ├── openday.py       # Open day
│           ├── planning_eventi.py # Eventi calendario
│           ├── schede_allenamento.py # Metriche GPS
│           ├── liste_tornei.py  # Liste torneo
│           ├── presenze_allenatori.py # Presenze staff
│           └── codici.py        # Codici presenza
│
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   ├── vite.config.js         # Proxy /api → localhost:8000
│   ├── index.html
│   ├── public/guida.html      # Guida utente in produzione
│   └── src/
│       ├── main.js            # App mount, router, auth guard
│       ├── store.js           # Stato globale (ref-based)
│       ├── global.css         # CSS variables, dark theme
│       ├── api/index.js       # Axios instance, tutti API calls
│       ├── views/             # 29 Vue pages
│       ├── components/        # TacticalBoard.vue, TacticalBoardSimple.vue
│       └── composables/       # useTacticalBoard.js
│
├── scripts/git-hooks/
│   ├── pre-commit         # Hook sicurezza
│   └── secrets.lst        # Stringhe da bloccare (gitignored)
│
├── migrations/                # SQL files
├── releases/                  # Snapshot versionati
│
├── start_dev.sh               # Avvia dev locale
├── deploy.sh                  # Deploy produzione
├── deploy_dev.sh              # Deploy dev server
├── release.sh                 # Crea release + tag
└── install-hooks.sh           # Installa git hook
```

---

## 5. Backend — FastAPI

### 5.1 Entry Point (`backend/app/main.py`)

Il file `main.py` è il cuore dell'applicazione backend. Configura:
- Middleware di sicurezza (HTTP headers)
- CORS per domini autorizzati
- Rate limiting globale
- Auto-migration del database
- Mount di tutti i router

```python
# backend/app/main.py (riassunto commentato)

from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
# ...

app = FastAPI(title="Registro Presenze API")
app.state.limiter = limiter                    # slowapi limiter
app.add_middleware(SlowAPIMiddleware)          # Rate limiting globale

# Handler per rate limit exceeded -> 429
@app.exception_handler(RateLimitExceeded)
async def rate_limit_exceeded_handler(request, exc):
    return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded"})

# Middleware sicurezza: inietta header HTTP su ogni risposta
@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"      # Blocca MIME sniffing
    response.headers["X-Frame-Options"] = "DENY"                # Blocca iframe (clickjacking)
    response.headers["X-XSS-Protection"] = "1; mode=block"      # XSS filter
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none'"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if "Server" in response.headers:
        del response.headers["Server"]            # Rimuove fingerprint server
    return response

# CORS: solo domini autorizzati
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://thof.crickethouse.mywire.org",  # Dominio produzione
        "http://localhost:5173",                  # Vite dev server
        "http://localhost:3000"                   # Nginx dev
    ],
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["Content-Disposition"]
)

# Upload statici: file caricati dagli utenti (loghi, documenti)
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Mount di tutti i router con auth dependency
app.include_router(auth_router)                                    # /auth (login pubblico)
app.include_router(societa.router, dependencies=[Depends(get_current_user)])
app.include_router(persone.router)                                # /persone (pubblico + privato)
app.include_router(registro.router, dependencies=[Depends(get_current_user)])
# ... 22 router totali

@app.get("/")
def root():
    return {"status": "ok"}
```

### 5.2 Auto-Migration (`run_migrations()`)

Il sistema NON usa Alembic. Le migration sono inline in `main.py:run_migrations()` e vengono eseguite automaticamente all'avvio del backend. Ogni blocco è idempotente:

```python
def run_migrations():
    with engine.connect() as conn:
        # Esempio: crea tabella societa se non esiste
        result = conn.execute(text(
            "SELECT table_name FROM information_schema.tables WHERE table_name = :tn"
        ), {"tn": "societa"})
        if result.fetchone() is None:
            conn.execute(text("""
                CREATE TABLE societa (
                    id SERIAL PRIMARY KEY,
                    nome VARCHAR(100) NOT NULL,
                    nome_breve VARCHAR(50),
                    logo VARCHAR(200),
                    logosponsor VARCHAR(200),
                    colore_primario VARCHAR(7) DEFAULT '#dc2626',
                    colore_secondario VARCHAR(7) DEFAULT '#1f2937',
                    is_attiva INTEGER DEFAULT 1
                )
            """))
            conn.commit()
            print("Migration: Created societa table")

        # Aggiunge societa_id alle tabelle esistenti (multi-tenant)
        for table in ALLOWED_TABLES:
            try:
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = :tn AND column_name = 'societa_id'"
                ), {"tn": table})
                if result.fetchone() is None:
                    conn.execute(text(
                        "ALTER TABLE " + table +
                        " ADD COLUMN societa_id INTEGER REFERENCES societa(id)"
                    ))
                    conn.commit()
            except Exception:
                pass
        # ... 30+ blocchi migration (categorie, partite, spogliatoi, campi, ecc.)
```

**Per aggiungere una nuova migrazione**: appendere un blocco `try/except` idempotente a `run_migrations()`. Verificare sempre l'esistenza della tabella/colonna prima di crearla.

### 5.3 Database Config (`backend/app/database.py`)

```python
# backend/app/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
import os

# Legge DATABASE_URL da .env (es. postgresql://user:pass@db:5432/registro)
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise ValueError("DATABASE_URL environment variable is required")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Dependency injection per FastAPI: crea/chiude sessione per ogni request
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### 5.4 Rate Limiting (`backend/app/rate_limit.py`)

```python
# backend/app/rate_limit.py
from slowapi import Limiter
from slowapi.util import get_remote_address

# Limiter globale, keyed per IP remoto
limiter = Limiter(key_func=get_remote_address)
```

I limiti sono **per worker** (4 workers in produzione = 4x il limite effettivo). Endpoint pubblici PII: `5/minute`. Login: `10/minute`.

---

## 6. Database — PostgreSQL

### 6.1 Modelli ORM (`backend/app/models.py`)

Ogni classe eredita da `Base` e mappa a una tabella PostgreSQL.

#### Societa — Multi-tenant root
```python
class Societa(Base):
    __tablename__ = "societa"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)           # "RedTigers 1957"
    nome_breve = Column(String(50))                      # "RedTigers"
    logo = Column(String(200))                           # Path nel filesystem
    logosponsor = Column(String(200))
    colore_primario = Column(String(7), default="#dc2626")  # CSS hex
    colore_secondario = Column(String(7), default="#1f2937")
    is_attiva = Column(Integer, default=1)
```

#### Categoria — Gerarchia con parent_id
```python
class Categoria(Base):
    __tablename__ = "categorie"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    nome = Column(String(100), nullable=False)           # "Under 14", "Piccoli Amici"
    anno = Column(Integer)                               # Anno di nascita (2014)
    stagione = Column(Integer)                           # Anno inizio stagione (2025)
    giorni = Column(String(20))                          # "1,3,5" = Lun,Mer,Ven
    ora_allenamento = Column(String(10))                 # "16:00"
    is_portieri = Column(Integer, default=0)             # 1 = portieri cross-category
    is_archiviata = Column(Integer, default=0)           # 1 = stagione archiviata
    parent_id = Column(Integer, ForeignKey("categorie.id"))  # Gerarchia
    data_inizio_stagione = Column(Date)
    data_fine_stagione = Column(Date)
```

**Gerarchia**: `Agonistica` e `Scuola Calcio` sono categorie padre (`parent_id IS NULL`). Le Under categorie hanno `parent_id` -> Agonistica.

#### Persona — Giocatore
```python
class Persona(Base):
    __tablename__ = "persone"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    gruppo_id = Column(Integer, ForeignKey("gruppi.id"))
    categoria_id = Column(Integer, ForeignKey("categorie.id"))
    data_nascita = Column(Date)
    codice_fiscale = Column(String(16))                  # Crittografato con pgcrypto
    matricola = Column(String(50))
    numero_maglia = Column(Integer)
    scadenza_certificato = Column(Date)
    residenza = Column(String(100))
    indirizzo = Column(String(200))
    cittadinanza = Column(String(50))
    tel_papa = Column(String(255))                       # Crittografato (255 per AES)
    tel_mamma = Column(String(255))                      # Crittografato
    email1 = Column(String(100))
    email2 = Column(String(100))
    prof_papa = Column(String(100))
    prof_mamma = Column(String(100))
    anamnesi = Column(Text)
    taglia = Column(String(10))
    note = Column(Text)
    nome_papa = Column(String(100))
    nome_mamma = Column(String(100))
    comune_nato = Column(String(100))
    # Pagamenti:
    totale_da_pagare = Column(Float)
    rata_iscrizione = Column(Float)
    rata1 = Column(Float)
    rata2 = Column(Float)
    rata3 = Column(Float)
    rata4 = Column(Float)
    rata_saldo = Column(Float)
```

#### Utente — Account accesso
```python
class Utente(Base):
    __tablename__ = "utenti"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    username = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(200), nullable=False)   # bcrypt
    is_admin = Column(Integer, default=0)
    is_super_admin = Column(Integer, default=0)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    data_nascita = Column(Date, nullable=False)
    codice_fiscale = Column(String(16), nullable=False)
    cellulare = Column(String(50), nullable=False)
    tesserino = Column(String(50))
    ruolo = Column(String(20))                           # admin, mister, dirigente, segreteria, infermeria
```

#### Registro — Presenza
```python
class Registro(Base):
    __tablename__ = "registro"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    data = Column(Date, nullable=False)
    codice = Column(String(5), ForeignKey("codici.codice"))  # X, AG, AI, I, R
    categoria_id = Column(Integer, ForeignKey("categorie.id"))
    # UNIQUE constraint: (persona_id, data, categoria_id)
```

#### SchedaAllenamento — Metriche GPS
```python
class SchedaAllenamento(Base):
    __tablename__ = "schede_allenamento"
    id = Column(Integer, primary_key=True)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    data = Column(Date, nullable=False)
    distanza_totale = Column(Float)                       # Metri totali
    distanza_alta_velocita = Column(Float)                # >19.8 km/h
    distanza_sprint = Column(Float)                       # >25.2 km/h
    velocita_massima = Column(Float)                      # km/h
    accelerazioni = Column(Integer)                       # >3m/s²
    decelerazioni = Column(Integer)                       # >3m/s²
    metabolic_power = Column(Float)                       # W/kg
    player_load = Column(Float)                           # Unitario
    calorie = Column(Float)                               # kcal
    tempo_lavoro = Column(Integer)                        # Minuti
    rpe = Column(Integer)                                 # 1-10, Rate of Perceived Exertion
    note = Column(Text)
    creato_il = Column(DateTime)
```

#### Altri modelli chiave

| Modello | Tabella | Descrizione |
|---------|---------|-------------|
| `Gruppo` | `gruppi` | Sottogruppo categoria (1°Gruppo, Portieri) |
| `CodicePresenza` | `codici` | Codici: X, AG, AI, I, R |
| `Convocazione` | `convocazioni` | Lista convocazioni per periodo |
| `ConvocazioneGara` | `convocazione_gare` | Singola gara nella convocazione |
| `ConvocazioneGiocatore` | `convocazione_giocatori` | Giocatore in gara (posizione, non_presente) |
| `Allenatore` | `allenatori` | Allenatori esterni |
| `Allenamento` | `allenamenti` | Allenamento giornaliero (JSONB esercizi) |
| `AllenamentoMese` | `allenamenti_mese` | Struttura mese allenamenti |
| `AllenamentoSettimana` | `allenamenti_settimana` | Settimana dentro mese |
| `AllenamentoGiorno` | `allenamenti_giorno` | Giorno dentro settimana |
| `AllenamentoEsercizio` | `allenamenti_esercizio` | Esercizio dentro giorno |
| `AllenamentoElemento` | `allenamenti_elemento` | Elemento grafico lavagna (x, y, tipo, colore) |
| `CatalogoEsercizio` | `catalogo_esercizi` | Catalogo esercizi riutilizzabili |
| `Partita` | `partite` | Partita programmata |
| `Weekend` | `weekend` | Weekend torneistico |
| `Spogliatoio` | `spogliatoi` | Spogliatoio disponibile |
| `Campo` | `campi_da_gioco` | Campo da gioco |
| `PresenzaAllenatore` | `presenze_allenatori` | Presenza staff |
| `Valutazione` | `valutazioni` | Valutazione tecnica giocatore |
| `Infortunio` | `infortuni` | Infortunio giocatore |
| `Openday` | `openday` | Iscrizione open day |
| `PlanningEvento` | `planning_eventi` | Evento calendario |
| `ListaTorneo` | `liste_torneo` | Lista torneo |
| `UtenteCategoria` | `utente_categorie` | Associazione utente-categoria |

### 6.2 Seed (`init.sql`)

```sql
-- init.sql: eseguito al primo avvio del container PostgreSQL
INSERT INTO gruppi (nome) VALUES
  ('PRIMO GRUPPO'),('SECONDO GRUPPO'),('TERZO GRUPPO'),('PORTIERI')
ON CONFLICT DO NOTHING;

INSERT INTO codici (codice, descrizione, tipo) VALUES
  ('X',  'Presenza',             'presenza'),
  ('AG', 'Assente giustificato', 'assenza'),
  ('AI', 'Assente ingiustificato', 'assenza'),
  ('I', 'Infortunato',           'assenza'),
  ('R',  'Recupero altra cat.',  'extra')
ON CONFLICT DO NOTHING;
```

### 6.3 Multi-Tenant

Ogni tabella con dati sensibili ha `societa_id`. Ogni query backend filtra per `societa_id` dall'utente corrente. L'unico bypass è `is_super_admin = 1`.

---

## 7. Frontend — Vue 3

### 7.1 Entry Point (`frontend/src/main.js`)

```javascript
// frontend/src/main.js (commentato)
import { createApp } from 'vue'
import App from './App.vue'
import './global.css'

// Disabilita Service Worker legacy (PWA disabilitata -> evita cache stantie)
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(regs => {
    for (const reg of regs) reg.unregister()
  })
}

import { createRouter, createWebHistory } from 'vue-router'
import { useStore } from './store.js'
// ... 29 import views

const store = useStore()

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: Login, name: 'login' },
    { path: '/', component: Home, name: 'home', meta: { requiresAuth: true } },
    { path: '/allenatori', component: Allenatori, meta: { requiresAuth: true } },
    { path: '/responsabili', component: Responsabili, meta: { requiresAuth: true } },
    { path: '/responsabili/categorie', component: ResponsabiliCategoria, meta: { requiresAuth: true } },
    { path: '/responsabili/partite', component: ProgrammazionePartite, meta: { requiresAuth: true } },
    { path: '/responsabili/spogliatoi', component: Spogliatoi, meta: { requiresAuth: true } },
    { path: '/responsabili/presenze-allenatori', component: PresenzeAllenatori, meta: { requiresAuth: true } },
    { path: '/scelta/:id', component: Scelta, meta: { requiresAuth: true } },
    { path: '/registro/:id', component: Registro, meta: { requiresAuth: true } },
    { path: '/convocazioni/:id', component: Convocazioni, meta: { requiresAuth: true } },
    { path: '/dati/:id', component: DatiMatricole, meta: { requiresAuth: true } },
    { path: '/liste-tornei/:id', component: ListeTornei, meta: { requiresAuth: true } },
    { path: '/allenamenti/:id', component: Allenamenti, meta: { requiresAuth: true } },
    { path: '/scheda-allenamento/:id', component: SchedaAllenamento, meta: { requiresAuth: true } },
    { path: '/admin', component: Admin, meta: { requiresAuth: true, requiresSuperAdmin: true } },
    { path: '/admin/societa', component: Societa, meta: { requiresAuth: true } },
    { path: '/reportistica/:id', component: Reportistica, meta: { requiresAuth: true } },
    { path: '/segreteria', component: Segreteria, meta: { requiresAuth: true } },
    // ATTENZIONE: /segreteria/scheda/:id DEVE essere PRIMA di /segreteria/:id
    { path: '/segreteria/scheda/:id', component: SchedaGiocatore, meta: { requiresAuth: true } },
    { path: '/segreteria/:id', component: SegreteriaCategoria, meta: { requiresAuth: true } },
    { path: '/valutazioni/:id', component: Valutazioni, meta: { requiresAuth: true } },
    { path: '/infermeria', component: Infermeria, meta: { requiresAuth: true } },
    { path: '/infermeria/certificati', component: CertificatoMedico, meta: { requiresAuth: true } },
    { path: '/infermeria/infortunati', component: Infortunati, meta: { requiresAuth: true } },
    { path: '/segreteria/openday', component: Openday, meta: { requiresAuth: true } },
    { path: '/segreteria/presenze', component: PresenzeSegreteria, meta: { requiresAuth: true } },
    { path: '/form-iscrizione', component: FormOnlineIscrizione }  // Pubblico, no auth
  ]
})

// Auth guard: controlla token e ruoli prima di ogni navigazione
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  const user = store.utenteAttivo.value
  // Check canonico super_admin: flag o ruolo
  const isSuperAdmin = user?.is_super_admin || user?.ruolo === 'super_admin'

  // Richiede autenticazione?
  if (to.meta.requiresAuth && !token) return next('/login')

  // Se già loggato e non super_admin, non tornare su /login
  if (to.path === '/login' && token && !isSuperAdmin && !to.query.selezione) return next('/')

  // Richiede super admin?
  if (to.meta.requiresSuperAdmin) {
    if (!isSuperAdmin) return next('/')
  }

  // Richiede admin?
  if (to.meta.requiresAdmin) {
    const isAdmin = user?.is_admin || user?.ruolo === 'admin' || isSuperAdmin
    if (!isAdmin) return next('/')
  }

  // Redirect diretto da home per ruoli specifici
  if (to.path === '/') {
    if (user?.ruolo === 'mister') return next('/allenatori')
    if (user?.ruolo === 'segreteria') return next('/segreteria')
    if (user?.ruolo === 'infermeria') return next('/infermeria')
  }

  next()
})

createApp(App).use(router).mount('#app')
```

### 7.2 Store Globale (`frontend/src/store.js`)

```javascript
// frontend/src/store.js (commentato)
import { ref } from 'vue'

// Stato reattivo globale (ref-based, no Pinia)
const categoriaAttiva = ref(null)        // Categoria selezionata
const token = ref(localStorage.getItem('token') || null)
const utenteAttivo = ref(null)           // Dati utente corrente
const stagioneCorrente = ref(null)       // Stagione selezionata
const societaAttiva = ref(null)          // Società attiva (per super_admin)
const listaSocieta = ref([])             // Tutte le società (super_admin)
const hideTopbar = ref(false)            // Nasconde topbar in pagine full-screen

// Applica i colori della società come CSS custom properties
function applySocietaColors(societa) {
  if (societa && societa.colore_primario) {
    document.documentElement.style.setProperty('--color-primary', societa.colore_primario)
    // Calcola varianti dark/light dal colore primario
    const hex = societa.colore_primario.replace('#', '')
    const r = parseInt(hex.substring(0, 2), 16)
    const g = parseInt(hex.substring(2, 4), 16)
    const b = parseInt(hex.substring(4, 6), 16)
    const dark = `rgb(${Math.max(0, r-30)}, ${Math.max(0, g-30)}, ${Math.max(0, b-30)})`
    const light = `rgba(${r}, ${g}, ${b}, 0.3)`
    document.documentElement.style.setProperty('--color-primary-dark', dark)
    document.documentElement.style.setProperty('--color-primary-light', light)
  } else {
    // Colori default (rosso)
    document.documentElement.style.setProperty('--color-primary', '#dc2626')
    document.documentElement.style.setProperty('--color-primary-dark', '#b91c1c')
    document.documentElement.style.setProperty('--color-primary-light', 'rgba(220, 38, 38, 0.3)')
  }
}

export function useStore() {
  function setCategoria(cat) { categoriaAttiva.value = cat }
  function setToken(t) { token.value = t; localStorage.setItem('token', t) }
  function setStagioneCorrente(s) {
    stagioneCorrente.value = s
    if (s) localStorage.setItem('stagione_corrente', s)
    else localStorage.removeItem('stagione_corrente')
  }
  function setSocietaAttiva(s) {
    societaAttiva.value = s
    if (s && s.id) {
      localStorage.setItem('societa_id', s.id)
      localStorage.setItem('societa_data', JSON.stringify(s))
    } else {
      localStorage.removeItem('societa_id')
      localStorage.removeItem('societa_data')
    }
    applySocietaColors(s)  // Aggiorna colori tema
  }
  function setListaSocieta(list) { listaSocieta.value = list }
  function clearToken() {
    token.value = null
    utenteAttivo.value = null
    societaAttiva.value = null
    stagioneCorrente.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('societa_id')
    localStorage.removeItem('societa_data')
    localStorage.removeItem('stagione_corrente')
    localStorage.removeItem('is_super_admin')
    localStorage.removeItem('is_admin')
  }

  // Ripristina società salvata al reload
  const savedSocietaData = localStorage.getItem('societa_data')
  if (savedSocietaData) {
    try {
      societaAttiva.value = JSON.parse(savedSocietaData)
      applySocietaColors(societaAttiva.value)
    } catch (e) { /* fallback */ }
  }

  // Ripristina stagione salvata
  const savedStagione = localStorage.getItem('stagione_corrente')
  if (savedStagione) {
    try { stagioneCorrente.value = parseInt(savedStagione) } catch {}
  }

  return {
    categoriaAttiva, token, utenteAttivo, stagioneCorrente,
    societaAttiva, listaSocieta, hideTopbar,
    setCategoria, setToken, setStagioneCorrente, setSocietaAttiva,
    setListaSocieta, clearToken
  }
}
```

### 7.3 API Layer (`frontend/src/api/index.js`)

```javascript
// frontend/src/api/index.js (riassunto commentato)
import axios from 'axios'

// Istanza principale: include JWT su ogni request
export const api = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' })

// Interceptor request: inietta token JWT
api.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Interceptor response: redirect su /login se 401
api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      localStorage.removeItem('societa_id')
      localStorage.removeItem('societa_data')
      if (!window.location.pathname.includes('/login')) {
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

// --- Auth ---
export const login = (username, password) => {
  const form = new URLSearchParams()
  form.append('username', username)
  form.append('password', password)
  return api.post('/auth/token', form)
}
export const getMe = () => api.get('/auth/me')
export const getUtenti = (societaId) => api.get('/auth/utenti' + (societaId ? `?societa_id=${societaId}` : ''))
export const createUtente = (data) => api.post('/auth/utenti', data)
export const deleteUtente = (id) => api.delete(`/auth/utenti/${id}`)
export const updateUtente = (id, data) => api.put(`/auth/utenti/${id}`, data)
export const resetPassword = (id) => api.put(`/auth/utenti/${id}/reset-password`)
export const changePassword = (id, vecchia, nuova) => api.put(`/auth/utenti/${id}/password`, { vecchia, nuova })
export const assegnaCategorie = (uid, categoria_ids) => api.put(`/auth/utenti/${uid}/categorie`, { categoria_ids })

// --- Categorie ---
export const getCategorie = (societaId) => api.get('/categorie/' + (societaId ? `?societa_id=${societaId}` : ''))
export const createCategoria = (data) => api.post('/categorie/', data)
export const updateCategoria = (id, data) => api.put(`/categorie/${id}`, data)
export const deleteCategoria = (id) => api.delete('/categorie/' + id)
export const getStagioni = (societaId) => api.get('/categorie/stagioni' + (societaId ? `?societa_id=${societaId}` : ''))
export const archiviaStagione = (stagione) => api.post('/categorie/archivia/' + stagione)

// --- Persone (Giocatori) ---
export const getPersone = (categoriaId) => categoriaId ? api.get('/persone/?categoria_id=' + categoriaId) : api.get('/persone/')
export const createPersona = (data) => api.post('/persone/', data)
export const updatePersona = (id, data) => api.put('/persone/' + id, data)
export const deletePersona = (id) => api.delete('/persone/' + id)

// --- Registro Presenze ---
export const getCodici = () => api.get('/codici/')
export const getRegistroMese = (categoriaId, anno, mese) => api.get('/registro/mese/' + categoriaId + '/' + anno + '/' + mese)
export const upsertRegistro = (entry) => api.post('/registro/', entry)

// --- Convocazioni ---
export const getConvocazioni = (categoriaId) => api.get('/convocazioni/?categoria_id=' + categoriaId)
export const createConvocazione = (data) => api.post('/convocazioni/', data)
export const updateConvocazione = (id, data) => api.put(`/convocazioni/${id}`, data)
export const deleteConvocazione = (id) => api.delete(`/convocazioni/${id}`)

// --- Allenamenti ---
export const getAllenamentiMesi = (categoriaId) => api.get('/allenamenti/mese/' + categoriaId)
export const getAllenamentiSettimane = (meseId) => api.get('/allenamenti/settimana/' + meseId)
export const getAllenamentiGiorni = (giornoId) => api.get('/allenamenti/giorno/' + giornoId)
export const getAllenamentiEsercizi = (giornoId) => api.get('/allenamenti/esercizio/' + giornoId)
export const getCatalogoEsercizi = (focus = '') => api.get('/allenamenti/catalogo' + (focus ? '?focus=' + focus : ''))
export function saveAllenamenti(categoriaId, payload) { return api.post('/allenamenti/', payload) }

// --- Partite ---
export const getPartite = (categoriaId) => api.get('/partite/' + (categoriaId ? `?categoria_id=${categoriaId}` : ''))
export const creaPartita = (data) => api.post('/partite/', data)
export const aggiornaPartita = (id, data) => api.put(`/partite/${id}`, data)
export const eliminaPartita = (id) => api.delete(`/partite/${id}`)

// --- Weekend ---
export const getWeekend = (societaId) => api.get('/weekend/' + (societaId ? `?societa_id=${societaId}` : ''))
export const creaWeekend = (data) => api.post('/weekend/', data)

// --- Spogliatoi ---
export const getSpogliatoi = (societaId) => api.get('/spogliatoi/' + (societaId ? `?societa_id=${societaId}` : ''))
export const getAssegnazioniSettimana = (dataInizio) => api.get(`/spogliatoi/assegnazioni/settimana/${dataInizio}`)
export const creaAssegnazione = (data) => api.post('/spogliatoi/assegnazioni', data)

// --- Campi ---
export const getCampi = (societaId) => api.get('/campi/' + (societaId ? `?societa_id=${societaId}` : ''))
export const getCampiAssegnazioniSettimana = (dataInizio) => api.get(`/campi/assegnazioni/settimana/${dataInizio}`)

// --- Presenze Allenatori ---
export const getPresenzeAllenatoriMese = (anno, mese) => api.get(`/presenze-allenatori/mese/${anno}/${mese}`)
export const upsertPresenzaAllenatore = (entry) => api.post('/presenze-allenatori/', entry)

// --- Valutazioni ---
export const getValutazioni = (categoriaId) => api.get('/valutazioni/categoria/' + categoriaId)
export const updateValutazione = (id, data) => api.put('/valutazioni/' + id, data)

// --- Infortuni ---
export const getInfortuni = (params = {}) => {
  const qs = new URLSearchParams()
  if (params.categoria_id) qs.set('categoria_id', params.categoria_id)
  if (params.attivi !== undefined) qs.set('attivi', params.attivi)
  return api.get('/infortuni/?' + qs.toString())
}
export const creaInfortunio = (data) => api.post('/infortuni/', data)
export const chiudiInfortunio = (id) => api.post(`/infortuni/${id}/chiudi`)

// --- Open Day ---
export const getOpenday = () => api.get('/openday/')
export const creaOpenday = (data) => api.post('/openday/', data)
export const iscriviOpenday = (id) => api.post(`/openday/${id}/iscrivi`)

// --- Planning Eventi ---
export const getPlanningEventi = (categoria_id = null) => api.get('/planning-eventi/', { params: { categoria_id } })

// --- Schede Allenamento GPS ---
export const getSchedeAllenamento = (params = {}) => api.get('/schede-allenamento/', { params })
export const getSchedeTrend = (params) => api.get('/schede-allenamento/stats/trend', { params })
export const getSchedeSummary = (params) => api.get('/schede-allenamento/stats/summary', { params })
export const getSchedeTeam = (params) => api.get('/schede-allenamento/stats/team', { params })
export const getSchedePlayerTrend = (params) => api.get('/schede-allenamento/stats/player-trend', { params })

// --- Società ---
export const getSocieta = () => api.get('/societa/')
export const createSocieta = (data) => api.post('/societa/', data)
export const uploadSocietaFile = (tipo, file) => {
  const formData = new FormData()
  formData.append('file', file)
  return api.post(`/societa/upload/${tipo}`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })
}

// --- API Pubblica (senza JWT) ---
export const apiPublic = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' })
export const getPublicPersona = (id) => apiPublic.get(`/persone/public/${id}`)
export const createPublicPersona = (data) => apiPublic.post('/persone/public/', data)
export const updatePublicPersona = (id, data) => apiPublic.put(`/persone/public/${id}`, data)
```

### 7.4 Login (`frontend/src/views/Login.vue`)

Il componente Login gestisce due flussi:
1. **Login standard**: form username/password -> JWT -> redirect
2. **Selezione società** (super_admin): dopo il login, mostra griglia società

```vue
<!-- Login.vue — flussi principali (riassunto) -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { login, getMe, getSocieta, getSocietaById, ... } from '../api/index.js'
import { useStore } from '../store.js'

const username = ref('')
const password = ref('')
const errore = ref('')
const loading = ref(false)
const showSocietaSelection = ref(false)
const societaOptions = ref([])
const societaSelezionata = ref(null)

// Check canonico super_admin
const isSuperAdmin = computed(() =>
  utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin'
)

const router = useRouter()
const { setToken, utenteAttivo, setSocietaAttiva, setListaSocieta } = useStore()

// On mount: se token valido e super_admin, mostra selezione società
onMounted(async () => {
  const token = localStorage.getItem('token')
  if (!token) return
  try {
    const me = await getMe()
    utenteAttivo.value = me.data
    if (me.data.is_super_admin || me.data.ruolo === 'super_admin') {
      const res = await getSocieta()
      societaOptions.value = res.data
      setListaSocieta(res.data)
      showSocietaSelection.value = true
      setSocietaAttiva(null)
    }
  } catch (e) { /* 401 = token scaduto, ignora */ }
})

async function doLogin() {
  loading.value = true
  errore.value = ''
  try {
    const res = await login(username.value, password.value)
    setToken(res.data.access_token)
    const me = await getMe()
    utenteAttivo.value = me.data

    // Super admin -> selezione società
    if (me.data.is_super_admin || me.data.ruolo === 'super_admin') {
      const res = await getSocieta()
      societaOptions.value = res.data
      setListaSocieta(res.data)
      showSocietaSelection.value = true
      return
    }

    // Admin locale -> carica società
    if (me.data.societa_id) {
      const societaRes = await getSocietaById(me.data.societa_id)
      setSocietaAttiva(societaRes.data)
    }

    // Redirect per ruolo
    if (me.data.ruolo === 'segreteria') return router.push('/segreteria')
    if (me.data.ruolo === 'infermeria') return router.push('/infermeria')
    if (me.data.ruolo === 'mister') return router.push('/allenatori')

    router.push('/')
  } catch {
    errore.value = 'Credenziali non valide. Riprova.'
  } finally {
    loading.value = false
  }
}

async function confermaSocieta() {
  const societa = societaOptions.value.find(s => s.id === societaSelezionata.value)
  setSocietaAttiva(societa)
  router.push('/')
}
</script>
```

### 7.5 Viste Frontend

| Vista | File | Rotta | Descrizione |
|-------|------|-------|-------------|
| Login | `Login.vue` | `/login` | Login + selezione società super_admin |
| Home | `Home.vue` | `/` | Dashboard principale |
| Allenatori | `Allenatori.vue` | `/allenatori` | CRUD categorie, accordion parent/child |
| Responsabili | `Responsabili.vue` | `/responsabili` | Hub area responsabili |
| ResponsabiliCategoria | `ResponsabiliCategoria.vue` | `/responsabili/categorie` | Gestione categorie |
| ProgrammazionePartite | `ProgrammazionePartite.vue` | `/responsabili/partite` | Programmazione partite |
| Spogliatoi | `Spogliatoi.vue` | `/responsabili/spogliatoi` | Assegnazione spogliatoi |
| PresenzeAllenatori | `PresenzeAllenatori.vue` | `/responsabili/presenze-allenatori` | Presenze staff |
| Scelta | `Scelta.vue` | `/scelta/:id` | Action picker per categoria |
| Registro | `Registro.vue` | `/registro/:id` | Calendario presenze mensile |
| Convocazioni | `Convocazioni.vue` | `/convocazioni/:id` | Liste convocazioni gare |
| DatiMatricole | `DatiMatricole.vue` | `/dati/:id` | Dati giocatori e matricole |
| ListeTornei | `ListeTornei.vue` | `/liste-tornei/:id` | Liste torneo |
| Allenamenti | `Allenamenti.vue` | `/allenamenti/:id` | Lavagna tattica, catalogo |
| SchedaAllenamento | `SchedaAllenamento.vue` | `/scheda-allenamento/:id` | Dashboard metriche GPS |
| Admin | `Admin.vue` | `/admin` | Gestione utenti (super_admin) |
| Societa | `Societa.vue` | `/admin/societa` | Gestione società |
| Reportistica | `Reportistica.vue` | `/reportistica/:id` | Report e statistiche |
| Segreteria | `Segreteria.vue` | `/segreteria` | Hub segreteria |
| SegreteriaCategoria | `SegreteriaCategoria.vue` | `/segreteria/:id` | Gestione categoria segreteria |
| SchedaGiocatore | `SchedaGiocatore.vue` | `/segreteria/scheda/:id` | Scheda dettaglio giocatore |
| Valutazioni | `Valutazioni.vue` | `/valutazioni/:id` | Valutazioni tecniche |
| Infermeria | `Infermeria.vue` | `/infermeria` | Hub infermeria |
| CertificatoMedico | `CertificatoMedico.vue` | `/infermeria/certificati` | Certificati medici |
| Infortunati | `Infortunati.vue` | `/infermeria/infortunati` | Gestione infortuni |
| Openday | `Openday.vue` | `/segreteria/openday` | Open day iscrizioni |
| PresenzeSegreteria | `PresenzeSegreteria.vue` | `/segreteria/presenze` | Presenze segreteria |
| FormOnlineIscrizione | `FormOnlineIscrizione.vue` | `/form-iscrizione` | Form pubblico iscrizione |

### 7.6 Componenti e Composables

| File | Descrizione |
|------|-------------|
| `TacticalBoard.vue` | Lavagna tattica interattiva (drag & drop, elementi campo) |
| `TacticalBoardSimple.vue` | Versione semplificata della lavagna |
| `useTacticalBoard.js` | Composable con logica lavagna (stato, eventi, salvataggio) |

---

## 8. Sistema di Autenticazione

### 8.1 Flusso JWT

```
CLIENTE                          BACKEND
   │                                │
   │  POST /auth/token              │
   │  (username, password)          │
   │ ──────────────────────────────►│
   │                                │  1. Cerca Utente per username
   │                                │  2. Verifica bcrypt hash
   │                                │  3. Crea JWT (HS256, 60 min)
   │                                │
   │  ← { access_token: "eyJ..." }  │
   │ ◀───────────────────────────── │
   │                                │
   │  GET /auth/me                  │
   │  Authorization: Bearer <token> │
   │ ──────────────────────────────►│
   │                                │  1. Decodifica JWT
   │                                │  2. Carica Utente da DB
   │                                │  3. Restituisce profilo
   │                                │
   │  ← { id, username, ruoli... }  │
   │ ◀───────────────────────────── │
   │                                │
   │  GET /persone/?categoria_id=X  │
   │  Authorization: Bearer <token> │
   │ ──────────────────────────────►│
   │                                │  1. get_current_user(token)
   │                                │  2. Filtra per societa_id
   │                                │  3. Restituisce dati
   │                                │
   │  ← [ persone... ]              │
   │ ◀───────────────────────────── │
```

### 8.2 Implementazione (`backend/app/routers/auth.py`)

```python
# backend/app/routers/auth.py (riassunto commentato)

from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
import os

SECRET_KEY = os.environ.get("SECRET_KEY")        # Chiave JWT
DEFAULT_PASSWORD = os.environ.get("DEFAULT_PASSWORD")  # Password default reset
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60                 # Token scade dopo 60 minuti

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)

def hash_password(password):
    return pwd_context.hash(password)

# Validazione password: min 8 char, maiuscolo, minuscolo, numero, speciale
def validate_password(password: str):
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="La password deve avere almeno 8 caratteri")
    if not re.search(r'[A-Z]', password):
        raise HTTPException(status_code=400, detail="La password deve contenere almeno un carattere maiuscolo")
    if not re.search(r'[a-z]', password):
        raise HTTPException(status_code=400, detail="La password deve contenere almeno un carattere minuscolo")
    if not re.search(r'\d', password):
        raise HTTPException(status_code=400, detail="La password deve contenere almeno un numero")
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        raise HTTPException(status_code=400, detail="La password deve contenere almeno un carattere speciale")

def create_token(data: dict):
    to_encode = data.copy()
    to_encode["exp"] = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# Dependency injection: estrae utente corrente dal JWT
def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="Token non valido")
        user = db.query(Utente).filter(Utente.username == username).first()
        if not user:
            raise HTTPException(status_code=401, detail="Utente non trovato")
        return user
    except JWTError:
        raise HTTPException(status_code=401, detail="Token non valido")

# Dependency: solo admin
def get_admin(current_user: Utente = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Solo admin")
    return current_user

# Dependency: solo super admin
def get_super_admin(current_user: Utente = Depends(get_current_user)):
    if not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Solo super admin")
    return current_user

# Verifica multi-tenant: utente appartiene alla società?
def check_societa(current_user: Utente, societa_id: int):
    if not current_user.is_super_admin and current_user.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su questa società")
    return current_user

# --- ENDPOINT LOGIN (rate-limited: 10/min) ---
@limiter.limit("10/minute")
@router.post("/token")
def login(request: Request, form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(Utente).filter(Utente.username == form.username).first()
    if not user or not verify_password(form.password, user.password_hash):
        # Timing attack mitigation: hash dummy anche se utente non trovato
        if not user:
            verify_password(form.password, "$2b$12$260mdxWoPqJ9blHKaB4fKuiJbLr7WbMYw6K78Q3vGHxRRz8xZzqEi")
        raise HTTPException(status_code=401, detail="Credenziali errate")
    token = create_token({
        "sub": user.username,
        "is_admin": user.is_admin,
        "societa_id": user.societa_id,
        "is_super_admin": user.is_super_admin
    })
    return {"access_token": token, "token_type": "bearer"}

# --- ENDPOINT PROFILO ---
@router.get("/me")
def me(current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    # Restituisce profilo utente con categorie assegnate
    if current_user.is_super_admin:
        categorie_ids = None  # Vede tutto
    elif current_user.is_admin:
        categorie_ids = None  # Vede tutte le categorie della sua società
    else:
        rows = db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == current_user.id).all()
        categorie_ids = [r.categoria_id for r in rows]
    return {
        "id": current_user.id,
        "username": current_user.username,
        "is_admin": current_user.is_admin,
        "is_super_admin": current_user.is_super_admin,
        "societa_id": None if current_user.is_super_admin else current_user.societa_id,
        "categorie_ids": categorie_ids,
        "nome": current_user.nome,
        "cognome": current_user.cognome,
        "ruolo": current_user.ruolo
    }

# --- CRUD UTENTI (solo admin) ---
@router.post("/utenti")
def crea_utente(data: UtenteCreate, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    validate_password(data.password)
    # Solo super_admin può creare super_admin
    is_super = 1 if data.ruolo == 'super_admin' else 0
    if is_super and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato a creare super admin")
    # Admin locale: solo propria società
    if not current_user.is_super_admin and data.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a creare utenti per altre società")
    utente = Utente(
        username=data.username,
        password_hash=hash_password(data.password),
        is_admin=1 if data.ruolo in ('super_admin', 'admin') else 0,
        is_super_admin=is_super,
        societa_id=data.societa_id,
        nome=format_nome(data.nome),
        cognome=format_cognome(data.cognome),
        ruolo=data.ruolo
    )
    db.add(utente)
    db.commit()
    return {"ok": True}

@limiter.limit("5/minute")
@router.put("/utenti/{uid}/reset-password")
def reset_password(request: Request, uid: int, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    # ... controlli autorizzazione
    utente.password_hash = hash_password(DEFAULT_PASSWORD)
    db.commit()
    return {"ok": True, "message": "Password reimpostata"}
```

---

## 9. Crittografia PII

I dati personali sensibili (codice fiscale, tel_papa, tel_mamma) sono crittografati con **AES tramite pgcrypto** di PostgreSQL.

### 9.1 Implementazione (`backend/app/routers/persone.py`)

```python
# backend/app/routers/persone.py (funzioni crittografia)
import os
from sqlalchemy import text

ENCRYPTION_KEY = os.environ.get("ENCRYPTION_KEY")  # Chiave AES (base64)
PGCRYPTO_AVAILABLE = os.environ.get("PGCRYPTO_AVAILABLE", "false").lower() == "true"

def safe_encrypt(db: Session, value: str) -> str:
    """Crittografa un valore con AES/pgcrypto, salvando l'hex nel DB."""
    if not value or not PGCRYPTO_AVAILABLE:
        return value
    try:
        result = db.execute(
            text("SELECT encode(encrypt(CAST(:val AS bytea), :enc_key, 'aes'), 'hex')"),
            {"val": value, "enc_key": ENCRYPTION_KEY}
        ).scalar()
        return result  # Stringa hex crittografata
    except Exception as e:
        db.rollback()
        logger.error(f"Encryption failed: {e}")
        raise

def safe_decrypt(db: Session, value: str) -> str:
    """Decrittografa un valore hex dal DB."""
    if not value or not PGCRYPTO_AVAILABLE:
        return value
    # Validazione: deve essere hex valido di lunghezza sufficiente
    if not isinstance(value, str) or len(value) < 32 or not all(c in '0123456789abcdef' for c in value):
        return value  # Non è crittografato, restituisce come-is
    try:
        db.rollback()
        decrypted = db.execute(
            text("SELECT convert_from(decrypt(decode(:val, 'hex'), :enc_key, 'aes'), 'UTF8')"),
            {"val": value, "enc_key": ENCRYPTION_KEY}
        ).scalar()
        return decrypted if decrypted else value
    except Exception as e:
        db.rollback()
        logger.warning(f"Could not decrypt: {e}")
        return value  # Fallback

def safe_decrypt_with_key(db: Session, value: str, key: str) -> str:
    """Decrittografa con una chiave specifica (per key rotation)."""

def safe_encrypt_with_key(db: Session, value: str, key: str) -> str:
    """Crittografa con una chiave specifica (per key rotation)."""
```

### 9.2 Flusso crittografia

```
Inserimento:
  "RSSMRN80A01F205U" -> safe_encrypt() -> "a3f2b1c4d5e6..." (hex AES) -> salvato in DB

Letture:
  "a3f2b1c4d5e6..." (dal DB) -> safe_decrypt() -> "RSSMRN80A01F205U" -> restituito all'API

Key Rotation:
  1. Decrittografa con vecchia chiave -> valore in chiaro
  2. Ricrittografa con nuova chiave -> nuovo hex
  3. Aggiorna DB con nuovo valore
```

**Campi crittografati**: `codice_fiscale`, `tel_papa`, `tel_mamma` (sia in `persone` che in `openday`).

---

## 10. Rate Limiting

| Endpoint | Limite | Note |
|----------|--------|------|
| `POST /auth/token` | 10/min | Login |
| `PUT /auth/utenti/{id}/reset-password` | 5/min | Reset password |
| `GET /persone/public/{id}` | 5/min | PII pubblico |
| `GET /persone/public/categoria/{id}` | 5/min | PII pubblico |

**Importante**: i limiti sono **per worker**. Con 4 workers in produzione, il limite effettivo è 4x.

---

## 11. Docker e Deployment

### 11.1 Docker Compose Base (`docker-compose.yml`)

```yaml
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      SECRET_KEY: ${SECRET_KEY}
      ENCRYPTION_KEY: ${ENCRYPTION_KEY}
      DEFAULT_PASSWORD: ${DEFAULT_PASSWORD}
      PGCRYPTO_AVAILABLE: "true"
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy

  frontend:
    build:
      context: ./frontend
      args:
        VITE_API_URL: ${VITE_API_URL:-/api}
    restart: unless-stopped
    ports:
      - "0.0.0.0:3000:80"   # ATTENZIONE: mai 127.0.0.1 in prod (502 error)
    depends_on:
      - backend

volumes:
  pgdata:
```

### 11.2 Ambienti

| Ambiente | Server | Deploy | Note |
|----------|--------|--------|------|
| **Locale** | Host | `./start_dev.sh` | PG su :5433, uvicorn :8000, vite :5173 |
| **Dev** | 192.168.178.133 | `./deploy_dev.sh` | tar+ssh sync, no git |
| **Prod** | 192.168.178.132 | `./deploy.sh` | git fetch+reset, 4 workers |

### 11.3 Deploy Produzione (`deploy.sh`)

```bash
#!/bin/bash
# Deploy script - pull latest changes and rebuild on LXC (prod)

set -e
echo "=== Deploying to LXC ==="

# Fetch and reset to ensure we have latest
ssh root@192.168.178.132 "cd /opt/registro_presenze && git fetch origin && git reset --hard origin/master"

# Run database migrations (copy SQL into container, then execute)
ssh root@192.168.178.132 'cd /opt/registro_presenze && docker compose cp migrations/add_stagione_fields.sql db:/tmp/... && docker compose exec -T db sh -c "psql ..."' 2>/dev/null || true

# Stop existing containers
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose -f docker-compose.yml -f docker-compose.prod.yml down"

# Force rebuild without cache
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache"

# Start containers
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d"

sleep 5
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose ps"
echo "=== Deploy complete! ==="
```

### 11.4 Deploy Dev (`deploy_dev.sh`)

```bash
#!/bin/bash
# Deploy script - tar+ssh sync + rebuild on Dev LXC (192.168.178.133)

set -e
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_dev}"
SSH="ssh -i $SSH_KEY"
REMOTE="root@192.168.178.133"
REMOTE_PATH="/opt/registro_presenze"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Sync files via tar pipe over SSH (esclude .git, node_modules, dist, __pycache__, .env)
tar -cz \
  --exclude='node_modules' \
  --exclude='dist' \
  --exclude='__pycache__' \
  --exclude='.env' \
  --exclude='uploads' \
  --exclude='.git' \
  --exclude='*.pyc' \
  -C "$PROJECT_ROOT" . | $SSH $REMOTE "tar -xzf - -C $REMOTE_PATH"

# Migrations, stop, rebuild, start
$SSH $REMOTE "cd $REMOTE_PATH && docker compose -f docker-compose.yml -f docker-compose.dev.yml down"
$SSH $REMOTE "cd $REMOTE_PATH && docker compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache"
$SSH $REMOTE "cd $REMOTE_PATH && docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d"
```

---

## 12. Sicurezza

### 12.1 Pre-commit Hook (`scripts/git-hooks/pre-commit`)

```bash
#!/bin/sh
# Blocca i commit che contengono:
#   - file di ambiente (*.env*) con credenziali (escluso .env.example)
#   - stringhe di credenziali reali (letto da scripts/git-hooks/secrets.lst)

set -e
RED='\033[0;31m'
NC='\033[0m'
echo_red() { printf "${RED}%s${NC}\n" "$1"; }
FAIL=0

# 1) Blocca file di ambiente con credenziali (tranne il placeholder)
ENV_STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E '/?\.env.*$' | grep -v '\.env\.example$' || true)
if [ -n "$ENV_STAGED" ]; then
  echo_red "Bloccato: file di ambiente con credenziali in staging:"
  printf '%s\n' "$ENV_STAGED" | sed 's/^/    /'
  FAIL=1
fi

# 2) Blocca stringhe di segreti lette dalla lista (filesystem, non nel repo)
REPO_ROOT="$(git rev-parse --show-toplevel)"
SECRETS_FILE="$REPO_ROOT/scripts/git-hooks/secrets.lst"
if [ -f "$SECRETS_FILE" ] && [ -s "$SECRETS_FILE" ]; then
  while IFS= read -r sec; do
    [ -z "$sec" ] && continue
    case "$sec" in \#*) continue ;; esac
    HIT=$(git diff --cached --diff-filter=ACM --name-only -z | xargs -0 -r grep -lFI -- "$sec" 2>/dev/null || true)
    if [ -n "$HIT" ]; then
      echo_red "Bloccato: trovata credenziale reale nei file in staging:"
      printf '%s\n' "$HIT" | sed 's/^/    /'
      FAIL=1
      break
    fi
  done < "$SECRETS_FILE"
fi

if [ "$FAIL" = "1" ]; then
  echo_red "Commit annullato per motivi di sicurezza."
  exit 1
fi
exit 0
```

**Installazione**: `./scripts/install-hooks.sh` (crea symlink in `.git/hooks/pre-commit`).

### 12.2 Misure di Sicurezza

| Misure | Implementazione |
|--------|----------------|
| **HTTPS HSTS** | Header `Strict-Transport-Security` su tutte le risposte |
| **CSP** | `default-src 'self'; frame-ancestors 'none'` |
| **XSS Protection** | Header `X-XSS-Protection`, `X-Content-Type-Options` |
| **Clickjacking** | `X-Frame-Options: DENY` |
| **CORS** | Solo domini autorizzati |
| **Rate Limiting** | slowapi, per-worker, IP-based |
| **Password Policy** | Min 8 char, maiuscolo, minuscolo, numero, speciale |
| **bcrypt** | Hash password con salt, timing attack safe |
| **JWT 60min** | Token scade dopo 60 minuti |
| **PII Encryption** | pgcrypto AES per CF, tel_papa, tel_mamma |
| **Pre-commit hook** | Blocca .env e segreti nei commit |
| **Timing attack mitigation** | Hash dummy su login fallito |
| **Server fingerprint** | Header `Server` rimosso |
| **Permissions Policy** | Camera, microphone, geolocation disabilitati |

---

## 13. Script di Automazione

### 13.1 `start_dev.sh` — Avvio locale

```bash
#!/bin/bash
set -e
echo "=== Avvio Ambiente Dev ==="

# Carica variabili d'ambiente
set -a && source /home/andrea/registro_presenze/.env && set +a

# 1. Avvia PostgreSQL se non è già in esecuzione
if ! pg_isready -h /tmp/pgsocket -p 5433 > /dev/null 2>&1; then
  mkdir -p /tmp/pgsocket /tmp/pgdata
  [ ! -d "/tmp/pgdata/base" ] && initdb -D /tmp/pgdata
  pg_ctl -D /tmp/pgdata -o "-p 5433 -k /tmp/pgsocket" -l /tmp/pg.log start
  sleep 2
fi

# 2. Verifica/crea utente e database
psql -h /tmp/pgsocket -p 5433 -d postgres -c "CREATE DATABASE registro OWNER registro_user;" 2>/dev/null || true

# Carica dati da production solo se il DB è vuoto (prima esecuzione)
ROWS=$(psql -h /tmp/pgsocket -p 5433 -d registro -t -c "SELECT COUNT(*) FROM persone" 2>/dev/null || echo "0")
if [ "$ROWS" = "0" ] || [ -z "$ROWS" ]; then
  ssh root@192.168.178.132 "docker exec registro_presenze-db-1 pg_dump -U registro_user -d registro --no-owner --no-acl" | psql -h /tmp/pgsocket -p 5433 -d registro
fi

# 3. Avvia backend in tmux
tmux kill-session -t registro_backend 2>/dev/null || true
tmux new-session -d -s registro_backend \
  'export DATABASE_URL="postgresql://registro_user:...@/registro?host=/tmp/pgsocket&port=5433" && cd backend && python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000'

# 4. Avvia frontend in tmux
tmux kill-session -t registro_frontend 2>/dev/null || true
tmux new-session -d -s registro_frontend \
  'cd frontend && npm run dev'

echo "=== Dev avviato! ==="
echo "Frontend: http://localhost:5173"
echo "Backend:  http://localhost:8000"
echo "Sessioni tmux: registro_backend, registro_frontend"
```

### 13.2 `release.sh` — Crea release

```bash
#!/bin/bash
# Usage: ./release.sh [major|minor] [messaggio]
# Esempio: ./release.sh minor "Aggiunta funzione X" -> v1.1.0

set -e
RELEASE_TYPE=$1
MESSAGE=${2:-"Nuova release"}
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/v//')
NEW_VERSION=$(calculate_version "$RELEASE_TYPE" "$CURRENT_VERSION")

# Crea cartella release, copia file sorgente
mkdir -p releases/v$NEW_VERSION
cp -r backend/app releases/v$NEW_VERSION/backend/
cp -r frontend/src releases/v$NEW_VERSION/frontend/
cp docker-compose.yml releases/v$NEW_VERSION/

# Aggiorna CHANGELOG
echo "## [$NEW_VERSION] - $(date +%Y-%m-%d)" >> CHANGELOG.md
echo "- $MESSAGE" >> CHANGELOG.md

# Commit e tag
git add -f releases/v$NEW_VERSION CHANGELOG.md
git commit -m "Release v$NEW_VERSION - $MESSAGE"
git tag -a v$NEW_VERSION -m "v$NEW_VERSION - $MESSAGE"
git push origin master && git push origin v$NEW_VERSION
```

### 13.3 `install-hooks.sh` — Installa git hook

```bash
#!/bin/sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.git/hooks"
ln -sf ../../scripts/git-hooks/pre-commit "$ROOT/.git/hooks/pre-commit"

HOOK_LIST="$ROOT/scripts/git-hooks/secrets.lst"
if [ ! -f "$HOOK_LIST" ]; then
  cat > "$HOOK_LIST" <<'EOF'
# Segreti da bloccare nei commit (ogni riga = una stringa, letterale).
# NB: questo file NON va committato (è in .gitignore).
EOF
  chmod 600 "$HOOK_LIST"
fi
echo "Hook pre-commit installato in $ROOT/.git/hooks/pre-commit"
```

---

## 14. Ruoli e Permessi

| Ruolo | Descrizione | Permessi |
|-------|-------------|----------|
| **super_admin** | Amministratore globale | Tutte le società, CRUD utenti, CRUD società |
| **admin** | Amministratore locale | Tutta la propria società, CRUD utenti propria società |
| **mister** | Allenatore | Categorie assegnate, allenamenti, convocazioni, presenze |
| **dirigente** | Dirigente sportivo | Lettura categorie assegnate, programmazione partite |
| **segreteria** | Segreteria | Anagrafica giocatori, pagamenti, certificati, open day |
| **infermeria** | Staff medico | Infortuni, certificati medici |

### Check canonico super_admin

```javascript
// Frontend
const isSuperAdmin = utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin'
```

```python
# Backend
def check_societa(current_user: Utente, societa_id: int):
    if not current_user.is_super_admin and current_user.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    return current_user
```

---

## 15. Variabili d'Ambiente (`.env`)

```bash
# Database
DB_USER=registro_user
DB_PASSWORD=<password_database>
DB_NAME=registro

# Chiavi di sicurezza
SECRET_KEY=<chiave_segreta_generata>        # JWT signing key
ENCRYPTION_KEY=<chiave_crittografia_base64> # AES encryption key
DEFAULT_PASSWORD=<password_default>         # Password per reset utente

# URL API
VITE_API_URL=<url_api_relative_o_assoluto>  # Prod: https://thof.crickethouse.mywire.org/api
                                              # Dev: /api

# Altre configurazioni
PGCRYPTO_AVAILABLE=true                     # Abilita crittografia pgcrypto
```

**File `.env`**: mai committare. Usare `.env.example` come template.

---

## 16. Note Operative

### Frontend
- **Service Worker**: disabilitato. Al primo avvio, tutti i SW vecchi vengono disinstallati.
- **Cache aggressiva**: in produzione, gli utenti potrebbero dover fare hard refresh (Ctrl+Shift+R).
- **Route ordering**: `/segreteria/scheda/:id` DEVE essere prima di `/segreteria/:id` in `main.js`.
- **Route ordering**: `/infermeria/infortunati` routea a `Infortunati.vue` (non `Infermeria.vue`).

### Backend
- **Dipendenze pinnote**: `slowapi==0.1.9`, `passlib[bcrypt]==1.7.4` + `bcrypt==4.0.1` (compatibilità nota).
- **Migrations**: NO Alembic. Tutte in `main.py:run_migrations()`, eseguite all'avvio.
- **Portieri cross-category**: `is_portieri=1` legge presenze across tutte le categorie.

### Produzione
- **Nginx esterno** su host proxy ai container.
- **Frontend port**: `0.0.0.0:3000:80` — MAI `127.0.0.1:3000:80` (502 error).
- **Backend port**: `0.0.0.0:8000:8000` — deve essere `0.0.0.0`.
- **4 workers** uvicorn in produzione.
- **Cambiamenti frontend** richiedono rebuild completo (`docker compose build --no-cache`).

### Git & GitHub
- **Autenticazione**: HTTPS + token in `~/.git-credentials` (chmod 600, `credential.helper store`).
- **SSH verso GitHub**: bloccato dalla rete, usare HTTPS+token.
- **Remote**: `origin` e `github` puntano a `github.com/andmor8277/registro-attivit-.git`.
- **Pre-commit hook**: attivo su prod. Non installato su dev (deploy via tar, no git).
