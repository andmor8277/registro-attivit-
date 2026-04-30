from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from slowapi.errors import RateLimitExceeded
from fastapi.responses import JSONResponse
import os
from .rate_limit import limiter
from .database import Base, engine
from .routers import persone, registro, codici, categorie, convocazioni, allenatori, societa, allenamenti
from .routers.gruppi import router as gruppi_router
from .routers.auth import router as auth_router, get_current_user
from sqlalchemy import text

app = FastAPI(title="Registro Presenze API")
app.state.limiter = limiter
app.add_middleware(limiter._middleware_class, limiter)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_exceeded_handler(request, exc):
    return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded"})

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
                result = conn.execute(text(
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
        finally:
            conn.close()

Base.metadata.create_all(bind=engine)
run_migrations()

app.include_router(auth_router)
app.include_router(societa.router)
app.include_router(persone.router)
app.include_router(registro.router, dependencies=[Depends(get_current_user)])
app.include_router(codici.router, dependencies=[Depends(get_current_user)])
app.include_router(categorie.router, dependencies=[Depends(get_current_user)])
app.include_router(convocazioni.router, dependencies=[Depends(get_current_user)])
app.include_router(allenatori.router, dependencies=[Depends(get_current_user)])
app.include_router(allenamenti.router, dependencies=[Depends(get_current_user)])
app.include_router(gruppi_router, dependencies=[Depends(get_current_user)])

@app.get("/")
def root():
    return {"status": "ok"}
