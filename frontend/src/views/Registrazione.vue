<template>
  <div v-if="checking" class="registrazione-wrapper">
    <div class="registrazione-card checking-card">
      <div class="spinner-big"></div>
      <p class="checking-text">Verifica dell'accesso in corso...</p>
    </div>
  </div>

  <div v-else-if="!completed">
    <div class="registrazione-wrapper">
    <div class="registrazione-card">
      <div class="card-header">
        <h1>Completa la registrazione</h1>
        <p class="subtitle">Società: <strong>{{ invitationData?.societa_nome }}</strong></p>
        <p class="subtitle">Ruolo: <strong>{{ invitationData?.ruolo }}</strong></p>
      </div>

      <form @submit.prevent="submitRegistration" class="form">
        <div class="form-row">
          <div class="form-group">
            <label>Nome *</label>
            <input v-model="form.nome" type="text" required />
          </div>
          <div class="form-group">
            <label>Cognome *</label>
            <input v-model="form.cognome" type="text" required />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Data di nascita *</label>
            <input v-model="form.data_nascita" type="date" required />
          </div>
          <div class="form-group">
            <label>Numero di telefono *</label>
            <input v-model="form.cellulare" type="tel" required placeholder="Es. 3331234567" />
          </div>
        </div>

        <div class="form-group full">
          <label>Codice fiscale *</label>
          <input v-model="form.codice_fiscale" type="text" required maxlength="16" placeholder="Es. RSSMRA85M01H501Z" />
        </div>

        <div class="form-group full">
          <label>Tesserino FIGC</label>
          <input v-model="form.tesserino" type="text" placeholder="Opzionale" />
        </div>

        <div class="form-group full">
          <label>Email Google</label>
          <input :value="invitationData?.google_email" disabled class="disabled-input" />
        </div>

        <button type="submit" class="btn-primary submit-btn" :disabled="loading">
          <span v-if="loading" class="spinner-small"></span>
          {{ loading ? 'Registrazione in corso...' : 'Registrati' }}
        </button>

        <p v-if="errore" class="errore-msg">{{ errore }}</p>
      </form>
    </div>
    </div>
  </div>

  <div v-else class="registrazione-wrapper">
    <div class="registrazione-card success-card">
      <div class="success-icon">&#10003;</div>
      <h1>Registrazione completata!</h1>
      <p>Benvenuto in {{ invitationData?.societa_nome }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { googleCallback, registraUtenteGoogle } from '../api/index.js'
import { useStore } from '../store.js'

const router = useRouter()
const { setToken, utenteAttivo, setSocietaAttiva } = useStore()

const loading = ref(false)
const errore = ref('')
const completed = ref(false)
const checking = ref(true)
const invitationData = ref(null)

const form = ref({
  nome: '',
  cognome: '',
  data_nascita: '',
  cellulare: '',
  codice_fiscale: '',
  tesserino: ''
})

onMounted(async () => {
  const params = new URLSearchParams(window.location.search)
  const code = params.get('code')
  const state = params.get('state')
  const directToken = params.get('invito')

  if (directToken && !code) {
    // User came directly from invitation link, redirect to Google login
    window.location.href = '/auth/google/authorize?invito=' + directToken
    return
  }

  if (code) {
    try {
      const res = await googleCallback(code, state || '')
      const data = res.data

      if (data.requires_registration) {
        checking.value = false
        invitationData.value = data
        form.value.nome = data.google_nome || ''
        form.value.cognome = data.google_cognome || ''
      } else {
        // User already exists, login directly
        setToken(data.access_token)
        utenteAttivo.value = data.user
        goHomeByRole(data.user)
      }
    } catch (e) {
      checking.value = false
      errore.value = e.response?.data?.detail || 'Errore durante il login Google'
      setTimeout(() => router.replace('/login'), 5000)
    }
  } else if (!directToken) {
    checking.value = false
    errore.value = 'Nessun token di autenticazione. Torna al login.'
    setTimeout(() => router.replace('/login'), 5000)
  }
})

async function submitRegistration() {
  if (!invitationData.value) return

  loading.value = true
  errore.value = ''

  try {
    const res = await registraUtenteGoogle({
      nome: form.value.nome,
      cognome: form.value.cognome,
      data_nascita: form.value.data_nascita,
      cellulare: form.value.cellulare,
      codice_fiscale: form.value.codice_fiscale,
      tesserino: form.value.tesserino || null,
      reg_token: invitationData.value.reg_token
    })

    setToken(res.data.access_token)
    utenteAttivo.value = res.data.user

    // Load society info
    const { getSocietaById } = await import('../api/index.js')
    if (res.data.user.societa_id) {
      try {
        const socRes = await getSocietaById(res.data.user.societa_id)
        setSocietaAttiva(socRes.data)
      } catch (e) {}
    }

    completed.value = true
    setTimeout(() => goHomeByRole(res.data.user), 2000)
  } catch (e) {
    errore.value = e.response?.data?.detail || 'Errore nella registrazione'
  } finally {
    loading.value = false
  }
}

async function goHomeByRole(user) {
  try {
    const ruolo = user?.ruolo
    if (ruolo === 'segreteria') return router.replace('/segreteria')
    if (ruolo === 'infermeria') return router.replace('/infermeria')
    if (ruolo === 'mister' || ruolo === 'dirigente') {
      const { getCategorie } = await import('../api/index.js')
      const cats = (await getCategorie()).data || []
      if (cats.length === 1) return router.replace('/scelta/' + cats[0].id)
      if (ruolo === 'mister') return router.replace('/allenatori')
    }
  } catch (e) {}
  router.replace('/')
}
</script>

<style scoped>
.registrazione-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: var(--color-bg);
  padding: 2rem;
}

.registrazione-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  padding: 2.5rem;
  max-width: 520px;
  width: 100%;
  animation: slideUp 0.4s ease-out;
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

.card-header {
  text-align: center;
  margin-bottom: 2rem;
}

.card-header h1 {
  color: var(--color-text);
  font-size: 1.5rem;
  margin-bottom: 0.5rem;
}

.subtitle {
  color: var(--color-text-muted);
  font-size: 0.9rem;
  margin: 0.25rem 0;
}

.subtitle strong {
  color: var(--color-text);
}

.form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.form-group.full {
  grid-column: 1 / -1;
}

.form-group label {
  color: var(--color-text-secondary);
  font-size: 0.85rem;
  font-weight: 500;
}

.form-group input {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 0.75rem 1rem;
  color: var(--color-text);
  font-size: 0.95rem;
  transition: border-color 0.2s;
}

.form-group input:focus {
  outline: none;
  border-color: #dc2626;
}

.disabled-input {
  background: var(--color-slate-soft) !important;
  color: var(--color-text-faint) !important;
  cursor: not-allowed;
}

.submit-btn {
  margin-top: 0.5rem;
  padding: 0.85rem;
  font-size: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
}

.errore-msg {
  color: #ef4444;
  font-size: 0.85rem;
  text-align: center;
}

.success-card {
  text-align: center;
}

.success-icon {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: #22c55e;
  color: white;
  font-size: 2rem;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 1.5rem;
}

.success-card h1 {
  color: var(--color-text);
  margin-bottom: 0.5rem;
}

.success-card p {
  color: var(--color-text-muted);
}

.spinner-small {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

.checking-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  padding: 3rem 2rem;
}

.spinner-big {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(220, 38, 38, 0.2);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

.checking-text {
  color: var(--color-text-muted);
  font-size: 0.95rem;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 600px) {
  .form-row {
    grid-template-columns: 1fr;
  }
  .registrazione-card {
    padding: 1.5rem;
  }
}
</style>
