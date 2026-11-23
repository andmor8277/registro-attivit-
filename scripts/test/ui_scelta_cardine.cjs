// Verifica UI REALE delle card di Scelta.vue (http://.../scelta/:id) con Chrome headless.
//
// Perche' esiste, accanto ai test API e al build di Vite: il difetto che deve acchiappare e'
// "la card non si vede". Un bundle che CONTIENE la stringa non lo dimostra — la card puo' essere
// nascosta dalla guardia v-if, o la pagina puo' essere bianca per un identificatore orfano nel
// template, e in entrambi i casi il build passa e il grep sul chunk dice "ok". Solo il browser
// risponde alla domanda "un mister, entrato sulla sua categoria, vede o non vede il pulsante?".
//
// Controlla tre cose per volta:
//   1. le card presenti, lette dal testo di .card-label (non dal numero: il numero sarebbe verde
//      anche con le card sbagliate);
//   2. che cliccare "Liste Tornei" porti davvero a /liste-tornei/:id e che la pagina che si apre
//      non sia bianca (un h1 presente e nessun errore in console);
//   3. che in Dati & Matricole il vecchio link a Liste Tornei non ci sia piu', perche' il punto
//      della modifica era toglierlo di li', non aggiungerlo anche qui.
//
// Non si lancia a mano: lo invoca scripts/test/verifica_ui_scelta.sh, che prepara e ripulisce i
// dati demo e passa le credenziali.
//
//   node ui_scelta_cardine.cjs <utente> <password> <categoria_id> <visible|hidden>
//
// "hidden" e' il caso del dirigente: le tre card non le deve vedere, e un test che verificasse
// solo la presenza sarebbe verde anche con la guardia rotta al contrario.

const fs = require('fs')
const { spawn } = require('child_process')

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const USER = process.argv[2]
const PASS = process.argv[3]
const CAT = process.argv[4]
const ATTESA = process.argv[5] || 'visible'   // visible | hidden
const OUT = process.env.THOF_UI_OUT || '/tmp/opencode/ui'
const CHROME = process.env.CHROME || '/usr/bin/google-chrome-stable'
fs.mkdirSync(OUT, { recursive: true })

if (!USER || !PASS || !CAT) {
  console.log('  uso: node ui_scelta_cardine.cjs <utente> <password> <categoria_id> <visible|hidden>')
  process.exit(2)
}

const PORT = Number(process.env.THOF_UI_PORT || 9223)
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
async function goto(url) { await send('Page.navigate', { url }); await sleep(1200) }

// Click VERO dall'input pipeline: el.click() di Runtime.evaluate non e' un gesto utente per Chrome
// e sulle card (che hanno @click sul div) puo' non attivare il handler router
async function clickReale(espressione) {
  const box = await evalJS(`(() => { const el = (${espressione}); if (!el) return null;
    const r = el.getBoundingClientRect(); return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)} })()`)
  if (!box) throw new Error('elemento non trovato per il click: ' + espressione)
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: box.x, y: box.y })
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: box.x, y: box.y, button: 'left', clickCount: 1 })
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: box.x, y: box.y, button: 'left', clickCount: 1 })
}
async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true })
  const p = `${OUT}/${name}.png`
  fs.writeFileSync(p, Buffer.from(r.data, 'base64'))
  return p
}

const risultati = []
function ck(nome, reale, atteso) {
  const ok = String(reale) === String(atteso)
  risultati.push({ ok, nome, reale, atteso })
  console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${nome}${ok ? '' : ` -> '${reale}' (atteso '${atteso}')`}`)
}

// Le card lette PER TESTO, non per indice: l'ordine puo' cambiare, e il numero delle card da solo
// sarebbe verde anche se al posto di "Liste Tornei" ci fosse un'altra card
const LEGGI_CARD = `(() => {
  const card = [...document.querySelectorAll('.scelta-card')]
  return card.map(c => {
    const label = c.querySelector('.card-label')?.innerText.trim() || ''
    const wrap  = c.querySelector('.card-icon-wrap')
    const cs    = wrap ? getComputedStyle(wrap) : null
    return {
      label,
      // una card "c'e'" solo se e' davvero dipinta: display:none o altezza zero non si vedono
      visibile: !!c.offsetParent && c.getBoundingClientRect().height > 20,
      colore: cs ? cs.color : '',
      sfondo: cs ? cs.backgroundImage.slice(0, 40) : ''
    }
  })
})()`

// Le voci della BARRA LATERALE. Vanno verificate a parte, e non e' ridondante con le card: sono due
// superfici diverse, e il difetto reale del 2026-11-23 era esattamente questo — le card di Scelta.vue
// c'erano, le voci di menu no, e chi naviga da sinistra non le ha mai viste. Il menu mobile e' una
// TERZA superficie (l'APK usa quello), e in App.vue e' markup duplicato a mano: aggiungerle solo alla
// sidebar sarebbe una modifica che sul telefono non si vede.
//
// `sel` arriva dal chiamante ma finisce dentro l'espressione: qui NON c'e' nessuna iniezione, i due
// valori sono costanti del file, pero' passarli come lettera nuda (senza apici) darebbe un
// identificatore indefinito e querySelectorAll lancerebbe — errore che sembrerebbe "menu assente".
function exprMenu(sel) {
  return `(() => {
    const sel = ${JSON.stringify(sel)}
    return [...document.querySelectorAll(sel)].map(el => ({
      testo: (el.querySelector('span') || el).innerText.trim().replace(/\\s+/g, ' '),
      visibile: !!el.offsetParent && el.getBoundingClientRect().height > 10
    })).filter(x => x.testo)
  })()`
}

function etichette(lista) { return lista.filter(x => x.visibile).map(x => x.testo) }

async function main() {
  fs.rmSync(`${OUT}/profile-${PORT}`, { recursive: true, force: true })
  const chrome = spawn(CHROME, [
    '--headless=new', `--remote-debugging-port=${PORT}`, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', `--user-data-dir=${OUT}/profile-${PORT}`,
    '--window-size=1180,1500', '--allow-running-insecure-content', '--test-type',
    `--unsafely-treat-insecure-origin-as-secure=${BASE}`,
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

  console.log(`--- accesso come ${USER} (mi aspetto card ${ATTESA}) ---`)
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
    return {ok:true, ruolo: me.ruolo, admin: !!me.is_admin}
  })()`, { awaitPromise: true })
  if (!login || !login.ok) throw new Error('login fallito: ' + JSON.stringify(login))
  console.log(`  ruolo=${login.ruolo} admin=${login.admin}`)

  await goto(`${BASE}/scelta/${CAT}`)
  // aspetta che LE CARD siano dipinte: alla prima lettura si vede lo scheletro e le asserzioni
  // sarebbero verdi senza aver misurato niente
  const pronte = await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelectorAll('.scelta-card').length || ++n > 40) { clearInterval(t); res(document.querySelectorAll('.scelta-card').length) } }, 150) })`,
    { awaitPromise: true })
  if (!pronte) {
    await shot('scelta-vuota')
    throw new Error('nessuna card dipinta su /scelta/' + CAT + ': pagina vuota o bianca (screenshot scelta-vuota.png)')
  }

  let card = await evalJS(LEGGI_CARD)
  const viste = card.filter(c => c.visibile).map(c => c.label)
  console.log('   card visibili:', viste.join(' | '))

  const TRE = ['Convocazioni', 'Convocazioni Tornei', 'Liste Tornei']
  const atteso = ATTESA === 'visible' ? 'si' : 'no'

  // Il caso "hidden" va blindato, perche' e' il posto dove il test si mente da solo: una pagina
  // bianca, o una categoria che non si e' caricata (il v-if="!categoria" nasconde la griglia),
  // rende "non la vede" vero per il motivo SBAGLIATO. Le due card senza guardia sul ruolo sono la
  // prova che la pagina e' dipinta davvero e che sono state le guardie a nascondere le tre.
  const TESTIMONI = ['Presenze', 'Dati & Matricole']
  for (const nome of TESTIMONI) {
    ck(`pagina dipinta: la card "${nome}" c'e'`, viste.includes(nome) ? 'si' : 'no', 'si')
  }
  if (ATTESA === 'hidden') {
    ck("ruolo non-mister riconosciuto (Presenze c'e', Allenamenti no)",
       viste.includes('Presenze') && !viste.includes('Allenamenti') ? 'si' : 'no', 'si')
  }

  for (const nome of TRE) {
    ck(`card "${nome}" visibile`, viste.includes(nome) ? 'si' : 'no', atteso)
  }

  // --- le voci della barra laterale (desktop) ---
  // Sono la superficie che l'utente usa davvero per navigare, e il difetto nato qui e' proprio
  // questo: card presenti, voci di menu assenti. Verificarle non e' ridondante con le card.
  const laterale = await evalJS(exprMenu('.side-item'))
  const etichetteLaterale = etichette(laterale)
  console.log('   sidebar:', etichetteLaterale.join(' | '))
  ck(`"Convocazioni" c'e' nella sidebar (testimone: il menu e' dipinto)`,
     etichetteLaterale.includes('Convocazioni') ? 'si' : 'no', 'si')
  for (const nome of ['Convocazioni Tornei', 'Liste Tornei']) {
    ck(`voce di sidebar "${nome}"`, etichetteLaterale.includes(nome) ? 'si' : 'no', atteso)
  }

  // --- il menu MOBILE, che e' quello che l'APK usa ---
  // In App.vue e' markup duplicato a mano rispetto alla sidebar: puo' essere aggiornato a meta', e
  // e' la superficie su cui il titolare guarda il sito dal telefono. Senza override del viewport
  // Chrome vede 1180px, la bottom-nav e' display:none e il menu non esiste nel DOM: l'asserzione
  // sarebbe verde "perche' non c'e' niente da vedere", il che e' il peggior falso verde possibile.
  //
  // Il pulsante che lo apre NON e' l'hamburger: `.hamburger` e' display:none SIA sopra sia sotto i
  // 768px (la regola base a fine file e un'altra dentro @media (max-width: 768px)), quindi non e'
  // mai cliccabile. Aprite il menu e' il pulsante "Menu" della bottom-nav, che fa lo stesso
  // mobileMenuOpen = true. Cercare l'hamburger darebbe un rosso sul TEST, non sull'app.
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true })
  await sleep(600)
  const bottom = await evalJS(exprMenu('.bottom-nav-item'))
  const etichetteBottom = etichette(bottom)
  console.log('   bottom-nav:', etichetteBottom.join(' | '))
  ck('su viewport da telefono la bottom-nav c\'e\' (altrimenti il menu mobile non si puo\' aprire e ' +
     'le asserzioni sotto non misurerebbero niente)', etichetteBottom.includes('Menu') ? 'si' : 'no', 'si')
  if (etichetteBottom.includes('Menu')) {
    await clickReale(`[...document.querySelectorAll('.bottom-nav-item')].find(b => (b.querySelector('span')||b).innerText.trim() === 'Menu')`)
    await sleep(800)
    const mobile = await evalJS(exprMenu('.mobile-menu-item'))
    const etichetteMobile = etichette(mobile)
    console.log('   menu mobile:', etichetteMobile.join(' | '))
    ck(`"Convocazioni" c'e' nel menu mobile (testimone)`,
       etichetteMobile.includes('Convocazioni') ? 'si' : 'no', 'si')
    for (const nome of ['Convocazioni Tornei', 'Liste Tornei']) {
      ck(`voce nel menu mobile "${nome}"`, etichetteMobile.includes(nome) ? 'si' : 'no', atteso)
    }
    await shot(`menu-mobile-${USER}`)
  }
  await send('Emulation.clearDeviceMetricsOverride')
  // Ricarica vera: mobileMenuOpen e' una ref di App.vue e sopravvive al cambio di rotta, quindi
  // senza un navigate l'overlay resterebbe aperto sopra i click e gli screenshot successivi.
  await goto(`${BASE}/scelta/${CAT}`)
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelectorAll('.scelta-card').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })`, { awaitPromise: true })

  if (ATTESA === 'visible') {
    // le tre card della stessa giornata devono essere riconoscibili anche dal colore: due uguali
    // sembrano la stessa funzione duplicata
    const c1 = card.find(c => c.label === 'Convocazioni')
    const c2 = card.find(c => c.label === 'Convocazioni Tornei')
    const c3 = card.find(c => c.label === 'Liste Tornei')
    ck('Liste Tornei ha un colore suo, diverso da Convocazioni', c1 && c3 && c1.colore !== c3.colore ? 'si' : 'no', 'si')
    ck('Liste Tornei ha un colore suo, diverso da Convocazioni Tornei', c2 && c3 && c2.colore !== c3.colore ? 'si' : 'no', 'si')
    await shot('scelta-card')

    // PRIMA di cliccare: il click porta via dalla pagina, e se la card manca clickReale lancia e
    // l'esecuzione si interrompe li'. Mettendo questo controllo dopo, la mutazione "card rimossa"
    // avrebbe nascosto anche il rosso sul link vecchio, e un rosso che ne copre un altro non e'
    // attribuibile a niente.
    console.log('--- in Dati & Matricole il vecchio link non c\'e\' piu\' ---')
    await goto(`${BASE}/dati/${CAT}`)
    await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
      if (document.querySelector('table') || ++n > 40) { clearInterval(t); res(true) } }, 150) })`, { awaitPromise: true })
    const link = await evalJS(`(() => {
      const a = [...document.querySelectorAll('a[href*="liste-tornei"]')]
      return {n: a.length, testi: a.map(x => x.innerText.trim())}
    })()`)
    console.log('   link a liste-tornei trovati:', JSON.stringify(link))
    ck('nessun link "Liste Tornei" in Dati & Matricole', link.n, 0)
    await shot('dati-matricole')

    console.log('--- clicco "Liste Tornei" ---')
    await goto(`${BASE}/scelta/${CAT}`)
    await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
      if ([...document.querySelectorAll('.scelta-card')].some(c => c.querySelector('.card-label')?.innerText.trim() === 'Liste Tornei') || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
      { awaitPromise: true })
    await clickReale(`[...document.querySelectorAll('.scelta-card')].find(c => c.querySelector('.card-label')?.innerText.trim() === 'Liste Tornei')`)
    await sleep(1800)
    const dopo = await evalJS(`(() => ({
      url: location.pathname,
      h1: document.querySelector('h1')?.innerText.trim() || null,
      corpo: (document.body.innerText || '').length
    }))()`)
    console.log('   dopo il click:', JSON.stringify(dopo))
    ck('porta a /liste-tornei/' + CAT, dopo.url, '/liste-tornei/' + CAT)
    ck('la pagina che si apre non e\' bianca (h1 presente)', !!dopo.h1 ? 'si' : 'no', 'si')
    ck('il testo della pagina non e\' vuoto', dopo.corpo > 200 ? 'si' : 'no', 'si')
    await shot('liste-tornei-aperta')
  }

  console.log('--- console della pagina ---')
  const rumorosi = erroriConsole.filter(e => !/favicon|DownloadBundle|insecure|DevTools/i.test(e))
  ck('nessun errore in console', rumorosi.length, 0)
  if (rumorosi.length) rumorosi.slice(0, 5).forEach(e => console.log('     !', e.slice(0, 160)))

  const rossi = risultati.filter(r => !r.ok).length
  console.log(`\n  ${risultati.length - rossi} passati, ${rossi} falliti`)
  return rossi === 0 ? 0 : 1
}

main().then(c => { try { require('child_process').execSync(`pkill -f remote-debugging-port=${PORT}`) } catch (e) {} ; process.exit(c) })
        .catch(e => { console.log('  ERRORE:', e.message); try { require('child_process').execSync(`pkill -f remote-debugging-port=${PORT}`) } catch (x) {} ; process.exit(1) })
