<template>
  <div class="valutazioni-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/scelta/' + categoriaId)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          <span>Indietro</span>
        </button>
      </div>
      <div class="header-main">
        <h1 class="page-title">
          <span class="title-gradient">Schede Valutative</span>
        </h1>
        <p class="header-subtitle">{{ categoria?.nome }} — Valutazione giocatori (1-3)</p>
      </div>
    </header>

    <div class="legend">
      <span class="legend-item"><span class="legend-dot dot-1"></span> 1 — Base</span>
      <span class="legend-item"><span class="legend-dot dot-2"></span> 2 — Intermedio</span>
      <span class="legend-item"><span class="legend-dot dot-3"></span> 3 — Avanzato</span>
    </div>

    <div v-if="loading" class="loading-wrap">
      <div class="spinner"></div>
      <span>Caricamento...</span>
    </div>

    <div class="table-container">
      <table class="val-table">
        <thead>
          <tr>
            <th class="th-player">Giocatore</th>
            <th v-for="col in colonne" :key="col.key" class="th-skill" :title="col.tipologia">
              {{ col.label }}
            </th>
            <th class="th-note">Note</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, idx) in righe" :key="row.persona_id" :class="{ 'row-empty': !row.valutazione_id }">
            <td class="td-player">
              <span class="player-cognome">{{ row.cognome }}</span>
              <span class="player-nome">{{ row.nome }}</span>
            </td>
            <td v-for="col in colonne" :key="col.key" class="td-skill">
              <div class="rating-group" @click.stop>
                <button
                  v-for="n in 3" :key="n"
                  class="rating-btn"
                  :class="{
                    active: row[col.key] === n,
                    ['level-' + n]: true
                  }"
                  @click="setValore(row, col.key, n)"
                >
                  {{ n }}
                </button>
              </div>
            </td>
            <td class="td-note">
              <input
                type="text"
                class="note-input"
                :value="row.note || ''"
                placeholder="..."
                @click.stop
                @input="setNote(row, $event.target.value)"
                @click="focusRow = row.persona_id"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="righe.length === 0 && !loading" class="empty-state">
      <span>Nessun giocatore trovato</span>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { getPersone, getCategorie, getValutazioni, updateValutazione, createValutazione } from '../api/index.js'

const router = useRouter()
const route = useRoute()
const categoriaId = computed(() => parseInt(route.params.id))
const categoria = ref(null)
const loading = ref(true)
const focusRow = ref(null)

const colonne = [
  { key: 'tecnica', label: 'Tecnica', tipologia: 'Controllo palla, primo tocco' },
  { key: 'velocita', label: 'Velocità', tipologia: 'Scatto, resistenza anaerobica' },
  { key: 'resistenza', label: 'Resistenza', tipologia: 'Condizione fisica, endurance' },
  { key: 'attitudine', label: 'Attitudine', tipologia: 'Impegno, voglia di migliorare' },
  { key: 'posizione', label: 'Posizione', tipologia: 'Letto di gioco, posizionamento' },
  { key: 'gioco_di_testa', label: 'Gioco aereo', tipologia: 'Colpo di testa, anticipo' },
  { key: 'tiro', label: 'Tiro', tipologia: 'Finalizzazione, potenza' },
  { key: 'passaggio', label: 'Passaggio', tipologia: 'Visione, precisione' },
  { key: 'dribbling', label: 'Dribbling', tipologia: 'Regate, cambi di direzione' },
  { key: 'disciplina', label: 'Disciplina', tipologia: 'Comportamento, rispetto regole' },
]

const righe = ref([])

onMounted(async () => {
  await Promise.all([loadCategoria(), loadDati()])
})

async function loadCategoria() {
  try {
    const res = await getCategorie()
    const cats = Array.isArray(res) ? res : (res?.data || [])
    categoria.value = cats.find(c => c.id === categoriaId.value) || null
  } catch (e) {
    console.error(e)
  }
}

async function loadDati() {
  loading.value = true
  try {
    const [personeRes, valutazioniRes] = await Promise.all([
      getPersone(categoriaId.value),
      getValutazioni(categoriaId.value).catch(() => [])
    ])

    const persone = Array.isArray(personeRes) ? personeRes : (personeRes?.data || [])
    const valutazioni = Array.isArray(valutazioniRes) ? valutazioniRes : (valutazioniRes?.data || [])

    const valMap = {}
    for (const v of valutazioni) {
      valMap[v.persona_id] = v
    }

    righe.value = persone.map(p => {
      const v = valMap[p.id] || {}
      const row = {
        persona_id: p.id,
        cognome: p.cognome,
        nome: p.nome,
        valutazione_id: v.id || null,
        note: v.note || '',
      }
      for (const col of colonne) {
        row[col.key] = v[col.key] || null
      }
      return row
    })
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

async function setValore(row, key, value) {
  const newVal = row[key] === value ? null : value
  row[key] = newVal

  const payload = {
    persona_id: row.persona_id,
    categoria_id: categoriaId.value,
  }
  for (const col of colonne) {
    payload[col.key] = row[col.key]
  }
  payload.note = row.note

  try {
    if (row.valutazione_id) {
      await updateValutazione(row.valutazione_id, payload)
    } else {
      const res = await createValutazione(payload)
      row.valutazione_id = res.data?.id || res.id
    }
  } catch (e) {
    console.error(e)
    row[key] = value === null ? null : value
  }
}

async function setNote(row, value) {
  row.note = value

  const payload = {
    persona_id: row.persona_id,
    categoria_id: categoriaId.value,
  }
  for (const col of colonne) {
    payload[col.key] = row[col.key]
  }
  payload.note = value

  try {
    if (row.valutazione_id) {
      await updateValutazione(row.valutazione_id, payload)
    } else {
      const res = await createValutazione(payload)
      row.valutazione_id = res.data?.id || res.id
    }
  } catch (e) {
    console.error(e)
  }
}
</script>

<style scoped>
.valutazioni-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1400px;
  margin: 0 auto;
  overflow: hidden;
  min-height: 100vh;
}

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
  left: -100px;
  background: radial-gradient(circle, rgba(34, 197, 94, 0.1) 0%, transparent 70%);
}

.bg-glow-2 {
  width: 450px;
  height: 450px;
  bottom: -100px;
  right: -80px;
  background: radial-gradient(circle, rgba(168, 85, 247, 0.08) 0%, transparent 70%);
}

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
  margin-bottom: 1.25rem;
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

.header-main {
  position: relative;
}

.page-title {
  font-size: clamp(2rem, 6vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.375rem;
}

.title-gradient {
  background: linear-gradient(135deg, #ffffff 0%, #ffffff 40%, #22c55e 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.header-subtitle {
  font-size: 1rem;
  color: var(--color-text-muted);
  font-weight: 400;
}

.legend {
  position: relative;
  z-index: 1;
  display: flex;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
  animation: fadeSlideIn 0.6s ease-out 0.1s both;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--color-text-secondary);
}

.legend-dot {
  width: 24px;
  height: 24px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.75rem;
  color: white;
}

.dot-1 { background: #ef4444; }
.dot-2 { background: #f59e0b; }
.dot-3 { background: #22c55e; }

.loading-wrap {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 4rem;
  color: var(--color-text-muted);
  font-size: 0.875rem;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-border);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.table-container {
  position: relative;
  z-index: 1;
  overflow-x: auto;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  animation: fadeSlideIn 0.6s ease-out 0.2s both;
}

.val-table {
  width: 100%;
  border-collapse: collapse;
  min-width: 1100px;
}

.val-table th {
  padding: 0.75rem 0.5rem;
  font-size: 0.625rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-text-muted);
  border-bottom: 1px solid var(--color-border);
  background: rgba(255, 255, 255, 0.02);
  text-align: center;
  white-space: nowrap;
  position: sticky;
  top: 0;
}

.th-player {
  text-align: left;
  padding-left: 1rem;
  min-width: 160px;
}

.th-skill {
  min-width: 100px;
}

.th-note {
  min-width: 140px;
}

.val-table td {
  padding: 0.5rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.04);
  text-align: center;
  vertical-align: middle;
}

.td-player {
  text-align: left;
  padding-left: 1rem;
}

.player-cognome {
  font-weight: 700;
  color: var(--color-text);
  font-size: 0.875rem;
}

.player-nome {
  font-weight: 400;
  color: var(--color-text-secondary);
  font-size: 0.8rem;
  margin-left: 0.25rem;
}

.rating-group {
  display: flex;
  gap: 3px;
  justify-content: center;
}

.rating-btn {
  width: 28px;
  height: 28px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  background: transparent;
  color: var(--color-text-muted);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
  font-family: inherit;
  padding: 0;
}

.rating-btn:hover {
  border-color: rgba(255, 255, 255, 0.3);
  color: var(--color-text);
}

.rating-btn.active {
  border-color: transparent;
  color: white;
  transform: scale(1.05);
}

.rating-btn.level-1.active {
  background: #ef4444;
  box-shadow: 0 2px 8px rgba(239, 68, 68, 0.4);
}

.rating-btn.level-2.active {
  background: #f59e0b;
  box-shadow: 0 2px 8px rgba(245, 158, 11, 0.4);
}

.rating-btn.level-3.active {
  background: #22c55e;
  box-shadow: 0 2px 8px rgba(34, 197, 94, 0.4);
}

.note-input {
  width: 100%;
  padding: 0.375rem 0.5rem;
  border: 1px solid transparent;
  border-radius: 6px;
  background: transparent;
  color: var(--color-text);
  font-size: 0.8rem;
  font-family: inherit;
  transition: all 0.15s;
  text-align: center;
}

.note-input:focus {
  outline: none;
  border-color: var(--color-border);
  background: rgba(255, 255, 255, 0.05);
}

.note-input::placeholder {
  color: var(--color-text-muted);
  opacity: 0.4;
}

.row-empty:hover {
  background: rgba(255, 255, 255, 0.02);
}

.val-table tbody tr:hover {
  background: rgba(255, 255, 255, 0.03);
}

.empty-state {
  position: relative;
  z-index: 1;
  text-align: center;
  padding: 4rem;
  color: var(--color-text-muted);
  font-size: 0.875rem;
}

@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

@media (max-width: 768px) {
  .valutazioni-page {
    padding: 1.5rem 1rem 3rem;
  }
  .legend {
    flex-wrap: wrap;
    gap: 0.75rem;
  }
}
</style>
