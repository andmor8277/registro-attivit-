import { Capacitor } from '@capacitor/core'
import { Filesystem, Directory } from '@capacitor/filesystem'
import { Share } from '@capacitor/share'

/**
 * Salva o condivide un documento jsPDF.
 * - Su Web (desktop / browser): doc.save(filename)
 * - Su Mobile (Capacitor nativo): salva in cache locale e apre il menu nativo di condivisione
 *   (WhatsApp, Salva su File, Drive, Stampa, ecc.).
 */
export async function saveOrSharePdf(doc, filename, title = '') {
  if (Capacitor.isNativePlatform()) {
    try {
      const dataUri = doc.output('datauristring')
      const base64Data = dataUri.split(',')[1]

      const fileResult = await Filesystem.writeFile({
        path: filename,
        data: base64Data,
        directory: Directory.Cache
      })

      await Share.share({
        title: title || filename,
        text: title || filename,
        url: fileResult.uri,
        dialogTitle: 'Condividi o Salva PDF'
      })
      return true
    } catch (err) {
      if (err?.message?.includes('canceled') || err?.message?.includes('cancelled')) {
        return false
      }
      console.error('Errore export PDF nativo:', err)
      throw err
    }
  } else {
    doc.save(filename)
    return true
  }
}

/**
 * Salva o condivide un file di testo (es. CSV).
 * - Su Web: download tramite <a> e blob URL
 * - Su Mobile (Capacitor nativo): salva in cache e apre il menu di condivisione nativo
 */
export async function saveOrShareText(content, filename, mimeType = 'text/csv;charset=utf-8;', title = '') {
  if (Capacitor.isNativePlatform()) {
    try {
      const utf8Bytes = new TextEncoder().encode(content)
      let binary = ''
      for (let i = 0; i < utf8Bytes.length; i++) {
        binary += String.fromCharCode(utf8Bytes[i])
      }
      const base64Data = btoa(binary)

      const fileResult = await Filesystem.writeFile({
        path: filename,
        data: base64Data,
        directory: Directory.Cache
      })

      await Share.share({
        title: title || filename,
        text: title || filename,
        url: fileResult.uri,
        dialogTitle: 'Condividi o Salva File'
      })
      return true
    } catch (err) {
      if (err?.message?.includes('canceled') || err?.message?.includes('cancelled')) {
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
    a.download = filename
    a.click()
    URL.revokeObjectURL(url)
    return true
  }
}

// Alias retrocompatibili
export const exportPdf = saveOrSharePdf
export const exportTextFile = saveOrShareText
