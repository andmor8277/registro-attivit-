import os
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from .. import models, schemas
from ..database import get_db
from ..routers.auth import get_current_user
from ..models import Utente
from typing import Optional
import logging

logger = logging.getLogger(__name__)

# Chiave di crittografia da env o default (cambiare in produzione!)
ENCRYPTION_KEY = os.environ.get("ENCRYPTION_KEY", "5DSqiSp+zs0pBlg7+vR46AYjJV70DMWnLRuZCUabd0c=")

PGCRYPTO_AVAILABLE = False

def encrypt_field(value):
    if not value:
        return value
    if PGCRYPTO_AVAILABLE:
        return text("SELECT encode(encrypt(:value::bytea, :key, 'aes'), 'hex')").bindparams(
            value=value, key=ENCRYPTION_KEY
        )
    return value

def decrypt_field(value):
    if not value:
        return value
    if PGCRYPTO_AVAILABLE and isinstance(value, str) and len(value) == 48 and all(c in '0123456789abcdef' for c in value):
        return text("SELECT decrypt(decode(:value, 'hex'), :key, 'aes')::text").bindparams(
            value=value, key=ENCRYPTION_KEY
        )
    return value

router = APIRouter(prefix="/persone", tags=["persone"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

@router.get("/")
def get_persone(categoria_id: Optional[int] = None, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user)
    
    query = """
        SELECT p.id, p.nome, p.cognome, p.gruppo_id, p.categoria_id,
               p.data_nascita, p.codice_fiscale, p.telefono, p.matricola,
               p.numero_maglia, p.scadenza_certificato, p.societa_id,
               p.totale_da_pagare, p.rata_iscrizione, p.rata1, p.rata2, p.rata3, p.rata4, p.rata_saldo
        FROM persone p
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
    query += " ORDER BY p.cognome"
    
    rows = db.execute(text(query), params).fetchall()
    
    # Decodifica i campi sensibili
    results = []
    for row in rows:
        r = dict(row._mapping)
        # Decodifica i campi crittografati (solo se pgcrypto disponibile)
        if PGCRYPTO_AVAILABLE:
            for field in ['codice_fiscale', 'telefono']:
                val = r.get(field)
                if val and isinstance(val, str) and len(val) >= 32 and all(c in '0123456789abcdef' for c in val):
                    try:
                        db.rollback()
                        decrypted = db.execute(text(
                            f"SELECT convert-from(decrypt(decode('{val}', 'hex'), '{ENCRYPTION_KEY}', 'aes'), 'UTF8')"
                        )).scalar()
                        r[field] = decrypted if decrypted else val
                    except Exception as e:
                        db.rollback()
                        logger.warning(f"Could not decrypt {field}: {e}")
        results.append(r)
    
    return results

@router.post("/")
def create_persona(p: schemas.PersonaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    data = p.dict()
    data["societa_id"] = societa_id
    
    # Crittografa i campi sensibili prima di salvare
    if PGCRYPTO_AVAILABLE:
        if data.get("codice_fiscale"):
            encrypted = db.execute(text(
                f"SELECT encode(encrypt('{data['codice_fiscale']}'::bytea, '{ENCRYPTION_KEY}', 'aes'), 'hex')"
            )).scalar()
            data["codice_fiscale"] = encrypted
        
        if data.get("telefono"):
            encrypted = db.execute(text(
                f"SELECT encode(encrypt('{data['telefono']}'::bytea, '{ENCRYPTION_KEY}', 'aes'), 'hex')"
            )).scalar()
            data["telefono"] = encrypted
    else:
        if data.get("codice_fiscale"):
            data["codice_fiscale"] = data["codice_fiscale"]
        if data.get("telefono"):
            data["telefono"] = data["telefono"]
    
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

    # Crittografa i campi sensibili prima di salvare
    if PGCRYPTO_AVAILABLE:
        if data.get("codice_fiscale"):
            encrypted = db.execute(text(
                f"SELECT encode(encrypt('{data['codice_fiscale']}'::bytea, '{ENCRYPTION_KEY}', 'aes'), 'hex')"
            )).scalar()
            data["codice_fiscale"] = encrypted

        if data.get("telefono"):
            encrypted = db.execute(text(
                f"SELECT encode(encrypt('{data['telefono']}'::bytea, '{ENCRYPTION_KEY}', 'aes'), 'hex')"
            )).scalar()
            data["telefono"] = encrypted

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

def decrypt_row(db: Session, row: dict) -> dict:
    r = dict(row._mapping) if hasattr(row, '_mapping') else dict(row)
    if PGCRYPTO_AVAILABLE:
        for field in ['codice_fiscale', 'telefono']:
            val = r.get(field)
            if val and isinstance(val, str) and len(val) >= 32 and all(c in '0123456789abcdef' for c in val):
                try:
                    db.rollback()
                    decrypted = db.execute(text(
                        f"SELECT convert_from(decrypt(decode('{val}', 'hex'), '{ENCRYPTION_KEY}', 'aes'), 'UTF8')"
                    )).scalar()
                    r[field] = decrypted if decrypted else val
                except Exception as e:
                    db.rollback()
                    logger.warning(f"Could not decrypt {field}: {e}")
    return r

@router.get("/public/{persona_id}")
def get_public_persona(persona_id: int, db: Session = Depends(get_db)):
    query = """
        SELECT p.id, p.nome, p.cognome, p.gruppo_id, p.categoria_id,
               p.data_nascita, p.codice_fiscale, p.telefono, p.matricola,
               p.numero_maglia, p.scadenza_certificato, p.societa_id,
               p.residenza, p.indirizzo, p.cittadinanza, p.tel_papa,
               p.tel_mamma, p.email1, p.email2, p.anamnesi, p.taglia,
               p.note, p.totale_da_pagare, p.rata_iscrizione, p.rata1, p.rata2, p.rata3, p.rata4, p.rata_saldo
        FROM persone p
        WHERE p.id = :id
    """
    row = db.execute(text(query), {"id": persona_id}).first()
    if not row:
        raise HTTPException(status_code=404, detail="Persona non trovata")
    result = decrypt_row(db, row)
    gruppo = db.execute(text("SELECT nome FROM gruppi WHERE id = :id"), {"id": result.get("gruppo_id")}).first()
    result["gruppo_nome"] = gruppo.nome if gruppo else None
    return result

@router.put("/public/{persona_id}")
def update_public_persona(persona_id: int, p: schemas.PersonaCreate, db: Session = Depends(get_db)):
    persona = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona non trovata")
    data = p.dict(exclude_none=True)
    if PGCRYPTO_AVAILABLE:
        if data.get("codice_fiscale"):
            encrypted = db.execute(text(
                f"SELECT encode(encrypt('{data['codice_fiscale']}'::bytea, '{ENCRYPTION_KEY}', 'aes'), 'hex')"
            )).scalar()
            data["codice_fiscale"] = encrypted
        if data.get("telefono"):
            encrypted = db.execute(text(
                f"SELECT encode(encrypt('{data['telefono']}'::bytea, '{ENCRYPTION_KEY}', 'aes'), 'hex')"
            )).scalar()
            data["telefono"] = encrypted
    for key, value in data.items():
        setattr(persona, key, value)
    db.commit(); db.refresh(persona)
    return {"ok": True}

@router.post("/public/")
def create_public_persona(p: schemas.PersonaCreate, db: Session = Depends(get_db)):
    data = p.dict(exclude_none=True)
    if not data.get("nome") or not data.get("cognome"):
        raise HTTPException(status_code=400, detail="Nome e cognome sono obbligatori")
    if data.get("categoria_id"):
        cat = db.execute(text("SELECT societa_id FROM categorie WHERE id = :id"), {"id": data["categoria_id"]}).first()
        if cat:
            data["societa_id"] = cat.societa_id
        else:
            raise HTTPException(status_code=400, detail="Categoria non trovata")
    else:
        raise HTTPException(status_code=400, detail="Categoria_id è richiesto")
    if PGCRYPTO_AVAILABLE:
        if data.get("codice_fiscale"):
            encrypted = db.execute(text(
                f"SELECT encode(encrypt('{data['codice_fiscale']}'::bytea, '{ENCRYPTION_KEY}', 'aes'), 'hex')"
            )).scalar()
            data["codice_fiscale"] = encrypted
        if data.get("telefono"):
            encrypted = db.execute(text(
                f"SELECT encode(encrypt('{data['telefono']}'::bytea, '{ENCRYPTION_KEY}', 'aes'), 'hex')"
            )).scalar()
            data["telefono"] = encrypted
    persona = models.Persona(**data)
    db.add(persona); db.commit(); db.refresh(persona)
    return {"id": persona.id, "ok": True}

@router.put("/encryption-key")
def update_encryption_key(
    data: dict,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user),
    reencrypt: bool = False
):
    if not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Solo super admin può modificare la chiave")
    
    new_key = data.get("key")
    old_key = data.get("old_key", ENCRYPTION_KEY)
    if not new_key:
        raise HTTPException(status_code=400, detail="Chiave non fornita")
    
    if reencrypt:
        # Re-encrypt all sensitive data with the new key
        rows = db.execute(text("SELECT id, codice_fiscale, telefono FROM persone")).fetchall()
        updated = 0
        for row in rows:
            persona_id = row.id
            old_cf = row.codice_fiscale
            old_tel = row.telefono
            
            decrypted_cf = None
            decrypted_tel = None
            
            # Try to decrypt with old key first
            if old_cf and len(old_cf) >= 32:
                try:
                    db.rollback()
                    decrypted_cf = db.execute(text(
                        f"SELECT convert_from(decrypt(decode('{old_cf}', 'hex'), '{old_key}', 'aes'), 'UTF8')"
                    )).scalar()
                except:
                    pass
            
            if old_tel and len(old_tel) >= 32:
                try:
                    db.rollback()
                    decrypted_tel = db.execute(text(
                        f"SELECT convert_from(decrypt(decode('{old_tel}', 'hex'), '{old_key}', 'aes'), 'UTF8')"
                    )).scalar()
                except:
                    pass
            
            # If still encrypted with current key, also try that
            if not decrypted_cf and old_cf and len(old_cf) >= 32:
                try:
                    db.rollback()
                    decrypted_cf = db.execute(text(
                        f"SELECT convert_from(decrypt(decode('{old_cf}', 'hex'), '{ENCRYPTION_KEY}', 'aes'), 'UTF8')"
                    )).scalar()
                except:
                    pass
            
            if not decrypted_tel and old_tel and len(old_tel) >= 32:
                try:
                    db.rollback()
                    decrypted_tel = db.execute(text(
                        f"SELECT convert_from(decrypt(decode('{old_tel}', 'hex'), '{ENCRYPTION_KEY}', 'aes'), 'UTF8')"
                    )).scalar()
                except:
                    pass
            
            # Now re-encrypt with new key and save
            if decrypted_cf or decrypted_tel:
                new_cf = None
                new_tel = None
                
                if decrypted_cf:
                    new_cf = db.execute(text(
                        f"SELECT encode(encrypt('{decrypted_cf}'::bytea, '{new_key}', 'aes'), 'hex')"
                    )).scalar()
                
                if decrypted_tel:
                    new_tel = db.execute(text(
                        f"SELECT encode(encrypt('{decrypted_tel}'::bytea, '{new_key}', 'aes'), 'hex')"
                    )).scalar()
                
                db.execute(text(
                    "UPDATE persone SET codice_fiscale = :cf, telefono = :tel WHERE id = :id"
                ).bindparams(cf=new_cf, tel=new_tel, id=persona_id))
                updated += 1
        
        db.commit()
        
        # Update the key
        os.environ["ENCRYPTION_KEY"] = new_key
        globals()["ENCRYPTION_KEY"] = new_key
        
        return {"ok": True, "message": f"Chiave aggiornata e {updated} record ricifrati"}
    
    # Just update the key without re-encrypting
    os.environ["ENCRYPTION_KEY"] = new_key
    globals()["ENCRYPTION_KEY"] = new_key
    
    return {"ok": True, "message": "Chiave aggiornata"}
