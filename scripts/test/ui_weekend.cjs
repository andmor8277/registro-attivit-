// Verifica UI reale dei PDF di Programmazione Partite (il weekend), nata insieme alla condivisione
// del formato: intestazione e stile di tabella sono passati in core/utils/pdfTHOF.js perche' il
// calendario del weekend e quello dei tornei sono lo stesso tipo di documento, e due copie del foglio
// di stile sono due documenti che il giorno dopo non si assomigliano piu'.
//
// Ma condividere il codice senza misurare l'output e' esattamente il rischio che si voleva chiudere:
// qui si esportano DUE documenti dalla stessa pagina (weekend e genitori) e UN terzo dalla pagina dei
// tornei, e si asserisce che abbiano la STESSA forma. Se qualcuno riscrive l'intestazione di una sola
// delle due pagine, questo file diventa rosso.
//
// Non si lancia a mano: lo invoca scripts/test/verifica_ui_weekend.sh, che crea e ripulisce i dati di
// prova (li usa anche la pagina Tornei, da cui si esporta il documento di confronto).
const fs = require('fs')
const { spawn } = require('child_process')

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const USER = process.argv[2]
const PASS = process.argv[3]
const OUT = process.env.THOF_UI_OUT || '/tmp/opencode/ui'
fs.mkdirSync(OUT, { recursive: true })

// Dati di DEV che questo file legge davvero (weekend id=1 'test', 2026-10-03/04, due partite della
// categoria 19, una in casa e una fuori, mister 8 e 12). Se li cambi, cambia anche le attese sotto
const NOME_WEEKEND = 'test'
const NOME_DEMO = '__demo_tornei__-WINTER CUP'

const PORT = 9223   // porta diversa da ui_tornei.cjs: i due file possono girare uno dopo l'altro
let ws, nextId = 1
const pending = new Map()
const erroriConsole = []

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
async function goto(url) { await send('Page.navigate', { url }); await sleep(1400) }

// Click VERO dall'input pipeline: Chrome blocca il download del blob se non c'e' un gesto utente
// reale, e non scrive nessun errore in console (vedi ui_tornei.cjs, dove e' costato un falso verde)
async function clickReale(espressione) {
  const box = await evalJS(`(() => { const el = (${espressione}); if (!el) return null;
    const r = el.getBoundingClientRect(); return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)} })()`)
  if (!box) throw new Error('elemento non trovato per il click: ' + espressione)
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: box.x, y: box.y })
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: box.x, y: box.y, button: 'left', clickCount: 1 })
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: box.x, y: box.y, button: 'left', clickCount: 1 })
}
const erroreSchermo = () => evalJS(`document.querySelector('.messaggio.errore')?.innerText.trim() || null`)

const risultati = []
function ck(nome, reale, atteso) {
  const ok = String(reale) === String(atteso)
  risultati.push({ ok, nome, reale, atteso })
  console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${nome}${ok ? '' : ` -> '${reale}' (atteso '${atteso}')`}`)
}
const piatto = t => String(t == null ? '' : t).replace(/\s+/g, ' ')
const primaRiga = t => String(t == null ? '' : t).split('\n').find(l => l.trim()) || ''

;(async () => {
  // Profilo cancellato a ogni run: lo stato di Safe Browsing e' persistente nel profilo e ha gia'
  // reso lo stesso export verde un giorno e rosso quello dopo
  fs.rmSync(`${OUT}/profile-weekend`, { recursive: true, force: true })
  const chrome = spawn('/usr/bin/google-chrome-stable', [
    '--headless=new', `--remote-debugging-port=${PORT}`, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', `--user-data-dir=${OUT}/profile-weekend`,
    '--window-size=1180,1500',
    '--allow-running-insecure-content', '--test-type', '--safebrowsing-disable-download-protection',
    `--unsafely-treat-insecure-origin-as-secure=${BASE}`,
    '--disable-features=InsecureDownloadWarnings,DownloadBubble,DownloadBubbleV2',
    'about:blank'
  ], { stdio: 'ignore' })
  process.on('exit', () => { try { chrome.kill('SIGKILL') } catch (e) {} })

  let target = null
  for (let i = 0; i < 60; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json()
      target = list.find(t => t.type === 'page')
      if (target) break
    } catch (e) {}
    await sleep(500)
  }
  if (!target) throw new Error('Chrome non espone un target page')

  ws = new WebSocket(target.webSocketDebuggerUrl)
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej })
  ws.onmessage = ev => {
    const m = JSON.parse(ev.data)
    if (m.id && pending.has(m.id)) {
      const p = pending.get(m.id); pending.delete(m.id)
      m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result)
    } else if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') {
      erroriConsole.push(m.params.args.map(a => a.value ?? a.description ?? a.type).join(' '))
    } else if (m.method === 'Log.entryAdded' && m.params.entry.level === 'error') {
      erroriConsole.push(m.params.entry.text)
    }
  }
  await send('Runtime.enable'); await send('Log.enable'); await send('Page.enable')

  console.log('--- accesso come responsabile ---')
  await goto(`${BASE}/login`)
  const login = await evalJS(`(async () => {
    const r = await fetch('/api/auth/token', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'},
      body: new URLSearchParams({username: ${JSON.stringify(USER)}, password: ${JSON.stringify(PASS)}})})
    if (!r.ok) return {errore: 'token http ' + r.status}
    const {access_token} = await r.json()
    const me = await (await fetch('/api/auth/me', {headers:{Authorization:'Bearer '+access_token}})).json()
    localStorage.setItem('token', access_token)
    localStorage.setItem('utente_data', JSON.stringify(me))
    localStorage.setItem('thof_last_activity', Date.now().toString())
    if (me.is_admin) localStorage.setItem('is_admin','1')
    if (me.societa_id) {
      try {
        const s = await (await fetch('/api/societa/' + me.societa_id, {headers:{Authorization:'Bearer '+access_token}})).json()
        localStorage.setItem('societa_data', JSON.stringify(s))
      } catch (e) {}
    }
    return {ok:true, admin: !!me.is_admin, societa: me.societa_id,
            societaNome: (JSON.parse(localStorage.getItem('societa_data') || '{}').nome || '')}
  })()`, { awaitPromise: true })
  if (!login || !login.ok) throw new Error('login fallito: ' + JSON.stringify(login))
  const SOC = login.societaNome
  console.log(`  accesso: admin=${login.admin} societa=${login.societa} nome=${JSON.stringify(SOC)}`)
  ck('la pagina conosce il nome della societa', String(SOC || '').length > 0, true)

  const DL = `${OUT}/download-weekend`
  const { execFileSync } = require('child_process')
  await send('Page.setDownloadBehavior', { behavior: 'allow', downloadPath: DL })
  await send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: DL }).catch(() => {})
  async function scarica(nome, espressioneElemento) {
    fs.mkdirSync(DL, { recursive: true })
    for (const f of fs.readdirSync(DL)) fs.rmSync(`${DL}/${f}`, { recursive: true, force: true })
    await clickReale(espressioneElemento)
    const atteso = `${DL}/${nome}`
    for (let i = 0; i < 60; i++) {
      if (fs.existsSync(atteso) && fs.statSync(atteso).size > 500) {
        await sleep(400)
        const testo = execFileSync('pdftotext', ['-layout', atteso, '-'], { encoding: 'utf8' })
        if (process.env.DUMP_PDF) {
          fs.mkdirSync(`${OUT}/pdf-text`, { recursive: true })
          fs.writeFileSync(`${OUT}/pdf-text/testo-${nome}.txt`, testo)
        }
        return testo
      }
      await sleep(250)
    }
    console.log('   perche\' nessun file:', await erroreSchermo(), '| cartella:', fs.readdirSync(DL).join(','),
                '| console:', erroriConsole.filter(e => !/favicon|DevTools|Download the Vue/i.test(e)).slice(-3).join(' // ') || 'pulita')
    return null
  }

  console.log('--- apro il weekend ---')
  await goto(`${BASE}/responsabili/partite`)
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelectorAll('.weekend-card').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
  const nWeekend = await evalJS(`document.querySelectorAll('.weekend-card').length`)
  ck('la lista dei weekend non e\' vuota (altrimenti le asserzioni sotto non misurano niente)', nWeekend > 0, true)
  await clickReale(`[...document.querySelectorAll('.weekend-card')].find(c => /${NOME_WEEKEND}/.test(c.innerText))`)
  await sleep(1200)
  ck('il weekend e\' aperto con le sue partite',
     await evalJS(`document.querySelectorAll('.partita-item, .partita-row, .partite-list > *').length`) > 0, true)

  const btnWeekend = `[...document.querySelectorAll('.weekend-actions .btn-secondary-sm')].find(b => /Esporta PDF$/.test(b.innerText.trim()))`
  const btnGenitori = `[...document.querySelectorAll('.weekend-actions .btn-secondary-sm')].find(b => /PDF Genitori/.test(b.innerText))`
  ck('i due pulsanti di export ci sono',
     (await evalJS(`!!${btnWeekend}`)) + '/' + (await evalJS(`!!${btnGenitori}`)), 'true/true')

  const nomeFileWeekend = `${NOME_WEEKEND.replace(/\s+/g, '_').toLowerCase()}_${String(SOC).replace(/\s+/g, '_').toLowerCase()}.pdf`
  const pdfWeekend = await scarica(nomeFileWeekend, btnWeekend)
  ck('il PDF del weekend si scarica', pdfSeScaricato(pdfWeekend), true)
  const w = piatto(pdfWeekend)
  ck('il titolo e\' "<weekend> - <societa>", la forma che la societa\' conosce',
     primaRiga(pdfWeekend).includes(`${NOME_WEEKEND} - ${SOC}`), true)
  ck('il sottotitolo ha le date del weekend', /03\/10\/2026/.test(w) && /04\/10\/2026/.test(w), true)
  ck('e dice quando e\' stato generato', /Generato il \d{1,2}\/\d{1,2}\/\d{4}/.test(w), true)
  ck('le colonne sono quelle del calendario del weekend',
     ['Data', 'Ora', 'Avversario', 'Livello', 'Campo', 'Indirizzo', 'Mister']
       .every(c => new RegExp('\\b' + c + '\\b').test(w)), true)
  ck('la barra di categoria e\' dentro la tabella, col suo titolo', /2016 - Pulcini/.test(w), true)
  ck('Casa e Trasferta sono disegnate (la colonna C/T non resta vuota)',
     /Casa/.test(w) && /Trasferta/.test(w), true)
  ck('la domenica e\' marcata, perche\' e\' quella che i genitori guardano', /\(DOM\)/.test(w), true)
  ck('il mister di ogni partita e\' nominato (non resta N/D)',
     /GRILLO/.test(w) && /ANDREUCCIOLI/.test(w), true)
  ck('e i livelli delle due partite ci sono', /Medio/.test(w) && /Basso/.test(w), true)

  console.log('--- il PDF per i genitori ---')
  const pdfGenitori = await scarica(`${NOME_WEEKEND.replace(/\s+/g, '_').toLowerCase()}_${String(SOC).replace(/\s+/g, '_').toLowerCase()}_genitori.pdf`, btnGenitori)
  ck('si scarica', pdfSeScaricato(pdfGenitori), true)
  const g = piatto(pdfGenitori)
  ck('ha lo stesso titolo del documento completo',
     primaRiga(pdfGenitori).includes(`${NOME_WEEKEND} - ${SOC}`), true)
  ck('ma non la colonna Livello, che ai genitori non serve', /\bLivello\b/.test(g), false)
  ck('e tiene la colonna Mister, che serve eccome', /\bMister\b/.test(g), true)

  console.log('--- i DUE documenti devono assomigliarsi: e\' il motivo del modulo condiviso ---')
  // Si esporta anche dalla pagina Tornei (i dati demo c'e' li ha messi il wrapper) e si confronta la
  // forma. Senza questo confronto, condividere il codice non prova niente: due pagine potrebbero
  // importare lo stesso modulo e poi riscriversi il titolo una per conto proprio
  await goto(`${BASE}/responsabili/tornei`)
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelectorAll('.torneo-card').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
  const btnTorneo = `[...document.querySelectorAll('.categoria-sezione')].find(x => /Pulcini/.test(x.querySelector('.categoria-intestazione').innerText))` +
                    `.querySelector('.torneo-card .btn-esporta')`
  const pdfTornei = await scarica(`tornei_demo_tornei___winter_cup_2016_pulcini_${String(SOC).replace(/[^\w]+/g, '_').toLowerCase()}.pdf`, btnTorneo)
  ck('il PDF dei tornei si scarica (confronto di forma)', pdfSeScaricato(pdfTornei), true)
  ck('entrambi i documenti chiudono il titolo con il nome della societa\'',
     primaRiga(pdfWeekend).trim().endsWith(`- ${SOC}`) && primaRiga(pdfTornei).trim().endsWith(`- ${SOC}`), true)
  ck('entrambi dichiarano la data di generazione nel sottotitolo',
     /Generato il/.test(piatto(pdfWeekend)) && /Generato il/.test(piatto(pdfTornei)), true)
  ck('entrambi usano la barra di categoria rossa con lo stesso formato "anno - nome"',
     /2016 - Pulcini/.test(piatto(pdfWeekend)) && /2016 - Pulcini/.test(piatto(pdfTornei)), true)
  ck('entrambi hanno la colonna Mister (nel torneo e\' una colonna, non una riga a parte)',
     /\bMister\b/.test(piatto(pdfWeekend)) && /\bMister\b/.test(piatto(pdfTornei)), true)

  console.log('\n--- console della pagina ---')
  const reali = erroriConsole.filter(e => !/favicon|DevTools|Download the Vue|Failed to load resource: the server responded with a status of 40/i.test(e))
  if (!reali.length) console.log('  nessun errore in console')
  else reali.forEach(e => console.log('  ERRORE:', e))

  const passati = risultati.filter(r => r.ok).length
  const falliti = risultati.filter(r => !r.ok).length
  console.log(`\n  ${passati} passati, ${falliti} falliti, ${reali.length} errori in console`)
  await send('Browser.close').catch(() => {})
  chrome.kill('SIGKILL')
  process.exit(falliti || reali.length ? 1 : 0)
})().catch(e => {
  console.error('ERRORE FATALE:', e && e.stack || e)
  try { require('child_process').execSync(`pkill -f remote-debugging-port=${PORT}`) } catch (x) {}
  process.exit(2)
})

// Un download che non arriva e' null; un file mezzo scritto non lo e'. La differenza conta, perche'
// "il PDF non si scarica" e "il PDF non contiene X" sono due guasti diversi
function pdfSeScaricato(t) { return t !== null && String(t).length > 0 }
