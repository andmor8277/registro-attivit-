<template>
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
        <div v-for="gruppo in gruppi" :key="gruppo" class="gruppo-block">
          <div class="gruppo-header">
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
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { getPersone, getCodici, getRegistroMese, upsertRegistro, getCategorie } from "../api/index.js"
import { useStore as useCategoria } from "../store.js"

const route = useRoute()
const router = useRouter()
const categoriaId = computed(() => parseInt(route.params.id))
const { categoriaAttiva, utenteAttivo } = useCategoria()
const isDirigente = computed(() => utenteAttivo.value?.ruolo === 'dirigente')

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

const gruppi = computed(() => [...new Set(persone.value.map(p => p.gruppo_nome || "Senza gruppo"))])
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
  const res = await getRegistroMese(categoriaId.value, anno.value, mese.value)
  registro.value = res.data
}
async function loadPersone() {
  const res = await getPersone(categoriaId.value)
  persone.value = res.data
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
  border-radius: var(--radius-lg);
  border: 1px solid #e5e5e5;
  overflow: visible;
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
  .registro-container { padding: 0.5rem; }
  .page-header { flex-direction: column; align-items: stretch; }
  .mese-selector { justify-content: center; }
  
  .legenda {
    display: none;
  }
  
  .table-wrapper {
    overflow-x: visible !important;
    overflow-y: visible !important;
  }
  
  .gruppo-block {
    margin-bottom: 2rem;
    overflow: visible;
  }
  
  .gruppo-header {
    position: sticky;
    position: -webkit-sticky;
    top: 0;
    z-index: 30;
  }
  
  table {
    min-width: 700px;
    display: block;
    overflow-x: auto;
    white-space: nowrap;
  }
  
  thead, tbody, tfoot {
    display: block;
  }
  
  tbody {
    display: block;
    width: 100%;
  }
  
  tr {
    display: table;
    width: 100%;
    table-layout: fixed;
  }
  
  th, td {
    display: table-cell;
  }
  
  thead th {
    position: sticky;
    position: -webkit-sticky;
    top: 45px;
    z-index: 20;
    background: #f9fafb;
  }
  
  .th-num {
    position: sticky !important;
    position: -webkit-sticky !important;
    left: 0;
    z-index: 25;
  }
  
  .th-nome {
    position: sticky !important;
    position: -webkit-sticky !important;
    left: 40px;
    z-index: 25;
  }
  
  .th-tot {
    position: sticky !important;
    position: -webkit-sticky !important;
    right: 0;
    z-index: 25;
  }
  
  .td-num {
    position: sticky !important;
    position: -webkit-sticky !important;
    left: 0;
    z-index: 10;
    background: #ffffff;
  }
  
  .td-nome {
    position: sticky !important;
    position: -webkit-sticky !important;
    left: 40px;
    z-index: 10;
    background: #ffffff;
  }
  
  .td-tot {
    position: sticky !important;
    position: -webkit-sticky !important;
    right: 0;
    z-index: 10;
    background: #ffffff;
  }
  
  tfoot td {
    position: sticky;
    position: -webkit-sticky;
    bottom: 0;
    background: #f9fafb;
    z-index: 30;
    font-weight: 600;
    border-top: 2px solid #d1d5db;
  }
  
  tfoot .td-num {
    z-index: 31;
  }
  
  tfoot .td-nome {
    z-index: 31;
  }
  
  tfoot .td-tot {
    z-index: 31;
  }
  
  tbody tr:hover .td-nome {
    background: #f5f5f5;
  }
  
  .td-pres {
    background: #f9fafb;
  }
  
  .totale-generale {
    margin-top: 2rem;
  }
  
  .totale-header {
    position: sticky;
    position: -webkit-sticky;
    top: 0;
    z-index: 30;
  }
  
  .totale-table {
    min-width: 700px;
  }
  
  .totale-table th,
  .totale-table td {
    display: table-cell;
  }
  
  .totale-table .tot-label {
    position: sticky !important;
    position: -webkit-sticky !important;
    left: 0;
    z-index: 20;
    background: #f9fafb;
  }
  
  .totale-table thead th {
    position: sticky;
    position: -webkit-sticky;
    top: 45px;
    z-index: 15;
    background: #f9fafb;
  }
}
</style>
