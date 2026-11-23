from fastapi import APIRouter, Depends, HTTPException
import re
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from pydantic import BaseModel
from ..database import get_db
from ..models import (Convocazione, ConvocazioneGara, ConvocazioneGiocatore, Persona, Utente,
                      Torneo, TorneoGara)
from .auth import get_current_user

router = APIRouter(prefix="/convocazioni", tags=["convocazioni"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id


# BUCO NOTO, non risolto qui e da decidere col titolare.
# Le scritture del percorso WEEKEND (`crea`, `aggiorna`, `elimina`) hanno come unica guardia
# `get_current_user` + il confronto su `societa_id`: chiunque abbia un token valido puo' creare,
# riscrivere o cancellare una convocazione di campionato, inclusi `dirigente`, `scouting` e `infermeria`,
# che nel resto dell'app sono ruoli di sola lettura. E' la stessa classe di buco chiuso nel 2026-11 su
# Liste Tornei, dove bastava un token per riscrivere il foglio consegnato all'organizzatore.
#
# Non l'ho chiuso in questa modifica perche' cambiare chi puo' scrivere su una funzione che il titolare
# usa ogni settimana e' una decisione sua, non una correzione ovvia: se oggi un dirigente prepara le
# convocazioni, mettere il gate gli toglie un lavoro che sta facendo. Le convocazioni di TORNEO, che
# invece nascono oggi, quel gate ce l'hanno gia' (_esigi_gestore_convocazioni).
#
# Il frontend non compensa: la pagina Convocazioni ha UNA sola guardia di ruolo (`puoScouting`, usata per
# il solo pulsante Scouting) e la rotta `/convocazioni/:id` in `core/router.js` non ha `roles`. La
# separazione reale sta nelle card di Scelta.vue e nel menu di App.vue, cioe' nella visibilita', non nel
# permesso.


# Chi puo' CONVOCARE. Non e' il gate delle scritture di convocazioni del weekend, che oggi e' aperto a
# chiunque abbia un token (vedi il commento su get_gestore_convocazioni): questo governa le convocazioni
# delle gare di TORNEO, nate con "Convocazioni Tornei", e la pagina da cui si fanno e' in sola lettura
# per i non-admin. Il mister convoca, l'admin puo' tutto; dirigente, scouting e infermeria leggono.
# E' la stessa scelta gia' presa per le Liste Tornei (RUOLI_GESTIONE_LISTA): chi mette i giocatori in un
# documento che esce dall'app e' uno staff preciso, non un ruolo qualsiasi.
RUOLI_GESTIONE_CONVOCAZIONI = ("mister",)


def _esigi_gestore_convocazioni(current_user: Utente):
    """Versione funzione, non dependency: il percorso torneo la invoca dentro il ramo, perche' lo stesso
    endpoint serve anche il weekend e il gate del weekend non si tocca (vedi il BUCO NOTO in cima al
    file: e' noto e accettato in attesa di una decisione, non una distrazione)."""
    if current_user.is_admin or current_user.is_super_admin:
        return current_user
    if current_user.ruolo in RUOLI_GESTIONE_CONVOCAZIONI:
        return current_user
    raise HTTPException(
        status_code=403,
        detail="Solo il mister della categoria o un amministratore possono convocare per una gara di torneo")


def get_gestore_convocazioni(current_user: Utente = Depends(get_current_user)):
    return _esigi_gestore_convocazioni(current_user)


class GiocatoreIn(BaseModel):
    persona_id: int
    posizione: int
    non_presente: bool = False

class GaraIn(BaseModel):
    numero: int
    partita_id: Optional[int] = None
    gara: Optional[str] = None
    data: Optional[date] = None
    campo: Optional[str] = None
    indirizzo: Optional[str] = None
    appuntamento: Optional[str] = None
    inizio_gara: Optional[str] = None
    allenatore: Optional[str] = None
    mister_manuale: Optional[str] = None
    allenatori: Optional[List[int]] = None
    livello: Optional[str] = None
    giocatori: List[GiocatoreIn] = []

class ConvocazioneIn(BaseModel):
    categoria_id: int
    weekend_id: Optional[int] = None
    # Presenza di questo campo = "e' un foglio di torneo". Non e' un campo informativo: decide quale
    # dei due percorsi esegue il router, e il percorso torneo non tocca ne' weekend ne' partite.
    tornei_gara_id: Optional[int] = None
    data_inizio: date
    data_fine: Optional[date] = None
    note: Optional[str] = None
    esclusioni: Optional[List[dict]] = []
    gare: List[GaraIn] = []
    # I convocati del foglio di TORNEO. Il percorso del weekend li porta dentro `gare[].giocatori`, perche'
    # li' le gare sono N; qui la gara e' una sola e sta nel padre. Il router rifiuta con un 400 chi mette i
    # giocatori in `gare` invece che qui: ignorarli in silenzio darebbe un foglio vuoto senza dirlo a nessuno
    giocatori: List[GiocatoreIn] = []

# ---------------------------------------------------------------------------
# Il percorso TORNEO. Vive separato da crea/aggiorna di proposito.
#
# crea() e aggiorna() non si limitano a leggere `partite`: esigono un weekend (400 senza), indovinano la
# partita con `WHERE categoria_id = ? AND data_partite = ?`, INSERTONO una riga in `partite` se non la
# trovano, la UPDATE, e fanno upsert su `campi_sportivi`. Interlecciare condizioni li' dentro e' il modo
# in cui una ne sfugge, e la conseguenza non e' un errore visibile: e' una gara di torneo che si aggancia
# a una partita di campionato nella stessa data, o una convocazione di torneo che crea una partita falsa.
# Qui il router DELEGA PRIMA di entrare in quel codice, quindi quelle righe non vengono proprio eseguite.
#
# Cio' che viene copiato e' solo il meccanismo dei convocati (ConvocazioneGara + ConvocazioneGiocatore
# con posizione e non_presente), che e' la parte che il mister usa davvero.
# ---------------------------------------------------------------------------

def _gara_torneo_validata(tornei_gara_id: int, db: Session, current_user: Utente):
    """La gara di torneo a cui il foglio si aggancia, gia' verificata nel tenant.

    Il tenant si verifica passando dal TORNEO, non dalla gara: `tornei_gare` non ha una societa_id, la
    societa' e' quella del torneo. Verificarla sulla gara sarebbe un controllo che sembra presente e non
    c'e'.
    """
    g = db.query(TorneoGara).filter(TorneoGara.id == tornei_gara_id).first()
    if not g:
        raise HTTPException(status_code=404, detail="La gara di torneo indicata non esiste")
    t = db.query(Torneo).filter(Torneo.id == g.torneo_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Il torneo di questa gara non esiste")
    societa_id = get_societa_filter(current_user)
    if societa_id and t.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato su questa gara di torneo")
    return g, t


def _categoria_gara_torneo(g: TorneoGara, t: Torneo, db: Session) -> int:
    """La categoria della gara, senza indovinarla.

    `tornei_gare.categoria_id` e' nullable solo per non farla scegliere ogni volta a chi ha un torneo mono
    categoria. Con piu' iscritte e la gara senza categoria, scegliere al posto suo vorrebbe dire convocare
    i Pulcini per la gara degli Esordienti: un foglio plausibile e falso, e i convocati sono la cosa che
    finisce in mano all'organizzatore.
    """
    if g.categoria_id:
        return g.categoria_id
    iscritte = db.execute(text(
        "SELECT categoria_id FROM tornei_categorie WHERE torneo_id = :t"),
        {"t": t.id}).scalars().all()
    if len(iscritte) == 1:
        return iscritte[0]
    raise HTTPException(status_code=400, detail=(
        f"Questa gara non ha una categoria e il torneo '{t.nome}' ne ha {len(iscritte)}: "
        "assegnala dal calendario del torneo prima di convocare"))


def _giocatori_del_foglio(data: ConvocazioneIn):
    """I giocatori del foglio di torneo, con la posizione ricalcolata qui.

    Il percorso del weekend si fida della `posizione` mandata dal client. Qui no: il foglio e' uno solo e
    l'ordine e' semplicemente l'ordine in cui arrivano, ricalcolarla lato server costa zero e toglie al
    client la possibilita' di mandare buchi o duplicati.
    """
    if data.gare:
        raise HTTPException(status_code=400, detail=(
            "Il foglio di una gara di torneo ha una sola gara: manda i giocatori nel campo 'giocatori', "
            "non in 'gare'"))
    visti = set()
    out = []
    for i, gk in enumerate(data.giocatori or []):
        if gk.persona_id in visti:
            continue          # lo stesso ragazzo due volte nello stesso foglio non e' un'ipotesi: e' un doppio click
        visti.add(gk.persona_id)
        out.append((gk.persona_id, i + 1, bool(gk.non_presente)))
    return out


def _controlla_giocatori_di_torneo(persona_ids, categoria_id, societa_id, db):
    """Ogni convocato deve essere un tesserato di quella categoria e di quella societa'.

    Il doppio filtro non e' ridondante: `persona_id` arriva dal client e senza il filtro di societa' si
    potrebbero convocare ragazzi di un'altra societa' nello stesso torneo, e senza quello di categoria si
    convocherebbero i 2014 per la gara dei 2015. Nessuno dei due errori produce un errore da qualche parte.
    """
    if not persona_ids:
        return
    righe = db.execute(text(
        "SELECT id, categoria_id, societa_id FROM persone WHERE id = ANY(:ids)"),
        {"ids": list(persona_ids)}).fetchall()
    trovati = {r.id: r for r in righe}
    for pid in persona_ids:
        r = trovati.get(pid)
        if not r:
            raise HTTPException(status_code=404, detail=f"Il giocatore {pid} non esiste")
        if societa_id and r.societa_id != societa_id:
            raise HTTPException(status_code=403, detail=f"Il giocatore {pid} non e' della tua societa'")
        if r.categoria_id != categoria_id:
            raise HTTPException(status_code=400, detail=(
                f"Il giocatore {pid} non appartiene alla categoria {categoria_id}: "
                "stai convocando un ragazzo di un'altra squadra per questa gara"))


def _crea_convocazione_torneo(data: ConvocazioneIn, db: Session, current_user: Utente):
    g, t = _gara_torneo_validata(data.tornei_gara_id, db, current_user)
    cat_id = _categoria_gara_torneo(g, t, db)
    if data.categoria_id != cat_id:
        raise HTTPException(status_code=400, detail=(
            f"Questa gara appartiene alla categoria {cat_id}, non {data.categoria_id}"))

    # payload SEMPRE validato, anche se il foglio esiste gia'. Farlo dopo il ritorno idempotente avrebbe
    # detto 200 a un client che mandava un ragazzo di un'altra categoria o i giocatori nel campo 'gare':
    # la chiamata sembra riuscita, nulla e' stato scritto, e nessuno se ne accorge. E' la stessa classe di
    # "plausibile e falso" che qui si combatte da sempre.
    data_inizio = g.data or t.data_inizio
    giocatori = _giocatori_del_foglio(data)
    _controlla_giocatori_di_torneo([p for p, _, _ in giocatori], cat_id, t.societa_id, db)

    # Idempotente per costruzione: un foglio per gara. Riaprire la convocazione due volte, o premere
    # "Convoca" due volte, non deve produrre un secondo foglio con meta' convocati — e' lo stesso motivo
    # per cui la Lista Tornei nasce col torneo e il doppio click sull'iscrizione non crea un secondo foglio.
    esistente = db.query(Convocazione).filter(Convocazione.tornei_gara_id == g.id).first()
    if esistente:
        return {"id": esistente.id, "gia_esistente": True}

    if not data_inizio:
        raise HTTPException(status_code=400, detail=(
            f"La gara di torneo non ha una data e il torneo '{t.nome}' non ha un periodo: "
            "metti la data nel calendario del torneo prima di convocare"))

    c = Convocazione(societa_id=t.societa_id, categoria_id=cat_id, weekend_id=None,
                     tornei_gara_id=g.id, data_inizio=data_inizio, data_fine=data_inizio,
                     note=data.note, esclusioni=data.esclusioni)
    db.add(c)
    db.flush()

    # I dati logistici si copiano dalla gara del torneo. `appuntamento` viene da ora_appuntamento e
    # `inizio_gara` da ora: invertire i due e' l'errore gia' visto nel PDF tornei, dove la colonna
    # usciva tutta "-" senza che nessun test se ne accorgesse.
    gara = ConvocazioneGara(
        convocazione_id=c.id, partita_id=None, numero=1,
        gara=(g.avversario or f"Gara {g.numero or 1}"),
        data=g.data, campo=g.campo, indirizzo=g.indirizzo,
        appuntamento=g.ora_appuntamento, inizio_gara=g.ora,
        allenatore=None, allenatori=[], livello=None)
    db.add(gara)
    db.flush()
    for pid, pos, np in giocatori:
        db.add(ConvocazioneGiocatore(gara_id=gara.id, persona_id=pid, posizione=pos,
                                     non_presente=1 if np else 0))
    db.commit()
    return {"id": c.id, "gia_esistente": False}


def _aggiorna_convocazione_torneo(c: Convocazione, data: ConvocazioneIn, db: Session,
                                  current_user: Utente):
    g, t = _gara_torneo_validata(c.tornei_gara_id, db, current_user)
    cat_id = _categoria_gara_torneo(g, t, db)

    # Un foglio non cambia mondo: spostarlo dal weekend al torneo (o viceversa) lascierebbe dietro i dati
    # dell'uno e prendesse quelli dell'altro. Se serve, si elimina e si ricrea.
    if data.weekend_id is not None:
        raise HTTPException(status_code=400, detail=(
            "Questa convocazione e' di una gara di torneo: non puo' essere collegata a un weekend"))
    if data.categoria_id != cat_id:
        raise HTTPException(status_code=400, detail=(
            f"Questa gara appartiene alla categoria {cat_id}, non {data.categoria_id}"))

    giocatori = _giocatori_del_foglio(data)
    _controlla_giocatori_di_torneo([p for p, _, _ in giocatori], cat_id, t.societa_id, db)

    c.note = data.note
    c.esclusioni = data.esclusioni
    c.data_inizio = g.data or t.data_inizio or c.data_inizio
    c.data_fine = c.data_inizio

    # La gara la riscrive, come fa gia' il percorso del weekend: il foglio e' uno e i convocati sono
    # l'aggregato intero. Ricrearla significa anche riallineare i dati logistici se il responsabile ha
    # nel frattempo cambiato campo, avversario o orario del calendario.
    vecchie = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == c.id).all()
    for v in vecchie:
        db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == v.id)\
          .delete(synchronize_session=False)
        db.delete(v)
    db.flush()

    gara = ConvocazioneGara(
        convocazione_id=c.id, partita_id=None, numero=1,
        gara=(g.avversario or f"Gara {g.numero or 1}"),
        data=g.data, campo=g.campo, indirizzo=g.indirizzo,
        appuntamento=g.ora_appuntamento, inizio_gara=g.ora,
        allenatore=None, allenatori=[], livello=None)
    db.add(gara)
    db.flush()
    for pid, pos, np in giocatori:
        db.add(ConvocazioneGiocatore(gara_id=gara.id, persona_id=pid, posizione=pos,
                                     non_presente=1 if np else 0))
    db.commit()
    return {"id": c.id}


@router.get("/")
def lista(categoria_id: Optional[int] = None, tornei_gara_id: Optional[int] = None,
          db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import text
    societa_id = get_societa_filter(current_user)
    where_soc = "AND c.societa_id = :sid" if societa_id else ""
    params = {}
    where_cat = ""
    if categoria_id is not None:
        where_cat = "AND c.categoria_id = :cid"
        params["cid"] = categoria_id
    if societa_id:
        params["sid"] = societa_id
    # Il filtro per gara di torneo serve alla pagina per riaprire il proprio foglio. Quando c'e', il
    # discrimine "tornei_gara_id IS NULL" va tolto: sarebbe la query che esclude il risultato che hai
    # chiesto. Le due condizioni sono mutuamente esclusive per costruzione, non perche' conviene.
    if tornei_gara_id is not None:
        where_torneo = "AND c.tornei_gara_id = :tg"
        params["tg"] = tornei_gara_id
    else:
        # I fogli delle gare di torneo NON vanno nella lista del campionato. La pagina Convocazioni
        # raggruppa per weekend e mostra `weekend_nome`: un foglio di torneo ci apparirebbe come una riga
        # senza weekend, cioe' come un dato rotto, e il mister si metterebbe a cercare perche' "la
        # convocazione del sabato non si vede". Si esclude qui, non nel frontend, perche' la lista la
        # leggono anche i test e qualsiasi client futuro.
        #
        # Il predicato e' `tornei_gara_id IS NULL` e NON `weekend_id IS NOT NULL`: su PROD ci sono gia' 4
        # convocazioni su 14 senza weekend (nate da weekend cancellati o da codice vecchio) e sono fogli
        # del campionato a tutti gli effetti. Filtrare sul weekend le farebbe sparire dalla pagina, che
        # sarebbe una regressione piu' grave del problema che stiamo risolvendo.
        where_torneo = "AND c.tornei_gara_id IS NULL"
    res = db.execute(text(f"""
        SELECT c.id, c.weekend_id, c.data_inizio, c.data_fine, c.categoria_id, w.nome as weekend_nome
        FROM convocazioni c
        LEFT JOIN weekend w ON c.weekend_id = w.id
        WHERE 1=1 {where_cat} {where_soc} {where_torneo}
        ORDER BY c.data_inizio DESC
    """), params)
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/{cid}")
def dettaglio(cid: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    # Verifica società
    societa_id = get_societa_filter(current_user)
    if societa_id and c.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    gare = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).order_by(ConvocazioneGara.numero).all()
    # Su un foglio di torneo `partita_id` e' NULL per costruzione, quindi i tre recuperi sotto non
    # scatterebbero comunque. Il flag c'e' lo stesso, e non e' ridondanza: rende esplicito che QUELLI
    # sono accessi alla tabella `partite` e che un foglio di torneo non deve leggerla nemmeno per
    # sbaglio, perche' li' dentro ci sono i dati del campionato di un'altra squadra della stessa societa'.
    foglio_torneo = c.tornei_gara_id is not None
    result_gare = []
    for g in gare:
        giocatori = db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).order_by(ConvocazioneGiocatore.posizione).all()
        persone = []
        for gk in giocatori:
            p = db.query(Persona).filter(Persona.id == gk.persona_id).first()
            persone.append({"persona_id": gk.persona_id, "posizione": gk.posizione, "nome": p.nome if p else "", "cognome": p.cognome if p else "", "non_presente": bool(gk.non_presente)})
        livello_val = getattr(g, 'livello', None)
        if not livello_val and g.partita_id and not foglio_torneo:
            p_row = db.execute(text("SELECT livello FROM partite WHERE id = :pid"), {"pid": g.partita_id}).fetchone()
            if p_row and p_row[0]:
                livello_val = p_row[0]
        allenatori_dettagli = []
        allenatori_ids = list(g.allenatori or [])
        if not allenatori_ids and g.partita_id and not foglio_torneo:
            p_row = db.execute(text("SELECT mister_id FROM partite WHERE id = :pid"), {"pid": g.partita_id}).fetchone()
            if p_row and p_row[0]:
                allenatori_ids = [p_row[0]]
        for aid in allenatori_ids:
            u = db.query(Utente).filter(Utente.id == aid).first()
            if u:
                allenatori_dettagli.append({
                    "id": u.id,
                    "nome": u.nome,
                    "cognome": u.cognome,
                    "cellulare": u.cellulare or ""
                })
        if not allenatori_dettagli and g.allenatore:
            for part in str(g.allenatore).split(','):
                part_clean = part.strip()
                if part_clean:
                    u = db.query(Utente).filter(
                        Utente.societa_id == c.societa_id,
                        Utente.cognome.ilike(part_clean)
                    ).first()
                    if u:
                        allenatori_dettagli.append({
                            "id": u.id,
                            "nome": u.nome,
                            "cognome": u.cognome,
                            "cellulare": u.cellulare or ""
                        })
        allenatore_val = g.allenatore
        mister_manuale_val = None
        if g.partita_id and not foglio_torneo:
            p_man = db.execute(text("SELECT mister_manuale FROM partite WHERE id = :pid"), {"pid": g.partita_id}).fetchone()
            if p_man and p_man[0]:
                mister_manuale_val = p_man[0]
                if not allenatore_val:
                    allenatore_val = mister_manuale_val

        result_gare.append({
            "id": g.id, "partita_id": g.partita_id, "numero": g.numero, "gara": g.gara, "data": g.data,
            "campo": g.campo, "indirizzo": g.indirizzo, "appuntamento": g.appuntamento,
            "inizio_gara": g.inizio_gara, "allenatore": allenatore_val, "allenatori": g.allenatori or [],
            "mister_manuale": mister_manuale_val,
            "allenatori_dettagli": allenatori_dettagli,
            "livello": livello_val or "", "giocatori": persone
        })
    w_row = db.execute(text("SELECT nome FROM weekend WHERE id = :wid"), {"wid": c.weekend_id}).fetchone() if c.weekend_id else None
    weekend_nome = w_row[0] if w_row else None

    # Il contesto del torneo, per la pagina che apre il foglio: senza questi il modal della convocazione
    # direbbe solo "Convocazione" e il mister non saprebbe per quale gara e quale torneo sta scrivendo.
    contesto_torneo = None
    if c.tornei_gara_id:
        riga = db.execute(text("""
            SELECT tg.id, tg.avversario, tg.numero, t.id, t.nome, t.data_inizio, t.data_fine,
                   c.nome, c.anno
            FROM tornei_gare tg
            JOIN tornei t ON t.id = tg.torneo_id
            LEFT JOIN categorie c ON c.id = tg.categoria_id
            WHERE tg.id = :g
        """), {"g": c.tornei_gara_id}).fetchone()
        if riga:
            contesto_torneo = {
                "tornei_gara_id": riga[0], "avversario": riga[1], "numero_gara": riga[2],
                "torneo_id": riga[3], "torneo_nome": riga[4],
                "torneo_data_inizio": riga[5], "torneo_data_fine": riga[6],
                "categoria_nome": riga[7], "categoria_anno": riga[8],
            }

    return {"id": c.id, "categoria_id": c.categoria_id, "weekend_id": c.weekend_id, "weekend_nome": weekend_nome, "tornei_gara_id": c.tornei_gara_id, "torneo": contesto_torneo, "data_inizio": c.data_inizio, "data_fine": c.data_fine, "note": c.note, "esclusioni": c.esclusioni or [], "gare": result_gare}

@router.post("/")
def crea(data: ConvocazioneIn, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    # Il percorso torneo esce PRIMA di tutto il resto. Non e' una questione di ordine estetico: sotto
    # c'e' il codice che esige un weekend, indovina la partita per categoria e data, ne INSERTA una
    # nuova in `partite` se non la trova e fa upsert su `campi_sportivi`. Se un foglio di torneo
    # attraversasse anche solo una di quelle righe, il danno non sarebbe un errore: sarebbe una partita
    # di campionato inventata, o una convocazione agganciata alla gara sbagliata della stessa sera.
    if data.tornei_gara_id is not None:
        _esigi_gestore_convocazioni(current_user)
        return _crea_convocazione_torneo(data, db, current_user)

    from ..models import Categoria
    from sqlalchemy import text
    cat = db.query(Categoria).filter(Categoria.id == data.categoria_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    if not current_user.is_super_admin and cat.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su questa categoria")
    societa_id = cat.societa_id

    # Trova weekend corrispondente se non fornito
    weekend_id = data.weekend_id
    if not weekend_id and data.data_inizio:
        w_row = db.execute(text("""
            SELECT id, data_inizio, data_fine FROM weekend
            WHERE societa_id = :sid AND data_inizio <= :di AND data_fine >= :di
            LIMIT 1
        """), {"sid": societa_id, "di": data.data_inizio}).fetchone()
        if w_row:
            weekend_id = w_row[0]

    if not weekend_id:
        raise HTTPException(
            status_code=400,
            detail="Non è possibile creare una convocazione senza un weekend programmato dal Responsabile."
        )

    w_info = db.execute(text("SELECT data_inizio, data_fine FROM weekend WHERE id = :wid"), {"wid": weekend_id}).fetchone()
    data_inizio = w_info[0] if w_info else data.data_inizio
    data_fine = w_info[1] if w_info else data.data_fine

    c = Convocazione(societa_id=societa_id, categoria_id=data.categoria_id, weekend_id=weekend_id, data_inizio=data_inizio, data_fine=data_fine, note=data.note, esclusioni=data.esclusioni)
    db.add(c)
    db.flush()
    used_pids = {g.partita_id for g in data.gare if g.partita_id}
    for g in data.gare:
        partita_id = g.partita_id
        dt = g.data or data_inizio
        if not partita_id and dt:
            p_rows = db.execute(text("""
                SELECT id FROM partite
                WHERE categoria_id = :cid AND data_partite = :data
                ORDER BY ora ASC NULLS LAST, id ASC
            """), {"cid": data.categoria_id, "data": dt}).fetchall()
            for r in p_rows:
                if r[0] not in used_pids:
                    partita_id = r[0]
                    used_pids.add(partita_id)
                    break

        ora_short = None
        if g.inizio_gara:
            m = re.search(r'\b([01]?\d|2[0-3]):[0-5]\d\b', g.inizio_gara)
            if m:
                ora_short = m.group(0)
        appunt_time = None
        if g.appuntamento:
            m = re.search(r'\b([01]?\d|2[0-3]):[0-5]\d\b', g.appuntamento)
            if m:
                appunt_time = m.group(0)

        g_campo = g.campo.strip() if g.campo else ""
        g_indirizzo = g.indirizzo.strip() if g.indirizzo else ""
        if g_campo and not g_indirizzo and societa_id:
            cs = db.execute(
                text("SELECT indirizzo FROM campi_sportivi WHERE societa_id = :sid AND LOWER(TRIM(nome)) = LOWER(TRIM(:nome)) LIMIT 1"),
                {"sid": societa_id, "nome": g_campo}
            ).fetchone()
            if cs and cs[0]:
                g_indirizzo = cs[0]
        if g_campo and g_indirizzo and societa_id:
            try:
                db.execute(text("""
                    INSERT INTO campi_sportivi (societa_id, nome, indirizzo, updated_at)
                    VALUES (:sid, :nome, :indirizzo, CURRENT_TIMESTAMP)
                    ON CONFLICT (societa_id, nome) DO UPDATE
                    SET indirizzo = EXCLUDED.indirizzo,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE EXCLUDED.indirizzo IS NOT NULL AND TRIM(EXCLUDED.indirizzo) != ''
                """), {"sid": societa_id, "nome": g_campo, "indirizzo": g_indirizzo})
            except Exception as e:
                pass

        p_livello = None
        if partita_id:
            p_row = db.execute(text("SELECT livello FROM partite WHERE id = :pid"), {"pid": partita_id}).fetchone()
            if p_row and p_row[0]:
                p_livello = p_row[0]
        g_livello = g.livello or p_livello

        if not partita_id and weekend_id:
            # Nuova partita aggiunta dal mister al weekend del responsabile: registrala in partite
            res_p = db.execute(text("""
                INSERT INTO partite (
                    categoria_id, data_partite, ora, ora_presentazione,
                    avversario, campo, indirizzo, casa_fuori, societa_id, weekend_id, livello
                ) VALUES (
                    :cid, :data, :ora, :appunt,
                    :avv, :campo, :indirizzo, :cf, :sid, :wid, :livello
                ) RETURNING id
            """), {
                "cid": data.categoria_id,
                "data": dt,
                "ora": ora_short,
                "appunt": appunt_time,
                "avv": g.gara or "Gara",
                "campo": g_campo,
                "indirizzo": g_indirizzo,
                "cf": "casa",
                "sid": societa_id,
                "wid": weekend_id,
                "livello": g_livello
            })
            partita_id = res_p.scalar()
            if partita_id:
                used_pids.add(partita_id)
        elif partita_id:
            db.execute(text("""
                UPDATE partite SET
                    ora = COALESCE(:ora, ora),
                    ora_presentazione = COALESCE(:appunt, ora_presentazione),
                    campo = COALESCE(:campo, campo),
                    indirizzo = COALESCE(:indirizzo, indirizzo),
                    livello = COALESCE(:livello, livello)
                WHERE id = :pid
            """), {
                "pid": partita_id,
                "ora": ora_short,
                "appunt": appunt_time,
                "campo": g_campo if g_campo else None,
                "indirizzo": g_indirizzo if g_indirizzo else None,
                "livello": g.livello if g.livello else None
            })

        g_allenatore = g.allenatore or g.mister_manuale
        if not g_allenatore and partita_id:
            p_man = db.execute(text("SELECT mister_manuale FROM partite WHERE id = :pid"), {"pid": partita_id}).fetchone()
            if p_man and p_man[0]:
                g_allenatore = p_man[0]
        if partita_id and g.mister_manuale and not (g.allenatori and len(g.allenatori) > 0):
            db.execute(text("UPDATE partite SET mister_manuale = :man WHERE id = :pid"), {"man": g.mister_manuale.strip(), "pid": partita_id})

        gara = ConvocazioneGara(convocazione_id=c.id, partita_id=partita_id, numero=g.numero, gara=g.gara, data=dt,
            campo=g_campo, indirizzo=g_indirizzo, appuntamento=g.appuntamento,
            inizio_gara=g.inizio_gara, allenatore=g_allenatore, allenatori=g.allenatori or [],
            livello=g_livello)
        db.add(gara)
        db.flush()
        for gk in g.giocatori:
            db.add(ConvocazioneGiocatore(gara_id=gara.id, persona_id=gk.persona_id, posizione=gk.posizione, non_presente=1 if gk.non_presente else 0))
    db.commit()
    return {"id": c.id}

@router.put("/{cid}")
def aggiorna(cid: int, data: ConvocazioneIn, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import text
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    # Verifica società
    societa_id = get_societa_filter(current_user)
    if societa_id and c.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")

    # Valgono le stesse ragioni di crea(): il percorso torneo deve uscire prima che questo codice tocchi
    # weekend e partite. Il discriminatore si prende DAL FOGLIO, non da cosa manda il client: un client
    # che dimenticasse `tornei_gara_id` nel PUT non deve poter riscrivere un foglio di torneo con la
    # logica del weekend, perche' quello significherebbe assegnargli un weekend e una partita.
    if c.tornei_gara_id is not None:
        _esigi_gestore_convocazioni(current_user)
        return _aggiorna_convocazione_torneo(c, data, db, current_user)

    weekend_id = data.weekend_id or c.weekend_id
    if not weekend_id and data.data_inizio and c.societa_id:
        w_row = db.execute(text("""
            SELECT id, data_inizio, data_fine FROM weekend
            WHERE societa_id = :sid AND data_inizio <= :di AND data_fine >= :di
            LIMIT 1
        """), {"sid": c.societa_id, "di": data.data_inizio}).fetchone()
        if w_row:
            weekend_id = w_row[0]

    if not weekend_id:
        raise HTTPException(
            status_code=400,
            detail="La convocazione deve essere associata a un weekend programmato dal Responsabile."
        )

    w_info = db.execute(text("SELECT data_inizio, data_fine FROM weekend WHERE id = :wid"), {"wid": weekend_id}).fetchone()
    if w_info:
        c.data_inizio = w_info[0]
        c.data_fine = w_info[1]
    else:
        c.data_inizio = data.data_inizio
        c.data_fine = data.data_fine

    c.weekend_id = weekend_id
    c.note = data.note
    c.esclusioni = data.esclusioni

    # Elimina e ricrea gare
    gare_old = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).all()
    for g in gare_old:
        db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).delete()
    db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).delete()
    used_pids = {g.partita_id for g in data.gare if g.partita_id}
    for g in data.gare:
        partita_id = g.partita_id
        dt = g.data or c.data_inizio
        if not partita_id and dt:
            p_rows = db.execute(text("""
                SELECT id FROM partite
                WHERE categoria_id = :cid AND data_partite = :data
                ORDER BY ora ASC NULLS LAST, id ASC
            """), {"cid": c.categoria_id, "data": dt}).fetchall()
            for r in p_rows:
                if r[0] not in used_pids:
                    partita_id = r[0]
                    used_pids.add(partita_id)
                    break

        ora_short = None
        if g.inizio_gara:
            m = re.search(r'\b([01]?\d|2[0-3]):[0-5]\d\b', g.inizio_gara)
            if m:
                ora_short = m.group(0)
        appunt_time = None
        if g.appuntamento:
            m = re.search(r'\b([01]?\d|2[0-3]):[0-5]\d\b', g.appuntamento)
            if m:
                appunt_time = m.group(0)

        g_campo = g.campo.strip() if g.campo else ""
        g_indirizzo = g.indirizzo.strip() if g.indirizzo else ""
        if g_campo and not g_indirizzo and c.societa_id:
            cs = db.execute(
                text("SELECT indirizzo FROM campi_sportivi WHERE societa_id = :sid AND LOWER(TRIM(nome)) = LOWER(TRIM(:nome)) LIMIT 1"),
                {"sid": c.societa_id, "nome": g_campo}
            ).fetchone()
            if cs and cs[0]:
                g_indirizzo = cs[0]
        if g_campo and g_indirizzo and c.societa_id:
            try:
                db.execute(text("""
                    INSERT INTO campi_sportivi (societa_id, nome, indirizzo, updated_at)
                    VALUES (:sid, :nome, :indirizzo, CURRENT_TIMESTAMP)
                    ON CONFLICT (societa_id, nome) DO UPDATE
                    SET indirizzo = EXCLUDED.indirizzo,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE EXCLUDED.indirizzo IS NOT NULL AND TRIM(EXCLUDED.indirizzo) != ''
                """), {"sid": c.societa_id, "nome": g_campo, "indirizzo": g_indirizzo})
            except Exception as e:
                pass

        p_livello = None
        if partita_id:
            p_row = db.execute(text("SELECT livello FROM partite WHERE id = :pid"), {"pid": partita_id}).fetchone()
            if p_row and p_row[0]:
                p_livello = p_row[0]
        g_livello = g.livello or p_livello

        if not partita_id and weekend_id:
            # Nuova partita aggiunta dal mister al weekend del responsabile: registrala in partite
            res_p = db.execute(text("""
                INSERT INTO partite (
                    categoria_id, data_partite, ora, ora_presentazione,
                    avversario, campo, indirizzo, casa_fuori, societa_id, weekend_id, livello
                ) VALUES (
                    :cid, :data, :ora, :appunt,
                    :avv, :campo, :indirizzo, :cf, :sid, :wid, :livello
                ) RETURNING id
            """), {
                "cid": c.categoria_id,
                "data": dt,
                "ora": ora_short,
                "appunt": appunt_time,
                "avv": g.gara or "Gara",
                "campo": g_campo,
                "indirizzo": g_indirizzo,
                "cf": "casa",
                "sid": c.societa_id,
                "wid": weekend_id,
                "livello": g_livello
            })
            partita_id = res_p.scalar()
            if partita_id:
                used_pids.add(partita_id)
        elif partita_id:
            db.execute(text("""
                UPDATE partite SET
                    ora = COALESCE(:ora, ora),
                    ora_presentazione = COALESCE(:appunt, ora_presentazione),
                    campo = COALESCE(:campo, campo),
                    indirizzo = COALESCE(:indirizzo, indirizzo),
                    livello = COALESCE(:livello, livello)
                WHERE id = :pid
            """), {
                "pid": partita_id,
                "ora": ora_short,
                "appunt": appunt_time,
                "campo": g_campo if g_campo else None,
                "indirizzo": g_indirizzo if g_indirizzo else None,
                "livello": g.livello if g.livello else None
            })

        g_allenatore = g.allenatore or g.mister_manuale
        if not g_allenatore and partita_id:
            p_man = db.execute(text("SELECT mister_manuale FROM partite WHERE id = :pid"), {"pid": partita_id}).fetchone()
            if p_man and p_man[0]:
                g_allenatore = p_man[0]
        if partita_id and g.mister_manuale and not (g.allenatori and len(g.allenatori) > 0):
            db.execute(text("UPDATE partite SET mister_manuale = :man WHERE id = :pid"), {"man": g.mister_manuale.strip(), "pid": partita_id})

        gara = ConvocazioneGara(convocazione_id=cid, partita_id=partita_id, numero=g.numero, gara=g.gara, data=dt,
            campo=g_campo, indirizzo=g_indirizzo, appuntamento=g.appuntamento,
            inizio_gara=g.inizio_gara, allenatore=g_allenatore, allenatori=g.allenatori or [],
            livello=g_livello)
        db.add(gara)
        db.flush()
        for gk in g.giocatori:
            db.add(ConvocazioneGiocatore(gara_id=gara.id, persona_id=gk.persona_id, posizione=gk.posizione, non_presente=1 if gk.non_presente else 0))
    db.commit()
    return {"ok": True}

@router.delete("/{cid}")
def elimina(cid: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    societa_id = get_societa_filter(current_user)
    if societa_id and c.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    # Cancellare e' modificare. Senza questo, un dirigente o uno scouting potrebbe cancellare la
    # convocazione che il mister ha appena fatto: il gate su crea/aggiorna non servirebbe a niente se
    # bastasse un DELETE per vanificarlo. Il controllo di societa' viene prima di proposito, cosi' un
    # utente di un'altra societa' riceve il 403 "non autorizzato" e non viene informato sull'esistenza
    # del foglio o sui ruoli che possono toccarlo.
    if c.tornei_gara_id is not None:
        _esigi_gestore_convocazioni(current_user)
    gare = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).all()
    for g in gare:
        db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).delete()
    db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).delete()
    db.delete(c)
    db.commit()
    return {"ok": True}

from datetime import timedelta

@router.get("/presenze-settimana/{categoria_id}")
def presenze_settimana(categoria_id: int, data_gara: date, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    from ..models import Registro, CodicePresenza, Categoria
    cat = db.query(Categoria).filter(Categoria.id == categoria_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    if not current_user.is_super_admin and cat.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su questa categoria")
    # Settimana precedente: lun-dom prima del weekend di gara
    giorno_settimana = data_gara.weekday()  # 0=lun, 6=dom
    inizio_sett = data_gara - timedelta(days=giorno_settimana + 7)
    fine_sett = inizio_sett + timedelta(days=6)

    # Codici assenza
    codici_assenza = [c.codice for c in db.query(CodicePresenza).filter(CodicePresenza.tipo == "assenza").all()]

    persone = db.query(Persona).filter(Persona.categoria_id == categoria_id).all()
    result = []
    for p in persone:
        count = db.query(Registro).filter(
            Registro.persona_id == p.id,
            Registro.categoria_id == categoria_id,
            Registro.data >= inizio_sett,
            Registro.data <= fine_sett,
            ~Registro.codice.in_(codici_assenza)
        ).count()
        result.append({
            "persona_id": p.id,
            "nome": p.nome,
            "cognome": p.cognome,
            "allenamenti": count
        })
    return result
