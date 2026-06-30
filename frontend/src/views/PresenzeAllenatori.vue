<template>
  <div class="presenze-allenatori-page">
    <header class="page-header">
      <div class="header-content">
        <button class="btn-back" @click="router.push('/responsabili')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <div>
          <h1>Presenze Allenatori</h1>
          <p class="page-subtitle">Registro presenze allenatori e collaboratori</p>
        </div>
      </div>
    </header>

    <div class="mese-selector">
      <button class="btn-nav" @click="prevMese">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      <span class="mese-label">{{ meseLabel }} {{ anno }}</span>
      <button class="btn-nav" @click="nextMese">
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
      <table>
        <thead>
          <tr>
            <th class="th-num">#</th>
            <th class="th-nome">Allenatore</th>
            <th v-for="g in giorniMese" :key="g.num" :class="{ 'th-weekend': g.weekend }">
              <div class="giorno-num">{{ g.num }}</div>
              <div class="giorno-nome">{{ g.gg }}</div>
            </th>
            <th class="th-tot th-pres">TOT</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(allenatore, idx) in allenatori" :key="allenatore.id">
            <td class="td-num">{{ idx + 1 }}</td>
            <td class="td-nome">
              <span class="persona-name">{{ allenatore.cognome }} {{ allenatore.nome }}</span>
              <span v-if="allenatore.cellulare" class="persona-phone">{{ allenatore.cellulare }}</span>
            </td>
            <td v-for="g in giorniMese" :key="g.num"
              class="cella"
              :class="[getCodiceClasse(allenatore.id, g.num), { 'cella-disabled': !isAllenamentoGiorno(allenatore, g.dow) }]"
              @click="isAllenamentoGiorno(allenatore, g.dow) && openEdit(allenatore, g.num)">
              {{ getCodice(allenatore.id, g.num) }}
            </td>
            <td class="td-tot td-pres">{{ totalePresenze(allenatore.id) }}</td>
          </tr>
        </tbody>
      </table>

      <div v-if="allenatori.length === 0" class="empty-state">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="48" height="48">
          <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
          <circle cx="9" cy="7" r="4"/>
          <path d="M23 21v-2a4 4 0 00-3-3.87"/>
          <path d="M16 3.13a4 4 0 010 7.75"/>
        </svg>
        <p>Nessun allenatore trovato</p>
        <p class="empty-hint">Aggiungi allenatori dalla pagina Allenatori</p>
        <button class="btn-primary" @click="router.push('/allenatori')">Vai ad Allenatori</button>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="editModal.show" class="modal-overlay" @click.self="editModal.show = false">
        <div class="modal modal-edit">
          <div class="modal-header">
            <h3>{{ editModal.allenatore.cognome }}</h3>
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
import { ref, computed, onMounted } from "vue"
import { useRouter } from "vue-router"
import { getCodici, getPresenzeAllenatoriMese, upsertPresenzaAllenatore, getMisterList } from "../api/index.js"

const router = useRouter()

const oggi = new Date()
const anno = ref(oggi.getFullYear())
const mese = ref(oggi.getMonth() + 1)
const allenatori = ref([])
const codici = ref([])
const presenze = ref([])
const editModal = ref({ show: false, allenatore: null, giorno: null })

const mesiNomi = ["Gennaio","Febbraio","Marzo","Aprile","Maggio","Giugno","Luglio","Agosto","Settembre","Ottobre","Novembre","Dicembre"]
const giorniNomi = ["Dom","Lun","Mar","Mer","Gio","Ven","Sab"]
const meseLabel = computed(() => mesiNomi[mese.value - 1])

const codiciOrdinati = computed(() => {
  const order = ['X', 'AG', 'AI', 'P', 'R']
  return [...codici.value].sort((a, b) => order.indexOf(a.codice) - order.indexOf(b.codice))
})

const giorniMese = computed(() => {
  const n = new Date(anno.value, mese.value, 0).getDate()
  // Collect all training day-of-week values across all coaches
  const trainingDows = new Set()
  allenatori.value.forEach(a => {
    ;(a.giorni || []).forEach(g => trainingDows.add(g))
  })
  return Array.from({ length: n }, (_, i) => {
    const d = new Date(anno.value, mese.value - 1, i + 1)
    const dow = d.getDay()
    if (!trainingDows.size) return { num: i + 1, dow, gg: giorniNomi[dow], weekend: dow === 0 || dow === 6 }
    if (!trainingDows.has(dow)) return null
    return { num: i + 1, dow, gg: giorniNomi[dow], weekend: dow === 0 || dow === 6 }
  }).filter(Boolean)
})

function getCodice(utenteId, giorno) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entry = presenze.value.find(r => r.utente_id === utenteId && r.data === d)
  return entry ? entry.codice : ""
}

function isAllenamentoGiorno(allenatore, dow) {
  return (allenatore.giorni || []).includes(dow)
}

function getCodiceClasse(utenteId, giorno) {
  const codice = getCodice(utenteId, giorno)
  const c = codici.value.find(x => x.codice === codice)
  if (!c) return ""
  return c.tipo
}

function totalePresenze(utenteId) {
  return presenze.value.filter(r => r.utente_id === utenteId && ["X","P","R"].includes(r.codice)).length
}

function openEdit(allenatore, giorno) {
  editModal.value = { show: true, allenatore, giorno }
}

async function salvaPresenza(codice) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(editModal.value.giorno).padStart(2,"0")
  await upsertPresenzaAllenatore({ utente_id: editModal.value.allenatore.id, data: d, codice })
  await loadPresenze()
  editModal.value.show = false
}

function prevMese() {
  if (mese.value === 1) { mese.value = 12; anno.value-- }
  else mese.value--
}

function nextMese() {
  if (mese.value === 12) { mese.value = 1; anno.value++ }
  else mese.value++
}

async function loadPresenze() {
  const res = await getPresenzeAllenatoriMese(anno.value, mese.value)
  presenze.value = res.data || []
}

async function loadAll() {
  try {
    const [aRes, cRes] = await Promise.all([
      getMisterList(),
      getCodici()
    ])
    allenatori.value = aRes.data || []
    codici.value = cRes.data || []
  } catch (e) {
    console.error('Errore caricamento:', e)
  }
  await loadPresenze()
}

onMounted(() => {
  loadAll()
})
</script>

<style scoped>
.presenze-allenatori-page {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 2rem;
  animation: slideUp 0.4s ease-out;
}

.header-content {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
}

.header-content h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.02em;
  margin-bottom: 0.25rem;
}

.page-subtitle {
  color: var(--color-text-muted);
  font-size: 1rem;
}

.btn-back {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
  color: var(--color-text);
}

.btn-back:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-back svg {
  width: 20px;
  height: 20px;
}

/* Month selector */
.mese-selector {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
  padding: 0.75rem 1.5rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
}

.mese-label {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
  min-width: 200px;
  text-align: center;
}

.btn-nav {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  color: var(--color-text);
}

.btn-nav:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-nav svg {
  width: 18px;
  height: 18px;
}

/* Legenda */
.legenda {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.75rem;
  border-radius: var(--radius-sm);
  font-size: 0.8125rem;
  font-weight: 600;
}

.badge.presenza {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
  border: 1px solid rgba(16, 185, 129, 0.3);
}

.badge.assenza {
  background: rgba(239, 68, 68, 0.15);
  color: #ef4444;
  border: 1px solid rgba(239, 68, 68, 0.3);
}

.badge.permesso {
  background: rgba(245, 158, 11, 0.15);
  color: #f59e0b;
  border: 1px solid rgba(245, 158, 11, 0.3);
}

.badge-code {
  font-weight: 800;
  font-family: var(--font-mono);
}

/* Table */
.table-wrapper {
  overflow-x: auto;
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-border);
  background: var(--color-surface);
}

table {
  width: 100%;
  border-collapse: collapse;
  min-width: 700px;
}

thead th {
  padding: 0.75rem 0.5rem;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-text-muted);
  border-bottom: 1px solid var(--color-border);
  background: var(--color-surface-elevated);
  position: sticky;
  top: 0;
}

.th-num {
  width: 40px;
  text-align: center;
}

.th-nome {
  text-align: left;
  padding-left: 1rem;
  min-width: 160px;
}

.th-weekend {
  color: var(--color-accent);
}

.th-tot {
  width: 60px;
  text-align: center;
}

th .giorno-num {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text);
}

th .giorno-nome {
  font-size: 0.6875rem;
  font-weight: 500;
  color: var(--color-text-muted);
}

tbody td {
  padding: 0.5rem;
  text-align: center;
  border-bottom: 1px solid var(--color-border-light);
  font-size: 0.875rem;
}

.td-num {
  color: var(--color-text-muted);
  font-size: 0.75rem;
  font-weight: 600;
}

.td-nome {
  text-align: left;
  padding-left: 1rem;
}

.persona-name {
  font-weight: 600;
  color: var(--color-text);
}

.persona-phone {
  display: block;
  font-size: 0.75rem;
  color: var(--color-text-muted);
  font-weight: 400;
}

.cella {
  cursor: pointer;
  font-weight: 700;
  font-family: var(--font-mono);
  font-size: 0.8125rem;
  transition: all var(--transition-fast);
  min-width: 36px;
  user-select: none;
}

.cella:hover {
  background: var(--color-surface-elevated);
  transform: scale(1.1);
}

.cella.presenza {
  color: #10b981;
  background: rgba(16, 185, 129, 0.1);
  border-radius: var(--radius-sm);
}

.cella.assenza {
  color: #ef4444;
  background: rgba(239, 68, 68, 0.1);
  border-radius: var(--radius-sm);
}

.cella.permesso {
  color: #f59e0b;
  background: rgba(245, 158, 11, 0.1);
  border-radius: var(--radius-sm);
}

.cella-disabled {
  opacity: 0.2;
  cursor: default;
  pointer-events: none;
}

.td-tot {
  font-weight: 800;
  font-family: var(--font-mono);
  color: #10b981;
}

/* Empty state */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 4rem 2rem;
  text-align: center;
  gap: 0.75rem;
}

.empty-state svg {
  color: var(--color-text-muted);
  opacity: 0.5;
}

.empty-state p {
  color: var(--color-text-muted);
  font-size: 1rem;
}

.empty-hint {
  font-size: 0.875rem !important;
  color: var(--color-text-muted) !important;
}

.btn-primary {
  padding: 0.625rem 1.25rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: var(--radius-md);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  font-family: inherit;
  margin-top: 0.5rem;
}

.btn-primary:hover {
  opacity: 0.9;
}

/* Modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  animation: fadeIn 0.2s ease-out;
}

.modal-edit {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  width: 90%;
  max-width: 400px;
  animation: slideUp 0.3s ease-out;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.25rem;
}

.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-date {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
}

.codici-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.btn-codice {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
  padding: 0.75rem;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  font-family: inherit;
  border: 1px solid var(--color-border);
  background: var(--color-surface-elevated);
}

.btn-codice:hover {
  transform: translateY(-2px);
}

.btn-codice.presenza {
  border-color: rgba(16, 185, 129, 0.3);
}

.btn-codice.presenza:hover {
  background: rgba(16, 185, 129, 0.15);
  border-color: #10b981;
}

.btn-codice.assenza {
  border-color: rgba(239, 68, 68, 0.3);
}

.btn-codice.assenza:hover {
  background: rgba(239, 68, 68, 0.15);
  border-color: #ef4444;
}

.btn-codice.permesso {
  border-color: rgba(245, 158, 11, 0.3);
}

.btn-codice.permesso:hover {
  background: rgba(245, 158, 11, 0.15);
  border-color: #f59e0b;
}

.btn-codice.cancella {
  border-color: rgba(107, 114, 128, 0.3);
}

.btn-codice.cancella:hover {
  background: rgba(107, 114, 128, 0.15);
  border-color: #6b7280;
}

.btn-codice .codice {
  font-weight: 800;
  font-family: var(--font-mono);
  font-size: 1rem;
  color: var(--color-text);
}

.btn-codice .descrizione {
  font-size: 0.6875rem;
  color: var(--color-text-muted);
}

.btn-close-modal {
  width: 100%;
  padding: 0.625rem;
  background: var(--color-bg);
  color: var(--color-text-secondary);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  font-family: inherit;
}

.btn-close-modal:hover {
  background: var(--color-border);
  color: var(--color-text);
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@media (max-width: 640px) {
  .presenze-allenatori-page {
    padding: 1rem;
  }
}
</style>
