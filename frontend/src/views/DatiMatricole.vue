<template>
  <div class="dati-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/scelta/' + route.params.id)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          Indietro
        </button>
        <div class="header-actions">
          <button v-if="utenteAttivo?.is_admin || utenteAttivo?.ruolo === 'mister'" class="btn-icon-pill" @click="gdprModal.show = true" :title="gdprSbloccato ? 'Dati sbloccati' : 'Sblocca Dati Sensibili'" :class="{ 'gdpr-unlocked': gdprSbloccato }">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
              <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            </svg>
          </button>
          <button v-if="utenteAttivo?.is_admin || utenteAttivo?.ruolo === 'mister'" class="btn-add-pill" @click="apriNuovo">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <line x1="12" y1="5" x2="12" y2="19"/>
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
            Aggiungi
          </button>
        </div>
      </div>
      <div class="header-main">
        <h1 class="category-name">
          <span class="name-gradient">{{ categoriaAttiva?.nome }}</span>
        </h1>
        <p class="header-subtitle">Dati & Matricole</p>
      </div>
    </header>

    <div class="dati-body">
      <div class="filters">
        <input v-model="search" placeholder="Cerca per nome, cognome o matricola..." class="search-input" />
        <select v-if="!isDirigente" v-model="gruppoFilter" class="gruppo-filter">
          <option value="">Tutti i gruppi</option>
          <option value="1">Primo Gruppo</option>
          <option value="2">Secondo Gruppo</option>
          <option value="3">Terzo Gruppo</option>
          <option value="4">Portieri</option>
        </select>
      </div>

      <div class="tabella-wrapper">
        <table class="tabella-giocatori">
          <thead>
            <tr>
              <th>#</th>
              <th>Cognome</th>
              <th>Nome</th>
              <th>Nr.</th>
              <th v-if="gdprSbloccato">Data Nascita</th>
              <th v-if="gdprSbloccato">Codice Fiscale</th>
              <th v-if="gdprSbloccato">Tel. Papà</th>
              <th v-if="gdprSbloccato">Tel. Mamma</th>
              <th v-if="gdprSbloccato">Matricola</th>
              <th v-if="gdprSbloccato">Scad. Cert.</th>
              <th v-if="!isDirigente">Gruppo</th>
              <th v-if="!gdprSbloccato"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(p, idx) in filteredPersone" :key="p.id" :class="{ 'row-scad': !p.scadenza_certificato || isScaduta(p.scadenza_certificato) }">
              <td class="cell-num">{{ idx + 1 }}</td>
              <td>{{ p.cognome }}</td>
              <td>{{ p.nome }}</td>
              <td class="cell-numero">{{ p.numero_maglia || '-' }}</td>
              <template v-if="gdprSbloccato">
                <td>{{ formatData(p.data_nascita) }}</td>
                <td class="cell-cf">{{ gdprSbloccato ? (p.codice_fiscale || '-') : '••••••••••••' }}</td>
                <td>{{ gdprSbloccato ? (p.tel_papa || '-') : '••••' }}</td>
                <td>{{ gdprSbloccato ? (p.tel_mamma || '-') : '••••' }}</td>
                <td class="cell-matricola">{{ p.matricola || '-' }}</td>
                <td class="cell-scadenza" :class="{ 'scad-rossa': isScaduta(p.scadenza_certificato) }">
                  {{ formatData(p.scadenza_certificato) }}
                </td>
              </template>
              <td v-if="!isDirigente" class="cell-gruppo">
                <span class="badge" :class="'badge-g' + p.gruppo_id">
                  {{ p.gruppo_id === 1 ? '1°' : p.gruppo_id === 2 ? '2°' : p.gruppo_id === 3 ? '3°' : p.gruppo_id === 4 ? 'P' : '-' }}
                </span>
              </td>
              <td class="cell-action">
                <button class="btn-modifica" @click="apriModifica(p)">✏️</button>
              </td>
            </tr>
            <tr v-if="filteredPersone.length === 0">
              <td :colspan="isDirigente ? (gdprSbloccato ? 10 : 5) : (gdprSbloccato ? 12 : 7)" class="no-data">Nessun giocatore trovato</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal sblocco GDPR -->
    <div v-if="gdprModal.show" class="modal-overlay" @click.self="gdprModal.show = false">
      <div class="modal modal-small">
        <h3>🔒 Sblocco Dati Sensibili</h3>
        <p class="gdpr-info">Inserisci la password per visualizzare i dati personali dei giocatori (CF, tel. Papà/Mamma, data nascita)</p>
        <div class="form-field">
          <label>Password</label>
          <input v-model="gdprModal.password" type="password" @keyup.enter="verificaPasswordGdpr" />
        </div>
        <p v-if="gdprModal.errore" class="error-msg">{{ gdprModal.errore }}</p>
        <div class="modal-actions">
          <button class="btn-annulla" @click="gdprModal.show = false">Annulla</button>
          <button class="btn-salva" @click="verificaPasswordGdpr">Sblocca</button>
        </div>
      </div>
    </div>

    <div v-if="modal.show" class="modal-overlay" @click.self="modal.show = false">
      <div class="modal">
        <h3>{{ modal.isNuovo ? 'Nuovo Giocatore' : 'Modifica Giocatore' }}</h3>
        <div class="form-grid">
          <div class="form-field">
            <label>Cognome</label>
            <input v-model="modal.cognome" />
          </div>
          <div class="form-field">
            <label>Nome</label>
            <input v-model="modal.nome" />
          </div>
          <div class="form-field">
            <label>Nr. Maglia</label>
            <input v-model="modal.numero_maglia" type="number" min="1" max="99" />
          </div>
          <div class="form-field">
            <label>Data Nascita</label>
            <input v-model="modal.data_nascita" type="date" />
          </div>
          <div class="form-field">
            <label>Codice Fiscale</label>
            <input v-model="modal.codice_fiscale" maxlength="16" />
          </div>
          <div class="form-field">
            <label>Tel. Papà</label>
            <input v-model="modal.tel_papa" />
          </div>
          <div class="form-field">
            <label>Tel. Mamma</label>
            <input v-model="modal.tel_mamma" />
          </div>
          <div class="form-field">
            <label>Matricola</label>
            <input v-model="modal.matricola" />
          </div>
          <div class="form-field">
            <label>Scad. Certificato</label>
            <input v-model="modal.scadenza_certificato" type="date" />
          </div>
          <div v-if="!isDirigente" class="form-field">
            <label>Gruppo</label>
            <select v-model="modal.gruppo_id">
              <option :value="1">Primo Gruppo</option>
              <option :value="2">Secondo Gruppo</option>
              <option :value="3">Terzo Gruppo</option>
              <option :value="4">Portieri</option>
            </select>
          </div>
        </div>
        <div class="modal-actions">
          <button v-if="!modal.isNuovo" class="btn-elimina" @click="elimina">🗑 Elimina</button>
          <div class="modal-actions-right">
            <button class="btn-annulla" @click="modal.show = false">Annulla</button>
            <button class="btn-salva" @click="salva">{{ modal.isNuovo ? 'Aggiungi' : 'Salva' }}</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, updatePersona, createPersona, deletePersona } from '../api/index.js'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva, utenteAttivo } = useStore()
const categoriaId = parseInt(route.params.id)

const persone = ref([])
const search = ref('')
const gruppoFilter = ref('')

const isDirigente = computed(() => ['dirigente', 'segreteria', 'infermeria'].includes(utenteAttivo.value?.ruolo))

// GDPR state
const gdprSbloccato = ref(false)
const gdprModal = ref({ show: false, password: '', errore: '' })

const modal = ref({ show: false, isNuovo: false, id: null, cognome: '', nome: '', numero_maglia: '', data_nascita: '', codice_fiscale: '', tel_papa: '', tel_mamma: '', matricola: '', scadenza_certificato: '', gruppo_id: 1 })

function apriSbloccoGdpr() {
  gdprModal.value = { show: true, password: '', errore: '' }
}

async function verificaPasswordGdpr() {
  try {
    const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:8000'
    const res = await fetch(`${apiUrl}/auth/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `username=${utenteAttivo.value?.username || ''}&password=${gdprModal.value.password}`
    })
    if (res.ok) {
      gdprSbloccato.value = true
      gdprModal.value.show = false
    } else {
      gdprModal.value.errore = 'Password non valida'
    }
  } catch (e) {
    gdprModal.value.errore = 'Errore di verifica'
  }
}

const filteredPersone = computed(() => {
  let result = persone.value.filter(p => {
    const matchSearch = !search.value || 
      p.cognome.toLowerCase().includes(search.value.toLowerCase()) ||
      p.nome.toLowerCase().includes(search.value.toLowerCase()) ||
      (p.matricola && p.matricola.toLowerCase().includes(search.value.toLowerCase()))
    
    const matchGruppo = !gruppoFilter.value || p.gruppo_id === parseInt(gruppoFilter.value)
    
    return matchSearch && matchGruppo
  })
  return result
})

function formatData(d) {
  if (!d) return '-'
  return d.split('-').reverse().join('/')
}

function isScaduta(d) {
  if (!d) return false
  const scad = new Date(d)
  const oggi = new Date()
  return scad < oggi
}

function mascheraDato(dato) {
  if (!dato) return ''
  if (gdprSbloccato.value) return dato
  if (dato.length > 4) return '••••••••••••'
  return dato
}

function apriModifica(p) {
  modal.value = {
    show: true,
    isNuovo: false,
    id: p.id,
    cognome: p.cognome,
    nome: p.nome,
    numero_maglia: p.numero_maglia || '',
    data_nascita: p.data_nascita || '',
    codice_fiscale: mascheraDato(p.codice_fiscale),
    tel_papa: mascheraDato(p.tel_papa),
    tel_mamma: mascheraDato(p.tel_mamma),
    matricola: p.matricola || '',
    scadenza_certificato: p.scadenza_certificato || '',
    gruppo_id: p.gruppo_id || 1
  }
}

function apriNuovo() {
  modal.value = {
    show: true,
    isNuovo: true,
    id: null,
    cognome: '',
    nome: '',
    numero_maglia: '',
    data_nascita: '',
    codice_fiscale: '',
    tel_papa: '',
    tel_mamma: '',
    matricola: '',
    scadenza_certificato: '',
    gruppo_id: 1
  }
}

async function salva() {
  if (!modal.value.cognome || !modal.value.nome) {
    alert('Cognome e Nome sono obbligatori')
    return
  }
  
  if (!gdprSbloccato.value && (modal.value.codice_fiscale || modal.value.tel_papa || modal.value.tel_mamma)) {
    alert('Sblocca i dati GDPR prima di modificare CF o telefoni')
    return
  }
  
  try {
    const data = {
      nome: modal.value.nome,
      cognome: modal.value.cognome,
      gruppo_id: modal.value.gruppo_id || 1,
      categoria_id: categoriaId,
      data_nascita: modal.value.data_nascita || null,
      codice_fiscale: modal.value.codice_fiscale?.startsWith('••') ? null : (modal.value.codice_fiscale || null),
      tel_papa: modal.value.tel_papa?.startsWith('••') ? null : (modal.value.tel_papa || null),
      tel_mamma: modal.value.tel_mamma?.startsWith('••') ? null : (modal.value.tel_mamma || null),
      matricola: modal.value.matricola || null,
      numero_maglia: modal.value.numero_maglia ? parseInt(modal.value.numero_maglia) : null,
      scadenza_certificato: modal.value.scadenza_certificato || null
    }
    
    if (modal.value.isNuovo) {
      await createPersona(data)
    } else {
      await updatePersona(modal.value.id, data)
    }
    
    modal.value.show = false
    const res = await getPersone(categoriaId)
    persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
  } catch (e) {
    console.error('Errore salvataggio:', e)
    alert('Errore durante il salvataggio')
  }
}

async function elimina() {
  if (!confirm('Eliminare questo giocatore?')) return
  await deletePersona(modal.value.id)
  modal.value.show = false
  const res = await getPersone(categoriaId)
  persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
}

onMounted(async () => {
  const res = await getPersone(categoriaId)
  persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
})
</script>

<style scoped>
.dati-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1400px;
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
  background: radial-gradient(circle, rgba(234, 179, 8, 0.07) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 400px;
  height: 400px;
  bottom: -100px;
  left: -80px;
  background: radial-gradient(circle, rgba(59, 130, 246, 0.06) 0%, transparent 70%);
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
  margin-bottom: 1.5rem;
  animation: fadeSlideIn 0.6s ease-out both;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
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

.header-actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.btn-icon-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--color-border);
  border-radius: 50%;
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-icon-pill:hover {
  background: rgba(234, 179, 8, 0.12);
  border-color: rgba(234, 179, 8, 0.3);
  color: #fbbf24;
}

.btn-icon-pill.gdpr-unlocked {
  background: rgba(34, 197, 94, 0.12);
  border-color: rgba(34, 197, 94, 0.3);
  color: #4ade80;
}

.btn-add-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 1rem;
  background: rgba(34, 197, 94, 0.1);
  border: 1px solid rgba(34, 197, 94, 0.2);
  border-radius: 100px;
  color: #4ade80;
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-add-pill:hover {
  background: rgba(34, 197, 94, 0.18);
  border-color: rgba(34, 197, 94, 0.35);
  transform: translateY(-1px);
}

.header-main {
  position: relative;
}

.category-name {
  font-size: clamp(2rem, 6vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.25rem;
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
.dati-body {
  position: relative;
  z-index: 1;
  animation: fadeSlideIn 0.6s ease-out 0.1s both;
}

/* ── Filters ── */
.filters {
  display: flex;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.search-input {
  flex: 1;
  padding: 0.625rem 1rem;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  font-size: 0.875rem;
  color: var(--color-text);
  background: rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(10px);
  transition: all var(--transition-fast);
}

.search-input::placeholder { color: var(--color-text-muted); }

.search-input:focus {
  outline: none;
  border-color: rgba(234, 179, 8, 0.4);
  box-shadow: 0 0 0 3px rgba(234, 179, 8, 0.08);
}

.gruppo-filter {
  padding: 0.625rem 1rem;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  font-size: 0.875rem;
  color: var(--color-text);
  background: rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(10px);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.gruppo-filter:focus {
  outline: none;
  border-color: rgba(234, 179, 8, 0.4);
}

/* ── Table ── */
.tabella-wrapper {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  border: 1px solid var(--color-border);
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.02);
  backdrop-filter: blur(10px);
}

.tabella-giocatori {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 0.8125rem;
  color: var(--color-text);
}

.tabella-giocatori th {
  background: rgba(255, 255, 255, 0.04);
  color: var(--color-text-secondary);
  padding: 0.75rem 0.5rem;
  text-align: left;
  font-weight: 600;
  white-space: nowrap;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.tabella-giocatori td {
  padding: 0.6rem 0.5rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.03);
  color: var(--color-text);
}

tr:last-child td { border-bottom: none; }

.tabella-giocatori tr:hover {
  background: rgba(255, 255, 255, 0.03);
}

.tabella-giocatori tr.row-scad {
  background: rgba(234, 88, 12, 0.08);
}

.tabella-giocatori tr.row-scad:hover {
  background: rgba(234, 88, 12, 0.14);
}

.cell-num {
  width: 40px;
  color: var(--color-text-muted);
  text-align: center;
  font-size: 0.75rem;
}

.cell-numero {
  color: #fbbf24;
  font-weight: 700;
  font-size: 1rem;
  text-align: center;
}

.cell-cf {
  font-size: 0.75rem;
  letter-spacing: 0.5px;
  font-family: var(--font-mono);
  color: var(--color-text-secondary);
}

.cell-matricola {
  color: #f87171;
  font-weight: 700;
  font-family: var(--font-mono);
}

.cell-scadenza {
  color: #4ade80;
  font-family: var(--font-mono);
  font-size: 0.75rem;
}

.cell-scadenza.scad-rossa {
  color: #f87171;
  font-weight: 700;
}

.cell-gruppo { text-align: center; }

.badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 10px;
  font-size: 0.75rem;
  font-weight: 700;
  color: white;
}

.badge-g1 {
  background: rgba(59, 130, 246, 0.2);
  border: 1px solid rgba(59, 130, 246, 0.3);
  color: #60a5fa;
}

.badge-g2 {
  background: rgba(34, 197, 94, 0.2);
  border: 1px solid rgba(34, 197, 94, 0.3);
  color: #4ade80;
}

.badge-g3 {
  background: rgba(168, 85, 247, 0.2);
  border: 1px solid rgba(168, 85, 247, 0.3);
  color: #a78bfa;
}

.badge-g4 {
  background: rgba(234, 88, 12, 0.2);
  border: 1px solid rgba(234, 88, 12, 0.3);
  color: #fb923c;
}

.cell-action { width: 50px; text-align: center; }

.btn-modifica {
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  cursor: pointer;
  font-size: 0.875rem;
  padding: 4px 10px;
  border-radius: 8px;
  color: var(--color-text-secondary);
  transition: all var(--transition-fast);
}

.btn-modifica:hover {
  background: rgba(220, 38, 38, 0.12);
  border-color: rgba(220, 38, 38, 0.3);
  color: var(--color-primary);
}

.no-data {
  text-align: center;
  padding: 3rem;
  color: var(--color-text-muted);
  font-size: 0.9375rem;
}

/* ── Modals ── */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(8px);
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.9) translateY(10px); }
  to { opacity: 1; transform: scale(1) translateY(0); }
}

@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

.modal {
  background: rgba(30, 30, 30, 0.95);
  backdrop-filter: blur(20px);
  border: 1px solid var(--color-border);
  border-radius: 24px;
  width: 90%;
  max-width: 500px;
  color: var(--color-text);
  padding: 2rem;
  box-shadow: 0 25px 60px rgba(0, 0, 0, 0.5);
  animation: scaleIn 0.3s ease-out;
}

.modal h3 {
  margin: 0 0 1.25rem;
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-small { max-width: 380px; }

.gdpr-info {
  font-size: 0.875rem;
  color: var(--color-text-muted);
  margin-bottom: 1.25rem;
  line-height: 1.5;
}

.error-msg {
  color: #f87171;
  font-size: 0.8125rem;
  margin-top: 0.5rem;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.form-field {
  margin-bottom: 0;
}

.form-field label {
  display: block;
  font-size: 0.6875rem;
  color: var(--color-text-muted);
  margin-bottom: 0.375rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-weight: 600;
}

.form-field input,
.form-field select {
  width: 100%;
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  font-size: 0.875rem;
  box-sizing: border-box;
  background: rgba(255, 255, 255, 0.04);
  color: var(--color-text);
  transition: all var(--transition-fast);
}

.form-field input:focus,
.form-field select:focus {
  outline: none;
  border-color: rgba(220, 38, 38, 0.4);
  box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.08);
}

.modal-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 1.5rem;
  padding-top: 1.25rem;
  border-top: 1px solid var(--color-border);
}

.modal-actions-right {
  display: flex;
  gap: 0.5rem;
}

.btn-elimina {
  padding: 0.5rem 1rem;
  border: 1px solid rgba(239, 68, 68, 0.3);
  border-radius: 10px;
  background: rgba(239, 68, 68, 0.08);
  color: #f87171;
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 600;
  transition: all var(--transition-fast);
}

.btn-elimina:hover {
  background: rgba(239, 68, 68, 0.16);
  border-color: rgba(239, 68, 68, 0.4);
}

.btn-annulla {
  padding: 0.5rem 1rem;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.04);
  color: var(--color-text-secondary);
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 600;
  transition: all var(--transition-fast);
}

.btn-annulla:hover {
  background: rgba(255, 255, 255, 0.08);
}

.btn-salva {
  padding: 0.5rem 1.25rem;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, var(--color-primary) 0%, #b91c1c 100%);
  color: white;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.8125rem;
  transition: all var(--transition-fast);
}

.btn-salva:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 16px rgba(220, 38, 38, 0.35);
}

/* ── Responsive ── */
@media (max-width: 768px) {
  .dati-page {
    padding: 1.5rem 1rem 3rem;
  }
  .header-top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }
  .form-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 480px) {
  .category-name {
    font-size: 1.75rem;
  }
  .filters {
    flex-direction: column;
  }
}
</style>
