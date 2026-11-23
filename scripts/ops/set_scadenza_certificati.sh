#!/bin/bash
# Imposta la scadenza del certificato medico per tutte le persone di una categoria.
#
#   scripts/ops/set_scadenza_certificati.sh dev  26 2027-07-01 esordienti 2015            # dry-run
#   scripts/ops/set_scadenza_certificati.sh prod 26 2027-07-01 esordienti 2015 --applica
#
# Senza --applica si limita a misurare e mostrare cosa cambierebbe: nessuna scrittura.
#
# Perche' un metodo ristretto e non la UI: la schermata Certificati Medici modifica UNA persona alla
# volta (PATCH /persone/{id}/certificato) e non ha un'azione di massa. 33 click a mano sui
# certificati medici di ragazzi minorenni e' il modo normale in cui si sbaglia una riga.
#
# Perche' nome e anno sono OBBLIGATORI e non "informativi": su PROD esistono TRE categorie chiamate
# "Esordienti" (2013 archiviata, 2014 archiviata, 2015 attiva) e cambiano solo per l'anno. Un id
# sbagliato di uno aggiorna la squadra sbagliata e nessuna query sembra strana. Il worker rifiuta se
# nome o anno non corrispondono, e rifiuta una categoria archiviata.
#
# Vuole il backup del DB gia' fatto e verificato: come cifra_cf.sh, perche' qui non esiste un
# "togli la data" a portata di click che riporti le righe a NULL senza perdere le date che c'erano
# prima (che qui non ci sono, ma il punto e' il metodo).
set -u
AMBIENTE=${1:-}
CAT=${2:-}
DATA=${3:-}
NOME=${4:-}
ANNO=${5:-}
MODO=${6:-}
case "$AMBIENTE" in
  dev)  KV="$HOME/.ssh/id_ed25519_dev";  IP=192.168.178.133 ;;
  prod) KV="$HOME/.ssh/id_ed25519_prod"; IP=192.168.178.132 ;;
  *) echo "Uso: $0 dev|prod <categoria_id> <AAAA-MM-GG> <nome-atteso> <anno-atteso> [--applica]"; exit 2 ;;
esac
[ -z "$CAT" ] || [ -z "$DATA" ] || [ -z "$NOME" ] || [ -z "$ANNO" ] && {
  echo "  mancano categoria, data, nome o anno: sono tutti e quattro obbligatori"
  echo "  Uso: $0 $AMBIENTE <categoria_id> <AAAA-MM-GG> <nome-atteso> <anno-atteso> [--applica]"
  exit 2; }
SSH="ssh -i $KV -o ConnectTimeout=15 root@$IP"
BE="registro_presenze-backend-1"
SCRIPT="scripts/ops/set_scadenza_certificati.py"
[ -f "$SCRIPT" ] || { echo "  lancia dalla radice del progetto (manca $SCRIPT)"; exit 2; }

q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

echo "=== ambiente: $AMBIENTE ($IP) — categoria $CAT, scadenza $DATA ==="

echo "--- 1. backup del DB (obbligatorio prima di scrivere) ---"
TS=$(date -u +%Y%m%d_%H%M%S)
F=/root/${AMBIENTE}_pre_scadenza_cert_$TS.sql.gz
$SSH "docker exec \$(docker ps -qf name=db) pg_dump -U registro_user -d registro | gzip > $F" || {
  echo "  backup fallito, mi fermo"; exit 1; }
BYTE=$($SSH "stat -c %s $F 2>/dev/null || wc -c < $F" | tr -d ' ')
if [ -z "$BYTE" ] || [ "$BYTE" -lt 1024 ]; then
  echo "  backup sospetto ($BYTE byte), mi fermo"; exit 1
fi
# Non basta che il dump esista: deve contenere tutte le righe persone, altrimenti il ripristino
# sembrerebbe riuscito e avrebbe perso dei tesserati.
DUMP_PERSONE=$($SSH "gunzip -c $F | awk 'index(\$0,\"COPY public.persone \")==1{f=1;next} f&&/^\\\\.\$/{exit} f{c++} END{print c+0}'" | tr -d ' ')
DB_PERSONE=$(q "SELECT count(*) FROM persone")
echo "  $F ($BYTE byte)"
echo "  persone nel dump: $DUMP_PERSONE  |  nel DB: $DB_PERSONE"
if [ "$DUMP_PERSONE" != "$DB_PERSONE" ]; then
  echo "  il dump non contiene tutte le righe persone, mi fermo"; exit 1
fi
SHA=$($SSH "sha256sum $F | cut -c1-16")
echo "  sha256: $SHA...  gzip -t: $($SSH "gzip -t $F && echo OK")"

echo "--- 2. stato prima, letto dal DB ---"
q "SELECT '  cat '||id||' \"'||nome||'\" anno='||coalesce(anno::text,'NULL')||' soc='||societa_id||
      ' archiviata='||coalesce(is_archiviata::text,'?')
   FROM categorie WHERE id=$CAT;
   SELECT '  persone='||count(*)||' senza data='||count(*) FILTER (WHERE scadenza_certificato IS NULL)||
      ' scadute='||count(*) FILTER (WHERE scadenza_certificato < current_date)||
      ' valide='||count(*) FILTER (WHERE scadenza_certificato >= current_date)
   FROM persone WHERE categoria_id=$CAT;"

echo "--- 3. dry-run dentro il container backend ---"
$SSH "docker exec -i -w /app $BE python - dry $CAT $DATA $NOME $ANNO" < "$SCRIPT"
RC=$?
[ $RC -ne 0 ] && { echo "  dry-run fallito (exit $RC): non si applica niente"; exit $RC; }

if [ "$MODO" != "--applica" ]; then
  echo
  echo "  nessuna scrittura. Per applicare: $0 $AMBIENTE $CAT $DATA $NOME $ANNO --applica"
  exit 0
fi

echo "--- 4. applicazione ---"
$SSH "docker exec -i -w /app $BE python - apply $CAT $DATA $NOME $ANNO" < "$SCRIPT"
RC=$?
if [ $RC -ne 0 ]; then
  echo "  APPLICAZIONE FALLITA (exit $RC). Backup verificato: $F (sha256 $SHA...)"
  exit $RC
fi

echo "--- 5. verifica a freddo, rileggendo il DB da fuori ---"
DOPO=$(q "SELECT count(*)||'/'||(count(*) FILTER (WHERE scadenza_certificato='$DATA'::date))||'/'||(count(*) FILTER (WHERE scadenza_certificato IS NULL))
         FROM persone WHERE categoria_id=$CAT;")
echo "  categoria $CAT: totali/data_corretta/senza_data = $DOPO"
TOT=$(printf '%s' "$DOPO" | cut -d/ -f1); OK=$(printf '%s' "$DOPO" | cut -d/ -f2); NULLA=$(printf '%s' "$DOPO" | cut -d/ -f3)
if [ "$TOT" = "$OK" ] && [ "$NULLA" = "0" ] && [ "$TOT" != "0" ]; then
  echo "  ok: tutte le $TOT persone della categoria hanno la scadenza $DATA"
else
  echo "  ROSSO: atteso totali=data_corrette e senza_data=0, letto '$DOPO'. Backup verificato: $F"
  exit 1
fi
# Le altre categorie non devono essere cambiate: e' l'unica prova esterna al WHERE dell'UPDATE
ALTRE=$(q "SELECT count(*) FROM persone WHERE scadenza_certificato='$DATA'::date AND categoria_id IS DISTINCT FROM $CAT;")
echo "  righe con quella data FUORI dalla categoria: $ALTRE"
echo
echo "  fatto. Backup: $F (sha256 $SHA...)"
exit 0
