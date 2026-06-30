<template>
  <div class="allenatori">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <div class="header-left">
          <button class="btn-back" @click="router.push('/')">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
              <line x1="19" y1="12" x2="5" y2="12"/>
              <polyline points="12 19 5 12 12 5"/>
            </svg>
          </button>
          <div class="header-badge">
            <span class="badge-dot"></span>
            <span>{{ currentSeason }}</span>
          </div>
        </div>
        <div v-if="isSuperAdmin" class="societa-switch">
          <button class="btn-societa" @click="vaiSelezioneSocieta">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
              <circle cx="12" cy="7" r="4"/>
            </svg>
            {{ societaAttiva?.nome || 'Seleziona Società' }}
          </button>
        </div>
      </div>
      <div class="header-main">
        <h1 class="page-title">
          <span class="title-gradient">Allenatori</span>
        </h1>
        <p class="header-subtitle">Gestisci categorie, allenamenti e presenze</p>
      </div>
    </header>

    <section class="planning-section">
      <div class="section-header">
        <div class="section-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="22" height="22">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
            <line x1="16" y1="2" x2="16" y2="6"/>
            <line x1="8" y1="2" x2="8" y2="6"/>
            <line x1="3" y1="10" x2="21" y2="10"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Planning Allenamenti</h2>
          <p class="section-subtitle">Programmazione settimanale</p>
        </div>
      </div>

      <div class="planning-grid">
        <div
          v-for="(giorno, idx) in planningSettimana"
          :key="giorno.val"
          class="planning-day"
          :class="{ active: isToday(giorno.val), empty: giorno.categorie.length === 0 }"
          :style="{ animationDelay: idx * 60 + 'ms' }"
        >
          <div class="day-header">
            <span class="day-name">{{ giorno.nome }}</span>
            <div v-if="isToday(giorno.val)" class="today-badge">OGGI</div>
          </div>
          <div class="day-divider"></div>
          <div class="day-content">
            <div v-if="giorno.categorie.length > 0" class="day-cats">
              <div
                v-for="cat in giorno.categorie"
                :key="cat.id"
                class="cat-chip"
                :class="{ portieri: cat.is_portieri }"
                @click="apriRegistro(cat)"
              >
                <span class="chip-dot" :class="{ portieri: cat.is_portieri }"></span>
                <span class="chip-name">{{ cat.nome }}</span>
                <span class="chip-badge">{{ cat.is_portieri ? 'POR' : cat.anno }}</span>
              </div>
            </div>
            <div v-else class="day-empty">
              <span class="empty-icon">—</span>
              <span class="empty-text">Nessun allenamento</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="categorie-section">
      <div class="section-header">
        <div class="section-icon" style="background: linear-gradient(135deg, rgba(34, 197, 94, 0.15) 0%, rgba(34, 197, 94, 0.05) 100%); border-color: rgba(34, 197, 94, 0.2);">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="22" height="22" style="color: #22c55e;">
            <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 00-3-3.87"/>
            <path d="M16 3.13a4 4 0 010 7.75"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Categorie</h2>
          <p class="section-subtitle">{{ categorie.length }} categorie attive</p>
        </div>
      </div>

      <div class="categorie-grid">
        <template v-for="group in categorieGruppo" :key="group.parentId">
          <div v-if="group.parent" class="parent-category-header" @click="toggleParent(group.parentId)">
            <div class="parent-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                <path d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16"/>
                <polyline points="1 10 5 10 11 14"/>
                <polyline points="15 10 21 10 21 14"/>
              </svg>
            </div>
            <div class="parent-info">
              <h3 class="parent-title">{{ group.parent.nome }}</h3>
              <span class="parent-count">{{ group.children.length }} categorie</span>
            </div>
            <svg class="parent-chevron" :class="{ expanded: isParentExpanded(group.parentId) }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <polyline points="6 9 12 15 18 9"/>
            </svg>
          </div>
          <template v-if="isParentExpanded(group.parentId)">
            <div
              v-for="(cat, index) in group.children"
              :key="cat.id"
              class="categoria-card child-card"
              :style="{ animationDelay: index * 50 + 'ms' }"
              @click="apriRegistro(cat)"
            >
              <div class="card-glow"></div>
              <div class="card-pattern"></div>
              <div class="card-top">
                <div class="card-icon-wrap" :class="{ portieri: cat.is_portieri }">
                  <svg v-if="cat.is_portieri" viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24">
                    <rect x="3" y="10" width="5" height="14" rx="2.5" stroke-linecap="round"/>
                    <rect x="10" y="6" width="5" height="18" rx="2.5" stroke-linecap="round"/>
                    <rect x="17" y="8" width="5" height="16" rx="2.5" stroke-linecap="round"/>
                    <rect x="24" y="11" width="5" height="13" rx="2.5" stroke-linecap="round"/>
                    <path d="M3 24 C3 30 8 33 12 33 L24 33 C28 33 29 30 29 24" stroke-linecap="round"/>
                    <rect x="40" y="10" width="5" height="14" rx="2.5" stroke-linecap="round"/>
                    <rect x="33" y="6" width="5" height="18" rx="2.5" stroke-linecap="round"/>
                    <rect x="26" y="8" width="5" height="16" rx="2.5" stroke-linecap="round"/>
                    <rect x="19" y="11" width="5" height="13" rx="2.5" stroke-linecap="round"/>
                    <path d="M45 24 C45 30 40 33 36 33 L24 33 C20 33 19 30 19 24" stroke-linecap="round"/>
                  </svg>
                  <span v-else class="card-year">{{ cat.anno }}</span>
                </div>
                <div class="card-actions" v-if="utenteAttivo?.is_admin || utenteAttivo?.ruolo === 'mister'">
                  <button class="btn-action" @click.stop="apriModifica(cat)" title="Modifica">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                      <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                      <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
                    </svg>
                  </button>
                  <button v-if="utenteAttivo?.is_admin" class="btn-action btn-danger" @click.stop="eliminaCategoria(cat.id)" title="Elimina">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                      <polyline points="3 6 5 6 21 6"/>
                      <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                    </svg>
                  </button>
                </div>
              </div>
              <div class="card-text">
                <h3 class="card-title">{{ cat.nome }}</h3>
                <div class="card-meta">
                  <div v-if="cat.giorni" class="meta-row">
                    <span class="meta-label">Giorni</span>
                    <div class="giorni-badges">
                      <span class="giorno-badge" v-for="g in cat.giorni.split(',').slice(0, 3)" :key="g">
                        {{ nomiBreviGiorni(parseInt(g)) }}
                      </span>
                      <span v-if="cat.giorni.split(',').length > 3" class="giorno-badge more">
                        +{{ cat.giorni.split(',').length - 3 }}
                      </span>
                    </div>
                  </div>
                  <div v-if="getMistersCat(cat.id).length > 0" class="meta-row">
                    <span class="meta-label">Mister</span>
                    <div class="people-badges">
                      <span class="person-badge mister" v-for="m in getMistersCat(cat.id)" :key="m.id">
                        {{ m.cognome }}
                      </span>
                    </div>
                  </div>
                  <div v-if="getDirigentiCat(cat.id).length > 0" class="meta-row">
                    <span class="meta-label">Dirigente</span>
                    <div class="people-badges">
                      <span class="person-badge dirigente" v-for="d in getDirigentiCat(cat.id)" :key="d.id">
                        {{ d.cognome }}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
              <div class="card-arrow">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                  <path d="M5 12h14M12 5l7 7-7 7"/>
                </svg>
              </div>
            </div>
          </template>
        </template>

        <div v-if="utenteAttivo?.is_admin" class="categoria-card nuova" @click="apriNuova">
          <div class="nuova-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="28" height="28">
              <line x1="12" y1="5" x2="12" y2="19"/>
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
          </div>
          <span class="nuova-text">Nuova Categoria</span>
        </div>
      </div>
    </section>

    <Teleport to="body">
      <div v-if="modal.show" class="modal-overlay">
        <div class="modal">
          <div class="modal-header">
            <h3>{{ modal.id ? 'Modifica Categoria' : 'Nuova Categoria' }}</h3>
            <button class="modal-close" @click="chiudiModal">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>

          <div class="modal-body">
            <div class="form-group" v-if="isSuperAdmin">
              <label>Società *</label>
              <select v-model="societaIdSelezionata" required>
                <option :value="null" disabled>Seleziona società...</option>
                <option v-for="s in listaSocieta" :key="s.id" :value="s.id">{{ s.nome }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Nome</label>
              <input v-model="modal.nome" placeholder="Es. Esordienti" />
            </div>
            <div class="form-group">
              <label>Stagione (anno inizio)</label>
              <input v-model="modal.stagione" placeholder="Es. 2025" type="number" />
            </div>
            <div class="form-group">
              <label>Categoria padre</label>
              <select v-model="modal.parent_id">
                <option :value="null">Nessuna (categoria principale)</option>
                <option v-for="p in categoriePadre" :key="p.id" :value="p.id">{{ p.nome }}</option>
              </select>
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
              <label>Orario di allenamento</label>
              <input type="time" v-model="modal.ora_allenamento" step="900" />
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
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
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
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useRouter } from "vue-router"
import { getCategorie, getAllCategorie, createCategoria, updateCategoria, deleteCategoria, getStagioni, getUtenti, getCategoriaUtenti, assegnaCategoriaUtenti, importaGiocatori as importaGiocatoriApi, getCategoriaResponsabili, getSocieta } from "../api/index.js"
import { useStore as useCategoria } from "../store.js"
const { utenteAttivo, societaAttiva, setSocietaAttiva } = useCategoria()

const router = useRouter()
const { setCategoria, setStagioneCorrente } = useCategoria()
const isSuperAdmin = computed(() => localStorage.getItem('is_super_admin') === 'true')
const listaSocieta = ref([])
const societaIdSelezionata = ref(null)

const currentSeason = computed(() => {
  const m = new Date().getMonth()
  const y = new Date().getFullYear()
  return m >= 7 ? `${y}/${y + 1}` : `${y - 1}/${y}`
})

watch(societaIdSelezionata, (newVal) => {
  if (newVal && isSuperAdmin.value) {
    cambiaSocieta()
  }
})

function cambiaSocieta() {
  const societa = listaSocieta.value.find(s => s.id === societaIdSelezionata.value)
  if (societa) {
    setSocietaAttiva(societa)
    loadCategorie()
    loadStagioni()
  }
}

function vaiSelezioneSocieta() {
  router.push('/login')
}
const categorie = ref([])
const allCategories = ref([])
const expandedParents = ref(new Set())

function toggleParent(parentId) {
  if (expandedParents.value.has(parentId)) {
    expandedParents.value.delete(parentId)
  } else {
    expandedParents.value.add(parentId)
  }
}

function isParentExpanded(parentId) {
  return expandedParents.value.has(parentId)
}

const categorieGruppo = computed(() => {
  const parents = categorie.value.filter(c => c.parent_id === null || c.parent_id === undefined)
  const children = categorie.value.filter(c => c.parent_id !== null && c.parent_id !== undefined)

  const result = []
  for (const parent of parents) {
    const kids = children.filter(c => c.parent_id === parent.id).sort((a, b) => (b.anno || 0) - (a.anno || 0))
    if (kids.length > 0) {
      result.push({ parentId: parent.id, parent, children: kids })
    }
  }

  // Categorie orfane (senza padre ma con parent_id non trovato)
  const groupedIds = new Set(result.flatMap(g => g.children.map(c => c.id)))
  const orphans = children.filter(c => !groupedIds.has(c.id)).sort((a, b) => (b.anno || 0) - (a.anno || 0))
  if (orphans.length > 0) {
    result.push({ parentId: null, parent: null, children: orphans })
  }

  return result
})

const categoriePadre = computed(() => {
  return categorie.value.filter(c => c.parent_id === null || c.parent_id === undefined)
})
const loading = ref(false)
const errore = ref('')
const stagioni = ref({ attiva: [], archiviate: [] })
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

function getMistersCat(catId) {
  return (responsabileMap.value[catId] || []).filter(r => r.ruolo === 'mister')
}

function getDirigentiCat(catId) {
  return (responsabileMap.value[catId] || []).filter(r => r.ruolo === 'dirigente')
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

const modal = ref({ show: false, id: null, nome: "", anno: null, stagione: new Date().getFullYear(), giorniSel: [], ora_allenamento: "", is_portieri: false, parent_id: null, data_inizio_stagione: "", data_fine_stagione: "" })

function chiudiModal() {
  modal.value.show = false
  errore.value = ''
}

function apriNuova() {
  const currentYear = new Date().getMonth() >= 8 ? new Date().getFullYear() : new Date().getFullYear() - 1
  modal.value = { show: true, id: null, nome: "", anno: null, stagione: currentYear, giorniSel: [], ora_allenamento: "", is_portieri: false, parent_id: null, data_inizio_stagione: "", data_fine_stagione: "" }
  modalUtentiSel.value = []
  errore.value = ''
}

async function loadCategorie() {
  try {
    const societaRes = await getSocieta()
    listaSocieta.value = societaRes.data

    if (isSuperAdmin.value) {
      if (!societaAttiva.value && listaSocieta.value.length > 0) {
        setSocietaAttiva(listaSocieta.value[0])
        societaIdSelezionata.value = listaSocieta.value[0].id
      }
    } else if (societaAttiva.value) {
      listaSocieta.value = [societaAttiva.value]
      societaIdSelezionata.value = societaAttiva.value.id
    }

    const meRes = await import("../api/index.js").then(m => m.getMe())
    const me = meRes.data
    const societaIdForApi = societaAttiva.value?.id || null
    const res = await getCategorie(societaIdForApi)
    categorie.value = me.is_super_admin || me.is_admin || me.categorie_ids === null
      ? res.data
      : res.data.filter(c => me.categorie_ids.includes(c.id))

    const allRes = await getAllCategorie(societaIdForApi)
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
      const utentiRes = await getUtenti(societaAttiva.value?.id)
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
    ora_allenamento: cat.ora_allenamento || "",
    is_portieri: cat.is_portieri === 1 || cat.is_portieri === true,
    parent_id: cat.parent_id || null,
    data_inizio_stagione: cat.data_inizio_stagione || "",
    data_fine_stagione: cat.data_fine_stagione || ""
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

  if (isSuperAdmin.value && !societaIdSelezionata.value) {
    errore.value = 'Seleziona una società specifica per creare una categoria'
    return
  }

  loading.value = true

  const societaId = societaAttiva.value?.id || null

  const payload = {
    nome: modal.value.nome,
    anno: modal.value.is_portieri ? null : parseInt(modal.value.anno),
    stagione: parseInt(modal.value.stagione),
    giorni: modal.value.giorniSel.sort().join(",") || null,
    ora_allenamento: modal.value.ora_allenamento || null,
    is_portieri: modal.value.is_portieri,
    parent_id: modal.value.parent_id || null,
    societa_id: societaId,
    data_inizio_stagione: modal.value.data_inizio_stagione || null,
    data_fine_stagione: modal.value.data_fine_stagione || null
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

  if (isSuperAdmin.value && !societaIdSelezionata.value) {
    errore.value = 'Seleziona una società specifica per importare giocatori'
    return
  }

  if (!confirm('Importare i giocatori dalla categoria corrispondente della stagione precedente?')) {
    return
  }

  importLoading.value = true
  errore.value = ''

  const societaId = societaAttiva.value?.id || null

  const payload = {
    nome: modal.value.nome,
    anno: modal.value.is_portieri ? null : parseInt(modal.value.anno),
    stagione: parseInt(modal.value.stagione),
    giorni: modal.value.giorniSel.sort().join(",") || null,
    is_portieri: modal.value.is_portieri,
    societa_id: societaId
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
    const societaId = societaAttiva.value?.id || null
    const res = await getStagioni(societaId)
    stagioni.value = res.data
    if (res.data.attiva && res.data.attiva.length > 0) {
      setStagioneCorrente(res.data.attiva[0])
    }
  } catch (e) {
    console.error('Errore nel caricamento stagioni:', e)
  }
}

onMounted(() => {
  loadCategorie()
  loadStagioni()
})
</script>

<style scoped>
.allenatori {
  position: relative;
  padding: 2.5rem 2rem 4rem;
  max-width: 1100px;
  margin: 0 auto;
  overflow: hidden;
}

/* ── Background Glows ── */
.bg-glow {
  position: fixed;
  border-radius: 50%;
  filter: blur(120px);
  pointer-events: none;
  z-index: 0;
}

.bg-glow-1 {
  width: 500px;
  height: 500px;
  top: -150px;
  left: -100px;
  background: radial-gradient(circle, rgba(34, 197, 94, 0.1) 0%, transparent 70%);
  animation: glowFloat 9s ease-in-out infinite;
}

.bg-glow-2 {
  width: 450px;
  height: 450px;
  bottom: -100px;
  right: -80px;
  background: radial-gradient(circle, rgba(220, 38, 38, 0.08) 0%, transparent 70%);
  animation: glowFloat 11s ease-in-out infinite reverse;
}

@keyframes glowFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(25px, -18px) scale(1.04); }
  66% { transform: translate(-18px, 12px) scale(0.96); }
}

/* ── Header ── */
.page-header {
  position: relative;
  z-index: 1;
  margin-bottom: 2.5rem;
  animation: fadeSlideIn 0.7s ease-out both;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.25rem;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.btn-back {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  cursor: pointer;
  transition: all var(--transition-fast);
  color: var(--color-text-secondary);
  flex-shrink: 0;
}

.btn-back:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: var(--color-primary);
  color: var(--color-text);
}

.header-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(34, 197, 94, 0.1);
  border: 1px solid rgba(34, 197, 94, 0.2);
  border-radius: 100px;
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 600;
  color: #22c55e;
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #22c55e;
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}

.btn-societa {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.6rem 1rem;
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  color: var(--color-text-secondary);
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-societa:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: var(--color-primary);
  color: var(--color-text);
}

.header-main {
  position: relative;
}

.page-title {
  font-size: clamp(2.5rem, 7vw, 4rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.5rem;
}

.title-gradient {
  background: linear-gradient(135deg, #ffffff 0%, #ffffff 40%, #22c55e 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.header-subtitle {
  font-size: 1.125rem;
  color: var(--color-text-muted);
  font-weight: 400;
}

/* ── Section Headers ── */
.section-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.section-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.15) 0%, rgba(220, 38, 38, 0.05) 100%);
  border: 1px solid rgba(220, 38, 38, 0.2);
  border-radius: 14px;
  color: var(--color-primary);
}

.section-title {
  font-size: 1.375rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.02em;
}

.section-subtitle {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  margin-top: 0.125rem;
}

/* ── Planning Section ── */
.planning-section {
  position: relative;
  z-index: 1;
  margin-bottom: 3rem;
  animation: fadeSlideIn 0.7s ease-out 0.15s both;
}

.planning-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.75rem;
}

.planning-day {
  position: relative;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 1rem 0.875rem;
  min-height: 140px;
  display: flex;
  flex-direction: column;
  transition: all var(--transition-base);
  animation: fadeSlideIn 0.5s ease-out both;
}

.planning-day:hover {
  border-color: rgba(255, 255, 255, 0.15);
  transform: translateY(-2px);
}

.planning-day.active {
  background: rgba(220, 38, 38, 0.06);
  border-color: rgba(220, 38, 38, 0.3);
  box-shadow: 0 0 30px rgba(220, 38, 38, 0.08);
}

.planning-day.empty {
  opacity: 0.45;
}

.day-header {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  position: relative;
}

.day-name {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text);
}

.planning-day.active .day-name {
  color: var(--color-primary);
}

.today-badge {
  position: absolute;
  top: 0;
  right: 0;
  font-family: var(--font-mono);
  font-size: 0.5625rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  padding: 0.15rem 0.5rem;
  background: var(--color-primary);
  color: white;
  border-radius: 4px;
}

.day-divider {
  height: 1px;
  background: linear-gradient(90deg, var(--color-border) 0%, transparent 100%);
  margin: 0.625rem 0;
}

.planning-day.active .day-divider {
  background: linear-gradient(90deg, rgba(220, 38, 38, 0.4) 0%, transparent 100%);
}

.day-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.day-cats {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.cat-chip {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.4rem 0.5rem;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.cat-chip:hover {
  background: rgba(220, 38, 38, 0.12);
  border-color: rgba(220, 38, 38, 0.4);
  transform: translateX(2px);
}

.cat-chip.portieri:hover {
  background: rgba(245, 158, 11, 0.12);
  border-color: rgba(245, 158, 11, 0.4);
}

.chip-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: var(--color-primary);
  flex-shrink: 0;
}

.chip-dot.portieri {
  background: var(--color-accent);
}

.chip-name {
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--color-text);
  flex: 1;
  line-height: 1.2;
}

.chip-badge {
  font-family: var(--font-mono);
  font-size: 0.5625rem;
  font-weight: 700;
  padding: 0.1rem 0.375rem;
  background: rgba(255, 255, 255, 0.06);
  color: var(--color-text-secondary);
  border-radius: 4px;
  letter-spacing: 0.05em;
  flex-shrink: 0;
}

.cat-chip:hover .chip-badge {
  background: var(--color-primary);
  color: white;
}

.cat-chip.portieri:hover .chip-badge {
  background: var(--color-accent);
}

.day-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.375rem;
  margin-top: auto;
  padding-top: 0.5rem;
}

.empty-icon {
  font-size: 1rem;
  color: var(--color-border);
  font-weight: 300;
}

.empty-text {
  font-size: 0.625rem;
  color: var(--color-text-muted);
  text-align: center;
}

/* ── Categorie Section ── */
.categorie-section {
  position: relative;
  z-index: 1;
  animation: fadeSlideIn 0.7s ease-out 0.3s both;
}

.categorie-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.parent-category-header {
  grid-column: 1 / -1;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem 1.25rem;
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.12) 0%, rgba(220, 38, 38, 0.04) 100%);
  border: 1px solid rgba(220, 38, 38, 0.2);
  border-radius: 16px;
  cursor: pointer;
  transition: all var(--transition-base);
  margin-bottom: 0.25rem;
}

.parent-category-header:hover {
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.18) 0%, rgba(220, 38, 38, 0.08) 100%);
  border-color: rgba(220, 38, 38, 0.35);
}

.parent-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  background: rgba(220, 38, 38, 0.15);
  border-radius: 10px;
  color: var(--color-primary);
  flex-shrink: 0;
}

.parent-info {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.parent-title {
  font-size: 1.0625rem;
  font-weight: 700;
  color: var(--color-text);
  margin: 0;
}

.parent-count {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  font-weight: 500;
}

.parent-chevron {
  color: var(--color-text-muted);
  transition: transform var(--transition-base);
  flex-shrink: 0;
}

.parent-chevron.expanded {
  transform: rotate(180deg);
}

.child-card {
  margin-left: 0.5rem;
  margin-right: 0.5rem;
}

.categoria-card {
  position: relative;
  display: flex;
  flex-direction: column;
  padding: 1.5rem;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  cursor: pointer;
  transition: all var(--transition-base);
  overflow: hidden;
  animation: fadeSlideIn 0.5s ease-out both;
}

.categoria-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 20px;
  opacity: 0;
  transition: opacity var(--transition-base);
  background: linear-gradient(135deg, rgba(34, 197, 94, 0.1) 0%, rgba(34, 197, 94, 0.03) 100%);
}

.categoria-card:hover {
  transform: translateY(-4px);
  border-color: rgba(34, 197, 94, 0.3);
  box-shadow: 0 8px 32px rgba(34, 197, 94, 0.12), 0 0 0 1px rgba(34, 197, 94, 0.1);
}

.categoria-card:hover::before {
  opacity: 1;
}

.categoria-card:hover .card-glow {
  opacity: 1;
}

.categoria-card:hover .card-arrow {
  opacity: 1;
  transform: translate(0, 0);
}

.categoria-card:hover .card-actions {
  opacity: 1;
}

.card-glow {
  position: absolute;
  inset: 0;
  opacity: 0;
  transition: opacity var(--transition-base);
  background: radial-gradient(circle at 20% 30%, rgba(34, 197, 94, 0.12) 0%, transparent 60%);
  border-radius: 20px;
}

.card-pattern {
  position: absolute;
  inset: 0;
  opacity: 0.03;
  background-image: radial-gradient(circle at 2px 2px, currentColor 1px, transparent 0);
  background-size: 20px 20px;
  pointer-events: none;
  color: #22c55e;
}

.card-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1rem;
  position: relative;
  z-index: 1;
}

.card-icon-wrap {
  width: 52px;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, rgba(34, 197, 94, 0.2) 0%, rgba(34, 197, 94, 0.08) 100%);
  border: 1px solid rgba(34, 197, 94, 0.3);
  border-radius: 14px;
  color: #22c55e;
  flex-shrink: 0;
}

.card-icon-wrap.portieri {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.2) 0%, rgba(245, 158, 11, 0.08) 100%);
  border-color: rgba(245, 158, 11, 0.3);
  color: #fbbf24;
}

.card-year {
  font-size: 1.125rem;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.card-actions {
  display: flex;
  gap: 0.25rem;
  opacity: 0;
  transition: opacity var(--transition-fast);
}

.btn-action {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  color: var(--color-text-muted);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-action:hover {
  background: rgba(255, 255, 255, 0.12);
  border-color: rgba(255, 255, 255, 0.2);
  color: var(--color-text);
}

.btn-action.btn-danger:hover {
  background: rgba(239, 68, 68, 0.15);
  border-color: rgba(239, 68, 68, 0.3);
  color: #ef4444;
}

.card-text {
  flex: 1;
  position: relative;
  z-index: 1;
}

.card-title {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.01em;
  margin-bottom: 0.75rem;
}

.card-meta {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.meta-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.meta-label {
  font-size: 0.625rem;
  font-weight: 600;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  min-width: 48px;
}

.giorni-badges {
  display: flex;
  gap: 0.25rem;
  flex-wrap: wrap;
}

.giorno-badge {
  font-family: var(--font-mono);
  font-size: 0.625rem;
  font-weight: 600;
  padding: 0.15rem 0.4rem;
  background: rgba(255, 255, 255, 0.05);
  border-radius: 4px;
  color: var(--color-text-secondary);
  letter-spacing: 0.04em;
}

.giorno-badge.more {
  background: rgba(34, 197, 94, 0.15);
  color: #22c55e;
}

.people-badges {
  display: flex;
  gap: 0.25rem;
  flex-wrap: wrap;
}

.person-badge {
  font-size: 0.625rem;
  font-weight: 600;
  padding: 0.15rem 0.4rem;
  border-radius: 4px;
  letter-spacing: 0.02em;
}

.person-badge.mister {
  background: rgba(220, 38, 38, 0.12);
  color: #ef4444;
}

.person-badge.dirigente {
  background: rgba(59, 130, 246, 0.12);
  color: #60a5fa;
}

.card-arrow {
  position: absolute;
  right: 1.5rem;
  bottom: 1.5rem;
  opacity: 0;
  transform: translate(-8px, 0);
  transition: all var(--transition-base);
  color: var(--color-text-secondary);
  z-index: 1;
}

/* ── Nuova Card ── */
.categoria-card.nuova {
  border-style: dashed;
  border-color: var(--color-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 200px;
  gap: 0.75rem;
  color: var(--color-text-muted);
}

.categoria-card.nuova:hover {
  border-color: rgba(34, 197, 94, 0.4);
  color: #22c55e;
  background: rgba(34, 197, 94, 0.03);
  box-shadow: 0 8px 32px rgba(34, 197, 94, 0.08);
}

.nuova-icon {
  width: 56px;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  transition: all var(--transition-base);
}

.categoria-card.nuova:hover .nuova-icon {
  background: rgba(34, 197, 94, 0.15);
  border-color: rgba(34, 197, 94, 0.3);
}

.nuova-text {
  font-weight: 600;
  font-size: 0.9375rem;
}

/* ── Modal ── */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  animation: fadeIn 0.2s ease-out;
}

.modal {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  width: 100%;
  max-width: 480px;
  box-shadow: 0 24px 80px rgba(0, 0, 0, 0.4);
  animation: scaleIn 0.3s ease-out;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 1.5rem 0;
}

.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-close {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  cursor: pointer;
  color: var(--color-text-muted);
  border-radius: 8px;
  transition: all var(--transition-fast);
}

.modal-close:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.modal-body {
  padding: 1.25rem 1.5rem;
}

.form-group {
  margin-bottom: 1.25rem;
}

.form-group:last-child {
  margin-bottom: 0;
}

.form-group label {
  display: block;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 0.375rem;
}

.form-group input,
.form-group select {
  width: 100%;
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 0.875rem;
  color: var(--color-text);
  background: rgba(255, 255, 255, 0.03);
  transition: all var(--transition-fast);
  font-family: inherit;
}

.form-group input:focus,
.form-group select:focus {
  outline: none;
  border-color: var(--color-primary);
  background: rgba(255, 255, 255, 0.05);
}

.giorni-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.giorno-check {
  display: flex;
  align-items: center;
  padding: 0.4rem 0.75rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--color-text-secondary);
  transition: all var(--transition-fast);
}

.giorno-check:hover {
  border-color: rgba(34, 197, 94, 0.4);
}

.giorno-check.selected {
  background: rgba(34, 197, 94, 0.1);
  border-color: rgba(34, 197, 94, 0.4);
  color: #22c55e;
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
  padding: 0.4rem 0.75rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--color-text-secondary);
  transition: all var(--transition-fast);
}

.utente-check:hover {
  border-color: rgba(34, 197, 94, 0.4);
}

.utente-check.selected {
  background: rgba(34, 197, 94, 0.1);
  border-color: rgba(34, 197, 94, 0.4);
  color: #22c55e;
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
  font-size: 0.6875rem;
  font-weight: 700;
  color: var(--color-text);
}

.utente-check.selected .utente-avatar {
  background: #22c55e;
  color: white;
}

.utente-nome {
  font-size: 0.8125rem;
}

.muted-text {
  font-size: 0.8125rem;
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
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-text);
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem 1.5rem;
  border-top: 1px solid var(--color-border);
}

.import-section {
  background: rgba(34, 197, 94, 0.05);
  border: 1px solid rgba(34, 197, 94, 0.15);
  border-radius: var(--radius-md);
  padding: 1rem;
  margin-top: 0.5rem;
}

.btn-import {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.625rem 1rem;
  background: rgba(34, 197, 94, 0.1);
  border: 1px solid rgba(34, 197, 94, 0.25);
  border-radius: var(--radius-md);
  color: #22c55e;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  font-family: inherit;
}

.btn-import:hover {
  background: rgba(34, 197, 94, 0.18);
}

.btn-import:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.import-hint {
  font-size: 0.6875rem;
  color: var(--color-text-muted);
  margin-top: 0.5rem;
  text-align: center;
}

.btn-secondary {
  padding: 0.625rem 1.25rem;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  font-family: inherit;
}

.btn-secondary:hover {
  background: rgba(255, 255, 255, 0.1);
  color: var(--color-text);
}

.btn-primary {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 100px;
  padding: 0.625rem 1.5rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  font-family: inherit;
}

.btn-primary:hover:not(:disabled) {
  opacity: 0.9;
  transform: translateY(-1px);
}

.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.spinner-small {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.errore-msg {
  margin: 0 1.5rem 1.25rem;
  padding: 0.625rem 0.875rem;
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.2);
  border-radius: var(--radius-md);
  color: #ef4444;
  font-size: 0.8125rem;
  font-weight: 500;
}

/* ── Animations ── */
@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}

/* ── Responsive ── */
@media (max-width: 1024px) {
  .planning-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

@media (max-width: 768px) {
  .allenatori {
    padding: 1.5rem 1rem 3rem;
  }
  .planning-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 0.5rem;
  }
  .planning-day {
    padding: 0.75rem 0.625rem;
    min-height: 110px;
  }
  .categorie-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 480px) {
  .planning-grid {
    grid-template-columns: 1fr;
  }
  .page-title {
    font-size: 2rem;
  }
  .header-top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }
}
</style>
