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
const trovati = new Set()
for (const m of code.matchAll(/_ctx\.([A-Za-z_$][\w$]*)/g)) trovati.add(m[1])
// con _ctx.x = y il compilatore emette anche _ctx.x, quindi nessun filtro serve: sono tutti reali
const globali = new Set(['$router', '$route', '$emit', '$props', '$attrs', '$slots', '$el', '$nextTick'])
const sospetti = [...trovati].filter(n => !globali.has(n))

console.log('file:', file)
console.log('identificatori del template non risolti dai binding di <script setup>:', sospetti.length ? sospetti.join(', ') : 'nessuno')
process.exit(sospetti.length ? 2 : 0)
