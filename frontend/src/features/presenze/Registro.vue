<template>
  <!-- NIENTE overlay "ruota il dispositivo in orizzontale", qui. Non era un blocco nativo (in
       AndroidManifest non c'e' nessun screenOrientation): era un div messo sopra la tabella perche'
       13 colonne non ci stavano in verticale. Con la vista settimana le colonne sono 3 e il telefono
       si usa come si usa un telefono. Sull'Allenamenti l'overlay RESTA: li' la lavagna serve davvero
       in paesaggio. -->
  <div class="registro-page">
    <div class="bg-glow bg-glow-1"></div>
    <div class="bg-glow bg-glow-2"></div>

    <header class="page-header">
      <div class="header-top">
        <button class="btn-back-pill" @click="router.push('/scelta/' + (route.params.id || categoriaAttiva?.id))" title="Torna alla Scelta">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
          Indietro
        </button>
        <button class="btn-back-pill btn-home-pill" @click="router.push('/')" title="Torna alla Home">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
          Home
        </button>
        <div class="header-actions">
          <div class="header-badge">
            <span class="badge-dot"></span>
            {{ categoriaAttiva?.anno }}
          </div>
          <button class="btn-print-pill" @click="apriStampa" title="Stampa registro">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <polyline points="6 9 6 2 18 2 18 9"/>
              <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>
              <rect x="6" y="14" width="12" height="8"/>
            </svg>
            Stampa
          </button>
        </div>
      </div>
      <div class="header-main">
        <h1 class="category-name">
          <span class="name-gradient">{{ categoriaAttiva?.nome }}</span>
        </h1>
        <p class="header-subtitle">Registro presenze</p>
      </div>
    </header>

    <div class="mese-selector-pill">
      <div class="vista-toggle" role="group" aria-label="Vista del registro">
        <button type="button" :class="{ attiva: vista === 'settimana' }" @click="cambiaVista('settimana')"
                title="Solo i giorni di allenamento di questa settimana: 3 colonne, si vede in verticale">Settimana</button>
        <button type="button" :class="{ attiva: vista === 'mese' }" @click="cambiaVista('mese')"
                title="Tutti i giorni di allenamento del mese">Mese</button>
      </div>
      <template v-if="vista === 'settimana'">
        <button class="btn-nav-mese" @click="prevSettimana" title="Settimana precedente">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>
        <span class="mese-label">
          <!-- a 390px l'etichetta lunga ("23 Novembre – 29 Novembre 2026") spostava fuori barra le
               frecce e "Oggi", e il pulsante Mese finiva irraggiungibile: sotto i 768px si mostra la
               forma corta, che dice la stessa cosa in meta' spazio -->
          <span class="etichetta-lunga">{{ etichettaSettimana }}</span>
          <span class="etichetta-corta">{{ etichettaSettimanaCorta }}</span>
        </span>
        <button class="btn-nav-mese" @click="nextSettimana" title="Settimana successiva">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <polyline points="9 18 15 12 9 6"/>
          </svg>
        </button>
        <button class="btn-oggi" @click="vaiAdOggi" title="Torna alla settimana di oggi">Oggi</button>
      </template>
      <template v-else>
        <button class="btn-nav-mese" @click="prevMese" title="Mese precedente">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>
        <span class="mese-label">{{ meseLabel }} {{ anno }}</span>
        <button class="btn-nav-mese" @click="nextMese" title="Mese successivo">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <polyline points="9 18 15 12 9 6"/>
          </svg>
        </button>
      </template>
    </div>

    <div class="legenda">
      <span v-for="c in codiciOrdinati" :key="c.codice" :class="['badge', c.tipo]">
        <span class="badge-code">{{ c.codice }}</span>
        <span class="badge-desc">{{ c.descrizione }}</span>
      </span>
    </div>

    <div class="empty-state" v-if="settimanaVuota">
      <p>Nessun giorno di allenamento in <strong>{{ etichettaSettimana }}</strong>.</p>
      <button class="btn-oggi" @click="cambiaVista('mese')">Vedi tutti i giorni del mese</button>
    </div>

    <div class="table-wrapper" v-else>
      <template v-if="isDirigente">
        <table>
          <thead>
            <tr>
              <th class="th-num">#</th>
              <th class="th-nome">Cognome Nome</th>
              <th v-for="g in giorniVisibili" :key="g.data" :class="{ 'th-weekend': g.weekend }">
                <div class="giorno-num">{{ g.num }}</div>
                <div class="giorno-nome">{{ g.gg }}</div>
                <!-- in vista settimana la finestra puo' attraversare due mesi: senza il mese sotto il
                     numero, un "1" e un "3" non si sa se sono di dicembre o di gennaio -->
                <div class="giorno-mese" v-if="vista === 'settimana'">{{ mesiCorti[g.mese - 1] }}</div>
              </th>
              <th class="th-tot th-pres">TOT</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(persona, idx) in personeAlfabetiche" :key="persona.id">
              <td class="td-num">{{ idx + 1 }}</td>
              <td class="td-nome">
                <span class="persona-name">{{ persona.cognome }} {{ persona.nome }}</span>
              </td>
              <td v-for="g in giorniVisibili" :key="g.data"
                class="cella"
                :class="[getCodiceClasse(persona.id, g), { 'cella-locked': isAutoInfortunio(persona.id, g) }]"
                :title="titoloCella(persona, g)"
                @click="openEdit(persona, g)">
                {{ getCodice(persona.id, g) }}
              </td>
              <td class="td-tot td-pres">{{ totalePresenze(persona.id) }}</td>
            </tr>
          </tbody>
        </table>
      </template>
      <template v-else>


        <template v-if="isPortieri">
          <div v-for="cat in categoriePortieri" :key="cat" class="gruppo-block">
            <div class="gruppo-header">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                <path d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16"/>
                <polyline points="1 10 5 10 11 14"/>
                <polyline points="15 10 21 10 21 14"/>
              </svg>
              {{ cat }}
            </div>
            <table>
              <thead>
                <tr>
                  <th class="th-num">#</th>
                  <th class="th-nome">Cognome Nome</th>
                  <th v-for="g in giorniVisibiliPortieri" :key="g.data" :class="{ 'th-weekend': g.weekend }">
                    <div class="giorno-num">{{ g.num }}</div>
                    <div class="giorno-nome">{{ g.gg }}</div>
                    <div class="giorno-mese" v-if="vista === 'settimana'">{{ mesiCorti[g.mese - 1] }}</div>
                  </th>
                  <th class="th-tot th-pres">TOT</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(persona, idx) in personePerCategoria(cat)" :key="persona.id">
                  <td class="td-num">{{ idx + 1 }}</td>
                  <td class="td-nome">
                    <span class="persona-name">{{ persona.cognome }} {{ persona.nome }}</span>
                  </td>
                  <td v-for="g in giorniVisibiliPortieri" :key="g.data"
                    class="cella"
                    :class="[getCodiceClasse(persona.id, g), { 'cella-locked': isAutoInfortunio(persona.id, g) }]"
                    :title="titoloCella(persona, g)"
                    @click="openEdit(persona, g)">
                    {{ getCodice(persona.id, g) }}
                  </td>
                  <td class="td-tot td-pres">{{ totalePresenze(persona.id) }}</td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="riga-totale pres">
                  <td class="td-num"></td>
                  <td class="td-nome tot-label">Presenti</td>
                  <td v-for="g in giorniVisibiliPortieri" :key="g.data" class="tot-cell">
                    {{ totGiornoCategoria(cat, g).pres || '' }}
                  </td>
                  <td class="td-tot"></td>
                </tr>
              </tfoot>
            </table>
          </div>
        </template>
        <template v-if="!isPortieri">
        <div v-for="gruppo in gruppi" :key="gruppo" class="gruppo-block">
          <div class="gruppo-header">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87"/>
              <path d="M16 3.13a4 4 0 010 7.75"/>
            </svg>
            {{ gruppo }}
            <span v-if="gruppoIsMisto(gruppo)" class="badge-misto-registro">MISTO</span>
          </div>
          <table>
            <thead>
              <tr>
                <th class="th-num">#</th>
                <th class="th-nome">Cognome Nome</th>
                <th v-for="g in getGiorniVisibili(gruppo)" :key="g.data" :class="{ 'th-weekend': g.weekend }">
                  <div class="giorno-num">{{ g.num }}</div>
                  <div class="giorno-nome">{{ g.gg }}</div>
                  <div class="giorno-mese" v-if="vista === 'settimana'">{{ mesiCorti[g.mese - 1] }}</div>
                </th>
                <th class="th-tot th-pres">TOT</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(persona, idx) in personePerGruppo(gruppo)" :key="persona.id">
                <td class="td-num">{{ idx + 1 }}</td>
                <td class="td-nome">
                  <span class="persona-name">{{ persona.cognome }} {{ persona.nome }}</span>
                </td>
                <td v-for="g in getGiorniVisibili(gruppo)" :key="g.data"
                  class="cella"
                  :class="[getCodiceClasse(persona.id, g), { 'cella-locked': isAutoInfortunio(persona.id, g) }]"
                  :title="titoloCella(persona, g)"
                  @click="openEdit(persona, g)">
                  {{ getCodice(persona.id, g) }}
                </td>
                <td class="td-tot td-pres">{{ totalePresenze(persona.id) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="riga-totale pres">
                <td class="td-num"></td>
                <td class="td-nome tot-label">Presenti</td>
                <td v-for="g in getGiorniVisibili(gruppo)" :key="g.data" class="tot-cell">
                  {{ totGiornoGruppo(gruppo, g).pres || '' }}
                </td>
                <td class="td-tot"></td>
              </tr>
              <tr class="riga-totale ass">
                <td class="td-num"></td>
                <td class="td-nome tot-label">Assenti</td>
                <td v-for="g in getGiorniVisibili(gruppo)" :key="g.data" class="tot-cell">
                  {{ totGiornoGruppo(gruppo, g).ass || '' }}
                </td>
                <td class="td-tot"></td>
              </tr>
          </tfoot>
        </table>
      </div>
        </template>
      </template>
      
      <div class="totale-generale">
        <div class="totale-header">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <path d="M12 20V10"/>
            <path d="M18 20V4"/>
            <path d="M6 20v-4"/>
          </svg>
          Totale Generale
        </div>
        <table class="totale-table">
          <thead>
            <tr>
              <th class="th-label"></th>
              <th v-for="g in giorniVisibiliTutti" :key="g.data" :class="{ 'th-weekend': g.weekend }">
                <div class="giorno-num">{{ g.num }}</div>
                <div class="giorno-nome">{{ g.gg }}</div>
                <div class="giorno-mese" v-if="vista === 'settimana'">{{ mesiCorti[g.mese - 1] }}</div>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="tot-label th-label">Presenti</td>
              <td v-for="g in giorniVisibiliTutti" :key="g.data" class="tot-cell tot-pres">
                {{ totaliGiornoVisibili[g.data]?.pres || '' }}
              </td>
            </tr>
            <tr>
              <td class="tot-label th-label">Assenti</td>
              <td v-for="g in giorniVisibiliTutti" :key="g.data" class="tot-cell tot-ass">
                {{ totaliGiornoVisibili[g.data]?.ass || '' }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="editModal.show" class="modal-overlay" @click.self="editModal.show = false">
        <div class="modal modal-edit">
          <div class="modal-header">
            <h3>{{ editModal.persona.cognome }} {{ editModal.persona.nome }}</h3>
            <!-- editModal.giorno e' l'oggetto giorno (serve per la data vera, che in vista settimana
                 puo' essere del mese accanto): stampare l'oggetto avrebbe mostrato "[object Object]".
                 Qui il mese va per ESTESO: e' l'unica cosa che dice all'utente se sta scrivendo il 30
                 novembre o il 30 dicembre, e nel modal c'e' tutto lo spazio che sulla tabella manca -->
            <span class="modal-date" v-if="editModal.giorno">
              {{ editModal.giorno.num }} {{ mesiNomi[editModal.giorno.mese - 1] }} {{ editModal.giorno.anno }}
            </span>
          </div>
          <div class="codici-grid">
            <button v-for="c in codici" :key="c.codice"
              :class="['btn-codice', c.tipo]" @click="salvaPresenza(c.codice)">
              <span class="codice">{{ c.codice }}</span>
              <span class="descrizione">{{ c.descrizione }}</span>
            </button>
            <button class="btn-codice cancella" @click="salvaPresenza(null)">
              <span class="codice">-</span>
              <span class="descrizione">Cancella</span>
            </button>
          </div>
          <button class="btn-close-modal" @click="editModal.show = false">Chiudi</button>
        </div>
      </div>
    </Teleport>

    <Teleport to="body">
      <div v-if="printModal.show" class="modal-overlay" @click.self="printModal.show = false">
        <div class="modal modal-print">
          <div class="modal-header">
            <h3>Stampa registro</h3>
            <span class="modal-date">{{ meseLabel }} {{ anno }}</span>
          </div>
          <div class="print-options">
            <label class="print-option">
              <input type="radio" value="vuoto" v-model="printModal.tipo" />
              <span>
                <strong>Foglio vuoto</strong>
                <small>Per compilare a mano</small>
              </span>
            </label>
            <label class="print-option">
              <input type="radio" value="corrente" v-model="printModal.tipo" />
              <span>
                <strong>Con presenze</strong>
                <small>Codici già inseriti</small>
              </span>
            </label>
          </div>
          <div class="print-preview">
            <RegistroPrintSheet
              ref="previewSheetRef"
              :societa="societaAttiva"
              :categoria="categoriaAttiva"
              :mese-label="meseLabel"
              :anno="anno"
              :persone="personeAlfabetiche"
              :giorni="giorniMese"
              :codici="codiciOrdinati"
              :tipo="printModal.tipo"
              :is-portieri="isPortieri"
              :get-codice="getCodice"
              :totale-presenze="totalePresenze"
              :totali-giorno="totaliGiorno"
            />
          </div>
          <div class="print-actions">
            <button class="btn-close-modal inline" @click="printModal.show = false">Chiudi</button>
            <button class="btn-print-primary" @click="stampa">Stampa</button>
          </div>
        </div>
      </div>
    </Teleport>

    <Teleport to="body">
      <div v-if="printModal.show" class="print-root">
        <RegistroPrintSheet
          :societa="societaAttiva"
          :categoria="categoriaAttiva"
          :mese-label="meseLabel"
          :anno="anno"
          :persone="personeAlfabetiche"
          :giorni="giorniMese"
          :codici="codiciOrdinati"
          :tipo="printModal.tipo"
          :is-portieri="isPortieri"
          :get-codice="getCodice"
          :totale-presenze="totalePresenze"
          :totali-giorno="totaliGiorno"
          :scale="printScale"
        />
      </div>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch, nextTick } from "vue"
import { useRoute, useRouter } from "vue-router"
import { getPersone, getCodici, getRegistroMese, upsertRegistro, getCategorie, getGruppi, getInfortuni } from "../../api/index.js"
import { useStore as useCategoria } from "../../store.js"
import RegistroPrintSheet from "./RegistroPrintSheet.vue"

const route = useRoute()
const router = useRouter()
const categoriaId = computed(() => parseInt(route.params.id))
const { categoriaAttiva, utenteAttivo, societaAttiva } = useCategoria()
const isDirigente = computed(() => ['dirigente', 'segreteria', 'infermeria'].includes(utenteAttivo.value?.ruolo))
const isPortieri = computed(() => categoriaAttiva.value?.is_portieri)

// NIENTE checkOrientation/showRotateMessage qui: l'overlay "ruota il dispositivo" copriva la tabella
// perche' 13 colonne non ci stavano in verticale. Con la vista settimana le colonne sono 3 e il
// registro si usa in verticale come si usa un telefono. Sull'Allenamenti l'overlay RESTA (li' la
// lavagna serve davvero in paesaggio)

const oggi = new Date()

// ── VISTA SETTIMANA (per l'uso dal telefono) ──────────────────────────────────────
// Il registro e' una tabella persone x giorni, gia' filtrata sui soli giorni di allenamento:
// sono ~13 colonne (3 a settimana x 4,3 settimane), e per questo la pagina obbligava a ruotare il
// telefono. In vista settimana restano 3 colonne e sta in verticale.
// `giorniMese` NON viene ridotta alla settimana: e' la fonte del foglio di stampa
// (RegistroPrintSheet, alimentato due volte) e dei totali di mese. Ridurla lei avrebbe stampato un
// foglio con dentro una settimana sola, dicendo sul foglio "Registro di Novembre": plausibile e
// falso, e il mister se ne accorgerebbe in segreteria.
const vista = ref(window.innerWidth <= 768 ? 'settimana' : 'mese')
const lunedi = ref(lunediDi(oggi))   // lunedi' della settimana mostrata
// Righe del mese ACCANTO, necessarie perche' la settimana sconfinà (29/12 -> 4/01). Stanno SEPARATE
// da `registro`: totalePresenze/totaleAssenze contano le righe di `registro`, quindi fondere li'
// quelle di un altro mese gonfierebbe i totali di mese -- e il numero sbagliato uscirebbe anche dal
// foglio stampato.
const registroExtra = ref([])

// Il mese iniziale DEVE essere quello della finestra aperta, non "il mese di oggi": il 1° gennaio
// che cade di venerdi' apre la settimana 28/12-3/01, che e' una settimana DI DICEMBRE (il giovedi'
// e' il 31). Lasciare `mese` a gennaio avrebbe detto "Gennaio" nell'intestazione con dentro le celle
// di dicembre, e il foglio di stampa avrebbe stampato gennaio con i dati di dicembre.
const meseIniziale = vista.value === 'settimana'
  ? meseDiGiovedi(lunedi.value)
  : { anno: oggi.getFullYear(), mese: oggi.getMonth() + 1 }
const anno = ref(meseIniziale.anno)
const mese = ref(meseIniziale.mese)
const persone = ref([])
const codici = ref([])
const registro = ref([])
const infortuniAttivi = ref([])
const giorniAllenamento = ref([])
const giorniAllenamentoPortieriCat = ref([])

const editModal = ref({ show: false, persona: null, giorno: null })
const printModal = ref({ show: false, tipo: 'vuoto' })
const printScale = ref(1)
const previewSheetRef = ref(null)

function calcolaScalaStampa() {
  const el = previewSheetRef.value?.$el || previewSheetRef.value
  if (!el) return
  const mmToPx = 96 / 25.4
  const printableWidth = 194 * mmToPx
  const printableHeight = 281 * mmToPx
  const width = el.scrollWidth || el.getBoundingClientRect().width || printableWidth
  const height = el.scrollHeight || el.getBoundingClientRect().height || printableHeight
  printScale.value = Math.min(1, printableWidth / width, printableHeight / height)
}

function apriStampa() {
  printModal.value = { show: true, tipo: 'vuoto' }
  nextTick(calcolaScalaStampa)
}

watch(() => printModal.value.tipo, () => nextTick(calcolaScalaStampa))

function stampa() {
  calcolaScalaStampa()
  window.print()
}

const mesiNomi = ["Gennaio","Febbraio","Marzo","Aprile","Maggio","Giugno","Luglio","Agosto","Settembre","Ottobre","Novembre","Dicembre"]
// etichetta corta sotto il numero del giorno, per la vista settimana che puo' attraversare due mesi
const mesiCorti = ["Gen","Feb","Mar","Apr","Mag","Giu","Lug","Ago","Set","Ott","Nov","Dic"]
const giorniNomi = ["Dom","Lun","Mar","Mer","Gio","Ven","Sab"]

// ── i giorni come DATE vere, non come "numero del giorno" ─────────────────────────
// Finche' la pagina mostrava un solo mese, bastava il numero: la data si ricostruiva da
// `anno`+`mese` dello schermo. Con la settimana che sconfinà nel mese accanto no: il "giorno 1"
// letto a dicembre sarebbe il 1 dicembre invece del 1 gennaio, e la cella mostrerebbe il codice
// sbagliato senza dire niente. Ogni giorno porta quindi la sua `data` ISO, e chi legge cerca quella.
function pad2(n) { return String(n).padStart(2, "0") }
function isoDi(a, m, g) { return a + "-" + pad2(m) + "-" + pad2(g) }
function giornoDi(a, m, g) {
  const dow = new Date(a, m - 1, g).getDay()
  return { num: g, anno: a, mese: m, dow, gg: giorniNomi[dow], weekend: dow === 0 || dow === 6, data: isoDi(a, m, g) }
}
// lunedi' della settimana di una data. (getDay()+6)%7 perche' getDay() dice 0=domenica, e la
// settimana di lavoro italiana comincia da lunedi'
function lunediDi(q) {
  const d = new Date(q.getFullYear(), q.getMonth(), q.getDate())
  d.setDate(d.getDate() - ((d.getDay() + 6) % 7))
  return d
}
// il mese di una settimana e' quello del GIOVEDI' (regola ISO 8601): il 29/12-4/01 e' una settimana
// di dicembre perche' la maggior parte dei giorni e' a dicembre. Prendere il lunedi' la chiamerebbe
// dicembre quando e' quasi tutta gennaio, e il selettore del mese si leggerebbe sbagliato
function meseDiGiovedi(lun) {
  const g = new Date(lun.getFullYear(), lun.getMonth(), lun.getDate() + 3)
  return { anno: g.getFullYear(), mese: g.getMonth() + 1 }
}
// il filtro dei giorni di allenamento, in UN solo posto: `giorniAllenamento` vuoto significa
// "non configurato" e allora si mostrano tutti i giorni, come faceva gia' prima
function perGiorniDiAllenamento(lista, dows) {
  const s = new Set(dows || [])
  if (s.size === 0) return lista
  return lista.filter(g => s.has(g.dow))
}
const meseLabel = computed(() => mesiNomi[mese.value - 1])

const codiciOrdinati = computed(() => {
  const order = ['X', 'AG', 'AI', 'I', 'R']
  return [...codici.value].sort((a, b) => order.indexOf(a.codice) - order.indexOf(b.codice))
})

const giorniMese = computed(() => {
  const n = new Date(anno.value, mese.value, 0).getDate()
  return perGiorniDiAllenamento(
    Array.from({ length: n }, (_, i) => giornoDi(anno.value, mese.value, i + 1)),
    giorniAllenamento.value)
})

// Per il gruppo "Portieri" dentro una categoria normale: unisce giorni categoria + giorni Portieri
const giorniMesePortieri = computed(() => perGiorniDiAllenamento(
  Array.from({ length: new Date(anno.value, mese.value, 0).getDate() }, (_, i) => giornoDi(anno.value, mese.value, i + 1)),
  [...giorniAllenamento.value, ...giorniAllenamentoPortieriCat.value]))

// I sette giorni della settimana mostrata, CHE POSSONO STARE SU DUE MESI: per questo ogni giorno
// porta anno e mese suoi, e non viene ricostruito da `anno`/`mese` dello schermo
const giorniSettimana = computed(() => {
  if (!lunedi.value) return []
  return Array.from({ length: 7 }, (_, k) => {
    const d = new Date(lunedi.value.getFullYear(), lunedi.value.getMonth(), lunedi.value.getDate() + k)
    return giornoDi(d.getFullYear(), d.getMonth() + 1, d.getDate())
  })
})
const giorniSettimanaFiltrati = computed(() => perGiorniDiAllenamento(giorniSettimana.value, giorniAllenamento.value))
const giorniSettimanaPortieri = computed(() => perGiorniDiAllenamento(
  giorniSettimana.value, [...giorniAllenamento.value, ...giorniAllenamentoPortieriCat.value]))

const haGruppoPortieri = computed(() => gruppi.value.some(g => g?.toLowerCase() === 'portieri'))

// Totale generale: unione di tutti i giorni (categoria + portieri se presente)
const giorniMeseTutti = computed(() => haGruppoPortieri.value ? giorniMesePortieri.value : giorniMese.value)

// ── cio' che si vede A SCHERMO ────────────────────────────────────────────────────
// Sono LE DUE liste: queste per le tabelle a schermo, `giorniMese*` per il foglio di stampa.
// Non sono la stessa cosa e non devono diventarlo mai.
const giorniVisibili = computed(() => vista.value === 'settimana' ? giorniSettimanaFiltrati.value : giorniMese.value)
const giorniVisibiliPortieri = computed(() => vista.value === 'settimana' ? giorniSettimanaPortieri.value : giorniMesePortieri.value)
const giorniVisibiliTutti = computed(() => {
  if (vista.value !== 'settimana') return giorniMeseTutti.value
  return haGruppoPortieri.value ? giorniSettimanaPortieri.value : giorniSettimanaFiltrati.value
})

function getGiorniVisibili(gruppo) {
  return gruppo && gruppo.toLowerCase() === 'portieri' ? giorniVisibiliPortieri.value : giorniVisibili.value
}

// la vista settimana puo' capitare su una settimana SENZA allenamenti (pausa, o categoria che in
// quei giorni non si allena): senza un avviso a schermo si dipingono tabelle con la sola colonna del
// nome, che sembra un registro rotto e non "questa settimana non si allena"
const settimanaVuota = computed(() => vista.value === 'settimana' && giorniVisibiliTutti.value.length === 0)

const hasSenzaGruppo = computed(() => {
  return persone.value.some(p => !p.gruppo_nome && !p.gruppo_id)
})

const allGruppiNames = computed(() => {
  const fromPersone = persone.value.map(p => p.gruppo_nome).filter(Boolean)
  const fromDb = gruppiList.value.map(g => g.nome)
  const result = [...new Set([...fromPersone, ...fromDb])]
  if (hasSenzaGruppo.value) result.push("Senza gruppo")
  return result
})

const gruppi = computed(() => {
  const all = allGruppiNames.value
  const normali = all.filter(g => g && g?.toLowerCase() !== "senza gruppo" && g?.toLowerCase() !== "portieri").sort()
  const portieri = all.filter(g => g?.toLowerCase() === "portieri")
  const senza = all.filter(g => g?.toLowerCase() === "senza gruppo")
  return [...normali, ...portieri, ...senza]
})

const categoriePortieri = computed(() => {
  if (!isPortieri.value) return []
  const cats = [...new Set(persone.value.map(p => p.categoria_nome).filter(Boolean))].sort()
  return cats
})

function personePerCategoria(cat) {
  return persone.value.filter(p => p.categoria_nome === cat)
}

function personaLabel(p) {
  if (isPortieri.value && p.categoria_nome) {
    return `${p.cognome} ${p.nome} <span class="cat-badge">${p.categoria_nome}</span>`
  }
  return `${p.cognome} ${p.nome}`
}
const personeAlfabetiche = computed(() => [...persone.value].sort((a, b) => a.cognome.localeCompare(b.cognome)))
function personePerGruppo(g) { return persone.value.filter(p => (p.gruppo_nome || "Senza gruppo") === g) }
function gruppoIsMisto(g) { const gr = gruppiList.value.find(x => x.nome === g); return gr && (gr.is_misto || false) }
// UN solo punto dove si cerca il codice di una cella, e cerca per DATA. `registro` sono le righe del
// mese a schermo, `registroExtra` quelle del mese accanto servite dalla settimana che sconfinà.
function cercaEntry(personaId, data) {
  return registro.value.find(r => r.persona_id === personaId && r.data === data)
    || registroExtra.value.find(r => r.persona_id === personaId && r.data === data)
}
function righeRegistro() {
  return registroExtra.value.length ? registro.value.concat(registroExtra.value) : registro.value
}
function getCodice(personaId, g) {
  const d = g.data
  if (hasActiveInfortunio(personaId, d)) return "I"
  const entry = cercaEntry(personaId, d)
  if (entry) return entry.codice
  return ""
}

function isAutoInfortunio(personaId, g) {
  return hasActiveInfortunio(personaId, g.data)
}

function hasActiveInfortunio(personaId, dataStr) {
  return infortuniAttivi.value.some(inf => {
    if (inf.persona_id !== personaId) return false
    if (inf.data_inizio > dataStr) return false
    if (inf.data_fine && inf.data_fine < dataStr) return false
    return true
  })
}
function getCodiceClasse(personaId, g) {
  const codice = getCodice(personaId, g)
  const c = codici.value.find(x => x.codice === codice)
  if (!c) return ""
  const auto = isAutoInfortunio(personaId, g) ? " cod-auto" : ""
  return c.tipo + (codice ? " cod-" + codice.toLowerCase() : "") + auto
}
// Il TOT della riga e' il MESE, non la settimana: legge SOLO `registro`, mai `registroExtra`.
// Se leggesse anche il mese accanto, una settimana che sconfinà aggiungerebbe presenze di gennaio al
// totale di novembre -- e quel numero uscirebbe anche dal foglio stampato.
function totalePresenze(personaId) {
  return registro.value.filter(r => r.persona_id === personaId && ["X","R"].includes(r.codice) && !hasActiveInfortunio(r.persona_id, r.data)).length
}
function totaleAssenze(personaId) {
  let count = 0
  giorniMeseTutti.value.forEach(g => {
    const d = g.data
    const entry = registro.value.find(r => r.persona_id === personaId && r.data === d)
    if (entry && ["AG","AI","I"].includes(entry.codice)) count++
    else if (hasActiveInfortunio(personaId, d)) count++
  })
  return count
}
// `g` e l'oggetto giorno con la sua data vera: il modal deve scrivere il 1° gennaio, non "il giorno 1"
function openEdit(persona, g) {
  if (hasActiveInfortunio(persona.id, g.data)) return
  editModal.value = { show: true, persona, giorno: g }
}

function titoloCella(persona, g) {
  const codice = getCodice(persona.id, g)
  if (!codice) return 'Vuoto — clicca per segnare'
  const c = codici.value.find(x => x.codice === codice)
  return c ? `${c.codice} — ${c.descrizione}` : codice
}

async function salvaPresenza(codice) {
  const g = editModal.value.giorno
  await upsertRegistro({ persona_id: editModal.value.persona.id, data: g.data, codice, categoria_id: categoriaId.value })
  await loadRegistro()
  editModal.value.show = false
}

// Il conteggio di UNA giornata, in un solo posto. Prima c'erano tre copie quasi uguali (gruppo,
// categoria, totale): e' il modo in cui cominciano a divergere un dettaglio alla volta e nessuno se
// ne accorge, perche' ognuna di per se' sembra giusta.
// `ids` serve a due cose: limitare le righe contate e contare come assenti chi non ha nessuna riga
// ma ha un infortunio attivo (che una riga sua, nel registro, non la produce).
function contaGiorno(ids, data, righe) {
  const entries = righe.filter(r => r.data === data && r.codice && (!ids || ids.includes(r.persona_id)))
  let pres = 0
  let ass = 0
  entries.forEach(r => {
    if (hasActiveInfortunio(r.persona_id, data)) return
    if (["X","R"].includes(r.codice)) pres++
    else if (["AG","AI","I"].includes(r.codice)) ass++
  })
  ;(ids || []).forEach(id => { if (hasActiveInfortunio(id, data)) ass++ })
  return { pres: pres || "", ass: ass || "" }
}
function totGiornoGruppo(gruppo, g) {
  return contaGiorno(personePerGruppo(gruppo).map(p => p.id), g.data, righeRegistro())
}
function totGiornoCategoria(cat, g) {
  return contaGiorno(personePerCategoria(cat).map(p => p.id), g.data, righeRegistro())
}
// CHIAVE = data ISO, non il numero del giorno: con la settimana che sconfinà "1" sarebbe ambiguo fra
// dicembre e gennaio. Il foglio di stampa indicizza `totaliGiorno[g.data]`
const totaliGiorno = computed(() => {
  const result = {}
  const allIds = persone.value.map(p => p.id)
  giorniMeseTutti.value.forEach(g => { result[g.data] = contaGiorno(allIds, g.data, registro.value) })
  return result
})
// La riga dei totali a schermo segue le colonne VISIBILI, quindi in vista settimana dice i totali
// della settimana e non quelli del mese. Sono due numeri diversi e devono restare tali: quello del
// mese sta nella colonna TOT e sul foglio di stampa.
const totaliGiornoVisibili = computed(() => {
  const result = {}
  const allIds = persone.value.map(p => p.id)
  giorniVisibiliTutti.value.forEach(g => { result[g.data] = contaGiorno(allIds, g.data, righeRegistro()) })
  return result
})
// ── navigazione ───────────────────────────────────────────────────────────────────
// Mese e settimana sono due maniglie della STESSA finestra e devono restare coerenti: cambiare mese
// sposta la settimana, cambiare settimana sposta il mese (quello del giovedi', ISO 8601). Lasciarli
// indipendenti e' il modo in cui ti trovi "Novembre" scritto nell'intestazione con dentro le celle di
// dicembre -- e il foglio di stampa stampa novembre con i dati di dicembre.
function allineaSettimanaAlMese() {
  lunedi.value = lunediDi(new Date(anno.value, mese.value - 1, 1))
}
function prevMese() { if (mese.value === 1) { mese.value = 12; anno.value-- } else mese.value--; allineaSettimanaAlMese() }
function nextMese() { if (mese.value === 12) { mese.value = 1; anno.value++ } else mese.value++; allineaSettimanaAlMese() }
function spostaSettimana(giorni) {
  const d = new Date(lunedi.value.getFullYear(), lunedi.value.getMonth(), lunedi.value.getDate() + giorni)
  lunedi.value = d
  const m = meseDiGiovedi(d)
  anno.value = m.anno
  mese.value = m.mese
}
function prevSettimana() { spostaSettimana(-7) }
function nextSettimana() { spostaSettimana(7) }
function vaiAdOggi() {
  lunedi.value = lunediDi(new Date())
  const m = meseDiGiovedi(lunedi.value)
  anno.value = m.anno; mese.value = m.mese
}
function cambiaVista(v) {
  vista.value = v
  if (v === 'settimana' && !lunedi.value) allineaSettimanaAlMese()
}
// l'etichetta della settimana, per non far dire all'intestazione "Novembre" mentre guardi 30 nov-4 dic
const etichettaSettimana = computed(() => {
  const s = giorniSettimana.value
  if (!s.length) return ''
  const a = s[0], b = s[s.length - 1]
  // la settimana intera (lun-ven), non i soli giorni allenati: le frecce spostano la finestra di 7
  // giorni e l'intestazione deve dire quale finestra si sta guardando, non quali celle ci sono dentro
  return `${a.num} ${mesiNomi[a.mese - 1]} – ${b.num} ${mesiNomi[b.mese - 1]} ${b.anno}`
})
// la stessa finestra scritta corta, per il telefono: "30 Nov – 6 Dic 2026"
const etichettaSettimanaCorta = computed(() => {
  const s = giorniSettimana.value
  if (!s.length) return ''
  const a = s[0], b = s[s.length - 1]
  return a.mese === b.mese
    ? `${a.num} – ${b.num} ${mesiCorti[a.mese - 1]} ${b.anno}`
    : `${a.num} ${mesiCorti[a.mese - 1]} – ${b.num} ${mesiCorti[b.mese - 1]} ${b.anno}`
})

async function loadRegistro() {
  if (!categoriaId.value || isNaN(categoriaId.value)) return
  const res = await getRegistroMese(categoriaId.value, anno.value, mese.value)
  registro.value = res.data || []
  // Il mese ACCANTO serve solo alla settimana che ci sconfinà dentro, e finisce in una variabile
  // separata per non gonfiare i totali di mese (vedi registroExtra)
  const altri = new Set()
  if (vista.value === 'settimana') {
    giorniSettimana.value.forEach(g => {
      if (!(g.anno === anno.value && g.mese === mese.value)) altri.add(g.anno + '-' + g.mese)
    })
  }
  if (altri.size === 0) { registroExtra.value = []; return }
  const righe = []
  for (const chiave of altri) {
    const [a, m] = chiave.split('-').map(Number)
    try {
      const r = await getRegistroMese(categoriaId.value, a, m)
      righe.push(...(r.data || []))
    } catch (e) {
      // le celle di quel mese restano vuote: meglio vederle vuote che piene dei dati del mese sbagliato
      console.error('Errore caricamento registro del mese accanto (' + chiave + '):', e)
    }
  }
  registroExtra.value = righe
}
async function loadInfortuni() {
  if (!categoriaId.value || isNaN(categoriaId.value)) return
  try {
    const res = await getInfortuni({ categoria_id: categoriaId.value, attivi: true })
    infortuniAttivi.value = res.data || []
  } catch (e) {
    console.error('Errore caricamento infortuni:', e)
  }
}
const gruppiList = ref([])
async function loadPersone() {
  if (!categoriaId.value || isNaN(categoriaId.value)) return
  try {
    const p = await getPersone(categoriaId.value)
    persone.value = p.data
  } catch(e) { console.error('Error loading persone:', e) }
  try {
    const g = await getGruppi(categoriaId.value)
    gruppiList.value = (g.data || []).map(item =>
      typeof item === 'string' ? { id: null, nome: item, is_misto: false } : { id: item.id, nome: item.nome, is_misto: item.is_misto || false }
    )
  } catch(e) { console.error('Error loading gruppi:', e) }
  const idToGruppo = Object.fromEntries(gruppiList.value.map(g => [g.id, g]).filter(([id]) => id != null))
  persone.value.forEach(p => {
    if (p.gruppo_id && idToGruppo[p.gruppo_id]) {
      p.gruppo_nome = idToGruppo[p.gruppo_id].nome
      p.gruppo_is_misto = idToGruppo[p.gruppo_id].is_misto || false
    }
  })
}
async function loadCategoria() {
  const res = await getCategorie()
  const cat = res.data.find(c => c.id === categoriaId.value)
  if (cat && cat.giorni) {
    giorniAllenamento.value = cat.giorni.split(",").map(Number)
  } else {
    giorniAllenamento.value = []
  }

  // Per la categoria Portieri, usa i giorni della categoria Portieri
  if (isPortieri.value) {
    giorniAllenamento.value = cat && cat.giorni ? cat.giorni.split(",").map(Number) : []
  }

  // Cerca la categoria Portieri per avere i suoi giorni
  const portieriCat = res.data.find(c => c.is_portieri)
  if (portieriCat && portieriCat.giorni) {
    giorniAllenamentoPortieriCat.value = portieriCat.giorni.split(",").map(Number)
  } else {
    giorniAllenamentoPortieriCat.value = []
  }
}

onMounted(async () => {
  const [c] = await Promise.all([getCodici()])
  codici.value = c.data
  await loadCategoria()
  await loadPersone()
  await loadRegistro()
  await loadInfortuni()
})
// `lunedi` e `vista` fra le sorgenti: spostare la settimana SENZA cambiare mese (29 nov -> 2 dic
// resta novembre) non fa scattare il watch sul mese, e senza di essi le celle del mese accanto
// resterebbero vuote perche' `registroExtra` non viene mai ricaricata
watch([anno, mese, lunedi, vista], async () => {
  await loadRegistro()
  await loadInfortuni()
})
</script>

<style scoped>
.registro-page {
  position: relative;
  padding: 2rem 2rem 4rem;
  max-width: 1400px;
  margin: 0 auto;
  overflow: hidden;
  min-height: 100vh;
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
  right: -80px;
  background: radial-gradient(circle, rgba(220, 38, 38, 0.08) 0%, transparent 70%);
  animation: glowFloat 8s ease-in-out infinite;
}

.bg-glow-2 {
  width: 400px;
  height: 400px;
  bottom: -100px;
  left: -80px;
  background: radial-gradient(circle, rgba(124, 58, 237, 0.06) 0%, transparent 70%);
  animation: glowFloat 10s ease-in-out infinite reverse;
}

@keyframes glowFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(25px, -18px) scale(1.05); }
  66% { transform: translate(-18px, 12px) scale(0.95); }
}

/* ── Header ── */
.page-header {
  position: relative;
  z-index: 1;
  margin-bottom: 1.5rem;
  animation: fadeSlideIn 0.6s ease-out both;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.btn-back-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.4rem 0.4rem 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  color: var(--color-text-secondary);
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-back-pill svg {
  background: var(--color-bg);
  border-radius: 50%;
  width: 24px;
  height: 24px;
  padding: 3px;
}

.btn-back-pill:hover {
  background: var(--color-bg);
  border-color: var(--color-text-muted);
  color: var(--color-text);
}

.header-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(220, 38, 38, 0.1);
  border: 1px solid rgba(220, 38, 38, 0.2);
  border-radius: 100px;
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-primary);
}

.badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--color-primary);
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}

.header-main {
  position: relative;
}

.category-name {
  font-size: clamp(2rem, 6vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.05;
  margin-bottom: 0.25rem;
}

.name-gradient {
  background: linear-gradient(135deg, var(--color-text) 0%, var(--color-text) 40%, var(--color-primary) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.header-subtitle {
  font-size: 1rem;
  color: var(--color-text-muted);
  font-weight: 400;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-print-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: var(--color-primary);
  border: 1px solid var(--color-primary);
  border-radius: 100px;
  color: #fff;
  font-family: var(--font-sans);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-print-pill:hover {
  filter: brightness(1.1);
  box-shadow: 0 4px 16px var(--color-primary-light);
}

/* ── Mese Selector Pill ── */
.mese-selector-pill {
  position: relative;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  gap: 1rem;
  padding: 0.5rem 0.5rem 0.5rem 1.25rem;
  background: var(--color-surface);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 100px;
  margin-bottom: 1.25rem;
  animation: fadeSlideIn 0.6s ease-out 0.1s both;
}

.mese-label {
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--color-text);
  min-width: 160px;
  text-align: center;
}

/* sul telefono vince la forma corta (vedi il commento nel template): le due span sono la STESSA
   finestra scritta in due modi, non due informazioni diverse */
.etichetta-corta {
  display: none;
}

.btn-nav-mese {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: 50%;
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.btn-nav-mese:hover {
  background: rgba(220, 38, 38, 0.15);
  border-color: rgba(220, 38, 38, 0.3);
  color: var(--color-primary);
}

/* ── Legenda ── */
.legenda {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
  padding: 1rem 1.25rem;
  background: var(--color-surface);
  backdrop-filter: blur(10px);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  animation: fadeSlideIn 0.6s ease-out 0.2s both;
}

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.3rem 0.625rem;
  border-radius: 8px;
  font-size: 0.8125rem;
}

.badge-code {
  font-weight: 700;
  font-family: var(--font-mono);
}

.badge-desc {
  font-weight: 500;
}

.badge.presenza {
  background: rgba(22, 163, 74, 0.1);
  border: 1px solid rgba(22, 163, 74, 0.25);
  color: #15803d;
}

.badge.assenza {
  background: rgba(220, 38, 38, 0.08);
  border: 1px solid rgba(220, 38, 38, 0.25);
  color: #b91c1c;
}

.badge.extra {
  background: rgba(217, 119, 6, 0.1);
  border: 1px solid rgba(217, 119, 6, 0.25);
  color: #92400e;
}

/* ── Table Wrapper ── */
.table-wrapper {
  position: relative;
  z-index: 1;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  animation: fadeSlideIn 0.6s ease-out 0.3s both;
}

table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 0.8125rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  overflow: hidden;
  color: var(--color-text);
}

th, td {
  border: none;
  border-bottom: 1px solid var(--color-border-light);
  text-align: center;
  padding: 0.5rem 0.25rem;
  white-space: nowrap;
  color: var(--color-text);
}

tr:last-child td {
  border-bottom: none;
}

.th-num, .td-num { width: 40px; color: var(--color-text-muted); font-size: 0.75rem; }
.th-nome, .td-nome { text-align: left; min-width: 150px; padding-left: 1rem; }
.th-tot, .td-tot { min-width: 60px; }

.th-weekend {
  background: var(--color-bg);
  color: var(--color-text-muted);
}

th {
  background: var(--color-bg);
  font-weight: 600;
  color: var(--color-text-secondary);
  position: sticky;
  top: 0;
}

.giorno-num { font-weight: 600; font-size: 0.8125rem; color: var(--color-text); }
.giorno-nome { font-size: 0.6875rem; color: var(--color-text-muted); }

.persona-name {
  font-weight: 500;
  color: var(--color-text);
}

/* ── Group Blocks ── */
.gruppo-block {
  margin-bottom: 2rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  overflow: hidden;
}

.gruppo-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.875rem 1.25rem;
  background: linear-gradient(135deg, rgba(220, 38, 38, 0.15) 0%, rgba(220, 38, 38, 0.05) 100%);
  border-bottom: 1px solid rgba(220, 38, 38, 0.15);
  color: var(--color-text);
  font-weight: 600;
  font-size: 0.9375rem;
}

.gruppo-header svg {
  opacity: 0.7;
  color: var(--color-primary);
}

.badge-misto-registro {
  display: inline-block;
  padding: 0.125rem 0.5rem;
  border-radius: 6px;
  background: rgba(251, 191, 36, 0.15);
  border: 1px solid rgba(251, 191, 36, 0.3);
  color: #fbbf24;
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  margin-left: 0.25rem;
}


/* ── Cells ── */
.cella {
  cursor: pointer;
  font-weight: 600;
  font-family: var(--font-mono);
  min-width: 32px;
  transition: all var(--transition-fast);
  color: var(--color-text);
  border-radius: 4px;
}

.cella:hover {
  background: rgba(220, 38, 38, 0.1);
}

.cella:active {
  transform: scale(0.82);
}

.cella.presenza {
  background: rgba(22, 163, 74, 0.14);
  color: #15803d;
}

.cella.assenza {
  background: rgba(220, 38, 38, 0.1);
  color: #b91c1c;
}

.cella.cod-ag {
  background: rgba(217, 119, 6, 0.14) !important;
  color: #92400e !important;
}

.cella.cod-p {
  background: rgba(217, 119, 6, 0.14) !important;
  color: #92400e !important;
}

.cella.cod-r {
  background: rgba(22, 163, 74, 0.18) !important;
  color: #166534 !important;
  font-weight: 700;
}

.cella.cod-i {
  background: rgba(220, 38, 38, 0.16) !important;
  color: #991b1b !important;
  font-weight: 700;
}

.cella-locked {
  cursor: default !important;
  position: relative;
}

.cella-locked::after {
  content: '';
  position: absolute;
  top: 2px;
  right: 2px;
  width: 8px;
  height: 8px;
  background: rgba(248, 113, 113, 0.7);
  border-radius: 50%;
}

.cella.cod-auto {
  border: 1px dashed rgba(248, 113, 113, 0.4);
  background: rgba(220, 38, 38, 0.06) !important;
  color: rgba(248, 113, 113, 0.6) !important;
  font-style: italic;
}

.cella.cod-auto:hover {
  background: rgba(220, 38, 38, 0.18) !important;
  color: #f87171 !important;
  border-color: rgba(248, 113, 113, 0.6);
}

.td-pres { color: #15803d; font-weight: 700; }

.riga-totale td {
  background: var(--color-bg);
  font-weight: 600;
  font-size: 0.75rem;
  border-top: 1px solid var(--color-border-light);
  color: var(--color-text-secondary);
}

.riga-totale.pres td { color: #15803d; }
.riga-totale.ass td { color: #b91c1c; }

.tot-cell {
  font-weight: 600;
  font-family: var(--font-mono);
  color: var(--color-text-secondary);
}

/* ── Totale Generale ── */
.totale-generale {
  margin-top: 1.5rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 20px;
  overflow: hidden;
}

.totale-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.875rem 1.25rem;
  background: linear-gradient(135deg, rgba(124, 58, 237, 0.1) 0%, rgba(124, 58, 237, 0.03) 100%);
  border-bottom: 1px solid rgba(124, 58, 237, 0.18);
  color: #6d28d9;
  font-weight: 700;
  font-size: 0.8125rem;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}

.totale-generale table th {
  background: var(--color-bg);
  font-weight: 600;
  font-size: 0.75rem;
  padding: 0.375rem;
  color: var(--color-text-secondary);
}

.tot-label {
  font-weight: 600;
  text-align: left;
  padding-left: 1rem;
  color: var(--color-text-secondary);
}

.tot-pres {
  background: rgba(22, 163, 74, 0.08) !important;
  color: #15803d !important;
}

.tot-ass {
  background: rgba(220, 38, 38, 0.07) !important;
  color: #b91c1c !important;
}

/* ── Modals ── */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  animation: fadeIn 0.2s ease-out;
  backdrop-filter: blur(8px);
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.9) translateY(10px); }
  to { opacity: 1; transform: scale(1) translateY(0); }
}

@keyframes fadeSlideIn {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

/* ── Edit Modal ── */
.modal {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 24px;
  width: 100%;
  max-width: 480px;
  box-shadow: 0 25px 60px rgba(22, 24, 29, 0.25);
  animation: scaleIn 0.3s ease-out;
  overflow: hidden;
}

.modal-edit { max-width: 520px; }

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 1.5rem 1.5rem 0;
  gap: 1rem;
}

.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--color-text);
}

.modal-date {
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  font-weight: 500;
}

.codici-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 0.5rem;
  padding: 1.25rem 1.5rem;
}

.btn-codice {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0.875rem 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  cursor: pointer;
  transition: all var(--transition-fast);
  background: var(--color-bg);
}

.btn-codice:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
}

.btn-codice .codice {
  font-size: 1.25rem;
  font-weight: 700;
  font-family: var(--font-mono);
  margin-bottom: 0.25rem;
  color: var(--color-text);
}

.btn-codice .descrizione {
  font-size: 0.6875rem;
  color: var(--color-text-muted);
  text-align: center;
}

.btn-codice.presenza {
  border-color: rgba(22, 163, 74, 0.35);
  background: rgba(22, 163, 74, 0.08);
  color: #15803d;
}
.btn-codice.presenza:hover { background: rgba(22, 163, 74, 0.16); }

.btn-codice.assenza {
  border-color: rgba(220, 38, 38, 0.35);
  background: rgba(220, 38, 38, 0.07);
  color: #b91c1c;
}
.btn-codice.assenza:hover { background: rgba(220, 38, 38, 0.14); }

.btn-codice.extra {
  border-color: rgba(217, 119, 6, 0.35);
  background: rgba(217, 119, 6, 0.08);
  color: #92400e;
}
.btn-codice.extra:hover { background: rgba(217, 119, 6, 0.16); }

.btn-codice.cancella {
  border-color: var(--color-border);
  background: transparent;
  color: var(--color-text-muted);
}
.btn-codice.cancella:hover { background: var(--color-bg); }

.btn-close-modal {
  display: block;
  width: calc(100% - 3rem);
  margin: 0 1.5rem 1.5rem;
  padding: 0.75rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: 12px;
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-close-modal:hover {
  background: var(--color-border-light);
}

/* ── Print Modal ── */
.modal-print {
  max-width: 920px;
  width: calc(100vw - 2rem);
  max-height: 90vh;
  overflow-y: auto;
}

.print-options {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
  padding: 1.25rem 1.5rem 0;
}

.print-option {
  display: flex;
  align-items: flex-start;
  gap: 0.625rem;
  padding: 0.875rem;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-bg);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.print-option input {
  margin-top: 0.2rem;
  accent-color: var(--color-primary);
}

.print-option span {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.print-option strong {
  color: var(--color-text);
  font-size: 0.9rem;
}

.print-option small {
  color: var(--color-text-muted);
  font-size: 0.75rem;
}

.print-option:has(input:checked) {
  border-color: var(--color-primary);
  background: var(--color-primary-light);
}

.print-preview {
  margin: 1rem 1.5rem 0;
  padding: 1rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  overflow: auto;
  max-height: 52vh;
}

.print-preview :deep(.print-sheet) {
  min-width: 650px;
  box-shadow: 0 18px 40px rgba(0, 0, 0, 0.18);
  border-radius: 8px;
}

.print-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1.25rem 1.5rem 1.5rem;
}

.btn-close-modal.inline {
  width: auto;
  margin: 0;
  padding: 0 1.1rem;
  min-height: 44px;
}

.btn-print-primary {
  padding: 0 1.25rem;
  min-height: 44px;
  background: var(--color-primary);
  color: #fff;
  border: none;
  border-radius: 12px;
  font-size: 0.875rem;
  font-weight: 700;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-print-primary:hover {
  filter: brightness(1.1);
  box-shadow: 0 4px 16px var(--color-primary-light);
}

/* ── Toggle settimana / mese ── */
.vista-toggle {
  display: inline-flex;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  overflow: hidden;
  background: var(--color-surface);
}

.vista-toggle button {
  border: none;
  background: transparent;
  padding: 0.35rem 0.85rem;
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--color-text-muted);
  cursor: pointer;
  font-family: inherit;
  white-space: nowrap;
}

.vista-toggle button.attiva {
  background: var(--color-primary);
  color: #fff;
}

.btn-oggi {
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text);
  border-radius: 999px;
  padding: 0.3rem 0.7rem;
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
  white-space: nowrap;
}

.btn-oggi:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
}

/* il mese sotto il numero: in vista settimana la finestra puo' stare fra due mesi */
.giorno-mese {
  font-size: 0.62rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  opacity: 0.75;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--color-text-muted);
}

.empty-state p {
  margin-bottom: 1rem;
}

/* ── Responsive ── */
@media (max-width: 768px) {
  .registro-page {
    /* 56px e' l'altezza della bottom-nav fissa di App.vue: senza questo spazio le ultime righe della
       tabella (e i totali) restano SOTTO la barra, e "usabile in verticale" non lo sarebbe */
    padding: 1rem 0.5rem calc(56px + 2rem + env(safe-area-inset-bottom, 0px));
  }

  .page-header {
    margin-bottom: 1rem;
  }

  .header-top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .header-actions {
    width: 100%;
    justify-content: space-between;
  }

  .print-options {
    grid-template-columns: 1fr;
    padding: 1rem 1rem 0;
  }

  .print-preview {
    margin: 0.75rem 1rem 0;
    padding: 0.5rem;
    max-height: 48vh;
  }

  .print-actions {
    padding: 1rem 1rem 1.25rem;
  }

  .category-name {
    font-size: 1.75rem;
  }

  .header-subtitle {
    font-size: 0.9rem;
  }

  /* A 390px la barra NON sta su una riga: toggle + due frecce + etichetta + "Oggi" sono ~430px.
     Senza wrap il pulsante "Mese" finiva fuori dalla barra e il click non arrivava a segno (misurato
     col browser: il modo Mese non si attivava proprio). Il toggle va sulla sua riga, la navigazione
     sulla seconda. */
  .mese-selector-pill {
    width: 100%;
    flex-wrap: wrap;
    row-gap: 0.5rem;
    justify-content: center;
    padding: 0.5rem 0.6rem;
    margin-bottom: 0.75rem;
  }

  .vista-toggle {
    order: -1;
    flex: 0 0 100%;
    justify-content: center;
  }

  .etichetta-lunga { display: none; }
  .etichetta-corta { display: inline; }

  .legenda {
    flex-wrap: wrap;
    gap: 0.375rem;
    padding: 0.5rem;
  }

  .badge {
    padding: 0.25rem 0.5rem;
    font-size: 0.7rem;
  }

  .badge-code {
    font-size: 0.7rem;
  }

  .badge-desc {
    display: none;
  }

  .table-wrapper {
    border-radius: 12px;
    -webkit-overflow-scrolling: touch;
  }

  .table-wrapper::-webkit-scrollbar {
    height: 4px;
  }

  .btn-back-pill {
    padding: 0.4rem 0.75rem;
    font-size: 0.8rem;
  }

  .gruppo-header {
    padding: 0.75rem 1rem;
    font-size: 0.85rem;
  }

  .modal {
    max-width: 100%;
    border-radius: var(--radius-lg);
    max-height: 85vh;
    overflow-y: auto;
  }

  .codici-grid {
    grid-template-columns: repeat(3, 1fr);
    gap: 0.375rem;
    padding: 1rem;
  }

  .btn-codice {
    padding: 0.75rem 0.375rem;
    border-radius: 10px;
    min-height: 48px;
  }

  .btn-codice .codice {
    font-size: 1.1rem;
  }

  .btn-codice .descrizione {
    font-size: 0.6rem;
  }

  .modal-header {
    padding: 1.25rem 1.25rem 0;
  }

  .btn-close-modal {
    width: calc(100% - 2.5rem);
    margin: 0 1.25rem 1.25rem;
    min-height: 44px;
  }
}

@media (max-width: 480px) {
  .registro-page {
    padding: 0.75rem 0.375rem 1.5rem;
  }

  .category-name {
    font-size: 1.5rem;
  }

  .mese-label {
    font-size: 0.85rem;
    min-width: 120px;
  }

  .btn-nav-mese {
    width: 36px;
    height: 36px;
  }

  .codici-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  /* il toggle e le frecce stanno nella pill a 390px: senza questo, "Settimana | Mese" piu' le
     frecce e l'etichetta della settimana andavano a capo e la barra mangiava mezza schermata */
  .vista-toggle button {
    padding: 0.3rem 0.6rem;
    font-size: 0.76rem;
  }

  .btn-oggi {
    padding: 0.25rem 0.55rem;
    font-size: 0.72rem;
  }
}
</style>
