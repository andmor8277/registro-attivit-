from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from .. import models, schemas
from ..database import get_db
from ..routers.auth import get_current_user
from ..models import Utente
from typing import Optional

router = APIRouter(prefix="/persone", tags=["persone"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

@router.get("/")
def get_persone(categoria_id: Optional[int] = None, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user)
    
    query = """
        SELECT p.id, p.nome, p.cognome, p.gruppo_id, p.categoria_id, g.nome as gruppo_nome,
               p.data_nascita, p.codice_fiscale, p.telefono, p.matricola,
               p.numero_maglia, p.scadenza_certificato
        FROM persone p
        LEFT JOIN gruppi g ON p.gruppo_id = g.id
    """
    
    conditions = []
    params = {}
    if categoria_id:
        conditions.append("p.categoria_id = :cid")
        params["cid"] = categoria_id
    if societa_id:
        conditions.append("p.societa_id = :sid")
        params["sid"] = societa_id
    
    if conditions:
        query += " WHERE " + " AND ".join(conditions)
    query += " ORDER BY g.nome, p.cognome"
    
    rows = db.execute(text(query), params).fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/")
def create_persona(p: schemas.PersonaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    data = p.dict()
    data["societa_id"] = societa_id
    persona = models.Persona(**data)
    db.add(persona); db.commit(); db.refresh(persona)
    return persona

@router.put("/{persona_id}")
def update_persona(persona_id: int, p: schemas.PersonaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    persona = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
    societa_id = get_societa_filter(current_user)
    if societa_id and persona.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    data = p.dict()
    for key, value in data.items():
        setattr(persona, key, value)
    db.commit(); db.refresh(persona)
    return persona

@router.delete("/{persona_id}")
def delete_persona(persona_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    persona = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
    societa_id = get_societa_filter(current_user)
    if societa_id and persona.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    db.delete(persona)
    db.commit()
    return {"ok": True}
