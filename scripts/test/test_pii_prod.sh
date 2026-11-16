#!/bin/bash
# Verifica post-deploy su PROD la chiusura PII su liste-torneo e note infortuni,
# piu' le invarianze di sicurezza. Crea solo oggetti di prova marcati e li rimuove.
P=https://thof.crickethouse.mywire.org/api
SSH="ssh -i $HOME/.ssh/id_ed25519_prod -o ConnectTimeout=15 root@192.168.178.132"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
campo() { curl -s --max-time 20 "$P/liste-torneo/$1/giocatori" -H "Authorization: Bearer $2" \
  | python3 -c "import sys,json
d=json.load(sys.stdin)
v=(d[0].get('$3') if isinstance(d,list) and d else None)
print('(nessun giocatore)' if not isinstance(d,list) else ('null' if v is None else 'VALORE'))" 2>/dev/null; }

echo "--- preparazione (solo oggetti di prova) ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }
q "DELETE FROM liste_torneo_giocatori WHERE lista_id IN (SELECT id FROM liste_torneo WHERE nome='__test_pii__');
   DELETE FROM liste_torneo WHERE nome='__test_pii__';
   DELETE FROM infortuni WHERE tipo_infortunio='__test_pii__tipo';
   DELETE FROM registro WHERE persona_id IN (SELECT id FROM persone WHERE upper(cognome)='TESTPII');
   DELETE FROM persone WHERE upper(cognome)='TESTPII';
   DELETE FROM utente_categorie WHERE categoria_id IN (SELECT id FROM categorie WHERE nome='__test_pii__');
   DELETE FROM categorie WHERE nome='__test_pii__';
   DELETE FROM utenti WHERE username LIKE 'testpiip%';" >/dev/null
q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES (1,'__test_pii__',1902,0);" >/dev/null
CATP=$(q "SELECT id FROM categorie WHERE nome='__test_pii__'")
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testpiip_admin','$HASH',1,1,0,NULL),
          ('testpiip_m_ok','$HASH',1,0,0,'mister'),
          ('testpiip_m_no','$HASH',1,0,0,'mister');" >/dev/null
ADMIN=$(q "SELECT id FROM utenti WHERE username='testpiip_admin'")
MOK=$(q "SELECT id FROM utenti WHERE username='testpiip_m_ok'")
MNO=$(q "SELECT id FROM utenti WHERE username='testpiip_m_no'")
q "INSERT INTO utente_categorie (utente_id,categoria_id) VALUES ($MOK,$CATP);" >/dev/null
tok() { curl -s --max-time 20 -X POST "$P/auth/token" -d "username=$1&password=$PW" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null; }
TADM=$(tok testpiip_admin); TMOK=$(tok testpiip_m_ok); TMNO=$(tok testpiip_m_no)
ck "login admin prova" "$([ -n "$TADM" ] && echo si)" "si"
PID=$(curl -s --max-time 20 -X POST "$P/persone/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
  -d "{\"nome\":\"Pii\",\"cognome\":\"TestPii\",\"categoria_id\":$CATP,\"societa_id\":1,\"data_nascita\":\"2012-03-04\",\"codice_fiscale\":\"TESTCF1980A01H501X\",\"tel_papa\":\"3330001111\",\"email1\":\"pii@test.local\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
LID=$(curl -s --max-time 20 -X POST "$P/liste-torneo/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
  -d "{\"nome\":\"__test_pii__\",\"categoria_id\":$CATP}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
curl -s -o /dev/null --max-time 20 -X POST "$P/liste-torneo/$LID/giocatori?persona_id=$PID" -H "Authorization: Bearer $TADM"
echo "  persona=$PID lista_prova=$LID cat=$CATP | lista_reale_id=3"
ck "CF cifrato in DB, non in chiaro" "$(q "SELECT CASE WHEN codice_fiscale IS NULL THEN 'null' WHEN codice_fiscale LIKE '%TESTCF%' THEN 'in chiaro!' ELSE 'cifrato' END FROM persone WHERE id=$PID")" "cifrato"

echo "--- lista di prova: diritti ---"
ck "admin vede il CF"                    "$(campo $LID "$TADM" codice_fiscale)" "VALORE"
ck "mister assegnato vede il CF"         "$(campo $LID "$TMOK" codice_fiscale)" "VALORE"
ck "mister NON assegnato: CF null"       "$(campo $LID "$TMNO" codice_fiscale)" "null"
ck "mister NON assegnato: tel_papa null" "$(campo $LID "$TMNO" tel_papa)" "null"
ck "mister NON assegnato: email1 null"   "$(campo $LID "$TMNO" email1)" "null"
ck "mister NON assegnato: data_nascita null" "$(campo $LID "$TMNO" data_nascita)" "null"
ck "mister NON assegnato vede cognome"   "$(curl -s --max-time 20 "$P/liste-torneo/$LID/giocatori" -H "Authorization: Bearer $TMNO" | python3 -c "import sys,json;d=json.load(sys.stdin);print('ok' if d and d[0].get('cognome')=='TESTPII' else 'mancante')" 2>/dev/null)" "ok"

echo "--- lista REALE id=3 (11 giocatori): nessun dato sensibile a chi non ne ha diritto ---"
CF_ADMIN=$(campo 3 "$TADM" codice_fiscale)
echo "  (l'amministrazione vede: $CF_ADMIN)"
ck "mister non assegnato alla cat 19: CF null"  "$(campo 3 "$TMNO" codice_fiscale)" "null"
ck "mister non assegnato alla cat 19: tel null" "$(campo 3 "$TMNO" tel_papa)" "null"
ck "mister non assegnato alla cat 19: email null" "$(campo 3 "$TMNO" email1)" "null"
ck "i giocatori restano elencati (11)" "$(curl -s --max-time 20 "$P/liste-torneo/3/giocatori" -H "Authorization: Bearer $TMNO" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null)" "$(q "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=3")"

echo "--- infortuni: note riservate ---"
curl -s -o /dev/null --max-time 20 -X POST "$P/infortuni/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
  -d "{\"persona_id\":$PID,\"categoria_id\":$CATP,\"data_inizio\":\"2026-11-10\",\"giorni_assenza\":20,\"tipo_infortunio\":\"__test_pii__tipo\",\"note\":\"__test_pii__nota\"}"
nota() { curl -s --max-time 20 "$P/infortuni/?attivi=true" -H "Authorization: Bearer $1" \
  | python3 -c "import sys,json
d=json.load(sys.stdin)
r=[x for x in d if x.get('tipo_infortunio')=='__test_pii__tipo']
print('(non presente)' if not r else ('null' if r[0].get('note') is None else 'VALORE'))" 2>/dev/null; }
ck "admin vede le note"        "$(nota "$TADM")" "VALORE"
ck "mister NON vede le note"   "$(nota "$TMNO")" "null"

echo "--- invarianze di sicurezza e sito ---"
for ep in "/" "/login" "/form-iscrizione"; do
  ck "GET $ep" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://thof.crickethouse.mywire.org$ep")" "200"
done
for ep in "/api/docs" "/api/openapi.json" "/api/redoc"; do
  ck "GET $ep bloccato" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://thof.crickethouse.mywire.org$ep")" "404"
done
ck "liste-torneo senza token -> 401" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$P/liste-torneo/3/giocatori")" "401"
ck "lista inesistente -> 404"         "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$P/liste-torneo/999999/giocatori" -H "Authorization: Bearer $TADM")" "404"

echo "--- conteggi vs baseline pre-deploy ---"
ck "persone = 127 + 1 prova"  "$(q "SELECT count(*) FROM persone")" "128"
ck "utenti = 13 + 3 prova"    "$(q "SELECT count(*) FROM utenti")" "16"
ck "giocatori lista 3 invariati (11)" "$(q "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=3")" "11"
ck "liste torneo = 1 + 1 prova"       "$(q "SELECT count(*) FROM liste_torneo")" "2"

echo "--- pulizia ---"
q "DELETE FROM infortuni WHERE tipo_infortunio='__test_pii__tipo';
   DELETE FROM liste_torneo_giocatori WHERE lista_id=$LID;
   DELETE FROM liste_torneo WHERE id=$LID;
   DELETE FROM registro WHERE persona_id=$PID;
   DELETE FROM persone WHERE id=$PID;
   DELETE FROM utente_categorie WHERE categoria_id=$CATP;
   DELETE FROM categorie WHERE id=$CATP;
   DELETE FROM utenti WHERE id IN ($ADMIN,$MOK,$MNO);" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM persone WHERE upper(cognome)='TESTPII')+(SELECT count(*) FROM categorie WHERE nome='__test_pii__')+(SELECT count(*) FROM utenti WHERE username LIKE 'testpiip%')+(SELECT count(*) FROM liste_torneo WHERE nome='__test_pii__')+(SELECT count(*) FROM infortuni WHERE tipo_infortunio='__test_pii__tipo')")" "0"
ck "tutto tornato alla baseline" "$(q "SELECT (SELECT count(*) FROM persone)||'/'||(SELECT count(*) FROM utenti)||'/'||(SELECT count(*) FROM liste_torneo)||'/'||(SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=3)||'/'||(SELECT count(*) FROM infortuni)")" "127/13/1/11/0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
