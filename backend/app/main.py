from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os
from .database import Base, engine
from .routers import persone, registro, codici, categorie, convocazioni, allenatori, societa, allenamenti
from .routers.gruppi import router as gruppi_router
from .routers.auth import router as auth_router, get_current_user
from sqlalchemy import text

Base.metadata.create_all(bind=engine)

with engine.connect() as conn:
    # Migration: Create societa table
    result = conn.execute(text("""
        SELECT table_name FROM information_schema.tables 
        WHERE table_name = 'societa'
    """))
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
    
    # Migration: Add societa_id to existing tables (only if table exists)
    for table in ['utenti', 'categorie', 'persone', 'registro', 'convocazioni']:
        try:
            result = conn.execute(text(f"""
                SELECT column_name FROM information_schema.columns 
                WHERE table_name = '{table}' AND column_name = 'societa_id'
            """))
            if result.fetchone() is None:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN societa_id INTEGER REFERENCES societa(id)"))
                conn.commit()
                print(f"Migration: Added societa_id to {table}")
        except:
            pass
    
    # Migration: Add is_super_admin to utenti
    try:
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'utenti' AND column_name = 'is_super_admin'
        """))
        if result.fetchone() is None:
            conn.execute(text("ALTER TABLE utenti ADD COLUMN is_super_admin INTEGER DEFAULT 0"))
            conn.commit()
            print("Migration: Added is_super_admin to utenti")
    except:
        pass
    
    # Migration: Ensure admin user is super_admin
    try:
        result = conn.execute(text("""
            SELECT id FROM utenti WHERE username = 'admin' LIMIT 1
        """))
        admin_user = result.fetchone()
        if admin_user:
            conn.execute(text("UPDATE utenti SET is_super_admin = 1, is_admin = 1 WHERE username = 'admin'"))
            conn.commit()
            print("Migration: Set admin user as super_admin")
    except:
        pass
    
    # Ensure all other users have is_super_admin = 0
    try:
        conn.execute(text("UPDATE utenti SET is_super_admin = 0 WHERE username != 'admin' AND is_super_admin IS NULL"))
        conn.commit()
    except:
        pass
    
    # Migration: Create default society if none exists
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
    except:
        pass
    
    # Migration: Add spazio and tempo columns to catalogo_esercizi
    try:
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'catalogo_esercizi' AND column_name = 'spazio'
        """))
        if result.fetchone() is None:
            conn.execute(text("ALTER TABLE catalogo_esercizi ADD COLUMN spazio VARCHAR(50)"))
            conn.execute(text("ALTER TABLE catalogo_esercizi ADD COLUMN tempo VARCHAR(50)"))
            conn.commit()
            print("Migration: Added spazio and tempo columns to catalogo_esercizi")
    except Exception as e:
        print(f"Migration warning (non-critical): {e}")
        conn.rollback()

app = FastAPI(title="Registro Presenze API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"], expose_headers=["*"])

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

app.include_router(auth_router)
app.include_router(societa.router)
app.include_router(persone.router, dependencies=[Depends(get_current_user)])
app.include_router(registro.router, dependencies=[Depends(get_current_user)])
app.include_router(codici.router, dependencies=[Depends(get_current_user)])
app.include_router(categorie.router, dependencies=[Depends(get_current_user)])
app.include_router(convocazioni.router, dependencies=[Depends(get_current_user)])
app.include_router(allenatori.router, dependencies=[Depends(get_current_user)])
app.include_router(allenamenti.router)
app.include_router(gruppi_router, dependencies=[Depends(get_current_user)])

@app.get("/")
def root():
    return {"status": "ok"}
