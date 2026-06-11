<template>
  <div class="app-layout">
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
        <router-link v-if="utenteAttivo?.is_admin || utenteAttivo?.is_super_admin || utenteAttivo?.ruolo === 'super_admin'" to="/admin" class="btn-nav btn-admin">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="3"/>
            <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-2 2 2 2 0 01-2-2v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 01-2-2 2 2 0 012-2h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 010-2.83 2 2 0 012.83 0l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 012-2 2 2 0 012 2v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 0 2 2 0 010 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 012 2 2 2 0 01-2 2h-.09a1.65 1.65 0 00-1.51 1z"/>
          </svg>
          <span>Admin</span>
        </router-link>
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
          <router-link v-if="utenteAttivo?.is_admin || utenteAttivo?.is_super_admin || utenteAttivo?.ruolo === 'super_admin'" to="/admin" class="mobile-menu-item" @click="mobileMenuOpen = false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="3"/>
              <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-2 2 2 2 0 01-2-2v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 01-2-2 2 2 0 012-2h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 010-2.83 2 2 0 012.83 0l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 012-2 2 2 0 012 2v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 0 2 2 0 010 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 012 2 2 2 0 01-2 2h-.09a1.65 1.65 0 00-1.51 1z"/>
            </svg>
            Admin
          </router-link>
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
import { ref, computed, onMounted } from 'vue'
import { useStore } from './store.js'
import { useRouter } from 'vue-router'
import { getMe, getStagioni, changePassword } from './api/index.js'

const { token, utenteAttivo, clearToken, setStagioneCorrente, stagioneCorrente, societaAttiva, setSocietaAttiva, hideTopbar } = useStore()
const router = useRouter()

const showPasswordModal = ref(false)
const passwordForm = ref({ attuale: '', nuova: '', conferma: '' })
const passwordErrore = ref('')
const passwordSuccess = ref('')
const passwordLoading = ref(false)
const isSuperAdmin = computed(() => utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin')
const mobileMenuOpen = ref(false)

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
    }
  } catch (e) {
    console.error('Errore nel caricamento stagione:', e)
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
  padding: 0.75rem 1.5rem;
  background: #000000;
  color: white;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: 0 4px 20px rgba(0,0,0,0.5);
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
  font-size: 1.4rem;
  font-weight: 900;
  letter-spacing: 0.05em;
  color: white;
  font-family: var(--font-sans);
}

.brand-red {
  color: #dc2626;
}

.topbar-season {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(220, 38, 38, 0.2);
  border: 1px solid rgba(220, 38, 38, 0.4);
  border-radius: 50px;
  font-size: 0.875rem;
  font-weight: 600;
  color: #fca5a5;
}

.topbar-season.empty {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.2);
  color: rgba(255, 255, 255, 0.7);
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
  background: rgba(255,255,255,0.1);
  border-radius: 50px;
  font-size: 0.875rem;
  font-weight: 500;
  border: 1px solid rgba(255,255,255,0.15);
}

.user-badge svg {
  width: 18px;
  height: 18px;
}

.btn-nav {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: rgba(255,255,255,0.08);
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 50px;
  color: white;
  font-size: 0.875rem;
  font-weight: 500;
  transition: all var(--transition-base);
  cursor: pointer;
}

.btn-nav:hover {
  background: rgba(255,255,255,0.15);
  transform: translateY(-1px);
}

.btn-nav.btn-admin {
  background: rgba(220, 38, 38, 0.2);
  border-color: rgba(220, 38, 38, 0.4);
}

.btn-nav.btn-admin:hover {
  background: rgba(220, 38, 38, 0.35);
}

.btn-nav svg {
  width: 16px;
  height: 16px;
}

.btn-logout {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1.25rem;
  background: transparent;
  border: 2px solid rgba(255,255,255,0.4);
  border-radius: 50px;
  color: white;
  font-size: 0.875rem;
  font-weight: 600;
  transition: all var(--transition-base);
  cursor: pointer;
}

.btn-logout:hover {
  background: rgba(220, 38, 38, 0.8);
  border-color: #dc2626;
  transform: translateY(-1px);
}

.btn-logout svg {
  width: 16px;
  height: 16px;
}

.main-content {
  flex: 1;
  animation: fadeIn var(--transition-base);
}

@media (max-width: 768px) {
  .topbar {
    padding: 0.75rem 1rem;
    flex-wrap: wrap;
    gap: 0.75rem;
    position: sticky;
    top: 0;
  }
  
  .topbar-actions {
    flex-wrap: wrap;
    gap: 0.5rem;
  }
  
  .user-badge span:last-child,
  .btn-nav span,
  .btn-logout span {
    display: none;
  }
  
  .brand-text {
    font-size: 1.1rem;
  }
  
  .logo-img {
    height: 36px;
  }
  
  .btn-nav,
  .btn-logout {
    padding: 0.5rem 0.75rem;
  }
}

@media (max-width: 768px) and (orientation: landscape) {
  .topbar {
    padding: 0.5rem 0.75rem;
    min-height: 48px;
  }
  
  .topbar-brand {
    gap: 0.5rem;
  }
  
  .brand-text {
    font-size: 0.9rem;
  }
  
  .logo-img {
    height: 28px;
  }
  
  .topbar-season {
    display: none;
  }
  
  .topbar-actions {
    gap: 0.25rem;
  }
  
  .btn-nav,
  .btn-logout {
    padding: 0.4rem;
  }
  
  .btn-nav svg,
  .btn-logout svg {
    width: 18px;
    height: 18px;
  }
  
  .btn-admin {
    display: none;
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
  background: #1a1a1a;
  animation: slideIn 0.3s ease-out;
  overflow-y: auto;
  box-shadow: 4px 0 20px rgba(0,0,0,0.5);
}

.mobile-menu-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  font-weight: 700;
  color: white;
  background: #000;
}

.mobile-menu-close {
  background: transparent;
  border: none;
  color: white;
  cursor: pointer;
  padding: 0.25rem;
  border-radius: 4px;
}

.mobile-menu-close:hover {
  background: rgba(255,255,255,0.1);
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
  background: rgba(255,255,255,0.1);
  border-radius: 8px;
}

.mobile-menu-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 10px;
  color: white;
  font-size: 0.95rem;
  font-weight: 500;
  text-decoration: none;
  cursor: pointer;
  transition: all 0.2s;
  width: 100%;
  text-align: left;
}

.mobile-menu-item:hover {
  background: rgba(255,255,255,0.12);
  transform: translateX(4px);
}

.mobile-menu-item svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
}

.mobile-menu-logout {
  margin-top: 0.5rem;
  background: rgba(220, 38, 38, 0.2);
  border-color: rgba(220, 38, 38, 0.4);
}

.mobile-menu-logout:hover {
  background: rgba(220, 38, 38, 0.35);
}

@keyframes slideIn {
  from {
    transform: translateX(-100%);
  }
  to {
    transform: translateX(0);
  }
}

@media (max-width: 768px) {
  .hamburger {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .topbar-actions {
    display: none;
  }
}

@media (min-width: 769px) {
  .mobile-menu-overlay {
    display: none;
  }
}

@media print {
  .topbar {
    display: none !important;
  }
}
</style>
