from fastapi import APIRouter, Depends, HTTPException, Request, Query
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.responses import RedirectResponse, JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta, date, timezone
from pydantic import BaseModel
from typing import Optional, List
from urllib.parse import urlencode
from ..database import get_db
from ..models import Utente, UtenteCategoria, Categoria, Invito, Societa
from ..rate_limit import limiter
import os
import re
import json
import httpx
import secrets

def format_cognome(val):
    return val.upper() if val else val

def format_nome(val):
    if not val: return val
    return ' '.join(w[:1].upper() + w[1:].lower() for w in val.split())

SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY environment variable is required")
DEFAULT_PASSWORD = os.environ.get("DEFAULT_PASSWORD")
if not DEFAULT_PASSWORD:
    raise RuntimeError("DEFAULT_PASSWORD environment variable is required")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")
router = APIRouter(prefix="/auth", tags=["auth"])

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

def create_token(data: dict):
    to_encode = data.copy()
    to_encode["exp"] = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="Token non valido")
        user = db.query(Utente).filter(Utente.username == username).first()
        if not user:
            raise HTTPException(status_code=401, detail="Utente non trovato")
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

def check_societa(current_user: Utente, societa_id: int):
    """Verifica che l'utente appartenga alla societa specificata o sia super_admin."""
    if not current_user.is_super_admin and current_user.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su questa società")
    return current_user

class UtenteCreate(BaseModel):
    username: str
    password: str
    is_admin: Optional[int] = 0
    is_super_admin: Optional[int] = 0
    societa_id: Optional[int] = None
    nome: str
    cognome: str
    data_nascita: Optional[date] = None
    codice_fiscale: Optional[str] = None
    cellulare: Optional[str] = None
    tesserino: Optional[str] = None
    ruolo: Optional[str] = None

class UtenteUpdate(BaseModel):
    nome: str
    cognome: str
    data_nascita: Optional[date] = None
    codice_fiscale: Optional[str] = None
    cellulare: Optional[str] = None
    societa_id: Optional[int] = None
    tesserino: Optional[str] = None
    ruolo: Optional[str] = None
    is_super_admin: Optional[int] = 0

class AssegnaCategorie(BaseModel):
    categoria_ids: List[int]

class PasswordChange(BaseModel):
    vecchia: Optional[str] = None
    nuova: str

@limiter.limit("10/minute")
@router.post("/token")
def login(request: Request, form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(Utente).filter(Utente.username == form.username).first()
    if not user or not user.password_hash or not verify_password(form.password, user.password_hash):
        if not user:
            verify_password(form.password, "$2b$12$260mdxWoPqJ9blHKaB4fKuiJbLr7WbMYw6K78Q3vGHxRRz8xZzqEi")
        raise HTTPException(status_code=401, detail="Credenziali errate")
    token = create_token({"sub": user.username, "is_admin": user.is_admin, "societa_id": user.societa_id, "is_super_admin": user.is_super_admin})
    return {"access_token": token, "token_type": "bearer"}

@router.get("/me")
def me(current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.is_super_admin:
        categorie_ids = None  # super_admin vede tutto
    elif current_user.is_admin:
        # admin vede tutto, ma può essere assegnato a categorie specifiche
        rows = db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == current_user.id).all()
        categorie_ids = [r.categoria_id for r in rows]
    else:
        rows = db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == current_user.id).all()
        categorie_ids = [r.categoria_id for r in rows]
    return {
        "id": current_user.id,
        "username": current_user.username,
        "is_admin": current_user.is_admin,
        "is_super_admin": current_user.is_super_admin,
        "societa_id": None if current_user.is_super_admin else current_user.societa_id,
        "categorie_ids": categorie_ids,
        "nome": current_user.nome,
        "cognome": current_user.cognome,
        "data_nascita": current_user.data_nascita,
        "cellulare": current_user.cellulare,
        "tesserino": current_user.tesserino,
        "ruolo": current_user.ruolo
    }

@router.post("/utenti")
def crea_utente(data: UtenteCreate, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    validate_password(data.password)
    if db.query(Utente).filter(Utente.username == data.username).first():
        raise HTTPException(status_code=400, detail="Username già esistente")
    
    # Se il ruolo è super_admin, imposta is_super_admin = 1 e is_admin = 1
    is_super = 1 if data.ruolo == 'super_admin' else 0
    is_admin = 1 if data.ruolo in ('super_admin', 'admin') else 0
    
    # Solo super_admin può creare super_admin
    if is_super and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato a creare super admin")
    
    # Admin locale può creare utenti solo per la propria società
    if not current_user.is_super_admin and data.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a creare utenti per altre società")
    
    utente = Utente(
        username=data.username,
        password_hash=hash_password(data.password),
        is_admin=is_admin,
        is_super_admin=is_super,
        societa_id=data.societa_id,
        nome=format_nome(data.nome),
        cognome=format_cognome(data.cognome),
        data_nascita=data.data_nascita,
        codice_fiscale=data.codice_fiscale,
        cellulare=data.cellulare,
        tesserino=data.tesserino,
        ruolo=data.ruolo
    )
    db.add(utente)
    db.commit()
    return {"ok": True}

@router.put("/utenti/{uid}")
def modifica_utente(uid: int, data: UtenteUpdate, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    utente = db.query(Utente).filter(Utente.id == uid).first()
    if not utente:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    # Non super_admin può modificare solo utenti della propria società
    if not current_user.is_super_admin and utente.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a modificare utenti di altre società")
    # Non super_admin non può modificare super_admin
    if utente.is_super_admin and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato a modificare super admin")
    utente.nome = format_nome(data.nome)
    utente.cognome = format_cognome(data.cognome)
    utente.data_nascita = data.data_nascita
    utente.codice_fiscale = data.codice_fiscale
    utente.cellulare = data.cellulare
    utente.tesserino = data.tesserino
    # Solo super_admin può modificare società dell'utente
    if current_user.is_super_admin:
        # Converti in int se è una stringa
        if data.societa_id is not None:
            if isinstance(data.societa_id, str):
                utente.societa_id = int(data.societa_id)
            else:
                utente.societa_id = data.societa_id
    # Non super_admin non può assegnare ruolo super_admin
    if data.ruolo == 'super_admin' and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato ad assegnare ruolo super_admin")
    utente.ruolo = data.ruolo
    utente.is_admin = 1 if data.ruolo in ('admin', 'super_admin') else 0
    # Solo super_admin può modificare is_super_admin
    if current_user.is_super_admin:
        utente.is_super_admin = 1 if data.ruolo == 'super_admin' else 0
    db.commit()
    return {"ok": True}

@router.get("/utenti")
def lista_utenti(
    societa_id: Optional[int] = None,
    current_user: Utente = Depends(get_admin), 
    db: Session = Depends(get_db)
):
    # Se non è super_admin, mostra solo utenti della propria società (escludendo super_admin)
    if not current_user.is_super_admin:
        utenti = db.query(Utente).filter(
            and_(
                Utente.societa_id == current_user.societa_id,
                or_(Utente.is_super_admin == 0, Utente.is_super_admin == None)
            )
        ).all()
    else:
        # Superadmin: filtra per società se specificata
        if societa_id:
            utenti = db.query(Utente).filter(Utente.societa_id == societa_id).all()
        else:
            utenti = db.query(Utente).all()
    result = []
    for u in utenti:
        rows = db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == u.id).all()
        result.append({
            "id": u.id,
            "username": u.username,
            "is_admin": u.is_admin,
            "is_super_admin": u.is_super_admin,
            "societa_id": u.societa_id,
            "categorie_ids": [r.categoria_id for r in rows],
            "nome": u.nome,
            "cognome": u.cognome,
            "data_nascita": u.data_nascita,
            "cellulare": u.cellulare,
            "tesserino": u.tesserino,
            "ruolo": u.ruolo
        })
    return result

@router.put("/utenti/{uid}/categorie")
def assegna_categorie(uid: int, data: AssegnaCategorie, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    utente = db.query(Utente).filter(Utente.id == uid).first()
    if not utente:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    if not current_user.is_super_admin and utente.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su utenti di altre società")
    for cid in data.categoria_ids:
        cat = db.query(Categoria).filter(Categoria.id == cid).first()
        if not cat:
            raise HTTPException(status_code=404, detail=f"Categoria {cid} non trovata")
        if cat.parent_id is None:
            raise HTTPException(status_code=400, detail=f"Non è possibile assegnare la categoria padre '{cat.nome}'")
    db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == uid).delete()
    for cid in data.categoria_ids:
        db.add(UtenteCategoria(utente_id=uid, categoria_id=cid))
    db.commit()
    return {"ok": True}

@router.delete("/utenti/{uid}")
def elimina_utente(uid: int, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    utente = db.query(Utente).filter(Utente.id == uid).first()
    if not utente:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    # Non super_admin può eliminare solo utenti della propria società
    if not current_user.is_super_admin and utente.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a eliminare utenti di altre società")
    # Non super_admin non può eliminare super_admin
    if utente.is_super_admin and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato a eliminare super admin")
    db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == uid).delete()
    db.query(Utente).filter(Utente.id == uid).delete()
    db.commit()
    return {"ok": True}

@limiter.limit("5/minute")
@router.put("/utenti/{uid}/reset-password")
def reset_password(request: Request, uid: int, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    utente = db.query(Utente).filter(Utente.id == uid).first()
    if not utente:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    # Non super_admin può resettare solo utenti della propria società
    if not current_user.is_super_admin and utente.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a resettare utenti di altre società")
    # Non super_admin non può resettare super_admin
    if utente.is_super_admin and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato a resettare super admin")
    utente.password_hash = hash_password(DEFAULT_PASSWORD)
    db.commit()
    return {"ok": True, "message": "Password reimpostata"}

@router.put("/utenti/{uid}/password")
def cambia_password(uid: int, data: PasswordChange, current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    validate_password(data.nuova)
    if not current_user.is_admin and current_user.id != uid:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    utente = db.query(Utente).filter(Utente.id == uid).first()
    if not utente:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    if not current_user.is_admin:
        if not data.vecchia or not verify_password(data.vecchia, utente.password_hash):
            raise HTTPException(status_code=400, detail="Password attuale errata")
    elif not current_user.is_super_admin and utente.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su utenti di altre società")
    utente.password_hash = hash_password(data.nuova)
    db.commit()
    return {"ok": True}


# ── Google OAuth ──

GOOGLE_CREDENTIALS_PATH = os.environ.get("GOOGLE_CREDENTIALS_PATH", "/app/google-credentials.json")
FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:5173")

_google_config = None

def get_google_config():
    global _google_config
    if _google_config:
        return _google_config
    try:
        with open(GOOGLE_CREDENTIALS_PATH) as f:
            _google_config = json.load(f)
        if isinstance(_google_config, dict) and "web" in _google_config:
            _google_config = _google_config["web"]
    except Exception as e:
        print(f"Google credentials error: {e}")
        _google_config = None
    return _google_config


def get_google_authorize_url(state: str):
    config = get_google_config()
    if not config:
        raise HTTPException(status_code=500, detail="Google OAuth non configurato")

    client_id = config.get("client_id")
    redirect_uri = f"{FRONTEND_URL}/registrazione"

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": "openid email profile",
        "prompt": "select_account",
        "state": state,
    }
    return f"https://accounts.google.com/o/oauth2/v2/auth?{urlencode(params)}"


@router.get("/google/authorize")
def google_authorize(request: Request, invito: Optional[str] = Query(None)):
    """Redirect to Google OAuth. Pass ?invito=token to link invitation."""
    # CSRF state: random, salvato in cookie httpOnly, verificato in callback
    state = secrets.token_urlsafe(32)
    url = get_google_authorize_url(state)
    secure = request.url.scheme == "https"

    resp = RedirectResponse(url=url)
    resp.set_cookie(
        key="oauth_state",
        value=state,
        httponly=True,
        samesite="lax",
        secure=secure,
        path="/",
        max_age=600,
    )
    if invito:
        resp.set_cookie(
            key="oauth_invito",
            value=invito,
            httponly=True,
            samesite="lax",
            secure=secure,
            path="/",
            max_age=600,
        )
    else:
        resp.delete_cookie("oauth_invito", path="/")
    return resp


def _clear_oauth_cookies(resp):
    resp.delete_cookie("oauth_state", path="/")
    resp.delete_cookie("oauth_invito", path="/")
    return resp


@router.get("/google/callback")
async def google_callback(
    code: str,
    request: Request,
    state: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    """Google OAuth callback. Exchanges code for user info."""
    # Verifica CSRF: il parametro state deve corrispondere al cookie
    cookie_state = request.cookies.get("oauth_state")
    if not cookie_state or not state or cookie_state != state:
        raise HTTPException(status_code=400, detail="Richiesta non valida (state mismatch)")

    config = get_google_config()
    if not config:
        raise HTTPException(status_code=500, detail="Google OAuth non configurato")

    client_id = config.get("client_id")
    client_secret = config.get("client_secret")
    redirect_uri = f"{FRONTEND_URL}/registrazione"

    # Exchange code for tokens
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post("https://oauth2.googleapis.com/token", data={
                "code": code,
                "client_id": client_id,
                "client_secret": client_secret,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code"
            })
            resp.raise_for_status()
            token_data = resp.json()
            access_token = token_data["access_token"]

            # Get user info
            resp = await client.get("https://www.googleapis.com/oauth2/v2/userinfo", headers={
                "Authorization": f"Bearer {access_token}"
            })
            resp.raise_for_status()
            google_user = resp.json()
    except Exception as e:
        print(f"Google OAuth error: {e}")
        raise HTTPException(status_code=400, detail="Errore nella comunicazione con Google")

    google_email = google_user.get("email", "").lower()
    google_name = google_user.get("name", "")
    google_sub = google_user.get("sub", "")
    email_verified = google_user.get("verified_email", False)

    if not google_email:
        raise HTTPException(status_code=400, detail="Email non trovata")

    # Verifica email confirmata da Google
    if not email_verified:
        raise HTTPException(status_code=400, detail="Email Google non verificata")

    # Match utente per google_sub prima, poi per email (backward compat)
    existing_user = db.query(Utente).filter(Utente.google_sub == google_sub).first()
    if not existing_user:
        existing_user = db.query(Utente).filter(Utente.username == google_email).first()
        if existing_user:
            existing_user.google_sub = google_sub
            db.commit()

    if existing_user:
        # Return existing JWT
        token = create_token({
            "sub": existing_user.username,
            "is_admin": existing_user.is_admin,
            "societa_id": existing_user.societa_id,
            "is_super_admin": existing_user.is_super_admin
        })
        resp = JSONResponse({
            "access_token": token,
            "token_type": "bearer",
            "user": {
                "id": existing_user.id,
                "username": existing_user.username,
                "is_admin": existing_user.is_admin,
                "is_super_admin": existing_user.is_super_admin,
                "societa_id": existing_user.societa_id,
                "nome": existing_user.nome,
                "cognome": existing_user.cognome,
                "ruolo": existing_user.ruolo
            },
            "requires_registration": False
        })
        return _clear_oauth_cookies(resp)

    # New user: read invitation token from cookie (non trustable da client)
    invito_token = request.cookies.get("oauth_invito")
    if not invito_token:
        raise HTTPException(status_code=400, detail="Nessun invito trovato. Contatta un amministratore.")

    invito = db.query(Invito).filter(Invito.token == invito_token).first()
    if not invito:
        raise HTTPException(status_code=404, detail="Invito non trovato")
    if invito.usato:
        raise HTTPException(status_code=400, detail="Invito già utilizzato")
    if invito.scade < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invito scaduto")
    if invito.email.lower() != google_email:
        raise HTTPException(status_code=400, detail="L'email Google non corrisponde a quella dell'invito")

    # Verify society exists
    societa = db.query(Societa).filter(Societa.id == invito.societa_id).first()
    if not societa:
        raise HTTPException(status_code=404, detail="Società non trovata")

    # Emi un reg_token temporaneo firmato: prova che questo utente ha
    # completato la callback OAuth. Serve a POST /google/registra.
    reg_token = jwt.encode({
        "invito_token": invito.token,
        "google_sub": google_sub,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=10)
    }, SECRET_KEY, algorithm=ALGORITHM)

    # Return info for registration form
    name_parts = google_name.split(" ", 1)
    resp = JSONResponse({
        "requires_registration": True,
        "reg_token": reg_token,
        "google_email": google_email,
        "google_name": google_name,
        "google_nome": name_parts[0] if len(name_parts) > 0 else "",
        "google_cognome": name_parts[1] if len(name_parts) > 1 else "",
        "ruolo": invito.ruolo,
        "societa_id": invito.societa_id,
        "societa_nome": societa.nome
    })
    return _clear_oauth_cookies(resp)


class RegistrazioneData(BaseModel):
    nome: str
    cognome: str
    cellulare: str
    data_nascita: str
    codice_fiscale: str
    tesserino: Optional[str] = None
    reg_token: str


@router.post("/google/registra")
def registra_utente_google(
    data: RegistrazioneData,
    db: Session = Depends(get_db)
):
    """Crea utente dopo Google OAuth + form registrazione.
    Richiede il reg_token emesso dal callback (prova di possesso Google)."""
    from datetime import datetime as dt

    # Verifica il reg_token firmato: chi chiama deve aver completato il callback
    try:
        payload = jwt.decode(data.reg_token, SECRET_KEY, algorithms=[ALGORITHM])
        invito_token = payload.get("invito_token")
        google_sub = payload.get("google_sub")
    except JWTError:
        raise HTTPException(status_code=400, detail="Sessione di registrazione non valida o scaduta. Riprova.")
    if not invito_token:
        raise HTTPException(status_code=400, detail="Sessione di registrazione non valida")

    # Verify invitation
    invito = db.query(Invito).filter(Invito.token == invito_token).first()
    if not invito:
        raise HTTPException(status_code=404, detail="Invito non trovato")
    if invito.usato:
        raise HTTPException(status_code=400, detail="Invito già utilizzato")
    if invito.scade < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invito scaduto")

    # Check user doesn't already exist
    if db.query(Utente).filter(Utente.username == invito.email).first():
        raise HTTPException(status_code=400, detail="Utente già esistente")

    # Parse date
    try:
        data_nascita = dt.strptime(data.data_nascita, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Data di nascita non valida")

    # Create user (no password hash needed for Google-only)
    is_admin = 1 if invito.ruolo == "admin" else 0
    is_super = 1 if invito.ruolo == "super_admin" else 0

    utente = Utente(
        username=invito.email,
        password_hash=None,
        google_sub=google_sub or None,
        is_admin=is_admin,
        is_super_admin=is_super,
        societa_id=invito.societa_id,
        nome=format_nome(data.nome),
        cognome=format_cognome(data.cognome),
        data_nascita=data_nascita,
        codice_fiscale=data.codice_fiscale.upper() if data.codice_fiscale else None,
        cellulare=data.cellulare,
        tesserino=data.tesserino,
        ruolo=invito.ruolo
    )
    db.add(utente)
    db.commit()
    db.refresh(utente)

    # Mark invitation as used
    invito.usato = True
    db.commit()

    # Create JWT
    token = create_token({
        "sub": utente.username,
        "is_admin": utente.is_admin,
        "societa_id": utente.societa_id,
        "is_super_admin": utente.is_super_admin
    })

    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": utente.id,
            "username": utente.username,
            "is_admin": utente.is_admin,
            "is_super_admin": utente.is_super_admin,
            "societa_id": utente.societa_id,
            "nome": utente.nome,
            "cognome": utente.cognome,
            "ruolo": utente.ruolo
        }
    }
