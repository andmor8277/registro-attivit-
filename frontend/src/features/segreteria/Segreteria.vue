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
            <p class="gdpr-info">Per sbloccare i dati sensibili (CF, telefoni) inserisci il tuo codice fiscale:</p>
            <input v-model="gdprModal.password" @keyup.enter="sbloccaGdpr" class="gdpr-cf-input" placeholder="Codice fiscale" maxlength="16" autocomplete="off" />
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
        <div class="cat-card openday-card" @click="router.push('/segreteria/openday')">
          <div class="cat-card-header openday-header">
            <span class="cat-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                <path d="M16 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                <circle cx="8.5" cy="7" r="4"/>
                <line x1="20" y1="8" x2="20" y2="14"/>
                <line x1="23" y1="11" x2="17" y2="11"/>
              </svg>
            </span>
            <span class="cat-nome">Iscrizioni OpenDay</span>
          </div>
          <div class="cat-card-body openday-body">
            <div class="cat-stat">
              <span class="cat-stat-value">{{ opendayStats.pending }}</span>
              <span class="cat-stat-label">in prova</span>
            </div>
            <div class="cat-stat">
              <span class="cat-stat-value enrolled">{{ opendayStats.enrolled }}</span>
              <span class="cat-stat-label">iscritti</span>
            </div>
          </div>
          <div class="cat-card-footer">
            <span class="cat-arrow">→</span>
          </div>
        </div>
      </div>

      <!-- Filtro rapido categorie padre -->
      <div class="cat-filter-bar">
        <button
          class="cat-filter-btn"
          :class="{ active: filtroPadre === 'tutti' }"
          @click="filtroPadre = 'tutti'"
        >
          Tutte ({{ categorieOrdinate.length }})
        </button>
        <button
          class="cat-filter-btn btn-scuola"
          :class="{ active: filtroPadre === 'scuola' }"
          @click="filtroPadre = 'scuola'"
        >
          <span class="filter-dot dot-scuola"></span>
          Scuola Calcio ({{ categorieScuolaCalcio.length }})
        </button>
        <button
          class="cat-filter-btn btn-agonistica"
          :class="{ active: filtroPadre === 'agonistica' }"
          @click="filtroPadre = 'agonistica'"
        >
          <span class="filter-dot dot-agonistica"></span>
          Agonistica ({{ categorieAgonistica.length }})
        </button>
      </div>

      <!-- SEZIONE 1: SCUOLA CALCIO -->
      <div v-if="categorieScuolaCalcio.length && (filtroPadre === 'tutti' || filtroPadre === 'scuola')" class="group-section">
        <div class="section-divider section-scuola">
          <div class="section-title-wrap">
            <span class="group-badge badge-scuola">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                <circle cx="12" cy="12" r="10"/>
                <path d="M12 6v6l4 2"/>
              </svg>
              Scuola Calcio
            </span>
            <span class="group-count">{{ categorieScuolaCalcio.length }} squadre</span>
          </div>
        </div>

        <div class="cat-grid">
          <div
            v-for="cat in categorieScuolaCalcio"
            :key="cat.id"
            class="cat-card card-scuola"
            @click="router.push('/segreteria/' + cat.id)"
          >
            <div class="cat-card-header">
              <span class="cat-anno">{{ cat.anno || '—' }}</span>
              <span class="cat-nome">{{ cat.nome }}</span>
              <span class="parent-tag tag-scuola">Scuola Calcio</span>
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
              <div class="cat-stat">
                <span class="cat-stat-value" :class="{ 'debt': nonInRegolaCat(cat.id) > 0 }">{{ nonInRegolaCat(cat.id) }}</span>
                <span class="cat-stat-label">non in regola</span>
              </div>
            </div>
            <div class="cat-card-footer">
              <span class="cat-arrow">→</span>
            </div>
          </div>
        </div>
      </div>

      <!-- SEZIONE 2: AGONISTICA -->
      <div v-if="categorieAgonistica.length && (filtroPadre === 'tutti' || filtroPadre === 'agonistica')" class="group-section">
        <div class="section-divider section-agonistica">
          <div class="section-title-wrap">
            <span class="group-badge badge-agonistica">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
              </svg>
              Agonistica
            </span>
            <span class="group-count">{{ categorieAgonistica.length }} squadre</span>
          </div>
        </div>

        <div class="cat-grid">
          <div
            v-for="cat in categorieAgonistica"
            :key="cat.id"
            class="cat-card card-agonistica"
            @click="router.push('/segreteria/' + cat.id)"
          >
            <div class="cat-card-header">
              <span class="cat-anno">{{ cat.anno || '—' }}</span>
              <span class="cat-nome">{{ cat.nome }}</span>
              <span class="parent-tag tag-agonistica">Agonistica</span>
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
              <div class="cat-stat">
                <span class="cat-stat-value" :class="{ 'debt': nonInRegolaCat(cat.id) > 0 }">{{ nonInRegolaCat(cat.id) }}</span>
                <span class="cat-stat-label">non in regola</span>
              </div>
            </div>
            <div class="cat-card-footer">
              <span class="cat-arrow">→</span>
            </div>
          </div>
        </div>
      </div>

      <!-- SEZIONE 3: ALTRE CATEGORIE (se presenti) -->
      <div v-if="categorieAltre.length && filtroPadre === 'tutti'" class="group-section">
        <div class="section-divider">
          <div class="section-title-wrap">
            <span class="group-badge">Altre Categorie</span>
            <span class="group-count">{{ categorieAltre.length }} squadre</span>
          </div>
        </div>

        <div class="cat-grid">
          <div
            v-for="cat in categorieAltre"
            :key="cat.id"
            class="cat-card card-default"
            @click="router.push('/segreteria/' + cat.id)"
          >
            <div class="cat-card-header">
              <span class="cat-anno">{{ cat.anno || '—' }}</span>
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
              <div class="cat-stat">
                <span class="cat-stat-value" :class="{ 'debt': nonInRegolaCat(cat.id) > 0 }">{{ nonInRegolaCat(cat.id) }}</span>
                <span class="cat-stat-label">non in regola</span>
              </div>
            </div>
            <div class="cat-card-footer">
              <span class="cat-arrow">→</span>
            </div>
          </div>
        </div>
      </div>

      <div class="section-divider">
        <span>Altri Moduli</span>
      </div>

      <div class="cat-grid">
        <div class="cat-card cert-card" @click="router.push('/infermeria/certificati')">
          <div class="cat-card-header cert-header">
            <span class="cat-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                <path d="M9 12l2 2 4-4"/>
                <path d="M12 2a10 10 0 100 20 10 10 0 000-20z"/>
                <path d="M12 6v6"/>
              </svg>
            </span>
            <span class="cat-nome">Certificati Medici</span>
          </div>
          <div class="cat-card-body">
            <div class="cat-stat">
              <span class="cat-stat-value" :class="{ 'stat-danger': scadutiTotali > 0 }">{{ scadutiTotali }}</span>
              <span class="cat-stat-label">scaduti</span>
            </div>
            <div class="cat-stat">
              <span class="cat-stat-value" :class="{ 'stat-warning': inScadenzaTotali > 0 }">{{ inScadenzaTotali }}</span>
              <span class="cat-stat-label">in scadenza</span>
            </div>
          </div>
          <div class="cat-card-footer">
            <span class="cat-arrow">→</span>
          </div>
        </div>

        <div class="cat-card infortuni-card" @click="router.push('/infermeria/infortunati')">
          <div class="cat-card-header infortuni-header">
            <span class="cat-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                <path d="M12 21C7 17 3 13.5 3 9.5A5.5 5.5 0 0113.6 6H12a5.5 5.5 0 018 3.5c0 4-4 7.5-8 11.5z"/>
              </svg>
            </span>
            <span class="cat-nome">Infortunati</span>
          </div>
          <div class="cat-card-body">
            <div class="cat-stat">
              <span class="cat-stat-value" :class="{ 'stat-danger': infortunatiAttivi > 0 }">{{ infortunatiAttivi }}</span>
              <span class="cat-stat-label">infortunati</span>
            </div>
          </div>
          <div class="cat-card-footer">
            <span class="cat-arrow">→</span>
          </div>
        </div>

        <div class="cat-card presenze-card" @click="router.push('/segreteria/presenze')">
          <div class="cat-card-header presenze-header">
            <span class="cat-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                <path d="M16 4h2a2 2 0 012 2v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h2"/>
                <rect x="8" y="2" width="8" height="4" rx="1" ry="1"/>
                <path d="M9 14l2 2 4-4"/>
              </svg>
            </span>
            <span class="cat-nome">Presenze</span>
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
import { useStore } from '../../store.js'
import { getPersone, getCategorie, getOpenday, verifyGdpr, getInfortuni } from '../../api/index.js'

const router = useRouter()
const { utenteAttivo } = useStore()

const categorie = ref([])
const persone = ref([])
const gdprSbloccato = ref(false)
const gdprModal = ref({ show: false, password: '', error: '' })
const mostraFinanze = ref(false)
const opendayStats = ref({ pending: 0, enrolled: 0 })
const infortunatiAttivi = ref(0)

function isScaduta(data) {
  if (!data) return false
  return new Date(data) < new Date()
}

function isInScadenza(data) {
  if (!data) return false
  const oggi = new Date()
  const scad = new Date(data)
  const diff = (scad - oggi) / (1000 * 60 * 60 * 24)
  return diff >= 0 && diff <= 30
}

const scadutiTotali = computed(() => {
  return persone.value.filter(p => p.scadenza_certificato && isScaduta(p.scadenza_certificato)).length
})

const inScadenzaTotali = computed(() => {
  return persone.value.filter(p => p.scadenza_certificato && isInScadenza(p.scadenza_certificato)).length
})

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
    const socCats = cats.filter(c => c.societa_id === societaId.value)
    const parents = socCats.filter(c => c.parent_id === null || c.parent_id === undefined)
    const children = socCats.filter(c => !c.is_portieri && c.parent_id !== null && c.parent_id !== undefined)

    categorie.value = children.map(c => {
      const p = parents.find(parent => parent.id === c.parent_id)
      const pNome = (p?.nome || '').toLowerCase()
      return {
        ...c,
        parentNome: p?.nome || '',
        is_scuola: pNome.includes('scuola'),
        is_agonistica: pNome.includes('agonistica')
      }
    })

    const validCatIds = new Set(children.map(c => c.id))
    const pRes = await getPersone()
    const players = Array.isArray(pRes) ? pRes : (pRes?.data || [])
    persone.value = players.filter(p => validCatIds.has(p.categoria_id))

    try {
      const oRes = await getOpenday()
      const entries = Array.isArray(oRes) ? oRes : (oRes?.data || [])
      opendayStats.value = {
        pending: entries.filter(e => !e.iscritto).length,
        enrolled: entries.filter(e => e.iscritto).length
      }
    } catch(e) { /* silent */ }

    try {
      const infRes = await getInfortuni({ attivi: true })
      const infData = Array.isArray(infRes) ? infRes : (infRes?.data || [])
      infortunatiAttivi.value = infData.length
    } catch(e) { /* silent */ }
  } catch(e) { console.error('Error loading:', e) }
}

const filtroPadre = ref('tutti')

const categorieScuolaCalcio = computed(() => {
  return categorie.value
    .filter(c => c.is_scuola)
    .sort((a, b) => (a.anno || 0) - (b.anno || 0) || (a.nome || '').localeCompare(b.nome || ''))
})

const categorieAgonistica = computed(() => {
  return categorie.value
    .filter(c => c.is_agonistica)
    .sort((a, b) => (a.anno || 0) - (b.anno || 0) || (a.nome || '').localeCompare(b.nome || ''))
})

const categorieAltre = computed(() => {
  return categorie.value
    .filter(c => !c.is_scuola && !c.is_agonistica)
    .sort((a, b) => (a.anno || 0) - (b.anno || 0) || (a.nome || '').localeCompare(b.nome || ''))
})

const categorieOrdinate = computed(() => {
  return [
    ...categorieScuolaCalcio.value,
    ...categorieAgonistica.value,
    ...categorieAltre.value
  ]
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

function nonInRegolaCat(catId) {
  return getGiocatoriCat(catId).filter(p => p.pagamenti_in_regola === false).length
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
  if (!gdprModal.value.password) {
    gdprModal.value.error = 'Inserisci il tuo codice fiscale'
    return
  }
  try {
    await verifyGdpr(gdprModal.value.password)
    gdprSbloccato.value = true
    gdprModal.value.show = false
    gdprModal.value.password = ''
    sessionStorage.setItem('gdpr_sbloccato', 'true')
  } catch(e) {
    gdprModal.value.error = e.response?.data?.detail || 'Codice fiscale non valido'
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

.cat-filter-bar {
  display: flex;
  gap: 0.5rem;
  margin: 1.5rem 0 1rem;
  flex-wrap: wrap;
}

.cat-filter-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.4rem 0.85rem;
  border-radius: 9999px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  color: var(--color-text-secondary);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
}

.cat-filter-btn:hover {
  border-color: var(--color-text);
  color: var(--color-text);
}

.cat-filter-btn.active {
  background: var(--color-surface-elevated, #27272a);
  border-color: var(--color-text);
  color: #fff;
}

.cat-filter-btn.btn-scuola.active {
  background: rgba(16, 185, 129, 0.15);
  border-color: #10b981;
  color: #10b981;
}

.cat-filter-btn.btn-agonistica.active {
  background: rgba(99, 102, 241, 0.15);
  border-color: #6366f1;
  color: #818cf8;
}

.filter-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.dot-scuola {
  background: #10b981;
}

.dot-agonistica {
  background: #6366f1;
}

.group-section {
  margin-bottom: 2rem;
}

.section-title-wrap {
  display: flex;
  align-items: center;
  gap: 0.6rem;
}

.group-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-weight: 700;
  font-size: 0.85rem;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.badge-scuola {
  color: #10b981;
}

.badge-agonistica {
  color: #818cf8;
}

.group-count {
  font-size: 0.75rem;
  color: var(--color-text-secondary);
  font-weight: 500;
  text-transform: lowercase;
}

.section-divider {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin: 1.5rem 0 1rem;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--color-text-muted, #6b7280);
}

.section-divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--color-border);
}

.section-scuola::after {
  background: linear-gradient(90deg, rgba(16, 185, 129, 0.5), var(--color-border));
}

.section-agonistica::after {
  background: linear-gradient(90deg, rgba(99, 102, 241, 0.5), var(--color-border));
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
  color: #ffffff;
}

/* Card Scuola Calcio: Smeraldo */
.card-scuola .cat-card-header {
  background: linear-gradient(135deg, #059669 0%, #047857 100%);
}

.card-scuola:hover {
  border-color: #10b981;
  box-shadow: 0 8px 24px rgba(16, 185, 129, 0.15);
}

.card-scuola:hover .cat-arrow {
  color: #10b981;
}

/* Card Agonistica: Indaco */
.card-agonistica .cat-card-header {
  background: linear-gradient(135deg, #4f46e5 0%, #4338ca 100%);
}

.card-agonistica:hover {
  border-color: #6366f1;
  box-shadow: 0 8px 24px rgba(99, 102, 241, 0.15);
}

.card-agonistica:hover .cat-arrow {
  color: #6366f1;
}

/* Card Default */
.card-default .cat-card-header {
  background: linear-gradient(135deg, #64748b 0%, #475569 100%);
}

/* Parent Tag */
.parent-tag {
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  padding: 0.15rem 0.45rem;
  border-radius: 4px;
  margin-left: auto;
  white-space: nowrap;
}

.tag-scuola {
  background: rgba(0, 0, 0, 0.25);
  color: #a7f3d0;
  border: 1px solid rgba(255, 255, 255, 0.15);
}

.tag-agonistica {
  background: rgba(0, 0, 0, 0.25);
  color: #c7d2fe;
  border: 1px solid rgba(255, 255, 255, 0.15);
}

.cat-anno {
  background: rgba(255, 255, 255, 0.2);
  color: #ffffff;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 700;
}

.cat-nome {
  font-weight: 600;
  font-size: 0.9rem;
  color: #ffffff;
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

.openday-card .cat-card-header.openday-header {
  background: linear-gradient(135deg, #0d9488 0%, #0f766e 100%);
}

.openday-card:hover {
  border-color: #0d9488;
}

.openday-card .cat-icon {
  display: flex;
  align-items: center;
  opacity: 0.9;
}

.openday-card .cat-card-body.openday-body {
  grid-template-columns: repeat(2, 1fr);
}

.presenze-card .cat-card-header.presenze-header {
  background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
}

.presenze-card:hover {
  border-color: #2563eb;
}

.presenze-card .cat-icon {
  display: flex;
  align-items: center;
  opacity: 0.9;
}

.cert-card .cat-card-header.cert-header {
  background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
}

.cert-card:hover {
  border-color: #f59e0b;
}

.infortuni-card .cat-card-header.infortuni-header {
  background: linear-gradient(135deg, #ef4444 0%, #b91c1c 100%);
}

.infortuni-card:hover {
  border-color: #ef4444;
}

.cat-stat-value.stat-danger {
  color: #ef4444;
}

.cat-stat-value.stat-warning {
  color: #f59e0b;
}

.openday-body .cat-stat-value.enrolled {
  color: #10b981;
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

.gdpr-cf-input {
  width: 100%;
  padding: 0.75rem;
  margin-bottom: 1rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  text-transform: uppercase;
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
