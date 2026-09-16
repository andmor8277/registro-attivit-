<template>
  <div class="scouting-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12" />
            <polyline points="12 19 5 12 12 5" />
          </svg>
          <span>Home</span>
        </button>
        <div class="header-badge">
          <span class="badge-dot"></span>
          <span>{{ stagioneLabel }}</span>
        </div>
      </div>
      <div class="header-main">
        <h1 class="page-title">
          <span class="name-gradient">Scouting</span>
        </h1>
        <p class="header-subtitle">Relazioni sui giocatori avversari e schede valutative</p>
      </div>
    </header>

    <div class="stats-row">
      <div v-for="s in statiStats" :key="s.key" class="stat-card" :class="s.cls">
        <span class="stat-value">{{ s.value }}</span>
        <span class="stat-label">{{ s.label }}</span>
      </div>
    </div>

    <div class="filters-card">
      <div class="search-wrap">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <circle cx="11" cy="11" r="7" />
          <path d="m21 21-4.3-4.3" />
        </svg>
        <input v-model="ricerca" class="search-input" placeholder="Cerca titolo, squadra o giocatore..." />
      </div>
      <select v-model="filtroStato" class="filter-select">
        <option value="">Tutti gli stati</option>
        <option value="inviata">Inviata</option>
        <option value="in_lavorazione">In lavorazione</option>
        <option value="completata">Completata</option>
      </select>
      <select v-model="filtroCategoria" class="filter-select">
        <option value="">Tutte le categorie</option>
        <option v-for="c in categorie" :key="c.id" :value="c.id">{{ c.nome }} {{ c.anno || '' }}</option>
      </select>
    </div>

    <div v-if="loading" class="loading-wrap">
      <div class="spinner"></div>
      <span>Caricamento...</span>
    </div>
    <p v-else-if="errore" class="error-msg">{{ errore }}</p>

    <div v-else class="segnalazioni-grid">
      <article v-for="seg in segnalazioni" :key="seg.id" class="segnalazione-card" @click="apriDettaglio(seg)">
        <div class="card-top">
          <span class="stato-pill" :class="'stato-' + seg.stato">{{ statoLabel(seg.stato) }}</span>
          <span class="card-date">{{ fmtData(seg.data_osservazione || seg.data_gara) }}</span>
        </div>
        <h3 class="card-title">{{ seg.titolo || 'Segnalazione scouting' }}</h3>
        <p class="card-squadra">{{ seg.squadra_avversaria || 'Squadra non indicata' }}</p>
        <div class="card-meta">
          <span class="meta-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" /></svg>
            {{ seg.categoria_nome || 'Categoria' }} {{ seg.categoria_anno || '' }}
          </span>
          <span class="meta-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="4" /><path d="M4 20c0-4 4-6 8-6s8 2 8 6" /></svg>
            {{ (seg.giocatori || []).length }} giocatori
          </span>
          <span v-if="seg.autore_nome" class="meta-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9" /><path d="M12 6v6l4 2" /></svg>
            {{ seg.autore_nome }}
          </span>
        </div>
        <div v-if="seg.giocatori?.length" class="card-players">
          <span v-for="g in seg.giocatori.slice(0, 4)" :key="g.id" class="player-chip">
            {{ g.numero_maglia ? '#' + g.numero_maglia : '' }} {{ g.cognome || g.nome || '?' }}
          </span>
          <span v-if="seg.giocatori.length > 4" class="player-chip more">+{{ seg.giocatori.length - 4 }}</span>
        </div>
      </article>
    </div>

    <div v-if="!segnalazioni.length && !loading" class="empty-state">
      <div class="empty-icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="42" height="42">
          <circle cx="11" cy="11" r="7" />
          <path d="m21 21-4.3-4.3" />
        </svg>
      </div>
      <div class="empty-title">Nessuna segnalazione</div>
      <div class="empty-sub">Le relazioni create dai mister appariranno qui</div>
    </div>

    <div v-if="selezionata" class="detail-overlay" @click.self="chiudiDettaglio">
      <div class="detail-panel">
        <header class="detail-header">
          <input v-model="selezionata.titolo" class="detail-title" placeholder="Titolo segnalazione" />
          <button class="icon-btn" @click="chiudiDettaglio" aria-label="Chiudi">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
          </button>
        </header>

        <div v-if="dettaglioLoading" class="loading-wrap small">
          <div class="spinner"></div>
          <span>Aggiornamento...</span>
        </div>

        <div class="detail-grid">
          <label class="detail-field">
            <span>Stato</span>
            <select v-if="canValutare" v-model="selezionata.stato" class="detail-select" @change="cambiaStato">
              <option value="inviata">Inviata</option>
              <option value="in_lavorazione">In lavorazione</option>
              <option value="completata">Completata</option>
            </select>
            <span v-else class="stato-pill" :class="'stato-' + selezionata.stato">{{ statoLabel(selezionata.stato) }}</span>
          </label>
          <label class="detail-field">
            <span>Data osservazione</span>
            <input type="date" v-model="selezionata.data_osservazione" class="detail-input" />
          </label>
          <label class="detail-field">
            <span>Squadra avversaria</span>
            <input v-model="selezionata.squadra_avversaria" class="detail-input" placeholder="Squadra" />
          </label>
          <label class="detail-field">
            <span>Categoria</span>
            <span class="detail-static">{{ selezionata.categoria_nome || '—' }} {{ selezionata.categoria_anno || '' }}</span>
          </label>
          <label class="detail-field">
            <span>Gara</span>
            <span class="detail-static">{{ selezionata.gara_nome || '—' }}</span>
          </label>
          <label class="detail-field">
            <span>Autore</span>
            <span class="detail-static">{{ selezionata.autore_nome || '—' }}</span>
          </label>
        </div>

        <label class="detail-note">
          <span>Note generali</span>
          <textarea v-model="selezionata.note" rows="4" class="detail-textarea" placeholder="Contesto gara, modulo, osservazioni generali..."></textarea>
        </label>

        <p v-if="dettaglioErrore" class="error-msg">{{ dettaglioErrore }}</p>

        <div class="detail-actions">
          <button class="btn btn-primary" :disabled="salvataggio" @click="salvaDettaglio">
            {{ salvataggio ? 'Salvataggio...' : 'Salva' }}
          </button>
          <button class="btn btn-ghost" @click="esportaPDF">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" /><polyline points="7 10 12 15 17 10" /><line x1="12" y1="15" x2="12" y2="3" /></svg>
            Esporta PDF
          </button>
          <button v-if="canModificare(selezionata)" class="btn btn-danger" @click="elimina">Elimina</button>
        </div>

        <section class="players-section">
          <div class="players-header">
            <h3>Giocatori osservati</h3>
            <button class="btn btn-ghost btn-sm" @click="apriNuovoGiocatore">+ Aggiungi</button>
          </div>
          <div class="players-table-wrap">
            <table class="players-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Giocatore</th>
                  <th>Squadra</th>
                  <th>Ruolo</th>
                  <th>Media</th>
                  <th>Note</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="g in selezionata.giocatori" :key="g.id">
                  <td class="maglia">{{ g.numero_maglia || '—' }}</td>
                  <td>
                    <div class="player-name">
                      <b>{{ g.cognome || '—' }}</b>
                      <span>{{ g.nome }}</span>
                    </div>
                  </td>
                  <td>{{ g.squadra || '—' }}</td>
                  <td>{{ g.ruolo || '—' }}</td>
                  <td><span class="media-badge" :class="mediaClass(mediaGiocatore(g))">{{ mediaGiocatore(g) }}</span></td>
                  <td class="note-cell" :title="g.note || ''">{{ g.note || '—' }}</td>
                  <td class="actions-cell">
                    <button v-if="canValutare" class="mini-btn" @click="apriValutazione(g)">Valuta</button>
                    <button v-if="canModificare(selezionata)" class="mini-btn danger" @click="eliminaGiocatore(g)">Elimina</button>
                  </td>
                </tr>
                <tr v-if="!selezionata.giocatori?.length">
                  <td colspan="7" class="empty-row">Nessun giocatore aggiunto</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </div>

    <div v-if="valutazioneOpen" class="modal-overlay" @click.self="valutazioneOpen = false">
      <div class="modal-panel">
        <header class="modal-header">
          <h3>Valutazione — {{ giocatoreValutato?.cognome || '' }} {{ giocatoreValutato?.nome || '' }}</h3>
          <button class="icon-btn" @click="valutazioneOpen = false" aria-label="Chiudi">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
          </button>
        </header>
        <div class="val-grid">
          <div v-for="col in colonne" :key="col.key" class="val-item">
            <span class="val-label" :title="col.tipologia">{{ col.label }}</span>
            <div class="rating-group">
              <button
                v-for="n in 3"
                :key="n"
                class="rating-btn"
                :class="{ active: formValutazione[col.key] === n, ['level-' + n]: true }"
                @click="formValutazione[col.key] = formValutazione[col.key] === n ? null : n"
              >{{ n }}</button>
            </div>
          </div>
        </div>
        <label class="detail-note">
          <span>Note sul giocatore</span>
          <textarea v-model="formValutazione.note" rows="3" class="detail-textarea" placeholder="Punti di forza, criticità, potenziale..."></textarea>
        </label>
        <div class="modal-actions">
          <button class="btn btn-ghost" @click="valutazioneOpen = false">Annulla</button>
          <button class="btn btn-primary" :disabled="valutazioneSaving" @click="salvaValutazione">
            {{ valutazioneSaving ? 'Salvataggio...' : 'Salva valutazione' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="nuovoGiocatoreOpen" class="modal-overlay" @click.self="nuovoGiocatoreOpen = false">
      <div class="modal-panel">
        <header class="modal-header">
          <h3>Aggiungi giocatore</h3>
          <button class="icon-btn" @click="nuovoGiocatoreOpen = false" aria-label="Chiudi">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
          </button>
        </header>
        <div class="form-grid">
          <label class="detail-field">
            <span>Cognome</span>
            <input v-model="formGiocatore.cognome" class="detail-input" />
          </label>
          <label class="detail-field">
            <span>Nome</span>
            <input v-model="formGiocatore.nome" class="detail-input" />
          </label>
          <label class="detail-field">
            <span>Squadra</span>
            <input v-model="formGiocatore.squadra" class="detail-input" :placeholder="selezionata?.squadra_avversaria || ''" />
          </label>
          <label class="detail-field">
            <span>Ruolo</span>
            <input v-model="formGiocatore.ruolo" class="detail-input" placeholder="ES, DC, T, P..." />
          </label>
          <label class="detail-field">
            <span>Numero maglia</span>
            <input type="number" min="1" max="99" v-model.number="formGiocatore.numero_maglia" class="detail-input" />
          </label>
        </div>
        <div class="modal-actions">
          <button class="btn btn-ghost" @click="nuovoGiocatoreOpen = false">Annulla</button>
          <button class="btn btn-primary" :disabled="giocatoreSaving" @click="salvaNuovoGiocatore">
            {{ giocatoreSaving ? 'Aggiunta...' : 'Aggiungi' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from '../../store.js'
import {
  getCategorie,
  getSegnalazioniScouting,
  getSegnalazioneScouting,
  aggiornaSegnalazioneScouting,
  eliminaSegnalazioneScouting,
  cambiaStatoScouting,
  valutaGiocatoreScouting
} from '../../api/index.js'
import { jsPDF } from 'jspdf'
import 'jspdf-autotable'

const router = useRouter()
const { utenteAttivo, societaAttiva, stagioneCorrente } = useStore()

const segnalazioni = ref([])
const categorie = ref([])
const loading = ref(true)
const errore = ref('')
const ricerca = ref('')
const filtroStato = ref('')
const filtroCategoria = ref('')

const selezionata = ref(null)
const dettaglioLoading = ref(false)
const dettaglioErrore = ref('')
const salvataggio = ref(false)

const valutazioneOpen = ref(false)
const valutazioneSaving = ref(false)
const giocatoreValutato = ref(null)
const formValutazione = ref({})

const nuovoGiocatoreOpen = ref(false)
const giocatoreSaving = ref(false)
const formGiocatore = ref({})

const colonne = [
  { key: 'tecnica', label: 'Tecnica', tipologia: 'Controllo palla, primo tocco' },
  { key: 'velocita', label: 'Velocità', tipologia: 'Scatto, resistenza anaerobica' },
  { key: 'resistenza', label: 'Resistenza', tipologia: 'Condizione fisica, endurance' },
  { key: 'attitudine', label: 'Attitudine', tipologia: 'Impegno, voglia di migliorare' },
  { key: 'posizione', label: 'Posizione', tipologia: 'Letto di gioco, posizionamento' },
  { key: 'gioco_di_testa', label: 'Gioco aereo', tipologia: 'Colpo di testa, anticipo' },
  { key: 'tiro', label: 'Tiro', tipologia: 'Finalizzazione, potenza' },
  { key: 'passaggio', label: 'Passaggio', tipologia: 'Visione, precisione' },
  { key: 'dribbling', label: 'Dribbling', tipologia: 'Regate, cambi di direzione' },
  { key: 'disciplina', label: 'Disciplina', tipologia: 'Comportamento, rispetto regole' }
]

const isSuperAdmin = computed(() => utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin')
const isAdmin = computed(() => !!utenteAttivo.value?.is_admin)
const isScouting = computed(() => utenteAttivo.value?.ruolo === 'scouting')
const canValutare = computed(() => isSuperAdmin.value || isAdmin.value || isScouting.value)

const stagioneLabel = computed(() => {
  if (!stagioneCorrente.value) return 'Stagione n.d.'
  return `${stagioneCorrente.value}/${Number(stagioneCorrente.value) + 1}`
})

const statiStats = computed(() => [
  { key: 'inviata', label: 'Inviata', value: segnalazioni.value.filter(s => s.stato === 'inviata').length, cls: 'stat-inviata' },
  { key: 'in_lavorazione', label: 'In lavorazione', value: segnalazioni.value.filter(s => s.stato === 'in_lavorazione').length, cls: 'stat-lavorazione' },
  { key: 'completata', label: 'Completata', value: segnalazioni.value.filter(s => s.stato === 'completata').length, cls: 'stat-completata' }
])

function statoLabel(stato) {
  return { inviata: 'Inviata', in_lavorazione: 'In lavorazione', completata: 'Completata' }[stato] || stato
}

function fmtData(d) {
  if (!d) return '—'
  return String(d).split('T')[0].split('-').reverse().join('/')
}

function canModificare(seg) {
  if (!seg) return false
  if (isSuperAdmin.value || isAdmin.value || isScouting.value) return true
  return utenteAttivo.value?.ruolo === 'mister' && seg.autore_id === utenteAttivo.value?.id
}

function mediaGiocatore(g) {
  const values = colonne.map(c => g[c.key]).filter(v => v != null)
  if (!values.length) return '—'
  return (values.reduce((a, b) => a + b, 0) / values.length).toFixed(1)
}

function mediaClass(m) {
  if (m === '—') return ''
  const n = Number(m)
  if (n <= 1.5) return 'media-bassa'
  if (n <= 2.2) return 'media-media'
  return 'media-alta'
}

async function caricaCategorie() {
  try {
    const sid = societaAttiva.value?.id || utenteAttivo.value?.societa_id || Number(localStorage.getItem('societa_id')) || 1
    const res = await getCategorie(sid)
    const cats = Array.isArray(res) ? res : (res.data || [])
    categorie.value = cats.filter(c => c.societa_id === sid && !c.is_archiviata && c.parent_id !== null)
  } catch (e) {
    console.error('Errore categorie:', e)
  }
}

async function carica() {
  loading.value = true
  errore.value = ''
  try {
    const params = {}
    if (filtroStato.value) params.stato = filtroStato.value
    if (filtroCategoria.value) params.categoria_id = filtroCategoria.value
    if (ricerca.value.trim()) params.q = ricerca.value.trim()
    const res = await getSegnalazioniScouting(params)
    segnalazioni.value = res.data || []
  } catch (e) {
    errore.value = e.response?.data?.detail || 'Errore nel caricamento delle segnalazioni'
  } finally {
    loading.value = false
  }
}

async function apriDettaglio(seg) {
  selezionata.value = seg
  dettaglioLoading.value = true
  dettaglioErrore.value = ''
  try {
    const res = await getSegnalazioneScouting(seg.id)
    selezionata.value = res.data
  } catch (e) {
    dettaglioErrore.value = e.response?.data?.detail || 'Errore nel caricamento del dettaglio'
  } finally {
    dettaglioLoading.value = false
  }
}

function chiudiDettaglio() {
  selezionata.value = null
  dettaglioErrore.value = ''
}

async function salvaDettaglio() {
  if (!selezionata.value) return
  salvataggio.value = true
  dettaglioErrore.value = ''
  try {
    const payload = {
      titolo: selezionata.value.titolo || '',
      data_osservazione: selezionata.value.data_osservazione || null,
      squadra_avversaria: selezionata.value.squadra_avversaria || '',
      note: selezionata.value.note || ''
    }
    const res = await aggiornaSegnalazioneScouting(selezionata.value.id, payload)
    selezionata.value = res.data
    await carica()
  } catch (e) {
    dettaglioErrore.value = e.response?.data?.detail || 'Errore nel salvataggio'
  } finally {
    salvataggio.value = false
  }
}

async function cambiaStato() {
  if (!selezionata.value) return
  dettaglioErrore.value = ''
  try {
    const res = await cambiaStatoScouting(selezionata.value.id, selezionata.value.stato)
    selezionata.value = res.data
    await carica()
  } catch (e) {
    dettaglioErrore.value = e.response?.data?.detail || 'Errore nel cambio stato'
  }
}

async function elimina() {
  if (!selezionata.value) return
  if (!confirm('Eliminare definitivamente la segnalazione?')) return
  try {
    await eliminaSegnalazioneScouting(selezionata.value.id)
    chiudiDettaglio()
    await carica()
  } catch (e) {
    dettaglioErrore.value = e.response?.data?.detail || 'Errore nell\'eliminazione'
  }
}

function apriNuovoGiocatore() {
  formGiocatore.value = {
    cognome: '',
    nome: '',
    squadra: selezionata.value?.squadra_avversaria || '',
    ruolo: '',
    numero_maglia: null
  }
  nuovoGiocatoreOpen.value = true
}

async function salvaNuovoGiocatore() {
  if (!selezionata.value) return
  if (!formGiocatore.value.nome && !formGiocatore.value.cognome) {
    dettaglioErrore.value = 'Inserisci nome o cognome del giocatore'
    return
  }
  giocatoreSaving.value = true
  dettaglioErrore.value = ''
  try {
    const payload = {
      giocatori: [
        ...selezionata.value.giocatori,
        {
          nome: formGiocatore.value.nome || null,
          cognome: formGiocatore.value.cognome || null,
          squadra: formGiocatore.value.squadra || selezionata.value.squadra_avversaria || null,
          ruolo: formGiocatore.value.ruolo || null,
          numero_maglia: formGiocatore.value.numero_maglia ? Number(formGiocatore.value.numero_maglia) : null
        }
      ]
    }
    const res = await aggiornaSegnalazioneScouting(selezionata.value.id, payload)
    selezionata.value = res.data
    nuovoGiocatoreOpen.value = false
    await carica()
  } catch (e) {
    dettaglioErrore.value = e.response?.data?.detail || 'Errore nell\'aggiunta del giocatore'
  } finally {
    giocatoreSaving.value = false
  }
}

async function eliminaGiocatore(g) {
  if (!selezionata.value) return
  if (!confirm(`Rimuovere ${g.cognome || g.nome || 'il giocatore'} dalla segnalazione?`)) return
  const idx = selezionata.value.giocatori.findIndex(x => x.id === g.id)
  if (idx === -1) return
  selezionata.value.giocatori.splice(idx, 1)
  try {
    const res = await aggiornaSegnalazioneScouting(selezionata.value.id, { giocatori: selezionata.value.giocatori })
    selezionata.value = res.data
    await carica()
  } catch (e) {
    dettaglioErrore.value = e.response?.data?.detail || 'Errore nella rimozione del giocatore'
    await apriDettaglio(selezionata.value)
  }
}

function apriValutazione(g) {
  giocatoreValutato.value = g
  formValutazione.value = {
    tecnica: g.tecnica,
    velocita: g.velocita,
    resistenza: g.resistenza,
    attitudine: g.attitudine,
    posizione: g.posizione,
    gioco_di_testa: g.gioco_di_testa,
    tiro: g.tiro,
    passaggio: g.passaggio,
    dribbling: g.dribbling,
    disciplina: g.disciplina,
    note: g.note || ''
  }
  valutazioneOpen.value = true
}

async function salvaValutazione() {
  if (!giocatoreValutato.value || !selezionata.value) return
  valutazioneSaving.value = true
  try {
    const payload = {}
    for (const col of colonne) {
      const v = formValutazione.value[col.key]
      payload[col.key] = v === '' || v == null ? null : Number(v)
    }
    payload.note = formValutazione.value.note || null
    const res = await valutaGiocatoreScouting(giocatoreValutato.value.id, payload)
    const updated = res.data
    const idx = selezionata.value.giocatori.findIndex(x => x.id === updated.id)
    if (idx > -1) selezionata.value.giocatori[idx] = updated
    valutazioneOpen.value = false
    await carica()
  } catch (e) {
    alert(e.response?.data?.detail || 'Errore nel salvataggio della valutazione')
  } finally {
    valutazioneSaving.value = false
  }
}

async function esportaPDF() {
  if (!selezionata.value) return
  try {
    const doc = new jsPDF('portrait', 'mm', 'a4')
    const pageWidth = doc.internal.pageSize.getWidth()
    const margin = 14
    const contentWidth = pageWidth - margin * 2
    const accent = [220, 38, 38]
    const dark = [17, 24, 39]
    const gray = [107, 114, 128]
    const light = [248, 250, 252]
    const line = [226, 232, 240]
    const seg = selezionata.value

    const formatD = (d) => d ? String(d).split('T')[0].split('-').reverse().join('/') : '—'

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
    const logoBox = 18
    if (logoData) addLogo(logoData, margin, y, logoBox)
    if (sponsorData) addLogo(sponsorData, pageWidth - margin - logoBox, y, logoBox)
    const textX = logoData ? margin + logoBox + 4 : margin

    doc.setFont('helvetica', 'bold')
    doc.setFontSize(17)
    doc.setTextColor(...dark)
    const societyMaxWidth = pageWidth - margin - textX - (sponsorData ? logoBox + 4 : 0)
    const societyName = doc.splitTextToSize(societaAttiva.value?.nome || 'SQUADRA', societyMaxWidth)[0] || 'SQUADRA'
    doc.text(societyName, textX, y + 6)

    doc.setFontSize(8.5)
    doc.setTextColor(...accent)
    doc.text('SCHEDA SCOUTING', textX, y + 11)

    doc.setFont('helvetica', 'normal')
    doc.setFontSize(11)
    doc.setTextColor(...dark)
    doc.text(seg.titolo || 'Segnalazione scouting', textX, y + 17)

    y += logoBox + 5
    doc.setDrawColor(...accent)
    doc.setLineWidth(0.6)
    doc.line(margin, y, pageWidth - margin, y)
    y += 6

    doc.autoTable({
      startY: y,
      margin: { left: margin, right: margin, bottom: 14 },
      body: [
        ['Stato', statoLabel(seg.stato), 'Data osservazione', formatD(seg.data_osservazione)],
        ['Squadra avversaria', seg.squadra_avversaria || '—', 'Categoria', `${seg.categoria_nome || ''} ${seg.categoria_anno || ''}`.trim() || '—'],
        ['Gara', seg.gara_nome || '—', 'Data gara', formatD(seg.data_gara)],
        ['Autore', seg.autore_nome || '—', 'Creato il', formatD(seg.creato_il)]
      ],
      theme: 'grid',
      styles: { font: 'helvetica', fontSize: 8, cellPadding: 1.5, lineColor: line, lineWidth: 0.15, textColor: dark },
      columnStyles: {
        0: { cellWidth: 30, fontStyle: 'bold', fillColor: light, textColor: gray },
        1: { cellWidth: contentWidth / 2 - 30 },
        2: { cellWidth: 30, fontStyle: 'bold', fillColor: light, textColor: gray },
        3: { cellWidth: contentWidth / 2 - 30 }
      },
      pageBreak: 'avoid'
    })
    y = doc.lastAutoTable.finalY + 4

    if (seg.note) {
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(9)
      doc.setTextColor(...dark)
      doc.text('Note generali', margin, y)
      y += 4
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(8.5)
      doc.setTextColor(...gray)
      const noteLines = doc.splitTextToSize(seg.note, contentWidth)
      doc.text(noteLines, margin, y)
      y += noteLines.length * 3.9 + 4
    }

    doc.setFont('helvetica', 'bold')
    doc.setFontSize(9)
    doc.setTextColor(...dark)
    doc.text('Giocatori osservati', margin, y)
    y += 4

    const body = seg.giocatori.map((g, i) => [
      String(g.numero_maglia || i + 1),
      `${g.cognome || ''} ${g.nome || ''}`.trim() || '—',
      g.squadra || '—',
      g.ruolo || '—',
      g.tecnica ?? '—',
      g.velocita ?? '—',
      g.resistenza ?? '—',
      g.attitudine ?? '—',
      g.posizione ?? '—',
      g.gioco_di_testa ?? '—',
      g.tiro ?? '—',
      g.passaggio ?? '—',
      g.dribbling ?? '—',
      g.disciplina ?? '—',
      mediaGiocatore(g),
      g.note || ''
    ])

    doc.autoTable({
      startY: y,
      margin: { left: margin, right: margin, bottom: 14 },
      head: [['#', 'Giocatore', 'Squadra', 'Ruolo', 'Tec', 'Vel', 'Res', 'Att', 'Pos', 'Aer', 'Tir', 'Pas', 'Dri', 'Dis', 'Media', 'Note']],
      body,
      theme: 'grid',
      styles: { font: 'helvetica', fontSize: 7, cellPadding: 1.2, lineColor: line, lineWidth: 0.12, textColor: dark },
      headStyles: { fillColor: accent, textColor: [255, 255, 255], fontSize: 6.8, fontStyle: 'bold' },
      columnStyles: {
        0: { cellWidth: 8, halign: 'center' },
        1: { cellWidth: 26 },
        2: { cellWidth: 22 },
        3: { cellWidth: 16 },
        4: { cellWidth: 8, halign: 'center' },
        5: { cellWidth: 8, halign: 'center' },
        6: { cellWidth: 8, halign: 'center' },
        7: { cellWidth: 8, halign: 'center' },
        8: { cellWidth: 8, halign: 'center' },
        9: { cellWidth: 8, halign: 'center' },
        10: { cellWidth: 8, halign: 'center' },
        11: { cellWidth: 8, halign: 'center' },
        12: { cellWidth: 8, halign: 'center' },
        13: { cellWidth: 8, halign: 'center' },
        14: { cellWidth: 10, halign: 'center', fontStyle: 'bold' },
        15: { cellWidth: 'auto' }
      },
      pageBreak: 'auto'
    })

    const nomeFile = `scouting-${(seg.squadra_avversaria || 'relazione').toLowerCase().replace(/\s+/g, '-')}-${seg.data_osservazione || new Date().toISOString().split('T')[0]}.pdf`
    doc.save(nomeFile)
  } catch (e) {
    console.error(e)
    dettaglioErrore.value = 'Errore nell\'esportazione PDF'
  }
}

onMounted(async () => {
  await caricaCategorie()
  await carica()
})

watch([filtroStato, filtroCategoria], () => carica())

let ricercaTimer = null
watch(ricerca, () => {
  clearTimeout(ricercaTimer)
  ricercaTimer = setTimeout(carica, 350)
})
</script>

<style scoped>
.scouting-page {
  position: relative;
  padding: 2.5rem 2rem 4rem;
  max-width: 1200px;
  margin: 0 auto;
  overflow: hidden;
  min-height: 100vh;
}

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
  background: radial-gradient(circle, rgba(220, 38, 38, 0.08) 0%, transparent 70%);
  animation: glowFloat 9s ease-in-out infinite;
}

.bg-glow-2 {
  width: 420px;
  height: 420px;
  bottom: -120px;
  left: -80px;
  background: radial-gradient(circle, rgba(37, 99, 235, 0.08) 0%, transparent 70%);
  animation: glowFloat 11s ease-in-out infinite reverse;
}

@keyframes glowFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(22px, -16px) scale(1.04); }
  66% { transform: translate(-16px, 12px) scale(0.96); }
}

.page-header {
  position: relative;
  z-index: 1;
  margin-bottom: 2rem;
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
  background: var(--color-surface);
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
  background: var(--color-surface);
  border-radius: 50%;
  width: 24px;
  height: 24px;
  padding: 3px;
}

.btn-back-pill:hover {
  background: var(--color-slate-soft);
  border-color: var(--color-border-strong);
  color: var(--color-text);
}

.header-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(220, 38, 38, 0.08);
  border: 1px solid rgba(220, 38, 38, 0.18);
  border-radius: 100px;
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 600;
  color: #dc2626;
}

.badge-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #dc2626;
  box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.12);
}

.header-main {
  position: relative;
}

.page-title {
  font-size: clamp(2rem, 6vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.375rem;
}

.name-gradient {
  background: linear-gradient(135deg, var(--color-text) 0%, var(--color-text) 40%, #dc2626 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.header-subtitle {
  font-size: 1rem;
  color: var(--color-text-muted);
  font-weight: 400;
}

.stats-row {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
  animation: fadeSlideIn 0.6s ease-out 0.05s both;
}

.stat-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 14px;
  padding: 1rem 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  backdrop-filter: blur(12px);
}

.stat-value {
  font-size: 1.75rem;
  font-weight: 800;
  line-height: 1;
  color: var(--color-text);
}

.stat-label {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  font-weight: 500;
}

.stat-inviata .stat-value { color: #d97706; }
.stat-lavorazione .stat-value { color: #2563eb; }
.stat-completata .stat-value { color: #16a34a; }

.filters-card {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
  animation: fadeSlideIn 0.6s ease-out 0.1s both;
}

.search-wrap {
  flex: 1 1 260px;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  padding: 0 0.875rem;
  color: var(--color-text-muted);
}

.search-input {
  flex: 1;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--color-text);
  font-family: var(--font-sans);
  font-size: 0.9375rem;
  padding: 0.625rem 0;
}

.search-input::placeholder {
  color: var(--color-text-muted);
}

.filter-select {
  min-width: 180px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  color: var(--color-text);
  font-family: var(--font-sans);
  font-size: 0.875rem;
  padding: 0.5rem 0.75rem;
  outline: none;
}

.loading-wrap {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  min-height: 220px;
  color: var(--color-text-muted);
  font-size: 0.9375rem;
}

.loading-wrap.small {
  min-height: 0;
  padding: 1rem 0;
}

.spinner {
  width: 22px;
  height: 22px;
  border: 2px solid var(--color-border);
  border-top-color: #dc2626;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.error-msg {
  position: relative;
  z-index: 1;
  background: rgba(220, 38, 38, 0.08);
  border: 1px solid rgba(220, 38, 38, 0.18);
  color: #dc2626;
  border-radius: 10px;
  padding: 0.75rem 1rem;
  font-size: 0.875rem;
  margin-bottom: 1rem;
}

.segnalazioni-grid {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1rem;
}

.segnalazione-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 1.25rem;
  cursor: pointer;
  transition: all var(--transition-fast);
  backdrop-filter: blur(12px);
  animation: fadeSlideIn 0.4s ease-out both;
}

.segnalazione-card:hover {
  transform: translateY(-3px);
  border-color: rgba(220, 38, 38, 0.35);
  box-shadow: 0 14px 34px rgba(0, 0, 0, 0.12);
}

.card-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.875rem;
}

.card-date {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  color: var(--color-text-muted);
}

.card-title {
  font-size: 1.0625rem;
  font-weight: 700;
  color: var(--color-text);
  margin-bottom: 0.25rem;
  line-height: 1.3;
}

.card-squadra {
  font-size: 0.875rem;
  color: #dc2626;
  font-weight: 600;
  margin-bottom: 0.875rem;
}

.card-meta {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  margin-bottom: 1rem;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.8125rem;
  color: var(--color-text-secondary);
}

.meta-item svg {
  width: 14px;
  height: 14px;
  flex-shrink: 0;
  color: var(--color-text-muted);
}

.card-players {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.player-chip {
  background: var(--color-slate-soft);
  border: 1px solid var(--color-border);
  color: var(--color-text-secondary);
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.25rem 0.5rem;
  border-radius: 999px;
}

.player-chip.more {
  background: rgba(220, 38, 38, 0.08);
  border-color: rgba(220, 38, 38, 0.18);
  color: #dc2626;
}

.empty-state {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 4rem 1rem;
  text-align: center;
}

.empty-icon {
  color: var(--color-text-muted);
  opacity: 0.35;
  margin-bottom: 0.5rem;
}

.empty-title {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}

.empty-sub {
  font-size: 0.9375rem;
  color: var(--color-text-muted);
  max-width: 360px;
}

.stato-pill {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.625rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}

.stato-inviata {
  background: rgba(217, 119, 6, 0.1);
  border: 1px solid rgba(217, 119, 6, 0.2);
  color: #d97706;
}

.stato-in_lavorazione {
  background: rgba(37, 99, 235, 0.1);
  border: 1px solid rgba(37, 99, 235, 0.2);
  color: #2563eb;
}

.stato-completata {
  background: rgba(22, 163, 74, 0.1);
  border: 1px solid rgba(22, 163, 74, 0.2);
  color: #16a34a;
}

.detail-overlay {
  position: fixed;
  inset: 0;
  z-index: 50;
  background: rgba(0, 0, 0, 0.45);
  backdrop-filter: blur(6px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
  animation: fadeIn 0.2s ease-out;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.detail-panel {
  width: 100%;
  max-width: 960px;
  max-height: calc(100vh - 3rem);
  overflow-y: auto;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: 18px;
  padding: 1.5rem;
  box-shadow: 0 28px 80px rgba(0, 0, 0, 0.28);
  animation: slideUp 0.25s ease-out;
}

@keyframes slideUp {
  from { transform: translateY(14px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

.detail-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.detail-title {
  flex: 1;
  background: transparent;
  border: 0;
  outline: 0;
  color: var(--color-text);
  font-family: var(--font-sans);
  font-size: 1.375rem;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.detail-title::placeholder {
  color: var(--color-text-muted);
}

.icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 10px;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.icon-btn:hover {
  color: var(--color-text);
  border-color: var(--color-border-strong);
}

.detail-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.875rem;
  margin-bottom: 1rem;
}

.detail-field {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.detail-field > span {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.detail-input,
.detail-select,
.detail-textarea {
  width: 100%;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  color: var(--color-text);
  font-family: var(--font-sans);
  font-size: 0.9375rem;
  padding: 0.5rem 0.75rem;
  outline: none;
}

.detail-input:focus,
.detail-select:focus,
.detail-textarea:focus {
  border-color: rgba(220, 38, 38, 0.4);
  box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.08);
}

.detail-textarea {
  resize: vertical;
  min-height: 90px;
}

.detail-static {
  font-size: 0.9375rem;
  color: var(--color-text);
  padding: 0.5rem 0;
}

.detail-note {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  margin-bottom: 1rem;
}

.detail-note > span {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.detail-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.625rem;
  margin-bottom: 1.5rem;
}

.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  border: 1px solid transparent;
  border-radius: 10px;
  font-family: var(--font-sans);
  font-size: 0.875rem;
  font-weight: 600;
  padding: 0.55rem 1rem;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.btn-primary {
  background: #dc2626;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #b91c1c;
}

.btn-ghost {
  background: var(--color-surface);
  border-color: var(--color-border);
  color: var(--color-text-secondary);
}

.btn-ghost:hover:not(:disabled) {
  color: var(--color-text);
  border-color: var(--color-border-strong);
}

.btn-danger {
  background: rgba(220, 38, 38, 0.08);
  border-color: rgba(220, 38, 38, 0.2);
  color: #dc2626;
}

.btn-danger:hover:not(:disabled) {
  background: rgba(220, 38, 38, 0.14);
}

.btn-sm {
  padding: 0.4rem 0.75rem;
  font-size: 0.8125rem;
}

.players-section {
  border-top: 1px solid var(--color-border);
  padding-top: 1.25rem;
}

.players-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.players-header h3 {
  font-size: 1.0625rem;
  font-weight: 700;
  color: var(--color-text);
}

.players-table-wrap {
  overflow-x: auto;
  border: 1px solid var(--color-border);
  border-radius: 12px;
}

.players-table {
  width: 100%;
  border-collapse: collapse;
  min-width: 720px;
}

.players-table th,
.players-table td {
  padding: 0.75rem 0.875rem;
  text-align: left;
  font-size: 0.875rem;
  border-bottom: 1px solid var(--color-border);
}

.players-table th {
  background: var(--color-slate-soft);
  color: var(--color-text-muted);
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.players-table tbody tr:last-child td {
  border-bottom: 0;
}

.maglia {
  font-family: var(--font-mono);
  font-weight: 700;
  color: var(--color-text);
}

.player-name {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
}

.player-name b {
  color: var(--color-text);
}

.player-name span {
  font-size: 0.75rem;
  color: var(--color-text-muted);
}

.media-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 38px;
  padding: 0.25rem 0.5rem;
  border-radius: 8px;
  font-family: var(--font-mono);
  font-size: 0.8125rem;
  font-weight: 700;
  background: var(--color-slate-soft);
  color: var(--color-text-secondary);
}

.media-bassa {
  background: rgba(220, 38, 38, 0.1);
  color: #dc2626;
}

.media-media {
  background: rgba(217, 119, 6, 0.1);
  color: #d97706;
}

.media-alta {
  background: rgba(22, 163, 74, 0.1);
  color: #16a34a;
}

.note-cell {
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--color-text-secondary);
}

.actions-cell {
  display: flex;
  gap: 0.375rem;
  justify-content: flex-end;
}

.mini-btn {
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.35rem 0.625rem;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.mini-btn:hover {
  color: var(--color-text);
  border-color: var(--color-border-strong);
}

.mini-btn.danger {
  color: #dc2626;
  border-color: rgba(220, 38, 38, 0.2);
}

.mini-btn.danger:hover {
  background: rgba(220, 38, 38, 0.08);
}

.empty-row {
  text-align: center;
  color: var(--color-text-muted);
  padding: 1.5rem !important;
}

.modal-overlay {
  position: fixed;
  inset: 0;
  z-index: 60;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(6px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
  animation: fadeIn 0.2s ease-out;
}

.modal-panel {
  width: 100%;
  max-width: 640px;
  max-height: calc(100vh - 3rem);
  overflow-y: auto;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: 18px;
  padding: 1.5rem;
  box-shadow: 0 28px 80px rgba(0, 0, 0, 0.28);
  animation: slideUp 0.25s ease-out;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.25rem;
}

.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 800;
  color: var(--color-text);
  line-height: 1.3;
}

.val-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.875rem;
  margin-bottom: 1rem;
}

.val-item {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.val-label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.rating-group {
  display: flex;
  gap: 0.375rem;
}

.rating-btn {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  border: 1px solid var(--color-border);
  background: var(--color-bg);
  color: var(--color-text-secondary);
  font-family: var(--font-mono);
  font-size: 0.875rem;
  font-weight: 700;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.rating-btn:hover {
  border-color: var(--color-border-strong);
  color: var(--color-text);
}

.rating-btn.level-1.active {
  background: #dc2626;
  border-color: #dc2626;
  color: white;
}

.rating-btn.level-2.active {
  background: #d97706;
  border-color: #d97706;
  color: white;
}

.rating-btn.level-3.active {
  background: #16a34a;
  border-color: #16a34a;
  color: white;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.875rem;
  margin-bottom: 1rem;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.625rem;
  margin-top: 1rem;
}

@media (max-width: 768px) {
  .scouting-page {
    padding: 1.5rem 1rem 3rem;
  }

  .stats-row {
    grid-template-columns: 1fr;
  }

  .filters-card {
    flex-direction: column;
  }

  .filter-select {
    width: 100%;
  }

  .segnalazioni-grid {
    grid-template-columns: 1fr;
  }

  .detail-overlay,
  .modal-overlay {
    padding: 1rem;
  }

  .detail-panel,
  .modal-panel {
    max-height: calc(100vh - 2rem);
    padding: 1rem;
  }

  .detail-grid {
    grid-template-columns: 1fr;
  }

  .val-grid,
  .form-grid {
    grid-template-columns: 1fr;
  }

  .detail-actions,
  .modal-actions {
    flex-direction: column;
  }

  .btn {
    width: 100%;
  }
}
</style>
