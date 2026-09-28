<template>
  <div class="cert-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-icon" @click="router.push('/infermeria')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <button class="btn-icon" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
        </button>
      </div>
      <span class="page-title">Certificati Medici</span>
      <div class="header-right">
        <div class="summary-pill">
          <span class="pill-dot" :class="{ 'dot-rosso': scaduti > 0 }"></span>
          <span>{{ totale }} iscritti · {{ scaduti }} scaduti · {{ inScadenza }} in scadenza</span>
        </div>
      </div>
    </header>

    <div class="content">
      <div class="toolbar">
        <div class="search-wrap">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="search-icon">
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input v-model="search" placeholder="Cerca giocatore..." class="search-input" />
        </div>
        <div class="filter-group">
          <button class="btn-filter" :class="{ active: filtro === 'tutti' }" @click="filtro = 'tutti'">Tutti</button>
          <button class="btn-filter" :class="{ active: filtro === 'scaduti' }" @click="filtro = 'scaduti'">
            Scaduti <span class="filter-count">{{ scaduti }}</span>
          </button>
          <button class="btn-filter" :class="{ active: filtro === 'in_scadenza' }" @click="filtro = 'in_scadenza'">
            In Scadenza <span class="filter-count">{{ inScadenza }}</span>
          </button>
          <button class="btn-filter" :class="{ active: filtro === 'senza' }" @click="filtro = 'senza'">
            Senza <span class="filter-count">{{ senzaCertificato }}</span>
          </button>
        </div>
      </div>

      <div class="cat-grid">
        <div
          v-for="cat in categorieOrdinate"
          :key="cat.id"
          class="cat-section"
        >
          <div class="cat-header">
            <span class="cat-anno">{{ cat.anno }}</span>
            <span class="cat-nome">{{ cat.nome }}</span>
            <span class="cat-count">{{ getFilteredPlayers(cat.id).length }} iscritti</span>
          </div>

          <div class="table-wrap">
            <table class="cert-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Nome</th>
                  <th>Cognome</th>
                  <th>Scadenza Certificato</th>
                  <th>Struttura di Rilascio</th>
                  <th>Stato</th>
                  <th class="th-azioni">Azioni</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(p, idx) in getFilteredPlayers(cat.id)" :key="p.id" class="cert-row" :class="getRowClass(p)">
                  <td>{{ idx + 1 }}</td>
                  <td>{{ p.nome }}</td>
                  <td class="col-cognome">{{ p.cognome }}</td>
                  <td
                    class="col-data clickable"
                    :class="{ 'data-rossa': isScaduta(p.scadenza_certificato), 'data-gialla': isInScadenza(p.scadenza_certificato) }"
                    @click="apriModifica(p, cat)"
                    title="Clicca per modificare la scadenza"
                  >
                    <div class="data-cell-content">
                      <span class="data-val">{{ formatData(p.scadenza_certificato) || '—' }}</span>
                      <svg class="cell-pencil" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
                      </svg>
                    </div>
                  </td>
                  <td class="col-struttura">{{ p.struttura_rilascio || '-' }}</td>
                  <td class="col-stato">
                    <span v-if="!p.scadenza_certificato" class="status-badge senza">Senza</span>
                    <span v-else-if="isScaduta(p.scadenza_certificato)" class="status-badge scaduto">Scaduto</span>
                    <span v-else-if="isInScadenza(p.scadenza_certificato)" class="status-badge scadenza">In Scadenza</span>
                    <span v-else class="status-badge valido">Valido</span>
                  </td>
                  <td class="col-azioni" @click.stop>
                    <button class="btn-edit-action" @click="apriModifica(p, cat)" title="Modifica scadenza certificato">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13">
                        <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
                      </svg>
                      <span>Modifica</span>
                    </button>
                  </td>
                </tr>
                <tr v-if="getFilteredPlayers(cat.id).length === 0">
                  <td colspan="7" class="no-data">Nessun giocatore trovato</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Modifica Scadenza Certificato -->
    <Teleport to="body">
      <div v-if="editModal.show" class="modal-overlay" @click.self="chiudiModifica">
        <div class="modal-box">
          <div class="modal-top">
            <div>
              <span class="modal-cat-tag">{{ editModal.categoriaNome }}</span>
              <h3 class="modal-player-name">{{ editModal.giocatore?.cognome }} {{ editModal.giocatore?.nome }}</h3>
            </div>
            <button class="btn-close-modal" @click="chiudiModifica" title="Chiudi">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>

          <div class="modal-body">
            <div class="status-preview-box">
              <span class="status-preview-label">Stato attuale:</span>
              <span v-if="!editModal.giocatore?.scadenza_certificato" class="status-badge senza">Nessun certificato</span>
              <span v-else-if="isScaduta(editModal.giocatore?.scadenza_certificato)" class="status-badge scaduto">
                Scaduto ({{ formatData(editModal.giocatore?.scadenza_certificato) }})
              </span>
              <span v-else-if="isInScadenza(editModal.giocatore?.scadenza_certificato)" class="status-badge scadenza">
                In Scadenza ({{ formatData(editModal.giocatore?.scadenza_certificato) }})
              </span>
              <span v-else class="status-badge valido">
                Valido ({{ formatData(editModal.giocatore?.scadenza_certificato) }})
              </span>
            </div>

            <div class="input-section">
              <label class="input-label" for="scadenza-date-input">Data scadenza certificato medico:</label>
              <input
                id="scadenza-date-input"
                type="date"
                v-model="editModal.scadenza"
                class="date-input-field"
                :disabled="editModal.loading"
              />
            </div>

            <div class="shortcuts-row">
              <span class="shortcuts-label">Imposta rapidamente:</span>
              <div class="shortcuts-btns">
                <button type="button" class="btn-quick-pill" @click="impostaPiuUnAnno" :disabled="editModal.loading">
                  +1 Anno
                </button>
                <button type="button" class="btn-quick-pill" @click="impostaFineStagione" :disabled="editModal.loading">
                  Fine Stagione (30 Giu)
                </button>
                <button type="button" class="btn-quick-pill pill-danger" @click="editModal.scadenza = ''" :disabled="editModal.loading" title="Rimuove la data">
                  Rimuovi data
                </button>
              </div>
            </div>

            <div v-if="editModal.error" class="modal-error-alert">
              {{ editModal.error }}
            </div>
          </div>

          <div class="modal-actions">
            <button type="button" class="btn-modal-cancel" @click="chiudiModifica" :disabled="editModal.loading">
              Annulla
            </button>
            <button type="button" class="btn-modal-save" @click="salvaCertificato" :disabled="editModal.loading">
              <span v-if="editModal.loading" class="spinner-inline"></span>
              <span v-else>Salva Data</span>
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from '../../store.js'
import { getCategorie, getPersone, updateScadenzaCertificato, getLocalDateStr } from '../../api/index.js'

const router = useRouter()
const { utenteAttivo } = useStore()

const categorie = ref([])
const persone = ref([])
const search = ref('')
const filtro = ref('tutti')

const editModal = ref({
  show: false,
  giocatore: null,
  categoriaNome: '',
  scadenza: '',
  loading: false,
  error: null
})

const societaId = computed(() => {
  return utenteAttivo.value?.societa_id || parseInt(localStorage.getItem('societa_id')) || 1
})

onMounted(async () => {
  await loadDati()
})

async function loadDati() {
  try {
    const res = await getCategorie()
    let cats = Array.isArray(res) ? res : (res?.data || [])
    categorie.value = cats.filter(c => c.societa_id === societaId.value && !c.is_archiviata && c.parent_id !== null)
    const validCatIds = new Set(categorie.value.map(c => c.id))

    const pRes = await getPersone()
    const players = Array.isArray(pRes) ? pRes : (pRes?.data || [])
    persone.value = players.filter(p => validCatIds.has(p.categoria_id))
  } catch (e) {
    console.error('Errore caricamento:', e)
  }
}

const categorieOrdinate = computed(() => {
  return [...categorie.value].sort((a, b) => (a.anno || 0) - (b.anno || 0))
})

function isScaduta(data) {
  if (!data) return false
  const oggiStr = getLocalDateStr(new Date())
  const dStr = typeof data === 'string' ? data.split('T')[0] : getLocalDateStr(data)
  return dStr < oggiStr
}

function isInScadenza(data) {
  if (!data) return false
  const dStr = typeof data === 'string' ? data.split('T')[0] : getLocalDateStr(data)
  const d = new Date(dStr + 'T00:00:00')
  const oggi = new Date()
  oggi.setHours(0, 0, 0, 0)
  const diff = (d - oggi) / (1000 * 60 * 60 * 24)
  return diff >= 0 && diff <= 30
}

function getFilteredPlayers(catId) {
  let list = persone.value.filter(p => p.categoria_id === catId)

  if (search.value) {
    const s = search.value.toLowerCase()
    list = list.filter(p =>
      p.nome?.toLowerCase().includes(s) ||
      p.cognome?.toLowerCase().includes(s)
    )
  }

  switch (filtro.value) {
    case 'scaduti':
      return list.filter(p => p.scadenza_certificato && isScaduta(p.scadenza_certificato))
    case 'in_scadenza':
      return list.filter(p => p.scadenza_certificato && isInScadenza(p.scadenza_certificato))
    case 'senza':
      return list.filter(p => !p.scadenza_certificato)
    default:
      return list
  }
}

const totale = computed(() => persone.value.length)
const scaduti = computed(() => persone.value.filter(p => p.scadenza_certificato && isScaduta(p.scadenza_certificato)).length)
const inScadenza = computed(() => persone.value.filter(p => p.scadenza_certificato && isInScadenza(p.scadenza_certificato)).length)
const senzaCertificato = computed(() => persone.value.filter(p => !p.scadenza_certificato).length)

function formatData(d) {
  if (!d) return ''
  if (typeof d === 'string' && d.includes('-')) {
    const parts = d.split('T')[0].split('-')
    if (parts.length === 3) {
      return `${parts[2]}/${parts[1]}/${parts[0]}`
    }
  }
  return new Date(d).toLocaleDateString('it-IT')
}

function getRowClass(p) {
  if (!p.scadenza_certificato) return 'row-senza'
  if (isScaduta(p.scadenza_certificato)) return 'row-scaduto'
  if (isInScadenza(p.scadenza_certificato)) return 'row-scadenza'
  return ''
}

function apriModifica(p, cat) {
  editModal.value = {
    show: true,
    giocatore: p,
    categoriaNome: cat ? `${cat.nome}${cat.anno ? ' (' + cat.anno + ')' : ''}` : '',
    scadenza: p.scadenza_certificato ? String(p.scadenza_certificato).slice(0, 10) : '',
    loading: false,
    error: null
  }
}

function chiudiModifica() {
  if (editModal.value.loading) return
  editModal.value.show = false
  editModal.value.giocatore = null
  editModal.value.error = null
}

function impostaPiuUnAnno() {
  const oggi = new Date()
  oggi.setFullYear(oggi.getFullYear() + 1)
  editModal.value.scadenza = getLocalDateStr(oggi)
}

function impostaFineStagione() {
  const oggi = new Date()
  let anno = oggi.getFullYear()
  if (oggi.getMonth() >= 6) {
    anno += 1
  }
  editModal.value.scadenza = `${anno}-06-30`
}

async function salvaCertificato() {
  if (!editModal.value.giocatore) return
  editModal.value.loading = true
  editModal.value.error = null

  try {
    const nuovaScadenza = editModal.value.scadenza ? editModal.value.scadenza : null
    await updateScadenzaCertificato(editModal.value.giocatore.id, {
      scadenza_certificato: nuovaScadenza
    })

    // Aggiorna sia il riferimento in editModal sia la persona nell'array
    editModal.value.giocatore.scadenza_certificato = nuovaScadenza
    const target = persone.value.find(p => p.id === editModal.value.giocatore.id)
    if (target) {
      target.scadenza_certificato = nuovaScadenza
    }

    chiudiModifica()
  } catch (err) {
    console.error('Errore salvataggio scadenza:', err)
    editModal.value.error = err?.response?.data?.detail || 'Errore durante il salvataggio della scadenza certificato'
  } finally {
    editModal.value.loading = false
  }
}
</script>

<style scoped>
.cert-page {
  min-height: 100vh;
  background: var(--color-bg);
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem;
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  position: sticky;
  top: 0;
  z-index: 100;
}

.header-left {
  display: flex;
  gap: 0.5rem;
}

.btn-icon {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-icon:hover {
  background: #10b981;
  border-color: #10b981;
}

.btn-icon svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
}

.page-title {
  font-size: 1rem;
  font-weight: 600;
}

.header-right {
  display: flex;
  gap: 0.5rem;
}

.summary-pill {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.35rem 0.75rem;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: 100px;
  font-size: 0.75rem;
  color: var(--color-text-secondary);
}

.pill-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10b981;
}

.pill-dot.dot-rosso {
  background: #ef4444;
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

.content {
  padding: 1rem;
}

.toolbar {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.search-wrap {
  flex: 1;
  min-width: 200px;
  position: relative;
}

.search-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--color-text-secondary);
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 0.625rem 1rem 0.625rem 2.25rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
}

.filter-group {
  display: flex;
  gap: 0.35rem;
}

.btn-filter {
  padding: 0.4rem 0.75rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  color: var(--color-text-secondary);
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 0.35rem;
  white-space: nowrap;
}

.btn-filter:hover {
  border-color: rgba(16, 185, 129, 0.4);
  color: var(--color-text);
}

.btn-filter.active {
  background: rgba(16, 185, 129, 0.15);
  border-color: rgba(16, 185, 129, 0.4);
  color: #10b981;
}

.filter-count {
  background: var(--color-slate-soft);
  padding: 0.1rem 0.4rem;
  border-radius: 100px;
  font-size: 0.65rem;
  font-weight: 700;
}

.btn-filter.active .filter-count {
  background: rgba(16, 185, 129, 0.3);
}

.cat-grid {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.cat-section {
  animation: fadeSlideIn 0.4s ease-out both;
}

.cat-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  padding: 0.5rem 0;
}

.cat-anno {
  background: rgba(16, 185, 129, 0.15);
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
  color: #10b981;
}

.cat-nome {
  font-weight: 700;
  font-size: 1rem;
  color: var(--color-text);
}

.cat-count {
  font-size: 0.75rem;
  color: var(--color-text-secondary);
  margin-left: auto;
}

.table-wrap {
  overflow-x: auto;
  background: var(--color-surface);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
}

.cert-table {
  width: 100%;
  border-collapse: collapse;
}

.cert-table th {
  background: var(--color-surface-elevated);
  padding: 0.625rem 0.75rem;
  text-align: left;
  font-weight: 600;
  color: var(--color-text-secondary);
  font-size: 0.7rem;
  text-transform: uppercase;
  white-space: nowrap;
  border-bottom: 1px solid var(--color-border);
}

.cert-table td {
  padding: 0.625rem 0.75rem;
  border-bottom: 1px solid var(--color-border);
  color: var(--color-text);
  font-size: 0.8rem;
}

.cert-row {
  transition: background-color 0.15s;
}

.cert-row:hover {
  background: rgba(16, 185, 129, 0.05);
}

.row-scaduto {
  background: rgba(239, 68, 68, 0.04);
}

.row-scadenza {
  background: rgba(245, 158, 11, 0.04);
}

.row-senza {
  background: rgba(107, 114, 128, 0.04);
}

.col-cognome {
  font-weight: 600;
}

.col-data {
  white-space: nowrap;
  font-weight: 500;
}

.col-data.clickable {
  cursor: pointer;
}

.data-cell-content {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
}

.cell-pencil {
  width: 12px;
  height: 12px;
  opacity: 0.25;
  transition: opacity 0.2s, transform 0.2s;
  color: var(--color-text-secondary);
}

.col-data.clickable:hover .cell-pencil,
.cert-row:hover .cell-pencil {
  opacity: 0.85;
  transform: scale(1.1);
  color: #10b981;
}

.th-azioni {
  text-align: center !important;
  width: 100px;
}

.col-azioni {
  text-align: center;
  white-space: nowrap;
}

.btn-edit-action {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.3rem 0.65rem;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.25);
  border-radius: var(--radius-md);
  color: #10b981;
  font-size: 0.72rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-edit-action:hover {
  background: #10b981;
  border-color: #10b981;
  color: #fff;
  transform: translateY(-1px);
}

.data-rossa {
  color: #ef4444;
  font-weight: 700;
}

.data-gialla {
  color: #f59e0b;
  font-weight: 600;
}

.col-struttura {
  color: var(--color-text-secondary);
  font-size: 0.75rem;
}

.col-stato {
  white-space: nowrap;
}

.status-badge {
  display: inline-block;
  padding: 0.2rem 0.5rem;
  border-radius: 100px;
  font-size: 0.65rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.status-badge.valido {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
}

.status-badge.scaduto {
  background: rgba(239, 68, 68, 0.15);
  color: #ef4444;
}

.status-badge.scadenza {
  background: rgba(245, 158, 11, 0.15);
  color: #f59e0b;
}

.status-badge.senza {
  background: rgba(107, 114, 128, 0.15);
  color: #6b7280;
}

.no-data {
  text-align: center;
  padding: 1.5rem;
  color: var(--color-text-muted);
  font-size: 0.8rem;
}

@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}

/* Modal Scadenza Certificato */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.65);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  animation: fadeIn 0.2s ease-out;
  padding: 1rem;
}

.modal-box {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  width: 100%;
  max-width: 440px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4);
  animation: slideUp 0.25s ease-out;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.modal-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 1.25rem 1.25rem 1rem;
  border-bottom: 1px solid var(--color-border);
}

.modal-cat-tag {
  display: block;
  font-size: 0.72rem;
  font-weight: 600;
  color: #10b981;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 0.25rem;
}

.modal-player-name {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--color-text);
  margin: 0;
}

.btn-close-modal {
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text-secondary);
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-close-modal:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.modal-body {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1.15rem;
}

.status-preview-box {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.65rem 0.85rem;
  background: var(--color-surface-elevated);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
}

.status-preview-label {
  font-size: 0.78rem;
  font-weight: 500;
  color: var(--color-text-secondary);
}

.input-section {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.input-label {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-text);
}

.date-input-field {
  width: 100%;
  padding: 0.65rem 0.85rem;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.9rem;
  font-family: inherit;
  transition: border-color var(--transition-fast), box-shadow var(--transition-fast);
}

.date-input-field:focus {
  outline: none;
  border-color: #10b981;
  box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.2);
}

.shortcuts-row {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.shortcuts-label {
  font-size: 0.72rem;
  font-weight: 500;
  color: var(--color-text-muted);
}

.shortcuts-btns {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.btn-quick-pill {
  padding: 0.35rem 0.65rem;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  color: var(--color-text-secondary);
  font-size: 0.72rem;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-quick-pill:hover {
  border-color: rgba(16, 185, 129, 0.4);
  color: #10b981;
  background: rgba(16, 185, 129, 0.08);
}

.btn-quick-pill.pill-danger:hover {
  border-color: rgba(239, 68, 68, 0.4);
  color: #ef4444;
  background: rgba(239, 68, 68, 0.08);
}

.modal-error-alert {
  padding: 0.6rem 0.85rem;
  background: rgba(239, 68, 68, 0.12);
  border: 1px solid rgba(239, 68, 68, 0.3);
  border-radius: var(--radius-md);
  color: #ef4444;
  font-size: 0.78rem;
  font-weight: 500;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.65rem;
  padding: 1rem 1.25rem;
  border-top: 1px solid var(--color-border);
  background: var(--color-surface-elevated);
}

.btn-modal-cancel {
  padding: 0.55rem 1rem;
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
  background: transparent;
  color: var(--color-text-secondary);
  font-size: 0.825rem;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-modal-cancel:hover:not(:disabled) {
  background: var(--color-surface);
  color: var(--color-text);
}

.btn-modal-save {
  padding: 0.55rem 1.25rem;
  border-radius: var(--radius-md);
  border: none;
  background: #10b981;
  color: #fff;
  font-size: 0.825rem;
  font-weight: 600;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 110px;
  transition: all var(--transition-fast);
}

.btn-modal-save:hover:not(:disabled) {
  background: #059669;
}

.btn-modal-save:disabled,
.btn-modal-cancel:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.spinner-inline {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(12px) scale(0.98); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 768px) {
  .toolbar { flex-direction: column; align-items: stretch; }
  .filter-group { flex-wrap: wrap; }
  .summary-pill { font-size: 0.65rem; }
  .btn-edit-action span { display: none; }
  .btn-edit-action { padding: 0.3rem 0.45rem; }
}

@media (max-width: 480px) {
  .page-header { flex-wrap: wrap; gap: 0.5rem; }
  .header-right { display: none; }
  .modal-box { width: 95%; }
}
</style>
