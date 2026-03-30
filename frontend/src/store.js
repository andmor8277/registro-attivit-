import { ref } from 'vue'

const categoriaAttiva = ref(null)
const token = ref(localStorage.getItem('token') || null)
const utenteAttivo = ref(null)
const stagioneCorrente = ref(null)
const societaAttiva = ref(null)
const listaSocieta = ref([])

export function useStore() {
  function setCategoria(cat) { categoriaAttiva.value = cat }
  function setToken(t) { token.value = t; localStorage.setItem('token', t) }
  function setStagioneCorrente(s) { stagioneCorrente.value = s }
  function setSocietaAttiva(s) { 
    societaAttiva.value = s 
    localStorage.setItem('societa_id', s?.id || '')
  }
  function setListaSocieta(list) { listaSocieta.value = list }
  function clearToken() { 
    token.value = null; 
    utenteAttivo.value = null; 
    societaAttiva.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('societa_id')
  }
  
  // Carica società salvata
  const savedSocietaId = localStorage.getItem('societa_id')
  if (savedSocietaId) {
    societaAttiva.value = { id: parseInt(savedSocietaId) }
  }
  
  return { 
    categoriaAttiva, 
    token, 
    utenteAttivo, 
    stagioneCorrente, 
    societaAttiva,
    listaSocieta,
    setCategoria, 
    setToken, 
    setStagioneCorrente, 
    setSocietaAttiva,
    setListaSocieta,
    clearToken 
  }
}
