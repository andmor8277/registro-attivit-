from typing import Optional
from fastapi import Request
from sqlalchemy.orm import Session
from ..models import Utente


def get_societa_filter(
    current_user: Utente,
    societa_id: Optional[int] = None,
    request: Optional[Request] = None
) -> Optional[int]:
    """
    Restituisce il societa_id per filtrare i dati di un tenant.
    - Se l'utente non è super_admin: restituisce SEMPRE current_user.societa_id (isolamento totale).
    - Se l'utente è super_admin:
      1. Se viene passato societa_id esplicitamente (parametro query/argomento), usa quello.
      2. Altrimenti, se request contiene l'header 'X-Societa-Id', usa quello.
      3. Se non specificato, restituisce None.
    """
    if not current_user.is_super_admin:
        return current_user.societa_id

    if societa_id is not None:
        try:
            return int(societa_id)
        except (ValueError, TypeError):
            pass

    if request is not None:
        hdr = request.headers.get("X-Societa-Id")
        if hdr:
            try:
                return int(hdr.strip())
            except (ValueError, TypeError):
                pass

    return None


def resolve_tenant_societa_id(
    current_user: Utente,
    explicit_societa_id: Optional[int] = None,
    request: Optional[Request] = None,
    categoria_id: Optional[int] = None,
    persona_id: Optional[int] = None,
    db: Optional[Session] = None
) -> Optional[int]:
    """
    Determina il societa_id da assegnare a un record creato o aggiornato:
    1. Per utenti non super_admin -> restituisce SEMPRE current_user.societa_id.
    2. Per super_admin:
       - usa explicit_societa_id se presente;
       - altrimenti usa header 'X-Societa-Id' se presente;
       - altrimenti ricava societa_id dalla categoria o persona collegata.
    """
    if not current_user.is_super_admin:
        return current_user.societa_id

    if explicit_societa_id is not None:
        try:
            return int(explicit_societa_id)
        except (ValueError, TypeError):
            pass

    if request is not None:
        hdr = request.headers.get("X-Societa-Id")
        if hdr:
            try:
                return int(hdr.strip())
            except (ValueError, TypeError):
                pass

    if db is not None:
        if categoria_id is not None:
            from ..models import Categoria
            cat = db.query(Categoria).filter(Categoria.id == categoria_id).first()
            if cat and cat.societa_id:
                return cat.societa_id

        if persona_id is not None:
            from ..models import Persona
            p = db.query(Persona).filter(Persona.id == persona_id).first()
            if p and p.societa_id:
                return p.societa_id

    return current_user.societa_id

