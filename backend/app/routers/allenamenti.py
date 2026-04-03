from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from .. import models
from ..database import get_db
from pydantic import BaseModel
from typing import Optional, List
from datetime import date, datetime

router = APIRouter(prefix="/allenamenti", tags=["allenamenti"])

class EsercizioElemento(BaseModel):
    tipo: str
    x: float
    y: float
    rotazione: float = 0
    colore: Optional[str] = None
    numero: Optional[int] = None

class EsercizioCreate(BaseModel):
    ordine: int
    titolo: Optional[str] = None
    descrizione: Optional[str] = None
    campo_con_righe: bool = True
    elementi: List[EsercizioElemento] = []

class GiornoCreate(BaseModel):
    data: date
    note: Optional[str] = None
    esercizi: List[EsercizioCreate] = []

class SettimanaCreate(BaseModel):
    numero_settimana: int
    data_inizio: date
    giorni: List[GiornoCreate] = []

class MeseCreate(BaseModel):
    nome_mese: str
    settimane: List[SettimanaCreate] = []

class AllenamentoJson(BaseModel):
    categoria_id: int
    data: date
    esercizi: List[EsercizioCreate] = []

@router.get("/giorno-by-data/{categoria_id}/{data}")
def get_giorno_by_data(categoria_id: int, data: str, db: Session = Depends(get_db)):
    from datetime import datetime
    data_date = datetime.strptime(data, "%Y-%m-%d").date()
    
    row = db.query(models.Allenamento).filter(
        models.Allenamento.categoria_id == categoria_id,
        models.Allenamento.data == data_date
    ).first()
    
    if not row:
        return {"giorno": {"id": None, "data": data_date}, "esercizi": []}
    
    esercizi = row.esercizi or []
    return {"giorno": {"id": row.id, "data": row.data}, "esercizi": esercizi}

@router.post("/")
def save_allenamento(data: AllenamentoJson, db: Session = Depends(get_db)):
    from datetime import datetime
    
    existing = db.query(models.Allenamento).filter(
        models.Allenamento.categoria_id == data.categoria_id,
        models.Allenamento.data == data.data
    ).first()
    
    esercizi_list = [
        {
            "ordine": e.ordine,
            "titolo": e.titolo,
            "descrizione": e.descrizione,
            "campo_con_righe": e.campo_con_righe,
            "elementi": [
                {"tipo": el.tipo, "x": el.x, "y": el.y, "rotazione": el.rotazione, "colore": el.colore, "numero": el.numero}
                for el in e.elementi
            ]
        }
        for e in data.esercizi
    ]
    
    if existing:
        existing.esercizi = esercizi_list
        existing.updated_at = datetime.now()
    else:
        new_row = models.Allenamento(
            categoria_id=data.categoria_id,
            data=data.data,
            esercizi=esercizi_list
        )
        db.add(new_row)
    
    db.commit()
    return {"success": True}
