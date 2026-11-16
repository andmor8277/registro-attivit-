#!/bin/bash
# A1: ora di presentazione precompilata (45' casa / 60' trasferta) e mai azzerata dal PUT.
# Crea solo partite e un utente di prova su DEV, e rimuove tutto alla fine.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }

echo "--- preparazione ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }
CAT1=$(q "SELECT id FROM categorie WHERE societa_id=1 AND is_archiviata=0 ORDER BY id LIMIT 1")
q "DELETE FROM partite WHERE note='__test_a1__';
   DELETE FROM utenti WHERE username='testpartite';" >/dev/null
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testpartite','$HASH',1,1,0,NULL);" >/dev/null
TOK=$(curl -s --max-time 20 -X POST "$D/auth/token" -d "username=testpartite&password=$PW" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
ck "login utente di prova" "$([ -n "$TOK" ] && echo si)" "si"
echo "  categoria di prova = $CAT1"

nuova() {  # nuova <casa_fuori> <ora> -> id
  curl -s --max-time 20 -X POST "$D/partite/" -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
    -d "{\"categoria_id\":$CAT1,\"data_partite\":\"2026-12-05\",\"ora\":\"$2\",\"casa_fuori\":\"$1\",\"note\":\"__test_a1__\"}" \
    | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null
}
pres() { q "SELECT coalesce(ora_presentazione::text,'(null)') FROM partite WHERE id=$1"; }

echo "--- 1. in creazione la presentazione viene precompilata ---"
IDC=$(nuova casa 15:00); IDF=$(nuova fuori 15:00)
ck "casa, gara 15:00 -> presentazione 14:15"  "$(pres $IDC)" "14:15:00"
ck "trasferta, gara 15:00 -> presentazione 14:00" "$(pres $IDF)" "14:00:00"

echo "--- 2. il PUT che non manda il campo NON la azzera (era il bug A1) ---"
curl -s -o /dev/null --max-time 20 -X PUT "$D/partite/$IDC" -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "{\"categoria_id\":$CAT1,\"data_partite\":\"2026-12-05\",\"ora\":\"16:30\",\"casa_fuori\":\"casa\",\"avversario\":\"Prova A1\",\"note\":\"__test_a1__\"}"
ck "PUT senza ora_presentazione: valore conservato" "$(pres $IDC)" "14:15:00"
ck "il PUT ha pero' aggiornato l'altro campo" \
   "$(q "SELECT avversario FROM partite WHERE id=$IDC")" "Prova A1"

echo "--- 3. il PUT che manda il campo lo scrive (editabile) ---"
curl -s -o /dev/null --max-time 20 -X PUT "$D/partite/$IDC" -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "{\"categoria_id\":$CAT1,\"data_partite\":\"2026-12-05\",\"ora\":\"16:30\",\"casa_fuori\":\"casa\",\"ora_presentazione\":\"15:40\",\"note\":\"__test_a1__\"}"
ck "PUT con ora_presentazione 15:40 -> 15:40" "$(pres $IDC)" "15:40:00"

echo "--- 4. svuotarla resta una scelta esplicita ---"
curl -s -o /dev/null --max-time 20 -X PUT "$D/partite/$IDC" -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "{\"categoria_id\":$CAT1,\"data_partite\":\"2026-12-05\",\"ora\":\"16:30\",\"casa_fuori\":\"casa\",\"ora_presentazione\":null,\"note\":\"__test_a1__\"}"
ck "PUT con ora_presentazione null -> null" "$(pres $IDC)" "(null)"

echo "--- 5. PUT senza campo anche su riga che non ce l'ha: precompilata, non lasciata vuota ---"
curl -s -o /dev/null --max-time 20 -X PUT "$D/partite/$IDC" -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
  -d "{\"categoria_id\":$CAT1,\"data_partite\":\"2026-12-05\",\"ora\":\"17:00\",\"casa_fuori\":\"fuori\",\"note\":\"__test_a1__\"}"
ck "riga vuota + PUT senza campo -> 16:00 (60' fuori)" "$(pres $IDC)" "16:00:00"

echo "--- 6. la pagina Convocazioni continua a poterla sovrascrivere ---"
ck "partita di trasferta creata con 14:00" "$(pres $IDF)" "14:00:00"

echo "--- pulizia ---"
q "DELETE FROM partite WHERE note='__test_a1__'; DELETE FROM utenti WHERE username='testpartite';" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM partite WHERE note='__test_a1__')+(SELECT count(*) FROM utenti WHERE username='testpartite')")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
