<template>
  <div class="infermeria-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          <span>Home</span>
        </button>
        <div class="header-badge">
          <span class="badge-dot"></span>
          <span>{{ currentSeason }}</span>
        </div>
      </div>
      <div class="header-main">
        <h1 class="page-title">
          <span class="name-gradient">Infermeria</span>
        </h1>
        <p class="header-subtitle">Gestione certificati e infortuni</p>
      </div>
    </header>

    <div class="content-grid">
      <div class="content-card" @click="router.push('/infermeria/certificati')">
        <div class="card-glow"></div>
        <div class="card-icon-wrap certificati">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="32" height="32">
            <path d="M9 12l2 2 4-4"/>
            <path d="M12 2a10 10 0 100 20 10 10 0 000-20z"/>
            <path d="M12 6v6"/>
          </svg>
        </div>
        <div class="card-text">
          <h3 class="card-title">Certificato Medico</h3>
          <p class="card-desc">Stato e scadenze dei certificati medici per categoria</p>
        </div>
        <div class="card-stats">
          <div class="stat-item" :class="{ 'stat-rosso': scadutiTotali > 0 }">
            <span class="stat-value">{{ scadutiTotali }}</span>
            <span class="stat-label">scaduti</span>
          </div>
          <div class="stat-item stat-warning" :class="{ 'stat-giallo': inScadenzaTotali > 0 }">
            <span class="stat-value">{{ inScadenzaTotali }}</span>
            <span class="stat-label">in scadenza</span>
          </div>
          <div class="stat-item stat-ok">
            <span class="stat-value">{{ validiTotali }}</span>
            <span class="stat-label">validi</span>
          </div>
        </div>
        <div class="card-arrow">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <path d="M5 12h14M12 5l7 7-7 7"/>
          </svg>
        </div>
      </div>

      <div class="content-card" @click="router.push('/infermeria/infortunati')">
        <div class="card-glow"></div>
        <div class="card-icon-wrap infortuni">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="32" height="32">
            <path d="M12 2L12 22"/>
            <path d="M12 2L8 6L12 10L16 6Z"/>
            <path d="M8 22L12 18L16 22"/>
            <circle cx="12" cy="15" r="1" fill="currentColor"/>
          </svg>
        </div>
        <div class="card-text">
          <h3 class="card-title">Infortunati</h3>
          <p class="card-desc">Gestione infortuni e recuperi degli atleti</p>
        </div>
        <div class="card-stats">
          <div class="stat-item" :class="{ 'stat-rosso': infortunatiAttivi > 0 }">
            <span class="stat-value">{{ infortunatiAttivi }}</span>
            <span class="stat-label">infortunati</span>
          </div>
        </div>
        <div class="card-arrow">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <path d="M5 12h14M12 5l7 7-7 7"/>
          </svg>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from '../store.js'
import { getCategorie, getPersone, getInfortuni } from '../api/index.js'

const router = useRouter()
const { utenteAttivo, societaAttiva } = useStore()

const categorie = ref([])
const tuttiGiocatori = ref([])
const infortunatiAttivi = ref(0)

const currentSeason = computed(() => {
  const m = new Date().getMonth()
  const y = new Date().getFullYear()
  return m >= 7 ? `${y}/${y + 1}` : `${y - 1}/${y}`
})

const societaId = computed(() => {
  return utenteAttivo.value?.societa_id || parseInt(localStorage.getItem('societa_id')) || 1
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

const scadutiTotali = computed(() => {
  return tuttiGiocatori.value.filter(p => p.scadenza_certificato && isScaduta(p.scadenza_certificato)).length
})

const inScadenzaTotali = computed(() => {
  return tuttiGiocatori.value.filter(p => p.scadenza_certificato && isInScadenza(p.scadenza_certificato)).length
})

const validiTotali = computed(() => {
  return tuttiGiocatori.value.filter(p => p.scadenza_certificato && !isScaduta(p.scadenza_certificato) && !isInScadenza(p.scadenza_certificato)).length
})

onMounted(async () => {
  try {
    const res = await getCategorie()
    let cats = Array.isArray(res) ? res : (res?.data || [])
    categorie.value = cats.filter(c => c.societa_id === societaId.value && !c.is_archiviata)

    for (const cat of categorie.value) {
      const pRes = await getPersone(cat.id)
      const players = Array.isArray(pRes) ? pRes : (pRes?.data || [])
      tuttiGiocatori.value.push(...players)
    }

    const infRes = await getInfortuni({ attivi: true })
    const infData = Array.isArray(infRes) ? infRes : (infRes?.data || [])
    infortunatiAttivi.value = infData.length
  } catch (e) {
    console.error('Errore caricamento:', e)
  }
})
</script>

<style scoped>
.infermeria-page {
  position: relative;
  padding: 2.5rem 2rem 4rem;
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
  width: 500px;
  height: 500px;
  top: -150px;
  right: -80px;
  background: radial-gradient(circle, rgba(16, 185, 129, 0.1) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 400px;
  height: 400px;
  bottom: -100px;
  left: -80px;
  background: radial-gradient(circle, rgba(239, 68, 68, 0.08) 0%, transparent 70%);
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
  margin-bottom: 2.5rem;
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

.header-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: 100px;
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 600;
  color: #10b981;
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10b981;
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
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

.name-gradient {
  background: linear-gradient(135deg, #ffffff 0%, #ffffff 40%, #10b981 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.header-subtitle {
  font-size: 1rem;
  color: var(--color-text-muted);
  font-weight: 400;
}

.content-grid {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
  gap: 1.25rem;
  animation: fadeSlideIn 0.6s ease-out 0.15s both;
}

.content-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1.75rem;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
}

.content-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 20px;
  opacity: 0;
  transition: opacity var(--transition-base);
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.08) 0%, transparent 60%);
}

.content-card:hover {
  transform: translateY(-4px);
  border-color: rgba(16, 185, 129, 0.3);
  box-shadow: 0 8px 32px rgba(16, 185, 129, 0.12), 0 0 0 1px rgba(16, 185, 129, 0.08);
}

.content-card:hover::before {
  opacity: 1;
}

.content-card:hover .card-icon-wrap {
  transform: scale(1.08);
}

.content-card:hover .card-arrow {
  opacity: 1;
  transform: translate(0, 0);
}

.card-glow {
  position: absolute;
  inset: 0;
  opacity: 0;
  transition: opacity var(--transition-base);
  background: radial-gradient(circle at 20% 50%, rgba(16, 185, 129, 0.1) 0%, transparent 60%);
  border-radius: 20px;
}

.card-icon-wrap {
  width: 64px;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 18px;
  border: 1px solid;
  flex-shrink: 0;
  transition: transform var(--transition-base);
}

.card-icon-wrap.certificati {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(16, 185, 129, 0.08) 100%);
  border-color: rgba(16, 185, 129, 0.3);
  color: #10b981;
}

.card-icon-wrap.infortuni {
  background: linear-gradient(135deg, rgba(239, 68, 68, 0.2) 0%, rgba(239, 68, 68, 0.08) 100%);
  border-color: rgba(239, 68, 68, 0.3);
  color: #ef4444;
}

.card-text {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.card-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.01em;
}

.card-desc {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
}

.card-stats {
  display: flex;
  gap: 1rem;
  padding: 0.75rem 0;
}

.stat-item {
  display: flex;
  align-items: baseline;
  gap: 0.35rem;
}

.stat-value {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
}

.stat-label {
  font-size: 0.7rem;
  color: var(--color-text-secondary);
  text-transform: uppercase;
  font-weight: 500;
}

.stat-rosso .stat-value { color: #ef4444; }
.stat-giallo .stat-value { color: #f59e0b; }
.stat-ok .stat-value { color: #10b981; }
.stat-info .stat-value { color: #60a5fa; }

.card-arrow {
  position: absolute;
  right: 1.5rem;
  bottom: 1.5rem;
  opacity: 0;
  transform: translate(-8px, 0);
  transition: all var(--transition-base);
  color: var(--color-text-secondary);
}

.card-badge-soon {
  position: absolute;
  top: 1.5rem;
  right: 1.5rem;
  font-size: 0.65rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 0.25rem 0.625rem;
  background: rgba(245, 158, 11, 0.15);
  border: 1px solid rgba(245, 158, 11, 0.3);
  border-radius: 100px;
  color: #f59e0b;
}

@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

@media (max-width: 768px) {
  .infermeria-page { padding: 1.5rem 1rem 3rem; }
  .content-grid { grid-template-columns: 1fr; }
}

@media (max-width: 480px) {
  .page-title { font-size: 1.75rem; }
  .header-top { flex-direction: column; align-items: flex-start; gap: 0.75rem; }
}
</style>
