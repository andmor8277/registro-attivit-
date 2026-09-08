import { api } from './client'

export const getCodici = () => api.get('/codici/')
export const getRegistroMese = (categoriaId, anno, mese) => api.get('/registro/mese/' + categoriaId + '/' + anno + '/' + mese)
export const upsertRegistro = (entry) => api.post('/registro/', entry)
export const getPresenzeAllenatoriMese = (anno, mese) => api.get(`/presenze-allenatori/mese/${anno}/${mese}`)
export const upsertPresenzaAllenatore = (entry) => api.post('/presenze-allenatori/', entry)
export const getMisterList = () => api.get('/presenze-allenatori/mister')
