<template>
  <div class="rotate-device-overlay" v-if="showRotateMessage">
    <div class="rotate-device-message">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="4" y="2" width="16" height="20" rx="2" ry="2"/>
        <line x1="12" y1="18" x2="12" y2="18"/>
      </svg>
      <span>Ruota il dispositivo in orizzontale</span>
    </div>
  </div>
  <div class="registro-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/scelta/' + route.params.id)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          Indietro
        </button>
        <div class="header-badge">
          <span class="badge-dot"></span>
          {{ categoriaAttiva?.anno }}
        </div>
      </div>
      <div class="header-main">
        <h1 class="category-name">
          <span class="name-gradient">{{ categoriaAttiva?.nome }}</span>
        </h1>
        <p class="header-subtitle">Registro presenze</p>
      </div>
    </header>

    <div class="mese-selector-pill">
      <button class="btn-nav-mese" @click="prevMese">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      <span class="mese-label">{{ meseLabel }} {{ anno }}</span>
      <button class="btn-nav-mese" @click="nextMese">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <polyline points="9 18 15 12 9 6"/>
        </svg>
      </button>
    </div>

    <div class="legenda">
      <span v-for="c in codiciOrdinati" :key="c.codice" :class="['badge', c.tipo]">
        <span class="badge-code">{{ c.codice }}</span>
        <span class="badge-desc">{{ c.descrizione }}</span>
      </span>
    </div>
    
    <div class="table-wrapper">
      <template v-if="isDirigente">
        <table>
          <thead>
            <tr>
              <th class="th-num">#</th>
              <th class="th-nome">Cognome Nome</th>
              <th v-for="g in giorniMese" :key="g.num" :class="{ 'th-weekend': g.weekend }">
                <div class="giorno-num">{{ g.num }}</div>
                <div class="giorno-nome">{{ g.gg }}</div>
              </th>
              <th class="th-tot th-pres">TOT</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(persona, idx) in personeAlfabetiche" :key="persona.id">
              <td class="td-num">{{ idx + 1 }}</td>
              <td class="td-nome">
                <span class="persona-name">{{ persona.cognome }} {{ persona.nome }}</span>
              </td>
              <td v-for="g in giorniMese" :key="g.num"
                class="cella" 
                :class="getCodiceClasse(persona.id, g.num)"
                @click="openEdit(persona, g.num)">
                {{ getCodice(persona.id, g.num) }}
              </td>
              <td class="td-tot td-pres">{{ totalePresenze(persona.id) }}</td>
            </tr>
          </tbody>
        </table>
      </template>
      <template v-else>


        <template v-if="isPortieri">
          <div v-for="cat in categoriePortieri" :key="cat" class="gruppo-block">
            <div class="gruppo-header">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                <path d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16"/>
                <polyline points="1 10 5 10 11 14"/>
                <polyline points="15 10 21 10 21 14"/>
              </svg>
              {{ cat }}
            </div>
            <table>
              <thead>
                <tr>
                  <th class="th-num">#</th>
                  <th class="th-nome">Cognome Nome</th>
                  <th v-for="g in giorniMese" :key="g.num" :class="{ 'th-weekend': g.weekend }">
                    <div class="giorno-num">{{ g.num }}</div>
                    <div class="giorno-nome">{{ g.gg }}</div>
                  </th>
                  <th class="th-tot th-pres">TOT</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(persona, idx) in personePerCategoria(cat)" :key="persona.id">
                  <td class="td-num">{{ idx + 1 }}</td>
                  <td class="td-nome">
                    <span class="persona-name">{{ persona.cognome }} {{ persona.nome }}</span>
                  </td>
                  <td v-for="g in giorniMese" :key="g.num"
                    class="cella" 
                    :class="getCodiceClasse(persona.id, g.num)"
                    @click="openEdit(persona, g.num)">
                    {{ getCodice(persona.id, g.num) }}
                  </td>
                  <td class="td-tot td-pres">{{ totalePresenze(persona.id) }}</td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="riga-totale pres">
                  <td class="td-num"></td>
                  <td class="td-nome tot-label">Presenti</td>
                  <td v-for="g in giorniMese" :key="g.num" class="tot-cell">
                    {{ totGiornoCategoria(cat, g.num).pres || '' }}
                  </td>
                  <td class="td-tot"></td>
                </tr>
              </tfoot>
            </table>
          </div>
        </template>
        <template v-if="!isPortieri">
        <div v-for="gruppo in gruppi" :key="gruppo" class="gruppo-block">
          <div class="gruppo-header">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87"/>
              <path d="M16 3.13a4 4 0 010 7.75"/>
            </svg>
            {{ gruppo }}
          </div>
          <table>
            <thead>
              <tr>
                <th class="th-num">#</th>
                <th class="th-nome">Cognome Nome</th>
                <th v-for="g in giorniMese" :key="g.num" :class="{ 'th-weekend': g.weekend }">
                  <div class="giorno-num">{{ g.num }}</div>
                  <div class="giorno-nome">{{ g.gg }}</div>
                </th>
                <th class="th-tot th-pres">TOT</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(persona, idx) in personePerGruppo(gruppo)" :key="persona.id">
                <td class="td-num">{{ idx + 1 }}</td>
                <td class="td-nome">
                  <span class="persona-name">{{ persona.cognome }} {{ persona.nome }}</span>
                </td>
                <td v-for="g in giorniMese" :key="g.num"
                  class="cella"
                  :class="[getCodiceClasse(persona.id, g.num), { 'cella-readthrough': isReadthrough(persona.id, g.num) }]"
                  @click="openEdit(persona, g.num)">
                  {{ getCodice(persona.id, g.num) }}
                </td>
                <td class="td-tot td-pres">{{ totalePresenze(persona.id) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="riga-totale pres">
                <td class="td-num"></td>
                <td class="td-nome tot-label">Presenti</td>
                <td v-for="g in giorniMese" :key="g.num" class="tot-cell">
                  {{ totGiornoGruppo(gruppo, g.num).pres || '' }}
                </td>
                <td class="td-tot"></td>
              </tr>
              <tr class="riga-totale ass">
                <td class="td-num"></td>
                <td class="td-nome tot-label">Assenti</td>
                <td v-for="g in giorniMese" :key="g.num" class="tot-cell">
                  {{ totGiornoGruppo(gruppo, g.num).ass || '' }}
                </td>
                <td class="td-tot"></td>
              </tr>
          </tfoot>
        </table>
      </div>
        </template>
      </template>
      
      <div class="totale-generale">
        <div class="totale-header">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <path d="M12 20V10"/>
            <path d="M18 20V4"/>
            <path d="M6 20v-4"/>
          </svg>
          Totale Generale
        </div>
        <table class="totale-table">
          <thead>
            <tr>
              <th class="th-label"></th>
              <th v-for="g in giorniMese" :key="g.num" :class="{ 'th-weekend': g.weekend }">
                <div class="giorno-num">{{ g.num }}</div>
                <div class="giorno-nome">{{ g.gg }}</div>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="tot-label th-label">Presenti</td>
              <td v-for="g in giorniMese" :key="g.num" class="tot-cell tot-pres">
                {{ totGiornoTutti(g.num).pres || '' }}
              </td>
            </tr>
            <tr>
              <td class="tot-label th-label">Assenti</td>
              <td v-for="g in giorniMese" :key="g.num" class="tot-cell tot-ass">
                {{ totGiornoTutti(g.num).ass || '' }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="editModal.show" class="modal-overlay" @click.self="editModal.show = false">
        <div class="modal modal-edit">
          <div class="modal-header">
            <h3>{{ editModal.persona.cognome }} {{ editModal.persona.nome }}</h3>
            <span class="modal-date">{{ editModal.giorno }} {{ meseLabel }} {{ anno }}</span>
          </div>
          <div class="codici-grid">
            <button v-for="c in codici" :key="c.codice"
              :class="['btn-codice', c.tipo]" @click="salvaPresenza(c.codice)">
              <span class="codice">{{ c.codice }}</span>
              <span class="descrizione">{{ c.descrizione }}</span>
            </button>
            <button class="btn-codice cancella" @click="salvaPresenza(null)">
              <span class="codice">-</span>
              <span class="descrizione">Cancella</span>
            </button>
          </div>
          <button class="btn-close-modal" @click="editModal.show = false">Chiudi</button>
        </div>
      </div>
    </Teleport>


  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { getPersone, getCodici, getRegistroMese, upsertRegistro, getCategorie, getGruppi } from "../api/index.js"
import { useStore as useCategoria } from "../store.js"

const route = useRoute()
const router = useRouter()
const categoriaId = computed(() => parseInt(route.params.id))
const { categoriaAttiva, utenteAttivo } = useCategoria()
const isDirigente = computed(() => ['dirigente', 'segreteria', 'infermeria'].includes(utenteAttivo.value?.ruolo))
const isPortieri = computed(() => categoriaAttiva.value?.is_portieri)
const showRotateMessage = ref(false)

const checkOrientation = () => {
  const isMobile = window.innerWidth <= 768
  const isPortrait = window.innerHeight > window.innerWidth
  showRotateMessage.value = isMobile && isPortrait
}

onMounted(() => {
  checkOrientation()
  window.addEventListener('resize', checkOrientation)
  window.addEventListener('orientationchange', checkOrientation)
})

onUnmounted(() => {
  window.removeEventListener('resize', checkOrientation)
  window.removeEventListener('orientationchange', checkOrientation)
})

const oggi = new Date()
const anno = ref(oggi.getFullYear())
const mese = ref(oggi.getMonth() + 1)
const persone = ref([])
const codici = ref([])
const registro = ref([])
const giorniAllenamento = ref([])
const editModal = ref({ show: false, persona: null, giorno: null })

const mesiNomi = ["Gennaio","Febbraio","Marzo","Aprile","Maggio","Giugno","Luglio","Agosto","Settembre","Ottobre","Novembre","Dicembre"]
const giorniNomi = ["Dom","Lun","Mar","Mer","Gio","Ven","Sab"]
const meseLabel = computed(() => mesiNomi[mese.value - 1])

const codiciOrdinati = computed(() => {
  const order = ['X', 'AG', 'AI', 'P', 'R']
  return [...codici.value].sort((a, b) => order.indexOf(a.codice) - order.indexOf(b.codice))
})

const giorniMese = computed(() => {
  const n = new Date(anno.value, mese.value, 0).getDate()
  const tutti = Array.from({ length: n }, (_, i) => {
    const d = new Date(anno.value, mese.value - 1, i + 1)
    const dow = d.getDay()
    return { num: i + 1, dow, gg: giorniNomi[dow], weekend: dow === 0 || dow === 6 }
  })
  if (giorniAllenamento.value.length === 0) return tutti
  return tutti.filter(g => giorniAllenamento.value.includes(g.dow))
})

const hasSenzaGruppo = computed(() => {
  return persone.value.some(p => !p.gruppo_nome && !p.gruppo_id)
})

const allGruppiNames = computed(() => {
  const fromPersone = persone.value.map(p => p.gruppo_nome).filter(Boolean)
  const fromDb = gruppiList.value.map(g => g.nome)
  const result = [...new Set([...fromPersone, ...fromDb])]
  if (hasSenzaGruppo.value) result.push("Senza gruppo")
  return result
})

const gruppi = computed(() => {
  const all = allGruppiNames.value
  const normali = all.filter(g => g && g?.toLowerCase() !== "senza gruppo" && g?.toLowerCase() !== "portieri").sort()
  const portieri = all.filter(g => g?.toLowerCase() === "portieri")
  const senza = all.filter(g => g?.toLowerCase() === "senza gruppo")
  return [...normali, ...portieri, ...senza]
})

const categoriePortieri = computed(() => {
  if (!isPortieri.value) return []
  const cats = [...new Set(persone.value.map(p => p.categoria_nome).filter(Boolean))].sort()
  return cats
})

function personePerCategoria(cat) {
  return persone.value.filter(p => p.categoria_nome === cat)
}

function personaLabel(p) {
  if (isPortieri.value && p.categoria_nome) {
    return `${p.cognome} ${p.nome} <span class="cat-badge">${p.categoria_nome}</span>`
  }
  return `${p.cognome} ${p.nome}`
}
const personeAlfabetiche = computed(() => [...persone.value].sort((a, b) => a.cognome.localeCompare(b.cognome)))
function personePerGruppo(g) { return persone.value.filter(p => (p.gruppo_nome || "Senza gruppo") === g) }
function getCodice(personaId, giorno) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entry = registro.value.find(r => r.persona_id === personaId && r.data === d)
  return entry ? entry.codice : ""
}
function getCodiceClasse(personaId, giorno) {
  const codice = getCodice(personaId, giorno)
  const c = codici.value.find(x => x.codice === codice)
  if (!c) return ""
  return c.tipo + (codice ? " cod-" + codice.toLowerCase() : "")
}
function totalePresenze(personaId) {
  return registro.value.filter(r => r.persona_id === personaId && ["X","P","R"].includes(r.codice) && !r.is_portieri_readthrough).length
}
function totaleAssenze(personaId) {
  return registro.value.filter(r => r.persona_id === personaId && ["AG","AI"].includes(r.codice)).length
}
function isReadthrough(personaId, giorno) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entry = registro.value.find(r => r.persona_id === personaId && r.data === d)
  return entry && entry.is_portieri_readthrough
}
function openEdit(persona, giorno) {
  if (isReadthrough(persona.id, giorno)) return
  editModal.value = { show: true, persona, giorno }
}

async function salvaPresenza(codice) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(editModal.value.giorno).padStart(2,"0")
  await upsertRegistro({ persona_id: editModal.value.persona.id, data: d, codice, categoria_id: categoriaId.value })
  await loadRegistro()
  editModal.value.show = false
}

function totGiornoGruppo(gruppo, giorno) {
  const ids = personePerGruppo(gruppo).map(p => p.id)
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entries = registro.value.filter(r => ids.includes(r.persona_id) && r.data === d && !r.is_portieri_readthrough)
  return {
    pres: entries.filter(r => ["X","P","R"].includes(r.codice)).length || "",
    ass: entries.filter(r => ["AG","AI"].includes(r.codice)).length || ""
  }
}
function totGiornoCategoria(cat, giorno) {
  const ids = personePerCategoria(cat).map(p => p.id)
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entries = registro.value.filter(r => ids.includes(r.persona_id) && r.data === d)
  return {
    pres: entries.filter(r => ["X","P","R"].includes(r.codice)).length || "",
    ass: entries.filter(r => ["AG","AI"].includes(r.codice)).length || ""
  }
}
function totGiornoTutti(giorno) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entries = registro.value.filter(r => r.data === d && !r.is_portieri_readthrough)
  return {
    pres: entries.filter(r => ["X","P","R"].includes(r.codice)).length || "",
    ass: entries.filter(r => ["AG","AI"].includes(r.codice)).length || ""
  }
}
function prevMese() { if (mese.value === 1) { mese.value = 12; anno.value-- } else mese.value-- }
function nextMese() { if (mese.value === 12) { mese.value = 1; anno.value++ } else mese.value++ }
async function loadRegistro() {
  if (!categoriaId.value || isNaN(categoriaId.value)) return
  const res = await getRegistroMese(categoriaId.value, anno.value, mese.value)
  registro.value = res.data
}
const gruppiList = ref([])
async function loadPersone() {
  if (!categoriaId.value || isNaN(categoriaId.value)) return
  try {
    const p = await getPersone(categoriaId.value)
    persone.value = p.data
  } catch(e) { console.error('Error loading persone:', e) }
  try {
    const g = await getGruppi(categoriaId.value)
    gruppiList.value = (g.data || []).map(item =>
      typeof item === 'string' ? { id: null, nome: item } : { id: item.id, nome: item.nome }
    )
  } catch(e) { console.error('Error loading gruppi:', e) }
  const idToNome = Object.fromEntries(gruppiList.value.map(g => [g.id, g.nome]).filter(([id]) => id != null))
  persone.value.forEach(p => { if (p.gruppo_id && idToNome[p.gruppo_id]) p.gruppo_nome = idToNome[p.gruppo_id] })
}
async function loadCategoria() {
  if (categoriaAttiva.value && categoriaAttiva.value.giorni) {
    giorniAllenamento.value = categoriaAttiva.value.giorni.split(",").map(Number)
  } else {
    const res = await getCategorie()
    const cat = res.data.find(c => c.id === categoriaId.value)
    if (cat && cat.giorni) giorniAllenamento.value = cat.giorni.split(",").map(Number)
    else giorniAllenamento.value = []
  }
}

onMounted(async () => {
  const [c] = await Promise.all([getCodici()])
  codici.value = c.data
  await loadCategoria()
  await loadPersone()
  await loadRegistro()
})
watch([anno, mese], loadRegistro)
</script>

<style scoped>
.registro-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1400px;
  margin: 0 auto;
  overflow: hidden;
  min-height: 100vh;
}

/* ── Background Glows ── */
.bg-glow {
  position: fixed;
  border-radius: 50%;
  filter: blur(120px);
  pointer-events: none;
  z-index: 0;
}

.bg-glow-1 {
  width: 500px;
  height: 500px;
  top: -150px;
  right: -80px;
  background: radial-gradient(circle, rgba(220, 38, 38, 0.08) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 400px;
  height: 400px;
  bottom: -100px;
  left: -80px;
  background: radial-gradient(circle, rgba(124, 58, 237, 0.06) 0%, transparent 70%);
  animation: glowFloat 10s ease-in-out infinite reverse;
}

@keyframes glowFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(25px, -18px) scale(1.05); }
  66% { transform: translate(-18px, 12px) scale(0.95); }
}

/* ── Header ── */
.page-header {
  position: relative;
  z-index: 1;
  margin-bottom: 1.5rem;
  animation: fadeSlideIn 0.6s ease-out both;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.btn-back-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.4rem 0.4rem 1rem;
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  color: var(--color-text-secondary);
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-back-pill svg {
  background: rgba(255, 255, 255, 0.08);
  border-radius: 50%;
  width: 24px;
  height: 24px;
  padding: 3px;
}

.btn-back-pill:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.2);
  color: var(--color-text);
}

.header-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(220, 38, 38, 0.1);
  border: 1px solid rgba(220, 38, 38, 0.2);
  border-radius: 100px;
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-primary);
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--color-primary);
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}

.header-main {
  position: relative;
}

.category-name {
  font-size: clamp(2rem, 6vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.25rem;
}

.name-gradient {
  background: linear-gradient(135deg, #ffffff 0%, #ffffff 40%, var(--color-primary) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.header-subtitle {
  font-size: 1rem;
  color: var(--color-text-muted);
  font-weight: 400;
}

/* ── Mese Selector Pill ── */
.mese-selector-pill {
  position: relative;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  gap: 1rem;
  padding: 0.5rem 0.5rem 0.5rem 1.25rem;
  background: rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  margin-bottom: 1.25rem;
  animation: fadeSlideIn 0.6s ease-out 0.1s both;
}

.mese-label {
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--color-text);
  min-width: 160px;
  text-align: center;
}

.btn-nav-mese {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid var(--color-border);
  border-radius: 50%;
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.btn-nav-mese:hover {
  background: rgba(220, 38, 38, 0.15);
  border-color: rgba(220, 38, 38, 0.3);
  color: var(--color-primary);
}

/* ── Legenda ── */
.legenda {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
  padding: 1rem 1.25rem;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  animation: fadeSlideIn 0.6s ease-out 0.2s both;
}

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.3rem 0.625rem;
  border-radius: 8px;
  font-size: 0.8125rem;
}

.badge-code {
  font-weight: 700;
  font-family: var(--font-mono);
}

.badge-desc {
  font-weight: 500;
}

.badge.presenza {
  background: rgba(34, 197, 94, 0.12);
  border: 1px solid rgba(34, 197, 94, 0.2);
  color: #4ade80;
}

.badge.assenza {
  background: rgba(220, 38, 38, 0.12);
  border: 1px solid rgba(220, 38, 38, 0.2);
  color: #f87171;
}

.badge.extra {
  background: rgba(234, 179, 8, 0.12);
  border: 1px solid rgba(234, 179, 8, 0.2);
  color: #fbbf24;
}

/* ── Table Wrapper ── */
.table-wrapper {
  position: relative;
  z-index: 1;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  animation: fadeSlideIn 0.6s ease-out 0.3s both;
}

table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 0.8125rem;
  background: rgba(255, 255, 255, 0.02);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  overflow: hidden;
  color: var(--color-text);
}

th, td {
  border: none;
  border-bottom: 1px solid rgba(255, 255, 255, 0.04);
  text-align: center;
  padding: 0.5rem 0.25rem;
  white-space: nowrap;
  color: var(--color-text);
}

tr:last-child td {
  border-bottom: none;
}

.th-num, .td-num { width: 40px; color: var(--color-text-muted); font-size: 0.75rem; }
.th-nome, .td-nome { text-align: left; min-width: 150px; padding-left: 1rem; }
.th-tot, .td-tot { min-width: 60px; }

.th-weekend {
  background: rgba(255, 255, 255, 0.02);
  color: var(--color-text-muted);
}

th {
  background: rgba(255, 255, 255, 0.04);
  font-weight: 600;
  color: var(--color-text-secondary);
  position: sticky;
  top: 0;
}

.giorno-num { font-weight: 600; font-size: 0.8125rem; color: var(--color-text); }
.giorno-nome { font-size: 0.6875rem; color: var(--color-text-muted); }

.persona-name {
  font-weight: 500;
  color: var(--color-text);
}

/* ── Group Blocks ── */
.gruppo-block {
  margin-bottom: 2rem;
  background: rgba(255, 255, 255, 0.02);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  overflow: hidden;
}

.gruppo-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.875rem 1.25rem;
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.15) 0%, rgba(220, 38, 38, 0.05) 100%);
  border-bottom: 1px solid rgba(220, 38, 38, 0.15);
  color: var(--color-text);
  font-weight: 600;
  font-size: 0.9375rem;
}

.gruppo-header svg {
  opacity: 0.7;
  color: var(--color-primary);
}


/* ── Cells ── */
.cella {
  cursor: pointer;
  font-weight: 600;
  font-family: var(--font-mono);
  min-width: 32px;
  transition: all var(--transition-fast);
  color: var(--color-text);
  border-radius: 4px;
}

.cella:hover {
  background: rgba(220, 38, 38, 0.15);
}

.cella.presenza {
  background: rgba(34, 197, 94, 0.12);
  color: #4ade80;
}

.cella.assenza {
  background: rgba(220, 38, 38, 0.12);
  color: #f87171;
}

.cella.cod-ag {
  background: rgba(234, 179, 8, 0.12) !important;
  color: #fbbf24 !important;
}

.cella.cod-p {
  background: rgba(234, 179, 8, 0.12) !important;
  color: #fbbf24 !important;
}

.cella.cod-r {
  background: rgba(34, 197, 94, 0.15) !important;
  color: #4ade80 !important;
  font-weight: 700;
}

.cella-readthrough {
  opacity: 0.5;
  cursor: default !important;
  pointer-events: none;
}

.td-pres { color: #4ade80; font-weight: 700; }

.riga-totale td {
  background: rgba(255, 255, 255, 0.03);
  font-weight: 600;
  font-size: 0.75rem;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
  color: var(--color-text-secondary);
}

.riga-totale.pres td { color: #4ade80; }
.riga-totale.ass td { color: #f87171; }

.tot-cell {
  font-weight: 600;
  font-family: var(--font-mono);
  color: var(--color-text-secondary);
}

/* ── Totale Generale ── */
.totale-generale {
  margin-top: 1.5rem;
  background: rgba(255, 255, 255, 0.02);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  overflow: hidden;
}

.totale-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.875rem 1.25rem;
  background: linear-gradient(135deg, rgba(168, 85, 247, 0.15) 0%, rgba(168, 85, 247, 0.05) 100%);
  border-bottom: 1px solid rgba(168, 85, 247, 0.15);
  color: #a78bfa;
  font-weight: 700;
  font-size: 0.8125rem;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}

.totale-generale table th {
  background: rgba(255, 255, 255, 0.03);
  font-weight: 600;
  font-size: 0.75rem;
  padding: 0.375rem;
  color: var(--color-text-secondary);
}

.tot-label {
  font-weight: 600;
  text-align: left;
  padding-left: 1rem;
  color: var(--color-text-secondary);
}

.tot-pres {
  background: rgba(34, 197, 94, 0.08) !important;
  color: #4ade80 !important;
}

.tot-ass {
  background: rgba(220, 38, 38, 0.08) !important;
  color: #f87171 !important;
}

/* ── Modals ── */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(8px);
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.9) translateY(10px); }
  to { opacity: 1; transform: scale(1) translateY(0); }
}

@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

/* ── Edit Modal ── */
.modal {
  background: rgba(30, 30, 30, 0.95);
  backdrop-filter: blur(20px);
  border: 1px solid var(--color-border);
  border-radius: 24px;
  width: 100%;
  max-width: 480px;
  box-shadow: 0 25px 60px rgba(0, 0, 0, 0.5);
  animation: scaleIn 0.3s ease-out;
  overflow: hidden;
}

.modal-edit { max-width: 520px; }

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 1.5rem 1.5rem 0;
  gap: 1rem;
}

.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-date {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  font-weight: 500;
}

.codici-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 0.5rem;
  padding: 1.25rem 1.5rem;
}

.btn-codice {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0.875rem 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  cursor: pointer;
  transition: all var(--transition-fast);
  background: rgba(255, 255, 255, 0.03);
}

.btn-codice:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
}

.btn-codice .codice {
  font-size: 1.25rem;
  font-weight: 700;
  font-family: var(--font-mono);
  margin-bottom: 0.25rem;
  color: var(--color-text);
}

.btn-codice .descrizione {
  font-size: 0.6875rem;
  color: var(--color-text-muted);
  text-align: center;
}

.btn-codice.presenza {
  border-color: rgba(34, 197, 94, 0.3);
  background: rgba(34, 197, 94, 0.1);
  color: #4ade80;
}
.btn-codice.presenza:hover { background: rgba(34, 197, 94, 0.18); }

.btn-codice.assenza {
  border-color: rgba(220, 38, 38, 0.3);
  background: rgba(220, 38, 38, 0.1);
  color: #f87171;
}
.btn-codice.assenza:hover { background: rgba(220, 38, 38, 0.18); }

.btn-codice.extra {
  border-color: rgba(234, 179, 8, 0.3);
  background: rgba(234, 179, 8, 0.1);
  color: #fbbf24;
}
.btn-codice.extra:hover { background: rgba(234, 179, 8, 0.18); }

.btn-codice.cancella {
  border-color: rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.02);
  color: var(--color-text-muted);
}
.btn-codice.cancella:hover { background: rgba(255, 255, 255, 0.06); }

.btn-close-modal {
  display: block;
  width: calc(100% - 3rem);
  margin: 0 1.5rem 1.5rem;
  padding: 0.75rem;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-close-modal:hover {
  background: rgba(255, 255, 255, 0.08);
}

/* ── Rotate Overlay ── */
.rotate-device-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.95);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  flex-direction: column;
  gap: 1rem;
}

.rotate-device-message {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  color: white;
  text-align: center;
  padding: 2rem;
}

.rotate-device-message svg {
  width: 80px;
  height: 80px;
  animation: rotate-hint 1.5s ease-in-out infinite;
}

.rotate-device-message span {
  font-size: 1.25rem;
  font-weight: 600;
}

@keyframes rotate-hint {
  0%, 100% { transform: rotate(0deg); }
  25% { transform: rotate(-20deg); }
  75% { transform: rotate(20deg); }
}

/* ── Responsive ── */
@media (max-width: 768px) {
  .registro-page {
    padding: 1.5rem 1rem 3rem;
  }
  .header-top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }
  .mese-selector-pill {
    width: 100%;
    justify-content: center;
  }
}

@media (max-width: 480px) {
  .category-name {
    font-size: 1.75rem;
  }
  .mese-label {
    font-size: 0.875rem;
    min-width: 130px;
  }
  .btn-nav-mese {
    width: 28px;
    height: 28px;
  }
}
</style>
