#!/bin/bash
# Prova scripts/ops/set_scadenza_certificati.{sh,py} su DEV con dati seminati a mano.
# E' DENTRO la suite: run_suite_dev.sh lo scopre da solo col nome test_*.sh. Le guardie di uno script
# che scrive certificati medici non possono dipendere da chi si ricorda di lanciarle a mano.
#   bash scripts/test/test_set_scadenza_certificati.sh
#
# Le guardie contano piu' del percorso buono: questo script scrive le scadenze dei certificati medici
# di ragazzi, e il modo in cui si sbaglia non e' "l'UPDATE da' errore" bensi' "l'UPDATE scrive la
# riga giusta per la squadra sbagliata", che non produce nessun errore da nessuna parte.
#
# Tocca solo la propria categoria seminata (__test_cert__): le due categorie vere che usa nei casi di
# blocco (cat 1 archiviata, cat 26 vuota) devono restare INTATTE, e infatti viene misurato.
set -u
cd "$(cd "$(dirname "$0")/../.." && pwd)" || exit 9
KV="$HOME/.ssh/id_ed25519_dev"; IP=192.168.178.133
SSH="ssh -i $KV -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ -n "$2" ] && [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }

# Il wrapper fa un pg_dump a ogni invocazione, anche in dry-run (come cifra_cf.sh). Sei invocazioni
# vogliono dire sei dump in /root su DEV a ogni esecuzione della suite: si accumulano all'infinito.
# Si annotano QUI i percorsi che ha creato QUESTO run, cosi' la pulizia cancella solo quelli.
# Su PROD il backup resta: li' a proteggerlo c'e' una scrittura vera e non verificata da nessun test.
BACKUP=""
tb() { local f; for f in $(printf '%s\n' "$1" | grep -oE "/root/dev_pre_scadenza_cert_[0-9_]+\.sql\.gz"); do
  case " $BACKUP " in *" $f "*) ;; *) BACKUP="$BACKUP $f";; esac; done; }

# Un solo punto di passaggio: ogni invocazione del wrapper passa di qui, cosi' i backup creati
# vengono annotati sempre e non solo dove qualcuno si ricorda di chiamare tb.
lancia() { OUT=$(timeout 600 bash scripts/ops/set_scadenza_certificati.sh "$@" 2>&1); tb "$OUT"; }

TC=__test_cert__
DATA=2027-07-01

echo "=== 0. semina: categoria di prova con 3 persone (2 senza data, 1 gia' con una data) ==="
q "DELETE FROM persone WHERE cognome LIKE '$TC%';
   DELETE FROM categorie WHERE nome = '$TC';" >/dev/null
q "INSERT INTO categorie (nome, anno, societa_id, is_archiviata, is_portieri)
   VALUES ('$TC', 2020, 1, 0, 0);" >/dev/null
TCID=$(q "SELECT id FROM categorie WHERE nome='$TC'")
[ -z "$TCID" ] && { echo "  semina fallita"; exit 1; }
# il cognome in MAIUSCOLO: POST /persone/ scrive cosi', e i confronti sul cognome falliscono per la forma
q "INSERT INTO persone (nome, cognome, societa_id, categoria_id, data_nascita, scadenza_certificato) VALUES
     ('Uno',   '${TC}A', 1, $TCID, '2020-01-10', NULL),
     ('Due',   '${TC}B', 1, $TCID, '2020-02-11', NULL),
     ('Tre',   '${TC}C', 1, $TCID, '2020-03-12', '2026-09-30');" >/dev/null
echo "  categoria $TCID, persone: $(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID")"

echo
echo "=== 1. dry-run: non deve scrivere nulla ==="
PRIMA=$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='$DATA'::date")
lancia dev $TCID $DATA "$TC" 2020
echo "$OUT" | grep -E "righe che cambiano|DRY-RUN|persone=|FERMO|FAIL" | sed 's/^/  /'
DOPO=$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='$DATA'::date")
ck "il dry-run non ha scritto nulla" "$DOPO" "$PRIMA"
ck "il dry-run annuncia 3 righe da cambiare" "$(printf '%s' "$OUT" | grep -oE 'righe che cambiano: [0-9]+' | grep -oE '[0-9]+')" "3"

echo
echo "=== 2. apply ==="
lancia dev $TCID $DATA "$TC" 2020 --applica
echo "$OUT" | grep -E "righe aggiornate|ok  |FAIL|commit|fatto\.|ROSSO|tutte le" | sed 's/^/  /'
ck "le 3 persone hanno la nuova data" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='$DATA'::date")" "3"
ck "nessuna persona della categoria resta senza data" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato IS NULL")" "0"
ck "la riga che aveva gia' una data e' stata sovrascritta (voluto: e' un'impostazione di massa)" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='2026-09-30'::date")" "0"

echo
echo "=== 3. guardia: anno sbagliato (la trappola delle due 'Esordienti') ==="
# Rimetto le righe a NULL PRIMA di provare: se restassero gia' a 2027-07-01, l'asserzione "nessuna
# scrittura" sarebbe verde anche con una scrittura avvenuta, perche' confronta lo stato con se stesso.
# E' il falso verde del "confronta il valore vecchio con se stesso" gia' visto in test_tornei_mister.sh.
q "UPDATE persone SET scadenza_certificato = NULL WHERE categoria_id=$TCID;" >/dev/null
ck "le righe sono state riportate a NULL (prerequisito: senza questo il test non misura niente)" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato IS NULL")" "3"
lancia dev $TCID $DATA "$TC" 2021 --applica
echo "$OUT" | grep -E "FERMO|fallito" | head -3 | sed 's/^/  /'
[ "$(printf '%s' "$OUT" | grep -cE "FERMO.*anno|dry-run fallito")" -ge 1 ] && { pass=$((pass+1)); echo "  ok   l'anno errato blocca PRIMA di arrivare all'UPDATE"; } || { fail=$((fail+1)); echo "  FAIL l'anno errato NON ha bloccato"; }
ck "nessuna riga ha la data: la scrittura non e' proprio partita" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='$DATA'::date")" "0"
# Anche il nome sbagliato deve bloccare (stessa guardia, altro ramo)
lancia dev $TCID $DATA "pulcini" 2020 --applica
[ "$(printf '%s' "$OUT" | grep -cE "FERMO.*si chiama|dry-run fallito")" -ge 1 ] && { pass=$((pass+1)); echo "  ok   il nome errato blocca PRIMA di arrivare all'UPDATE"; } || { fail=$((fail+1)); echo "  FAIL il nome errato NON ha bloccato"; }
ck "neanche qui nessuna scrittura" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='$DATA'::date")" "0"

echo
echo "=== 4. guardia: categoria archiviata (Esordienti 2014, cat 1, 16 persone) ==="
lancia dev 1 $DATA esordienti 2014 --applica
echo "$OUT" | grep -E "FERMO|archiviata|fallito" | head -2 | sed 's/^/  /'
[ "$(printf '%s' "$OUT" | grep -cE 'archiviata|fallito')" -ge 1 ] && { pass=$((pass+1)); echo "  ok   la categoria archiviata e' stata rifiutata"; } || { fail=$((fail+1)); echo "  FAIL la categoria archiviata NON e' stata rifiutata"; }
ck "le 16 persone della cat 1 non hanno quella data" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=1 AND scadenza_certificato='$DATA'::date")" "0"

echo
echo "=== 5. guardia: categoria senza persone (Esordienti 2015, cat 26, vuota su DEV) ==="
lancia dev 26 $DATA esordienti 2015 --applica
echo "$OUT" | grep -E "FERMO|non ha persone|fallito" | head -2 | sed 's/^/  /'
[ "$(printf '%s' "$OUT" | grep -cE 'non ha persone|fallito')" -ge 1 ] && { pass=$((pass+1)); echo "  ok   la categoria vuota e' stata rifiutata"; } || { fail=$((fail+1)); echo "  FAIL la categoria vuota NON e' stata rifiutata"; }

echo
echo "=== 6. guardia che conta di piu': un UPDATE che colpisce FUORI dalla categoria ==="
# Mutazione reale: all'UPDATE viene aggiunto IN (cat, 19), cioe' travolge anche i 43 Pulcini.
# Devono diventare rosse DUE guardie indipendenti e il transaction deve fare ROLLBACK.
# Le due insieme perche' e' il punto: "righe aggiornate quante previsto" guarda il conteggio interno,
# "nessuna riga fuori dalla categoria" guarda il resto della tabella. Una delle due da sola puo'
# coincidere per caso; la seconda no, e prima di questa correzione non c'era (confrontava il totale
# con totale_prima + righe_aggiornate, cioe' cresceva insieme all'UPDATE: verde anche col trabocco).
PRIMA_PULCINI=$(q "SELECT count(*) FROM persone WHERE categoria_id=19 AND scadenza_certificato='$DATA'::date")
ck "prerequisito: le righe di prova sono a NULL prima di sfidare la guardia" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='$DATA'::date")" "0"
sed 's|WHERE categoria_id = :c AND societa_id = :s"), {"d": DATA, "c": CAT, "s": cat.societa_id})|WHERE categoria_id IN (:c, 19) AND societa_id = :s"), {"d": DATA, "c": CAT, "s": cat.societa_id})|' \
  scripts/ops/set_scadenza_certificati.py > /tmp/opencode/set_cert_mutato.py
if ! diff -q scripts/ops/set_scadenza_certificati.py /tmp/opencode/set_cert_mutato.py >/dev/null; then
  echo "  mutazione applicata (il file e' cambiato)"
else
  echo "  MUTAZIONE NON PARTITA: il test sotto non misurerebbe niente"
  fail=$((fail+1))
fi
OUT=$($SSH "docker exec -i -w /app $BE python - apply $TCID $DATA $TC 2020" < /tmp/opencode/set_cert_mutato.py 2>&1)
echo "$OUT" | grep -E "FAIL|ROLLBACK|VERIFICHE ROSSE|righe aggiornate" | sed 's/^/  /'
[ "$(printf '%s' "$OUT" | grep -c ROLLBACK)" -ge 1 ] && { pass=$((pass+1)); echo "  ok   il WHERE che trabocca e' stato bloccato con ROLLBACK"; } || { fail=$((fail+1)); echo "  FAIL il WHERE che trabocca NON e' stato bloccato"; }
# le due guardie devono scattare ENTRAMBE: se una delle due fosse codice morto, qui si vede
[ "$(printf '%s' "$OUT" | grep -c 'FAIL righe aggiornate quante previsto')" -ge 1 ] \
  && { pass=$((pass+1)); echo "  ok   guardia 1 rossa: il conteggio righe non coincide"; } \
  || { fail=$((fail+1)); echo "  FAIL guardia 1 non rossa: il conteggio righe non viene confrontato"; }
[ "$(printf '%s' "$OUT" | grep -c 'FAIL nessuna riga FUORI dalla categoria')" -ge 1 ] \
  && { pass=$((pass+1)); echo "  ok   guardia 2 rossa: il traboccamento sulla tabella viene visto"; } \
  || { fail=$((fail+1)); echo "  FAIL guardia 2 non rossa: il traboccamento non viene visto"; }
DOPO_PULCINI=$(q "SELECT count(*) FROM persone WHERE categoria_id=19 AND scadenza_certificato='$DATA'::date")
ck "i 43 Pulcini non hanno ricevuto la data (il rollback ha retto)" "$DOPO_PULCINI" "$PRIMA_PULCINI"
ck "la categoria di prova non e' stata toccata dal tentativo fallito" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='$DATA'::date")" "0"

echo
echo "=== 7. percorso buono dopo i blocchi, e idempotenza ==="
lancia dev $TCID $DATA "$TC" 2020 --applica
ck "dopo tutti i blocchi l'applicazione buona riesce" \
   "$(q "SELECT count(*) FROM persone WHERE categoria_id=$TCID AND scadenza_certificato='$DATA'::date")" "3"
lancia dev $TCID $DATA "$TC" 2020
echo "$OUT" | grep -E "righe che cambiano" | sed 's/^/  /'
ck "la seconda esecuzione non trova nulla da cambiare" "$(printf '%s' "$OUT" | grep -oE 'righe che cambiano: [0-9]+' | grep -oE '[0-9]+$')" "0"

echo
echo "=== 8. pulizia ==="
q "DELETE FROM persone WHERE cognome LIKE '$TC%';
   DELETE FROM categorie WHERE nome = '$TC';" >/dev/null
rm -f /tmp/opencode/set_cert_mutato.py
# Si cancellano SOLO i dump annotati da questo run (pattern dev_pre_scadenza_cert_+timestamp), e solo
# su DEV. Qui sono davvero inutili: i due apply hanno scritto tre righe seminate e poi cancellate, e i
# sei dry-run non hanno scritto niente. Ripristinarne uno rimetterebbe nel DB le righe di prova che la
# pulizia ha appena tolto. Su PROD il backup NON si cancella: li' protegge una scrittura vera.
N=0
for f in $BACKUP; do
  case "$f" in
    /root/dev_pre_scadenza_cert_*.sql.gz)
      $SSH "rm -f -- $f"; N=$((N+1));;
    *) echo "  ATTENZIONE: percorso backup non riconosciuto, non lo tocco: $f";;
  esac
done
echo "  dump di questo run rimossi da /root: $N"
echo "  persone residue: $(q "SELECT count(*) FROM persone WHERE cognome LIKE '$TC%'")  categorie residue: $(q "SELECT count(*) FROM categorie WHERE nome='$TC'")"
ck "nessun residuo di prova" \
   "$(q "SELECT (SELECT count(*) FROM persone WHERE cognome LIKE '$TC%')+(SELECT count(*) FROM categorie WHERE nome='$TC')")" "0"

echo
echo "  ------------------------------------------------------------"
echo "  TOTALE: $pass passati, $fail falliti"
[ $fail -eq 0 ] && exit 0 || exit 1
