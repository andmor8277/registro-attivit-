import axios from 'axios'
import { api } from './client'

export const creaInvito = (data) => api.post('/inviti/', data)
export const listaInviti = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/inviti/' + params)
}
export const eliminaInvito = (id) => api.delete(`/inviti/${id}`)
export const rinviaInvito = (id) => api.post(`/inviti/${id}/rinvia`)
export const verificaInvito = (token) => axios.get((import.meta.env.VITE_API_URL || '/api') + '/inviti/verifica/' + token)
