from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
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

@router.get("/mese/{categoria_id}")
def get_mesi(categoria_id: int, db: Session = Depends(get_db)):
    mesi = db.query(models.AllenamentoMese).filter(models.AllenamentoMese.categoria_id == categoria_id).all()
    return mesi

@router.get("/giorno-by-data/{categoria_id}/{data}")
def get_giorno_by_data(categoria_id: int, data: str, db: Session = Depends(get_db)):
    from datetime import datetime
    data_date = datetime.strptime(data, "%Y-%m-%d").date()
    
    anno = data_date.year
    mese_num = data_date.month
    
    mese = db.query(models.AllenamentoMese).filter(
        models.AllenamentoMese.categoria_id == categoria_id,
        models.AllenamentoMese.nome_mese == f"{anno}-{mese_num:02d}"
    ).first()
    
    if not mese:
        mese = models.AllenamentoMese(categoria_id=categoria_id, nome_mese=f"{anno}-{mese_num:02d}", created_at=datetime.now())
        db.add(mese)
        db.commit()
        db.refresh(mese)
    
    week_num = (data_date.day - 1) // 7 + 1
    settimana = db.query(models.AllenamentoSettimana).filter(
        models.AllenamentoSettimana.mese_id == mese.id,
        models.AllenamentoSettimana.numero_settimana == week_num
    ).first()
    
    if not settimana:
        settimana = models.AllenamentoSettimana(mese_id=mese.id, numero_settimana=week_num, data_inizio=data_date, created_at=datetime.now())
        db.add(settimana)
        db.commit()
        db.refresh(settimana)
    
    giorno = db.query(models.AllenamentoGiorno).filter(
        models.AllenamentoGiorno.settimana_id == settimana.id,
        models.AllenamentoGiorno.data == data_date
    ).first()
    
    if not giorno:
        giorno = models.AllenamentoGiorno(settimana_id=settimana.id, data=data_date, created_at=datetime.now())
        db.add(giorno)
        db.commit()
        db.refresh(giorno)
    
    esercizi = db.query(models.AllenamentoEsercizio).filter(models.AllenamentoEsercizio.giorno_id == giorno.id).order_by(models.AllenamentoEsercizio.ordine).all()
    result = []
    for e in esercizi:
        elementi = db.query(models.AllenamentoElemento).filter(models.AllenamentoElemento.esercizio_id == e.id).all()
        result.append({
            "id": e.id,
            "ordine": e.ordine,
            "titolo": e.titolo,
            "descrizione": e.descrizione,
            "campo_con_righe": e.campo_con_righe,
            "elementi": [{"id": el.id, "tipo": el.tipo, "x": el.x, "y": el.y, "rotazione": el.rotazione, "colore": el.colore, "numero": el.numero} for el in elementi]
        })
    return {"giorno": {"id": giorno.id, "data": giorno.data}, "esercizi": result}

@router.get("/settimana/{mese_id}")
def get_settimane(mese_id: int, db: Session = Depends(get_db)):
    settimane = db.query(models.AllenamentoSettimana).filter(models.AllenamentoSettimana.mese_id == mese_id).order_by(models.AllenamentoSettimana.numero_settimana).all()
    return settimane

@router.get("/giorno/{settimana_id}")
def get_giorni(settimana_id: int, db: Session = Depends(get_db)):
    giorni = db.query(models.AllenamentoGiorno).filter(models.AllenamentoGiorno.settimana_id == settimana_id).order_by(models.AllenamentoGiorno.data).all()
    return giorni

@router.get("/esercizio/{giorno_id}")
def get_esercizi(giorno_id: int, db: Session = Depends(get_db)):
    esercizi = db.query(models.AllenamentoEsercizio).filter(models.AllenamentoEsercizio.giorno_id == giorno_id).order_by(models.AllenamentoEsercizio.ordine).all()
    result = []
    for e in esercizi:
        elementi = db.query(models.AllenamentoElemento).filter(models.AllenamentoElemento.esercizio_id == e.id).all()
        result.append({
            "id": e.id,
            "ordine": e.ordine,
            "titolo": e.titolo,
            "descrizione": e.descrizione,
            "campo_con_righe": e.campo_con_righe,
            "elementi": [{"id": el.id, "tipo": el.tipo, "x": el.x, "y": el.y, "rotazione": el.rotazione, "colore": el.colore, "numero": el.numero} for el in elementi]
        })
    return result

@router.post("/mese")
def create_mese(data: MeseCreate, db: Session = Depends(get_db)):
    mese = models.AllenamentoMese(categoria_id=data.settimane[0].giorni[0].data if data.settimane and data.settimane[0].giorni else None, nome_mese=data.nome_mese)
    db.add(mese)
    db.commit()
    db.refresh(mese)
    return mese

@router.post("/")
def create_allenamento_completo(data: MeseCreate, db: Session = Depends(get_db), categoria_id: int = 1):
    from datetime import datetime
    
    # Parse nome_mese to get anno and mese
    anno, mese_num = map(int, data.nome_mese.split('-'))
    
    # Find or create month
    mese = db.query(models.AllenamentoMese).filter(
        models.AllenamentoMese.categoria_id == categoria_id,
        models.AllenamentoMese.nome_mese == data.nome_mese
    ).first()
    
    if not mese:
        mese = models.AllenamentoMese(categoria_id=categoria_id, nome_mese=data.nome_mese, created_at=datetime.now())
        db.add(mese)
        db.commit()
        db.refresh(mese)
    
    # Process each week
    for sem_data in data.settimane:
        settimana = db.query(models.AllenamentoSettimana).filter(
            models.AllenamentoSettimana.mese_id == mese.id,
            models.AllenamentoSettimana.numero_settimana == sem_data.numero_settimana
        ).first()
        
        if not settimana:
            settimana = models.AllenamentoSettimana(mese_id=mese.id, numero_settimana=sem_data.numero_settimana, data_inizio=sem_data.data_inizio, created_at=datetime.now())
            db.add(settimana)
            db.commit()
            db.refresh(settimana)
        
        for g_data in sem_data.giorni:
            giorno = db.query(models.AllenamentoGiorno).filter(
                models.AllenamentoGiorno.settimana_id == settimana.id,
                models.AllenamentoGiorno.data == g_data.data
            ).first()
            
            if not giorno:
                giorno = models.AllenamentoGiorno(settimana_id=settimana.id, data=g_data.data, note=g_data.note, created_at=datetime.now())
                db.add(giorno)
                db.commit()
                db.refresh(giorno)
            
            # Delete existing exercises for this day
            db.query(models.AllenamentoEsercizio).filter(models.AllenamentoEsercizio.giorno_id == giorno.id).delete()
            
            # Create new exercises
            for e_data in g_data.esercizi:
                esercizio = models.AllenamentoEsercizio(giorno_id=giorno.id, ordine=e_data.ordine, titolo=e_data.titolo, descrizione=e_data.descrizione, campo_con_righe=e_data.campo_con_righe, created_at=datetime.now())
                db.add(esercizio)
                db.commit()
                db.refresh(esercizio)
                
                for el_data in e_data.elementi:
                    elemento = models.AllenamentoElemento(esercizio_id=esercizio.id, tipo=el_data.tipo, x=el_data.x, y=el_data.y, rotazione=el_data.rotazione, colore=el_data.colore, numero=el_data.numero)
                    db.add(elemento)
    
    db.commit()
    return {"success": True, "mese_id": mese.id}
