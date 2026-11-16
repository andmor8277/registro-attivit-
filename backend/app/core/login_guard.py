"""Blocco dei tentativi di login sul singolo username, indipendente dall'indirizzo IP.

Perche' serve: il limiter slowapi conta per indirizzo (`get_remote_address`), ma openresty sta
sul router e ACCORPA l'header `X-Forwarded-For` invece di sostituirlo. Chi attacca si
attribuisce un IP diverso a ogni richiesta e il contatore per IP non lo ferma mai: verificato
in produzione, i log uvicorn registravano l'IP dichiarato dal client.

Questo modulo conta invece sull'username, che l'attaccante non puo' cambiare se il suo obiettivo
e' indovinare proprio quella password.

Il rovescio della medaglia va conosciuto, perche' e' una scelta e non un miglioramento gratuito:
sbagliando di proposito la password su un username noto si riesce a bloccare l'accesso
all'utente legittimo per il tempo del blocco. Per questo la soglia e' alta, il blocco e' breve,
e tutti e tre i valori si regolano via env senza toccare il codice.
"""
import os
import sys
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import text

# Tentativi concessi nella finestra prima di finire in blocco
MAX_TENTATIVI = int(os.getenv("LOGIN_MAX_TENTATIVI", "10"))
# Finestra, in minuti, entro la quale i tentativi si sommano
FINESTRA_MINUTI = int(os.getenv("LOGIN_FINESTRA_MINUTI", "15"))
# Durata, in minuti, del blocco una volta superata la soglia
BLOCCO_MINUTI = int(os.getenv("LOGIN_BLOCCO_MINUTI", "15"))


def _adesso():
    return datetime.now(timezone.utc)


def _avviso(cosa, errore):
    """Scrive l'avviso su stderr e subito flushato.

    print() su stdout, in un container senza TTY, e' bufferizzato a blocchi: l'avviso resterebbe
    nel buffer del worker e non comparirebbe mai in `docker compose logs`, cioe' il guasto di
    questa protezione resterebbe invisibile. stderr e' la stessa scelta gia' usata da uvicorn.
    """
    print(f"AVVISO login_guard: {cosa} ({type(errore).__name__}: {errore})", file=sys.stderr, flush=True)


def _ripristina(db):
    """Ripulisce la sessione dopo una query fallita.

    Serve perche' il login continua a usare la stessa sessione: se la transazione resta in stato
    "aborted" ogni query successiva fallisce e il fallimento aperto non evita il 500.
    """
    try:
        db.rollback()
    except Exception:
        pass


def _pulisci_vecchie(db):
    """Rimuove le righe troppo vecchie per contare ancora.

    Senza questa pulizia la tabella crescerebbe per sempre: ogni username provato, anche
    inesistente, lascia una riga. Un attaccante che ne spara migliaia al minuto la ingrosserebbe
    senza fine. Si cancella solo cio' che non e' in blocco, quindi nessun utente legittimo perde
    la protezione.
    """
    limite = _adesso() - timedelta(minutes=FINESTRA_MINUTI)
    db.execute(
        text("DELETE FROM login_bloccaggi WHERE bloccato_sino IS NULL AND ultimo_tentativo < :limite"),
        {"limite": limite},
    )


def chiave_login(username):
    """Chiave di conteggio: l'username normalizzato.

    Si normalizza per non farsi aggirare scrivendo Mario@X invece di mario@x, che sono lo stesso
    account ma altrimenti avrebbero due contatori distinti.
    """
    return (username or "").strip().lower()[:255] or "(vuoto)"


def verifica_non_bloccato(db, username):
    """Alza 429 se l'username e' in blocco. Da chiamare prima di verificare le credenziali."""
    try:
        return _verifica_non_bloccato(db, username)
    except HTTPException:
        # il blocco che funziona: deve passare
        raise
    except Exception as e:
        # Fall-open deliberato. Se questa tabella non c'e' o la query fallisce, far esplodere il
        # login significherebbe tenere tutta l'azienda fuori dal sistema: verificato, senza tabella
        # ogni accesso risponde 500. Meglio un tentativo in piu' all'attaccante (resta il limiter
        # slowapi) che un disservizio totale. L'errore va pero' nei log, per non scoprirlo tra mesi.
        #
        # Il rollback NON e' opzionale: dopo una query fallita la transazione di SQLAlchemy resta
        # in stato "aborted" e la query successiva della rotta login fallirebbe a sua volta,
        # producendo comunque un 500. Senza rollback il fallimento aperto non apre niente.
        _avviso("controllo blocco non applicabile", e)
        _ripristina(db)
        return None


def _verifica_non_bloccato(db, username):
    chiave = chiave_login(username)
    riga = db.execute(
        text("SELECT tentativi, bloccato_sino FROM login_bloccaggi WHERE chiave = :k"),
        {"k": chiave}
    ).first()
    if not riga:
        return

    if riga.bloccato_sino and riga.bloccato_sino > _adesso():
        secondi = int((riga.bloccato_sino - _adesso()).total_seconds())
        minuti = max(1, (secondi + 59) // 60)
        raise HTTPException(
            status_code=429,
            detail=f"Troppi tentativi di accesso per questo utente. Riprova tra {minuti} minuti.",
            headers={"Retry-After": str(max(1, secondi))},
        )

    # Il blocco e' scaduto, oppure non c'era: si riparte puliti
    if riga.bloccato_sino is not None:
        db.execute(text("DELETE FROM login_bloccaggi WHERE chiave = :k"), {"k": chiave})
        db.commit()


def registra_tentativo_fallito(db, username):
    """Segna un tentativo errato e, superata la soglia, mette l'username in blocco."""
    try:
        return _registra_tentativo_fallito(db, username)
    except HTTPException:
        raise
    except Exception as e:
        _avviso("tentativo non registrato", e)
        _ripristina(db)
        return None


def _registra_tentativo_fallito(db, username):
    chiave = chiave_login(username)
    ora = _adesso()
    inizio_finestra = ora - timedelta(minutes=FINESTRA_MINUTI)

    riga = db.execute(
        text("SELECT tentativi, primo_tentativo FROM login_bloccaggi WHERE chiave = :k"),
        {"k": chiave}
    ).first()

    if riga is None or riga.primo_tentativo is None or _naif(riga.primo_tentativo) < _naif(inizio_finestra):
        # primo tentativo della finestra, o quella precedente e' troppo vecchia: si riparte da 1
        db.execute(
            text("""
                INSERT INTO login_bloccaggi (chiave, tentativi, primo_tentativo, ultimo_tentativo, bloccato_sino)
                VALUES (:k, 1, :ora, :ora, NULL)
                ON CONFLICT (chiave) DO UPDATE
                   SET tentativi = 1, primo_tentativo = :ora, ultimo_tentativo = :ora, bloccato_sino = NULL
            """),
            {"k": chiave, "ora": ora}
        )
    else:
        n = (riga.tentativi or 0) + 1
        bloccato = ora + timedelta(minutes=BLOCCO_MINUTI) if n >= MAX_TENTATIVI else None
        db.execute(
            text("""
                UPDATE login_bloccaggi
                   SET tentativi = :n, ultimo_tentativo = :ora, bloccato_sino = :b
                 WHERE chiave = :k
            """),
            {"n": n, "ora": ora, "b": bloccato, "k": chiave}
        )
    _pulisci_vecchie(db)
    db.commit()


def login_avvenuto(db, username):
    """Azzera il contatore dopo un accesso riuscito."""
    try:
        db.execute(text("DELETE FROM login_bloccaggi WHERE chiave = :k"), {"k": chiave_login(username)})
        db.commit()
    except Exception as e:
        _avviso("contatore non azzerato", e)
        _ripristina(db)


def _naif(dt):
    """Postgres puo' restituire datetime naive o aware a seconda della colonna: si confrontano
    tutti nello stesso modo, altrimenti il confronto tra naive e aware va in eccezione."""
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt
