import { Capacitor } from '@capacitor/core'
import { Filesystem, Directory } from '@capacitor/filesystem'
import { Share } from '@capacitor/share'
import { jpegDaPdf } from './jpegDaPdf.js'

/**
 * Pulisce il nome file eliminando caratteri illegali nei filesystem (/ \ ? % * : | " < >).
 */
export function sanitizeFilename(name, defaultExt = '.pdf') {
  if (!name) return `documento${defaultExt}`
  let clean = String(name)
    .replace(/[/\\?%*:|"<>]/g, '_')
    .replace(/\s+/g, ' ')
    .trim()
  if (defaultExt && !clean.toLowerCase().endsWith(defaultExt.toLowerCase())) {
    clean += defaultExt
  }
  return clean
}

/**
 * Salva o condivide un documento jsPDF.
 * - Su Web (desktop / browser): doc.save(filename)
 * - Su Mobile (Capacitor nativo): salva in cache locale e apre il menu nativo di condivisione
 *   (WhatsApp, Salva su File, Drive, Stampa, ecc.).
 */
export async function saveOrSharePdf(doc, filename, title = '') {
  const safeFilename = sanitizeFilename(filename, '.pdf')

  if (Capacitor.isNativePlatform()) {
    try {
      const dataUri = doc.output('datauristring')
      const base64Data = dataUri.split(',')[1]

      const fileResult = await Filesystem.writeFile({
        path: safeFilename,
        data: base64Data,
        directory: Directory.Cache
      })

      // Ottieni l'URI esatto risolto dal Filesystem nativo
      let shareUri = fileResult?.uri
      try {
        const uriResult = await Filesystem.getUri({
          directory: Directory.Cache,
          path: safeFilename
        })
        if (uriResult?.uri) {
          shareUri = uriResult.uri
        }
      } catch (uriErr) {
        console.warn('Filesystem.getUri fallback a fileResult.uri:', uriErr)
      }

      await Share.share({
        title: title || safeFilename,
        url: shareUri,
        dialogTitle: 'Condividi o Salva PDF'
      })
      return true
    } catch (err) {
      const msg = String(err?.message || err || '').toLowerCase()
      if (msg.includes('cancel') || msg.includes('annullat')) {
        return false
      }
      console.error('Errore export PDF nativo:', err)

      // Fallback: prova download browser se supportato dalla webview
      try {
        doc.save(safeFilename)
        return true
      } catch (fallbackErr) {
        console.error('Fallback doc.save fallito:', fallbackErr)
        throw err
      }
    }
  } else {
    doc.save(safeFilename)
    return true
  }
}

/**
 * Converte un data: URL in Blob senza passare da fetch(). Con un `connect-src` restrittivo e un
 * data: URL da qualche centinaio di KB, fetch e' il modo piu' semplice per un fallimento
 * silenzioso; qui i byte ce li abbiamo gia' in mano.
 */
function dataUrlABlob(dataUrl) {
  const virgola = dataUrl.indexOf(',')
  const meta = dataUrl.slice(0, virgola)
  const b64 = dataUrl.slice(virgola + 1)
  const mime = (meta.match(/^data:([^;,]+)/) || [])[1] || 'image/jpeg'
  const binario = atob(b64)
  const byte = new Uint8Array(binario.length)
  for (let i = 0; i < binario.length; i++) byte[i] = binario.charCodeAt(i)
  return new Blob([byte], { type: mime })
}

function scaricaBlob(blob, filename) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

/**
 * Salva o condivide **l'immagine JPEG del documento**, non una sua reinterpretazione: la
 * rasterizzazione parte dai byte del PDF (vedi core/utils/jpegDaPdf.js), quindi tutto cio' che
 * uscirebbe nel PDF esce nell'immagine, pagine comprese.
 *
 * Perche' esiste accanto al PDF e non al suo posto: il PDF resta il file giusto per stampare, la
 * JPEG e' quella giusta per WhatsApp -- si apre da sola, non serve un'app che legga i PDF.
 *
 * - Su Web (desktop / browser): download tramite <a> e blob URL
 * - Su Mobile (Capacitor nativo): salva in cache e apre il menu nativo di condivisione
 *
 * Il nome file e' QUELLO del PDF con .jpg: due export dello stesso foglio che si chiamano in due
 * modi diversi fanno chiedere quale dei due sia quello giusto. Il `.pdf` viene tolto e sostituito,
 * non aggiunto sopra (altrimenti `Convocazioni_Pulcini.pdf.jpg`).
 */
export async function saveOrShareJpeg(doc, filename, title = '', opts = {}) {
  const senzaEstensione = String(filename || '').replace(/\.(pdf|jpe?g|png)$/i, '')
  const safeFilename = sanitizeFilename(senzaEstensione, '.jpg')

  const { dataUrl } = await jpegDaPdf(doc, opts)

  if (Capacitor.isNativePlatform()) {
    try {
      const base64Data = dataUrl.slice(dataUrl.indexOf(',') + 1)

      const fileResult = await Filesystem.writeFile({
        path: safeFilename,
        data: base64Data,
        directory: Directory.Cache
      })

      let shareUri = fileResult?.uri
      try {
        const uriResult = await Filesystem.getUri({
          directory: Directory.Cache,
          path: safeFilename
        })
        if (uriResult?.uri) {
          shareUri = uriResult.uri
        }
      } catch (uriErr) {
        console.warn('Filesystem.getUri fallback a fileResult.uri:', uriErr)
      }

      await Share.share({
        title: title || safeFilename,
        url: shareUri,
        dialogTitle: 'Condividi o Salva immagine'
      })
      return true
    } catch (err) {
      const msg = String(err?.message || err || '').toLowerCase()
      if (msg.includes('cancel') || msg.includes('annullat')) {
        return false
      }
      console.error('Errore export JPEG nativo:', err)

      // Fallback come per il PDF: se il plugin nativo non risponde l'immagine non e' persa, si scarica
      try {
        scaricaBlob(dataUrlABlob(dataUrl), safeFilename)
        return true
      } catch (fallbackErr) {
        console.error('Fallback download JPEG fallito:', fallbackErr)
        throw err
      }
    }
  }

  scaricaBlob(dataUrlABlob(dataUrl), safeFilename)
  return true
}

/**
 * Salva o condivide un file di testo (es. CSV).
 * - Su Web: download tramite <a> e blob URL
 * - Su Mobile (Capacitor nativo): salva in cache e apre il menu di condivisione nativo
 */
export async function saveOrShareText(content, filename, mimeType = 'text/csv;charset=utf-8;', title = '') {
  const safeFilename = sanitizeFilename(filename, '')

  if (Capacitor.isNativePlatform()) {
    try {
      const utf8Bytes = new TextEncoder().encode(content)
      let binary = ''
      for (let i = 0; i < utf8Bytes.length; i++) {
        binary += String.fromCharCode(utf8Bytes[i])
      }
      const base64Data = btoa(binary)

      const fileResult = await Filesystem.writeFile({
        path: safeFilename,
        data: base64Data,
        directory: Directory.Cache
      })

      let shareUri = fileResult?.uri
      try {
        const uriResult = await Filesystem.getUri({
          directory: Directory.Cache,
          path: safeFilename
        })
        if (uriResult?.uri) {
          shareUri = uriResult.uri
        }
      } catch (uriErr) {
        console.warn('Filesystem.getUri fallback a fileResult.uri:', uriErr)
      }

      await Share.share({
        title: title || safeFilename,
        url: shareUri,
        dialogTitle: 'Condividi o Salva File'
      })
      return true
    } catch (err) {
      const msg = String(err?.message || err || '').toLowerCase()
      if (msg.includes('cancel') || msg.includes('annullat')) {
        return false
      }
      console.error('Errore export file nativo:', err)
      throw err
    }
  } else {
    const blob = new Blob([content], { type: mimeType })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = safeFilename
    a.click()
    URL.revokeObjectURL(url)
    return true
  }
}

// Alias retrocompatibili
export const exportPdf = saveOrSharePdf
export const exportTextFile = saveOrShareText
export const exportJpeg = saveOrShareJpeg
