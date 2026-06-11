import os
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from sqlalchemy import text
from .. import models, schemas
from ..database import get_db
from ..routers.auth import get_current_user, get_super_admin
from ..models import Utente
from ..rate_limit import limiter
from typing import Optional
import logging

logger = logging.getLogger(__name__)

ENCRYPTION_KEY = os.environ.get("ENCRYPTION_KEY")
if not ENCRYPTION_KEY:
    raise RuntimeError("ENCRYPTION_KEY environment variable is required")

PGCRYPTO_AVAILABLE = os.environ.get("PGCRYPTO_AVAILABLE", "false").lower() == "true"

def safe_encrypt(db: Session, value: str) -> str:
    """Safely encrypt a value using parameterized query."""
    if not value or not PGCRYPTO_AVAILABLE:
        return value
    try:
        result = db.execute(
            text("SELECT encode(encrypt(:value::bytea, :key, 'aes'), 'hex')"),
            {"value": value, "key": ENCRYPTION_KEY}
        ).scalar()
        return result
    except Exception as e:
        db.rollback()
        logger.error(f"Encryption failed: {e}")
        raise

def safe_decrypt(db: Session, value: str) -> str:
    """Safely decrypt a value using parameterized query."""
    if not value or not PGCRYPTO_AVAILABLE:
        return value
    if not isinstance(value, str) or len(value) < 32 or not all(c in '0123456789abcdef' for c in value):
        return value
    try:
        db.rollback()
        decrypted = db.execute(
            text("SELECT convert_from(decrypt(decode(:value, 'hex'), :key, 'aes'), 'UTF8')"),
            {"value": value, "key": ENCRYPTION_KEY}
        ).scalar()
        return decrypted if decrypted else value
    except Exception as e:
        db.rollback()
        logger.warning(f"Could not decrypt: {e}")
        return value

def safe_decrypt_with_key(db: Session, value: str, key: str) -> str:
    """Safely decrypt a value with a specific key using parameterized query."""
    if not value or not PGCRYPTO_AVAILABLE:
        return None
    if not isinstance(value, str) or len(value) < 32 or not all(c in '0123456789abcdef' for c in value):
        return None
    try:
        db.rollback()
        decrypted = db.execute(
            text("SELECT convert_from(decrypt(decode(:value, 'hex'), :key, 'aes'), 'UTF8')"),
            {"value": value, "key": key}
        ).scalar()
        return decrypted
    except Exception:
        db.rollback()
        return None

def safe_encrypt_with_key(db: Session, value: str, key: str) -> str:
    """Safely encrypt a value with a specific key using parameterized query."""
    if not value or not PGCRYPTO_AVAILABLE:
        return value
    try:
        result = db.execute(
            text("SELECT encode(encrypt(:value::bytea, :key, 'aes'), 'hex')"),
            {"value": value, "key": key}
        ).scalar()
        return result
    except Exception as e:
        db.rollback()
        logger.error(f"Encryption failed: {e}")
        raise

router = APIRouter(prefix="/persone", tags=["persone"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

SENSITIVE_FIELDS = frozenset(['codice_fiscale', 'tel_papa', 'tel_mamma', 'anamnesi',
                               'prof_papa', 'prof_mamma', 'nome_papa', 'nome_mamma', 'comune_nato',
                               'totale_da_pagare', 'rata_iscrizione', 'rata1', 'rata2', 'rata3', 'rata4', 'rata_saldo'])

@router.get("/")
@limiter.limit("60/minute")
def get_persone(request: Request, categoria_id: Optional[int] = None, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user)
    is_admin = current_user.is_admin or current_user.is_super_admin

    # Se la categoria è Portieri (is_portieri=1), restituisci tutti i portieri di tutte le categorie
    is_portieri = False
    if categoria_id:
        cat_row = db.execute(text("SELECT is_portieri FROM categorie WHERE id = :id"), {"id": categoria_id}).first()
        is_portieri = cat_row and cat_row.is_portieri == 1

    cat_label = ", CASE WHEN pc.anno IS NOT NULL THEN pc.nome || ' ' || pc.anno::text ELSE pc.nome END as categoria_nome" if is_portieri else ""

    if is_admin:
        query = f"""
            SELECT p.id, p.nome, p.cognome, p.gruppo_id, p.categoria_id,
                    p.data_nascita, p.codice_fiscale, p.matricola,
                    p.numero_maglia, p.scadenza_certificato, p.societa_id,
                    p.residenza, p.indirizzo, p.cittadinanza, p.tel_papa, p.tel_mamma,
                    p.email1, p.email2, p.prof_papa, p.prof_mamma, p.nome_papa, p.nome_mamma, p.comune_nato,
                    p.anamnesi, p.taglia, p.note,
                    p.totale_da_pagare, p.rata_iscrizione, p.rata1, p.rata2, p.rata3, p.rata4, p.rata_saldo
                    {cat_label}
            FROM persone p
            LEFT JOIN categorie pc ON p.categoria_id = pc.id
        """
    else:
        query = f"""
            SELECT p.id, p.nome, p.cognome, p.gruppo_id, p.categoria_id,
                    p.data_nascita, p.matricola,
                    p.numero_maglia, p.scadenza_certificato, p.societa_id,
                    p.residenza, p.indirizzo, p.cittadinanza,
                    p.email1, p.email2, p.taglia, p.note
                    {cat_label}
            FROM persone p
            LEFT JOIN categorie pc ON p.categoria_id = pc.id
        """

    conditions = []
    params = {}
    if is_portieri:
        # Tutti i giocatori nei gruppi "Portieri" di tutte le categorie attive
        conditions.append("""p.gruppo_id IN (
            SELECT g.id FROM gruppi g
            INNER JOIN categorie c ON g.categoria_id = c.id
            WHERE LOWER(g.nome) = 'portieri' AND c.is_archiviata = 0
        )""")
    elif categoria_id:
        conditions.append("p.categoria_id = :cid")
        params["cid"] = categoria_id
    if societa_id:
        # Usa COALESCE per includere persone con societa_id NULL ma categoria con societa_id valido
        conditions.append("COALESCE(p.societa_id, pc.societa_id) = :sid")
        params["sid"] = societa_id

    if conditions:
        query += " WHERE " + " AND ".join(conditions)
    query += " ORDER BY p.cognome"

    rows = db.execute(text(query), params).fetchall()

    results = []
    for row in rows:
        if is_admin:
            r = decrypt_row(db, row)
        else:
            r = dict(row._mapping) if hasattr(row, '_mapping') else dict(row)
        results.append(r)

    return results

@router.post("/")
def create_persona(p: schemas.PersonaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    data = p.dict()
    data["societa_id"] = societa_id
    
    if data.get("codice_fiscale"):
        data["codice_fiscale"] = safe_encrypt(db, data["codice_fiscale"])
    if data.get("tel_papa"):
        data["tel_papa"] = safe_encrypt(db, data["tel_papa"])
    if data.get("tel_mamma"):
        data["tel_mamma"] = safe_encrypt(db, data["tel_mamma"])

    persona = models.Persona(**data)
    db.add(persona); db.commit(); db.refresh(persona)
    return persona

@router.put("/{persona_id}")
def update_persona(persona_id: int, p: schemas.PersonaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    persona = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
    societa_id = get_societa_filter(current_user)
    if societa_id and persona.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    data = p.dict(exclude_none=True)

    if data.get("codice_fiscale"):
        data["codice_fiscale"] = safe_encrypt(db, data["codice_fiscale"])
    if data.get("tel_papa"):
        data["tel_papa"] = safe_encrypt(db, data["tel_papa"])
    if data.get("tel_mamma"):
        data["tel_mamma"] = safe_encrypt(db, data["tel_mamma"])

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

# --- Public endpoints (no authentication required) ---

def decrypt_row(db: Session, row) -> dict:
    r = dict(row._mapping) if hasattr(row, '_mapping') else dict(row)
    for field in ['codice_fiscale', 'tel_papa', 'tel_mamma']:
        r[field] = safe_decrypt(db, r.get(field))
    return r

@router.get("/public/{persona_id}")
@limiter.limit("5/minute")
def get_public_persona(request: Request, persona_id: int, db: Session = Depends(get_db)):
    query = """
        SELECT p.id, p.nome, p.cognome, p.gruppo_id, p.categoria_id,
                p.data_nascita, p.matricola,
                p.numero_maglia, p.scadenza_certificato,
                p.residenza, p.indirizzo, p.cittadinanza,
                p.email1, p.email2, p.taglia,
                p.note
        FROM persone p
        WHERE p.id = :id
    """
    row = db.execute(text(query), {"id": persona_id}).first()
    if not row:
        raise HTTPException(status_code=404, detail="Persona non trovata")
    result = dict(row._mapping) if hasattr(row, '_mapping') else dict(row)
    gruppo = db.execute(text("SELECT nome FROM gruppi WHERE id = :id"), {"id": result.get("gruppo_id")}).first()
    result["gruppo_nome"] = gruppo.nome if gruppo else None
    return result

@router.put("/public/{persona_id}")
@limiter.limit("5/minute")
def update_public_persona(request: Request, persona_id: int, p: schemas.PersonaCreate, db: Session = Depends(get_db)):
    persona = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona non trovata")
    allowed_fields = {"nome", "cognome", "residenza", "indirizzo", "cittadinanza", "email1", "email2", "tel_papa", "tel_mamma", "anamnesi", "taglia", "note"}
    data = {k: v for k, v in p.dict(exclude_none=True).items() if k in allowed_fields}
    if data.get("tel_papa"):
        data["tel_papa"] = safe_encrypt(db, data["tel_papa"])
    if data.get("tel_mamma"):
        data["tel_mamma"] = safe_encrypt(db, data["tel_mamma"])
    for key, value in data.items():
        setattr(persona, key, value)
    db.commit(); db.refresh(persona)
    return {"ok": True}

@router.post("/public/")
@limiter.limit("5/minute")
def create_public_persona(request: Request, p: schemas.PersonaCreate, db: Session = Depends(get_db)):
    allowed_fields = {"nome", "cognome", "categoria_id", "residenza", "indirizzo", "cittadinanza", "email1", "email2", "tel_papa", "tel_mamma", "anamnesi", "taglia", "note", "data_nascita", "matricola", "numero_maglia", "scadenza_certificato"}
    data = {k: v for k, v in p.dict(exclude_none=True).items() if k in allowed_fields}
    if not data.get("nome") or not data.get("cognome"):
        raise HTTPException(status_code=400, detail="Nome e cognome sono obbligatori")
    if not data.get("categoria_id"):
        raise HTTPException(status_code=400, detail="Categoria_id è richiesto")
    cat = db.execute(text("SELECT societa_id FROM categorie WHERE id = :id"), {"id": data["categoria_id"]}).first()
    if not cat:
        raise HTTPException(status_code=400, detail="Categoria non trovata")
    data["societa_id"] = cat.societa_id
    if data.get("tel_papa"):
        data["tel_papa"] = safe_encrypt(db, data["tel_papa"])
    if data.get("tel_mamma"):
        data["tel_mamma"] = safe_encrypt(db, data["tel_mamma"])
    persona = models.Persona(**data)
    db.add(persona); db.commit(); db.refresh(persona)
    return {"id": persona.id, "ok": True}

@router.put("/encryption-key")
def update_encryption_key(
    data: dict,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_super_admin),
    reencrypt: bool = False
):
    new_key = data.get("key")
    old_key = data.get("old_key", ENCRYPTION_KEY)
    if not new_key or not isinstance(new_key, str) or len(new_key) < 16:
        raise HTTPException(status_code=400, detail="Chiave non valida (min 16 caratteri)")
    
    if reencrypt:
        rows = db.execute(text("SELECT id, codice_fiscale, tel_papa, tel_mamma FROM persone")).fetchall()
        updated = 0
        for row in rows:
            persona_id = row.id
            old_cf = row.codice_fiscale
            old_papa = row.tel_papa
            old_mamma = row.tel_mamma

            decrypted_cf = safe_decrypt_with_key(db, old_cf, old_key)
            if not decrypted_cf:
                decrypted_cf = safe_decrypt_with_key(db, old_cf, ENCRYPTION_KEY)

            decrypted_papa = safe_decrypt_with_key(db, old_papa, old_key)
            if not decrypted_papa:
                decrypted_papa = safe_decrypt_with_key(db, old_papa, ENCRYPTION_KEY)

            decrypted_mamma = safe_decrypt_with_key(db, old_mamma, old_key)
            if not decrypted_mamma:
                decrypted_mamma = safe_decrypt_with_key(db, old_mamma, ENCRYPTION_KEY)

            if decrypted_cf or decrypted_papa or decrypted_mamma:
                new_cf = safe_encrypt_with_key(db, decrypted_cf, new_key) if decrypted_cf else None
                new_papa = safe_encrypt_with_key(db, decrypted_papa, new_key) if decrypted_papa else None
                new_mamma = safe_encrypt_with_key(db, decrypted_mamma, new_key) if decrypted_mamma else None

                db.execute(text(
                    "UPDATE persone SET codice_fiscale = :cf, tel_papa = :papa, tel_mamma = :mamma WHERE id = :id"
                ), {"cf": new_cf, "papa": new_papa, "mamma": new_mamma, "id": persona_id})
                updated += 1

        db.commit()
        os.environ["ENCRYPTION_KEY"] = new_key
        globals()["ENCRYPTION_KEY"] = new_key
        return {"ok": True, "message": f"Chiave aggiornata e {updated} record ricifrati"}

    os.environ["ENCRYPTION_KEY"] = new_key
    globals()["ENCRYPTION_KEY"] = new_key
    return {"ok": True, "message": "Chiave aggiornata"}
