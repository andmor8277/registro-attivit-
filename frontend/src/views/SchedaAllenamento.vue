<template>
  <div class="scheda-page">
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
        <p class="header-subtitle">Scheda Allenamento Individuale</p>
      </div>
    </header>

    <div class="controls-row">
      <div class="date-picker-pill">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
          <line x1="16" y1="2" x2="16" y2="6"/>
          <line x1="8" y1="2" x2="8" y2="6"/>
          <line x1="3" y1="10" x2="21" y2="10"/>
        </svg>
        <input type="date" v-model="dataSelezionata" class="date-input" />
      </div>
      <button class="btn-add" @click="apriModalNuovo">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <line x1="12" y1="5" x2="12" y2="19"/>
          <line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        Nuovo
      </button>
    </div>

    <div class="table-wrapper">
      <table v-if="schede.length > 0">
        <thead>
          <tr>
            <th class="th-num">#</th>
            <th class="th-nome">Giocatore</th>
            <th class="th-gps">Distanza Totale</th>
            <th class="th-gps">Alta Velocità</th>
            <th class="th-gps">Sprint</th>
            <th class="th-gps">Vel. Max</th>
            <th class="th-gps">Accel.</th>
            <th class="th-gps">Decel.</th>
            <th class="th-gps">Met. Power</th>
            <th class="th-gps">PlayerLoad</th>
            <th class="th-gps">Calorie</th>
            <th class="th-gps">Tempo</th>
            <th class="th-gps">RPE</th>
            <th class="th-note">Note</th>
            <th class="th-actions"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(scheda, idx) in schede" :key="scheda.id">
            <td class="td-num">{{ idx + 1 }}</td>
            <td class="td-nome">
              <span class="persona-name">{{ scheda.cognome }} {{ scheda.nome }}</span>
            </td>
            <td class="td-gps">{{ scheda.distanza_totale ? scheda.distanza_totale.toFixed(0) + 'm' : '-' }}</td>
            <td class="td-gps">{{ scheda.distanza_alta_velocita ? scheda.distanza_alta_velocita.toFixed(0) + 'm' : '-' }}</td>
            <td class="td-gps">{{ scheda.distanza_sprint ? scheda.distanza_sprint.toFixed(0) + 'm' : '-' }}</td>
            <td class="td-gps">{{ scheda.velocita_massima ? scheda.velocita_massima.toFixed(1) + 'km/h' : '-' }}</td>
            <td class="td-gps">{{ scheda.accelerazioni ?? '-' }}</td>
            <td class="td-gps">{{ scheda.decelerazioni ?? '-' }}</td>
            <td class="td-gps">{{ scheda.metabolic_power ? scheda.metabolic_power.toFixed(1) + 'W/kg' : '-' }}</td>
            <td class="td-gps">{{ scheda.player_load ? scheda.player_load.toFixed(0) : '-' }}</td>
            <td class="td-gps">{{ scheda.calorie ? scheda.calorie.toFixed(0) + 'kcal' : '-' }}</td>
            <td class="td-gps">{{ scheda.tempo_lavoro ? scheda.tempo_lavoro + 'min' : '-' }}</td>
            <td class="td-rpe" :class="rpeClass(scheda.rpe)">{{ scheda.rpe ?? '-' }}</td>
            <td class="td-note">{{ scheda.note || '-' }}</td>
            <td class="td-actions">
              <button class="btn-edit" @click="apriModalEdit(scheda)" title="Modifica">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                  <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                  <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
                </svg>
              </button>
              <button class="btn-delete" @click="eliminaScheda(scheda.id)" title="Elimina">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                  <polyline points="3 6 5 6 21 6"/>
                  <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                </svg>
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-else class="empty-state">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="48" height="48">
          <circle cx="12" cy="12" r="10"/>
          <path d="M12 6v6l4 2"/>
        </svg>
        <p>Nessun dato allenamento per questa data</p>
        <button class="btn-add-empty" @click="apriModalNuovo">Aggiungi primo allenamento</button>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="modal.show" class="modal-overlay" @click.self="modal.show = false">
        <div class="modal modal-scheda">
          <div class="modal-header">
            <h3>{{ modal.id ? 'Modifica' : 'Nuovo' }} Allenamento</h3>
            <button class="modal-close" @click="modal.show = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>

          <div class="modal-body">
            <div class="form-section">
              <label class="form-label">Giocatore</label>
              <select v-model="modal.persona_id" class="form-select">
                <option :value="null" disabled>Seleziona giocatore...</option>
                <option v-for="p in persone" :key="p.id" :value="p.id">
                  {{ p.cognome }} {{ p.nome }}
                </option>
              </select>
            </div>

            <div class="form-section">
              <label class="form-label">Data</label>
              <input type="date" v-model="modal.data" class="form-input" />
            </div>

            <div class="metrics-grid">
              <div class="metric-input">
                <label class="metric-label">Distanza Totale</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.distanza_totale" placeholder="0" class="metric-value" />
                  <span class="metric-unit">m</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Alta Velocità (&gt;19.8km/h)</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.distanza_alta_velocita" placeholder="0" class="metric-value" />
                  <span class="metric-unit">m</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Sprint (&gt;25.2km/h)</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.distanza_sprint" placeholder="0" class="metric-value" />
                  <span class="metric-unit">m</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Vel. Massima</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.velocita_massima" step="0.1" placeholder="0" class="metric-value" />
                  <span class="metric-unit">km/h</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Accelerazioni (&gt;3m/s²)</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.accelerazioni" placeholder="0" class="metric-value" />
                  <span class="metric-unit">n.</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Decelerazioni (&gt;3m/s²)</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.decelerazioni" placeholder="0" class="metric-value" />
                  <span class="metric-unit">n.</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Metabolic Power</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.metabolic_power" step="0.1" placeholder="0" class="metric-value" />
                  <span class="metric-unit">W/kg</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">PlayerLoad</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.player_load" placeholder="0" class="metric-value" />
                  <span class="metric-unit">PL</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Calorie</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.calorie" placeholder="0" class="metric-value" />
                  <span class="metric-unit">kcal</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Tempo Lavoro</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.tempo_lavoro" placeholder="0" class="metric-value" />
                  <span class="metric-unit">min</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">RPE (1-10)</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.rpe" min="1" max="10" placeholder="0" class="metric-value" />
                  <span class="metric-unit">/10</span>
                </div>
              </div>
            </div>

            <div class="form-section">
              <label class="form-label">Note</label>
              <textarea v-model="modal.note" placeholder="Note sull'allenamento..." class="form-textarea" rows="3"></textarea>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-save" @click="salvaScheda" :disabled="!modal.persona_id || !modal.data">
              Salva
            </button>
            <button class="btn-cancel" @click="modal.show = false">Annulla</button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { getPersone, getCategorie } from "../api/index.js"
import { getSchedeAllenamento, creaSchedaAllenamento, aggiornaSchedaAllenamento, eliminaSchedaAllenamento } from "../api/index.js"

const route = useRoute()
const router = useRouter()
const categoriaId = computed(() => parseInt(route.params.id))
const categoriaAttiva = ref(null)

async function loadCategoria() {
  if (categoriaAttiva.value) return
  try {
    const res = await getCategorie()
    const found = (res.data || []).find(c => c.id === categoriaId.value)
    if (found) categoriaAttiva.value = found
  } catch (e) {
    console.error('Errore caricamento categoria:', e)
  }
}

const oggi = new Date()
const dataSelezionata = ref(oggi.toISOString().split('T')[0])
const persone = ref([])
const schede = ref([])

const modal = ref({
  show: false,
  id: null,
  persona_id: null,
  data: dataSelezionata.value,
  distanza_totale: null,
  distanza_alta_velocita: null,
  distanza_sprint: null,
  velocita_massima: null,
  accelerazioni: null,
  decelerazioni: null,
  metabolic_power: null,
  player_load: null,
  calorie: null,
  tempo_lavoro: null,
  rpe: null,
  note: ''
})

function resetModal() {
  modal.value = {
    show: false,
    id: null,
    persona_id: null,
    data: dataSelezionata.value,
    distanza_totale: null,
    distanza_alta_velocita: null,
    distanza_sprint: null,
    velocita_massima: null,
    accelerazioni: null,
    decelerazioni: null,
    metabolic_power: null,
    player_load: null,
    calorie: null,
    tempo_lavoro: null,
    rpe: null,
    note: ''
  }
}

function apriModalNuovo() {
  modal.value.show = true
  modal.value.data = dataSelezionata.value
}

function apriModalEdit(scheda) {
  modal.value = {
    show: true,
    id: scheda.id,
    persona_id: scheda.persona_id,
    data: scheda.data,
    distanza_totale: scheda.distanza_totale,
    distanza_alta_velocita: scheda.distanza_alta_velocita,
    distanza_sprint: scheda.distanza_sprint,
    velocita_massima: scheda.velocita_massima,
    accelerazioni: scheda.accelerazioni,
    decelerazioni: scheda.decelerazioni,
    metabolic_power: scheda.metabolic_power,
    player_load: scheda.player_load,
    calorie: scheda.calorie,
    tempo_lavoro: scheda.tempo_lavoro,
    rpe: scheda.rpe,
    note: scheda.note || ''
  }
}

function rpeClass(rpe) {
  if (!rpe) return ''
  if (rpe <= 3) return 'rpe-low'
  if (rpe <= 6) return 'rpe-mid'
  return 'rpe-high'
}

async function loadPersone() {
  if (!categoriaId.value) return
  const res = await getPersone(categoriaId.value)
  persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
}

async function loadSchede() {
  if (!categoriaId.value || !dataSelezionata.value) return
  const res = await getSchedeAllenamento({
    categoria_id: categoriaId.value,
    data: dataSelezionata.value
  })
  const data = res.data
  const personaMap = Object.fromEntries(persone.value.map(p => [p.id, p]))
  schede.value = data.map(s => ({
    ...s,
    nome: personaMap[s.persona_id]?.nome || '',
    cognome: personaMap[s.persona_id]?.cognome || ''
  }))
}

async function salvaScheda() {
  if (!modal.value.persona_id || !modal.value.data) return
  const payload = {
    persona_id: modal.value.persona_id,
    categoria_id: categoriaId.value,
    data: modal.value.data,
    distanza_totale: modal.value.distanza_totale || null,
    distanza_alta_velocita: modal.value.distanza_alta_velocita || null,
    distanza_sprint: modal.value.distanza_sprint || null,
    velocita_massima: modal.value.velocita_massima || null,
    accelerazioni: modal.value.accelerazioni || null,
    decelerazioni: modal.value.decelerazioni || null,
    metabolic_power: modal.value.metabolic_power || null,
    player_load: modal.value.player_load || null,
    calorie: modal.value.calorie || null,
    tempo_lavoro: modal.value.tempo_lavoro || null,
    rpe: modal.value.rpe || null,
    note: modal.value.note || null
  }
  try {
    if (modal.value.id) {
      await aggiornaSchedaAllenamento(modal.value.id, payload)
    } else {
      await creaSchedaAllenamento(payload)
    }
    modal.value.show = false
    await loadSchede()
  } catch (e) {
    console.error('Errore salvataggio:', e)
  }
}

async function eliminaScheda(id) {
  if (!confirm('Eliminare questa scheda?')) return
  try {
    await eliminaSchedaAllenamento(id)
    await loadSchede()
  } catch (e) {
    console.error('Errore eliminazione:', e)
  }
}

watch(dataSelezionata, loadSchede)

onMounted(async () => {
  await loadCategoria()
  await loadPersone()
  await loadSchede()
})
</script>

<style scoped>
.scheda-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1600px;
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

.page-header {
  position: relative;
  z-index: 1;
  margin-bottom: 1.5rem;
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
.header-main { position: relative; }
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

.controls-row {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}
.date-picker-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 1.25rem;
  background: rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  color: var(--color-text);
  font-size: 0.875rem;
}
.date-input {
  background: transparent;
  border: none;
  color: var(--color-text);
  font-family: var(--font-mono);
  font-size: 0.875rem;
  outline: none;
  cursor: pointer;
}
.date-input::-webkit-calendar-picker-indicator {
  filter: invert(0.7);
  cursor: pointer;
}
.btn-add {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1.25rem;
  background: rgba(220, 38, 38, 0.15);
  border: 1px solid rgba(220, 38, 38, 0.3);
  border-radius: 100px;
  color: var(--color-primary);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}
.btn-add:hover {
  background: rgba(220, 38, 38, 0.25);
  border-color: rgba(220, 38, 38, 0.5);
}

.table-wrapper {
  position: relative;
  z-index: 1;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
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
  padding: 0.6rem 0.3rem;
  white-space: nowrap;
  color: var(--color-text);
}
tr:last-child td { border-bottom: none; }
th {
  background: rgba(255, 255, 255, 0.04);
  font-weight: 600;
  color: var(--color-text-secondary);
  position: sticky;
  top: 0;
  font-size: 0.75rem;
}
.th-num, .td-num { width: 40px; color: var(--color-text-muted); font-size: 0.75rem; }
.th-nome, .td-nome { text-align: left; min-width: 140px; padding-left: 1rem; }
.th-gps { min-width: 72px; }
.th-note { min-width: 100px; }
.th-actions { width: 70px; }
.td-nome .persona-name {
  font-weight: 500;
  color: var(--color-text);
}
.td-gps {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  color: var(--color-text-secondary);
}
.td-rpe {
  font-family: var(--font-mono);
  font-weight: 700;
  font-size: 0.8125rem;
}
.td-rpe.rpe-low { color: #4ade80; }
.td-rpe.rpe-mid { color: #fbbf24; }
.td-rpe.rpe-high { color: #f87171; }
.td-note {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  max-width: 160px;
  overflow: hidden;
  text-overflow: ellipsis;
}
.td-actions {
  display: flex;
  gap: 0.25rem;
  justify-content: center;
}
.btn-edit, .btn-delete {
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 4px;
  cursor: pointer;
  color: var(--color-text-secondary);
  transition: all var(--transition-fast);
  display: flex;
  align-items: center;
  justify-content: center;
}
.btn-edit:hover {
  background: rgba(59, 130, 246, 0.15);
  border-color: rgba(59, 130, 246, 0.3);
  color: #60a5fa;
}
.btn-delete:hover {
  background: rgba(220, 38, 38, 0.15);
  border-color: rgba(220, 38, 38, 0.3);
  color: #f87171;
}

.empty-state {
  text-align: center;
  padding: 4rem 2rem;
  color: var(--color-text-muted);
}
.empty-state svg {
  opacity: 0.3;
  margin-bottom: 1rem;
}
.empty-state p {
  margin-bottom: 1.5rem;
  font-size: 0.9375rem;
}
.btn-add-empty {
  padding: 0.6rem 1.5rem;
  background: rgba(220, 38, 38, 0.15);
  border: 1px solid rgba(220, 38, 38, 0.3);
  border-radius: 100px;
  color: var(--color-primary);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}
.btn-add-empty:hover {
  background: rgba(220, 38, 38, 0.25);
}

/* ── Modal ── */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  backdrop-filter: blur(8px);
}
@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.9) translateY(10px); }
  to { opacity: 1; transform: scale(1) translateY(0); }
}
.modal {
  background: rgba(30, 30, 30, 0.95);
  backdrop-filter: blur(20px);
  border: 1px solid var(--color-border);
  border-radius: 24px;
  width: 100%;
  box-shadow: 0 25px 60px rgba(0, 0, 0, 0.5);
  animation: scaleIn 0.3s ease-out;
  overflow: hidden;
}
.modal-scheda { max-width: 720px; max-height: 90vh; display: flex; flex-direction: column; }
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
}
.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}
.modal-close {
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: var(--color-text-secondary);
  transition: all var(--transition-fast);
}
.modal-close:hover {
  background: rgba(255, 255, 255, 0.1);
}
.modal-body {
  padding: 0 1.5rem 1.5rem;
  overflow-y: auto;
  flex: 1;
}
.form-section {
  margin-bottom: 1.25rem;
}
.form-label {
  display: block;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  margin-bottom: 0.5rem;
}
.form-select, .form-input, .form-textarea {
  width: 100%;
  padding: 0.625rem 0.875rem;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  color: var(--color-text);
  font-family: var(--font-sans);
  font-size: 0.875rem;
  outline: none;
  transition: border-color var(--transition-fast);
}
.form-select:focus, .form-input:focus, .form-textarea:focus {
  border-color: rgba(220, 38, 38, 0.5);
}
.form-textarea {
  resize: vertical;
}
.form-select option {
  background: #1a1a1a;
  color: var(--color-text);
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 1rem;
  margin-bottom: 1.25rem;
}
.metric-input {
  background: rgba(255, 255, 255, 0.02);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 0.75rem;
}
.metric-label {
  display: block;
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--color-text-muted);
  margin-bottom: 0.5rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.metric-field {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.metric-value {
  flex: 1;
  background: transparent;
  border: none;
  color: var(--color-text);
  font-family: var(--font-mono);
  font-size: 1rem;
  font-weight: 700;
  outline: none;
  min-width: 0;
}
.metric-unit {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  font-weight: 500;
  white-space: nowrap;
}

.modal-footer {
  display: flex;
  gap: 0.75rem;
  padding: 1rem 1.5rem 1.5rem;
  justify-content: flex-end;
}
.btn-save {
  padding: 0.625rem 1.5rem;
  background: var(--color-primary);
  border: none;
  border-radius: 10px;
  color: white;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}
.btn-save:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
.btn-save:not(:disabled):hover {
  opacity: 0.9;
  transform: translateY(-1px);
}
.btn-cancel {
  padding: 0.625rem 1.5rem;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}
.btn-cancel:hover {
  background: rgba(255, 255, 255, 0.08);
}

@media (max-width: 768px) {
  .scheda-page { padding: 1.5rem 1rem 3rem; }
  .controls-row { flex-wrap: wrap; }
  .metrics-grid { grid-template-columns: repeat(2, 1fr); }
}
</style>
