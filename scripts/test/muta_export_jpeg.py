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
        ('B=16*1e3*1e3', 'B=1e5'),
    ],
    # (3) Le pagine contate male nella geometria del composite. `d` e' la somma delle altezze: azzerata
    # quella, il canvas viene alto 1 pixel e le pagine spariscono dall'immagine pur restando nel PDF.
    # E' il caso che l'asserzione sull'aspect deve beccare da sola -- la larghezza resta quella giusta
    # (2526 px) e quindi NON la vede.
    "pagine-perse": [
        ('d+=m.height', 'd+=0'),
    ],
    # (4) Le pagine TUTTE nello stesso punto: l'offset di impilamento fermo a zero. L'canvas e' alto
    # la somma delle pagine, quindi l'aspect RESTA verde -- e deve restarlo -- ma dalla seconda pagina
    # in poi l'immagine e' bianca. E' la mutazione che dimostra perche' servono DUE asserzioni e non
    # una: senza questa, si potrebbe credere che l'aspect basti a garantire "tutte le pagine".
    "pagine-sovrapposte": [
        ('M+=P', 'M+=0'),
    ],
}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "lista"

    if cmd == "lista":
        for k in MUTAZIONI:
            print(k)

    elif cmd == "ancore":
        # tab: mutazione \t ancora \t sostituto. Il wrapper la usa per verificare PRIMA dei giri che
        # ogni ancora sia presente una volta sola nel chunk pristine: cosi' "la mutazione non e'
        # partita" emerge subito, non dopo tre minuti di browser
        for k, coppie in MUTAZIONI.items():
            for src, dst in coppie:
                print(f"{k}\t{src}\t{dst}")

    elif cmd == "marcatore":
        # cosa deve essere PRESENTE nei byte serviti dopo la mutazione (prova che il browser riceve
        # il file mutato, non quello originale)
        print(MUTAZIONI[sys.argv[2]][-1][1])

    elif cmd == "applica":
        src_file, dst_file, chiave = sys.argv[2], sys.argv[3], sys.argv[4]
        coppie = MUTAZIONI[chiave]
        with open(src_file, encoding="utf-8") as f:
            testo = f.read()
        n = 0
        for src, dst in coppie:
            occ = testo.count(src)
            if occ != 1:
                print(
                    f"ERRORE: l'ancora {src!r} compare {occ} volte in {src_file}, e qui ne serve "
                    "esattamente 1. La mutazione non puo' partire: meglio fermarsi che girare verde "
                    "senza aver cambiato niente.",
                    file=sys.stderr,
                )
                sys.exit(2)
            testo = testo.replace(src, dst)
            n += occ
        with open(dst_file, "w", encoding="utf-8") as f:
            f.write(testo)
        print(f"{chiave}: {n} sostituzioni applicate")

    else:
        print("comandi: lista | ancore | marcatore <mut> | applica <src> <dst> <mut>", file=sys.stderr)
        sys.exit(64)


import sys

main()
