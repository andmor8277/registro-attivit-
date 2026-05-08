<template>
  <div class="rotate-device-overlay" v-if="showRotateMessage">
    <div class="rotate-device-message">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="4" y="2" width="16" height="20" rx="2" ry="2"/>
        <line x1="12" y1="18" x2="12" y2="18"/>
      </svg>
      <span>Ruota il dispositivo in orizzontale</span>
    </div>
  </div>
  <div class="allenamenti-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/scelta/' + route.params.id)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>
        </button>
        <button class="btn-home" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
        </button>
      </div>
      <span class="titolo-toolbar">Allenamenti — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
    </header>

    <div class="allenamenti-body">
      <div class="month-nav">
        <button class="nav-btn" @click="prevMonth"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"/></svg></button>
        <div class="current-month">{{ currentMonthName }} {{ currentYear }}</div>
        <button class="nav-btn" @click="nextMonth"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg></button>
      </div>

      <div class="weeks-grid">
        <div v-for="week in weeksInMonth" :key="week.num" class="week-card" :class="{ active: selectedWeek?.num === week.num }" @click="selectWeek(week)">
          <div class="week-header">Settimana {{ week.num }}</div>
          <div class="week-dates">{{ formatDateRange(week.start, week.end) }}</div>
          <div class="week-days">
            <span v-for="day in week.days" :key="day.date" class="day-chip" :class="{ 'has-training': day.isSelectable, 'today': day.isToday, 'other-month': day.month !== currentMonth }" @click.stop="selectDay(day)">{{ day.dayNum }}</span>
          </div>
        </div>
      </div>

      <div v-if="selectedDay" class="day-detail">
        <div class="day-header">
          <button class="nav-btn" @click="clearSelectedDay" title="Torna al calendario">←</button>
          <h3>Allenamento del {{ formatDate(selectedDay.data) }}</h3>
          <button class="btn-add-exercise" @click="addEsercizio">+ Esercizio</button>
          <button class="btn-catalogo" @click="openCatalogo">📚 Catalogo</button>
          <button class="btn-save-exercise" @click="saveCurrentExercise" title="Salva">💾 Salva</button>
          <button class="btn-save-catalogo-explicit" @click="openSaveToCatalogoDialog" title="Salva nel Catalogo">💾 Salva nel Catalogo</button>
          <button class="btn-save-exercise" @click="exportPdf" title="Esporta PDF">📄 PDF</button>
        </div>

        <div class="esercizi-list">
          <div v-for="(ex, idx) in esercizi" :key="ex.id" class="esercizio-card" :class="{ active: selectedExercise?.id === ex.id }" :data-ex-id="ex.id" @click="selectExercise(ex)">
            <div class="esercizio-header">
              <span class="esercizio-num">{{ idx + 1 }}</span>
              <input v-model="ex.titolo" class="esercizio-titolo" placeholder="Titolo esercizio..." @change="saveEsercizio(ex)" />

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
                  <label>Spazio:</label>
                  <input type="text" v-model="ex.spazio" placeholder="es. 20x30m" @change="saveEsercizio(ex)" />
                </div>
                <div class="meta-field">
                  <label>Tempo:</label>
                  <input type="text" v-model="ex.tempo" placeholder="es. 3x4'" @change="saveEsercizio(ex)" />
                </div>
              </div>
              <textarea v-model="ex.descrizione" placeholder="Descrizione dell'esercizio..." @change="saveEsercizio(ex)"></textarea>
            </div>

            <div class="board-area">
              <TacticalBoard
                :elements="ex.elementi"
                :field-mode="ex.campo_con_righe === false ? 'blank' : (ex.campo_con_righe === 'half' ? 'half' : 'full')"
                @update:elements="(newElements) => updateElementi(ex, newElements)"
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
              <span class="catalogo-item-focus" :class="'focus-' + ex.focus">{{ ex.focus_label }}</span>
            </div>
            <div v-if="ex.descrizione" class="catalogo-item-desc">{{ ex.descrizione }}</div>
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
          <h3>💾 Salva nel Catalogo</h3>
        </div>
        <div class="save-dialog-body">
          <p>Seleziona gli esercizi da salvare nel catalogo:</p>
          <div class="esercizi-selezione">
              <label class="esercizio-checkbox" v-for="ex in eserciziConTitolo" :key="ex.id">
              <input type="checkbox" v-model="selectedForCatalogo[ex.id]" :disabled="!ex.titolo || !ex.titolo.trim()" />
              <span class="checkbox-titolo" :class="{ 'no-titolo': !ex.titolo || !ex.titolo.trim() }">{{ ex.titolo || 'Esercizio senza titolo' }}</span>
            </label>
            <div v-if="eserciziConTitolo.length === 0" class="no-esercizi-selezione">
              Non ci sono esercizi in questo allenamento
            </div>
          </div>
        </div>
        <div class="save-dialog-actions">
          <button class="btn-save-catalogo" @click="confirmSaveSelectedToCatalogo" :disabled="!hasSelectedForCatalogo">💾 Salva selezionati</button>
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
const saveError = ref('')
const hasChanges = ref(false)
let saveDebounceTimer = null
const saveLoading = ref(false)
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
          type: el.tipo ?? el.type,
          x: el.x ?? null,
          y: el.y ?? null,
          color: el.colore ?? el.color ?? '#3b82f6',
          num: el.numero ?? el.num ?? null,
          size: el.size ?? 28,
          w: el.w ?? null,
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
  } catch (e) {
    console.error('Errore caricamento catalogo:', e)
    catalogoEsercizi.value = []
  }
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
    campo_con_righe: ex.campo_con_righe !== false,
    elementi: (ex.elementi || []).map(el => ({
      ...el,
      id: generateId('el_')
    })),
    fromCatalogo: true,
    catalogoTitolo: ex.titolo
  })
  selectedExercise.value = esercizi.value[esercizi.value.length - 1]
  closeCatalogo()
}

function addEsercizio() {
  esercizi.value.push({ id: generateId(), ordine: esercizi.value.length + 1, titolo: '', descrizione: '', focus: '', campo_con_righe: true, elementi: [] })
  selectedExercise.value = esercizi.value[esercizi.value.length - 1]
  hasChanges.value = true
}

function deleteEsercizio(ex) { 
  esercizi.value = esercizi.value.filter(e => e.id !== ex.id)
  if (esercizi.value.length > 0) {
    selectedExercise.value = esercizi.value[0]
  }
  hasChanges.value = true
  saveDataToServer()
}

function saveCurrentExercise() {
  if (esercizi.value.length === 0) return
  if (saveDebounceTimer) {
    clearTimeout(saveDebounceTimer)
    saveDebounceTimer = null
  }
  saveDataToServer()
}

function exportPdf() {
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

    // Canvas snapshot - immagine grande
    y += 5
    if (ex.elementi && ex.elementi.length > 0) {
      const card = document.querySelector(`.esercizio-card[data-ex-id="${ex.id}"]`)
      if (card) {
        const canvas = card.querySelector('canvas')
        if (canvas) {
          try {
            const imgData = canvas.toDataURL('image/png')
            const availableH = pageHeight - y - 10
            const maxW = pageWidth - (margin * 2)
            const maxH = availableH
            const ratio = Math.min(maxW / canvas.width, maxH / canvas.height, 1)
            const imgW = canvas.width * ratio
            const imgH = canvas.height * ratio
            doc.addImage(imgData, 'PNG', margin, y, imgW, imgH)
          } catch (e) {
            console.warn('Errore rendering canvas nel PDF:', e)
          }
        }
      }
    }
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
    esercizi.value[idx].elementi = newElements
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

  const payload = {
    categoria_id: categoriaId,
    data: selectedDay.value.data,
    esercizi: esercizi.value.map((e, idx) => ({
      ordine: idx + 1,
      titolo: e.titolo || '',
      descrizione: e.descrizione || '',
      focus: e.focus || '',
      spazio: e.spazio || '',
      tempo: e.tempo || '',
      campo_con_righe: e.campo_con_righe !== false,
      elementi: (e.elementi || []).map(el => ({
        tipo:      el.tipo      ?? el.type   ?? '',
        x:         el.x        ?? null,
        y:         el.y        ?? null,
        rotazione: el.rotazione ?? 0,
        colore:    el.colore    ?? el.color  ?? null,
        numero:    el.numero    ?? el.num    ?? null,
        size:      el.size      ?? null,
        w:         el.w        ?? null,
        x1:        el.x1       ?? null,
        y1:        el.y1       ?? null,
        x2:        el.x2       ?? null,
        y2:        el.y2       ?? null,
        points:    el.points   ?? null,
        text:      el.text     ?? null,
        length:    el.length   ?? null,
        wavy:      el.wavy     ?? false,
      }))
    }))
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
      console.error('Errore salvataggio:', err)
    })
}

function openSaveToCatalogoDialog() {
  const exercisesWithTitles = esercizi.value.filter(e => e.titolo && e.titolo.trim())
  if (exercisesWithTitles.length === 0) {
    alert('Non ci sono esercizi con titolo da salvare nel catalogo')
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
      elementi: ex.elementi || []
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
    let msg = `Salvati ${savedCount} esercizi nel catalogo!`
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

onBeforeRouteLeave(() => {
  if (hasChanges.value) {
    saveDataToServer()
  }
})

onUnmounted(() => {
  hideTopbar.value = false
})
</script>

<style scoped>
.allenamenti-page { display: flex; flex-direction: column; height: 100vh; background: #0a0a0a; min-width: 100%; overflow: hidden; }
.allenamenti-body { flex: 1; overflow-y: auto; padding: 1rem; width: 100%; box-sizing: border-box; display: flex; flex-direction: column; }
.page-header { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1rem; background: var(--color-primary); flex-shrink: 0; }
.header-left { display: flex; gap: 0.25rem; }
.btn-back, .btn-home { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; }
.btn-back svg, .btn-home svg { width: 18px; height: 18px; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 1rem; color: white; }
.month-nav { display: flex; align-items: center; justify-content: center; gap: 1rem; margin-bottom: 1.5rem; }
.nav-btn { width: 40px; height: 40px; display: flex; align-items: center; justify-content: center; background: #1a1a1a; border: 1px solid #333; border-radius: 8px; color: white; cursor: pointer; }
.nav-btn svg { width: 20px; height: 20px; }
.current-month { font-size: 1.25rem; font-weight: bold; color: white; min-width: 180px; text-align: center; }
.weeks-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; margin-bottom: 1rem; }
.week-card { background: #141414; border: 1px solid #222; border-radius: 12px; padding: 1rem; cursor: pointer; transition: all 0.2s; }
.week-card:hover { border-color: var(--color-primary); }
.week-card.active { border-color: var(--color-primary); background: rgba(16, 185, 129, 0.15); }
.week-header { font-weight: bold; color: #fff; margin-bottom: 0.25rem; font-size: 0.95rem; }
.week-dates { font-size: 0.8rem; color: #888; margin-bottom: 0.75rem; font-weight: 500; }
.week-days { display: flex; gap: 0.35rem; flex-wrap: wrap; }
.day-chip { width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; background: #252525; border-radius: 8px; font-size: 0.85rem; color: #666; cursor: not-allowed; border: 1px solid #333; }
.day-chip.has-training { background: var(--color-primary); color: white; cursor: pointer; border: 1px solid var(--color-primary); font-weight: 600; }
.day-chip.has-training:hover { transform: scale(1.1); background: #059669; }
.day-chip.today { border: 2px solid #fff; box-shadow: 0 0 0 2px rgba(255,255,255,0.3); }
.day-chip.other-month { opacity: 0.4; }
.day-detail { background: #141414; border-radius: 12px; padding: 1rem; width: 100%; box-sizing: border-box; margin-top: 1rem; }
.day-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; flex-wrap: wrap; gap: 0.5rem; }
.day-header h3 { color: #fff; margin: 0; font-size: 1rem; }
.btn-add-exercise { padding: 0.5rem 1rem; background: var(--color-primary); border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; white-space: nowrap; }
.btn-save-exercise { padding: 0.5rem 1rem; background: #22c55e; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; white-space: nowrap; }
.btn-save-exercise:hover { background: #16a34a; }
.btn-save-catalogo-explicit { padding: 0.5rem 1rem; background: #8b5cf6; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; white-space: nowrap; }
.btn-save-catalogo-explicit:hover { background: #7c3aed; }
.esercizi-list { display: flex; flex-direction: column; gap: 2rem; }
.esercizio-card { background: #1a1a1a; border-radius: 12px; padding: 1rem; width: 100%; box-sizing: border-box; }
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
.catalogo-item-desc { color: #888; font-size: 0.85rem; margin-bottom: 0.5rem; }
.catalogo-item-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 0.5rem; gap: 0.5rem; }
.catalogo-item-count { color: #666; font-size: 0.75rem; flex: 1; }
.catalogo-item-already { color: #22c55e; font-size: 0.75rem; font-weight: 500; }
.catalogo-delete-btn { background: none; border: none; cursor: pointer; padding: 4px 8px; font-size: 0.9rem; opacity: 0.6; transition: opacity 0.2s; }
.catalogo-delete-btn:hover { opacity: 1; }
.catalogo-empty { text-align: center; padding: 2rem; color: #666; }
.catalogo-item.already-added { opacity: 0.6; cursor: not-allowed; }
.catalogo-item.already-added:hover { border-color: #333; background: #252525; }

.btn-catalogo { padding: 0.5rem 1rem; background: #8b5cf6; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; margin-left: 0.5rem; }
.btn-catalogo:hover { background: #7c3aed; }

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
  .allenamenti-body { padding: 0.5rem; display: flex; flex-direction: column; }
  .page-header { padding: 0.5rem 0.75rem; flex-shrink: 0; }
  .titolo-toolbar { font-size: 0.85rem; }
  .weeks-grid { grid-template-columns: repeat(2, 1fr); gap: 0.75rem; }
  .month-nav { margin-bottom: 0.5rem; }
  .week-card { padding: 0.75rem; }
  .day-chip { width: 32px; height: 32px; font-size: 0.8rem; }
  .day-header { flex-wrap: wrap; gap: 0.5rem; }
  .day-header h3 { width: 100%; font-size: 0.9rem; }
  .day-header button { font-size: 0.75rem; padding: 0.4rem 0.6rem; }
}

@media (max-width: 768px) and (orientation: landscape) {
  .allenamenti-body { padding: 0.15rem; display: flex; flex-direction: column; }
  .page-header { padding: 0.2rem 0.3rem; flex-shrink: 0; }
  .btn-back, .btn-home { width: 24px; height: 24px; }
  .btn-back svg, .btn-home svg { width: 14px; height: 14px; }
  .titolo-toolbar { font-size: 0.65rem; }
  .weeks-grid { grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 0.5rem; }
  .week-card { padding: 0.5rem; }
  .week-header { font-size: 0.8rem; }
  .week-dates { font-size: 0.7rem; margin-bottom: 0.5rem; }
  .day-chip { width: 28px; height: 28px; font-size: 0.75rem; gap: 0.2rem; }
  .month-nav { margin-bottom: 0.3rem; }
  .current-month { font-size: 0.9rem; min-width: 120px; }
  .weeks-grid { grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 0.3rem; }
}

</style>
