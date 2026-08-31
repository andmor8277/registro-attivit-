<template>
  <div class="report-indiv-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="goBack">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          Indietro
        </button>
      </div>
      <div class="header-main">
        <h1 class="category-name">
          <span class="name-gradient">{{ categoriaAttiva?.nome }}</span>
        </h1>
        <p class="header-subtitle">Report Individuale</p>
      </div>
    </header>

    <!-- Player selector -->
    <div class="player-selector">
      <label class="selector-label">Seleziona Giocatore</label>
      <select v-model="selectedPlayerId" class="selector-dropdown" @change="onPlayerChange">
        <option value="">-- Scegli giocatore --</option>
        <option v-for="p in giocatori" :key="p.id" :value="p.id">{{ p.cognome }} {{ p.nome }}</option>
      </select>
    </div>

    <div v-if="!selectedPlayerId" class="empty-hint">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="48" height="48">
        <circle cx="12" cy="7" r="4"/><path d="M5.5 21c0-4.5 3-6.5 6.5-6.5s6.5 2 6.5 6.5"/>
      </svg>
      <p>Seleziona un giocatore per visualizzare il report</p>
    </div>

    <div v-else class="report-content">
      <!-- Player header -->
      <div class="player-header">
        <div class="player-avatar">{{ selectedPlayer?.cognome?.charAt(0) || '?' }}</div>
        <div class="player-info">
          <h2 class="player-name">{{ selectedPlayer?.cognome }} {{ selectedPlayer?.nome }}</h2>
          <p class="player-meta">{{ selectedPlayer?.matricola ? 'Matricola: ' + selectedPlayer.matricola : '' }}</p>
        </div>
      </div>

      <!-- Seasonal summary cards -->
      <div class="summary-cards">
        <div class="summary-card card-presenze">
          <div class="card-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24">
              <polyline points="20 6 9 17 4 12"/>
            </svg>
          </div>
          <div class="card-value">{{ stats.presenze }}</div>
          <div class="card-label">Presenze</div>
        </div>
        <div class="summary-card card-assenze">
          <div class="card-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24">
              <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </div>
          <div class="card-value">{{ stats.assenze }}</div>
          <div class="card-label">Assenze</div>
        </div>
        <div class="summary-card card-doppie">
          <div class="card-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24">
              <path d="M8 7V3m8 4V3"/><path d="M4 21l16-16"/>
            </svg>
          </div>
          <div class="card-value">{{ stats.doppie }}</div>
          <div class="card-label">Doppie</div>
        </div>
        <div class="summary-card card-weekend">
          <div class="card-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24">
              <circle cx="12" cy="12" r="10"/><path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/>
            </svg>
          </div>
          <div class="card-value">{{ stats.weekendMancati }}</div>
          <div class="card-label">Weekend Mancati</div>
        </div>
      </div>

      <!-- Monthly breakdown -->
      <div class="section-block">
        <h3 class="section-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
          </svg>
          Dettaglio Mensile
        </h3>
        <div class="table-glass">
          <table class="report-table">
            <thead>
              <tr>
                <th>Mese</th>
                <th>Allenamenti</th>
                <th>Presenze</th>
                <th>Assenze</th>
                <th>% Presenza</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in monthlyData" :key="m.mese">
                <td>{{ m.mese }}</td>
                <td>{{ m.totali }}</td>
                <td class="cell-ok">{{ m.presenze }}</td>
                <td class="cell-danger">{{ m.assenze }}</td>
                <td class="cell-pct">{{ m.percentuale }}%</td>
              </tr>
              <tr v-if="monthlyData.length === 0">
                <td colspan="5" class="no-data">Nessun dato disponibile</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Doppie -->
      <div class="section-block">
        <h3 class="section-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <path d="M8 7V3m8 4V3"/><path d="M4 21l16-16"/>
          </svg>
          Doppie Convocazioni
        </h3>
        <div class="table-glass">
          <table class="report-table">
            <thead>
              <tr>
                <th>Data</th>
                <th>Gare</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="d in playerDoppie" :key="d.key">
                <td>{{ d.data }}</td>
                <td class="cell-warning">{{ d.numGare }}</td>
              </tr>
              <tr v-if="playerDoppie.length === 0">
                <td colspan="2" class="no-data">Nessuna doppia convocazione</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Weekend absences -->
      <div class="section-block">
        <h3 class="section-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <circle cx="12" cy="12" r="10"/><path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/>
          </svg>
          Partite Weekend
        </h3>
        <div class="table-glass">
          <table class="report-table">
            <thead>
              <tr>
                <th>Data</th>
                <th>Partita</th>
                <th>Stato</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="w in playerWeekend" :key="w.key">
                <td>{{ w.data }}</td>
                <td>{{ w.gara }}</td>
                <td :class="w.convocato ? 'cell-ok' : 'cell-danger'">
                  {{ w.convocato ? (w.non_presente ? 'Convocato (non presente)' : 'Convocato') : 'Non convocato' }}
                </td>
              </tr>
              <tr v-if="playerWeekend.length === 0">
                <td colspan="3" class="no-data">Nessuna partita weekend registrata</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, getRegistroMese, getConvocazioni, getConvocazione } from '../api/index.js'

const router = useRouter()
const route = useRoute()
const { societaAttiva, categoriaAttiva } = useStore()
const categoriaId = parseInt(route.params.id)

const giocatori = ref([])
const selectedPlayerId = ref('')
const mesi = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre']

const stats = ref({ presenze: 0, assenze: 0, doppie: 0, weekendMancati: 0 })
const monthlyData = ref([])
const playerDoppie = ref([])
const playerWeekend = ref([])

const selectedPlayer = computed(() => giocatori.value.find(p => p.id === selectedPlayerId.value))

function goBack() {
  router.push('/scelta/' + route.params.id)
}

function formatData(d) {
  if (!d) return '-'
  return d.split('-').reverse().join('/')
}

async function onPlayerChange() {
  if (!selectedPlayerId.value) {
    stats.value = { presenze: 0, assenze: 0, doppie: 0, weekendMancati: 0 }
    monthlyData.value = []
    playerDoppie.value = []
    playerWeekend.value = []
    return
  }
  await Promise.all([
    calcolaStatsStagionali(),
    calcolaDoppie(),
    calcolaWeekend()
  ])
}

async function calcolaStatsStagionali() {
  const cat = categoriaAttiva.value
  const dataInizio = cat?.data_inizio_stagione || new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0]
  const dataFine = cat?.data_fine_stagione || new Date().toISOString().split('T')[0]
  const pid = selectedPlayerId.value

  const monthly = []
  const start = new Date(dataInizio)
  const end = new Date(dataFine)
  const current = new Date(start.getFullYear(), start.getMonth(), 1)

  let totalPresenze = 0
  let totalAssenze = 0

  while (current <= end) {
    const anno = current.getFullYear()
    const mese = current.getMonth() + 1

    try {
      const regRes = await getRegistroMese(categoriaId, anno, mese)
      const entries = regRes.data || []
      const giorni = new Set()
      let presenze = 0
      let assenze = 0

      for (const e of entries) {
        if (!e.data || e.data < dataInizio || e.data > dataFine) continue
        if (e.persona_id !== pid) continue
        giorni.add(e.data)
        if (e.codice === 'AG' || e.codice === 'AI' || e.codice === 'I') {
          assenze++
        } else {
          presenze++
        }
      }

      const totali = giorni.size
      monthly.push({
        mese: mesi[mese - 1] + ' ' + anno,
        totali,
        presenze,
        assenze,
        percentuale: totali > 0 ? Math.round((presenze / totali) * 100) : 0
      })

      totalPresenze += presenze
      totalAssenze += assenze
    } catch (e) {}

    current.setMonth(current.getMonth() + 1)
  }

  monthlyData.value = monthly
  stats.value.presenze = totalPresenze
  stats.value.assenze = totalAssenze
}

async function calcolaDoppie() {
  const pid = selectedPlayerId.value
  try {
    const convRes = await getConvocazioni(categoriaId)
    const convsList = convRes.data || []

    const dataMap = new Map()

    for (const conv of convsList) {
      try {
        const convDetailRes = await getConvocazione(conv.id)
        const convDetail = convDetailRes.data
        if (!convDetail) continue

        for (const gara of convDetail.gare || []) {
          const dataGara = gara.data
          if (!dataGara) continue
          if (!dataMap.has(dataGara)) dataMap.set(dataGara, 0)
          for (const g of gara.giocatori || []) {
            if (g.persona_id === pid) {
              dataMap.set(dataGara, dataMap.get(dataGara) + 1)
            }
          }
        }
      } catch (e) {}
    }

    const result = []
    for (const [data, count] of dataMap) {
      if (count >= 2) {
        result.push({ key: data, data: formatData(data), numGare: count })
      }
    }
    playerDoppie.value = result.sort((a, b) => a.data.localeCompare(b.data))
    stats.value.doppie = result.length
  } catch (e) {}
}

async function calcolaWeekend() {
  const pid = selectedPlayerId.value
  try {
    const convRes = await getConvocazioni(categoriaId)
    const convsList = convRes.data || []

    const allGare = []

    for (const conv of convsList) {
      try {
        const convDetailRes = await getConvocazione(conv.id)
        const convDetail = convDetailRes.data
        if (!convDetail) continue

        for (const gara of convDetail.gare || []) {
          if (!gara.data) continue
          const giorno = new Date(gara.data).getDay()
          if (giorno !== 0 && giorno !== 6) continue

          const convocato = (gara.giocatori || []).some(g => g.persona_id === pid)
          const nonPresente = (gara.giocatori || []).find(g => g.persona_id === pid)?.non_presente

          allGare.push({
            key: gara.data + '_' + gara.gara,
            data: formatData(gara.data),
            gara: gara.gara || 'Partita',
            convocato,
            non_presente: nonPresente || false
          })
        }
      } catch (e) {}
    }

    playerWeekend.value = allGare.sort((a, b) => a.data.localeCompare(b.data))
    stats.value.weekendMancati = allGare.filter(g => !g.convocato).length
  } catch (e) {}
}

onMounted(async () => {
  try {
    const res = await getPersone(categoriaId)
    const arr = Array.isArray(res) ? res : (res?.data || [])
    giocatori.value = arr.sort((a, b) => a.cognome.localeCompare(b.cognome))
  } catch (e) {
    console.error('Errore caricamento giocatori:', e)
  }
})
</script>

<style scoped>
.report-indiv-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1100px;
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
  width: 500px; height: 500px;
  top: -150px; right: -80px;
  background: radial-gradient(circle, rgba(168, 85, 247, 0.08) 0%, transparent 70%);
}
.bg-glow-2 {
  width: 400px; height: 400px;
  bottom: -100px; left: -60px;
  background: radial-gradient(circle, rgba(59, 130, 246, 0.06) 0%, transparent 70%);
}

.page-header {
  position: relative;
  z-index: 1;
  margin-bottom: 2rem;
}
.header-top {
  display: flex;
  margin-bottom: 1rem;
}
.btn-back-pill {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  padding: 6px 14px;
  color: var(--color-text-secondary);
  cursor: pointer;
  font-size: 0.85rem;
  transition: all 0.2s;
}
.btn-back-pill:hover {
  background: var(--color-slate-soft);
  color: var(--color-text);
}
.header-main {
  margin-top: 0.5rem;
}
.category-name {
  font-size: 1.8rem;
  font-weight: 700;
  margin: 0;
}
.name-gradient {
  background: linear-gradient(135deg, #a855f7, #3b82f6);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.header-subtitle {
  color: var(--color-text-muted);
  margin: 4px 0 0;
  font-size: 0.95rem;
}

/* Player selector */
.player-selector {
  position: relative;
  z-index: 1;
  margin-bottom: 2rem;
}
.selector-label {
  display: block;
  font-size: 0.85rem;
  color: var(--color-text-secondary);
  margin-bottom: 8px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.selector-dropdown {
  width: 100%;
  max-width: 400px;
  padding: 12px 16px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  color: var(--color-text);
  font-size: 1rem;
  outline: none;
  cursor: pointer;
  transition: border-color 0.2s;
}
.selector-dropdown:focus {
  border-color: rgba(168, 85, 247, 0.5);
}
.selector-dropdown option {
  background: var(--color-surface);
  color: var(--color-text);
}

/* Empty hint */
.empty-hint {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 40vh;
  color: var(--color-text-faint);
  gap: 1rem;
}
.empty-hint p {
  font-size: 1.1rem;
}

/* Report content */
.report-content {
  position: relative;
  z-index: 1;
}

/* Player header */
.player-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 2rem;
  padding: 1.5rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
}
.player-avatar {
  width: 56px; height: 56px;
  border-radius: 50%;
  background: linear-gradient(135deg, #a855f7, #3b82f6);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.4rem;
  font-weight: 700;
  color: #fff;
  flex-shrink: 0;
}
.player-name {
  font-size: 1.4rem;
  font-weight: 600;
  margin: 0;
  color: var(--color-text);
}
.player-meta {
  color: var(--color-text-muted);
  margin: 4px 0 0;
  font-size: 0.9rem;
}

/* Summary cards */
.summary-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}
.summary-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 1.2rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  transition: transform 0.2s, border-color 0.2s;
}
.summary-card:hover {
  transform: translateY(-2px);
  border-color: var(--color-border-strong);
}
.card-icon {
  width: 44px; height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.card-presenze .card-icon { background: rgba(34,197,94,0.15); color: #22c55e; }
.card-assenze .card-icon { background: rgba(239,68,68,0.15); color: #ef4444; }
.card-doppie .card-icon { background: rgba(245,158,11,0.15); color: #f59e0b; }
.card-weekend .card-icon { background: rgba(168,85,247,0.15); color: #a855f7; }
.card-value {
  font-size: 2rem;
  font-weight: 700;
  color: var(--color-text);
}
.card-label {
  font-size: 0.8rem;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* Section blocks */
.section-block {
  margin-bottom: 2rem;
}
.section-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 1.1rem;
  font-weight: 600;
  color: var(--color-text);
  margin-bottom: 1rem;
}
.section-title svg {
  color: rgba(168, 85, 247, 0.7);
}

/* Table */
.table-glass {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  overflow: hidden;
}
.report-table {
  width: 100%;
  border-collapse: collapse;
}
.report-table th {
  text-align: left;
  padding: 14px 16px;
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--color-text-muted);
  border-bottom: 1px solid var(--color-border);
}
.report-table td {
  padding: 12px 16px;
  font-size: 0.95rem;
  color: var(--color-text);
  border-bottom: 1px solid var(--color-border);
}
.report-table tbody tr:last-child td {
  border-bottom: none;
}
.report-table .no-data {
  text-align: center;
  color: var(--color-text-faint);
  padding: 2rem !important;
}
.cell-ok { color: #22c55e; font-weight: 600; }
.cell-danger { color: #ef4444; font-weight: 600; }
.cell-warning { color: #f59e0b; font-weight: 600; }
.cell-pct { color: var(--color-text-secondary); font-weight: 500; }

@media (max-width: 768px) {
  .report-indiv-page { padding: 1rem; }
  .summary-cards { grid-template-columns: repeat(2, 1fr); }
  .report-table { font-size: 0.85rem; }
  .report-table th, .report-table td { padding: 10px 12px; }
}
</style>