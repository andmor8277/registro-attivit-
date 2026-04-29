<template>
  <div class="dati-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/scelta/' + route.params.id)">
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
      <span class="titolo-toolbar">Dati Giocatori — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
      <div class="header-right">
        <button v-if="utenteAttivo?.is_admin || utenteAttivo?.ruolo === 'mister'" class="btn-header" @click="gdprModal.show = true" title="Sblocca Dati Sensibili">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
            <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
          </svg>
        </button>
        <button v-if="utenteAttivo?.is_admin || utenteAttivo?.ruolo === 'mister'" class="btn-header" @click="apriNuovo" title="Aggiungi Giocatore">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="5" x2="12" y2="19"/>
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
        </button>
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
.dati-page { display: flex; flex-direction: column; height: 100vh; }
.toolbar { display: flex; align-items: center; gap: 0.8rem; padding: 0.5rem 1rem; background: var(--color-primary); color: white; flex-shrink: 0; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 0.95rem; }
.btn-back { padding: 4px 12px; border-radius: 4px; border: 1px solid #555; background: #2a2a4a; color: white; cursor: pointer; }
.btn-nuovo { padding: 4px 14px; border-radius: 4px; border: none; background: #22c55e; color: white; cursor: pointer; font-weight: bold; }
.btn-nuovo:hover { background: #16a34a; }
.dati-body { flex: 1; overflow-y: auto; padding: 1rem; background: #111; }

.filters { display: flex; gap: 1rem; margin-bottom: 1rem; }
.search-input { flex: 1; padding: 0.5rem 1rem; border: 1px solid #333; border-radius: 4px; font-size: 0.9rem; background: #1a1a1a; color: #eee; }
.search-input::placeholder { color: #666; }
.gruppo-filter { padding: 0.5rem 1rem; border: 1px solid #333; border-radius: 4px; font-size: 0.9rem; background: #1a1a1a; color: #eee; }

.tabella-wrapper { overflow-x: auto; background: #1a1a1a; border-radius: 8px; -webkit-overflow-scrolling: touch; }
.tabella-giocatori { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
.tabella-giocatori th { background: var(--color-primary); color: white; padding: 0.75rem 0.5rem; text-align: left; font-weight: 600; white-space: nowrap; }
.tabella-giocatori td { padding: 0.6rem 0.5rem; border-bottom: 1px solid #2a2a2a; color: #ddd; }
.tabella-giocatori tr:hover { background: #252525; }
.tabella-giocatori tr.row-scad { background: rgba(234, 88, 12, 0.15); }
.tabella-giocatori tr.row-scad:hover { background: rgba(234, 88, 12, 0.25); }
.cell-num { width: 40px; color: #666; text-align: center; }
.cell-numero { color: #ffd700; font-weight: bold; font-size: 1.1rem; text-align: center; }
.cell-cf { font-size: 0.8rem; letter-spacing: 0.5px; }
.cell-matricola { color: #ff6b6b; font-weight: bold; }
.cell-scadenza { color: #22c55e; }
.cell-scadenza.scad-rossa { color: #ef4444; font-weight: bold; }
.cell-gruppo { text-align: center; }
.badge { display: inline-block; width: 24px; height: 24px; line-height: 24px; border-radius: 50%; font-size: 0.75rem; font-weight: bold; color: white; }
.badge-g1 { background: #2563eb; }
.badge-g2 { background: #16a34a; }
.badge-g3 { background: #9333ea; }
.badge-g4 { background: #ea580c; }
.cell-action { width: 50px; text-align: center; }
.btn-modifica { background: #333; border: none; cursor: pointer; font-size: 1rem; padding: 4px 10px; border-radius: 4px; color: #ddd; }
.btn-modifica:hover { background: var(--color-primary); color: white; }
.no-data { text-align: center; padding: 2rem; color: #666; }

.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.8); display: flex; align-items: center; justify-content: center; z-index: 1000; }
.modal { background: #1a1a1a; padding: 1.5rem; border-radius: 12px; width: 90%; max-width: 500px; color: #ddd; border: 1px solid #333; }
.modal h3 { margin: 0 0 1rem; color: #ff6b6b; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.form-field label { display: block; font-size: 0.75rem; color: #888; margin-bottom: 0.25rem; text-transform: uppercase; }
.form-field input, .form-field select { width: 100%; padding: 0.5rem; border: 1px solid #333; border-radius: 4px; font-size: 0.9rem; box-sizing: border-box; background: #111; color: #eee; }
.form-field input:focus, .form-field select:focus { outline: none; border-color: var(--color-primary); }
.modal-actions { display: flex; justify-content: space-between; align-items: center; margin-top: 1rem; }
.modal-actions-right { display: flex; gap: 0.5rem; }
.btn-elimina { padding: 0.5rem 1rem; border: 1px solid var(--color-primary); border-radius: 4px; background: transparent; color: var(--color-primary); cursor: pointer; }
.btn-elimina:hover { background: var(--color-primary); color: white; }
.btn-annulla { padding: 0.5rem 1rem; border: 1px solid #444; border-radius: 4px; background: #222; color: #ddd; cursor: pointer; }
.btn-salva { padding: 0.5rem 1rem; border: none; border-radius: 4px; background: var(--color-primary); color: white; cursor: pointer; font-weight: 600; }
.btn-salva:hover { background: var(--color-primary-dark); }

.page-header { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1rem; background: var(--color-primary); }
.header-right { display: flex; gap: 0.25rem; margin-left: auto; }
.btn-header { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; }
.btn-header:hover { background: rgba(255,255,255,0.2); }
.btn-header svg { width: 18px; height: 18px; }
.header-left { display: flex; gap: 0.25rem; }
.btn-back, .btn-home { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; transition: background 0.2s; }
.btn-back:hover, .btn-home:hover { background: rgba(255,255,255,0.2); }
.btn-back svg, .btn-home svg { width: 18px; height: 18px; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 0.95rem; color: white; }
.header-right { display: flex; gap: 0.5rem; align-items: center; }
.btn-sblocca { padding: 6px 12px; border-radius: 6px; border: 1px solid rgba(255,255,255,0.5); background: rgba(255,255,255,0.1); color: white; cursor: pointer; font-size: 0.8rem; }
.btn-sblocca:hover { background: rgba(255,255,255,0.2); }
.btn-sblocca.sbloccato { background: #22c55e; border-color: #22c55e; }
.btn-nuovo { padding: 6px 14px; border-radius: 6px; border: none; background: #22c55e; color: white; cursor: pointer; font-size: 0.85rem; font-weight: 600; }
.btn-nuovo:hover { background: #16a34a; }

.modal-small { max-width: 350px; }
.gdpr-info { font-size: 0.9rem; color: #888; margin-bottom: 1rem; }
.error-msg { color: #ef4444; font-size: 0.85rem; margin-top: 0.5rem; }
</style>
