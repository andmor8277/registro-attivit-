<template>
  <div class="segreteria-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <button class="btn-home" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
        </button>
      </div>
      <span class="titolo-toolbar">Segreteria — Dati & Matricole</span>
      <div class="header-right">
        <button class="btn-header" :class="{ 'btn-unlocked': gdprSbloccato }" @click="gdprModal.show = true" :title="gdprSbloccato ? 'Dati sbloccati' : 'Sblocca Dati Sensibili'">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
            <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
          </svg>
        </button>
      </div>
    </header>

    <Teleport to="body">
      <div v-if="gdprModal.show" class="modal-overlay" @click.self="gdprModal.show = false">
        <div class="modal">
          <div class="modal-header">
            <h3>Sblocca Dati Sensibili</h3>
            <button class="modal-close" @click="gdprModal.show = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <p class="gdpr-info">Inserisci la password admin per visualizzare i dati sensibili (codice fiscale, telefono, data di nascita).</p>
            <div class="form-group">
              <label>Password</label>
              <input type="password" v-model="gdprModal.password" @keyup.enter="sbloccaGdpr" placeholder="Password admin" />
            </div>
            <button class="btn-sblocca" @click="sbloccaGdpr">Sblocca</button>
            <p v-if="gdprModal.error" class="gdpr-error">{{ gdprModal.error }}</p>
          </div>
        </div>
      </div>
    </Teleport>

    <div class="segreteria-body">
      <div class="filters">
        <input v-model="search" placeholder="Cerca per nome, cognome o matricola..." class="search-input" />
      </div>

      <div v-for="cat in categorieOrdinate" :key="cat.id" class="categoria-section">
        <div class="categoria-header">
          <span class="cat-anno">{{ cat.anno }}</span>
          <span class="cat-nome">{{ cat.nome }}</span>
          <span class="cat-count">{{ getGiocatoriCat(cat.id).length }} giocatori</span>
        </div>
        
        <div class="tabella-wrapper">
          <table class="tabella-giocatori">
            <thead>
              <tr>
                <th class="th-num">#</th>
                <th class="th-nome">Cognome Nome</th>
                <th v-if="gdprSbloccato">Data N.</th>
                <th v-if="gdprSbloccato">CF</th>
                <th v-if="gdprSbloccato">Telefono</th>
                <th>Matr.</th>
                <th>Maglia</th>
                <th v-if="gdprSbloccato">Scad. Cert.</th>
                <th v-if="!gdprSbloccato"></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, idx) in getGiocatoriCatFiltered(cat.id)" :key="p.id">
                <td class="td-num">{{ idx + 1 }}</td>
                <td class="td-nome">{{ p.cognome }} {{ p.nome }}</td>
                <td>{{ formatData(p.data_nascita) }}</td>
                <td class="td-cf">{{ mascheraDato(p.codice_fiscale) || '—' }}</td>
                <td>{{ mascheraDato(p.telefono) || '—' }}</td>
                <td>{{ p.matricola || '—' }}</td>
                <td>{{ p.numero_maglia || '—' }}</td>
                <td :class="{'scad-rosso': gdprSbloccato && isCertScaduto(p.scadenza_certificato), 'scad-verde': gdprSbloccato && !isCertScaduto(p.scadenza_certificato)}">
                  {{ formatData(p.scadenza_certificato) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-if="giocatoriFiltrati.length === 0" class="no-data">
        Nessun giocatore trovato
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue"
import { useRouter } from "vue-router"
import { getPersone, getCategorie } from "../api/index.js"

const router = useRouter()

const categorie = ref([])
const persone = ref([])
const search = ref("")
const gdprSbloccato = ref(false)
const gdprModal = ref({ show: false, password: '', error: '' })

onMounted(async () => {
  await loadDati()
  if (localStorage.getItem('gdpr_sbloccato') === 'true') {
    gdprSbloccato.value = true
  }
})

async function loadDati() {
  try {
    const catRes = await getCategorie()
    categorie.value = catRes.data || []
  } catch(e) { console.error('Error loading categorie:', e) }
  
  try {
    const allPersone = []
    for (const cat of categorie.value) {
      const pRes = await getPersone(cat.id)
      const players = (pRes.data || []).map(p => ({
        ...p,
        categoria_id: cat.id,
        categoria_anno: cat.anno,
        categoria_nome: cat.nome
      }))
      allPersone.push(...players)
    }
    persone.value = allPersone
  } catch(e) { console.error('Error loading persone:', e) }
}

const categorieOrdinate = computed(() => {
  return [...categorie.value].sort((a, b) => a.anno - b.anno)
})

function getGiocatoriCat(catId) {
  return persone.value.filter(p => p.categoria_id === catId)
}

function getGiocatoriCatFiltered(catId) {
  const giocatori = getGiocatoriCat(catId)
  if (!search.value) return giocatori
  const s = search.value.toLowerCase()
  return giocatori.filter(p => 
    p.nome?.toLowerCase().includes(s) || 
    p.cognome?.toLowerCase().includes(s) ||
    p.matricola?.toLowerCase().includes(s)
  )
}

const giocatoriFiltrati = computed(() => {
  if (!search.value) return []
  const s = search.value.toLowerCase()
  return persone.value.filter(p => 
    p.nome?.toLowerCase().includes(s) || 
    p.cognome?.toLowerCase().includes(s) ||
    p.matricola?.toLowerCase().includes(s)
  )
})

function isCertScaduto(data) {
  if (!data) return false
  return new Date(data) < new Date()
}

async function sbloccaGdpr() {
  gdprModal.value.error = ''
  try {
    const response = await fetch('/api/auth/me', {
      headers: { 'Authorization': 'Bearer ' + localStorage.getItem('token') }
    })
    const user = await response.json()
    
    const loginRes = await fetch('/api/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'username=' + user.username + '&password=' + gdprModal.value.password
    })
    
    if (loginRes.ok) {
      gdprSbloccato.value = true
      gdprModal.value.show = false
      gdprModal.value.password = ''
      localStorage.setItem('gdpr_sbloccato', 'true')
    } else {
      gdprModal.value.error = 'Password errata'
    }
  } catch(e) {
    gdprModal.value.error = 'Errore di verifica'
  }
}

function mascheraDato(dato) {
  if (!dato) return ''
  if (gdprSbloccato.value) return dato
  if (dato.length > 4) return '••••••••••••'
  return dato
}

function formatData(data) {
  if (!data) return ""
  if (!gdprSbloccato.value) return '••/••/••••'
  return new Date(data).toLocaleDateString("it-IT")
}

onMounted(async () => {
  await loadDati()
  if (localStorage.getItem('gdpr_sbloccato') === 'true') {
    gdprSbloccato.value = true
  }
})
</script>

<style scoped>
.segreteria-page {
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

.header-left {
  display: flex;
  gap: 0.5rem;
}

.btn-back, .btn-home {
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

.btn-back:hover, .btn-home:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-back svg, .btn-home svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
}

.titolo-toolbar {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-text);
}

.segreteria-body {
  padding: 1rem;
}

.filters {
  margin-bottom: 1.5rem;
}

.search-input {
  width: 100%;
  padding: 0.75rem 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.9375rem;
}

.search-input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.categoria-section {
  margin-bottom: 2rem;
}

.categoria-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
  padding: 0.75rem 1rem;
  background: linear-gradient(135deg, #7c3aed 0%, #6d28d9 100%);
  border-radius: var(--radius-md);
}

.cat-anno {
  background: rgba(255, 255, 255, 0.2);
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: 600;
}

.cat-nome {
  flex: 1;
  font-weight: 600;
  font-size: 1rem;
}

.cat-count {
  font-size: 0.75rem;
  opacity: 0.8;
}

.tabella-wrapper {
  overflow-x: auto;
}

.tabella-giocatori {
  width: 100%;
  border-collapse: collapse;
  background: var(--color-surface);
  border-radius: var(--radius-md);
  overflow: hidden;
  font-size: 0.875rem;
}

.tabella-giocatori th {
  background: var(--color-surface-elevated);
  padding: 0.75rem 0.5rem;
  text-align: left;
  font-weight: 600;
  color: var(--color-text-secondary);
  font-size: 0.75rem;
  text-transform: uppercase;
  border-bottom: 1px solid var(--color-border);
}

.tabella-giocatori td {
  padding: 0.625rem 0.5rem;
  border-bottom: 1px solid var(--color-border);
  color: var(--color-text);
}

.tabella-giocatori tr:last-child td {
  border-bottom: none;
}

.th-num, .td-num {
  width: 40px;
  text-align: center;
}

.th-nome, .td-nome {
  min-width: 150px;
}

.td-cf {
  font-family: var(--font-mono);
  font-size: 0.75rem;
}

.td-lock {
  text-align: center;
}

.td-lock svg {
  width: 16px;
  height: 16px;
  color: var(--color-text-muted);
}

.scad-rosso {
  color: #ef4444;
}

.scad-verde {
  color: #10b981;
}

.no-data {
  text-align: center;
  padding: 3rem;
  color: var(--color-text-muted);
}

.header-right {
  display: flex;
  gap: 0.5rem;
}

.btn-header {
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

.btn-header:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-header.btn-unlocked {
  background: #10b981;
  border-color: #10b981;
}

.btn-header svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
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
  backdrop-filter: blur(4px);
}

.modal {
  background: var(--color-surface);
  border-radius: var(--radius-xl);
  width: 100%;
  max-width: 400px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid var(--color-border);
}

.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 700;
}

.modal-close {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  cursor: pointer;
  border-radius: var(--radius-md);
}

.modal-close:hover {
  background: var(--color-surface-elevated);
}

.modal-close svg {
  width: 20px;
  height: 20px;
  color: var(--color-text-muted);
}

.modal-body {
  padding: 1.5rem;
}

.gdpr-info {
  font-size: 0.875rem;
  color: var(--color-text-secondary);
  margin-bottom: 1rem;
}

.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  font-size: 0.875rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

.form-group input {
  width: 100%;
  padding: 0.75rem 1rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 1rem;
}

.form-group input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.btn-sblocca {
  width: 100%;
  padding: 0.75rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
}

.btn-sblocca:hover {
  background: var(--color-primary-dark);
}

.gdpr-error {
  color: #ef4444;
  font-size: 0.875rem;
  margin-top: 0.75rem;
  text-align: center;
}
</style>
