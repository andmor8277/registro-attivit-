#!/bin/bash
# Reset password e cambio password: chi puo' fare cosa.
#
# Nasce da due buchi verificati in esecuzione il 2026-11-16:
#  1) reset_password assegnava la DEFAULT_PASSWORD, unica e condivisa: reset + login locale
#     = entrare in qualunque account appena resettato, anche di un utente che entra con Google
#  2) PUT /auth/utenti/{uid}/password NON chiedeva la password vecchia a chi era admin: un
#     admin qualsiasi ne impostava una a scelta su un utente della sua societa' ed entrava
#
# Uso: scripts/test/test_reset_password.sh   (DEV)
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
body() { curl -s --max-time 25 "$@"; }
# --data-urlencode e' obbligatorio, non cosmetico: l'alfabeto delle password temporanee contiene
# &, % e #, e passarli grezzi in un body form fa arrivare al server una password troncata o
# decodificata male. Il primo giro di questo test ha dato 13 falsi fallimenti proprio per questo.
#
# Il retry sul 429 non e' cosmetico: /auth/token ha @limiter.limit("10/minute") e questo file fa
# circa venti login. Senza retry il limiter si presentava come un 401/403 mancante e tre asserzioni
# verdi-diventate-rosse non c'entravano niente con la logica testata. Si distingue il 429 da un
# errore vero proprio per non confondere "rate limit" con "password sbagliata".
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
  echo ""   # ancora 429 dopo 5 tentativi: meglio un token vuoto che un falso positivo
}
loginraw() {
  local out code i
  for i in 1 2 3 4 5; do
    out=$(curl -s -w '\n%{http_code}' --max-time 25 -X POST "$D/auth/token" \
             --data-urlencode "username=$1" --data-urlencode "password=$2")
    code="${out##*$'\n'}"
    if [ "$code" = "429" ]; then sleep 8; continue; fi
    printf '%s' "${out%$'\n'*}"
    return 0
  done
  echo ""
}
hash() { $SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$1'))\"" 2>/dev/null | tr -d '\r' | tail -1; }
json() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }

U_ADM="testpw_admin@x.local"
U_SUP="testpw_super@x.local"
U_LOC="testpw_locale@x.local"
U_GOO="testpw_google@x.local"
# secondo account Google-only, da non toccare nei test del super_admin: se gli si attribuisce una
# password locale, le asserzioni della sezione 9 su accesso_locale non varrebbero piu' nulla
U_GOO2="testpw_google2@x.local"
P_ADM="Adm-$(openssl rand -hex 6)"
P_SUP="Sup-$(openssl rand -hex 6)"
P_LOC="Loc-$(openssl rand -hex 6)"
P_GOO="Goo-$(openssl rand -hex 6)"

H_ADM=$(hash "$P_ADM"); H_SUP=$(hash "$P_SUP"); H_LOC=$(hash "$P_LOC"); H_GOO=$(hash "$P_GOO")
for coppia in "admin:$H_ADM" "super:$H_SUP" "locale:$H_LOC" "google:$H_GOO"; do
  [ -z "${coppia#*:}" ] && { echo "  impossibile generare l'hash di ${coppia%%:*}: annullato"; exit 1; }
done

echo "--- preparazione: 4 utenti, due con password locale e due no ---"
q "DELETE FROM utenti WHERE username IN ('$U_ADM','$U_SUP','$U_LOC','$U_GOO','$U_GOO2');
   INSERT INTO utenti (username,password_hash,google_sub,societa_id,is_admin,is_super_admin,ruolo,nome,cognome)
   VALUES ('$U_ADM','$H_ADM',NULL,1,1,0,'admin','Admin','Test'),
          ('$U_SUP','$H_SUP',NULL,1,1,1,'super_admin','Super','Test'),
          ('$U_LOC','$H_LOC',NULL,1,0,0,'mister','Locale','Test'),
          ('$U_GOO',NULL,'GOOGLE-SUB-PROVA',1,0,0,'mister','Google','Test'),
          ('$U_GOO2',NULL,'GOOGLE-SUB-PROVA-2',1,0,0,'mister','Google2','Test');" >/dev/null
ck "utenti creati" "$(q "SELECT count(*) FROM utenti WHERE username LIKE 'testpw@%' OR username LIKE 'testpw_%'")" "5"
ck "l'utente Google-only non ha password locale" \
   "$(q "SELECT count(*) FROM utenti WHERE username='$U_GOO' AND password_hash IS NULL")" "1"
ID_LOC=$(q "SELECT id FROM utenti WHERE username='$U_LOC'")
ID_GOO=$(q "SELECT id FROM utenti WHERE username='$U_GOO'")

TOK_ADM=$(tok "$U_ADM" "$P_ADM"); TOK_SUP=$(tok "$U_SUP" "$P_SUP"); TOK_LOC=$(tok "$U_LOC" "$P_LOC")
ck "login admin -> token"        "$([ -n "$TOK_ADM" ] && echo si)" "si"
ck "login super_admin -> token"  "$([ -n "$TOK_SUP" ] && echo si)" "si"
ck "login utente locale -> token" "$([ -n "$TOK_LOC" ] && echo si)" "si"

echo "--- 1. il reset su un account Google-only e' rifiutato a un admin ---"
# Una chiamata sola per sezione: la rotta ha @limiter.limit("5/minute") e sei chiamate in un
# minuto le avrebbero fatte diventare 429, con un test verde per il motivo sbagliato
RESP=$(curl -s -w '\n%{http_code}' --max-time 25 -X PUT "$D/auth/utenti/$ID_GOO/reset-password" -H "Authorization: Bearer $TOK_ADM")
CODICE=${RESP##*$'\n'}
R=${RESP%$'\n'*}
ck "admin resetta un utente Google -> 403" "$CODICE" "403"
ck "  e il motivo dice che accede con Google" \
   "$(echo "$R" | grep -ci "google")" "1"
ck "  l'utente NON ha ricevuto una password" \
   "$(q "SELECT count(*) FROM utenti WHERE username='$U_GOO' AND password_hash IS NOT NULL")" "0"

echo "--- 2. il reset su un account locale genera una password propria, non quella condivisa ---"
# Una sola chiamata: estrarre il body e poi rifare la stessa richiesta per il codice significherebbe
# generare una SECONDA password temporanea, e le asserzioni sotto verificherebbero un valore gia'
# sostituito da quella chiamata
RESP=$(curl -s -w '\n%{http_code}' --max-time 25 -X PUT "$D/auth/utenti/$ID_LOC/reset-password" -H "Authorization: Bearer $TOK_ADM")
CODICE=${RESP##*$'\n'}
R=${RESP%$'\n'*}
ck "admin resetta un utente con password -> 200" "$CODICE" "200"
T1=$(echo "$R" | python3 -c "import sys,json;print(json.load(sys.stdin).get('password_temporanea',''))" 2>/dev/null)
ck "  la risposta contiene password_temporanea" "$([ -n "$T1" ] && echo si)" "si"
ck "  e' lunga almeno 12 caratteri" "$([ ${#T1} -ge 12 ] && echo si)" "si"
DEF=$($SSH "sed -n 's/^DEFAULT_PASSWORD=//p' /opt/registro_presenze/.env | head -1" | tr -d '\r\n')
ck "la vecchia default condivisa NON viene piu' usata" \
   "$([ -n "$DEF" ] && [ "$T1" != "$DEF" ] && echo si)" "si"
ck "  la password precedente dell'utente non funziona piu'" \
   "$([ -z "$(tok "$U_LOC" "$P_LOC")" ] && echo si)" "si"
ck "  quella temporanea si'" "$([ -n "$(tok "$U_LOC" "$T1")" ] && echo si)" "si"

echo "--- 3. due reset dello stesso utente danno password diverse (non e' un valore fisso) ---"
T2=$(body -X PUT "$D/auth/utenti/$ID_LOC/reset-password" -H "Authorization: Bearer $TOK_ADM" \
     | python3 -c "import sys,json;print(json.load(sys.stdin).get('password_temporanea',''))" 2>/dev/null)
ck "la seconda reset genera un valore diverso" "$([ -n "$T2" ] && [ "$T1" != "$T2" ] && echo si)" "si"
ck "  e la prima non funziona piu'" "$([ -z "$(tok "$U_LOC" "$T1")" ] && echo si)" "si"

echo "--- 4. con la password temporanea l'app e' bloccata finche' non la cambi ---"
TOK_T=$(tok "$U_LOC" "$T2")
ck "login con la temporanea -> token" "$([ -n "$TOK_T" ] && echo si)" "si"
ck "  GET /persone/ -> 403" "$(cod "$D/persone/" -H "Authorization: Bearer $TOK_T")" "403"
ck "  e il 403 porta il codice PASSWORD_DA_CAMBIARE" \
   "$(body "$D/persone/" -H "Authorization: Bearer $TOK_T" | grep -c PASSWORD_DA_CAMBIARE)" "1"
ck "  GET /auth/me invece passa (serve al frontend per aprirsi)" \
   "$(cod "$D/auth/me" -H "Authorization: Bearer $TOK_T")" "200"
ck "  e /auth/me dice che la password va cambiata" \
   "$(body "$D/auth/me" -H "Authorization: Bearer $TOK_T" | grep -c '"deve_cambiare_password": *true')" "1"
ck "  un token normale invece non e' toccato dal blocco" \
   "$(cod "$D/persone/" -H "Authorization: Bearer $TOK_ADM")" "200"

echo "--- 5. il cambio della propria password toglie il blocco ---"
NUOVA="Cambiata-$(openssl rand -hex 4)!"
ck "PUT /auth/utenti/{proprio}/password con la temporanea -> 200" \
   "$(cod -X PUT "$D/auth/utenti/$ID_LOC/password" -H "Authorization: Bearer $TOK_T" \
        -H "Content-Type: application/json" -d "{\"vecchia\":\"$T2\",\"nuova\":\"$NUOVA\"}")" "200"
TOK_N=$(tok "$U_LOC" "$NUOVA")
ck "  login con la nuova -> token" "$([ -n "$TOK_N" ] && echo si)" "si"
ck "  e ora legge i dati (403 rimosso)" "$(cod "$D/persone/" -H "Authorization: Bearer $TOK_N")" "200"
ck "  /auth/me non chiede piu' il cambio" \
   "$(body "$D/auth/me" -H "Authorization: Bearer $TOK_N" | grep -c '"deve_cambiare_password": *true')" "0"
ck "  la temporanea non funziona piu'" "$([ -z "$(tok "$U_LOC" "$T2")" ] && echo si)" "si"

echo "--- 6. la porta grossa: un admin non puo' piu' impostare la password di un altro ---"
VITTIMA="testpw_vittima@x.local"; P_VIT="Vittima-$(openssl rand -hex 6)"; H_VIT=$(hash "$P_VIT")
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo,nome,cognome)
   VALUES ('$VITTIMA','$H_VIT',1,0,0,'mister','Vittima','Test');" >/dev/null
ID_VIT=$(q "SELECT id FROM utenti WHERE username='$VITTIMA'")
ck "la vittima entra con la SUA password" "$([ -n "$(tok "$VITTIMA" "$P_VIT")" ] && echo si)" "si"
ck "admin prova a impostare la password della vittima -> 403" \
   "$(cod -X PUT "$D/auth/utenti/$ID_VIT/password" -H "Authorization: Bearer $TOK_ADM" \
        -H "Content-Type: application/json" -d '{"nuova":"ImpostaDallAdmin-1!"}')" "403"
ck "  e la password della vittima funziona ancora (nessuna scrittura avvenuta)" \
   "$([ -n "$(tok "$VITTIMA" "$P_VIT")" ] && echo si)" "si"
ck "  nemmeno il super_admin puo' cambiare la password di un altro" \
   "$(cod -X PUT "$D/auth/utenti/$ID_VIT/password" -H "Authorization: Bearer $TOK_SUP" \
        -H "Content-Type: application/json" -d '{"nuova":"ImpostaDalSuper-1!"}')" "403"
ck "un mister non puo' cambiare la password di un altro mister -> 403" \
   "$(cod -X PUT "$D/auth/utenti/$ID_VIT/password" -H "Authorization: Bearer $TOK_N" \
        -H "Content-Type: application/json" -d '{"nuova":"Qualcosa-1!aA"}')" "403"
ck "cambiare la propria password SENZA la vecchia -> 400" \
   "$(cod -X PUT "$D/auth/utenti/$ID_LOC/password" -H "Authorization: Bearer $TOK_N" \
        -H "Content-Type: application/json" -d '{"nuova":"Debole"}')" "400"

echo "--- 7. eccezione voluta: il super_admin puo' dare una via locale a un account Google ---"
RESP=$(curl -s -w '\n%{http_code}' --max-time 25 -X PUT "$D/auth/utenti/$ID_GOO/reset-password" -H "Authorization: Bearer $TOK_SUP")
CODICE=${RESP##*$'\n'}
R=${RESP%$'\n'*}
ck "super_admin resetta l'utente Google-only -> 200" "$CODICE" "200"
T3=$(echo "$R" | python3 -c "import sys,json;print(json.load(sys.stdin).get('password_temporanea',''))" 2>/dev/null)
ck "  riceve una password temporanea" "$([ -n "$T3" ] && echo si)" "si"
ck "  e dovra' cambiarla anche lui" \
   "$(cod "$D/persone/" -H "Authorization: Bearer $(tok "$U_GOO" "$T3")")" "403"

echo "--- 8. il login espone il flag, per aprire il modal al primo accesso ---"
ck "login normale: deve_cambiare_password false" \
   "$(loginraw "$U_ADM" "$P_ADM" | grep -c '"deve_cambiare_password": *false')" "1"
ck "login con temporanea: deve_cambiare_password true" \
   "$(loginraw "$U_GOO" "$T3" | grep -c '"deve_cambiare_password": *true')" "1"

echo "--- 9. la lista utenti dice alla UI quali account hanno una via locale ---"
L=$(body "$D/auth/utenti" -H "Authorization: Bearer $TOK_ADM")
ck "l'utente Google risulta accesso_locale false" \
   "$(echo "$L" | python3 -c "
import sys,json
u=[x for x in json.load(sys.stdin) if x['username']=='$U_GOO2']
print('si' if u and u[0].get('accesso_locale') is False else 'no')")" "si"
ck "l'utente locale risulta accesso_locale true" \
   "$(echo "$L" | python3 -c "
import sys,json
u=[x for x in json.load(sys.stdin) if x['username']=='$U_LOC']
print('si' if u and u[0].get('accesso_locale') is True else 'no')")" "si"
ck "  e il campo password_hash non esce mai dalla lista" \
   "$(echo "$L" | grep -c 'password_hash')" "0"

echo "--- pulizia ---"
q "DELETE FROM login_bloccaggi WHERE chiave LIKE 'testpw%';
   DELETE FROM utenti WHERE username LIKE 'testpw_%';" >/dev/null
ck "nessun residuo" \
   "$(q "SELECT (SELECT count(*) FROM utenti WHERE username LIKE 'testpw_%')+(SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'testpw%')")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
