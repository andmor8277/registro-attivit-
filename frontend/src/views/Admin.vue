<template>
  <div class="admin">
    <header class="page-header">
      <h1>Gestione Utenti</h1>
      <p class="page-subtitle">Crea e gestisci gli account degli utenti</p>
    </header>

    <div class="card card-create">
      <div class="card-header">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M16 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
          <circle cx="8.5" cy="7" r="4"/>
          <line x1="20" y1="8" x2="20" y2="14"/>
          <line x1="23" y1="11" x2="17" y2="11"/>
        </svg>
        <h3>{{ editingUtente ? 'Modifica utente' : 'Crea nuovo utente' }}</h3>
      </div>
      <div class="form-grid">
        <div class="input-group">
          <label>Username *</label>
          <input v-model="nuovo.username" placeholder="Username" :disabled="editingUtente" />
        </div>
        <div class="input-group" v-if="!editingUtente">
          <label>Password *</label>
          <input v-model="nuovo.password" type="password" placeholder="Password" />
        </div>
        <div class="input-group">
          <label>Ruolo *</label>
          <select v-model="nuovo.ruolo" class="ruolo-select">
            <option value="">Seleziona ruolo...</option>
            <option value="admin">Admin</option>
            <option value="mister">Mister</option>
            <option value="dirigente">Dirigente</option>
          </select>
        </div>
        <div class="input-group">
          <label>Nome *</label>
          <input v-model="nuovo.nome" placeholder="Nome" />
        </div>
        <div class="input-group">
          <label>Cognome *</label>
          <input v-model="nuovo.cognome" placeholder="Cognome" />
        </div>
        <div class="input-group">
          <label>Data di Nascita *</label>
          <input v-model="nuovo.data_nascita" type="date" />
        </div>
        <div class="input-group">
          <label>Codice Fiscale *</label>
          <input v-model="nuovo.codice_fiscale" placeholder="Codice Fiscale" maxlength="16" />
        </div>
        <div class="input-group">
          <label>Cellulare *</label>
          <input v-model="nuovo.cellulare" placeholder="Numero Cellulare" />
        </div>
        <div class="input-group">
          <label>Tesserino</label>
          <input v-model="nuovo.tesserino" placeholder="Numero Tesserino" />
        </div>
      </div>
      <div class="form-actions">
        <button class="btn-primary" @click="editingUtente ? salvaUtente() : creaUtente()">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
          {{ editingUtente ? 'Salva' : 'Crea' }}
        </button>
        <button v-if="editingUtente" class="btn-secondary" @click="annullaModifica">
          Annulla
        </button>
      </div>
      <p v-if="errore" class="errore">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/>
          <line x1="12" y1="8" x2="12" y2="12"/>
          <line x1="12" y1="16" x2="12.01" y2="16"/>
        </svg>
        {{ errore }}
      </p>
    </div>

    <div class="users-list">
      <div class="card user-card" v-for="u in utenti" :key="u.id">
        <div class="user-header">
          <div class="user-info">
            <div class="user-avatar">
              {{ u.nome ? u.nome.charAt(0).toUpperCase() : u.username.charAt(0).toUpperCase() }}
            </div>
            <div class="user-details">
              <span class="user-name">{{ u.username }}</span>
              <span class="user-fullname">{{ u.nome }} {{ u.cognome }}</span>
              <span class="badge-role badge-admin" v-if="u.ruolo === 'admin'">ADMIN</span>
              <span class="badge-role badge-mister" v-if="u.ruolo === 'mister'">MISTER</span>
              <span class="badge-role badge-dirigente" v-if="u.ruolo === 'dirigente'">DIRIGENTE</span>
            </div>
          </div>
          <div class="user-data">
            <span><strong>CF:</strong> {{ u.codice_fiscale }}</span>
            <span><strong>Cell:</strong> {{ u.cellulare }}</span>
            <span v-if="u.tesserino"><strong>Tess:</strong> {{ u.tesserino }}</span>
            <span><strong>Nato:</strong> {{ formatData(u.data_nascita) }}</span>
          </div>
          <div class="user-actions">
            <button class="btn-edit" @click="modificaUtente(u)" title="Modifica">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
              Modifica
            </button>
            <button class="btn-reset" @click="resetsPassword(u.id)" title="Reset Password">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
              </svg>
              Reset
            </button>
            <button class="btn-delete" @click="eliminaUtente(u.id)">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
              </svg>
              Elimina
            </button>
          </div>
        </div>
        <div v-if="u.ruolo === 'mister' || u.ruolo === 'dirigente'" class="categorie-assegna">
          <span class="label">Assegna a categorie (come Mister):</span>
          <div class="categorie-grid">
            <label v-for="cat in tutteCategorie" :key="cat.id" class="cat-check" :class="{ selected: isMister(u, cat.id) }">
              <input type="checkbox" :value="cat.id" @change="toggleMister(u, cat.id, $event)" />
              <span class="cat-anno">{{ cat.anno }}</span>
              <span class="cat-nome">{{ cat.nome }}</span>
              <span v-if="isMister(u, cat.id) && u.ruolo === 'dirigente'" class="badge-mister" style="background: #2563eb;">DIR</span>
              <span v-else-if="isMister(u, cat.id)" class="badge-mister">MISTER</span>
            </label>
            <span v-if="tutteCategorie.length === 0" class="muted">Nessuna categoria presente</span>
          </div>
        </div>
        <div v-else class="admin-note">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3"/>
            <line x1="12" y1="17" x2="12.01" y2="17"/>
          </svg>
          L'admin vede tutte le categorie
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getUtenti, createUtente, deleteUtente, updateUtente, resetPassword, assegnaCategorie, getCategorie, getCategoriaUtenti } from '../api/index.js'

const utenti = ref([])
const tutteCategorie = ref([])
const errore = ref('')
const editingUtente = ref(null)
const nuovo = ref({ username: '', password: '', nome: '', cognome: '', data_nascita: '', codice_fiscale: '', cellulare: '', tesserino: '', ruolo: '' })

// Track mister assignments: { utenteId: { categoriaId: true/false } }
const misterMap = ref({})

function formatData(d) {
  if (!d) return ''
  return d.split('-').reverse().join('/')
}

function resetForm() {
  nuovo.value = { username: '', password: '', nome: '', cognome: '', data_nascita: '', codice_fiscale: '', cellulare: '', tesserino: '', ruolo: '' }
  editingUtente.value = null
}

function isMister(u, catId) {
  return misterMap.value[u.id]?.[catId] !== undefined
}

async function toggleMister(u, catId, event) {
  const checked = event.target.checked
  if (!misterMap.value[u.id]) {
    misterMap.value[u.id] = {}
  }
  
  if (checked) {
    // Add with the user's ruolo (mister or dirigente)
    misterMap.value[u.id][catId] = u.ruolo || 'mister'
  } else {
    delete misterMap.value[u.id][catId]
  }
  
  // Save to backend - get all category IDs for this user
  const utenteIds = Object.keys(misterMap.value[u.id] || {}).map(id => parseInt(id))
  
  await assegnaCategorie(u.id, utenteIds)
}

async function load() {
  const [u, c] = await Promise.all([getUtenti(), getCategorie()])
  utenti.value = u.data
  tutteCategorie.value = c.data
  
  // Load mister assignments for each category
  for (const cat of c.data) {
    const res = await getCategoriaUtenti(cat.id)
    for (const uid of res.data) {
      if (!misterMap.value[uid]) {
        misterMap.value[uid] = {}
      }
      misterMap.value[uid][cat.id] = true
    }
  }
}

async function creaUtente() {
  errore.value = ''
  const n = nuovo.value
  if (!n.username || !n.password || !n.nome || !n.cognome || !n.data_nascita || !n.codice_fiscale || !n.cellulare || !n.ruolo) {
    errore.value = 'Compila tutti i campi obbligatori (*)' 
    return
  }
  try {
    await createUtente({
      username: n.username,
      password: n.password,
      is_admin: n.ruolo === 'admin' ? 1 : 0,
      nome: n.nome,
      cognome: n.cognome,
      data_nascita: n.data_nascita,
      codice_fiscale: n.codice_fiscale.toUpperCase(),
      cellulare: n.cellulare,
      tesserino: n.tesserino || null,
      ruolo: n.ruolo
    })
    resetForm()
    await load()
  } catch (e) {
    errore.value = e.response?.data?.detail || 'Errore'
  }
}

function modificaUtente(u) {
  editingUtente.value = u.id
  nuovo.value = {
    username: u.username,
    password: '',
    nome: u.nome,
    cognome: u.cognome,
    data_nascita: u.data_nascita,
    codice_fiscale: u.codice_fiscale,
    cellulare: u.cellulare,
    tesserino: u.tesserino || '',
    ruolo: u.ruolo || ''
  }
}

function annullaModifica() {
  resetForm()
}

async function salvaUtente() {
  errore.value = ''
  const n = nuovo.value
  if (!n.nome || !n.cognome || !n.data_nascita || !n.codice_fiscale || !n.cellulare || !n.ruolo) {
    errore.value = 'Compila tutti i campi obbligatori (*)' 
    return
  }
  try {
    await updateUtente(editingUtente.value, {
      nome: n.nome,
      cognome: n.cognome,
      data_nascita: n.data_nascita,
      codice_fiscale: n.codice_fiscale.toUpperCase(),
      cellulare: n.cellulare,
      tesserino: n.tesserino || null,
      ruolo: n.ruolo
    })
    resetForm()
    await load()
  } catch (e) {
    errore.value = e.response?.data?.detail || 'Errore'
  }
}

async function eliminaUtente(id) {
  if (!confirm('Eliminare utente?')) return
  await deleteUtente(id)
  await load()
}

async function resetsPassword(id) {
  if (!confirm('Resettare la password a "password"?')) return
  await resetPassword(id)
  alert('Password resettata! La nuova password è: password')
  await load()
}

onMounted(load)
</script>

<style scoped>
.admin {
  padding: 2rem;
  max-width: 1000px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 2rem;
  animation: slideUp 0.4s ease-out;
}

.admin h1 {
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

.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  margin-bottom: 1rem;
  animation: slideUp 0.4s ease-out both;
}

.card-create {
  margin-bottom: 1.5rem;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.card-header svg {
  width: 24px;
  height: 24px;
  color: var(--color-primary);
}

.card-header h3 {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-text);
  margin: 0;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
  align-items: end;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.input-group label {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.input-group input {
  width: 100%;
  padding: 0.6rem 0.875rem;
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 0.9375rem;
  color: var(--color-text);
  background: var(--color-bg);
  transition: all var(--transition-fast);
}

.input-group input:focus {
  outline: none;
  border-color: var(--color-primary);
  background: var(--color-surface);
}

.input-group input:disabled {
  background: #e0e0e0;
  cursor: not-allowed;
}

.ruolo-select {
  width: 100%;
  padding: 0.6rem 0.875rem;
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 0.9375rem;
  color: var(--color-text);
  background: var(--color-bg);
  cursor: pointer;
}

.ruolo-select:focus {
  outline: none;
  border-color: var(--color-primary);
  background: var(--color-surface);
}

.form-actions {
  margin-top: 1rem;
  display: flex;
  gap: 0.75rem;
}

.btn-primary {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-primary:hover {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
}

.btn-primary svg {
  width: 18px;
  height: 18px;
}

.btn-secondary {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: #6b7280;
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-secondary:hover {
  background: #4b5563;
}

.errore {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1rem;
  padding: 0.75rem 1rem;
  background: rgba(244, 63, 94, 0.1);
  border: 1px solid rgba(244, 63, 94, 0.2);
  border-radius: var(--radius-md);
  color: var(--color-error);
  font-size: 0.875rem;
  font-weight: 500;
}

.errore svg {
  width: 18px;
  height: 18px;
  flex-shrink: 0;
}

.user-card {
  animation-delay: 100ms;
}

.user-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 1rem;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.user-avatar {
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--color-secondary), var(--color-secondary-light));
  border-radius: 50%;
  color: white;
  font-weight: 700;
  font-size: 1.125rem;
}

.user-details {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.user-name {
  font-weight: 600;
  font-size: 1rem;
  color: var(--color-text);
}

.user-fullname {
  font-size: 0.85rem;
  color: var(--color-text-muted);
}

.user-data {
  display: flex;
  gap: 1.5rem;
  font-size: 0.8rem;
  color: var(--color-text-secondary);
}

.user-actions {
  display: flex;
  gap: 0.5rem;
}

.badge-role {
  font-size: 0.6875rem;
  font-weight: 700;
  padding: 0.25rem 0.5rem;
  border-radius: var(--radius-sm);
  letter-spacing: 0.05em;
  width: fit-content;
}

.badge-admin {
  background: #9333ea;
  color: white;
}

.badge-mister {
  background: #dc2626;
  color: white;
}

.badge-dirigente {
  background: #2563eb;
  color: white;
}

.btn-edit {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.875rem;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.3);
  border-radius: var(--radius-md);
  color: #10b981;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-edit:hover {
  background: #10b981;
  border-color: #10b981;
  color: white;
}

.btn-edit svg {
  width: 16px;
  height: 16px;
}

.btn-delete {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.875rem;
  background: rgba(244, 63, 94, 0.1);
  border: 1px solid rgba(244, 63, 94, 0.2);
  border-radius: var(--radius-md);
  color: var(--color-error);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-delete:hover {
  background: var(--color-error);
  border-color: var(--color-error);
  color: white;
}

.btn-delete svg {
  width: 16px;
  height: 16px;
}

.btn-reset {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.875rem;
  background: rgba(59, 130, 246, 0.1);
  border: 1px solid rgba(59, 130, 246, 0.2);
  border-radius: var(--radius-md);
  color: #3b82f6;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-reset:hover {
  background: #3b82f6;
  border-color: #3b82f6;
  color: white;
}

.btn-reset svg {
  width: 16px;
  height: 16px;
}

.categorie-assegna {
  padding-top: 1rem;
  border-top: 1px solid var(--color-border-light);
}

.label {
  display: block;
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--color-text-muted);
  margin-bottom: 0.75rem;
}

.categorie-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.cat-check {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.cat-check:hover {
  border-color: var(--color-primary);
}

.cat-check.selected {
  background: rgba(16, 185, 129, 0.1);
  border-color: var(--color-primary);
}

.cat-check input {
  display: none;
}

.cat-anno {
  font-weight: 700;
  color: var(--color-secondary);
  font-size: 0.875rem;
}

.cat-nome {
  font-size: 0.8125rem;
  color: var(--color-text-secondary);
}

.badge-mister {
  font-size: 0.6rem;
  font-weight: 700;
  background: var(--color-primary);
  color: white;
  padding: 2px 6px;
  border-radius: 4px;
  margin-left: auto;
}

.muted {
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.admin-note {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding-top: 1rem;
  border-top: 1px solid var(--color-border-light);
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.admin-note svg {
  width: 18px;
  height: 18px;
}

@media (max-width: 640px) {
  .admin { padding: 1.25rem; }
  .form-grid { grid-template-columns: 1fr; }
  .user-header { flex-direction: column; align-items: flex-start; }
  .user-data { flex-direction: column; gap: 0.5rem; }
  .btn-delete { align-self: flex-end; }
}
</style>
