from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta, date
from pydantic import BaseModel
from typing import Optional, List
from ..database import SessionLocal
from ..models import Utente, UtenteCategoria, Categoria

SECRET_KEY = "REMOVED"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")
router = APIRouter(prefix="/auth", tags=["auth"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)

def hash_password(password):
    return pwd_context.hash(password)

def create_token(data: dict):
    to_encode = data.copy()
    to_encode["exp"] = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
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

class UtenteCreate(BaseModel):
    username: str
    password: str
    is_admin: Optional[int] = 0
    nome: str
    cognome: str
    data_nascita: date
    codice_fiscale: str
    cellulare: str
    tesserino: Optional[str] = None
    ruolo: Optional[str] = None

class UtenteUpdate(BaseModel):
    nome: str
    cognome: str
    data_nascita: date
    codice_fiscale: str
    cellulare: str
    tesserino: Optional[str] = None
    ruolo: Optional[str] = None

class AssegnaCategorie(BaseModel):
    categoria_ids: List[int]

class PasswordChange(BaseModel):
    vecchia: Optional[str] = None
    nuova: str

@router.post("/token")
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(Utente).filter(Utente.username == form.username).first()
    if not user or not verify_password(form.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Credenziali errate")
    token = create_token({"sub": user.username, "is_admin": user.is_admin})
    return {"access_token": token, "token_type": "bearer"}

@router.get("/me")
def me(current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.is_admin:
        categorie_ids = None  # admin vede tutto
    else:
        rows = db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == current_user.id).all()
        categorie_ids = [r.categoria_id for r in rows]
    return {
        "id": current_user.id,
        "username": current_user.username,
        "is_admin": current_user.is_admin,
        "categorie_ids": categorie_ids,
        "nome": current_user.nome,
        "cognome": current_user.cognome,
        "data_nascita": current_user.data_nascita,
        "codice_fiscale": current_user.codice_fiscale,
        "cellulare": current_user.cellulare,
        "tesserino": current_user.tesserino,
        "ruolo": current_user.ruolo
    }

@router.post("/utenti")
def crea_utente(data: UtenteCreate, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    if db.query(Utente).filter(Utente.username == data.username).first():
        raise HTTPException(status_code=400, detail="Username già esistente")
    utente = Utente(
        username=data.username,
        password_hash=hash_password(data.password),
        is_admin=data.is_admin,
        nome=data.nome,
        cognome=data.cognome,
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
    utente.nome = data.nome
    utente.cognome = data.cognome
    utente.data_nascita = data.data_nascita
    utente.codice_fiscale = data.codice_fiscale
    utente.cellulare = data.cellulare
    utente.tesserino = data.tesserino
    utente.ruolo = data.ruolo
    utente.is_admin = 1 if data.ruolo == 'admin' else 0
    db.commit()
    return {"ok": True}

@router.get("/utenti")
def lista_utenti(current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    utenti = db.query(Utente).all()
    result = []
    for u in utenti:
        rows = db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == u.id).all()
        result.append({
            "id": u.id,
            "username": u.username,
            "is_admin": u.is_admin,
            "categorie_ids": [r.categoria_id for r in rows],
            "nome": u.nome,
            "cognome": u.cognome,
            "data_nascita": u.data_nascita,
            "codice_fiscale": u.codice_fiscale,
            "cellulare": u.cellulare,
            "tesserino": u.tesserino,
            "ruolo": u.ruolo
        })
    return result

@router.put("/utenti/{uid}/categorie")
def assegna_categorie(uid: int, data: AssegnaCategorie, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == uid).delete()
    for cid in data.categoria_ids:
        db.add(UtenteCategoria(utente_id=uid, categoria_id=cid))
    db.commit()
    return {"ok": True}

@router.delete("/utenti/{uid}")
def elimina_utente(uid: int, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == uid).delete()
    db.query(Utente).filter(Utente.id == uid).delete()
    db.commit()
    return {"ok": True}

@router.put("/utenti/{uid}/reset-password")
def reset_password(uid: int, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
    utente = db.query(Utente).filter(Utente.id == uid).first()
    if not utente:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    utente.password_hash = hash_password("RedTigers2024!")
    db.commit()
    return {"ok": True, "message": "Password reimpostata a RedTigers2024!"}

@router.put("/utenti/{uid}/password")
def cambia_password(uid: int, data: PasswordChange, current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user.is_admin and current_user.id != uid:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    utente = db.query(Utente).filter(Utente.id == uid).first()
    if not utente:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    if not current_user.is_admin:
        if not data.vecchia or not verify_password(data.vecchia, utente.password_hash):
            raise HTTPException(status_code=400, detail="Password attuale errata")
    utente.password_hash = hash_password(data.nuova)
    db.commit()
    return {"ok": True}
