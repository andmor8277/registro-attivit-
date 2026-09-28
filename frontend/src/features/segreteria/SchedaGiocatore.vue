<template>
  <div class="scheda-page" :class="{ editing: editMode }">
    <!-- Toolbar in alto (solo su schermo) -->
    <header class="page-header no-print">
      <div class="header-left">
        <button class="btn-tool" @click="router.push('/segreteria')" title="Torna alla Segreteria">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          <span class="btn-text">Segreteria</span>
        </button>
      </div>

      <div class="header-center">
        <span class="titolo-toolbar">{{ isNuovo ? 'Nuova Iscrizione' : 'Modulo Iscrizione Atleta' }}</span>
        <span v-if="categoriaNome" class="badge-cat">{{ categoriaNome }}</span>
      </div>

      <div class="header-right">
        <button
          class="btn-tool"
          :class="{ active: editMode }"
          @click="toggleEdit"
          :title="editMode ? 'Visualizza Modulo' : 'Modifica Dati'"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
            <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
          </svg>
          <span class="btn-text">{{ editMode ? 'Fine Modifica' : 'Modifica' }}</span>
        </button>
        <button
          class="btn-tool btn-export"
          @click="esportaPDF"
          :disabled="esportandoPdf"
          title="Scarica Modulo PDF identico alla pagina web"
        >
          <span v-if="esportandoPdf" class="spinner-small"></span>
          <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
            <polyline points="7 10 12 15 17 10"/>
            <line x1="12" y1="15" x2="12" y2="3"/>
          </svg>
          <span class="btn-text">{{ esportandoPdf ? 'Generazione...' : 'Esporta PDF' }}</span>
        </button>
        <button class="btn-tool btn-print" @click="stampaModulo" title="Stampa o Salva tramite browser">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="6 9 6 2 18 2 18 9"/>
            <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
            <rect x="6" y="14" width="12" height="8"/>
          </svg>
          <span class="btn-text">Stampa</span>
        </button>
      </div>
    </header>

    <!-- FOGLIO MODULO ISCRIZIONE (FORMATO UFFICIALE RED TIGERS) -->
    <div class="foglio-iscrizione" ref="schedaContainer">
      <!-- 1. Stemma Società in alto al centro -->
      <div class="header-logo-row">
        <img v-if="societaLogo" :src="societaLogo" :alt="societaNome" class="stemma-societa" crossorigin="anonymous" />
        <div v-else class="stemma-placeholder">
          <span>{{ societaNome.charAt(0) }}</span>
        </div>
      </div>

      <!-- 2. Titolo Ufficiale Iscrizione -->
      <div class="header-title-box">
        <h1 class="titolo-iscrizione">
          ISCRIZIONE {{ societaNome.toUpperCase() }} STAGIONE {{ stagioneLabel }}
        </h1>
      </div>

      <div class="divider-line"></div>

      <!-- 3. Tabella Principale Dati Anagrafici & Contatto (2 Colonne) -->
      <div class="grid-anagrafica">
        <!-- Colonna Sinistra -->
        <div class="col-anagrafica col-left">
          <div class="field-row">
            <span class="field-label">COGNOME</span>
            <div class="field-val">
              <input v-if="editMode" v-model="giocatoreEdit.cognome" class="sheet-input uppercase" />
              <span v-else class="sheet-text uppercase bold">{{ giocatoreEdit.cognome }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">NOME</span>
            <div class="field-val">
              <input v-if="editMode" v-model="giocatoreEdit.nome" class="sheet-input uppercase" />
              <span v-else class="sheet-text uppercase bold">{{ giocatoreEdit.nome }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">NATO/ A</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.comune_nato" class="sheet-input uppercase" />
              <span v-else class="sheet-text uppercase">{{ scheda.comune_nato }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">IL</span>
            <div class="field-val">
              <input v-if="editMode" v-model="giocatoreEdit.data_nascita" type="date" class="sheet-input" />
              <span v-else class="sheet-text">{{ formatData(giocatoreEdit.data_nascita) }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">RESIDENZA</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.residenza" class="sheet-input uppercase" />
              <span v-else class="sheet-text uppercase">{{ scheda.residenza }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">IN VIA</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.indirizzo" class="sheet-input uppercase" />
              <span v-else class="sheet-text uppercase">{{ scheda.indirizzo }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">CITTADINANZA</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.cittadinanza" class="sheet-input uppercase" />
              <span v-else class="sheet-text uppercase">{{ scheda.cittadinanza }}</span>
            </div>
          </div>

          <div class="field-row row-cf">
            <span class="field-label">CODICE FISCALE</span>
            <div class="field-val cf-wrap">
              <input v-if="editMode" v-model="giocatoreEdit.codice_fiscale" maxlength="16" class="sheet-input uppercase" />
              <span v-else class="sheet-text uppercase font-mono">{{ giocatoreEdit.codice_fiscale }}</span>
              <button v-if="editMode" type="button" class="btn-gen-cf no-print" @click="generaCf" title="Genera automaticamente CF">
                Gen. CF
              </button>
            </div>
          </div>
        </div>

        <!-- Colonna Destra -->
        <div class="col-anagrafica col-right">
          <div class="field-row">
            <span class="field-label">TEL RAGAZZO</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.tel_ragazzo" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.tel_ragazzo }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">TEL PAPA'</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.tel_papa" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.tel_papa }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">TEL MAMMA</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.tel_mamma" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.tel_mamma }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">TEL NONNI</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.tel_nonni" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.tel_nonni }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">PROFESSIONE MAMMA</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.prof_mamma" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.prof_mamma }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">PROFESSIONE PAPA'</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.prof_papa" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.prof_papa }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">SOCIETA' DI PROVENIENZA</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.societa_provenienza" class="sheet-input uppercase" />
              <span v-else class="sheet-text uppercase">{{ scheda.societa_provenienza }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">SCADENZA CERTIFICATO {{ annoInizio }}</span>
            <div class="field-val">
              <input v-if="editMode" v-model="giocatoreEdit.scadenza_certificato" type="date" class="sheet-input" />
              <span v-else class="sheet-text">{{ formatData(giocatoreEdit.scadenza_certificato) }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">SCADENZA CERTIFICATO {{ annoFine }}</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.scadenza_certificato_2" type="date" class="sheet-input" />
              <span v-else class="sheet-text">{{ formatData(scheda.scadenza_certificato_2) }}</span>
            </div>
          </div>

          <div class="field-row">
            <span class="field-label">NOTE</span>
            <div class="field-val">
              <input v-if="editMode" v-model="scheda.note" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.note }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 4. Tabella Materiale (Taglia + Dotazione) & Email -->
      <div class="section-dotazione-email">
        <div class="col-dotazione">
          <!-- Blocco Taglia Materiale Sportivo -->
          <div class="section-header-bar header-taglia">
            <span>TAGLIA MATERIALE SPORTIVO</span>
          </div>
          <div class="taglia-grid">
            <div
              v-for="t in taglie"
              :key="t"
              class="taglia-box"
              :class="{ active: scheda.taglia === t, clickable: editMode }"
              @click="selezionaTaglia(t)"
            >
              <span class="taglia-name">{{ t }}</span>
              <span v-if="scheda.taglia === t" class="taglia-check">✓</span>
            </div>
          </div>

          <!-- Blocco Materiale Individuale in Dotazione -->
          <div class="section-header-bar header-dotazione">
            <span>MATERIALE INDIVIDUALE IN DOTAZIONE</span>
          </div>
          <div class="dotazione-grid">
            <div class="dotazione-col">
              <div
                v-for="item in equipSinistra"
                :key="item"
                class="dotazione-row"
                :class="{ clickable: editMode }"
                @click="toggleDotazione(item)"
              >
                <span class="dotazione-label">{{ item }}</span>
                <div class="dot-check-cell">
                  <div class="box-check" :class="{ checked: isDotazioneChecked(item) }">
                    <span v-if="isDotazioneChecked(item)">✓</span>
                  </div>
                </div>
              </div>
            </div>
            <div class="dotazione-col">
              <div
                v-for="item in equipDestra"
                :key="item"
                class="dotazione-row"
                :class="{ clickable: editMode }"
                @click="toggleDotazione(item)"
              >
                <span class="dotazione-label">{{ item }}</span>
                <div class="dot-check-cell">
                  <div class="box-check" :class="{ checked: isDotazioneChecked(item) }">
                    <span v-if="isDotazioneChecked(item)">✓</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="col-email">
          <div class="email-field-row">
            <span class="email-label">EMAIL 1:</span>
            <div class="email-val">
              <input v-if="editMode" v-model="scheda.email1" type="email" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.email1 }}</span>
            </div>
          </div>
          <div class="email-field-row">
            <span class="email-label">EMAIL 2:</span>
            <div class="email-val">
              <input v-if="editMode" v-model="scheda.email2" type="email" class="sheet-input" />
              <span v-else class="sheet-text">{{ scheda.email2 }}</span>
            </div>
          </div>
          <div class="email-field-row">
            <span class="email-label">CATEGORIA:</span>
            <div class="email-val">
              <span class="sheet-text uppercase bold">{{ categoriaNome || '---' }}</span>
            </div>
          </div>
          <div class="email-field-row">
            <span class="email-label">NR. MAGLIA:</span>
            <div class="email-val">
              <input v-if="editMode" v-model="giocatoreEdit.numero_maglia" type="number" class="sheet-input-small" />
              <span v-else class="sheet-text bold">{{ giocatoreEdit.numero_maglia || '-' }}</span>
            </div>
          </div>
          <div class="email-field-row">
            <span class="email-label">MATRICOLA:</span>
            <div class="email-val">
              <input v-if="editMode" v-model="giocatoreEdit.matricola" class="sheet-input-small uppercase" />
              <span v-else class="sheet-text uppercase bold">{{ giocatoreEdit.matricola || '-' }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 6. Bottom Grid: Privacy / Firme (Sinistra) & Pagamenti / Rate (Destra) -->
      <div class="grid-bottom">
        <!-- Colonna Privacy -->
        <div class="col-privacy">
          <div class="section-header-bar header-privacy">
            <span>AUTORIZZAZIONE ALL'USO DELL'IMMAGINE</span>
            <span class="sub">E PRIVACY DEL MINORE</span>
          </div>

          <div class="privacy-block priv-block-1">
            <p class="privacy-p">
              Con la presente, il succitato genitore <strong>AUTORIZZA</strong> il
              trattamento dei dati personali del proprio figlio/figlia
              ai fini dell'esercizio dell'attività richiesta, ovvero compilazione
              di schede tecniche e assegnazione ai gruppi di appartenenza.<br>
              <em>Eventuale diniego da parte del genitore comporterà
              l'annullamento dell'iscrizione alla attività richiesta</em>
            </p>
            <div class="firma-container">
              <span class="firma-title">FIRMA DEL GENITORE</span>
              <div class="firma-line"></div>
            </div>
          </div>

          <div class="privacy-block priv-block-2 block-obbligo">
            <p class="privacy-p">
              Con l'accettazione di quanto sopra il firmatario si impegna ad onorare tutte le scadenze dei pagamenti previste
            </p>
            <div class="firma-container">
              <span class="firma-title">FIRMA DEL GENITORE</span>
              <div class="firma-line"></div>
            </div>
          </div>

          <div class="privacy-block priv-block-3">
            <p class="privacy-p small-p">
              E' altresì previsto l'utilizzo di immagini del minore rappresentato ed iscritto. Le immagini saranno destinate alla realizzazione di progetti, pubblicazioni, interviste ed attività di divulgazione delle attività svolte dalla Scuola Calcio e potranno essere utilizzate per essere inserite su pubblicazioni, per riprese televisive, Dvd od altro supporto idoneo alla memorizzazione. Potranno altresì essere diffuse pubblicamente durante proiezioni, trasmissioni televisive o pubblicate su stampa o riviste in contesti riguardanti le attività didattiche/sportive svolte nel Centro sportivo. L'eventuale diniego non comporterà alcuna conseguenza.
            </p>
            <div class="firma-container">
              <span class="firma-title">FIRMA DEL GENITORE</span>
              <div class="firma-line"></div>
            </div>
          </div>
        </div>

        <!-- Colonna Pagamenti -->
        <div class="col-pagamenti">
          <div class="section-header-bar">
            <span>SITUAZIONE PAGAMENTI</span>
          </div>

          <div class="pagamento-row row-costo-totale">
            <span class="pag-label">COSTO TOTALE</span>
            <div class="pag-val">
              <input v-if="editMode" v-model="rate.totale_da_pagare" placeholder="€ 0.00" class="sheet-input-num bold" />
              <span v-else class="sheet-text bold">{{ formatEuro(rate.totale_da_pagare) }}</span>
            </div>
          </div>

          <div class="pagamento-row">
            <span class="pag-label">PREISCRIZIONE RIC N</span>
            <div class="pag-val">
              <input v-if="editMode" v-model="scheda.ricevuta_preiscrizione" class="sheet-input" placeholder="N. ricevuta / Note" />
              <span v-else class="sheet-text">{{ scheda.ricevuta_preiscrizione }}</span>
            </div>
          </div>

          <div class="pagamento-row">
            <span class="pag-label">ISCRIZIONE RIC N</span>
            <div class="pag-val double-input">
              <input v-if="editMode" v-model="rate.iscrizione" placeholder="€ Quota" class="sheet-input-num" />
              <span v-else-if="rate.iscrizione" class="sheet-text font-bold">{{ formatEuro(rate.iscrizione) }}</span>
              <input v-if="editMode" v-model="scheda.ricevuta_iscrizione" placeholder="Ric. N." class="sheet-input-rec" />
              <span v-else-if="scheda.ricevuta_iscrizione" class="sheet-text rec-tag">Ric. {{ scheda.ricevuta_iscrizione }}</span>
            </div>
          </div>

          <div class="pagamento-row">
            <span class="pag-label">SALDO ISCRIZIONE RIC N</span>
            <div class="pag-val double-input">
              <input v-if="editMode" v-model="rate.saldo" placeholder="€ Saldo" class="sheet-input-num" />
              <span v-else-if="rate.saldo" class="sheet-text font-bold">{{ formatEuro(rate.saldo) }}</span>
              <input v-if="editMode" v-model="scheda.ricevuta_saldo" placeholder="Ric. N." class="sheet-input-rec" />
              <span v-else-if="scheda.ricevuta_saldo" class="sheet-text rec-tag">Ric. {{ scheda.ricevuta_saldo }}</span>
            </div>
          </div>

          <div class="section-header-bar header-rate">
            <span>SITUAZIONE RATE</span>
          </div>

          <div class="pagamento-row">
            <span class="pag-label">1 RATA</span>
            <div class="pag-val">
              <input v-if="editMode" v-model="rate.rata1" placeholder="€" class="sheet-input-num" />
              <span v-else class="sheet-text">{{ formatEuro(rate.rata1) }}</span>
            </div>
          </div>

          <div class="pagamento-row">
            <span class="pag-label">2 RATA</span>
            <div class="pag-val">
              <input v-if="editMode" v-model="rate.rata2" placeholder="€" class="sheet-input-num" />
              <span v-else class="sheet-text">{{ formatEuro(rate.rata2) }}</span>
            </div>
          </div>

          <div class="pagamento-row">
            <span class="pag-label">3 RATA</span>
            <div class="pag-val">
              <input v-if="editMode" v-model="rate.rata3" placeholder="€" class="sheet-input-num" />
              <span v-else class="sheet-text">{{ formatEuro(rate.rata3) }}</span>
            </div>
          </div>

          <div class="pagamento-row">
            <span class="pag-label">4 RATA</span>
            <div class="pag-val">
              <input v-if="editMode" v-model="rate.rata4" placeholder="€" class="sheet-input-num" />
              <span v-else class="sheet-text">{{ formatEuro(rate.rata4) }}</span>
            </div>
          </div>

          <!-- Safeguarding & Regole di Comportamento -->
          <div
            class="safeguarding-box"
            :class="{ clickable: editMode }"
            @click="editMode && (scheda.safeguarding_accettato = !scheda.safeguarding_accettato)"
          >
            <span class="safe-title">CODICE DI CONDOTTA SAFEGUARDING:</span>
            <div class="safe-line">
              <div class="box-check" :class="{ checked: scheda.safeguarding_accettato }">
                <span v-if="scheda.safeguarding_accettato">✓</span>
              </div>
              <span class="safe-text">LETTO E SOTTOSCRITTO DAL GENITORE</span>
            </div>
          </div>

          <div
            class="safeguarding-box"
            :class="{ clickable: editMode }"
            @click="editMode && (scheda.regole_accettate = !scheda.regole_accettate)"
          >
            <span class="safe-title">REGOLE DI COMPORTAMENTO</span>
            <div class="safe-line">
              <div class="box-check" :class="{ checked: scheda.regole_accettate }">
                <span v-if="scheda.regole_accettate">✓</span>
              </div>
              <span class="safe-text">LETTO E SOTTOSCRITTO DAL GENITORE</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Barra Salva Modifiche (in basso, solo in editMode) -->
    <div v-if="editMode" class="save-bar no-print">
      <div class="save-bar-content">
        <span v-if="saveError" class="save-msg error-msg">{{ saveError }}</span>
        <span v-else-if="saveSuccess" class="save-msg success-msg">Modifiche salvate con successo!</span>
        <span v-else class="save-info">Modalità di modifica attiva: clicca Salva per confermare</span>

        <div class="save-actions">
          <button class="btn-action btn-cancel" @click="annullaModifiche" :disabled="saving">Annulla</button>
          <button class="btn-action btn-save" @click="salvaDati" :disabled="saving">
            <span v-if="saving" class="spinner-small"></span>
            <span v-else>Salva Modifiche</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getPersone,
  updatePersona,
  createPersona,
  getCategorie,
  getSocietaById,
  getUploadUrl,
  generaCf as generaCfApi,
  saveOrSharePdf
} from '../../api'
import { jsPDF } from 'jspdf'
import html2canvas from 'html2canvas'
import { useStore } from '../../store'

const route = useRoute()
const router = useRouter()
const { utenteAttivo, societaAttiva, hideTopbar } = useStore()

const schedaContainer = ref(null)
const esportandoPdf = ref(false)
const editMode = ref(false)
const saving = ref(false)
const saveError = ref('')
const saveSuccess = ref(false)
const giocatore = ref(null)
const societa = ref(null)
const isNuovo = ref(false)
const categoriaIdNuovo = ref(null)
const categoriaNome = ref('')
const categoriaStagione = ref(null)

const taglie = ['XXXS', 'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL']

const equipSinistra = [
  'Completo gara',
  'Compl. all.to m/estivo',
  'Polo Estiva',
  'Short Estivi',
  'Calzettoni 1',
  'Calzettoni 2',
  'Borsa'
]

const equipDestra = [
  'Piumino',
  'Tuta Rappr.',
  'Tuta lav. completa',
  'Kway Antipioggia',
  'Maglia m/c Prep.',
  'Pallone',
  'Maglia Portiere'
]

const giocatoreEdit = reactive({
  cognome: '',
  nome: '',
  data_nascita: '',
  sesso: '',
  numero_maglia: '',
  matricola: '',
  codice_fiscale: '',
  scadenza_certificato: ''
})

const scheda = reactive({
  residenza: '',
  indirizzo: '',
  cittadinanza: 'ITALIANA',
  tel_ragazzo: '',
  tel_papa: '',
  tel_mamma: '',
  tel_nonni: '',
  prof_papa: '',
  prof_mamma: '',
  societa_provenienza: '',
  scadenza_certificato_2: '',
  note: '',
  taglia: '',
  dotazione_materiale: {},
  email1: '',
  email2: '',
  ricevuta_preiscrizione: '',
  ricevuta_iscrizione: '',
  ricevuta_saldo: '',
  safeguarding_accettato: false,
  regole_accettate: false,
  comune_nato: '',
  anamnesi: '',
  nome_papa: '',
  nome_mamma: ''
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

const annoInizio = computed(() => {
  if (categoriaStagione.value) return parseInt(categoriaStagione.value)
  const d = new Date()
  return d.getMonth() >= 6 ? d.getFullYear() : d.getFullYear() - 1
})

const annoFine = computed(() => annoInizio.value + 1)

const stagioneLabel = computed(() => `${annoInizio.value}/${annoFine.value}`)

const societaLogo = computed(() => {
  if (societa.value?.logo) return getUploadUrl(societa.value.logo)
  if (societaAttiva.value?.logo) return getUploadUrl(societaAttiva.value.logo)
  return null
})

const societaNome = computed(() => {
  return societa.value?.nome || societaAttiva.value?.nome || 'RED TIGERS'
})

onMounted(async () => {
  hideTopbar.value = true

  const id = route.params.id
  const catId = route.query.categoria_id

  if (id === 'nuovo') {
    isNuovo.value = true
    categoriaIdNuovo.value = catId ? parseInt(catId) : null
    editMode.value = true
    if (catId) {
      try {
        const res = await getCategorie()
        const lista = Array.isArray(res) ? res : (res?.data || [])
        const cat = lista.find(c => c.id === parseInt(catId))
        if (cat) {
          categoriaNome.value = cat.nome || ''
          categoriaStagione.value = cat.stagione || null
          if (cat.societa_id) {
            await caricaSocieta(cat.societa_id)
          }
        }
      } catch(e) {}
    }
    if (!societa.value) {
      const fallbackSocId = utenteAttivo.value?.societa_id || parseInt(localStorage.getItem('societa_id'))
      if (fallbackSocId) await caricaSocieta(fallbackSocId)
    }
    return
  }

  if (!id) return

  try {
    const res = await getPersone()
    const arr = Array.isArray(res) ? res : (res?.data || [])
    giocatore.value = arr.find(p => p.id === parseInt(id))

    if (giocatore.value) {
      caricaDatiGiocatore()
      await caricaNomeCategoria(giocatore.value.categoria_id)
      const targetSocId = giocatore.value.societa_id || utenteAttivo.value?.societa_id || parseInt(localStorage.getItem('societa_id'))
      if (targetSocId) {
        await caricaSocieta(targetSocId)
      }
    }
  } catch(e) {
    console.error('Errore caricamento:', e)
  }
})

onBeforeUnmount(() => {
  hideTopbar.value = false
})

async function caricaSocieta(socId) {
  if (!socId) return
  try {
    const sRes = await getSocietaById(socId)
    societa.value = sRes.data
  } catch(e) {
    console.error('Errore caricamento societa:', e)
  }
}

async function caricaNomeCategoria(catId) {
  if (!catId) return
  try {
    const res = await getCategorie()
    const lista = Array.isArray(res) ? res : (res?.data || [])
    const cat = lista.find(c => c.id === catId)
    if (cat) {
      categoriaNome.value = cat.nome || ''
      categoriaStagione.value = cat.stagione || null
      if (cat.societa_id && !societa.value) {
        await caricaSocieta(cat.societa_id)
      }
    }
  } catch (e) {
    console.error('Errore caricamento categoria:', e)
  }
}

function caricaDatiGiocatore() {
  if (!giocatore.value) return

  giocatoreEdit.cognome = giocatore.value.cognome || ''
  giocatoreEdit.nome = giocatore.value.nome || ''
  giocatoreEdit.data_nascita = giocatore.value.data_nascita || ''
  giocatoreEdit.sesso = giocatore.value.sesso || ''
  giocatoreEdit.numero_maglia = giocatore.value.numero_maglia != null ? giocatore.value.numero_maglia : ''
  giocatoreEdit.matricola = giocatore.value.matricola || ''
  giocatoreEdit.codice_fiscale = giocatore.value.codice_fiscale || ''
  giocatoreEdit.scadenza_certificato = giocatore.value.scadenza_certificato ? String(giocatore.value.scadenza_certificato).slice(0, 10) : ''

  scheda.residenza = giocatore.value.residenza || ''
  scheda.indirizzo = giocatore.value.indirizzo || ''
  scheda.cittadinanza = giocatore.value.cittadinanza || 'ITALIANA'
  scheda.tel_ragazzo = giocatore.value.tel_ragazzo || ''
  scheda.tel_papa = giocatore.value.tel_papa || ''
  scheda.tel_mamma = giocatore.value.tel_mamma || ''
  scheda.tel_nonni = giocatore.value.tel_nonni || ''
  scheda.email1 = giocatore.value.email1 || ''
  scheda.email2 = giocatore.value.email2 || ''
  scheda.prof_papa = giocatore.value.prof_papa || ''
  scheda.prof_mamma = giocatore.value.prof_mamma || ''
  scheda.societa_provenienza = giocatore.value.societa_provenienza || ''
  scheda.scadenza_certificato_2 = giocatore.value.scadenza_certificato_2 ? String(giocatore.value.scadenza_certificato_2).slice(0, 10) : ''
  scheda.comune_nato = giocatore.value.comune_nato || ''
  scheda.taglia = giocatore.value.taglia || ''
  scheda.note = giocatore.value.note || ''
  scheda.ricevuta_preiscrizione = giocatore.value.ricevuta_preiscrizione || ''
  scheda.ricevuta_iscrizione = giocatore.value.ricevuta_iscrizione || ''
  scheda.ricevuta_saldo = giocatore.value.ricevuta_saldo || ''
  scheda.safeguarding_accettato = !!giocatore.value.safeguarding_accettato
  scheda.regole_accettate = !!giocatore.value.regole_accettate
  scheda.dotazione_materiale = giocatore.value.dotazione_materiale || {}
  scheda.anamnesi = giocatore.value.anamnesi || ''
  scheda.nome_papa = giocatore.value.nome_papa || ''
  scheda.nome_mamma = giocatore.value.nome_mamma || ''

  rate.totale_da_pagare = giocatore.value.totale_da_pagare != null ? giocatore.value.totale_da_pagare : ''
  rate.iscrizione = giocatore.value.rata_iscrizione != null ? giocatore.value.rata_iscrizione : ''
  rate.rata1 = giocatore.value.rata1 != null ? giocatore.value.rata1 : ''
  rate.rata2 = giocatore.value.rata2 != null ? giocatore.value.rata2 : ''
  rate.rata3 = giocatore.value.rata3 != null ? giocatore.value.rata3 : ''
  rate.rata4 = giocatore.value.rata4 != null ? giocatore.value.rata4 : ''
  rate.saldo = giocatore.value.rata_saldo != null ? giocatore.value.rata_saldo : ''
}

function toggleEdit() {
  editMode.value = !editMode.value
  saveError.value = ''
  saveSuccess.value = false
}

function annullaModifiche() {
  if (isNuovo.value) {
    router.push('/segreteria')
  } else {
    caricaDatiGiocatore()
    editMode.value = false
    saveError.value = ''
    saveSuccess.value = false
  }
}

function selezionaTaglia(t) {
  if (!editMode.value) return
  scheda.taglia = (scheda.taglia === t ? '' : t)
}

function toggleDotazione(item) {
  if (!editMode.value) return
  if (!scheda.dotazione_materiale) {
    scheda.dotazione_materiale = {}
  }
  scheda.dotazione_materiale[item] = !scheda.dotazione_materiale[item]
}

function isDotazioneChecked(item) {
  return !!scheda.dotazione_materiale?.[item]
}

function formatEuro(val) {
  if (val === null || val === undefined || val === '') return ''
  const num = parseFloat(val)
  if (isNaN(num)) return val
  return `€ ${num.toFixed(2)}`
}

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

async function esportaPDF() {
  if (!schedaContainer.value || esportandoPdf.value) return
  esportandoPdf.value = true

  const wasEditing = editMode.value
  if (wasEditing) {
    editMode.value = false
    await nextTick()
  }

  try {
    const el = schedaContainer.value
    await new Promise(resolve => setTimeout(resolve, 100))

    const canvas = await html2canvas(el, {
      scale: 2.5,
      useCORS: true,
      logging: false,
      backgroundColor: '#ffffff'
    })

    const imgData = canvas.toDataURL('image/jpeg', 0.96)
    const pdf = new jsPDF({
      orientation: 'portrait',
      unit: 'mm',
      format: 'a4'
    })

    const pageWidth = 210
    const pageHeight = 297
    const margin = 8
    const maxW = pageWidth - (margin * 2)
    const maxH = pageHeight - (margin * 2)

    let imgW = maxW
    let imgH = (canvas.height * imgW) / canvas.width

    if (imgH > maxH) {
      imgH = maxH
      imgW = (canvas.width * imgH) / canvas.height
    }

    const posX = margin + (maxW - imgW) / 2
    const posY = margin + (maxH - imgH) / 2

    pdf.addImage(imgData, 'JPEG', posX, posY, imgW, imgH)

    const cognome = (giocatoreEdit.cognome || 'ATLETA').toUpperCase()
    const nome = (giocatoreEdit.nome || '').toUpperCase()
    const filename = `ISCRIZIONE_${cognome}_${nome}.pdf`.replace(/\s+/g, '_')

    await saveOrSharePdf(pdf, filename, `Iscrizione ${cognome} ${nome}`)
  } catch (err) {
    console.error('Errore durante esportazione PDF:', err)
    alert('Errore durante la generazione del PDF. Riprova.')
  } finally {
    if (wasEditing) {
      editMode.value = true
      await nextTick()
    }
    esportandoPdf.value = false
  }
}

function stampaModulo() {
  const originali = document.title
  const cognome = (giocatoreEdit.cognome || 'ATLETA').toUpperCase()
  const nome = (giocatoreEdit.nome || '').toUpperCase()
  document.title = `ISCRIZIONE_${cognome}_${nome}`.replace(/\s+/g, '_')
  window.print()
  setTimeout(() => { document.title = originali }, 1000)
}

async function generaCf() {
  saveError.value = ''
  if (!giocatoreEdit.nome || !giocatoreEdit.cognome) {
    saveError.value = 'Inserisci nome e cognome per generare il CF'
    return
  }
  if (!giocatoreEdit.data_nascita) {
    saveError.value = 'Inserisci la data di nascita per generare il CF'
    return
  }
  if (!giocatoreEdit.sesso) {
    saveError.value = 'Seleziona o specifica il sesso per generare il CF'
    return
  }
  if (!scheda.comune_nato) {
    saveError.value = 'Inserisci il comune di nascita (NATO/A) per generare il CF'
    return
  }
  try {
    const res = await generaCfApi({
      nome: giocatoreEdit.nome,
      cognome: giocatoreEdit.cognome,
      data_nascita: giocatoreEdit.data_nascita,
      sesso: giocatoreEdit.sesso,
      comune_nato: scheda.comune_nato
    })
    const cf = res?.data?.codice_fiscale ?? res?.codice_fiscale
    if (cf) {
      giocatoreEdit.codice_fiscale = cf
    }
  } catch(e) {
    saveError.value = e.response?.data?.detail || 'Errore nella generazione del CF'
  }
}

async function salvaDati() {
  saveError.value = ''
  saveSuccess.value = false
  saving.value = true

  try {
    const payload = {
      nome: giocatoreEdit.nome,
      cognome: giocatoreEdit.cognome,
      data_nascita: giocatoreEdit.data_nascita || null,
      sesso: giocatoreEdit.sesso || null,
      matricola: giocatoreEdit.matricola || null,
      numero_maglia: giocatoreEdit.numero_maglia !== '' && giocatoreEdit.numero_maglia != null ? parseInt(giocatoreEdit.numero_maglia) : null,
      codice_fiscale: giocatoreEdit.codice_fiscale || null,
      scadenza_certificato: giocatoreEdit.scadenza_certificato || null,
      scadenza_certificato_2: scheda.scadenza_certificato_2 || null,
      categoria_id: isNuovo.value ? categoriaIdNuovo.value : giocatore.value.categoria_id,
      residenza: scheda.residenza || null,
      indirizzo: scheda.indirizzo || null,
      cittadinanza: scheda.cittadinanza || 'ITALIANA',
      tel_ragazzo: scheda.tel_ragazzo || null,
      tel_papa: scheda.tel_papa || null,
      tel_mamma: scheda.tel_mamma || null,
      tel_nonni: scheda.tel_nonni || null,
      email1: scheda.email1 || null,
      email2: scheda.email2 || null,
      prof_papa: scheda.prof_papa || null,
      prof_mamma: scheda.prof_mamma || null,
      societa_provenienza: scheda.societa_provenienza || null,
      comune_nato: scheda.comune_nato || null,
      anamnesi: scheda.anamnesi || null,
      taglia: scheda.taglia || null,
      note: scheda.note || null,
      ricevuta_preiscrizione: scheda.ricevuta_preiscrizione || null,
      ricevuta_iscrizione: scheda.ricevuta_iscrizione || null,
      ricevuta_saldo: scheda.ricevuta_saldo || null,
      safeguarding_accettato: scheda.safeguarding_accettato || false,
      regole_accettate: scheda.regole_accettate || false,
      dotazione_materiale: scheda.dotazione_materiale || {},
      totale_da_pagare: rate.totale_da_pagare !== '' ? (parseFloat(rate.totale_da_pagare) || null) : null,
      rata_iscrizione: rate.iscrizione !== '' ? (parseFloat(rate.iscrizione) || null) : null,
      rata1: rate.rata1 !== '' ? (parseFloat(rate.rata1) || null) : null,
      rata2: rate.rata2 !== '' ? (parseFloat(rate.rata2) || null) : null,
      rata3: rate.rata3 !== '' ? (parseFloat(rate.rata3) || null) : null,
      rata4: rate.rata4 !== '' ? (parseFloat(rate.rata4) || null) : null,
      rata_saldo: rate.saldo !== '' ? (parseFloat(rate.saldo) || null) : null
    }

    if (isNuovo.value) {
      const res = await createPersona(payload)
      const newId = res?.data?.id ?? res?.id
      saveSuccess.value = true
      editMode.value = false
      if (newId) router.push('/segreteria/scheda/' + newId)
    } else {
      await updatePersona(giocatore.value.id, payload)
      if (giocatore.value) {
        Object.assign(giocatore.value, payload)
      }
      saveSuccess.value = true
      editMode.value = false
    }
  } catch(e) {
    console.error('Errore salvataggio:', e)
    saveError.value = e.response?.data?.detail || 'Errore durante il salvataggio. Riprova.'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
/* Contenitore Pagina */
.scheda-page {
  min-height: 100vh;
  background: var(--color-bg, #0f172a);
  padding: 1.25rem 1rem 6rem;
  display: flex;
  flex-direction: column;
  align-items: center;
}

/* Toolbar Superiore */
.page-header {
  width: 100%;
  max-width: 820px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  background: var(--color-surface, #1e293b);
  border: 1px solid var(--color-border, #334155);
  border-radius: 12px;
  margin-bottom: 1.25rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
}

.header-left, .header-right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.header-center {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.titolo-toolbar {
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--color-text, #f8fafc);
}

.badge-cat {
  background: rgba(16, 185, 129, 0.15);
  border: 1px solid rgba(16, 185, 129, 0.3);
  color: #10b981;
  font-size: 0.7rem;
  font-weight: 600;
  padding: 0.2rem 0.5rem;
  border-radius: 6px;
  text-transform: uppercase;
}

.btn-tool {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.5rem 0.85rem;
  background: var(--color-surface-elevated, #334155);
  border: 1px solid var(--color-border, #475569);
  border-radius: 8px;
  color: var(--color-text, #f8fafc);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-tool svg {
  width: 16px;
  height: 16px;
}

.btn-tool:hover {
  background: var(--color-border, #475569);
  color: #fff;
}

.btn-tool.active {
  background: #10b981;
  border-color: #10b981;
  color: #fff;
}

.btn-export {
  background: #0284c7;
  border-color: #0369a1;
  color: #fff;
}

.btn-export:hover:not(:disabled) {
  background: #0369a1;
}

.btn-export:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.btn-print {
  background: var(--color-surface-elevated, #334155);
  border-color: var(--color-border, #475569);
  color: #fff;
}

.btn-print:hover {
  background: #475569;
}

/* =========================================================
   FOGLIO ISCRIZIONE — FORMATO A4 / REPLICA RED TIGERS
   ========================================================= */
.foglio-iscrizione {
  width: 100%;
  max-width: 820px;
  background: #ffffff;
  color: #000000;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
  font-family: Arial, "Helvetica Neue", Helvetica, sans-serif;
  padding: 12px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
}

/* 1. Header con Stemma */
.header-logo-row {
  display: flex;
  justify-content: center;
  align-items: center;
  margin-bottom: 2px;
}

.stemma-societa {
  height: 52px;
  max-width: 120px;
  object-fit: contain;
}

.stemma-placeholder {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #1e40af;
  color: #fff;
  font-weight: 800;
  font-size: 1.3rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* 2. Titolo Iscrizione */
.header-title-box {
  text-align: center;
  margin-bottom: 2px;
}

.titolo-iscrizione {
  font-size: 15px;
  font-weight: 800;
  color: #0284c7;
  letter-spacing: 0.04em;
  margin: 2px 0 3px 0;
  text-transform: uppercase;
}

.divider-line {
  height: 2px;
  background: #0284c7;
  margin-bottom: 5px;
}

/* 3. Grid Anagrafica (2 Colonne) */
.grid-anagrafica {
  display: grid;
  grid-template-columns: 50% 50%;
  border: 1.5px solid #000000;
  margin-bottom: 5px;
}

.col-anagrafica {
  display: flex;
  flex-direction: column;
}

.col-anagrafica.col-left {
  border-right: 1.5px solid #000000;
}

.field-row {
  display: flex;
  align-items: stretch;
  border-bottom: 1px solid #000000;
  min-height: 25px;
  flex: 1;
}

.col-anagrafica .field-row:last-child {
  border-bottom: none;
}

.field-label {
  width: 42%;
  min-width: 120px;
  padding: 3px 6px;
  font-size: 9.5px;
  font-weight: 800;
  color: #000000;
  text-transform: uppercase;
  letter-spacing: -0.01em;
  white-space: nowrap;
  border-right: 1px solid #000000;
  display: flex;
  align-items: center;
  background: #ffffff;
}

.col-right .field-label {
  width: 52%;
  min-width: 140px;
}

.field-val {
  flex: 1;
  padding: 3px 6px;
  display: flex;
  align-items: center;
}

.sheet-text {
  font-size: 10px;
  color: #000000;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sheet-input {
  width: 100%;
  padding: 2px 4px;
  font-size: 10px;
  color: #000000;
  background: #eff6ff;
  border: 1px dashed #3b82f6;
  border-radius: 2px;
  outline: none;
  font-family: inherit;
}

.sheet-input:focus {
  background: #dbeafe;
  border-style: solid;
}

.uppercase {
  text-transform: uppercase;
}

.bold {
  font-weight: 700;
}

.font-mono {
  font-family: "Courier New", Courier, monospace;
}

.cf-wrap {
  display: flex;
  gap: 4px;
  align-items: center;
}

.btn-gen-cf {
  background: #0284c7;
  color: #fff;
  border: none;
  border-radius: 2px;
  font-size: 8px;
  font-weight: 700;
  padding: 1px 4px;
  cursor: pointer;
  white-space: nowrap;
}

.section-header-bar {
  background: #ffffff;
  border-bottom: 1px solid #000000;
  text-align: center;
  padding: 3px 4px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  height: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* 4. Tabella Materiale (Taglia + Dotazione) & Email */
.section-dotazione-email {
  margin-bottom: 5px;
  display: grid;
  grid-template-columns: 66% 34%;
  border: 1.5px solid #000000;
}

.col-dotazione {
  border-right: 1.5px solid #000000;
  display: flex;
  flex-direction: column;
}

.header-taglia {
  border-bottom: 1px solid #000000;
}

.taglia-grid {
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  border-bottom: 1px solid #000000;
  height: 24px;
}

.taglia-box {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 3px;
  padding: 3.5px 2px;
  font-size: 10px;
  font-weight: 700;
  border-right: 1px solid #000000;
  user-select: none;
  background: #ffffff;
}

.taglia-box:last-child {
  border-right: none;
}

.taglia-box.clickable {
  cursor: pointer;
}

.taglia-box.clickable:hover {
  background: #f1f5f9;
}

.taglia-box.active {
  background: #000000;
  color: #ffffff;
}

.taglia-check {
  font-size: 9px;
  font-weight: 900;
}

.header-dotazione {
  border-bottom: 1px solid #000000;
}

.dotazione-grid {
  display: grid;
  grid-template-columns: 50% 50%;
  flex: 1;
}

.dotazione-col {
  display: flex;
  flex-direction: column;
}

.dotazione-col:first-child {
  border-right: 1px solid #000000;
}

.dotazione-row {
  display: flex;
  align-items: stretch;
  border-bottom: 1px solid #000000;
  min-height: 22px;
  flex: 1;
}

.dotazione-col .dotazione-row:last-child {
  border-bottom: none;
}

.dotazione-row.clickable {
  cursor: pointer;
}

.dotazione-row.clickable:hover {
  background: #f8fafc;
}

.dotazione-label {
  flex: 1;
  padding: 2px 6px;
  font-size: 9.5px;
  font-weight: 700;
  display: flex;
  align-items: center;
  border-right: 1px solid #000000;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.dot-check-cell {
  width: 26px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.box-check {
  width: 12px;
  height: 12px;
  border: 1px solid #000000;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 9px;
  font-weight: 900;
  line-height: 1;
  background: #ffffff;
  flex-shrink: 0;
}

.box-check.checked {
  background: #000000;
  color: #ffffff;
}

/* Colonna Email */
.col-email {
  display: flex;
  flex-direction: column;
}

.email-field-row {
  display: flex;
  align-items: stretch;
  border-bottom: 1px solid #000000;
  flex: 1;
  min-height: 28px;
}

.col-email .email-field-row:last-child {
  border-bottom: none;
}

.email-label {
  width: 40%;
  padding: 3px 6px;
  font-size: 9.5px;
  font-weight: 800;
  border-right: 1px solid #000000;
  display: flex;
  align-items: center;
  white-space: nowrap;
}

.email-val {
  flex: 1;
  padding: 3px 6px;
  display: flex;
  align-items: center;
}

.sheet-input-small {
  width: 70px;
  padding: 1px 4px;
  font-size: 9.5px;
  background: #eff6ff;
  border: 1px dashed #3b82f6;
  border-radius: 2px;
}

/* 6. Grid Bottom: Privacy & Pagamenti */
.grid-bottom {
  display: grid;
  grid-template-columns: 54% 46%;
  border: 1.5px solid #000000;
  margin-bottom: 0;
}

.col-privacy {
  border-right: 1.5px solid #000000;
  display: flex;
  flex-direction: column;
}

.header-privacy {
  display: flex;
  flex-direction: column;
  line-height: 1.15;
  height: 26px;
}

.header-privacy .sub {
  font-size: 8px;
  font-weight: 800;
}

.privacy-block {
  padding: 6px 8px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.priv-block-1 {
  flex: 1.1;
  border-bottom: 1px solid #000000;
}

.priv-block-2 {
  border: 1.5px solid #000000;
  margin: 4px;
  background: #fafafa;
}

.priv-block-3 {
  flex: 1.4;
  border-bottom: none;
}

.privacy-p {
  font-size: 8px;
  line-height: 1.3;
  margin: 0 0 6px 0;
  text-align: justify;
}

.small-p {
  font-size: 7.2px;
  line-height: 1.25;
}

.firma-container {
  display: flex;
  align-items: flex-end;
  margin-top: 4px;
}

.firma-title {
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: -0.01em;
  white-space: nowrap;
}

.firma-line {
  flex: 1;
  margin-left: 8px;
  border-bottom: 1px solid #000000;
  height: 14px;
}

/* Colonna Pagamenti & Rate */
.col-pagamenti {
  display: flex;
  flex-direction: column;
}

.pagamento-row {
  display: flex;
  align-items: stretch;
  border-bottom: 1px solid #000000;
  min-height: 24px;
  flex: 1;
}

.pag-label {
  width: 55%;
  padding: 2px 6px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: -0.02em;
  border-right: 1px solid #000000;
  display: flex;
  align-items: center;
  white-space: nowrap;
}

.pag-val {
  flex: 1;
  padding: 2px 6px;
  display: flex;
  align-items: center;
}

.row-costo-totale {
  background: #f8fafc;
}

.row-costo-totale .pag-label {
  font-weight: 900;
}

.sheet-input-num {
  width: 80px;
  padding: 1px 4px;
  font-size: 9.5px;
  background: #eff6ff;
  border: 1px dashed #3b82f6;
  border-radius: 2px;
}

.sheet-input-rec {
  width: 70px;
  padding: 1px 4px;
  font-size: 9px;
  background: #eff6ff;
  border: 1px dashed #3b82f6;
  border-radius: 2px;
}

.double-input {
  display: flex;
  gap: 4px;
  align-items: center;
}

.rec-tag {
  font-size: 8.5px;
  color: #475569;
  background: #f1f5f9;
  padding: 1px 4px;
  border-radius: 2px;
  border: 1px solid #cbd5e1;
}

.safeguarding-box {
  padding: 4px 6px;
  border-top: 1px solid #000000;
}

.safeguarding-box.clickable {
  cursor: pointer;
}

.safeguarding-box.clickable:hover {
  background: #f8fafc;
}

.safe-title {
  display: block;
  font-size: 8.5px;
  font-weight: 900;
  margin-bottom: 2px;
  letter-spacing: -0.02em;
}

.safe-line {
  display: flex;
  align-items: center;
  gap: 6px;
}

.safe-text {
  font-size: 8px;
  font-weight: 700;
  letter-spacing: -0.01em;
}

/* Barra Salva in basso */
.save-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(15, 23, 42, 0.95);
  backdrop-filter: blur(8px);
  border-top: 1px solid var(--color-border, #334155);
  padding: 0.85rem 1.5rem;
  z-index: 1000;
  box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.4);
}

.save-bar-content {
  max-width: 820px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.save-info {
  font-size: 0.825rem;
  color: #94a3b8;
}

.save-msg {
  font-size: 0.825rem;
  font-weight: 600;
}

.error-msg {
  color: #ef4444;
}

.success-msg {
  color: #10b981;
}

.save-actions {
  display: flex;
  gap: 0.65rem;
}

.btn-action {
  padding: 0.5rem 1.25rem;
  border-radius: 8px;
  font-size: 0.825rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-cancel {
  background: transparent;
  border: 1px solid #475569;
  color: #94a3b8;
}

.btn-cancel:hover:not(:disabled) {
  background: #334155;
  color: #fff;
}

.btn-save {
  background: #10b981;
  border: none;
  color: #ffffff;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 120px;
}

.btn-save:hover:not(:disabled) {
  background: #059669;
}

.spinner-small {
  width: 14px;
  height: 14px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* =========================================================
   MEDIA QUERY PER LA STAMPA (@media print)
   Garantisce bordi interni ed esterni completi,
   riempimento pagina e RIGOROSAMENTE 1 SOLA PAGINA!
   ========================================================= */
@media print {
  @page {
    size: A4 portrait;
    margin: 8mm; /* Margini regolari e uniformi su tutti e 4 i lati */
  }

  *, *:before, *:after {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  body, html {
    margin: 0 !important;
    padding: 0 !important;
    width: 100% !important;
    height: auto !important;
    min-height: 0 !important;
    background: #ffffff !important;
    color: #000000 !important;
    overflow: hidden !important;
  }

  .scheda-page {
    background: #ffffff !important;
    padding: 0 !important;
    margin: 0 !important;
    min-height: 0 !important;
    height: auto !important;
    display: block !important;
    overflow: hidden !important;
    page-break-after: avoid !important;
    break-after: avoid-page !important;
    break-after: avoid !important;
  }

  .no-print {
    display: none !important;
  }

  .foglio-iscrizione {
    max-width: 100% !important;
    width: 100% !important;
    margin: 0 !important;
    padding: 0 !important;
    border: none !important;
    box-shadow: none !important;
    box-sizing: border-box !important;
    display: flex !important;
    flex-direction: column !important;
    page-break-inside: avoid !important;
    break-inside: avoid !important;
    page-break-after: avoid !important;
    break-after: avoid !important;
    overflow: hidden !important;
  }

  .header-logo-row {
    margin-bottom: 2mm !important;
  }

  .stemma-societa {
    height: 50px !important;
  }

  .titolo-iscrizione {
    font-size: 15px !important;
    color: #0284c7 !important;
    margin: 2px 0 3px 0 !important;
  }

  .divider-line {
    margin-bottom: 3mm !important;
    height: 2px !important;
  }

  .grid-anagrafica {
    border: 1.5px solid #000000 !important;
    margin-bottom: 3.5mm !important;
  }

  .col-anagrafica.col-left {
    border-right: 1.5px solid #000000 !important;
  }

  .col-left .field-row {
    height: 28px !important;
  }

  .col-right .field-row {
    height: 22.4px !important;
  }

  .field-label {
    border-right: 1px solid #000000 !important;
    font-size: 9.5px !important;
    padding: 3px 6px !important;
  }

  .col-left .field-label {
    width: 42% !important;
  }

  .col-right .field-label {
    width: 52% !important;
  }

  .field-val {
    padding: 3px 6px !important;
  }

  .sheet-text {
    font-size: 9.5px !important;
  }

  .section-dotazione-email {
    margin-bottom: 3.5mm !important;
    border: 1.5px solid #000000 !important;
  }

  .col-dotazione {
    border-right: 1.5px solid #000000 !important;
  }

  .header-taglia {
    border-bottom: 1px solid #000000 !important;
    height: 22px !important;
    font-size: 10px !important;
  }

  .taglia-grid {
    border-bottom: 1px solid #000000 !important;
    height: 24px !important;
  }

  .taglia-box {
    border-right: 1px solid #000000 !important;
    font-size: 10px !important;
  }

  .header-dotazione {
    border-bottom: 1px solid #000000 !important;
    height: 22px !important;
    font-size: 10px !important;
  }

  .dotazione-col:first-child {
    border-right: 1px solid #000000 !important;
  }

  .dotazione-row {
    height: 22px !important;
    border-bottom: 1px solid #000000 !important;
  }

  .dotazione-label {
    border-right: 1px solid #000000 !important;
    font-size: 9.5px !important;
  }

  .dot-check-cell {
    width: 26px !important;
  }

  .col-email .email-field-row {
    flex: 1 !important;
    border-bottom: 1px solid #000000 !important;
  }

  .col-email .email-field-row:last-child {
    border-bottom: none !important;
  }

  .email-label {
    border-right: 1px solid #000000 !important;
    width: 40% !important;
    font-size: 9.5px !important;
    padding: 3px 6px !important;
  }

  .email-val {
    padding: 3px 6px !important;
  }

  .grid-bottom {
    border: 1.5px solid #000000 !important;
    margin-bottom: 0 !important;
  }

  .col-privacy {
    border-right: 1.5px solid #000000 !important;
  }

  .header-privacy {
    border-bottom: 1px solid #000000 !important;
    height: 26px !important;
  }

  .priv-block-1 {
    flex: 1.1 !important;
    border-bottom: 1px solid #000000 !important;
    padding: 6px 8px !important;
  }

  .priv-block-2 {
    border: 1.5px solid #000000 !important;
    margin: 4px !important;
    padding: 6px 8px !important;
  }

  .priv-block-3 {
    flex: 1.4 !important;
    padding: 6px 8px !important;
  }

  .privacy-p {
    font-size: 8px !important;
    line-height: 1.3 !important;
  }

  .small-p {
    font-size: 7.2px !important;
    line-height: 1.25 !important;
  }

  .firma-container {
    margin-top: 4px !important;
  }

  .firma-title {
    font-size: 8.5px !important;
  }

  .firma-line {
    height: 14px !important;
  }

  .col-pagamenti .section-header-bar {
    border-bottom: 1px solid #000000 !important;
    height: 22px !important;
    font-size: 10px !important;
  }

  .pagamento-row {
    height: 24px !important;
    border-bottom: 1px solid #000000 !important;
  }

  .pag-label {
    width: 55% !important;
    border-right: 1px solid #000000 !important;
    font-size: 9px !important;
  }

  .box-check {
    width: 12px !important;
    height: 12px !important;
    border: 1px solid #000000 !important;
  }

  .safeguarding-box {
    padding: 4px 6px !important;
    border-top: 1px solid #000000 !important;
  }

  .safe-title {
    font-size: 8.5px !important;
  }

  .safe-text {
    font-size: 8px !important;
  }
}

/* Responsive mobile */
@media (max-width: 768px) {
  .scheda-page {
    padding: 0.5rem 0.25rem 5rem;
  }

  .page-header {
    border-radius: 8px;
    margin-bottom: 0.75rem;
  }

  .btn-text {
    display: none;
  }

  .foglio-iscrizione {
    padding: 6px;
    font-size: 9px;
  }

  .field-label {
    min-width: 90px;
    font-size: 8px;
  }
}
</style>