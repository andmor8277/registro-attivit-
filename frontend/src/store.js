import { ref } from 'vue'

const categoriaAttiva = ref(null)
const token = ref(localStorage.getItem('token') || null)
const utenteAttivo = ref(null)
const stagioneCorrente = ref(null)
const societaAttiva = ref(null)
const listaSocieta = ref([])
const hideTopbar = ref(false)

function applySocietaColors(societa) {
  if (societa && societa.colore_primario) {
    document.documentElement.style.setProperty('--color-primary', societa.colore_primario)
    // Add dark and light variants
    const hex = societa.colore_primario.replace('#', '')
    const r = parseInt(hex.substring(0, 2), 16)
    const g = parseInt(hex.substring(2, 4), 16)
    const b = parseInt(hex.substring(4, 6), 16)
    const dark = `rgb(${Math.max(0, r-30)}, ${Math.max(0, g-30)}, ${Math.max(0, b-30)})`
    const light = `rgba(${r}, ${g}, ${b}, 0.3)`
    document.documentElement.style.setProperty('--color-primary-dark', dark)
    document.documentElement.style.setProperty('--color-primary-light', light)
  } else {
    // Default colors
    document.documentElement.style.setProperty('--color-primary', '#dc2626')
    document.documentElement.style.setProperty('--color-primary-dark', '#b91c1c')
    document.documentElement.style.setProperty('--color-primary-light', 'rgba(220, 38, 38, 0.3)')
  }
}

export function useStore() {
  function setCategoria(cat) { categoriaAttiva.value = cat }
  function setToken(t) { token.value = t; localStorage.setItem('token', t) }
  function setStagioneCorrente(s) { stagioneCorrente.value = s }
  function setSocietaAttiva(s) { 
    societaAttiva.value = s 
    if (s && s.id) {
      localStorage.setItem('societa_id', s.id)
      localStorage.setItem('societa_data', JSON.stringify(s))
    } else {
      localStorage.removeItem('societa_id')
      localStorage.removeItem('societa_data')
    }
    applySocietaColors(s)
  }
  function setListaSocieta(list) { listaSocieta.value = list }
  function clearToken() { 
    token.value = null; 
    utenteAttivo.value = null; 
    societaAttiva.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('societa_id')
    localStorage.removeItem('societa_data')
    localStorage.removeItem('is_super_admin')
    localStorage.removeItem('is_admin')
  }
  
  // Carica società salvata
  const savedSocietaData = localStorage.getItem('societa_data')
  if (savedSocietaData) {
    try {
      societaAttiva.value = JSON.parse(savedSocietaData)
      applySocietaColors(societaAttiva.value)
    } catch (e) {
      const savedSocietaId = localStorage.getItem('societa_id')
      if (savedSocietaId) {
        societaAttiva.value = { id: parseInt(savedSocietaId) }
      }
    }
  }
  
  return { 
    categoriaAttiva, 
    token, 
    utenteAttivo, 
    stagioneCorrente, 
    societaAttiva,
    listaSocieta,
    hideTopbar,
    setCategoria, 
    setToken, 
    setStagioneCorrente, 
    setSocietaAttiva,
    setListaSocieta,
    clearToken 
  }
}
