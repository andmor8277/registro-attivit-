import { createRouter, createWebHistory } from 'vue-router'
import { useStore } from '../store.js'
import { getMe } from './api/auth.js'
import { isSessionExpired, clearActivity, recordActivity } from '../composables/useInactivity.js'

const store = useStore()

const RUOLI = {
  segreteria: ['segreteria', 'admin', 'super_admin'],
  infermeria: ['infermeria', 'segreteria', 'admin', 'super_admin'],
  scouting: ['scouting', 'admin', 'super_admin'],
  responsabili: ['admin', 'super_admin'],
  gestioneSquadre: ['admin', 'super_admin'],
  admin: ['admin', 'super_admin'],
  superAdmin: ['super_admin']
}

let userPromise = null

export async function caricaUtente(force = false) {
  if (!force && store.utenteAttivo.value) return store.utenteAttivo.value
  if (!localStorage.getItem('token')) return null
  if (!userPromise) {
    userPromise = (async () => {
      let lastErr = null
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          const res = await getMe()
          store.setUtenteAttivo(res.data)
          return res.data
        } catch (err) {
          lastErr = err
          if (err.response?.status === 401) {
            throw err
          }
          if (attempt === 0) {
            await new Promise(r => setTimeout(r, 600))
          }
        }
      }
      throw lastErr
    })().finally(() => {
      userPromise = null
    })
  }
  return userPromise
}

function haRuolo(user, roles = []) {
  if (!roles || roles.length === 0) return true
  if (!user) return false
  const isSuperAdmin = user.is_super_admin || user.ruolo === 'super_admin'
  if (isSuperAdmin && roles.includes('super_admin')) return true
  if (user.is_admin && roles.includes('admin')) return true
  if (user.ruolo && roles.includes(user.ruolo)) return true
  return false
}

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: () => import('../features/auth/Login.vue'), name: 'login' },
    { path: '/', component: () => import('../features/home/Home.vue'), name: 'home', meta: { requiresAuth: true } },
    { path: '/allenatori', component: () => import('../features/allenatori/Allenatori.vue'), name: 'allenatori', meta: { requiresAuth: true, roles: RUOLI.gestioneSquadre } },
    { path: '/responsabili', component: () => import('../features/allenatori/Responsabili.vue'), name: 'responsabili', meta: { requiresAuth: true, roles: RUOLI.responsabili } },
    { path: '/responsabili/categorie', component: () => import('../features/allenatori/ResponsabiliCategoria.vue'), name: 'responsabili-categorie', meta: { requiresAuth: true, roles: RUOLI.responsabili } },
    { path: '/responsabili/partite', component: () => import('../features/partite/ProgrammazionePartite.vue'), name: 'responsabili-partite', meta: { requiresAuth: true, roles: RUOLI.responsabili } },
    { path: '/responsabili/spogliatoi', component: () => import('../features/partite/Spogliatoi.vue'), name: 'responsabili-spogliatoi', meta: { requiresAuth: true, roles: RUOLI.responsabili } },
    { path: '/responsabili/presenze-allenatori', component: () => import('../features/allenatori/PresenzeAllenatori.vue'), name: 'responsabili-presenze-allenatori', meta: { requiresAuth: true, roles: RUOLI.responsabili } },
    { path: '/scelta/:id', component: () => import('../features/home/Scelta.vue'), name: 'scelta', meta: { requiresAuth: true } },
    { path: '/registro/:id', component: () => import('../features/presenze/Registro.vue'), name: 'registro', meta: { requiresAuth: true } },
    { path: '/convocazioni/:id', component: () => import('../features/partite/Convocazioni.vue'), name: 'convocazioni', meta: { requiresAuth: true } },
    { path: '/dati/:id', component: () => import('../features/segreteria/DatiMatricole.vue'), name: 'dati-matricole', meta: { requiresAuth: true } },
    { path: '/liste-tornei/:id', component: () => import('../features/partite/ListeTornei.vue'), name: 'liste-tornei', meta: { requiresAuth: true } },
    { path: '/allenamenti/:id', component: () => import('../features/allenamenti/Allenamenti.vue'), name: 'allenamenti', meta: { requiresAuth: true } },
    { path: '/scheda-allenamento/:id', component: () => import('../features/allenamenti/SchedaAllenamento.vue'), name: 'scheda-allenamento', meta: { requiresAuth: true } },
    { path: '/admin', component: () => import('../features/admin/Admin.vue'), name: 'admin', meta: { requiresAuth: true, roles: RUOLI.superAdmin } },
    { path: '/admin/societa', component: () => import('../features/admin/Societa.vue'), name: 'societa', meta: { requiresAuth: true, roles: RUOLI.admin } },
    { path: '/reportistica/:id', component: () => import('../features/reportistica/Reportistica.vue'), name: 'reportistica', meta: { requiresAuth: true } },
    { path: '/segreteria', component: () => import('../features/segreteria/Segreteria.vue'), name: 'segreteria', meta: { requiresAuth: true, roles: RUOLI.segreteria } },
    { path: '/segreteria/scheda/:id', component: () => import('../features/segreteria/SchedaGiocatore.vue'), name: 'scheda-giocatore', meta: { requiresAuth: true, roles: RUOLI.segreteria } },
    { path: '/segreteria/:id', component: () => import('../features/segreteria/SegreteriaCategoria.vue'), name: 'segreteria-categoria', meta: { requiresAuth: true, roles: RUOLI.segreteria } },
    { path: '/valutazioni/:id', component: () => import('../features/segreteria/Valutazioni.vue'), name: 'valutazioni', meta: { requiresAuth: true } },
    { path: '/infermeria', component: () => import('../features/infermeria/Infermeria.vue'), name: 'infermeria', meta: { requiresAuth: true, roles: RUOLI.infermeria } },
    { path: '/infermeria/certificati', component: () => import('../features/infermeria/CertificatoMedico.vue'), name: 'certificati', meta: { requiresAuth: true, roles: RUOLI.infermeria } },
    { path: '/infermeria/infortunati', component: () => import('../features/infermeria/Infortunati.vue'), name: 'infortunati', meta: { requiresAuth: true, roles: RUOLI.infermeria } },
    { path: '/scouting', component: () => import('../features/scouting/Scouting.vue'), name: 'scouting', meta: { requiresAuth: true, roles: RUOLI.scouting } },
    { path: '/segreteria/openday', component: () => import('../features/segreteria/Openday.vue'), name: 'openday', meta: { requiresAuth: true, roles: RUOLI.segreteria } },
    { path: '/segreteria/presenze', component: () => import('../features/segreteria/PresenzeSegreteria.vue'), name: 'presenze-segreteria', meta: { requiresAuth: true, roles: RUOLI.segreteria } },
    { path: '/form-iscrizione', component: () => import('../features/auth/FormOnlineIscrizione.vue'), name: 'form-iscrizione' },
    { path: '/registrazione', component: () => import('../features/auth/Registrazione.vue'), name: 'registrazione' }
  ]
})

router.beforeEach(async (to, from, next) => {
  const token = localStorage.getItem('token')

  if (token && isSessionExpired()) {
    store.clearToken()
    clearActivity()
    return next('/login?session_expired=1')
  }

  if (token) {
    recordActivity()
  }

  let user = store.utenteAttivo.value
  const isSuperAdmin = user?.is_super_admin || user?.ruolo === 'super_admin'

  if (to.meta.requiresAuth && !token) return next('/login')
  if (to.path === '/login' && token && !isSuperAdmin && !to.query.selezione && !to.query.invito) return next('/')

  if (to.meta.requiresAuth && token && !user) {
    try {
      user = await caricaUtente()
    } catch (err) {
      if (err?.response?.status === 401) {
        store.clearToken()
        return next('/login')
      }
      // Se è un errore di rete o temporaneo e abbiamo utente in cache, usalo
      if (store.utenteAttivo.value) {
        user = store.utenteAttivo.value
      } else {
        return next('/login')
      }
    }
  }

  if (!haRuolo(user, to.meta.roles)) return next('/')

  if (to.path === '/') {
    if (user?.ruolo === 'segreteria') return next('/segreteria')
    if (user?.ruolo === 'infermeria') return next('/infermeria')
    if (user?.ruolo === 'scouting') return next('/scouting')
  }

  next()
})
