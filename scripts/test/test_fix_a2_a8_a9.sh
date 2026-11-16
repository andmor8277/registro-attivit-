#!/bin/bash
# Verifica i fix A2 (cross-tenant categorie), A8 (svuotamento campi persona),
# A9 (infortuni: campi svuotabili + data_fine coerente).
# Crea solo oggetti di prova marcati __test_fix__ / testfix e rimuove quelli.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X "$1" "$D$2" -H "Content-Type: application/json" ${3:+-H "Authorization: Bearer $3"} ${4:+-d "$4"}; }

echo "--- preparazione (solo oggetti di prova) ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }

q "DELETE FROM infortuni WHERE note LIKE '__test_fix%';
   DELETE FROM registro WHERE persona_id IN (SELECT id FROM persone WHERE cognome='TestFix');
   DELETE FROM persone WHERE cognome='TestFix';
   DELETE FROM utente_categorie WHERE categoria_id IN (SELECT id FROM categorie WHERE nome='__test_fix__');
   DELETE FROM categorie WHERE nome='__test_fix__';
   DELETE FROM utenti WHERE username LIKE 'testfix%';" >/dev/null

# categoria di prova con anno 1900: nessuna categoria archiviata ha quell'anno, quindi
# importa-giocatori sul percorso legittimo non trova nulla e non tocca dati reali
q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES (1,'__test_fix__',1900,0);" >/dev/null
CATP=$(q "SELECT id FROM categorie WHERE nome='__test_fix__'")
q "INSERT INTO persone (societa_id,nome,cognome,categoria_id) VALUES (1,'Fissa','TestFix',$CATP);" >/dev/null
PN=$(q "SELECT id FROM persone WHERE cognome='TestFix'")
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testfix_a','$HASH',1,1,0,'admin'),('testfix_b','$HASH',2,1,0,'admin');" >/dev/null
AID=$(q "SELECT id FROM utenti WHERE username='testfix_a'")
BID=$(q "SELECT id FROM utenti WHERE username='testfix_b'")
CAT_SOC2=$(q "SELECT id FROM categorie WHERE societa_id=2 ORDER BY id LIMIT 1")
[ -z "$CATP" ] || [ -z "$PN" ] || [ -z "$CAT_SOC2" ] && { echo "  preparazione fallita (cat=$CATP persona=$PN cat_soc2=$CAT_SOC2)"; exit 1; }
echo "  cat prova=$CATP  persona=$PN  cat altra soc=$CAT_SOC2  utenti: A(soc1)=$AID B(soc2)=$BID"

TOKA=$(curl -s --max-time 20 -X POST "$D/auth/token" -d "username=testfix_a&password=$PW" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
ck "login admin societa' 1" "$([ -n "$TOKA" ] && echo si)" "si"

echo "--- A2.1 PUT /categorie/{id}/utenti ---"
PRIMA_SOC2=$(q "SELECT count(*) FROM utente_categorie WHERE categoria_id=$CAT_SOC2")
ck "flusso legittimo: assegna utente della propria societa'" "$(cod PUT "/categorie/$CATP/utenti" "$TOKA" '{"utente_ids":['"$AID"']}')" "200"
ck "  l'assegnazione risulta nel DB" "$(q "SELECT count(*) FROM utente_categorie WHERE categoria_id=$CATP AND utente_id=$AID")" "1"
ck "categoria di un'altra societa' -> 403" "$(cod PUT "/categorie/$CAT_SOC2/utenti" "$TOKA" '{"utente_ids":['"$AID"']}')" "403"
ck "  le assegnazioni dell'altra societa' sono intatte ($PRIMA_SOC2)" "$(q "SELECT count(*) FROM utente_categorie WHERE categoria_id=$CAT_SOC2")" "$PRIMA_SOC2"
ck "utente di un'altra societa' -> 403" "$(cod PUT "/categorie/$CATP/utenti" "$TOKA" '{"utente_ids":['"$BID"']}')" "403"
ck "  nessun estraneo assegnato alla categoria di prova" "$(q "SELECT count(*) FROM utente_categorie WHERE categoria_id=$CATP AND utente_id=$BID")" "0"
ck "  dopo il 403 l'assegnazione legittima e' ancora li'" "$(q "SELECT count(*) FROM utente_categorie WHERE categoria_id=$CATP AND utente_id=$AID")" "1"
ck "categoria inesistente -> 404" "$(cod PUT "/categorie/999999/utenti" "$TOKA" '{"utente_ids":[]}')" "404"

echo "--- A2.2 POST /categorie/importa-giocatori/{id} ---"
ck "categoria di un'altra societa' -> 403" "$(cod POST "/categorie/importa-giocatori/$CAT_SOC2" "$TOKA" '{}')" "403"
ck "categoria propria -> 200 (flusso legittimo)" "$(cod POST "/categorie/importa-giocatori/$CATP" "$TOKA" '{}')" "200"
ck "nessuna persona importata da altre societa'" "$(q "SELECT count(*) FROM persone WHERE cognome='Test' AND societa_id=1")" "0"

echo "--- A8 PUT /persone/{id}: campi svuotabili, PUT parziale sicuro ---"
ck "imposta note"                          "$(cod PUT "/persone/$PN" "$TOKA" '{"note":"prova-note"}')" "200"
ck "  note nel DB"                          "$(q "SELECT note FROM persone WHERE id=$PN")" "prova-note"
ck "PUT parziale su una rata -> 200"        "$(cod PUT "/persone/$PN" "$TOKA" '{"rata1":50}')" "200"
ck "  rata1 scritta"                         "$(q "SELECT rata1::text FROM persone WHERE id=$PN")" "50"
ck "  la nota NON e' stata azzerata dal PUT parziale" "$(q "SELECT note FROM persone WHERE id=$PN")" "prova-note"
ck "PUT con note:null -> 200"               "$(cod PUT "/persone/$PN" "$TOKA" '{"note":null}')" "200"
ck "  la nota e' stata davvero svuotata"     "$(q "SELECT coalesce(note,'(null)') FROM persone WHERE id=$PN")" "(null)"
ck "  rata1 ancora intatta dopo lo svuotamento" "$(q "SELECT rata1::text FROM persone WHERE id=$PN")" "50"
ck "persona di altra societa' -> 403"       "$(cod PUT "/persone/17" "$TOKA" '{"note":"x"}')" "403"

echo "--- A9 PUT /infortuni/{id}: data_fine coerente e campi svuotabili ---"
IID=$(curl -s --max-time 20 -X POST "$D/infortuni/" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKA" \
  -d "{\"persona_id\":$PN,\"categoria_id\":$CATP,\"data_inizio\":\"2026-11-01\",\"giorni_assenza\":10,\"note\":\"__test_fix__\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
[ -z "$IID" ] && { echo "  creazione infortunio fallita"; exit 1; }
df() { q "SELECT coalesce(data_fine::text,'(null)') FROM infortuni WHERE id=$IID"; }
ga() { q "SELECT coalesce(giorni_assenza::text,'(null)') FROM infortuni WHERE id=$IID"; }
ck "creato con data_fine = inizio+10g"      "$(df)" "2026-11-11"
ck "PUT con solo data_inizio -> 200"         "$(cod PUT "/infortuni/$IID" "$TOKA" '{"data_inizio":"2026-12-01"}')" "200"
ck "  data_fine ricalcolata (prima restava vecchia)" "$(df)" "2026-12-11"
ck "PUT con giorni_assenza:0 -> 200"         "$(cod PUT "/infortuni/$IID" "$TOKA" '{"giorni_assenza":0}')" "200"
ck "  giorni azzerati (prima restavano 10)"   "$(ga)" "0"
ck "  data_fine annullata con 0 giorni"        "$(df)" "(null)"
ck "PUT con note:null svuota le note"         "$(cod PUT "/infortuni/$IID" "$TOKA" '{"note":null}')" "200"
ck "  note nel DB"                            "$(q "SELECT coalesce(note,'(null)') FROM infortuni WHERE id=$IID")" "(null)"
ck "PUT senza alcun campo -> 200 (no-op)"     "$(cod PUT "/infortuni/$IID" "$TOKA" '{}')" "200"
# isolamento cross-tenant: deve restare 403 anche dopo l'allineamento dei codici di stato
TOKB=$(curl -s --max-time 20 -X POST "$D/auth/token" -d "username=testfix_b&password=$PW" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
IID_B=$(curl -s --max-time 20 -X POST "$D/infortuni/" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKB" \
  -d "{\"persona_id\":17,\"categoria_id\":$CAT_SOC2,\"data_inizio\":\"2026-11-01\",\"giorni_assenza\":5,\"note\":\"__test_fix_b__\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
ck "infortunio di altra societa' -> 403 (non 404)" "$(cod PUT "/infortuni/$IID_B" "$TOKA" '{"note":"manomesso"}')" "403"
ck "  la nota dell'altro infortunio e' intatta"     "$(q "SELECT note FROM infortuni WHERE id=$IID_B")" "__test_fix_b__"
ck "infortunio inesistente -> 404"            "$(cod PUT "/infortuni/999999" "$TOKA" '{"note":"x"}')" "404"

echo "--- pulizia ---"
q "DELETE FROM infortuni WHERE id IN ($IID,$IID_B);
   DELETE FROM registro WHERE persona_id=$PN;
   DELETE FROM persone WHERE id=$PN;
   DELETE FROM utente_categorie WHERE categoria_id=$CATP;
   DELETE FROM categorie WHERE id=$CATP;
   DELETE FROM utenti WHERE id IN ($AID,$BID);" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM persone WHERE cognome='TestFix')+(SELECT count(*) FROM categorie WHERE nome='__test_fix__')+(SELECT count(*) FROM utenti WHERE username LIKE 'testfix%')+(SELECT count(*) FROM infortuni WHERE id IN ($IID,$IID_B))")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
