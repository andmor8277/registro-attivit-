<template>
  <div class="reportistica-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="goBack">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          {{ activeReport ? 'Torna ai report' : 'Indietro' }}
        </button>
      </div>
      <div class="header-main">
        <h1 class="category-name">
          <span class="name-gradient">{{ categoriaAttiva?.nome }}</span>
        </h1>
        <p class="header-subtitle">{{ activeReport ? reportMeta[activeReport].title : 'Reportistica' }}</p>
      </div>
    </header>

    <!-- Landing: report cards -->
    <div v-if="!activeReport" class="report-landing">
      <div class="report-grid">
        <div
          v-for="report in availableReports"
          :key="report.key"
          class="report-card"
          :class="report.cardClass"
          @click="activeReport = report.key"
        >
          <div class="report-icon-wrap">
            <svg v-if="report.key === 'mensile'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
              <line x1="16" y1="2" x2="16" y2="6"/>
              <line x1="8" y1="2" x2="8" y2="6"/>
              <line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
            <svg v-if="report.key === 'annuale'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <line x1="18" y1="20" x2="18" y2="10"/>
              <line x1="12" y1="20" x2="12" y2="4"/>
              <line x1="6" y1="20" x2="6" y2="14"/>
            </svg>
            <svg v-if="report.key === 'doppie'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M8 7V3m8 4V3"/>
              <path d="M4 21l16-16"/>
              <path d="M4 11l3-3"/>
              <path d="M20 7l-3-3"/>
            </svg>
          </div>
          <div class="report-label">{{ report.title }}</div>
          <div class="report-desc">{{ report.desc }}</div>
          <div class="report-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>
      </div>
    </div>

    <!-- Print-only header -->
    <div v-if="activeReport" class="print-header-only">
      <div class="print-societa-row">
        <img v-if="societaAttiva?.logo" :src="`/uploads/${societaAttiva.logo}`" alt="Logo" class="print-logo" />
        <div class="print-societa-info">
          <div class="print-societa-name">{{ societaAttiva?.nome || '' }}</div>
          <div class="print-report-type">{{ reportMeta[activeReport].title }}</div>
        </div>
      </div>
      <div class="print-category-badge">{{ categoriaAttiva?.nome }}</div>
    </div>

    <!-- Print-only stats summary -->
    <div v-if="activeReport === 'mensile'" class="print-stats-only">
      <div class="print-stat-item">
        <span class="print-stat-label">Giocatori</span>
        <span class="print-stat-value">{{ assenzeMensili.length }}</span>
      </div>
      <div class="print-stat-item">
        <span class="print-stat-label">Periodo</span>
        <span class="print-stat-value">{{ mesi[meseSelezionato - 1] }} {{ annoSelezionato }}</span>
      </div>
      <div class="print-stat-item">
        <span class="print-stat-label">Max assenze</span>
        <span class="print-stat-value" :class="{ 'print-stat-high': assenzeMensili[0]?.assenze > 3 }">{{ assenzeMensili[0]?.assenze || 0 }}</span>
      </div>
    </div>

    <div v-if="activeReport === 'annuale'" class="print-stats-only">
      <div class="print-stat-item">
        <span class="print-stat-label">Giocatori</span>
        <span class="print-stat-value">{{ assenzePerGiocatore.length }}</span>
      </div>
      <div class="print-stat-item">
        <span class="print-stat-label">Periodo</span>
        <span class="print-stat-value">{{ formatData(dataInizio) }} — {{ formatData(dataFine) }}</span>
      </div>
      <div class="print-stat-item">
        <span class="print-stat-label">Max assenze</span>
        <span class="print-stat-value" :class="{ 'print-stat-high': assenzePerGiocatore[0]?.assenze > 5 }">{{ assenzePerGiocatore[0]?.assenze || 0 }}</span>
      </div>
    </div>

    <div v-if="activeReport === 'doppie'" class="print-stats-only">
      <div class="print-stat-item">
        <span class="print-stat-label">Casi rilevati</span>
        <span class="print-stat-value">{{ convocatiPerGiornata.length }}</span>
      </div>
      <div class="print-stat-item">
        <span class="print-stat-label">Tipo</span>
        <span class="print-stat-value">Convocazioni multiple</span>
      </div>
    </div>

    <!-- Report: Mensile -->
    <div v-if="activeReport === 'mensile'" class="report-view">
      <div class="report-toolbar">
        <div class="month-nav-pill">
          <button class="btn-nav-mese" @click="mesePrecedente">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <polyline points="15 18 9 12 15 6"/>
            </svg>
          </button>
          <span class="current-month">{{ mesi[meseSelezionato - 1] }} {{ annoSelezionato }}</span>
          <button class="btn-nav-mese" @click="meseSuccessivo">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <polyline points="9 18 15 12 9 6"/>
            </svg>
          </button>
        </div>
        <div class="report-actions">
          <button class="btn-action" @click="printReport" title="Stampa">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <polyline points="6 9 6 2 18 2 18 9"/>
              <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
              <rect x="6" y="14" width="12" height="8"/>
            </svg>
            Stampa
          </button>
          <button class="btn-action" @click="downloadCSV" title="Scarica CSV">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
              <polyline points="7 10 12 15 17 10"/>
              <line x1="12" y1="15" x2="12" y2="3"/>
            </svg>
            CSV
          </button>
        </div>
      </div>
      <div class="table-glass">
        <table class="report-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Cognome</th>
              <th>Nome</th>
              <th>Assenze</th>
              <th>%</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(g, idx) in assenzeMensili" :key="g.id">
              <td class="cell-num">{{ idx + 1 }}</td>
              <td>{{ g.cognome }}</td>
              <td>{{ g.nome }}</td>
              <td class="cell-danger">{{ g.assenze }}</td>
              <td class="cell-pct">{{ g.percentuale }}%</td>
            </tr>
            <tr v-if="assenzeMensili.length === 0">
              <td colspan="5" class="no-data">Nessun dato per questo mese</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Report: Annuale -->
    <div v-if="activeReport === 'annuale'" class="report-view">
      <div class="report-toolbar">
        <div class="report-period-label">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
            <line x1="16" y1="2" x2="16" y2="6"/>
            <line x1="8" y1="2" x2="8" y2="6"/>
            <line x1="3" y1="10" x2="21" y2="10"/>
          </svg>
          {{ formatData(dataInizio) }} — {{ formatData(dataFine) }}
        </div>
        <div class="report-actions">
          <button class="btn-action" @click="printReport" title="Stampa">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <polyline points="6 9 6 2 18 2 18 9"/>
              <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
              <rect x="6" y="14" width="12" height="8"/>
            </svg>
            Stampa
          </button>
          <button class="btn-action" @click="downloadCSV" title="Scarica CSV">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
              <polyline points="7 10 12 15 17 10"/>
              <line x1="12" y1="15" x2="12" y2="3"/>
            </svg>
            CSV
          </button>
        </div>
      </div>
      <div class="table-glass">
        <table class="report-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Cognome</th>
              <th>Nome</th>
              <th>Assenze</th>
              <th>%</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(g, idx) in assenzePerGiocatore" :key="g.id">
              <td class="cell-num">{{ idx + 1 }}</td>
              <td>{{ g.cognome }}</td>
              <td>{{ g.nome }}</td>
              <td class="cell-danger">{{ g.assenze }}</td>
              <td class="cell-pct">{{ g.percentuale }}%</td>
            </tr>
            <tr v-if="assenzePerGiocatore.length === 0">
              <td colspan="5" class="no-data">Nessun dato disponibile</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Report: Doppie -->
    <div v-if="activeReport === 'doppie'" class="report-view">
      <div class="report-toolbar">
        <div class="report-period-label">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M8 7V3m8 4V3"/>
            <path d="M4 21l16-16"/>
            <path d="M4 11l3-3"/>
            <path d="M20 7l-3-3"/>
          </svg>
          Giocatori convocati in gare multiple nello stesso giorno
        </div>
        <div class="report-actions">
          <button class="btn-action" @click="printReport" title="Stampa">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <polyline points="6 9 6 2 18 2 18 9"/>
              <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
              <rect x="6" y="14" width="12" height="8"/>
            </svg>
            Stampa
          </button>
          <button class="btn-action" @click="downloadCSV" title="Scarica CSV">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
              <polyline points="7 10 12 15 17 10"/>
              <line x1="12" y1="15" x2="12" y2="3"/>
            </svg>
            CSV
          </button>
        </div>
      </div>
      <div class="table-glass">
        <table class="report-table">
          <thead>
            <tr>
              <th>Cognome</th>
              <th>Nome</th>
              <th>Data</th>
              <th>Gare</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in convocatiPerGiornata" :key="item.key">
              <td>{{ item.cognome }}</td>
              <td>{{ item.nome }}</td>
              <td>{{ item.data }}</td>
              <td class="cell-warning">{{ item.numGare }}</td>
            </tr>
            <tr v-if="convocatiPerGiornata.length === 0">
              <td colspan="4" class="no-data">Nessuna convocazione multipla registrata</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, getRegistroMese, getConvocazioni, getConvocazione, getAllCategorie } from '../api/index.js'

const router = useRouter()
const route = useRoute()
const { societaAttiva, setCategoria, categoriaAttiva } = useStore()
const categoriaId = parseInt(route.params.id)

const activeReport = ref(null)
const categoria = ref(null)
const dataInizio = ref('')
const dataFine = ref('')
const assenzePerGiocatore = ref([])
const assenzeMensili = ref([])
const meseSelezionato = ref(new Date().getMonth() + 1)
const annoSelezionato = ref(new Date().getFullYear())
const mesi = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre']
const convocatiPerGiornata = ref([])
const personeMap = ref(new Map())

const reportMeta = {
  mensile: { title: 'Report Mensile', desc: '' },
  annuale: { title: 'Report Annuale', desc: '' },
  doppie: { title: 'Doppie Convocazioni', desc: '' }
}

const availableReports = [
  { key: 'mensile', title: 'Mensile', desc: 'Assenze dettagliate per mese', cardClass: 'card-blue' },
  { key: 'annuale', title: 'Annuale', desc: 'Assenze totali stagione', cardClass: 'card-red' },
  { key: 'doppie', title: 'Doppie', desc: 'Giocatori in gare multiple stesso giorno', cardClass: 'card-yellow' }
]

function goBack() {
  if (activeReport.value) {
    activeReport.value = null
  } else {
    router.push('/scelta/' + route.params.id)
  }
}

function formatData(d) {
  if (!d) return '-'
  return d.split('-').reverse().join('/')
}

async function ricalcolaDati() {
  if (!dataInizio.value || !dataFine.value) return

  const giocatoriMap = new Map()
  const giorniTotali = new Set()

  for (const [id, p] of personeMap.value) {
    giocatoriMap.set(id, { id, cognome: p.cognome, nome: p.nome, assenze: 0 })
  }

  const oggi = new Date()
  for (let m = 0; m < 12; m++) {
    const d = new Date(oggi.getFullYear(), oggi.getMonth() - m, 1)
    const anno = d.getFullYear()
    const mese = d.getMonth() + 1

    try {
      const regRes = await getRegistroMese(categoriaId, anno, mese)
      const entries = regRes.data || []

      for (const e of entries) {
        if (!e.data || e.data < dataInizio.value || e.data > dataFine.value) continue
        giorniTotali.add(e.data)
        if (e.codice === 'AG' || e.codice === 'AI') {
          if (giocatoriMap.has(e.persona_id)) {
            giocatoriMap.get(e.persona_id).assenze++
          }
        }
      }
    } catch (e) {}
  }

  const tot = giorniTotali.size
  assenzePerGiocatore.value = Array.from(giocatoriMap.values()).map(g => {
    g.percentuale = tot > 0 ? Math.min(100, Math.round((g.assenze / tot) * 100)) : 0
    return g
  }).sort((a, b) => b.assenze - a.assenze)
}

async function ricalcolaAssenzeMensili() {
  const mese = parseInt(meseSelezionato.value)
  const anno = annoSelezionato.value

  const giocatoriMap = new Map()
  const giorniTotali = new Set()

  for (const [id, p] of personeMap.value) {
    giocatoriMap.set(id, { id, cognome: p.cognome, nome: p.nome, assenze: 0 })
  }

  try {
    const regRes = await getRegistroMese(categoriaId, anno, mese)
    const entries = regRes.data || []

    for (const e of entries) {
      if (!e.data) continue
      giorniTotali.add(e.data)
      if (e.codice === 'AG' || e.codice === 'AI') {
        if (giocatoriMap.has(e.persona_id)) {
          giocatoriMap.get(e.persona_id).assenze++
        }
      }
    }
  } catch (e) {}

  const tot = giorniTotali.size
  assenzeMensili.value = Array.from(giocatoriMap.values()).map(g => {
    g.percentuale = tot > 0 ? Math.min(100, Math.round((g.assenze / tot) * 100)) : 0
    return g
  }).sort((a, b) => b.assenze - a.assenze)
}

function mesePrecedente() {
  if (meseSelezionato.value === 1) {
    meseSelezionato.value = 12
    annoSelezionato.value--
  } else {
    meseSelezionato.value--
  }
  ricalcolaAssenzeMensili()
}

function meseSuccessivo() {
  if (meseSelezionato.value === 12) {
    meseSelezionato.value = 1
    annoSelezionato.value++
  } else {
    meseSelezionato.value++
  }
  ricalcolaAssenzeMensili()
}

async function caricaConvocati() {
  try {
    const convRes = await getConvocazioni(categoriaId)
    const convsList = convRes.data || []

    const dataMap = new Map()

    for (const conv of convsList) {
      try {
        const convDetailRes = await getConvocazione(conv.id)
        const convDetail = convDetailRes.data
        if (!convDetail || !convDetail.data_inizio) continue

        for (const gara of convDetail.gare || []) {
          const dataGara = gara.data
          if (!dataGara) continue
          if (!dataMap.has(dataGara)) dataMap.set(dataGara, new Map())
          const map = dataMap.get(dataGara)
          for (const g of gara.giocatori || []) {
            if (!map.has(g.persona_id)) {
              map.set(g.persona_id, { id: g.persona_id, cognome: g.cognome, nome: g.nome, numGare: 0 })
            }
            map.get(g.persona_id).numGare++
          }
        }
      } catch (e) {}
    }

    const risultato = []
    for (const [data, players] of dataMap) {
      for (const p of players.values()) {
        if (p.numGare >= 2) {
          risultato.push({
            key: data + '_' + p.id,
            data: formatData(data),
            cognome: p.cognome,
            nome: p.nome,
            numGare: p.numGare
          })
        }
      }
    }
    convocatiPerGiornata.value = risultato.sort((a, b) => a.data.localeCompare(b.data))
  } catch (e) {}
}

// ── CSV & Print ──
function getReportData() {
  if (activeReport.value === 'mensile') {
    return {
      header: ['#', 'Cognome', 'Nome', 'Assenze', '%'],
      rows: assenzeMensili.value.map((g, i) => [i + 1, g.cognome, g.nome, g.assenze, g.percentuale + '%'])
    }
  }
  if (activeReport.value === 'annuale') {
    return {
      header: ['#', 'Cognome', 'Nome', 'Assenze', '%'],
      rows: assenzePerGiocatore.value.map((g, i) => [i + 1, g.cognome, g.nome, g.assenze, g.percentuale + '%'])
    }
  }
  if (activeReport.value === 'doppie') {
    return {
      header: ['Cognome', 'Nome', 'Data', 'Gare'],
      rows: convocatiPerGiornata.value.map(g => [g.cognome, g.nome, g.data, g.numGare])
    }
  }
  return { header: [], rows: [] }
}

function downloadCSV() {
  const { header, rows } = getReportData()
  const csv = [header.join(','), ...rows.map(r => r.join(','))].join('\n')
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `report_${activeReport.value}_${categoriaAttiva.value?.nome || ''}_${new Date().toISOString().slice(0,10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function printReport() {
  nextTick(() => {
    const view = document.querySelector('.report-view')
    if (view) {
      const oggi = new Date()
      const data = oggi.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit', year: 'numeric' })
      view.setAttribute('data-print-date', data)
    }
    setTimeout(() => window.print(), 150)
  })
}

onMounted(async () => {
  try {
    const societaId = societaAttiva.value?.id || null
    const [catRes, personeRes] = await Promise.all([
      getAllCategorie(societaId),
      getPersone(categoriaId)
    ])

    const cats = catRes.data || []
    categoria.value = cats.find(c => c.id === categoriaId)
    if (categoria.value) {
      setCategoria(categoria.value)
      dataInizio.value = categoria.value.data_inizio_stagione || new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0]
      dataFine.value = categoria.value.data_fine_stagione || new Date().toISOString().split('T')[0]
    }

    const ppl = personeRes.data || []
    for (const p of ppl) personeMap.value.set(p.id, p)

    await Promise.all([
      ricalcolaDati(),
      ricalcolaAssenzeMensili(),
      caricaConvocati()
    ])
  } catch (e) {
    console.error('Errore caricamento reportistica:', e)
  }
})
</script>

<style scoped>
.reportistica-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1200px;
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
  background: radial-gradient(circle, rgba(168, 85, 247, 0.08) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 400px;
  height: 400px;
  bottom: -100px;
  left: -80px;
  background: radial-gradient(circle, rgba(59, 130, 246, 0.06) 0%, transparent 70%);
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
  margin-bottom: 2rem;
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

/* ── Report Landing Cards ── */
.report-landing {
  position: relative;
  z-index: 1;
  animation: fadeSlideIn 0.6s ease-out 0.1s both;
}

.report-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}

.report-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 2rem 1.75rem;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
}

.report-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 20px;
  opacity: 0;
  transition: opacity var(--transition-base);
}

.report-card:hover {
  transform: translateY(-4px);
  border-color: rgba(255, 255, 255, 0.12);
}

.report-card:hover::before {
  opacity: 1;
}

.report-card:hover .report-arrow {
  opacity: 1;
  transform: translate(0, 0);
}

.card-blue::before {
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.08) 0%, transparent 60%);
}
.card-blue:hover {
  border-color: rgba(59, 130, 246, 0.3);
  box-shadow: 0 8px 32px rgba(59, 130, 246, 0.1);
}

.card-red::before {
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.08) 0%, transparent 60%);
}
.card-red:hover {
  border-color: rgba(220, 38, 38, 0.3);
  box-shadow: 0 8px 32px rgba(220, 38, 38, 0.1);
}

.card-yellow::before {
  background: linear-gradient(135deg, rgba(234, 179, 8, 0.08) 0%, transparent 60%);
}
.card-yellow:hover {
  border-color: rgba(234, 179, 8, 0.3);
  box-shadow: 0 8px 32px rgba(234, 179, 8, 0.1);
}

.report-icon-wrap {
  width: 56px;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
  border: 1px solid;
  flex-shrink: 0;
  margin-bottom: 0.25rem;
}

.card-blue .report-icon-wrap {
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.2) 0%, rgba(59, 130, 246, 0.08) 100%);
  border-color: rgba(59, 130, 246, 0.3);
  color: #60a5fa;
}

.card-red .report-icon-wrap {
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.2) 0%, rgba(220, 38, 38, 0.08) 100%);
  border-color: rgba(220, 38, 38, 0.3);
  color: #f87171;
}

.card-yellow .report-icon-wrap {
  background: linear-gradient(135deg, rgba(234, 179, 8, 0.2) 0%, rgba(234, 179, 8, 0.08) 100%);
  border-color: rgba(234, 179, 8, 0.3);
  color: #fbbf24;
}

.report-label {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.01em;
}

.report-desc {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
}

.report-arrow {
  position: absolute;
  right: 1.5rem;
  bottom: 1.5rem;
  opacity: 0;
  transform: translate(-8px, 0);
  transition: all var(--transition-base);
  color: var(--color-text-secondary);
}

/* ── Report View ── */
.report-view {
  position: relative;
  z-index: 1;
  animation: fadeSlideIn 0.5s ease-out both;
}

.report-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.25rem;
  flex-wrap: wrap;
  gap: 0.75rem;
}

.month-nav-pill {
  display: inline-flex;
  align-items: center;
  gap: 1rem;
  padding: 0.5rem 0.5rem 0.5rem 1.25rem;
  background: rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 100px;
}

.current-month {
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
  background: rgba(59, 130, 246, 0.15);
  border-color: rgba(59, 130, 246, 0.3);
  color: #60a5fa;
}

.report-period-label {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  font-size: 0.8125rem;
  color: var(--color-text-secondary);
}

.report-period-label svg {
  color: var(--color-primary);
}

.report-actions {
  display: flex;
  gap: 0.5rem;
}

.btn-action {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.9rem;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  color: var(--color-text-secondary);
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-action:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.2);
  color: var(--color-text);
}

/* ── Table ── */
.table-glass {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  border: 1px solid var(--color-border);
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.02);
  backdrop-filter: blur(10px);
}

.report-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 0.875rem;
  color: var(--color-text);
}

.report-table th {
  background: rgba(255, 255, 255, 0.04);
  color: var(--color-text-secondary);
  padding: 0.875rem 1rem;
  text-align: left;
  font-weight: 600;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

.report-table td {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.03);
}

tr:last-child td { border-bottom: none; }

.report-table tr:hover {
  background: rgba(255, 255, 255, 0.03);
}

.cell-num {
  width: 40px;
  color: var(--color-text-muted);
  text-align: center;
  font-size: 0.75rem;
}

.cell-danger {
  color: #f87171;
  font-weight: 700;
  font-family: var(--font-mono);
}

.cell-pct {
  color: var(--color-text-muted);
  font-family: var(--font-mono);
  font-weight: 600;
}

.cell-warning {
  color: #fbbf24;
  font-weight: 700;
  font-family: var(--font-mono);
}

.no-data {
  text-align: center;
  padding: 3rem;
  color: var(--color-text-muted);
  font-size: 0.9375rem;
}

/* ── Animations ── */
@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

/* ── Print ── */
@media print {
  @page {
    size: A4 landscape;
    margin: 12mm 10mm 18mm 10mm;
  }

  html, body {
    margin: 0 !important;
    padding: 0 !important;
    background: white !important;
    color: #111 !important;
    font-family: 'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif !important;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  /* ── Nascosti ── */
  .bg-glow,
  .btn-back-pill,
  .report-actions,
  .btn-nav-mese,
  .report-landing,
  .report-arrow,
  nav,
  footer { display: none !important; }

  .reportistica-page {
    padding: 0 !important;
    max-width: none !important;
    background: white !important;
    color: #111 !important;
    overflow: visible !important;
    min-height: auto !important;
  }

  /* ── Print-only header (società + logo + report type) ── */
  .print-header-only {
    display: flex !important;
    justify-content: space-between;
    align-items: flex-start;
    padding-bottom: 5mm !important;
    margin-bottom: 5mm !important;
    border-bottom: 1.5pt solid var(--color-primary, #dc2626) !important;
    position: relative;
  }

  .print-societa-row {
    display: flex;
    align-items: center;
    gap: 4mm;
  }

  .print-logo {
    width: 14mm;
    height: 14mm;
    object-fit: contain;
    border-radius: 2mm;
  }

  .print-societa-info {
    display: flex;
    flex-direction: column;
    gap: 1mm;
  }

  .print-societa-name {
    font-size: 14pt;
    font-weight: 800;
    color: #111;
    letter-spacing: -0.02em;
    line-height: 1.1;
  }

  .print-report-type {
    font-size: 9pt;
    font-weight: 500;
    color: #666;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .print-category-badge {
    background: var(--color-primary, #dc2626) !important;
    color: white !important;
    font-size: 10pt;
    font-weight: 700;
    padding: 2.5mm 5mm;
    border-radius: 100px;
    letter-spacing: -0.01em;
  }

  /* ── Print-only stats summary ── */
  .print-stats-only {
    display: flex !important;
    gap: 3mm;
    margin-bottom: 5mm !important;
  }

  .print-stat-item {
    flex: 1;
    display: flex;
    flex-direction: column;
    padding: 3.5mm 4mm;
    background: #f8f9fb !important;
    border-radius: 3mm;
    border: 0.5pt solid #e5e7eb !important;
    gap: 1mm;
  }

  .print-stat-label {
    font-size: 7pt;
    font-weight: 600;
    color: #888;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .print-stat-value {
    font-size: 12pt;
    font-weight: 800;
    color: #111;
    letter-spacing: -0.02em;
  }

  .print-stat-high {
    color: #dc2626 !important;
  }

  /* ── Page header (category name) ── */
  .page-header {
    margin-bottom: 8mm !important;
    animation: none !important;
  }

  .header-main { margin-top: 0 !important; }

  .category-name {
    font-size: 18pt !important;
    font-weight: 800 !important;
    margin-bottom: 0 !important;
    letter-spacing: -0.03em !important;
    line-height: 1.1 !important;
  }

  .name-gradient {
    background: none !important;
    -webkit-background-clip: unset !important;
    background-clip: unset !important;
    -webkit-text-fill-color: #111 !important;
    color: #111 !important;
  }

  .header-subtitle {
    font-size: 10pt !important;
    color: #666 !important;
    font-weight: 400 !important;
    margin: 0 !important;
  }

  /* ── Toolbar: solo info periodo ── */
  .report-toolbar {
    margin-bottom: 5mm !important;
    flex-direction: column !important;
    align-items: flex-start !important;
    gap: 2mm !important;
  }

  .month-nav-pill {
    background: none !important;
    border: none !important;
    backdrop-filter: none !important;
    padding: 0 !important;
    gap: 0 !important;
  }

  .current-month {
    font-size: 10pt !important;
    font-weight: 600 !important;
    color: #444 !important;
    min-width: auto !important;
    text-align: left !important;
  }

  .report-period-label {
    background: none !important;
    border: none !important;
    padding: 0 !important;
    font-size: 9pt !important;
    color: #555 !important;
    gap: 2mm !important;
  }

  .report-period-label svg { display: none !important; }

  /* ── Tabella ── */
  .table-glass {
    border: 0.75pt solid #e0e0e0 !important;
    background: white !important;
    backdrop-filter: none !important;
    overflow: visible !important;
    border-radius: 0 !important;
  }

  .report-table {
    width: 100% !important;
    border-collapse: collapse !important;
    font-size: 8.5pt !important;
    color: #111 !important;
  }

  .report-table thead { display: table-header-group !important; }

  .report-table th {
    background: #111 !important;
    color: white !important;
    padding: 3mm 3mm !important;
    text-align: left !important;
    font-weight: 700 !important;
    font-size: 7pt !important;
    text-transform: uppercase !important;
    letter-spacing: 0.08em !important;
    border: none !important;
    border-bottom: none !important;
  }

  .report-table th:first-child {
    border-radius: 0 !important;
  }

  .report-table th:last-child {
    border-radius: 0 !important;
  }

  .report-table td {
    padding: 2.2mm 3mm !important;
    border-bottom: 0.5pt solid #eee !important;
    color: #111 !important;
    background: transparent !important;
    vertical-align: middle !important;
  }

  .report-table tbody tr:nth-child(even) td {
    background: #fafbfc !important;
  }

  .report-table tr:hover { background: transparent !important; }

  .report-table tbody tr:last-child td {
    border-bottom: none !important;
  }

  .cell-num {
    width: 7mm !important;
    text-align: center !important;
    color: #999 !important;
    font-size: 7.5pt !important;
    font-weight: 600 !important;
  }

  .cell-danger {
    color: #dc2626 !important;
    font-weight: 700 !important;
    font-family: 'SF Mono', 'Cascadia Code', 'Consolas', monospace !important;
    font-size: 9pt !important;
  }

  .cell-warning {
    color: #d97706 !important;
    font-weight: 700 !important;
    font-family: 'SF Mono', 'Cascadia Code', 'Consolas', monospace !important;
    font-size: 9pt !important;
  }

  .cell-pct {
    color: #555 !important;
    font-family: 'SF Mono', 'Cascadia Code', 'Consolas', monospace !important;
    font-weight: 600 !important;
    font-size: 8.5pt !important;
  }

  .no-data {
    text-align: center !important;
    padding: 10mm !important;
    color: #999 !important;
    font-size: 10pt !important;
    font-style: italic !important;
  }

  /* ── Footer ── */
  .report-view::after {
    content: 'Stampato il ' attr(data-print-date) ' — ' 'Registro Presenze';
    display: block;
    position: fixed;
    bottom: 6mm;
    left: 10mm;
    right: 10mm;
    text-align: right;
    font-size: 7pt;
    color: #aaa;
    border-top: 0.5pt solid #e8e8e8;
    padding-top: 2.5mm;
    letter-spacing: 0.02em;
  }

  /* ── Hide print-only elements on screen ── */
}

/* ── Print-only elements: hidden on screen ── */
.print-header-only,
.print-stats-only {
  display: none;
}

/* ── Responsive ── */
@media (max-width: 768px) {
  .reportistica-page {
    padding: 1.5rem 1rem 3rem;
  }
  .report-grid {
    grid-template-columns: 1fr;
  }
  .report-toolbar {
    flex-direction: column;
    align-items: flex-start;
  }
}

@media (max-width: 480px) {
  .category-name {
    font-size: 1.75rem;
  }
  .header-top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }
}
</style>
