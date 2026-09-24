import axios from 'axios'
import { api, getApiBaseUrl } from './client'

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

import { Browser } from '@capacitor/browser'
import { Capacitor } from '@capacitor/core'

export const googleAuthorize = async (invitoToken) => {
  const params = new URLSearchParams()
  if (invitoToken) params.append('invito', invitoToken)
  if (Capacitor.isNativePlatform()) {
    params.append('mobile', 'true')
    const authUrl = `${getApiBaseUrl()}/auth/google/authorize?${params.toString()}`
    await Browser.open({ url: authUrl, windowName: '_system' })
    return
  }
  const queryStr = params.toString() ? `?${params.toString()}` : ''
  window.location.href = getApiBaseUrl() + '/auth/google/authorize' + queryStr
}
export const googleCallback = (code, state) => {
  return axios.get(`${getApiBaseUrl()}/auth/google/callback`, { params: { code, state } })
}
export const registraUtenteGoogle = (data) => api.post('/auth/google/registra', data)
export const verifyGdpr = (codiceFiscale, categoriaId = null) => {
  const params = { codice_fiscale: codiceFiscale }
  if (categoriaId) params.categoria_id = categoriaId
  return api.post('/auth/verify-gdpr', null, { params })
}
