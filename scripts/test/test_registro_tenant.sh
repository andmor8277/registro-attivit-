#!/bin/bash
# Verifica i controlli di tenant aggiunti a upsert_registro (registro.py).
# Crea su DEV utenti E persone di prova, e cancella solo quelli: nessuna riga reale toccata.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
codice() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X POST "$D/registro/" -H "Content-Type: application/json" ${1:+-H "Authorization: Bearer $1"} -d "$2"; }

echo "--- preparazione: solo oggetti di prova, mai dati reali ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }

GRUPPO_PORT=$(q "SELECT g.id FROM gruppi g JOIN categorie c ON c.id=g.categoria_id WHERE c.societa_id=1 AND lower(g.nome)='portieri' LIMIT 1")
CAT1=$(q "SELECT id FROM categorie WHERE societa_id=1 ORDER BY id LIMIT 1")

q "DELETE FROM registro WHERE persona_id IN (SELECT id FROM persone WHERE cognome='TestTenant');
   DELETE FROM persone WHERE cognome='TestTenant';
   DELETE FROM utenti WHERE username LIKE 'testtenant%';" >/dev/null
q "INSERT INTO persone (societa_id,nome,cognome,categoria_id) VALUES (1,'Normale','TestTenant',$CAT1);
   INSERT INTO persone (societa_id,nome,cognome,categoria_id,gruppo_id) VALUES (1,'Portiere','TestTenant',$CAT1,$GRUPPO_PORT);
   INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testtenantadmin','$HASH',1,1,0,NULL), ('testtenantmister','$HASH',1,0,0,'mister');" >/dev/null
PN=$(q "SELECT id FROM persone WHERE cognome='TestTenant' AND nome='Normale'")
PP=$(q "SELECT id FROM persone WHERE cognome='TestTenant' AND nome='Portiere'")
AID=$(q "SELECT id FROM utenti WHERE username='testtenantadmin'")
MID=$(q "SELECT id FROM utenti WHERE username='testtenantmister'")
q "INSERT INTO utente_categorie (utente_id,categoria_id) VALUES ($MID,20);" >/dev/null
echo "  persone prova: normale=$PN portiere=$PP | utenti: admin=$AID mister=$MID (assegnato solo a cat 20)"

tok() { curl -s --max-time 20 -X POST "$D/auth/token" -d "username=$1&password=$PW" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null; }
TOK_A=$(tok testtenantadmin); TOK_M=$(tok testtenantmister)
ck "login admin di prova"  "$([ -n "$TOK_A" ] && echo si)" "si"
ck "login mister di prova" "$([ -n "$TOK_M" ] && echo si)" "si"

echo "--- 1. scrittura legittima: non deve rompersi ---"
ck "admin su persona e categoria proprie"        "$(codice "$TOK_A" "{\"persona_id\":$PN,\"data\":\"2026-11-16\",\"codice\":\"P\",\"categoria_id\":20}")" "200"
ck "mister sulla categoria a cui e' assegnato"   "$(codice "$TOK_M" "{\"persona_id\":$PN,\"data\":\"2026-11-17\",\"codice\":\"P\",\"categoria_id\":20}")" "200"

echo "--- 2. cross-tenant: deve essere bloccato ---"
ck "admin su persona di altra societa' (id 17)"  "$(codice "$TOK_A" '{"persona_id":17,"data":"2026-11-16","codice":"P","categoria_id":20}')" "403"
ck "admin su categoria di altra societa' (13)"   "$(codice "$TOK_A" "{\"persona_id\":$PN,\"data\":\"2026-11-16\",\"codice\":\"P\",\"categoria_id\":13}")" "403"
# Scelta del titolare 2026-11-16: il mister puo ancora scrivere su una categoria della PROPRIA
# societa' anche se non assegnata (la UI di Scelta.vue gliele mostra tutte via by-stagione).
# Questo caso documenta la policy: se un domani si attiva il check di assegnazione, diventa 403.
ck "mister su categoria propria non assegnata (18) resta ammesso" "$(codice "$TOK_M" "{\"persona_id\":$PN,\"data\":\"2026-11-18\",\"codice\":\"P\",\"categoria_id\":18}")" "200"

echo "--- 3. autenticazione e inesistenti ---"
ck "senza token"                    "$(codice "" "{\"persona_id\":$PN,\"data\":\"2026-11-16\",\"codice\":\"P\",\"categoria_id\":20}")" "401"
ck "persona inesistente -> 404"     "$(codice "$TOK_A" '{"persona_id":999999,"data":"2026-11-16","codice":"P","categoria_id":20}')" "404"
ck "categoria inesistente -> 404"   "$(codice "$TOK_A" "{\"persona_id\":$PN,\"data\":\"2026-11-16\",\"codice\":\"P\",\"categoria_id\":999999}")" "404"

echo "--- 4. DELETE cross-tenant neutralizzata (innesco: portiere + categoria altrui) ---"
ck "innesco redirect con categoria altrui -> 403" "$(codice "$TOK_A" "{\"persona_id\":$PP,\"data\":\"2026-11-19\",\"codice\":\"P\",\"categoria_id\":13}")" "403"
ck "nessuna riga creata sulla categoria altrui"   "$(q "SELECT count(*) FROM registro WHERE categoria_id=13 AND data='2026-11-19'")" "0"

echo "--- 5. la scrittura buona ha davvero scritto ---"
ck "riga presente nel DB"  "$(q "SELECT count(*) FROM registro WHERE persona_id=$PN AND data='2026-11-16' AND codice='P'")" "1"

echo "--- pulizia (solo gli oggetti di prova) ---"
q "DELETE FROM registro WHERE persona_id IN ($PN,$PP);
   DELETE FROM persone WHERE id IN ($PN,$PP);
   DELETE FROM utente_categorie WHERE utente_id IN ($AID,$MID);
   DELETE FROM utenti WHERE id IN ($AID,$MID);" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM persone WHERE cognome='TestTenant')+(SELECT count(*) FROM utenti WHERE username LIKE 'testtenant%')+(SELECT count(*) FROM registro WHERE persona_id IN ($PN,$PP))")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
