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

#明文加密
def encrypt_field(value):
    if not value:
        return value
    # 使用 pgcrypto 的 AES 加密
    return text("SELECT encode(encrypt(:value::bytea, :key, 'aes'), 'hex')").bindparams(
        value=value, key=ENCRYPTION_KEY
    )

# 解密
def decrypt_field(value):
    if not value:
        return value
    # 检查是否已经加密（十六进制字符串）
    if isinstance(value, str) and len(value) == 48 and all(c in '0123456789abcdef' for c in value):
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
        SELECT p.id, p.nome, p.cognome, p.gruppo_id, p.categoria_id, g.nome as gruppo_nome,
               p.data_nascita, p.codice_fiscale, p.telefono, p.matricola,
               p.numero_maglia, p.scadenza_certificato
        FROM persone p
        LEFT JOIN gruppi g ON p.gruppo_id = g.id
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
    query += " ORDER BY g.nome, p.cognome"
    
    rows = db.execute(text(query), params).fetchall()
    
    # Decodifica i campi sensibili
    results = []
    for row in rows:
        r = dict(row._mapping)
        # Decodifica i campi crittografati (se presenti come hex)
        for field in ['codice_fiscale', 'telefono']:
            if r.get(field):
                try:
                    decrypted = db.execute(text(
                        "SELECT decrypt(decode(:value, 'hex'), :key, 'aes')::text"
                    ), {"value": r[field], "key": ENCRYPTION_KEY}).scalar()
                    r[field] = decrypted if decrypted else r[field]
                except Exception as e:
                    logger.warning(f"Could not decrypt {field}: {e}")
        results.append(r)
    
    return results

@router.post("/")
def create_persona(p: schemas.PersonaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    data = p.dict()
    data["societa_id"] = societa_id
    
    # Crittografa i campi sensibili prima di salvare
    if data.get("codice_fiscale"):
        encrypted = db.execute(text(
            "SELECT encode(encrypt(:value::bytea, :key, 'aes'), 'hex')"
        ), {"value": data["codice_fiscale"], "key": ENCRYPTION_KEY}).scalar()
        data["codice_fiscale"] = encrypted
    
    if data.get("telefono"):
        encrypted = db.execute(text(
            "SELECT encode(encrypt(:value::bytea, :key, 'aes'), 'hex')"
        ), {"value": data["telefono"], "key": ENCRYPTION_KEY}).scalar()
        data["telefono"] = encrypted
    
    persona = models.Persona(**data)
    db.add(persona); db.commit(); db.refresh(persona)
    return persona

@router.put("/{persona_id}")
def update_persona(persona_id: int, p: schemas.PersonaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    persona = db.query(models.Persona).filter(models.Persona.id == persona_id).first()
    societa_id = get_societa_filter(current_user)
    if societa_id and persona.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    data = p.dict()
    
    # Crittografa i campi sensibili prima di salvare
    if data.get("codice_fiscale"):
        encrypted = db.execute(text(
            "SELECT encode(encrypt(:value::bytea, :key, 'aes'), 'hex')"
        ), {"value": data["codice_fiscale"], "key": ENCRYPTION_KEY}).scalar()
        data["codice_fiscale"] = encrypted
    
    if data.get("telefono"):
        encrypted = db.execute(text(
            "SELECT encode(encrypt(:value::bytea, :key, 'aes'), 'hex')"
        ), {"value": data["telefono"], "key": ENCRYPTION_KEY}).scalar()
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
