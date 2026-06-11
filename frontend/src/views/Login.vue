<template>
  <div class="login-wrapper">
    <div class="login-bg"></div>
    <div class="login-card">
        <!-- Selezione Società (per super_admin) -->
        <div v-if="showSocietaSelection" class="societa-selection">
          <div class="login-header">
            <h1>The Home of <span class="home-text">Football</span></h1>
            <p class="subtitle">Seleziona la società</p>
          </div>
          
          <!-- Logo società selezionata -->
          <div v-if="societaSelezionata" class="selected-societa-preview">
            <img v-if="societaSelezionataObj?.logo" :src="`/uploads/${societaSelezionataObj.logo}`" :alt="societaSelezionataObj.nome" class="preview-logo" />
            <div v-else class="preview-logo-placeholder" :style="{ background: societaSelezionataObj?.colore_primario }">
              {{ societaSelezionataObj?.nome?.charAt(0) || 'S' }}
            </div>
            <div class="preview-info">
              <h3>{{ societaSelezionataObj?.nome }}</h3>
              <p>{{ societaSelezionataObj?.nome_breve }}</p>
            </div>
          </div>
        
        <div class="societa-grid">
          <div 
            v-for="s in societaOptions" 
            :key="s.id"
            :class="['societa-card', { selected: societaSelezionata === s.id }]"
            @click="societaSelezionata = s.id"
          >
            <div class="societa-logo" :style="{ background: s.colore_primario }">
              <img v-if="s.logo" :src="`/uploads/${s.logo}`" :alt="s.nome" />
              <span v-else>{{ s.nome?.charAt(0) || 'S' }}</span>
            </div>
            <div class="societa-info">
              <h3>{{ s.nome }}</h3>
            </div>
            <button type="button" v-if="isSuperAdmin" class="btn-edit-societa" @click.stop="modificaSocieta(s)" title="Modifica">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
            </button>
          </div>
        </div>
        
        <button type="button" class="btn-login" @click="confermaSocieta">
          Continua
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </button>
        
        <div class="create-societa" v-if="isSuperAdmin">
          <button type="button" class="btn-create" @click="showCreateSocieta = true">
            + Crea nuova società
          </button>
          <button type="button" class="btn-gestione" @click="vaiGestioneSocieta">
            ⚙️ Gestione Società
          </button>
        </div>
        
        <!-- Modal creazione società -->
        <div v-if="showCreateSocieta" class="create-modal">
          <div class="create-modal-content">
            <h3>Crea nuova società</h3>
            
            <div class="form-section">
              <h4>Dati Società</h4>
              <div class="form-group">
                <label>Nome Società *</label>
                <input v-model="newSocieta.nome" placeholder="Es. Nuova Società" />
              </div>
              <div class="form-group">
                <label>Colore Primario</label>
                <input type="color" v-model="newSocieta.colore_primario" />
              </div>
              <div class="form-group">
                <label>Colore Secondario</label>
                <input type="color" v-model="newSocieta.colore_secondario" />
              </div>
              <div class="form-group">
                <label>Logo</label>
                <input type="file" @change="handleLogoUpload" accept="image/*" />
              </div>
              <div class="form-group">
                <label>Logo Sponsor</label>
                <input type="file" @change="handleLogosponsorUpload" accept="image/*" />
              </div>
            </div>
            
            <div class="form-section">
              <h4>Amministratore Locale</h4>
              <div class="form-row">
                <div class="form-group">
                  <label>Username *</label>
                  <input v-model="newAdmin.username" placeholder="admin" />
                </div>
                <div class="form-group">
                  <label>Password *</label>
                  <input v-model="newAdmin.password" type="password" placeholder="Password" />
                </div>
              </div>
              <div class="form-row">
                <div class="form-group">
                  <label>Nome *</label>
                  <input v-model="newAdmin.nome" placeholder="Nome" />
                </div>
                <div class="form-group">
                  <label>Cognome *</label>
                  <input v-model="newAdmin.cognome" placeholder="Cognome" />
                </div>
              </div>
            </div>
            
            <div class="form-section">
              <h4>Stagione</h4>
              <div class="form-group">
                <label>Stagione *</label>
                <select v-model="newStagione">
                  <option :value="currentYear">{{ currentYear }}/{{ currentYear + 1 }}</option>
                  <option :value="currentYear - 1">{{ currentYear - 1 }}/{{ currentYear }}</option>
                  <option :value="currentYear + 1">{{ currentYear + 1 }}/{{ currentYear + 2 }}</option>
                </select>
              </div>
            </div>
            
            <div class="modal-actions">
              <button type="button" class="btn-secondary" @click="showCreateSocieta = false">Annulla</button>
              <button type="button" class="btn-primary" @click="creaSocieta">Crea</button>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Login Form -->
      <div v-else>
        <div class="login-header">
          <h1>The Home of <span class="home-text">Football</span></h1>
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
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { login, getMe, getSocieta, getSocietaById, createSocieta, uploadSocietaFile, createUtente, createCategoria } from '../api/index.js'
import { useStore } from '../store.js'

const username = ref('')
const password = ref('')
const errore = ref('')
const loading = ref(false)
const showPassword = ref(false)
const showSocietaSelection = ref(false)
const societaOptions = ref([])
const societaSelezionata = ref(null)
const societaSelezionataObj = computed(() => societaOptions.value.find(s => s.id === societaSelezionata.value))
const isSuperAdmin = computed(() => utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin')
const showCreateSocieta = ref(false)
const newSocieta = ref({
  nome: '',
  nome_breve: null,
  colore_primario: '#dc2626',
  colore_secondario: '#1f2937',
  logo: '',
  logosponsor: ''
})
const logoFile = ref(null)
const logosponsorFile = ref(null)
const currentYear = new Date().getFullYear()
const newStagione = ref(new Date().getFullYear())
const newAdmin = ref({
  username: '',
  password: '',
  nome: '',
  cognome: ''
})

function handleLogoUpload(event) {
  const file = event.target.files[0]
  if (file) {
    logoFile.value = file
    newSocieta.value.logo = file.name
  }
}

function handleLogosponsorUpload(event) {
  const file = event.target.files[0]
  if (file) {
    logosponsorFile.value = file
    newSocieta.value.logosponsor = file.name
  }
}
const router = useRouter()
const { setToken, utenteAttivo, setSocietaAttiva, setListaSocieta, societaAttiva } = useStore()

onMounted(async () => {
  // Carica lista società per selezione (richiede auth)
  try {
    const res = await getSocieta()
    societaOptions.value = res.data
    setListaSocieta(res.data)
    
    // Se utente già loggato e super_admin, mostra selezione società
    const token = localStorage.getItem('token')
    const isSuper = utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin'
    if (token && isSuper) {
      const me = await getMe()
      utenteAttivo.value = me.data
      showSocietaSelection.value = true
      // Resetta società attiva per obbligare la scelta
      setSocietaAttiva(null)
    }
  } catch (e) {
    // 401 è atteso quando non si è loggati
    if (e.response?.status !== 401) {
      console.error('Errore caricamento società:', e)
    }
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
    
    const isSuper = me.data.is_super_admin || me.data.ruolo === 'super_admin'
    
    // Se è super_admin (ruolo o flag), mostra selezione società
    if (isSuper) {
      // Ricarica lista società ora che abbiamo il token
      try {
        const res = await getSocieta()
        societaOptions.value = res.data
        setListaSocieta(res.data)
      } catch {}
      showSocietaSelection.value = true
      loading.value = false
      return
    }
    
    // Admin locale: carica la società dell'utente e vai alla home
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

function vaiGestioneSocieta() {
  router.push('/admin/societa')
}

function modificaSocieta(s) {
  // Popola il form con i dati della società esistente
  newSocieta.value = { 
    nome: s.nome, 
    nome_breve: s.nome_breve, 
    colore_primario: s.colore_primario, 
    colore_secondario: s.colore_secondario, 
    logo: s.logo || '', 
    logosponsor: s.logosponsor || '' 
  }
  societaSelezionata.value = s.id
  showCreateSocieta.value = true
}

async function creaSocieta() {
  if (!newSocieta.value.nome) {
    alert('Inserisci il nome della società')
    return
  }
  if (!newAdmin.value.username || !newAdmin.value.password || !newAdmin.value.nome || !newAdmin.value.cognome) {
    alert('Compila tutti i dati dell\'amministratore')
    return
  }
  try {
    // Upload logo
    if (logoFile.value) {
      const uploadRes = await uploadSocietaFile('logo', logoFile.value)
      newSocieta.value.logo = uploadRes.data.filename
    }
    // Upload logosponsor
    if (logosponsorFile.value) {
      const uploadRes = await uploadSocietaFile('logosponsor', logosponsorFile.value)
      newSocieta.value.logosponsor = uploadRes.data.filename
    }
    
    // Crea società
    const res = await createSocieta(newSocieta.value)
    const nuova = res.data
    
    // Crea utente admin per la società
    await createUtente({
      username: newAdmin.value.username,
      password: newAdmin.value.password,
      nome: newAdmin.value.nome,
      cognome: newAdmin.value.cognome,
      data_nascita: null,
      codice_fiscale: null,
      cellulare: null,
      tesserino: null,
      ruolo: 'admin',
      is_admin: 1,
      societa_id: nuova.id
    })
    
    // Crea la stagione come categoria attiva
    await createCategoria({
      nome: 'Stagione ' + newStagione.value + '/' + (newStagione.value + 1),
      anno: newStagione.value,
      stagione: newStagione.value,
      giorni: null,
      is_portieri: false,
      societa_id: nuova.id
    })
    
    societaOptions.value.push(nuova)
    societaSelezionata.value = nuova.id
    setListaSocieta(societaOptions.value)
    setSocietaAttiva(nuova)
    showCreateSocieta.value = false
    newSocieta.value = { nome: '', nome_breve: null, colore_primario: '#dc2626', colore_secondario: '#1f2937', logo: '', logosponsor: '' }
    newAdmin.value = { username: '', password: '', nome: '', cognome: '' }
    newStagione.value = currentYear
    logoFile.value = null
    logosponsorFile.value = null
    router.push('/')
  } catch (e) {
    console.error('Errore nella creazione:', e)
    alert('Errore nella creazione della società: ' + (e.response?.data?.detail || e.message))
  }
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

h1 {
  font-size: 1.75rem;
  font-weight: 800;
  color: #ffffff;
  margin-bottom: 0.25rem;
  letter-spacing: 0.02em;
}

.home-text {
  color: var(--color-primary);
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
  border-color: var(--color-primary);
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
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-dark));
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
}

.create-societa {
  text-align: center;
  margin-top: 1rem;
}

.btn-create {
  background: transparent;
  border: 2px dashed #444;
  border-radius: var(--radius-md);
  color: #888;
  padding: 0.75rem 1.5rem;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
  width: 100%;
}

.btn-create:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
}

.btn-gestione {
  margin-top: 0.5rem;
  background: #333;
  border: none;
  border-radius: var(--radius-md);
  color: #fff;
  padding: 0.75rem 1.5rem;
  font-size: 0.875rem;
  cursor: pointer;
  width: 100%;
}

.btn-gestione:hover {
  background: #444;
}

.create-modal {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
  padding: 1rem;
}

.create-modal-content {
  background: #1a1a1a;
  border: 1px solid #333;
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  width: 100%;
  max-width: 500px;
  max-height: 90vh;
  overflow-y: auto;
}

.create-modal-content h3 {
  color: #fff;
  margin-bottom: 1rem;
  font-size: 1.25rem;
}

.create-modal-content .form-group {
  margin-bottom: 1rem;
}

.create-modal-content .form-group label {
  display: block;
  font-size: 0.875rem;
  color: #aaa;
  margin-bottom: 0.5rem;
}

.create-modal-content .form-group input[type="color"] {
  width: 50px;
  height: 40px;
  padding: 0.25rem;
  cursor: pointer;
}

.create-modal-content .form-group input[type="file"] {
  padding: 0.5rem;
  background: #222;
  border: 1px solid #444;
  border-radius: var(--radius-md);
  color: #ccc;
  font-size: 0.875rem;
}

.modal-actions {
  display: flex;
  gap: 1rem;
  margin-top: 1.5rem;
}

.modal-actions .btn-primary {
  flex: 1;
}

.modal-actions .btn-secondary {
  flex: 1;
  padding: 0.75rem;
  background: #333;
  border: none;
  border-radius: var(--radius-md);
  color: #fff;
  cursor: pointer;
}

.form-section {
  margin-bottom: 1.5rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #333;
}

.form-section:last-of-type {
  border-bottom: none;
}

.form-section h4 {
  color: #fff;
  font-size: 0.9rem;
  font-weight: 600;
  margin-bottom: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

.form-section .form-group {
  margin-bottom: 0.75rem;
}

.create-modal-content .form-group input[type="file"] {
  padding: 0.5rem;
  background: #222;
  border: 1px solid #444;
  border-radius: var(--radius-md);
  color: #ccc;
  font-size: 0.875rem;
}

.create-modal-content .form-group select {
  padding: 0.75rem 1rem;
  border: 2px solid #333;
  border-radius: var(--radius-md);
  font-size: 1rem;
  color: #fff;
  background: #1a1a1a;
  cursor: pointer;
}

.create-modal-content .form-group select:focus {
  outline: none;
  border-color: var(--color-primary);
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
  padding-right: 3rem;
  background: #1a1a1a;
  border: 2px solid #333;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  position: relative;
}

.societa-card:hover {
  border-color: var(--color-primary);
  transform: translateY(-2px);
}

.societa-card.selected {
  border-color: var(--color-primary);
  background: rgba(220, 38, 38, 0.1);
}

.btn-edit-societa {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255,255,255,0.1);
  border: none;
  border-radius: var(--radius-md);
  color: #888;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-edit-societa:hover {
  background: rgba(220, 38, 38, 0.3);
  color: #fff;
}

.btn-edit-societa svg {
  width: 16px;
  height: 16px;
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
  overflow: hidden;
}

.societa-logo img {
  width: 100%;
  height: 100%;
  object-fit: contain;
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

.selected-societa-preview {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background: rgba(220, 38, 38, 0.1);
  border: 2px solid rgba(220, 38, 38, 0.3);
  border-radius: var(--radius-md);
  margin-bottom: 1.5rem;
}

.preview-logo {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  object-fit: contain;
  background: white;
}

.preview-logo-placeholder {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  font-weight: 700;
  color: white;
}

.preview-info h3 {
  font-size: 1rem;
  font-weight: 600;
  color: #fff;
  margin-bottom: 0.25rem;
}

.preview-info p {
  font-size: 0.875rem;
  color: #888;
}
</style>
