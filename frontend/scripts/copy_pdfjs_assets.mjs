// Copia in `public/pdfjs/` le due cose che pdf.js carica da URL: i font standard e il worker.
//
// PERCHE' I FONT (e cosa c'e' da sapere, perche' la prima versione di questo file la diceva sbagliata)
// I nostri PDF non incorporano i font: jsPDF usa i 14 Type1 standard (Helvetica, Times, Courier &
// c.) e nel file finiscono solo i `/BaseFont`, zero `/FontFile` -- verificato generando un documento
// con la libreria stessa. Sembra ne segua che pdf.js DEVE prendere glifi e metriche da
// `standardFontDataUrl`, e che senza quella cartella il testo esca storto. **Misurato: no.** Con l'URL
// dei font rotto le quattro JPEG del test sono venute fuori byte-identiche all'originale, e nginx non
// ha visto nemmeno una richiesta a `pdfjs/standard_fonts/`: pdf.js 5.4 rende i 14 font standard col
// suo percorso di riserva, senza chiedere niente al server.
//
// Quindi i 762 KB qui sotto sono, allo stato, un'assicurazione che oggi nessuno incassa. Si tengono
// per due motivi: se un documento usera' glifi che la riserva non copre, il posto dove prenderli deve
// essere gia' li' (in APK un CDN non e' un'opzione), e perche' toglierli non cambierebbe niente su
// nessun documento che il test copre -- quindi non e' una decisione urgente, e' una decisione di peso
// dell'APK da prendere sapendo il numero vero. Se si tolgono, togliere anche l'opzione in jpegDaPdf.js.
//
// PERCHE' NEL BUNDLE E NON DA UN CDN
// L'APK carica gli asset da https://localhost e deve funzionare anche senza rete; un CDN in un'app
// che gira in un WebView e' un pulsante che dipende da cosa risponde internet.
//
// PERCHE' IL WORKER VIENE RINOMINATO .js (e non e' un vezzo)
// pdf.js lo carica con `new Worker(url, {type:"module"})`. Chrome rifiuta di eseguire un modulo il
// cui server risponde con un MIME che non e' JavaScript, e qui il rifiuto e' sicuro per due motivi
// che si sommano: `nginx.conf` dichiara JavaScript solo per `\.(js|css)$` (`.mjs` cadrebbe nel
// fallback SPA) e c'e' `X-Content-Type-Options: nosniff` attivo, che toglie anche l'indulgenza.
// Il file originale e' `pdf.worker.min.mjs`; copiato come `.js` e servito come application/javascript
// da nginx E da Capacitor (che `.mjs` lo conosce, ma non serve contarsi una differenza fra web e
// APK per un'estensione). Il contenuto non cambia: resta un modulo ES, e `type:"module"` e' il
// MIME a decidere, non il suffisso.
//
// Il fallimento e' rumoroso di proposito: se manca qualcosa, il build si ferma. Un build che passa e
// sforna un pulsante JPEG il cui testo esce storto, o che non produce niente senza dire perche', e'
// la stessa classe di difetto del "container frontend mai creato" di `npm ci`: sembra a posto.
import { existsSync, mkdirSync, readdirSync, copyFileSync, statSync, rmSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const QUI = dirname(fileURLToPath(import.meta.url))
const FRONTEND = resolve(QUI, '..')
const PKG = join(FRONTEND, 'node_modules', 'pdfjs-dist')
const FONT_SORGENTE = join(PKG, 'standard_fonts')
const WORKER_SORGENTE = join(PKG, 'build', 'pdf.worker.min.mjs')
const DESTINAZIONE = join(FRONTEND, 'public', 'pdfjs')

function copia(src, dst, cosa) {
  copyFileSync(src, dst)
  // Copia verificata sulla misura: un file troncato a meta' e' un glifo mancante, o un worker che
  // non parte, e in entrambi i casi il sintomo arriva lontano dal difetto
  const prima = statSync(src).size
  const dopo = statSync(dst).size
  if (prima !== dopo) {
    console.error(`ERRORE: copia troncata su ${cosa}: ${prima} byte attesi, ${dopo} scritti (${src}).`)
    process.exit(1)
  }
  return dopo
}

for (const [percorso, cosa] of [[FONT_SORGENTE, 'cartella standard_fonts di pdf.js'],
                               [WORKER_SORGENTE, 'worker di pdf.js']]) {
  if (!existsSync(percorso)) {
    console.error(
      `ERRORE: ${cosa} non trovata in ${percorso}\n` +
      'Senza di essa "Esporta JPEG" non puo' + (percorso === FONT_SORGENTE
        ? ' rendere i font Helvetica/Times/Courier che i nostri PDF non incorporano, e il testo\n' +
          '  uscirebbe storto o assente.'
        : ' creare il worker, e l\'export non partirebbe.') +
      '\nVerifica che "pdfjs-dist" sia tra le dipendenze e che "npm ci" sia andato a buon fine.'
    )
    process.exit(1)
  }
}

// Si riparte da zero ogni volta: un font o un worker rimasti da una versione vecchia di pdf.js
// resterebbero serviti accanto a una libreria nuova, e pdf.js rifiuta worker di versione diversa
// dicendo solo "The API and Worker versions do not match"
rmSync(DESTINAZIONE, { recursive: true, force: true })
mkdirSync(join(DESTINAZIONE, 'standard_fonts'), { recursive: true })

let byteFont = 0
let nFont = 0
for (const f of readdirSync(FONT_SORGENTE)) {
  const src = join(FONT_SORGENTE, f)
  if (!statSync(src).isFile()) continue
  byteFont += copia(src, join(DESTINAZIONE, 'standard_fonts', f), `font ${f}`)
  nFont++
}
if (nFont === 0) {
  console.error(`ERRORE: ${FONT_SORGENTE} esiste ma e' vuota: niente font da copiare.`)
  process.exit(1)
}

const byteWorker = copia(WORKER_SORGENTE, join(DESTINAZIONE, 'pdf.worker.min.js'), 'worker')

console.log(`asset pdf.js -> public/pdfjs/: ${nFont} font (${(byteFont / 1024).toFixed(0)} KB) ` +
            `+ worker come .js (${(byteWorker / 1024).toFixed(0)} KB)`)
