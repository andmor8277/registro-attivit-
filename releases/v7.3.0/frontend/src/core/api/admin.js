import { api } from './client'

export const getSocieta = () => api.get('/societa/')
export const getSocietaById = (id) => api.get('/societa/' + id)
export const createSocieta = (data) => api.post('/societa/', data)
export const updateSocieta = (id, data) => api.put(`/societa/${id}`, data)
export const deleteSocieta = (id) => api.delete(`/societa/${id}`)
export const uploadSocietaFile = (tipo, file) => {
  const formData = new FormData()
  formData.append('file', file)
  return api.post(`/societa/upload/${tipo}`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })
}
