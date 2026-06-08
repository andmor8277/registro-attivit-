<template>
  <div class="responsabili">
    <header class="page-header">
      <div class="header-content">
        <div>
          <h1>Responsabili</h1>
          <p class="page-subtitle">Gestione responsabili, programmazione partite e stagioni</p>
        </div>
        <button class="btn-back" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
      </div>
    </header>

    <div class="hub-grid">
      <div class="hub-card categorie" @click="router.push('/responsabili/categorie')">
        <div class="card-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 00-3-3.87"/>
            <path d="M16 3.13a4 4 0 010 7.75"/>
          </svg>
        </div>
        <div class="card-content">
          <span class="card-title">Responsabili per Categoria</span>
          <span class="card-desc">Assegna mister e dirigenti alle categorie</span>
        </div>
        <div class="card-arrow">→</div>
      </div>

      <div class="hub-card partite" @click="router.push('/responsabili/partite')">
        <div class="card-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/>
            <path d="M2 12h20"/>
          </svg>
        </div>
        <div class="card-content">
          <span class="card-title">Programmazione Partite</span>
          <span class="card-desc">Calendario partite fine settimana</span>
        </div>
        <div class="card-arrow">→</div>
      </div>

      <div class="hub-card spogliatoi" @click="router.push('/responsabili/spogliatoi')">
        <div class="card-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
        </div>
        <div class="card-content">
          <span class="card-title">Spogliatoi e Campi</span>
          <span class="card-desc">Assegnazione settimanale e weekend</span>
        </div>
        <div class="card-arrow">→</div>
      </div>

      <div class="hub-card presenze-allenatori" @click="router.push('/responsabili/presenze-allenatori')">
        <div class="card-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 00-3-3.87"/>
            <path d="M16 3.13a4 4 0 010 7.75"/>
          </svg>
        </div>
        <div class="card-content">
          <span class="card-title">Presenze Allenatori</span>
          <span class="card-desc">Registro presenze allenatori e collaboratori</span>
        </div>
        <div class="card-arrow">→</div>
      </div>

      <div v-if="utenteAttivo?.is_admin" class="hub-card gestione-stagione" @click="apriGestioneStagione">
        <div class="card-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <path d="M12 6v6l4 2"/>
          </svg>
        </div>
        <div class="card-content">
          <span class="card-title">Gestione Stagione</span>
          <span class="card-desc">Inizializza o archivia una stagione</span>
        </div>
        <div class="card-arrow">→</div>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="gestioneStagioneModal.show" class="modal-overlay" @click.self="chiudiGestioneStagione">
        <div class="modal">
          <div class="modal-header">
            <h3>Gestione Stagione</h3>
            <button class="modal-close" @click="chiudiGestioneStagione">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-menu-list">
            <button class="modal-menu-item" @click="selezionaAzione('inizializza')">
              <div class="modal-menu-icon" style="background: rgba(59, 130, 246, 0.15); color: #3b82f6;">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                  <circle cx="12" cy="12" r="10"/>
                  <path d="M12 6v6l4 2"/>
                </svg>
              </div>
              <div class="modal-menu-text">
                <span class="modal-menu-title">Inizializza Stagione</span>
                <span class="modal-menu-desc">Imposta stagione per tutte le categorie</span>
              </div>
            </button>
            <button v-if="stagioniDisponibili.length > 0" class="modal-menu-item" @click="selezionaAzione('archivia')">
              <div class="modal-menu-icon" style="background: rgba(245, 158, 11, 0.15); color: #f59e0b;">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                  <path d="M21 8v13H3V8M1 3h22v5H1z"/>
                </svg>
              </div>
              <div class="modal-menu-text">
                <span class="modal-menu-title">Archivia Stagione</span>
                <span class="modal-menu-desc">Archivia una stagione passata</span>
              </div>
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <Teleport to="body">
      <div v-if="stagioneModal.show" class="modal-overlay" @click.self="stagioneModal.show = false">
        <div class="modal">
          <div class="modal-header">
            <h3>Imposta Stagione per Tutte le Categorie</h3>
            <button class="modal-close" @click="stagioneModal.show = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <p class="modal-info">Questa operazione assegnerà la stessa stagione a tutte le categorie attive.</p>
            <div class="form-group">
              <label>Stagione Calcistica</label>
              <select v-model="stagioneModal.stagione">
                <option v-for="s in stagioniOptions" :key="s" :value="s">{{ s }}/{{ s + 1 }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Inizio Stagione</label>
              <input v-model="stagioneModal.data_inizio_stagione" type="date" />
            </div>
            <div class="form-group">
              <label>Fine Stagione</label>
              <input v-model="stagioneModal.data_fine_stagione" type="date" />
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="stagioneModal.show = false">Annulla</button>
            <button class="btn-primary" @click="impostaStagioneTutte" :disabled="stagioneModal.loading">
              <span v-if="stagioneModal.loading" class="spinner-small"></span>
              <template v-else>Applica a Tutti</template>
            </button>
          </div>
          <p v-if="stagioneModal.errore" class="errore-msg">{{ stagioneModal.errore }}</p>
        </div>
      </div>
    </Teleport>

    <Teleport to="body">
      <div v-if="archiviaModal.show" class="modal-overlay" @click.self="archiviaModal.show = false">
        <div class="modal">
          <div class="modal-header">
            <h3>Archivia Stagione</h3>
            <button class="modal-close" @click="archiviaModal.show = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <p class="modal-info">Seleziona la stagione da archiviare. Le categorie diventeranno visibili solo nella sezione "Stagioni Passate".</p>
            <div class="form-group">
              <label>Stagione</label>
              <select v-model="archiviaModal.stagione">
                <option v-for="s in stagioniDisponibili" :key="s" :value="s">
                  {{ s }}/{{ s + 1 }}
                </option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="archiviaModal.show = false">Annulla</button>
            <button class="btn-archive" @click="confermaArchiviazione" :disabled="archiviaModal.loading">
              <span v-if="archiviaModal.loading" class="spinner-small"></span>
              <template v-else>Archivia</template>
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue"
import { useRouter } from "vue-router"
import { useStore } from "../store.js"
import { getAllCategorie, updateCategoria, archiviaStagione } from "../api/index.js"

const router = useRouter()
const { utenteAttivo, societaAttiva } = useStore()

const categorie = ref([])

const stagioniDisponibili = computed(() => {
  const stagioniSet = new Set()
  categorie.value.forEach(c => {
    if (c.stagione) stagioniSet.add(c.stagione)
  })
  return Array.from(stagioniSet).sort((a, b) => b - a)
})

const stagioniOptions = computed(() => {
  const currentYear = new Date().getFullYear()
  const options = []
  for (let y = currentYear + 1; y >= 2020; y--) {
    options.push(y)
  }
  return options
})

const gestioneStagioneModal = ref({ show: false })
const stagioneModal = ref({ show: false, stagione: new Date().getFullYear(), data_inizio_stagione: '', data_fine_stagione: '', loading: false, errore: '' })
const archiviaModal = ref({ show: false, loading: false, stagione: null })

async function loadCategorie() {
  try {
    const societaId = societaAttiva.value?.id || null
    const res = await getAllCategorie(societaId)
    categorie.value = res.data || []
  } catch (e) {
    console.error('Errore loadCategorie:', e)
  }
}

function apriGestioneStagione() {
  gestioneStagioneModal.value.show = true
}

function chiudiGestioneStagione() {
  gestioneStagioneModal.value.show = false
}

function selezionaAzione(azione) {
  gestioneStagioneModal.value.show = false
  if (azione === 'inizializza') {
    apriImpostaStagione()
  } else if (azione === 'archivia') {
    apriArchiviazione()
  }
}

function apriImpostaStagione() {
  const categorieConStagione = categorie.value.filter(c => c.stagione)
  const primaCat = categorieConStagione.length > 0 ? categorieConStagione[0] : null
  stagioneModal.value = {
    show: true,
    stagione: primaCat?.stagione || new Date().getFullYear(),
    data_inizio_stagione: primaCat?.data_inizio_stagione || '',
    data_fine_stagione: primaCat?.data_fine_stagione || '',
    loading: false,
    errore: ''
  }
}

async function impostaStagioneTutte() {
  if (!stagioneModal.value.stagione) {
    stagioneModal.value.errore = 'Inserisci la stagione'
    return
  }

  if (!confirm(`Impostare la stagione ${stagioneModal.value.stagione}/${stagioneModal.value.stagione + 1} per tutte le ${categorie.value.length} categorie?`)) {
    return
  }

  stagioneModal.value.loading = true
  stagioneModal.value.errore = ''

  try {
    for (const cat of categorie.value) {
      await updateCategoria(cat.id, {
        nome: cat.nome,
        anno: cat.anno,
        stagione: parseInt(stagioneModal.value.stagione),
        giorni: cat.giorni,
        is_portieri: cat.is_portieri === 1,
        data_inizio_stagione: stagioneModal.value.data_inizio_stagione || null,
        data_fine_stagione: stagioneModal.value.data_fine_stagione || null
      })
    }
    stagioneModal.value.show = false
    await loadCategorie()
  } catch (e) {
    stagioneModal.value.errore = e.response?.data?.detail || 'Errore durante il salvataggio'
  } finally {
    stagioneModal.value.loading = false
  }
}

function apriArchiviazione() {
  if (stagioniDisponibili.value.length === 0) {
    alert('Nessuna stagione da archiviare. Le categorie devono avere una stagione assegnata.')
    return
  }

  archiviaModal.value = {
    show: true,
    loading: false,
    stagione: stagioniDisponibili.value[0]
  }
}

async function confermaArchiviazione() {
  if (!archiviaModal.value.stagione) return

  archiviaModal.value.loading = true
  try {
    await archiviaStagione(archiviaModal.value.stagione)
    archiviaModal.value.show = false
    await loadCategorie()
  } catch (e) {
    alert('Errore: ' + (e.response?.data?.detail || 'Errore sconosciuto'))
  } finally {
    archiviaModal.value.loading = false
  }
}

onMounted(() => {
  loadCategorie()
})
</script>

<style scoped>
.responsabili {
  padding: 2rem;
  max-width: 900px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 2rem;
  animation: slideUp 0.4s ease-out;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.header-content h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.02em;
  margin-bottom: 0.25rem;
}

.page-subtitle {
  color: var(--color-text-muted);
  font-size: 1rem;
}

.btn-back {
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
  flex-shrink: 0;
}

.btn-back:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-back svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
}

.hub-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.25rem;
}

.hub-card {
  position: relative;
  display: flex;
  align-items: center;
  gap: 1rem;
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  cursor: pointer;
  transition: all var(--transition-base);
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  animation: slideUp 0.4s ease-out both;
}

.hub-card:hover {
  transform: translateY(-4px);
  border-color: transparent;
}

.hub-card.categorie .card-icon { background: rgba(245, 158, 11, 0.15); }
.hub-card.categorie .card-icon svg { color: #f59e0b; }
.hub-card.categorie:hover { border-color: rgba(245, 158, 11, 0.3); box-shadow: 0 8px 20px rgba(245, 158, 11, 0.12); }

.hub-card.partite .card-icon { background: rgba(34, 197, 94, 0.15); }
.hub-card.partite .card-icon svg { color: #22c55e; }
.hub-card.partite:hover { border-color: rgba(34, 197, 94, 0.3); box-shadow: 0 8px 20px rgba(34, 197, 94, 0.12); }

.hub-card.stagione .card-icon { background: rgba(59, 130, 246, 0.15); }
.hub-card.stagione .card-icon svg { color: #3b82f6; }
.hub-card.stagione:hover { border-color: rgba(59, 130, 246, 0.3); box-shadow: 0 8px 20px rgba(59, 130, 246, 0.12); }

.hub-card.spogliatoi .card-icon { background: rgba(139, 92, 246, 0.15); }
.hub-card.spogliatoi .card-icon svg { color: #8b5cf6; }
.hub-card.spogliatoi:hover { border-color: rgba(139, 92, 246, 0.3); box-shadow: 0 8px 20px rgba(139, 92, 246, 0.12); }

.hub-card.presenze-allenatori .card-icon { background: rgba(6, 182, 212, 0.15); }
.hub-card.presenze-allenatori .card-icon svg { color: #06b6d4; }
.hub-card.presenze-allenatori:hover { border-color: rgba(6, 182, 212, 0.3); box-shadow: 0 8px 20px rgba(6, 182, 212, 0.12); }

.hub-card.gestione-stagione .card-icon { background: rgba(59, 130, 246, 0.15); }
.hub-card.gestione-stagione .card-icon svg { color: #3b82f6; }
.hub-card.gestione-stagione:hover { border-color: rgba(59, 130, 246, 0.3); box-shadow: 0 8px 20px rgba(59, 130, 246, 0.12); }

.hub-card .card-icon {
  width: 56px;
  height: 56px;
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.hub-card .card-icon svg {
  width: 28px;
  height: 28px;
}

.hub-card .card-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.hub-card .card-title {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}

.hub-card .card-desc {
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.hub-card .card-arrow {
  font-size: 1.5rem;
  color: var(--color-primary);
  transition: transform var(--transition-base);
}

.hub-card:hover .card-arrow {
  transform: translateX(4px);
}

/* ── Modals ── */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  animation: fadeIn 0.2s ease-out;
}

.modal {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  width: 90%;
  max-width: 440px;
  animation: slideUp 0.3s ease-out;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.25rem;
}

.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-close {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  cursor: pointer;
  color: var(--color-text-muted);
  border-radius: var(--radius-sm);
  transition: all var(--transition-fast);
}

.modal-close:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.modal-close svg {
  width: 18px;
  height: 18px;
}

.modal-body {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1.25rem;
}

.modal-info {
  font-size: 0.875rem;
  color: var(--color-text-secondary);
  line-height: 1.5;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.form-group label {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.form-group select,
.form-group input {
  padding: 0.625rem 0.75rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
  font-family: inherit;
  transition: border-color var(--transition-fast);
}

.form-group select:focus,
.form-group input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
}

.btn-primary,
.btn-secondary,
.btn-archive {
  padding: 0.625rem 1.25rem;
  border-radius: var(--radius-md);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  font-family: inherit;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-primary {
  background: var(--color-primary);
  color: white;
  border: none;
}

.btn-primary:hover {
  opacity: 0.9;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  background: var(--color-bg);
  color: var(--color-text-secondary);
  border: 1px solid var(--color-border);
}

.btn-secondary:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.btn-archive {
  background: rgba(245, 158, 11, 0.1);
  border: 1px solid rgba(245, 158, 11, 0.3);
  color: #f59e0b;
}

.btn-archive:hover {
  background: rgba(245, 158, 11, 0.2);
}

.btn-archive:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.spinner-small {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

.errore-msg {
  margin-top: 0.75rem;
  font-size: 0.8125rem;
  color: #ef4444;
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.modal-menu-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.modal-menu-item {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  text-align: left;
  font-family: inherit;
}

.modal-menu-item:hover {
  border-color: var(--color-primary);
  background: var(--color-surface);
  transform: translateX(4px);
}

.modal-menu-icon {
  width: 44px;
  height: 44px;
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.modal-menu-text {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.modal-menu-title {
  font-size: 1rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-menu-desc {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
}

@media (max-width: 640px) {
  .responsabili {
    padding: 1.25rem;
  }
}
</style>
