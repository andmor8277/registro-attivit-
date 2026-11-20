#!/bin/bash
# Verifica post-deploy su PROD la chiusura PII su liste-torneo e note infortuni,
# piu' le invarianze di sicurezza. Crea solo oggetti di prova marcati e li rimuove.
P=https://thof.crickethouse.mywire.org/api
SSH="ssh -i $HOME/.ssh/id_ed25519_prod -o ConnectTimeout=15 root@192.168.178.132"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
# Soglia minima assoluta: non insegue la crescita del DB (altrimenti scade come scadeva il "127"
# scritto a mano a lato), deve solo stare molto sopra zero.
ckmin() { local n; n=$(q "SELECT count(*) FROM $2"); if [ -n "$n" ] && [ "$n" -ge "$3" ]; then pass=$((pass+1)); echo "  ok   $1 (>= $3, ora $n)"; else fail=$((fail+1)); echo "  FAIL $1 -> $n, sotto la soglia $3"; fi; }
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
# Baseline misurata ADESSO (dopo la pulizia dei residui, prima di creare gli oggetti di prova).
# Prima qui sotto c'era "persone = 128", "utenti = 16", "giocatori lista 3 = 11": numeri di una
# sera di novembre copiati nel file. Bastava che qualcuno iscrivesse un ragazzo perche' il test
# diventasse rosso da solo. L'invarianza la misuriamo su questi valori; i minimi assoluti in coda
# sono quelli che si accorgono di un DB davvero svuotato.
PRIMA_PERSONE=$(q "SELECT count(*) FROM persone")
PRIMA_UTENTI=$(q "SELECT count(*) FROM utenti")
PRIMA_LISTE=$(q "SELECT count(*) FROM liste_torneo")
PRIMA_INF=$(q "SELECT count(*) FROM infortuni")
echo "  baseline di questa esecuzione: persone=$PRIMA_PERSONE utenti=$PRIMA_UTENTI liste=$PRIMA_LISTE infortuni=$PRIMA_INF"
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
# La lista "vera" non e' la numero 3 per always: era l'unica lista esistente a novembre, con id 3
# assegnato dal generatore. Se la segreteria ne cancella una e ne crea un'altra l'id cambia e il
# test sarebbe rosso per il motivo sbagliato. Si prende la lista reale con piu' giocatori, e se
# non c'e' il test si ferma: un prerequisito perduto deve fermare, non stampare un verde falso.
L3=$(q "SELECT l.id FROM liste_torneo l JOIN liste_torneo_giocatori g ON g.lista_id=l.id
        WHERE l.nome<>'__test_pii__' GROUP BY l.id ORDER BY count(g.id) DESC, l.id LIMIT 1")
NG3=$(q "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=$L3")
[ -z "$L3" ] && { echo "  FAIL nessuna lista torneo reale con giocatori: il test non pu' verificare l'accesso alla lista"; echo; echo "  0 passati, 1 falliti"; exit 1; }
echo "  persona=$PID lista_prova=$LID cat=$CATP | lista_reale_id=$L3 con $NG3 giocatori"
ck "CF cifrato in DB, non in chiaro" "$(q "SELECT CASE WHEN codice_fiscale IS NULL THEN 'null' WHEN codice_fiscale LIKE '%TESTCF%' THEN 'in chiaro!' ELSE 'cifrato' END FROM persone WHERE id=$PID")" "cifrato"

echo "--- lista di prova: diritti ---"
ck "admin vede il CF"                    "$(campo $LID "$TADM" codice_fiscale)" "VALORE"
ck "mister assegnato vede il CF"         "$(campo $LID "$TMOK" codice_fiscale)" "VALORE"
ck "mister NON assegnato: CF null"       "$(campo $LID "$TMNO" codice_fiscale)" "null"
ck "mister NON assegnato: tel_papa null" "$(campo $LID "$TMNO" tel_papa)" "null"
ck "mister NON assegnato: email1 null"   "$(campo $LID "$TMNO" email1)" "null"
ck "mister NON assegnato: data_nascita null" "$(campo $LID "$TMNO" data_nascita)" "null"
ck "mister NON assegnato vede cognome"   "$(curl -s --max-time 20 "$P/liste-torneo/$LID/giocatori" -H "Authorization: Bearer $TMNO" | python3 -c "import sys,json;d=json.load(sys.stdin);print('ok' if d and d[0].get('cognome')=='TESTPII' else 'mancante')" 2>/dev/null)" "ok"

echo "--- lista REALE id=$L3 ($NG3 giocatori): nessun dato sensibile a chi non ne ha diritto ---"
CF_ADMIN=$(campo $L3 "$TADM" codice_fiscale)
echo "  (l'amministrazione vede: $CF_ADMIN)"
ck "mister non assegnato alla cat $CATP: CF null"  "$(campo $L3 "$TMNO" codice_fiscale)" "null"
ck "mister non assegnato alla cat $CATP: tel null" "$(campo $L3 "$TMNO" tel_papa)" "null"
ck "mister non assegnato alla cat $CATP: email null" "$(campo $L3 "$TMNO" email1)" "null"
ck "i giocatori restano tutti elencati ($NG3)" "$(curl -s --max-time 20 "$P/liste-torneo/$L3/giocatori" -H "Authorization: Bearer $TMNO" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null)" "$NG3"

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
ck "liste-torneo senza token -> 401" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$P/liste-torneo/$L3/giocatori")" "401"
ck "lista inesistente -> 404"         "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$P/liste-torneo/999999/giocatori" -H "Authorization: Bearer $TADM")" "404"

echo "--- conteggi DB: invarianza + gli incrementi portati dal test ---"
ck "persone = baseline + 1 prova"     "$(q "SELECT count(*) FROM persone")"    "$((PRIMA_PERSONE + 1))"
ck "utenti = baseline + 3 prova"      "$(q "SELECT count(*) FROM utenti")"     "$((PRIMA_UTENTI + 3))"
ck "giocatori lista $L3 invariati ($NG3)" "$(q "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=$L3")" "$NG3"
ck "liste torneo = baseline + 1 prova"    "$(q "SELECT count(*) FROM liste_torneo")" "$((PRIMA_LISTE + 1))"
echo "--- minimi assoluti: questi si' che accorgono di un DB svuotato dal deploy ---"
ckmin "persone popolate"         persone            50
ckmin "utenti presenti"          utenti             10
ckmin "liste torneo presenti"    liste_torneo        1
ckmin "giocatori nelle liste"    liste_torneo_giocatori 1

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
ck "tutto tornato alla baseline" "$(q "SELECT (SELECT count(*) FROM persone)||'/'||(SELECT count(*) FROM utenti)||'/'||(SELECT count(*) FROM liste_torneo)||'/'||(SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=$L3)||'/'||(SELECT count(*) FROM infortuni)")" "$PRIMA_PERSONE/$PRIMA_UTENTI/$PRIMA_LISTE/$NG3/$PRIMA_INF"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
