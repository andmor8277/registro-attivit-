#!/usr/bin/env python3
# Le mutazioni del negative test dell'export JPEG, in un posto solo (come muta_registro.py).
#
# Perche' un file a parte: le ancore sono frammenti di codice MINIFICATO. Scritte dentro il bash
# sarebbero un incubo di apici e backslash, e -- cosa peggiore -- una ancora che non trova nulla
# diventerebbe un sed che non sostituisce niente, cioe' un giro che "non produce rossi" sembrando
# onesto. Qui l'ancora che non compare ESATTAMENTE una volta e' un errore che fa fallire il giro
# prima di lanciare il browser.
#
# Perche' si muta il chunk SERVITO e non il sorgente (a differenza di muta_registro.py):
#  - il browser esegue QUEI byte, quindi e' la mutazione a massima fedelta': niente rebuild da 2
#    minuti per giro e nessuna possibilita' di lasciare sorgenti sporchi su DEV;
#  - la rasterizzazione vive in UN modulo (core/utils/jpegDaPdf.js) che Vite emette come chunk a se',
#    quindi "il chunk export-<hash>.js" e' esattamente quel sorgente, non un agglomerato;
#  - il rischio che si apre cosi' -- "ho mutato un file che il browser non legge" -- si chiude
#    verificando i byte SERVITI con curl dopo ogni mutazione, non fidandosi del disco.
#
# Le quattro mutazioni non sono scelte a caso: sono le quattro cose che questo file asserisce e che
# un programmatore distratto puo' rompere in buona fede.
#
# COSA C'ERA E NON C'E' PIU' -- "font-senza-metriche", rimossa perche' NON discriminava.
# L'idea era buona e la misura l'ha smentita: rompendo standardFontDataUrl (i nostri PDF non
# incorporano i glifi, zero /FontFile) le quattro JPEG venivano fuori BYTE-IDENTICHE all'originale
# e nel log di nginx non compariva NESSUNA richiesta a /pdfjs/standard_fonts/. pdf.js 5.4 rende i
# 14 font standard col suo percorso di riserva, senza chiedere i file. Un'asserzione che resta verde
# davanti a quel difetto non sta guardando i font: per questo qui non c'e' una mutazione sui font, e
# per questo i commenti di jpegDaPdf.js / copy_pdfjs_assets.mjs sono stati corretti (dicevano il
# contrario, e lo dicevano con sicurezza).
MUTAZIONI = {
    # (1) Lo sfondo bianco. Il JPEG non ha alpha: se il riempimento salta, il foglio in chat esce
    # NERO. Si mutano ENTRAMBE le difese -- il fillRect sul composite e il `background` passato a
    # render() -- perche' ce ne sono due e toglierne una sola NON cambia l'output: sarebbe una
    # mutazione che non testa niente (e il negative test lo direbbe, correttamente).
    "sfondo-nero": [
        ('fillStyle="#ffffff"', 'fillStyle="#000000"'),
        ('background:"#ffffff"', 'background:"#000000"'),
    ],
    # (2) Il tetto del canvas. E' l'unica cosa che puo' ridurre i DPI, e la consegna del titolare e'
    # che il contenuto non si tocchi: abbassandolo di molto l'immagine deve diventare ILLEGGIBILE
    # (larghezza sotto soglia) ma le pagine devono RESTARE tutte. Qui si misura che le due cose sono
    # davvero separate -- se il tetto tagliasse una pagina, l'aspect diventerebbe rosso e questo
    # giro lo denunciarebbe come "doveva restare verde".
    "tetto-dei-dpi": [
        ("regex", r'16\*1e3\*1e3', '1e5'),
    ],
    # (3) Le pagine contate male nella geometria del composite. La somma delle altezze diventa zero:
    # il canvas viene alto UN PIXEL per pagina e le pagine spariscono dall'immagine pur restando nel
    # PDF. E' il caso che l'asserzione sull'aspect deve beccare da sola -- la larghezza resta quella
    # giusta (2526 px) e quindi NON la vede.
    #
    # RICALIBRATA il 24/11/2026, e il perche' vale piu' della mutazione stessa. La prima versione
    # matchava `(\+=)(\w+)\.height\b`, cioe' `baseAltezza += vp.height`. Il fix della scala ha reso
    # quell'accumulatore una cosa che SERVE SOLO A CALCOLARE IL TETTO DEI DPI (riga 156 di
    # jpegDaPdf.js: `scalaDaLato = min(latoMax/baseLarghezza, latoMax/baseAltezza)`): azzerarlo fa
    # `latoMax/0 = Infinity`, la scala non si muove, l'immagine viene perfetta. Il giro ha riportato
    # "nessuna asserzione e' diventata rossa: la mutazione non ha cambiato output, non ha testato
    # niente" -- il negative test che fa il suo lavoro su se stesso, e l'unico modo che c'era per
    # accorgersi che una delle cinque promesse non era piu' presidiata. Ora si colpisce la somma che
    # DIVENTA il canvas (il `reduce` di riga 180), non quella che misura la geometria.
    #
    # Perche' regex e non la lettera minificata: `d+=m.height` era giusto finche' non ho toccato il
    # file, e il minificatore ha rinominato `d` e `m` -- l'ancora letterale sarebbe morta al rebuild
    # successivo senza dire niente. Qui si matcha la FORMA (`reduce((a,b)=>a+b.h,0)`), che il
    # minificatore non puo' cambiare, e "esattamente una occorrenza" resta il controllo che la
    # mutazione sia partita.
    "pagine-perse": [
        ("regex", r'(reduce\(\([A-Za-z_$][\w$]*,[A-Za-z_$][\w$]*\)=>)([A-Za-z_$][\w$]*)\+([A-Za-z_$][\w$]*)\.h,0\)',
         r'\g<1>\g<2>+1,0)'),
    ],
    # (4) Le pagine TUTTE nello stesso punto: l'offset di impilamento fermo a zero. L'canvas e' alto
    # la somma delle pagine, quindi l'aspect RESTA verde -- e deve restarlo -- ma dalla seconda pagina
    # in poi l'immagine e' bianca. E' la mutazione che dimostra perche' servono DUE asserzioni e non
    # una: senza questa, si potrebbe credere che l'aspect basti a garantire "tutte le pagine".
    # `\b` dopo `.h` impedisce di prendersi anche un eventuale `+=<id>.height`: qui serve colpire
    # SOLO l'offset di impilamento, la somma del canvas la mutazione sopra.
    "pagine-sovrapposte": [
        ("regex", r'(\+=)([A-Za-z_$][\w$]*)\.h\b', r'\g<1>0'),
    ],
    # (5) LA REGRESSIONE TROVATA DAL TITOLARE (24/11/2026): la pagina resa a scala 1 dentro un canvas
    # grande 3 volte. Il foglio usciva rimpicciolito in alto a sinistra -- "di un A4 prende solo una
    # piccola parte", e se l'ingrandisci sgrana -- mentre il canvas era delle misure giuste. Tutte le
    # asserzioni che guardano il canvas (dimensioni, aspect, inchiostro presente, angoli bianchi)
    # erano VERDI. Qui si rimette in piedi esattamente quel difetto, e l'unica cosa che deve diventare
    # rossa e' il confronto del quadro contro il PDF reso da poppler.
    #
    # Perche' regex e non letterale: il viewport del render ha la scala in una variabile minificata
    # (`getViewport({scale:f})`), e il nome cambia a ogni build. Il pattern ammette SOLO un
    # identificatore, quindi non tocca il `getViewport({scale:1})` usato per misurare -- e "esattamente
    # una occorrenza" resta il controllo che la mutazione sia partita davvero.
    "scala-render": [
        ("regex", r'getViewport\(\{scale:([A-Za-z_$][\w$]*)\}\)', r'getViewport({scale:\1/3})'),
    ],
}


def _normale(coppia):
    """(tipo, ancora, sostituto). Due elementi = letterale, tre = il primo dice il tipo."""
    if len(coppia) == 3:
        return coppia[0], coppia[1], coppia[2]
    return "literal", coppia[0], coppia[1]


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "lista"

    if cmd == "lista":
        for k in MUTAZIONI:
            print(k)

    elif cmd == "ancore":
        # tab: mutazione \t tipo \t ancora \t sostituto. Il wrapper la usa per verificare PRIMA dei
        # giri che ogni ancora sia presente una volta sola nel chunk pristine: cosi' "la mutazione non
        # e' partita" emerge subito, non dopo tre minuti di browser
        for k, coppie in MUTAZIONI.items():
            for coppia in coppie:
                tipo, src, dst = _normale(coppia)
                print(f"{k}\t{tipo}\t{src}\t{dst}")

    elif cmd == "marcatore":
        # Una manciata di byte del file MUTATO che nell'originale non compaiono: e' cio' che il wrapper
        # cerca nei byte SERVITI per provare che il browser sta eseguendo il file giusto. Non e' il
        # "sostituto" scritto qui -- con le mutazioni regex il sostituto reale dipende dal match, e
        # fidarsi della stringa nel sorgente e' il modo classico di verificare una mutazione mai partita
        chiave, orig_file, mut_file = sys.argv[2], sys.argv[3], sys.argv[4]
        with open(orig_file, encoding="utf-8") as f:
            a = f.read()
        with open(mut_file, encoding="utf-8") as f:
            b = f.read()
        i = 0
        while i < min(len(a), len(b)) and a[i] == b[i]:
            i += 1
        for lun in (48, 32, 20, 12, 8, 5):
            cand = b[i:i + lun].split("\n")[0]
            if cand and cand not in a:
                print(cand)
                return
        print("NESSUN-MARCATORE-DISTINGUIBILE", file=sys.stderr)
        sys.exit(3)

    elif cmd == "applica":
        src_file, dst_file, chiave = sys.argv[2], sys.argv[3], sys.argv[4]
        import re
        with open(src_file, encoding="utf-8") as f:
            testo = f.read()
        n = 0
        for coppia in MUTAZIONI[chiave]:
            tipo, src, dst = _normale(coppia)
            occ = len(re.findall(src, testo)) if tipo == "regex" else testo.count(src)
            if occ != 1:
                print(
                    f"ERRORE: l'ancora {src!r} ({tipo}) compare {occ} volte in {src_file}, e qui ne "
                    "serve esattamente 1. La mutazione non puo' partire: meglio fermarsi che girare "
                    "verde senza aver cambiato niente.",
                    file=sys.stderr,
                )
                sys.exit(2)
            testo = re.sub(src, dst, testo) if tipo == "regex" else testo.replace(src, dst)
            n += occ
        with open(dst_file, "w", encoding="utf-8") as f:
            f.write(testo)
        print(f"{chiave}: {n} sostituzioni applicate")

    else:
        print("comandi: lista | ancore | marcatore <mut> <orig> <mut> | applica <src> <dst> <mut>",
              file=sys.stderr)
        sys.exit(64)


import sys

main()
