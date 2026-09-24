from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import date, datetime
from .. import models
from ..database import get_db
from ..routers.auth import get_current_user
from ..models import Utente
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/planning-eventi", tags=["planning-eventi"])

class PlanningEventoCreate(BaseModel):
    categoria_id: int
    data: date
    tipo: str  # sospensione, vacanza, evento, festa, gara
    titolo: Optional[str] = None
    note: Optional[str] = None

class PlanningEventoUpdate(BaseModel):
    data: Optional[date] = None
    tipo: Optional[str] = None
    titolo: Optional[str] = None
    note: Optional[str] = None

@router.get("/")
def get_eventi(
    categoria_id: Optional[int] = None,
    societa_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    query = db.query(models.PlanningEvento)
    if current_user.societa_id and not current_user.is_super_admin:
        query = query.filter(models.PlanningEvento.societa_id == current_user.societa_id)
    elif societa_id:
        query = query.filter(models.PlanningEvento.societa_id == societa_id)
    if categoria_id:
        query = query.filter(models.PlanningEvento.categoria_id == categoria_id)
    return query.order_by(models.PlanningEvento.data.desc()).all()

@router.post("/")
def create_evento(
    evento: PlanningEventoCreate,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    societa_id = current_user.societa_id
    if not societa_id:
        raise HTTPException(status_code=400, detail="Società non impostata")
    db_evento = models.PlanningEvento(
        categoria_id=evento.categoria_id,
        societa_id=societa_id,
        data=evento.data,
        tipo=evento.tipo,
        titolo=evento.titolo,
        note=evento.note,
        creato_il=datetime.now()
    )
    db.add(db_evento)
    db.commit()
    db.refresh(db_evento)
    return db_evento

@router.put("/{evento_id}")
def update_evento(
    evento_id: int,
    evento: PlanningEventoUpdate,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    db_evento = db.query(models.PlanningEvento).filter(
        models.PlanningEvento.id == evento_id
    ).first()
    if not db_evento:
        raise HTTPException(status_code=404, detail="Evento non trovato")
    if current_user.societa_id and db_evento.societa_id != current_user.societa_id and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    update_data = evento.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_evento, key, value)
    db.commit()
    db.refresh(db_evento)
    return db_evento

@router.delete("/{evento_id}")
def delete_evento(
    evento_id: int,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    db_evento = db.query(models.PlanningEvento).filter(
        models.PlanningEvento.id == evento_id
    ).first()
    if not db_evento:
        raise HTTPException(status_code=404, detail="Evento non trovato")
    if current_user.societa_id and db_evento.societa_id != current_user.societa_id and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    db.delete(db_evento)
    db.commit()
    return {"ok": True}
