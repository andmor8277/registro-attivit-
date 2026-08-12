<template>
  <div class="resp-cat">
    <header class="page-header">
      <div class="header-content">
        <button class="btn-back" @click="router.push('/responsabili')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <div>
          <h1>Responsabili per Categoria</h1>
          <p class="page-subtitle">Assegna mister e dirigenti alle categorie</p>
        </div>
      </div>
    </header>

    <div class="table-section">
      <h2 class="section-title">
        <span class="section-icon badge-admin">A</span>
        Admin
      </h2>
      <div class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th class="th-nome">Admin</th>
              <th v-for="cat in categorie" :key="cat.id" class="th-cat">
                <span v-if="cat.is_portieri">⭐</span>
                <span v-else>{{ cat.anno }}</span>
                <span class="cat-label">{{ cat.nome }}</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in adminList" :key="a.id">
              <td class="td-nome">
                <span class="persona-name">{{ a.cognome }} {{ a.nome }}</span>
              </td>
              <td v-for="cat in categorie" :key="cat.id" class="td-check">
                <label class="check-cell">
                  <input type="checkbox"
                    :checked="isAssegnato(cat.id, a.id)"
                    @change="toggleAssegna(cat.id, a.id, $event)" />
                  <span class="checkmark"></span>
                </label>
              </td>
              <td class="td-actions">
                <button class="btn-delete" @click="eliminaUtente(a)" title="Elimina utente">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                    <path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/>
                  </svg>
                </button>
              </td>
            </tr>
            <tr v-if="adminList.length === 0">
              <td colspan="999" class="td-empty">Nessun admin disponibile</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="table-section">
      <h2 class="section-title">
        <span class="section-icon badge-mister">M</span>
        Mister
      </h2>
      <div class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th class="th-nome">Mister</th>
              <th v-for="cat in categorie" :key="cat.id" class="th-cat">
                <span v-if="cat.is_portieri">⭐</span>
                <span v-else>{{ cat.anno }}</span>
                <span class="cat-label">{{ cat.nome }}</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in misterList" :key="m.id">
              <td class="td-nome">
                <span class="persona-name">{{ m.cognome }} {{ m.nome }}</span>
              </td>
              <td v-for="cat in categorie" :key="cat.id" class="td-check">
                <label class="check-cell">
                  <input type="checkbox"
                    :checked="isAssegnato(cat.id, m.id)"
                    @change="toggleAssegna(cat.id, m.id, $event)" />
                  <span class="checkmark"></span>
                </label>
              </td>
              <td class="td-actions">
                <button class="btn-delete" @click="eliminaUtente(m)" title="Elimina utente">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                    <path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/>
                  </svg>
                </button>
              </td>
            </tr>
            <tr v-if="misterList.length === 0">
              <td colspan="999" class="td-empty">Nessun mister disponibile</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="table-section">
      <h2 class="section-title">
        <span class="section-icon badge-dirigente">D</span>
        Dirigenti
      </h2>
      <div class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th class="th-nome">Dirigente</th>
              <th v-for="cat in categorie" :key="cat.id" class="th-cat">
                <span v-if="cat.is_portieri">⭐</span>
                <span v-else>{{ cat.anno }}</span>
                <span class="cat-label">{{ cat.nome }}</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in dirigentiList" :key="d.id">
              <td class="td-nome">
                <span class="persona-name">{{ d.cognome }} {{ d.nome }}</span>
              </td>
              <td v-for="cat in categorie" :key="cat.id" class="td-check">
                <label class="check-cell">
                  <input type="checkbox"
                    :checked="isAssegnato(cat.id, d.id)"
                    @change="toggleAssegna(cat.id, d.id, $event)" />
                  <span class="checkmark"></span>
                </label>
              </td>
              <td class="td-actions">
                <button class="btn-delete" @click="eliminaUtente(d)" title="Elimina utente">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                    <path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/>
                  </svg>
                </button>
              </td>
            </tr>
            <tr v-if="dirigentiList.length === 0">
              <td colspan="999" class="td-empty">Nessun dirigente disponibile</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue"
import { useRouter } from "vue-router"
import { getCategorie, getCategoriaResponsabili, getCategoriaUtenti, assegnaCategoriaUtenti, getUtenti, deleteUtente } from "../api/index.js"
import { useStore } from "../store.js"
const router = useRouter()
const { societaAttiva } = useStore()

const categorie = ref([])
const tuttiUtenti = ref([])
const assegnazioneMap = ref({})
const responsabileMap = ref({})

const adminList = computed(() => tuttiUtenti.value.filter(u => u.ruolo === 'admin').sort((a, b) => a.cognome.localeCompare(b.cognome)))
const misterList = computed(() => tuttiUtenti.value.filter(u => u.ruolo === 'mister').sort((a, b) => a.cognome.localeCompare(b.cognome)))
const dirigentiList = computed(() => tuttiUtenti.value.filter(u => u.ruolo === 'dirigente').sort((a, b) => a.cognome.localeCompare(b.cognome)))

function isAssegnato(catId, uid) {
  return (assegnazioneMap.value[catId] || []).includes(uid)
}

async function toggleAssegna(catId, uid, event) {
  const checked = event.target.checked
  let current = [...(assegnazioneMap.value[catId] || [])]
  if (checked) {
    if (!current.includes(uid)) current.push(uid)
  } else {
    current = current.filter(id => id !== uid)
  }
  assegnazioneMap.value[catId] = current
  await assegnaCategoriaUtenti(catId, current)
  await refreshResponsabili(catId)
}

async function eliminaUtente(utente) {
  if (!confirm(`Eliminare l'utente ${utente.cognome} ${utente.nome}?`)) return
  try {
    await deleteUtente(utente.id)
    await load()
  } catch (e) {
    alert('Errore: ' + (e.response?.data?.detail || 'Errore sconosciuto'))
  }
}

async function refreshResponsabili(catId) {
  try {
    const respRes = await getCategoriaResponsabili(catId)
    responsabileMap.value[catId] = respRes.data || []
  } catch (e) {
    console.warn('Errore responsabili', catId, e)
  }
}

async function load() {
  const societaId = societaAttiva.value?.id || null
  const catRes = await getCategorie(societaId)
  categorie.value = (catRes.data || []).filter(c => c.parent_id !== null)

  const utentiRes = await getUtenti(societaId)
  tuttiUtenti.value = (utentiRes.data || []).filter(u => ['admin', 'mister', 'dirigente'].includes(u.ruolo))

  for (const cat of categorie.value) {
    await refreshResponsabili(cat.id)
    try {
      const utentiCatRes = await getCategoriaUtenti(cat.id)
      assegnazioneMap.value[cat.id] = utentiCatRes.data || []
    } catch (e) {
      assegnazioneMap.value[cat.id] = []
    }
  }
}

onMounted(load)
</script>

<style scoped>
.resp-cat {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 2rem;
  animation: slideUp 0.4s ease-out;
}

.header-content {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
}

.btn-back {
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
  flex-shrink: 0;
}

.btn-back:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-back svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
}

.header-content h1 {
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

.table-section {
  margin-bottom: 2.5rem;
  animation: slideUp 0.4s ease-out both;
}

.section-title {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.section-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: var(--radius-sm);
  font-size: 0.8125rem;
  font-weight: 800;
  color: white;
}

.section-icon.badge-admin {
  background: #7c3aed;
}

.section-icon.badge-mister {
  background: #dc2626;
}

.section-icon.badge-dirigente {
  background: #2563eb;
}

.table-wrapper {
  overflow-x: auto;
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-border);
  background: var(--color-surface);
}

table {
  width: 100%;
  border-collapse: collapse;
  min-width: 600px;
  table-layout: fixed;
}

thead th {
  padding: 0.625rem 0;
  font-size: 0.625rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--color-text-muted);
  border-bottom: 1px solid var(--color-border);
  background: var(--color-surface-elevated);
  position: sticky;
  top: 0;
  text-align: center;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.th-nome {
  text-align: left;
  padding: 0.75rem 1rem;
  width: 180px;
}

.th-cat {
  overflow: hidden;
}

.cat-label {
  font-size: 0.625rem;
  font-weight: 500;
  color: var(--color-text-muted);
  display: inline;
}

tbody td {
  padding: 0.75rem 0;
  text-align: center;
  border-bottom: 1px solid var(--color-border-light);
  font-size: 0.875rem;
}

.td-nome {
  text-align: left;
  padding: 0.75rem 1rem;
  width: 180px;
}

.persona-name {
  font-weight: 600;
  color: var(--color-text);
}

.td-check {
  padding: 0.75rem 0;
}

.td-actions {
  text-align: right;
  padding: 0.5rem 0.75rem;
  width: 44px;
}

.check-cell {
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
}

.check-cell input {
  display: none;
}

.checkmark {
  width: 22px;
  height: 22px;
  border: 2px solid var(--color-border);
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all var(--transition-fast);
  background: var(--color-bg);
}

.checkmark::after {
  content: '✓';
  font-size: 14px;
  font-weight: 800;
  color: white;
  opacity: 0;
  transition: opacity var(--transition-fast);
}

.check-cell input:checked + .checkmark {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.check-cell input:checked + .checkmark::after {
  opacity: 1;
}

.check-cell:hover .checkmark {
  border-color: var(--color-primary);
}

.td-empty {
  text-align: center !important;
  padding: 2rem !important;
  color: var(--color-text-muted);
  font-style: italic;
}

.btn-delete {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  margin-left: 0.75rem;
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.2);
  border-radius: var(--radius-sm);
  cursor: pointer;
  color: #ef4444;
  transition: all var(--transition-fast);
}

.btn-delete:hover {
  background: rgba(239, 68, 68, 0.2);
  border-color: rgba(239, 68, 68, 0.4);
}

@media (max-width: 640px) {
  .resp-cat {
    padding: 1.25rem;
  }
}
</style>
