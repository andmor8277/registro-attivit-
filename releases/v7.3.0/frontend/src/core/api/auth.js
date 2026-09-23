import axios from 'axios'
import { api } from './client'

export const login = (username, password) => {
  const form = new URLSearchParams()
  form.append('username', username)
  form.append('password', password)
  return api.post('/auth/token', form)
}
export const getMe = () => api.get('/auth/me')
export const getUtenti = (societaId) => {
  const params = societaId ? `?societa_id=${societaId}` : ''
  return api.get('/auth/utenti' + params)
}
export const createUtente = (data) => api.post('/auth/utenti', data)
export const deleteUtente = (id) => api.delete(`/auth/utenti/${id}`)
export const updateUtente = (id, data) => api.put(`/auth/utenti/${id}`, data)
export const resetPassword = (id) => api.put(`/auth/utenti/${id}/reset-password`)
export const changePassword = (id, vecchia, nuova) => api.put(`/auth/utenti/${id}/password`, { vecchia, nuova })
export const assegnaCategorie = (uid, categoria_ids) => api.put(`/auth/utenti/${uid}/categorie`, { categoria_ids })

export const googleAuthorize = (invitoToken) => {
  const params = invitoToken ? `?invito=${invitoToken}` : ''
  window.location.href = (import.meta.env.VITE_API_URL || '/api') + '/auth/google/authorize' + params
}
export const googleCallback = (code, state) => {
  const base = import.meta.env.VITE_API_URL || '/api'
  return axios.get(`${base}/auth/google/callback`, { params: { code, state } })
}
export const registraUtenteGoogle = (data) => api.post('/auth/google/registra', data)
