#!/bin/bash
# Runner dei NEGATIVE TEST del guard-rail della lavagna (scripts/test/ui_lavagna.cjs).
#
# Perche' esiste: un test che non ho visto rosso non ha testato niente. Qui si sfidano LE CINQUE
# serializzazioni dello stesso elemento, una per volta, e per ognuna si asserisce quali asserzioni
# DEVONO diventare rosse e quali devono restare verdi. Il verso "devono restare verdi" conta quanto
# l'altro: se una mutazione ne accende dieci a caso, il test non e' discriminatorio e non prova nulla.
#
# Le cinque superfici (e' esattamente il motivo per cui "la lavagna si rompe"):
#   loadelement  -> ramo di loadElement tolto      : sparisce alla riapertura IN SILENZIO
#   getelements  -> rami di getElements rinominati : l'oggetto perde il colore o la misura
#   pdf          -> tipo rinominato in drawElementsCanvas: a schermo c'e', nel PDF no
#   etichetta    -> etichetta palette cambiata     : il pulsante a schermo non corrisponde al sorgente
#   whitelist    -> campo tolto dalla lista bianca : arriva a terra monco, e il conteggio non lo dice
#
# Due meta' diverse, e la differenza e' il punto:
#   la PARTE A legge il SORGENTE LOCALE   -> basta mutare il file qui
#   le PARTI B..F girano contro DEV        -> serve la mutazione dentro il container (--dev)
# Il caso `pdf` e' la prova regina: la mutazione e' visibile SOLO alla statica, il browser resta
# verde. E' la classe di difetto che nessuno vede perche' nessuno guarda il PDF dal test.
#
# Uso: bash scripts/test/negative_lavagna.sh            # tutti e cinque i casi
#        bash scripts/test/negative_lavagna.sh whitelist # uno solo
set -u
# REPO derivato dalla posizione dello script (non il path della mia postazione): un arnese dei
# negative test che solo io posso lanciare e' un arnese che nessuno rilancera'
REPO="${THOF_REPO:-$(cd "$(dirname "$0")/../.." && pwd)}"
MUTA="${THOF_REPO:-$(cd "$(dirname "$0")" && pwd)}/muta_lavagna.sh"
LOG=/tmp/opencode/neg-lavagna
mkdir -p "$LOG"
F="$REPO/frontend/public/lavagna-20250702.html"
A="$REPO/frontend/src/features/allenamenti/Allenamenti.vue"
PRISTINO_F=$(sha256sum "$F" | cut -c1-16)
PRISTINO_A=$(sha256sum "$A" | cut -c1-16)
echo "  pristino: lavagna=$PRISTINO_F allenamenti=$PRISTINO_A"

# caso atteso: <modo> <tipo> [--dev] | poi le asserzioni che DEVONO essere rosse e quelle verdi
cases() {
  case "$1" in
    loadelement)  echo "mutare loadelement ring --dev" ;;
    getelements)  echo "mutare getelements cone" ;;
    pdf)          echo "mutare pdf zone" ;;
    etichetta)    echo "mutare etichetta ring" ;;
    whitelist)    echo "mutare whitelist size --dev" ;;
    *) return 1 ;;
  esac
}
# pattern di cio' che DEVE diventare rosso (uno per riga) e di cio' che DEVE restare verde
expected_rossi() {
  case "$1" in
    loadelement)  printf '%s\n' "esiste in loadElement" "si perde alla riapertura" "si perde nel caricamento sintetico" ;;
    # perche' SOLO la statica: il `tipo` serializzato viene preso da child.getAttr('dataElement')
    # (riga 393), NON da questi rami. Rinominarli fa perdere al cono il COLORE o la MISURA, non
    # l'esistenza -- pretendere rosso su "si perde nel salvataggio" qui era una aspettativa sbagliata,
    # e il primo giro lo ha dimostrato bloccandosi. Per il tipo che sparisce davvero c'e' `whitelist`.
    getelements)  printf '%s\n' "esiste in getElements" ;;
    pdf)          printf '%s\n' "esiste in pdf" ;;
    etichetta)    printf '%s\n' "un pulsante a schermo" "il pulsante e' cliccabile" ;;
    # la lista bianca del payload: qui il campo SPARISCE dal viaggio schermo->DB. Rossa la statica
    # che lo dichiara e rossa la confronto campo-per-campo; il CONTEGGIO degli elementi resta giusto
    # ed e' esattamente per questo che le asserzioni "nessun tipo si perde" non bastavano
    whitelist)    printf '%s\n' "il campo size sopravvive al payload" "arriva a terra identico" ;;
  esac
}
expected_verdi() {
  case "$1" in
    loadelement)  printf '%s\n' "esiste in getElements" "esiste in pdf" "si perde nel salvataggio" "arriva a terra identico" ;;
    getelements)  printf '%s\n' "esiste in loadElement" "esiste in pdf" "si perde nel salvataggio" \
                            "si perde alla riapertura" "si perde nel caricamento sintetico" "arriva a terra identico" ;;
    pdf)          printf '%s\n' "esiste in getElements" "esiste in loadElement" "si perde alla riapertura" \
                            "il server ha gli stessi elementi" "arriva a terra identico" ;;
    etichetta)    printf '%s\n' "esiste in getElements" "esiste in loadElement" "esiste in pdf" "si perde alla riapertura" ;;
    whitelist)    printf '%s\n' "si perde nel salvataggio" "si perde alla riapertura" "esiste in getElements" \
                            "esiste in loadElement" "esiste in pdf" "il campo tipo sopravvive al payload" ;;
  esac
}

UNO="${1:-}"
LISTA="loadelement getelements pdf etichetta whitelist"
[ -n "$UNO" ] && LISTA="$UNO"
ESITO=0

for caso in $LISTA; do
  echo
  echo "════════════════════════════════════════════════════════════"
  echo "  NEGATIVE TEST: $caso"
  echo "════════════════════════════════════════════════════════════"
  ARG=$(cases "$caso") || { echo "  caso sconosciuto: $caso"; ESITO=1; continue; }
  # shellcheck disable=SC2086
  bash "$MUTA" $ARG | sed 's/^/  /'
  RC_MUTA=$?
  if [ $RC_MUTA -ne 0 ]; then echo "  BLOCCATO: la mutazione non e' partita ($RC_MUTA): un eventuale verde sarebbe un falso verde"; bash "$MUTA" ripristino >/dev/null; ESITO=1; continue; fi

  # la mutazione deve essere PARTITA: hash cambiato, e la stringa del tipo non deve piu' esserci dove
  # doveva sparire
  NOW_F=$(sha256sum "$F" | cut -c1-16); NOW_A=$(sha256sum "$A" | cut -c1-16)
  if [ "$NOW_F" = "$PRISTINO_F" ] && [ "$NOW_A" = "$PRISTINO_A" ]; then
    echo "  BLOCCATO: nessun file e' cambiato dopo la mutazione"; bash "$MUTA" ripristino >/dev/null; ESITO=1; continue
  fi
  echo "  mutato: lavagna=$NOW_F allenamenti=$NOW_A"

  bash "$REPO/scripts/test/verifica_ui_lavagna.sh" > "$LOG/$caso.log" 2>&1
  RC=$?
  echo "  esito test con la mutazione: exit=$RC"
  grep -E "passati, |^  FAIL" "$LOG/$caso.log" | sed 's/^/    /' | cut -c1-165

  # 1) ogni asserzione attesa deve essere rossa
  MANCANO=0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if ! grep -q "FAIL.*$p" "$LOG/$caso.log"; then echo "    MANCATO ROSSO: nessuna asserzione rossa su '$p'"; MANCANO=1; fi
  done < <(expected_rossi "$caso")
  # 2) le asserzioni sorelle devono essere RESTATE verdi: e' la discrimine
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if grep -q "FAIL.*$p" "$LOG/$caso.log"; then echo "    ROSSO INDESIDERATO: '$p' doveva restare verde"; MANCANO=1; fi
  done < <(expected_verdi "$caso")
  [ $RC -eq 0 ] && { echo "    MANCATO ROSSO: il test e' uscito 0 con una mutazione in corso"; MANCANO=1; }
  [ $MANCANO -eq 0 ] && echo "    OK: la mutazione e' stata vista, e solo li'"
  [ $MANCANO -ne 0 ] && ESITO=1

  bash "$MUTA" ripristino | sed 's/^/  /'
  RIP_F=$(sha256sum "$F" | cut -c1-16); RIP_A=$(sha256sum "$A" | cut -c1-16)
  if [ "$RIP_F" != "$PRISTINO_F" ] || [ "$RIP_A" != "$PRISTINO_A" ]; then
    echo "  BLOCCATO: ripristino non riuscito (lavagna=$RIP_F allenamenti=$RIP_A)"; ESITO=1
  else
    echo "  ripristino verificato per hash"
  fi
done

echo
echo "════════════════════════════════════════════════════════════"
[ $ESITO -eq 0 ] && echo "  tutti i negative test hanno funzionato" || echo "  ALCUNI NEGATIVE TEST NON HANNO FUNZIONATO"
echo "════════════════════════════════════════════════════════════"
exit $ESITO
