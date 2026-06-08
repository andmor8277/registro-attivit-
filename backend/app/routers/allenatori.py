from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from ..database import SessionLocal
from ..models import Allenatore
from .auth import get_current_user

router = APIRouter(prefix="/allenatori", tags=["allenatori"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class AllenatoreIn(BaseModel):
    cognome: str

class AllenatoreOut(BaseModel):
    id: int
    cognome: str

    class Config:
        from_attributes = True

@router.get("/", response_model=list[AllenatoreOut])
def lista(db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    allenatori = db.query(Allenatore).order_by(Allenatore.cognome).all()
    return allenatori

@router.post("/", response_model=AllenatoreOut)
def crea(data: AllenatoreIn, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    a = Allenatore(cognome=data.cognome)
    db.add(a)
    db.commit()
    db.refresh(a)
    return a

@router.put("/{aid}", response_model=AllenatoreOut)
def aggiorna(aid: int, data: AllenatoreIn, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    a = db.query(Allenatore).filter(Allenatore.id == aid).first()
    if not a:
        raise HTTPException(status_code=404, detail="Allenatore non trovato")
    a.cognome = data.cognome
    db.commit()
    db.refresh(a)
    return a

@router.delete("/{aid}")
def elimina(aid: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    a = db.query(Allenatore).filter(Allenatore.id == aid).first()
    if not a:
        raise HTTPException(status_code=404, detail="Allenatore non trovato")
    db.delete(a)
    db.commit()
    return {"ok": True}
