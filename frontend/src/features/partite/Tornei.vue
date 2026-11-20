<template>
  <div class="tornei-page">
    <div class="page-header">
      <button class="btn-back" @click="tornaIndietro">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
          <path d="M19 12H5M12 19l-7-7 7-7"/>
        </svg>
        <span>Indietro</span>
      </button>
      <h2>{{ solaLettura ? 'Convocazioni Tornei' : 'Programmazione Tornei' }}</h2>
      <button v-if="!solaLettura" class="btn-primary" @click="apriModalTorneo()">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        <span>Nuovo torneo</span>
      </button>
    </div>

    <p v-if="solaLettura" class="nota">
      I tornei della tua società. Apri la lista per scegliere i giocatori e stampare il file da
      consegnare all'organizzatore.
    </p>

    <div class="filtri">
      <select v-model="categoriaFiltro" class="select-filtro" @change="carica">
        <option value="">Tutte le categorie</option>
        <option v-for="c in categorieOperative" :key="c.id" :value="c.id">{{ etichettaCategoria(c) }}</option>
      </select>
      <label class="filtro-data">
        <span>Da</span>
        <input type="date" v-model="daFiltro" @change="carica" />
      </label>
      <label class="filtro-data">
        <span>A</span>
        <input type="date" v-model="aFiltro" @change="carica" />
      </label>
    </div>

    <p v-if="errore" class="messaggio errore">{{ errore }}</p>
    <p v-if="conferma" class="messaggio successo">{{ conferma }}</p>
    <div v-if="caricamento" class="stato">Caricamento…</div>
    <div v-else-if="!tornei.length" class="stato">
      {{ solaLettura
          ? 'Nessun torneo inserito per ora.'
          : 'Nessun torneo. Con "Nuovo torneo" si crea anche la Lista Tornei collegata.' }}
    </div>

    <!-- Prima le categorie, come fa la programmazione partite del weekend: la sezione "2016 - Pulcini"
         e' il primo livello e dentro ci sono i tornei a cui i Pulcini sono iscritti. Un torneo
         iscritto a due categorie compare in entrambe, ed e' voluto: cio' che chi guarda cerca e'
         "cosa fa la MIA categoria", non "cosa e' questo torneo". Le azioni pero' restano del torneo
         intero, quindi la card dice esplicitamente le altre categorie coinvolte prima di distruggerlo -->
    <section v-for="sez in sezioniPerCategoria" :key="sez.chiave" class="categoria-sezione">
      <h2 class="categoria-intestazione">
        {{ sez.titolo }}
        <span class="conteggio-sezione">{{ sez.tornei.length }} {{ sez.tornei.length === 1 ? 'torneo' : 'tornei' }}</span>
      </h2>

      <div v-for="t in sez.tornei" :key="t.id" class="torneo-card">
        <div class="torneo-testata" @click="apriCalendario(t, sez)">
          <div class="torneo-titolo">
            <span class="torneo-nome">{{ t.nome }}</span>
            <!-- Solo le gare DI QUESTA categoria: "6 gare" detto nella sezione Pulcini sarebbe falso
                 se 4 sono degli Esordienti -->
            <span v-if="t.gare_per_categoria && t.gare_per_categoria[sez.catId]" class="badge gare">
              {{ t.gare_per_categoria[sez.catId] }} {{ t.gare_per_categoria[sez.catId] === 1 ? 'gara' : 'gare' }}
            </span>
            <span v-if="foglioDi(t, sez.catId)" class="badge lista" :class="{ vuota: !foglioDi(t, sez.catId).giocatori }">
              {{ foglioDi(t, sez.catId).giocatori }} {{ foglioDi(t, sez.catId).giocatori === 1 ? 'giocatore' : 'giocatori' }}
            </span>
            <!-- Il foglio nasce da solo con l'iscrizione: se manca, qui c'e' un buco reale ed e'
                 esattamente il caso che in due anni ha lasciato i tornei senza documento -->
            <span v-else class="badge lista vuota">foglio assente</span>
            <!-- Le altre categorie dello stesso torneo: non e' decorazione, e' l'avvertenza che
                 "Elimina" qui si porta via anche loro -->
            <span v-for="a in altreCategorie(t, sez.catId)" :key="a.id" class="badge categoria altrui">
              anche {{ etichettaCategoria(a) }}
            </span>
            <span v-if="t.gare_orfane" class="badge lista vuota" :title="'Gare senza categoria, o con una categoria non piu\' iscritta al torneo'">
              {{ t.gare_orfane }} {{ t.gare_orfane === 1 ? 'gara' : 'gare' }} senza categoria
            </span>
          </div>
          <div class="torneo-meta">
            <span v-if="t.data_inizio || t.data_fine">{{ formatoPeriodo(t) }}</span>
            <span v-if="t.luogo">{{ t.luogo }}</span>
            <span v-if="t.organizzatore">a cura di {{ t.organizzatore }}</span>
          </div>
          <p v-if="t.descrizione" class="torneo-descrizione">{{ t.descrizione }}</p>
        </div>

        <div class="torneo-azioni">
          <button class="btn-azione" @click="apriCalendario(t, sez)">
            {{ calendarioAperto === chiaveCalendario(t, sez) ? 'Chiudi calendario' : 'Calendario' }}
          </button>
          <!-- Una sola categoria per sezione, quindi il bottone non deve piu' dire QUALE foglio:
               lo dice l'intestazione della sezione -->
          <button
            v-if="foglioDi(t, sez.catId)"
            class="btn-azione primario"
            @click="apriLista(foglioDi(t, sez.catId))"
            title="Apre il foglio giocatori di questa categoria: scegli i giocatori ed esporta il PDF"
          >Foglio giocatori</button>
          <button v-else class="btn-azione" disabled :title="'Nessun foglio per ' + etichettaCategoria(sez) + ' in questo torneo'">
            Foglio giocatori
          </button>
          <template v-if="!solaLettura">
            <button class="btn-azione" @click="apriModalTorneo(t)">Modifica</button>
            <button class="btn-azione pericolo" @click="elimina(t, sez)">Elimina</button>
          </template>
        </div>

        <div v-if="calendarioAperto === chiaveCalendario(t, sez)" class="calendario">
          <div v-if="!gareDiCategoria(t, sez.catId)" class="stato piccolo">Nessuna gara per questa categoria.</div>
          <div v-for="g in gareDiCategoria(t, sez.catId)" :key="g.id" class="gara-riga">
            <div class="gara-numero">{{ g.numero || '–' }}</div>
            <div class="gara-corpo">
              <div class="gara-verso">
                <strong>{{ g.avversario || 'Da definire' }}</strong>
              </div>
              <div class="gara-dettaglio">
                <span v-if="g.data">{{ formatoData(g.data) }}</span>
                <span v-if="g.ora">inizio {{ g.ora }}</span>
                <span v-if="g.ora_appuntamento">appuntamento {{ g.ora_appuntamento }}</span>
                <span v-if="g.campo">{{ g.campo }}<template v-if="g.indirizzo"> — {{ g.indirizzo }}</template></span>
              </div>
              <div v-if="g.note" class="gara-note">{{ g.note }}</div>
            </div>
            <div v-if="!solaLettura" class="gara-azioni">
              <button class="btn-icon" @click="apriModalGara(t, g, sez)" title="Modifica gara">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                  <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                  <path d="M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4z"/>
                </svg>
              </button>
              <button class="btn-icon pericolo" @click="eliminaGara(t, g, sez)" title="Elimina gara">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                  <polyline points="3 6 5 6 21 6"/>
                  <path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                </svg>
              </button>
            </div>
          </div>
          <!-- Le gare senza categoria, o con una categoria non piu' iscritta, una sezione loro non
               ce l'hanno: si mostrano qui, in ogni sezione del torneo, perche' nasconderle sarebbe
               peggio che ripetere -->
          <template v-if="gareOrfaneDi(t).length">
            <h4 class="orfane-intestazione">Senza categoria ({{ gareOrfaneDi(t).length }})</h4>
            <div v-for="g in gareOrfaneDi(t)" :key="'orfana-' + g.id" class="gara-riga orfana">
              <div class="gara-numero">{{ g.numero || '–' }}</div>
              <div class="gara-corpo">
                <div class="gara-verso"><strong>{{ g.avversario || 'Da definire' }}</strong></div>
                <div class="gara-dettaglio">
                  <span v-if="g.data">{{ formatoData(g.data) }}</span>
                  <span v-if="g.ora">inizio {{ g.ora }}</span>
                  <span v-if="g.campo">{{ g.campo }}</span>
                </div>
              </div>
              <div v-if="!solaLettura" class="gara-azioni">
                <button class="btn-icon" @click="apriModalGara(t, g)" title="Modifica gara">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                    <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                    <path d="M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4z"/>
                  </svg>
                </button>
              </div>
            </div>
          </template>
          <button v-if="!solaLettura" class="btn-aggiungi" @click="apriModalGara(t, null, sez)">
            + Aggiungi gara per {{ sez.titolo }}
          </button>
        </div>
      </div>
    </section>

    <!-- Modal torneo -->
    <Teleport to="body">
      <div v-if="modalTorneo" class="modal-overlay" @click.self="modalTorneo = false">
        <div class="modal">
          <div class="modal-header">
            <h3>{{ torneoDaModificare ? 'Modifica torneo' : 'Nuovo torneo' }}</h3>
            <button class="modal-close" @click="modalTorneo = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <p v-if="!torneoDaModificare" class="suggerimento">
              Con il torneo viene creata anche la Lista Tornei della categoria: il mister la trova
              già pronta in Liste Tornei.
            </p>
            <div class="form-group">
              <label>Torneo *</label>
              <input v-model="formTorneo.nome" placeholder="es. Torneo di Natale" />
            </div>
            <!-- CREAZIONE: le categorie che partecipano. Caselle e non menu a tendina perche' la
                 scelta e' multipla: un torneo di stagione con Pulcini ed Esordienti dentro e' la
                 norma, non l'eccezione, e col menu a tendina diventavano due tornei omonimi -->
            <div v-if="!torneoDaModificare" class="form-group">
              <label>
                Categorie iscritte *
                <span class="conteggio">{{ (formTorneo.categorie_id || []).length }} scelte</span>
              </label>
              <div class="scelta-categorie">
                <label v-for="c in categorieOperative" :key="c.id" class="scelta-categoria">
                  <input type="checkbox" :value="c.id" v-model="formTorneo.categorie_id" />
                  <span>{{ etichettaCategoria(c) }}</span>
                </label>
              </div>
              <p class="suggerimento">
                Per ognuna viene creato il suo foglio giocatori, quello da consegnare all'organizzatore.
              </p>
            </div>

            <!-- MODIFICA: le categorie NON si toccano con la richiesta che rinomina il torneo (il
                 PUT le ignora di proposito, perche' toglierne una significa gestire il suo foglio
                 giocatori). Qui si usano le rotte dedicate, con le loro regole. -->
            <div v-else class="form-group">
              <label>Categorie iscritte</label>
              <div class="scelta-categorie">
                <span v-for="c in categorieDel(torneoDaModificare)" :key="c.id" class="chip-categoria">
                  {{ etichettaCategoria(c) }}
                  <button type="button" class="chip-x" title="Rimuovi l'iscrizione" @click="togliCategoria(c)">✕</button>
                </span>
                <span v-if="!categorieDel(torneoDaModificare).length" class="suggerimento">nessuna categoria iscritta</span>
              </div>
              <div class="aggiungi-categoria">
                <select v-model="nuovaCategoria">
                  <option :value="null" disabled>Aggiungi categoria…</option>
                  <option v-for="c in categorieNonIscritte" :key="c.id" :value="c.id">{{ etichettaCategoria(c) }}</option>
                </select>
                <button type="button" class="btn-secondary" :disabled="!nuovaCategoria || salvataggio" @click="aggiungiCategoria">
                  Iscriviti
                </button>
              </div>
            </div>
            <div class="form-riga">
              <div class="form-group">
                <label>Dal</label>
                <input type="date" v-model="formTorneo.data_inizio" />
              </div>
              <div class="form-group">
                <label>Al</label>
                <input type="date" v-model="formTorneo.data_fine" />
              </div>
            </div>
            <div class="form-group">
              <label>Luogo / struttura</label>
              <input v-model="formTorneo.luogo" placeholder="es. Palazzetto di Via Roma" />
            </div>
            <div class="form-group">
              <label>Organizzatore</label>
              <input v-model="formTorneo.organizzatore" placeholder="es. Società X" />
            </div>
            <div class="form-group">
              <label>Note</label>
              <textarea v-model="formTorneo.descrizione" rows="3"
                        placeholder="quote, orari di arrivo, documenti richiesti…"></textarea>
            </div>
            <p v-if="erroreModal" class="messaggio errore">{{ erroreModal }}</p>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="modalTorneo = false">Annulla</button>
            <button class="btn-primary" @click="salvaTorneo" :disabled="salvataggio">
              {{ salvataggio ? 'Salvataggio…' : 'Salva' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal gara -->
    <Teleport to="body">
      <div v-if="modalGara" class="modal-overlay" @click.self="modalGara = false">
        <div class="modal">
          <div class="modal-header">
            <h3>{{ garaDaModificare ? 'Modifica gara' : 'Nuova gara' }}</h3>
            <button class="modal-close" @click="modalGara = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <!-- La categoria della gara serve solo quando il torneo ne ha piu' d'una: con una sola
                 iscritta il backend la deduce da solo, e chiederla ogni volta sarebbe rumore. Quando
                 sono piu' d'una va chiesta per forza: indovinarla vorrebbe dire mettere la gara nel
                 foglio sbagliato da consegnare -->
            <div v-if="categorieDelTorneoGara().length > 1" class="form-group">
              <label>Categoria della gara *</label>
              <select v-model="formGara.categoria_id">
                <option :value="null" disabled>Seleziona…</option>
                <option v-for="c in categorieDelTorneoGara()" :key="c.id" :value="c.id">{{ etichettaCategoria(c) }}</option>
              </select>
            </div>
            <div v-else-if="categorieDelTorneoGara().length === 1" class="form-group">
              <label>Categoria della gara</label>
              <p class="suggerimento">{{ etichettaCategoria(categorieDelTorneoGara()[0]) }} — l'unica iscritta al torneo</p>
            </div>
            <div class="form-riga">
              <div class="form-group">
                <label>Numero</label>
                <input type="number" v-model="formGara.numero" min="1" placeholder="automatico" />
              </div>
              <div class="form-group">
                <label>Avversario</label>
                <input v-model="formGara.avversario" placeholder="es. Young Boys" />
              </div>
            </div>
            <div class="form-riga">
              <div class="form-group">
                <label>Data</label>
                <input type="date" v-model="formGara.data" />
              </div>
              <div class="form-group">
                <label>Ora inizio</label>
                <input v-model="formGara.ora" placeholder="10:30" />
              </div>
            </div>
            <div class="form-riga">
              <div class="form-group">
                <label>Appuntamento</label>
                <input v-model="formGara.ora_appuntamento" placeholder="09:45" />
              </div>
              <div class="form-group">
                <label>Campo</label>
                <input v-model="formGara.campo" placeholder="es. Campo 2 sintetico" />
              </div>
            </div>
            <div class="form-group">
              <label>Indirizzo</label>
              <input v-model="formGara.indirizzo" />
            </div>
            <div class="form-group">
              <label>Note</label>
              <textarea v-model="formGara.note" rows="2"></textarea>
            </div>
            <p v-if="erroreModal" class="messaggio errore">{{ erroreModal }}</p>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="modalGara = false">Annulla</button>
            <button class="btn-primary" @click="salvaGara" :disabled="salvataggio">
              {{ salvataggio ? 'Salvataggio…' : 'Salva' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getTornei, getTorneo, creaTorneo, aggiornaTorneo, eliminaTorneo,
  aggiungiGaraTorneo, modificaGaraTorneo, eliminaGaraTorneo, getAllCategorie, isParentCategory,
  iscriviCategoriaTorneo, rimuoviCategoriaTorneo
} from '../../api/index.js'
import { useStore } from '../../store.js'

const route = useRoute()
const router = useRouter()
const { utenteAttivo, societaAttiva } = useStore()

// Una sola pagina per due ingressi: chi arriva da /responsabili/tornei (admin) modifica, chi
// arriva da Scelta.vue come "Convocazioni Tornei" legge e basta. Il livello di modifica lo decide
// il ruolo e non la rotta, cosi' un admin che entra dal link dei mister non resta senza pulsanti
// e un mister non vede controlli che il backend gli rifiuterebbe comunque.
const solaLettura = computed(() => !(utenteAttivo.value?.is_admin || utenteAttivo.value?.is_super_admin))

const tornei = ref([])
const categorie = ref([])
const gareCache = ref({})
const caricamento = ref(true)
const salvataggio = ref(false)
const errore = ref('')
const conferma = ref('')
const erroreModal = ref('')
const calendarioAperto = ref(null)

// Da Scelta.vue (/tornei/:id) si arriva gia' filtrati sulla categoria della card. Number() perche'
// i parametri della rotta sono stringhe mentre le option usano c.id numerico: senza la conversione
// il menu a tendina non mostrerebbe la categoria gia' selezionata all'ingresso del mister
const categoriaFiltro = ref(route.params.id && !isNaN(Number(route.params.id)) ? Number(route.params.id) : '')
const daFiltro = ref('')
const aFiltro = ref('')

const modalTorneo = ref(false)
const torneoDaModificare = ref(null)
const formTorneo = ref({})
const modalGara = ref(false)
const garaDaModificare = ref(null)
const garaTorneoId = ref(null)
// La sezione da cui il modal e' stato aperto: serve a riaprire il calendario ESATTAMENTE dove era,
// perche' con la pagina suddivisa per categorie la chiave e' torneo+sezione e "riapri il torneo" non
// riapre niente (era il bug che faceva sparire il calendario dopo aver salvato una gara)
const garaSezione = ref(null)
const formGara = ref({})
// La categoria da iscrivere nel modal di modifica: niente di selezionato finche' non si sceglie
const nuovaCategoria = ref(null)

function tornaIndietro() {
  if (route.params.id) router.push('/scelta/' + route.params.id)
  else router.push('/responsabili')
}

// "Agonistica" e "Scuola Calcio" sono gruppi, non categorie con giocatori: il responsabile non
// deve poter iscrivere un torneo a un gruppo. E' la stessa isParentCategory di ProgrammazionePartite
const categorieOperative = computed(() =>
  (categorie.value || []).filter(c => !isParentCategory(c, categorie.value))
    .slice().sort((a, b) => (a.anno || 9999) - (b.anno || 9999))
)

// Etichetta "2012 - Esordienti", il formato gia' usato in ProgrammazionePartite.vue. Senza l'anno
// le due "Esordienti" della societa' sembrano la stessa voce e il responsabile iscrive il torneo
// alla categoria sbagliata, con la lista dei giocatori gia' creata dietro di esso
function etichettaCategoria(c) {
  if (!c) return 'categoria'
  return c.anno ? `${c.anno} - ${c.nome}` : c.nome
}

// ------------------------------------------------------- categorie e fogli di un torneo
// Un torneo iscrive N categorie. `t.categoria_id` e' solo la "prima", il ricordo del tempo in cui
// di categorie ne esisteva una sola: le liste della pagina leggono `t.categorie`, che e' la verita',
// e ripiegano sul vecchio campo solo se il backend e' piu' vecchio della migrazione.
function categorieDel(t) {
  if (!t) return []
  if (Array.isArray(t.categorie)) return t.categorie
  return t.categoria_id ? [{ id: Number(t.categoria_id), nome: null, anno: null }] : []
}

function listeDel(t) {
  if (!t) return []
  if (Array.isArray(t.liste)) return t.liste
  return t.lista ? [t.lista] : []
}

// ------------------------------------------------------- sezioni per categoria
// Il primo livello della pagina e' la categoria, non il torneo: la stessa scelta di
// weekendPartiteGrouped in ProgrammazionePartite.vue, per la stessa ragione. Chi guarda vuole
// sapere cosa fa la SUA categoria. Un torneo iscritto a Pulcini ed Esordienti compare in entrambe
// le sezioni, ed e' corretto: sono due attivita' diverse che condividono nome e calendario.
const sezioniPerCategoria = computed(() => {
  const sezioni = []
  const piazzati = new Set()
  categorieOperative.value.forEach(cat => {
    const id = String(cat.id)
    const dentro = tornei.value.filter(t => categorieDel(t).some(c => String(c.id) === id))
    if (!dentro.length) return
    dentro.forEach(t => piazzati.add(t.id))
    // la sezione porta anche anno/nome, cosi' etichettaCategoria() funziona su di lei direttamente
    sezioni.push({
      chiave: 'cat-' + id, catId: id, id: cat.id, nome: cat.nome, anno: cat.anno,
      titolo: etichettaCategoria(cat), tornei: dentro
    })
  })
  // Le categorie non operative (archiviate, o un gruppo parent) e i tornei rimasti senza nessuna
  // iscrizione non avrebbero una sezione: senza questo giro sparirebbero dalla pagina, che e' il
  // modo peggiore di perdere un torneo
  const extra = {}
  tornei.value.filter(t => !piazzati.has(t.id)).forEach(t => {
    const cats = categorieDel(t)
    const chiavi = cats.length ? cats : [null]
    chiavi.forEach(c => {
      const k = c ? 'cat-' + c.id : 'cat-nessuna'
      if (!extra[k]) {
        extra[k] = c
          ? { chiave: k, catId: String(c.id), id: c.id, nome: c.nome, anno: c.anno,
              titolo: etichettaCategoria(c) + ' (non operativa)', tornei: [] }
          : { chiave: k, catId: '__nessuna__', id: null, nome: 'Senza categoria', anno: null,
              titolo: 'Senza categoria', tornei: [] }
      }
      extra[k].tornei.push(t)
    })
  })
  Object.keys(extra).forEach(k => sezioni.push(extra[k]))
  return sezioni
})

function chiaveCalendario(t, sez) {
  // Non basta t.id: lo stesso torneo sta in due sezioni, e aprire il calendario nei Pulcini non
  // deve aprirlo anche negli Esordienti
  return `${t.id}:${sez ? sez.catId : '*'}`
}

// Il conteggio arriva dal backend (gare_per_categoria), non dal calendario: quello si carica solo
// quando la sezione la apri, e chiederlo per ogni card significherebbe N richieste per dipingere
// dei numeri
function gareDiCategoria(t, catId) {
  const g = gareDi(t).filter(x => x.categoria_id && String(x.categoria_id) === String(catId))
  return g.length ? g : null
}

// Le gare senza categoria, o con una categoria non piu' iscritta al torneo: una sezione loro non
// ce l'hanno, quindi si mostrano in ogni sezione del torneo invece di sparire. Ripeterle e'
// fastidioso, nasconderle no
function gareOrfaneDi(t) {
  const iscritte = new Set(categorieDel(t).map(c => String(c.id)))
  return gareDi(t).filter(g => !g.categoria_id || !iscritte.has(String(g.categoria_id)))
}

function foglioDi(t, catId) {
  return listeDel(t).find(l => String(l.categoria_id) === String(catId)) || null
}

// Le altre categorie dello stesso torneo. Non e' decorazione: e' l'avvertenza che "Elimina" qui
// dentro si porta via anche loro, perche' il torneo e' uno solo
function altreCategorie(t, catId) {
  return categorieDel(t).filter(c => String(c.id) !== String(catId))
}

// Le categorie disponibili nel modal della gara: solo quelle iscritte al torneo, perche' una gara
// di una categoria non iscritta non avrebbe un foglio a cui appartenere
function categorieDelTorneoGara() {
  return categorieDel(tornei.value.find(x => x.id === garaTorneoId.value))
}

const categorieNonIscritte = computed(() => {
  const gia = new Set(categorieDel(torneoDaModificare.value).map(c => Number(c.id)))
  return categorieOperative.value.filter(c => !gia.has(Number(c.id)))
})

function formatoData(d) {
  if (!d) return ''
  const p = String(d).slice(0, 10).split('-')
  return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : d
}

function formatoPeriodo(t) {
  if (t.data_inizio && t.data_fine && t.data_inizio !== t.data_fine) {
    return `${formatoData(t.data_inizio)} – ${formatoData(t.data_fine)}`
  }
  if (t.data_inizio) return formatoData(t.data_inizio)
  if (t.data_fine) return 'fino al ' + formatoData(t.data_fine)
  return 'date da definire'
}

async function carica() {
  caricamento.value = true
  errore.value = ''
  try {
    const params = {}
    if (categoriaFiltro.value) params.categoria_id = categoriaFiltro.value
    if (daFiltro.value) params.da = daFiltro.value
    if (aFiltro.value) params.a = aFiltro.value
    const res = await getTornei(params)
    tornei.value = res.data || []
    // le gare cambiano solo perche' sono figlie del torneo: dopo una lista nuova si ricaricano
    gareCache.value = {}
    calendarioAperto.value = null
  } catch (e) {
    errore.value = e.response?.data?.detail || 'Errore nel caricamento dei tornei'
  } finally {
    caricamento.value = false
  }
}

async function caricaCategorie() {
  try {
    // getAllCategorie e non getCategorie: quest'ultima, per un mister, restituisce solo le
    // categorie assegnate in utente_categorie. I tornei invece si vedono di tutta la societa'
    // (decisone del titolare), quindi con /categorie/ il torneo di una categoria non assegnata
    // sarebbe arrivato senza etichetta e senza voce nel filtro
    const res = await getAllCategorie(societaAttiva.value?.id)
    categorie.value = res.data || []
  } catch (e) {
    // senza categorie non si puo' creare un torneo, ma l'elenco dei tornei si vede comunque
    categorie.value = []
  }
}

function gareDi(t) {
  return gareCache.value[t.id] || []
}

// Le gare di un torneo: dalla cache del calendario, o caricate adesso. Serve a chi le vuole
// contare PRIMA di un'azione (togliere una categoria) e non puo' permettere che la cache vuota
// venga letta come "non ci sono gare": sarebbe un via libera bugiardo. Rende null, non [], quando
// non e' riuscita a saperlo: "non lo so" e "non ce ne sono" sono due risposte diverse
async function gareDel(t) {
  if (gareCache.value[t.id]) return gareCache.value[t.id]
  try {
    const res = await getTorneo(t.id)
    const gare = res.data.gare || []
    gareCache.value = { ...gareCache.value, [t.id]: gare }
    return gare
  } catch (e) {
    return null
  }
}

async function apriCalendario(t, sez) {
  // La chiave e' torneo+sezione, non il solo torneo: la stessa card sta in due sezioni e aprire il
  // calendario nei Pulcini non deve aprirlo anche negli Esordienti
  const chiave = chiaveCalendario(t, sez)
  if (calendarioAperto.value === chiave) {
    calendarioAperto.value = null
    return
  }
  calendarioAperto.value = chiave
  if (!gareCache.value[t.id] && (await gareDel(t)) === null) {
    errore.value = 'Errore nel caricamento del calendario'
  }
}

// Il foglio giocatori non si crea qui: nasce col torneo (o con l'iscrizione della categoria) nel
// backend. Qui si apre quello gia' esistente, dove il mister sceglie i giocatori e preme
// "Esporta PDF" (gia' funzionante in ListeTornei.vue, che e' una pagina per categoria).
function apriLista(l) {
  router.push('/liste-tornei/' + l.categoria_id)
}

function apriModalTorneo(t = null) {
  erroreModal.value = ''
  nuovaCategoria.value = null
  torneoDaModificare.value = t
  formTorneo.value = t
    ? {
        nome: t.nome, data_inizio: t.data_inizio || '',
        data_fine: t.data_fine || '', luogo: t.luogo || '', organizzatore: t.organizzatore || '',
        descrizione: t.descrizione || ''
      }
    : {
        nome: '',
        // da Scelta.vue si arriva con la categoria gia' in testa: pre-selezione la sua, altrimenti
        // si parte vuoti e si lascia scegliere chi iscrive
        categorie_id: categoriaFiltro.value ? [Number(categoriaFiltro.value)] : [],
        data_inizio: '', data_fine: '', luogo: '', organizzatore: '', descrizione: ''
      }
  modalTorneo.value = true
}

async function salvaTorneo() {
  erroreModal.value = ''
  if (!formTorneo.value.nome?.trim()) { erroreModal.value = "Il nome del torneo e' obbligatorio"; return }
  const scelte = (formTorneo.value.categorie_id || []).map(Number)
  if (!torneoDaModificare.value && !scelte.length) {
    erroreModal.value = 'Seleziona almeno una categoria: senza categorie il torneo non ha squadre'
    return
  }
  salvataggio.value = true
  try {
    const corpo = {
      nome: formTorneo.value.nome.trim(),
      data_inizio: formTorneo.value.data_inizio || null,
      data_fine: formTorneo.value.data_fine || null,
      luogo: formTorneo.value.luogo || null,
      organizzatore: formTorneo.value.organizzatore || null,
      descrizione: formTorneo.value.descrizione || null
    }
    if (torneoDaModificare.value) {
      // niente categorie nel corpo: le gestiscono le rotte dedicate, con le loro regole
      await aggiornaTorneo(torneoDaModificare.value.id, corpo)
      conferma.value = 'Torneo aggiornato'
    } else {
      const n = scelte.length
      await creaTorneo({ ...corpo, categorie_id: scelte })
      conferma.value = n === 1
        ? 'Torneo creato: il foglio giocatori della categoria e gia'
          + ' pronto in Liste Tornei'
        : `Torneo creato con ${n} categorie: i ${n} fogli giocatori sono gia' pronti in Liste Tornei`
    }
    modalTorneo.value = false
    await carica()
  } catch (e) {
    erroreModal.value = e.response?.data?.detail || 'Errore nel salvataggio del torneo'
  } finally {
    salvataggio.value = false
  }
}

// Iscrivere una categoria a un torneo gia' creato porta con se' il suo foglio giocatori: lo fa il
// backend nello stesso transaction, qui si ricarica la pagina per mostrarlo
async function aggiungiCategoria() {
  if (!nuovaCategoria.value || !torneoDaModificare.value) return
  erroreModal.value = ''
  salvataggio.value = true
  try {
    await iscriviCategoriaTorneo(torneoDaModificare.value.id, Number(nuovaCategoria.value))
    conferma.value = 'Categoria iscritta: il suo foglio giocatori e gia'
      + ' pronto in Liste Tornei'
    nuovaCategoria.value = null
    await ricaricaTorneoInModifica()
  } catch (e) {
    erroreModal.value = e.response?.data?.detail || "Errore nell'iscrizione della categoria"
  } finally {
    salvataggio.value = false
  }
}

async function togliCategoria(c) {
  if (!torneoDaModificare.value) return
  const t = torneoDaModificare.value
  // Si chiedono le gare davvero invece di leggere la cache: se il calendario non era mai stato
  // aperto la cache e' vuota, e leggerla avrebbe detto "nessun rischio" senza saperlo
  const cache = await gareDel(t)
  const gare = cache === null ? null
    : cache.filter(g => Number(g.categoria_id) === Number(c.id)).length
  // Il backend rifiuta l'operazione se resterebbero gare orfane: dirlo qui, prima del click, costa
  // una domanda in meno a chi altrimenti si ritrova un errore senza capire da dove viene. E quando
  // non e' stato possibile saperlo, la domanda lo dice invece di far finta di niente
  const avvertenza = gare === null
    ? "\nNon ho potuto verificare il calendario: se questa categoria ha gare, il backend la rifiutera'."
    : gare
      ? `\nIl backend la rifiutera': questa categoria ha ${gare} ${gare === 1 ? 'gara' : 'gare'} nel calendario.`
      : "\nIl foglio giocatori di questa categoria restera' in Liste Tornei, non verra' cancellato."
  if (!confirm(`Rimuovere ${etichettaCategoria(c)} dal torneo "${t.nome}"?${avvertenza}`)) return
  salvataggio.value = true
  try {
    await rimuoviCategoriaTorneo(t.id, Number(c.id))
    conferma.value = 'Iscrizione rimossa'
    await ricaricaTorneoInModifica()
  } catch (e) {
    erroreModal.value = e.response?.data?.detail || "Errore nella rimozione dell'iscrizione"
  } finally {
    salvataggio.value = false
  }
}

// Dopo un'iscrizione o una rimozione il modal mostra le categorie del torneo: se si ricaricasse
// solo l'elenco, il chip appena aggiunto (o tolto) comparirebbe solo chiudendo e riaprendo il modal
async function ricaricaTorneoInModifica() {
  const id = torneoDaModificare.value?.id
  await carica()
  const aggiornato = tornei.value.find(x => x.id === id)
  // se il torneo non c'e' piu' (eliminato altrove) il modal si chiude da solo invece di restare
  // aggrappato a un oggetto che non esiste piu'
  if (!aggiornato) { modalTorneo.value = false; return }
  torneoDaModificare.value = aggiornato
}

async function elimina(t, sez = null) {
  // Non piu' "la" lista: i fogli sono uno per categoria, e l'avvertenza deve dire quanti giocatori
  // si perdono in totale, perche' il backend li elimina insieme al torneo
  const giocatori = listeDel(t).reduce((s, l) => s + (l.giocatori || 0), 0)
  const fogli = listeDel(t).length
  const avvertenza = giocatori
    ? `\nAttenzione: ${fogli} ${fogli === 1 ? 'foglio' : 'fogli'} con ${giocatori} `
      + `${giocatori === 1 ? 'giocatore' : 'giocatori'} verranno eliminati insieme al torneo.`
    : ''
  // Qui sta il rischio vero della pagina suddivisa per categorie: la card e' "Winter Cup dei
  // Pulcini", ma il torneo e' uno solo e "Elimina" si porta via anche le altre categorie iscritte.
  // Se la sezione le nasconde, chi cancella non lo sa: vanno nominate, tutte
  const altre = altreCategorie(t, sez ? sez.catId : null)
  const anche = altre.length
    ? `\nIl torneo e' uno solo: vengono eliminati anche ${altre.map(a => etichettaCategoria(a)).join(', ')}.`
    : ''
  if (!confirm(`Eliminare il torneo "${t.nome}"${sez ? ' — ' + sez.titolo : ''}?${avvertenza}${anche}`)) return
  try {
    await eliminaTorneo(t.id)
    conferma.value = 'Torneo eliminato'
    await carica()
  } catch (e) {
    errore.value = e.response?.data?.detail || "Errore nell'eliminazione del torneo"
  }
}

function apriModalGara(t, g = null, sez = null) {
  erroreModal.value = ''
  garaTorneoId.value = t.id
  garaDaModificare.value = g
  garaSezione.value = sez || null
  // Con una sola categoria iscritta la si pre-seleziona: il backend la dedurrebbe comunque, ma
  // vederla scritta nel modal evita la sorpresa di una gara finita in un foglio non previsto.
  // Con piu' d'una si parte vuoti: scegliere noi sarebbe mettere la gara nel foglio sbagliato.
  const iscritte = categorieDel(t)
  const unaSola = iscritte.length === 1 ? Number(iscritte[0].id) : null
  // La sezione in cui si sta lavorando vince sul "una sola": aggiungere una gara dentro i Pulcini
  // vuol dire metterla nei Pulcini, anche se il torneo ne iscrive altre due. Non vale per la
  // sezione "Senza categoria", che di una categoria non ha niente
  const diSezione = sez && sez.catId && sez.catId !== '__nessuna__' ? Number(sez.catId) : null
  formGara.value = g
    ? {
        categoria_id: g.categoria_id ? Number(g.categoria_id) : (diSezione || unaSola),
        numero: g.numero, avversario: g.avversario || '', data: g.data || '', ora: g.ora || '',
        ora_appuntamento: g.ora_appuntamento || '', campo: g.campo || '',
        indirizzo: g.indirizzo || '', note: g.note || ''
      }
    : {
        categoria_id: diSezione || unaSola,
        numero: null, avversario: '', data: t.data_inizio || '', ora: '',
        ora_appuntamento: '', campo: '', indirizzo: '', note: ''
      }
  modalGara.value = true
}

async function salvaGara() {
  erroreModal.value = ''
  // Il controllo sta anche qui, e non solo nel backend, per non far premere "Salva" per niente:
  // con piu' categorie iscritte la gara senza categoria verrebbe rifiutata comunque
  const disponibili = categorieDelTorneoGara()
  if (disponibili.length > 1 && !formGara.value.categoria_id) {
    erroreModal.value = "Indica a quale categoria appartiene la gara: il torneo ne ha " + disponibili.length
    return
  }
  salvataggio.value = true
  const tid = garaTorneoId.value
  try {
    const corpo = {
      categoria_id: formGara.value.categoria_id ? Number(formGara.value.categoria_id) : null,
      numero: formGara.value.numero ? Number(formGara.value.numero) : null,
      avversario: formGara.value.avversario || null,
      data: formGara.value.data || null,
      ora: formGara.value.ora || null,
      ora_appuntamento: formGara.value.ora_appuntamento || null,
      campo: formGara.value.campo || null,
      indirizzo: formGara.value.indirizzo || null,
      note: formGara.value.note || null
    }
    if (garaDaModificare.value) {
      await modificaGaraTorneo(tid, garaDaModificare.value.id, corpo)
    } else {
      await aggiungiGaraTorneo(tid, corpo)
    }
    modalGara.value = false
    await ricaricaConCalendarioAperto(tid, garaSezione.value)
  } catch (e) {
    erroreModal.value = e.response?.data?.detail || 'Errore nel salvataggio della gara'
  } finally {
    salvataggio.value = false
  }
}

async function eliminaGara(t, g, sez = null) {
  if (!confirm(`Eliminare la gara ${g.avversario || g.numero || ''}?`)) return
  try {
    await eliminaGaraTorneo(t.id, g.id)
    await ricaricaConCalendarioAperto(t.id, sez)
  } catch (e) {
    errore.value = e.response?.data?.detail || "Errore nell'eliminazione della gara"
  }
}

// carica() richiude il calendario e svuota la cache delle gare: dopo una modifica alla gara si
// vuole rivedere il calendario aperto con il dato nuovo, non la lista chiusa
async function ricaricaConCalendarioAperto(torneoId, sez = null) {
  await carica()
  // carica() ha chiuso il calendario e svuotato la cache: si riapre la STESSA sezione da cui si
  // stava lavorando. Con la pagina suddivisa per categorie la chiave e' torneo+sezione, quindi
  // riaprire "il torneo" senza sezione non corrisponde a nessuna card aperta: dopo il salvataggio
  // il calendario che avevi davanti spariva dalla pagina
  const t = tornei.value.find(x => x.id === torneoId)
  if (t && sez) await apriCalendario(t, sez)
}

onMounted(async () => {
  await caricaCategorie()
  await carica()
})
</script>

<style scoped>
.tornei-page { padding: 1rem; max-width: 900px; margin: 0 auto; }

.page-header { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.75rem; flex-wrap: wrap; }
.page-header h2 { margin: 0; flex: 1; font-size: 1.25rem; }

.btn-back {
  display: flex; align-items: center; gap: 0.375rem; padding: 0.375rem 0.625rem;
  background: transparent; border: none; color: #a3a3a3; font-size: 0.8125rem; cursor: pointer;
}
.btn-back:hover { color: white; }

.nota { color: #a3a3a3; font-size: 0.8125rem; margin: 0 0 1rem; }

.filtri { display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap; margin-bottom: 1rem; }
.select-filtro, .filtro-data input {
  padding: 0.4rem 0.5rem; border-radius: var(--radius-md, 8px); border: 1px solid rgba(255,255,255,0.15);
  background: rgba(255,255,255,0.05); color: white; font-size: 0.8125rem;
}
.filtro-data { display: flex; align-items: center; gap: 0.375rem; color: #a3a3a3; font-size: 0.75rem; }

.stato { padding: 2rem; text-align: center; color: #737373; font-size: 0.875rem; }
.stato.piccolo { padding: 0.75rem; font-size: 0.8125rem; }
.messaggio { padding: 0.5rem 0.75rem; border-radius: var(--radius-md, 8px); font-size: 0.8125rem; margin-bottom: 0.75rem; }
.messaggio.errore { background: rgba(239,68,68,0.12); color: #ef4444; }
.messaggio.successo { background: rgba(34,197,94,0.12); color: #22c55e; }

.torneo-card {
  background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08);
  border-radius: var(--radius-lg, 12px); padding: 1rem; margin-bottom: 0.875rem;
}
.torneo-testata { cursor: pointer; }
.torneo-titolo { display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.375rem; }
.torneo-nome { font-size: 1.0625rem; font-weight: 700; }
.badge {
  padding: 0.125rem 0.4375rem; border-radius: 999px; font-size: 0.6875rem; font-weight: 600;
  background: rgba(255,255,255,0.08); color: #a3a3a3;
}
.badge.categoria { background: rgba(59,130,246,0.14); color: #60a5fa; }
.badge.gare { background: rgba(168,85,247,0.14); color: #c084fc; }
.badge.lista { background: rgba(34,197,94,0.14); color: #4ade80; }
.badge.lista.vuota { background: rgba(234,179,8,0.14); color: #facc15; }

.torneo-meta { display: flex; gap: 0.875rem; flex-wrap: wrap; color: #a3a3a3; font-size: 0.8125rem; }
.torneo-descrizione { color: #a3a3a3; font-size: 0.8125rem; margin: 0.5rem 0 0; white-space: pre-line; }

.torneo-azioni { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 0.75rem; }
.btn-azione {
  padding: 0.375rem 0.75rem; border-radius: var(--radius-md, 8px); font-size: 0.75rem; font-weight: 600;
  background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12); color: #d4d4d4; cursor: pointer;
}
.btn-azione:hover:not(:disabled) { background: rgba(255,255,255,0.12); }
.btn-azione.primario { background: rgba(220,38,38,0.16); border-color: rgba(220,38,38,0.35); color: #fca5a5; }
.btn-azione.primario:hover { background: #dc2626; color: white; }
.btn-azione.pericolo { color: #f87171; }
.btn-azione:disabled { opacity: 0.45; cursor: not-allowed; }

.calendario { margin-top: 0.875rem; border-top: 1px solid rgba(255,255,255,0.08); padding-top: 0.5rem; }
.gara-riga {
  display: flex; gap: 0.625rem; padding: 0.5rem 0; align-items: flex-start;
  border-bottom: 1px solid rgba(255,255,255,0.05);
}
.gara-numero {
  flex: 0 0 1.5rem; height: 1.5rem; border-radius: 999px; display: flex; align-items: center;
  justify-content: center; font-size: 0.6875rem; font-weight: 700;
  background: rgba(255,255,255,0.08); color: #a3a3a3;
}
.gara-corpo { flex: 1; min-width: 0; }
.gara-verso { font-size: 0.9375rem; }
.gara-dettaglio { display: flex; gap: 0.75rem; flex-wrap: wrap; color: #a3a3a3; font-size: 0.75rem; margin-top: 0.1875rem; }
.gara-note { color: #d4d4d4; font-size: 0.75rem; margin-top: 0.25rem; white-space: pre-line; }
.gara-azioni { display: flex; gap: 0.25rem; }
.btn-icon {
  padding: 0.3125rem; border-radius: var(--radius-md, 8px); background: transparent; border: none;
  color: #737373; cursor: pointer;
}
.btn-icon:hover { background: rgba(255,255,255,0.08); color: white; }
.btn-icon.pericolo:hover { color: #f87171; }
.btn-aggiungi {
  margin-top: 0.625rem; padding: 0.375rem 0.75rem; border-radius: var(--radius-md, 8px);
  background: transparent; border: 1px dashed rgba(255,255,255,0.2); color: #a3a3a3;
  font-size: 0.75rem; cursor: pointer;
}
.btn-aggiungi:hover { color: white; border-color: rgba(255,255,255,0.4); }

/* Modal: gli stili sono scoped e non esiste un CSS globale condiviso, quindi ogni pagina
   definisce i suoi (come ListeTornei.vue). Gli stessi nomi di classe, le stesse variabili. */
.modal-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,0.6);
  display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.modal {
  background: var(--color-surface, #171717); border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 16px; width: 92%; max-width: 460px; max-height: 90vh;
  display: flex; flex-direction: column;
}
.modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.25rem 1.5rem 0.75rem;
}
.modal-header h3 { font-size: 1.125rem; font-weight: 700; color: var(--color-text, #f3f4f6); margin: 0; }
.modal-close {
  background: transparent; border: none; color: #737373; cursor: pointer; padding: 0.25rem;
  display: flex; align-items: center;
}
.modal-close:hover { color: white; }
.modal-close svg { width: 20px; height: 20px; }
.modal-body { padding: 0 1.5rem; overflow-y: auto; }
.modal-footer {
  display: flex; justify-content: flex-end; gap: 0.5rem; padding: 1rem 1.5rem 1.25rem;
}
.suggerimento {
  font-size: 0.75rem; color: #a3a3a3; background: rgba(59,130,246,0.1);
  border-left: 2px solid rgba(59,130,246,0.5); padding: 0.5rem 0.625rem;
  border-radius: 6px; margin: 0 0 1rem;
}

.form-group { margin-bottom: 0.875rem; flex: 1; }
.form-group label {
  display: block; font-size: 0.75rem; font-weight: 600;
  color: var(--color-text-muted, #6b7280); margin-bottom: 0.3125rem;
}
.form-group input, .form-group select, .form-group textarea {
  width: 100%; padding: 0.5625rem 0.75rem; border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px; background: var(--color-surface, #171717); color: var(--color-text, #f3f4f6);
  font-size: 0.875rem; box-sizing: border-box; font-family: inherit;
}
.form-group input:focus, .form-group select:focus, .form-group textarea:focus {
  outline: none; border-color: rgba(220,38,38,0.5);
}
.form-group select option { background: #171717; color: #f3f4f6; }
.form-group textarea { resize: vertical; }
.form-riga { display: flex; gap: 0.75rem; }

.btn-primary {
  display: flex; align-items: center; gap: 0.375rem; padding: 0.5rem 1rem; border: none;
  border-radius: 10px; background: #dc2626; color: white; font-size: 0.8125rem;
  font-weight: 600; cursor: pointer;
}
.btn-primary:hover:not(:disabled) { background: #b91c1c; }
.btn-primary:disabled { opacity: 0.6; cursor: wait; }
.btn-secondary {
  padding: 0.5rem 1rem; border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px; background: transparent; color: #a3a3a3; font-size: 0.8125rem; cursor: pointer;
}
.btn-secondary:hover { color: white; border-color: rgba(255,255,255,0.3); }

/* ------------------------------------------------------------------ sezioni per categoria
   Il primo livello della pagina, stesso aspetto delle sezioni di ProgrammazionePartite.vue: titolo
   grande e bordo basso del colore primario. Chi apre la pagina deve vedere prima "2016 - Pulcini"
   e solo dopo i tornei, perche' la domanda reale e' "cosa fa la mia categoria" */
.categoria-sezione { margin: 0 0 1.75rem; }
.categoria-sezione:last-of-type { margin-bottom: 0; }
.categoria-intestazione {
  display: flex; align-items: center; gap: 0.625rem; flex-wrap: wrap;
  font-size: 1.25rem; font-weight: 700; color: var(--color-text, #f3f4f6);
  margin: 0 0 0.875rem; padding-bottom: 0.625rem; letter-spacing: -0.01em;
  border-bottom: 2px solid #dc2626;
}
.conteggio-sezione {
  font-size: 0.6875rem; font-weight: 600; padding: 0.125rem 0.4375rem; border-radius: 999px;
  background: rgba(255,255,255,0.08); color: #a3a3a3;
}

/* Le altre categorie dello stesso torneo: colore diverso dal badge della sezione, perche' qui il
   messaggio non e' "questa e' la tua categoria" ma "attenzione, il torneo e' condiviso con loro"
   e "Elimina" le porta via */
.badge.categoria.altrui { background: rgba(168,85,247,0.14); color: #c084fc; }

/* Le gare senza categoria, o con una categoria non piu' iscritta: non hanno una sezione, quindi
   vengono elencate in fondo a quelle del torneo con un'intestazione che le nomina. Un calendario
   che ne mostra sei su otto e' peggio di uno che ammette di averne due senza etichetta */
.orfane-intestazione {
  font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em;
  color: #facc15; margin: 0.75rem 0 0.25rem;
}
.gara-riga.orfana { border-left: 2px solid rgba(234,179,8,0.45); padding-left: 0.5rem; }

/* ------------------------------------------------------------------ scelta delle categorie
   Il checkbox eredita width:100% e il padding da .form-group input: vanno annullati qui, o le
   caselle si allargano una riga ciascuna e la scelta multipla diventa un elenco infinito */
.scelta-categorie {
  display: flex; flex-wrap: wrap; gap: 0.375rem; max-height: 11rem; overflow-y: auto;
  padding: 0.5rem; border: 1px solid var(--color-border, rgba(255,255,255,0.1));
  border-radius: 10px; background: rgba(255,255,255,0.02);
}
.scelta-categoria {
  display: flex; align-items: center; gap: 0.3125rem; padding: 0.25rem 0.5rem;
  border-radius: 999px; background: rgba(255,255,255,0.06); cursor: pointer;
  font-size: 0.75rem; font-weight: 500; color: #d4d4d4; margin: 0;
}
.scelta-categoria input[type="checkbox"] {
  width: auto; padding: 0; margin: 0; accent-color: #3b82f6; cursor: pointer;
}
.conteggio { font-weight: 500; color: #60a5fa; margin-left: 0.25rem; }
.chip-categoria {
  display: inline-flex; align-items: center; gap: 0.3125rem; padding: 0.25rem 0.5rem;
  border-radius: 999px; font-size: 0.75rem; font-weight: 600;
  background: rgba(59,130,246,0.14); color: #60a5fa;
}
.chip-x {
  border: none; background: transparent; color: inherit; cursor: pointer;
  font-size: 0.75rem; line-height: 1; padding: 0 0.1875rem; border-radius: 999px;
}
.chip-x:hover { background: rgba(239,68,68,0.25); color: #fca5a5; }
.aggiungi-categoria { display: flex; gap: 0.5rem; margin-top: 0.5rem; align-items: flex-end; }
.aggiungi-categoria select { flex: 1; }
.aggiungi-categoria .btn-secondary { white-space: nowrap; }

@media (max-width: 560px) {
  .form-riga { flex-direction: column; gap: 0; }
  .modal { max-width: 100%; }
  .aggiungi-categoria { flex-direction: column; align-items: stretch; }
}
</style>