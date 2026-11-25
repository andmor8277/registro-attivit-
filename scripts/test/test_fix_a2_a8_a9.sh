#!/bin/bash
# Verifica i fix A2 (cross-tenant categorie), A8 (svuotamento campi persona),
# A9 (infortuni: campi svuotabili + data_fine coerente).
# Crea solo oggetti di prova marcati __test_fix__ / testfix e rimuove quelli.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
# Due valori vuoti non sono "uguali": sono un test che non ha misurato niente. Con un token perduto
# (429 del limiter, login rifiutato) le asserzioni sotto confrontavano '' con '' e dicevano ok.
ck() { if [ -z "$2" ] && [ -z "$3" ]; then fail=$((fail+1)); echo "  FAIL $1 -> entrambi vuoti: il test non ha misurato nulla"; return; fi
       if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X "$1" "$D$2" -H "Content-Type: application/json" ${3:+-H "Authorization: Bearer $3"} ${4:+-d "$4"}; }
# /auth/token ha @limiter.limit("10/minute") PER WORKER: dentro la suite, che fa girare ~20 file di
# fila, i due login di qui possono capitare su un worker che ne ha gia' visti 10 e diventare 429. Il
# corpo di un 429 non ha access_token: il token viene '', ogni richiesta dopo risponde 401, e senza
# retry ne senza guardia il file si fermava a meta' SENZA stampare il riepilogo -- "NESSUN RIASSUNTO
# (test rotto)" nella suite, con il suo contributo che spariva dal TOTALE (misurato il 25/11/2026:
# 720 asserzioni invece di 754, e nessuno se n'era accorto prima che il totale calasse)
tok() {
  local out code i
  for i in 1 2 3 4 5; do
    out=$(curl -s -w '\n%{http_code}' --max-time 20 -X POST "$D/auth/token" \
             --data-urlencode "username=$1" --data-urlencode "password=$PW")
    code="${out##*$'\n'}"
    if [ "$code" = "429" ]; then sleep 8; continue; fi
    printf '%s' "${out%$'\n'*}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null
    return 0
  done
  echo ""
}

echo "--- preparazione (solo oggetti di prova) ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  FAIL impossibile generare l'hash nel container: senza gli utenti di prova"
                     echo "       nessun login parte e nessuna asserzione misura qualcosa"
                     echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }

# La pulizia sta in UNA funzione, chiamata qui e nel trap su EXIT: prima, su un abortimento a meta'
# (hash non generato, token mancato, infortunio non creato), il file usciva lasciando in DEV la
# categoria __test_fix__, la persona TestFix e i due utenti testfix_ -- puliti solo dall'esecuzione
# successiva, che non e' detta. Un test che si ferma per un prerequisito non deve sporcare.
# L'infortunio si cancella **anche per persona e per categoria**, non solo per marker: il test stesso
# fa `PUT /infortuni/{id} {"note":null}` ("PUT con note:null svuota le note"), quindi a fine run il
# marker non c'e' piu' e il solo `note LIKE '__test_fix%'` non lo trova -- la `DELETE FROM persone`
# resta bloccata dalla FK e, poiche' `q` gira con lo stderr scartato, **non compare nessun errore**:
# resta la persona e resta la categoria (misurato il 25/11/2026 su DEV: 2 residui dopo un abortimento).
# Peggio: con una persona residua, la run dopo legge `PN=$(SELECT id FROM persone WHERE
# cognome='TestFix')` e si ritrova DUE id in una variabile sola
pulizia() {
  q "DELETE FROM infortuni WHERE persona_id IN (SELECT id FROM persone WHERE cognome='TestFix');
     DELETE FROM infortuni WHERE categoria_id IN (SELECT id FROM categorie WHERE nome='__test_fix__');
     DELETE FROM infortuni WHERE note LIKE '__test_fix%';
     DELETE FROM registro WHERE persona_id IN (SELECT id FROM persone WHERE cognome='TestFix');
     DELETE FROM persone WHERE cognome='TestFix';
     DELETE FROM utente_categorie WHERE categoria_id IN (SELECT id FROM categorie WHERE nome='__test_fix__');
     DELETE FROM categorie WHERE nome='__test_fix__';
     DELETE FROM utenti WHERE username LIKE 'testfix%';" >/dev/null
  # Self-check rumoroso: `q` scarta lo stderr, quindi una DELETE bloccata da una FK e' esattamente il
  # difetto che non si vede mai. Contare dopo, e dirlo, e' l'unico modo
  local RES
  RES=$(q "SELECT (SELECT count(*) FROM persone WHERE cognome='TestFix')
                + (SELECT count(*) FROM categorie WHERE nome='__test_fix__')
                + (SELECT count(*) FROM utenti WHERE username LIKE 'testfix%')
                + (SELECT count(*) FROM infortuni WHERE note LIKE '__test_fix%'
                   OR persona_id IN (SELECT id FROM persone WHERE cognome='TestFix'))")
  if [ -n "$RES" ] && [ "$RES" != "0" ]; then
    echo "  ATTENZIONE: la pulizia ha lasciato $RES righe: una DELETE sara' stata bloccata da una FK"
    echo "       in silenzio (q scarta lo stderr). Le asserzioni sui residui qui sotto dicono dove."
  fi
  return 0
}
pulizia
trap pulizia EXIT

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
[ -z "$CATP" ] || [ -z "$PN" ] || [ -z "$CAT_SOC2" ] && { echo "  FAIL preparazione fallita (cat=$CATP persona=$PN cat_soc2=$CAT_SOC2):"
                     echo "       senza questi tre id le asserzioni sul tenant non confrontano niente"
                     echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }
echo "  cat prova=$CATP  persona=$PN  cat altra soc=$CAT_SOC2  utenti: A(soc1)=$AID B(soc2)=$BID"

TOKA=$(tok testfix_a)
ck "login admin societa' 1" "$([ -n "$TOKA" ] && echo si)" "si"
# Qui ci si FERMA, non si prosegue: senza token ogni richiesta dopo risponde 401 e le ~30 asserzioni
# successive diventano una valanga che accusa l'app per un login mai avvenuto (e il file, senza
# riepilogo, sparisce dalla somma della suite)
if [ -z "$TOKA" ]; then
  echo "  FAIL token di testfix_a mancante: le ~33 asserzioni che seguono sarebbero tutte 401"
  echo "  $pass passati, $((fail+1)) falliti (prerequisiti)"; exit 1
fi

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
[ -z "$IID" ] && { echo "  FAIL creazione infortunio di prova fallita: le asserzioni su /infortuni/\$IID"
                     echo "       che seguono sarebbero tutte 404, non un verdetto su A9"
                     echo "  $pass passati, $((fail+1)) falliti (prerequisiti)"; exit 1; }
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
TOKB=$(tok testfix_b)
# Vale la stessa ragione di TOKA: le asserzioni cross-tenant che seguono misurerebbero 401 invece di
# 403, cioe' direbbero "il tenant non e' protetto" quando e' solo mancato un login
if [ -z "$TOKB" ]; then
  echo "  FAIL token di testfix_b mancante: le asserzioni cross-tenant che seguono sarebbero 401, non 403"
  echo "  $pass passati, $((fail+1)) falliti (prerequisiti)"; exit 1
fi
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
# Un numero composito che dice "2" senza dire dove non e' una prova: quattro asserzioni, una per
# tabella, perche' e' esattamente cosi' che si e' visto il residuo (persona + categoria, infortuni a
# zero) e con la somma sola non si sarebbe capito quale DELETE era stata bloccata
ck "nessun residuo: persone"        "$(q "SELECT count(*) FROM persone WHERE cognome='TestFix'")" "0"
ck "nessun residuo: categorie"      "$(q "SELECT count(*) FROM categorie WHERE nome='__test_fix__'")" "0"
ck "nessun residuo: utenti"         "$(q "SELECT count(*) FROM utenti WHERE username LIKE 'testfix%'")" "0"
ck "nessun residuo: infortuni"      "$(q "SELECT count(*) FROM infortuni WHERE note LIKE '__test_fix%' OR persona_id IN (SELECT id FROM persone WHERE cognome='TestFix')")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
