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
  <div class="registro-container">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/scelta/' + route.params.id)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <button class="btn-home" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
        </button>
      </div>
      <span class="titolo-toolbar">Registro Presenze — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
    </header>

    <div class="mese-selector">
        <button class="btn-nav-mese" @click="prevMese">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>
        <span class="mese-label">{{ meseLabel }} {{ anno }}</span>
        <button class="btn-nav-mese" @click="nextMese">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
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
        <div class="gruppi-actions">
          <button class="btn-gruppo-add" @click="groupModal = { show: true, nome: '', editing: null }">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 5v14M5 12h14"/>
            </svg>
            <span>Nuovo Gruppo</span>
          </button>
        </div>
        <div v-for="gruppo in gruppi" :key="gruppo" class="gruppo-block">
          <div class="gruppo-header">
            <button v-if="gruppo?.toLowerCase() !== 'portieri' && gruppo !== 'Senza gruppo'" class="btn-edit-gruppo" @click="openEditGruppo(gruppo)" title="Modifica gruppo">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
            </button>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
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
      
      <div class="totale-generale">
        <div class="totale-header">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 20V10"/>
            <path d="M18 20V4"/>
            <path d="M6 20v-4"/>
          </svg>
          TOTALE GENERALE
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

    <Teleport to="body">
      <div v-if="groupModal.show" class="modal-overlay" @click.self="groupModal.show = false">
        <div class="gruppo-modal">
          <div class="gruppo-modal-header">
            <svg class="gruppo-modal-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87"/>
              <path d="M16 3.13a4 4 0 010 7.75"/>
            </svg>
            <h3>{{ groupModal.editing ? 'Modifica Gruppo' : 'Nuovo Gruppo' }}</h3>
          </div>
          <div class="gruppo-modal-body">
            <label for="gruppo-nome" class="sr-only">Nome gruppo</label>
            <input 
              id="gruppo-nome" 
              v-model="groupModal.nome" 
              name="gruppo_nome" 
              class="gruppo-input"
              placeholder="Inserisci nome gruppo..." 
              @keyup.enter="salvaGruppo" 
            />
          </div>
          <div class="gruppo-modal-actions">
            <button v-if="groupModal.editing" class="btn-rimuovi" @click="rimuoviGruppo(groupModal.nome)">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
              </svg>
              Elimina
            </button>
            <button class="btn-save" @click="salvaGruppo">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="20 6 9 17 4 12"/>
              </svg>
              {{ groupModal.editing ? 'Salva' : 'Crea' }}
            </button>
          </div>
          <button class="btn-close-gruppo" @click="groupModal.show = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { getPersone, getCodici, getRegistroMese, upsertRegistro, getCategorie, getGruppi, createGruppo, deleteGruppo } from "../api/index.js"
import { useStore as useCategoria } from "../store.js"

const route = useRoute()
const router = useRouter()
const categoriaId = computed(() => parseInt(route.params.id))
const { categoriaAttiva, utenteAttivo } = useCategoria()
const isDirigente = computed(() => ['dirigente', 'segreteria', 'infermeria'].includes(utenteAttivo.value?.ruolo))
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
const groupModal = ref({ show: false, nome: '', editing: null })

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
  return registro.value.filter(r => r.persona_id === personaId && ["X","P","R"].includes(r.codice)).length
}
function totaleAssenze(personaId) {
  return registro.value.filter(r => r.persona_id === personaId && ["AG","AI"].includes(r.codice)).length
}
function openEdit(persona, giorno) { editModal.value = { show: true, persona, giorno } }

async function salvaPresenza(codice) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(editModal.value.giorno).padStart(2,"0")
  await upsertRegistro({ persona_id: editModal.value.persona.id, data: d, codice, categoria_id: categoriaId.value })
  await loadRegistro()
  editModal.value.show = false
}

async function salvaGruppo() {
  if (!groupModal.value.nome.trim()) return
  await createGruppo({ nome: groupModal.value.nome.trim(), categoria_id: categoriaId.value })
  groupModal.value.show = false
  groupModal.value.nome = ''
  groupModal.value.editing = null
  await loadPersone()
}

function openEditGruppo(nome) {
  const g = gruppiList.value.find(x => x.nome === nome)
  if (g) {
    groupModal.value = { show: true, nome: g.nome, editing: g }
  }
}

async function rimuoviGruppo(nome) {
  if (!confirm('Eliminare il gruppo "' + nome + '"?')) return
  const g = gruppiList.value.find(x => x.nome === nome)
  if (g?.id) {
    await deleteGruppo(g.id)
    await loadPersone()
  }
}

function totGiornoGruppo(gruppo, giorno) {
  const ids = personePerGruppo(gruppo).map(p => p.id)
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entries = registro.value.filter(r => ids.includes(r.persona_id) && r.data === d)
  return {
    pres: entries.filter(r => ["X","P","R"].includes(r.codice)).length || "",
    ass: entries.filter(r => ["AG","AI"].includes(r.codice)).length || ""
  }
}
function totGiornoTutti(giorno) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entries = registro.value.filter(r => r.data === d)
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
.registro-container {
  padding: 1.5rem;
  font-family: var(--font-sans);
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
}

.header-left {
  display: flex;
  gap: 0.5rem;
}

.btn-back, .btn-home {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-back:hover, .btn-home:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

.btn-back svg, .btn-home svg {
  width: 18px;
  height: 18px;
}

.mese-selector {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  justify-content: center;
  padding: 0.75rem;
  background: var(--color-surface);
  margin-bottom: 0.5rem;
}

.btn-nav-mese {
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.btn-nav-mese:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

.btn-nav-mese svg {
  width: 20px;
  height: 20px;
}

.mese-label {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
  min-width: 180px;
  text-align: center;
}

@media (max-width: 480px) {
  .mese-selector {
    gap: 0.5rem;
    padding: 0.5rem;
  }
  
  .btn-nav-mese {
    width: 40px;
    height: 40px;
  }
  
  .btn-nav-mese svg {
    width: 18px;
    height: 18px;
  }
  
  .mese-label {
    font-size: 1.1rem;
    min-width: 140px;
  }
}

.legenda {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
  padding: 1rem;
  background: #ffffff;
  border-radius: var(--radius-lg);
  border: 1px solid #e5e5e5;
}

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.625rem;
  border-radius: var(--radius-sm);
  font-size: 0.8125rem;
  color: #111827;
}

.badge-code {
  font-weight: 700;
  font-family: var(--font-mono);
}

.badge-desc {
  font-weight: 500;
  color: #374151;
}

.badge.presenza { background: #dcfce7; color: #166534; }
.badge.assenza { background: #fee2e2; color: var(--color-primary); }
.badge.extra { background: #fef3c7; color: #92400e; }

.table-wrapper {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8125rem;
  background: #ffffff;
  color: #111827;
}

th, td {
  border: 1px solid #e5e5e5;
  text-align: center;
  padding: 0.5rem 0.25rem;
  white-space: nowrap;
  color: #111827;
}

.th-num, .td-num { width: 40px; }
.th-nome, .td-nome { text-align: left; min-width: 150px; padding-left: 1rem; }
.th-tot, .td-tot { min-width: 60px; }

.th-weekend { background: #f5f5f5; color: #666666; }
th { background: #f9fafb; font-weight: 600; color: #374151; }

.giorno-num { font-weight: 600; font-size: 0.875rem; color: #111827; }
.giorno-nome { font-size: 0.6875rem; color: #666666; }

.persona-name { font-weight: 500; color: #111827; }

.gruppo-block {
  margin-bottom: 1.5rem;
  background: #ffffff;
  border: 2px solid var(--color-primary);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.gruppo-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.875rem 1.25rem;
  background: var(--color-primary);
  color: white;
  font-weight: 600;
  font-size: 0.9375rem;
}

.gruppo-header svg {
  width: 18px;
  height: 18px;
  opacity: 0.9;
}

.gruppi-actions {
  margin-bottom: 1rem;
}

.btn-gruppo-add {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-lg);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  box-shadow: 0 2px 8px rgba(220, 38, 38, 0.3);
}

.btn-gruppo-add:hover {
  background: var(--color-primary-dark);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(220, 38, 38, 0.4);
}

.btn-gruppo-add svg {
  width: 20px;
  height: 20px;
}

.btn-edit-gruppo {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-edit-gruppo:hover {
  background: var(--color-primary-dark);
  transform: scale(1.1);
}

.btn-edit-gruppo svg {
  width: 16px;
  height: 16px;
}

.cella {
  cursor: pointer;
  font-weight: 600;
  font-family: var(--font-mono);
  min-width: 32px;
  transition: all var(--transition-fast);
  color: #111827;
}

.cella:hover { background: #fee2e2; }
.cella.presenza { background: #dcfce7; color: #166534; }
.cella.assenza { background: #fee2e2; color: var(--color-primary); }
.cella.cod-ag { background: #fef3c7 !important; color: #92400e !important; }
.cella.cod-p { background: #fef3c7 !important; color: #92400e !important; }
.cella.cod-r { background: #dcfce7 !important; color: var(--color-primary) !important; font-weight: 700; }

.td-pres { color: #166534; font-weight: 700; }

.riga-totale td { 
  background: #f9fafb; 
  font-weight: 600; 
  font-size: 0.75rem;
  border-top: 2px solid #e5e5e5;
  color: #111827;
}

.riga-totale.pres td { color: #166534; }
.riga-totale.ass td { color: var(--color-primary); }

.tot-cell { font-weight: 600; font-family: var(--font-mono); color: #111827; }

.totale-generale {
  margin-top: 1.5rem;
  background: #ffffff;
  border: 2px solid var(--color-primary);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.totale-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.875rem 1.25rem;
  background: var(--color-primary);
  color: white;
  font-weight: 700;
  font-size: 0.875rem;
  letter-spacing: 0.05em;
}

.totale-header svg {
  width: 18px;
  height: 18px;
}

.totale-generale table th {
  background: #f9fafb;
  font-weight: 600;
  font-size: 0.75rem;
  padding: 0.375rem;
  color: #374151;
}

.tot-label {
  background: #f9fafb;
  font-weight: 600;
  text-align: left;
  padding-left: 1rem;
  color: #111827;
}

.tot-pres { background: #dcfce7 !important; color: #166534; }
.tot-ass { background: #fee2e2 !important; color: var(--color-primary); }

.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(4px);
}

.gruppo-modal {
  background: linear-gradient(145deg, #ffffff 0%, #f8fafc 100%);
  border-radius: var(--radius-xl);
  width: 100%;
  max-width: 400px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25), 0 12px 24px -8px rgba(0, 0, 0, 0.15);
  padding: 2rem;
  position: relative;
  animation: scaleIn 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.gruppo-modal-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}

.gruppo-modal-icon {
  width: 28px;
  height: 28px;
  color: var(--color-primary);
}

.gruppo-modal-header h3 {
  font-size: 1.25rem;
  font-weight: 700;
  color: #111827;
}

.gruppo-modal-body {
  margin-bottom: 1.5rem;
}

.gruppo-input {
  width: 100%;
  padding: 0.875rem 1rem;
  border: 2px solid #e5e5e5;
  border-radius: var(--radius-md);
  font-size: 1rem;
  transition: all var(--transition-fast);
}

.gruppo-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.1);
}

.gruppo-modal-actions {
  display: flex;
  gap: 0.75rem;
}

.btn-rimuovi, .btn-save {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  border: none;
  border-radius: var(--radius-md);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-rimuovi {
  background: #fee2e2;
  color: #dc2626;
}

.btn-rimuovi:hover {
  background: #fecaca;
  transform: translateY(-1px);
}

.btn-save {
  flex: 1;
  background: var(--color-primary);
  color: white;
}

.btn-save:hover {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
}

.btn-rimuovi svg, .btn-save svg {
  width: 18px;
  height: 18px;
}

.btn-close-gruppo {
  position: absolute;
  top: 1rem;
  right: 1rem;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-close-gruppo:hover {
  background: #f3f4f6;
}

.btn-close-gruppo svg {
  width: 20px;
  height: 20px;
  color: #6b7280;
}

.modal {
  background: #ffffff;
  border-radius: var(--radius-xl);
  width: 100%;
  max-width: 480px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  animation: scaleIn 0.3s ease-out;
}

.modal-edit {
  max-width: 520px;
}

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
  color: #111827;
}

.modal-date {
  font-size: 0.875rem;
  color: #666666;
  font-weight: 500;
}

.modal-close {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f5f5;
  border: none;
  border-radius: 50%;
  color: #666666;
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.modal-close:hover {
  background: #e5e5e5;
  color: #111827;
}

.modal-close svg { width: 20px; height: 20px; }

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
  padding: 0.75rem;
  border: 2px solid #e5e5e5;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  background: #ffffff;
}

.btn-codice:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

.btn-codice .codice {
  font-size: 1.25rem;
  font-weight: 700;
  font-family: var(--font-mono);
  margin-bottom: 0.25rem;
  color: #111827;
}

.btn-codice .descrizione {
  font-size: 0.6875rem;
  color: #666666;
  text-align: center;
}

.btn-codice.presenza { border-color: #166534; background: #dcfce7; color: #166534; }
.btn-codice.presenza:hover { background: #bbf7d0; }
.btn-codice.assenza { border-color: var(--color-primary); background: #fee2e2; color: var(--color-primary); }
.btn-codice.assenza:hover { background: #fecaca; }
.btn-codice.extra { border-color: #92400e; background: #fef3c7; color: #92400e; }
.btn-codice.extra:hover { background: #fde68a; }
.btn-codice.cancella { border-color: #d1d5db; background: #ffffff; }
.btn-codice.cancella:hover { background: #f5f5f5; }

.btn-close-modal {
  display: block;
  width: calc(100% - 3rem);
  margin: 0 1.5rem 1.5rem;
  padding: 0.75rem;
  background: #ffffff;
  border: 1px solid #d1d5db;
  border-radius: var(--radius-md);
  color: #374151;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-close-modal:hover {
  background: #f5f5f5;
}

.modal-body {
  padding: 1.5rem;
}

.form-group {
  margin-bottom: 1rem;
}

.form-group:last-child { margin-bottom: 0; }

.form-group label {
  display: block;
  font-size: 0.875rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.5rem;
}

.form-group input, .form-group select {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 2px solid #d1d5db;
  border-radius: var(--radius-md);
  font-size: 1rem;
  color: #111827;
  background: #ffffff;
  transition: all var(--transition-fast);
}

.form-group input:focus, .form-group select:focus {
  outline: none;
  border-color: var(--color-primary);
  background: #ffffff;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem 1.5rem;
  border-top: 1px solid #f3f4f6;
}

.btn-secondary {
  padding: 0.75rem 1.25rem;
  background: #ffffff;
  border: 1px solid #d1d5db;
  border-radius: var(--radius-md);
  color: #374151;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-secondary:hover { background: #f5f5f5; }

.btn-primary {
  padding: 0.75rem 1.5rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-primary:hover {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
}

@media (max-width: 768px) {
  .registro-container { padding: 1rem; }
  .page-header { flex-direction: column; align-items: stretch; }
  .mese-selector { justify-content: center; }
}

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
</style>
