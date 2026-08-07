from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from ..database import get_db
from ..models import Allenatore
from .auth import get_current_user

router = APIRouter(prefix="/allenatori", tags=["allenatori"])

def get_societa_filter(user):
    if user.is_super_admin:
        return None
    return user.societa_id

class AllenatoreIn(BaseModel):
    cognome: str

class AllenatoreOut(BaseModel):
    id: int
    cognome: str

    class Config:
        from_attributes = True

@router.get("/", response_model=list[AllenatoreOut])
def lista(db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    query = db.query(Allenatore)
    sid = get_societa_filter(current_user)
    if sid:
        query = query.filter(Allenatore.societa_id == sid)
    return query.order_by(Allenatore.cognome).all()

@router.post("/", response_model=AllenatoreOut)
def crea(data: AllenatoreIn, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    a = Allenatore(cognome=data.cognome, societa_id=societa_id)
    db.add(a)
    db.commit()
    db.refresh(a)
    return a

@router.put("/{aid}", response_model=AllenatoreOut)
def aggiorna(aid: int, data: AllenatoreIn, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    a = _get_owned(aid, current_user, db)
    a.cognome = data.cognome
    db.commit()
    db.refresh(a)
    return a

@router.delete("/{aid}")
def elimina(aid: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    a = _get_owned(aid, current_user, db)
    db.delete(a)
    db.commit()
    return {"ok": True}

def _get_owned(aid, user, db):
    query = db.query(Allenatore).filter(Allenatore.id == aid)
    soc = get_societa_filter(user)
    if soc:
        query = query.filter(Allenatore.societa_id == soc)
    a = query.first()
    if not a:
        raise HTTPException(status_code=404, detail="Allenatore non trovato")
    return a
