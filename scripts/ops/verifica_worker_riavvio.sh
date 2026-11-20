#!/bin/bash
# Misura la salute dei worker uvicorn a un riavvio, per provare la corsa di Base.metadata.create_all.
#
#   AMBIENTE=dev bash scripts/ops/verifica_worker_riavvio.sh drop [cicli]    # droppa le tabelle dei tornei e riavvia N volte
#   AMBIENTE=dev bash scripts/ops/verifica_worker_riavvio.sh restart [cicli] # solo riavvio
#
# Sta in scripts/ops e non in scripts/test perche' `run_suite_dev.sh` scopre solo scripts/test/
# test_*.sh: questo RIAVVIA il backend e DROPPA tabelle, non e' un test da fare a ogni suite.
# Voluto: l'ultima esecuzione ha fatto 14 cicli senza un crash, contro i 2 crash su 4 cicli di prima.
#
# Droppare `tornei` e `tornei_gare` (vuote su DEV) e' l'unico modo di far scattare la corsa:
# create_all non fa nulla se la tabella esiste gia', quindi con lo schema gia' creato il difetto e'
# invisibile. E' cosi' che si e' presentato su PROD al deploy dei tornei: 3 SpawnProcess morti su 4.
#
# ATTENZIONE a cosa si puo' misurare dai log. Le righe "Migration: ..." sono print() su stdout, e
# Python bufferizza a blocchi quando stdout non e' un TTY: possono comparire nel log anche minuti
# dopo, o dopo la finestra che stai leggendo. I traceback invece vanno su stderr, non bufferizzato.
# Quindi le asserzioni dure stanno solo sulle cose di stderr (traceback, UniqueViolation, processi
# morti); i contatori "Migration:" sono informativi e possono mentire per ritardo di flush.
set -u
AMBIENTE=${AMBIENTE:-dev}
AZIONE=${1:-restart}
CICLI=${2:-1}
if [ "$AMBIENTE" = "prod" ]; then
  KV="$HOME/.ssh/id_ed25519_prod"; IP=192.168.178.132
  COMPOSE="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
  URL=https://thof.crickethouse.mywire.org/api
else
  KV="$HOME/.ssh/id_ed25519_dev"; IP=192.168.178.133
  COMPOSE="docker compose"
  URL=http://192.168.178.133:3000/api
fi
SSH="ssh -i $KV -o ConnectTimeout=15 root@$IP"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
# Il vincolo lo si cerca per NOME, non risolvendo 'tornei'::regclass: quando tornei e' stata droppata
# col CASCADE, confrelid='tornei'::regclass fa errori su una tabella che non esiste piu' e
# l'asserzione diventa rossa per il modo sbagliato. Il nome e' lo stesso sia generato in automatico
# dalla REFERENCES inline sia creato in modo esplicito dalla migrazione.
FK() { q "SELECT count(*) FROM pg_constraint WHERE conname='liste_torneo_torneo_id_fkey'"; }

CRASH_TOTALI=0
for CICLO in $(seq 1 "$CICLI"); do
  echo
  echo "=================== ciclo $CICLO di $CICLI ==================="
  if [ "$AZIONE" = "drop" ]; then
    VUOTE=$(q "SELECT (SELECT count(*) FROM tornei)+(SELECT count(*) FROM tornei_gare)")
    if [ "$VUOTE" != "0" ]; then
      echo "  FERMO: tornei/tornei_gare non sono vuote ($VUOTE righe): non le droppo"
      exit 2
    fi
    # CASCADE perche' liste_torneo_torneo_id_fkey si appoggia a tornei: senza, il DROP di tornei
    # viene rifiutato e si finisce per droppare solo tornei_gare.
    q "DROP TABLE IF EXISTS tornei_gare; DROP TABLE IF EXISTS tornei CASCADE;" >/dev/null 2>&1
    ck "  tabelle droppate"        "$(q "SELECT count(*) FROM information_schema.tables WHERE table_name IN ('tornei','tornei_gare')")" "0"
    ck "  FK saltata via col CASCADE" "$(FK)" "0"
    ck "  colonna torneo_id rimasta"  "$(q "SELECT count(*) FROM information_schema.columns WHERE table_name='liste_torneo' AND column_name='torneo_id'")" "1"
  fi

  T0=$(date -u +%Y-%m-%dT%H:%M:%S)
  $SSH "cd /opt/registro_presenze && $COMPOSE restart backend" >/dev/null 2>&1
  sleep 40
  L=$($SSH "cd /opt/registro_presenze && $COMPOSE logs --since $T0 backend 2>&1")
  n() { printf '%s\n' "$L" | grep -cE "$1"; }

  echo "  --- stderr (affidabile) ---"
  echo "    Started parent process : $(n 'Started parent process')          (atteso 1)"
  echo "    Started server process : $(n 'Started server process')          (atteso 4)"
  echo "    Application startup ok : $(n 'Application startup complete')    (atteso 4)"
  echo "    Process SpawnProcess-N : $(n 'Process SpawnProcess-[0-9]+:')    (atteso 0 = processi morti)"
  echo "    Traceback              : $(n 'Traceback \(most recent call last\)')       (atteso 0)"
  echo "    UniqueViolation        : $(n 'UniqueViolation')                 (atteso 0)"
  echo "    pg_class_relname_nsp   : $(n 'pg_class_relname_nsp_index')      (atteso 0)"
  echo "    create_all nel traceback: $(n 'create_all')                     (atteso 0)"
  echo "  --- stdout (puo' ritardare per il flush di Python, non e' un'asserzione) ---"
  echo "    Migration: Created tornei : $(n 'Migration: Created tornei')"
  echo "    Could not acquire lock    : $(n 'Could not acquire advisory lock')"

  ck "  un solo parent"           "$(n 'Started parent process')"        "1"
  ck "  quattro worker avviati"   "$(n 'Started server process')"        "4"
  ck "  quattro startup complete" "$(n 'Application startup complete')"  "4"
  MORTI=$(n 'Process SpawnProcess-[0-9]+:')
  CRASH_TOTALI=$((CRASH_TOTALI + MORTI))
  ck "  nessun processo crashato" "$MORTI" "0"
  ck "  nessun traceback"         "$(n 'Traceback \(most recent call last\)')" "0"
  ck "  nessuna UniqueViolation"  "$(n 'UniqueViolation')"                "0"
  ck "  nessuna collisione su pg_class" "$(n 'pg_class_relname_nsp_index')" "0"

  echo "  --- esito sullo schema ---"
  ck "  tornei e tornei_gare ricreate" "$(q "SELECT count(*) FROM information_schema.tables WHERE table_name IN ('tornei','tornei_gare')")" "2"
  ck "  tornei_id_seq unica"           "$(q "SELECT count(*) FROM pg_class WHERE relname='tornei_id_seq'")" "1"
  ck "  FK liste_torneo->tornei rimessa su" "$(FK)" "1"
  ck "  indice UNIQUE ux_liste_torneo_torneo" "$(q "SELECT count(*) FROM pg_indexes WHERE indexname='ux_liste_torneo_torneo'")" "1"
  ck "  indice ix_tornei_societa_categoria"   "$(q "SELECT count(*) FROM pg_indexes WHERE indexname='ix_tornei_societa_categoria'")" "1"

  CK=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$URL/auth/me")
  ck "  GET /api/auth/me senza token -> 401" "$CK" "401"
done

echo
echo "  processi crashati sommati su $CICLI cicli: $CRASH_TOTALI"
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
