from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import text, func
from pydantic import BaseModel
from typing import Optional
from app.models import Utente, Gruppo
from app.database import get_db
from app.routers.auth import get_current_user
from app.core.security import get_persona_staff
from app.core.deps import get_societa_filter, resolve_tenant_societa_id

router = APIRouter(prefix="/gruppi", tags=["gruppi"])

class GruppoOut(BaseModel):
    id: int
    nome: str
    categoria_id: Optional[int] = None
    societa_id: Optional[int] = None
    is_misto: bool = False
    class Config:
        from_attributes = True

class GruppoIn(BaseModel):
    nome: Optional[str] = None
    categoria_id: Optional[int] = None
    societa_id: Optional[int] = None
    is_misto: bool = False

class GruppoUpdate(BaseModel):
    nome: Optional[str] = None
    is_misto: Optional[bool] = None

@router.get("/", response_model=list[GruppoOut])
def get_gruppi(categoria_id: Optional[int] = None, societa_id: Optional[int] = Query(None), request: Request = None, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    sid = get_societa_filter(current_user, societa_id, request)
    query = db.query(Gruppo)
    if categoria_id:
        cat_row = db.execute(text("SELECT is_portieri, societa_id FROM categorie WHERE id = :id"), {"id": categoria_id}).first()
        if cat_row:
            if cat_row.societa_id:
                sid = cat_row.societa_id
            if cat_row.is_portieri == 1:
                query = query.filter(func.lower(Gruppo.nome) == "portieri")
            else:
                query = query.filter(Gruppo.categoria_id == categoria_id)
    if sid:
        query = query.filter(Gruppo.societa_id == sid)
    return query.order_by(Gruppo.nome).all()

@router.post("/", response_model=GruppoOut)
def create_gruppo(data: GruppoIn, request: Request = None, db: Session = Depends(get_db), current_user: Utente = Depends(get_persona_staff)):
    societa_id = resolve_tenant_societa_id(current_user, data.societa_id, request, categoria_id=data.categoria_id, db=db)
    # Auto-generate nome if not provided
    if not data.nome:
        existing = db.query(Gruppo).filter(
            Gruppo.categoria_id == data.categoria_id,
            Gruppo.societa_id == societa_id
        ).all()
        nums = []
        for g in existing:
            import re
            m = re.match(r'^(\d+)°Gruppo$', g.nome)
            if m:
                nums.append(int(m.group(1)))
        next_num = (max(nums) if nums else 0) + 1
        data.nome = f"{next_num}°Gruppo"
    existing = db.query(Gruppo).filter(
        Gruppo.nome == data.nome,
        Gruppo.categoria_id == data.categoria_id,
        Gruppo.societa_id == societa_id
    ).first()
    if existing:
        return existing
    gruppo = Gruppo(nome=data.nome, categoria_id=data.categoria_id, societa_id=societa_id, is_misto=data.is_misto)
    db.add(gruppo)
    db.commit()
    db.refresh(gruppo)
    return gruppo

@router.put("/{gruppo_id}", response_model=GruppoOut)
def update_gruppo(gruppo_id: int, data: GruppoUpdate, db: Session = Depends(get_db), current_user: Utente = Depends(get_persona_staff)):
    gruppo = db.query(Gruppo).filter(Gruppo.id == gruppo_id).first()
    if not gruppo:
        raise HTTPException(status_code=404, detail="Gruppo non trovato")
    societa_id = get_societa_filter(current_user)
    if societa_id and gruppo.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    if data.nome is not None:
        gruppo.nome = data.nome
    if data.is_misto is not None:
        gruppo.is_misto = data.is_misto
    db.commit()
    db.refresh(gruppo)
    return gruppo

@router.delete("/{gruppo_id}")
def delete_gruppo(gruppo_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_persona_staff)):
    gruppo = db.query(Gruppo).filter(Gruppo.id == gruppo_id).first()
    if not gruppo:
        return {"success": True}
    societa_id = get_societa_filter(current_user)
    if societa_id and gruppo.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    db.delete(gruppo)
    db.commit()
    return {"success": True}
