#!/bin/bash
# Guard-rail sul README: deve dichiarare la stessa versione dell'ultimo tag, e deve avere la sua
# sezione "Novita'".
#
# Perche' esiste. Il README ha un blocco Release con la versione dichiarata e le "Novita'" per
# release, cioe' una DUPLICAZIONE del CHANGELOG. release.sh pero' scriveva solo il CHANGELOG, cosi'
# il README e' rimasto fermo alla v7.4.0 per 12 release (dal 25/09 al 24/11/2026): la pagina che un
# estraneo legge per prima raccontava un prodotto di due mesi e undici release piu' vecchio. E' la
# classe "plausibile e falso" applicata alla documentazione: niente si rompe, nessun test diventa
# rosso, e l'unica prova e' qualcuno che guarda e se ne accorge.
#
# Da qui due regole:
#   - release.sh aggiorna il README insieme al tag (sotto il marcatore <!-- RELEASE_INFO -->);
#   - QUESTO file verifica che l'abbia fatto, perche' un meccanismo di sincronizzazione che nessuno
#     verifica e' esattamente cio' che ha permesso il drift.
#
# Perche' verifica solo l'ULTIMO tag, e non tutti. Le release vecchie precedono la convenzione, e
# alcune sono state raggruppate in un'unica sezione (es. "Novita' v7.5.0 – v7.5.2"): un controllo su
# tutti i tag sarebbe rosso su cose giuste. Cio' che non puo' MAI essere rotto e l'ultimo tag: se
# release.sh si rompe, o se qualcuno modifica il README a mano, si vede qui. Le lacune storiche
# vengono riportate come NOTA, perche' un problema reale che nessuno guarda diventa rumore, e il
# rumore e' cio' che rende ignorabili gli avvisi veri.
#
# Si lancia da solo (non tocca ne' DEV ne' il DB): basta git e il file.
set -u
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR" || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL non riesco a entrare nella root del progetto"; exit 1; }

pass=0; fail=0
ck() { # ck <cosa> <avuto> <atteso>
  if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1";
  else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi
}

# ── prerequisito: l'ultimo tag semver raggiungibile da HEAD ─────────────────────────
ULTIMO=$(git tag --merged HEAD 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
         | sort -V | tail -1)
if [ -z "$ULTIMO" ]; then
  echo "  0 passati, 1 falliti (prerequisiti)"
  echo "  FAIL nessun tag semver raggiungibile da HEAD: il test non ha niente da confrontare"
  exit 1
fi
if [ ! -f README.md ]; then
  echo "  0 passati, 1 falliti (prerequisiti)"
  echo "  FAIL README.md assente: non c'e' niente da verificare"
  exit 1
fi
if [ ! -f CHANGELOG.md ]; then
  echo "  0 passati, 1 falliti (prerequisiti)"
  echo "  FAIL CHANGELOG.md assente: il README rimanda a un file che non c'e'"
  exit 1
fi
echo "=== README allineato all'ultimo tag? (ultimo tag: $ULTIMO) ==="

# ── 1. la riga della versione ───────────────────────────────────────────────────────
# Conteggio ESATTO: zero occorrenze significa che release.sh non trova piu' il pattern e quindi
# non aggiorna piu' nessuno; due significa che qualcuno ne ha aggiunta una copia, e la seconda
# sarebbe verde anche con la versione vecchia.
N_VERSIONI=$(grep -cE '^La versione attuale è \*\*v[0-9][0-9.]*\*\*\.$' README.md)
ck "nel README c'e' esattamente UNA riga di versione" "$N_VERSIONI" "1"
DICHIARATA=$(grep -oE '^La versione attuale è \*\*v[0-9][0-9.]*\*\*\.$' README.md | grep -oE 'v[0-9][0-9.]*')
ck "il README dichiara l'ultimo tag rilasciato" "$DICHIARATA" "$ULTIMO"

# ── 2. la sezione Novita' di quella release ─────────────────────────────────────────
N_SEZ=$(grep -cE "^### [^#]*Novità ${ULTIMO}\b" README.md)
ck "il README ha la sezione Novita' di $ULTIMO" "$N_SEZ" "1"

# ── 3. il marcatore che release.sh usa per inserire le novita' ──────────────────────
ck "il marcatore <!-- RELEASE_INFO --> e' presente (e' li' che release.sh inserisce)" \
   "$(grep -cE '^<!-- RELEASE_INFO -->$' README.md)" "1"

# ── 4. il CHANGELOG, che il README cita come fonte completa ─────────────────────────
ck "il CHANGELOG ha la voce di ${ULTIMO#v}" \
   "$(grep -cE "^## \[${ULTIMO#v}\]" CHANGELOG.md)" "1"

# ── nota: le lacune storiche, riportate ma non fatte fallire (vedi testa del file) ───
python3 - "$ULTIMO" <<'PY'
import re, subprocess, sys
ultimo = sys.argv[1]
tags = [t for t in subprocess.run(['git','tag','--merged','HEAD'],capture_output=True,text=True
        ).stdout.split() if re.match(r'^v\d+\.\d+\.\d+$', t)]
tags.sort(key=lambda s: [int(x) for x in s[1:].split('.')])
cl = open('CHANGELOG.md', encoding='utf-8').read()
senza = [t for t in tags if f'## [{t[1:]}]' not in cl]
if senza:
    print(f"  NOTA {len(senza)} tag senza voce nel CHANGELOG: {' '.join(senza)}")
    print("       (lacune storiche precedenti la convenzione di release.sh; l'ultimo tag invece")
    print("        viene asserito qui sopra, perche' e' li' che il meccanismo si rompe)")
PY

echo "  ------------------------------------------------------------------"
echo "  $pass passati, $fail falliti"
[ "$fail" = "0" ] || exit 1
