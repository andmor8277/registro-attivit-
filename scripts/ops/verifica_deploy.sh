#!/bin/bash
# Verifica POST-DEPLOY su PROD. Da eseguire DOPO ogni ./deploy.sh, sempre, senza che nessuno lo chieda.
#
#   scripts/ops/verifica_deploy.sh                  # orologio derivato dal commit HEAD (lo dice)
#   scripts/ops/verifica_deploy.sh "2026-11-23 09:00:00 UTC"   # l'ora vera del deploy
#
# Perche' esiste. Su PROD i file a disco e il codice in esecuzione sono DUE COSE DIVERSE: il codice che
# risponde sta nell'IMMAGINE Docker costruita al deploy, `git log` dice cosa c'e' su disco. Un
# `docker compose up -d` senza `build` rialza i container dall'immagine VECCHIA: uptime freschissimo,
# RestartCount=0, log puliti, sito che risponde 200. Tutto sano, deploy non avvenuto. E' il "plausibile
# e falso" contro cui questo progetto si difende, e nessun controllo singolo qui sotto lo vede da solo:
# per questo si misurano TUTTE le cose e si riportano i numeri, non si dice "ok".
#
# L'orologio del deploy va passato a mano perche' il deploy e' un evento nel tempo e lo script puo'
# girare minuti o ore dopo. Senza un riferimento confrontabile, "Up 29 minutes" non prova niente.
#
# E' un file solo e si copia da solo su PROD e si esegue li': i comandi passati dentro ssh con l'escaping
# annidato hanno gia' rotto quattro operazioni in questo progetto.
set -u
DIR=/opt/registro_presenze
BE=registro_presenze-backend-1
FE=registro_presenze-frontend-1
DB=registro_presenze-db-1
COMPOSE="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
RUNTIME_RE='^(backend|frontend)/|docker-compose.*\.yml$|Dockerfile|requirements'

# ------------------------------------------------------------------ lato server
if [ "${LATO_SERVER:-}" = "1" ]; then
  cd "$DIR" || { echo "  manco da $DIR"; exit 9; }
  pass=0; fail=0; avviso=0; saltati=0
  ck()      { if [ -n "$2" ] && [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi; }
  ckmin()   { if [ -n "$2" ] && [ "$2" -ge "$3" ]; then pass=$((pass+1)); echo "  ok   $1 (>= $3, ora $2)"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2', sotto $3"; fi; }
  nota()    { avviso=$((avviso+1)); echo "  nota $1"; }
  # Docker restituisce nanosecondi (…T09:00:03.128370359Z) e `date -d` non li mastica sempre: si troncano.
  ep()      { local v; v=$(printf '%s' "${1:-}" | sed -E 's/\.[0-9]+(Z|[+-][0-9:]+)$/\1/'); [ -z "$v" ] && return 1
              date -u -d "$v" +%s 2>/dev/null; }
  iso()     { date -u -d "@$1" +%Y-%m-%dT%H:%M:%S 2>/dev/null; }

  HEAD=$(git rev-parse --short HEAD 2>/dev/null)
  PORC=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  # --- orologio di riferimento: quello vero passato a mano, altrimenti quello del commit HEAD ---
  DERIVATO=0
  RIF="${1:-}"
  if [ -z "$RIF" ]; then
    RIF=$(git log -1 --format=%cI HEAD 2>/dev/null); DERIVATO=1
    echo "  nota: nessun orologio del deploy passato, uso la data del commit HEAD ($RIF)."
    echo "        E' un'approssimazione: se il deploy e' avvenuto PRIMA di questo commit, i controlli"
    echo "        sui timestamp vanno fatti passare l'ora vera come primo argomento."
  fi
  RIF_E=$(ep "$RIF")
  [ -z "$RIF_E" ] && { echo "  orologio non interpretabile: '$RIF'"; exit 2; }
  echo "  riferimento: $(iso "$RIF_E") UTC  HEAD su disco: $HEAD"

  echo "--- 1. cosa c'e' su disco (NON prova cosa gira) ---"
  ck "working tree pulito (un reset --hard con modifiche locali le distrugge)" "$PORC" "0"
  git fetch -q origin "+refs/heads/*:refs/remotes/origin/*" 2>/dev/null
  DIETRO=$(git rev-list --count HEAD..origin/master 2>/dev/null)
  if [ "$DIETRO" = "0" ]; then pass=$((pass+1)); echo "  ok   clone allineato a origin/master"
  else nota "clone indietro di $DIETRO commit rispetto a origin/master"; fi

  echo "--- 2. L'IMMAGINE E' STATA DAVVERO RICOSTRUITA (il controllo che distingue un deploy da un up -d) ---"
  for c in "$BE" "$FE"; do
    IMGID=$(docker inspect -f '{{.Image}}' "$c" 2>/dev/null)
    IMGC=$(docker image inspect --format '{{.Created}}' "$IMGID" 2>/dev/null)
    IMGE=$(ep "$IMGC")
    if [ -z "$IMGE" ]; then fail=$((fail+1)); echo "  FAIL $c: non leggo la data di build dell'immagine"
    elif [ "$IMGE" -ge "$RIF_E" ]; then pass=$((pass+1)); echo "  ok   $c: immagine costruita $(iso "$IMGE") UTC, dopo il riferimento"
    else
      # Non e' automaticamente un guasto: se fra il commit dell'immagine e HEAD non c'e' nessun file
      # runtime, l'immagine vecchia E' quella giusta e nessun build serviva (deploy di soli scripts/).
      # Dirlo "deployato" in quel caso sarebbe il falso che questo script esiste per impedire, quindi
      # la distinzione va fatta e stampata, non saltata.
      IMGCMT=$(git log -1 --before="$IMGC" --format=%h HEAD 2>/dev/null)
      NRT=$(git diff --name-only "${IMGCMT:-HEAD}"..HEAD 2>/dev/null | grep -cE "$RUNTIME_RE")
      if [ "${NRT:-0}" -eq 0 ]; then
        pass=$((pass+1))
        echo "  ok   $c: immagine di $(iso "$IMGE") UTC (codice $IMGCMT) e su disco c'e' $HEAD,"
        echo "       ma fra i due NON c'e' nessun file runtime: nessun build era necessario"
      else
        fail=$((fail+1))
        echo "  FAIL $c: l'immagine gira da $IMGCMT ($(iso "$IMGE") UTC) ma su disco c'e' $HEAD,"
        echo "       e fra i due $NRT file runtime sono cambiati -> il codice in esecuzione NON e'"
        echo "       quello su disco. Serve: $COMPOSE build --no-cache && $COMPOSE up -d"
      fi
    fi
  done

  echo "--- 3. i container sono ripartiti DOPO il deploy, e nessuno e' morto ---"
  # Due invarianti diverse, e non si possono confondere:
  #  - con l'orologio del deploy passato a mano: i container devono essere partiti DOPO quel momento.
  #    E' questo che accorge un `up -d` che non ha rialzato niente, o un deploy mai partito.
  #  - senza orologio (derivato dalla data del commit): quel confronto NON ha senso. La data di un commit
  #    non e' il momento del deploy: misurato il 23/11/2026, container alle 09:00 e commit alle 09:25, e
  #    la versione precedente di questo script dava 3 rossi su un PROD perfettamente sano. Resta
  #    un'altra invariante, vera e indipendente dall'orologio: un container non puo' essere partito prima
  #    dell'immagine che sta eseguendo. Si asserisce quella, e si dice che il verdetto sul "dopo il
  #    deploy" NON c'e', invece di fingere di averlo dato.
  for c in "$BE" "$FE"; do
    ST=$(docker inspect -f '{{.State.StartedAt}}' "$c" 2>/dev/null)
    RC=$(docker inspect -f '{{.RestartCount}}' "$c" 2>/dev/null)
    STE=$(ep "$ST")
    CIMG=$(docker inspect -f '{{.Image}}' "$c" 2>/dev/null)
    CIME=$(docker image inspect --format '{{.Created}}' "$CIMG" 2>/dev/null | sed -E 's/\.[0-9]+(Z|[+-][0-9:]+)$/\1/')
    CIME=$(ep "$CIME")
    if [ -z "$STE" ]; then fail=$((fail+1)); echo "  FAIL $c: non leggo StartedAt"
    elif [ "$DERIVATO" = "0" ] && [ "$STE" -lt "$RIF_E" ]; then
      fail=$((fail+1))
      echo "  FAIL $c avviato $(iso "$STE") UTC, PRIMA del deploy ($RIF)."
      echo "       O il deploy non ha rialzato i container, o l'orologio passato e' sbagliato, o"
      echo "       qualcuno li ha riavviati prima. Non dichiarare successo."
    elif [ -n "$CIME" ] && [ "$STE" -lt "$CIME" ]; then
      fail=$((fail+1)); echo "  FAIL $c avviato $(iso "$STE") UTC, prima della sua immagine ($(iso "$CIME")): impossibile, c'e' sporco dentro docker"
    elif [ "$DERIVATO" = "0" ]; then pass=$((pass+1)); echo "  ok   $c avviato $(iso "$STE") UTC, dopo il deploy"
    else saltati=$((saltati+1)); echo "  --   $c avviato $(iso "$STE") UTC, dopo la sua immagine ($(iso "$CIME")). Il"
      echo "       'dopo il deploy' non e' verificabile senza l'ora vera: ripassala come argomento."
    fi
    ck "$c RestartCount" "$RC" "0"
  done

  # Il DB NON va nel giro sopra: `up -d` alza prima il database e poi gli applicativi, quindi parte
  # LEGITTIMAMENTE qualche secondo prima (misurato: db 08:59:57, backend 09:00:03 con deploy alle 09:00).
  # E la sua immagine, postgres:16-alpine, non viene ricostruita dal deploy: pretendere che riparta dopo
  # l'istante del deploy e' una pretesa sbagliata, non un guasto. Qui serve un'altra cosa: che ci sia,
  # sia healthy e che non sia mai restartato.
  DRC=$(docker inspect -f '{{.RestartCount}}' "$DB" 2>/dev/null)
  DST=$(docker inspect -f '{{.State.StartedAt}}' "$DB" 2>/dev/null)
  DHEALTH=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}nessun healthcheck{{end}}' "$DB" 2>/dev/null)
  ck "$DB RestartCount" "$DRC" "0"
  ck "$DB healthy" "$DHEALTH" "healthy"
  echo "       (avviato $(iso "$(ep "$DST")") UTC; il riavvio al deploy non e' una sua condizione)"

  echo "--- 4. i 4 worker uvicorn sono vivi, e stderr e' pulito ---"
  # stdout NON e' una prova: le print("Migration: ...") sono bufferizzate a blocchi senza TTY e possono
  # comparire dopo la finestra che stai leggendo. I traceback vanno su stderr, non bufferizzato.
  BST=$(docker inspect -f '{{.State.StartedAt}}' "$BE" 2>/dev/null)
  BST_E=$(ep "$BST"); [ -z "$BST_E" ] && BST_E=$RIF_E
  LOG=$($COMPOSE logs --since "$(iso "$BST_E")" backend 2>&1)
  NSTART=$(printf '%s' "$LOG" | grep -c "Started server process")
  ck "worker uvicorn avviati (PROD gira con --workers 4)" "$NSTART" "4"
  NCRASH=$(printf '%s' "$LOG" | grep -ciE "traceback|uniqueviolation|worker failed|exited with code")
  ck "nessun traceback / UniqueViolation / worker morto nel log di questa vita del container" "$NCRASH" "0"

  echo "--- 5. smoke HTTP dal server ---"
  c200=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 http://127.0.0.1:3000/)
  ck "GET / (frontend)" "$c200" "200"
  c401=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 http://127.0.0.1:8000/auth/me)
  ck "GET /api/auth/me senza token" "$c401" "401"
  for d in docs openapi.json redoc; do
    cd_=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "http://127.0.0.1:8000/$d")
    if [ -n "$cd_" ] && [ "$cd_" != "200" ]; then pass=$((pass+1)); echo "  ok   /api/$d non esposto ($cd_)"
    else fail=$((fail+1)); echo "  FAIL /api/$d risponde $cd_ : la mappa dell'API e' di nuovo pubblica"; fi
  done
  cpers=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 http://127.0.0.1:8000/persone/)
  if [ "$cpers" = "401" ] || [ "$cpers" = "403" ]; then pass=$((pass+1)); echo "  ok   /api/persone/ richiede autenticazione ($cpers)"
  else fail=$((fail+1)); echo "  FAIL /api/persone/ risponde $cpers (atteso 401/403)"; fi

  echo "--- 6. il DB risponde e i dati ci sono (un deploy che ricrea lo schema da zero si vede qui) ---"
  q() { docker exec -i $(docker ps -qf name=db) psql -U registro_user -d registro -tA -f - <<< "$1" | tr -d '\r'; }
  ckmin "persone popolate"   "$(q "SELECT count(*) FROM persone")"   50
  ckmin "registro popolato"  "$(q "SELECT count(*) FROM registro")"  1000
  ckmin "categorie popolate" "$(q "SELECT count(*) FROM categorie")" 10
  ckmin "utenti presenti"    "$(q "SELECT count(*) FROM utenti")"    10

  echo
  echo "  ------------------------------------------------------------"
  echo "  $pass passati, $fail falliti, $avviso note, $saltati controlli temporali NON fatti"
  [ $fail -eq 0 ] || echo "  NON dichiarare il deploy riuscito finche' i falliti non sono 0."
  [ "$saltati" -gt 0 ] && echo "  Con $saltati controlli temporali saltati il verdetto 'il deploy ha rialzato i container' NON c'e': rilancia con l'ora vera del deploy come primo argomento."
  echo
  echo "  Questo script NON copre le suite PROD, che vanno lanciate a parte dalla postazione:"
  echo "    bash scripts/test/test_login_guard_prod.sh    # ~47 asserzioni"
  echo "    bash scripts/test/test_pii_prod.sh            # ~33"
  echo "    bash scripts/test/test_post_deploy_prod.sh    # ~53"
  echo "  Ne' copre la UI: per quella ci sono verifica_ui_tornei.sh / verifica_ui_scelta.sh /"
  echo "  verifica_ui_weekend.sh, e il grep sul chunk servito non basta mai (prova che il testo e'"
  echo "  distribuito, non che il pulsante sia dipinto). L'APK non si aggiorna da solo: carica i propri"
  echo "  asset, serve build_android_apk.sh + publish_android_apk.sh."
  exit $([ $fail -eq 0 ] && echo 0 || echo 1)
fi

# ------------------------------------------------------------------ wrapper locale
KV="${THOF_PROD_KEY:-$HOME/.ssh/id_ed25519_prod}"
IP="${THOF_PROD_IP:-192.168.178.132}"
[ -f "$0" ] || { echo "  non trovo il mio stesso file: invocalo con il percorso"; exit 2; }
echo "=== verifica post-deploy su PROD ($IP) ==="
timeout 120 scp -q -i "$KV" "$0" root@$IP:/tmp/verifica_deploy.sh || { echo "  scp fallito"; exit 1; }
timeout 600 ssh -i "$KV" -o ConnectTimeout=15 root@$IP "LATO_SERVER=1 bash /tmp/verifica_deploy.sh \"${1:-}\"" 2>&1 \
  | grep -v "Warning: Permanently added"
# PIPESTATUS[0], NON $?: dopo una pipeline $? e' l'exit di grep, che dice solo se ha stampato righe.
# Prendere $qui renderebbe verde una verifica rossa sul server: il fallimento sparirebbe in silenzio.
RC=${PIPESTATUS[0]}
timeout 120 ssh -i "$KV" root@$IP 'rm -f /tmp/verifica_deploy.sh' >/dev/null 2>&1
exit $RC
