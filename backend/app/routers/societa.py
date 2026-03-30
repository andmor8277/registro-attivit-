from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
import os
import shutil
from pathlib import Path
from ..database import SessionLocal
from ..models import Societa
from .auth import get_admin, get_current_user

UPLOAD_DIR = Path(__file__).parent.parent.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

router = APIRouter(prefix="/societa", tags=["societa"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class SocietaIn(BaseModel):
    nome: str
    nome_breve: Optional[str] = None
    logo: Optional[str] = None
    logosponsor: Optional[str] = None
    colore_primario: Optional[str] = "#dc2626"
    colore_secondario: Optional[str] = "#1f2937"

class SocietaOut(BaseModel):
    id: int
    nome: str
    nome_breve: Optional[str]
    logo: Optional[str]
    logosponsor: Optional[str]
    colore_primario: str
    colore_secondario: str
    is_attiva: int

    class Config:
        from_attributes = True

@router.get("/", response_model=list[SocietaOut])
def lista_societa(db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return db.query(Societa).all()

@router.get("/{sid}", response_model=SocietaOut)
def get_societa(sid: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    s = db.query(Societa).filter(Societa.id == sid).first()
    if not s:
        raise HTTPException(status_code=404, detail="Società non trovata")
    return s

@router.post("/", response_model=SocietaOut)
def crea_societa(data: SocietaIn, db: Session = Depends(get_db), current_user=Depends(get_admin)):
    s = Societa(**data.model_dump())
    db.add(s)
    db.commit()
    db.refresh(s)
    return s

@router.put("/{sid}", response_model=SocietaOut)
def aggiorna_societa(sid: int, data: SocietaIn, db: Session = Depends(get_db), current_user=Depends(get_admin)):
    s = db.query(Societa).filter(Societa.id == sid).first()
    if not s:
        raise HTTPException(status_code=404, detail="Società non trovata")
    for k, v in data.model_dump().items():
        setattr(s, k, v)
    db.commit()
    db.refresh(s)
    return s

@router.delete("/{sid}")
def elimina_societa(sid: int, db: Session = Depends(get_db), current_user=Depends(get_admin)):
    s = db.query(Societa).filter(Societa.id == sid).first()
    if not s:
        raise HTTPException(status_code=404, detail="Società non trovata")
    db.delete(s)
    db.commit()
    return {"ok": True}

@router.post("/upload/{tipo}")
async def upload_file(tipo: str, file: UploadFile = File(...), current_user=Depends(get_admin)):
    if tipo not in ["logo", "logosponsor"]:
        raise HTTPException(status_code=400, detail="Tipo file non valido")
    
    filename = f"{tipo}_{file.filename}"
    filepath = UPLOAD_DIR / filename
    
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    return {"filename": filename}
