#!/bin/bash
# NEGATIVE TEST dell'export JPEG: rompe UNA cosa alla volta nella rasterizzazione e asserisce che
# scripts/test/verifica_ui_export_jpeg.sh se ne accorga.
#
# Perche' esiste. Il test dell'export JPEG e' verde e confronta PDF e JPEG per quattro documenti, ma
# un'asserzione verde da sola non dice che stia guardando la cosa giusta. Questo file ha gia' girato
# verde mentre il file JPEG non veniva nemmeno analizzato (Runtime.callFunctionOn senza objectId:
# l'errore CDP non propagato lasciava le asserzioni senza eseguire nulla), e verde era indistinguibile
# da "tutto a posto". L'unico modo di sapere che un'asserzione vede il difetto e' creare il difetto.
#
# Cosa si rompe, e perche' proprio queste: sono le quattro promesse della consegna "come e' previsto
# che esca il PDF deve uscire il JPEG" -- lo sfondo (il JPEG non ha alpha), il tetto dei DPI (che puo'
# toccare i DPI e MAI il contenuto), e le pagine da due angolazioni diverse: contate male nella
# geometria, e impilate nello stesso punto.
#
# Due controlli per giro, non uno (stessa disciplina di negative_registro.sh):
#   - ROSSI_ATTESI: almeno queste asserzioni devono diventare rosse;
#   - VERDI_DA_CONSERVARE: devono RESTARE verdi E DEVONO ESSERE STATE ESEGUITE. La seconda parte e' la
#     trappola vera: se il test si interrompe prima, l'asserzione "da conservare" e' ASSENTE, e
#     "non e' fra le rosse" sarebbe verde senza aver misurato niente.
# Se una mutazione non produce nessun rosso, il giro e' FALLITO.
#
# Una mutazione l'ho DOVUTA togliere, e vale la pena saperlo: "font-senza-metriche" (URL di
# standardFontDataUrl rotto) produceva ZERO rossi. Misurando, le JPEG venivano fuori byte-identiche e
# nginx non vedeva nemmeno una richiesta a /pdfjs/standard_fonts/: pdf.js rende i font standard col
# suo percorso di riserva. Un'asserzione che non si muove davanti al difetto che dovrebbe vedere non
# e' un'asserzione -- e i commenti che affermavano il contrario sono stati corretti.
#
# Si muta il chunk SERVITO dentro il container, non il sorgente: il browser esegue quei byte, quindi
# niente rebuild da 2 minuti a giro e nessun sorgente sporco in giro per DEV. Il rischio che si apre
# ("ho mutato un file che il browser non legge") si chiude a ogni giro verificando i byte SERVITI con
# curl, non fidandosi del disco.
#
# Si lancia a mano (vuole Chrome e ~3 minuti a mutazione):
#   bash scripts/test/negative_export_jpeg.sh                    # tutte
#   bash scripts/test/negative_export_jpeg.sh tetto-dei-dpi      # una sola
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
SCP="scp -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 -q"
REMOTE="root@192.168.178.133"
BASE="${THOF_UI_BASE:-http://192.168.178.133:3000}"
PY="$DIR/muta_export_jpeg.py"
LAVORO=/tmp/opencode/negative-export-jpeg
mkdir -p "$LAVORO/mut"

if [ ! -x "${CHROME:-/usr/bin/google-chrome-stable}" ]; then echo "serve Google Chrome"; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "serve node"; exit 1; fi

# ── cosa deve rompersi, e cosa no, per ogni mutazione ───────────────────────────────
declare -A ROSSI VERDI
# Lo sfondo nero deve accecare SOLO l'asserzione sul bianco: con tutto nero ogni pixel campionato e'
# "inchiostro", quindi le soglie d'inchiostro restano verdi -- e devono restarlo, perche' misurano
# un'altra cosa
ROSSI[sfondo-nero]="lo sfondo e' bianco"
VERDI[sfondo-nero]="l'aspect della JPEG e' quello delle|il nome file e' quello del PDF con .jpg|la pagina 3 del PDF ha inchiostro nella sua banda"
# Il tetto dei DPI: deve poter rendere il foglio ILLEGGIBILE e non toccare le pagine. E' l'asserzione
# della consegna del titolare, e per questo la si mette qui e non solo nel test positivo
ROSSI[tetto-dei-dpi]="larghezza sopra la soglia di leggibilita'"
VERDI[tetto-dei-dpi]="l'aspect della JPEG e' quello delle|almeno un documento esportato ha piu' di una pagina|il nome file e' quello del PDF con .jpg|occupa lo STESSO spazio del PDF"
# Geometria senza pagine: il canvas viene alto 1 pixel. Deve cadere l'aspect. La LARGHEZZA resta
# quella giusta (2526 px) e deve restare verde: e' la prova che a vedere la pagina persa e' l'aspect,
# non una soglia qualunque sulla dimensione
ROSSI[pagine-perse]="l'aspect della JPEG e' quello delle"
VERDI[pagine-perse]="larghezza sopra la soglia di leggibilita'|il nome file e' quello del PDF con .jpg|almeno un documento esportato ha piu' di una pagina"
# Pagine una sopra l'altra: l'canvas e' alto la somma, quindi l'aspect DEVE restare verde. Cade
# l'inchiostro delle bande successive -- ed e' esattamente l'asserzione che giustifica l'esistenza
# dell'inchiostro accanto all'aspect
ROSSI[pagine-sovrapposte]="ha inchiostro nella sua banda"
VERDI[pagine-sovrapposte]="l'aspect della JPEG e' quello delle|lo sfondo e' bianco|il nome file e' quello del PDF con .jpg"
# LA REGRESSIONE SEGNALATA DAL TITOLARE (24/11/2026): contenuto reso a 1/3 dentro un canvas delle
# misure giuste. Deve diventare rossa SOLO l'asserzione sul quadro. Che l'aspect e l'inchiostro
# RESTINO verdi non e' un dettaglio: e' la prova scritta che erano loro, le asserzioni che il titolare
# aveva visto verde mentre il foglio era illeggibile
ROSSI[scala-render]="occupa lo STESSO spazio del PDF"
VERDI[scala-render]="l'aspect della JPEG e' quello delle|la pagina 3 del PDF ha inchiostro nella sua banda|il nome file e' quello del PDF con .jpg|almeno un documento esportato ha piu' di una pagina"

# ── il chunk da mutare, preso dal container ─────────────────────────────────────────
echo "--- individuo il chunk della rasterizzazione su DEV ---"
CONT=$($SSH 'docker ps -qf name=frontend' 2>/dev/null | tr -d '\r' | head -1)
if [ -z "$CONT" ]; then echo "  nessun container frontend su DEV: non c'e' niente da mutare"; exit 1; fi
PERCORSO=$($SSH "docker exec $CONT sh -c \"grep -rl 'Condividi o Salva immagine' /usr/share/nginx/html/assets/ | head -1\"" 2>/dev/null | tr -d '\r')
if [ -z "$PERCORSO" ]; then
  echo "  FAIL il marker dell'export JPEG non e' in nessun chunk servito: il deploy non e' a posto"
  echo "  0 passati, 1 falliti (prerequisiti)"
  exit 1
fi
NOME=$(basename "$PERCORSO")
URL="$BASE/assets/$NOME"
echo "  chunk: $PERCORSO"

$SSH "mkdir -p /tmp/jpg-neg && docker cp $CONT:$PERCORSO /tmp/jpg-neg/$NOME" >/dev/null 2>&1
$SCP "$REMOTE:/tmp/jpg-neg/$NOME" "$LAVORO/$NOME" 2>/dev/null
if [ ! -s "$LAVORO/$NOME" ]; then echo "  non sono riuscito a prendere il chunk dal container"; exit 1; fi
ORIG_HASH=$(sha256sum "$LAVORO/$NOME" | cut -c1-16)
CONT_HASH=$($SSH "docker exec $CONT sha256sum $PERCORSO" 2>/dev/null | cut -c1-16 | tr -d '\r')
# Copia e originale devono essere la stessa cosa: se il docker cp ha preso un file diverso, stiamo
# per mutare qualcosa che il browser non guarda
if [ "$ORIG_HASH" != "$CONT_HASH" ]; then
  echo "  FAIL la copia locale non coincide col file nel container ($ORIG_HASH != $CONT_HASH)"
  exit 1
fi
echo "  originale: $NOME  sha256=$ORIG_HASH"

# Pre-flight: ogni ancora deve esistere una volta sola. Meglio dirlo qui, in due secondi, che dopo
# tre minuti di browser con un giro che "non produce rossi"
echo "--- le ancore delle mutazioni esistono nel chunk? ---"
for M in $(python3 "$PY" lista); do
  if ! python3 "$PY" applica "$LAVORO/$NOME" "$LAVORO/mut/preflight.js" "$M" >/dev/null 2>/tmp/opencode/neg-jpeg-ancora.err; then
    echo "  FAIL mutazione $M: $(cat /tmp/opencode/neg-jpeg-ancora.err)"
    echo "  0 passati, 1 falliti (prerequisiti)"
    exit 1
  fi
  echo "  ok   le ancore di $M sono presenti e univoche"
done

MUTAZIONI=("$@")
if [ "${#MUTAZIONI[@]}" = "0" ]; then
  mapfile -t MUTAZIONI < <(python3 "$PY" lista)
fi

PRISTINO=1
ripristina() {
  $SSH "docker cp /tmp/jpg-neg/$NOME $CONT:$PERCORSO" >/dev/null 2>&1
  sleep 1
  local H
  H=$(curl -s "$URL" | sha256sum | cut -c1-16)
  if [ "$H" != "$ORIG_HASH" ]; then
    echo "  !! ATTENZIONE: il chunk servito NON e' tornato pristine ($H != $ORIG_HASH)"
    PRISTINO=0
    return 1
  fi
  # Non basta l'hash: le ancore devono essere di nuovo nei byte che il browser riceve. Sono forme, non
  # nomi minificati (il minificatore li cambia a ogni build, e un'ancora morta sarebbe un ripristino
  # che dice "ok" senza aver verificato niente)
  for A in 'fillStyle="#ffffff"' 'background:"#ffffff"' 'standardFontDataUrl:"/pdfjs/standard_fonts/"' '16*1e3*1e3' 'getViewport({scale:1})'; do
    if ! curl -s "$URL" | grep -qF "$A"; then
      echo "  !! ATTENZIONE: ripristinato ma l'ancora $A non e' piu' nei byte serviti"
      PRISTINO=0
      return 1
    fi
  done
  return 0
}
trap 'if [ "${FINITO:-0}" != "1" ]; then echo "  !! ripristino attivato dalla trap"; ripristina; fi' EXIT

ROTTI=0
for M in "${MUTAZIONI[@]}"; do
  echo
  echo "════════════════════════════════════════════════════════════════════"
  echo "  MUTAZIONE: $M"
  echo "════════════════════════════════════════════════════════════════════"
  if ! python3 "$PY" applica "$LAVORO/$NOME" "$LAVORO/mut/$NOME" "$M"; then
    echo "  FAIL la mutazione non e' partita: questo giro NON ha testato niente"
    ROTTI=1
    continue
  fi
  if cmp -s "$LAVORO/$NOME" "$LAVORO/mut/$NOME"; then
    echo "  FAIL il file mutato e' identico all'originale: la mutazione non ha toccato niente"
    ROTTI=1
    continue
  fi
  $SCP "$LAVORO/mut/$NOME" "$REMOTE:/tmp/jpg-neg/mut-$NOME" >/dev/null 2>&1
  $SSH "docker cp /tmp/jpg-neg/mut-$NOME $CONT:$PERCORSO" >/dev/null 2>&1
  # La prova che il browser riceve il file mutato. Senza questa, un docker cp finito nel posto
  # sbagliato darebbe "nessun rosso" e il giro sembrerebbe onesto
  MARCATORE=$(python3 "$PY" marcatore "$M" "$LAVORO/$NOME" "$LAVORO/mut/$NOME" 2>/dev/null)
  if [ -z "$MARCATORE" ] || ! curl -s "$URL" | grep -qF "$MARCATORE"; then
    echo "  FAIL la mutazione non e' nei byte SERVITI (cerco '$MARCATORE' in $URL): il giro non ha testato niente"
    ROTTI=1
    ripristina
    continue
  fi
  echo "  mutazione servita: '$MARCATORE' presente nei byte del browser"

  echo "  lancio la verifica UI..."
  LOG="$LAVORO/$M.log"
  timeout 600 bash "$DIR/verifica_ui_export_jpeg.sh" >"$LOG" 2>&1
  RC_GIRO=$?
  grep -E '^  FAIL' "$LOG" >"$LAVORO/$M.rossi" 2>/dev/null
  grep -E '^  ok  ' "$LOG" >"$LAVORO/$M.verdi" 2>/dev/null
  N_ROSSI=$(wc -l <"$LAVORO/$M.rossi" | tr -d ' ')
  N_VERDI=$(wc -l <"$LAVORO/$M.verdi" | tr -d ' ')
  echo "  esito del giro: rc=$RC_GIRO, $N_VERDI verdi, $N_ROSSI rossi"
  if [ "$N_ROSSI" = "0" ] && [ "$N_VERDI" = "0" ]; then
    # Zero asserzioni eseguite: il wrapper non e' nemmeno arrivato al browser (Chrome appeso, login
    # caduto, ssh giu'). Non e' "il test non se n'e' accorta": e' un giro che non ha misurato niente
    echo "  FAIL nessuna asserzione eseguita in questo giro: non ha misurato niente"
    sed 's/^/      /' "$LOG" | tail -8
    ROTTI=1
    ripristina
    continue
  fi
  sed 's/^/      /' "$LAVORO/$M.rossi" | head -12

  if [ "$N_ROSSI" = "0" ]; then
    echo "  FAIL nessuna asserzione e' diventata rossa: la mutazione non ha cambiato output, non ha testato niente"
    ROTTI=1
  fi

  IFS='|' read -r -a ATTESI <<< "${ROSSI[$M]:-}"
  for A in "${ATTESI[@]}"; do
    if grep -qF "$A" "$LAVORO/$M.rossi"; then
      echo "  ok   diventa rossa: $A"
    else
      echo "  FAIL NON diventa rossa: $A"
      ROTTI=1
    fi
  done

  IFS='|' read -r -a KEEPGREEN <<< "${VERDI[$M]:-}"
  for A in "${KEEPGREEN[@]}"; do
    if grep -qF "$A" "$LAVORO/$M.rossi"; then
      echo "  FAIL diventa rossa anche questa (non discriminatoria): $A"
      ROTTI=1
    elif grep -qF "$A" "$LAVORO/$M.verdi"; then
      echo "  ok   resta verde ed era stata eseguita: $A"
    else
      echo "  FAIL asserzione MAI ESEGUITA (non e' ne' fra le rosse ne' fra le verdi): $A"
      ROTTI=1
    fi
  done

  ripristina || ROTTI=1
done

echo
echo "--- ripristino finale ---"
if ripristina; then
  echo "  ok   il chunk servito e' pristine ($ORIG_HASH), le ancore sono a posto"
else
  ROTTI=1
fi

FINITO=1
echo
if [ "$ROTTI" = "0" ]; then
  echo "  negative test: il test sa fallire su tutte le ${#MUTAZIONI[@]} mutazioni"
else
  echo "  negative test: $ROTTI problemi"
fi
exit $ROTTI
