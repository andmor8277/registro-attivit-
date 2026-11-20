from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional, List
from datetime import date

from app.models import Utente, Torneo, TorneoCategoria, TorneoGara, ListaTorneo, Categoria
from app.database import get_db
from app.routers.auth import get_current_user
from app.core.deps import get_societa_filter, resolve_tenant_societa_id

router = APIRouter(prefix="/tornei", tags=["tornei"])


class TorneoIn(BaseModel):
    nome: str
    # Le categorie iscritte. `categoria_id` resta per compatibilita' (e' la "prima", quella del
    # badge e dell'ingresso da Scelta.vue), ma la fonte di verita' sono le iscrizioni.
    categorie_id: Optional[List[int]] = None
    categoria_id: Optional[int] = None
    societa_id: Optional[int] = None
    data_inizio: Optional[date] = None
    data_fine: Optional[date] = None
    luogo: Optional[str] = None
    organizzatore: Optional[str] = None
    descrizione: Optional[str] = None


class CategorieIn(BaseModel):
    categoria_id: int


class GaraIn(BaseModel):
    categoria_id: Optional[int] = None
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


def _richiedi_categorie(data: TorneoIn) -> List[int]:
    """Le categorie richieste dal payload, deduplicate e nell'ordine in cui arrivano.

    `categorie_id` e' la strada nuova; `categoria_id` resta per chi la manda ancora (il frontend
    vecchio e i test gia' scritti). Accettarle entrambe senza confonderle e' il prezzo di non
    rompere niente in mezzo al deploy.
    """
    ids: List[int] = []
    for c in (data.categorie_id or []):
        if c and int(c) not in ids:
            ids.append(int(c))
    if data.categoria_id and int(data.categoria_id) not in ids:
        ids.append(int(data.categoria_id))
    return ids


def _valida(data: TorneoIn, current_user: Utente, db: Session) -> List[int]:
    if not (data.nome or "").strip():
        raise HTTPException(status_code=400, detail="Il nome del torneo e' obbligatorio")
    if data.data_inizio and data.data_fine and data.data_fine < data.data_inizio:
        raise HTTPException(status_code=400, detail="La data di fine non puo' precedere quella di inizio")
    categorie = _richiedi_categorie(data)
    if not categorie:
        raise HTTPException(status_code=400, detail="Seleziona almeno una categoria")
    sid = get_societa_filter(current_user)
    for cid in categorie:
        cat = db.query(Categoria).filter(Categoria.id == cid).first()
        if not cat:
            raise HTTPException(status_code=404, detail="Categoria non trovata")
        if sid and cat.societa_id != sid:
            raise HTTPException(status_code=403, detail="Non autorizzato su questa categoria")
    return categorie


def _categorie_iscritte(torneo_id: int, db: Session) -> List[dict]:
    """Le categorie iscritte al torneo, ordinate per anno come le sezioni del weekend."""
    righe = db.execute(text("""
        SELECT c.id, c.nome, c.anno
        FROM tornei_categorie tc
        JOIN categorie c ON c.id = tc.categoria_id
        WHERE tc.torneo_id = :tid
        ORDER BY c.anno ASC NULLS LAST, c.nome ASC
    """), {"tid": torneo_id}).fetchall()
    return [dict(r._mapping) for r in righe]


def _etichetta_categoria(cat: dict) -> str:
    return f"{cat['anno']} - {cat['nome']}" if cat.get("anno") else (cat.get("nome") or "categoria")


def _dati_categoria(cat) -> dict:
    """Una categoria come dizionario {id, nome, anno}, da un'istanza ORM o da una Row.

    Serve perche' le due strade sono diverse e scambiarle costa un 500: le query con text()
    restituiscono Row, che ha ._mapping, mentre un oggetto db.query(Categoria).first() non ce
    l'ha proprio. Qui si leggono i tre campi che servono al nome del foglio, e il resto del
    router lavora solo con dizionari.
    """
    if isinstance(cat, dict):
        return {"id": cat["id"], "nome": cat.get("nome"), "anno": cat.get("anno")}
    if hasattr(cat, "_mapping"):
        cat = dict(cat._mapping)
        return {"id": cat["id"], "nome": cat.get("nome"), "anno": cat.get("anno")}
    return {"id": cat.id, "nome": cat.nome, "anno": cat.anno}


def _serie_gare(torneo_id: int, db: Session) -> List[dict]:
    """Il calendario, con la categoria di ogni gara.

    L'ordinamento e' quello di GET /weekend/{id}/partite: prima la categoria per anno, poi la data
    e l'ora dentro la categoria. E' cio' che permette al frontend di raggruppare a sezioni senza
    doversi inventare l'ordine, e rende il calendario di un torneo leggibile come quello del weekend.
    """
    righe = db.execute(text("""
        SELECT g.id, g.categoria_id, g.numero, g.avversario, g.data, g.ora,
               g.ora_appuntamento, g.campo, g.indirizzo, g.note,
               c.nome AS categoria_nome, c.anno AS categoria_anno
        FROM tornei_gare g
        LEFT JOIN categorie c ON c.id = g.categoria_id
        WHERE g.torneo_id = :tid
        ORDER BY c.anno ASC NULLS LAST, c.nome ASC NULLS LAST,
                 g.data NULLS LAST, g.ora NULLS LAST, g.numero NULLS LAST, g.id
    """), {"tid": torneo_id}).fetchall()
    gare = []
    for r in righe:
        d = dict(r._mapping)
        # serializzate a mano: date.isoformat() e le stringhe "HH:MM" arrivano al frontend cosi'
        # come sono state inserite, senza fusi orari di mezzo
        d["data"] = d["data"].isoformat() if d.get("data") else None
        gare.append(d)
    return gare


def _nome_lista(torneo_nome: str, cat: dict) -> str:
    """Il nome del foglio da consegnare: torneo + categoria.

    L'organizzatore riceve un foglio per categoria, e due fogli che si chiamano entrambi "Winter
    Cup" non gli dicono quali sono i Pulcini e quali gli Esordienti. Il nome finisce nell'intestazione
    del PDF, quindi si costruisce una volta sola, allo stesso modo per tutti.
    """
    return f"{torneo_nome} - {_etichetta_categoria(cat)}"


def _liste_collegate(torneo_id: int, db: Session) -> List[dict]:
    """I fogli giocatori del torneo, uno per categoria iscritta."""
    righe = db.execute(text("""
        SELECT l.id, l.nome, l.categoria_id, c.nome AS categoria_nome, c.anno AS categoria_anno
        FROM liste_torneo l
        LEFT JOIN categorie c ON c.id = l.categoria_id
        WHERE l.torneo_id = :tid
        ORDER BY c.anno ASC NULLS LAST, c.nome ASC
    """), {"tid": torneo_id}).fetchall()
    liste = []
    for r in righe:
        d = dict(r._mapping)
        d["giocatori"] = db.execute(text(
            "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id = :lid"
        ), {"lid": d["id"]}).scalar() or 0
        liste.append(d)
    return liste


def _lista_collegata(torneo_id: int, db: Session, categoria_id=None) -> Optional[dict]:
    """Il foglio della categoria principale, per chi legge ancora il campo `lista` di una volta."""
    liste = _liste_collegate(torneo_id, db)
    if categoria_id:
        for l in liste:
            if l["categoria_id"] == categoria_id:
                return l
    return liste[0] if liste else None


def _crea_lista_del_torneo(torneo: Torneo, cat: dict, db: Session) -> int:
    """Crea il foglio giocatori di una categoria iscritta, se non c'e' gia'.

    Non e' un dettaglio di comodita': se la lista dipende da un passaggio manuale del mister resta
    semplicemente senza (in liste_torneo c'era UNA lista in tutto, in due anni). Per questo nasce
    nello stesso transaction dell'iscrizione, non dopo.
    """
    esiste = db.execute(text(
        "SELECT id FROM liste_torneo WHERE torneo_id = :t AND categoria_id = :c"
    ), {"t": torneo.id, "c": cat["id"]}).fetchone()
    if esiste:
        return esiste[0]
    lista = ListaTorneo(
        nome=_nome_lista(torneo.nome, cat),
        categoria_id=cat["id"],
        societa_id=torneo.societa_id,
        creato_il=text("NOW()"),
        torneo_id=torneo.id,
    )
    db.add(lista)
    db.flush()
    return lista.id


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
        # Il filtro guarda le ISCRIZIONI, non tornei.categoria_id: un torneo con tre categorie ha
        # in quella colonna solo la prima, e filtrando su quella i tornei sparirebbero dalla vista
        # del mister che cerca la sua.
        query = query.filter(text(
            "EXISTS (SELECT 1 FROM tornei_categorie tc WHERE tc.torneo_id = tornei.id "
            "AND tc.categoria_id = :cid)"
        ).bindparams(cid=categoria_id))
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
            "categorie": _categorie_iscritte(t.id, db),
            "societa_id": t.societa_id,
            "data_inizio": t.data_inizio.isoformat() if t.data_inizio else None,
            "data_fine": t.data_fine.isoformat() if t.data_fine else None,
            "luogo": t.luogo,
            "organizzatore": t.organizzatore,
            "descrizione": t.descrizione,
            "gare": db.execute(text(
                "SELECT count(*) FROM tornei_gare WHERE torneo_id = :tid"), {"tid": t.id}).scalar() or 0,
            "liste": _liste_collegate(t.id, db),
            "lista": _lista_collegata(t.id, db, t.categoria_id),
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
        "categorie": _categorie_iscritte(torneo_id, db),
        "societa_id": torneo.societa_id,
        "data_inizio": torneo.data_inizio.isoformat() if torneo.data_inizio else None,
        "data_fine": torneo.data_fine.isoformat() if torneo.data_fine else None,
        "luogo": torneo.luogo,
        "organizzatore": torneo.organizzatore,
        "descrizione": torneo.descrizione,
        "gare": _serie_gare(torneo_id, db),
        "liste": _liste_collegate(torneo_id, db),
        "lista": _lista_collegata(torneo_id, db, torneo.categoria_id),
    }


@router.post("/")
def crea_torneo(data: TorneoIn, request: Request = None, db: Session = Depends(get_db),
                current_user: Utente = Depends(get_responsabile_tornei)):
    categorie_ids = _valida(data, current_user, db)
    societa_id = resolve_tenant_societa_id(current_user, data.societa_id, request,
                                           categoria_id=categorie_ids[0], db=db)
    torneo = Torneo(
        societa_id=societa_id,
        categoria_id=categorie_ids[0],
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
    db.flush()  # serve l'id prima di creare iscrizioni e liste che lo referenziano

    # Un solo transaction per torneo + iscrizioni + fogli giocatori. Se i fogli restassero fuori
    # da qui dovrebbe crearli il mister, ed e' esattamente la strada che in due anni ha prodotto
    # una lista sola.
    liste = []
    for cid in categorie_ids:
        cat = db.query(Categoria).filter(Categoria.id == cid).first()
        db.add(TorneoCategoria(torneo_id=torneo.id, categoria_id=cid))
        db.flush()
        liste.append({"id": _crea_lista_del_torneo(torneo, _dati_categoria(cat), db),
                      "categoria_id": cid})
    db.commit()
    db.refresh(torneo)
    return {"id": torneo.id, "nome": torneo.nome, "categorie": categorie_ids, "liste": liste,
            "lista_id": liste[0]["id"] if liste else None}


@router.put("/{torneo_id}")
def aggiorna_torneo(torneo_id: int, data: TorneoIn, db: Session = Depends(get_db),
                    current_user: Utente = Depends(get_responsabile_tornei)):
    """Modifica i dati anagrafici del torneo. Le categorie NON si toccano qui.

    Cambiare le categorie nella stessa richiesta che rinomina il torneo darebbe un effetto
    collaterale invisibile: togliere un'iscrizione significa gestire il foglio giocatori di quella
    categoria, che puo' avere gia' dei giocatori dentro. Per quello esistono le rotte /categorie,
    che su quell'operazione hanno una regola loro.
    """
    torneo = _get_torneo(torneo_id, current_user, db)
    if not (data.nome or "").strip():
        raise HTTPException(status_code=400, detail="Il nome del torneo e' obbligatorio")
    if data.data_inizio and data.data_fine and data.data_fine < data.data_inizio:
        raise HTTPException(status_code=400, detail="La data di fine non puo' precedere quella di inizio")
    torneo.nome = data.nome.strip()
    torneo.data_inizio = data.data_inizio
    torneo.data_fine = data.data_fine
    torneo.luogo = data.luogo
    torneo.organizzatore = data.organizzatore
    torneo.descrizione = data.descrizione
    # I fogli portano il nome del torneo nell'intestazione del PDF: se il responsabile lo corregge,
    # nessuno deve restare con il nome vecchio. Si ricostruisce il nome categoria per categoria,
    # cosi' il suffisso con la categoria non si perde.
    for cat in _categorie_iscritte(torneo_id, db):
        db.execute(text("UPDATE liste_torneo SET nome = :n WHERE torneo_id = :t AND categoria_id = :c"),
                   {"n": _nome_lista(torneo.nome, cat), "t": torneo.id, "c": cat["id"]})
    db.commit()
    return {"ok": True}


@router.delete("/{torneo_id}")
def elimina_torneo(torneo_id: int, db: Session = Depends(get_db),
                   current_user: Utente = Depends(get_responsabile_tornei)):
    torneo = _get_torneo(torneo_id, current_user, db)
    # La lista creata col torneo se ne va con lui: senza il torneo non e' piu' la lista di niente,
    # e lasciarla in Liste Tornei significherebbe esportare un file per un torneo che non esiste
    # piu'. Le liste create a mano (torneo_id NULL) non sono toccate.
    ids_liste = [r[0] for r in db.execute(text(
        "SELECT id FROM liste_torneo WHERE torneo_id = :t"), {"t": torneo_id}).fetchall()]
    for lid in ids_liste:
        db.execute(text("DELETE FROM liste_torneo_giocatori WHERE lista_id = :l"), {"l": lid})
        db.execute(text("DELETE FROM liste_torneo WHERE id = :l"), {"l": lid})
    db.execute(text("DELETE FROM tornei_gare WHERE torneo_id = :t"), {"t": torneo_id})
    db.execute(text("DELETE FROM tornei_categorie WHERE torneo_id = :t"), {"t": torneo_id})
    db.delete(torneo)
    db.commit()
    return {"ok": True, "liste_eliminate": len(ids_liste)}


@router.post("/{torneo_id}/categorie")
def iscrivi_categoria(torneo_id: int, data: CategorieIn, db: Session = Depends(get_db),
                      current_user: Utente = Depends(get_responsabile_tornei)):
    """Iscrive una categoria al torneo e le crea dietro il suo foglio giocatori.

    Le due cose nello stesso transaction sono il punto, non un dettaglio: il foglio e' il documento
    che l'organizzatore aspetta, e se dipendesse da un passaggio manuale resterebbe senza.
    """
    torneo = _get_torneo(torneo_id, current_user, db)
    cat = db.query(Categoria).filter(Categoria.id == data.categoria_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    sid = get_societa_filter(current_user)
    if sid and cat.societa_id != sid:
        raise HTTPException(status_code=403, detail="Non autorizzato su questa categoria")
    # Un doppio click non deve creare un secondo foglio per la stessa categoria. L'UNIQUE del DB lo
    # impedisce gia', ma rispondere "gia' iscritta" e' meglio di lasciar trapelare un 500.
    gia = db.query(TorneoCategoria).filter(TorneoCategoria.torneo_id == torneo_id,
                                           TorneoCategoria.categoria_id == cat.id).first()
    if gia:
        lista_id = _crea_lista_del_torneo(torneo, _dati_categoria(cat), db)
        db.commit()
        return {"ok": True, "gia_iscritta": True, "lista_id": lista_id}
    db.add(TorneoCategoria(torneo_id=torneo_id, categoria_id=cat.id))
    db.flush()
    lista_id = _crea_lista_del_torneo(torneo, _dati_categoria(cat), db)
    # La colonna "prima categoria" alimenta il badge e l'ingresso da Scelta.vue: se il torneo non
    # ne aveva una (nata con categoria_id NULL) questa lo diventa
    if torneo.categoria_id is None:
        torneo.categoria_id = cat.id
    db.commit()
    return {"ok": True, "lista_id": lista_id}


@router.delete("/{torneo_id}/categorie/{categoria_id}")
def rimuovi_categoria(torneo_id: int, categoria_id: int, db: Session = Depends(get_db),
                      current_user: Utente = Depends(get_responsabile_tornei)):
    """Toglie l'iscrizione di una categoria, ma non cancella il lavoro fatto sul suo foglio.

    Due scelte precise. Le gare gia' in calendario bloccano l'operazione: una gara rimasta senza
    categoria sarebbe un buco nel calendario, e chi la cancella deve sapere che la sta perdendo.
    Il foglio giocatori invece si distacca (torneo_id torna NULL) e resta in Liste Tornei: chi ci
    ha messo i giocatori non li perde perche' il responsabile ha cambiato idea sulle categorie.
    """
    torneo = _get_torneo(torneo_id, current_user, db)
    iscrizione = db.query(TorneoCategoria).filter(TorneoCategoria.torneo_id == torneo_id,
                                                  TorneoCategoria.categoria_id == categoria_id).first()
    if not iscrizione:
        raise HTTPException(status_code=404, detail="Categoria non iscritta a questo torneo")
    gare = db.execute(text(
        "SELECT count(*) FROM tornei_gare WHERE torneo_id = :t AND categoria_id = :c"
    ), {"t": torneo_id, "c": categoria_id}).scalar() or 0
    if gare:
        raise HTTPException(status_code=400, detail=(
            f"La categoria ha {gare} {'gara' if gare == 1 else 'gare'} nel calendario: "
            "eliminale prima di rimuovere l'iscrizione"))
    distaccate = db.execute(text(
        "UPDATE liste_torneo SET torneo_id = NULL WHERE torneo_id = :t AND categoria_id = :c"
    ), {"t": torneo_id, "c": categoria_id}).rowcount
    # Se si toglie la categoria che il torneo mostrava come "prima", va scelta la nuova: lasciare
    # un riferimento a una categoria non piu' iscritta darebbe al badge un'etichetta bugiarda
    if torneo.categoria_id == categoria_id:
        db.delete(iscrizione)
        db.flush()
        restanti = _categorie_iscritte(torneo_id, db)
        torneo.categoria_id = restanti[0]["id"] if restanti else None
    else:
        db.delete(iscrizione)
    db.commit()
    return {"ok": True, "liste_distaccate": distaccate}


def _risolvi_categoria_gara(torneo_id: int, categoria_id, db: Session):
    """La categoria di una gara: quella chiesta, o l'unica iscritta se non viene chiesta.

    Se le iscritte sono piu' d'una e la richiesta non dice quale, scegliere al posto suo e'
    sbagliare: la gara finirebbe nel foglio sbagliato da consegnare all'organizzatore. Meglio un 400
    che un calendario plausibile e falso.
    """
    iscritte = _categorie_iscritte(torneo_id, db)
    if categoria_id:
        if not any(c["id"] == categoria_id for c in iscritte):
            raise HTTPException(status_code=400, detail=(
                "La categoria non e' iscritta a questo torneo: iscrivila prima di programmare la gara"))
        return categoria_id
    if len(iscritte) == 1:
        return iscritte[0]["id"]
    if not iscritte:
        raise HTTPException(status_code=400, detail="Il torneo non ha categorie iscritte")
    raise HTTPException(status_code=400, detail=(
        f"Il torneo ha {len(iscritte)} categorie: indica a quale categoria appartiene la gara"))


@router.post("/{torneo_id}/gare")
def aggiungi_gara(torneo_id: int, data: GaraIn, db: Session = Depends(get_db),
                  current_user: Utente = Depends(get_responsabile_tornei)):
    _get_torneo(torneo_id, current_user, db)
    if not any([(data.avversario or "").strip(), (data.campo or "").strip(),
                (data.note or "").strip(), data.data]):
        raise HTTPException(status_code=400, detail="La gara deve avere almeno un avversario, un campo o una data")
    data.categoria_id = _risolvi_categoria_gara(torneo_id, data.categoria_id, db)
    if data.numero is None:
        data.numero = (db.execute(text(
            "SELECT COALESCE(MAX(numero), 0) FROM tornei_gare WHERE torneo_id = :t"),
            {"t": torneo_id}).scalar() or 0) + 1
    gara = TorneoGara(torneo_id=torneo_id, **data.model_dump())
    db.add(gara)
    db.commit()
    db.refresh(gara)
    return {"id": gara.id, "numero": gara.numero, "categoria_id": gara.categoria_id}


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
    dati = data.model_dump()
    dati["categoria_id"] = _risolvi_categoria_gara(torneo_id, dati.get("categoria_id"), db)
    for k, v in dati.items():
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
