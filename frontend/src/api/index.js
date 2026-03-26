import axios from 'axios'

const api = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' })

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
export const getUtenti = () => api.get('/auth/utenti')
export const createUtente = (data) => api.post('/auth/utenti', data)
export const deleteUtente = (id) => api.delete(`/auth/utenti/${id}`)
export const updateUtente = (id, data) => api.put(`/auth/utenti/${id}`, data)
export const resetPassword = (id) => api.put(`/auth/utenti/${id}/reset-password`)
export const changePassword = (id, vecchia, nuova) => api.put(`/auth/utenti/${id}/password`, { vecchia, nuova })
export const assegnaCategorie = (uid, categoria_ids) => api.put(`/auth/utenti/${uid}/categorie`, { categoria_ids })

export const getCategorie = () => api.get('/categorie/')
export const getAllCategorie = () => api.get('/categorie/all')
export const createCategoria = (data) => api.post('/categorie/', data)
export const updateCategoria = (id, data) => api.put(`/categorie/${id}`, data)
export const deleteCategoria = (id) => api.delete('/categorie/' + id)
export const getStagioni = () => api.get('/categorie/stagioni')
export const getCategorieArchived = () => api.get('/categorie/archived')
export const getCategorieByStagione = (stagione) => api.get('/categorie/by-stagione/' + stagione)
export const archiviaStagione = (stagione) => api.post('/categorie/archivia/' + stagione)
export const ripristinaStagione = (stagione) => api.post('/categorie/ripristina/' + stagione)
export const getCategoriaUtenti = (categoriaId) => api.get('/categorie/' + categoriaId + '/utenti')
export const assegnaCategoriaUtenti = (categoriaId, utenteIds) => api.put('/categorie/' + categoriaId + '/utenti', { utente_ids: utenteIds })
export const importaGiocatori = (nuovaCategoriaId) => api.post('/categorie/importa-giocatori/' + nuovaCategoriaId)
export const getPersone = (categoriaId) => api.get('/persone/?categoria_id=' + categoriaId)
export const getCodici = () => api.get('/codici/')
export const getRegistroMese = (categoriaId, anno, mese) => api.get('/registro/mese/' + categoriaId + '/' + anno + '/' + mese)
export const upsertRegistro = (entry) => api.post('/registro/', entry)
export const createPersona = (data) => api.post('/persone/', data)
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
