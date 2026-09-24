import { api } from './client'

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
export const archiviaStagione = (stagione, societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.post('/categorie/archivia/' + stagione + params)
}
export const ripristinaStagione = (stagione, societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.post('/categorie/ripristina/' + stagione + params)
}
export const getCategoriaUtenti = (categoriaId) => api.get('/categorie/' + categoriaId + '/utenti')
export const getCategoriaResponsabili = (categoriaId) => api.get('/categorie/' + categoriaId + '/responsabili')
export const assegnaCategoriaUtenti = (categoriaId, utenteIds) => api.put('/categorie/' + categoriaId + '/utenti', { utente_ids: utenteIds })
export const importaGiocatori = (nuovaCategoriaId) => api.post('/categorie/importa-giocatori/' + nuovaCategoriaId)
export const getPersone = (categoriaId) => {
  if (categoriaId) return api.get('/persone/?categoria_id=' + categoriaId)
  return api.get('/persone/')
}
export const createPersona = (data) => api.post('/persone/', data)
export const updatePersona = (id, data) => api.put('/persone/' + id, data)
export const deletePersona = (id) => api.delete('/persone/' + id)
export const generaCf = (data) => api.post('/persone/genera-cf', data)
export const getGruppi = (categoriaId) => categoriaId ? api.get('/gruppi/?categoria_id=' + categoriaId) : api.get('/gruppi/')
export const createGruppo = (data) => api.post('/gruppi/', data)
export const deleteGruppo = (id) => api.delete('/gruppi/' + id)
export const updateGruppo = (id, data) => api.put('/gruppi/' + id, data)
