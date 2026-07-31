from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import extract
from sqlalchemy.dialects.postgresql import insert as pg_insert
from typing import Optional
from pydantic import BaseModel
from ..database import get_db
from ..models import PresenzaAllenatore, Utente, UtenteCategoria, Categoria
from .auth import get_current_user

router = APIRouter(prefix="/presenze-allenatori", tags=["presenze-allenatori"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

class PresenzaAllenatoreIn(BaseModel):
    utente_id: int
    data: str
    codice: Optional[str] = None

class PresenzaAllenatoreOut(BaseModel):
    id: int
    utente_id: int
    data: str
    codice: Optional[str] = None

    class Config:
        from_attributes = True

@router.get("/mese/{anno}/{mese}")
def get_mese(anno: int, mese: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user)
    query = db.query(PresenzaAllenatore).filter(
        extract("year", PresenzaAllenatore.data) == anno,
        extract("month", PresenzaAllenatore.data) == mese
    )
    if societa_id:
        query = query.filter(PresenzaAllenatore.societa_id == societa_id)
    return query.all()

@router.post("/", response_model=PresenzaAllenatoreOut)
def upsert_presenza(entry: PresenzaAllenatoreIn, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    data = entry.model_dump()
    data["societa_id"] = societa_id
    data.pop("id", None)
    stmt = pg_insert(PresenzaAllenatore).values(**data)
    stmt = stmt.on_conflict_do_update(
        index_elements=[PresenzaAllenatore.utente_id, PresenzaAllenatore.data],
        set_={
            "codice": stmt.excluded.codice,
            "societa_id": stmt.excluded.societa_id,
        }
    )
    db.execute(stmt)
    db.commit()
    r = db.query(PresenzaAllenatore).filter(
        PresenzaAllenatore.utente_id == entry.utente_id,
        PresenzaAllenatore.data == entry.data
    ).first()
    return r

@router.get("/mister")
def get_mister(db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user)
    query = db.query(Utente).filter(Utente.ruolo == "mister")
    if societa_id:
        query = query.filter(Utente.societa_id == societa_id)
    mister_list = query.order_by(Utente.cognome).all()

    result = []
    for m in mister_list:
        # Get training days from assigned categories (excluding portieri)
        cat_ids = db.query(UtenteCategoria.categoria_id).filter(
            UtenteCategoria.utente_id == m.id
        ).all()
        cat_ids = [c[0] for c in cat_ids]

        giorni_set = set()
        for cat_id in cat_ids:
            cat = db.query(Categoria).filter(
                Categoria.id == cat_id
            ).first()
            if cat and cat.giorni:
                for g in cat.giorni.split(","):
                    g = g.strip()
                    if g.isdigit():
                        giorni_set.add(int(g))

        result.append({
            "id": m.id,
            "nome": m.nome,
            "cognome": m.cognome,
            "cellulare": m.cellulare,
            "ruolo": m.ruolo,
            "societa_id": m.societa_id,
            "giorni": sorted(giorni_set)
        })

    return result
