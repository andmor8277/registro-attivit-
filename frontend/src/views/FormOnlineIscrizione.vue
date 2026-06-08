<template>
  <div class="form-page">
    <div class="form-container" v-if="!loading">
      <div class="form-header">
        <h1 v-if="isNew">PREISCRIZIONA ONLINE</h1>
        <h1 v-else>MODULO ISCRIZIONE SCUOLA CALCIO</h1>
        <h2>STAGIONE SPORTIVA 2025-2026</h2>
      </div>

      <div v-if="error" class="error-banner">{{ error }}</div>

      <div class="form-body">
        <section class="section">
          <h3>DATI PERSONALI ATLETA</h3>
          <div class="form-row">
            <div class="form-field">
              <label>COGNOME</label>
              <input v-model="form.cognome" required disabled />
            </div>
            <div class="form-field">
              <label>NOME</label>
              <input v-model="form.nome" required disabled />
            </div>
          </div>
          <div class="form-row">
            <div class="form-field">
              <label>NATO/A IL</label>
              <input v-model="form.data_nascita" type="date" />
            </div>
            <div class="form-field">
              <label>CODICE FISCALE</label>
              <input v-model="form.codice_fiscale" maxlength="16" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-field">
              <label>RESIDENZA</label>
              <input v-model="form.residenza" />
            </div>
            <div class="form-field">
              <label>IN VIA</label>
              <input v-model="form.indirizzo" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-field">
              <label>CITTADINANZA</label>
              <input v-model="form.cittadinanza" />
            </div>
            <div class="form-field">
              <label>SCAD. CERTIFICATO</label>
              <input v-model="form.scadenza_certificato" type="date" />
            </div>
          </div>
        </section>

        <section class="section">
          <h3>DATI GENITORI</h3>
          <div class="form-row">
            <div class="form-field">
              <label>NOME PAPÀ</label>
              <input v-model="form.nome_papa" />
            </div>
            <div class="form-field">
              <label>NOME MAMMA</label>
              <input v-model="form.nome_mamma" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-field">
              <label>PROFESSIONE PAPÀ</label>
              <input v-model="form.prof_papa" />
            </div>
            <div class="form-field">
              <label>PROFESSIONE MAMMA</label>
              <input v-model="form.prof_mamma" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-field">
              <label>TEL PAPÀ</label>
              <input v-model="form.tel_papa" />
            </div>
            <div class="form-field">
              <label>TEL MAMMA</label>
              <input v-model="form.tel_mamma" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-field">
              <label>EMAIL 1</label>
              <input v-model="form.email1" type="email" />
            </div>
            <div class="form-field">
              <label>EMAIL 2</label>
              <input v-model="form.email2" type="email" />
            </div>
          </div>
        </section>

        <section class="section">
          <h3>ANAMNESI</h3>
          <div class="form-field full">
            <textarea v-model="form.anamnesi" rows="2"></textarea>
          </div>
        </section>

        <section class="section">
          <h3>EQUIPAGGIAMENTO</h3>
          <div class="form-row">
            <div class="form-field">
              <label>TAGLIA</label>
              <select v-model="form.taglia">
                <option value="">Seleziona...</option>
                <option v-for="t in taglie" :key="t" :value="t">{{ t }}</option>
              </select>
            </div>
          </div>
        </section>

        <section class="section">
          <h3>NOTE</h3>
          <div class="form-field full">
            <textarea v-model="form.note" rows="3"></textarea>
          </div>
        </section>
      </div>

      <div class="save-bar">
        <span v-if="saved" class="saved-msg">Dati salvati con successo!</span>
        <button class="btn-salva" @click="salvaDati" :disabled="saving">
          {{ saving ? 'Salvataggio...' : 'Invia Dati' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="loading-overlay">
      <div class="spinner"></div>
      <p>Caricamento modulo...</p>
    </div>
  </div>
</template>

<script setup>
import { reactive, ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getPublicPersona, updatePublicPersona, createPublicPersona } from '../api'

const route = useRoute()
const router = useRouter()
const loading = ref(true)
const saving = ref(false)
const saved = ref(false)
const error = ref('')
const isNew = ref(false)

const form = reactive({
  cognome: '',
  nome: '',
  data_nascita: '',
  codice_fiscale: '',
  residenza: '',
  indirizzo: '',
  cittadinanza: 'ITALIANA',
  nome_papa: '',
  nome_mamma: '',
  prof_papa: '',
  prof_mamma: '',
  tel_papa: '',
  tel_mamma: '',
  email1: '',
  email2: '',
  anamnesi: '',
  taglia: '',
  note: '',
  scadenza_certificato: '',
  categoria_id: ''
})

const taglie = ['XXXS', 'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL']

onMounted(async () => {
  const id = route.query.id
  const catId = route.query.categoria_id
  if (catId) {
    isNew.value = true
    form.categoria_id = catId
    loading.value = false
    return
  }
  if (!id) {
    loading.value = false
    error.value = 'ID giocatore non trovato.'
    return
  }

  try {
    const res = await getPublicPersona(id)
    const data = res.data
    form.cognome = data.cognome || ''
    form.nome = data.nome || ''
    form.data_nascita = data.data_nascita || ''
    form.codice_fiscale = data.codice_fiscale || ''
    form.residenza = data.residenza || ''
    form.indirizzo = data.indirizzo || ''
    form.cittadinanza = data.cittadinanza || 'ITALIANA'
    form.nome_papa = data.nome_papa || ''
    form.nome_mamma = data.nome_mamma || ''
    form.prof_papa = data.prof_papa || ''
    form.prof_mamma = data.prof_mamma || ''
    form.tel_papa = data.tel_papa || ''
    form.tel_mamma = data.tel_mamma || ''
    form.email1 = data.email1 || ''
    form.email2 = data.email2 || ''
    form.anamnesi = data.anamnesi || ''
    form.taglia = data.taglia || ''
    form.note = data.note || ''
    form.scadenza_certificato = data.scadenza_certificato || ''
  } catch (e) {
    error.value = 'Errore nel caricamento dei dati: ' + (e.response?.data?.detail || e.message)
  } finally {
    loading.value = false
  }
})

function cleanForm() {
  const payload = {}
  for (const key in form) {
    const val = form[key]
    if (key === 'categoria_id') {
      payload[key] = val ? parseInt(val) : null
    } else if (key === 'cittadinanza') {
      payload[key] = val || 'ITALIANA'
    } else {
      payload[key] = val !== '' ? val : null
    }
  }
  return payload
}

async function salvaDati() {
  saving.value = true
  saved.value = false
  error.value = ''

  try {
    const payload = cleanForm()
    if (isNew.value) {
      const res = await createPublicPersona(payload)
      const newId = res.data.id
      router.replace({ query: { id: newId, categoria_id: '' } })
      isNew.value = false
    } else {
      const id = route.query.id
      await updatePublicPersona(id, payload)
    }
    saved.value = true
    setTimeout(() => { saved.value = false }, 4000)
  } catch (e) {
    error.value = 'Errore nel salvataggio: ' + (e.response?.data?.detail || e.message)
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.form-page {
  min-height: 100vh;
  background: #e8ecf1;
  padding: 20px;
  padding-bottom: 100px;
  display: flex;
  justify-content: center;
}

.form-container {
  max-width: 900px;
  width: 100%;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.1);
  overflow: hidden;
}

.form-header {
  text-align: center;
  padding: 20px 20px 16px;
  border-bottom: 2px solid #1a3a6e;
  background: #fafbfc;
}

.form-header h1 {
  font-size: 18px;
  font-weight: 700;
  color: #1a3a6e;
  margin: 0 0 4px 0;
  letter-spacing: 1px;
}

.form-header h2 {
  font-size: 13px;
  font-weight: 500;
  color: #4a6a9e;
  margin: 0;
}

.error-banner {
  margin: 16px;
  padding: 12px 16px;
  background: #fee2e2;
  color: #dc2626;
  border-radius: 8px;
  font-size: 14px;
  text-align: center;
}

.form-body {
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section {
  padding: 16px;
  background: #fafbfc;
  border: 1px solid #e8ecf1;
  border-radius: 8px;
}

.section h3 {
  font-size: 12px;
  font-weight: 600;
  color: #1a3a6e;
  margin: 0 0 12px 0;
  padding-bottom: 8px;
  border-bottom: 1px solid #1a3a6e;
  letter-spacing: 0.5px;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin-bottom: 12px;
}

.form-row:last-child {
  margin-bottom: 0;
}

.form-field {
  display: flex;
  flex-direction: column;
}

.form-field.full {
  width: 100%;
}

.form-field label {
  font-size: 11px;
  font-weight: 600;
  color: #4a6a9e;
  margin-bottom: 4px;
  letter-spacing: 0.3px;
}

.form-field input,
.form-field select,
.form-field textarea {
  padding: 10px 12px;
  border: 1px solid #d0d8e4;
  border-radius: 6px;
  font-size: 14px;
  color: #1a1a1a;
  background: #fff;
  font-family: inherit;
  box-sizing: border-box;
  width: 100%;
}

.form-field input:focus,
.form-field select:focus,
.form-field textarea:focus {
  outline: none;
  border-color: #5b7fff;
  box-shadow: 0 0 0 2px rgba(91,127,255,0.15);
}

.form-field textarea {
  resize: vertical;
}

.privacy-text {
  font-size: 13px;
  line-height: 1.5;
  margin-bottom: 16px;
  color: #333;
}

.firma-row {
  margin-bottom: 16px;
}

.firma-row label {
  display: block;
  font-size: 11px;
  font-weight: 600;
  color: #4a6a9e;
  margin-bottom: 4px;
}

.firma-line {
  display: block;
  border-bottom: 1px solid #1a3a6e;
  height: 40px;
}

.obbligo-text {
  font-size: 12px;
  font-style: italic;
  color: #666;
  margin-top: 12px;
}

.save-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 16px 20px;
  border-top: 1px solid #e8ecf1;
  background: #fafbfc;
}

.saved-msg {
  color: #16a34a;
  font-size: 14px;
  font-weight: 600;
}

.btn-salva {
  padding: 10px 24px;
  background: linear-gradient(135deg, #1a3a6e, #2a4a7e);
  color: #fff;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-salva:hover:not(:disabled) {
  opacity: 0.9;
  transform: translateY(-1px);
}

.btn-salva:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.loading-overlay {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  color: #4a6a9e;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #e8ecf1;
  border-top-color: #1a3a6e;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin-bottom: 12px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 600px) {
  .form-page {
    padding: 8px;
  }

  .form-row {
    grid-template-columns: 1fr;
  }

  .form-header h1 {
    font-size: 15px;
  }

  .form-body {
    padding: 12px;
  }
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

  .form-page {
    background: #fff;
    padding: 0;
  }

  .form-container {
    box-shadow: none;
    border-radius: 0;
  }

  .save-bar {
    display: none !important;
  }

  .form-field input,
  .form-field select,
  .form-field textarea {
    border: 1px solid #000;
    background: #fff;
    color: #000;
  }
}
</style>
