from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from .. import models
from ..database import get_db
from ..routers.auth import get_current_user, get_admin
from ..models import Utente, UtenteCategoria
from pydantic import BaseModel
from typing import Optional, List

router = APIRouter(prefix="/categorie", tags=["categorie"])

class CategoriaCreate(BaseModel):
    nome: str
    anno: Optional[int] = None
    stagione: Optional[int] = None
    giorni: Optional[str] = None
    is_portieri: bool = False

@router.get("/")
def get_categorie(db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    tutte = db.query(models.Categoria).filter(
        models.Categoria.is_archiviata == 0
    ).order_by(models.Categoria.anno.desc()).all()
    if current_user.is_admin:
        return tutte
    assegnate = db.query(UtenteCategoria).filter(UtenteCategoria.utente_id == current_user.id).all()
    ids = {r.categoria_id for r in assegnate}
    return [c for c in tutte if c.id in ids]

@router.get("/all")
def get_all_categorie(db: Session = Depends(get_db)):
    return db.query(models.Categoria).filter(
        models.Categoria.is_archiviata == 0
    ).order_by(models.Categoria.anno.desc()).all()

@router.get("/archived")
def get_categorie_archived(db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    return db.query(models.Categoria).filter(
        models.Categoria.is_archiviata == 1
    ).order_by(models.Categoria.anno.desc()).all()

@router.get("/stagioni")
def get_stagioni(db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    stagioni_attive = db.query(models.Categoria.stagione).filter(
        models.Categoria.is_archiviata == 0,
        models.Categoria.stagione.isnot(None)
    ).distinct().order_by(models.Categoria.stagione.desc()).all()
    
    stagioni_archiviate = db.query(models.Categoria.stagione).filter(
        models.Categoria.is_archiviata == 1,
        models.Categoria.stagione.isnot(None)
    ).distinct().order_by(models.Categoria.stagione.desc()).all()
    
    return {
        "attiva": [s.stagione for s in stagioni_attive],
        "archiviate": [s.stagione for s in stagioni_archiviate]
    }

@router.post("/archivia/{stagione}")
def archivia_stagione(stagione: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    db.query(models.Categoria).filter(
        models.Categoria.stagione == stagione
    ).update({"is_archiviata": 1})
    db.commit()
    return {"ok": True, "messaggio": f"Stagione {stagione}/{stagione+1} archiviata"}

@router.post("/ripristina/{stagione}")
def ripristina_stagione(stagione: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    db.query(models.Categoria).filter(
        models.Categoria.stagione == stagione
    ).update({"is_archiviata": 0})
    db.commit()
    return {"ok": True, "messaggio": f"Stagione {stagione}/{stagione+1} ripristinata"}

@router.get("/by-stagione/{stagione}")
def get_categorie_by_stagione(stagione: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    categorie = db.query(models.Categoria).filter(
        models.Categoria.stagione == stagione
    ).order_by(models.Categoria.nome).all()
    if not categorie:
        raise HTTPException(status_code=404, detail="Nessuna categoria per questa stagione")
    return categorie

@router.post("/")
def create_categoria(c: CategoriaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    cat = models.Categoria(
        nome=c.nome,
        anno=c.anno,
        stagione=c.stagione,
        giorni=c.giorni,
        is_portieri=1 if c.is_portieri else 0
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    if not current_user.is_admin:
        db.add(UtenteCategoria(utente_id=current_user.id, categoria_id=cat.id))
        db.commit()
    return cat

@router.put("/{categoria_id}")
def update_categoria(categoria_id: int, c: CategoriaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    cat = db.query(models.Categoria).filter(models.Categoria.id == categoria_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    cat.nome = c.nome
    cat.anno = c.anno
    cat.stagione = c.stagione
    cat.giorni = c.giorni
    cat.is_portieri = 1 if c.is_portieri else 0
    db.commit(); db.refresh(cat)
    return cat

@router.delete("/{categoria_id}")
def delete_categoria(categoria_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    db.query(models.Registro).filter(models.Registro.categoria_id == categoria_id).delete()
    db.query(models.Persona).filter(models.Persona.categoria_id == categoria_id).delete()
    db.query(UtenteCategoria).filter(UtenteCategoria.categoria_id == categoria_id).delete()
    db.query(models.Categoria).filter(models.Categoria.id == categoria_id).delete()
    db.commit()
    return {"ok": True}

class AssegnaUtenti(BaseModel):
    utente_ids: List[int]

@router.get("/{categoria_id}/utenti")
def get_categoria_utenti(categoria_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    assegnazioni = db.query(UtenteCategoria).filter(UtenteCategoria.categoria_id == categoria_id).all()
    return [a.utente_id for a in assegnazioni]

@router.put("/{categoria_id}/utenti")
def assegna_utenti_categoria(categoria_id: int, data: AssegnaUtenti, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    db.query(UtenteCategoria).filter(UtenteCategoria.categoria_id == categoria_id).delete()
    for uid in data.utente_ids:
        db.add(UtenteCategoria(utente_id=uid, categoria_id=categoria_id))
    db.commit()
    return {"ok": True}

@router.post("/importa-giocatori/{nuova_categoria_id}")
def importa_giocatori(nuova_categoria_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    nuova_cat = db.query(models.Categoria).filter(models.Categoria.id == nuova_categoria_id).first()
    if not nuova_cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    
    if nuova_cat.is_portieri:
        vecchie = db.query(models.Categoria).filter(
            models.Categoria.is_portieri == 1,
            models.Categoria.is_archiviata == 1,
            models.Categoria.id != nuova_categoria_id
        ).all()
    else:
        vecchie = db.query(models.Categoria).filter(
            models.Categoria.anno == nuova_cat.anno,
            models.Categoria.is_portieri == 0,
            models.Categoria.is_archiviata == 1,
            models.Categoria.id != nuova_categoria_id
        ).all()
    
    if not vecchie:
        return {"ok": True, "giocatori_importati": 0, "messaggio": "Nessuna categoria precedente trovata"}
    
    vecchia_cat = vecchie[0]
    giocatori = db.query(models.Persona).filter(
        models.Persona.categoria_id == vecchia_cat.id
    ).all()
    
    importati = 0
    for g in giocatori:
        nuovo_giocatore = models.Persona(
            nome=g.nome,
            cognome=g.cognome,
            categoria_id=nuova_categoria_id,
            gruppo_id=g.gruppo_id,
            gruppo_nome=g.gruppo_nome
        )
        db.add(nuovo_giocatore)
        importati += 1
    
    db.commit()
    return {
        "ok": True, 
        "giocatori_importati": importati,
        "messaggio": f"Importati {importati} giocatori dalla categoria '{vecchia_cat.nome}'"
    }
