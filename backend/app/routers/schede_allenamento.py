from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_
from datetime import date
from typing import Optional
from pydantic import BaseModel
from .. import models
from ..database import get_db
from ..routers.auth import get_current_user, get_admin
from ..models import Utente

router = APIRouter(prefix="/schede-allenamento", tags=["schede allenamento"])

class SchedaCreate(BaseModel):
    persona_id: int
    categoria_id: int
    data: date
    distanza_totale: Optional[float] = None
    distanza_alta_velocita: Optional[float] = None
    distanza_sprint: Optional[float] = None
    velocita_massima: Optional[float] = None
    accelerazioni: Optional[int] = None
    decelerazioni: Optional[int] = None
    metabolic_power: Optional[float] = None
    player_load: Optional[float] = None
    calorie: Optional[float] = None
    tempo_lavoro: Optional[int] = None
    rpe: Optional[int] = None
    note: Optional[str] = None

@router.get("/")
def get_schede(
    categoria_id: Optional[int] = Query(None),
    data: Optional[date] = Query(None),
    persona_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    query = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.societa_id == current_user.societa_id
    )
    if categoria_id:
        query = query.filter(models.SchedaAllenamento.categoria_id == categoria_id)
    if data:
        query = query.filter(models.SchedaAllenamento.data == data)
    if persona_id:
        query = query.filter(models.SchedaAllenamento.persona_id == persona_id)
    return query.order_by(models.SchedaAllenamento.data.desc()).all()

@router.post("/")
def create_scheda(data: SchedaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import func
    result = db.execute(
        func.now(),
    )
    now = result.scalar()
    scheda = models.SchedaAllenamento(
        persona_id=data.persona_id,
        categoria_id=data.categoria_id,
        societa_id=current_user.societa_id,
        data=data.data,
        distanza_totale=data.distanza_totale,
        distanza_alta_velocita=data.distanza_alta_velocita,
        distanza_sprint=data.distanza_sprint,
        velocita_massima=data.velocita_massima,
        accelerazioni=data.accelerazioni,
        decelerazioni=data.decelerazioni,
        metabolic_power=data.metabolic_power,
        player_load=data.player_load,
        calorie=data.calorie,
        tempo_lavoro=data.tempo_lavoro,
        rpe=data.rpe,
        note=data.note,
        creato_il=now,
    )
    db.add(scheda)
    db.commit()
    db.refresh(scheda)
    return scheda

@router.put("/{scheda_id}")
def update_scheda(scheda_id: int, data: SchedaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    scheda = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.id == scheda_id,
        models.SchedaAllenamento.societa_id == current_user.societa_id
    ).first()
    if not scheda:
        raise HTTPException(status_code=404, detail="Scheda non trovata")
    for field in ['distanza_totale', 'distanza_alta_velocita', 'distanza_sprint', 'velocita_massima',
                  'accelerazioni', 'decelerazioni', 'metabolic_power', 'player_load', 'calorie',
                  'tempo_lavoro', 'rpe', 'note']:
        val = getattr(data, field)
        if val is not None:
            setattr(scheda, field, val)
    db.commit()
    db.refresh(scheda)
    return scheda

@router.delete("/{scheda_id}")
def delete_scheda(scheda_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    scheda = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.id == scheda_id,
        models.SchedaAllenamento.societa_id == current_user.societa_id
    ).first()
    if not scheda:
        raise HTTPException(status_code=404, detail="Scheda non trovata")
    db.delete(scheda)
    db.commit()
    return {"ok": True}
