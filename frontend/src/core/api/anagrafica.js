import { api } from './client'

export const getCategorie = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/categorie/' + params)
}
export const getAllCategorie = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/categorie/all' + params)
}
/**
 * Le categorie assegnate a **chi chiede**, sempre e solo quelle: lista di id.
 *
 * Non e' `getCategorie`, che per admin e segreteria restituisce TUTTE le categorie della societa'
 * (eccezione di ruolo che esiste da prima). Serve a Tornei.vue per limitare le SEZIONI del calendario
 * dei tornei alle categorie di chi guarda: con `getCategorie` la whitelist per un admin sarebbe "tutte",
 * e un torneo iscritto a quattro categorie - di cui una sola sua - ricomparirebbe nelle altre tre.
 * Il permesso vero sta nel backend (`GET /tornei/?scope=`); questo e' cio' che la pagina usa per non
 * dipingere piu' di quanto il server le ha dato.
 */
export const getMieCategorie = () => api.get('/categorie/mie')
export const createCategoria = (data) => api.post('/categorie/', data)
export const updateCategoria = (id, data) => api.put(`/categorie/${id}`, data)
export const deleteCategoria = (id) => api.delete('/categorie/' + id)
export const getStagioni = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/categorie/stagioni' + params)
}
export const getCategorieArchived = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/categorie/archived' + params)
}
export const getCategorieByStagione = (stagione, societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/categorie/by-stagione/' + stagione + params)
}
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
export const getPersone = (categoriaId, societaId) => {
  const params = new URLSearchParams()
  if (categoriaId) params.append('categoria_id', categoriaId)
  if (societaId) params.append('societa_id', societaId)
  const qs = params.toString()
  return api.get('/persone/' + (qs ? `?${qs}` : ''))
}
export const createPersona = (data) => api.post('/persone/', data)
export const updatePersona = (id, data) => api.put('/persone/' + id, data)
export const deletePersona = (id) => api.delete('/persone/' + id)
export const generaCf = (data) => api.post('/persone/genera-cf', data)
export const getGruppi = (categoriaId, societaId) => {
  const params = new URLSearchParams()
  if (categoriaId) params.append('categoria_id', categoriaId)
  if (societaId) params.append('societa_id', societaId)
  const qs = params.toString()
  return api.get('/gruppi/' + (qs ? `?${qs}` : ''))
}
export const createGruppo = (data) => api.post('/gruppi/', data)
export const deleteGruppo = (id) => api.delete('/gruppi/' + id)
export const updateGruppo = (id, data) => api.put('/gruppi/' + id, data)
export const updateScadenzaCertificato = (personaId, data) => api.patch('/persone/' + personaId + '/certificato', data)
