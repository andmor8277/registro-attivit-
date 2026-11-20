#!/bin/bash
# Cifra i codici fiscali ancora in chiaro su `persone` usando la chiave attuale.
#
#   scripts/ops/cifra_cf.sh dev          # solo dry-run + verifica
#   scripts/ops/cifra_cf.sh dev  --applica
#   scripts/ops/cifra_cf.sh prod --applica
#
# Senza --applica si limita a misurare e mostrare cosa verrebbe cifrato: nessuna scrittura.
#
# Perche' un wrapper e non una chiamata all'endpoint: PUT /persone/encryption-key?reencrypt=true
# azzera i campi che non decifrano (vedi il docstring di cifra_cf_in_chiaro.py). Non usarla.
#
# Richiede il backup del DB gia' fatto: come ruota_segreti.sh vuole il .env backuppato, qui si
# rifiuta di scrivere senza un dump verificato, perche' l'operazione non ha un "togli la cifratura"
# a portata di click (si puo' fare, ma solo con lo stesso script al contrario e la chiave giusta).
set -u
AMBIENTE=${1:-}
MODO=${2:-}
case "$AMBIENTE" in
  dev)  KV="$HOME/.ssh/id_ed25519_dev";  IP=192.168.178.133 ;;
  prod) KV="$HOME/.ssh/id_ed25519_prod"; IP=192.168.178.132 ;;
  *) echo "Uso: $0 dev|prod [--applica]"; exit 2 ;;
esac
SSH="ssh -i $KV -o ConnectTimeout=15 root@$IP"
BE="registro_presenze-backend-1"
SCRIPT="scripts/ops/cifra_cf_in_chiaro.py"
[ -f "$SCRIPT" ] || { echo "  lancia dalla radice del progetto (manca $SCRIPT)"; exit 2; }

q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

echo "=== ambiente: $AMBIENTE ($IP) ==="
echo "--- 1. backup del DB (obbligatorio prima di scrivere) ---"
TS=$(date -u +%Y%m%d_%H%M%S)
F=/root/${AMBIENTE}_pre_cifratura_cf_$TS.sql.gz
$SSH "docker exec \$(docker ps -qf name=db) pg_dump -U registro_user -d registro | gzip > $F" || {
  echo "  backup fallito, mi fermo"; exit 1; }
BYTE=$($SSH "stat -c %s $F 2>/dev/null || wc -c < $F" | tr -d ' ')
if [ -z "$BYTE" ] || [ "$BYTE" -lt 1024 ]; then
  echo "  backup sospetto ($BYTE byte), mi fermo"; exit 1
fi
RIGHE_PERSONE_DUMP=$($SSH "gunzip -c $F | awk 'index(\$0,\"COPY public.persone \")==1{f=1;next} f&&/^\\\\.\$/{exit} f{c++} END{print c+0}'" | tr -d ' ')
RIGHE_PERSONE_DB=$(q "SELECT count(*) FROM persone")
echo "  $F ($BYTE byte)"
echo "  persone nel dump: $RIGHE_PERSONE_DUMP  |  nel DB: $RIGHE_PERSONE_DB"
if [ "$RIGHE_PERSONE_DUMP" != "$RIGHE_PERSONE_DB" ]; then
  echo "  il dump non contiene tutte le righe persone, mi fermo"; exit 1
fi

echo "--- 2. dry-run ---"
$SSH "docker exec -i -w /app $BE python - dry" < "$SCRIPT"
RC=$?
[ $RC -ne 0 ] && { echo "  dry-run fallito (exit $RC): non si applica niente"; exit $RC; }

if [ "$MODO" != "--applica" ]; then
  echo
  echo "  nessuna scrittura. Per applicare: $0 $AMBIENTE --applica"
  exit 0
fi

echo "--- 3. applicazione ---"
$SSH "docker exec -i -w /app $BE python - apply" < "$SCRIPT"
RC=$?
if [ $RC -ne 0 ]; then
  echo "  APPLICAZIONE FALLITA (exit $RC). Il backup verificato e' $F"
  exit $RC
fi

echo "--- 4. verifica col test dedicato ---"
AMBIENTE=$AMBIENTE PERSONE_ATTESE=$RIGHE_PERSONE_DB bash scripts/test/test_cifratura_cf.sh
RC=$?
echo
if [ $RC -eq 0 ]; then
  echo "  fatto. Backup: $F"
else
  echo "  VERIFICA ROSSA dopo l'applicazione. Backup verificato: $F"
fi
exit $RC
