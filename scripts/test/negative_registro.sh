#!/bin/bash
# NEGATIVE TEST della verifica visiva del Registro: rompe UNA cosa alla volta, come la farebbe un
# programmatore distratto, e asserisce che scripts/test/verifica_ui_registro.sh se ne accorga.
#
# Perche' esiste. Un test UI verde da solo non dice niente: questo file ha girato verde anche mentre
# il pulsante "Mese" era fuori dalla barra a 390px e il click non arrivava a segno (lo ha trovato il
# test stesso, ma solo perche' le asserzioni sotto dipendevano da quel click). L'unico modo di sapere
# che un'asserzione guarda la cosa giusta e' toglierla di mezzo e vedere il rosso.
#
# Due controlli per giro, non uno:
#   - ROSSI_ATTESI: almeno queste asserzioni devono diventare rosse;
#   - VERDI_DA_CONSERVARE: queste devono RESTARE verdi E DEVONO ESSERE STATE ESEGUITE. La seconda parte
#     e' la trappola: se il test si interrompe prima, le asserzioni "da conservare" sono ASSENTI, e
#     "non sono fra le rosse" sarebbe verde senza aver misurato niente.
# Se una mutazione non produce nessun rosso, il giro e' FALLITO: una mutazione che non cambia output
# non ha testato niente (e non e' teoria: e' gia' successo in questo progetto con una mutazione mai
# partita, confermata leggendo una stringa nel file invece di vedere il rosso).
#
# Ogni giro RIBUILDA l'immagine frontend su DEV: Registro.vue e' un SFC compilato, quindi mutare il
# file sul disco senza rebuild non porta niente davanti al browser (lezione gia' pagata con la lavagna).
#
# Si lancia a mano (vuole Chrome e ~2 minuti di build per mutazione):
#   bash scripts/test/negative_registro.sh                 # tutte
#   bash scripts/test/negative_registro.sh foglio-segue-lo-schermo
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
REMOTE="root@192.168.178.133"
REMOTE_PATH="/opt/registro_presenze"
PY="$DIR/muta_registro.py"
LAVORO=/tmp/opencode/negative-registro
mkdir -p "$LAVORO"

if [ ! -x "${CHROME:-/usr/bin/google-chrome-stable}" ]; then echo "serve Google Chrome"; exit 1; fi

builda() {
  # stessi exclude di deploy_dev.sh: un frontend/.env o il keystore NON devono finire su DEV ne'
  # dentro l'immagine
  tar -cz --exclude=node_modules --exclude=dist --exclude=android --exclude='.env*' --exclude='.local' \
      --exclude='*.keystore' --exclude='keystore.properties' --exclude='client_secret_*.json' \
      -C "$ROOT" frontend | $SSH "tar -xzf - -C $REMOTE_PATH"
  $SSH "cd $REMOTE_PATH && docker compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache frontend >/dev/null 2>&1 \
        && docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d frontend >/dev/null 2>&1"
  sleep 5
}

# ── cosa deve rompersi, e cosa no, per ogni mutazione ───────────────────────────────
declare -A ROSSI VERDI
ROSSI[settimana-a-mese]="le colonne della settimana sono MENO di 7|la tabella STA nella larghezza del telefono"
VERDI[settimana-a-mese]="nessun overlay \"ruota il dispositivo\" sul Registro|il toggle ha i due modi (Settimana / Mese)|IL FOGLIO DI STAMPA ha i giorni di allenamento del MESE, non della settimana (Postgres)"
ROSSI[foglio-segue-lo-schermo]="IL FOGLIO DI STAMPA ha i giorni di allenamento del MESE, non della settimana (Postgres)|il foglio di stampa ha PIU' colonne dello schermo"
VERDI[foglio-segue-lo-schermo]="le colonne della settimana sono MENO di 7|la cella del MESE ACCANTO mostra il codice seminato|nessun errore in console|il modal della cella dice la data VERA del mese accanto"
ROSSI[celle-per-numero]="la cella del MESE ACCANTO mostra il codice seminato|la riga scritta a schermo esiste nel DB, su QUELLA data|nessuna riga sul giorno OMONIMO"
VERDI[celle-per-numero]="la tabella STA nella larghezza del telefono|IL FOGLIO DI STAMPA ha i giorni di allenamento del MESE, non della settimana (Postgres)|il TOT di riga conta il MESE e non la settimana"
ROSSI[totali-fusi]="il TOT di riga conta il MESE e non la settimana|il TOT del foglio e' il mese"
VERDI[totali-fusi]="la cella del MESE ACCANTO mostra il codice seminato|le colonne della settimana sono MENO di 7"
ROSSI[default-mese]="il modo di DEFAULT e' Settimana|la tabella STA nella larghezza del telefono"
VERDI[default-mese]="nessun overlay \"ruota il dispositivo\" sul Registro|il toggle adesso segna Mese"

MUTAZIONI=("$@")
if [ "${#MUTAZIONI[@]}" = "0" ]; then
  mapfile -t MUTAZIONI < <(python3 "$PY" lista)
fi

echo "--- snapshot PRISTINO (da zero, sempre) ---"
python3 "$PY" prepara || exit 1
PRISTINO=$(python3 "$PY" hash)

ROTTI=0
ripulisci() {
  python3 "$PY" ripristina >/dev/null 2>&1
  builda >/dev/null 2>&1
  VERIFICATO=$(python3 "$PY" hash)
  if [ "$VERIFICATO" != "$PRISTINO" ]; then
    echo "  !! ATTENZIONE: i file NON sono tornati pristini ($VERIFICATO != $PRISTINO)"
    ROTTI=1
  fi
}
trap 'if [ "${FINITO:-0}" != "1" ]; then echo "  !! ripristino attivato dalla trap"; ripulisci; fi' EXIT

for M in "${MUTAZIONI[@]}"; do
  echo
  echo "════════════════════════════════════════════════════════════════════"
  echo "  MUTAZIONE: $M"
  echo "════════════════════════════════════════════════════════════════════"
  if ! python3 "$PY" applica "$M"; then
    echo "  FAIL la mutazione non e' partita: questo giro NON ha testato niente"
    ROTTI=1
    python3 "$PY" ripristina >/dev/null 2>&1
    continue
  fi
  if [ "$(python3 "$PY" hash)" = "$PRISTINO" ]; then
    echo "  FAIL l'hash non e' cambiato: la mutazione non ha toccato i file"
    ROTTI=1
    continue
  fi
  echo "  rebuild frontend su DEV..."
  builda
  echo "  lancio la verifica UI..."
  LOG="$LAVORO/$M.log"
  bash "$DIR/verifica_ui_registro.sh" >"$LOG" 2>&1
  grep -E '^  FAIL' "$LOG" > "$LAVORO/$M.rossi" 2>/dev/null
  grep -E '^  ok  ' "$LOG" > "$LAVORO/$M.verdi" 2>/dev/null
  N_ROSSI=$(wc -l < "$LAVORO/$M.rossi")
  echo "  rossi prodotti: $N_ROSSI"
  sed 's/^/      /' "$LAVORO/$M.rossi" | head -20

  if [ "$N_ROSSI" = "0" ]; then
    echo "  FAIL nessuna asserzione e' diventata rossa: la mutazione non ha cambiato output, non ha testato niente"
    ROTTI=1
  fi

  IFS='|' read -r -a ATTESI <<< "${ROSSI[$M]}"
  for A in "${ATTESI[@]}"; do
    if grep -qF "$A" "$LAVORO/$M.rossi"; then
      echo "  ok   diventa rossa: $A"
    else
      echo "  FAIL NON diventa rossa: $A"
      ROTTI=1
    fi
  done

  IFS='|' read -r -a KEEPGREEN <<< "${VERDI[$M]}"
  for A in "${KEEPGREEN[@]}"; do
    if grep -qF "$A" "$LAVORO/$M.rossi"; then
      echo "  FAIL diventa rossa anche questa (non discriminatoria): $A"
      ROTTI=1
    elif grep -qF "$A" "$LAVORO/$M.verdi"; then
      echo "  ok   resta verde ed era stata eseguita: $A"
    else
      # assente sia dai rossi sia dai verdi = il test non ci e' mai arrivato: "non e' fra le rosse"
      # sarebbe verde senza aver misurato niente
      echo "  FAIL asserzione MAI ESEGUITA (non e' ne' fra le rosse ne' fra le verdi): $A"
      ROTTI=1
    fi
  done

  python3 "$PY" ripristina >/dev/null 2>&1
done

echo
echo "--- ripristino finale e rebuild del codice pristino ---"
ripulisci
if [ "$(python3 "$PY" hash)" = "$PRISTINO" ]; then
  echo "  ok   Registro.vue e RegistroPrintSheet.vue sono pristini ($PRISTINO)"
else
  ROTTI=1
fi

FINITO=1
echo
if [ "$ROTTI" = "0" ]; then
  echo "  negative test: il test sa fallire su tutte le ${#MUTAZIONI[@]} mutazioni"
else
  echo "  negative test: $ROTTI problemi"
fi
exit $ROTTI
