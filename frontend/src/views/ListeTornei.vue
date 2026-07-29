<template>
  <div class="liste-page">
    <div class="page-header">
      <button class="btn-back" @click="goBack">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
          <path d="M19 12H5M12 19l-7-7 7-7"/>
        </svg>
        Indietro
      </button>
      <h1>Liste Tornei — {{ categoriaNome }}</h1>
    </div>

    <div class="liste-container">
      <div class="liste-sidebar">
        <div class="sidebar-header">
          <h3>Liste</h3>
          <button class="btn-nuova-lista" @click="apriNuovaLista" title="Nuova lista">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
          </button>
        </div>
        <div class="liste-list">
          <div v-for="lista in listeList" :key="lista.id" class="lista-item" :class="{ active: selectedListaId === lista.id }" @click="selectLista(lista.id)">
            <span class="lista-nome">{{ lista.nome }}</span>
            <button class="btn-delete-lista" @click.stop="eliminaLista(lista)" title="Elimina">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                <polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
              </svg>
            </button>
          </div>
          <div v-if="listeList.length === 0" class="no-liste">Nessuna lista creata</div>
        </div>
      </div>

      <div class="liste-main">
        <div v-if="selectedListaId === null" class="empty-state">
          <p>Seleziona o crea una lista per iniziare</p>
        </div>
        <div v-else class="lista-content">
          <div class="lista-toolbar">
            <div class="search-box">
              <input v-model="searchPlayer" placeholder="Cerca giocatore..." class="search-input" />
            </div>
            <button class="btn-export-pdf" @click="exportPdf">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/>
              </svg>
              Esporta PDF
            </button>
          </div>

          <div class="giocatori-selezionati">
            <h3>Giocatori in lista ({{ giocatoriLista.length }})</h3>
            <div v-if="giocatoriLista.length === 0" class="no-giocatori">Nessun giocatore selezionato</div>
            <div v-else class="giocatori-table-wrapper">
              <table class="giocatori-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Cognome</th>
                    <th>Nome</th>
                    <th>Azione</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(g, idx) in giocatoriLista" :key="g.persona_id">
                    <td>{{ idx + 1 }}</td>
                    <td>{{ g.cognome }}</td>
                    <td>{{ g.nome }}</td>
                    <td>
                      <button class="btn-rimuovi" @click="rimuoviGiocatore(g.persona_id)" title="Rimuovi">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                          <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                        </svg>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div class="aggiungi-giocatore">
            <h3>Aggiungi giocatore</h3>
            <div class="giocatori-grid">
              <div v-for="p in giocatoriDisponibili" :key="p.id" class="giocatore-card" @click="aggiungiGiocatore(p.id)">
                <span class="giocatore-cognome">{{ p.cognome }}</span>
                <span class="giocatore-nome">{{ p.nome }}</span>
              </div>
              <div v-if="giocatoriDisponibili.length === 0" class="no-giocatori">Tutti i giocatori sono nella lista</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Nuova Lista -->
    <div v-if="nuovaListaModal.show" class="modal-overlay" @click.self="nuovaListaModal.show = false">
      <div class="modal modal-small">
        <h3>Nuova Lista Torneo</h3>
        <div class="form-field">
          <label>Nome lista</label>
          <input v-model="nuovaListaModal.nome" placeholder="es. Torneo Primavera 2026" @keyup.enter="creaLista" />
        </div>
        <div class="modal-actions">
          <button class="btn-annulla" @click="nuovaListaModal.show = false">Annulla</button>
          <button class="btn-salva" @click="creaLista">Crea</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getPersone, getCategorie, getListeTorneo, creaListaTorneo, eliminaListaTorneo, getGiocatoriLista, aggiungiGiocatoreLista, rimuoviGiocatoreLista } from '../api/index.js'
import { jsPDF } from 'jspdf'
import 'jspdf-autotable'
const route = useRoute()
const router = useRouter()

const categoriaId = parseInt(route.params.id)
const categoriaNome = ref('')
const listeList = ref([])
const selectedListaId = ref(null)
const giocatoriLista = ref([])
const tuttiGiocatori = ref([])
const searchPlayer = ref('')
const nuovaListaModal = ref({ show: false, nome: '' })

const giocatoriDisponibili = computed(() => {
  const idsInLista = new Set(giocatoriLista.value.map(g => g.persona_id))
  let disponibili = tuttiGiocatori.value.filter(p => !idsInLista.has(p.id))
  if (searchPlayer.value.trim()) {
    const s = searchPlayer.value.toLowerCase()
    disponibili = disponibili.filter(p =>
      p.cognome.toLowerCase().includes(s) || p.nome.toLowerCase().includes(s)
    )
  }
  return disponibili.sort((a, b) => a.cognome.localeCompare(b.cognome))
})

async function loadCategoria() {
  try {
    const res = await getCategorie()
    const cat = res.data.find(c => c.id === categoriaId)
    if (cat) categoriaNome.value = cat.nome
  } catch(e) { console.error(e) }
}

async function loadListe() {
  try {
    const res = await getListeTorneo(categoriaId)
    listeList.value = res.data
    if (listeList.value.length > 0 && selectedListaId.value === null) {
      selectLista(listeList.value[0].id)
    }
  } catch(e) { console.error(e) }
}

async function loadGiocatori() {
  try {
    const res = await getPersone(categoriaId)
    tuttiGiocatori.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
  } catch(e) { console.error(e) }
}

async function selectLista(id) {
  selectedListaId.value = id
  try {
    const res = await getGiocatoriLista(id)
    giocatoriLista.value = res.data
  } catch(e) { console.error(e) }
}

async function creaLista() {
  if (!nuovaListaModal.value.nome.trim()) return
  try {
    await creaListaTorneo({
      nome: nuovaListaModal.value.nome.trim(),
      categoria_id: categoriaId
    })
    nuovaListaModal.value = { show: false, nome: '' }
    await loadListe()
  } catch(e) { console.error(e) }
}

async function eliminaLista(lista) {
  if (!confirm(`Eliminare la lista "${lista.nome}"?`)) return
  try {
    await eliminaListaTorneo(lista.id)
    if (selectedListaId.value === lista.id) {
      selectedListaId.value = null
      giocatoriLista.value = []
    }
    await loadListe()
  } catch(e) { console.error(e) }
}

async function aggiungiGiocatore(personaId) {
  try {
    await aggiungiGiocatoreLista(selectedListaId.value, personaId)
    await selectLista(selectedListaId.value)
  } catch(e) { console.error(e) }
}

async function rimuoviGiocatore(personaId) {
  try {
    await rimuoviGiocatoreLista(selectedListaId.value, personaId)
    await selectLista(selectedListaId.value)
  } catch(e) { console.error(e) }
}

function apriNuovaLista() {
  nuovaListaModal.value = { show: true, nome: '' }
}

function goBack() {
  router.push(`/dati/${categoriaId}`)
}

function exportPdf() {
  const lista = listeList.value.find(l => l.id === selectedListaId.value)
  if (!lista || giocatoriLista.value.length === 0) {
    alert('Nessun giocatore da esportare')
    return
  }

  const doc = new jsPDF()
  const pageWidth = doc.internal.pageSize.getWidth()

  doc.setFontSize(18)
  doc.setFont(undefined, 'bold')
  doc.text('Lista Torneo', pageWidth / 2, 20, { align: 'center' })

  doc.setFontSize(12)
  doc.setFont(undefined, 'normal')
  doc.text(lista.nome, pageWidth / 2, 28, { align: 'center' })

  doc.setFontSize(10)
  doc.text(`Categoria: ${categoriaNome.value}`, pageWidth / 2, 34, { align: 'center' })

  const tableData = giocatoriLista.value.map((g, i) => [
    i + 1,
    g.cognome,
    g.nome
  ])

  doc.autoTable({
    startY: 40,
    head: [['#', 'Cognome', 'Nome']],
    body: tableData,
    theme: 'grid',
    headStyles: { fillColor: [220, 38, 38], textColor: 255, fontStyle: 'bold' },
    alternateRowStyles: { fillColor: [245, 245, 245] },
    styles: { fontSize: 10, cellPadding: 5 }
  })

  doc.setFontSize(8)
  doc.text(`Esportato il ${new Date().toLocaleDateString('it-IT')}`, pageWidth / 2, doc.internal.pageSize.getHeight() - 10, { align: 'center' })

  doc.save(`lista_torneo_${lista.nome.replace(/\s+/g, '_')}.pdf`)
}

onMounted(async () => {
  await Promise.all([loadCategoria(), loadListe(), loadGiocatori()])
})
</script>

<style scoped>
.liste-page {
  padding: 1.5rem 2rem 3rem;
  max-width: 1400px;
  margin: 0 auto;
  min-height: 100vh;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.page-header h1 {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--color-text, #f3f4f6);
}

.btn-back {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.875rem;
  border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px;
  background: rgba(255,255,255,0.04);
  color: var(--color-text, #f3f4f6);
  cursor: pointer;
  font-size: 0.875rem;
  transition: all 0.15s;
}

.btn-back:hover {
  background: rgba(255,255,255,0.08);
}

.liste-container {
  display: flex;
  gap: 1.5rem;
  min-height: calc(100vh - 140px);
}

.liste-sidebar {
  width: 260px;
  flex-shrink: 0;
  background: rgba(255,255,255,0.03);
  border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 14px;
  padding: 1rem;
  height: fit-content;
  position: sticky;
  top: 1.5rem;
}

.sidebar-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
}

.sidebar-header h3 {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text, #f3f4f6);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.btn-nuova-lista {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border: 1px solid rgba(168, 85, 247, 0.3);
  border-radius: 8px;
  background: rgba(168, 85, 247, 0.12);
  color: #a78bfa;
  cursor: pointer;
  transition: all 0.15s;
}

.btn-nuova-lista:hover {
  background: rgba(168, 85, 247, 0.25);
}

.liste-list {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.lista-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.15s;
  background: rgba(255,255,255,0.02);
}

.lista-item:hover {
  background: rgba(255,255,255,0.06);
}

.lista-item.active {
  background: rgba(220, 38, 38, 0.12);
  border-color: rgba(220, 38, 38, 0.3);
}

.lista-nome {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-text, #f3f4f6);
}

.btn-delete-lista {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border: none;
  border-radius: 6px;
  background: transparent;
  color: var(--color-text-muted, #6b7280);
  cursor: pointer;
  opacity: 0;
  transition: all 0.15s;
}

.lista-item:hover .btn-delete-lista {
  opacity: 1;
}

.btn-delete-lista:hover {
  background: rgba(239, 68, 68, 0.15);
  color: #f87171;
}

.no-liste {
  text-align: center;
  padding: 1.5rem 0.5rem;
  color: var(--color-text-muted, #6b7280);
  font-size: 0.8125rem;
}

.liste-main {
  flex: 1;
  min-width: 0;
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 300px;
  color: var(--color-text-muted, #6b7280);
  font-size: 0.9375rem;
}

.lista-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
  gap: 1rem;
}

.search-input {
  padding: 0.625rem 0.875rem;
  border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px;
  background: rgba(255,255,255,0.04);
  color: var(--color-text, #f3f4f6);
  font-size: 0.875rem;
  width: 280px;
  transition: all 0.15s;
}

.search-input:focus {
  outline: none;
  border-color: rgba(168, 85, 247, 0.4);
  box-shadow: 0 0 0 3px rgba(168, 85, 247, 0.08);
}

.search-input::placeholder {
  color: var(--color-text-muted, #6b7280);
}

.btn-export-pdf {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 1rem;
  border: 1px solid rgba(220, 38, 38, 0.3);
  border-radius: 10px;
  background: rgba(220, 38, 38, 0.12);
  color: #f87171;
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 600;
  transition: all 0.15s;
}

.btn-export-pdf:hover {
  background: rgba(220, 38, 38, 0.2);
}

.giocatori-selezionati h3,
.aggiungi-giocatore h3 {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text, #f3f4f6);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 0.75rem;
}

.giocatori-table-wrapper {
  background: rgba(255,255,255,0.03);
  border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 14px;
  overflow: hidden;
  margin-bottom: 1.5rem;
}

.giocatori-table {
  width: 100%;
  border-collapse: collapse;
}

.giocatori-table th {
  padding: 0.75rem 1rem;
  text-align: left;
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--color-text-muted, #6b7280);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border-bottom: 1px solid var(--color-border, rgba(255,255,255,0.1));
}

.giocatori-table td {
  padding: 0.625rem 1rem;
  font-size: 0.875rem;
  color: var(--color-text, #f3f4f6);
  border-bottom: 1px solid rgba(255,255,255,0.04);
}

.giocatori-table tr:last-child td {
  border-bottom: none;
}

.btn-rimuovi {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: 1px solid rgba(239, 68, 68, 0.2);
  border-radius: 8px;
  background: rgba(239, 68, 68, 0.08);
  color: #f87171;
  cursor: pointer;
  transition: all 0.15s;
}

.btn-rimuovi:hover {
  background: rgba(239, 68, 68, 0.2);
}

.no-giocatori {
  text-align: center;
  padding: 1rem;
  color: var(--color-text-muted, #6b7280);
  font-size: 0.8125rem;
}

.giocatori-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 0.5rem;
}

.giocatore-card {
  display: flex;
  flex-direction: column;
  padding: 0.75rem;
  border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.15s;
  background: rgba(255,255,255,0.02);
}

.giocatore-card:hover {
  background: rgba(168, 85, 247, 0.1);
  border-color: rgba(168, 85, 247, 0.3);
}

.giocatore-cognome {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-text, #f3f4f6);
}

.giocatore-nome {
  font-size: 0.75rem;
  color: var(--color-text-muted, #6b7280);
}

/* Modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal {
  background: #1f2937;
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 16px;
  padding: 1.5rem;
  width: 90%;
  max-width: 400px;
}

.modal h3 {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text, #f3f4f6);
  margin-bottom: 1rem;
}

.form-field {
  margin-bottom: 1rem;
}

.form-field label {
  display: block;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-text-muted, #6b7280);
  margin-bottom: 0.375rem;
}

.form-field input {
  width: 100%;
  padding: 0.625rem 0.875rem;
  border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px;
  background: rgba(255,255,255,0.04);
  color: var(--color-text, #f3f4f6);
  font-size: 0.875rem;
  box-sizing: border-box;
}

.form-field input:focus {
  outline: none;
  border-color: rgba(168, 85, 247, 0.4);
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}

.btn-annulla {
  padding: 0.5rem 1rem;
  border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px;
  background: rgba(255,255,255,0.04);
  color: var(--color-text, #f3f4f6);
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 600;
  transition: all 0.15s;
}

.btn-annulla:hover {
  background: rgba(255,255,255,0.08);
}

.btn-salva {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
  color: white;
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 600;
  transition: all 0.15s;
}

.btn-salva:hover {
  box-shadow: 0 4px 16px rgba(220, 38, 38, 0.35);
}

@media (max-width: 768px) {
  .liste-container {
    flex-direction: column;
  }
  .liste-sidebar {
    width: 100%;
    position: static;
  }
  .giocatori-grid {
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  }
  .search-input {
    width: 100%;
  }
  .lista-toolbar {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>