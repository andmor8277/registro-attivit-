import os
from datetime import datetime
from fastapi import HTTPException
from ..models import Invito

FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:5173")
RUOLI_PERMESSI_ADMIN = {"mister", "dirigente", "segreteria", "infermeria", "scouting"}


def build_invite_link(token: str) -> str:
    return f"{FRONTEND_URL}/login?invito={token}"


def costruisci_email_invito(societa_nome: str, ruolo: str, invite_link: str, categoria_nome: str = None) -> str:
    categoria_riga = f"<p>Categoria di appartenenza: <strong>{categoria_nome}</strong>.</p>" if categoria_nome else ""
    return f"""
    <html>
    <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2>Invito a {societa_nome}</h2>
        <p>Sei stato invitato a unirti a <strong>{societa_nome}</strong> come <strong>{ruolo}</strong>.</p>
        {categoria_riga}
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


def costruisci_email_password_iniziale(nome: str, cognome: str, societa_nome: str,
                                       username: str, password: str, url_login: str) -> str:
    """Email con la password iniziale di un account a accesso locale.

    La password viaggia in mail e non viene mai mostrata all'admin che ha creato l'utente:
    e' il motivo per cui questa funzione esiste. Se un admin poteva scegliere o vedere la
    password di un altro account, poteva entrarci (era cosi' prima del 2026-11-16).
    """
    return f"""
    <html>
    <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2>Il tuo accesso a {societa_nome}</h2>
        <p>Ciao {nome}, un amministratore di <strong>{societa_nome}</strong> ha creato il tuo account.</p>
        <p>
            <strong>Nome utente:</strong> {username}<br>
            <strong>Password iniziale:</strong> <code style="font-size: 16px; letter-spacing: 1px;">{password}</code>
        </p>
        <p>
            <a href="{url_login}" style="background: #dc2626; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                Accedi
            </a>
        </p>
        <p style="color: #666; font-size: 14px;">
            Al primo accesso ti verra' chiesto di cambiarla: fino a quel momento l'applicazione
            non ti mostrera' nessun dato.
        </p>
    </body>
    </html>
    """


def get_invitation(db, token: str):
    return db.query(Invito).filter(Invito.token == token).first()


def is_invitation_used(invito) -> bool:
    return bool(invito.usato)


def is_invitation_expired(invito) -> bool:
    return invito.scade < datetime.utcnow()
