from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
import os
from .rate_limit import limiter
from .database import Base, engine
from .routers import persone, registro, codici, categorie, convocazioni, allenatori, societa, allenamenti, partite, weekend, spogliatoi, campi, presenze_allenatori, valutazioni, infortuni, openday, planning_eventi
from .routers.gruppi import router as gruppi_router
from .routers.auth import router as auth_router, get_current_user
from sqlalchemy import text

app = FastAPI(title="Registro Presenze API")
app.state.limiter = limiter
app.add_middleware(SlowAPIMiddleware)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_exceeded_handler(request, exc):
    return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded"})

@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none'"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if "Server" in response.headers:
        del response.headers["Server"]
    return response

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://thof.crickethouse.mywire.org", "http://localhost:5173", "http://localhost:3000"],
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["Content-Disposition"]
)



UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

ALLOWED_TABLES = frozenset({'utenti', 'categorie', 'persone', 'registro', 'convocazioni'})

def run_migrations():
    with engine.connect() as conn:
        try:
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
                        print(f"Migration: Added societa_id to {table}")
                except Exception:
                    pass

            try:
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'utenti' AND column_name = 'is_super_admin'"
                ))
                if result.fetchone() is None:
                    conn.execute(text(
                        "ALTER TABLE utenti ADD COLUMN is_super_admin INTEGER DEFAULT 0"
                    ))
                    conn.commit()
                    print("Migration: Added is_super_admin to utenti")
            except Exception:
                pass

            try:
                result = conn.execute(text(
                    "SELECT id FROM utenti WHERE username = :un LIMIT 1"
                ), {"un": "admin"})
                admin_user = result.fetchone()
                if admin_user:
                    conn.execute(text(
                        "UPDATE utenti SET is_super_admin = 1, is_admin = 1 "
                        "WHERE username = :un"
                    ), {"un": "admin"})
                    conn.commit()
                    print("Migration: Set admin user as super_admin")
            except Exception:
                pass

            try:
                conn.execute(text(
                    "UPDATE utenti SET is_super_admin = 0 "
                    "WHERE username != :un AND is_super_admin IS NULL"
                ), {"un": "admin"})
                conn.commit()
            except Exception:
                pass

            try:
                result = conn.execute(text("SELECT COUNT(*) FROM societa"))
                count = result.fetchone()
                if count and count[0] == 0:
                    conn.execute(text("""
                        INSERT INTO societa (nome, nome_breve, colore_primario, colore_secondario)
                        VALUES ('RedTigers 1957', 'RedTigers', '#dc2626', '#1f2937')
                    """))
                    conn.commit()
                    print("Migration: Created default society")
            except Exception:
                pass

            try:
                conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'catalogo_esercizi' AND column_name = 'spazio'"
                ))
                if result.fetchone() is None:
                    conn.execute(text(
                        "ALTER TABLE catalogo_esercizi ADD COLUMN spazio VARCHAR(50)"
                    ))
                    conn.execute(text(
                        "ALTER TABLE catalogo_esercizi ADD COLUMN tempo VARCHAR(50)"
                    ))
                    conn.commit()
                    print("Migration: Added spazio and tempo columns to catalogo_esercizi")
            except Exception as e:
                print(f"Migration warning (non-critical): {e}")
                conn.rollback()

            # visibilita and societa_id on catalogo_esercizi
            try:
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'catalogo_esercizi' AND column_name = 'visibilita'"
                ))
                if result.fetchone() is None:
                    conn.execute(text(
                        "ALTER TABLE catalogo_esercizi ADD COLUMN visibilita VARCHAR(20) NOT NULL DEFAULT 'pubblico'"
                    ))
                    conn.commit()
                    print("Migration: Added visibilita to catalogo_esercizi")
            except Exception as e:
                print(f"Migration warning (visibilita): {e}")
                conn.rollback()

            try:
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'catalogo_esercizi' AND column_name = 'societa_id'"
                ))
                if result.fetchone() is None:
                    conn.execute(text(
                        "ALTER TABLE catalogo_esercizi ADD COLUMN societa_id INTEGER REFERENCES societa(id)"
                    ))
                    conn.commit()
                    print("Migration: Added societa_id to catalogo_esercizi")
            except Exception as e:
                print(f"Migration warning (catalogo societa_id): {e}")
                conn.rollback()

            try:
                result = conn.execute(text(
                    "SELECT table_name FROM information_schema.tables WHERE table_name = :tn"
                ), {"tn": "partite"})
                if result.fetchone() is None:
                    conn.execute(text("""
                        CREATE TABLE partite (
                            id SERIAL PRIMARY KEY,
                            categoria_id INTEGER NOT NULL REFERENCES categorie(id),
                            data_partite DATE NOT NULL,
                             ora TIME,
                             ora_presentazione TIME,
                             avversario VARCHAR(100),
                            campo VARCHAR(100),
                            indirizzo VARCHAR(200),
                            casa_fuori VARCHAR(10),
                            mister_id INTEGER,
                            risultato VARCHAR(20),
                            goal_punti INTEGER DEFAULT 0,
                            goal_contro INTEGER DEFAULT 0,
                            note TEXT,
                            societa_id INTEGER REFERENCES societa(id)
                        )
                    """))
                    conn.commit()
                    print("Migration: Created partite table")
            except Exception as e:
                print(f"Migration warning (partite table): {e}")
                conn.rollback()

            for col_name, col_type in [('indirizzo', 'VARCHAR(200)'), ('casa_fuori', 'VARCHAR(10)'), ('mister_id', 'INTEGER'), ('ora_presentazione', 'TIME')]:
                try:
                    result = conn.execute(text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name = 'partite' AND column_name = :cn"
                    ), {"cn": col_name})
                    if result.fetchone() is None:
                        conn.execute(text(
                            f"ALTER TABLE partite ADD COLUMN {col_name} {col_type}"
                        ))
                        conn.commit()
                        print(f"Migration: Added {col_name} to partite")
                except Exception:
                    pass

            # Weekend table
            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS weekend (
                        id SERIAL PRIMARY KEY,
                        nome VARCHAR(100) NOT NULL,
                        data_inizio DATE NOT NULL,
                        data_fine DATE NOT NULL,
                        societa_id INTEGER REFERENCES societa(id)
                    )
                """))
                conn.commit()
                print("Migration: Created weekend table")
            except Exception as e:
                print(f"Migration warning (weekend table): {e}")
                conn.rollback()

            # weekend_id on partite
            try:
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'partite' AND column_name = 'weekend_id'"
                ))
                if result.fetchone() is None:
                    conn.execute(text(
                        "ALTER TABLE partite ADD COLUMN weekend_id INTEGER"
                    ))
                    conn.commit()
                    print("Migration: Added weekend_id to partite")
            except Exception:
                pass

            # Spogliatoi table
            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS spogliatoi (
                        id SERIAL PRIMARY KEY,
                        etichetta VARCHAR(100) NOT NULL,
                        ordine INTEGER DEFAULT 0,
                        societa_id INTEGER REFERENCES societa(id)
                    )
                """))
                conn.commit()
                print("Migration: Created spogliatoi table")
            except Exception as e:
                print(f"Migration warning (spogliatoi table): {e}")
                conn.rollback()

            # Spogliatoi assegnazioni table
            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS spogliatoi_assegnazioni (
                        id SERIAL PRIMARY KEY,
                        spogliatoio_id INTEGER REFERENCES spogliatoi(id),
                        categoria_id INTEGER REFERENCES categorie(id),
                        nome_squadra_esterna VARCHAR(100),
                        tipo VARCHAR(20) DEFAULT 'casa',
                        data_inizio DATE,
                        weekend_id INTEGER,
                        societa_id INTEGER REFERENCES societa(id)
                    )
                """))
                conn.commit()
                print("Migration: Created spogliatoi_assegnazioni table")
            except Exception as e:
                print(f"Migration warning (spogliatoi_assegnazioni table): {e}")
                conn.rollback()

            # Add ora_allenamento column to categorie table
            try:
                conn.execute(text("ALTER TABLE categorie ADD COLUMN ora_allenamento VARCHAR(10)"))
                conn.commit()
                print("Migration: Added ora_allenamento column to categorie table")
            except Exception as e:
                print(f"Migration warning (ora_allenamento column): {e}")
                conn.rollback()

            # Add data column to spogliatoi_assegnazioni table (per-day assignments)
            try:
                conn.execute(text("ALTER TABLE spogliatoi_assegnazioni ADD COLUMN data DATE"))
                conn.commit()
                print("Migration: Added data column to spogliatoi_assegnazioni table")
            except Exception as e:
                print(f"Migration warning (assegnazioni data column): {e}")
                conn.rollback()

            # Campi da gioco table
            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS campi_da_gioco (
                        id SERIAL PRIMARY KEY,
                        etichetta VARCHAR(100) NOT NULL,
                        ordine INTEGER DEFAULT 0,
                        societa_id INTEGER REFERENCES societa(id)
                    )
                """))
                conn.commit()
                print("Migration: Created campi_da_gioco table")
            except Exception as e:
                print(f"Migration warning (campi_da_gioco table): {e}")
                conn.rollback()

            try:
                conn.execute(text("ALTER TABLE campi_da_gioco ADD COLUMN tipo_campo VARCHAR(5) DEFAULT '11'"))
                conn.commit()
                print("Migration: Added tipo_campo to campi_da_gioco")
            except Exception as e:
                print(f"Migration warning (campi_da_gioco tipo_campo): {e}")
                conn.rollback()

            # Campi assegnazioni table
            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS campi_assegnazioni (
                        id SERIAL PRIMARY KEY,
                        campo_id INTEGER REFERENCES campi_da_gioco(id),
                        categoria_id INTEGER REFERENCES categorie(id),
                        nome_squadra_esterna VARCHAR(100),
                        tipo VARCHAR(20) DEFAULT 'casa',
                        data_inizio DATE,
                        data DATE,
                        weekend_id INTEGER,
                        societa_id INTEGER REFERENCES societa(id)
                    )
                """))
                conn.commit()
                print("Migration: Created campi_assegnazioni table")
            except Exception as e:
                print(f"Migration warning (campi_assegnazioni table): {e}")
                conn.rollback()

            try:
                conn.execute(text("ALTER TABLE campi_assegnazioni ADD COLUMN metacampo VARCHAR(2)"))
                conn.commit()
                print("Migration: Added metacampo to campi_assegnazioni")
            except Exception as e:
                print(f"Migration warning (campi_assegnazioni metacampo): {e}")
                conn.rollback()

            # is_default column for default week template
            try:
                conn.execute(text("ALTER TABLE spogliatoi_assegnazioni ADD COLUMN is_default BOOLEAN DEFAULT FALSE"))
                conn.commit()
                print("Migration: Added is_default to spogliatoi_assegnazioni")
            except Exception as e:
                print(f"Migration warning (spogliatoi_assegnazioni is_default): {e}")
                conn.rollback()

            try:
                conn.execute(text("ALTER TABLE campi_assegnazioni ADD COLUMN is_default BOOLEAN DEFAULT FALSE"))
                conn.commit()
                print("Migration: Added is_default to campi_assegnazioni")
            except Exception as e:
                print(f"Migration warning (campi_assegnazioni is_default): {e}")
                conn.rollback()

            # Presenze allenatori table
            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS presenze_allenatori (
                        id SERIAL PRIMARY KEY,
                        utente_id INTEGER REFERENCES utenti(id),
                        data DATE NOT NULL,
                        codice VARCHAR(5) REFERENCES codici.codice,
                        societa_id INTEGER REFERENCES societa(id)
                    )
                """))
                conn.commit()
                print("Migration: Created presenze_allenatori table (utente_id)")
            except Exception as e:
                print(f"Migration warning (presenze_allenatori table): {e}")
                conn.rollback()

            # Rename allenatore_id -> utente_id if needed
            try:
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'presenze_allenatori' AND column_name = 'allenatore_id'"
                ))
                if result.fetchone():
                    conn.execute(text("ALTER TABLE presenze_allenatori RENAME COLUMN allenatore_id TO utente_id"))
                    conn.commit()
                    print("Migration: Renamed allenatore_id -> utente_id in presenze_allenatori")
            except Exception:
                pass

            # Add societa_id to gruppi and populate from categorie
            try:
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'gruppi' AND column_name = 'societa_id'"
                ))
                if result.fetchone() is None:
                    conn.execute(text(
                        "ALTER TABLE gruppi ADD COLUMN societa_id INTEGER REFERENCES societa(id)"
                    ))
                    conn.commit()
                    print("Migration: Added societa_id to gruppi")
            except Exception:
                pass

            try:
                conn.execute(text("""
                    UPDATE gruppi g SET societa_id = c.societa_id
                    FROM categorie c
                    WHERE g.categoria_id = c.id AND g.societa_id IS NULL
                """))
                conn.commit()
                print("Migration: Populated gruppi.societa_id from categorie")
            except Exception:
                pass

            # Assign gruppo "Pigna" to categoria "Test2013"
            try:
                conn.execute(text("""
                    UPDATE gruppi SET categoria_id = (SELECT id FROM categorie WHERE nome = :cn LIMIT 1)
                    WHERE nome = :gn AND categoria_id IS NULL
                """), {"cn": "TEST2", "gn": "Pigna"})
                conn.commit()
                print("Migration: Assigned gruppo Pigna to categoria Test2013")
            except Exception:
                pass

            # Remove unique constraint on gruppi.nome (needed for multiple "Portieri" groups)
            try:
                conn.execute(text("ALTER TABLE gruppi DROP CONSTRAINT IF EXISTS gruppi_nome_key"))
                conn.commit()
                print("Migration: Dropped gruppi.nome unique constraint")
            except Exception as e:
                print(f"Migration warning (drop gruppi_nome_key): {e}")

            # Create "Portieri" group for every active category that doesn't have one
            try:
                cats = conn.execute(text("""
                    SELECT c.id, c.societa_id FROM categorie c
                    WHERE c.is_portieri = 0 AND c.is_archiviata = 0
                    AND NOT EXISTS (
                        SELECT 1 FROM gruppi g
                        WHERE g.categoria_id = c.id AND LOWER(g.nome) = 'portieri'
                    )
                """)).fetchall()
                created = 0
                for cat in cats:
                    try:
                        conn.execute(text("""
                            INSERT INTO gruppi (nome, categoria_id, societa_id)
                            VALUES ('Portieri', :cid, :sid)
                        """), {"cid": cat.id, "sid": cat.societa_id})
                        created += 1
                    except Exception:
                        pass
                conn.commit()
                print(f"Migration: Created Portieri groups for {created} categories")
            except Exception as e:
                print(f"Migration error (Portieri groups): {e}")

            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS valutazioni (
                        id SERIAL PRIMARY KEY,
                        persona_id INTEGER REFERENCES persone(id),
                        categoria_id INTEGER REFERENCES categorie(id),
                        tecnica INTEGER,
                        velocita INTEGER,
                        resistenza INTEGER,
                        attitudine INTEGER,
                        posizione INTEGER,
                        gioco_di_testa INTEGER,
                        tiro INTEGER,
                        passaggio INTEGER,
                        dribbling INTEGER,
                        disciplina INTEGER,
                        note TEXT
                    )
                """))
                conn.commit()
                print("Migration: Created valutazioni table")
            except Exception as e:
                print(f"Migration warning (valutazioni table): {e}")
                conn.rollback()

            # Infortuni table
            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS infortuni (
                        id SERIAL PRIMARY KEY,
                        persona_id INTEGER NOT NULL REFERENCES persone(id),
                        categoria_id INTEGER REFERENCES categorie(id),
                        societa_id INTEGER NOT NULL REFERENCES societa(id),
                        data_inizio DATE NOT NULL,
                        giorni_assenza INTEGER NOT NULL DEFAULT 0,
                        data_fine DATE,
                        tipo_infortunio VARCHAR(100),
                        note TEXT,
                        creato_il TIMESTAMP
                    )
                """))
                conn.commit()
                print("Migration: Created infortuni table")
            except Exception as e:
                print(f"Migration warning (infortuni table): {e}")
                conn.rollback()

            try:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS openday (
                        id SERIAL PRIMARY KEY,
                        societa_id INTEGER REFERENCES societa(id),
                        nome VARCHAR(100) NOT NULL,
                        cognome VARCHAR(100) NOT NULL,
                        data_nascita DATE NOT NULL,
                        iscritto BOOLEAN DEFAULT FALSE,
                        persona_id INTEGER REFERENCES persone(id),
                        creato_il TIMESTAMP
                    )
                """))
                conn.commit()
                print("Migration: Created openday table")
            except Exception as e:
                print(f"Migration warning (openday table): {e}")
                conn.rollback()

            try:
                conn.execute(text("ALTER TABLE openday ADD COLUMN date_prova JSONB DEFAULT '[]'"))
                conn.execute(text("ALTER TABLE openday ADD COLUMN nulla_osta BOOLEAN DEFAULT FALSE"))
                conn.execute(text("ALTER TABLE openday ADD COLUMN certificato_medico BOOLEAN DEFAULT FALSE"))
                conn.execute(text("ALTER TABLE openday ADD COLUMN scadenza_certificato DATE"))
                conn.execute(text("ALTER TABLE openday ADD COLUMN tel_papa VARCHAR(20)"))
                conn.execute(text("ALTER TABLE openday ADD COLUMN tel_mamma VARCHAR(20)"))
                conn.execute(text("ALTER TABLE openday ADD COLUMN email_papa VARCHAR(100)"))
                conn.execute(text("ALTER TABLE openday ADD COLUMN email_mamma VARCHAR(100)"))
                conn.commit()
                print("Migration: Added new columns to openday table")
            except Exception as e:
                print(f"Migration warning (openday new columns): {e}")
                conn.rollback()

            try:
                result = conn.execute(text(
                    "SELECT table_name FROM information_schema.tables WHERE table_name = 'planning_eventi'"
                ))
                if result.fetchone() is None:
                    conn.execute(text("""
                        CREATE TABLE planning_eventi (
                            id SERIAL PRIMARY KEY,
                            categoria_id INTEGER REFERENCES categorie(id) NOT NULL,
                            societa_id INTEGER REFERENCES societa(id) NOT NULL,
                            data DATE NOT NULL,
                            tipo VARCHAR(20) NOT NULL,
                            titolo VARCHAR(200),
                            note TEXT,
                            creato_il TIMESTAMP
                        )
                    """))
                    conn.commit()
                    print("Migration: Created planning_eventi table")
            except Exception as e:
                print(f"Migration warning (planning_eventi): {e}")
                conn.rollback()

            # parent_id on categorie for category hierarchy
            try:
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'categorie' AND column_name = 'parent_id'"
                ))
                if result.fetchone() is None:
                    conn.execute(text(
                        "ALTER TABLE categorie ADD COLUMN parent_id INTEGER REFERENCES categorie(id)"
                    ))
                    conn.commit()
                    print("Migration: Added parent_id to categorie")
            except Exception as e:
                print(f"Migration warning (categorie parent_id): {e}")
                conn.rollback()

            # Create Agonistica and Scuola Calcio parent categories and Under categories
            try:
                result = conn.execute(text(
                    "SELECT id FROM categorie WHERE nome = :n AND parent_id IS NULL"
                ), {"n": "Agonistica"})
                if result.fetchone() is None:
                    # Get societa_id from existing categories
                    societa_result = conn.execute(text(
                        "SELECT DISTINCT societa_id FROM categorie LIMIT 1"
                    ))
                    societa_id = societa_result.fetchone()[0] if societa_result.fetchone() else 1

                    # Create Agonistica parent
                    conn.execute(text("""
                        INSERT INTO categorie (societa_id, nome, parent_id, is_portieri, is_archiviata)
                        VALUES (:sid, 'Agonistica', NULL, 0, 0)
                    """), {"sid": societa_id})

                    # Create Scuola Calcio parent
                    conn.execute(text("""
                        INSERT INTO categorie (societa_id, nome, parent_id, is_portieri, is_archiviata)
                        VALUES (:sid, 'Scuola Calcio', NULL, 0, 0)
                    """), {"sid": societa_id})
                    conn.commit()

                    # Get the parent IDs
                    ag_result = conn.execute(text(
                        "SELECT id FROM categorie WHERE nome = 'Agonistica' AND parent_id IS NULL"
                    ))
                    agonistica_id = ag_result.fetchone()[0]

                    sc_result = conn.execute(text(
                        "SELECT id FROM categorie WHERE nome = 'Scuola Calcio' AND parent_id IS NULL"
                    ))
                    scuola_id = sc_result.fetchone()[0]

                    # Create Under categories under Agonistica
                    under_cats = [
                        ('Under 14', 2012, '1,3,5', '16:00'),
                        ('Under 15', 2011, '1,3,5', '16:30'),
                        ('Under 16', 2010, '1,3,5', '17:00'),
                        ('Under 17', 2009, '1,3,5', '17:30'),
                        ('Under 18', 2008, '1,3,5', '18:00'),
                        ('Under 19', 2007, '1,3,5', '18:30'),
                    ]
                    for nome, anno, giorni, ora in under_cats:
                        conn.execute(text("""
                            INSERT INTO categorie (societa_id, nome, anno, giorni, ora_allenamento, parent_id, is_portieri, is_archiviata, stagione)
                            VALUES (:sid, :nome, :anno, :giorni, :ora, :pid, 0, 0, 2025)
                        """), {"sid": societa_id, "nome": nome, "anno": anno, "giorni": giorni, "ora": ora, "pid": agonistica_id})
                    conn.commit()

                    # Set existing non-portieri categories under Scuola Calcio
                    conn.execute(text("""
                        UPDATE categorie SET parent_id = :pid
                        WHERE parent_id IS NULL AND is_portieri = 0 AND nome NOT IN ('Agonistica', 'Scuola Calcio')
                    """), {"pid": scuola_id})
                    conn.commit()

                    # Delete TEST categories and their test players
                    conn.execute(text("""
                        DELETE FROM persone WHERE categoria_id IN (
                            SELECT id FROM categorie WHERE nome LIKE 'TEST%'
                        )
                    """))
                    conn.execute(text("""
                        DELETE FROM categorie WHERE nome LIKE 'TEST%'
                    """))
                    conn.commit()

                    print("Migration: Created Agonistica, Scuola Calcio, Under categories, and cleaned TEST")
            except Exception as e:
                print(f"Migration warning (category hierarchy): {e}")
                conn.rollback()

        finally:
            conn.close()

Base.metadata.create_all(bind=engine)
run_migrations()

app.include_router(auth_router)
app.include_router(societa.router, dependencies=[Depends(get_current_user)])
app.include_router(persone.router)
app.include_router(registro.router, dependencies=[Depends(get_current_user)])
app.include_router(codici.router, dependencies=[Depends(get_current_user)])
app.include_router(categorie.router, dependencies=[Depends(get_current_user)])
app.include_router(convocazioni.router, dependencies=[Depends(get_current_user)])
app.include_router(allenatori.router, dependencies=[Depends(get_current_user)])
app.include_router(allenamenti.router, dependencies=[Depends(get_current_user)])
app.include_router(gruppi_router, dependencies=[Depends(get_current_user)])
app.include_router(partite.router, dependencies=[Depends(get_current_user)])
app.include_router(weekend.router, dependencies=[Depends(get_current_user)])
app.include_router(spogliatoi.router, dependencies=[Depends(get_current_user)])
app.include_router(campi.router, dependencies=[Depends(get_current_user)])
app.include_router(presenze_allenatori.router, dependencies=[Depends(get_current_user)])
app.include_router(valutazioni.router, dependencies=[Depends(get_current_user)])
app.include_router(infortuni.router, dependencies=[Depends(get_current_user)])
app.include_router(openday.router, prefix="/openday", dependencies=[Depends(get_current_user)])
app.include_router(planning_eventi.router, dependencies=[Depends(get_current_user)])

@app.get("/")
def root():
    return {"status": "ok"}
