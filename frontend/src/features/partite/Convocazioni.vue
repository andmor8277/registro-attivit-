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
          <div class="mister-title">Responsabili</div>
          <div class="mister-list">
            <div v-for="r in responsabili" :key="r.id" class="mister-row">
              <span class="mister-name">{{ r.cognome }} {{ r.nome }}</span>
              <span class="mister-tel">{{ r.cellulare }}</span>
            </div>
          </div>
        </div>

        <!-- PAGAMENTI NON IN REGOLA -->
        <div class="alert-box pagamenti-box" :class="{ 'ok': giocatoriNonInRegola.length === 0 }">
          <span class="alert-icon">{{ giocatoriNonInRegola.length ? '⚠️' : '✅' }}</span>
          <span class="alert-label">PAGAMENTI</span>
          <span v-for="p in giocatoriNonInRegola" :key="p.id" class="alert-tag tag-non-regola">{{ p.cognome }} {{ p.nome }}</span>
          <span v-if="giocatoriNonInRegola.length === 0" class="alert-none">Tutti in regola</span>
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
            <span v-for="p in nonConvocabili" :key="p.id" class="alert-tag" :class="{ 'tag-cert': p.motivi.includes('cert_scaduto') || p.motivi.includes('senza_cert') }" :title="labelMotivi(p.motivi)">{{ p.cognome }} {{ p.nome }}<small v-if="p.motivi.includes('cert_scaduto')">cert. scaduto</small><small v-else-if="p.motivi.includes('senza_cert')">senza cert.</small></span>
            <span v-if="nonConvocabili.length === 0" class="alert-none">Nessuno</span>
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
            <button v-if="puoScouting" class="btn btn-ghost" :disabled="!convocazioneId || !garaAttiva?.id" @click="apriScouting" title="Crea segnalazione scouting per questa gara">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
              Scouting
            </button>
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
                      <div class="mister-checkboxes">
                        <label class="mister-option" v-for="r in responsabili" :key="r.id">
                          <input type="checkbox" :checked="garaAttiva.allenatori.includes(r.id)" @change="toggleAllenatore(garaAttiva, r.id)" />
                          <span>{{ r.cognome }} &middot; {{ r.cellulare }}</span>
                        </label>
                        <span v-if="responsabili.length === 0" class="mister-empty">&mdash;</span>
                      </div>
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
                    <div class="picker-name-row">
                      <span class="picker-name">{{ p.cognome }}</span>
                      <span v-if="getPlayerWarning(p)" class="picker-warning" :title="getPlayerWarningTitle(p)">{{ getPlayerWarning(p) }}</span>
                    </div>
                    <span class="picker-surname">{{ p.nome }}</span>
                  </div>
                  <div class="picker-check" v-if="p.id === garaAttiva.giocatori[pickerPos]">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- SCOUTING MODAL -->
          <div v-if="scoutingModal.open" class="scout-overlay" @click.self="scoutingModal.open = false">
            <div class="scout-modal">
              <div class="scout-header">
                <h3>Segnalazione Scouting</h3>
                <button class="scout-close" @click="scoutingModal.open = false">&times;</button>
              </div>
              <div class="scout-form">
                <div class="scout-field">
                  <label>Titolo</label>
                  <input v-model="scoutingModal.titolo" placeholder="Es. Rilevamento attaccanti" />
                </div>
                <div class="scout-row">
                  <div class="scout-field">
                    <label>Data osservazione</label>
                    <input type="date" v-model="scoutingModal.data_osservazione" />
                  </div>
                  <div class="scout-field">
                    <label>Squadra avversaria</label>
                    <input v-model="scoutingModal.squadra_avversaria" placeholder="Avversario" />
                  </div>
                </div>
                <div class="scout-field">
                  <label>Note</label>
                  <textarea v-model="scoutingModal.note" rows="3" placeholder="Note generali sulla squadra avversaria..."></textarea>
                </div>
                <div class="scout-players">
                  <div class="scout-players-header">
                    <span>Giocatori da segnalare</span>
                    <button type="button" class="btn btn-ghost btn-sm" @click="aggiungiGiocatoreScouting">+ Aggiungi</button>
                  </div>
                  <div v-for="(g, gi) in scoutingModal.giocatori" :key="'sg-' + gi" class="scout-player-row">
                    <input v-model="g.nome" placeholder="Nome" class="scout-nome" />
                    <input v-model="g.cognome" placeholder="Cognome" class="scout-cognome" />
                    <input v-model="g.ruolo" placeholder="Ruolo" class="scout-ruolo" />
                    <input v-model.number="g.numero_maglia" type="number" min="1" max="99" placeholder="N°" class="scout-num" />
                    <button type="button" class="scout-remove" @click="rimuoviGiocatoreScouting(gi)" title="Rimuovi">&times;</button>
                  </div>
                  <p v-if="scoutingModal.giocatori.length === 0" class="scout-empty">Nessun giocatore aggiunto</p>
                </div>
                <div class="scout-actions">
                  <button class="btn btn-ghost" @click="scoutingModal.open = false">Annulla</button>
                  <button class="btn btn-primary" :disabled="scoutingModal.loading" @click="inviaScouting">
                    {{ scoutingModal.loading ? 'Invio...' : 'Invia a Scouting' }}
                  </button>
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
import { useStore } from '../../store.js'
import { getPersone, getRegistroMese, getPartite, getCategoriaResponsabili, getWeekend, getWeekendPartite, creaSegnalazioneScouting } from '../../api/index.js'
import axios from 'axios'
import { jsPDF } from 'jspdf'
import 'jspdf-autotable'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva, societaAttiva, stagioneCorrente, utenteAttivo } = useStore()
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
const scoutingModal = ref({ open: false, loading: false, titolo: '', data_osservazione: '', squadra_avversaria: '', note: '', giocatori: [] })

const garaAttiva = computed(() => convocazione.value?.gare?.[activeGaraIdx.value] || null)
const puoScouting = computed(() => ['mister', 'admin', 'super_admin'].includes(utenteAttivo.value?.ruolo))

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
  const gara = pickerGara.value !== null ? convocazione.value?.gare?.[pickerGara.value] : null
  const currentId = gara && pickerPos.value !== null ? gara.giocatori[pickerPos.value] : null
  const assignedInGara = new Set((gara?.giocatori || []).filter(Boolean))
  const available = persone.value
    .filter(p => p.id === currentId || !assignedInGara.has(p.id))
    .sort((a, b) => a.cognome.localeCompare(b.cognome))
  if (!pickerSearch.value) return available
  const s = pickerSearch.value.toLowerCase()
  return available.filter(p => p.cognome.toLowerCase().includes(s) || p.nome.toLowerCase().includes(s))
})

const giocatoriNonInRegola = computed(() =>
  persone.value
    .filter(p => p.pagamenti_in_regola === false)
    .sort((a, b) => a.cognome.localeCompare(b.cognome))
)

const oggi = new Date()
const annoCorrente = oggi.getFullYear()
const meseCorrente = oggi.getMonth() + 1
const registroMesiCaricate = new Set()

function parseLocalDate(value) {
  const [y, m, d] = value.split('-').map(Number)
  return new Date(y, m - 1, d)
}

function formatLocalDate(date) {
  return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, '0'), String(date.getDate()).padStart(2, '0')].join('-')
}

function getPickerReferenceDate() {
  const gara = pickerGara.value !== null ? convocazione.value?.gare?.[pickerGara.value] : null
  return gara?.data || convocazione.value?.data_inizio || null
}

const pickerStats = computed(() => {
  const referenceDate = getPickerReferenceDate()
  const range = getWeekDateRange(referenceDate)
  if (!range) return {}
  const stats = {}
  registro.value
    .filter(r => r.data >= range.monday && r.data <= range.friday)
    .forEach(r => {
      if (!stats[r.persona_id]) stats[r.persona_id] = { presenze: 0, assenze: 0 }
      if (['X', 'P', 'R'].includes(r.codice)) stats[r.persona_id].presenze += 1
      if (['I', 'AI', 'AG'].includes(r.codice)) stats[r.persona_id].assenze += 1
    })
  return stats
})

function getPlayerWarning(player) {
  const referenceDate = getPickerReferenceDate()
  if (!referenceDate) return ''
  const stats = pickerStats.value[player.id] || { presenze: 0, assenze: 0 }
  if (stats.presenze >= 2 && stats.assenze < 2) return ''
  return `${stats.presenze}P · ${stats.assenze}A`
}

function getPlayerWarningTitle(player) {
  const stats = pickerStats.value[player.id] || { presenze: 0, assenze: 0 }
  return `Settimana precedente: ${stats.presenze} presenze, ${stats.assenze} assenze`
}

async function caricaRegistroMese(anno, mese) {
  const key = `${anno}-${String(mese).padStart(2, '0')}`
  if (registroMesiCaricate.has(key)) return
  const res = await getRegistroMese(categoriaId, anno, mese)
  const existing = new Set(registro.value.map(r => r.id ?? `${r.persona_id}|${r.data}|${r.categoria_id}`))
  registro.value = [
    ...registro.value,
    ...(res.data || []).filter(r => !existing.has(r.id ?? `${r.persona_id}|${r.data}|${r.categoria_id}`))
  ]
  registroMesiCaricate.add(key)
}

async function ensureRegistroPerData(dataStr) {
  if (!dataStr) return
  const range = getWeekDateRange(dataStr)
  if (!range) return
  const months = new Set([range.monday, range.friday].map(ds => {
    const [y, m] = ds.split('-').map(Number)
    return `${y}-${m}`
  }))
  for (const monthKey of months) {
    const [y, m] = monthKey.split('-').map(Number)
    try {
      await caricaRegistroMese(y, m)
    } catch (e) {
      console.warn('Registro mese non caricato per avviso presenze', e)
    }
  }
}

function getWeekDateRange(dataGara) {
  if (!dataGara) return null
  const data = parseLocalDate(dataGara)
  const dow = data.getDay()
  const daysSinceMonday = dow === 0 ? 6 : dow - 1
  const mondayPrev = new Date(data)
  mondayPrev.setDate(data.getDate() - daysSinceMonday)
  const fridayPrev = new Date(mondayPrev)
  fridayPrev.setDate(mondayPrev.getDate() + 4)
  return {
    monday: formatLocalDate(mondayPrev),
    friday: formatLocalDate(fridayPrev),
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

function dateRiferimentoCertificato() {
  if (!convocazione.value) return []
  const dateGare = (convocazione.value.gare || [])
    .map(g => g.data)
    .filter(Boolean)
    .map(d => String(d).slice(0, 10))
  if (dateGare.length > 0) return [...new Set(dateGare)]
  return [convocazione.value.data_inizio, convocazione.value.data_fine]
    .filter(Boolean)
    .map(d => String(d).slice(0, 10))
}

function statoCertificato(p) {
  const dates = dateRiferimentoCertificato()
  if (dates.length === 0) return null
  const scadenza = p.scadenza_certificato ? String(p.scadenza_certificato).slice(0, 10) : null
  if (!scadenza) return 'senza_cert'
  if (dates.some(d => scadenza < d)) return 'cert_scaduto'
  return null
}

function labelMotivi(motivi) {
  return (motivi || [])
    .map(m => {
      if (m === 'assenze') return 'Almeno 2 assenze Lun-Ven'
      if (m === 'cert_scaduto') return 'Certificato medico scaduto per la data gara/convocazione'
      if (m === 'senza_cert') return 'Certificato medico non presente'
      return m
    })
    .join(' · ')
}

const nonConvocabili = computed(() => {
  const map = new Map()
  for (const p of getAllEsclusi()) {
    map.set(p.id, { ...p, motivi: ['assenze'] })
  }
  for (const p of persone.value) {
    const stato = statoCertificato(p)
    if (!stato) continue
    const existing = map.get(p.id)
    if (existing) {
      if (!existing.motivi.includes(stato)) existing.motivi.push(stato)
    } else {
      map.set(p.id, { ...p, motivi: [stato] })
    }
  }
  return [...map.values()].sort((a, b) => a.cognome.localeCompare(b.cognome))
})

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

function toggleAllenatore(gara, personaId) {
  if (!Array.isArray(gara.allenatori)) gara.allenatori = []
  const idx = gara.allenatori.indexOf(personaId)
  if (idx >= 0) gara.allenatori.splice(idx, 1)
  else gara.allenatori.push(personaId)
}

async function openPicker(garaIdx, pos) {
  pickerGara.value = garaIdx
  pickerPos.value = pos
  pickerSearch.value = ''
  const gara = convocazione.value?.gare?.[garaIdx]
  await ensureRegistroPerData(gara?.data || convocazione.value?.data_inizio)
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
  const alreadyInOtherSlot = gara.giocatori.some((id, idx) => id === playerId && idx !== pos)
  if (playerId && alreadyInOtherSlot) return
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
  return { numero, gara: '', data: '', campo: '', indirizzo: '', appuntamento: '', inizio_gara: '', allenatore: '', allenatori: [], giocatori: Array(10).fill(null), nonPresenti: new Set() }
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

function trovaResponsabileDaNome(nome) {
  const clean = String(nome || '').trim().toLowerCase()
  if (!clean) return null
  return responsabili.value.find(r =>
    r.cognome?.toLowerCase() === clean ||
    `${r.cognome} ${r.nome}`.trim().toLowerCase() === clean ||
    `${r.nome} ${r.cognome}`.trim().toLowerCase() === clean
  ) || null
}

function inferisciAllenatori(gara) {
  if (Array.isArray(gara?.allenatori) && gara.allenatori.length) return gara.allenatori
  if (!gara?.allenatore) return []
  return gara.allenatore
    .split(',')
    .map(s => trovaResponsabileDaNome(s)?.id)
    .filter(Boolean)
}

function getAllenatoriLabel(gara) {
  const ids = inferisciAllenatori(gara)
  if (ids.length) {
    const label = ids
      .map(id => {
        const m = responsabili.value.find(r => r.id === id)
        if (!m) return ''
        return m.cellulare ? `${m.cognome} (${m.cellulare})` : m.cognome
      })
      .filter(Boolean)
      .join(', ')
    if (label) return label
  }
  return gara?.allenatore || ''
}

function getAllenatoriLabelCompatta(gara) {
  const ids = inferisciAllenatori(gara)
  if (ids.length) {
    const label = ids
      .map(id => responsabili.value.find(r => r.id === id)?.cognome)
      .filter(Boolean)
      .join(', ')
    if (label) return label
  }
  return gara?.allenatore || ''
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
    allenatore: getMisterCognome(p.mister_id), allenatori: p.mister_id ? [p.mister_id] : [], giocatori: Array(10).fill(null), nonPresenti: new Set()
  })) : [garaVuota(1)]
  numPartite.value = gare.length
  activeGaraIdx.value = 0
  convocazione.value = {
    data_inizio: dataInizio, data_fine: dataFine, esclusioni: [],
    note: `PRESENTARSI ALL'APPUNTAMENTO IN ORARIO STABILITO ED IN TENUTA DA RAPPRESENTANZA MACRON (NO GIA CAMBIATI).
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
    allenatore: getMisterCognome(p.mister_id), allenatori: p.mister_id ? [p.mister_id] : [], giocatori: Array(10).fill(null), nonPresenti: new Set()
  }))
  convocazione.value.gare = gare
  numPartite.value = gare.length
  if (activeGaraIdx.value >= gare.length) activeGaraIdx.value = 0
}

async function caricaConvocazione(id) {
  convocazioneId.value = id
  const res = await axios.get(base + '/convocazioni/' + id, { headers: headers() })
  const d = res.data
  convocazione.value = {
    data_inizio: d.data_inizio, data_fine: d.data_fine || '', esclusioni: d.esclusioni || [],
    note: d.note || '',
    gare: d.gare.map((g, idx) => {
      const giocatoriArr = (g.giocatori || []).sort((a, b) => a.posizione - b.posizione)
      const nonPresenti = new Set(giocatoriArr.filter(x => x.non_presente).map(x => x.persona_id))
      return {
        ...g, numero: g.numero || idx + 1, data: g.data || '',
        allenatori: inferisciAllenatori(g),
        giocatori: padGiocatori(giocatoriArr.map(x => x.persona_id)), nonPresenti
      }
    })
  }
  numPartite.value = convocazione.value.gare.length
  activeGaraIdx.value = 0
  const referenceDates = [...new Set([d.data_inizio, ...(d.gare || []).map(g => g.data)].filter(Boolean))]
  for (const referenceDate of referenceDates) {
    await ensureRegistroPerData(referenceDate)
  }
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

async function creaConvocazioneDaWeekend(weekend) {
  convocazioneId.value = null
  const dataInizio = weekend.data_inizio
  const dataFine = weekend.data_fine || dataInizio
  const nomeSocieta = societaAttiva.value?.nome_breve || societaAttiva.value?.nome || 'Noi'
  const gare = weekend.partite.map((p, idx) => ({
    numero: idx + 1,
    gara: p.casa_fuori === 'fuori' ? `${p.avversario || 'TBD'} vs ${nomeSocieta}` : `${nomeSocieta} vs ${p.avversario || 'TBD'}`,
    data: p.data_partite, campo: p.campo || '', indirizzo: p.indirizzo || '', appuntamento: '',
    inizio_gara: p.ora ? p.ora.slice(0, 5) : '', allenatore: getMisterCognome(p.mister_id), allenatori: p.mister_id ? [p.mister_id] : [], giocatori: Array(10).fill(null), nonPresenti: new Set()
  }))
  numPartite.value = gare.length
  activeGaraIdx.value = 0
  convocazione.value = {
    data_inizio: dataInizio, data_fine: dataFine, esclusioni: [],
    note: `PRESENTARSI ALL'APPUNTAMENTO IN ORARIO STABILITO ED IN TENUTA DA RAPPRESENTANZA MACRON (NO GIA CAMBIATI).
 SI GIOCA CON KIT GARA* (MAGLIA CALZONCINI E CALZETTONI) PORTARE FELPA D'ALLENAMENTO PER RISCALDAMENTO E K-WAY IN BORSA PER L'EVENIENZA.
 AVVISARE TEMPESTIVAMENTE L'ALLENATORE PRESENTE IN GARA IN CASO DI RITARDO O ASSENZA.
 *PORTARE COMUNQUE MAGLIA DI RICAMBIO, CALZONCINI E CALZETTONI PER MODIFICARE I COLORI IN BASE ALL'AVVERSARIO.`,
    gare
  }
  const referenceDates = [...new Set([dataInizio, ...gare.map(g => g.data)].filter(Boolean))]
  for (const referenceDate of referenceDates) {
    await ensureRegistroPerData(referenceDate)
  }
}

async function salva() {
  const payload = {
    categoria_id: categoriaId, data_inizio: convocazione.value.data_inizio, data_fine: convocazione.value.data_fine,
    esclusioni: convocazione.value.esclusioni || [], note: convocazione.value.note,
    gare: convocazione.value.gare.map((g, gi) => {
      const allenatori = g.allenatori || []
      const allenatoriNomi = allenatori
        .map(id => responsabili.value.find(r => r.id === id)?.cognome)
        .filter(Boolean)
      return {
        numero: gi + 1, gara: g.gara, data: g.data || null, campo: g.campo, indirizzo: g.indirizzo,
        appuntamento: g.appuntamento, inizio_gara: g.inizio_gara,
        allenatore: allenatoriNomi.length ? allenatoriNomi.join(', ') : (g.allenatore || ''),
        allenatori,
        giocatori: g.giocatori.map((pid, i) => pid ? { persona_id: pid, posizione: i + 1, non_presente: g.nonPresenti?.has(pid) || false } : null).filter(Boolean)
      }
    })
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
  try {
    const gareList = convocazione.value.gare || []
    const multiGare = gareList.length > 1
    const singleGara = gareList.length === 1
    const singleRows = singleGara ? (gareList[0]?.giocatori || []).filter(Boolean).length : 0
    const useLandscape = multiGare || (singleGara && singleRows > 20)
    const doc = new jsPDF(useLandscape ? 'landscape' : 'portrait', 'mm', 'a4')
    const pageWidth = doc.internal.pageSize.getWidth()
    const pageHeight = doc.internal.pageSize.getHeight()
    const margin = multiGare ? 12 : 14
    const contentWidth = pageWidth - margin * 2
    const accent = [220, 38, 38]
    const dark = [17, 24, 39]
    const gray = [107, 114, 128]
    const light = [248, 250, 252]
    const line = [226, 232, 240]

    const noteText = convocazione.value.note || ''
    let noteLines = []
    let noteHeight = 0
    let noteFontSize = 8.5
    let noteLineHeight = 3.9
    if (noteText) {
      const maxNoteHeight = multiGare ? (gareList.length >= 4 ? 28 : 34) : (useLandscape ? 48 : 72)
      const notePresets = [
        { fontSize: 8.5, lineHeight: 3.9 },
        { fontSize: 7.5, lineHeight: 3.4 },
        { fontSize: 7, lineHeight: 3.1 },
        { fontSize: 6.5, lineHeight: 2.8 }
      ]
      for (const preset of notePresets) {
        noteFontSize = preset.fontSize
        noteLineHeight = preset.lineHeight
        doc.setFont('helvetica', 'normal')
        doc.setFontSize(noteFontSize)
        noteLines = doc.splitTextToSize(noteText, contentWidth - 8)
        noteHeight = noteLines.length * noteLineHeight + 10
        if (noteHeight <= maxNoteHeight) break
      }
      if (noteHeight > maxNoteHeight) {
        const maxLines = Math.max(1, Math.floor((maxNoteHeight - 9) / noteLineHeight))
        if (noteLines.length > maxLines) {
          noteLines = noteLines.slice(0, maxLines)
          noteLines[maxLines - 1] = `${noteLines[maxLines - 1].slice(0, Math.max(0, noteLines[maxLines - 1].length - 1))}…`
        }
        noteHeight = Math.min(maxNoteHeight, noteLines.length * noteLineHeight + 9)
      }
    }
    const bottomMargin = 18 + (noteText ? noteHeight + 6 : 0)

    const personeMap = new Map()
    persone.value.forEach(p => personeMap.set(p.id, p))
    const getPersona = (id) => personeMap.get(id) || persone.value.find(p => p.id === id || p.id === Number(id))
    const formatD = (d) => d ? d.split('-').reverse().join('/') : '—'
    const stagioneTxt = stagioneCorrente.value ? `${stagioneCorrente.value}/${Number(stagioneCorrente.value) + 1}` : ''

    async function loadImageData(url) {
      if (!url) return null
      try {
        const res = await fetch(url)
        if (!res.ok) return null
        const blob = await res.blob()
        const dataUrl = await new Promise((resolve, reject) => {
          const reader = new FileReader()
          reader.onload = () => resolve(reader.result)
          reader.onerror = reject
          reader.readAsDataURL(blob)
        })
        const img = new Image()
        img.src = dataUrl
        await img.decode()
        const canvas = document.createElement('canvas')
        const max = 256
        const scale = Math.min(max / img.width, max / img.height, 1)
        canvas.width = Math.max(1, Math.floor(img.width * scale))
        canvas.height = Math.max(1, Math.floor(img.height * scale))
        const ctx = canvas.getContext('2d')
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
        return canvas.toDataURL('image/png')
      } catch {
        return null
      }
    }

    function addLogo(data, x, y, box) {
      if (!data) return
      try {
        const props = doc.getImageProperties(data)
        const scale = Math.min(box / props.width, box / props.height)
        const w = props.width * scale
        const h = props.height * scale
        doc.addImage(data, 'PNG', x + (box - w) / 2, y + (box - h) / 2, w, h)
      } catch {}
    }

    const logoData = await loadImageData(societaAttiva.value?.logo ? `/uploads/${societaAttiva.value.logo}` : null)
    const sponsorData = await loadImageData(societaAttiva.value?.logosponsor ? `/uploads/${societaAttiva.value.logosponsor}` : null)

    let y = margin
    const logoBox = multiGare ? 14 : 18
    if (logoData) addLogo(logoData, margin, y, logoBox)
    if (sponsorData) addLogo(sponsorData, pageWidth - margin - logoBox, y, logoBox)
    const textX = logoData ? margin + logoBox + 4 : margin

    doc.setFont('helvetica', 'bold')
    doc.setFontSize(multiGare ? 15 : 17)
    doc.setTextColor(...dark)
    const societyMaxWidth = pageWidth - margin - textX - (sponsorData ? logoBox + 4 : 0)
    const societyName = doc.splitTextToSize(societaAttiva.value?.nome || 'SQUADRA', societyMaxWidth)[0] || 'SQUADRA'
    doc.text(societyName, textX, y + (multiGare ? 5 : 6))

    doc.setFontSize(multiGare ? 8 : 8.5)
    doc.setTextColor(...accent)
    doc.text('CONVOCAZIONE GARE', textX, y + (multiGare ? 9 : 11))

    doc.setFont('helvetica', 'normal')
    doc.setFontSize(multiGare ? 10 : 11)
    doc.setTextColor(...dark)
    doc.text(`${categoriaAttiva.value?.nome || ''} ${categoriaAttiva.value?.anno || ''}`.trim(), textX, y + (multiGare ? 14 : 17))

    y += logoBox + (multiGare ? 3 : 5)
    doc.setDrawColor(...accent)
    doc.setLineWidth(0.6)
    doc.line(margin, y, pageWidth - margin, y)
    y += multiGare ? 4 : 6

    function buildRows(gara, combined = false) {
      return gara.giocatori
        .map((pid, i) => {
          if (!pid) return null
          const p = getPersona(pid)
          const cognome = p?.cognome || '—'
          const nome = p?.nome || ''
          return combined ? [String(i + 1), `${cognome} ${nome}`.trim()] : [String(i + 1), cognome, nome]
        })
        .filter(Boolean)
    }

    function renderInfoAbove(gara, x, width, startY, compact = false) {
      if (compact) {
        const ultra = width < 75
        doc.autoTable({
          startY,
          margin: { left: x, right: pageWidth - (x + width), bottom: bottomMargin },
          tableWidth: width,
          body: [
            ['Data / Inizio', `${formatD(gara.data)}${gara.inizio_gara ? ' · ' + gara.inizio_gara : ''}`],
            ['Campo', gara.campo || '—'],
            ['Indirizzo', gara.indirizzo || '—'],
            ['Appuntamento', gara.appuntamento || '—'],
            ['Allenatore', (ultra ? getAllenatoriLabelCompatta(gara) : getAllenatoriLabel(gara)) || '—']
          ],
          theme: 'grid',
          styles: { font: 'helvetica', fontSize: ultra ? 6 : 6.5, cellPadding: ultra ? 0.7 : 0.8, lineColor: line, lineWidth: 0.15, textColor: dark },
          columnStyles: {
            0: { cellWidth: ultra ? 16 : 18, fontStyle: 'bold', fillColor: light, textColor: gray },
            1: { cellWidth: 'auto' }
          },
          pageBreak: 'avoid'
        })
        return doc.lastAutoTable.finalY + 2
      }
      doc.autoTable({
        startY,
        margin: { left: x, right: pageWidth - (x + width), bottom: bottomMargin },
        tableWidth: width,
        body: [
          ['Data', formatD(gara.data), 'Campo', gara.campo || '—'],
          ['Indirizzo', gara.indirizzo || '—', 'Appuntamento', gara.appuntamento || '—'],
          ['Inizio gara', gara.inizio_gara || '—', 'Allenatore', getAllenatoriLabel(gara) || '—']
        ],
        theme: 'grid',
        styles: { font: 'helvetica', fontSize: 8, cellPadding: 1.5, lineColor: line, lineWidth: 0.15, textColor: dark },
        columnStyles: {
          0: { cellWidth: 24, fontStyle: 'bold', fillColor: light, textColor: gray },
          1: { cellWidth: width / 2 - 24 },
          2: { cellWidth: 30, fontStyle: 'bold', fillColor: light, textColor: gray },
          3: { cellWidth: width / 2 - 30 }
        },
        pageBreak: 'avoid'
      })
      return doc.lastAutoTable.finalY + 3
    }

    function chooseSinglePlayerLayout(rowsCount, startY) {
      const available = Math.max(20, pageHeight - bottomMargin - startY)
      const presets = [
        { fontSize: 9.5, cellPadding: 2.8, rowHeight: 8.8 },
        { fontSize: 9, cellPadding: 2.2, rowHeight: 8 },
        { fontSize: 8.5, cellPadding: 1.8, rowHeight: 7.2 },
        { fontSize: 8, cellPadding: 1.4, rowHeight: 6.6 },
        { fontSize: 7.5, cellPadding: 1, rowHeight: 6.2 },
        { fontSize: 7, cellPadding: 0.8, rowHeight: 5.8 }
      ]
      return presets.find(p => (rowsCount + 1) * p.rowHeight <= available) || presets[presets.length - 1]
    }

    function chooseMultiPlayerLayout(rowsCount, width, startY, groupColumns = 3) {
      const available = Math.max(20, pageHeight - bottomMargin - startY)
      const presets = groupColumns === 2 ? [
        { columns: 2, fontSize: 6.5, cellPadding: 0.6, rowHeight: 5.2, minSubWidth: 28 },
        { columns: 3, fontSize: 6, cellPadding: 0.5, rowHeight: 5, minSubWidth: 20 },
        { columns: 4, fontSize: 5.5, cellPadding: 0.4, rowHeight: 4.8, minSubWidth: 15 }
      ] : [
        { columns: 2, fontSize: 8.5, cellPadding: 1.5, rowHeight: 6.6, minSubWidth: 42 },
        { columns: 3, fontSize: 8.5, cellPadding: 1.5, rowHeight: 6.6, minSubWidth: 36 },
        { columns: 4, fontSize: 8, cellPadding: 1.2, rowHeight: 6.8, minSubWidth: 32 },
        { columns: 5, fontSize: 7.5, cellPadding: 1, rowHeight: 8, minSubWidth: 28 },
        { columns: 6, fontSize: 7, cellPadding: 0.8, rowHeight: 7.5, minSubWidth: 24 },
        { columns: 8, fontSize: 6.5, cellPadding: 0.6, rowHeight: 8, minSubWidth: 18 },
        { columns: 10, fontSize: 6, cellPadding: 0.5, rowHeight: 8.5, minSubWidth: 16 },
        { columns: 12, fontSize: 5.5, cellPadding: 0.4, rowHeight: 9.5, minSubWidth: 14 }
      ]
      for (const preset of presets) {
        const rowsPerCol = Math.ceil(rowsCount / preset.columns)
        const subWidth = width / preset.columns
        if ((rowsPerCol + 1) * preset.rowHeight <= available && subWidth >= preset.minSubWidth) return preset
      }
      return presets[presets.length - 1]
    }

    function renderPlayerTable(gara, x, width, startY, columns = 'auto', groupColumns = 3) {
      const combined = groupColumns === 2
      const rows = buildRows(gara, combined)
      const forceSingle = columns === 1
      const multiLayout = forceSingle ? null : chooseMultiPlayerLayout(rows.length, width, startY, groupColumns)
      if (forceSingle || rows.length <= 10 || !multiLayout) {
        const singleLayout = chooseSinglePlayerLayout(rows.length, startY)
        const singleFontSize = width < 75 ? Math.min(singleLayout.fontSize, 7) : singleLayout.fontSize
        const singleCellPadding = width < 75 ? Math.min(singleLayout.cellPadding, 1) : singleLayout.cellPadding
        doc.autoTable({
          startY,
          margin: { left: x, right: pageWidth - (x + width), bottom: bottomMargin },
          tableWidth: width,
          head: combined ? [['#', 'Cognome Nome']] : [['#', 'Cognome', 'Nome']],
          body: rows.length ? rows : (combined ? [['—', 'Nessun giocatore selezionato']] : [['—', 'Nessun giocatore selezionato', '']]),
          theme: 'grid',
          headStyles: { fillColor: dark, textColor: [255, 255, 255], font: 'helvetica', fontSize: singleFontSize, cellPadding: singleCellPadding },
          styles: { font: 'helvetica', fontSize: singleFontSize, cellPadding: singleCellPadding, lineColor: line, lineWidth: 0.15, textColor: dark },
          columnStyles: combined
            ? {
                0: { cellWidth: 8, halign: 'center', fontStyle: 'bold' },
                1: { cellWidth: 'auto' }
              }
            : {
                0: { cellWidth: 10, halign: 'center', fontStyle: 'bold' },
                1: { cellWidth: Math.max(20, width * 0.42), fontStyle: 'bold' },
                2: { cellWidth: 'auto' }
              },
          pageBreak: 'avoid'
        })
        return doc.lastAutoTable.finalY
      }

      const colCount = multiLayout.columns
      const per = Math.ceil(rows.length / colCount)
      const chunks = Array.from({ length: colCount }, (_, i) => rows.slice(i * per, (i + 1) * per))
      const maxRows = Math.max(...chunks.map(c => c.length), 1)
      const body = Array.from({ length: maxRows }, (_, r) => {
        const line = []
        chunks.forEach(chunk => {
          const row = chunk[r] || (combined ? ['', ''] : ['', '', ''])
          line.push(...row)
        })
        return line
      })
      const head = Array.from({ length: colCount }, () => (combined ? ['#', 'Cognome Nome'] : ['#', 'Cognome', 'Nome'])).flat()
      const groupWidth = width / colCount
      const columnStyles = {}
      if (combined) {
        const numWidth = colCount > 3 ? 3.5 : 4.5
        const nameWidth = Math.max(4, groupWidth - numWidth)
        for (let c = 0; c < colCount; c++) {
          columnStyles[c * 2] = { cellWidth: numWidth, halign: 'center', fontStyle: 'bold' }
          columnStyles[c * 2 + 1] = { cellWidth: nameWidth }
        }
      } else {
        const numWidth = colCount > 8 ? 4 : colCount > 6 ? 5 : colCount > 4 ? 6 : colCount > 2 ? 7 : 8
        const cognomeWidth = groupWidth * (colCount > 8 ? 0.5 : colCount > 4 ? 0.55 : colCount > 2 ? 0.5 : 0.55)
        const nomeWidth = Math.max(1.5, groupWidth - numWidth - cognomeWidth)
        for (let c = 0; c < colCount; c++) {
          columnStyles[c * 3] = { cellWidth: numWidth, halign: 'center', fontStyle: 'bold' }
          columnStyles[c * 3 + 1] = { cellWidth: cognomeWidth, fontStyle: 'bold' }
          columnStyles[c * 3 + 2] = { cellWidth: nomeWidth }
        }
      }
      doc.autoTable({
        startY,
        margin: { left: x, right: pageWidth - (x + width), bottom: bottomMargin },
        tableWidth: width,
        head: [head],
        body,
        theme: 'grid',
        headStyles: { fillColor: dark, textColor: [255, 255, 255], font: 'helvetica', fontSize: multiLayout.fontSize, cellPadding: multiLayout.cellPadding },
        styles: { font: 'helvetica', fontSize: multiLayout.fontSize, cellPadding: multiLayout.cellPadding, lineColor: line, lineWidth: 0.15, textColor: dark },
        columnStyles,
        pageBreak: 'avoid'
      })
      return doc.lastAutoTable.finalY
    }

    function renderGaraColumn(gara, x, width, startY, compact = false) {
      const ultra = compact && width < 75
      const titleHeight = compact ? 5 : 6
      const titleFont = ultra ? 9.5 : compact ? 10.5 : 12
      doc.setFillColor(...accent)
      doc.rect(x, startY, 2, titleHeight, 'F')
      if (gara.gara) {
        doc.setFont('helvetica', 'bold')
        doc.setFontSize(titleFont)
        doc.setTextColor(...dark)
        const garaTitle = doc.splitTextToSize(gara.gara, width - 7)[0] || ''
        doc.text(garaTitle, x + 4, startY + (compact ? 3.8 : 4.5))
      }
      let colY = startY + (compact ? 6.5 : 8)
      colY = renderInfoAbove(gara, x, width, colY, compact)
      const groupColumns = width < 75 ? 2 : 3
      const playerColumns = width >= 55 ? 'auto' : 1
      colY = renderPlayerTable(gara, x, width, colY, playerColumns, groupColumns)
      return colY
    }

    if (!multiGare) {
      const gara = gareList[0]
      if (gara) {
        doc.setFillColor(...accent)
        doc.rect(margin, y, 2.5, 6, 'F')
        if (gara.gara) {
          doc.setFont('helvetica', 'bold')
          doc.setFontSize(12)
          doc.setTextColor(...dark)
          const garaTitle = doc.splitTextToSize(gara.gara, pageWidth - margin - (margin + 5))[0] || ''
          doc.text(garaTitle, margin + 5, y + 4.5)
        }
        y += 10

        const infoRows = [
          ['Data', formatD(gara.data)],
          ['Campo', gara.campo || '—'],
          ['Indirizzo', gara.indirizzo || '—'],
          ['Appuntamento', gara.appuntamento || '—'],
          ['Inizio gara', gara.inizio_gara || '—'],
          ['Allenatore', getAllenatoriLabel(gara) || '—']
        ]
        const startY = y

        if (useLandscape) {
          const infoWidth = 85
          const gap = 6
          const playerX = margin + infoWidth + gap
          const playerWidth = pageWidth - margin - playerX

          doc.autoTable({
            startY,
            margin: { left: margin, right: pageWidth - (margin + infoWidth), bottom: bottomMargin },
            tableWidth: infoWidth,
            head: [[{ content: 'INFO GARA', colSpan: 2 }]],
            body: infoRows,
            theme: 'grid',
            headStyles: { fillColor: dark, textColor: [255, 255, 255], font: 'helvetica', fontSize: 9, cellPadding: 2.8, halign: 'left' },
            styles: { font: 'helvetica', fontSize: 8.5, cellPadding: 2.5, lineColor: line, lineWidth: 0.15, textColor: dark, valign: 'top' },
            columnStyles: {
              0: { cellWidth: 26, fontStyle: 'bold', fillColor: light, textColor: gray },
              1: { cellWidth: 'auto' }
            },
            pageBreak: 'avoid'
          })
          const infoFinalY = doc.lastAutoTable.finalY
          const playerFinalY = renderPlayerTable(gara, playerX, playerWidth, startY, 'auto')
          y = Math.max(infoFinalY, playerFinalY) + 6
        } else {
          const leftWidth = 105
          const gap = 6
          const rightX = margin + leftWidth + gap
          const rightWidth = pageWidth - margin - rightX

          const leftFinalY = renderPlayerTable(gara, margin, leftWidth, startY, 1)

          doc.autoTable({
            startY,
            margin: { left: rightX, right: margin, bottom: bottomMargin },
            tableWidth: rightWidth,
            head: [[{ content: 'INFO GARA', colSpan: 2 }]],
            body: infoRows,
            theme: 'grid',
            headStyles: { fillColor: dark, textColor: [255, 255, 255], font: 'helvetica', fontSize: 9, cellPadding: 2.8, halign: 'left' },
            styles: { font: 'helvetica', fontSize: 8.5, cellPadding: 2.5, lineColor: line, lineWidth: 0.15, textColor: dark, valign: 'top' },
            columnStyles: {
              0: { cellWidth: 26, fontStyle: 'bold', fillColor: light, textColor: gray },
              1: { cellWidth: 'auto' }
            },
            pageBreak: 'avoid'
          })
          const rightFinalY = doc.lastAutoTable.finalY

          y = Math.max(leftFinalY, rightFinalY) + 9
        }
      }
    } else {
      const n = convocazione.value.gare.length
      const gap = n >= 4 ? 6 : 8
      const maxPlayers = Math.max(0, ...convocazione.value.gare.map(g => (g.giocatori || []).filter(Boolean).length))
      const singlePageMax = { 2: 99, 3: 30, 4: 24 }
      const maxPerRow = (n <= 4 && maxPlayers <= (singlePageMax[n] || 99)) ? n : 2
      let rowStart = 0
      let firstRow = true
      while (rowStart < n) {
        const count = Math.min(maxPerRow, n - rowStart)
        const colWidth = (contentWidth - gap * (count - 1)) / count
        const compact = colWidth < 100
        if (!firstRow) {
          doc.addPage()
          y = margin
        }
        firstRow = false
        const startY = y
        let finalY = margin
        for (let j = 0; j < count; j++) {
          const colX = margin + j * (colWidth + gap)
          finalY = Math.max(finalY, renderGaraColumn(convocazione.value.gare[rowStart + j], colX, colWidth, startY, compact))
        }
        y = finalY + 6
        rowStart += count
      }
    }

    if (noteText) {
      const targetY = Math.max(margin, pageHeight - noteHeight - 18)
      if (multiGare && y + 6 > targetY) {
        doc.addPage()
      }
      y = targetY
      doc.setFillColor(...light)
      doc.setDrawColor(...line)
      doc.setLineWidth(0.15)
      doc.roundedRect(margin, y, contentWidth, noteHeight, 1.5, 1.5, 'FD')
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(7.5)
      doc.setTextColor(...accent)
      doc.text('NOTE', margin + 4, y + 5)
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(noteFontSize)
      doc.setTextColor(...dark)
      doc.text(noteLines, margin + 4, y + 10, { maxLineSpacing: noteLineHeight })
    }

    const pageCount = doc.getNumberOfPages()
    for (let i = 1; i <= pageCount; i++) {
      doc.setPage(i)
      doc.setDrawColor(...line)
      doc.setLineWidth(0.15)
      doc.line(margin, pageHeight - 11, pageWidth - margin, pageHeight - 11)
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(7.5)
      doc.setTextColor(148, 163, 184)
      doc.text(`${societaAttiva.value?.nome || ''}${stagioneTxt ? ' · Stagione ' + stagioneTxt : ''}`, margin, pageHeight - 7)
      doc.text(`Pagina ${i} di ${pageCount}`, pageWidth - margin, pageHeight - 7, { align: 'right' })
    }

    const categoriaNome = categoriaAttiva.value?.nome || 'Categoria'
    const dataInizio = convocazione.value.data_inizio || ''
    const dataFine = convocazione.value.data_fine || ''
    const dataFormattata = dataInizio ? dataInizio.split('-').reverse().join('/') : 'data'
    const dataFinale = dataFine ? dataFormattata + '-' + dataFine.split('-').reverse().join('/') : dataFormattata
    doc.save(`Convocazioni ${categoriaNome} ${dataFinale}.pdf`)
  } catch (e) {
    console.error('Errore PDF:', e)
    alert('Errore nella generazione del PDF')
  }
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

function estraiAvversario(testo) {
  if (!testo) return ''
  const parti = testo.split(' vs ')
  if (parti.length === 2) {
    return parti[0].trim() === nomeSocieta.value ? parti[1].trim() : parti[0].trim()
  }
  return ''
}

function nuovoGiocatoreScouting() {
  return { nome: '', cognome: '', ruolo: '', numero_maglia: null, squadra: scoutingModal.value.squadra_avversaria || null }
}

function apriScouting() {
  if (!convocazioneId.value || !garaAttiva.value?.id) {
    alert('Salva prima la convocazione per poter creare una segnalazione scouting')
    return
  }
  scoutingModal.value = {
    open: true,
    loading: false,
    titolo: '',
    data_osservazione: garaAttiva.value.data || new Date().toISOString().slice(0, 10),
    squadra_avversaria: estraiAvversario(garaAttiva.value.gara),
    note: '',
    giocatori: [nuovoGiocatoreScouting()]
  }
}

function aggiungiGiocatoreScouting() {
  scoutingModal.value.giocatori.push(nuovoGiocatoreScouting())
}

function rimuoviGiocatoreScouting(idx) {
  scoutingModal.value.giocatori.splice(idx, 1)
}

async function inviaScouting() {
  const giocatori = scoutingModal.value.giocatori
    .map(g => ({ ...g, squadra: g.squadra || scoutingModal.value.squadra_avversaria || null }))
    .filter(g => g.nome || g.cognome)
  if (giocatori.length === 0) {
    alert('Aggiungi almeno un giocatore con nome o cognome')
    return
  }
  scoutingModal.value.loading = true
  try {
    await creaSegnalazioneScouting({
      categoria_id: categoriaId,
      convocazione_id: convocazioneId.value,
      gara_id: garaAttiva.value?.id || null,
      titolo: scoutingModal.value.titolo || null,
      data_osservazione: scoutingModal.value.data_osservazione || null,
      squadra_avversaria: scoutingModal.value.squadra_avversaria || null,
      note: scoutingModal.value.note || null,
      giocatori
    })
    scoutingModal.value.open = false
    alert('Segnalazione inviata a Scouting')
  } catch (e) {
    alert('Errore: ' + (e.response?.data?.detail || e.message))
  } finally {
    scoutingModal.value.loading = false
  }
}

onMounted(async () => {
  const res = await getPersone(categoriaId)
  persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
  const regRes = await getRegistroMese(categoriaId, annoCorrente, meseCorrente)
  registro.value = regRes.data
  registroMesiCaricate.add(`${annoCorrente}-${String(meseCorrente).padStart(2, '0')}`)
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
.alert-tag small {
  margin-left: 4px;
  font-size: 0.6rem;
  font-style: normal;
  font-weight: 700;
  opacity: 0.75;
}
.alert-tag.tag-cert {
  background: rgba(220, 38, 38, 0.16);
}
.alert-none { font-size: 0.75rem; color: var(--color-text-muted); }

.pagamenti-box.ok {
  background: rgba(22, 163, 74, 0.06);
  border-color: rgba(22, 163, 74, 0.25);
}

.tag-non-regola {
  background: #dc2626;
  color: #fff;
}

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
.info-dl .v .mister-checkboxes {
  display: flex;
  flex-direction: column;
  gap: 6px;
  max-height: 132px;
  overflow-y: auto;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  background: var(--color-surface);
  padding: 8px;
}
.info-dl .v .mister-option {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 500;
  cursor: pointer;
  user-select: none;
}
.info-dl .v .mister-option input[type="checkbox"] {
  width: 16px;
  height: 16px;
  margin: 0;
  accent-color: #dc2626;
  cursor: pointer;
}
.info-dl .v .mister-empty {
  color: var(--color-text-muted);
}

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
.picker-name-row { display: flex; align-items: center; gap: 0.35rem; min-width: 0; }
.picker-name { font-size: 0.82rem; font-weight: 700; color: var(--color-text); }
.picker-warning {
  flex-shrink: 0;
  padding: 0.05rem 0.3rem;
  border-radius: 999px;
  background: rgba(245, 158, 11, 0.12);
  border: 1px solid rgba(245, 158, 11, 0.25);
  color: #b45309;
  font-size: 0.58rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  white-space: nowrap;
}
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

/* ---- SCOUTING MODAL ---- */
.scout-overlay {
  position: fixed;
  inset: 0;
  z-index: 1000;
  background: rgba(15, 23, 42, 0.45);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  animation: fadeIn 0.18s ease-out;
}
.scout-modal {
  width: 100%;
  max-width: 640px;
  max-height: calc(100vh - 2rem);
  overflow-y: auto;
  background: var(--color-bg, #f8fafc);
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 16px;
  box-shadow: 0 24px 64px rgba(0, 0, 0, 0.22);
  animation: scaleIn 0.2s ease-out;
}
.scout-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--color-border, #e2e8f0);
}
.scout-header h3 {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 800;
  color: var(--color-text, #0f172a);
}
.scout-close {
  border: 0;
  background: transparent;
  font-size: 1.5rem;
  line-height: 1;
  color: var(--color-text-muted, #64748b);
  cursor: pointer;
}
.scout-form {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
}
.scout-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.85rem;
}
.scout-field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}
.scout-field label {
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--color-text-muted, #64748b);
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.scout-field input,
.scout-field textarea {
  width: 100%;
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 10px;
  background: var(--color-surface, #ffffff);
  color: var(--color-text, #0f172a);
  font-family: inherit;
  font-size: 0.9rem;
  padding: 0.55rem 0.75rem;
  outline: none;
}
.scout-field input:focus,
.scout-field textarea:focus {
  border-color: #dc2626;
  box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.1);
}
.scout-players {
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 12px;
  padding: 0.85rem;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}
.scout-players-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 0.82rem;
  font-weight: 700;
  color: var(--color-text, #0f172a);
}
.scout-player-row {
  display: grid;
  grid-template-columns: 1.1fr 1.1fr 0.8fr 0.45fr auto;
  gap: 0.5rem;
  align-items: center;
}
.scout-player-row input {
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 8px;
  background: var(--color-surface, #ffffff);
  color: var(--color-text, #0f172a);
  font-size: 0.85rem;
  padding: 0.45rem 0.6rem;
  outline: none;
  width: 100%;
  min-width: 0;
}
.scout-player-row input:focus {
  border-color: #dc2626;
}
.scout-remove {
  border: 0;
  background: rgba(220, 38, 38, 0.08);
  color: #dc2626;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  font-size: 1.1rem;
  line-height: 1;
  cursor: pointer;
}
.scout-empty {
  margin: 0;
  font-size: 0.82rem;
  color: var(--color-text-muted, #64748b);
  text-align: center;
  padding: 0.5rem 0;
}
.scout-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.6rem;
}
.btn-sm {
  padding: 0.4rem 0.7rem;
  font-size: 0.8rem;
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
  .scout-row { grid-template-columns: 1fr; }
  .scout-player-row { grid-template-columns: 1fr 1fr; }
  .scout-actions { flex-direction: column; }
  .scout-actions .btn { width: 100%; }
}
</style>

