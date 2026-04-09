from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from .. import models
from ..database import get_db
from pydantic import BaseModel
from typing import Optional, List
from datetime import date, datetime
from .auth import get_current_user

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
    focus: Optional[str] = None
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
            "focus": e.focus,
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

def normalize_titolo(titolo):
    if not titolo:
        return ''
    return titolo.strip().lower()

@router.get("/catalogo")
def get_catalogo(focus: Optional[str] = None, db: Session = Depends(get_db)):
    rows = db.query(models.Allenamento).all()
    
    catalogo_dict = {}
    focus_nomi = {
        'tecnica': 'Tecnica',
        'tattica': 'Tattica',
        'fisico': 'Fisico',
        'capacita-coordinativa': 'Cap. Coordinativa',
        'palleggio': 'Palleggio',
        'passaggio': 'Passaggio',
        'conclusione': 'Conclusione',
        'difesa': 'Difesa',
        'attacco': 'Attacco',
        'possessione': 'Possesso',
        'set-piece': 'Set Piece'
    }
    
    for row in rows:
        esercizi = row.esercizi or []
        for ex in esercizi:
            ex_focus = ex.get('focus', '') if isinstance(ex, dict) else getattr(ex, 'focus', '')
            
            if focus and ex_focus != focus:
                continue
            
            titolo = ex.get('titolo', '') if isinstance(ex, dict) else getattr(ex, 'titolo', '')
            if not titolo or not titolo.strip():
                continue
            
            titolo_key = normalize_titolo(titolo)
            if not titolo_key:
                continue
            
            titolo_display = titolo.strip()
            
            if titolo_key in catalogo_dict:
                catalogo_dict[titolo_key]['count'] += 1
            else:
                catalogo_dict[titolo_key] = {
                    "titolo": titolo_display,
                    "focus": ex_focus,
                    "focus_label": focus_nomi.get(ex_focus, ex_focus) if ex_focus else 'Nessuno',
                    "descrizione": ex.get('descrizione', '') if isinstance(ex, dict) else '',
                    "campo_con_righe": ex.get('campo_con_righe', True) if isinstance(ex, dict) else True,
                    "elementi": ex.get('elementi', []) if isinstance(ex, dict) else [],
                    "categoria_id": row.categoria_id,
                    "data": row.data.isoformat() if row.data else None,
                    "count": 1
                }
    
    catalogo = sorted(catalogo_dict.values(), key=lambda x: x['titolo'].lower())
    
    return {"esercizi": list(catalogo), "totale": len(catalogo)}

@router.get("/check-titolo")
def check_titolo(titolo: str, db: Session = Depends(get_db)):
    titolo_key = normalize_titolo(titolo)
    if not titolo_key:
        return {"exists": False, "message": ""}
    
    rows = db.query(models.Allenamento).all()
    
    for row in rows:
        esercizi = row.esercizi or []
        for ex in esercizi:
            ex_titolo = ex.get('titolo', '') if isinstance(ex, dict) else getattr(ex, 'titolo', '')
            if ex_titolo and normalize_titolo(ex_titolo) == titolo_key:
                return {
                    "exists": True,
                    "message": f"Esiste già un esercizio chiamato '{ex_titolo.strip()}'"
                }
    
    return {"exists": False, "message": ""}

@router.get("/focus-list")
def get_focus_list(db: Session = Depends(get_db)):
    return {
        "focus_options": [
            {"value": "", "label": "Tutti"},
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
    
    esercizi = query.order_by(models.CatalogoEsercizio.titolo).all()
    
    focus_nomi = {
        'tecnica': 'Tecnica', 'tattica': 'Tattica', 'fisico': 'Fisico',
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
                "focus_label": focus_nomi.get(e.focus, 'Nessuno'),
                "descrizione": e.descrizione or '',
                "campo_con_righe": e.campo_con_righe,
                "elementi": e.elementi or [],
                "creato_da": e.creato_da,
                "creato_il": e.creato_il.isoformat() if e.creato_il else None,
                "can_delete": current_user.is_super_admin or e.creato_da == current_user.id
            }
            for e in esercizi
        ],
        "totale": len(esercizi),
        "current_user_id": current_user.id,
        "is_super_admin": current_user.is_super_admin
    }

@router.post("/catalogo-new")
def save_to_catalogo(data: dict, db: Session = Depends(get_db), current_user: models.Utente = Depends(get_current_user)):
    from datetime import datetime
    
    titolo = data.get('titolo', '').strip()
    if not titolo:
        raise HTTPException(status_code=400, detail="Titolo richiesto")
    
    existing = db.query(models.CatalogoEsercizio).filter(
        models.CatalogoEsercizio.titolo == titolo
    ).first()
    
    if existing:
        existing.focus = data.get('focus', '')
        existing.descrizione = data.get('descrizione', '')
        existing.campo_con_righe = data.get('campo_con_righe', True)
        existing.elementi = data.get('elementi', [])
        existing.aggiornato_il = datetime.now()
    else:
        new_ex = models.CatalogoEsercizio(
            titolo=titolo,
            focus=data.get('focus', ''),
            descrizione=data.get('descrizione', ''),
            campo_con_righe=data.get('campo_con_righe', True),
            elementi=data.get('elementi', []),
            creato_da=current_user.id,
            creato_il=datetime.now()
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
