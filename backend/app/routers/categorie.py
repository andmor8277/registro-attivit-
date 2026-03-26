from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from .. import models
from ..database import get_db
from ..routers.auth import get_current_user, get_admin
from ..models import Utente, UtenteCategoria
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/categorie", tags=["categorie"])

class CategoriaCreate(BaseModel):
    nome: str
    anno: int
    giorni: Optional[str] = None

@router.get("/")
def get_categorie(db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    tutte = db.query(models.Categoria).order_by(models.Categoria.anno.desc()).all()
    if current_user.is_admin:
        return tutte
    assegnate = db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == current_user.id).all()
    ids = {r.categoria_id for r in assegnate}
    return [c for c in tutte if c.id in ids]

@router.post("/")
def create_categoria(c: CategoriaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    cat = models.Categoria(**c.dict())
    db.add(cat)
    db.commit()
    db.refresh(cat)
    # assegna automaticamente la categoria all'utente che la crea
    if not current_user.is_admin:
        db.add(UtenteCategoria(utente_id=current_user.id, categoria_id=cat.id))
        db.commit()
    return cat

@router.put("/{categoria_id}")
def update_categoria(categoria_id: int, c: CategoriaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    cat = db.query(models.Categoria).filter(models.Categoria.id == categoria_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    cat.nome = c.nome; cat.anno = c.anno; cat.giorni = c.giorni
    db.commit(); db.refresh(cat)
    return cat

@router.delete("/{categoria_id}")
def delete_categoria(categoria_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    db.query(models.Registro).filter(models.Registro.categoria_id == categoria_id).delete()
    db.query(models.Persona).filter(models.Persona.categoria_id == categoria_id).delete()
    db.query(UtenteCategoria).filter(UtenteCategoria.categoria_id == categoria_id).delete()
    db.query(models.Categoria).filter(models.Categoria.id == categoria_id).delete()
    db.commit()
    return {"ok": True}
