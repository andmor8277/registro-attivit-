#!/bin/bash
# Verifica VISIVA dell'EXPORT JPEG su DEV con Chrome headless: per ogni documento esporta IL PDF e
# LA JPEG e asserisce che la JPEG sia davvero l'immagine di quel PDF (stesse pagine, stessa geometria,
# inchiostro su ogni pagina, sfondo bianco).
#
# Perche' esiste: la consegna e' "come e' previsto che esca il PDF, deve uscire il JPEG". Il PDF e la
# JPEG possono essere entrambi "verdi" presa ciascuno da sola, e divergere comunque: manca una pagina
# nell'immagine, lo sfondo esce nero perche' il JPEG non ha alpha, o i font -- che i nostri PDF NON
# incorporano -- vengono rasterizzati senza le metriche giuste. Nessuna di queste cose si vede dal
# build, e nessuna la vede il test del solo PDF.
#
# Copre i TRE documenti scelti dal titolare (foglio convocazioni, calendario tornei, programmazione
# weekend) su quattro pulsanti: weekend, genitori, tutti i tornei, foglio di convocazione.
#
# NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Google Chrome e crea i dati
# di prova. Si lancia a mano:
#   bash scripts/test/verifica_ui_export_jpeg.sh
# Gli scaricati restano in /tmp/opencode/ui-export-jpeg/{pdfs,jpegs}/: servono a guardare con i propri
# occhi l'immagine che il test ha misurato.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/usr/bin/google-chrome-stable}"
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" 2>&1 | tr -d '\r'; }
CAT="${CAT:-19}"
FRONT="$DIR/../../frontend"

if [ ! -x "$CHROME" ]; then echo "serve Google Chrome ($CHROME). Sovrascrivibile con CHROME=/percorso/chrome"; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "serve node"; exit 1; fi

RC=0
ck() { if [ -z "$2" ] && [ -z "$3" ]; then echo "  FAIL $1 -> entrambi vuoti: non ha misurato nulla"; RC=1; return; fi
       if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 -> '$2' (atteso '$3')"; RC=1; fi; }
ckmin() { if [ -n "$2" ] && [ "$2" -ge "$3" ] 2>/dev/null; then echo "  ok   $1 ($2 >= $3)"; else echo "  FAIL $1 -> '$2' (atteso >= $3)"; RC=1; fi; }

# ---------------------------------------------------------------- guard-rail statici
# Due secondi che ne risparmiano mezz'ora: un identificatore del template che <script setup> non
# espone e' PAGINA BIANCA, e il test sotto non troverebbe nessun pulsante -- sembrando un difetto
# dell'export quando e' il binding
echo "--- controllo statico dei template toccati ---"
for VUE in src/features/partite/Convocazioni.vue src/features/partite/Tornei.vue src/features/partite/ProgrammazionePartite.vue; do
  (cd "$FRONT" && node "$DIR/controllo_template.cjs" "$VUE") || {
    echo "  $VUE: il template usa identificatori che <script setup> non espone, la pagina sarebbe bianca"
    echo "  0 passati, 1 falliti (controllo template)"
    exit 1
  }
done

# I dati sensibili restano fuori dalla JPEG per decisione del titolare: il roster di Liste Tornei ha
# il codice fiscale e il certificato medico ha dati sanitari, entrambi NON vanno in un'immagine che
# finisce in chat. E' un'asserzione SUL CODICE, quindi cade se qualcuno li aggiunge domani senza
# che la decisione la prenda il titolare
echo
echo "--- i documenti con dati sensibili non hanno l'export JPEG ---"
for VUE in src/features/partite/ListeTornei.vue src/features/infermeria/CertificatoMedico.vue; do
  # Un file che non c'e' NON e' un "zero riferimenti": e' il guard-rail che non misura niente, e
  # deve diventare rosso lui, non verde perche' grep non ha trovato nulla in un file inesistente
  if [ ! -f "$FRONT/$VUE" ]; then
    echo "  FAIL $VUE non esiste: il guard-rail PII non puo' misurare niente"; RC=1; continue
  fi
  # Marker di CODICE, non di etichetta: fino al 24/11/2026 fra questi c'era anche la stringa
  # "Esporta JPEG", che pero' e' testo a schermo -- e il giorno che le etichette sono state allineate
  # alla convenzione "(PDF)"/"(immagine)" quel marker sarebbe diventato invisibile a un pulsante JPEG
  # aggiunto davvero. Un guard-rail sulla PII che smette di vedere il difetto perche' e' cambiato un
  # testo e' peggio di non averlo. Si cercano i ganci del codice E, come rete, il suffisso che la
  # convenzione impone a un pulsante immagine: le due cose insieme non dipendono da come e' scritto.
  RIF=$(grep -c "jpegDaPdf\|saveOrShareJpeg\|formato: .jpeg\|esportaJPEG\|(immagine)" "$FRONT/$VUE")
  RIF=${RIF:-0}
  ck "$VUE: nessun riferimento all'export JPEG (roster con CF e dati sanitari non escono in chat)" "$RIF" "0"
done

# Il helper deve esistere e deve essere l'UNICO punto di rasterizzazione: due implementazioni della
# stessa rasterizzazione sono due documenti che il giorno dopo non si assomigliano piu'
echo
echo "--- la rasterizzazione ha una sola casa ---"
ck "jpegDaPdf.js esiste" "$([ -f "$FRONT/src/core/utils/jpegDaPdf.js" ] && echo si || echo no)" "si"
N_CASA=$(grep -rl 'getDocument\|GlobalWorkerOptions' "$FRONT/src" 2>/dev/null | wc -l | tr -d ' ')
ck "pdf.js e' usato solo in core/utils/jpegDaPdf.js" "$N_CASA" "1"
# I font standard vanno nel bundle: i nostri PDF non incorporano i font, e in APK un CDN non e'
# un'opzione. Se prebuild non li copia, il testo rasterizzato esce storto
grep -q 'prebuild.*copy_pdfjs_assets' "$FRONT/package.json" \
  && echo "  ok   gli asset di pdf.js (font + worker) sono agganciati a prebuild" \
  || { echo "  FAIL gli asset di pdf.js NON sono agganciati a prebuild: il testo rasterizzato uscirebbe storto"; RC=1; }
# Il worker deve arrivare come .js: con nosniff attivo, un modulo servito come octet-stream viene
# rifiutato da Chrome e l'export non partirebbe sul web (sull'APK no, e la differenza e' il difetto)
[ -f "$FRONT/public/pdfjs/pdf.worker.min.js" ] \
  && echo "  ok   il worker di pdf.js e' nel bundle come .js (MIME giusto su nginx e su Capacitor)" \
  || { echo "  FAIL il worker di pdf.js non e' nel bundle come .js"; RC=1; }

# ---------------------------------------------------------------- dati di prova
echo
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

export THOF_UI_BASE="${THOF_UI_BASE:-http://192.168.178.133:3000}"
export THOF_UI_OUT="${THOF_UI_OUT:-/tmp/opencode/ui-export-jpeg}"
rm -rf "$THOF_UI_OUT"

# ---------------------------------------------------------------- semina multi-pagina
# `singlePageMax` in pdfConvocazione.js tiene il foglio su UNA pagina finche' le gare sono <=4: e'
# una forzatura voluta, e infatti su DEV e PROD non esiste nessun foglio a due pagine (max reale:
# 4 gare con 14 convocati). Ma e' proprio li' che la consegna "quello che c'e' nel PDF deve esserci
# nella JPEG" ha valore, e il test da solo non lo puo' percorrere. Quindi si semina un weekend con
# 5 gare: a 5 il layout degrada a 2 colonne per riga e la seconda pagina nasce davvero.
# Le partite si creano PRIMA del foglio perche' `crea()` di convocazioni.py, se non le trova,
# INSERTISCE in `partite` e fa upsert su `campi_sportivi`: un foglio di prova che passasse di li'
# non darebbe un errore, darebbe una partita di campionato inventata
API="$THOF_UI_BASE/api"
TOK=$(curl -s --max-time 25 -X POST "$API/auth/token" --data-urlencode "username=demo_tornei" \
        --data-urlencode "password=$PW" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
RAGAZZI=$(q "SELECT string_agg(id::text, ',') FROM (SELECT id FROM persone WHERE categoria_id=$CAT
              AND cognome IS NOT NULL ORDER BY id LIMIT 12) t" | tr -d ' ')
MULTI_OK=0
MULTI_WID=""
MULTI_CID=""
if [ -n "$TOK" ] && [ -n "$RAGAZZI" ]; then
  echo
  echo "--- semino un weekend a 5 gare per forzare il foglio su DUE pagine ---"
  # Lo slash FINALE non e' ornamentale: le rotte sono @router.post("/") sotto prefix="/weekend",
  # quindi senza slash FastAPI risponde 307 e curl senza -L riceve un corpo VUOTO. Sarebbe sembrato
  # "il weekend non si crea" quando invece si era solo persa la risposta
  R_W=$(curl -s --max-time 25 -X POST "$API/weekend/" -H "Authorization: Bearer $TOK" \
    -H 'Content-Type: application/json' \
    -d '{"nome":"__demo_multi__","data_inizio":"2026-09-05","data_fine":"2026-09-06"}')
  MULTI_WID=$(printf '%s' "$R_W" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)
  if [ -z "$MULTI_WID" ]; then
    echo "  POST /weekend/ non ha restituito un id. Risposta: $(printf '%s' "$R_W" | head -c 200)"
  fi
  if [ -n "$MULTI_WID" ]; then
    for i in 1 2 3 4 5; do
      curl -s --max-time 25 -X POST "$API/partite/" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
        -d "{\"categoria_id\":$CAT,\"weekend_id\":$MULTI_WID,\"data_partite\":\"2026-09-05\",\"ora\":\"09:0${i}\",\"avversario\":\"__Demo Multi ${i}__\",\"campo\":\"Campo Demo\",\"casa_fuori\":\"casa\"}" \
        >/dev/null
    done
    GARE_JSON=$(printf '%s' "$RAGAZZI" | python3 -c "
import sys, json
ids = [int(x) for x in sys.stdin.read().strip().split(',') if x.strip()]
gare = [{'numero': i, 'data': '2026-09-05', 'gara': f'__Demo Multi {i}__',
         'appuntamento': f'08:3{i}', 'inizio_gara': f'10:0{i}',
         'giocatori': [{'persona_id': p, 'posizione': k + 1} for k, p in enumerate(ids)]}
        for i in range(1, 6)]
print(json.dumps(gare, ensure_ascii=False))
")
    R_C=$(curl -s --max-time 30 -X POST "$API/convocazioni/" -H "Authorization: Bearer $TOK" \
      -H 'Content-Type: application/json' \
      -d "{\"categoria_id\":$CAT,\"weekend_id\":$MULTI_WID,\"data_inizio\":\"2026-09-05\",\"data_fine\":\"2026-09-06\",\"note\":\"foglio di prova a 5 gare\",\"gare\":$GARE_JSON}")
    MULTI_CID=$(printf '%s' "$R_C" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)
    if [ -z "$MULTI_CID" ]; then
      echo "  POST /convocazioni/ non ha restituito un id. Risposta: $(printf '%s' "$R_C" | head -c 300)"
    fi
    # Il conteggio si fa solo con un id numerico in mano: passare una stringa vuota a psql produce un
    # errore che finisce dentro ckmin, che lo stampa come valore e non come fallimento -- verde per il
    # motivo sbagliato
    if [ -n "$MULTI_CID" ]; then
      N_GARE=$(q "SELECT count(*) FROM convocazione_gare WHERE convocazione_id=$MULTI_CID" | tr -dc '0-9')
      ckmin "il foglio di prova ha 5 gare (sotto le 4, singlePageMax lo terrebbe su una pagina e il multi-pagina non verrebbe percorso)" "${N_GARE:-0}" 5
      if [ "${N_GARE:-0}" -ge 5 ]; then MULTI_OK=1; THOF_UI_FOGLIO_DATA="05/09/26"; export THOF_UI_FOGLIO_DATA; fi
    else
      ck "il foglio di prova a 5 gare e' stato creato" "no" "si"
    fi
  else
    echo "  il weekend di prova non e' stato creato: il multi-pagina non verra' percorso"
  fi
else
  echo "  token o ragazzi mancanti: il multi-pagina non verra' percorso (il test lo dichiarera')"
fi

# L'export e' una LETTURA. I pulsanti JPEG stanno accanto a "Salva convocazione" e ad "Aggiungi gara":
# se per errore chiamassero una scrittura, il danno sarebbe un foglio o una gara che nessuno ha creato.
# Il conteggio si prende DOPO la semina: la semina scrive, l'export no, e le due cose non vanno confuse
FOGLI_PRIMA=$(q "SELECT count(*) FROM convocazioni")
GIOC_PRIMA=$(q "SELECT count(*) FROM convocazione_giocatori")
GARE_PRIMA=$(q "SELECT count(*) FROM tornei_gare")
PARTITE_PRIMA=$(q "SELECT count(*) FROM partite")

echo
echo "--- apro le pagine con Chrome headless ---"
node "$DIR/ui_export_jpeg.cjs" "$PW" "demo_tornei_mister1" "$CAT"
RC_CJS=$?
[ "$RC_CJS" -ne 0 ] && RC=1

echo
echo "--- cosa dice il database di cio' che ho premuto ---"
ck "l'export JPEG non ha creato ne' cancellato fogli di convocazione" "$(q "SELECT count(*) FROM convocazioni")" "$FOGLI_PRIMA"
ck "l'export JPEG non ha aggiunto ne' tolto convocati" "$(q "SELECT count(*) FROM convocazione_giocatori")" "$GIOC_PRIMA"
ck "l'export JPEG non ha toccato il calendario delle gare di torneo" "$(q "SELECT count(*) FROM tornei_gare")" "$GARE_PRIMA"
ck "l'export JPEG non ha inventato partite di campionato" "$(q "SELECT count(*) FROM partite")" "$PARTITE_PRIMA"

# Gli scaricati devono essere li', altrimenti il .cjs ha "misurato" un file che non c'era
N_PDF=$(ls -1 "$THOF_UI_OUT"/pdfs/*.pdf 2>/dev/null | wc -l | tr -d ' ')
N_JPG=$(ls -1 "$THOF_UI_OUT"/jpegs/*.jpg 2>/dev/null | wc -l | tr -d ' ')
ckmin "i PDF scaricati sono piu' di zero" "$N_PDF" 1
ckmin "le JPEG scaricate sono piu' di zero" "$N_JPG" 1
# Un PDF e una JPEG per ogni documento confrontato: se il .cjs si e' fermato a meta', qui si vede
ck "le JPEG scaricate sono quante i PDF (ogni PDF ha il suo gemello)" "$N_JPG" "$N_PDF"
for f in "$THOF_UI_OUT"/jpegs/*.jpg; do
  [ -e "$f" ] || continue
  ckmin "$(basename "$f"): peso oltre la soglia di un'immagine reale" "$(/usr/bin/stat -c%s "$f")" 2000
  ck "$(basename "$f"): comincia con i magic bytes di una JPEG" "$(od -An -tx1 -N3 "$f" | tr -s ' ' | sed 's/^ //')" "ff d8 ff"
done

echo
echo "--- ripulisco i dati di prova ---"
# I figli prima dei padri: convocazione_giocatori -> convocazione_gare -> convocazioni. Cancellare
# nell'ordine sbagliato lascia orfani in silenzio, e il run dopo trova un foglio che non si spiega
if [ -n "$MULTI_CID" ]; then
  q "DELETE FROM convocazione_giocatori WHERE gara_id IN (SELECT id FROM convocazione_gare WHERE convocazione_id=$MULTI_CID);
     DELETE FROM convocazione_gare WHERE convocazione_id=$MULTI_CID;
     DELETE FROM convocazioni WHERE id=$MULTI_CID;" >/dev/null
fi
if [ -n "$MULTI_WID" ]; then
  q "DELETE FROM partite WHERE weekend_id=$MULTI_WID;
     DELETE FROM weekend WHERE id=$MULTI_WID;" >/dev/null
fi
RESIDUI=$(q "SELECT count(*) FROM weekend WHERE nome='__demo_multi__'")
ck "nessun residuo del weekend a 5 gare" "$RESIDUI" "0"
bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
echo "  fatto"

# Il riepilogo vero e' quello stampato dal .cjs (le asserzioni sono sue). Qui sotto c'e' solo il
# verdetto del wrapper: i controlli sul database e sui file scaricati
if [ "$RC" -eq 0 ]; then
  echo
  echo "  wrapper: verde ($N_PDF PDF e $N_JPG JPEG confrontati, database invariato)"
else
  echo
  echo "  wrapper: ROSSO (vedi i FAIL sopra)"
fi
exit $RC
