import axios from 'axios'

export const api = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' })

api.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      localStorage.removeItem('societa_id')
      localStorage.removeItem('societa_data')
      if (!window.location.pathname.includes('/login')) {
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

export const login = (username, password) => {
  const form = new URLSearchParams()
  form.append('username', username)
  form.append('password', password)
  return api.post('/auth/token', form)
}
export const getMe = () => api.get('/auth/me')
export const getUtenti = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/auth/utenti' + params)
}
export const createUtente = (data) => api.post('/auth/utenti', data)
export const deleteUtente = (id) => api.delete(`/auth/utenti/${id}`)
export const updateUtente = (id, data) => api.put(`/auth/utenti/${id}`, data)
export const resetPassword = (id) => api.put(`/auth/utenti/${id}/reset-password`)
export const changePassword = (id, vecchia, nuova) => api.put(`/auth/utenti/${id}/password`, { vecchia, nuova })
export const assegnaCategorie = (uid, categoria_ids) => api.put(`/auth/utenti/${uid}/categorie`, { categoria_ids })

export const getCategorie = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/categorie/' + params)
}
export const getAllCategorie = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/categorie/all' + params)
}
export const createCategoria = (data) => api.post('/categorie/', data)
export const updateCategoria = (id, data) => api.put(`/categorie/${id}`, data)
export const deleteCategoria = (id) => api.delete('/categorie/' + id)
export const getStagioni = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/categorie/stagioni' + params)
}
export const getCategorieArchived = () => api.get('/categorie/archived')
export const getCategorieByStagione = (stagione) => api.get('/categorie/by-stagione/' + stagione)
export const archiviaStagione = (stagione) => api.post('/categorie/archivia/' + stagione)
export const ripristinaStagione = (stagione) => api.post('/categorie/ripristina/' + stagione)
export const getCategoriaUtenti = (categoriaId) => api.get('/categorie/' + categoriaId + '/utenti')
export const getCategoriaResponsabili = (categoriaId) => api.get('/categorie/' + categoriaId + '/responsabili')
export const assegnaCategoriaUtenti = (categoriaId, utenteIds) => api.put('/categorie/' + categoriaId + '/utenti', { utente_ids: utenteIds })
export const importaGiocatori = (nuovaCategoriaId) => api.post('/categorie/importa-giocatori/' + nuovaCategoriaId)
export const getPersone = (categoriaId) => {
  if (categoriaId) return api.get('/persone/?categoria_id=' + categoriaId)
  return api.get('/persone/')
}
export const getGruppi = (categoriaId) => categoriaId ? api.get('/gruppi/?categoria_id=' + categoriaId) : api.get('/gruppi/')
export const createGruppo = (data) => api.post('/gruppi/', data)
export const deleteGruppo = (id) => api.delete('/gruppi/' + id)
export const getCodici = () => api.get('/codici/')
export const getRegistroMese = (categoriaId, anno, mese) => api.get('/registro/mese/' + categoriaId + '/' + anno + '/' + mese)
export const upsertRegistro = (entry) => api.post('/registro/', entry)
export const createPersona = (data) => api.post('/persone/', data)
export const updatePersona = (id, data) => api.put('/persone/' + id, data)
export const deletePersona = (id) => api.delete('/persone/' + id)

export const getConvocazioni = (categoriaId) => api.get('/convocazioni/?categoria_id=' + categoriaId)
export const getConvocazione = (id) => api.get('/convocazioni/' + id)
export const createConvocazione = (data) => api.post('/convocazioni/', data)
export const updateConvocazione = (id, data) => api.put('/convocazioni/' + id, data)
export const deleteConvocazione = (id) => api.delete('/convocazioni/' + id)

export const getAllenatori = () => api.get('/allenatori/')
export const createAllenatore = (data) => api.post('/allenatori/', data)
export const updateAllenatore = (id, data) => api.put('/allenatori/' + id, data)
export const deleteAllenatore = (id) => api.delete('/allenatori/' + id)

export const getSocieta = () => api.get('/societa/')
export const getSocietaById = (id) => api.get('/societa/' + id)
export const createSocieta = (data) => api.post('/societa/', data)
export const updateSocieta = (id, data) => api.put('/societa/' + id, data)
export const deleteSocieta = (id) => api.delete('/societa/' + id)
export const uploadSocietaFile = (tipo, file) => {
  const formData = new FormData()
  formData.append('file', file)
  return api.post(`/societa/upload/${tipo}`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })
}

export const getAllenamentiMesi = (categoriaId) => api.get('/allenamenti/mese/' + categoriaId)
export const getAllenamentiSettimane = (meseId) => api.get('/allenamenti/settimana/' + meseId)
export const getAllenamentiGiorni = (giornoId) => api.get('/allenamenti/giorno/' + giornoId)
export const getAllenamentiEsercizi = (giornoId) => api.get('/allenamenti/esercizio/' + giornoId)
export const getAllenamentiGiornoByData = (categoriaId, data) => api.get('/allenamenti/giorno-by-data/' + categoriaId + '/' + data)
export const getCatalogoEsercizi = (focus = '') => api.get('/allenamenti/catalogo' + (focus ? '?focus=' + focus : ''))
export const getCatalogoEserciziNew = (focus = '') => api.get('/allenamenti/catalogo-new' + (focus ? '?focus=' + focus : ''))
export const saveEsercizioToCatalogo = (data) => api.post('/allenamenti/catalogo-new', data)
export const deleteEsercizioFromCatalogo = (id) => api.delete('/allenamenti/catalogo-new/' + id)
export const getFocusList = () => api.get('/allenamenti/focus-list')
// Public API instance - no JWT interceptor
export const apiPublic = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' })

// Public endpoints for online form
export const getPublicPersona = (id) => apiPublic.get(`/persone/public/${id}`)
export const updatePublicPersona = (id, data) => apiPublic.put(`/persone/public/${id}`, data)
export const createPublicPersona = (data) => apiPublic.post('/persone/public/', data)

export function saveAllenamenti(categoriaId, payload) {
  return api.post('/allenamenti/', payload)
}

export const getPartite = (categoriaId) => {
  const params = categoriaId ? `?categoria_id=${categoriaId}` : ''
  return api.get('/partite/' + params)
}
export const creaPartita = (data) => api.post('/partite/', data)
export const aggiornaPartita = (id, data) => api.put(`/partite/${id}`, data)
export const eliminaPartita = (id) => api.delete(`/partite/${id}`)

export const getWeekend = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/weekend/' + params)
}
export const getWeekendPartite = (weekendId) => api.get(`/weekend/${weekendId}/partite`)
export const creaWeekend = (data) => api.post('/weekend/', data)
export const aggiornaWeekend = (id, data) => api.put(`/weekend/${id}`, data)
export const eliminaWeekend = (id) => api.delete(`/weekend/${id}`)

// Spogliatoi
export const getSpogliatoi = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/spogliatoi/' + params)
}
export const creaSpogliatoio = (data) => api.post('/spogliatoi/', data)
export const aggiornaSpogliatoio = (id, data) => api.put(`/spogliatoi/${id}`, data)
export const eliminaSpogliatoio = (id) => api.delete(`/spogliatoi/${id}`)
export const getAssegnazioniSettimana = (dataInizio) => api.get(`/spogliatoi/assegnazioni/settimana/${dataInizio}`)
export const getAssegnazioniWeekend = (weekendId) => api.get(`/spogliatoi/assegnazioni/weekend/${weekendId}`)
export const creaAssegnazione = (data) => api.post('/spogliatoi/assegnazioni', data)
export const aggiornaAssegnazione = (id, data) => api.put(`/spogliatoi/assegnazioni/${id}`, data)
export const eliminaAssegnazione = (id) => api.delete(`/spogliatoi/assegnazioni/${id}`)
export const getAssegnazioniDefault = () => api.get('/spogliatoi/assegnazioni/default')
export const applyDefaultWeekSpogliatoi = (dataInizio) => api.post(`/spogliatoi/assegnazioni/default/apply?data_inizio=${dataInizio}`)

// Campi da gioco
export const getCampi = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/campi/' + params)
}
export const creaCampo = (data) => api.post('/campi/', data)
export const aggiornaCampo = (id, data) => api.put(`/campi/${id}`, data)
export const eliminaCampo = (id) => api.delete(`/campi/${id}`)
export const getCampiAssegnazioniSettimana = (dataInizio) => api.get(`/campi/assegnazioni/settimana/${dataInizio}`)
export const getCampiAssegnazioniWeekend = (weekendId) => api.get(`/campi/assegnazioni/weekend/${weekendId}`)
export const creaCampoAssegnazione = (data) => api.post('/campi/assegnazioni', data)
export const aggiornaCampoAssegnazione = (id, data) => api.put(`/campi/assegnazioni/${id}`, data)
export const eliminaCampoAssegnazione = (id) => api.delete(`/campi/assegnazioni/${id}`)
export const getCampiAssegnazioniDefault = () => api.get('/campi/assegnazioni/default')
export const applyDefaultWeekCampi = (dataInizio) => api.post(`/campi/assegnazioni/default/apply?data_inizio=${dataInizio}`)

// Presenze allenatori
export const getPresenzeAllenatoriMese = (anno, mese) => api.get(`/presenze-allenatori/mese/${anno}/${mese}`)
export const upsertPresenzaAllenatore = (entry) => api.post('/presenze-allenatori/', entry)
export const getMisterList = () => api.get('/presenze-allenatori/mister')

// Valutazioni
export const getValutazioni = (categoriaId) => api.get('/valutazioni/categoria/' + categoriaId)
export const updateValutazione = (id, data) => api.put('/valutazioni/' + id, data)
export const createValutazione = (data) => api.post('/valutazioni/', data)

// Infortuni
export const getInfortuni = (params = {}) => {
  const qs = new URLSearchParams()
  if (params.categoria_id) qs.set('categoria_id', params.categoria_id)
  if (params.attivi !== undefined) qs.set('attivi', params.attivi)
  return api.get('/infortuni/?' + qs.toString())
}
export const creaInfortunio = (data) => api.post('/infortuni/', data)
export const aggiornaInfortunio = (id, data) => api.put(`/infortuni/${id}`, data)
export const eliminaInfortunio = (id) => api.delete(`/infortuni/${id}`)
export const chiudiInfortunio = (id) => api.post(`/infortuni/${id}/chiudi`)
export const getInfortuniScaduti = () => api.get('/infortuni/scaduti')

// Openday
export const getOpenday = () => api.get('/openday/')
export const creaOpenday = (data) => api.post('/openday/', data)
export const aggiornaOpenday = (id, data) => api.put(`/openday/${id}`, data)
export const eliminaOpenday = (id) => api.delete(`/openday/${id}`)
export const iscriviOpenday = (id) => api.post(`/openday/${id}/iscrivi`)
export const disiscriviOpenday = (id) => api.post(`/openday/${id}/disiscrivi`)

// Planning Eventi
export const getPlanningEventi = (categoria_id = null) => api.get('/planning-eventi/', { params: { categoria_id } })
export const creaPlanningEvento = (data) => api.post('/planning-eventi/', data)
export const aggiornaPlanningEvento = (id, data) => api.put(`/planning-eventi/${id}`, data)
export const eliminaPlanningEvento = (id) => api.delete(`/planning-eventi/${id}`)
