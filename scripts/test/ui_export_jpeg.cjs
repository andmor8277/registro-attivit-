// Verifica UI reale dell'EXPORT JPEG: il pulsante "Esporta JPEG" deve produrre L'IMMAGINE del PDF,
// non un documento scritto a parte.
//
// Perche' esiste: la consegna del titolare e' "come e' previsto che esca il PDF, deve uscire il JPEG".
// E' una promessa sulla RELAZIONE fra due file, e nessuna delle due cose la verifica da sola: il PDF
// sta a posto anche se la JPEG e' vuota, e la JPEG "sembra" a posto anche se le manca una pagina.
// Quindi questo file esporta ENTRAMBI dallo stesso documento e misura l'uno contro l'altra. E' la
// stessa ragione per cui ui_weekend.cjs confronta la forma dei due calendari: condividere un modulo
// senza misurare l'output non prova niente.
//
// Le quattro cose misurate per ogni documento, e perche':
//  1. che sia una JPEG vera (magic bytes, EOF, e che il browser la decodifichi) -- un file scritto a
//     meta' o un canvas fallito passano il "esiste e pesa", e si scoprono solo provando a leggerli;
//  2. che abbia DENTRO le stesse pagine del PDF: l'aspect della JPEG deve essere
//     somma(MediaBox.height) / max(MediaBox.width) del PDF. Indipendente dalla scala, becca sia una
//     pagina persa (aspect troppo corto) sia una duplicata (troppo lungo);
//  3. che ogni pagina del PDF corrisponda a una banda con inchiostro nella JPEG -- perche' un canvas
//     che rende la prima pagina e lascia bianche le successive ha comunque l'altezza giusta;
//  4. che lo sfondo sia BIANCO: pdf.js rende su trasparente e il JPEG non ha alpha, quindi se il
//     riempimento bianco salta lo sfondo viene nero.
//
// Non si lancia a mano: lo invoca scripts/test/verifica_ui_export_jpeg.sh, che crea gli utenti di
// prova con prepara_demo_tornei.sh e passa le credenziali.
const fs = require('fs')
const { spawn } = require('child_process')

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const PW = process.argv[2]
const UTENTE = process.argv[3] || 'demo_tornei_mister1'
const AMMINISTRATORE = process.argv[5] || 'demo_tornei'
const CAT = process.argv[4] || '19'
const NOME_WEEKEND = process.env.THOF_UI_WEEKEND || 'test'
const OUT = process.env.THOF_UI_OUT || '/tmp/opencode/ui-export-jpeg'
const PORT = 9227   // porta sua: i test UI girano in sequenza, non in parallelo

// Un foglio pieno di tabelle ha qualche punto percentuale di inchiostro: sotto 0,1% la banda e'
// bianca per qualunque scopo pratico, e il negative test sul documento vuoto deve cadere qui
const INCHIOSTRO_MINIMO = 0.001
// Sotto questa larghezza un calendario a otto colonne non e' leggibile su un telefono. Non blocca
// l'export (la consegna dice che il contenuto non si tocca): e' un'asserzione, perche' un'immagine
// illeggibile che "funziona" e' il plausibile e falso di questa funzione
const LARGHEZZA_MINIMA = 900
const PESO_MINIMO = 8000

let ws, nextId = 1
let chrome = null   // serve a chiudiTutto(), che sta fuori dall'IIFE: un Chrome orfano tiene vivo il wrapper
const pending = new Map()
const erroriConsole = []
const dialoghi = []   // gli alert dell'app: sono il posto dove l'export scrive PERCHE' ha fallito

function send(method, params = {}) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    ws.send(JSON.stringify({ id, method, params }))
  })
}
const sleep = ms => new Promise(r => setTimeout(r, ms))

async function evalJS(expression, { awaitPromise = false } = {}) {
  const r = await send('Runtime.evaluate', { expression, awaitPromise, returnByValue: true })
  if (r.exceptionDetails) {
    throw new Error('ECCEZIONE IN PAGINA: ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text))
  }
  return r.result.value
}

// I byte dell'immagine viaggiano come argomento tipizzato, non interpolati nell'espressione: un data
// URL da due megabyte dentro una stringa di codice e' il modo in cui un test muore per un backslash
// e non per un difetto dell'app. `Runtime.callFunctionOn` vuole un contesto: si chiede l'objectId di
// `window` OGNI volta, perche' dopo un Page.navigate il contesto precedente e' morto e un objectId
// riusato e' l'errore che arriva come "Cannot find context" a meta' run
async function richiama(functionDeclaration, ...args) {
  const w = await send('Runtime.evaluate', { expression: 'window', returnByValue: false })
  if (w.exceptionDetails || !w.result?.objectId) {
    throw new Error('nessun contesto di esecuzione disponibile: ' +
                    (w.exceptionDetails?.text || 'objectId assente'))
  }
  const r = await send('Runtime.callFunctionOn', {
    objectId: w.result.objectId,
    functionDeclaration,
    arguments: args.map(v => ({ value: v })),
    awaitPromise: true,
    returnByValue: true
  })
  if (r.exceptionDetails) {
    throw new Error('ECCEZIONE IN PAGINA: ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text))
  }
  return r.result.value
}

async function goto(url) { await send('Page.navigate', { url }); await sleep(1500) }

// Click VERO dalla pipeline input: el.click() non e' un gesto utente per Chrome, e senza gesto reale
// il download viene bloccato in silenzio (nessun errore in console, nessun file)
async function clickReale(espressione) {
  const box = await evalJS(`(() => { const el = (${espressione}); if (!el) return null;
    const r = el.getBoundingClientRect(); if (!r.width || !r.height) return null;
    return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)} })()`)
  if (!box) throw new Error('elemento non trovato o non visibile per il click: ' + espressione)
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: box.x, y: box.y })
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: box.x, y: box.y, button: 'left', clickCount: 1 })
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: box.x, y: box.y, button: 'left', clickCount: 1 })
  await sleep(350)
}

async function erroreSchermo() {
  return await evalJS(`(document.querySelector('.error, .alert-errore, .errore')?.innerText || '').slice(0,200)`)
}

const risultati = []
function ck(nome, reale, atteso) {
  const ok = String(reale) === String(atteso)
  risultati.push({ nome, ok, reale, atteso })
  console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${nome}${ok ? '' : ` -> '${reale}' (atteso '${atteso}')`}`)
}
function ckVicinanza(nome, reale, atteso, tolleranza) {
  const ok = Number.isFinite(reale) && Math.abs(reale - atteso) / Math.abs(atteso) <= tolleranza
  risultati.push({ nome, ok, reale, atteso })
  console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${nome}${ok ? '' : ` -> '${reale}' (atteso ~${atteso}, tolleranza ${tolleranza})`}`)
}

// Le pagine non si contano "a occhio": MediaBox per pagina, che e' anche la geometria con cui si
// confrontano i pixel della JPEG. Se il lettore leggesse 0 pagine, le asserzioni di parita'
// diventerebbero verdi senza misurare niente -- percio' il conteggio e' un PREREQUISITO asserito
function leggiPdf(percorso) {
  const byte = fs.readFileSync(percorso)
  const s = byte.toString('latin1')
  const box = [...s.matchAll(/\/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]/g)]
    .map(m => ({ w: parseFloat(m[1]), h: parseFloat(m[2]) }))
  const pagine = (s.match(/\/Type\s*\/Page(?![s])/g) || []).length
  const sommaAltezze = box.reduce((a, x) => a + x.h, 0)
  const larghezzaMax = box.length ? Math.max(...box.map(x => x.w)) : 0
  return { byte: byte.length, pagine, sommaAltezze, larghezzaMax,
           aspectAtteso: larghezzaMax ? sommaAltezze / larghezzaMax : 0 }
}

// Misura l'immagine CON IL DECODER DEL BROWSER: se la JPEG e' corrotta decode() rifiuta, e' anche
// l'unico modo di leggere i pixel senza portarsi una libreria di decodifica nel test
const ANALIZZA = `async function(b64, nBande) {
  const img = new Image()
  img.src = 'data:image/jpeg;base64,' + b64
  try { await img.decode() } catch (e) { return { decodificata: false, perche: String(e) } }
  const w = img.naturalWidth, h = img.naturalHeight
  if (!w || !h) return { decodificata: false, perche: 'naturalWidth/Height a zero' }
  const c = document.createElement('canvas')
  c.width = w; c.height = h
  const x = c.getContext('2d')
  x.drawImage(img, 0, 0)
  const d = x.getImageData(0, 0, w, h).data
  const rgb = (px, py) => { const i = (py * w + px) * 4; return [d[i], d[i+1], d[i+2]] }
  const angoli = [rgb(2,2), rgb(w-3,2), rgb(2,h-3), rgb(w-3,h-3)]
  const passo = Math.max(1, Math.round(Math.sqrt(w * h) / 1500))
  const bande = []
  for (let b = 0; b < nBande; b++) {
    const y0 = Math.floor(h * b / nBande), y1 = Math.floor(h * (b + 1) / nBande)
    let tot = 0, inch = 0
    for (let y = y0; y < y1; y += passo) {
      for (let xx = 0; xx < w; xx += passo) {
        const i = (y * w + xx) * 4
        tot++
        if (d[i] < 235 || d[i+1] < 235 || d[i+2] < 235) inch++
      }
    }
    bande.push(tot ? inch / tot : 0)
  }
  return { decodificata: true, w, h, angoli, bande }
}`

;(async () => {
  if (!PW) {
    console.log('  FAIL prerequisito: nessuna password in argomento, senza login non misura niente')
    console.log('  0 passati, 1 falliti (prerequisiti)')
    process.exit(1)
  }
  fs.rmSync(`${OUT}/profile`, { recursive: true, force: true })
  fs.mkdirSync(OUT, { recursive: true })
  chrome = spawn(process.env.CHROME || '/usr/bin/google-chrome-stable', [
    '--headless=new', `--remote-debugging-port=${PORT}`, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', `--user-data-dir=${OUT}/profile`,
    '--window-size=1180,1600',
    '--allow-running-insecure-content', '--test-type', '--safebrowsing-disable-download-protection',
    `--unsafely-treat-insecure-origin-as-secure=${BASE}`,
    '--disable-features=InsecureDownloadWarnings,DownloadBubble,DownloadBubbleV2',
    'about:blank'
  ], { stdio: 'ignore' })
  // Senza SIGKILL il processo node resta appeso dopo l'ultimo verde: e' gia' costato un wrapper
  // bloccato a meta' della ripulitura dei dati di prova
  process.on('exit', () => { try { chrome.kill('SIGKILL') } catch (e) {} })

  let target = null
  for (let i = 0; i < 60; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json()
      target = list.find(t => t.type === 'page')
      if (target) break
    } catch (e) {}
    await sleep(250)
  }
  if (!target) throw new Error('Chrome non risponde sul porto ' + PORT)

  await new Promise((resolve, reject) => {
    ws = new WebSocket(target.webSocketDebuggerUrl)
    ws.onopen = () => resolve()
    ws.onerror = e => reject(e)
    ws.onmessage = ev => {
      const m = JSON.parse(ev.data)
      if (m.method === 'Runtime.consoleAPICalled') {
        const t = (m.params.args || []).map(a => a.value ?? a.description ?? '').join(' ')
        if (m.params.type === 'error') erroriConsole.push(t)
      }
      if (m.method === 'Runtime.exceptionThrown') {
        erroriConsole.push(m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text)
      }
      // L'app scrive il PERCHE' di un export fallito in un alert. Se nessuno lo smaltisce la pagina si
      // blocca sul modal, e il test sembra appeso invece che rotto
      if (m.method === 'Page.javascriptDialogOpening') {
        dialoghi.push(m.params.message)
        send('Page.handleJavaScriptDialog', { accept: true }).catch(() => {})
      }
      if (m.id && pending.has(m.id)) {
        const p = pending.get(m.id); pending.delete(m.id)
        m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result)
      }
    }
  })
  await send('Runtime.enable')
  await send('Page.enable')

  // Due login, perche' sono due utenti diversi nella realta': la programmazione partite e la
  // programmazione tornei le apre il responsabile (admin), il foglio di convocazione il mister. Il
  // test fratelli fanno cosi', e usare un solo utente significherebbe non vedere le pagine dell'altro
  async function loginCome(utente) {
    await goto(`${BASE}/login`)
    const r = await evalJS(`(async () => {
      const res = await fetch('/api/auth/token', {method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body:new URLSearchParams({username:${JSON.stringify(utente)}, password:${JSON.stringify(PW)}})})
      if (!res.ok) return {ok:false, codice:res.status}
      const d = await res.json()
      localStorage.setItem('token', d.access_token)
      const me = await (await fetch('/api/auth/me', {headers:{Authorization:'Bearer '+d.access_token}})).json()
      return {ok:true, ruolo:me.ruolo, admin:me.is_admin}
    })()`, { awaitPromise: true })
    if (!r || !r.ok) throw new Error('login fallito per ' + utente + ': ' + JSON.stringify(r))
    console.log(`  accesso come ${utente}: ruolo=${r.ruolo} admin=${r.admin}`)
    return r
  }

  await loginCome(AMMINISTRATORE)

  const DL = `${OUT}/download`
  await send('Page.setDownloadBehavior', { behavior: 'allow', downloadPath: DL })
  await send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: DL }).catch(() => {})

  // Il nome del file lo DECIDE L'APP: si svuota la cartella, si clicca, si aspetta UN file con
  // l'estensione chiesta. E' anche l'unico modo di misurare il nome che l'app ha scelto
  async function scarica(etichetta, estensione, espressioneElemento) {
    fs.mkdirSync(DL, { recursive: true })
    for (const f of fs.readdirSync(DL)) fs.rmSync(`${DL}/${f}`, { recursive: true, force: true })
    try {
      await clickReale(espressioneElemento)
    } catch (e) {
      console.log(`   click non arrivato a segno per ${etichetta}: ${e.message}`)
      return null
    }
    for (let i = 0; i < 120; i++) {
      const trovati = fs.readdirSync(DL).filter(f => f.toLowerCase().endsWith(estensione))
      if (trovati.length) {
        const percorso = `${DL}/${trovati[0]}`
        for (let k = 0; k < 40 && fs.statSync(percorso).size <= 500; k++) await sleep(250)
        await sleep(400)
        // Nomi di cartella ESPLICITI: derivarli dall'estensione (`jpg` + 's') ha dato `jpgs` qui e
        // `jpegs` nel wrapper, e il wrapper ha contato zero JPEG mentre le JPEG c'erano tutte
        const cartella = `${OUT}/${estensione === '.pdf' ? 'pdfs' : 'jpegs'}`
        fs.mkdirSync(cartella, { recursive: true })
        fs.copyFileSync(percorso, `${cartella}/${etichetta}--${trovati[0]}`)
        return { nome: trovati[0], percorso, byte: fs.statSync(percorso).size }
      }
      await sleep(250)
    }
    console.log(`   perche' nessun ${estensione} per ${etichetta}:`, await erroreSchermo(),
                '| cartella:', fs.readdirSync(DL).join(',') || '(vuota)',
                '| dialoghi:', dialoghi.slice(-2).join(' // ') || '(nessuno)',
                '| console:', erroriConsole.filter(e => !/favicon|DevTools|Vue devtools/i.test(e)).slice(-3).join(' // ') || 'pulita')
    return null
  }

  async function analizza(percorso, nBande) {
    const b64 = fs.readFileSync(percorso).toString('base64')
    return await richiama(ANALIZZA, b64, nBande)
  }

  /**
   * Esporta lo STESSO documento due volte -- PDF e JPEG -- e asserisce la loro relazione.
   */
  async function confronta(etichetta, selPdf, selJpeg) {
    console.log(`\n--- ${etichetta}: PDF e JPEG a confronto ---`)
    const dPdf = await scarica(`${etichetta}-pdf`, '.pdf', selPdf)
    if (!dPdf) {
      ck(`${etichetta}: il PDF di partenza si scarica (senza, il confronto non puo' essere fatto)`, false, true)
      return null
    }
    const pdf = leggiPdf(dPdf.percorso)
    ck(`${etichetta}: il PDF di partenza ha pagine leggibili`, pdf.pagine >= 1, true)
    if (pdf.pagine < 1) return null
    console.log(`  PDF: ${pdf.pagine} pagine, ${pdf.byte} byte, aspect atteso ${pdf.aspectAtteso.toFixed(4)}`)

    const dJpg = await scarica(`${etichetta}-jpeg`, '.jpg', selJpeg)
    if (!dJpg) {
      ck(`${etichetta}: la JPEG si scarica`, false, true)
      return null
    }
    ck(`${etichetta}: la JPEG pesa piu' di un file vuoto`, dJpg.byte >= PESO_MINIMO, true)
    // La consegna e' "l'immagine di QUEL PDF": stesso nome. Due nomi diversi per lo stesso foglio
    // fanno chiedere quale dei due sia quello giusto
    ck(`${etichetta}: il nome file e' quello del PDF con .jpg`,
       dJpg.nome, dPdf.nome.replace(/\.pdf$/i, '') + '.jpg')

    const byte = fs.readFileSync(dJpg.percorso)
    const esadec = b => [...b].map(x => x.toString(16).toUpperCase().padStart(2, '0')).join(' ')
    ck(`${etichetta}: magic bytes FF D8 FF`, esadec(byte.slice(0, 3)), 'FF D8 FF')
    ck(`${etichetta}: marcatore di fine FFD9`, esadec(byte.slice(-2)), 'FF D9')

    const a = await analizza(dJpg.percorso, pdf.pagine)
    ck(`${etichetta}: il browser la decodifica`, a.decodificata, true)
    if (!a.decodificata) { console.log("     perche':", a.perche); return null }
    console.log(`  JPEG: ${a.w}x${a.h} px, aspect ${(a.h / a.w).toFixed(4)}, ` +
                `inchiostro per banda ${a.bande.map(f => (f * 100).toFixed(2) + '%').join(' ')}`)

    ckVicinanza(`${etichetta}: l'aspect della JPEG e' quello delle ${pdf.pagine} pagine del PDF`,
                a.h / a.w, pdf.aspectAtteso, 0.03)
    ck(`${etichetta}: larghezza sopra la soglia di leggibilita'`, a.w >= LARGHEZZA_MINIMA, true)
    // L'altezza giusta non basta: un canvas che rende solo la prima pagina e' alto il doppio e ha la
    // seconda banda bianca. E' l'asserzione che tiene la consegna "tutte le pagine del PDF"
    a.bande.forEach((frazione, i) => {
      ck(`${etichetta}: la pagina ${i + 1} del PDF ha inchiostro nella sua banda`,
         frazione >= INCHIOSTRO_MINIMO, true)
    })
    const angoliBianchi = a.angoli.every(p => p[0] >= 250 && p[1] >= 250 && p[2] >= 250)
    ck(`${etichetta}: lo sfondo e' bianco (la JPEG non ha alpha, altrimenti sarebbe nero)`,
       angoliBianchi, true)
    if (!angoliBianchi) console.log('     angoli letti:', JSON.stringify(a.angoli))
    return { pdf, jpg: a }
  }

  const esiti = {}

  // --- 1+2. Programmazione Partite: il calendario del weekend e la versione per i genitori ---
  console.log('\n--- Programmazione Partite ---')
  await goto(`${BASE}/responsabili/partite`)
  await evalJS(`(async () => { await new Promise(res => { let n = 0
    const t = setInterval(() => { if (document.querySelectorAll('.weekend-card').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })
    return true })()`, { awaitPromise: true })
  const nWeekend = await evalJS(`document.querySelectorAll('.weekend-card').length`)
  ck('la lista dei weekend non e\' vuota (senza, le asserzioni sotto non misurano niente)', nWeekend > 0, true)
  if (nWeekend > 0) {
    await clickReale(`[...document.querySelectorAll('.weekend-card')].find(c => /${NOME_WEEKEND}/.test(c.innerText))`)
    ck('il weekend e\' aperto con le sue partite',
       await evalJS(`document.querySelectorAll('.categoria-section').length`) > 0, true)
    const AZ = '.weekend-actions .btn-secondary-sm'
    esiti.weekend = await confronta('weekend',
      `[...document.querySelectorAll('${AZ}')].find(b => /^Esporta PDF$/.test(b.innerText.trim()))`,
      `[...document.querySelectorAll('${AZ}')].find(b => /^JPEG$/.test(b.innerText.trim()))`)
    esiti.genitori = await confronta('genitori',
      `[...document.querySelectorAll('${AZ}')].find(b => /PDF Genitori/.test(b.innerText))`,
      `[...document.querySelectorAll('${AZ}')].find(b => /^JPEG Genitori$/.test(b.innerText.trim()))`)
  }

  // --- 3. Tornei: il calendario di tutti i tornei ---
  console.log('\n--- Tornei ---')
  await goto(`${BASE}/responsabili/tornei`)
  await sleep(1200)
  const cTutti = await evalJS(`[...document.querySelectorAll('button')].filter(b => /Esporta tutti i tornei/.test(b.innerText)).length`)
  const cImgTutti = await evalJS(`[...document.querySelectorAll('button')].filter(b => /Immagine tutti i tornei/.test(b.innerText)).length`)
  ck('il pulsante "Esporta tutti i tornei" c\'e\'', cTutti > 0, true)
  ck('il suo gemello "Immagine tutti i tornei" c\'e\' (senza, la consegna non e\' soddisfatta)', cImgTutti > 0, true)
  if (cTutti && cImgTutti) {
    esiti.tornei = await confronta('tornei-tutti',
      `[...document.querySelectorAll('button')].find(b => /Esporta tutti i tornei/.test(b.innerText))`,
      `[...document.querySelectorAll('button')].find(b => /Immagine tutti i tornei/.test(b.innerText))`)
  }

  // --- 4. Foglio di convocazione, dalla pagina Convocazioni ---
  console.log('\n--- Foglio di convocazione ---')
  await loginCome(UTENTE)
  await goto(`${BASE}/convocazioni/${CAT}`)
  await evalJS(`(async () => { await new Promise(res => { let n = 0
    const t = setInterval(() => { if (document.querySelectorAll('.wk-storico').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })
    return true })()`, { awaitPromise: true })
  const chip = await evalJS(`[...document.querySelectorAll('.wk-storico')].map(b => b.innerText.trim())`)
  ck('lo storico dei fogli non e\' vuoto (senza, non c\'e\' niente da esportare)', chip.length > 0, true)
  if (chip.length) {
    console.log('  chip nello storico: ' + JSON.stringify(chip.slice(0, 4)))
    // Quando il wrapper ha seminato un foglio a 5 gare, si apre QUELLO: e' l'unico modo di percorrere
    // l'impilamento di piu' pagine, e sceglierne uno a caso significherebbe misurare sempre una pagina
    const dataChiesta = process.env.THOF_UI_FOGLIO_DATA || ''
    const selettoreChip = dataChiesta
      ? `[...document.querySelectorAll('.wk-storico')].find(b => b.innerText.includes(${JSON.stringify(dataChiesta)}))`
      : `document.querySelector('.wk-storico')`
    if (dataChiesta) {
      ck(`il foglio a 5 gare seminato dal wrapper compare nello storico (${dataChiesta})`,
         await evalJS(`!!(${selettoreChip})`), true)
    }
    await clickReale(selettoreChip)
    await sleep(900)
    const cPdf = await evalJS(`[...document.querySelectorAll('button')].filter(b => /Esporta PDF/.test(b.innerText)).length`)
    const cJpg = await evalJS(`[...document.querySelectorAll('button')].filter(b => /Esporta JPEG/.test(b.innerText)).length`)
    ck('il pulsante "Esporta PDF" del foglio c\'e\'', cPdf > 0, true)
    ck('il suo gemello "Esporta JPEG" c\'e\'', cJpg > 0, true)
    if (cPdf && cJpg) {
      esiti.foglio = await confronta('foglio-convocazione',
        `[...document.querySelectorAll('button')].find(b => /Esporta PDF/.test(b.innerText))`,
        `[...document.querySelectorAll('button')].find(b => /Esporta JPEG/.test(b.innerText))`)
    }
  }

  // --- 5. Almeno un documento deve essere venuto fuori multi-pagina, o la guardia sulle pagine
  //        impilate non e' mai stata percorsa e il suo verde non significa niente ---
  const multi = Object.entries(esiti).filter(([, e]) => e && e.pdf.pagine > 1)
  console.log('\n--- il multi-pagina e\' stato percorso? ---')
  console.log(`  documenti con piu' di una pagina: ${multi.length ? multi.map(([k, e]) => `${k} (${e.pdf.pagine})`).join(', ') : 'NESSUNO'}`)
  // Non e' una nota: e' un'asserzione. La consegna "quello che c'e' nel PDF deve esserci nella JPEG"
  // vale proprio quando le pagine sono piu' di una, e un verde ottenuto senza mai percorrerla sarebbe
  // il peggior falso verde di questo file -- il codice dell'impilamento non sarebbe stato eseguito
  ck('almeno un documento esportato ha piu\' di una pagina (senza, il percorso che le impila non e\' stato eseguito)',
     multi.length >= 1, true)
  for (const [k, e] of multi) {
    ck(`${k}: con ${e.pdf.pagine} pagine la JPEG le ha tutte e ognuna ha il suo inchiostro`,
       e.jpg.bande.length === e.pdf.pagine && e.jpg.bande.every(f => f >= INCHIOSTRO_MINIMO), true)
  }

  // La console della pagina deve restare pulita: un errore inghiottito dal try/catch dell'export
  // lascerebbe solo "Errore nella generazione del PDF" a schermo e nessun segno nel file
  const rumore = erroriConsole.filter(e => !/favicon|DevTools|Vue devtools|Download is starting/i.test(e))
  ck('nessun errore in console della pagina', rumore.length, 0)
  if (rumore.length) rumore.slice(0, 5).forEach(e => console.log('   console: ' + e.slice(0, 220)))
  ck('nessun alert di errore dall\'app', dialoghi.length, 0)
  if (dialoghi.length) dialoghi.forEach(d => console.log('   alert: ' + d.slice(0, 220)))

  const pass = risultati.filter(r => r.ok).length
  const fail = risultati.filter(r => !r.ok).length
  console.log(`\n${pass} passati, ${fail} falliti`)
  console.log(`  (documenti confrontati: ${Object.keys(esiti).filter(k => esiti[k]).length}/${Object.keys(esiti).length})`)
  // Il processo NON esce da solo: il WebSocket verso Chrome tiene vivo l'event loop, il wrapper resta
  // appeso e non arriva ne' alla ripulitura dei dati di prova ne' al verdetto. Gia' costato un wrapper
  // bloccato a meta' in ui_weekend.cjs -- si chiude il browser, poi il socket, poi si esce esplicitamente
  await chiudiTutto()
  process.exit(fail ? 1 : 0)
})().catch(async e => {
  console.error('ERRORE DEL TEST:', e)
  console.log('  0 passati, 1 falliti (eccezione del test)')
  await chiudiTutto()
  process.exit(1)
})

async function chiudiTutto() {
  try { await Promise.race([send('Browser.close'), sleep(3000)]) } catch (e) {}
  try { ws && ws.close() } catch (e) {}
  try { chrome.kill('SIGKILL') } catch (e) {}
}
