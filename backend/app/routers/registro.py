from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from .. import models, schemas
from ..database import get_db
from ..routers.auth import get_current_user
from ..models import Utente
from typing import Optional

router = APIRouter(prefix="/registro", tags=["registro"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

@router.get("/mese/{categoria_id}/{anno}/{mese}")
def get_mese(categoria_id: int, anno: int, mese: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import extract
    societa_id = get_societa_filter(current_user)
    query = db.query(models.Registro).filter(
        models.Registro.categoria_id == categoria_id,
        extract("year", models.Registro.data) == anno,
        extract("month", models.Registro.data) == mese
    )
    if societa_id:
        query = query.filter(models.Registro.societa_id == societa_id)
    records = query.all()

    # Se non è la categoria Portieri, mergia anche le presenze dalla categoria Portieri per i portieri di questa categoria
    cat_row = db.execute(text("SELECT is_portieri FROM categorie WHERE id = :id"), {"id": categoria_id}).first()
    if cat_row and cat_row.is_portieri != 1:
        sid_param = {"sid": societa_id} if societa_id else {}
        portieri_cat = db.execute(text(
            "SELECT id FROM categorie WHERE is_portieri = 1 AND is_archiviata = 0" + (" AND societa_id = :sid" if societa_id else "")
        ), sid_param).first()

        if portieri_cat:
            home_keys = {(r.persona_id, str(r.data)) for r in records}
            portieri_rows = db.execute(text("""
                SELECT r.id, r.persona_id, r.data, r.codice, r.categoria_id, r.societa_id
                FROM registro r
                WHERE r.categoria_id = :pid
                AND r.persona_id IN (
                    SELECT p.id FROM persone p
                    WHERE p.categoria_id = :cid
                    AND p.gruppo_id IN (
                        SELECT g.id FROM gruppi g WHERE LOWER(g.nome) = 'portieri'
                    )
                )
                AND EXTRACT(YEAR FROM r.data) = :anno
                AND EXTRACT(MONTH FROM r.data) = :mese
            """), {"pid": portieri_cat.id, "cid": categoria_id, "anno": anno, "mese": mese}).fetchall()

            for pr in portieri_rows:
                key = (pr.persona_id, str(pr.data))
                if key not in home_keys:
                    from types import SimpleNamespace
                    records.append(SimpleNamespace(
                        id=pr.id, persona_id=pr.persona_id, data=pr.data,
                        codice=pr.codice, categoria_id=pr.categoria_id, societa_id=pr.societa_id,
                        is_portieri_readthrough=True
                    ))

    result = []
    for r in records:
        if hasattr(r, '__dict__'):
            d = r.__dict__.copy()
            d['is_portieri_readthrough'] = d.get('is_portieri_readthrough', False)
            if isinstance(d.get('data'), str):
                d['data'] = d['data'][:10]
            result.append(d)
        else:
            d = {
                'id': r.id, 'persona_id': r.persona_id, 'data': str(r.data)[:10],
                'codice': r.codice, 'categoria_id': r.categoria_id, 'societa_id': r.societa_id,
                'is_portieri_readthrough': False
            }
            result.append(d)
    return result

@router.post("/", response_model=schemas.RegistroOut)
def upsert_registro(entry: schemas.RegistroEntry, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id

    # Se la categoria corrente NON è Portieri ma la persona è un portiere, reindirizza alla categoria Portieri
    target_categoria_id = entry.categoria_id
    if target_categoria_id:
        cat_row = db.execute(text("SELECT is_portieri FROM categorie WHERE id = :id"), {"id": target_categoria_id}).first()
        if cat_row and cat_row.is_portieri != 1:
            persona = db.execute(text("SELECT gruppo_id FROM persone WHERE id = :pid"), {"pid": entry.persona_id}).first()
            if persona and persona.gruppo_id:
                gruppo_row = db.execute(text("SELECT nome FROM gruppi WHERE id = :gid"), {"gid": persona.gruppo_id}).first()
                if gruppo_row and gruppo_row.nome.lower() == "portieri":
                    portieri_cat = db.execute(text(
                        "SELECT id FROM categorie WHERE is_portieri = 1 AND is_archiviata = 0" + (" AND societa_id = :sid" if societa_id else "")
                    ), {"sid": societa_id} if societa_id else {}).first()
                    if portieri_cat:
                        target_categoria_id = portieri_cat.id

    existing = db.query(models.Registro).filter(
        models.Registro.persona_id == entry.persona_id,
        models.Registro.data == entry.data,
        models.Registro.categoria_id == target_categoria_id
    ).first()
    if existing:
        existing.codice = entry.codice
        if societa_id:
            existing.societa_id = societa_id
        db.commit(); db.refresh(existing)
        return existing
    data = entry.model_dump()
    data["societa_id"] = societa_id
    data["categoria_id"] = target_categoria_id
    r = models.Registro(**data)
    db.add(r); db.commit(); db.refresh(r)
    return r
