from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import SessionLocal
from ..models import Valutazione, Persona, Categoria
from ..routers.auth import get_current_user, check_societa
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/valutazioni", tags=["valutazioni"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class ValutazioneCreate(BaseModel):
    persona_id: int
    categoria_id: int
    tecnica: Optional[int] = None
    velocita: Optional[int] = None
    resistenza: Optional[int] = None
    attitudine: Optional[int] = None
    posizione: Optional[int] = None
    gioco_di_testa: Optional[int] = None
    tiro: Optional[int] = None
    passaggio: Optional[int] = None
    dribbling: Optional[int] = None
    disciplina: Optional[int] = None
    note: Optional[str] = None

def check_categoria_societa(db, categoria_id, user):
    if user.is_super_admin:
        return
    res = db.execute(text("SELECT societa_id FROM categorie WHERE id = :id"), {"id": categoria_id})
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Categoria non trovata")
    check_societa(user, row.societa_id)

@router.get("/categoria/{categoria_id}")
def get_valutazioni_categoria(categoria_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    check_categoria_societa(db, categoria_id, user)
    valutazioni = db.query(Valutazione).filter(Valutazione.categoria_id == categoria_id).all()
    result = []
    for v in valutazioni:
        persona = db.query(Persona).filter(Persona.id == v.persona_id).first()
        result.append({
            "id": v.id,
            "persona_id": v.persona_id,
            "categoria_id": v.categoria_id,
            "cognome": persona.cognome if persona else "",
            "nome": persona.nome if persona else "",
            "tecnica": v.tecnica,
            "velocita": v.velocita,
            "resistenza": v.resistenza,
            "attitudine": v.attitudine,
            "posizione": v.posizione,
            "gioco_di_testa": v.gioco_di_testa,
            "tiro": v.tiro,
            "passaggio": v.passaggio,
            "dribbling": v.dribbling,
            "disciplina": v.disciplina,
            "note": v.note,
        })
    return result

@router.put("/{id}")
def update_valutazione(id: int, data: ValutazioneCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    v = db.query(Valutazione).filter(Valutazione.id == id).first()
    if not v:
        raise HTTPException(status_code=404, detail="Valutazione non trovata")
    check_categoria_societa(db, v.categoria_id, user)
    for field in ["tecnica", "velocita", "resistenza", "attitudine", "posizione", "gioco_di_testa", "tiro", "passaggio", "dribbling", "disciplina", "note"]:
        val = getattr(data, field, None)
        if val is not None:
            setattr(v, field, val)
    db.commit()
    return {"status": "ok"}

@router.post("/")
def create_valutazione(data: ValutazioneCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    check_categoria_societa(db, data.categoria_id, user)
    v = Valutazione(
        persona_id=data.persona_id,
        categoria_id=data.categoria_id,
        tecnica=data.tecnica,
        velocita=data.velocita,
        resistenza=data.resistenza,
        attitudine=data.attitudine,
        posizione=data.posizione,
        gioco_di_testa=data.gioco_di_testa,
        tiro=data.tiro,
        passaggio=data.passaggio,
        dribbling=data.dribbling,
        disciplina=data.disciplina,
        note=data.note,
    )
    db.add(v)
    db.commit()
    return {"id": v.id}
