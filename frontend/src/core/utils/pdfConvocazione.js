// Il FOGLIO DI CONVOCAZIONE, una sola implementazione.
//
// Lo chiamano in due: `Convocazioni.vue` (il foglio del weekend, quello che si consegna il venerdi')
// e il modal convocazione di `Tornei.vue` (un foglio per ogni gara del Calendario Tornei). E' la
// stessa ragione per cui i due CALENDARI stanno in `pdfTHOF.js`: il foglio e' lo stesso oggetto --
// un elenco di ragazzi con la logistica della gara, che un genitore o un organizzatore riceve in
// chat. Due copie del foglio di stile sono due documenti che il giorno dopo non si assomigliano
// piu', e in chat sembrano di due associazioni diverse.
//
// La funzione e' la estrazione meccanica del corpo di `esportaPDF()` di Convocazioni.vue: i sei
// nomi che leggevano dallo stato della pagina (`convocazione`, `persone`, `societa`, `categoria`,
// `stagione`, `getAllenatoriLabel`) sono ora parametri. Il corpo del documento -- impaginazione,
// ritratto/paesaggio, i preset che riducono il carattere, le colonne -- non e' stato riscritto.
//
// Cosa NON si fa qui, e va saputo: `buildRows` stampa chiunque sia nell'array `giocatori` della
// gara, SENZA guardare `non_presente`. Un ragazzo segnato "assente" a schermo esce quindi nel
// documento come se ci fosse. E' il comportamento del foglio del weekend da prima che il percorso
// torneo esistesse, scelto di mantenere identico su entrambi i fogli invece di farli divergere;
// chiarezza sul documento si ottiene togliendo il ragazzo dalla lista, non segnandolo assente.
import { jsPDF } from 'jspdf'
import 'jspdf-autotable'
// Le fonti dirette, non il barrel `src/api/index.js`: questo modulo sta gia' dentro core/, e passare
// dal barrel per due funzioni significherebbe importare tutta la superficie API in ogni chunk che
// importa il foglio. Sono gli STESSI file da cui il barrel le riesporta
import { getUploadUrl } from '../api/client.js'
import { exportPdf, exportJpeg } from './export.js'
import { senzaSecondi } from './date.js'

export async function esportaFoglioConvocazione({
  convocazione,
  persone = [],
  societa = null,
  categoria = null,
  stagione = null,
  etichettaAllenatori = () => '',
  nomeFile = null,
  titoloDownload = null,
  // 'pdf' | 'jpeg'. NON cambia una riga dell'impaginazione: il documento si costruisce comunque
  // qui sotto, e il formato sceglie solo come viene consegnato. E' il motivo per cui la JPEG e'
  // davvero il PDF -- stessi byte, non una seconda versione del foglio
  formato = 'pdf',
} = {}) {
  if (!convocazione) return
  try {
    const gareList = convocazione.gare || []
    const multiGare = gareList.length > 1
    const singleGara = gareList.length === 1
    const singleRows = singleGara ? (gareList[0]?.giocatori || []).filter(Boolean).length : 0
    const useLandscape = multiGare || (singleGara && singleRows > 20)
    const doc = new jsPDF(useLandscape ? 'landscape' : 'portrait', 'mm', 'a4')
    const pageWidth = doc.internal.pageSize.getWidth()
    const pageHeight = doc.internal.pageSize.getHeight()
    const margin = multiGare ? 12 : 14
    const contentWidth = pageWidth - margin * 2
    const accent = [220, 38, 38]
    const dark = [17, 24, 39]
    const gray = [107, 114, 128]
    const light = [248, 250, 252]
    const line = [226, 232, 240]

    const noteText = convocazione.note || ''
    let noteLines = []
    let noteHeight = 0
    let noteFontSize = 8.5
    let noteLineHeight = 3.9
    if (noteText) {
      const maxNoteHeight = multiGare ? (gareList.length >= 4 ? 28 : 34) : (useLandscape ? 48 : 72)
      const notePresets = [
        { fontSize: 8.5, lineHeight: 3.9 },
        { fontSize: 7.5, lineHeight: 3.4 },
        { fontSize: 7, lineHeight: 3.1 },
        { fontSize: 6.5, lineHeight: 2.8 }
      ]
      for (const preset of notePresets) {
        noteFontSize = preset.fontSize
        noteLineHeight = preset.lineHeight
        doc.setFont('helvetica', 'normal')
        doc.setFontSize(noteFontSize)
        noteLines = doc.splitTextToSize(noteText, contentWidth - 8)
        noteHeight = noteLines.length * noteLineHeight + 10
        if (noteHeight <= maxNoteHeight) break
      }
      if (noteHeight > maxNoteHeight) {
        const maxLines = Math.max(1, Math.floor((maxNoteHeight - 9) / noteLineHeight))
        if (noteLines.length > maxLines) {
          noteLines = noteLines.slice(0, maxLines)
          noteLines[maxLines - 1] = `${noteLines[maxLines - 1].slice(0, Math.max(0, noteLines[maxLines - 1].length - 1))}…`
        }
        noteHeight = Math.min(maxNoteHeight, noteLines.length * noteLineHeight + 9)
      }
    }
    const bottomMargin = 18 + (noteText ? noteHeight + 6 : 0)

    const personeMap = new Map()
    persone.forEach(p => personeMap.set(p.id, p))
    const getPersona = (id) => personeMap.get(id) || persone.find(p => p.id === id || p.id === Number(id))
    const formatD = (d) => d ? d.split('-').reverse().join('/') : '—'
    // L'orario del foglio esce SENZA secondi, sempre. Le colonne `ora` / `ora_presentazione` sono
    // `time without time zone` e l'API le restituisce `HH:MM:SS`; il campo e' pero' anche testo libero
    // ("13:45 · spogliatoi"), quindi la regola -- non un .slice(0,5) che taglierebbe l'annotazione --
    // vive in senzaSecondi() e qui la si chiama. Si applica a ENTRAMBI gli orari del foglio: il
    // difetto segnalato dal titolare il 25/11/2026 era nato proprio da una riga che normalizzava
    // `inizio_gara` e dalla vicina che non normalizzava `appuntamento`.
    const formatOra = (v) => senzaSecondi(v) || '—'
    const stagioneTxt = stagione ? `${stagione}/${Number(stagione) + 1}` : ''

    async function loadImageData(url) {
      if (!url) return null
      try {
        const res = await fetch(url)
        if (!res.ok) return null
        const blob = await res.blob()
        const dataUrl = await new Promise((resolve, reject) => {
          const reader = new FileReader()
          reader.onload = () => resolve(reader.result)
          reader.onerror = reject
          reader.readAsDataURL(blob)
        })
        const img = new Image()
        img.src = dataUrl
        await img.decode()
        const canvas = document.createElement('canvas')
        const max = 256
        const scale = Math.min(max / img.width, max / img.height, 1)
        canvas.width = Math.max(1, Math.floor(img.width * scale))
        canvas.height = Math.max(1, Math.floor(img.height * scale))
        const ctx = canvas.getContext('2d')
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
        return canvas.toDataURL('image/png')
      } catch {
        return null
      }
    }

    function addLogo(data, x, y, box) {
      if (!data) return
      try {
        const props = doc.getImageProperties(data)
        const scale = Math.min(box / props.width, box / props.height)
        const w = props.width * scale
        const h = props.height * scale
        doc.addImage(data, 'PNG', x + (box - w) / 2, y + (box - h) / 2, w, h)
      } catch {}
    }

    const logoData = await loadImageData(societa?.logo ? getUploadUrl(societa.logo) : null)
    const sponsorData = await loadImageData(societa?.logosponsor ? getUploadUrl(societa.logosponsor) : null)

    let y = margin
    const logoBox = multiGare ? 14 : 18
    if (logoData) addLogo(logoData, margin, y, logoBox)
    if (sponsorData) addLogo(sponsorData, pageWidth - margin - logoBox, y, logoBox)
    const textX = logoData ? margin + logoBox + 4 : margin

    doc.setFont('helvetica', 'bold')
    doc.setFontSize(multiGare ? 15 : 17)
    doc.setTextColor(...dark)
    const societyMaxWidth = pageWidth - margin - textX - (sponsorData ? logoBox + 4 : 0)
    const societyName = doc.splitTextToSize(societa?.nome || 'SQUADRA', societyMaxWidth)[0] || 'SQUADRA'
    doc.text(societyName, textX, y + (multiGare ? 5 : 6))

    doc.setFontSize(multiGare ? 8 : 8.5)
    doc.setTextColor(...accent)
    doc.text('CONVOCAZIONE GARE', textX, y + (multiGare ? 9 : 11))

    doc.setFont('helvetica', 'normal')
    doc.setFontSize(multiGare ? 10 : 11)
    doc.setTextColor(...dark)
    doc.text(`${categoria?.nome || ''} ${categoria?.anno || ''}`.trim(), textX, y + (multiGare ? 14 : 17))

    y += logoBox + (multiGare ? 3 : 5)
    doc.setDrawColor(...accent)
    doc.setLineWidth(0.6)
    doc.line(margin, y, pageWidth - margin, y)
    y += multiGare ? 4 : 6

    function buildRows(gara) {
      const list = (gara.giocatori || [])
        .filter(Boolean)
        .map(pid => {
          const p = getPersona(pid)
          const cognome = (p?.cognome || '—').trim()
          const nome = (p?.nome || '').trim()
          const full = nome ? `${cognome} ${nome}` : cognome
          return { pid, cognome, nome, full }
        })
      list.sort((a, b) => a.cognome.localeCompare(b.cognome, 'it', { sensitivity: 'base' }) || a.nome.localeCompare(b.nome, 'it', { sensitivity: 'base' }))
      return list.map((item, idx) => [String(idx + 1), item.full])
    }

    function renderInfoAbove(gara, x, width, startY, compact = false) {
      if (compact) {
        const ultra = width < 75
        doc.autoTable({
          startY,
          margin: { left: x, right: pageWidth - (x + width), bottom: bottomMargin },
          tableWidth: width,
          body: [
            ['Data / Inizio', `${formatD(gara.data)}${gara.inizio_gara ? ' · ' + senzaSecondi(gara.inizio_gara) : ''}`],
            ['Campo', gara.campo || '—'],
            ['Indirizzo', gara.indirizzo || '—'],
            ['Appuntamento', formatOra(gara.appuntamento)],
            ['Allenatore', etichettaAllenatori(gara) || '—']
          ],
          theme: 'grid',
          styles: { font: 'helvetica', fontSize: ultra ? 6 : 6.3, cellPadding: ultra ? 0.5 : 0.6, lineColor: line, lineWidth: 0.15, textColor: dark },
          columnStyles: {
            0: { cellWidth: ultra ? 16 : 18, fontStyle: 'bold', fillColor: light, textColor: gray },
            1: { cellWidth: 'auto' }
          },
          pageBreak: 'avoid'
        })
        return doc.lastAutoTable.finalY + 2
      }
      doc.autoTable({
        startY,
        margin: { left: x, right: pageWidth - (x + width), bottom: bottomMargin },
        tableWidth: width,
        body: [
          ['Data', formatD(gara.data), 'Campo', gara.campo || '—'],
          ['Indirizzo', gara.indirizzo || '—', 'Appuntamento', formatOra(gara.appuntamento)],
          ['Inizio gara', formatOra(gara.inizio_gara), 'Allenatore', etichettaAllenatori(gara) || '—']
        ],
        theme: 'grid',
        styles: { font: 'helvetica', fontSize: 8, cellPadding: 1.5, lineColor: line, lineWidth: 0.15, textColor: dark },
        columnStyles: {
          0: { cellWidth: 24, fontStyle: 'bold', fillColor: light, textColor: gray },
          1: { cellWidth: width / 2 - 24 },
          2: { cellWidth: 22, fontStyle: 'bold', fillColor: light, textColor: gray },
          3: { cellWidth: width / 2 - 22 }
        },
        pageBreak: 'avoid'
      })
      return doc.lastAutoTable.finalY + 3
    }

    function chooseSinglePlayerLayout(rowsCount, startY) {
      const available = Math.max(20, pageHeight - bottomMargin - startY)
      const presets = [
        { maxRows: 10, fontSize: 8.0, cellPadding: 0.8, rowHeight: 4.8 },
        { maxRows: 15, fontSize: 7.5, cellPadding: 0.6, rowHeight: 4.1 },
        { maxRows: 18, fontSize: 7.0, cellPadding: 0.5, rowHeight: 3.6 },
        { maxRows: 22, fontSize: 6.5, cellPadding: 0.45, rowHeight: 3.3 }
      ]
      return presets.find(p => rowsCount <= p.maxRows && (rowsCount + 1) * p.rowHeight <= available)
        || presets.find(p => (rowsCount + 1) * p.rowHeight <= available)
        || presets[presets.length - 1]
    }

    function chooseMultiPlayerLayout(rowsCount, width, startY) {
      const available = Math.max(20, pageHeight - bottomMargin - startY)
      const maxCols = width >= 140 ? 3 : 2
      const presets = [
        { columns: 2, fontSize: 7.5, cellPadding: 0.8, rowHeight: 4.8 },
        { columns: 2, fontSize: 7, cellPadding: 0.6, rowHeight: 4.5 },
        { columns: 2, fontSize: 6.5, cellPadding: 0.5, rowHeight: 4.2 },
        { columns: maxCols, fontSize: 6.5, cellPadding: 0.5, rowHeight: 4.2 }
      ]
      if (width < 75) {
        presets.forEach(p => {
          p.fontSize = Math.min(p.fontSize, 6.8)
          p.cellPadding = Math.min(p.cellPadding, 0.5)
        })
      }
      for (const preset of presets) {
        const rowsPerCol = Math.ceil(rowsCount / preset.columns)
        if ((rowsPerCol + 1) * preset.rowHeight <= available) return preset
      }
      return presets[presets.length - 1]
    }

    function renderPlayerTable(gara, x, width, startY, forceSingle = false) {
      const rows = buildRows(gara)
      const available = Math.max(20, pageHeight - bottomMargin - startY)
      const fitsSingle = (rows.length + 1) * 3.3 <= available
      const preferSingle = rows.length <= 20 && fitsSingle

      if (forceSingle || preferSingle || width < 50) {
        const layout = chooseSinglePlayerLayout(rows.length, startY)
        const fontSize = width < 75 ? Math.min(layout.fontSize, 7.2) : layout.fontSize
        const cellPadding = width < 75 ? Math.min(layout.cellPadding, 0.55) : layout.cellPadding
        const numWidth = width < 75 ? 4.5 : 5.0

        doc.autoTable({
          startY,
          margin: { left: x, right: pageWidth - (x + width), bottom: bottomMargin },
          tableWidth: width,
          head: [['#', 'Cognome Nome']],
          body: rows.length ? rows : [['—', 'Nessun giocatore selezionato']],
          theme: 'grid',
          headStyles: { fillColor: dark, textColor: [255, 255, 255], font: 'helvetica', fontSize, cellPadding },
          styles: { font: 'helvetica', fontSize, cellPadding, lineColor: line, lineWidth: 0.15, textColor: dark },
          columnStyles: {
            0: { cellWidth: numWidth, halign: 'center', fontStyle: 'bold', textColor: gray, cellPadding: { top: cellPadding, bottom: cellPadding, left: 0.2, right: 0.2 } },
            1: { cellWidth: 'auto', cellPadding: { top: cellPadding, bottom: cellPadding, left: 1.0, right: 1.0 } }
          },
          pageBreak: 'avoid'
        })
        return doc.lastAutoTable.finalY
      }

      const multiLayout = chooseMultiPlayerLayout(rows.length, width, startY)
      const colCount = multiLayout.columns
      const per = Math.ceil(rows.length / colCount)
      const chunks = Array.from({ length: colCount }, (_, i) => rows.slice(i * per, (i + 1) * per))
      const maxRows = Math.max(...chunks.map(c => c.length), 1)
      const body = Array.from({ length: maxRows }, (_, r) => {
        const line = []
        chunks.forEach(chunk => {
          const row = chunk[r] || ['', '']
          line.push(...row)
        })
        return line
      })
      const head = Array.from({ length: colCount }, () => ['#', 'Cognome Nome']).flat()
      const groupWidth = width / colCount
      const numWidth = width < 75 ? 4.0 : 4.5
      const nameWidth = groupWidth - numWidth
      const columnStyles = {}
      for (let c = 0; c < colCount; c++) {
        columnStyles[c * 2] = { cellWidth: numWidth, halign: 'center', fontStyle: 'bold', textColor: gray, cellPadding: { top: multiLayout.cellPadding, bottom: multiLayout.cellPadding, left: 0.2, right: 0.2 } }
        columnStyles[c * 2 + 1] = { cellWidth: nameWidth, cellPadding: { top: multiLayout.cellPadding, bottom: multiLayout.cellPadding, left: 0.8, right: 0.8 } }
      }

      doc.autoTable({
        startY,
        margin: { left: x, right: pageWidth - (x + width), bottom: bottomMargin },
        tableWidth: width,
        head: [head],
        body,
        theme: 'grid',
        headStyles: { fillColor: dark, textColor: [255, 255, 255], font: 'helvetica', fontSize: multiLayout.fontSize, cellPadding: multiLayout.cellPadding },
        styles: { font: 'helvetica', fontSize: multiLayout.fontSize, cellPadding: multiLayout.cellPadding, lineColor: line, lineWidth: 0.15, textColor: dark },
        columnStyles,
        pageBreak: 'avoid'
      })
      return doc.lastAutoTable.finalY
    }

    function renderGaraColumn(gara, x, width, startY, compact = false) {
      const ultra = compact && width < 75
      const titleHeight = compact ? 5 : 6
      const titleFont = ultra ? 9.5 : compact ? 10.5 : 12
      doc.setFillColor(...accent)
      doc.rect(x, startY, 2, titleHeight, 'F')
      if (gara.gara) {
        doc.setFont('helvetica', 'bold')
        doc.setFontSize(titleFont)
        doc.setTextColor(...dark)
        const garaTitle = doc.splitTextToSize(gara.gara, width - 7)[0] || ''
        doc.text(garaTitle, x + 4, startY + (compact ? 3.8 : 4.5))
      }
      let colY = startY + (compact ? 6.5 : 8)
      colY = renderInfoAbove(gara, x, width, colY, compact)
      colY = renderPlayerTable(gara, x, width, colY)
      return colY
    }

    if (!multiGare) {
      const gara = gareList[0]
      if (gara) {
        doc.setFillColor(...accent)
        doc.rect(margin, y, 2.5, 6, 'F')
        if (gara.gara) {
          doc.setFont('helvetica', 'bold')
          doc.setFontSize(12)
          doc.setTextColor(...dark)
          const garaTitle = doc.splitTextToSize(gara.gara, pageWidth - margin - (margin + 5))[0] || ''
          doc.text(garaTitle, margin + 5, y + 4.5)
        }
        y += 10

        const infoRows = [
          ['Data', formatD(gara.data)],
          ['Campo', gara.campo || '—'],
          ['Indirizzo', gara.indirizzo || '—'],
          ['Appuntamento', formatOra(gara.appuntamento)],
          ['Inizio gara', formatOra(gara.inizio_gara)],
          ['Allenatore', etichettaAllenatori(gara) || '—']
        ]
        const startY = y

        if (useLandscape) {
          const infoWidth = 85
          const gap = 6
          const playerX = margin + infoWidth + gap
          const playerWidth = pageWidth - margin - playerX

          doc.autoTable({
            startY,
            margin: { left: margin, right: pageWidth - (margin + infoWidth), bottom: bottomMargin },
            tableWidth: infoWidth,
            head: [[{ content: 'INFO GARA', colSpan: 2 }]],
            body: infoRows,
            theme: 'grid',
            headStyles: { fillColor: dark, textColor: [255, 255, 255], font: 'helvetica', fontSize: 9, cellPadding: 2.8, halign: 'left' },
            styles: { font: 'helvetica', fontSize: 8.5, cellPadding: 2.5, lineColor: line, lineWidth: 0.15, textColor: dark, valign: 'top' },
            columnStyles: {
              0: { cellWidth: 26, fontStyle: 'bold', fillColor: light, textColor: gray },
              1: { cellWidth: 'auto' }
            },
            pageBreak: 'avoid'
          })
          const infoFinalY = doc.lastAutoTable.finalY
          const playerFinalY = renderPlayerTable(gara, playerX, playerWidth, startY, false)
          y = Math.max(infoFinalY, playerFinalY) + 6
        } else {
          const leftWidth = 105
          const gap = 6
          const rightX = margin + leftWidth + gap
          const rightWidth = pageWidth - margin - rightX

          const leftFinalY = renderPlayerTable(gara, margin, leftWidth, startY, true)

          doc.autoTable({
            startY,
            margin: { left: rightX, right: margin, bottom: bottomMargin },
            tableWidth: rightWidth,
            head: [[{ content: 'INFO GARA', colSpan: 2 }]],
            body: infoRows,
            theme: 'grid',
            headStyles: { fillColor: dark, textColor: [255, 255, 255], font: 'helvetica', fontSize: 9, cellPadding: 2.8, halign: 'left' },
            styles: { font: 'helvetica', fontSize: 8.5, cellPadding: 2.5, lineColor: line, lineWidth: 0.15, textColor: dark, valign: 'top' },
            columnStyles: {
              0: { cellWidth: 26, fontStyle: 'bold', fillColor: light, textColor: gray },
              1: { cellWidth: 'auto' }
            },
            pageBreak: 'avoid'
          })
          const rightFinalY = doc.lastAutoTable.finalY

          y = Math.max(leftFinalY, rightFinalY) + 9
        }
      }
    } else {
      const n = convocazione.gare.length
      const gap = n >= 4 ? 6 : 8
      const maxPlayers = Math.max(0, ...convocazione.gare.map(g => (g.giocatori || []).filter(Boolean).length))
      const singlePageMax = { 2: 99, 3: 30, 4: 24 }
      const maxPerRow = (n <= 4 && maxPlayers <= (singlePageMax[n] || 99)) ? n : 2
      let rowStart = 0
      let firstRow = true
      while (rowStart < n) {
        const count = Math.min(maxPerRow, n - rowStart)
        const colWidth = (contentWidth - gap * (count - 1)) / count
        const compact = colWidth < 100
        if (!firstRow) {
          doc.addPage()
          y = margin
        }
        firstRow = false
        const startY = y
        let finalY = margin
        for (let j = 0; j < count; j++) {
          const colX = margin + j * (colWidth + gap)
          finalY = Math.max(finalY, renderGaraColumn(convocazione.gare[rowStart + j], colX, colWidth, startY, compact))
        }
        y = finalY + 6
        rowStart += count
      }
    }

    if (noteText) {
      const targetY = Math.max(margin, pageHeight - noteHeight - 16)
      if (multiGare && y + 4 > targetY) {
        doc.addPage()
      }
      y = Math.max(y + 3, targetY)
      doc.setFillColor(...light)
      doc.setDrawColor(...line)
      doc.setLineWidth(0.15)
      doc.roundedRect(margin, y, contentWidth, noteHeight, 1.5, 1.5, 'FD')
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(7.5)
      doc.setTextColor(...accent)
      doc.text('NOTE', margin + 4, y + 5)
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(noteFontSize)
      doc.setTextColor(...dark)
      doc.text(noteLines, margin + 4, y + 10, { maxLineSpacing: noteLineHeight })
    }

    const pageCount = doc.getNumberOfPages()
    for (let i = 1; i <= pageCount; i++) {
      doc.setPage(i)
      doc.setDrawColor(...line)
      doc.setLineWidth(0.15)
      doc.line(margin, pageHeight - 11, pageWidth - margin, pageHeight - 11)
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(7.5)
      doc.setTextColor(148, 163, 184)
      doc.text(`${societa?.nome || ''}${stagioneTxt ? ' · Stagione ' + stagioneTxt : ''}`, margin, pageHeight - 7)
      doc.text(`Pagina ${i} di ${pageCount}`, pageWidth - margin, pageHeight - 7, { align: 'right' })
    }

    // Il nome del file segue lo schema del weekend di default. Il chiamante di un'altra pagina puo'
    // passarne uno proprio: tre fogli dello stesso torneo che si chiamano tutti
    // Convocazioni_Pulcini_2026-12-19.pdf non dicono quale e' di quale gara, e il secondo finisce
    // accanto al primo nella cartella download con un (1) appeso.
    const categoriaNome = (categoria?.nome || 'Categoria').replace(/[/\\?%*:|"<>]/g, '_')
    const dataInizio = convocazione.data_inizio || ''
    const dataFine = convocazione.data_fine || ''
    const dataFormattata = dataInizio ? dataInizio.split('-').reverse().join('-') : 'data'
    const dataFinale = dataFine ? dataFormattata + '_' + dataFine.split('-').reverse().join('-') : dataFormattata
    const nome = nomeFile || `Convocazioni_${categoriaNome}_${dataFinale}.pdf`
    const titolo = titoloDownload || `Convocazioni ${categoria?.nome || ''}`.trim()
    // Il bivio e' qui e soltanto qui: `doc` e' lo stesso oggetto, quindi l'immagine esce dai byte
    // stessi del PDF. Spostare questo if piu' in su significherebbe avere due modi di costruire il
    // foglio, e due fogli che il giorno dopo non si assomigliano piu'
    if (formato === 'jpeg') {
      await exportJpeg(doc, nome, titolo)
    } else {
      await exportPdf(doc, nome, titolo)
    }
  } catch (e) {
    const cosa = formato === 'jpeg' ? 'JPEG' : 'PDF'
    console.error(`Errore ${cosa}:`, e)
    alert(`Errore nella generazione del ${cosa}: ` + (e?.message || e))
  }
}
