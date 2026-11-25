#!/usr/bin/env python3
"""Prova che `misura_serializzazioni_lavagna.py` sappia diventare rosso.

Perche' esiste. Un negative che non cambia l'output non ha testato niente: la misura della lavagna dice
"0 buchi" e se nessuno la guasta mai quella frase e' solo un'opinione. Qui i sorgenti della lavagna
vengono rotti in otto modi che DEVONO essere visti, piu' il pristino che deve restare verde.

Ogni mutazione e' verificata all'atto: se il pattern non trova nulla l'asserzione esplode invece di
contare un verde bugiardo (e' il modo in cui due giri di questa prova erano passati verdi per colpa
dell'arness, non della lavagna).

Le otto mutazioni, e perche' proprio queste:
  a  strumento nuovo in palette, nessun ramo scritto da nessuna parte
  b  un tipo tolto da TUTTI i rami di getElements (una sola occorrenza non basta: ce n'e' un'altra)
  c  un campo tolto dalla lista bianca del payload
  d  un tipo linea tolto dalla lista ['pass','dribble',...].includes(tipo) della miniatura -- il ramo
     annidato lo nomina ancora: SOLO la regola "catena principale" lo vede, ed e' il buco che le altre
     due misure non coprivano
  e  il ramo text in fondo a drawElementsCanvas (prova che il bound del blocco arriva a riga ~1191)
  f  il ramo line della miniatura
  g  lo sbaglio realistico: un sesto strumento linea in palette e sulla lavagna, dimenticato in miniatura
  h  un campo nuovo sull'elemento, dimenticato nella lista bianca del payload

  python3 scripts/test/prova_misura_serializzazioni_lavagna.py
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))
MISURA = os.path.join(HERE, 'misura_serializzazioni_lavagna.py')
REL_HTML = os.path.join('frontend', 'public', 'lavagna-20250702.html')
REL_VUE = os.path.join('frontend', 'src', 'features', 'allenamenti', 'Allenamenti.vue')

html0 = open(os.path.join(REPO, REL_HTML), encoding='utf-8').read()
vue0 = open(os.path.join(REPO, REL_VUE), encoding='utf-8').read()


def corpo(testo, inizio, fine):
    i = testo.index(inizio)
    return i, testo.index(fine, i + len(inizio))


def sostituisci(testo, vecchio, nuovo, nome, volte=None):
    n = testo.count(vecchio)
    assert n > 0, f'mutazione {nome}: pattern non trovato ({vecchio[:60]!r})'
    if volte is not None:
        assert n == volte, f'mutazione {nome}: attese {volte} occorrenze, trovate {n}'
    return testo.replace(vecchio, nuovo)


def lancia(html, vue, etichetta):
    """Esegue la misura su una copia dell'albero con i due sorgenti sostituiti."""
    d = tempfile.mkdtemp(prefix='lav_neg_')
    try:
        for rel, txt in ((REL_HTML, html), (REL_VUE, vue)):
            f = os.path.join(d, rel)
            os.makedirs(os.path.dirname(f), exist_ok=True)
            open(f, 'w', encoding='utf-8').write(txt)
        r = subprocess.run([sys.executable, MISURA, d], capture_output=True, text=True)
        if 'Traceback' in r.stderr:
            raise SystemExit(f'  la misura e\' andata in eccezione su "{etichetta}":\n{r.stderr[-900:]}')
        return 'BUCHI' in r.stdout, r.stdout
    finally:
        shutil.rmtree(d, ignore_errors=True)


MUTAZIONI = {}

# a) uno strumento nuovo in palette, senza nessun ramo scritto da nessuna parte
MUTAZIONI['a strumento nuovo in palette'] = (
    sostituisci(html0, "{type:'player-bib',label:'Fratinato',icon:",
                "{type:'paletta',label:'Paletta',icon:'X'},\n      {type:'player-bib',label:'Fratinato',icon:",
                'a', 1), vue0)

# b) tipo ball tolto da TUTTI i rami di getElements
i, j = corpo(html0, 'function getElements(', 'function loadElement(')
blocco = html0[i:j]
n = len(re.findall(r"tipo==='ball'", blocco))
assert n >= 1, 'mutazione b: nessun ramo ball in getElements'
MUTAZIONI[f'b tutti i {n} rami ball di getElements'] = (
    html0[:i] + blocco.replace("tipo==='ball'", "tipo==='ball_NON_PIU_USATO'") + html0[j:], vue0)

# c) un campo tolto dalla lista bianca del payload. `points` e non `wavy`: wavy la lavagna non lo
#    produce nemmeno, quindi toglierlo non toglie niente e la misura farebbe bene a restare verde
i, j = corpo(vue0, 'const payload = {', '\n  saveAllenamenti(')
blocco = vue0[i:j]
assert re.search(r'^\s*points:\s+el\.points', blocco, re.M), 'mutazione c: points non e\' nel payload'
MUTAZIONI['c campo points dal payload'] = (
    html0, vue0[:i] + re.sub(r'^\s*points:\s+el\.points[^\n]*\n', '\n', blocco, flags=re.M) + vue0[j:])

# d) movement tolto dalla LISTA .includes della miniatura: il tipo resta nominato dal ramo annidato,
#    quindi solo la regola sulla catena principale lo vede
v = sostituisci(vue0, "['pass', 'dribble', 'wallpass', 'shot', 'movement'].includes(tipo)",
                "['pass', 'dribble', 'wallpass', 'shot'].includes(tipo)", 'd', 1)
MUTAZIONI['d movement dalla lista .includes'] = (html0, v)

# e) ramo text in fondo a drawElementsCanvas
i, j = corpo(vue0, 'function drawElementsCanvas(', 'function saveEsercizio(')
blocco = vue0[i:j]
assert "tipo === 'text'" in blocco, "mutazione e: il ramo text non e' nel blocco (bound sbagliato)"
MUTAZIONI['e ramo text in fondo alla miniatura'] = (
    html0, vue0[:i] + blocco.replace("tipo === 'text'", "tipo === 'text_NON_PIU_USATO'") + vue0[j:])

# f) ramo line della miniatura
assert "tipo === 'line'" in blocco, "mutazione f: il ramo line non e' nel blocco"
MUTAZIONI['f ramo line nella miniatura'] = (
    html0, vue0[:i] + blocco.replace("tipo === 'line'", "tipo === 'line_NON_PIU_USATO'") + vue0[j:])

# g) un sesto strumento LINEA in palette e sulla lavagna, dimenticato nella miniatura
h = sostituisci(html0, "{type:'line',label:'Linea',icon:",
                "{type:'calcio',label:'Calcio',icon:'>'},\n      {type:'line',label:'Linea',icon:", 'g1', 1)
i, j = corpo(h, 'function createLineElement(', 'function resizeStage(')
blocco = h[i:j]
assert "if(currentTool==='pass')" in blocco, "mutazione g: la catena delle linee non c'e'"
h = h[:i] + blocco.replace("if(currentTool==='pass')",
                           "if(currentTool==='calcio')el=createArrow(x1,y1,x2,y2);\n      "
                           "else if(currentTool==='pass')", 1) + h[j:]
MUTAZIONI['g linea nuova dimenticata in miniatura'] = (h, vue0)

# h) un campo nuovo sull'elemento, dimenticato nella lista bianca del salvataggio: e' il buco silenzioso
#    per eccellenza (lo vedi a schermo, non arriva al DB, nessun errore da nessuna parte)
i, j = corpo(html0, 'function getElements(', 'function loadElement(')
blocco = html0[i:j]
m = re.search(r'var el=\{([^}]*)\}', blocco)
assert m, 'mutazione h: var el={...} non trovato in getElements'
h2 = html0[:i] + blocco[:m.start(1)] + m.group(1) + ',spin:0' + blocco[m.end(1):] + html0[j:]
MUTAZIONI['h campo nuovo dimenticato nel payload'] = (h2, vue0)

print('=== il file vero, come controllo di partenza (deve restare verde) ===')
rosso, _ = lancia(html0, vue0, 'pristino')
assert not rosso, 'LA MISURA DA BUCHI SUL FILE VERO: non e\' una misura, e\' rumore'
print('  pristino                             verde')

print()
print(f'=== le {len(MUTAZIONI)} mutazioni (tutte DEVONO essere viste rosse) ===')
mancanti = []
for k, (h_, v_) in MUTAZIONI.items():
    rosso, output = lancia(h_, v_, k)
    print(f'  {"ok    " if rosso else "MANCA "} {k}')
    if not rosso:
        mancanti.append(k)
    for riga in output.splitlines():
        if 'senza ramo' in riga or 'NON diramate' in riga or 'NON nel payload' in riga:
            print(f'            {riga.strip()}')

print()
print(f'  {len(MUTAZIONI) - len(mancanti)}/{len(MUTAZIONI)} mutazioni viste rosse' +
      ('' if not mancanti else '  -> NON affidabile: ' + ', '.join(mancanti)))
sys.exit(1 if mancanti else 0)
