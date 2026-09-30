import axios from 'axios'
import { Capacitor } from '@capacitor/core'
import { isSessionExpired, recordActivity, clearActivity } from '../../composables/useInactivity.js'

const DEFAULT_PROD_API = 'https://thof.crickethouse.mywire.org/api'

export function getApiBaseUrl() {
  if (import.meta.env.VITE_API_URL) {
    return import.meta.env.VITE_API_URL
  }
  if (Capacitor.isNativePlatform()) {
    return DEFAULT_PROD_API
  }
  return '/api'
}

export const api = axios.create({ baseURL: getApiBaseUrl(), timeout: 15000 })

api.interceptors.request.use(config => {
  if (isSessionExpired()) {
    localStorage.removeItem('token')
    localStorage.removeItem('societa_id')
    localStorage.removeItem('societa_data')
    localStorage.removeItem('utente_data')
    clearActivity()
    if (!window.location.pathname.includes('/login')) {
      window.location.href = '/login?session_expired=1'
    }
    return Promise.reject(new Error('Sessione scaduta per inattività'))
  }
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  const activeSocietaId = localStorage.getItem('societa_id')
  if (activeSocietaId) {
    config.headers['X-Societa-Id'] = activeSocietaId
  }
  recordActivity()
  return config
})

api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      localStorage.removeItem('societa_id')
      localStorage.removeItem('societa_data')
      localStorage.removeItem('utente_data')
      clearActivity()
      if (!window.location.pathname.includes('/login')) {
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

export const apiPublic = axios.create({ baseURL: getApiBaseUrl(), timeout: 15000 })

export function getUploadUrl(path) {
  if (!path) return ''
  if (path.startsWith('http://') || path.startsWith('https://')) return path
  let cleanPath = path.startsWith('/') ? path : `/${path}`
  if (!cleanPath.startsWith('/uploads/')) {
    cleanPath = `/uploads${cleanPath}`
  }
  if (Capacitor.isNativePlatform()) {
    return `https://thof.crickethouse.mywire.org${cleanPath}`
  }
  return cleanPath
}
