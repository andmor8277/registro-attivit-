import { api } from './client'

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
