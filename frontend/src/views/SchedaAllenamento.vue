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
        <p class="header-subtitle">Dashboard GPS Allenamento</p>
      </div>
    </header>

    <div class="tab-bar">
      <button
        class="tab-btn"
        :class="{ active: tabAttiva === 'dashboard' }"
        @click="tabAttiva = 'dashboard'"
      >Dashboard</button>
      <button
        class="tab-btn"
        :class="{ active: tabAttiva === 'tabella' }"
        @click="tabAttiva = 'tabella'"
      >Tabella</button>
    </div>

    <div v-if="tabAttiva === 'dashboard'" class="dashboard-content">
      <div class="controls-row dashboard-controls">
        <div class="period-selector">
          <button
            v-for="p in periodi" :key="p.value"
            class="period-btn"
            :class="{ active: periodo === p.value }"
            @click="periodo = p.value"
          >{{ p.label }}</button>
        </div>
        <div class="view-toggle">
          <button
            class="toggle-btn"
            :class="{ active: vista === 'squadra' }"
            @click="vista = 'squadra'"
          >Squadra</button>
          <button
            class="toggle-btn"
            :class="{ active: vista === 'individuale' }"
            @click="vista = 'individuale'"
          >Individuale</button>
        </div>
        <select v-if="vista === 'individuale'" v-model="playerSelezionato" class="player-select">
          <option :value="null" disabled>Seleziona giocatore...</option>
          <option v-for="p in persone" :key="p.id" :value="p.id">
            {{ p.cognome }} {{ p.nome }}
          </option>
        </select>
        <select v-model="metricaSelezionata" class="metric-select">
          <option v-for="m in metriche" :key="m.key" :value="m.key">{{ m.label }} ({{ m.unit }})</option>
        </select>
      </div>

      <div class="summary-cards">
        <div v-for="(val, key) in summaryData" :key="key" class="summary-card">
          <div class="card-label">{{ getMetricLabel(key) }}</div>
          <div class="card-value">{{ formatSummaryValue(key, val) }}</div>
          <div class="card-meta">{{ val.sessions || 0 }} session{{ (val.sessions || 0) !== 1 ? 'i' : 'e' }}</div>
        </div>
      </div>

      <div class="charts-grid">
        <div class="chart-card">
          <div class="chart-title">
            <span>Trend {{ getMetricLabel(metricaSelezionata) }}</span>
            <span class="chart-subtitle">Media per sessione</span>
          </div>
          <div class="chart-container">
            <canvas ref="trendChart"></canvas>
          </div>
        </div>

        <div class="chart-card">
          <div class="chart-title">
            <span>Classifica Squadra</span>
            <span class="chart-subtitle">{{ getMetricLabel(metricaSelezionata) }}</span>
          </div>
          <div class="chart-container">
            <canvas ref="teamChart"></canvas>
          </div>
        </div>

        <div v-if="vista === 'individuale' && playerSelezionato" class="chart-card chart-full">
          <div class="chart-title">
            <span>Analisi Completa Giocatore</span>
            <span class="chart-subtitle">{{ getPlayerName(playerSelezionato) }}</span>
          </div>
          <div class="chart-container">
            <canvas ref="playerChart"></canvas>
          </div>
        </div>
      </div>
    </div>

    <div v-if="tabAttiva === 'tabella'" class="tabella-content">
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
                <label class="metric-label">Alta Velocit\u00e0 (&gt;19.8km/h)</label>
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
                <label class="metric-label">Accelerazioni (&gt;3m/s\u00b2)</label>
                <div class="metric-field">
                  <input type="number" v-model.number="modal.accelerazioni" placeholder="0" class="metric-value" />
                  <span class="metric-unit">n.</span>
                </div>
              </div>
              <div class="metric-input">
                <label class="metric-label">Decelerazioni (&gt;3m/s\u00b2)</label>
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
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from "vue"
import { useRoute, useRouter } from "vue-router"
import Chart from 'chart.js/auto'
import {
  getPersone, getCategorie,
  getSchedeAllenamento, creaSchedaAllenamento, aggiornaSchedaAllenamento, eliminaSchedaAllenamento,
  getSchedeTrend, getSchedeSummary, getSchedeTeam, getSchedePlayerTrend
} from "../api/index.js"

const route = useRoute()
const router = useRouter()
const categoriaId = computed(() => parseInt(route.params.id))
const categoriaAttiva = ref(null)

const tabAttiva = ref('dashboard')
const periodo = ref('settimana')
const vista = ref('squadra')
const playerSelezionato = ref(null)
const metricaSelezionata = ref('distanza_totale')

const periodi = [
  { value: 'settimana', label: 'Settimana' },
  { value: 'mese', label: 'Mese' },
  { value: 'stagione', label: 'Stagione' }
]

const metriche = [
  { key: 'distanza_totale', label: 'Distanza Totale', unit: 'm' },
  { key: 'distanza_alta_velocita', label: 'Alta Velocit\u00e0', unit: 'm' },
  { key: 'distanza_sprint', label: 'Sprint', unit: 'm' },
  { key: 'velocita_massima', label: 'Vel. Max', unit: 'km/h' },
  { key: 'accelerazioni', label: 'Accelerazioni', unit: 'n.' },
  { key: 'decelerazioni', label: 'Decelerazioni', unit: 'n.' },
  { key: 'metabolic_power', label: 'Met. Power', unit: 'W/kg' },
  { key: 'player_load', label: 'PlayerLoad', unit: 'PL' },
  { key: 'calorie', label: 'Calorie', unit: 'kcal' },
  { key: 'tempo_lavoro', label: 'Tempo', unit: 'min' },
  { key: 'rpe', label: 'RPE', unit: '/10' }
]

const getMetricLabel = (key) => {
  const m = metriche.find(m => m.key === key)
  return m ? m.label : key
}

const getMetricUnit = (key) => {
  const m = metriche.find(m => m.key === key)
  return m ? m.unit : ''
}

const formatValue = (key, val) => {
  if (val == null) return '-'
  const unit = getMetricUnit(key)
  if (['velocita_massima', 'metabolic_power'].includes(key)) return val.toFixed(1) + ' ' + unit
  if (key === 'rpe') return val + ' /10'
  if (['accelerazioni', 'decelerazioni', 'player_load'].includes(key)) return val.toFixed(0) + ' ' + unit
  return val.toFixed(0) + ' ' + unit
}

const formatSummaryValue = (key, val) => {
  if (!val) return '-'
  const avg = val.avg != null ? val.avg : 0
  return formatValue(key, avg)
}

const oggi = new Date()
const dataSelezionata = ref(oggi.toISOString().split('T')[0])
const persone = ref([])
const schede = ref([])

const summaryData = ref({})
const trendData = ref([])
const teamData = ref([])
const playerTrendData = ref([])

const trendChartRef = ref(null)
const teamChartRef = ref(null)
const playerChartRef = ref(null)

let trendChartInstance = null
let teamChartInstance = null
let playerChartInstance = null

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

function getPlayerName(id) {
  const p = persone.value.find(p => p.id === id)
  return p ? `${p.cognome} ${p.nome}` : ''
}

const chartColors = {
  primary: '#dc2626',
  primaryAlpha: 'rgba(220, 38, 38, 0.15)',
  secondary: '#7c3aed',
  secondaryAlpha: 'rgba(124, 58, 237, 0.15)',
  accent: '#3b82f6',
  accentAlpha: 'rgba(59, 130, 246, 0.15)',
  green: '#4ade80',
  greenAlpha: 'rgba(74, 222, 128, 0.15)',
  yellow: '#fbbf24',
  yellowAlpha: 'rgba(251, 191, 36, 0.15)',
  grid: 'rgba(255, 255, 255, 0.06)',
  text: '#aaaaaa',
  textMuted: '#666666'
}

const playerMetricColors = [
  chartColors.primary,
  chartColors.secondary,
  chartColors.accent,
  chartColors.green,
  chartColors.yellow,
  '#f97316',
  '#ec4899',
  '#14b8a6',
  '#a855f7',
  '#06b6d4',
  '#84cc16'
]

const playerMetricsKeys = [
  'distanza_totale',
  'distanza_alta_velocita',
  'distanza_sprint',
  'velocita_massima',
  'accelerazioni',
  'decelerazioni',
  'metabolic_power',
  'player_load',
  'calorie',
  'tempo_lavoro',
  'rpe'
]

function getChartDefaults() {
  return {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        labels: {
          color: chartColors.text,
          font: { size: 11, family: "'Inter', sans-serif" }
        }
      }
    },
    scales: {
      x: {
        grid: { color: chartColors.grid },
        ticks: { color: chartColors.textMuted, font: { size: 10 } }
      },
      y: {
        grid: { color: chartColors.grid },
        ticks: { color: chartColors.textMuted, font: { size: 10 } }
      }
    }
  }
}

function destroyChart(instance) {
  if (instance) {
    instance.destroy()
    return null
  }
  return null
}

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

async function loadSummary() {
  if (!categoriaId.value) return
  try {
    const params = { categoria_id: categoriaId.value, period: periodo.value }
    if (vista.value === 'individuale' && playerSelezionato.value) {
      params.persona_id = playerSelezionato.value
    }
    const res = await getSchedeSummary(params)
    summaryData.value = res.data || {}
  } catch (e) {
    console.error('Errore caricamento summary:', e)
  }
}

async function loadTrend() {
  if (!categoriaId.value) return
  try {
    const params = {
      categoria_id: categoriaId.value,
      period: periodo.value,
      metric: metricaSelezionata.value
    }
    if (vista.value === 'individuale' && playerSelezionato.value) {
      params.persona_id = playerSelezionato.value
    }
    const res = await getSchedeTrend(params)
    trendData.value = res.data || []
    renderTrendChart()
  } catch (e) {
    console.error('Errore caricamento trend:', e)
  }
}

async function loadTeam() {
  if (!categoriaId.value) return
  try {
    const res = await getSchedeTeam({
      categoria_id: categoriaId.value,
      period: periodo.value,
      metric: metricaSelezionata.value
    })
    teamData.value = res.data || []
    renderTeamChart()
  } catch (e) {
    console.error('Errore caricamento team:', e)
  }
}

async function loadPlayerTrend() {
  if (!categoriaId.value || !playerSelezionato.value) return
  try {
    const res = await getSchedePlayerTrend({
      categoria_id: categoriaId.value,
      persona_id: playerSelezionato.value,
      period: periodo.value
    })
    playerTrendData.value = res.data || []
    renderPlayerChart()
  } catch (e) {
    console.error('Errore caricamento player trend:', e)
  }
}

function renderTrendChart() {
  if (!trendChartRef.value) return
  trendChartInstance = destroyChart(trendChartInstance)

  const labels = trendData.value.map(d => {
    const date = new Date(d.period)
    return date.toLocaleDateString('it-IT', { day: '2-digit', month: 'short' })
  })
  const values = trendData.value.map(d => d.avg != null ? parseFloat(d.avg) : null)

  trendChartInstance = new Chart(trendChartRef.value, {
    type: 'line',
    data: {
      labels,
      datasets: [{
        label: getMetricLabel(metricaSelezionata.value),
        data: values,
        borderColor: chartColors.primary,
        backgroundColor: chartColors.primaryAlpha,
        fill: true,
        tension: 0.4,
        pointRadius: 4,
        pointHoverRadius: 6,
        pointBackgroundColor: chartColors.primary,
        pointBorderColor: 'transparent',
        borderWidth: 2.5,
        spanGaps: true
      }]
    },
    options: {
      ...getChartDefaults(),
      plugins: {
        ...getChartDefaults().plugins,
        legend: { display: false },
        tooltip: {
          backgroundColor: 'rgba(30, 30, 30, 0.95)',
          borderColor: 'rgba(255, 255, 255, 0.1)',
          borderWidth: 1,
          titleColor: '#ffffff',
          bodyColor: '#aaaaaa',
          padding: 10,
          cornerRadius: 8,
          callbacks: {
            label: (ctx) => {
              const val = ctx.parsed.y
              return val != null ? `${getMetricLabel(metricaSelezionata.value)}: ${formatValue(metricaSelezionata.value, val)}` : 'N/D'
            }
          }
        }
      }
    }
  })
}

function renderTeamChart() {
  if (!teamChartRef.value) return
  teamChartInstance = destroyChart(teamChartInstance)

  const sorted = [...teamData.value].sort((a, b) => (b.avg || 0) - (a.avg || 0))
  const labels = sorted.map(d => `${d.cognome} ${d.nome}`)
  const values = sorted.map(d => d.avg != null ? parseFloat(d.avg) : 0)
  const sessions = sorted.map(d => d.sessions || 0)

  const bgColors = values.map((_, i) => {
    if (i === 0) return chartColors.primary
    if (i === 1) return chartColors.secondary
    if (i === 2) return chartColors.accent
    return chartColors.textMuted
  })

  teamChartInstance = new Chart(teamChartRef.value, {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: getMetricLabel(metricaSelezionata.value),
        data: values,
        backgroundColor: bgColors.map(c => c + '33'),
        borderColor: bgColors,
        borderWidth: 1.5,
        borderRadius: 4,
        barThickness: 20
      }]
    },
    options: {
      indexAxis: 'y',
      ...getChartDefaults(),
      plugins: {
        ...getChartDefaults().plugins,
        legend: { display: false },
        tooltip: {
          backgroundColor: 'rgba(30, 30, 30, 0.95)',
          borderColor: 'rgba(255, 255, 255, 0.1)',
          borderWidth: 1,
          titleColor: '#ffffff',
          bodyColor: '#aaaaaa',
          padding: 10,
          cornerRadius: 8,
          callbacks: {
            label: (ctx) => {
              const idx = ctx.dataIndex
              const entry = sorted[idx]
              return [
                `${getMetricLabel(metricaSelezionata.value)}: ${formatValue(metricaSelezionata.value, entry.avg)}`,
                `Max: ${formatValue(metricaSelezionata.value, entry.max)}`,
                `Sessioni: ${sessions[idx]}`
              ]
            }
          }
        }
      },
      scales: {
        x: {
          grid: { color: chartColors.grid },
          ticks: { color: chartColors.textMuted, font: { size: 10 } }
        },
        y: {
          grid: { display: false },
          ticks: { color: chartColors.text, font: { size: 11 } }
        }
      }
    }
  })
}

function renderPlayerChart() {
  if (!playerChartRef.value) return
  playerChartInstance = destroyChart(playerChartInstance)

  if (playerTrendData.value.length === 0) return

  const labels = playerTrendData.value.map(d => {
    const date = new Date(d.data)
    return date.toLocaleDateString('it-IT', { day: '2-digit', month: 'short' })
  })

  const datasets = playerMetricsKeys.map((key, i) => ({
    label: getMetricLabel(key),
    data: playerTrendData.value.map(d => d[key] != null ? parseFloat(d[key]) : null),
    borderColor: playerMetricColors[i],
    backgroundColor: playerMetricColors[i] + '15',
    fill: false,
    tension: 0.4,
    pointRadius: 3,
    pointHoverRadius: 5,
    borderWidth: 2,
    spanGaps: true
  }))

  playerChartInstance = new Chart(playerChartRef.value, {
    type: 'line',
    data: { labels, datasets },
    options: {
      ...getChartDefaults(),
      interaction: {
        mode: 'index',
        intersect: false
      },
      plugins: {
        ...getChartDefaults().plugins,
        legend: {
          ...getChartDefaults().plugins.legend,
          position: 'bottom',
          labels: {
            ...getChartDefaults().plugins.legend.labels,
            boxWidth: 12,
            padding: 12,
            usePointStyle: true,
            pointStyle: 'circle'
          }
        },
        tooltip: {
          backgroundColor: 'rgba(30, 30, 30, 0.95)',
          borderColor: 'rgba(255, 255, 255, 0.1)',
          borderWidth: 1,
          titleColor: '#ffffff',
          bodyColor: '#aaaaaa',
          padding: 10,
          cornerRadius: 8,
          filter: (item) => item.parsed.y != null
        }
      }
    }
  })
}

async function loadDashboardData() {
  await Promise.all([
    loadSummary(),
    loadTrend(),
    loadTeam()
  ])
  if (vista.value === 'individuale' && playerSelezionato.value) {
    await loadPlayerTrend()
  } else {
    playerChartInstance = destroyChart(playerChartInstance)
    playerTrendData.value = []
  }
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
    await loadDashboardData()
  } catch (e) {
    console.error('Errore salvataggio:', e)
  }
}

async function eliminaScheda(id) {
  if (!confirm('Eliminare questa scheda?')) return
  try {
    await eliminaSchedaAllenamento(id)
    await loadSchede()
    await loadDashboardData()
  } catch (e) {
    console.error('Errore eliminazione:', e)
  }
}

watch(dataSelezionata, loadSchede)
watch(periodo, loadDashboardData)
watch(metricaSelezionata, loadDashboardData)
watch(vista, () => {
  if (vista.value === 'individuale' && !playerSelezionato.value && persone.value.length > 0) {
    playerSelezionato.value = persone.value[0].id
  }
  loadDashboardData()
})
watch(playerSelezionato, () => {
  if (vista.value === 'individuale') {
    loadDashboardData()
  }
})

onMounted(async () => {
  await loadCategoria()
  await loadPersone()
  await loadSchede()
  await nextTick()
  await loadDashboardData()
})

onUnmounted(() => {
  destroyChart(trendChartInstance)
  destroyChart(teamChartInstance)
  destroyChart(playerChartInstance)
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
  margin-bottom: 1rem;
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

/* ── Tab Bar ── */
.tab-bar {
  position: relative;
  z-index: 1;
  display: flex;
  gap: 0.25rem;
  margin-bottom: 1.5rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 4px;
  width: fit-content;
}
.tab-btn {
  padding: 0.5rem 1.5rem;
  background: transparent;
  border: none;
  border-radius: 8px;
  color: var(--color-text-muted);
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}
.tab-btn:hover {
  color: var(--color-text-secondary);
}
.tab-btn.active {
  background: rgba(220, 38, 38, 0.15);
  color: var(--color-primary);
}

/* ── Dashboard Controls ── */
.dashboard-content {
  position: relative;
  z-index: 1;
}
.dashboard-controls {
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}
.period-selector {
  display: flex;
  gap: 0.25rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  padding: 3px;
}
.period-btn {
  padding: 0.4rem 1rem;
  background: transparent;
  border: none;
  border-radius: 8px;
  color: var(--color-text-muted);
  font-family: var(--font-sans);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}
.period-btn:hover {
  color: var(--color-text-secondary);
}
.period-btn.active {
  background: rgba(220, 38, 38, 0.15);
  color: var(--color-primary);
}
.view-toggle {
  display: flex;
  gap: 0.25rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  padding: 3px;
}
.toggle-btn {
  padding: 0.4rem 1rem;
  background: transparent;
  border: none;
  border-radius: 8px;
  color: var(--color-text-muted);
  font-family: var(--font-sans);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}
.toggle-btn:hover {
  color: var(--color-text-secondary);
}
.toggle-btn.active {
  background: rgba(124, 58, 237, 0.15);
  color: #a78bfa;
}
.player-select, .metric-select {
  padding: 0.45rem 0.875rem;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  color: var(--color-text);
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  outline: none;
  cursor: pointer;
  transition: border-color var(--transition-fast);
}
.player-select:focus, .metric-select:focus {
  border-color: rgba(220, 38, 38, 0.5);
}
.player-select option, .metric-select option {
  background: #1a1a1a;
  color: var(--color-text);
}

/* ── Summary Cards ── */
.summary-cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}
.summary-card {
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 14px;
  padding: 1rem;
  transition: all var(--transition-fast);
}
.summary-card:hover {
  background: rgba(255, 255, 255, 0.05);
  border-color: rgba(255, 255, 255, 0.12);
}
.card-label {
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin-bottom: 0.5rem;
}
.card-value {
  font-family: var(--font-mono);
  font-size: 1.375rem;
  font-weight: 700;
  color: var(--color-text);
  line-height: 1.1;
  margin-bottom: 0.25rem;
}
.card-meta {
  font-size: 0.6875rem;
  color: var(--color-text-muted);
}

/* ── Charts ── */
.charts-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}
.chart-card {
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 1.25rem;
}
.chart-full {
  grid-column: 1 / -1;
}
.chart-title {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 1rem;
}
.chart-title span:first-child {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text);
}
.chart-subtitle {
  font-size: 0.6875rem !important;
  color: var(--color-text-muted);
  font-weight: 500;
}
.chart-container {
  position: relative;
  height: 280px;
}
.chart-full .chart-container {
  height: 320px;
}

/* ── Table (Tabella tab) ── */
.tabella-content {
  position: relative;
  z-index: 1;
}
.controls-row {
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

@media (max-width: 1024px) {
  .charts-grid {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 768px) {
  .scheda-page { padding: 1.5rem 1rem 3rem; }
  .controls-row { flex-wrap: wrap; }
  .dashboard-controls { flex-direction: column; align-items: stretch; }
  .metrics-grid { grid-template-columns: repeat(2, 1fr); }
  .summary-cards { grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); }
}
</style>
