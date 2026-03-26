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
        <h3>Crea nuovo utente</h3>
      </div>
      <div class="form-row">
        <div class="input-group">
          <input v-model="nuovo.username" placeholder="Username" />
        </div>
        <div class="input-group">
          <input v-model="nuovo.password" type="password" placeholder="Password" />
        </div>
        <label class="check-admin">
          <input type="checkbox" v-model="nuovo.is_admin" />
          <span class="check-label">Admin</span>
        </label>
        <button class="btn-primary" @click="creaUtente">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="5" x2="12" y2="19"/>
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
          Crea
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
              {{ u.username.charAt(0).toUpperCase() }}
            </div>
            <div class="user-details">
              <span class="user-name">{{ u.username }}</span>
              <span class="badge-admin" v-if="u.is_admin">ADMIN</span>
            </div>
          </div>
          <button class="btn-delete" @click="eliminaUtente(u.id)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="3 6 5 6 21 6"/>
              <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
            </svg>
            Elimina
          </button>
        </div>
        <div v-if="!u.is_admin" class="categorie-assegna">
          <span class="label">Categorie visibili:</span>
          <div class="categorie-grid">
            <label v-for="cat in tutteCategorie" :key="cat.id" class="cat-check" :class="{ selected: u.categorie_ids?.includes(cat.id) }">
              <input type="checkbox" :value="cat.id" v-model="u.categorie_ids" @change="salvaCategorie(u)" />
              <span class="cat-anno">{{ cat.anno }}</span>
              <span class="cat-nome">{{ cat.nome }}</span>
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
import { getUtenti, createUtente, deleteUtente, assegnaCategorie, getCategorie } from '../api/index.js'

const utenti = ref([])
const tutteCategorie = ref([])
const errore = ref('')
const nuovo = ref({ username: '', password: '', is_admin: false })

async function load() {
  const [u, c] = await Promise.all([getUtenti(), getCategorie()])
  utenti.value = u.data
  tutteCategorie.value = c.data
}

async function creaUtente() {
  errore.value = ''
  if (!nuovo.value.username || !nuovo.value.password) { errore.value = 'Compila tutti i campi'; return }
  try {
    await createUtente({ username: nuovo.value.username, password: nuovo.value.password, is_admin: nuovo.value.is_admin ? 1 : 0 })
    nuovo.value = { username: '', password: '', is_admin: false }
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

async function salvaCategorie(u) {
  await assegnaCategorie(u.id, u.categorie_ids)
}

onMounted(load)
</script>

<style scoped>
.admin {
  padding: 2rem;
  max-width: 900px;
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

.form-row {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  flex-wrap: wrap;
}

.input-group {
  flex: 1;
  min-width: 150px;
}

.input-group input {
  width: 100%;
  padding: 0.75rem 1rem;
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

.check-admin {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.check-admin input[type="checkbox"] {
  width: 18px;
  height: 18px;
  accent-color: var(--color-primary);
  cursor: pointer;
}

.check-label {
  font-weight: 500;
  color: var(--color-text-secondary);
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

.users-list .user-card:nth-child(1) { animation-delay: 50ms; }
.users-list .user-card:nth-child(2) { animation-delay: 100ms; }
.users-list .user-card:nth-child(3) { animation-delay: 150ms; }
.users-list .user-card:nth-child(4) { animation-delay: 200ms; }

.user-card {
  animation-delay: 100ms;
}

.user-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
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
  align-items: center;
  gap: 0.5rem;
}

.user-name {
  font-weight: 600;
  font-size: 1rem;
  color: var(--color-text);
}

.badge-admin {
  background: var(--color-secondary);
  color: white;
  font-size: 0.6875rem;
  font-weight: 700;
  padding: 0.25rem 0.5rem;
  border-radius: var(--radius-sm);
  letter-spacing: 0.05em;
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
  .form-row { flex-direction: column; align-items: stretch; }
  .btn-primary { justify-content: center; }
  .user-header { flex-direction: column; align-items: flex-start; gap: 1rem; }
  .btn-delete { align-self: flex-end; }
}
</style>
