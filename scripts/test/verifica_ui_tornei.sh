#!/bin/bash
# Verifica VISIVA della pagina Tornei (http://192.168.178.133:3000/responsabili/tornei) con Chrome
# headless: fa login come responsabile, apre le sezioni, apre i calendari, assegna il Mister dal
# menu, preme i TRE pulsanti di export (scaricando e leggendo i PDF), "+ Aggiungi gara" ed "Elimina"
# (con confirm intercettato), e riporta cosa c'e' davvero a schermo.
#
# Perche' esiste, accanto ai test API: i test di scripts/test fermano il backend, non il browser.
# I difetti di questa pagina che nessun altro test vede, e che questo ha trovato davvero:
#   1. un helper citato dal template e non piu' definito sarebbe una pagina bianca, non un 500;
#   2. i colori della pagina erano scritti per un tema scuro che l'app non ha, e a schermo i bottoni
#      delle azioni risultavano grigio chiarissimo su bianco, illeggibili;
#   3. l'export sembrava funzionare e non scaricava niente (mancava l'import del plugin autotable,
#      e l'errore moriva dentro il try/catch);
#   4. il menu del Mister poteva offrire le persone sbagliate (dirigenti, o solo la prima categoria).
#
# NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Chrome e pdftotext, e crea
# dati di prova con nome e categoria veri. Si lancia a mano:
#   bash scripts/test/verifica_ui_tornei.sh
# Esce 0 se tutto e' verde e la console della pagina e' pulita. Le schermate finiscono in
# /tmp/opencode/ui/*.png, per guardarle davvero.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/usr/bin/google-chrome-stable}"

if [ ! -x "$CHROME" ]; then
  echo "serve Google Chrome ($CHROME). Sovrascrivibile con CHROME=/percorso/chrome"
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then echo "serve node"; exit 1; fi
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "serve pdftotext (poppler-utils): senza, le asserzioni sui PDF non misurano niente"
  exit 1
fi

# Prima di accendere Chrome: un identificatore del template che non e' un binding di <script setup>
# diventa undefined a runtime, e la pagina e' BIANCA senza che nessun build si lamenti. Costano due
# secondi, e senza questi due secondi si passa mezz'ora a chiedersi perche' il test non trova niente
echo "--- controllo statico del template ---"
(cd "$DIR/../../frontend" && node "$DIR/controllo_template.cjs" src/features/partite/Tornei.vue)
if [ $? -ne 0 ]; then
  echo "  il template usa identificatori che <script setup> non espone: la pagina sarebbe bianca"
  echo "  0 passati, 1 falliti (controllo template)"
  exit 1
fi

echo "--- preparo i dati di prova su DEV ---"
PREP=$(bash "$DIR/prepara_demo_tornei.sh" 2>&1)
echo "$PREP" | sed 's/^/  /'
PW=$(printf '%s' "$PREP" | sed -n 's/.*password_admin_demo=\(.*\)/\1/p' | tail -1)
# L'id del mister senza categoria, per le asserzioni sul menu che deve mostrare anche il referente
# "fuori lista". Se non arriva, le asserzioni sotto si fermerebbero da sole: meglio un rosso dichiarato
MISTER_FUORI=$(printf '%s' "$PREP" | sed -n 's/.*mister_fuori_lista=\([0-9]*\).*/\1/p' | tail -1)
if [ -z "$PW" ]; then
  echo "  i dati di prova non sono stati creati: mi fermo, perche' senza pagina le asserzioni non misurano niente"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti)"
  exit 1
fi

echo
echo "--- apro la pagina con Chrome headless ---"
node "$DIR/ui_tornei.cjs" demo_tornei "$PW" "$MISTER_FUORI"
RC=$?

echo
echo "--- ripulisco i dati di prova ---"
bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
echo "  fatto"

[ "$RC" -eq 0 ] && exit 0 || exit 1
