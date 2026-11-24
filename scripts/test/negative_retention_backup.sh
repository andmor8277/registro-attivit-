#!/bin/bash
# Negative test di test_retention_backup.sh: prova che il guard-rail della retention SAPPIA FALLIRE.
#
# Perche' esiste. Il cron di PROD ha cancellato se stesso per ~60 giorni dichiarando "completato con
# successo". Un test verde che non si e' mai visto rosso davanti a QUESTO difetto non e' una difesa:
# e' la stessa fiducia che ha retto per due mesi. Ogni giro qui rimette dentro il selettore uno dei
# difetti reali o una delle guardie tolta, e il test deve accorgersene.
#
# Perche' ogni giro ASSERISCE che la mutazione e' partita. E' la lezione gia' pagata tre volte in
# questo progetto (le etichette, le migrazioni, i certificati): una mutazione che non sostituisce
# niente produce un verde che non ha misurato niente, ed e' il verde piu' pericoloso che c'e' perche'
# assomiglia a una prova.
#
# Non e' nella suite: run_suite_dev.sh scopre solo test_*.sh, e questo stampa rossi di proposito.
# Si lancia a mano, ~10 secondi (non tocca ne' DEV ne' PROD ne' l'API: legge fixture).
set -u
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR" || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL non riesco a entrare nella root"; exit 1; }

LIB=scripts/lib/selezione_retention.py
T=scripts/test/test_retention_backup.sh
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for f in "$LIB" "$T"; do
  [ -f "$f" ] || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL manca $f"; exit 1; }
  cp "$f" "$TMP/$(basename "$f").pristino"
done
sha() { sha256sum "$1" | cut -c1-16; }
PRISTINO=$(for f in "$LIB" "$T"; do printf '%s ' "$(sha "$f")"; done)

pass=0; fail=0
ripristina() {
  local f
  # SOLO dalle copie in $TMP: mai `git checkout`, che qui dentro ha gia' cancellato lavoro non
  # committato in un altro giro di test di questo progetto
  for f in "$LIB" "$T"; do cp "$TMP/$(basename "$f").pristino" "$f"; done
  local adesso; adesso=$(for f in "$LIB" "$T"; do printf '%s ' "$(sha "$f")"; done)
  if [ "$adesso" != "$PRISTINO" ]; then
    echo "  FAIL il ripristino non ha riportato i file pristini: i giri successivi non varrebbero"
    fail=$((fail+1)); return 1
  fi
  return 0
}

giro() { # giro <descrizione> <file> <comando-di-mutazione> <rossi-attesi>
  local cosa="$1" file="$2" muta="$3" attesi="$4"
  echo
  echo "── $cosa"
  eval "$muta"
  if diff -q "$file" "$TMP/$(basename "$file").pristino" >/dev/null; then
    echo "  FAIL MUTAZIONE NON PARTITA su $file: identica al pristino, il verdetto dopo non prova niente"
    fail=$((fail+1)); ripristina; return
  fi
  local out n rc
  out=$(bash "$T" 2>&1); rc=$?
  n=$(printf '%s\n' "$out" | grep -c '^  FAIL')
  printf '%s\n' "$out" | grep '^  FAIL' | sed 's/^/       /' | head -6
  if [ "$rc" = "0" ] || [ "$n" = "0" ]; then
    echo "  FAIL il test non si e' accorto di \"$cosa\": dice verde su un difetto che deve vedere"
    fail=$((fail+1))
  elif [ "$n" != "$attesi" ]; then
    echo "  FAIL rossi $n, attesi $attesi per \"$cosa\" (troppe o troppo poche asserzioni colpite = il"
    echo "       test non e' discriminatorio: non sai quale regola ha visto cosa)"
    fail=$((fail+1))
  else
    echo "  ok   $n rossi come atteso"
    pass=$((pass+1))
  fi
  ripristina
}

echo "=== il guard-rail della retention sa fallire? ==="
if bash "$T" >/dev/null 2>&1; then echo "  ok   verde a riposo"; pass=$((pass+1)); else
  echo "  FAIL non e' verde a riposo: i giri sotto non misurerebbero niente"; fail=$((fail+1)); fi

# 1. IL difetto reale, quello che ha cancellato 60 giorni di backup: il campo dell'eta' torna
#    created_at, che su quelle release e' di settembre.
#    Rossi attesi 11: e' il perno, quindi tutto il blocco "caso reale" + tutto il blocco "fa ancora il
#    suo lavoro" + l'asserzione statica sul campo cadono insieme. E' voluto: qui l'indiscriminazione
#    sarebbe il difetto, non la virtu' -- un campo sbagliato deve essere rumoroso.
giro "il campo dell'eta' torna created_at (il difetto che ha mangiato 60 giorni di backup)" \
     "$LIB" "sed -i \"s/^CAMPO_ETA = 'published_at'/CAMPO_ETA = 'created_at'/\" $LIB" 11

# 2. Guardia G2 tolta: una release senza published_at torna a essere "piu' vecchia di tutte"
#    ('' < '2026-...' e' VERO) e viene cancellata. E' il modo in cui l'API che risponde male
#    cancella tutto. Rossi attesi 2: il selettore va in eccezione su fromisoformat(None), quindi
#    cadono "gira davvero" (rc) e "lo dice" (il conteggio dei conservati). Il conteggio delle righe
#    RESTA verde perche' un crash non stampa niente -- ed e' il motivo per cui quell'asserzione da
#    sola non bastava e la riga sul rc e' obbligatoria.
giro "la guardia sul published_at assente e' tolta (l'API che risponde male cancella tutto)" \
     "$LIB" "sed -i 's/if not data or not isinstance(data, str):/if False:/' $LIB" 2

# 3. Guardia G4 tolta: la retention puo' di nuovo azzerare tutta la storia in un giro. Rossi attesi 3:
#    rc, stdout vuoto, messaggio di rifiuto -- le tre facce dello stesso "rifiuta".
giro "la guardia 'non cancellare tutto' e' tolta" \
     "$LIB" "sed -i 's/if totali and not conservate:/if False:/' $LIB" 3

# 4. Guardia G3 tolta: il --keep non conta piu', il backup appena creato e' di nuovo cancellabile.
#    Rossi attesi 3, le tre asserzioni del blocco --keep. Alla prima esecuzione questo giro era
#    VERDE: la fixture aveva una release sola, quindi senza --keep scattava G4 e l'elenco restava
#    vuoto -- "non ha cancellato" perche' ha rifiutato tutto. Ora le vecchie sono due e il --keep
#    deve salvare quella giusta, non "una qualsiasi".
giro "il --keep non viene piu' rispettato (il backup di stanotte e' di nuovo cancellabile)" \
     "$LIB" "sed -i 's/if tieni is not None and str(rid) == tieni:/if False:/' $LIB" 3

# 5. Il conteggio finisce in stdout: bash lo itererebbe come se fosse una release da cancellare,
#    quindi il DELETE partirebbe su una riga inventata. Rossi attesi 16: sporca ogni conteggio di
#    righe del file. Anche qui l'indiscriminazione e' il comportamento giusto.
giro "il conteggio finisce in stdout invece che in stderr" \
     "$LIB" "sed -i \"s/file=sys.stderr)\$/file=sys.stdout)/\" $LIB" 16

echo
echo "=== a riposo, dopo tutti i giri ==="
if bash "$T" | tail -1 | grep -qE '^  [0-9]+ passati, 0 falliti'; then
  echo "  ok   verde dopo il ripristino"; pass=$((pass+1))
else
  echo "  FAIL dopo i giri non e' piu' verde: il ripristino non ha riportato tutto com'era"
  fail=$((fail+1))
fi

echo "  ------------------------------------------------------------------"
echo "  $pass passati, $fail falliti"
[ "$fail" = "0" ] || exit 1
