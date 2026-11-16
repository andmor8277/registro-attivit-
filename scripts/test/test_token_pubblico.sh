#!/bin/bash
# Prova end-to-end del token di possesso sul form d'iscrizione (DEV).
# Verifica sia il flusso della famiglia sia che il vecchio accesso per ID sia morto.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }

echo "--- preparazione ---"
CAT=$(q "SELECT id FROM categorie WHERE societa_id IS NOT NULL ORDER BY id LIMIT 1")
echo "  categoria di prova: $CAT"

echo "--- 1. il vecchio accesso per ID deve essere MORTO ---"
ck "GET /persone/public/3 (vecchio)"  "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 $D/persone/public/3)" "404"
ck "PUT /persone/public/3 (vecchio)"  "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X PUT $D/persone/public/3 -H 'Content-Type: application/json' -d '{}')" "404"
ck "GET /persone/public/999999"       "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 $D/persone/public/999999)" "404"

echo "--- 2. la categoria pubblica resta raggiungibile (serve al form) ---"
ck "GET /persone/public/categoria/$CAT" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 $D/persone/public/categoria/$CAT)" "200"

echo "--- 3. creazione (il link 'nuova iscrizione') restituisce il token ---"
CRE=$(curl -s --max-time 20 -X POST $D/persone/public/ -H 'Content-Type: application/json' \
      -d "{\"nome\":\"Test\",\"cognome\":\"Token\",\"categoria_id\":$CAT}")
ID=$(echo "$CRE" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
TOK=$(echo "$CRE" | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
ck "creazione riuscita"        "$(echo $CRE | grep -c '"ok":true')" "1"
ck "id restituito"             "$([ -n "$ID" ] && echo si)" "si"
ck "token restituito"          "$([ -n "$TOK" ] && echo si)" "si"
ck "token lungo (>=32)"        "$([ ${#TOK} -ge 32 ] && echo si)" "si"
echo "  id=$ID  token=${TOK:0:12}… (${#TOK} char)"

echo "--- 4. la famiglia apre il link: GET by-token ---"
G=$(curl -s --max-time 20 "$D/persone/public/by-token/$TOK")
ck "GET by-token 200"          "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 $D/persone/public/by-token/$TOK)" "200"
ck "prefill del nome"          "$(echo "$G" | python3 -c "import sys,json;print(json.load(sys.stdin).get('nome',''))" 2>/dev/null)" "Test"
ck "il CF NON esce da qui"     "$(echo "$G" | grep -c codice_fiscale)" "0"

echo "--- 5. la famiglia salva: PUT by-token ---"
ck "PUT by-token"              "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X PUT "$D/persone/public/by-token/$TOK" -H 'Content-Type: application/json' -d '{"note":"scritto dal token","email1":"fam@prova.it"}')" "200"
ck "il dato e stato salvato"   "$(q "SELECT note FROM persone WHERE id=$ID")" "scritto dal token"

echo "--- 6. token falsi o corti rifiutati ---"
FAKE_A=$(python3 -c "print('a'*40)"); FAKE_B=$(python3 -c "print('b'*43)")
ck "token inesistente"         "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 $D/persone/public/by-token/$FAKE_A)" "404"
ck "token troppo corto"        "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 $D/persone/public/by-token/corto)" "404"
ck "PUT con token inventato"   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X PUT "$D/persone/public/by-token/$FAKE_B" -H 'Content-Type: application/json' -d '{"note":"x"}')" "404"

echo "--- 7. token scaduto ---"
q "UPDATE persone SET public_token_scadenza = NOW() - INTERVAL '1 day' WHERE id=$ID" >/dev/null
ck "scaduto risponde 410"      "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 $D/persone/public/by-token/$TOK)" "410"
ck "il PUT scaduto e rifiutato" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X PUT "$D/persone/public/by-token/$TOK" -H 'Content-Type: application/json' -d '{"note":"dopo scadenza"}')" "410"

echo "--- 8. coniare un link richiede l'accesso ---"
ck "POST /persone/$ID/public-link senza token" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X POST $D/persone/$ID/public-link)" "401"

echo "--- pulizia ---"
q "DELETE FROM persone WHERE id=$ID" >/dev/null
ck "riga di prova rimossa"     "$(q "SELECT count(*) FROM persone WHERE id=$ID")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
