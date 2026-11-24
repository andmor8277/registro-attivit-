// Copia in `public/pdfjs/` il worker, che pdf.js carica da URL.
//
// QUESTO FILE UNA VOLTA COPIAVA ANCHE I FONT (762 KB, 16 file). Tolti il 24/11/2026 su decisione del
// titolare, perche' erano peso senza contropartita. La misura, che va raccontata perche' e' il motivo
// per cui NON vanno rimessi "per sicurezza":
//   i nostri PDF non incorporano font -- jsPDF usa i 14 Type1 standard (Helvetica, Times, Courier & c.)
//   e nel file finiscono solo i `/BaseFont`, zero `/FontFile` (verificato generando un documento con la
//   libreria stessa). Ne sembrava seguire che chi rasterizza il PDF (pdf.js, vedi
//   src/core/utils/jpegDaPdf.js) dovesse prendere glifi e metriche da `standardFontDataUrl`, e che senza
//   quella cartella il testo uscisse storto. **Non e' cosi'**: rompendo quell'URL (mutazione del negative
//   test) le quattro JPEG sono venute fuori byte-identiche all'originale, il testo a schermo era
//   perfettamente leggibile, e nel log di nginx non compare nemmeno una richiesta a
//   `pdfjs/standard_fonts/`. pdf.js 5.4 rende i 14 standard col suo percorso di riserva.
//   Conseguenza sul negative test: non esiste una mutazione sui font, perche' non esiste asserzione che
//   quel difetto veda (le soglie d'inchiostro sono dominate da righe di tabella e barre, che sono
//   vettori jsPDF e non dipendono dai font). E' la mutazione tolta, documentata in
//   scripts/test/negative_export_jpeg.sh.
//   SE UN GIORNO SERVISSERO davvero (un documento con glifi che la riserva non copre): rimettere
//   `standardFontDataUrl` in jpegDaPdf.js E copiare qui `node_modules/pdfjs-dist/standard_fonts`. Il
//   perche' nel bundle e non da un CDN resta valido: l'APK carica gli asset da https://localhost e deve
//   funzionare anche senza rete, e un CDN in un WebView e' un pulsante che dipende da cosa risponde
//   internet.
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
// sforna un pulsante JPEG che non produce niente senza dire perche' e' la stessa classe di difetto del
// "container frontend mai creato" di `npm ci`: sembra a posto.
import { existsSync, mkdirSync, copyFileSync, statSync, rmSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const QUI = dirname(fileURLToPath(import.meta.url))
const FRONTEND = resolve(QUI, '..')
const PKG = join(FRONTEND, 'node_modules', 'pdfjs-dist')
const WORKER_SORGENTE = join(PKG, 'build', 'pdf.worker.min.mjs')
const DESTINAZIONE = join(FRONTEND, 'public', 'pdfjs')

if (!existsSync(WORKER_SORGENTE)) {
  console.error(
    `ERRORE: il worker di pdf.js non trovato in ${WORKER_SORGENTE}\n` +
    'Senza di esso "Esporta JPEG" non puo' + ' creare il worker, e l\'export non partirebbe.\n' +
    'Verifica che "pdfjs-dist" sia tra le dipendenze e che "npm ci" sia andato a buon fine.'
  )
  process.exit(1)
}

// Si riparte da zero ogni volta: un worker rimasto da una versione vecchia di pdf.js verrebbe servito
// accanto a una libreria nuova, e pdf.js rifiuta worker di versione diversa dicendo solo
// "The API and Worker versions do not match"
rmSync(DESTINAZIONE, { recursive: true, force: true })
mkdirSync(DESTINAZIONE, { recursive: true })

copyFileSync(WORKER_SORGENTE, join(DESTINAZIONE, 'pdf.worker.min.js'))
// Copia verificata sulla misura: un worker troncato a meta' e' un export che non parte, e il sintomo
// arriva lontano dal difetto
const attesi = statSync(WORKER_SORGENTE).size
const scritti = statSync(join(DESTINAZIONE, 'pdf.worker.min.js')).size
if (attesi !== scritti) {
  console.error(
    `ERRORE: copia troncata sul worker: ${attesi} byte attesi, ${scritti} scritti (${WORKER_SORGENTE}).`
  )
  process.exit(1)
}

console.log(`asset pdf.js -> public/pdfjs/: worker come .js (${(scritti / 1024).toFixed(0)} KB)`)
