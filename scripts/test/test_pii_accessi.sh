#!/bin/bash
# Verifica la chiusura dell'esposizione PII:
#  - GET /liste-torneo/{id}/giocatori: CF, telefoni, email, data nascita solo a chi ha diritto
#  - GET /infortuni/: note cliniche solo a infermeria/admin/segreteria
# Crea solo oggetti di prova marcati __test_pii__ / testpii e li rimuove alla fine.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
# estrae un campo dalla risposta JSON di GET /liste-torneo/{id}/giocatori (primo giocatore)
campo() { curl -s --max-time 20 "$D/liste-torneo/$1/giocatori" -H "Authorization: Bearer $2" \
  | python3 -c "import sys,json
d=json.load(sys.stdin)
v=(d[0].get('$3') if isinstance(d,list) and d else None)
print('(nessun giocatore)' if not isinstance(d,list) else ('null' if v is None else 'VALORE'))" 2>/dev/null; }
nota_inf() { curl -s --max-time 20 "$D/infortuni/?attivi=true" -H "Authorization: Bearer $1" \
  | python3 -c "import sys,json
d=json.load(sys.stdin)
r=[x for x in d if x.get('tipo_infortunio')=='__test_pii__tipo']
print('(non presente)' if not r else ('null' if r[0].get('note') is None else 'VALORE'))" 2>/dev/null; }
tipo_inf() { curl -s --max-time 20 "$D/infortuni/?attivi=true" -H "Authorization: Bearer $1" \
  | python3 -c "import sys,json
d=json.load(sys.stdin)
r=[x for x in d if x.get('tipo_infortunio')=='__test_pii__tipo']
print('(non presente)' if not r else 'VALORE')" 2>/dev/null; }

echo "--- preparazione (solo oggetti di prova) ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }

q "DELETE FROM infortuni WHERE tipo_infortunio='__test_pii__tipo';
   DELETE FROM liste_torneo_giocatori WHERE lista_id IN (SELECT id FROM liste_torneo WHERE nome='__test_pii__');
   DELETE FROM liste_torneo WHERE nome='__test_pii__';
   DELETE FROM registro WHERE persona_id IN (SELECT id FROM persone WHERE cognome='TestPii');
   DELETE FROM persone WHERE upper(cognome)='TESTPII';
   DELETE FROM utente_categorie WHERE categoria_id IN (SELECT id FROM categorie WHERE nome='__test_pii__');
   DELETE FROM categorie WHERE nome='__test_pii__';
   DELETE FROM utenti WHERE username LIKE 'testpii%';" >/dev/null

q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES (1,'__test_pii__',1901,0);" >/dev/null
CATP=$(q "SELECT id FROM categorie WHERE nome='__test_pii__'")
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testpii_admin','$HASH',1,1,0,NULL),
          ('testpii_m_ok','$HASH',1,0,0,'mister'),
          ('testpii_m_no','$HASH',1,0,0,'mister'),
          ('testpii_dir','$HASH',1,0,0,'dirigente');" >/dev/null
ADMIN=$(q "SELECT id FROM utenti WHERE username='testpii_admin'")
MOK=$(q "SELECT id FROM utenti WHERE username='testpii_m_ok'")
MNO=$(q "SELECT id FROM utenti WHERE username='testpii_m_no'")
DIR=$(q "SELECT id FROM utenti WHERE username='testpii_dir'")
q "INSERT INTO utente_categorie (utente_id,categoria_id) VALUES ($MOK,$CATP);" >/dev/null

tok() { curl -s --max-time 20 -X POST "$D/auth/token" -d "username=$1&password=$PW" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null; }
TADM=$(tok testpii_admin); TMOK=$(tok testpii_m_ok); TMNO=$(tok testpii_m_no); TDIR=$(tok testpii_dir)
ck "login admin"        "$([ -n "$TADM" ] && echo si)" "si"
ck "login mister assegnato"     "$([ -n "$TMOK" ] && echo si)" "si"
ck "login mister NON assegnato" "$([ -n "$TMNO" ] && echo si)" "si"
ck "login dirigente"    "$([ -n "$TDIR" ] && echo si)" "si"

# persona con dati sensibili, creata via API cosi' CF e telefoni passano dalla cifratura
PID=$(curl -s --max-time 20 -X POST "$D/persone/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
  -d "{\"nome\":\"Pii\",\"cognome\":\"TestPii\",\"categoria_id\":$CATP,\"societa_id\":1,\"data_nascita\":\"2012-03-04\",\"codice_fiscale\":\"TESTCF1980A01H501X\",\"tel_papa\":\"3330001111\",\"tel_mamma\":\"3330002222\",\"email1\":\"pii@test.local\"}" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('id',''))" 2>/dev/null)
[ -z "$PID" ] && { echo "  creazione persona fallita"; exit 1; }
LID=$(curl -s --max-time 20 -X POST "$D/liste-torneo/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
  -d "{\"nome\":\"__test_pii__\",\"categoria_id\":$CATP}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
curl -s -o /dev/null --max-time 20 -X POST "$D/liste-torneo/$LID/giocatori?persona_id=$PID" -H "Authorization: Bearer $TADM"
echo "  persona=$PID lista=$LID categoria=$CATP | mister_ok=$MOK (assegnato) mister_no=$MNO dirigente=$DIR"
ck "la persona ha il CF cifrato in DB" "$(q "SELECT CASE WHEN codice_fiscale IS NULL THEN 'null' WHEN codice_fiscale LIKE '%TESTCF%' THEN 'in chiaro!' ELSE 'cifrato' END FROM persone WHERE id=$PID")" "cifrato"

echo "--- liste-torneo/giocatori: chi ha diritto continua a vedere i dati ---"
ck "admin vede il CF"                    "$(campo $LID "$TADM" codice_fiscale)" "VALORE"
ck "admin vede tel_papa"                 "$(campo $LID "$TADM" tel_papa)" "VALORE"
ck "mister assegnato vede il CF"         "$(campo $LID "$TMOK" codice_fiscale)" "VALORE"
ck "mister assegnato vede email1"        "$(campo $LID "$TMOK" email1)" "VALORE"
echo "--- liste-torneo/giocatori: chi non ha diritto non li riceve piu' ---"
ck "mister NON assegnato: CF null"       "$(campo $LID "$TMNO" codice_fiscale)" "null"
ck "mister NON assegnato: tel_papa null" "$(campo $LID "$TMNO" tel_papa)" "null"
ck "mister NON assegnato: tel_mamma null" "$(campo $LID "$TMNO" tel_mamma)" "null"
ck "mister NON assegnato: email1 null"   "$(campo $LID "$TMNO" email1)" "null"
ck "mister NON assegnato: data_nascita null" "$(campo $LID "$TMNO" data_nascita)" "null"
ck "dirigente: CF null"                  "$(campo $LID "$TDIR" codice_fiscale)" "null"
ck "dirigente: tel_mamma null"           "$(campo $LID "$TDIR" tel_mamma)" "null"
ck "dirigente: scadenza_certificato null" "$(campo $LID "$TDIR" scadenza_certificato)" "null"
echo "--- i campi non sensibili restano disponibili a tutti (la pagina deve funzionare) ---"
for chi in "$TMNO:mister_no" "$TDIR:dirigente"; do
  t="${chi%%:*}"; n="${chi##*:}"
  ck "$n vede nome/cognome" "$(curl -s --max-time 20 "$D/liste-torneo/$LID/giocatori" -H "Authorization: Bearer $t" | python3 -c "import sys,json;d=json.load(sys.stdin);print('ok' if d and d[0].get('cognome')=='TESTPII' else 'mancante')" 2>/dev/null)" "ok"
  ck "$n vede sesso e gruppo" "$(curl -s --max-time 20 "$D/liste-torneo/$LID/giocatori" -H "Authorization: Bearer $t" | python3 -c "import sys,json;d=json.load(sys.stdin);print('ok' if d and 'sesso' in d[0] and 'gruppo_nome' in d[0] else 'mancante')" 2>/dev/null)" "ok"
done
ck "senza token -> 401"  "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$D/liste-torneo/$LID/giocatori")" "401"
ck "lista inesistente -> 404" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$D/liste-torneo/999999/giocatori" -H "Authorization: Bearer $TADM")" "404"

echo "--- infortuni: le note cliniche solo a chi se ne occupa ---"
curl -s -o /dev/null --max-time 20 -X POST "$D/infortuni/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
  -d "{\"persona_id\":$PID,\"categoria_id\":$CATP,\"data_inizio\":\"2026-11-10\",\"giorni_assenza\":20,\"tipo_infortunio\":\"__test_pii__tipo\",\"note\":\"__test_pii__nota\"}"
ck "l'infortunio e' visibile"            "$(tipo_inf "$TADM")" "VALORE"
ck "infermeria/admin vede le note"       "$(nota_inf "$TADM")" "VALORE"
ck "mister NON vede le note"             "$(nota_inf "$TMNO")" "null"
ck "dirigente NON vede le note"          "$(nota_inf "$TDIR")" "null"
ck "il tipo di infortunio resta visibile al dirigente (invariato)" "$(tipo_inf "$TDIR")" "VALORE"

echo "--- pulizia ---"
q "DELETE FROM infortuni WHERE tipo_infortunio='__test_pii__tipo';
   DELETE FROM liste_torneo_giocatori WHERE lista_id=$LID;
   DELETE FROM liste_torneo WHERE id=$LID;
   DELETE FROM registro WHERE persona_id=$PID;
   DELETE FROM persone WHERE id=$PID;
   DELETE FROM utente_categorie WHERE categoria_id=$CATP;
   DELETE FROM categorie WHERE id=$CATP;
   DELETE FROM utenti WHERE id IN ($ADMIN,$MOK,$MNO,$DIR);" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM persone WHERE upper(cognome)='TESTPII')+(SELECT count(*) FROM categorie WHERE nome='__test_pii__')+(SELECT count(*) FROM utenti WHERE username LIKE 'testpii%')+(SELECT count(*) FROM liste_torneo WHERE nome='__test_pii__')+(SELECT count(*) FROM infortuni WHERE tipo_infortunio='__test_pii__tipo')")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
