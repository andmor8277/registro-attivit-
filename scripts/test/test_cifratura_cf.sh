#!/bin/bash
# Invariante: nessun codice fiscale in chiaro su `persone`, e il percorso di lettura dell'app
# continua a mostrarlo a chi ne ha diritto.
#
# Perche' un test e non un controllo una tantum: i 16 CF rimasti in chiaro su PROD per mesi non
# erano un incidente visibile da nessuna parte. L'applicazione cifra in scrittura (lo verifica
# test_pii_accessi.sh), quindi "zero in chiaro" e' un'invariante che si PUO' imporre, e se qualcuno
# la rompe - un import via SQL, uno script, una rotta che scrive il campo senza passare da
# safe_encrypt - questo e' il punto in cui deve comparire un rosso.
#
# Esercita anche HTTP, non solo il DB: un CF che decifra in psql ma arriva al client come esadecimale
# sarebbe un rosso che il solo conteggio non vede.
#
# Uso: AMBIENTE=dev|prod PERSONE_ATTESE=64 bash test_cifratura_cf.sh
set -u
AMBIENTE=${AMBIENTE:-dev}
if [ "$AMBIENTE" = "prod" ]; then
  D=https://thof.crickethouse.mywire.org/api
  SSH="ssh -i $HOME/.ssh/id_ed25519_prod -o ConnectTimeout=15 root@192.168.178.132"
  PERSONE_ATTESE=${PERSONE_ATTESE:-}
else
  D=http://192.168.178.133:3000/api
  SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
  PERSONE_ATTESE=${PERSONE_ATTESE:-}
fi
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }
pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }

echo "  ambiente: $AMBIENTE -> $D"
PLAIN_SQL="codice_fiscale IS NOT NULL AND trim(codice_fiscale)<>''
             AND NOT (length(codice_fiscale)>=32 AND codice_fiscale ~ '^[0-9a-f]+$')"
N_CHIARO=$(q "SELECT count(*) FROM persone WHERE $PLAIN_SQL")
N_CIFRATI=$(q "SELECT count(*) FROM persone WHERE codice_fiscale ~ '^[0-9a-f]+$' AND length(codice_fiscale)>=32")
N_NULLI=$(q "SELECT count(*) FROM persone WHERE codice_fiscale IS NULL OR trim(codice_fiscale)=''")
PRIMA_PERSONE=$(q "SELECT count(*) FROM persone")
PRIMA_REGISTRO=$(q "SELECT count(*) FROM registro")
echo "  nel DB: $N_CIFRATI cifrati, $N_CHIARO in chiaro, $N_NULLI nulli/vuoti su $PRIMA_PERSONE persone"
ck "nessun codice fiscale in chiaro su persone" "$N_CHIARO" "0"
# un DB senza nemmeno un CF cifrato significherebbe che il test non sta misurando niente
if [ "$N_CIFRATI" -lt 10 ]; then
  echo "  FAIL solo $N_CIFRATI CF cifrati: il test non ha prerequisiti da verificare, si ferma qui"
  echo; echo "  $pass passati, $((fail+1)) falliti"; exit 1
fi

PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
if [ -z "$HASH" ]; then echo "  FAIL impossibile generare l'hash, il test si ferma"; echo; echo "  $pass passati, $((fail+1)) falliti"; exit 1; fi
q "DELETE FROM utenti WHERE username LIKE 'testcf%';
   DELETE FROM login_bloccaggi WHERE chiave LIKE 'testcf%';" >/dev/null
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testcf_admin','$HASH',1,1,0,NULL),
          ('testcf_mister','$HASH',1,0,0,'mister');" >/dev/null
tok() { curl -s --max-time 20 -X POST "$D/auth/token" -d "username=$1&password=$PW" \
        | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null; }
TADM=$(tok testcf_admin); TM=$(tok testcf_mister)
ck "login admin di prova"  "$([ -n "$TADM" ] && echo si)" "si"
ck "login mister di prova" "$([ -n "$TM" ]  && echo si)" "si"
if [ -z "$TADM" ] || [ -z "$TM" ]; then
  echo "  FAIL senza token non si puo' verificare il percorso di lettura: mi fermo"
  q "DELETE FROM utenti WHERE username LIKE 'testcf%'; DELETE FROM login_bloccaggi WHERE chiave LIKE 'testcf%';" >/dev/null
  echo; echo "  $pass passati, $((fail+1)) falliti"; exit 1
fi

# Mai fidarsi del solo conteggio: se l'API lasciasse passare il cipher, il DB sarebbe "a posto"
# e la segreteria vedrebbe una stringa esadecimale al posto del codice fiscale.
CONTAPY="
import sys,json,re
CF=re.compile(r'^[A-Z0-9]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]\$')
d=json.load(sys.stdin)
if not isinstance(d,list): print('ERRORE'); sys.exit(1)
print(sum(1 for r in d if r.get('codice_fiscale') and CF.match(str(r['codice_fiscale']).strip().upper())))"
PASSANTI_PY="
import sys,json
d=json.load(sys.stdin)
print(sum(1 for r in d if r.get('codice_fiscale') and len(r['codice_fiscale'])>=32
          and all(c in '0123456789abcdef' for c in r['codice_fiscale'])))"
CON_PY="import sys,json;d=json.load(sys.stdin);print(sum(1 for r in d if r.get('codice_fiscale')))"
CON_CF=$(curl -s --max-time 40 "$D/persone/" -H "Authorization: Bearer $TADM" | python3 -c "$CON_PY" 2>/dev/null)
LEGGIIBILI=$(curl -s --max-time 40 "$D/persone/" -H "Authorization: Bearer $TADM" | python3 -c "$CONTAPY" 2>/dev/null)
PASSANTI=$(curl -s --max-time 40 "$D/persone/" -H "Authorization: Bearer $TADM" | python3 -c "$PASSANTI_PY" 2>/dev/null)
echo "  API all'amministrazione: $CON_CF righe con CF, $LEGGIIBILI leggibili, $PASSANTI ancora cifrate"
ck "l'API decifra i CF a chi puo' vedere i dati sensibili" "$( [ "${LEGGIIBILI:-0}" -ge 10 ] && echo si )" "si"
ck "nessun CF esadecimale arriva al client" "$PASSANTI" "0"
NASC=$(curl -s --max-time 40 "$D/persone/" -H "Authorization: Bearer $TM" | python3 -c "$CON_PY" 2>/dev/null)
ck "il mister senza assegnazione non vede nessun CF" "$NASC" "0"

q "DELETE FROM utenti WHERE username LIKE 'testcf%';
   DELETE FROM login_bloccaggi WHERE chiave LIKE 'testcf%';" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT count(*) FROM utenti WHERE username LIKE 'testcf%'")" "0"
ck "persone invariate ($PRIMA_PERSONE)" "$(q "SELECT count(*) FROM persone")" "$PRIMA_PERSONE"
ck "registro invariato ($PRIMA_REGISTRO)" "$(q "SELECT count(*) FROM registro")" "$PRIMA_REGISTRO"
if [ -n "$PERSONE_ATTESE" ]; then
  ck "persone = valore atteso ($PERSONE_ATTESE)" "$PRIMA_PERSONE" "$PERSONE_ATTESE"
fi
echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
