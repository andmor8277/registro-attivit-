<template>
  <div class="conv-page">
    <header class="page-header">
      <div class="header-left">
        <button class="icon-btn" @click="router.push('/')" aria-label="Home">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
        </button>
      </div>
      <div class="header-center">
        <span class="header-label">CONVOCAZIONI</span>
        <span class="header-category">{{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
      </div>
      <div class="header-right">
        <button class="btn btn-primary" @click="nuovaConvocazione()">+ Nuova</button>
      </div>
    </header>

    <div class="conv-body">
      <main class="editor">
        <!-- WEEKEND CHIPS -->
        <div class="weekend-chips">
          <button v-for="c in convocazioniAttive" :key="'a-' + c.id" :class="['wk', { active: convocazioneId === c.id }]" @click="caricaConvocazione(c.id)">
            {{ formatDataShort(c.data_inizio) }}{{ c.data_fine ? ' \u2013 ' + formatDataShort(c.data_fine) : '' }}
          </button>
          <button v-for="w in weekendDisponibili" :key="'w-' + w.id" class="wk wk-new" @click="creaConvocazioneDaWeekend(w)">
            + {{ w.nome || formatDataShort(w.data_inizio) }}
          </button>
          <button class="wk wk-new" @click="nuovaConvocazione()">+ nuovo</button>
        </div>

        <!-- STORICO -->
        <div v-if="convocazioniStorico.length > 0" class="storico-section">
          <div class="storico-title">Storico</div>
          <div class="storico-chips">
            <button v-for="c in convocazioniStorico" :key="'s-' + c.id" :class="['wk', 'wk-storico', { active: convocazioneId === c.id }]" @click="caricaConvocazione(c.id)">
              {{ formatDataShort(c.data_inizio) }}{{ c.data_fine ? ' \u2013 ' + formatDataShort(c.data_fine) : '' }}
            </button>
          </div>
        </div>

        <!-- MISTER -->
        <div v-if="responsabili.length > 0" class="mister-section">
          <div class="mister-title">Mister</div>
          <div class="mister-list">
            <div v-for="r in responsabili" :key="r.id" class="mister-row">
              <span class="mister-name">{{ r.cognome }} {{ r.nome }}</span>
              <span class="mister-tel">{{ r.cellulare }}</span>
            </div>
          </div>
        </div>

        <template v-if="convocazione">
          <!-- TOPBAR: date + azioni -->
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
              <button class="btn btn-ghost" @click="caricaPartiteEsistenti">Carica Partite</button>
              <button class="btn btn-danger" @click="elimina">Elimina</button>
              <button class="btn btn-primary" @click="salva">Salva</button>
            </div>
          </div>

          <!-- NON CONVOCABILI -->
          <div class="alert-box">
            <span class="alert-icon">&#9888;&#65039;</span>
            <span class="alert-label">NON CONVOCABILI</span>
            <span class="alert-period" v-if="convocazione.data_inizio">(Lun-Ven {{ getSettimanaLabel(convocazione.data_inizio) }})</span>
            <span v-for="p in getAllEsclusi()" :key="p.id" class="alert-tag">{{ p.cognome }} {{ p.nome }}</span>
            <span v-if="getAllEsclusi().length === 0" class="alert-none">Nessuno</span>
          </div>

          <!-- ESCLUSIONI MANUALI -->
          <div class="esclusioni-grid">
            <div class="esclusione-panel" v-for="tipo in ['no_sabato_mattina', 'no_sabato_pomeriggio', 'no_domenica']" :key="tipo">
              <div class="esclusione-panel-header">
                <span class="esclusione-panel-title">{{ tipo.replace(/_/g, ' ').toUpperCase() }}</span>
                <select @change="toggleEsclusione(tipo, $event)" class="esclusione-select">
                  <option value="">+ Aggiungi</option>
                  <option v-for="p in getGiocatoriDisponibili(tipo)" :key="p.id" :value="p.id">{{ p.cognome }} {{ p.nome }}</option>
                </select>
              </div>
              <div class="esclusioni-tags-wrap esclusione-tags">
                <span v-for="p in getEsclusiPerTipo(tipo)" :key="p.id" class="esclusione-tag" @click="toggleEsclusione(tipo, p.id)">{{ p.cognome }} {{ p.nome }} &times;</span>
                <span v-if="getEsclusiPerTipo(tipo).length === 0" class="esclusione-none">&mdash;</span>
              </div>
            </div>
          </div>

          <!-- PAGE HEAD -->
          <div class="page-head">
            <div>
              <h1>Convocazioni</h1>
              <p class="sub">Attiva o disattiva i giocatori con un tocco &middot; l'elenco va in PDF pronto da stampare</p>
            </div>
            <button class="btn btn-primary" @click="esportaPDF">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9V6a6 6 0 0112 0v3"/><rect x="4" y="9" width="16" height="12" rx="2"/><path d="M12 14v3"/></svg>
              Esporta PDF
            </button>
          </div>

          <!-- GARE TABS -->
          <div class="gara-tabs" v-if="convocazione.gare.length > 0">
            <button v-for="(g, gi) in convocazione.gare" :key="'t-' + gi" :class="['gtab', { active: gi === activeGaraIdx }]" @click="activeGaraIdx = gi">
              Gara {{ gi + 1 }}<span v-if="g.gara" class="gtab-label"> &middot; {{ g.gara }}</span>
            </button>
          </div>

          <!-- CONV GRID -->
          <div class="conv-grid" v-if="garaAttiva">
            <div class="card">
              <div class="card-h">
                <h2><input v-model="garaAttiva.gara" class="gara-title-inline" :placeholder="nomeSocieta + ' vs Avversario'" /></h2>
                <span class="conv-count">{{ countAssigned(garaAttiva) }} convocati</span>
              </div>
              <ul class="roster">
                <li v-for="(pid, pos) in garaAttiva.giocatori" :key="'r-' + pos" :class="[pid ? (garaAttiva.nonPresenti && garaAttiva.nonPresenti.has(pid) ? 'off' : 'on') : 'empty']">
                  <template v-if="pid">
                    <span class="pnum">{{ pos + 1 }}</span>
                    <span class="pname" @click="openPicker(activeGaraIdx, pos)" title="Cambia giocatore">{{ getPlayerLabel(pid) }}</span>
                    <span class="prole">{{ getPlayerRuolo(pid) }}</span>
                    <button class="toggle" aria-label="attiva/disattiva" @click="switchNonPresente(activeGaraIdx, pid)"></button>
                    <button class="slot-x" title="Rimuovi" @click.stop="rimuoviGiocatore(activeGaraIdx, pos)">&times;</button>
                  </template>
                  <template v-else>
                    <span class="pnum">{{ pos + 1 }}</span>
                    <button class="slot-add" @click="openPicker(activeGaraIdx, pos)">+ Seleziona giocatore</button>
                  </template>
                </li>
              </ul>
              <div class="roster-foot">
                <button class="link-btn" @click="aggiungiSlot(activeGaraIdx)">+ Aggiungi riga</button>
              </div>
            </div>

            <div class="conv-side">
              <div class="card">
                <div class="card-h"><h2>Dettagli gara</h2></div>
                <ul class="info-dl">
                  <li><span class="k">Data</span><span class="v"><input type="date" v-model="garaAttiva.data" /></span></li>
                  <li><span class="k">Campo</span><span class="v"><input v-model="garaAttiva.campo" placeholder="Comunale n.1" /></span></li>
                  <li><span class="k">Indirizzo</span><span class="v"><input v-model="garaAttiva.indirizzo" placeholder="&mdash;" /></span></li>
                  <li><span class="k">Orario Appuntamento</span><span class="v"><input v-model="garaAttiva.appuntamento" placeholder="13:45 &middot; spogliatoi" /></span></li>
                  <li><span class="k">Inizio gara</span><span class="v"><input v-model="garaAttiva.inizio_gara" placeholder="15:00" /></span></li>
                  <li><span class="k">Mister</span>
                    <span class="v">
                      <select v-model="garaAttiva.allenatore">
                        <option value="">&mdash;</option>
                        <option v-for="r in responsabili" :key="r.id" :value="r.cognome">{{ r.cognome }} &middot; {{ r.cellulare }}</option>
                      </select>
                    </span>
                  </li>
                </ul>
              </div>
              <div class="card note-card">
                <div class="note-box">
                  <label>Note per la convocazione</label>
                  <textarea v-model="convocazione.note" rows="5"></textarea>
                  <div class="note-actions">
                    <button class="btn btn-primary" @click="salva">Salva</button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- PLAYER PICKER MODAL -->
          <div v-if="pickerOpen && pickerPos !== null && garaAttiva" class="picker-overlay" @click.self="closePicker">
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
                <div v-for="p in filteredPickerPlayers" :key="p.id" class="picker-item" :class="{ selected: p.id === garaAttiva.giocatori[pickerPos] }" @click="selectPlayer(activeGaraIdx, pickerPos, p.id)">
                  <div class="picker-avatar">{{ p.cognome.charAt(0) }}{{ p.nome.charAt(0) }}</div>
                  <div class="picker-info">
                    <span class="picker-name">{{ p.cognome }}</span>
                    <span class="picker-surname">{{ p.nome }}</span>
                  </div>
                  <div class="picker-check" v-if="p.id === garaAttiva.giocatori[pickerPos]">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </template>

        <div v-if="!convocazione" class="empty-state">
          <div class="empty-icon">&#9917;</div>
          <div class="empty-title">Nessuna convocazione attiva</div>
          <div class="empty-sub">Seleziona un weekend dai chip sopra o crea una nuova convocazione</div>
          <button class="btn btn-primary" @click="nuovaConvocazione()">+ Nuova Convocazione</button>
        </div>
      </main>
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

const nomeSocieta = computed(() => societaAttiva.value?.nome_breve || societaAttiva.value?.nome || 'Noi')

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
const weekendDisponibili = ref([])
const pickerOpen = ref(false)
const pickerGara = ref(null)
const pickerPos = ref(null)
const pickerSearch = ref('')
const activeGaraIdx = ref(0)

const garaAttiva = computed(() => convocazione.value?.gare?.[activeGaraIdx.value] || null)

function todayStr() { return new Date().toISOString().split('T')[0] }

const convocazioniAttive = computed(() =>
  storico.value
    .filter(c => !c.data_fine || c.data_fine >= todayStr())
    .sort((a, b) => a.data_inizio.localeCompare(b.data_inizio))
)

const convocazioniStorico = computed(() =>
  storico.value
    .filter(c => c.data_fine && c.data_fine < todayStr())
    .sort((a, b) => b.data_inizio.localeCompare(a.data_inizio))
)

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
    if (['I', 'AI', 'AG'].includes(r.codice)) assenzeCount[r.persona_id] = (assenzeCount[r.persona_id] || 0) + 1
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
  registro.value.filter(r => r.data >= range.monday && r.data <= range.friday && ['I', 'AI', 'AG'].includes(r.codice)).forEach(r => {
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

function getPlayerLabel(id) {
  const p = persone.value.find(x => x.id === id)
  return p ? getCognomeDisplay(p) : ''
}

function getPlayerRuolo(id) {
  const p = persone.value.find(x => x.id === id)
  return (p && p.ruolo) ? p.ruolo.toUpperCase() : ''
}

function switchNonPresente(garaIdx, personaId) {
  const gara = convocazione.value.gare[garaIdx]
  if (!gara.nonPresenti) gara.nonPresenti = new Set()
  if (gara.nonPresenti.has(personaId)) gara.nonPresenti.delete(personaId)
  else gara.nonPresenti.add(personaId)
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
  const pid = gara.giocatori[pos]
  if (pid && gara.nonPresenti) gara.nonPresenti.delete(pid)
  gara.giocatori.splice(pos, 1)
}

function aggiungiSlot(garaIdx) {
  convocazione.value.gare[garaIdx].giocatori.push(null)
}

function toggleNonPresente(garaIdx, personaId, event) {
  const gara = convocazione.value.gare[garaIdx]
  if (!gara.nonPresenti) gara.nonPresenti = new Set()
  if (event.target.checked) {
    gara.nonPresenti.add(personaId)
  } else {
    gara.nonPresenti.delete(personaId)
  }
}

function aggiustaGare() {
  const n = numPartite.value
  const gare = convocazione.value.gare
  while (gare.length < n) gare.push(garaVuota(gare.length + 1))
   if (gare.length > n) gare.splice(n)
  if (activeGaraIdx.value >= gare.length) activeGaraIdx.value = Math.max(0, gare.length - 1)
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
  return { numero, gara: '', data: '', campo: '', indirizzo: '', appuntamento: '', inizio_gara: '', allenatore: '', giocatori: Array(10).fill(null), nonPresenti: new Set() }
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
    allenatore: getMisterCognome(p.mister_id), giocatori: Array(10).fill(null), nonPresenti: new Set()
  })) : [garaVuota(1)]
  numPartite.value = gare.length
  activeGaraIdx.value = 0
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
    allenatore: getMisterCognome(p.mister_id), giocatori: Array(10).fill(null), nonPresenti: new Set()
  }))
  convocazione.value.gare = gare
  numPartite.value = gare.length
  if (activeGaraIdx.value >= gare.length) activeGaraIdx.value = 0
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
    gare: d.gare.map((g, idx) => {
      const giocatoriArr = (g.giocatori || []).sort((a, b) => a.posizione - b.posizione)
      const nonPresenti = new Set(giocatoriArr.filter(x => x.non_presente).map(x => x.persona_id))
      return {
        ...g, numero: g.numero || idx + 1, data: g.data || '',
        giocatori: padGiocatori(giocatoriArr.map(x => x.persona_id)), nonPresenti
      }
    })
  }
  numPartite.value = convocazione.value.gare.length
  activeGaraIdx.value = 0
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
    inizio_gara: p.ora ? p.ora.slice(0, 5) : '', allenatore: getMisterCognome(p.mister_id), giocatori: Array(10).fill(null), nonPresenti: new Set()
  }))
  numPartite.value = gare.length
  activeGaraIdx.value = 0
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
      giocatori: g.giocatori.map((pid, i) => pid ? { persona_id: pid, posizione: i + 1, non_presente: g.nonPresenti?.has(pid) || false } : null).filter(Boolean)
    }))
  }
  if (convocazioneId.value) await axios.put(base + '/convocazioni/' + convocazioneId.value, payload, { headers: headers() })
  else { const res = await axios.post(base + '/convocazioni/', payload, { headers: headers() }); convocazioneId.value = res.data.id }
  await loadStorico()
  await loadWeekendDisponibili()
  alert('Salvato!')
}

function esc(s) {
  if (s == null) return ''
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
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
      const np = filled && gara.nonPresenti?.has(pid)
      return `<div style="display:flex;align-items:center;gap:8px;padding:4px 0;${i < 13 ? 'border-bottom:1px solid #f0f0f0;' : ''}">
        <span style="min-width:22px;height:22px;border-radius:50%;background:${np ? '#ef4444' : (filled ? '#dc2626' : '#f0f0f0')};color:#fff;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:800;flex-shrink:0;">${i + 1}</span>
        <span style="font-size:12px;font-weight:${filled ? '700' : '400'};color:${np ? '#ef4444' : (filled ? '#1a1a1a' : '#ccc')};flex:1;${np ? 'text-decoration:line-through;opacity:0.7;' : ''}">${esc(nome)}${np ? ' (NP)' : ''}</span>
      </div>`
    }).join('')

    return `<div style="background:#fff;border:2px solid #1a1a1a;border-radius:12px;overflow:hidden;box-shadow:4px 4px 0 #1a1a1a;">
      <div style="background:#1a1a1a;color:#fff;padding:12px 16px;display:flex;align-items:center;gap:10px;">
        <span style="font-size:28px;font-weight:900;line-height:1;">${idx + 1}</span>
        <div style="flex:1;">
          <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#dc2626;font-weight:700;">Gara ${idx + 1}</div>
          <div style="font-size:14px;font-weight:800;letter-spacing:0.5px;">${esc(gara.gara || '—')}</div>
        </div>
      </div>
      <div style="padding:12px 16px;background:#fafafa;border-bottom:1px solid #eee;">
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px 16px;">
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Data</span><br><span style="font-weight:700;color:#1a1a1a;">${esc(formatD(gara.data))}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Campo</span><br><span style="font-weight:700;color:#1a1a1a;">${esc(gara.campo || '—')}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Indirizzo</span><br><span style="font-weight:700;color:#1a1a1a;">${esc(gara.indirizzo || '—')}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Appuntamento</span><br><span style="font-weight:700;color:#1a1a1a;">${esc(gara.appuntamento || '—')}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Inizio Gara</span><br><span style="font-weight:700;color:#1a1a1a;">${esc(gara.inizio_gara || '—')}</span></div>
          <div style="font-size:11px;"><span style="color:#999;text-transform:uppercase;letter-spacing:0.5px;">Allenatore</span><br><span style="font-weight:700;color:#1a1a1a;">${esc(gara.allenatore || '—')}</span></div>
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
      <div style="position:absolute;top:0;left:0;right:0;bottom:0;background:repeating-linear-gradient(90deg,transparent,transparent 40px,var(--color-surface) 40px,var(--color-surface) 41px);pointer-events:none;"></div>
      <div style="display:flex;align-items:center;justify-content:center;gap:20px;position:relative;z-index:1;">
        <img src="${societaAttiva.value?.logosponsor ? '/uploads/' + societaAttiva.value.logosponsor : '/logosponsor.png'}" style="height:60px;width:60px;object-fit:contain;border-radius:50%;background:#fff;padding:4px;" />
        <div>
          <div style="font-size:10px;letter-spacing:4px;text-transform:uppercase;color:#dc2626;font-weight:700;margin-bottom:4px;">Convocazione Gare</div>
          <div style="font-size:28px;font-weight:900;letter-spacing:3px;line-height:1;">${esc(societaAttiva.value?.nome || 'SQUADRA')}</div>
          <div style="font-size:16px;font-weight:700;color:#dc2626;margin-top:6px;letter-spacing:1px;">${esc(categoriaAttiva.value?.nome || '')} ${esc(categoriaAttiva.value?.anno || '')}</div>
          <div style="font-size:11px;color:#999;margin-top:4px;letter-spacing:1px;">${esc(formatD(convocazione.value.data_inizio))}${convocazione.value.data_fine ? ' — ' + esc(formatD(convocazione.value.data_fine)) : ''}</div>
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
      <div style="font-size:10px;color:#666;line-height:1.6;white-space:pre-wrap;">${esc(convocazione.value.note)}</div>
    </div>` : ''}
    <div style="text-align:center;padding:12px;border-top:2px solid #1a1a1a;margin-top:0;">
      <span style="font-size:9px;letter-spacing:2px;text-transform:uppercase;color:#ccc;">${esc(societaAttiva.value?.nome || '')} — Stagione ${esc(stagioneTxt)}</span>
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
  if (convocazioniAttive.value.length > 0) await caricaConvocazione(convocazioniAttive.value[0].id)
})
</script>

<style scoped>
/* ============================================
   DESIGN SYSTEM — Light operational theme (demo)
   ============================================ */

.conv-page {
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100%;
  max-width: none;
  background: var(--color-bg);
  color: var(--color-text);
}

/* ---- PAGE HEADER ---- */
.page-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1.25rem;
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  flex-shrink: 0;
}

.header-left { display: flex; align-items: center; gap: 0.25rem; }

.icon-btn {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all 0.2s;
}
.icon-btn:hover { background: var(--color-bg); color: var(--color-text); }
.icon-btn svg { width: 18px; height: 18px; }

.header-center { flex: 1; display: flex; flex-direction: column; gap: 0; }

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
  color: var(--color-text);
  letter-spacing: 0.02em;
  line-height: 1.2;
}

.header-right { display: flex; align-items: center; }

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
.btn svg { width: 15px; height: 15px; }

.btn-primary { background: #dc2626; color: #fff; }
.btn-primary:hover { background: #b91c1c; transform: translateY(-1px); }

.btn-ghost {
  background: var(--color-surface);
  color: var(--color-text-secondary);
  border-color: var(--color-border);
}
.btn-ghost:hover { background: var(--color-bg); color: var(--color-text); }

.btn-danger {
  background: rgba(220, 38, 38, 0.08);
  color: #dc2626;
  border-color: rgba(220, 38, 38, 0.35);
}
.btn-danger:hover { background: #dc2626; color: #fff; }

/* ---- BODY LAYOUT ---- */
.conv-body { display: flex; flex: 1; overflow: hidden; min-height: 0; }

.editor {
  flex: 1;
  overflow-y: auto;
  padding: 1.25rem;
  background: var(--color-bg);
  min-width: 0;
}

/* ---- TOPBAR date + azioni ---- */
.editor-topbar {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  flex-wrap: wrap;
  margin-bottom: 1rem;
  padding: 0.85rem 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 12px;
}

.date-pickers { display: flex; align-items: flex-end; gap: 0.75rem; }

.date-field { display: flex; flex-direction: column; gap: 0.25rem; }
.date-field label {
  font-size: 0.55rem;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.date-field input {
  padding: 0.4rem 0.6rem;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  background: var(--color-bg);
  color: var(--color-text);
  font-size: 0.8rem;
  outline: none;
  transition: border-color 0.2s;
}
.date-field input:focus { border-color: #dc2626; }

.num-input { width: 56px !important; text-align: center; }

.editor-actions { display: flex; gap: 0.5rem; margin-left: auto; }

/* ---- ALERT BOX (non convocabili) ---- */
.alert-box {
  background: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.25);
  border-radius: 8px;
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}
.alert-icon { font-size: 0.9rem; }
.alert-label { font-size: 0.75rem; font-weight: 700; color: #92400e; letter-spacing: 0.05em; }
.alert-period { font-size: 0.7rem; color: #a16207; }
.alert-tag {
  background: rgba(220, 38, 38, 0.1);
  color: #b91c1c;
  padding: 3px 10px;
  border-radius: 12px;
  font-size: 0.7rem;
  font-weight: 600;
}
.alert-none { font-size: 0.75rem; color: var(--color-text-muted); }

/* ---- ESCLUSIONI ---- */
.esclusioni-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 0.75rem;
  margin-bottom: 1rem;
}
.esclusione-panel {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 0.75rem;
}
.esclusione-panel-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
.esclusione-panel-title { font-size: 0.6rem; font-weight: 700; letter-spacing: 0.08em; color: var(--color-text-muted); }
.esclusione-select {
  font-size: 0.7rem;
  padding: 3px 6px;
  border: 1px solid var(--color-border);
  border-radius: 4px;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  max-width: 130px;
  outline: none;
}
.esclusione-tags { display: flex; flex-wrap: wrap; gap: 4px; }
.esclusione-tag {
  background: var(--color-bg);
  color: var(--color-text-secondary);
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 0.65rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
}
.esclusione-tag:hover { background: #dc2626; color: #fff; }
.esclusione-none { font-size: 0.65rem; color: var(--color-text-muted); }

/* ---- PAGE HEAD (demo) ---- */
.page-head {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
  margin-bottom: 18px;
}
.page-head h1 { font-size: clamp(1.25rem, 2.6vw, 1.55rem); font-weight: 800; letter-spacing: -0.02em; }
.page-head .sub { color: var(--color-text-muted); font-size: 0.86rem; margin-top: 2px; }

/* ---- WEEKEND CHIPS (demo) ---- */
.weekend-chips {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
  margin-bottom: 14px;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.weekend-chips::-webkit-scrollbar { display: none; }
.wk {
  flex-shrink: 0;
  padding: 7px 14px;
  border-radius: 999px;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  font-family: var(--font-mono, monospace);
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all 0.15s;
  white-space: nowrap;
}
.wk:hover { border-color: var(--color-text); color: var(--color-text); }
.wk.active { background: var(--color-text); border-color: var(--color-text); color: #fff; }
.wk-new { border-style: dashed; color: #dc2626; border-color: rgba(220, 38, 38, 0.4); background: transparent; }
.wk-new:hover { border-color: #dc2626; background: rgba(220, 38, 38, 0.05); color: #dc2626; }

/* ---- STORICO ---- */
.storico-section { margin-bottom: 14px; }
.storico-title {
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: var(--color-text-muted);
  margin-bottom: 6px;
}
.storico-chips {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.storico-chips::-webkit-scrollbar { display: none; }
.wk-storico { opacity: 0.6; }
.wk-storico:hover { opacity: 1; }
.wk-storico.active { opacity: 1; }

/* ---- MISTER ---- */
.mister-section { margin-bottom: 14px; }
.mister-title {
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: var(--color-text-muted);
  margin-bottom: 6px;
}
.mister-list {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  overflow: hidden;
}
.mister-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 0.6rem 0.9rem;
  border-bottom: 1px solid var(--color-border-light);
  font-size: 0.85rem;
}
.mister-row:last-child { border-bottom: none; }
.mister-row .mister-name { color: var(--color-text); font-weight: 600; }
.mister-row .mister-tel { color: var(--color-text-muted); font-family: var(--font-mono, monospace); }

/* ---- GARA TABS ---- */
.gara-tabs { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 14px; }
.gtab {
  padding: 7px 16px;
  border-radius: 10px;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all 0.15s;
  max-width: 320px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.gtab:hover { border-color: var(--color-text); color: var(--color-text); }
.gtab.active { background: #dc2626; border-color: #dc2626; color: #fff; }
.gtab-label { font-weight: 500; opacity: 0.85; }

/* ---- CONV GRID + CARD (demo) ---- */
.conv-grid { display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr); gap: 14px; align-items: start; }

.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 14px;
  overflow: hidden;
}
.card-h {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 13px 18px;
  border-bottom: 1px solid var(--color-border-light);
}
.card-h h2 { font-size: 0.95rem; font-weight: 800; letter-spacing: -0.01em; min-width: 0; flex: 1; }

.gara-title-inline {
  width: 100%;
  border: none;
  background: transparent;
  font-family: inherit;
  font-size: 0.95rem;
  font-weight: 800;
  color: var(--color-text);
  outline: none;
  padding: 4px 6px;
  border-radius: 6px;
}
.gara-title-inline:focus { background: var(--color-bg); box-shadow: inset 0 -2px 0 #dc2626; }

.conv-count {
  font-family: var(--font-mono, monospace);
  font-size: 0.72rem;
  font-weight: 700;
  background: rgba(220, 38, 38, 0.08);
  color: #b91c1c;
  border-radius: 999px;
  padding: 3px 10px;
  white-space: nowrap;
  flex-shrink: 0;
}

/* ---- ROSTER (demo) ---- */
.roster { list-style: none; margin: 0; padding: 0; }
.roster li {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 16px;
  border-bottom: 1px solid var(--color-border-light);
  transition: opacity 0.15s ease;
}
.roster li:last-child { border-bottom: none; }

.pnum {
  font-family: var(--font-mono, monospace);
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.66rem;
  font-weight: 700;
  background: var(--color-bg);
  color: var(--color-text-muted);
  flex-shrink: 0;
}
li.on .pnum { background: #dc2626; color: #fff; }

.pname { font-weight: 600; font-size: 0.89rem; cursor: pointer; }
.pname:hover { text-decoration: underline; text-decoration-color: var(--color-text-muted); }
.prole {
  font-family: var(--font-mono, monospace);
  font-size: 0.6rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  color: var(--color-text-muted);
}

.toggle {
  margin-left: auto;
  width: 36px;
  height: 20px;
  border-radius: 999px;
  background: #d3d9e3;
  border: none;
  position: relative;
  cursor: pointer;
  transition: background 0.2s;
  flex-shrink: 0;
}
.toggle::after {
  content: '';
  position: absolute;
  top: 2px;
  left: 2px;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 1px 3px rgba(22, 24, 29, 0.25);
  transition: left 0.2s;
}
li.on .toggle { background: #15803d; }
li.on .toggle::after { left: 18px; }
li.off .pname { color: var(--color-text-muted); text-decoration: line-through; }
li.off .pnum { background: rgba(220, 38, 38, 0.12); color: #b91c1c; }

.slot-x {
  border: none;
  background: transparent;
  color: var(--color-text-muted);
  font-size: 1rem;
  line-height: 1;
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 6px;
  opacity: 0;
  transition: opacity 0.15s, all 0.15s;
}
.roster li:hover .slot-x { opacity: 1; }
.slot-x:hover { color: #dc2626; background: rgba(220, 38, 38, 0.08); }

.slot-add {
  border: 1px dashed var(--color-border);
  background: transparent;
  border-radius: 8px;
  padding: 4px 12px;
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--color-text-muted);
  cursor: pointer;
  transition: all 0.15s;
}
.slot-add:hover { border-color: #dc2626; color: #dc2626; background: rgba(220, 38, 38, 0.04); }

.roster-foot { padding: 10px 16px; border-top: 1px solid var(--color-border-light); }
.link-btn {
  border: none;
  background: transparent;
  color: #dc2626;
  font-size: 0.75rem;
  font-weight: 700;
  cursor: pointer;
  padding: 2px 4px;
}
.link-btn:hover { text-decoration: underline; }

/* ---- DETTAGLI GARA (demo info-dl editabile) ---- */
.conv-side { display: flex; flex-direction: column; gap: 14px; }

.info-dl { list-style: none; margin: 0; padding: 0; }
.info-dl li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 14px;
  padding: 9px 18px;
  border-bottom: 1px solid var(--color-border-light);
  font-size: 0.87rem;
}
.info-dl li:last-child { border-bottom: none; }
.info-dl .k { color: var(--color-text-muted); font-weight: 600; font-size: 0.8rem; flex: none; }
.info-dl .v { flex: 1; display: flex; justify-content: flex-end; min-width: 0; }
.info-dl .v input,
.info-dl .v select {
  width: 100%;
  max-width: 210px;
  border: none;
  border-bottom: 1px dashed transparent;
  background: transparent;
  text-align: right;
  font-family: inherit;
  font-size: 0.84rem;
  font-weight: 600;
  color: var(--color-text);
  padding: 3px 4px;
  outline: none;
  transition: border-color 0.15s, background 0.15s;
}
.info-dl .v input::placeholder { color: var(--color-text-muted); font-weight: 400; }
.info-dl .v input:focus,
.info-dl .v select:focus { border-bottom: 1px dashed #dc2626; background: var(--color-bg); }

.note-card { margin-top: 0; }
.note-box { padding: 14px 18px; }
.note-box label {
  display: block;
  font-size: 0.76rem;
  font-weight: 700;
  color: var(--color-text-muted);
  margin-bottom: 7px;
}
.note-box textarea {
  width: 100%;
  box-sizing: border-box;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  background: var(--color-bg);
  color: var(--color-text);
  padding: 10px 12px;
  font-family: inherit;
  font-size: 0.82rem;
  line-height: 1.45;
  resize: vertical;
  outline: none;
  transition: border-color 0.15s;
}
.note-box textarea:focus { border-color: #dc2626; }
.note-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 10px; }

/* ---- EMPTY STATE ---- */
.empty-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  color: var(--color-text-muted);
}
.empty-icon { font-size: 3rem; opacity: 0.3; }
.empty-title { font-size: 1.25rem; font-weight: 700; color: var(--color-text-secondary); }
.empty-sub { font-size: 0.85rem; margin-bottom: 0.5rem; }

/* ---- PLAYER PICKER MODAL ---- */
.picker-overlay {
  position: fixed;
  inset: 0;
  background: rgba(22, 24, 29, 0.45);
  z-index: 300;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn 0.15s ease-out;
  backdrop-filter: blur(6px);
}
.picker-modal {
  width: 340px;
  max-height: 80vh;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  animation: scaleIn 0.2s ease-out;
  overflow: hidden;
  box-shadow: 0 24px 48px rgba(22, 24, 29, 0.25);
}
.picker-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--color-border-light);
  background: var(--color-surface);
}
.picker-title { display: flex; align-items: center; gap: 0.5rem; }
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
.picker-title span:last-child { font-size: 0.85rem; font-weight: 700; color: var(--color-text); }
.picker-close {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: var(--color-bg);
  border-radius: 6px;
  color: var(--color-text-muted);
  cursor: pointer;
  transition: all 0.15s;
}
.picker-close:hover { background: var(--color-border-light); color: var(--color-text); }
.picker-close svg { width: 14px; height: 14px; }
.picker-search {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  border-bottom: 1px solid var(--color-border-light);
}
.picker-search svg { width: 16px; height: 16px; color: var(--color-text-muted); flex-shrink: 0; }
.picker-search input {
  flex: 1;
  border: none;
  background: none;
  color: var(--color-text);
  font-size: 0.85rem;
  outline: none;
  font-family: inherit;
}
.picker-search input::placeholder { color: var(--color-text-muted); }
.picker-list { flex: 1; overflow-y: auto; padding: 0.5rem; }
.picker-empty { text-align: center; padding: 2rem 1rem; color: var(--color-text-muted); font-size: 0.8rem; }
.picker-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.6rem 0.75rem;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.12s;
}
.picker-item:hover { background: var(--color-bg); }
.picker-item.selected { background: rgba(220, 38, 38, 0.08); }
.picker-avatar {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: var(--color-bg);
  color: var(--color-text-secondary);
  font-size: 0.65rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  letter-spacing: 0.02em;
}
.picker-item.selected .picker-avatar { background: #dc2626; color: #fff; }
.picker-info { flex: 1; display: flex; flex-direction: column; min-width: 0; }
.picker-name { font-size: 0.82rem; font-weight: 700; color: var(--color-text); }
.picker-surname { font-size: 0.7rem; color: var(--color-text-muted); }
.picker-check { color: #dc2626; flex-shrink: 0; }
.picker-check svg { width: 16px; height: 16px; }

/* ---- ANIMATIONS ---- */
@keyframes slideInLeft {
  from { transform: translateX(-100%); }
  to { transform: translateX(0); }
}
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.96); }
  to { opacity: 1; transform: scale(1); }
}

/* ---- RESPONSIVE ---- */
@media (max-width: 1024px) {
  .conv-grid { grid-template-columns: 1fr; }
}
@media (max-width: 768px) {
  .conv-body { flex-direction: column; }
  .editor { padding: 0.85rem; }
  .editor-topbar { flex-direction: column; align-items: stretch; gap: 0.75rem; }
  .date-pickers { flex-wrap: wrap; }
  .editor-actions { margin-left: 0; justify-content: flex-end; }
  .esclusioni-grid { grid-template-columns: 1fr; }
  .header-center { flex-direction: column; gap: 0; }
  .header-label { font-size: 0.5rem; }
  .header-category { font-size: 0.85rem; }
  .roster li { padding: 8px 10px; gap: 8px; }
  .pname { font-size: 0.8rem; }
  .slot-x { opacity: 1; }
  .picker-modal { width: 95vw; max-width: 340px; }
  .info-dl li { padding: 8px 12px; }
}
</style>

