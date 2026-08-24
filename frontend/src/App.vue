<template>
  <div class="app-layout">
    <aside v-if="token && !hideTopbar" class="sidebar">
      <div class="brand">
        <img v-if="societaAttiva?.logo" :src="`/uploads/${societaAttiva.logo}`" :alt="societaAttiva.nome" class="logo-img" />
        <span v-else class="mark">{{ (societaAttiva?.nome_breve || societaAttiva?.nome || 'TH').slice(0, 2).toUpperCase() }}</span>
        <div class="brand-txt">
          <b>{{ societaAttiva?.nome_breve || societaAttiva?.nome || 'THOF' }}</b>
          <small>The Home of Football</small>
        </div>
      </div>

      <nav class="sidebar-nav">
        <div class="nav-label">Operativo</div>
        <router-link to="/" class="side-item" :class="{ active: isActive(['/']) }">
          <svg viewBox="0 0 24 24"><path d="M3 10.5L12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/></svg>
          <span>Panoramica</span>
        </router-link>
        <button class="side-item" :class="{ active: isActive(['/scelta', '/registro', '/dati', '/scheda-allenamento']) }" @click="vaiPaginaCategoria('scelta')">
          <svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="17" rx="2"/><path d="M3 9h18M8 2v4M16 2v4"/></svg>
          <span>Presenze</span>
        </button>
        <button class="side-item" :class="{ active: isActive(['/convocazioni']) }" @click="vaiPaginaCategoria('convocazioni')">
          <svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h10"/></svg>
          <span>Convocazioni</span>
        </button>
        <button class="side-item" :class="{ active: isActive(['/allenamenti']) }" @click="vaiPaginaCategoria('allenamenti')">
          <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 3v18M3 12h18"/></svg>
          <span>Allenamenti</span>
        </button>
        <router-link v-if="canInfermeria" to="/infermeria" class="side-item" :class="{ active: isActive(['/infermeria']) }">
          <svg viewBox="0 0 24 24"><path d="M12 21C7 17 3 13.5 3 9.5A5.5 5.5 0 0113.6 6H12a5.5 5.5 0 018 3.5c0 4-4 7.5-8 11.5z"/></svg>
          <span>Infermeria</span>
          <span v-if="infortuniCount > 0" class="badge">{{ infortuniCount }}</span>
        </router-link>
        <router-link v-if="canSegreteria" to="/segreteria" class="side-item" :class="{ active: isActive(['/segreteria']) }">
          <svg viewBox="0 0 24 24"><path d="M17 2H7a2 2 0 00-2 2v16a2 2 0 002 2h10a2 2 0 002-2V4a2 2 0 00-2-2z"/><path d="M9 8h6M9 12h6M9 16h3"/></svg>
          <span>Segreteria</span>
        </router-link>

        <div class="nav-label">Amministrazione</div>
        <router-link to="/allenatori" class="side-item" :class="{ active: isActive(['/allenatori']) }">
          <svg viewBox="0 0 24 24"><circle cx="9" cy="8" r="3.2"/><path d="M3.5 20c0-3 2.5-5 5.5-5s5.5 2 5.5 5"/><circle cx="17" cy="9" r="2.5"/><path d="M15.5 15.3c2.7.4 4.5 2.2 4.5 4.7"/></svg>
          <span>Squadre e ruoli</span>
        </router-link>
        <router-link v-if="isAdminUtente && !isSuperAdmin" to="/responsabili" class="side-item" :class="{ active: isActive(['/responsabili']) }">
          <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/></svg>
          <span>Responsabili</span>
        </router-link>
        <button v-if="isSuperAdmin" class="side-item" @click="vaiSelezioneSocieta">
          <svg viewBox="0 0 24 24"><path d="M7 16V4m0 0L3 8m4-4l4 4"/><path d="M17 8v12m0 0l4-4m-4 4l-4-4"/></svg>
          <span>Cambia societ&agrave;</span>
        </button>
        <router-link v-if="isAdminUtente || isSuperAdmin" to="/admin" class="side-item" :class="{ active: isActive(['/admin']) }">
          <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 11-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 11-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 11-2.83-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 110-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 112.83-2.83l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 114 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 112.83 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 110 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>
          <span>Impostazioni</span>
        </router-link>
      </nav>

      <div class="side-footer">
        <span class="season-pill" :class="{ off: !stagioneCorrente }">Stagione {{ stagioneCorrente ? `${stagioneCorrente}/${stagioneCorrente + 1}` : 'n.d.' }}</span>
        <button class="user-chip" @click="showPasswordModal = true" title="Cambia password">
          <span class="user-avatar">{{ (utenteAttivo?.cognome || utenteAttivo?.username || '?').slice(0, 2).toUpperCase() }}</span>
          <span class="nm">
            <b>{{ utenteAttivo?.cognome || utenteAttivo?.username }}</b>
            <span>{{ ruoloLabel }}</span>
          </span>
        </button>
        <div class="side-mini">
          <a href="/guida.html" target="_blank" rel="noopener,noreferrer" class="mini-btn" title="Guida Utente">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
          </a>
          <button v-if="!isSuperAdmin && societaAttiva" class="mini-btn" title="Modifica Societ&agrave;" @click="modificaSocietaAttiva">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
          </button>
          <button class="mini-btn danger" title="Esci" @click="logout">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
          </button>
        </div>
      </div>
    </aside>


    <div class="main-col">
    <nav v-if="token && !hideTopbar" class="topbar">
      <button class="hamburger" @click="mobileMenuOpen = true; window.scrollTo(0, 0)" aria-label="Menu">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="3" y1="6" x2="21" y2="6"/>
          <line x1="3" y1="12" x2="21" y2="12"/>
          <line x1="3" y1="18" x2="21" y2="18"/>
        </svg>
      </button>
      <div class="topbar-brand">
        <img v-if="societaAttiva?.logo" :src="`/uploads/${societaAttiva.logo}`" :alt="societaAttiva.nome" class="logo-img" />
        <span class="brand-text">{{ societaAttiva?.nome_breve || societaAttiva?.nome || 'Società' }}</span>
      </div>
      <div class="topbar-season" :class="{ empty: !stagioneCorrente }">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/>
          <path d="M12 6v6l4 2"/>
        </svg>
        <span>{{ stagioneCorrente ? `${stagioneCorrente}/${stagioneCorrente + 1}` : 'Stagione non impostata' }}</span>
      </div>
      <div class="topbar-actions">
        <span class="user-badge">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="8" r="4"/>
            <path d="M4 20c0-4 4-6 8-6s8 2 8 6"/>
          </svg>
          {{ utenteAttivo?.cognome || utenteAttivo?.username }}
        </span>
        <router-link v-if="!isSuperAdmin" to="/" class="btn-nav">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
          <span>Home</span>
        </router-link>
        <button v-else @click="vaiSelezioneSocieta" class="btn-nav">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
          <span>Home</span>
        </button>
        <a href="/guida.html" target="_blank" rel="noopener,noreferrer" class="btn-nav btn-guida" title="Guida Utente">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
            <polyline points="14 2 14 8 20 8"/>
            <line x1="16" y1="13" x2="8" y2="13"/>
            <line x1="16" y1="17" x2="8" y2="17"/>
            <polyline points="10 9 9 9 8 9"/>
          </svg>
          <span>Guida</span>
        </a>
        <button @click="logout" class="btn-logout">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/>
            <polyline points="16 17 21 12 16 7"/>
            <line x1="21" y1="12" x2="9" y2="12"/>
          </svg>
          <span>Esci</span>
        </button>
        <button @click="showPasswordModal = true" class="btn-nav">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
            <path d="M7 11V7a5 5 0 0110 0v4"/>
          </svg>
          Password
        </button>
        <button v-if="!isSuperAdmin && societaAttiva" @click="modificaSocietaAttiva" class="btn-nav">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
            <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
          </svg>
          Modifica Società
        </button>
      </div>
    </nav>

    <div v-if="mobileMenuOpen" class="mobile-menu-overlay" @click="mobileMenuOpen = false">
      <div class="mobile-menu" @click.stop>
        <div class="mobile-menu-header">
          <span>{{ societaAttiva?.nome_breve || societaAttiva?.nome || 'Menu' }}</span>
          <button class="mobile-menu-close" @click="mobileMenuOpen = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
        <div class="mobile-menu-content">
          <span class="user-badge">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="8" r="4"/>
              <path d="M4 20c0-4 4-6 8-6s8 2 8 6"/>
            </svg>
            {{ utenteAttivo?.cognome || utenteAttivo?.username }}
          </span>
          <router-link v-if="!isSuperAdmin" to="/" class="mobile-menu-item" @click="mobileMenuOpen = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
              <polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
            Home
          </router-link>
          <button v-else @click="vaiSelezioneSocieta(); mobileMenuOpen = false" class="mobile-menu-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
              <polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
            Home
          </button>
          <button @click="showPasswordModal = true; mobileMenuOpen = false" class="mobile-menu-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
              <path d="M7 11V7a5 5 0 0110 0v4"/>
            </svg>
            Password
          </button>
          <button v-if="!isSuperAdmin && societaAttiva" @click="modificaSocietaAttiva(); mobileMenuOpen = false" class="mobile-menu-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
            Modifica Società
          </button>
          <a href="/guida.html" target="_blank" rel="noopener,noreferrer" class="mobile-menu-item" @click="mobileMenuOpen = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
              <polyline points="14 2 14 8 20 8"/>
              <line x1="16" y1="13" x2="8" y2="13"/>
              <line x1="16" y1="17" x2="8" y2="17"/>
              <polyline points="10 9 9 9 8 9"/>
            </svg>
            Guida
          </a>
          <button @click="logout" class="mobile-menu-item mobile-menu-logout">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/>
              <polyline points="16 17 21 12 16 7"/>
              <line x1="21" y1="12" x2="9" y2="12"/>
            </svg>
            Esci
          </button>
        </div>
      </div>
    </div>

    <main class="main-content">
      <router-view />
    </main>
    </div>

    <nav v-if="token && !hideTopbar" class="bottom-nav">
      <router-link v-if="!isSuperAdmin" to="/" class="bottom-nav-item" :class="{ active: route.path === '/' }">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
          <polyline points="9 22 9 12 15 12 15 22"/>
        </svg>
        <span>Home</span>
      </router-link>
      <button v-else class="bottom-nav-item" @click="vaiSelezioneSocieta">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
          <polyline points="9 22 9 12 15 12 15 22"/>
        </svg>
        <span>Home</span>
      </button>
      <a href="/guida.html" target="_blank" rel="noopener,noreferrer" class="bottom-nav-item">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
          <polyline points="14 2 14 8 20 8"/>
          <line x1="16" y1="13" x2="8" y2="13"/>
          <line x1="16" y1="17" x2="8" y2="17"/>
          <polyline points="10 9 9 9 8 9"/>
        </svg>
        <span>Guida</span>
      </a>
      <button @click="mobileMenuOpen = true" class="bottom-nav-item">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="3" y1="6" x2="21" y2="6"/>
          <line x1="3" y1="12" x2="21" y2="12"/>
          <line x1="3" y1="18" x2="21" y2="18"/>
        </svg>
        <span>Menu</span>
      </button>
    </nav>

    <Teleport to="body">
      <div v-if="showPasswordModal" class="modal-overlay" @click.self="showPasswordModal = false">
        <div class="modal">
          <div class="modal-header">
            <h3>Cambia Password</h3>
            <button class="modal-close" @click="showPasswordModal = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Password Attuale</label>
              <input v-model="passwordForm.attuale" type="password" placeholder="Inserisci password attuale" />
            </div>
            <div class="form-group">
              <label>Nuova Password</label>
              <input v-model="passwordForm.nuova" type="password" placeholder="Inserisci nuova password" />
            </div>
            <div class="form-group">
              <label>Conferma Password</label>
              <input v-model="passwordForm.conferma" type="password" placeholder="Conferma nuova password" />
            </div>
            <p v-if="passwordErrore" class="errore-msg">{{ passwordErrore }}</p>
            <p v-if="passwordSuccess" class="success-msg">{{ passwordSuccess }}</p>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="showPasswordModal = false">Annulla</button>
            <button class="btn-primary" @click="cambiaPassword" :disabled="passwordLoading">
              <span v-if="passwordLoading" class="spinner-small"></span>
              <template v-else>Salva</template>
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useStore } from './store.js'
import { useRouter, useRoute } from 'vue-router'
import { getMe, getStagioni, changePassword, getInfortuni } from './api/index.js'

const { token, utenteAttivo, clearToken, setStagioneCorrente, stagioneCorrente, societaAttiva, setSocietaAttiva, hideTopbar, categoriaAttiva } = useStore()
const router = useRouter()
const route = useRoute()

const showPasswordModal = ref(false)
const passwordForm = ref({ attuale: '', nuova: '', conferma: '' })
const passwordErrore = ref('')
const passwordSuccess = ref('')
const passwordLoading = ref(false)
const isSuperAdmin = computed(() => utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin')
const isAdminUtente = computed(() => !!utenteAttivo.value?.is_admin)
const canSegreteria = computed(() => utenteAttivo.value?.ruolo === 'segreteria' || isAdminUtente.value || isSuperAdmin.value)
const canInfermeria = computed(() => ['infermeria', 'admin', 'super_admin'].includes(utenteAttivo.value?.ruolo))
const infortuniCount = ref(0)

function vaiPaginaCategoria(base) {
  if (categoriaAttiva.value?.id) router.push('/' + base + '/' + categoriaAttiva.value.id)
  else router.push('/allenatori')
}
const ruoloLabel = computed(() => {
  if (isSuperAdmin.value) return 'Super Admin'
  const r = utenteAttivo.value?.ruolo
  return r ? r.charAt(0).toUpperCase() + r.slice(1) : ''
})
const mobileMenuOpen = ref(false)

function isActive(prefixes) {
  const path = route.path
  return prefixes.some(p => p === '/' ? path === '/' : path.startsWith(p))
}

function vaiSelezioneSocieta() {
  router.push('/login?selezione=societa')
}

function modificaSocietaAttiva() {
  router.push({ path: '/admin/societa', query: { id: societaAttiva.value.id } })
}

async function cambiaPassword() {
  passwordErrore.value = ''
  passwordSuccess.value = ''
  
  if (!passwordForm.value.attuale || !passwordForm.value.nuova || !passwordForm.value.conferma) {
    passwordErrore.value = 'Compila tutti i campi'
    return
  }
  
  if (passwordForm.value.nuova !== passwordForm.value.conferma) {
    passwordErrore.value = 'Le password non coincidono'
    return
  }
  
  if (passwordForm.value.nuova.length < 4) {
    passwordErrore.value = 'La password deve essere di almeno 4 caratteri'
    return
  }
  
  passwordLoading.value = true
  
  try {
    await changePassword(utenteAttivo.value.id, passwordForm.value.attuale, passwordForm.value.nuova)
    passwordSuccess.value = 'Password cambiata con successo!'
    passwordForm.value = { attuale: '', nuova: '', conferma: '' }
    setTimeout(() => {
      showPasswordModal.value = false
      passwordSuccess.value = ''
    }, 2000)
  } catch (e) {
    passwordErrore.value = e.response?.data?.detail || 'Errore nel cambio password'
  } finally {
    passwordLoading.value = false
  }
}

async function logout() {
  clearToken()
  router.push('/login')
}

async function loadStagione() {
  try {
    const res = await getStagioni(societaAttiva.value?.id || null)
    const stagioniAttive = res.data?.attiva || []
    if (stagioniAttive.length > 0) {
      setStagioneCorrente(stagioniAttive[0])
    } else {
      setStagioneCorrente(null)
    }
  } catch (e) {
    console.error('Errore nel caricamento stagione:', e)
    setStagioneCorrente(null)
  }
}

onMounted(async () => {
  if (token.value) {
    try {
      const res = await getMe()
      utenteAttivo.value = res.data
      await loadStagione()
    } catch {
      clearToken()
      router.push('/login')
    }
  }

  if (token.value && canInfermeria.value) {
    try {
      const res = await getInfortuni({ attivi: true })
      infortuniCount.value = Array.isArray(res.data) ? res.data.length : 0
    } catch { infortuniCount.value = 0 }
  }
})

watch(societaAttiva, async (newVal) => {
  if (newVal?.id) {
    await loadStagione()
  } else {
    setStagioneCorrente(null)
  }
})
</script>

<style scoped>
.app-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  overflow-x: hidden;
}

.topbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.6rem 1rem;
  background: var(--color-surface);
  color: var(--color-text);
  border-bottom: 1px solid var(--color-border);
  position: sticky;
  top: 0;
  z-index: 100;
}

.topbar-brand {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.logo-img {
  height: 42px;
  width: auto;
  object-fit: contain;
}

.brand-text {
  font-size: 1.25rem;
  font-weight: 800;
  letter-spacing: -0.01em;
  color: var(--color-text);
  font-family: var(--font-sans);
}

.brand-red {
  color: #dc2626;
}

.sidebar-season,
.topbar-season {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.35rem 0.85rem;
  background: rgba(220, 38, 38, 0.07);
  border: 1px solid rgba(220, 38, 38, 0.22);
  border-radius: 50px;
  font-size: 0.8125rem;
  font-weight: 700;
  color: var(--color-primary);
}

.sidebar-season.empty,
.topbar-season.empty {
  background: var(--color-bg);
  border-color: var(--color-border);
  color: var(--color-text-muted);
}

.sidebar-season svg,
.topbar-season svg {
  width: 15px;
  height: 15px;
}

.topbar-season svg {
  width: 16px;
  height: 16px;
}

.topbar-actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.user-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: var(--color-bg);
  border-radius: 50px;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  border: 1px solid var(--color-border);
}

.user-badge svg {
  width: 18px;
  height: 18px;
}

.btn-nav {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.45rem 0.9rem;
  background: transparent;
  border: 1px solid var(--color-border);
  border-radius: 50px;
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  font-weight: 600;
  transition: all var(--transition-base);
  cursor: pointer;
}

.btn-nav:hover {
  background: var(--color-bg);
  color: var(--color-text);
}

.btn-nav.btn-admin {
  background: rgba(220, 38, 38, 0.2);
  border-color: rgba(220, 38, 38, 0.4);
}

.btn-nav.btn-admin:hover {
  background: rgba(220, 38, 38, 0.35);
}

.btn-nav.btn-guida {
  background: rgba(34, 197, 94, 0.15);
  border-color: rgba(34, 197, 94, 0.35);
}

.btn-nav.btn-guida:hover {
  background: rgba(34, 197, 94, 0.3);
}

.btn-nav svg {
  width: 16px;
  height: 16px;
}

.btn-logout {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.45rem 1rem;
  background: transparent;
  border: 1px solid var(--color-border);
  border-radius: 50px;
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  font-weight: 600;
  transition: all var(--transition-base);
  cursor: pointer;
}

.btn-logout:hover {
  background: rgba(220, 38, 38, 0.08);
  border-color: rgba(220, 38, 38, 0.4);
  color: var(--color-primary);
}

.btn-logout svg {
  width: 16px;
  height: 16px;
}

/* ── Sidebar fissa stile demo ── */
.sidebar {
  position: fixed;
  left: 0;
  top: 0;
  bottom: 0;
  width: 236px;
  background: var(--color-surface);
  border-right: 1px solid var(--color-border);
  display: none;
  flex-direction: column;
  padding: 18px 14px 14px;
  gap: 4px;
  z-index: 120;
  overflow-y: auto;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 4px 8px 16px;
}

.brand .logo-img {
  height: 36px;
  width: 36px;
  max-width: 36px;
  object-fit: contain;
  border-radius: 10px;
  flex-shrink: 0;
}

.mark {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  background: var(--color-primary);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 0.82rem;
  letter-spacing: 0.02em;
  flex-shrink: 0;
}

.brand-txt { min-width: 0; line-height: 1.15; }
.brand-txt b {
  display: block;
  font-size: 1.05rem;
  font-weight: 800;
  letter-spacing: -0.01em;
  color: var(--color-text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.brand-txt small {
  display: block;
  font-size: 0.66rem;
  color: var(--color-text-muted);
  font-weight: 500;
}

.nav-label {
  font-size: 0.62rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--color-text-muted);
  padding: 12px 10px 6px;
}

.sidebar-nav {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.side-item {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  text-align: left;
  padding: 9px 11px;
  border-radius: 9px;
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  text-decoration: none;
  background: transparent;
  border: none;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
  white-space: nowrap;
  min-width: 0;
}

.side-item svg {
  width: 19px;
  height: 19px;
  stroke: currentColor;
  fill: none;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
  flex: none;
}

.side-item:hover { background: var(--color-bg); color: var(--color-text); }
.side-item.active { background: rgba(220, 38, 38, 0.08); color: #b91c1c; }

.side-item .badge {
  margin-left: auto;
  font-family: var(--font-mono, monospace);
  font-size: 0.62rem;
  font-weight: 700;
  background: #dc2626;
  color: #fff;
  border-radius: 999px;
  padding: 2px 7px;
}
.side-item span:last-child {
  overflow: hidden;
  text-overflow: ellipsis;
}

.side-footer {
  margin-top: auto;
  border-top: 1px solid var(--color-border-light);
  padding-top: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.season-pill {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  align-self: flex-start;
  margin: 0 6px;
  font-family: var(--font-mono, monospace);
  font-size: 0.66rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  background: var(--color-bg);
  border-radius: 999px;
  padding: 5px 11px;
}
.season-pill::before {
  content: '';
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #15803d;
}
.season-pill.off::before { background: #d3d9e3; }

.user-chip {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 6px;
  padding: 8px;
  border-radius: 10px;
  background: transparent;
  border: none;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s ease;
}
.user-chip:hover { background: var(--color-bg); }

.user-avatar {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: linear-gradient(135deg, #dc2626, #f59e0b);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.72rem;
  flex-shrink: 0;
}

.user-chip .nm { line-height: 1.25; min-width: 0; }
.user-chip .nm b {
  display: block;
  font-size: 0.84rem;
  color: var(--color-text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.user-chip .nm span {
  font-size: 0.7rem;
  color: var(--color-text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: block;
}

.side-mini { display: flex; gap: 6px; margin: 0 6px; }

.mini-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px 0;
  border-radius: 9px;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  cursor: pointer;
  text-decoration: none;
  transition: all 0.15s ease;
}
.mini-btn svg { width: 16px; height: 16px; }
.mini-btn:hover { background: var(--color-bg); color: var(--color-text); }
.mini-btn.danger:hover {
  color: #dc2626;
  border-color: rgba(220, 38, 38, 0.35);
  background: rgba(220, 38, 38, 0.05);
}

.main-col {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}

@media (min-width: 1024px) {
  .sidebar {
    display: flex;
  }

  .main-col {
    margin-left: 236px;
  }

  .topbar {
    display: none;
  }
}

@media (max-width: 1023px) {
  .sidebar {
    display: none;
  }
}

.main-content {
  flex: 1;
  animation: fadeIn var(--transition-base);
}

@media (max-width: 768px) {
  .topbar {
    padding: 0.5rem 0.75rem;
    flex-wrap: nowrap;
    gap: 0.5rem;
    position: sticky;
    top: 0;
    min-height: 52px;
  }

  .topbar-season {
    display: none;
  }

  .topbar-actions {
    display: none;
  }

  .brand-text {
    font-size: 1rem;
    max-width: 140px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .logo-img {
    height: 32px;
  }

  .hamburger {
    display: none;
  }

  .main-content {
    padding-bottom: 72px;
  }
}

@media (max-width: 768px) and (orientation: landscape) {
  .topbar {
    padding: 0.35rem 0.5rem;
    min-height: 44px;
  }

  .topbar-brand {
    gap: 0.4rem;
  }

  .brand-text {
    font-size: 0.85rem;
    max-width: 100px;
  }

  .logo-img {
    height: 26px;
  }

  .main-content {
    padding-bottom: 56px;
  }
}

.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(4px);
}

.modal {
  background: var(--color-surface);
  border-radius: var(--radius-xl);
  width: 100%;
  max-width: 400px;
  box-shadow: var(--shadow-xl);
  animation: scaleIn 0.3s ease-out;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 1.5rem 0;
}

.modal-header h3 {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-close {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  border: none;
  border-radius: 50%;
  color: var(--color-text-muted);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.modal-close:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.modal-close svg {
  width: 20px;
  height: 20px;
}

.modal-body {
  padding: 1.5rem;
}

.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  margin-bottom: 0.5rem;
}

.form-group input {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 1rem;
  color: var(--color-text);
  background: var(--color-bg);
  transition: all var(--transition-fast);
}

.form-group input:focus {
  outline: none;
  border-color: var(--color-primary);
  background: var(--color-surface);
}

.modal-footer {
  display: flex;
  gap: 0.75rem;
  padding: 0 1.5rem 1.5rem;
}

.btn-primary {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-primary:hover {
  background: var(--color-primary-dark);
}

.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-secondary {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-secondary:hover {
  background: var(--color-border);
}

.errore-msg {
  padding: 0.75rem;
  background: rgba(244, 63, 94, 0.1);
  border: 1px solid rgba(244, 63, 94, 0.2);
  border-radius: var(--radius-md);
  color: var(--color-error);
  font-size: 0.875rem;
  margin-top: 0.5rem;
}

.success-msg {
  padding: 0.75rem;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: var(--radius-md);
  color: #10b981;
  font-size: 0.875rem;
  margin-top: 0.5rem;
}

.spinner-small {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.hamburger {
  display: none;
  background: transparent;
  border: none;
  color: white;
  cursor: pointer;
  padding: 0.5rem;
  border-radius: 8px;
  transition: background 0.2s;
}

.hamburger:hover {
  background: rgba(255,255,255,0.1);
}

.hamburger svg {
  width: 28px;
  height: 28px;
}

.bottom-nav {
  display: none;
}

@media (max-width: 768px) {
  .bottom-nav {
    display: flex;
    justify-content: space-around;
    align-items: stretch;
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 150;
    background: rgba(255, 255, 255, 0.94);
    border-top: 1px solid var(--color-border);
    padding-bottom: env(safe-area-inset-bottom, 0px);
    backdrop-filter: blur(20px);
    height: 56px;
  }

  .bottom-nav-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2px;
    flex: 1;
    background: transparent;
    border: none;
    color: var(--color-text-muted);
    font-size: 0.625rem;
    font-weight: 700;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: color 0.2s;
    text-decoration: none;
    padding: 0.25rem 0;
  }

  .bottom-nav-item svg {
    width: 22px;
    height: 22px;
  }

  .bottom-nav-item:hover {
    color: var(--color-text);
  }

  .bottom-nav-item.active {
    color: var(--color-primary);
  }
}

@media (max-width: 768px) and (orientation: landscape) {
  .bottom-nav {
    height: 44px;
  }

  .bottom-nav-item {
    font-size: 0.5625rem;
  }

  .bottom-nav-item svg {
    width: 18px;
    height: 18px;
  }
}

.mobile-menu-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.7);
  z-index: 200;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(4px);
}

.mobile-menu {
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 280px;
  max-width: 85vw;
  background: var(--color-surface);
  animation: slideIn 0.3s ease-out;
  overflow-y: auto;
  box-shadow: 4px 0 24px rgba(22, 24, 29, 0.15);
}

.mobile-menu-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--color-border-light);
  font-weight: 700;
  color: var(--color-text);
}

.mobile-menu-close {
  background: transparent;
  border: none;
  color: var(--color-text-secondary);
  cursor: pointer;
  padding: 0.25rem;
  border-radius: 4px;
}

.mobile-menu-close:hover {
  background: var(--color-bg);
}

.mobile-menu-close svg {
  width: 24px;
  height: 24px;
}

.mobile-menu-content {
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.mobile-menu .user-badge {
  margin-bottom: 0.5rem;
  padding: 0.75rem 1rem;
  background: var(--color-bg);
  border-radius: 8px;
}

.mobile-menu-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border-light);
  border-radius: 10px;
  color: var(--color-text);
  font-size: 0.95rem;
  font-weight: 600;
  text-decoration: none;
  cursor: pointer;
  transition: all 0.2s;
  width: 100%;
  text-align: left;
}

.mobile-menu-item:hover {
  background: var(--color-border-light);
  transform: translateX(4px);
}

.mobile-menu-item svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
}

.mobile-menu-logout {
  margin-top: 0.5rem;
  background: rgba(220, 38, 38, 0.06);
  border-color: rgba(220, 38, 38, 0.25);
  color: var(--color-primary);
}

.mobile-menu-logout:hover {
  background: rgba(220, 38, 38, 0.12);
}

@keyframes slideIn {
  from {
    transform: translateX(-100%);
  }
  to {
    transform: translateX(0);
  }
}

@media (min-width: 769px) {
  .mobile-menu-overlay {
    display: none;
  }
}

@media print {
  .topbar,
  .sidebar,
  .bottom-nav,
  .mobile-menu-overlay {
    display: none !important;
  }
}
</style>
