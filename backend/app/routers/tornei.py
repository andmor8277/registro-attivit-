from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional, List
from datetime import date

from app.models import Utente, Torneo, TorneoCategoria, TorneoGara, ListaTorneo, Categoria
from app.database import get_db
from app.routers.auth import get_current_user
# Importato e non riscritto: e' l'elenco che GET /categorie/{id}/responsabili usa per costruire il
# menu a tendina dei mister. Validare con un elenco scritto a parte qui vorrebbe dire, il giorno
# che si aggiunge un ruolo, o rifiutare valori legittimi o accettarne che la pagina non puo'
# produrre. Non c'e' ciclo: categorie.py non importa questo modulo
from app.routers.categorie import RUOLI_RESPONSABILI
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
    # Il referente del torneo. Le due strade si escludono a vicenda (vedi _valida_mister)
    mister_id: Optional[int] = None
    mister_manuale: Optional[str] = None


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


def get_gestore_gare_torneo(current_user: Utente = Depends(get_current_user)):
    """Chi scrive sul CALENDARIO gare di un torneo: i mister, oltre agli admin.

    E' un gate piu' largo di get_responsabile_tornei e volutamente separato. Il responsabile decide QUALE
    torneo esiste e quali categorie ci giocano; il mister, che e' quello che la gara la gioca, deve poter
    aggiungere la partita che l'organizzatore gli ha comunicato la sera prima — costringerlo a passare da
    un admin significa che la gara non viene registrata, che e' il modo in cui in due anni in liste_torneo
    c'era una lista sola.

    Il filtro di societa' NON sta qui: lo fa _get_torneo, che ogni endpoint delle gare chiama prima di
    toccare i dati. Metterlo anche qui sarebbe un secondo controllo sullo stesso campo mentre il rischio
    reale (conoscere l'id di un torneo di un'altra societa') e' gia' coperto li'.

    Non si filtra per utente_categorie: il titolare ha deciso che i mister vedono e usano legittimamente
    tutte le categorie della propria societa', quindi qui un mister puo' curare il calendario di un torneo
    a cui e' iscritta anche una categoria che non segue.
    """
    if current_user.is_admin or current_user.is_super_admin:
        return current_user
    if current_user.ruolo == "mister":
        return current_user
    raise HTTPException(
        status_code=403,
        detail="Solo il mister o un amministratore possono gestire il calendario gare del torneo")


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


def _valida_mister(data: TorneoIn, db: Session, societa_id):
    """Pulisce e valida il mister del torneo; restituisce (mister_id, mister_manuale).

    Le due fonti si escludono: o una persona censita, o un nome scritto a mano per
    l'accompagnatore non censito. Accettarle entrambe e decidere quale delle due stampare
    vorrebbe dire consegnare all'organizzatore un documento con un referente scelto in silenzio.

    Il tenant si controlla qui e non ci si fida del client: mister_id arriva dalla richiesta e,
    senza questo controllo, passando l'id di un utente di un'altra societa' (sono sequenziali) si
    leggerebbe il suo nome nel PDF. Il controllo sul ruolo e' lo stesso elenco che la pagina usa
    per riempire il menu a tendina, cosi' non succede che la pagina offra un valore che il backend
    rifiuta o viceversa.
    """
    manuale = (data.mister_manuale or "").strip() or None
    mister_id = int(data.mister_id) if data.mister_id else None
    if manuale and mister_id:
        raise HTTPException(status_code=400,
                            detail="Indica un solo mister: quello a tendina oppure il nome scritto a mano")
    if manuale and len(manuale) > 100:
        # 100 e' la larghezza della colonna: oltre, sarebbe il database a rispondere 500 invece
        # di dirlo all'utente
        raise HTTPException(status_code=400, detail="Il nome del mister non puo' superare 100 caratteri")
    if mister_id:
        u = db.query(Utente).filter(Utente.id == mister_id).first()
        if not u:
            raise HTTPException(status_code=404, detail="Mister non trovato")
        if societa_id and u.societa_id != societa_id:
            raise HTTPException(status_code=403, detail="Non autorizzato su questo mister")
        if u.ruolo not in RUOLI_RESPONSABILI:
            raise HTTPException(status_code=400,
                                detail="Il mister del torneo deve essere un allenatore o un dirigente della societa'")
    return mister_id, manuale


def _dati_mister(t: Torneo, db: Session) -> dict:
    """I campi del mister gia' risolti, tutti insieme: la card, il modal e il PDF leggono questi.

    Il nome scritto a mano vince su mister_id: se il responsabile ne ha scritto uno, quello e' il
    referente che vuole sul documento. Si risolve qui e non lasciato comporre alle pagine perche'
    il PDF va consegnato, e due schermate che chiamano la stessa persona "Rossi" in un punto e
    "Mario Rossi" nell'altro e' il modo in cui nasce un documento incoerente.

    `mister_cellulare` viene esposto perche' il PDF del weekend stampa gia' il recapito del mister
    di ogni partita: qui e' lo stesso dato, la stessa persona, nello stesso tipo di documento che
    finisce all'organizzatore.
    """
    dati = {"mister_id": t.mister_id, "mister_manuale": t.mister_manuale,
            "mister_nome": None, "mister_cellulare": None}
    if t.mister_manuale and t.mister_manuale.strip():
        dati["mister_nome"] = t.mister_manuale.strip()
        return dati
    if t.mister_id:
        # nessuna FK (vedi modello): l'utente puo' non esserci piu'. In quel caso mister_nome resta
        # None e la pagina scrive "da assegnare", invece di stampare un id orfano
        u = db.query(Utente).filter(Utente.id == t.mister_id).first()
        if u:
            nome = " ".join(x for x in [u.nome, u.cognome] if x).strip()
            dati["mister_nome"] = nome or None
            dati["mister_cellulare"] = u.cellulare
    return dati


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


def _mie_categorie(utente: Utente, db: Session) -> list:
    """Le categorie assegnate all'utente (`utente_categorie`), come elenco ordinato di id.

    E' la fonte del filtro di GET /tornei/. Si calcola QUI e non nella pagina perche' il filtro e' un
    PERMESSO: se lo calcolasse il client basterebbe chiamare l'API a mano per vedersi tutti i tornei
    della societa', ed e' esattamente la lezione gia' pagata sulle scritture delle convocazioni -- li'
    la guardia "c'era" nella visibilita' (le card di Scelta.vue) e non nel permesso, e dirigente/
    scouting/infermeria potevano cancellare un foglio di campionato.
    """
    return [r[0] for r in db.execute(text(
        "SELECT DISTINCT categoria_id FROM utente_categorie WHERE utente_id = :u ORDER BY categoria_id"
    ), {"u": utente.id}).fetchall()]


def _e_responsabile(utente: Utente) -> bool:
    """True se l'utente e' un responsabile dei tornei: `is_admin` O `is_super_admin`.

    Stesso criterio di `get_responsabile_tornei`, da cui il nome prende il senso, e per la stessa
    ragione scritta li': non usare `ruolo == "admin"` ne' `get_admin` di core.security,che guarda solo
    `is_admin` -- un super_admin con `is_admin = 0` resterebbe fuori da una funzione che per definizione
    gli spetta. Misurato su PROD il 25/11/2026: l'account del titolare ha `ruolo='admin'` ma le due
    cose sono colonne distinte, e confonderle vorrebbe dire negargli l'interruttore "tutte le categorie"
    sulla pagina che gli serve per creare i tornei.
    """
    return bool(utente.is_admin or utente.is_super_admin)


RUOLI_VEDONO_TUTTI_I_TORNEI = ("segreteria",)
"""Ruoli che, OLTRE ai responsabili, vedono di default tutti i tornei della societa' e hanno
l'interruttore "tutte le categorie" (scelta del titolare, 2026-11-25: «anche il profilo segreteria puo'
vedere come l'admin»).

**E' un elenco di LETTURA, non di scrittura.** Non confonderlo con `RUOLI_GESTIONE_LISTA`
(`liste_tornei.py`, che include gia' `segreteria`) ne' con `get_responsabile_tornei` (che e' chi crea,
modifica ed elimina i tornei): la segreteria guarda i calendari per preparare le liste e le convocazioni,
non decide quali tornei esistono. Se un giorno qualcuno aggiunge `segreteria` a un gate di scrittura
"perche' tanto vede gia' tutto", quella e' la regressione da rifiutare -- e' la stessa distinzione per cui
`get_gestore_gare_torneo` e' separato da `get_responsabile_tornei`.
"""


def _vede_tutti_i_tornei(utente: Utente) -> bool:
    """Chi vede tutti i tornei della societa' di default, e puo' quindi chiedere `scope=tutte_categorie`.

    Responsabili + i ruoli di `RUOLI_VEDONO_TUTTI_I_TORNEI`. Misurato su PROD il 25/11/2026, il caso che
    rende necessaria la seconda meta': `stefaniafiorini8@gmail.com` ha `ruolo='segreteria'` e **zero**
    categorie in `utente_categorie`; con il solo filtro per assegnazione si sarebbe trovata una pagina
    vuota, e la segreteria e' proprio chi quelle liste le prepara.
    """
    return _e_responsabile(utente) or (utente.ruolo in RUOLI_VEDONO_TUTTI_I_TORNEI)


@router.get("/")
def lista_tornei(
    categoria_id: Optional[int] = None,
    societa_id: Optional[int] = Query(None),
    da: Optional[date] = None,
    a: Optional[date] = None,
    scope: Optional[str] = Query(None),
    request: Request = None,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    """I tornei di chi chiede, **per default solo quelli delle sue categorie**.

    **RIBALTAMENTO di una decisione precedente, registrato perche' era una scelta e non una svista.**
    Il 2026-11-16 il titolare aveva deciso il contrario: «i mister vedono e usano legittimamente tutte
    le categorie della propria societa' (in media hanno una sola riga di assegnazione). Filtrare qui per
    assegnazione li terrebbe fuori». Il 2026-11-25 la richiesta e' opposta: «in Convocazioni Tornei i
    Mister devono vedere solo i tornei della propria categoria, non di tutte», con l'eccezione subito
    aggiunta: «anche il profilo segreteria puo' vedere come l'admin».

    La premessa di allora oggi non regge piu' nei dati, misurata su PROD il 25/11/2026: **tutti e 8 i
    mister hanno almeno una categoria in `utente_categorie`** (nessuno a zero, quindi nessuno resta
    fuori), e **tutti e 10 i tornei hanno almeno una categoria iscritta** in `tornei_categorie` (quindi
    nessun calendario sparisce perche' orfano). Con il filtro ogni mister passa da 10 tornei a 3-5.

    Perche' nel backend e non nella pagina: vedi `_mie_categorie`. Il filtro deve essere un permesso.

    `scope`:
      - assente o `"mie_categorie"` -> solo i tornei iscritti a una delle categorie di chi chiede;
      - `"tutte_categorie"` -> tutti i tornei della societa', **ma solo per chi e' coperto da
        `_vede_tutti_i_tornei`** (responsabili e `segreteria`). Un mister che lo manda riceve comunque la
        lista filtrata: e' l'unico modo perche' l'interruttore "tutte le categorie" della pagina non
        diventi una scorciatoia utilizzabile da chiunque conosca l'URL.
      - un valore sconosciuto da' **400**, non un silenzio: uno `scope=tutte` scritto male che passasse
        come "filtrato" sarebbe un comportamento plausibile e falso, e il contrario sarebbe una
        escalation silenziosa.

    Il caso "nessuna categoria assegnata" ha due risposte **diverse di proposito**, perche' le due
    persone hanno due bisogni opposti:
      - chi **vede tutti i tornei** (`_vede_tutti_i_tornei`) e non ha assegnazioni -- misurato:
        `gresamor8277@gmail.com` (l'account del titolare, `ruolo='admin'`), `admin`, e
        `stefaniafiorini8@gmail.com` (`segreteria`) -- vede **tutti** i tornei. Lasciarlo con la pagina
        vuota vorrebbe dire bloccare chi i tornei li crea, li iscrive o ci prepara le liste: sembrerebbe
        che li abbia cancellati qualcuno.
      - **un mister** senza categorie vede **lista vuota**. Qui il silenzio sarebbe la direzione
        sbagliata: la pagina lo deve dire, perche' una lista vuota senza motivo assomiglia a "i tornei
        sono stati cancellati". Un mister senza categorie non ha una squadra da portare al torneo.

    La lista resta una **lista nuda**, non un oggetto `{tornei, meta}`: decine di asserzioni fra
    `test_tornei.sh`, `test_tornei_categorie.sh`, `test_tornei_sezioni.sh` e `ui_tornei.cjs` la leggono
    come tale, e `gare_per_categoria`/`gare_orfane` sono campi di QUEGLI elementi. Il "perche' sto
    vedendo questo" lo costruisce la pagina con dati suoi legittimi (e` presentazione); qui sta solo il
    permesso.
    """
    sid = get_societa_filter(current_user, societa_id, request)
    query = db.query(Torneo)
    if sid:
        query = query.filter(Torneo.societa_id == sid)

    # --- il filtro per le categorie di chi chiede ---
    scope_norm = (scope or "mie_categorie").strip().lower()
    if scope_norm not in ("mie_categorie", "tutte_categorie"):
        raise HTTPException(
            status_code=400,
            detail="scope ammessi: 'mie_categorie' (default) o 'tutte_categorie' (solo responsabili e segreteria)")
    vede_tutti = _vede_tutti_i_tornei(current_user)
    mie = _mie_categorie(current_user, db)
    if scope_norm == "tutte_categorie" and vede_tutti:
        passa_tutte = True
    elif not mie:
        # chi vede tutto non resta fuori perche' non ha assegnazioni; un mister senza categorie si'
        passa_tutte = vede_tutti
    else:
        passa_tutte = False
    if not passa_tutte:
        if not mie:
            # Non e' un errore e non e' "tutti": e' "non hai categorie, non hai tornei". La pagina deve
            # dirlo, perche' una lista vuota senza motivo assomiglia a "i tornei sono stati cancellati"
            return []
        # OR di parametri legati, non `IN :lista` e non `= ANY(:lista)`: la seconda dipende da come
        # psycopg2 adatta una lista, e una lista adattata male diventa una stringa dentro l'SQL -- un
        # errore che si vede solo alla prima categoria con la virgola dentro. Le categorie di un utente
        # sono poche, quindi il numero di rami e' limitato dai dati, non da un input
        rami = " OR ".join(f"tc.categoria_id = :mc{i}" for i in range(len(mie)))
        params = {f"mc{i}": c for i, c in enumerate(mie)}
        query = query.filter(text(
            f"EXISTS (SELECT 1 FROM tornei_categorie tc WHERE tc.torneo_id = tornei.id AND ({rami}))"
        ).bindparams(**params))

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
        categorie = _categorie_iscritte(t.id, db)
        # Il conteggio delle gare non puo' essere un numero solo: nella pagina suddivisa per
        # categorie, dire "6 gare" dentro la sezione Pulcini e' falso se 4 sono degli Esordienti.
        # Si contano per categoria qui, perche' il calendario vero arriva solo quando lo si apre
        # (GET /tornei/{id}) e chiederlo per ogni card significherebbe N richieste per dipingere
        # dei numeri.
        righe_gare = db.execute(text(
            "SELECT categoria_id, count(*) FROM tornei_gare WHERE torneo_id = :tid GROUP BY categoria_id"
        ), {"tid": t.id}).fetchall()
        gare_per_categoria = {str(r[0]): r[1] for r in righe_gare if r[0] is not None}
        # Orfana non e' solo la gara con la categoria NULL: e' anche quella che punta a una
        # categoria che NON risulta piu' iscritta (dati nati prima della migrazione, o un'iscrizione
        # sciolta a mani nude sul DB). Quella categoria non ha una sezione dove comparire, quindi
        # contarla solo come NULL darebbe "0 gare senza categoria" accanto a una gara elencata lo
        # stesso, che e' il tipo di bug che si vede solo dopo mesi
        iscritte = {str(c["id"]) for c in categorie}
        gare_orfane = sum(
            r[1] for r in righe_gare
            if r[0] is None or str(r[0]) not in iscritte
        )
        risultati.append({
            "id": t.id,
            "nome": t.nome,
            "categoria_id": t.categoria_id,
            "categorie": categorie,
            "societa_id": t.societa_id,
            "data_inizio": t.data_inizio.isoformat() if t.data_inizio else None,
            "data_fine": t.data_fine.isoformat() if t.data_fine else None,
            "luogo": t.luogo,
            "organizzatore": t.organizzatore,
            "descrizione": t.descrizione,
            **_dati_mister(t, db),
            "gare": sum(r[1] for r in righe_gare),
            "gare_per_categoria": gare_per_categoria,
            "gare_orfane": gare_orfane,
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
        **_dati_mister(torneo, db),
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
    mister_id, mister_manuale = _valida_mister(data, db, societa_id)
    torneo = Torneo(
        societa_id=societa_id,
        categoria_id=categorie_ids[0],
        nome=data.nome.strip(),
        data_inizio=data.data_inizio,
        data_fine=data.data_fine,
        luogo=data.luogo,
        organizzatore=data.organizzatore,
        descrizione=data.descrizione,
        mister_id=mister_id,
        mister_manuale=mister_manuale,
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
    # Il mister si sovrascrive sempre, come gli altri campi anagrafici: il modal manda la scheda
    # completa, quindi "campo assente" qui vuol dire "il responsabile lo ha tolto", non "non lo
    # so". Valutare la differenza significherebbe non poter mai togliere un mister sbagliato.
    torneo.mister_id, torneo.mister_manuale = _valida_mister(data, db, torneo.societa_id)
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
                  current_user: Utente = Depends(get_gestore_gare_torneo)):
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
                  current_user: Utente = Depends(get_gestore_gare_torneo)):
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
                 current_user: Utente = Depends(get_gestore_gare_torneo)):
    _get_torneo(torneo_id, current_user, db)
    n = db.execute(text("DELETE FROM tornei_gare WHERE id = :g AND torneo_id = :t"),
                   {"g": gara_id, "t": torneo_id}).rowcount
    db.commit()
    if not n:
        raise HTTPException(status_code=404, detail="Gara non trovata in questo torneo")
    return {"ok": True}
