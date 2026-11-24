#!/usr/bin/env python3
# Confronta il QUADRO di una JPEG con quello del PDF da cui dovrebbe essere nata.
#
# Perche' esiste. Il test dell'export JPEG misurava il CANVAS: dimensioni giuste, aspect giusto,
# inchiostro presente su ogni pagina, angoli bianchi. Con quel difetto -- la pagina resa a scala 1
# dentro un canvas grande 3 volte -- erano TUTTE verdi, perche' il canvas era davvero delle misure
# giuste: era il contenuto a essere rimpicciolito in alto a sinistra, e chi scaricava il foglio
# trovava un'A4 con il foglio in un angolo che se l'ingrandiva sgranava. "Il canvas e' la cornice,
# il contenuto e' il quadro": un'asserzione che guarda solo la cornice non puo' vedere un quadro
# rimpicciolito.
#
# Quindi qui si misura DOVE STA L'INCHIOSTRO, e lo si misura su due renderizzazioni diverse dello
# STESSO documento:
#   - il PDF, reso da poppler (pdftoppm): un renderer indipendente, che non condivide una riga di
#     codice con pdf.js, quindi non puo' sbagliare la scala insieme a lui;
#   - la JPEG prodotta dall'app.
# Se la JPEG e' davvero l'immagine di quel PDF, i due riquadri d'inchiostro coincidono. Se la
# rasterizzazione sbaglia la scala, il ritaglio una pagina o l'impaginazione, il riquadro si sposta
# e questo lo dice.
#
# Le bande della JPEG non gli si passa: le pagine sono impilate, quindi la banda della pagina i va da
# (somma delle altezze precedenti) a (somma fino a i), in proporzione alle MediaBox del PDF. E' la
# stessa geometria che usa jpegDaPdf.js, e proprio per questo va ricalcolata qui da sola: se la
# ricalcolasse male come la rasterizzazione, il confronto sarebbe un falso verde.
#
# Fallisce RUMOROSO se manca qualcosa (Pillow, pdftoppm, file illeggibili): un confronto che non parte
# deve essere rosso, non assente.
import json
import os
import subprocess
import sys
import tempfile

SOGLIA_INCHIOSTRO = 235   # "non bianco", stessa soglia del test nel browser
MINIMO_CANDIDATI = 2       # una riga/colonna conta se ha almeno 2 pixel scuri: un pixel solo e'
                           # rumore di compressione della JPEG, non contenuto


def riquadro(im):
    """Riquadro normalizzato (0..1) dell'inchiostro, o None se l'immagine e' bianca."""
    w, h = im.size
    if w == 0 or h == 0:
        return None
    px = im.load()
    # Campiona: a 3x un foglio e' 2526x1786, leggerli tutti e due via Python e' lento e non serve a
    # localizzare un bordo, che si sposta di percentuali, non di pixel
    passo = max(1, round(max(w, h) / 700))
    righe, cols = [], []
    for y in range(0, h, passo):
        n = 0
        for x in range(0, w, passo):
            if px[x, y] < SOGLIA_INCHIOSTRO:
                n += 1
                if n >= MINIMO_CANDIDATI:
                    break
        if n >= MINIMO_CANDIDATI:
            righe.append(y)
    for x in range(0, w, passo):
        n = 0
        for y in range(0, h, passo):
            if px[x, y] < SOGLIA_INCHIOSTRO:
                n += 1
                if n >= MINIMO_CANDIDATI:
                    break
        if n >= MINIMO_CANDIDATI:
            cols.append(x)
    if not righe or not cols:
        return None
    return {
        "x0": round(cols[0] / w, 4), "x1": round(cols[-1] / w, 4),
        "y0": round(righe[0] / h, 4), "y1": round(righe[-1] / h, 4),
        "largh": round((cols[-1] - cols[0]) / w, 4), "alt": round((righe[-1] - righe[0]) / h, 4),
    }


def apri(path):
    from PIL import Image
    return Image.open(path).convert("L")


def altezze_pagine(pdf):
    """Altezze delle MediaBox, lette dal PDF: sono le proporzioni con cui jpegDaPdf impila."""
    import re
    with open(pdf, "rb") as f:
        grezzo = f.read()
    box = list(re.finditer(rb"/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]", grezzo))
    if not box:
        raise RuntimeError("nessuna MediaBox trovata in %s: il PDF non e' leggibile" % pdf)
    return [(float(m.group(1)), float(m.group(2))) for m in box]


def rendi_pdf(pdf, cartella, dpi):
    base = os.path.join(cartella, "p")
    subprocess.run(["pdftoppm", "-png", "-r", str(dpi), pdf, base],
                   check=True, capture_output=True)
    png = sorted(f for f in os.listdir(cartella) if f.startswith("p-") and f.endswith(".png"))
    if not png:
        raise RuntimeError("pdftoppm non ha prodotto nessuna pagina per %s" % pdf)
    return [os.path.join(cartella, f) for f in png]


def main():
    if len(sys.argv) < 3:
        print("uso: confronta_inchiostro.py <pdf> <jpg> [--dpi 100] [--soglia 0.05]", file=sys.stderr)
        return 64
    pdf, jpg = sys.argv[1], sys.argv[2]
    dpi, soglia = 100, 0.05
    if "--dpi" in sys.argv:
        dpi = int(sys.argv[sys.argv.index("--dpi") + 1])
    if "--soglia" in sys.argv:
        soglia = float(sys.argv[sys.argv.index("--soglia") + 1])

    try:
        import PIL  # noqa: F401
    except ImportError:
        print(json.dumps({"errore": "Pillow non installata: il confronto non puo' essere fatto"}))
        return 2
    if not os.path.exists(pdf) or not os.path.exists(jpg):
        print(json.dumps({"errore": "file mancante: pdf=%s jpg=%s" % (os.path.exists(pdf), os.path.exists(jpg))}))
        return 2

    try:
        altezze = altezze_pagine(pdf)
    except Exception as e:
        print(json.dumps({"errore": str(e)}))
        return 2

    try:
        im_jpg = apri(jpg)
    except Exception as e:
        print(json.dumps({"errore": "JPEG illeggibile: %s" % e}))
        return 2

    with tempfile.TemporaryDirectory() as tmp:
        try:
            png = rendi_pdf(pdf, tmp, dpi)
        except Exception as e:
            print(json.dumps({"errore": "pdftoppm ha fallito: %s" % e}))
            return 2

        if len(png) != len(altezze):
            print(json.dumps({"errore": "poppler legge %d pagine, il PDF ne dichiara %d"
                                       % (len(png), len(altezze))}))
            return 2

        totale = sum(h for (_w, h) in altezze) or 1.0
        W, H = im_jpg.size
        confronti = []
        peggio = 0.0
        y0 = 0
        for i, (png_path, (_w, h)) in enumerate(zip(png, altezze), start=1):
            a = int(round(H * (y0 / totale)))
            b = int(round(H * ((y0 + h) / totale)))
            y0 += h
            banda = im_jpg.crop((0, a, W, max(a + 1, b)))
            r_pdf = riquadro(apri(png_path))
            r_jpg = riquadro(banda)
            if r_pdf is None or r_jpg is None:
                confronti.append({"pagina": i, "pdf": r_pdf, "jpg": r_jpg,
                                  "delta_max": None,
                                  "perche": "una delle due meta' e' bianca: non c'e' un riquadro da confrontare"})
                peggio = 1.0
                continue
            delta = max(abs(r_pdf[k] - r_jpg[k]) for k in ("x0", "y0", "x1", "y1"))
            peggio = max(peggio, delta)
            confronti.append({"pagina": i, "pdf": r_pdf, "jpg": r_jpg,
                              "delta_max": round(delta, 4),
                              "banda": [a, b]})

        print(json.dumps({
            "pagine": len(png), "dpi": dpi, "soglia": soglia,
            "jpeg": {"w": W, "h": H},
            "peggio": round(peggio, 4),
            "ok": peggio <= soglia,
            "confronti": confronti,
        }, ensure_ascii=False))
        return 0


if __name__ == "__main__":
    # Un'eccezione qui dentro diventerebbe un traceback su stderr e stdout vuoto: il test node non
    # riuscirebbe a parsare e racconterebbe un errore suo, non il difetto dell'export. Ogni strada
    # passa da un JSON, anche quelle che falliscono
    try:
        sys.exit(main())
    except Exception as e:
        import traceback
        print(json.dumps({"errore": "%s: %s" % (type(e).__name__, e),
                          "dove": traceback.format_exc().splitlines()[-3:]}))
        sys.exit(2)
