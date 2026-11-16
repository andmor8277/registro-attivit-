import os
import re
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, Request
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Utente

SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY environment variable is required")

# Non e' piu' usata per i reset: dal 2026-11-16 ogni reset genera una password temporanea
# propria per quell'utente (vedi genera_password_temporanea). Resta letta perche' i compose
# la passano ancora e per non far fallire l'avvio su un .env che la contiene; non va piu'
# distribuita a nessuno.
DEFAULT_PASSWORD = os.environ.get("DEFAULT_PASSWORD")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", 60 * 24 * 30))  # Default 30 giorni per evitare logout frequenti su app mobile

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)


def hash_password(password):
    return pwd_context.hash(password)


def validate_password(password: str):
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="La password deve avere almeno 8 caratteri")
    if not re.search(r'[A-Z]', password):
        raise HTTPException(status_code=400, detail="La password deve contenere almeno un carattere maiuscolo")
    if not re.search(r'[a-z]', password):
        raise HTTPException(status_code=400, detail="La password deve contenere almeno un carattere minuscolo")
    if not re.search(r'\d', password):
        raise HTTPException(status_code=400, detail="La password deve contenere almeno un numero")
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        raise HTTPException(status_code=400, detail="La password deve contenere almeno un carattere speciale")


# Alfabeto senza i caratteri che a schermo o dettati al telefono si confondono: O/0, I/l/1,
# e senza spazi. La password temporanea viene mostrata una volta sola all'admin e digitata
# una volta sola dall'utente, quindi deve essere ricopiabile a mano senza ambiguita'.
_PW_MAIUSCOLE = "ABCDEFGHJKLMNPQRSTUVWXYZ"
_PW_MINUSCOLE = "abcdefghjkmnpqrstuvwxyz"
_PW_CIFRE = "23456789"
_PW_SPECIALI = "!@#$%^&*()"


def genera_password_temporanea(lunghezza: int = 14) -> str:
    """Password casuale per il reset di un singolo utente.

    Sostituisce la vecchia DEFAULT_PASSWORD, che era unica e condivisa: finche' esisteva lei,
    chiunque la conoscesse poteva entrare in qualsiasi account appena resettato. Qui ogni reset
    produce un valore proprio, mostrato una volta sola all'admin e mai salvato in chiaro.
    """
    if lunghezza < 8:
        raise ValueError("la password temporanea deve avere almeno 8 caratteri")
    # una garanzia per classe, cosi' il risultato supera validate_password senza doverci riprovare
    caratteri = [
        secrets.choice(_PW_MAIUSCOLE),
        secrets.choice(_PW_MINUSCOLE),
        secrets.choice(_PW_CIFRE),
        secrets.choice(_PW_SPECIALI),
    ]
    tutto = _PW_MAIUSCOLE + _PW_MINUSCOLE + _PW_CIFRE + _PW_SPECIALI
    while len(caratteri) < lunghezza:
        caratteri.append(secrets.choice(tutto))
    # secrets.SystemRandom shuffle: senza mescolamento le prime quattro posizioni sarebbero
    # sempre maiuscola/minuscola/cifra/speciale, una struttura prevedibile
    secrets.SystemRandom().shuffle(caratteri)
    pw = "".join(caratteri)
    # se qualcuno inasprira' validate_password senza aggiornare l'alfabeto, meglio scoprirlo
    # qui con un errore che consegnare una password che l'utente non potra' tenere
    validate_password(pw)
    return pw


def create_token(data: dict):
    to_encode = data.copy()
    to_encode["exp"] = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


# Pochi percorsi restano raggiungibili a chi deve ancora cambiare la password temporanea.
# Senza questa lista il flag sarebbe solo un suggerimento del frontend: chi chiama l'API a
# mano continuerebbe a leggere anagrafiche e presenze con la password ricevuta dal reset.
_PERCORSI_CONSENTITI_SENZA_CAMBIO = ("/auth/me", "/auth/logout")


def _consentito_senza_cambio_password(path: str, user) -> bool:
    # nginx arriva al container senza prefisso, il frontend passa da /api: normalizziamo
    p = path or ""
    if p.startswith("/api"):
        p = p[len("/api"):]
    if not p.startswith("/"):
        p = "/" + p
    if p in _PERCORSI_CONSENTITI_SENZA_CAMBIO:
        return True
    # il cambio password stesso, ma solo sul proprio id
    parti = [x for x in p.split("/") if x]
    return (len(parti) == 4 and parti[0] == "auth" and parti[1] == "utenti"
            and parti[3] == "password" and parti[2] == str(user.id))


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db),
                     request: Request = None):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="Token non valido")
        user = db.query(Utente).filter(Utente.username == username).first()
        if not user:
            raise HTTPException(status_code=401, detail="Utente non trovato")
        if getattr(user, "deve_cambiare_password", False) and not _consentito_senza_cambio_password(
            request.url.path if request is not None else "", user
        ):
            raise HTTPException(status_code=403, detail={
                "code": "PASSWORD_DA_CAMBIARE",
                "message": "Devi cambiare la password prima di continuare.",
            })
        return user
    except JWTError:
        raise HTTPException(status_code=401, detail="Token non valido")


def get_admin(current_user: Utente = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Solo admin")
    return current_user


def get_super_admin(current_user: Utente = Depends(get_current_user)):
    if not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Solo super admin")
    return current_user


def requires_roles(*roles):
    def dependency(current_user: Utente = Depends(get_current_user)):
        if current_user.is_super_admin:
            return current_user
        if current_user.is_admin and "admin" in roles:
            return current_user
        if current_user.ruolo in roles:
            return current_user
        raise HTTPException(status_code=403, detail="Non autorizzato")
    return dependency


get_segreteria = requires_roles("admin", "segreteria")
get_infermeria = requires_roles("admin", "infermeria", "segreteria")
get_scouting = requires_roles("admin", "scouting")
get_persona_staff = requires_roles("admin", "segreteria", "mister", "infermeria")
get_persona_admin = requires_roles("admin", "segreteria")
get_staff_admin = requires_roles("admin")


def check_societa(current_user: Utente, societa_id: int):
    if not current_user.is_super_admin and current_user.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su questa società")
    return current_user
