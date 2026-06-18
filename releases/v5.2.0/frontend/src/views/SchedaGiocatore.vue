<template>
  <div class="scheda-page" :class="{ editing: editMode }">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/segreteria')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
      </div>
      <span class="titolo-toolbar">{{ isNuovo ? 'Nuovo Giocatore' : 'Scheda Giocatore' }}</span>
      <div class="header-right">
        <button class="btn-header" :class="{ active: editMode }" @click="toggleEdit" :title="editMode ? 'Disabilita Modifica' : 'Abilita Modifica'">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
            <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
          </svg>
        </button>
        <button class="btn-header" @click="stampaPDF" title="Esporta PDF">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="6 9 6 2 18 2 18 9"/>
            <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
            <rect x="6" y="14" width="12" height="8"/>
          </svg>
        </button>
      </div>
    </header>

    <div class="scheda-container" ref="schedaContainer">
      <div class="scheda-header">
        <h1>MODULO ISCRIZIONE SCUOLA CALCIO</h1>
        <h2>STAGIONE SPORTIVA 2025-2026</h2>
      </div>

      <div class="scheda-top">
        <div class="col-left">
          <div class="section dati-personali">
            <h3>DATI PERSONALI ATLETA</h3>
            <div class="form-row">
              <div class="form-field">
                <label>MATRICOLA</label>
                <input v-model="giocatoreEdit.matricola" :disabled="!editMode" />
              </div>
              <div class="form-field">
                <label>NR. MAGLIA</label>
                <input v-model="giocatoreEdit.numero_maglia" :disabled="!editMode" type="number" />
              </div>
            </div>
            <div class="form-row">
              <div class="form-field">
                <label>COGNOME</label>
                <input v-model="giocatoreEdit.cognome" :disabled="!editMode" />
              </div>
              <div class="form-field">
                <label>NOME</label>
                <input v-model="giocatoreEdit.nome" :disabled="!editMode" />
              </div>
            </div>
            <div class="form-row">
              <div class="form-field">
                <label>NATO/A IL</label>
                <input v-model="giocatoreEdit.data_nascita" :disabled="!editMode" type="date" />
              </div>
              <div class="form-field">
                <label>SCAD. CERTIFICATO</label>
                <input v-model="giocatoreEdit.scadenza_certificato" :disabled="!editMode" type="date" />
              </div>
            </div>
            <div class="form-row">
              <div class="form-field">
                <label>RESIDENZA</label>
                <input v-model="scheda.residenza" :disabled="!editMode" />
              </div>
              <div class="form-field">
                <label>IN VIA</label>
                <input v-model="scheda.indirizzo" :disabled="!editMode" />
              </div>
            </div>
            <div class="form-row">
              <div class="form-field">
                <label>CITTADINANZA</label>
                <input v-model="scheda.cittadinanza" :disabled="!editMode" />
              </div>
              <div class="form-field">
                <label>CODICE FISCALE</label>
                <input v-model="giocatoreEdit.codice_fiscale" :disabled="!editMode" maxlength="16" />
              </div>
            </div>
          </div>

          <div class="section contatti">
            <h3>DATI CONTATTO</h3>
            <div class="form-row">
              <div class="form-field">
                <label>TEL PAPA'</label>
                <input v-model="scheda.tel_papa" :disabled="!editMode" />
              </div>
              <div class="form-field">
                <label>TEL MAMMA</label>
                <input v-model="scheda.tel_mamma" :disabled="!editMode" />
              </div>
            </div>
            <div class="form-row">
              <div class="form-field">
                <label>EMAIL 1</label>
                <input v-model="scheda.email1" :disabled="!editMode" type="email" />
              </div>
              <div class="form-field">
                <label>EMAIL 2</label>
                <input v-model="scheda.email2" :disabled="!editMode" type="email" />
              </div>
            </div>
            <div class="form-row">
              <div class="form-field">
                <label>PROFESSIONE PAPA'</label>
                <input v-model="scheda.prof_papa" :disabled="!editMode" />
              </div>
              <div class="form-field">
                <label>PROFESSIONE MAMMA</label>
                <input v-model="scheda.prof_mamma" :disabled="!editMode" />
              </div>
            </div>
          </div>
        </div>

        <div class="col-right">
          <div class="section anamnesi">
            <h3>ANAMNESI</h3>
            <div class="form-field full">
              <textarea v-model="scheda.anamnesi" :disabled="!editMode" rows="2"></textarea>
            </div>
          </div>

          <div class="section equipaggiamento">
            <h3>EQUIPAGGIAMENTO</h3>
            <div class="form-row">
              <div class="form-field">
                <label>TAGLIA</label>
                <select v-model="scheda.taglia" :disabled="!editMode">
                  <option value="">Seleziona...</option>
                  <option v-for="t in taglie" :key="t" :value="t">{{ t }}</option>
                </select>
              </div>
            </div>
            <div class="equip-list">
              <label class="equip-title">ELENCO EQUIPAGGIAMENTO INDIVIDUALE</label>
              <div class="equip-grid">
                <div class="equip-col">
                  <div v-for="item in equipSinistra" :key="item" class="equip-item">
                    <span class="checkbox" :class="{ checked: scheda.equip[item] }" @click="toggleEquip(item)"></span>
                    <span class="equip-label">{{ item }}</span>
                  </div>
                </div>
                <div class="equip-col">
                  <div v-for="item in equipDestra" :key="item" class="equip-item">
                    <span class="checkbox" :class="{ checked: scheda.equip[item] }" @click="toggleEquip(item)"></span>
                    <span class="equip-label">{{ item }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="scheda-bottom">
        <div class="col-bottom-left">
          <div class="section pagamenti">
            <h3>SITUAZIONE PAGAMENTI</h3>
            <div class="rate-grid">
              <div class="rate-row rate-totale-input">
                <label>TOTALE DA PAGARE</label>
                <input v-model="rate.totale_da_pagare" :disabled="!editMode" class="rate-input" placeholder="€" />
              </div>
              <div class="rate-row">
                <label>ISCRIZIONE</label>
                <input v-model="rate.iscrizione" :disabled="!editMode" class="rate-input" placeholder="€" />
              </div>
              <div class="rate-row">
                <label>1^ RATA</label>
                <input v-model="rate.rata1" :disabled="!editMode" class="rate-input" placeholder="€" />
              </div>
              <div class="rate-row">
                <label>2^ RATA</label>
                <input v-model="rate.rata2" :disabled="!editMode" class="rate-input" placeholder="€" />
              </div>
              <div class="rate-row">
                <label>3^ RATA</label>
                <input v-model="rate.rata3" :disabled="!editMode" class="rate-input" placeholder="€" />
              </div>
              <div class="rate-row">
                <label>4^ RATA</label>
                <input v-model="rate.rata4" :disabled="!editMode" class="rate-input" placeholder="€" />
              </div>
              <div class="rate-row">
                <label>SALDO</label>
                <input v-model="rate.saldo" :disabled="!editMode" class="rate-input" placeholder="€" />
              </div>
              <div class="rate-row rate-rimane">
                <label>RIMANE DA PAGARE</label>
                <span class="rate-rimane-value">€ {{ rimaneDaPagare.toFixed(2) }}</span>
              </div>
            </div>
          </div>

          <div class="section privacy">
            <h3>AUTORIZZAZIONE ALL'USO DELL'IMMAGINE E PRIVACY DEL MINORE</h3>
            <p class="privacy-text">
              Il sottoscritto genitore/tutore legale acconsente all'utilizzo, da parte della Società Sportiva Dilettantistica,
              delle immagini e dei dati personali del minorenne sopra indicato per finalità connesse all'attività sportiva,
              compresa la diffusione tramite pubblicazioni, siti web, TV, DVD e altri mezzi di comunicazione.
            </p>
            <div class="firma-row">
              <label>FIRMA DEL GENITORE</label>
              <span class="firma-line"></span>
            </div>
            <div class="firma-row">
              <label>FIRMA DEL GENITORE</label>
              <span class="firma-line"></span>
            </div>
            <p class="obbligo-text">
              Il genitore dichiara di essere a conoscenza dell'obbligo di pagamento della quota di iscrizione.
            </p>
          </div>
        </div>

        <div class="col-bottom-right">
          <div class="section note">
            <h3>NOTE</h3>
            <div class="note-area">
              <textarea v-model="scheda.note" :disabled="!editMode" rows="2"></textarea>
            </div>
            <div class="firma-row">
              <label>FIRMA DEL GENITORE</label>
              <span class="firma-line"></span>
            </div>
          </div>
        </div>
      </div>

      <div v-if="editMode" class="save-bar">
        <button class="btn-annulla" @click="toggleEdit">Annulla</button>
        <button class="btn-salva" @click="salvaDati">Salva Modifiche</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getPersone, updatePersona, createPersona, getCategorie } from '../api'
import { useStore } from '../store'

const route = useRoute()
const router = useRouter()

const editMode = ref(false)
const giocatore = ref(null)
const isNuovo = ref(false)
const categoriaIdNuovo = ref(null)
const categoriaNome = ref('')

const giocatoreEdit = reactive({
  cognome: '',
  nome: '',
  data_nascita: '',
  numero_maglia: '',
  matricola: '',
  codice_fiscale: '',
  scadenza_certificato: ''
})

const scheda = reactive({
  residenza: '',
  indirizzo: '',
  cittadinanza: 'ITALIANA',
  tel_papa: '',
  tel_mamma: '',
  email1: '',
  email2: '',
  prof_papa: '',
  prof_mamma: '',
  nome_papa: '',
  nome_mamma: '',
  comune_nato: '',
  anamnesi: '',
  taglia: '',
  equip: {},
  note: ''
})

const rate = reactive({
  totale_da_pagare: '',
  iscrizione: '',
  rata1: '',
  rata2: '',
  rata3: '',
  rata4: '',
  saldo: ''
})

const totalePagato = computed(() => {
  const fields = ['iscrizione', 'rata1', 'rata2', 'rata3', 'rata4', 'saldo']
  return fields.reduce((sum, f) => sum + (parseFloat(rate[f]) || 0), 0)
})

const rimaneDaPagare = computed(() => {
  return (parseFloat(rate.totale_da_pagare) || 0) - totalePagato.value
})

const taglie = ['XXXS', 'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL']
const equipSinistra = [
  'Completo gara', 'Compl. all.to m/estivo', 'Polo Estiva', 
  'Short Estivi', 'Calzettoni 1', 'Calzettoni 2', 'Borsa'
]
const equipDestra = [
  'Piumino', 'Tuta Rappr.', 'Tuta lav. completa', 
  'Kway Antipioggia', 'Maglia m/c Prep.', 'Pallone', 'Maglia Portiere'
]

function toggleEdit() {
  editMode.value = !editMode.value
}

function toggleEquip(item) {
  if (!editMode.value) return
  scheda.equip[item] = !scheda.equip[item]
}

onMounted(async () => {
  const { hideTopbar } = useStore()
  hideTopbar.value = true
  
  const id = route.params.id
  const catId = route.query.categoria_id
  
  if (id === 'nuovo') {
    isNuovo.value = true
    categoriaIdNuovo.value = catId ? parseInt(catId) : null
    editMode.value = true
    return
  }
  
  if (!id) return
  
  try {
    const res = await getPersone()
    const arr = Array.isArray(res) ? res : (res?.data || [])
    giocatore.value = arr.find(p => p.id === parseInt(id))
    
    if (giocatore.value) {
      caricaDatiGiocatore()
      caricaNomeCategoria(giocatore.value.categoria_id)
    }
  } catch(e) {
    console.error('Error loading:', e)
  }
})

function caricaDatiGiocatore() {
  if (!giocatore.value) return
  scheda.residenza = giocatore.value.residenza || ''
  scheda.indirizzo = giocatore.value.indirizzo || ''
  scheda.cittadinanza = giocatore.value.cittadinanza || 'ITALIANA'
  scheda.tel_papa = giocatore.value.tel_papa || ''
  scheda.tel_mamma = giocatore.value.tel_mamma || ''
  scheda.email1 = giocatore.value.email1 || ''
  scheda.email2 = giocatore.value.email2 || ''
  scheda.prof_papa = giocatore.value.prof_papa || ''
  scheda.prof_mamma = giocatore.value.prof_mamma || ''
  scheda.anamnesi = giocatore.value.anamnesi || ''
  scheda.taglia = giocatore.value.taglia || ''
  scheda.note = giocatore.value.note || ''
  scheda.nome_papa = giocatore.value.nome_papa || ''
  scheda.nome_mamma = giocatore.value.nome_mamma || ''
  scheda.comune_nato = giocatore.value.comune_nato || ''
  
  giocatoreEdit.cognome = giocatore.value.cognome || ''
  giocatoreEdit.nome = giocatore.value.nome || ''
  giocatoreEdit.data_nascita = giocatore.value.data_nascita || ''
  giocatoreEdit.numero_maglia = giocatore.value.numero_maglia || ''
  giocatoreEdit.matricola = giocatore.value.matricola || ''
  giocatoreEdit.codice_fiscale = giocatore.value.codice_fiscale || ''
  giocatoreEdit.scadenza_certificato = giocatore.value.scadenza_certificato || ''
  
  rate.totale_da_pagare = giocatore.value.totale_da_pagare != null ? giocatore.value.totale_da_pagare : ''
  rate.iscrizione = giocatore.value.rata_iscrizione != null ? giocatore.value.rata_iscrizione : ''
  rate.rata1 = giocatore.value.rata1 != null ? giocatore.value.rata1 : ''
  rate.rata2 = giocatore.value.rata2 != null ? giocatore.value.rata2 : ''
  rate.rata3 = giocatore.value.rata3 != null ? giocatore.value.rata3 : ''
  rate.rata4 = giocatore.value.rata4 != null ? giocatore.value.rata4 : ''
  rate.saldo = giocatore.value.rata_saldo != null ? giocatore.value.rata_saldo : ''
}

async function caricaNomeCategoria(catId) {
  if (!catId) return
  try {
    const res = await getCategorie()
    const lista = Array.isArray(res) ? res : (res?.data || [])
    const cat = lista.find(c => c.id === catId)
    if (cat) categoriaNome.value = cat.nome || ''
  } catch (e) {
    console.error('Errore caricamento categoria:', e)
  }
}

function stampaPDF() {
  const originali = document.title
  const cat = categoriaNome.value || 'Giocatore'
  const cognome = (giocatore.value?.cognome || '').toUpperCase()
  const nome = giocatore.value?.nome || ''
  document.title = `${cat} - ${cognome} ${nome}`
  window.print()
  setTimeout(() => { document.title = originali }, 1000)
}

async function salvaDati() {
  try {
    const data = {
      nome: giocatoreEdit.nome,
      cognome: giocatoreEdit.cognome,
      data_nascita: giocatoreEdit.data_nascita,
      matricola: giocatoreEdit.matricola,
      numero_maglia: giocatoreEdit.numero_maglia,
      codice_fiscale: giocatoreEdit.codice_fiscale,
      scadenza_certificato: giocatoreEdit.scadenza_certificato,
      categoria_id: isNuovo.value ? categoriaIdNuovo.value : giocatore.value.categoria_id,
      residenza: scheda.residenza,
      indirizzo: scheda.indirizzo,
      cittadinanza: scheda.cittadinanza,
      tel_papa: scheda.tel_papa,
      tel_mamma: scheda.tel_mamma,
      email1: scheda.email1,
      email2: scheda.email2,
      prof_papa: scheda.prof_papa,
      prof_mamma: scheda.prof_mamma,
      nome_papa: scheda.nome_papa,
      nome_mamma: scheda.nome_mamma,
      comune_nato: scheda.comune_nato,
      anamnesi: scheda.anamnesi,
      taglia: scheda.taglia,
      note: scheda.note,
      totale_da_pagare: rate.totale_da_pagare !== '' ? (parseFloat(rate.totale_da_pagare) || null) : null,
      rata_iscrizione: rate.iscrizione !== '' ? (parseFloat(rate.iscrizione) || null) : null,
      rata1: rate.rata1 !== '' ? (parseFloat(rate.rata1) || null) : null,
      rata2: rate.rata2 !== '' ? (parseFloat(rate.rata2) || null) : null,
      rata3: rate.rata3 !== '' ? (parseFloat(rate.rata3) || null) : null,
      rata4: rate.rata4 !== '' ? (parseFloat(rate.rata4) || null) : null,
      rata_saldo: rate.saldo !== '' ? (parseFloat(rate.saldo) || null) : null
    }
    
    if (isNuovo.value) {
      const result = await createPersona(data)
      if (result?.id) router.push('/segreteria/scheda/' + result.id)
      else router.push('/segreteria')
    } else {
      await updatePersona(giocatore.value.id, data)
      editMode.value = false
      const res = await getPersone()
      const arr = Array.isArray(res) ? res : (res?.data || [])
      giocatore.value = arr.find(p => p.id === parseInt(route.params.id))
      caricaDatiGiocatore()
    }
  } catch(e) {
    console.error('Error saving:', e)
  }
}

onBeforeUnmount(() => {
  const { hideTopbar } = useStore()
  hideTopbar.value = false
})
</script>

<style scoped>
.scheda-page {
  min-height: 100vh;
  background: #e8ecf1;
  padding: 20px;
  padding-bottom: 80px;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 20px;
  background: #fff;
  border-radius: 12px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}

.header-left, .header-right {
  display: flex;
  gap: 10px;
}

.btn-back, .btn-header {
  width: 42px;
  height: 42px;
  border: none;
  background: #f0f4f8;
  border-radius: 10px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.btn-back:hover, .btn-header:hover {
  background: #e4eaf2;
}

.btn-header.active {
  background: linear-gradient(135deg, #1a3a6e, #2a4a7e);
}

.btn-header.active svg {
  color: #fff;
}

.btn-back svg, .btn-header svg {
  width: 20px;
  height: 20px;
  color: #1a3a6e;
}

.titolo-toolbar {
  font-size: 17px;
  font-weight: 600;
  color: #1a3a6e;
}

.scheda-container {
  max-width: 297mm;
  margin: 0 auto;
  background: #fff;
  padding: 3mm 4mm;
  box-shadow: 0 2px 12px rgba(0,0,0,0.1);
}

.scheda-container {
  max-width: 297mm;
  margin: 0 auto;
  background: #fff;
  padding: 2mm 3mm;
  box-shadow: 0 2px 12px rgba(0,0,0,0.1);
}

.scheda-header {
  text-align: center;
  margin-bottom: 1.5mm;
  padding-bottom: 1.5mm;
  border-bottom: 2px solid #1a3a6e;
}

.scheda-header h1 {
  font-size: 14px;
  font-weight: 700;
  color: #1a3a6e;
  margin: 0 0 1px 0;
  letter-spacing: 1px;
}

.scheda-header h2 {
  font-size: 10px;
  font-weight: 500;
  color: #4a6a9e;
  margin: 0;
}

.scheda-top {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2mm;
  margin-bottom: 2mm;
}

.scheda-top .col-left,
.scheda-top .col-right {
  display: flex;
  flex-direction: column;
  gap: 0;
}

.scheda-bottom {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 2mm;
}

.col-bottom-left {
  display: flex;
  flex-direction: column;
  gap: 2mm;
}

.col-bottom-right {
  display: flex;
  flex-direction: column;
}

.section {
  margin-bottom: 0;
  padding: 1.5mm;
  background: #fafbfc;
  border: 1px solid #e8ecf1;
  border-radius: 2px;
}

.section h3 {
  font-size: 8px;
  font-weight: 600;
  color: #1a3a6e;
  margin: 0 0 1.5mm 0;
  padding-bottom: 1mm;
  border-bottom: 1px solid #1a3a6e;
  letter-spacing: 0.5px;
}

.form-row {
  display: flex;
  gap: 2mm;
  margin-bottom: 1mm;
}

.form-field {
  flex: 1;
}

.form-field.full {
  width: 100%;
}

.form-field label {
  display: block;
  font-size: 7px;
  font-weight: 600;
  color: #4a6a9e;
  margin-bottom: 0.5mm;
  letter-spacing: 0.3px;
}

.form-field input,
.form-field select,
.form-field textarea {
  width: 100%;
  padding: 1.5mm 2mm;
  border: 1px solid #d0d8e4;
  border-radius: 2px;
  font-size: 9px;
  color: #000;
  background: #fff;
  box-sizing: border-box;
  font-family: inherit;
}

.form-field input:focus,
.form-field select:focus,
.form-field textarea:focus {
  outline: none;
  border-color: #5b7fff;
}

.form-field input:disabled,
.form-field select:disabled,
.form-field textarea:disabled {
  background: #fff;
  border-color: #d0d8e4;
  color: #000;
}

.form-field textarea {
  resize: none;
}

.equip-list {
  margin-top: 3mm;
}

.equip-title {
  display: block;
  font-size: 9px;
  font-weight: 600;
  color: #4a6a9e;
  margin-bottom: 2mm;
  text-transform: uppercase;
}

.equip-grid {
  display: flex;
  gap: 20mm;
}

.equip-col {
  flex: 1;
}

.equip-item {
  display: flex;
  align-items: center;
  gap: 2mm;
  margin-bottom: 2mm;
}

.equip-label {
  font-size: 9px;
  color: #1a1a1a;
}

.checkbox {
  width: 10px;
  height: 10px;
  min-width: 10px;
  border: 1.5px solid #4a6a9e;
  border-radius: 2px;
  cursor: pointer;
  background: #fff;
}

.checkbox.checked {
  background: #1a3a6e;
  border-color: #1a3a6e;
}

.checkbox.checked::after {
  content: '✓';
  color: #fff;
  font-size: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.rate-grid {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 2mm;
}

.rate-row {
  display: flex;
  flex-direction: column;
  gap: 0.5mm;
}

.rate-totale-input {
  grid-column: 1 / -1;
  flex-direction: row;
  justify-content: space-between;
  align-items: center;
  padding-bottom: 2mm;
  border-bottom: 1.5px solid #4a6a9e;
}

.rate-totale-input label {
  font-size: 8px;
  font-weight: 700;
  color: #4a6a9e;
}

.rate-totale-input .rate-input {
  width: 80px;
}

.rate-row label {
  font-size: 7px;
  font-weight: 600;
  color: #4a6a9e;
}

.rate-input {
  padding: 1.5mm 2mm;
  border: 1px solid #000;
  border-radius: 3px;
  font-size: 9px;
  background: #fff;
  font-family: inherit;
  color: #000;
}

.rate-input:focus {
  outline: none;
  border-color: #5b7fff;
}

.rate-input:disabled {
  background: #fff;
  border-color: #000;
  color: #000;
}

.rate-totale {
  grid-column: 1 / -1;
  flex-direction: row;
  justify-content: space-between;
  align-items: center;
  padding-top: 2mm;
  border-top: 1.5px solid #4a6a9e;
  margin-top: 1mm;
}

.rate-totale label {
  font-size: 8px;
  font-weight: 700;
  color: #4a6a9e;
}

.rate-totale-value {
  font-size: 9px;
  font-weight: 700;
  color: #1a3a6e;
}

.rate-rimane {
  grid-column: 1 / -1;
  flex-direction: row;
  justify-content: space-between;
  align-items: center;
  padding-top: 1mm;
  border-top: 2px solid #c0392b;
}

.rate-rimane label {
  font-size: 8px;
  font-weight: 700;
  color: #c0392b;
}

.rate-rimane-value {
  padding: 1.5mm 2mm;
  border: 1px solid #c0392b;
  border-radius: 3px;
  font-size: 9px;
  font-weight: 700;
  color: #c0392b;
  background: #fdf2f2;
  min-width: 60px;
  text-align: right;
}

.privacy-text {
  font-size: 7px;
  line-height: 1.3;
  margin-bottom: 2mm;
  color: #333;
}

.firma-row {
  margin-bottom: 2mm;
}

.firma-row label {
  display: block;
  font-size: 6px;
  font-weight: 600;
  color: #4a6a9e;
  margin-bottom: 0.5mm;
}

.firma-line {
  display: block;
  border-bottom: 1px solid #1a3a6e;
  height: 6mm;
}

.obbligo-text {
  font-size: 6px;
  font-style: italic;
  color: #666;
}

.note-area textarea {
  margin-bottom: 1.5mm;
}

.save-bar {
  display: flex;
  gap: 8px;
  margin-top: 3mm;
  padding-top: 3mm;
  border-top: 1px solid #e8ecf1;
}

.btn-annulla {
  flex: 1;
  padding: 2mm;
  background: #f0f4f8;
  color: #4a6a9e;
  border: 1px solid #d0d8e4;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}

.btn-annulla:hover {
  background: #e4eaf2;
}

.btn-salva {
  flex: 2;
  padding: 2mm;
  background: linear-gradient(135deg, #1a3a6e, #2a4a7e);
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}

.btn-salva:hover {
  opacity: 0.9;
}

@media print {
  @page {
    size: A4 landscape;
    margin: 0;
  }
  
  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
  
  html, body {
    width: 297mm;
    height: 210mm;
    margin: 0;
    padding: 0;
    overflow: hidden;
    background: #fff;
  }
  
  .scheda-page {
    background: #fff;
    padding: 0;
    min-height: 210mm;
    height: 210mm;
    display: flex;
    flex-direction: column;
  }
  
  .page-header, .save-bar {
    display: none !important;
  }
  
  .scheda-container {
    width: 297mm;
    height: 210mm;
    max-width: none;
    max-height: none;
    padding: 2.5mm 4mm;
    margin: 0 auto;
    box-shadow: none;
    background: #fff;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    flex: 1;
  }
  
  .scheda-header {
    margin-bottom: 1.5mm;
    padding-bottom: 1.5mm;
    flex-shrink: 0;
  }
  
  .scheda-header h1 {
    font-size: 18px;
  }
  
  .scheda-header h2 {
    font-size: 12px;
  }
  
  .scheda-top {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5mm;
    margin-bottom: 1.5mm;
    flex-shrink: 0;
  }
  
  .scheda-top .col-left,
  .scheda-top .col-right {
    display: flex;
    flex-direction: column;
    gap: 0;
  }
  
  .scheda-bottom {
    display: grid;
    grid-template-columns: 1.4fr 0.8fr;
    gap: 1.5mm;
    flex: 1;
    min-height: 0;
  }
  
  .col-bottom-left {
    display: flex;
    flex-direction: column;
    gap: 0;
  }
  
  .col-bottom-right {
    display: flex;
    flex-direction: column;
  }
  
  .section {
    padding: 1.5mm;
    margin-bottom: 0;
    flex-shrink: 0;
  }
  
  .col-bottom-right .section.note {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }
  
  .col-bottom-right .note-area {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }
  
  .col-bottom-right .note-area textarea {
    flex: 1;
    min-height: 0;
  }
  
  .section h3 {
    font-size: 10px;
    margin-bottom: 1mm;
  }
  
  .form-row {
    margin-bottom: 0.8mm;
    gap: 1.5mm;
  }
  
  .form-field label {
    font-size: 7px;
    margin-bottom: 0.3mm;
  }
  
  .form-field input,
  .form-field select,
  .form-field textarea {
    padding: 1mm 1.5mm;
    font-size: 10px;
    color: #000;
    background: #fff;
    border: 1px solid #000;
  }
  
  .equip-list {
    margin-top: 1.5mm;
  }
  
  .equip-title {
    font-size: 10px;
    margin-bottom: 1mm;
  }
  
  .equip-grid {
    gap: 5mm;
  }
  
  .equip-item {
    margin-bottom: 0.8mm;
  }
  
  .equip-label {
    font-size: 9px;
  }
  
  .checkbox {
    width: 8px;
    height: 8px;
    min-width: 8px;
  }
  
  .checkbox.checked::after {
    font-size: 6px;
  }
  
  .rate-grid {
    gap: 1.5mm;
  }
  
  .rate-row label {
    font-size: 7px;
  }
  
  .rate-input {
    padding: 1mm 1.5mm;
    font-size: 10px;
    color: #000;
    background: #fff;
    border: 1px solid #000;
  }
  
  .privacy-text {
    font-size: 8px;
    line-height: 1.3;
  }
  
  .firma-line {
    height: 4.5mm;
  }
  
  .firma-row label {
    font-size: 7px;
  }
  
  .obbligo-text {
    font-size: 7px;
  }
}
</style>