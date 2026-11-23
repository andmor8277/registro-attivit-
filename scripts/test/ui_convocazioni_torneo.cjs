// Verifica UI reale della CONVOCAZIONE di una gara di torneo e del calendario scritto dai mister.
//
// Perche' esiste, accanto a test_convocazioni_torneo.sh: quel file ferma il backend, non il browser.
// Le cose che solo guardando la pagina si vedono, e che questo progetto ha gia' pagato:
//   1. un identificatore citato dal template e non esposto da <script setup> e' PAGINA BIANCA, e il
//      build Vite non lo dice;
//   2. un pulsante che il ruolo VEDE quando il backend gli direbbe 403 e' un errore che l'utente
//      incontra lui, e al contrario un pulsante che il ruolo non vede quando potrebbe usarlo e' il
//      lavoro che non viene fatto (e' cosi' che in due anni in liste_torneo c'era una lista sola);
//   3. i colori scritti per un tema scuro: la pagina funziona, i dati sono giusti, e a schermo i
//      bottoni sono grigio chiarissimo su bianco.
//
// Il punto di fondo di questa pagina: il gate del calendario gare (mister + admin) e' DIVERSO da
// solaLettura (solo admin). Se qualcuno allargasse solaLettura ai mister "per fare prima", il mister si
// troverebbe Modifica/Elimina sul torneo e l'iscrizione delle categorie. Qui quella regressione diventa
// rossa.
//
// Non si lancia a mano: lo invoca scripts/test/verifica_ui_convocazioni_torneo.sh, che crea e ripulisce
// i dati di prova con prepara_demo_tornei.sh e passa le credenziali.
const fs = require('fs')
const { spawn } = require('child_process')

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const PW = process.argv[2]
const UTENTE_MISTER = process.argv[3] || 'demo_tornei_mister1'
const UTENTE_DIRIGENTE = process.argv[4] || 'demo_tornei_dirigente'
// Vengono da prepara_demo_tornei.sh: se li cambi li', cambiali anche qui
const NOME_TORNEO = '__demo_tornei__-WINTER CUP'
const CAT_PULCINI = '19'
const GARA_CON_CATEGORIA = 'Real Junior'
const GARA_ORFANA = 'Amichevole fuori calendario'
const OUT = process.env.THOF_UI_OUT || '/tmp/opencode/ui-conv'

const PORT = 9223   // porta diversa da ui_tornei.cjs: i due test possono girare in sequenza
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
async function goto(url) { await send('Page.navigate', { url }); await sleep(1500) }

// Click VERO dalla pipeline input del browser: el.click() di Runtime.evaluate non e' un gesto utente
// per Chrome, e su alcune interazioni la pagina non reagisce senza. Cosi' si clicca come clicca una
// persona (e fu quello che rese visibile un download che "sembrava funzionare" e non scaricava niente)
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

async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true })
  fs.writeFileSync(`${OUT}/${name}.png`, Buffer.from(r.data, 'base64'))
}

const risultati = []
function ck(nome, reale, atteso) {
  const ok = String(reale) === String(atteso)
  risultati.push({ ok, nome, reale, atteso })
  console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${nome}${ok ? '' : ` -> '${reale}' (atteso '${atteso}')`}`)
}

// Cosa la pagina dice di se' stessa: senza questo, un salvataggio che fallisce dentro un try/catch e'
// completamente invisibile dall'esterno
const erroreSchermo = () => evalJS(`document.querySelector('.modal .messaggio.errore')?.innerText.trim()
  || document.querySelector('.messaggio.errore')?.innerText.trim() || null`)

// ------------------------------------------------------------- cosa c'e' a schermo
const LEGGI_PAGINA = `(() => {
  // Il match e' "contiene", non "comincia con": il pulsante spento ha un titolo che parla del motivo
  // ("...assegnala dal calendario prima di convocare") e non comincia per "Convoca". Con startsWith il
  // pulsante disabilitato sarebbe risultato invisibile al lettore, e l'asserzione sul suo motivo sarebbe
  // rimasta verde perche' non trovava niente da confrontare
  const iconeConvoca = r => [...r.querySelectorAll('.btn-icon')]
    .filter(b => (b.title || '').toLowerCase().includes('convoca'))
  const righe = sel => [...document.querySelectorAll(sel)].map(r => ({
    avversario: r.querySelector('.gara-verso strong')?.innerText.trim() || '',
    convoca: iconeConvoca(r).some(b => !b.disabled),
    convocaSpento: iconeConvoca(r).some(b => b.disabled),
    motivoConvocaSpento: (iconeConvoca(r).find(b => b.disabled) || {}).title || null
  }))
  return {
    titoloPagina: document.querySelector('.page-header h2')?.innerText.trim() || '',
    nota: (document.querySelector('.nota')?.innerText || '').replace(/\\s+/g, ' ').trim(),
    nuovoTorneo: [...document.querySelectorAll('.btn-primary')].some(b => /Nuovo torneo/.test(b.innerText)),
    aggiungiGara: [...document.querySelectorAll('.btn-aggiungi')].map(b => b.innerText.trim()),
    azioniTorneo: [...document.querySelectorAll('.torneo-azioni .btn-azione')].map(b => b.innerText.trim()),
    calendariAperti: document.querySelectorAll('.calendario').length,
    gare: righe('.gara-riga:not(.orfana)'),
    orfane: righe('.gara-riga.orfana')
  }
})()`

const LEGGI_MODAL = `(() => {
  const m = document.querySelector('.modal-conv')
  if (!m) return null
  return {
    titolo: m.querySelector('.modal-header h3')?.innerText.trim() || '',
    sottotitolo: m.querySelector('.conv-sottotitolo')?.innerText.trim() || '',
    logistica: [...(m.querySelectorAll('.conv-logistica span') || [])].map(s => s.innerText.trim()),
    colonne: [...m.querySelectorAll('.conv-colonna')].map(c => ({
      titolo: c.querySelector('.conv-titolo')?.innerText.trim() || '',
      righe: [...c.querySelectorAll('.conv-riga')].map(r => ({
        nome: r.querySelector('.conv-nome')?.innerText.trim() || '',
        pos: r.querySelector('.conv-pos')?.innerText.trim() || null,
        assente: r.classList.contains('assente'),
        leva: r.querySelector('.btn-mini.leva')?.innerText.trim() || null
      }))
    })),
    errore: m.querySelector('.messaggio.errore')?.innerText.trim() || null
  }
})()`

// Compila un campo Vue: assegnare .value non basta, perche' v-model ascolta l'evento input
async function riempi(espressioneSel, valore) {
  await evalJS(`(() => { const el = (${espressioneSel}); if (!el) throw new Error('campo non trovato');
    el.value = ${JSON.stringify(valore)}
    el.dispatchEvent(new Event('input', {bubbles: true}))
    el.dispatchEvent(new Event('change', {bubbles: true})) })()`)
}

async function loginCome(utente) {
  await goto(`${BASE}/login`)
  const r = await evalJS(`(async () => {
    const res = await fetch('/api/auth/token', {method:'POST',
      headers:{'Content-Type':'application/x-www-form-urlencoded'},
      body: new URLSearchParams({username: ${JSON.stringify(utente)}, password: ${JSON.stringify(PW)}})})
    if (!res.ok) return {errore: 'token http ' + res.status}
    const {access_token} = await res.json()
    const me = await (await fetch('/api/auth/me', {headers:{Authorization:'Bearer '+access_token}})).json()
    // localStorage e' persistente nel profilo: un utente_data della PERSONA precedente lascerebbe la
    // pagina a decidere i pulsanti col ruolo sbagliato, e sarebbe un verde per il motivo sbagliato
    localStorage.clear()
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
    return {ok: true, ruolo: me.ruolo, admin: !!me.is_admin}
  })()`, { awaitPromise: true })
  if (!r || !r.ok) throw new Error('login fallito per ' + utente + ': ' + JSON.stringify(r))
  console.log(`  accesso come ${utente}: ruolo=${r.ruolo} admin=${r.admin}`)
  return r
}

async function attendiCard() {
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelectorAll('.torneo-card').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
}

const CLIC_CALENDARIO = `[...document.querySelectorAll('.torneo-azioni .btn-azione')]
  .find(b => /^Calendario$/.test(b.innerText.trim()))`
function clicConvoca(nome) {
  return `[...document.querySelectorAll('.gara-riga:not(.orfana)')]
    .filter(r => r.querySelector('.gara-verso strong')?.innerText.trim() === ${JSON.stringify(nome)})
    .map(r => [...r.querySelectorAll('.btn-icon')].find(b => (b.title || '').toLowerCase().startsWith('convoca')))
    .find(Boolean)`
}
function clicConvocaRiga(nome) {
  return `[...document.querySelectorAll('.conv-riga')]
    .filter(r => r.querySelector('.conv-nome')?.innerText.trim() === ${JSON.stringify(nome)})
    .map(r => r.querySelector('.btn-mini.primario')).find(Boolean)`
}

;(async () => {
  fs.rmSync(`${OUT}/profile`, { recursive: true, force: true })
  fs.mkdirSync(OUT, { recursive: true })
  const chrome = spawn('/usr/bin/google-chrome-stable', [
    '--headless=new', `--remote-debugging-port=${PORT}`, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', `--user-data-dir=${OUT}/profile`,
    '--window-size=1180,1600',
    // DEV serve l'app in HTTP: senza queste Chrome blocca in silenzio il blob generato dall'export.
    // Sono flag del browser di prova, non dell'app, che in produzione serve tutto in HTTPS
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

  // =============================================================== IL MISTER
  console.log('--- il mister, dalla card "Convocazioni Tornei" ---')
  await loginCome(UTENTE_MISTER)
  await goto(`${BASE}/tornei/${CAT_PULCINI}`)
  await attendiCard()

  let p = await evalJS(LEGGI_PAGINA)
  ck('il mister arriva col titolo "Convocazioni Tornei"', p.titoloPagina, 'Convocazioni Tornei')
  ck('la nota del mister dice cosa PUO fare, non che e\' in sola lettura',
     /registrare le gare/.test(p.nota) && !/sola lettura/.test(p.nota), true)
  // Il confine che deve reggere: solaLettura e' rimasto admin-only. Se qualcuno lo allargasse ai mister
  // per abilitare le gare, queste tre asserzioni diventano rosse
  ck('il mister NON vede "Nuovo torneo"', p.nuovoTorneo, false)
  ck('il mister NON vede "Modifica" sul torneo', p.azioniTorneo.includes('Modifica'), false)
  ck('il mister NON vede "Elimina" sul torneo', p.azioniTorneo.includes('Elimina'), false)
  // "+ Aggiungi gara" sta DENTRO il calendario, che e' v-if: leggerlo a calendario chiuso darebbe zero
  // per chiunque, anche per l'admin. Era il falso verde di questa versione del test — il dirigente
  // risultava "corretto" per la ragione sbagliata. Si asserisce solo DOPO aver aperto il calendario
  ck('a calendario chiuso il pulsante aggiungi non c\'e\' ancora, per nessuno', p.aggiungiGara.length, 0)

  await clickReale(CLIC_CALENDARIO)
  p = await evalJS(LEGGI_PAGINA)
  ck('il calendario si apre', p.calendariAperti >= 1, true)
  ck('il mister VEDE "+ Aggiungi gara": e\' la regola nuova',
     p.aggiungiGara.some(x => /Aggiungi gara/.test(x)), true)

  const conCat = p.gare.find(g => g.avversario === GARA_CON_CATEGORIA)
  const orfana = p.orfane.find(g => g.avversario === GARA_ORFANA)
  ck(`la gara "${GARA_CON_CATEGORIA}" e' in calendario`, !!conCat, true)
  ck('la gara con categoria offre Convoca', conCat && conCat.convoca, true)
  ck(`la gara senza categoria "${GARA_ORFANA}" e' in calendario`, !!orfana, true)
  ck('e non offre un Convoca attivo', orfana && orfana.convoca, false)
  ck('il pulsante spento dice perche\', invece di sparire e basta',
     /non ha una categoria/.test((orfana && orfana.motivoConvocaSpento) || ''), true)
  await shot('01-calendario-mister')

  // -------------------------------------------------- il modal della convocazione
  console.log('--- apro la convocazione di "' + GARA_CON_CATEGORIA + '" ---')
  await clickReale(clicConvoca(GARA_CON_CATEGORIA))
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelector('.modal-conv') || ++n > 30) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
  await sleep(1000)

  let m = await evalJS(LEGGI_MODAL)
  if (!m) throw new Error('il modal della convocazione non si e\' aperto')
  ck('il modal dice PER QUALE gara si sta scrivendo', m.titolo, 'Convocazione — ' + GARA_CON_CATEGORIA)
  ck('e per quale torneo', m.sottotitolo.includes(NOME_TORNEO), true)
  ck('e per quale categoria, non un id nudo', /Pulcini/.test(m.sottotitolo), true)
  // appuntamento e inizio gara: invertire i due e' l'errore che nel PDF dei tornei faceva uscire la
  // colonna tutta "-" senza che nessun test se ne accorgesse. Qui si guarda a schermo, perche' il
  // backend puo' anche essere giusto e la pagina leggere i campi sbagliati
  ck('l\'appuntamento della gara e\' 08:45', m.logistica.includes('appuntamento 08:45'), true)
  ck('l\'inizio gara e\' 09:30: i due orari non sono scambiati', m.logistica.includes('inizio 09:30'), true)
  ck('il campo della gara e\' scritto nel foglio', m.logistica.some(x => x.includes('Campo 1')), true)

  const col = (t) => (m.colonne.find(c => t.test(c.titolo)) || { righe: [] })
  ck('il foglio parte vuoto, e la pagina lo dice', col(/Convocati/).righe.length, 0)
  ck('il roster della categoria e\' popolato', col(/Da convocare/).righe.length > 0, true)
  await shot('02-modal-vuoto')

  // -------------------------------------------------- convoco due ragazzi
  const due = col(/Da convocare/).righe.slice(0, 2).map(r => r.nome)
  if (due.length !== 2) throw new Error('il roster ha meno di 2 ragazzi: le asserzioni sotto non misurerebbero niente')
  for (const nome of due) await clickReale(clicConvocaRiga(nome))
  m = await evalJS(LEGGI_MODAL)
  ck('convocare due ragazzi porta il foglio a 2', col(/Convocati/).righe.length, 2)
  ck('i convocati spariscono da "Da convocare"',
     col(/Da convocare/).righe.some(r => due.includes(r.nome)), false)
  ck('il foglio e\' numerato 1,2', col(/Convocati/).righe.map(r => r.pos).join(','), '1,2')

  await clickReale(`[...document.querySelectorAll('.conv-riga')].filter(r => r.querySelector('.conv-pos'))
    .map(r => r.querySelector('.btn-mini.leva')).find(Boolean)`)
  m = await evalJS(LEGGI_MODAL)
  ck('la leva diventa "assente"', col(/Convocati/).righe[0].leva, 'assente')
  ck('e il nome viene segnato come assente', col(/Convocati/).righe[0].assente, true)
  await shot('03-modal-due-convocati')

  // -------------------------------------------------- salvo e riapro
  await clickReale(`[...document.querySelectorAll('.modal-conv .modal-footer .btn-primary')]
                      .find(b => /Salva/.test(b.innerText))`)
  await sleep(1800)
  ck('salvare la convocazione non produce errori a schermo', await erroreSchermo(), 'null')
  ck('il modal si chiude dopo il salvataggio', await evalJS(`!!document.querySelector('.modal-conv')`), false)
  ck('il calendario resta aperto dove era (la chiave e\' torneo+sezione)',
     (await evalJS(LEGGI_PAGINA)).calendariAperti >= 1, true)

  await clickReale(clicConvoca(GARA_CON_CATEGORIA))
  await sleep(1500)
  m = await evalJS(LEGGI_MODAL)
  const riaperti = col(/Convocati/).righe
  ck('riaprendo il foglio i convocati ci sono ancora', riaperti.length, 2)
  ck('e sono gli stessi ragazzi salvati', riaperti.map(r => r.nome).join(' | '), due.join(' | '))
  ck('anche il segno "assente" e\' sopravvissuto', riaperti[0] && riaperti[0].assente, true)
  await shot('04-modal-riaperto')
  await clickReale(`document.querySelector('.modal-conv .modal-footer .btn-secondary')`)
  await sleep(500)

  // -------------------------------------------------- il mister aggiunge una gara
  console.log('--- il mister aggiunge una gara al calendario ---')
  const nuovaGara = 'Gara messa dal mister'
  await clickReale(`[...document.querySelectorAll('.btn-aggiungi')].find(b => /Aggiungi gara/.test(b.innerText))`)
  await sleep(700)
  const SEL_AVVERSARIO = `(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => !x.classList.contains('modal-conv'))
    if (!m) return null
    const g = [...m.querySelectorAll('.form-group')].find(g => g.querySelector('label')?.innerText.trim() === 'Avversario')
    return g ? g.querySelector('input') : null })()`
  await riempi(SEL_AVVERSARIO, nuovaGara)
  ck('il campo Avversario del modal gara e\' stato compilato davvero',
     await evalJS(`(${SEL_AVVERSARIO})?.value || null`), nuovaGara)
  await clickReale(`[...document.querySelectorAll('.modal:not(.modal-conv) .modal-footer .btn-primary')]
                      .find(b => /Salva/.test(b.innerText))`)
  await sleep(2000)
  ck('salvare la nuova gara non produce errori', await erroreSchermo(), 'null')
  p = await evalJS(LEGGI_PAGINA)
  ck('la gara aggiunta dal mister compare in calendario', p.gare.some(g => g.avversario === nuovaGara), true)
  ck('e nasce con il suo pulsante Convoca',
     (p.gare.find(g => g.avversario === nuovaGara) || {}).convoca, true)
  await shot('05-gara-del-mister')

  // =============================================================== IL DIRIGENTE
  console.log('--- il dirigente, sulla stessa pagina ---')
  await loginCome(UTENTE_DIRIGENTE)
  await goto(`${BASE}/tornei/${CAT_PULCINI}`)
  await attendiCard()
  const d = await evalJS(LEGGI_PAGINA)
  ck('il dirigente vede la stessa pagina', d.titoloPagina, 'Convocazioni Tornei')
  ck('la nota del dirigente dice "sola lettura"', /sola lettura/.test(d.nota), true)
  ck('il dirigente NON vede "Nuovo torneo"', d.nuovoTorneo, false)
  ck('il dirigente NON vede "Modifica" sul torneo', d.azioniTorneo.includes('Modifica'), false)

  await clickReale(CLIC_CALENDARIO)
  const d2 = await evalJS(LEGGI_PAGINA)
  ck('il dirigente il calendario lo legge eccome', d2.gare.length > 0, true)
  // Stesso requisito del mister: l'assenza del pulsante va misurata a calendario APERTO, perche' a
  // calendario chiuso e' assente anche per chi quel pulsante ce l'ha. Verde li' non voleva dire niente
  ck('ma il calendario aperto NON gli offre "+ Aggiungi gara"', d2.aggiungiGara.length, 0)
  ck('e nessuna gara gli offre Convoca', d2.gare.some(g => g.convoca), false)
  ck('neppure una spenta con il motivo: non vede proprio il controllo',
     d2.gare.some(g => g.convocaSpento), false)
  await shot('06-dirigente-sola-lettura')

  // =============================================================== controlli negativi
  // Rompono deliberatamente il DOM e verificano che il file se ne accorga. Un'asserzione che non puo'
  // diventare rossa non ha testato niente: e' il motivo per cui esistono questi tre.
  console.log('--- controlli negativi ---')
  await loginCome(UTENTE_MISTER)
  await goto(`${BASE}/tornei/${CAT_PULCINI}`)
  await attendiCard()
  await clickReale(CLIC_CALENDARIO)
  await evalJS(`(() => {
    // tolgo tutti i pulsanti Convoca e aggiungo un "+ Aggiungi gara" fasullo al dirigente: se il file
    // leggesse costanti invece del DOM, queste due righe non cambierebbero niente
    document.querySelectorAll('.btn-icon[title^="Convoca"]').forEach(b => b.remove())
    const c = document.querySelector('.calendario')
    if (c) { const b = document.createElement('button'); b.className = 'btn-aggiungi'; b.innerText = '+ Aggiungi gara truccata'; c.appendChild(b) }
    return null })()`)
  const dopoRottura = await evalJS(LEGGI_PAGINA)
  ck('CONTROLLO NEGATIVO: togliendo i pulsanti Convoca il file se ne accorge',
     dopoRottura.gare.some(g => g.convoca), false)
  ck('CONTROLLO NEGATIVO: senza manomissione quei pulsanti c\'erano',
     p.gare.some(g => g.convoca), true)

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
