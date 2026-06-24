<template>
  <div class="home">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>
    <div class="bg-glow bg-glow-3"></div>

    <header class="page-header">
      <div class="header-top">
        <div class="header-badge">
          <span class="badge-dot"></span>
          <span>{{ currentSeason }}</span>
        </div>
        <div v-if="isSuperAdmin" class="societa-switch">
          <button class="btn-societa" @click="vaiSelezioneSocieta">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <path d="M7 16V4m0 0L3 8m4-4l4 4"/>
              <path d="M17 8v12m0 0l4-4m-4 4l-4-4"/>
            </svg>
            {{ societaAttiva?.nome || 'Cambia Società' }}
          </button>
        </div>
      </div>
      <div class="header-main">
        <h1 class="society-name">
          <span class="name-gradient">{{ societaAttiva?.nome || 'Benvenuto' }}</span>
        </h1>
        <p class="header-subtitle">Pannello di controllo</p>
      </div>
    </header>

    <section class="planning-section">
      <div class="section-header">
        <div class="section-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="22" height="22">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
            <line x1="16" y1="2" x2="16" y2="6"/>
            <line x1="8" y1="2" x2="8" y2="6"/>
            <line x1="3" y1="10" x2="21" y2="10"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Planning Allenamenti</h2>
          <p class="section-subtitle">Programmazione settimanale</p>
        </div>
      </div>

      <div class="planning-grid">
        <div
          v-for="(giorno, idx) in planningSettimana"
          :key="giorno.val"
          class="planning-day"
          :class="{ active: isToday(giorno.val), empty: giorno.categorie.length === 0 }"
          :style="{ animationDelay: idx * 60 + 'ms' }"
        >
          <div class="day-header">
            <span class="day-name">{{ giorno.nome }}</span>
            <div v-if="isToday(giorno.val)" class="today-badge">OGGI</div>
          </div>
          <div class="day-divider"></div>
          <div class="day-content">
            <div
              v-if="giorno.categorie.length > 0"
              class="day-cats"
            >
              <div
                v-for="cat in giorno.categorie"
                :key="cat.id"
                class="cat-chip"
                :class="{ portieri: cat.is_portieri }"
                @click="apriRegistro(cat)"
              >
                <span class="chip-dot" :class="{ portieri: cat.is_portieri }"></span>
                <span class="chip-name">{{ cat.nome }}</span>
                <span class="chip-badge">{{ cat.is_portieri ? 'POR' : cat.anno }}</span>
              </div>
            </div>
            <div v-else class="day-empty">
              <span class="empty-icon">—</span>
              <span class="empty-text">Nessun allenamento</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="sections-section">
      <div class="section-header">
        <div class="section-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="22" height="22">
            <rect x="3" y="3" width="7" height="7" rx="1"/>
            <rect x="14" y="3" width="7" height="7" rx="1"/>
            <rect x="3" y="14" width="7" height="7" rx="1"/>
            <rect x="14" y="14" width="7" height="7" rx="1"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Sezioni</h2>
          <p class="section-subtitle">Naviga per area</p>
        </div>
      </div>

      <div class="sections-grid">
        <div class="section-card allenatori" @click="router.push('/allenatori')">
          <div class="card-glow"></div>
          <div class="card-pattern"></div>
          <div class="card-icon-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <circle cx="12" cy="12" r="10"/>
              <path d="M12 6v6l4 2"/>
            </svg>
          </div>
          <div class="card-text">
            <h3 class="card-title">Allenatori</h3>
            <p class="card-desc">Allenamenti · Categorie · Presenze</p>
          </div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="utenteAttivo?.ruolo === 'segreteria' || utenteAttivo?.is_admin" class="section-card segreteria" @click="router.push('/segreteria')">
          <div class="card-glow"></div>
          <div class="card-pattern"></div>
          <div class="card-icon-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M17 2H7a2 2 0 00-2 2v16a2 2 0 002 2h10a2 2 0 002-2V4a2 2 0 00-2-2z"/>
              <path d="M12 6v4"/>
              <path d="M12 14h.01"/>
            </svg>
          </div>
          <div class="card-text">
            <h3 class="card-title">Segreteria</h3>
            <p class="card-desc">Tesseramenti · Documenti · Rate</p>
          </div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="utenteAttivo?.is_admin" class="section-card responsabili" @click="router.push('/responsabili')">
          <div class="card-glow"></div>
          <div class="card-pattern"></div>
          <div class="card-icon-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87"/>
              <path d="M16 3.13a4 4 0 010 7.75"/>
            </svg>
          </div>
          <div class="card-text">
            <h3 class="card-title">Responsabili</h3>
            <p class="card-desc">Mister · Dirigenti · Partite</p>
          </div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="['infermeria', 'admin', 'super_admin'].includes(utenteAttivo?.ruolo)" class="section-card infermeria" @click="router.push('/infermeria')">
          <div class="card-glow"></div>
          <div class="card-pattern"></div>
          <div class="card-icon-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M9 12l2 2 4-4"/>
              <path d="M12 2a10 10 0 100 20 10 10 0 000-20z"/>
              <path d="M12 6v6"/>
            </svg>
          </div>
          <div class="card-text">
            <h3 class="card-title">Infermeria</h3>
            <p class="card-desc">Certificati medici · Infortuni</p>
          </div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue"
import { useRouter } from "vue-router"
import { useStore } from "../store.js"
import { getSocieta, getAllCategorie, getCategoriaResponsabili } from "../api/index.js"

const router = useRouter()
const { utenteAttivo, societaAttiva, setSocietaAttiva } = useStore()
const isSuperAdmin = computed(() => localStorage.getItem('is_super_admin') === 'true')

const allCategories = ref([])
const responsabileMap = ref({})

const currentSeason = computed(() => {
  const m = new Date().getMonth()
  const y = new Date().getFullYear()
  return m >= 7 ? `${y}/${y + 1}` : `${y - 1}/${y}`
})

const tuttiGiorni = [
  { val: 1, nome: "Lunedì" },
  { val: 2, nome: "Martedì" },
  { val: 3, nome: "Mercoledì" },
  { val: 4, nome: "Giovedì" },
  { val: 5, nome: "Venerdì" },
  { val: 6, nome: "Sabato" },
  { val: 0, nome: "Domenica" }
]

const planningSettimana = computed(() => {
  return tuttiGiorni.map(g => {
    const cats = allCategories.value.filter(c => {
      if (!c.giorni) return false
      const giorniCat = c.giorni.split(',').map(Number)
      return giorniCat.includes(g.val)
    })
    return { ...g, categorie: cats }
  })
})

function isToday(giornoVal) {
  return new Date().getDay() === giornoVal
}

function apriRegistro(cat) {
  router.push("/scelta/" + cat.id)
}

function vaiSelezioneSocieta() {
  router.push('/login')
}

async function loadPlanning() {
  const societaId = societaAttiva.value?.id || null
  try {
    const res = await getAllCategorie(societaId)
    allCategories.value = res.data || []
    for (const cat of allCategories.value) {
      try {
        const respRes = await getCategoriaResponsabili(cat.id)
        if (respRes.data && respRes.data.length > 0) {
          responsabileMap.value[cat.id] = respRes.data
        }
      } catch (e) {}
    }
  } catch (e) {
    console.error('Errore loadPlanning:', e)
  }
}

onMounted(async () => {
  if (!societaAttiva.value) {
    try {
      const res = await getSocieta()
      const data = res.data || []
      if (isSuperAdmin.value && data.length > 0) {
        setSocietaAttiva(data[0])
      } else if (data.length === 1) {
        setSocietaAttiva(data[0])
      }
    } catch (e) {
      console.error('Errore caricamento società:', e)
    }
  }

  // Redirect diretto per ruoli specifici
  const ruolo = utenteAttivo.value?.ruolo
  if (ruolo === 'mister') {
    router.replace('/allenatori')
    return
  }
  if (ruolo === 'segreteria') {
    router.replace('/segreteria')
    return
  }
  if (ruolo === 'infermeria') {
    router.replace('/infermeria')
    return
  }

  loadPlanning()
})
</script>

<style scoped>
.home {
  position: relative;
  padding: 2.5rem 2rem 4rem;
  max-width: 1100px;
  margin: 0 auto;
  overflow: hidden;
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
  width: 600px;
  height: 600px;
  top: -200px;
  right: -100px;
  background: radial-gradient(circle, rgba(220, 38, 38, 0.12) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 500px;
  height: 500px;
  bottom: -150px;
  left: -100px;
  background: radial-gradient(circle, rgba(124, 58, 237, 0.1) 0%, transparent 70%);
  animation: glowFloat 10s ease-in-out infinite reverse;
}

.bg-glow-3 {
  width: 400px;
  height: 400px;
  top: 40%;
  left: 50%;
  transform: translateX(-50%);
  background: radial-gradient(circle, rgba(245, 158, 11, 0.06) 0%, transparent 70%);
  animation: glowFloat 12s ease-in-out infinite 2s;
}

@keyframes glowFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(30px, -20px) scale(1.05); }
  66% { transform: translate(-20px, 15px) scale(0.95); }
}

/* ── Header ── */
.page-header {
  position: relative;
  z-index: 1;
  margin-bottom: 3rem;
  animation: fadeSlideIn 0.7s ease-out both;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
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

.btn-societa {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.6rem 1rem;
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  color: var(--color-text-secondary);
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-societa:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: var(--color-primary);
  color: var(--color-text);
}

.header-main {
  position: relative;
}

.society-name {
  font-size: clamp(2.5rem, 7vw, 4.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.5rem;
}

.name-gradient {
  background: linear-gradient(135deg, #ffffff 0%, #ffffff 40%, var(--color-primary) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.header-subtitle {
  font-size: 1.125rem;
  color: var(--color-text-muted);
  font-weight: 400;
}

/* ── Section Headers ── */
.section-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.section-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.15) 0%, rgba(220, 38, 38, 0.05) 100%);
  border: 1px solid rgba(220, 38, 38, 0.2);
  border-radius: 14px;
  color: var(--color-primary);
}

.section-title {
  font-size: 1.375rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.02em;
}

.section-subtitle {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  margin-top: 0.125rem;
}

/* ── Planning Section ── */
.planning-section {
  position: relative;
  z-index: 1;
  margin-bottom: 3rem;
  animation: fadeSlideIn 0.7s ease-out 0.15s both;
}

.planning-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.75rem;
}

.planning-day {
  position: relative;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 1rem 0.875rem;
  min-height: 140px;
  display: flex;
  flex-direction: column;
  transition: all var(--transition-base);
  animation: fadeSlideIn 0.5s ease-out both;
}

.planning-day:hover {
  border-color: rgba(255, 255, 255, 0.15);
  transform: translateY(-2px);
}

.planning-day.active {
  background: rgba(220, 38, 38, 0.06);
  border-color: rgba(220, 38, 38, 0.3);
  box-shadow: 0 0 30px rgba(220, 38, 38, 0.08);
}

.planning-day.empty {
  opacity: 0.45;
}

.day-header {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  position: relative;
}

.day-name {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text);
}

.planning-day.active .day-name {
  color: var(--color-primary);
}

.day-date {
  font-size: 0.6875rem;
  color: var(--color-text-muted);
}

.today-badge {
  position: absolute;
  top: 0;
  right: 0;
  font-family: var(--font-mono);
  font-size: 0.5625rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  padding: 0.15rem 0.5rem;
  background: var(--color-primary);
  color: white;
  border-radius: 4px;
}

.day-divider {
  height: 1px;
  background: linear-gradient(90deg, var(--color-border) 0%, transparent 100%);
  margin: 0.625rem 0;
}

.planning-day.active .day-divider {
  background: linear-gradient(90deg, rgba(220, 38, 38, 0.4) 0%, transparent 100%);
}

.day-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.day-cats {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.cat-chip {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.4rem 0.5rem;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.cat-chip:hover {
  background: rgba(220, 38, 38, 0.12);
  border-color: rgba(220, 38, 38, 0.4);
  transform: translateX(2px);
}

.cat-chip.portieri:hover {
  background: rgba(245, 158, 11, 0.12);
  border-color: rgba(245, 158, 11, 0.4);
}

.chip-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: var(--color-primary);
  flex-shrink: 0;
}

.chip-dot.portieri {
  background: var(--color-accent);
}

.chip-name {
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--color-text);
  flex: 1;
  line-height: 1.2;
}

.chip-badge {
  font-family: var(--font-mono);
  font-size: 0.5625rem;
  font-weight: 700;
  padding: 0.1rem 0.375rem;
  background: rgba(255, 255, 255, 0.06);
  color: var(--color-text-secondary);
  border-radius: 4px;
  letter-spacing: 0.05em;
  flex-shrink: 0;
}

.cat-chip:hover .chip-badge {
  background: var(--color-primary);
  color: white;
}

.cat-chip.portieri:hover .chip-badge {
  background: var(--color-accent);
}

.day-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.375rem;
  margin-top: auto;
  padding-top: 0.5rem;
}

.empty-icon {
  font-size: 1rem;
  color: var(--color-border);
  font-weight: 300;
}

.empty-text {
  font-size: 0.625rem;
  color: var(--color-text-muted);
  text-align: center;
}

/* ── Sections Grid ── */
.sections-section {
  position: relative;
  z-index: 1;
  animation: fadeSlideIn 0.7s ease-out 0.3s both;
}

.sections-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1rem;
}

.section-card {
  position: relative;
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.5rem;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
}

.section-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 20px;
  opacity: 0;
  transition: opacity var(--transition-base);
}

.section-card:hover {
  transform: translateY(-4px);
  border-color: transparent;
}

.section-card:hover::before {
  opacity: 1;
}

.section-card:hover .card-glow {
  opacity: 1;
}

.section-card:hover .card-arrow {
  opacity: 1;
  transform: translate(0, 0);
}

.section-card:hover .card-icon-wrap {
  transform: scale(1.1);
}

.card-glow {
  position: absolute;
  inset: 0;
  opacity: 0;
  transition: opacity var(--transition-base);
  border-radius: 20px;
}

.card-pattern {
  position: absolute;
  inset: 0;
  opacity: 0.03;
  background-image: radial-gradient(circle at 2px 2px, currentColor 1px, transparent 0);
  background-size: 20px 20px;
  pointer-events: none;
}

/* Allenatori - Red */
.section-card.allenatori::before {
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.12) 0%, rgba(185, 28, 28, 0.04) 100%);
}
.section-card.allenatori .card-glow {
  background: radial-gradient(circle at 20% 50%, rgba(220, 38, 38, 0.15) 0%, transparent 60%);
}
.section-card.allenatori .card-icon-wrap {
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.2) 0%, rgba(220, 38, 38, 0.08) 100%);
  border-color: rgba(220, 38, 38, 0.3);
  color: #ef4444;
}
.section-card.allenatori:hover {
  border-color: rgba(220, 38, 38, 0.3);
  box-shadow: 0 8px 32px rgba(220, 38, 38, 0.15), 0 0 0 1px rgba(220, 38, 38, 0.1);
}
.section-card.allenatori .card-pattern { color: #dc2626; }

/* Segreteria - Purple */
.section-card.segreteria::before {
  background: linear-gradient(135deg, rgba(124, 58, 237, 0.12) 0%, rgba(109, 40, 217, 0.04) 100%);
}
.section-card.segreteria .card-glow {
  background: radial-gradient(circle at 20% 50%, rgba(124, 58, 237, 0.15) 0%, transparent 60%);
}
.section-card.segreteria .card-icon-wrap {
  background: linear-gradient(135deg, rgba(124, 58, 237, 0.2) 0%, rgba(124, 58, 237, 0.08) 100%);
  border-color: rgba(124, 58, 237, 0.3);
  color: #a78bfa;
}
.section-card.segreteria:hover {
  border-color: rgba(124, 58, 237, 0.3);
  box-shadow: 0 8px 32px rgba(124, 58, 237, 0.15), 0 0 0 1px rgba(124, 58, 237, 0.1);
}
.section-card.segreteria .card-pattern { color: #7c3aed; }

/* Responsabili - Amber */
.section-card.responsabili::before {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.12) 0%, rgba(217, 119, 6, 0.04) 100%);
}
.section-card.responsabili .card-glow {
  background: radial-gradient(circle at 20% 50%, rgba(245, 158, 11, 0.15) 0%, transparent 60%);
}
.section-card.responsabili .card-icon-wrap {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.2) 0%, rgba(245, 158, 11, 0.08) 100%);
  border-color: rgba(245, 158, 11, 0.3);
  color: #fbbf24;
}
.section-card.responsabili:hover {
  border-color: rgba(245, 158, 11, 0.3);
  box-shadow: 0 8px 32px rgba(245, 158, 11, 0.15), 0 0 0 1px rgba(245, 158, 11, 0.1);
}
.section-card.responsabili .card-pattern { color: #f59e0b; }

/* Infermeria - Green */
.section-card.infermeria::before {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.12) 0%, rgba(5, 150, 105, 0.04) 100%);
}
.section-card.infermeria .card-glow {
  background: radial-gradient(circle at 20% 50%, rgba(16, 185, 129, 0.15) 0%, transparent 60%);
}
.section-card.infermeria .card-icon-wrap {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(16, 185, 129, 0.08) 100%);
  border-color: rgba(16, 185, 129, 0.3);
  color: #10b981;
}
.section-card.infermeria:hover {
  border-color: rgba(16, 185, 129, 0.3);
  box-shadow: 0 8px 32px rgba(16, 185, 129, 0.15), 0 0 0 1px rgba(16, 185, 129, 0.1);
}
.section-card.infermeria .card-pattern { color: #10b981; }

.card-icon-wrap {
  width: 56px;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
  border: 1px solid;
  flex-shrink: 0;
  transition: transform var(--transition-base);
}

.card-text {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.card-title {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.01em;
}

.card-desc {
  font-size: 0.75rem;
  color: var(--color-text-muted);
}

.card-arrow {
  opacity: 0;
  transform: translate(-8px, 0);
  transition: all var(--transition-base);
  color: var(--color-text-secondary);
  flex-shrink: 0;
}

/* ── Animations ── */
@keyframes fadeSlideIn {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* ── Responsive ── */
@media (max-width: 1024px) {
  .planning-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

@media (max-width: 768px) {
  .home {
    padding: 1.5rem 1rem 3rem;
  }
  .planning-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 0.5rem;
  }
  .planning-day {
    padding: 0.75rem 0.625rem;
    min-height: 110px;
  }
  .sections-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 480px) {
  .planning-grid {
    grid-template-columns: 1fr;
  }
  .society-name {
    font-size: 2rem;
  }
  .header-top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }
}
</style>
