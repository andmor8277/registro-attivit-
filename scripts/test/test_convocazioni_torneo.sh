#!/bin/bash
# Convocazioni delle gare di TORNEO + calendario gare scritto dai mister.
#
# Perche' questo file esiste. Due regole nuove, entrambe con un modo silenzioso di rompersi:
#
# 1. Il foglio di convocazione di una gara di torneo riusa le tabelle del weekend (`convocazioni`,
#    `convocazione_gare`, `convocazione_giocatori`) con un discriminatore, `tornei_gara_id`. Il codice
#    che ha attorno esige un weekend, indovina la partita con `WHERE categoria_id AND data_partite`,
#    INSERTA in `partite` se non la trova e fa upsert su `campi_sportivi`. Se un foglio di torneo
#    attraversasse anche una sola di quelle righe, il danno NON sarebbe un errore: sarebbe una partita
#    di campionato inventata, o una convocazione agganciata alla gara sbagliata della stessa sera. Per
#    questo meta' delle asserzioni qui sotto guarda `partite` e dice "non deve essere cambiata".
#
# 2. Il calendario gare e' passato da "solo admin" a "mister + admin", mentre il resto dei tornei
#    (creare il torneo, iscrivere categorie) e' rimasto dell'admin. Un gate troppo largo darebbe a un
#    dirigente la possibilita' di riscrivere un calendario; uno troppo stretto lascerebbe il mister
#    senza la gara che l'organizzatore gli ha comunicato ieri sera.
#
# Crea solo oggetti marcati __test_conv__ / testconv e li rimuove alla fine. Nessuno dei conteggi e'
# scritto a mano: le baseline si misurano qui, perche' un DB che cresce non deve rendere rosso niente.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE=registro_presenze-backend-1
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" 2>&1 | tr -d '\r'; }

pass=0; fail=0
# Due valori vuoti NON sono "uguali": con i token vuoti le asserzioni confrontavano '' con '' e dicevano ok.
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
det() { curl -s --max-time 25 "$@" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('detail',''))
except Exception: print('')" 2>/dev/null; }
# campo della risposta col parser, non col grep: grep su '"id":12,' dipende dalla spaziatura del
# serializzatore, e quando cambia il test diventa rosso per la forma della risposta
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
# il CODICE HTTP delle scritture: senza, una mutazione che non parte affatto lascia le asserzioni verdi
# perche' confrontano il valore vecchio con se stesso (gia' successo in test_tornei_mister.sh)
post_cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$1" -H "Content-Type: application/json" \
             ${3:+-H "Authorization: Bearer $3"} -d "$2"; }
put_cod()  { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X PUT  "$1" -H "Content-Type: application/json" \
             ${3:+-H "Authorization: Bearer $3"} -d "$2"; }
del_cod()  { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X DELETE "$1" \
             ${2:+-H "Authorization: Bearer $2"}; }
# id restituito da una POST
post_id()  { curl -s --max-time 25 -X POST "$1" -H "Content-Type: application/json" \
             ${3:+-H "Authorization: Bearer $3"} -d "$2" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('id',''))
except Exception: print('')" 2>/dev/null; }
# la risposta contiene una data id?
contiene_id() { curl -s --max-time 25 "$1" -H "Authorization: Bearer $2" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print('')
print('si' if isinstance(d,list) and any(t.get('id')==$3 for t in d) else 'no')" 2>/dev/null; }

P=__test_conv__
U=testconv
SOC=1
SOC_ALTRA=2

echo "--- preparazione ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  FAIL prerequisito: impossibile generare l'hash bcrypt: il test non puo' misurare niente"; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }

# Pulizia iniziale con gli STESSI pattern di quella finale: un residuo di un run interrotto falserebbe
# le baseline (e' il motivo per cui la sentinella di un altro test non arrivava mai alla sua).
#
# L'ordine NON e' indifferente: prima i figli, poi i padri. `partite.categoria_id`, `tornei_gare.categoria_id`
# e `tornei_categorie.categoria_id` sono FK NO ACTION, quindi cancellare le categorie con una partita ancora
# legata non e' un errore che si vede — `q` gira con lo stderr scartato e la riga resta li', verde.
# E' successo: la pulizia lasciava 2 categorie perche' la DELETE su `partite` stava piu' in basso.
pulisci() {
q "DELETE FROM convocazione_giocatori WHERE gara_id IN (SELECT cg.id FROM convocazione_gare cg JOIN convocazioni c ON c.id=cg.convocazione_id WHERE c.categoria_id IN (SELECT id FROM categorie WHERE nome LIKE '$P%'));
   DELETE FROM convocazione_gare WHERE convocazione_id IN (SELECT id FROM convocazioni WHERE categoria_id IN (SELECT id FROM categorie WHERE nome LIKE '$P%'));
   DELETE FROM convocazioni WHERE categoria_id IN (SELECT id FROM categorie WHERE nome LIKE '$P%');
   DELETE FROM tornei_gare WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%');
   DELETE FROM tornei_categorie WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%');
   DELETE FROM liste_torneo_giocatori WHERE lista_id IN (SELECT id FROM liste_torneo WHERE nome LIKE '$P%');
   DELETE FROM liste_torneo WHERE nome LIKE '$P%';
   DELETE FROM tornei WHERE nome LIKE '$P%';
   DELETE FROM partite WHERE avversario LIKE '$P%';
   DELETE FROM persone WHERE cognome LIKE '$P%';
   DELETE FROM categorie WHERE nome LIKE '$P%';
   DELETE FROM utente_categorie WHERE utente_id IN (SELECT id FROM utenti WHERE username LIKE '$U%');
   DELETE FROM login_bloccaggi WHERE chiave LIKE '$U%';
   DELETE FROM utenti WHERE username LIKE '$U%';
   DELETE FROM weekend WHERE nome LIKE '$P%';" >/dev/null; }
pulisci
# E qui si VERIFICA che la pulizia iniziale sia riuscita, prima di misurare qualsiasi baseline: se un
# residuo di un run interrotto e' rimasto, le baseline successive sarebbero sbagliate per il motivo
# sbagliato. Lo stderr di pulisci non si vede, quindi l'unica prova e' contare.
RESIDUI_INIZIALI=$(q "SELECT (SELECT count(*) FROM categorie WHERE nome LIKE '$P%')
                        + (SELECT count(*) FROM tornei WHERE nome LIKE '$P%')
                        + (SELECT count(*) FROM persone WHERE cognome LIKE '$P%')
                        + (SELECT count(*) FROM utenti WHERE username LIKE '$U%')
                        + (SELECT count(*) FROM partite WHERE avversario LIKE '$P%');")
[ "$RESIDUI_INIZIALI" != "0" ] && { echo "  FAIL prerequisito: la pulizia iniziale non ha svuotato tutto ($RESIDUI_INIZIALI residui): le baseline non sarebbero valide"; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }

q "INSERT INTO categorie (nome, anno, societa_id, is_archiviata, is_portieri) VALUES
     ('${P}A', 2016, $SOC, 0, 0), ('${P}B', 2015, $SOC, 0, 0);" >/dev/null
CA=$(q "SELECT id FROM categorie WHERE nome='${P}A'")
CB=$(q "SELECT id FROM categorie WHERE nome='${P}B'")
if [ -z "$CA" ] || [ -z "$CB" ]; then echo "  FAIL prerequisito: semina categorie fallita: $(echo $CA $CB)"; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; fi

# 3 ragazzi nella categoria A, 2 nella B, e UNO nella A ma di un'altra societa': serve a provare che il
# filtro di societa' esiste davvero e non e' gia' coperto da quello di categoria
q "INSERT INTO persone (nome, cognome, societa_id, categoria_id, data_nascita) VALUES
     ('Alpha',   '${P}G1', $SOC, $CA, '2016-01-05'),
     ('Beta',    '${P}G2', $SOC, $CA, '2016-02-06'),
     ('Gamma',   '${P}G3', $SOC, $CA, '2016-03-07'),
     ('Delta',   '${P}G4', $SOC, $CB, '2015-04-08'),
     ('Epsilon', '${P}G5', $SOC, $CB, '2015-05-09'),
     ('Lontano', '${P}G6', $SOC_ALTRA, $CA, '2016-06-10');" >/dev/null
G1=$(q "SELECT id FROM persone WHERE cognome='${P}G1'")
G2=$(q "SELECT id FROM persone WHERE cognome='${P}G2'")
G3=$(q "SELECT id FROM persone WHERE cognome='${P}G3'")
GB=$(q "SELECT id FROM persone WHERE cognome='${P}G4'")
GL=$(q "SELECT id FROM persone WHERE cognome='${P}G6'")

q "INSERT INTO tornei (societa_id, categoria_id, nome, data_inizio, data_fine)
   VALUES ($SOC, $CA, '${P}TORNEO', '2026-12-19', '2026-12-20');" >/dev/null
TID=$(q "SELECT id FROM tornei WHERE nome='${P}TORNEO'")
q "INSERT INTO tornei_categorie (torneo_id, categoria_id) VALUES ($TID,$CA),($TID,$CB);" >/dev/null
# gara 1 con categoria, gara 2 SENZA categoria (con due iscritte deve dare 400), gara 3 nell'altra categoria
q "INSERT INTO tornei_gare (torneo_id, categoria_id, numero, avversario, data, ora, ora_appuntamento, campo)
   VALUES ($TID,$CA,1,'${P}AvversarioUno','2026-12-19','10:30','09:45','Campo Prova'),
          ($TID,NULL,2,'${P}AvversarioDue','2026-12-19','11:30',NULL,NULL),
          ($TID,$CB,3,'${P}AvversarioTre','2026-12-20','09:00','08:15',NULL);" >/dev/null
GA=$(q "SELECT id FROM tornei_gare WHERE torneo_id=$TID AND numero=1")
GN=$(q "SELECT id FROM tornei_gare WHERE torneo_id=$TID AND numero=2")
GC=$(q "SELECT id FROM tornei_gare WHERE torneo_id=$TID AND numero=3")
# Un id di semina vuoto NON e' un dettaglio: `$G3` vuoto ha prodotto un JSON malformato e un 422 che
# sembrava un difetto del backend, e le asserzioni ci si sono costruite sopra. Un prerequisito non
# verificato rende verde (o rosso) un test che non sta misurando quello che crede, quindi qui si ferma.
for v in CA CB G1 G2 G3 GB GL TID GA GN GC; do
  [ -z "${!v}" ] && { echo "  FAIL prerequisito: semina incompleta: \$$v e' vuoto"; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }
done

q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo,nome,cognome) VALUES
     ('${U}_mister',    '$HASH', $SOC,      0, 0,'mister',    'Mario', '${P}MISTER'),
     ('${U}_dirigente', '$HASH', $SOC,      0, 0,'dirigente', 'Luigi', '${P}DIRIG'),
     ('${U}_scouting',  '$HASH', $SOC,      0, 0,'scouting',  'Anna',  '${P}SCOUT'),
     ('${U}_altri',     '$HASH', $SOC_ALTRA,0, 0,'mister',    'Paolo', '${P}ALTRI');" >/dev/null
q "INSERT INTO utente_categorie (utente_id, categoria_id, ruolo)
   SELECT id, $CA, 'mister' FROM utenti WHERE username='${U}_mister';" >/dev/null

T_MISTER=$(tok "${U}_mister" "$PW"); T_DIR=$(tok "${U}_dirigente" "$PW")
T_SCOUT=$(tok "${U}_scouting" "$PW"); T_ALTRI=$(tok "${U}_altri" "$PW")
for t in T_MISTER T_DIR T_SCOUT T_ALTRI; do
  [ -z "${!t}" ] && { echo "  FAIL prerequisito: token $t mancante (429 o credenziali): il test non puo' misurare niente"; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }
done
echo "  torneo $TID | gare $GA/$GN/$GC | categorie $CA/$CB | ragazzi $G1/$G2/$GB/$GL"

# Baseline: quante partite di campionato esistono. E' L'asserzione regina di questo file.
PARTI_PRIMA=$(q "SELECT count(*) FROM partite")
CAMPI_PRIMA=$(q "SELECT count(*) FROM campi_sportivi")

echo
echo "=== 1. il mister crea la convocazione di una gara di torneo ==="
BODY="{\"categoria_id\":$CA,\"tornei_gara_id\":$GA,\"data_inizio\":\"2026-12-19\",\"note\":\"prova\",\"giocatori\":[{\"persona_id\":$G1,\"posizione\":1,\"non_presente\":false},{\"persona_id\":$G2,\"posizione\":2,\"non_presente\":true}]}"
RC=$(post_cod "$D/convocazioni/" "$BODY" "$T_MISTER")
ck "il mister puo' creare la convocazione di una gara di torneo" "$RC" "200"
CID=$(post_id "$D/convocazioni/" "$BODY" "$T_MISTER")
[ -z "$CID" ] && { echo "  FAIL prerequisito: nessun id di ritorno: il resto del test non misurerebbe niente"; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }
GARAID=$(q "SELECT id FROM convocazione_gare WHERE convocazione_id=$CID")

echo "  --- il foglio e' di torneo, non del campionato ---"
ck "weekend_id resta NULL (non e' stato inventato un weekend)" \
   "$(q "SELECT coalesce(weekend_id::text,'NULL') FROM convocazioni WHERE id=$CID")" "NULL"
ck "tornei_gara_id punta alla gara giusta" \
   "$(q "SELECT tornei_gara_id FROM convocazioni WHERE id=$CID")" "$GA"
ck "la societa' del foglio e' quella del torneo" \
   "$(q "SELECT societa_id FROM convocazioni WHERE id=$CID")" "$SOC"
ck "partita_id resta NULL (nessun aggancio a una partita di campionato)" \
   "$(q "SELECT coalesce(partita_id::text,'NULL') FROM convocazione_gare WHERE convocazione_id=$CID")" "NULL"
ck "c'e' UNA sola riga di gara nel foglio" \
   "$(q "SELECT count(*) FROM convocazione_gare WHERE convocazione_id=$CID")" "1"
echo "  --- i dati logistici vengono dalla gara del torneo ---"
ck "avversario copiato dalla gara" \
   "$(q "SELECT gara FROM convocazione_gare WHERE convocazione_id=$CID")" "${P}AvversarioUno"
ck "appuntamento viene da ora_appuntamento (09:45) e NON da ora" \
   "$(q "SELECT appuntamento FROM convocazione_gare WHERE convocazione_id=$CID")" "09:45"
ck "inizio_gara viene da ora (10:30): invertire i due e' l'errore gia' visto nel PDF tornei" \
   "$(q "SELECT inizio_gara FROM convocazione_gare WHERE convocazione_id=$CID")" "10:30"
ck "data presa dalla gara" \
   "$(q "SELECT data::text FROM convocazione_gare WHERE convocazione_id=$CID")" "2026-12-19"
echo "  --- i convocati ---"
ck "due convocati salvati" \
   "$(q "SELECT count(*) FROM convocazione_giocatori WHERE gara_id=$GARAID")" "2"
ck "non_presente salvato per il secondo ragazzo" \
   "$(q "SELECT non_presente FROM convocazione_giocatori WHERE gara_id=$GARAID AND persona_id=$G2")" "1"
ck "posizione contigua 1..2" \
   "$(q "SELECT string_agg(posizione::text,',' ORDER BY posizione) FROM convocazione_giocatori WHERE gara_id=$GARAID")" "1,2"

echo
echo "=== 2. il campionato non deve essersi mosso di una riga ==="
ck "nessuna partita di campionato creata dal flusso torneo" "$(q "SELECT count(*) FROM partite")" "$PARTI_PRIMA"
ck "nessun upsert su campi_sportivi (il campo del torneo lo comunica l'organizzatore, non e' un campo nostro)" \
   "$(q "SELECT count(*) FROM campi_sportivi")" "$CAMPI_PRIMA"
ck "nessun foglio di torneo con partita_id valorizzato" \
   "$(q "SELECT count(*) FROM convocazione_gare cg JOIN convocazioni c ON c.id=cg.convocazione_id WHERE c.tornei_gara_id IS NOT NULL AND cg.partita_id IS NOT NULL")" "0"

echo
echo "=== 3. idempotenza: riaprire non crea un secondo foglio ==="
CID2=$(post_id "$D/convocazioni/" "$BODY" "$T_MISTER")
ck "il secondo POST restituisce lo STESSO foglio" "$CID2" "$CID"
ck "per quella gara esiste un solo foglio" \
   "$(q "SELECT count(*) FROM convocazioni WHERE tornei_gara_id=$GA")" "1"
ck "e i convocati non sono raddoppiati" \
   "$(q "SELECT count(*) FROM convocazione_giocatori WHERE gara_id=(SELECT id FROM convocazione_gare WHERE convocazione_id=$CID)")" "2"

echo
echo "=== 4. il foglio di torneo NON compare nella lista del weekend ==="
# E' l'asserzione che protegge il mister che usa Convocazioni ogni settimana: se qui comparisse, vedrebbe
# una riga senza weekend e penserebbe a un dato corrotto.
ck "escluso da GET /convocazioni/?categoria_id=" \
   "$(contiene_id "$D/convocazioni/?categoria_id=$CA" "$T_MISTER" "$CID")" "no"
ck "escluso anche dalla lista senza filtri" \
   "$(contiene_id "$D/convocazioni/" "$T_MISTER" "$CID")" "no"
# ma raggiungibile col suo filtro, altrimenti la pagina non puo' riaprirlo
ck "il filtro ?tornei_gara_id= lo trova" \
   "$(contiene_id "$D/convocazioni/?tornei_gara_id=$GA" "$T_MISTER" "$CID")" "si"
# e le 4 righe storiche con weekend_id NULL non devono essere sparite dalla pagina Convocazioni
QUANTE=$(q "SELECT count(*) FROM convocazioni WHERE weekend_id IS NULL AND tornei_gara_id IS NULL")
VISIBILI=$(curl -s --max-time 25 "$D/convocazioni/" -H "Authorization: Bearer $T_MISTER" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print('')
print(sum(1 for t in d if t.get('weekend_id') is None))" 2>/dev/null)
ck "i fogli del campionato senza weekend ($QUANTE) restano visibili nella lista" "$VISIBILI" "$QUANTE"

echo
echo "=== 5. il dettaglio dice per quale gara e torneo si sta scrivendo ==="
ck "GET /convocazioni/{id} espone tornei_gara_id" \
   "$(jq1 "$D/convocazioni/$CID" "$T_MISTER" "tornei_gara_id")" "$GA"
ck "espone il nome del torneo (il modal deve dirlo, non solo 'Convocazione')" \
   "$(jq1 "$D/convocazioni/$CID" "$T_MISTER" "torneo.torneo_nome")" "${P}TORNEO"
ck "espone l'avversario della gara" \
   "$(jq1 "$D/convocazioni/$CID" "$T_MISTER" "torneo.avversario")" "${P}AvversarioUno"
ck "il nome della categoria arriva dal backend" \
   "$(jq1 "$D/convocazioni/$CID" "$T_MISTER" "torneo.categoria_nome")" "${P}A"

echo
echo "=== 6. le guardie sui giocatori ==="
# Il ragazzo di UN'ALTRA CATEGORIA: il rischio e' convocare i 2015 per la gara dei 2016. Se il controllo
# manca non c'e' nessun errore da nessuna parte: esce un foglio plausibile con dentro ragazzi sbagliati.
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CA,\"tornei_gara_id\":$GA,\"data_inizio\":\"2026-12-19\",\"giocatori\":[{\"persona_id\":$GB,\"posizione\":1}]}" "$T_MISTER")
ck "un ragazzo di un'altra categoria viene rifiutato" "$RC" "400"
ck "e non viene salvato" \
   "$(q "SELECT count(*) FROM convocazione_giocatori WHERE persona_id=$GB")" "0"
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CA,\"tornei_gara_id\":$GA,\"data_inizio\":\"2026-12-19\",\"giocatori\":[{\"persona_id\":$GL,\"posizione\":1}]}" "$T_MISTER")
ck "un ragazzo di un'altra SOCIETA' viene rifiutato" "$RC" "403"
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CB,\"tornei_gara_id\":$GA,\"data_inizio\":\"2026-12-19\",\"giocatori\":[]}" "$T_MISTER")
ck "la categoria dichiarata deve essere quella della gara" "$RC" "400"
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CA,\"tornei_gara_id\":$GN,\"data_inizio\":\"2026-12-19\",\"giocatori\":[]}" "$T_MISTER")
ck "gara senza categoria, con due iscritte: rifiutata invece di sceglierne una a caso" "$RC" "400"
echo "       -> $(det -X POST "$D/convocazioni/" -H "Content-Type: application/json" -H "Authorization: Bearer $T_MISTER" -d "{\"categoria_id\":$CA,\"tornei_gara_id\":$GN,\"data_inizio\":\"2026-12-19\",\"giocatori\":[]}")"
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CA,\"tornei_gara_id\":999999,\"data_inizio\":\"2026-12-19\",\"giocatori\":[]}" "$T_MISTER")
ck "gara di torneo inesistente -> 404" "$RC" "404"
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CA,\"tornei_gara_id\":$GA,\"data_inizio\":\"2026-12-19\",\"gare\":[{\"numero\":1,\"giocatori\":[]}]}" "$T_MISTER")
ck "i giocatori nel campo 'gare' vengono rifiutati, non silenziosamente ignorati" "$RC" "400"

echo
echo "=== 7. chi puo' scrivere ==="
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CB,\"tornei_gara_id\":$GC,\"data_inizio\":\"2026-12-20\",\"giocatori\":[]}" "$T_DIR")
ck "il DIRIGENTE non puo' creare una convocazione di torneo" "$RC" "403"
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CB,\"tornei_gara_id\":$GC,\"data_inizio\":\"2026-12-20\",\"giocatori\":[]}" "$T_SCOUT")
ck "lo SCOUTING non puo' crearla" "$RC" "403"
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CA,\"tornei_gara_id\":$GA,\"data_inizio\":\"2026-12-19\",\"giocatori\":[]}" "$T_ALTRI")
ck "un mister di UN'ALTRA SOCIETA' non puo' scriverci sopra" "$RC" "403"
ck "e non puo' nemmeno cancellarla" "$(del_cod "$D/convocazioni/$CID" "$T_ALTRI")" "403"
# cancellare e' modificare: se bastasse un DELETE, il gate su crea non servirebbe a niente
ck "il dirigente non puo' cancellare il foglio del mister" "$(del_cod "$D/convocazioni/$CID" "$T_DIR")" "403"
ck "lo scouting non puo' cancellarlo" "$(del_cod "$D/convocazioni/$CID" "$T_SCOUT")" "403"
ck "e il foglio esiste ancora dopo i tentativi di cancellazione" \
   "$(q "SELECT count(*) FROM convocazioni WHERE id=$CID")" "1"

echo
echo "=== 8. un foglio non passa dal torneo al weekend ==="
RC=$(put_cod "$D/convocazioni/$CID" "{\"categoria_id\":$CA,\"weekend_id\":1,\"tornei_gara_id\":$GA,\"data_inizio\":\"2026-12-19\",\"giocatori\":[]}" "$T_MISTER")
ck "collegare un foglio di torneo a un weekend viene rifiutato" "$RC" "400"
ck "e il foglio resta senza weekend" \
   "$(q "SELECT coalesce(weekend_id::text,'NULL') FROM convocazioni WHERE id=$CID")" "NULL"
# il discriminatore si prende DAL FOGLIO, non da cosa manda il client: un client che dimenticasse
# tornei_gara_id nel PUT non deve poter riscrivere un foglio di torneo con la logica del weekend
RC=$(put_cod "$D/convocazioni/$CID" "{\"categoria_id\":$CA,\"data_inizio\":\"2026-12-19\",\"giocatori\":[{\"persona_id\":$G1,\"posizione\":1},{\"persona_id\":$G2,\"posizione\":2},{\"persona_id\":$G3,\"posizione\":3}]}" "$T_MISTER")
ck "un PUT senza tornei_gara_id viene comunque gestito dal percorso torneo" "$RC" "200"
ck "il foglio e' ancora di torneo dopo quel PUT" \
   "$(q "SELECT coalesce(tornei_gara_id::text,'NULL')||'/'||coalesce(weekend_id::text,'NULL') FROM convocazioni WHERE id=$CID")" "$GA/NULL"
ck "la modifica ai convocati e' arrivata a terra (3 ora)" \
   "$(q "SELECT count(*) FROM convocazione_giocatori WHERE gara_id=(SELECT id FROM convocazione_gare WHERE convocazione_id=$CID)")" "3"
ck "e nessuna partita di campionato e stata creata dal PUT" "$(q "SELECT count(*) FROM partite")" "$PARTI_PRIMA"

echo
echo "=== 9. il vincolo del database, provato violandolo ==="
# Contare che il CHECK "esista" non dimostra che funzioni.
q "INSERT INTO weekend (societa_id, nome, data_inizio, data_fine) VALUES ($SOC,'${P}WE','2026-12-19','2026-12-20');" >/dev/null
WID=$(q "SELECT id FROM weekend WHERE nome='${P}WE'")
ERR=$(q "INSERT INTO convocazioni (societa_id, categoria_id, weekend_id, tornei_gara_id, data_inizio)
         VALUES ($SOC,$CA,$WID,$GA,'2026-12-19');" 2>&1 | head -1)
ck "il DB rifiuta un foglio con weekend E gara di torneo insieme" \
   "$(printf '%s' "$ERR" | grep -c ck_convocazioni_uno_dei_due)" "1"
ck "e non lascia righe a meta'" \
   "$(q "SELECT count(*) FROM convocazioni WHERE weekend_id=$WID AND tornei_gara_id=$GA")" "0"
# il caso LEGALE che deve restare valido: le righe con entrambi NULL (4 su 14 su PROD) non devono essere
# diventate illegali, perche' una migrazione che rompe i dati reali non e' un vincolo, e' un deploy rotto
OK=$(q "INSERT INTO convocazioni (societa_id, categoria_id, weekend_id, tornei_gara_id, data_inizio)
        VALUES ($SOC,$CA,NULL,NULL,'2026-12-19') RETURNING id;" 2>&1 | head -1)
ck "un foglio con entrambi NULL resta valido (le 4 righe vecchie su PROD non si sono rotte)" \
   "$(printf '%s' "$OK" | grep -cE '^[0-9]+$')" "1"
q "DELETE FROM convocazioni WHERE weekend_id=$WID OR (weekend_id IS NULL AND tornei_gara_id IS NULL AND categoria_id=$CA AND data_inizio='2026-12-19');" >/dev/null

echo
echo "=== 10. il calendario gare: ora anche il mister scrive ==="
RC=$(post_cod "$D/tornei/$TID/gare" "{\"categoria_id\":$CA,\"numero\":9,\"avversario\":\"${P}GaraDelMister\",\"data\":\"2026-12-20\",\"ora\":\"15:00\"}" "$T_MISTER")
ck "il mister puo' AGGIUNGERE una gara al calendario del torneo" "$RC" "200"
GUOVA=$(q "SELECT id FROM tornei_gare WHERE torneo_id=$TID AND avversario='${P}GaraDelMister'")
ck "la gara e' davvero nel calendario" "$(q "SELECT count(*) FROM tornei_gare WHERE id=$GUOVA")" "1"
ck "il mister puo' MODIFICARE una gara" \
   "$(put_cod "$D/tornei/$TID/gare/$GUOVA" "{\"categoria_id\":$CA,\"numero\":9,\"avversario\":\"${P}GaraRinominata\",\"data\":\"2026-12-20\"}" "$T_MISTER")" "200"
ck "la modifica e' arrivata a terra" \
   "$(q "SELECT avversario FROM tornei_gare WHERE id=$GUOVA")" "${P}GaraRinominata"
ck "il mister puo' ELIMINARE una gara" "$(del_cod "$D/tornei/$TID/gare/$GUOVA" "$T_MISTER")" "200"
ck "e la gara non c'e' piu'" "$(q "SELECT count(*) FROM tornei_gare WHERE id=$GUOVA")" "0"
# e il gate vecchio non deve essersi allargato a tutti
ck "il DIRIGENTE non puo' aggiungere gare" \
   "$(post_cod "$D/tornei/$TID/gare" "{\"categoria_id\":$CA,\"avversario\":\"${P}NoDir\",\"data\":\"2026-12-20\"}" "$T_DIR")" "403"
ck "lo SCOUTING non puo' aggiungere gare" \
   "$(post_cod "$D/tornei/$TID/gare" "{\"categoria_id\":$CA,\"avversario\":\"${P}NoScout\",\"data\":\"2026-12-20\"}" "$T_SCOUT")" "403"
ck "un mister di UN'ALTRA SOCIETA' non puo' toccare il torneo" \
   "$(post_cod "$D/tornei/$TID/gare" "{\"categoria_id\":$CA,\"avversario\":\"${P}NoAltri\",\"data\":\"2026-12-20\"}" "$T_ALTRI")" "403"
ck "e non puo' nemmeno cancellarne le gare" "$(del_cod "$D/tornei/$TID/gare/$GA" "$T_ALTRI")" "403"

echo
echo "=== 11. il resto dei tornei resta dell'admin ==="
# Se il gate nuovo fosse stato messo anche qui, un mister potrebbe far sparire il torneo di una societa'.
ck "il mister NON puo' creare un torneo" \
   "$(post_cod "$D/tornei/" "{\"nome\":\"${P}TorneoDelMister\",\"data_inizio\":\"2026-12-19\",\"data_fine\":\"2026-12-20\",\"categorie_id\":[$CA]}" "$T_MISTER")" "403"
ck "il mister NON puo' modificare il torneo" \
   "$(put_cod "$D/tornei/$TID" "{\"nome\":\"${P}Manomesso\",\"data_inizio\":\"2026-12-19\",\"data_fine\":\"2026-12-20\"}" "$T_MISTER")" "403"
ck "il nome del torneo non e' cambiato" \
   "$(q "SELECT nome FROM tornei WHERE id=$TID")" "${P}TORNEO"
ck "il mister NON puo' eliminare il torneo" "$(del_cod "$D/tornei/$TID" "$T_MISTER")" "403"
ck "il torneo esiste ancora" "$(q "SELECT count(*) FROM tornei WHERE id=$TID")" "1"
ck "il mister NON puo' iscrivere una categoria" \
   "$(post_cod "$D/tornei/$TID/categorie" "{\"categorie_id\":[$CB]}" "$T_MISTER")" "403"
ck "il mister NON puo' rimuovere una categoria iscritta" \
   "$(del_cod "$D/tornei/$TID/categorie/$CB" "$T_MISTER")" "403"
ck "e le due categorie risultano ancora iscritte" \
   "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$TID")" "2"

echo
echo "=== 12. cancellare la gara si porta via il foglio (ON DELETE CASCADE) ==="
# E' la ragione per cui il discriminatore sta su `convocazioni` e non su `convocazione_gare`: se fosse
# sul figlio, cancellando la gara resterebbe un foglio senza gare, cioe' un convocazioni orfano che
# nessuna pagina apre piu' e che nessuno cancella mai.
# Il foglio della terza gara qui non c'e' ancora: le prove di cui sopra lo hanno solo tentato e rifiutato.
RC=$(post_cod "$D/convocazioni/" "{\"categoria_id\":$CB,\"tornei_gara_id\":$GC,\"data_inizio\":\"2026-12-20\",\"giocatori\":[{\"persona_id\":$GB,\"posizione\":1}]}" "$T_MISTER")
ck "il mister crea il foglio della terza gara" "$RC" "200"
CIDC=$(post_id "$D/convocazioni/" "{\"categoria_id\":$CB,\"tornei_gara_id\":$GC,\"data_inizio\":\"2026-12-20\",\"giocatori\":[{\"persona_id\":$GB,\"posizione\":1}]}" "$T_MISTER")
ck "il foglio della terza gara c'e'" "$(q "SELECT count(*) FROM convocazioni WHERE id=$CIDC")" "1"
ck "cancella la gara dal calendario" "$(del_cod "$D/tornei/$TID/gare/$GC" "$T_MISTER")" "200"
ck "il foglio di convocazione e' sparito con la gara" \
   "$(q "SELECT count(*) FROM convocazioni WHERE id=$CIDC")" "0"
ck "e non sono rimaste gare di convocazione orfane" \
   "$(q "SELECT count(*) FROM convocazione_gare WHERE convocazione_id=$CIDC")" "0"
ck "e non sono rimasti convocati orfani" \
   "$(q "SELECT count(*) FROM convocazione_giocatori WHERE gara_id NOT IN (SELECT id FROM convocazione_gare)")" "0"

echo
echo "=== 13. un secondo torneo della stessa categoria non si mescola ==="
# Due tornei con la stessa categoria: se il foglio venisse trovato per categoria invece che per gara, il
# secondo torneo aprirebbe i convocati del primo.
q "INSERT INTO tornei (societa_id, categoria_id, nome, data_inizio, data_fine)
   VALUES ($SOC, $CA, '${P}SECONDO', '2027-01-09', '2027-01-10');" >/dev/null
T2=$(q "SELECT id FROM tornei WHERE nome='${P}SECONDO'")
q "INSERT INTO tornei_categorie (torneo_id, categoria_id) VALUES ($T2,$CA);" >/dev/null
q "INSERT INTO tornei_gare (torneo_id, categoria_id, numero, avversario, data, ora)
   VALUES ($T2,$CA,1,'${P}AvversarioDueT','2027-01-09','16:00');" >/dev/null
G2T=$(q "SELECT id FROM tornei_gare WHERE torneo_id=$T2")
CIDT=$(post_id "$D/convocazioni/" "{\"categoria_id\":$CA,\"tornei_gara_id\":$G2T,\"data_inizio\":\"2027-01-09\",\"giocatori\":[{\"persona_id\":$G1,\"posizione\":1}]}" "$T_MISTER")
ck "il secondo torneo ha un foglio suo" "$(q "SELECT count(*) FROM convocazioni WHERE id=$CIDT AND tornei_gara_id=$G2T")" "1"
ck "e sono due fogli distinti" "$([ -n "$CIDT" ] && [ "$CIDT" != "$CID" ] && echo diverse || echo UGUALI)" "diverse"
# G3 era stato messo nel primo foglio dalla sezione 8: se i due tornei condividessero l'aggregato, qui
# il conteggio cambierebbe. E' l'asserzione che distingue "foglio per gara" da "foglio per categoria".
ck "il primo foglio ha ancora i suoi 3 convocati, intatti" \
   "$(q "SELECT count(*) FROM convocazione_giocatori WHERE gara_id=(SELECT id FROM convocazione_gare WHERE convocazione_id=$CID)")" "3"
ck "lo stesso ragazzo risulta convocato in due fogli distinti" \
   "$(q "SELECT count(*) FROM convocazione_giocatori WHERE persona_id=$G1")" "2"
ck "il dettaglio del secondo dice il suo torneo, non il primo" \
   "$(jq1 "$D/convocazioni/$CIDT" "$T_MISTER" "torneo.torneo_nome")" "${P}SECONDO"

echo
echo "=== 14. la convocazione del WEEKEND continua a funzionare come prima ==="
# Il regression test del percorso che non dovevo toccare: 47 gare convocate su PROD dipendono da qui.
# `crea` esige un weekend programmato che copra la data (400 senza), quindi ne creo uno suo e lo passo
# esplicitamente: e' il flusso reale del mister del sabato e va riprodotto, non simulato.
q "INSERT INTO weekend (societa_id, nome, data_inizio, data_fine) VALUES ($SOC,'${P}WE2','2026-12-26','2026-12-27');" >/dev/null
WID2=$(q "SELECT id FROM weekend WHERE nome='${P}WE2'")
q "INSERT INTO partite (categoria_id, societa_id, avversario, data_partite, ora, campo, indirizzo)
   VALUES ($CA, $SOC, '${P}PartitaWeekend', '2026-12-27', '15:00', 'Campo Weekend Test', 'Via Prova 1');" >/dev/null
PID=$(q "SELECT id FROM partite WHERE avversario='${P}PartitaWeekend'")
WBODY="{\"categoria_id\":$CA,\"weekend_id\":$WID2,\"data_inizio\":\"2026-12-27\",\"note\":\"weekend\",\"gare\":[{\"numero\":1,\"gara\":\"${P}PartitaWeekend\",\"data\":\"2026-12-27\",\"campo\":\"Campo Weekend Test\",\"giocatori\":[{\"persona_id\":$G1,\"posizione\":1}]}]}"
RC=$(post_cod "$D/convocazioni/" "$WBODY" "$T_MISTER")
ck "una convocazione del weekend passa ancora" "$RC" "200"
CWID=$(post_id "$D/convocazioni/" "$WBODY" "$T_MISTER")
ck "quel foglio NON e' di torneo" \
   "$(q "SELECT coalesce(tornei_gara_id::text,'NULL') FROM convocazioni WHERE id=$CWID")" "NULL"
ck "e compare nella lista del weekend" \
   "$(contiene_id "$D/convocazioni/?categoria_id=$CA" "$T_MISTER" "$CWID")" "si"
ck "e ha la sua partita agganciata (il flusso vecchio deve continuare a trovarla)" \
   "$(q "SELECT coalesce(partita_id::text,'NULL') FROM convocazione_gare WHERE convocazione_id=$CWID")" "$PID"

echo
echo "=== pulizia ==="
pulisci
# Un conteggio COMPOSITO che dice "2" senza dire dove non e' una prova: e' la stessa trappola del
# `a/b/c/d` di test_post_deploy_prod.sh, dove il campo sbagliato era nascosto dentro una stringa sola.
# Qui ogni tabella ha la sua asserzione, cosi' il rosso nomina la tabella.
for t in "categorie:SELECT count(*) FROM categorie WHERE nome LIKE '$P%'" \
         "tornei:SELECT count(*) FROM tornei WHERE nome LIKE '$P%'" \
         "tornei_gare:SELECT count(*) FROM tornei_gare WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%')" \
         "tornei_categorie:SELECT count(*) FROM tornei_categorie WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%')" \
         "convocazioni:SELECT count(*) FROM convocazioni WHERE categoria_id IN (SELECT id FROM categorie WHERE nome LIKE '$P%')" \
         "persone:SELECT count(*) FROM persone WHERE cognome LIKE '$P%'" \
         "utenti:SELECT count(*) FROM utenti WHERE username LIKE '$U%'" \
         "weekend:SELECT count(*) FROM weekend WHERE nome LIKE '$P%'" \
         "partite:SELECT count(*) FROM partite WHERE avversario LIKE '$P%'"; do
  nome="${t%%:*}"; sql="${t#*:}"
  ck "nessun residuo di test in $nome" "$(q "$sql")" "0"
done
PARTI_DOPO=$(q "SELECT count(*) FROM partite")
ck "il conteggio partite e' tornato al valore di partenza" "$PARTI_DOPO" "$PARTI_PRIMA"

echo
echo "=============================="
# Il formato di questa riga NON e' libero: run_suite_dev.sh la cerca con
#   grep -oE '[0-9]+ passati, [0-9]+ falliti'
# e se non la trova conta il file "NESSUN RIASSUNTO (test rotto)" senza sommare niente. Il mio test
# quindi passava 93/93 da solo e risultava ROTTO dentro la suite, invisibile nel totale. Scritto a
# mano da me invece di copiare la chiusura degli altri file: un formato di output e' un'interfaccia.
echo "  $pass passati, $fail falliti"
echo "=============================="
[ "$fail" -eq 0 ] || exit 1