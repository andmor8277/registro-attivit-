import { createRouter, createWebHistory } from 'vue-router'
import { useStore } from '../store.js'

const store = useStore()

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: () => import('../features/auth/Login.vue'), name: 'login' },
    { path: '/', component: () => import('../features/home/Home.vue'), name: 'home', meta: { requiresAuth: true } },
    { path: '/allenatori', component: () => import('../features/allenatori/Allenatori.vue'), name: 'allenatori', meta: { requiresAuth: true } },
    { path: '/responsabili', component: () => import('../features/allenatori/Responsabili.vue'), name: 'responsabili', meta: { requiresAuth: true } },
    { path: '/responsabili/categorie', component: () => import('../features/allenatori/ResponsabiliCategoria.vue'), name: 'responsabili-categorie', meta: { requiresAuth: true } },
    { path: '/responsabili/partite', component: () => import('../features/partite/ProgrammazionePartite.vue'), name: 'responsabili-partite', meta: { requiresAuth: true } },
    { path: '/responsabili/spogliatoi', component: () => import('../features/partite/Spogliatoi.vue'), name: 'responsabili-spogliatoi', meta: { requiresAuth: true } },
    { path: '/responsabili/presenze-allenatori', component: () => import('../features/allenatori/PresenzeAllenatori.vue'), name: 'responsabili-presenze-allenatori', meta: { requiresAuth: true } },
    { path: '/scelta/:id', component: () => import('../features/home/Scelta.vue'), name: 'scelta', meta: { requiresAuth: true } },
    { path: '/registro/:id', component: () => import('../features/presenze/Registro.vue'), name: 'registro', meta: { requiresAuth: true } },
    { path: '/convocazioni/:id', component: () => import('../features/partite/Convocazioni.vue'), name: 'convocazioni', meta: { requiresAuth: true } },
    { path: '/dati/:id', component: () => import('../features/segreteria/DatiMatricole.vue'), name: 'dati-matricole', meta: { requiresAuth: true } },
    { path: '/liste-tornei/:id', component: () => import('../features/partite/ListeTornei.vue'), name: 'liste-tornei', meta: { requiresAuth: true } },
    { path: '/allenamenti/:id', component: () => import('../features/allenamenti/Allenamenti.vue'), name: 'allenamenti', meta: { requiresAuth: true } },
    { path: '/scheda-allenamento/:id', component: () => import('../features/allenamenti/SchedaAllenamento.vue'), name: 'scheda-allenamento', meta: { requiresAuth: true } },
    { path: '/admin', component: () => import('../features/admin/Admin.vue'), name: 'admin', meta: { requiresAuth: true, requiresSuperAdmin: true } },
    { path: '/admin/societa', component: () => import('../features/admin/Societa.vue'), name: 'societa', meta: { requiresAuth: true } },
    { path: '/reportistica/:id', component: () => import('../features/reportistica/Reportistica.vue'), name: 'reportistica', meta: { requiresAuth: true } },
    { path: '/segreteria', component: () => import('../features/segreteria/Segreteria.vue'), name: 'segreteria', meta: { requiresAuth: true } },
    { path: '/segreteria/scheda/:id', component: () => import('../features/segreteria/SchedaGiocatore.vue'), name: 'scheda-giocatore', meta: { requiresAuth: true } },
    { path: '/segreteria/:id', component: () => import('../features/segreteria/SegreteriaCategoria.vue'), name: 'segreteria-categoria', meta: { requiresAuth: true } },
    { path: '/valutazioni/:id', component: () => import('../features/segreteria/Valutazioni.vue'), name: 'valutazioni', meta: { requiresAuth: true } },
    { path: '/infermeria', component: () => import('../features/infermeria/Infermeria.vue'), name: 'infermeria', meta: { requiresAuth: true } },
    { path: '/infermeria/certificati', component: () => import('../features/infermeria/CertificatoMedico.vue'), name: 'certificati', meta: { requiresAuth: true } },
    { path: '/infermeria/infortunati', component: () => import('../features/infermeria/Infortunati.vue'), name: 'infortunati', meta: { requiresAuth: true } },
    { path: '/segreteria/openday', component: () => import('../features/segreteria/Openday.vue'), name: 'openday', meta: { requiresAuth: true } },
    { path: '/segreteria/presenze', component: () => import('../features/segreteria/PresenzeSegreteria.vue'), name: 'presenze-segreteria', meta: { requiresAuth: true } },
    { path: '/form-iscrizione', component: () => import('../features/auth/FormOnlineIscrizione.vue'), name: 'form-iscrizione' },
    { path: '/registrazione', component: () => import('../features/auth/Registrazione.vue'), name: 'registrazione' }
  ]
})

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  const user = store.utenteAttivo.value
  const isSuperAdmin = user?.is_super_admin || user?.ruolo === 'super_admin'
  if (to.meta.requiresAuth && !token) return next('/login')
  if (to.path === '/login' && token && !isSuperAdmin && !to.query.selezione && !to.query.invito) return next('/')
  if (to.meta.requiresSuperAdmin) {
    if (!isSuperAdmin) return next('/')
  }
  if (to.meta.requiresAdmin) {
    const isAdmin = user?.is_admin || user?.ruolo === 'admin' || isSuperAdmin
    if (!isAdmin) return next('/')
  }
  if (to.path === '/') {
    if (user?.ruolo === 'segreteria') return next('/segreteria')
    if (user?.ruolo === 'infermeria') return next('/infermeria')
  }
  if (to.path === '/allenatori') {
    if (user?.ruolo === 'mister' || user?.ruolo === 'dirigente') return next('/')
  }
  next()
})
