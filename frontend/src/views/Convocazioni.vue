<template>
  <div class="conv-page">
    <header class="page-header">
      <div class="header-left">
        <button class="hamburger" @click="mobileMenuOpen = true" aria-label="Menu">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="3" y1="6" x2="21" y2="6"/>
            <line x1="3" y1="12" x2="21" y2="12"/>
            <line x1="3" y1="18" x2="21" y2="18"/>
          </svg>
        </button>
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
      <span class="titolo-toolbar">Convocazioni — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
      <button class="btn-nuovo" @click="nuovaConvocazione">+ Nuovo</button>
    </header>

    <div v-if="mobileMenuOpen" class="mobile-menu-overlay" @click="mobileMenuOpen = false">
      <div class="mobile-menu" @click.stop>
        <div class="mobile-menu-header">
          <span>Menu Convocazioni</span>
          <button class="mobile-menu-close" @click="mobileMenuOpen = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
        <div class="mobile-menu-content">
          <button class="mobile-menu-item" @click="scrollToStorico">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12 6 12 12 16 14"/>
            </svg>
            Storico
          </button>
          <button class="mobile-menu-item" @click="scrollToMister">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87"/>
              <path d="M16 3.13a4 4 0 010 7.75"/>
            </svg>
            Mister
          </button>
          <button class="mobile-menu-item" @click="nuovaConvocazione(); mobileMenuOpen = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <line x1="12" y1="8" x2="12" y2="16"/>
              <line x1="8" y1="12" x2="16" y2="12"/>
            </svg>
            Nuovo Weekend
          </button>
          <button class="mobile-menu-item" @click="router.push('/'); mobileMenuOpen = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
              <polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
            Home
          </button>
        </div>
      </div>
    </div>

    <div class="conv-body">
      <!-- SIDEBAR SINISTRA -->
      <div class="left-sidebar">
        <!-- STORICO -->
        <div class="sidebar-section">
          <div class="sidebar-title">📅 Storico</div>
          <div v-for="c in storico" :key="c.id"
            :class="['storico-item', { attivo: convocazioneId === c.id }]"
            @click="caricaConvocazione(c.id)">
            WE {{ formatDataShort(c.data_inizio) }}{{ c.data_fine ? ' - ' + formatDataShort(c.data_fine) : '' }}
          </div>
        </div>

        <!-- RESPONSABILI -->
        <div class="sidebar-section misters-section">
          <div class="sidebar-title">👥 Mister</div>
          <div v-for="r in responsabili" :key="r.id" class="mister-item">
            <span class="mister-cognome">{{ r.cognome }}</span>
            <span class="mister-tel">{{ r.cellulare }}</span>
          </div>
          <div v-if="responsabili.length === 0" class="empty-misters">
            Nessun mister assegnato
          </div>
        </div>
      </div>

      <!-- EDITOR -->
      <div class="editor" v-if="convocazione">
        <div class="editor-header">
          <div class="field-row">
            <input type="date" v-model="convocazione.data_inizio" />
          </div>
          <div class="field-row">
            <input type="date" v-model="convocazione.data_fine" />
          </div>
          <div class="field-row">
            <input type="number" min="1" max="7" v-model.number="numPartite" @change="aggiustaGare" style="width:60px" />
          </div>
          <div class="actions">
            <button class="btn-salva" @click="salva">💾 Salva</button>
            <button class="btn-del" @click="elimina">🗑 Elimina</button>
            <button class="btn-export" @click="esportaPDF">📄 Esporta PDF</button>
          </div>
        </div>

        <!-- BOX NON CONVOCABILI -->
        <div class="esclusi-editor-box" v-if="convocazione">
          <span class="esclusi-label">⚠️ NON CONVOCABILI</span>
          <span class="esclusi-period" v-if="convocazione.data_inizio">
            (Lun-Ven {{ getSettimanaLabel(convocazione.data_inizio) }})
          </span>
          <span v-for="p in getAllEsclusi()" :key="p.id" class="escluso-tag">
            {{ p.cognome }} {{ p.nome }}
          </span>
          <span v-if="getAllEsclusi().length === 0" class="esclusi-none">Nessuno</span>
        </div>

        <!-- BOX ESCLUSIONI MANUALI -->
        <div class="esclusioni-manuali" v-if="convocazione">
          <div class="esclusi-manuali-box" v-for="tipo in ['no_sabato_mattina', 'no_sabato_pomeriggio', 'no_domenica']" :key="tipo">
            <div class="esclusi-manuali-header">
              <span class="esclusi-manuali-titolo">{{ tipo.replace(/_/g, ' ').toUpperCase() }}</span>
              <select @change="toggleEsclusione(tipo, $event)" class="esclusi-select">
                <option value="">+ Aggiungi giocatore</option>
                <option v-for="p in getGiocatoriDisponibili(tipo)" :key="p.id" :value="p.id">
                  {{ p.cognome }} {{ p.nome }}
                </option>
              </select>
            </div>
            <div class="esclusi-manuali-tags">
              <span v-for="p in getEsclusiPerTipo(tipo)" :key="p.id" class="escluso-tag" @click="toggleEsclusione(tipo, p.id)">
                {{ p.cognome }} {{ p.nome }} ×
              </span>
              <span v-if="getEsclusiPerTipo(tipo).length === 0" class="esclusi-none">Nessuno</span>
            </div>
          </div>
        </div>

        <!-- GARE -->
        <div class="gare-scroll">
          <div class="gare-grid" :style="{ gridTemplateColumns: 'repeat(' + convocazione.gare.length + ', minmax(220px, 1fr))' }">
            <!-- HEADER -->
            <div class="gare-header-full" :style="{ gridColumn: '1 / -1' }">
              <img v-if="societaAttiva?.logosponsor" :src="'/uploads/' + societaAttiva.logosponsor" alt="logo" class="logo-rt logo-left" />
              <img v-else src="/logosponsor.png" alt="logo" class="logo-rt logo-left" />
              <div class="header-rt-text">
                <div class="header-rt-title">{{ societaAttiva?.nome || 'SQUADRA' }}</div>
                <div class="header-rt-subtitle">CONVOCAZIONE GARE</div>
                <div class="header-rt-category">{{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</div>
              </div>
              <img v-if="societaAttiva?.logo" :src="'/uploads/' + societaAttiva.logo" alt="logo" class="logo-rt logo-right" />
              <img v-else src="/logo.jpg" alt="logo" class="logo-rt logo-right" />
            </div>
            <div v-for="(gara, gi) in convocazione.gare" :key="gi" class="gara-col">
              <div class="gara-header">
                <input v-model="gara.gara" placeholder="Squadra A - Squadra B" class="gara-title-input" />
              </div>
              <div class="gara-fields">
                <div class="gf-row">
                  <span class="gf-label">DATA</span>
                  <input type="date" v-model="gara.data" class="gf-input" />
                </div>
                <div class="gf-row">
                  <span class="gf-label">CAMPO</span>
                  <input v-model="gara.campo" class="gf-input" />
                </div>
                <div class="gf-row">
                  <span class="gf-label">INDIRIZZO</span>
                  <input v-model="gara.indirizzo" class="gf-input" />
                </div>
                <div class="gf-row">
                  <span class="gf-label">APPUNTAMENTO</span>
                  <input v-model="gara.appuntamento" class="gf-input" />
                </div>
                <div class="gf-row">
                  <span class="gf-label">INIZIO GARA</span>
                  <input v-model="gara.inizio_gara" class="gf-input" />
                </div>
                <div class="gf-row">
                  <span class="gf-label">MISTER</span>
                  <select v-model="gara.allenatore" class="gf-input">
                    <option value="">— Seleziona —</option>
                    <option v-for="r in responsabili" :key="r.id" :value="r.cognome">
                      {{ r.cognome }} - {{ r.cellulare }}
                    </option>
                  </select>
                </div>
              </div>
              <div class="giocatori-list">
                <div v-for="pos in 14" :key="pos" class="giocatore-row">
                  <span class="pos-num">{{ pos }}</span>
                  <select v-model="gara.giocatori[pos-1]">
                    <option :value="null">—</option>
                    <option v-for="p in getGiocatoriSettimanaPrecedente()" :key="p.id" :value="p.id">{{ getCognomeDisplay(p) }}</option>
                  </select>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- NOTE -->
        <div class="note-section">
          <textarea v-model="convocazione.note" rows="6"></textarea>
        </div>
      </div>

      <div v-else class="empty-state">
        Seleziona un weekend dallo storico oppure crea una nuova convocazione.
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, getRegistroMese } from '../api/index.js'
import axios from 'axios'
import { jsPDF } from 'jspdf'
import html2canvas from 'html2canvas'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva, societaAttiva } = useStore()
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

function scrollToStorico() {
  mobileMenuOpen.value = false
  const el = document.querySelector('.sidebar-section:first-child')
  if (el) el.scrollIntoView({ behavior: 'smooth' })
}

function scrollToMister() {
  mobileMenuOpen.value = false
  const el = document.querySelector('.misters-section')
  if (el) el.scrollIntoView({ behavior: 'smooth' })
}

const oggi = new Date()
const annoCorrente = oggi.getFullYear()
const meseCorrente = oggi.getMonth() + 1

function getGiocatoriSettimanaPrecedente() {
  if (!convocazione.value || !convocazione.value.data_inizio) return persone.value
  
  const range = getWeekDateRange(convocazione.value.data_inizio)
  if (!range) return persone.value
  
  const presenzeCount = {}
  const assenzeCount = {}
  
  registro.value
    .filter(r => r.data >= range.monday && r.data <= range.friday)
    .forEach(r => {
      if (['X', 'P', 'R'].includes(r.codice)) {
        presenzeCount[r.persona_id] = (presenzeCount[r.persona_id] || 0) + 1
      }
      if (['AI', 'AG'].includes(r.codice)) {
        assenzeCount[r.persona_id] = (assenzeCount[r.persona_id] || 0) + 1
      }
    })
  
  return persone.value.filter(p => presenzeCount[p.id] >= 2 && (assenzeCount[p.id] || 0) < 2)
}

function getWeekDateRange(dataGara) {
  if (!dataGara) return null
  
  const data = new Date(dataGara)
  const dayOfWeek = data.getDay()
  
  // Find the Saturday of the weekend (or use the given date if it's Sat/Sun)
  let weekendSat = new Date(data)
  if (dayOfWeek === 0) {
    // Sunday - go back 1 day to Saturday
    weekendSat.setDate(data.getDate() - 1)
  } else if (dayOfWeek !== 6) {
    // Not weekend - assume this is the Saturday
    weekendSat = new Date(data)
  }
  
  // Go back to the Monday of the week before the weekend
  const daysToPrevMonday = weekendSat.getDay() === 0 ? 2 : weekendSat.getDay() + 1
  const mondayPrev = new Date(weekendSat)
  mondayPrev.setDate(weekendSat.getDate() - daysToPrevMonday)
  
  // Friday is Monday + 4
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
  registro.value
    .filter(r => r.data >= range.monday && r.data <= range.friday && ['AI', 'AG'].includes(r.codice))
    .forEach(r => {
      assenzeCount[r.persona_id] = (assenzeCount[r.persona_id] || 0) + 1
    })
  
  return persone.value
    .filter(p => assenzeCount[p.id] >= 2)
    .sort((a, b) => a.cognome.localeCompare(b.cognome))
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
  if (!convocazione.value.esclusioni) {
    convocazione.value.esclusioni = []
  }
  
  let personaId
  if (typeof eventOrId === 'object') {
    personaId = parseInt(eventOrId.target.value)
    eventOrId.target.value = ''
  } else {
    personaId = parseInt(eventOrId)
  }
  
  if (!personaId) return
  
  const existingIdx = convocazione.value.esclusioni.findIndex(
    e => e.tipo === tipo && e.persona_id === personaId
  )
  
  if (existingIdx >= 0) {
    convocazione.value.esclusioni.splice(existingIdx, 1)
  } else {
    convocazione.value.esclusioni.push({ tipo, persona_id: personaId })
  }
}

function getAssentiEsclusi(dataGara) {
  if (!dataGara) return []
  
  const range = getWeekDateRange(dataGara)
  if (!range) return []
  
  const assenzeCount = {}
  registro.value
    .filter(r => r.data >= range.monday && r.data <= range.friday && ['AI', 'AG'].includes(r.codice))
    .forEach(r => {
      assenzeCount[r.persona_id] = (assenzeCount[r.persona_id] || 0) + 1
    })
  
  return persone.value.filter(p => assenzeCount[p.id] >= 2)
}

function getCognomeDisplay(p) {
  const sameCognomi = persone.value.filter(x => x.cognome === p.cognome)
  if (sameCognomi.length > 1) {
    return `${p.cognome} ${p.nome.charAt(0)}.`
  }
  return p.cognome
}

function aggiustaGare() {
  const n = numPartite.value
  const gare = convocazione.value.gare
  while (gare.length < n) gare.push(garaVuota(gare.length + 1))
  if (gare.length > n) gare.splice(n)
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
  return {
    numero,
    gara: '', data: '', campo: '', indirizzo: '',
    appuntamento: '', inizio_gara: '', allenatore: '',
    giocatori: Array(14).fill(null)
  }
}

function nuovaConvocazione() {
  convocazioneId.value = null
  numPartite.value = 1
  const oggi = new Date().toISOString().split('T')[0]
  const domani = new Date()
  domani.setDate(domani.getDate() + 1)
  const domenica = domani.toISOString().split('T')[0]
  convocazione.value = {
    data_inizio: oggi,
    data_fine: domenica,
    esclusioni: [],
    note: `PRESENTARSI ALL'APPUNTAMENTO IN ORARIO STABILITO ED IN TENUTA DA RAPPRESENTANZA GEMS (NO GIA CAMBIATI).
SI GIOCA CON KIT GARA* (MAGLIA CALZONCINI E CALZETTONI) PORTARE FELPA D'ALLENAMENTO PER RISCALDAMENTO E K-WAY IN BORSA PER L'EVENIENZA.
AVVISARE TEMPESTIVAMENTE L'ALLENATORE PRESENTE IN GARA IN CASO DI RITARDO O ASSENZA.
*PORTARE COMUNQUE MAGLIA DI RICAMBIO, CALZONCINI E CALZETTONI PER MODIFICARE I COLORI IN BASE ALL'AVVERSARIO.`,
    gare: [garaVuota(1)]
  }
}

async function caricaConvocazione(id) {
  convocazioneId.value = id
  const res = await axios.get(base + '/convocazioni/' + id, { headers: headers() })
  const d = res.data
  
  // Carica registro per il mese della gara se diversa da quello corrente
  const garaData = d.gare[0]?.data
  if (garaData) {
    const [y, m] = garaData.split('-')
    if (parseInt(m) !== meseCorrente || parseInt(y) !== annoCorrente) {
      const regRes = await getRegistroMese(categoriaId, parseInt(y), parseInt(m))
      registro.value = regRes.data
    }
  }
  
  convocazione.value = {
    data_inizio: d.data_inizio,
    data_fine: d.data_fine || '',
    esclusioni: d.esclusioni || [],
    note: d.note || '',
    gare: d.gare.map((g, idx) => ({
      ...g,
      numero: g.numero || idx + 1,
      data: g.data || '',
      giocatori: Array.from({ length: 14 }, (_, i) => {
        const gk = g.giocatori.find(x => x.posizione === i + 1)
        return gk ? gk.persona_id : null
      })
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
  } catch (e) {
    console.error('Errore caricamento responsabili:', e)
    responsabili.value = []
  }
}

async function salva() {
  const payload = {
    categoria_id: categoriaId,
    data_inizio: convocazione.value.data_inizio,
    data_fine: convocazione.value.data_fine,
    esclusioni: convocazione.value.esclusioni || [],
    note: convocazione.value.note,
    gare: convocazione.value.gare.map((g, gi) => ({
      numero: gi + 1,
      gara: g.gara, data: g.data || null, campo: g.campo,
      indirizzo: g.indirizzo, appuntamento: g.appuntamento,
      inizio_gara: g.inizio_gara, allenatore: g.allenatore,
      giocatori: g.giocatori
        .map((pid, i) => pid ? { persona_id: pid, posizione: i + 1 } : null)
        .filter(Boolean)
    }))
  }
  if (convocazioneId.value) {
    await axios.put(base + '/convocazioni/' + convocazioneId.value, payload, { headers: headers() })
  } else {
    const res = await axios.post(base + '/convocazioni/', payload, { headers: headers() })
    convocazioneId.value = res.data.id
  }
  await loadStorico()
  alert('Salvato!')
}

async function esportaPDF() {
  if (!convocazione.value) return
  
  const gareGridEl = document.querySelector('.gare-grid')
  if (!gareGridEl) {
    alert('Elemento non trovato')
    return
  }
  
  try {
    const canvas = await html2canvas(gareGridEl, {
      scale: 1.5,
      useCORS: true,
      logging: false,
      backgroundColor: '#ffffff',
      width: gareGridEl.scrollWidth,
      height: gareGridEl.scrollHeight,
      windowWidth: gareGridEl.scrollWidth,
      windowHeight: gareGridEl.scrollHeight
    })
    
    const pdf = new jsPDF('landscape', 'mm', 'a4')
    const pdfWidth = pdf.internal.pageSize.getWidth()
    
    const ratio = (pdfWidth - 20) / canvas.width
    const finalWidth = pdfWidth - 20
    
    pdf.addImage(canvas.toDataURL('image/png'), 'PNG', 10, 10, finalWidth, canvas.height * ratio)
    
    if (convocazione.value.note) {
      const noteY = 10 + (canvas.height * ratio) + 5
      pdf.setFillColor(220, 38, 38)
      const noteText = convocazione.value.note
      pdf.setTextColor(255, 255, 255)
      pdf.setFontSize(8)
      const maxWidth = finalWidth - 20
      const lines = pdf.splitTextToSize(noteText, maxWidth)
      const lineHeight = 4.5
      const noteHeight = lines.length * lineHeight + 12
      pdf.rect(10, noteY, finalWidth, noteHeight, 'F')
      pdf.text(lines, 15, noteY + 8)
    }
    
    const categoriaNome = categoriaAttiva.value?.nome || 'Categoria'
    const dataInizio = convocazione.value.data_inizio || ''
    const dataFine = convocazione.value.data_fine || ''
    const dataFormattata = dataInizio ? dataInizio.split('-').reverse().join('/') : 'data'
    const dataFinale = dataFine ? dataInizio.split('-').reverse().join('/') + ' - ' + dataFine.split('-').reverse().join('/') : dataFormattata
    pdf.save('Convocazioni ' + categoriaNome + ' del ' + dataFinale + '.pdf')
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
}

onMounted(async () => {
  const res = await getPersone(categoriaId)
  persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
  const regRes = await getRegistroMese(categoriaId, annoCorrente, meseCorrente)
  registro.value = regRes.data
  await loadStorico()
  await loadMisters()
})
</script>

<style scoped>
.conv-page { display: flex; flex-direction: column; height: 100vh; width: 100%; max-width: none; }
.editor { flex: 1; overflow-y: auto; padding: 1rem; width: 100%; max-width: none; }
.toolbar { display: flex; align-items: center; gap: 0.8rem; padding: 0.5rem 1rem; background: var(--color-primary); color: white; flex-shrink: 0; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 0.95rem; }
.btn-back { padding: 4px 12px; border-radius: 4px; border: 1px solid #555; background: #2a2a4a; color: white; cursor: pointer; }
.btn-nuovo { padding: 4px 14px; border-radius: 4px; border: none; background: var(--color-primary); color: white; cursor: pointer; font-weight: bold; }
.conv-body { display: flex; flex: 1; overflow: hidden; }

.gare-header-full { background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-primary) 100%); color: white; padding: 10px 10px; display: flex; align-items: center; justify-content: center; gap: 1.5rem; border-radius: 8px 8px 0 0; }
.logo-rt { width: 70px; height: 70px; object-fit: contain; border-radius: 50%; background: white; padding: 2px; margin: 0; }
.header-rt-text { text-align: center; }
.header-rt-title { font-size: 1.5rem; font-weight: 900; letter-spacing: 3px; }
.header-rt-subtitle { font-size: 1rem; font-weight: 600; letter-spacing: 2px; margin-top: 2px; }
.header-rt-category { font-size: 1.1rem; font-weight: 700; margin-top: 4px; color: #ffd700; }

.left-sidebar {
  width: 180px;
  flex-shrink: 0;
  background: #f5f5f5;
  border-right: 1px solid #ddd;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
}

.sidebar-section {
  padding: 0.75rem;
  border-bottom: 1px solid #ddd;
}

.sidebar-section:last-child {
  border-bottom: none;
  flex: 1;
}

.sidebar-title {
  font-weight: bold;
  font-size: 0.75rem;
  color: #555;
  margin-bottom: 0.5rem;
  padding-bottom: 0.3rem;
  border-bottom: 1px solid #ddd;
}

.storico-item { padding: 6px 8px; border-radius: 4px; cursor: pointer; font-size: 0.8rem; margin-bottom: 3px; background: #f5f5f5; color: #333; }
.storico-item:hover { background: #e0e0e0; }
.storico-item.attivo { background: var(--color-primary); color: white; }

.misters-section { background: #fff8f8; }
.mister-item {
  background: white;
  border: 1px solid #eee;
  border-radius: 6px;
  padding: 8px 10px;
  margin-bottom: 6px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.mister-cognome { font-weight: 600; font-size: 0.85rem; color: #333; display: flex; align-items: center; gap: 4px; }
.badge-dir { font-size: 0.6rem; background: #2563eb; color: white; padding: 1px 4px; border-radius: 3px; font-weight: 700; }
.mister-tel { font-size: 0.75rem; color: #666; }
.empty-misters { font-size: 0.75rem; color: #aaa; text-align: center; padding: 0.5rem; }

.editor { flex: 1; overflow-y: auto; padding: 1rem; }
.editor-header { display: flex; align-items: center; gap: 1.5rem; flex-wrap: wrap; margin-bottom: 1rem; padding-bottom: 0.8rem; border-bottom: 2px solid #eee; }
.field-row { display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem; }
.field-row input { padding: 4px 8px; border: 1px solid #ddd; border-radius: 4px; }
.actions { display: flex; gap: 0.5rem; margin-left: auto; }
.btn-salva { padding: 6px 18px; background: var(--color-primary); color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; }
.btn-del { padding: 6px 14px; background: var(--color-primary); color: white; border: none; border-radius: 4px; cursor: pointer; }
.gare-scroll { overflow-x: auto; width: 100%; -webkit-overflow-scrolling: touch; }
.gare-grid { display: grid; gap: 1rem; min-width: max-content; width: 100%; }
.gara-col { background: white; border: 1px solid #ddd; border-radius: 8px; min-width: 320px; }
.gara-header { background: var(--color-primary); color: white; font-weight: bold; padding: 10px 14px; font-size: 1.1rem; display: flex; align-items: center; justify-content: center; gap: 0.5rem; min-height: 50px; }
.gara-header span { flex-shrink: 0; }
.gara-title-input { flex: 1; min-width: 0; background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); border-radius: 4px; padding: 8px 14px; color: white; font-size: 1.1rem; font-weight: 700; text-align: center; line-height: 1.2; }
.gara-title-input::placeholder { color: rgba(255,255,255,0.6); }
.gara-title-input::-webkit-calendar-picker-indicator { filter: invert(1); }
.gara-fields { padding: 0.5rem; border-bottom: 2px solid #eee; min-height: 180px; box-sizing: border-box; }
.gf-row { display: flex; align-items: center; margin-bottom: 6px; gap: 0.5rem; }
.gf-label { font-size: 0.65rem; color: #888; font-weight: bold; text-transform: uppercase; min-width: 80px; flex-shrink: 0; }
.gf-input { flex: 1; border: 1px solid #eee; border-radius: 3px; padding: 4px 6px; font-size: 0.8rem; height: 28px; box-sizing: border-box; }
.gf-row:last-child { margin-bottom: 0; }
.gf-input select { height: 100%; }
.giocatori-list { padding: 0.5rem; box-sizing: border-box; }
.giocatore-row { display: flex; align-items: center; gap: 6px; margin-bottom: 2px; height: 28px; }
.esclusi-editor-box { background: #fff3cd; border: 2px solid #ffc107; border-radius: 6px; padding: 0.75rem 1rem; margin-bottom: 1rem; display: flex; flex-wrap: wrap; align-items: center; gap: 0.5rem; }
.esclusi-label { font-size: 0.85rem; font-weight: bold; color: #856404; }
.esclusi-period { font-size: 0.8rem; color: #856404; }
.escluso-tag { background: #dc3545; color: white; padding: 4px 12px; border-radius: 15px; font-size: 0.8rem; font-weight: 600; cursor: pointer; }
.esclusi-none { font-size: 0.85rem; color: #666; }
.esclusioni-manuali { display: flex; gap: 0.5rem; margin-bottom: 1rem; flex-wrap: wrap; }
.esclusi-manuali-box { background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 6px; padding: 0.5rem; flex: 1; min-width: 200px; }
.esclusi-manuali-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
.esclusi-manuali-titolo { font-size: 0.7rem; font-weight: bold; color: #495057; }
.esclusi-select { font-size: 0.75rem; padding: 2px 4px; border: 1px solid #ced4da; border-radius: 4px; max-width: 140px; }
.esclusi-manuali-tags { display: flex; flex-wrap: wrap; gap: 0.25rem; }
.escluso-tag { background: #6c757d; color: white; padding: 2px 8px; border-radius: 10px; font-size: 0.7rem; font-weight: 600; cursor: pointer; }
.escluso-item { font-size: 0.75rem; color: #856404; padding: 2px 0; font-weight: 600; }
.escluso-none { font-size: 0.7rem; color: #6c757d; font-style: italic; }
.pos-num { width: 18px; text-align: right; font-size: 0.8rem; color: #888; flex-shrink: 0; }
.giocatore-row select { flex: 1; min-width: 150px; font-size: 1rem; padding: 6px 12px; border: 1px solid #eee; border-radius: 3px; }
.note-section { margin-top: 1rem; }
.note-section label { font-size: 0.8rem; font-weight: bold; color: #555; display: block; margin-bottom: 4px; }
.note-section textarea { width: 100%; border: 1px solid var(--color-primary); border-radius: 4px; padding: 10px; font-size: 0.7rem; resize: vertical; background: var(--color-primary); color: white; font-weight: bold; white-space: pre-wrap; word-wrap: break-word; min-height: 120px; line-height: 1.3; }
.empty-state { flex: 1; display: flex; align-items: center; justify-content: center; color: #aaa; font-size: 1rem; }

.page-header { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1rem; background: var(--color-primary); }
.header-left { display: flex; align-items: center; gap: 0.25rem; }
.btn-back, .btn-home, .hamburger { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; transition: background 0.2s; }
.btn-back:hover, .btn-home:hover, .hamburger:hover { background: rgba(255,255,255,0.2); }
.btn-back svg, .btn-home svg, .hamburger svg { width: 18px; height: 18px; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 1rem; color: white; }
.btn-nuovo { padding: 6px 14px; border-radius: 6px; border: none; background: rgba(255,255,255,0.2); color: white; cursor: pointer; font-size: 0.85rem; font-weight: 600; }
.btn-nuovo:hover { background: rgba(255,255,255,0.3); }

.mobile-menu-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.7);
  z-index: 200;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(4px);
}

.mobile-menu {
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 280px;
  max-width: 85vw;
  background: #1a1a1a;
  animation: slideInLeft 0.3s ease-out;
  overflow-y: auto;
  box-shadow: 4px 0 20px rgba(0,0,0,0.5);
}

.mobile-menu-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  font-weight: 700;
  color: white;
  background: var(--color-primary);
}

.mobile-menu-close {
  background: transparent;
  border: none;
  color: white;
  cursor: pointer;
  padding: 0.25rem;
  border-radius: 4px;
}

.mobile-menu-close:hover { background: rgba(255,255,255,0.1); }
.mobile-menu-close svg { width: 24px; height: 24px; }

.mobile-menu-content {
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.mobile-menu-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 10px;
  color: white;
  font-size: 0.95rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  width: 100%;
  text-align: left;
}

.mobile-menu-item:hover {
  background: rgba(255,255,255,0.12);
  transform: translateX(4px);
}

.mobile-menu-item svg { width: 20px; height: 20px; flex-shrink: 0; }

@keyframes slideInLeft {
  from { transform: translateX(-100%); }
  to { transform: translateX(0); }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@media (min-width: 769px) {
  .hamburger { display: none; }
  .mobile-menu-overlay { display: none; }
}

@media (max-width: 768px) {
  .left-sidebar { display: none !important; }
  .conv-body { flex-direction: column; }
}
</style>
