from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from .. import models, schemas
from ..database import get_db
from typing import Optional

router = APIRouter(prefix="/registro", tags=["registro"])

@router.get("/mese/{categoria_id}/{anno}/{mese}", response_model=list[schemas.RegistroOut])
def get_mese(categoria_id: int, anno: int, mese: int, db: Session = Depends(get_db)):
    from sqlalchemy import extract
    return db.query(models.Registro).filter(
        models.Registro.categoria_id == categoria_id,
        extract("year", models.Registro.data) == anno,
        extract("month", models.Registro.data) == mese
    ).all()

@router.post("/", response_model=schemas.RegistroOut)
def upsert_registro(entry: schemas.RegistroEntry, db: Session = Depends(get_db)):
    existing = db.query(models.Registro).filter(
        models.Registro.persona_id == entry.persona_id,
        models.Registro.data == entry.data
    ).first()
    if existing:
        existing.codice = entry.codice
        db.commit(); db.refresh(existing)
        return existing
    r = models.Registro(**entry.dict())
    db.add(r); db.commit(); db.refresh(r)
    return r
