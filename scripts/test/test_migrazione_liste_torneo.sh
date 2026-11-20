#!/bin/bash
# Le migrazioni di liste_torneo devono arrivare ALLO STESSO stato su un DB vecchio e su uno nuovo,
# e devono dirlo senza urlare.
#
# Perche' questo file esiste: `run_migrations()` aveva un blocco che creava
# `ux_liste_torneo_torneo` (l'idea vecchia di "un torneo produce una sola lista") e un blocco piu'
# avanti che lo DROPPAVA per creare quello giusto, `ux_liste_torneo_torneo_categoria` su
# (torneo_id, categoria_id). Su PROD "WINTER CUP" ha quattro fogli, uno per categoria iscritta,
# quindi la CREATE vecchia falliva `UniqueViolation` a OGNI avvio: un warning che sembra un guasto
# grosso ed e' rumore, e che a forza di vederlo nessuno legge piu'. C'era anche un rischio vero: la
# CREATE fallita stava nello stesso `try` della `ADD COLUMN torneo_id`, e il `conn.rollback()` di
# quel try si sarebbe portato via anche la colonna appena aggiunta.
#
# Qui si misura il risultato, non il log: lo stato finale degli indici, il vincolo che DEVE restare
# (due fogli per la stessa categoria dello stesso torneo => il DB rifiuta la riga), e i due casi che
# sembrano uguali e non lo sono (due categorie dello stesso torneo => ok; due liste manuali senza
# torneo => ok, perche' l'UNIQUE e' parziale).
#
# Crea solo righe marcate __mig__ e le rimuove alla fine.
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ -z "$2" ] && [ -z "$3" ]; then fail=$((fail+1)); echo "  FAIL $1 -> entrambi vuoti: il test non ha misurato nulla"; return; fi
       if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi; }

# due categorie reali della societa' 1: sono le stesse che la pagina Tornei usa gia' (Pulcini 2016 e
# Esordienti 2015), e il foglio viene creato per (torneo, categoria) come fa il backend
CAT_A=19; CAT_B=26
SOC=1

pulisci() {
  q "DELETE FROM liste_torneo WHERE nome LIKE '__mig__%';
     DELETE FROM tornei_gare WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '__mig__%');
     DELETE FROM tornei_categorie WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '__mig__%');
     DELETE FROM tornei WHERE nome LIKE '__mig__%';" >/dev/null
}
pulisci

echo "--- preparo un torneo con DUE categorie iscritte e i suoi due fogli ---"
# Le righe si creano via SQL perche' qui cio' che conta e' la FORMA dei dati (un torneo, due fogli di
# categorie diverse) e deve essere esattamente quella formatasi su PROD nel tempo, non quella che
# l'API di oggi accetta di creare
TID=$(q "INSERT INTO tornei (nome, categoria_id, societa_id, data_inizio, data_fine, luogo, organizzatore)
         VALUES ('__mig__-COPPA', $CAT_A, $SOC, '2027-01-10', '2027-01-11', 'Palazzetto', 'ASD')
         RETURNING id;" | head -1 | tr -d '[:space:]')
if [ -z "$TID" ]; then
  echo "  il torneo di prova non e' stato creato: mi fermo, perche' senza dati le asserzioni non misurano niente"
  echo "  0 passati, 1 falliti (prerequisiti)"
  exit 1
fi
q "INSERT INTO tornei_categorie (torneo_id, categoria_id) VALUES ($TID, $CAT_A), ($TID, $CAT_B);
   INSERT INTO liste_torneo (nome, categoria_id, societa_id, torneo_id) VALUES
     ('__mig__-foglio A', $CAT_A, $SOC, $TID),
     ('__mig__-foglio B', $CAT_B, $SOC, $TID);" >/dev/null
ck "il torneo $TID ha i suoi due fogli, di categorie diverse" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id = $TID;")" "2"

echo "--- eseguo run_migrations() con quel dato presente (e' la condizione di PROD) ---"
OUT=$($SSH "docker exec $BE python -c 'from app.migrations.run import run_migrations; run_migrations()' 2>&1")
echo "$OUT" | sed 's/^/  | /' | tail -8

# Il punto della correzione: questa riga NON deve comparire. Prima compariva a ogni avvio su PROD
# perche' WINTER CUP ha quattro fogli e l'UNIQUE vecchio ne ammetteva uno solo
ck "la migrazione obsoleta non produce piu' il suo warning" "$(printf '%s' "$OUT" | grep -c 'Migration warning (liste_torneo.torneo_id)')" "0"
ck "e non c'e' nessun UniqueViolation nelle migrazioni" "$(printf '%s' "$OUT" | grep -c 'UniqueViolation')" "0"
ck "il blocco che possiede il vincolo giusto continua a girare" "$(printf '%s' "$OUT" | grep -c 'Migration: Lista Tornei unica per (torneo, categoria)')" "1"

echo "--- lo stato finale degli indici ---"
INDECI=$(q "SELECT string_agg(indexname, ',' ORDER BY indexname) FROM pg_indexes WHERE tablename='liste_torneo';")
echo "   indici: $INDECI"
ck "l'indice vecchio 'un torneo = una lista' NON esiste piu'" "$(printf '%s' "$INDECI" | grep -c 'ux_liste_torneo_torneo,')" "0"
ck "esiste l'UNIQUE parziale su (torneo_id, categoria_id)" "$(printf '%s' "$INDECI" | grep -c 'ux_liste_torneo_torneo_categoria')" "1"
ck "la FK su tornei e' ancora li' (create_all non la rimette su, la rimette il blocco esplicito)" "$(q "SELECT count(*) FROM pg_constraint WHERE conname = 'liste_torneo_torneo_id_fkey';")" "1"

echo "--- il vincolo che conta deve restare severo ---"
DUP=$(q "INSERT INTO liste_torneo (nome, categoria_id, societa_id, torneo_id)
         VALUES ('__mig__-duplicato', $CAT_A, $SOC, $TID) RETURNING id;" 2>&1)
ck "due fogli per la STESSA categoria dello stesso torneo sono rifiutati dal DB" \
   "$(printf '%s' "$DUP" | grep -c 'ux_liste_torneo_torneo_categoria')" "1"
DUE_MANUALI=$(q "INSERT INTO liste_torneo (nome, categoria_id, societa_id, torneo_id) VALUES
                   ('__mig__-manuale 1', $CAT_A, $SOC, NULL),
                   ('__mig__-manuale 2', $CAT_A, $SOC, NULL) RETURNING id;" 2>&1)
ck "due liste manuali SENZA torneo convivono (l'UNIQUE e' parziale: i NULL non collidono)" \
   "$(printf '%s' "$DUE_MANUALI" | grep -ci 'duplicate key')" "0"
ck "e i due fogli del torneo sono ancora li', intatti" "$(q "SELECT count(*) FROM liste_torneo WHERE torneo_id = $TID;")" "2"

echo "--- ripulisco ---"
pulisci
ck "nessun residuo __mig__" "$(q "SELECT count(*) FROM liste_torneo WHERE nome LIKE '__mig__%';")" "0"

echo ""
echo "  $pass passati, $fail falliti"
[ "$fail" -eq 0 ] && exit 0 || exit 1
