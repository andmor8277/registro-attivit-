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
# In piu' i tre giri sulla richiesta del titolare del 25/11/2026 (Jolly e Portiere pieni, lettera J/P,
# rombo). Sono un'altra classe, e per questo stanno accanto e non in mezzo ai cinque: non toccano nessuna
# serializzazione, toccano cio' che il nodo Konva E' a schermo. `getElements` non serializza il riempimento,
# quindi la statica non li puo' vedere -- e infatti fra le asserzioni che DEVONO restare verdi c'e' proprio
# "esiste in getElements"/"esiste in pdf". Un difetto che esiste solo sul vetro ha bisogno di un test che
# guardi il vetro:
#   jolly-vuoto  -> Jolly e Portiere rimessi VUOTI dentro  : era esattamente il difetto segnalato
#   rombo        -> rotation:45 sul RegularPolygon          : il Jolly torna quadrato, la miniatura rombo
#   jolly-numero -> il Jolly ridipinge il numero            : la lettera J non c'e' piu'
#
# Poi i due giri sui 132 elementi salvati con i tipi di una versione vecchia della lavagna (player-red,
# disk-orange, ...), che prima non si dipingevano da nessuna parte:
#   legacy-identita -> tipoDisegno diventa l'identita'  : gli oggetti SPARISCONO in silenzio, e la misura
#                                                        statica resta verde perche' la mappa e' intatta
#   legacy-forma    -> player-red mappato su 'ball'     : l'elemento c'e', ma e' un altro oggetto
#
# Due meta' diverse, e la differenza e' il punto:
#   la PARTE A legge il SORGENTE LOCALE   -> basta mutare il file qui
#   le PARTI B..F girano contro DEV        -> serve la mutazione dentro il container (--dev)
# Il caso `pdf` e' la prova regina: la mutazione e' visibile SOLO alla statica, il browser resta
# verde. E' la classe di difetto che nessuno vede perche' nessuno guarda il PDF dal test.
#
# Uso: bash scripts/test/negative_lavagna.sh            # tutti i dieci giri
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
    # i tre giri sulla richiesta del titolare del 25/11/2026 (Jolly e Portiere pieni, lettera J/P, rombo).
    # Tutti e tre servono `--dev`: sono asserzioni sul nodo Konva reso dal BROWSER, la sola Parte A non le
    # vede -- e infatti la statica deve restare verde, ed e' quello che asseriamo qui sotto
    jolly-vuoto)  echo "mutare jolly-vuoto --dev" ;;
    rombo)        echo "mutare rombo --dev" ;;
    jolly-numero) echo "mutare jolly-numero --dev" ;;
    # i due giri sui 132 elementi con i tipi della vecchia lavagna (player-red, disk-orange, ...).
    # `legacy-identita` e' il piu' utile: la mappa resta intatta, quindi la misura STATICA continua a
    # dire "0 buchi", e solo il browser vede che gli oggetti sono spariti. `legacy-forma` e' il
    # discriminatorio sull'asserzione della forma: l'elemento c'e', ma e' disegnato come un altro oggetto
    legacy-identita) echo "mutare legacy-identita --dev" ;;
    legacy-forma)    echo "mutare legacy-forma --dev" ;;
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
    # Jolly e Portiere tornano VUOTI: devono diventare rosse le tre asserzioni che guardano il nodo Konva
    # (riempimento, colore della lettera, fixedFill). Che la statica resti verde e' parte della prova:
    # un riempimento non e' un campo serializzato, nessun controllo sul sorgente lo puo' vedere
    jolly-vuoto)  printf '%s\n' "l'interno e' colorato" "la lettera e' bianca su fondo colorato" "la lettera e' protetta" ;;
    rombo)        printf '%s\n' "il Jolly e un ROMBO" ;;
    jolly-numero) printf '%s\n' "la lettera e' 'J', non il numero" ;;
    # la normalizzazione legacy e' l'unica cosa che tiene visibili 132 elementi: tolta quella, spariscono
    # senza errori. La statica resta VERDE (la mappa e' intatta, e' la funzione che non la consulta), e
    # questo e' parte della prova: e' la classe di difetto che nessun controllo sul sorgente vede
    legacy-identita) printf '%s\n' "i due tipi legacy NON spariscono" "arriva a getElements" \
                             "il nodo Konva di player-red esiste" "il nodo Konva di disk-orange esiste" ;;
    # l'elemento arriva, ma disegnato come un altro oggetto: rossa SOLO l'asserzione sulla forma
    legacy-forma)    printf '%s\n' "si disegna come un giocatore" ;;
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
    # la lettera C'E' ancora, cambia solo il colore: se queste diventassero rosse, la mutazione starebbe
    # accendendo mezzo test e non sarebbe discriminatoria
    jolly-vuoto)  printf '%s\n' "la lettera e' 'J', non il numero" "la lettera e' 'P', non il numero" \
                            "il Jolly e un ROMBO" "esiste in getElements" "esiste in pdf" "nasce un elemento del suo tipo" ;;
    rombo)        printf '%s\n' "l'interno e' colorato" "la lettera e' 'J', non il numero" \
                            "la lettera e' bianca su fondo colorato" "esiste in pdf" ;;
    jolly-numero) printf '%s\n' "l'interno e' colorato" "la lettera e' bianca su fondo colorato" \
                            "la lettera e' protetta" "il Jolly e un ROMBO" "la lettera e' 'P', non il numero" ;;
    # i tipi veri non si toccano: se queste diventassero rosse la mutazione starebbe accendendo meta'
    # test. "un tipo sconosciuto non si aggiunge" e' il verso opposto della stessa funzione, e deve
    # continuare a valere anche con la normalizzazione spenta
    legacy-identita) printf '%s\n' "un tipo sconosciuto non si aggiunge" "il Jolly e un ROMBO" \
                             "l'interno e' colorato" "nessun tipo si perde nel salvataggio" ;;
    # qui gli oggetti CI SONO (cambia solo come sono dipinti): il conteggio deve restare verde, ed e'
    # esattamente la ragione per cui serve l'asserzione sulla forma e non solo quella sul conteggio
    legacy-forma)    printf '%s\n' "i due tipi legacy NON spariscono" "arriva a getElements" \
                             "il nodo Konva di disk-orange esiste" "il Jolly e un ROMBO" \
                             "un tipo sconosciuto non si aggiunge" ;;
  esac
}

# Le tre verifiche sul log di un giro, in UNA funzione. La autoprovatura in fondo (--prova-arnese) deve
# eseguire QUESTO codice e non una copia dei suoi grep: un negative dell'arnese scritto duplicando i
# pattern resterebbe verde anche con l'arnese rotto, cioe' non proverebbe niente
controlla_log() {
  local caso="$1" log="$2" rc="$3" p mancano=0
  # 1) ogni asserzione attesa deve essere rossa
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    grep -q "FAIL.*$p" "$log" || { echo "    MANCATO ROSSO: nessuna asserzione rossa su '$p'"; mancano=1; }
  done < <(expected_rossi "$caso")
  # 2) le asserzioni sorelle devono essere RESTATE verdi: e' la discrimine
  #    Non basta "non e' fra le FAIL": sarebbe verde anche se l'asserzione NON fosse proprio partita (il
  #    test si ferma prima) -- e' il falso verde gia' registrato per negative_registro.sh. Quindi si asserisce
  #    anche che COMPRAIA fra quelle eseguite, come riga `ok`.
  #    NON c'e' un confronto sul TOTALE delle asserzioni: misurato, `legacy-identita` ne esegue 173 su 175
  #    perche' i due ckVero che falliscono saltano le dipendenti (`if (n) ck(...)`), quindi un conteggio fisso
  #    sarebbe un falso rosso fisso. Si asserisce invece che il riepilogo ci sia: un test morto a meta' non lo
  #    stampa, ed e' il vero segnale di "verde ottenuto non misurando" (stessa regola di run_suite_dev.sh)
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if grep -q "FAIL.*$p" "$log"; then echo "    ROSSO INDESIDERATO: '$p' doveva restare verde"; mancano=1
    elif ! grep -q "^[[:space:]]*ok[[:space:]].*$p" "$log"; then
      echo "    NON ESEGUITA: '$p' doveva restare verde ma non compare fra le asserzioni eseguite"; mancano=1
    fi
  done < <(expected_verdi "$caso")
  grep -qE "[0-9]+ passati, [0-9]+ falliti" "$log" \
    || { echo "    IL TEST NON HA STAMPATO IL RIEPILOGO: e' morto per strada, nessun verde ha valore"; mancano=1; }
  [ "$rc" -eq 0 ] && { echo "    MANCATO ROSSO: il test e' uscito 0 con una mutazione in corso"; mancano=1; }
  [ $mancano -eq 0 ] && echo "    OK: la mutazione e' stata vista, e solo li'"
  return $mancano
}

# ── autoprovatura dell'arnese: `bash negative_lavagna.sh --prova-arnese` ──────────────────────────
# Un giro che dice "questa asserzione deve restare verde" dice NOTHING se quella asserzione non e' mai
# partita. Me ne sono accorto leggendo il mio codice, non da un rosso: per questo qui si sfida controlla_log
# su log manomessi, cosi' la prova che sa fallire non dipende dalla mia buona volonta'. Il fixture viene
# GENERATO dalle liste expected_rossi/expected_verdi: scrivere le etichette a mano avrebbe fatto provare
# una copia del log invece del log. Costa un secondo e non tocca ne' DEV ne' Chrome
prova_arnese() {
  local caso=legacy-forma f rc_ar=0 prima
  # Il fixture si GENERA dalle liste stesse: scrivere le etichette a mano avrebbe fatto provare una copia
  # del log invece del log. E si rigenera PRIMA DI OGNI caso: manomettendo in sequenza, il rosso del caso
  # successivo potrebbe venire dal caso prima -- e il caso non dimostrerebbe piu' niente da solo (difetto
  # gia' registrato per muta_registro.py)
  fai_fixture() {
    { expected_rossi "$caso" | sed 's/^/  FAIL /; s/$/ -> mutato per prova/'
      expected_verdi "$caso" | sed 's/^/  ok   /'
      echo '     174 passati, 1 falliti, 0 errori in console'
    } > "$1"
  }
  f=$(mktemp)

  echo "=== 1) log integro: l'arnese non deve dire niente (guardia contro i falsi rossi) ==="
  fai_fixture "$f"
  if controlla_log "$caso" "$f" 1; then echo "  ok   nessun falso rosso"; else echo "  DIFETTO DELL'ARNESE: giudica rotto un log sano"; rc_ar=1; fi

  echo "=== 2) un'asserzione 'da conservare verde' SPARISCE dal log (il test e' morto prima) ==="
  fai_fixture "$f"
  prima=$(expected_verdi "$caso" | head -1)
  grep -vF "$prima" "$f" > "$f.2" && mv "$f.2" "$f"
  if controlla_log "$caso" "$f" 1; then echo "  DIFETTO: '$prima' non c'e' piu' e l'arnese tace (era il falso verde)"; rc_ar=1
  else echo "  ok   vista come NON ESEGUITA"; fi

  echo "=== 3) il riepilogo non c'e' piu' (test morto a meta': '174 passati' sparito) ==="
  fai_fixture "$f"
  grep -vE "[0-9]+ passati, [0-9]+ falliti" "$f" > "$f.3" && mv "$f.3" "$f"
  if controlla_log "$caso" "$f" 1; then echo "  DIFETTO: nessun riepilogo e l'arnese tace"; rc_ar=1
  else echo "  ok   visto: il test non ha stampato il riepilogo"; fi

  echo "=== 4) un'asserzione attesa NON e' rossa (la mutazione non e' stata vista) ==="
  fai_fixture "$f"
  grep -v "^[[:space:]]*FAIL" "$f" > "$f.4" && mv "$f.4" "$f"
  if controlla_log "$caso" "$f" 1; then echo "  DIFETTO: nessuna asserzione rossa e l'arnese tace"; rc_ar=1
  else echo "  ok   visto come MANCATO ROSSO"; fi

  echo "=== 5) il test esce 0 con una mutazione in corso ==="
  fai_fixture "$f"
  if controlla_log "$caso" "$f" 0; then echo "  DIFETTO: exit 0 con mutazione applicata e l'arnese tace"; rc_ar=1
  else echo "  ok   visto: il test e' uscito 0 con la mutazione"; fi
  rm -f "$f"

  echo
  [ $rc_ar -eq 0 ] && echo "  l'arnese sa fallire: tutti e cinque i log manomessi sono stati visti, e il log integro no" \
                   || echo "  ARNESE DIFETTOSO: vedere le righe DIFETTO qui sopra"
  return $rc_ar
}

if [ "${1:-}" = "--prova-arnese" ]; then prova_arnese; exit $?; fi

# `--log <caso> <file> [rc]`: riapplica le tre verifiche a un log gia' scritto, senza riaccendere ne' DEV
# ne' Chrome. Serve a due cose: rivedere un verdetto di ieri, e provare le verifiche dell'arnese sui log
# REALI (il fixture di --prova-arnese e' generato, quindi non dimostra che il prefisso `ok` sia quello
# vero che ui_lavagna.cjs stampa)
if [ "${1:-}" = "--log" ]; then
  [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo "uso: $0 --log <caso> <file> [rc]"; exit 2; }
  [ -f "$3" ] || { echo "log non trovato: $3"; exit 2; }
  controlla_log "$2" "$3" "${4:-1}"; exit $?
fi

UNO="${1:-}"
LISTA="loadelement getelements pdf etichetta whitelist jolly-vuoto rombo jolly-numero legacy-identita legacy-forma"
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

  controlla_log "$caso" "$LOG/$caso.log" "$RC" || ESITO=1

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
