import { api } from './client'

export const getSegnalazioniScouting = (params = {}) => {
  const qs = new URLSearchParams()
  if (params.stato) qs.set('stato', params.stato)
  if (params.categoria_id) qs.set('categoria_id', params.categoria_id)
  if (params.q) qs.set('q', params.q)
  return api.get('/scouting/segnalazioni?' + qs.toString())
}

export const getSegnalazioneScouting = (id) => api.get(`/scouting/segnalazioni/${id}`)
export const creaSegnalazioneScouting = (data) => api.post('/scouting/segnalazioni', data)
export const aggiornaSegnalazioneScouting = (id, data) => api.put(`/scouting/segnalazioni/${id}`, data)
export const eliminaSegnalazioneScouting = (id) => api.delete(`/scouting/segnalazioni/${id}`)
export const cambiaStatoScouting = (id, stato) => api.put(`/scouting/segnalazioni/${id}/stato`, { stato })
export const valutaGiocatoreScouting = (id, data) => api.put(`/scouting/giocatori/${id}`, data)
