// Verifica UI reale della pagina Tornei suddivisa per categorie: apre il frontend DEV su Chrome
// headless, si comporta come il responsabile (login, apre i calendari, apre il modal gara, preme
// Elimina con confirm intercettato) e riporta cosa c'e' davvero a schermo + gli errori in console.
// Il build Vite e i test API non vedono niente di questo: un helper rimasto orfano nel template
// sarebbe una pagina bianca, e nessuno se ne accorgerebbe.
//
// Non si lancia a mano: lo invoca scripts/test/verifica_ui_tornei.sh, che crea e ripulisce i dati
// di prova e passa le credenziali dell'utente demo.
//
// Le sezioni si cercano PER TITOLO e non per indice: l'ordine reale e' per anno crescente, quindi
// "2015 - Esordienti" viene PRIMA di "2016 - Pulcini" (i piu' grandi per primi, come nel weekend).
// La prima versione di questo file dava per scontato il contrario e ha prodotto 14 rossi che non
// misuravano niente: il verde di un test che non sa cosa sta guardando e' peggio di un rosso.
const fs = require('fs')
const { spawn } = require('child_process')

// Specchiano i valori di scripts/test/prepara_demo_tornei.sh: se li cambi li', cambiali anche qui,
// perche' le asserzioni sull'export cercano il torneo demo per nome e il foglio per categoria
const NOME_DEMO = '__demo_tornei__-WINTER CUP'
const CAT_PULCINI = '19'

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const USER = process.argv[2]
const PASS = process.argv[3]
const OUT = process.env.THOF_UI_OUT || '/tmp/opencode/ui'
fs.mkdirSync(OUT, { recursive: true })

const PORT = 9222
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

// Click VERO, dall'input pipeline del browser. el.click() di Runtime.evaluate non e' un gesto utente
// per Chrome, che senza gesto blocca il download: l'export sembrava non fare niente e in console non
// compariva nessun errore. Con i mouse event dispatchati via CDP il download parte davvero, e cosi'
// si clicca come clicca una persona
async function clickReale(espressione) {
  const box = await evalJS(`(() => { const el = (${espressione}); if (!el) return null;
    const r = el.getBoundingClientRect(); return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)} })()`)
  if (!box) throw new Error('elemento non trovato per il click: ' + espressione)
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: box.x, y: box.y })
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: box.x, y: box.y, button: 'left', clickCount: 1 })
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: box.x, y: box.y, button: 'left', clickCount: 1 })
}
// Cosa la pagina dice di se' stessa dopo un'azione: senza questo, un export che fallisce dentro un
// try/catch e' completamente invisibile dall'esterno
const erroreSchermo = () => evalJS(`document.querySelector('.messaggio.errore')?.innerText.trim() || null`)
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

// Lo stato della pagina, aggregato PER TITOLO di sezione
const LEGGI = `(() => {
  const sec = [...document.querySelectorAll('.categoria-sezione')]
  const perTitolo = {}
  sec.forEach(s => {
    // Il titolo si legge dal testo della testata ESCLUSO il pulsante di export, che sta dentro
    // l'h2: leggerlo tutto avrebbe dato "2016 - Pulcini 1 torneo Esporta PDF"
    const h = s.querySelector('.categoria-intestazione')
    let t = ''
    if (h) {
      const c = h.cloneNode(true)
      c.querySelectorAll('.btn-esporta').forEach(b => b.remove())
      t = (c.textContent || '').replace(/\\s+/g, ' ').trim()
    }
    const k = t.split(' ').slice(0,2).join(' ')
    perTitolo[k] = {
      titolo: t,
      idx: sec.indexOf(s),
      gare: s.querySelector('.badge.gare')?.innerText.trim() || null,
      giocatori: s.querySelector('.badge.lista:not(.vuota)')?.innerText.trim() || null,
      vuoti: [...s.querySelectorAll('.badge.lista.vuota')].map(b => b.innerText.trim()),
      altrui: [...s.querySelectorAll('.badge.categoria.altrui')].map(b => b.innerText.trim()),
      disabilitati: [...s.querySelectorAll('.btn-azione')].filter(b => b.disabled).map(b => b.innerText.trim()),
      nCalendari: s.querySelectorAll('.calendario').length,
      etichette: [...s.querySelectorAll('.gara-verso strong')].map(x => x.innerText.trim()),
      orfaneTitle: s.querySelector('.orfane-intestazione')?.innerText.trim() || null
    }
  })
  return {sezioni: sec.length, perTitolo}
})()`

;(async () => {
  const chrome = spawn('/usr/bin/google-chrome-stable', [
    '--headless=new', `--remote-debugging-port=${PORT}`, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', `--user-data-dir=${OUT}/profile`,
    '--window-size=1180,1500', 'about:blank'
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
    return {ok:true, admin: !!me.is_admin, societa: me.societa_id}
  })()`, { awaitPromise: true })
  if (!login || !login.ok) throw new Error('login fallito: ' + JSON.stringify(login))
  console.log(`  accesso: admin=${login.admin} societa=${login.societa}`)

  await goto(`${BASE}/responsabili/tornei`)
  // aspetta che le card siano dipinte: alla prima lettura si vede "Caricamento..." e le asserzioni
  // sarebbero verdi senza aver misurato niente
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelectorAll('.torneo-card').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })

  console.log('--- le sezioni per categoria ---')
  let pagina = await evalJS(LEGGI)
  console.log('   ordine sezioni:', Object.keys(pagina.perTitolo).join(' | '))
  let PULC = pagina.perTitolo['2016 -'], ESOR = pagina.perTitolo['2015 -']
  ck('due sezioni, una per categoria iscritta', pagina.sezioni, 2)
  ck('le sezioni sono ordinate per anno crescente, come nel weekend',
     Object.keys(pagina.perTitolo).join(' | '), '2015 - | 2016 -')
  ck('la sezione dei Pulcini 2016 c\'e\' ed e\' etichettata', PULC && PULC.titolo, '2016 - Pulcini 1 torneo')
  ck('la sezione degli Esordienti 2015 c\'e\' ed e\' etichettata', ESOR && ESOR.titolo, '2015 - Esordienti 1 torneo')
  // Il punto delicato della pagina: il badge gare deve essere PER categoria, non il totale (4)
  ck('Pulcini dice 2 gare, non il totale del torneo', PULC && PULC.gare, '2 gare')
  ck('Esordienti dice 1 gara, non il totale del torneo', ESOR && ESOR.gare, '1 gara')
  ck('il foglio dei Pulcini conta i suoi 3 giocatori', PULC && PULC.giocatori, '3 giocatori')
  ck('il foglio degli Esordienti, distaccato, dichiara il buco',
     ESOR && ESOR.vuoti.includes('foglio assente'), true)
  ck('la card dei Pulcini dichiara l\'altra categoria coinvolta', PULC && PULC.altrui[0], 'anche 2015 - Esordienti')
  ck('la card degli Esordienti dichiara l\'altra categoria coinvolta', ESOR && ESOR.altrui[0], 'anche 2016 - Pulcini')
  ck('Foglio giocatori e\' disabilitato solo dove il foglio manca',
     (PULC ? PULC.disabilitati.length : -1) + '/' + (ESOR ? ESOR.disabilitati.length : -1), '0/1')
  ck('le gare senza categoria sono dichiarate in entrambe le sezioni',
     (PULC ? PULC.vuoti.filter(x => /senza categoria/.test(x)).length : -1) + '/' +
     (ESOR ? ESOR.vuoti.filter(x => /senza categoria/.test(x)).length : -1), '1/1')
  await shot('01_sezioni')

  console.log('--- esportazione PDF: i due pulsanti, e cosa c\'E\' dentro i file ---')
  // L'export non lo verifica nessun test API: qui si scarica davvero il PDF e se ne legge il testo.
  // Un pulsante che sembra funzionare e sforna un documento vuoto e' il modo peggiore per scoprirlo
  // la sera prima del torneo, quando il file va consegnato all'organizzatore
  const DL = `${OUT}/download`
  fs.rmSync(DL, { recursive: true, force: true })
  fs.mkdirSync(DL, { recursive: true })
  await send('Page.setDownloadBehavior', { behavior: 'allow', downloadPath: DL })
  // Su alcune versioni di Chrome il percorso di download e' solo a livello di browser: messo su
  // entrambe le sessioni, il file arriva comunque dove lo aspettiamo
  await send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: DL }).catch(() => {})
  const { execFileSync } = require('child_process')
  async function scarica(nome, espressioneElemento) {
    await clickReale(espressioneElemento)
    const atteso = `${DL}/${nome}`
    for (let i = 0; i < 60; i++) {
      if (fs.existsSync(atteso) && fs.statSync(atteso).size > 500) {
        await sleep(400)   // il file puo' ancora essere in scrittura
        return execFileSync('pdftotext', ['-layout', atteso, '-'], { encoding: 'utf8' })
      }
      await sleep(250)
    }
    console.log('   perche\' nessun file:', await erroreSchermo(), '| cartella:', fs.readdirSync(DL).join(','))
    return null
  }
  const occorrenze = (testo, ago) => (testo.match(new RegExp(ago, 'g')) || []).length

  // le cognome vere dei giocatori, prese dalla STESSA API che l'export usa: se il PDF le contiene,
  // il foglio e' stato davvero caricato e stampato
  const attese = await evalJS(`(async () => {
    const tk = localStorage.getItem('token')
    const ts = await (await fetch('/api/tornei/', {headers:{Authorization:'Bearer '+tk}})).json()
    const t = ts.find(x => (x.nome || '').indexOf(${JSON.stringify(NOME_DEMO)}) === 0)
    if (!t) return {cognomi: [], errore: 'torneo demo non trovato'}
    const l = (t.liste || []).find(x => String(x.categoria_id) === ${JSON.stringify(CAT_PULCINI)})
    if (!l) return {cognomi: [], errore: 'foglio pulcini non trovato'}
    const g = await (await fetch('/api/liste-torneo/' + l.id + '/giocatori', {headers:{Authorization:'Bearer '+tk}})).json()
    return {cognomi: (g || []).map(x => x.cognome), nomeFoglio: l.nome}
  })()`, { awaitPromise: true })
  console.log('   atteso nel foglio:', JSON.stringify(attese))

  const btnSezione = `[...document.querySelectorAll('.categoria-sezione')]
      .find(x => /Esordienti/.test(x.querySelector('.categoria-intestazione').innerText))
      .querySelector('.btn-esporta')`
  const pdfSezione = await scarica('tornei_2015_esordienti.pdf', btnSezione)
  ck('il PDF della singola categoria si scarica', pdfSezione !== null, true)
  if (pdfSezione) {
    ck('contiene la sua categoria', /2015 - Esordienti/.test(pdfSezione), true)
    ck('contiene la SUA gara', /Vecchia Guardia/.test(pdfSezione), true)
    // Il punto delicato dell'export per categoria: se trapelassero le gare dell'altra categoria, il
    // documento consegnato all'organizzatore sarebbe plausibile e falso
    ck('NON contiene le gare dei Pulcini', /Real Junior|Atletico Sud/.test(pdfSezione), false)
    ck('dichiara il foglio assente, non lo tace', /Foglio giocatori assente/.test(pdfSezione), true)
    ck('nomina le orfane invece di dimenticarle', /Gare senza categoria \(1\)/.test(pdfSezione), true)
    ck('e stampa la gara orfana', /Amichevole fuori calendario/.test(pdfSezione), true)
    ck('non stampa colonne GDPR (data di nascita, CF, telefoni)',
       /Data Nascita|Codice fiscale|Telefono/i.test(pdfSezione), false)
    // Qui il foglio NON c'e' (e' stato distaccato di proposito): un tabella del roster vuota sarebbe
    // peggio della frase che dichiara l'assenza
    ck('e non stampa una tabella giocatori vuota', /Cognome/.test(pdfSezione), false)
  }

  const btnTutti = `document.querySelector('.page-header .btn-esporta')`
  const pdfTutti = await scarica('tornei_tutte_categorie.pdf', btnTutti)
  ck('il PDF di tutte le categorie si scarica', pdfTutti !== null, true)
  if (pdfTutti) {
    ck('contiene entrambe le sezioni', /2015 - Esordienti/.test(pdfTutti) && /2016 - Pulcini/.test(pdfTutti), true)
    ck('contiene le gare di entrambe',
       /Vecchia Guardia/.test(pdfTutti) && /Real Junior/.test(pdfTutti) && /Atletico Sud/.test(pdfTutti), true)
    ck('contiene i giocatori veri del foglio dei Pulcini',
       attese.cognomi.length > 0 && attese.cognomi.every(c => pdfTutti.includes(c)), true)
    ck('il foglio ha le sue colonne, e niente di piu\'',
       /Cognome/.test(pdfTutti) && /Nome/.test(pdfTutti), true)
    ck('nomina il foglio con il suo nome completo', pdfTutti.includes(attese.nomeFoglio || '###'), true)
    // Le orfane sono dello stesso torneo: in "tutte le categorie" vanno stampate una volta sola
    ck('la gara orfana compare UNA volta sola, non una per sezione', occorrenze(pdfTutti, 'Amichevole fuori calendario'), 1)
    ck('anche l\'intestazione orfane compare una volta sola', occorrenze(pdfTutti, 'Gare senza categoria'), 1)
    ck('non stampa colonne GDPR', /Data Nascita|Codice fiscale|Telefono/i.test(pdfTutti), false)
  }
  ck('nessun file PDF inaspettato nella cartella download',
     fs.readdirSync(DL).sort().join(','), 'tornei_2015_esordienti.pdf,tornei_tutte_categorie.pdf')
  ck('i pulsanti non sono rimasti disabilitati dopo l\'export',
     await evalJS(`[...document.querySelectorAll('.btn-esporta')].every(b => !b.disabled)`), true)

  console.log('--- aprire il calendario di UNA sola sezione ---')
  await evalJS(`document.querySelectorAll('.categoria-sezione')[${PULC.idx}].querySelectorAll('.btn-azione')[0].click(); 'ok'`)
  await sleep(1300)
  pagina = await evalJS(LEGGI)
  let p2 = pagina.perTitolo['2016 -'], e2 = pagina.perTitolo['2015 -']
  ck('solo la sezione dei Pulcini ha il calendario aperto', p2.nCalendari + '/' + e2.nCalendari, '1/0')
  ck('mostra le sue 2 gare, piu\' la orfana che una sezione propria non ce l\'ha',
     p2.etichette.join(' / '), 'Real Junior / Atletico Sud / Amichevole fuori calendario')

  console.log('--- aprire l\'altra: la chiave e\' torneo+sezione, la prima si chiude ---')
  await evalJS(`document.querySelectorAll('.categoria-sezione')[${ESOR.idx}].querySelectorAll('.btn-azione')[0].click(); 'ok'`)
  await sleep(1300)
  pagina = await evalJS(LEGGI)
  let p3 = pagina.perTitolo['2016 -'], e3 = pagina.perTitolo['2015 -']
  ck('ora e\' aperta solo la sezione degli Esordienti', p3.nCalendari + '/' + e3.nCalendari, '0/1')
  ck('l\'Esordienti mostra la sua gara', e3.etichette[0], 'Vecchia Guardia')
  ck('la gara senza categoria non sparisce', (e3.orfaneTitle || '').toUpperCase(), 'SENZA CATEGORIA (1)')
  // Una sezione aperta per volta e' il comportamento della pagina (calendarioAperto e' un valore
  // solo), quindi qui si prova che l'orfana sta DENTRO la sezione Esordienti; che stia anche nei
  // Pulcini e' gia' provato sopra, dove aprendo i Pulcini le righe erano tre
  ck('l\'orfana e\' elencata dentro la sezione degli Esordienti',
     e3.etichette.join(' / '), 'Vecchia Guardia / Amichevole fuori calendario')
  await shot('02_calendario_esordienti')

  console.log('--- la gara orfana si puo\' eliminare, e il calendario si riapre li\' ---')
  // Il cestino sulla riga orfana non e' decorazione: una gara senza categoria non compare nella
  // lista di nessuna sezione, quindi senza di esso non si potrebbe eliminare da nessuna parte
  const azioniOrfana = await evalJS(`(() => {
    const r = document.querySelector('.gara-riga.orfana')
    return r ? [...r.querySelectorAll('.btn-icon')].length : -1
  })()`)
  ck('la gara orfana ha i suoi due pulsanti, cestino compreso', azioniOrfana, 2)
  await evalJS(`window.confirm = () => true`)
  await evalJS(`document.querySelector('.gara-riga.orfana .btn-icon.pericolo').click(); 'ok'`)
  // Si aspetta la scomparsa della riga, non un tempo fisso: dopo l'eliminazione la pagina ricarica
  // la lista e il calendario, e con il sleep fisso si leggerebbe lo stato di mezzo
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (!document.querySelector('.gara-riga.orfana') || ++n > 30) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
  pagina = await evalJS(LEGGI)
  const e4 = pagina.perTitolo['2015 -']
  ck('dopo l\'eliminazione la sezione da cui lavoravi e\' ancora aperta', e4.nCalendari, 1)
  ck('l\'orfana e\' sparita dal calendario', e4.etichette.join(' / '), 'Vecchia Guardia')
  ck('il conteggio della sezione non era toccato dalle orfane', e4.gare, '1 gara')
  ck('il badge "senza categoria" e\' sparito con lei',
     e4.vuoti.some(x => /senza categoria/.test(x)), false)

  console.log('--- "+ Aggiungi gara" deve partire gia\' con la categoria della sezione ---')
  await evalJS(`(() => { const b=[...document.querySelectorAll('.categoria-sezione')[${ESOR.idx}].querySelectorAll('.btn-aggiungi')][0]; b.click(); return 'ok' })()`)
  await sleep(900)
  const modal = await evalJS(`(() => {
    const m = document.querySelector('.modal')
    if (!m) return {nessuno: true}
    const sel = m.querySelector('select')
    const opt = sel ? sel.options[sel.selectedIndex] : null
    return {titolo: m.querySelector('h3')?.innerText.trim(),
            categoria: opt ? opt.text.trim() : null,
            valore: sel ? sel.value : null}
  })()`)
  console.log('  ', JSON.stringify(modal))
  ck('il modal e\' aperto', !!modal.titolo, true)
  ck('la categoria pre-selezionata e\' quella della sezione in cui sei', modal.categoria, '2015 - Esordienti')
  await shot('03_modal_gara')

  console.log('--- eliminare da una sezione deve nominare l\'altra categoria ---')
  await evalJS(`document.querySelector('.modal-close')?.click(); 'ok'`); await sleep(400)
  await evalJS(`window.__conferme = []; window.confirm = m => { window.__conferme.push(m); return false }`)
  await evalJS(`(() => { const b=[...document.querySelectorAll('.categoria-sezione')[${PULC.idx}].querySelectorAll('.btn-azione')].find(x=>x.innerText.trim()==='Elimina'); b.click(); return 'ok' })()`)
  await sleep(500)
  const conferma = await evalJS(`window.__conferme.join(' || ')`)
  console.log('   conferma:', JSON.stringify(conferma))
  ck('la conferma nomina gli Esordienti, che stanno per essere cancellati insieme', /Esordienti/.test(conferma), true)
  ck('la conferma dice anche quanti giocatori si perdono', /3 giocatori/.test(conferma), true)
  ck('la conferma nomina la sezione da cui si sta eliminando', /2016 - Pulcini/.test(conferma), true)
  ck('il torneo NON e\' stato eliminato (confirm intercettato a false)',
     await evalJS(`document.querySelectorAll('.torneo-card').length`), 2)

  console.log('\n--- controllo negativo: se la pagina avesse quel bug, questo file sarebbe rosso? ---')
  // Si rompe il DOM come rompendo il codice, e si rilegge con le STESSUE asserzioni: un test che
  // non e' mai stato visto fallire non ha dimostrato niente. Qui si rompono i tre punti che la
  // pagina ha di delicato: il conteggio per categoria, il foglio assente, l'altra categoria dichiarata
  await evalJS(`document.querySelectorAll('.badge.gare').forEach(b => b.innerText = '4 gare')`)
  await evalJS(`document.querySelectorAll('.badge.lista.vuota').forEach(b => { if (b.innerText.trim()==='foglio assente') b.remove() })`)
  await evalJS(`document.querySelectorAll('.badge.categoria.altrui').forEach(b => b.remove())`)
  const rotto = await evalJS(LEGGI)
  ck('CONTROLLO NEGATIVO: il badge "4 gare" ovunque sarebbe stato rosso',
     rotto.perTitolo['2016 -'].gare === '2 gare', false)
  ck('CONTROLLO NEGATIVO: il foglio assente tolto sarebbe stato rosso',
     rotto.perTitolo['2015 -'].vuoti.includes('foglio assente'), false)
  ck('CONTROLLO NEGATIVO: la card senza "anche ..." sarebbe stata rossa',
     rotto.perTitolo['2016 -'].altrui.length > 0, false)

  console.log('\n--- console della pagina ---')
  const reali = erroriConsole.filter(e => !/favicon|DevTools|Download the Vue|Failed to load resource: the server responded with a status of 40/i.test(e))
  console.log(reali.length ? reali.slice(0, 12).join('\n') : '  nessun errore in console')

  const rossi = risultati.filter(r => !r.ok)
  console.log(`\n  ${risultati.length - rossi.length} passati, ${rossi.length} falliti, ${reali.length} errori in console`)
  await send('Browser.close').catch(() => {})
  chrome.kill('SIGKILL')
  process.exit(rossi.length || reali.length ? 1 : 0)
})().catch(e => {
  console.error('ERRORE:', e.message)
  try { require('child_process').execSync(`pkill -f remote-debugging-port=${PORT}`) } catch (x) {}
  process.exit(2)
})
