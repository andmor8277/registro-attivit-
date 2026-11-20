#!/bin/bash
# Tornei con piu' categorie iscritte: il foglio giocatori uno per categoria, il calendario
# suddiviso come quello del weekend, e le guardie che ne conseguono.
#
# Perche' questo file esiste accanto a test_tornei.sh: quel file prova il torneo con UNA categoria,
# che era il modello di ieri. Qui si prova il modello nuovo -- tornei_categorie -- e soprattutto le
# tre cose che si rompono per prime quando un torneo prende due categorie:
#   1. il foglio da consegnare all'organizzatore deve essere UNO PER CATEGORIA, non uno solo;
#   2. il filtro per categoria deve guardare le ISCRIZIONI, non tornei.categoria_id (che e' solo la
#      "prima"): altrimenti il mister che cerca la seconda categoria non vede il torneo;
#   3. una gara non puo' finire in una categoria a caso quando le iscritte sono piu' d'una: sarebbe
#      un calendario plausibile e falso, e il file consegnato sarebbe quello sbagliato.
#
# Crea solo oggetti marcati __test_torneicat__ / testtorneicat e li rimuove alla fine. I conteggi
# di partenza sono MISURATI qui, non scritti nel file: un DB che cresce non deve rendere rosso
# niente (e' l'errore che i test PROD hanno gia' commesso una volta).
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
# Due valori vuoti non sono "uguali": sono un test che non ha misurato niente. Con i token vuoti
# le asserzioni sotto confrontavano '' con '' e dicevano ok.
ck() { if [ -z "$2" ] && [ -z "$3" ]; then fail=$((fail+1)); echo "  FAIL $1 -> entrambi vuoti: il test non ha misurato nulla"; return; fi
       if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi; }
ckmin() { if [ -n "$2" ] && [ "$2" -ge "$3" ]; then pass=$((pass+1)); echo "  ok   $1 ($2 >= $3)"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (minimo $3)"; fi; }

# /auth/token ha @limiter.limit("10/minute") per worker: senza retry il test diventa rosso per il
# rate limiter e non per la logica che sta provando
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
cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 "$@"; }
det() { curl -s --max-time 25 "$@" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('detail',''))
except Exception: print('')" 2>/dev/null; }
# campo del dettaglio: accetta "categorie.0.anno" e "liste.1.categoria_id". Serve gestire gli indici
# perche' categorie e liste arrivano come array
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
# lunghezza di un array della risposta: senza, "il torneo ha due fogli" resterebbe un'ipotesi
jqlen() { curl -s --max-time 25 "$1" -H "Authorization: Bearer $2" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
d=d[0] if isinstance(d,list) and d else d
v=d
for k in '$3'.split('.'):
    v=v.get(k) if isinstance(v,dict) else None
print('' if v is None else len(v))" 2>/dev/null; }
# "il torneo compare in questa lista?" fatto col parser, non col grep: grep su '"id":12,' dipende
# da come il serializzatore spaziatura i due punti, e quando cambia il test diventa rosso per la
# forma della risposta invece che per la regola che vuole provare
contiene() { curl -s --max-time 25 "$1" -H "Authorization: Bearer $2" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
if not isinstance(d,list): d=[d]
print('si' if any(isinstance(t,dict) and t.get('id')==$3 for t in d) else 'no')" 2>/dev/null; }

P=__test_torneicat__
U=testtorneicat

echo "--- preparazione (solo oggetti di prova) ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }

pulizia() {
  q "DELETE FROM tornei_gare WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%');
     DELETE FROM tornei_categorie WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%');
     DELETE FROM liste_torneo_giocatori WHERE lista_id IN (SELECT id FROM liste_torneo WHERE nome LIKE '$P%');
     DELETE FROM liste_torneo WHERE nome LIKE '$P%';
     DELETE FROM tornei WHERE nome LIKE '$P%';
     DELETE FROM utente_categorie WHERE categoria_id IN (SELECT id FROM categorie WHERE nome LIKE '$P%');
     DELETE FROM categorie WHERE nome LIKE '$P%';
     DELETE FROM login_bloccaggi WHERE chiave LIKE '$U%';
     DELETE FROM utenti WHERE username LIKE '$U%';" >/dev/null
}
pulizia

# Baseline MISURATA: le liste e i tornei che gia' esistono in DEV non devono essere toccati.
BASE_LISTE=$(q "SELECT count(*) FROM liste_torneo")
BASE_TORNEI=$(q "SELECT count(*) FROM tornei")
BASE_ISCR=$(q "SELECT count(*) FROM tornei_categorie")
echo "  baseline: liste=$BASE_LISTE tornei=$BASE_TORNEI iscrizioni=$BASE_ISCR"

# Tre categorie con anni DIVERSI: servono per provare che il calendario e le liste escono ordinate
# per anno e non nell'ordine in cui sono state iscritte
q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES
     (1,'$P-a',1901,0),(1,'$P-b',1902,0),(1,'$P-c',1903,0),(2,'$P-x',1901,0);" >/dev/null
CA=$(q "SELECT id FROM categorie WHERE nome='$P-a'")
CB=$(q "SELECT id FROM categorie WHERE nome='$P-b'")
CC=$(q "SELECT id FROM categorie WHERE nome='$P-c'")
CX=$(q "SELECT id FROM categorie WHERE nome='$P-x'")

# Username scritti per esteso, non '$U_adm': in bash il underscore e' un carattere valido nei nomi
# di variabile, quindi "$U_adm" viene letto come la variabile U_adm e finisce nel DB una riga vuota
# (o peggio, il valore di un'altra variabile). Il test esistente fa cosi' e per la stessa ragione.
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testtorneicat_admin','$HASH',1,1,0,NULL),
          ('testtorneicat_mister','$HASH',1,0,0,'mister'),
           ('testtorneicat_s2','$HASH',2,1,0,NULL);" >/dev/null
TADM=$(tok testtorneicat_admin "$PW"); TMIS=$(tok testtorneicat_mister "$PW"); TS2=$(tok testtorneicat_s2 "$PW")
for pair in "admin:$TADM" "mister:$TMIS" "admin soc2:$TS2"; do
  if [ -z "${pair##*:}" ]; then
    echo "  login ${pair%%:*} fallito: senza token le asserzioni sotto confrontano vuoto con vuoto, mi fermo"
    pulizia; echo; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1
  fi
done
echo "  cat a=$CA b=$CB c=$CC (soc2) x=$CX"

post() { curl -s --max-time 25 -X POST "$D$1" -H "Authorization: Bearer $2" \
          -H 'Content-Type: application/json' -d "$3"; }

echo
echo "--- 1. un torneo puo' iscrivere due categorie, e i fogli nascono da soli ---"
R=$(post /tornei/ "$TADM" "{\"nome\":\"$P-multi\",\"categorie_id\":[$CA,$CB],\"data_inizio\":\"2026-12-20\",\"data_fine\":\"2027-01-06\"}")
TID=$(printf '%s' "$R" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('id',''))
except Exception: print('')" 2>/dev/null)
ck "POST /tornei/ con due categorie restituisce un id" "$([ -n "$TID" ] && echo si)" "si"
ck "la risposta dichiara due fogli giocatori" "$(printf '%s' "$R" | python3 -c "import sys,json
try: print(len(json.load(sys.stdin).get('liste') or []))
except Exception: print('')" 2>/dev/null)" "2"
ck "tornei_categorie ha due iscrizioni" "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$TID")" "2"
ck "liste_torneo ha due fogli per il torneo" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$TID")" "2"
ck "i due fogli sono di categorie diverse" "$(q "SELECT count(DISTINCT categoria_id) FROM liste_torneo WHERE torneo_id=$TID")" "2"
# Il nome del foglio finisce nell'intestazione del PDF: due fogli chiamati entrambi "Winter Cup"
# non dicono all'organizzatore quali sono i Pulcini e quali gli Esordienti
ck "il nome del foglio porta la categoria" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$TID AND nome LIKE '%$P-multi%1901%'")" "1"
ck "i due fogli si chiamano in modo diverso" "$(q "SELECT count(DISTINCT nome) FROM liste_torneo WHERE torneo_id=$TID")" "2"

echo
echo "--- 2. il dettaglio riporta categorie e fogli, ordinati per anno ---"
ck "GET /tornei/{id} elenca due categorie" "$(jqlen "$D/tornei/$TID" "$TADM" categorie)" "2"
ck "GET /tornei/{id} elenca due fogli" "$(jqlen "$D/tornei/$TID" "$TADM" liste)" "2"
# Ordinati per anno, NON nell'ordine di iscrizione: qui CB (1902) e' stata iscritta seconda e CA
# (1901) prima, ma se l'ordine dipendesse dall'iscrizione un'inversione passerebbe inosservata
ck "la prima categoria e' quella con l'anno minore" "$(jq1 "$D/tornei/$TID" "$TADM" categorie.0.anno)" "1901"
ck "la seconda categoria ha l'anno maggiore" "$(jq1 "$D/tornei/$TID" "$TADM" categorie.1.anno)" "1902"

echo
echo "--- 3. il filtro per categoria guarda le ISCRIZIONI, non la 'prima' categoria ---"
# E' il guasto che il modello nuovo portava dentro: tornei.categoria_id contiene solo la prima,
# quindi filtrare su quella nasconderebbe il torneo al mister della seconda categoria
ck "filtrando per la SECONDA categoria il torneo c'e'" \
   "$(contiene "$D/tornei/?categoria_id=$CB" "$TADM" $TID)" "si"
ck "filtrando per la prima categoria il torneo c'e'" \
   "$(contiene "$D/tornei/?categoria_id=$CA" "$TADM" $TID)" "si"
ck "filtrando per una categoria NON iscritta il torneo non c'e'" \
   "$(contiene "$D/tornei/?categoria_id=$CC" "$TADM" $TID)" "no"

echo
echo "--- 4. la gara deve dire a quale categoria appartiene, quando le iscritte sono due ---"
cod_gara() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/tornei/$TID/gare" \
               -H "Authorization: Bearer $TADM" -H 'Content-Type: application/json' -d "$1"; }
ck "gara senza categoria, con due iscritte -> 400" "$(cod_gara '{"avversario":"Senza categoria"}')" "400"
ck "gara di categoria NON iscritta -> 400" "$(cod_gara "{\"avversario\":\"Straniera\",\"categoria_id\":$CC}")" "400"
ck "gara della prima categoria -> 200" "$(cod_gara "{\"avversario\":\"Avversario A\",\"categoria_id\":$CA,\"data\":\"2026-12-21\"}")" "200"
ck "gara della seconda categoria -> 200" "$(cod_gara "{\"avversario\":\"Avversario B\",\"categoria_id\":$CB,\"data\":\"2026-12-22\"}")" "200"
ck "il calendario riporta due gare" "$(jqlen "$D/tornei/$TID" "$TADM" gare)" "2"
# Il raggruppamento per categoria si fida dell'ordine dell'API, esattamente come fa il weekend:
# se l'ordine fosse sbagliato il frontend mostrerebbe le sezioni mescolate
ck "le gare escono ordinate per categoria (anno)" "$(jq1 "$D/tornei/$TID" "$TADM" gare.0.categoria_anno)" "1901"
ck "la seconda gara e' dell'altra categoria" "$(jq1 "$D/tornei/$TID" "$TADM" gare.1.categoria_anno)" "1902"
ck "la gara porta il nome della sua categoria" "$(jq1 "$D/tornei/$TID" "$TADM" gare.0.categoria_nome)" "$(q "SELECT nome FROM categorie WHERE id=$CA")"

echo
echo "--- 5. retrocompatibilita': il payload vecchio con una sola categoria funziona ancora ---"
R1=$(post /tornei/ "$TADM" "{\"nome\":\"$P-mono\",\"categoria_id\":$CC}")
T1=$(printf '%s' "$R1" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('id',''))
except Exception: print('')" 2>/dev/null)
ck "POST con il vecchio campo categoria_id crea il torneo" "$([ -n "$T1" ] && echo si)" "si"
ck "il torneo mono-categoria ha un solo foglio" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$T1")" "1"
ck "gara senza categoria, con UNA iscritta -> 200 (la deduce)" \
   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/tornei/$T1/gare" \
        -H "Authorization: Bearer $TADM" -H 'Content-Type: application/json' \
        -d '{"avversario":"Dedotta"}')" "200"
ck "la gara dedotta ha la categoria giusta" \
   "$(q "SELECT categoria_id FROM tornei_gare WHERE torneo_id=$T1")" "$CC"

echo
echo "--- 6. iscrivere una categoria dopo porta con se' il suo foglio ---"
ck "POST /tornei/{id}/categorie -> 200" \
   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/tornei/$TID/categorie" \
        -H "Authorization: Bearer $TADM" -H 'Content-Type: application/json' -d "{\"categoria_id\":$CC}")" "200"
ck "le iscrizioni sono diventate tre" "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$TID")" "3"
# Il foglio nasce da solo: se dipendesse da un passaggio manuale del mister, in due anni di liste
# ne sarebbe uscita una sola
ck "il terzo foglio e' stato creato da solo" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$TID")" "3"
R2=$(post /tornei/$TID/categorie "$TADM" "{\"categoria_id\":$CC}")
ck "iscrivere due volte la stessa categoria non esplode" \
   "$(printf '%s' "$R2" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('gia_iscritta',''))
except Exception: print('')" 2>/dev/null)" "True"
ck "il doppio click NON crea un secondo foglio" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$TID")" "3"

echo
echo "--- 7. togliere una categoria: le gare la proteggono, il foglio no ---"
cod_rim() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X DELETE "$D/tornei/$TID/categorie/$1" \
              -H "Authorization: Bearer $TADM"; }
# Una gara rimasta senza categoria sarebbe un buco nel calendario: chi la cancella deve farlo
# consapevolmente, non perche' l'iscrizione e' scivolata via
ck "rimuovere una categoria che ha gare -> 400" "$(cod_rim $CA)" "400"
ck "la categoria e' ancora iscritta dopo il rifiuto" "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$TID AND categoria_id=$CA")" "1"
GARA=$(q "SELECT id FROM tornei_gare WHERE torneo_id=$TID AND categoria_id=$CA LIMIT 1")
q "DELETE FROM tornei_gare WHERE id=$GARA;" >/dev/null
ck "rimuovere la categoria rimasta senza gare -> 200" "$(cod_rim $CA)" "200"
ck "le iscrizioni sono tornate due" "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$TID")" "2"
# Il lavoro sui giocatori non si perde perche' il responsabile ha cambiato idea: il foglio si
# distacca (torneo_id NULL) invece di essere cancellato
ck "il foglio della categoria rimossa NON e' stato cancellato" \
   "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id IS NULL AND categoria_id=$CA AND nome LIKE '$P-multi%'")" "1"
# CB (1902) e CC (1903) restano; la "prima" deve diventare CB, perche' e' li' che il badge della
# card e l'ingresso da Scelta.vue vanno a guardare
ck "la 'prima' categoria del torneo e' stata riassegnata" \
   "$(q "SELECT categoria_id FROM tornei WHERE id=$TID")" "$CB"

echo
echo "--- 8. PUT non tocca le categorie (le gestiscono le rotte loro) ---"
curl -s --max-time 25 -X PUT "$D/tornei/$TID" -H "Authorization: Bearer $TADM" \
     -H 'Content-Type: application/json' \
     -d "{\"nome\":\"$P-rinominato\",\"categorie_id\":[$CC]}" >/dev/null
ck "il PUT rinomina il torneo" "$(q "SELECT nome FROM tornei WHERE id=$TID")" "$P-rinominato"
ck "il PUT NON ha toccato le iscrizioni" "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$TID")" "2"
ck "i fogli seguono il nuovo nome del torneo" \
   "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$TID AND nome LIKE '$P-rinominato%'")" "2"

echo
echo "--- 9. confine fra le societa' ---"
ck "creare un torneo con una categoria di un'altra societa' -> 403" \
   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/tornei/" \
        -H "Authorization: Bearer $TADM" -H 'Content-Type: application/json' \
        -d "{\"nome\":\"$P-ladra\",\"categorie_id\":[$CX]}")" "403"
ck "iscrivere una categoria di un'altra societa' -> 403" \
   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/tornei/$TID/categorie" \
        -H "Authorization: Bearer $TADM" -H 'Content-Type: application/json' \
        -d "{\"categoria_id\":$CX}")" "403"
ck "la societa' vicina non vede il torneo -> 403" "$(cod "$D/tornei/$TID" -H "Authorization: Bearer $TS2")" "403"
ck "scrivere le categorie non e' del mister -> 403" \
   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/tornei/$TID/categorie" \
        -H "Authorization: Bearer $TMIS" -H 'Content-Type: application/json' \
        -d "{\"categoria_id\":$CC}")" "403"

echo
echo "--- 10. il database tiene lui, non solo l'API ---"
ck "esiste l'UNIQUE (torneo_id, categoria_id)" \
   "$(q "SELECT count(*) FROM pg_constraint WHERE conname='uq_tornei_categorie'")" "1"
ck "tornei_gare.categoria_id ha la sua FK" \
   "$(q "SELECT count(*) FROM pg_constraint WHERE conrelid='tornei_gare'::regclass AND contype='f' AND confrelid='categorie'::regclass")" "1"
ck "il foglio e' unico per (torneo, categoria)" \
   "$(q "SELECT count(*) FROM pg_indexes WHERE tablename='liste_torneo' AND indexname='ux_liste_torneo_torneo_categoria'")" "1"
# Il vincolo vecchio diceva "un torneo produce una sola lista": con le categorie multiple era
# sbagliato, non solo stretto. Se fosse ancora li' il terzo foglio non sarebbe nato.
ck "il vecchio UNIQUE 'un torneo una lista' non c'e' piu'" \
   "$(q "SELECT count(*) FROM pg_indexes WHERE tablename='liste_torneo' AND indexname='ux_liste_torneo_torneo'")" "0"
# Prova DIRETTA del vincolo, scavalcando l'API. Contare che il vincolo "esiste" non dimostra che
# funzioni: qui si tenta davvero l'iscrizione duplicata e si verifica che il database la rifiuti.
# E' lo stesso criterio usato per i test che "devono saper fallire": un negative test che non cambia
# nessun output non ha testato niente.
DUP_ERR=$(q "INSERT INTO tornei_categorie (torneo_id,categoria_id) VALUES ($TID,$CB);" 2>&1 | grep -ci duplicate)
ck "il DB rifiuta l'iscrizione duplicata (prova diretta)" "$DUP_ERR" "1"
ck "dopo il tentativo rifiutato le iscrizioni restano due" \
   "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$TID")" "2"

echo
echo "--- 11. cancellare il torneo porta via iscrizioni e fogli ---"
curl -s --max-time 25 -X DELETE "$D/tornei/$TID" -H "Authorization: Bearer $TADM" >/dev/null
ck "il torneo e' sparito" "$(q "SELECT count(*) FROM tornei WHERE id=$TID")" "0"
ck "le sue iscrizioni sono sparite con lui" "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$TID")" "0"
ck "i suoi fogli sono spariti con lui" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id=$TID")" "0"
ck "le sue gare sono sparite" "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID")" "0"

echo
echo "--- 12. niente residui: il test riporta il DB alla baseline ---"
pulizia
ck "tornei tornati alla baseline" "$(q "SELECT count(*) FROM tornei")" "$BASE_TORNEI"
ckmin "liste non sotto la baseline (il test non ne ha cancellate di altrui)" "$(q "SELECT count(*) FROM liste_torneo")" "$BASE_LISTE"
ck "liste tornate alla baseline" "$(q "SELECT count(*) FROM liste_torneo")" "$BASE_LISTE"
ck "iscrizioni tornate alla baseline" "$(q "SELECT count(*) FROM tornei_categorie")" "$BASE_ISCR"
ck "nessun utente di prova residuo" "$(q "SELECT count(*) FROM utenti WHERE username LIKE '$U%'")" "0"
ck "nessuna categoria di prova residua" "$(q "SELECT count(*) FROM categorie WHERE nome LIKE '$P%'")" "0"

echo
echo "  ------------------------------------------------------------------"
echo "  $pass passati, $fail falliti"
[ "$fail" -eq 0 ]
