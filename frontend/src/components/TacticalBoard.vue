<template>
  <div class="tactical-board-container">
    <iframe
      ref="boardIframe"
      :src="iframeSrc"
      class="board-iframe"
      frameborder="0"
      allowfullscreen
      style="width:100%;height:100%;border:none;display:block"
    ></iframe>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue'

const props = defineProps({
  elements: {
    type: Array,
    default: () => []
  },
  fieldMode: {
    type: String,
    default: 'full'
  }
})

const emit = defineEmits(['update:elements', 'update:fieldMode'])

const boardIframe = ref(null)
const iframeSrc = ref('/lavagna-20250702.html')
const lastSentElements = ref(null)
const lastCanvasTs = ref(0)
const isProcessingUpdate = ref(false)
const isRequesting = ref(false)
let elementsResolve = null
let elementsTimeout = null
let unloadHandler = null

onMounted(() => {
  const params = new URLSearchParams()
  params.set('fieldMode', props.fieldMode || 'full')
  iframeSrc.value = `/lavagna-20250702.html?${params.toString()}`

  nextTick(() => {
    if (boardIframe.value) {
      unloadHandler = () => {
        window.addEventListener('message', handleMessage)
        // Invia elementi via postMessage dopo il load
        const hasElements = props.elements && props.elements.length > 0
        if (hasElements) {
          lastSentElements.value = JSON.stringify(props.elements)
          try {
            const clonedElements = JSON.parse(JSON.stringify(props.elements))
            boardIframe.value.contentWindow.postMessage({type:'loadElements', elements: clonedElements}, '*')
          } catch(e) {
            console.error('[TacticalBoard] Errore invio elementi iniziali:', e)
          }
        }
      }
      boardIframe.value.addEventListener('load', unloadHandler)
    }
  })
})

onUnmounted(() => {
  if (boardIframe.value && unloadHandler) {
    boardIframe.value.removeEventListener('load', unloadHandler)
  }
  window.removeEventListener('message', handleMessage)
  if (elementsTimeout) clearTimeout(elementsTimeout)
})

function handleMessage(event) {
  if (!boardIframe.value || event.source !== boardIframe.value.contentWindow) return

  if (event.data && event.data.type === 'fieldModeChanged') {
    emit('update:fieldMode', event.data.mode)
    return
  }

  if (event.data && event.data.type === 'elementsUpdated') {
    if (isRequesting.value) return
    const elementsStr = JSON.stringify(event.data.elements)
    if (elementsStr !== lastSentElements.value) {
      isProcessingUpdate.value = true
      lastSentElements.value = elementsStr
      lastCanvasTs.value = event.data.canvasTs || 0
      emit('update:elements', event.data.elements)

      nextTick(() => {
        isProcessingUpdate.value = false
      })
    }
  }
}

watch(() => props.elements, (newElements) => {
  if (isProcessingUpdate.value) return
  if (!newElements || newElements.length === 0) return

  const newStr = JSON.stringify(newElements)
  if (newStr === lastSentElements.value) return

  lastSentElements.value = newStr
  const iframeWindow = boardIframe.value?.contentWindow
  if (!iframeWindow) return

  try {
    const clonedElements = JSON.parse(JSON.stringify(newElements))
    iframeWindow.postMessage({type:'loadElements', elements: clonedElements, canvasTs: lastCanvasTs.value}, '*')
  } catch(e) {
    console.error('[TacticalBoard] Errore invio elementi all\'iframe:', e)
  }
}, { deep: true })

watch(() => props.fieldMode, (newMode) => {
  const iframeWindow = boardIframe.value?.contentWindow
  if (iframeWindow) {
    try {
      iframeWindow.postMessage({type:'updateFieldMode', mode: newMode}, '*')
    } catch(e) {
      console.error('[TacticalBoard] Errore invio fieldMode:', e)
    }
  }
})

function requestElements() {
  const iframeWindow = boardIframe.value?.contentWindow
  if (!iframeWindow) return Promise.resolve(null)

  return new Promise((resolve) => {
    isRequesting.value = true
    elementsTimeout = setTimeout(() => {
      isRequesting.value = false
      resolve(null)
    }, 2000)

    const handler = (event) => {
      if (event.source === iframeWindow && event.data && event.data.type === 'elementsUpdated') {
        clearTimeout(elementsTimeout)
        isRequesting.value = false
        window.removeEventListener('message', handler)
        resolve(event.data.elements)
      }
    }

    window.addEventListener('message', handler)
    iframeWindow.postMessage({type:'getElements'}, '*')
  })
}

defineExpose({ requestElements })
</script>

<style scoped>
.tactical-board-container {
  width: 100%;
  height: 100%;
  overflow: hidden;
}

.board-iframe {
  width: 100%;
  height: 100%;
  border: none;
  display: block;
}
</style>