<template>
  <div class="infortuni-page">
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
      <span class="page-title">Infortuni</span>
      <div class="header-right">
        <div class="summary-pill">
          <span class="pill-dot" :class="{ 'dot-rosso': attiviCount > 0 }"></span>
          <span>{{ attiviCount }} attivi</span>
        </div>
        <div class="summary-pill pill-storico">
          <span>{{ storicoCount }} totali</span>
        </div>
      </div>
    </header>

    <div class="content">
      <div class="toolbar">
        <div class="select-wrap">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="select-icon">
            <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <polyline points="16 3 21 3 21 8"/>
            <line x1="19" y1="5" x2="19" y2="13"/>
            <line x1="13" y1="5" x2="13" y2="13"/>
          </svg>
          <select v-model="selectedPlayerId" class="select-input" @change="onPlayerSelect">
            <option value="">Aggiungi giocatore infortunato...</option>
            <optgroup v-for="cat in categorieOrdinate" :key="cat.id" :label="cat.nome + ' ' + cat.anno">
              <option v-for="p in getPlayersByCategory(cat.id)" :key="p.id" :value="p.id">
                {{ p.cognome }} {{ p.nome }}
              </option>
            </optgroup>
          </select>
        </div>
      </div>

      <div v-if="newForm" class="new-form-card">
        <div class="player-info">
          <div class="player-avatar">
            {{ newForm.nome.charAt(0) }}{{ newForm.cognome.charAt(0) }}
          </div>
          <div class="player-meta">
            <h3 class="player-name">{{ newForm.cognome }} {{ newForm.nome }}</h3>
            <p class="player-cat">{{ getCategoriaNome(newForm.categoria_id) }}</p>
          </div>
        </div>

        <div class="form-grid">
          <div class="form-field">
            <label>Data infortunio</label>
            <input type="date" v-model="newForm.data_inizio" class="form-input" />
          </div>
          <div class="form-field">
            <label>Giorni di assenza</label>
            <input type="number" v-model.number="newForm.giorni_assenza" min="0" class="form-input" />
          </div>
          <div class="form-field">
            <label>Data recupero prevista</label>
            <input type="date" :value="dataRecuperoPreview" class="form-input form-input-readonly" readonly />
          </div>
          <div class="form-field">
            <label>Tipo infortunio</label>
            <input type="text" v-model="newForm.tipo_infortunio" placeholder="es. Distorsione caviglia" class="form-input" />
          </div>
          <div class="form-field full-width">
            <label>Note</label>
            <textarea v-model="newForm.note" placeholder="Note sull'infortunio..." class="form-textarea"></textarea>
          </div>
        </div>

        <div class="form-actions">
          <button class="btn-form btn-cancel" @click="cancelNewForm">Annulla</button>
          <button class="btn-form btn-save" @click="saveNewInfortunio" :disabled="saving">
            <span v-if="saving" class="spinner-small"></span>
            <template v-else>Registra infortunio</template>
          </button>
        </div>
      </div>

      <div v-if="editingInfortunio" class="edit-card">
        <div class="player-info">
          <div class="player-avatar">
            {{ editingInfortunio.persona_nome.charAt(0) }}{{ editingInfortunio.persona_cognome.charAt(0) }}
          </div>
          <div class="player-meta">
            <h3 class="player-name">{{ editingInfortunio.persona_cognome }} {{ editingInfortunio.persona_nome }}</h3>
            <p class="player-cat">{{ editingInfortunio.categoria_nome }} {{ editingInfortunio.categoria_anno }}</p>
          </div>
        </div>

        <div class="form-grid">
          <div class="form-field">
            <label>Data infortunio</label>
            <input type="date" v-model="editForm.data_inizio" class="form-input" />
          </div>
          <div class="form-field">
            <label>Giorni di assenza</label>
            <input type="number" v-model.number="editForm.giorni_assenza" min="0" class="form-input" />
          </div>
          <div class="form-field">
            <label>Data recupero prevista</label>
            <input type="date" :value="editDataRecuperoPreview" class="form-input form-input-readonly" readonly />
          </div>
          <div class="form-field">
            <label>Tipo infortunio</label>
            <input type="text" v-model="editForm.tipo_infortunio" placeholder="es. Distorsione caviglia" class="form-input" />
          </div>
          <div class="form-field full-width">
            <label>Note</label>
            <textarea v-model="editForm.note" placeholder="Note sull'infortunio..." class="form-textarea"></textarea>
          </div>
        </div>

        <div class="form-actions">
          <button class="btn-form btn-cancel" @click="cancelEdit">Annulla</button>
          <button v-if="editingInfortunio.attivo" class="btn-form btn-close" @click="closeInfortunio">
            Chiudi infortunio
          </button>
          <button class="btn-form btn-save" @click="saveEditInfortunio" :disabled="saving">
            <span v-if="saving" class="spinner-small"></span>
            <template v-else>Salva modifiche</template>
          </button>
        </div>
      </div>

      <div v-else>
        <div class="tabs">
          <button class="tab" :class="{ active: activeTab === 'attivi' }" @click="activeTab = 'attivi'">
            Attivi ({{ attiviCount }})
          </button>
          <button class="tab" :class="{ active: activeTab === 'storico' }" @click="activeTab = 'storico'">
            Storico ({{ storicoCount }})
          </button>
        </div>

        <div v-if="activeTab === 'attivi'" class="table-wrap">
          <table class="infortuni-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Cognome</th>
                <th>Nome</th>
                <th>Categoria</th>
                <th>Tipo</th>
                <th>Inizio</th>
                <th>Giorni</th>
                <th>Recupero</th>
                <th>Note</th>
                <th>Azioni</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(item, idx) in attiviList" :key="item.id" class="infortunato-row" @click="openEdit(item)">
                <td>{{ idx + 1 }}</td>
                <td class="col-cognome">{{ item.persona_cognome }}</td>
                <td>{{ item.persona_nome }}</td>
                <td class="col-cat">{{ item.categoria_nome }} {{ item.categoria_anno }}</td>
                <td class="col-tipo">{{ item.tipo_infortunio || '-' }}</td>
                <td class="col-date">{{ formatDate(item.data_inizio) }}</td>
                <td class="col-giorni">{{ item.giorni_assenza }}</td>
                <td class="col-recupero" :class="{ 'recupero-prossimo': isRecuperoProssimo(item) }">
                  {{ item.data_fine ? formatDate(item.data_fine) : '—' }}
                </td>
                <td class="col-note">{{ item.note || '-' }}</td>
                <td class="col-azioni" @click.stop>
                  <button class="btn-sm btn-edit" @click="openEdit(item)" title="Modifica">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
                    </svg>
                  </button>
                  <button class="btn-sm btn-close-sm" @click="confirmClose(item)" title="Chiudi infortunio">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <polyline points="20 6 9 17 4 12"/>
                    </svg>
                  </button>
                  <button class="btn-sm btn-delete" @click="confirmDelete(item)" title="Elimina">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <polyline points="3 6 5 6 21 6"/>
                      <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                    </svg>
                  </button>
                </td>
              </tr>
              <tr v-if="attiviList.length === 0">
                <td colspan="10" class="no-data">Nessun infortunio attivo. Seleziona un giocatore per aggiungerlo.</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-if="activeTab === 'storico'" class="table-wrap">
          <table class="infortuni-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Cognome</th>
                <th>Nome</th>
                <th>Categoria</th>
                <th>Tipo</th>
                <th>Inizio</th>
                <th>Giorni</th>
                <th>Recupero</th>
                <th>Note</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(item, idx) in storicoList" :key="item.id" class="infortunato-row storico-row">
                <td>{{ idx + 1 }}</td>
                <td class="col-cognome">{{ item.persona_cognome }}</td>
                <td>{{ item.persona_nome }}</td>
                <td class="col-cat">{{ item.categoria_nome }} {{ item.categoria_anno }}</td>
                <td class="col-tipo">{{ item.tipo_infortunio || '-' }}</td>
                <td class="col-date">{{ formatDate(item.data_inizio) }}</td>
                <td class="col-giorni">{{ item.giorni_assenza }}</td>
                <td class="col-recupero">{{ item.data_fine ? formatDate(item.data_fine) : '—' }}</td>
                <td class="col-note">{{ item.note || '-' }}</td>
              </tr>
              <tr v-if="storicoList.length === 0">
                <td colspan="9" class="no-data">Nessun infortunio nello storico.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from '../store.js'
import { getCategorie, getPersone } from '../api/index.js'
import { getInfortuni, creaInfortunio, aggiornaInfortunio, eliminaInfortunio, chiudiInfortunio } from '../api/index.js'

const router = useRouter()
const { utenteAttivo } = useStore()

const categorie = ref([])
const persone = ref([])
const infortuni = ref([])
const selectedPlayerId = ref('')
const activeTab = ref('attivi')
const saving = ref(false)

const newForm = ref(null)
const editingInfortunio = ref(null)
const editForm = ref(null)

const societaId = computed(() => {
  return utenteAttivo.value?.societa_id || parseInt(localStorage.getItem('societa_id')) || 1
})

onMounted(async () => {
  await loadDati()
  await loadInfortuni()
})

async function loadDati() {
  try {
    const res = await getCategorie()
    let cats = Array.isArray(res) ? res : (res?.data || [])
    categorie.value = cats.filter(c => c.societa_id === societaId.value && !c.is_archiviata && !c.is_portieri)

    for (const cat of categorie.value) {
      const pRes = await getPersone(cat.id)
      const players = Array.isArray(pRes) ? pRes : (pRes?.data || [])
      persone.value.push(...players.map(p => ({ ...p, categoria_id: cat.id })))
    }
  } catch (e) {
    console.error('Errore caricamento:', e)
  }
}

async function loadInfortuni() {
  try {
    const res = await getInfortuni()
    const data = Array.isArray(res) ? res : (res?.data || [])
    infortuni.value = data
  } catch (e) {
    console.error('Errore caricamento infortuni:', e)
    infortuni.value = []
  }
}

const attiviList = computed(() => {
  return infortuni.value.filter(i => i.attivo)
})

const storicoList = computed(() => {
  return infortuni.value.filter(i => !i.attivo)
})

const attiviCount = computed(() => attiviList.value.length)
const storicoCount = computed(() => storicoList.value.length)

function getPlayersByCategory(catId) {
  return persone.value.filter(p => p.categoria_id === catId)
}

const categorieOrdinate = computed(() => {
  return [...categorie.value].sort((a, b) => (a.anno || 0) - (b.anno || 0))
})

function getCategoriaNome(catId) {
  const cat = categorie.value.find(c => c.id === catId)
  return cat ? cat.nome + ' ' + cat.anno : ''
}

function formatDate(d) {
  if (!d) return ''
  const parts = d.split('-')
  if (parts.length === 3) return `${parts[2]}/${parts[1]}`
  return d
}

function isRecuperoProssimo(item) {
  if (!item.data_fine) return false
  const fine = new Date(item.data_fine)
  const oggi = new Date()
  oggi.setHours(0, 0, 0, 0)
  const diff = Math.ceil((fine - oggi) / (1000 * 60 * 60 * 24))
  return diff >= 0 && diff <= 3
}

const dataRecuperoPreview = computed(() => {
  if (!newForm.value || !newForm.value.data_inizio || !newForm.value.giorni_assenza || newForm.value.giorni_assenza === 0) return ''
  const d = new Date(newForm.value.data_inizio)
  d.setDate(d.getDate() + newForm.value.giorni_assenza)
  return d.toISOString().split('T')[0]
})

const editDataRecuperoPreview = computed(() => {
  if (!editForm.value || !editForm.value.data_inizio || !editForm.value.giorni_assenza || editForm.value.giorni_assenza === 0) return ''
  const d = new Date(editForm.value.data_inizio)
  d.setDate(d.getDate() + editForm.value.giorni_assenza)
  return d.toISOString().split('T')[0]
})

function onPlayerSelect() {
  if (!selectedPlayerId.value) return
  const p = persone.value.find(pl => pl.id === parseInt(selectedPlayerId.value))
  if (!p) return

  newForm.value = {
    persona_id: p.id,
    id: p.id,
    nome: p.nome,
    cognome: p.cognome,
    categoria_id: p.categoria_id,
    data_inizio: new Date().toISOString().split('T')[0],
    giorni_assenza: 0,
    tipo_infortunio: '',
    note: ''
  }
  selectedPlayerId.value = ''
}

function cancelNewForm() {
  newForm.value = null
}

async function saveNewInfortunio() {
  if (!newForm.value) return
  if (!newForm.value.data_inizio) {
    alert('Inserisci la data dell\'infortunio')
    return
  }
  saving.value = true
  try {
    await creaInfortunio({
      persona_id: newForm.value.persona_id,
      categoria_id: newForm.value.categoria_id,
      data_inizio: newForm.value.data_inizio,
      giorni_assenza: newForm.value.giorni_assenza || 0,
      tipo_infortunio: newForm.value.tipo_infortunio || null,
      note: newForm.value.note || null
    })
    newForm.value = null
    await loadInfortuni()
  } catch (e) {
    alert(e.response?.data?.detail || 'Errore nel salvataggio')
  } finally {
    saving.value = false
  }
}

function openEdit(item) {
  editingInfortunio.value = item
  editForm.value = {
    data_inizio: item.data_inizio,
    giorni_assenza: item.giorni_assenza,
    tipo_infortunio: item.tipo_infortunio || '',
    note: item.note || ''
  }
  activeTab.value = 'attivi'
}

function cancelEdit() {
  editingInfortunio.value = null
  editForm.value = null
}

async function saveEditInfortunio() {
  if (!editingInfortunio.value || !editForm.value) return
  saving.value = true
  try {
    await aggiornaInfortunio(editingInfortunio.value.id, {
      data_inizio: editForm.value.data_inizio,
      giorni_assenza: editForm.value.giorni_assenza,
      tipo_infortunio: editForm.value.tipo_infortunio || null,
      note: editForm.value.note || null
    })
    editingInfortunio.value = null
    editForm.value = null
    await loadInfortuni()
  } catch (e) {
    alert(e.response?.data?.detail || 'Errore nel salvataggio')
  } finally {
    saving.value = false
  }
}

async function confirmClose(item) {
  if (!confirm(`Chiudere l'infortunio di ${item.persona_cognome} ${item.persona_nome}?`)) return
  saving.value = true
  try {
    await chiudiInfortunio(item.id)
    if (editingInfortunio.value && editingInfortunio.value.id === item.id) {
      editingInfortunio.value = null
      editForm.value = null
    }
    await loadInfortuni()
  } catch (e) {
    alert(e.response?.data?.detail || 'Errore')
  } finally {
    saving.value = false
  }
}

async function confirmDelete(item) {
  if (!confirm(`Eliminare definitivamente l'infortunio di ${item.persona_cognome} ${item.persona_nome}?`)) return
  saving.value = true
  try {
    await eliminaInfortunio(item.id)
    if (editingInfortunio.value && editingInfortunio.value.id === item.id) {
      editingInfortunio.value = null
      editForm.value = null
    }
    await loadInfortuni()
  } catch (e) {
    alert(e.response?.data?.detail || 'Errore')
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.infortuni-page {
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

.header-left { display: flex; gap: 0.5rem; }

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
  background: #ef4444;
  border-color: #ef4444;
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

.header-right { display: flex; gap: 0.5rem; }

.summary-pill {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.35rem 0.75rem;
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.2);
  border-radius: 100px;
  font-size: 0.75rem;
  color: var(--color-text-secondary);
}

.summary-pill.pill-storico {
  background: rgba(100, 116, 139, 0.1);
  border-color: rgba(100, 116, 139, 0.2);
}

.pill-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #ef4444;
  animation: pulse 1.5s ease-in-out infinite;
}

.pill-dot.dot-rosso {
  background: #ef4444;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

.content { padding: 1rem; }

.toolbar {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.select-wrap {
  flex: 1;
  min-width: 250px;
  position: relative;
}

.select-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--color-text-secondary);
  pointer-events: none;
}

.select-input {
  width: 100%;
  padding: 0.625rem 1rem 0.625rem 2.25rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
  appearance: none;
  cursor: pointer;
}

.select-input:focus {
  outline: none;
  border-color: #ef4444;
  box-shadow: 0 0 0 2px rgba(239, 68, 68, 0.15);
}

.new-form-card,
.edit-card {
  background: var(--color-surface);
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-border);
  overflow: hidden;
  animation: fadeSlideIn 0.3s ease-out;
  margin-bottom: 1rem;
}

.player-info {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.25rem 1.5rem;
  background: rgba(239, 68, 68, 0.05);
  border-bottom: 1px solid var(--color-border);
}

.player-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: rgba(239, 68, 68, 0.15);
  color: #ef4444;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.9rem;
  flex-shrink: 0;
}

.player-name {
  font-size: 1.1rem;
  font-weight: 700;
  margin: 0;
  color: var(--color-text);
}

.player-cat {
  font-size: 0.8rem;
  color: var(--color-text-secondary);
  margin: 0.15rem 0 0;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  padding: 1.5rem;
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.form-field.full-width {
  grid-column: 1 / -1;
}

.form-field label {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--color-text-secondary);
  letter-spacing: 0.03em;
}

.form-input {
  padding: 0.625rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.9375rem;
  font-weight: 500;
  width: 100%;
  box-sizing: border-box;
}

.form-input:focus {
  outline: none;
  border-color: #ef4444;
  box-shadow: 0 0 0 2px rgba(239, 68, 68, 0.15);
}

.form-input.form-input-readonly {
  background: rgba(239, 68, 68, 0.05);
  color: #ef4444;
  font-weight: 700;
  cursor: default;
  border-color: rgba(239, 68, 68, 0.2);
}

.form-textarea {
  padding: 0.625rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
  min-height: 70px;
  resize: vertical;
  font-family: inherit;
  width: 100%;
  box-sizing: border-box;
}

.form-textarea:focus {
  outline: none;
  border-color: #ef4444;
  box-shadow: 0 0 0 2px rgba(239, 68, 68, 0.15);
}

.form-actions {
  display: flex;
  gap: 0.75rem;
  justify-content: flex-end;
  padding: 0 1.5rem 1.5rem;
}

.btn-form {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.625rem 1.25rem;
  border-radius: var(--radius-md);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  border: none;
}

.btn-form:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-save {
  background: #ef4444;
  color: white;
}

.btn-save:hover:not(:disabled) {
  background: #dc2626;
}

.btn-cancel {
  background: var(--color-bg);
  color: var(--color-text);
  border: 1px solid var(--color-border);
}

.btn-cancel:hover {
  background: var(--color-border);
}

.btn-close {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
  border: 1px solid rgba(16, 185, 129, 0.3);
}

.btn-close:hover {
  background: rgba(16, 185, 129, 0.25);
}

.spinner-small {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.tabs {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.tab {
  padding: 0.5rem 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-secondary);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.tab.active {
  background: rgba(239, 68, 68, 0.1);
  border-color: rgba(239, 68, 68, 0.3);
  color: #ef4444;
}

.tab:hover:not(.active) {
  background: var(--color-border);
}

.table-wrap {
  overflow-x: auto;
  background: var(--color-surface);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
}

.infortuni-table {
  width: 100%;
  border-collapse: collapse;
}

.infortuni-table th {
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

.infortuni-table td {
  padding: 0.625rem 0.75rem;
  border-bottom: 1px solid var(--color-border);
  color: var(--color-text);
  font-size: 0.8rem;
}

.infortunato-row {
  cursor: pointer;
  transition: background-color 0.15s;
}

.infortunato-row:hover {
  background: rgba(239, 68, 68, 0.04);
}

.storico-row {
  opacity: 0.7;
}

.storico-row:hover {
  background: rgba(100, 116, 139, 0.04);
  opacity: 0.85;
}

.col-cognome { font-weight: 600; }

.col-cat {
  color: var(--color-text-secondary);
  font-size: 0.75rem;
}

.col-tipo {
  font-size: 0.75rem;
  color: var(--color-text-secondary);
}

.col-date {
  white-space: nowrap;
  font-size: 0.75rem;
}

.col-giorni {
  font-weight: 700;
  text-align: center;
  color: #ef4444;
}

.col-recupero {
  white-space: nowrap;
  font-size: 0.75rem;
  font-weight: 600;
}

.col-recupero.recupero-prossimo {
  color: #f59e0b;
}

.col-note {
  max-width: 200px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: var(--color-text-secondary);
}

.col-azioni {
  display: flex;
  gap: 0.35rem;
  white-space: nowrap;
}

.btn-sm {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  cursor: pointer;
  transition: all var(--transition-fast);
  color: var(--color-text-secondary);
}

.btn-sm.btn-edit:hover {
  background: rgba(59, 130, 246, 0.1);
  border-color: rgba(59, 130, 246, 0.3);
  color: #3b82f6;
}

.btn-sm.btn-close-sm:hover {
  background: rgba(16, 185, 129, 0.1);
  border-color: rgba(16, 185, 129, 0.3);
  color: #10b981;
}

.btn-sm.btn-delete:hover {
  background: rgba(239, 68, 68, 0.1);
  border-color: rgba(239, 68, 68, 0.3);
  color: #ef4444;
}

.no-data {
  text-align: center;
  padding: 2rem;
  color: var(--color-text-muted);
  font-size: 0.8rem;
}

@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}

@media (max-width: 768px) {
  .toolbar { flex-direction: column; align-items: stretch; }
  .form-grid { grid-template-columns: 1fr; }
  .form-field.full-width { grid-column: auto; }
  .page-header { flex-wrap: wrap; gap: 0.5rem; }
  .header-right { display: none; }
  .form-actions { flex-wrap: wrap; }
  .btn-form { flex: 1; justify-content: center; }
}

@media (max-width: 480px) {
  .content { padding: 0.75rem; }
  .tabs { flex-direction: column; }
}
</style>
