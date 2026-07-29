<template>
  <div class="presenze-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-icon" @click="router.push('/segreteria')">
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
      <span class="page-title">Presenze</span>
      <div class="header-right">
        <div class="month-selector">
          <button class="btn-nav" @click="prevMonth">‹</button>
          <span class="month-label">{{ monthLabel }}</span>
          <button class="btn-nav" @click="nextMonth">›</button>
        </div>
      </div>
    </header>

    <div class="content">
      <div class="summary-bar">
        <div class="summary-item">
          <span class="summary-label">Categorie</span>
          <span class="summary-value">{{ categorieOrdinate.length }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">Giocatori totali</span>
          <span class="summary-value">{{ totaleGiocatori }}</span>
        </div>
      </div>

      <div class="cat-grid">
        <div
          v-for="cat in categorieOrdinate"
          :key="cat.id"
          class="cat-card"
          @click="router.push('/registro/' + cat.id)"
        >
          <div class="cat-card-header">
            <span class="cat-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                <path d="M16 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                <circle cx="8.5" cy="7" r="4"/>
                <line x1="20" y1="8" x2="20" y2="14"/>
                <line x1="23" y1="11" x2="17" y2="11"/>
              </svg>
            </span>
            <span class="cat-anno">{{ cat.anno }}</span>
            <span class="cat-nome">{{ cat.nome }}</span>
          </div>
          <div class="cat-card-body">
            <div class="cat-stat">
              <span class="cat-stat-value">{{ getGiocatoriCat(cat.id).length }}</span>
              <span class="cat-stat-label">giocatori</span>
            </div>
            <div class="cat-stat">
              <span class="cat-stat-value">{{ getGiorniAllenamento(cat.id) }}</span>
              <span class="cat-stat-label">giorni</span>
            </div>
          </div>
          <div class="cat-card-footer">
            <span class="cat-label">Vai al registro</span>
            <span class="cat-arrow">→</span>
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
const meseCorrente = ref(new Date().getMonth() + 1)
const annoCorrente = ref(new Date().getFullYear())

const mesi = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno','Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre']

const monthLabel = computed(() => `${mesi[meseCorrente.value - 1]} ${annoCorrente.value}`)

function prevMonth() {
  meseCorrente.value--
  if (meseCorrente.value < 1) { meseCorrente.value = 12; annoCorrente.value-- }
}

function nextMonth() {
  meseCorrente.value++
  if (meseCorrente.value > 12) { meseCorrente.value = 1; annoCorrente.value++ }
}

const societaId = computed(() => {
  const u = utenteAttivo.value
  return u?.societa_id || parseInt(localStorage.getItem('societa_id')) || 1
})

const categorieOrdinate = computed(() => {
  return [...categorie.value].sort((a, b) => (a.anno || 0) - (b.anno || 0))
})

const totaleGiocatori = computed(() => persone.value.length)

function getGiocatoriCat(catId) {
  return persone.value.filter(p => p.categoria_id === catId)
}

function getGiorniAllenamento(catId) {
  const giorni = categorie.value.find(c => c.id === catId)?.giorni
  if (!giorni) return 0
  return giorni.split(',').filter(g => g.trim()).length
}

onMounted(async () => {
  await loadDati()
})

async function loadDati() {
  try {
    const response = await getCategorie()
    let cats = Array.isArray(response) ? response : (response?.data || [])
    cats = cats.filter(c => c.societa_id === societaId.value && !c.is_portieri && c.parent_id !== null)
    categorie.value = cats

    let all = []
    for (const cat of categorie.value) {
      const pRes = await getPersone(cat.id)
      const players = Array.isArray(pRes) ? pRes : (pRes?.data || [])
      all.push(...players.map(p => ({ ...p, categoria_id: cat.id })))
    }
    persone.value = all
  } catch(e) { console.error('Error loading:', e) }
}
</script>

<style scoped>
.presenze-page {
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
  color: var(--color-text);
}

.btn-icon:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.page-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-text);
}

.header-right {
  display: flex;
  align-items: center;
}

.month-selector {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.btn-nav {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  cursor: pointer;
  color: var(--color-text);
  font-size: 1.2rem;
  transition: all 0.15s;
}

.btn-nav:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.month-label {
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--color-text);
  min-width: 140px;
  text-align: center;
}

.content {
  padding: 1rem;
}

.summary-bar {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}

.summary-item {
  background: var(--color-surface);
  border-radius: var(--radius-md);
  padding: 0.75rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.summary-label {
  font-size: 0.7rem;
  text-transform: uppercase;
  color: var(--color-text-secondary);
  font-weight: 600;
  letter-spacing: 0.03em;
}

.summary-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--color-text);
}

.cat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.cat-card {
  background: var(--color-surface);
  border-radius: var(--radius-lg);
  overflow: hidden;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid var(--color-border);
}

.cat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  border-color: var(--color-primary);
}

.cat-card-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
}

.cat-icon {
  display: flex;
  align-items: center;
  opacity: 0.9;
}

.cat-anno {
  background: rgba(255, 255, 255, 0.2);
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
}

.cat-nome {
  flex: 1;
  font-weight: 600;
  font-size: 0.9rem;
}

.cat-card-body {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.5rem;
  padding: 1rem;
}

.cat-stat {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
}

.cat-stat-value {
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--color-text);
}

.cat-stat-label {
  font-size: 0.65rem;
  color: var(--color-text-secondary);
  text-transform: uppercase;
  font-weight: 500;
}

.cat-card-footer {
  padding: 0.5rem 1rem;
  border-top: 1px solid var(--color-border);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.cat-label {
  font-size: 0.75rem;
  color: var(--color-text-secondary);
  font-weight: 500;
}

.cat-arrow {
  font-size: 1.2rem;
  color: var(--color-primary);
  transition: transform 0.2s;
}

.cat-card:hover .cat-arrow {
  transform: translateX(4px);
}

@media (max-width: 600px) {
  .summary-bar {
    grid-template-columns: repeat(2, 1fr);
  }
  .cat-grid {
    grid-template-columns: 1fr;
  }
}
</style>