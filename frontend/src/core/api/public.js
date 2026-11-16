import { api, apiPublic } from './client'

// Il form d'iscrizione pubblico non si identifica piu' con l'ID della persona: quello era
// sequenziale, quindi chiunque poteva scorrere /persone/public/1, 2, 3... e leggere o
// sovrascrivere anagrafiche, indirizzi, email e anamnesi dei tesserati. Si usa ora un token
// di possesso coniato dalla segreteria (POST /persone/{id}/public-link), con scadenza e
// revocabile. Vedi backend/app/routers/persone.py.
export const getPublicPersonaByToken = (token) =>
  apiPublic.get(`/persone/public/by-token/${encodeURIComponent(token)}`)

export const updatePublicPersonaByToken = (token, data) =>
  apiPublic.put(`/persone/public/by-token/${encodeURIComponent(token)}`, data)

export const getPublicCategoria = (id) => apiPublic.get(`/persone/public/categoria/${id}`)

// La creazione resta pubblica (e' il link "nuova iscrizione" che il club condivide), ma la
// risposta porta il token con cui il form continuera' a salvare.
export const createPublicPersona = (data) => apiPublic.post('/persone/public/', data)

// Coniare o rigenerare un link e' un'operazione di segreteria: istanza autenticata.
export const generaLinkPubblico = (personaId) => api.post(`/persone/${personaId}/public-link`)
