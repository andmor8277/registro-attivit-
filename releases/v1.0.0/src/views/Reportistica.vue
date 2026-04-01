<template>
  <div class="reportistica-page">
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
      <span class="titolo-toolbar">Reportistica — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
    </header>

    <div class="reportistica-body">
      <div class="filters">
        <div class="date-range">
          <label>Da:</label>
          <input type="date" v-model="dataInizio" @change="ricalcolaDati">
          <label>A:</label>
          <input type="date" v-model="dataFine" @change="ricalcolaDati">
        </div>
      </div>

      <div class="section">
        <h3 class="section-title">📉 Assenze per Giocatore</h3>
        <div class="table-wrapper">
          <table class="report-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Cognome</th>
                <th>Nome</th>
                <th>Assenze</th>
                <th>% Assenze</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(g, idx) in assenzePerGiocatore" :key="g.id">
                <td>{{ idx + 1 }}</td>
                <td>{{ g.cognome }}</td>
                <td>{{ g.nome }}</td>
                <td class="text-danger">{{ g.assenze }}</td>
                <td>{{ g.percentuale }}%</td>
              </tr>
              <tr v-if="assenzePerGiocatore.length === 0">
                <td colspan="5" class="no-data">Nessun dato disponibile</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <h3 class="section-title">⚽ Convocazioni per Giornata</h3>
        <div class="table-wrapper">
          <table class="report-table">
            <thead>
              <tr>
                <th>Giocatore</th>
                <th>Data</th>
                <th>Gare</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="item in convocatiPerGiornata" :key="item.key">
                <td>{{ item.cognome }}</td>
                <td>{{ item.data }}</td>
                <td class="text-warning">{{ item.numGare }}</td>
              </tr>
              <tr v-if="convocatiPerGiornata.length === 0">
                <td colspan="3" class="no-data">Nessuna convocazione registrata</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, getRegistroMese, getConvocazioni, getConvocazione, getAllCategorie } from '../api/index.js'

const router = useRouter()
const route = useRoute()
const { societaAttiva, setCategoria, categoriaAttiva } = useStore()
const categoriaId = parseInt(route.params.id)

const categoria = ref(null)
const dataInizio = ref('')
const dataFine = ref('')
const assenzePerGiocatore = ref([])
const convocatiPerGiornata = ref([])
const personeMap = ref(new Map())

function formatData(d) {
  if (!d) return '-'
  return d.split('-').reverse().join('/')
}

function getPersonaNome(id) {
  const p = personeMap.value.get(id)
  return p ? { cognome: p.cognome, nome: p.nome } : { cognome: '?', nome: '?' }
}

function getWeekend(data) {
  const d = new Date(data)
  const day = d.getDay()
  const diff = d.getDate() - day + (day === 0 ? -6 : 1)
  const weekStart = new Date(d.getFullYear(), d.getMonth(), diff)
  return weekStart.toISOString().split('T')[0]
}

async function ricalcolaDati() {
  if (!dataInizio.value || !dataFine.value) return
  
  const giocatoriMap = new Map()
  const giorniTotali = new Set()
  
  for (const [id, p] of personeMap.value) {
    giocatoriMap.set(id, { id: id, cognome: p.cognome, nome: p.nome, assenze: 0, totaleGiorni: 0 })
  }
  
  const oggi = new Date()
  for (let m = 0; m < 12; m++) {
    const d = new Date(oggi.getFullYear(), oggi.getMonth() - m, 1)
    const anno = d.getFullYear()
    const mese = d.getMonth() + 1
    
    try {
      const regRes = await getRegistroMese(categoriaId, anno, mese)
      const entries = regRes.data || []
      
      for (const e of entries) {
        if (!e.data) continue
        if (e.data < dataInizio.value || e.data > dataFine.value) continue
        
        giorniTotali.add(e.data)
        
        if (e.codice === 'AG' || e.codice === 'AI') {
          if (giocatoriMap.has(e.persona_id)) {
            giocatoriMap.get(e.persona_id).assenze++
          }
        }
      }
    } catch (e) {
      // no data for this month
    }
  }
  
  const tot = giorniTotali.size
  
  assenzePerGiocatore.value = Array.from(giocatoriMap.values()).map(g => {
    g.percentuale = tot > 0 ? Math.min(100, Math.round((g.assenze / tot) * 100)) : 0
    return g
  }).sort((a, b) => b.assenze - a.assenze)
}

async function caricaConvocati() {
  try {
    const convRes = await getConvocazioni(categoriaId)
    const convsList = convRes.data || []
    
    const dataMap = new Map()
    
    for (const conv of convsList) {
      try {
        const convDetailRes = await getConvocazione(conv.id)
        const convDetail = convDetailRes.data
        
        if (!convDetail || !convDetail.data_inizio) continue
        
        for (const gara of convDetail.gare || []) {
          const dataGara = gara.data
          if (!dataGara) continue
          
          if (!dataMap.has(dataGara)) {
            dataMap.set(dataGara, new Map())
          }
          
          const map = dataMap.get(dataGara)
          
          for (const g of gara.giocatori || []) {
            if (!map.has(g.persona_id)) {
              map.set(g.persona_id, { 
                id: g.persona_id, 
                cognome: g.cognome, 
                nome: g.nome, 
                numGare: 0 
              })
            }
            map.get(g.persona_id).numGare++
          }
        }
      } catch (e) {
        // skip
      }
    }
    
    const risultato = []
    for (const [data, players] of dataMap) {
      for (const p of players.values()) {
        if (p.numGare >= 2) {
          risultato.push({
            key: data + '_' + p.id,
            data: formatData(data),
                cognome: p.cognome,
                nome: p.nome,
            numGare: p.numGare
          })
        }
      }
    }
    
    convocatiPerGiornata.value = risultato.sort((a, b) => a.data.localeCompare(b.data))
  } catch (e) {
    // no data
  }
}

onMounted(async () => {
  try {
    const societaId = societaAttiva.value?.id || null
    
    const [catRes, personeRes] = await Promise.all([
      getAllCategorie(societaId),
      getPersone(categoriaId)
    ])
    
    const cats = catRes.data || []
    categoria.value = cats.find(c => c.id === categoriaId)
    if (categoria.value) {
      setCategoria(categoria.value)
      
      if (categoria.value.data_inizio_stagione) {
        dataInizio.value = categoria.value.data_inizio_stagione
      } else {
        const inizioAnno = new Date(new Date().getFullYear(), 0, 1)
        dataInizio.value = inizioAnno.toISOString().split('T')[0]
      }
      
      if (categoria.value.data_fine_stagione) {
        dataFine.value = categoria.value.data_fine_stagione
      } else {
        const today = new Date()
        dataFine.value = today.toISOString().split('T')[0]
      }
    }
    
    const ppl = personeRes.data || []
    for (const p of ppl) {
      personeMap.value.set(p.id, p)
    }
    
    await Promise.all([
      ricalcolaDati(),
      caricaConvocati()
    ])
    
  } catch (e) {
    console.error('Errore caricamento reportistica:', e)
  }
})
</script>

<style scoped>
.reportistica-page { display: flex; flex-direction: column; height: 100vh; background: #111; }

.page-header { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1rem; background: var(--color-primary); }
.header-left { display: flex; gap: 0.25rem; }
.btn-back, .btn-home { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; }
.btn-back svg, .btn-home svg { width: 18px; height: 18px; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 1rem; color: white; }

.reportistica-body { flex: 1; overflow-y: auto; padding: 1rem; }

.filters { margin-bottom: 1.5rem; }
.date-range { display: flex; align-items: center; gap: 0.5rem; background: #1a1a1a; padding: 1rem; border-radius: 8px; }
.date-range label { color: #888; }
.date-range input { background: #2a2a2a; border: 1px solid #444; color: #ddd; padding: 0.5rem; border-radius: 4px; }

.section { margin-bottom: 1.5rem; }
.section-title { font-size: 1rem; color: #ddd; margin-bottom: 0.75rem; padding-left: 0.5rem; border-left: 3px solid var(--color-primary); }

.table-wrapper { background: #1a1a1a; border-radius: 8px; overflow: hidden; }
.report-table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
.report-table th { background: var(--color-primary); color: white; padding: 0.75rem; text-align: left; font-weight: 600; }
.report-table td { padding: 0.6rem 0.75rem; border-bottom: 1px solid #2a2a2a; color: #ddd; }
.report-table tr:hover { background: #252525; }

.text-danger { color: #ef4444; }
.text-warning { color: #eab308; }
.no-data { text-align: center; color: #666; padding: 1rem; }
</style>
