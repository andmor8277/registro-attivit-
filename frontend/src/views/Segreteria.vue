<template>
  <div class="segreteria-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-icon" @click="router.push('/')">
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
      <span class="page-title">Segreteria</span>
      <div class="header-right">
        <button class="btn-icon" @click="router.push('/segreteria/openday')" title="Open Day">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M16 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
            <circle cx="8.5" cy="7" r="4"/>
            <line x1="20" y1="8" x2="20" y2="14"/>
            <line x1="23" y1="11" x2="17" y2="11"/>
          </svg>
        </button>
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

    <div class="content">
      <div class="summary-bar">
        <div class="summary-item">
          <span class="summary-label">Totale iscritti</span>
          <span class="summary-value">{{ totaleIscritti }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">Categorie</span>
          <span class="summary-value">{{ categorieOrdinate.length }}</span>
        </div>
        <div class="summary-item financial">
          <span class="summary-label">Totale incasso</span>
          <span class="summary-value" @click="toggleFinanze" style="cursor:pointer">
            {{ mostraFinanze ? totaleIncasso + ' €' : '*** €' }}
            <svg class="eye-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path v-if="mostraFinanze" d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
              <circle v-if="mostraFinanze" cx="12" cy="12" r="3"/>
              <path v-if="!mostraFinanze" d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24"/>
              <line v-if="!mostraFinanze" x1="1" y1="1" x2="23" y2="23"/>
            </svg>
          </span>
        </div>
        <div class="summary-item financial">
          <span class="summary-label">Da recuperare</span>
          <span class="summary-value" :class="{ 'debt': mostraFinanze && daRecuperare > 0 }" @click="toggleFinanze" style="cursor:pointer">
            {{ mostraFinanze ? daRecuperare + ' €' : '*** €' }}
            <svg class="eye-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path v-if="mostraFinanze" d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
              <circle v-if="mostraFinanze" cx="12" cy="12" r="3"/>
              <path v-if="!mostraFinanze" d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24"/>
              <line v-if="!mostraFinanze" x1="1" y1="1" x2="23" y2="23"/>
            </svg>
          </span>
        </div>
      </div>

      <div class="cat-grid">
        <div
          v-for="cat in categorieOrdinate"
          :key="cat.id"
          class="cat-card"
          @click="router.push('/segreteria/' + cat.id)"
        >
          <div class="cat-card-header">
            <span class="cat-anno">{{ cat.anno }}</span>
            <span class="cat-nome">{{ cat.nome }}</span>
          </div>
          <div class="cat-card-body">
            <div class="cat-stat">
              <span class="cat-stat-value">{{ getGiocatoriCat(cat.id).length }}</span>
              <span class="cat-stat-label">iscritti</span>
            </div>
            <div class="cat-stat financial" @click.stop="toggleFinanze">
              <span class="cat-stat-value">{{ mostraFinanze ? calcTotalePagato(cat.id) + ' €' : '***' }}</span>
              <span class="cat-stat-label">incasso</span>
            </div>
            <div class="cat-stat financial" @click.stop="toggleFinanze">
              <span class="cat-stat-value" :class="{ 'debt': mostraFinanze && calcRimaneCat(cat.id) > 0 }">{{ mostraFinanze ? calcRimaneCat(cat.id) + ' €' : '***' }}</span>
              <span class="cat-stat-label">da recuperare</span>
            </div>
          </div>
          <div class="cat-card-footer">
            <span class="cat-arrow">→</span>
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
import { getPersone, getCategorie } from '../api/index.js'

const router = useRouter()
const { utenteAttivo } = useStore()

const categorie = ref([])
const persone = ref([])
const gdprSbloccato = ref(false)
const gdprModal = ref({ show: false, password: '', error: '' })
const mostraFinanze = ref(false)

function toggleFinanze() {
  mostraFinanze.value = !mostraFinanze.value
}

const societaId = computed(() => {
  const u = utenteAttivo.value
  return u?.societa_id || parseInt(localStorage.getItem('societa_id')) || 1
})

onMounted(async () => {
  gdprSbloccato.value = sessionStorage.getItem('gdpr_sbloccato') === 'true'
  await loadDati()
})

async function loadDati() {
  try {
    const response = await getCategorie()
    let cats = Array.isArray(response) ? response : (response?.data || [])
    cats = cats.filter(c => c.societa_id === societaId.value)
    categorie.value = cats

    let all = []
    for (const cat of categorie.value) {
      const pRes = await getPersone(cat.id)
      const players = Array.isArray(pRes) ? pRes.map(p => ({...p, categoria_id: cat.id})) : ((pRes?.data || []).map(p => ({...p, categoria_id: cat.id})))
      all.push(...players)
    }
    persone.value = all
  } catch(e) { console.error('Error loading:', e) }
}

const categorieOrdinate = computed(() => {
  return [...categorie.value].sort((a, b) => (a.anno || 0) - (b.anno || 0))
})

function getGiocatoriCat(catId) {
  return persone.value.filter(p => p.categoria_id === catId)
}

function calcPagato(p) {
  return (p.rata_iscrizione || 0) + (p.rata1 || 0) + (p.rata2 || 0) + (p.rata3 || 0) + (p.rata4 || 0) + (p.rata_saldo || 0)
}

function calcRimane(p) {
  return (p.totale_da_pagare || 0) - calcPagato(p)
}

function calcTotalePagato(catId) {
  return getGiocatoriCat(catId).reduce((sum, p) => sum + calcPagato(p), 0)
}

function calcRimaneCat(catId) {
  return getGiocatoriCat(catId).reduce((sum, p) => sum + calcRimane(p), 0)
}

const totaleIscritti = computed(() => persone.value.length)

const totaleIncasso = computed(() => {
  return persone.value.reduce((sum, p) => sum + calcPagato(p), 0)
})

const daRecuperare = computed(() => {
  return persone.value.reduce((sum, p) => sum + calcRimane(p), 0)
})

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
      sessionStorage.setItem('gdpr_sbloccato', 'true')
    } else {
      gdprModal.value.error = 'Password errata'
    }
  } catch(e) {
    gdprModal.value.error = 'Errore di verifica'
  }
}
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

.header-right {
  display: flex;
  gap: 0.5rem;
}

.content {
  padding: 1rem;
}

.summary-bar {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}

.summary-item {
  background: var(--color-surface);
  border-radius: var(--radius-md);
  padding: 0.75rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.summary-label {
  font-size: 0.7rem;
  text-transform: uppercase;
  color: var(--color-text-secondary);
  font-weight: 600;
  letter-spacing: 0.03em;
}

.summary-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--color-text);
  display: flex;
  align-items: center;
  gap: 0.35rem;
}

.eye-icon {
  opacity: 0.5;
  transition: opacity 0.2s;
}

.summary-value:hover .eye-icon {
  opacity: 1;
}

.summary-item.financial {
  cursor: pointer;
}

.summary-value.debt {
  color: #dc2626;
}

.cat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.cat-card {
  background: var(--color-surface);
  border-radius: var(--radius-lg);
  overflow: hidden;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid var(--color-border);
}

.cat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  border-color: var(--color-primary);
}

.cat-card-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  background: linear-gradient(135deg, #7c3aed 0%, #6d28d9 100%);
}

.cat-anno {
  background: rgba(255, 255, 255, 0.2);
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
}

.cat-nome {
  flex: 1;
  font-weight: 600;
  font-size: 0.9rem;
}

.cat-card-body {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
  padding: 1rem;
}

.cat-stat {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
}

.cat-stat.financial {
  cursor: pointer;
  opacity: 0.7;
  transition: opacity 0.2s;
}

.cat-stat.financial:hover {
  opacity: 1;
}

.cat-stat-value {
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--color-text);
}

.cat-stat-value.debt {
  color: #dc2626;
}

.cat-stat-label {
  font-size: 0.65rem;
  color: var(--color-text-secondary);
  text-transform: uppercase;
  font-weight: 500;
}

.cat-card-footer {
  padding: 0.5rem 1rem;
  border-top: 1px solid var(--color-border);
  text-align: right;
}

.cat-arrow {
  font-size: 1.2rem;
  color: var(--color-primary);
  transition: transform 0.2s;
}

.cat-card:hover .cat-arrow {
  transform: translateX(4px);
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
  padding: 1.5rem;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.modal-header h3 {
  font-size: 1.1rem;
  font-weight: 700;
  margin: 0;
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
  padding: 0.5rem 0;
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

@media (max-width: 600px) {
  .summary-bar {
    grid-template-columns: repeat(2, 1fr);
  }
  .cat-grid {
    grid-template-columns: 1fr;
  }
}
</style>
