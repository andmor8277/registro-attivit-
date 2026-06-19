<template>
  <div class="openday-page">
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
      <span class="page-title">Open Day</span>
      <div class="header-right">
        <div class="summary-pill">
          <span class="pill-dot dot-amber"></span>
          <span>{{ nonIscritti }} in attesa</span>
        </div>
        <div class="summary-pill pill-ok">
          <span>{{ iscritti }} iscritti</span>
        </div>
      </div>
    </header>

    <Teleport to="body">
      <div v-if="showAddForm" class="modal-overlay" @click.self="showAddForm = false">
        <div class="modal">
          <div class="modal-header">
            <h3>Nuovo Interessato</h3>
            <button class="modal-close" @click="showAddForm = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Nome</label>
              <input type="text" v-model="form.nome" class="form-input" placeholder="Nome" />
            </div>
            <div class="form-group">
              <label>Cognome</label>
              <input type="text" v-model="form.cognome" class="form-input" placeholder="Cognome" />
            </div>
            <div class="form-group">
              <label>Data di Nascita</label>
              <input type="date" v-model="form.data_nascita" class="form-input" />
            </div>
            <p v-if="formMsg" class="form-msg">{{ formMsg }}</p>
            <div class="modal-actions">
              <button class="btn-cancel" @click="showAddForm = false">Annulla</button>
              <button class="btn-save" @click="salvaNuovo">Salva</button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <div class="content">
      <div class="toolbar">
        <button class="btn-add" @click="showAddForm = true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="12" y1="5" x2="12" y2="19"/>
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
          Nuovo Interessato
        </button>
        <div class="search-wrap">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="search-icon">
            <circle cx="11" cy="11" r="8"/>
            <line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input type="text" v-model="search" placeholder="Cerca..." class="search-input" />
        </div>
        <div class="filter-group">
          <button class="filter-btn" :class="{ active: filter === 'all' }" @click="filter = 'all'">Tutti</button>
          <button class="filter-btn" :class="{ active: filter === 'pending' }" @click="filter = 'pending'">In Attesa</button>
          <button class="filter-btn" :class="{ active: filter === 'enrolled' }" @click="filter = 'enrolled'">Iscritti</button>
        </div>
      </div>

      <div class="table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>Nome</th>
              <th>Cognome</th>
              <th>Data Nascita</th>
              <th>Anno</th>
              <th>Iscritto</th>
              <th>Categoria</th>
              <th>Azioni</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="entry in filteredEntries" :key="entry.id" :class="{ 'row-enrolled': entry.iscritto }">
              <td class="td-editable" @click="startEdit(entry, 'nome')">
                {{ entry.nome }}
              </td>
              <td class="td-editable" @click="startEdit(entry, 'cognome')">
                {{ entry.cognome }}
              </td>
              <td class="td-editable" @click="startEditDate(entry)">
                {{ formatDate(entry.data_nascita) }}
              </td>
              <td>{{ getAnno(entry.data_nascita) }}</td>
              <td>
                <label class="toggle-switch">
                  <input type="checkbox" :checked="entry.iscritto" @change="toggleIscritto(entry)" />
                  <span class="toggle-slider"></span>
                </label>
              </td>
              <td>
                <span v-if="entry.categoria_nome" class="cat-badge">{{ entry.categoria_nome }} {{ entry.categoria_anno }}</span>
                <span v-else class="cat-none">—</span>
              </td>
              <td class="td-actions">
                <button v-if="!entry.iscritto" class="btn-action btn-enroll" @click="iscrivi(entry)" title="Iscrivi">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                    <path d="M16 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                    <circle cx="8.5" cy="7" r="4"/>
                    <line x1="20" y1="8" x2="20" y2="14"/>
                    <line x1="23" y1="11" x2="17" y2="11"/>
                  </svg>
                  Iscrivi
                </button>
                <button class="btn-action btn-delete" @click="elimina(entry)" title="Elimina">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                    <polyline points="3 6 5 6 21 6"/>
                    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                  </svg>
                </button>
              </td>
            </tr>
            <tr v-if="filteredEntries.length === 0">
              <td colspan="7" class="empty-row">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="40" height="40">
                  <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                  <circle cx="9" cy="7" r="4"/>
                  <path d="M23 21v-2a4 4 0 00-3-3.87"/>
                  <path d="M16 3.13a4 4 0 010 7.75"/>
                </svg>
                <p>Nessun interessato registrato</p>
                <button class="btn-add-inline" @click="showAddForm = true">Aggiungi il primo</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { getOpenday, creaOpenday, eliminaOpenday, iscriviOpenday, aggiornaOpenday } from '../api/index.js'

const router = useRouter()
const entries = ref([])
const search = ref('')
const filter = ref('all')
const showAddForm = ref(false)
const formMsg = ref('')

const form = ref({ nome: '', cognome: '', data_nascita: '' })

const iscritti = computed(() => entries.value.filter(e => e.iscritto).length)
const nonIscritti = computed(() => entries.value.filter(e => !e.iscritto).length)

const filteredEntries = computed(() => {
  let list = entries.value
  if (filter.value === 'pending') list = list.filter(e => !e.iscritto)
  if (filter.value === 'enrolled') list = list.filter(e => e.iscritto)
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(e =>
      e.nome.toLowerCase().includes(q) || e.cognome.toLowerCase().includes(q)
    )
  }
  return list
})

function formatDate(d) {
  if (!d) return '—'
  const dt = new Date(d)
  return dt.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

function getAnno(d) {
  if (!d) return '—'
  return new Date(d).getFullYear()
}

async function carica() {
  try {
    const res = await getOpenday()
    entries.value = Array.isArray(res) ? res : (res?.data || [])
  } catch (e) {
    console.error('Errore caricamento openday:', e)
  }
}

async function salvaNuovo() {
  if (!form.value.nome || !form.value.cognome || !form.value.data_nascita) {
    formMsg.value = 'Compila tutti i campi'
    return
  }
  formMsg.value = ''
  try {
    await creaOpenday({
      nome: form.value.nome.trim(),
      cognome: form.value.cognome.trim(),
      data_nascita: form.value.data_nascita
    })
    form.value = { nome: '', cognome: '', data_nascita: '' }
    showAddForm.value = false
    await carica()
  } catch (e) {
    formMsg.value = 'Errore nel salvataggio'
  }
}

async function elimina(entry) {
  if (!confirm(`Eliminare ${entry.cognome} ${entry.nome}?`)) return
  try {
    await eliminaOpenday(entry.id)
    await carica()
  } catch (e) {
    console.error('Errore eliminazione:', e)
  }
}

async function toggleIscritto(entry) {
  if (entry.iscritto) return
  await iscrivi(entry)
}

async function iscrivi(entry) {
  if (entry.iscritto) return
  try {
    const res = await iscriviOpenday(entry.id)
    if (res.data?.ok) {
      await carica()
    } else {
      alert(res.data?.detail || 'Errore nell\'iscrizione')
    }
  } catch (e) {
    const msg = e.response?.data?.detail || 'Errore nell\'iscrizione'
    alert(msg)
  }
}

function startEdit(entry, field) {
  const val = prompt(`${field === 'nome' ? 'Nome' : 'Cognome'}:`, entry[field])
  if (val !== null && val.trim()) {
    aggiorna(entry, { [field]: val.trim() })
  }
}

function startEditDate(entry) {
  const val = prompt('Data di nascita (YYYY-MM-DD):', entry.data_nascita?.split('T')[0] || '')
  if (val !== null && val.trim()) {
    aggiorna(entry, { data_nascita: val.trim() })
  }
}

async function aggiorna(entry, data) {
  try {
    await aggiornaOpenday(entry.id, data)
    await carica()
  } catch (e) {
    console.error('Errore aggiornamento:', e)
  }
}

onMounted(carica)
</script>

<style scoped>
.openday-page {
  position: relative;
  padding: 2.5rem 2rem 4rem;
  max-width: 1100px;
  margin: 0 auto;
  min-height: 100vh;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 2rem;
}

.header-left { display: flex; gap: 0.5rem; }

.btn-icon {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 10px;
  color: var(--color-text-secondary, #9ca3af);
  cursor: pointer;
  transition: all 0.2s;
}

.btn-icon:hover {
  background: rgba(255,255,255,0.1);
  color: var(--color-text, #fff);
}

.page-title {
  flex: 1;
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--color-text, #fff);
  letter-spacing: -0.02em;
}

.header-right { display: flex; gap: 0.5rem; }

.summary-pill {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.3rem 0.75rem;
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 100px;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-text-secondary, #9ca3af);
}

.summary-pill.pill-ok {
  background: rgba(16,185,129,0.1);
  border-color: rgba(16,185,129,0.2);
  color: #10b981;
}

.pill-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.pill-dot.dot-amber { background: #f59e0b; }

.content {
  position: relative;
  z-index: 1;
}

.toolbar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
  flex-wrap: wrap;
}

.btn-add {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.5rem 1rem;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  border: none;
  border-radius: 10px;
  color: #fff;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-add:hover { transform: translateY(-1px); box-shadow: 0 4px 16px rgba(99,102,241,0.3); }

.search-wrap {
  position: relative;
  flex: 1;
  min-width: 180px;
}

.search-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  width: 14px;
  height: 14px;
  color: var(--color-text-muted, #6b7280);
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 0.5rem 0.75rem 0.5rem 2.25rem;
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 10px;
  color: var(--color-text, #fff);
  font-size: 0.8125rem;
  outline: none;
  transition: border-color 0.2s;
}

.search-input:focus { border-color: rgba(99,102,241,0.5); }

.filter-group { display: flex; gap: 0.25rem; }

.filter-btn {
  padding: 0.4rem 0.75rem;
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 8px;
  color: var(--color-text-secondary, #9ca3af);
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.filter-btn.active {
  background: rgba(99,102,241,0.15);
  border-color: rgba(99,102,241,0.3);
  color: #818cf8;
}

.table-wrap {
  overflow-x: auto;
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 16px;
  background: rgba(255,255,255,0.02);
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8125rem;
}

.data-table th {
  padding: 0.75rem 1rem;
  text-align: left;
  font-weight: 600;
  font-size: 0.6875rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-text-muted, #6b7280);
  border-bottom: 1px solid rgba(255,255,255,0.06);
  white-space: nowrap;
}

.data-table td {
  padding: 0.65rem 1rem;
  color: var(--color-text, #fff);
  border-bottom: 1px solid rgba(255,255,255,0.04);
}

.data-table tbody tr {
  transition: background 0.15s;
}

.data-table tbody tr:hover {
  background: rgba(255,255,255,0.03);
}

.data-table tbody tr.row-enrolled {
  background: rgba(16,185,129,0.04);
}

.td-editable {
  cursor: pointer;
  position: relative;
}

.td-editable:hover {
  color: #818cf8;
}

.td-editable::after {
  content: '✎';
  margin-left: 0.4rem;
  font-size: 0.65rem;
  opacity: 0;
  transition: opacity 0.2s;
  color: #818cf8;
}

.td-editable:hover::after { opacity: 1; }

.toggle-switch {
  position: relative;
  display: inline-block;
  width: 40px;
  height: 22px;
}

.toggle-switch input { opacity: 0; width: 0; height: 0; }

.toggle-slider {
  position: absolute;
  inset: 0;
  background: rgba(255,255,255,0.1);
  border-radius: 11px;
  cursor: pointer;
  transition: 0.2s;
}

.toggle-slider::before {
  content: '';
  position: absolute;
  height: 16px;
  width: 16px;
  left: 3px;
  bottom: 3px;
  background: #fff;
  border-radius: 50%;
  transition: 0.2s;
}

.toggle-switch input:checked + .toggle-slider {
  background: #10b981;
}

.toggle-switch input:checked + .toggle-slider::before {
  transform: translateX(18px);
}

.cat-badge {
  display: inline-block;
  padding: 0.15rem 0.5rem;
  background: rgba(99,102,241,0.12);
  border-radius: 6px;
  font-size: 0.7rem;
  font-weight: 600;
  color: #818cf8;
  white-space: nowrap;
}

.cat-none {
  color: var(--color-text-muted, #6b7280);
}

.td-actions {
  display: flex;
  gap: 0.35rem;
  align-items: center;
}

.btn-action {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.3rem 0.6rem;
  border: none;
  border-radius: 6px;
  font-size: 0.7rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
  white-space: nowrap;
}

.btn-enroll {
  background: rgba(16,185,129,0.12);
  color: #10b981;
}

.btn-enroll:hover { background: rgba(16,185,129,0.25); }

.btn-delete {
  background: rgba(239,68,68,0.1);
  color: #ef4444;
  padding: 0.35rem;
}

.btn-delete:hover { background: rgba(239,68,68,0.25); }

.empty-row {
  text-align: center;
  padding: 3rem 1rem !important;
  color: var(--color-text-muted, #6b7280);
}

.empty-row svg {
  margin-bottom: 0.75rem;
  opacity: 0.4;
}

.empty-row p {
  margin-bottom: 1rem;
  font-size: 0.9rem;
}

.btn-add-inline {
  padding: 0.5rem 1.25rem;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  border: none;
  border-radius: 10px;
  color: #fff;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}

/* Modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.modal {
  background: #1e1e2e;
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 16px;
  width: 100%;
  max-width: 420px;
  overflow: hidden;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid rgba(255,255,255,0.06);
}

.modal-header h3 {
  font-size: 1rem;
  font-weight: 700;
  color: var(--color-text, #fff);
}

.modal-close {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255,255,255,0.05);
  border: none;
  border-radius: 8px;
  color: var(--color-text-secondary, #9ca3af);
  cursor: pointer;
}

.modal-body {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.form-group label {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-secondary, #9ca3af);
}

.form-input {
  padding: 0.5rem 0.75rem;
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 8px;
  color: var(--color-text, #fff);
  font-size: 0.875rem;
  outline: none;
  transition: border-color 0.2s;
}

.form-input:focus { border-color: rgba(99,102,241,0.5); }

.form-msg {
  font-size: 0.75rem;
  color: #ef4444;
  margin: 0;
}

.modal-actions {
  display: flex;
  gap: 0.5rem;
  justify-content: flex-end;
  margin-top: 0.5rem;
}

.btn-cancel {
  padding: 0.5rem 1rem;
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 8px;
  color: var(--color-text-secondary, #9ca3af);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}

.btn-save {
  padding: 0.5rem 1.25rem;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  border: none;
  border-radius: 8px;
  color: #fff;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}

@media (max-width: 768px) {
  .openday-page { padding: 1.5rem 1rem 3rem; }
  .toolbar { flex-direction: column; align-items: stretch; }
  .filter-group { justify-content: center; }
  .btn-add { justify-content: center; }
  .data-table { font-size: 0.75rem; }
  .data-table th, .data-table td { padding: 0.5rem 0.6rem; }
  .btn-enroll span { display: none; }
}
</style>
