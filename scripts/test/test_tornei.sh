#!/bin/bash
# Tornei: chi li crea, chi li vede, cosa succede alle liste collegate.
#
# Copre tre cose che senza test resterebbero solo intenzioni:
#  1. la scrittura dei tornei e' del responsabile (admin), non di chi convocava;
#  2. la Lista Tornei nasce col torneo e ne segue nome e cancellazione (e' il file che viene
#     consegnato all'organizzatore: se dipende da un passaggio manuale del mister resta senza);
#  3. dirigente e scouting, che prima potevano aggiungere/rimuovere giocatori e cancellare
#     l'intera lista con il solo token valido, ora restano in sola lettura.
#
# Crea solo oggetti marcati __test_tornei__ / testtornei / TestTornei e li rimuove alla fine.
# La lista e i giocatori gia' presenti nel DB di DEV non vengono toccati: il test lo dimostra
# confrontando i conteggi prima e dopo.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
# ck non accetta un "ok" quando entrambi i valori sono vuoti: senza questo guard, con i token
# vuoti l'asserzione "il dettaglio riporta la lista collegata" confrontava '' con '' e diceva ok.
# Un confronto fra due vuoti non ha misurato niente, e' il modo peggiore di essere verdi.
ck() { if [ -z "$2" ] && [ -z "$3" ]; then fail=$((fail+1)); echo "  FAIL $1 -> entrambi vuoti: il test non ha misurato nulla"; return; fi
       if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi; }

# Il retry sul 429 non e' cosmetico: /auth/token ha @limiter.limit("10/minute") per worker e
# questo file fa 7 login. Senza retry il test diventa rosso per il limiter e non per la logica.
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
  echo ""
}
# codice http + dettaglio, per distinguere un 403 "giusto" da un 403 arrivato per un altro motivo
cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 "$@"; }
det() { curl -s --max-time 25 "$@" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('detail',''))
except Exception: print('')" 2>/dev/null; }
# campo del dettaglio torneo: accetta percorsi misti come "lista.giocatori" (dizionari) e
# "gare.0.avversario" (liste). Gestire anche gli indici e' necessario perche' il calendario
# arriva come array: senza, l'asserzione leggerrebbe '' e fallirebbe per il motivo sbagliato
jq1() { curl -s --max-time 25 "$1" -H "Authorization: Bearer $2" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
d=d[0] if isinstance(d,list) and d else d
v=d
for k in '$3'.split('.'):
    if isinstance(v,dict): v=v.get(k)
    elif isinstance(v,list) and k.isdigit(): v=v[int(k)] if int(k)<len(v) else None
    else: v=None
print('' if v is None else v)" 2>/dev/null; }

P=__test_tornei__
echo "--- preparazione (solo oggetti di prova) ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }

pulizia() {
  q "DELETE FROM tornei_gare WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%');
     DELETE FROM liste_torneo_giocatori WHERE lista_id IN (SELECT id FROM liste_torneo WHERE nome LIKE '$P%');
     DELETE FROM liste_torneo WHERE nome LIKE '$P%';
     DELETE FROM tornei WHERE nome LIKE '$P%';
     DELETE FROM persone WHERE upper(cognome)='TESTTORNEI';
     DELETE FROM utente_categorie WHERE categoria_id IN (SELECT id FROM categorie WHERE nome LIKE '$P%');
     DELETE FROM categorie WHERE nome LIKE '$P%';
     DELETE FROM utenti WHERE username LIKE 'testtornei%';" >/dev/null
}
pulizia

# Baseline: la lista e i giocatori che gia' esistono in DEV non devono essere toccati dal test.
# Contati qui e non scritti a mano: se qualcuno aggiunge una lista, il test deve restare verde.
BASE_LISTE=$(q "SELECT count(*) FROM liste_torneo")
BASE_GIOC=$(q "SELECT count(*) FROM liste_torneo_giocatori")
BASE_TORNEI=$(q "SELECT count(*) FROM tornei")
echo "  baseline: liste=$BASE_LISTE giocatori=$BASE_GIOC tornei=$BASE_TORNEI"

q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES (1,'$P-cat1',1901,0);
   INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES (2,'$P-cat2',1901,0);" >/dev/null
CAT1=$(q "SELECT id FROM categorie WHERE nome='$P-cat1'")
CAT2=$(q "SELECT id FROM categorie WHERE nome='$P-cat2'")

# due persone per la societa' 1 (servono per aggiungere/rimuovere dalla lista) e una nella 2,
# che e' quella che NON deve poter finire nella lista della societa' 1.
# Cognome in maiuscolo perche' POST /persone/ lo scrive cosi' (verificato: "DbgCog" diventa
# "DBGCOG"): inserire i dati di prova come li produce l'applicazione stessa, altrimenti un
# confronto sul cognome fallisce per la forma e non per la regola che si vuole testare
q "INSERT INTO persone (nome,cognome,societa_id,categoria_id) VALUES
     ('Uno','TESTTORNEI',1,$CAT1),('Due','TESTTORNEI',1,$CAT1),('Tre','TESTTORNEI',2,$CAT2);" >/dev/null
P1=$(q "SELECT min(id) FROM persone WHERE upper(cognome)='TESTTORNEI' AND societa_id=1")
P1B=$(q "SELECT max(id) FROM persone WHERE upper(cognome)='TESTTORNEI' AND societa_id=1")
P2=$(q "SELECT min(id) FROM persone WHERE upper(cognome)='TESTTORNEI' AND societa_id=2")

q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testtornei_admin','$HASH',1,1,0,NULL),
          ('testtornei_mister','$HASH',1,0,0,'mister'),
          ('testtornei_dir','$HASH',1,0,0,'dirigente'),
          ('testtornei_scout','$HASH',1,0,0,'scouting'),
          ('testtornei_infer','$HASH',1,0,0,'infermeria'),
          ('testtornei_segr','$HASH',1,0,0,'segreteria'),
          ('testtornei_soc2','$HASH',2,1,0,NULL);" >/dev/null
# tok vuole DUE argomenti (username e password): chiamarla con uno solo legge $2 vuoto,
# ogni login risponde 401 e il test diventa rosso per un motivo che non c'entra col torneo
TADM=$(tok testtornei_admin "$PW"); TMIS=$(tok testtornei_mister "$PW"); TDIR=$(tok testtornei_dir "$PW")
TSCO=$(tok testtornei_scout "$PW"); TINF=$(tok testtornei_infer "$PW"); TSEG=$(tok testtornei_segr "$PW")
TSOC=$(tok testtornei_soc2 "$PW")
# Se manca un token si esce qui: proseguire con i token vuoti significa che le decine di
# asserzioni sotto confrontano fra loro gli stessi valori vuoti e il riepilogo non significa piu' niente
for pair in "admin:$TADM" "mister:$TMIS" "dirigente:$TDIR" "scouting:$TSCO" "infermeria:$TINF" "segreteria:$TSEG" "admin soc2:$TSOC"; do
  if [ -z "${pair##*:}" ]; then
    echo "  login ${pair%%:*} fallito: i 7 login sono il prerequisito di tutto il resto, mi fermo"
    pulizia
    echo; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1
  fi
done
for pair in "admin:$TADM" "mister:$TMIS" "dirigente:$TDIR" "scouting:$TSCO" "infermeria:$TINF" "segreteria:$TSEG" "admin soc2:$TSOC"; do
  ck "login ${pair%%:*}" "$([ -n "${pair##*:}" ] && echo si)" "si"
done
echo "  cat1=$CAT1 cat2=$CAT2 | persone soc1=$P1,$P1B soc2=$P2"

echo
echo "--- 1. leggere i tornei richiede un token, il torneo inesistente risponde 404 ---"
ck "GET /tornei/ senza token -> 401" "$(cod "$D/tornei/")" "401"
ck "GET /tornei/999999 -> 404" "$(cod "$D/tornei/999999" -H "Authorization: Bearer $TADM")" "404"

echo
echo "--- 2. creare un torneo e' del responsabile: gli altri ruoli restano fuori ---"
corpo() { echo "{\"nome\":\"$1\",\"categoria_id\":$2${3:+,\"data_inizio\":\"2026-12-19\",\"data_fine\":\"2026-12-20\"}}"; }
for pair in "mister:$TMIS" "dirigente:$TDIR" "scouting:$TSCO" "infermeria:$TINF" "segreteria:$TSEG"; do
  n="${pair%%:*}"; t="${pair##*:}"
  ck "$n crea un torneo -> 403" "$(cod -X POST "$D/tornei/" -H "Content-Type: application/json" -H "Authorization: Bearer $t" -d "$(corpo "$P-$n" $CAT1 x)")" "403"
done
ck "  nessuno di quei 403 ha creato righe in tornei" "$(q "SELECT count(*) FROM tornei")" "$BASE_TORNEI"

echo
echo "--- 3. il responsabile crea il torneo e la Lista Tornei nasce con lui ---"
CREA=$(curl -s --max-time 25 -X POST "$D/tornei/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
        -d "$(corpo "$P-Natale" $CAT1 x)")
TID=$(printf '%s' "$CREA" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
LID=$(printf '%s' "$CREA" | python3 -c "import sys,json;print(json.load(sys.stdin).get('lista_id',''))" 2>/dev/null)
if [ -z "$TID" ] || [ -z "$LID" ]; then
  echo "  creazione del torneo fallita: $(printf '%s' "$CREA" | head -c 200)"
  echo "  le sezioni 3-10 dipendono tutte da questo id, mi fermo invece di stampare un rosso inutile"
  pulizia; echo; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1
fi
ck "admin crea il torneo" "$([ -n "$TID" ] && echo si)" "si"
ck "  la risposta porta gia' la lista collegata" "$([ -n "$LID" ] && echo si)" "si"
ck "  la lista esiste e punta al torneo" "$(q "SELECT count(*) FROM liste_torneo WHERE id=$LID AND torneo_id=$TID")" "1"
ck "  la lista eredita il nome del torneo" "$(q "SELECT nome FROM liste_torneo WHERE id=$LID")" "$P-Natale"
ck "  la lista eredita la categoria" "$(q "SELECT categoria_id FROM liste_torneo WHERE id=$LID")" "$CAT1"
ck "  la lista eredita la societa'" "$(q "SELECT societa_id FROM liste_torneo WHERE id=$LID")" "1"
ck "  il torneo ha la data di creazione" "$(q "SELECT CASE WHEN creato_il IS NULL THEN 'null' ELSE 'ok' END FROM tornei WHERE id=$TID")" "ok"
ck "  il torneo registra chi lo ha creato" "$(q "SELECT creato_da FROM tornei WHERE id=$TID")" "$(q "SELECT id FROM utenti WHERE username='testtornei_admin'")"
ck "  un solo torneo = una sola lista" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$TID")" "1"
ck "GET /tornei/{id} come mister: vede il torneo" "$(jq1 "$D/tornei/$TID" "$TMIS" nome)" "$P-Natale"
ck "GET /tornei/{id} come dirigente: lo vede lo stesso (e' informazione di squadra)" "$(jq1 "$D/tornei/$TID" "$TDIR" nome)" "$P-Natale"
ck "GET /tornei/ come mister: il torneo c'e'" "$(jq1 "$D/tornei/?categoria_id=$CAT1" "$TMIS" nome)" "$P-Natale"
ck "  il dettaglio riporta la lista collegata" "$(jq1 "$D/tornei/$TID" "$TMIS" lista.id)" "$LID"
ck "  la lista parte vuota (0 giocatori)" "$(jq1 "$D/tornei/$TID" "$TMIS" lista.giocatori)" "0"

echo
echo "--- 4. i dati incompleti o incoerenti vengono rifiutati ---"
ck "nome vuoto -> 400" "$(cod -X POST "$D/tornei/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" -d "{\"nome\":\"   \",\"categoria_id\":$CAT1}")" "400"
ck "data fine prima dell'inizio -> 400" "$(cod -X POST "$D/tornei/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" -d "{\"nome\":\"$P-invertito\",\"categoria_id\":$CAT1,\"data_inizio\":\"2026-12-20\",\"data_fine\":\"2026-12-19\"}")" "400"
ck "categoria inesistente -> 404" "$(cod -X POST "$D/tornei/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" -d "{\"nome\":\"$P-cat\",\"categoria_id\":999999}")" "404"
ck "categoria di un'altra societa' -> 403" "$(cod -X POST "$D/tornei/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" -d "$(corpo "$P-straniera" $CAT2 x)")" "403"
ck "  e nessuna di queste e' stata creata" "$(q "SELECT count(*) FROM tornei")" "$((BASE_TORNEI+1))"

echo
echo "--- 5. il calendario: il responsabile lo scrive, gli altri lo leggono ---"
G1=$(curl -s --max-time 25 -X POST "$D/tornei/$TID/gare" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
      -d '{"avversario":"Rossoblu","data":"2026-12-19","ora":"10:30","ora_appuntamento":"09:45","campo":"Campo 2","indirizzo":"Via Roma 1"}' \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
ck "admin aggiunge una gara" "$([ -n "$G1" ] && echo si)" "si"
ck "  il numero viene da solo (prima gara = 1)" "$(q "SELECT numero FROM tornei_gare WHERE id=$G1")" "1"
ck "  l'ora resta la stringa comunicata dall'organizzatore" "$(q "SELECT ora FROM tornei_gare WHERE id=$G1")" "10:30"
ck "  l'appuntamento pure" "$(q "SELECT ora_appuntamento FROM tornei_gare WHERE id=$G1")" "09:45"
ck "il mister legge il calendario" "$(jq1 "$D/tornei/$TID" "$TMIS" gare.0.avversario)" "Rossoblu"
G2=$(curl -s --max-time 25 -X POST "$D/tornei/$TID/gare" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
      -d '{"avversario":"Verdi","data":"2026-12-20"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
ck "  il numero della seconda gara e' 2" "$(q "SELECT numero FROM tornei_gare WHERE id=$G2")" "2"
ck "admin modifica una gara" "$(cod -X PUT "$D/tornei/$TID/gare/$G1" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" -d '{"avversario":"Rossoblu FC","data":"2026-12-19","ora":"11:00","ora_appuntamento":"10:15","campo":"Campo 2","indirizzo":"Via Roma 1"}')" "200"
ck "  la modifica si vede nel dettaglio" "$(jq1 "$D/tornei/$TID" "$TMIS" gare.0.avversario)" "Rossoblu FC"
for pair in "mister:$TMIS" "dirigente:$TDIR" "scouting:$TSCO" "segreteria:$TSEG"; do
  n="${pair%%:*}"; t="${pair##*:}"
  ck "$n aggiunge una gara -> 403" "$(cod -X POST "$D/tornei/$TID/gare" -H "Content-Type: application/json" -H "Authorization: Bearer $t" -d '{"avversario":"Abusiva"}')" "403"
  ck "$n elimina una gara -> 403" "$(cod -X DELETE "$D/tornei/$TID/gare/$G2" -H "Authorization: Bearer $t")" "403"
done
ck "  le gare abusive non sono state create" "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID")" "2"
ck "  la gara non cancellata dai non-responsabili e' ancora li'" "$(q "SELECT count(*) FROM tornei_gare WHERE id=$G2")" "1"
ck "gare vuote -> 400" "$(cod -X POST "$D/tornei/$TID/gare" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" -d '{"note":""}')" "400"
# id di gara preso da un ALTRO torneo, creato qui apposta: senza il doppio vincolo (gara.id E
# torneo_id) basterebbe conoscere un id qualsiasi per riscrivere la gara di un altro torneo
# passando l'id di un torneo legittimo. Il secondo torneo esiste per davvero, perche' un
# "if [ -n "$ALTRA" ]" che salta l'asserzione sarebbe un verde senza significato
TID2=$(curl -s --max-time 25 -X POST "$D/tornei/" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
        -d "$(corpo "$P-Doppio" $CAT1 x)" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
GALT=$(curl -s --max-time 25 -X POST "$D/tornei/$TID2/gare" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" \
       -d '{"avversario":"GaraAltrui","data":"2026-12-21"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
ck "  (preparazione: secondo torneo con una gara propria)" "$([ -n "$TID2" ] && [ -n "$GALT" ] && echo si)" "si"
ck "gara di un altro torneo -> 404, non 200" "$(cod -X PUT "$D/tornei/$TID/gare/$GALT" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" -d '{"avversario":"Intrusa"}')" "404"
ck "  e la gara dell'altro torneo non e' stata toccata" "$(q "SELECT avversario FROM tornei_gare WHERE id=$GALT")" "GaraAltrui"
ck "  l'elenco dei tornei ne mostra due" "$(curl -s --max-time 25 "$D/tornei/?categoria_id=$CAT1" -H "Authorization: Bearer $TMIS" | python3 -c "import sys,json
print(sum(1 for t in json.load(sys.stdin) if t.get('nome','').startswith('$P')))" 2>/dev/null)" "2"
ck "admin elimina una gara" "$(cod -X DELETE "$D/tornei/$TID/gare/$G2" -H "Authorization: Bearer $TADM")" "200"
ck "  ne resta una" "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID")" "1"
ck "  eliminarla di nuovo -> 404" "$(cod -X DELETE "$D/tornei/$TID/gare/$G2" -H "Authorization: Bearer $TADM")" "404"

echo
echo "--- 6. rinominare il torneo aggiorna la lista: quel nome finisce nell'intestazione del PDF ---"
ck "admin rinomina il torneo" "$(cod -X PUT "$D/tornei/$TID" -H "Content-Type: application/json" -H "Authorization: Bearer $TADM" -d "$(corpo "$P-Natale2027" $CAT1 x)")" "200"
ck "  la lista collegata porta il nome nuovo" "$(q "SELECT nome FROM liste_torneo WHERE id=$LID")" "$P-Natale2027"

echo
echo "--- 7. un'altra societa' non vede e non tocca i tornei della prima ---"
ck "admin soc2 legge il torneo -> 403" "$(cod "$D/tornei/$TID" -H "Authorization: Bearer $TSOC")" "403"
ck "admin soc2 lo modifica -> 403" "$(cod -X PUT "$D/tornei/$TID" -H "Content-Type: application/json" -H "Authorization: Bearer $TSOC" -d "$(corpo "$P-di-soc2" $CAT2 x)")" "403"
ck "admin soc2 lo elimina -> 403" "$(cod -X DELETE "$D/tornei/$TID" -H "Authorization: Bearer $TSOC")" "403"
ck "admin soc2 aggiunge una gara -> 403" "$(cod -X POST "$D/tornei/$TID/gare" -H "Content-Type: application/json" -H "Authorization: Bearer $TSOC" -d '{"avversario":"Intrusa"}')" "403"
ck "admin soc2 non lo vede nell'elenco" "$(curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $TSOC" | python3 -c "import sys,json
print(sum(1 for t in json.load(sys.stdin) if t.get('nome','').startswith('$P')))" 2>/dev/null)" "0"
ck "  e il torneo e' ancora intatto" "$(q "SELECT count(*) FROM tornei WHERE id=$TID")" "1"

echo
echo "--- 8. la lista torneo la modificano mister, segreteria e admin: dirigente e scouting no ---"
ck "mister aggiunge un giocatore" "$(cod -X POST "$D/liste-torneo/$LID/giocatori?persona_id=$P1" -H "Authorization: Bearer $TMIS")" "200"
ck "  il conteggio nel dettaglio sale a 1" "$(jq1 "$D/tornei/$TID" "$TMIS" lista.giocatori)" "1"
ck "  l'ordine viene assegnato" "$(q "SELECT ordine FROM liste_torneo_giocatori WHERE lista_id=$LID AND persona_id=$P1")" "0"
ck "segreteria aggiunge un giocatore" "$(cod -X POST "$D/liste-torneo/$LID/giocatori?persona_id=$P1B" -H "Authorization: Bearer $TSEG")" "200"
ck "  lo stesso giocatore due volte -> 400" "$(cod -X POST "$D/liste-torneo/$LID/giocatori?persona_id=$P1" -H "Authorization: Bearer $TMIS")" "400"
for pair in "dirigente:$TDIR" "scouting:$TSCO" "infermeria:$TINF"; do
  n="${pair%%:*}"; t="${pair##*:}"
  ck "$n aggiunge un giocatore -> 403" "$(cod -X POST "$D/liste-torneo/$LID/giocatori?persona_id=$P2" -H "Authorization: Bearer $t")" "403"
  ck "$n rimuove un giocatore -> 403" "$(cod -X DELETE "$D/liste-torneo/$LID/giocatori/$P1" -H "Authorization: Bearer $t")" "403"
  ck "$n elimina l'intera lista -> 403" "$(cod -X DELETE "$D/liste-torneo/$LID" -H "Authorization: Bearer $t")" "403"
  ck "$n crea una lista -> 403" "$(cod -X POST "$D/liste-torneo/" -H "Content-Type: application/json" -H "Authorization: Bearer $t" -d "{\"nome\":\"$P-$n\",\"categoria_id\":$CAT1}")" "403"
  ck "  e la lista e i giocatori sono ancora li'" "$(q "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=$LID")" "2"
done
ck "mister elimina la lista -> 403 (la cancellazione e' dell'admin)" "$(cod -X DELETE "$D/liste-torneo/$LID" -H "Authorization: Bearer $TMIS")" "403"
ck "  il dettaglio della lista resta leggibile al dirigente" "$(cod "$D/liste-torneo/$LID/giocatori" -H "Authorization: Bearer $TDIR")" "200"

echo
echo "--- 9. una persona di un'altra societa' non entra nella lista, e non si legge ---"
ck "mister aggiunge la persona della societa' 2 -> 403" "$(cod -X POST "$D/liste-torneo/$LID/giocatori?persona_id=$P2" -H "Authorization: Bearer $TMIS")" "403"
ck "  e non compare nella lista" "$(q "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=$LID AND persona_id=$P2")" "0"
ck "persona inesistente -> 404" "$(cod -X POST "$D/liste-torneo/$LID/giocatori?persona_id=999999" -H "Authorization: Bearer $TMIS")" "404"
# secondo livello: anche se una riga orfana esiste gia' nel DB (dato vecchio, o un bug futuro
# nella scrittura), GET /giocatori non deve restituire l'anagrafica di un'altra societa'
q "INSERT INTO liste_torneo_giocatori (lista_id,persona_id,ordine) VALUES ($LID,$P2,99);" >/dev/null
ck "con la riga orfana inserita a mano, GET /giocatori non la restituisce" \
   "$(curl -s --max-time 25 "$D/liste-torneo/$LID/giocatori" -H "Authorization: Bearer $TADM" | python3 -c "import sys,json
print(sum(1 for g in json.load(sys.stdin) if g.get('persona_id')==$P2))" 2>/dev/null)" "0"
ck "  e i giocatori legittimi restano visibili" \
   "$(curl -s --max-time 25 "$D/liste-torneo/$LID/giocatori" -H "Authorization: Bearer $TADM" | python3 -c "import sys,json
print(sum(1 for g in json.load(sys.stdin) if g.get('cognome')=='TESTTORNEI'))" 2>/dev/null)" "2"
q "DELETE FROM liste_torneo_giocatori WHERE lista_id=$LID AND persona_id=$P2;" >/dev/null

echo
echo "--- 10. cancellare il torneo si porta dietro calendario e lista, non le liste create a mano ---"
MAN=$(curl -s --max-time 25 -X POST "$D/liste-torneo/" -H "Content-Type: application/json" -H "Authorization: Bearer $TMIS" \
       -d "{\"nome\":\"$P-a-mano\",\"categoria_id\":$CAT1}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
ck "il mister crea una lista a mano (torneo_id NULL)" "$(q "SELECT CASE WHEN torneo_id IS NULL THEN 'null' ELSE 'collegata' END FROM liste_torneo WHERE id=$MAN")" "null"
ck "admin elimina il torneo" "$(cod -X DELETE "$D/tornei/$TID" -H "Authorization: Bearer $TADM")" "200"
ck "  il torneo non c'e' piu'" "$(q "SELECT count(*) FROM tornei WHERE id=$TID")" "0"
ck "  il calendario e' stato cancellato con lui" "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID")" "0"
ck "  la lista collegata se ne va con il torneo" "$(q "SELECT count(*) FROM liste_torneo WHERE id=$LID")" "0"
ck "  e i suoi giocatori con essa" "$(q "SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id=$LID")" "0"
ck "  la lista creata a mano resta" "$(q "SELECT count(*) FROM liste_torneo WHERE id=$MAN")" "1"
ck "  eliminare di nuovo lo stesso torneo -> 404" "$(cod -X DELETE "$D/tornei/$TID" -H "Authorization: Bearer $TADM")" "404"
ck "admin elimina la lista creata a mano" "$(cod -X DELETE "$D/liste-torneo/$MAN" -H "Authorization: Bearer $TADM")" "200"
# anche il secondo torneo creato in preparazione: il confronto con la baseline qui sotto ha
# senso solo se il test ha rilasciato tutto cio' che ha creato, altrimenti "liste preesistenti"
# conta anche il lavoro del test e il verde/rosso dipende dall'ordine delle sezioni
ck "admin elimina anche il secondo torneo" "$(cod -X DELETE "$D/tornei/$TID2" -H "Authorization: Bearer $TADM")" "200"
ck "  il suo calendario se ne va con lui" "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID2")" "0"
ck "  e la sua lista collegata" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$TID2")" "0"

echo
echo "--- 11. il lavoro gia' presente nel DB non e' stato toccato ---"
ck "le liste preesistenti sono ancora $BASE_LISTE" "$(q "SELECT count(*) FROM liste_torneo")" "$BASE_LISTE"
ck "i giocatori preesistenti sono ancora $BASE_GIOC" "$(q "SELECT count(*) FROM liste_torneo_giocatori")" "$BASE_GIOC"
ck "i tornei sono tornati a $BASE_TORNEI" "$(q "SELECT count(*) FROM tornei")" "$BASE_TORNEI"

echo
echo "--- pulizia ---"
pulizia
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM tornei WHERE nome LIKE '$P%')
 +(SELECT count(*) FROM tornei_gare g JOIN tornei t ON t.id=g.torneo_id WHERE t.nome LIKE '$P%')
 +(SELECT count(*) FROM liste_torneo WHERE nome LIKE '$P%')
 +(SELECT count(*) FROM liste_torneo_giocatori WHERE lista_id IN (SELECT id FROM liste_torneo WHERE nome LIKE '$P%'))
 +(SELECT count(*) FROM persone WHERE upper(cognome)='TESTTORNEI')
 +(SELECT count(*) FROM categorie WHERE nome LIKE '$P%')
 +(SELECT count(*) FROM utenti WHERE username LIKE 'testtornei%')")" "0"
ck "  e i dati reali sono ancora intatti" "$(q "SELECT (SELECT count(*) FROM liste_torneo)-(SELECT count(*) FROM liste_torneo WHERE nome LIKE '$P%')")" "$BASE_LISTE"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
