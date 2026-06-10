<template>
  <div class="conv-page">
    <header class="page-header">
      <div class="header-left">
        <button class="icon-btn" @click="mobileMenuOpen = true; window.scrollTo(0, 0)" aria-label="Menu">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/></svg>
        </button>
        <button class="icon-btn" @click="router.push('/scelta/' + route.params.id)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>
        </button>
        <button class="icon-btn" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
        </button>
      </div>
      <div class="header-center">
        <span class="header-label">CONVOCAZIONI</span>
        <span class="header-category">{{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
      </div>
      <div class="header-right">
        <button v-if="convocazione" class="btn btn-accent" @click="nuovaConvocazione()">+ Nuova</button>
        <button v-else class="btn btn-accent" @click="nuovaConvocazione()">+ Nuova</button>
      </div>
    </header>

    <!-- MOBILE MENU -->
    <div v-if="mobileMenuOpen" class="mobile-overlay" @click="mobileMenuOpen = false">
      <div class="mobile-drawer" @click.stop>
        <div class="mobile-drawer-header">
          <span class="mobile-drawer-title">Menu</span>
          <button class="icon-btn" @click="mobileMenuOpen = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="mobile-drawer-body">
          <div class="drawer-section">
            <div class="drawer-section-title">Storico</div>
            <div v-for="c in storico" :key="c.id" :class="['drawer-link', { active: convocazioneId === c.id }]" @click="caricaConvocazione(c.id); mobileMenuOpen = false">
              {{ formatDataShort(c.data_inizio) }}{{ c.data_fine ? ' — ' + formatDataShort(c.data_fine) : '' }}
            </div>
            <div v-if="storico.length === 0" class="drawer-empty">Nessun storico</div>
          </div>
          <div class="drawer-section">
            <div class="drawer-section-title">Mister</div>
            <div v-for="r in responsabili" :key="r.id" class="drawer-mister">
              <span class="mister-name">{{ r.cognome }}</span>
              <span class="mister-tel">{{ r.cellulare }}</span>
            </div>
            <div v-if="responsabili.length === 0" class="drawer-empty">Nessun mister</div>
          </div>
          <div class="drawer-section">
            <div class="drawer-section-title">Weekend Gare</div>
            <div v-for="w in weekendDisponibili" :key="w.id" class="drawer-link drawer-weekend-link" @click="creaConvocazioneDaWeekend(w); mobileMenuOpen = false">
              <span>{{ w.nome || 'Weekend' }}</span>
              <span class="drawer-weekend-meta">{{ formatDataShort(w.data_inizio) }} · {{ w.partite.length }} gara{{ w.partite.length > 1 ? 'e' : '' }}</span>
            </div>
            <div v-if="weekendDisponibili.length === 0" class="drawer-empty">Nessun weekend</div>
          </div>
        </div>
      </div>
    </div>

    <div class="conv-body">
      <!-- SIDEBAR -->
      <aside class="sidebar">
        <div class="sidebar-section">
          <div class="sidebar-title">Storico</div>
          <div v-for="c in storico" :key="c.id" :class="['sidebar-link', { active: convocazioneId === c.id }]" @click="caricaConvocazione(c.id)">
            {{ formatDataShort(c.data_inizio) }}{{ c.data_fine ? ' — ' + formatDataShort(c.data_fine) : '' }}
          </div>
          <div v-if="storico.length === 0" class="sidebar-empty">Nessun storico</div>
        </div>
        <div class="sidebar-section">
          <div class="sidebar-title">Mister</div>
          <div v-for="r in responsabili" :key="r.id" class="mister-card">
            <div class="mister-avatar">{{ r.cognome.charAt(0) }}</div>
            <div class="mister-info">
              <span class="mister-name">{{ r.cognome }}</span>
              <span class="mister-tel">{{ r.cellulare }}</span>
            </div>
          </div>
          <div v-if="responsabili.length === 0" class="sidebar-empty">Nessun mister</div>
        </div>
        <div class="sidebar-section">
          <div class="sidebar-title">Weekend Gare</div>
          <div v-for="w in weekendDisponibili" :key="w.id" class="weekend-card" @click="creaConvocazioneDaWeekend(w)">
            <div class="weekend-card-top">
              <span class="weekend-name">{{ w.nome || 'Weekend' }}</span>
              <span class="weekend-badge">{{ w.partite.length }}</span>
            </div>
            <div class="weekend-dates">{{ formatDataShort(w.data_inizio) }}{{ w.data_fine ? ' — ' + formatDataShort(w.data_fine) : '' }}</div>
          </div>
          <div v-if="weekendDisponibili.length === 0" class="sidebar-empty">Nessun weekend</div>
        </div>
      </aside>

      <!-- EDITOR -->
      <main class="editor" v-if="convocazione">
        <!-- Editor Top Bar -->
        <div class="editor-topbar">
          <div class="date-pickers">
            <div class="date-field">
              <label>Inizio</label>
              <input type="date" v-model="convocazione.data_inizio" />
            </div>
            <div class="date-field">
              <label>Fine</label>
              <input type="date" v-model="convocazione.data_fine" />
            </div>
            <div class="date-field">
              <label>Gare</label>
              <input type="number" min="1" max="7" v-model.number="numPartite" @change="aggiustaGare" class="num-input" />
            </div>
          </div>
          <div class="editor-actions">
            <button class="btn btn-ghost" @click="caricaPartiteEsistenti">⚽ Carica Partite</button>
            <button class="btn btn-primary" @click="salva">💾 Salva</button>
            <button class="btn btn-danger" @click="elimina">🗑</button>
            <button class="btn btn-ghost" @click="esportaPDF">📄 PDF</button>
          </div>
        </div>

        <!-- NON CONVOCABILI -->
        <div class="alert-box" v-if="convocazione">
          <span class="alert-icon">⚠️</span>
          <span class="alert-label">NON CONVOCABILI</span>
          <span class="alert-period" v-if="convocazione.data_inizio">(Lun-Ven {{ getSettimanaLabel(convocazione.data_inizio) }})</span>
          <span v-for="p in getAllEsclusi()" :key="p.id" class="alert-tag">{{ p.cognome }} {{ p.nome }}</span>
          <span v-if="getAllEsclusi().length === 0" class="alert-none">Nessuno</span>
        </div>

        <!-- ESCLUSIONI MANUALI -->
        <div class="esclusioni-grid" v-if="convocazione">
          <div class="esclusione-panel" v-for="tipo in ['no_sabato_mattina', 'no_sabato_pomeriggio', 'no_domenica']" :key="tipo">
            <div class="esclusione-panel-header">
              <span class="esclusione-panel-title">{{ tipo.replace(/_/g, ' ').toUpperCase() }}</span>
              <select @change="toggleEsclusione(tipo, $event)" class="esclusione-select">
                <option value="">+ Aggiungi</option>
                <option v-for="p in getGiocatoriDisponibili(tipo)" :key="p.id" :value="p.id">{{ p.cognome }} {{ p.nome }}</option>
              </select>
            </div>
            <div class="esclusione-tags">
              <span v-for="p in getEsclusiPerTipo(tipo)" :key="p.id" class="esclusione-tag" @click="toggleEsclusione(tipo, p.id)">{{ p.cognome }} {{ p.nome }} ×</span>
              <span v-if="getEsclusiPerTipo(tipo).length === 0" class="esclusione-none">—</span>
            </div>
          </div>
        </div>

        <!-- GARE -->
        <div class="gare-scroll">
          <div class="gare-grid" :style="{ gridTemplateColumns: 'repeat(' + convocazione.gare.length + ', minmax(280px, 1fr))' }">
            <!-- Header Banner -->
            <div class="gare-banner" :style="{ gridColumn: '1 / -1' }">
              <img v-if="societaAttiva?.logosponsor" :src="'/uploads/' + societaAttiva.logosponsor" alt="logo" class="banner-logo banner-logo-left" />
              <img v-else src="/logosponsor.png" alt="logo" class="banner-logo banner-logo-left" />
              <div class="banner-text">
                <div class="banner-title">{{ societaAttiva?.nome || 'SQUADRA' }}</div>
                <div class="banner-sub">CONVOCAZIONE GARE</div>
                <div class="banner-cat">{{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</div>
              </div>
              <img v-if="societaAttiva?.logo" :src="'/uploads/' + societaAttiva.logo" alt="logo" class="banner-logo banner-logo-right" />
              <img v-else src="/logo.jpg" alt="logo" class="banner-logo banner-logo-right" />
            </div>

            <div v-for="(gara, gi) in convocazione.gare" :key="gi" class="gara-card">
              <div class="gara-card-header">
                <span class="gara-num">{{ gi + 1 }}</span>
                <input v-model="gara.gara" placeholder="Squadra A vs Squadra B" class="gara-title-input" />
              </div>
              <div class="gara-fields">
                <div class="gf-row"><span class="gf-label">Data</span><input type="date" v-model="gara.data" class="gf-input" /></div>
                <div class="gf-row"><span class="gf-label">Campo</span><input v-model="gara.campo" class="gf-input" /></div>
                <div class="gf-row"><span class="gf-label">Indirizzo</span><input v-model="gara.indirizzo" class="gf-input" /></div>
                <div class="gf-row"><span class="gf-label">Appuntamento</span><input v-model="gara.appuntamento" class="gf-input" /></div>
                <div class="gf-row"><span class="gf-label">Inizio Gara</span><input v-model="gara.inizio_gara" class="gf-input" /></div>
                <div class="gf-row"><span class="gf-label">Mister</span>
                  <select v-model="gara.allenatore" class="gf-input">
                    <option value="">— Seleziona —</option>
                    <option v-for="r in responsabili" :key="r.id" :value="r.cognome">{{ r.cognome }} - {{ r.cellulare }}</option>
                  </select>
                </div>
              </div>
              <div class="giocatori-section">
                <div class="giocatori-title">
                  <span class="giocatori-title-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="7" r="4"/><path d="M5.5 21c0-4.5 3-6.5 6.5-6.5s6.5 2 6.5 6.5"/></svg>
                  </span>
                  SQUADRA
                  <span class="giocatori-count">{{ countAssigned(gara) }}</span>
                </div>
                <div class="giocatori-grid">
                  <div v-for="(pid, pos) in gara.giocatori" :key="'slot-' + pos" class="giocatore-slot" :class="{ filled: !!pid }" @click="openPicker(gi, pos)">
                    <span class="pos-badge">{{ pos + 1 }}</span>
                    <span v-if="pid" class="slot-name">{{ getPlayerCognome(pid) }}</span>
                    <span v-else class="slot-empty">+ tap</span>
                    <span v-if="pid" class="slot-remove" @click.stop="rimuoviGiocatore(gi, pos)">×</span>
                  </div>
                  <div class="giocatore-slot add-slot" @click="aggiungiSlot(gi)">
                    <span class="add-icon">+</span>
                    <span class="slot-empty">Aggiungi</span>
                  </div>
                </div>
              </div>

              <!-- PLAYER PICKER MODAL -->
              <div v-if="pickerOpen && pickerGara === gi && pickerPos !== null" class="picker-overlay" @click.self="closePicker">
                <div class="picker-modal">
                  <div class="picker-header">
                    <div class="picker-title">
                      <span class="picker-pos">#{{ pickerPos + 1 }}</span>
                      <span>Seleziona Giocatore</span>
                    </div>
                    <button class="picker-close" @click="closePicker">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                    </button>
                  </div>
                  <div class="picker-search">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
                    <input v-model="pickerSearch" placeholder="Cerca giocatore..." autofocus />
                  </div>
                  <div class="picker-list">
                    <div class="picker-empty" v-if="filteredPickerPlayers.length === 0">Nessun giocatore trovato</div>
                    <div v-for="p in filteredPickerPlayers" :key="p.id" class="picker-item" :class="{ selected: p.id === gara.giocatori[pickerPos] }" @click="selectPlayer(gi, pickerPos, p.id)">
                      <div class="picker-avatar">{{ p.cognome.charAt(0) }}{{ p.nome.charAt(0) }}</div>
                      <div class="picker-info">
                        <span class="picker-name">{{ p.cognome }}</span>
                        <span class="picker-surname">{{ p.nome }}</span>
                      </div>
                      <div class="picker-check" v-if="p.id === gara.giocatori[pickerPos]">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- NOTE -->
        <div class="note-section">
          <label class="note-label">Note</label>
          <textarea v-model="convocazione.note" rows="6" class="note-textarea"></textarea>
        </div>
      </main>

      <div v-else class="empty-state">
        <div class="empty-icon">⚽</div>
        <div class="empty-title">Nessuna convocazione attiva</div>
        <div class="empty-sub">Seleziona un weekend dalla sidebar o crea una nuova convocazione</div>
        <button class="btn btn-accent" @click="nuovaConvocazione()">+ Nuova Convocazione</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, getRegistroMese, getPartite, getCategoriaResponsabili, getWeekend, getWeekendPartite } from '../api/index.js'
import axios from 'axios'
import { jsPDF } from 'jspdf'
import html2canvas from 'html2canvas'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva, societaAttiva, stagioneCorrente } = useStore()
const categoriaId = parseInt(route.params.id)

const base = '/api'
const token = () => localStorage.getItem('token')
const headers = () => ({ Authorization: 'Bearer ' + token() })

const storico = ref([])
const convocazioneId = ref(null)
const convocazione = ref(null)
const persone = ref([])
const responsabili = ref([])
const numPartite = ref(1)
const registro = ref([])
const mobileMenuOpen = ref(false)
const weekendDisponibili = ref([])
const pickerOpen = ref(false)
const pickerGara = ref(null)
const pickerPos = ref(null)
const pickerSearch = ref('')

const filteredPickerPlayers = computed(() => {
  const players = getGiocatoriSettimanaPrecedente()
  if (!pickerSearch.value) return players
  const s = pickerSearch.value.toLowerCase()
  return players.filter(p => p.cognome.toLowerCase().includes(s) || p.nome.toLowerCase().includes(s))
})

const oggi = new Date()
const annoCorrente = oggi.getFullYear()
const meseCorrente = oggi.getMonth() + 1

function getGiocatoriSettimanaPrecedente() {
  if (!convocazione.value || !convocazione.value.data_inizio) return persone.value
  const range = getWeekDateRange(convocazione.value.data_inizio)
  if (!range) return persone.value
  const presenzeCount = {}
  const assenzeCount = {}
  registro.value.filter(r => r.data >= range.monday && r.data <= range.friday).forEach(r => {
    if (['X', 'P', 'R'].includes(r.codice)) presenzeCount[r.persona_id] = (presenzeCount[r.persona_id] || 0) + 1
    if (['AI', 'AG'].includes(r.codice)) assenzeCount[r.persona_id] = (assenzeCount[r.persona_id] || 0) + 1
  })
  return persone.value.filter(p => presenzeCount[p.id] >= 2 && (assenzeCount[p.id] || 0) < 2)
}

function getWeekDateRange(dataGara) {
  if (!dataGara) return null
  const data = new Date(dataGara)
  const dayOfWeek = data.getDay()
  let weekendSat = new Date(data)
  if (dayOfWeek === 0) weekendSat.setDate(data.getDate() - 1)
  else if (dayOfWeek !== 6) weekendSat = new Date(data)
  const daysToPrevMonday = weekendSat.getDay() === 0 ? 2 : weekendSat.getDay() + 1
  const mondayPrev = new Date(weekendSat)
  mondayPrev.setDate(weekendSat.getDate() - daysToPrevMonday)
  const fridayPrev = new Date(mondayPrev)
  fridayPrev.setDate(mondayPrev.getDate() + 4)
  return {
    monday: mondayPrev.toISOString().split('T')[0],
    friday: fridayPrev.toISOString().split('T')[0],
    mondayLabel: mondayPrev.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit' }),
    fridayLabel: fridayPrev.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit' })
  }
}

function getSettimanaLabel(dataGara) {
  const range = getWeekDateRange(dataGara)
  if (!range) return ''
  return `${range.mondayLabel} - ${range.fridayLabel}`
}

function getAllEsclusi() {
  if (!convocazione.value || !convocazione.value.data_inizio) return []
  const range = getWeekDateRange(convocazione.value.data_inizio)
  if (!range) return []
  const assenzeCount = {}
  registro.value.filter(r => r.data >= range.monday && r.data <= range.friday && ['AI', 'AG'].includes(r.codice)).forEach(r => {
    assenzeCount[r.persona_id] = (assenzeCount[r.persona_id] || 0) + 1
  })
  return persone.value.filter(p => assenzeCount[p.id] >= 2).sort((a, b) => a.cognome.localeCompare(b.cognome))
}

function getEsclusiPerTipo(tipo) {
  if (!convocazione.value) return []
  const esclusioni = convocazione.value.esclusioni || []
  const ids = esclusioni.filter(e => e.tipo === tipo).map(e => e.persona_id)
  return persone.value.filter(p => ids.includes(p.id)).sort((a, b) => a.cognome.localeCompare(b.cognome))
}

function getGiocatoriDisponibili(tipo) {
  const esclusiIds = getEsclusiPerTipo(tipo).map(p => p.id)
  const nonConvocabiliIds = getAllEsclusi().map(p => p.id)
  const tuttiEsclusi = [...new Set([...esclusiIds, ...nonConvocabiliIds])]
  return persone.value.filter(p => !tuttiEsclusi.includes(p.id)).sort((a, b) => a.cognome.localeCompare(b.cognome))
}

function toggleEsclusione(tipo, eventOrId) {
  if (!convocazione.value) return
  if (!convocazione.value.esclusioni) convocazione.value.esclusioni = []
  let personaId
  if (typeof eventOrId === 'object') {
    personaId = parseInt(eventOrId.target.value)
    eventOrId.target.value = ''
  } else {
    personaId = parseInt(eventOrId)
  }
  if (!personaId) return
  const existingIdx = convocazione.value.esclusioni.findIndex(e => e.tipo === tipo && e.persona_id === personaId)
  if (existingIdx >= 0) convocazione.value.esclusioni.splice(existingIdx, 1)
  else convocazione.value.esclusioni.push({ tipo, persona_id: personaId })
}

function getCognomeDisplay(p) {
  const sameCognomi = persone.value.filter(x => x.cognome === p.cognome)
  if (sameCognomi.length > 1) return `${p.cognome} ${p.nome.charAt(0)}.`
  return p.cognome
}

function getPlayerCognome(id) {
  const p = persone.value.find(x => x.id === id)
  return p ? p.cognome : ''
}

function countAssigned(gara) {
  return gara.giocatori.filter(Boolean).length
}

function openPicker(garaIdx, pos) {
  pickerGara.value = garaIdx
  pickerPos.value = pos
  pickerSearch.value = ''
  pickerOpen.value = true
}

function closePicker() {
  pickerOpen.value = false
  pickerGara.value = null
  pickerPos.value = null
  pickerSearch.value = ''
}

function selectPlayer(garaIdx, pos, playerId) {
  const gara = convocazione.value.gare[garaIdx]
  gara.giocatori[pos] = playerId
  closePicker()
}

function rimuoviGiocatore(garaIdx, pos) {
  const gara = convocazione.value.gare[garaIdx]
  gara.giocatori.splice(pos, 1)
}

function aggiungiSlot(garaIdx) {
  convocazione.value.gare[garaIdx].giocatori.push(null)
}

function aggiustaGare() {
  const n = numPartite.value
  const gare = convocazione.value.gare
  while (gare.length < n) gare.push(garaVuota(gare.length + 1))
   if (gare.length > n) gare.splice(n)
}

function padGiocatori(arr) {
  while (arr.length < 10) arr.push(null)
  return arr
}

function formatData(d) {
  if (!d) return ''
  const [y, m, g] = d.split('-')
  return `${g}/${m}/${y}`
}

function formatDataShort(d) {
  if (!d) return ''
  const [y, m, g] = d.split('-')
  return `${g}/${m}/${y.slice(2)}`
}

function garaVuota(numero) {
  return { numero, gara: '', data: '', campo: '', indirizzo: '', appuntamento: '', inizio_gara: '', allenatore: '', giocatori: Array(10).fill(null) }
}

async function caricaPartiteWeekend(dataInizio, dataFine) {
  if (!dataInizio || !dataFine) return []
  try {
    const res = await getPartite(categoriaId)
    const partite = res.data || []
    return partite.filter(p => p.data_partite >= dataInizio && p.data_partite <= dataFine).sort((a, b) => (a.ora || '').localeCompare(b.ora || ''))
  } catch { return [] }
}

function getMisterCognome(misterId) {
  const m = responsabili.value.find(r => r.id === misterId)
  return m ? m.cognome : ''
}

function nuovaConvocazione() {
  convocazioneId.value = null
  const oggi = new Date().toISOString().split('T')[0]
  const domani = new Date()
  domani.setDate(domani.getDate() + 1)
  const domenica = domani.toISOString().split('T')[0]
  popolaConvocazione(oggi, domenica)
}

async function popolaConvocazione(dataInizio, dataFine) {
  const partite = await caricaPartiteWeekend(dataInizio, dataFine)
  const nomeSocieta = societaAttiva.value?.nome_breve || societaAttiva.value?.nome || 'Noi'
  const gare = partite.length > 0 ? partite.map((p, idx) => ({
    numero: idx + 1, gara: `${nomeSocieta} vs ${p.avversario || 'TBD'}`, data: p.data_partite, campo: p.campo || '',
    indirizzo: p.indirizzo || '', appuntamento: '', inizio_gara: p.ora ? p.ora.slice(0, 5) : '',
    allenatore: getMisterCognome(p.mister_id), giocatori: Array(10).fill(null)
  })) : [garaVuota(1)]
  numPartite.value = gare.length
  convocazione.value = {
    data_inizio: dataInizio, data_fine: dataFine, esclusioni: [],
    note: `PRESENTARSI ALL'APPUNTAMENTO IN ORARIO STABILITO ED IN TENUTA DA RAPPRESENTANZA GEMS (NO GIA CAMBIATI).
SI GIOCA CON KIT GARA* (MAGLIA CALZONCINI E CALZETTONI) PORTARE FELPA D'ALLENAMENTO PER RISCALDAMENTO E K-WAY IN BORSA PER L'EVENIENZA.
AVVISARE TEMPESTIVAMENTE L'ALLENATORE PRESENTE IN GARA IN CASO DI RITARDO O ASSENZA.
*PORTARE COMUNQUE MAGLIA DI RICAMBIO, CALZONCINI E CALZETTONI PER MODIFICARE I COLORI IN BASE ALL'AVVERSARIO.`,
    gare
  }
}

async function caricaPartiteEsistenti() {
  if (!convocazione.value || !convocazione.value.data_inizio || !convocazione.value.data_fine) { alert('Seleziona prima il weekend (data inizio e fine)'); return }
  const partite = await caricaPartiteWeekend(convocazione.value.data_inizio, convocazione.value.data_fine)
  if (partite.length === 0) { alert('Nessuna partita trovata per questo weekend'); return }
  const nomeSocieta = societaAttiva.value?.nome_breve || societaAttiva.value?.nome || 'Noi'
  const gare = partite.map((p, idx) => ({
    numero: idx + 1, gara: `${nomeSocieta} vs ${p.avversario || 'TBD'}`, data: p.data_partite, campo: p.campo || '',
    indirizzo: p.indirizzo || '', appuntamento: '', inizio_gara: p.ora ? p.ora.slice(0, 5) : '',
    allenatore: getMisterCognome(p.mister_id), giocatori: Array(10).fill(null)
  }))
  convocazione.value.gare = gare
  numPartite.value = gare.length
}

async function caricaConvocazione(id) {
  convocazioneId.value = id
  const res = await axios.get(base + '/convocazioni/' + id, { headers: headers() })
  const d = res.data
  const garaData = d.gare[0]?.data
  if (garaData) {
    const [y, m] = garaData.split('-')
    if (parseInt(m) !== meseCorrente || parseInt(y) !== annoCorrente) {
      const regRes = await getRegistroMese(categoriaId, parseInt(y), parseInt(m))
      registro.value = regRes.data
    }
  }
  convocazione.value = {
    data_inizio: d.data_inizio, data_fine: d.data_fine || '', esclusioni: d.esclusioni || [],
    note: d.note || '',
    gare: d.gare.map((g, idx) => ({
      ...g, numero: g.numero || idx + 1, data: g.data || '',
       giocatori: padGiocatori((g.giocatori || []).sort((a, b) => a.posizione - b.posizione).map(x => x.persona_id))
    }))
  }
  numPartite.value = convocazione.value.gare.length
}

async function loadStorico() {
  const res = await axios.get(base + '/convocazioni/?categoria_id=' + categoriaId, { headers: headers() })
  storico.value = res.data
}

async function loadMisters() {
  try {
    const res = await axios.get(base + '/categorie/' + categoriaId + '/responsabili', { headers: headers() })
    responsabili.value = res.data.filter(r => r.ruolo !== 'dirigente')
  } catch (e) { responsabili.value = [] }
}

async function loadWeekendDisponibili() {
  try {
    const res = await getWeekend(societaAttiva.value?.id || null)
    const tuttiWeekend = res.data || []
    const convocazioneRanges = storico.value.map(c => ({ inizio: c.data_inizio, fine: c.data_fine || c.data_inizio }))
    const result = []
    for (const w of tuttiWeekend) {
      const giaConvocato = convocazioneRanges.some(r => w.data_inizio >= r.inizio && w.data_inizio <= r.fine)
      if (giaConvocato) continue
      const partiteRes = await getWeekendPartite(w.id)
      const partite = (partiteRes.data || []).filter(p => p.categoria_id === categoriaId)
      if (partite.length === 0) continue
      result.push({ ...w, partite: partite.sort((a, b) => a.data_partite.localeCompare(b.data_partite) || (a.ora || '').localeCompare(b.ora || '')) })
    }
    weekendDisponibili.value = result.sort((a, b) => a.data_inizio.localeCompare(b.data_inizio))
  } catch (e) { weekendDisponibili.value = [] }
}

function creaConvocazioneDaWeekend(weekend) {
  convocazioneId.value = null
  const dataInizio = weekend.data_inizio
  const dataFine = weekend.data_fine || dataInizio
  const nomeSocieta = societaAttiva.value?.nome_breve || societaAttiva.value?.nome || 'Noi'
  const gare = weekend.partite.map((p, idx) => ({
    numero: idx + 1,
    gara: p.casa_fuori === 'fuori' ? `${p.avversario || 'TBD'} vs ${nomeSocieta}` : `${nomeSocieta} vs ${p.avversario || 'TBD'}`,
    data: p.data_partite, campo: p.campo || '', indirizzo: p.indirizzo || '', appuntamento: '',
    inizio_gara: p.ora ? p.ora.slice(0, 5) : '', allenatore: getMisterCognome(p.mister_id), giocatori: Array(10).fill(null)
  }))
  numPartite.value = gare.length
  convocazione.value = {
    data_inizio: dataInizio, data_fine: dataFine, esclusioni: [],
    note: `PRESENTARSI ALL'APPUNTAMENTO IN ORARIO STABILITO ED IN TENUTA DA RAPPRESENTANZA GEMS (NO GIA CAMBIATI).
SI GIOCA CON KIT GARA* (MAGLIA CALZONCINI E CALZETTONI) PORTARE FELPA D'ALLENAMENTO PER RISCALDAMENTO E K-WAY IN BORSA PER L'EVENIENZA.
AVVISARE TEMPESTIVAMENTE L'ALLENATORE PRESENTE IN GARA IN CASO DI RITARDO O ASSENZA.
*PORTARE COMUNQUE MAGLIA DI RICAMBIO, CALZONCINI E CALZETTONI PER MODIFICARE I COLORI IN BASE ALL'AVVERSARIO.`,
    gare
  }
}

async function salva() {
  const payload = {
    categoria_id: categoriaId, data_inizio: convocazione.value.data_inizio, data_fine: convocazione.value.data_fine,
    esclusioni: convocazione.value.esclusioni || [], note: convocazione.value.note,
    gare: convocazione.value.gare.map((g, gi) => ({
      numero: gi + 1, gara: g.gara, data: g.data || null, campo: g.campo, indirizzo: g.indirizzo,
      appuntamento: g.appuntamento, inizio_gara: g.inizio_gara, allenatore: g.allenatore,
      giocatori: g.giocatori.map((pid, i) => pid ? { persona_id: pid, posizione: i + 1 } : null).filter(Boolean)
    }))
  }
  if (convocazioneId.value) await axios.put(base + '/convocazioni/' + convocazioneId.value, payload, { headers: headers() })
  else { const res = await axios.post(base + '/convocazioni/', payload, { headers: headers() }); convocazioneId.value = res.data.id }
  await loadStorico()
  await loadWeekendDisponibili()
  alert('Salvato!')
}

async function esportaPDF() {
  if (!convocazione.value) return
  const numGare = convocazione.value.gare.length
  const containerWidth = Math.max(800, numGare * 320) + 40
  const personeMap = {}
  persone.value.forEach(p => { personeMap[p.id] = p; personeMap[String(p.id)] = p; personeMap[Number(p.id)] = p })
  let exportContainer = document.getElementById('pdf-export-container')
  if (!exportContainer) { exportContainer = document.createElement('div'); exportContainer.id = 'pdf-export-container'; document.body.appendChild(exportContainer) }
  exportContainer.style.cssText = `position: fixed !important; left: -9999px !important; top: 0px !important; width: ${containerWidth}px !important; background: #fff !important; padding: 0px !important; z-index: 9999 !important; overflow: visible !important; display: block !important;`
  const getGiocatoreNome = (id) => { if (!id) return '—'; const p = personeMap[id] || personeMap[Number(id)] || persone.value.find(x => x.id === id || x.id === Number(id)); return p ? p.cognome : '—' }
  const formatD = (d) => { if (!d) return '—'; const [y, m, g] = d.split('-'); return `${g}/${m}/${y}` }

  const garaCards = convocazione.value.gare.map((gara, idx) => {
    const giocatoriRows = gara.giocatori.map((pid, i) => {
      const nome = getGiocatoreNome(pid)
      const filled = pid !== null
      return `<div style="display:flex;align-items:center;gap:8px;padding:4px 0;${i < 13 ? 'border-bottom:1px solid #f0f0f0;' : ''}">
        <span style="min-width:22px;height:22px;border-radius:50%;background:${filled ? '#dc2626' : '#f0f0f0'};color:#fff;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:800;flex-shrink:0;">${i + 1}</span>
        <span style="font-size:12px;font-weight:${filled ? '700' : '400'};color:${filled ? '#1a1a1a' : '#ccc'};flex:1;">${nome}</span>
      </div>`
    }).join('')

    return `<div style="background:#fff;border:2px solid #1a1a1a;border-radius:12px;overflow:hidden;box-shadow:4px 4px 0 #1a1a1a;">
      <div style="background:#1a1a1a;color:#fff;padding:12px 16px;display:flex;align-items:center;gap:10px;">
        <span style="font-size:28px;font-weight:900;line-height:1;">${idx + 1}</span>
        <div style="flex:1;">
          <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#dc2626;font-weight:700;">Gara ${idx + 1}</div>
          <div style="font-size:14px;font-weight:800;letter-spacing:0.5px;">${gara.gara || '—'}</div>
        </div>
      </div>
      <div style="padding:12px 16px;background:#fafafa;border-bottom:1px solid #eee;">
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px 16px;">
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Data</span><br><span style="font-weight:700;color:#1a1a1a;">${formatD(gara.data)}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Campo</span><br><span style="font-weight:700;color:#1a1a1a;">${gara.campo || '—'}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Indirizzo</span><br><span style="font-weight:700;color:#1a1a1a;">${gara.indirizzo || '—'}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Appuntamento</span><br><span style="font-weight:700;color:#1a1a1a;">${gara.appuntamento || '—'}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Inizio Gara</span><br><span style="font-weight:700;color:#1a1a1a;">${gara.inizio_gara || '—'}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Allenatore</span><br><span style="font-weight:700;color:#1a1a1a;">${gara.allenatore || '—'}</span></div>
        </div>
      </div>
      <div style="padding:12px 16px;">
        <div style="font-size:9px;letter-spacing:2px;text-transform:uppercase;color:#999;font-weight:700;margin-bottom:8px;">Squadra</div>
        ${giocatoriRows}
      </div>
    </div>`
  }).join('')

  const stagioneTxt = stagioneCorrente.value ? `${stagioneCorrente.value}/${(stagioneCorrente.value || 0) + 1}` : ''

  exportContainer.innerHTML = `<div style="background:#fff;font-family:'Helvetica Neue',Arial,sans-serif;width:100%;box-sizing:border-box;">
    <div style="background:#1a1a1a;color:#fff;padding:24px 20px;text-align:center;position:relative;overflow:hidden;">
      <div style="position:absolute;top:0;left:0;right:0;bottom:0;background:repeating-linear-gradient(90deg,transparent,transparent 40px,rgba(255,255,255,0.02) 40px,rgba(255,255,255,0.02) 41px);pointer-events:none;"></div>
      <div style="display:flex;align-items:center;justify-content:center;gap:20px;position:relative;z-index:1;">
        <img src="${societaAttiva.value?.logosponsor ? '/uploads/' + societaAttiva.value.logosponsor : '/logosponsor.png'}" style="height:60px;width:60px;object-fit:contain;border-radius:50%;background:#fff;padding:4px;" />
        <div>
          <div style="font-size:10px;letter-spacing:4px;text-transform:uppercase;color:#dc2626;font-weight:700;margin-bottom:4px;">Convocazione Gare</div>
          <div style="font-size:28px;font-weight:900;letter-spacing:3px;line-height:1;">${societaAttiva.value?.nome || 'SQUADRA'}</div>
          <div style="font-size:16px;font-weight:700;color:#dc2626;margin-top:6px;letter-spacing:1px;">${categoriaAttiva.value?.nome || ''} ${categoriaAttiva.value?.anno || ''}</div>
          <div style="font-size:11px;color:#999;margin-top:4px;letter-spacing:1px;">${formatD(convocazione.value.data_inizio)}${convocazione.value.data_fine ? ' — ' + formatD(convocazione.value.data_fine) : ''}</div>
        </div>
        <img src="${societaAttiva.value?.logo ? '/uploads/' + societaAttiva.value.logo : '/logo.jpg'}" style="height:60px;width:60px;object-fit:contain;border-radius:50%;background:#fff;padding:4px;" />
      </div>
    </div>
    <div style="display:grid;grid-template-columns:repeat(${numGare},1fr);gap:20px;padding:20px;box-sizing:border-box;">
      ${garaCards}
    </div>
    ${convocazione.value.note ? `
    <div style="margin:0 20px 20px;padding:16px 20px;background:#fff8f0;border:1px solid #fde0c0;border-radius:8px;">
      <div style="font-size:9px;letter-spacing:2px;text-transform:uppercase;color:#dc2626;font-weight:700;margin-bottom:6px;">Note</div>
      <div style="font-size:10px;color:#666;line-height:1.6;white-space:pre-wrap;">${convocazione.value.note}</div>
    </div>` : ''}
    <div style="text-align:center;padding:12px;border-top:2px solid #1a1a1a;margin-top:0;">
      <span style="font-size:9px;letter-spacing:2px;text-transform:uppercase;color:#ccc;">${societaAttiva.value?.nome || ''} — Stagione ${stagioneTxt}</span>
    </div>
  </div>`

  try {
    await new Promise(resolve => setTimeout(resolve, 500))
    const actualHeight = exportContainer.scrollHeight
    const captureHeight = Math.max(actualHeight + 100, 800)
    const canvas = await html2canvas(exportContainer, { scale: 1.5, useCORS: true, logging: false, backgroundColor: '#ffffff', width: containerWidth, height: captureHeight, windowWidth: containerWidth, scrollX: 0, scrollY: 0, x: 0, y: 0 })
    const pdf = new jsPDF('landscape', 'mm', 'a4')
    const pdfWidth = pdf.internal.pageSize.getWidth()
    const pdfHeight = pdf.internal.pageSize.getHeight()
    const imgWidth = pdfWidth - 20
    const imgHeight = (canvas.height / canvas.width) * imgWidth
    pdf.addImage(canvas.toDataURL('image/png'), 'PNG', 10, 10, imgWidth, Math.min(imgHeight, pdfHeight - 20))
    const categoriaNome = categoriaAttiva.value?.nome || 'Categoria'
    const dataInizio = convocazione.value.data_inizio || ''
    const dataFine = convocazione.value.data_fine || ''
    const dataFormattata = dataInizio ? dataInizio.split('-').reverse().join('/') : 'data'
    const dataFinale = dataFine ? dataInizio.split('-').reverse().join('/') + ' - ' + dataFine.split('-').reverse().join('/') : dataFormattata
    pdf.save('Convocazioni ' + categoriaNome + ' del ' + dataFinale + '.pdf')
  } catch (e) { console.error('Errore PDF:', e); alert('Errore nella generazione del PDF') }
}

async function elimina() {
  if (!convocazioneId.value) return
  if (!confirm('Eliminare questa convocazione?')) return
  await axios.delete(base + '/convocazioni/' + convocazioneId.value, { headers: headers() })
  convocazione.value = null
  convocazioneId.value = null
  await loadStorico()
  await loadWeekendDisponibili()
}

onMounted(async () => {
  const res = await getPersone(categoriaId)
  persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
  const regRes = await getRegistroMese(categoriaId, annoCorrente, meseCorrente)
  registro.value = regRes.data
  await loadStorico()
  await loadMisters()
  await loadWeekendDisponibili()
})
</script>

<style scoped>
/* ============================================
   DESIGN SYSTEM — Dark editorial sports theme
   ============================================ */

.conv-page {
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100%;
  max-width: none;
  background: #0a0a0a;
  color: #e4e4e4;
  font-family: var(--font-sans, 'Segoe UI', system-ui, -apple-system, sans-serif);
}

/* ---- PAGE HEADER ---- */
.page-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1.25rem;
  background: #000;
  border-bottom: 1px solid rgba(255,255,255,0.06);
  flex-shrink: 0;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.icon-btn {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  border: 1px solid rgba(255,255,255,0.08);
  background: rgba(255,255,255,0.04);
  color: #a3a3a3;
  cursor: pointer;
  transition: all 0.2s;
}

.icon-btn:hover {
  background: rgba(255,255,255,0.1);
  color: #fff;
}

.icon-btn svg {
  width: 18px;
  height: 18px;
}

.header-center {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0;
}

.header-label {
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: #dc2626;
}

.header-category {
  font-size: 1.05rem;
  font-weight: 800;
  color: #fff;
  letter-spacing: 0.02em;
  line-height: 1.2;
}

.header-right {
  display: flex;
  align-items: center;
}

/* ---- BUTTONS ---- */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.5rem 1rem;
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
  white-space: nowrap;
}

.btn-accent {
  background: #dc2626;
  color: #fff;
  border-color: #dc2626;
}

.btn-accent:hover {
  background: #ef4444;
  border-color: #ef4444;
  transform: translateY(-1px);
  box-shadow: 0 4px 16px rgba(220, 38, 38, 0.3);
}

.btn-primary {
  background: #dc2626;
  color: #fff;
}

.btn-primary:hover {
  background: #ef4444;
  transform: translateY(-1px);
}

.btn-ghost {
  background: rgba(255,255,255,0.05);
  color: #a3a3a3;
  border-color: rgba(255,255,255,0.08);
}

.btn-ghost:hover {
  background: rgba(255,255,255,0.1);
  color: #fff;
}

.btn-danger {
  background: rgba(239, 68, 68, 0.15);
  color: #ef4444;
  border-color: rgba(239, 68, 68, 0.3);
  padding: 0.5rem 0.6rem;
}

.btn-danger:hover {
  background: #dc2626;
  color: #fff;
}

/* ---- BODY LAYOUT ---- */
.conv-body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

/* ---- SIDEBAR ---- */
.sidebar {
  width: 220px;
  flex-shrink: 0;
  background: #111;
  border-right: 1px solid rgba(255,255,255,0.06);
  overflow-y: auto;
  display: none;
  flex-direction: column;
}

@media (min-width: 1024px) {
  .sidebar { display: flex; }
}

.sidebar-section {
  padding: 1rem;
  border-bottom: 1px solid rgba(255,255,255,0.06);
}

.sidebar-section:last-child {
  border-bottom: none;
}

.sidebar-title {
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: #525252;
  margin-bottom: 0.75rem;
}

.sidebar-link {
  padding: 0.5rem 0.65rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.8rem;
  margin-bottom: 2px;
  color: #737373;
  transition: all 0.15s;
}

.sidebar-link:hover {
  background: rgba(255,255,255,0.05);
  color: #e4e4e4;
}

.sidebar-link.active {
  background: #dc2626;
  color: #fff;
  font-weight: 600;
}

.sidebar-empty {
  font-size: 0.7rem;
  color: #404040;
  text-align: center;
  padding: 0.5rem;
}

/* Mister cards */
.mister-card {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  border-radius: 8px;
  margin-bottom: 4px;
  background: rgba(255,255,255,0.02);
  border: 1px solid rgba(255,255,255,0.04);
}

.mister-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: #dc2626;
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.7rem;
  font-weight: 700;
  flex-shrink: 0;
}

.mister-info {
  display: flex;
  flex-direction: column;
  gap: 1px;
  min-width: 0;
}

.mister-name {
  font-size: 0.78rem;
  font-weight: 600;
  color: #e4e4e4;
}

.mister-tel {
  font-size: 0.65rem;
  color: #525252;
}

/* Weekend cards */
.weekend-card {
  background: rgba(255,255,255,0.03);
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 8px;
  padding: 0.65rem 0.75rem;
  margin-bottom: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.weekend-card:hover {
  border-color: #dc2626;
  background: rgba(220, 38, 38, 0.08);
  transform: translateY(-1px);
}

.weekend-card-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.weekend-name {
  font-weight: 700;
  font-size: 0.78rem;
  color: #e4e4e4;
}

.weekend-badge {
  background: #dc2626;
  color: #fff;
  font-size: 0.6rem;
  font-weight: 700;
  padding: 2px 6px;
  border-radius: 4px;
  min-width: 18px;
  text-align: center;
}

.weekend-dates {
  font-size: 0.65rem;
  color: #525252;
  margin-top: 3px;
}

/* ---- EDITOR ---- */
.editor {
  flex: 1;
  overflow-y: auto;
  padding: 1.25rem;
  background: #0a0a0a;
}

.editor-topbar {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  flex-wrap: wrap;
  margin-bottom: 1.25rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid rgba(255,255,255,0.06);
}

.date-pickers {
  display: flex;
  align-items: flex-end;
  gap: 0.75rem;
}

.date-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.date-field label {
  font-size: 0.55rem;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: #525252;
}

.date-field input {
  padding: 0.4rem 0.6rem;
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 6px;
  background: #171717;
  color: #e4e4e4;
  font-size: 0.8rem;
  outline: none;
  transition: border-color 0.2s;
}

.date-field input:focus {
  border-color: #dc2626;
}

.num-input {
  width: 56px !important;
  text-align: center;
}

.editor-actions {
  display: flex;
  gap: 0.5rem;
  margin-left: auto;
}

/* ---- ALERT BOX (non convocabili) ---- */
.alert-box {
  background: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.2);
  border-radius: 8px;
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.alert-icon {
  font-size: 0.9rem;
}

.alert-label {
  font-size: 0.75rem;
  font-weight: 700;
  color: #f59e0b;
  letter-spacing: 0.05em;
}

.alert-period {
  font-size: 0.7rem;
  color: #a16207;
}

.alert-tag {
  background: rgba(239, 68, 68, 0.2);
  color: #fca5a5;
  padding: 3px 10px;
  border-radius: 12px;
  font-size: 0.7rem;
  font-weight: 600;
}

.alert-none {
  font-size: 0.75rem;
  color: #525252;
}

/* ---- ESCLUSIONI ---- */
.esclusioni-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.esclusione-panel {
  background: #171717;
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 8px;
  padding: 0.75rem;
}

.esclusione-panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.esclusione-panel-title {
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  color: #737373;
}

.esclusione-select {
  font-size: 0.7rem;
  padding: 3px 6px;
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 4px;
  background: #0a0a0a;
  color: #a3a3a3;
  max-width: 130px;
  outline: none;
}

.esclusione-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.esclusione-tag {
  background: rgba(255,255,255,0.06);
  color: #a3a3a3;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 0.65rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
}

.esclusione-tag:hover {
  background: #dc2626;
  color: #fff;
}

.esclusione-none {
  font-size: 0.65rem;
  color: #404040;
}

/* ---- GARE GRID ---- */
.gare-scroll {
  overflow-x: auto;
  width: 100%;
  -webkit-overflow-scrolling: touch;
  margin-bottom: 1.25rem;
}

.gare-grid {
  display: grid;
  gap: 1rem;
  min-width: max-content;
  width: 100%;
}

/* Banner */
.gare-banner {
  background: linear-gradient(135deg, #1a0000 0%, #0a0a0a 100%);
  border: 1px solid rgba(220, 38, 38, 0.2);
  border-radius: 12px;
  padding: 1.25rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1.5rem;
}

.banner-logo {
  width: 64px;
  height: 64px;
  object-fit: contain;
  border-radius: 50%;
  background: rgba(255,255,255,0.05);
  padding: 4px;
}

.banner-text {
  text-align: center;
}

.banner-title {
  font-size: 1.5rem;
  font-weight: 900;
  letter-spacing: 0.1em;
  color: #fff;
}

.banner-sub {
  font-size: 0.85rem;
  font-weight: 600;
  letter-spacing: 0.15em;
  color: #737373;
  margin-top: 2px;
}

.banner-cat {
  font-size: 0.95rem;
  font-weight: 700;
  color: #dc2626;
  margin-top: 4px;
}

/* Gara card */
.gara-card {
  background: #111;
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 12px;
  min-width: 300px;
  overflow: hidden;
  transition: border-color 0.2s;
}

.gara-card:hover {
  border-color: rgba(255,255,255,0.12);
}

.gara-card-header {
  background: #dc2626;
  padding: 0.75rem 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.gara-num {
  font-size: 0.7rem;
  font-weight: 800;
  background: rgba(0,0,0,0.3);
  color: #fff;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.gara-title-input {
  flex: 1;
  background: rgba(255,255,255,0.12);
  border: 1px solid rgba(255,255,255,0.2);
  border-radius: 6px;
  padding: 0.5rem 0.75rem;
  color: #fff;
  font-size: 0.9rem;
  font-weight: 700;
  text-align: center;
  outline: none;
  transition: all 0.2s;
}

.gara-title-input::placeholder {
  color: rgba(255,255,255,0.4);
}

.gara-title-input:focus {
  background: rgba(255,255,255,0.18);
  border-color: rgba(255,255,255,0.4);
}

/* Gara fields */
.gara-fields {
  padding: 0.75rem;
  border-bottom: 1px solid rgba(255,255,255,0.06);
}

.gf-row {
  display: flex;
  align-items: center;
  margin-bottom: 6px;
  gap: 0.5rem;
}

.gf-row:last-child {
  margin-bottom: 0;
}

.gf-label {
  font-size: 0.6rem;
  color: #525252;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  min-width: 72px;
  flex-shrink: 0;
}

.gf-input {
  flex: 1;
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 4px;
  padding: 4px 8px;
  font-size: 0.78rem;
  height: 28px;
  box-sizing: border-box;
  background: #0a0a0a;
  color: #e4e4e4;
  outline: none;
  transition: border-color 0.2s;
}

.gf-input:focus {
  border-color: #dc2626;
}

/* Giocatori — Grid Layout */
.giocatori-section {
  padding: 0.75rem;
}

.giocatori-title {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: #525252;
  margin-bottom: 0.6rem;
}

.giocatori-title-icon {
  width: 14px;
  height: 14px;
  color: #dc2626;
}

.giocatori-title-icon svg {
  width: 100%;
  height: 100%;
}

.giocatori-count {
  margin-left: auto;
  font-size: 0.6rem;
  color: #404040;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

.giocatori-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
}

.giocatore-slot {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: 6px 2px;
  border-radius: 6px;
  border: 1px solid rgba(255,255,255,0.06);
  background: rgba(255,255,255,0.02);
  cursor: pointer;
  transition: all 0.15s;
  min-height: 48px;
  justify-content: center;
}

.giocatore-slot:hover {
  border-color: #dc2626;
  background: rgba(220, 38, 38, 0.08);
  transform: translateY(-1px);
}

.giocatore-slot.filled {
  border-color: rgba(220, 38, 38, 0.3);
  background: rgba(220, 38, 38, 0.06);
}

.pos-badge {
  font-size: 0.55rem;
  font-weight: 800;
  color: #404040;
  line-height: 1;
}

.giocatore-slot.filled .pos-badge {
  color: #dc2626;
}

.slot-name {
  font-size: 0.65rem;
  font-weight: 700;
  color: #e4e4e4;
  text-align: center;
  line-height: 1.2;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}

.slot-empty {
  font-size: 0.55rem;
  color: #404040;
  font-weight: 500;
  text-transform: uppercase;
}

.giocatore-slot.add-slot {
  border-style: dashed;
  border-color: rgba(255,255,255,0.12);
  background: rgba(255,255,255,0.01);
}

.giocatore-slot.add-slot:hover {
  border-color: #22c55e;
  background: rgba(34, 197, 94, 0.08);
}

.add-icon {
  font-size: 1.1rem;
  font-weight: 300;
  color: #666;
  line-height: 1;
}

.giocatore-slot.add-slot:hover .add-icon {
  color: #22c55e;
}

.slot-remove {
  position: absolute;
  top: 2px;
  right: 4px;
  font-size: 0.7rem;
  color: #ef4444;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.15s;
  line-height: 1;
}

.giocatore-slot:hover .slot-remove {
  opacity: 1;
}

.giocatore-slot {
  position: relative;
  letter-spacing: 0.05em;
}

/* ---- PLAYER PICKER MODAL ---- */
.picker-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.75);
  z-index: 300;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn 0.15s ease-out;
  backdrop-filter: blur(8px);
}

.picker-modal {
  width: 340px;
  max-height: 80vh;
  background: #111;
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  animation: scaleIn 0.2s ease-out;
  overflow: hidden;
  box-shadow: 0 24px 48px rgba(0,0,0,0.5);
}

.picker-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid rgba(255,255,255,0.06);
  background: #000;
}

.picker-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.picker-pos {
  background: #dc2626;
  color: #fff;
  font-size: 0.7rem;
  font-weight: 800;
  width: 24px;
  height: 24px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.picker-title span:last-child {
  font-size: 0.85rem;
  font-weight: 700;
  color: #fff;
}

.picker-close {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: rgba(255,255,255,0.06);
  border-radius: 6px;
  color: #737373;
  cursor: pointer;
  transition: all 0.15s;
}

.picker-close:hover {
  background: rgba(255,255,255,0.12);
  color: #fff;
}

.picker-close svg {
  width: 14px;
  height: 14px;
}

.picker-search {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  border-bottom: 1px solid rgba(255,255,255,0.06);
}

.picker-search svg {
  width: 16px;
  height: 16px;
  color: #404040;
  flex-shrink: 0;
}

.picker-search input {
  flex: 1;
  border: none;
  background: none;
  color: #e4e4e4;
  font-size: 0.85rem;
  outline: none;
  font-family: inherit;
}

.picker-search input::placeholder {
  color: #404040;
}

.picker-list {
  flex: 1;
  overflow-y: auto;
  padding: 0.5rem;
}

.picker-empty {
  text-align: center;
  padding: 2rem 1rem;
  color: #404040;
  font-size: 0.8rem;
}

.picker-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.6rem 0.75rem;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.12s;
}

.picker-item:hover {
  background: rgba(255,255,255,0.06);
}

.picker-item.selected {
  background: rgba(220, 38, 38, 0.15);
}

.picker-avatar {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: rgba(255,255,255,0.06);
  color: #a3a3a3;
  font-size: 0.65rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  letter-spacing: 0.02em;
}

.picker-item.selected .picker-avatar {
  background: #dc2626;
  color: #fff;
}

.picker-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.picker-name {
  font-size: 0.82rem;
  font-weight: 700;
  color: #e4e4e4;
}

.picker-surname {
  font-size: 0.7rem;
  color: #525252;
}

.picker-check {
  color: #dc2626;
  flex-shrink: 0;
}

.picker-check svg {
  width: 16px;
  height: 16px;
}

/* ---- NOTE ---- */
.note-section {
  margin-top: 0.5rem;
}

.note-label {
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: #525252;
  display: block;
  margin-bottom: 0.5rem;
}

.note-textarea {
  width: 100%;
  border: 1px solid rgba(220, 38, 38, 0.3);
  border-radius: 8px;
  padding: 1rem;
  font-size: 0.72rem;
  resize: vertical;
  background: rgba(220, 38, 38, 0.06);
  color: #fca5a5;
  font-weight: 600;
  white-space: pre-wrap;
  word-wrap: break-word;
  min-height: 100px;
  line-height: 1.4;
  outline: none;
  font-family: inherit;
  transition: border-color 0.2s;
}

.note-textarea:focus {
  border-color: #dc2626;
}

/* ---- EMPTY STATE ---- */
.empty-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  color: #404040;
}

.empty-icon {
  font-size: 3rem;
  opacity: 0.3;
}

.empty-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: #525252;
}

.empty-sub {
  font-size: 0.85rem;
  color: #404040;
  margin-bottom: 0.5rem;
}

/* ---- MOBILE MENU ---- */
.mobile-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.8);
  z-index: 200;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(6px);
}

.mobile-drawer {
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 280px;
  max-width: 85vw;
  background: #111;
  animation: slideInLeft 0.3s ease-out;
  overflow-y: auto;
  border-right: 1px solid rgba(255,255,255,0.06);
}

.mobile-drawer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid rgba(255,255,255,0.06);
  background: #000;
}

.mobile-drawer-title {
  font-weight: 700;
  font-size: 0.9rem;
  color: #fff;
}

.mobile-drawer-body {
  padding: 1rem;
}

.drawer-section {
  margin-bottom: 1.25rem;
}

.drawer-section-title {
  font-weight: 700;
  font-size: 0.6rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: #404040;
  margin-bottom: 0.5rem;
}

.drawer-link {
  padding: 0.6rem 0.75rem;
  border-radius: 6px;
  font-size: 0.8rem;
  cursor: pointer;
  color: #737373;
  margin-bottom: 2px;
  transition: all 0.15s;
}

.drawer-link:hover {
  background: rgba(255,255,255,0.05);
  color: #e4e4e4;
}

.drawer-link.active {
  background: #dc2626;
  color: #fff;
  font-weight: 600;
}

.drawer-weekend-link {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.drawer-weekend-meta {
  font-size: 0.65rem;
  color: #404040;
}

.drawer-mister {
  display: flex;
  justify-content: space-between;
  padding: 0.4rem 0.75rem;
  font-size: 0.8rem;
  border-bottom: 1px solid rgba(255,255,255,0.03);
}

.drawer-mister:last-child {
  border-bottom: none;
}

.mister-name {
  color: #e4e4e4;
  font-weight: 600;
}

.mister-tel {
  color: #525252;
}

.drawer-empty {
  font-size: 0.7rem;
  color: #404040;
  padding: 0.5rem;
  text-align: center;
}

/* ---- ANIMATIONS ---- */
@keyframes slideInLeft {
  from { transform: translateX(-100%); }
  to { transform: translateX(0); }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* ---- RESPONSIVE ---- */
@media (max-width: 768px) {
  .conv-body {
    flex-direction: column;
  }
  .gare-scroll {
    overflow-x: visible !important;
  }
  .gare-grid {
    grid-template-columns: 1fr !important;
    min-width: auto !important;
  }
  .editor-topbar {
    flex-direction: column;
    align-items: stretch;
    gap: 0.75rem;
  }
  .date-pickers {
    flex-wrap: wrap;
  }
  .editor-actions {
    margin-left: 0;
    justify-content: flex-end;
  }
  .esclusioni-grid {
    grid-template-columns: 1fr;
  }
  .header-center {
    flex-direction: column;
    gap: 0;
  }
  .header-label {
    font-size: 0.5rem;
  }
  .header-category {
    font-size: 0.85rem;
  }
  .banner-title {
    font-size: 1.1rem;
  }
  .banner-logo {
    width: 48px;
    height: 48px;
  }
  .giocatori-grid {
    grid-template-columns: repeat(4, 1fr) !important;
  }
  .giocatore-slot {
    min-height: 42px;
    padding: 4px 1px;
  }
  .slot-name {
    font-size: 0.58rem;
  }
  .picker-modal {
    width: 95vw;
    max-width: 340px;
  }
}
</style>
