import { createApp } from 'vue'
import App from './App.vue'
import './global.css'
import { createRouter, createWebHistory } from 'vue-router'
import Home from './views/Home.vue'
import Registro from './views/Registro.vue'
import Login from './views/Login.vue'
import Admin from './views/Admin.vue'
import Scelta from './views/Scelta.vue'
import Convocazioni from './views/Convocazioni.vue'
import DatiMatricole from './views/DatiMatricole.vue'
import Allenamenti from './views/Allenamenti.vue'
import Societa from './views/Societa.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: Login },
    { path: '/', component: Home, meta: { requiresAuth: true } },
    { path: '/scelta/:id', component: Scelta, meta: { requiresAuth: true } },
    { path: '/registro/:id', component: Registro, meta: { requiresAuth: true } },
    { path: '/convocazioni/:id', component: Convocazioni, meta: { requiresAuth: true } },
    { path: '/dati/:id', component: DatiMatricole, meta: { requiresAuth: true } },
    { path: '/allenamenti/:id', component: Allenamenti, meta: { requiresAuth: true } },
    { path: '/admin', component: Admin, meta: { requiresAuth: true, requiresAdmin: true } },
    { path: '/admin/societa', component: Societa, meta: { requiresAuth: true } }
  ]
})

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  const isSuperAdmin = localStorage.getItem('is_super_admin') === 'true'
  if (to.meta.requiresAuth && !token) return next('/login')
  // SuperAdmin can go to /login to change society
  if (to.path === '/login' && token && !isSuperAdmin) return next('/')
  if (to.meta.requiresSuperAdmin) {
    if (!isSuperAdmin) return next('/')
  }
  // Check for requiresAdmin (allows both admin and super_admin)
  if (to.meta.requiresAdmin) {
    const isAdmin = localStorage.getItem('is_admin') === 'true' || isSuperAdmin
    if (!isAdmin) return next('/')
  }
  next()
})

createApp(App).use(router).mount('#app')
