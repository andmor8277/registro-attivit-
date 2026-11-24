// Verifica UI reale del FOGLIO DI CONVOCAZIONE in PDF.
//
// Perche' esiste: nessuno, prima di oggi, premeva mai il pulsante di export della pagina
// Convocazioni. `verifica_ui_weekend.sh` esporta i CALENDARI (ProgrammazionePartite), non il foglio
// dei convocati. Il documento che la societa' consegna ogni venerdi' -- e che da oggi produce anche il
// modal convocazione di Tornei.vue -- non aveva nessuna asserzione sopra. E' la classe di difetto gia'
// pagata qui: l'export "sembra funzionare", non compare nessun errore in console, e il file e' vuoto
// o ha le colonne sbagliate.
//
// Le due fonti, tenute separate di proposito: il BROWSER dice cosa viene dipinto, il DB dice se e'
// vero. I cognomi attesi non sono scritti a mano qui dentro -- si leggono dall'API con il token della
// pagina, cosi' il test regge quando il titolare aggiunge un ragazzo alla squadra.
//
// Non si lancia a mano: lo invoca scripts/test/verifica_ui_convocazioni_pdf.sh, che crea e ripulisce
// gli utenti di prova con prepara_demo_tornei.sh e passa le credenziali.
const fs = require('fs')
const { spawn, execFileSync } = require('child_process')

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const PW = process.argv[2]
const UTENTE = process.argv[3] || 'demo_tornei_mister1'
const CAT = process.argv[4] || '19'
const MAX_FOGLI = parseInt(process.argv[5] || '3', 10)
const OUT = process.env.THOF_UI_OUT || '/tmp/opencode/ui-conv-pdf'
const PORT = 9225   // porta sua: i test UI girano in sequenza, non in parallelo

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
  return await evalJS(`(document.querySelector('.error, .alert-errore, .errore')?.innerText || '').slice(0,160)`)
}

const risultati = []
function ck(nome, reale, atteso) {
  const ok = String(reale) === String(atteso)
  risultati.push({ nome, ok, reale, atteso })
  console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${nome}${ok ? '' : ` -> '${reale}' (atteso '${atteso}')`}`)
}

// pdftotext spezza le frasi lunghe e interlaccia le celle delle testate: le asserzioni si fanno sul
// testo APPIATTITO, senza pretendere contiguita', tranne dove serve la POSIZIONE (appuntamento contro
// inizio gara), che si legge invece riga per riga
function piatto(t) { return String(t || '').replace(/\s+/g, ' ').trim() }
function righe(t) { return String(t || '').split('\n').map(r => r.trim()).filter(Boolean) }

async function loginCome(utente) {
  await goto(`${BASE}/login`)
  const r = await evalJS(`(async () => {
    const res = await fetch('/api/auth/token', {method:'POST',
      headers:{'Content-Type':'application/x-www-form-urlencoded'},
      body: new URLSearchParams({username: ${JSON.stringify(utente)}, password: ${JSON.stringify(PW)}})})
    if (!res.ok) return {errore: 'token http ' + res.status}
    const {access_token} = await res.json()
    const me = await (await fetch('/api/auth/me', {headers:{Authorization:'Bearer '+access_token}})).json()
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

;(async () => {
  fs.rmSync(`${OUT}/profile`, { recursive: true, force: true })
  fs.mkdirSync(OUT, { recursive: true })
  const chrome = spawn('/usr/bin/google-chrome-stable', [
    '--headless=new', `--remote-debugging-port=${PORT}`, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', `--user-data-dir=${OUT}/profile`,
    '--window-size=1180,1600',
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
      if (m.id && pending.has(m.id)) {
        const p = pending.get(m.id); pending.delete(m.id)
        m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result)
      }
    }
  })
  await send('Runtime.enable')
  await send('Page.enable')

  const login = await loginCome(UTENTE)

  const DL = `${OUT}/download`
  await send('Page.setDownloadBehavior', { behavior: 'allow', downloadPath: DL })
  await send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: DL }).catch(() => {})
  async function scarica(etichetta, espressioneElemento) {
    // Il nome del file lo DECIDE L'APP (`Convocazioni_<categoria>_<date>.pdf`), non chi scrive il test:
    // aspettare un nome inventato qui significava non trovare mai il file mentre il file c'era, e il
    // fallimento sembrava un difetto dell'export. Si svuota la cartella, si clicca, e si aspetta che
    // comparia UN pdf qualunque -- che e' anche l'unico modo di asserire il nome che l'app ha scelto
    fs.mkdirSync(DL, { recursive: true })
    for (const f of fs.readdirSync(DL)) fs.rmSync(`${DL}/${f}`, { recursive: true, force: true })
    await clickReale(espressioneElemento)
    for (let i = 0; i < 80; i++) {
      const pdf = fs.readdirSync(DL).filter(f => f.toLowerCase().endsWith('.pdf'))
      if (pdf.length) {
        const percorso = `${DL}/${pdf[0]}`
        for (let k = 0; k < 20 && fs.statSync(percorso).size <= 500; k++) await sleep(250)
        await sleep(400)
        const byte = fs.statSync(percorso).size
        const testo = execFileSync('pdftotext', ['-layout', percorso, '-'], { encoding: 'utf8' })
        fs.mkdirSync(`${OUT}/pdf-text`, { recursive: true })
        fs.writeFileSync(`${OUT}/pdf-text/testo-${etichetta}.txt`, testo)
        // Si conserva una copia per foglio: la cartella download viene svuotata a ogni export, quindi
        // a fine run resterebbe solo l'ultimo PDF e il wrapper non potrebbe controllare gli altri
        fs.mkdirSync(`${OUT}/pdfs`, { recursive: true })
        fs.copyFileSync(percorso, `${OUT}/pdfs/${etichetta}--${percorso.split('/').pop()}`)
        return { testo, byte, nome: pdf[0] }
      }
      await sleep(250)
    }
    console.log('   perche\' nessun file:', await erroreSchermo(), '| cartella:',
                fs.readdirSync(DL).join(',') || '(vuota)', '| console:',
                erroriConsole.filter(e => !/favicon|DevTools|Vue devtools/i.test(e)).slice(-3).join(' // ') || 'pulita')
    return null
  }

  // ---- cosa dice il DB: i fogli della categoria, con i cognomi VERI e la logistica vera ----
  console.log('--- cosa c\'e\' in banca dati per la categoria ' + CAT + ' ---')
  const attese = await evalJS(`(async () => {
    const tk = localStorage.getItem('token')
    const H = {headers:{Authorization:'Bearer '+tk}}
    const lista = await (await fetch('/api/convocazioni/?categoria_id=${CAT}', H)).json()
    const out = []
    for (const f of (Array.isArray(lista) ? lista : [])) {
      const det = await (await fetch('/api/convocazioni/' + f.id, H)).json()
      const gare = (det.gare || []).map(g => ({
        titolo: g.gara || '', data: g.data || '', campo: g.campo || '', indirizzo: g.indirizzo || '',
        appuntamento: g.appuntamento || '', inizio_gara: g.inizio_gara || '',
        cognomi: (g.giocatori || []).filter(x => x && x.cognome).map(x => String(x.cognome).trim())
      }))
      out.push({ id: f.id, data_inizio: f.data_inizio || '', note: f.note || '', gare })
    }
    // GET /categorie/{id} NON ESISTE (esistono /all e /archived): qui la fetch andava in 404, il .catch
    // restituiva {} e l'asserzione sull'intestazione diventava vera senza confrontare niente. Un falso
    // verde costruito dal fallback. Si legge da /categorie/all, la STESSA fonte che usa la pagina, e la
    // premessa "l'etichetta l'ho trovata" diventa essa stessa un'asserzione
    const tutte = await (await fetch('/api/categorie/all', H)).json().catch(() => [])
    const cat = (Array.isArray(tutte) ? tutte : []).find(c => String(c.id) === String(${CAT})) || null
    const soc = JSON.parse(localStorage.getItem('societa_data') || '{}')
    return { fogli: out, categoria: cat, societa: soc }
  })()`, { awaitPromise: true })

  const conGente = (attese.fogli || []).filter(f => f.gare.some(g => g.cognomi.length > 0))
  console.log(`  ${attese.fogli.length} fogli, ${conGente.length} con convocati dentro`)
  // Guardiano, non asserzione: senza fogli con gente dentro ogni asserzione sotto sarebbe verde perche'
  // non c'e' niente da confrontare
  if (!conGente.length) {
    console.log('  FAIL prerequisito: nessun foglio della categoria ha convocati, il test non puo\' misurare niente')
    console.log('  0 passati, 1 falliti (prerequisiti)')
    await send('Browser.close').catch(() => {}); chrome.kill('SIGKILL'); return
  }

  const SOC = (attese.societa && (attese.societa.nome || attese.societa.nome_breve)) || ''
  // Il foglio scrive `nome + anno` affiancati ("Pulcini 2016"), la pagina li scrive "2016 - Pulcini":
  // si asserisce sui DUE tokeni, non su una stringa composta che sarebbe diversa fra documento e pagina
  const CAT_TOKENI = [attese.categoria?.nome, attese.categoria?.anno].filter(Boolean).map(String)
  ck('l\'etichetta della categoria e\' stata trovata (senza, l\'asserzione sotto non misurerebbe niente)',
     CAT_TOKENI.length, 2)

  await goto(`${BASE}/convocazioni/${CAT}`)
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelectorAll('.wk-storico').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })

  const chip = await evalJS(`document.querySelectorAll('.wk-storico').length`)
  ck('la pagina mostra lo storico dei fogli (altrimenti non c\'e\' nulla da esportare)', chip > 0, true)

  const CLIC_ESPORTA = `[...document.querySelectorAll('.page-head .btn')].find(b => /^Foglio convocazione \\(PDF\\)$/.test(b.innerText.trim()))`
  ck('il pulsante "Foglio convocazione (PDF)" c\'e\'', await evalJS(`Boolean(${CLIC_ESPORTA})`), true)

  // I chip dello storico non hanno un data-id: si scelgono per DATA, che e' l'unica cosa che li
  // distingue a schermo. Selezionarli per indice avrebbe significato leggere le aspettative di un
  // foglio e confrontarle con il PDF di un altro -- verde o rosso per la ragione sbagliata.
  // Lo storico della pagina, inoltre, MOSTRA SOLO i fogli con data_fine nel passato: un foglio senza
  // data_fine non ha nessun chip, quindi non e' selezionabile e non si puo' esportare. Chiederlo al
  // test sarebbe rosso sul test, non sull'app
  const chipTesto = await evalJS(`[...document.querySelectorAll('.wk-storico')].map(b => b.innerText.trim())`)
  console.log('  chip nello storico: ' + JSON.stringify(chipTesto))
  const dataShort = d => { if (!d) return ''; const [y, m, g] = String(d).split('-'); return `${g}/${m}/${y.slice(2)}` }

  const selezionabili = conGente.filter(f => chipTesto.some(t => t.includes(dataShort(f.data_inizio))))
  ck('almeno un foglio con convocati e selezionabile dallo storico (senza, non ci sarebbe niente da esportare)',
     selezionabili.length > 0, true)
  if (!selezionabili.length) {
    console.log('  FAIL prerequisito: nessun foglio con convocati compare nello storico, il test non misura niente')
    console.log('  0 passati, 1 falliti (prerequisiti)')
    await send('Browser.close').catch(() => {}); chrome.kill('SIGKILL'); return
  }

  const presi = selezionabili.slice(0, MAX_FOGLI)
  // Il termine di paragone per il confronto di forma col foglio di torneo: un foglio del weekend a GARA
  // UNICA, perche' e' lo stesso ramo di codice (singleGara) che percorre il foglio di torneo. Un
  // multi-gara avrebbe un layout diverso per progetto, e il confronto direbbe una falsita'
  let testoWeekendSingolo = null
  for (const f of presi) {
    console.log(`--- apro ed esporto il foglio ${f.id} (${f.data_inizio}, ` +
                `${f.gare.reduce((s, g) => s + g.cognomi.length, 0)} convocati su ${f.gare.length} gare) ---`)
    const ds = dataShort(f.data_inizio)
    const CLIC_CHIP = `[...document.querySelectorAll('.wk-storico')].find(b => b.innerText.includes(${JSON.stringify(ds)}))`
    await clickReale(CLIC_CHIP)
    // non un sonno a caso: si aspetta che il numero di tab-gara sia QUELLO del foglio chiesto, che e'
    // anche la prova che il chip cliccato ha caricato il foglio giusto e non il vicino
    const tabViste = await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
      const k = document.querySelectorAll('.gtab').length
      if (k === ${f.gare.length} || ++n > 40) { clearInterval(t); res(k) } }, 150) })`, { awaitPromise: true })
    ck(`  il foglio ${f.id} si apre con le sue ${f.gare.length} gare (se il chip fosse sbagliato, qui si vede)`,
       tabViste, f.gare.length)
    await sleep(400)

    const d = await scarica(`foglio-${f.id}`, CLIC_ESPORTA)
    ck(`il foglio ${f.id} scarica un PDF`, d !== null, true)
    if (!d) continue
    ck(`  ${f.id}: il file scaricato non e' minuscolo (${d.byte} byte)`, d.byte > 2000, true)
    ck(`  ${f.id}: il nome del file dice categoria e date (${d.nome})`,
       new RegExp(`^Convocazioni_.*${f.data_inizio.split('-').reverse().join('-')}`).test(d.nome), true)
    const P = piatto(d.testo), R = righe(d.testo)

    ck(`  ${f.id}: l'intestazione del documento e' "CONVOCAZIONE GARE"`, /CONVOCAZIONE GARE/.test(P), true)
    // Nessuna delle due asserzioni sotto ammette il "non ho letto l'atteso, passo": `X ? ... : true` e'
    // il modo in cui un fallback vuoto (un 404, un localStorage senza societa_data) rende verde un
    // confronto che non ha confrontato niente. Se l'atteso manca, il test deve diventare ROSSO
    ck(`  ${f.id}: il documento reca il nome della societa' ${JSON.stringify(SOC)}`,
       CAT_TOKENI.length === 2 && SOC.length > 0 && P.toUpperCase().includes(SOC.toUpperCase()), true)
    ck(`  ${f.id}: il documento reca la categoria ${JSON.stringify(CAT_TOKENI.join(' '))}`,
       CAT_TOKENI.length === 2 && CAT_TOKENI.every(t => P.toUpperCase().includes(t.toUpperCase())), true)
    // Il foglio ha TRE layout (singolo verticale, singolo orizzontale, multi-gara a colonne) e non hanno
    // le stesse etichette: il multi-gara a colonne non ha la testata "INFO GARA" e mette l'orario dentro
    // una riga "Data / Inizio". Il layout non lo deduco replicando la matematica delle larghezze della
    // pagina (il test misurerebbe la mia replica, non l'app): lo leggo dai marcatori del documento.
    const haDataInizio = R.some(r => r.includes('Data / Inizio'))
    const haInizioGara = R.some(r => r.includes('Inizio gara'))
    // "Appuntamento" si spezza su due righe quando la colonna e' stretta (il difetto gia' visto per
    // "Appuntamen/to" nel calendario tornei): si riconosce dal prefisso, non dalla parola intera
    const ETICHETTA_APPUNT = 'Appuntament'
    // Le righe si selezionano per CONTENERE l'etichetta, non per cominciare con essa: nel blocco info a
    // quattro colonne (due coppie etichetta/valore per riga) "Appuntamento" sta a meta' della riga che
    // comincia con "Indirizzo", e "Campo" in mezzo a quella che comincia con "Data". Selezionare per
    // prefisso avrebbe dato rosso su un documento perfettamente a posto
    const rigaCon = etichetta => R.find(r => r.includes(etichetta)) || ''

    if (f.gare.length === 1) {
      ck(`  ${f.id}: la tabella INFO GARA c'e' (foglio a gara unica)`, /INFO GARA/.test(P), true)
    } else {
      ck(`  ${f.id}: ogni colonna gara ha il suo blocco logistico ("Campo" presente)`,
         R.some(r => r.includes('Campo')), true)
      ck(`  ${f.id}: il layout a colonne ha la riga dei tempi ("Data / Inizio" o "Inizio gara")`,
         haDataInizio || haInizioGara, true)
    }
    ck(`  ${f.id}: la tabella giocatori ha la colonna "Cognome Nome"`, /Cognome\s+Nome/.test(P), true)
    ck(`  ${f.id}: il pie' dice "Pagina 1 di"`, /Pagina 1 di/.test(P), true)

    // I cognomi veri, letti dal DB. La premessa (ce ne sono) e' asserita: senza, "tutti i cognomi ci
    // sono" diventa verde anche con un documento vuoto -- e' il falso verde gia' visto sull'export tornei
    const tutti = f.gare.flatMap(g => g.cognomi)
    const unici = [...new Set(tutti)]
    ck(`  ${f.id}: il DB dice che ci sono ${unici.length} cognomi da stampare (> 0)`, unici.length > 0, true)
    const mancanti = unici.filter(c => !P.toUpperCase().includes(String(c).toUpperCase()))
    ck(`  ${f.id}: tutti i ${unici.length} cognomi convocati sono nel documento` +
       (mancanti.length ? ` (mancano: ${mancanti.slice(0, 4).join(', ')})` : ''), mancanti.length, 0)

    // La logistica della gara 1. Si legge dalla POSIZIONE, non dalla presenza del valore: se appuntamento
    // e inizio gara si invertono, entrambi i valori restano nel documento e un'asserzione "il testo
    // contiene 11:00" sarebbe verde lo stesso. E si legge dalla PRIMA colonna, perche' nel multi-gara le
    // tre colonne stanno sulla STESSA riga di pdftotext: il valore della gara 2 soddisferebbe
    // l'asserzione scritta per la gara 1
    const g1 = f.gare[0]
    const primaColonna = (riga, etichetta) => {
      const parti = String(riga).split(etichetta)
      return parti.length > 1 ? (parti[1].split(etichetta)[0] || '') : ''
    }
    if (g1.appuntamento) {
      const riga = rigaCon(ETICHETTA_APPUNT)
      ck(`  ${f.id}: l'appuntamento della gara 1 e' ${g1.appuntamento} (sulla sua riga, prima colonna)`,
         primaColonna(riga, ETICHETTA_APPUNT).includes(g1.appuntamento), true)
    }
    if (g1.inizio_gara) {
      const etichetta = haInizioGara ? 'Inizio gara' : 'Data / Inizio'
      ck(`  ${f.id}: l'inizio gara della gara 1 e' ${g1.inizio_gara} (sulla sua riga, prima colonna)`,
         primaColonna(rigaCon(etichetta), etichetta).includes(g1.inizio_gara), true)
    }
    if (g1.appuntamento && g1.inizio_gara) {
      // Se i due valori fossero uguali le due asserzioni sopra non distinguerebbero lo scambio: qui si
      // asserisce che il confronto ha un senso, la stessa trappola del "confronta lo stato con se stesso"
      ck(`  ${f.id}: appuntamento (${g1.appuntamento}) e inizio gara (${g1.inizio_gara}) sono diversi ` +
         `(la prova anti-inversione puo' distinguere)`, g1.appuntamento !== g1.inizio_gara, true)
    }
    if (g1.campo) {
      ck(`  ${f.id}: il campo "${g1.campo}" e' sulla sua riga, prima colonna`,
         primaColonna(rigaCon('Campo'), 'Campo').includes(g1.campo), true)
    }
    if (f.note) ck(`  ${f.id}: le note del foglio compariono nel riquadro NOTE`,
                   /NOTE/.test(P) && P.toUpperCase().includes(String(f.note).toUpperCase().slice(0, 20)), true)
    // Le asserzioni sulla logistica sopra sono condizionate al valore atteso: se il DB non ce l'ha, non
    // girano e il totale si accorcia in silenzio. Questa rende VISIBILE il buco, perche' un'asserzione
    // che non gira assomiglia a un'asserzione verde
    const attesiMancanti = ['appuntamento', 'inizio_gara', 'campo'].filter(k => !g1[k])
    ck(`  ${f.id}: la logistica della gara 1 era completa (altrimenti l'asserzione corrispondente ` +
       `non ha girato)`, attesiMancanti.join(','), '')
    if (f.gare.length === 1) testoWeekendSingolo = d.testo
  }

  // ============================ IL FOGLIO DI UNA GARA DI TORNEO ============================
  // Da oggi lo stesso documento lo produce anche il modal convocazione di Tornei.vue. Due ordini di
  // asserzioni, e la seconda e' quella che conta:
  //   1. il CONTENUTO: i ragazzi che ho convocato a schermo ci sono, gli altri no, la logistica della
  //      gara e' al suo posto (appuntamento e inizio gara NON scambiati);
  //   2. la FORMA CONDIVISA col foglio del weekend: l'inventario delle etichette dei due documenti deve
  //      essere lo STESSO. Condividere il modulo senza misurare l'output non prova niente, perche' due
  //      pagine possono importare lo stesso file e riscriverci il titolo una per conto sua -- e' gia'
  //      successo coi due calendari, ed e' per questo che verifica_ui_weekend.sh confronta i PDF.
  console.log('--- il foglio di una gara di torneo, dal modal di Tornei.vue ---')
  await goto(`${BASE}/tornei/${CAT}`)
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (document.querySelectorAll('.torneo-card').length || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
  const nCard = await evalJS(`document.querySelectorAll('.torneo-card').length`)
  ck('la pagina dei tornei mostra delle card', nCard > 0, true)
  // `.torneo-nome` e' il selettore vero della card (non un h2/h3 generico: nella card il titolo e' uno
  // span). Serve a restringere la ricerca dell'atteso ai tornei che ho DAVANTI, non a tutti quelli della
  // societa'. Se leggesse vuoto, il filtro sotto cadrebbe su "tutti" e un'omonimia fra tornei darebbe un
  // rosso del test: per questo il valore letto viene stampato
  const nomiCard = await evalJS(`[...document.querySelectorAll('.torneo-card .torneo-nome')].map(e => e.innerText.trim())`)
  console.log('  card a schermo: ' + JSON.stringify(nomiCard))

  await clickReale(`[...document.querySelectorAll('.torneo-azioni .btn-azione')].find(b => /^Calendario$/.test(b.innerText.trim()))`)
  const righeGara = await evalJS(`[...document.querySelectorAll('.gara-riga:not(.orfana)')].map(r => ({
    avversario: (r.querySelector('.gara-verso strong')?.innerText || '').trim(),
    convoca: [...r.querySelectorAll('.btn-icon')].some(b => (b.title || '').toLowerCase().includes('convoca') && !b.disabled)
  }))`).catch(() => [])
  console.log('  gare in calendario: ' + JSON.stringify(righeGara.map(r => r.avversario)))
  const gara = righeGara.find(r => r.convoca)
  ck('c\'e\' una gara con il Convoca attivo (senza, non c\'e\' nessun foglio da esportare)', !!gara, true)

  if (gara) {
    // La logistica vera, dall'API, con `ora` e `ora_appuntamento` da due campi DISTINTI: e' l'unico modo
    // di accorgersi che il foglio li ha scambiati.
    // ATTENZIONE, e' il gotcha gia' documentato sul badge della card: `gare` da GET /tornei/ e' un NUMERO
    // (il conteggio), l'array delle gare sta solo in GET /tornei/{id}. Iterare il primo dava
    // "number 4 is not iterable" -- un errore rumoroso, che e' la direzione giusta, ma il dato giusto va
    // preso dove sta. Si cerca fra i tornei la cui card e' davvero a schermo, perche' la stessa avversaria
    // puo' esistere in due tornei e un atteso preso dall'altro darebbe un rosso del test, non dell'app
    const atteso = await evalJS(`(async () => {
      const tk = localStorage.getItem('token')
      const H = {headers:{Authorization:'Bearer '+tk}}
      const ts = await (await fetch('/api/tornei/', H)).json()
      const lista = Array.isArray(ts) ? ts : []
      const aSchermo = ${JSON.stringify(nomiCard)}
      const candidati = lista.filter(t => aSchermo.some(n => n && String(t.nome).startsWith(String(n).slice(0, 8))))
      const daGuardare = candidati.length ? candidati : lista
      for (const t of daGuardare) {
        const det = await (await fetch('/api/tornei/' + t.id, H)).json()
        for (const g of (det.gare || [])) {
          if (String(g.avversario || '').trim() === ${JSON.stringify(gara.avversario)})
            return { torneo: det.nome, id: t.id, avversario: g.avversario, data: g.data || '',
                     campo: g.campo || '', indirizzo: g.indirizzo || '',
                     ora: g.ora || '', ora_appuntamento: g.ora_appuntamento || '' }
        }
      }
      return null
    })()`, { awaitPromise: true })
    ck('la gara scelta esiste nell\'API con la sua logistica', !!atteso, true)
    console.log('  attesa dal torneo ' + JSON.stringify(atteso && atteso.torneo) + ': ' + JSON.stringify(atteso))

    await clickReale(`[...document.querySelectorAll('.gara-riga:not(.orfana)')]
      .filter(r => (r.querySelector('.gara-verso strong')?.innerText || '').trim() === ${JSON.stringify(gara.avversario)})
      .map(r => [...r.querySelectorAll('.btn-icon')].find(b => (b.title || '').toLowerCase().includes('convoca') && !b.disabled))
      .find(Boolean)`)
    const modalAperto = await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
      if (document.querySelector('.modal-conv .modal-footer .btn-esporta') || ++n > 40) { clearInterval(t); res(Boolean(document.querySelector('.modal-conv'))) } }, 150) })`,
      { awaitPromise: true })
    ck('il modal della convocazione si apre', modalAperto, true)

    const LEGGI_PULSANTE = `(() => { const b = [...document.querySelectorAll('.modal-conv .modal-footer .btn-esporta')]
        .find(x => /^Foglio convocazione \\(PDF\\)$/.test(x.innerText.trim()))
      return b ? { c: true, spento: !!b.disabled, motivo: b.title || '' } : { c: false } })()`

    // Si parte da una lista VUOTA, tolendo chi c'era gia' (un foglio salvato da una run precedente).
    // Serve per avere entrambi i rami del pulsante: spento con zero convocati e acceso con qualcuno
    for (let i = 0; i < 80; i++) {
      const n = await evalJS(`document.querySelectorAll('.modal-conv .conv-riga .btn-mini.pericolo').length`)
      if (!n) break
      await clickReale(`document.querySelector('.modal-conv .conv-riga .btn-mini.pericolo')`)
    }
    const primaDiAggiungere = await evalJS(`[...document.querySelectorAll('.modal-conv .conv-riga')]
      .filter(r => r.querySelector('.conv-pos')).map(r => (r.querySelector('.conv-nome')?.innerText || '').trim())`)
    ck('il foglio del modal ora e\' vuoto', primaDiAggiungere.length, 0)

    const b0 = await evalJS(LEGGI_PULSANTE)
    ck('il pulsante "Foglio convocazione (PDF)" c\'e\' nel footer del modal', b0.c, true)
    ck('con zero convocati e\' SPENTO (un foglio vuoto all\'organizzatore e\' plausibile e falso)', b0.spento, true)
    ck('e il motivo e\' scritto nel title: spento senza motivo, a schermo, sembra assente',
       /nessun giocatore|vuoto/i.test(b0.motivo), true)

    const daConvocare = await evalJS(`[...document.querySelectorAll('.modal-conv .conv-riga')]
      .filter(r => !r.querySelector('.conv-pos')).map(r => (r.querySelector('.conv-nome')?.innerText || '').trim())`)
    ck('ci sono ragazzi da convocare (senza, il foglio non si puo\' riempire)', daConvocare.length > 0, true)
    const presiConv = daConvocare.slice(0, 3)
    for (const nome of presiConv) {
      await clickReale(`[...document.querySelectorAll('.modal-conv .conv-riga')]
        .filter(r => (r.querySelector('.conv-nome')?.innerText || '').trim() === ${JSON.stringify(nome)})
        .map(r => r.querySelector('.btn-mini.primario')).find(Boolean)`)
    }
    const convocati = await evalJS(`[...document.querySelectorAll('.modal-conv .conv-riga')]
      .filter(r => r.querySelector('.conv-pos')).map(r => (r.querySelector('.conv-nome')?.innerText || '').trim())`)
    ck('convocati ' + presiConv.length + ' ragazzi dal modal', convocati.length, presiConv.length)
    const b1 = await evalJS(LEGGI_PULSANTE)
    ck('con dei convocati il pulsante "Foglio convocazione (PDF)" si accende', b1.spento, false)

    const dT = await scarica('torneo', `[...document.querySelectorAll('.modal-conv .modal-footer .btn-esporta')]
      .find(x => /^Foglio convocazione \\(PDF\\)$/.test(x.innerText.trim()))`)
    ck('il foglio di convocazione del torneo scarica un PDF', dT !== null, true)
    if (dT) {
      const PT = piatto(dT.testo), RT = righe(dT.testo)
      ck('  torneo: il file non e\' minuscolo (' + dT.byte + ' byte)', dT.byte > 2000, true)
      ck('  torneo: l\'intestazione e\' "CONVOCAZIONE GARE" come nel weekend', /CONVOCAZIONE GARE/.test(PT), true)
      ck('  torneo: reca la societa\' ' + JSON.stringify(SOC),
         SOC.length > 0 && PT.toUpperCase().includes(SOC.toUpperCase()), true)
      ck('  torneo: reca la categoria ' + JSON.stringify(CAT_TOKENI.join(' ')),
         CAT_TOKENI.length === 2 && CAT_TOKENI.every(t => PT.toUpperCase().includes(t.toUpperCase())), true)
      // Il titolo della singola gara: e' `avversario` di tornei_gare, l'analogo del titolo che il weekend
      // stampa in rosso. Senza, il foglio non dice nemmeno contro chi si gioca
      ck('  torneo: il titolo della gara e\' l\'avversario ' + JSON.stringify(gara.avversario),
         PT.toUpperCase().includes(String(gara.avversario).toUpperCase()), true)
      ck('  torneo: la tabella giocatori ha la colonna "Cognome Nome"', /Cognome\s+Nome/.test(PT), true)
      ck('  torneo: il pie\' dice "Pagina 1 di"', /Pagina 1 di/.test(PT), true)

      // I nomi che ho convocato IO, letti a schermo -- non cognomi scritti a mano nel test, cosi' regge
      // quando il titolare aggiunge un ragazzo alla squadra
      ck('  torneo: i convocati a schermo sono ' + convocati.length + ' (> 0, altrimenti "tutti i nomi ci sono" sarebbe verde su un foglio vuoto)',
         convocati.length > 0, true)
      const mancT = convocati.filter(n => !PT.toUpperCase().includes(String(n).toUpperCase()))
      ck('  torneo: tutti i convocati a schermo sono nel documento' +
         (mancT.length ? ' (mancano: ' + mancT.slice(0, 4).join(', ') + ')' : ''), mancT.length, 0)
      // Il verso opposto, che e' quello che tiene il foglio onesto: chi NON ho convocato non deve esserci.
      // Si esclude chi ha un nome contenuto in quello di un convocato ("Bianchi Luca" dentro "Bianchi Luca
      // Maria"): sarebbe un rosso del test, non dell'app
      const giaDentro = n => convocati.some(c => String(c).toUpperCase().includes(String(n).toUpperCase()))
      const nonConv = [...new Set(daConvocare.filter(n => !presiConv.includes(n) && !giaDentro(n)))]
      ck('  torneo: ci sono ' + nonConv.length + ' non convocati da controllare (> 0)', nonConv.length > 0, true)
      const intrusi = nonConv.filter(n => PT.toUpperCase().includes(String(n).toUpperCase()))
      ck('  torneo: NESSUN non convocato finisce nel documento' +
         (intrusi.length ? ' (intrusi: ' + intrusi.slice(0, 4).join(', ') + ')' : ''), intrusi.length, 0)

      // La logistica, con l'anti-inversione. Qui il valore lo mette il FRONTEEND leggendo tornei_gare,
      // ed e' esattamente il punto dove il PDF dei calendari usciva tutto "-" perche' leggeva
      // `appuntamento` al posto di `ora_appuntamento`
      if (atteso) {
        // Il foglio di torneo ha UNA sola colonna di dati (gara unica), quindi il lettore prende tutto
        // quello che viene DOPO l'etichetta, senza tagliare sulla successiva come fa il lettore del
        // weekend multi-gara. Serve: il campo di questa gara si chiama "Campo 1", e spezzare sulla parola
        // "Campo" avrebbe tagliato via proprio il valore, dando un rosso che nel documento non c'era
        // (`Campo          Campo 1`). L'etichetta va seguita da due spazi, che e' il separatore di cella:
        // un ragazzo di cognome "Campo" non puo' essere scambiato per l'etichetta
        const esc = t => String(t).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        // L'etichetta va cercata TOLLERANDO sia la forma intera sia quella spezzata a meta': nel foglio di
        // torneo (colonna larga) pdftotext scrive "Appuntamento   08:45", in quello del weekend a due
        // colonne scrive "Appuntament   10:45" perche' la cella e' stretta e la parola si spezza.
        // Cercarne solo una delle due dava un rosso su un documento perfettamente a posto.
        const rCon = etichetta => RT.find(r => new RegExp(esc(etichetta) + '\\w{0,2}\\s{2,}').test(r)) || ''
        const dopo = (riga, etichetta) => {
          const i = String(riga).indexOf(etichetta)
          return i < 0 ? '' : String(riga).slice(i + etichetta.length)
        }
        ck('  torneo: la riga INFO GARA c\'e\' (foglio a gara unica, come il weekend)', /INFO GARA/.test(PT), true)
        if (atteso.ora_appuntamento) {
          ck('  torneo: l\'appuntamento e\' ' + atteso.ora_appuntamento + ' (da ora_appuntamento)',
             dopo(rCon('Appuntament'), 'Appuntament').includes(atteso.ora_appuntamento), true)
        }
        if (atteso.ora) {
          ck('  torneo: l\'inizio gara e\' ' + atteso.ora + ' (da ora)',
             dopo(rCon('Inizio gara'), 'Inizio gara').includes(atteso.ora), true)
        }
        ck('  torneo: ora e ora_appuntamento sono due valori diversi (la prova anti-inversione puo\' distinguere)',
           !!atteso.ora && !!atteso.ora_appuntamento && atteso.ora !== atteso.ora_appuntamento, true)
        const mancantiLog = ['ora', 'ora_appuntamento', 'campo'].filter(k => !atteso[k])
        ck('  torneo: la logistica della gara era completa (altrimenti l\'asserzione sopra non ha girato)',
           mancantiLog.join(','), '')
        if (atteso.campo) {
          ck('  torneo: il campo "' + atteso.campo + '" e\' sulla sua riga',
             dopo(rCon('Campo'), 'Campo').includes(atteso.campo), true)
        }
        // La riga Allenatore DEVE esserci, vuota: la scelta del titolare e' di non metterci il referente
        // del torneo, ma "non c'e' la riga" e "la riga dice che non c'e'" a schermo si somigliano, e la
        // seconda e' l'unica onesta
        ck('  torneo: la riga Allenatore c\'e\' e dice che non c\'e\' nessun allenatore (\'—\', non assente)',
           /^\s*(—|-)/.test(dopo(rCon('Allenatore'), 'Allenatore')), true)
      }

      // IL CONFRONTO DI FORMA. Le etichette strutturali sono indipendenti dal contenuto: se una delle due
      // pagine si riscrive il titolo, perde la riga Allenatore o smette di scrivere il pie' di pagina,
      // i due inventari divergono. E' l'asserzione che rende reale la condivisione del modulo
      const MARCATORI = ['CONVOCAZIONE GARE', 'INFO GARA', 'Cognome Nome', 'Pagina 1 di',
                         'Data', 'Campo', 'Indirizzo', 'Appuntament', 'Inizio gara', 'Allenatore', 'Stagione']
      const inventario = t => {
        const P = piatto(t)
        const o = {}
        for (const m of MARCATORI) o[m] = P.includes(m)
        return o
      }
      ck('il confronto di forma ha un termine di paragone (un foglio del weekend a gara unica)',
         !!testoWeekendSingolo, true)
      if (testoWeekendSingolo) {
        const A = inventario(testoWeekendSingolo), B = inventario(dT.testo)
        const divergenti = MARCATORI.filter(m => A[m] !== B[m])
        ck('il foglio di torneo ha la STESSA forma di quello del weekend (' + MARCATORI.length + ' etichette)',
           divergenti.join(','), '')
        if (divergenti.length) {
          console.log('   divergono: ' + divergenti.map(m => m + (A[m] ? ' (solo nel weekend)' : ' (solo nel torneo)')).join(', '))
        }
      }
    }
  }

  const puliti = erroriConsole.filter(e => !/favicon|DevTools|Vue devtools|WebSocket|Failed to load resource/i.test(e))
  ck('la console della pagina e\' vuota', puliti.length, 0)
  if (puliti.length) console.log('   console:', puliti.slice(0, 3).join(' // '))

  const pass = risultati.filter(r => r.ok).length, fail = risultati.length - pass
  console.log('\n  ' + pass + ' passati, ' + fail + ' falliti, ' + puliti.length + ' errori in console')
  await send('Browser.close').catch(() => {})
  chrome.kill('SIGKILL')
  process.exit(fail ? 1 : 0)
})().catch(e => {
  console.error('  ERRORE FATALE:', e.message)
  console.log('  0 passati, 1 falliti (prerequisiti)')
  process.exit(1)
})
