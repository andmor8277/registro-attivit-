"""Imposta la scadenza del certificato medico per TUTTE le persone di una categoria.

Perche' un metodo ristretto e non la UI
---------------------------------------
La schermata Certificati Medici (`features/infermeria/CertificatoMedico.vue`) modifica UNA persona
alla volta con `PATCH /persone/{id}/certificato`, e non esiste un'azione di massa. Fare 33 click a
mano e' il modo normale in cui si sbaglia una riga, e qui le righe sono i certificati medici di
ragazzi minorenni: la data scritta qui e' l'unica cosa che fa risultare un ragazzo "Valido" invece
di "Senza certificato".

Cosa controlla, e perche' proprio queste verifiche
--------------------------------------------------
Le due categorie "Esordienti" (2014 e 2015) hanno lo STESSO nome e cambiano solo per `anno`, e su
PROD ne esistono tre chiamate "Esordienti" (2013 archiviata, 2014 archiviata, 2015 attiva): un
`categoria_id` sbagliato di uno aggiorna la squadra sbagliata senza che nessuna query sembri strana.
Per questo il nome e l'anno vanno passati e devono corrispondere, e una categoria archiviata viene
rifiutata (una stagione chiusa non riceve certificati nuovi).

Scrive UNA sola colonna (`scadenza_certificato`), mai `scadenza_certificato_2`, che la UI non legge.
Tutto in un solo transaction: le verifiche si fanno sulle righe gia' aggiornate ma PRIMA della
commit, e se anche una sola non passa si fa rollback. Il conteggio "nessun altro e' stato toccato"
confronta le righe con quella data su tutta la tabella, prima e dopo: e' l'unico modo di accorgersi
che il WHERE ha colpito piu' del previsto.

Uso (dentro il container backend, da /app)
------------------------------------------
    python - dry   <categoria_id> <AAAA-MM-GG> <nome-atteso> <anno-atteso>
    python - apply <categoria_id> <AAAA-MM-GG> <nome-atteso> <anno-atteso>

Fuori dal container usare `scripts/ops/set_scadenza_certificati.sh dev|prod <id> <data> <nome> <anno>`,
che fa prima il backup verificato.
"""
import sys
from datetime import date, datetime

from sqlalchemy import text

from app.database import SessionLocal

# argv: [modo, categoria_id, data, nome_atteso, anno_atteso]
MODO = (sys.argv[1] if len(sys.argv) > 1 else "dry").lower()
if len(sys.argv) < 6:
    print("  uso: python - dry|apply <categoria_id> <AAAA-MM-GG> <nome-atteso> <anno-atteso>")
    sys.exit(2)
CAT = int(sys.argv[2])
DATA = datetime.strptime(sys.argv[3], "%Y-%m-%d").date()
ATTESO_NOME = sys.argv[4].strip().lower()
ATTESO_ANNO = sys.argv[5].strip()

rosso = []  # una lista perche' ck deve poter incrementare il contatore senza `global`


def ck(nome, reale, atteso):
    """Due valori vuoti NON sono un 'ok': e' il bug che in altri test di qui ha reso verdi
    asserzioni che non avevano niente da confrontare (vedi test_tornei_mister.sh)."""
    reale_s = "NULL" if reale is None else str(reale)
    atteso_s = "NULL" if atteso is None else str(atteso)
    ok = reale_s == atteso_s and reale_s not in ("", "NULL")
    if not ok:
        rosso.append(nome)
    print(f"  {'ok  ' if ok else 'FAIL'} {nome}" + ("" if ok else f" -> '{reale_s}' (atteso '{atteso_s}')"))


db = SessionLocal()
try:
    # --- 1. la categoria deve essere quella che chi chiama crede, non "una" categoria ---
    cat = db.execute(text(
        "SELECT id, nome, anno::text AS anno, societa_id, is_archiviata, is_portieri "
        "FROM categorie WHERE id = :c"), {"c": CAT}).fetchone()
    if not cat:
        print(f"  CATEGORIA {CAT} INESISTENTE: nessun aggiornamento")
        sys.exit(1)
    print(f"  categoria {cat.id} = \"{cat.nome}\" anno={cat.anno} societa={cat.societa_id} "
          f"archiviata={cat.is_archiviata} portieri={cat.is_portieri}")
    # Sono STAMPE DI BLOCCO con exit, non asserzioni ck. La differenza e' il punto: un'asserzione
    # registra il rosso e prosegue, e qui "prosegue" vuol dire scrivere i certificati medici della
    # squadra sbagliata. Misurato: con l'anno dichiarato sbagliato, la versione con ck arrivava fino
    # all'UPDATE e si fermava solo perche' un'altra verifica e scattata per caso (il conteggio delle
    # righe non coincideva). Se il conteggio fosse coinciso, la scrittura sarebbe passata.
    if str(cat.nome).strip().lower() != ATTESO_NOME:
        print(f"  FERMO: la categoria {CAT} si chiama \"{cat.nome}\", tu hai dichiarato \"{ATTESO_NOME}\".")
        print("       Sono due categorie diverse, oppure l'id e' sbagliato. Nessuna scrittura.")
        sys.exit(1)
    if str(cat.anno) != ATTESO_ANNO:
        print(f"  FERMO: la categoria {CAT} (\"{cat.nome}\") ha anno {cat.anno}, tu hai dichiarato {ATTESO_ANNO}.")
        print("       E' esattamente la trappola delle due 'Esordienti' 2014/2015: stesso nome, cambia solo")
        print("       l'anno, e un id sbagliato di uno aggiorna la squadra sbagliata senza errori visibili.")
        sys.exit(1)
    if cat.is_archiviata:
        print("  FERMO: categoria archiviata. Una stagione chiusa non riceve certificati nuovi: "
              "se e' davvero voluto, farlo a mano sulla singola riga")
        sys.exit(1)

    # --- 2. data plausibile ---
    oggi = date.today()
    if DATA.year < 2000 or DATA.year > 2100:
        print(f"  FERMO: data {DATA} fuori dall'intervallo plausibile (2000-2100), probabilmente un refuso")
        sys.exit(1)
    if DATA < oggi:
        print(f"  ATTENZIONE: {DATA} e' nel passato. Tutte le righe risulteranno SCADUTE. "
              "Se cercavi un anno diverso, fermati ora (Ctrl+C non serve: non ho ancora scritto)")

    # --- 3. lo stato prima ---
    prima = db.execute(text(
        "SELECT count(*) AS totali, "
        "  count(*) FILTER (WHERE scadenza_certificato IS NULL) AS nulli, "
        "  count(*) FILTER (WHERE scadenza_certificato < current_date) AS scadute, "
        "  count(*) FILTER (WHERE scadenza_certificato >= current_date) AS valide, "
        "  min(scadenza_certificato)::text AS min, max(scadenza_certificato)::text AS max "
        "FROM persone WHERE categoria_id = :c AND societa_id = :s"),
        {"c": CAT, "s": cat.societa_id}).fetchone()
    print(f"  prima: totali={prima.totali} senza={prima.nulli} scadute={prima.scadute} "
          f"valide={prima.valide} min={prima.min} max={prima.max}")
    if prima.totali == 0:
        print("  FERMO: la categoria non ha persone. O l'id e' sbagliato, o non c'e' nulla da fare")
        sys.exit(1)

    # Quante righe HANNO GIA' quella data FUORI dalla categoria. Si misura il "fuori" e non il totale:
    # confrontare il totale con (totale_prima + righe_aggiornate) e' un falso verde strutturale, perche'
    # quel numero cresce insieme all'UPDATE. Se il WHERE trabocca, agg e il totale crescono insieme e
    # l'asserzione resta verde esattamente nel caso in cui dovrebbe diventare rossa.
    fuori_prima = db.execute(text(
        "SELECT count(*) FROM persone WHERE scadenza_certificato = :d "
        "  AND categoria_id IS DISTINCT FROM :c"), {"d": DATA, "c": CAT}).scalar()
    soc2_prima = db.execute(text(
        "SELECT count(*) FROM persone WHERE scadenza_certificato_2 IS NOT NULL")).scalar()
    membri_prima = prima.totali

    # cosa cambiera' davvero
    verrebbero = db.execute(text(
        "SELECT count(*) FROM persone WHERE categoria_id = :c AND societa_id = :s "
        "  AND (scadenza_certificato IS DISTINCT FROM :d)"),
        {"c": CAT, "s": cat.societa_id, "d": DATA}).scalar()
    print(f"  righe che cambiano: {verrebbero} su {prima.totali} "
          f"(gia' cosi': {prima.totali - verrebbero})")

    if MODO != "apply":
        print("\n  DRY-RUN: nessuna scrittura. Per applicare: ... apply "
              f"{CAT} {DATA} {ATTESO_NOME} {ATTESO_ANNO}")
        sys.exit(0)

    # --- 4. scrittura: un solo transaction, verifiche prima del commit ---
    print(f"\n  --- applico: UPDATE scadenza_certificato = {DATA} su categoria {CAT} ---")
    res = db.execute(text(
        "UPDATE persone SET scadenza_certificato = :d "
        "WHERE categoria_id = :c AND societa_id = :s"), {"d": DATA, "c": CAT, "s": cat.societa_id})
    agg = res.rowcount
    print(f"  righe aggiornate: {agg}")

    ck("righe aggiornate quante previsto", agg, verrebbero)
    dopo_cat = db.execute(text(
        "SELECT count(*) AS totali, "
        "  count(*) FILTER (WHERE scadenza_certificato = :d) AS con_data, "
        "  count(*) FILTER (WHERE scadenza_certificato IS NULL) AS nulli "
        "FROM persone WHERE categoria_id = :c AND societa_id = :s"),
        {"c": CAT, "s": cat.societa_id, "d": DATA}).fetchone()
    ck("tutte le persone della categoria hanno la nuova data", dopo_cat.con_data, prima.totali)
    ck("nessuna persona della categoria resta senza data", dopo_cat.nulli, 0)
    ck("la categoria non ha perso o guadagnato membri", dopo_cat.totali, membri_prima)

    fuori_dopo = db.execute(text(
        "SELECT count(*) FROM persone WHERE scadenza_certificato = :d "
        "  AND categoria_id IS DISTINCT FROM :c"), {"d": DATA, "c": CAT}).scalar()
    ck("nessuna riga FUORI dalla categoria ha quella data (il WHERE non ha traboccato)",
       fuori_dopo, fuori_prima)
    soc2_dopo = db.execute(text(
        "SELECT count(*) FROM persone WHERE scadenza_certificato_2 IS NOT NULL")).scalar()
    ck("scadenza_certificato_2 non e' stata toccata", soc2_dopo, soc2_prima)

    if rosso:
        db.rollback()
        print(f"\n  {len(rosso)} VERIFICHE ROSSE: ROLLBACK, niente e' stato scritto")
        for r in rosso: print(f"     ! {r}")
        sys.exit(1)

    db.commit()
    print("\n  commit eseguita")

    # --- 5. rilettura a freddo, dopo il commit ---
    dopo = db.execute(text(
        "SELECT count(*) AS totali, "
        "  count(*) FILTER (WHERE scadenza_certificato = :d) AS con_data, "
        "  count(*) FILTER (WHERE scadenza_certificato IS NULL) AS nulli, "
        "  count(*) FILTER (WHERE scadenza_certificato >= current_date) AS valide "
        "FROM persone WHERE categoria_id = :c AND societa_id = :s"),
        {"c": CAT, "s": cat.societa_id, "d": DATA}).fetchone()
    print(f"  dopo: totali={dopo.totali} con_la_data={dopo.con_data} senza={dopo.nulli} "
          f"valide_a_schermo={dopo.valide}")
    ck("a freddo: le righe con la data sono tutte", dopo.con_data, dopo.totali)

    if rosso:
        print(f"\n  {len(rosso)} verifiche rosse DOPO il commit: il backup verificato e' l'unica strada")
        for r in rosso: print(f"     ! {r}")
        sys.exit(1)
    print("\n  fatto.")
finally:
    db.close()
