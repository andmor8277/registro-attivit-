// Verifica statica del template di un SFC: ogni identificatore che il template usa e che NON e'
// un binding di <script setup> finisce su _ctx, cioe' a runtime sarebbe undefined e la pagina
// bianca. Il build Vite non lo dice: il template compila comunque.
const fs = require('fs')
const path = require('path')
const { parse, compileScript } = require(path.join(process.cwd(), 'node_modules/@vue/compiler-sfc'))

const file = process.argv[2]
const src = fs.readFileSync(file, 'utf8')
const { descriptor, errors } = parse(src, { filename: file })
if (errors.length) { console.log('ERRORI PARSE:', errors.map(e => e.message)); process.exit(1) }

const id = 'check'
const script = compileScript(descriptor, { id, inlineTemplate: true })
const code = script.content

// _ctx.<nome> = riferito dal template ma non risolto dai binding dello script
//
// Il commento va tolto PRIMA di cercare, perche' la regex non distingue il codice dalla prosa: ho
// scritto un commento che citava letteralmente `_ctx.window` e il controllo e' diventato ROSSO per
// una frase. Vale anche al contrario, ed e' il verso pericoloso: un `_ctx.pulsante` scritto in un
// commento maschererebbe un assente vero come "gia' segnalato". Quindi i commenti non vengono
// buttati via, ma contati e riportati a parte come informazione: un risultato verde che arriva
// solo perche' ho tolto del testo deve restare visibile, non diventare invisibile.
const senzaCommenti = code.split('\n')
  .filter(l => !/^\s*\/\//.test(l))
  .join('\n')
const inCommento = code.split('\n')
  .filter(l => /^\s*\/\//.test(l))
  .join('\n')

const trovati = new Set()
for (const m of senzaCommenti.matchAll(/_ctx\.([A-Za-z_$][\w$]*)/g)) trovati.add(m[1])
// con _ctx.x = y il compilatore emette anche _ctx.x, quindi nessun filtro serve: sono tutti reali
const globali = new Set(['$router', '$route', '$emit', '$props', '$attrs', '$slots', '$el', '$nextTick'])
const sospetti = [...trovati].filter(n => !globali.has(n))

const citati = new Set()
for (const m of inCommento.matchAll(/_ctx\.([A-Za-z_$][\w$]*)/g)) citati.add(m[1])

console.log('file:', file)
console.log('identificatori del template non risolti dai binding di <script setup>:', sospetti.length ? sospetti.join(', ') : 'nessuno')
if (citati.size) console.log('  (nota: citati solo in un commento, non contati:', [...citati].join(', ') + ')')
process.exit(sospetti.length ? 2 : 0)
