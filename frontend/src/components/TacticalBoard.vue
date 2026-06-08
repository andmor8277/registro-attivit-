<template>
  <div class="tactical-board">
    <header class="tb-header">
      <button class="tb-btn" :disabled="histIdx <= 0" @click="undo" title="Annulla">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M3 10h11a7 7 0 0 1 0 14H3"/><polyline points="3,3 3,10 10,10"/></svg>
      </button>
      <button class="tb-btn" :disabled="histIdx >= history.length - 1" @click="redo" title="Ripeti">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M21 10H10a7 7 0 0 0 0 14h11"/><polyline points="21,3 21,10 14,10"/></svg>
      </button>
      <button class="tb-btn tb-danger" @click="clearBoard" title="Pulisci">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/></svg>
      </button>
    </header>

    <div class="tb-main">
      <div class="tb-sidebar">
        <div class="tb-section">
          <div class="tb-label">Base</div>
          <button class="tb-tool" :class="{ active: tool === 'select' }" data-tool="select" @click="selectTool('select')" title="Seleziona">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 3l14 9-7 1-3 7z"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'pencil' }" data-tool="pencil" @click="selectTool('pencil')" title="Matita">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'erase' }" data-tool="erase" @click="selectTool('erase')" title="Gomma">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 20H7L3 16l10-10 7 7-3.5 3.5"/><path d="M6.5 17.5l5-5"/></svg>
          </button>
        </div>

        <div class="tb-divider"></div>

        <div class="tb-section">
          <div class="tb-label">Frecce</div>
          <button class="tb-tool" :class="{ active: tool === 'arrow' }" @click="selectTool('arrow')" title="Passaggio">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><line x1="4" y1="12" x2="20" y2="12"/><polyline points="14,6 20,12 14,18"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'arrow-dash' }" @click="selectTool('arrow-dash')" title="Movimento">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-dasharray="4 2"><line x1="4" y1="12" x2="17" y2="12"/><polyline points="13,7 19,12 13,17"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'arrow-curve' }" @click="selectTool('arrow-curve')" title="Curva">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M4 18 Q12 4 20 12"/><polyline points="14,7 20,12 15,17"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'arrow-curve-dash' }" @click="selectTool('arrow-curve-dash')" title="Mov. senza">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-dasharray="4 2"><path d="M4 18 Q12 4 20 12"/><polyline points="14,7 20,12 15,17"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'one-two' }" @click="selectTool('one-two')" title="Uno-due">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><line x1="4" y1="12" x2="20" y2="12"/><polyline points="14,6 20,12 14,18"/><polyline points="10,6 4,12 10,18"/></svg>
          </button>
        </div>

        <div class="tb-divider"></div>

        <div class="tb-section">
          <div class="tb-label">Giocatori</div>
          <button class="tb-tool" :class="{ active: tool === 'player' }" @click="selectTool('player')" title="Giocatore">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="#3b82f6"><circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/></svg>
          </button>
        </div>

        <div class="tb-divider"></div>

        <div class="tb-section">
          <div class="tb-label">Pallone</div>
          <button class="tb-tool" :class="{ active: tool === 'ball' }" @click="selectTool('ball')" title="Pallone">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="9"/><path d="M12 3c0 0 3 4 3 9s-3 9-3 9M12 3c0 0-3 4-3 9s3 9 3 9M3 12h18"/></svg>
          </button>
        </div>

        <div class="tb-divider"></div>

        <div class="tb-section">
          <div class="tb-label">Oggetti</div>
          <button class="tb-tool" :class="{ active: tool === 'cone' }" @click="selectTool('cone')" title="Cono">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="#f97316"><polygon points="12,3 20,21 4,21"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'disc' }" @click="selectTool('disc')" title="Cinesino">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="#a78bfa"><ellipse cx="12" cy="19" rx="8" ry="3"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'goal-large' }" @click="selectTool('goal-large')" title="Porta grande">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="6" width="20" height="12" rx="1"/><line x1="2" y1="6" x2="2" y2="18"/><line x1="22" y1="6" x2="22" y2="18"/><line x1="7" y1="6" x2="7" y2="18"/><line x1="12" y1="6" x2="12" y2="18"/><line x1="17" y1="6" x2="17" y2="18"/><line x1="2" y1="10" x2="22" y2="10"/><line x1="2" y1="14" x2="22" y2="14"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'goal-small' }" @click="selectTool('goal-small')" title="Porta piccola">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="7" width="16" height="10" rx="1"/><line x1="4" y1="7" x2="4" y2="17"/><line x1="20" y1="7" x2="20" y2="17"/><line x1="8" y1="7" x2="8" y2="17"/><line x1="12" y1="7" x2="12" y2="17"/><line x1="16" y1="7" x2="16" y2="17"/><line x1="4" y1="12" x2="20" y2="12"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'ladder' }" @click="selectTool('ladder')" title="Scaletta">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="1.8"><rect x="2" y="6" width="20" height="12" rx="1" fill="none"/><line x1="2" y1="10" x2="22" y2="10"/><line x1="2" y1="14" x2="22" y2="14"/><line x1="5" y1="6" x2="5" y2="18"/><line x1="8" y1="6" x2="8" y2="18"/><line x1="11" y1="6" x2="11" y2="18"/><line x1="14" y1="6" x2="14" y2="18"/><line x1="17" y1="6" x2="17" y2="18"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'pole' }" @click="selectTool('pole')" title="Paletto">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><ellipse cx="11" cy="20" rx="5" ry="2" fill="#94a3b8"/><rect x="9" y="3" width="4" height="4" fill="#ef4444"/><rect x="9" y="7" width="4" height="4" fill="#fff"/><rect x="9" y="11" width="4" height="4" fill="#ef4444"/><rect x="9" y="15" width="4" height="4" fill="#fff"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'rod' }" @click="selectTool('rod')" title="Sbarra">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><rect x="2" y="9" width="20" height="4" rx="1" fill="#eab308"/><circle cx="3" cy="11" r="3" fill="#ca8a04"/><circle cx="21" cy="11" r="3" fill="#ca8a04"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'zone' }" @click="selectTool('zone')" title="Zona">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="rgba(59,130,246,0.25)" stroke="currentColor" stroke-width="1.8" stroke-dasharray="3 2"><rect x="3" y="5" width="18" height="14" rx="2"/></svg>
          </button>
          <button class="tb-tool" :class="{ active: tool === 'text' }" @click="selectTool('text')" title="Testo">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7V4h16v3M9 20h6M12 4v16"/></svg>
          </button>
        </div>
      </div>

      <div class="tb-canvas-wrap" ref="canvasWrapRef">
        <canvas ref="canvasRef"></canvas>
      </div>

      <div class="tb-right">
        <div class="tb-panel">
          <div class="tb-panel-title">Colore</div>
          <div class="tb-color-grid">
            <div v-for="c in colors" :key="c" class="tb-swatch" :class="{ active: color === c }" :style="{ background: c }" @click="selectColor(c)"></div>
          </div>
        </div>

        <div class="tb-panel">
          <div class="tb-panel-title">Dimensione</div>
          <div class="tb-size-row">
            <label>Spessore</label>
            <input type="range" min="1" max="10" value="2" @input="strokeWidth = +$event.target.value" />
          </div>
          <div class="tb-size-row">
            <label>Elemento</label>
            <input type="range" min="16" max="60" value="28" @input="elemSize = +$event.target.value" />
          </div>
        </div>

        <div class="tb-panel">
          <div class="tb-panel-title">Campo</div>
          <div class="tb-mode-row">
            <div class="tb-chip" :class="{ active: internalFieldMode === 'full' }" @click="internalFieldMode = 'full'; resizeCanvas()">Intero</div>
            <div class="tb-chip" :class="{ active: internalFieldMode === 'half' }" @click="internalFieldMode = 'half'; resizeCanvas()">Metà</div>
            <div class="tb-chip" :class="{ active: internalFieldMode === 'blank' }" @click="internalFieldMode = 'blank'; resizeCanvas()">Vuoto</div>
          </div>
        </div>

        <div class="tb-panel" v-if="selectedIdx >= 0">
          <div class="tb-panel-title">Modifica</div>
          <button class="tb-delete-btn" @click="deleteSelected" title="Elimina elemento">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
            Elimina
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue'

const props = defineProps({
  elements: { type: Array, default: () => [] },
  fieldMode: { type: String, default: 'full' }
})

const emit = defineEmits(['update:elements'])

const canvasRef = ref(null)
const canvasWrapRef = ref(null)

let ctx = null
let canvasW = 0
let canvasH = 0
let fieldPad = 0
let fieldW = 0
let fieldH = 0
let fieldX = 0
let fieldY = 0

const tool = ref('select')
const color = ref('#000000')
const strokeWidth = ref(2)
const elemSize = ref(28)
const internalFieldMode = ref(props.fieldMode)
const elements = ref([])
const history = ref([[]])
const histIdx = ref(0)
const selectedIdx = ref(-1)

let isDrawing = false
let drawStart = null
let drawCurrent = null
let freePoints = []
let resizingArrow = null
let resizingEnd = null
let dragging = false
let dragOffset = { x: 0, y: 0 }
let dragStart = null

const colors = ['#3b82f6', '#ef4444', '#22c55e', '#f59e0b', '#f97316', '#ffffff', '#a78bfa', '#ec4899', '#06b6d4', '#000000']

// Virtual coordinate system: 0-100 x 0-100 (field space)
function fieldToCanvas(fx, fy) {
  return {
    x: fieldX + (fx / 100) * fieldW,
    y: fieldY + (fy / 100) * fieldH
  }
}

function canvasToField(cx, cy) {
  return {
    x: ((cx - fieldX) / fieldW) * 100,
    y: ((cy - fieldY) / fieldH) * 100
  }
}

function canvasToPercent(cx, cy) {
  const f = canvasToField(cx, cy)
  return { x: f.x, y: f.y }
}

function percentToCanvas(px, py) {
  return fieldToCanvas(px, py)
}

function convertToCanvas(el) {
  const c = percentToCanvas(el.x, el.y)
  const converted = { ...el, x: c.x, y: c.y }
  if (el.x1 !== undefined) {
    const p1 = percentToCanvas(el.x1, el.y1)
    const p2 = percentToCanvas(el.x2 || el.x1, el.y2 || el.y1)
    converted.x1 = p1.x
    converted.y1 = p1.y
    converted.x2 = p2.x
    converted.y2 = p2.y
  }
  if (el.points) {
    converted.points = el.points.map(p => percentToCanvas(p.x, p.y))
  }
  return converted
}

function convertToPercent(el) {
  const p = canvasToPercent(el.x, el.y)
  const converted = { ...el, x: p.x, y: p.y }
  if (el.x1 !== undefined) {
    const c1 = canvasToPercent(el.x1, el.y1)
    const c2 = canvasToPercent(el.x2, el.y2)
    converted.x1 = c1.x
    converted.y1 = c1.y
    converted.x2 = c2.x
    converted.y2 = c2.y
  }
  if (el.points) {
    converted.points = el.points.map(p => canvasToPercent(p.x, p.y))
  }
  return converted
}

function syncToServer() {
  if (_syncDisabled) return
  if (!canvasW || !canvasH) return
  const percentElements = elements.value.map(el => convertToPercent(el))
  emit('update:elements', percentElements)
}

let _syncDisabled = false
let _pendingProps = null

function setSyncEnabled(enabled) {
  _syncDisabled = !enabled
}

watch(() => props.elements, (newVal) => {
  setSyncEnabled(false)
  if (fieldW > 0 && fieldH > 0) {
    elements.value = (newVal || []).map(el => convertToCanvas(el))
    histIdx.value = -1
    history.value = [JSON.parse(JSON.stringify(elements.value))]
    histIdx.value = 0
    draw()
  }
  nextTick(() => { setSyncEnabled(true) })
}, { deep: false })

watch(() => props.fieldMode, (val) => {
  internalFieldMode.value = val
  resizeCanvas()
})

watch(internalFieldMode, () => {
  const pcts = elements.value.map(el => convertToPercent(el))
  resizeCanvas(true)
  elements.value = pcts.map(el => convertToCanvas(el))
  draw()
})

function resizeCanvas(skipDraw = false) {
  const wrap = canvasWrapRef.value
  const canvas = canvasRef.value
  if (!wrap || !canvas) return

  const ww = wrap.clientWidth - 32
  const wh = wrap.clientHeight - 32
  if (ww <= 0 || wh <= 0) {
    setTimeout(() => resizeCanvas(skipDraw), 50)
    return
  }

  const isHalf = internalFieldMode.value === 'half'
  const ratio = isHalf ? (105 / 2) / 68 : 105 / 68
  let cw, ch
  if (ww / wh > ratio) {
    ch = wh
    cw = ch * ratio
  } else {
    cw = ww
    ch = cw / ratio
  }

  const dpr = window.devicePixelRatio || 1
  canvas.width = Math.floor(cw * dpr)
  canvas.height = Math.floor(ch * dpr)
  canvas.style.width = Math.floor(cw) + 'px'
  canvas.style.height = Math.floor(ch) + 'px'
  ctx = canvas.getContext('2d')
  ctx.scale(dpr, dpr)
  canvasW = Math.floor(cw)
  canvasH = Math.floor(ch)

  // Set field coords here so convertToCanvas works (was only in draw())
  const pad = canvasH * 0.05
  fieldW = canvasW - pad * 2
  fieldH = canvasH - pad * 2
  fieldX = pad
  fieldY = pad

  // Convert pending elements now that fieldW/fieldH are valid
  if (_pendingProps && _pendingProps.length > 0 && elements.value.length === 0) {
    elements.value = _pendingProps.map(el => convertToCanvas(el))
    _pendingProps = null
    histIdx.value = 0
    history.value = [JSON.parse(JSON.stringify(elements.value))]
  }

  if (!skipDraw) draw()
}

function draw() {
  if (!ctx) return
  ctx.clearRect(0, 0, canvasW, canvasH)

  const fm = internalFieldMode.value
  const isBlank = fm === 'blank'
  const isHalf = fm === 'half'

  // Always set field coords so percentToCanvas/canvasToPercent work
  const pad = canvasH * 0.05
  const fw = canvasW - pad * 2
  const fh = canvasH - pad * 2
  const fx = pad, fy = pad
  fieldX = fx
  fieldY = fy
  fieldW = fw
  fieldH = fh

  // Grass stripes
  const stripeCount = isBlank ? 6 : (isHalf ? 6 : 11)
  const sw = canvasW / stripeCount
  for (let i = 0; i < stripeCount; i++) {
    ctx.fillStyle = i % 2 === 0 ? '#2d5a1b' : '#346b20'
    ctx.fillRect(i * sw, 0, sw, canvasH)
  }

  // Blank mode: just grass, no lines
  if (!isBlank) {
    ctx.strokeStyle = 'rgba(255,255,255,0.88)'
    ctx.lineWidth = Math.max(1, canvasH * 0.004)
    ctx.lineCap = 'round'

    // Outer border
    ctx.strokeRect(fx, fy, fw, fh)

    // Half field: only outer border, nothing else
    if (!isHalf) {
    // Center line (vertical)
    ctx.beginPath()
    ctx.moveTo(fx + fw / 2, fy)
    ctx.lineTo(fx + fw / 2, fy + fh)
    ctx.stroke()
    // Center circle
    ctx.beginPath()
    ctx.arc(fx + fw / 2, fy + fh / 2, fh * 0.146, 0, Math.PI * 2)
    ctx.stroke()
    // Center dot
    ctx.beginPath()
    ctx.arc(fx + fw / 2, fy + fh / 2, canvasH * 0.007, 0, Math.PI * 2)
    ctx.fillStyle = 'rgba(255,255,255,0.88)'
    ctx.fill()

    // Penalty areas
    const paH = fh * 0.384
    const paW = fw * 0.157
    const paY = fy + (fh - paH) / 2

    // Goal areas
    const gaH = fh * 0.27
    const gaW = fw * 0.052
    const gaY = fy + (fh - gaH) / 2

    // Left penalty area
    ctx.strokeRect(fx, paY, paW, paH)
    ctx.strokeRect(fx, gaY, gaW, gaH)
    // Left penalty spot
    ctx.beginPath()
    ctx.arc(fx + fw * 0.105, fy + fh / 2, canvasH * 0.006, 0, Math.PI * 2)
    ctx.fill()
    // Left arc
    ctx.beginPath()
    ctx.arc(fx + fw * 0.105, fy + fh / 2, fh * 0.146, -0.93, 0.93)
    ctx.stroke()

    // Right penalty area
    ctx.strokeRect(fx + fw - paW, paY, paW, paH)
    ctx.strokeRect(fx + fw - gaW, gaY, gaW, gaH)
    // Right penalty spot
    ctx.beginPath()
    ctx.arc(fx + fw * 0.895, fy + fh / 2, canvasH * 0.006, 0, Math.PI * 2)
    ctx.fill()
    // Right arc
    ctx.beginPath()
    ctx.arc(fx + fw * 0.895, fy + fh / 2, fh * 0.146, Math.PI - 0.93, Math.PI + 0.93)
    ctx.stroke()

    // Corner arcs
    const cr = fh * 0.018
    ctx.strokeStyle = 'rgba(255,255,255,0.88)'
    const corners = [
      [fx, fy, 0, Math.PI / 2],
      [fx + fw, fy, Math.PI / 2, Math.PI],
      [fx, fy + fh, 3 * Math.PI / 2, 2 * Math.PI],
      [fx + fw, fy + fh, Math.PI, 3 * Math.PI / 2]
    ]
    for (let c = 0; c < corners.length; c++) {
      ctx.beginPath()
      ctx.arc(corners[c][0], corners[c][1], cr, corners[c][2], corners[c][3])
      ctx.stroke()
    }

    // Goals
    const gH = fh * 0.11
    const gW = fw * 0.024
    const gY = fy + (fh - gH) / 2
    ctx.strokeStyle = 'rgba(255,255,255,0.7)'
    ctx.lineWidth = 2
    ctx.strokeRect(fx - gW, gY, gW, gH)
    ctx.strokeRect(fx + fw, gY, gW, gH)
    }
  }

  // Draw elements
  const els = elements.value || []
  for (let i = 0; i < els.length; i++) {
    const el = els[i]
    const selected = i === selectedIdx.value
    if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash', 'one-two'].includes(el.type)) {
      drawArrow(el, selected)
    } else if (el.type === 'zone') {
      drawZone(el, selected)
    } else {
      drawElement(el, selected)
    }
  }

  // Draw current drawing
  if (isDrawing && drawCurrent && ['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash', 'one-two', 'zone'].includes(tool.value)) {
    const t = tool.value
    if (t === 'zone') {
      drawZone({ x1: drawStart.x, y1: drawStart.y, x2: drawCurrent.x, y2: drawCurrent.y, color: color.value }, false)
    } else if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash', 'one-two'].includes(t)) {
      drawArrow({ x1: drawStart.x, y1: drawStart.y, x2: drawCurrent.x, y2: drawCurrent.y, type: t, color: color.value, w: strokeWidth.value }, false)
    }
  }
}

function drawElement(el, selected) {
  const { type, x, y, color: c, size: s } = el
  ctx.save()
  if (selected) {
    ctx.shadowColor = '#fff'
    ctx.shadowBlur = 8
  }

  switch (type) {
    case 'player': {
      const pc = c || color.value
      const r = s / 2
      ctx.beginPath()
      ctx.ellipse(x, y + r * 0.9, r * 0.6, r * 0.18, 0, 0, Math.PI * 2)
      ctx.fillStyle = 'rgba(0,0,0,0.3)'
      ctx.fill()
      ctx.beginPath()
      ctx.arc(x, y, r, 0, Math.PI * 2)
      ctx.fillStyle = pc
      ctx.fill()
      ctx.strokeStyle = 'rgba(255,255,255,0.6)'
      ctx.lineWidth = 1.5
      ctx.stroke()
      if (el.num) {
        ctx.fillStyle = '#fff'
        ctx.font = `bold ${r * 0.9}px Inter,sans-serif`
        ctx.textAlign = 'center'
        ctx.textBaseline = 'middle'
        ctx.fillText(el.num, x, y)
      }
      break
    }
    case 'ball': {
      const r = s / 2.5
      ctx.beginPath()
      ctx.arc(x, y, r, 0, Math.PI * 2)
      ctx.fillStyle = c || '#fff'
      ctx.fill()
      ctx.strokeStyle = 'rgba(0,0,0,0.3)'
      ctx.lineWidth = 1
      ctx.stroke()
      ctx.fillStyle = c || '#111'
      ctx.beginPath()
      ctx.moveTo(x, y - r * 0.5)
      ctx.lineTo(x + r * 0.3, y - r * 0.1)
      ctx.lineTo(x, y + r * 0.3)
      ctx.lineTo(x - r * 0.3, y - r * 0.1)
      ctx.closePath()
      ctx.fill()
      break
    }
    case 'cone': {
      const bw = s * 0.6, bh = s * 0.7
      ctx.beginPath()
      ctx.moveTo(x, y - bh / 2)
      ctx.lineTo(x + bw / 2, y + bh / 2)
      ctx.lineTo(x - bw / 2, y + bh / 2)
      ctx.closePath()
      ctx.fillStyle = c || '#f97316'
      ctx.fill()
      ctx.strokeStyle = 'rgba(255,255,255,0.3)'
      ctx.lineWidth = 1
      ctx.stroke()
      break
    }
    case 'disc': {
      ctx.beginPath()
      ctx.ellipse(x, y, s / 2, s / 5, 0, 0, Math.PI * 2)
      ctx.fillStyle = c || '#a78bfa'
      ctx.fill()
      ctx.strokeStyle = 'rgba(255,255,255,0.3)'
      ctx.lineWidth = 1
      ctx.stroke()
      break
    }
    case 'goal': {
      const gw = s * 2.2, gh = s * 0.8
      ctx.strokeStyle = '#fff'
      ctx.lineWidth = 3
      ctx.lineJoin = 'round'
      ctx.strokeRect(x - gw / 2, y - gh / 2, gw, gh)
      ctx.strokeStyle = 'rgba(255,255,255,0.3)'
      ctx.lineWidth = 0.8
      for (let i = 1; i < 4; i++) {
        ctx.beginPath()
        ctx.moveTo(x - gw / 2 + (gw / 4) * i, y - gh / 2)
        ctx.lineTo(x - gw / 2 + (gw / 4) * i, y + gh / 2)
        ctx.stroke()
      }
      ctx.beginPath()
      ctx.moveTo(x - gw / 2, y)
      ctx.lineTo(x + gw / 2, y)
      ctx.stroke()
      break
    }
    case 'goal-large': {
      const gw = s * 1.8, gh = s * 0.6
      ctx.strokeStyle = '#fff'
      ctx.lineWidth = 2.5
      ctx.lineJoin = 'round'
      ctx.strokeRect(x - gw / 2, y - gh / 2, gw, gh)
      ctx.strokeStyle = 'rgba(255,255,255,0.5)'
      ctx.lineWidth = 0.8
      for (let i = 1; i < 5; i++) {
        ctx.beginPath()
        ctx.moveTo(x - gw / 2 + (gw / 5) * i, y - gh / 2)
        ctx.lineTo(x - gw / 2 + (gw / 5) * i, y + gh / 2)
        ctx.stroke()
      }
      for (let j = 1; j < 3; j++) {
        ctx.beginPath()
        ctx.moveTo(x - gw / 2, y - gh / 2 + (gh / 3) * j)
        ctx.lineTo(x + gw / 2, y - gh / 2 + (gh / 3) * j)
        ctx.stroke()
      }
      ctx.strokeStyle = 'rgba(255,255,255,0.3)'
      ctx.lineWidth = 1.5
      ctx.beginPath()
      ctx.moveTo(x - gw / 2 - 4, y - gh / 2)
      ctx.lineTo(x - gw / 2, y - gh / 2)
      ctx.lineTo(x - gw / 2, y + gh / 2)
      ctx.lineTo(x - gw / 2 - 4, y + gh / 2)
      ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(x + gw / 2 + 4, y - gh / 2)
      ctx.lineTo(x + gw / 2, y - gh / 2)
      ctx.lineTo(x + gw / 2, y + gh / 2)
      ctx.lineTo(x + gw / 2 + 4, y + gh / 2)
      ctx.stroke()
      break
    }
    case 'goal-small': {
      const gw = s * 1.2, gh = s * 0.5
      ctx.strokeStyle = '#fff'
      ctx.lineWidth = 2
      ctx.lineJoin = 'round'
      ctx.strokeRect(x - gw / 2, y - gh / 2, gw, gh)
      ctx.strokeStyle = 'rgba(255,255,255,0.5)'
      ctx.lineWidth = 0.7
      for (let i = 1; i < 4; i++) {
        ctx.beginPath()
        ctx.moveTo(x - gw / 2 + (gw / 4) * i, y - gh / 2)
        ctx.lineTo(x - gw / 2 + (gw / 4) * i, y + gh / 2)
        ctx.stroke()
      }
      for (let j = 1; j < 3; j++) {
        ctx.beginPath()
        ctx.moveTo(x - gw / 2, y - gh / 2 + (gh / 3) * j)
        ctx.lineTo(x + gw / 2, y - gh / 2 + (gh / 3) * j)
        ctx.stroke()
      }
      ctx.strokeStyle = 'rgba(255,255,255,0.3)'
      ctx.lineWidth = 1.2
      ctx.beginPath()
      ctx.moveTo(x - gw / 2 - 3, y - gh / 2)
      ctx.lineTo(x - gw / 2, y - gh / 2)
      ctx.lineTo(x - gw / 2, y + gh / 2)
      ctx.lineTo(x - gw / 2 - 3, y + gh / 2)
      ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(x + gw / 2 + 3, y - gh / 2)
      ctx.lineTo(x + gw / 2, y - gh / 2)
      ctx.lineTo(x + gw / 2, y + gh / 2)
      ctx.lineTo(x + gw / 2 + 3, y + gh / 2)
      ctx.stroke()
      break
    }
    case 'ladder': {
      const lw = s * 1.6, lh = s * 0.45
      ctx.strokeStyle = c || '#f59e0b'
      ctx.lineWidth = 2
      ctx.beginPath()
      ctx.rect(x - lw / 2, y - lh / 2, lw, lh)
      ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(x - lw / 2, y - lh / 2)
      ctx.lineTo(x + lw / 2, y - lh / 2)
      ctx.moveTo(x - lw / 2, y + lh / 2)
      ctx.lineTo(x + lw / 2, y + lh / 2)
      ctx.stroke()
      ctx.lineWidth = 1.5
      const rungs = 6
      for (let i = 1; i < rungs; i++) {
        const rx = x - lw / 2 + (lw / rungs) * i
        ctx.beginPath()
        ctx.moveTo(rx, y - lh / 2)
        ctx.lineTo(rx, y + lh / 2)
        ctx.stroke()
      }
      break
    }
    case 'pole': {
      const pw = s * 0.3, ph = s * 1.2
      ctx.fillStyle = '#94a3b8'
      ctx.beginPath()
      ctx.ellipse(x, y + ph / 2, s * 0.35, s * 0.1, 0, 0, Math.PI * 2)
      ctx.fill()
      const stripeH = ph / 5
      for (let i = 0; i < 5; i++) {
        ctx.fillStyle = i % 2 === 0 ? (c || '#ef4444') : '#fff'
        ctx.fillRect(x - pw / 2, y - ph / 2 + i * stripeH, pw, stripeH)
      }
      ctx.strokeStyle = 'rgba(0,0,0,0.2)'
      ctx.lineWidth = 0.5
      ctx.strokeRect(x - pw / 2, y - ph / 2, pw, ph)
      break
    }
    case 'rod': {
      const rw = s * 1.6, rh = s * 0.25
      ctx.fillStyle = c || '#eab308'
      ctx.beginPath()
      ctx.rect(x - rw / 2, y - rh / 2, rw, rh)
      ctx.fill()
      ctx.strokeStyle = 'rgba(0,0,0,0.2)'
      ctx.lineWidth = 1
      ctx.strokeRect(x - rw / 2, y - rh / 2, rw, rh)
      ctx.fillStyle = c || '#ca8a04'
      ctx.beginPath()
      ctx.arc(x - rw / 2, y, s * 0.2, 0, Math.PI * 2)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(x + rw / 2, y, s * 0.2, 0, Math.PI * 2)
      ctx.fill()
      break
    }
    case 'text': {
      ctx.font = `bold ${s * 0.6}px Inter,sans-serif`
      ctx.fillStyle = c || '#fff'
      ctx.textAlign = 'left'
      ctx.textBaseline = 'middle'
      ctx.fillText(el.text || 'Testo', x, y)
      break
    }
  }
  ctx.restore()
}

function drawArrow(el, selected) {
  const { x1, y1, x2, y2, type, color: c } = el
  ctx.save()
  ctx.strokeStyle = c || color.value
  ctx.lineWidth = el.w || strokeWidth.value
  ctx.lineCap = 'round'
  if (type === 'arrow-dash' || type === 'arrow-curve-dash') {
    ctx.setLineDash([8, 5])
  } else {
    ctx.setLineDash([])
  }
  if (selected) {
    ctx.shadowColor = '#fff'
    ctx.shadowBlur = 6
  }
  if (type === 'arrow-curve' || type === 'arrow-curve-dash') {
    const cx1 = x1 + (x2 - x1) * 0.2
    const cy1 = y1 - Math.abs(y2 - y1) * 0.7 - Math.abs(x2 - x1) * 0.3
    ctx.beginPath()
    ctx.moveTo(x1, y1)
    ctx.quadraticCurveTo(cx1, cy1, x2, y2)
    ctx.stroke()
    const dx = x2 - cx1, dy = y2 - cy1
    drawArrowhead(x2, y2, dx, dy, el.w || strokeWidth.value, c)
  } else if (type === 'one-two') {
    ctx.beginPath()
    ctx.moveTo(x1, y1)
    ctx.lineTo(x2, y2)
    ctx.stroke()
    const dx1 = x2 - x1, dy1 = y2 - y1
    drawArrowhead(x2, y2, dx1, dy1, el.w || strokeWidth.value, c)
    const dx2 = x1 - x2, dy2 = y1 - y2
    drawArrowhead(x1, y1, dx2, dy2, el.w || strokeWidth.value, c)
  } else {
    ctx.beginPath()
    ctx.moveTo(x1, y1)
    ctx.lineTo(x2, y2)
    ctx.stroke()
    const dx = x2 - x1, dy = y2 - y1
    drawArrowhead(x2, y2, dx, dy, el.w || strokeWidth.value, c)
  }
  if (selected) {
    const handleR = 6
    ctx.setLineDash([])
    ctx.shadowColor = 'transparent'
    ctx.shadowBlur = 0
    ctx.beginPath()
    ctx.arc(x2, y2, handleR, 0, Math.PI * 2)
    ctx.fillStyle = '#fff'
    ctx.fill()
    ctx.strokeStyle = c || color.value
    ctx.lineWidth = 2
    ctx.stroke()
    if (type === 'one-two') {
      ctx.beginPath()
      ctx.arc(x1, y1, handleR, 0, Math.PI * 2)
      ctx.fillStyle = '#fff'
      ctx.fill()
      ctx.strokeStyle = c || color.value
      ctx.lineWidth = 2
      ctx.stroke()
    }
  }
  ctx.restore()
}

function drawArrowhead(x, y, dx, dy, w, c) {
  const len = Math.sqrt(dx * dx + dy * dy)
  if (len < 1) return
  const nx = dx / len, ny = dy / len
  const size = 8 + w * 2.5
  ctx.save()
  ctx.setLineDash([])
  ctx.fillStyle = c || color.value
  ctx.beginPath()
  ctx.moveTo(x, y)
  ctx.lineTo(x - size * nx + size * 0.4 * (-ny), y - size * ny + size * 0.4 * nx)
  ctx.lineTo(x - size * nx - size * 0.4 * (-ny), y - size * ny - size * 0.4 * nx)
  ctx.closePath()
  ctx.fill()
  ctx.restore()
}

function drawZone(el, selected) {
  const { x1, y1, x2, y2, color: c } = el
  ctx.save()
  ctx.setLineDash([6, 4])
  ctx.strokeStyle = c || color.value
  ctx.lineWidth = 1.5
  const fc = c || color.value
  let rgba = 'rgba(59,130,246,0.18)'
  try {
    const r2 = parseInt(fc.slice(1, 3), 16)
    const g2 = parseInt(fc.slice(3, 5), 16)
    const b2 = parseInt(fc.slice(5, 7), 16)
    rgba = `rgba(${r2},${g2},${b2},0.18)`
  } catch (e) {}
  ctx.fillStyle = rgba
  const rx = Math.min(x1, x2), ry = Math.min(y1, y2)
  const rw = Math.abs(x2 - x1), rh = Math.abs(y2 - y1)
  ctx.fillRect(rx, ry, rw, rh)
  ctx.strokeRect(rx, ry, rw, rh)
  ctx.restore()
}

function getPos(e) {
  const r = canvasRef.value.getBoundingClientRect()
  const touch = e.touches ? e.touches[0] : e
  return {
    x: (touch.clientX - r.left) * (canvasW / r.width),
    y: (touch.clientY - r.top) * (canvasH / r.height)
  }
}

function hitTest(x, y, el, idx) {
  const thresh = Math.max(12, el.size || 20)
  if (el.type === 'free') {
    const pts = el.points
    if (!pts || pts.length < 2) return pts.some(p => Math.hypot(p.x - x, p.y - y) < 8) ? idx : false
    for (let s = 0; s < pts.length - 1; s++) {
      const dx = pts[s + 1].x - pts[s].x, dy = pts[s + 1].y - pts[s].y
      const len2 = dx * dx + dy * dy
      if (len2 < 1) {
        if (Math.hypot(pts[s].x - x, pts[s].y - y) < 8) return idx
        continue
      }
      const t = Math.max(0, Math.min(1, ((x - pts[s].x) * dx + (y - pts[s].y) * dy) / len2))
      const px = pts[s].x + t * dx - x, py = pts[s].y + t * dy - y
      if (Math.sqrt(px * px + py * py) < 10) return idx
    }
    return false
  }
  if (el.type === 'zone') {
    return x >= Math.min(el.x1, el.x2) && x <= Math.max(el.x1, el.x2) &&
      y >= Math.min(el.y1, el.y2) && y <= Math.max(el.y1, el.y2) ? idx : false
  }
  if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash', 'one-two'].includes(el.type)) {
    const dx = el.x2 - el.x1, dy = el.y2 - el.y1
    const len2 = dx * dx + dy * dy
    if (len2 < 1) return false
    if (el.type === 'one-two') {
      const onHandle2 = Math.hypot(el.x2 - x, el.y2 - y) < 8
      if (onHandle2) return { resize: true, idx, end: 'x2' }
      const onHandle1 = Math.hypot(el.x1 - x, el.y1 - y) < 8
      if (onHandle1) return { resize: true, idx, end: 'x1' }
    } else {
      const onHandle = Math.hypot(el.x2 - x, el.y2 - y) < 8
      if (onHandle) return { resize: true, idx }
    }
    const t2 = Math.max(0, Math.min(1, ((x - el.x1) * dx + (y - el.y1) * dy) / len2))
    const px = el.x1 + t2 * dx - x, py = el.y1 + t2 * dy - y
    const onLine = Math.sqrt(px * px + py * py) < 10
    if (onLine) return { move: true, idx }
    return false
  }
  if (el.type === 'goal' || el.type === 'goal-large' || el.type === 'goal-small') {
    const scale = el.type === 'goal-large' ? 1.8 : el.type === 'goal-small' ? 1.2 : 1
    const gw = (el.size || 28) * scale * 2.2
    const gh = (el.size || 28) * scale * 0.8
    return x >= el.x - gw / 2 - 5 && x <= el.x + gw / 2 + 5 &&
      y >= el.y - gh / 2 - 5 && y <= el.y + gh / 2 + 5 ? idx : false
  }
  if (['ladder', 'rod'].includes(el.type)) {
    const w = (el.size || 28) * 1.6
    const h = (el.size || 28) * 0.45
    return x >= el.x - w / 2 - 5 && x <= el.x + w / 2 + 5 &&
      y >= el.y - h / 2 - 5 && y <= el.y + h / 2 + 5 ? idx : false
  }
  if (el.type === 'pole') {
    const w = (el.size || 28) * 0.35
    const h = (el.size || 28) * 1.2
    return x >= el.x - w - 5 && x <= el.x + w + 5 &&
      y >= el.y - h / 2 - 5 && y <= el.y + h / 2 + 5 ? idx : false
  }
  if (el.type === 'text') {
    return x >= el.x - 4 && x <= el.x + 80 && y >= el.y - 12 && y <= el.y + 12 ? idx : false
  }
  return Math.hypot(el.x - x, el.y - y) < thresh ? idx : false
}

function pointerDown(e) {
  const pos = getPos(e)
  if (canvasRef.value) canvasRef.value.setPointerCapture(e.pointerId || 0)

  if (tool.value === 'select') {
    let found = -1
    let resizeIdx = -1
    let resizeEndLocal = 'x2'

    for (let i = elements.value.length - 1; i >= 0; i--) {
      const result = hitTest(pos.x, pos.y, elements.value[i], i)

      if (result !== false && result !== undefined && result !== null) {
        if (typeof result === 'object' && result.resize) {
          resizeIdx = result.idx
          resizeEndLocal = result.end || 'x2'
          break
        }

        if (typeof result === 'object' && result.move) {
          found = result.idx
          break
        }

        if (typeof result === 'number') {
          found = result
          break
        }
      }
    }

    selectedIdx.value = found >= 0 ? found : resizeIdx

    if (resizeIdx >= 0) {
      resizingArrow = resizeIdx
      const el = elements.value[resizeIdx]
      resizingEnd = resizeEndLocal

      if (el.type === 'one-two' && resizingEnd === 'x1') {
        dragOffset = { x: pos.x - el.x1, y: pos.y - el.y1 }
      } else {
        dragOffset = { x: pos.x - el.x2, y: pos.y - el.y2 }
      }

      dragStart = { ...pos }
    } else if (found >= 0) {
      dragging = true
      const el = elements.value[found]
      dragOffset = {
        x: pos.x - (el.x ?? el.x1 ?? 0),
        y: pos.y - (el.y ?? el.y1 ?? 0)
      }
      dragStart = { ...pos }
    }

    draw()
    return
  }

  if (tool.value === 'erase') {
    for (let i = elements.value.length - 1; i >= 0; i--) {
      if (elements.value[i].type === 'free' && hitTest(pos.x, pos.y, elements.value[i], i)) {
        elements.value.splice(i, 1)
        pushHistory()
        draw()
        return
      }
    }
    return
  }

  if (tool.value === 'pencil') {
    isDrawing = true
    freePoints = [pos]
    return
  }

  if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash', 'one-two', 'zone'].includes(tool.value)) {
    isDrawing = true
    drawStart = pos
    drawCurrent = pos
    return
  }

  if (tool.value === 'text') {
    const txt = prompt('Inserisci testo:')
    if (!txt) return
    elements.value.push({ type: 'text', x: pos.x, y: pos.y, color: color.value, size: elemSize.value, text: txt })
    pushHistory()
    draw()
    return
  }

  // Place object tools
  const newEl = { type: tool.value, x: pos.x, y: pos.y, color: color.value, size: elemSize.value }
  elements.value.push(newEl)
  selectedIdx.value = elements.value.length - 1
  pushHistory()
  draw()
}

function pointerMove(e) {
  const pos = getPos(e)

  if (tool.value === 'select' && dragging && selectedIdx.value >= 0) {
    const el = elements.value[selectedIdx.value]
    if (el.x !== undefined) {
      el.x = pos.x - dragOffset.x
      el.y = pos.y - dragOffset.y
    }
    if (el.x1 !== undefined) {
      if (resizingArrow === selectedIdx.value) {
        const ddx = pos.x - dragStart.x
        const ddy = pos.y - dragStart.y
        if (el.type === 'one-two') {
          if (resizingEnd === 'x1') {
            el.x1 += ddx
            el.y1 += ddy
          } else {
            el.x2 += ddx
            el.y2 += ddy
          }
        } else {
          el.x2 += ddx
          el.y2 += ddy
        }
        dragStart = { ...pos }
      } else {
        const ddx = pos.x - (dragStart?.x || pos.x)
        const ddy = pos.y - (dragStart?.y || pos.y)
        el.x1 += ddx; el.y1 += ddy
        el.x2 += ddx; el.y2 += ddy
      }
    }
    if (el.type === 'free' && el.points) {
      el.points = el.points.map(p => ({ x: p.x + (pos.x - (dragStart?.x || pos.x)), y: p.y + (pos.y - (dragStart?.y || pos.y)) }))
    }
    dragStart = { ...pos }
    draw()
    return
  }

  if (tool.value === 'erase' && e.buttons) {
    for (let i = elements.value.length - 1; i >= 0; i--) {
      if (elements.value[i].type === 'free' && hitTest(pos.x, pos.y, elements.value[i], i)) {
        elements.value.splice(i, 1)
        draw()
        return
      }
    }
  }

  if (tool.value === 'pencil' && isDrawing) {
    freePoints.push(pos)
    ctx.clearRect(0, 0, canvasW, canvasH)
    draw()
    ctx.save()
    ctx.strokeStyle = color.value
    ctx.lineWidth = strokeWidth.value
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.beginPath()
    ctx.moveTo(freePoints[0].x, freePoints[0].y)
    freePoints.forEach(p => ctx.lineTo(p.x, p.y))
    ctx.stroke()
    ctx.restore()
    return
  }

  if (isDrawing && drawStart) {
    drawCurrent = pos
    draw()
  }
}

function pointerUp(e) {
  const pos = getPos(e)

  if (dragging) {
    dragging = false
    resizingArrow = null
    resizingEnd = null
    pushHistory()
    syncToServer()
    return
  }

  if (tool.value === 'pencil' && isDrawing) {
    isDrawing = false
    if (freePoints.length > 1) {
      const cPoints = freePoints.map(p => ({ x: p.x, y: p.y }))
      elements.value.push({ type: 'free', points: cPoints, color: color.value, w: strokeWidth.value })
      pushHistory()
      draw()
      syncToServer()
    }
    freePoints = []
    return
  }

  if (isDrawing && drawStart && drawCurrent) {
    isDrawing = false
    const dx = drawCurrent.x - drawStart.x
    const dy = drawCurrent.y - drawStart.y
    if (Math.hypot(dx, dy) > 8) {
      elements.value.push({
        type: tool.value,
        x1: drawStart.x, y1: drawStart.y,
        x2: drawCurrent.x, y2: drawCurrent.y,
        color: color.value, w: strokeWidth.value
      })
      selectedIdx.value = elements.value.length - 1
      pushHistory()
      syncToServer()
    }
    drawStart = null
    drawCurrent = null
    draw()
  }
}

function pushHistory() {
  history.value = history.value.slice(0, histIdx.value + 1)
  history.value.push(JSON.parse(JSON.stringify(elements.value)))
  histIdx.value = history.value.length - 1
  if (!_syncDisabled) {
    syncToServer()
  }
}

function undo() {
  if (histIdx.value > 0) {
    histIdx.value--
    elements.value = JSON.parse(JSON.stringify(history.value[histIdx.value]))
    selectedIdx.value = -1
    draw()
    syncToServer()
  }
}

function redo() {
  if (histIdx.value < history.value.length - 1) {
    histIdx.value++
    elements.value = JSON.parse(JSON.stringify(history.value[histIdx.value]))
    selectedIdx.value = -1
    draw()
    syncToServer()
  }
}

function clearBoard() {
  if (confirm('Cancellare tutto il campo?')) {
    elements.value = []
    selectedIdx.value = -1
    pushHistory()
    syncToServer()
    draw()
  }
}

function deleteSelected() {
  if (selectedIdx.value >= 0) {
    elements.value.splice(selectedIdx.value, 1)
    selectedIdx.value = -1
    pushHistory()
    draw()
  }
}

function selectTool(t) {
  tool.value = t
  if (canvasRef.value) {
    canvasRef.value.style.cursor = t === 'select' ? 'default' : t === 'erase' ? 'cell' : 'crosshair'
  }
}

function selectColor(c) {
  color.value = c
  if (selectedIdx.value >= 0 && elements.value[selectedIdx.value]) {
    elements.value[selectedIdx.value].color = c
    pushHistory()
    draw()
  }
}

onMounted(() => {
  const canvas = canvasRef.value
  if (canvas) {
    canvas.addEventListener('pointerdown', pointerDown)
    canvas.addEventListener('pointermove', pointerMove)
    canvas.addEventListener('pointerup', pointerUp)
  }
  document.addEventListener('keydown', keyDown)
  window.addEventListener('resize', resizeCanvas)

  if (props.elements && props.elements.length > 0) {
    _pendingProps = props.elements
  }
  resizeCanvas()
})

onUnmounted(() => {
  if (canvasRef.value) {
    canvasRef.value.removeEventListener('pointerdown', pointerDown)
    canvasRef.value.removeEventListener('pointermove', pointerMove)
    canvasRef.value.removeEventListener('pointerup', pointerUp)
  }
  document.removeEventListener('keydown', keyDown)
  window.removeEventListener('resize', resizeCanvas)
})

function keyDown(e) {
  if (e.key === 'Delete' || e.key === 'Backspace') {
    if (selectedIdx.value >= 0 && document.activeElement === document.body) {
      elements.value.splice(selectedIdx.value, 1)
      selectedIdx.value = -1
      pushHistory()
      draw()
    }
  }
  if ((e.ctrlKey || e.metaKey) && e.key === 'z') { e.preventDefault(); undo() }
  if ((e.ctrlKey || e.metaKey) && e.key === 'y') { e.preventDefault(); redo() }
  if (e.key === 'Escape') { selectedIdx.value = -1; draw() }
}
</script>

<style scoped>
.tactical-board {
  display: flex;
  flex-direction: column;
  height: 100%;
  width: 100%;
  background: #0f1117;
  border-radius: 12px;
  overflow: hidden;
}

.tb-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: #181b24;
  border-bottom: 1px solid rgba(255,255,255,0.08);
  flex-shrink: 0;
}

.tb-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 7px;
  background: #252836;
  border: 1px solid rgba(255,255,255,0.08);
  color: #e8eaf0;
  font-size: 13px;
  cursor: pointer;
  transition: background 0.15s;
}

.tb-btn:hover:not(:disabled) { background: #2e3247 }
.tb-btn:disabled { opacity: 0.4; cursor: not-allowed }
.tb-btn.tb-danger { background: rgba(239,68,68,0.1); border-color: rgba(239,68,68,0.3); color: #ef4444 }
.tb-btn.tb-danger:hover { background: rgba(239,68,68,0.2) }
.tb-btn.tb-primary { background: #3b82f6; border-color: transparent; color: #fff }
.tb-btn.tb-primary:hover { background: #2563eb }

.tb-delete-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  width: 100%;
  padding: 8px 12px;
  border-radius: 6px;
  background: rgba(239,68,68,0.1);
  border: 1px solid rgba(239,68,68,0.3);
  color: #ef4444;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.15s;
}
.tb-delete-btn:hover { background: rgba(239,68,68,0.2) }

.tb-main {
  display: flex;
  flex: 1;
  overflow: hidden;
  min-height: 0;
}

.tb-sidebar {
  width: 72px;
  background: #181b24;
  border-right: 1px solid rgba(255,255,255,0.08);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 10px 0;
  gap: 4px;
  flex-shrink: 0;
  overflow-y: auto;
}

.tb-section {
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: 4px 0;
}

.tb-label {
  font-size: 9px;
  color: #8b909e;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 2px;
}

.tb-divider {
  width: 40px;
  height: 1px;
  background: rgba(255,255,255,0.08);
  margin: 6px 0;
}

.tb-tool {
  width: 52px;
  height: 52px;
  border-radius: 10px;
  background: #252836;
  border: 1.5px solid transparent;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  cursor: pointer;
  transition: all 0.15s;
}

.tb-tool:hover { background: #2e3247 }
.tb-tool.active { background: #3b4263; border-color: #3b82f6 }

.tb-canvas-wrap {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #0f1117;
  padding: 16px;
  overflow: hidden;
  position: relative;
  min-width: 0;
}

.tb-canvas-wrap canvas {
  border-radius: 12px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.04);
  cursor: crosshair;
  display: block;
  max-width: 100%;
  max-height: 100%;
}

.tb-right {
  width: 200px;
  background: #181b24;
  border-left: 1px solid rgba(255,255,255,0.08);
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  overflow-y: auto;
}

.tb-panel {
  padding: 12px;
  border-bottom: 1px solid rgba(255,255,255,0.08);
}

.tb-panel-title {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  color: #8b909e;
  margin-bottom: 10px;
}

.tb-color-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 5px;
}

.tb-swatch {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  cursor: pointer;
  border: 2px solid transparent;
  transition: transform 0.1s, border-color 0.1s;
}

.tb-swatch:hover { transform: scale(1.1) }
.tb-swatch.active { border-color: #fff }

.tb-size-row {
  display: flex;
  gap: 6px;
  align-items: center;
  margin-bottom: 8px;
}

.tb-size-row label {
  font-size: 11px;
  color: #8b909e;
  width: 70px;
}

.tb-size-row input[type=range] {
  flex: 1;
  accent-color: #3b82f6;
  height: 4px;
}

.tb-mode-row {
  display: flex;
  gap: 4px;
  flex-wrap: wrap;
}

.tb-chip {
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 11px;
  font-weight: 500;
  cursor: pointer;
  background: #252836;
  border: 1px solid rgba(255,255,255,0.08);
  color: #8b909e;
  transition: all 0.1s;
}

.tb-chip:hover { background: #2e3247; color: #e8eaf0 }
.tb-chip.active { background: #3b82f6; border-color: transparent; color: #fff }
</style>
