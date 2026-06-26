from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text, or_
from .. import models
from ..database import get_db
from pydantic import BaseModel
from typing import Optional, List
from datetime import date, datetime
from .auth import get_current_user

router = APIRouter(prefix="/allenamenti", tags=["allenamenti"])

class EsercizioElemento(BaseModel):
    tipo: str
    x: Optional[float] = None
    y: Optional[float] = None
    rotazione: float = 0
    colore: Optional[str] = None
    numero: Optional[int] = None
    length: Optional[float] = None
    wavy: Optional[bool] = None
    size: Optional[float] = None
    w: Optional[float] = None
    x1: Optional[float] = None
    y1: Optional[float] = None
    x2: Optional[float] = None
    y2: Optional[float] = None
    points: Optional[List] = None
    text: Optional[str] = None

class EsercizioCreate(BaseModel):
    ordine: int
    titolo: Optional[str] = None
    descrizione: Optional[str] = None
    focus: Optional[str] = None
    spazio: Optional[str] = None
    tempo: Optional[str] = None
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
def save_allenamento(data: AllenamentoJson, db: Session = Depends(get_db), current_user: models.Utente = Depends(get_current_user)):
    from datetime import datetime
    import logging
    logger = logging.getLogger(__name__)
    
    # Autorizzazione: admin/super_admin possono modificare, mister/segreteria solo se assegnati alla categoria
    if not current_user.is_admin and not current_user.is_super_admin:
        assegnazioni = db.query(models.UtenteCategoria).filter(
            models.UtenteCategoria.utente_id == current_user.id,
            models.UtenteCategoria.categoria_id == data.categoria_id
        ).first()
        if not assegnazioni:
            raise HTTPException(status_code=403, detail="Non autorizzato a modificare questa categoria")
    
    logger.info(f"save_allenamento: categoria_id={data.categoria_id}, data={data.data}, esercizi={len(data.esercizi)}")
    
    existing = db.query(models.Allenamento).filter(
        models.Allenamento.categoria_id == data.categoria_id,
        models.Allenamento.data == data.data
    ).first()
    
    logger.info(f"save_allenamento: existing={existing is not None}")
    
    esercizi_list = [
        {
            "ordine": e.ordine,
            "titolo": e.titolo,
            "descrizione": e.descrizione,
            "focus": e.focus,
            "spazio": e.spazio,
            "tempo": e.tempo,
            "campo_con_righe": e.campo_con_righe,
            "elementi": [
                {
                    "tipo": el.tipo, 
                    "x": el.x, 
                    "y": el.y, 
                    "rotazione": el.rotazione, 
                    "colore": el.colore, 
                    "numero": el.numero,
                    "length": el.length,
                    "wavy": el.wavy,
                    "size": el.size,
                    "w": el.w,
                    "x1": el.x1,
                    "y1": el.y1,
                    "x2": el.x2,
                    "y2": el.y2,
                    "points": el.points,
                    "text": el.text
                }
                for el in e.elementi
            ]
        }
        for e in data.esercizi
    ]
    
    logger.info(f"save_allenamento: esercizi_list={len(esercizi_list)}, first elementi={len(esercizi_list[0]['elementi']) if esercizi_list else 0}")
    
    if existing:
        existing.esercizi = esercizi_list
        existing.updated_at = datetime.now()
        logger.info(f"save_allenamento: updated existing row id={existing.id}")
    else:
        new_row = models.Allenamento(
            categoria_id=data.categoria_id,
            data=data.data,
            esercizi=esercizi_list
        )
        db.add(new_row)
        logger.info(f"save_allenamento: added new row")
    
    try:
        db.commit()
        logger.info(f"save_allenamento: committed successfully")
    except Exception as e:
        logger.error(f"save_allenamento: commit failed: {e}")
        db.rollback()
        raise
    
    return {"success": True}

@router.get("/focus-list")
def get_focus_list(db: Session = Depends(get_db)):
    return {
        "focus_options": [
            {"value": "", "label": "Tutti"},
            {"value": "attivazione", "label": "Attivazione"},
            {"value": "tecnica", "label": "Tecnica"},
            {"value": "tattica", "label": "Tattica"},
            {"value": "fisico", "label": "Fisico"},
            {"value": "capacita-coordinativa", "label": "Capacità Coordinativa"},
            {"value": "palleggio", "label": "Palleggio"},
            {"value": "passaggio", "label": "Passaggio"},
            {"value": "conclusione", "label": "Conclusione"},
            {"value": "difesa", "label": "Difesa"},
            {"value": "attacco", "label": "Attacco"},
            {"value": "possessione", "label": "Possesso"},
            {"value": "set-piece", "label": "Set Piece"}
        ]
    }

@router.get("/catalogo-new")
def get_catalogo_new(focus: Optional[str] = None, db: Session = Depends(get_db), current_user: models.Utente = Depends(get_current_user)):
    query = db.query(models.CatalogoEsercizio)
    if focus:
        query = query.filter(models.CatalogoEsercizio.focus == focus)

    # Filter: public exercises + society-only exercises from user's own society
    user_societa_id = current_user.societa_id
    query = query.filter(
        or_(
            models.CatalogoEsercizio.visibilita == 'pubblico',
            and_(
                models.CatalogoEsercizio.visibilita == 'societa',
                models.CatalogoEsercizio.societa_id == user_societa_id
            )
        )
    )

    esercizi = query.order_by(models.CatalogoEsercizio.titolo).all()
    
    focus_nomi = {
        'attivazione': 'Attivazione', 'tecnica': 'Tecnica', 'tattica': 'Tattica', 'fisico': 'Fisico',
        'capacita-coordinativa': 'Cap. Coordinativa', 'palleggio': 'Palleggio',
        'passaggio': 'Passaggio', 'conclusione': 'Conclusione', 'difesa': 'Difesa',
        'attacco': 'Attacco', 'possessione': 'Possesso', 'set-piece': 'Set Piece'
    }
    
    return {
        "esercizi": [
            {
                "id": e.id,
                "titolo": e.titolo,
                "focus": e.focus or '',
                "spazio": e.spazio or '',
                "tempo": e.tempo or '',
                "focus_label": focus_nomi.get(e.focus, 'Nessuno'),
                "descrizione": e.descrizione or '',
                "campo_con_righe": e.campo_con_righe,
                "elementi": e.elementi or [],
                "creato_da": e.creato_da,
                "creato_il": e.creato_il.isoformat() if e.creato_il else None,
                "visibilita": e.visibilita or 'pubblico',
                "can_delete": current_user.is_super_admin or e.creato_da == current_user.id
            }
            for e in esercizi
        ],
        "totale": len(esercizi),
        "current_user_id": current_user.id,
        "is_super_admin": current_user.is_super_admin
    }

class CatalogoEsercizioIn(BaseModel):
    titolo: str
    focus: Optional[str] = ''
    spazio: Optional[str] = ''
    tempo: Optional[str] = ''
    descrizione: Optional[str] = ''
    campo_con_righe: bool = True
    elementi: List[EsercizioElemento] = []
    visibilita: str = 'pubblico'

@router.post("/catalogo-new")
def save_to_catalogo(data: CatalogoEsercizioIn, db: Session = Depends(get_db), current_user: models.Utente = Depends(get_current_user)):
    from datetime import datetime
    
    titolo = data.titolo.strip()
    if not titolo:
        raise HTTPException(status_code=400, detail="Titolo richiesto")
    
    existing = db.query(models.CatalogoEsercizio).filter(
        models.CatalogoEsercizio.titolo == titolo
    ).first()
    
    if existing:
        # Solo il creatore o super_admin possono aggiornare un esercizio esistente
        if not (current_user.is_super_admin or existing.creato_da == current_user.id):
            raise HTTPException(status_code=403, detail="Solo l'autore può modificare questo esercizio")
        existing.focus = data.focus
        existing.spazio = data.spazio
        existing.tempo = data.tempo
        existing.descrizione = data.descrizione
        existing.campo_con_righe = data.campo_con_righe
        existing.elementi = [e.model_dump() for e in data.elementi]
        existing.visibilita = data.visibilita
        existing.aggiornato_il = datetime.now()
    else:
        new_ex = models.CatalogoEsercizio(
            titolo=titolo,
            focus=data.focus,
            spazio=data.spazio,
            tempo=data.tempo,
            descrizione=data.descrizione,
            campo_con_righe=data.campo_con_righe,
            elementi=[e.model_dump() for e in data.elementi],
            creato_da=current_user.id,
            creato_il=datetime.now(),
            visibilita=data.visibilita,
            societa_id=current_user.societa_id
        )
        db.add(new_ex)
    
    db.commit()
    return {"success": True}

@router.delete("/catalogo-new/{esercizio_id}")
def delete_from_catalogo(esercizio_id: int, db: Session = Depends(get_db), current_user: models.Utente = Depends(get_current_user)):
    esercizio = db.query(models.CatalogoEsercizio).filter(
        models.CatalogoEsercizio.id == esercizio_id
    ).first()
    
    if not esercizio:
        raise HTTPException(status_code=404, detail="Esercizio non trovato")
    
    if not (current_user.is_super_admin or esercizio.creato_da == current_user.id):
        raise HTTPException(status_code=403, detail="Non hai i permessi per eliminare questo esercizio")
    
    db.delete(esercizio)
    db.commit()
    return {"success": True}
