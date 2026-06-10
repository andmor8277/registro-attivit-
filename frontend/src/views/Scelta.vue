<template>
  <div class="scelta-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          <span>{{ categoria?.is_archived ? 'Stagioni Passate' : 'Categorie' }}</span>
        </button>
        <div class="header-badge">
          <span class="badge-dot"></span>
          <span>{{ currentSeason }}</span>
        </div>
      </div>
      <div class="header-main">
        <h1 class="category-name">
          <span class="name-gradient">
            {{ categoria?.is_archived ? categoria?.nome : (categoria?.anno ? categoria?.nome + ' ' + categoria?.anno : categoria?.nome) }}
          </span>
        </h1>
        <p class="header-subtitle" v-if="!categoria?.is_archived">Cosa vuoi gestire?</p>
        <p class="header-subtitle" v-else>Seleziona una categoria</p>
      </div>
    </header>

    <div class="scelta-body">
      
      <div v-if="categoria?.is_archived" class="scelta-grid">
        <div
          v-for="cat in categorieStagione"
          :key="cat.id"
          class="scelta-card archived-cat"
          @click="selezionaCategoria(cat)"
        >
          <div class="card-icon-wrap dati">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
            </svg>
          </div>
          <div class="card-label">{{ cat.nome }}</div>
          <div class="card-desc" v-if="cat.giorni">{{ cat.giorni.split(',').map(g => nomiBreviGiorni(parseInt(g))).join(', ') }}</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>
      </div>
      
      <div v-else class="scelta-grid">
        <div class="scelta-card" @click="router.push('/registro/' + categoria?.id)">
          <div class="card-icon-wrap presenze">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2"/>
              <rect x="9" y="3" width="6" height="4" rx="1"/>
              <path d="M9 12h6M9 16h6"/>
            </svg>
          </div>
          <div class="card-label">Presenze</div>
          <div class="card-desc">Gestisci le presenze degli atleti</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>
        
        <div v-if="!isDirigente && !categoria?.is_portieri" class="scelta-card" @click="router.push('/convocazioni/' + categoria?.id)">
          <div class="card-icon-wrap convocazioni">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M22 17H2a3 3 0 000 6h20a3 3 0 000-6z"/>
              <path d="M6 17V7a2 2 0 012-2h10a2 2 0 012 2v10"/>
              <line x1="12" y1="9" x2="12" y2="13"/>
              <line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
          </div>
          <div class="card-label">Convocazioni</div>
          <div class="card-desc">Crea e gestisci convocazioni</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="!categoria?.is_portieri" class="scelta-card" @click="router.push('/dati/' + categoria?.id)">
          <div class="card-icon-wrap dati">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
              <polyline points="14 2 14 8 20 8"/>
              <line x1="16" y1="13" x2="8" y2="13"/>
              <line x1="16" y1="17" x2="8" y2="17"/>
              <polyline points="10 9 9 9 8 9"/>
            </svg>
          </div>
          <div class="card-label">Dati & Matricole</div>
          <div class="card-desc">Visualizza dati e matricole dei giocatori</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="!isDirigente" class="scelta-card" @click="router.push('/allenamenti/' + categoria?.id)">
          <div class="card-icon-wrap allenamenti">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <circle cx="12" cy="12" r="10"/>
              <path d="M12 6v6l4 2"/>
            </svg>
          </div>
          <div class="card-label">Allenamenti</div>
          <div class="card-desc">Gestisci gli allenamenti della settimana</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="!isDirigente" class="scelta-card" @click="router.push('/reportistica/' + categoria?.id)">
          <div class="card-icon-wrap reportistica">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <line x1="18" y1="20" x2="18" y2="10"/>
              <line x1="12" y1="20" x2="12" y2="4"/>
              <line x1="6" y1="20" x2="6" y2="14"/>
            </svg>
          </div>
          <div class="card-label">Reportistica</div>
          <div class="card-desc">Statistiche e report presenze</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="!isDirigente" class="scelta-card" @click="router.push('/valutazioni/' + categoria?.id)">
          <div class="card-icon-wrap valutazioni">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M9 11l3 3L22 4"/>
              <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11"/>
            </svg>
          </div>
          <div class="card-label">Valutazioni</div>
          <div class="card-desc">Schede valutative giocatori</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
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
import { getCategorieByStagione } from '../api/index.js'
const router = useRouter()
const { categoriaAttiva, setCategoria, utenteAttivo } = useStore()
const categoria = categoriaAttiva
const isDirigente = computed(() => ['dirigente', 'segreteria', 'infermeria'].includes(utenteAttivo.value?.ruolo))
const currentSeason = computed(() => {
  const m = new Date().getMonth()
  const y = new Date().getFullYear()
  return m >= 7 ? `${y}/${y + 1}` : `${y - 1}/${y}`
})
const categorieStagione = ref([])
const loading = ref(false)

const tuttiGiorni = [
  { val: 1, nome: "Lun" },
  { val: 2, nome: "Mar" },
  { val: 3, nome: "Mer" },
  { val: 4, nome: "Gio" },
  { val: 5, nome: "Ven" },
  { val: 6, nome: "Sab" },
  { val: 0, nome: "Dom" }
]

const nomiBreviGiorni = (val) => tuttiGiorni.find(g => g.val === val)?.nome || ''

async function loadCategorieStagione() {
  if (categoria?.is_archived && categoria?.stagione) {
    loading.value = true
    try {
      const res = await getCategorieByStagione(categoria.stagione)
      categorieStagione.value = res.data
    } catch (e) {
      console.error('Errore nel caricamento categorie:', e)
    } finally {
      loading.value = false
    }
  }
}

function selezionaCategoria(cat) {
  setCategoria(cat)
  router.push('/registro/' + cat.id)
}

onMounted(loadCategorieStagione)
</script>

<style scoped>
.scelta-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1100px;
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
  background: radial-gradient(circle, rgba(220, 38, 38, 0.1) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 400px;
  height: 400px;
  bottom: -100px;
  left: -80px;
  background: radial-gradient(circle, rgba(124, 58, 237, 0.08) 0%, transparent 70%);
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

.header-main {
  position: relative;
}

.category-name {
  font-size: clamp(2rem, 6vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.375rem;
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

/* ── Body ── */
.scelta-body {
  position: relative;
  z-index: 1;
  animation: fadeSlideIn 0.6s ease-out 0.15s both;
}

.scelta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.scelta-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1.75rem;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
}

.scelta-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 20px;
  opacity: 0;
  transition: opacity var(--transition-base);
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.08) 0%, transparent 60%);
}

.scelta-card:hover {
  transform: translateY(-4px);
  border-color: rgba(220, 38, 38, 0.3);
  box-shadow: 0 8px 32px rgba(220, 38, 38, 0.12), 0 0 0 1px rgba(220, 38, 38, 0.08);
}

.scelta-card:hover::before {
  opacity: 1;
}

.scelta-card:hover .card-icon-wrap {
  transform: scale(1.08);
}

.scelta-card:hover .card-arrow {
  opacity: 1;
  transform: translate(0, 0);
}

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
  margin-bottom: 0.5rem;
}

.card-icon-wrap.presenze {
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.2) 0%, rgba(220, 38, 38, 0.08) 100%);
  border-color: rgba(220, 38, 38, 0.3);
  color: #ef4444;
}

.card-icon-wrap.convocazioni {
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.2) 0%, rgba(59, 130, 246, 0.08) 100%);
  border-color: rgba(59, 130, 246, 0.3);
  color: #60a5fa;
}

.card-icon-wrap.dati {
  background: linear-gradient(135deg, rgba(234, 179, 8, 0.2) 0%, rgba(234, 179, 8, 0.08) 100%);
  border-color: rgba(234, 179, 8, 0.3);
  color: #fbbf24;
}

.card-icon-wrap.allenamenti {
  background: linear-gradient(135deg, rgba(34, 197, 94, 0.2) 0%, rgba(34, 197, 94, 0.08) 100%);
  border-color: rgba(34, 197, 94, 0.3);
  color: #4ade80;
}

.card-icon-wrap.reportistica {
  background: linear-gradient(135deg, rgba(168, 85, 247, 0.2) 0%, rgba(168, 85, 247, 0.08) 100%);
  border-color: rgba(168, 85, 247, 0.3);
  color: #a78bfa;
}

.card-icon-wrap.valutazioni {
  background: linear-gradient(135deg, rgba(20, 184, 166, 0.2) 0%, rgba(20, 184, 166, 0.08) 100%);
  border-color: rgba(20, 184, 166, 0.3);
  color: #2dd4bf;
}

.card-icon-wrap svg {
  width: 28px;
  height: 28px;
}

.card-label {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.01em;
}

.card-desc {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
}

.card-arrow {
  position: absolute;
  right: 1.5rem;
  bottom: 1.5rem;
  opacity: 0;
  transform: translate(-8px, 0);
  transition: all var(--transition-base);
  color: var(--color-text-secondary);
}

.card-arrow svg {
  width: 20px;
  height: 20px;
}

/* ── Archived cards ── */
.scelta-card.archived-cat {
  background: rgba(255, 255, 255, 0.02);
}

.scelta-card.archived-cat::before {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.08) 0%, transparent 60%);
}

.scelta-card.archived-cat:hover {
  border-color: rgba(245, 158, 11, 0.3);
  box-shadow: 0 8px 32px rgba(245, 158, 11, 0.12), 0 0 0 1px rgba(245, 158, 11, 0.08);
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
@media (max-width: 768px) {
  .scelta-page {
    padding: 1.5rem 1rem 3rem;
  }
  .scelta-grid {
    grid-template-columns: 1fr;
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
