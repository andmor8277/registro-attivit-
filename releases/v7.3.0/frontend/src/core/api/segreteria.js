import { api } from './client'

export const getOpenday = () => api.get('/openday/')
export const creaOpenday = (data) => api.post('/openday/', data)
export const aggiornaOpenday = (id, data) => api.put(`/openday/${id}`, data)
export const eliminaOpenday = (id) => api.delete(`/openday/${id}`)
export const iscriviOpenday = (id) => api.post(`/openday/${id}/iscrivi`)
export const disiscriviOpenday = (id) => api.post(`/openday/${id}/disiscrivi`)

export const getValutazioni = (categoriaId) => api.get('/valutazioni/categoria/' + categoriaId)
export const updateValutazione = (id, data) => api.put('/valutazioni/' + id, data)
export const createValutazione = (data) => api.post('/valutazioni/', data)

export const getPlanningEventi = (categoria_id = null) => api.get('/planning-eventi/', { params: { categoria_id } })
export const creaPlanningEvento = (data) => api.post('/planning-eventi/', data)
export const aggiornaPlanningEvento = (id, data) => api.put(`/planning-eventi/${id}`, data)
export const eliminaPlanningEvento = (id) => api.delete(`/planning-eventi/${id}`)
