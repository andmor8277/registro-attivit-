<template>
  <div class="dati-page">
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
      <span class="titolo-toolbar">Dati Giocatori — Segreteria</span>
      <div class="header-right">
        <button class="btn-header" @click="gdprModal.show = true" :class="{ 'btn-unlocked': gdprSbloccato }" :title="gdprSbloccato ? 'Dati sbloccati' : 'Sblocca Dati Sensibili'">
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
            <p class="gdpr-info">Inserisci la password admin per visualizzare i dati sensibili.</p>
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

    <Teleport to="body">
      <div v-if="modal.show" class="modal-overlay" @click.self="modal.show = false">
        <div class="modal">
          <h3>{{ modal.isNuovo ? 'Nuovo Giocatore' : 'Modifica Giocatore' }}</h3>
          <div class="form-grid">
            <div class="form-field">
              <label>Categoria</label>
              <select v-model="modal.categoria_id">
                <option v-for="c in categorie" :key="c.id" :value="c.id">{{ c.nome }} ({{ c.anno }})</option>
              </select>
            </div>
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
              <label>Telefono</label>
              <input v-model="modal.telefono" />
            </div>
            <div class="form-field">
              <label>Matricola</label>
              <input v-model="modal.matricola" />
            </div>
            <div class="form-field">
              <label>Scad. Certificato</label>
              <input v-model="modal.scadenza_certificato" type="date" />
            </div>
            <div class="form-field">
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
    </Teleport>

    <Teleport to="body">
      <div v-if="preiscrizioneModal.show" class="modal-overlay" @click.self="preiscrizioneModal.show = false">
        <div class="modal">
          <h3>PREISCRIZIONE - {{ preiscrizioneModal.catNome }}</h3>
          <div class="form-grid">
            <div class="form-field">
              <label>COGNOME</label>
              <input v-model="preiscrizioneModal.cognome" @keyup.enter="salvaPreiscrizione" placeholder="Cognome giocatore" />
            </div>
            <div class="form-field">
              <label>NOME</label>
              <input v-model="preiscrizioneModal.nome" @keyup.enter="salvaPreiscrizione" placeholder="Nome giocatore" />
            </div>
          </div>
          <div v-if="preiscrizioneModal.link" class="preiscrizione-link">
            <p>Link preiscrizione:</p>
            <div class="link-box">
              <span class="link-text">{{ preiscrizioneModal.link }}</span>
              <button class="btn-copy-link" @click="copiaLinkPreiscrizione" :class="{ 'copied': preiscrizioneModal.copied }">Copia</button>
            </div>
          </div>
          <div class="modal-actions">
            <button class="btn-annulla" @click="preiscrizioneModal.show = false">Chiudi</button>
            <button class="btn-salva" @click="salvaPreiscrizione" :disabled="!preiscrizioneModal.cognome || !preiscrizioneModal.nome">Crea Preiscrizione</button>
          </div>
        </div>
      </div>
    </Teleport>

    <div class="dati-body">
      <div class="filters">
        <input v-model="search" placeholder="Cerca per nome, cognome o matricola..." class="search-input" />
      </div>

      <div v-for="cat in categorieOrdinate" :key="cat.id" class="categoria-section">
        <div class="categoria-header">
          <span class="cat-anno">{{ cat.anno }}</span>
          <span class="cat-nome">{{ cat.nome }}</span>
          <span class="cat-count">{{ getGiocatoriCat(cat.id).length }} giocatori</span>
          <button class="btn-add-player" @click="apriNuovo(cat.id)" title="Aggiungi Giocatore">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="12" y1="5" x2="12" y2="19"/>
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
          </button>
          <button class="btn-add-player" @click="apriPreiscrizione(cat.id)" title="Preiscrizione">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <line x1="19" y1="8" x2="19" y2="14"/>
              <line x1="22" y1="11" x2="16" y2="11"/>
            </svg>
          </button>
        </div>
        
        <div class="tabella-wrapper">
          <table class="tabella-giocatori">
            <thead>
              <tr>
                <th>#</th>
                <th>Cognome</th>
                <th>Nome</th>
                <th>Totale</th>
                <th>Iscriz.</th>
                <th>Rata 1</th>
                <th>Rata 2</th>
                <th>Rata 3</th>
                <th>Rata 4</th>
                <th>Saldo</th>
                <th>Rimane</th>
                <th v-if="gdprSbloccato">Data Nascita</th>
                <th v-if="gdprSbloccato">Codice Fiscale</th>
                <th v-if="gdprSbloccato">Tel. Papà</th>
                <th v-if="gdprSbloccato">Tel. Mamma</th>
                <th v-if="gdprSbloccato">Scad. Cert.</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, idx) in getGiocatoriCatFiltered(cat.id)" :key="p.id" class="giocatore-row" @click="apriScheda(p)">
                <td>{{ idx + 1 }}</td>
                <td>{{ p.cognome }}</td>
                <td>{{ p.nome }}</td>
                <td class="cell-pagamento">
                  <input type="number" step="0.01" class="cell-input" :value="p.totale_da_pagare ?? ''" @click.stop @input="updateRate(p, 'totale_da_pagare', $event.target.value)" placeholder="€" />
                </td>
                <td class="cell-pagamento">
                  <input type="number" step="0.01" class="cell-input" :value="p.rata_iscrizione ?? ''" @click.stop @input="updateRate(p, 'rata_iscrizione', $event.target.value)" placeholder="€" />
                </td>
                <td class="cell-pagamento">
                  <input type="number" step="0.01" class="cell-input" :value="p.rata1 ?? ''" @click.stop @input="updateRate(p, 'rata1', $event.target.value)" placeholder="€" />
                </td>
                <td class="cell-pagamento">
                  <input type="number" step="0.01" class="cell-input" :value="p.rata2 ?? ''" @click.stop @input="updateRate(p, 'rata2', $event.target.value)" placeholder="€" />
                </td>
                <td class="cell-pagamento">
                  <input type="number" step="0.01" class="cell-input" :value="p.rata3 ?? ''" @click.stop @input="updateRate(p, 'rata3', $event.target.value)" placeholder="€" />
                </td>
                <td class="cell-pagamento">
                  <input type="number" step="0.01" class="cell-input" :value="p.rata4 ?? ''" @click.stop @input="updateRate(p, 'rata4', $event.target.value)" placeholder="€" />
                </td>
                <td class="cell-pagamento">
                  <input type="number" step="0.01" class="cell-input" :value="p.rata_saldo ?? ''" @click.stop @input="updateRate(p, 'rata_saldo', $event.target.value)" placeholder="€" />
                </td>
                <td class="cell-pagamento cell-rimane">
                  <span :class="{'rimane-ok': calcRimane(p) <= 0}">{{ calcRimane(p).toFixed(2) }}</span>
                </td>
                <template v-if="gdprSbloccato">
                  <td>{{ formatData(p.data_nascita) }}</td>
                  <td class="cell-cf">{{ mascheraDato(p.codice_fiscale) || '-' }}</td>
                  <td>{{ mascheraDato(p.tel_papa) || '-' }}</td>
                  <td>{{ mascheraDato(p.tel_mamma) || '-' }}</td>
                </template>
                <td v-if="gdprSbloccato" class="cell-scadenza" :class="{ 'scad-rossa': isScaduta(p.scadenza_certificato) }">
                  {{ formatData(p.scadenza_certificato) }}
                </td>
                <td class="cell-actions">
                  <div class="actions-group">
                    <button class="btn-apri-scheda" @click.stop="apriScheda(p)" title="Apri Scheda">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                        <line x1="3" y1="9" x2="21" y2="9"/>
                        <line x1="9" y1="21" x2="9" y2="9"/>
                      </svg>
                    </button>
                    <button class="btn-delete" @click.stop="eliminaGiocatore(p)" title="Elimina">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="3 6 5 6 21 6"/>
                        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                      </svg>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
          <div v-if="getGiocatoriCatFiltered(cat.id).length === 0" class="no-data-small">
            Nessun giocatore
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, getCategorie, createPersona, updatePersona, deletePersona, createPublicPersona } from '../api/index.js'

const router = useRouter()
const { utenteAttivo } = useStore()

const categorie = ref([])
const persone = ref([])
const search = ref('')

const gdprSbloccato = ref(false)
const gdprModal = ref({ show: false, password: '', error: '' })
const preiscrizioneModal = ref({
  show: false,
  categoria_id: null,
  catNome: '',
  cognome: '',
  nome: '',
  link: '',
  copied: false
})
const modal = ref({ 
  show: false, 
  isNuovo: true, 
  id: null, 
  categoria_id: null,
  cognome: '', 
  nome: '', 
  numero_maglia: '', 
  data_nascita: '', 
  codice_fiscale: '', 
  telefono: '', 
  matricola: '', 
  scadenza_certificato: '', 
  gruppo_id: 1 
})

const isSuperAdmin = computed(() => localStorage.getItem('is_super_admin') === 'true')
const societaId = computed(() => {
  const u = utenteAttivo.value
  return u?.societa_id || parseInt(localStorage.getItem('societa_id')) || 1
})

onMounted(async () => {
  gdprSbloccato.value = false
  localStorage.removeItem('gdpr_sbloccato')
  await loadDati()
})

async function loadDati() {
  try {
    const response = await getCategorie()
    let cats = Array.isArray(response) ? response : (response?.data || [])
    const targetId = societaId.value
    cats = cats.filter(c => c.societa_id === targetId)
    categorie.value = cats
    
    await loadPersone()
  } catch(e) { console.error('Error loading categorie:', e) }
}

async function loadPersone() {
  try {
    let all = []
    for (const cat of categorie.value) {
      const pRes = await getPersone(cat.id)
      const players = Array.isArray(pRes) ? pRes.map(p => ({...p, categoria_id: cat.id})) : ((pRes?.data || []).map(p => ({...p, categoria_id: cat.id})))
      all.push(...players)
    }
    persone.value = all
  } catch(e) { console.error('Error loading persone:', e) }
}

const categorieOrdinate = computed(() => {
  return [...categorie.value].sort((a, b) => (a.anno || 0) - (b.anno || 0))
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

function formatData(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('it-IT')
}

function mascheraDato(dato) {
  if (!dato) return ''
  if (gdprSbloccato.value) return dato
  if (dato.length > 4) return '••••••••••••'
  return dato
}

function isScaduta(data) {
  if (!data) return false
  const scad = new Date(data)
  const oggi = new Date()
  return scad < oggi
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
      body: `username=${user.username}&password=${gdprModal.value.password}`
    })
    
    if (loginRes.ok) {
      gdprSbloccato.value = true
      gdprModal.value.show = false
      localStorage.setItem('gdpr_sbloccato', 'true')
    } else {
      gdprModal.value.error = 'Password errata'
    }
  } catch(e) {
    gdprModal.value.error = 'Errore di verifica'
  }
}

function apriNuovo(catId) {
  router.push('/segreteria/scheda/nuovo?categoria_id=' + catId)
}

function apriScheda(p) {
  router.push('/segreteria/scheda/' + p.id)
}

async function salva() {
  try {
    if (modal.value.isNuovo) {
      await createPersona({ ...modal.value })
    } else {
      await updatePersona(modal.value.id, modal.value)
    }
    modal.value.show = false
    await loadPersone()
  } catch(e) {
    console.error('Error saving:', e)
  }
}

async function elimina() {
  if (!confirm('Eliminare questo giocatore?')) return
  try {
    await deletePersona(modal.value.id)
    modal.value.show = false
    await loadPersone()
  } catch(e) {
    console.error('Error deleting:', e)
  }
}

async function eliminaGiocatore(p) {
  if (!confirm(`Eliminare ${p.cognome} ${p.nome}?`)) return
  try {
    await deletePersona(p.id)
    await loadPersone()
  } catch(e) {
    console.error('Error deleting:', e)
  }
}

function calcRimane(p) {
  const totale = p.totale_da_pagare || 0
  const pagato = (p.rata_iscrizione || 0) + (p.rata1 || 0) + (p.rata2 || 0) + (p.rata3 || 0) + (p.rata4 || 0) + (p.rata_saldo || 0)
  return totale - pagato
}

async function updateRate(p, field, value) {
  const numVal = value === '' ? null : parseFloat(value)
  const payload = { [field]: numVal }
  p[field] = numVal
  await updatePersona(p.id, payload)
}

function apriPreiscrizione(catId) {
  const cat = categorie.value.find(c => c.id === catId)
  preiscrizioneModal.value = {
    show: true,
    categoria_id: catId,
    catNome: cat ? cat.nome : '',
    cognome: '',
    nome: '',
    link: '',
    copied: false
  }
}

async function salvaPreiscrizione() {
  if (!preiscrizioneModal.value.cognome || !preiscrizioneModal.value.nome) return
  try {
    const res = await createPublicPersona({
      cognome: preiscrizioneModal.value.cognome,
      nome: preiscrizioneModal.value.nome,
      categoria_id: preiscrizioneModal.value.categoria_id
    })
    const newId = res.data.id
    preiscrizioneModal.value.link = `${window.location.origin}/form-iscrizione?id=${newId}`
  } catch(e) {
    console.error('Errore preiscrizione:', e)
  }
}

function copiaLinkPreiscrizione() {
  navigator.clipboard.writeText(preiscrizioneModal.value.link).then(() => {
    preiscrizioneModal.value.copied = true
    setTimeout(() => { preiscrizioneModal.value.copied = false }, 2000)
  })
}
</script>

<style scoped>
.dati-page {
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
}

.header-right {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.link-generator {
  display: flex;
  gap: 0.25rem;
  align-items: center;
}

.link-cat-select {
  height: 34px;
  padding: 0 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface-elevated);
  color: var(--color-text);
  font-size: 0.8rem;
  cursor: pointer;
  outline: none;
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
}

.dati-body {
  padding: 1rem;
}

.filters {
  margin-bottom: 1rem;
}

.search-input {
  width: 100%;
  padding: 0.75rem 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
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

.categoria-header .btn-add-player {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: white;
  border: none;
  border-radius: var(--radius-md);
  color: #7c3aed;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.categoria-header .btn-add-player:hover {
  background: #f3f4f6;
}

.categoria-header .btn-add-player.copied {
  background: #dcfce7;
}

.categoria-header .btn-add-player svg {
  width: 18px;
  height: 18px;
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
}

.tabella-giocatori th {
  background: var(--color-surface-elevated);
  padding: 0.75rem;
  text-align: left;
  font-weight: 600;
  color: var(--color-text-secondary);
  font-size: 0.75rem;
  text-transform: uppercase;
  white-space: nowrap;
}

.tabella-giocatori td {
  padding: 0.75rem;
  border-bottom: 1px solid var(--color-border);
  color: var(--color-text);
  font-size: 0.875rem;
}

.tabella-giocatori tr:hover {
  background: var(--color-surface-elevated);
  cursor: pointer;
}

.cell-numero {
  text-align: center;
  font-weight: 600;
}

.cell-cf {
  font-family: monospace;
  font-size: 0.75rem;
}

.cell-matricola {
  font-weight: 600;
}

.cell-gruppo {
  text-align: center;
}

.cell-scadenza {
  white-space: nowrap;
}

.scad-rossa {
  color: #dc2626;
  font-weight: 600;
}

.cell-pagamento {
  padding: 2px;
}

.cell-input {
  width: 100%;
  min-width: 50px;
  padding: 4px 6px;
  border: 1px solid transparent;
  border-radius: 4px;
  font-size: 0.875rem;
  text-align: right;
  background: transparent;
  color: var(--color-text);
  font-family: inherit;
  font-weight: 500;
}

.cell-input:focus {
  outline: none;
  border-color: #5b7fff;
  box-shadow: 0 0 0 2px rgba(91, 127, 255, 0.15);
  background: var(--color-surface);
}

.cell-rimane {
  font-weight: 700;
  font-size: 0.75rem;
}

.rimane-ok {
  color: #16a34a;
}

.badge {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: 600;
}

.badge-g1 { background: #dbeafe; color: #1e40af; }
.badge-g2 { background: #dcfce7; color: #166534; }
.badge-g3 { background: #fef3c7; color: #92400e; }
.badge-g4 { background: #fce7f3; color: #9d174d; }

.no-data-small {
  text-align: center;
  padding: 1rem;
  color: var(--color-text-muted);
  background: var(--color-surface);
  border-radius: var(--radius-md);
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
  max-width: 500px;
  padding: 1.5rem;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}

.modal h3 {
  font-size: 1.25rem;
  font-weight: 700;
  margin-bottom: 1rem;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.form-field label {
  display: block;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  margin-bottom: 0.25rem;
}

.form-field input, .form-field select {
  width: 100%;
  padding: 0.625rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
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
}

.modal-close svg {
  width: 20px;
  height: 20px;
}

.modal-body {
  padding: 1rem 0;
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
  padding: 0.75rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
}

.btn-sblocca {
  width: 100%;
  padding: 0.75rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-weight: 600;
  cursor: pointer;
}

.gdpr-error {
  color: #ef4444;
  font-size: 0.875rem;
  margin-top: 0.5rem;
  text-align: center;
}

.modal-actions {
  display: flex;
  justify-content: space-between;
  margin-top: 1rem;
}

.modal-actions-right {
  display: flex;
  gap: 0.5rem;
}

.btn-annulla {
  padding: 0.625rem 1rem;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
}

.btn-salva {
  padding: 0.625rem 1rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-weight: 600;
  cursor: pointer;
}

.btn-elimina {
  padding: 0.625rem 1rem;
  background: #fee2e2;
  border: none;
  border-radius: var(--radius-md);
  color: #dc2626;
  cursor: pointer;
}

.giocatore-row {
  cursor: pointer;
  transition: background-color 0.15s;
}

.giocatore-row:hover {
  background: rgba(99, 102, 241, 0.08);
}

.cell-actions {
  width: 80px;
  text-align: center;
}

.actions-group {
  display: flex;
  gap: 4px;
  justify-content: center;
  align-items: center;
}

.btn-apri-scheda {
  width: 32px;
  height: 32px;
  padding: 4px;
  background: #f0f0f0;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
}

.btn-apri-scheda:hover {
  background: #e0e0ff;
}

.btn-apri-scheda svg {
  width: 18px;
  height: 18px;
  color: #666;
}

.btn-delete {
  width: 32px;
  height: 32px;
  padding: 4px;
  background: #fef2f2;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
}

.btn-delete:hover {
  background: #fecaca;
}

.btn-delete svg {
  width: 18px;
  height: 18px;
  color: #dc2626;
}

.preiscrizione-link {
  margin: 1rem 0;
  padding: 0.75rem;
  background: #f0f4ff;
  border-radius: 6px;
}

.preiscrizione-link p {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  margin: 0 0 0.5rem 0;
}

.link-box {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.link-text {
  flex: 1;
  font-size: 0.75rem;
  word-break: break-all;
  color: #5b7fff;
  font-family: monospace;
}

.btn-copy-link {
  padding: 0.375rem 0.75rem;
  background: #5b7fff;
  color: #fff;
  border: none;
  border-radius: 4px;
  font-size: 0.75rem;
  cursor: pointer;
  white-space: nowrap;
}

.btn-copy-link:hover {
  background: #4a6ae0;
}

.btn-copy-link.copied {
  background: #16a34a;
}
</style>