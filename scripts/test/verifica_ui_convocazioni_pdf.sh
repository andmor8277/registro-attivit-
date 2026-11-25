#!/bin/bash
# Verifica VISIVA del FOGLIO DI CONVOCAZIONE in PDF, con Chrome headless su DEV
# (http://192.168.178.133:3000/convocazioni/19).
#
# Perche' esiste: quando e' stato scritto, NESSUNO premeva mai il pulsante di export della pagina
# Convocazioni (oggi si chiama "Foglio convocazione (PDF)").
# verifica_ui_weekend.sh esporta i CALENDARI di ProgrammazionePartite, non l'elenco dei convocati: il
# documento che la societa' consegna ogni venerdi' non aveva nessuna asserzione sopra. Da oggi quello
# stesso foglio lo produce anche il modal convocazione di Tornei.vue, e un foglio di stile che vive in
# due pagine e' esattamente il punto dove i due documenti smettono di assomigliarsi.
#
# Cosa puo' beccare, che nessun altro test vede:
#   - l'export che "sembra funzionare" e sforna un documento vuoto (nessun errore in console);
#   - i cognomi che non ci sono perche' la mappa persone non li ha risolti (il documento esce con le
#     righe "- " e nessuno se ne accorge: e' la classe della colonna Mister uscita tutta "-");
#   - appuntamento e inizio gara INVERTITI, che qui si misurano sulla POSIZIONE della riga, non sulla
#     presenza del valore (altrimenti lo scambio resta verde: entrambi i valori ci sono lo stesso);
#   - la mancanza di `import 'jspdf-autotable'` nel chunk della pagina, che cade dentro il try/catch
#     lasciando solo "Errore nella generazione del PDF".
#
# NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Google Chrome e pdftotext, e
# crea gli utenti di prova con prepara_demo_tornei.sh. Si lancia a mano:
#   bash scripts/test/verifica_ui_convocazioni_pdf.sh
# I PDF scaricati e il loro testo restano in /tmp/opencode/ui-conv-pdf/pdf-text/: servono a confrontare
# il documento prima e dopo una modifica al foglio (DUMP implicito, sempre attivo).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/usr/bin/google-chrome-stable}"
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" 2>&1 | tr -d '\r'; }
CAT="${CAT:-19}"

if [ ! -x "$CHROME" ]; then echo "serve Google Chrome ($CHROME). Sovrascrivibile con CHROME=/percorso/chrome"; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "serve node"; exit 1; fi
if ! command -v pdftotext >/dev/null 2>&1; then echo "serve pdftotext (poppler-utils)"; exit 1; fi

# Due secondi che ne risparmiano mezz'ora: se il template usa un identificatore che <script setup> non
# espone, la pagina e' BIANCA e il test sotto non troverebbe niente, sembrando un difetto dell'app.
# ENTRAMBE le pagine che producono il foglio: Convocazioni.vue (il venerdi') e Tornei.vue (il modal, dove
# oggi il pulsante di export ("Foglio convocazione (PDF)") e' nuovo di zecca -- e un binding sbagliato li' e' pagina bianca)
echo "--- controllo statico del template ---"
for VUE in src/features/partite/Convocazioni.vue src/features/partite/Tornei.vue; do
  (cd "$DIR/../../frontend" && node "$DIR/controllo_template.cjs" "$VUE") || {
    echo "  $VUE: il template usa identificatori che <script setup> non espone, la pagina sarebbe bianca"
    echo "  0 passati, 1 falliti (controllo template)"
    exit 1
  }
done

# Un nome letto e mai definito dentro un modulo JS NON e' un errore di build: Vite lo lascia passare e
# diventa un ReferenceError dentro il try/catch dell'export, cioe' "Errore nella generazione del PDF" e
# nient'altro. Qui non c'e' un controllatore AST per JS (undef_check.py e' per il backend python), e la
# prova vera e' premere il pulsante: il test sotto fallisce se il documento non esce. Non si finge una
# copertura statica che non esiste

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

# Il numero di asserzioni di questo test dipende dai dati che ci sono su DEV, quindi il totale non e'
# un numero fisso da confrontare con un numero scritto a mano: cio' che non puo' mancare e' che ci sia
# ALMENO un foglio con dei convocati, e lo asserisce il file .cjs come prerequisito
# Si riparte da una cartella vuota: i PDF di un run precedente farebbero numero e lascerebbero verdi
# controlli che non hanno guardato niente di questa esecuzione
export THOF_UI_OUT="${THOF_UI_OUT:-/tmp/opencode/ui-conv-pdf}"
rm -rf "$THOF_UI_OUT"

echo
echo "--- apro la pagina con Chrome headless ---"
# L'export e' una LETTURA. Il pulsante nuovo sta DENTRO il modal, accanto a "Salva convocazione": se per
# errore chiamasse una scrittura, il risultato sarebbe un foglio salvato che nessuno ha salvato. Si misura
# prima e dopo perche' e' l'unico modo di vederselo comparire
# --- semina: un appuntamento CON i secondi, perche' su DEV quel caso non esiste -----------------
# Misurato il 25/11/2026: `convocazione_gare` ha 7 appuntamenti non vuoti su DEV e **nessuno** con i
# secondi; su PROD invece ce ne sono TRE, tutti del foglio 17 del 21/11 -- `08:00:00`, `14:15:00`,
# `17:00:00` -- e sono esattamente la cosa che il titolare ha segnalato. Li ha scritti il codice vecchio,
# che popolava l'appuntamento da `partite.ora_presentazione` (colonna `time without time zone`, quindi
# `HH:MM:SS`) e lo rimandava indietro identico nel payload di salvataggio.
# Senza semina, le asserzioni del .cjs sui secondi NON GIREREBBERO: il PDF non avrebbe secondi da
# mostrare e il giro sarebbe verde senza misurare niente. E' la stessa ragione per cui il multi-pagina
# del JPEG va seminato, non aspettato.
#
# Si semina con l'UPDATE diretto e NON passando dalla UI: la UI ormai normalizza (e' cio' che si vuole
# verificare), quindi non potrebbe riprodurre il dato sporco che il vecchio codice ha lasciato in giro.
SPORCO_FOGLIO=$(q "SELECT c.id FROM convocazioni c
                   JOIN convocazione_gare g ON g.convocazione_id = c.id
                   WHERE c.categoria_id = $CAT
                     AND coalesce(g.appuntamento, '') <> ''
                     AND c.data_fine IS NOT NULL AND c.data_fine <= CURRENT_DATE
                     AND EXISTS (SELECT 1 FROM convocazione_giocatori j WHERE j.gara_id = g.id)
                   ORDER BY c.data_inizio DESC NULLS LAST, c.id LIMIT 1")
SPORCO_GARA=""
SPORCO_ORIGINE=""
if [ -n "$SPORCO_FOGLIO" ]; then
  # La gara con il numero piu' basso: e' la prima tab, cosi' il .cjs non deve inseguire il tab attivo
  SPORCO_GARA=$(q "SELECT id FROM convocazione_gare WHERE convocazione_id = $SPORCO_FOGLIO
                   ORDER BY coalesce(numero, 999), id LIMIT 1")
fi
if [ -n "$SPORCO_GARA" ]; then
  SPORCO_ORIGINE=$(q "SELECT coalesce(appuntamento, '<NULL>') FROM convocazione_gare WHERE id = $SPORCO_GARA")
  # Dollar-quoted: l'appuntamento e' testo libero (VARCHAR(50), puo' avere un'annotazione) e un apice
  # dentro il valore originario romperebbe l'UPDATE del ripristino, nel momento in cui serve di piu'
  q "UPDATE convocazione_gare SET appuntamento = \$\$14:15:00\$\$ WHERE id = $SPORCO_GARA;" >/dev/null
  APPOSTA=$(q "SELECT appuntamento FROM convocazione_gare WHERE id = $SPORCO_GARA")
  if [ "$APPOSTA" != "14:15:00" ]; then
    echo "  FAIL la semina non e' partita:gara $SPORCO_GARA dice '$APPOSTA', atteso '14:15:00'"
    SPORCO_GARA=""
  fi
fi
if [ -z "$SPORCO_GARA" ]; then
  echo "  NOTA ROSSA: nessun foglio della categoria $CAT, selezionabile dallo storico, ha un appuntamento"
  echo "  da sporcare: le asserzioni sui secondi non potranno misurare niente. Il .cjs lo dira' come FAIL."
fi
export THOF_UI_SPORCO_GARA="$SPORCO_GARA"
export THOF_UI_SPORCO_FOGLIO="$SPORCO_FOGLIO"
export THOF_UI_SPORCO_VALORE="14:15:00"

ripristina_sporco() {
  [ -n "$SPORCO_GARA" ] || return 0
  local ad
  ad=$(q "SELECT coalesce(appuntamento, '<NULL>') FROM convocazione_gare WHERE id = $SPORCO_GARA")
  # Se a questo punto il valore NON e' quello seminato, il .cjs lo ha toccato: e' una scrittura che
  # nessuno ha chiesto, e va detta prima di sovrascriverla
  if [ "$ad" != "14:15:00" ]; then
    echo "  FAIL a ripulitura la gara $SPORCO_GARA dice '$ad', non il valore seminato '14:15:00':"
    echo "       qualcosa ha scritto su quel campo durante il test"
  fi
  if [ "$SPORCO_ORIGINE" = "<NULL>" ]; then
    q "UPDATE convocazione_gare SET appuntamento = NULL WHERE id = $SPORCO_GARA;" >/dev/null
  else
    q "UPDATE convocazione_gare SET appuntamento = \$\$${SPORCO_ORIGINE}\$\$ WHERE id = $SPORCO_GARA;" >/dev/null
  fi
  ad=$(q "SELECT coalesce(appuntamento, '<NULL>') FROM convocazione_gare WHERE id = $SPORCO_GARA")
  # "ho eseguito l'UPDATE" non e' il ripristino: lo e' il valore che c'e' dopo
  if [ "$ad" = "$SPORCO_ORIGINE" ]; then
    echo "  ok   ripulitura: gara $SPORCO_GARA di nuovo a '$ad'"
  else
    echo "  FAIL ripristino non riuscito: gara $SPORCO_GARA dice '$ad', doveva essere '$SPORCO_ORIGINE'"
    RC=${RC:-1}
  fi
}
# Nel trap, non solo in fondo: un Chrome che esplode a meta' run non deve lasciare un appuntamento
# inventato sul foglio di venerdi' di una squadra vera
trap 'ripristina_sporco' EXIT

FOGLI_PRIMA=$(q "SELECT count(*) FROM convocazioni")
GIOC_PRIMA=$(q "SELECT count(*) FROM convocazione_giocatori")
node "$DIR/ui_convocazioni_pdf.cjs" "$PW" "demo_tornei_mister1" "$CAT"
RC=$?

# La verita' dietro i verdi a schermo: il browser dice quali cognomi ha visto nel PDF, il DB dice se
# QUEI ragazzi sono davvero convocati su QUEL foglio. Se il documento mostrasse ragazzi di un altro
# foglio della stessa categoria (un errore di stato della pagina), qui si vede
echo
echo "--- cosa dice il database di cio' che ho visto a schermo ---"
ck() { if [ -z "$2" ] && [ -z "$3" ]; then echo "  FAIL $1 -> entrambi vuoti: non ha misurato nulla"; RC=1; return; fi
       if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 -> '$2' (atteso '$3')"; RC=1; fi; }
ckmin() { if [ -n "$2" ] && [ "$2" -ge "$3" ] 2>/dev/null; then echo "  ok   $1 ($2 >= $3)"; else echo "  FAIL $1 -> '$2' (atteso >= $3)"; RC=1; fi; }
ckmin "la categoria ha fogli di convocazione" "$(q "SELECT count(*) FROM convocazioni WHERE categoria_id=$CAT")" 1
ckmin "almeno un foglio ha convocati dentro (senza, le asserzioni sul PDF non misurerebbero niente)" \
  "$(q "SELECT count(*) FROM convocazione_giocatori j JOIN convocazione_gare g ON g.id=j.gara_id
        JOIN convocazioni c ON c.id=g.convocazione_id WHERE c.categoria_id=$CAT")" 1
# Nessuno dei PDF scaricati deve essere un file vuoto o corrotto: un jsPDF che non ha scritto pagine
# esiste, ha l'intestazione PDF e pesa poche centinaia di byte
N_PDF=$(ls -1 "$THOF_UI_OUT"/pdfs/*.pdf 2>/dev/null | wc -l | tr -d ' ')
ckmin "i PDF scaricati sono piu' di zero" "$N_PDF" 1
for f in "$THOF_UI_OUT"/pdfs/*.pdf; do
  [ -e "$f" ] || continue
  ckmin "$(basename "$f"): peso oltre la soglia di un documento reale" "$(/usr/bin/stat -c%s "$f")" 2000
  ck "$(basename "$f"): e' un PDF vero (comincia per %PDF)" "$(head -c 4 "$f")" "%PDF"
done

# Il pulsante di export del modal non deve scrivere: e' una lettura, e sta a un dito da "Salva convocazione"
ck "l'export non ha creato ne' cancellato fogli di convocazione" \
  "$(q "SELECT count(*) FROM convocazioni")" "$FOGLI_PRIMA"
ck "l'export non ha aggiunto ne' tolto convocati" \
  "$(q "SELECT count(*) FROM convocazione_giocatori")" "$GIOC_PRIMA"

echo
echo "--- ripulisco i dati di prova ---"
bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
echo "  fatto"

exit $RC
