<template>
  <div class="cat-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-icon" @click="router.push('/segreteria')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
      </div>
      <span class="page-title">{{ categoria?.nome }} — {{ categoria?.anno }}</span>
      <div class="header-right">
        <button class="btn-icon" @click="gdprModal.show = true" :class="{ 'btn-unlocked': gdprSbloccato }" :title="gdprSbloccato ? 'Dati sbloccati' : 'Sblocca Dati Sensibili'">
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
      <div v-if="preiscrizioneModal.show" class="modal-overlay" @click.self="preiscrizioneModal.show = false">
        <div class="modal">
          <h3>PREISCRIZIONE - {{ categoria?.nome }}</h3>
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

    <div class="content">
      <div class="toolbar">
        <div class="search-wrap">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="search-icon">
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input v-model="search" placeholder="Cerca giocatore..." class="search-input" />
        </div>
        <div class="toolbar-actions">
          <button class="btn-tool" @click="apriPreiscrizione" title="Preiscrizione">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <line x1="19" y1="8" x2="19" y2="14"/>
              <line x1="22" y1="11" x2="16" y2="11"/>
            </svg>
            Preiscrizione
          </button>
          <button class="btn-tool btn-primary" @click="apriNuovo" title="Aggiungi Giocatore">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="12" y1="5" x2="12" y2="19"/>
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
            Aggiungi
          </button>
        </div>
      </div>

      <div class="mini-summary">
        <div class="mini-stat">
          <span class="mini-val">{{ filteredPlayers.length }}</span>
          <span class="mini-label">iscritti</span>
        </div>
        <div class="mini-stat">
          <span class="mini-val">{{ catIncasso }} €</span>
          <span class="mini-label">incasso</span>
        </div>
        <div class="mini-stat">
          <span class="mini-val" :class="{ 'debt': catRimane > 0 }">{{ catRimane }} €</span>
          <span class="mini-label">da recuperare</span>
        </div>
      </div>

      <div class="table-wrap">
        <table class="player-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Cognome</th>
              <th>Nome</th>
              <th>Totale</th>
              <th>Iscriz.</th>
              <th>R1</th>
              <th>R2</th>
              <th>R3</th>
              <th>R4</th>
              <th>Saldo</th>
              <th>Rimane</th>
              <th v-if="gdprSbloccato">Nascita</th>
              <th v-if="gdprSbloccato">CF</th>
              <th v-if="gdprSbloccato">Tel. Papà</th>
              <th v-if="gdprSbloccato">Tel. Mamma</th>
              <th v-if="gdprSbloccato">Scad. Cert.</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(p, idx) in filteredPlayers" :key="p.id" class="player-row" @click="apriScheda(p)">
              <td>{{ idx + 1 }}</td>
              <td class="col-cognome">{{ p.cognome }}</td>
              <td>{{ p.nome }}</td>
              <td class="col-money">
                <input type="number" step="0.01" class="money-input" :value="p.totale_da_pagare ?? ''" @click.stop @input="updateRate(p, 'totale_da_pagare', $event.target.value)" placeholder="€" />
              </td>
              <td class="col-money">
                <input type="number" step="0.01" class="money-input" :value="p.rata_iscrizione ?? ''" @click.stop @input="updateRate(p, 'rata_iscrizione', $event.target.value)" placeholder="€" />
              </td>
              <td class="col-money">
                <input type="number" step="0.01" class="money-input" :value="p.rata1 ?? ''" @click.stop @input="updateRate(p, 'rata1', $event.target.value)" placeholder="€" />
              </td>
              <td class="col-money">
                <input type="number" step="0.01" class="money-input" :value="p.rata2 ?? ''" @click.stop @input="updateRate(p, 'rata2', $event.target.value)" placeholder="€" />
              </td>
              <td class="col-money">
                <input type="number" step="0.01" class="money-input" :value="p.rata3 ?? ''" @click.stop @input="updateRate(p, 'rata3', $event.target.value)" placeholder="€" />
              </td>
              <td class="col-money">
                <input type="number" step="0.01" class="money-input" :value="p.rata4 ?? ''" @click.stop @input="updateRate(p, 'rata4', $event.target.value)" placeholder="€" />
              </td>
              <td class="col-money">
                <input type="number" step="0.01" class="money-input" :value="p.rata_saldo ?? ''" @click.stop @input="updateRate(p, 'rata_saldo', $event.target.value)" placeholder="€" />
              </td>
              <td class="col-rimane">
                <span :class="{'ok': calcRimane(p) <= 0}">{{ calcRimane(p).toFixed(2) }}</span>
              </td>
              <template v-if="gdprSbloccato">
                <td class="col-small">{{ formatData(p.data_nascita) }}</td>
                <td class="col-cf">{{ mascheraDato(p.codice_fiscale) || '-' }}</td>
                <td class="col-small">{{ mascheraDato(p.tel_papa) || '-' }}</td>
                <td class="col-small">{{ mascheraDato(p.tel_mamma) || '-' }}</td>
                <td class="col-small" :class="{ 'scad-rossa': isScaduta(p.scadenza_certificato) }">
                  {{ formatData(p.scadenza_certificato) }}
                </td>
              </template>
              <td class="col-actions">
                <div class="actions-group">
                  <button class="btn-action" @click.stop="apriScheda(p)" title="Scheda">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                      <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                      <line x1="3" y1="9" x2="21" y2="9"/>
                      <line x1="9" y1="21" x2="9" y2="9"/>
                    </svg>
                  </button>
                  <button class="btn-action btn-danger" @click.stop="eliminaGiocatore(p)" title="Elimina">
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
        <div v-if="filteredPlayers.length === 0" class="no-data">
          Nessun giocatore trovato
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, getCategorie, createPersona, updatePersona, deletePersona, createPublicPersona } from '../api/index.js'

const router = useRouter()
const route = useRoute()
const { utenteAttivo } = useStore()

const categoria = ref(null)
const giocatori = ref([])
const search = ref('')
const gdprSbloccato = ref(false)
const gdprModal = ref({ show: false, password: '', error: '' })
const preiscrizioneModal = ref({
  show: false,
  cognome: '',
  nome: '',
  link: '',
  copied: false
})

const catId = computed(() => parseInt(route.params.id))

onMounted(async () => {
  gdprSbloccato.value = localStorage.getItem('gdpr_sbloccato') === 'true'
  await loadDati()
})

watch(() => route.params.id, async () => {
  await loadDati()
})

async function loadDati() {
  try {
    const response = await getCategorie()
    let cats = Array.isArray(response) ? response : (response?.data || [])
    const target = cats.find(c => c.id === catId.value)
    categoria.value = target

    const pRes = await getPersone(catId.value)
    giocatori.value = Array.isArray(pRes) ? pRes : (pRes?.data || [])
  } catch(e) { console.error('Error loading:', e) }
}

const filteredPlayers = computed(() => {
  let list = giocatori.value
  if (!search.value) return list
  const s = search.value.toLowerCase()
  return list.filter(p =>
    p.nome?.toLowerCase().includes(s) ||
    p.cognome?.toLowerCase().includes(s) ||
    p.matricola?.toLowerCase().includes(s)
  )
})

function calcPagato(p) {
  return (p.rata_iscrizione || 0) + (p.rata1 || 0) + (p.rata2 || 0) + (p.rata3 || 0) + (p.rata4 || 0) + (p.rata_saldo || 0)
}

function calcRimane(p) {
  return (p.totale_da_pagare || 0) - calcPagato(p)
}

const catIncasso = computed(() => giocatori.value.reduce((s, p) => s + calcPagato(p), 0))
const catRimane = computed(() => giocatori.value.reduce((s, p) => s + calcRimane(p), 0))

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

function apriNuovo() {
  router.push('/segreteria/scheda/nuovo?categoria_id=' + catId.value)
}

function apriScheda(p) {
  router.push('/segreteria/scheda/' + p.id)
}

async function eliminaGiocatore(p) {
  if (!confirm(`Eliminare ${p.cognome} ${p.nome}?`)) return
  try {
    await deletePersona(p.id)
    await loadDati()
  } catch(e) { console.error('Error deleting:', e) }
}

async function updateRate(p, field, value) {
  const numVal = value === '' ? null : parseFloat(value)
  const payload = { [field]: numVal }
  p[field] = numVal
  await updatePersona(p.id, payload)
}

function apriPreiscrizione() {
  preiscrizioneModal.value = {
    show: true,
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
      categoria_id: catId.value
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
.cat-page {
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
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-icon svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
}

.btn-icon.btn-unlocked {
  background: #10b981;
  border-color: #10b981;
}

.page-title {
  font-size: 1rem;
  font-weight: 600;
}

.header-right { display: flex; gap: 0.5rem; }

.content { padding: 1rem; }

.toolbar {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.search-wrap {
  flex: 1;
  min-width: 200px;
  position: relative;
}

.search-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--color-text-secondary);
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 0.625rem 1rem 0.625rem 2.25rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
}

.toolbar-actions {
  display: flex;
  gap: 0.5rem;
}

.btn-tool {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.5rem 0.75rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.8rem;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
}

.btn-tool svg {
  width: 16px;
  height: 16px;
}

.btn-tool.btn-primary {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

.mini-summary {
  display: flex;
  gap: 1rem;
  margin-bottom: 1rem;
  padding: 0.75rem 1rem;
  background: var(--color-surface);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
}

.mini-stat {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
}

.mini-val {
  font-size: 1.1rem;
  font-weight: 700;
}

.mini-val.debt { color: #dc2626; }

.mini-label {
  font-size: 0.7rem;
  color: var(--color-text-secondary);
  text-transform: uppercase;
}

.table-wrap {
  overflow-x: auto;
  background: var(--color-surface);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
}

.player-table {
  width: 100%;
  border-collapse: collapse;
}

.player-table th {
  background: var(--color-surface-elevated);
  padding: 0.625rem 0.5rem;
  text-align: left;
  font-weight: 600;
  color: var(--color-text-secondary);
  font-size: 0.7rem;
  text-transform: uppercase;
  white-space: nowrap;
  border-bottom: 1px solid var(--color-border);
}

.player-table td {
  padding: 0.5rem;
  border-bottom: 1px solid var(--color-border);
  color: var(--color-text);
  font-size: 0.8rem;
}

.player-row {
  cursor: pointer;
  transition: background-color 0.15s;
}

.player-row:hover {
  background: rgba(99, 102, 241, 0.08);
}

.col-cognome {
  font-weight: 600;
}

.col-money { padding: 2px; }

.money-input {
  width: 100%;
  min-width: 48px;
  padding: 4px 6px;
  border: 1px solid transparent;
  border-radius: 4px;
  font-size: 0.8rem;
  text-align: right;
  background: transparent;
  color: var(--color-text);
  font-family: inherit;
  font-weight: 500;
}

.money-input:focus {
  outline: none;
  border-color: #5b7fff;
  box-shadow: 0 0 0 2px rgba(91, 127, 255, 0.15);
  background: var(--color-surface);
}

.col-rimane {
  font-weight: 700;
  font-size: 0.75rem;
  white-space: nowrap;
}

.col-rimane .ok { color: #16a34a; }

.col-small {
  white-space: nowrap;
  font-size: 0.75rem;
}

.col-cf {
  font-family: monospace;
  font-size: 0.7rem;
}

.scad-rossa {
  color: #dc2626;
  font-weight: 600;
}

.col-actions {
  width: 72px;
  text-align: center;
}

.actions-group {
  display: flex;
  gap: 4px;
  justify-content: center;
}

.btn-action {
  width: 30px;
  height: 30px;
  padding: 3px;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
}

.btn-action svg {
  width: 16px;
  height: 16px;
  color: #666;
}

.btn-action:hover {
  background: #e0e0ff;
}

.btn-action.btn-danger {
  background: #fef2f2;
  border-color: #fecaca;
}

.btn-action.btn-danger svg {
  color: #dc2626;
}

.btn-action.btn-danger:hover {
  background: #fecaca;
}

.no-data {
  text-align: center;
  padding: 2rem;
  color: var(--color-text-muted);
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
  max-width: 450px;
  padding: 1.5rem;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}

.modal h3 {
  font-size: 1.1rem;
  font-weight: 700;
  margin-bottom: 1rem;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.modal-header h3 { margin: 0; }

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

.modal-close svg { width: 20px; height: 20px; }

.modal-body { padding: 0.5rem 0; }

.gdpr-info {
  font-size: 0.875rem;
  color: var(--color-text-secondary);
  margin-bottom: 1rem;
}

.form-group { margin-bottom: 1rem; }

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

.form-field input {
  width: 100%;
  padding: 0.625rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
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
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 1rem;
}

.btn-annulla {
  padding: 0.625rem 1rem;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  color: var(--color-text);
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

.btn-salva:disabled {
  opacity: 0.5;
  cursor: not-allowed;
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

.btn-copy-link:hover { background: #4a6ae0; }
.btn-copy-link.copied { background: #16a34a; }
</style>
