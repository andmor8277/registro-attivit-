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
const CAT_ESORDIENTI = '26'

const BASE = process.env.THOF_UI_BASE || 'http://192.168.178.133:3000'
const USER = process.argv[2]
const PASS = process.argv[3]
// L'id dell'utente 'mister' SENZA categoria, creato da prepara_demo_tornei.sh: serve per il caso del
// referente che il menu non conosce piu'
const MISTER_FUORI = process.argv[4] || ''
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
  // Il profilo si ripulisce a ogni esecuzione: Chrome ricorda in quello lo stato di Safe Browsing e
  // delle protezioni sui download, e riusandolo lo stesso identico export e' passato dall'essere
  // scaricato all'essere bloccato senza nessun errore in pagina ("The file at 'blob:...' was loaded
  // over an insecure connection"). Una cartella pulita rende il run deterministico
  fs.rmSync(`${OUT}/profile`, { recursive: true, force: true })
  const chrome = spawn('/usr/bin/google-chrome-stable', [
    '--headless=new', `--remote-debugging-port=${PORT}`, '--no-sandbox', '--disable-gpu',
    '--disable-dev-shm-usage', '--hide-scrollbars', `--user-data-dir=${OUT}/profile`,
    '--window-size=1180,1500',
    // DEV serve l'app in HTTP: senza queste, Chrome blocca il download del blob generato
    // dall'export e non scrive nessun errore in console ("The file at 'blob:...' was loaded over an
    // insecure connection"). Sono flags del browser di prova, non dell'app: la stessa pagina in
    // produzione serve tutto in HTTPS. Il terzo e' quello che conta, perche' dichiara sicura
    // QUELL'origine; gli altri tolgono gli avvisi residui
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
    // Come fa Login.vue: la societa' si carica dopo e finisce in societa_data, da cui lo store la
    // rilegge all'avvio. Senza questo la pagina non sa come si chiama la societa', e il documento
    // "tutti i tornei" perderebbe il pezzo di nome file che serve a capire di chi e'
    if (me.societa_id) {
      try {
        const s = await (await fetch('/api/societa/' + me.societa_id, {headers:{Authorization:'Bearer '+access_token}})).json()
        localStorage.setItem('societa_data', JSON.stringify(s))
      } catch (e) {}
    }
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

  console.log('--- esportazione PDF: i QUATTRO pulsanti, e cosa c\'E\' dentro i file ---')
  // L'export non lo verifica nessun test API: qui si scarica davvero il PDF e se ne legge il testo.
  // Un pulsante che sembra funzionare e sforna un documento vuoto e' il modo peggiore per scoprirlo
  // la sera prima del torneo, quando il file va consegnato all'organizzatore
  const DL = `${OUT}/download`
  // Come si chiama davvero il file del singolo torneo: il prefisso __demo_tornei__ lascia tre
  // underscorelli (due letterali + quello della virgoletta), e riscriverlo a mano quattro volte e
  // il modo piu veloce per sbagliarlo
  // Il nome del documento "tutti i tornei" porta la societa', quindi va costruito come lo costruisce
  // la pagina: riscriverlo a mano qui vuol dire un rosso per il nome del file e non per il contenuto
  const nomeSocieta = await evalJS(`(() => { try { return JSON.parse(localStorage.getItem('societa_data') || '{}').nome || '' } catch (e) { return '' } })()`)
  const pulito = s => String(s || '').replace(/[^\w]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase()
  const PDF_SOCIETA = nomeSocieta ? `tornei_societa_${pulito(nomeSocieta)}.pdf` : 'tornei_societa.pdf'
  // Tutti e quattro i documenti si chiamano ..._<societa>.pdf: due societa' che si scambiano i
  // calendari in chat non devono ritrovarsi due file con lo stesso nome
  const SUFFISSO = nomeSocieta ? '_' + pulito(nomeSocieta) : ''
  const PDF_TORNEO = `tornei_demo_tornei___winter_cup_2016_pulcini${SUFFISSO}.pdf`
  const PDF_ESORDIENTI = `tornei_2015_esordienti${SUFFISSO}.pdf`
  console.log('   societa letta dal profilo:', JSON.stringify(nomeSocieta), '->', PDF_SOCIETA)
  // Se la pagina non sapesse come si chiama la societa', il file sarebbe "tornei_societa.pdf" per
  // tutti: due societa' che si scambiano i PDF in chat non saprebbero di chi e' quale
  ck('la pagina conosce il nome della societa', String(nomeSocieta || '').length > 0, true)
  const { execFileSync } = require('child_process')
  const occorrenze = (testo, ago) => (testo.match(new RegExp(ago, 'g')) || []).length
  // Le frasi del PDF vanno cercate su un testo senza a capo: "Gare senza categoria" scritto in una
  // cella da 30 mm arriva come "Gare senza / categoria", e il documento era giusto. Appiattire
  // rende le asserzioni sull'impaginazione meno fragili; sui controlli GDPR puo' solo aggiungere
  // un falso rosso, mai un falso verde, che e' la direzione giusta
  const piatto = t => String(t == null ? '' : t).replace(/\s+/g, ' ')
  // Senza questo Chrome non scrive da nessuna parte il blob dell'export, e non dice niente: la
  // prima volta che e' successo sembrava un export rotto, ed era solo il browser di prova senza
  // una cartella di destinazione. Su alcune versioni il percorso vale solo a livello di browser,
  // quindi viene messo su entrambe le sessioni
  await send('Page.setDownloadBehavior', { behavior: 'allow', downloadPath: DL })
  await send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: DL }).catch(() => {})

  // Ogni export riparte da una cartella vuota: Chrome non sovrascrive lo stesso nome, scrive
  // "nome (1).pdf", e la seconda esportazione dello stesso documento avrebbe rotto l'asserzione sul
  // nome del file per il motivo sbagliato. Si svuota la cartella, NON si cancella: il percorso e'
  // quello dato a Chrome con setDownloadBehavior, e rifare la directory con un inode nuovo e'
  // bastato a far finire nel vuoto tutti e tre i download
  async function scarica(nome, espressioneElemento) {
    fs.mkdirSync(DL, { recursive: true })
    for (const f of fs.readdirSync(DL)) fs.rmSync(`${DL}/${f}`, { recursive: true, force: true })
    await clickReale(espressioneElemento)
    const atteso = `${DL}/${nome}`
    for (let i = 0; i < 60; i++) {
      if (fs.existsSync(atteso) && fs.statSync(atteso).size > 500) {
        await sleep(400)   // il file puo' ancora essere in scrittura
        const testo = execFileSync('pdftotext', ['-layout', atteso, '-'], { encoding: 'utf8' })
        // DUMP_PDF=1 lascia il testo estratto accanto al PDF: quando un'asserzione sul contenuto e'
        // rossa, la domanda e' quasi sempre "il documento non c'e' l'ha o lo cerca male il test", e
        // senza il testo estratto la risposta e' un'altra esecuzione
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

  // Agganci stabili: la sezione per titolo, la card per nome, i pulsanti per testo
  const SEZ_ESOR = `[...document.querySelectorAll('.categoria-sezione')].find(x=>/Esordienti/.test(x.querySelector('.categoria-intestazione').innerText))`
  const SEZ_PULC = `[...document.querySelectorAll('.categoria-sezione')].find(x=>/Pulcini/.test(x.querySelector('.categoria-intestazione').innerText))`
  // La card si prende DENTRO la sezione dei Pulcini: il torneo e' uno solo e sta in entrambe, ma il
  // pulsante di export della prima card della pagina esporterebbe la sezione degli Esordienti
  const CARD = `${SEZ_PULC}.querySelector('.torneo-card')`
  const btnSezione = `${SEZ_ESOR}.querySelector('.btn-esporta')`
  const btnTutti = `document.querySelector('.page-header .btn-esporta')`
  const btnCard = `${CARD}.querySelector('.btn-esporta')`

  // ---------------------------------------------------------------- 1) nessun mister assegnato
  const cardSenzaMister = await evalJS(`(() => {
    const c = ${CARD}
    const m = c && c.querySelector('.mister-torneo')
    return m ? { testo: m.innerText.replace(/\\s+/g,' ').trim(), assente: m.classList.contains('assente') } : null
  })()`)
  ck('la card dice che il torneo non ha un referente', cardSenzaMister && cardSenzaMister.testo, 'mister da assegnare')
  ck('e lo dice come un buco (ambra), non come un dato normale', cardSenzaMister && cardSenzaMister.assente, true)

  const pdfSezione = await scarica(PDF_ESORDIENTI, btnSezione)
  ck('il PDF della singola categoria si scarica', pdfSezione !== null, true)
  if (pdfSezione) {
    ck('contiene la sua categoria', /2015 - Esordienti/.test(pdfSezione), true)
    ck('il titolo finisce con il nome della societa\', come quello del weekend',
       (pdfSezione.split('\n').find(l => l.trim()) || '').includes(' - RedTigers 1957'), true)
    ck('e il sottotitolo dice quando e\' stato generato, come quello del weekend',
       /Generato il \d{1,2}\/\d{1,2}\/\d{4}/.test(pdfSezione), true)
    ck('le colonne sono quelle del calendario, Mister compreso',
       ['Data', 'Ora', 'Avversario', 'Appuntamento', 'Campo', 'Indirizzo', 'Mister', 'Note']
         .every(c => new RegExp('\\b' + c + '\\b').test(piatto(pdfSezione))), true)
    ck('contiene la SUA gara', /Vecchia Guardia/.test(pdfSezione), true)
    // Il punto delicato dell'export per categoria: se trapelassero le gare dell'altra categoria, il
    // documento consegnato all'organizzatore sarebbe plausibile e falso
    ck('NON contiene le gare dei Pulcini', /Real Junior|Atletico Sud/.test(pdfSezione), false)
    ck('dichiara il foglio assente, non lo tace', /Foglio giocatori assente/.test(pdfSezione), true)
    ck('nomina le orfane invece di dimenticarle',
       /Gare senza categoria \(1\)/.test(piatto(pdfSezione)) && /assegnare a una categoria/.test(piatto(pdfSezione)), true)
    ck('e stampa la gara orfana', /Amichevole fuori calendario/.test(pdfSezione), true)
    ck('dichiara il mister mancante nella sua colonna, invece di omettere la riga', /non assegnato/.test(piatto(pdfSezione)), true)
    ck('non stampa colonne GDPR (data di nascita, CF, telefoni)',
       /Data Nascita|Codice fiscale|Telefono/i.test(pdfSezione), false)
    // Qui il foglio NON c'e' (e' stato distaccato di proposito): una tabella del roster vuota sarebbe
    // peggio della frase che dichiara l'assenza
    ck('e non stampa una tabella giocatori vuota', /Cognome/.test(pdfSezione), false)
  }

  const pdfTutti = await scarica(PDF_SOCIETA, btnTutti)
  ck('il PDF di tutti i tornei della societa si scarica', pdfTutti !== null, true)
  if (pdfTutti) {
    ck('il titolo del documento dice che e\' di tutta la societa',
       /tutti i tornei/i.test(pdfTutti), true)
    ck('dice quanti tornei contiene, cosi\' chi lo riceve puo\' accorgersi se ne mancano',
       /1 torneo di tutta la societa/.test(pdfTutti), true)
    ck('contiene entrambe le sezioni', /2015 - Esordienti/.test(pdfTutti) && /2016 - Pulcini/.test(pdfTutti), true)
    ck('contiene le gare di entrambe',
       /Vecchia Guardia/.test(pdfTutti) && /Real Junior/.test(pdfTutti) && /Atletico Sud/.test(pdfTutti), true)
    ck('contiene i giocatori veri del foglio dei Pulcini',
       attese.cognomi.length > 0 && attese.cognomi.every(c => pdfTutti.includes(c)), true)
    ck('il foglio ha le sue colonne, e niente di piu\'', /Cognome/.test(pdfTutti) && /Nome/.test(pdfTutti), true)
    ck('nomina il foglio con il suo nome completo', piatto(pdfTutti).includes(attese.nomeFoglio || '###'), true)
    // Le orfane sono dello stesso torneo: in "tutte le categorie" vanno stampate una volta sola
    ck('la gara orfana compare UNA volta sola, non una per sezione', occorrenze(pdfTutti, 'Amichevole fuori calendario'), 1)
    ck('anche l\'intestazione orfane compare una volta sola', occorrenze(piatto(pdfTutti), 'Gare senza categoria'), 1)
    // Il referente sta nell'intestazione del torneo, e in "tutte le categorie" il torneo viene
    // ripetuto una volta per sezione (come il suo nome, le sue date e il suo luogo): una sezione e'
    // una lettura a se'. Le GARE senza categoria invece si stampano una volta sola, perche' li' la
    // ripetizione sarebbe dato duplicato, non contesto
    ck('il mister e\' dichiarato su ogni riga di gara (3 gare: 1 Esordienti + 2 Pulcini)',
       occorrenze(piatto(pdfTutti), 'non assegnato'), 3)
    ck('non stampa colonne GDPR', /Data Nascita|Codice fiscale|Telefono/i.test(pdfTutti), false)
  }
  ck('i pulsanti non sono rimasti disabilitati dopo l\'export',
     await evalJS(`[...document.querySelectorAll('.btn-esporta')].every(b => !b.disabled)`), true)

  console.log('--- il terzo livello: QUESTO torneo, in QUESTA categoria ---')
  // Perche' esiste: il responsabile che deve mandare il suo all'organizzatore non vuole il resto
  // della giornata. Un PDF con dentro anche l'altra categoria e' un documento da tagliare a mano
  const pdfCard = await scarica(PDF_TORNEO, btnCard)
  ck('il PDF del singolo torneo si scarica', pdfCard !== null, true)
  if (pdfCard) {
    ck('il file si chiama anche con il torneo, non solo con la categoria',
       fs.readdirSync(DL).join(','), PDF_TORNEO)
    ck('ha il torneo nel titolo, oltre alla categoria',
       pdfCard.includes(NOME_DEMO) && /2016 - Pulcini/.test(pdfCard), true)
    ck('ha le sue due gare dei Pulcini', /Real Junior/.test(pdfCard) && /Atletico Sud/.test(pdfCard), true)
    ck('NON ha la gara dell\'altra categoria dello stesso torneo', /Vecchia Guardia/.test(pdfCard), false)
    ck('NON ha nemmeno l\'intestazione dell\'altra categoria', /2015 - Esordienti/.test(pdfCard), false)
    ck('ha il foglio giocatori di quella categoria', attese.cognomi.every(c => pdfCard.includes(c)), true)
    ck('e l\'appuntamento, che e\' la colonna che si spezzava', /08:45/.test(pdfCard), true)
  }

  // I responsabili della categoria, letti dalla STESSA API che usa la pagina. Confrontare il menu
  // con l'attesa scritta a mano (Papaveri dentro, Quadri fuori) vede i due nomi che ci si aspetta ma
  // non vede il terzo arrivato: qui si confronta l'insieme degli id, cosi' un mister censito dopo
  // nella categoria sbagliata, o una categoria in piu' nel menu, diventano rossi da soli
  const responsabiliDi = async catId => await evalJS(`(async () => {
    const tk = localStorage.getItem('token')
    const r = await (await fetch('/api/categorie/${catId}/responsabili', {headers:{Authorization:'Bearer '+tk}})).json()
    return (r || []).filter(x => x.ruolo !== 'dirigente').map(x => String(x.id)).sort()
  })()`, { awaitPromise: true })

  console.log('--- il Mister: il menu, il salvataggio, e il PDF che lo stampa ---')
  // Il menu a tendina non si inventa le persone: prende i responsabili DELLE categorie iscritte al
  // torneo, come fa il weekend. Qui si prova l'unione (Papaveri e' dei Pulcini, Quadri degli
  // Esordienti) e l'esclusione del dirigente, che nel menu non c'entra
  const apriModifica = `[...${CARD}.querySelectorAll('.btn-azione')]` +
    `.find(b => b.innerText.trim() === 'Modifica')`
  await clickReale(apriModifica)
  await sleep(700)
  const menuMister = await evalJS(`(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))
    if (!m) return {nessuno: true}
    const sel = [...m.querySelectorAll('select')].find(s => [...s.options].some(o => o.value === '__manuale__'))
    if (!sel) return {nienteSelect: true}
    return {
      opzioni: [...sel.options].map(o => o.text.replace(/\\s+/g, ' ').trim()),
      valore: sel.value,
      etichetta: (sel.closest('.form-group')?.querySelector('label')?.innerText || '').trim(),
      valori: [...sel.options].map(o => o.value),
      titolo: (m.querySelector('h3')?.innerText || '').replace(/\\s+/g, ' ').trim(),
      suggerimento: (sel.closest('.form-group')?.querySelector('.suggerimento')?.innerText || '').replace(/\\s+/g, ' ').trim()
    }
  })()`)
  console.log('   menu:', JSON.stringify(menuMister))
  ck('il modal di modifica ha la voce Mister', menuMister.etichetta, 'Mister del torneo')
  ck('il menu offre il mister dei Pulcini', (menuMister.opzioni || []).some(o => /Papaveri/.test(o)), true)
  // Quadri e' dei 2015 - Esordienti e il torneo e' iscritto a entrambe le categorie: qui NON deve
  // esserci, perche' la lista arriva dalla sezione in cui stai lavorando e non dall'unione. E' la
  // richiesta del titolare: un torneo dei 2016 lo segue uno dei 2016
  ck('e NON offre il mister dell\'altra categoria iscritta (la lista e\' della sezione)',
     (menuMister.opzioni || []).some(o => /Quadri/.test(o)), false)
  ck('il modal dice in quale sezione stai lavorando', menuMister.titolo, 'Modifica torneo — 2016 - Pulcini')
  const respPulcini = await responsabiliDi(CAT_PULCINI)
  console.log('   responsabili API dei Pulcini:', JSON.stringify(respPulcini))
  ck('il menu offre ESATTAMENTE i responsabili dei Pulcini: né uno in piu ne uno in meno',
     (menuMister.valori || []).filter(v => v && v !== '__manuale__').sort().join(','), respPulcini.join(','))
  ck('e il suggerimento nomina la categoria da cui arrivano le persone',
     /2016 - Pulcini/.test(menuMister.suggerimento || ''), true)
  ck('il dirigente NON e\' un candidato a mister del torneo',
     (menuMister.opzioni || []).some(o => /Dirigenti/.test(o)), false)
  ck('parte vuoto, perche\' il torneo non ce l\'ha', menuMister.valore, '')

  // Selezionare dal menu e salvare: la pagina deve ricaricarsi con il nome sulla card
  await evalJS(`(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))
    const sel = [...m.querySelectorAll('select')].find(s => [...s.options].some(o => o.value === '__manuale__'))
    const o = [...sel.options].find(o => /Papaveri/.test(o.text))
    sel.value = o.value
    sel.dispatchEvent(new Event('change', { bubbles: true }))
    return sel.value
  })()`)
  await clickReale(`[...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))` +
                   `.querySelectorAll('.modal-footer .btn-primary')[0]`)
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (!document.querySelector('.modal') || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
  const cardConMister = await evalJS(`(() => {
    const m = ${CARD}.querySelector('.mister-torneo')
    return m ? { testo: m.innerText.replace(/\\s+/g,' ').trim(), assente: m.classList.contains('assente') } : null
  })()`)
  ck('dopo il salvataggio la card dice CHI e\' il mister', cardConMister && cardConMister.testo,
     'Gino Papaveri 3330000111')
  ck('e non e\' piu\' un buco', cardConMister && cardConMister.assente, false)
  await shot('04_mister_sulla_card')

  const pdfConMister = await scarica(PDF_TORNEO, btnCard)
  ck('il PDF del singolo torneo stampa il mister con il recapito',
     pdfConMister !== null && /Mister: Gino Papaveri \(3330000111\)/.test(pdfConMister), true)
  ck('e non dice piu\' "non assegnato"', /Mister: non assegnato/.test(pdfConMister || ''), false)

  console.log('--- il mister scritto a mano (l\'accompagnatore non censito) ---')
  await clickReale(apriModifica)
  await sleep(700)
  // Il menu deve riaprirsi gia\' con la persona giusta: se il modal ripartisse vuoto, il primo
  // "Salva" distruggerebbe il mister scelto prima
  ck('il modal si riapre con il mister gia\' selezionato', await evalJS(`(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))
    const sel = [...m.querySelectorAll('select')].find(s => [...s.options].some(o => o.value === '__manuale__'))
    const o = sel.options[sel.selectedIndex]
    return o ? o.text.replace(/\\s+/g, ' ').trim() : null
  })()`), 'Papaveri Gino (3330000111)')

  await evalJS(`(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))
    const sel = [...m.querySelectorAll('select')].find(s => [...s.options].some(o => o.value === '__manuale__'))
    const o = [...sel.options].find(o => o.value === '__manuale__')
    sel.value = o.value
    sel.dispatchEvent(new Event('change', { bubbles: true }))
    return 'ok'
  })()`)
  await sleep(300)
  // "manuale" senza nome NON e' un torneo senza mister: e' un nome perso per strada. La pagina deve
  // rifiutarsi di salvare, perche' il PDF uscirebbe senza referente mentre lo schermo mostrava la
  // voce selezionata
  await clickReale(`[...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))` +
                   `.querySelectorAll('.modal-footer .btn-primary')[0]`)
  await sleep(700)
  ck('"manuale" senza nome non salva, e lo dice', await evalJS(`(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))
    return m ? (m.querySelector('.messaggio.errore')?.innerText.trim() || 'NESSUN ERRORE A SCHERMO') : 'MODAL CHIUSO'
  })()`), 'Scrivi il nome del mister, o scegli una persona dal menu')
  ck('e il torneo tiene il suo mister (il tentativo non ha scritto niente)',
     await evalJS(`${CARD}.querySelector('.mister-torneo').innerText.replace(/\\s+/g,' ').trim()`),
     'Gino Papaveri 3330000111')

  await evalJS(`(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))
    const i = m.querySelector('.mister-manuale input')
    i.value = 'Gianni Testa'
    i.dispatchEvent(new Event('input', { bubbles: true }))
    return 'ok'
  })()`)
  await clickReale(`[...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))` +
                   `.querySelectorAll('.modal-footer .btn-primary')[0]`)
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (!document.querySelector('.modal') || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
  ck('il nome scritto a mano compare sulla card',
     await evalJS(`${CARD}.querySelector('.mister-torneo').innerText.replace(/\\s+/g,' ').trim()`), 'Gianni Testa')
  const pdfMisterManuale = await scarica(PDF_TORNEO, btnCard)
  ck('e compare nel PDF, cosi\' com\'e\' scritto',
     pdfMisterManuale !== null && /Mister: Gianni Testa/.test(pdfMisterManuale), true)
  ck('senza recapito inventati', /Gianni Testa \(333/.test(pdfMisterManuale || ''), false)

  console.log('--- il referente che il menu non conosce piu\' (fuori lista) ---')
  // Il caso reale: il mister assegnato cambia categoria, o il responsabile scioglie un'iscrizione.
  // Il backend NON chiede che il referente sia delle categorie iscritte (valida solo societa' e
  // ruolo), quindi questa condizione si crea da sola e la pagina deve reggerla: se il menu la
  // dipingesse vuota, chi apre il modal per correggere il luogo vedrebbe "da assegnare" e con il
  // prossimo Salva perderebbe il mister senza averlo mai visto
  if (!MISTER_FUORI) {
    console.log('  ATTENZIONE: nessun mister senza categoria nei dati di prova: le asserzioni sotto non misurano niente')
  }
  const idTorneo = await evalJS(`(async () => {
    const tk = localStorage.getItem('token')
    const ts = await (await fetch('/api/tornei/', {headers:{Authorization:'Bearer '+tk}})).json()
    const t = ts.find(x => (x.nome || '').indexOf(${JSON.stringify(NOME_DEMO)}) === 0)
    return t ? t.id : null })()`, { awaitPromise: true })
  const messoFuori = await evalJS(`(async () => {
    const tk = localStorage.getItem('token')
    const d = await (await fetch('/api/tornei/${idTorneo}', {headers:{Authorization:'Bearer '+tk}})).json()
    const corpo = { nome: d.nome, data_inizio: d.data_inizio, data_fine: d.data_fine, luogo: d.luogo,
                    organizzatore: d.organizzatore, descrizione: d.descrizione,
                    mister_id: ${Number(MISTER_FUORI) || 0}, mister_manuale: null }
    const r = await fetch('/api/tornei/${idTorneo}', {method:'PUT',
      headers:{'Content-Type':'application/json', Authorization:'Bearer '+tk}, body: JSON.stringify(corpo)})
    return r.status })()`, { awaitPromise: true })
  ck('il backend accetta un referente che non e\' delle categorie iscritte (valida solo societa\' e ruolo)',
     messoFuori, 200)
  await goto(`${BASE}/responsabili/tornei`)
  const cardFuori = await evalJS(`${CARD}.querySelector('.mister-torneo').innerText.replace(/\\s+/g,' ').trim()`)
  ck('la card lo dice lo stesso, con il nome e non con l\'id', cardFuori, 'Ivo Fuorilista')
  await clickReale(apriModifica)
  await sleep(900)
  const menuFuori = await evalJS(`(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))
    const sel = [...m.querySelectorAll('select')].find(s => [...s.options].some(o => o.value === '__manuale__'))
    const o = sel.options[sel.selectedIndex]
    return { valore: sel.value, testo: o ? o.text.replace(/\\s+/g, ' ').trim() : null }
  })()`)
  console.log('   menu:', JSON.stringify(menuFuori))
  ck('il menu NON e\' vuoto su un torneo che il mister ce l\'ha', menuFuori.valore, String(MISTER_FUORI))
  ck('lo nomina come persona, non come numero', /Ivo Fuorilista/.test(menuFuori.testo || ''), true)
  ck('e spiega perche\' non e\' fra le persone delle categorie',
     /tra i responsabili di 2016 - Pulcini/.test(menuFuori.testo || ''), true)
  // Il punto che questa opzione esiste per evitare: salvare senza toccare niente
  await clickReale(`[...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))` +
                   `.querySelectorAll('.modal-footer .btn-primary')[0]`)
  await evalJS(`new Promise(res => { let n=0; const t=setInterval(() => {
    if (!document.querySelector('.modal') || ++n > 40) { clearInterval(t); res(true) } }, 150) })`,
    { awaitPromise: true })
  ck('salvare senza toccare niente NON se lo porta via',
     await evalJS(`${CARD}.querySelector('.mister-torneo').innerText.replace(/\\s+/g,' ').trim()`), 'Ivo Fuorilista')

  console.log('--- la lista la decide la sezione: apro lo stesso torneo dagli Esordienti ---')
  // Senza questa, "la lista viene dalla sezione" resta verde anche con un menu fisso sui Pulcini: e'
  // l'asserzione che distingue "filtrato per la sezione" da "filtrato per caso"
  await clickReale(`[...${SEZ_ESOR}.querySelectorAll('.btn-azione')].find(b => b.innerText.trim() === 'Modifica')`)
  await sleep(900)
  const menuEsordienti = await evalJS(`(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))
    if (!m) return {nessuno: true}
    const sel = [...m.querySelectorAll('select')].find(s => [...s.options].some(o => o.value === '__manuale__'))
    return {
      titolo: (m.querySelector('h3')?.innerText || '').replace(/\\s+/g, ' ').trim(),
      opzioni: sel ? [...sel.options].map(o => o.text.replace(/\\s+/g, ' ').trim()) : [],
      valori: sel ? [...sel.options].map(o => o.value) : []
    }
  })()`)
  console.log('   menu (Esordienti):', JSON.stringify(menuEsordienti))
  ck('il modal si apre nominando gli Esordienti', menuEsordienti.titolo, 'Modifica torneo — 2015 - Esordienti')
  ck('e offre il mister degli Esordienti', (menuEsordienti.opzioni || []).some(o => /Quadri/.test(o)), true)
  ck('ma NON quello dei Pulcini, che pure e\' iscritto allo stesso torneo',
     (menuEsordienti.opzioni || []).some(o => /Papaveri/.test(o)), false)
  const respEsordienti = await responsabiliDi(CAT_ESORDIENTI)
  console.log('   responsabili API degli Esordienti:', JSON.stringify(respEsordienti))
  ck('il menu degli Esordienti offre ESATTAMENTE i loro responsabili (fuori il referente fuori lista)',
     (menuEsordienti.valori || []).filter(v => v && v !== '__manuale__' && v !== String(MISTER_FUORI))
       .sort().join(','), respEsordienti.join(','))
  await clickReale(`[...document.querySelectorAll('.modal')].find(x => /Modifica torneo/.test(x.innerText))` +
                   `.querySelector('.modal-footer .btn-secondary')`)
  await sleep(600)
  ck('Annulla chiude il modal senza salvare niente',
     await evalJS(`!!document.querySelector('.modal')`), false)

  console.log('--- il menu del Mister nel "Nuovo torneo": segue le categorie che spunti ---')
  // La richiesta del titolare: "quando aggiungi un torneo per la categoria 2016 i mister che devono
  // comparire nel menu devono essere quelli dei 2016". Qui si misura con gli id letti dall'API, non
  // con i nomi che ci si aspetta: e' l'unico modo di accorgersi di una categoria in piu' nel menu
  const MENU_CREA = `(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Nuovo torneo/.test(x.innerText))
    if (!m) return {nessuno: true}
    const sel = [...m.querySelectorAll('select')].find(s => [...s.options].some(o => o.value === '__manuale__'))
    return {
      scelte: [...m.querySelectorAll('.scelta-categoria')].filter(l => l.querySelector('input').checked)
              .map(l => l.innerText.replace(/\\s+/g,' ').trim()),
      suggerimento: (sel?.closest('.form-group')?.querySelector('.suggerimento')?.innerText || '').replace(/\\s+/g,' ').trim(),
      valori: sel ? [...sel.options].map(o => o.value).filter(v => v && v !== '__manuale__') : []
    }
  })()`
  const spuntaCat = (catId, on) => `(() => {
    const m = [...document.querySelectorAll('.modal')].find(x => /Nuovo torneo/.test(x.innerText))
    const l = [...m.querySelectorAll('.scelta-categoria')].find(x => x.querySelector('input').value === ${JSON.stringify(String(catId))})
    if (!l) return 'NON TROVATA'
    const i = l.querySelector('input'); i.checked = ${on ? 'true' : 'false'}
    i.dispatchEvent(new Event('change', { bubbles: true }))
    return i.checked
  })()`
  const soloId = v => (v || []).filter(x => /^\d+$/.test(String(x))).map(String).sort()
  const union = (...liste) => [...new Set([].concat(...liste))].sort()

  await clickReale(`document.querySelector('.page-header .btn-primary')`)
  await sleep(900)
  const creaVuoto = await evalJS(MENU_CREA)
  console.log('   nuovo torneo, nessuna categoria:', JSON.stringify(creaVuoto))
  ck('senza categorie spuntate il menu non offre persone, e il perche\' lo dice',
     creaVuoto.suggerimento, 'Spunta una categoria: il menu offre i mister di quella categoria.')
  ck('e le uniche due voci restano "da assegnare" e "manuale"', soloId(creaVuoto.valori).length, 0)

  console.log('   spunto 2016 - Pulcini:', await evalJS(spuntaCat(CAT_PULCINI, true)))
  await sleep(1300)
  const crea2016 = await evalJS(MENU_CREA)
  ck('spuntati i Pulcini, il suggerimento nomina loro',
     /2016 - Pulcini/.test(crea2016.suggerimento || '') && !/2015/.test(crea2016.suggerimento || ''), true)
  ck('e il menu offre ESATTAMENTE i responsabili dei 2016',
     soloId(crea2016.valori).join(','), respPulcini.join(','))

  console.log('   spunto anche 2015 - Esordienti:', await evalJS(spuntaCat(CAT_ESORDIENTI, true)))
  await sleep(1300)
  const creaDue = await evalJS(MENU_CREA)
  ck('con due categorie spuntate il suggerimento le nomina entrambe',
     /2016 - Pulcini/.test(creaDue.suggerimento || '') && /2015 - Esordienti/.test(creaDue.suggerimento || ''), true)
  ck('e il menu e\' l\'unione dei responsabili delle due, senza duplicati',
     soloId(creaDue.valori).join(','), union(respPulcini, respEsordienti).join(','))

  console.log('   tolgo 2015 - Esordienti:', await evalJS(spuntaCat(CAT_ESORDIENTI, false)))
  await sleep(1300)
  const creaDiNuovo = await evalJS(MENU_CREA)
  ck('deselezionandola il menu torna solo i 2016 (segue le spunte, non e\' un colpo unico)',
     soloId(creaDiNuovo.valori).join(','), respPulcini.join(','))

  await clickReale(`[...document.querySelectorAll('.modal')].find(x => /Nuovo torneo/.test(x.innerText))` +
                   `.querySelector('.modal-footer .btn-secondary')`)
  await sleep(600)
  ck('Annulla chiude anche questo modal', await evalJS(`!!document.querySelector('.modal')`), false)

  console.log('--- il filtro categoria: lo schermo si restringe, il documento della societa\' no ---')
  // Il filtro in alto filtra i TORNEI (EXISTS su tornei_categorie), ma il backend restituisce ogni
  // torneo con TUTTE le sue categorie: se la pagina le dipinge tutte, scegliendo "2016 - Pulcini"
  // resta visibile anche la sezione degli Esordienti e il filtro sembra rotto. E soprattutto l'export
  // "selezione" dichiarerebbe di essere un sottoinsieme senza esserlo
  await evalJS(`(() => { const s = document.querySelector('.select-filtro')
    s.value = ${JSON.stringify(CAT_PULCINI)}
    s.dispatchEvent(new Event('change', { bubbles: true }))
    return s.value })()`)
  await sleep(1800)
  const titoliFiltrati = await evalJS(`[...document.querySelectorAll('.categoria-intestazione')].map(x => x.innerText.replace(/\\s+/g,' ').trim())`)
  console.log('   sezioni col filtro:', JSON.stringify(titoliFiltrati))
  ck('col filtro su Pulcini la sezione degli Esordienti NON compare piu\'', titoliFiltrati.length, 1)
  ck('e resta quella chiesta', /^2016 - Pulcini/.test(titoliFiltrati[0] || ''), true)

  const btnSelezione = `document.querySelectorAll('.page-header .btn-esporta')[1]`
  ck('con un filtro attivo compare il secondo pulsante di export', await evalJS(`!!(${btnSelezione})`), true)
  ck('e si chiama "Esporta la selezione", non un altro "Esporta PDF"',
     await evalJS(`${btnSelezione} ? ${btnSelezione}.innerText.trim() : null`), 'Esporta la selezione')

  const pdfSelezione = await scarica('tornei_selezione.pdf', btnSelezione)
  ck('il PDF della selezione si scarica', pdfSelezione !== null, true)
  if (pdfSelezione) {
    ck('dichiara da solo di essere un sottoinsieme',
       /ATTENZIONE: solo la selezione a schermo/.test(pdfSelezione), true)
    ck('e dice quale filtro lo ha prodotto', /categoria 2016 - Pulcini/.test(pdfSelezione), true)
    ck('ha la categoria chiesta', /2016 - Pulcini/.test(pdfSelezione), true)
    ck('NON ha l\'altra categoria, che a schermo non c\'e\'', /2015 - Esordienti/.test(pdfSelezione), false)
    ck('e ha i suoi giocatori', attese.cognomi.length > 0 && attese.cognomi.every(c => pdfSelezione.includes(c)), true)
  }

  // Il punto della richiesta: con lo schermo filtrato, "tutti i tornei" deve restare completo. E'
  // l'asserzione che distingue il documento della societa' da una copia di quello che ho in faccia
  const pdfSocietaFiltrato = await scarica(PDF_SOCIETA, btnTutti)
  ck('con il filtro attivo, "Esporta tutti i tornei" si scarica lo stesso', pdfSocietaFiltrato !== null, true)
  if (pdfSocietaFiltrato) {
    ck('e dentro ci sta ANCHE la categoria che a schermo e\' nascosta',
       /2015 - Esordienti/.test(pdfSocietaFiltrato) && /Vecchia Guardia/.test(pdfSocietaFiltrato), true)
    ck('ci sta anche il foglio assente degli Esordienti', /Foglio giocatori assente/.test(pdfSocietaFiltrato), true)
    ck('e non si spaccia per una selezione', /solo la selezione a schermo/.test(pdfSocietaFiltrato), false)
  }

  // Anche i due pulsanti "piccoli", con un filtro attivo, producono un sottoinsieme: devono dirlo,
  // perche' il file parte in chat e chi lo riceve non ha visto lo schermo di chi l'ha generato
  const pdfCardFiltrata = await scarica(PDF_TORNEO, btnCard)
  ck('anche il PDF del singolo torneo, col filtro attivo, lo dichiara',
     pdfCardFiltrata !== null && /solo la selezione a schermo/.test(pdfCardFiltrata), true)

  await evalJS(`(() => { const s = document.querySelector('.select-filtro')
    s.value = ''
    s.dispatchEvent(new Event('change', { bubbles: true }))
    return s.value })()`)
  await sleep(1800)
  ck('tolto il filtro, le sezioni tornano due',
     await evalJS(`document.querySelectorAll('.categoria-intestazione').length`), 2)
  ck('e il secondo pulsante non ha piu\' niente da dichiarare, quindi sparisce',
     await evalJS(`!!document.querySelectorAll('.page-header .btn-esporta')[1]`), false)

  console.log('--- lo schermo VUOTO non deve fermare il documento della societa\' ---')
  // Questo e' il caso che distingue davvero le due implementazioni. Con un solo torneo demo, il filtro
  // per categoria non esclude nessun torneo (il backend filtra i tornei ma li restituisce con tutte le
  // loro categorie), quindi "riusare la lista a schermo" e "ricaricare tutto" producono lo stesso
  // documento: l'asserzione qui sopra era verde per il motivo sbagliato. Svuotando la pagina con un
  // filtro per date, invece, le due strade si separano: se il pulsante riusasse cio' che si vede non
  // ci sarebbe niente da stampare e non scaricherebbe nulla
  await evalJS(`(() => {
    const [da, a] = document.querySelectorAll('.filtro-data input')
    // v-model ascolta 'input', @change e' quello che chiama carica(): vanno entrambi, dare per
    // scontato il solo change lascia la lista vecchia a schermo e il test misura il nulla
    da.value = '2027-06-01'; da.dispatchEvent(new Event('input', { bubbles: true }))
    a.value = '2027-06-30'; a.dispatchEvent(new Event('input', { bubbles: true }))
    da.dispatchEvent(new Event('change', { bubbles: true }))
    a.dispatchEvent(new Event('change', { bubbles: true }))
    return 'ok' })()`)
  await sleep(1800)
  ck('col filtro su un periodo senza tornei la pagina non mostra nessuna card',
     await evalJS(`document.querySelectorAll('.torneo-card').length`), 0)
  ck('ma "Esporta tutti i tornei" resta attivo: non dipende da cosa si vede',
     await evalJS(`!document.querySelector('.page-header .btn-esporta').disabled`), true)
  const pdfSchermoVuoto = await scarica(PDF_SOCIETA, btnTutti)
  ck('e il documento completo esce lo stesso', pdfSchermoVuoto !== null, true)
  if (pdfSchermoVuoto) {
    ck('con entrambe le categorie', /2015 - Esordienti/.test(pdfSchermoVuoto) && /2016 - Pulcini/.test(pdfSchermoVuoto), true)
    ck('con le gare di entrambe, che a schermo non c\'erano piu\'',
       /Vecchia Guardia/.test(pdfSchermoVuoto) && /Real Junior/.test(pdfSchermoVuoto) && /Atletico Sud/.test(pdfSchermoVuoto), true)
    ck('con i giocatori del foglio', attese.cognomi.length > 0 && attese.cognomi.every(c => pdfSchermoVuoto.includes(c)), true)
    ck('e senza l\'avviso da sottoinsieme, perche\' sottoinsieme non e\'',
       /solo la selezione a schermo/.test(pdfSchermoVuoto), false)
  }
  await evalJS(`(() => {
    const [da, a] = document.querySelectorAll('.filtro-data input')
    da.value = ''; a.value = ''
    da.dispatchEvent(new Event('input', { bubbles: true })); a.dispatchEvent(new Event('input', { bubbles: true }))
    da.dispatchEvent(new Event('change', { bubbles: true })); a.dispatchEvent(new Event('change', { bubbles: true }))
    return 'ok' })()`)
  await sleep(1800)
  ck('tolto il filtro per date, le card tornano',
     await evalJS(`document.querySelectorAll('.torneo-card').length`), 2)

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
