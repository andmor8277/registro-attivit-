import { createApp } from 'vue'
import App from './App.vue'
import './global.css'
import { createRouter, createWebHistory } from 'vue-router'
import { useStore } from './store.js'
import Home from './views/Home.vue'
import Registro from './views/Registro.vue'
import Login from './views/Login.vue'
import Admin from './views/Admin.vue'
import Scelta from './views/Scelta.vue'
import Convocazioni from './views/Convocazioni.vue'
import DatiMatricole from './views/DatiMatricole.vue'
import Allenamenti from './views/Allenamenti.vue'
import Allenatori from './views/Allenatori.vue'
import Societa from './views/Societa.vue'
import Reportistica from './views/Reportistica.vue'
import Segreteria from './views/Segreteria.vue'
import SegreteriaCategoria from './views/SegreteriaCategoria.vue'
import SchedaGiocatore from './views/SchedaGiocatore.vue'
import FormOnlineIscrizione from './views/FormOnlineIscrizione.vue'
import Responsabili from './views/Responsabili.vue'
import ResponsabiliCategoria from './views/ResponsabiliCategoria.vue'
import ProgrammazionePartite from './views/ProgrammazionePartite.vue'
import Spogliatoi from './views/Spogliatoi.vue'
import PresenzeAllenatori from './views/PresenzeAllenatori.vue'
import Valutazioni from './views/Valutazioni.vue'
import Infermeria from './views/Infermeria.vue'
import CertificatoMedico from './views/CertificatoMedico.vue'
import Infortunati from './views/Infortunati.vue'
import Openday from './views/Openday.vue'
import SchedaAllenamento from './views/SchedaAllenamento.vue'

const store = useStore()

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: Login, name: 'login' },
    { path: '/', component: Home, name: 'home', meta: { requiresAuth: true } },
    { path: '/allenatori', component: Allenatori, name: 'allenatori', meta: { requiresAuth: true } },
    { path: '/responsabili', component: Responsabili, name: 'responsabili', meta: { requiresAuth: true } },
    { path: '/responsabili/categorie', component: ResponsabiliCategoria, name: 'responsabili-categorie', meta: { requiresAuth: true } },
    { path: '/responsabili/partite', component: ProgrammazionePartite, name: 'responsabili-partite', meta: { requiresAuth: true } },
    { path: '/responsabili/spogliatoi', component: Spogliatoi, name: 'responsabili-spogliatoi', meta: { requiresAuth: true } },
    { path: '/responsabili/presenze-allenatori', component: PresenzeAllenatori, name: 'responsabili-presenze-allenatori', meta: { requiresAuth: true } },
    { path: '/scelta/:id', component: Scelta, name: 'scelta', meta: { requiresAuth: true } },
    { path: '/registro/:id', component: Registro, name: 'registro', meta: { requiresAuth: true } },
    { path: '/convocazioni/:id', component: Convocazioni, name: 'convocazioni', meta: { requiresAuth: true } },
    { path: '/dati/:id', component: DatiMatricole, name: 'dati-matricole', meta: { requiresAuth: true } },
    { path: '/allenamenti/:id', component: Allenamenti, name: 'allenamenti', meta: { requiresAuth: true } },
    { path: '/scheda-allenamento/:id', component: SchedaAllenamento, name: 'scheda-allenamento', meta: { requiresAuth: true } },
    { path: '/admin', component: Admin, name: 'admin', meta: { requiresAuth: true, requiresAdmin: true } },
    { path: '/admin/societa', component: Societa, name: 'societa', meta: { requiresAuth: true } },
    { path: '/reportistica/:id', component: Reportistica, name: 'reportistica', meta: { requiresAuth: true } },
    { path: '/segreteria', component: Segreteria, name: 'segreteria', meta: { requiresAuth: true } },
    { path: '/segreteria/scheda/:id', component: SchedaGiocatore, name: 'scheda-giocatore', meta: { requiresAuth: true } },
    { path: '/segreteria/:id', component: SegreteriaCategoria, name: 'segreteria-categoria', meta: { requiresAuth: true } },
    { path: '/valutazioni/:id', component: Valutazioni, name: 'valutazioni', meta: { requiresAuth: true } },
    { path: '/infermeria', component: Infermeria, name: 'infermeria', meta: { requiresAuth: true } },
    { path: '/infermeria/certificati', component: CertificatoMedico, name: 'certificati', meta: { requiresAuth: true } },
    { path: '/infermeria/infortunati', component: Infortunati, name: 'infortunati', meta: { requiresAuth: true } },
    { path: '/segreteria/openday', component: Openday, name: 'openday', meta: { requiresAuth: true } },
    { path: '/form-iscrizione', component: FormOnlineIscrizione, name: 'form-iscrizione' }
  ]
})

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  const user = store.utenteAttivo.value
  const isSuperAdmin = user?.is_super_admin || user?.ruolo === 'super_admin'
  if (to.meta.requiresAuth && !token) return next('/login')
  if (to.path === '/login' && token && !isSuperAdmin && !to.query.selezione) return next('/')
  if (to.meta.requiresSuperAdmin) {
    if (!isSuperAdmin) return next('/')
  }
  if (to.meta.requiresAdmin) {
    const isAdmin = user?.is_admin || user?.ruolo === 'admin' || isSuperAdmin
    if (!isAdmin) return next('/')
  }
  // Redirect diretto da home per ruoli specifici
  if (to.path === '/') {
    if (user?.ruolo === 'mister') return next('/allenatori')
    if (user?.ruolo === 'segreteria') return next('/segreteria')
    if (user?.ruolo === 'infermeria') return next('/infermeria')
  }
  next()
})

createApp(App).use(router).mount('#app')
