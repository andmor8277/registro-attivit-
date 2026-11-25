#!/bin/bash
# NEGATIVE TEST di test_tornei_scope.sh: rompe una regola alla volta, come la farebbe un programmatore
# distratto sei mesi da oggi, e asserisce che il test se ne accorga.
#
# Perche' esiste. Il test che accompagna dice 69/0, e un 69/0 che non si e' mai visto rosso davanti a
# QUESTE mutazioni non e' una difesa: e' la stessa fiducia che ha retto finche' qualcuno non ha guardato
# lo schermo. Qui sotto ci sono le sette cose che possono andare storte su questa regola -- le sei che
# si possono rompere in modo plausibile piu' quella che sembra innocua -- e per ognuna il test deve
# diventare rosso SUL PUNTO GIUSTO, non genericamente.
#
# Due controlli per giro, come in negative_registro.sh:
#   - un FAIL che contenga una stringa OBBLIGATORIA: "qualche asserzione e' rossa" non basta, il rosso
#     deve essere quello di quella regola (altrimenti il test e' rosso per un motivo suo e la mutazione
#     non e' stata vista);
#   - un'asserzione che deve RESTARE VERDE: senza questo, una mutazione che fa crollare tutto sembra
#     perfetta, mentre e' il test che e' caduto.
#
# Se una mutazione non produce nessun rosso, il giro e' FALLITO: una mutazione che non cambia output non
# ha testato niente (e' gia' successo in questo progetto con una mutazione mai partita).
#
# A differenza dei negative sui sorgenti, QUESTO gira contro DEV: la regola e' nel backend, quindi
# mutare il file sul disco senza portarlo nel container non porta niente davanti alla richiesta. Ogni
# giro fa `docker cp` del file mutato + `docker restart`, e il ripristino sta nel TRAP perche' un
# Ctrl-C a meta' di un giro lascerebbe il backend di DEV con una regola di permessi rotta.
#
# Non e' nella suite: run_suite_dev.sh scopre solo test_*.sh, e questo stampa rossi di proposito.
# Si lancia a mano (~8 minuti: ogni giro ripete le 69 asserzioni contro DEV):
#   bash scripts/test/negative_tornei_scope.sh              # tutti i giri
#   bash scripts/test/negative_tornei_scope.sh segreteria   # uno solo
set -u
# 1) ESEGUIRE UNA COPIA DI SE STESSI. Bash legge lo script dal file **in modo incrementale**, quindi
#    modificare questo file mentre un giro sta girando non e' affatto innocuo: il processo riprende a
#    leggere da un offset che nel frattempo e' sbagliato e interpreta spazzatura. Misurato il 25/11/2026:
#    una modifica a meta' esecuzione ha fatto morire lo script con "errore di sintassi vicino al token
#    non atteso" su riga 191, una riga che `bash -n` dichiarava valida. Da qui l'exec della copia, che
#    nessuno tocca mentre gira
if [ -z "${THOF_NEG_RUNNER:-}" ]; then
  D0="$(cd "$(dirname "$0")" && pwd)"
  THOF_NEG_RUNNER="$(mktemp -d)/$(basename "$0")"
  cp "$0" "$THOF_NEG_RUNNER" || { echo "  FAIL non riesco a copiare me stesso in un posto stabile"; exit 1; }
  export THOF_NEG_RUNNER THOF_NEG_DIR="$D0"
  exec bash "$THOF_NEG_RUNNER" "$@"
fi
DIR="$(cd "$THOF_NEG_DIR/../.." && pwd)"
cd "$DIR" || { echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }

# 2) UN SOLO GIRO ALLA VOLTA. Questo script TOCCA il backend di DEV: due esecuzioni sovrapposte non sono
#    "piu' lente", sono due verdetti senza valore. Misurato il 25/11/2026: una run rimasta viva ha
#    ripristinato il file pristine durante il giro di un'altra -- e quella ha detto "il test non si e'
#    accorto", che era il verdetto GIUSTO su un difetto che non c'era piu' -- e le ha scritto sopra la
#    propria mutazione, all'altro giro risultata "la mutazione non e' applicabile". E' la stessa regola
#    gia' scritta in AGENTS.md per la suite e per deploy_dev.sh, qui resa un blocco invece che un avviso
BLOCCO=/tmp/opencode/negative_tornei_scope.lock
if ! mkdir "$BLOCCO" 2>/dev/null; then
  ALTRO=$(cat "$BLOCCO/pid" 2>/dev/null || echo "")
  if [ -n "$ALTRO" ] && kill -0 "$ALTRO" 2>/dev/null; then
    echo "  0 passati, 1 falliti (prerequisiti)"
    echo "  FAIL un'altra esecuzione e' gia' in corso (PID $ALTRO): due negative test sullo stesso backend"
    echo "       si annullano a vicenda e nessuno dei due verdetti vale. Aspetta che finisca, o cancella"
    echo "       $BLOCCO solo se quel PID e' davvero morto."
    exit 1
  fi
  echo "  (raccolto il blocco di un'esecuzione morta, PID ${ALTRO:-nessuno})"
  rm -rf "$BLOCCO"
  mkdir "$BLOCCO" || { echo "  FAIL non riesco a creare il blocco $BLOCCO"; exit 1; }
fi
echo $$ > "$BLOCCO/pid"

TORNEI=backend/app/routers/tornei.py
CAT=backend/app/routers/categorie.py
T=scripts/test/test_tornei_scope.sh
FILEI=("$TORNEI" "$CAT")
BE=registro_presenze-backend-1
# `-n` NON e' una precauzione estetica: `ssh` senza eredita lo stdin dello script, e quando lo script
# viene eseguito da un pipe/quota qui dentro quello stdin E' il testo del script stesso che resta da
# eseguire. Il primo `docker restart` si e' quindi mangiato i sei giri successivi, che sono semplicemente
# spariti (exit 0, log fermo a nove righe). Il push dei file usa SSH_IN, senza -n, perche' li legge da stdin
SSH="ssh -n -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
SSH_IN="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
D=http://192.168.178.133:3000/api

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for f in "${FILEI[@]}"; do
  [ -f "$f" ] || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL manca $f"; exit 1; }
  cp "$f" "$TMP/$(basename "$f").pristino"
done
sha() { sha256sum "$1" | cut -c1-16; }
PRISTINO=$(for f in "${FILEI[@]}"; do printf '%s ' "$(sha "$f")"; done)

push_dev() { # porta i file correnti nel container e riavvia il backend
  local f
  for f in "${FILEI[@]}"; do
    base64 -w0 "$f" | $SSH_IN "base64 -d > /tmp/neg_$(basename "$f") && docker cp /tmp/neg_$(basename "$f") $BE:/app/app/routers/$(basename "$f")" \
      || { echo "  FAIL push di $f su DEV non riuscita"; return 1; }
  done
  $SSH "docker restart $BE >/dev/null" || { echo "  FAIL restart del backend su DEV"; return 1; }
  # Il container non ha --reload (4 worker), quindi il riavvio e' l'unico modo e va ATTESO: senza
  # questo, il primo curl del test prende un connection refused e il giro e' rosso per il riavvio
  local i
  for i in $(seq 1 40); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$D/tornei/")" = "401" ] && return 0
    sleep 2
  done
  echo "  FAIL il backend non e' tornato su (nessun 401 su GET /tornei/ in 80s)"
  return 1
}
ripristina() {
  local f adesso
  # SOLO dalle copie in $TMP: mai `git checkout`, che qui dentro ha gia' cancellato lavoro non
  # committato in un altro giro di test di questo progetto
  for f in "${FILEI[@]}"; do cp "$TMP/$(basename "$f").pristino" "$f"; done
  push_dev || return 1
  adesso=$(for f in "${FILEI[@]}"; do printf '%s ' "$(sha "$f")"; done)
  if [ "$adesso" != "$PRISTINO" ]; then
    echo "  FAIL il ripristino non ha riportato i sorgenti pristini ($adesso != $PRISTINO)"
    return 1
  fi
  return 0
}
# Il trap, non solo il fondo dei giri: questo script lascia un backend mutato su DEV se muore a meta'
trap 'ripristina >/dev/null 2>&1; rm -rf "$TMP" "$BLOCCO"' EXIT

pass=0; fail=0
muta() { # muta <file> <vecchio> <nuovo>  -- ESATTAMENTE una occorrenza, altrimenti si ferma
  python3 - "$1" "$2" "$3" <<'PY'
import sys
p, vecchio, nuovo = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
n = s.count(vecchio)
if n != 1:
    print(f'       MUTAZIONE NON VALIDA: {n} occorrenze del frammento in {p}, attesa 1')
    raise SystemExit(2)
open(p, 'w', encoding='utf-8').write(s.replace(vecchio, nuovo))
PY
}

giro() { # giro <nome> <file> <vecchio> <nuovo> <rosso-obbligatorio> <min-rossi> <verde-da-conservare>
  local nome="$1" file="$2" vecchio="$3" nuovo="$4" rosso="$5" min="$6" verde="$7"
  echo
  echo "── $nome"
  if ! muta "$file" "$vecchio" "$nuovo"; then
    echo "  FAIL la mutazione non e' applicabile: il sorgente e' cambiato, questo negative test va"
    echo "       aggiornato (non ignorato: se non sa piu' rompere, non sa piu' nemmeno difendere)"
    fail=$((fail+1)); ripristina; return
  fi
  if diff -q "$file" "$TMP/$(basename "$file").pristino" >/dev/null; then
    echo "  FAIL MUTAZIONE NON PARTITA su $file: identica al pristino, il verdetto dopo non prova niente"
    fail=$((fail+1)); ripristina; return
  fi
  if ! push_dev; then fail=$((fail+1)); ripristina; return; fi

  local out rc n tentativi=0
  while :; do
    # `< /dev/null` e' la stessa lezione del `-n` sull'ssh: il test lancia a sua volta ssh verso DEV,
    # e senza questa redirezione sarebbe il test a mangiarsi lo stdin di questo script
    out=$(bash "$T" 2>&1 </dev/null); rc=$?
    # I 7 login del test possono incappare nel rate limiter: se il test si ferma ai prerequisiti NON
    # e' un verdetto sulla mutazione, e contarlo come tale darebbe un rosso dell'arness spacciato per
    # un rosso del test. Si riprova, e se continua e' un problema suo
    if printf '%s\n' "$out" | grep -q 'sono il prerequisito di tutto il resto' && [ "$tentativi" -lt 2 ]; then
      tentativi=$((tentativi+1)); echo "  (login negati dal rate limiter, riprovo -- tentativo $tentativi)"; sleep 20; continue
    fi
    break
  done
  n=$(printf '%s\n' "$out" | grep -c '^  FAIL')
  printf '%s\n' "$out" | grep '^  FAIL' | sed 's/^/       /' | head -6

  # Il riepilogo del test e' a margine zero ("69 passati, 0 falliti"), non rientrato come i FAIL:
  # chiedere due spazi iniziali rendeva ogni giro "morto", e un guard che non si e' mai visto verde
  # davanti al test giusto non e' un guard -- e' un guasto dell'arness
  if ! printf '%s\n' "$out" | grep -qE '^[[:space:]]*[0-9]+ passati, [0-9]+ falliti'; then
    echo "  FAIL il test non arriva al riepilogo (rc $rc): e' morto, e un crash non e' una prova"
    fail=$((fail+1)); ripristina; return
  fi
  if [ "$rc" = "0" ] || [ "$n" = "0" ]; then
    echo "  FAIL il test non si e' accorto di \"$nome\": dice verde su un difetto che deve vedere"
    fail=$((fail+1))
  elif ! printf '%s\n' "$out" | grep '^  FAIL' | grep -q -- "$rosso"; then
    echo "  FAIL nessun rosso riguarda \"$rosso\": il test e' rosso per un altro motivo, quindi questa"
    echo "       mutazione non e' stata vista (e' il caso in cui 69 rossi non dicono niente)"
    fail=$((fail+1))
  elif [ "$n" -lt "$min" ]; then
    echo "  FAIL solo $n rossi, minimo atteso $min per \"$nome\""
    fail=$((fail+1))
  elif ! printf '%s\n' "$out" | grep -q "^  ok   $verde"; then
    echo "  FAIL \"$verde\" non e' rimasto verde: la mutazione avrebbe dovuto lasciare intatta quella"
    echo "       regola, e invece il test la perde -- significa che non distingue le due cose"
    fail=$((fail+1))
  else
    echo "  ok   $n rossi, il giusto su \"$rosso\", e \"$verde\" ancora verde"
    pass=$((pass+1))
  fi
  ripristina || { echo "  !! il ripristino e' fallito a meta' giro: fermarsi qui, continuare con un";
                  echo "  !! backend mutato falserebbe tutti i giri successivi"; exit 1; }
}

# ---- i frammenti, presi dai sorgenti pristini ---------------------------------------------------
ESCAL='    if scope_norm == "tutte_categorie" and vede_tutti:'
ESCAL_ROT='    if scope_norm == "tutte_categorie":'
SEGR='RUOLI_VEDONO_TUTTI_I_TORNEI = ("segreteria",)'
SEGR_ROT='RUOLI_VEDONO_TUTTI_I_TORNEI = ()'
NOCA='        passa_tutte = vede_tutti'
NOCA_TUTTI='        passa_tutte = True'
NOCA_VUOTO='        passa_tutte = False'
GUARDIA='    if scope_norm not in ("mie_categorie", "tutte_categorie"):'
GUARDIA_ROT='    if False:'
LEGACY='        query = query.filter(text(
            f"EXISTS (SELECT 1 FROM tornei_categorie tc WHERE tc.torneo_id = tornei.id AND ({rami}))"
        ).bindparams(**params))'
LEGACY_ROT='        rami_leg = " OR ".join(f"tornei.categoria_id = :mc{i}" for i in range(len(mie)))
        query = query.filter(text(f"({rami_leg})").bindparams(**params))'
MIE='    righe = db.query(UtenteCategoria.categoria_id).filter(
        UtenteCategoria.utente_id == current_user.id
    ).distinct().order_by(UtenteCategoria.categoria_id).all()'
MIE_ROT='    righe = db.query(UtenteCategoria.categoria_id).distinct().order_by(UtenteCategoria.categoria_id).all()'

SCELTO="${1:-}"
[ -z "$SCELTO" ] || { SCELTO="giro_$SCELTO"; }

# ---------------------------------------------------------------------------
# IL PRISTINO VA DIMOSTRATO, NON ASSUNTO.
# Il baseline viene catturato dai file COM'ESSIONO in questo momento: se uno di loro era gia' mutato da
# un'esecuzione morta a meta', questo script lo congela come "pristino" e ogni `ripristina ... verificato
# per hash` riporta li' dichiarando di aver riparato. E' successo il 25/11/2026: `RUOLI_VEDONO_TUTTI_I_TORNEI`
# era rimasto `()` su disco **e dentro il container** per due esecuzioni intere, il riepilogo finale diceva
# "pristini" perche' il confronto era contro il manomesso, e i conteggi dei giri erano tutti gonfiati dalle
# due asserzioni sulla segreteria che restavano rosse di base. Un hash uguale a un valore sbagliato non e'
# una prova: l'unica prova e' che il baseline contenga le ancore che i giri si aspettano.
# ---------------------------------------------------------------------------
ANCORE=("$TORNEI|$ESCAL" "$TORNEI|$SEGR" "$TORNEI|$NOCA" "$TORNEI|$GUARDIA" "$TORNEI|$LEGACY" "$CAT|$MIE")
echo "--- il pristino viene dimostrato prima di qualsiasi giro ---"
n_ancore=0
for coppia in "${ANCORE[@]}"; do
  f="${coppia%%|*}"; fr="${coppia#*|}"
  n=$(python3 -c "import sys;print(open(sys.argv[1],encoding='utf-8').read().count(sys.argv[2]))" \
        "$TMP/$(basename "$f").pristino" "$fr" 2>/dev/null || echo "")
  n_ancore=$((n_ancore+1))
  if [ "$n" != "1" ]; then
    echo "  FAIL il 'pristino' di $(basename "$f") NON ha l'ancora del giro (occorrenze=${n:-nessuna}):"
    echo "       $(printf '%.72s' "$fr")"
    echo "       Il file era gia' mutato PRIMA che questo script partisse (esecuzione morta a meta', o"
    echo "       ripristino fallito). Fermarsi qui e' l'unica cosa onesta: continuare significherebbe"
    echo "       chiamare 'pristino' un backend con una regola di permessi rotta."
    echo "  0 passati, 1 falliti (prerequisiti)"
    exit 1
  fi
done
echo "  ok   $n_ancore ancore dei giri trovate una sola volta nei pristini"

echo "PRISTINO: $PRISTINO"
echo "(ogni giro riporta i file pristini e verifica per hash; il ripristino sta anche nel trap)"

# 1. L'interruttore diventa un permesso. E' la mutazione piu' verosimile di tutte: qualcuno toglie
#    `and vede_tutti` "perche' tanto il checkbox lo vede solo l'admin", e da' a chiunque conosca l'URL
#    i calendari di tutte le altre squadre.
[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_escalation" ] && \
giro escalation "$TORNEI" "$ESCAL" "$ESCAL_ROT" \
  "scope=tutte_categorie" 2 "dirigente con la categoria a: filtrato come un mister (il filtro non e' solo per i mister)"

# 2. La segreteria esce dall'elenco: la richiesta del titolare del 25/11/2026 sparisce in silenzio e
#    la segreteria si ritrova con la pagina vuota (non ha nessuna categoria assegnata, misurato su PROD).
[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_segreteria" ] && \
giro segreteria "$TORNEI" "$SEGR" "$SEGR_ROT" \
  "SEGRETARIA senza categorie" 2 "admin senza categorie vede tutti e quattro i tornei"

# 3. "Nessuna categoria" diventa sempre-tutti: il filtro si disattiva da solo perche' un account senza
#    assegnazioni e' considerato "non filtrato". E' la scorciatoia che allarga la vista a chi non deve,
#    e colpisce il mister senza categorie -- NON mister-a, che le categorie le ha: per questo il rosso
#    obbligatorio qui sotto e' mister-zero, e non il "mister-a vede i suoi due" che verrebbe naturale.
[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_no-cat-sempre-tutti" ] && \
giro no-cat-sempre-tutti "$TORNEI" "$NOCA" "$NOCA_TUTTI" \
  "mister-zero -> zero tornei" 4 "il 400 nomina 'mie_categorie'"

# 4. Il rovescio della stessa medaglia: "nessuna categoria" diventa sempre-vuoto, e l'admin -- che non
#    ha assegnazioni, misurato -- resta fuori dai tornei che lui stesso crea.
[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_no-cat-sempre-vuoto" ] && \
giro no-cat-sempre-vuoto "$TORNEI" "$NOCA" "$NOCA_VUOTO" \
  "admin senza categorie vede tutti e quattro i tornei" 2 "mister-a vede i suoi due tornei"

# 5. La guardia sullo `scope` sconosciuto salta: un `scope=tutte` scritto male diventa
#    silenziosamente "filtrato", e il contrario sarebbe un'escalation silenziosa. Il 400 e' l'unica
#    cosa che rende visibile l'errore a chi l'ha scritto.
[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_guardia-400" ] && \
giro guardia-400 "$TORNEI" "$GUARDIA" "$GUARDIA_ROT" \
  "scope sconosciuto -> 400" 3 "mister-a vede i suoi due tornei"

# 6. "Tanto la categoria sta anche su tornei": il filtro passa dalla colonna legacy, che costa meno ed
#    e' gia' li'. Sembra equivalente, e per i tornei di oggi LO E' -- per questo nessun test funzionale
#    lo nota. L'orfano con la colonna popolata e zero iscrizioni e' l'unica cosa che lo distingue.
[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_colonna-legacy" ] && \
giro colonna-legacy "$TORNEI" "$LEGACY" "$LEGACY_ROT" \
  "l'orfano non lo vede nemmeno mister-b" 2 "mister-a vede i suoi due tornei"

# 7. /categorie/mie si "allinea" a GET /categorie/ e dimentica il filtro per utente: l'admin si
#    ritroverebbe tutte le categorie, quindi la whitelist delle sezioni della pagina diventerebbe
#    "tutte" e un torneo iscritto a piu' categorie ricomparirebbe dove non deve. Il verde da
#    conservare e' il 401 senza token: la mutazione allarga l'elenco, non toglie l'autenticazione, e
#    se quel 401 cadesse il test sarebbe rosso per un'altra ragione.
[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_mie-senza-utente" ] && \
giro mie-senza-utente "$CAT" "$MIE" "$MIE_ROT" \
  "admin senza categorie: nessuna in /mie" 2 "GET /categorie/mie senza token -> 401"

echo
echo "verifica finale: i sorgenti sono tornati pristini?"
ADESSO=$(for f in "${FILEI[@]}"; do printf '%s ' "$(sha "$f")"; done)
if [ "$ADESSO" = "$PRISTINO" ]; then
  echo "  ok   $TORNEI e $CAT pristini ($ADESSO)"
else
  echo "  FAIL sorgenti DIVERSI dal pristino ($ADESSO != $PRISTINO): riavviare a mano da deploy_dev.sh"
  fail=$((fail+1))
fi
echo "  (GET /tornei/ risponde $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$D/tornei/") senza token: 401 = il backend di DEV e' quello giusto)"

echo
echo "negative test: $pass passati, $fail falliti"
[ "$fail" -eq 0 ] || exit 1
