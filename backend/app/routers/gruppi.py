from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from app.models import Utente, Gruppo
from app.routers.auth import get_current_user
from app.database import get_db

router = APIRouter(prefix="/gruppi", tags=["gruppi"])

class GruppoOut(BaseModel):
    id: int
    nome: str
    categoria_id: int
    class Config:
        from_attributes = True

class GruppoIn(BaseModel):
    nome: str
    categoria_id: int

@router.get("/", response_model=list[GruppoOut])
def get_gruppi(db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    return db.query(Gruppo).filter(Gruppo.categoria_id == current_user.categoria_id).order_by(Gruppo.nome).all()

@router.post("/", response_model=GruppoOut)
def create_gruppo(data: GruppoIn, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    existing = db.query(Gruppo).filter(
        Gruppo.nome == data.nome,
        Gruppo.categoria_id == data.categoria_id
    ).first()
    if existing:
        return existing
    gruppo = Gruppo(nome=data.nome, categoria_id=data.categoria_id)
    db.add(gruppo)
    db.commit()
    db.refresh(gruppo)
    return gruppo

@router.delete("/{gruppo_id}")
def delete_gruppo(gruppo_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    gruppo = db.query(Gruppo).filter(Gruppo.id == gruppo_id).first()
    if gruppo:
        db.delete(gruppo)
        db.commit()
    return {"success": True}