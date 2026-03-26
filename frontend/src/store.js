import { ref } from 'vue'

const categoriaAttiva = ref(null)
const token = ref(localStorage.getItem('token') || null)
const utenteAttivo = ref(null)
const stagioneCorrente = ref(null)

export function useStore() {
  function setCategoria(cat) { categoriaAttiva.value = cat }
  function setToken(t) { token.value = t; localStorage.setItem('token', t) }
  function setStagioneCorrente(s) { stagioneCorrente.value = s }
  function clearToken() { token.value = null; utenteAttivo.value = null; localStorage.removeItem('token') }
  return { categoriaAttiva, token, utenteAttivo, stagioneCorrente, setCategoria, setToken, setStagioneCorrente, clearToken }
}
