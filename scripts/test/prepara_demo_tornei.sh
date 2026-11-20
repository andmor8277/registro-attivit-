#!/bin/bash
# Prepara su DEV i dati per vedere la pagina Tornei suddivisa per categorie in TUTTI i suoi stati:
# due sezioni, conteggi diversi, un foglio con giocatori, un foglio assente, una gara orfana.
# Niente di questo resta: si ripulisce tutto alla fine (o con --pulisci).
set -u
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

P=__demo_tornei__
U=demo_tornei
# Il $ prima di P non va dimenticato: "$P-x" e' __demo_tornei__-x, "P-x" e' la stringa letterale
# P-x, e la pulizia sotto non la troverebbe piu' (era successo: il torneo restava nel DB)
TOD="$P-WINTER CUP"
CATP=19   # 2016 - Pulcini
CATE=26   # 2015 - Esordienti

pulisci() {
  # Anche il nome "P-WINTER CUP": residuo del $P dimenticato in bash, ripulito qui perche' il
  # pattern sotto non lo intercetta
  q "DELETE FROM tornei_gare WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%' OR nome LIKE 'P-WINTER CUP%');
     DELETE FROM tornei_categorie WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%' OR nome LIKE 'P-WINTER CUP%');
     DELETE FROM liste_torneo_giocatori WHERE lista_id IN (SELECT id FROM liste_torneo WHERE nome LIKE '$P%' OR nome LIKE 'P-WINTER CUP%');
     DELETE FROM liste_torneo WHERE nome LIKE '$P%' OR nome LIKE 'P-WINTER CUP%';
     DELETE FROM tornei WHERE nome LIKE '$P%' OR nome LIKE 'P-WINTER CUP%';
     DELETE FROM utente_categorie WHERE utente_id IN (SELECT id FROM utenti WHERE username LIKE '$U%');
     DELETE FROM login_bloccaggi WHERE chiave LIKE '$U%';
     DELETE FROM utenti WHERE username LIKE '$U%';" >/dev/null
  echo "ripulito"
}
if [ "${1:-}" = "--pulisci" ]; then pulisci; exit 0; fi

pulisci
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "hash fallito"; exit 1; }
# utente demo: admin della societa' 1, serve solo per aprire la pagina col browser headless
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('$U','$HASH',1,1,0,NULL);" >/dev/null

# Le persone che il menu "Mister del torneo" deve offrire. Vengono dagli STESSI responsabili di
# categoria che usa la programmazione partite del weekend: la tabella allenatori e' vuota in
# produzione, quindi non e' quella la fonte dei nomi. Due mister, uno per categoria, per provare che
# il menu fa l'unione delle categorie iscritte, e un dirigente che nel menu NON deve comparire
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo,nome,cognome,cellulare) VALUES
     ('demo_tornei_mister1','$HASH',1,0,0,'mister','Gino','Papaveri','3330000111'),
     ('demo_tornei_mister2','$HASH',1,0,0,'mister','Nina','Quadri','3330000222'),
     ('demo_tornei_dirigente','$HASH',1,0,0,'dirigente','Tito','Dirigenti',NULL),
     ('demo_tornei_mister3','$HASH',1,0,0,'mister','Ivo','Fuorilista',NULL);" >/dev/null
# NB: demo_tornei_mister3 NON viene assegnato a nessuna categoria, di proposito. E' il caso del
# referente che il torneo ce l'ha ma il menu non lo conosce piu' (cambia assegnazione, o viene tolta
# una categoria): la pagina deve comunque mostrarlo, perche' un menu vuoto su un torneo che il mister
# ce l'ha vuol dire che il prossimo "Salva" se lo porta via
q "INSERT INTO utente_categorie (utente_id, categoria_id, ruolo)
   SELECT id, $CATP, 'mister'     FROM utenti WHERE username='demo_tornei_mister1'
   UNION ALL
   SELECT id, $CATE, 'mister'     FROM utenti WHERE username='demo_tornei_mister2'
   UNION ALL
   SELECT id, $CATP, 'dirigente'  FROM utenti WHERE username='demo_tornei_dirigente';" >/dev/null

TOK=$(curl -s --max-time 25 -X POST "$D/auth/token" --data-urlencode "username=$U" --data-urlencode "password=$PW" \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
[ -z "$TOK" ] && { echo "login fallito"; pulisci; exit 1; }
echo "token ok"

post() { curl -s --max-time 25 -X POST "$D$1" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d "$2"; }

R=$(post /tornei/ "{\"nome\":\"$TOD\",\"categorie_id\":[$CATP,$CATE],\"data_inizio\":\"2026-12-18\",\"data_fine\":\"2026-12-20\",\"luogo\":\"Centro Sportivo Nord\",\"organizzatore\":\"ASD Calcio Giovani\",\"descrizione\":\"Torneo di Natale con due categorie iscritte: serve a vedere le due sezioni della pagina.\"}")
TID=$(printf '%s' "$R" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))")
[ -z "$TID" ] && { echo "creazione torneo fallita: $R"; pulisci; exit 1; }
echo "torneo $TID"

post /tornei/$TID/gare "{\"categoria_id\":$CATP,\"numero\":1,\"avversario\":\"Real Junior\",\"data\":\"2026-12-18\",\"ora\":\"09:30\",\"ora_appuntamento\":\"08:45\",\"campo\":\"Campo 1\",\"indirizzo\":\"Via dello Sport 4\"}" >/dev/null
post /tornei/$TID/gare "{\"categoria_id\":$CATP,\"numero\":2,\"avversario\":\"Atletico Sud\",\"data\":\"2026-12-18\",\"ora\":\"11:00\",\"ora_appuntamento\":\"10:15\",\"campo\":\"Campo 2\"}" >/dev/null
post /tornei/$TID/gare "{\"categoria_id\":$CATE,\"numero\":1,\"avversario\":\"Vecchia Guardia\",\"data\":\"2026-12-19\",\"ora\":\"15:00\",\"campo\":\"Campo 1\"}" >/dev/null
# gara orfana: categoria NULL, il caso dei dati nati prima della migrazione. Dall'API non si puo'
# creare (con due iscritte arriva un 400), quindi via SQL, che e' esattamente come esiste nel DB vero
q "INSERT INTO tornei_gare (torneo_id, numero, avversario, data, ora) VALUES ($TID, 3, 'Amichevole fuori calendario', '2026-12-20', '10:00');" >/dev/null

# giocatori veri sul foglio dei Pulcini (persone della societa' 1), per vedere il badge verde pieno.
# persona_id e' un PARAMETRO DI QUERY, non un corpo JSON: mandarlo nel body risponde 422 "Field
# required" e il foglio resta vuoto senza che nessuno se ne accorga
LID=$(q "SELECT id FROM liste_torneo WHERE torneo_id=$TID AND categoria_id=$CATP")
for id in $(q "SELECT id FROM persone WHERE societa_id=1 ORDER BY id LIMIT 3;"); do
  curl -s --max-time 25 -X POST "$D/liste-torneo/$LID/giocatori?persona_id=$id" -H "Authorization: Bearer $TOK" >/dev/null
done

# distacca il foglio degli Esordienti: e' il buco reale che la pagina deve dichiarare ("foglio assente")
q "UPDATE liste_torneo SET torneo_id = NULL WHERE torneo_id = $TID AND categoria_id = $CATE;" >/dev/null

echo "=== stato creato ==="
echo "torneo_id=$TID  password_admin_demo=$PW"
echo "mister_fuori_lista=$(q "SELECT id FROM utenti WHERE username='demo_tornei_mister3'")"
q "SELECT 'gare: '||count(*) FROM tornei_gare WHERE torneo_id=$TID;
   SELECT 'orfane(NULL): '||count(*) FROM tornei_gare WHERE torneo_id=$TID AND categoria_id IS NULL;
   SELECT 'foglio cat '||categoria_id||' giocatori='||(SELECT count(*) FROM liste_torneo_giocatori g WHERE g.lista_id=l.id)||' legato='||COALESCE(torneo_id::text,'NULL') FROM liste_torneo l WHERE nome LIKE '$P%';"
