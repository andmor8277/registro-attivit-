from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text, func
from pydantic import BaseModel
from typing import Optional
from app.models import Utente, Gruppo
from app.database import get_db
from app.routers.auth import get_current_user

router = APIRouter(prefix="/gruppi", tags=["gruppi"])

class GruppoOut(BaseModel):
    id: int
    nome: str
    categoria_id: Optional[int] = None
    societa_id: Optional[int] = None
    class Config:
        from_attributes = True

class GruppoIn(BaseModel):
    nome: str
    categoria_id: Optional[int] = None

class GruppoUpdate(BaseModel):
    nome: str

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

@router.get("/", response_model=list[GruppoOut])
def get_gruppi(categoria_id: Optional[int] = None, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user)
    query = db.query(Gruppo)
    if societa_id:
        query = query.filter(Gruppo.societa_id == societa_id)
    if categoria_id:
        cat_row = db.execute(text("SELECT is_portieri FROM categorie WHERE id = :id"), {"id": categoria_id}).first()
        if cat_row and cat_row.is_portieri == 1:
            query = query.filter(func.lower(Gruppo.nome) == "portieri")
        else:
            query = query.filter(Gruppo.categoria_id == categoria_id)
    return query.order_by(Gruppo.nome).all()

@router.post("/", response_model=GruppoOut)
def create_gruppo(data: GruppoIn, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    existing = db.query(Gruppo).filter(
        Gruppo.nome == data.nome,
        Gruppo.categoria_id == data.categoria_id,
        Gruppo.societa_id == societa_id
    ).first()
    if existing:
        return existing
    gruppo = Gruppo(nome=data.nome, categoria_id=data.categoria_id, societa_id=societa_id)
    db.add(gruppo)
    db.commit()
    db.refresh(gruppo)
    return gruppo

@router.put("/{gruppo_id}", response_model=GruppoOut)
def update_gruppo(gruppo_id: int, data: GruppoUpdate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    gruppo = db.query(Gruppo).filter(Gruppo.id == gruppo_id).first()
    if not gruppo:
        raise HTTPException(status_code=404, detail="Gruppo non trovato")
    societa_id = get_societa_filter(current_user)
    if societa_id and gruppo.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    gruppo.nome = data.nome
    db.commit()
    db.refresh(gruppo)
    return gruppo

@router.delete("/{gruppo_id}")
def delete_gruppo(gruppo_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    gruppo = db.query(Gruppo).filter(Gruppo.id == gruppo_id).first()
    if not gruppo:
        return {"success": True}
    societa_id = get_societa_filter(current_user)
    if societa_id and gruppo.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    db.delete(gruppo)
    db.commit()
    return {"success": True}
