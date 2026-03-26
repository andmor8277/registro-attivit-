import { ref } from 'vue'

const categoriaAttiva = ref(null)
const token = ref(localStorage.getItem('token') || null)
const utenteAttivo = ref(null)

export function useStore() {
  function setCategoria(cat) { categoriaAttiva.value = cat }
  function setToken(t) { token.value = t; localStorage.setItem('token', t) }
  function clearToken() { token.value = null; utenteAttivo.value = null; localStorage.removeItem('token') }
  return { categoriaAttiva, token, utenteAttivo, setCategoria, setToken, clearToken }
}
