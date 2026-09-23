import { apiPublic } from './client'

export const getPublicPersona = (id) => apiPublic.get(`/persone/public/${id}`)
export const getPublicCategoria = (id) => apiPublic.get(`/persone/public/categoria/${id}`)
export const updatePublicPersona = (id, data) => apiPublic.put(`/persone/public/${id}`, data)
export const createPublicPersona = (data) => apiPublic.post('/persone/public/', data)
