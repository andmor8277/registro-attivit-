<template>
  <div class="home">
    <!-- Page head -->
    <div class="home-head">
      <div class="home-head-txt">
        <h1 class="society-name">{{ societaAttiva?.nome || 'Benvenuto' }}</h1>
        <p class="header-subtitle">Pannello di controllo · {{ oggiLabel }}</p>
      </div>
      <div class="home-head-actions">
        <span class="season-pill">{{ currentSeason }}</span>
        <button v-if="isSuperAdmin" class="btn-societa" @click="vaiSelezioneSocieta">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M7 16V4m0 0L3 8m4-4l4 4"/>
            <path d="M17 8v12m0 0l4-4m-4 4l-4-4"/>
          </svg>
          {{ societaAttiva?.nome_breve || 'Cambia Società' }}
        </button>
      </div>
    </div>

    <div class="grid">
      <!-- Oggi al campo -->
      <section class="card span2">
        <div class="card-h">
          <h2>Oggi al campo</h2>
          <span class="card-date">{{ oggiLabel }}</span>
        </div>
        <div class="card-body">
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

      <!-- Prossima gara -->
      <section class="card">
        <div class="card-h">
          <h2>Prossima gara</h2>
          <span v-if="prossimaGara" class="pill pill-blue">{{ countdown }}</span>
        </div>
        <div class="card-body">
          <div v-if="prossimaGara" class="match-box">
            <div class="match-teams">
              <span class="team">{{ prossimaGara.casa_fuori === 'fuori' ? (prossimaGara.avversario || 'TBD') : (societaAttiva?.nome_breve || 'Noi') }}</span>
              <span class="match-vs">vs</span>
              <span class="team">{{ prossimaGara.casa_fuori === 'fuori' ? (societaAttiva?.nome_breve || 'Noi') : (prossimaGara.avversario || 'TBD') }}</span>
            </div>
            <div class="match-meta">
              <span class="meta-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>
                {{ dataGaraLabel }}
              </span>
              <span v-if="prossimaGara.ora" class="meta-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/></svg>
                {{ prossimaGara.ora.slice(0, 5) }}
              </span>
              <span v-if="prossimaGara.campo" class="meta-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M21 10c0 7-9 12-9 12s-9-5-9-12a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>
                {{ prossimaGara.campo }}
              </span>
              <span class="pill pill-violet" v-if="categoriaGaraNome">{{ prossimaGara.casa_fuori === 'fuori' ? 'Trasferta' : 'Casa' }} · {{ categoriaGaraNome }}</span>
            </div>
          </div>
          <p v-else class="empty-note">Nessuna gara in programma</p>
        </div>
      </section>

      <!-- Da controllare -->
      <section class="card">
        <div class="card-h">
          <h2>Da controllare</h2>
        </div>
        <div class="card-body">
          <div v-if="canInfermeria || canSegreteria" class="check-list">
            <button v-if="canInfermeria && infortuniCount > 0" class="check-row" @click="router.push('/infermeria')">
              <span class="check-ic red">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M12 21C7 17 3 13.5 3 9.5A5.5 5.5 0 0113.6 6H12a5.5 5.5 0 018 3.5c0 4-4 7.5-8 11.5z"/></svg>
              </span>
              <span class="check-label"><strong>{{ infortuniCount }}</strong>&nbsp;{{ infortuniCount === 1 ? 'giocatore infortunato' : 'giocatori infortunati' }}</span>
              <svg class="check-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><path d="M9 18l6-6-6-6"/></svg>
            </button>
            <button v-if="canSegreteria && certScaduti > 0" class="check-row" @click="router.push('/infermeria/certificati')">
              <span class="check-ic amber">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M14 3H6a2 2 0 00-2 2v14a2 2 0 002 2h12a2 2 0 002-2V9l-6-6z"/><path d="M14 3v6h6M9 15l2 2 4-4"/></svg>
              </span>
              <span class="check-label"><strong>{{ certScaduti }}</strong>&nbsp;{{ certScaduti === 1 ? 'certificato scaduto' : 'certificati scaduti' }}</span>
              <svg class="check-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><path d="M9 18l6-6-6-6"/></svg>
            </button>
            <p v-if="!((canInfermeria && infortuniCount > 0) || (canSegreteria && certScaduti > 0))" class="empty-note">Tutto in ordine</p>
          </div>
          <p v-else class="empty-note">Nessuna voce da controllare</p>
        </div>
      </section>

      <!-- Azioni rapide -->
      <section class="card span2">
        <div class="card-h">
          <h2>Azioni rapide</h2>
        </div>
        <div class="card-body">
          <div class="quick-grid">
            <button class="quick" @click="apriRegistroPrimo">
              <span class="quick-ic red">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M8 9h8M8 13h5M14 16l2 2 3-3"/></svg>
              </span>
              <span>Apri registro</span>
            </button>
            <button class="quick" @click="vaiConvocazioni">
              <span class="quick-ic blue">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M4 6h16M4 12h16M4 18h10"/></svg>
              </span>
              <span>Convocazioni</span>
            </button>
            <button class="quick" @click="router.push('/allenatori')">
              <span class="quick-ic violet">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><circle cx="9" cy="8" r="3.2"/><path d="M3.5 20c0-3 2.5-5 5.5-5s5.5 2 5.5 5"/><circle cx="17" cy="9" r="2.5"/><path d="M15.5 15.3c2.7.4 4.5 2.2 4.5 4.7"/></svg>
              </span>
              <span>Gestione squadre</span>
            </button>
            <button v-if="canSegreteria" class="quick" @click="router.push('/segreteria')">
              <span class="quick-ic green">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M17 2H7a2 2 0 00-2 2v16a2 2 0 002 2h10a2 2 0 002-2V4a2 2 0 00-2-2z"/><path d="M9 8h6M9 12h6M9 16h3"/></svg>
              </span>
              <span>Segreteria</span>
            </button>
            <button v-if="canInfermeria" class="quick" @click="router.push('/infermeria')">
              <span class="quick-ic amber">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M12 9v8M8 13h8"/></svg>
              </span>
              <span>Infermeria</span>
            </button>
          </div>
        </div>
      </section>

      <!-- Programmazione settimana -->
      <section class="card span2">
        <div class="card-h">
          <h2>Programmazione settimana</h2>
          <span class="card-date">Tutte le categorie</span>
        </div>
        <div class="card-body">
          <div class="week-list">
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
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue"
import { useRouter } from "vue-router"
import { useStore } from "../store.js"
import { getSocieta, getAllCategorie, getInfortuni, getPartite, getPersone } from "../api/index.js"

const router = useRouter()
const { utenteAttivo, societaAttiva, setSocietaAttiva } = useStore()
const isSuperAdmin = computed(() => utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin')
const canInfermeria = computed(() => ['infermeria', 'admin', 'super_admin'].includes(utenteAttivo.value?.ruolo))
const canSegreteria = computed(() => ['segreteria', 'admin', 'super_admin'].includes(utenteAttivo.value?.ruolo))

const allCategories = ref([])
const partite = ref([])
const infortuniCount = ref(0)
const certScaduti = ref(0)

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

function apriRegistroPrimo() {
  const cat = allCategories.value.find(c => c.parent_id !== null) || allCategories.value[0]
  if (cat) router.push("/scelta/" + cat.id)
  else router.push("/allenatori")
}

function vaiConvocazioni() {
  const cat = allCategories.value.find(c => c.parent_id !== null) || allCategories.value[0]
  if (cat) router.push("/convocazioni/" + cat.id)
  else router.push("/allenatori")
}

function vaiSelezioneSocieta() {
  router.push('/login')
}

// ── Prossima gara ──
const prossimaGara = computed(() => {
  const now = new Date()
  const future = partite.value
    .filter(p => p.data_partite && !p.risultato)
    .map(p => {
      const d = new Date(p.data_partite + 'T' + (p.ora ? p.ora.slice(0, 5) : '00:00'))
      return { ...p, _dt: isNaN(d) ? null : d }
    })
    .filter(p => p._dt && p._dt > now)
  if (!future.length) return null
  future.sort((a, b) => a._dt - b._dt)
  return future[0]
})

const categoriaGaraNome = computed(() => {
  if (!prossimaGara.value) return ''
  const cat = allCategories.value.find(c => c.id === prossimaGara.value.categoria_id)
  return cat?.nome || ''
})

const dataGaraLabel = computed(() => {
  if (!prossimaGara.value) return ''
  const d = new Date(prossimaGara.value.data_partite)
  return d.toLocaleDateString('it-IT', { weekday: 'short', day: 'numeric', month: 'short' })
})

const countdown = computed(() => {
  if (!prossimaGara.value?._dt) return ''
  const diff = prossimaGara.value._dt - new Date()
  const days = Math.floor(diff / 86400000)
  const hours = Math.floor((diff % 86400000) / 3600000)
  if (days > 0) return `Tra ${days}g ${hours}h`
  if (hours > 0) return `Tra ${hours}h`
  return 'Oggi'
})

// ── Certificati scaduti ──
function isCertScaduto(dateStr) {
  if (!dateStr) return false
  const d = new Date(dateStr)
  const today = new Date(); today.setHours(0, 0, 0, 0)
  return !isNaN(d) && d < today
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

async function loadPartite() {
  try {
    const res = await getPartite()
    partite.value = res.data || []
  } catch (e) {
    console.error('Errore caricamento partite:', e)
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

async function loadCertificati() {
  if (!canSegreteria.value) return
  try {
    const res = await getPersone()
    const list = res.data || []
    certScaduti.value = list.filter(p => isCertScaduto(p.scadenza_certificato)).length
  } catch (e) {
    console.error('Errore caricamento certificati:', e)
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
  loadPartite()
  loadInfortuni()
  loadCertificati()
})
</script>

<style scoped>
.home {
  position: relative;
  padding: 1.25rem 1.5rem 3rem;
  max-width: 1180px;
  margin: 0 auto;
}

/* ── Head ── */
.home-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
  margin-bottom: 1.1rem;
}

.society-name {
  font-size: clamp(1.35rem, 2.6vw, 1.7rem);
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--color-text);
  line-height: 1.1;
}

.header-subtitle {
  font-size: 0.86rem;
  color: var(--color-text-secondary);
  font-weight: 500;
  margin-top: 3px;
}

.home-head-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.season-pill {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--color-primary-dark);
  background: var(--color-primary-soft);
  border-radius: 999px;
  padding: 5px 12px;
}

.btn-societa {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.9rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border-strong);
  border-radius: 10px;
  color: var(--color-text);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-societa:hover {
  border-color: var(--color-primary);
  color: var(--color-primary-dark);
}

/* ── Grid ── */
.grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 16px;
}

@media (min-width: 900px) {
  .grid {
    grid-template-columns: 2fr 1fr;
  }
  .span2 {
    grid-column: span 2;
  }
}

.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  box-shadow: var(--shadow);
  min-width: 0;
}

.card-h {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 14px 18px;
  border-bottom: 1px solid var(--color-border);
}

.card-h h2 {
  font-size: 0.95rem;
  font-weight: 700;
  letter-spacing: -0.01em;
}

.card-date {
  font-size: 0.76rem;
  color: var(--color-text-muted);
  font-weight: 600;
}

.card-body {
  padding: 16px 18px;
}

.empty-note {
  color: var(--color-text-muted);
  font-size: 0.85rem;
  padding: 6px 0;
}

/* ── Oggi al campo ── */
.today-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.today-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 13px;
  background: var(--color-slate-soft);
  border: 1px solid var(--color-border);
  border-radius: 11px;
}

.chip-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--color-primary);
  flex-shrink: 0;
}

.chip-dot.portieri {
  background: var(--color-violet);
}

.today-cat {
  font-weight: 700;
  font-size: 0.9rem;
  color: var(--color-text);
}

.chip-badge {
  font-family: var(--font-mono);
  font-size: 0.66rem;
  font-weight: 700;
  color: var(--color-text-muted);
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 2px 7px;
}

.btn-open {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: var(--color-primary);
  color: #fff;
  border: none;
  border-radius: 9px;
  padding: 8px 13px;
  font-size: 0.8rem;
  font-weight: 700;
  cursor: pointer;
  transition: background var(--transition-fast), transform 0.1s ease;
}

.btn-open:hover {
  background: var(--color-primary-dark);
}

.btn-open:active {
  transform: scale(0.97);
}

/* ── Prossima gara ── */
.match-box {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.match-teams {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.team {
  flex: 1;
  text-align: center;
  font-weight: 800;
  font-size: 1rem;
  color: var(--color-text);
  letter-spacing: -0.01em;
}

.match-vs {
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--color-text-muted);
  background: var(--color-slate-soft);
  border-radius: 999px;
  padding: 3px 9px;
  flex-shrink: 0;
}

.match-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.meta-item {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--color-text-secondary);
}

/* ── Da controllare ── */
.check-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.check-row {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  text-align: left;
  padding: 11px 13px;
  background: var(--color-slate-soft);
  border: 1px solid var(--color-border);
  border-radius: 11px;
  cursor: pointer;
  transition: border-color var(--transition-fast), background var(--transition-fast);
}

.check-row:hover {
  border-color: var(--color-border-strong);
  background: var(--color-border-light);
}

.check-ic {
  width: 34px;
  height: 34px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.check-ic.red {
  background: var(--color-primary-soft);
  color: var(--color-primary-dark);
}

.check-ic.amber {
  background: var(--color-warning-soft);
  color: var(--color-warning);
}

.check-label {
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--color-text);
  flex: 1;
}

.check-label strong {
  font-weight: 800;
}

.check-arrow {
  color: var(--color-text-muted);
  flex-shrink: 0;
}

/* ── Azioni rapide ── */
.quick-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
}

@media (min-width: 600px) {
  .quick-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

@media (min-width: 900px) {
  .quick-grid {
    grid-template-columns: repeat(5, 1fr);
  }
}

.quick {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 9px;
  padding: 15px 10px;
  background: var(--color-surface);
  border: 1px solid var(--color-border-strong);
  border-radius: 11px;
  font-size: 0.82rem;
  font-weight: 700;
  color: var(--color-text);
  cursor: pointer;
  transition: border-color var(--transition-fast), background var(--transition-fast), transform 0.1s ease;
}

.quick:hover {
  border-color: var(--color-text);
  background: var(--color-slate-soft);
}

.quick:active {
  transform: scale(0.98);
}

.quick-ic {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.quick-ic.red { background: var(--color-primary-soft); color: var(--color-primary-dark); }
.quick-ic.blue { background: var(--color-info-soft); color: var(--color-info); }
.quick-ic.green { background: var(--color-success-soft); color: var(--color-success); }
.quick-ic.amber { background: var(--color-warning-soft); color: var(--color-warning); }
.quick-ic.violet { background: var(--color-violet-soft); color: var(--color-violet); }

/* ── Programmazione settimana ── */
.week-list {
  display: flex;
  flex-direction: column;
}

.week-row {
  display: grid;
  grid-template-columns: 108px 1fr;
  gap: 12px;
  align-items: center;
  padding: 10px 4px;
  border-bottom: 1px solid var(--color-border);
}

.week-row:last-child {
  border-bottom: none;
}

.week-row.today {
  background: var(--color-primary-soft);
  border-radius: 9px;
  padding: 10px 8px;
  border-bottom-color: transparent;
}

.week-row.empty {
  opacity: 0.55;
}

.day-name {
  font-weight: 700;
  font-size: 0.84rem;
  color: var(--color-text-secondary);
  display: flex;
  align-items: center;
  gap: 6px;
}

.week-row.today .day-name {
  color: var(--color-primary-dark);
}

.today-tag {
  font-size: 0.6rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #fff;
  background: var(--color-primary);
  border-radius: 999px;
  padding: 2px 7px;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.cat-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--color-text);
  background: var(--color-slate-soft);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  padding: 5px 11px;
  cursor: pointer;
  transition: border-color var(--transition-fast), background var(--transition-fast);
}

.cat-chip:hover {
  border-color: var(--color-primary);
  background: var(--color-primary-soft);
}

.cat-chip .chip-badge {
  background: transparent;
  border: none;
  padding: 0;
}

.no-cats {
  color: var(--color-text-muted);
  font-size: 0.8rem;
}

@media (max-width: 600px) {
  .week-row {
    grid-template-columns: 1fr;
    gap: 6px;
  }
}
</style>
