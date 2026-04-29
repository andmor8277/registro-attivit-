import axios from 'axios'

export const api = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' })

api.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

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

export const saveAllenamenti = (categoriaId, data) => {
  const payload = {
    categoria_id: categoriaId,
    data: data.settimane[0]?.giorni[0]?.data || data.settimane[0]?.data_inizio,
    esercizi: data.settimane[0]?.giorni[0]?.esercizi || []
  }
  return api.post('/allenamenti/', payload)
}
