from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from pydantic import BaseModel
from ..database import SessionLocal
from ..models import Convocazione, ConvocazioneGara, ConvocazioneGiocatore, Persona
from .auth import get_current_user

router = APIRouter(prefix="/convocazioni", tags=["convocazioni"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class GiocatoreIn(BaseModel):
    persona_id: int
    posizione: int

class GaraIn(BaseModel):
    numero: int
    gara: Optional[str] = None
    data: Optional[date] = None
    campo: Optional[str] = None
    indirizzo: Optional[str] = None
    appuntamento: Optional[str] = None
    inizio_gara: Optional[str] = None
    allenatore: Optional[str] = None
    giocatori: List[GiocatoreIn] = []

class ConvocazioneIn(BaseModel):
    categoria_id: int
    data_inizio: date
    note: Optional[str] = None
    gare: List[GaraIn] = []

@router.get("/")
def lista(categoria_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    convs = db.query(Convocazione).filter(Convocazione.categoria_id == categoria_id).order_by(Convocazione.data_inizio.desc()).all()
    return [{"id": c.id, "data_inizio": c.data_inizio, "categoria_id": c.categoria_id} for c in convs]

@router.get("/{cid}")
def dettaglio(cid: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    gare = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).order_by(ConvocazioneGara.numero).all()
    result_gare = []
    for g in gare:
        giocatori = db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).order_by(ConvocazioneGiocatore.posizione).all()
        persone = []
        for gk in giocatori:
            p = db.query(Persona).filter(Persona.id == gk.persona_id).first()
            persone.append({"persona_id": gk.persona_id, "posizione": gk.posizione, "nome": p.nome if p else "", "cognome": p.cognome if p else ""})
        result_gare.append({
            "id": g.id, "numero": g.numero, "gara": g.gara, "data": g.data,
            "campo": g.campo, "indirizzo": g.indirizzo, "appuntamento": g.appuntamento,
            "inizio_gara": g.inizio_gara, "allenatore": g.allenatore, "giocatori": persone
        })
    return {"id": c.id, "categoria_id": c.categoria_id, "data_inizio": c.data_inizio, "note": c.note, "gare": result_gare}

@router.post("/")
def crea(data: ConvocazioneIn, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    c = Convocazione(categoria_id=data.categoria_id, data_inizio=data.data_inizio, note=data.note)
    db.add(c)
    db.flush()
    for g in data.gare:
        gara = ConvocazioneGara(convocazione_id=c.id, numero=g.numero, gara=g.gara, data=g.data,
            campo=g.campo, indirizzo=g.indirizzo, appuntamento=g.appuntamento,
            inizio_gara=g.inizio_gara, allenatore=g.allenatore)
        db.add(gara)
        db.flush()
        for gk in g.giocatori:
            db.add(ConvocazioneGiocatore(gara_id=gara.id, persona_id=gk.persona_id, posizione=gk.posizione))
    db.commit()
    return {"id": c.id}

@router.put("/{cid}")
def aggiorna(cid: int, data: ConvocazioneIn, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    c.data_inizio = data.data_inizio
    c.note = data.note
    # Elimina e ricrea gare
    gare_old = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).all()
    for g in gare_old:
        db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).delete()
    db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).delete()
    for g in data.gare:
        gara = ConvocazioneGara(convocazione_id=cid, numero=g.numero, gara=g.gara, data=g.data,
            campo=g.campo, indirizzo=g.indirizzo, appuntamento=g.appuntamento,
            inizio_gara=g.inizio_gara, allenatore=g.allenatore)
        db.add(gara)
        db.flush()
        for gk in g.giocatori:
            db.add(ConvocazioneGiocatore(gara_id=gara.id, persona_id=gk.persona_id, posizione=gk.posizione))
    db.commit()
    return {"ok": True}

@router.delete("/{cid}")
def elimina(cid: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    gare = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).all()
    for g in gare:
        db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).delete()
    db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).delete()
    db.delete(c)
    db.commit()
    return {"ok": True}

from datetime import timedelta

@router.get("/presenze-settimana/{categoria_id}")
def presenze_settimana(categoria_id: int, data_gara: date, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    from ..models import Registro, CodicePresenza
    # Settimana precedente: lun-dom prima del weekend di gara
    giorno_settimana = data_gara.weekday()  # 0=lun, 6=dom
    inizio_sett = data_gara - timedelta(days=giorno_settimana + 7)
    fine_sett = inizio_sett + timedelta(days=6)

    # Codici assenza
    codici_assenza = [c.codice for c in db.query(CodicePresenza).filter(CodicePresenza.tipo == "assenza").all()]

    persone = db.query(Persona).filter(Persona.categoria_id == categoria_id).all()
    result = []
    for p in persone:
        count = db.query(Registro).filter(
            Registro.persona_id == p.id,
            Registro.categoria_id == categoria_id,
            Registro.data >= inizio_sett,
            Registro.data <= fine_sett,
            ~Registro.codice.in_(codici_assenza)
        ).count()
        result.append({
            "persona_id": p.id,
            "nome": p.nome,
            "cognome": p.cognome,
            "allenamenti": count
        })
    return result
