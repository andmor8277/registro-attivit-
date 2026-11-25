import { api } from './client'

export const getConvocazioni = (categoriaId) => api.get('/convocazioni/' + (categoriaId ? '?categoria_id=' + categoriaId : ''))
export const getConvocazione = (id) => api.get('/convocazioni/' + id)
export const createConvocazione = (data) => api.post('/convocazioni/', data)
export const updateConvocazione = (id, data) => api.put(`/convocazioni/${id}`, data)
export const deleteConvocazione = (id) => api.delete(`/convocazioni/${id}`)

// ---- Convocazione di una GARA DI TORNEO ----
// Sono lo stesso aggregato di sopra con un solo campo in piu', `tornei_gara_id`, che pero' cambia
// completamente il percorso nel backend: con quel campo il router non tocca ne' weekend ne' partite.
// `creaConvocazioneTorneo` e' idempotente per costruzione (un foglio per gara): riaprire la convocazione
// due volte non produce un secondo foglio, e la pagina la chiama all'apertura del modal senza doversi
// ricordare se era gia' stata aperta.
export const getConvocazioneDiGaraTorneo = (garaId) =>
  api.get('/convocazioni/?tornei_gara_id=' + garaId)
export const creaConvocazioneTorneo = (data) => api.post('/convocazioni/', { ...data, gare: [] })
export const salvaConvocazioneTorneo = (id, data) => api.put(`/convocazioni/${id}`, data)

export const getPartite = (categoriaId, societaId) => {
  const params = new URLSearchParams()
  if (categoriaId) params.append('categoria_id', categoriaId)
  if (societaId) params.append('societa_id', societaId)
  const qs = params.toString()
  return api.get('/partite/' + (qs ? `?${qs}` : ''))
}
export const getCampiSportivi = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/partite/campi-sportivi' + params)
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
export const getAssegnazioniSettimana = (dataInizio, societaId) => {
  const qs = societaId ? `?societa_id=${societaId}` : ''
  return api.get(`/spogliatoi/assegnazioni/settimana/${dataInizio}${qs}`)
}
export const getAssegnazioniWeekend = (weekendId) => api.get(`/spogliatoi/assegnazioni/weekend/${weekendId}`)
export const creaAssegnazione = (data) => api.post('/spogliatoi/assegnazioni', data)
export const aggiornaAssegnazione = (id, data) => api.put(`/spogliatoi/assegnazioni/${id}`, data)
export const eliminaAssegnazione = (id) => api.delete(`/spogliatoi/assegnazioni/${id}`)
export const getAssegnazioniDefault = (societaId) => {
  const qs = societaId ? `?societa_id=${societaId}` : ''
  return api.get(`/spogliatoi/assegnazioni/default${qs}`)
}
export const applyDefaultWeekSpogliatoi = (dataInizio, societaId) => {
  const params = new URLSearchParams({ data_inizio: dataInizio })
  if (societaId) params.append('societa_id', societaId)
  return api.post(`/spogliatoi/assegnazioni/default/apply?${params.toString()}`)
}
export const salvaAssegnazioniSettimanaSpogliatoi = (data) => api.post('/spogliatoi/assegnazioni/settimana', data)
export const salvaAssegnazioniWeekendSpogliatoi = (data) => api.post('/spogliatoi/assegnazioni/weekend', data)

export const getCampi = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/campi/' + params)
}
export const creaCampo = (data) => api.post('/campi/', data)
export const aggiornaCampo = (id, data) => api.put(`/campi/${id}`, data)
export const eliminaCampo = (id) => api.delete(`/campi/${id}`)
export const getCampiAssegnazioniSettimana = (dataInizio, societaId) => {
  const qs = societaId ? `?societa_id=${societaId}` : ''
  return api.get(`/campi/assegnazioni/settimana/${dataInizio}${qs}`)
}
export const getCampiAssegnazioniWeekend = (weekendId) => api.get(`/campi/assegnazioni/weekend/${weekendId}`)
export const creaCampoAssegnazione = (data) => api.post('/campi/assegnazioni', data)
export const aggiornaCampoAssegnazione = (id, data) => api.put(`/campi/assegnazioni/${id}`, data)
export const eliminaCampoAssegnazione = (id) => api.delete(`/campi/assegnazioni/${id}`)
export const getCampiAssegnazioniDefault = (societaId) => {
  const qs = societaId ? `?societa_id=${societaId}` : ''
  return api.get(`/campi/assegnazioni/default${qs}`)
}
export const applyDefaultWeekCampi = (dataInizio, societaId) => {
  const params = new URLSearchParams({ data_inizio: dataInizio })
  if (societaId) params.append('societa_id', societaId)
  return api.post(`/campi/assegnazioni/default/apply?${params.toString()}`)
}
export const salvaAssegnazioniSettimanaCampi = (data) => api.post('/campi/assegnazioni/settimana', data)
export const salvaAssegnazioniWeekendCampi = (data) => api.post('/campi/assegnazioni/weekend', data)

export const getListeTorneo = (categoriaId, societaId) => {
  const params = new URLSearchParams()
  if (categoriaId) params.append('categoria_id', categoriaId)
  if (societaId) params.append('societa_id', societaId)
  const qs = params.toString()
  return api.get('/liste-torneo/' + (qs ? `?${qs}` : ''))
}
export const creaListaTorneo = (data) => api.post('/liste-torneo/', data)
export const eliminaListaTorneo = (id) => api.delete('/liste-torneo/' + id)
export const getGiocatoriLista = (listaId) => api.get('/liste-torneo/' + listaId + '/giocatori')
export const aggiungiGiocatoreLista = (listaId, personaId) => api.post('/liste-torneo/' + listaId + '/giocatori', null, { params: { persona_id: personaId } })
export const rimuoviGiocatoreLista = (listaId, personaId) => api.delete('/liste-torneo/' + listaId + '/giocatori/' + personaId)

// ---- Tornei (Natale, Pasqua, tornei di stagione) ----
// Il calendario sta qui, la lista dei giocatori no: quella resta in /liste-torneo, collegata
// al torneo, perche' l'export PDF del file da consegnare all'organizzatore vive gia' li'.
export const getTornei = (params = {}) => {
  const qs = new URLSearchParams()
  if (params.categoria_id) qs.append('categoria_id', params.categoria_id)
  if (params.societa_id) qs.append('societa_id', params.societa_id)
  if (params.da) qs.append('da', params.da)
  if (params.a) qs.append('a', params.a)
  // `scope` va elencato qui, NON e' un parametro che passa da solo: questa e' una whitelist, e una
  // whitelist che non nomina una chiave la butta via **in silenzio**, senza errori e senza log. E'
  // successo davvero il 25/11/2026 con lo scope: la pagina lo passava, `getTornei` lo scartava, e
  // sembrava funzionare perche' il default del server (`mie_categorie`) coincide con quello che la
  // pagina chiede -- quindi il filtro per categoria si vedeva a schermo. Cio' che non funzionava era
  // l'interruttore "Tutte le categorie della societa'", che lasciava la lista identica a se stessa: un
  // controllo visibile che non fa niente e' peggio di un controllo assente, perche' chi l'ha premuto
  // crede di stare vedendo tutto. L'asserzione che lo ha trovato e' in `ui_tornei.cjs` ("la pagina
  // chiede i tornei con scope=mie_categorie"), e non e' duplicabile lato API: li' il parametro viene
  // sempre passato a mano, quindi il buco non si vede mai
  if (params.scope) qs.append('scope', params.scope)
  const q = qs.toString()
  return api.get('/tornei/' + (q ? `?${q}` : ''))
}
export const getTorneo = (id) => api.get(`/tornei/${id}`)
export const creaTorneo = (data) => api.post('/tornei/', data)
export const aggiornaTorneo = (id, data) => api.put(`/tornei/${id}`, data)
export const eliminaTorneo = (id) => api.delete(`/tornei/${id}`)
export const aggiungiGaraTorneo = (id, data) => api.post(`/tornei/${id}/gare`, data)
export const modificaGaraTorneo = (id, garaId, data) => api.put(`/tornei/${id}/gare/${garaId}`, data)
export const eliminaGaraTorneo = (id, garaId) => api.delete(`/tornei/${id}/gare/${garaId}`)
// Iscrivere una categoria a un torneo porta con se' il suo foglio giocatori: lo fa il backend
// nello stesso transaction, non va creato qui con creaListaTorneo.
export const iscriviCategoriaTorneo = (id, categoriaId) => api.post(`/tornei/${id}/categorie`, { categoria_id: categoriaId })
export const rimuoviCategoriaTorneo = (id, categoriaId) => api.delete(`/tornei/${id}/categorie/${categoriaId}`)
