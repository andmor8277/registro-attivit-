import { ref, onMounted, onUnmounted, nextTick } from 'vue'

export function useTacticalBoard(canvasRef, elements, onSave) {
  const canvas = ref(null)
  const ctx = ref(null)
  const tool = ref('select')
  const color = ref('#3b82f6')
  const strokeW = ref(2)
  const elemSize = ref(28)
  const fieldMode = ref('full')
  const selectedIdx = ref(-1)
  const tooltip = ref(null)
  let isDrawing = false
  let drawStart = null
  let drawCurrent = null
  let freePoints = []
  let dragging = false
  let dragOffset = { x: 0, y: 0 }
  let dragStart = null
  let history = [[]]
  let histIdx = 0

  function resize() {
    if (!canvas.value) return
    const wrap = canvas.value.parentElement
    const ww = wrap.clientWidth - 32
    const wh = wrap.clientHeight - 32
    const ratio = fieldMode.value === 'half' ? 105 / 2 / 68 : 105 / 68
    let cw, ch
    if (ww / wh > ratio) {
      ch = wh
      cw = ch * ratio
    } else {
      cw = ww
      ch = cw / ratio
    }
    canvas.value.width = Math.floor(cw)
    canvas.value.height = Math.floor(ch)
    draw()
  }

  function drawField() {
    const W = canvas.value.width
    const H = canvas.value.height
    if (W <= 0 || H <= 0) return
    const ctx2 = canvas.value.getContext('2d')
    const isHalf = fieldMode.value === 'half'
    const isBlank = fieldMode.value === 'blank'

    if (isBlank) {
      ctx2.fillStyle = '#1a2535'
      ctx2.fillRect(0, 0, W, H)
      return
    }

    const stripeCount = isHalf ? 6 : 11
    const sw = W / stripeCount
    for (let i = 0; i < stripeCount; i++) {
      ctx2.fillStyle = i % 2 === 0 ? '#2d5a1b' : '#346b20'
      ctx2.fillRect(i * sw, 0, sw, H)
    }

    const pad = H * 0.05
    const fw = W - pad * 2
    const fh = H - pad * 2
    const fx = pad
    const fy = pad

    ctx2.strokeStyle = 'rgba(255,255,255,0.88)'
    ctx2.lineWidth = Math.max(1, H * 0.004)
    ctx2.lineCap = 'round'

    ctx2.strokeRect(fx, fy, fw, fh)

    if (!isHalf) {
      ctx2.beginPath()
      ctx2.moveTo(fx + fw / 2, fy)
      ctx2.lineTo(fx + fw / 2, fy + fh)
      ctx2.stroke()
      ctx2.beginPath()
      ctx2.arc(fx + fw / 2, fy + fh / 2, fh * 0.146, 0, Math.PI * 2)
      ctx2.stroke()
      ctx2.beginPath()
      ctx2.arc(fx + fw / 2, fy + fh / 2, H * 0.007, 0, Math.PI * 2)
      ctx2.fillStyle = 'rgba(255,255,255,0.88)'
      ctx2.fill()
    }

    const paH = fh * 0.384
    const paW = fw * 0.157
    const paY = fy + (fh - paH) / 2
    const gaH = fh * 0.27
    const gaW = fw * 0.052
    const gaY = fy + (fh - gaH) / 2

    ctx2.strokeRect(fx, paY, paW, paH)
    ctx2.strokeRect(fx, gaY, gaW, gaH)
    ctx2.beginPath()
    ctx2.arc(fx + fw * 0.105, fy + fh / 2, H * 0.006, 0, Math.PI * 2)
    ctx2.fill()
    ctx2.beginPath()
    ctx2.arc(fx + fw * 0.105, fy + fh / 2, fh * 0.146, -0.93, 0.93)
    ctx2.stroke()

    if (!isHalf) {
      ctx2.strokeRect(fx + fw - paW, paY, paW, paH)
      ctx2.strokeRect(fx + fw - gaW, gaY, gaW, gaH)
      ctx2.beginPath()
      ctx2.arc(fx + fw * 0.895, fy + fh / 2, H * 0.006, 0, Math.PI * 2)
      ctx2.fill()
      ctx2.beginPath()
      ctx2.arc(fx + fw * 0.895, fy + fh / 2, fh * 0.146, Math.PI - 0.93, Math.PI + 0.93)
      ctx2.stroke()
    }

    const cr = fh * 0.018
    ctx2.strokeStyle = 'rgba(255,255,255,0.88)'
    [[fx, fy, 0, Math.PI / 2],
      [fx + fw, fy, Math.PI / 2, Math.PI],
      [fx, fy + fh, 3 * Math.PI / 2, 2 * Math.PI],
      [fx + fw, fy + fh, Math.PI, 3 * Math.PI / 2]].forEach(([x, y, s, e]) => {
        ctx2.beginPath()
        ctx2.arc(x, y, cr, s, e)
        ctx2.stroke()
      })

    const gH = fh * 0.11
    const gW = fw * 0.024
    const gY = fy + (fh - gH) / 2
    ctx2.strokeStyle = 'rgba(255,255,255,0.7)'
    ctx2.lineWidth = 2
    ctx2.strokeRect(fx - gW, gY, gW, gH)
    if (!isHalf) {
      ctx2.strokeRect(fx + fw, gY, gW, gH)
    }
  }

  function drawElement(el, selected) {
    const { type, x, y, color: c, size: s } = el
    const ctx2 = canvas.value.getContext('2d')
    ctx2.save()

    if (selected) {
      ctx2.shadowColor = '#fff'
      ctx2.shadowBlur = 8
    }

    switch (type) {
      case 'player-home':
      case 'player-away':
      case 'player-gk': {
        const cols = { 'player-home': '#3b82f6', 'player-away': '#ef4444', 'player-gk': '#f59e0b' }
        const pc = c || cols[type]
        const r = s / 2
        ctx2.beginPath()
        ctx2.ellipse(x, y + r * 0.9, r * 0.6, r * 0.18, 0, 0, Math.PI * 2)
        ctx2.fillStyle = 'rgba(0,0,0,0.3)'
        ctx2.fill()
        ctx2.beginPath()
        ctx2.arc(x, y, r, 0, Math.PI * 2)
        ctx2.fillStyle = pc
        ctx2.fill()
        ctx2.strokeStyle = 'rgba(255,255,255,0.6)'
        ctx2.lineWidth = 1.5
        ctx2.stroke()
        if (el.num) {
          ctx2.fillStyle = '#fff'
          ctx2.font = `bold ${r * 0.9}px Inter,sans-serif`
          ctx2.textAlign = 'center'
          ctx2.textBaseline = 'middle'
          ctx2.fillText(el.num, x, y)
        }
        break
      }
      case 'ball': {
        const r = s / 2.2
        ctx2.beginPath()
        ctx2.arc(x, y, r, 0, Math.PI * 2)
        ctx2.fillStyle = '#fff'
        ctx2.fill()
        ctx2.strokeStyle = '#333'
        ctx2.lineWidth = 1
        ctx2.stroke()
        ctx2.fillStyle = '#222'
        ctx2.beginPath()
        ctx2.arc(x, y, r * 0.3, 0, Math.PI * 2)
        ctx2.fill()
        ctx2.strokeStyle = '#555'
        ctx2.lineWidth = 0.8
        for (let i = 0; i < 5; i++) {
          const a = (i / 5) * Math.PI * 2
          ctx2.beginPath()
          ctx2.moveTo(x, y)
          ctx2.lineTo(x + Math.cos(a) * r * 0.9, y + Math.sin(a) * r * 0.9)
          ctx2.stroke()
        }
        ctx2.strokeStyle = '#333'
        ctx2.lineWidth = 1
        ctx2.beginPath()
        ctx2.arc(x, y, r, 0, Math.PI * 2)
        ctx2.stroke()
        break
      }
      case 'cone': {
        const h = s * 1.1
        const bw = s * 0.7
        ctx2.beginPath()
        ctx2.moveTo(x, y - h / 2)
        ctx2.lineTo(x - bw / 2, y + h / 2)
        ctx2.lineTo(x + bw / 2, y + h / 2)
        ctx2.closePath()
        ctx2.fillStyle = c || '#f97316'
        ctx2.fill()
        ctx2.strokeStyle = 'rgba(255,255,255,0.3)'
        ctx2.lineWidth = 1
        ctx2.stroke()
        ctx2.strokeStyle = 'rgba(255,255,255,0.5)'
        ctx2.lineWidth = 1.5
        ctx2.beginPath()
        ctx2.moveTo(x - bw * 0.25, y + h * 0.15)
        ctx2.lineTo(x + bw * 0.25, y + h * 0.15)
        ctx2.stroke()
        break
      }
      case 'disc': {
        ctx2.beginPath()
        ctx2.ellipse(x, y, s / 2, s / 5, 0, 0, Math.PI * 2)
        ctx2.fillStyle = c || '#a78bfa'
        ctx2.fill()
        ctx2.strokeStyle = 'rgba(255,255,255,0.3)'
        ctx2.lineWidth = 1
        ctx2.stroke()
        break
      }
      case 'goal': {
        const gw = s * 2.2
        const gh = s * 0.8
        ctx2.strokeStyle = '#fff'
        ctx2.lineWidth = 3
        ctx2.lineJoin = 'round'
        ctx2.strokeRect(x - gw / 2, y - gh / 2, gw, gh)
        ctx2.strokeStyle = 'rgba(255,255,255,0.3)'
        ctx2.lineWidth = 0.8
        for (let i = 1; i < 4; i++) {
          ctx2.beginPath()
          ctx2.moveTo(x - gw / 2 + (gw / 4) * i, y - gh / 2)
          ctx2.lineTo(x - gw / 2 + (gw / 4) * i, y + gh / 2)
          ctx2.stroke()
        }
        ctx2.beginPath()
        ctx2.moveTo(x - gw / 2, y)
        ctx2.lineTo(x + gw / 2, y)
        ctx2.stroke()
        break
      }
      case 'mannequin': {
        const r = s / 4
        ctx2.strokeStyle = c || '#e2e8f0'
        ctx2.lineWidth = 2
        ctx2.fillStyle = c || '#e2e8f0'
        ctx2.beginPath()
        ctx2.arc(x, y - s * 0.4, r, 0, Math.PI * 2)
        ctx2.fill()
        ctx2.beginPath()
        ctx2.moveTo(x, y - s * 0.28)
        ctx2.lineTo(x, y + s * 0.1)
        ctx2.stroke()
        ctx2.beginPath()
        ctx2.moveTo(x - s * 0.28, y - s * 0.1)
        ctx2.lineTo(x + s * 0.28, y - s * 0.1)
        ctx2.stroke()
        ctx2.beginPath()
        ctx2.moveTo(x, y + s * 0.1)
        ctx2.lineTo(x - s * 0.2, y + s * 0.45)
        ctx2.moveTo(x, y + s * 0.1)
        ctx2.lineTo(x + s * 0.2, y + s * 0.45)
        ctx2.stroke()
        break
      }
      case 'text': {
        ctx2.font = `bold ${s * 0.6}px Inter,sans-serif`
        ctx2.fillStyle = c || '#fff'
        ctx2.textAlign = 'left'
        ctx2.textBaseline = 'middle'
        ctx2.fillText(el.text || 'Testo', x, y)
        break
      }
    }

    ctx2.restore()
  }

  function drawArrow(el, selected) {
    const { x1, y1, x2, y2, type, color: c } = el
    const ctx2 = canvas.value.getContext('2d')
    ctx2.save()
    ctx2.strokeStyle = c || color.value
    ctx2.lineWidth = el.w || strokeW.value
    ctx2.lineCap = 'round'

    if (type === 'arrow-dash' || type === 'arrow-curve-dash') {
      ctx2.setLineDash([8, 5])
    } else {
      ctx2.setLineDash([])
    }

    if (selected) {
      ctx2.shadowColor = '#fff'
      ctx2.shadowBlur = 6
    }

    if (type === 'arrow-curve' || type === 'arrow-curve-dash') {
      const cx1 = x1 + (x2 - x1) * 0.2
      const cy1 = y1 - Math.abs(y2 - y1) * 0.7 - Math.abs(x2 - x1) * 0.3
      ctx2.beginPath()
      ctx2.moveTo(x1, y1)
      ctx2.quadraticCurveTo(cx1, cy1, x2, y2)
      ctx2.stroke()
      const dx = x2 - cx1
      const dy = y2 - cy1
      drawArrowhead(ctx2, x2, y2, dx, dy, el.w || strokeW.value, c)
    } else {
      ctx2.beginPath()
      ctx2.moveTo(x1, y1)
      ctx2.lineTo(x2, y2)
      ctx2.stroke()
      const dx = x2 - x1
      const dy = y2 - y1
      drawArrowhead(ctx2, x2, y2, dx, dy, el.w || strokeW.value, c)
    }
    ctx2.restore()
  }

  function drawArrowhead(ctx2, x, y, dx, dy, w, c) {
    const len = Math.sqrt(dx * dx + dy * dy)
    if (len < 1) return
    const nx = dx / len
    const ny = dy / len
    const size = 8 + w * 2.5
    ctx2.save()
    ctx2.setLineDash([])
    ctx2.fillStyle = c || color.value
    ctx2.beginPath()
    ctx2.moveTo(x, y)
    ctx2.lineTo(x - size * nx + size * 0.4 * (-ny), y - size * ny + size * 0.4 * nx)
    ctx2.lineTo(x - size * nx - size * 0.4 * (-ny), y - size * ny - size * 0.4 * nx)
    ctx2.closePath()
    ctx2.fill()
    ctx2.restore()
  }

  function drawZone(el, selected) {
    const { x1, y1, x2, y2, color: c } = el
    const ctx2 = canvas.value.getContext('2d')
    ctx2.save()
    ctx2.setLineDash([6, 4])
    ctx2.strokeStyle = c || color.value
    ctx2.lineWidth = 1.5
    const fc = c || color.value
    try {
      const r = parseInt(fc.slice(1, 3), 16)
      const g = parseInt(fc.slice(3, 5), 16)
      const b = parseInt(fc.slice(5, 7), 16)
      ctx2.fillStyle = `rgba(${r},${g},${b},0.18)`
    } catch (e) { }
    const rx = Math.min(x1, x2)
    const ry = Math.min(y1, y2)
    const rw = Math.abs(x2 - x1)
    const rh = Math.abs(y2 - y1)
    ctx2.fillRect(rx, ry, rw, rh)
    ctx2.strokeRect(rx, ry, rw, rh)
    if (selected) {
      ctx2.setLineDash([])
      ctx2.strokeStyle = '#fff'
      ctx2.lineWidth = 1
      ctx2.strokeRect(rx - 1, ry - 1, rw + 2, rh + 2)
    }
    ctx2.restore()
  }

  function drawFree(el, selected) {
    if (!el.points || el.points.length < 2) return
    const ctx2 = canvas.value.getContext('2d')
    ctx2.save()
    ctx2.strokeStyle = el.color || color.value
    ctx2.lineWidth = el.w || strokeW.value
    ctx2.lineCap = 'round'
    ctx2.lineJoin = 'round'
    if (selected) { ctx2.shadowColor = '#fff'; ctx2.shadowBlur = 5 }
    ctx2.beginPath()
    ctx2.moveTo(el.points[0].x, el.points[0].y)
    for (let i = 1; i < el.points.length; i++) {
      ctx2.lineTo(el.points[i].x, el.points[i].y)
    }
    ctx2.stroke()
    ctx2.restore()
  }

  function draw() {
    const ctx2 = canvas.value.getContext('2d')
    ctx2.clearRect(0, 0, canvas.value.width, canvas.value.height)
    drawField()

    elements.value.forEach((el, i) => {
      const sel = i === selectedIdx.value
      if (el.type === 'free') drawFree(el, sel)
      else if (el.type === 'zone') drawZone(el, sel)
      else if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash'].includes(el.type)) drawArrow(el, sel)
      else drawElement(el, sel)
    })

    if (isDrawing && drawStart && drawCurrent) {
      const t = tool.value
      if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash'].includes(t)) {
        drawArrow({ x1: drawStart.x, y1: drawStart.y, x2: drawCurrent.x, y2: drawCurrent.y, type: t, color: color.value, w: strokeW.value }, false)
      } else if (t === 'zone') {
        drawZone({ x1: drawStart.x, y1: drawStart.y, x2: drawCurrent.x, y2: drawCurrent.y, color: color.value }, false)
      }
    }
  }

  function hitTest(x, y, el) {
    const thresh = Math.max(12, el.size || 20)
    if (el.type === 'free') {
      return el.points.some(p => Math.hypot(p.x - x, p.y - y) < 8)
    }
    if (el.type === 'zone') {
      return x >= Math.min(el.x1, el.x2) && x <= Math.max(el.x1, el.x2) &&
        y >= Math.min(el.y1, el.y2) && y <= Math.max(el.y1, el.y2)
    }
    if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash'].includes(el.type)) {
      const dx = el.x2 - el.x1
      const dy = el.y2 - el.y1
      const len2 = dx * dx + dy * dy
      if (len2 < 1) return false
      const t2 = Math.max(0, Math.min(1, ((x - el.x1) * dx + (y - el.y1) * dy) / len2))
      const px = el.x1 + t2 * dx - x
      const py = el.y1 + t2 * dy - y
      return Math.sqrt(px * px + py * py) < 10
    }
    if (el.type === 'goal') {
      const gw = (el.size || 28) * 2.2
      const gh = (el.size || 28) * 0.8
      return x >= el.x - gw / 2 - 5 && x <= el.x + gw / 2 + 5 &&
        y >= el.y - gh / 2 - 5 && y <= el.y + gh / 2 + 5
    }
    if (el.type === 'text') {
      return x >= el.x - 4 && x <= el.x + 80 && y >= el.y - 12 && y <= el.y + 12
    }
    return Math.hypot(el.x - x, el.y - y) < thresh
  }

  function getPos(e) {
    const r = canvas.value.getBoundingClientRect()
    const touch = e.touches ? e.touches[0] : e
    return {
      x: (touch.clientX - r.left) * (canvas.value.width / r.width),
      y: (touch.clientY - r.top) * (canvas.value.height / r.height)
    }
  }

  function pointerDown(e) {
    const pos = getPos(e)
    canvas.value.setPointerCapture(e.pointerId)

    if (tool.value === 'select') {
      let found = -1
      for (let i = elements.value.length - 1; i >= 0; i--) {
        if (hitTest(pos.x, pos.y, elements.value[i])) { found = i; break }
      }
      selectedIdx.value = found
      if (found >= 0) {
        dragging = true
        const el = elements.value[found]
        dragOffset.value = {
          x: pos.x - (el.x || el.x1 || 0),
          y: pos.y - (el.y || el.y1 || 0)
        }
        dragStart = { ...pos }
      }
      draw()
      return
    }

    if (tool.value === 'erase') {
      for (let i = elements.value.length - 1; i >= 0; i--) {
        if (hitTest(pos.x, pos.y, elements.value[i])) {
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

    if (['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash', 'zone'].includes(tool.value)) {
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
        el.x = pos.x - dragOffset.value.x
        el.y = pos.y - dragOffset.value.y
      }
      if (el.x1 !== undefined) {
        const ddx = pos.x - (dragStart?.x || pos.x)
        const ddy = pos.y - (dragStart?.y || pos.y)
        el.x1 += ddx
        el.y1 += ddy
        el.x2 += ddx
        el.y2 += ddy
      }
      if (el.type === 'free' && el.points) {
        el.points = el.points.map(p => ({ x: p.x + dx, y: p.y + dy }))
      }
      dragStart = { ...pos }
      draw()
      return
    }

    if (tool.value === 'erase' && e.buttons) {
      for (let i = elements.value.length - 1; i >= 0; i--) {
        if (hitTest(pos.x, pos.y, elements.value[i])) {
          elements.value.splice(i, 1)
          draw()
          return
        }
      }
    }

    if (tool.value === 'pencil' && isDrawing) {
      freePoints.push(pos)
      const ctx2 = canvas.value.getContext('2d')
      ctx2.clearRect(0, 0, canvas.value.width, canvas.value.height)
      draw()
      ctx2.save()
      ctx2.strokeStyle = color.value
      ctx2.lineWidth = strokeW.value
      ctx2.lineCap = 'round'
      ctx2.lineJoin = 'round'
      ctx2.beginPath()
      ctx2.moveTo(freePoints[0].x, freePoints[0].y)
      freePoints.forEach(p => ctx2.lineTo(p.x, p.y))
      ctx2.stroke()
      ctx2.restore()
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
      pushHistory()
      return
    }

    if (tool.value === 'pencil' && isDrawing) {
      isDrawing = false
      if (freePoints.length > 1) {
        elements.value.push({ type: 'free', points: [...freePoints], color: color.value, w: strokeW.value })
        pushHistory()
        draw()
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
          color: color.value, w: strokeW.value
        })
        selectedIdx.value = elements.value.length - 1
        pushHistory()
      }
      drawStart = null
      drawCurrent = null
      draw()
    }
  }

  function pushHistory() {
    history = history.slice(0, histIdx + 1)
    history.push(JSON.parse(JSON.stringify(elements.value)))
    histIdx = history.length - 1
  }

  function undo() {
    if (histIdx > 0) {
      histIdx--
      elements.value = JSON.parse(JSON.stringify(history[histIdx]))
      selectedIdx.value = -1
      draw()
    }
  }

  function redo() {
    if (histIdx < history.length - 1) {
      histIdx++
      elements.value = JSON.parse(JSON.stringify(history[histIdx]))
      selectedIdx.value = -1
      draw()
    }
  }

  function clearBoard() {
    if (confirm('Cancellare tutto il campo?')) {
      elements.value = []
      selectedIdx.value = -1
      pushHistory()
      draw()
    }
  }

  function saveToServer() {
    const W = canvas.value.width
    const H = canvas.value.height
    const serverElements = elements.value.map(el => {
      if (el.type === 'free' || el.type === 'zone' || ['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash'].includes(el.type)) {
        return {
          tipo: el.type,
          x1: (el.x1 / W) * 100,
          y1: (el.y1 / H) * 100,
          x2: (el.x2 / W) * 100,
          y2: (el.y2 / H) * 100,
          colore: el.color,
          size: el.size || 1,
          w: el.w || 2
        }
      }
      return {
        tipo: el.type,
        x: (el.x / W) * 100,
        y: (el.y / H) * 100,
        colore: el.color,
        size: el.size || 1
      }
    })
    if (onSave) onSave(serverElements)
  }

  function loadFromServer(serverElements) {
    if (!canvas.value) return
    const W = canvas.value.width
    const H = canvas.value.height
    elements.value = (serverElements || []).map(el => {
      if (el.tipo === 'free' || el.tipo === 'zone' || ['arrow', 'arrow-dash', 'arrow-curve', 'arrow-curve-dash'].includes(el.tipo)) {
        return {
          type: el.tipo,
          x1: (el.x1 / 100) * W,
          y1: (el.y1 / 100) * H,
          x2: (el.x2 / 100) * W,
          y2: (el.y2 / 100) * H,
          color: el.colore,
          size: el.size || 28,
          w: el.w || 2
        }
      }
      return {
        type: el.tipo,
        x: (el.x / 100) * W,
        y: (el.y / 100) * H,
        color: el.colore,
        size: el.size ? el.size * 28 : 28
      }
    })
    selectedIdx.value = -1
    draw()
  }

  function selectTool(t) {
    tool.value = t
    canvas.value.style.cursor = t === 'select' ? 'default' :
      t === 'erase' ? 'cell' : 'crosshair'
  }

  onMounted(() => {
    nextTick(() => {
      if (canvas.value) {
        ctx.value = canvas.value.getContext('2d')
        resize()
        pushHistory()
      }
    })
    window.addEventListener('resize', resize)
  })

  onUnmounted(() => {
    window.removeEventListener('resize', resize)
  })

  return {
    canvas,
    tool,
    color,
    strokeW,
    elemSize,
    fieldMode,
    selectedIdx,
    pointerDown,
    pointerMove,
    pointerUp,
    undo,
    redo,
    clearBoard,
    saveToServer,
    loadFromServer,
    selectTool,
    resize
  }
}
