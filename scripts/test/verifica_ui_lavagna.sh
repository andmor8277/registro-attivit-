#!/bin/bash
# Verifica VISIVA della LAVAGNA TATTICA con Chrome headless su DEV
# (http://192.168.178.133:3000/allenamenti/19 -> calendario -> Esercizio -> lavagna).
#
# Perche' esiste. La lavagna era l'unica superficie dell'app con **zero** asserzioni sopra: nessun
# verifica_ui_*.sh la guardava, e il risultato e' la frase del titolare "ogni volta che tentiamo le
# modifiche la lavagna si rompe". Non e' sfortuna: un tipo nuovo va scritto in TRE catene if/else
# chiaviste sulla stessa stringa `el.tipo`, in due file diversi, per ~860 righe di codice diramato per
# tipo -- getElements (107) e loadElement (128) in lavagna-20250702.html, drawElementsCanvas (621) in
# Allenamenti.vue. Dimenticarne una non da' un errore: senza loadElement l'elemento SPARISCE alla
# riapertura in silenzio (`if(newEl) add(newEl)`, e il console.error scatta solo sulle eccezioni),
# senza drawElementsCanvas a schermo c'e' e nel PDF no.
#
# Cosa becca, che nessun altro test vede:
#   - un pulsante della palette dimenticato in una delle tre catene (Parte A, dal solo sorgente);
#   - un pulsante che nel sorgente c'e' ma a schermo non viene dipinto;
#   - un tipo che sopravvive a schermo ma non al salvataggio, o alla riapertura (il modo reale in cui
#     il mister perde gli oggetti);
#   - un tipo sconosciuto nel DB che si porta via anche gli elementi buoni;
#   - un campo dell'elemento azzerato dalla lista bianca del payload di salvataggio;
#   - la console che si sporca mentre si lavora (nessuno la guarda mentre disegna).
#
# DOVE STA IL DATA, e perche' la prima versione di questo wrapper era un falso verde. Gli esercizi NON
# stanno in `allenamenti_giorno/esercizio/elemento` (ne' nelle versioni al singolare): quelle tabelle
# sono VUOTE e vivono solo nei modelli. La fonte reale e' la tabella `allenamenti` -- una riga per
# (categoria_id, data), con gli esercizi dentro la colonna JSONB `esercizi` (routers/allenamenti.py
# :74-83). Un'asserzione "disegnare non scrive nulla" fatta sulle tabelle relazionali era verde per
# sempre senza misurare niente.
#
# Il test SCRIVE nel DB, e qui lo si gestisce invece di fingere che non succeda: `addEsercizio` fa
# `markDirty(); debouncedSave()` (800 ms), quindi l'esercizio arriva a terra da solo. Si lavora sul
# MESE indicato da THOF_LAVAGNA_MESE (default 2027-02) e sul primo suo giorno di allenamento LIBERO
# (il calendario dipinge solo i giorni che stanno in `categorie.giorni`: cat 19 = lun/mer/ven).
# Prima di toccare niente si mette in snapshot l'INTERA categoria e, senza snapshot valido, il test
# NON PARTE: ripristinare "dopo" un'immagine presa "dopo" e' il falso verde gemello di quello del
# backup con `||`. Il ripristino scatta anche se il test va in eccezione (trap sull'EXIT), e l'ultima
# asserzione verifica che lo stato finale della categoria coincida con quello di partenza.
#
# NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Google Chrome. Si lancia a mano:
#   bash scripts/test/verifica_ui_lavagna.sh
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/usr/bin/google-chrome-stable}"
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" 2>&1 | tr -d '\r'; }
CAT="${CAT:-19}"
MESE_PROVA="${THOF_LAVAGNA_MESE:-2027-02}"
STRUMENTI_ATTESI=23   # gli strumenti della palette: il disegno completo che deve arrivare a terra

if [ ! -x "$CHROME" ]; then echo "serve Google Chrome ($CHROME). Sovrascrivibile con CHROME=/percorso/chrome"; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "serve node"; exit 1; fi
if ! printf '%s' "$MESE_PROVA" | grep -qE '^[0-9]{4}-[0-9]{2}$'; then
  echo "THOF_LAVAGNA_MESE deve essere AAAA-MM, non '$MESE_PROVA'"; exit 1
fi

# Due secondi che ne risparmiano mezz'ora: se il template usa un identificatore che <script setup> non
# espone, la pagina e' BIANCA e il test sotto non troverebbe niente, sembrando un difetto dell'app
echo "--- controllo statico del template ---"
(cd "$DIR/../../frontend" && node "$DIR/controllo_template.cjs" "src/features/allenamenti/Allenamenti.vue") || {
  echo "  Allenamenti.vue: il template usa identificatori che <script setup> non espone, la pagina sarebbe bianca"
  echo "  0 passati, 1 falliti (controllo template)"
  exit 1
}

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
echo "--- snapshot dell'intera categoria $CAT PRIMA di toccare qualunque cosa ---"
# senza uno snapshot valido NON si parte: e' il gemello del `[ -f backup ] || cp` che ha gia' bruciato
# del lavoro, solo che qui la copia la si farebbe DOPO la scrittura
HASH_SQL="SELECT coalesce(md5(string_agg(id||'|'||data::text||'|'||coalesce(esercizi::text,''),'|' ORDER BY id)),'DB-VUOTO')
          FROM allenamenti WHERE categoria_id=$CAT"
SNAP=$(q "SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'data',data::text,'esercizi',esercizi,
                   'created_at',created_at::text,'updated_at',updated_at::text) ORDER BY id),'[]'::jsonb)::text
          FROM allenamenti WHERE categoria_id=$CAT")
N_RIGHE_PRIMA=$(q "SELECT count(*) FROM allenamenti WHERE categoria_id=$CAT")
HASH_PRIMA=$(q "$HASH_SQL")
case "$SNAP" in
  \[*\]) : ;;
  *) echo "  BLOCCATO: lo snapshot di 'allenamenti' (cat $CAT) non e' JSON: '$(printf '%s' "$SNAP" | head -c 90)'"
     echo "  senza uno snapshot ripristinabile il test non parte: sarebbe un test che scrive e non sa tornare indietro"
     bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
     echo "  0 passati, 1 falliti (prerequisiti: snapshot non valido)"
     exit 1 ;;
esac
if [ -z "$HASH_PRIMA" ]; then
  echo "  BLOCCATO: non riesco a leggere lo stato iniziale di 'allenamenti' (cat $CAT)"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti: DB non leggibile)"
  exit 1
fi
echo "  righe=$N_RIGHE_PRIMA  stato=$HASH_PRIMA  ($(printf '%s' "$SNAP" | wc -c) byte di snapshot)"

RIPRISTINATO=0
ripristina() {
  [ "$RIPRISTINATO" = "1" ] && return 0
  local esc; esc=$(printf '%s' "$SNAP" | sed "s/'/''/g")
  q "DELETE FROM allenamenti WHERE categoria_id=$CAT;
     INSERT INTO allenamenti (id, categoria_id, data, esercizi, created_at, updated_at)
       SELECT (r->>'id')::int, $CAT, (r->>'data')::date, r->'esercizi',
              NULLIF(r->>'created_at','')::timestamp, NULLIF(r->>'updated_at','')::timestamp
         FROM jsonb_array_elements('$esc'::jsonb) r;
     SELECT setval(pg_get_serial_sequence('allenamenti','id'),
                   (SELECT coalesce(max(id),1) FROM allenamenti));" >/dev/null
  RIPRISTINATO=1
}
# il test puo' andare in eccezione a meta': il ripristino deve scattare comunque, non solo sul percorso
# felice (e' la stessa ragione per cui i dati di prova li pulisce il wrapper e non il test)
trap 'if [ "$RIPRISTINATO" = "0" ]; then echo "  !! ripristino da snapshot attivato dalla trap"; ripristina; fi' EXIT

export THOF_UI_OUT="${THOF_UI_OUT:-/tmp/opencode/ui-lavagna}"
rm -rf "$THOF_UI_OUT"
# la cartella va creata QUI: se non esiste, `tee` non apre il file, stampa l'errore su stderr e
# continua a copiare su stdout -- il test gira, ma il log non viene scritto e le asserzioni che lo
# leggono (DATA-USATA) diventano rosse per colpa del wrapper
mkdir -p "$THOF_UI_OUT"
export THOF_LAVAGNA_MESE="$MESE_PROVA"
LOG_NODE="$THOF_UI_OUT/node.log"

node "$DIR/ui_lavagna.cjs" "$PW" "demo_tornei_mister1" "$CAT" 2>&1 | tee "$LOG_NODE"
RC=${PIPESTATUS[0]}

echo
echo "--- cosa dice il DATABASE di cio' che il browser ha visto ---"
ck() { if [ -z "$2" ] && [ -z "$3" ]; then echo "  FAIL $1 -> entrambi vuoti: non ha misurato nulla"; RC=1; return; fi
       if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 -> '$2' (atteso '$3')"; RC=1; fi; }
ckmin() { if [ -z "$2" ] || [ -z "$3" ]; then echo "  FAIL $1 -> lettura vuota: non ha misurato nulla"; RC=1; return; fi
       if [ "$2" -ge "$3" ] 2>/dev/null; then echo "  ok   $1 ($2, soglia $3)"; else echo "  FAIL $1 -> '$2', sotto la soglia $3"; RC=1; fi; }

# il test dice SU CHE GIORNO ha lavorato (letto dal titolo della pagina, non scritto a mano qui)
DATA_USATA=$(grep -oE 'DATA-USATA=[0-9]{4}-[0-9]{2}-[0-9]{2}' "$LOG_NODE" 2>/dev/null | head -1 | cut -d= -f2)
if [ -n "$DATA_USATA" ]; then
  echo "  ok   il test ha detto su quale giorno ha lavorato ($DATA_USATA)"
else
  echo "  FAIL il test non ha detto su quale giorno ha lavorato: le asserzioni sul DB non avrebbero un bersaglio"
  RC=1
fi
if [ -n "$DATA_USATA" ]; then
  # qui si misura che il test AVEVA scritto: senza questa, il confronto di dopo sarebbe verde anche se
  # il test non avesse salvato niente (e' il falso verde del "confronta lo stato con se stesso")
  ELEMENTI_A_TERRA=$(q "SELECT coalesce(sum(jsonb_array_length(coalesce(e->'elementi','[]'::jsonb))),0)
                        FROM allenamenti a, jsonb_array_elements(a.esercizi) e
                        WHERE a.categoria_id=$CAT AND a.data='$DATA_USATA'")
  ckmin "il disegno e' arrivato davvero in allenamenti.esercizi (misurato sul DB)" "$ELEMENTI_A_TERRA" "$STRUMENTI_ATTESI"
  TITOLI=$(q "SELECT coalesce(count(*),0) FROM allenamenti a, jsonb_array_elements(a.esercizi) e
              WHERE a.categoria_id=$CAT AND a.data='$DATA_USATA' AND coalesce(btrim(e->>'titolo'),'')<>''")
  ck "il giorno di prova non ha esercizi con un titolo (non e' lavoro di un mister)" "$TITOLI" "0"
fi

ripristina
echo "  ripristino eseguito dallo snapshot"
ck "la categoria $CAT e' tornata ad avere le righe di prima" \
  "$(q "SELECT count(*) FROM allenamenti WHERE categoria_id=$CAT")" "$N_RIGHE_PRIMA"
ck "l'INTERO stato degli allenamenti della categoria $CAT e' identico a prima del test" \
  "$(q "$HASH_SQL")" "$HASH_PRIMA"
if [ -n "$DATA_USATA" ]; then
  ck "il giorno di prova non lascia tracce" \
    "$(q "SELECT count(*) FROM allenamenti WHERE categoria_id=$CAT AND data='$DATA_USATA'")" "0"
fi

echo
echo "--- ripulisco i dati di prova ---"
bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
echo "  fatto"

exit $RC
