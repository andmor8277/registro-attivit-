from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from .. import models, schemas
from ..database import get_db
from ..routers.auth import get_current_user
from ..models import Utente
from typing import Optional

router = APIRouter(prefix="/registro", tags=["registro"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

@router.get("/mese/{categoria_id}/{anno}/{mese}", response_model=list[schemas.RegistroOut])
def get_mese(categoria_id: int, anno: int, mese: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import extract
    societa_id = get_societa_filter(current_user)
    query = db.query(models.Registro).filter(
        models.Registro.categoria_id == categoria_id,
        extract("year", models.Registro.data) == anno,
        extract("month", models.Registro.data) == mese
    )
    if societa_id:
        query = query.filter(models.Registro.societa_id == societa_id)
    return query.all()

@router.post("/", response_model=schemas.RegistroOut)
def upsert_registro(entry: schemas.RegistroEntry, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    existing = db.query(models.Registro).filter(
        models.Registro.persona_id == entry.persona_id,
        models.Registro.data == entry.data
    ).first()
    if existing:
        existing.codice = entry.codice
        if societa_id:
            existing.societa_id = societa_id
        db.commit(); db.refresh(existing)
        return existing
    data = entry.dict()
    data["societa_id"] = societa_id
    r = models.Registro(**data)
    db.add(r); db.commit(); db.refresh(r)
    return r
