from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
import os
from pathlib import Path
from uuid import uuid4
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
    is_attiva: Optional[int] = None

    class Config:
        from_attributes = True

@router.get("/", response_model=list[SocietaOut])
def lista_societa(db: Session = Depends(get_db)):
    return db.query(Societa).all()

@router.get("/{sid}", response_model=SocietaOut)
def get_societa(sid: int, db: Session = Depends(get_db)):
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

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "gif", "webp"}
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB

@router.post("/upload/{tipo}")
async def upload_file(tipo: str, file: UploadFile = File(...), current_user=Depends(get_admin)):
    if tipo not in ["logo", "logosponsor"]:
        raise HTTPException(status_code=400, detail="Tipo file non valido")

    # Validate file extension
    ext = Path(file.filename).suffix.lower().lstrip(".")
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Tipo file non consentito. Sono ammessi solo: jpg, jpeg, png, gif, webp")

    # Read file content in chunks and enforce size limit
    content = b""
    while True:
        chunk = await file.read(1024 * 1024)  # 1 MB chunks
        if not chunk:
            break
        content += chunk
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(status_code=400, detail="File troppo grande. Dimensione massima: 5 MB")

    # Validate MIME type by checking magic bytes
    mime_type = None
    if content[:2] == b'\xff\xd8':
        mime_type = "image/jpeg"
    elif content[:8] == b'\x89PNG\r\n\x1a\n':
        mime_type = "image/png"
    elif content[:6] == b'GIF87a' or content[:6] == b'GIF89a':
        mime_type = "image/gif"
    elif content[:4] == b'\x00\x00\x01\x00' or content[:12] == b'\x52\x49\x46\x46\x00\x00\x00\x00\x57\x45\x42\x50':
        mime_type = "image/webp"
    elif content[:4] in (b'RIFF', b'WEBP'):
        mime_type = "image/webp"

    if mime_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(status_code=400, detail="File non valido. Il contenuto non corrisponde a un'immagine")

    # Generate safe filename using uuid4
    safe_filename = f"{tipo}_{uuid4().hex}.{ext}"
    filepath = UPLOAD_DIR / safe_filename

    with open(filepath, "wb") as f:
        f.write(content)

    return {"filename": safe_filename}
