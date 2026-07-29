<template>
  <div class="rotate-device-overlay" v-if="showRotateMessage">
    <div class="rotate-device-message">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="80" height="80">
        <rect x="4" y="2" width="16" height="20" rx="2" ry="2"/>
        <line x1="12" y1="18" x2="12" y2="18"/>
      </svg>
      <span>Ruota il dispositivo in orizzontale</span>
    </div>
  </div>
  <div class="allenamenti-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/scelta/' + route.params.id)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          Indietro
        </button>
        <button class="btn-pill" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
          Home
        </button>
      </div>
      <div class="header-main">
        <h1 class="category-name">
          <span class="name-gradient">{{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
        </h1>
        <p class="header-subtitle">Allenamenti</p>
      </div>
    </header>

    <div class="allenamenti-body">
      <div class="month-nav-pill">
        <button class="btn-nav-mese" @click="prevMonth">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>
        <span class="current-month">{{ currentMonthName }} {{ currentYear }}</span>
        <button class="btn-nav-mese" @click="nextMonth">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <polyline points="9 18 15 12 9 6"/>
          </svg>
        </button>
      </div>

      <div class="weeks-grid">
        <div v-for="week in weeksInMonth" :key="week.num" class="week-card" :class="{ active: selectedWeek?.num === week.num }" @click="selectWeek(week)">
          <div class="week-header">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
              <line x1="16" y1="2" x2="16" y2="6"/>
              <line x1="8" y1="2" x2="8" y2="6"/>
              <line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
            Settimana {{ week.num }}
          </div>
          <div class="week-dates">{{ formatDateRange(week.start, week.end) }}</div>
          <div class="week-days">
            <span v-for="day in week.days" :key="day.date" class="day-chip" :class="{ 'has-training': day.isSelectable, 'today': day.isToday, 'other-month': day.month !== currentMonth }" @click.stop="selectDay(day)">{{ day.dayNum }}</span>
          </div>
        </div>
      </div>

      <div v-if="selectedDay" class="day-detail">
        <div class="day-header">
          <button class="btn-back-pill" @click="clearSelectedDay">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <line x1="19" y1="12" x2="5" y2="12"/>
              <polyline points="12 19 5 12 12 5"/>
            </svg>
            Calendario
          </button>
          <h3>Allenamento del {{ formatDate(selectedDay.data) }}</h3>
          <div class="day-actions">
            <button class="btn-action" @click="addEsercizio">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                <line x1="12" y1="5" x2="12" y2="19"/>
                <line x1="5" y1="12" x2="19" y2="12"/>
              </svg>
              Esercizio
            </button>
            <button class="btn-action" @click="openCatalogo">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                <path d="M4 19.5A2.5 2.5 0 016.5 17H20"/>
                <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z"/>
              </svg>
              Catalogo
            </button>
            
            <button class="btn-action" @click="openSaveToCatalogoDialog">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                <path d="M22 11.08V12a10 10 0 11-5.93-9.14"/>
                <polyline points="22 4 12 14.01 9 11.01"/>
              </svg>
              Condividi
            </button>
            <button class="btn-action" @click="exportPdf">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
                <polyline points="14 2 14 8 20 8"/>
                <line x1="16" y1="13" x2="8" y2="13"/>
                <line x1="16" y1="17" x2="8" y2="17"/>
                <polyline points="10 9 9 9 8 9"/>
              </svg>
              PDF
            </button>
          </div>
        </div>

        <div class="esercizi-list">
          <div v-for="(ex, idx) in esercizi" :key="ex.id" class="esercizio-card" :class="{ active: selectedExercise?.id === ex.id }" :data-ex-id="ex.id" @click="selectExercise(ex)">
            <div class="esercizio-header">
              <span class="esercizio-num">{{ idx + 1 }}</span>
              <input v-model="ex.titolo" class="esercizio-titolo" placeholder="Titolo esercizio..." @change="saveEsercizio(ex)" :id="'titolo-' + idx" name="titolo" />

              <button class="btn-delete" @click="deleteEsercizio(ex)">×</button>
            </div>

            <div class="esercizio-meta">
              <div class="focus-field">
                <label>Focus:</label>
                <select v-model="ex.focus" @change="saveEsercizio(ex)">
                  <option value="">Nessuno</option>
                  <option value="attivazione">Attivazione</option>
                  <option value="tecnica">Tecnica</option>
                  <option value="tattica">Tattica</option>
                  <option value="fisico">Fisico</option>
                  <option value="capacita-coordinativa">Capacità Coordinativa</option>
                  <option value="palleggio">Palleggio</option>
                  <option value="passaggio">Passaggio</option>
                  <option value="conclusione">Conclusione</option>
                  <option value="difesa">Difesa</option>
                  <option value="attacco">Attacco</option>
                  <option value="possessione">Possesso</option>
                  <option value="set-piece">Set Piece</option>
                </select>
              </div>
              <div class="meta-row">
                <div class="meta-field">
                  <label :for="'spazio-' + idx">Spazio:</label>
                  <input type="text" v-model="ex.spazio" placeholder="es. 20x30m" @change="saveEsercizio(ex)" :id="'spazio-' + idx" name="spazio" />
                </div>
                <div class="meta-field">
                  <label :for="'tempo-' + idx">Tempo:</label>
                  <input type="text" v-model="ex.tempo" placeholder="es. 3x4'" @change="saveEsercizio(ex)" :id="'tempo-' + idx" name="tempo" />
                </div>
              </div>
              <textarea v-model="ex.descrizione" placeholder="Descrizione dell'esercizio..." @change="saveEsercizio(ex)" :id="'desc-' + idx" name="descrizione"></textarea>
            </div>

            <div class="board-area" ref="boardArea">
              <TacticalBoard
                :ref="(el) => { if (el) tacticalBoardRefs[idx] = el }"
                :elements="ex.elementi"
                :field-mode="ex.campo_con_righe === 'blank' ? 'blank' : (ex.campo_con_righe === 'half' ? 'half' : 'full')"
                @update:elements="(newElements) => updateElementi(ex, newElements)"
                @update:field-mode="handleFieldModeChange(ex, $event)"
              />
            </div>
          </div>
        </div>

        <div v-if="saveError" class="save-error-banner">
          <span>{{ saveError }}</span>
          <button @click="saveError = ''">✕</button>
        </div>
        <div v-if="esercizi.length === 0" class="no-esercizi">
          <p>Nessun esercizio. Clicca "Esercizio" per iniziare.</p>
        </div>
      </div>
    </div>

    <div v-if="showCatalogo" class="catalogo-overlay" @click.self="closeCatalogo">
      <div class="catalogo-modal">
        <div class="catalogo-header">
          <h2>📚 Catalogo Esercizi</h2>
          <button class="catalogo-close" @click="closeCatalogo">×</button>
        </div>
        <div class="catalogo-filters">
          <select v-model="catalogoFocus" @change="loadCatalogo">
            <option v-for="opt in focusOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
          </select>
          <span class="catalogo-count">{{ catalogoEsercizi.length }} esercizi unici</span>
        </div>
        <div class="catalogo-list">
          <div v-for="(ex, idx) in catalogoEsercizi" :key="idx" class="catalogo-item" :class="{ 'already-added': titoloGiaPresente(ex.titolo) }" @click="selezionaDaCatalogo(ex)">
            <div class="catalogo-item-header">
              <span class="catalogo-item-title">{{ ex.titolo }}</span>
              <div style="display:flex;gap:0.35rem;align-items:center;">
                <span v-if="ex.visibilita === 'societa'" class="catalogo-visibilita-badge" title="Visibile solo nella tua società">🔒 Società</span>
                <span class="catalogo-item-focus" :class="'focus-' + ex.focus">{{ ex.focus_label }}</span>
              </div>
            </div>
            <div class="catalogo-item-body">
              <div class="catalogo-item-info">
                <div v-if="ex.descrizione" class="catalogo-item-desc">{{ ex.descrizione }}</div>
                <div v-if="ex.spazio || ex.tempo" class="catalogo-item-details">
                  <span v-if="ex.spazio" class="detail-item">📐 {{ ex.spazio }}</span>
                  <span v-if="ex.tempo" class="detail-item">⏱ {{ ex.tempo }}</span>
                </div>
              </div>
              <div class="catalogo-item-preview">
                <canvas :id="'cat-canvas-' + idx" width="200" height="125" class="catalogo-canvas"></canvas>
              </div>
            </div>
            <div class="catalogo-item-footer">
              <span class="catalogo-item-count">Creato {{ formatDateShort(ex.creato_il) }}</span>
              <span v-if="titoloGiaPresente(ex.titolo)" class="catalogo-item-already">✓ Già nell'allenamento</span>
              <button v-if="ex.can_delete" class="catalogo-delete-btn" @click.stop="deleteFromCatalogo(ex)" title="Elimina dal catalogo">🗑️</button>
            </div>
          </div>
          <div v-if="catalogoEsercizi.length === 0" class="catalogo-empty">
            Nessun esercizio trovato per questo focus
          </div>
        </div>
      </div>
    </div>

    <div v-if="showCatalogoSelectDialog" class="catalogo-overlay" @click.self="closeCatalogoSelectDialog">
      <div class="save-dialog">
        <div class="save-dialog-header">
          <h3>Condividi Esercizi</h3>
        </div>
        <div class="save-dialog-body">
          <p>Seleziona gli esercizi da condividere:</p>
          <div class="esercizi-selezione">
              <label class="esercizio-checkbox" v-for="ex in eserciziConTitolo" :key="ex.id">
              <input type="checkbox" v-model="selectedForCatalogo[ex.id]" :disabled="!ex.titolo || !ex.titolo.trim()" name="esercizio-selezione" />
              <span class="checkbox-titolo" :class="{ 'no-titolo': !ex.titolo || !ex.titolo.trim() }">{{ ex.titolo || 'Esercizio senza titolo' }}</span>
            </label>
            <div v-if="eserciziConTitolo.length === 0" class="no-esercizi-selezione">
              Non ci sono esercizi in questo allenamento
            </div>
          </div>
          <div class="save-dialog-visibility">
            <label>Visibilità:</label>
            <select v-model="catalogoVisibilita">
              <option value="pubblico">🌍 Tutti — visibile a tutte le società</option>
              <option value="societa">🔒 Solo mia società</option>
            </select>
          </div>
        </div>
        <div class="save-dialog-actions">
          <button class="btn-save-catalogo" @click="confirmSaveSelectedToCatalogo" :disabled="!hasSelectedForCatalogo">Condividi selezionati</button>
          <button class="btn-cancel" @click="closeCatalogoSelectDialog">Annulla</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter, useRoute, onBeforeRouteLeave } from 'vue-router'
import { useStore } from '../store.js'
import { getAllCategorie, getAllenamentiGiornoByData, saveAllenamenti, getCatalogoEsercizi, getCatalogoEserciziNew, saveEsercizioToCatalogo, deleteEsercizioFromCatalogo, getFocusList } from '../api/index.js'
import { jsPDF } from 'jspdf'
import html2canvas from 'html2canvas'
import TacticalBoard from '../components/TacticalBoard.vue'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva, setCategoria, hideTopbar } = useStore()
const categoriaId = parseInt(route.params.id)

const trainingDays = computed(() => {
  if (!categoriaAttiva.value?.giorni) return []
  return categoriaAttiva.value.giorni.split(',').map(Number)
})

const currentDate = new Date()
const currentYear = ref(currentDate.getFullYear())
const currentMonth = ref(currentDate.getMonth() + 1)
const selectedWeek = ref(null)
const selectedDay = ref(null)
const esercizi = ref([])
const selectedExercise = ref(null)
const showRotateMessage = ref(false)
const showCatalogo = ref(false)
const catalogoFocus = ref('')
const catalogoEsercizi = ref([])
const focusOptions = ref([])
const currentUserId = ref(null)
const isSuperAdmin = ref(false)
const showCatalogoSelectDialog = ref(false)
const selectedForCatalogo = ref({})
const catalogoVisibilita = ref('pubblico')
const saveError = ref('')
const hasChanges = ref(false)
let saveDebounceTimer = null
const saveLoading = ref(false)
const tacticalBoardRefs = ref([])
let idCounter = 0
function generateId(prefix = '') {
  idCounter++
  return prefix + Date.now() + '_' + idCounter
}

const eserciziConTitolo = computed(() => {
  return esercizi.value.filter(e => e.titolo && e.titolo.trim())
})
const hasSelectedForCatalogo = computed(() => {
  return esercizi.value.some(ex => selectedForCatalogo.value[ex.id] && ex.titolo && ex.titolo.trim())
})

const monthNames = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre']
const currentMonthName = computed(() => monthNames[currentMonth.value - 1])

const weeksInMonth = computed(() => {
  const weeks = []
  const firstDay = new Date(currentYear.value, currentMonth.value - 1, 1)
  const lastDay = new Date(currentYear.value, currentMonth.value, 0)
  const dayNames = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab']
  
  let firstMonday = new Date(firstDay)
  const dayOfWeek = firstMonday.getDay()
  const daysToSubtract = dayOfWeek === 0 ? 6 : dayOfWeek - 1
  firstMonday.setDate(firstMonday.getDate() - daysToSubtract)
  
  let currentWeekStart = new Date(firstMonday)
  let weekNum = 1
  
  while (currentWeekStart <= lastDay) {
    const weekEnd = new Date(currentWeekStart)
    weekEnd.setDate(weekEnd.getDate() + 4)
    
    const firstDayOfWeek = new Date(currentWeekStart)
    const weekStartsInMonth = firstDayOfWeek.getMonth() + 1 === currentMonth.value
    
    if (weekStartsInMonth) {
      const days = []
      for (let i = 0; i < 5; i++) {
        const d = new Date(currentWeekStart)
        d.setDate(d.getDate() + i)
        const dayOfWeek = d.getDay()
        const isTrainingDay = trainingDays.value.includes(dayOfWeek === 0 ? 7 : dayOfWeek)
        if (isTrainingDay) {
          const year = d.getFullYear()
          const month = String(d.getMonth() + 1).padStart(2, '0')
          const day = String(d.getDate()).padStart(2, '0')
          const dateStr = `${year}-${month}-${day}`
          const today = new Date()
          const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
          days.push({ 
            date: dateStr, 
            dayNum: d.getDate(),
            dayName: dayNames[dayOfWeek],
            month: d.getMonth() + 1,
            isToday: dateStr === todayStr, 
            hasTraining: true, 
            isSelectable: true, 
            data: dateStr 
          })
        }
      }
      
      if (days.length > 0) {
        const weekLabel = `Sett ${weekNum} (Lun-Ven)`
        const fmt = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
        weeks.push({ num: weekNum, label: weekLabel, start: fmt(currentWeekStart), end: fmt(weekEnd), days })
        weekNum++
      }
    }
    
    currentWeekStart.setDate(currentWeekStart.getDate() + 7)
  }
  return weeks
})

function formatDateRange(start, end) {
  const [sy, sm, sd] = start.split('-').map(Number)
  const [ey, em, ed] = end.split('-').map(Number)
  const s = new Date(sy, sm - 1, sd)
  const e = new Date(ey, em - 1, ed)
  const sMonth = s.toLocaleDateString('it-IT', { month: 'short' })
  const eMonth = e.toLocaleDateString('it-IT', { month: 'short' })
  if (s.getMonth() !== e.getMonth()) {
    return `${s.getDate()} ${sMonth} - ${e.getDate()} ${eMonth}`
  }
  return `${s.getDate()} - ${e.getDate()} ${eMonth}`
}

function prevMonth() {
  if (currentMonth.value === 1) { currentMonth.value = 12; currentYear.value-- } else { currentMonth.value-- }
}

function nextMonth() {
  if (currentMonth.value === 12) { currentMonth.value = 1; currentYear.value++ } else { currentMonth.value++ }
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  const [year, month, day] = dateStr.split('-')
  const d = new Date(parseInt(year), parseInt(month) - 1, parseInt(day))
  return d.toLocaleDateString('it-IT', { day: 'numeric', month: 'long', year: 'numeric' })
}

function selectWeek(week) { selectedWeek.value = week }

function selectExercise(ex) { selectedExercise.value = ex }

function selectDay(day) {
  if (!day.isSelectable) return
  selectedDay.value = day
  loadEsercizi(day.data)
}

function clearSelectedDay() {
  selectedDay.value = null
  esercizi.value = []
  hasChanges.value = false
  saveError.value = ''
}

function getCurrentExercise() {
  return selectedExercise.value || esercizi.value[0]
}

function loadEsercizi(data) {
  selectedExercise.value = null
  
  getAllenamentiGiornoByData(categoriaId, data).then(res => {
    const dayData = res.data
    let loadedEsercizi = []
    
    if (dayData.esercizi && dayData.esercizi.length > 0) {
      loadedEsercizi = dayData.esercizi.map((e, idx) => ({
        ...e,
        id: e.id || generateId('loaded_'),
        fromCatalogo: false,
        elementi: (e.elementi || []).map(el => ({
          tipo: el.tipo ?? el.type ?? 'unknown',
          x: el.x ?? null,
          y: el.y ?? null,
          colore: el.colore ?? el.color ?? '#3b82f6',
          numero: el.numero ?? el.num ?? null,
          size: el.size ?? 28,
          w: el.w ?? null,
          h: el.h ?? null,
          scaleX: el.scaleX ?? null,
          scaleY: el.scaleY ?? null,
          rotazione: el.rotazione ?? 0,
          length: el.length ?? null,
          wavy: el.wavy ?? false,
          x1: el.x1 ?? undefined,
          y1: el.y1 ?? undefined,
          x2: el.x2 ?? undefined,
          y2: el.y2 ?? undefined,
          points: el.points ?? null,
          text: el.text ?? null,
        }))
      }))
    }
    
    esercizi.value = loadedEsercizi
    selectedExercise.value = loadedEsercizi.length > 0 ? loadedEsercizi[0] : null
  }).catch(() => {
    esercizi.value = []
    selectedExercise.value = null
  })
}

async function openCatalogo() {
  showCatalogo.value = true
  try {
    const res = await getFocusList()
    focusOptions.value = res.data.focus_options
  } catch (e) {
    console.error('Errore caricamento focus:', e)
  }
  await loadCatalogo()
}

async function loadCatalogo() {
  try {
    const res = await getCatalogoEserciziNew(catalogoFocus.value)
    catalogoEsercizi.value = res.data.esercizi || []
    currentUserId.value = res.data.current_user_id
    isSuperAdmin.value = res.data.is_super_admin
    await nextTick()
    await drawCatalogoPreviews()
  } catch (e) {
    console.error('Errore caricamento catalogo:', e)
    catalogoEsercizi.value = []
  }
}

function drawCatalogoPreviews() {
  catalogoEsercizi.value.forEach((ex, idx) => {
    const canvas = document.getElementById('cat-canvas-' + idx)
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    const W = canvas.width
    const H = canvas.height
    const isBlank = ex.campo_con_righe === 'blank'

    if (isBlank) {
      ctx.fillStyle = '#2d8a4e'
      ctx.fillRect(0, 0, W, H)
      return
    }

    ctx.fillStyle = '#1a2535'
    ctx.fillRect(0, 0, W, H)

    const stripeCount = 11
    const sw = W / stripeCount
    for (let i = 0; i < stripeCount; i++) {
      ctx.fillStyle = i % 2 === 0 ? '#2d5a1b' : '#346b20'
      ctx.fillRect(i * sw, 0, sw, H)
    }

    const pad = H * 0.06
    const fw = W - pad * 2
    const fh = H - pad * 2
    const fx = pad
    const fy = pad

    ctx.strokeStyle = 'rgba(255,255,255,0.88)'
    ctx.lineWidth = Math.max(1, H * 0.008)
    ctx.lineCap = 'round'
    ctx.strokeRect(fx, fy, fw, fh)
    ctx.beginPath()
    ctx.moveTo(fx + fw / 2, fy)
    ctx.lineTo(fx + fw / 2, fy + fh)
    ctx.stroke()
ctx.beginPath()
        ctx.arc(fx + fw / 2, fy + fh / 2, fh * 0.1346, 0, Math.PI * 2)
        ctx.stroke()
    ctx.beginPath()
    ctx.arc(fx + fw / 2, fy + fh / 2, H * 0.012, 0, Math.PI * 2)
    ctx.fillStyle = 'rgba(255,255,255,0.88)'
    ctx.fill()

    const paH = fh * 0.384
    const paW = fw * 0.157
    const paY = fy + (fh - paH) / 2
    const gaH = fh * 0.27
    const gaW = fw * 0.052
    const gaY = fy + (fh - gaH) / 2

    ctx.strokeRect(fx, paY, paW, paH)
    ctx.strokeRect(fx, gaY, gaW, gaH)
    ctx.beginPath()
    ctx.arc(fx + fw * 0.105, fy + fh / 2, H * 0.008, 0, Math.PI * 2)
    ctx.fill()
    ctx.beginPath()
    ctx.arc(fx + fw * 0.105, fy + fh / 2, fh * 0.146, -0.93, 0.93)
    ctx.stroke()
    ctx.strokeRect(fx + fw - paW, paY, paW, paH)
    ctx.strokeRect(fx + fw - gaW, gaY, gaW, gaH)
    ctx.beginPath()
    ctx.arc(fx + fw * 0.895, fy + fh / 2, H * 0.008, 0, Math.PI * 2)
    ctx.fill()
    ctx.beginPath()
    ctx.arc(fx + fw * 0.895, fy + fh / 2, fh * 0.146, Math.PI - 0.93, Math.PI + 0.93)
    ctx.stroke()

    const gH = fh * 0.11
    const gW = fw * 0.024
    const gY = fy + (fh - gH) / 2
    ctx.strokeStyle = 'rgba(255,255,255,0.7)'
    ctx.lineWidth = 2
    ctx.strokeRect(fx - gW, gY, gW, gH)
    ctx.strokeRect(fx + fw, gY, gW, gH)

    const elementi = ex.elementi || []
    if (elementi.length > 0) {
      elementi.forEach(el => {
        const ex_ = (el.x / 100) * W
        const ey = (el.y / 100) * H
        const ex1 = (el.x1 / 100) * W
        const ey1 = (el.y1 / 100) * H
        const ex2 = (el.x2 / 100) * W
        const ey2 = (el.y2 / 100) * H
        if (el.tipo === 'player-home' || el.tipo === 'player-away' || el.tipo === 'player-gk') {
          const cols = { 'player-home': '#3b82f6', 'player-away': '#ef4444', 'player-gk': '#f59e0b' }
          ctx.beginPath()
          ctx.arc(ex_, ey, 3, 0, Math.PI * 2)
          ctx.fillStyle = cols[el.tipo]
          ctx.fill()
        } else if (el.tipo === 'ball') {
          ctx.beginPath()
          ctx.arc(ex_, ey, 2, 0, Math.PI * 2)
          ctx.fillStyle = '#fff'
          ctx.fill()
        } else if (el.tipo === 'cone') {
          ctx.beginPath()
          ctx.moveTo(ex_, ey - 4)
          ctx.lineTo(ex_ - 3, ey + 3)
          ctx.lineTo(ex_ + 3, ey + 3)
          ctx.closePath()
          ctx.fillStyle = '#f97316'
          ctx.fill()
        } else if (el.tipo === 'disc') {
          ctx.beginPath()
          ctx.ellipse(ex_, ey, 4, 2, 0, 0, Math.PI * 2)
          ctx.fillStyle = '#a78bfa'
          ctx.fill()
        } else if (el.tipo === 'goal') {
          ctx.strokeStyle = '#fff'
          ctx.lineWidth = 1.5
          ctx.strokeRect(ex_ - 4, ey - 3, 8, 6)
        } else if (el.tipo === 'mannequin') {
          ctx.beginPath()
          ctx.arc(ex_, ey - 4, 2, 0, Math.PI * 2)
          ctx.fillStyle = '#e2e8f0'
          ctx.fill()
        } else if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash'].includes(el.tipo)) {
          ctx.strokeStyle = el.colore || '#3b82f6'
          ctx.lineWidth = Math.max(1, (el.w || 2) * 0.7)
          if (el.tipo === 'arrow-dash' || el.tipo === 'arrow-curve-dash') {
            ctx.setLineDash([3, 2])
          } else {
            ctx.setLineDash([])
          }
          ctx.beginPath()
          ctx.moveTo(ex1, ey1)
          ctx.lineTo(ex2, ey2)
          ctx.stroke()
          ctx.setLineDash([])
          const dx = ex2 - ex1
          const dy = ey2 - ey1
          const len = Math.sqrt(dx * dx + dy * dy)
          if (len > 1) {
            const nx = dx / len
            const ny = dy / len
            const size = 5
            ctx.fillStyle = el.colore || '#3b82f6'
            ctx.beginPath()
            ctx.moveTo(ex2, ey2)
            ctx.lineTo(ex2 - size * nx + size * 0.4 * (-ny), ey2 - size * ny + size * 0.4 * nx)
            ctx.lineTo(ex2 - size * nx - size * 0.4 * (-ny), ey2 - size * ny - size * 0.4 * nx)
            ctx.closePath()
            ctx.fill()
          }
        } else if (el.tipo === 'zone') {
          ctx.strokeStyle = el.colore || '#3b82f6'
          ctx.lineWidth = 1
          ctx.setLineDash([3, 2])
          const rx = Math.min(ex1, ex2)
          const ry = Math.min(ey1, ey2)
          const rw = Math.abs(ex2 - ex1)
          const rh = Math.abs(ey2 - ey1)
          ctx.strokeRect(rx, ry, rw, rh)
          ctx.setLineDash([])
        } else if (el.tipo === 'free') {
          if (el.points && el.points.length > 1) {
            ctx.strokeStyle = el.colore || '#3b82f6'
            ctx.lineWidth = Math.max(1, (el.w || 2) * 0.7)
            ctx.beginPath()
            ctx.moveTo((el.points[0].x / 100) * W, (el.points[0].y / 100) * H)
            el.points.forEach(p => ctx.lineTo((p.x / 100) * W, (p.y / 100) * H))
            ctx.stroke()
          }
        }
      })
    }
  })
}

function closeCatalogo() {
  showCatalogo.value = false
}

function titoloGiaPresente(titolo) {
  if (!titolo) return false
  const titoloNorm = titolo.trim().toLowerCase()
  return esercizi.value.some(e => e.titolo && e.titolo.trim().toLowerCase() === titoloNorm)
}

function formatDateShort(dateStr) {
  if (!dateStr) return '?'
  const d = new Date(dateStr)
  return d.toLocaleDateString('it-IT', { day: 'numeric', month: 'short' })
}

async function deleteFromCatalogo(ex) {
  if (!confirm(`Eliminare "${ex.titolo}" dal catalogo?`)) return
  try {
    await deleteEsercizioFromCatalogo(ex.id)
    await loadCatalogo()
  } catch (e) {
    console.error('Errore eliminazione:', e)
    alert('Errore durante l\'eliminazione')
  }
}

function selezionaDaCatalogo(ex) {
  if (titoloGiaPresente(ex.titolo)) {
    return
  }
  
  esercizi.value.push({
    id: generateId(),
    ordine: esercizi.value.length + 1,
    titolo: ex.titolo,
    descrizione: ex.descrizione || '',
    focus: ex.focus || '',
    campo_con_righe: ex.campo_con_righe,
    elementi: (ex.elementi || []).map(el => ({
      id: generateId('el_'),
      type: el.tipo ?? el.type ?? '',
      x: el.x ?? null,
      y: el.y ?? null,
      color: el.colore ?? el.color ?? '#3b82f6',
      num: el.numero ?? el.num ?? null,
      size: el.size ?? 28,
      w: el.w ?? null,
      h: el.h ?? null,
      scaleX: el.scaleX ?? null,
      scaleY: el.scaleY ?? null,
      rotazione: el.rotazione ?? 0,
      length: el.length ?? null,
      wavy: el.wavy ?? false,
      x1: el.x1 ?? undefined,
      y1: el.y1 ?? undefined,
      x2: el.x2 ?? undefined,
      y2: el.y2 ?? undefined,
      points: el.points ?? null,
      text: el.text ?? null,
    })),
    fromCatalogo: true,
    catalogoTitolo: ex.titolo
  })
  selectedExercise.value = esercizi.value[esercizi.value.length - 1]
  closeCatalogo()
}

function addEsercizio() {
  esercizi.value.push({ id: generateId(), ordine: esercizi.value.length + 1, titolo: '', descrizione: '', focus: '', campo_con_righe: 'full', elementi: [] })
  selectedExercise.value = esercizi.value[esercizi.value.length - 1]
  hasChanges.value = true
  debouncedSave()
}

function deleteEsercizio(ex) { 
  esercizi.value = esercizi.value.filter(e => e.id !== ex.id)
  if (esercizi.value.length > 0) {
    selectedExercise.value = esercizi.value[0]
  }
  hasChanges.value = true
  saveDataToServer()
}



async function exportPdf() {
  const doc = new jsPDF('portrait', 'mm', 'a4')
  const pageWidth = doc.internal.pageSize.getWidth()
  const pageHeight = doc.internal.pageSize.getHeight()
  const margin = 15

  const focusLabels = {
    'tecnica': 'Tecnica',
    'tattica': 'Tattica',
    'fisico': 'Fisico',
    'capacita-coordinativa': 'Cap. Coordinativa',
    'palleggio': 'Palleggio',
    'passaggio': 'Passaggio',
    'conclusione': 'Conclusione',
    'difesa': 'Difesa',
    'attacco': 'Attacco',
    'possessione': 'Possesso',
    'set-piece': 'Set Piece',
    'attivazione': 'Attivazione'
  }

  // Header sulla prima pagina
  doc.setFontSize(22)
  doc.setTextColor(220, 38, 38)
  doc.text('Allenamento del ' + formatDate(selectedDay.value?.data || ''), pageWidth / 2, 25, { align: 'center' })
  doc.setFontSize(12)
  doc.setTextColor(100, 100, 100)
  doc.text(categoriaAttiva.value?.nome + ' ' + (categoriaAttiva.value?.anno || ''), pageWidth / 2, 37, { align: 'center' })

  for (let idx = 0; idx < esercizi.value.length; idx++) {
    const ex = esercizi.value[idx]
    if (idx > 0) doc.addPage()
    let y = idx === 0 ? 48 : 18

    // Titolo esercizio con numero
    doc.setTextColor(220, 38, 38)
    doc.setFontSize(16)
    doc.text('Esercizio ' + (idx + 1) + ': ' + (ex.titolo || 'Senza titolo'), margin, y)

    // Focus, Spazio, Tempo - stessa riga
    y += 14
    doc.setFontSize(9)
    let metaX = margin
    if (ex.focus) {
      const focusLabel = 'Focus: ' + (focusLabels[ex.focus] || ex.focus)
      const focusW = doc.getTextWidth(focusLabel) + 6
      doc.setFillColor(59, 130, 246)
      doc.roundedRect(metaX, y - 3, focusW, 6, 1.5, 1.5, 'F')
      doc.setTextColor(255, 255, 255)
      doc.text(focusLabel, metaX + focusW / 2, y + 1, { align: 'center' })
      metaX += focusW + 4
    }
    if (ex.spazio) {
      const spazioW = doc.getTextWidth('Spazio: ' + ex.spazio) + 6
      doc.setFillColor(16, 185, 129)
      doc.roundedRect(metaX, y - 3, spazioW, 6, 1.5, 1.5, 'F')
      doc.setTextColor(255, 255, 255)
      doc.text('Spazio: ' + ex.spazio, metaX + spazioW / 2, y + 1, { align: 'center' })
      metaX += spazioW + 4
    }
    if (ex.tempo) {
      const tempoW = doc.getTextWidth('Tempo: ' + ex.tempo) + 6
      doc.setFillColor(245, 158, 11)
      doc.roundedRect(metaX, y - 3, tempoW, 6, 1.5, 1.5, 'F')
      doc.setTextColor(255, 255, 255)
      doc.text('Tempo: ' + ex.tempo, metaX + tempoW / 2, y + 1, { align: 'center' })
    }

    // Separatore
    y += 6
    doc.setDrawColor(220, 38, 38)
    doc.setLineWidth(0.4)
    doc.line(margin, y, pageWidth - margin, y)

    // Descrizione
    y += 8
    if (ex.descrizione) {
      doc.setFontSize(10)
      doc.setTextColor(50, 50, 50)
      const descLines = doc.splitTextToSize(ex.descrizione, pageWidth - (margin * 2))
      doc.text(descLines, margin, y)
      y += descLines.length * 5.5
    }

    // Canvas snapshot - disegna il campo su un canvas nascosto
    y += 5
    await nextTick()
    
    const canvasWidth = 800
    const canvasHeight = Math.round(canvasWidth * 68 / 105)
    const exportCanvas = document.createElement('canvas')
    exportCanvas.width = canvasWidth
    exportCanvas.height = canvasHeight
    const ctx = exportCanvas.getContext('2d')
    
    // Sfondo
    const isBlank = ex.campo_con_righe === 'blank'
    ctx.fillStyle = isBlank ? '#2d8a4e' : '#1a2535'
    ctx.fillRect(0, 0, canvasWidth, canvasHeight)

    // Campo da calcio
    const fieldMode = ex.campo_con_righe === 'half' ? 'half' : (ex.campo_con_righe === 'blank' ? 'blank' : 'full')
    const pad = canvasHeight * 0.06
    const fw = canvasWidth - pad * 2
    const fh = canvasHeight - pad * 2
    const fx = pad
    const fy = pad

    if (!isBlank) {
      // Strisce verdi
      const stripeCount = 11
      const sw = canvasWidth / stripeCount
      for (let i = 0; i < stripeCount; i++) {
        ctx.fillStyle = i % 2 === 0 ? '#2d5a1b' : '#346b20'
        ctx.fillRect(i * sw, 0, sw, canvasHeight)
      }
      
      ctx.strokeStyle = 'rgba(255,255,255,0.88)'
      ctx.lineWidth = Math.max(2, canvasHeight * 0.005)
      ctx.lineCap = 'round'
      ctx.strokeRect(fx, fy, fw, fh)
      
      // Linea di metà campo
      ctx.beginPath()
      ctx.moveTo(fx + fw / 2, fy)
      ctx.lineTo(fx + fw / 2, fy + fh)
      ctx.stroke()
      
      // Cerchio di centrocampo
      ctx.beginPath()
      ctx.arc(fx + fw / 2, fy + fh / 2, fh * 0.146, 0, Math.PI * 2)
      ctx.stroke()
      
      // Punto di centrocampo
      ctx.beginPath()
      ctx.arc(fx + fw / 2, fy + fh / 2, canvasHeight * 0.008, 0, Math.PI * 2)
      ctx.fillStyle = 'rgba(255,255,255,0.88)'
      ctx.fill()
      
      // Area grande e piccola (solo campo intero)
      if (fieldMode === 'full') {
        const paH = fh * 0.384
        const paW = fw * 0.157
        const paY = fy + (fh - paH) / 2
        const gaH = fh * 0.27
        const gaW = fw * 0.052
        const gaY = fy + (fh - gaH) / 2
        
        ctx.strokeRect(fx, paY, paW, paH)
        ctx.strokeRect(fx, gaY, gaW, gaH)
        ctx.strokeRect(fx + fw - paW, paY, paW, paH)
        ctx.strokeRect(fx + fw - gaW, gaY, gaW, gaH)
        
        // Arci di rigore
        ctx.beginPath()
        ctx.arc(fx + fw * 0.105, fy + fh / 2, fh * 0.1346, -0.93, 0.93)
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(fx + fw * 0.895, fy + fh / 2, fh * 0.1346, Math.PI - 0.93, Math.PI + 0.93)
        ctx.stroke()
        
        // Punti di rigore
        ctx.beginPath()
        ctx.arc(fx + fw * 0.105, fy + fh / 2, canvasHeight * 0.006, 0, Math.PI * 2)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(fx + fw * 0.895, fy + fh / 2, canvasHeight * 0.006, 0, Math.PI * 2)
        ctx.fill()
        
        // Porte
        const gH = fh * 0.11
        const gW = fw * 0.024
        const gY = fy + (fh - gH) / 2
        ctx.strokeStyle = 'rgba(255,255,255,0.7)'
        ctx.lineWidth = 2
        ctx.strokeRect(fx - gW, gY, gW, gH)
        ctx.strokeRect(fx + fw, gY, gW, gH)
      } else {
        // Metà campo
        const paH2 = fh * 0.384
        const paW2 = fw * 0.157
        const paY2 = fy + (fh - paH2) / 2
        const gaH2 = fh * 0.27
        const gaW2 = fw * 0.052
        const gaY2 = fy + (fh - gaH2) / 2
        
        ctx.strokeRect(fx + fw - paW2, paY2, paW2, paH2)
        ctx.strokeRect(fx + fw - gaW2, gaY2, gaW2, gaH2)
        
        const gH2 = fh * 0.11
        const gW2 = fw * 0.024
        const gY2 = fy + (fh - gH2) / 2
        ctx.strokeStyle = 'rgba(255,255,255,0.7)'
        ctx.lineWidth = 2
        ctx.strokeRect(fx + fw, gY2, gW2, gH2)
      }
    }
    
    // Disegna elementi - coordinate percentuali relative al campo da gioco (0-100%)
    const elementi = ex.elementi || []
    if (elementi.length > 0) {
      const pdfFx = isBlank ? 0 : fx
      const pdfFy = isBlank ? 0 : fy
      const pdfFw = isBlank ? canvasWidth : fw
      const pdfFh = isBlank ? canvasHeight : fh
const toPdfX = (xp) => pdfFx + (xp / 100) * pdfFw
       const toPdfY = (yp) => pdfFy + (yp / 100) * pdfFh
       const baseScale = pdfFw / 650
       elementi.forEach(el => {
        const ex_ = toPdfX(el.x || 0)
        const ey = toPdfY(el.y || 0)
        const ex1 = toPdfX(el.x1 || 0)
        const ey1 = toPdfY(el.y1 || 0)
        const ex2 = toPdfX(el.x2 || 0)
        const ey2 = toPdfY(el.y2 || 0)
        const color = el.colore || el.color || '#3b82f6'
        const rotation = el.rotazione || 0
const sX = (el.scaleX || 1) * baseScale
         const sY = (el.scaleY || 1) * baseScale
        
        if (el.tipo === 'player' || el.tipo === 'player-bib' || el.tipo === 'player-jolly' || el.tipo === 'gk') {
          ctx.save()
          ctx.translate(ex_, ey)
          ctx.rotate((rotation * Math.PI) / 180)
          ctx.scale(sX, sY)
          const r = 16
          if (el.tipo === 'player-jolly') {
            // Diamante
            ctx.beginPath()
            ctx.moveTo(0, -r)
            ctx.lineTo(r, 0)
            ctx.lineTo(0, r)
            ctx.lineTo(-r, 0)
            ctx.closePath()
            ctx.strokeStyle = color
            ctx.lineWidth = 2.5
            ctx.stroke()
          } else {
            // Cerchio
            ctx.beginPath()
            ctx.arc(0, 0, r, 0, Math.PI * 2)
            ctx.strokeStyle = color
            ctx.lineWidth = 2.5
            ctx.stroke()
            if (el.tipo === 'player-bib') {
              ctx.fillStyle = color
              ctx.fill()
            }
          }
          // Portiere: lettera P
          if (el.tipo === 'gk') {
            ctx.fillStyle = color
            ctx.font = 'bold 12px sans-serif'
            ctx.textAlign = 'center'
            ctx.textBaseline = 'middle'
            ctx.fillText('P', 0, 1)
          }
          ctx.restore()
        } else if (el.tipo === 'ball') {
          ctx.save()
          ctx.translate(ex_, ey)
          ctx.rotate((rotation * Math.PI) / 180)
          ctx.scale(sX, sY)
          ctx.beginPath()
          ctx.arc(0, 0, 10, 0, Math.PI * 2)
          ctx.strokeStyle = color
          ctx.lineWidth = 2
          ctx.stroke()
          ctx.beginPath()
          ctx.arc(0, 0, 3, 0, Math.PI * 2)
          ctx.fillStyle = color
          ctx.fill()
          ctx.restore()
        } else if (el.tipo === 'cone') {
          ctx.save()
          ctx.translate(ex_, ey)
          ctx.rotate((rotation * Math.PI) / 180)
          ctx.scale(sX, sY)
          // Triangolo equilatero
          const s = 14
          ctx.beginPath()
          ctx.moveTo(0, -s)
          ctx.lineTo(-s * Math.cos(Math.PI / 6), s * Math.sin(Math.PI / 6))
          ctx.lineTo(s * Math.cos(Math.PI / 6), s * Math.sin(Math.PI / 6))
          ctx.closePath()
          ctx.fillStyle = color
          ctx.fill()
          ctx.restore()
        } else if (el.tipo === 'coord') {
          ctx.save()
          ctx.translate(ex_, ey)
          ctx.rotate((rotation * Math.PI) / 180)
          ctx.scale(sX, sY)
          // Rettangolo giallo
          ctx.fillStyle = color
          ctx.beginPath()
          ctx.roundRect(-16, -3, 32, 6, 2)
          ctx.fill()
          // Cerchi ai lati
          ctx.fillStyle = color
          ctx.beginPath()
          ctx.arc(-16, 0, 4, 0, Math.PI * 2)
          ctx.fill()
          ctx.beginPath()
          ctx.arc(16, 0, 4, 0, Math.PI * 2)
          ctx.fill()
          ctx.restore()
        } else if (el.tipo === 'pole') {
          ctx.save()
          ctx.translate(ex_, ey)
          ctx.rotate((rotation * Math.PI) / 180)
          ctx.scale(sX, sY)
          // Ombra
          ctx.fillStyle = color
          ctx.beginPath()
          ctx.ellipse(0, 12, 6, 3, 0, 0, Math.PI * 2)
          ctx.fill()
          // Asta rossa
          ctx.fillStyle = color
          ctx.fillRect(-2.5, -12, 5, 24)
          ctx.restore()
        } else if (el.tipo === 'goal') {
          ctx.save()
          ctx.translate(ex_, ey)
          ctx.rotate((rotation * Math.PI) / 180)
          ctx.scale(sX, sY)
          const w = 28, h = 14
          ctx.strokeStyle = '#fff'
          ctx.lineWidth = 3
          // Linea di porta
          ctx.beginPath()
          ctx.moveTo(-w, -h)
          ctx.lineTo(-w, h)
          ctx.stroke()
          ctx.beginPath()
          ctx.moveTo(w, -h)
          ctx.lineTo(w, h)
          ctx.stroke()
          // Attraverso
          ctx.beginPath()
          ctx.moveTo(-w, -h)
          ctx.lineTo(w, -h)
          ctx.stroke()
          // Rete (linee orizzontali)
          ctx.strokeStyle = 'rgba(255,255,255,0.3)'
          ctx.lineWidth = 0.8
          for (let i = -h + 5; i < h; i += 5) {
            ctx.beginPath()
            ctx.moveTo(-w, i)
            ctx.lineTo(w, i)
            ctx.stroke()
          }
          // Linee verticali rete
          for (let i = -w + 9; i < w; i += 9) {
            ctx.beginPath()
            ctx.moveTo(i, -h)
            ctx.lineTo(i, h)
            ctx.stroke()
          }
          ctx.restore()
        } else if (['pass', 'dribble', 'wallpass', 'shot', 'movement', 'line'].includes(el.tipo)) {
          ctx.save()
          const dx = ex2 - ex1
          const dy = ey2 - ey1
          const len = Math.sqrt(dx * dx + dy * dy)
          if (len > 0) {
            const angle = Math.atan2(dy, dx)
            ctx.translate(ex1, ey1)
            ctx.rotate(angle)
            ctx.scale(baseScale, baseScale)

            ctx.strokeStyle = color
            ctx.lineWidth = Math.max(2.5, (el.w || 2) * 0.7)
            if (el.tipo === 'dribble' || el.tipo === 'movement') {
              ctx.setLineDash([6 / baseScale, 4 / baseScale])
            } else {
              ctx.setLineDash([])
            }

            // Linea
            ctx.beginPath()
            ctx.moveTo(-len / 2 / baseScale, 0)
            ctx.lineTo(len / 2 / baseScale, 0)
            ctx.stroke()
            ctx.setLineDash([])

            // Freccia
            const aLen = 14
            const halfLen = len / 2 / baseScale
            ctx.fillStyle = color
            ctx.beginPath()
            ctx.moveTo(halfLen, 0)
            ctx.lineTo(halfLen - aLen, -aLen / 2)
            ctx.lineTo(halfLen - aLen, aLen / 2)
            ctx.closePath()
            ctx.fill()

            // Wallpass: seconda freccia
            if (el.tipo === 'wallpass') {
              ctx.beginPath()
              ctx.moveTo(-halfLen, 0)
              ctx.lineTo(-halfLen + aLen, -aLen / 2)
              ctx.lineTo(-halfLen + aLen, aLen / 2)
              ctx.closePath()
              ctx.fill()
            }

            // Shot: linea verticale alla fine
            if (el.tipo === 'shot') {
              ctx.strokeStyle = color
              ctx.lineWidth = 2.5
              ctx.beginPath()
              ctx.moveTo(halfLen + 6, -10)
              ctx.lineTo(halfLen + 6, 10)
              ctx.stroke()
            }
          }
          ctx.restore()
        } else if (el.tipo === 'text') {
          ctx.save()
          ctx.translate(ex_, ey)
          ctx.rotate((rotation * Math.PI) / 180)
          ctx.scale(sX, sY)
          ctx.fillStyle = color
          ctx.font = '16px sans-serif'
          ctx.textAlign = 'center'
          ctx.textBaseline = 'middle'
          ctx.fillText(el.text || 'Testo', 0, 0)
          ctx.restore()
        }
      })
    }
    
    // Aggiungi immagine al PDF
    const imgData = exportCanvas.toDataURL('image/png')
    const availableH = pageHeight - y - 10
    const maxW = pageWidth - (margin * 2)
    const imgWidth = canvasWidth
    const imgHeight = canvasHeight
    const ratio = Math.min(maxW / imgWidth, availableH / imgHeight, 1)
    const imgW = imgWidth * ratio
    const imgH = imgHeight * ratio
    const imgX = margin + (maxW - imgW) / 2
    doc.addImage(imgData, 'PNG', imgX, y, imgW, imgH)
    console.log('Export: added image to PDF for idx', idx, 'size:', imgW.toFixed(1) + 'x' + imgH.toFixed(1))
  }

  const categoriaNome = categoriaAttiva.value?.nome || 'Categoria'
  const dataSelezionata = selectedDay.value?.data || 'data'
  const dataFormattata = dataSelezionata.split('-').reverse().join('/')
  doc.save('Scheda ' + categoriaNome + ' del ' + dataFormattata + '.pdf')
}

function saveEsercizio(ex) {
  if (!selectedDay.value) return
  hasChanges.value = true
  debouncedSave()
}

function updateElementi(ex, newElements) {
  const idx = esercizi.value.findIndex(e => e.id === ex.id)
  if (idx !== -1) {
    const current = JSON.stringify(esercizi.value[idx].elementi || [])
    const incoming = JSON.stringify(newElements || [])
    if (current === incoming) return
    esercizi.value[idx].elementi = newElements
  }
  hasChanges.value = true
  debouncedSave()
}

function handleFieldModeChange(ex, mode) {
  const idx = esercizi.value.findIndex(e => e.id === ex.id)
  if (idx !== -1) {
    esercizi.value[idx].campo_con_righe = mode
  }
  hasChanges.value = true
  debouncedSave()
}

function debouncedSave() {
  if (saveDebounceTimer) {
    clearTimeout(saveDebounceTimer)
  }
  saveDebounceTimer = setTimeout(() => {
    saveDataToServer()
  }, 800)
}

function saveDataToServer() {
  if (!selectedDay.value) return
  
  if (saveLoading.value) {
    console.log('[Allenamenti] Salvataggio in corso, skip')
    return
  }
  
  saveLoading.value = true

  const payload = {
    categoria_id: categoriaId,
    data: selectedDay.value.data,
    esercizi: esercizi.value.map((e, idx) => {
      return {
        ordine: idx + 1,
        titolo: e.titolo || '',
        descrizione: e.descrizione || '',
        focus: e.focus || '',
        spazio: e.spazio || '',
        tempo: e.tempo || '',
        campo_con_righe: e.campo_con_righe,
        elementi: (e.elementi || []).map(el => ({
          tipo:      el.tipo      ?? el.type   ?? '',
          x:         el.x        ?? null,
          y:         el.y        ?? null,
          rotazione: el.rotazione ?? 0,
          colore:    el.colore    ?? el.color  ?? null,
          numero:    el.numero    ?? el.num    ?? null,
          size:      el.size      ?? null,
          w:         el.w        ?? null,
          h:         el.h        ?? null,
          scaleX:    el.scaleX   ?? null,
          scaleY:    el.scaleY   ?? null,
          x1:        el.x1       ?? null,
          y1:        el.y1       ?? null,
          x2:        el.x2       ?? null,
          y2:        el.y2       ?? null,
          points:    el.points   ?? null,
          text:      el.text     ?? null,
          length:    el.length   ?? null,
          wavy:      el.wavy     ?? false,
        }))
      }
    })
  }

  saveAllenamenti(categoriaId, payload)
    .then(() => {
      hasChanges.value = false
      saveError.value = ''
    })
    .catch(err => {
      hasChanges.value = true
      const detail = err.response?.data?.detail || 'Errore durante il salvataggio. Riprova.'
      saveError.value = detail
    })
    .finally(() => {
      saveLoading.value = false
    })
}

function openSaveToCatalogoDialog() {
  const exercisesWithTitles = esercizi.value.filter(e => e.titolo && e.titolo.trim())
  if (exercisesWithTitles.length === 0) {
    alert('Non ci sono esercizi con titolo da condividere')
    return
  }
  exercisesWithTitles.forEach(ex => {
    if (selectedForCatalogo.value[ex.id] === undefined) {
      selectedForCatalogo.value[ex.id] = true
    }
  })
  showCatalogoSelectDialog.value = true
}

function closeCatalogoSelectDialog() {
  showCatalogoSelectDialog.value = false
  selectedForCatalogo.value = {}
}

function confirmSaveSelectedToCatalogo() {
  const selectedExercises = esercizi.value.filter(ex => selectedForCatalogo.value[ex.id])
  if (selectedExercises.length === 0) {
    alert('Seleziona almeno un esercizio')
    return
  }
  
  closeCatalogoSelectDialog()
  saveLoading.value = true
  
  let savedCount = 0
  let failedCount = 0
  const failedTitles = []
  const promises = selectedExercises.map(ex => {
    if (!ex.titolo || !ex.titolo.trim()) {
      return Promise.resolve()
    }
    return saveEsercizioToCatalogo({
      titolo: ex.titolo,
      focus: ex.focus || '',
      spazio: ex.spazio || '',
      tempo: ex.tempo || '',
      descrizione: ex.descrizione || '',
      campo_con_righe: ex.campo_con_righe,
      visibilita: catalogoVisibilita.value,
      elementi: (ex.elementi || []).map(el => ({
        tipo: el.tipo ?? el.type ?? '',
        x: el.x ?? null,
        y: el.y ?? null,
        rotazione: el.rotazione ?? 0,
        colore: el.colore ?? el.color ?? null,
        numero: el.numero ?? el.num ?? null,
        size: el.size ?? null,
        w: el.w ?? null,
        h: el.h ?? null,
        scaleX: el.scaleX ?? null,
        scaleY: el.scaleY ?? null,
        x1: el.x1 ?? null,
        y1: el.y1 ?? null,
        x2: el.x2 ?? null,
        y2: el.y2 ?? null,
        points: el.points ?? null,
        text: el.text ?? null,
        length: el.length ?? null,
        wavy: el.wavy ?? false,
      }))
    }).then(() => {
      savedCount++
    }).catch(e => {
      failedCount++
      failedTitles.push(ex.titolo)
      console.error('Errore salvataggio catalogo:', e)
    })
  })
  
  Promise.all(promises).then(() => {
    saveLoading.value = false
    let msg = `Condivisi ${savedCount} esercizi!`
    if (failedCount > 0) {
      msg += `\n\nFalliti: ${failedTitles.join(', ')}`
    }
    alert(msg)
  })
}

onMounted(async () => {
  hideTopbar.value = true
  currentMonth.value = currentDate.getMonth() + 1
  currentYear.value = currentDate.getFullYear()
  
  if (!categoriaAttiva.value || categoriaAttiva.value.id !== categoriaId) {
    const societaId = (await import('../store.js')).useStore().societaAttiva.value?.id
    const res = await getAllCategorie(societaId)
    const cats = res.data || []
    const cat = cats.find(c => c.id === categoriaId)
    if (cat) setCategoria(cat)
  }
  
  const checkRotate = () => {
    const isMobile = window.innerWidth <= 768
    const isPortrait = window.innerHeight > window.innerWidth
    showRotateMessage.value = isMobile && isPortrait
  }
  checkRotate()
  window.addEventListener('resize', checkRotate)
})

onBeforeRouteLeave(async () => {
  if (hasChanges.value) {
    // Recupera elementi freschi dall'iframe prima di salvare
    const selectedIndex = esercizi.value.findIndex(ex => ex.id === selectedExercise.value?.id)
    if (selectedIndex !== -1 && tacticalBoardRefs.value[selectedIndex]) {
      try {
        const elements = await tacticalBoardRefs.value[selectedIndex].requestElements()
        if (elements) {
          esercizi.value[selectedIndex].elementi = elements
        }
      } catch (err) {
        console.error('[Allenamenti] Errore recupero elementi:', err)
      }
    }
    // Cancella debounce e salva subito
    if (saveDebounceTimer) {
      clearTimeout(saveDebounceTimer)
      saveDebounceTimer = null
    }
    saveDataToServer()
  }
})

onUnmounted(() => {
  hideTopbar.value = false
})
</script>

<style scoped>
.allenamenti-page {
  position: relative;
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100vw;
  background: #0a0a0a;
  overflow: hidden;
}

.allenamenti-body {
  position: relative;
  z-index: 1;
  flex: 1;
  overflow-y: auto;
  padding: 1rem 1rem 2rem;
  width: 100%;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  max-width: 100%;
  margin: 0;
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
  background: radial-gradient(circle, rgba(168, 85, 247, 0.06) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 400px;
  height: 400px;
  bottom: -100px;
  left: -80px;
  background: radial-gradient(circle, rgba(59, 130, 246, 0.05) 0%, transparent 70%);
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
  padding: 1.5rem 2rem 1rem;
  animation: fadeSlideIn 0.6s ease-out both;
}

.header-top {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.btn-back-pill,
.btn-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.4rem 0.4rem 1rem;
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 100px;
  color: rgba(255, 255, 255, 0.5);
  font-family: var(--font-sans, system-ui, sans-serif);
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-pill {
  padding: 0.4rem 0.75rem;
}

.btn-back-pill svg,
.btn-pill svg {
  background: rgba(255, 255, 255, 0.08);
  border-radius: 50%;
  width: 24px;
  height: 24px;
  padding: 3px;
}

.btn-back-pill:hover,
.btn-pill:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.2);
  color: rgba(255, 255, 255, 0.9);
}

.header-main {
  position: relative;
}

.category-name {
  font-size: clamp(2rem, 6vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.25rem;
}

.name-gradient {
  background: linear-gradient(135deg, #ffffff 0%, #ffffff 40%, var(--color-primary, #dc2626) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.header-subtitle {
  font-size: 1rem;
  color: rgba(255, 255, 255, 0.35);
  font-weight: 400;
}

/* ── Month Navigation ── */
.month-nav-pill {
  display: inline-flex;
  align-items: center;
  gap: 1rem;
  padding: 0.5rem 0.5rem 0.5rem 1.25rem;
  background: rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 100px;
  margin-bottom: 1.5rem;
  align-self: center;
}

.current-month {
  font-size: 0.9375rem;
  font-weight: 600;
  color: #fff;
  min-width: 180px;
  text-align: center;
}

.btn-nav-mese {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 50%;
  color: rgba(255, 255, 255, 0.5);
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
}

.btn-nav-mese:hover {
  background: rgba(59, 130, 246, 0.15);
  border-color: rgba(59, 130, 246, 0.3);
  color: #60a5fa;
}

/* ── Weeks Grid ── */
.weeks-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
  margin-bottom: 1rem;
}

.week-card {
  position: relative;
  padding: 1.25rem;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 16px;
  cursor: pointer;
  transition: all 0.25s;
  overflow: hidden;
}

.week-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 16px;
  opacity: 0;
  transition: opacity 0.25s;
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.06) 0%, transparent 60%);
  pointer-events: none;
}

.week-card:hover {
  border-color: rgba(255, 255, 255, 0.12);
  transform: translateY(-2px);
}

.week-card:hover::before {
  opacity: 1;
}

.week-card.active {
  border-color: var(--color-primary, #dc2626);
  background: rgba(255, 255, 255, 0.05);
}

.week-card.active::before {
  opacity: 1;
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.08) 0%, transparent 60%);
}

.week-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 700;
  color: #fff;
  margin-bottom: 0.25rem;
  font-size: 0.9375rem;
  letter-spacing: -0.01em;
}

.week-header svg {
  color: var(--color-primary, #dc2626);
  flex-shrink: 0;
}

.week-dates {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.35);
  margin-bottom: 0.75rem;
  font-weight: 500;
}

.week-days {
  display: flex;
  gap: 0.35rem;
  flex-wrap: wrap;
}

.day-chip {
  width: 34px;
  height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.06);
  border-radius: 10px;
  font-size: 0.85rem;
  color: rgba(255, 255, 255, 0.25);
  cursor: not-allowed;
  border: 1px solid rgba(255, 255, 255, 0.06);
  transition: all 0.2s;
}

.day-chip.has-training {
  background: var(--color-primary, #dc2626);
  color: white;
  cursor: pointer;
  border: 1px solid var(--color-primary, #dc2626);
  font-weight: 600;
}

.day-chip.has-training:hover {
  transform: scale(1.1);
  filter: brightness(1.15);
}

.day-chip.today {
  border: 2px solid rgba(255, 255, 255, 0.5);
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.1);
}

.day-chip.other-month {
  opacity: 0.3;
}

/* ── Day Detail ── */
.day-detail {
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 20px;
  padding: 1.25rem;
  width: 100%;
  box-sizing: border-box;
  margin-top: 1rem;
}

.day-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.day-header h3 {
  color: #fff;
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
}

.day-actions {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.btn-action {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.9rem;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 100px;
  color: rgba(255, 255, 255, 0.6);
  font-family: var(--font-sans, system-ui, sans-serif);
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn-action:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.2);
  color: rgba(255, 255, 255, 0.9);
}

/* ── Animations ── */
@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}
.esercizi-list { display: flex; flex-direction: column; gap: 2rem; }
.esercizio-card { background: #1a1a1a; border-radius: 12px; padding: 0; width: 100%; box-sizing: border-box; }
.esercizio-header { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.75rem; flex-shrink: 0; }
.esercizio-num { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; background: var(--color-primary); border-radius: 50%; color: white; font-weight: bold; font-size: 1rem; flex-shrink: 0; }
.esercizio-titolo { flex: 1; min-width: 200px; background: #252525; border: 1px solid #333; border-radius: 8px; padding: 0.6rem 0.8rem; color: #fff; font-size: 1rem; }
.btn-delete { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; background: #dc2626; border: none; border-radius: 8px; color: white; cursor: pointer; font-size: 1.25rem; flex-shrink: 0; }

.esercizio-meta { padding: 0 0 0.75rem 0; display: flex; flex-direction: row; align-items: flex-start; gap: 1rem; }
.esercizio-meta textarea { flex: 1; min-height: 60px; background: #252525; border: 1px solid #333; border-radius: 6px; padding: 0.5rem 0.75rem; color: #ddd; font-size: 0.85rem; resize: vertical; font-family: inherit; }
.esercizio-description { flex: 1; display: flex; flex-direction: column; }
.esercizio-description textarea { width: 100%; flex: 1; min-height: 150px; background: #252525; border: 1px solid #333; border-radius: 8px; padding: 0.75rem; color: #ddd; font-size: 0.9rem; resize: vertical; }

.focus-field { display: flex; align-items: center; gap: 0.5rem; flex-shrink: 0; }
.focus-field label { font-size: 0.75rem; color: #888; font-weight: 500; white-space: nowrap; }
.focus-field select { max-width: 160px; padding: 0.3rem 0.5rem; background: #252525; border: 1px solid #333; border-radius: 6px; color: #ddd; font-size: 0.8rem; cursor: pointer; }
.focus-field select:focus { outline: none; border-color: var(--color-primary); }
.focus-field select option { background: #1a1a1a; color: #ddd; }
.meta-row { display: flex; gap: 1rem; margin: 0.5rem 0; }
.meta-field { display: flex; align-items: center; gap: 0.5rem; }
.meta-field label { font-size: 0.75rem; color: #888; font-weight: 500; white-space: nowrap; }
.meta-field input { padding: 0.3rem 0.5rem; background: #252525; border: 1px solid #333; border-radius: 6px; color: #ddd; font-size: 0.8rem; width: 80px; }
.meta-field input:focus { outline: none; border-color: var(--color-primary); }
.meta-field input::placeholder { color: #555; }

.board-area {
  margin-top: 0;
  overflow: hidden;
  height: 95vh;
  width: 100%;
  max-width: 100%;
  padding: 0;
}

.no-esercizi { text-align: center; padding: 2rem; color: #666; }

.save-error-banner { display: flex; align-items: center; gap: 1rem; padding: 0.75rem 1rem; background: rgba(220, 38, 38, 0.2); border: 1px solid #dc2626; border-radius: 8px; margin-bottom: 1rem; color: #fca5a5; }
.save-error-banner button { background: none; border: none; color: #fca5a5; cursor: pointer; font-size: 1.1rem; padding: 0 0.5rem; }

.catalogo-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.8); z-index: 1000; display: flex; align-items: center; justify-content: center; }
.catalogo-modal { background: #1a1a1a; border-radius: 12px; width: 90%; max-width: 800px; max-height: 80vh; display: flex; flex-direction: column; }
.catalogo-header { display: flex; justify-content: space-between; align-items: center; padding: 1rem 1.5rem; border-bottom: 1px solid #333; }
.catalogo-header h2 { margin: 0; color: #fff; font-size: 1.25rem; }
.catalogo-close { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; background: #dc2626; border: none; border-radius: 8px; color: white; cursor: pointer; font-size: 1.5rem; }
.catalogo-close:hover { background: #b91c1c; }
.catalogo-filters { display: flex; align-items: center; gap: 1rem; padding: 1rem 1.5rem; border-bottom: 1px solid #333; }
.catalogo-filters select { flex: 1; max-width: 300px; padding: 0.5rem 0.75rem; background: #252525; border: 1px solid #333; border-radius: 8px; color: #fff; font-size: 0.9rem; }
.catalogo-filters select:focus { outline: none; border-color: var(--color-primary); }
.catalogo-count { color: #888; font-size: 0.85rem; }
.catalogo-list { flex: 1; overflow-y: auto; padding: 1rem 1.5rem; display: flex; flex-direction: column; gap: 0.75rem; }
.catalogo-item { background: #252525; border: 1px solid #333; border-radius: 8px; padding: 1rem; cursor: pointer; transition: all 0.2s; }
.catalogo-item:hover { border-color: var(--color-primary); background: #2a2a2a; }
.catalogo-item-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
.catalogo-item-title { color: #fff; font-weight: 600; font-size: 1rem; }
.catalogo-item-focus { padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.75rem; font-weight: 500; background: #374151; color: #fff; }
.catalogo-item-focus.focus-tecnica { background: #3b82f6; }
.catalogo-item-focus.focus-tattica { background: #8b5cf6; }
.catalogo-item-focus.focus-fisico { background: #ef4444; }
.catalogo-item-focus.focus-capacita-coordinativa { background: #f59e0b; }
.catalogo-item-focus.focus-palleggio { background: #10b981; }
.catalogo-item-focus.focus-passaggio { background: #06b6d4; }
.catalogo-item-focus.focus-conclusione { background: #f97316; }
.catalogo-item-focus.focus-difesa { background: #6366f1; }
.catalogo-item-focus.focus-attacco { background: #ec4899; }
.catalogo-item-focus.focus-possessione { background: #84cc16; }
.catalogo-item-focus.focus-set-piece { background: #a855f7; }
.catalogo-item-body { display: flex; gap: 0.75rem; align-items: flex-start; }
.catalogo-item-info { flex: 1; min-width: 0; }
.catalogo-item-desc { color: #888; font-size: 0.85rem; line-height: 1.4; margin-bottom: 0.5rem; }
.catalogo-item-details { display: flex; gap: 0.75rem; flex-wrap: wrap; }
.catalogo-item-details .detail-item { color: #aaa; font-size: 0.8rem; }
.catalogo-item-preview { flex-shrink: 0; }
.catalogo-canvas { border-radius: 6px; border: 1px solid #333; }
.catalogo-item-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 0.5rem; gap: 0.5rem; }
.catalogo-item-count { color: #666; font-size: 0.75rem; flex: 1; }
.catalogo-item-already { color: #22c55e; font-size: 0.75rem; font-weight: 500; }
.catalogo-delete-btn { background: none; border: none; cursor: pointer; padding: 4px 8px; font-size: 0.9rem; opacity: 0.6; transition: opacity 0.2s; }
.catalogo-delete-btn:hover { opacity: 1; }
.catalogo-empty { text-align: center; padding: 2rem; color: #666; }
.catalogo-item.already-added { opacity: 0.6; cursor: not-allowed; }
.catalogo-item.already-added:hover { border-color: #333; background: #252525; }
.catalogo-visibilita-badge { padding: 0.2rem 0.55rem; border-radius: 12px; font-size: 0.7rem; font-weight: 500; background: rgba(234, 179, 8, 0.15); color: #eab308; white-space: nowrap; }

.save-dialog-visibility { margin-top: 1.25rem; display: flex; align-items: center; gap: 0.75rem; padding-top: 1rem; border-top: 1px solid #333; }
.save-dialog-visibility label { color: #888; font-size: 0.85rem; font-weight: 500; white-space: nowrap; }
.save-dialog-visibility select { flex: 1; padding: 0.5rem 0.75rem; background: #252525; border: 1px solid #333; border-radius: 8px; color: #fff; font-size: 0.85rem; cursor: pointer; }
.save-dialog-visibility select:focus { outline: none; border-color: var(--color-primary); }



.save-dialog { background: #1a1a1a; border-radius: 12px; width: 90%; max-width: 450px; }
.save-dialog-header { padding: 1rem 1.5rem; border-bottom: 1px solid #333; }
.save-dialog-header h3 { margin: 0; color: #fff; font-size: 1.1rem; }
.save-dialog-body { padding: 1.5rem; }
.save-dialog-body p { color: #ccc; margin-bottom: 1rem; line-height: 1.5; }
.save-dialog-titolo { display: flex; flex-direction: column; gap: 0.5rem; }
.save-dialog-titolo label { color: #888; font-size: 0.85rem; }
.save-dialog-input { width: 100%; padding: 0.75rem; background: #252525; border: 1px solid #333; border-radius: 8px; color: #fff; font-size: 0.95rem; box-sizing: border-box; }
.save-dialog-input:focus { outline: none; border-color: var(--color-primary); }
.save-dialog-warning { margin-top: 0.75rem; padding: 0.5rem; background: rgba(234, 179, 8, 0.2); border: 1px solid #eab308; border-radius: 6px; color: #eab308; font-size: 0.85rem; }
.save-dialog-actions { padding: 1rem 1.5rem; border-top: 1px solid #333; display: flex; gap: 0.75rem; justify-content: flex-end; }
.btn-save-private { padding: 0.5rem 1rem; background: #374151; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 500; }
.btn-save-private:hover { background: #4b5563; }
.btn-save-catalogo { padding: 0.5rem 1rem; background: var(--color-primary); border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 500; }
.btn-save-catalogo:hover { background: #059669; }
.btn-save-catalogo:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-cancel { padding: 0.5rem 1rem; background: transparent; border: 1px solid #444; border-radius: 8px; color: #888; cursor: pointer; }
.btn-cancel:hover { background: #252525; }
.esercizi-selezione { max-height: 300px; overflow-y: auto; margin-top: 1rem; }
.esercizio-checkbox { display: flex; align-items: center; gap: 0.75rem; padding: 0.5rem; border-radius: 6px; cursor: pointer; }
.esercizio-checkbox:hover { background: #252525; }
.esercizio-checkbox input[type="checkbox"] { width: 18px; height: 18px; cursor: pointer; }
.checkbox-titolo { color: #ccc; font-size: 0.95rem; }
.no-esercizi-selezione { color: #666; text-align: center; padding: 1rem; }
.checkbox-titolo.no-titolo { color: #666; font-style: italic; }

.rotate-device-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.95);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  flex-direction: column;
  gap: 1rem;
}

.rotate-device-message {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  color: white;
  text-align: center;
  padding: 2rem;
}

.rotate-device-message svg {
  width: 80px;
  height: 80px;
  animation: rotate-hint 1.5s ease-in-out infinite;
}

.rotate-device-message span {
  font-size: 1.25rem;
  font-weight: 600;
}

@keyframes rotate-hint {
  0%, 100% { transform: rotate(0deg); }
  25% { transform: rotate(-20deg); }
  75% { transform: rotate(20deg); }
}

@media (max-width: 900px) {
  .allenamenti-body { padding: 0.75rem 1rem 2rem; }
  .page-header { padding: 1rem 1rem 0.75rem; }
  .weeks-grid { grid-template-columns: repeat(2, 1fr); gap: 0.75rem; }
  .week-card { padding: 0.75rem; }
  .day-chip { width: 32px; height: 32px; font-size: 0.8rem; }
  .day-header { flex-wrap: wrap; gap: 0.5rem; }
  .day-header h3 { width: 100%; font-size: 0.9rem; }
  .day-actions { width: 100%; }
}

@media (max-width: 768px) and (orientation: landscape) {
  .allenamenti-body { padding: 0.15rem; display: flex; flex-direction: column; }
  .page-header { padding: 0.5rem 0.75rem; }
  .category-name { font-size: 1.5rem; }
  .header-subtitle { font-size: 0.75rem; }
  .header-top { gap: 0.35rem; margin-bottom: 0.5rem; }
  .btn-back-pill, .btn-pill { padding: 0.3rem 0.3rem 0.3rem 0.6rem; font-size: 0.7rem; }
  .btn-back-pill svg, .btn-pill svg { width: 20px; height: 20px; }
  .weeks-grid { grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 0.3rem; }
  .week-card { padding: 0.5rem; }
  .week-header { font-size: 0.75rem; }
  .week-dates { font-size: 0.65rem; margin-bottom: 0.4rem; }
  .day-chip { width: 26px; height: 26px; font-size: 0.7rem; }
  .month-nav-pill { margin-bottom: 0.5rem; padding: 0.35rem 0.35rem 0.35rem 0.75rem; gap: 0.5rem; }
  .current-month { font-size: 0.8rem; min-width: 120px; }
}

</style>
