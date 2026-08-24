<template>
  <div class="home">
    <header class="page-header">
      <div class="header-top">
        <div class="header-badge">
          <span class="badge-dot"></span>
          <span>{{ currentSeason }}</span>
        </div>
        <div v-if="isSuperAdmin" class="societa-switch">
          <button class="btn-societa" @click="vaiSelezioneSocieta">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M7 16V4m0 0L3 8m4-4l4 4"/>
              <path d="M17 8v12m0 0l4-4m-4 4l-4-4"/>
            </svg>
            {{ societaAttiva?.nome || 'Cambia Società' }}
          </button>
        </div>
      </div>
      <h1 class="society-name">{{ societaAttiva?.nome || 'Benvenuto' }}</h1>
      <p class="header-subtitle">Pannello di controllo</p>
    </header>

    <div v-if="canInfermeria && infortuniCount > 0" class="alert-strip" @click="router.push('/infermeria')">
      <span class="alert-icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
          <line x1="12" y1="9" x2="12" y2="13"/>
          <line x1="12" y1="17" x2="12.01" y2="17"/>
        </svg>
      </span>
      <span class="alert-text"><strong>{{ infortuniCount }}</strong>&nbsp;{{ infortuniCount === 1 ? 'giocatore infortunato' : 'giocatori infortunati' }} — apri Infermeria</span>
      <span class="alert-arrow">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
      </span>
    </div>

    <section class="op-section">
      <div class="section-header">
        <div class="section-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="20" height="20">
            <circle cx="12" cy="12" r="10"/>
            <polyline points="12 6 12 12 16 14"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Allenamenti di oggi</h2>
          <p class="section-subtitle">{{ oggiLabel }}</p>
        </div>
      </div>

      <div class="panel today-panel">
        <div v-if="oggiCategorie.length" class="today-list">
          <div v-for="cat in oggiCategorie" :key="cat.id" class="today-row">
            <span class="chip-dot" :class="{ portieri: cat.is_portieri }"></span>
            <span class="today-cat">{{ cat.nome }}</span>
            <span class="chip-badge">{{ cat.is_portieri ? 'POR' : cat.anno }}</span>
            <button class="btn-open" @click="apriRegistro(cat)">
              Apri registro
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
            </button>
          </div>
        </div>
        <p v-else class="empty-note">Nessun allenamento in programma oggi</p>
      </div>
    </section>

    <section class="op-section">
      <div class="section-header">
        <div class="section-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="20" height="20">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
            <line x1="16" y1="2" x2="16" y2="6"/>
            <line x1="8" y1="2" x2="8" y2="6"/>
            <line x1="3" y1="10" x2="21" y2="10"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Programmazione settimana</h2>
          <p class="section-subtitle">Tutte le categorie, giorno per giorno</p>
        </div>
      </div>

      <div class="panel week-panel">
        <div
          v-for="giorno in planningSettimana"
          :key="giorno.val"
          class="week-row"
          :class="{ today: isToday(giorno.val), empty: giorno.categorie.length === 0 }"
        >
          <span class="day-name">{{ giorno.nome }}<span v-if="isToday(giorno.val)" class="today-tag">oggi</span></span>
          <div class="chips">
            <span
              v-for="cat in giorno.categorie"
              :key="cat.id"
              class="cat-chip"
              :class="{ portieri: cat.is_portieri }"
              @click="apriRegistro(cat)"
            >
              <span class="chip-dot" :class="{ portieri: cat.is_portieri }"></span>
              {{ cat.nome }}
              <span class="chip-badge">{{ cat.is_portieri ? 'POR' : cat.anno }}</span>
            </span>
            <span v-if="giorno.categorie.length === 0" class="no-cats">—</span>
          </div>
        </div>
      </div>
    </section>

    <section class="op-section">
      <div class="section-header">
        <div class="section-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="20" height="20">
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
        <div class="section-card" @click="router.push('/allenatori')">
          <div class="card-icon-wrap icon-red">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="24" height="24">
              <circle cx="12" cy="12" r="10"/>
              <path d="M12 6v6l4 2"/>
            </svg>
          </div>
          <div class="card-text">
            <h3 class="card-title">Gestione Squadre</h3>
            <p class="card-desc">Allenamenti · Categorie · Presenze</p>
          </div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
          </div>
        </div>

        <div v-if="utenteAttivo?.ruolo === 'segreteria' || utenteAttivo?.is_admin" class="section-card" @click="router.push('/segreteria')">
          <div class="card-icon-wrap icon-purple">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="24" height="24">
              <path d="M17 2H7a2 2 0 00-2 2v16a2 2 0 002 2h10a2 2 0 002-2V4a2 2 0 00-2-2z"/>
              <path d="M12 6v4"/><path d="M12 14h.01"/>
            </svg>
          </div>
          <div class="card-text">
            <h3 class="card-title">Gestione Segreteria</h3>
            <p class="card-desc">Tesseramenti · Documenti · Rate</p>
          </div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
          </div>
        </div>

        <div v-if="utenteAttivo?.is_admin" class="section-card" @click="router.push('/responsabili')">
          <div class="card-icon-wrap icon-amber">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="24" height="24">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87"/>
              <path d="M16 3.13a4 4 0 010 7.75"/>
            </svg>
          </div>
          <div class="card-text">
            <h3 class="card-title">Gestione Responsabili</h3>
            <p class="card-desc">Mister · Dirigenti · Partite</p>
          </div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
          </div>
        </div>

        <div v-if="['infermeria', 'admin', 'super_admin'].includes(utenteAttivo?.ruolo)" class="section-card" @click="router.push('/infermeria')">
          <div class="card-icon-wrap icon-green">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="24" height="24">
              <path d="M9 12l2 2 4-4"/>
              <path d="M12 2a10 10 0 100 20 10 10 0 000-20z"/>
              <path d="M12 6v6"/>
            </svg>
          </div>
          <div class="card-text">
            <h3 class="card-title">Gestione Infermeria</h3>
            <p class="card-desc">Certificati medici · Infortuni</p>
          </div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
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
import { getSocieta, getAllCategorie, getInfortuni } from "../api/index.js"

const router = useRouter()
const { utenteAttivo, societaAttiva, setSocietaAttiva } = useStore()
const isSuperAdmin = computed(() => utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin')
const canInfermeria = computed(() => ['infermeria', 'admin', 'super_admin'].includes(utenteAttivo.value?.ruolo))

const allCategories = ref([])
const infortuniCount = ref(0)

const m = new Date().getMonth() + 1
const currentSeason = ref(`${m >= 8 ? new Date().getFullYear() : new Date().getFullYear() - 1}/${m >= 8 ? new Date().getFullYear() + 1 : new Date().getFullYear()}`)

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

const oggiCategorie = computed(() => {
  const dow = new Date().getDay()
  return allCategories.value.filter(c => {
    if (!c.giorni) return false
    return c.giorni.split(',').map(Number).includes(dow)
  })
})

const oggiLabel = computed(() => {
  const d = new Date()
  const nome = (tuttiGiorni.find(g => g.val === d.getDay()) || {}).nome || ''
  return `${nome} ${d.toLocaleDateString('it-IT', { day: 'numeric', month: 'long' })}`
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
    const activeCat = allCategories.value.find(c => c.parent_id !== null && c.stagione)
    currentSeason.value = activeCat ? `${activeCat.stagione}/${activeCat.stagione + 1}` : currentSeason.value
  } catch (e) {
    console.error('Errore loadPlanning:', e)
  }
}

async function loadInfortuni() {
  if (!canInfermeria.value) return
  try {
    const res = await getInfortuni({ attivi: true })
    infortuniCount.value = (res.data || []).length
  } catch (e) {
    console.error('Errore caricamento infortuni:', e)
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

  loadPlanning()
  loadInfortuni()
})
</script>

<style scoped>
.home {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1080px;
  margin: 0 auto;
}

/* ── Header ── */
.page-header {
  margin-bottom: 1.5rem;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.header-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.3rem 0.8rem;
  background: rgba(220, 38, 38, 0.07);
  border: 1px solid rgba(220, 38, 38, 0.22);
  border-radius: 100px;
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--color-primary);
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--color-primary);
}

.btn-societa {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.45rem 0.9rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  color: var(--color-text-secondary);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-societa:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
}

.society-name {
  font-size: 1.75rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--color-text);
  line-height: 1.15;
  margin-bottom: 0.15rem;
}

.header-subtitle {
  font-size: 0.95rem;
  color: var(--color-text-muted);
  font-weight: 500;
}

/* ── Alert operativi ── */
.alert-strip {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.8rem 1rem;
  margin-bottom: 1.25rem;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: 12px;
  color: #92400e;
  font-size: 0.875rem;
  cursor: pointer;
  transition: box-shadow var(--transition-fast), transform var(--transition-fast);
}

.alert-strip:hover {
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.alert-strip strong {
  font-weight: 800;
}

.alert-icon {
  display: flex;
  align-items: center;
  color: #d97706;
  flex-shrink: 0;
}

.alert-arrow {
  margin-left: auto;
  display: flex;
  align-items: center;
  flex-shrink: 0;
}

/* ── Sezioni operative ── */
.op-section {
  margin-bottom: 2rem;
}

.section-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.85rem;
}

.section-icon {
  width: 38px;
  height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  color: var(--color-primary);
  flex-shrink: 0;
}

.section-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.01em;
}

.section-subtitle {
  font-size: 0.78rem;
  color: var(--color-text-muted);
  margin-top: 0.05rem;
}

.panel {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 14px;
  overflow: hidden;
}

/* Oggi */
.today-list {
  display: flex;
  flex-direction: column;
}

.today-row {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 0.8rem 1rem;
  border-bottom: 1px solid var(--color-border-light);
}

.today-row:last-child {
  border-bottom: none;
}

.today-cat {
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--color-text);
}

.chip-badge {
  font-family: var(--font-mono);
  font-size: 0.62rem;
  font-weight: 700;
  padding: 0.12rem 0.4rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border-light);
  color: var(--color-text-secondary);
  border-radius: 5px;
  letter-spacing: 0.04em;
}

.btn-open {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.85rem;
  background: var(--color-primary);
  border: none;
  border-radius: 8px;
  color: #fff;
  font-size: 0.8rem;
  font-weight: 700;
  cursor: pointer;
  transition: background var(--transition-fast);
}

.btn-open:hover {
  background: var(--color-primary-dark);
}

.empty-note {
  padding: 1.25rem 1rem;
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.chip-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--color-primary);
  flex-shrink: 0;
}

.chip-dot.portieri {
  background: var(--color-accent);
}

/* Settimana */
.week-list {
  display: flex;
  flex-direction: column;
}

.week-row {
  display: flex;
  align-items: baseline;
  gap: 1rem;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--color-border-light);
}

.week-row:last-child {
  border-bottom: none;
}

.week-row.today {
  background: rgba(220, 38, 38, 0.03);
  box-shadow: inset 3px 0 0 var(--color-primary);
}

.week-row.empty {
  opacity: 0.5;
}

.day-name {
  width: 96px;
  flex-shrink: 0;
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--color-text-secondary);
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.week-row.today .day-name {
  color: var(--color-primary);
}

.today-tag {
  font-family: var(--font-mono);
  font-size: 0.58rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  padding: 0.1rem 0.35rem;
  background: var(--color-primary);
  color: #fff;
  border-radius: 4px;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.cat-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.32rem 0.6rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border-light);
  border-radius: 8px;
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--color-text);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.cat-chip:hover {
  border-color: var(--color-primary);
  background: rgba(220, 38, 38, 0.05);
  color: var(--color-primary);
}

.no-cats {
  font-size: 0.8rem;
  color: var(--color-text-muted);
}

/* Sezioni */
.sections-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 0.75rem;
}

.section-card {
  display: flex;
  align-items: center;
  gap: 0.9rem;
  padding: 1.05rem 1.1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 14px;
  cursor: pointer;
  transition: all var(--transition-base);
}

.section-card:hover {
  transform: translateY(-2px);
  border-color: var(--color-text-muted);
  box-shadow: var(--shadow-md);
}

.card-icon-wrap {
  width: 46px;
  height: 46px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 11px;
  flex-shrink: 0;
}

.icon-red { background: rgba(220, 38, 38, 0.08); color: var(--color-primary); }
.icon-purple { background: rgba(124, 58, 237, 0.08); color: #7c3aed; }
.icon-amber { background: rgba(217, 119, 6, 0.1); color: #b45309; }
.icon-green { background: rgba(22, 163, 74, 0.09); color: #15803d; }

.card-text {
  flex: 1;
  min-width: 0;
}

.card-title {
  font-size: 0.98rem;
  font-weight: 700;
  color: var(--color-text);
}

.card-desc {
  font-size: 0.74rem;
  color: var(--color-text-muted);
  margin-top: 0.1rem;
}

.card-arrow {
  color: var(--color-text-muted);
  flex-shrink: 0;
  opacity: 0;
  transform: translateX(-4px);
  transition: all var(--transition-base);
}

.section-card:hover .card-arrow {
  opacity: 1;
  transform: translateX(0);
  color: var(--color-primary);
}

/* ── Responsive ── */
@media (max-width: 768px) {
  .home {
    padding: 1.25rem 0.75rem 2rem;
  }

  .society-name {
    font-size: 1.35rem;
  }

  .header-top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .today-row {
    flex-wrap: wrap;
  }

  .btn-open {
    width: 100%;
    justify-content: center;
    margin-left: 0;
  }

  .week-row {
    flex-direction: column;
    gap: 0.4rem;
  }

  .day-name {
    width: auto;
  }
}
</style>
