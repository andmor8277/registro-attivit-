from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional, List
from datetime import date

from app.models import Utente, Torneo, TorneoGara, ListaTorneo, Categoria
from app.database import get_db
from app.routers.auth import get_current_user
from app.core.deps import get_societa_filter, resolve_tenant_societa_id

router = APIRouter(prefix="/tornei", tags=["tornei"])


class TorneoIn(BaseModel):
    nome: str
    categoria_id: int
    societa_id: Optional[int] = None
    data_inizio: Optional[date] = None
    data_fine: Optional[date] = None
    luogo: Optional[str] = None
    organizzatore: Optional[str] = None
    descrizione: Optional[str] = None


class GaraIn(BaseModel):
    numero: Optional[int] = None
    avversario: Optional[str] = None
    data: Optional[date] = None
    ora: Optional[str] = None
    ora_appuntamento: Optional[str] = None
    campo: Optional[str] = None
    indirizzo: Optional[str] = None
    note: Optional[str] = None


def get_responsabile_tornei(current_user: Utente = Depends(get_current_user)):
    """Chi gestisce i tornei: gli admin della societa' e i super admin.

    Non riusa get_admin di core.security perche' quel controllo guarda solo is_admin: un
    super_admin con is_admin=0 resterebbe fuori da una funzione che per definizione gli spetta.
    E' lo stesso criterio gia' usato da GET /liste-torneo/{id}/giocatori per decidere chi vede
    i dati sensibili.
    """
    if not (current_user.is_admin or current_user.is_super_admin):
        raise HTTPException(status_code=403, detail="Solo il responsabile puo' creare o modificare i tornei")
    return current_user


def _get_torneo(torneo_id: int, current_user: Utente, db: Session) -> Torneo:
    """Carica il torneo e verifica che appartenga alla societa' di chi chiede.

    Il filtro di societa' va fatto qui e non solo nella lista: conoscere l'id di un torneo di
    un'altra societa' (sono sequenziali) non deve dare accesso ne' al calendario ne' alla
    modifica.
    """
    torneo = db.query(Torneo).filter(Torneo.id == torneo_id).first()
    if not torneo:
        raise HTTPException(status_code=404, detail="Torneo non trovato")
    sid = get_societa_filter(current_user)
    if sid and torneo.societa_id != sid:
        raise HTTPException(status_code=403, detail="Non autorizzato su questo torneo")
    return torneo


def _valida(data: TorneoIn, current_user: Utente, db: Session) -> None:
    if not (data.nome or "").strip():
        raise HTTPException(status_code=400, detail="Il nome del torneo e' obbligatorio")
    if data.data_inizio and data.data_fine and data.data_fine < data.data_inizio:
        raise HTTPException(status_code=400, detail="La data di fine non puo' precedere quella di inizio")
    cat = db.query(Categoria).filter(Categoria.id == data.categoria_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    sid = get_societa_filter(current_user)
    if sid and cat.societa_id != sid:
        raise HTTPException(status_code=403, detail="Non autorizzato su questa categoria")


def _serie_gare(torneo_id: int, db: Session) -> List[dict]:
    righe = db.execute(text("""
        SELECT id, numero, avversario, data, ora, ora_appuntamento, campo, indirizzo, note
        FROM tornei_gare WHERE torneo_id = :tid
        ORDER BY data NULLS LAST, ora NULLS LAST, numero NULLS LAST, id
    """), {"tid": torneo_id}).fetchall()
    gare = []
    for r in righe:
        d = dict(r._mapping)
        # serializzate a mano: date.isoformat() e le stringhe "HH:MM" arrivano al frontend cosi'
        # come sono state inserite, senza fusi orari di mezzo
        d["data"] = d["data"].isoformat() if d.get("data") else None
        gare.append(d)
    return gare


def _lista_collegata(torneo_id: int, db: Session) -> Optional[dict]:
    r = db.execute(text(
        "SELECT id, nome FROM liste_torneo WHERE torneo_id = :tid"
    ), {"tid": torneo_id}).fetchone()
    if not r:
        return None
    d = dict(r._mapping)
    d["giocatori"] = db.execute(text(
        "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id = :lid"
    ), {"lid": d["id"]}).scalar() or 0
    return d


@router.get("/")
def lista_tornei(
    categoria_id: Optional[int] = None,
    societa_id: Optional[int] = Query(None),
    da: Optional[date] = None,
    a: Optional[date] = None,
    request: Request = None,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    """I tornei della societa' di chi chiede.

    Nessun filtro per utente_categorie: il 2026-11-16 il titolare ha deciso che i mister vedono
    e usano legittimamente tutte le categorie della propria societa' (la lista in Scelta.vue viene
    da GET /categorie/by-stagione, che filtra solo per societa'), avendo in media una sola riga di
    assegnazione. Filtrare qui per assegnazione li terrebbe fuori dai tornei della loro societa'.
    """
    sid = get_societa_filter(current_user, societa_id, request)
    query = db.query(Torneo)
    if sid:
        query = query.filter(Torneo.societa_id == sid)
    if categoria_id:
        query = query.filter(Torneo.categoria_id == categoria_id)
    if da:
        # .bindparams perche' Query.filter() accetta solo espressioni: passare il dizionario dei
        # parametri come secondo argomento solleverebbe TypeError
        query = query.filter(text(
            "(tornei.data_fine >= :da OR (tornei.data_fine IS NULL AND tornei.data_inizio >= :da))"
        ).bindparams(da=da))
    if a:
        query = query.filter(text(
            "(tornei.data_inizio <= :a OR tornei.data_inizio IS NULL)"
        ).bindparams(a=a))

    risultati = []
    for t in query.order_by(Torneo.data_inizio.desc().nullslast(), Torneo.id.desc()).all():
        risultati.append({
            "id": t.id,
            "nome": t.nome,
            "categoria_id": t.categoria_id,
            "societa_id": t.societa_id,
            "data_inizio": t.data_inizio.isoformat() if t.data_inizio else None,
            "data_fine": t.data_fine.isoformat() if t.data_fine else None,
            "luogo": t.luogo,
            "organizzatore": t.organizzatore,
            "descrizione": t.descrizione,
            "gare": db.execute(text(
                "SELECT count(*) FROM tornei_gare WHERE torneo_id = :tid"), {"tid": t.id}).scalar() or 0,
            "lista": _lista_collegata(t.id, db),
        })
    return risultati


@router.get("/{torneo_id}")
def dettaglio_torneo(torneo_id: int, db: Session = Depends(get_db),
                     current_user: Utente = Depends(get_current_user)):
    torneo = _get_torneo(torneo_id, current_user, db)
    return {
        "id": torneo.id,
        "nome": torneo.nome,
        "categoria_id": torneo.categoria_id,
        "societa_id": torneo.societa_id,
        "data_inizio": torneo.data_inizio.isoformat() if torneo.data_inizio else None,
        "data_fine": torneo.data_fine.isoformat() if torneo.data_fine else None,
        "luogo": torneo.luogo,
        "organizzatore": torneo.organizzatore,
        "descrizione": torneo.descrizione,
        "gare": _serie_gare(torneo_id, db),
        "lista": _lista_collegata(torneo_id, db),
    }


@router.post("/")
def crea_torneo(data: TorneoIn, request: Request = None, db: Session = Depends(get_db),
                current_user: Utente = Depends(get_responsabile_tornei)):
    _valida(data, current_user, db)
    societa_id = resolve_tenant_societa_id(current_user, data.societa_id, request,
                                           categoria_id=data.categoria_id, db=db)
    torneo = Torneo(
        societa_id=societa_id,
        categoria_id=data.categoria_id,
        nome=data.nome.strip(),
        data_inizio=data.data_inizio,
        data_fine=data.data_fine,
        luogo=data.luogo,
        organizzatore=data.organizzatore,
        descrizione=data.descrizione,
        creato_da=current_user.id,
        creato_il=text("NOW()"),
    )
    db.add(torneo)
    db.flush()  # serve l'id prima di creare la lista che lo referenzia

    # La Lista Tornei nasce insieme al torneo, non la deve creare il mister: il "file con la
    # lista bloccata" e' il documento che l'organizzatore aspetta, e se dipende da un passaggio
    # manuale del mister resta semplicemente senza (in liste_torneo c'era UNA lista in tutto).
    # Stesso nome, stessa categoria, stessa societa': il mister la trova gia' in Liste Tornei.
    lista = ListaTorneo(
        nome=torneo.nome,
        categoria_id=torneo.categoria_id,
        societa_id=torneo.societa_id,
        creato_il=text("NOW()"),
        torneo_id=torneo.id,
    )
    db.add(lista)
    db.commit()
    db.refresh(torneo)
    db.refresh(lista)
    return {"id": torneo.id, "nome": torneo.nome, "lista_id": lista.id}


@router.put("/{torneo_id}")
def aggiorna_torneo(torneo_id: int, data: TorneoIn, db: Session = Depends(get_db),
                    current_user: Utente = Depends(get_responsabile_tornei)):
    torneo = _get_torneo(torneo_id, current_user, db)
    _valida(data, current_user, db)
    torneo.nome = data.nome.strip()
    torneo.categoria_id = data.categoria_id
    torneo.data_inizio = data.data_inizio
    torneo.data_fine = data.data_fine
    torneo.luogo = data.luogo
    torneo.organizzatore = data.organizzatore
    torneo.descrizione = data.descrizione
    # La lista collegata porta il nome del torneo: se il responsabile lo corregge, la lista
    # non deve restare con il nome vecchio, perche' quel nome finisce nell'intestazione del PDF
    db.execute(text("UPDATE liste_torneo SET nome = :n WHERE torneo_id = :t"),
               {"n": torneo.nome, "t": torneo.id})
    db.commit()
    return {"ok": True}


@router.delete("/{torneo_id}")
def elimina_torneo(torneo_id: int, db: Session = Depends(get_db),
                   current_user: Utente = Depends(get_responsabile_tornei)):
    torneo = _get_torneo(torneo_id, current_user, db)
    # La lista creata col torneo se ne va con lui: senza il torneo non e' piu' la lista di
    # niente, e lasciarla in Liste Tornei significherebbe esportare un file per un torneo che
    # non esiste piu'. Le liste create a mano (torneo_id NULL) non sono toccate.
    ids_liste = [r[0] for r in db.execute(text(
        "SELECT id FROM liste_torneo WHERE torneo_id = :t"), {"t": torneo_id}).fetchall()]
    for lid in ids_liste:
        db.execute(text("DELETE FROM liste_torneo_giocatori WHERE lista_id = :l"), {"l": lid})
        db.execute(text("DELETE FROM liste_torneo WHERE id = :l"), {"l": lid})
    db.execute(text("DELETE FROM tornei_gare WHERE torneo_id = :t"), {"t": torneo_id})
    db.delete(torneo)
    db.commit()
    return {"ok": True, "liste_eliminate": len(ids_liste)}


@router.post("/{torneo_id}/gare")
def aggiungi_gara(torneo_id: int, data: GaraIn, db: Session = Depends(get_db),
                  current_user: Utente = Depends(get_responsabile_tornei)):
    _get_torneo(torneo_id, current_user, db)
    if not any([(data.avversario or "").strip(), (data.campo or "").strip(),
                (data.note or "").strip(), data.data]):
        raise HTTPException(status_code=400, detail="La gara deve avere almeno un avversario, un campo o una data")
    if data.numero is None:
        data.numero = (db.execute(text(
            "SELECT COALESCE(MAX(numero), 0) FROM tornei_gare WHERE torneo_id = :t"),
            {"t": torneo_id}).scalar() or 0) + 1
    gara = TorneoGara(torneo_id=torneo_id, **data.model_dump())
    db.add(gara)
    db.commit()
    db.refresh(gara)
    return {"id": gara.id, "numero": gara.numero}


@router.put("/{torneo_id}/gare/{gara_id}")
def modifica_gara(torneo_id: int, gara_id: int, data: GaraIn, db: Session = Depends(get_db),
                  current_user: Utente = Depends(get_responsabile_tornei)):
    _get_torneo(torneo_id, current_user, db)
    # La verifica che la gara sia di QUESTO torneo va fatta perche' l'id della gara arriva
    # dall'URL: senza il doppio vincolo si potrebbe modificare la gara di un altro torneo
    # passando il suo id insieme all'id di un torneo legittimo
    gara = db.query(TorneoGara).filter(TorneoGara.id == gara_id,
                                       TorneoGara.torneo_id == torneo_id).first()
    if not gara:
        raise HTTPException(status_code=404, detail="Gara non trovata in questo torneo")
    for k, v in data.model_dump().items():
        setattr(gara, k, v)
    db.commit()
    return {"ok": True}


@router.delete("/{torneo_id}/gare/{gara_id}")
def elimina_gara(torneo_id: int, gara_id: int, db: Session = Depends(get_db),
                 current_user: Utente = Depends(get_responsabile_tornei)):
    _get_torneo(torneo_id, current_user, db)
    n = db.execute(text("DELETE FROM tornei_gare WHERE id = :g AND torneo_id = :t"),
                   {"g": gara_id, "t": torneo_id}).rowcount
    db.commit()
    if not n:
        raise HTTPException(status_code=404, detail="Gara non trovata in questo torneo")
    return {"ok": True}
