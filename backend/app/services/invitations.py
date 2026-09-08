import os
from datetime import datetime
from fastapi import HTTPException
from ..models import Invito

FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:5173")
RUOLI_PERMESSI_ADMIN = {"mister", "dirigente", "segreteria", "infermeria"}


def build_invite_link(token: str) -> str:
    return f"{FRONTEND_URL}/login?invito={token}"


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


def get_invitation(db, token: str):
    return db.query(Invito).filter(Invito.token == token).first()


def is_invitation_used(invito) -> bool:
    return bool(invito.usato)


def is_invitation_expired(invito) -> bool:
    return invito.scade < datetime.utcnow()
