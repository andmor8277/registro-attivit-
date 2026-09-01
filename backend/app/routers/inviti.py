from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
from uuid import uuid4
from ..database import get_db
from ..models import Invito, Utente, Societa
from ..routers.auth import get_admin, get_super_admin
from ..utils.email import send_email
import os

router = APIRouter(prefix="/inviti", tags=["inviti"])

FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:5173")

RUOLI_PERMESSI_ADMIN = {"mister", "dirigente", "segreteria", "infermeria"}


class InvitoCreate(BaseModel):
    email: str
    ruolo: str
    societa_id: Optional[int] = None


def costruisci_email_invito(societa_nome: str, ruolo: str, invite_link: str) -> str:
    return f"""
    <html>
    <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2>Invito a {societa_nome}</h2>
        <p>Sei stato invitato a unirti a <strong>{societa_nome}</strong> come <strong>{ruolo}</strong>.</p>
        <p>Clicca sul link sottostante per accedere:</p>
        <p>
            <a href="{invite_link}" style="background: #dc2626; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                Accedi con Google
            </a>
        </p>
        <p style="color: #666; font-size: 14px;">Questo link scadrà tra 30 giorni.</p>
    </body>
    </html>
    """


@router.post("/")
def crea_invito(
    data: InvitoCreate,
    current_user: Utente = Depends(get_admin),
    db: Session = Depends(get_db)
):
    # Super admin può invitare solo admin
    if current_user.is_super_admin:
        if data.ruolo != "admin":
            raise HTTPException(status_code=400, detail="Il super admin può invitare solo ruoli admin")
    else:
        if data.ruolo not in RUOLI_PERMESSI_ADMIN:
            raise HTTPException(status_code=403, detail=f"Ruolo non permesso. Puoi invitare: {', '.join(RUOLI_PERMESSI_ADMIN)}")

    # Verifica email valida
    if "@" not in data.email or "." not in data.email:
        raise HTTPException(status_code=400, detail="Email non valida")

    # Verifica che non esista già un invito attivo per questa email
    invitoo_esistente = db.query(Invito).filter(
        Invito.email == data.email,
        Invito.usato == False,
        Invito.scade > datetime.utcnow()
    ).first()
    if invitoo_esistente:
        raise HTTPException(status_code=400, detail="Esiste già un invito attivo per questa email")

    # Verifica che l'utente non esista già
    utente_esistente = db.query(Utente).filter(Utente.username == data.email).first()
    if utente_esistente:
        raise HTTPException(status_code=400, detail="Un utente con questa email esiste già")

    token = uuid4().hex
    scade = datetime.utcnow() + timedelta(days=30)

    # Determina societa_id
    if current_user.is_super_admin:
        if not data.societa_id:
            raise HTTPException(status_code=400, detail="Il super admin deve specificare la società")
        societa_id = data.societa_id
    else:
        societa_id = current_user.societa_id

    # Verifica che la società esista
    societa = db.query(Societa).filter(Societa.id == societa_id).first()
    if not societa:
        raise HTTPException(status_code=404, detail="Società non trovata")

    invito = Invito(
        email=data.email,
        societa_id=societa_id,
        ruolo=data.ruolo,
        token=token,
        scade=scade
    )
    db.add(invito)
    db.commit()
    db.refresh(invito)

    # Costruisce il link di invito
    invite_link = f"{FRONTEND_URL}/login?invito={token}"

    # Invia email
    societa_nome = societa.nome
    body_html = costruisci_email_invito(societa_nome, data.ruolo, invite_link)
    send_email(data.email, f"Invito a {societa_nome}", body_html)

    return {
        "ok": True,
        "id": invito.id,
        "email": invito.email,
        "ruolo": invito.ruolo,
        "scade": invito.scade.isoformat(),
        "link": invite_link
    }


@router.get("/")
def lista_inviti(
    societa_id: Optional[int] = Query(None),
    current_user: Utente = Depends(get_admin),
    db: Session = Depends(get_db)
):
    # Determina filtro società
    if current_user.is_super_admin:
        filter_id = societa_id
    else:
        filter_id = current_user.societa_id

    query = db.query(Invito)
    if filter_id:
        query = query.filter(Invito.societa_id == filter_id)
    query = query.order_by(Invito.creato_il.desc())

    inviti = query.all()
    result = []
    for inv in inviti:
        societa = db.query(Societa).filter(Societa.id == inv.societa_id).first()
        result.append({
            "id": inv.id,
            "email": inv.email,
            "ruolo": inv.ruolo,
            "societa_id": inv.societa_id,
            "societa_nome": societa.nome if societa else "N/A",
            "creato_il": inv.creato_il.isoformat() if inv.creato_il else None,
            "scade": inv.scade.isoformat(),
            "usato": inv.usato,
            "link": f"{FRONTEND_URL}/login?invito={inv.token}"
        })
    return result


@router.delete("/{invito_id}")
def elimina_invito(
    invito_id: int,
    current_user: Utente = Depends(get_admin),
    db: Session = Depends(get_db)
):
    invito = db.query(Invito).filter(Invito.id == invito_id).first()
    if not invito:
        raise HTTPException(status_code=404, detail="Invito non trovato")

    # Verifica permessi
    if not current_user.is_super_admin and invito.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")

    db.delete(invito)
    db.commit()
    return {"ok": True}


@router.post("/{invito_id}/rinvia")
def rinvia_invito(
    invito_id: int,
    current_user: Utente = Depends(get_admin),
    db: Session = Depends(get_db)
):
    invito = db.query(Invito).filter(Invito.id == invito_id).first()
    if not invito:
        raise HTTPException(status_code=404, detail="Invito non trovato")

    # Verifica permessi
    if not current_user.is_super_admin and invito.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")

    if invito.usato:
        raise HTTPException(status_code=400, detail="Invito già utilizzato")
    if invito.scade < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invito scaduto. Crea un nuovo invito.")

    societa = db.query(Societa).filter(Societa.id == invito.societa_id).first()
    if not societa:
        raise HTTPException(status_code=404, detail="Società non trovata")

    invite_link = f"{FRONTEND_URL}/login?invito={invito.token}"
    body_html = costruisci_email_invito(societa.nome, invito.ruolo, invite_link)
    send_email(invito.email, f"Invito a {societa.nome}", body_html)

    return {"ok": True, "email": invito.email}


@router.get("/verifica/{token}")
def verifica_invito(token: str, db: Session = Depends(get_db)):
    """Endpoint pubblico: verifica se un token invito è valido."""
    invito = db.query(Invito).filter(Invito.token == token).first()
    if not invito:
        raise HTTPException(status_code=404, detail="Invito non trovato")
    if invito.usato:
        raise HTTPException(status_code=400, detail="Invito già utilizzato")
    if invito.scade < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invito scaduto")

    societa = db.query(Societa).filter(Societa.id == invito.societa_id).first()
    return {
        "valido": True,
        "email": invito.email,
        "ruolo": invito.ruolo,
        "societa_nome": societa.nome if societa else "Società"
    }
