#!/bin/bash
# La pagina Tornei e' suddivisa PER CATEGORIA: la sezione "2016 - Pulcini" e' il primo livello e il
# torneo si ripete dentro ciascuna delle sue categorie iscritte. Per farlo la lista dei tornei deve
# restituire i conteggi GIusti per sezione, e qui si prova proprio quello.
#
# Perche' questo file esiste accanto a test_tornei.sh e test_tornei_categorie.sh: quelli provano le
# regole di scrittura (fogli, iscrizioni, 400 sulla gara senza categoria). Nessuno prova cio' che la
# pagina legge per dipingersi, e sono tre bug silenziosi che nessun altro test vede:
#   1. "6 gare" nella sezione Pulcini sarebbe falso se 4 sono degli Esordienti: il conteggio deve
#      essere PER categoria, non il totale del torneo;
#   2. una categoria iscritta senza gare non deve avere una chiave, o la pagina stampa un badge "0
#      gare" accanto a un calendario vuoto;
#   3. le gare orfane -- categoria NULL (i dati nati prima della migrazione) o puntate a una
#      categoria non piu' iscritta -- non hanno una sezione dove comparire: se il conteggio le
#      dimentica, la pagina le elenca ma dichiara di non averne.
#
# Crea solo oggetti marcati __test_sezioni__ / testsezioni e li rimuove alla fine. I conteggi di
# partenza sono MISURATI qui: un DB che cresce non deve rendere rosso niente.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
# Due valori vuoti non sono "uguali": sono un test che non ha misurato niente
ck() { if [ -z "$2" ] && [ -z "$3" ]; then fail=$((fail+1)); echo "  FAIL $1 -> entrambi vuoti: il test non ha misurato nulla"; return; fi
       if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi; }

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

# Legge la lista /tornei/ e ne estrae il campo di UN torneo, perche' la risposta e' un array e il
# nostro torneo sta in mezzo a quelli veri di DEV
riga() { curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $1" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
t=next((x for x in d if x.get('id')==$2), None)
print('' if t is None else t.get('$3',''))" 2>/dev/null; }
# Come sopra ma per una chiave dell'oggetto gare_per_categoria; "assente" e un valore distinguibile
# da "0", che sono due risposte diverse (la prima dice "nessuna gara qui", la seconda e' un bug)
gpc() { curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $1" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
t=next((x for x in d if x.get('id')==$2), None)
if t is None: print(''); raise SystemExit
g=t.get('gare_per_categoria')
if not isinstance(g,dict): print('NON-OGGETTO'); raise SystemExit
print(g[str($3)] if str($3) in g else 'assente')" 2>/dev/null; }
# Il tipo conta: la pagina indicizza l'oggetto con gare_per_categoria[catId]. Se qualcuno lo cambia
# in una lista di coppie, la pagina non stampa piu' nessun badge e non succede nessun errore
tipo_gpc() { curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $1" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
t=next((x for x in d if x.get('id')==$2), None)
print('' if t is None else type(t.get('gare_per_categoria')).__name__)" 2>/dev/null; }

P=__test_sezioni__
U=testsezioni

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
echo "  baseline: tornei=$(q 'SELECT count(*) FROM tornei') gare=$(q 'SELECT count(*) FROM tornei_gare')"

# Quattro categorie con anni DIVERSI: tre iscritte al torneo (di cui una senza gare) e una che non
# viene mai iscritta, che e' la destinazione delle gare orfane "categoria non piu' iscritta"
q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES
     (1,'$P-a',1901,0),(1,'$P-b',1902,0),(1,'$P-d',1903,0),(1,'$P-c',1904,0);" >/dev/null
CA=$(q "SELECT id FROM categorie WHERE nome='$P-a'")
CB=$(q "SELECT id FROM categorie WHERE nome='$P-b'")
CD=$(q "SELECT id FROM categorie WHERE nome='$P-d'")
CC=$(q "SELECT id FROM categorie WHERE nome='$P-c'")

# Username scritti per esteso: in bash "$U_adm" viene letto come la variabile U_adm
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testsezioni_admin','$HASH',1,1,0,NULL);" >/dev/null
TADM=$(tok testsezioni_admin "$PW")
if [ -z "$TADM" ]; then
  echo "  login admin fallito: senza token le asserzioni sotto confrontano vuoto con vuoto, mi fermo"
  pulizia; echo; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1
fi
echo "  cat a=$CA b=$CB d=$CD (iscritta, senza gare) c=$CC (NON iscritta)"

post() { curl -s --max-time 25 -X POST "$D$1" -H "Authorization: Bearer $2" \
          -H 'Content-Type: application/json' -d "$3"; }

echo
echo "--- 1. torneo senza gare: la pagina deve poter distinguere 'zero' da 'non lo so' ---"
R=$(post /tornei/ "$TADM" "{\"nome\":\"$P-campionato\",\"categorie_id\":[$CA,$CB,$CD],\"data_inizio\":\"2026-12-20\",\"data_fine\":\"2027-01-06\"}")
TID=$(printf '%s' "$R" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('id',''))
except Exception: print('')" 2>/dev/null)
ck "POST /tornei/ con tre categorie restituisce un id" "$([ -n "$TID" ] && echo si)" "si"
ck "il torneo compare nella lista" "$(curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $TADM" | python3 -c "
import sys,json
d=json.load(sys.stdin); print('si' if any(t.get('id')==$TID for t in d) else 'no')" 2>/dev/null)" "si"
ck "gare_per_categoria e un oggetto (la pagina lo indicizza per categoria)" "$(tipo_gpc "$TADM" "$TID")" "dict"
ck "senza gare il conteggio e un oggetto vuoto, non null" "$(riga "$TADM" "$TID" "gare_per_categoria")" "{}"
ck "senza gare le orfane sono 0" "$(riga "$TADM" "$TID" "gare_orfane")" "0"
ck "senza gare il totale e 0" "$(riga "$TADM" "$TID" "gare")" "0"

echo
echo "--- 2. il conteggio deve essere PER categoria, non il totale del torneo ---"
for i in 1 2; do
  post /tornei/$TID/gare "$TADM" "{\"categoria_id\":$CA,\"avversario\":\"$P-gara-a$i\",\"data\":\"2026-12-21\"}" >/dev/null
done
post /tornei/$TID/gare "$TADM" "{\"categoria_id\":$CB,\"avversario\":\"$P-gara-b1\",\"data\":\"2026-12-22\"}" >/dev/null
ck "due gare nella categoria a" "$(gpc "$TADM" "$TID" "$CA")" "2"
ck "una gara nella categoria b" "$(gpc "$TADM" "$TID" "$CB")" "1"
ck "il totale del torneo e 3, cioe' NESSUNA sezione legge il totale" "$(riga "$TADM" "$TID" "gare")" "3"
# Questa e' l'asserzione che manca se qualcuno torna a un conteggio solo: il badge della sezione a
# deve dire 2, non 3, perche' una delle tre e' dell'altra categoria
ck "la sezione a non mostra il totale (2, non 3)" "$(gpc "$TADM" "$TID" "$CA")" "2"
ck "la categoria iscritta senza gare non ha una chiave (niente badge '0 gare')" "$(gpc "$TADM" "$TID" "$CD")" "assente"
ck "le orfane restano 0 con un calendario tutto etichettato" "$(riga "$TADM" "$TID" "gare_orfane")" "0"

echo
echo "--- 3. le gare orfane: NULL (dati pre-migrazione) e categoria non iscritta ---"
# Via SQL di proposito: dall'API una gara senza categoria non puo' nascere, con tre iscritte arriva
# un 400. Queste sono le righe vecchie, quelle che la suddivisione per categorie deve comunque
# mostrare invece di perderle
q "INSERT INTO tornei_gare (torneo_id, avversario, data) VALUES ($TID, '$P-orfana-null', '2026-12-23');" >/dev/null
q "INSERT INTO tornei_gare (torneo_id, categoria_id, avversario, data)
   VALUES ($TID, $CC, '$P-orfana-noniscritta', '2026-12-24');" >/dev/null
ck "il calendario ha 5 gare in tutto" "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID")" "5"
ck "il totale della lista dice 5 (le orfane non spariscono dal conteggio)" "$(riga "$TADM" "$TID" "gare")" "5"
ck "due gare sono senza una sezione dove apparire" "$(riga "$TADM" "$TID" "gare_orfane")" "2"
ck "una gara con categoria NULL conta come orfana" "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID AND categoria_id IS NULL")" "1"
ck "una gara verso una categoria non iscritta conta come orfana" "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID AND categoria_id=$CC")" "1"
ck "le due categorie iscritte non cambiano conteggio" "$(gpc "$TADM" "$TID" "$CA")/$(gpc "$TADM" "$TID" "$CB")" "2/1"

echo
echo "--- 4. il filtro per categoria porta ancora il torneo, coi suoi conteggi ---"
# La sezione si costruisce anche col filtro attivo: se la lista filtrata perdesse i conteggi, la
# pagina mostrerebbe le sezioni senza nessun numero
ck "filtrando per la categoria b il torneo c'e'" "$(curl -s --max-time 25 "$D/tornei/?categoria_id=$CB" -H "Authorization: Bearer $TADM" | python3 -c "
import sys,json
d=json.load(sys.stdin); print('si' if any(t.get('id')==$TID for t in d) else 'no')" 2>/dev/null)" "si"
ck "filtrando per la categoria d, che non ha gare, il torneo c'e' lo stesso" "$(curl -s --max-time 25 "$D/tornei/?categoria_id=$CD" -H "Authorization: Bearer $TADM" | python3 -c "
import sys,json
d=json.load(sys.stdin); print('si' if any(t.get('id')==$TID for t in d) else 'no')" 2>/dev/null)" "si"
ck "la lista filtrata porta gare_per_categoria" "$(curl -s --max-time 25 "$D/tornei/?categoria_id=$CB" -H "Authorization: Bearer $TADM" | python3 -c "
import sys,json
d=json.load(sys.stdin)
t=next((x for x in d if x.get('id')==$TID), None)
g=(t or {}).get('gare_per_categoria')
print('si' if isinstance(g,dict) and g.get(str($CB)) == 1 else 'no')" 2>/dev/null)" "si"
ck "la lista filtrata porta gare_orfane" "$(curl -s --max-time 25 "$D/tornei/?categoria_id=$CB" -H "Authorization: Bearer $TADM" | python3 -c "
import sys,json
d=json.load(sys.stdin)
t=next((x for x in d if x.get('id')==$TID), None)
print((t or {}).get('gare_orfane',''))" 2>/dev/null)" "2"

echo
echo "--- 5. un altro tenant non legge i conteggi del torneo ---"
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('testsezioni_s2','$HASH',2,1,0,NULL);" >/dev/null
TS2=$(tok testsezioni_s2 "$PW")
if [ -z "$TS2" ]; then
  echo "  login soc2 fallito: mi fermo, perche' 'non lo vedo' e 'non ho il token' sono due risposte diverse"
  pulizia; echo; echo "  $pass passati, $((fail+1)) falliti (prerequisiti)"; exit 1
fi
ck "l'admin di un'altra societa' non vede il torneo" "$(curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $TS2" | python3 -c "
import sys,json
d=json.load(sys.stdin); print('no' if any(t.get('id')==$TID for t in d) else 'si')" 2>/dev/null)" "si"
ck "e non ne riceve i conteggi" "$(curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $TS2" | python3 -c "
import sys,json
d=json.load(sys.stdin)
t=next((x for x in d if x.get('id')==$TID), None)
print('presente' if t is not None and 'gare_orfane' in t else 'assente')" 2>/dev/null)" "assente"

echo
echo "--- ripulitura ---"
pulizia
ck "nessun residuo dei dati di prova" "$(q "SELECT count(*) FROM tornei WHERE nome LIKE '$P%'")" "0"
ck "nessuna gara orfana dei dati di prova" "$(q "SELECT count(*) FROM tornei_gare WHERE avversario LIKE '$P%'")" "0"

echo
echo "  $pass passati, $fail falliti"
[ "$fail" -gt 0 ] && exit 1
exit 0
