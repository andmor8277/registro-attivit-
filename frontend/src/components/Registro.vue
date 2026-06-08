<template>
  <div class="registro-container">
    <div class="toolbar">
      <button @click="prevMese">Prec</button>
      <span class="mese-label">{{ meseLabel }} {{ anno }}</span>
      <button @click="nextMese">Succ</button>
      <button class="btn-aggiungi" @click="modalPersona.show = true">+ Aggiungi Persona</button>
    </div>
    <div class="legenda">
      <span v-for="c in codici" :key="c.codice" :class="['badge', c.tipo]">
        {{ c.codice }} = {{ c.descrizione }}
      </span>
    </div>
    <div v-for="gruppo in gruppi" :key="gruppo" class="gruppo-block">
      <h3>{{ gruppo }}</h3>
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th class="nome-col">Cognome Nome</th>
            <th v-for="g in giorniMese" :key="g" :class="{ weekend: isWeekend(g) }">{{ g }}</th>
            <th>TOT</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(persona, idx) in personePerGruppo(gruppo)" :key="persona.id">
            <td>{{ idx + 1 }}</td>
            <td class="nome-col">{{ persona.cognome }} {{ persona.nome }}</td>
            <td v-for="g in giorniMese" :key="g"
              class="cella" :class="getCodiceClasse(persona.id, g)"
              @click="openEdit(persona, g)">
              {{ getCodice(persona.id, g) }}
            </td>
            <td><strong>{{ totalePresenze(persona.id) }}</strong></td>
            <td><button class="btn-del" @click="eliminaPersona(persona.id)">✕</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal presenze -->
    <div v-if="editModal.show" class="modal-overlay" @click.self="editModal.show = false">
      <div class="modal">
        <h4>{{ editModal.persona.cognome }} {{ editModal.persona.nome }} - {{ editModal.giorno }}/{{ mese }}/{{ anno }}</h4>
        <div class="codici-grid">
          <button v-for="c in codici" :key="c.codice"
            :class="['btn-codice', c.tipo]" @click="salvaPresenza(c.codice)">{{ c.codice }}</button>
          <button class="btn-codice cancella" @click="salvaPresenza(null)">Cancella</button>
        </div>
        <button class="btn-close" @click="editModal.show = false">Chiudi</button>
      </div>
    </div>

    <!-- Modal aggiungi persona -->
    <div v-if="modalPersona.show" class="modal-overlay" @click.self="modalPersona.show = false">
      <div class="modal">
        <h4>Aggiungi Persona</h4>
        <div class="form-group">
          <label>Cognome</label>
          <input v-model="modalPersona.cognome" placeholder="Cognome" />
        </div>
        <div class="form-group">
          <label>Nome</label>
          <input v-model="modalPersona.nome" placeholder="Nome" />
        </div>
        <div class="form-group">
          <label>Gruppo</label>
          <select v-model="modalPersona.gruppo_id">
            <option v-for="g in listaGruppi" :key="g.id" :value="g.id">{{ g.nome }}</option>
          </select>
        </div>
        <div class="modal-actions">
          <button class="btn-salva" @click="salvaPersona">Salva</button>
          <button class="btn-close" @click="modalPersona.show = false">Annulla</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { getPersone, getCodici, getRegistroMese, upsertRegistro, createPersona, deletePersona } from "../api/index.js"

const oggi = new Date()
const anno = ref(oggi.getFullYear())
const mese = ref(oggi.getMonth() + 1)
const persone = ref([])
const codici = ref([])
const registro = ref([])
const listaGruppi = ref([])
const editModal = ref({ show: false, persona: null, giorno: null })
const modalPersona = ref({ show: false, nome: "", cognome: "", gruppo_id: 1 })

const mesiNomi = ["Gennaio","Febbraio","Marzo","Aprile","Maggio","Giugno","Luglio","Agosto","Settembre","Ottobre","Novembre","Dicembre"]
const meseLabel = computed(() => mesiNomi[mese.value - 1])
const giorniMese = computed(() => {
  const n = new Date(anno.value, mese.value, 0).getDate()
  return Array.from({ length: n }, (_, i) => i + 1)
})
const gruppi = computed(() => [...new Set(persone.value.map(p => p.gruppo_nome || "Senza gruppo"))])

function personePerGruppo(g) { return persone.value.filter(p => (p.gruppo_nome || "Senza gruppo") === g) }
function getCodice(personaId, giorno) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(giorno).padStart(2,"0")
  const entry = registro.value.find(r => r.persona_id === personaId && r.data === d)
  return entry ? entry.codice : ""
}
function getCodiceClasse(personaId, giorno) {
  const codice = getCodice(personaId, giorno)
  const c = codici.value.find(x => x.codice === codice)
  return c ? c.tipo : ""
}
function totalePresenze(personaId) { return registro.value.filter(r => r.persona_id === personaId && r.codice === "X").length }
function isWeekend(giorno) { const d = new Date(anno.value, mese.value - 1, giorno); return d.getDay() === 0 || d.getDay() === 6 }
function openEdit(persona, giorno) { editModal.value = { show: true, persona, giorno } }

async function salvaPresenza(codice) {
  const d = anno.value + "-" + String(mese.value).padStart(2,"0") + "-" + String(editModal.value.giorno).padStart(2,"0")
  await upsertRegistro({ persona_id: editModal.value.persona.id, data: d, codice })
  await loadRegistro()
  editModal.value.show = false
}

async function salvaPersona() {
  if (!modalPersona.value.nome || !modalPersona.value.cognome) return
  await createPersona({
    nome: modalPersona.value.nome,
    cognome: modalPersona.value.cognome,
    gruppo_id: modalPersona.value.gruppo_id
  })
  modalPersona.value = { show: false, nome: "", cognome: "", gruppo_id: 1 }
  await loadPersone()
}

async function eliminaPersona(id) {
  if (!confirm("Eliminare questa persona?")) return
  await deletePersona(id)
  await loadPersone()
}

function prevMese() { if (mese.value === 1) { mese.value = 12; anno.value-- } else mese.value-- }
function nextMese() { if (mese.value === 12) { mese.value = 1; anno.value++ } else mese.value++ }
async function loadRegistro() { const res = await getRegistroMese(anno.value, mese.value); registro.value = res.data }
async function loadPersone() { const res = await getPersone(); persone.value = res.data }

onMounted(async () => {
  const [p, c, g] = await Promise.all([
    getPersone(),
    getCodici(),
    fetch(import.meta.env.VITE_API_URL + "/gruppi/").then(r => r.json()).catch(() => [])
  ])
  persone.value = p.data
  codici.value = c.data
  listaGruppi.value = g.length ? g : [
    {id:1, nome:"PRIMO GRUPPO"},{id:2, nome:"SECONDO GRUPPO"},
    {id:3, nome:"TERZO GRUPPO"},{id:4, nome:"PORTIERI"}
  ]
  await loadRegistro()
})
watch([anno, mese], loadRegistro)
</script>

<style scoped>
.registro-container { padding: 1rem; font-family: sans-serif; }
.toolbar { display: flex; align-items: center; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; }
.mese-label { font-size: 1.2rem; font-weight: bold; min-width: 150px; text-align: center; }
.btn-aggiungi { background: #3a3a5c; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer; font-size: 0.9rem; }
.btn-aggiungi:hover { background: #5a5a8c; }
.legenda { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 1rem; }
.badge { padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; }
.badge.presenza { background: #c8f7c5; }
.badge.assenza { background: #ffd6d6; }
.badge.extra { background: #fff3cd; }
.gruppo-block { margin-bottom: 2rem; }
.gruppo-block h3 { background: #3a3a5c; color: white; padding: 6px 12px; border-radius: 4px; }
table { border-collapse: collapse; width: 100%; font-size: 0.8rem; }
th, td { border: 1px solid #ddd; text-align: center; padding: 3px 5px; white-space: nowrap; }
th { background: #f0f0f0; }
.nome-col { text-align: left; min-width: 150px; }
.weekend { background: #f9f9f9; color: #aaa; }
.cella { cursor: pointer; font-weight: bold; }
.cella:hover { background: #e8f4fd; }
.cella.presenza { background: #c8f7c5; }
.cella.assenza { background: #ffd6d6; color: #c00; }
.cella.extra { background: #fff3cd; }
.btn-del { background: none; border: none; color: #ccc; cursor: pointer; font-size: 0.8rem; }
.btn-del:hover { color: #c00; }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 100; }
.modal { background: white; padding: 2rem; border-radius: 8px; min-width: 320px; }
.modal h4 { margin-bottom: 1rem; }
.codici-grid { display: flex; flex-wrap: wrap; gap: 0.5rem; margin: 1rem 0; }
.btn-codice { padding: 8px 16px; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; }
.btn-codice.presenza { background: #c8f7c5; }
.btn-codice.assenza { background: #ffd6d6; }
.btn-codice.extra { background: #fff3cd; }
.btn-codice.cancella { background: #eee; }
.btn-close { margin-top: 0.5rem; padding: 6px 16px; cursor: pointer; }
.form-group { margin-bottom: 0.8rem; display: flex; flex-direction: column; gap: 4px; }
.form-group input, .form-group select { padding: 6px 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 0.9rem; }
.modal-actions { display: flex; gap: 0.5rem; margin-top: 1rem; }
.btn-salva { background: #3a3a5c; color: white; border: none; padding: 8px 20px; border-radius: 4px; cursor: pointer; }
.btn-salva:hover { background: #5a5a8c; }
</style>
