import { api } from './client'

export const getAllenatori = () => api.get('/allenatori/')
export const createAllenatore = (data) => api.post('/allenatori/', data)
export const updateAllenatore = (id, data) => api.put(`/allenatori/${id}`, data)
export const deleteAllenatore = (id) => api.delete(`/allenatori/${id}`)

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
export function saveAllenamenti(categoriaId, payload) {
  return api.post('/allenamenti/', payload)
}

export const getSchedeAllenamento = (params = {}) => api.get('/schede-allenamento/', { params })
export const creaSchedaAllenamento = (data) => api.post('/schede-allenamento/', data)
export const aggiornaSchedaAllenamento = (id, data) => api.put(`/schede-allenamento/${id}`, data)
export const eliminaSchedaAllenamento = (id) => api.delete(`/schede-allenamento/${id}`)
export const getSchedeTrend = (params) => api.get('/schede-allenamento/stats/trend', { params })
export const getSchedeSummary = (params) => api.get('/schede-allenamento/stats/summary', { params })
export const getSchedeTeam = (params) => api.get('/schede-allenamento/stats/team', { params })
export const getSchedePlayerTrend = (params) => api.get('/schede-allenamento/stats/player-trend', { params })
