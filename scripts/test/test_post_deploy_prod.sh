#!/bin/bash
# Verifiche post-deploy su PROD per A1 (ora presentazione), A2 (confine societa' categorie),
# A8 (svuotamento campi persona), A9 (infortuni). Crea solo oggetti di prova marcati
# __test_fix__ / testprod e li rimuove alla fine.
P=https://thof.crickethouse.mywire.org/api
SSH="ssh -i $HOME/.ssh/id_ed25519_prod -o ConnectTimeout=15 root@192.168.178.132"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
# Soglia minima assoluta su una tabella: non deve seguire la crescita del DB (altrimenti scade come
# scadiva il "2961" scritto a mano), deve solo stare molto sopra zero. Un ripristino da un dump
# vuoto, o un deploy che ricrea lo schema da zero, la fanno scattare; l'uso normale no.
ckmin() { local n; n=$(q "SELECT count(*) FROM $2"); if [ -n "$n" ] && [ "$n" -ge "$3" ]; then pass=$((pass+1)); echo "  ok   $1 (>= $3, ora $n)"; else fail=$((fail+1)); echo "  FAIL $1 -> $n, sotto la soglia $3"; fi; }
cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X "$1" "$P$2" -H "Content-Type: application/json" ${3:+-H "Authorization: Bearer $3"} ${4:+-d "$4"}; }

echo "--- preparazione (solo oggetti di prova) ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }

q "DELETE FROM infortuni WHERE note LIKE '__test_fix%';
   DELETE FROM partite WHERE note='__test_fix__';
   DELETE FROM registro WHERE persona_id IN (SELECT id FROM persone WHERE cognome='TestProd');
   DELETE FROM persone WHERE cognome='TestProd';
   DELETE FROM utente_categorie WHERE categoria_id IN (SELECT id FROM categorie WHERE nome='__test_fix__');
   DELETE FROM categorie WHERE nome='__test_fix__';
   DELETE FROM utenti WHERE username LIKE 'testprod%';" >/dev/null
# Baseline misurata ADESSO, dopo la pulizia dei residui e prima di creare gli oggetti di prova.
# Prima c'era "registro = 2961" scritto a mano: il conteggio di un deploy di novembre, reso a mano.
# Quattro giorni di presenze reali lo hanno portato a 3154 e il test era rosso senza che fosse
# rotto niente. Un conteggio assoluto di un DB in uso scade alla prima iscrizione vera.
# Sotto pero' restano dei minimi assoluti: la sola invarianza non vede un DB gia' svuotato.
PRIMA_REGISTRO=$(q "SELECT count(*) FROM registro")
PRIMA_PERSONE=$(q "SELECT count(*) FROM persone")
PRIMA_UTENTI=$(q "SELECT count(*) FROM utenti")
PRIMA_CAT=$(q "SELECT count(*) FROM categorie")
PRIMA_INF=$(q "SELECT count(*) FROM infortuni")
echo "  baseline di questa esecuzione: registro=$PRIMA_REGISTRO persone=$PRIMA_PERSONE utenti=$PRIMA_UTENTI categorie=$PRIMA_CAT infortuni=$PRIMA_INF"
q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES (1,'__test_fix__',1900,0);" >/dev/null
CATP=$(q "SELECT id FROM categorie WHERE nome='__test_fix__'")
q "INSERT INTO persone (societa_id,nome,cognome,categoria_id) VALUES (1,'Prova','TestProd',$CATP);" >/dev/null
PN=$(q "SELECT id FROM persone WHERE cognome='TestProd'")
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testprod_a','$HASH',1,1,0,'admin'),('testprod_b','$HASH',2,1,0,'admin');" >/dev/null
AID=$(q "SELECT id FROM utenti WHERE username='testprod_a'")
BID=$(q "SELECT id FROM utenti WHERE username='testprod_b'")
CAT_SOC2=$(q "SELECT id FROM categorie WHERE societa_id=2 ORDER BY id LIMIT 1")
[ -z "$CATP" ] || [ -z "$PN" ] && { echo "  preparazione fallita (cat=$CATP persona=$PN)"; exit 1; }
echo "  cat prova=$CATP persona=$PN cat altra soc=$CAT_SOC2 utenti A(soc1)=$AID B(soc2)=$BID"

tok() { curl -s --max-time 20 -X POST "$P/auth/token" -d "username=$1&password=$PW" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null; }
TOKA=$(tok testprod_a); TOKB=$(tok testprod_b)
ck "login admin prova soc1" "$([ -n "$TOKA" ] && echo si)" "si"
ck "login admin prova soc2" "$([ -n "$TOKB" ] && echo si)" "si"

echo "--- A1 ora di presentazione ---"
IDC=$(curl -s --max-time 20 -X POST "$P/partite/" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKA" \
  -d "{\"categoria_id\":$CATP,\"data_partite\":\"2026-12-05\",\"ora\":\"15:00\",\"casa_fuori\":\"casa\",\"note\":\"__test_fix__\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
IDF=$(curl -s --max-time 20 -X POST "$P/partite/" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKA" \
  -d "{\"categoria_id\":$CATP,\"data_partite\":\"2026-12-06\",\"ora\":\"15:00\",\"casa_fuori\":\"fuori\",\"note\":\"__test_fix__\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
ck "casa 15:00 -> presentazione 14:15"     "$(q "SELECT coalesce(ora_presentazione::text,'(null)') FROM partite WHERE id=$IDC")" "14:15:00"
ck "trasferta 15:00 -> presentazione 14:00" "$(q "SELECT coalesce(ora_presentazione::text,'(null)') FROM partite WHERE id=$IDF")" "14:00:00"
ck "PUT senza il campo -> 200"              "$(cod PUT "/partite/$IDC" "$TOKA" "{\"categoria_id\":$CATP,\"data_partite\":\"2026-12-05\",\"ora\":\"16:30\",\"casa_fuori\":\"casa\",\"note\":\"__test_fix__\"}")" "200"
ck "  la presentazione NON e' stata azzerata" "$(q "SELECT coalesce(ora_presentazione::text,'(null)') FROM partite WHERE id=$IDC")" "14:15:00"
ck "PUT con presentazione 15:40 (editabile)" "$(cod PUT "/partite/$IDC" "$TOKA" "{\"categoria_id\":$CATP,\"data_partite\":\"2026-12-05\",\"ora\":\"16:30\",\"casa_fuori\":\"casa\",\"ora_presentazione\":\"15:40\",\"note\":\"__test_fix__\"}")" "200"
ck "  valore scritto"                         "$(q "SELECT coalesce(ora_presentazione::text,'(null)') FROM partite WHERE id=$IDC")" "15:40:00"

echo "--- A2 confine di societa' su categorie ---"
PRIMA_SOC2=$(q "SELECT count(*) FROM utente_categorie WHERE categoria_id=$CAT_SOC2")
ck "flusso legittimo: assegna utente della propria societa'" "$(cod PUT "/categorie/$CATP/utenti" "$TOKA" '{"utente_ids":['"$AID"']}')" "200"
ck "categoria di altra societa' -> 403" "$(cod PUT "/categorie/$CAT_SOC2/utenti" "$TOKA" '{"utente_ids":['"$AID"']}')" "403"
ck "  assegnazioni altra societa' intatte ($PRIMA_SOC2)" "$(q "SELECT count(*) FROM utente_categorie WHERE categoria_id=$CAT_SOC2")" "$PRIMA_SOC2"
ck "utente di altra societa' -> 403"   "$(cod PUT "/categorie/$CATP/utenti" "$TOKA" '{"utente_ids":['"$BID"']}')" "403"
ck "  dopo il 403 l'assegnazione legittima resta" "$(q "SELECT count(*) FROM utente_categorie WHERE categoria_id=$CATP AND utente_id=$AID")" "1"
ck "importa-giocatori su categoria altrui -> 403" "$(cod POST "/categorie/importa-giocatori/$CAT_SOC2" "$TOKA" '{}')" "403"
ck "importa-giocatori su categoria propria -> 200" "$(cod POST "/categorie/importa-giocatori/$CATP" "$TOKA" '{}')" "200"
ck "categoria inesistente -> 404"       "$(cod PUT "/categorie/999999/utenti" "$TOKA" '{"utente_ids":[]}')" "404"

echo "--- A8 PUT /persone: svuotamento e PUT parziale ---"
ck "imposta note"                    "$(cod PUT "/persone/$PN" "$TOKA" '{"note":"prova-prod"}')" "200"
ck "  note nel DB"                    "$(q "SELECT note FROM persone WHERE id=$PN")" "prova-prod"
ck "PUT parziale su una rata -> 200"  "$(cod PUT "/persone/$PN" "$TOKA" '{"rata1":50}')" "200"
ck "  nota non azzerata dal PUT parziale" "$(q "SELECT note FROM persone WHERE id=$PN")" "prova-prod"
ck "PUT con note:null -> 200"         "$(cod PUT "/persone/$PN" "$TOKA" '{"note":null}')" "200"
ck "  nota davvero svuotata"           "$(q "SELECT coalesce(note,'(null)') FROM persone WHERE id=$PN")" "(null)"
ck "  rata1 intatta"                   "$(q "SELECT rata1::text FROM persone WHERE id=$PN")" "50"
ck "persona di altra societa' -> 403" "$(cod PUT "/persone/17" "$TOKA" '{"note":"x"}')" "403"

echo "--- A9 PUT /infortuni ---"
IID=$(curl -s --max-time 20 -X POST "$P/infortuni/" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKA" \
  -d "{\"persona_id\":$PN,\"categoria_id\":$CATP,\"data_inizio\":\"2026-11-01\",\"giorni_assenza\":10,\"note\":\"__test_fix__\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
df() { q "SELECT coalesce(data_fine::text,'(null)') FROM infortuni WHERE id=$IID"; }
ck "creato con data_fine = inizio+10g"  "$(df)" "2026-11-11"
ck "PUT con solo data_inizio -> 200"     "$(cod PUT "/infortuni/$IID" "$TOKA" '{"data_inizio":"2026-12-01"}')" "200"
ck "  data_fine ricalcolata"              "$(df)" "2026-12-11"
ck "PUT giorni_assenza:0 -> data_fine null" "$(cod PUT "/infortuni/$IID" "$TOKA" '{"giorni_assenza":0}')" "200"
ck "  data_fine annullata"                 "$(df)" "(null)"
ck "PUT note:null svuota"                 "$(cod PUT "/infortuni/$IID" "$TOKA" '{"note":null}')" "200"
ck "infortunio inesistente -> 404"        "$(cod PUT "/infortuni/999999" "$TOKA" '{"note":"x"}')" "404"
IID_B=$(curl -s --max-time 20 -X POST "$P/infortuni/" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKB" \
  -d "{\"persona_id\":17,\"categoria_id\":$CAT_SOC2,\"data_inizio\":\"2026-11-01\",\"giorni_assenza\":5,\"note\":\"__test_fix_b__\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
ck "infortunio di altra societa' -> 403"  "$(cod PUT "/infortuni/$IID_B" "$TOKA" '{"note":"manomesso"}')" "403"
ck "  nota dell'altro infortunio intatta"   "$(q "SELECT note FROM infortuni WHERE id=$IID_B")" "__test_fix_b__"

echo "--- invariati: sicurezza e sito ---"
for ep in "/" "/login" "/form-iscrizione"; do
  ck "GET $ep" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://thof.crickethouse.mywire.org$ep")" "200"
done
for ep in "/api/docs" "/api/openapi.json" "/api/redoc"; do
  ck "GET $ep bloccato" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://thof.crickethouse.mywire.org$ep")" "404"
done
ck "GET /api/auth/me senza token" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$P/auth/me")" "401"
ck "GET /api/persone/public/by-token/errato -> 4xx" "$(cod GET "/persone/public/by-token/inesistente" "" "")" "404"

echo "--- conteggi DB: invarianza + gli incrementi portati dal test ---"
# registro lo scrive chiunque faccia un accesso su PROD: pretenderlo IDENTICO a prima fa fallire il
# test perche' qualcuno ha usato il sito mentre girava. Si verifica il verso che conta, che il test non
# ne abbia cancellate (il "non ha aggiunto" lo dice il conteggio dei residui di prova)
ckmin "registro non ha perso righe (baseline $PRIMA_REGISTRO)" registro "$PRIMA_REGISTRO"
ck "persone = baseline + 1 di prova"            "$(q "SELECT count(*) FROM persone")"  "$((PRIMA_PERSONE + 1))"
ck "utenti = baseline + 2 di prova"             "$(q "SELECT count(*) FROM utenti")"   "$((PRIMA_UTENTI + 2))"
ck "categorie = baseline + 1 di prova"          "$(q "SELECT count(*) FROM categorie")" "$((PRIMA_CAT + 1))"
echo "--- minimi assoluti: questi si' che accorgono di un DB svuotato dal deploy ---"
ckmin "registro popolato"        registro 1000
ckmin "persone popolate"         persone     50
ckmin "categorie popolate"       categorie   10
ckmin "utenti presenti"          utenti      10
ckmin "almeno una lista torneo"  liste_torneo 1

echo "--- pulizia ---"
q "DELETE FROM infortuni WHERE id IN ($IID,$IID_B);
   DELETE FROM partite WHERE id IN ($IDC,$IDF);
   DELETE FROM registro WHERE persona_id=$PN;
   DELETE FROM persone WHERE id=$PN;
   DELETE FROM utente_categorie WHERE categoria_id=$CATP;
   DELETE FROM categorie WHERE id=$CATP;
   DELETE FROM utenti WHERE id IN ($AID,$BID);" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM persone WHERE cognome='TestProd')+(SELECT count(*) FROM categorie WHERE nome='__test_fix__')+(SELECT count(*) FROM utenti WHERE username LIKE 'testprod%')+(SELECT count(*) FROM infortuni WHERE id IN ($IID,$IID_B))+(SELECT count(*) FROM partite WHERE note='__test_fix__')")" "0"
# registro NON va in questo confronto: lo scrive chiunque faccia un accesso su PROD mentre il test
# gira. Misurato il 23/11/2026: baseline 3207, il test finisce con 3210 e a fine serata era 3214, con
# le presenze di ragazzi reali (persone 127-136) scritte durante l'esecuzione. E' la stessa regola gia'
# applicata a riga 125 e in test_login_guard_prod.sh: la tabella la verifica chi usa il sito, quindi si
# chiede il verso che conta - che il test non l'abbia VUOTATA. Il "non ha lasciato righe sue" lo dicono
# l'DELETE qui sopra e l'asserzione sui residui di prova, che e' per pattern e non dipende dal mondo.
ck "conteggi tornati alla baseline (persone/utenti/categorie/infortuni)" \
   "$(q "SELECT (SELECT count(*) FROM persone)||'/'||(SELECT count(*) FROM utenti)||'/'||(SELECT count(*) FROM categorie)||'/'||(SELECT count(*) FROM infortuni)")" "$PRIMA_PERSONE/$PRIMA_UTENTI/$PRIMA_CAT/$PRIMA_INF"
ckmin "registro non ha perso righe (dopo la pulizia, baseline $PRIMA_REGISTRO)" registro "$PRIMA_REGISTRO"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
