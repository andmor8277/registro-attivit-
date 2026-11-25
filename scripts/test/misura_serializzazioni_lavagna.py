#!/usr/bin/env python3
"""Rimisura l'invariante delle serializzazioni della lavagna, senza Chrome.

Perche' esiste. La lavagna disegna lo stesso elemento in QUATTRO posti separati, e nessuno di questi
chiama gli altri: `getElements` (legge l'oggetto da Konva), `loadElement` (lo ricrea sul campo),
`placeElement`/`createLineElement` (lo fa nascere al click) e `drawElementsCanvas` in Allenamenti.vue
(lo ridipinge nella miniatura del catalogo). Aggiungere uno strumento senza scriverlo in uno di questi
quattro non da' nessun errore: l'elemento si vede a schermo e scompare, o arriva a terra storto.

Il guard-rail vero e' `ui_lavagna.cjs` (148 asserzioni + 6 controlli sul DB), che pero' vuole Chrome e
non puo' stare nella suite. Qui la stessa invariante si rimisura in un secondo, e in piu' si guarda la
miniatura del catalogo, che nessun test col browser apre.

Tre controlli, perche' sono tre modi diversi di rompere la lavagna:
  1. PRESENZA -- ogni tipo della palette deve essere nominato da una guardia di ogni catena;
  2. CATENA   -- gli strumenti LINEA devono essere diramati alla catena principale, non citati da
                 qualche parte. Un tipo tolto dalla lista ['pass','dribble',...].includes(tipo) della
                 miniatura resta nominato dal suo ramo annidato, e il solo controllo di presenza non lo
                 vede: e' il buco che NESSUNA delle due misure vedeva, chiuso qui;
  3. PAYLOAD  -- ogni campo che la lavagna produce deve essere nella lista bianca del salvataggio,
                 altrimenti lo vedi a schermo e lo perdi al DB senza nessun errore. L'elenco dei campi
                 NON e' scritto a mano qui: viene da `var el={...}` di getElements e dalle assegnazioni,
                 perche' una lista a mano smette silenziosamente di testare qualcosa appena un campo
                 viene rinominato.

Non verifica che l'elemento si DISEGNI davvero: quello lo fa `verifica_ui_lavagna.sh` col browser.
Che questo script sappia diventare rosso lo verifica `prova_misura_serializzazioni_lavagna.py`.

  python3 scripts/test/misura_serializzazioni_lavagna.py            # sul repo
  python3 scripts/test/misura_serializzazioni_lavagna.py <radice>   # su un albero mutato
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))
ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else REPO
HTML = os.path.join(ROOT, 'frontend', 'public', 'lavagna-20250702.html')
VUE = os.path.join(ROOT, 'frontend', 'src', 'features', 'allenamenti', 'Allenamenti.vue')

# I tipi legacy normalizzati PRIMA dei rami (player-home -> player, arrow -> pass, ...): non sono
# strumenti della palette e un regex ingenuo li conterebbe come rami "in piu'"
LEGACY = {'player-home', 'player-away', 'player-gk', 'arrow', 'arrow-curve', 'arrow-dash',
          'arrow-curve-dash', 'movement-legacy', 'unknown'}
# Tool della palette che non creano un elemento: per loro nessun ramo e' corretto, non e' un buco
NON_TIPO = {'select'}
# Sono il mirror Konva di x/y/x1..y2 (li legge getElements per ricostruirli): non vanno nel payload
SPECCHIO_KONVA = {'fieldX', 'fieldY', 'origX1', 'origY1', 'origX2', 'origY2'}


def corpo(testo, inizio, fine):
    """Il testo tra l'inizio di `inizio` e l'inizio di `fine` (come `corpo()` in ui_lavagna.cjs)."""
    i = testo.index(inizio)
    return testo[i:testo.index(fine, i + len(inizio))]


def guardie(testo, var):
    """Le condizioni if/else if del blocco: (indentazione, tipi che ammettono, testo della guardia)."""
    out = []
    for riga in testo.splitlines():
        m = re.search(r'\bif\s*\((.*)\)', riga)
        if not m:
            continue
        cond = m.group(1)
        tipi = set(re.findall(var + r"\s*===?\s*'([a-z0-9-]+)'", cond))
        for lista in re.findall(r"\[([^\]]*?)\]\s*\.(?:includes|indexOf)\(", cond):
            tipi |= set(re.findall(r"'([a-z0-9-]+)'", lista))
        if tipi:
            out.append((len(riga) - len(riga.lstrip()), tipi, cond.strip()))
    return out


html = open(HTML, encoding='utf-8').read()
vue = open(VUE, encoding='utf-8').read()

# 1. la palette: e' lei che decide quali sono "gli strumenti"
palette = re.findall(r"\{type:'([a-z0-9-]+)',label:'", html)
tipi_palette = [t for t in palette if t not in NON_TIPO]

# 2. gli strumenti LINEA li prende dalla lavagna stessa (createLineElement), non da una lista scritta a
#    mano qui: se uno ne aggiunge un sesto e dimentica la miniatura, questo e' quello che lo vede
LINEE = {t for t in re.findall(r"currentTool\s*===?\s*'([a-z0-9-]+)'",
                               corpo(html, 'function createLineElement(', 'function resizeStage('))} - NON_TIPO

# Le àncore dei blocchi sono le stesse di ui_lavagna.cjs, non inventate qui.
POSTI = {
    'getElements (lettura da Konva)': (corpo(html, 'function getElements(', 'function loadElement('), 'tipo'),
    'loadElement (ricreazione)': (corpo(html, 'function loadElement(', 'function doLoadElements('), r'el\.tipo'),
    'placeElement (nascita al click)': (corpo(html, 'function placeElement(', 'function resizeStage('), 'currentTool'),
    'drawElementsCanvas (miniatura)': (corpo(vue, 'function drawElementsCanvas(', 'function saveEsercizio('), 'tipo'),
}

print(f'  palette: {len(palette)} pulsanti, {len(tipi_palette)} tipi di elemento')
print(f'  strumenti linea (da createLineElement): {", ".join(sorted(LINEE))}')
print()

buchi = 0
for nome, (testo, var) in POSTI.items():
    g = guardie(testo, var)
    if not g:
        print(f'  {nome:34s} NESSUNA GUARDIA TROVATA: àncora del blocco sbagliata')
        buchi += 1
        continue
    minimo = min(i for i, _, _ in g)
    trovati = set().union(*(n for _, n, _ in g)) - LEGACY - NON_TIPO
    principali = set().union(*(n for i, n, _ in g if i == minimo)) - LEGACY - NON_TIPO

    mancanti = sorted(set(tipi_palette) - trovati)
    linee_fuori = sorted((LINEE & set(tipi_palette)) - principali)
    extra = sorted(trovati - set(tipi_palette))
    buchi += len(mancanti) + len(linee_fuori)

    stato = 'allineato' if not (mancanti or linee_fuori) else f'{len(mancanti) + len(linee_fuori)} BUCHI'
    print(f'  {nome:34s} rami={len(trovati):2d}  catena@{minimo:<2d} {stato}')
    if mancanti:
        print(f'    {"":34s} tipi della palette senza ramo: {", ".join(mancanti)}')
    if linee_fuori:
        print(f'    {"":34s} linee NON diramate alla catena principale (ramo annidato o morto): '
              f'{", ".join(linee_fuori)}')
    if extra:
        # non e' un difetto di per se' (tipo legacy o interno), ma va nominato: e' qui che si vede un
        # ramo scritto per uno strumento poi tolto dalla palette
        print(f'    {"":34s} rami senza pulsante in palette: {", ".join(extra)}')

# 3. la lista bianca dei campi del payload: il punto piu' silenzioso. Àncora = ui_lavagna.cjs riga 170.
payload = corpo(vue, 'const payload = {', '\n  saveAllenamenti(')
campi = {m.group(1) for m in re.finditer(r'(\w+):\s+el\.', payload)}
# cosa produce la lavagna: l'oggetto che si costruisce in getElements + le assegnazioni/setAttr
m = re.search(r'var el=\{([^}]*)\}', POSTI['getElements (lettura da Konva)'][0])
dichiarati = set(re.findall(r'(?:^|[,{])([a-zA-Z][a-zA-Z0-9_]*)\s*:', m.group(1))) if m else set()
ascritti = set(re.findall(r"el\.setAttr\('([a-zA-Z0-9_]+)'", html)) | \
           set(re.findall(r"\bel\.([a-zA-Z0-9_]+)\s*=", html))
prodotti = (dichiarati | ascritti) - SPECCHIO_KONVA
persi = sorted(prodotti - campi)
vestigiali = sorted(campi - prodotti)
buchi += len(persi)
print()
print(f'  lista bianca del payload: {len(campi)} campi -> {", ".join(sorted(campi))}')
print(f'  campi prodotti dalla lavagna: {len(prodotti)} (da var el={{...}} + assegnazioni)')
if persi:
    print(f'    {"":34s} prodotti dalla lavagna ma NON nel payload (li perdi al salvataggio): {", ".join(persi)}')
if vestigiali:
    # non e' un buco: un campo che la lavagna non produce porta solo il suo default. Va nominato perche'
    # e' codice che finge di trasportare qualcosa (wavy: l'ondulazione viaggia gia' in `points`)
    print(f'    {"":34s} nel payload ma mai prodotti dalla lavagna (vestigiali): {", ".join(vestigiali)}')

print()
print(f'  {"0 buchi: le quattro serializzazioni sono allineate alla palette" if not buchi else str(buchi) + " BUCHI da chiudere"}')
sys.exit(1 if buchi else 0)
