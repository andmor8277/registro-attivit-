#!/usr/bin/env bash
# negative_sezioni_tornei.sh — le asserzioni nuove di ui_convocazioni_torneo.cjs sanno fallire?
#
# Il 25/11/2026 il mister dei 2016 ha segnalato che dal menu a tendina vedeva "tutto il resto dei tornei".
# La toppa ha TRE pezzi, non uno, e questo file ha un giro per pezzo:
#   (1) il menu a tendina tolto a chi non vede tutte le categorie        -> giro `tendino-a-tutti`
#   (2) `filtroCategoria`, che azzera il filtro arrivato da /tornei/<id> -> giro `clamp-tolto`
#   (3) la whitelist applicata anche al ramo `extra` di costruisciSezioni-> giro `whitelist-null`
# piu' un quarto giro, `difesa-cliente-tolta`, che toglie (2) e (3) insieme.
#
# Perche' quattro giri e non due, e perche' il terzo quasi non c'entrava. La prima versione di questo file
# aveva (3) come giro da-vedere-rosso e ha detto **55 passati, 0 falliti**: verde. Non era l'arnese rotto,
# era una mia assunzione falsa. Con l'URL su /tornei/19 il ramo principale di costruisciSezioni ha gia' la
# sua guardia (`if (filtro && id !== filtro) return`), quindi la whitelist non e' l'unica difesa e toglierla
# non muove niente. La whitelist e' l'unica guardia solo quando il filtro NON c'e', e c'e' una terza porta
# per arrivarci: /tornei/:id accetta un id qualsiasi, e con un id non numerico `categoriaFiltro` resta ''
# (Number('senza-filtro') e' NaN). Da li' il ramo principale itera tutte le categorie operative -- che
# GET /categorie/all restituisce intere a chiunque abbia un login -- e senza `okSezione` il mister vede le
# sezioni degli altri. Il test ora apre anche quell'URL, e il giro (3) diventa rosso li'.
#   Un'asserzione che non si muove davanti al difetto che dovrebbe vedere non e' un'asserzione: o si trova
# lo scenario dove si muove, o si toglie. Questa l'ha trovato il negative, non la sua scrittura.
#
# Perche' si muta il chunk e non il sorgente: Tornei.vue e' un SFC compilato, il browser esegue
# `assets/Tornei-<hash>.js`. Cambiare il .vue senza rebuild non porta niente davanti al browser -- falso
# verde gia' pagato sul caso `whitelist` della lavagna. Il nome dello chunk va SCOPERTO a ogni uso (porta
# l'hash dei contenuti) e mai copiato da un ambiente all'altro.
#
# Tre difetti di una versione precedente di QUESTO file, perche' sono il tipo di cosa che si ripresenta:
#  (1) REPO va calcolato PRIMA dell'exec sulla copia di se stesso e riletto con `:=`: dopo, BASH_SOURCE e'
#      il mktemp in /tmp e REPO diventa `/`, il wrapper non esiste, bash risponde 127 e il giro dice
#      "nessun riepilogo" per colpa dell'arnese. Un rc=127 non e' mai un verdetto sul test.
#  (2) Il separatore dei campi NON puo' essere `|` quando una sostituzione contiene `||!0`: i campi si
#      spostano, la mutazione diventa JS sgrammaticato e il giro "vede rosso" per la ragione sbagliata.
#      Le sostituzioni stanno quindi in array paralleli, senza parsing.
#  (3) `ck`/`ckVero` di ui_convocazioni_torneo.cjs stampano `ok` seguito da TRE spazi e `FAIL` da uno. Il
#      check dei verdi cercava `"ok $a"` con uno spazio: non matchava MAI, quindi ogni giro accusava le
#      asserzioni da-conservare-verdi di non essere mai state eseguite, mentre i rossi (un solo spazio)
#      matchavano. Da qui `tr -s ' '` su log e ago. **Uno zero che arriva dal modo in cui cerchi non e'
#      un'assenza** (gia' scritto in AGENTS.md per i marker della lavagna).
set -u

DEV="root@192.168.178.133"
KEY="$HOME/.ssh/id_ed25519_dev"
BASE="http://192.168.178.133:3000"
# `:=` e non `=`: dopo l'exec sulla copia di se stesso BASH_SOURCE e' il mktemp in /tmp, e ricalcolare qui
# darebbe `/` -- il difetto (1). Il valore giusto arriva dall'invocazione originale, esportato sotto.
: "${REPO:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export REPO
LOGDIR="/tmp/opencode/neg_sezioni"
PIDFILE="/tmp/opencode/negative_sezioni_tornei.pid"

# ------------------------------------------------------------------- una copia di se stesso
# bash legge lo script dal file in modo incrementale: modificarlo mentre un giro gira lo fa morire su una
# riga che `bash -n` dichiarava valida, e l'esecuzione interrotta non ripristina (lezione di
# negative_tornei_scope.sh, pagata due volte)
if [ -z "${NEG_SEZIONI_COPIA:-}" ]; then
  TMP="$(mktemp /tmp/opencode/neg_sezioni_esec_XXXXXX.sh)"
  cp "${BASH_SOURCE[0]}" "$TMP"; chmod +x "$TMP"
  NEG_SEZIONI_COPIA=1 exec bash "$TMP" "$@"
fi
[ -f "$REPO/scripts/test/verifica_ui_convocazioni_torneo.sh" ] || { echo "  FAIL wrapper non trovato in $REPO"; exit 1; }

# ------------------------------------------------------------------- mutua esclusione
if [ -f "$PIDFILE" ]; then
  OLD="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
    echo "Un altro giro e' gia' in corso (pid $OLD). Due esecuzioni sovrapposte sono due verdetti senza"
    echo "valore, e una delle due puo' ripristinare il chunk durante l'altra."
    exit 1
  fi
  rm -f "$PIDFILE"
fi
echo $$ > "$PIDFILE"

# Non basta `pgrep -f "negative_"`: la riga di comando che HA lanciato questo script contiene il suo nome,
# quindi il guardiano bloccava se stesso (gemello del `pkill -f` gia' registrato). Si esclude la famiglia di
# processi di QUESTO negative, non tutto cio' che ha una parola nel cmdline.
ALTRI=""
for p in $(pgrep -f "run_suite_dev|verifica_ui_|negative_" 2>/dev/null); do
  [ "$p" = "$$" ] && continue
  cmd="$(ps -o args= -p "$p" 2>/dev/null || true)"
  case "$cmd" in *negative_sezioni_tornei*|*neg_sezioni_esec*) continue ;; esac
  ALTRI="$ALTRI $p"
done
if [ -n "$ALTRI" ]; then
  echo "Attenzione: un altro test sta girando su DEV:$ALTRI. Questo negative pesta il chunk servito."
  for p in $ALTRI; do ps -o pid=,args= -p "$p" 2>/dev/null | cut -c1-140 | sed 's/^/  /'; done
  exit 1
fi

dev()    { ssh -n -o ConnectTimeout=15 -i "$KEY" "$DEV" "$@"; }
# Senza -n qui: serve lo stdin per caricare il file. `docker cp` vuole un file regolare (non /dev/stdin) e
# `ssh -n` chiude lo stdin: le due cose insieme non funzionano.
dev_in() { ssh -o ConnectTimeout=15 -i "$KEY" "$DEV" "$@"; }
carica_chunk() {
  dev_in "cat > /tmp/chunk_mutato.js" < "$1"
  dev "f=\$(docker ps -qf name=frontend); docker cp /tmp/chunk_mutato.js \$f:/usr/share/nginx/html/assets/$CHUNK"
}

CHUNK="$(dev 'f=$(docker ps -qf name=frontend); docker exec $f sh -c "ls /usr/share/nginx/html/assets/ | grep ^Tornei- | grep \.js\$"' | tr -d '\r\n')"
if ! printf '%s' "$CHUNK" | grep -qE '^Tornei-[A-Za-z0-9_-]+\.js$'; then
  echo "  FAIL non trovo lo chunk dei tornei nel container (scoperto: '$CHUNK')"; exit 1
fi
echo "chunk servito: $CHUNK   (nome scoperto ora, mai copiato da un altro ambiente)"

mkdir -p "$LOGDIR"
PREISTINO="$LOGDIR/pristino-$CHUNK"
# Il backup si fa SEMPRE da zero: `[ -f bk ] || cp` riusa un pristino stantio e ogni ripristino riporta
# quello dicendo "verificato per hash"
dev "f=\$(docker ps -qf name=frontend); docker exec \$f cat /usr/share/nginx/html/assets/$CHUNK" > "$PREISTINO"
PRISTINO_SHA="$(sha256sum "$PREISTINO" | cut -d' ' -f1)"
[ -s "$PREISTINO" ] || { echo "  FAIL chunk pristino vuoto"; exit 1; }
echo "pristino: $PRISTINO_SHA  ($(wc -c < "$PREISTINO") byte)"

# Se questo script viene ucciso a meta' -- SIGTERM, terminale chiuso, il timeout di chi lo lancia -- la
# mutazione RESTA nel container. E' successo davvero il 25/11/2026: interrotto a 60 secondi, i byte serviti
# erano 51670 contro i 51666 del pristino. Il trap ripristina, in silenzio per non sporcare il verdetto.
MUTATO_IN_CORSO=0
ripristina_in_uscita() {
  if [ "$MUTATO_IN_CORSO" = "1" ]; then
    echo "  (interruzione rilevata: riporto il pristino nel container)" >&2
    carica_chunk "$PREISTINO" >/dev/null 2>&1
  fi
  rm -f "$PIDFILE"
}
trap 'ripristina_in_uscita' EXIT INT TERM

# ------------------------------------------------------------------- i giri, in array paralleli
US=$'\x1f'   # separatore fra le coppie della stessa mutazione (le sostituzioni contengono `|`, `?`, `&&`)
NOMI=( "tendino-a-tutti" "clamp-tolto" "whitelist-null" "difesa-cliente-tolta" )
# NIENTE backtick dentro le doppie virgolette: `filtroCategoria` qui dentro e' una SOSTITUZIONE DI COMANDO,
# bash ha eseguito "filtroCategoria" (=> "comando non trovato") e la riga stampata perdeva il pezzo.
MOTIVI=(
  "il menu a tendina offerto anche a chi non vede tutte le categorie (la segnalazione del mister dei 2016)"
  "il filtro dall'URL applicato anche quando non e' una categoria di chi guarda (filtroCategoria deve azzerarlo)"
  "la whitelist delle sezioni mai applicata (il comportamento dell'amministratore dato a tutti)"
  "tolte INSIEME la guardia sull'URL e la whitelist: e' lo stato in cui le sezioni non sono protette da nulla"
)
ANCORE=(
  "i.ruolo)===\"segreteria\""
  "const e=G.value;return e&&e.includes(String(o))?o:null"
  '_=i&&i.length?i.map(String):null'
  "const e=G.value;return e&&e.includes(String(o))?o:null${US}_=i&&i.length?i.map(String):null"
)
SOSTS=(
  "i.ruolo)===\"segreteria\"||!0"
  'const e=G.value;return o'
  '_=null'
  "const e=G.value;return o${US}_=null"
)
# etichette separate da a-capo (i testi sono lunghi e non contengono mai un a-capo)
ROSSI[0]=$'il mister NON ha il menu a tendina delle categorie\nil mister NON ha l\'interruttore "tutte le categorie della società"\nnemmeno da li\' ha il menu a tendina delle categorie'
VERDI[0]=$'il mister arriva col titolo "Convocazioni Tornei"\nnessuna sezione di categorie che non segue'
ROSSI[1]=$'e al server non chiede una categoria che non segue'
VERDI[1]=$'il mister NON ha il menu a tendina delle categorie\ne non gli compare nessuna sezione di categorie che non segue'
ROSSI[2]=$'e la whitelist delle sezioni lo tiene dentro le sue categorie\ncon tutte le sue sezioni e nessuna in piu\'\ne non gli compare nessuna sezione di categorie che non segue'
VERDI[2]=$'il mister NON ha il menu a tendina delle categorie\ne al server non chiede una categoria che non segue'
# `le sue sezioni restano tutte e sole` sta fra le VERDI di questo giro, di proposito: con entrambe le difese
# tolte, su /tornei/26 le sezioni diventano UNA (quella sbagliata, 2015 - Esordienti) e il CONTEGGIO torna
# quindi giusto. E' la prova scritta che il conteggio non e' l'asserzione che lavora -- quella che lavora e'
# il confronto delle ETICHETTE con le sue categorie. Togliendo quelle, questo giro resterebbe verde su un
# difetto reale
ROSSI[3]=$'e non gli compare nessuna sezione di categorie che non segue\ne la whitelist delle sezioni lo tiene dentro le sue categorie\ncon tutte le sue sezioni e nessuna in piu\''
VERDI[3]=$'il mister NON ha il menu a tendina delle categorie\nil mister arriva col titolo "Convocazioni Tornei"\nle sue sezioni restano tutte e sole'

# ------------------------------------------------------------------- le verifiche sul log
# In UNA funzione, perche' deve essere QUEL codice a essere eseguito dall'autoprovatura e dal --log, non una
# copia dei suoi grep (lezione di negative_lavagna.sh). "Non e' fra le rosse" non e' un verde: e' un'assenza.
# `tr -s ' '` perche' `ck` stampa `ok` + TRE spazi e `FAIL` + uno: senza normalizzare, il check dei verdi non
# matcha mai e accusa di "mai eseguita" un'asserzione perfettamente verde (difetto (3) in testa al file).
controlla_log() {
  local caso="$1" log="$2" rossi="$3" verdi="$4" rc="${5:-0}" problema=0 a norm
  if [ ! -s "$log" ]; then echo "    FAIL '$caso': log vuoto"; return 1; fi
  if [ "$rc" = "127" ] || [ "$rc" = "126" ]; then
    echo "    FAIL '$caso': rc=$rc, il wrapper NON e' partito. Non e' un verdetto sul test, e' l'arnese rotto."
    return 1
  fi
  norm="$(sed 's/^[[:space:]]*//' "$log" | tr -s ' ')"
  printf '%s\n' "$norm" | grep -qE "^[0-9]+ passati, [0-9]+ falliti" || {
    echo "    FAIL '$caso': nessun riepilogo nel log (test rotto), rc=$rc"; problema=1; }
  # La console DEVE essere vuota perche' il giro sia credibile, non per estetismo: nel giro
  # `difesa-cliente-tolta` del 25/11/2026 sono comparsi 14 `Failed to load resource:
  # net::ERR_ADDRESS_UNREACHABLE`. Se DEV diventa irraggiungibile a meta' giro, le asserzioni "non c'e'"
  # restano verdi perche' non c'era niente da vedere -- che e' il falso verde, non un dettaglio di rumore.
  # (Il perche' prima non si vedeva QUALE risorsa: il collettore CDP teneva solo entry.text, ora anche url)
  local riga_console err_console
  riga_console="$(printf '%s\n' "$norm" | grep -E "^[0-9]+ passati, [0-9]+ falliti, [0-9]+ errori in console" | tail -1)"
  err_console="$(printf '%s' "$riga_console" | sed -n 's/.*, \([0-9]*\) errori in console.*/\1/p')"
  if [ -n "$err_console" ] && [ "$err_console" != "0" ]; then
    echo "    FAIL '$caso': $err_console errori in console -- il giro NON e' credibile (risorse non caricate"
    echo "         = asserzioni 'non c'e'' verdi per assenza). Le righe della console sono nel log $log"
    problema=1
  fi
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    printf '%s\n' "$norm" | grep -qF "FAIL $a" || {
      echo "    FAIL '$caso': '$a' NON e' diventata rossa -- l'asserzione non ha testato niente"; problema=1; }
  done <<< "$rossi"
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    printf '%s\n' "$norm" | grep -qF "ok $a" || {
      echo "    FAIL '$caso': '$a' non compare come riga ok -- o e' rossa, o non e' mai stata eseguita"; problema=1; }
  done <<< "$verdi"
  return $problema
}

if [ "${1:-}" = "--log" ]; then
  shift; CASO="$1"; LOG="$2"; RC="${3:-0}"
  for i in "${!NOMI[@]}"; do
    [ "${NOMI[$i]}" = "$CASO" ] && { controlla_log "$CASO" "$LOG" "${ROSSI[$i]}" "${VERDI[$i]}" "$RC"; exit $?; }
  done
  echo "caso '$CASO' sconosciuto"; exit 2
fi

# ------------------------------------------------------------------- il pristino va DIMOSTRATO, prima dei giri
echo; echo "=== pristino: ogni àncora deve comparire UNA sola volta e la sostituzione non deve esserci ==="
PREREQ=0
for i in "${!NOMI[@]}"; do
  IFS="$US" read -r -a AN <<< "${ANCORE[$i]}"
  IFS="$US" read -r -a SO <<< "${SOSTS[$i]}"
  if [ "${#AN[@]}" != "${#SO[@]}" ]; then
    echo "  FAIL ${NOMI[$i]}: ${#AN[@]} ancore contro ${#SO[@]} sostituzioni"; PREREQ=1; continue
  fi
  k=0; ok=1
  while [ "$k" -lt "${#AN[@]}" ]; do
    n="$(grep -oF "${AN[$k]}" "$PREISTINO" | wc -l)"
    if [ "$n" != "1" ]; then
      echo "  FAIL ${NOMI[$i]}: àncora trovata $n volte (volevo 1): ${AN[$k]}"
      echo "         Il chunk e' cambiato: aggiornare l'àncora, non il verdetto."; ok=0
    elif grep -qF "${SO[$k]}" "$PREISTINO"; then
      echo "  FAIL ${NOMI[$i]}: la sostituzione e' GIA' nel pristino: la mutazione non cambierebbe niente"; ok=0
    fi
    k=$((k + 1))
  done
  if [ "$ok" = "1" ]; then
    echo "  ok   ${NOMI[$i]}: ${#AN[@]} àncora/e uniche, sostituzioni assenti"
  else
    PREREQ=1
  fi
done
if [ "$PREREQ" = "1" ]; then echo; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; fi

# ------------------------------------------------------------------- i giri
TOT_FAIL=0
ripristina() {
  carica_chunk "$PREISTINO"
  if curl -s "$BASE/assets/$CHUNK" | cmp -s - "$PREISTINO"; then
    MUTATO_IN_CORSO=0
    echo "  ripristino verificato: i byte serviti sono byte-identici al pristino"
    return 0
  fi
  echo "  FAIL ripristino: i byte serviti NON coincidono con il pristino ($PRISTINO_SHA)"
  return 1
}

for i in "${!NOMI[@]}"; do
  nome="${NOMI[$i]}"; motivo="${MOTIVI[$i]}"
  IFS="$US" read -r -a AN <<< "${ANCORE[$i]}"
  IFS="$US" read -r -a SO <<< "${SOSTS[$i]}"
  echo; echo "=== giro: $nome ==="
  echo "    difetto rimesso: $motivo"
  MUTO="$LOGDIR/$nome-$CHUNK"
  # Le coppie vanno passate INTERLACCIATE (da1 a1 da2 a2), non "tutte le àncore e poi tutte le sostituzioni":
  # con i giri ad àncora singola le due cose coincidevano e il bug non si vedeva, mentre al quarto giro python
  # riceveva (àncora1, àncora2) come prima coppia e moriva con "ancora trovata 0 volte".
  COPPIE=()
  k=0
  while [ "$k" -lt "${#AN[@]}" ]; do COPPIE+=("${AN[$k]}" "${SO[$k]}"); k=$((k + 1)); done
  python3 - "$PREISTINO" "$MUTO" "${COPPIE[@]}" <<'PY'
import sys
a = sys.argv[1:]
src, dst = a[0], a[1]
coppie = a[2:]
assert len(coppie) % 2 == 0, "ancore e sostituzioni non in numero pari"
t = open(src, encoding='utf-8').read()
for k in range(0, len(coppie), 2):
    da, a_sost = coppie[k], coppie[k + 1]
    n = t.count(da)
    assert n == 1, f"ancora trovata {n} volte: {da}"
    t = t.replace(da, a_sost)
open(dst, 'w', encoding='utf-8').write(t)
PY
  [ -s "$MUTO" ] || { echo "  FAIL la mutazione non e' partita"; TOT_FAIL=1; ripristina || TOT_FAIL=1; continue; }
  if cmp -s "$MUTO" "$PREISTINO"; then
    echo "  FAIL la mutazione non cambia i byte del file: non ha testato niente"; TOT_FAIL=1; continue
  fi

  carica_chunk "$MUTO"; MUTATO_IN_CORSO=1
  # la mutazione va verificata nei byte SERVITI: "ho mutato un file che il browser non legge" darebbe un
  # giro verde senza valore
  SERVITO="$(curl -s "$BASE/assets/$CHUNK")"
  k=0; mancante=""
  while [ "$k" -lt "${#SO[@]}" ]; do
    printf '%s' "$SERVITO" | grep -qF "${SO[$k]}" || mancante="$mancante ${SO[$k]}"
    k=$((k + 1))
  done
  if [ -n "$mancante" ]; then
    echo "  FAIL queste sostituzioni non sono nei byte serviti:$mancante"
    TOT_FAIL=1; ripristina || TOT_FAIL=1; continue
  fi
  echo "  tutte le sostituzioni presenti nei byte serviti: verificata"

  bash "$REPO/scripts/test/verifica_ui_convocazioni_torneo.sh" > "$LOGDIR/$nome.log" 2>&1
  RC=$?
  grep -E "[0-9]+ passati, [0-9]+ falliti" "$LOGDIR/$nome.log" | sed 's/^/    /'
  controlla_log "$nome" "$LOGDIR/$nome.log" "${ROSSI[$i]}" "${VERDI[$i]}" "$RC" || TOT_FAIL=1

  ripristina || TOT_FAIL=1
done

echo
if [ "$TOT_FAIL" = "0" ]; then
  echo "VERDETTO: ${#NOMI[@]} giri: rosso dove doveva diventare rosso, verde (ed eseguito) dove doveva restare verde."
  echo "  0 passati, 0 falliti"; exit 0
else
  echo "VERDETTO: almeno un giro non ha misurato quello che dichiarava di misurare."
  echo "  0 passati, 1 falliti"; exit 1
fi
