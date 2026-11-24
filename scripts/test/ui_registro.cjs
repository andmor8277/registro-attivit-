// Verifica UI REALE del Registro presenze (http://.../registro/:id) con Chrome headless, sul
// viewport VERTICALE di un telefono (390x844).
//
// Perche' esiste. La modifica da difendere e' questa: il registro e' una tabella persone x giorni di
// allenamento, ~13 colonne, e per questo la pagina copriva se stessa con un overlay "ruota il
// dispositivo in orizzontale". Ora c'e' una VISTA SETTIMANA che dipinge solo i giorni di allenamento
// della settimana, e l'overlay qui non c'e' piu'. E' una modifica che il build di Vite non vede in
// NESSUNA delle sue forme:
//   - se le colonne visibili fossero ancora quelle del mese, il build passerebbe e il grep sul chunk
//     direbbe "Settimana c'e'" (il pulsante c'e' davvero) -- ma sul telefono andrebbe ancora ruotato;
//   - se il foglio di stampa scivolasse dietro la vista settimana, a schermo tutto sarebbe giusto e
//     il mister si accorgerebbe in segreteria di un foglio "Registro di Novembre" con dentro una
//     settimana sola: plausibile e falso;
//   - se la settimana che sconfinà nel mese accanto cercasse le celle per NUMERO di giorno, il 30
//     novembre leggerebbe le presenze del 30 dicembre: due numeri identici, due date diverse, nessun
//     errore da nessuna parte.
//
// Le ultime due sono le asserzioni che contano, e nessuna delle due si fa dal sorgente.
//
// Cosa becca, in ordine:
//   A. nessun overlay "ruota il dispositivo", toggle su "Settimana" di default a 390px, e la tabella
//      STA dentro la larghezza del telefono senza scroll orizzontale;
//   B. "Mese" ridà tutte le colonne del mese (e non e' lo stesso numero di A);
//   C. la settimana a cavallo di due mesi: il mese sotto il numero del giorno, la cella del mese
//      ACCANTO popolata (riga seminata dal wrapper via SQL) e il TOT di riga che conta il MESE e non
//      la settimana;
//   D. il foglio di stampa, aperto MENTRE lo schermo e' in vista settimana: conserva le colonne del
//      mese e i codici del mese;
//   E. scrivere sulla cella del mese accanto: il modal dice la data vera e il codice appare a schermo
//      (il wrapper asserisce sul DB che e' atterrato su QUELLA data e non sul giorno omonimo);
//   F. dopo una ricarica vera la cella scrive ancora li'.
//
// Non si lancia a mano: lo invoca scripts/test/verifica_ui_registro.sh, che crea gli utenti demo,
// semina le righe nel DB e le ripristina dallo snapshot. I dati della settimana a cavallo arrivano
// dal wrapper come variabili d'ambiente: NON se li sceglie questo file, perche' il DB viene preparato
// per UNA settimana precisa e sceglierne un'altra qui darebbe asserzioni verdi sul niente.
//
//   node ui_registro.cjs <utente> <password> <categoria_id>

const fs = require('fs')
const { spawn } = require('child_process')

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const USER = process.argv[2]
const PASS = process.argv[3]
const CAT = process.argv[4]
const OUT = process.env.THOF_UI_OUT || '/tmp/opencode/ui-registro'
const CHROME = process.env.CHROME || '/usr/bin/google-chrome-stable'
const PORT = Number(process.env.THOF_UI_PORT || '9231')

// ── cosa ha deciso il wrapper (e ha scritto nel DB) ───────────────────────────────
const LUN_CROSS = process.env.LUN_CROSS            // AAAA-MM-GG: lunedi' della settimana a cavallo
const AVANTI = Number(process.env.SETTIMANE_AVANTI || '0')
const DATA_ADJ = process.env.DATA_ADJACENTE        // AAAA-MM-GG: giorno di allenamento NEL MESE ACCANTO
const DATA_MESE = process.env.DATA_MESE            // AAAA-MM-GG: giorno di allenamento NEL MESE della settimana
const MESE_ATTESO = process.env.MESE_ATTESO        // AAAA-MM: il mese della settimana = quello del giovedi'
const SEED_NOME = process.env.SEED_NOME            // "COGNOME NOME" del ragazzo con le due righe seminate
const SEED_TOT = process.env.SEED_TOT              // TOT atteso sulla sua riga = SOLO le righe del mese
const SCRIVI_NOME = process.env.SCRIVI_NOME        // "COGNOME NOME" sul quale scrivere a schermo
const CODICE = process.env.SEED_CODICE || 'X'

const MANCANTI = [['LUN_CROSS', LUN_CROSS], ['SETTIMANE_AVANTI', process.env.SETTIMANE_AVANTI],
  ['DATA_ADJACENTE', DATA_ADJ], ['DATA_MESE', DATA_MESE], ['MESE_ATTESO', MESE_ATTESO],
  ['SEED_NOME', SEED_NOME], ['SEED_TOT', SEED_TOT], ['SCRIVI_NOME', SCRIVI_NOME]]
  .filter(kv => !kv[1]).map(kv => kv[0])
if (!USER || !PASS || !CAT || MANCANTI.length) {
  console.log('  uso: node ui_registro.cjs <utente> <password> <categoria_id>')
  console.log('  e le variabili LUN_CROSS SETTIMANE_AVANTI DATA_ADJACENTE DATA_MESE MESE_ATTESO ' +
              'SEED_NOME SEED_TOT SCRIVI_NOME' + (MANCANTI.length ? ' -- mancano: ' + MANCANTI.join(', ') : ''))
  // 2 e non 1: "mi mancano i prerequisiti" non e' un test fallito, e il wrapper deve distinguerli
  process.exit(2)
}

fs.mkdirSync(OUT, { recursive: true })

const MESI_CORTI = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic']
const MESI_LUNGHI = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio',
  'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre']
function parti(iso) {
  const p = iso.split('-').map(Number)
  return { a: p[0], m: p[1], g: p[2], corto: MESI_CORTI[p[1] - 1], lungo: MESI_LUNGHI[p[1] - 1] }
}
const ADJ = parti(DATA_ADJ)
const MES = parti(DATA_MESE)
const MESE_FOLIO_NUM = Number(MESE_ATTESO.split('-')[1])
const MESE_FOLIO_ANNO = Number(MESE_ATTESO.split('-')[0])

const PORT_W = 390, PORT_H = 844

let ws, nextId = 1
const pending = new Map()
const erroriConsole = []

function send(method, params) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    ws.send(JSON.stringify({ id, method, params: params || {} }))
  })
}
const sleep = ms => new Promise(r => setTimeout(r, ms))

async function evalJS(expression, opts) {
  const awaitPromise = !!(opts && opts.awaitPromise)
  const r = await send('Runtime.evaluate', { expression, awaitPromise, returnByValue: true })
  if (r.exceptionDetails) {
    throw new Error('ECCEZIONE IN PAGINA: ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text))
  }
  return r.result.value
}
async function goto(url) { await send('Page.navigate', { url }); await sleep(1400) }

// Click VERO dalla pipeline input: sulle celle c'e' @click, e un el.click() di Runtime.evaluate non
// e' un gesto utente per Chrome -- sulla cella sbagliata sembrerebbe "la cella non risponde"
async function clickReale(espressione) {
  const box = await evalJS('(() => { const el = (' + espressione + '); if (!el) return null; ' +
    'const r = el.getBoundingClientRect(); if (!r.width || !r.height) return null; ' +
    'return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)} })()')
  if (!box) throw new Error('elemento non trovato o non visibile per il click: ' + espressione)
  await clickPunto(box.x, box.y)
}
async function clickPunto(x, y) {
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x, y: y })
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: x, y: y, button: 'left', clickCount: 1 })
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x, y: y, button: 'left', clickCount: 1 })
}
async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true })
  const p = OUT + '/' + name + '.png'
  fs.writeFileSync(p, Buffer.from(r.data, 'base64'))
  return p
}
// aspetta una condizione a schermo. Il "prima" di ogni lettura va SEMPRE aspettato: leggere lo
// scheletro renderebbe verdi asserzioni che non hanno misurato niente
async function attendi(expr, opts) {
  const tentativi = (opts && opts.tentativi) || 60
  const ogni = (opts && opts.ogni) || 150
  const cosa = (opts && opts.cosa) || 'condizione'
  const ok = await evalJS('new Promise(res => { let n=0; const t=setInterval(() => { ' +
    'if ((' + expr + ') || ++n > ' + tentativi + ') { clearInterval(t); res(!!(' + expr + ')) } }, ' + ogni + ') })',
    { awaitPromise: true })
  if (!ok) throw new Error('attesa esaurita: ' + cosa)
  return true
}

const risultati = []
function ck(nome, reale, atteso) {
  const ok = String(reale) === String(atteso)
  risultati.push({ ok: ok, nome: nome, reale: reale, atteso: atteso })
  console.log('  ' + (ok ? 'ok  ' : 'FAIL') + ' ' + nome + (ok ? '' : " -> '" + reale + "' (atteso '" + atteso + "')"))
}
function ckmin(nome, reale, soglia) {
  const ok = Number(reale) >= Number(soglia)
  risultati.push({ ok: ok, nome: nome, reale: reale, atteso: '>= ' + soglia })
  console.log('  ' + (ok ? 'ok  ' : 'FAIL') + ' ' + nome + ' (' + reale + ', soglia ' + soglia + ')')
}

// ── letture dalla pagina ──────────────────────────────────────────────────────────
// `norm` normalizza il testo SENZA regex letterali: dentro una stringa passata a Runtime.evaluate un
// backslash di troppo produce un'espressione che non compila nella pagina, e l'errore sembrerebbe
// dell'app. String.fromCharCode(9,10,13,32) = tab, a capo, rientro, spazio.
const NORM = "const norm = s => (s || '').replace(new RegExp('[' + String.fromCharCode(9,10,13,32) + ']+','g'),' ').trim().toUpperCase(); "
const NOME = '(tr.querySelector(".persona-name") || tr.querySelector(".td-nome") || {})'

// Le colonne-giorno si riconoscono perche' hanno .giorno-num DENTRO il th (le colonne fisse #,
// Cognome Nome e TOT no). Contare i th e non i td: se una colonna viene omessa, il th manca.
function exprTabella(nome) {
  return '(() => { ' + NORM +
    'const cerca = norm(' + JSON.stringify(nome || '') + '); ' +
    'const tabelle = [...document.querySelectorAll("table")]; ' +
    'const tabella = tabelle.find(t => [...t.querySelectorAll("tbody tr")].some(tr => norm(' + NOME + '.innerText) === cerca)); ' +
    'if (!tabella) return { trovata: false, tabelle: tabelle.length }; ' +
    'const th = [...tabella.querySelectorAll("thead th")].filter(x => x.querySelector(".giorno-num")); ' +
    'const riga = [...tabella.querySelectorAll("tbody tr")].find(tr => norm(' + NOME + '.innerText) === cerca); ' +
    'const td = [...riga.querySelectorAll("td")]; ' +
    'const wrap = tabella.parentElement; ' +
    'return { trovata: true, colonne: th.length, ' +
    'giorni: th.map(x => ({ num: ((x.querySelector(".giorno-num") || {}).innerText || "").trim(), ' +
      'gg: ((x.querySelector(".giorno-nome") || {}).innerText || "").trim(), ' +
      'mese: ((x.querySelector(".giorno-mese") || {}).innerText || "").trim() })), ' +
    'celle: th.map((_, i) => td[2 + i] ? (td[2 + i].innerText || "").trim() : null), ' +
    'tot: ((td[td.length - 1] || {}).innerText || "").trim(), ' +
    'scrollTabella: tabella.scrollWidth, larghWrapper: wrap ? wrap.clientWidth : 0, ' +
    'docScroll: document.documentElement.scrollWidth, docLargh: window.innerWidth } })()'
}
function leggiRiga(nome) { return evalJS(exprTabella(nome)) }

// La cella di un ragazzo per un dato giorno, cercata per NUMERO + MESE (non per indice: l'indice
// dipende da quante colonne c'erano un secondo prima, ed e' esattamente cio' che stiamo misurando)
function exprCella(nome, num, meseCorto) {
  return '(() => { ' + NORM +
    'const cerca = norm(' + JSON.stringify(nome) + '); ' +
    'const NUM = ' + JSON.stringify(String(num)) + ', MESE = ' + JSON.stringify(String(meseCorto).toUpperCase()) + '; ' +
    'for (const t of document.querySelectorAll("table")) { ' +
    '  const riga = [...t.querySelectorAll("tbody tr")].find(tr => norm(' + NOME + '.innerText) === cerca); ' +
    '  if (!riga) continue; ' +
    '  const th = [...t.querySelectorAll("thead th")].filter(x => x.querySelector(".giorno-num")); ' +
    // .giorno-mese ha text-transform: uppercase nel CSS e innerText restituisce il testo TRANSFORMATO:
    // confrontare "Nov" con "NOV" avrebbe detto "colonna non trovata" su una colonna perfettamente presente
    '  const i = th.findIndex(x => ((x.querySelector(".giorno-num") || {}).innerText || "").trim() === NUM ' +
    '    && (MESE === "" || ((x.querySelector(".giorno-mese") || {}).innerText || "").trim().toUpperCase() === MESE)); ' +
    '  if (i < 0) return { ok: false, motivo: "colonna " + NUM + " " + MESE + " non trovata; colonne: " ' +
    '    + th.map(y => ((y.querySelector(".giorno-num") || {}).innerText || "").trim()).join(","), colonne: th.length }; ' +
    '  const td = [...riga.querySelectorAll("td")][2 + i]; ' +
    '  if (!td) return { ok: false, motivo: "cella assente alla colonna " + i }; ' +
    '  const r = td.getBoundingClientRect(); ' +
    '  return { ok: true, testo: (td.innerText || "").trim(), i: i, ' +
    '    x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2) } } ' +
    'return { ok: false, motivo: "ragazzo non trovato in nessuna tabella" } })()'
}

async function vaiAllaSettimanaObiettivo() {
  for (let k = 0; k < AVANTI; k++) {
    const n = await evalJS('document.querySelectorAll(\'button[title="Settimana successiva"]\').length')
    ckmin('freccia "Settimana successiva" presente (giro ' + (k + 1) + ')', n, 1)
    await clickReale('document.querySelector(\'button[title="Settimana successiva"]\')')
    await sleep(800)
  }
}

async function main() {
  fs.rmSync(OUT + '/profile-' + PORT, { recursive: true, force: true })
  const chrome = spawn(CHROME, [
    '--headless=new', '--remote-debugging-port=' + PORT, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', '--user-data-dir=' + OUT + '/profile-' + PORT,
    '--window-size=' + PORT_W + ',' + (PORT_H + 120), '--allow-running-insecure-content', '--test-type',
    '--unsafely-treat-insecure-origin-as-secure=' + BASE,
    'about:blank'
  ], { stdio: 'ignore' })
  // si ammazza per PID (chrome.kill), non con pkill: il pattern matcha anche la propria riga comando
  process.on('exit', () => { try { chrome.kill('SIGKILL') } catch (e) {} })

  let target = null
  for (let i = 0; i < 60; i++) {
    try {
      const list = await (await fetch('http://127.0.0.1:' + PORT + '/json/list')).json()
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

  // Il viewport va messo PRIMA di aprire la pagina: la vista di default la decide il componente al
  // mount leggendo window.innerWidth. Farlo dopo sarebbe troppo tardi, e "Settimana di default"
  // sarebbe verde o rosso a seconda dei millisecondi.
  await send('Emulation.setDeviceMetricsOverride', { width: PORT_W, height: PORT_H, deviceScaleFactor: 2, mobile: true })

  console.log('--- accesso come ' + USER + ' su categoria ' + CAT + ', viewport ' + PORT_W + 'x' + PORT_H + ' (verticale) ---')
  await goto(BASE + '/login')
  const login = await evalJS('(async () => { ' +
    'const r = await fetch("/api/auth/token", {method:"POST", headers:{"Content-Type":"application/x-www-form-urlencoded"}, ' +
      'body: new URLSearchParams({username: ' + JSON.stringify(USER) + ', password: ' + JSON.stringify(PASS) + '})}); ' +
    'if (!r.ok) return {errore: "token http " + r.status}; ' +
    'const j = await r.json(); const access_token = j.access_token; ' +
    'const me = await (await fetch("/api/auth/me", {headers:{Authorization:"Bearer " + access_token}})).json(); ' +
    'localStorage.setItem("token", access_token); ' +
    'localStorage.setItem("utente_data", JSON.stringify(me)); ' +
    'localStorage.setItem("thof_last_activity", Date.now().toString()); ' +
    'if (me.is_admin) localStorage.setItem("is_admin","1"); ' +
    'if (me.societa_id) { try { const s = await (await fetch("/api/societa/" + me.societa_id, ' +
      '{headers:{Authorization:"Bearer " + access_token}})).json(); localStorage.setItem("societa_data", JSON.stringify(s)) } catch (e) {} } ' +
    // la categoria serve a Registro.vue per l'intestazione e per quella del foglio di stampa: senza,
    // la pagina si dipinge lo stesso ma con "-" dove il test dovrebbe leggere il nome
    // NB lo SLASH finale: il router e' GET /categorie/ e senza slash FastAPI risponde redirect 307, che
    // nginx riscrive come URL assoluto SENZA porta (http://192.168.178.133/api/categorie/) -> la pagina
    // lo blocca per Content Security Policy e il test si sporca la console per colpa sua
    'try { const cs = await (await fetch("/api/categorie/", {headers:{Authorization:"Bearer " + access_token}})).json(); ' +
      'const cat = (cs.data || []).find(c => c.id === ' + Number(CAT) + '); ' +
      'if (cat) { localStorage.setItem("categoria_data", JSON.stringify(cat)); localStorage.setItem("categoria_id", String(cat.id)) } } catch (e) {} ' +
    'return {ok:true, ruolo: me.ruolo} })()', { awaitPromise: true })
  if (!login || !login.ok) throw new Error('login fallito: ' + JSON.stringify(login))
  console.log('  ruolo=' + login.ruolo)

  await goto(BASE + '/registro/' + CAT)
  await attendi('document.querySelector(".vista-toggle") && document.querySelector("table tbody tr")',
    { cosa: 'il registro con il toggle settimana/mese' })

  // ── A. il telefono, in verticale ────────────────────────────────────────────────
  console.log('--- A. vista settimana sul telefono ---')
  const overlay = await evalJS('(() => ({ nodi: document.querySelectorAll(".rotate-device-overlay").length, ' +
    'testo: (document.body.innerText || "").indexOf("Ruota il dispositivo") >= 0 }))()')
  ck('nessun overlay "ruota il dispositivo" sul Registro', overlay.nodi, 0)
  ck('la pagina non chiede di ruotare il telefono', overlay.testo ? 'si' : 'no', 'no')

  const defaultVista = await evalJS('(() => { const b = [...document.querySelectorAll(".vista-toggle button")]; ' +
    'const attiva = b.find(x => x.classList.contains("attiva")); ' +
    'return { n: b.length, attiva: attiva ? attiva.innerText.trim() : null } })()')
  console.log('   toggle: ' + JSON.stringify(defaultVista))
  ck('il toggle ha i due modi (Settimana / Mese)', defaultVista.n, 2)
  ck('a 390px il modo di DEFAULT e\' Settimana', defaultVista.attiva, 'Settimana')

  let r = await leggiRiga(SEED_NOME)
  if (!r.trovata) throw new Error('il ragazzo seminato (' + SEED_NOME + ') non e\' in nessuna tabella: ' + JSON.stringify(r))
  console.log('   colonne settimana: ' + JSON.stringify(r.giorni))
  console.log('COLONNE-SCHERMO=' + r.colonne)
  ckmin('la vista settimana dipinge ALMENO una colonna (senza colonne le asserzioni sotto non misurerebbero niente)', r.colonne, 1)
  ck('le colonne della settimana sono MENO di 7 (sono i giorni di allenamento, non tutti i giorni)',
     r.colonne < 7 ? 'si' : 'no', 'si')
  // "si vede in verticale" non e' un'impressione: e' scrollWidth che non supera il contenitore
  ck('la tabella STA nella larghezza del telefono, senza scroll orizzontale',
     r.scrollTabella <= r.larghWrapper + 2 ? 'si' : 'no', 'si')
  ck('la pagina intera non deborda dalla larghezza del telefono',
     r.docScroll <= r.docLargh + 2 ? 'si' : 'no', 'si')
  await shot('A-settimana-verticale')

  // ── B. il modo Mese ─────────────────────────────────────────────────────────────
  console.log('--- B. il modo Mese ---')
  await clickReale('[...document.querySelectorAll(".vista-toggle button")].find(b => b.innerText.trim() === "Mese")')
  await sleep(900)
  const rMese = await leggiRiga(SEED_NOME)
  console.log('   colonne mese: ' + rMese.colonne)
  console.log('COLONNE-MESE-VISTA=' + rMese.colonne)
  ck('il modo Mese ridà PIU\' colonne della settimana', rMese.colonne > r.colonne ? 'si' : 'no', 'si')
  ck('il toggle adesso segna Mese', await evalJS(
    '(() => { const a = [...document.querySelectorAll(".vista-toggle button")].find(b => b.classList.contains("attiva")); ' +
    'return a ? a.innerText.trim() : "" })()'), 'Mese')
  await clickReale('[...document.querySelectorAll(".vista-toggle button")].find(b => b.innerText.trim() === "Settimana")')
  await sleep(900)

  // ── C. la settimana a cavallo dei due mesi ──────────────────────────────────────
  console.log('--- C. settimana a cavallo: ' + AVANTI + ' avanzamenti, lunedi\' ' + LUN_CROSS + ' ---')
  await vaiAllaSettimanaObiettivo()
  const etichetta = await evalJS('((document.querySelector(".mese-selector-pill .mese-label") || {}).innerText || "").trim()')
  console.log('   intestazione settimana: ' + etichetta)
  console.log('ETICHETTA-SETTIMANA=' + etichetta)

  r = await leggiRiga(SEED_NOME)
  if (!r.trovata) throw new Error('dopo l\'avanzamento il ragazzo seminato non e\' piu\' in nessuna tabella: ' + JSON.stringify(r))
  console.log('   colonne: ' + JSON.stringify(r.giorni))
  console.log('COLONNE-CROSS=' + r.colonne)
  const mesiVisti = [...new Set(r.giorni.map(g => g.mese).filter(Boolean))]
  console.log('   mesi sotto i numeri: ' + mesiVisti.join(','))
  ck('in vista settimana il numero del giorno ha anche il MESE sotto (altrimenti un "1" e\' ambiguo)',
     mesiVisti.length > 0 ? 'si' : 'no', 'si')
  ck('la settimana a cavallo mostra DUE mesi diversi', mesiVisti.length, 2)
  const cellaAdj = await evalJS(exprCella(SEED_NOME, ADJ.g, ADJ.corto))
  ck('la cella del MESE ACCANTO mostra il codice seminato (cerca la DATA, non il numero del giorno)',
     cellaAdj.ok ? cellaAdj.testo : 'CELLA-ASSENTE: ' + cellaAdj.motivo, CODICE)
  const cellaMese = await evalJS(exprCella(SEED_NOME, MES.g, MES.corto))
  ck('la cella del giorno NEL MESE mostra il codice seminato',
     cellaMese.ok ? cellaMese.testo : 'CELLA-ASSENTE: ' + cellaMese.motivo, CODICE)
  // Il TOT e' il MESE, non la settimana: se qualcuno fondesse registroExtra con registro qui comparirebbe
  // 2, e lo stesso numero sbagliato uscirebbe anche dal foglio stampato
  ck('il TOT di riga conta il MESE e non la settimana (la riga del mese accanto non deve entrarci)',
     r.tot, SEED_TOT)
  await shot('C-cavallo-verticale')

  // ── D. il foglio di stampa, mentre lo schermo e' in vista settimana ─────────────
  console.log('--- D. il foglio di stampa resta del MESE ---')
  await clickReale('document.querySelector(".btn-print-pill")')
  await attendi('document.querySelector(".print-preview .print-sheet thead th.col-day")',
    { cosa: 'il foglio di stampa in anteprima' })
  const foglio = await evalJS('(() => { ' + NORM +
    'const sheet = document.querySelector(".print-preview .print-sheet"); ' +
    'if (!sheet) return { presente: false }; ' +
    'const th = [...sheet.querySelectorAll("thead th.col-day")]; ' +
    'return { presente: true, colonne: th.length, ' +
    'numeri: th.map(x => ((x.querySelector("span") || x).innerText || "").trim()), ' +
    'periodo: norm((document.querySelector(".print-preview .sheet-meta") || {}).innerText) } })()')
  console.log('   foglio: colonne=' + foglio.colonne + '  periodo=' + foglio.periodo)
  console.log('COLONNE-FOLIO=' + foglio.colonne)
  console.log('MESE-FOLIO=' + MESE_ATTESO)
  console.log('PERIODO-FOLIO=' + foglio.periodo)
  ck('il foglio di stampa c\'e\'', foglio.presente ? 'si' : 'no', 'si')
  ck('il foglio di stampa HA LE COLONNE DEL MESE mentre lo schermo e\' in vista settimana',
     foglio.colonne > r.colonne ? 'si' : 'no', 'si')
  ck('il foglio di stampa dice il MESE della settimana (quello del giovedi\')',
     foglio.periodo.indexOf(MESI_LUNGHI[MESE_FOLIO_NUM - 1].toUpperCase()) >= 0
       && foglio.periodo.indexOf(String(MESE_FOLIO_ANNO)) >= 0 ? 'si' : 'no', 'si')
  // "Con presenze": il foglio deve riportare i codici, e solo quelli del mese
  await clickReale('[...document.querySelectorAll(".print-option")].find(l => l.innerText.indexOf("Con presenze") >= 0)')
  await sleep(700)
  const foglio2 = await evalJS('(() => { ' + NORM +
    'const sheet = document.querySelector(".print-preview .print-sheet"); ' +
    'const cerca = norm(' + JSON.stringify(SEED_NOME) + '); ' +
    'const th = [...sheet.querySelectorAll("thead th.col-day")]; ' +
    'const riga = [...sheet.querySelectorAll("tbody tr")].find(tr => norm((tr.querySelector(".col-nome") || {}).innerText).indexOf(cerca) === 0); ' +
    'if (!riga) return { rigaTrovata: false }; ' +
    'const celle = [...riga.querySelectorAll("td.col-day")].map(x => (x.innerText || "").trim()); ' +
    'const i = th.findIndex(x => ((x.querySelector("span") || x).innerText || "").trim() === ' + JSON.stringify(String(MES.g)) + '); ' +
    'return { rigaTrovata: true, i: i, valore: i >= 0 ? celle[i] : "COLONNA-NON-TROVATA", ' +
    'tot: ((riga.querySelector(".col-tot") || {}).innerText || "").trim() } })()')
  ck('il foglio ha la riga del ragazzo seminato', foglio2.rigaTrovata ? 'si' : 'no', 'si')
  ck('il foglio riporta il codice del giorno NEL MESE', foglio2.valore, CODICE)
  ck('il TOT del foglio e\' il mese, come a schermo', foglio2.tot, SEED_TOT)
  await shot('D-foglio-stampa')
  await clickReale('[...document.querySelectorAll(".btn-close-modal")].find(b => b.innerText.trim() === "Chiudi")')
  await sleep(600)

  // ── E. scrivere sulla cella del MESE ACCANTO ────────────────────────────────────
  console.log('--- E. scrivo ' + CODICE + ' su ' + DATA_ADJ + ' (mese accanto) per ' + SCRIVI_NOME + ' ---')
  const prima = await evalJS(exprCella(SCRIVI_NOME, ADJ.g, ADJ.corto))
  if (!prima.ok) throw new Error('la cella da scrivere non c\'e\': ' + JSON.stringify(prima))
  ck('prima di scrivere, la cella del mese accanto e\' vuota', prima.testo, '')
  await clickPunto(prima.x, prima.y)
  await attendi('document.querySelector(".modal-edit .codici-grid .btn-codice")', { cosa: 'il modal della cella' })
  const dataModal = await evalJS('(() => { ' + NORM + 'return norm((document.querySelector(".modal-edit .modal-date") || {}).innerText) })()')
  console.log('   data nel modal: ' + dataModal)
  console.log('DATA-MODAL=' + dataModal)
  // "[OBJECT OBJECT]" e' il modo in cui si presenta la regressione "editModal.giorno e' un oggetto",
  // e il mese sbagliato e' quella "il giorno N del mese mostrato": plausibile e falso
  ck('il modal dice la DATA VERA del giorno (non l\'oggetto, non il giorno omonimo del mese mostrato)',
     dataModal, (ADJ.g + ' ' + ADJ.lungo + ' ' + ADJ.a).toUpperCase())
  await shot('E-modal-mese-accanto')
  await clickReale('[...document.querySelectorAll(".modal-edit .btn-codice")].find(b => ((b.querySelector(".codice") || b).innerText || "").trim() === ' + JSON.stringify(CODICE) + ')')
  await sleep(1400)
  const dopo = await evalJS(exprCella(SCRIVI_NOME, ADJ.g, ADJ.corto))
  ck('dopo il salvataggio la cella del mese accanto mostra il codice', dopo.ok ? dopo.testo : 'CELLA-ASSENTE', CODICE)
  console.log('CELLA-SCRITTA=' + DATA_ADJ)

  // ── F. ricarica vera: la cella deve essere ancora li' ───────────────────────────
  console.log('--- F. ricarica della pagina ---')
  await goto(BASE + '/registro/' + CAT)
  await attendi('document.querySelector(".vista-toggle") && document.querySelector("table tbody tr")',
    { cosa: 'il registro dopo la ricarica' })
  await vaiAllaSettimanaObiettivo()
  const riesco = await evalJS(exprCella(SCRIVI_NOME, ADJ.g, ADJ.corto))
  ck('dopo la ricarica la cella scrive ancora sul MESE ACCANTO', riesco.ok ? riesco.testo : 'CELLA-ASSENTE', CODICE)
  const riescoSeed = await evalJS(exprCella(SEED_NOME, ADJ.g, ADJ.corto))
  ck('dopo la ricarica scrive ancora anche la riga seminata', riescoSeed.ok ? riescoSeed.testo : 'CELLA-ASSENTE', CODICE)
  await shot('F-dopo-ricarica')

  console.log('--- console della pagina ---')
  const rumorosi = erroriConsole.filter(e => !/favicon|DownloadBundle|insecure|DevTools/i.test(e))
  ck('nessun errore in console', rumorosi.length, 0)
  if (rumorosi.length) rumorosi.slice(0, 5).forEach(e => console.log('     ! ' + e.slice(0, 160)))

  const rossi = risultati.filter(x => !x.ok).length
  console.log('\n  ' + (risultati.length - rossi) + ' passati, ' + rossi + ' falliti')
  return rossi === 0 ? 0 : 1
}

main()
  .then(c => process.exit(c))
  .catch(e => { console.log('  ERRORE: ' + e.message); process.exit(1) })
