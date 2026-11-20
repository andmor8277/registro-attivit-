"""Cifra i soli codici fiscali ancora in chiaro su `persone`, con la chiave attuale.

Perche' esiste
--------------
La rotta che sembrava fatta per questo, `PUT /persone/encryption-key?reencrypt=true`, NON e'
utilizzabile e non va usata: e' un endpoint di **rotazione di chiave**. `safe_decrypt_with_key`
rende `None` per qualunque valore sotto i 32 caratteri o non esadecimale (`core/encryption.py:57`),
quindi un codice fiscale in chiaro non si decifra mai; la riga 426 di `routers/persone.py` pero'
esegue comunque l'`UPDATE` su tutti e tre i campi non appena **uno** dei tre decifra, scrivendo
`NULL` negli altri due. Chiamarla sulla chiave attuale per "cifrare i CF rimasti in chiaro"
cancellerebbe i CF delle righe che hanno anche un telefono cifrato.

Cosa fa invece qui
------------------
Una colonna sola (`codice_fiscale`), solo le righe gia' in chiaro, la chiave gia' in uso, e tutto
in **un solo transaction**: le verifiche si fanno sulle righe aggiornate ma prima della commit, e
se anche una sola non passa si fa rollback. Nessun valore sensibile viene mai stampato: solo
conteggi, lunghezze e id.

Uso (dentro il container backend, da /app)
------------------------------------------
    python scripts/ops/cifra_cf_in_chiaro.py dry      # default: non scrive
    python scripts/ops/cifra_cf_in_chiaro.py apply    # scrive, ma solo se le verifiche passano

Fuori dal container, usare `scripts/ops/cifra_cf.sh dev|prod`, che fa il backup prima.

Gia' eseguito su DEV e PROD il 2026-11-20 (16 CF per ambiente). Idempotente: rilanciato non trova
nulla da fare.
"""
import os
import re
import sys

from sqlalchemy import text

from app.database import SessionLocal
from app.core import encryption as enc

MODO = (sys.argv[1] if len(sys.argv) > 1 else "dry").lower()

# Le righe da cifrare attese sono poche decine. Se ne vediamo molte di piu' qualcosa e' cambiato
# (per esempio la chiave non e' piu' quella dei dati) e rischieremmo di cifrare sopra del cifrato.
SOGLIA_MASSIMA = 40


def is_encrypted(v):
    """Esattamente il test che usa il percorso di lettura dell'app (encryption.safe_decrypt)."""
    return isinstance(v, str) and len(v) >= 32 and all(c in "0123456789abcdef" for c in v)


def classifica(db):
    righe = db.execute(text(
        "SELECT id, codice_fiscale, tel_papa, tel_mamma FROM persone ORDER BY id")).fetchall()
    cifrati, chiaro, nulli = [], [], []
    for r in righe:
        v = r.codice_fiscale
        if v is None or (isinstance(v, str) and v.strip() == ""):
            nulli.append(r.id)
        elif is_encrypted(v):
            cifrati.append(r.id)
        else:
            chiaro.append((r.id, v))
    return cifrati, chiaro, nulli


def fotografa(db):
    """Fotografia di cio' che NON dobbiamo toccare, da ricontrollare prima della commit."""
    r = db.execute(text("""
        SELECT count(*) FILTER (WHERE tel_papa  ~ '^[0-9a-f]+$' AND length(tel_papa)  >= 32) AS tp,
               count(*) FILTER (WHERE tel_mamma ~ '^[0-9a-f]+$' AND length(tel_mamma) >= 32) AS tm,
               count(*) FILTER (WHERE tel_papa  IS NOT NULL AND trim(tel_papa)  <> '') AS tp_any,
               count(*) FILTER (WHERE tel_mamma IS NOT NULL AND trim(tel_mamma) <> '') AS tm_any,
               (SELECT count(*) FROM persone)                AS tot,
               (SELECT count(*) FROM liste_torneo)           AS liste,
               (SELECT count(*) FROM liste_torneo_giocatori) AS giocatori
        FROM persone""")).fetchone()
    return dict(tp=r.tp, tm=r.tm, tp_any=r.tp_any, tm_any=r.tm_any,
                tot=r.tot, liste=r.liste, giocatori=r.giocatori)


def cf_di(db, persona_id):
    return db.execute(text("SELECT codice_fiscale FROM persone WHERE id = :i"),
                      {"i": persona_id}).scalar()


def main():
    print("  modalita':", MODO.upper())
    print("  chiave:", "presente" if enc.ENCRYPTION_KEY else "MANCANTE",
          "| pgcrypto:", enc.PGCRYPTO_AVAILABLE)
    if not enc.ENCRYPTION_KEY or not enc.PGCRYPTO_AVAILABLE:
        print("  FERMO: senza chiave o senza pgcrypto non si puo' cifrare")
        return 2

    db = SessionLocal()
    problemi = []
    try:
        prima_cifrati, prima_chiaro, prima_nulli = classifica(db)
        prima_altri = fotografa(db)
        print("  prima: %d cifrati, %d in chiaro, %d nulli/vuoti, %d righe"
              % (len(prima_cifrati), len(prima_chiaro), len(prima_nulli), prima_altri["tot"]))
        print("  id delle righe in chiaro:", [i for i, v in prima_chiaro])

        if not prima_chiaro:
            print("  niente da fare: nessun codice fiscale in chiaro")
            return 0
        if len(prima_chiaro) > SOGLIA_MASSIMA:
            print("  FERMO: %d righe in chiaro sono troppe (attese ~16)." % len(prima_chiaro))
            print("  Se la chiave fosse cambiata ogni valore sembrerebbe 'in chiaro' e")
            print("  cifreremmo sopra del cifrato gia' valido.")
            return 2
        for i, v in prima_chiaro:
            if v is None or v.strip() == "" or is_encrypted(v):
                print("  FERMO: riga %s classificata in chiaro per errore" % i)
                return 1

        # Guardia sulla chiave: se anche uno solo dei gia' cifrati non decifrasse, la chiave in
        # uso NON e' quella che ha cifrato quei dati. Con una chiave sbagliata la cifratura
        # funzionerebbe comunque e il round-trip sotto passerebbe comunque: e' l'unico controllo
        # che impedisce di ritrovarsi due chiavi diverse nello stesso campo.
        non_decifrano = [i for i in prima_cifrati
                         if not enc.safe_decrypt_with_key(db, cf_di(db, i), enc.ENCRYPTION_KEY)]
        if non_decifrano:
            print("  FERMO: %d dei %d CF gia' cifrati non decifrano con questa chiave (id %s)."
                  % (len(non_decifrano), len(prima_cifrati), non_decifrano))
            print("  La chiave in uso non e' quella che ha cifrato quei dati: non si aggiunge altro.")
            return 2
        print("  guardia chiave: tutti i %d CF gia' cifrati decifrano" % len(prima_cifrati))

        # 1) cifra in memoria e verifica il round-trip PRIMA di scrivere qualsiasi cosa
        nuovi = {}
        for i, v in prima_chiaro:
            cipher = enc.safe_encrypt_with_key(db, v, enc.ENCRYPTION_KEY)
            if not cipher or not is_encrypted(cipher):
                print("  FERMO: riga %s, cifratura non riuscita" % i)
                return 1
            if enc.safe_decrypt_with_key(db, cipher, enc.ENCRYPTION_KEY) != v:
                print("  FERMO: riga %s, il round-trip non ridade il valore originale" % i)
                return 1
            nuovi[i] = (v, cipher)
        print("  pronte da cifrare: %d/%d" % (len(nuovi), len(prima_chiaro)))

        if MODO != "apply":
            print("  dry-run: nessuna scrittura. Rilanciare con 'apply' per applicare.")
            return 0

        # 2) scrive una riga alla volta, solo la colonna codice_fiscale, e solo se a quel punto
        #    la riga e' ancora in chiaro (nel frattempo qualcuno potrebbe averla sistemata)
        for i, (v, cipher) in nuovi.items():
            ris = db.execute(text(
                "UPDATE persone SET codice_fiscale = :c "
                "WHERE id = :i AND codice_fiscale IS NOT NULL AND trim(codice_fiscale) <> '' "
                "AND NOT (length(codice_fiscale) >= 32 AND codice_fiscale ~ '^[0-9a-f]+$')"),
                {"c": cipher, "i": i})
            if ris.rowcount != 1:
                print("  ROLLBACK: riga %s, UPDATE non applicato (rowcount=%s)" % (i, ris.rowcount))
                db.rollback()
                return 1

        # 3) verifica SULLE RIGHE GIA' AGGIORNATE, ma prima della commit
        dopo_cifrati, dopo_chiaro, dopo_nulli = classifica(db)
        dopo_altri = fotografa(db)
        print("  dopo (in transazione): %d cifrati, %d in chiaro, %d nulli"
              % (len(dopo_cifrati), len(dopo_chiaro), len(dopo_nulli)))

        esiti = [
            ("nessun codice fiscale in chiaro", len(dopo_chiaro) == 0),
            ("cifrati = %d + %d = %d" % (len(prima_cifrati), len(nuovi),
                                         len(prima_cifrati) + len(nuovi)),
             len(dopo_cifrati) == len(prima_cifrati) + len(nuovi)),
            ("i nulli non sono cambiati (%d)" % len(prima_nulli),
             sorted(dopo_nulli) == sorted(prima_nulli)),
            ("numero di persone invariato (%d)" % prima_altri["tot"],
             dopo_altri["tot"] == prima_altri["tot"]),
            ("telefoni cifrati invariati (%d/%d)" % (prima_altri["tp"], prima_altri["tm"]),
             dopo_altri["tp"] == prima_altri["tp"] and dopo_altri["tm"] == prima_altri["tm"]),
            ("telefoni presenti invariati (%d/%d)" % (prima_altri["tp_any"], prima_altri["tm_any"]),
             dopo_altri["tp_any"] == prima_altri["tp_any"] and dopo_altri["tm_any"] == prima_altri["tm_any"]),
            ("liste torneo invariate (%d liste, %d giocatori)"
             % (prima_altri["liste"], prima_altri["giocatori"]),
             dopo_altri["liste"] == prima_altri["liste"]
             and dopo_altri["giocatori"] == prima_altri["giocatori"]),
        ]

        fedeli = sum(1 for i, (v, _cipher) in nuovi.items()
                     if enc.safe_decrypt_with_key(db, cf_di(db, i), enc.ENCRYPTION_KEY) == v)
        esiti.append(("tutti i %d valori rileggono identici all'originale" % len(nuovi),
                      fedeli == len(nuovi)))
        ancora_ok = sum(1 for i in prima_cifrati
                        if enc.safe_decrypt_with_key(db, cf_di(db, i), enc.ENCRYPTION_KEY))
        esiti.append(("i %d CF gia' cifrati decifrano ancora" % len(prima_cifrati),
                      ancora_ok == len(prima_cifrati)))

        rotti = 0
        for n, (msg, ok) in enumerate(esiti, 1):
            print("    [%2d %s] %s" % (n, "ok" if ok else "KO", msg))
            if not ok:
                rotti += 1
        if rotti:
            print("  ROLLBACK: %d verifiche fallite, nessuna modifica salvata" % rotti)
            db.rollback()
            return 1

        db.commit()
        print("  COMMIT: %d codici fiscali cifrati con la chiave attuale" % len(nuovi))
        return 0
    except Exception as e:
        db.rollback()
        print("  ECCEZIONE, rollback eseguito:", type(e).__name__, str(e)[:200])
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
