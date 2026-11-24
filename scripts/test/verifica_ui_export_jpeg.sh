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
  RIF=$(grep -c 'jpegDaPdf\|saveOrShareJpeg\|exportJpeg\|Esporta JPEG' "$FRONT/$VUE")
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

export THOF_UI_OUT="${THOF_UI_OUT:-/tmp/opencode/ui-export-jpeg}"
rm -rf "$THOF_UI_OUT"

# L'export e' una LETTURA. I pulsanti JPEG stanno accanto a "Salva convocazione" e ad "Aggiungi gara":
# se per errore chiamassero una scrittura, il danno sarebbe un foglio o una gara che nessuno ha creato
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
