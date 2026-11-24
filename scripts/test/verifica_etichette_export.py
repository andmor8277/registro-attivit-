#!/usr/bin/env python3
"""Verifica l'invariante delle coppie di export: i due pulsanti di una coppia dicono le STESSE
parole, cambia solo il formato, ed e' l'ultima parola.

Perche' un file a se': il titolare ha scelto la convenzione "Ambito (PDF)" / "Ambito (immagine)"
perche' le etichette erano derivate in quattro modi diversi ("Immagine", "Esporta JPEG", "JPEG",
e il non-italiano "Immagine la selezione"). Un rinomino fatto a mano su una meta' sola delle coppie
non rompe nessun test e nessun build: e' la stessa classe del drift del README. Qui diventa rossa.

Abbina ogni pulsante JPEG al pulsante PDF piu' vicino che lo precede: nelle tre pagine la coppia e'
scritta adiacente (il gemello JPEG sta subito sotto il suo PDF, con un commento in mezzo).
"""
import re
import sys

DIR = '/home/andrea/Documenti/opencode-project/registro_presenze/frontend/src/features/partite/'
PAGINE = ['Tornei.vue', 'Convocazioni.vue', 'ProgrammazionePartite.vue']
# Le 9 coppie, nell'ordine in cui compaiono. Il conteggio e' asserito: un pulsante in piu' o in
# meno (uno rimosso "perche' tanto c'e' l'altro") deve essere rosso, non un verde con 8 coppie.
AMBITI = ['Tutti i tornei', 'Selezione', 'Calendario categoria', 'Calendario torneo',
          'Foglio convocazione',            # Tornei.vue  (5)
          'Foglio convocazione',            # Convocazioni.vue
          'Calendario weekend', 'Gare genitori', 'Gare genitori']  # ProgrammazionePartite.vue

def etichetta(blocco):
    """L'etichetta leggibile del pulsante, QUALUNQUE sia la sua forma.

    Non si chiede "somiglia a una delle etichette giuste": se il testo torna a `JPEG genitori` o
    someone scrive `Immagine la selezione`, l'etichetta va letta lo stesso, perche' e' LI' che le
    asserzioni sotto (simmetria, formato in fondo, nessuna parola vecchia) hanno qualcosa da
    confrontare. Chiedere il pattern `(PDF)|(immagine)` per estrarla le rendeva `None` e spegneva
    proprio i tre controlli che servono.
    """
    b = re.sub(r'<svg\b.*?</svg>', ' ', blocco, flags=re.S)          # le icone non sono testo
    b = re.sub(r'<!--.*?-->', ' ', b, flags=re.S)
    m = re.findall(r"\?\s*'([^']*)'\s*:\s*'([^']*)'", b)             # {{ busy ? 'Genero…' : 'X' }}
    if m:
        return m[-1][1]
    m = re.findall(r'<span>(.*?)</span>', b, re.S)
    if m:
        return m[-1].strip()
    m = re.findall(r'>\s*([^<>{}\n][^<>{}\n]*?)\s*<', b)            # testo nudo fra i tag
    m = [x.strip() for x in m if x.strip()]
    return m[-1] if m else None

def pulsante(blocco):
    c = re.search(r'@click="([^"]*)"', blocco)
    if not c:
        return None
    click = c.group(1)
    # Solo i pulsanti di export: nella pagina ci sono anche Modifica, Annulla, "Aggiungi Partita",
    # "Salva convocazione". Considerarli "pdf" voleva dire che il gemello JPEG poteva essere
    # abbinato al pulsante sbagliato, e l'abbinamento e' tutto qui.
    if not re.search(r'esporta', click, re.I):
        return None
    jpeg = ('jpeg' in click.lower()) or bool(re.search(r'\besportaJPEG\b', click))
    return ('jpeg' if jpeg else 'pdf'), etichetta(blocco)

rosso, coppie = [], []
for f in PAGINE:
    t = open(DIR + f, encoding='utf-8').read()
    visti = []
    for m in re.finditer(r'<button\b[^>]*>(.*?)</button>', t, re.S):
        p = pulsante(m.group(0))
        if p:
            visti.append((f, t[:m.start()].count('\n') + 1, p[0], p[1]))
    # abbina ogni jpeg al pdf immediatamente precedente
    for i, (file, riga, tipo, lab) in enumerate(visti):
        if tipo != 'jpeg':
            continue
        pdf = next(((rg, l) for fl, rg, t2, l in reversed(visti[:i]) if t2 == 'pdf'), (None, None))
        coppie.append((file, pdf[0], pdf[1], riga, lab))

print(f'{"pagina":<26} {"r.PDF":>6}  {"etichetta PDF":<30} {"r.JPG":>6}  etichetta immagine')
print('-' * 100)
for file, rpdf, lpdf, rjpg, ljpg in coppie:
    print(f'{file:<26} {str(rpdf):>6}  {str(lpdf):<30} {str(rjpg):>6}  {ljpg}')
    if not lpdf or not ljpg:
        rosso.append(f'{file}:{rjpg}: etichetta non trovata ({lpdf!r} / {ljpg!r})')
        continue
    # 1) le due etichette devono coincidere sostituendo il solo formato
    atteso = lpdf.replace('(PDF)', '(immagine)')
    if atteso != ljpg:
        rosso.append(f'{file}:{rjpg}: la coppia non e\' simmetrica -> "{ljpg}" doveva essere "{atteso}"')
    # 2) il formato deve essere l'ultima parola, fra parentesi
    for l, formato in ((lpdf, '(PDF)'), (ljpg, '(immagine)')):
        if not l.endswith(formato):
            rosso.append(f'{file}: "{l}" non finisce con {formato}')
    # 3) nessun residuo delle parole vecchie
    for sporco in ('JPEG', 'Esporta ', 'Immagine '):
        if sporco in lpdf or sporco in ljpg:
            rosso.append(f'{file}: "{lpdf}" / "{ljpg}" contiene ancora "{sporco.strip()}"')

print()
if len(coppie) != len(AMBITI):
    rosso.append(f'coppie trovate {len(coppie)}, attese {len(AMBITI)}')
else:
    # le coppie con etichetta mancante sono GIA' rosse sopra: qui si confrontano solo quelle lette,
    # altrimenti un'etichetta assente farebbe esplodere questo confronto invece di restare il rosso
    # preciso ("etichetta non trovata") che gia' parla da solo
    lette = [c for c in coppie if c[2] and c[4]]
    if len(lette) == len(AMBITI):
        trovati = [c[2].replace(' (PDF)', '') for c in lette]
        if trovati != AMBITI:
            rosso.append(f'gli ambiti non sono quelli attesi:\n    trovati: {trovati}\n    attesi : {AMBITI}')

print('-' * 100)
if rosso:
    for r in rosso:
        print('  FAIL ' + r)
    print(f'  {len(coppie) - len(rosso)} ok, {len(rosso)} falliti')
    sys.exit(1)
print(f'  ok   {len(coppie)} coppie: etichette identiche tranne il formato, formato in fondo, '
      'nessuna parola vecchia')
