#!/bin/bash
# Negative test di verifica_etichette_export.py: prova che il guard-rail delle coppie di export
# SAPPIA FALLIRE, e lo prova in quattro direzioni diverse.
#
# Perche' esiste. Il titolare ha scelto la convenzione "Ambito (PDF)" / "Ambito (immagine)" perche'
# le etichette erano derivate in quattro modi ("Immagine", "Esporta JPEG", "JPEG", e il non-italiano
# "Immagine la selezione"). Il guard-rail che deve impedire che il drift torni, se non e' mai stato
# visto rosso, non e' un guard-rail: e' una speranza. E' la stessa ragione per cui esiste
# negative_export_jpeg.sh.
#
# Perche' ogni giro ASSERISCE che la mutazione e' partita. La prima versione di questo file ha
# prodotto DUE falsi verdi con la propria mano: le mutazioni 1 e 4 matchavano `'Calendario torneo
# (PDF)'` con le virgolette, ma quelle etichette stanno in un <span> senza virgolette, quindi `sed`
# non sostituiva niente e il guard-rail diceva verde -- esattamente il caso (una meta' della coppia
# rinominata) per cui era stato scritto. Una mutazione che non parte non ha testato niente, quindi
# qui il `diff` fra file mutato e file pristino DEVE essere non vuoto, e il nome del file mutato
# viene nominato nel rosso.
#
# Non e' nella suite: `run_suite_dev.sh` scopre solo `test_*.sh`, e questo stampa i rossi di
# proposito. Si lancia a mano, ~5 secondi in tutto (non tocca ne' DEV ne' il DB: legge tre .vue).
set -u
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR" || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL non riesco a entrare nella root"; exit 1; }

V=scripts/test/verifica_etichette_export.py
T=frontend/src/features/partite/Tornei.vue
C=frontend/src/features/partite/Convocazioni.vue
P=frontend/src/features/partite/ProgrammazionePartite.vue
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

[ -f "$V" ] || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL manca $V"; exit 1; }
for f in "$T" "$C" "$P"; do
  [ -f "$f" ] || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL manca $f"; exit 1; }
  cp "$f" "$TMP/$(basename "$f").pristino"
done
# impronte dei pristini: il ripristino si verifica su queste, non su "ho eseguito il comando"
sha() { sha256sum "$1" | cut -c1-16; }
PRISTINO=$(for f in "$T" "$C" "$P"; do printf '%s ' "$(sha "$f")"; done)

pass=0; fail=0
# ripristina tutto e VERIFICA le impronte: un ripristino non verificato rende verdi i giri dopo
ripristina() {
  local f
  for f in "$T" "$C" "$P"; do cp "$TMP/$(basename "$f").pristino" "$f"; done
  local adesso; adesso=$(for f in "$T" "$C" "$P"; do printf '%s ' "$(sha "$f")"; done)
  if [ "$adesso" != "$PRISTINO" ]; then
    echo "  FAIL il ripristino non ha riportato i file pristini (i giri successivi non varrebbero)"
    fail=$((fail+1)); return 1
  fi
  return 0
}

# giro <descrizione> <file da mutare> <comando-di-mutazione> <numero-rossi-atteso>
giro() {
  local cosa="$1" file="$2" muta="$3" attesi="$4"
  echo
  echo "── $cosa"
  eval "$muta"
  # 1) la mutazione deve aver cambiato i BYTE del file, o il giro non ha misurato niente
  if diff -q "$file" "$TMP/$(basename "$file").pristino" >/dev/null; then
    echo "  FAIL MUTAZIONE NON PARTITA su $file: il file e' identico al pristino, il verdetto"
    echo "       successivo non prova niente (e' cosi' che questa suite ha prodotto falsi verdi)"
    fail=$((fail+1)); ripristina; return
  fi
  local out n
  out=$(python3 "$V" 2>&1); local rc=$?
  n=$(printf '%s' "$out" | grep -c '^  FAIL')
  printf '%s\n' "$out" | grep '^  FAIL' | sed 's/^/       /'
  if [ "$rc" = "0" ] || [ "$n" = "0" ]; then
    echo "  FAIL il guard-rail non si e\' accorto di \"$cosa\": dice verde su un difetto che deve vedere"
    fail=$((fail+1))
  elif [ "$n" != "$attesi" ]; then
    echo "  FAIL rossi $n, attesi $attesi per \"$cosa\" (troppe o troppo poche asserzioni colpite"
    echo "       significa che il test non e\' discriminatorio: non sai quale regola ha visto cosa)"
    fail=$((fail+1))
  else
    echo "  ok   $n rossi come atteso"
    pass=$((pass+1))
  fi
  ripristina
}

echo "=== il guard-rail delle coppie sa fallire? ==="
echo "prerequisito: a riposo deve essere verde"
if python3 "$V" >/dev/null 2>&1; then echo "  ok   verde a riposo"; pass=$((pass+1)); else
  echo "  FAIL non e\' verde a riposo: i giri sotto non misurerebbero niente"; fail=$((fail+1)); fi

# 1. LA regressione reale: una meta' sola della coppia viene rinominata. E' il difetto che il
#    titolare ha visto (le quattro etichette diverse) e il motivo per cui questo file esiste.
giro "una meta' sola della coppia rinominata (Calendario torneo -> tornei)" \
     "$T" "sed -i 's|<span>Calendario torneo (PDF)</span>|<span>Calendario tornei (PDF)</span>|' $T" 2

# 2. Il formato smette di essere l'ultima parola: la simmetria puo' restare vera ma la convenzione
#    e' rotta, e i pulsanti tornano a non leggersi come una coppia. Rossi attesi e giustificati:
#    (a) coppia non simmetrica, (b) non finisce con (immagine), (c) contiene la parola nuda
#    "Immagine" -- che E' l'etichetta vecchia, quindi la terza non e' ridondante.
giro "il formato non e' piu' in fondo (Calendario weekend (immagine) -> Immagine calendario weekend)" \
     "$P" "sed -i \"s|'Calendario weekend (immagine)'|'Immagine calendario weekend'|\" $P" 3

# 3. Una parola vecchia di ritorno: e' il drift che ha generato il reclamo del titolare. Colpisce
#    UNA riga sola (106) perche' le due etichette "Gare genitori (immagine)" sono identiche e
#    colpirle entrambe darebbe rossi in duplice, che non dicono niente in piu'. Rossi attesi:
#    simmetria, formato in fondo, e la parola "JPEG".
giro "ritorna la parola JPEG su una meta' della coppia" \
     "$P" "sed -i \"106s|'Gare genitori (immagine)'|'JPEG genitori'|\" $P" 3

# 4. Il pulsante PDF perde il formato dall'etichetta: la coppia non e' piu' confrontabile. Rossi
#    attesi DUE, non tre: la lista degli ambiti non si muove perche' "Foglio convocazione" e'
#    comunque l'ambito atteso, e questo e' il giro che dimostra che le tre asserzioni non scattano
#    sempre tutte in blocco -- se scattassero sempre, il test non sarebbe discriminatorio.
giro "il pulsante PDF perde il formato dall'etichetta (Convocazioni)" \
     "$C" "sed -i 's|Foglio convocazione (PDF)|Foglio convocazione|' $C" 2

echo
echo "=== a riposo, dopo tutti i giri ==="
if python3 "$V" | tail -1 | grep -q '^  ok'; then echo "  ok   verde dopo il ripristino"; pass=$((pass+1)); else
  echo "  FAIL dopo i giri non e\' piu\' verde: il ripristino non ha riportato tutto com'era"; fail=$((fail+1)); fi

echo "  ------------------------------------------------------------------"
echo "  $pass passati, $fail falliti"
[ "$fail" = "0" ] || exit 1
