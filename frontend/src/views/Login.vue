<template>
  <div class="login-wrapper">
    <div class="login-bg"></div>
    <div class="login-card">
      <!-- Selezione Società (per super_admin) -->
      <div v-if="showSocietaSelection" class="societa-selection">
        <div class="login-header">
          <img src="/logo.jpg" alt="RedTigers" class="login-logo" />
          <h1>Seleziona <span class="home-text">Società</span></h1>
          <p class="subtitle">Scegli su quale società lavorare</p>
        </div>
        
        <div class="societa-grid">
          <div 
            v-for="s in societaOptions" 
            :key="s.id"
            :class="['societa-card', { selected: societaSelezionata === s.id }]"
            @click="societaSelezionata = s.id"
          >
            <div class="societa-logo" :style="{ background: s.colore_primario }">
              {{ s.nome_breve?.charAt(0) || s.nome.charAt(0) }}
            </div>
            <div class="societa-info">
              <h3>{{ s.nome }}</h3>
              <p>{{ s.nome_breve }}</p>
            </div>
          </div>
        </div>
        
        <button type="button" class="btn-login" @click="confermaSocieta">
          Continua
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </button>
      </div>
      
      <!-- Login Form -->
      <div v-else>
        <div class="login-header">
          <img src="/logo.jpg" alt="RedTigers" class="login-logo" />
          <h1>Red Tigers <span class="home-text">Home</span></h1>
          <p class="subtitle">Accedi al tuo account</p>
        </div>
        
        <form @submit.prevent="doLogin" class="login-form">
        <div class="form-group">
          <label for="username">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="8" r="4"/>
              <path d="M4 20c0-4 4-6 8-6s8 2 8 6"/>
            </svg>
            Username
          </label>
          <input 
            id="username"
            v-model="username" 
            type="text" 
            placeholder="Inserisci il tuo username"
            autocomplete="username"
            required
          />
        </div>
        
        <div class="form-group">
          <label for="password">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
              <path d="M7 11V7a5 5 0 0110 0v4"/>
            </svg>
            Password
          </label>
          <div class="input-wrapper">
            <input 
              id="password"
              v-model="password" 
              :type="showPassword ? 'text' : 'password'" 
              placeholder="Inserisci la password"
              autocomplete="current-password"
              required
            />
            <button type="button" class="toggle-password" @click="showPassword = !showPassword">
              <svg v-if="!showPassword" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                <circle cx="12" cy="12" r="3"/>
              </svg>
              <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24"/>
                <line x1="1" y1="1" x2="23" y2="23"/>
              </svg>
            </button>
          </div>
        </div>
        
        <p v-if="errore" class="errore">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <line x1="12" y1="8" x2="12" y2="12"/>
            <line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
          {{ errore }}
        </p>
        
        <button type="submit" class="btn-login" :disabled="loading">
          <span v-if="loading" class="spinner"></span>
          <template v-else>
            Accedi
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="5" y1="12" x2="19" y2="12"/>
              <polyline points="12 5 19 12 12 19"/>
            </svg>
          </template>
        </button>
      </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { login, getMe, getSocieta, getSocietaById } from '../api/index.js'
import { useStore } from '../store.js'

const username = ref('')
const password = ref('')
const errore = ref('')
const loading = ref(false)
const showPassword = ref(false)
const showSocietaSelection = ref(false)
const societaOptions = ref([])
const societaSelezionata = ref(null)
const router = useRouter()
const { setToken, utenteAttivo, setSocietaAttiva, setListaSocieta } = useStore()

onMounted(async () => {
  // Carica lista società per selezione
  try {
    const res = await getSocieta()
    societaOptions.value = res.data
    setListaSocieta(res.data)
  } catch (e) {
    console.error('Errore caricamento società:', e)
  }
})

async function doLogin() {
  if (loading.value) return
  loading.value = true
  errore.value = ''
  
  try {
    const res = await login(username.value, password.value)
    setToken(res.data.access_token)
    const me = await getMe()
    utenteAttivo.value = me.data
    
    // Se è super_admin, mostra selezione società
    if (me.data.is_super_admin) {
      showSocietaSelection.value = true
      loading.value = false
      return
    }
    
    // Altrimenti, carica la società dell'utente e vai alla home
    if (me.data.societa_id) {
      const societaRes = await getSocietaById(me.data.societa_id)
      setSocietaAttiva(societaRes.data)
    }
    
    router.push('/')
  } catch {
    errore.value = 'Credenziali non valide. Riprova.'
  } finally {
    loading.value = false
  }
}

async function confermaSocieta() {
  if (!societaSelezionata.value) {
    errore.value = 'Seleziona una società'
    return
  }
  const societa = societaOptions.value.find(s => s.id === societaSelezionata.value)
  setSocietaAttiva(societa)
  router.push('/')
}
</script>

<style scoped>
.login-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: #000000;
  padding: 2rem;
  position: relative;
  overflow: hidden;
}

.login-bg {
  position: absolute;
  inset: 0;
  background: radial-gradient(circle at 50% 30%, rgba(220, 38, 38, 0.15) 0%, transparent 50%),
              radial-gradient(circle at 80% 80%, rgba(220, 38, 38, 0.1) 0%, transparent 40%);
  pointer-events: none;
}

.login-card {
  background: rgba(20, 20, 20, 0.95);
  border: 1px solid rgba(220, 38, 38, 0.3);
  border-radius: var(--radius-xl);
  padding: 2.5rem;
  width: 100%;
  max-width: 420px;
  box-shadow: 0 0 60px rgba(220, 38, 38, 0.2);
  animation: scaleIn 0.4s ease-out, slideUp 0.4s ease-out;
  position: relative;
  z-index: 1;
}

.login-header {
  text-align: center;
  margin-bottom: 2rem;
}

.login-logo {
  width: 100px;
  height: auto;
  margin: 0 auto 1rem;
  object-fit: contain;
}

h1 {
  font-size: 1.75rem;
  font-weight: 800;
  color: #ffffff;
  margin-bottom: 0.25rem;
  letter-spacing: 0.02em;
}

.home-text {
  color: #dc2626;
}

.subtitle {
  color: #888888;
  font-size: 0.9375rem;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-group label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  font-weight: 600;
  color: #cccccc;
}

.form-group label svg {
  width: 16px;
  height: 16px;
  color: #888888;
}

.form-group input {
  padding: 0.875rem 1rem;
  border: 2px solid #333333;
  border-radius: var(--radius-md);
  font-size: 1rem;
  color: #ffffff;
  background: #1a1a1a;
  transition: all var(--transition-fast);
}

.form-group input:focus {
  outline: none;
  border-color: #dc2626;
  background: #0d0d0d;
  box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.2);
}

.form-group input::placeholder {
  color: #666666;
}

.input-wrapper {
  position: relative;
}

.input-wrapper input {
  width: 100%;
  padding-right: 3rem;
}

.toggle-password {
  position: absolute;
  right: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: #888888;
  padding: 0.25rem;
  cursor: pointer;
  transition: color var(--transition-fast);
}

.toggle-password:hover {
  color: #cccccc;
}

.toggle-password svg {
  width: 20px;
  height: 20px;
}

.errore {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  background: rgba(220, 38, 38, 0.15);
  border: 1px solid rgba(220, 38, 38, 0.3);
  border-radius: var(--radius-md);
  color: #f87171;
  font-size: 0.875rem;
  font-weight: 500;
  animation: slideDown 0.2s ease-out;
}

.errore svg {
  width: 18px;
  height: 18px;
  flex-shrink: 0;
}

.btn-login {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 1rem 1.5rem;
  background: linear-gradient(135deg, #dc2626, #b91c1c);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-base);
  margin-top: 0.5rem;
}

.btn-login:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(220, 38, 38, 0.4);
}

.btn-login:active:not(:disabled) {
  transform: translateY(0);
}

.btn-login:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.btn-login svg {
  width: 18px;
  height: 18px;
}

.spinner {
  width: 20px;
  height: 20px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 480px) {
  .login-wrapper {
    padding: 1rem;
  }
  
  .login-card {
    padding: 1.5rem;
  }

  .login-logo {
    width: 80px;
  }
}

.societa-selection {
  animation: scaleIn 0.4s ease-out;
}

.societa-grid {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin: 1.5rem 0;
}

.societa-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background: #1a1a1a;
  border: 2px solid #333;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.societa-card:hover {
  border-color: #dc2626;
  transform: translateY(-2px);
}

.societa-card.selected {
  border-color: #dc2626;
  background: rgba(220, 38, 38, 0.1);
}

.societa-logo {
  width: 50px;
  height: 50px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  font-weight: 700;
  color: white;
}

.societa-info h3 {
  font-size: 1rem;
  font-weight: 600;
  color: #fff;
  margin-bottom: 0.25rem;
}

.societa-info p {
  font-size: 0.875rem;
  color: #888;
}
</style>
