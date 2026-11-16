#!/bin/bash
# POST /auth/utenti: chi crea un account NON deve poter scegliere ne' vedere la password.
#
# Prima di questa modifica l'admin passava il campo `password` nel body e quindi conosceva una
# credenziale valida per quell'account: poteva entrarci. Il flag deve_cambiare_password chiudeva
# la finestra solo dopo il primo accesso dell'interessato. Ora la password e' generata dal server
# e consegnata via mail, e la risposta non la contiene.
#
# Uso: scripts/test/test_creazione_utente.sh      (DEV)
#      KV=... IP=... D=... scripts/test/test_creazione_utente.sh   (per puntare ad altro ambiente)
set -u
KV=${KV:-$HOME/.ssh/id_ed25519_dev}
IP=${IP:-192.168.178.133}
D=${D:-http://192.168.178.133:3000/api}
SSH="ssh -i $KV -o ConnectTimeout=15 root@$IP"
BE=registro_presenze-backend-1

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }
cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 "$@"; }
hash() { $SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$1'))\"" 2>/dev/null | tr -d '\r' | tail -1; }

# --data-urlencode perche' le password generate contengono &, % e #; il retry sul 429 perche'
# /auth/token ha @limiter.limit("10/minute") e senza di esso un limite di frequenza si
# presenterebbe come un 401/403 mancante
tok() {
  local out code i
  for i in 1 2 3 4 5; do
    out=$(curl -s -w '\n%{http_code}' --max-time 25 -X POST "$D/auth/token" \
             --data-urlencode "username=$1" --data-urlencode "password=$2")
    code="${out##*$'\n'}"
    if [ "$code" = "429" ]; then sleep 8; continue; fi
    printf '%s' "${out%$'\n'*}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null
    return 0
  done
  echo ""
}
post_utenti() {   # post_utenti <json> -> stampa "CODICE\n<body>"
  curl -s -w '\n%{http_code}' --max-time 30 -X POST "$D/auth/utenti" \
       -H "Authorization: Bearer $TOK_ADM" -H "Content-Type: application/json" -d "$1"
}

U_ADM="testc_admin@x.local";      P_ADM="Adm-$(openssl rand -hex 6)"
U_MISTER="testc_mister@x.local";  P_MISTER="Sir-$(openssl rand -hex 6)"
U_ALTRO="testc_admin2@x.local";   P_ALTRO="Adm2-$(openssl rand -hex 6)"
# password che un client malevolo (o un admin distratto) provera' a imporre: non deve attecchire
PW_IMPOSTA="ProvataDalClient-1aA!"

H_ADM=$(hash "$P_ADM"); H_MISTER=$(hash "$P_MISTER"); H_ALTRO=$(hash "$P_ALTRO")
for h in "$H_ADM" "$H_MISTER" "$H_ALTRO"; do
  [ -n "$h" ] || { echo "  impossibile generare gli hash bcrypt: annullato"; exit 1; }
done

PULISCI="testc_%"
echo "--- preparazione: un admin, un mister e un admin di altra societa' ---"
q "DELETE FROM utenti WHERE username LIKE '$PULISCI';
   INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo,nome,cognome)
   VALUES ('$U_ADM','$H_ADM',1,1,0,'admin','Admin','Test'),
          ('$U_MISTER','$H_MISTER',1,0,0,'mister','Mister','Test'),
          ('$U_ALTRO','$H_ALTRO',2,1,0,'admin','Altro','Societa');" >/dev/null
TOK_ADM=$(tok "$U_ADM" "$P_ADM")
TOK_MISTER=$(tok "$U_MISTER" "$P_MISTER")
ck "login admin societa' 1 -> token" "$([ -n "$TOK_ADM" ] && echo si)" "si"
ck "login mister -> token" "$([ -n "$TOK_MISTER" ] && echo si)" "si"

echo "--- 1. senza indirizzo email la creazione e' rifiutata ---"
R=$(post_utenti '{"username":"testc_senza_email","nome":"Senza","cognome":"Mail","societa_id":1,"ruolo":"mister"}')
CODICE=${R##*$'\n'}; BODY=${R%$'\n'*}
ck "POST senza email -> 400" "$CODICE" "400"
ck "  e il motivo chiede un indirizzo email" "$(echo "$BODY" | grep -ci "email")" "1"
ck "  nessun account creato" \
   "$(q "SELECT count(*) FROM utenti WHERE username='testc_senza_email'")" "0"

echo "--- 2. un indirizzo malformato non basta ---"
ck "username senza chiocciola ne' email -> 400" \
   "$(post_utenti '{"username":"testc_noat","nome":"N","cognome":"C","societa_id":1,"ruolo":"mister"}' | tail -1)" "400"
ck "'mario@rossi' (manca il punto) -> 400" \
   "$(post_utenti '{"username":"testc_no punto","nome":"N","cognome":"C","societa_id":1,"ruolo":"mister","email":"mario@rossi"}' | tail -1)" "400"
ck "  e nessun account creato con l'email malformata" \
   "$(q "SELECT count(*) FROM utenti WHERE username LIKE 'testc_no%'")" "0"

echo "--- 3. la password scelta dal client viene ignorata ---"
R=$(post_utenti "{\"username\":\"testc_pwimposta\",\"nome\":\"Password\",\"cognome\":\"Ignorata\",\"societa_id\":1,\"ruolo\":\"mister\",\"email\":\"testc.pwimposta@x.local\",\"password\":\"$PW_IMPOSTA\"}")
CODICE=${R##*$'\n'}; BODY=${R%$'\n'*}
ck "POST con il campo password nel body -> 200 (il campo e' scartato, non un errore)" "$CODICE" "200"
ck "  l'account esiste" "$(q "SELECT count(*) FROM utenti WHERE username='testc_pwimposta'")" "1"
ck "  e la password impostata dal client NON apre l'account" \
   "$([ -z "$(tok 'testc_pwimposta' "$PW_IMPOSTA")" ] && echo si)" "si"

echo "--- 4. la risposta non contiene nessuna credenziale ---"
CHIAVI=$(echo "$BODY" | python3 -c "import sys,json;print(','.join(sorted(json.load(sys.stdin).keys())))" 2>/dev/null)
ck "  le chiavi della risposta sono solo quelle previste" \
   "$CHIAVI" "email_inviata,id,ok,username"
ck "  nessuna chiave parla di password" "$(echo "$BODY" | grep -ci 'password\|temporanea\|hash')" "0"
# la prova vera, non un proxy: nessuno dei valori testuali della risposta apre l'account
VALORI=$(echo "$BODY" | python3 -c "
import sys,json
for v in json.load(sys.stdin).values():
    if isinstance(v,str): print(v)" 2>/dev/null)
APRE="no"
for v in $VALORI; do
  [ -n "$(tok 'testc_pwimposta' "$v")" ] && APRE="si"
done
ck "  nessun valore testuale della risposta funziona come password" "$APRE" "no"

echo "--- 5. l'account nasce con una password che nessuno all'admin conosce ---"
ck "  password_hash valorizzato (e' un account a accesso locale)" \
   "$(q "SELECT count(*) FROM utenti WHERE username='testc_pwimposta' AND password_hash IS NOT NULL")" "1"
ck "  deve_cambiare_password TRUE: finche' non la cambia l'app risponde 403" \
   "$(q "SELECT deve_cambiare_password::text FROM utenti WHERE username='testc_pwimposta'")" "true"
ck "  e la mail e' partita (SMTP l'ha accettata)" \
   "$(echo "$BODY" | python3 -c "import sys,json;print(json.load(sys.stdin).get('email_inviata'))" 2>/dev/null)" "True"

echo "--- 6. se lo username e' gia' un indirizzo, la mail va a quello ---"
R=$(post_utenti '{"username":"testc.username@x.local","nome":"Username","cognome":"Email","societa_id":1,"ruolo":"mister"}')
CODICE=${R##*$'\n'}; BODY=${R%$'\n'*}
ck "POST con username = email -> 200" "$CODICE" "200"
ck "  email_inviata true (destinatario dedotto dallo username)" \
   "$(echo "$BODY" | python3 -c "import sys,json;print(json.load(sys.stdin).get('email_inviata'))" 2>/dev/null)" "True"

echo "--- 7. i controlli di autorizzazione di prima non si sono rotti ---"
ck "username gia' esistente -> 400 e dice perche'" \
   "$(post_utenti '{"username":"testc_pwimposta","nome":"Doppio","cognome":"Test","societa_id":1,"ruolo":"mister","email":"doppio@x.local"}' \
     | python3 -c "import sys;d=sys.stdin.read();print(d.splitlines()[-1], 'Username' in d)" 2>/dev/null)" "400 True"
ck "admin di altra societa' non puo' creare per la societa' 1 -> 403" \
   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/auth/utenti" \
        -H "Authorization: Bearer $(tok "$U_ALTRO" "$P_ALTRO")" -H "Content-Type: application/json" \
        -d '{"username":"testc_cross","nome":"Cross","cognome":"Test","societa_id":1,"ruolo":"mister","email":"cross@x.local"}')" "403"
ck "  e nessun account cross-societa' creato" \
   "$(q "SELECT count(*) FROM utenti WHERE username='testc_cross'")" "0"
ck "un mister non puo' creare utenti -> 403" \
   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/auth/utenti" \
        -H "Authorization: Bearer $TOK_MISTER" -H "Content-Type: application/json" \
        -d '{"username":"testc_mister_crea","nome":"No","cognome":"Test","societa_id":1,"ruolo":"mister","email":"x@x.local"}')" "403"
ck "un non super_admin non puo' creare un super_admin -> 403" \
   "$(post_utenti '{"username":"testc_super","nome":"Super","cognome":"Abusivo","societa_id":1,"ruolo":"super_admin","email":"s@x.local"}' | tail -1)" "403"
ck "  e non e' stato creato nessun super_admin abusivo" \
   "$(q "SELECT count(*) FROM utenti WHERE username='testc_super'")" "0"

echo "--- 8. via di recupero: se la mail non arriva, il Reset c'e' ancora ---"
# Si forza il ramo "mail fallita" dentro il container, senza rompere la SMTP dell'ambiente:
# send_email sostituito da un double che risponde False. E' l'unico modo di provare l'avviso,
# perche' postfix accetta comunque il messaggio e il fallimento vero si vedrebbe dopo, in coda
q "DELETE FROM utenti WHERE username='testc_mailguasta';" >/dev/null
OUT=$($SSH "docker exec -i $BE python -" <<'PY' 2>&1 | tr -d '\r'
import json
import app.routers.auth as a
from app.database import SessionLocal
from app.models import Utente

a.send_email = lambda to, subject, body: False          # double: la mail non parte
db = SessionLocal()
admin = db.query(Utente).filter(Utente.username == 'testc_admin@x.local').first()
data = a.UtenteCreate(username='testc_mailguasta', nome='Mail', cognome='Guasta',
                      societa_id=1, ruolo='mister', email='mailguasta@x.local')
try:
    res = a.crea_utente(data=data, current_user=admin, db=db)
    print(json.dumps(res, ensure_ascii=False))
finally:
    db.close()
PY
)
ck "con la mail guasta la creazione riesce comunque" \
   "$(echo "$OUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('ok'))" 2>/dev/null)" "True"
ck "  e avvisa che la mail non e' partita" \
   "$(echo "$OUT" | python3 -c "import sys,json;print('si' if 'non e' in json.load(sys.stdin).get('avviso','') else 'no')" 2>/dev/null)" "si"
ck "  l'account esiste ma non e' utilizzabile finche' non si genera una password" \
   "$(q "SELECT count(*) FROM utenti WHERE username='testc_mailguasta' AND deve_cambiare_password IS TRUE")" "1"
TOK_A=$(tok "$U_ADM" "$P_ADM")
RESP=$(curl -s -w '\n%{http_code}' --max-time 25 -X PUT "$D/auth/utenti/$(q "SELECT id FROM utenti WHERE username='testc_mailguasta'")/reset-password" -H "Authorization: Bearer $TOK_A")
TMP=$(echo "$RESP" | head -n -1 | python3 -c "import sys,json;print(json.load(sys.stdin).get('password_temporanea',''))" 2>/dev/null)
ck "  il Reset gliene genera una, e quella funziona" "$([ -n "$(tok 'testc_mailguasta' "$TMP")" ] && echo si)" "si"

echo "--- pulizia ---"
q "DELETE FROM login_bloccaggi WHERE chiave LIKE '$PULISCI';
   DELETE FROM utenti WHERE username LIKE '$PULISCI';" >/dev/null
ck "nessun residuo" \
   "$(q "SELECT (SELECT count(*) FROM utenti WHERE username LIKE '$PULISCI')+(SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE '$PULISCI')")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
