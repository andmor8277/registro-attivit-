from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta, date
from pydantic import BaseModel
from typing import Optional, List
from ..database import SessionLocal
from ..models import Utente, UtenteCategoria, Categoria

SECRET_KEY = "cambia-questa-chiave-segreta-123"
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
        # Aggiorna dati da token in caso di modifiche
        user.societa_id = payload.get("societa_id", user.societa_id)
        user.is_super_admin = payload.get("is_super_admin", user.is_super_admin)
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

@router.post("/token")
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(Utente).filter(Utente.username == form.username).first()
    if not user or not verify_password(form.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Credenziali errate")
    token = create_token({"sub": user.username, "is_admin": user.is_admin, "societa_id": user.societa_id, "is_super_admin": user.is_super_admin})
    return {"access_token": token, "token_type": "bearer"}

@router.get("/me")
def me(current_user: Utente = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.is_super_admin:
        categorie_ids = None  # super_admin vede tutto
    elif current_user.is_admin:
        # admin locale vede solo le categorie della propria società
        categorie_ids = None
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
        "codice_fiscale": current_user.codice_fiscale,
        "cellulare": current_user.cellulare,
        "tesserino": current_user.tesserino,
        "ruolo": current_user.ruolo
    }

@router.post("/utenti")
def crea_utente(data: UtenteCreate, current_user: Utente = Depends(get_admin), db: Session = Depends(get_db)):
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
    # Non super_admin può modificare solo utenti della propria società
    if not current_user.is_super_admin and utente.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a modificare utenti di altre società")
    # Non super_admin non può modificare super_admin
    if utente.is_super_admin and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato a modificare super admin")
    utente.nome = data.nome
    utente.cognome = data.cognome
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
    utente = db.query(Utente).filter(Utente.id == uid).first()
    if not utente:
        raise HTTPException(status_code=404, detail="Utente non trovato")
    # Non super_admin non può eliminare super_admin
    if utente.is_super_admin and not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Non autorizzato a eliminare super admin")
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
