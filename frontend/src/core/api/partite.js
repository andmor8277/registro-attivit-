import { api } from './client'

export const getConvocazioni = (categoriaId) => api.get('/convocazioni/?categoria_id=' + categoriaId)
export const getConvocazione = (id) => api.get('/convocazioni/' + id)
export const createConvocazione = (data) => api.post('/convocazioni/', data)
export const updateConvocazione = (id, data) => api.put(`/convocazioni/${id}`, data)
export const deleteConvocazione = (id) => api.delete(`/convocazioni/${id}`)

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

export const getListeTorneo = (categoriaId) => api.get('/liste-torneo/?categoria_id=' + categoriaId)
export const creaListaTorneo = (data) => api.post('/liste-torneo/', data)
export const eliminaListaTorneo = (id) => api.delete('/liste-torneo/' + id)
export const getGiocatoriLista = (listaId) => api.get('/liste-torneo/' + listaId + '/giocatori')
export const aggiungiGiocatoreLista = (listaId, personaId) => api.post('/liste-torneo/' + listaId + '/giocatori', null, { params: { persona_id: personaId } })
export const rimuoviGiocatoreLista = (listaId, personaId) => api.delete('/liste-torneo/' + listaId + '/giocatori/' + personaId)
