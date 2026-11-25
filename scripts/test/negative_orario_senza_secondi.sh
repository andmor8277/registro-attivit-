#!/bin/bash
# Negative test di test_orario_senza_secondi.sh: prova che il guard-rail sugli orari SAPPIA FALLIRE.
#
# Perche' esiste. Il difetto segnalato dal titolare il 25/11/2026 ("Orario Appuntamento fa vedere
# anche i secondi") era nato cosi': due righe adiacenti, una con `.slice(0, 5)` e una senza. Un test
# verde che non si e' mai visto rosso davanti a QUESTE due mutazioni -- la regola tolta, e la regola
# ridotta a un taglio -- non e' una difesa: e' la stessa fiducia che ha retto finche' qualcuno non ha
# guardato lo schermo.
#
# La mutazione che conta di piu' e' la seconda. Se `senzaSecondi()` fosse solo un `.slice(0, 5)`, il
# caso segnalato funzionerebbe lo stesso: "13:45:00" -> "13:45". La differenza la fa il campo che
# accetta annotazioni (`13:45 · spogliatoi`), dove il taglio cancella il testo in silenzio nel
# documento che parte in chat. Se quel giro non diventa rosso, il test non distingue una regola da un
# taglio -- e allora tanto valeva scrivere lo slice.
#
# Perche' ogni giro ASSERISCE che la mutazione e' partita, e perche' la mutazione esige UNA sola
# occorrenza. E' la lezione pagata tre volte in questo progetto (etichette, migrazioni, certificati):
# una mutazione che non sostituisce niente produce un verde che non ha misurato niente, e una che ne
# sostituisce tre non e' la mutazione che credi di aver fatto.
#
# Non e' nella suite: run_suite_dev.sh scopre solo test_*.sh, e questo stampa rossi di proposito.
# Si lancia a mano, ~10 secondi (non tocca ne' DEV ne' PROD ne' il DB: lavora sui sorgenti e li
# ripristina, verificando per hash).
set -u
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR" || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL non riesco a entrare nella root"; exit 1; }

UTIL=frontend/src/core/utils/date.js
FOGLIO=frontend/src/core/utils/pdfConvocazione.js
TORNEI=frontend/src/features/partite/Tornei.vue
CONV=frontend/src/features/partite/Convocazioni.vue
T=scripts/test/test_orario_senza_secondi.sh
FILEI=("$UTIL" "$FOGLIO" "$TORNEI" "$CONV" "$T")

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for f in "${FILEI[@]}"; do
  [ -f "$f" ] || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL manca $f"; exit 1; }
  cp "$f" "$TMP/$(basename "$f").pristino"
done
# Il ripristino va nel trap, non solo in fondo ai giri: questo script TOCCA sorgenti veri, e un
# Ctrl-C o un timeout a meta' di un giro li lascerebbe mutati. E' la stessa classe di disastro gia'
# pagato qui dentro con `git checkout` dentro un ciclo di test -- solo che qui non serve nemmeno
# un comando sbagliato, basta un Ctrl-C.
ripristina_puo_fallire() { local f; for f in "${FILEI[@]}"; do cp "$TMP/$(basename "$f").pristino" "$f" 2>/dev/null || true; done; }
trap 'ripristina_puo_fallire; rm -rf "$TMP"' EXIT
sha() { sha256sum "$1" | cut -c1-16; }
PRISTINO=$(for f in "${FILEI[@]}"; do printf '%s ' "$(sha "$f")"; done)

pass=0; fail=0
ripristina() {
  local f
  # SOLO dalle copie in $TMP: mai `git checkout`, che qui dentro ha gia' cancellato lavoro non
  # committato in un altro giro di test di questo progetto
  for f in "${FILEI[@]}"; do cp "$TMP/$(basename "$f").pristino" "$f"; done
  local adesso; adesso=$(for f in "${FILEI[@]}"; do printf '%s ' "$(sha "$f")"; done)
  if [ "$adesso" != "$PRISTINO" ]; then
    echo "  FAIL il ripristino non ha riportato i file pristini: i giri successivi non varrebbero"
    fail=$((fail+1)); return 1
  fi
  return 0
}

# Sostituisce ESATTAMENTE una occorrenza, e se non e' una sola si ferma. Il `diff` sotto da solo non
# basta: una sostituzione che colpisce tre punti diversi E' partita, ma non e' la mutazione che
# descrive l'etichetta del giro.
muta() { # muta <file> <vecchio> <nuovo>
  python3 - "$1" "$2" "$3" <<'PY'
import sys
p, vecchio, nuovo = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
n = s.count(vecchio)
if n != 1:
    print(f'       MUTAZIONE NON VALIDA: {n} occorrenze del frammento in {p}, attesa 1')
    raise SystemExit(2)
open(p, 'w', encoding='utf-8').write(s.replace(vecchio, nuovo))
PY
}

giro() { # giro <descrizione> <file> <comando-di-mutazione> <rossi-attesi>
  local cosa="$1" file="$2" muta_cmd="$3" attesi="$4"
  echo
  echo "── $cosa"
  if ! eval "$muta_cmd"; then
    echo "  FAIL la mutazione non e' applicabile: il frammento non e' piu' quello che il giro si aspetta"
    echo "       (il sorgente e' cambiato: questo negative test va aggiornato, non ignorato)"
    fail=$((fail+1)); ripristina; return
  fi
  if diff -q "$file" "$TMP/$(basename "$file").pristino" >/dev/null; then
    echo "  FAIL MUTAZIONE NON PARTITA su $file: identica al pristino, il verdetto dopo non prova niente"
    fail=$((fail+1)); ripristina; return
  fi
  local out n rc
  out=$(bash "$T" 2>&1); rc=$?
  n=$(printf '%s\n' "$out" | grep -c '^  FAIL')
  printf '%s\n' "$out" | grep '^  FAIL' | sed 's/^/       /' | head -8
  # Un test che MUORE non e' un test che ha trovato un difetto: e' un test rotto. Se non arriva al
  # riepilogo, il conteggio dei FAIL non rappresenta niente e il verde/rosso sotto sarebbe una
  # coincidenza. (Nessuno dei giri qui sotto lo provoca: e' una guardia sull'arness, non sul codice.)
  if ! printf '%s\n' "$out" | grep -qE '^  [0-9]+ passati, [0-9]+ falliti'; then
    echo "  FAIL il test non arriva al riepilogo (rc $rc): e' morto, e un crash non e' una prova"
    fail=$((fail+1)); ripristina; return
  fi
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

# ---- i frammenti, presi dai sorgenti pristini ----------------------------------------------
# Il corpo della regola, tutto: sostituirlo tutto e' il modo onesto di mutare "la funzione diventa un
# taglio". Sostituire solo l'ultima riga avrebbe lasciato in piedi `if (!m) return testo`, che
# nasconde meta' dei rossi e renderebbe il giro piu' debole di quanto sembra.
CORPO=$(cat <<'EOF'
  if (valore === null || valore === undefined) return ''
  const testo = typeof valore === 'string' ? valore : String(valore)
  const m = CON_SECONDI.exec(testo)
  if (!m) return testo
  return m[1] + testo.slice(m[0].length)
EOF
)
NOOP=$(cat <<'EOF'
  const m = CON_SECONDI.exec(testo)
  if (!m) return testo
  return m[1] + testo.slice(m[0].length)
EOF
)
GUARDIA="  if (valore === null || valore === undefined) return ''"
REGEX='const CON_SECONDI = /^(\d{1,2}:\d{2}):(\d{2})(?:[.,]\d+)?(?=\D|$)/'
FOGLIO_GREZZO="            ['Appuntamento', formatOra(gara.appuntamento)],"
COPPIA_TORNEI=$(cat <<'EOF'
          appuntamento: senzaSecondi(g.ora_appuntamento),
          inizio_gara: senzaSecondi(g.ora),
EOF
)
POP_ANNIDATO='          appuntamento: senzaSecondi(p.ora_presentazione),'
POP_GREZZO=$(cat <<'EOF'
          appuntamento: p.ora_presentazione || '',
EOF
)
# IL percorso che riapre un foglio salvato. `caricaConvocazione` fa `...g`, quindi senza queste due righe
# il campo a schermo torna a mostrare il valore del DB com'e' -- ed e' esattamente il caso che il titolare
# ha visto (foglio 17 del 21/11 su PROD: 08:00:00 / 14:15:00 / 17:00:00). Nessuna delle altre mutazioni
# lo vede: il PDF resta corretto perche' formatOra normalizza comunque, quindi senza questo giro il
# difetto sarebbe verde a meta' (documento si', schermo no)
CARICO=$(cat <<'EOF'
      appuntamento: senzaSecondi(g.appuntamento),
      inizio_gara: senzaSecondi(g.inizio_gara),
EOF
)
CARICO_ROTTA=$(cat <<'EOF'
      appuntamento: g.appuntamento,
      inizio_gara: g.inizio_gara,
EOF
)
COPPIA_ROTTA=$(cat <<'EOF'
          appuntamento: g.ora_appuntamento,
          inizio_gara: senzaSecondi(g.ora),
EOF
)

echo "=== il guard-rail sugli orari sa fallire? ==="
if bash "$T" >/dev/null 2>&1; then echo "  ok   verde a riposo"; pass=$((pass+1)); else
  echo "  FAIL non e' verde a riposo: i giri sotto non misurerebbero niente"; fail=$((fail+1)); fi

# 1. LA mutazione che conta: la regola diventa un .slice(0, 5). E' esattamente quello che qualcuno
#    scriverebbe al posto di senzaSecondi() "perche' fa lo stesso". Il caso segnalato dal titolare
#    ("13:45:00" -> "13:45") con lo slice FUNZIONA: quindi se questo giro non diventa rosso, il test
#    non distingue una regola da un taglio e non vale niente.
#    Rossi attesi 7: le due asserzioni sull'annotazione + quella che confronta lo slice + i tre testi
#    che non sono orari (troncati) + l'ora a una cifra (9:05: -> "9:05:").
giro "la regola diventa un .slice(0, 5) (e' cio' che qualcuno scriverrebbe al suo posto)" \
     "$UTIL" "muta \"$UTIL\" \"\$CORPO\" \"  return String(valore ?? '').slice(0, 5)\"" 7

# 2. La regola diventa un no-op: i secondi restano. E' il difetto com'era prima della correzione --
#    le due righe adiacenti che facevano cose diverse.
#    Rossi attesi 7: i cinque valori del DB + l'annotazione coi secondi + 9:05:00.
giro "la regola e' un no-op (il difetto com'era: i secondi arrivano a schermo)" \
     "$UTIL" "muta \"$UTIL\" \"\$NOOP\" \"  return testo\"" 7

# 3. La guardia sul null/undefined tolta: `String(null)` e' 'null', e un campo vuoto del DB diventerebbe
#    la parola "null" stampata nel foglio che parte in chat.
#    Rossi attesi 2: i due casi null e undefined.
giro "la guardia su null/undefined e' tolta (un campo vuoto del DB diventa la parola 'null')" \
     "$UTIL" "muta \"$UTIL\" \"\$GUARDIA\" \"  if (false) return ''\"" 2

# 4. L'ancora (?=\D|\$) tolta dal regex: "13:45:000" (malformato) verrebbe "corretto" in '13:450'
#    invece di restare tale. E' il giro piu' stretto dei quattro: colpisce UNA sola asserzione, e
#    proprio per questo dimostra che quella riga del regex serve e non e' decorazione.
#    Rossi attesi 1.
giro "l'ancora (?=\D|\$) del regex e' tolta (un orario malformato viene 'corretto' invece che lasciato tale)" \
     "$UTIL" "muta \"$UTIL\" \"\$REGEX\" \"const CON_SECONDI = /^(\\\\d{1,2}:\\\\d{2}):(\\\\d{2})(?:[.,]\\\\d+)?/\"" 1

# 5. Il foglio torna a stampare l'appuntamento grezzo in UNO dei tre punti. Dimostra che le asserzioni
#    sul cablaggio mordono: non stanno contando che la parola esista da qualche parte, contano QUANTE
#    volte e dove.
#    Rossi attesi 2: il conteggio dei tre campi Appuntamento e l'asserzione "nessun orario esce grezzo".
giro "il foglio stampa di nuovo un appuntamento grezzo in uno dei tre punti" \
     "$FOGLIO" "muta \"$FOGLIO\" \"\$FOGLIO_GREZZO\" \"            ['Appuntamento', gara.appuntamento || '—'],\"" 2

# 6. IL DIFETTO ORIGINALE, riprodotto sul file dove e' nato: la coppia di righe del foglio del torneo
#    torna divergente, una normalizza e l'altra no. E' la classe di difetto che questo progetto
#    incontra da sempre, e qui e' diventata visibile perche' qualcuno ha guardato lo schermo.
#    Rossi attesi 1: l'asserzione che esige la coppia intera.
giro "la coppia di orari del foglio torna divergente (il difetto originale, riga si' riga no)" \
     "$TORNEI" "muta \"$TORNEI\" \"\$COPPIA_TORNEI\" \"\$COPPIA_ROTTA\"" 1

# 7. Uno dei cinque punti di popolazione delle Convocazioni torna grezzo: e' il punto annidato (10
#    spazi), quello che le altre due occorrenze non rendono unico -- se il test se ne accorge solo
#    qui, vuol dire che le altre due non le sta guardando affatto.
#    Rossi attesi 2, non 1: le due asserzioni che guardano quel punto -- il conteggio dei quattro
#    punti di popolazione e il divieto che qualcuno passi grezzo -- sono la stessa regola vista da due
#    angolazioni, quindi un taglio vero le colpisce entrambe. Non e' indiscriminazione come nel giro 1
#    e 5: qui entrambi i rossi dicono "manca senzaSecondi su ora_presentazione".
giro "un punto di popolazione delle Convocazioni torna grezzo (il piu' annidato)" \
     "$CONV" "muta \"$CONV\" \"\$POP_ANNIDATO\" \"\$POP_GREZZO\"" 2

# 8. IL caso che il titolare ha visto, e che nessuna delle mutazioni sopra vede: chi RIAPRE un foglio
#    salvato torna a mostrare i secondi. E' il giro che vale piu' di tutti, perche' e' l'unico che colpisce
#    `caricaConvocazione` -- e li' il PDF resta verde (formatOra normalizza comunque), quindi un test che
#    guardasse solo il documento direbbe "a posto" mentre lo schermo mente.
#    Rossi attesi 2: le due asserzioni del percorso di caricamento.
giro "chi riapre un foglio salvato torna a mostrare i secondi (il caso reale di PROD)" \
     "$CONV" "muta \"$CONV\" \"\$CARICO\" \"\$CARICO_ROTTA\"" 2

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