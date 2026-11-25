#!/bin/bash
# NEGATIVE TEST del gate `get_gestore_gare_torneo` (le asserzioni sono la sezione 8 di
# test_tornei_scope.sh). Rompe una regola alla volta, come la farebbe un programmatore distratto fra sei
# mesi, e asserisce che il test se ne accorga SUL PUNTO GIUSTO.
#
# Perche' esiste. Quelle asserzioni dicono oggi "il permesso di scrivere sul calendario gare coincide con
# quello di leggere i tornei". Un 102/0 che non si e' mai visto rosso davanti a QUESTE mutazioni non e'
# una difesa: e' la stessa fiducia che ha retto finche' il 25/11/2026 qualcuno non ha guardato la docstring
# di quel gate, che giustificava un permesso piu' largo della lettura citando una decisione gia' annullata.
#
# I sei giri, e perche' proprio questi:
#   1. `gate-sempre-aperto`  -- il mister branch torna senza guardare le categorie: E' ESATTAMENTE il
#      comportamento che c'era prima del 25/11/2026. Se il test non diventa rosso qui, non ha mai visto
#      il difetto che deve impedire.
#   2. `gate-sempre-chiuso`  -- il rovescio: un gate che blocca tutti passa per "sicuro". Le asserzioni
#      sul mister che scrive sul PROPRIO torneo devono urlare, perche' e' il lavoro del sabato.
#   3. `colonna-legacy`      -- "tanto la categoria sta anche su tornei.categoria_id": costa meno, ed e'
#      per questo che qualcuno lo fara'. Sembra equivalente, e sui tornei di oggi lo e' quasi ovunque.
#   4. `salta-get-torneo`    -- il gate smette di chiamare `_get_torneo`: i verdetti escono nell'ordine
#      sbagliato e un torneo inesistente risponde "non e' una delle tue categorie".
#   5. `segreteria-dentro`   -- la fusione fra elenco di LETTURA e gate di SCRITTURA, l'errore che
#      ui_convocazioni_torneo.cjs esiste per beccare dall'altra parte.
#   6. `messaggi-uguali`     -- i due 403 diventano lo stesso testo. Sembra cosmesi, e le due asserzioni
#      sui messaggi erano decorate a scriverle: qui si vede se servono.
#
# Due controlli per giro, come in negative_tornei_scope.sh: un FAIL che contenga una stringa OBBLIGATORIA
# (il rosso deve essere QUELLO della regola, non un rosso generico) e un'asserzione che deve RESTARE VERDE
# (una mutazione che fa crollare tutto non e' perfetta, e' il test che e' caduto). Se una mutazione non
# produce nessun rosso, il giro e' FALLITO: una mutazione che non cambia output non ha testato niente.
#
# Gira contro DEV: la regola e' nel backend, e il container non ha `--reload` (4 worker), quindi ogni giro
# fa `docker cp` del file mutato + `docker restart`. Il ripristino sta nel TRAP perche' un Ctrl-C a meta'
# giro lascerebbe il backend di DEV con una regola di permessi rotta.
#
# Non e' nella suite: run_suite_dev.sh scopre solo test_*.sh, e questo stampa rossi di proposito.
# Si lancia a mano (~12 minuti):
#   bash scripts/test/negative_gestore_gare.sh
#   bash scripts/test/negative_gestore_gare.sh colonna-legacy      # uno solo
set -u
# 1) ESEGUIRE UNA COPIA DI SE STESSI. Bash legge lo script dal file in modo incrementale: modificarlo
#    mentre un giro sta girando non e' innocuo, e' gia' costato un "errore di sintassi vicino al token non
#    atteso" su una riga che `bash -n` dichiarava valida, e due esecuzioni che hanno congelato come
#    "pristino" un file gia' manomesso
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
#    "piu' lente", sono due verdetti senza valore
BLOCCO=/tmp/opencode/negative_gestore_gare.lock
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
T=scripts/test/test_tornei_scope.sh
FILEI=("$TORNEI")
BE=registro_presenze-backend-1
# `-n` NON e' una precauzione estetica: `ssh` senza eredita lo stdin dello script, e qui dentro quello
# stdin E' il testo del test che resta da eseguire. Il push dei file usa SSH_IN perche' li legge da stdin
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
# L'hash del solo tornei.py, WITHOUT il separatore che `PRISTINO` aggiunge in coda. E' quello con cui
# confrontare gli hash letti nel container: `PRISTINO` finisce con uno spazio, e un confronto con un hash
# secco sarebbe sempre "diverso" -- un guard che si rifiuta di partire, o che dichiara il push fallito
# quando e' riuscito, e' peggio di non averlo
PRISTINO_TORNEI=$(sha "$TORNEI")
# Il pristino del CONTAINER, confrontato prima di sporcare qualunque cosa: se il backend che sta
# rispondendo non esegue gia' questo file, i sei giri misurerebbero un codice che non e' quello in test.
# Si confronta `sha "$TORNEI"`, NON `$PRISTINO`: quel giratore di hash aggiunge uno spazio in coda a ogni
# file (serve quando i file sono due, per separarli), e confrontarlo con un hash secco darebbe "diversi"
# anche quando sono identici -- un guard che si rifiuta di partire per un motivo suo e' peggio di non averlo
IN_CONTAINER=$($SSH "docker exec $BE sha256sum /app/app/routers/tornei.py" 2>/dev/null | cut -c1-16)
if [ "$IN_CONTAINER" != "$PRISTINO_TORNEI" ]; then
  echo "  FAIL il container NON esegue il file locale ($IN_CONTAINER != $PRISTINO): i sei giri"
  echo "       misurerebbero un backend diverso da quello che sto mutando. Allinea DEV (deploy_dev.sh)"
  echo "  0 passati, 1 falliti (prerequisiti)"
  exit 1
fi

push_dev() {
  local f base
  for f in "${FILEI[@]}"; do
    base=$(basename "$f")
    base64 -w0 "$f" | $SSH_IN "base64 -d > /tmp/neg_$base && docker cp /tmp/neg_$base $BE:/app/app/routers/$base" \
      || { echo "  FAIL push di $f su DEV non riuscita"; return 1; }
  done
  $SSH "docker restart $BE >/dev/null" || { echo "  FAIL restart del backend su DEV"; return 1; }
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
  # SOLO dalle copie in $TMP: mai `git checkout`, che in questo progetto ha gia' cancellato lavoro non
  # committato dentro un ciclo di test
  for f in "${FILEI[@]}"; do cp "$TMP/$(basename "$f").pristino" "$f"; done
  push_dev || return 1
  adesso=$(for f in "${FILEI[@]}"; do printf '%s ' "$(sha "$f")"; done)
  if [ "$adesso" != "$PRISTINO" ]; then
    echo "  FAIL il ripristino non ha riportato i sorgenti pristini ($adesso != $PRISTINO)"
    return 1
  fi
  return 0
}
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

giro() { # giro <nome> <vecchio> <nuovo> <rosso-obbligatorio> <min-rossi> <verde-da-conservare>
  local nome="$1" vecchio="$2" nuovo="$3" rosso="$4" min="$5" verde="$6"
  echo
  echo "── $nome"
  if ! muta "$TORNEI" "$vecchio" "$nuovo"; then
    echo "  FAIL la mutazione non e' applicabile: il sorgente e' cambiato, questo negative test va"
    echo "       aggiornato (non ignorato: se non sa piu' rompere, non sa piu' nemmeno difendere)"
    fail=$((fail+1)); ripristina; return
  fi
  if diff -q "$TORNEI" "$TMP/tornei.py.pristino" >/dev/null; then
    echo "  FAIL MUTAZIONE NON PARTITA su $TORNEI: identica al pristino, il verdetto dopo non prova niente"
    fail=$((fail+1)); ripristina; return
  fi
  # La mutazione deve essere ANCHE nei byte serviti: "ho mutato un file che il backend non legge" darebbe
  # un giro verde senza valore (lezione gia' pagata sui chunk del frontend)
  if ! push_dev; then fail=$((fail+1)); ripristina; return; fi
  local adesso_c locale_c
  adesso_c=$($SSH "docker exec $BE sha256sum /app/app/routers/tornei.py" 2>/dev/null | cut -c1-16)
  locale_c=$(sha "$TORNEI")
  # Si confronta con l'hash del file MUTATO, non con "non e' il pristino": cosi' un push che ha portato
  # meta' file, o il pristino perche' il docker cp non e' partito, danno entrambi rosso. E' la stessa
  # ragione per cui sui chunk del frontend si misurano i byte serviti
  if [ "$adesso_c" != "$locale_c" ]; then
    echo "  FAIL il container NON esegue i byte mutati ($adesso_c != $locale_c): la mutazione non e'"
    echo "       arrivata al codice che risponde alle richieste, e il verdetto qui sotto non proverebbe niente"
    fail=$((fail+1)); ripristina; return
  fi

  local out rc n tentativi=0
  while :; do
    # `< /dev/null` e' la stessa lezione del `-n` sull'ssh: il test lancia a sua volta ssh verso DEV
    out=$(bash "$T" 2>&1 </dev/null); rc=$?
    # I 7 login possono incappare nel rate limiter: un test fermo ai prerequisiti NON e' un verdetto sulla
    # mutazione, e contarlo come tale darebbe un rosso dell'arness spacciato per un rosso del test
    if printf '%s\n' "$out" | grep -q 'prerequisiti' && [ "$tentativi" -lt 2 ]; then
      tentativi=$((tentativi+1)); echo "  (prerequisiti non soddisfatti -- login dal limiter: riprovo, tentativo $tentativi)"; sleep 20; continue
    fi
    break
  done
  n=$(printf '%s\n' "$out" | grep -c '^  FAIL')
  printf '%s\n' "$out" | grep '^  FAIL' | sed 's/^/       /' | head -6

  if ! printf '%s\n' "$out" | grep -qE '^[[:space:]]*[0-9]+ passati, [0-9]+ falliti'; then
    echo "  FAIL il test non arriva al riepilogo (rc $rc): e' morto, e un crash non e' una prova"
    fail=$((fail+1)); ripristina; return
  fi
  if [ "$rc" = "0" ] || [ "$n" = "0" ]; then
    echo "  FAIL il test non si e' accorto di \"$nome\": dice verde su un difetto che deve vedere"
    fail=$((fail+1))
  elif ! printf '%s\n' "$out" | grep '^  FAIL' | grep -q -- "$rosso"; then
    echo "  FAIL nessun rosso riguarda \"$rosso\": il test e' rosso per un altro motivo, quindi questa"
    echo "       mutazione non e' stata vista (e' il caso in cui dieci rossi non dicono niente)"
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

# ---- i frammenti, presi dal sorgente pristine --------------------------------------------------------
# 1. Il gate torna com'era prima del 25/11/2026: il ruolo basta, le categorie non vengono guardate
APERTO='        if iscritte_seguite:
            return current_user'
APERTO_ROT='        if True:  # MUTATO: come prima del 2026-11-25, basta il ruolo
            return current_user'
# 2. Il gate blocca anche chi le categorie le ha
CHIUSO='        if iscritte_seguite:
            return current_user'
# (doppie virgolette, non singole: il commento contiene un apostrofo, e in bash `'...puo'...'` si
# spezzerebbe in silenzio lasciando un frammento sbagliato che `muta` non troverebbe)
CHIUSO_ROT="        if False:  # MUTATO: nessun mister puo' scrivere
            return current_user"
# 3. "Tanto la categoria sta anche su tornei.categoria_id"
LEGACY='SELECT count(*) FROM tornei_categorie tc
                WHERE tc.torneo_id = :t
                  AND EXISTS (SELECT 1 FROM utente_categorie uc
                               WHERE uc.categoria_id = tc.categoria_id AND uc.utente_id = :u)'
LEGACY_ROT='SELECT count(*) FROM tornei t2
                WHERE t2.id = :t
                  AND EXISTS (SELECT 1 FROM utente_categorie uc
                               WHERE uc.categoria_id = t2.categoria_id AND uc.utente_id = :u)'
# 4. Il gate non verifica piu' che il torneo esista e sia del tenant prima di parlare di categorie
GETT='    _get_torneo(torneo_id, current_user, db)
    if _e_responsabile(current_user):'
GETT_ROT='    if _e_responsabile(current_user):'
# 5. L'elenco di LETTURA diventa anche un permesso di scrittura
RESP='    if _e_responsabile(current_user):
        return current_user
    if current_user.ruolo == "mister":'
RESP_ROT='    if _e_responsabile(current_user) or current_user.ruolo == "segreteria":  # MUTATO
        return current_user
    if current_user.ruolo == "mister":'
# 6. I due 403 diventano lo stesso testo
MSG="\"Non sei assegnato a nessuna categoria: il calendario gare di un torneo e' dei mister delle \"
                \"categorie iscritte. Chiedi al responsabile di assegnarti una categoria.\""
MSG_ROT="\"Il torneo non ha nessuna delle tue categorie iscritte: non puoi modificarne il calendario.\""

SCELTO="${1:-}"
[ -z "$SCELTO" ] || { SCELTO="giro_$SCELTO"; }

# ---- IL PRISTINO VA DIMOSTRATO, NON ASSUNTO (lezione di negative_tornei_scope.sh) -------------------
# Un hash uguale a un valore sbagliato non e' una prova: se il file era gia' mutato da un'esecuzione morta
# a meta', questo script lo congelerebbe come "pristino" e ogni `ripristina ... verificato per hash`
# riporterebbe li'. L'unica prova e' che il baseline contenga le ancore che i giri si aspettano
ANCORE=("$APERTO" "$LEGACY" "$GETT" "$RESP" "$MSG")
echo "--- il pristino viene dimostrato prima di qualsiasi giro ---"
n_ancore=0
for fr in "${ANCORE[@]}"; do
  n=$(python3 -c "import sys;print(open(sys.argv[1],encoding='utf-8').read().count(sys.argv[2]))" \
        "$TMP/tornei.py.pristino" "$fr" 2>/dev/null || echo "")
  n_ancore=$((n_ancore+1))
  if [ "$n" != "1" ]; then
    echo "  FAIL il 'pristino' di tornei.py NON ha l'ancora di un giro (occorrenze=${n:-nessuna}):"
    echo "       $(printf '%.72s' "$fr")"
    echo "       Il file era gia' mutato PRIMA che questo script partisse (esecuzione morta a meta', o"
    echo "       ripristino fallito). Fermarsi qui e' l'unica cosa onesta: continuare significherebbe"
    echo "       chiamare 'pristino' un backend con una regola di permessi rotta."
    echo "  0 passati, 1 falliti (prerequisiti)"
    exit 1
  fi
done
echo "  ok   $n_ancore ancore dei giri trovate una sola volta nel pristino"
echo "PRISTINO: $PRISTINO (identico a quello nel container, verificato sopra)"

# ---------------------------------------------------------------------------
[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_gate-sempre-aperto" ] && \
giro gate-sempre-aperto "$APERTO" "$APERTO_ROT" \
  "mister-a aggiunge una gara al torneo di mister-b -> 403" 6 \
  "mister-a aggiunge una gara al torneo della sua categoria -> 200"

[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_gate-sempre-chiuso" ] && \
giro gate-sempre-chiuso "$CHIUSO" "$CHIUSO_ROT" \
  "mister-a aggiunge una gara al torneo della sua categoria -> 200" 6 \
  "mister-a aggiunge una gara al torneo di mister-b -> 403"

[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_colonna-legacy" ] && \
giro colonna-legacy "$LEGACY" "$LEGACY_ROT" \
  "sull'orfano, anche se la colonna legacy dice" 3 \
  "mister-b aggiunge una gara al torneo della sua categoria -> 200"

[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_salta-get-torneo" ] && \
giro salta-get-torneo "$GETT" "$GETT_ROT" \
  "torneo inesistente come mister -> 404" 2 \
  "admin puo' scrivere su entrambi i tornei -> 200,200"

[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_segreteria-dentro" ] && \
giro segreteria-dentro "$RESP" "$RESP_ROT" \
  "RUOLI_VEDONO_TUTTI_I_TORNEI e' un elenco di LETTURA" 2 \
  "dirigente CON la categoria a -> 403 (legge i tornei della sua categoria, non li scrive)"

[ -z "$SCELTO" ] || [ "$SCELTO" = "giro_messaggi-uguali" ] && \
giro messaggi-uguali "$MSG" "$MSG_ROT" \
  "nomina LE CATEGORIE MANCANTI a lui" 2 \
  "mister-zero (nessuna categoria) -> 403"

echo
echo "verifica finale: il sorgente e' tornato pristine?"
ADESSO=$(for f in "${FILEI[@]}"; do printf '%s ' "$(sha "$f")"; done)
if [ "$ADESSO" = "$PRISTINO" ]; then
  echo "  ok   $TORNEI pristine ($ADESSO)"
else
  echo "  FAIL sorgente DIVERSO dal pristino ($ADESSO != $PRISTINO): riavviare a mano da deploy_dev.sh"
  fail=$((fail+1))
fi
echo "  (GET /tornei/ risponde $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$D/tornei/") senza token: 401 = il backend di DEV e' quello giusto)"

echo
echo "negative test: $pass passati, $fail falliti"
[ "$fail" -eq 0 ] || exit 1
