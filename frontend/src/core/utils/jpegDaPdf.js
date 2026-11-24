// Trasforma il documento jsPDF appena costruito nella SUA immagine JPEG.
//
// Perche' esiste: quei fogli partono in chat (WhatsApp ai genitori, all'organizzatore), e li' una
// immagine si apre da sola mentre un PDF va scaricato e aperto. Non e' un documento alternativo:
// e' la stessa pagina vista come un quadro.
//
// La regola, e l'unica che conta qui: **quello che esce nel PDF esce nella JPEG**. Stesso numero di
// pagine, stesso ordine, stesso contenuto. La rasterizzazione parte dai byte del PDF -- gli stessi
// `doc.output()` da cui nasce il file -- e non da una seconda impaginazione. Un JPEG fatto
// fotografando il DOM avrebbe richiesto di riscrivere in CSS le barre di `barra()`, il `(DOM)` della
// `didParseCellBarra` e Casa/Trasferta della `didDrawCell`: due documenti che il giorno dopo non si
// assomigliano piu', e chi riceve l'immagine non ha modo di accorgersi quale dei due ha in mano.
// E per Convocazioni e Tornei un DOM da fotografare non esiste nemmeno: nascono da jsPDF.
//
// Le tre cose che sembrano dettagli e sono il motivo per cui questo file esiste:
//
// 1) **I font non sono nel PDF -- ma a pdf.js non servono lo stesso (misurato).** jsPDF usa i 14
//    Type1 standard (Helvetica & c.) e NON li incorpora: verificato sui nostri documenti, zero
//    `/FontFile`, solo `/BaseFont`. Sembra il vincolo che decide tutto, e infatti la prima versione
//    di questo file diceva che senza `standardFontDataUrl` il testo usciva storto. **Non e' vero per
//    i nostri documenti**: con l'URL dei font rotto le quattro JPEG del test sono venute fuori
//    BYTE-IDENTICHE, e nel log di nginx non compariva nemmeno una richiesta a
//    `pdfjs/standard_fonts/` -- pdf.js 5.4 rende i 14 standard col suo percorso di riserva. L'opzione
//    resta perche' e' quella giusta da dichiarare se un documento usera' glifi che la riserva non
//    copre; i 762 KB di `standard_fonts` nel bundle sono, oggi, assicurazione non richiesta.
//    (E' anche il motivo per cui il negative test NON ha una mutazione sui font: non c'e'
//    asserzione che quel difetto lo veda.)
//
// 2) **La JPEG non ha l'alpha.** pdf.js rende su canvas trasparente: se il composite non viene
//    riempito di bianco prima, lo sfondo diventa NERO. Il composite qui viene riempito e mai
//    cancellato (il `clearRect` di pdf.js sta nel percorso soft-mask della singola pagina, non sul
//    canvas finale), e ogni pagina viene resa con `background: '#ffffff'`.
//
// 3) **Una JPEG e' una sola immagine, i fogli possono essere piu' pagine.** Le pagine vengono
//    impilate in un unico canvas, perche' condividere due file per dire "il foglio della gara" e'
//    peggio che condividere un file lungo. Nessuna pagina viene mai saltata o rifiutata: il tetto
//    del canvas puo' toccare i DPI, mai cosa c'e' dentro.
//
// pdf.js viene importato DINAMICAMENTE, dentro la chiamata: 412 KB di chunk + il worker (1 MB) + i
// font pesano solo a chi preme il pulsante, e se un WebView vecchio non regge pdf.js si rompe il solo
// pulsante JPEG, non l'export PDF che oggi funziona.

const SCALA_DI_DEFAULT = 3
const QUALITA_DI_DEFAULT = 0.95

// Budget del canvas composite in pixel. 16 Mpx RGBA = 64 MB: sopra, un WebView di telefono rischia
// l'OOM del renderer piu' che l'illeggibilita'. E' un paracadute, di norma non si tocca: i fogli
// reali (1 pagina A4 a 3x = 4,5 Mpx) stanno lontani.
const PIXEL_MAX_COMPOSITE = 16 * 1000 * 1000

// Valore usato solo se non si riesce a misurare il limite vero del dispositivo
const LATO_DI_RISERVA = 4096

let pdfjsPromise = null
let limiteLatoMisurato = null

/**
 * Il limite reale di un lato del canvas su questo dispositivo.
 *
 * Non e' 4096 per definizione: e' il MAX_TEXTURE_SIZE del WebView, che sui telefoni recenti e'
 * spesso 8192 o 16384. Indovinare al ribasso significherebbe ridurre i DPI di documenti che
 * starebbero interi, e la consegna dice che la JPEG deve essere il PDF: quindi si misura.
 */
function limiteLatoReale() {
  if (limiteLatoMisurato) return limiteLatoMisurato
  let n = LATO_DI_RISERVA
  try {
    const c = document.createElement('canvas')
    const gl = c.getContext('webgl') || c.getContext('experimental-webgl')
    if (gl) {
      const max = gl.getParameter(gl.MAX_TEXTURE_SIZE)
      if (Number.isFinite(max) && max >= 1024) n = max
      gl.getExtension('WEBGL_lose_context')?.loseContext()
    }
  } catch (e) {
    // Nessun WebGL: si resta sul valore di riserva. Meglio conservativo che un canvas null
    console.warn('limite canvas non misurabile, uso', LATO_DI_RISERVA, e)
  }
  limiteLatoMisurato = n
  return n
}

/**
 * Carica pdf.js una volta sola. Import dinamico perche' finisca in un chunk lazy proprio: ~412 KB
 * che pesano solo a chi preme il pulsante.
 *
 * Il worker NON arriva da `?url` ma da un asset statico `.js` nel bundle (copiato da
 * frontend/scripts/copy_pdfjs_assets.mjs). Motivo: pdf.js lo crea con
 * `new Worker(url, {type:"module"})`, e Chrome rifiuta di eseguire un modulo il cui server risponde
 * con un MIME che non e' JavaScript -- qui succede, perche' nginx dichiara JavaScript solo per
 * `\.(js|css)$` e `X-Content-Type-Options: nosniff` e' attivo. Con `.js` lo servono correttamente
 * sia nginx sia il WebView di Capacitor, e fra web e APK non resta nessuna differenza.
 * Il blob-wrapper che pdf.js usa per i worker cross-origin non entra in gioco: l'URL e' same-origin.
 */
function caricaPdfjs() {
  if (!pdfjsPromise) {
    pdfjsPromise = (async () => {
      const pdfjs = await import('pdfjs-dist')
      pdfjs.GlobalWorkerOptions.workerSrc = `${import.meta.env.BASE_URL}pdfjs/pdf.worker.min.js`
      return pdfjs
    })().catch(e => {
      // Si riprova alla chiamata successiva: una promessa reject in cache condannerebbe il
      // pulsante a rispondere "non disponibile" per sempre, anche dopo una rete instabile
      pdfjsPromise = null
      throw e
    })
  }
  return pdfjsPromise
}

/**
 * Rasterizza il documento in una singola JPEG verticale con DENTRO TUTTE le pagine.
 *
 * @param {object} doc          documento jsPDF (lo stesso oggetto che si salverebbe come PDF)
 * @param {number} scale        DPI richiesti (default 3 = ~216 dpi su A4)
 * @param {number} quality      qualita' JPEG 0..1 (default 0.95)
 * @returns {Promise<{dataUrl,width,height,pagine,scala,scalaRichiesta,ridotta}>}
 *          `ridotta` dice onestamente se il dispositivo ha imposto meno DPI del richiesto.
 */
export async function jpegDaPdf(doc, { scale = SCALA_DI_DEFAULT, quality = QUALITA_DI_DEFAULT } = {}) {
  if (!doc) throw new Error('Nessun documento da rasterizzare')
  const pdfjs = await caricaPdfjs()

  // Gli stessi byte del PDF. jsPDF restituisce un buffer nuovo a ogni chiamata, quindi pdf.js puo'
  // trasferirlo al worker senza toccare il documento (che il chiamante potrebbe ancora salvare)
  const dati = doc.output('arraybuffer')

  const pdf = await pdfjs.getDocument({
    data: dati,
    // I font Type1 non incorporati: dal bundle, non da un CDN. In APK un CDN non e' un'opzione,
    // e il path va sotto BASE_URL perche' l'app carica gli asset da https://localhost.
    // SUI NOSTRI DOCUMENTI QUESTA OPZIONE NON VIENE MAI LETTA (vedi punto 1 in testa al file):
    // dichiararla comunque costa una stringa, e se un giorno un documento avra' glifi che la
    // riserva di pdf.js non copre, qui c'e' gia' dove prenderli
    standardFontDataUrl: `${import.meta.env.BASE_URL}pdfjs/standard_fonts/`,
    // pdf.js usa eval per convertire alcuni font: senza, su una CSP restrittiva la conversione
    // fallirebbe in un modo difficile da distinguere da un PDF rotto
    isEvalSupported: false,
    // Niente fetch di range: abbiamo gia' l'intero buffer in memoria
    disableStream: true,
    disableAutoFetch: true
  }).promise

  const pagine = pdf.numPages

  // Misure a scala 1. Si sommano perche' le pagine vanno impilate: l'altezza totale e' la somma,
  // la larghezza e' la massima (i fogli multi-gara sono in paesaggio, gli altri in ritratto: le
  // pagine possono avere formati diversi e la larghezza la decide la piu' larga)
  const viewport = []
  let baseLarghezza = 0
  let baseAltezza = 0
  for (let i = 1; i <= pagine; i++) {
    const vp = (await pdf.getPage(i)).getViewport({ scale: 1 })
    viewport.push(vp)
    if (vp.width > baseLarghezza) baseLarghezza = vp.width
    baseAltezza += vp.height
  }

  // Il tetto del dispositivo puo' ridurre i DPI, MAI il contenuto. Sotto il limite ci si finisce per
  // due strade: il lato piu' lungo (texture) e i pixel totali (memoria). Nessuna delle due deve
  // far sparire una pagina.
  const latoMax = limiteLatoReale()
  const scalaDaLato = Math.min(latoMax / baseLarghezza, latoMax / baseAltezza)
  const scalaDaPixeli = Math.sqrt(PIXEL_MAX_COMPOSITE / (baseLarghezza * baseAltezza))
  const scalaEffettiva = Math.max(0.25, Math.min(scale, scalaDaLato, scalaDaPixeli))

  const larghezza = Math.max(1, Math.round(baseLarghezza * scalaEffettiva))
  const altezza = Math.max(1, Math.round(baseAltezza * scalaEffettiva))

  // `willReadFrequently: true` dice al browser di tenere il canvas in RAM invece che in GPU: e'
  // esattamente cio' che toglie il vincolo di texture quando il limite e' li', e tanto il canvas
  // viene solo codificato, mai mostrato
  const canvas = document.createElement('canvas')
  canvas.width = larghezza
  canvas.height = altezza
  let ctx = canvas.getContext('2d', { alpha: false, willReadFrequently: true })
  if (!ctx) {
    // Il WebView ha rifiutato il canvas: si riprova dimezzando, per non consegnare niente. Meglio
    // un'immagine a meta' DPI che un pulsante che non fa nulla
    canvas.width = Math.max(1, Math.round(larghezza / 2))
    canvas.height = Math.max(1, Math.round(altezza / 2))
    ctx = canvas.getContext('2d', { alpha: false, willReadFrequently: true })
    if (!ctx) throw new Error('Il dispositivo non riesce a creare il canvas dell\'immagine')
  }

  // IL bianco dello sfondo. Va fatto qui, sul composite, perche' la JPEG non ha trasparenza:
  // senza questa riga lo sfondo viene nero (trappola n.2 in testa al file)
  ctx.fillStyle = '#ffffff'
  ctx.fillRect(0, 0, canvas.width, canvas.height)

  let offsetY = 0
  for (let i = 1; i <= pagine; i++) {
    const pagina = await pdf.getPage(i)
    const vp = viewport[i - 1]
    const w = Math.max(1, Math.round(vp.width * scalaEffettiva))
    const h = Math.max(1, Math.round(vp.height * scalaEffettiva))

    // Una pagina alla volta su un canvas d'appoggio, poi drawImage sul composite: pdf.js puo'
    // cancellare l'area che rende, e sul composite non deve arrivare nessun clear. Costo: un solo
    // canvas-pagina alla volta, rilasciato subito sotto
    const tmp = document.createElement('canvas')
    tmp.width = w
    tmp.height = h
    const tctx = tmp.getContext('2d')
    await pagina.render({ canvasContext: tctx, viewport: vp, background: '#ffffff' }).promise
    ctx.drawImage(tmp, 0, offsetY)

    // Rilascia la memoria della pagina prima della successiva
    tmp.width = 0
    tmp.height = 0
    offsetY += h
  }

  const dataUrl = canvas.toDataURL('image/jpeg', quality)
  const risultato = {
    dataUrl,
    width: canvas.width,
    height: canvas.height,
    pagine,
    scala: scalaEffettiva,
    scalaRichiesta: scale,
    // Dire se il dispositivo ha imposto meno DPI di quelli chiesti: un'immagine venuta fuori a
    // meta' risoluzione deve essere visibile anche nei log e nei test, non un dettaglio interno
    ridotta: scalaEffettiva < scale - 0.001
  }
  canvas.width = 0
  canvas.height = 0
  await pdf.destroy()
  return risultato
}

export const SCALA_DEFAULT = SCALA_DI_DEFAULT
export const QUALITA_DEFAULT = QUALITA_DI_DEFAULT
