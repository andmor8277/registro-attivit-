#!/bin/bash
# Verifica VISIVA del REGISTRO PRESENZE in verticale su telefono, con Chrome headless su DEV
# (http://192.168.178.133:3000/registro/19).
#
# Perche' esiste. Il titolare ha chiesto: «invece di obbligare la modalita' orizzontale, facciamo in
# modo che si aprano solo i giorni di allenamento di quella settimana, cosi' sono 3 caselle da
# visualizzare e sul telefono si possono vedere in verticale». E' una modifica che nessun test
# esistente vede: i test API sul registro (test_registro_tenant.sh) verificano chi legge e chi scrive,
# non quante colonne ci sono. E il build di Vite non vede nessuna delle tre regressioni possibili:
#   1. le colonne a schermo che restano quelle del mese (il pulsante "Settimana" ci sarebbe comunque);
#   2. il FOGLIO DI STAMPA che scivola dietro la vista settimana: a schermo tutto giusto, e in
#      segreteria arriva un foglio "Registro di Novembre" con dentro una settimana sola;
#   3. la settimana che sconfinà nel mese accanto che cerca le celle per NUMERO di giorno: il 30
#      novembre leggerebbe (e scriverebbe) il 30 dicembre. Due numeri identici, due date diverse,
#      nessun errore da nessuna parte.
#
# Dove sta il dato, e perche' il test NON sceglie la settimana da se'. Le asserzioni sul mese accanto
# hanno bisogno di RIGHE VERE in quel mese: e' il wrapper che le calcola (con Postgres, non con la
# stessa aritmetica JS della pagina) e le semina, e poi passa tutto al browser come variabile
# d'ambiente. Se il test si scegliesse la settimana e il DB fosse preparato per un'altra, le asserzioni
# "la cella del mese accanto e' popolata" sarebbero verdi sul niente.
#
# Il test SCRIVE nel DB (una cella cliccata fa upsert_registro). Come in verifica_ui_lavagna.sh: prima
# di toccare qualunque cosa si mette in snapshot l'intervallo di date usato, e senza snapshot valido il
# test NON PARTE; il ripristino scatta anche in caso di eccezione (trap sull'EXIT) e l'ultima asserzione
# verifica che lo stato finale coincida con quello di partenza per HASH, non per "ho eseguito il comando".
#
# NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Google Chrome. Si lancia a mano:
#   bash scripts/test/verifica_ui_registro.sh
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/usr/bin/google-chrome-stable}"
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" 2>&1 | tr -d '\r'; }
CAT="${CAT:-19}"
CAT_PORTIERI="${CAT_PORTIERI:-31}"
SOC=1
CODICE="${SEED_CODICE:-X}"

if [ ! -x "$CHROME" ]; then echo "serve Google Chrome ($CHROME). Sovrascrivibile con CHROME=/percorso/chrome"; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "serve node"; exit 1; fi

# Due secondi che ne risparmiano mezz'ora: un identificatore del template che <script setup> non espone
# rende la pagina BIANCA, e tutte le asserzioni sotto sarebbero rosse (o peggio, verdi sul niente)
echo "--- controllo statico del template ---"
for f in src/features/presenze/Registro.vue src/features/presenze/RegistroPrintSheet.vue; do
  (cd "$DIR/../../frontend" && node "$DIR/controllo_template.cjs" "$f") || {
    echo "  $f: il template usa identificatori che <script setup> non espone, la pagina sarebbe bianca"
    echo "  0 passati, 1 falliti (controllo template)"
    exit 1
  }
done

echo "--- preparo gli utenti di prova su DEV ---"
PREP=$(bash "$DIR/prepara_demo_tornei.sh" 2>&1)
echo "$PREP" | sed 's/^/  /'
PW=$(printf '%s' "$PREP" | sed -n 's/.*password_admin_demo=\(.*\)/\1/p' | tail -1)
if [ -z "$PW" ]; then
  echo "  gli utenti di prova non ci sono: mi fermo, perche' senza login le asserzioni non misurano niente"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti)"
  exit 1
fi

echo
echo "--- i giorni di allenamento, letti dal DB (fonte indipendente dalla pagina) ---"
GIORNI=$(q "SELECT giorni FROM categorie WHERE id=$CAT")
# il CSV finisce dentro un IN (): validato prima, perche' un valore qualsiasi qui sarebbe SQL injection
if ! printf '%s' "$GIORNI" | grep -qE '^[0-6](,[0-6]*)*$'; then
  echo "  BLOCCATO: categorie.giorni per la categoria $CAT non e' un elenco di 0-6: '$GIORNI'"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti: giorni di allenamento illeggibili)"
  exit 1
fi
echo "  categoria $CAT giorni=$GIORNI (0=domenica, 1=lunedi', come getDay() di JavaScript)"

# ── la settimana a cavallo, calcolata da POSTGRES e non dalla pagina ────────────────
# Sarebbe un falso verde calcolarla con la stessa aritmetica JS che la pagina usa: se la regola del
# lunedi'/giovedi' fosse sbagliata in un posto, sbagliarla anche qui la renderebbe "confermata".
# NB: generate_series NON esiste sui date (generate_series(date,date,integer) non esiste), quindi gli
# intervalli si fanno sui timestamp e si torna ai date col cast: scritto sui date il query fallisce e
# la settimana a cavallo risulta "inesistente", cioe' il test si ferma per colpa del test.
DOW=$(date +%u)                       # 1=lunedi' .. 7=domenica
LUN_OGGI=$(date -d "-$((DOW-1)) days" +%F)
LETTURA=$(q "
WITH d AS (SELECT generate_series('$LUN_OGGI'::timestamp, ('$LUN_OGGI'::date + 91)::timestamp, interval '7 days')::date AS lun),
     g AS (SELECT d.lun AS lun, (d.lun + n)::date AS x FROM d CROSS JOIN generate_series(0,6) n),
     t AS (
  SELECT g.lun AS lun,
    (SELECT min(g2.x) FROM g g2 WHERE g2.lun = g.lun AND EXTRACT(DOW FROM g2.x)::int IN ($GIORNI)
       AND date_trunc('month', g2.x::timestamp) <> date_trunc('month', (g.lun + 3)::timestamp)) AS adj,
    (SELECT min(g2.x) FROM g g2 WHERE g2.lun = g.lun AND EXTRACT(DOW FROM g2.x)::int IN ($GIORNI)
       AND date_trunc('month', g2.x::timestamp) =  date_trunc('month', (g.lun + 3)::timestamp)) AS nel_mese
  FROM g GROUP BY g.lun)
SELECT lun||'|'||adj||'|'||nel_mese||'|'||to_char((lun + 3)::timestamp, 'YYYY-MM')||'|'||
       ((lun - '$LUN_OGGI'::date) / 7)
  FROM t WHERE adj IS NOT NULL AND nel_mese IS NOT NULL ORDER BY lun LIMIT 1")
IFS='|' read -r LUN_CROSS DATA_ADJ DATA_MESE MESE_ATTESO AVANTI <<< "$LETTURA"
if [ -z "${LUN_CROSS:-}" ] || [ -z "${DATA_ADJ:-}" ] || [ -z "${DATA_MESE:-}" ]; then
  echo "  BLOCCATO: in 13 settimane da oggi non trovo una settimana con un giorno di allenamento nel"
  echo "  mese accanto: le asserzioni sul mese accanto non avrebbero un bersaglio"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti: nessuna settimana a cavallo)"
  exit 1
fi
echo "  oggi=$(date +%F)  lunedi' di oggi=$LUN_OGGI"
echo "  settimana a cavallo: lunedi'=$LUN_CROSS  giorno nel MESE ACCANTO=$DATA_ADJ  giorno nel MESE=$DATA_MESE"
echo "  il mese della settimana (quello del giovedi', ISO 8601) = $MESE_ATTESO   avanzamenti di frecce: $AVANTI"

# il giorno OMONIMO nel mese mostrato: e' li' che finisce la scrittura se le celle vengono cercate per
# numero di giorno invece che per data (2026-11-30 -> 2026-12-30). Serve saperlo ADESSO, perche' fra le
# date da liberare c'e' anche lui
GIORNO_ADJ=$(printf '%s' "$DATA_ADJ" | cut -d- -f3)
OMBRA="$MESE_ATTESO-$(printf '%02d' "$((10#$GIORNO_ADJ))")"
echo "  giorno ombra (dove finirebbe la scrittura con le celle cercate per numero): $OMBRA"

# Due ragazzi LIBERI SULLE DATE CHE IL TEST TOCCA -- non "senza nessuna presenza": su DEV tutti e 38 i
# non-portieri della 2016 hanno gia' righe nel registro, quindi il criterio "nessuna riga al mondo" non
# trova nessuno e il test si ferma per colpa sua. Cio' che serve davvero e' che le tre date in gioco
# (mese accanto, giorno nel mese, giorno ombra) siano vuote per loro, e che non abbiano un infortunio
# che copra quelle date: un infortunio attivo blocca la cella (getCodice risponde "I" e openEdit non
# apre il modal), e il rosso accuserebbe la vista settimana per colpa del dato.
# Il TOT atteso NON e' scritto qui: lo conta il DB dopo la semina, quindi le eventuali righe preesistenti
# del ragazzo sono gia' dentro l'atteso e il confronto resta vero.
RAGAZZI=$(q "SELECT p.id||'|'||upper(btrim(p.cognome))||' '||upper(btrim(p.nome))
               FROM persone p LEFT JOIN gruppi g ON g.id = p.gruppo_id
              WHERE p.categoria_id = $CAT AND lower(coalesce(g.nome,'')) <> 'portieri'
                AND NOT EXISTS (SELECT 1 FROM registro r WHERE r.persona_id = p.id
                                  AND r.data IN ('$DATA_ADJ','$DATA_MESE','$OMBRA'))
                AND NOT EXISTS (SELECT 1 FROM infortuni i WHERE i.persona_id = p.id
                                  AND ( (i.data_inizio <= '$DATA_ADJ'::date  AND (i.data_fine IS NULL OR i.data_fine >= '$DATA_ADJ'::date))
                                     OR (i.data_inizio <= '$DATA_MESE'::date AND (i.data_fine IS NULL OR i.data_fine >= '$DATA_MESE'::date)) ))
              ORDER BY p.cognome, p.nome LIMIT 2")
P1=$(printf '%s\n' "$RAGAZZI" | sed -n '1p' | cut -d'|' -f1)
P1_NOME=$(printf '%s\n' "$RAGAZZI" | sed -n '1p' | cut -d'|' -f2)
P2=$(printf '%s\n' "$RAGAZZI" | sed -n '2p' | cut -d'|' -f1)
P2_NOME=$(printf '%s\n' "$RAGAZZI" | sed -n '2p' | cut -d'|' -f2)
if [ -z "$P1" ] || [ -z "$P2" ]; then
  echo "  BLOCCATO: servono due ragazzi della categoria $CAT senza presenze e senza infortuni"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti: ragazzi non disponibili)"
  exit 1
fi
echo "  semino su '$P1_NOME' ($P1), scrivo a schermo su '$P2_NOME' ($P2)"

echo
echo "--- snapshot dell'intervallo di date PRIMA di toccare qualunque cosa ---"
DA="2026-01-01"; A="2027-12-31"
HASH_SQL="SELECT coalesce(md5(string_agg(id||'|'||persona_id||'|'||data::text||'|'||coalesce(codice,'NULL')||'|'||categoria_id,'|' ORDER BY id)),'DB-VUOTO')
          FROM registro WHERE categoria_id IN ($CAT,$CAT_PORTIERI) AND data BETWEEN '$DA' AND '$A'"
SNAP=$(q "SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'societa_id',societa_id,'persona_id',persona_id,
                    'data',data::text,'codice',codice,'categoria_id',categoria_id) ORDER BY id),'[]'::jsonb)::text
          FROM registro WHERE categoria_id IN ($CAT,$CAT_PORTIERI) AND data BETWEEN '$DA' AND '$A'")
N_RIGHE_PRIMA=$(q "SELECT count(*) FROM registro WHERE categoria_id IN ($CAT,$CAT_PORTIERI) AND data BETWEEN '$DA' AND '$A'")
HASH_PRIMA=$(q "$HASH_SQL")
case "$SNAP" in
  \[*\]) : ;;
  *) echo "  BLOCCATO: lo snapshot di 'registro' non e' JSON: '$(printf '%s' "$SNAP" | head -c 90)'"
     echo "  senza uno snapshot ripristinabile il test non parte: sarebbe un test che scrive e non sa tornare indietro"
     bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
     echo "  0 passati, 1 falliti (prerequisiti: snapshot non valido)"
     exit 1 ;;
esac
if [ -z "$HASH_PRIMA" ]; then
  echo "  BLOCCATO: non riesco a leggere lo stato iniziale di 'registro'"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti: DB non leggibile)"
  exit 1
fi
echo "  righe=$N_RIGHE_PRIMA  stato=$HASH_PRIMA  ($(printf '%s' "$SNAP" | wc -c) byte di snapshot)"

RIPRISTINATO=0
ripristina() {
  [ "$RIPRISTINATO" = "1" ] && return 0
  local esc; esc=$(printf '%s' "$SNAP" | sed "s/'/''/g")
  q "DELETE FROM registro WHERE categoria_id IN ($CAT,$CAT_PORTIERI) AND data BETWEEN '$DA' AND '$A';
     INSERT INTO registro (id, societa_id, persona_id, data, codice, categoria_id)
       SELECT (r->>'id')::int, (r->>'societa_id')::int, (r->>'persona_id')::int,
              (r->>'data')::date, NULLIF(r->>'codice',''), (r->>'categoria_id')::int
         FROM jsonb_array_elements('$esc'::jsonb) r;
     SELECT setval(pg_get_serial_sequence('registro','id'), (SELECT coalesce(max(id),1) FROM registro));" >/dev/null
  RIPRISTINATO=1
}
# il test puo' andare in eccezione a meta': il ripristino deve scattare comunque, non solo sul percorso
# felice (e' la stessa ragione per cui i dati di prova li pulisce il wrapper e non il test)
trap 'if [ "$RIPRISTINATO" = "0" ]; then echo "  !! ripristino da snapshot attivato dalla trap"; ripristina; fi' EXIT

echo
echo "--- semino le due righe che il browser dovra' vedere ---"
# P1: una riga NEL mese della settimana e una nel mese ACCANTO. Le due insieme sono il test del TOT:
# se qualcuno fondesse registroExtra con registro, il TOT diventerebbe 2 invece di 1
q "INSERT INTO registro (societa_id, persona_id, data, codice, categoria_id) VALUES
     ($SOC, $P1, '$DATA_ADJ', '$CODICE', $CAT),
     ($SOC, $P1, '$DATA_MESE', '$CODICE', $CAT);" >/dev/null
SEED_TOT=$(q "SELECT count(*) FROM registro r
                WHERE r.persona_id=$P1 AND r.categoria_id=$CAT AND r.codice IN ('X','R')
                  -- il cast sul letterale serve: date_trunc('month','2026-12-01') e' AMBIGUO per Postgres
                  -- (timestamp / timestamptz / interval) e la query fallisce, lasciando SEED_TOT con il
                  -- testo dell'errore in mano al confronto -- che diventa un rosso sul test, non sull'app
                  AND r.data >= date_trunc('month','$MESE_ATTESO-01'::date)::date
                  AND r.data <  date_trunc('month','$MESE_ATTESO-01'::date)::date + interval '1 month'
                  -- totalePresenze() esclude le righe coperte da un infortunio attivo: se qui sopra
                  -- non lo escludessi, l'atteso sarebbe piu' alto di cio' che la pagina dipinge e il
                  -- rosso accuserebbe la vista settimana per colpa del dato
                  AND NOT EXISTS (SELECT 1 FROM infortuni i WHERE i.persona_id = r.persona_id
                                    AND i.data_inizio <= r.data
                                    AND (i.data_fine IS NULL OR i.data_fine >= r.data))")
SEED_VERIFICATE=$(q "SELECT count(*) FROM registro WHERE persona_id=$P1 AND categoria_id=$CAT AND data IN ('$DATA_ADJ','$DATA_MESE')")
if [ "$SEED_VERIFICATE" != "2" ]; then
  echo "  BLOCCATO: le due righe seminate non ci sono (letto $SEED_VERIFICATE, atteso 2): il browser"
  echo "  non avrebbe niente da mostrare e 'la cella del mese accanto e' vuota' sarebbe verde per il"
  echo "  motivo sbagliato"
  echo "  0 passati, 1 falliti (prerequisiti: semina fallita)"
  exit 1
fi
echo "  ok: 2 righe seminate, TOT atteso sulla riga di $P1_NOME = $SEED_TOT (solo le righe del mese)"

export THOF_UI_OUT="${THOF_UI_OUT:-/tmp/opencode/ui-registro}"
rm -rf "$THOF_UI_OUT"
# la cartella va creata QUI, prima di tee: se non esiste, GNU tee non apre il file, stampa l'errore su
# stderr e continua a copiare su stdout -- il test gira, il log non viene scritto, e le asserzioni che
# leggono i marker diventano rosse per colpa del wrapper
mkdir -p "$THOF_UI_OUT"
LOG_NODE="$THOF_UI_OUT/node.log"

export LUN_CROSS SETTIMANE_AVANTI="$AVANTI" DATA_ADJACENTE="$DATA_ADJ" DATA_MESE="$DATA_MESE"
export MESE_ATTESO SEED_NOME="$P1_NOME" SEED_TOT SCRIVI_NOME="$P2_NOME" SEED_CODICE="$CODICE"

node "$DIR/ui_registro.cjs" "demo_tornei_mister1" "$PW" "$CAT" 2>&1 | tee "$LOG_NODE"
RC=${PIPESTATUS[0]}
if [ "$RC" = "2" ]; then
  echo "  il test non aveva i prerequisiti (exit 2): le sue asserzioni non sono state eseguite"
  echo "  0 passati, 1 falliti (prerequisiti nel test node)"
  exit 1
fi

echo
echo "--- cosa dice il DATABASE di cio' che il browser ha visto ---"
ck() { if [ -z "$2" ] && [ -z "$3" ]; then echo "  FAIL $1 -> entrambi vuoti: non ha misurato nulla"; RC=1; return 0; fi
       if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 -> '$2' (atteso '$3')"; RC=1; fi; }
marker() { grep -oE "^$1=.*" "$LOG_NODE" 2>/dev/null | head -1 | cut -d= -f2-; }
# conteggio dei giorni di allenamento in un intervallo: POSTGRES, non la stessa aritmetica JS della
# pagina. Gli intervalli nascono sui timestamp per lo stesso motivo del query qui sopra
conta_da() { q "SELECT count(*) FROM generate_series('$1'::timestamp, ('$1'::date + $2)::timestamp, interval '1 day') d
                 WHERE EXTRACT(DOW FROM d)::int IN ($GIORNI)"; }
conta_mese() { q "SELECT count(*) FROM generate_series(date_trunc('month','$1'::date)::timestamp,
                                          (date_trunc('month','$1'::date) + interval '1 month - 1 day')::timestamp,
                                          interval '1 day') d
                 WHERE EXTRACT(DOW FROM d)::int IN ($GIORNI)"; }
MESI_IT=(Gennaio Febbraio Marzo Aprile Maggio Giugno Luglio Agosto Settembre Ottobre Novembre Dicembre)
MESE_ATTESO_LABEL="${MESI_IT[$(( 10#$(printf '%s' "$MESE_ATTESO" | cut -d- -f2) - 1 ))]}"
ANNO_ATTESO=$(printf '%s' "$MESE_ATTESO" | cut -d- -f1)
MESE_ADJ_LABEL="${MESI_IT[$(( 10#$(printf '%s' "$DATA_ADJ" | cut -d- -f2) - 1 ))]}"
ANNO_ADJ=$(printf '%s' "$DATA_ADJ" | cut -d- -f1)

CS=$(marker COLONNE-SCHERMO); CM=$(marker COLONNE-MESE-VISTA); CC=$(marker COLONNE-CROSS)
CF=$(marker COLONNE-FOLIO); MF=$(marker MESE-FOLIO); PF=$(marker PERIODO-FOLIO)
DM=$(marker DATA-MODAL); CSZ=$(marker CELLA-SCRITTA); ES=$(marker ETICHETTA-SETTIMANA)

if [ -n "$CS" ]; then ck "le colonne della settimana di oggi sono i giorni di allenamento di quella settimana (Postgres)" "$CS" "$(conta_da "$LUN_OGGI" 6)"; else echo "  FAIL il test non ha detto quante colonne ha dipinto: nessuna asserzione sulle colonne ha un bersaglio"; RC=1; fi
if [ -n "$CM" ]; then ck "il modo Mese dipinge i giorni di allenamento dell'intero mese (Postgres)" "$CM" "$(conta_mese "$MESE_ATTESO-01")"; else echo "  FAIL il test non ha detto quante colonne ha il modo Mese"; RC=1; fi
if [ -n "$CC" ]; then ck "le colonne della settimana a cavallo sono i suoi giorni di allenamento (Postgres)" "$CC" "$(conta_da "$LUN_CROSS" 6)"; else echo "  FAIL il test non ha detto quante colonne ha la settimana a cavallo"; RC=1; fi
if [ -n "$CF" ]; then ck "IL FOGLIO DI STAMPA ha i giorni di allenamento del MESE, non della settimana (Postgres)" "$CF" "$(conta_mese "$MESE_ATTESO-01")"; else echo "  FAIL il test non ha contato le colonne del foglio di stampa"; RC=1; fi
ck "il foglio di stampa ha PIU' colonne dello schermo (lo schermo e' in vista settimana)" \
   "$([ -n "$CF" ] && [ -n "$CC" ] && [ "$CF" -gt "$CC" ] 2>/dev/null && echo si || echo no)" "si"
# il guard -n non e' decorativo: grep su stringa VUOTA matcha tutto, quindi un'etichetta mai letta
# sarebbe diventata verde per il motivo sbagliato
ck "il foglio di stampa dichiara il mese della settimana ($MESE_ATTESO_LABEL $ANNO_ATTESO)" \
   "$([ -n "$PF" ] && printf '%s' "$PF" | grep -qi "$MESE_ATTESO_LABEL" && printf '%s' "$PF" | grep -q "$ANNO_ATTESO" && echo si || echo no)" "si"
ck "il mese che il browser ha messo sul foglio e' quello del giovedi', calcolato da Postgres" "$MF" "$MESE_ATTESO"
ck "la settimana scelta attraversa DUE mesi (altrimenti il mese accanto non viene provato)" \
   "$(q "SELECT CASE WHEN date_trunc('month','$LUN_CROSS'::date) <> date_trunc('month','$LUN_CROSS'::date + 6) THEN 'si' ELSE 'no' END")" "si"
# sul telefono l'etichetta della settimana e' la forma CORTA ("30 Nov – 6 Dic 2026"), quindi si cerca
# l'abbreviazione: funziona con entrambe le forme, perche' "Novembre" contiene "Nov"
MESI_CORTI_IT=(Gen Feb Mar Apr Mag Giu Lug Ago Set Ott Nov Dic)
ADJ_CORTO="${MESI_CORTI_IT[$(( 10#$(printf '%s' "$DATA_ADJ" | cut -d- -f2) - 1 ))]}"
ATT_CORTO="${MESI_CORTI_IT[$(( 10#$(printf '%s' "$MESE_ATTESO" | cut -d- -f2) - 1 ))]}"
ck "l'etichetta della settimana nomina entrambi i mesi ($ADJ_CORTO e $ATT_CORTO)" \
   "$([ -n "$ES" ] && printf '%s' "$ES" | grep -qi "$ADJ_CORTO" && printf '%s' "$ES" | grep -qi "$ATT_CORTO" && echo si || echo no)" "si"
# norm() in pagina maiuscola il testo, quindi anche l'atteso va maiuscolo: confrontare "30 Novembre 2026"
# con "30 NOVEMBRE 2026" sarebbe un rosso sul test, non sull'app
ATTESO_MODALE=$(printf '%s %s %s' "$((10#$GIORNO_ADJ))" "$MESE_ADJ_LABEL" "$ANNO_ADJ" | tr '[:lower:]' '[:upper:]')
ck "il modal della cella dice la data VERA del mese accanto ($ATTESO_MODALE)" "$DM" "$ATTESO_MODALE"

echo
echo "--- la scrittura a schermo e' arrivata a terra, e sulla data giusta ---"
if [ -n "$CSZ" ]; then
  ck "il test ha detto su quale cella ha scritto" "$CSZ" "$DATA_ADJ"
  ck "la riga scritta a schermo esiste nel DB, su QUELLA data" \
     "$(q "SELECT count(*) FROM registro WHERE persona_id=$P2 AND categoria_id=$CAT AND data='$DATA_ADJ' AND codice='$CODICE'")" "1"
  # questa e' l'asserzione che vale la modifica: con le celle cercate per numero di giorno la scrittura
  # finiva sul giorno omonimo del mese mostrato (30 novembre -> 30 dicembre) e nessuno se ne accorgeva
  if [ "$OMBRA" != "$DATA_ADJ" ]; then
    ck "nessuna riga sul giorno OMONIMO del mese mostrato ($OMBRA): le celle sono cercate per DATA" \
       "$(q "SELECT count(*) FROM registro WHERE persona_id=$P2 AND categoria_id=$CAT AND data='$OMBRA'")" "0"
  else
    echo "  (il giorno ombra coincide con quello scritto: asserzione non applicabile, non 'verde')"
  fi
else
  echo "  FAIL il test non ha scritto nessuna cella: le asserzioni sulla scrittura non misurerebbero niente"
  RC=1
fi

ripristina
echo "  ripristino eseguito dallo snapshot"
ck "l'intervallo di registro e' tornato ad avere le righe di prima" \
   "$(q "SELECT count(*) FROM registro WHERE categoria_id IN ($CAT,$CAT_PORTIERI) AND data BETWEEN '$DA' AND '$A'")" "$N_RIGHE_PRIMA"
ck "l'INTERO stato di 'registro' dell'intervallo e' identico a prima del test" \
   "$(q "$HASH_SQL")" "$HASH_PRIMA"
# non "il ragazzo non ha piu' nessuna riga": su DEV i ragazzi hanno gia' le loro presenze reali, e
# quel conteggio sarebbe rosso perche' il ripristino le ha giustamente lasciate. Qui si verifica che
# NON RESTI cio' che ha scritto il test
ck "le date toccate dal test non lasciano tracce" \
   "$(q "SELECT count(*) FROM registro WHERE persona_id IN ($P1,$P2) AND data IN ('$DATA_ADJ','$DATA_MESE','$OMBRA')")" "0"

echo
echo "--- ripulisco i dati di prova ---"
bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
echo "  fatto"

exit $RC
