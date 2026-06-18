<template>
  <div class="cert-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-icon" @click="router.push('/infermeria')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <button class="btn-icon" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
        </button>
      </div>
      <span class="page-title">Certificati Medici</span>
      <div class="header-right">
        <div class="summary-pill">
          <span class="pill-dot" :class="{ 'dot-rosso': scaduti > 0 }"></span>
          <span>{{ totale }} iscritti · {{ scaduti }} scaduti · {{ inScadenza }} in scadenza</span>
        </div>
      </div>
    </header>

    <div class="content">
      <div class="toolbar">
        <div class="search-wrap">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="search-icon">
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input v-model="search" placeholder="Cerca giocatore..." class="search-input" />
        </div>
        <div class="filter-group">
          <button class="btn-filter" :class="{ active: filtro === 'tutti' }" @click="filtro = 'tutti'">Tutti</button>
          <button class="btn-filter" :class="{ active: filtro === 'scaduti' }" @click="filtro = 'scaduti'">
            Scaduti <span class="filter-count">{{ scaduti }}</span>
          </button>
          <button class="btn-filter" :class="{ active: filtro === 'in_scadenza' }" @click="filtro = 'in_scadenza'">
            In Scadenza <span class="filter-count">{{ inScadenza }}</span>
          </button>
          <button class="btn-filter" :class="{ active: filtro === 'senza' }" @click="filtro = 'senza'">
            Senza <span class="filter-count">{{ senzaCertificato }}</span>
          </button>
        </div>
      </div>

      <div class="cat-grid">
        <div
          v-for="cat in categorieOrdinate"
          :key="cat.id"
          class="cat-section"
        >
          <div class="cat-header">
            <span class="cat-anno">{{ cat.anno }}</span>
            <span class="cat-nome">{{ cat.nome }}</span>
            <span class="cat-count">{{ getFilteredPlayers(cat.id).length }} iscritti</span>
          </div>

          <div class="table-wrap">
            <table class="cert-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Nome</th>
                  <th>Cognome</th>
                  <th>Scadenza Certificato</th>
                  <th>Struttura di Rilascio</th>
                  <th>Stato</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(p, idx) in getFilteredPlayers(cat.id)" :key="p.id" class="cert-row" :class="getRowClass(p)">
                  <td>{{ idx + 1 }}</td>
                  <td>{{ p.nome }}</td>
                  <td class="col-cognome">{{ p.cognome }}</td>
                  <td class="col-data" :class="{ 'data-rossa': isScaduta(p.scadenza_certificato), 'data-gialla': isInScadenza(p.scadenza_certificato) }">
                    {{ formatData(p.scadenza_certificato) }}
                  </td>
                  <td class="col-struttura">{{ p.struttura_rilascio || '-' }}</td>
                  <td class="col-stato">
                    <span v-if="!p.scadenza_certificato" class="status-badge senza">Senza</span>
                    <span v-else-if="isScaduta(p.scadenza_certificato)" class="status-badge scaduto">Scaduto</span>
                    <span v-else-if="isInScadenza(p.scadenza_certificato)" class="status-badge scadenza">In Scadenza</span>
                    <span v-else class="status-badge valido">Valido</span>
                  </td>
                </tr>
                <tr v-if="getFilteredPlayers(cat.id).length === 0">
                  <td colspan="6" class="no-data">Nessun giocatore trovato</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from '../store.js'
import { getCategorie, getPersone } from '../api/index.js'

const router = useRouter()
const { utenteAttivo } = useStore()

const categorie = ref([])
const persone = ref([])
const search = ref('')
const filtro = ref('tutti')

const societaId = computed(() => {
  return utenteAttivo.value?.societa_id || parseInt(localStorage.getItem('societa_id')) || 1
})

onMounted(async () => {
  await loadDati()
})

async function loadDati() {
  try {
    const res = await getCategorie()
    let cats = Array.isArray(res) ? res : (res?.data || [])
    categorie.value = cats.filter(c => c.societa_id === societaId.value && !c.is_archiviata)

    for (const cat of categorie.value) {
      const pRes = await getPersone(cat.id)
      const players = Array.isArray(pRes) ? pRes : (pRes?.data || [])
      persone.value.push(...players.map(p => ({ ...p, categoria_id: cat.id })))
    }
  } catch (e) {
    console.error('Errore caricamento:', e)
  }
}

const categorieOrdinate = computed(() => {
  return [...categorie.value].sort((a, b) => (a.anno || 0) - (b.anno || 0))
})

function isScaduta(data) {
  if (!data) return false
  return new Date(data) < new Date()
}

function isInScadenza(data) {
  if (!data) return false
  const oggi = new Date()
  const scad = new Date(data)
  const diff = (scad - oggi) / (1000 * 60 * 60 * 24)
  return diff >= 0 && diff <= 30
}

function getFilteredPlayers(catId) {
  let list = persone.value.filter(p => p.categoria_id === catId)

  if (search.value) {
    const s = search.value.toLowerCase()
    list = list.filter(p =>
      p.nome?.toLowerCase().includes(s) ||
      p.cognome?.toLowerCase().includes(s)
    )
  }

  switch (filtro.value) {
    case 'scaduti':
      return list.filter(p => p.scadenza_certificato && isScaduta(p.scadenza_certificato))
    case 'in_scadenza':
      return list.filter(p => p.scadenza_certificato && isInScadenza(p.scadenza_certificato))
    case 'senza':
      return list.filter(p => !p.scadenza_certificato)
    default:
      return list
  }
}

const totale = computed(() => persone.value.length)
const scaduti = computed(() => persone.value.filter(p => p.scadenza_certificato && isScaduta(p.scadenza_certificato)).length)
const inScadenza = computed(() => persone.value.filter(p => p.scadenza_certificato && isInScadenza(p.scadenza_certificato)).length)
const senzaCertificato = computed(() => persone.value.filter(p => !p.scadenza_certificato).length)

function formatData(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('it-IT')
}

function getRowClass(p) {
  if (!p.scadenza_certificato) return 'row-senza'
  if (isScaduta(p.scadenza_certificato)) return 'row-scaduto'
  if (isInScadenza(p.scadenza_certificato)) return 'row-scadenza'
  return ''
}
</script>

<style scoped>
.cert-page {
  min-height: 100vh;
  background: var(--color-bg);
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem;
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  position: sticky;
  top: 0;
  z-index: 100;
}

.header-left {
  display: flex;
  gap: 0.5rem;
}

.btn-icon {
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
}

.btn-icon:hover {
  background: #10b981;
  border-color: #10b981;
}

.btn-icon svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
}

.page-title {
  font-size: 1rem;
  font-weight: 600;
}

.header-right {
  display: flex;
  gap: 0.5rem;
}

.summary-pill {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.35rem 0.75rem;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: 100px;
  font-size: 0.75rem;
  color: var(--color-text-secondary);
}

.pill-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10b981;
}

.pill-dot.dot-rosso {
  background: #ef4444;
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

.content {
  padding: 1rem;
}

.toolbar {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.search-wrap {
  flex: 1;
  min-width: 200px;
  position: relative;
}

.search-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--color-text-secondary);
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 0.625rem 1rem 0.625rem 2.25rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
}

.filter-group {
  display: flex;
  gap: 0.35rem;
}

.btn-filter {
  padding: 0.4rem 0.75rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  color: var(--color-text-secondary);
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 0.35rem;
  white-space: nowrap;
}

.btn-filter:hover {
  border-color: rgba(16, 185, 129, 0.4);
  color: var(--color-text);
}

.btn-filter.active {
  background: rgba(16, 185, 129, 0.15);
  border-color: rgba(16, 185, 129, 0.4);
  color: #10b981;
}

.filter-count {
  background: rgba(255, 255, 255, 0.1);
  padding: 0.1rem 0.4rem;
  border-radius: 100px;
  font-size: 0.65rem;
  font-weight: 700;
}

.btn-filter.active .filter-count {
  background: rgba(16, 185, 129, 0.3);
}

.cat-grid {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.cat-section {
  animation: fadeSlideIn 0.4s ease-out both;
}

.cat-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  padding: 0.5rem 0;
}

.cat-anno {
  background: rgba(16, 185, 129, 0.15);
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
  color: #10b981;
}

.cat-nome {
  font-weight: 700;
  font-size: 1rem;
  color: var(--color-text);
}

.cat-count {
  font-size: 0.75rem;
  color: var(--color-text-secondary);
  margin-left: auto;
}

.table-wrap {
  overflow-x: auto;
  background: var(--color-surface);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
}

.cert-table {
  width: 100%;
  border-collapse: collapse;
}

.cert-table th {
  background: var(--color-surface-elevated);
  padding: 0.625rem 0.75rem;
  text-align: left;
  font-weight: 600;
  color: var(--color-text-secondary);
  font-size: 0.7rem;
  text-transform: uppercase;
  white-space: nowrap;
  border-bottom: 1px solid var(--color-border);
}

.cert-table td {
  padding: 0.625rem 0.75rem;
  border-bottom: 1px solid var(--color-border);
  color: var(--color-text);
  font-size: 0.8rem;
}

.cert-row {
  transition: background-color 0.15s;
}

.cert-row:hover {
  background: rgba(16, 185, 129, 0.05);
}

.row-scaduto {
  background: rgba(239, 68, 68, 0.04);
}

.row-scadenza {
  background: rgba(245, 158, 11, 0.04);
}

.row-senza {
  background: rgba(107, 114, 128, 0.04);
}

.col-cognome {
  font-weight: 600;
}

.col-data {
  white-space: nowrap;
  font-weight: 500;
}

.data-rossa {
  color: #ef4444;
  font-weight: 700;
}

.data-gialla {
  color: #f59e0b;
  font-weight: 600;
}

.col-struttura {
  color: var(--color-text-secondary);
  font-size: 0.75rem;
}

.col-stato {
  white-space: nowrap;
}

.status-badge {
  display: inline-block;
  padding: 0.2rem 0.5rem;
  border-radius: 100px;
  font-size: 0.65rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.status-badge.valido {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
}

.status-badge.scaduto {
  background: rgba(239, 68, 68, 0.15);
  color: #ef4444;
}

.status-badge.scadenza {
  background: rgba(245, 158, 11, 0.15);
  color: #f59e0b;
}

.status-badge.senza {
  background: rgba(107, 114, 128, 0.15);
  color: #6b7280;
}

.no-data {
  text-align: center;
  padding: 1.5rem;
  color: var(--color-text-muted);
  font-size: 0.8rem;
}

@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}

@media (max-width: 768px) {
  .toolbar { flex-direction: column; align-items: stretch; }
  .filter-group { flex-wrap: wrap; }
  .summary-pill { font-size: 0.65rem; }
}

@media (max-width: 480px) {
  .page-header { flex-wrap: wrap; gap: 0.5rem; }
  .header-right { display: none; }
}
</style>
