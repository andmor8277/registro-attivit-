<template>
  <div class="admin">
    <header class="page-header">
      <h1>Gestione Società</h1>
      <p class="page-subtitle">Crea e gestisci le società sportive</p>
    </header>

    <div class="card card-create">
      <div class="card-header">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
          <polyline points="9 22 9 12 15 12 15 22"/>
        </svg>
        <h3>{{ editing ? 'Modifica società' : 'Crea nuova società' }}</h3>
      </div>
      <div class="form-grid">
        <div class="input-group">
          <label>Nome Società *</label>
          <input v-model="nuovo.nome" placeholder="Es. RedTigers 1957" />
        </div>
        <div class="input-group">
          <label>Nome Breve</label>
          <input v-model="nuovo.nome_breve" placeholder="Es. RedTigers" />
        </div>
        <div class="input-group">
          <label>Colore Primario</label>
          <div class="color-input">
            <input type="color" v-model="nuovo.colore_primario" />
            <input v-model="nuovo.colore_primario" placeholder="#dc2626" />
          </div>
        </div>
        <div class="input-group">
          <label>Colore Secondario</label>
          <div class="color-input">
            <input type="color" v-model="nuovo.colore_secondario" />
            <input v-model="nuovo.colore_secondario" placeholder="#1f2937" />
          </div>
        </div>
        <div class="input-group">
          <label>Logo</label>
          <input v-model="nuovo.logo" placeholder="nomefile.jpg" />
        </div>
        <div class="input-group">
          <label>Logo Sponsor</label>
          <input v-model="nuovo.logosponsor" placeholder="nomefile.png" />
        </div>
      </div>
      <div class="form-actions">
        <button class="btn-secondary" @click="resetForm" v-if="editing">Annulla</button>
        <button class="btn-primary" @click="salva">
          {{ editing ? 'Salva modifiche' : 'Crea società' }}
        </button>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
          <polyline points="9 22 9 12 15 12 15 22"/>
        </svg>
        <h3>Società esistenti</h3>
      </div>
      <table class="data-table">
        <thead>
          <tr>
            <th>Colore</th>
            <th>Nome</th>
            <th>Nome Breve</th>
            <th>Logo</th>
            <th>Logo Sponsor</th>
            <th>Azioni</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in societa" :key="s.id">
            <td>
              <div class="color-badge" :style="{ background: s.colore_primario }"></div>
            </td>
            <td>{{ s.nome }}</td>
            <td>{{ s.nome_breve || '-' }}</td>
            <td>{{ s.logo || '-' }}</td>
            <td>{{ s.logosponsor || '-' }}</td>
            <td>
              <div class="action-btns">
                <button class="btn-icon" @click="modifica(s)" title="Modifica">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                    <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
                  </svg>
                </button>
                <button class="btn-icon btn-danger" @click="elimina(s.id)" title="Elimina" v-if="societa.length > 1">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="3 6 5 6 21 6"/>
                    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                  </svg>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getSocieta, createSocieta, updateSocieta, deleteSocieta } from '../api/index.js'

const societa = ref([])
const editing = ref(null)
const nuovo = ref({
  nome: '',
  nome_breve: '',
  logo: '',
  logosponsor: '',
  colore_primario: '#dc2626',
  colore_secondario: '#1f2937'
})

async function load() {
  const res = await getSocieta()
  societa.value = res.data
}

function resetForm() {
  editing.value = null
  nuovo.value = {
    nome: '',
    nome_breve: '',
    logo: '',
    logosponsor: '',
    colore_primario: '#dc2626',
    colore_secondario: '#1f2937'
  }
}

function modifica(s) {
  editing.value = s.id
  nuovo.value = { ...s }
}

async function salva() {
  if (!nuovo.value.nome) {
    alert('Inserisci il nome della società')
    return
  }
  
  if (editing.value) {
    await updateSocieta(editing.value, nuovo.value)
  } else {
    await createSocieta(nuovo.value)
  }
  
  await load()
  resetForm()
}

async function elimina(id) {
  if (!confirm('Eliminare questa società? Attenzione: tutti i dati associati verranno eliminati!')) return
  await deleteSocieta(id)
  await load()
}

onMounted(load)
</script>

<style scoped>
.admin {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 2rem;
}

.page-header h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: #fff;
  margin-bottom: 0.5rem;
}

.page-subtitle {
  color: #888;
  font-size: 0.9375rem;
}

.card {
  background: #1a1a1a;
  border: 1px solid #333;
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  margin-bottom: 1.5rem;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #333;
}

.card-header svg {
  width: 24px;
  height: 24px;
  color: #dc2626;
}

.card-header h3 {
  font-size: 1.125rem;
  font-weight: 600;
  color: #fff;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.input-group label {
  font-size: 0.875rem;
  font-weight: 500;
  color: #aaa;
}

.input-group input, .input-group select {
  padding: 0.75rem 1rem;
  background: #0d0d0d;
  border: 2px solid #333;
  border-radius: var(--radius-md);
  color: #fff;
  font-size: 0.9375rem;
}

.input-group input:focus {
  outline: none;
  border-color: #dc2626;
}

.color-input {
  display: flex;
  gap: 0.5rem;
}

.color-input input[type="color"] {
  width: 50px;
  padding: 0.25rem;
  cursor: pointer;
}

.form-actions {
  display: flex;
  gap: 1rem;
  justify-content: flex-end;
}

.btn-primary {
  padding: 0.75rem 1.5rem;
  background: #dc2626;
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-weight: 600;
  cursor: pointer;
}

.btn-secondary {
  padding: 0.75rem 1.5rem;
  background: #333;
  border: none;
  border-radius: var(--radius-md);
  color: #fff;
  font-weight: 600;
  cursor: pointer;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
}

.data-table th, .data-table td {
  padding: 1rem;
  text-align: left;
  border-bottom: 1px solid #333;
}

.data-table th {
  font-size: 0.75rem;
  font-weight: 600;
  color: #888;
  text-transform: uppercase;
}

.data-table td {
  color: #fff;
  font-size: 0.9375rem;
}

.color-badge {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 2px solid #444;
}

.action-btns {
  display: flex;
  gap: 0.5rem;
}

.btn-icon {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #333;
  border: none;
  border-radius: var(--radius-md);
  color: #fff;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-icon:hover {
  background: #444;
}

.btn-icon.btn-danger:hover {
  background: #dc2626;
}

.btn-icon svg {
  width: 18px;
  height: 18px;
}
</style>
