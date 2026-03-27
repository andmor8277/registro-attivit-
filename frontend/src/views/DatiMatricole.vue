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
      <span class="titolo-toolbar">Dati & Matricole — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
      <button v-if="!isDirigente" class="btn-nuovo" @click="apriNuovo">+ Nuovo Giocatore</button>
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
              <th>Data Nascita</th>
              <th>Codice Fiscale</th>
              <th>Telefono</th>
              <th>Matricola</th>
              <th>Scad. Cert.</th>
              <th v-if="!isDirigente">Gruppo</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(p, idx) in filteredPersone" :key="p.id" :class="{ 'row-scad': !p.scadenza_certificato || isScaduta(p.scadenza_certificato) }">
              <td class="cell-num">{{ idx + 1 }}</td>
              <td>{{ p.cognome }}</td>
              <td>{{ p.nome }}</td>
              <td class="cell-numero">{{ p.numero_maglia || '-' }}</td>
              <td>{{ formatData(p.data_nascita) }}</td>
              <td class="cell-cf">{{ p.codice_fiscale || '-' }}</td>
              <td>{{ p.telefono || '-' }}</td>
              <td class="cell-matricola">{{ p.matricola || '-' }}</td>
              <td class="cell-scadenza" :class="{ 'scad-rossa': isScaduta(p.scadenza_certificato) }">
                {{ formatData(p.scadenza_certificato) }}
              </td>
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
              <td :colspan="isDirigente ? 9 : 10" class="no-data">Nessun giocatore trovato</td>
            </tr>
          </tbody>
        </table>
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

const isDirigente = computed(() => utenteAttivo.value?.ruolo === 'dirigente')

const modal = ref({ show: false, isNuovo: false, id: null, cognome: '', nome: '', numero_maglia: '', data_nascita: '', codice_fiscale: '', telefono: '', matricola: '', scadenza_certificato: '', gruppo_id: 1 })

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

function apriModifica(p) {
  modal.value = {
    show: true,
    isNuovo: false,
    id: p.id,
    cognome: p.cognome,
    nome: p.nome,
    numero_maglia: p.numero_maglia || '',
    data_nascita: p.data_nascita || '',
    codice_fiscale: p.codice_fiscale || '',
    telefono: p.telefono || '',
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
    telefono: '',
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
  
  try {
    const data = {
      nome: modal.value.nome,
      cognome: modal.value.cognome,
      gruppo_id: modal.value.gruppo_id || 1,
      categoria_id: categoriaId,
      data_nascita: modal.value.data_nascita || null,
      codice_fiscale: modal.value.codice_fiscale || null,
      telefono: modal.value.telefono || null,
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
.toolbar { display: flex; align-items: center; gap: 0.8rem; padding: 0.5rem 1rem; background: #8B0000; color: white; flex-shrink: 0; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 0.95rem; }
.btn-back { padding: 4px 12px; border-radius: 4px; border: 1px solid #555; background: #2a2a4a; color: white; cursor: pointer; }
.btn-nuovo { padding: 4px 14px; border-radius: 4px; border: none; background: #22c55e; color: white; cursor: pointer; font-weight: bold; }
.btn-nuovo:hover { background: #16a34a; }
.dati-body { flex: 1; overflow-y: auto; padding: 1rem; background: #111; }

.filters { display: flex; gap: 1rem; margin-bottom: 1rem; }
.search-input { flex: 1; padding: 0.5rem 1rem; border: 1px solid #333; border-radius: 4px; font-size: 0.9rem; background: #1a1a1a; color: #eee; }
.search-input::placeholder { color: #666; }
.gruppo-filter { padding: 0.5rem 1rem; border: 1px solid #333; border-radius: 4px; font-size: 0.9rem; background: #1a1a1a; color: #eee; }

.tabella-wrapper { overflow-x: auto; background: #1a1a1a; border-radius: 8px; }
.tabella-giocatori { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
.tabella-giocatori th { background: #CC0000; color: white; padding: 0.75rem 0.5rem; text-align: left; font-weight: 600; white-space: nowrap; }
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
.btn-modifica:hover { background: #CC0000; color: white; }
.no-data { text-align: center; padding: 2rem; color: #666; }

.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.8); display: flex; align-items: center; justify-content: center; z-index: 1000; }
.modal { background: #1a1a1a; padding: 1.5rem; border-radius: 12px; width: 90%; max-width: 500px; color: #ddd; border: 1px solid #333; }
.modal h3 { margin: 0 0 1rem; color: #ff6b6b; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.form-field label { display: block; font-size: 0.75rem; color: #888; margin-bottom: 0.25rem; text-transform: uppercase; }
.form-field input, .form-field select { width: 100%; padding: 0.5rem; border: 1px solid #333; border-radius: 4px; font-size: 0.9rem; box-sizing: border-box; background: #111; color: #eee; }
.form-field input:focus, .form-field select:focus { outline: none; border-color: #CC0000; }
.modal-actions { display: flex; justify-content: space-between; align-items: center; margin-top: 1rem; }
.modal-actions-right { display: flex; gap: 0.5rem; }
.btn-elimina { padding: 0.5rem 1rem; border: 1px solid #dc2626; border-radius: 4px; background: transparent; color: #dc2626; cursor: pointer; }
.btn-elimina:hover { background: #dc2626; color: white; }
.btn-annulla { padding: 0.5rem 1rem; border: 1px solid #444; border-radius: 4px; background: #222; color: #ddd; cursor: pointer; }
.btn-salva { padding: 0.5rem 1rem; border: none; border-radius: 4px; background: #CC0000; color: white; cursor: pointer; font-weight: 600; }
.btn-salva:hover { background: #a30000; }

.page-header { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1rem; background: #8B0000; }
.header-left { display: flex; gap: 0.25rem; }
.btn-back, .btn-home { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; transition: background 0.2s; }
.btn-back:hover, .btn-home:hover { background: rgba(255,255,255,0.2); }
.btn-back svg, .btn-home svg { width: 18px; height: 18px; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 0.95rem; color: white; }
.btn-nuovo { padding: 6px 14px; border-radius: 6px; border: none; background: #22c55e; color: white; cursor: pointer; font-size: 0.85rem; font-weight: 600; }
.btn-nuovo:hover { background: #16a34a; }
</style>
