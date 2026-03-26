from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from .. import models, schemas
from ..database import get_db
from typing import Optional

router = APIRouter(prefix="/persone", tags=["persone"])

@router.get("/")
def get_persone(categoria_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = """
        SELECT p.id, p.nome, p.cognome, p.gruppo_id, p.categoria_id, g.nome as gruppo_nome
        FROM persone p
        LEFT JOIN gruppi g ON p.gruppo_id = g.id
    """
    if categoria_id:
        query += " WHERE p.categoria_id = :cid"
        rows = db.execute(text(query + " ORDER BY g.nome, p.cognome"), {"cid": categoria_id}).fetchall()
    else:
        rows = db.execute(text(query + " ORDER BY g.nome, p.cognome")).fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/")
def create_persona(p: schemas.PersonaCreate, db: Session = Depends(get_db)):
    persona = models.Persona(**p.dict())
    db.add(persona); db.commit(); db.refresh(persona)
    return persona

@router.put("/{persona_id}")
def update_persona(persona_id: int, p: schemas.PersonaCreate, db: Session = Depends(get_db)):
    persona = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
    persona.nome = p.nome; persona.cognome = p.cognome; persona.gruppo_id = p.gruppo_id
    db.commit(); db.refresh(persona)
    return persona

@router.delete("/{persona_id}")
def delete_persona(persona_id: int, db: Session = Depends(get_db)):
    db.query(models.Persona).filter(models.Persona.id == persona_id).delete()
    db.commit()
    return {"ok": True}
