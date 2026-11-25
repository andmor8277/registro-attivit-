#!/bin/bash
# Guard-rail sull'orario del foglio di convocazione: ore e minuti, non secondi.
#
# Perche' esiste. Il titolare il 25/11/2026: «nelle Convocazioni in Orario Appuntamento fa vedere
# anche i secondi, bastano ore e minuti». Il campo e' popolato da `partite.ora_presentazione`, che
# e' una colonna `time without time zone` (verificato su DEV: information_schema.columns) e quindi
# l'API la restituisce SEMPRE `HH:MM:SS` -- lo asserisce gia' test_orario_presentazione.sh con
# `14:15:00` / `14:00:00` / `15:40:00`.
#
# Perche' il difetto esisteva: due righe ADIACENTI dello stesso file facevano cose diverse.
#     appuntamento: p.ora_presentazione || '',        <-- i secondi restavano
#     inizio_gara: p.ora ? p.ora.slice(0, 5) : '',    <-- ore e minuti
# E' la classe di difetto che questo progetto incontra da sempre: la stessa regola scritta a mano
# in due posti, e un posto si dimentica. `slice(0, 5)` in giro era gia' scritto VENTITRE' volte in
# sei file. Qui la regola vive in UN punto, `senzaSecondi()` in core/utils/date.js.
#
# Perche' NON e' un .slice(0, 5), che e' la prima cosa che verrebbe in mente. Il campo "Orario
# Appuntamento" accetta annotazioni -- il suo placeholder e' `13:45 · spogliatoi`. Su
# "13:45:00 · spogliatoi" un taglio a 5 caratteri lascia "13:45" e **cancella l'annotazione in
# silenzio**, nel documento che parte in chat ai genitori. Le asserzioni qui sotto sono costruite
# perche' quel caso sia rosso se qualcuno sostituisce la funzione con un taglio.
#
# Si lancia da solo: non tocca ne' DEV ne' il DB. Vuole solo node.
set -u
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR" || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL non riesco a entrare nella root"; exit 1; }
UTIL=frontend/src/core/utils/date.js
FOGLIO=frontend/src/core/utils/pdfConvocazione.js
CONV=frontend/src/features/partite/Convocazioni.vue
TORNEI=frontend/src/features/partite/Tornei.vue

for f in "$UTIL" "$FOGLIO" "$CONV" "$TORNEI"; do
  [ -f "$f" ] || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL manca $f"; exit 1; }
done
command -v node >/dev/null 2>&1 || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL node non disponibile"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/harness.mjs" <<'NODE'
// L'import e' dinamico perche' il percorso arriva dall'ambiente: lo risolve come URL di file, cosi'
// il test resta eseguibile da qualsiasi cartella.
import { pathToFileURL } from 'node:url'
const { senzaSecondi } = await import(pathToFileURL(process.env.UTIL_PATH).href)

let pass = 0, fail = 0
const ck = (cosa, avuto, atteso) => {
  // Si confrontano le FORME JSON, non i valori nudi. Il motivo: `senzaSecondi(null)` deve valere
  // '', e un ck che confronta '' con '' e' la lezione di test_tornei.sh (verde senza misurare
  // niente). Con JSON.stringify le tre cose diverse restano tre cose diverse: '' -> '""',
  // null -> 'null', undefined -> undefined. Cosi' la guardia "non misurare niente" non deve
  // rifiutare i casi legittimi: se la funzione regredisce e restituisce undefined, diventa rossa
  // invece di essere esclusa perche' "erano entrambi vuoti".
  const a = JSON.stringify(avuto), e = JSON.stringify(atteso)
  if (e === undefined) { fail++; console.log(`  FAIL ${cosa} -> atteso non specificato (undefined): l'asserzione non chiede niente`); return }
  if (a === undefined && e === undefined) { fail++; console.log(`  FAIL ${cosa} -> entrambi indefiniti, non ha misurato niente`); return }
  if (a === e) { pass++; console.log(`  ok   ${cosa}`) }
  else { fail++; console.log(`  FAIL ${cosa} -> ${a} (atteso ${e})`) }
}

console.log('=== la forma che arriva dal database ===')
// i valori reali di test_orario_presentazione.sh: e' cosi' che Postgres restituisce un TIME
ck('14:15:00 -> 14:15 (il caso segnalato)', senzaSecondi('14:15:00'), '14:15')
ck('14:00:00 -> 14:00', senzaSecondi('14:00:00'), '14:00')
ck('09:45:00 -> 09:45', senzaSecondi('09:45:00'), '09:45')
ck('secondi diversi da zero si tolgono comunque (13:45:30)', senzaSecondi('13:45:30'), '13:45')
ck('microsecondi di un TIME ad alta precisione', senzaSecondi('13:45:00.123456'), '13:45')

console.log('\n=== cio\' che NON e\' un orario passa invariato ===')
ck('13:45 resta 13:45', senzaSecondi('13:45'), '13:45')
ck('stringa vuota resta vuota', senzaSecondi(''), '')
ck('null -> stringa vuota (non "null", non crash)', senzaSecondi(null), '')
ck('undefined -> stringa vuota', senzaSecondi(undefined), '')
ck('testo qualsiasi intatto', senzaSecondi('dopo il riscaldamento'), 'dopo il riscaldamento')
ck('orario malformato NON viene "corretto" (13:45:0)', senzaSecondi('13:45:0'), '13:45:0')
ck('tre cifre di secondi NON matchano (13:45:000)', senzaSecondi('13:45:000'), '13:45:000')
ck('un oggetto Date non fa crashare niente', typeof senzaSecondi(new Date()), 'string')

console.log('\n=== le annotazioni: il motivo per cui non e\' uno slice ===')
// Il placeholder del campo e` `13:45 · spogliatoi`. Se qualcuno sostituisce senzaSecondi() con
// un .slice(0, 5), queste due asserzioni diventano rosse. Sono il cuore del file.
ck('l\'annotazione senza secondi resta intera',
   senzaSecondi('13:45 · spogliatoi'), '13:45 · spogliatoi')
ck('l\'annotazione SOPRAVVIVE ai secondi (uno slice la taglierebbe)',
   senzaSecondi('13:45:00 · spogliatoi'), '13:45 · spogliatoi')
ck('e indeed non e\' quello che farebbe uno slice',
   String(senzaSecondi('13:45:00 · spogliatoi') === '13:45:00 · spogliatoi'.slice(0, 5)), 'false')

console.log('\n=== l\'idempotenza, perche\' il valore fa il giro del DB ===')
// Il foglio scrive l'appuntamento in partite.ora_presentazione (COALESCE in convocazioni.py) e lo
// rilegge: se la funzione non fosse idempotente, ogni giro aggiungerebbe o toglierebbe qualcosa.
const una = senzaSecondi('14:15:00')
ck('applicarla due volte non cambia niente', senzaSecondi(una), una)
const conNota = senzaSecondi('13:45:00 · spogliatoi')
ck('idempotente anche con l\'annotazione', senzaSecondi(conNota), conNota)

console.log('\n=== l\'ora con un solo numero non si riempie (non inventiamo niente) ===')
ck('9:05:00 -> 9:05, non 09:05', senzaSecondi('9:05:00'), '9:05')

console.log('\n=== cablaggio: la regola e\' chiamata dove serve ===')
import { readFileSync } from 'node:fs'
const foglio = readFileSync(process.env.FOGLIO_PATH, 'utf8')
const conv = readFileSync(process.env.CONV_PATH, 'utf8')
const tornei = readFileSync(process.env.TORNEI_PATH, 'utf8')
ck('il foglio importa la regola, non la riscrive', (foglio.match(/from '\.\/date\.js'/g) || []).length, 1)
ck('il foglio la chiama su tutti e 3 i campi Appuntamento',
   (foglio.match(/formatOra\(gara\.appuntamento\)/g) || []).length, 3)
ck('e su entrambi gli orari Inizio gara del foglio',
   (foglio.match(/formatOra\(gara\.inizio_gara\)/g) || []).length +
   (foglio.match(/senzaSecondi\(gara\.inizio_gara\)/g) || []).length, 3)
ck('nessun orario del foglio esce piu\' grezzo',
   (foglio.match(/gara\.(appuntamento|inizio_gara) \|\| '—'/g) || []).length, 0)
ck('Convocazioni.vue importa la regola, non la riscrive',
   (conv.match(/import \{ senzaSecondi \} from/g) || []).length, 1)
// Conteggio ESATTO, non `>= 5`. Alla prima esecuzione era `>= 5` e le occorrenze erano esattamente 5:
// un'asserzione a coltello, che urla per qualunque taglio e tace su qualunque aggiunta, e che infatti
// rendeva il giro 7 del negative test "2 rossi, attesi 1" -- cioe' non sapevo quale delle due avesse
// visto cosa. Qui si chiede il numero dei punti di popolazione, che e' la cosa che conta.
ck('i punti di popolazione che applicano la regola sono 4 (li ho contati a mano)',
   (conv.match(/senzaSecondi\(p\.ora_presentazione\)/g) || []).length, 4)
ck('e nessuno di essi passa da un .slice(0, 5) scritto a mano',
   (conv.match(/ora_presentazione[^)\n]*\.slice\(0,/g) || []).length, 0)
ck('nessun appuntamento popolato piu\' grezzo da ora_presentazione',
   (conv.match(/appuntamento: p\.ora_presentazione/g) || []).length, 0)
// IL percorso che il titolare guarda davvero: riaprire un foglio gia' salvato. `caricaConvocazione` fa
// `...g`, quindi porta via il valore COM'E' nel DB -- e nel DB i secondi ci sono (misurato su PROD: tre
// righe del foglio 17 del 21/11 con 08:00:00 / 14:15:00 / 17:00:00). I cinque punti di popolazione non
// lo toccano: se questa coppia di asserzioni cade, il difetto torna visibile a schermo anche con il
// PDF corretto, che e' meta' del segnalato del 25/11/2026
ck('chi riapre un foglio salvato normalizza l\'appuntamento',
   (conv.match(/appuntamento: senzaSecondi\(g\.appuntamento\)/g) || []).length, 1)
ck('e normalizza anche inizio_gara sullo stesso percorso (la coppia non deve divergere)',
   (conv.match(/inizio_gara: senzaSecondi\(g\.inizio_gara\)/g) || []).length, 1)
ck('Tornei.vue normalizza ENTRAMBI gli orari del foglio (la coppia che divergeva)',
   [/\sappuntamento: senzaSecondi\(g\.ora_appuntamento\)/, /\sinizio_gara: senzaSecondi\(g\.ora\)/]
     .filter(r => r.test(tornei)).length, 2)

console.log(`  ------------------------------------------------------------------`)
console.log(`  ${pass} passati, ${fail} falliti`)
process.exit(fail === 0 ? 0 : 1)
NODE

UTIL_PATH="$DIR/$UTIL" FOGLIO_PATH="$DIR/$FOGLIO" CONV_PATH="$DIR/$CONV" TORNEI_PATH="$DIR/$TORNEI" \
  node --no-warnings "$TMP/harness.mjs"
