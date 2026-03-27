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
    { path: '/admin', component: Admin, meta: { requiresAuth: true, requiresAdmin: true } }
  ]
})

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  if (to.meta.requiresAuth && !token) return next('/login')
  if (to.path === '/login' && token) return next('/')
  next()
})

createApp(App).use(router).mount('#app')
