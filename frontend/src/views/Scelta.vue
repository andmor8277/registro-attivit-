<template>
  <div class="scelta">
    <div class="scelta-header">
      <button class="btn-back" @click="router.push('/')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="19" y1="12" x2="5" y2="12"/>
          <polyline points="12 19 5 12 12 5"/>
        </svg>
        {{ categoria?.is_archived ? 'Stagioni Passate' : 'Categorie' }}
      </button>
      <h1 v-if="categoria?.is_archived">{{ categoria?.nome }}</h1>
      <h1 v-else>{{ categoria?.nome }} {{ categoria?.anno }}</h1>
      <p class="sottotitolo" v-if="!categoria?.is_archived">Cosa vuoi gestire?</p>
      <p class="sottotitolo archived" v-else>Seleziona una categoria</p>
    </div>
    
    <div v-if="categoria?.is_archived" class="categorie-archived">
      <div 
        v-for="cat in categorieStagione" 
        :key="cat.id" 
        class="scelta-card"
        @click="selezionaCategoria(cat)"
      >
        <div class="card-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
          </svg>
        </div>
        <div class="card-label">{{ cat.nome }}</div>
        <div class="card-desc" v-if="cat.giorni">{{ cat.giorni.split(',').map(g => nomiBreviGiorni(parseInt(g))).join(', ') }}</div>
        <div class="card-arrow">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </div>
      </div>
    </div>
    
    <div v-else class="scelta-grid">
      <div class="scelta-card" @click="router.push('/registro/' + categoria?.id)">
        <div class="card-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2"/>
            <rect x="9" y="3" width="6" height="4" rx="1"/>
            <path d="M9 12h6M9 16h6"/>
          </svg>
        </div>
        <div class="card-label">Presenze</div>
        <div class="card-desc">Gestisci le presenze degli atleti</div>
        <div class="card-arrow">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </div>
      </div>
      
      <div v-if="!isDirigente" class="scelta-card" @click="router.push('/convocazioni/' + categoria?.id)">
        <div class="card-icon accent">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M22 17H2a3 3 0 000 6h20a3 3 0 000-6z"/>
            <path d="M6 17V7a2 2 0 012-2h10a2 2 0 012 2v10"/>
            <line x1="12" y1="9" x2="12" y2="13"/>
            <line x1="12" y1="17" x2="12.01" y2="17"/>
          </svg>
        </div>
        <div class="card-label">Convocazioni</div>
        <div class="card-desc">Crea e gestisci convocazioni</div>
        <div class="card-arrow">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </div>
      </div>

      <div class="scelta-card" @click="router.push('/dati/' + categoria?.id)">
        <div class="card-icon" style="background: rgba(234, 179, 8, 0.1); color: #eab308;">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
            <polyline points="14 2 14 8 20 8"/>
            <line x1="16" y1="13" x2="8" y2="13"/>
            <line x1="16" y1="17" x2="8" y2="17"/>
            <polyline points="10 9 9 9 8 9"/>
          </svg>
        </div>
        <div class="card-label">Dati & Matricole</div>
        <div class="card-desc">Visualizza dati e matricole dei giocatori</div>
        <div class="card-arrow" style="background: #eab308;">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </div>
      </div>

      <div v-if="!isDirigente" class="scelta-card" @click="router.push('/allenamenti/' + categoria?.id)">
        <div class="card-icon" style="background: rgba(34, 197, 94, 0.1); color: #22c55e;">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <polyline points="12 6 12 12 16 14"/>
          </svg>
        </div>
        <div class="card-label">Allenamenti</div>
        <div class="card-desc">Gestisci gli allenamenti della settimana</div>
        <div class="card-arrow" style="background: #22c55e;">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </div>
      </div>

      <div v-if="!isDirigente" class="scelta-card" @click="router.push('/reportistica/' + categoria?.id)">
        <div class="card-icon" style="background: rgba(168, 85, 247, 0.1); color: #a855f7;">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="18" y1="20" x2="18" y2="10"/>
            <line x1="12" y1="20" x2="12" y2="4"/>
            <line x1="6" y1="20" x2="6" y2="14"/>
          </svg>
        </div>
        <div class="card-label">Reportistica</div>
        <div class="card-desc">Statistiche e report presenze</div>
        <div class="card-arrow" style="background: #a855f7;">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
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
import { getCategorieByStagione } from '../api/index.js'
const router = useRouter()
const { categoriaAttiva, setCategoria, utenteAttivo } = useStore()
const categoria = categoriaAttiva
const isDirigente = computed(() => ['dirigente', 'segreteria', 'infermeria'].includes(utenteAttivo.value?.ruolo))
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
.scelta {
  padding: 2rem;
  max-width: 700px;
  margin: 0 auto;
}

.scelta-header {
  text-align: center;
  margin-bottom: 2.5rem;
  animation: slideUp 0.4s ease-out;
}

.btn-back {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
  margin-bottom: 1.5rem;
}

.btn-back:hover {
  background: var(--color-secondary);
  border-color: var(--color-secondary);
  color: white;
}

.btn-back svg {
  width: 16px;
  height: 16px;
}

.scelta h1 {
  font-size: 2rem;
  font-weight: 800;
  color: var(--color-text);
  margin-bottom: 0.5rem;
  letter-spacing: -0.02em;
}

.sottotitolo {
  color: var(--color-text-muted);
  font-size: 1rem;
}

.sottotitolo.archived {
  color: var(--color-text-muted);
}

.categorie-archived {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 1rem;
}

.categorie-archived .scelta-card {
  padding: 1.5rem;
}

.scelta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1.25rem;
}

.scelta-card {
  position: relative;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 2rem;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
  animation: slideUp 0.4s ease-out both;
}

.scelta-card:nth-child(2) {
  animation-delay: 100ms;
}

.scelta-card:hover {
  border-color: var(--color-primary);
  box-shadow: var(--shadow-lg);
  transform: translateY(-4px);
}

.scelta-card:hover .card-arrow {
  opacity: 1;
  transform: translateX(0);
}

.card-icon {
  width: 56px;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(16, 185, 129, 0.1);
  border-radius: var(--radius-md);
  color: var(--color-primary);
  margin-bottom: 1rem;
  transition: all var(--transition-base);
}

.card-icon.accent {
  background: rgba(59, 130, 246, 0.1);
  color: var(--color-info);
}

.scelta-card:hover .card-icon {
  transform: scale(1.05);
}

.card-icon svg {
  width: 28px;
  height: 28px;
}

.card-label {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
  margin-bottom: 0.5rem;
}

.card-desc {
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.card-arrow {
  position: absolute;
  right: 1.5rem;
  bottom: 1.5rem;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-primary);
  border-radius: 50%;
  color: white;
  opacity: 0;
  transform: translateX(-8px);
  transition: all var(--transition-base);
}

.card-arrow svg {
  width: 18px;
  height: 18px;
}

@media (max-width: 640px) {
  .scelta { padding: 1.25rem; }
  .scelta-grid { grid-template-columns: 1fr; }
}
</style>
