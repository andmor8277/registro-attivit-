/**
 * I pezzi comuni dei PDF dell'area partite (Programmazione Partite e Programmazione Tornei).
 *
 * Perche' un file e non il codice scritto due volte: il PDF del weekend e quello dei tornei sono lo
 * stesso tipo di documento — un calendario che un genitore o un organizzatore riceve in chat — e due
 * copie del foglio di stile sono due documenti che il giorno dopo non si assomigliano piu'. La forma
 * di riferimento e' quella gia' in uso su Programmazione Partite, perche' e' quella che la societa'
 * conosce: titolo a 16 con il nome della societa', sottotitolo grigio con le date e "Generato il",
 * tabella `grid` con margini 14, tableWidth 260, intestazione rossa e le barre di categoria come
 * RIGHE colSpan DENTRO il corpo della tabella.
 *
 * L'ultima cosa non e' un dettaglio di gusto. Disegnare la barra con `doc.rect` + `doc.text` (come
 * faceva l'export dei tornei alla prima versione) sembra identico in anteprima e non lo e': la barra
 * non partecipa all'impaginazione, quindi a fondo pagina si ritrovi con il titolo del torneo in fondo
 * al foglio e il calendario che ricomincia dopo, oppure con la barra sopra il bordo della tabella.
 * Dentro la tabella, autotable la porta via con la riga quando serve.
 */

// I colori sono quelli del tema chiaro dell'app scritti in RGB: jsPDF non legge le CSS variables, e
// il rosso deve essere lo stesso della pagina o il documento sembra di un'altra applicazione
export const ROSSO_THOF = [220, 38, 38]
export const AMBRA_THOF = [180, 83, 9]
export const GRIGIO_TESTO = 100

/**
 * L'intestazione del documento, identica a quella del weekend.
 *
 * Ritorna la y dove comincia il corpo, cosi' chi chiama non si deve ricordare il numero: se un giorno
 * l'intestazione cresce, la modifica e' qui e le due pagine restano allineate.
 *
 * `avviso` e' la riga in piu', in ambra, per dire cio' che il documento NON e' (per esempio "solo la
 * selezione a schermo"): sta su una riga sua perche' il sottotitolo grigio e' gia' occupato dalle
 * date, e un avviso che condivide la riga con la data diventa decorazione.
 */
export function intestazionePdf(doc, { titolo, sottotitolo, avviso } = {}) {
  doc.setFontSize(16)
  doc.text(String(titolo || ''), 14, 15)
  doc.setFontSize(9)
  doc.setTextColor(GRIGIO_TESTO)
  doc.text(String(sottotitolo || ''), 14, 22)
  if (avviso) {
    doc.setTextColor(AMBRA_THOF[0], AMBRA_THOF[1], AMBRA_THOF[2])
    doc.setFont(undefined, 'bold')
    doc.text(String(avviso), 14, 26)
    doc.setFont(undefined, 'normal')
  }
  doc.setTextColor(0)
  return avviso ? 32 : 28
}

/**
 * Le opzioni comuni di autoTable: theme, margini, larghezza e stili di testa/corpo del weekend.
 * Chi la usa aggiunge `head`, `body`, `startY` e le proprie `columnStyles` (le larghezze dipendono
 * dalle colonne, quelle non sono condivisibili).
 */
export const BASE_TABELLA = {
  theme: 'grid',
  margin: { left: 14, right: 14 },
  tableWidth: 260,
  styles: { fontSize: 8.5, cellPadding: 3, halign: 'left', valign: 'middle' },
  headStyles: { fillColor: ROSSO_THOF, textColor: 255, fontStyle: 'bold', halign: 'center', fontSize: 9 }
}

/**
 * Una riga-barra che occupa tutta la larghezza della tabella: la barra di categoria del weekend,
 * usata anche per il nome del torneo e per il titolo del foglio giocatori.
 *
 * `tipo` sceglie il livello gerarchico. 'categoria' e' il rosso del weekend, 11pt. 'torneo' e' un
 * grigio chiaro: il documento dei tornei ha DUE livelli (categoria > torneo) e due barre rosse una
 * sopra l'altra non direbbero quale delle due contiene l'altra.
 */
export function barra(testo, colonne, tipo = 'categoria') {
  return [{ content: String(testo || ''), colSpan: colonne, barraTipo: tipo }]
}

/**
 * Il didParseCell che trasforma le righe di `barra()` in barre vere. Copiato dal weekend, riga per
 * riga: chi lo usa lo chiama per primo e poi gestisce le proprie celle.
 */
export function didParseCellBarra(d) {
  if (d.section !== 'body' || !d.raw || !d.raw.colSpan) return
  d.cell.colSpan = d.raw.colSpan
  d.cell.raw = d.raw.content
  const torneo = d.raw.barraTipo === 'torneo'
  const nebulosa = d.raw.barraTipo === 'avviso'
  d.cell.styles.fontStyle = 'bold'
  d.cell.styles.halign = 'left'
  d.cell.styles.cellPadding = { top: 5, bottom: 5, left: 6, right: 6 }
  if (torneo) {
    d.cell.styles.fillColor = [243, 244, 246]
    d.cell.styles.textColor = [17, 24, 39]
    d.cell.styles.fontSize = 10
  } else if (nebulosa) {
    d.cell.styles.fillColor = AMBRA_THOF
    d.cell.styles.textColor = [255, 255, 255]
    d.cell.styles.fontSize = 9.5
  } else {
    d.cell.styles.fillColor = ROSSO_THOF
    d.cell.styles.textColor = [255, 255, 255]
    d.cell.styles.fontSize = 11
  }
}

/**
 * La cella della data, identica fra i due documenti: `dd/mm/aaaa` e, se e' domenica, ` (DOM)` in coda.
 * Il marcatore sta nella STRINGA e non solo nel colore perche' il PDF lo si legge anche stampato in
 * bianco e nero, e perche' `coloraDomenica` deve avere qualcosa su cui decidere.
 *
 * `vuoto` e' cosa scrivere quando la data non c'e': il weekend lascia la cella vuota, i tornei mettono
 * '-'. Lasciati diversi di proposito, non e' la stessa identica tabella.
 */
export function cellData(dataStr, vuoto = '') {
  if (!dataStr) return vuoto
  const parti = String(dataStr).split('-')
  if (parti.length !== 3) return String(dataStr)
  const [y, m, d] = parti
  const dt = new Date(Number(y), Number(m) - 1, Number(d))
  return `${d}/${m}/${y}${dt.getDay() === 0 ? ' (DOM)' : ''}`
}

/**
 * La domenica in arancione, come la fa il weekend: i genitori guardano quella colonna per capire se e'
 * sabato o domenica. `indice` e' la colonna della data, perche' nei tornei gli elenchi hanno un numero
 * di colonne diverso dal weekend.
 */
export function coloraDomenica(d, indice = 0) {
  if (d.section !== 'body' || !d.cell || (d.raw && d.raw.colSpan)) return
  if (d.column.index !== indice) return
  if (d.cell.raw && String(d.cell.raw).includes('(DOM)')) {
    d.cell.styles.textColor = [217, 119, 6]
    d.cell.styles.fontStyle = 'bold'
  }
}
