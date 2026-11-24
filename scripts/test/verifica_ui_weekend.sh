#!/bin/bash
# Verifica VISIVA dei PDF di Programmazione Partite (http://192.168.178.133:3000/responsabili/partite)
# con Chrome headless: apre il weekend, preme "Calendario weekend (PDF)" e "Gare genitori (PDF)",
# scarica i file e ne legge
# il testo, poi esporta anche il documento della pagina Tornei e confronta le due FORME.
#
# Perche' esiste: l'intestazione e lo stile di tabella dei due calendari sono passati in
# frontend/src/core/utils/pdfTHOF.js perche' restino lo stesso documento. Condividere il codice senza
# misurare l'output non prova niente: qui si misura che il titolo, il sottotitolo, la barra di
# categoria e la colonna Mister siano gli stessi su entrambi.
#
# NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Chrome e pdftotext. Si lancia
# a mano:
#   bash scripts/test/verifica_ui_weekend.sh
# Esce 0 se tutto e' verde e la console della pagina e' pulita.
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

echo "--- controllo statico dei template ---"
(cd "$DIR/../../frontend" && node "$DIR/controllo_template.cjs" src/features/partite/ProgrammazionePartite.vue) || {
  echo "  il template usa identificatori che <script setup> non espone: la pagina sarebbe bianca"
  echo "  0 passati, 1 falliti (controllo template)"
  exit 1
}
(cd "$DIR/../../frontend" && node "$DIR/controllo_template.cjs" src/features/partite/Tornei.vue) || {
  echo "  idem per la pagina Tornei, che e' il secondo consumatore del formato condiviso"
  echo "  0 passati, 1 falliti (controllo template)"
  exit 1
}

echo "--- preparo i dati di prova su DEV (servono al documento di confronto) ---"
PREP=$(bash "$DIR/prepara_demo_tornei.sh" 2>&1)
echo "$PREP" | sed 's/^/  /'
PW=$(printf '%s' "$PREP" | sed -n 's/.*password_admin_demo=\(.*\)/\1/p' | tail -1)
if [ -z "$PW" ]; then
  echo "  i dati di prova non sono stati creati: mi fermo, perche' senza pagina le asserzioni non misurano niente"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti)"
  exit 1
fi

echo
echo "--- apro la pagina con Chrome headless ---"
node "$DIR/ui_weekend.cjs" demo_tornei "$PW"
RC=$?

echo
echo "--- ripulisco i dati di prova ---"
bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
echo "  fatto"

[ "$RC" -eq 0 ] && exit 0 || exit 1
