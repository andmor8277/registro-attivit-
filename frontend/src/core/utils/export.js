import { Capacitor } from '@capacitor/core'
import { Filesystem, Directory } from '@capacitor/filesystem'
import { Share } from '@capacitor/share'

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
