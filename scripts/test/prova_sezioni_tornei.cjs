#!/usr/bin/env node
/**
 * prova_sezioni_tornei.cjs — le sezioni della pagina Tornei non sconfinano dalle categorie di chi guarda.
 *
 * Perche' esiste. Il 25/11/2026 il mister dei 2016 - Pulcini (utente 8 di PROD) segnala: «vedo i tornei
 * 2016 ma poi posso aprire il menu a tendina e vedere tutto il resto dei tornei, che secondo me non devo
 * vedere da mister dei 2016». Il backend rispondeva gia' giusto (**5 tornei su 10**, misurato eseguendo
 * `lista_tornei` nel container con il suo `Utente` reale). Il difetto era tutto nella pagina: i 5 tornei
 * legittimi sono iscritti a 6 categorie, e quando il filtro a tendina e' attivo i tornei non vengono piu'
 * piazzati nel ramo principale di `costruisciSezioni` ma cadono nel ramo `extra`, che prendeva `cats` cosi'
 * com'era e li duplicava **sotto tutte le categorie iscritte**. Misurato, prima della toppa:
 *
 *     menu su "2015 - Esordienti" (26), che lui NON segue -> 6 sezioni, 15 card,
 *     comprese "2018 - Primi Calci" e "2019 - Primi Calci", etichettate "(non operativa)"
 *     -- etichetta che per giunta e' falsa: quelle categorie sono operative, sono solo NON sue.
 *
 * Perche' un test node e non solo il browser. `ui_tornei.cjs` gira come **responsabile** (dove le sezioni
 * sono tutte legittime) e `test_tornei_scope.sh` e' tutto lato API, dove questo buco non esiste per
 * costruzione: li' il filtro lo passa a mano chi scrive il test. Le due cose che coprono la riga difettosa
 * erano quindi due cose che non la guardavano. Questo file esegue LA FUNZIONE VERA, estratta dal .vue, su
 * una sagoma di dati pari a quella misurata su PROD: un secondo, senza Chrome ne' DEV ne' login.
 *
 * L'estrazione e' per nome e non per numero di riga, e le ancore sono asserite: un refactoring che sposta
 * la funzione deve far fallire QUESTO test dicendo quale àncora e' sparita, non fargli valutare in silenzio
 * una funzione che non c'e' piu'.
 *
 * Uso:
 *   node scripts/test/prova_sezioni_tornei.cjs                 -> le asserzioni sul codice attuale
 *   node scripts/test/prova_sezioni_tornei.cjs --prova-arnese  -> le stesse sul codice GUASTO: deve essere rosso
 */
const fs = require('fs')
const path = require('path')

const VUE = path.join(__dirname, '..', '..', 'frontend', 'src', 'features', 'partite', 'Tornei.vue')
const UTILS = path.join(__dirname, '..', '..', 'frontend', 'src', 'core', 'utils', 'categorie.js')

let pass = 0, fail = 0
const ck = (nome, atteso, reale) => {
  if (atteso === reale) { pass++; console.log(`  ok   ${nome}`) }
  else { fail++; console.log(`  FAIL ${nome}\n         atteso: ${JSON.stringify(atteso)}\n         reale:  ${JSON.stringify(reale)}`) }
}
const ckVero = (nome, cond, perche) => {
  if (cond) { pass++; console.log(`  ok   ${nome}`) }
  else { fail++; console.log(`  FAIL ${nome}${perche ? ' -- ' + perche : ''}`) }
}

// ---------------------------------------------------------------- estrazione della funzione vera
function estraiFunzione(testo, nome, ancore) {
  const inizio = testo.indexOf(`function ${nome}(`)
  if (inizio < 0) { console.log(`  FAIL estrazione: \`function ${nome}(\` non c'e' piu' in ${path.basename(VUE)}`); fail++; return null }
  const fine = testo.indexOf('\n}', inizio)
  if (fine < 0) { console.log(`  FAIL estrazione: \`function ${nome}(\` non si chiude a colonna 0`); fail++; return null }
  const corpo = testo.slice(inizio, fine + 2)
  for (const a of (ancore || [])) {
    if (!corpo.includes(a)) { console.log(`  FAIL estrazione: \`function ${nome}(\` non contiene piu' l'àncora \`${a}\``); fail++ }
  }
  return corpo
}

const sorgenteVue = fs.readFileSync(VUE, 'utf8')
const sorgenteUtils = fs.readFileSync(UTILS, 'utf8')

// ---------------------------------------------------------------- la sagoma dei dati (misurata su PROD il 25/11/2026)
// Stesse id, stessi anni e stesse iscrizioni dei 5 tornei che `lista_tornei` restituisce all'utente 8
// (mister della sola categoria 19). I nomi sono quelli veri perche' il punto e' la forma, non il contenuto.
const CATEGORIE = [
  { id: 17, nome: 'Scuola Calcio', anno: null, parent_id: null, is_portieri: 0 },  // gruppo
  { id: 18, nome: 'Agonistica', anno: null, parent_id: null, is_portieri: 0 },      // gruppo
  { id: 25, nome: 'Esordienti', anno: 2014, parent_id: 17, is_portieri: 0 },
  { id: 26, nome: 'Esordienti', anno: 2015, parent_id: 17, is_portieri: 0 },
  { id: 19, nome: 'Pulcini', anno: 2016, parent_id: 17, is_portieri: 0 },
  { id: 20, nome: 'Pulcini', anno: 2017, parent_id: 17, is_portieri: 0 },
  { id: 27, nome: 'Primi Calci', anno: 2018, parent_id: 17, is_portieri: 0 },
  { id: 28, nome: 'Primi Calci', anno: 2019, parent_id: 17, is_portieri: 0 },
  { id: 34, nome: 'UNDER 14 NEXT GEN', anno: 2013, parent_id: 18, is_portieri: 0 }
]
const TORNEI = [
  { id: 2, nome: 'WINTER CUP', categoria_id: 19, categorie: [25, 26, 19, 20] },
  { id: 3, nome: 'RADIO ROCK CHRISTMAS CUP', categoria_id: 26, categorie: [26, 19, 20, 27, 28] },
  { id: 4, nome: 'FM 10', categoria_id: 25, categorie: [25, 26, 19, 20, 27, 28] },
  { id: 5, nome: 'THE MAJOR LEAGUE', categoria_id: 19, categorie: [19] },
  { id: 6, nome: 'GIORGIO CASTELLI WINTER', categoria_id: 19, categorie: [19] }
]
// Un torneo iscritto solo a una categoria ARCHIVIATA (7 non e' in CATEGORIE: /categorie/all la esclude).
// E' il perche' il ramo `extra` esiste, e la toppa non deve cancellarlo.
const TORNEO_ARCHIVIATA = { id: 99, nome: 'TORNEO FANTASMA', categoria_id: 7, categorie: [7] }

const conCategorie = (t) => ({
  ...t,
  categorie: t.categorie.map(id => CATEGORIE.find(c => c.id === id) || { id, nome: 'Pulcini', anno: 2016 })
})
const listaMister = TORNEI.map(conCategorie)
const listaConArchiviata = listaMister.concat([conCategorie(TORNEO_ARCHIVIATA)])

// ---------------------------------------------------------------- costruiamo il modulo con la funzione vera
function caricaCostruttore(sorgente) {
  const corpo = estraiFunzione(sorgente, 'costruisciSezioni', ['okSezione', 'piazzati', 'extra', 'consentite'])
  const etichetta = estraiFunzione(sorgente, 'etichettaCategoria', ['c.anno'])
  const catDel = estraiFunzione(sorgente, 'categorieDel', ['t.categorie', 'categoria_id'])
  let isParent = estraiFunzione(sorgenteUtils, 'isParentCategory', ['agonistica', 'parent_id'])
  if (isParent) isParent = isParent.replace(/^export\s+/, '')
  if (!corpo || !etichetta || !catDel || !isParent) return null
  // `categorieOperative` e' il computed della pagina: qui e' lo stesso filtro, con le stesse categorie
  const codice = `
    ${isParent}
    ${etichetta}
    ${catDel}
    const categorieOperative = { value: CATEGORIE.filter(c => !isParentCategory(c, CATEGORIE)) };
    ${corpo}
    return costruisciSezioni;
  `
  try { return new Function('CATEGORIE', codice)(CATEGORIE) }
  catch (e) { console.log(`  FAIL la funzione estratta non compila: ${e.message}`); fail++; return null }
}

// ---------------------------------------------------------------- le asserzioni
const MIA = ['19']
const riepilogo = (sezioni) => `${sezioni.length} sezioni [${sezioni.map(s => s.catId).join(',')}] `
  + `${sezioni.reduce((n, s) => n + s.tornei.length, 0)} card`

function prova(f, etichetta) {
  console.log(`\n--- ${etichetta} ---`)

  // A) pagina aperta cosi' com'e': una sola sezione, la sua
  const A = f(listaMister, null, MIA)
  ck(`${etichetta}: A) senza filtro -> solo la SUA sezione`, '1 sezioni [19] 5 card', riepilogo(A))

  // B) IL CASO DEL BUG: tendino su una categoria che NON segue. Prima della toppa: 6 sezioni, 15 card.
  const B = f(listaMister, 26, MIA)
  ck(`${etichetta}: B) tendino su 2015 (non sua) -> nessuna sezione altrui`, '1 sezioni [19] 3 card', riepilogo(B))
  const strani = B.filter(s => !['19'].includes(String(s.catId))).map(s => s.titolo)
  ckVero(`${etichetta}: B) nessun "2018/2019 - Primi Calci" al mister dei 2016`, strani.length === 0,
    `sconfinano: ${strani.join(' | ')}`)
  // L'etichetta "(non operativa)" e' falsa per le categorie operative: non deve comparire qui
  ckVero(`${etichetta}: B) nessuna sezione etichettata "(non operativa)"`,
    !B.some(s => /non operativa/.test(s.titolo)),
    B.filter(s => /non operativa/.test(s.titolo)).map(s => s.titolo).join(' | '))

  // C) tendino su una SUA categoria: filtra, non raddoppia
  const C = f(listaMister, 19, MIA)
  ck(`${etichetta}: C) tendino sulla sua 2016 -> la sua sezione`, '1 sezioni [19] 5 card', riepilogo(C))

  // D) chi NON e' filtrato (admin/segreteria) non deve perdere niente: erano 6 sezioni e 17 card.
  //    L'ordine e' quello di `categorieOperative`, cioe' per ANNO crescente (25=2014, 26=2015, 19=2016,
  //    20=2017, 27=2018, 28=2019): non e' pignoleria, e' l'ordine che `ui_tornei.cjs` legge per agganciare
  //    le sezioni dal titolo invece che dall'indice.
  const D = f(listaMister, null, null)
  ck(`${etichetta}: D) admin senza whitelist -> le sue 6 sezioni restano, in ordine di anno`,
    '6 sezioni [25,26,19,20,27,28] 17 card', riepilogo(D))

  // E) admin col tendino su 2015: il filtro governa, una sola sezione
  const E = f(listaMister, 26, null)
  ck(`${etichetta}: E) admin tendino su 2015 -> solo quella`, '1 sezioni [26] 3 card', riepilogo(E))

  // F) lo SCOPO del ramo extra sopravvive alla toppa: un torneo iscritto solo a una categoria archiviata
  //    non deve sparire dalla pagina ("e' il modo peggiore di perdere un torneo", dice la nota del file)
  const F = f(listaConArchiviata, null, null)
  const fantasma = F.flatMap(s => s.tornei).filter(t => t.id === 99)
  ckVero(`${etichetta}: F) il torneo nella categoria archiviata NON sparisce`, fantasma.length === 1,
    `comparso ${fantasma.length} volte`)
  // ...e il suffisso resta DOVE E' GIUSTO: toglierlo dappertutto avrebbe "corretto" il bug nel modo sbagliato
  const sezFantasma = F.filter(s => s.tornei.some(t => t.id === 99)).map(s => s.titolo)
  ckVero(`${etichetta}: F) la categoria davvero non operativa LO DICE ancora`,
    sezFantasma.length === 1 && /non operativa/.test(sezFantasma[0]),
    `titoli: ${sezFantasma.join(' | ') || 'nessuna sezione'}`)
  const G = f(listaConArchiviata, null, MIA)
  const fantasmaG = G.flatMap(s => s.tornei).filter(t => t.id === 99)
  ckVero(`${etichetta}: G) per il mister quel torneo resta fuori (non e' una sua categoria)`, fantasmaG.length === 0,
    `e' comparso lo stesso`)
}

const f = caricaCostruttore(sorgenteVue)
if (!f) {
  console.log(`\n${pass} passati, ${fail} falliti (estrazione)`)
  process.exit(1)
}
prova(f, 'attuale')

// -------------------------------------------------- autoprovatura: l'arnese deve vederli rossi i difetti
// Tre mutazioni, una per riga di difesa aggiunta oggi. Ognuna asserisce che il file E' cambiato (una
// mutazione che non parte e' il falso verde gia' pagato due volte in questo repo) e che il caso giusto
// diventa rosso: un'asserzione che non si muove davanti al difetto che dovrebbe vedere non e' un'asserzione.
if (process.argv.includes('--prova-arnese')) {
  console.log('\n=== autoprovatura: rimetto i difetti che questo file esiste per impedire ===')
  const MUTAZIONI = [
    {
      nome: 'extra-non-filtrato',
      perche: 'il ramo extra duplica i tornei sotto tutte le categorie iscritte (il caso del mister dei 2016)',
      da: 'const chiavi = cats.length ? cats.filter(c => okSezione(c.id)) : [null]',
      a: 'const chiavi = cats.length ? cats : [null]',
      vista: (f2) => { const B = f2(listaMister, 26, MIA); return B.length > 1 || B.reduce((n, s) => n + s.tornei.length, 0) > 5 },
      misura: (f2) => riepilogo(f2(listaMister, 26, MIA))
    },
    {
      nome: 'etichetta-regalata',
      perche: 'il suffisso "(non operativa)" appiccicato anche a chi operativo lo e\' davvero',
      da: 'titolo: eOperativa ? etichettaCategoria(c) : etichettaCategoria(c) + \' (non operativa)\'',
      a: 'titolo: etichettaCategoria(c) + \' (non operativa)\'',
      vista: (f2) => f2(listaMister, 26, MIA).some(s => /non operativa/.test(s.titolo)),
      misura: (f2) => f2(listaMister, 26, MIA).map(s => s.titolo).join(' | ')
    },
    {
      nome: 'whitelist-null',
      perche: 'la whitelist delle sezioni non viene mai applicata (il comportamento dell\'admin dato a tutti)',
      da: 'const consentite = soloQueste && soloQueste.length ? soloQueste.map(String) : null',
      a: 'const consentite = null',
      vista: (f2) => f2(listaMister, null, MIA).length > 1,
      misura: (f2) => riepilogo(f2(listaMister, null, MIA))
    }
  ]
  for (const m of MUTAZIONI) {
    const guasto = sorgenteVue.split(m.da).join(m.a)
    if (guasto === sorgenteVue) {
      console.log(`  FAIL ${m.nome}: l'àncora non c'e' piu' -- questo arnese non prova piu' niente`)
      console.log(`         àncora cercata: ${m.da}`)
      fail++; continue
    }
    const f2 = caricaCostruttore(guasto)
    if (!f2) { console.log(`  FAIL ${m.nome}: il file mutato non compila`); fail++; continue }
    if (m.vista(f2)) {
      console.log(`  ok   ${m.nome} -> il difetto si vede (${m.misura(f2)})`)
      pass++
    } else {
      console.log(`  FAIL ${m.nome} (${m.perche}) non cambia nessun output: l'asserzione non ha testato niente`)
      console.log(`         misurato: ${m.misura(f2)}`)
      fail++
    }
  }
}

console.log(`\n${pass} passati, ${fail} falliti`)
process.exit(fail ? 1 : 0)
