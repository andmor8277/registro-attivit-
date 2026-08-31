<template>
  <div class="admin">
    <header class="page-header">
      <div class="header-content">
        <h1>Gestione Utenti</h1>
        <p class="page-subtitle">Crea e gestisci gli account degli utenti</p>
      </div>
      <div class="header-actions">
        <button @click="cambiaSocieta" class="btn-societa">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
          Cambia Società
        </button>
        <router-link v-if="isSuperAdmin" to="/admin/societa" class="btn-societa">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 20h9"/>
            <path d="M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z"/>
          </svg>
          Gestione Società
        </router-link>
      </div>
    </header>

    <div v-if="isSuperAdmin" class="encryption-section">
      <div class="section-card">
        <div class="section-header">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
            <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
          </svg>
          <h3>Chiave di Crittografia</h3>
        </div>
        <div class="section-body">
          <p class="section-desc">La chiave usata per crittografare i dati sensibili dei giocatori (CF, telefono). Per cambiare la chiave e mantenere i dati, usa "Salva e ricifra" inserendo prima la chiave vecchia.</p>
          <div class="input-row">
            <input 
              v-model="oldKey" 
              placeholder="Chiave vecchia..." 
              class="key-input"
              style="max-width: 200px;"
            />
            <input 
              v-model="encryptionKey" 
              placeholder="Nuova chiave..." 
              class="key-input"
              @keyup.enter="salvaChiave"
            />
            <button class="btn-salva-chiave reencrypt" @click="salvaChiave" :disabled="!encryptionKey || !oldKey">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="20 6 9 17 4 12"/>
              </svg>
              Salva e ricifra
            </button>
          </div>
          <p v-if="chiaveMsg" class="chiave-msg" :class="{'error': chiaveError, 'success': !chiaveError}">
            {{ chiaveMsg }}
          </p>
        </div>
      </div>
    </div>

    <!-- Sezione Inviti Google -->
    <div class="card card-inviti">
      <div class="card-header">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
          <polyline points="22,6 12,13 2,6"/>
        </svg>
        <h3>Invita utente con Google</h3>
      </div>
      <div class="invito-form">
        <div class="invito-inputs">
          <input v-model="nuovoInvito.email" placeholder="Email dell'utente" />
          <select v-model="nuovoInvito.ruolo" class="ruolo-select">
            <option value="">Seleziona ruolo...</option>
            <option v-if="isSuperAdmin" value="admin">Admin</option>
            <option value="mister">Mister</option>
            <option value="dirigente">Dirigente</option>
            <option value="segreteria">Segreteria</option>
            <option value="infermeria">Infermeria</option>
          </select>
          <select v-if="isSuperAdmin" v-model="nuovoInvito.societa_id" class="ruolo-select">
            <option value="">Seleziona società...</option>
            <option v-for="s in listaSocieta" :key="s.id" :value="s.id">{{ s.nome }}</option>
          </select>
          <button @click="creaInvitoUtente" class="btn-primary" :disabled="!nuovoInvito.email || !nuovoInvito.ruolo">
            Invia Invito
          </button>
        </div>
        <p v-if="invitoMsg" class="invito-msg" :class="{ 'success': !invitoError, 'error': invitoError }">{{ invitoMsg }}</p>
      </div>

      <div v-if="inviti.length" class="inviti-list">
        <h4>Inviti attivi</h4>
        <div v-for="inv in inviti" :key="inv.id" class="invito-row">
          <div class="invito-info">
            <span class="invito-email">{{ inv.email }}</span>
            <span class="invito-ruolo">{{ inv.ruolo }}</span>
            <span v-if="inv.societa_nome" class="invito-societa">{{ inv.societa_nome }}</span>
            <span class="invito-date">{{ new Date(inv.scade).toLocaleDateString('it-IT') }}</span>
          </div>
          <div class="invito-actions">
            <button @click="copiaLink(inv.link)" class="btn-copia" title="Copia link">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
              </svg>
            </button>
            <button @click="eliminaInvitoUtente(inv.id)" class="btn-elimina" title="Elimina">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/>
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="users-list">
      <div class="card user-card" v-for="u in utenti" :key="u.id">
        <div class="user-header">
          <div class="user-info">
            <div class="user-avatar">
              {{ (u.cognome || u.nome || u.username).charAt(0).toUpperCase() }}
            </div>
            <div class="user-details">
              <span class="user-name">{{ u.cognome || u.username }}</span>
              <span class="user-fullname">{{ u.nome }} {{ u.cognome }}</span>
              <span class="badge-role badge-superadmin" v-if="u.ruolo === 'super_admin'">SUPERADMIN</span>
              <span class="badge-role badge-admin" v-if="u.ruolo === 'admin'">RESPONSABILE</span>
              <span class="badge-role badge-mister" v-if="u.ruolo === 'mister'">MISTER</span>
              <span class="badge-role badge-dirigente" v-if="u.ruolo === 'dirigente'">DIRIGENTE</span>
              <span class="badge-role badge-segreteria" v-if="u.ruolo === 'segreteria'">SEGRETERIA</span>
              <span class="badge-role badge-infermeria" v-if="u.ruolo === 'infermeria'">INFERMERIA</span>
              <span class="badge-societa">{{ getSocietaNome(u.societa_id) }}</span>
            </div>
          </div>
          <div class="user-data">
            <span><strong>CF:</strong> {{ u.codice_fiscale }}</span>
            <span><strong>Cell:</strong> {{ u.cellulare }}</span>
            <span v-if="u.tesserino"><strong>Tess:</strong> {{ u.tesserino }}</span>
            <span><strong>Nato:</strong> {{ formatData(u.data_nascita) }}</span>
          </div>
          <div class="user-actions">
            <button class="btn-reset" @click="resetsPassword(u.id)" title="Reset Password">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
              </svg>
              Reset
            </button>
            <button class="btn-delete" @click="eliminaUtente(u.id)">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
              </svg>
              Elimina
            </button>
          </div>
        </div>
        <div v-if="u.ruolo === 'mister' || u.ruolo === 'dirigente'" class="categorie-assegna">
          <span class="label">Assegna a categorie (come Mister):</span>
          <div class="categorie-grid">
            <label v-for="cat in categorieAssegnabili" :key="cat.id" class="cat-check" :class="{ selected: isMister(u, cat.id) }">
              <input type="checkbox" :value="cat.id" @change="toggleMister(u, cat.id, $event)" />
              <span class="cat-anno">{{ cat.anno }}</span>
              <span class="cat-nome">{{ cat.nome }}</span>
              <span v-if="isMister(u, cat.id) && u.ruolo === 'dirigente'" class="badge-mister" style="background: #2563eb;">DIR</span>
              <span v-else-if="isMister(u, cat.id)" class="badge-mister">MISTER</span>
            </label>
            <span v-if="categorieAssegnabili.length === 0" class="muted">Nessuna categoria presente</span>
          </div>
        </div>
        <div v-else class="admin-note">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3"/>
            <line x1="12" y1="17" x2="12.01" y2="17"/>
          </svg>
          L'admin vede tutte le categorie
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from '../store.js'
import { getUtenti, deleteUtente, resetPassword, assegnaCategorie, getCategorie, getCategoriaUtenti, getSocieta, api, creaInvito, listaInviti, eliminaInvito } from '../api/index.js'

const router = useRouter()
const { societaAttiva, utenteAttivo } = useStore()
const isSuperAdmin = computed(() => utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'super_admin')

const utenti = ref([])
const tutteCategorie = ref([])
const categorieAssegnabili = computed(() => tutteCategorie.value.filter(cat => cat.parent_id != null))
const listaSocieta = ref([])
const societaIdSelezionata = ref(null)

const loading = ref(false)
const encryptionKey = ref('')
const oldKey = ref('')
const chiaveMsg = ref('')
const chiaveError = ref(false)

async function salvaChiave() {
  if (!oldKey.value || !encryptionKey.value) return
  chiaveMsg.value = ''
  chiaveError.value = false
  try {
    await api.put('/persone/encryption-key?reencrypt=true', { 
      key: encryptionKey.value, 
      old_key: oldKey.value 
    })
    chiaveMsg.value = 'Chiave aggiornata e dati ricifrati!'
    encryptionKey.value = ''
    oldKey.value = ''
  } catch(e) {
    chiaveError.value = true
    chiaveMsg.value = 'Errore: ' + (e.detail || 'impossibile aggiornare')
  }
}
const inviti = ref([])
const nuovoInvito = ref({ email: '', ruolo: '', societa_id: '' })
const invitoMsg = ref('')
const invitoError = ref(false)

async function caricaInviti() {
  try {
    const socId = isSuperAdmin.value ? societaIdSelezionata.value : societaAttiva.value?.id
    const res = await listaInviti(socId)
    inviti.value = res.data.filter(i => !i.usato)
  } catch (e) {
    console.error('Errore caricamento inviti:', e)
  }
}

async function creaInvitoUtente() {
  invitoMsg.value = ''
  invitoError.value = false
  if (!nuovoInvito.value.email || !nuovoInvito.value.ruolo) return
  try {
    const data = { email: nuovoInvito.value.email, ruolo: nuovoInvito.value.ruolo }
    if (isSuperAdmin.value) {
      data.societa_id = nuovoInvito.value.societa_id || societaIdSelezionata.value
    }
    await creaInvito(data)
    invitoMsg.value = 'Invito inviato a ' + nuovoInvito.value.email
    nuovoInvito.value = { email: '', ruolo: '', societa_id: '' }
    caricaInviti()
  } catch (e) {
    invitoError.value = true
    invitoMsg.value = e.response?.data?.detail || 'Errore nell\'invio'
  }
}

async function eliminaInvitoUtente(id) {
  try {
    await eliminaInvito(id)
    invitoMsg.value = 'Invito eliminato'
    caricaInviti()
  } catch (e) {
    invitoError.value = true
    invitoMsg.value = 'Errore nell\'eliminazione'
  }
}

function copiaLink(link) {
  navigator.clipboard.writeText(link).then(() => {
    invitoMsg.value = 'Link copiato negli appunti!'
    invitoError.value = false
  }).catch(() => {
    invitoError.value = true
    invitoMsg.value = 'Impossibile copiare il link'
  })
}

// Track mister assignments: { utenteId: { categoriaId: true/false } }
const misterMap = ref({})

function formatData(d) {
  if (!d) return ''
  return d.split('-').reverse().join('/')
}

function cambiaSocieta() {
  router.push('/login')
}

function onCambiaSocieta() {
  load()
}

function getSocietaNome(societaId) {
  if (!societaId) return ''
  const s = listaSocieta.value.find(s => s.id === societaId)
  return s ? s.nome_breve || s.nome : ''
}

function isMister(u, catId) {
  return misterMap.value[u.id]?.[catId] !== undefined
}

async function toggleMister(u, catId, event) {
  const checked = event.target.checked
  if (!misterMap.value[u.id]) {
    misterMap.value[u.id] = {}
  }
  
  if (checked) {
    // Add with the user's ruolo (mister or dirigente)
    misterMap.value[u.id][catId] = u.ruolo || 'mister'
  } else {
    delete misterMap.value[u.id][catId]
  }
  
  // Save to backend - get all category IDs for this user
  const utenteIds = Object.keys(misterMap.value[u.id] || {}).map(id => parseInt(id))
  
  await assegnaCategorie(u.id, utenteIds)
}

async function load() {
  if (loading.value) return
  loading.value = true
  try {
    // Prima carica la lista società per determinare quale società usare
    let sData = []
    try {
      const sRes = await getSocieta()
      sData = sRes.data || []
    } catch (e) {
      console.error('Errore getSocieta:', e)
      sData = []
    }
    
    listaSocieta.value = sData
    
    // SuperAdmin: usa la società attiva (selezionata dopo login)
    // Admin locale: usa la società assegnata
    const societaId = societaAttiva.value?.id || null
    
    let uData = []
    try {
      const uRes = await getUtenti(societaId)
      uData = uRes.data || []
    } catch (e) {
      console.error('Errore getUtenti:', e)
      uData = []
    }
    
    utenti.value = uData
    
    // Carica le categorie per la società
    let categorieData = []
    if (societaId) {
      try {
        const catRes = await getCategorie(societaId)
        categorieData = catRes.data || []
      } catch (e) {
        console.error('Errore getCategorie:', e)
        categorieData = []
      }
      tutteCategorie.value = categorieData
    } else {
      tutteCategorie.value = []
    }
    
    // Load mister assignments for each category
    for (const cat of categorieData) {
      try {
        const res = await getCategoriaUtenti(cat.id)
        if (res.data) {
          for (const uid of res.data) {
            if (!misterMap.value[uid]) {
              misterMap.value[uid] = {}
            }
            misterMap.value[uid][cat.id] = true
          }
        }
      } catch (e) {
        console.error('Errore getCategoriaUtenti:', e)
      }
    }
  } catch (e) {
    console.error('Errore in load():', e)
  } finally {
    loading.value = false
  }
}

async function eliminaUtente(id) {
  if (!confirm('Eliminare utente?')) return
  await deleteUtente(id)
  await load()
}

async function resetsPassword(id) {
  if (!confirm('Resettare la password?')) return
  await resetPassword(id)
  alert('Password resettata!')
  await load()
}

onMounted(() => {
  load()
  caricaInviti()
})
</script>

<style scoped>
.admin {
  padding: 2rem;
  max-width: 1000px;
  margin: 0 auto;
}

.encryption-section {
  margin-bottom: 2rem;
  animation: slideUp 0.4s ease-out;
}

.encryption-section .section-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 1.5rem;
}

.encryption-section .section-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.encryption-section .section-header svg {
  width: 24px;
  height: 24px;
  color: #f59e0b;
}

.encryption-section .section-header h3 {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}

.encryption-section .section-desc {
  font-size: 0.875rem;
  color: var(--color-text-muted);
  margin-bottom: 1rem;
}

.encryption-section .input-row {
  display: flex;
  gap: 0.75rem;
}

.encryption-section .key-input {
  flex: 1;
  padding: 0.75rem 1rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.9375rem;
}

.encryption-section .key-input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.encryption-section .btn-salva-chiave {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: #f59e0b;
  border: none;
  border-radius: var(--radius-md);
  color: black;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.encryption-section .btn-salva-chiave:hover:not(:disabled) {
  background: #d97706;
}

.encryption-section .btn-salva-chiave:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.encryption-section .btn-salva-chiave.reencrypt {
  background: #059669;
}

.encryption-section .btn-salva-chiave.reencrypt:hover:not(:disabled) {
  background: #047857;
}

.encryption-section .btn-salva-chiave svg {
  width: 18px;
  height: 18px;
}

.encryption-section .chiave-msg {
  margin-top: 0.75rem;
  font-size: 0.875rem;
}

.encryption-section .chiave-msg.error {
  color: #ef4444;
}

.encryption-section .chiave-msg.success {
  color: #10b981;
}

.page-header {
  margin-bottom: 2rem;
  animation: slideUp 0.4s ease-out;
}

.admin h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.02em;
  margin-bottom: 0.25rem;
}

.page-subtitle {
  color: var(--color-text-muted);
  font-size: 1rem;
}

.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  margin-bottom: 1rem;
  animation: slideUp 0.4s ease-out both;
}

.card-create {
  margin-bottom: 1.5rem;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.card-header svg {
  width: 24px;
  height: 24px;
  color: var(--color-primary);
}

.card-header h3 {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-text);
  margin: 0;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
  align-items: end;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.input-group label {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.input-group input {
  width: 100%;
  padding: 0.6rem 0.875rem;
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 0.9375rem;
  color: var(--color-text);
  background: var(--color-bg);
  transition: all var(--transition-fast);
}

.input-group input:focus {
  outline: none;
  border-color: var(--color-primary);
  background: var(--color-surface);
}

.input-group input:disabled {
  background: #e0e0e0;
  cursor: not-allowed;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-size: 0.875rem;
}

.checkbox-label input[type="checkbox"] {
  width: auto;
  padding: 0;
}

.checkbox-label span {
  color: var(--color-text-secondary);
}

.ruolo-select {
  width: 100%;
  padding: 0.6rem 0.875rem;
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 0.9375rem;
  color: var(--color-text);
  background: var(--color-bg);
  cursor: pointer;
}

.ruolo-select:focus {
  outline: none;
  border-color: var(--color-primary);
  background: var(--color-surface);
}

.form-actions {
  margin-top: 1rem;
  display: flex;
  gap: 0.75rem;
}

.btn-primary {
  display: flex;
  align-items: center;
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
  transform: translateY(-1px);
}

.btn-primary svg {
  width: 18px;
  height: 18px;
}

.btn-secondary {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: #6b7280;
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-secondary:hover {
  background: #4b5563;
}

.errore {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1rem;
  padding: 0.75rem 1rem;
  background: rgba(244, 63, 94, 0.1);
  border: 1px solid rgba(244, 63, 94, 0.2);
  border-radius: var(--radius-md);
  color: var(--color-error);
  font-size: 0.875rem;
  font-weight: 500;
}

.errore svg {
  width: 18px;
  height: 18px;
  flex-shrink: 0;
}

.user-card {
  animation-delay: 100ms;
}

.user-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 1rem;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.user-avatar {
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--color-secondary), var(--color-secondary-light));
  border-radius: 50%;
  color: white;
  font-weight: 700;
  font-size: 1.125rem;
}

.user-details {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.user-name {
  font-weight: 600;
  font-size: 1rem;
  color: var(--color-text);
}

.user-fullname {
  font-size: 0.85rem;
  color: var(--color-text-muted);
}

.user-data {
  display: flex;
  gap: 1.5rem;
  font-size: 0.8rem;
  color: var(--color-text-secondary);
}

.user-actions {
  display: flex;
  gap: 0.5rem;
}

.badge-role {
  font-size: 0.6875rem;
  font-weight: 700;
  padding: 0.25rem 0.5rem;
  border-radius: var(--radius-sm);
  letter-spacing: 0.05em;
  width: fit-content;
}

.badge-admin {
  background: #9333ea;
  color: white;
}

.badge-mister {
  background: var(--color-primary);
  color: white;
}

.badge-dirigente {
  background: #2563eb;
  color: white;
}

.badge-segreteria {
  background: #7c3aed;
  color: white;
}

.badge-infermeria {
  background: #059669;
  color: white;
}

.badge-superadmin {
  background: #f59e0b;
  color: black;
}

.badge-societa {
  background: #6b7280;
  color: white;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 0.65rem;
  font-weight: 600;
  margin-left: 0.5rem;
}

.btn-edit {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.875rem;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.3);
  border-radius: var(--radius-md);
  color: #10b981;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-edit:hover {
  background: #10b981;
  border-color: #10b981;
  color: white;
}

.btn-edit svg {
  width: 16px;
  height: 16px;
}

.btn-delete {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.875rem;
  background: rgba(244, 63, 94, 0.1);
  border: 1px solid rgba(244, 63, 94, 0.2);
  border-radius: var(--radius-md);
  color: var(--color-error);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-delete:hover {
  background: var(--color-error);
  border-color: var(--color-error);
  color: white;
}

.btn-delete svg {
  width: 16px;
  height: 16px;
}

.btn-reset {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.875rem;
  background: rgba(59, 130, 246, 0.1);
  border: 1px solid rgba(59, 130, 246, 0.2);
  border-radius: var(--radius-md);
  color: #3b82f6;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-reset:hover {
  background: #3b82f6;
  border-color: #3b82f6;
  color: white;
}

.btn-reset svg {
  width: 16px;
  height: 16px;
}

.categorie-assegna {
  padding-top: 1rem;
  border-top: 1px solid var(--color-border-light);
}

.label {
  display: block;
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--color-text-muted);
  margin-bottom: 0.75rem;
}

.categorie-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.cat-check {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.cat-check:hover {
  border-color: var(--color-primary);
}

.cat-check.selected {
  background: rgba(16, 185, 129, 0.1);
  border-color: var(--color-primary);
}

.cat-check input {
  display: none;
}

.cat-anno {
  font-weight: 700;
  color: var(--color-secondary);
  font-size: 0.875rem;
}

.cat-nome {
  font-size: 0.8125rem;
  color: var(--color-text-secondary);
}

.badge-mister {
  font-size: 0.6rem;
  font-weight: 700;
  background: var(--color-primary);
  color: white;
  padding: 2px 6px;
  border-radius: 4px;
  margin-left: auto;
}

.muted {
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.admin-note {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding-top: 1rem;
  border-top: 1px solid var(--color-border-light);
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.admin-note svg {
  width: 18px;
  height: 18px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 1rem;
}

.header-content {
  flex: 1;
}

.header-actions {
  display: flex;
  gap: 0.5rem;
}

.societa-select {
  padding: 0.5rem 1rem;
  background: var(--color-surface);
  border: 2px solid var(--color-primary);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
}

.societa-select:focus {
  outline: none;
  border-color: var(--color-primary);
}

.btn-societa {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: rgba(220, 38, 38, 0.2);
  border: 1px solid rgba(220, 38, 38, 0.4);
  border-radius: var(--radius-md);
  color: #fff;
  font-size: 0.875rem;
  font-weight: 500;
  text-decoration: none;
  transition: all 0.2s;
}

.btn-societa:hover {
  background: rgba(220, 38, 38, 0.3);
}

.btn-societa svg {
  width: 18px;
  height: 18px;
}

@media (max-width: 640px) {
  .admin { padding: 1.25rem; }
  .form-grid { grid-template-columns: 1fr; }
  .user-header { flex-direction: column; align-items: flex-start; }
  .user-data { flex-direction: column; gap: 0.5rem; }
  .btn-delete { align-self: flex-end; }
}

/* Inviti */
.card-inviti {
  margin-top: 1.5rem;
}

.invito-form {
  margin-top: 1rem;
}

.invito-inputs {
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
  align-items: center;
}

.invito-inputs input {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 0.6rem 1rem;
  color: var(--color-text);
  font-size: 0.9rem;
  flex: 1;
  min-width: 200px;
}

.invito-inputs input:focus {
  outline: none;
  border-color: #dc2626;
}

.inviti-list {
  margin-top: 1.5rem;
  border-top: 1px solid var(--color-border);
  padding-top: 1rem;
}

.inviti-list h4 {
  color: var(--color-text-muted);
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 0.75rem;
}

.invito-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.6rem 0;
  border-bottom: 1px solid var(--color-border);
}

.invito-info {
  display: flex;
  gap: 1rem;
  align-items: center;
  flex-wrap: wrap;
}

.invito-email {
  color: var(--color-text);
  font-weight: 500;
}

.invito-ruolo {
  color: #dc2626;
  font-size: 0.85rem;
  text-transform: uppercase;
}

.invito-societa {
  color: var(--color-text-muted);
  font-size: 0.85rem;
}

.invito-date {
  color: var(--color-text-muted);
  font-size: 0.8rem;
}

.invito-actions {
  display: flex;
  gap: 0.5rem;
}

.btn-copia,
.btn-elimina {
  background: transparent;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 0.4rem;
  color: var(--color-text-muted);
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
}

.btn-copia:hover {
  border-color: #dc2626;
  color: #dc2626;
}

.btn-elimina:hover {
  border-color: #ef4444;
  color: #ef4444;
}

.btn-copia svg,
.btn-elimina svg {
  width: 16px;
  height: 16px;
}

.invito-msg {
  margin-top: 0.5rem;
  font-size: 0.85rem;
}

.invito-msg.success {
  color: #22c55e;
}

.invito-msg.error {
  color: #ef4444;
}

@media (max-width: 640px) {
  .invito-inputs {
    flex-direction: column;
  }
  .invito-inputs input,
  .invito-inputs select {
    width: 100%;
  }
  .invito-row {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }
  .invito-info {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.25rem;
  }
}
</style>
