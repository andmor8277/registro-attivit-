import axios from 'axios'
import { Capacitor } from '@capacitor/core'

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
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      localStorage.removeItem('societa_id')
      localStorage.removeItem('societa_data')
      if (!window.location.pathname.includes('/login')) {
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

export const apiPublic = axios.create({ baseURL: getApiBaseUrl(), timeout: 15000 })
