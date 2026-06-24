<template>
  <div class="scelta-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <div v-if="!categoria" class="loading-state">
      <div class="loading-spinner"></div>
      <p>Caricamento...</p>
    </div>

    <template v-else>
    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          <span>{{ categoria.is_archived ? 'Stagioni Passate' : 'Categorie' }}</span>
        </button>
        <div class="header-badge">
          <span class="badge-dot"></span>
          <span>{{ currentSeason }}</span>
        </div>
      </div>
      <div class="header-main">
        <h1 class="category-name">
          <span class="name-gradient">
            {{ categoria.is_archived ? categoria.nome : (categoria.anno ? categoria.nome + ' ' + categoria.anno : categoria.nome) }}
          </span>
        </h1>
        <p class="header-subtitle" v-if="!categoria.is_archived">Cosa vuoi gestire?</p>
        <p class="header-subtitle" v-else>Seleziona una categoria</p>
      </div>
    </header>

    <div class="scelta-body">

      <!-- Planning Allenamenti -->
      <div v-if="!categoria?.is_archived" class="planning-section">
        <div class="section-header">
          <div class="section-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="22" height="22">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
              <line x1="16" y1="2" x2="16" y2="6"/>
              <line x1="8" y1="2" x2="8" y2="6"/>
              <line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
          </div>
          <div>
            <h2 class="section-title">Planning Allenamenti</h2>
            <p class="section-subtitle">Programmazione settimanale</p>
          </div>
        </div>

        <div class="planning-grid">
          <div
            v-for="(giorno, idx) in planningSettimana"
            :key="giorno.val"
            class="planning-day"
            :class="{ active: isToday(giorno.val), empty: !giorno.allenamento }"
            :style="{ animationDelay: idx * 60 + 'ms' }"
          >
            <div class="day-header">
              <span class="day-name">{{ giorno.nome }}</span>
              <div v-if="isToday(giorno.val)" class="today-badge">OGGI</div>
            </div>
            <div class="day-divider"></div>
            <div class="day-content">
              <div v-if="giorno.allenamento" class="day-cats">
                <div
                  class="cat-chip"
                  :class="{ evento: giorno.hasEvento }"
                  @click="giorno.hasEvento ? apriEventoModal(giorno.data, giorno.evento) : null"
                >
                  <span class="chip-dot" :class="{ evento: giorno.hasEvento }"></span>
                  <span class="chip-name">{{ categoria?.nome }}</span>
                  <span class="chip-badge">{{ categoria?.anno || 'POR' }}</span>
                </div>
                <div v-if="giorno.hasEvento" class="evento-badge" :style="{ borderColor: getEventoColor(giorno.evento.tipo) + '55' }" @click="apriEventoModal(giorno.data, giorno.evento)">
                  <span class="evento-dot" :style="{ background: getEventoColor(giorno.evento.tipo) }"></span>
                  <span class="evento-label">{{ giorno.evento.titolo || giorno.evento.tipo }}</span>
                </div>
                <div v-if="giorno.spogliatoi.length" class="assegnazioni-row">
                  <div v-for="sp in giorno.spogliatoi" :key="sp.id" class="asseg-chip spogliatoio">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="10" height="10"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/></svg>
                    <span>{{ sp.etichetta }}</span>
                  </div>
                </div>
                <div v-if="giorno.campi.length" class="assegnazioni-row">
                  <div v-for="ca in giorno.campi" :key="ca.id" class="asseg-chip campo">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="10" height="10"><circle cx="12" cy="12" r="10"/><path d="M12 6v12M8 10l4-4 4 4M8 14l4 4 4-4"/></svg>
                    <span>{{ ca.etichetta }}{{ ca.metacampo ? ' (' + getMetacampoLabel(ca.metacampo) + ')' : '' }}</span>
                  </div>
                </div>
              </div>
              <div v-else class="day-empty">
                <span class="empty-icon">—</span>
                <span class="empty-text">Nessun allenamento</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-if="categoria?.is_archived" class="scelta-grid">
        <div
          v-for="cat in categorieStagione"
          :key="cat.id"
          class="scelta-card archived-cat"
          @click="selezionaCategoria(cat)"
        >
          <div class="card-icon-wrap dati">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
            </svg>
          </div>
          <div class="card-label">{{ cat.nome }}</div>
          <div class="card-desc" v-if="cat.giorni">{{ cat.giorni.split(',').map(g => nomiBreviGiorni(parseInt(g))).join(', ') }}</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>
      </div>
      
      <div v-else class="scelta-grid">
        <div class="scelta-card" @click="router.push('/registro/' + categoria?.id)">
          <div class="card-icon-wrap presenze">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2"/>
              <rect x="9" y="3" width="6" height="4" rx="1"/>
              <path d="M9 12h6M9 16h6"/>
            </svg>
          </div>
          <div class="card-label">Presenze</div>
          <div class="card-desc">Gestisci le presenze degli atleti</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>
        
        <div v-if="!isDirigente && !categoria?.is_portieri" class="scelta-card" @click="router.push('/convocazioni/' + categoria?.id)">
          <div class="card-icon-wrap convocazioni">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M22 17H2a3 3 0 000 6h20a3 3 0 000-6z"/>
              <path d="M6 17V7a2 2 0 012-2h10a2 2 0 012 2v10"/>
              <line x1="12" y1="9" x2="12" y2="13"/>
              <line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
          </div>
          <div class="card-label">Convocazioni</div>
          <div class="card-desc">Crea e gestisci convocazioni</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="!categoria?.is_portieri" class="scelta-card" @click="router.push('/dati/' + categoria?.id)">
          <div class="card-icon-wrap dati">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
              <polyline points="14 2 14 8 20 8"/>
              <line x1="16" y1="13" x2="8" y2="13"/>
              <line x1="16" y1="17" x2="8" y2="17"/>
              <polyline points="10 9 9 9 8 9"/>
            </svg>
          </div>
          <div class="card-label">Dati & Matricole</div>
          <div class="card-desc">Visualizza dati e matricole dei giocatori</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="!isDirigente" class="scelta-card" @click="router.push('/allenamenti/' + categoria?.id)">
          <div class="card-icon-wrap allenamenti">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <circle cx="12" cy="12" r="10"/>
              <path d="M12 6v6l4 2"/>
            </svg>
          </div>
          <div class="card-label">Allenamenti</div>
          <div class="card-desc">Gestisci gli allenamenti della settimana</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="!isDirigente" class="scelta-card" @click="router.push('/reportistica/' + categoria?.id)">
          <div class="card-icon-wrap reportistica">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <line x1="18" y1="20" x2="18" y2="10"/>
              <line x1="12" y1="20" x2="12" y2="4"/>
              <line x1="6" y1="20" x2="6" y2="14"/>
            </svg>
          </div>
          <div class="card-label">Reportistica</div>
          <div class="card-desc">Statistiche e report presenze</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>

        <div v-if="!isDirigente" class="scelta-card" @click="router.push('/valutazioni/' + categoria?.id)">
          <div class="card-icon-wrap valutazioni">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
              <path d="M9 11l3 3L22 4"/>
              <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11"/>
            </svg>
          </div>
          <div class="card-label">Valutazioni</div>
          <div class="card-desc">Schede valutative giocatori</div>
          <div class="card-arrow">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>
      </div>

      <!-- Planning Evento Modal -->
      <div v-if="eventoModal.show" class="modal-overlay" @click.self="eventoModal.show = false">
        <div class="modal evento-modal">
          <div class="modal-header">
            <h3>{{ eventoModal.id ? 'Modifica Evento' : 'Nuovo Evento' }}</h3>
            <button class="modal-close" @click="eventoModal.show = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Data</label>
              <input v-model="eventoModal.data" type="date" />
            </div>
            <div class="form-group">
              <label>Tipo</label>
              <select v-model="eventoModal.tipo">
                <option value="sospensione">Sospensione</option>
                <option value="vacanza">Vacanza</option>
                <option value="evento">Evento</option>
                <option value="festa">Festa</option>
                <option value="gara">Gara</option>
              </select>
            </div>
            <div class="form-group">
              <label>Titolo</label>
              <input v-model="eventoModal.titolo" placeholder="Es. Ferragosto" />
            </div>
            <div class="form-group">
              <label>Note</label>
              <textarea v-model="eventoModal.note" rows="2" placeholder="Note aggiuntive..."></textarea>
            </div>
            <div v-if="eventoModal.id" class="evento-delete-row">
              <button class="btn-danger-small" @click="eliminaEvento">Elimina evento</button>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="eventoModal.show = false">Annulla</button>
            <button class="btn-primary" @click="salvaEvento" :disabled="eventoModal.loading">
              <span v-if="eventoModal.loading" class="spinner-small"></span>
              <template v-else>{{ eventoModal.id ? 'Aggiorna' : 'Crea' }}</template>
            </button>
          </div>
        </div>
      </div>
    </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getCategorie, getCategorieByStagione, getPlanningEventi, creaPlanningEvento, aggiornaPlanningEvento, eliminaPlanningEvento, getSpogliatoi, getAssegnazioniSettimana, getCampi, getCampiAssegnazioniSettimana } from '../api/index.js'
const router = useRouter()
const route = useRoute()
const { categoriaAttiva, setCategoria, utenteAttivo } = useStore()
const categoria = categoriaAttiva
const isDirigente = computed(() => ['dirigente', 'segreteria', 'infermeria'].includes(utenteAttivo.value?.ruolo))
const currentSeason = computed(() => {
  const m = new Date().getMonth()
  const y = new Date().getFullYear()
  return m >= 7 ? `${y}/${y + 1}` : `${y - 1}/${y}`
})
const categorieStagione = ref([])
const loading = ref(false)

// ── Planning Allenamenti (settimanale) ──
const eventi = ref([])
const spogliatoi = ref([])
const campi = ref([])
const assegSpogliatoioSettimanali = ref({})
const assegCampoSettimanali = ref({})
const assegnazioniCaricate = ref(false)

function getSettimanaInizio() {
  const oggi = new Date()
  const dow = oggi.getDay()
  const diff = dow === 0 ? -6 : 1 - dow
  const lunedi = new Date(oggi)
  lunedi.setDate(lunedi.getDate() + diff)
  return lunedi.toISOString().split('T')[0]
}

async function loadSpogliatoiCampi() {
  try {
    const [spRes, caRes] = await Promise.all([
      getSpogliatoi(),
      getCampi()
    ])
    spogliatoi.value = spRes.data || []
    campi.value = caRes.data || []
  } catch (e) {
    console.error('Errore caricamento spogliatoi/campi:', e)
  }
}

async function loadAssegnazioniSettimana() {
  const dataInizio = getSettimanaInizio()
  try {
    const [spRes, caRes] = await Promise.all([
      getAssegnazioniSettimana(dataInizio),
      getCampiAssegnazioniSettimana(dataInizio)
    ])
    const spDict = {}
    ;(spRes.data || []).forEach(a => {
      const dataKey = a.data || dataInizio
      const key = `${a.categoria_id}_${a.spogliatoio_id}_${dataKey}`
      spDict[key] = a
    })
    assegSpogliatoioSettimanali.value = spDict
    const caDict = {}
    ;(caRes.data || []).forEach(a => {
      const dataKey = a.data || dataInizio
      const key = `${a.categoria_id}_${a.campo_id}_${dataKey}`
      caDict[key] = a
    })
    assegCampoSettimanali.value = caDict
    assegnazioniCaricate.value = true
  } catch (e) {
    console.error('Errore caricamento assegnazioni:', e)
  }
}

function getSpogliatoioGiorno(catId, spId, dataStr) {
  const key = `${catId}_${spId}_${dataStr}`
  const keyWeekly = `${catId}_${spId}_${getSettimanaInizio()}`
  return !!(assegSpogliatoioSettimanali.value[key] || assegSpogliatoioSettimanali.value[keyWeekly])
}

function getCampoGiorno(catId, campoId, dataStr) {
  const key = `${catId}_${campoId}_${dataStr}`
  const keyWeekly = `${catId}_${campoId}_${getSettimanaInizio()}`
  return assegCampoSettimanali.value[key] || assegCampoSettimanali.value[keyWeekly] || null
}

function getSpogliatoiAssegnati(catId, dataStr) {
  return spogliatoi.value.filter(sp => getSpogliatoioGiorno(catId, sp.id, dataStr))
}

function getCampiAssegnati(catId, dataStr) {
  const risultati = []
  campi.value.forEach(campo => {
    const asseg = getCampoGiorno(catId, campo.id, dataStr)
    if (asseg) {
      risultati.push({ ...campo, metacampo: asseg.metacampo })
    }
  })
  return risultati
}

function getMetacampoLabel(metacampo) {
  if (metacampo === 'A') return 'Metà A'
  if (metacampo === 'B') return 'Metà B'
  return 'Tutto'
}

const tuttiGiorni = [
  { val: 1, nome: "Lunedì" },
  { val: 2, nome: "Martedì" },
  { val: 3, nome: "Mercoledì" },
  { val: 4, nome: "Giovedì" },
  { val: 5, nome: "Venerdì" },
  { val: 6, nome: "Sabato" },
  { val: 0, nome: "Domenica" }
]

const planningSettimana = computed(() => {
  const cat = categoria.value
  const loaded = assegnazioniCaricate.value
  if (!cat) return tuttiGiorni.map(g => ({ ...g, allenamento: false, hasEvento: false, evento: null, data: null, spogliatoi: [], campi: [] }))
  const giorniAllenamento = cat.giorni ? cat.giorni.split(',').map(Number) : []
  const oggi = new Date()
  const oggiStr = `${oggi.getFullYear()}-${String(oggi.getMonth() + 1).padStart(2, '0')}-${String(oggi.getDate()).padStart(2, '0')}`
  return tuttiGiorni.map(g => {
    const isAllenamento = giorniAllenamento.includes(g.val)
    const dataProssimo = getProssimoGiorno(g.val)
    const dataStr = dataProssimo ? `${dataProssimo.getFullYear()}-${String(dataProssimo.getMonth() + 1).padStart(2, '0')}-${String(dataProssimo.getDate()).padStart(2, '0')}` : oggiStr
    const evento = eventi.value.find(e => e.data === dataStr)
    const spAssegnati = isAllenamento && loaded ? getSpogliatoiAssegnati(cat.id, dataStr) : []
    const caAssegnati = isAllenamento && loaded ? getCampiAssegnati(cat.id, dataStr) : []
    return {
      ...g,
      allenamento: isAllenamento,
      hasEvento: !!evento,
      evento: evento || null,
      data: dataStr,
      spogliatoi: spAssegnati,
      campi: caAssegnati
    }
  })
})

function getProssimoGiorno(targetDow) {
  const oggi = new Date()
  const todayDow = oggi.getDay()
  let diff = targetDow - todayDow
  if (diff < 0) diff += 7
  const risultato = new Date(oggi)
  risultato.setDate(risultato.getDate() + diff)
  return risultato
}

function isToday(giornoVal) {
  return new Date().getDay() === giornoVal
}

function getEventoColor(tipo) {
  const colors = { sospensione: '#ef4444', vacanza: '#f59e0b', evento: '#8b5cf6', festa: '#ec4899', gara: '#06b6d4' }
  return colors[tipo] || '#6b7280'
}

async function loadEventi() {
  if (!categoria.value?.id) return
  try {
    const res = await getPlanningEventi(categoria.value.id)
    eventi.value = res.data || []
  } catch (e) {
    console.error('Errore caricamento eventi:', e)
  }
}

const eventoModal = ref({ show: false, id: null, data: '', tipo: 'sospensione', titolo: '', note: '', loading: false })

function apriEventoModal(dataStr, evento) {
  if (evento) {
    eventoModal.value = { show: true, id: evento.id, data: evento.data, tipo: evento.tipo, titolo: evento.titolo || '', note: evento.note || '', loading: false }
  } else {
    eventoModal.value = { show: true, id: null, data: dataStr || '', tipo: 'sospensione', titolo: '', note: '', loading: false }
  }
}

async function salvaEvento() {
  if (!eventoModal.value.data || !categoria.value?.id) return
  eventoModal.value.loading = true
  try {
    const payload = { categoria_id: categoria.value.id, data: eventoModal.value.data, tipo: eventoModal.value.tipo, titolo: eventoModal.value.titolo || null, note: eventoModal.value.note || null }
    if (eventoModal.value.id) {
      await aggiornaPlanningEvento(eventoModal.value.id, payload)
    } else {
      await creaPlanningEvento(payload)
    }
    eventoModal.value.show = false
    await loadEventi()
  } catch (e) {
    alert(e.response?.data?.detail || 'Errore salvataggio')
  } finally {
    eventoModal.value.loading = false
  }
}

async function eliminaEvento() {
  if (!confirm('Eliminare questo evento?')) return
  try {
    await eliminaPlanningEvento(eventoModal.value.id)
    eventoModal.value.show = false
    await loadEventi()
  } catch (e) {
    alert('Errore eliminazione')
  }
}

watch(categoria, (newCat) => {
  if (newCat?.id) {
    eventi.value = []
    assegnazioniCaricate.value = false
    loadEventi()
  }
  else if (!newCat) {
    assegnazioniCaricate.value = false
  }
})

watch(() => route.params.id, async (newId) => {
  if (newId && !categoria.value) {
    await loadCategoriaFromRoute()
    await loadSpogliatoiCampi()
    await loadAssegnazioniSettimana()
    if (categoria.value?.id) loadEventi()
  }
})

async function loadCategoriaFromRoute() {
  if (categoria.value) return
  const catId = parseInt(route.params.id)
  if (!catId) return
  try {
    const res = await getCategorie()
    const all = res.data || []
    const found = all.find(c => c.id === catId)
    if (found) {
      setCategoria(found)
    }
  } catch (e) {
    console.error('Errore caricamento categoria:', e)
  }
}

onMounted(async () => {
  await loadCategoriaFromRoute()
  await loadSpogliatoiCampi()
  await loadAssegnazioniSettimana()
  if (categoria.value?.id) loadEventi()
  loadCategorieStagione()
})

const nomiBreviGiorni = (val) => tuttiGiorni.find(g => g.val === val)?.nome || ''

async function loadCategorieStagione() {
  if (categoria?.is_archived && categoria?.stagione) {
    loading.value = true
    try {
      const res = await getCategorieByStagione(categoria.stagione)
      categorieStagione.value = res.data
    } catch (e) {
      console.error('Errore nel caricamento categorie:', e)
    } finally {
      loading.value = false
    }
  }
}

function selezionaCategoria(cat) {
  setCategoria(cat)
  router.push('/registro/' + cat.id)
}


</script>

<style scoped>
.scelta-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1100px;
  margin: 0 auto;
  overflow: hidden;
  min-height: 100vh;
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  gap: 1rem;
  color: var(--color-text-muted);
}

.loading-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid rgba(255, 255, 255, 0.1);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
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
  background: radial-gradient(circle, rgba(220, 38, 38, 0.1) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 400px;
  height: 400px;
  bottom: -100px;
  left: -80px;
  background: radial-gradient(circle, rgba(124, 58, 237, 0.08) 0%, transparent 70%);
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
  margin-bottom: 2.5rem;
  animation: fadeSlideIn 0.6s ease-out both;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.25rem;
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

.header-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(220, 38, 38, 0.1);
  border: 1px solid rgba(220, 38, 38, 0.2);
  border-radius: 100px;
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-primary);
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--color-primary);
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}

.header-main {
  position: relative;
}

.category-name {
  font-size: clamp(2rem, 6vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.375rem;
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
.scelta-body {
  position: relative;
  z-index: 1;
  animation: fadeSlideIn 0.6s ease-out 0.15s both;
}

.scelta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.scelta-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1.75rem;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
}

.scelta-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 20px;
  opacity: 0;
  transition: opacity var(--transition-base);
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.08) 0%, transparent 60%);
}

.scelta-card:hover {
  transform: translateY(-4px);
  border-color: rgba(220, 38, 38, 0.3);
  box-shadow: 0 8px 32px rgba(220, 38, 38, 0.12), 0 0 0 1px rgba(220, 38, 38, 0.08);
}

.scelta-card:hover::before {
  opacity: 1;
}

.scelta-card:hover .card-icon-wrap {
  transform: scale(1.08);
}

.scelta-card:hover .card-arrow {
  opacity: 1;
  transform: translate(0, 0);
}

.card-icon-wrap {
  width: 56px;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
  border: 1px solid;
  flex-shrink: 0;
  transition: transform var(--transition-base);
  margin-bottom: 0.5rem;
}

.card-icon-wrap.presenze {
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.2) 0%, rgba(220, 38, 38, 0.08) 100%);
  border-color: rgba(220, 38, 38, 0.3);
  color: #ef4444;
}

.card-icon-wrap.convocazioni {
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.2) 0%, rgba(59, 130, 246, 0.08) 100%);
  border-color: rgba(59, 130, 246, 0.3);
  color: #60a5fa;
}

.card-icon-wrap.dati {
  background: linear-gradient(135deg, rgba(234, 179, 8, 0.2) 0%, rgba(234, 179, 8, 0.08) 100%);
  border-color: rgba(234, 179, 8, 0.3);
  color: #fbbf24;
}

.card-icon-wrap.allenamenti {
  background: linear-gradient(135deg, rgba(34, 197, 94, 0.2) 0%, rgba(34, 197, 94, 0.08) 100%);
  border-color: rgba(34, 197, 94, 0.3);
  color: #4ade80;
}

.card-icon-wrap.reportistica {
  background: linear-gradient(135deg, rgba(168, 85, 247, 0.2) 0%, rgba(168, 85, 247, 0.08) 100%);
  border-color: rgba(168, 85, 247, 0.3);
  color: #a78bfa;
}

.card-icon-wrap.valutazioni {
  background: linear-gradient(135deg, rgba(20, 184, 166, 0.2) 0%, rgba(20, 184, 166, 0.08) 100%);
  border-color: rgba(20, 184, 166, 0.3);
  color: #2dd4bf;
}

.card-icon-wrap svg {
  width: 28px;
  height: 28px;
}

.card-label {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.01em;
}

.card-desc {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
}

.card-arrow {
  position: absolute;
  right: 1.5rem;
  bottom: 1.5rem;
  opacity: 0;
  transform: translate(-8px, 0);
  transition: all var(--transition-base);
  color: var(--color-text-secondary);
}

.card-arrow svg {
  width: 20px;
  height: 20px;
}

/* ── Archived cards ── */
.scelta-card.archived-cat {
  background: rgba(255, 255, 255, 0.02);
}

.scelta-card.archived-cat::before {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.08) 0%, transparent 60%);
}

.scelta-card.archived-cat:hover {
  border-color: rgba(245, 158, 11, 0.3);
  box-shadow: 0 8px 32px rgba(245, 158, 11, 0.12), 0 0 0 1px rgba(245, 158, 11, 0.08);
}

/* ── Animations ── */
@keyframes fadeSlideIn {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* ── Responsive ── */
@media (max-width: 768px) {
  .scelta-page {
    padding: 1.5rem 1rem 3rem;
  }
  .scelta-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 480px) {
  .category-name {
    font-size: 1.75rem;
  }
  .header-top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }
}

/* ── Planning Section (come Home.vue) ── */
.planning-section {
  position: relative;
  z-index: 1;
  margin-bottom: 3rem;
}

.section-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.section-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  border-radius: 14px;
  background: rgba(220, 38, 38, 0.1);
  border: 1px solid rgba(220, 38, 38, 0.2);
  color: var(--color-primary);
}

.section-title {
  font-size: 1.25rem;
  font-weight: 800;
  color: var(--color-text);
  margin: 0;
}

.section-subtitle {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  margin: 0;
}

.planning-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.75rem;
}

.planning-day {
  position: relative;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 1rem 0.875rem;
  min-height: 140px;
  display: flex;
  flex-direction: column;
  transition: all var(--transition-base);
  animation: fadeSlideIn 0.5s ease-out both;
}

.planning-day:hover {
  border-color: rgba(255, 255, 255, 0.15);
  transform: translateY(-2px);
}

.planning-day.active {
  background: rgba(220, 38, 38, 0.06);
  border-color: rgba(220, 38, 38, 0.3);
  box-shadow: 0 0 30px rgba(220, 38, 38, 0.08);
}

.planning-day.empty {
  opacity: 0.45;
}

.day-header {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  position: relative;
}

.day-name {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text);
}

.planning-day.active .day-name {
  color: var(--color-primary);
}

.today-badge {
  position: absolute;
  top: 0;
  right: 0;
  font-family: var(--font-mono);
  font-size: 0.5625rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  padding: 0.15rem 0.5rem;
  background: var(--color-primary);
  color: white;
  border-radius: 4px;
}

.day-divider {
  height: 1px;
  background: linear-gradient(90deg, var(--color-border) 0%, transparent 100%);
  margin: 0.625rem 0;
}

.planning-day.active .day-divider {
  background: linear-gradient(90deg, rgba(220, 38, 38, 0.4) 0%, transparent 100%);
}

.day-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.day-cats {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.cat-chip {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.4rem 0.5rem;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.cat-chip:hover {
  background: rgba(220, 38, 38, 0.12);
  border-color: rgba(220, 38, 38, 0.4);
  transform: translateX(2px);
}

.cat-chip.evento:hover {
  background: rgba(239, 68, 68, 0.12);
  border-color: rgba(239, 68, 68, 0.4);
}

.chip-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: var(--color-primary);
  flex-shrink: 0;
}

.chip-dot.evento {
  background: #ef4444;
}

.chip-name {
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--color-text);
  flex: 1;
  line-height: 1.2;
}

.chip-badge {
  font-family: var(--font-mono);
  font-size: 0.5625rem;
  font-weight: 700;
  padding: 0.1rem 0.375rem;
  background: rgba(255, 255, 255, 0.06);
  color: var(--color-text-secondary);
  border-radius: 4px;
  letter-spacing: 0.05em;
  flex-shrink: 0;
}

.cat-chip:hover .chip-badge {
  background: var(--color-primary);
  color: white;
}

.chip-time {
  font-family: var(--font-mono);
  font-size: 0.5625rem;
  color: var(--color-text-muted);
  flex-shrink: 0;
}

.evento-badge {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.35rem 0.5rem;
  border: 1px solid;
  border-radius: 8px;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.evento-badge:hover {
  transform: translateX(2px);
}

.evento-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  flex-shrink: 0;
}

.evento-label {
  font-size: 0.625rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  text-transform: capitalize;
}

.day-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.375rem;
  margin-top: auto;
  padding-top: 0.5rem;
}

.empty-icon {
  font-size: 1rem;
  color: var(--color-border);
  font-weight: 300;
}

.empty-text {
  font-size: 0.625rem;
  color: var(--color-text-muted);
  text-align: center;
}

.assegnazioni-row {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-top: 0.25rem;
}

.asseg-chip {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.25rem 0.4rem;
  border-radius: 6px;
  font-size: 0.6rem;
  font-weight: 600;
}

.asseg-chip svg {
  flex-shrink: 0;
}

.asseg-chip.spogliatoio {
  background: rgba(168, 85, 247, 0.1);
  border: 1px solid rgba(168, 85, 247, 0.25);
  color: #c084fc;
}

.asseg-chip.campo {
  background: rgba(34, 197, 94, 0.1);
  border: 1px solid rgba(34, 197, 94, 0.25);
  color: #4ade80;
}

@media (max-width: 900px) {
  .planning-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}
@media (max-width: 600px) {
  .planning-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  .planning-day {
    min-height: 100px;
    padding: 0.75rem 0.625rem;
  }
}
@media (max-width: 400px) {
  .planning-grid {
    grid-template-columns: 1fr;
  }
}

/* Evento modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}
.modal {
  background: #1e1e2e;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  padding: 24px;
  width: 90%;
  max-width: 420px;
  max-height: 90vh;
  overflow-y: auto;
}
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.modal-header h3 {
  color: #e5e7eb;
  font-size: 1rem;
  margin: 0;
}
.modal-close {
  background: none;
  border: none;
  color: #9ca3af;
  cursor: pointer;
  padding: 4px;
}
.modal-close:hover {
  color: #e5e7eb;
}
.modal-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.form-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.form-group label {
  font-size: 0.75rem;
  font-weight: 600;
  color: #9ca3af;
}
.form-group input,
.form-group select,
.form-group textarea {
  padding: 8px 10px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  background: rgba(255, 255, 255, 0.05);
  color: #e5e7eb;
  font-size: 0.85rem;
  font-family: inherit;
}
.form-group textarea {
  resize: vertical;
}
.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 16px;
}
.btn-primary {
  padding: 8px 16px;
  border-radius: 8px;
  background: #dc2626;
  border: none;
  color: white;
  font-weight: 600;
  font-size: 0.8rem;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-primary:hover:not(:disabled) {
  background: #ef4444;
}
.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.btn-secondary {
  padding: 8px 16px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: #d1d5db;
  font-size: 0.8rem;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-secondary:hover {
  background: rgba(255, 255, 255, 0.15);
}
.evento-delete-row {
  text-align: right;
  margin-top: 4px;
}
.btn-danger-small {
  padding: 6px 14px;
  border-radius: 6px;
  background: rgba(239, 68, 68, 0.15);
  border: 1px solid rgba(239, 68, 68, 0.3);
  color: #f87171;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-danger-small:hover {
  background: rgba(239, 68, 68, 0.25);
}
.spinner-small {
  display: inline-block;
  width: 14px;
  height: 14px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
