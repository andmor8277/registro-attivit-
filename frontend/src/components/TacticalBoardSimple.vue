<template>
  <div class="tactical-board-simple">
    <div class="tb-header">
      <button class="tb-btn" @click="undo" :disabled="elements.length === 0" title="Annulla">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 10h11a7 7 0 0 1 0 14H3"/><polyline points="3,3 3,10 10,10"/>
        </svg>
      </button>
      <button class="tb-btn" @click="clearBoard" title="Pulisci">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/>
        </svg>
      </button>
    </div>

    <div class="tb-canvas-wrap" ref="canvasWrapRef">
      <canvas ref="canvasRef"></canvas>
    </div>

    <div class="tb-colors">
      <div v-for="c in colors" :key="c" 
           class="tb-color-swatch" 
           :class="{ active: color === c }" 
           :style="{ background: c }" 
           @click="color = c">
      </div>
    </div>

    <div class="tb-field-toggle">
      <button v-for="mode in fieldModes" :key="mode.value"
              class="tb-field-chip"
              :class="{ active: fieldMode === mode.value }"
              @click="fieldMode = mode.value; resizeCanvas()">
        {{ mode.label }}
      </button>
    </div>

    <div class="tb-toolbar">
      <button v-for="tool in tools" :key="tool.type"
              class="tb-tool-btn"
              :class="{ active: currentTool === tool.type }"
              @click="currentTool = tool.type">
        <svg width="24" height="24" viewBox="0 0 24 24" :fill="tool.fill || 'none'" :stroke="tool.stroke || 'currentColor'" stroke-width="2">
          <component :is="tool.svg" />
        </svg>
        <span>{{ tool.label }}</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'

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
let fieldX = 0
let fieldY = 0
let fieldW = 0
let fieldH = 0

const currentTool = ref('player')
const color = ref('#3b82f6')
const fieldMode = ref(props.fieldMode)
const elements = ref([])

const colors = ['#3b82f6', '#ef4444', '#22c55e', '#f59e0b', '#ffffff']

const fieldModes = [
  { value: 'full', label: 'Intero' },
  { value: 'half', label: 'Metà' },
  { value: 'blank', label: 'Vuoto' }
]

const tools = [
  { 
    type: 'player', 
    label: 'Giocatore', 
    fill: '#3b82f6',
    svg: () => h('g', [
      h('circle', { cx: 12, cy: 8, r: 4 }),
      h('path', { d: 'M4 20c0-4 3.6-7 8-7s8 3 8 7' })
    ])
  },
  { 
    type: 'arrow', 
    label: 'Passaggio', 
    svg: () => h('g', [
      h('line', { x1: 4, y1: 12, x2: 20, y2: 12 }),
      h('polyline', { points: '14,6 20,12 14,18' })
    ])
  },
  { 
    type: 'arrow-dash', 
    label: 'Movimento', 
    svg: () => h('g', [
      h('line', { x1: 4, y1: 12, x2: 17, y2: 12, 'stroke-dasharray': '4 2' }),
      h('polyline', { points: '13,7 19,12 13,17' })
    ])
  },
  { 
    type: 'cone', 
    label: 'Cono', 
    fill: '#f97316',
    svg: () => h('polygon', { points: '12,3 20,21 4,21' })
  },
  { 
    type: 'disc', 
    label: 'Cinesino', 
    fill: '#a78bfa',
    svg: () => h('ellipse', { cx: 12, cy: 19, rx: 8, ry: 3 })
  },
  { 
    type: 'goal', 
    label: 'Porta', 
    svg: () => h('rect', { x: 2, y: 6, width: 20, height: 12, rx: 1 })
  },
  { 
    type: 'pencil', 
    label: 'Matita', 
    svg: () => h('g', [
      h('path', { d: 'M12 20h9' }),
      h('path', { d: 'M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z' })
    ])
  },
  { 
    type: 'erase', 
    label: 'Gomma', 
    svg: () => h('g', [
      h('path', { d: 'M20 20H7L3 16l10-10 7 7-3.5 3.5' }),
      h('path', { d: 'M6.5 17.5l5-5' })
    ])
  }
]

let isDrawing = false
let drawStart = null
let drawCurrent = null

function resizeCanvas() {
  if (!canvasRef.value || !canvasWrapRef.value) return
  
  const rect = canvasWrapRef.value.getBoundingClientRect()
  canvasW = rect.width
  canvasH = rect.height
  
  canvasRef.value.width = canvasW * window.devicePixelRatio
  canvasRef.value.height = canvasH * window.devicePixelRatio
  canvasRef.value.style.width = canvasW + 'px'
  canvasRef.value.style.height = canvasH + 'px'
  
  ctx = canvasRef.value.getContext('2d')
  ctx.scale(window.devicePixelRatio, window.devicePixelRatio)
  
  fieldX = 20
  fieldY = 20
  fieldW = canvasW - 40
  fieldH = canvasH - 40
  
  draw()
}

function drawField() {
  if (fieldMode.value === 'blank') return
  
  ctx.strokeStyle = 'rgba(255,255,255,0.6)'
  ctx.lineWidth = 2
  
  ctx.strokeRect(fieldX, fieldY, fieldW, fieldH)
  
  if (fieldMode.value === 'full') {
    ctx.beginPath()
    ctx.moveTo(fieldX, fieldY + fieldH / 2)
    ctx.lineTo(fieldX + fieldW, fieldY + fieldH / 2)
    ctx.stroke()
    
    ctx.beginPath()
    ctx.arc(fieldX + fieldW / 2, fieldY + fieldH / 2, 30, 0, Math.PI * 2)
    ctx.stroke()
    
    ctx.strokeRect(fieldX, fieldY + fieldH * 0.3, fieldW * 0.15, fieldH * 0.4)
    ctx.strokeRect(fieldX + fieldW * 0.85, fieldY + fieldH * 0.3, fieldW * 0.15, fieldH * 0.4)
  }
}

function drawElement(el) {
  ctx.save()
  ctx.strokeStyle = el.color
  ctx.fillStyle = el.color
  ctx.lineWidth = 2
  
  switch(el.type) {
    case 'player':
      ctx.beginPath()
      ctx.arc(el.x, el.y, 12, 0, Math.PI * 2)
      ctx.fill()
      ctx.fillStyle = '#fff'
      ctx.font = 'bold 10px Arial'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(el.number || '1', el.x, el.y)
      break
      
    case 'arrow':
    case 'arrow-dash':
      const angle = Math.atan2(el.y2 - el.y1, el.x2 - el.x1)
      ctx.setLineDash(el.type === 'arrow-dash' ? [5, 5] : [])
      ctx.beginPath()
      ctx.moveTo(el.x1, el.y1)
      ctx.lineTo(el.x2, el.y2)
      ctx.stroke()
      ctx.setLineDash([])
      const arrowLen = 10
      ctx.beginPath()
      ctx.moveTo(el.x2, el.y2)
      ctx.lineTo(el.x2 - arrowLen * Math.cos(angle - Math.PI / 6), el.y2 - arrowLen * Math.sin(angle - Math.PI / 6))
      ctx.lineTo(el.x2 - arrowLen * Math.cos(angle + Math.PI / 6), el.y2 - arrowLen * Math.sin(angle + Math.PI / 6))
      ctx.closePath()
      ctx.fill()
      break
      
    case 'cone':
      ctx.beginPath()
      ctx.moveTo(el.x, el.y - 10)
      ctx.lineTo(el.x + 8, el.y + 10)
      ctx.lineTo(el.x - 8, el.y + 10)
      ctx.closePath()
      ctx.fill()
      break
      
    case 'disc':
      ctx.beginPath()
      ctx.ellipse(el.x, el.y, 12, 5, 0, 0, Math.PI * 2)
      ctx.fill()
      break
      
    case 'goal':
      ctx.strokeRect(el.x - 15, el.y - 8, 30, 16)
      break
      
    case 'pencil':
      ctx.beginPath()
      ctx.moveTo(el.points[0].x, el.points[0].y)
      for (let i = 1; i < el.points.length; i++) {
        ctx.lineTo(el.points[i].x, el.points[i].y)
      }
      ctx.stroke()
      break
  }
  
  ctx.restore()
}

function draw() {
  ctx.clearRect(0, 0, canvasW, canvasH)
  drawField()
  elements.value.forEach(drawElement)
}

function getPos(e) {
  const rect = canvasRef.value.getBoundingClientRect()
  const x = (e.touches ? e.touches[0].clientX : e.clientX) - rect.left
  const y = (e.touches ? e.touches[0].clientY : e.clientY) - rect.top
  return { x, y }
}

function handleStart(e) {
  e.preventDefault()
  const pos = getPos(e)
  isDrawing = true
  drawStart = pos
  drawCurrent = pos
  
  if (currentTool.value === 'player') {
    elements.value.push({
      type: 'player',
      x: pos.x,
      y: pos.y,
      color: color.value,
      number: elements.value.filter(el => el.type === 'player').length + 1
    })
    draw()
    isDrawing = false
  }
}

function handleMove(e) {
  e.preventDefault()
  if (!isDrawing) return
  drawCurrent = getPos(e)
  
  if (currentTool.value === 'pencil') {
    if (elements.value.length === 0 || elements.value[elements.value.length - 1].type !== 'pencil') {
      elements.value.push({ type: 'pencil', points: [{ x: drawStart.x, y: drawStart.y }], color: color.value })
    }
    elements.value[elements.value.length - 1].points.push(drawCurrent)
  } else if (currentTool.value === 'arrow' || currentTool.value === 'arrow-dash') {
    draw()
    ctx.save()
    ctx.strokeStyle = color.value
    ctx.lineWidth = 2
    ctx.setLineDash(currentTool.value === 'arrow-dash' ? [5, 5] : [])
    ctx.beginPath()
    ctx.moveTo(drawStart.x, drawStart.y)
    ctx.lineTo(drawCurrent.x, drawCurrent.y)
    ctx.stroke()
    ctx.restore()
  }
}

function handleEnd(e) {
  e.preventDefault()
  if (!isDrawing) return
  isDrawing = false
  
  if (currentTool.value === 'arrow' || currentTool.value === 'arrow-dash') {
    const dist = Math.sqrt(Math.pow(drawCurrent.x - drawStart.x, 2) + Math.pow(drawCurrent.y - drawStart.y, 2))
    if (dist > 20) {
      elements.value.push({
        type: currentTool.value,
        x1: drawStart.x,
        y1: drawStart.y,
        x2: drawCurrent.x,
        y2: drawCurrent.y,
        color: color.value
      })
    }
  }
  draw()
}

function undo() {
  if (elements.value.length > 0) {
    elements.value.pop()
    draw()
  }
}

function clearBoard() {
  if (confirm('Cancellare tutto?')) {
    elements.value = []
    draw()
  }
}

onMounted(() => {
  resizeCanvas()
  window.addEventListener('resize', resizeCanvas)
})

onUnmounted(() => {
  window.removeEventListener('resize', resizeCanvas)
})

watch(fieldMode, () => resizeCanvas())
</script>

<style scoped>
.tactical-board-simple {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #1a1a1a;
}

.tb-header {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  padding: 12px 16px;
  background: #2d2d2d;
  border-bottom: 1px solid #404040;
}

.tb-btn {
  width: 40px;
  height: 40px;
  border: none;
  background: #404040;
  color: #fff;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
}

.tb-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.tb-btn:active {
  background: #525252;
}

.tb-canvas-wrap {
  flex: 1;
  position: relative;
  overflow: hidden;
  background: #2d5a2d;
}

.tb-canvas-wrap canvas {
  position: absolute;
  top: 0;
  left: 0;
}

.tb-colors {
  display: flex;
  gap: 8px;
  padding: 8px 16px;
  background: #2d2d2d;
  border-top: 1px solid #404040;
}

.tb-color-swatch {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: 3px solid transparent;
  cursor: pointer;
}

.tb-color-swatch.active {
  border-color: #fff;
  transform: scale(1.1);
}

.tb-field-toggle {
  display: flex;
  gap: 8px;
  padding: 8px 16px;
  background: #2d2d2d;
  border-top: 1px solid #404040;
}

.tb-field-chip {
  padding: 6px 12px;
  background: #404040;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  color: #fff;
  border: none;
}

.tb-field-chip.active {
  background: #3b82f6;
}

.tb-toolbar {
  display: flex;
  gap: 8px;
  padding: 12px 16px;
  background: #2d2d2d;
  border-top: 1px solid #404040;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.tb-tool-btn {
  min-width: 56px;
  height: 56px;
  border: 2px solid transparent;
  background: #404040;
  color: #fff;
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  cursor: pointer;
  font-size: 11px;
  font-weight: 500;
}

.tb-tool-btn.active {
  border-color: #3b82f6;
  background: #1e40af;
}

.tb-tool-btn:active {
  transform: scale(0.95);
}
</style>