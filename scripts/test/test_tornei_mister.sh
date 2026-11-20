#!/bin/bash
# Il torneo ha UN mister, suo, non quello delle categorie: l'organizzatore chiama un numero solo la
# mattina della domenica, e con le gare su due categorie il mister della singola partita non dice chi
# risponde del torneo intero. Questo file prova le regole di QUEL campo.
#
# Perche' esiste accanto a test_tornei.sh / _categorie.sh / _sezioni.sh: quelli provano le gare, le
# iscrizioni e i fogli. Nessuno prova il referente, che e' l'unico dato di questa scheda che finisce
# nel PDF consegnato a una persona esterna alla societa'. E' anche l'unico campo che arriva dal client
# come id di un'altra tabella, quindi e' l'unico dove un id sbagliato puo' far comparire il nome di
# una persona di un'altra societa' in un documento che viene inoltrato in chat.
#
# Le asserzioni che contano sono le quattro di rifiuto:
#   - id di un utente di un'altra societa'  -> 403 (altrimenti: nome altrui nel nostro PDF)
#   - id inesistente                        -> 404 (altrimenti: un numero stampato come persona)
#   - ruolo che non guida le squadre        -> 400 (la segreteria non e' il mister del torneo)
#   - nome a mano troppo lungo              -> 400, non 500 dal database
#
# Crea solo oggetti marcati __test_mister__ / testmister* e li rimuove alla fine.
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

# Un campo del torneo, letto dalla LISTA (e' quella che la pagina usa per dipingere la card e per
# comporre il PDF: se il mister manca qui, il documento esce senza referente).
# NULL e il vuoto NON sono la stessa cosa: "NULL" e' il campo assente dalla risposta (o nullo),
# "" e' il torneo che non e' stato trovato o la richiesta fallita. Confonderle vuol dire vedere
# verdi le asserzioni che in realta' non hanno letto niente
riga() { curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $1" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
t=next((x for x in d if x.get('id')==$2), None)
if t is None: print('TORNEO-NON-TROVATO'); raise SystemExit
v=t.get('$3')
print('NULL' if v is None else v)" 2>/dev/null; }
# Lo stesso campo letto dal DETTAGLIO: le due risposte sono due codifiche separate nel router, e
# aggiungerlo a una dimenticando l'altra e' il modo piu' veloce per avere la card giusta e il modal
# che riapre vuoto
dettaglio() { curl -s --max-time 25 "$D/tornei/$2" -H "Authorization: Bearer $1" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
v=d.get('$3')
print('NULL' if v is None else v)" 2>/dev/null; }
http() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X "$1" "$D$2" -H "Authorization: Bearer $3" \
          -H 'Content-Type: application/json' -d "$4"; }

P=__test_mister__
U=testmister

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
echo "  baseline: tornei=$(q 'SELECT count(*) FROM tornei') utenti=$(q 'SELECT count(*) FROM utenti')"

q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES (1,'$P-a',1901,0);" >/dev/null
CA=$(q "SELECT id FROM categorie WHERE nome='$P-a'")

# Username scritti per esteso: in bash "$U_adm" viene letto come la variabile U_adm, e l'utente non
# viene creato (era successo: le asserzioni sotto confrontavano token vuoti)
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo,nome,cognome,cellulare) VALUES
     ('testmister_admin','$HASH',1,1,0,NULL,'Admin','Prova',NULL),
     ('testmister_mister','$HASH',1,0,0,'mister','Mario','Rossi','3331234567'),
     ('testmister_dirigente','$HASH',1,0,0,'dirigente','Luigi','Bianchi',NULL),
     ('testmister_segreteria','$HASH',1,0,0,'segreteria','Anna','Verdi',NULL),
     ('testmister_senza_ruolo','$HASH',1,0,0,NULL,'Senza','Ruolo',NULL),
     ('testmister_altra_soc','$HASH',2,0,0,'mister','Paolo','Conti',NULL);" >/dev/null
TADM=$(tok testmister_admin "$PW")
if [ -z "$TADM" ]; then
  echo "  login admin fallito: senza token le asserzioni sotto confrontano vuoto con vuoto, mi fermo"
  pulizia; echo; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1
fi
M_MISTER=$(q "SELECT id FROM utenti WHERE username='testmister_mister'")
M_DIR=$(q "SELECT id FROM utenti WHERE username='testmister_dirigente'")
M_SEG=$(q "SELECT id FROM utenti WHERE username='testmister_segreteria'")
M_NORUOLO=$(q "SELECT id FROM utenti WHERE username='testmister_senza_ruolo'")
M_ALTRA=$(q "SELECT id FROM utenti WHERE username='testmister_altra_soc'")
echo "  mister=$M_MISTER dirigente=$M_DIR segreteria=$M_SEG senza_ruolo=$M_NORUOLO altra_societa=$M_ALTRA cat=$CA"

post() { curl -s --max-time 25 -X POST "$D$1" -H "Authorization: Bearer $2" \
          -H 'Content-Type: application/json' -d "$3"; }
# Il codice della PUT si guarda, non si scarta: nella prima versione di questo file il token finiva
# nell'argomento sbagliato, le PUT partivano con un Bearer senza senso e il torneo non cambiava MAI.
# Le asserzioni sotto erano verdi lo stesso, perche' confrontavano il valore vecchio con se stesso
put() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X PUT "$D/tornei/$1" \
          -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
SCHEDA() { printf '{"nome":"%s","categorie_id":[%s]}' "$1" "$CA"; }

echo
echo "--- 1. il mister si assegna e arriva risolto, non come numero ---"
R=$(post /tornei/ "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_id\":$M_MISTER}")
TID=$(printf '%s' "$R" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('id',''))
except Exception: print('')" 2>/dev/null)
ck "POST /tornei/ con mister_id restituisce un id" "$([ -n "$TID" ] && echo si)" "si"
ck "la lista espone mister_id" "$(riga "$TADM" "$TID" "mister_id")" "$M_MISTER"
# Il nome, non l'id: la card e il PDF devono dire chi e', e nessuno dei due deve doverselo ricordare
ck "la lista espone il NOME del mister (non l'id)" "$(riga "$TADM" "$TID" "mister_nome")" "Mario Rossi"
ck "il nome e' anche nel dettaglio (il modal legge quello)" "$(dettaglio "$TADM" "$TID" "mister_nome")" "Mario Rossi"
ck "il recapito arriva, perche' il PDF del weekend lo stampa gia'" "$(riga "$TADM" "$TID" "mister_cellulare")" "3331234567"
ck "mister_manuale resta NULL quando si sceglie dal menu" "$(riga "$TADM" "$TID" "mister_manuale")" "NULL"

echo
echo "--- 2. il nome scritto a mano (l'accompagnatore non censito) ---"
C=$(put "$TID" "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_manuale\":\"Gianni Testa\"}")
ck "la PUT con il nome a mano e' andata a buon fine (se e' rossa, sotto non si misura niente)" "$C" "200"
ck "il nome a mano compare nella lista" "$(riga "$TADM" "$TID" "mister_nome")" "Gianni Testa"
ck "il nome a mano vince sul mister_id, che si svuota" "$(riga "$TADM" "$TID" "mister_id")" "NULL"
ck "e il dettaglio dice la stessa cosa" "$(dettaglio "$TADM" "$TID" "mister_nome")" "Gianni Testa"
# Togliere gli spazi iniziali/finali: un PDF che stampa " Gianni Testa " e uno che stampa "Gianni
# Testa" sembrano due persone diverse all'organizzatore
put "$TID" "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_manuale\":\"   Gianni Testa   \"}" >/dev/null
ck "il nome a mano viene ripulito dagli spazi" "$(riga "$TADM" "$TID" "mister_nome")" "Gianni Testa"
ck "il nome a mano arriva anche nel database, non solo nella risposta" \
   "$(q "SELECT mister_manuale FROM tornei WHERE id=$TID")" "Gianni Testa"

echo
echo "--- 3. senza mister: il campo deve potersi togliere ---"
C=$(put "$TID" "$TADM" "$(SCHEDA "$P-coppa")")
ck "la PUT senza mister e' andata a buon fine" "$C" "200"
ck "tolto il mister, mister_id e NULL" "$(riga "$TADM" "$TID" "mister_id")" "NULL"
ck "tolto il mister, mister_nome e NULL (la pagina scrive 'da assegnare')" "$(riga "$TADM" "$TID" "mister_nome")" "NULL"
ck "e il dettaglio e' coerente con la lista" "$(dettaglio "$TADM" "$TID" "mister_nome")" "NULL"
ck "e nel database non e' rimasto niente" \
   "$(q "SELECT COALESCE(mister_id::text,'NULL')||'/'||COALESCE(mister_manuale,'NULL') FROM tornei WHERE id=$TID")" "NULL/NULL"

echo
echo "--- 4. i rifiuti: sono i quattro che proteggono il PDF ---"
ck "mister di un'altra societa' -> 403 (altrimenti: nome altrui nel nostro PDF)" \
   "$(http PUT /tornei/$TID "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_id\":$M_ALTRA}")" "403"
ck "e il torneo e' rimasto senza mister (il rifiuto non ha scritto niente)" \
   "$(riga "$TADM" "$TID" "mister_nome")" "NULL"
ck "mister inesistente -> 404 (altrimenti: un numero stampato come persona)" \
   "$(http PUT /tornei/$TID "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_id\":999999}")" "404"
ck "la segreteria non e' un mister del torneo -> 400" \
   "$(http PUT /tornei/$TID "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_id\":$M_SEG}")" "400"
ck "un utente senza ruolo -> 400 (lo stesso filtro del menu a tendina)" \
   "$(http PUT /tornei/$TID "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_id\":$M_NORUOLO}")" "400"
ck "entrambi i campi insieme -> 400 (quale dei due va nel PDF?) e non una scelta silenziosa" \
   "$(http PUT /tornei/$TID "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_id\":$M_MISTER,\"mister_manuale\":\"Gianni Testa\"}")" "400"
LUNGO=$(python3 -c "print('X'*101)")
ck "nome a mano di 101 caratteri -> 400 e non 500 dal database" \
   "$(http PUT /tornei/$TID "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_manuale\":\"$LUNGO\"}")" "400"
ck "dopo i rifiuti il torneo e' ancora senza mister" "$(riga "$TADM" "$TID" "mister_nome")" "NULL"

echo
echo "--- 5. chi il menu non lo mostra, l'API lo accetta (la lista dei candidati la decide la pagina) ---"
# Il dirigente viene escluso dal menu a tendina come fa il weekend, ma non e' un abuso: se il
# responsabile lo indica come referente, il backend non deve inventarsi un divieto suo
ck "il dirigente viene accettato dal backend" \
   "$(http PUT /tornei/$TID "$TADM" "{\"nome\":\"$P-coppa\",\"categorie_id\":[$CA],\"mister_id\":$M_DIR}")" "200"
ck "e il suo nome esce nel PDF" "$(riga "$TADM" "$TID" "mister_nome")" "Luigi Bianchi"

echo
echo "--- 6. il mister e' del torneo, non della categoria: due tornei, due referenti ---"
R2=$(post /tornei/ "$TADM" "{\"nome\":\"$P-trofeo\",\"categorie_id\":[$CA],\"mister_id\":$M_MISTER}")
TID2=$(printf '%s' "$R2" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('id',''))
except Exception: print('')" 2>/dev/null)
ck "il secondo torneo ha un suo id" "$([ -n "$TID2" ] && echo si)" "si"
ck "il primo torneo ha il suo dirigente" "$(riga "$TADM" "$TID" "mister_nome")" "Luigi Bianchi"
ck "il secondo ha il suo mister, sulla STESSA categoria" "$(riga "$TADM" "$TID2" "mister_nome")" "Mario Rossi"
# Rinominare il torneo NON deve perdere il referente. Si cambia anche il mister nello stesso colpo:
# se la PUT ignorava il campo, questa asserzione restava verde confrontando il valore vecchio con
# se stessa (e' esattamente come era sfuggito il bug dell'helper rotto)
C=$(put "$TID2" "$TADM" "{\"nome\":\"$P-trofeo 2\",\"categorie_id\":[$CA],\"mister_manuale\":\"Gianni Testa\"}")
ck "la PUT di rinomino con il mister a mano e' andata a buon fine" "$C" "200"
ck "il rinomino non perde il mister, e quello nuovo e' il suo" "$(riga "$TADM" "$TID2" "mister_nome")" "Gianni Testa"
ck "il nome del torneo e' cambiato davvero" \
   "$(q "SELECT nome FROM tornei WHERE id=$TID2")" "$P-trofeo 2"
# Un id orfano (l'utente viene cancellato: la colonna non ha FK di proposito) non deve stampare un
# numero nel documento
q "UPDATE tornei SET mister_id=$M_DIR, mister_manuale=NULL WHERE id=$TID2;" >/dev/null
q "DELETE FROM utenti WHERE username='testmister_mister';" >/dev/null
ck "l'id di un utente cancellato non diventa un numero nel PDF" "$(riga "$TADM" "$TID2" "mister_nome")" "Luigi Bianchi"
q "UPDATE tornei SET mister_id=999999, mister_manuale=NULL WHERE id=$TID2;" >/dev/null
ck "un id che non corrisponde a nessuno non viene stampato" "$(riga "$TADM" "$TID2" "mister_nome")" "NULL"
ck "e la pagina puo' ancora dire 'da assegnare' senza errori" \
   "$(curl -s --max-time 25 -o /dev/null -w '%{http_code}' "$D/tornei/$TID2" -H "Authorization: Bearer $TADM")" "200"

echo
echo "--- 7. il campo esiste davvero nel database (non solo nella risposta) ---"
ck "tornei.mister_id esiste" "$(q "SELECT count(*) FROM information_schema.columns WHERE table_name='tornei' AND column_name='mister_id'")" "1"
ck "tornei.mister_manuale esiste" "$(q "SELECT count(*) FROM information_schema.columns WHERE table_name='tornei' AND column_name='mister_manuale'")" "1"
ck "mister_manuale e' largo 100, come il controllo sul 400" \
   "$(q "SELECT character_maximum_length FROM information_schema.columns WHERE table_name='tornei' AND column_name='mister_manuale'")" "100"
ck "mister_id non ha vincolo di chiave esterna (l'utente puo' essere cancellato)" \
   "$(q "SELECT count(*) FROM pg_constraint WHERE conname LIKE 'tornei_mister_id%'")" "0"

echo
pulizia
R=$(q "SELECT count(*) FROM tornei WHERE nome LIKE '$P%'")
[ "$R" = "0" ] && echo "  pulizia ok (nessun residuo)" || echo "  ATTENZIONE: residuati tornei=$R"
echo "  $pass passati, $fail falliti"
[ "$fail" -eq 0 ] && exit 0 || exit 1
