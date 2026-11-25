/**
 * Date utility functions for THOF frontend.
 * Formats dates in the local browser timezone to prevent midnight-UTC shift bugs
 * (e.g. between 00:00 and 02:00 in Italy, toISOString() evaluates to yesterday).
 */

export function getLocalDateStr(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date)
  if (isNaN(d.getTime())) return ''
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function addDays(date, days) {
  const d = new Date(date)
  d.setDate(d.getDate() + days)
  return d
}

export function getMondayOfWeek(date = new Date()) {
  const d = new Date(date)
  const day = d.getDay()
  const diff = d.getDate() - day + (day === 0 ? -6 : 1)
  d.setDate(diff)
  return d
}

/**
 * Toglie i secondi a un orario, **senza toccare il resto del testo**.
 *
 * Perche' una funzione e non un `.slice(0, 5)`, che e' il modo in cui la stessa cosa e' gia' scritta
 * a mano ventitre' volte in sei file (`ora`, `inizio_gara`). Due ragioni, entrambe pagate:
 *
 * 1. **Il taglio cieco mangia le annotazioni.** `partite.ora_presentazione` finisce nel campo
 *    "Orario Appuntamento" del foglio di convocazione, che ha il placeholder `13:45 · spogliatoi`:
 *    li' la gente scrive un orario **e una nota**. Su `"13:45:00 · spogliatoi"` un `.slice(0, 5)`
 *    lascia `"13:45"` e la nota sparisce in silenzio, nel documento che parte in chat ai genitori.
 *    Qui si toglie solo il componente `:SS`, il resto passa com'e'.
 * 2. **La regola va scritta una volta.** `ora` e `ora_presentazione` sono colonne `time without time
 *    zone` (verificato su DEV: `information_schema.columns`), quindi l'API le restituisce sempre
 *    `HH:MM:SS` -- `test_orario_presentazione.sh` lo asserisce da tempo (`14:15:00`, `14:00:00`).
 *    Il campo "Orario Appuntamento" delle Convocazioni mostrava i secondi perche' le righe adiacenti
 *    facevano cose diverse: `inizio_gara: p.ora.slice(0, 5)` normalizzava, `appuntamento:
 *    p.ora_presentazione` no. E' il difetto segnalato dal titolare il 25/11/2026.
 *
 * Cosa NON fa, di proposito:
 *  - non riempie e non formatta: `"9:05"` resta `"9:05"`, non diventa `"09:05"` (non stiamo inventando
 *    niente, stiamo togliendo un `:00` ridondante);
 *  - non tocca cio' che non e' un orario: `"13:45"`, `""`, `null`, un testo qualsiasi passano invariati;
 *  - **non taglia la stringa**: il match e' ancorato all'inizio e richiede la forma `H:MM:SS`, perche'
 *    `ora_appuntamento` dei tornei e` `VARCHAR(20)` e registra l'orario *come lo comunica
 *    l'organizzatore* -- li' il contenuto non si tocca.
 *
 * I secondi vengono tolti anche se diversi da `00` (es. `13:45:30` -> `13:45`): la richiesta del
 * titolare e' "bastano ore e minuti", e per un appuntamento giovanile la precisione del minuto e'
 * quella utile.
 */
// \D alla fine: "13:45:0" (secondi monodigit, malformato) NON deve matchare, e "13:45:00" deve
// matchare anche a fine stringa. Senza, un orario rotto verrebbe "corretto" invece di restare tale.
const CON_SECONDI = /^(\d{1,2}:\d{2}):(\d{2})(?:[.,]\d+)?(?=\D|$)/

export function senzaSecondi(valore) {
  if (valore === null || valore === undefined) return ''
  const testo = typeof valore === 'string' ? valore : String(valore)
  const m = CON_SECONDI.exec(testo)
  if (!m) return testo
  return m[1] + testo.slice(m[0].length)
}
