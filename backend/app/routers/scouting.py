from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text, or_
from datetime import datetime, date
from typing import Optional, List
from pydantic import BaseModel

from ..database import get_db
from ..models import (
    ScoutingSegnalazione,
    ScoutingGiocatore,
    Categoria,
    Utente,
    UtenteCategoria,
    Convocazione,
    ConvocazioneGara,
)
from ..routers.auth import get_current_user, check_societa
from ..core.security import get_scouting

router = APIRouter(prefix="/scouting", tags=["scouting"])

STATI = {"inviata", "in_lavorazione", "completata"}
CAMPI_VALUTAZIONE = [
    "tecnica",
    "velocita",
    "resistenza",
    "attitudine",
    "posizione",
    "gioco_di_testa",
    "tiro",
    "passaggio",
    "dribbling",
    "disciplina",
]


class GiocatoreScoutingBase(BaseModel):
    id: Optional[int] = None
    nome: Optional[str] = None
    cognome: Optional[str] = None
    squadra: Optional[str] = None
    ruolo: Optional[str] = None
    numero_maglia: Optional[int] = None
    tecnica: Optional[int] = None
    velocita: Optional[int] = None
    resistenza: Optional[int] = None
    attitudine: Optional[int] = None
    posizione: Optional[int] = None
    gioco_di_testa: Optional[int] = None
    tiro: Optional[int] = None
    passaggio: Optional[int] = None
    dribbling: Optional[int] = None
    disciplina: Optional[int] = None
    note: Optional[str] = None


class SegnalazioneCreate(BaseModel):
    categoria_id: int
    convocazione_id: Optional[int] = None
    gara_id: Optional[int] = None
    titolo: Optional[str] = None
    data_osservazione: Optional[date] = None
    squadra_avversaria: Optional[str] = None
    note: Optional[str] = None
    giocatori: List[GiocatoreScoutingBase] = []


class SegnalazioneUpdate(BaseModel):
    convocazione_id: Optional[int] = None
    gara_id: Optional[int] = None
    titolo: Optional[str] = None
    data_osservazione: Optional[date] = None
    squadra_avversaria: Optional[str] = None
    note: Optional[str] = None
    stato: Optional[str] = None
    giocatori: Optional[List[GiocatoreScoutingBase]] = None


class StatoUpdate(BaseModel):
    stato: str


def _get_categoria_societa(db: Session, categoria_id: int, user: Utente) -> int:
    row = db.execute(
        text("SELECT societa_id FROM categorie WHERE id = :id"),
        {"id": categoria_id},
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    if not user.is_super_admin:
        check_societa(user, row.societa_id)
    return row.societa_id


def _is_mister_categoria(db: Session, user: Utente, categoria_id: int) -> bool:
    if user.is_admin or user.is_super_admin:
        return True
    row = db.execute(
        text("SELECT ruolo FROM utente_categorie WHERE utente_id = :uid AND categoria_id = :cid"),
        {"uid": user.id, "cid": categoria_id},
    ).fetchone()
    return bool(row and row.ruolo == "mister")


def _can_modify(user: Utente, seg: ScoutingSegnalazione) -> bool:
    if user.is_super_admin or user.is_admin:
        return True
    if user.societa_id != seg.societa_id:
        return False
    if user.ruolo == "scouting":
        return True
    if user.ruolo == "mister" and seg.autore_id == user.id:
        return True
    return False


def _can_valutare(user: Utente, seg: ScoutingSegnalazione) -> bool:
    if user.is_super_admin or user.is_admin:
        return True
    return user.ruolo == "scouting" and user.societa_id == seg.societa_id


def _serialize_giocatore(g: ScoutingGiocatore) -> dict:
    return {
        "id": g.id,
        "nome": g.nome,
        "cognome": g.cognome,
        "squadra": g.squadra,
        "ruolo": g.ruolo,
        "numero_maglia": g.numero_maglia,
        "ordine": g.ordine or 0,
        "tecnica": g.tecnica,
        "velocita": g.velocita,
        "resistenza": g.resistenza,
        "attitudine": g.attitudine,
        "posizione": g.posizione,
        "gioco_di_testa": g.gioco_di_testa,
        "tiro": g.tiro,
        "passaggio": g.passaggio,
        "dribbling": g.dribbling,
        "disciplina": g.disciplina,
        "note": g.note,
        "valutato_il": g.valutato_il.isoformat() if g.valutato_il else None,
    }


def _serialize_segnalazione(db: Session, seg: ScoutingSegnalazione) -> dict:
    categoria = db.get(Categoria, seg.categoria_id) if seg.categoria_id else None
    autore = db.get(Utente, seg.autore_id) if seg.autore_id else None
    convocazione = db.get(Convocazione, seg.convocazione_id) if seg.convocazione_id else None
    gara = db.get(ConvocazioneGara, seg.gara_id) if seg.gara_id else None
    giocatori = (
        db.query(ScoutingGiocatore)
        .filter(ScoutingGiocatore.segnalazione_id == seg.id)
        .order_by(ScoutingGiocatore.ordine, ScoutingGiocatore.id)
        .all()
    )
    return {
        "id": seg.id,
        "societa_id": seg.societa_id,
        "categoria_id": seg.categoria_id,
        "categoria_nome": categoria.nome if categoria else None,
        "categoria_anno": getattr(categoria, "anno", None) if categoria else None,
        "convocazione_id": seg.convocazione_id,
        "gara_id": seg.gara_id,
        "gara_nome": gara.gara if gara else None,
        "data_gara": gara.data.isoformat() if gara and gara.data else None,
        "autore_id": seg.autore_id,
        "autore_nome": f"{autore.cognome or ''} {autore.nome or ''}".strip() if autore else None,
        "titolo": seg.titolo,
        "data_osservazione": seg.data_osservazione.isoformat() if seg.data_osservazione else None,
        "squadra_avversaria": seg.squadra_avversaria,
        "note": seg.note,
        "stato": seg.stato,
        "creato_il": seg.creato_il.isoformat() if seg.creato_il else None,
        "aggiornato_il": seg.aggiornato_il.isoformat() if seg.aggiornato_il else None,
        "giocatori": [_serialize_giocatore(g) for g in giocatori],
    }


def _verifica_convocazione(db: Session, user: Utente, convocazione_id: Optional[int], categoria_id: int):
    if not convocazione_id:
        return
    conv = db.get(Convocazione, convocazione_id)
    if not conv or conv.categoria_id != categoria_id:
        raise HTTPException(status_code=400, detail="Convocazione non valida per la categoria")
    if not user.is_super_admin:
        check_societa(user, conv.societa_id)


def _verifica_gara(db: Session, gara_id: Optional[int], convocazione_id: Optional[int]):
    if not gara_id:
        return
    gara = db.get(ConvocazioneGara, gara_id)
    if not gara:
        raise HTTPException(status_code=400, detail="Gara non trovata")
    if convocazione_id and gara.convocazione_id != convocazione_id:
        raise HTTPException(status_code=400, detail="Gara non valida per la convocazione")


def _applica_giocatore(dest: ScoutingGiocatore, src: GiocatoreScoutingBase, can_valutare: bool):
    if src.nome is not None:
        dest.nome = src.nome
    if src.cognome is not None:
        dest.cognome = src.cognome
    if src.squadra is not None:
        dest.squadra = src.squadra
    if src.ruolo is not None:
        dest.ruolo = src.ruolo
    if src.numero_maglia is not None:
        dest.numero_maglia = src.numero_maglia
    if can_valutare:
        for campo in CAMPI_VALUTAZIONE:
            valore = getattr(src, campo)
            if valore is not None:
                setattr(dest, campo, valore)
        if src.note is not None:
            dest.note = src.note
        if any(getattr(src, campo) is not None for campo in CAMPI_VALUTAZIONE) or src.note is not None:
            dest.valutato_il = datetime.utcnow()


@router.get("/segnalazioni")
def lista_segnalazioni(
    stato: Optional[str] = None,
    categoria_id: Optional[int] = None,
    q: Optional[str] = None,
    db: Session = Depends(get_db),
    user: Utente = Depends(get_current_user),
):
    query = db.query(ScoutingSegnalazione)
    if user.is_super_admin:
        pass
    elif user.is_admin or user.ruolo == "scouting":
        query = query.filter(ScoutingSegnalazione.societa_id == user.societa_id)
    else:
        query = query.filter(ScoutingSegnalazione.autore_id == user.id)

    if stato:
        query = query.filter(ScoutingSegnalazione.stato == stato)
    if categoria_id:
        query = query.filter(ScoutingSegnalazione.categoria_id == categoria_id)
    if q:
        pattern = f"%{q}%"
        player_sub = (
            db.query(ScoutingGiocatore.segnalazione_id)
            .filter(
                or_(
                    ScoutingGiocatore.nome.ilike(pattern),
                    ScoutingGiocatore.cognome.ilike(pattern),
                    ScoutingGiocatore.squadra.ilike(pattern),
                )
            )
            .subquery()
        )
        query = query.filter(
            or_(
                ScoutingSegnalazione.titolo.ilike(pattern),
                ScoutingSegnalazione.squadra_avversaria.ilike(pattern),
                ScoutingSegnalazione.id.in_(player_sub),
            )
        )

    segnalazioni = query.order_by(ScoutingSegnalazione.creato_il.desc(), ScoutingSegnalazione.id.desc()).all()
    return [_serialize_segnalazione(db, s) for s in segnalazioni if _can_modify(user, s)]


@router.get("/segnalazioni/{segnalazione_id}")
def dettaglio_segnalazione(
    segnalazione_id: int,
    db: Session = Depends(get_db),
    user: Utente = Depends(get_current_user),
):
    seg = db.get(ScoutingSegnalazione, segnalazione_id)
    if not seg:
        raise HTTPException(status_code=404, detail="Segnalazione non trovata")
    if not _can_modify(user, seg):
        raise HTTPException(status_code=403, detail="Non autorizzato")
    return _serialize_segnalazione(db, seg)


@router.post("/segnalazioni")
def crea_segnalazione(
    data: SegnalazioneCreate,
    db: Session = Depends(get_db),
    user: Utente = Depends(get_current_user),
):
    societa_id = _get_categoria_societa(db, data.categoria_id, user)
    if not _is_mister_categoria(db, user, data.categoria_id):
        raise HTTPException(status_code=403, detail="Solo il mister della categoria può creare segnalazioni")
    _verifica_convocazione(db, user, data.convocazione_id, data.categoria_id)
    _verifica_gara(db, data.gara_id, data.convocazione_id)

    now = datetime.utcnow()
    seg = ScoutingSegnalazione(
        societa_id=societa_id,
        categoria_id=data.categoria_id,
        convocazione_id=data.convocazione_id,
        gara_id=data.gara_id,
        autore_id=user.id,
        titolo=data.titolo,
        data_osservazione=data.data_osservazione,
        squadra_avversaria=data.squadra_avversaria,
        note=data.note,
        stato="inviata",
        creato_il=now,
        aggiornato_il=now,
    )
    db.add(seg)
    db.flush()
    for idx, g in enumerate(data.giocatori):
        db.add(
            ScoutingGiocatore(
                segnalazione_id=seg.id,
                nome=g.nome,
                cognome=g.cognome,
                squadra=g.squadra,
                ruolo=g.ruolo,
                numero_maglia=g.numero_maglia,
                ordine=idx,
            )
        )
    db.commit()
    db.refresh(seg)
    return _serialize_segnalazione(db, seg)


@router.put("/segnalazioni/{segnalazione_id}")
def modifica_segnalazione(
    segnalazione_id: int,
    data: SegnalazioneUpdate,
    db: Session = Depends(get_db),
    user: Utente = Depends(get_current_user),
):
    seg = db.get(ScoutingSegnalazione, segnalazione_id)
    if not seg:
        raise HTTPException(status_code=404, detail="Segnalazione non trovata")
    if not _can_modify(user, seg):
        raise HTTPException(status_code=403, detail="Non autorizzato")

    if data.stato is not None:
        if data.stato not in STATI:
            raise HTTPException(status_code=400, detail="Stato non valido")
        if not _can_valutare(user, seg):
            raise HTTPException(status_code=403, detail="Solo scouting/admin può cambiare lo stato")
        seg.stato = data.stato

    _verifica_convocazione(db, user, data.convocazione_id if data.convocazione_id is not None else seg.convocazione_id, seg.categoria_id)
    _verifica_gara(db, data.gara_id if data.gara_id is not None else seg.gara_id, data.convocazione_id if data.convocazione_id is not None else seg.convocazione_id)

    if data.convocazione_id is not None:
        seg.convocazione_id = data.convocazione_id
    if data.gara_id is not None:
        seg.gara_id = data.gara_id
    if data.titolo is not None:
        seg.titolo = data.titolo
    if data.data_osservazione is not None:
        seg.data_osservazione = data.data_osservazione
    if data.squadra_avversaria is not None:
        seg.squadra_avversaria = data.squadra_avversaria
    if data.note is not None:
        seg.note = data.note

    if data.giocatori is not None:
        esistenti = {
            g.id: g
            for g in db.query(ScoutingGiocatore).filter(ScoutingGiocatore.segnalazione_id == seg.id).all()
        }
        mantenuti = []
        for idx, g in enumerate(data.giocatori):
            if g.id and g.id in esistenti:
                giocatore = esistenti.pop(g.id)
                _applica_giocatore(giocatore, g, _can_valutare(user, seg))
                giocatore.ordine = idx
            else:
                giocatore = ScoutingGiocatore(
                    segnalazione_id=seg.id,
                    nome=g.nome,
                    cognome=g.cognome,
                    squadra=g.squadra,
                    ruolo=g.ruolo,
                    numero_maglia=g.numero_maglia,
                    ordine=idx,
                )
                if _can_valutare(user, seg):
                    _applica_giocatore(giocatore, g, True)
                db.add(giocatore)
                db.flush()
            mantenuti.append(giocatore.id)
        for giocatore in esistenti.values():
            db.delete(giocatore)

    seg.aggiornato_il = datetime.utcnow()
    db.commit()
    db.refresh(seg)
    return _serialize_segnalazione(db, seg)


@router.delete("/segnalazioni/{segnalazione_id}")
def elimina_segnalazione(
    segnalazione_id: int,
    db: Session = Depends(get_db),
    user: Utente = Depends(get_current_user),
):
    seg = db.get(ScoutingSegnalazione, segnalazione_id)
    if not seg:
        raise HTTPException(status_code=404, detail="Segnalazione non trovata")
    if not _can_modify(user, seg):
        raise HTTPException(status_code=403, detail="Non autorizzato")
    db.delete(seg)
    db.commit()
    return {"status": "ok"}


@router.put("/segnalazioni/{segnalazione_id}/stato")
def cambia_stato(
    segnalazione_id: int,
    data: StatoUpdate,
    db: Session = Depends(get_db),
    user: Utente = Depends(get_scouting),
):
    if data.stato not in STATI:
        raise HTTPException(status_code=400, detail="Stato non valido")
    seg = db.get(ScoutingSegnalazione, segnalazione_id)
    if not seg:
        raise HTTPException(status_code=404, detail="Segnalazione non trovata")
    check_societa(user, seg.societa_id)
    seg.stato = data.stato
    seg.aggiornato_il = datetime.utcnow()
    db.commit()
    return _serialize_segnalazione(db, seg)


@router.put("/giocatori/{giocatore_id}")
def valuta_giocatore(
    giocatore_id: int,
    data: GiocatoreScoutingBase,
    db: Session = Depends(get_db),
    user: Utente = Depends(get_scouting),
):
    giocatore = db.get(ScoutingGiocatore, giocatore_id)
    if not giocatore:
        raise HTTPException(status_code=404, detail="Giocatore non trovato")
    seg = db.get(ScoutingSegnalazione, giocatore.segnalazione_id)
    if not seg:
        raise HTTPException(status_code=404, detail="Segnalazione non trovata")
    check_societa(user, seg.societa_id)
    for campo in CAMPI_VALUTAZIONE:
        setattr(giocatore, campo, getattr(data, campo))
    giocatore.note = data.note
    if any(getattr(data, campo) is not None for campo in CAMPI_VALUTAZIONE) or data.note:
        giocatore.valutato_il = datetime.utcnow()
    db.commit()
    db.refresh(giocatore)
    return _serialize_giocatore(giocatore)
