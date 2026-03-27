<template>
  <div class="allenamenti-page">
    <div class="toolbar">
      <button class="btn-back" @click="router.push('/scelta/' + route.params.id)">← Indietro</button>
      <button class="btn-back" @click="router.push('/')">🏠 Home</button>
      <span class="titolo-toolbar">Allenamenti — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
      <select v-model="selectedWeek" class="week-select" @change="loadAllenamenti">
        <option v-for="w in settimane" :key="w.value" :value="w.value">{{ w.label }}</option>
      </select>
    </div>

    <div class="allenamenti-body">
      <div class="header-row">
        <div class="giocatori-col">Giocatore</div>
        <div v-for="g in giorniSettimana" :key="g.giorno" class="giorno-col" :class="{ 'weekend': g.isWeekend }">
          <div class="giorno-nome">{{ g.nome }}</div>
          <div class="giorno-data">{{ g.data }}</div>
        </div>
      </div>

      <div class="giocatori-list">
        <div v-for="p in persone" :key="p.id" class="giocatore-row">
          <div class="giocatore-info">
            <span class="cognome">{{ p.cognome }}</span>
            <span class="nome">{{ p.nome }}</span>
          </div>
          <div v-for="g in giorniSettimana" :key="g.giorno" class="cella-presenza" :class="getClasse(p.id, g.giorno)" @click="togglePresenza(p.id, g.giorno)">
            {{ getCodice(p.id, g.giorno) }}
          </div>
        </div>
      </div>

      <div class="totali-row">
        <div class="totale-label">Totale presenti</div>
        <div v-for="g in giorniSettimana" :key="g.giorno" class="totale-cella">
          {{ getTotali(g.giorno) }}
        </div>
      </div>
    </div>

    <!-- LEGENDA -->
    <div class="legenda">
      <span class="legenda-item"><span class="badge presenza">P</span> Presente</span>
      <span class="legenda-item"><span class="badge assenza">A</span> Assente</span>
    </div>

    <!-- MODAL PER AGGIUNGERE/MODIFICARE GIOCATORI -->
    <div v-if="modal.show" class="modal-overlay" @click.self="modal.show = false">
      <div class="modal">
        <h3>{{ modal.persona ? 'Modifica' : 'Nuovo' }} Giocatore</h3>
        <div class="form-row">
          <input v-model="modal.nome" placeholder="Nome" />
          <input v-model="modal.cognome" placeholder="Cognome" />
        </div>
        <div class="modal-actions">
          <button class="btn-annulla" @click="modal.show = false">Annulla</button>
          <button class="btn-salva" @click="salvaPersona">Salva</button>
        </div>
      </div>
    </div>

    <div class="actions-bar">
      <button class="btn-primary" @click="salvaTutto">💾 Salva</button>
      <button class="btn-secondary" @click="modal.show = true; modal.persona = null">+ Aggiungi Giocatore</button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, createPersona, updatePersona, deletePersona } from '../api/index.js'
import axios from 'axios'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva } = useStore()
const categoriaId = parseInt(route.params.id)

const base = '/api'
const token = () => localStorage.getItem('token')
const headers = () => ({ Authorization: 'Bearer ' + token() })

const persone = ref([])
const selectedWeek = ref(getWeekValue(new Date()))
const allenamenti = ref([])
const loading = ref(false)
const modal = ref({ show: false, persona: null, nome: '', cognome: '' })

const nomiGiorni = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab']

function getWeekValue(date) {
  const d = new Date(date)
  const day = d.getDay()
  const diff = d.getDate() - day + (day === 0 ? -6 : 1)
  const monday = new Date(d.setDate(diff))
  return monday.toISOString().split('T')[0]
}

const settimane = computed(() => {
  const weeks = []
  const today = new Date()
  for (let i = -8; i <= 8; i++) {
    const d = new Date(today)
    d.setDate(d.getDate() + i * 7)
    const monday = new Date(d)
    const day = d.getDay()
    const diff = d.getDate() - day + (day === 0 ? -6 : 1)
    monday.setDate(diff)
    const sunday = new Date(monday)
    sunday.setDate(monday.getDate() + 6)
    weeks.push({
      value: monday.toISOString().split('T')[0],
      label: `${monday.getDate()}/${monday.getMonth() + 1} - ${sunday.getDate()}/${sunday.getMonth() + 1}`
    })
  }
  return weeks
})

const giorniSettimana = computed(() => {
  const monday = new Date(selectedWeek.value)
  return nomiGiorni.map((nome, i) => {
    const d = new Date(monday)
    d.setDate(monday.getDate() + i)
    return {
      giorno: i,
      nome,
      data: `${d.getDate()}/${d.getMonth() + 1}`,
      dataISO: d.toISOString().split('T')[0],
      isWeekend: i === 0 || i === 6
    }
  })
})

function getAllenamentoKey(personaId, giorno) {
  return `${selectedWeek.value}_${giorno}_${personaId}`
}

function getCodice(personaId, giorno) {
  const key = getAllenamentoKey(personaId, giorno)
  return allenamenti.value.find(a => a.key === key)?.codice || ''
}

function getClasse(personaId, giorno) {
  const codice = getCodice(personaId, giorno)
  if (!codice) return 'vuota'
  if (codice === 'P') return 'presenza'
  if (codice === 'A') return 'assenza'
  return 'vuota'
}

function togglePresenza(personaId, giorno) {
  const key = getAllenamentoKey(personaId, giorno)
  const existing = allenamenti.value.find(a => a.key === key)
  
  if (!existing) {
    allenamenti.value.push({ key, persona_id: personaId, giorno, codice: 'P' })
  } else if (existing.codice === 'P') {
    existing.codice = 'A'
  } else if (existing.codice === 'A') {
    allenamenti.value = allenamenti.value.filter(a => a.key !== key)
  }
}

function getTotali(giorno) {
  return allenamenti.value.filter(a => a.giorno === giorno && a.codice === 'P').length
}

function formatDate(d) {
  if (!d) return ''
  const date = new Date(d)
  return date.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit' })
}

async function loadAllenamenti() {
  loading.value = true
  try {
    const res = await axios.get(base + '/allenamenti/', {
      params: { categoria_id: categoriaId, week: selectedWeek.value },
      headers: headers()
    })
    allenamenti.value = res.data.map(a => ({
      ...a,
      key: getAllenamentoKey(a.persona_id, a.giorno)
    }))
  } catch (e) {
    console.error('Errore caricamento:', e)
  }
  loading.value = false
}

async function salvaTutto() {
  try {
    const payload = allenamenti.value.map(a => ({
      persona_id: a.persona_id,
      giorno: a.giorno,
      codice: a.codice
    }))
    await axios.post(base + '/allenamenti/', {
      categoria_id: categoriaId,
      week: selectedWeek.value,
      presenze: payload
    }, { headers: headers() })
    alert('Salvato!')
  } catch (e) {
    console.error('Errore salvataggio:', e)
    alert('Errore nel salvataggio')
  }
}

function salvaPersona() {
  // Placeholder for adding new players
  modal.value.show = false
}

onMounted(async () => {
  const res = await getPersone(categoriaId)
  persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
  await loadAllenamenti()
})
</script>

<style scoped>
.allenamenti-page { display: flex; flex-direction: column; height: 100vh; }
.toolbar { display: flex; align-items: center; gap: 0.8rem; padding: 0.5rem 1rem; background: #22c55e; color: white; flex-shrink: 0; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 0.95rem; }
.btn-back { padding: 4px 12px; border-radius: 4px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; }
.week-select { padding: 4px 8px; border-radius: 4px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; }

.allenamenti-body { flex: 1; overflow: auto; padding: 1rem; }

.header-row { display: flex; border-bottom: 2px solid #ddd; padding-bottom: 0.5rem; margin-bottom: 0.5rem; position: sticky; top: 0; background: white; z-index: 10; }
.giocatori-col { width: 180px; flex-shrink: 0; font-weight: bold; font-size: 0.9rem; }
.giorno-col { flex: 1; text-align: center; padding: 0.5rem; min-width: 60px; }
.giorno-col.weekend { background: #f5f5f5; }
.giorno-nome { font-weight: bold; font-size: 0.85rem; color: #333; }
.giorno-data { font-size: 0.75rem; color: #666; }

.giocatori-list { }
.giocatore-row { display: flex; border-bottom: 1px solid #eee; }
.giocatore-row:hover { background: #f8f8f8; }
.giocatore-info { width: 180px; flex-shrink: 0; padding: 0.75rem 0.5rem; display: flex; flex-direction: column; }
.giocatore-info .cognome { font-weight: 600; font-size: 0.9rem; }
.giocatore-info .nome { font-size: 0.8rem; color: #666; }
.cella-presenza { flex: 1; display: flex; align-items: center; justify-content: center; padding: 0.75rem 0.5rem; cursor: pointer; min-width: 60px; font-size: 0.85rem; font-weight: bold; }
.cella-presenza.vuota { background: #fafafa; color: #ccc; }
.cella-presenza.presenza { background: #dcfce7; color: #16a34a; }
.cella-presenza.assenza { background: #fee2e2; color: #dc2626; }
.cella-presenza.weekend { background: #f0f0f0; }

.totali-row { display: flex; margin-top: 1rem; padding-top: 0.5rem; border-top: 2px solid #ddd; }
.totale-label { width: 180px; flex-shrink: 0; font-weight: bold; font-size: 0.85rem; }
.totale-cella { flex: 1; text-align: center; font-weight: bold; font-size: 0.85rem; min-width: 60px; }

.legenda { display: flex; gap: 1.5rem; padding: 0.75rem 1rem; background: #f5f5f5; border-top: 1px solid #ddd; }
.legenda-item { display: flex; align-items: center; gap: 0.5rem; font-size: 0.8rem; }
.legenda-item .badge { width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; border-radius: 4px; font-size: 0.75rem; font-weight: bold; }
.badge.presenza { background: #dcfce7; color: #16a34a; }
.badge.assenza { background: #fee2e2; color: #dc2626; }

.actions-bar { display: flex; gap: 0.5rem; padding: 0.75rem 1rem; background: #f5f5f5; border-top: 1px solid #ddd; }
.btn-primary { padding: 8px 20px; background: #22c55e; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; }
.btn-secondary { padding: 8px 20px; background: #666; color: white; border: none; border-radius: 4px; cursor: pointer; }

.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 1000; }
.modal { background: white; padding: 1.5rem; border-radius: 12px; width: 90%; max-width: 400px; }
.modal h3 { margin: 0 0 1rem; color: #22c55e; }
.form-row { display: flex; gap: 1rem; }
.form-row input { flex: 1; padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; }
.modal-actions { display: flex; justify-content: flex-end; gap: 0.5rem; margin-top: 1rem; }
.btn-annulla { padding: 0.5rem 1rem; border: 1px solid #ddd; border-radius: 4px; background: white; cursor: pointer; }
.btn-salva { padding: 0.5rem 1rem; border: none; border-radius: 4px; background: #22c55e; color: white; cursor: pointer; font-weight: 600; }
</style>
