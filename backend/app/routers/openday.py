from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime
from .. import models, schemas
from ..database import get_db
from ..routers.auth import get_current_user
from ..models import Utente
from typing import Optional

router = APIRouter()

def get_societa_filter(user: Utente):
    if user.is_super_admin:
        return None
    return user.societa_id

@router.get("/")
def get_openday(current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    query = """
        SELECT o.id, o.nome, o.cognome, o.data_nascita, o.iscritto, o.persona_id, o.creato_il,
               o.date_prova, o.nulla_osta, o.certificato_medico, o.scadenza_certificato,
               o.tel_papa, o.tel_mamma, o.email_papa, o.email_mamma,
               pc.anno as categoria_anno, pc.nome as categoria_nome, pc.id as categoria_id
        FROM openday o
        LEFT JOIN persone p ON o.persona_id = p.id
        LEFT JOIN categorie pc ON p.categoria_id = pc.id
        WHERE o.societa_id = :sid
        ORDER BY o.iscritto DESC, o.cognome, o.nome
    """
    rows = db.execute(text(query), {"sid": societa_id}).fetchall()
    result = []
    for r in rows:
        d = dict(r._mapping)
        d['date_prova'] = d['date_prova'] if d['date_prova'] else []
        result.append(d)
    return result

@router.post("/")
def create_openday(entry: dict, current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    o = models.Openday(
        societa_id=societa_id,
        nome=entry["nome"],
        cognome=entry["cognome"],
        data_nascita=entry["data_nascita"],
        date_prova=entry.get("date_prova", []),
        nulla_osta=entry.get("nulla_osta", False),
        certificato_medico=entry.get("certificato_medico", False),
        scadenza_certificato=entry.get("scadenza_certificato"),
        tel_papa=entry.get("tel_papa"),
        tel_mamma=entry.get("tel_mamma"),
        email_papa=entry.get("email_papa"),
        email_mamma=entry.get("email_mamma"),
        creato_il=datetime.now()
    )
    db.add(o)
    db.commit()
    db.refresh(o)
    return {
        "id": o.id, "nome": o.nome, "cognome": o.cognome,
        "data_nascita": str(o.data_nascita), "iscritto": False, "persona_id": None,
        "date_prova": o.date_prova or [], "nulla_osta": o.nulla_osta,
        "certificato_medico": o.certificato_medico, "scadenza_certificato": str(o.scadenza_certificato) if o.scadenza_certificato else None,
        "tel_papa": o.tel_papa, "tel_mamma": o.tel_mamma,
        "email_papa": o.email_papa, "email_mamma": o.email_mamma
    }

@router.put("/{entry_id}")
def update_openday(entry_id: int, entry: dict, current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    o = db.query(models.Openday).filter(models.Openday.id == entry_id).first()
    if not o:
        raise HTTPException(status_code=404, detail="Non trovato")
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    if o.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    updatable = ["nome", "cognome", "data_nascita", "date_prova", "nulla_osta",
                 "certificato_medico", "scadenza_certificato", "tel_papa", "tel_mamma",
                 "email_papa", "email_mamma"]
    for field in updatable:
        if field in entry:
            setattr(o, field, entry[field])
    db.commit()
    db.refresh(o)
    return {
        "id": o.id, "nome": o.nome, "cognome": o.cognome,
        "data_nascita": str(o.data_nascita), "iscritto": o.iscritto, "persona_id": o.persona_id,
        "date_prova": o.date_prova or [], "nulla_osta": o.nulla_osta,
        "certificato_medico": o.certificato_medico, "scadenza_certificato": str(o.scadenza_certificato) if o.scadenza_certificato else None,
        "tel_papa": o.tel_papa, "tel_mamma": o.tel_mamma,
        "email_papa": o.email_papa, "email_mamma": o.email_mamma
    }

@router.delete("/{entry_id}")
def delete_openday(entry_id: int, current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    o = db.query(models.Openday).filter(models.Openday.id == entry_id).first()
    if not o:
        raise HTTPException(status_code=404, detail="Non trovato")
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    if o.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    persona_id = o.persona_id
    db.delete(o)
    db.commit()
    if persona_id:
        p = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
        if p:
            db.delete(p)
            db.commit()
    return {"ok": True}

@router.post("/{entry_id}/iscrivi")
def iscrivi_openday(entry_id: int, current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    o = db.query(models.Openday).filter(models.Openday.id == entry_id).first()
    if not o:
        raise HTTPException(status_code=404, detail="Non trovato")
    if o.iscritto:
        return {"ok": True, "persona_id": o.persona_id}

    anno_nascita = o.data_nascita.year
    cat_query = """
        SELECT id, anno FROM categorie
        WHERE societa_id = :sid AND anno = :anno AND is_archiviata = 0
        ORDER BY stagione DESC LIMIT 1
    """
    cat = db.execute(text(cat_query), {"sid": o.societa_id, "anno": anno_nascita}).first()
    if not cat:
        raise HTTPException(status_code=400, detail=f"Nessuna categoria attiva per l'anno {anno_nascita}")

    from ..routers.persone import safe_encrypt
    p = models.Persona(
        societa_id=o.societa_id,
        nome=o.nome,
        cognome=o.cognome,
        data_nascita=o.data_nascita,
        categoria_id=cat.id
    )
    db.add(p)
    db.commit()
    db.refresh(p)

    o.iscritto = True
    o.persona_id = p.id
    db.commit()

    return {"ok": True, "persona_id": p.id, "categoria_id": cat.id, "categoria_anno": cat.anno}

@router.post("/{entry_id}/disiscrivi")
def disiscrivi_openday(entry_id: int, current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    o = db.query(models.Openday).filter(models.Openday.id == entry_id).first()
    if not o:
        raise HTTPException(status_code=404, detail="Non trovato")
    if not o.iscritto:
        return {"ok": True, "persona_id": o.persona_id}

    persona_id = o.persona_id
    if persona_id:
        p = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
        if p:
            p.categoria_id = None

    o.iscritto = False
    o.persona_id = None
    db.commit()

    return {"ok": True}
