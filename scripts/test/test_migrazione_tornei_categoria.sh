#!/bin/bash
# `tornei.categoria_id`: il modello e il database devono dire LA STESSA COSA.
#
# Perche' questo file esiste. `backend/app/models/partite.py::Torneo.categoria_id` dichiara
# `nullable=True` e il commento accanto dice "Nullable dal 2026-11-20", ma la migrazione corrispondente
# non era mai stata scritta: misurato il 2026-11-25, `information_schema.columns.is_nullable` diceva
# **NO su DEV e NO su PROD**. Un modello che promette una cosa e uno schema che ne applica un'altra non
# produce nessun errore finche' nessuno passa di li' -- e nessuno ci passava, perche' `crea_torneo`
# scrive sempre `categorie_ids[0]`. Il primo che scrive un `NULL` fidandosi del modello si prende un
# IntegrityError in produzione, e i test non lo vedono perche' passano tutti dall'API. E' la stessa
# classe di `persone.codice_fiscale`, che il modello dice String(16) e la colonna e' varchar(255).
#
# Cosa misura, e perche' proprio questo:
#  1. lo **stato reale** della colonna, letto da information_schema -- non "la migrazione c'e' nel file";
#  2. che **modello e DB coincidano**, confrontando le due fonti. E' l'asserzione che impedisce al
#     difetto di tornare: un test che aspettasse `YES` scritto a mano sarebbe verde anche il giorno che
#     qualcuno rimettesse il NOT NULL *e* il `nullable=False` nel modello, cioe' quando il problema e'
#     di nuovo li' ma simmetrico;
#  3. che il DB **accetta davvero** la riga con il NULL (un INSERT diretto): information_schema che dice
#     YES non basta, e' la dichiarazione; la riga che entra e' la prova;
#  4. che l'API continui a **rifiutare** un torneo senza categorie con 400: la migrazione chiude la
#     promessa del modello, non apre una strada nuova. Se qualcuno togliesse la guardia in `_valida`,
#     dall'app nascerebbe un torneo senza categorie e senza foglio giocatori da consegnare;
#  5. che `run_migrations()` sia **idempotente e silenziosa**: rieseguendola la colonna resta nullable e
#     il blocco non stampa nessun warning ne' il suo print "ora nullable" (il rumore nei log di
#     migrazione e' il posto dove un guasto vero si nasconde);
#  6. che nessuna riga esistente sia stata toccata: la migrazione non riscrive dati.
#
# Crea solo righe marcate __migcat__ e le rimuove alla fine, trap incluso.
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ -z "$2" ] && [ -z "$3" ]; then fail=$((fail+1)); echo "  FAIL $1 -> entrambi vuoti: il test non ha misurato nulla"; return; fi
       if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi; }

nullable_db() { q "SELECT is_nullable FROM information_schema.columns
                   WHERE table_schema = current_schema() AND table_name = 'tornei'
                     AND column_name = 'categoria_id';"; }
# La fonte opposta: cosa DICE il modello, letto dal container che sta eseguendo questo codice. Chiederlo
# al sorgente locale sarebbe un'altra asserzione su un file, non sul sistema in esecuzione
nullable_modello() { $SSH "docker exec $BE python -c \"from app.models.partite import Torneo; print(Torneo.__table__.columns['categoria_id'].nullable)\"" 2>/dev/null | tr -d '\r' | tail -1; }

pulisci() {
  q "DELETE FROM tornei_gare WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '__migcat__%');
     DELETE FROM tornei_categorie WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '__migcat__%');
     DELETE FROM liste_torneo WHERE nome LIKE '__migcat__%';
     DELETE FROM tornei WHERE nome LIKE '__migcat__%';" >/dev/null
}
pulisci
trap pulisci EXIT

echo "--- lo stato reale della colonna, letto dal database ---"
PRIMA=$(nullable_db)
# Un valore vuoto qui significa che la query non ha colpito (tabella o colonna inesistente, o psql che
# ha risposto con l'errore): \`ck\` rifiuterebbe il confronto fra due vuoti, ma il motivo va detto
[ -n "$PRIMA" ] || echo "  ATTENZIONE: information_schema non ha restituito nulla per tornei.categoria_id: le asserzioni sotto sono rosse per questo"
ck "tornei.categoria_id e' nullable nel DB (la migrazione del 2026-11-25 e' davvero corsa)" "$PRIMA" "YES"
ck "e il modello dice la stessa cosa (le due fonti confrontate, non un valore scritto a mano)" \
   "$(nullable_modello)" "True"

echo "--- il DB accetta la riga con il NULL? (la dichiarazione non e' la prova) ---"
# CAT 19 esiste e non viene usata: qui cio' che conta e' che la colonna resti vuota
NULL_ID=$(q "INSERT INTO tornei (nome, categoria_id, societa_id, data_inizio, data_fine)
              VALUES ('__migcat__-senza-categoria', NULL, 1, '2027-02-01', '2027-02-02')
              RETURNING id;" | head -1 | tr -d '[:space:]')
ck "un INSERT con categoria_id NULL viene accolto (non e' un IntegrityError)" \
   "$([ -n "$NULL_ID" ] && echo si)" "si"
ck "  e la riga ha davvero la colonna vuota" \
   "$(q "SELECT coalesce(categoria_id::text,'(null)') FROM tornei WHERE id=$NULL_ID")" "(null)"
ck "  e non ha categorie iscritte (e' un orfano vero, non un torneo a meta')" \
   "$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$NULL_ID")" "0"
# Il rovescio della medaglia, e la parte che rende la migrazione sicura: togliere il NOT NULL al DB non
# deve autorizzare nessuno a creare un torneo senza categorie DALL'APP. Un torneo cosi' non avrebbe il
# foglio giocatori da consegnare all'organizzatore, che e' il motivo per cui la Lista Tornei nasce col
# torneo. La guardia sta in `_valida`, e qui si misura che ci sia ancora
D=http://192.168.178.133:3000/api
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('migcat_adm','$HASH',1,1,0,NULL);" >/dev/null
# Il limiter di /auth/token e' 10/minute PER WORKER: senza ritento il login diventa un 401 e il 400 che
# voglio misurare qui sotto si trasforma in un rosso che accusa la guardia sbagliata
TOK=""
for i in 1 2 3 4 5; do
  OUT=$(curl -s -w '\n%{http_code}' --max-time 25 -X POST "$D/auth/token" \
           --data-urlencode "username=migcat_adm" --data-urlencode "password=$PW")
  CODE="${OUT##*$'\n'}"
  if [ "$CODE" = "429" ]; then sleep 8; continue; fi
  TOK=$(printf '%s' "${OUT%$'\n'*}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
  break
done
if [ -z "$TOK" ]; then
  echo "  FAIL login dell'admin di prova fallito (429 o hash non valido): il caso 'l'API rifiuta ancora'"
  echo "       non puo' essere misurato, e senza di esso questa migrazione sembrerebbe aver aperto una strada"
  echo "  $pass passati, $((fail+1)) falliti (prerequisiti)"; exit 1
fi
ck "POST /tornei/ senza categorie -> 400: la guardia dell'app c'e' ancora" \
   "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/tornei/" \
        -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
        -d '{"nome":"__migcat__-api-orfano","categorie_id":[]}')" "400"
ck "  e il torneo via API non e' nato" \
   "$(q "SELECT count(*) FROM tornei WHERE nome='__migcat__-api-orfano'")" "0"
q "DELETE FROM utenti WHERE username='migcat_adm';" >/dev/null

echo "--- run_migrations() rieseguita: idempotente e silenziosa ---"
CON_PRIMA=$(q "SELECT count(*) FROM tornei")
CON_VAL=$(q "SELECT count(*) FROM tornei WHERE categoria_id IS NOT NULL")
OUT=$($SSH "docker exec $BE python -c 'from app.migrations.run import run_migrations; run_migrations()' 2>&1")
ck "la colonna e' ancora nullable dopo una seconda esecuzione" "$(nullable_db)" "YES"
ck "nessun warning da questo blocco" "$(printf '%s' "$OUT" | grep -c 'Migration warning (tornei.categoria_id')" "0"
# Il print di esito deve comparire UNA VOLTA SOLA nel giro: se il blocco non controllasse
# information_schema eseguirebbe l'ALTER a ogni avvio, e il print lo racconterebbe ogni volta
ck "il print di esito non si ripete (il blocco non riesegue l'ALTER)" \
   "$(printf '%s' "$OUT" | grep -c 'categoria_id ora nullable')" "0"
ck "nessun traceback" "$(printf '%s' "$OUT" | grep -ci traceback)" "0"
ck "  e nessun UniqueViolation" "$(printf '%s' "$OUT" | grep -c UniqueViolation)" "0"
ck "la migrazione non ha toccato nessuna riga" "$(q "SELECT count(*) FROM tornei")" "$CON_PRIMA"
ck "  e le righe che avevano una categoria ce l'hanno ancora" \
   "$(q "SELECT count(*) FROM tornei WHERE categoria_id IS NOT NULL")" "$CON_VAL"

echo "--- ripulitura ---"
pulisci
ck "nessun residuo di prova" \
   "$(q "SELECT (SELECT count(*) FROM tornei WHERE nome LIKE '__migcat__%') + (SELECT count(*) FROM utenti WHERE username LIKE 'migcat%')")" "0"

echo
echo "  $pass passati, $fail falliti"
[ "$fail" -eq 0 ]
