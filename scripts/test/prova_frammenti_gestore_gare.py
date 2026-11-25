#!/usr/bin/env python3
"""Controllo statico degli àncore di `negative_gestore_gare.sh`, senza toccare DEV.

Perche' esiste. Ogni giro del negative rompe il sorgente sostituendo un frammento che deve comparire
ESATTAMENTE una volta. Quando quell'àncora non coincide piu' -- dopo un refactoring, o per un apostrofo
sbagliato in un commento bash -- il giro lo scopre dopo due minuti di `docker cp` + `restart` + suite, e
con cinque giri gia' eseguiti. Qui la stessa cosa si vede in un secondo, senza SSH e senza backend.

Cosa verifica, per ogni coppia ancora/sostituzione:
  - l'àncora compare UNA SOLA volta nel sorgente (zero = il giro non parte; due = colpirebbe il ramo
    sbagliato e chiamerebbe "una mutazione" un'altra cosa);
  - la sostituzione e' DIVERSA dall'àncora (una mutazione che non cambia nessun byte non ha testato
    niente, ed e' il caso in cui il giro dice "il test non si e' accorto" per colpa dell'arness);
  - il file mutato COMPILA: un giro che muore all'import darebbe "il test non arriva al riepilogo", cioe'
    un rosso dell'arness spacciato per un rosso del test.

Non verifica che il test diventi rosso: quello lo fa il negative, eseguendolo.

  python3 scripts/test/prova_frammenti_gestore_gare.py
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
NEG = os.path.join(HERE, 'negative_gestore_gare.sh')
SRC = os.path.normpath(os.path.join(HERE, '..', '..', 'backend', 'app', 'routers', 'tornei.py'))
COPPIE = [('APERTO', 'APERTO_ROT'), ('CHIUSO', 'CHIUSO_ROT'), ('LEGACY', 'LEGACY_ROT'),
          ('GETT', 'GETT_ROT'), ('RESP', 'RESP_ROT'), ('MSG', 'MSG_ROT')]

if not os.path.exists(NEG):
    print(f'  FAIL manca {NEG}')
    raise SystemExit(1)
if not os.path.exists(SRC):
    print(f'  FAIL manca {SRC} (lo script assume di girare dal repo)')
    raise SystemExit(1)

# I frammenti sono assegnazioni bash a inizio riga, alcune multiriga e con apici annidati: li valuti bash
# stesso, non un regex mio che spezzerebbe al primo \n -- un'àncora troncata a meta' sarebbe risultata "ok"
# e il controllo avrebbe detto verde su un frammento rotto.
blocco = subprocess.run(['sed', '-n', '/^# ---- i frammenti/,/^SCELTO=/p', NEG],
                        capture_output=True, text=True, check=True).stdout
if not blocco.strip():
    print('  FAIL nel negative non trovo il blocco "# ---- i frammenti ... SCELTO=": questo controllo')
    print('       non sta verificando niente. Aggiornarlo insieme al negative, non rimuoverlo.')
    raise SystemExit(1)

tmpdir = tempfile.mkdtemp(prefix='thof-frammenti-')
fr_sh = os.path.join(tmpdir, 'frammenti.sh')
probe = os.path.join(tmpdir, 'mutato_probe.py')
open(fr_sh, 'w', encoding='utf-8').write(blocco)

nomi = [n for coppia in COPPIE for n in coppia]
cmd = ['bash', '-c', 'set -u; source "$1"; for n in "${@:2}"; do printf "%s\\n%s\\n---FRAMMENTO---\\n" "$n" "${!n}"; done',
       '_', fr_sh] + nomi
out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
frag = {}
for blocco_frag in out.split('---FRAMMENTO---\n'):
    if not blocco_frag.strip():
        continue
    nome, _, testo = blocco_frag.partition('\n')
    # `printf "%s\n%s\n"` aggiunge UN newline in coda: senza toglierlo, un'àncora che nel sorgente non
    # finisce a capo non matcha piu' e il controllo dice "0 occorrenze" su un frammento giusto
    if testo.endswith('\n'):
        testo = testo[:-1]
    frag[nome.strip()] = testo

src = open(SRC, encoding='utf-8').read()
rc = 0
for ancora, rot in COPPIE:
    a = frag.get(ancora)
    r = frag.get(rot)
    if a is None or r is None:
        print(f'  FAIL {ancora}/{rot} non definito nel negative')
        rc = 1
        continue
    n = src.count(a)
    if n != 1:
        print(f'  FAIL {ancora}: {n} occorrenze in tornei.py (attesa 1) -> il giro non e\' applicabile')
        rc = 1
    else:
        print(f'  ok   {ancora}: 1 occorrenza')
    if a == r:
        print(f'  FAIL {rot} identico a {ancora}: la mutazione non cambierebbe nessun byte')
        rc = 1
    elif src.count(r) != 0:
        print(f'  ATTENZIONE {rot} e\' gia\' presente nel sorgente: il "mutazione non partita" non lo vedrebbe')
    open(probe, 'w', encoding='utf-8').write(src.replace(a, r, 1))
    p = subprocess.run([sys.executable, '-m', 'py_compile', probe], capture_output=True, text=True)
    if p.returncode != 0:
        print(f'  FAIL {rot}: il file mutato non compila ({p.stderr.strip().splitlines()[-1]})')
        rc = 1
    else:
        print(f'  ok   {rot}: il file mutato compila')

# L'ultimo pezzo, e quello che rende utile tutto il resto: le ancore che il negative ELA nel suo elenco
# `ANCORE=(...)` devono essere le stesse stringhe che questo controllo prova. Se il negative aggiungesse un
# giro senza aggiungerlo qui, il nuovo àncora resterebbe senza controllo statico e la cosa si vedrebbe solo
# a meta' dei sei giri, venti minuti dopo. Confronto per **valore**, non per nome: `APERTO` e `CHIUSO` sono
# lo stesso testo (il secondo ne cambia solo la sostituzione), e il negative li elenca una volta sola
# L'elenco si legge con un regex sul testo, NON con `sed -n '/^ANCORE=(/,/)$/p'`: in GNU sed l'indirizzo
# di fine viene cercato dalla riga SUCCESSIVA a quella di inizio, quindi una definizione su una riga sola
# non chiude il range e sed prosegue fino alla prossima riga che finisce con `)`. Qui si era portata dietro
# l'echo del paragrafo e il ciclo di guardia: eseguiti, hanno stampato testo finito dentro l'elenco, e il
# controllo ha dichiarato "àncora mancante" per una stringa giusta piu' un finto àncora fantasma
m_anc = re.search(r'^ANCORE=\(([^)]*)\)', open(NEG, encoding='utf-8').read(), re.M)
elenco = 'ANCORE=(' + m_anc.group(1) + ')' if m_anc else ''
if not elenco.strip():
    print('  FAIL nel negative non trovo l\'elenco ANCORE=(...): il guardiano del pristino non c\'e\' piu\'')
    rc = 1
else:
    with open(fr_sh, 'a', encoding='utf-8') as fh:
        fh.write('\n' + elenco + '\n')
    out_a = subprocess.run(
        ['bash', '-c', 'set -u; source "$1"; for a in "${ANCORE[@]}"; do printf "%s\\n---ANCORA---\\n" "$a"; done',
         '_', fr_sh], capture_output=True, text=True, check=True).stdout
    dichiarate = {x for x in out_a.split('---ANCORA---\n') if x.strip()}
    dichiarate = {x[:-1] if x.endswith('\n') else x for x in dichiarate}
    attese = {frag[a] for a, _ in COPPIE}
    mancanti = sorted(attese - dichiarate)
    non_coperte = sorted(dichiarate - attese)
    if mancanti:
        for m in mancanti:
            print(f'  FAIL un\'àncora verificata qui NON e\' nell\'elenco ANCORE del negative: '
                  f'{m[:60]!r}...')
        rc = 1
    if non_coperte:
        # E' il verso che conta: un giro aggiunto al negative e non aggiunto qui resterebbe senza
        # controllo statico, e la cosa si vedrebbe solo a meta' dei giri, venti minuti dopo
        for m in non_coperte:
            print(f'  FAIL il negative ha un\'àncora che questo controllo NON prova: {m[:60]!r}... '
                  f'-> aggiungere la coppia a COPPIE')
        rc = 1
    if not mancanti and not non_coperte:
        print(f'  ok   le {len(dichiarate)} ancore del negative sono le stesse {len(attese)} coperte qui '
              f'(nessuna in piu\', nessuna in meno)')

for f in (fr_sh, probe):
    try:
        os.remove(f)
    except OSError:
        pass
shutil.rmtree(tmpdir, ignore_errors=True)
raise SystemExit(rc)
