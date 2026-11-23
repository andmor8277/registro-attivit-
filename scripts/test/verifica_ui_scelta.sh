#!/bin/bash
# Verifica VISIVA delle card di Scelta.vue (http://192.168.178.133:3000/scelta/:id) con Chrome
# headless, con DUE account: un mister (deve vedere Convocazioni, Convocazioni Tornei e Liste Tornei)
# e un dirigente (non le deve vedere).
#
# Perche' esiste. Il difetto che deve acchiappare e' "la card non si vede", e su questa pagina ne
# esistono di due tipi, entrambi invisibili al build di Vite e al grep sul chunk:
#   1. un identificatore del template che <script setup> non espone -> pagina BIANCA, il build passa;
#   2. la guardia v-if sbagliata -> la card c'e' nel bundle, il grep dice "ok", a schermo non compare.
# Il caso 2 e' quello reale del 2026-11-23: "Liste Tornei" era raggiungibile solo dal link in fondo a
# Dati & Matricole, una pagina di segreteria, e nessun test se n'era accorto perche' nessun test apre
# un browser.
#
# Il grep sul chunk servito NON e' sufficiente, e qui va detto chiaramente: dimostra che la stringa e'
# stata distribuita, non che il pulsante sia dipinto. Lo screenshot in /tmp/opencode/ui/*.png e' parte
# del test, non un accessorio.
#
# NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Google Chrome e crea dati di
# prova. Si lancia a mano:
#   bash scripts/test/verifica_ui_scelta.sh
# Esce 0 se le due sessioni sono verdi.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/usr/bin/google-chrome-stable}"

if [ ! -x "$CHROME" ]; then
  echo "serve Google Chrome ($CHROME). Sovrascrivibile con CHROME=/percorso/chrome"
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then echo "serve node"; exit 1; fi

# Prima di accendere Chrome: un identificatore del template che non e' un binding di <script setup>
# diventa undefined a runtime e la pagina e' BIANCA senza che nessun build si lamenti. Costano due
# secondi, e senza questi due secondi si passa mezz'ora a chiedersi perche' il test non trova niente.
# Sono tre file perche' la modifica e' a tre mani: la card nuova in Scelta.vue, il link tolto da
# DatiMatricole.vue e le due voci aggiunte in App.vue (sidebar E menu mobile).
echo "--- controllo statico dei template ---"
RC_TOT=0
for f in src/features/home/Scelta.vue src/features/segreteria/DatiMatricole.vue src/App.vue; do
  (cd "$DIR/../../frontend" && node "$DIR/controllo_template.cjs" "$f")
  if [ $? -ne 0 ]; then
    echo "  il template usa identificatori che <script setup> non espone: la pagina sarebbe bianca"
    RC_TOT=1
  fi
done
if [ "$RC_TOT" -ne 0 ]; then
  echo "  0 passati, 1 falliti (controllo template)"
  exit 1
fi

echo "--- preparo i dati di prova su DEV ---"
# Gli serve il torneo: la card Liste Tornei apre il foglio del torneo della categoria, e senza dati
# la pagina che si apre dopo il click sarebbe vuota perche' non c'e' niente da mostrare, non per un
# difetto. prepara_demo_tornei.sh crea anche i due account che servono qui (demo_tornei_mister1 e
# demo_tornei_dirigente, entrambi assegnati alla categoria 19 - 2016 Pulcini) con la stessa password.
PREP=$(bash "$DIR/prepara_demo_tornei.sh" 2>&1)
echo "$PREP" | sed 's/^/  /'
PW=$(printf '%s' "$PREP" | sed -n 's/.*password_admin_demo=\(.*\)/\1/p' | tail -1)
if [ -z "$PW" ]; then
  echo "  i dati di prova non sono stati creati: mi fermo, perche' senza pagina le asserzioni non misurano niente"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti)"
  exit 1
fi

CAT=19   # 2016 - Pulcini, la categoria a cui prepara_demo_tornei.sh assegna mister1 e dirigente
RC=0

# I due account si passano PORTA CDP DIVERSI: se Chrome restasse vivo fra i due run (e' gia'
# successo con ui_tornei.cjs, che senza Browser.close non rilascia la porta), il secondo si
# attaccherebbe al browser del primo e leggerebbe una pagina gia' caricata, verde per inerzia.
echo
echo "=== 1/2  mister: le tre card le DEVE vedere ==="
THOF_UI_PORT=9231 node "$DIR/ui_scelta_cardine.cjs" demo_tornei_mister1 "$PW" "$CAT" visible || RC=1

# /auth/token ha @limiter.limit("10/minute") PER WORKER (4 worker): due login ravvicinati reggono,
# ma fra le due sessioni un respiro costa niente e toglie il 429 dal novero dei rossi possibili
sleep 8

echo
echo "=== 2/2  dirigente: le tre card NON le deve vedere ==="
THOF_UI_PORT=9232 node "$DIR/ui_scelta_cardine.cjs" demo_tornei_dirigente "$PW" "$CAT" hidden || RC=1

echo
echo "--- ripulisco i dati di prova ---"
bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
echo "  fatto"
echo "  schermate in /tmp/opencode/ui/*.png"

[ "$RC" -eq 0 ] && exit 0 || exit 1
