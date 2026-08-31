from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional, List
from app.models import Utente, ListaTorneo, ListaTorneoGiocatore
from app.database import get_db
from app.routers.auth import get_current_user

router = APIRouter(prefix="/liste-torneo", tags=["liste-torneo"])

class ListaTorneoOut(BaseModel):
    id: int
    nome: str
    categoria_id: int
    societa_id: int
    class Config:
        from_attributes = True

class ListaTorneoIn(BaseModel):
    nome: str
    categoria_id: int

class GiocatoreListaOut(BaseModel):
    id: int
    persona_id: int
    nome: str
    cognome: str
    ordine: int
    class Config:
        from_attributes = True

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

@router.get("/", response_model=list[ListaTorneoOut])
def get_liste_torneo(categoria_id: Optional[int] = None, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user)
    query = db.query(ListaTorneo).filter(ListaTorneo.societa_id == societa_id if societa_id else True)
    if categoria_id:
        query = query.filter(ListaTorneo.categoria_id == categoria_id)
    return query.order_by(ListaTorneo.creato_il.desc()).all()

@router.post("/", response_model=ListaTorneoOut)
def create_lista_torneo(data: ListaTorneoIn, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id
    lista = ListaTorneo(nome=data.nome, categoria_id=data.categoria_id, societa_id=societa_id, creato_il=text("NOW()"))
    db.add(lista)
    db.commit()
    db.refresh(lista)
    return lista

@router.get("/{lista_id}/giocatori")
def get_giocatori_lista(lista_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    lista = db.query(ListaTorneo).filter(ListaTorneo.id == lista_id).first()
    if not lista:
        raise HTTPException(status_code=404, detail="Lista non trovata")
    societa_id = get_societa_filter(current_user)
    if societa_id and lista.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    result = db.execute(text("""
        SELECT p.id as persona_id, p.nome, p.cognome, p.data_nascita, p.sesso,
               p.comune_nato, p.residenza, p.indirizzo, p.codice_fiscale,
               p.matricola, p.numero_maglia, p.scadenza_certificato,
               p.tel_papa, p.tel_mamma, p.email1,
               g.nome as gruppo_nome, g.is_misto as gruppo_is_misto,
               lg.id, lg.ordine
        FROM liste_torneo_giocatori lg
        JOIN persone p ON p.id = lg.persona_id
        LEFT JOIN gruppi g ON g.id = p.gruppo_id
        WHERE lg.lista_id = :lid
        ORDER BY lg.ordine, p.cognome
    """), {"lid": lista_id}).fetchall()
    return [{
        "id": r.id, "persona_id": r.persona_id,
        "nome": r.nome, "cognome": r.cognome,
        "data_nascita": str(r.data_nascita) if r.data_nascita else None,
        "sesso": r.sesso,
        "comune_nato": r.comune_nato,
        "residenza": r.residenza,
        "indirizzo": r.indirizzo,
        "codice_fiscale": r.codice_fiscale,
        "matricola": r.matricola,
        "numero_maglia": r.numero_maglia,
        "scadenza_certificato": str(r.scadenza_certificato) if r.scadenza_certificato else None,
        "tel_papa": r.tel_papa,
        "tel_mamma": r.tel_mamma,
        "email1": r.email1,
        "gruppo_nome": r.gruppo_nome,
        "gruppo_is_misto": r.gruppo_is_misto,
        "ordine": r.ordine
    } for r in result]

@router.post("/{lista_id}/giocatori")
def add_giocatore_lista(lista_id: int, persona_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    lista = db.query(ListaTorneo).filter(ListaTorneo.id == lista_id).first()
    if not lista:
        raise HTTPException(status_code=404, detail="Lista non trovata")
    societa_id = get_societa_filter(current_user)
    if societa_id and lista.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    existing = db.query(ListaTorneoGiocatore).filter(
        ListaTorneoGiocatore.lista_id == lista_id,
        ListaTorneoGiocatore.persona_id == persona_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Giocatore già nella lista")
    max_ordine = db.execute(text("SELECT COALESCE(MAX(ordine), -1) FROM liste_torneo_giocatori WHERE lista_id = :lid"), {"lid": lista_id}).scalar()
    giocatore = ListaTorneoGiocatore(lista_id=lista_id, persona_id=persona_id, ordine=max_ordine + 1)
    db.add(giocatore)
    db.commit()
    db.refresh(giocatore)
    return {"success": True}

@router.delete("/{lista_id}/giocatori/{persona_id}")
def remove_giocatore_lista(lista_id: int, persona_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    lista = db.query(ListaTorneo).filter(ListaTorneo.id == lista_id).first()
    if not lista:
        raise HTTPException(status_code=404, detail="Lista non trovata")
    societa_id = get_societa_filter(current_user)
    if societa_id and lista.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    giocatore = db.query(ListaTorneoGiocatore).filter(
        ListaTorneoGiocatore.lista_id == lista_id,
        ListaTorneoGiocatore.persona_id == persona_id
    ).first()
    if giocatore:
        db.delete(giocatore)
        db.commit()
    return {"success": True}

@router.delete("/{lista_id}")
def delete_lista_torneo(lista_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    lista = db.query(ListaTorneo).filter(ListaTorneo.id == lista_id).first()
    if not lista:
        return {"success": True}
    societa_id = get_societa_filter(current_user)
    if societa_id and lista.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    db.query(ListaTorneoGiocatore).filter(ListaTorneoGiocatore.lista_id == lista_id).delete()
    db.delete(lista)
    db.commit()
    return {"success": True}

@router.put("/{lista_id}/riordina")
def riordina_giocatori(lista_id: int, giocatori: List[dict], db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    lista = db.query(ListaTorneo).filter(ListaTorneo.id == lista_id).first()
    if not lista:
        raise HTTPException(status_code=404, detail="Lista non trovata")
    societa_id = get_societa_filter(current_user)
    if societa_id and lista.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    for i, g in enumerate(giocatori):
        db.execute(text("UPDATE liste_torneo_giocatori SET ordine = :ord WHERE lista_id = :lid AND persona_id = :pid"),
                   {"ord": i, "lid": lista_id, "pid": g["persona_id"]})
    db.commit()
    return {"success": True}