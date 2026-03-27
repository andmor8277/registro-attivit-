from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from .database import Base, engine
from .routers import persone, registro, codici, categorie, convocazioni, allenatori
from .routers.auth import router as auth_router, get_current_user
from sqlalchemy import text

Base.metadata.create_all(bind=engine)

with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT column_name FROM information_schema.columns 
        WHERE table_name = 'categorie' AND column_name = 'drive_folder_id'
    """))
    if result.fetchone() is None:
        conn.execute(text("ALTER TABLE categorie ADD COLUMN drive_folder_id VARCHAR(100)"))
        conn.commit()
        print("Migration: Added drive_folder_id column")

app = FastAPI(title="Registro Presenze API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"], expose_headers=["*"])

app.include_router(auth_router)
app.include_router(persone.router, dependencies=[Depends(get_current_user)])
app.include_router(registro.router, dependencies=[Depends(get_current_user)])
app.include_router(codici.router, dependencies=[Depends(get_current_user)])
app.include_router(categorie.router, dependencies=[Depends(get_current_user)])
app.include_router(convocazioni.router, dependencies=[Depends(get_current_user)])
app.include_router(allenatori.router, dependencies=[Depends(get_current_user)])

@app.get("/")
def root():
    return {"status": "ok"}
