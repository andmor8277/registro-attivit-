<template>
  <div class="home">
    <div class="planning-section">
      <h2 class="section-title">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
          <line x1="16" y1="2" x2="16" y2="6"/>
          <line x1="8" y1="2" x2="8" y2="6"/>
          <line x1="3" y1="10" x2="21" y2="10"/>
        </svg>
        Planning Annuale Allenamenti
      </h2>
      <div class="planning-grid">
        <div v-for="giorno in planningSettimana" :key="giorno.val" class="planning-day" :class="{ today: isToday(giorno.val), empty: giorno.categorie.length === 0 }">
          <div class="day-header">
            <span class="day-name">{{ giorno.nome }}</span>
            <span class="day-date">{{ formatDayDate(giorno.val) }}</span>
          </div>
          <div class="day-categories" v-if="giorno.categorie.length > 0">
            <div 
              v-for="cat in giorno.categorie" 
              :key="cat.id" 
              class="planning-cat"
              @click="apriRegistro(cat)"
            >
              <span class="cat-name">{{ cat.nome }}</span>
              <span class="cat-time">{{ cat.is_portieri ? '🧤' : cat.anno }}</span>
            </div>
          </div>
          <div class="day-empty" v-else>
            Nessun allenamento
          </div>
        </div>
      </div>
    </div>
    
    <header class="page-header">
      <div class="header-content">
        <div>
          <h1>Seleziona Categoria</h1>
          <p class="page-subtitle">Scegli la categoria da gestire</p>
        </div>
        <div class="header-actions" v-if="stagioni.archiviate.length > 0 || utenteAttivo?.is_admin">
          <button v-if="stagioni.archiviate.length > 0" class="btn-archived" @click="mostraStagioniArchiviate = !mostraStagioniArchiviate">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 8v13H3V8M1 3h22v5H1zM10 12h4"/>
            </svg>
            Stagioni Passate ({{ stagioni.archiviate.length }})
          </button>
          <button v-if="utenteAttivo?.is_admin" class="btn-season" @click="apriImpostaStagione">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <path d="M12 6v6l4 2"/>
            </svg>
            Imposta Stagione
          </button>
          <button v-if="utenteAttivo?.is_admin && categorie.length > 0" class="btn-archive" @click="apriArchiviazione">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 8v13H3V8M1 3h22v5H1z"/>
            </svg>
            Archivia Stagione
          </button>
        </div>
      </div>
    </header>
     
    <div v-if="mostraStagioniArchiviate && stagioni.archiviate.length > 0" class="archived-section">
      <h2 class="section-title">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/>
          <polyline points="12 6 12 12 16 14"/>
        </svg>
        Stagioni Archiviate
      </h2>
      <div class="stagioni-grid">
        <div 
          v-for="stagione in stagioni.archiviate" 
          :key="stagione" 
          class="stagione-card archived"
          @click="apriStagioneArchiviata(stagione)"
        >
          <div class="stagione-anno">{{ stagione }}/{{ stagione + 1 }}</div>
          <div class="stagione-label">Archiviata</div>
        </div>
      </div>
    </div>
    
    <div class="categorie-grid">
      <div 
        v-for="(cat, index) in categorie" 
        :key="cat.id" 
        class="categoria-card"
        :style="{ animationDelay: index * 50 + 'ms' }"
        @click="apriRegistro(cat)"
      >
        <div class="card-accent"></div>
          <div class="card-content">
          <div class="cat-anno" :class="{ 'portieri': cat.is_portieri }">
            <span v-if="cat.is_portieri">⭐</span>
            <span v-else>{{ cat.anno }}</span>
          </div>
          <div class="cat-nome">
            {{ cat.nome }}
          </div>
          <div class="cat-giorni" v-if="cat.giorni">
            <span class="giorno-badge" v-for="g in cat.giorni.split(',').slice(0, 3)" :key="g">
              {{ nomiBreviGiorni(parseInt(g)) }}
            </span>
            <span v-if="cat.giorni.split(',').length > 3" class="giorno-badge more">
              +{{ cat.giorni.split(',').length - 3 }}
            </span>
          </div>
          <div class="cat-mister" v-if="getResponsabiliCat(cat.id).length > 0">
            <span class="mister-badge" v-for="m in getResponsabiliCat(cat.id)" :key="m.id">
              {{ m.cognome }}
            </span>
          </div>
          <div class="card-actions" v-if="utenteAttivo?.is_admin || utenteAttivo?.ruolo === 'mister'">
            <button class="btn-icon" @click.stop="apriModifica(cat)" title="Modifica">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
            </button>
            <button v-if="utenteAttivo?.is_admin" class="btn-icon btn-danger" @click.stop="eliminaCategoria(cat.id)" title="Elimina">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                <line x1="10" y1="11" x2="10" y2="17"/>
                <line x1="14" y1="11" x2="14" y2="17"/>
              </svg>
            </button>
          </div>
        </div>
        <div class="card-arrow">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </div>
      </div>
      
      <div v-if="utenteAttivo?.is_admin" class="categoria-card nuova" @click="apriNuova">
        <div class="nuova-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="5" x2="12" y2="19"/>
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
        </div>
        <span>Nuova Categoria</span>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="modal.show" class="modal-overlay" @click.self="chiudiModal">
        <div class="modal" :class="{ 'animate-in': modal.show }">
          <div class="modal-header">
            <h3>{{ modal.id ? 'Modifica Categoria' : 'Nuova Categoria' }}</h3>
            <button class="modal-close" @click="chiudiModal">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          
          <div class="modal-body">
            <div class="form-group">
              <label>Nome</label>
              <input v-model="modal.nome" placeholder="Es. Esordienti" />
            </div>
            <div class="form-group">
              <label>Stagione (anno inizio)</label>
              <input v-model="modal.stagione" placeholder="Es. 2025" type="number" />
            </div>
            <div class="form-group" v-if="!modal.is_portieri">
              <label>Categoria Portieri</label>
              <label class="switch-label">
                <input type="checkbox" v-model="modal.is_portieri" />
                <span class="switch-text">Portieri (tutti gli anni)</span>
              </label>
            </div>
            <div class="form-group" v-if="!modal.is_portieri">
              <label>Anno di nascita</label>
              <input v-model="modal.anno" placeholder="Es. 2014" type="number" />
            </div>
            <div class="form-group">
              <label>Giorni di allenamento</label>
              <div class="giorni-grid">
                <label v-for="g in tuttiGiorni" :key="g.val" class="giorno-check" :class="{ selected: modal.giorniSel.includes(g.val) }">
                  <input type="checkbox" :value="g.val" v-model="modal.giorniSel" />
                  {{ g.nome }}
                </label>
              </div>
            </div>
            <div class="form-group">
              <label>Google Drive Folder ID</label>
              <input v-model="modal.drive_folder_id" placeholder="Es. 1a2b3c4d5e6f..." />
              <p class="form-hint">ID della cartella Google Drive per gli allenamenti</p>
            </div>
            <div class="form-group" v-if="utenteAttivo?.is_admin && modal.id">
              <label>Utenti che possono accedere</label>
              <div class="utenti-grid" v-if="tuttiUtenti.length > 0">
                <label v-for="u in tuttiUtenti" :key="u.id" class="utente-check" :class="{ selected: modalUtentiSel.includes(u.id) }">
                  <input type="checkbox" :value="u.id" v-model="modalUtentiSel" />
                  <span class="utente-avatar">{{ (u.cognome || u.nome || u.username).charAt(0).toUpperCase() }}</span>
                  <span class="utente-nome">{{ u.cognome || u.nome || u.username }}</span>
                </label>
              </div>
              <p v-else class="muted-text">Nessun utente non-admin presente</p>
            </div>
            <div class="form-group import-section" v-if="!modal.id && utenteAttivo?.is_admin">
              <button class="btn-import" @click="importaGiocatori" :disabled="importLoading">
                <span v-if="importLoading" class="spinner-small"></span>
                <template v-else>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M16 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                    <circle cx="8.5" cy="7" r="4"/>
                    <line x1="20" y1="8" x2="20" y2="14"/>
                    <line x1="23" y1="11" x2="17" y2="11"/>
                  </svg>
                  Importa Giocatori dalla Stagione Precedente
                </template>
              </button>
              <p class="import-hint">Importa automaticamente i giocatori dalla categoria corrispondente della stagione precedente</p>
            </div>
          </div>
          
          <div class="modal-footer">
            <button class="btn-secondary" @click="chiudiModal">Annulla</button>
            <button class="btn-primary" @click="salvaCategoria" :disabled="loading">
              <span v-if="loading" class="spinner-small"></span>
              <template v-else>{{ modal.id ? 'Aggiorna' : 'Crea' }}</template>
            </button>
          </div>
          <p v-if="errore" class="errore-msg">{{ errore }}</p>
        </div>
      </div>
    </Teleport>

    <Teleport to="body">
      <div v-if="stagioneModal.show" class="modal-overlay" @click.self="stagioneModal.show = false">
        <div class="modal">
          <div class="modal-header">
            <h3>Imposta Stagione per Tutte le Categorie</h3>
            <button class="modal-close" @click="stagioneModal.show = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <p class="modal-info">Questa operazione assegnerà la stessa stagione a tutte le categorie attive.</p>
            <div class="form-group">
              <label>Stagione Calcistica</label>
              <input v-model="stagioneModal.stagione" placeholder="Es. 2025" type="number" />
              <p class="form-hint">Anno di inizio della stagione (es. 2025 per 2025/2026)</p>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="stagioneModal.show = false">Annulla</button>
            <button class="btn-primary" @click="impostaStagioneTutte" :disabled="stagioneModal.loading">
              <span v-if="stagioneModal.loading" class="spinner-small"></span>
              <template v-else>Applica a Tutti</template>
            </button>
          </div>
          <p v-if="stagioneModal.errore" class="errore-msg">{{ stagioneModal.errore }}</p>
        </div>
      </div>
    </Teleport>

    <Teleport to="body">
      <div v-if="archiviaModal.show" class="modal-overlay" @click.self="archiviaModal.show = false">
        <div class="modal">
          <div class="modal-header">
            <h3>Archivia Stagione</h3>
            <button class="modal-close" @click="archiviaModal.show = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <p class="modal-info">Seleziona la stagione da archiviare. Le categorie diventeranno visibili solo nella sezione "Stagioni Passate".</p>
            <div class="form-group">
              <label>Stagione</label>
              <select v-model="archiviaModal.stagione">
                <option v-for="s in stagioniDisponibili" :key="s" :value="s">
                  {{ s }}/{{ s + 1 }}
                </option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="archiviaModal.show = false">Annulla</button>
            <button class="btn-archive" @click="confermaArchiviazione" :disabled="archiviaModal.loading">
              <span v-if="archiviaModal.loading" class="spinner-small"></span>
              <template v-else>Archivia</template>
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue"
import { useRouter } from "vue-router"
import { getCategorie, getAllCategorie, createCategoria, updateCategoria, deleteCategoria, getStagioni, archiviaStagione, getUtenti, getCategoriaUtenti, assegnaCategoriaUtenti, importaGiocatori as importaGiocatoriApi, getCategoriaResponsabili } from "../api/index.js"
import { useStore as useCategoria } from "../store.js"
const { utenteAttivo } = useCategoria()

const router = useRouter()
const { setCategoria, setStagioneCorrente } = useCategoria()
const categorie = ref([])
const allCategories = ref([])
const loading = ref(false)
const errore = ref('')
const stagioni = ref({ attiva: [], archiviate: [] })
const mostraStagioniArchiviate = ref(false)
const stagioneModal = ref({ show: false, stagione: new Date().getFullYear(), loading: false, errore: '' })
const archiviaModal = ref({ show: false, loading: false, stagione: null })

const stagioniDisponibili = computed(() => {
  const stagioniSet = new Set()
  categorie.value.forEach(c => {
    if (c.stagione) stagioniSet.add(c.stagione)
  })
  return Array.from(stagioniSet).sort((a, b) => b - a)
})
const tuttiUtenti = ref([])
const modalUtentiSel = ref([])
const importLoading = ref(false)
const responsabileMap = ref({})

const tuttiGiorni = [
  { val: 1, nome: "Lunedì" },
  { val: 2, nome: "Martedì" },
  { val: 3, nome: "Mercoledì" },
  { val: 4, nome: "Giovedì" },
  { val: 5, nome: "Venerdì" },
  { val: 6, nome: "Sabato" },
  { val: 0, nome: "Domenica" }
]

const nomiBreviGiorni = (val) => tuttiGiorni.find(g => g.val === val)?.nome?.slice(0, 3) || ''

function getResponsabiliCat(catId) {
  return responsabileMap.value[catId] || []
}

const planningSettimana = computed(() => {
  return tuttiGiorni.map(g => {
    const cats = allCategories.value.filter(c => {
      if (!c.giorni) return false
      const giorniCat = c.giorni.split(',').map(Number)
      return giorniCat.includes(g.val)
    })
    return { ...g, categorie: cats }
  })
})

function isToday(giornoVal) {
  return new Date().getDay() === giornoVal
}

function formatDayDate(giornoVal) {
  const oggi = new Date()
  const diff = (giornoVal - oggi.getDay() + 7) % 7
  const data = new Date(oggi)
  data.setDate(oggi.getDate() + diff)
  return data.toLocaleDateString('it-IT', { day: 'numeric', month: 'short' })
}

const modal = ref({ show: false, id: null, nome: "", anno: null, stagione: new Date().getFullYear(), giorniSel: [], is_portieri: false, drive_folder_id: "" })

function chiudiModal() {
  modal.value.show = false
  errore.value = ''
}

function apriNuova() {
  const currentYear = new Date().getMonth() >= 8 ? new Date().getFullYear() : new Date().getFullYear() - 1
  modal.value = { show: true, id: null, nome: "", anno: null, stagione: currentYear, giorniSel: [], is_portieri: false, drive_folder_id: "" }
  modalUtentiSel.value = []
  errore.value = ''
}

async function loadCategorie() {
  try {
    const meRes = await import("../api/index.js").then(m => m.getMe())
    const me = meRes.data
    const res = await getCategorie()
    categorie.value = me.is_admin || me.categorie_ids === null
      ? res.data
      : res.data.filter(c => me.categorie_ids.includes(c.id))
    
    const allRes = await getAllCategorie()
    allCategories.value = allRes.data
    
    for (const cat of categorie.value) {
      try {
        const respRes = await getCategoriaResponsabili(cat.id)
        if (respRes.data && respRes.data.length > 0) {
          responsabileMap.value[cat.id] = respRes.data
        }
      } catch (e) {
        console.warn('Errore caricamento responsabili per categoria', cat.id)
      }
    }
    
    if (me?.is_admin) {
      const utentiRes = await getUtenti()
      tuttiUtenti.value = utentiRes.data.filter(u => !u.is_admin)
    }
  } catch (e) {
    console.error('Errore loadCategorie:', e)
  }
}

async function apriModifica(cat) {
  modal.value = {
    show: true, id: cat.id, nome: cat.nome, anno: cat.anno, stagione: cat.stagione,
    giorniSel: cat.giorni ? cat.giorni.split(",").map(Number) : [],
    is_portieri: cat.is_portieri === 1 || cat.is_portieri === true,
    drive_folder_id: cat.drive_folder_id || ""
  }
  
  if (utenteAttivo.value?.is_admin && cat.id) {
    try {
      const res = await getCategoriaUtenti(cat.id)
      modalUtentiSel.value = res.data || []
    } catch {
      modalUtentiSel.value = []
    }
  }
  
  errore.value = ''
}

function apriRegistro(cat) {
  setCategoria(cat)
  router.push("/scelta/" + cat.id)
}

async function salvaCategoria() {
  errore.value = ''
  
  if (!modal.value.nome) {
    errore.value = 'Inserisci il nome della categoria'
    return
  }
  
  if (!modal.value.stagione) {
    errore.value = 'Inserisci la stagione'
    return
  }
  
  if (!modal.value.is_portieri && !modal.value.anno) {
    errore.value = 'Inserisci l\'anno di nascita per le categorie non-portieri'
    return
  }
  
  loading.value = true
  
  const payload = {
    nome: modal.value.nome,
    anno: modal.value.is_portieri ? null : parseInt(modal.value.anno),
    stagione: parseInt(modal.value.stagione),
    giorni: modal.value.giorniSel.sort().join(",") || null,
    is_portieri: modal.value.is_portieri,
    drive_folder_id: modal.value.drive_folder_id || null
  }
  
  try {
    if (modal.value.id) {
      await updateCategoria(modal.value.id, payload)
      if (utenteAttivo.value?.is_admin) {
        await assegnaCategoriaUtenti(modal.value.id, modalUtentiSel.value)
      }
    } else {
      await createCategoria(payload)
    }
    
    modal.value.show = false
    await loadCategorie()
  } catch (e) {
    errore.value = e.response?.data?.detail || 'Errore durante il salvataggio'
  } finally {
    loading.value = false
  }
}

async function importaGiocatori() {
  if (!modal.value.nome || !modal.value.stagione) {
    errore.value = 'Prima compila nome e stagione'
    return
  }
  
  if (!modal.value.is_portieri && !modal.value.anno) {
    errore.value = 'Per importare i giocatori, inserisci l\'anno di nascita'
    return
  }
  
  if (!confirm('Importare i giocatori dalla categoria corrispondente della stagione precedente?')) {
    return
  }
  
  importLoading.value = true
  errore.value = ''
  
  const payload = {
    nome: modal.value.nome,
    anno: modal.value.is_portieri ? null : parseInt(modal.value.anno),
    stagione: parseInt(modal.value.stagione),
    giorni: modal.value.giorniSel.sort().join(",") || null,
    is_portieri: modal.value.is_portieri,
    drive_folder_id: modal.value.drive_folder_id || null
  }
  
  try {
    const res = await createCategoria(payload)
    const newCatId = res.data.id
    
    if (newCatId) {
      const importRes = await importaGiocatoriApi(newCatId)
      alert(importRes.data.messaggio || `Importati ${importRes.data.giocatori_importati} giocatori`)
    }
    
    modal.value.show = false
    await loadCategorie()
  } catch (e) {
    errore.value = e.response?.data?.detail || 'Errore durante l\'importazione'
  } finally {
    importLoading.value = false
  }
}

async function eliminaCategoria(id) {
  if (!confirm("Eliminare questa categoria e tutte le presenze?")) return
  await deleteCategoria(id)
  await loadCategorie()
}

async function loadStagioni() {
  try {
    const res = await getStagioni()
    stagioni.value = res.data
    if (res.data.attiva && res.data.attiva.length > 0) {
      setStagioneCorrente(res.data.attiva[0])
    }
  } catch (e) {
    console.error('Errore nel caricamento stagioni:', e)
  }
}

function apriArchiviazione() {
  if (stagioniDisponibili.value.length === 0) {
    alert('Nessuna stagione da archiviare. Le categorie devono avere una stagione assegnata.')
    return
  }
  
  archiviaModal.value = {
    show: true,
    loading: false,
    stagione: stagioniDisponibili.value[0]
  }
}

async function confermaArchiviazione() {
  if (!archiviaModal.value.stagione) return
  
  archiviaModal.value.loading = true
  try {
    await archiviaStagione(archiviaModal.value.stagione)
    archiviaModal.value.show = false
    await loadCategorie()
    await loadStagioni()
  } catch (e) {
    alert('Errore: ' + (e.response?.data?.detail || 'Errore sconosciuto'))
  } finally {
    archiviaModal.value.loading = false
  }
}

function apriStagioneArchiviata(stagione) {
  setCategoria({ id: null, stagione, is_archived: true, nome: `${stagione}/${stagione + 1}` })
  router.push("/stagione/" + stagione)
}

function apriImpostaStagione() {
  const categorieConStagione = categorie.value.filter(c => c.stagione)
  const stagioneEsistente = categorieConStagione.length > 0 ? categorieConStagione[0].stagione : null
  stagioneModal.value = { 
    show: true, 
    stagione: stagioneEsistente || new Date().getFullYear(), 
    loading: false, 
    errore: '' 
  }
}

async function impostaStagioneTutte() {
  if (!stagioneModal.value.stagione) {
    stagioneModal.value.errore = 'Inserisci la stagione'
    return
  }
  
  if (!confirm(`Impostare la stagione ${stagioneModal.value.stagione}/${stagioneModal.value.stagione + 1} per tutte le ${categorie.value.length} categorie?`)) {
    return
  }
  
  stagioneModal.value.loading = true
  stagioneModal.value.errore = ''
  
  try {
    for (const cat of categorie.value) {
      await updateCategoria(cat.id, {
        nome: cat.nome,
        anno: cat.anno,
        stagione: parseInt(stagioneModal.value.stagione),
        giorni: cat.giorni,
        is_portieri: cat.is_portieri === 1
      })
    }
    stagioneModal.value.show = false
    await loadCategorie()
    await loadStagioni()
  } catch (e) {
    stagioneModal.value.errore = e.response?.data?.detail || 'Errore durante il salvataggio'
  } finally {
    stagioneModal.value.loading = false
  }
}

onMounted(() => {
  loadCategorie()
  loadStagioni()
})
</script>

<style scoped>
.home {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 2rem;
  animation: slideUp 0.4s ease-out;
}

.home h1 {
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

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 1rem;
}

.header-actions {
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.btn-archived, .btn-archive, .btn-season {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.625rem 1rem;
  border-radius: var(--radius-md);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-archived {
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  color: var(--color-text-secondary);
}

.btn-archived:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.btn-season {
  background: rgba(59, 130, 246, 0.1);
  border: 1px solid rgba(59, 130, 246, 0.3);
  color: #3b82f6;
}

.btn-season:hover {
  background: rgba(59, 130, 246, 0.2);
}

.btn-archive {
  background: rgba(245, 158, 11, 0.1);
  border: 1px solid rgba(245, 158, 11, 0.3);
  color: #f59e0b;
}

.btn-archive:hover {
  background: rgba(245, 158, 11, 0.2);
}

.btn-archived svg, .btn-archive svg, .btn-season svg {
  width: 18px;
  height: 18px;
}

.archived-section {
  margin-bottom: 2rem;
  padding: 1.5rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  animation: slideUp 0.4s ease-out;
}

.planning-section {
  margin-bottom: 2rem;
  padding: 1.5rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  animation: slideUp 0.4s ease-out;
}

.planning-section .section-title {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-text);
  margin-bottom: 1.25rem;
}

.planning-section .section-title svg {
  width: 22px;
  height: 22px;
  color: var(--color-primary);
}

.planning-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.75rem;
}

.planning-day {
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 0.75rem;
  min-height: 120px;
  transition: all var(--transition-fast);
}

.planning-day.today {
  border-color: var(--color-primary);
  background: rgba(220, 38, 38, 0.05);
}

.planning-day.empty {
  opacity: 0.6;
}

.day-header {
  margin-bottom: 0.75rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--color-border-light);
}

.day-name {
  display: block;
  font-weight: 600;
  font-size: 0.875rem;
  color: var(--color-text);
}

.day-date {
  display: block;
  font-size: 0.75rem;
  color: var(--color-text-muted);
}

.planning-day.today .day-name {
  color: var(--color-primary);
}

.day-categories {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.planning-cat {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.375rem 0.5rem;
  background: white;
  border: 1px solid var(--color-border-light);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.planning-cat:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

.planning-cat .cat-name {
  font-size: 0.75rem;
  font-weight: 500;
}

.planning-cat .cat-time {
  font-size: 0.625rem;
  font-weight: 700;
  color: var(--color-text-muted);
}

.planning-cat:hover .cat-time {
  color: rgba(255,255,255,0.8);
}

.day-empty {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  font-style: italic;
  text-align: center;
  padding-top: 0.5rem;
}

@media (max-width: 1024px) {
  .planning-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

@media (max-width: 768px) {
  .planning-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 480px) {
  .planning-grid {
    grid-template-columns: 1fr;
  }
}

.section-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  margin-bottom: 1rem;
}

.section-title svg {
  width: 20px;
  height: 20px;
  color: var(--color-text-muted);
}

.stagioni-grid {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.stagione-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1rem 1.5rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  min-width: 140px;
}

.stagione-card:hover {
  border-color: var(--color-primary);
  transform: translateY(-2px);
}

.stagione-card.archived {
  border-color: rgba(107, 114, 128, 0.3);
}

.stagione-card.archived:hover {
  border-color: var(--color-text-muted);
}

.stagione-anno {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-text);
}

.stagione-card.archived .stagione-anno {
  color: var(--color-text-secondary);
}

.stagione-label {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  margin-top: 0.25rem;
}

.categorie-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1.25rem;
}

.categoria-card {
  position: relative;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 1.5rem;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
  animation: slideUp 0.4s ease-out both;
}

.categoria-card:hover {
  border-color: var(--color-primary);
  box-shadow: var(--shadow-lg);
  transform: translateY(-4px);
}

.categoria-card:hover .card-arrow {
  opacity: 1;
  transform: translateX(0);
}

.card-accent {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: linear-gradient(90deg, var(--color-primary), var(--color-primary-light));
}

.card-content {
  position: relative;
  z-index: 1;
}

.cat-anno {
  font-size: 2.5rem;
  font-weight: 800;
  color: #dc2626;
  line-height: 1;
  margin-bottom: 0.5rem;
  letter-spacing: -0.03em;
}

.cat-anno.portieri {
  display: flex;
  align-items: center;
  justify-content: center;
}

.gloves-icon {
  width: 48px;
  height: 48px;
  color: #f59e0b;
}

.cat-nome {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-text);
  margin-bottom: 0.75rem;
}

.cat-giorni {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.giorno-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.5rem;
  background: var(--color-bg);
  border-radius: var(--radius-sm);
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-text-secondary);
}

.giorno-badge.more {
  background: var(--color-primary);
  color: white;
}

.cat-mister {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.75rem;
}

.mister-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.4rem;
  background: rgba(220, 38, 38, 0.1);
  border: 1px solid rgba(220, 38, 38, 0.3);
  border-radius: var(--radius-sm);
  font-size: 0.7rem;
  font-weight: 600;
  color: #dc2626;
}

.badge-portieri {
  display: inline-block;
  margin-left: 0.5rem;
  padding: 0.25rem 0.5rem;
  background: linear-gradient(135deg, #f59e0b, #d97706);
  border-radius: var(--radius-sm);
  font-size: 0.625rem;
  font-weight: 700;
  color: white;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.cat-portieri-info {
  font-size: 0.875rem;
  color: #f59e0b;
  font-weight: 500;
}

.card-actions {
  position: absolute;
  top: 1rem;
  right: 1rem;
  display: flex;
  gap: 0.25rem;
  opacity: 0;
  transition: opacity var(--transition-fast);
}

.categoria-card:hover .card-actions {
  opacity: 1;
}

.btn-icon {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  border: none;
  border-radius: var(--radius-sm);
  color: var(--color-text-muted);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-icon:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.btn-icon.btn-danger:hover {
  background: rgba(244, 63, 94, 0.1);
  color: var(--color-error);
}

.btn-icon svg {
  width: 16px;
  height: 16px;
}

.card-arrow {
  position: absolute;
  right: 1.5rem;
  bottom: 1.5rem;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-primary);
  border-radius: 50%;
  color: white;
  opacity: 0;
  transform: translateX(-8px);
  transition: all var(--transition-base);
}

.card-arrow svg {
  width: 16px;
  height: 16px;
}

.categoria-card.nuova {
  border-style: dashed;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 180px;
  color: var(--color-text-muted);
  text-align: center;
}

.categoria-card.nuova:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
  background: rgba(16, 185, 129, 0.05);
}

.nuova-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  border-radius: 50%;
  margin-bottom: 0.75rem;
  transition: all var(--transition-base);
}

.categoria-card.nuova:hover .nuova-icon {
  background: var(--color-primary);
  color: white;
}

.nuova-icon svg {
  width: 24px;
  height: 24px;
}

.categoria-card.nuova span {
  font-weight: 600;
  font-size: 0.9375rem;
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
  max-width: 480px;
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
  margin-bottom: 1.25rem;
}

.form-group:last-child {
  margin-bottom: 0;
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

.modal-info {
  background: rgba(59, 130, 246, 0.1);
  border: 1px solid rgba(59, 130, 246, 0.2);
  border-radius: var(--radius-md);
  padding: 0.875rem 1rem;
  color: var(--color-text-secondary);
  font-size: 0.9375rem;
  margin-bottom: 1.25rem;
}

.form-hint {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  margin-top: 0.5rem;
}

.giorni-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.giorno-check {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-text-secondary);
  transition: all var(--transition-fast);
}

.giorno-check:hover {
  border-color: var(--color-primary);
}

.giorno-check.selected {
  background: rgba(16, 185, 129, 0.1);
  border-color: var(--color-primary);
  color: var(--color-primary-dark);
}

.giorno-check input {
  display: none;
}

.utenti-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.utente-check {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-text-secondary);
  transition: all var(--transition-fast);
}

.utente-check:hover {
  border-color: var(--color-primary);
}

.utente-check.selected {
  background: rgba(16, 185, 129, 0.1);
  border-color: var(--color-primary);
}

.utente-check input {
  display: none;
}

.utente-avatar {
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-border);
  border-radius: 50%;
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--color-text);
}

.utente-check.selected .utente-avatar {
  background: var(--color-primary);
  color: white;
}

.utente-nome {
  font-size: 0.875rem;
}

.muted-text {
  font-size: 0.875rem;
  color: var(--color-text-muted);
  font-style: italic;
}

.switch-label {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
  user-select: none;
}

.switch-label input[type="checkbox"] {
  width: 44px;
  height: 24px;
  appearance: none;
  background: var(--color-border);
  border-radius: 12px;
  position: relative;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.switch-label input[type="checkbox"]::before {
  content: '';
  position: absolute;
  top: 2px;
  left: 2px;
  width: 20px;
  height: 20px;
  background: white;
  border-radius: 50%;
  transition: all var(--transition-fast);
}

.switch-label input[type="checkbox"]:checked {
  background: #f59e0b;
}

.switch-label input[type="checkbox"]:checked::before {
  transform: translateX(20px);
}

.switch-text {
  font-size: 0.9375rem;
  font-weight: 500;
  color: var(--color-text);
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem 1.5rem;
  border-top: 1px solid var(--color-border-light);
}

.import-section {
  background: rgba(16, 185, 129, 0.05);
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: var(--radius-md);
  padding: 1rem;
  margin-top: 1rem;
}

.btn-import {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.75rem 1rem;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.3);
  border-radius: var(--radius-md);
  color: #10b981;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-import:hover {
  background: rgba(16, 185, 129, 0.2);
}

.btn-import:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-import svg {
  width: 18px;
  height: 18px;
}

.import-hint {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  margin-top: 0.5rem;
  text-align: center;
}

.btn-secondary {
  padding: 0.75rem 1.25rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-secondary);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-secondary:hover {
  background: var(--color-border);
}

.btn-primary {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 100px;
  padding: 0.75rem 1.5rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-primary:hover:not(:disabled) {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
}

.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
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

.errore-msg {
  margin: 0 1.5rem 1.5rem;
  padding: 0.75rem 1rem;
  background: rgba(244, 63, 94, 0.1);
  border: 1px solid rgba(244, 63, 94, 0.2);
  border-radius: var(--radius-md);
  color: var(--color-error);
  font-size: 0.875rem;
  font-weight: 500;
}

@media (max-width: 640px) {
  .home {
    padding: 1.25rem;
  }
  
  .categorie-grid {
    grid-template-columns: 1fr;
  }
}
</style>
