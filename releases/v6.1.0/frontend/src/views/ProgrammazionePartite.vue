<template>
  <div class="partite-page">
    <header class="page-header">
      <div class="header-content">
        <button class="btn-back" @click="router.push('/responsabili')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <div>
          <h1>Weekend di Gare</h1>
          <p class="page-subtitle">Gestione weekend e partite</p>
        </div>
      </div>
    </header>

  <div class="weekend-section">
    <div v-if="weekendSelezionato" class="weekend-detail">
      <div class="weekend-detail-header">
        <button class="btn-back-sm" @click="weekendSelezionato = null" title="Torna alla lista">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <div>
          <h2>{{ weekendSelezionato.nome }}</h2>
          <p class="weekend-dates">{{ formatDate(weekendSelezionato.data_inizio) }} - {{ formatDate(weekendSelezionato.data_fine) }}</p>
        </div>
        <div class="weekend-actions">
          <button class="btn-secondary-sm" @click="apriModalWeekend(weekendSelezionato)" title="Modifica">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
              <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
            Modifica
          </button>
          <button class="btn-secondary-sm" @click="stampaWeekend" title="Stampa">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
              <polyline points="6 9 6 2 18 2 18 9"/>
              <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
              <rect x="6" y="14" width="12" height="8"/>
            </svg>
            Stampa
          </button>
          <button class="btn-secondary-sm" @click="esportaPDFWeekend" title="Esporta PDF">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
              <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
              <polyline points="14 2 14 8 20 8"/>
              <line x1="12" y1="18" x2="12" y2="12"/>
              <polyline points="9 15 12 18 15 15"/>
            </svg>
            PDF
          </button>
          <button class="btn-add-sm" @click="apriModal(null, null, weekendSelezionato.id)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
              <line x1="12" y1="5" x2="12" y2="19"/>
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
            Aggiungi Partita
          </button>
        </div>
      </div>
      <div v-if="weekendPartite.length > 0" class="categorie-grouped">
        <div v-for="group in weekendPartiteGrouped" :key="group.cat.id" class="categoria-section">
          <div class="categoria-section-header">
            <h2 class="categoria-title">{{ group.cat.anno }} - {{ group.cat.nome }}</h2>
          </div>
          <div class="partite-list">
            <div v-for="partita in group.partite" :key="partita.id" class="partita-card" :class="{ played: partita.risultato }">
              <div class="partita-header">
                <div class="partita-actions">
                  <button class="btn-icon-sm" @click="apriModal(partita)" title="Modifica">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                      <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                      <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
                    </svg>
                  </button>
                  <button class="btn-icon-sm btn-delete" @click="eliminaPartita(partita.id)" title="Elimina">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                      <polyline points="3 6 5 6 21 6"/>
                      <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                    </svg>
                  </button>
                </div>
              </div>
              <div class="partita-body">
                <div class="partita-date">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                    <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                    <line x1="16" y1="2" x2="16" y2="6"/>
                    <line x1="8" y1="2" x2="8" y2="6"/>
                    <line x1="3" y1="10" x2="21" y2="10"/>
                  </svg>
                  {{ formatDate(partita.data_partite) }}
                  <span v-if="partita.ora" class="partita-time">Inizio Gara: {{ partita.ora.slice(0, 5) }}</span>
                </div>
                <div class="partita-match">
                  <template v-if="partita.casa_fuori === 'fuori'">
                    <span class="team-name">{{ partita.avversario || 'TBD' }}</span>
                    <span class="score" v-if="partita.risultato">{{ partita.goal_contro }} - {{ partita.goal_punti }}</span>
                    <span class="score" v-else>vs</span>
                    <span class="team-name">{{ societaNome }}</span>
                  </template>
                  <template v-else>
                    <span class="team-name">{{ societaNome }}</span>
                    <span class="score" v-if="partita.risultato">{{ partita.goal_punti }} - {{ partita.goal_contro }}</span>
                    <span class="score" v-else>vs</span>
                    <span class="team-name">{{ partita.avversario || 'TBD' }}</span>
                  </template>
                  <span class="casa-fuori-badge" :class="partita.casa_fuori || 'casa'">{{ partita.casa_fuori === 'fuori' ? 'In trasferta' : 'In casa' }}</span>
                </div>
                <div class="partita-meta">
                  <span v-if="partita.casa_fuori" class="meta-item giorno-badge">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                      <line x1="16" y1="2" x2="16" y2="6"/>
                      <line x1="8" y1="2" x2="8" y2="6"/>
                      <line x1="3" y1="10" x2="21" y2="10"/>
                    </svg>
                    {{ getGiornoSettimana(partita.data_partite) }}
                  </span>
                  <span v-if="partita.campo" class="meta-item">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/>
                      <circle cx="12" cy="10" r="3"/>
                    </svg>
                    {{ partita.campo }}{{ partita.indirizzo ? ' - ' + partita.indirizzo : '' }}
                  </span>
                  <span v-if="partita.mister_id" class="meta-item mister-badge">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                      <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/>
                      <circle cx="12" cy="7" r="4"/>
                    </svg>
                    {{ getMisterName(partita.categoria_id, partita.mister_id) }}
                  </span>
                  <span v-if="partita.risultato" class="meta-item risultato" :class="getRisultatoClass(partita.goal_punti, partita.goal_contro)">
                    {{ partita.risultato }}
                  </span>
                </div>
                <div v-if="partita.note" class="partita-note">{{ partita.note }}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div v-else class="empty-state">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="48" height="48">
          <circle cx="12" cy="12" r="10"/>
          <path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/>
          <path d="M2 12h20"/>
        </svg>
        <p>Nessuna partita per questo weekend</p>
        <button class="btn-add-small" @click="apriModal(null, null, weekendSelezionato.id)">Aggiungi prima partita</button>
      </div>
    </div>

    <div v-else class="weekend-list">
      <div class="weekend-list-header">
        <h2>Weekend</h2>
        <button class="btn-add-sm" @click="apriModalWeekend(null)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <line x1="12" y1="5" x2="12" y2="19"/>
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
          Nuovo Weekend
        </button>
      </div>
      <div v-if="weekend.length > 0" class="weekend-cards">
        <div v-for="w in weekend" :key="w.id" class="weekend-card" @click="weekendSelezionato = w">
          <div class="weekend-card-main">
            <h3>{{ w.nome }}</h3>
            <p>{{ formatDate(w.data_inizio) }} - {{ formatDate(w.data_fine) }}</p>
          </div>

          <button class="btn-icon-sm btn-delete" @click.stop="eliminaWeekendFn(w.id)" title="Elimina">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
              <polyline points="3 6 5 6 21 6"/>
              <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
            </svg>
          </button>
        </div>
      </div>
      <div v-else class="empty-state">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="48" height="48">
          <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
          <line x1="16" y1="2" x2="16" y2="6"/>
          <line x1="8" y1="2" x2="8" y2="6"/>
          <line x1="3" y1="10" x2="21" y2="10"/>
        </svg>
        <p>Nessun weekend creato</p>
        <button class="btn-add-small" @click="apriModalWeekend(null)">Crea primo weekend</button>
      </div>
    </div>
  </div>

  <Teleport to="body">
      <div v-if="weekendModal.show" class="modal-overlay" @click.self="chiudiModalWeekend">
        <div class="modal">
          <div class="modal-header">
            <h3>{{ weekendModal.id ? 'Modifica Weekend' : 'Nuovo Weekend' }}</h3>
            <button class="modal-close" @click="chiudiModalWeekend">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Nome</label>
              <input type="text" v-model="weekendModal.nome" placeholder="Es. Giornata 1, Finale ecc." />
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Data Inizio</label>
                <input type="date" v-model="weekendModal.data_inizio" />
              </div>
              <div class="form-group">
                <label>Data Fine</label>
                <input type="date" v-model="weekendModal.data_fine" />
              </div>
            </div>
            <div class="modal-actions">
              <button class="btn-cancel" @click="chiudiModalWeekend">Annulla</button>
              <button class="btn-save" @click="salvaWeekend">{{ weekendModal.id ? 'Salva' : 'Crea' }}</button>
            </div>
          </div>
        </div>
      </div>

      <div v-if="modal.show" class="modal-overlay" @click.self="chiudiModal">
        <div class="modal">
          <div class="modal-header">
            <h3>{{ modal.id ? 'Modifica Partita' : 'Nuova Partita' }}</h3>
            <button class="modal-close" @click="chiudiModal">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <div class="form-row">
              <div class="form-group">
                <label>Categoria</label>
                <select v-model="modal.categoria_id">
                  <option v-for="cat in categorie" :key="cat.id" :value="cat.id">{{ cat.anno }} - {{ cat.nome }}</option>
                </select>
              </div>
              <div class="form-group">
                <label>Data</label>
                <input type="date" v-model="modal.data_partite" />
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Inizio Gara</label>
                <input type="time" v-model="modal.ora" />
              </div>
              <div class="form-group">
                <label>In Casa / Fuori</label>
                <select v-model="modal.casa_fuori">
                  <option value="casa">In Casa</option>
                  <option value="fuori">In Trasferta</option>
                </select>
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Avversario</label>
                <input type="text" v-model="modal.avversario" placeholder="Nome squadra" />
              </div>
              <div class="form-group">
                <label>Mister</label>
                <select v-model="modal.mister_id">
                  <option :value="null">— Seleziona —</option>
                  <option v-for="m in getMisterPerCategoria(modal.categoria_id)" :key="m.id" :value="m.id">
                    {{ m.cognome }} - {{ m.cellulare }}
                  </option>
                </select>
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Campo Sportivo</label>
                <input type="text" v-model="modal.campo" placeholder="Nome campo" />
              </div>
              <div class="form-group">
                <label>Indirizzo Campo</label>
                <input type="text" v-model="modal.indirizzo" placeholder="Indirizzo completo" />
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Weekend</label>
                <select v-model="modal.weekend_id">
                  <option :value="null">— Nessuno —</option>
                  <option v-for="w in weekend" :key="w.id" :value="w.id">{{ w.nome }} ({{ formatDate(w.data_inizio) }} - {{ formatDate(w.data_fine) }})</option>
                </select>
              </div>
            </div>

            <div class="form-group">
              <label>Note</label>
              <textarea v-model="modal.note" rows="2" placeholder="Note aggiuntive..."></textarea>
            </div>
            <div class="modal-actions">
              <button class="btn-cancel" @click="chiudiModal">Annulla</button>
              <button class="btn-save" @click="salvaPartita">{{ modal.id ? 'Salva' : 'Crea' }}</button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useRouter } from "vue-router"
import { getAllCategorie, getCategoriaResponsabili, creaPartita, aggiornaPartita, eliminaPartita as eliminaPartitaApi, getWeekend, getWeekendPartite, creaWeekend, aggiornaWeekend, eliminaWeekend as eliminaWeekendApi } from "../api/index.js"
import { useStore } from "../store.js"
import { jsPDF } from "jspdf"
import "jspdf-autotable"
const router = useRouter()
const { societaAttiva } = useStore()

const societaNome = computed(() => societaAttiva.value?.nome_breve || societaAttiva.value?.nome || 'Società')

const categorie = ref([])
const misterPerCategoria = ref({})
const weekend = ref([])
const weekendSelezionato = ref(null)
const weekendPartite = ref([])

const modal = ref({
  show: false,
  id: null,
  categoria_id: null,
  data_partite: "",
  ora: "",
  avversario: "",
  campo: "",
  indirizzo: "",
  casa_fuori: "casa",
  mister_id: null,
  risultato: "",
  goal_punti: 0,
  goal_contro: 0,
  note: "",
  weekend_id: null
})

const weekendModal = ref({
  show: false,
  id: null,
  nome: "",
  data_inizio: "",
  data_fine: ""
})

const weekendPartiteGrouped = computed(() => {
  const catMap = {}
  weekendPartite.value.forEach(p => {
    if (!catMap[p.categoria_id]) catMap[p.categoria_id] = []
    catMap[p.categoria_id].push(p)
  })
  const sortedCats = categorie.value
    .filter(c => catMap[c.id])
    .sort((a, b) => (a.anno || 9999) - (b.anno || 9999))
  return sortedCats.map(cat => ({
    cat,
    partite: catMap[cat.id].sort((a, b) => a.data_partite.localeCompare(b.data_partite))
  }))
})

function getCatName(catId) {
  const cat = categorie.value.find(c => c.id === catId)
  return cat ? `${cat.anno} - ${cat.nome}` : 'Sconosciuta'
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  const [y, m, d] = dateStr.split('-')
  return `${d}/${m}/${y}`
}

function getRisultatoClass(punti, contro) {
  if (punti > contro) return 'win'
  if (punti < contro) return 'loss'
  return 'draw'
}

function getGiornoSettimana(dataStr) {
  if (!dataStr) return ''
  const giorni = ['Domenica', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato']
  const d = new Date(dataStr)
  return giorni[d.getDay()]
}

function getMisterName(catId, misterId) {
  const lista = misterPerCategoria.value[catId] || []
  const m = lista.find(r => r.id === misterId)
  return m ? m.cognome : 'N/D'
}

function getMisterPerCategoria(catId) {
  return misterPerCategoria.value[catId] || []
}

function apriModal(partita, defaultCatId, defaultWeekendId) {
  if (partita) {
    modal.value = {
      show: true,
      id: partita.id,
      categoria_id: partita.categoria_id,
      data_partite: partita.data_partite,
      ora: partita.ora,
      avversario: partita.avversario || "",
      campo: partita.campo || "",
      indirizzo: partita.indirizzo || "",
      casa_fuori: partita.casa_fuori || "casa",
      mister_id: partita.mister_id || null,
      risultato: partita.risultato || "",
      goal_punti: partita.goal_punti || 0,
      goal_contro: partita.goal_contro || 0,
      note: partita.note || "",
      weekend_id: partita.weekend_id || null
    }
  } else {
    modal.value = {
      show: true,
      id: null,
      categoria_id: defaultCatId || categorie.value[0]?.id || null,
      data_partite: "",
      ora: "",
      avversario: "",
      campo: "",
      indirizzo: "",
      casa_fuori: "casa",
      mister_id: null,
      risultato: "",
      goal_punti: 0,
      goal_contro: 0,
      note: "",
      weekend_id: defaultWeekendId || null
    }
  }
}

function chiudiModal() {
  modal.value.show = false
}

async function salvaPartita() {
  const payload = {
    ...modal.value,
    societa_id: societaAttiva.value?.id || null
  }
  if (modal.value.id) {
    await aggiornaPartita(modal.value.id, payload)
  } else {
    await creaPartita(payload)
  }
  chiudiModal()
  if (weekendSelezionato.value) {
    await caricaWeekendPartite(weekendSelezionato.value.id)
  }
}

async function eliminaPartita(id) {
  if (!confirm('Eliminare questa partita?')) return
  await eliminaPartitaApi(id)
  if (weekendSelezionato.value) {
    await caricaWeekendPartite(weekendSelezionato.value.id)
  }
}

async function loadCategorie() {
  const societaId = societaAttiva.value?.id || null
  try {
    categorie.value = (await getAllCategorie(societaId)).data || []
  } catch (e) {
    console.error('Errore caricamento categorie:', e)
    categorie.value = []
  }
  const misterPromises = categorie.value.map(async (cat) => {
    try {
      const res = await getCategoriaResponsabili(cat.id)
      misterPerCategoria.value[cat.id] = res.data.filter(r => r.ruolo !== 'dirigente')
    } catch {
      misterPerCategoria.value[cat.id] = []
    }
  })
  await Promise.all(misterPromises)
}

async function loadWeekend() {
  const societaId = societaAttiva.value?.id || null
  try {
    const res = await getWeekend(societaId)
    weekend.value = res.data || []
  } catch (e) {
    console.error('Errore caricamento weekend:', e)
    weekend.value = []
  }
}

async function caricaWeekendPartite(weekendId) {
  try {
    const res = await getWeekendPartite(weekendId)
    weekendPartite.value = res.data || []
  } catch (e) {
    console.error('Errore caricamento partite weekend:', e)
    weekendPartite.value = []
  }
}

function apriModalWeekend(weekend) {
  if (weekend) {
    weekendModal.value = {
      show: true,
      id: weekend.id,
      nome: weekend.nome,
      data_inizio: weekend.data_inizio,
      data_fine: weekend.data_fine
    }
  } else {
    weekendModal.value = {
      show: true,
      id: null,
      nome: "",
      data_inizio: "",
      data_fine: ""
    }
  }
}

function chiudiModalWeekend() {
  weekendModal.value.show = false
}

async function salvaWeekend() {
  const payload = {
    ...weekendModal.value,
    societa_id: societaAttiva.value?.id || null
  }
  if (weekendModal.value.id) {
    await aggiornaWeekend(weekendModal.value.id, payload)
  } else {
    await creaWeekend(payload)
  }
  chiudiModalWeekend()
  await loadWeekend()
  if (weekendSelezionato.value && weekendModal.value.id === weekendSelezionato.value.id) {
    const w = weekend.value.find(x => x.id === weekendModal.value.id)
    if (w) weekendSelezionato.value = w
  }
}

async function eliminaWeekendFn(id) {
  if (!confirm('Eliminare questo weekend?')) return
  await eliminaWeekendApi(id)
  if (weekendSelezionato.value && weekendSelezionato.value.id === id) {
    weekendSelezionato.value = null
  }
  await loadWeekend()
}

function esc(s) {
  if (s == null) return ''
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
}

async function stampaWeekend() {
  if (!weekendSelezionato.value) return
  const win = window.open('', '_blank', 'noopener,noreferrer')
  const sorted = weekendPartiteGrouped.value.map(g => ({
    cat: g.cat,
    partite: g.partite.sort((a, b) => a.data_partite.localeCompare(b.data_partite))
  }))
  const rows = []
  sorted.forEach(g => {
    const catLabel = `${esc(g.cat.anno)} - ${esc(g.cat.nome)}`
    rows.push(`<tr class="cat-divider"><td colspan="7">${catLabel}</td></tr>`)
    g.partite.forEach(p => {
      const data = esc(formatDate(p.data_partite))
      const ora = esc(p.ora ? p.ora.slice(0, 5) : '-')
      const cf = p.casa_fuori === 'fuori' ? 'Trasferta' : 'Casa'
      const campo = esc(p.campo || '-')
      const indirizzo = esc(p.indirizzo || '-')
      const mister = esc(p.mister_id ? getMisterName(p.categoria_id, p.mister_id) : '-')
      const aversario = esc(p.avversario || '-')
      rows.push(`<tr>
        <td>${data}</td><td>${ora}</td><td>${cf}</td><td>${aversario}</td><td>${campo}</td><td>${indirizzo}</td><td>${mister}</td>
      </tr>`)
    })
  })
  win.document.write(`<!DOCTYPE html><html><head><title>${esc(weekendSelezionato.value.nome)} - ${esc(societaNome.value)}</title>
    <style>
      body{font-family:Arial,sans-serif;margin:20px;font-size:12px;color:#1a1a1a}
      h1{margin:0 0 5px;font-size:20px}p.sub{color:#666;margin:0 0 15px}
      table{width:100%;border-collapse:collapse}
      th,td{border:1px solid #ddd;padding:6px 8px;text-align:left}
      th{background:#f3f4f6;font-weight:700}
      tr:nth-child(even) td{background:#fafafa}
      .cat-divider{background:#1e1e1e !important;color:#fff;font-weight:700;font-size:13px;padding:8px 10px !important}
    </style></head><body>
    <h1>${esc(weekendSelezionato.value.nome)} - ${esc(societaNome.value)}</h1><p class="sub">${esc(formatDate(weekendSelezionato.value.data_inizio))} - ${esc(formatDate(weekendSelezionato.value.data_fine))} | Stampato il ${new Date().toLocaleDateString('it-IT')}</p>
    <table><thead><tr><th>Data</th><th>Ora</th><th>Casa/Trasferta</th><th>Avversario</th><th>Campo</th><th>Indirizzo</th><th>Mister</th></tr></thead>
    <tbody>${rows.join('')}</tbody></table>
    <script>window.print()<\/script></body></html>`)
  win.document.close()
}

async function esportaPDFWeekend() {
  if (!weekendSelezionato.value) return
  const doc = new jsPDF({ orientation: 'landscape' })
  const nome = societaNome.value
  doc.setFontSize(16)
  doc.text(`${weekendSelezionato.value.nome} - ${nome}`, 14, 15)
  doc.setFontSize(9)
  doc.setTextColor(100)
  doc.text(`${formatDate(weekendSelezionato.value.data_inizio)} - ${formatDate(weekendSelezionato.value.data_fine)} | Generato il ${new Date().toLocaleDateString('it-IT')}`, 14, 22)
  doc.setTextColor(0)
  const sorted = weekendPartiteGrouped.value.map(g => ({
    cat: g.cat,
    partite: g.partite.sort((a, b) => a.data_partite.localeCompare(b.data_partite))
  }))
  const headers = [['Data', 'Ora', 'C/T', 'Avversario', 'Campo', 'Indirizzo', 'Mister']]
  const body = []
  sorted.forEach(g => {
    const catLabel = `${g.cat.anno} - ${g.cat.nome}`
    body.push([{ content: catLabel, colSpan: 7 }])
    g.partite.forEach(p => {
      const data = formatDate(p.data_partite)
      const ora = p.ora ? p.ora.slice(0, 5) : '-'
      const cf = p.casa_fuori === 'fuori' ? 'Trasferta' : 'Casa'
      const campo = p.campo || '-'
      const indirizzo = p.indirizzo || '-'
      const mister = p.mister_id ? getMisterName(p.categoria_id, p.mister_id) : '-'
      const aversario = p.avversario || '-'
      body.push([data, ora, cf, aversario, campo, indirizzo, mister])
    })
  })
  doc.autoTable({
    head: headers,
    body: body,
    startY: 28,
    theme: 'grid',
    margin: { left: 14, right: 14 },
    tableWidth: 260,
    styles: { fontSize: 8.5, cellPadding: 3, halign: 'left', valign: 'middle' },
    headStyles: { fillColor: [220, 38, 38], textColor: 255, fontStyle: 'bold', halign: 'center', fontSize: 9 },
    columnStyles: {
      0: { cellWidth: 25, halign: 'center' },
      1: { cellWidth: 16, halign: 'center' },
      2: { cellWidth: 20, halign: 'center' },
      3: { cellWidth: 'wrap' },
      4: { cellWidth: 'wrap' },
      5: { cellWidth: 'wrap' },
      6: { cellWidth: 'wrap' }
    },
    didParseCell: function(d) {
      if (d.section === 'body' && d.raw && d.raw.colSpan) {
        d.cell.colSpan = d.raw.colSpan
        d.cell.raw = d.raw.content
        d.cell.styles.fillColor = [220, 38, 38]
        d.cell.styles.textColor = [255, 255, 255]
        d.cell.styles.fontStyle = 'bold'
        d.cell.styles.fontSize = 11
        d.cell.styles.halign = 'left'
        d.cell.styles.cellPadding = { top: 5, bottom: 5, left: 6, right: 6 }
      }
    }
  })
  doc.save(`${weekendSelezionato.value.nome.replace(/\s+/g, '_').toLowerCase()}_${nome.replace(/\s+/g, '_').toLowerCase()}.pdf`)
}

onMounted(() => {
  loadCategorie()
  loadWeekend()
})

watch(weekendSelezionato, (newVal) => {
  if (newVal) {
    caricaWeekendPartite(newVal.id)
  }
})


</script>

<style scoped>
.partite-page {
  padding: 2rem;
  max-width: 1000px;
  margin: 0 auto;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1.5rem;
  animation: slideUp 0.4s ease-out;
}

.header-content {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
}

.btn-back {
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
  flex-shrink: 0;
}

.btn-back:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-back svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
}

.header-content h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.02em;
  margin-bottom: 0.25rem;
}

.page-subtitle {
  color: var(--color-text-muted);
  font-size: 1rem;
}

.btn-add {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.625rem 1rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-add:hover {
  opacity: 0.9;
  transform: translateY(-1px);
}

.btn-add svg {
  width: 18px;
  height: 18px;
}

.header-actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.btn-secondary {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.625rem 0.875rem;
  background: var(--color-surface-elevated, #1e1e1e);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-secondary:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
}

.filters-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
  padding: 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
}

.filter-select {
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  color: var(--color-text);
  font-size: 0.875rem;
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 0.375rem;
}

.filter-group label {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-muted);
}

.filter-group input {
  padding: 0.5rem 0.625rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  color: var(--color-text);
  font-size: 0.875rem;
}

.btn-filter {
  padding: 0.5rem 0.75rem;
  background: rgba(220, 38, 38, 0.1);
  border: 1px solid var(--color-primary);
  border-radius: var(--radius-sm);
  color: var(--color-primary);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-filter:hover {
  background: var(--color-primary);
  color: white;
}

.partite-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.categorie-grouped {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.categoria-section {
  animation: slideUp 0.3s ease-out both;
}

.categoria-section-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1rem;
  padding-bottom: 0.75rem;
  border-bottom: 2px solid var(--color-primary);
}

.categoria-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
  margin: 0;
  letter-spacing: -0.01em;
}

.btn-add-cat {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(220, 38, 38, 0.1);
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all var(--transition-fast);
  color: var(--color-primary);
  flex-shrink: 0;
}

.btn-add-cat:hover {
  background: var(--color-primary);
  color: white;
}

.partita-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 1rem 1.25rem;
  animation: slideUp 0.3s ease-out both;
  transition: all var(--transition-fast);
}

.partita-card:hover {
  border-color: var(--color-primary);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
}

.partita-card.played {
  border-left: 3px solid #10b981;
}

.partita-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
}

.partita-cat {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-primary);
  background: rgba(220, 38, 38, 0.1);
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
}

.partita-actions {
  display: flex;
  gap: 0.375rem;
}

.btn-icon-sm {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all var(--transition-fast);
  color: var(--color-text-muted);
}

.btn-icon-sm:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

.btn-icon-sm.btn-delete:hover {
  background: #dc2626;
  border-color: #dc2626;
}

.partita-body {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.partita-date {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.partita-date svg {
  color: var(--color-primary);
}

.partita-time {
  font-weight: 600;
  color: var(--color-text);
}

.partita-match {
  display: flex;
  align-items: center;
  gap: 1rem;
  font-size: 1rem;
  font-weight: 600;
}

.team-name {
  color: var(--color-text);
  flex: 1;
}

.team-name:last-of-type {
  text-align: right;
}

.score {
  font-weight: 800;
  color: var(--color-primary);
  font-size: 1.125rem;
  min-width: 60px;
  text-align: center;
}

.partita-meta {
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  font-size: 0.8125rem;
  color: var(--color-text-muted);
}

.meta-item.risultato {
  font-weight: 700;
  padding: 0.125rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
}

.meta-item.risultato.win {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
}

.meta-item.risultato.loss {
  background: rgba(220, 38, 38, 0.15);
  color: #dc2626;
}

.meta-item.risultato.draw {
  background: rgba(245, 158, 11, 0.15);
  color: #f59e0b;
}

.casa-fuori-badge {
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.125rem 0.5rem;
  border-radius: 4px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.casa-fuori-badge.casa {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
}

.casa-fuori-badge.fuori {
  background: rgba(245, 158, 11, 0.15);
  color: #f59e0b;
}

.giorno-badge {
  background: rgba(59, 130, 246, 0.1);
  color: #3b82f6;
  font-weight: 600;
  padding: 0.125rem 0.5rem;
  border-radius: 4px;
}

.mister-badge {
  background: rgba(139, 92, 246, 0.1);
  color: #8b5cf6;
  font-weight: 600;
  padding: 0.125rem 0.5rem;
  border-radius: 4px;
}

.partita-note {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  font-style: italic;
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border-radius: var(--radius-sm);
  margin-top: 0.25rem;
}

.empty-state {
  text-align: center;
  padding: 4rem 2rem;
  color: var(--color-text-muted);
}

.empty-state svg {
  margin-bottom: 1rem;
  opacity: 0.3;
}

.empty-state p {
  margin-bottom: 1rem;
  font-size: 1rem;
}

.btn-add-small {
  padding: 0.5rem 1rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
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
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--color-border);
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
  padding: 1.25rem 1.5rem 1.5rem;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.form-group {
  margin-bottom: 0;
}

.form-group label {
  display: block;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-muted);
  margin-bottom: 0.375rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.form-group input,
.form-group select,
.form-group textarea {
  width: 100%;
  padding: 0.625rem 0.75rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  color: var(--color-text);
  font-size: 0.875rem;
  transition: border-color var(--transition-fast);
}

.form-group input:focus,
.form-group select:focus,
.form-group textarea:focus {
  outline: none;
  border-color: var(--color-primary);
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  margin-top: 1.25rem;
  padding-top: 1rem;
  border-top: 1px solid var(--color-border);
}

.btn-cancel {
  padding: 0.625rem 1rem;
  background: transparent;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-cancel:hover {
  background: var(--color-bg);
}

.btn-save {
  padding: 0.625rem 1.5rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-save:hover {
  opacity: 0.9;
}

@media (max-width: 640px) {
  .partite-page {
    padding: 1.25rem;
  }
  .page-header {
    flex-direction: column;
    gap: 1rem;
  }
  .filters-bar {
    flex-direction: column;
    align-items: stretch;
  }
  .form-row {
    grid-template-columns: 1fr;
  }
  .partita-match {
    flex-direction: column;
    gap: 0.25rem;
    text-align: center;
  }
  .team-name:last-of-type {
    text-align: center;
  }
  .categoria-title {
    font-size: 1rem;
  }
}

/* Tabs */
.tabs-bar {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}

.tab-btn {
  padding: 0.5rem 1.25rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-muted);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.tab-btn:hover {
  color: var(--color-text);
  border-color: var(--color-text-muted);
}

.tab-btn.active {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

/* Weekend section */
.weekend-section {
  animation: slideUp 0.3s ease-out;
}

.weekend-list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.25rem;
}

.weekend-list-header h2 {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
  margin: 0;
}

.weekend-cards {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.weekend-card {
  display: flex;
  align-items: center;
  padding: 1rem 1.25rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  cursor: pointer;
  transition: all var(--transition-fast);
  position: relative;
}

.weekend-card:hover {
  border-color: var(--color-primary);
  transform: translateY(-1px);
}

.weekend-card-main {
  flex: 1;
}

.weekend-card-main h3 {
  margin: 0 0 0.25rem;
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-text);
}

.weekend-card-main p {
  margin: 0;
  font-size: 0.8125rem;
  color: var(--color-text-muted);
}

.weekend-card-count {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  margin-right: 1rem;
}

.count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 6px;
  background: var(--color-primary);
  color: white;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 700;
  margin-right: 4px;
}

/* Weekend detail */
.weekend-detail-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
}

.weekend-detail-header h2 {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
  margin: 0;
}

.weekend-dates {
  font-size: 0.875rem;
  color: var(--color-text-muted);
  margin: 0;
}

.weekend-actions {
  display: flex;
  gap: 0.5rem;
  margin-left: auto;
  flex-wrap: wrap;
}

.btn-back-sm {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.btn-back-sm:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-back-sm svg {
  color: var(--color-text);
}

.btn-secondary-sm {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.4rem 0.75rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  color: var(--color-text);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-secondary-sm:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
}

.btn-add-sm {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.4rem 0.75rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-sm);
  color: white;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-add-sm:hover {
  opacity: 0.9;
}

.btn-add-sm svg {
  width: 14px;
  height: 14px;
}

@media (max-width: 640px) {
  .weekend-detail-header {
    flex-direction: column;
    align-items: flex-start;
  }
  .weekend-actions {
    margin-left: 0;
    width: 100%;
  }
  .weekend-card {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }
  .weekend-card-count {
    margin-right: 0;
  }
}
</style>
