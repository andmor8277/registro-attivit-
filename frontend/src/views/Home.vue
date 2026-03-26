<template>
  <div class="home">
    <header class="page-header">
      <h1>Seleziona Categoria</h1>
      <p class="page-subtitle">Scegli una categoria per gestire le presenze</p>
    </header>
    
    <div class="categorie-grid">
      <div 
        v-for="(cat, index) in categorie" 
        :key="cat.id" 
        class="categoria-card"
        :style="{ animationDelay: index * 50 + 'ms' }"
        @click="apriRegistro(cat)"
      >
        <div class="card-accent"></div>
        <div class="card-content">
          <div class="cat-anno">{{ cat.anno }}</div>
          <div class="cat-nome">{{ cat.nome }}</div>
          <div class="cat-giorni" v-if="cat.giorni">
            <span class="giorno-badge" v-for="g in cat.giorni.split(',').slice(0, 3)" :key="g">
              {{ nomiBreviGiorni(parseInt(g)) }}
            </span>
            <span v-if="cat.giorni.split(',').length > 3" class="giorno-badge more">
              +{{ cat.giorni.split(',').length - 3 }}
            </span>
          </div>
          <div class="card-actions" v-if="utenteAttivo?.is_admin || true">
            <button class="btn-icon" @click.stop="apriModifica(cat)" title="Modifica">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
            </button>
            <button v-if="utenteAttivo?.is_admin" class="btn-icon btn-danger" @click.stop="eliminaCategoria(cat.id)" title="Elimina">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                <line x1="10" y1="11" x2="10" y2="17"/>
                <line x1="14" y1="11" x2="14" y2="17"/>
              </svg>
            </button>
          </div>
        </div>
        <div class="card-arrow">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </div>
      </div>
      
      <div class="categoria-card nuova" @click="apriNuova">
        <div class="nuova-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="5" x2="12" y2="19"/>
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
        </div>
        <span>Nuova Categoria</span>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="modal.show" class="modal-overlay" @click.self="chiudiModal">
        <div class="modal" :class="{ 'animate-in': modal.show }">
          <div class="modal-header">
            <h3>{{ modal.id ? 'Modifica Categoria' : 'Nuova Categoria' }}</h3>
            <button class="modal-close" @click="chiudiModal">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          
          <div class="modal-body">
            <div class="form-group">
              <label>Nome</label>
              <input v-model="modal.nome" placeholder="Es. Esordienti" />
            </div>
            <div class="form-group">
              <label>Anno</label>
              <input v-model="modal.anno" placeholder="Es. 2014" type="number" />
            </div>
            <div class="form-group">
              <label>Giorni di allenamento</label>
              <div class="giorni-grid">
                <label v-for="g in tuttiGiorni" :key="g.val" class="giorno-check" :class="{ selected: modal.giorniSel.includes(g.val) }">
                  <input type="checkbox" :value="g.val" v-model="modal.giorniSel" />
                  {{ g.nome }}
                </label>
              </div>
            </div>
          </div>
          
          <div class="modal-footer">
            <button class="btn-secondary" @click="chiudiModal">Annulla</button>
            <button class="btn-primary" @click="salvaCategoria" :disabled="loading">
              <span v-if="loading" class="spinner-small"></span>
              <template v-else>{{ modal.id ? 'Aggiorna' : 'Crea' }}</template>
            </button>
          </div>
          <p v-if="errore" class="errore-msg">{{ errore }}</p>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue"
import { useRouter } from "vue-router"
import { getCategorie, createCategoria, updateCategoria, deleteCategoria } from "../api/index.js"
import { useStore as useCategoria } from "../store.js"
const { utenteAttivo } = useCategoria()

const router = useRouter()
const { setCategoria } = useCategoria()
const categorie = ref([])
const loading = ref(false)
const errore = ref('')

const tuttiGiorni = [
  { val: 1, nome: "Lunedì" },
  { val: 2, nome: "Martedì" },
  { val: 3, nome: "Mercoledì" },
  { val: 4, nome: "Giovedì" },
  { val: 5, nome: "Venerdì" },
  { val: 6, nome: "Sabato" },
  { val: 0, nome: "Domenica" }
]

const nomiBreviGiorni = (val) => tuttiGiorni.find(g => g.val === val)?.nome?.slice(0, 3) || ''

const modal = ref({ show: false, id: null, nome: "", anno: new Date().getFullYear(), giorniSel: [] })

function chiudiModal() {
  modal.value.show = false
  errore.value = ''
}

function apriNuova() {
  modal.value = { show: true, id: null, nome: "", anno: new Date().getFullYear(), giorniSel: [] }
  errore.value = ''
}

function apriModifica(cat) {
  modal.value = {
    show: true, id: cat.id, nome: cat.nome, anno: cat.anno,
    giorniSel: cat.giorni ? cat.giorni.split(",").map(Number) : []
  }
  errore.value = ''
}

async function loadCategorie() {
  const meRes = await import("../api/index.js").then(m => m.getMe())
  const me = meRes.data
  const res = await getCategorie()
  categorie.value = me.is_admin || me.categorie_ids === null
    ? res.data
    : res.data.filter(c => me.categorie_ids.includes(c.id))
}

function apriRegistro(cat) {
  setCategoria(cat)
  router.push("/scelta/" + cat.id)
}

async function salvaCategoria() {
  errore.value = ''
  
  if (!modal.value.nome || !modal.value.anno) {
    errore.value = 'Compila tutti i campi'
    return
  }
  
  loading.value = true
  
  const payload = {
    nome: modal.value.nome,
    anno: parseInt(modal.value.anno),
    giorni: modal.value.giorniSel.sort().join(",") || null
  }
  
  try {
    if (modal.value.id) {
      await updateCategoria(modal.value.id, payload)
    } else {
      await createCategoria(payload)
    }
    modal.value.show = false
    await loadCategorie()
  } catch (e) {
    errore.value = e.response?.data?.detail || 'Errore durante il salvataggio'
  } finally {
    loading.value = false
  }
}

async function eliminaCategoria(id) {
  if (!confirm("Eliminare questa categoria e tutte le presenze?")) return
  await deleteCategoria(id)
  await loadCategorie()
}

onMounted(loadCategorie)
</script>

<style scoped>
.home {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 2rem;
  animation: slideUp 0.4s ease-out;
}

.home h1 {
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

.categorie-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1.25rem;
}

.categoria-card {
  position: relative;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
  animation: slideUp 0.4s ease-out both;
}

.categoria-card:hover {
  border-color: var(--color-primary);
  box-shadow: var(--shadow-lg);
  transform: translateY(-4px);
}

.categoria-card:hover .card-arrow {
  opacity: 1;
  transform: translateX(0);
}

.card-accent {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: linear-gradient(90deg, var(--color-primary), var(--color-primary-light));
}

.card-content {
  position: relative;
  z-index: 1;
}

.cat-anno {
  font-size: 2.5rem;
  font-weight: 800;
  color: var(--color-secondary);
  line-height: 1;
  margin-bottom: 0.5rem;
  letter-spacing: -0.03em;
}

.cat-nome {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-text);
  margin-bottom: 0.75rem;
}

.cat-giorni {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.giorno-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.5rem;
  background: var(--color-bg);
  border-radius: var(--radius-sm);
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-text-secondary);
}

.giorno-badge.more {
  background: var(--color-primary);
  color: white;
}

.card-actions {
  position: absolute;
  top: 1rem;
  right: 1rem;
  display: flex;
  gap: 0.25rem;
  opacity: 0;
  transition: opacity var(--transition-fast);
}

.categoria-card:hover .card-actions {
  opacity: 1;
}

.btn-icon {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  border: none;
  border-radius: var(--radius-sm);
  color: var(--color-text-muted);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-icon:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.btn-icon.btn-danger:hover {
  background: rgba(244, 63, 94, 0.1);
  color: var(--color-error);
}

.btn-icon svg {
  width: 16px;
  height: 16px;
}

.card-arrow {
  position: absolute;
  right: 1.5rem;
  bottom: 1.5rem;
  width: 32px;
  height: 32px;
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
  width: 16px;
  height: 16px;
}

.categoria-card.nuova {
  border-style: dashed;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 180px;
  color: var(--color-text-muted);
  text-align: center;
}

.categoria-card.nuova:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
  background: rgba(16, 185, 129, 0.05);
}

.nuova-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  border-radius: 50%;
  margin-bottom: 0.75rem;
  transition: all var(--transition-base);
}

.categoria-card.nuova:hover .nuova-icon {
  background: var(--color-primary);
  color: white;
}

.nuova-icon svg {
  width: 24px;
  height: 24px;
}

.categoria-card.nuova span {
  font-weight: 600;
  font-size: 0.9375rem;
}

.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(4px);
}

.modal {
  background: var(--color-surface);
  border-radius: var(--radius-xl);
  width: 100%;
  max-width: 480px;
  box-shadow: var(--shadow-xl);
  animation: scaleIn 0.3s ease-out;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 1.5rem 0;
}

.modal-header h3 {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-close {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  border: none;
  border-radius: 50%;
  color: var(--color-text-muted);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.modal-close:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.modal-close svg {
  width: 20px;
  height: 20px;
}

.modal-body {
  padding: 1.5rem;
}

.form-group {
  margin-bottom: 1.25rem;
}

.form-group:last-child {
  margin-bottom: 0;
}

.form-group label {
  display: block;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  margin-bottom: 0.5rem;
}

.form-group input {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 1rem;
  color: var(--color-text);
  background: var(--color-bg);
  transition: all var(--transition-fast);
}

.form-group input:focus {
  outline: none;
  border-color: var(--color-primary);
  background: var(--color-surface);
}

.giorni-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.giorno-check {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-text-secondary);
  transition: all var(--transition-fast);
}

.giorno-check:hover {
  border-color: var(--color-primary);
}

.giorno-check.selected {
  background: rgba(16, 185, 129, 0.1);
  border-color: var(--color-primary);
  color: var(--color-primary-dark);
}

.giorno-check input {
  display: none;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem 1.5rem;
  border-top: 1px solid var(--color-border-light);
}

.btn-secondary {
  padding: 0.75rem 1.25rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-secondary);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-secondary:hover {
  background: var(--color-border);
}

.btn-primary {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 100px;
  padding: 0.75rem 1.5rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-primary:hover:not(:disabled) {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
}

.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.spinner-small {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.errore-msg {
  margin: 0 1.5rem 1.5rem;
  padding: 0.75rem 1rem;
  background: rgba(244, 63, 94, 0.1);
  border: 1px solid rgba(244, 63, 94, 0.2);
  border-radius: var(--radius-md);
  color: var(--color-error);
  font-size: 0.875rem;
  font-weight: 500;
}

@media (max-width: 640px) {
  .home {
    padding: 1.25rem;
  }
  
  .categorie-grid {
    grid-template-columns: 1fr;
  }
}
</style>
