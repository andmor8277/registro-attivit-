// Guard-rail della LAVAGNA TATTICA (frontend/public/lavagna-20250702.html + il wrapper
// components/TacticalBoard.vue + il renderizzatore PDF in features/allenamenti/Allenamenti.vue).
//
// Perche' esiste. La lavagna era l'unica superficie dell'app con ZERO asserzioni sopra: nessun
// verifica_ui_*.sh la guardava. Il risultato, raccontato dal titolare: "ogni volta che tentiamo le
// modifiche la lavagna si rompe". Non e' sfortuna, e' una struttura:
//
//   un tipo nuovo va scritto in TRE catene if/else chiaviste sulla STESSA stringa el.tipo, in DUE
//   file diversi, per ~860 righe di codice diramato per tipo:
//     - getElements()        in lavagna-20250702.html   (serializza per il salvataggio)   ~107 righe
//     - loadElement()        in lavagna-20250702.html   (ridisegna alla riapertura)        ~128 righe
//     - drawElementsCanvas() in Allenamenti.vue         (disegna in PDF e anteprime)       ~621 righe
//   Dimenticarne una NON da' un errore:
//     - senza getElements   l'elemento si vede a schermo ma viene salvato a meta';
//     - senza loadElement   `newEl` resta null e doLoadElements fa `if(newEl) add(newEl)`: l'elemento
//       SPARISCE alla riapertura in silenzio, perche' il console.error scatta solo sulle eccezioni;
//     - senza drawElementsCanvas a schermo c'e', nel PDF no.
//   La Parte A becca esattamente questo, dal solo sorgente, prima ancora di aprire il browser.
//
// Le parti B/C/D/E/F aggiungono il resto, che la statica non puo' vedere: che il pulsante esista
// davvero, che il gesto giusto lo faccia nascere (le linee nascono solo con un trascinamento sopra
// i 15 px, riga 994: un click singolo non crea niente e un test ingenuo le darebbe per rotte), e che
// il lavoro dell'allenatore faccia il giro VERO: piazza -> getElements -> POST /allenamenti/ -> riga
// in `allenamenti.esercizi` -> GET -> loadElement -> ridipinto a schermo.
//
// TRE cose non ovvie scoperte scrivendo questo test, e tutte e tre erano falsi verdi:
//  1) GLI ESERCIZI NON STANNO IN TABELLE RELAZIONALI. `allenamenti_giorno/esercizio/elemento` (e le
//     loro versioni al singolare) esistono nei modelli ma sono VUOTE: la fonte reale e' la tabella
//     `allenamenti`, una riga per (categoria, data), con gli esercizi dentro la colonna JSONB
//     `esercizi` (routers/allenamenti.py:74-83). Un'asserzione sul DB fatta sulle tabelle
//     relazionali e' verde per sempre senza misurare niente.
//  2) C'E' UN IFRAME PER OGNI CARD. `.board-area` (Allenamenti.vue:160) non ha nessun v-if: ogni
//     esercizio renderizza la SUA TacticalBoard. Prendere il primo iframe della pagina vuol dire
//     leggere la lavagna dell'esercizio sbagliato (e' successo: il test leggeva 22 elementi che non
//     erano sulla card attiva). Qui si legge SOLO l'iframe della card `.active`, e i postMessage
//     vengono filtrati per `e.source`, perche' le altre lavagne montate rispondono altrettanto bene.
//  3) LA LAVAGNA RIFIUTA IN SILENZIO un loadElements quando ha modifiche locali non salvate (riga
//     640, `if(canvasModifiedAt>canvasLoadedAt)return`). E' il guardiano che protegge il lavoro non
//     salvato, ma e' anche il motivo per cui un confronto "carica e rileggi" fatto a caso resta verde
//     per inerzia: qui viene prima DIMOSTRATO che il caricamento avviene (set dimostrativo con un
//     conteggio DIVERSO da quello a schermo) e poi misurato, e il guardiano ha una asserzione sua.
//
// Il test scrive nel DB, e lo dichiara: `addEsercizio` fa `markDirty(); debouncedSave()` (800 ms),
// quindi l'esercizio arriva a terra da solo. Per questo lavora su un MESE DEDICATO (default 2027-02,
// sovrascrivibile con THOF_LAVAGNA_MESE) e sul primo giorno di allenamento LIBERO di quel mese -- il
// calendario, poi, mostra solo i giorni che stanno in `categorie.giorni`. Il wrapper mette in
// snapshot l'intera categoria prima e la rimette esattamente com'era dopo, e l'ultima asserzione
// verifica che lo stato finale coincida con quello di partenza.
//
// NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Google Chrome. Si lancia:
//   bash scripts/test/verifica_ui_lavagna.sh
const fs = require('fs')
const path = require('path')
const { spawn } = require('child_process')

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const PW = process.argv[2]
const UTENTE = process.argv[3] || 'demo_tornei_mister1'
const CAT = process.argv[4] || '19'
const TARGET_MESE = process.env.THOF_LAVAGNA_MESE || '2027-02'
const OUT = process.env.THOF_UI_OUT || '/tmp/opencode/ui-lavagna'
const PORT = 9226   // porta sua: i test UI girano in sequenza, non in parallelo

const REPO = path.resolve(__dirname, '..', '..')
const F_LAVAGNA = path.join(REPO, 'frontend/public/lavagna-20250702.html')
const F_ALLEN = path.join(REPO, 'frontend/src/features/allenamenti/Allenamenti.vue')

let ws, nextId = 1
const pending = new Map()
const erroriConsole = []
const dialoghi = []
const risultati = []

function ck(nome, reale, atteso) {
  const ok = String(reale) === String(atteso)
  risultati.push({ nome, ok })
  console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${nome}${ok ? '' : ` -> '${reale}' (atteso '${atteso}')`}`)
}
function ckVero(nome, condizione, dettaglio) {
  risultati.push({ nome, ok: !!condizione })
  console.log(`  ${condizione ? 'ok  ' : 'FAIL'} ${nome}${condizione ? '' : ` -> ${dettaglio}`}`)
}
const sleep = ms => new Promise(r => setTimeout(r, ms))

function send(method, params = {}) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    ws.send(JSON.stringify({ id, method, params }))
  })
}
async function evalJS(expression, { awaitPromise = false } = {}) {
  const r = await send('Runtime.evaluate', { expression, awaitPromise, returnByValue: true })
  if (r.exceptionDetails) {
    throw new Error('ECCEZIONE IN PAGINA: ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text))
  }
  return r.result.value
}
async function goto(url) { await send('Page.navigate', { url }); await sleep(1700) }

// Click e trascinamento VERI dalla pipeline input: el.click() non e' un gesto utente per Chrome, e
// la lavagna ascolta Konva, che vuole mousedown/mousemove/mouseup reali
async function mouse(type, x, y) {
  await send('Input.dispatchMouseEvent', { type, x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1, buttons: type === 'mouseReleased' ? 0 : 1 })
}
async function clickReale(x, y) {
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: Math.round(x), y: Math.round(y) })
  await mouse('mousePressed', x, y); await sleep(60); await mouse('mouseReleased', x, y)
  await sleep(320)
}
async function trascinaReale(x1, y1, x2, y2) {
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: Math.round(x1), y: Math.round(y1) })
  await mouse('mousePressed', x1, y1)
  for (let i = 1; i <= 6; i++) {
    await mouse('mouseMoved', x1 + (x2 - x1) * i / 6, y1 + (y2 - y1) * i / 6)
    await sleep(35)
  }
  await mouse('mouseReleased', x2, y2)
  await sleep(320)
}

// ───────────────────────── PARTE A ─────────────────────────
// Le TRE catene a confronto, dal solo sorgente. E' l'asserzione che manca quando "la lavagna si
// rompe": un tipo scritto nella palette e dimenticato in una delle tre catene diventa qui rosso,
// prima ancora di aprire Chrome e senza dipendere da nessun dato di DEV
function analizzaStatica() {
  const lav = fs.readFileSync(F_LAVAGNA, 'utf8')
  const all = fs.readFileSync(F_ALLEN, 'utf8')

  // la palette reale: e' LEI cio' che il mister vede, non un elenco scritto a mano nel test
  const i0 = lav.indexOf('var toolSections=[')
  const i1 = lav.indexOf('\n  ];', i0)
  const palette = [...lav.slice(i0, i1 > i0 ? i1 : i0 + 6000)
    .matchAll(/\{type:'([a-z0-9-]+)',label:'([^']*)',icon:'([^']*)'\}/g)]
    .map(m => ({ type: m[1], label: m[2], icon: m[3] }))
    .filter(t => t.type !== 'select')

  function corpo(src, firma, fine) {
    const a = src.indexOf(firma); if (a < 0) return ''
    const b = src.indexOf(fine, a + firma.length); return src.slice(a, b > a ? b : a + 20000)
  }
  const ge = corpo(lav, 'function getElements(', '\n  function ')
  const le = corpo(lav, 'function loadElement(', '\n  function ')
  const dc = corpo(all, 'function drawElementsCanvas(', '\n}\n')

  const insieme = t => new Set([...t.matchAll(/tipo\s*===?\s*'([a-z0-9-]+)'/g)].map(m => m[1]))
  const S = { getElements: insieme(ge), loadElement: insieme(le), pdf: insieme(dc) }

  console.log('--- A. le tre catene dello stesso tipo, a confronto (dal solo sorgente) ---')
  ckVero('la palette della lavagna e\' stata trovata', palette.length >= 20, `${palette.length} strumenti`)
  // 22 dal 25/11/2026: tolto il pulsante "Giocatore" su richiesta del titolare («sostituisci Giocatore con
  // Fratinato, Fratinato lo puo anche togliere»). Il TIPO `player` resta nelle quattro serializzazioni --
  // sono gli strumenti della palette a essere 22, non i tipi disegnabili
  ck('la palette ha gli strumenti attesi', palette.length, 22)
  for (const [nome, k] of Object.entries(S)) {
    ckVero(`righe di codice diramato per tipo in ${nome}`, k.size > 15, `${k.size} tipi`)
  }
  for (const [nome, k] of Object.entries(S)) {
    const manc = palette.map(t => t.type).filter(t => !k.has(t))
    ck(`ogni strumento della palette esiste in ${nome}`, manc.length, 0)
    if (manc.length) console.log(`       dimenticati in ${nome}: ${manc.join(', ')}`)
  }

  const etichette = palette.map(t => t.label)
  ck('ogni strumento ha un\'etichetta', etichette.filter(l => l && l.trim()).length, palette.length)
  ck('le etichette sono univoche (il test le clicca per titolo)', new Set(etichette).size, palette.length)
  ck('ogni strumento ha una sua icona', palette.filter(t => t.icon && t.icon.trim()).length, palette.length)

  // la QUARTA serializzazione, quella che nessuno chiama in causa: il payload del salvataggio e' una
  // LISTA BIANCA di campi (Allenamenti.vue ~1415). Un campo che un tipo futuro dovesse portare viene
  // buttato via in silenzio a meta' strada tra lo schermo e il DB: l'elemento torna indietro monco,
  // a schermo c'era, e nessun errore compare da nessuna parte
  const payload = corpo(all, 'const payload = {', '\n  saveAllenamenti(')
  const campi = [...payload.matchAll(/(\w+):\s+el\./g)].map(m => m[1])
  ckVero('il payload di salvataggio dichiara i campi degli elementi', campi.length >= 18, `${campi.length} campi`)
  for (const c of ['tipo', 'x', 'y', 'rotazione', 'colore', 'numero', 'size', 'points', 'text', 'x1', 'y1', 'x2', 'y2', 'w', 'h', 'scaleX', 'scaleY']) {
    ck(`il campo ${c} sopravvive al payload del salvataggio`, campi.includes(c), 'true')
  }

  return palette
}

;(async () => {
  const palette = analizzaStatica()

  if (!PW) {
    console.log('\n  0 passati, 1 falliti (prerequisiti): nessuna password: il login e\' il prerequisito di tutto il resto')
    process.exit(1)
  }

  fs.rmSync(`${OUT}/profile`, { recursive: true, force: true })
  fs.mkdirSync(OUT, { recursive: true })
  const chrome = spawn('/usr/bin/google-chrome-stable', [
    '--headless=new', `--remote-debugging-port=${PORT}`, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', `--user-data-dir=${OUT}/profile`,
    '--window-size=1500,1100',
    '--allow-running-insecure-content', '--test-type',
    `--unsafely-treat-insecure-origin-as-secure=${BASE}`,
    'about:blank'
  ], { stdio: 'ignore' })
  // senza questa chiusura il processo node resta appeso dopo l'ultimo verde, come gia' visto negli
  // altri test UI: il wrapper non arriverebbe mai alla ripulitura
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
  if (!target) throw new Error('Chrome non risponde sulla porta ' + PORT)

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
      // I dialoghi nativi vanno RISPOSTI, non aggirati. La lavagna chiama confirm('Cancellare tutto?')
      // dentro l'IFRAME: sovrascrivere window.confirm nella pagina padre non lo tocca, e in headless
      // nessuno risponde al dialogo nativo -> Runtime.evaluate si blocca per sempre a CPU zero (e'
      // successo al secondo run di questo test). Rispondere qui permette anche di ASSERIRE il testo
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

  async function chiudiEVai(codice) {
    await send('Browser.close').catch(() => {})
    chrome.kill('SIGKILL')
    const p = risultati.filter(r => r.ok).length, f = risultati.filter(r => !r.ok).length
    console.log(`\n  ${p} passati, ${f + 1} falliti (${codice})`)
    process.exit(1)
  }
  async function screenshot(nome) {
    try {
      const r = await send('Page.captureScreenshot', { format: 'png' })
      fs.writeFileSync(`${OUT}/${nome}.png`, Buffer.from(r.data, 'base64'))
      console.log(`       screenshot: ${OUT}/${nome}.png`)
    } catch (e) {}
  }

  // ── login ──
  await goto(`${BASE}/login`)
  const login = await evalJS(`(async () => {
    const res = await fetch('/api/auth/token', {method:'POST',
      headers:{'Content-Type':'application/x-www-form-urlencoded'},
      body: new URLSearchParams({username: ${JSON.stringify(UTENTE)}, password: ${JSON.stringify(PW)}})})
    if (!res.ok) return {errore: 'token http ' + res.status}
    const {access_token} = await res.json()
    const me = await (await fetch('/api/auth/me', {headers:{Authorization:'Bearer '+access_token}})).json()
    localStorage.clear()
    localStorage.setItem('token', access_token)
    localStorage.setItem('utente_data', JSON.stringify(me))
    localStorage.setItem('thof_last_activity', Date.now().toString())
    if (me.is_admin) localStorage.setItem('is_admin','1')
    return {ok:true, ruolo: me.ruolo}
  })()`, { awaitPromise: true })
  if (!login || !login.ok) await chiudiEVai('prerequisiti: login fallito ' + (login && login.errore))

  // ───────────────────────── PARTE B ─────────────────────────
  console.log('\n--- B. si arriva alla lavagna con i gesti del mister ---')

  const MESI = { gennaio: 1, febbraio: 2, marzo: 3, aprile: 4, maggio: 5, giugno: 6, luglio: 7,
                 agosto: 8, settembre: 9, ottobre: 10, novembre: 11, dicembre: 12 }
  const [tY, tM] = TARGET_MESE.split('-').map(Number)
  let dataUsata = null
  async function meseVisualizzato() {
    const t = await evalJS(`(document.querySelector('.current-month')?.innerText || '').trim()`)
    const p = t.split(/\s+/)
    return { testo: t, anno: Number(p[1]) || 0, mese: MESI[(p[0] || '').toLowerCase()] || 0 }
  }
  // Il calendario NON mostra tutti i giorni: `weeksInMonth` (Allenamenti.vue:345) tiene solo i giorni
  // il cui giorno della settimana e' in `categorie.giorni` (cat 19 = 1,3,5 = lun/mer/ven). Un giorno
  // scritto a mano nel test sarebbe un chip che non esiste, e il rosso sarebbe del test. Si naviga al
  // MESE di prova e si prende il primo chip LIBERO; la data vera la si legge dal titolo che la pagina
  // stessa dipinge, non la si ricostruisce
  async function vaiAlMese() {
    await goto(`${BASE}/allenamenti/${CAT}`)
    await sleep(1300)
    let mv = await meseVisualizzato()
    for (let i = 0; i < 40; i++) {
      const delta = (tY * 12 + tM) - (mv.anno * 12 + mv.mese)
      if (delta === 0) break
      const b = await evalJS(`(() => { const btns = [...document.querySelectorAll('.month-nav-pill .btn-nav-mese')];
        const t = ${delta > 0 ? 'btns[btns.length-1]' : 'btns[0]'}; if (!t) return null;
        const r = t.getBoundingClientRect(); return {x: Math.round(r.x+r.width/2), y: Math.round(r.y+r.height/2)} })()`)
      if (!b) return { ok: false, perche: 'pulsante di navigazione del mese assente' }
      await clickReale(b.x, b.y); await sleep(260)
      mv = await meseVisualizzato()
    }
    if (mv.anno * 12 + mv.mese !== tY * 12 + tM) return { ok: false, perche: `il calendario si e' fermato a '${mv.testo}'` }
    return { ok: true, testo: mv.testo }
  }
  function dataDalTitolo(titolo) {
    // "Allenamento del 1 febbraio 2027" -> 2027-02-01. Se il titolo cambia forma, il test deve dirlo,
    // non lavorare su una data ipotizzata
    const m = /(\d{1,2})\s+([A-Za-zàèéìòù]+)\s+(\d{4})/.exec(titolo || '')
    if (!m) return null
    const mm = MESI[m[2].toLowerCase()]
    if (!mm) return null
    return `${m[3]}-${String(mm).padStart(2, '0')}-${String(m[1]).padStart(2, '0')}`
  }
  async function apriGiornoLibero(testoMese) {
    const n = await evalJS(`document.querySelectorAll('.day-chip:not(.other-month)').length`)
    if (!n) return { ok: false, perche: `nessun .day-chip in ${testoMese}: categorie.giorni e' vuoto o il mese non ha giorni di allenamento` }
    for (let i = 0; i < n; i++) {
      const p = await evalJS(`(() => { const c = [...document.querySelectorAll('.day-chip:not(.other-month)')][${i}]; if (!c) return null;
        const r = c.getBoundingClientRect(); return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)} })()`)
      if (!p) continue
      await clickReale(p.x, p.y); await sleep(900)
      if (!await evalJS(`!!document.querySelector('.day-detail')`)) continue
      const titolo = await evalJS(`(document.querySelector('.day-detail h3')?.innerText || '').trim()`)
      const data = dataDalTitolo(titolo)
      if (!data) return { ok: false, perche: `titolo del giorno non interpretabile: '${titolo}'` }
      const nCard = await evalJS(`document.querySelectorAll('.esercizio-card').length`)
      if (nCard === 0) return { ok: true, data, titolo, provati: i + 1 }
    }
    return { ok: false, perche: `nessuno dei ${n} giorni di allenamento di ${testoMese} e' libero: scegli un altro mese con THOF_LAVAGNA_MESE` }
  }

  // come sopra, ma per riaprire UN giorno specifico dopo la ricarica della pagina: e' il gesto del
  // mister che torna sull'allenamento di quel giorno
  async function riapriGiorno(dataStr, testoMese) {
    const n = await evalJS(`document.querySelectorAll('.day-chip:not(.other-month)').length`)
    for (let i = 0; i < n; i++) {
      const p = await evalJS(`(() => { const c = [...document.querySelectorAll('.day-chip:not(.other-month)')][${i}]; if (!c) return null;
        const r = c.getBoundingClientRect(); return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)} })()`)
      if (!p) continue
      await clickReale(p.x, p.y); await sleep(900)
      const titolo = await evalJS(`(document.querySelector('.day-detail h3')?.innerText || '').trim()`)
      if (dataDalTitolo(titolo) === dataStr) return { ok: true, titolo }
    }
    return { ok: false, perche: `riaprendo il calendario, il giorno ${dataStr} non c'era piu' in ${testoMese}` }
  }

  const nav = await vaiAlMese()
  ckVero('il calendario arriva al mese di prova', nav.ok, nav.perche)
  if (!nav.ok) await chiudiEVai('prerequisiti: ' + nav.perche)
  console.log(`       mese di prova: ${nav.testo}`)
  const g = await apriGiornoLibero(nav.testo)
  ckVero('si apre un giorno di allenamento senza esercizi', g.ok, g.perche)
  if (!g.ok) await chiudiEVai('prerequisiti: ' + g.perche)
  dataUsata = g.data
  ckVero('il giorno di prova parte senza esercizi (altrimenti i conti non tornano)', true, '')
  console.log(`       giorno di prova: ${g.data} ('${g.titolo}', ${g.provati} chip provati)`)
  console.log(`  DATA-USATA=${g.data}`)

  async function clickBtnAzione(txt) {
    const b = await evalJS(`(() => { const x = [...document.querySelectorAll('.day-actions .btn-action')]
        .find(y => new RegExp(${JSON.stringify(txt)},'i').test(y.innerText)); if (!x) return null;
      const r = x.getBoundingClientRect(); return {x: Math.round(r.x+r.width/2), y: Math.round(r.y+r.height/2)} })()`)
    if (!b) return false
    await clickReale(b.x, b.y); await sleep(900)
    return true
  }
  async function apriCard(i) {
    const c = await evalJS(`(() => { const cs = [...document.querySelectorAll('.esercizio-card')];
      const c = cs[${i}]; if (!c) return null;
      const r = c.getBoundingClientRect(); return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + 24)} })()`)
    if (!c) return false
    await clickReale(c.x, c.y); await sleep(1500)
    return true
  }

  ckVero('il pulsante "Esercizio" c\'e\'', await clickBtnAzione('Esercizio'), 'nessun .btn-action con testo Esercizio')
  const nCard = await evalJS(`document.querySelectorAll('.esercizio-card').length`)
  ck('l\'esercizio creato compare nella lista', nCard, 1)
  ckVero('la card si apre con un click', await apriCard(0), 'nessuna card da aprire')

  // QUI il difetto che ha accecato il test per un giro intero: `.board-area` (Allenamenti.vue:160) NON
  // ha un v-if, quindi OGNI card monta la SUA TacticalBoard. Il primo iframe della pagina e' la lavagna
  // del primo esercizio, non quella che stai guardando
  ck('c\'e\' un iframe per ogni card (nessun v-if su .board-area)',
    await evalJS(`document.querySelectorAll('iframe[src*="lavagna-20250702"]').length`), nCard)
  ck('una sola card e\' attiva alla volta', await evalJS(`document.querySelectorAll('.esercizio-card.active').length`), 1)
  const SEL_ATTIVA = '.esercizio-card.active iframe[src*="lavagna-20250702"]'
  if (!await evalJS(`!!document.querySelector(${JSON.stringify(SEL_ATTIVA)})`)) {
    await chiudiEVai('prerequisiti: nessuna lavagna nella card attiva')
  }
  await sleep(1300)

  // wrapper e iframe sono STESSA ORIGINE: si entra nell'iframe dal documento padre. Le funzioni della
  // lavagna NON sono raggiungibili (tutto dentro un IIFE, righe 84-1149): l'unico contratto e' il
  // postMessage, ed e' quello che questo test usa -- niente scorciatoie che il mister non puo' prendere
  async function inIframe(body) {
    return await evalJS(`(() => {
      const f = document.querySelector(${JSON.stringify(SEL_ATTIVA)});
      if (!f) return {__noiframe: true};
      const w = f.contentWindow, d = f.contentDocument;
      const fr = f.getBoundingClientRect();
      ${body}
    })()`)
  }
  async function puntoNellIframe(selettore) {
    return await inIframe(`const el = d.querySelector(${JSON.stringify(selettore)});
      if (!el) return null; const r = el.getBoundingClientRect();
      if (!r.width || !r.height) return null;
      return {x: fr.x + r.x + r.width/2, y: fr.y + r.y + r.height/2};`)
  }
  async function puntoCampo(fx, fy) {
    return await inIframe(`const c = d.getElementById('canvasWrap'); if (!c) return null;
      const r = c.getBoundingClientRect();
      return {x: fr.x + r.x + r.width*${fx}, y: fr.y + r.y + r.height*${fy}};`)
  }
  // Il conteggio dei messaggi elementsUpdated fa leggere SOLO la risposta a una richiesta appena
  // fatta. Il filtro su e.source e' indispensabile: con piu' lavagne montate, le altre rispondono allo
  // stesso tipo di messaggio e leggerebbero loro al posto della card attiva
  async function riascolta() {
    await evalJS(`(() => {
      const f = document.querySelector(${JSON.stringify(SEL_ATTIVA)});
      window.__lav = {els: null, n: 0, ts: 0, da: f ? f.contentWindow : null};
      window.addEventListener('message', function(e){
        if (e.data && e.data.type === 'elementsUpdated' && e.source === window.__lav.da) {
          window.__lav.els = e.data.elements; window.__lav.n++; window.__lav.ts = e.data.canvasTs || 0;
        }
      });
      return 1;
    })()`)
  }
  await riascolta()
  async function leggiElementi() {
    const prima = await evalJS('window.__lav.n')
    await inIframe(`w.postMessage({type:'getElements'},'*'); return 1`)
    for (let i = 0; i < 50; i++) {
      const s = await evalJS('({n: window.__lav.n, els: window.__lav.els})')
      if (s && s.n > prima) return s.els
      await sleep(60)
    }
    return null
  }
  const perTipo = a => (a || []).reduce((o, e) => (o[e.tipo] = (o[e.tipo] || 0) + 1, o), {})
  const diffTipo = (prima, dopo) => Object.keys(prima).filter(t => (dopo[t] || 0) !== prima[t])
    .map(t => `${t} ${prima[t]}->${dopo[t] || 0}`).join(', ')

  // ── la palette dipinta deve essere LA STESSA del sorgente, non una simile ──
  // Attenzione: il corpo passato a inIframe e' il CORPO di una freccia, quindi ogni valore letto va
  // RESTITUITO esplicitamente. Omettere il return non da' errore: restituisce undefined, e il rosso
  // che ne viene sembra un difetto della lavagna. E' successo al primo run di questo test
  const pulsanti = await inIframe(`return [...d.querySelectorAll('.tool-btn')].map(b => b.getAttribute('title'))`)
  if (!Array.isArray(pulsanti)) await chiudiEVai('prerequisiti: toolbar non leggibile ' + JSON.stringify(pulsanti))
  ckVero('la toolbar e\' dipinta', pulsanti.length > 0, `pulsanti trovati: ${pulsanti.length}`)
  const mancanti = ['Seleziona', ...palette.map(t => t.label)].filter(l => !pulsanti.includes(l))
  ck('ogni strumento del sorgente e\' un pulsante a schermo', mancanti.length, 0)
  if (mancanti.length) console.log('       pulsanti assenti a schermo: ' + mancanti.join(', '))
  ck('la palette dei colori e\' dipinta', await inIframe(`return d.querySelectorAll('.color-swatch').length`), 10)
  ck('le tre modalita\' di campo ci sono',
    await inIframe(`return [...d.querySelectorAll('.field-chip[data-mode]')].map(c => c.dataset.mode).sort().join(',')`),
    'blank,full,half')

  // ── pulisci: si parte da una lavagna vuota, o i conti non tornano ──
  const svuota = await puntoNellIframe('#clearBtn')
  ckVero('il pulsante Pulisci esiste ed e\' cliccabile', !!svuota, '#clearBtn non trovato o senza misura')
  const nDialoghiPrima = dialoghi.length
  if (svuota) { await clickReale(svuota.x, svuota.y); await sleep(700) }
  // Svuotare la lavagna cancella il lavoro di un allenatore: deve chiederglielo. Il dialogo si
  // intercetta via CDP, non si sovrascrive
  ckVero('Pulisci chiede conferma prima di azzerare tutto', dialoghi.length > nDialoghiPrima, 'nessun dialogo di conferma intercettato')
  ckVero('la conferma dice cosa sta per essere cancellato', /cancell/i.test(dialoghi.slice(nDialoghiPrima).join(' ')), `testo: '${dialoghi.slice(nDialoghiPrima).join(' ')}'`)
  const vuoto = await leggiElementi()
  ckVero('la lavagna risponde al postMessage getElements', Array.isArray(vuoto), 'nessuna risposta: il contratto postMessage non funziona')
  ck('la lavagna parte vuota', Array.isArray(vuoto) ? vuoto.length : -1, 0)

  // ───────────────────────── PARTE C ─────────────────────────
  // Ogni strumento deve produrre il SUO tipo, con il gesto giusto: sotto i 15 px nasce un elemento
  // puntale, sopra nasce una linea (riga 994). Le 6 linee HANNO BISOGNO del trascinamento, e un click
  // singolo le lascerebbe rossi per colpa del test
  console.log('\n--- C. piazza ogni strumento e leggi cosa nasce ---')
  const LINEE = ['pass', 'dribble', 'wallpass', 'shot', 'movement', 'line']
  const nTot = palette.length
  for (let i = 0; i < nTot; i++) {
    const t = palette[i]
    const btn = await puntoNellIframe(`.tool-btn[title="${t.label}"]`)
    if (!btn) { ckVero(`${t.type}: il pulsante e' cliccabile`, false, 'non trovato'); continue }
    await clickReale(btn.x, btn.y); await sleep(180)

    const prima = await evalJS('window.__lav.n')
    const fx = 0.16 + (i % 6) * 0.13, fy = 0.20 + Math.floor(i / 6) * 0.16
    const p1 = await puntoCampo(fx, fy)
    if (!p1) { ckVero(`${t.type}: il campo e' cliccabile`, false, 'canvasWrap senza misura'); continue }
    if (LINEE.includes(t.type)) {
      const p2 = await puntoCampo(Math.min(fx + 0.11, 0.95), Math.min(fy + 0.07, 0.95))
      await trascinaReale(p1.x, p1.y, p2.x, p2.y)
    } else {
      await clickReale(p1.x, p1.y)
    }
    await sleep(260)

    const els = await leggiElementi()
    const mio = (els || []).filter(e => e.tipo === t.type).length
    ckVero(`${t.type}: nasce un elemento del suo tipo`, mio >= 1, `elementi totali ${(els||[]).length}, di tipo ${t.type}: ${mio}`)
    const uno = (els || []).find(e => e.tipo === t.type)
    if (uno) {
      ckVero(`${t.type}: le coordinate sono in campo (0-100)`,
        Number.isFinite(uno.x) && uno.x >= 0 && uno.x <= 100 && Number.isFinite(uno.y) && uno.y >= 0 && uno.y <= 100,
        `x=${uno.x} y=${uno.y}`)
    }
    ckVero(`${t.type}: la lavagna ha risposto al getElements`, (await evalJS('window.__lav.n')) > prima, 'nessuna risposta')
  }

  const raccolti = await leggiElementi()
  ckVero('la lavagna ha elementi da far viaggiare', (raccolti || []).length >= nTot, `${(raccolti || []).length} elementi`)
  const tAttesi = perTipo(raccolti)
  ck('gli elementi piazzati sono uno per strumento', (raccolti || []).length, nTot)

  // ───────────────────────── PARTE C2 ─────────────────────────
  // Jolly e Portiere: l'interno DEVE essere colorato e la lettera DEVE esserci (titolare 25/11/2026:
  // «deve avere il colore anche all'interno, adesso e' vuoto», «deve avere la P ma deve essere colorato
  // l'interno, altrimenti non si vedono bene»). `getElements` non dice niente del riempimento -- serializza
  // tipo, coordinate e numero -- quindi qui si legge il nodo Konva reale: `fill() == 'transparent'` E' il
  // difetto, non un dettaglio. Si misura anche la forma del Jolly perche' campo e miniatura non erano lo
  // stesso oggetto: `RegularPolygon({sides:4, rotation:45})` e' un QUADRATO, mentre l'icona della palette e
  // la miniatura del catalogo lo disegnano a rombo
  console.log('\n--- C2. Jolly e Portiere: interno colorato, lettera, forma ---')
  const nodi = await inIframe(`
    const K = w.Konva;
    if (!K || !K.stages || !K.stages.length) return {__nokonva: true};
    const out = [];
    K.stages[0].find('Group').forEach(function (g) {
      const tipo = g.getAttr && g.getAttr('dataElement');
      if (!tipo) return;
      let shape = null, txt = null;
      (g.getChildren ? g.getChildren() : []).forEach(function (c) {
        const cn = c.getClassName && c.getClassName();
        if (cn === 'Text') { if (!txt) txt = c } else if (c.fill && !shape) shape = c
      });
      out.push({tipo: tipo,
        forma: shape ? shape.getClassName() : null,
        fill: shape ? String(shape.fill()) : null,
        stroke: shape ? String(shape.stroke()) : null,
        rot_shape: shape ? (shape.rotation() || 0) : null,
        testo: txt ? txt.text() : null,
        testo_fill: txt ? String(txt.fill()) : null,
        testo_fisso: txt ? !!txt.getAttr('fixedFill') : null});
    });
    return out;`)
  ckVero('i nodi Konva della lavagna sono leggibili', Array.isArray(nodi),
    nodi && nodi.__nokonva ? 'Konva.stages non esposto: la misura non puo\' partire' : 'risposta non attesa')
  const nodoDi = t => (Array.isArray(nodi) ? nodi : []).find(n => n.tipo === t)
  for (const [tipo, lettera] of [['player-jolly', 'J'], ['gk', 'P'], ['player-bib', null]]) {
    const n = nodoDi(tipo)
    ckVero(`${tipo}: il nodo e' stato trovato`, !!n, 'nessun nodo con questo dataElement')
    if (!n) continue
    // il cuore della richiesta: riempimento presente e del colore del bordo. 'transparent' = vuoto
    ckVero(`${tipo}: l'interno e' colorato (fill non trasparente)`,
      !!n.fill && n.fill !== 'transparent' && n.fill !== 'null', `fill=${n.fill}`)
    ck(`${tipo}: il riempimento e' dello stesso colore del bordo`, n.fill, n.stroke)
    if (lettera) {
      ck(`${tipo}: la lettera e' '${lettera}', non il numero progressivo`, n.testo, lettera)
      // bianca perche' sta sopra il riempimento colorato; e fissa, altrimenti il selettore colore la
      // ridipingerebbe del colore dell'elemento e sparirebbe sul suo stesso riempimento
      ck(`${tipo}: la lettera e' bianca su fondo colorato`, n.testo_fill, '#ffffff')
      ck(`${tipo}: la lettera e' protetta dal ri-coloramento (fixedFill)`, n.testo_fisso, true)
    }
  }
  const nj = nodoDi('player-jolly')
  ck('il Jolly e un ROMBO come la sua icona e come la miniatura (RegularPolygon, rotazione 0)',
    nj ? `${nj.forma}/${nj.rot_shape}` : 'nodo mancante', 'RegularPolygon/0')

  // ───────────────────────── PARTE D ─────────────────────────
  // Il salvataggio automatico: addEsercizio/updateElementi fanno markDirty + debouncedSave (800 ms),
  // quindi il disegno deve arrivare a `allenamenti.esercizi` SENZA premere niente. Si rilegge con la
  // STESSA API che usa la pagina: il browser dice cosa si vede, il server dice se e' vero
  console.log('\n--- D. il salvataggio automatico porta davvero il disegno al server ---')
  async function leggiDalServer() {
    return await evalJS(`(async () => {
      const t = localStorage.getItem('token');
      const r = await fetch('/api/allenamenti/giorno-by-data/${CAT}/${dataUsata}',
        {headers:{Authorization:'Bearer '+t}});
      if (!r.ok) return {errore: 'http ' + r.status};
      return await r.json();
    })()`, { awaitPromise: true })
  }
  ckVero('la data di prova e\' nota (letta dal titolo della pagina)', !!dataUsata, 'dataUsata e\' null')
  let server = null
  for (let i = 0; i < 40; i++) {
    server = await leggiDalServer()
    const n = server && server.esercizi ? server.esercizi.reduce((s, e) => s + ((e.elementi || []).length), 0) : -1
    if (n >= nTot) break
    await sleep(400)
  }
  ckVero('GET /allenamenti/giorno-by-data risponde', !!(server && !server.errore && server.esercizi), JSON.stringify(server && server.errore))
  ck('a terra c\'e\' un solo esercizio, quello su cui ho disegnato',
    server && server.esercizi ? server.esercizi.length : -1, 1)
  const elServer = server && server.esercizi ? (server.esercizi[0] && server.esercizi[0].elementi) || [] : []
  ck('il server ha gli stessi elementi visti a schermo', elServer.length, nTot)
  const tServer = perTipo(elServer)
  const persiInSalvataggio = Object.keys(tAttesi).filter(t => (tServer[t] || 0) !== tAttesi[t])
  ck('nessun tipo si perde nel salvataggio (la catena getElements)', persiInSalvataggio.length, 0)
  if (persiInSalvataggio.length) console.log('       tipi che NON arrivano al server: ' + diffTipo(tAttesi, tServer))
  // la lista bianca del payload: un campo valorizzato a schermo che arriva null a terra e' un elemento
  // che torna indietro monco, e a schermo c'era
  const campiCritici = ['x', 'y', 'colore']
  const monchi = elServer.filter(e => campiCritici.some(c => e[c] === null || e[c] === undefined))
  ck('nessun elemento arriva a terra con un campo chiave azzerato', monchi.length, 0)
  if (monchi.length) console.log('       esempio: ' + JSON.stringify(monchi[0]))

  // Il CAMPO, non solo il conteggio. Nel payload `elementi` e' una lista bianca di 19 nomi scritti a
  // mano (Allenamenti.vue ~1415, dentro saveDataToServer): un campo rinominato o dimenticato non da'
  // nessun errore, l'elemento parte e quel campo non c'e'. Il conteggio per tipo resta giusto, quindi
  // le asserzioni sopra non lo vedono -- e' il difetto che AGENTS.md chiama "un campo nuovo viene perso
  // in silenzio". Si confronta il valore che la lavagna ha dichiarato con quello che e' atterrato,
  // campo per campo.
  // I due `?? 0` / `?? false` della whitelist dicono che li' undefined e il default SONO la stessa
  // cosa: senza normalizzarli, l'asserzione griderebbe su `wavy` per ogni oggetto che non e' un
  // movimento (la lavagna quel campo non lo mette proprio), e un'asserzione che piange sempre diventa
  // rumore che si impara a ignorare.
  const CAMPI_PAYLOAD = ['tipo','x','y','rotazione','colore','numero','size','w','h','scaleX','scaleY',
                         'x1','y1','x2','y2','points','text','length','wavy']
  const vuotoP = v => v === null || v === undefined
  const DEFAULT_BIANCA = { rotazione: 0, wavy: false }
  const norm = (c, v) => vuotoP(v) ? (c in DEFAULT_BIANCA ? DEFAULT_BIANCA[c] : undefined) : v
  const divergenze = []
  for (let i = 0; i < Math.min(raccolti.length, elServer.length); i++) {
    const a = raccolti[i], b = elServer[i]
    if (a.tipo !== b.tipo) { divergenze.push(`#${i} tipo: schermo=${JSON.stringify(a.tipo)} terra=${JSON.stringify(b.tipo)}`); continue }
    for (const c of CAMPI_PAYLOAD) {
      const va = norm(c, a[c]), vb = norm(c, b[c])
      if (vuotoP(va) && vuotoP(vb)) continue
      if (JSON.stringify(va) !== JSON.stringify(vb)) divergenze.push(`${a.tipo}.${c}: schermo=${JSON.stringify(va)} terra=${JSON.stringify(vb)}`)
    }
  }
  ck('ogni campo della lista bianca arriva a terra identico a schermo', divergenze.length, 0)
  if (divergenze.length) console.log('       campi persi o cambiati: ' + divergenze.slice(0, 6).join(' | '))
  // la premessa che rende significativa l'asserzione qui sopra: se nessuno degli elementi avesse UN
  // solo dei campi oltre a x/y/tipo, il confronto sarebbe verde senza misurare niente
  const conUnCampoInPiu = raccolti.filter(e => CAMPI_PAYLOAD.some(c => !vuotoP(e[c]) && !['tipo','x','y'].includes(c))).length
  ckVero('gli elementi portavano davvero dei campi oltre a tipo/x/y (altrimenti il confronto e' +
    ' vuoto e sarebbe verde per niente)', conUnCampoInPiu > 0, `${conUnCampoInPiu}/${raccolti.length} elementi con un campo di geometria o testo`)

  // ───────────────────────── PARTE E ─────────────────────────
  // Il giro del mister: chiude la pagina, la riapre, riapre l'esercizio. E' qui che muore un tipo
  // dimenticato in loadElement: doLoadElements fa `if(newEl) add(newEl)` e salta IN SILENZIO, senza
  // eccezioni e senza una riga in console
  console.log('\n--- E. richiudi e riapri: gli elementi salvati devono ridipingersi ---')
  const nav2 = await vaiAlMese()
  ckVero('il mese si riapre dopo la ricarica della pagina', nav2.ok, nav2.perche)
  const g2 = await riapriGiorno(dataUsata, nav2.testo || '')
  ckVero('il giorno di prova si riapre', g2.ok, g2.perche)
  const nCard2 = await evalJS(`document.querySelectorAll('.esercizio-card').length`)
  ck('dopo la ricarica gli esercizi ci sono ancora (erano salvati)', nCard2, 1)
  ckVero('la card si riapre', await apriCard(0), 'la card non si e\' aperta')
  await riascolta()
  await sleep(900)
  const ridipinti = await leggiElementi()
  ck('alla riapertura gli elementi ridipinti sono tanti quanti salvati', (ridipinti || []).length, nTot)
  const tRidipinti = perTipo(ridipinti)
  const persiRiaprendo = Object.keys(tAttesi).filter(t => (tRidipinti[t] || 0) !== tAttesi[t])
  ck('nessun tipo si perde alla riapertura (la catena loadElement)', persiRiaprendo.length, 0)
  if (persiRiaprendo.length) {
    console.log('       tipi che NON sopravvivono alla riapertura: ' + diffTipo(tAttesi, tRidipinti))
    await screenshot('riapertura-tipi-persi')
  }
  const fuoriRiapertura = (ridipinti || []).filter(e => !Number.isFinite(e.x) || e.x < 0 || e.x > 100 || !Number.isFinite(e.y) || e.y < 0 || e.y > 100)
  ck('le coordinate sopravvivono alla riapertura restando in campo', fuoriRiapertura.length, 0)

  // ───────────────────────── PARTE F ─────────────────────────
  // loadElements sintetico, sulla lavagna di un SECONDO esercizio (pulita). Serve perche' E misura il
  // giro reale ma non puo' misurare i casi limite: un set ridotto, un tipo sconosciuto, e il guardiano
  // console.log(...) e' dentro il commento perche' il testo conta, non la posizione
  console.log('\n--- F. loadElements sintetico, su una lavagna pulita ---')
  ckVero('si crea un secondo esercizio da usare pulito', await clickBtnAzione('Esercizio'), 'secondo esercizio non creato')
  const nCard3 = await evalJS(`document.querySelectorAll('.esercizio-card').length`)
  ck('il secondo esercizio compare nella lista', nCard3, 2)
  ckVero('si apre il secondo esercizio', await apriCard(nCard3 - 1), 'la seconda card non si e\' aperta')
  await riascolta(); await sleep(900)
  const pulita = await leggiElementi()
  ckVero('la lavagna del secondo esercizio e\' pulita', Array.isArray(pulita) && pulita.length === 0,
    `${Array.isArray(pulita) ? pulita.length : 'nessuna risposta'} elementi`)

  async function caricaEridividi(els) {
    await inIframe(`w.postMessage({type:'loadElements', elements: ${JSON.stringify(els)}, canvasTs: Date.now()},'*'); return 1`)
    await sleep(800)
    return await leggiElementi()
  }
  // 1) CARICAMENTO DIMOSTRATIVO. Se il conteggio non diventa ESATTAMENTE questo, il loadElements non e'
  //    partito e ogni confronto sotto sarebbe verde per inerzia (e' esattamente il falso verde che
  //    questo test ha gia' avuto: la riga 640 rifiutava i caricamenti e 23==23 era "ok")
  // `player-bib` e non `player`: dal 25/11/2026 il tipo `player` non ha piu' il pulsante in palette, quindi
  // il giro C non lo piazza piu' e il filtro sarebbe rimasto vuoto -- un `ckVero` che ferma il test per
  // colpa del test. Serve un tipo che il mister puo' ancora mettere a mano
  const dimostrativo = (raccolti || []).filter(e => e.tipo === 'player-bib').slice(0, 3)
  ckVero('il set dimostrativo ha elementi da caricare', dimostrativo.length > 0, 'nessun Fratinato raccolto: il confronto non misurerebbe niente')
  const caricati = await caricaEridividi(dimostrativo)
  ck('il caricamento avviene DAVVERO (il conteggio diventa quello che ho mandato io)',
    Array.isArray(caricati) ? caricati.length : -1, dimostrativo.length)

  // 2) GIRO COMPLETO di tutti gli strumenti della palette, su una lavagna che non li ha mai avuti
  const ricaricati = await caricaEridividi(JSON.parse(JSON.stringify(raccolti || [])))
  ck('dopo il caricamento gli elementi sono tanti quanti inviati',
    Array.isArray(ricaricati) ? ricaricati.length : -1, nTot)
  const tCaricati = perTipo(ricaricati)
  const persiSintetici = Object.keys(tAttesi).filter(t => (tCaricati[t] || 0) !== tAttesi[t])
  ck('nessun tipo si perde nel caricamento sintetico (loadElement di nuovo)', persiSintetici.length, 0)
  if (persiSintetici.length) console.log('       tipi che NON sopravvivono: ' + diffTipo(tAttesi, tCaricati))

  // 3) un tipo sconosciuto NON deve aggiungersi e soprattutto NON deve portarsi via quelli buoni: e'
  //    il comportamento che protegge chi ha in DB un tipo vecchio o scritto male
  const buoni = (ricaricati || []).slice(0, 3)
  ckVero('ci sono 3 elementi buoni da usare come canarino', buoni.length === 3, `${buoni.length}`)
  const conGuasto = await caricaEridividi(buoni.concat([{ tipo: 'tipo-che-non-esiste', x: 50, y: 50, colore: '#ff0000' }]))
  ck('un tipo sconosciuto non si aggiunge', (conGuasto || []).filter(e => e.tipo === 'tipo-che-non-esiste').length, 0)
  ck('un tipo sconosciuto non si porta via gli elementi buoni', (conGuasto || []).length, 3)

  // 3b) IL VERSO OPPOSTO, ed e' quello che serve ai 132 elementi salvati con i tipi di una versione
  //     vecchia della lavagna (misurato su PROD 25/11/2026: player-red 51, disk-orange 25, player-blue 19,
  //     player-yellow 19, disk-yellow 18). Sopra si asserisce che un tipo SCOMOSCIUTO cada; qui si asserisce
  //     che un tipo CONOSCIUTO dalla mappa `legacyTipi` NON cada: prima di quella mappa questi due oggetti
  //     sparivano in silenzio (doLoadElements fa `if(newEl) add(newEl)`, console.error solo sulle eccezioni),
  //     ne' in campo ne' in miniatura ne' nel PDF. Si misura anche la FORMA del nodo, perche' "esiste" non
  //     basta: player-red deve diventare il Cerchio di un giocatore e disk-orange l'Ellipse di un disco,
  //     non un contorno a caso. Ultima cosa, la piu' costosa se sbagliata: il tipo serializzato resta
  //     QUELLO SALVATO, cosi' nessun salvataggio riscrive il DB al primo apertura della pagina
  const canarini = (conGuasto || []).slice(0, 3)
  ckVero('c\'e\' ancora un canarino buono su cui misurare i legacy', canarini.length === 3, `${canarini.length}`)
  const LEG = [
    { tipo: 'player-red', x: 20, y: 30, rotazione: 0, colore: '#ef4444', size: 44, scaleX: 1, scaleY: 1 },
    { tipo: 'disk-orange', x: 60, y: 70, rotazione: 0, colore: '#f97316', size: 36, scaleX: 1, scaleY: 1 },
  ]
  const conLegacy = await caricaEridividi(canarini.concat(LEG))
  ck('i due tipi legacy NON spariscono (erano 132 invisibili su PROD)',
    Array.isArray(conLegacy) ? conLegacy.length : -1, 5)
  for (const L of LEG) {
    const n = (conLegacy || []).find(e => e.tipo === L.tipo)
    ckVero(`${L.tipo}: arriva a getElements`, !!n, 'il nodo e\' stato buttato via in silenzio')
    if (n) ck(`${L.tipo}: il colore sopravvive`, n.colore, L.colore)
    ck(`${L.tipo}: il tipo serializzato resta quello SALVATO (il DB non viene migrato aprendo la pagina)`,
      (conLegacy || []).filter(e => e.tipo === L.tipo).length, 1)
  }
  const nodiLegacy = await inIframe(`
    const K = w.Konva;
    if (!K || !K.stages || !K.stages.length) return {__nokonva: true};
    const out = {};
    K.stages[0].find('Group').forEach(function (g) {
      const t = g.getAttr && g.getAttr('dataElement');
      if (t !== 'player-red' && t !== 'disk-orange') return;
      const figli = (g.getChildren ? g.getChildren() : []).map(function (c) { return c.getClassName && c.getClassName() });
      out[t] = {figli: figli.join(','), n: figli.length};
    });
    return out;`)
  ckVero('i nodi legacy si leggono dal Konva', nodiLegacy && !nodiLegacy.__nokonva, 'Konva.stages non esposto')
  // il nodo si ricorda il nome SALVATO (loadElement lo rimette dopo createPlayer/createDisc): e' cio' che
  // impedisce la migrazione silenziosa, e senza di esso qui sotto non si troverebbe nulla da confrontare
  ckVero('il nodo Konva di player-red esiste (dataElement conservato)', !!(nodiLegacy && nodiLegacy['player-red']), 'nessun nodo')
  ckVero('il nodo Konva di disk-orange esiste (dataElement conservato)', !!(nodiLegacy && nodiLegacy['disk-orange']), 'nessun nodo')
  // Un giocatore e' un Cerchio + il Text del numero; un disco e' un'Ellipse (+ la cupoletta). Il Text
  // NON e' un dettaglio: `createBall` usa Konva.Circle ESATTAMENTE come createPlayer, quindi chiedere
  // solo "e' un Cerchio" resta verde anche se player-red viene mappato su un pallone -- l'ho misurato,
  // il giro legacy-forma diceva 0 rossi con l'asserzione sul solo Cerchio
  ck('player-red si disegna come un giocatore (Cerchio + il Text del numero)',
    nodiLegacy && nodiLegacy['player-red']
      ? (/Circle/.test(nodiLegacy['player-red'].figli) && /Text/.test(nodiLegacy['player-red'].figli)) : false, true)
  ck('disk-orange si disegna come un disco (Ellipse, non il Cerchio di un pallone)',
    nodiLegacy && nodiLegacy['disk-orange']
      ? (/Ellipse/.test(nodiLegacy['disk-orange'].figli) && !/Circle/.test(nodiLegacy['disk-orange'].figli)) : false, true)

  // 4) IL GUARDIANO (riga 640): con modifiche locali pendenti la lavagna DEVE rifiutare il carico.
  //    E' cio' che impedisce al wrapper di cancellare quello che il mister ha appena disegnato; se
  //    qualcuno lo toglie "perche' non serve", qui si vede.
  //    La modifica si crea col gesto del mister: pulsante della palette + click sul campo, perche' e'
  //    `placeElement` (riga 924) a scrivere canvasModifiedAt, che e' ESATTAMENTE la condizione del
  //    guardiano (`canvasModifiedAt > canvasLoadedAt`). Due trappole, entrambe costate un rosso falso:
  //    (a) la toolbar e' un contenitore scorrevole -- senza scrollIntoView il click sul pulsante non va
  //        a segno, currentTool resta 'select', la lavagna resta pulita e il carico viene accettato;
  //    (b) trascinare un oggetto a caso non funziona: le coordinate del campo sono stage pixel con i
  //        margini propri della lavagna, e il primo elemento puo' essere una zona o una freccia, dove
  //        (x,y) non e' un bersaglio. Un click sul fondo del stage invece no, li' `e.target===stage` e
  //        l'oggetto nasce davvero.
  //    Nessun passaggio e' dato per scontato: che il pulsante sia a segno e che la lavagna si dichiari
  //    modificata si misurano, l'uno sul conteggio degli oggetti e l'altro su canvasTs (canvasModifiedAt)
  //    che la lavagna stessa allega a ogni elementsUpdated. Ultimo perche' sporca la lavagna.
  const primaDelClick = await leggiElementi()
  const nPrima = (primaDelClick || []).length
  const tsPrima = await evalJS('window.__lav.ts')
  async function piazzaUnOggetto(fx, fy) {
    const raggiungibile = await evalJS(`(() => { const f = document.querySelector('.esercizio-card.active iframe');
      if (!f || !f.contentDocument) return false; const b = f.contentDocument.querySelector('.tool-btn[title="Pallone"]');
      if (!b) return false; b.scrollIntoView({ inline: 'center', block: 'nearest' });
      const r = b.getBoundingClientRect(); const d = f.contentDocument.documentElement;
      return r.width > 0 && r.height > 0 && r.left >= 0 && r.top >= 0 && r.right <= d.clientWidth && r.bottom <= d.clientHeight })()`)
    if (!raggiungibile) return null
    await sleep(150)
    const btn = await puntoNellIframe('.tool-btn[title="Pallone"]')
    const campo = await puntoCampo(fx, fy)
    if (!btn || !campo) return null
    await clickReale(btn.x, btn.y); await sleep(250)
    await clickReale(campo.x, campo.y); await sleep(500)
    return await leggiElementi()
  }
  // piu' punti di prova: se il primo cade sopra un oggetto gia' presente, li il click non piazza niente
  let dopoIlClick = null, puntiProvati = 0
  for (const [fx, fy] of [[0.5, 0.5], [0.28, 0.72], [0.72, 0.28], [0.5, 0.82]]) {
    puntiProvati++
    const dopo = await piazzaUnOggetto(fx, fy)
    if (Array.isArray(dopo) && dopo.length > nPrima) { dopoIlClick = dopo; break }
  }
  ckVero('un click a schermo ha creato un oggetto (il test ha toccato la lavagna per davvero)',
    !!dopoIlClick, `${puntiProvati} punti provati, oggetti ${nPrima} -> ${dopoIlClick ? dopoIlClick.length : 'nessun aumento'}`)
  const conModifica = dopoIlClick || await leggiElementi()
  const tsDopo = await evalJS('window.__lav.ts')
  ckVero('dopo il click la lavagna si dichiara modificata (canvasTs avanza)',
    tsDopo > tsPrima, `canvasTs ${tsPrima} -> ${tsDopo}`)
  ck('il click ha aggiunto UN oggetto', (conModifica || []).length, nPrima + 1)
  const tentato = await caricaEridividi([{ tipo: 'cone', x: 12, y: 12, colore: '#22c55e' }])
  ck('con modifiche non salvate il caricamento viene RIFIUTATO (non ti cancella il lavoro)',
    Array.isArray(tentato) ? tentato.length : -1, nPrima + 1)

  // ───────────────────────── PARTE G ─────────────────────────
  const puliti = erroriConsole.filter(e => !/favicon|DevTools|Vue devtools|WebSocket|Failed to load resource|Download the Vue/i.test(e))
  ck('nessun errore in console durante tutto il giro', puliti.length, 0)
  if (puliti.length) console.log('       errori in console: ' + puliti.slice(0, 4).join(' | '))

  const pass = risultati.filter(r => r.ok).length
  const fail = risultati.filter(r => !r.ok).length
  console.log('\n  ' + pass + ' passati, ' + fail + ' falliti, ' + puliti.length + ' errori in console')
  await send('Browser.close').catch(() => {})
  chrome.kill('SIGKILL')
  process.exit(fail ? 1 : 0)
})().catch(e => {
  console.log('  0 passati, 1 falliti (eccezione): ' + (e && e.message ? e.message : e))
  process.exit(1)
})
