#!/usr/bin/env python3
"""Applica UNA mutazione nota a Registro.vue / RegistroPrintSheet.vue, e ripristina lo snapshot.

Perche' un file separato e non un `sed` dentro lo shell: le sostituzioni contengono apici, doppi apici,
parentesi e `=>`. In bash sarebbero una gara di escaping, e una gara di escaping persa produce la
peggior cosa possibile qui -- una mutazione che NON parte e un negative test verde. Questo script, se
l'ancoraggio non c'e' o compare piu' di una volta, **esce con un codice diverso da zero dicendo perche'**,
e il wrapper tratta quel codice come "la mutazione non e' partita", non come "il test e' verde".

Il pristino e' uno SNAPSHOT in /tmp, NON il commit: queste due file hanno lavoro non commesso sopra, e
un `git checkout --` che "ripristina il pristino" si porterebbe via la feature intera. Lo snapshot si
fa con `prepara` (sempre da zero, mai `|| cp`: un backup gia' esistente sarebbe il file GIA' MUTATO del
giro precedente) e `ripristina` verifica l'hash contro quello registrato in `prepara`.

  python3 muta_registro.py prepara
  python3 muta_registro.py applica <nome>
  python3 muta_registro.py ripristina
  python3 muta_registro.py hash
  python3 muta_registro.py lista
"""
import hashlib
import os
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(BASE, "..", ".."))
FRONT = os.path.join(ROOT, "frontend", "src", "features", "presenze")
REGISTRO = os.path.join(FRONT, "Registro.vue")
FOGLIO = os.path.join(FRONT, "RegistroPrintSheet.vue")
BK = "/tmp/opencode/bk-registro"
PRISTINO = os.path.join(BK, "pristino.sha")

# Le mutazioni. Ognuna e' una regressione che il test ESISTE per beccare: non sono "cose casuali da
# rompere", sono le tre maniere in cui questa modifica si guasta senza che nessun build se ne accorga,
# piu' i due requisiti del titolare (3 colonne in verticale, e il default settimana sul telefono).
MUTAZIONI = {
    # 1. la vista settimana mostra ancora il mese: e' esattamente cio' che il titolare si lamentava di
    #    vedere, e il pulsante "Settimana" a schermo ci sarebbe comunque
    "settimana-a-mese": [
        (REGISTRO,
         "const giorniVisibili = computed(() => vista.value === 'settimana' ? giorniSettimanaFiltrati.value : giorniMese.value)",
         "const giorniVisibili = computed(() => giorniMese.value)"),
    ],
    # 2. il foglio di stampa scivola dietro la vista settimana: a schermo tutto giusto, e in segreteria
    #    arriva un foglio "Registro di Novembre" con dentro una settimana sola. Le due occorrenze SONO
    #    lo stesso difetto: l'anteprima e il foglio reale, che sono due markup e devono divergere insieme
    "foglio-segue-lo-schermo": [
        (REGISTRO, ':giorni="giorniMese"', ':giorni="giorniVisibili"', 2),
    ],
    # 3. le celle cercate per NUMERO di giorno invece che per data: il 30 novembre legge (e scrive) il
    #    30 dicembre. E' la regressione silenziosa per eccellenza: due numeri identici, due date diverse
    "celle-per-numero": [
        (REGISTRO,
         "  return registro.value.find(r => r.persona_id === personaId && r.data === data)\n"
         "    || registroExtra.value.find(r => r.persona_id === personaId && r.data === data)",
         "  const numerica = isoDi(anno.value, mese.value, Number(String(data).slice(8, 10)))\n"
         "  return registro.value.find(r => r.persona_id === personaId && r.data === numerica)\n"
         "    || registroExtra.value.find(r => r.persona_id === personaId && r.data === numerica)"),
        (REGISTRO,
         "data: g.data, codice, categoria_id: categoriaId.value",
         "data: isoDi(anno.value, mese.value, g.num), codice, categoria_id: categoriaId.value"),
    ],
    # 4. il mese accanto fuso nei totali: il TOT direbbe 2 dove il mese ha 1, e lo stesso numero
    #    sbagliato uscirebbe dal foglio di stampa
    "totali-fusi": [
        (REGISTRO,
         '  return registro.value.filter(r => r.persona_id === personaId && ["X","R"].includes(r.codice)',
         '  return righeRegistro().filter(r => r.persona_id === personaId && ["X","R"].includes(r.codice)'),
    ],
    # 5. sul telefono si apre di nuovo il mese: il requisito ("si apre la settimana, 3 caselle") cade
    #    senza che nessuno abbia toccato la tabella
    "default-mese": [
        (REGISTRO,
         "const vista = ref(window.innerWidth <= 768 ? 'settimana' : 'mese')",
         "const vista = ref('mese')"),
    ],
}


def leggi(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def scrivi(p, t):
    with open(p, "w", encoding="utf-8") as f:
        f.write(t)


def hash_file(p):
    return hashlib.sha256(leggi(p).encode("utf-8")).hexdigest()[:16]


def hash_tutti():
    return hash_file(REGISTRO) + " " + hash_file(FOGLIO)


def prepara():
    # SEMPRE da zero: `[ -f bk ] || cp` riuserebbe il pristino del giro precedente, che dopo una
    # mutazione sarebbe il file MUTATO. E' il falso verde del backup con `||`, gia' costato lavoro
    #
    # E non basta "da zero": lo snapshot e' fedele a cio' che c'e' sul DISCO, quindi se il disco e' gia'
    # mutato (un giro interrotto, una `applica` lanciata a mano per capire perche' un rosso non arrivava)
    # lo snapshot "pristino" e' il file mutato e ogni `ripristina` successivo riporta li', in silenzio.
    # E' successo: la mutazione `celle-per-numero` era rimasta a meta' sul disco, lo snapshot l'ha
    # battezzata pristino, e `ripristina` ha detto "verificato per hash" su un file manomesso.
    # Quindi: se una delle sostituzioni e' GIA' nel file, il file non e' pristino e lo snapshot non si fa.
    sporche = []
    for nome, tappe in MUTAZIONI.items():
        for tappa in tappe:
            percorso, nuovo = tappa[0], tappa[2]
            if nuovo in leggi(percorso):
                sporche.append("%s in %s (mutazione '%s')"
                               % (nuovo.replace("\n", " <a capo> ")[:60], os.path.basename(percorso), nome))
    if sporche:
        print("  BLOCCATO: il file sul disco contiene gia' una sostituzione di una mutazione:")
        for s in sporche:
            print("    - " + s)
        print("  Lo snapshot registrerebbe come PRISTINO un file manomesso, e ogni `ripristina` successivo")
        print("  riporterebbe li' dicendo 'verificato per hash'. Prima: python3 muta_registro.py ripristina")
        print("  (se lo snapshot di /tmp/opencode/bk-registro e' a sua volta sporco, servirebbe il file")
        print("  vero: e' lavoro non commesso, quindi NON va ripristinato con git checkout)")
        return 7
    os.makedirs(BK, exist_ok=True)
    for f in os.listdir(BK):
        os.remove(os.path.join(BK, f))
    for p in (REGISTRO, FOGLIO):
        with open(leggi_path(p), "rb") as src, open(os.path.join(BK, os.path.basename(p)), "wb") as dst:
            dst.write(src.read())
    with open(PRISTINO, "w") as f:
        f.write(hash_tutti() + "\n")
    print("  snapshot preso da zero: " + hash_tutti() + "  -> " + BK)
    return 0


def leggi_path(p):
    return p


def ripristina(verifica=True):
    for nome in ("Registro.vue", "RegistroPrintSheet.vue"):
        src = os.path.join(BK, nome)
        if not os.path.exists(src):
            print("  RIPRISTINO IMPOSSIBILE: manca lo snapshot " + src)
            print("  senza ripristino verificato il giro NON vale: rilancia con `prepara`")
            return 5
    scrivi_bytes(os.path.join(BK, "Registro.vue"), REGISTRO)
    scrivi_bytes(os.path.join(BK, "RegistroPrintSheet.vue"), FOGLIO)
    adesso = hash_tutti()
    if verifica:
        atteso = ""
        if os.path.exists(PRISTINO):
            atteso = open(PRISTINO).read().strip()
        if atteso and adesso != atteso:
            print("  RIPRISTINO NON VERIFICATO: hash " + adesso + ", lo snapshot diceva " + atteso)
            return 6
    print("  ripristinato e verificato per hash: " + adesso)
    return 0


def scrivi_bytes(src, dst):
    with open(src, "rb") as f:
        dati = f.read()
    with open(dst, "wb") as f:
        f.write(dati)


def applica(nome):
    if nome not in MUTAZIONI:
        print("  mutazione sconosciuta: '%s'. Disponibili: %s" % (nome, ", ".join(sorted(MUTAZIONI))))
        return 2
    tappe = MUTAZIONI[nome]

    # PASSO 1 -- verifica preliminare SENZA scrivere niente: se un ancoraggio manca o ha il conteggio
    # sbagliato, la mutazione non deve essere applicata nemmeno in parte (meta' mutazione applicata e
    # meta' no lascia il file in uno stato che nessuno dei due casi descrive)
    for tappa in tappe:
        percorso, vecchio = tappa[0], tappa[1]
        attese = tappa[3] if len(tappa) > 3 else 1   # 2 = le due occorrenze sono lo stesso difetto
        n = leggi(percorso).count(vecchio)
        if n == 0:
            print("  SCRITTA-MANCANTE in %s: l'ancoraggio non c'e' piu'" % os.path.basename(percorso))
            print("  La mutazione NON e' partita: un negative test verde, qui, sarebbe un falso verde")
            print("  ancoraggio: " + vecchio.replace("\n", " <a capo> ")[:160])
            return 3
        if n != attese:
            print("  ANCORAGGIO CONTEGGIO SBAGLIATO in %s: %d occorrenze, il file della mutazione ne dice %d"
                  % (os.path.basename(percorso), n, attese))
            print("  Non si sostituisce a caso: colpire un'occorrenza invece di un'altra chiama"
                  " 'una mutazione' un'altra cosa")
            return 3

    # PASSO 2 -- si applica UNA tappa alla volta, ognuna sul file COM'E' DOPO la precedente.
    # Leggere tutti i testi prima di scrivere (come faceva questa funzione) fa vincere l'ultima tappa,
    # che riscrive il file dalla versione iniziale e la prima sostituzione viene persa: la mutazione
    # esce PARTITA A META'. E' successo davvero con `celle-per-numero` -- cercaEntry restava pristina e
    # salvaPresenza era mutata -- e il negative test ha registrato un verde che non aveva misurato
    # niente, perche' l'unica asserzione che dipendeva dalla tappa persa e' rimasta verde.
    for tappa in tappe:
        percorso, vecchio, nuovo = tappa[0], tappa[1], tappa[2]
        attese = tappa[3] if len(tappa) > 3 else 1
        testo = leggi(percorso)
        if testo.count(vecchio) != attese:
            print("  MUTAZIONE NON PARTITA in %s: l'ancoraggio non c'e' piu' (l'ha gia' sostituito la tappa precedente?)"
                  % os.path.basename(percorso))
            return 4
        scritto = testo.replace(vecchio, nuovo)
        # si verifica che il NUOVO sia arrivato quante volte serve: "il vecchio non c'e' piu'" non
        # funziona quando il testo nuovo contiene il vecchio come sottostringa
        if scritto.count(nuovo) < attese:
            print("  MUTAZIONE NON PARTITA in %s: la sostituzione non ha prodotto il testo atteso"
                  % os.path.basename(percorso))
            return 4
        scrivi(percorso, scritto)

    # PASSO 3 -- ultima verifica SUL FILE FINALE: tutte le tappe devono essere presenti INSIEME.
    # E' il controllo che al primo giro mancava, e che ha lasciato passare la mutazione a meta'
    for tappa in tappe:
        percorso, nuovo = tappa[0], tappa[2]
        attese = tappa[3] if len(tappa) > 3 else 1
        if leggi(percorso).count(nuovo) < attese:
            print("  MUTAZIONE INCOMPLETA in %s: una tappa non e' arrivata al file finale"
                  % os.path.basename(percorso))
            print("  testo atteso: " + nuovo.replace("\n", " <a capo> ")[:160])
            return 5
    print("  mutazione '%s' applicata (%d tappe, tutte verificate sul file finale)" % (nome, len(tappe)))
    return 0


if __name__ == "__main__":
    azione = sys.argv[1] if len(sys.argv) > 1 else ""
    if azione == "prepara":
        sys.exit(prepara())
    if azione == "applica":
        sys.exit(applica(sys.argv[2] if len(sys.argv) > 2 else ""))
    if azione == "ripristina":
        sys.exit(ripristina())
    if azione == "hash":
        print(hash_tutti())
        sys.exit(0)
    if azione == "lista":
        print("\n".join(sorted(MUTAZIONI)))
        sys.exit(0)
    print(__doc__)
    sys.exit(2)
