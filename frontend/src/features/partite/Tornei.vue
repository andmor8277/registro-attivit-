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
      <!-- Quattro livelli di export, una sola funzione: tutti i tornei della societa' (quaggiu'),
           la selezione a schermo (quaggiu', ma solo quando un filtro e' attivo), questa categoria
           (nell'intestazione della sezione) e questo torneo (sulla card). Il primo IGNORA i filtri e
           si ricarica la lista: un documento che si chiama "i tornei della societa'" e ha dentro solo
           i Pulcini perche' qualcuno aveva il filtro su e' plausibile e falso -->
      <button class="btn-esporta" :disabled="esportazione" @click="esportaTutti()"
              title="Esporta il PDF di TUTTI i tornei della società: solo i calendari, senza farsi condizionare dai filtri. I giocatori si stampano da Liste Tornei">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
          <polyline points="14 2 14 8 20 8"/>
          <line x1="12" y1="18" x2="12" y2="12"/><polyline points="9 15 12 18 15 15"/>
        </svg>
        <span>{{ esportazione ? 'Genero…' : 'Esporta tutti i tornei' }}</span>
      </button>
      <!-- Compare solo con un filtro attivo: senza filtri "selezione" e "tutti" sono lo stesso
           documento, e due bottoni che fanno la stessa cosa sono due risposte diverse alla stessa
           domanda. Quando c'e', il PDF che produce lo scrive da solo di essere un sottoinsieme -->
      <button v-if="filtriAttivi.length" class="btn-esporta secondario"
              :disabled="!tornei.length || esportazione" @click="esportaSelezione()"
              :title="'Esporta solo quello che vedi (' + filtriAttivi.join(', ') + '). Il documento lo dichiara, per non scambiarlo per quello completo'">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
          <polyline points="14 2 14 8 20 8"/>
          <line x1="12" y1="18" x2="12" y2="12"/><polyline points="9 15 12 18 15 15"/>
        </svg>
        <span>Esporta la selezione</span>
      </button>
      <button v-if="!solaLettura" class="btn-primary" @click="apriModalTorneo()">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        <span>Nuovo torneo</span>
      </button>
    </div>

    <!-- Due note, perche' sono due risposte diverse. "Puoi aggiungere gare e convocare" detto a un
         dirigente sarebbe una promessa falsa: lui quelle cose non le vede nemmeno. Il testo segue cio'
         che il ruolo puo' davvero fare, non chi ha aperto la pagina -->
    <p v-if="solaLettura && puoGestireGare" class="nota">
      I tornei della tua società. Apri il calendario per registrare le gare che ti comunica
      l'organizzatore e per convocare i giocatori, una gara alla volta. Il "Foglio giocatori" resta il
      file da consegnare all'organizzatore e si stampa da Liste Tornei.
    </p>
    <p v-else-if="solaLettura" class="nota">
      I tornei della tua società, in sola lettura. Apri la lista per vedere i giocatori e il file da
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
        <button class="btn-esporta" :disabled="esportazione" @click="esportaPDF(sez)"
                :title="'Esporta il PDF di ' + sez.titolo + ': solo i calendari dei tornei di questa categoria. I giocatori si stampano da Liste Tornei'">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
            <polyline points="14 2 14 8 20 8"/>
            <line x1="12" y1="18" x2="12" y2="12"/><polyline points="9 15 12 18 15 15"/>
          </svg>
          <span>Esporta PDF</span>
        </button>
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
            <!-- Il referente del torneo, mostrato sempre: se manca, l'organizzatore non ha chi
                 chiamare la mattina, e scriverlo qui e' il modo per non scoprirlo il venerdi' sera.
                 Il nome arriva gia' risolto dal backend, cosi' card e PDF dicono la stessa cosa -->
            <span class="mister-torneo" :class="{ assente: !t.mister_nome }"
                  :title="t.mister_nome ? 'Referente del torneo' : 'Nessun referente: chi chiama per questo torneo?'">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13">
                <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/>
              </svg>
              <span>{{ t.mister_nome || 'mister da assegnare' }}</span>
              <span v-if="t.mister_cellulare" class="mister-tel">{{ t.mister_cellulare }}</span>
            </span>
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
            <button class="btn-azione" @click="apriModalTorneo(t, sez)">Modifica</button>
            <button class="btn-azione pericolo" @click="elimina(t, sez)">Elimina</button>
          </template>
          <!-- Terzo livello di export: questo torneo, in questa categoria. Serve perche' il
               responsabile che deve mandare "il suo" all'organizzatore non gli interessa il resto
               della giornata: un PDF con dentro anche l'altra categoria e' un documento che va
               tagliato a mano prima di essere inviato -->
          <button class="btn-esporta" :disabled="esportazione" @click="esportaPDF(sez, t)"
                  :title="'Esporta il PDF di ' + t.nome + ' per ' + etichettaCategoria(sez) + ': solo il calendario. I giocatori si stampano da Liste Tornei'">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
              <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
              <polyline points="14 2 14 8 20 8"/>
              <line x1="12" y1="18" x2="12" y2="12"/><polyline points="9 15 12 18 15 15"/>
            </svg>
            <span>Esporta PDF</span>
          </button>
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
            <div v-if="puoGestireGare" class="gara-azioni">
              <!-- La convocazione si può fare anche da sola lettura? No: e' una scrittura, e il gate e'
                   lo stesso del backend. Ma non e' legata a solaLettura, che governa il torneo: un mister
                   convoca la SUA gara senza poter cancellare il torneo -->
              <button
                v-if="categoriaDellaGara(t, g)"
                class="btn-icon"
                @click="apriConvocazione(t, g, sez)"
                title="Convoca i giocatori per questa gara">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                  <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                  <circle cx="9" cy="7" r="4"/>
                  <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
                </svg>
              </button>
              <button v-else class="btn-icon" disabled
                      :title="'Questa gara non ha una categoria e il torneo ne ha ' + categorieDel(t).length + ': assegnala dal calendario prima di convocare'">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                  <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                  <circle cx="9" cy="7" r="4"/>
                  <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
                </svg>
              </button>
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
              <div v-if="puoGestireGare" class="gara-azioni">
                <!-- Anche qui il pulsante c'e', spento: una gara "senza categoria" che non mostra
                     nessun invito alla convocazione sembra un difetto dei dati, e il mister va a
                     cercare altrove. Spento con il motivo e' una risposta, assente ne' e' una -->
                <button
                  v-if="categoriaDellaGara(t, g)"
                  class="btn-icon"
                  @click="apriConvocazione(t, g, sez)"
                  title="Convoca i giocatori per questa gara">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                    <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                    <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
                  </svg>
                </button>
                <button v-else class="btn-icon" disabled
                        :title="'Questa gara non ha una categoria e il torneo ne ha ' + categorieDel(t).length + ': assegnala dal calendario prima di convocare'">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                    <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                    <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
                  </svg>
                </button>
                <button class="btn-icon" @click="apriModalGara(t, g)" title="Modifica gara">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                    <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                    <path d="M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4z"/>
                  </svg>
                </button>
                <!-- Il cestino qui non e' ridondante: una gara senza categoria non compare nella
                     lista di nessuna sezione, quindi senza questo bottino non si potrebbe
                     eliminare da nessuna parte -->
                <button class="btn-icon pericolo" @click="eliminaGara(t, g, sez)" title="Elimina gara">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15">
                    <polyline points="3 6 5 6 21 6"/>
                    <path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                  </svg>
                </button>
              </div>
            </div>
          </template>
          <button v-if="puoGestireGare" class="btn-aggiungi" @click="apriModalGara(t, null, sez)">
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
            <!-- Il titolo nomina la sezione da cui stai lavorando: e' lei a decidere chi compare nel
                 menu del Mister, e un menu piu' corto del previsto senza una ragione scritta in alto
                 sembra un bug della lista -->
            <h3>{{ (torneoDaModificare ? 'Modifica torneo' : 'Nuovo torneo') + (etichettaCategoriaLavoro ? ' — ' + etichettaCategoriaLavoro : '') }}</h3>
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
            <!-- Il referente del torneo, UNA persona per il torneo intero e non una per categoria:
                 l'organizzatore chiama un numero solo la mattina, e con le gare su due categorie il
                 mister della singola gara non dice chi risponde del torneo. Stessa UX del weekend:
                 menu a tendina + "manuale" per chi non ha un account -->
            <div class="form-group">
              <label>Mister del torneo</label>
              <select v-model="misterScelta" @change="cambioMister">
                <option value="">— da assegnare —</option>
                <option v-for="m in misterDisponibili" :key="m.id" :value="String(m.id)">
                  {{ m.cognome }}{{ m.nome ? ' ' + m.nome : '' }}{{ m.cellulare ? ' (' + m.cellulare + ')' : '' }}
                </option>
                <!-- Il referente salvato puo' non essere piu' tra i responsabili delle categorie:
                     senza questa voce il menu sarebbe vuoto su un torneo che il mister ce l'ha -->
                <option v-if="misterFuoriLista" :value="String(misterFuoriLista.id)">
                  {{ misterFuoriLista.nome }} ({{ misterFuoriLista.motivo }})
                </option>
                <option value="__manuale__">✏️ Inserisci manualmente (non censito)…</option>
              </select>
              <div v-if="misterScelta === '__manuale__'" class="mister-manuale">
                <input v-model="formTorneo.mister_manuale" maxlength="100"
                       placeholder="Nome e cognome (es. Mario Rossi)" />
              </div>
              <p class="suggerimento">{{ suggerimentoMister }}</p>
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
    <!-- Modal convocazione di UNA gara di torneo. Stesso pattern dei due modal esistenti (Teleport,
         overlay che chiude al click fuori, ✕, Annulla, errore in coda al body) per non introdurre una
         terza forma di dialog nella stessa pagina.
         Le righe sopra alla griglia NON sono campi da compilare: sono la gara del calendario letta e
         basta. Renderle modificabili qui avrebbe creato un secondo posto dove correggere l'orario della
         domenica, con il calendario che dice una cosa e il foglio un'altra -->
    <Teleport to="body">
      <div v-if="modalConv" class="modal-overlay" @click.self="modalConv = false">
        <div class="modal modal-conv">
          <div class="modal-header">
            <div>
              <h3>Convocazione — {{ convGara?.avversario || 'Gara' }}</h3>
              <p class="conv-sottotitolo">
                {{ convTorneo?.nome }} · {{ convEtichettaCategoria }}
              </p>
            </div>
            <button class="modal-close" @click="modalConv = false" title="Chiudi">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>

          <div class="modal-body">
            <div v-if="convCaricamento" class="stato piccolo">Carico i giocatori…</div>

            <template v-else>
              <p class="conv-logistica">
                <span v-if="convGara?.data">{{ formatoData(convGara.data) }}</span>
                <span v-if="convGara?.ora">inizio {{ convGara.ora }}</span>
                <span v-if="convGara?.ora_appuntamento">appuntamento {{ convGara.ora_appuntamento }}</span>
                <span v-if="convGara?.campo">{{ convGara.campo }}<template v-if="convGara?.indirizzo"> — {{ convGara.indirizzo }}</template></span>
              </p>

              <div class="conv-colonna">
                <h4 class="conv-titolo">Convocati ({{ convConvocati.length }})</h4>
                <p v-if="!convConvocati.length" class="suggerimento">
                  Nessuno convocato ancora. Aggiungi i giocatori dalla lista qui sotto.
                </p>
                <div v-for="(c, i) in convConvocatiDettaglio" :key="c.persona.id" class="conv-riga"
                     :class="{ assente: convAssenti.includes(c.persona.id) }">
                  <span class="conv-pos">{{ c.posizione }}</span>
                  <span class="conv-nome">{{ c.persona.cognome }} {{ c.persona.nome }}</span>
                  <span class="conv-ordinamento">
                    <button class="btn-mini" @click="spostaConvocato(i, -1)" :disabled="i === 0" title="Sposta su">▲</button>
                    <button class="btn-mini" @click="spostaConvocato(i, 1)" :disabled="i === convConvocatiDettaglio.length - 1" title="Sposta giù">▼</button>
                  </span>
                  <button class="btn-mini leva" :class="{ on: convAssenti.includes(c.persona.id) }"
                          @click="scambiaAssente(c.persona.id)"
                          title="Segna presente o assente in gara">
                    {{ convAssenti.includes(c.persona.id) ? 'assente' : 'presente' }}
                  </button>
                  <button class="btn-mini pericolo" @click="togliConvocato(c.persona.id)" title="Togli dalla convocazione">✕</button>
                </div>
              </div>

              <div class="conv-colonna">
                <h4 class="conv-titolo">Da convocare ({{ convNonConvocati.length }})</h4>
                <input v-model="convRicerca" class="conv-ricerca" placeholder="Cerca per cognome o nome…" />
                <div v-for="p in convNonConvocati" :key="p.id" class="conv-riga">
                  <span class="conv-nome">{{ p.cognome }} {{ p.nome }}</span>
                  <button class="btn-mini primario" @click="convoca(p.id)">+ Convoca</button>
                </div>
              </div>

              <div class="form-group">
                <label>Note del foglio</label>
                <textarea v-model="convNota" rows="2" placeholder="Es. ritrovo al campo, portare la maglia rossa…"></textarea>
              </div>

              <p v-if="erroreConv" class="messaggio errore">{{ erroreConv }}</p>
            </template>
          </div>

          <div class="modal-footer">
            <button class="btn-secondary" @click="modalConv = false">Annulla</button>
            <!-- Il foglio esce da QUI, accanto a chi lo ha appena guardato: un pulsante sul calendario
                 avrebbe esportato un foglio che nessuno aveva aperto. Per questo e' un .btn-esporta e non
                 un .btn-secondary: quella classe ha la regola :disabled, l'altra no, e un pulsante spento
                 che sembra acceso e' il difetto gia' visto sulla riga "Senza categoria" -->
            <button class="btn-esporta" @click="esportaConvocazionePDF"
                    :disabled="convExport || convCaricamento || convSalvataggio || !convConvocati.length"
                    :title="!convConvocati.length
                            ? 'Nessun giocatore convocato: il foglio uscirebbe vuoto'
                            : 'Scarica il foglio di convocazione in PDF: lo stesso documento della pagina Convocazioni'">
              {{ convExport ? 'Genero…' : 'Esporta PDF' }}
            </button>
            <button class="btn-primary" @click="salvaConvocazione"
                    :disabled="convSalvataggio || convCaricamento">
              {{ convSalvataggio ? 'Salvataggio…' : 'Salva convocazione' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getTornei, getTorneo, creaTorneo, aggiornaTorneo, eliminaTorneo,
  aggiungiGaraTorneo, modificaGaraTorneo, eliminaGaraTorneo, getAllCategorie, isParentCategory,
  iscriviCategoriaTorneo, rimuoviCategoriaTorneo, saveOrSharePdf,
  getCategoriaResponsabili,
  // La convocazione di UNA gara di torneo: stesso aggregato della pagina Convocazioni, ma il campo
  // `tornei_gara_id` nel backend cambia completamente percorso e non tocca ne' weekend ne' partite
  getPersone, getConvocazione, getConvocazioneDiGaraTorneo, creaConvocazioneTorneo, salvaConvocazioneTorneo
} from '../../api/index.js'
import { jsPDF } from 'jspdf'
// Il plugin va importato ANCHE qui, non basta che lo importino Liste Tornei o Programmazione Partite:
// le pagine sono chunk caricati al bisogno, e senza questa riga doc.autoTable e' undefined. E' un
// errore che non si vede in nessun posto, perche' la chiamata cade dentro il try/catch dell'export
import 'jspdf-autotable'
// Intestazione e stile di tabella condivisi con Programmazione Partite: la forma di riferimento
// e' la sua, perche' e' il PDF che la societa' gia' conosce e riceve il venerdi'
import { intestazionePdf, BASE_TABELLA, barra, didParseCellBarra, coloraDomenica, cellData, AMBRA_THOF } from '../../core/utils/pdfTHOF.js'
// IL FOGLIO DI CONVOCAZIONE, la stessa funzione che usa la pagina Convocazioni il venerdi'. Non se ne
// scrive una seconda copia qui: due fogli di stile sono due documenti che il giorno dopo non si
// assomigliano piu', e in chat sembrano di due associazioni diverse
import { esportaFoglioConvocazione } from '../../core/utils/pdfConvocazione.js'
import { useStore } from '../../store.js'

const route = useRoute()
const router = useRouter()
// stagioneCorrente serve solo al pie' del foglio ("Stagione 2026/2027"), che e' lo stesso del weekend
const { utenteAttivo, societaAttiva, stagioneCorrente } = useStore()

// Una sola pagina per due ingressi: chi arriva da /responsabili/tornei (admin) modifica, chi
// arriva da Scelta.vue come "Convocazioni Tornei" legge e basta. Il livello di modifica lo decide
// il ruolo e non la rotta, cosi' un admin che entra dal link dei mister non resta senza pulsanti
// e un mister non vede controlli che il backend gli rifiuterebbe comunque.
const solaLettura = computed(() => !(utenteAttivo.value?.is_admin || utenteAttivo.value?.is_super_admin))

// Chi scrive sul CALENDARIO GARE e sulle CONVOCZIONI di un torneo: i mister, oltre agli admin.
//
// E' un gate DIVERSO da solaLettura e non lo sostituisce, e la differenza e' il punto. Allentare
// solaLettura al mister ridarebbe anche "Modifica"/"Elimina" sul torneo e l'iscrizione delle categorie:
// decisioni che restano del responsabile, perche' cancellare il torneo di una societa' o togliere una
// categoria iscritta non e' lavoro che si fa "per provare". Qui si apre solo il calendario gare e il
// foglio dei convocati.
//
// Il backend applica lo stesso criterio (get_gestore_gare_torneo e _esigi_gestore_convocazioni): questa
// e' visibilita', non permesso, e senza il backend sarebbe solo un pulsante nascosto.
const puoGestireGare = computed(() =>
  !!(utenteAttivo.value?.is_admin || utenteAttivo.value?.is_super_admin || utenteAttivo.value?.ruolo === 'mister'))

const tornei = ref([])
const categorie = ref([])
const gareCache = ref({})
const caricamento = ref(true)
const esportazione = ref(false)
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

// ------------------------------------------------------- convocazione di una gara di torneo
// Un foglio per OGNI gara del calendario: il backend ne tiene uno per `tornei_gara_id`, riaprire non
// ne crea un secondo. I dati logistici (avversario, campo, orari) NON si chiedono qui: arrivano dalla
// gara del torneo, che e' l'unica fonte. Chiederli di nuovo significherebbe avere due copie della
// stessa informazione, una nel calendario e una nel foglio, destinate a divergere.
const modalConv = ref(false)
const convGara = ref(null)            // la riga di tornei_gara
const convTorneo = ref(null)          // il torneo, per dirlo nell'intestazione
const convSezione = ref(null)         // per riaprire il calendario dove era, come per le gare
const convId = ref(null)              // id del foglio (convocazioni.id), null finche' non si crea
const convNota = ref('')
const convConvocati = ref([])         // persona_id in ordine: l'ordine a schermo E' l'ordine salvato
const convAssenti = ref([])           // persona_id marcati "non presente"
const convRoster = ref([])            // i tesserati della categoria della gara
const convRicerca = ref('')
const convCaricamento = ref(false)
const convSalvataggio = ref(false)
const convExport = ref(false)         // mentre il foglio si genera, perche' jsPDF ci mette un secondo
const erroreConv = ref('')
const confermaConv = ref('')

// ------------------------------------------------------- mister del torneo
// Il referente e' UNO per il torneo intero, non uno per categoria: l'organizzatore chiama un numero
// solo la mattina della domenica, e con le gare su due categorie il mister della singola gara (che
// nel weekend esiste gia') non dice chi risponde del torneo.
//
// La lista viene dagli STESSI responsabili di categoria che usa la programmazione partite del
// weekend, non dalla tabella allenatori: quella tabella in produzione e' vuota (zero righe,
// verificato sul DB di PROD e DEV), quindi un menu attaccato a quella non avrebbe mai offerto un
// nome e sarebbe rimasta solo la voce "manuale".
const misterPerCategoria = ref({})
// '', l'id come stringa, o '__manuale__': lo stesso pattern del weekend
const misterScelta = ref('')

// La categoria "di lavoro" del modal, cioe' QUELLA che decide chi finisce nel menu del Mister: la
// categoria della sezione da cui hai aperto Modifica (stai lavorando nei 2016, e il menu offre i
// mister dei 2016), o il filtro a schermo quando stai creando. E' una ref e non un computed perche'
// la sezione e' un contesto di click: il torneo e' uno solo e sta in piu' sezioni, quindi "da dove
// hai cliccato" e' un'informazione che lo script non puo' dedurre dal torneo.
// null = nessun contesto, il menu torna l'unione delle categorie (il comportamento di prima)
const categoriaLavoro = ref(null)

// L'etichetta da mostrare accanto al menu: dire "le persone delle categorie iscritte" quando poi il
// menu ne mostra solo una parte e' il genere di frase che fa scegliere la persona sbagliata
const etichettaCategoriaLavoro = computed(() => {
  const id = categoriaLavoro.value
  if (!id) return ''
  const c = (categorie.value || []).find(x => String(x.id) === String(id))
  return c ? etichettaCategoria(c) : `categoria ${id}`
})

// Le categorie a cui il mister deve appartenere: la categoria della sezione in cui si sta lavorando
// (se e fra quelle del torneo), altrimenti quelle gia' iscritte in modifica o quelle spuntate in
// creazione. Non si chiedono i responsabili di tutte le categorie della societa' a ogni apertura di
// pagina: sono N richieste per un menu che serve solo a modal aperto
const categorieDelModal = computed(() => {
  const lav = categoriaLavoro.value ? String(categoriaLavoro.value) : null
  const candidate = torneoDaModificare.value
    ? categorieDel(torneoDaModificare.value)
    : (formTorneo.value.categorie_id || []).map(Number).map(id => ({ id }))
  // La categoria di lavoro vale solo se il torneo la contempla davvero: aprirlo da un altro punto
  // (o un filtro cambiato dopo) non deve far sparire le altre persone dal menu
  if (lav && candidate.some(c => String(c.id) === lav)) return [{ id: Number(lav) }]
  return candidate
})

const misterDisponibili = computed(() => {
  const visti = new Map()
  for (const c of categorieDelModal.value) {
    for (const r of (misterPerCategoria.value[String(c.id)] || [])) {
      if (!visti.has(r.id)) visti.set(r.id, r)
    }
  }
  // per cognome, come il weekend: due "Rossi" in fila sono due voci da indovinare, e qui accanto
  // al cognome esce anche il nome
  return [...visti.values()]
    .sort((a, b) => String(a.cognome || '').localeCompare(String(b.cognome || '')))
})

// Cosa nominare nel suggerimento: in modifica la sezione da cui hai aperto il modal, in creazione
// le categorie spuntate. Dire "le persone delle categorie iscritte" quando ne hai spuntata una sola
// non fa capire da dove arriva la lista, e chi crea il torneo non ha modo di accorgersi se il menu
// sta guardando la categoria sbagliata
const doveMenuTesto = computed(() => {
  if (etichettaCategoriaLavoro.value) return etichettaCategoriaLavoro.value
  return categorieDelModal.value
    .map(c => etichettaCategoria((categorie.value || []).find(x => String(x.id) === String(c.id)) || c))
    .join(' e ')
})

const suggerimentoMister = computed(() => {
  if (misterScelta.value === '__manuale__') return 'Verrà stampato nel PDF così com\'è scritto.'
  // Senza categorie non c'e' nessun menu da offrire, e dirlo e' diverso da "non ce ne sono": qui la
  // lista e' vuota perche' non hai ancora detto per chi la vuoi
  if (!categorieDelModal.value.length) return 'Spunta una categoria: il menu offre i mister di quella categoria.'
  if (misterDisponibili.value.length) return `I mister e gli amministrativi di ${doveMenuTesto.value}.`
  return `Nessun responsabile censito per ${doveMenuTesto.value}: scegli "Inserisci manualmente".`
})

// Il mister salvato puo' non essere piu' tra i responsabili delle categorie: cambia l'assegnazione
// di categoria, o il responsabile scioglie un'iscrizione. Senza questa opzione il menu si dipinge
// VUOTO mentre il torneo un referente ce l'ha, e chi apre il modal per cambiare il luogo vede
// "da assegnare" e con il prossimo Salva lo perde davvero. L'opzione si aggiunge solo quando le
// categorie sono gia' state lette, altrimenti per un attimo ogni mister salvato sembrerebbe "fuori
// lista" mentre le richieste sono ancora in volo
const misterFuoriLista = computed(() => {
  const id = misterScelta.value
  if (!id || id === '__manuale__') return null
  const categorie = categorieDelModal.value
  if (!categorie.length) return null
  if (!categorie.every(c => String(c.id) in misterPerCategoria.value)) return null
  if (misterDisponibili.value.some(m => String(m.id) === String(id))) return null
  const nome = (torneoDaModificare.value && torneoDaModificare.value.mister_nome) || `persona ${id}`
  // Il motivo va detto bene: con il menu ristretto alla sezione, un mister degli Esordienti aperto
  // dalla sezione dei Pulcini NON e' "un responsabile che non c'e' piu'", e' uno di un'altra
  // categoria. Scriverlo male fa pensare a un dato perso e induce a sostituirlo
  return { id, nome, motivo: `non e' tra i responsabili di ${doveMenuTesto.value}` }
})

async function caricaMister(ids) {
  const mancanti = [...new Set((ids || []).map(String))].filter(id => !(id in misterPerCategoria.value))
  await Promise.all(mancanti.map(async id => {
    try {
      const res = await getCategoriaResponsabili(Number(id))
      // i dirigenti non guidano le squadre: il weekend li esclude dallo stesso menu, e qui il
      // backend li accetterebbe comunque (valida solo che sia una persona della societa')
      misterPerCategoria.value[id] = (res.data || []).filter(r => r.ruolo !== 'dirigente')
    } catch (e) {
      // un fallimento qui non deve lasciare il modal senza menu ne' impedire di salvare il torneo:
      // il campo resta compilabile a mano
      misterPerCategoria.value[id] = []
    }
  }))
}

function cambioMister() {
  // le due fonti si escludono a vicenda, e la scelta si fa qui per non mandare al backend un
  // payload con entrambe: lo rifiuterebbe con un 400, ma l'utente lo vedrebbe solo dopo un click
  // che sembrava riuscito
  const manuale = misterScelta.value === '__manuale__'
  formTorneo.value.mister_id = manuale || !misterScelta.value ? null : Number(misterScelta.value)
  if (!manuale) formTorneo.value.mister_manuale = ''
  // ^  se si sceglie una persona dal menu, il nome scritto a mano prima non deve restare nel form:
  //    il backend li vuole uno dei due, non entrambi
}

// Spuntando una categoria nuova il menu deve offrire anche le sue persone: senza questo, il
// responsabile iscrive gli Esordienti e nel menu restano solo i mister dei Pulcini
watch(() => [...(formTorneo.value.categorie_id || [])], ids => { caricaMister(ids) })

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
// Le sezioni si costruiscono a partire da UNA LISTA DI TORNEI passata dentro, non leggendo
// `tornei.value`: l'export "tutti i tornei della societa'" deve poterle costruire sulla lista completa
// appena ripresa dall'API, mentre a schermo c'e' la lista filtrata. Un computed che leggeva solo lo
// schermo non poteva farlo, e l'alternativa (cambiare i filtri, riesportare, rimetterli a posto) e'
// il modo in cui un documento esce con dentro meta' giornata
//
// `soloCategoria` e' il filtro scelto in alto, e serve perche' il backend filtra i TORNEI (EXISTS su
// tornei_categorie) ma restituisce ogni torneo con TUTTE le sue categorie: senza questo parametro,
// scegliendo "2016 - Pulcini" la pagina dipingeva comunque la sezione "2015 - Esordienti" con dentro
// il torneo condiviso, cioe' il filtro sembrava non funzionare. Il torneo condiviso lo dice gia' la
// card, con "anche 2015 - Esordienti": la sezione in piu' era rumore, e rendeva falso l'avviso
// "solo la selezione a schermo" del PDF
function costruisciSezioni(lista, soloCategoria = null) {
  const sezioni = []
  const piazzati = new Set()
  const filtro = soloCategoria ? String(soloCategoria) : null
  categorieOperative.value.forEach(cat => {
    const id = String(cat.id)
    if (filtro && id !== filtro) return
    const dentro = lista.filter(t => categorieDel(t).some(c => String(c.id) === id))
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
  // modo peggiore di perdere un torneo. Con il filtro attivo contano solo i tornei che riguardano la
  // categoria scelta: gli altri li ha gia' esclusi il filtro, e rimetterli dentro sarebbe peggio di
  // prima (il filtro darebbe il via libera a cio' che ha appena tolto)
  const extra = {}
  lista.filter(t => !piazzati.has(t.id)).forEach(t => {
    const cats = categorieDel(t)
    if (filtro && !cats.some(c => String(c.id) === filtro)) return
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
}

const sezioniPerCategoria = computed(() => costruisciSezioni(tornei.value, categoriaFiltro.value || null))

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

// `sez` e' la sezione da cui si sta aprendo il modal: e' lei a decidere chi finisce nel menu del
// Mister (stai lavorando nei 2016, il menu offre i mister dei 2016). In creazione non c'e' sezione,
// e il filtro a schermo non viene usato come contesto: li' le categorie le stai scegliendo proprio
// in quel momento, e restringere il menu a una di esse nasconderebbe le persone delle altre che hai
// appena spuntato (difetto che questo file ha gia' corretto una volta)
function apriModalTorneo(t = null, sez = null) {
  erroreModal.value = ''
  nuovaCategoria.value = null
  torneoDaModificare.value = t
  categoriaLavoro.value = (t && sez && sez.catId) ? Number(sez.catId) : null
  formTorneo.value = t
    ? {
        nome: t.nome, data_inizio: t.data_inizio || '',
        data_fine: t.data_fine || '', luogo: t.luogo || '', organizzatore: t.organizzatore || '',
        descrizione: t.descrizione || '',
        mister_id: t.mister_id || null, mister_manuale: t.mister_manuale || ''
      }
    : {
        nome: '',
        // da Scelta.vue si arriva con la categoria gia' in testa: pre-selezione la sua, altrimenti
        // si parte vuoti e si lascia scegliere chi iscrive
        categorie_id: categoriaFiltro.value ? [Number(categoriaFiltro.value)] : [],
        data_inizio: '', data_fine: '', luogo: '', organizzatore: '', descrizione: '',
        mister_id: null, mister_manuale: ''
      }
  // Il menu riparte da quello che c'e' gia' scritto: un torneo con il mister a mano deve riaprirsi
  // con "manuale" selezionato e il nome dentro, non con il menu vuoto che sembrerebbe perso
  misterScelta.value = (formTorneo.value.mister_manuale || '').trim()
    ? '__manuale__'
    : (formTorneo.value.mister_id ? String(formTorneo.value.mister_id) : '')
  modalTorneo.value = true
  caricaMister(categorieDelModal.value.map(c => c.id))
}

async function salvaTorneo() {
  erroreModal.value = ''
  if (!formTorneo.value.nome?.trim()) { erroreModal.value = "Il nome del torneo e' obbligatorio"; return }
  const scelte = (formTorneo.value.categorie_id || []).map(Number)
  if (!torneoDaModificare.value && !scelte.length) {
    erroreModal.value = 'Seleziona almeno una categoria: senza categorie il torneo non ha squadre'
    return
  }
  // "manuale" senza nome non e' un torneo senza mister: e' un nome perso per strada. Lasciarlo
  // passare significherebbe svuotare il campo senza che nessuno lo dica, e il PDF uscirebbe senza
  // referente mentre lo schermo mostrava la voce selezionata
  if (misterScelta.value === '__manuale__' && !(formTorneo.value.mister_manuale || '').trim()) {
    erroreModal.value = 'Scrivi il nome del mister, o scegli una persona dal menu'
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
      descrizione: formTorneo.value.descrizione || null,
      // uno solo dei due, come deciso dal menu: il backend rifiuta chi li manda entrambi
      mister_id: misterScelta.value && misterScelta.value !== '__manuale__'
        ? Number(misterScelta.value) : null,
      mister_manuale: misterScelta.value === '__manuale__'
        ? (formTorneo.value.mister_manuale || '').trim() : null
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

// ------------------------------------------------------- convocazione di una gara di torneo
// Il meccanismo dei convocati non e' importabile da Convocazioni.vue: quella pagina e' una SFC da 3703
// righe senza nessun export e con 1484 righe di CSS scoped. Qui si riprende la stessa IDEA (chi e'
// convocato, in che ordine, chi e' segnato assente) in una forma proporzionata a una gara sola.
//
// Cio' che NON si rifà qui: i dati logistici. Avversario, campo, indirizzo, appuntamento e inizio gara
// li scrive il backend copiandoli dalla riga di tornei_gare, quindi il calendario resta l'unica fonte
// e non esiste un secondo posto dove correggere l'orario della domenica.

function categoriaDellaGara(t, g) {
  // La stessa regola del backend, anticipata qui solo per non far aprire un modal che verrebbe rifiutato:
  // con piu' categorie iscritte e la gara senza categoria, scegliere noi significherebbe convocare i
  // Pulcini per la gara degli Esordienti. Il backend risponde 400 e qui si dice perche' il pulsante e'
  // spento, invece di lasciarlo premere per niente
  if (g && g.categoria_id) return Number(g.categoria_id)
  const iscritte = categorieDel(t)
  return iscritte.length === 1 ? Number(iscritte[0].id) : null
}

const convNonConvocati = computed(() => {
  const q = convRicerca.value.trim().toLowerCase()
  return convRoster.value
    .filter(p => !convConvocati.value.includes(p.id))
    .filter(p => !q || (`${p.cognome} ${p.nome}`).toLowerCase().includes(q))
    .sort((a, b) => String(a.cognome).localeCompare(String(b.cognome), 'it', { sensitivity: 'base' }))
})

const convConvocatiDettaglio = computed(() =>
  convConvocati.value
    .map((pid, i) => ({ persona: convRoster.value.find(p => p.id === pid), posizione: i + 1 }))
    .filter(x => x.persona))

// L'etichetta della categoria della gara, cercata nelle categorie caricate dalla pagina. Passare a
// etichettaCategoria un oggetto costruito a mano con solo l'id darebbe un'intestazione vuota, e il modal
// della convocazione senza dire PER QUALE categoria si sta scrivendo e' esattamente il tipo di foglio
// plausibile e falso contro cui questo progetto si difende
const convEtichettaCategoria = computed(() => {
  const catId = categoriaDellaGara(convTorneo.value, convGara.value)
  if (!catId) return 'categoria da assegnare'
  const c = categorie.value.find(x => String(x.id) === String(catId))
  return c ? etichettaCategoria(c) : 'categoria ' + catId
})

async function apriConvocazione(t, g, sez = null) {
  erroreConv.value = ''
  confermaConv.value = ''
  convRicerca.value = ''
  convGara.value = g
  convTorneo.value = t
  convSezione.value = sez || null
  convId.value = null
  convNota.value = ''
  convConvocati.value = []
  convAssenti.value = []
  convRoster.value = []
  modalConv.value = true
  convCaricamento.value = true

  const catId = categoriaDellaGara(t, g)
  try {
    // Il roster della categoria della gara, non quella della sezione: sono la stessa cosa finche' la
    // gara ha una categoria, e quando non ce l'ha qui si ferma con un messaggio invece di proporre i
    // ragazzi di una categoria a caso
    const res = await getPersone(catId)
    convRoster.value = (res.data || []).slice().sort((a, b) =>
      String(a.cognome).localeCompare(String(b.cognome), 'it', { sensitivity: 'base' }))

    // Se il foglio esiste gia' si riparte da quello che c'e' in banca dati: aprire la convocazione di
    // una gara gia' convocata e premere Salva senza toccare niente NON deve azzerare i convocati
    const esistente = await getConvocazioneDiGaraTorneo(g.id)
    const foglio = (esistente.data || [])[0]
    if (foglio) {
      convId.value = foglio.id
      convNota.value = foglio.note || ''
      const det = await getConvocazione(foglio.id)
      const gara = (det.data.gare || [])[0]
      const lista = (gara?.giocatori || []).slice().sort((a, b) => a.posizione - b.posizione)
      convConvocati.value = lista.map(x => x.persona_id)
      convAssenti.value = lista.filter(x => x.non_presente).map(x => x.persona_id)
      // Un ragazzo convocato e poi uscito dalla categoria non e' piu' nel roster: tenerlo lo mostrerebbe
      // come "senza nome" e salvarlo lo riconsegnerebbe al backend come se ci fosse ancora
      convConvocati.value = convConvocati.value.filter(pid => convRoster.value.some(p => p.id === pid))
    }
  } catch (e) {
    erroreConv.value = e.response?.data?.detail || 'Impossibile caricare la convocazione'
  } finally {
    convCaricamento.value = false
  }
}

function convoca(personaId) {
  if (!convConvocati.value.includes(personaId)) convConvocati.value.push(personaId)
}

function togliConvocato(personaId) {
  convConvocati.value = convConvocati.value.filter(pid => pid !== personaId)
  convAssenti.value = convAssenti.value.filter(pid => pid !== personaId)
}

function scambiaAssente(personaId) {
  convAssenti.value = convAssenti.value.includes(personaId)
    ? convAssenti.value.filter(pid => pid !== personaId)
    : [...convAssenti.value, personaId]
}

function spostaConvocato(indice, verso) {
  const j = indice + verso
  if (j < 0 || j >= convConvocati.value.length) return
  const arr = convConvocati.value.slice()
  ;[arr[indice], arr[j]] = [arr[j], arr[indice]]
  convConvocati.value = arr
}

async function salvaConvocazione() {
  erroreConv.value = ''
  confermaConv.value = ''
  const t = convTorneo.value
  const g = convGara.value
  const catId = categoriaDellaGara(t, g)
  if (!catId) {
    erroreConv.value = 'Questa gara non ha una categoria e il torneo ne ha piu\' di una: assegnala dal calendario prima di convocare'
    return
  }
  convSalvataggio.value = true
  const giocatori = convConvocati.value.map((pid, i) => ({
    persona_id: pid,
    // posizione = indice+1, ricalcolata qui come fa la pagina Convocazioni: non e' il numero di maglia,
    // e' l'ordine del foglio. Il backend la ricalcola comunque, ma mandarla coerente evita che un client
    // diverso possa lasciare buchi
    posizione: i + 1,
    non_presente: convAssenti.value.includes(pid)
  }))
  const corpo = { categoria_id: catId, tornei_gara_id: g.id, data_inizio: g.data || t.data_inizio,
                 note: convNota.value || null, giocatori }
  try {
    // Due scritture, perche' POST e' idempotente: se il foglio esiste gia' RESTITUISCE l'id esistente
    // senza applicare i giocatori (e' cio' che impedisce a un doppio click di creare un secondo foglio).
    // Il salvataggio vero deve quindi passare dal PUT in ogni caso.
    const creato = await creaConvocazioneTorneo(corpo)
    convId.value = creato.data.id
    await salvaConvocazioneTorneo(convId.value, corpo)
    modalConv.value = false
    await ricaricaConCalendarioAperto(t.id, convSezione.value)
  } catch (e) {
    erroreConv.value = e.response?.data?.detail || 'Errore nel salvataggio della convocazione'
  } finally {
    convSalvataggio.value = false
  }
}

/**
 * Il foglio di convocazione di questa gara di torneo, in PDF.
 *
 * E' LO STESSO DOCUMENTO della pagina Convocazioni: chiama `esportaFoglioConvocazione`, non una copia
 * scritta qui. Un torneo ha una gara per foglio, quindi la `gare` e' un array di uno, e i dati logistici
 * si prendono da `convGara` (la riga di `tornei_gare`) con gli STESSI accoppiamenti che scrive il backend
 * nel foglio: `appuntamento`<-`ora_appuntamento` e `inizio_gara`<-`ora`. Scambiarli qui darebbe un foglio
 * con l'ora del ritrovo al posto del calcio d'inizio, e nel PDF dei calendari e' gia' successo.
 *
 * Cosa si esporta: QUELLO CHE C'E' A SCHERMO, non una rilettura dal database. Il pulsante sta accanto a
 * "Salva convocazione" proprio per questo: chi esporta ha davanti la lista che sta per uscire. Se il
 * documento rileggesse il DB, un mister che aggiunge un ragazzo e stampa senza salvare si ritroverebbe in
 * chat un foglio diverso da quello che ha visto, cioe' un documento plausibile e falso. La pagina
 * Convocazioni fa gia' cosi' (esporta `convocazione.value`, non un GET fresco).
 *
 * Perche' `etichettaAllenatori` e' vuota: la riga "Allenatore" del weekend legge i responsabili della
 * partita, e una gara di torneo non li ha (il backend scrive `allenatore = None`). Il referente del
 * torneo NON viene messo qui per scelta del titolare: il suo posto e' la colonna Mister del calendario
 * tornei, che esce da un altro documento. Il foglio uscira' quindi con "Allenatore  —".
 */
async function esportaConvocazionePDF() {
  const t = convTorneo.value
  const g = convGara.value
  if (!g) return
  const catId = categoriaDellaGara(t, g)
  // L'oggetto categoria vero, non uno costruito a mano con solo l'id: il foglio ci scrive
  // `nome + anno` sotto il titolo, e un'etichetta vuota sarebbe un foglio senza destinatario
  const categoria = catId ? (categorie.value.find(x => String(x.id) === String(catId)) || null) : null
  convExport.value = true
  try {
    await esportaFoglioConvocazione({
      convocazione: {
        // Stessa regola del salvataggio: la data della gara, e se l'organizzatore non l'ha messa quella
        // del torneo. Il foglio a schermo e il foglio salvato devono avere la stessa data
        data_inizio: g.data || t?.data_inizio || null,
        data_fine: null,
        note: convNota.value || '',
        // Una gara sola: il foglio di convocazione di una gara di torneo copre quella gara
        gare: [{
          numero: 1,
          // `avversario` e' il titolo del blocco, come `gara` lo e' per il weekend: senza, il foglio non
          // dice nemmeno contro chi si gioca
          gara: g.avversario || `Gara ${g.numero || 1}`,
          data: g.data,
          campo: g.campo,
          indirizzo: g.indirizzo,
          appuntamento: g.ora_appuntamento,
          inizio_gara: g.ora,
          // array di persona_id, come lo aspetta `buildRows`; `.slice()` perche' il foglio non tocchi
          // l'ordine del modal (lo riordina in base ai cognomi, e a schermo deve restare il nostro)
          giocatori: convConvocati.value.slice()
        }]
      },
      persone: convRoster.value,
      societa: societaAttiva.value,
      categoria,
      stagione: stagioneCorrente.value,
      etichettaAllenatori: () => ''
    })
  } finally {
    convExport.value = false
  }
}

// ------------------------------------------------------- esportazione PDF
// QUATTRO pulsanti, UNA sola funzione: tutti i tornei della societa' (indipendente da cosa c'e' a
// schermo), la selezione a schermo, questa categoria, questo torneo in questa categoria. Sono lo
// stesso documento con perimetro diverso, e tre funzioni che si duplicano il foglio di stile sono
// tre documenti che il giorno dopo non si assomigliano piu'.
// I filtri in alto (categoria, date) servono a TROVARE un torneo, non a decidere cosa finisce nel
// file che l'organizzatore riceve: per questo il pulsante "tutti i tornei" si ricarica la lista senza
// parametri, e quando invece si esporta cio' che si vede il documento LO DICE, perche' un foglio con
// meta' giornata e nessun segno che lo dice e' plausibile e falso
const filtriAttivi = computed(() => {
  const parti = []
  if (categoriaFiltro.value) {
    const c = categorieOperative.value.find(x => String(x.id) === String(categoriaFiltro.value))
    parti.push('categoria ' + (c ? etichettaCategoria(c) : '#' + categoriaFiltro.value))
  }
  if (daFiltro.value) parti.push('dal ' + formatoData(daFiltro.value))
  if (aFiltro.value) parti.push('al ' + formatoData(aFiltro.value))
  return parti
})

/**
 * Come si legge il Mister nella colonna: `Cognome Nome (cellulare)`, o `non assegnato`.
 * Stesso testo della card, perche' la card e il PDF sono lo stesso dato visto da due persone che si
 * parlano fra loro: se uno dei due tace il buco, l'organizzatore telefona a chi non c'e'.
 */
function testoMisterPdf(t) {
  if (!t || !t.mister_nome) return 'non assegnato'
  return t.mister_cellulare ? `${t.mister_nome} (${t.mister_cellulare})` : t.mister_nome
}

/**
 * Il PDF dei tornei, in quattro varianti che sono la stessa funzione: tutte le categorie della
 * societa', la selezione a schermo, una categoria, un singolo torneo.
 *
 * **Solo il calendario, mai i giocatori.** Il roster esce soltanto da Liste Tornei, dove chi stampa
 * ha verificato il codice fiscale: un PDF dei tornei con dentro i nomi dei ragazzi sarebbe il modo
 * piu' semplice di portarli fuori, perche' quel file viaggia in chat verso gli organizzatori.
 *
 * La forma e' quella del weekend (vedi core/utils/pdfTHOF.js): intestazione con il nome della
 * societa', tabelle col tema rosso, le barre di categoria e di torneo come RIGHE colSpan dentro il
 * corpo, il Mister come colonna. Non e' estetica: un calendario consegnato all'organizzatore deve
 * assomigliare al calendario che la societa' gia' stampa il venerdi', altrimenti in chat arrivano due
 * documenti che sembrano di due associazioni diverse.
 *
 * Perche' UNA tabella per torneo e non una tabella sola come nel weekend: ogni torneo ha la sua barra
 * con nome, periodo, luogo e organizzatore, e mischiarli in un'unica tabella perderebbe il confine fra
 * un impegno e l'altro. La barra della categoria esce una volta sola per gruppo, quando cambia:
 * ripetuta sotto ogni torneo direbbe niente.
 */
async function esportaPDF(sez = null, torneo = null, opts = {}) {
  const sezioni = opts.sezioni || (sez ? [sez] : sezioniPerCategoria.value)
  if (!sezioni.length || esportazione.value) return
  // Chi ha chiesto "tutti i tornei" ha gia' una lista presa senza filtri: per lui questo avviso non ha
  // senso. Per gli altri tre pulsanti il perimetro e' quello che sta a schermo, e se a schermo c'e' un
  // filtro attivo il documento e' un sottoinsieme: va scritto nel foglio, non lasciato intuire
  const avviso = opts.avviso || (opts.senzaFiltri ? null : (filtriAttivi.value.length
      ? `ATTENZIONE: solo la selezione a schermo (${filtriAttivi.value.join(' · ')}), non tutti i tornei della societa'`
      : null))
  const oggi = new Date().toLocaleDateString('it-IT')
  esportazione.value = true
  errore.value = ''
  try {
    const doc = new jsPDF({ orientation: 'landscape' })
    const nomeSocieta = societaAttiva.value?.nome || ''
    // Il nome della societa' in coda al titolo, come nel weekend (`<nome> - <societa'>`): il file
    // parte in chat e arriva a organizzatori di altre societa'
    const conSocieta = t => (nomeSocieta ? `${t} - ${nomeSocieta}` : t)
    const titolo = opts.titolo || conSocieta(opts.titoloBase
      || (torneo ? `${torneo.nome} — ${sez.titolo}`
                 : sez ? `Tornei ${sez.titolo}`
                       : 'Tutti i tornei della società'))
    // La riga grigia sotto il titolo, come nel weekend: cosa c'e' dentro e quando e' stato generato.
    // Nel torneo singolo c'e' anche il Mister, perche' e' la prima cosa che l'organizzatore cerca
    const quanti = sezioni.reduce((n, s) => n + (torneo ? 1 : (s.tornei || []).length), 0)
    const sottotitolo = opts.sottotitolo || (torneo
      ? [formatoPeriodo(torneo), `Mister: ${testoMisterPdf(torneo)}`, `Generato il ${oggi}`].filter(Boolean).join(' | ')
      : [`${quanti} ${quanti === 1 ? 'torneo' : 'tornei'}` +
         (sez ? ' in questa categoria' : ` in ${sezioni.length} categor${sezioni.length === 1 ? 'ia' : 'ie'}`),
         `Generato il ${oggi}`].join(' | '))
    let y = intestazionePdf(doc, { titolo, sottotitolo, avviso })

    const COLONNE = 8
    const headers = [['Data', 'Ora', 'Avversario', 'Appuntamento', 'Campo', 'Indirizzo', 'Mister', 'Note']]
    const didParseCell = function (d) {
      didParseCellBarra(d)
      if (d.section !== 'body' || !d.cell || (d.raw && d.raw.colSpan)) return
      coloraDomenica(d, 0)
      // Il referente che non c'e' si vede anche in tabella: chi sfoglia il calendario deve poter
      // dire "qui manca un numero da chiamare" senza tornare all'intestazione
      if (d.column.index === 6 && String(d.cell.raw) === 'non assegnato') {
        d.cell.styles.textColor = AMBRA_THOF
        d.cell.styles.fontStyle = 'italic'
      }
    }
    // autotable impagina da solo anche fra una tabella e l'altra: se lo spazio rimasto non basta,
    // ricomincia su un foglio nuovo con la testata. E' il motivo per cui qui non c'e' piu' nessun
    // "respira()" calcolato a mano come nella prima versione
    const tabella = (head, body, larghezza, stili, testata) => {
      doc.autoTable({
        ...BASE_TABELLA,
        head, body, startY: y,
        tableWidth: larghezza || 260,
        columnStyles: stili,
        ...(testata ? { headStyles: testata } : {}),
        didParseCell
      })
      y = doc.lastAutoTable.finalY + 7
    }
    // Le gare senza categoria, o con una categoria non piu' iscritta: una sezione loro non ce
    // l'hanno, quindi tendono a sparire dall'export. Se il documento le tacesse sarebbe un calendario
    // che ne mostra sei su otto. Una volta sola per torneo: in "tutte le categorie" lo stesso torneo
    // sta in piu' sezioni e ripetere le stesse righe e' peggio che non ripeterle
    const orfaneStampate = new Set()
    let ultimaCategoria = null

    for (const s of sezioni) {
      const lista = torneo ? [torneo] : (s.tornei || [])
      if (!lista.length) {
        tabella(headers, [barra(`${s.titolo} — nessun torneo in questa categoria`, COLONNE, 'avviso')],
                260, { 0: { cellWidth: 26 }, 1: { cellWidth: 14 }, 2: { cellWidth: 'wrap' }, 3: { cellWidth: 26 },
                      4: { cellWidth: 30 }, 5: { cellWidth: 'wrap' }, 6: { cellWidth: 38 }, 7: { cellWidth: 'wrap' } })
        continue
      }

      for (const t of lista) {
        const body = []
        // La barra della categoria esce solo al primo torneo del gruppo: sotto ogni tabella sarebbe
        // rumore, e il documento si legge ancora come il weekend
        if (ultimaCategoria !== String(s.catId)) {
          body.push(barra(s.titolo, COLONNE))
          ultimaCategoria = String(s.catId)
        }
        const rigaTorneo = [t.nome, formatoPeriodo(t), t.luogo, t.organizzatore ? 'a cura di ' + t.organizzatore : '']
          .filter(Boolean).join('   ·   ')
        body.push(barra(rigaTorneo, COLONNE, 'torneo'))

        // null vuol dire "non sono riuscita a leggerle", [] vuol dire "non ce ne sono": stampare
        // "nessuna gara" quando la richiesta era fallita consegnerebbe un calendario falso
        const tutte = await gareDel(t)
        if (tutte === null) {
          body.push(barra('Gare non caricabili: la richiesta al server e\' fallita, questo calendario non e\' completo', COLONNE, 'avviso'))
        } else {
          const gare = tutte.filter(g => g.categoria_id && String(g.categoria_id) === String(s.catId))
          if (!gare.length) {
            body.push(barra('Nessuna gara per questa categoria', COLONNE, 'avviso'))
          } else {
            gare.forEach(g => body.push([
              cellData(g.data, '-'), g.ora || '-', g.avversario || '-', g.ora_appuntamento || '-',
              g.campo || '-', g.indirizzo || '-', testoMisterPdf(t), g.note || '-'
            ]))
          }
        }
        tabella(headers, body, 260, {
          0: { cellWidth: 26, halign: 'center' },
          1: { cellWidth: 14, halign: 'center' },
          2: { cellWidth: 'wrap' },
          3: { cellWidth: 30, halign: 'center' },
          4: { cellWidth: 26, halign: 'center' },
          5: { cellWidth: 'wrap' },
          6: { cellWidth: 38 },
          7: { cellWidth: 'wrap' }
        })

        // QUI NON C'E' IL FOGLIO GIOCATORI, e non va rimesso: il roster esce SOLO da Liste Tornei,
        // dove chi lo stampa ha verificato il codice fiscale. Un calendario che portasse anche i nomi
        // dei ragazzi sarebbe la scorciatoia per portarli fuori in un file che finisce in chat agli
        // organizzatori. Il buco del foglio manca lo dice la card (badge "foglio assente" e il pulsante
        // "Foglio giocatori"), non il documento che si consegna

        // Testata ambra, non rossa: queste non sono appuntamenti, sono un buco da riempire prima di
        // consegnare il calendario
        if (tutte !== null && !orfaneStampate.has(t.id)) {
          const iscritte = new Set(categorieDel(t).map(c => String(c.id)))
          const orfane = tutte.filter(g => !g.categoria_id || !iscritte.has(String(g.categoria_id)))
          if (orfane.length) {
            orfaneStampate.add(t.id)
            tabella(
              [[`Gare senza categoria (${orfane.length}) — da assegnare a una categoria`, 'Avversario', 'Data', 'Inizio', 'Campo']],
              orfane.map(g => [
                g.numero ? 'Gara ' + g.numero : '-', g.avversario || 'Da definire', cellData(g.data, '-'),
                g.ora || '-', [g.campo, g.indirizzo].filter(Boolean).join(' — ') || '-'
              ]),
              200,
              { 0: { cellWidth: 56 }, 1: { cellWidth: 'wrap' },
                2: { cellWidth: 26, halign: 'center' }, 3: { cellWidth: 16, halign: 'center' },
                4: { cellWidth: 'wrap' } },
              { fillColor: AMBRA_THOF, textColor: 255, fontStyle: 'bold', halign: 'left', fontSize: 9 }
            )
          }
        }
      }
    }

    // Nomi file diversi per i quattro livelli, perche' finiscono in una chat e "tornei.pdf" non dice
    // cosa c'e' dentro. Con la societa' in coda: due societa' che si scambiano i calendari non devono
    // ritrovarsi due file che si chiamano uguale. Gli altri caratteri illegali li toglie
    // sanitizeFilename dentro saveOrSharePdf
    const pulito = s => String(s || '').replace(/[^\w]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase()
    const suffissoSocieta = nomeSocieta ? '_' + pulito(nomeSocieta) : ''
    const nomeFile = opts.nomeFile || (torneo
      ? `tornei_${pulito(torneo.nome)}_${pulito(`${sez.anno || ''} ${sez.nome || ''}`)}${suffissoSocieta}.pdf`
      : sez ? `tornei_${pulito(`${sez.anno || ''} ${sez.nome || ''}`)}${suffissoSocieta}.pdf`
            : `tornei_tutte_categorie${suffissoSocieta}.pdf`)
    await saveOrSharePdf(doc, nomeFile, titolo)
    conferma.value = 'PDF generato'
  } catch (e) {
    // console.error perche' dall'esterno un'eccezione inghiottita qui sarebbe invisibile: la pagina
    // mostrerebbe solo "Errore nella generazione del PDF" e il test non avrebbe modo di capire perche'
    console.error('Export PDF tornei fallito:', e)
    errore.value = 'Errore nella generazione del PDF'
  } finally {
    esportazione.value = false
  }
}

// Il pulsante "Esporta tutti i tornei". Non riusa `tornei.value`: si ricarica la lista SENZA
// parametri, perche' il documento che porta il nome della societa' deve contenere la societa' intera
// anche mentre a schermo c'e' un filtro attivo. Chiedere all'utente di togliere i filtri prima di
// esportare e' la stessa classe di errore del "ricordati di salvare prima di chiudere": funziona fin
// che nessuno si dimentica
async function esportaTutti() {
  if (esportazione.value) return
  errore.value = ''
  let lista
  try {
    lista = (await getTornei({})).data || []
  } catch (e) {
    console.error('Export "tutti i tornei": lettura lista fallita:', e)
    // Meglio nessun PDF che un PDF a meta': chi lo riceve non ha modo di accorgersi che mancano
    // dei tornei, e lo consegna all'organizzatore lo stesso
    errore.value = 'Esportazione interrotta: non sono riuscita a leggere tutti i tornei della societa'
    return
  }
  if (!lista.length) { errore.value = 'Nessun torneo da esportare'; return }
  const soc = societaAttiva.value?.nome
  await esportaPDF(null, null, {
    sezioni: costruisciSezioni(lista),
    senzaFiltri: true,
    titoloBase: 'Tutti i tornei della società',
    nomeFile: soc ? `tornei_societa_${String(soc).replace(/[^\w]+/g, '_').toLowerCase()}.pdf`
                  : 'tornei_societa.pdf',
    sottotitolo: `${lista.length} ${lista.length === 1 ? 'torneo' : 'tornei'} di tutta la societa'`
                 + (filtriAttivi.value.length ? ' (i filtri a schermo non contano)' : '')
  })
}

// Il pulsante che compare solo con un filtro attivo: esporta esattamente il perimetro che si sta
// guardando. Serve a chi vuole "solo il weekend di Natale", ma il foglio deve dichiararlo da solo,
// perche' il file parte in chat e chi lo riceve non ha visto lo schermo di chi l'ha generato
async function esportaSelezione() {
  await esportaPDF(null, null, {
    sezioni: sezioniPerCategoria.value,
    titoloBase: 'Tornei (selezione a schermo)',
    nomeFile: 'tornei_selezione.pdf'
  })
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
  background: transparent; border: none; color: var(--color-text-muted); font-size: 0.8125rem; cursor: pointer;
}
.btn-back:hover { color: var(--color-primary); }

.nota { color: var(--color-text-secondary); font-size: 0.8125rem; margin: 0 0 1rem; }

.filtri { display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap; margin-bottom: 1rem; }
.select-filtro, .filtro-data input {
  padding: 0.4rem 0.5rem; border-radius: var(--radius-md, 8px); border: 1px solid var(--color-border);
  background: var(--color-surface); color: var(--color-text); font-size: 0.8125rem;
}
.filtro-data { display: flex; align-items: center; gap: 0.375rem; color: var(--color-text-secondary); font-size: 0.75rem; }

.stato { padding: 2rem; text-align: center; color: var(--color-text-muted); font-size: 0.875rem; }
.stato.piccolo { padding: 0.75rem; font-size: 0.8125rem; }
.messaggio { padding: 0.5rem 0.75rem; border-radius: var(--radius-md, 8px); font-size: 0.8125rem; margin-bottom: 0.75rem; }
.messaggio.errore { background: var(--color-primary-soft); color: var(--color-error); }
.messaggio.successo { background: var(--color-success-soft); color: var(--color-success); }

/* I colori vengono TUTTI dalle variabili di global.css. Questa pagina era stata scritta con
   letterali pensati per un tema scuro (#d4d4d4 su rgba(255,255,255,0.06), #facc15, #171717):
   l'app non ha nessun tema scuro, `--color-surface` e' #ffffff, e a schermo i bottoni delle azioni
   risultavano grigio chiarissimo su bianco, praticamente illeggibili. Verificato su DEV con lo
   screenshot della pagina, non a occhio sul codice. */
.torneo-card {
  background: var(--color-surface); border: 1px solid var(--color-border);
  border-radius: var(--radius-lg, 12px); padding: 1rem; margin-bottom: 0.875rem;
  box-shadow: var(--shadow-sm); transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.torneo-card:hover { border-color: var(--color-primary); box-shadow: 0 4px 12px rgba(20,26,36,0.08); }
.torneo-testata { cursor: pointer; }
.torneo-titolo { display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.375rem; }
.torneo-nome { font-size: 1.0625rem; font-weight: 700; color: var(--color-text); }
.badge {
  padding: 0.125rem 0.4375rem; border-radius: 999px; font-size: 0.6875rem; font-weight: 600;
  background: var(--color-slate-soft); color: var(--color-text-secondary);
}
.badge.categoria { background: var(--color-info-soft); color: var(--color-info); }
.badge.gare { background: var(--color-violet-soft); color: var(--color-violet); }
.badge.lista { background: var(--color-success-soft); color: var(--color-success); }
.badge.lista.vuota { background: var(--color-warning-soft); color: var(--color-warning); }

.torneo-meta { display: flex; gap: 0.875rem; flex-wrap: wrap; color: var(--color-text-secondary); font-size: 0.8125rem; }
/* Il referente del torneo, mostrato anche quando manca: un documento da consegnare senza un numero
   da chiamare lo si scopre la mattina del torneo, qui costa una riga color ambra */
.mister-torneo { display: inline-flex; align-items: center; gap: 0.25rem; }
.mister-torneo.assente { color: var(--color-warning); font-weight: 600; }
.mister-tel { color: var(--color-text-muted); font-size: 0.75rem; }
.mister-manuale { margin-top: 0.375rem; }
.torneo-descrizione { color: var(--color-text-secondary); font-size: 0.8125rem; margin: 0.5rem 0 0; white-space: pre-line; }

.torneo-azioni { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 0.75rem; }
.btn-azione {
  padding: 0.375rem 0.75rem; border-radius: var(--radius-md, 8px); font-size: 0.75rem; font-weight: 600;
  background: var(--color-surface); border: 1px solid var(--color-border-strong); color: var(--color-text-secondary);
  cursor: pointer;
}
.btn-azione:hover:not(:disabled) { border-color: var(--color-primary); color: var(--color-primary); background: var(--color-primary-soft); }
.btn-azione.primario { background: var(--color-primary-soft); border-color: rgba(220,38,38,0.35); color: var(--color-primary); }
.btn-azione.primario:hover { background: var(--color-primary); border-color: var(--color-primary); color: white; }
.btn-azione.pericolo { color: var(--color-error); }
.btn-azione:disabled { opacity: 0.5; cursor: not-allowed; }

.calendario { margin-top: 0.875rem; border-top: 1px solid var(--color-border); padding-top: 0.5rem; }
.gara-riga {
  display: flex; gap: 0.625rem; padding: 0.5rem 0; align-items: flex-start;
  border-bottom: 1px solid var(--color-border-light);
}
.gara-numero {
  flex: 0 0 1.5rem; height: 1.5rem; border-radius: 999px; display: flex; align-items: center;
  justify-content: center; font-size: 0.6875rem; font-weight: 700;
  background: var(--color-slate-soft); color: var(--color-text-secondary);
}
.gara-corpo { flex: 1; min-width: 0; }
.gara-verso { font-size: 0.9375rem; color: var(--color-text); }
.gara-dettaglio { display: flex; gap: 0.75rem; flex-wrap: wrap; color: var(--color-text-muted); font-size: 0.75rem; margin-top: 0.1875rem; }
.gara-note { color: var(--color-text-secondary); font-size: 0.75rem; margin-top: 0.25rem; white-space: pre-line; }
.gara-azioni { display: flex; gap: 0.25rem; }
.btn-icon {
  padding: 0.3125rem; border-radius: var(--radius-md, 8px); background: transparent; border: none;
  color: var(--color-text-muted); cursor: pointer;
}
.btn-icon:hover { background: var(--color-slate-soft); color: var(--color-primary); }
.btn-icon.pericolo:hover { color: var(--color-error); }
.btn-aggiungi {
  margin-top: 0.625rem; padding: 0.375rem 0.75rem; border-radius: var(--radius-md, 8px);
  background: transparent; border: 1px dashed var(--color-border-strong); color: var(--color-text-secondary);
  font-size: 0.75rem; cursor: pointer;
}
.btn-aggiungi:hover { color: var(--color-primary); border-color: var(--color-primary); background: var(--color-primary-soft); }

/* Modal: gli stili sono scoped e non esiste un CSS globale condiviso, quindi ogni pagina
   definisce i suoi (come ListeTornei.vue). Gli stessi nomi di classe, le stesse variabili. */
.modal-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,0.6);
  display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.modal {
  background: var(--color-surface); border: 1px solid var(--color-border);
  border-radius: 16px; width: 92%; max-width: 460px; max-height: 90vh;
  display: flex; flex-direction: column; box-shadow: var(--shadow);
}
.modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.25rem 1.5rem 0.75rem;
}
.modal-header h3 { font-size: 1.125rem; font-weight: 700; color: var(--color-text); margin: 0; }
.modal-close {
  background: transparent; border: none; color: var(--color-text-muted); cursor: pointer; padding: 0.25rem;
  display: flex; align-items: center;
}
.modal-close:hover { color: var(--color-text); }
.modal-close svg { width: 20px; height: 20px; }
.modal-body { padding: 0 1.5rem; overflow-y: auto; }
.modal-footer {
  display: flex; justify-content: flex-end; gap: 0.5rem; padding: 1rem 1.5rem 1.25rem;
}
.suggerimento {
  font-size: 0.75rem; color: var(--color-info); background: var(--color-info-soft);
  border-left: 2px solid var(--color-info); padding: 0.5rem 0.625rem;
  border-radius: 6px; margin: 0 0 1rem;
}

.form-group { margin-bottom: 0.875rem; flex: 1; }
.form-group label {
  display: block; font-size: 0.75rem; font-weight: 600;
  color: var(--color-text-muted); margin-bottom: 0.3125rem;
}
.form-group input, .form-group select, .form-group textarea {
  width: 100%; padding: 0.5625rem 0.75rem; border: 1px solid var(--color-border);
  border-radius: 10px; background: var(--color-surface); color: var(--color-text);
  font-size: 0.875rem; box-sizing: border-box; font-family: inherit;
}
.form-group input:focus, .form-group select:focus, .form-group textarea:focus {
  outline: none; border-color: var(--color-primary);
}
/* Le opzioni del menu a tendina si dipingono da sole, fuori dal flusso della pagina: lasciarle
   scritte per un tema scuro dava un menu nero con testo chiarissimo su un'app bianca */
.form-group select option { background: var(--color-surface); color: var(--color-text); }
.form-group textarea { resize: vertical; }
.form-riga { display: flex; gap: 0.75rem; }

.btn-primary {
  display: flex; align-items: center; gap: 0.375rem; padding: 0.5rem 1rem; border: none;
  border-radius: 10px; background: var(--color-primary); color: white; font-size: 0.8125rem;
  font-weight: 600; cursor: pointer;
}
.btn-primary:hover:not(:disabled) { background: var(--color-primary-dark); }
.btn-primary:disabled { opacity: 0.6; cursor: wait; }
.btn-secondary {
  padding: 0.5rem 1rem; border: 1px solid var(--color-border-strong);
  border-radius: 10px; background: transparent; color: var(--color-text-secondary); font-size: 0.8125rem; cursor: pointer;
}
.btn-secondary:hover { color: var(--color-text); background: var(--color-slate-soft); }

/* ------------------------------------------------------------------ sezioni per categoria
   Il primo livello della pagina, stesso aspetto delle sezioni di ProgrammazionePartite.vue: titolo
   grande e bordo basso del colore primario. Chi apre la pagina deve vedere prima "2016 - Pulcini"
   e solo dopo i tornei, perche' la domanda reale e' "cosa fa la mia categoria" */
.categoria-sezione { margin: 0 0 1.75rem; }
.categoria-sezione:last-of-type { margin-bottom: 0; }
.categoria-intestazione {
  display: flex; align-items: center; gap: 0.625rem; flex-wrap: wrap;
  font-size: 1.25rem; font-weight: 700; color: var(--color-text);
  margin: 0 0 0.875rem; padding-bottom: 0.625rem; letter-spacing: -0.01em;
  border-bottom: 2px solid var(--color-primary);
}
.conteggio-sezione {
  font-size: 0.6875rem; font-weight: 600; padding: 0.125rem 0.4375rem; border-radius: 999px;
  background: var(--color-slate-soft); color: var(--color-text-secondary);
}

/* Il pulsante di export, nelle due versioni: nell'intestazione della pagina (tutte le categorie)
   e in quella di ogni sezione (solo quella categoria). Stesso ruolo di .btn-secondary-sm nel
   weekend, colori del tema */
.btn-esporta {
  display: inline-flex; align-items: center; gap: 0.3125rem;
  padding: 0.3125rem 0.625rem; border-radius: var(--radius-md, 8px);
  border: 1px solid var(--color-border-strong); background: var(--color-surface);
  color: var(--color-text-secondary); font-size: 0.75rem; font-weight: 600; cursor: pointer;
}
.btn-esporta:hover:not(:disabled) { border-color: var(--color-primary); color: var(--color-primary); background: var(--color-primary-soft); }
.btn-esporta:disabled { opacity: 0.5; cursor: not-allowed; }
/* "Esporta la selezione" non e' lo stesso pulsante con un altro nome: produce un sottoinsieme e il
   PDF lo dichiara. Il bordo tratteggiato e' il linguaggio gia' usato per le altre categorie del
   torneo, cioe' "attenzione, questo non e' quello che sembra a prima vista" */
.btn-esporta.secondario { border-style: dashed; }
/* In fondo all'intestazione, come il pulsante del weekend: a schermo deve dire "questo esporta la
   sezione", non essere l'ennesimo pulsante della card */
.categoria-intestazione .btn-esporta { margin-left: auto; }

/* Le altre categorie dello stesso torneo: stesso colore del badge categoria, ma tratteggiato, perche'
   qui il messaggio non e' "questa e' la tua categoria" bensi' "attenzione, il torneo e' condiviso con
   loro" e "Elimina" le porta via. Non e' decorazione: e' la guardia della card */
.badge.categoria.altrui {
  background: var(--color-info-soft); color: var(--color-info);
  border: 1px dashed rgba(37,99,235,0.45);
}

/* Le gare senza categoria, o con una categoria non piu' iscritta: non hanno una sezione, quindi
   vengono elencate in fondo a quelle del torneo con un'intestazione che le nomina. Un calendario
   che ne mostra sei su otto e' peggio di uno che ammette di averne due senza etichetta */
.orfane-intestazione {
  font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em;
  color: var(--color-warning); margin: 0.75rem 0 0.25rem;
}
.gara-riga.orfana { border-left: 2px solid rgba(180,83,9,0.4); padding-left: 0.5rem; }

/* ------------------------------------------------------------------ scelta delle categorie
   Il checkbox eredita width:100% e il padding da .form-group input: vanno annullati qui, o le
   caselle si allargano una riga ciascuna e la scelta multipla diventa un elenco infinito */
.scelta-categorie {
  display: flex; flex-wrap: wrap; gap: 0.375rem; max-height: 11rem; overflow-y: auto;
  padding: 0.5rem; border: 1px solid var(--color-border);
  border-radius: 10px; background: var(--color-bg);
}
.scelta-categoria {
  display: flex; align-items: center; gap: 0.3125rem; padding: 0.25rem 0.5rem;
  border-radius: 999px; background: var(--color-surface); border: 1px solid var(--color-border);
  cursor: pointer;
  font-size: 0.75rem; font-weight: 500; color: var(--color-text-secondary); margin: 0;
}
.scelta-categoria:hover { border-color: var(--color-primary); color: var(--color-primary); }
.scelta-categoria input[type="checkbox"] {
  width: auto; padding: 0; margin: 0; accent-color: var(--color-primary); cursor: pointer;
}
.conteggio { font-weight: 500; color: var(--color-info); margin-left: 0.25rem; }
.chip-categoria {
  display: inline-flex; align-items: center; gap: 0.3125rem; padding: 0.25rem 0.5rem;
  border-radius: 999px; font-size: 0.75rem; font-weight: 600;
  background: var(--color-info-soft); color: var(--color-info);
}
.chip-x {
  border: none; background: transparent; color: inherit; cursor: pointer;
  font-size: 0.75rem; line-height: 1; padding: 0 0.1875rem; border-radius: 999px;
}
.chip-x:hover { background: var(--color-primary-soft); color: var(--color-error); }
.aggiungi-categoria { display: flex; gap: 0.5rem; margin-top: 0.5rem; align-items: flex-end; }
.aggiungi-categoria select { flex: 1; }
.aggiungi-categoria .btn-secondary { white-space: nowrap; }

/* ---- modal convocazione di una gara di torneo ----
   Tutti i colori vengono da global.css: l'app ha UN SOLO tema, chiaro, e un componente non eredita
   nessun CSS (gli stili sono scoped). Scrivere un letterale pensato per un tema scuro non produce nessun
   errore — la pagina funziona, i dati sono giusti, e a schermo i bottoni sono grigio chiarissimo su
   bianco. E' successo davvero in questa stessa pagina. */
.modal-conv { max-width: 620px; }
.conv-sottotitolo { margin: 0.15rem 0 0; font-size: 0.78rem; color: var(--color-text-secondary); }
.conv-logistica {
  display: flex; flex-wrap: wrap; gap: 0.5rem;
  margin: 0 0 0.75rem; padding: 0.5rem 0.625rem;
  background: var(--color-slate-soft); border-radius: 8px;
  font-size: 0.8rem; color: var(--color-secondary);
}
.conv-colonna { margin-bottom: 0.9rem; }
.conv-titolo { margin: 0 0 0.4rem; font-size: 0.85rem; color: var(--color-secondary); }
.conv-riga {
  display: flex; align-items: center; gap: 0.4rem;
  padding: 0.3rem 0.4rem; border: 1px solid var(--color-border);
  border-radius: 8px; margin-bottom: 0.25rem; background: var(--color-surface);
}
/* Il ragazzo segnato assente resta nel foglio (e' convocato, non partecipa): il segno e' il nome
   cancellato, come nella pagina Convocazioni. Togliere la riga sarebbe un'altra cosa — sarebbe non
   convocarlo affatto */
.conv-riga.assente .conv-nome { text-decoration: line-through; color: var(--color-text-secondary); }
.conv-pos {
  min-width: 1.4rem; text-align: center; font-size: 0.72rem; font-weight: 600;
  color: var(--color-primary); background: var(--color-primary-soft); border-radius: 999px;
}
.conv-nome { flex: 1; font-size: 0.85rem; }
.conv-ordinamento { display: flex; gap: 0.1rem; }
.btn-mini {
  border: 1px solid var(--color-border); background: var(--color-surface);
  color: var(--color-secondary); cursor: pointer;
  font-size: 0.7rem; line-height: 1; padding: 0.25rem 0.4rem; border-radius: 6px;
}
.btn-mini:hover:not(:disabled) { border-color: var(--color-primary); color: var(--color-primary); }
.btn-mini:disabled { opacity: 0.4; cursor: default; }
.btn-mini.primario { color: var(--color-success); border-color: var(--color-success); background: var(--color-success-soft); }
.btn-mini.pericolo:hover:not(:disabled) { color: var(--color-error); border-color: var(--color-error); }
/* La leva presente/assente: verde a destra quando e' "assente", come nella pagina Convocazioni, perche'
   chi guarda il foglio deve vedere a colpo quale nome e' da sostituire */
.btn-mini.leva { min-width: 4.2rem; text-align: center; }
.btn-mini.leva.on { color: var(--color-warning); border-color: var(--color-warning); background: var(--color-warning-soft); }
.conv-ricerca {
  width: 100%; box-sizing: border-box; margin-bottom: 0.4rem;
  padding: 0.4rem 0.5rem; border: 1px solid var(--color-border);
  border-radius: 8px; font-size: 0.85rem; background: var(--color-surface); color: var(--color-secondary);
}

@media (max-width: 560px) {
  .form-riga { flex-direction: column; gap: 0; }
  .modal { max-width: 100%; }
  .aggiungi-categoria { flex-direction: column; align-items: stretch; }
}
</style>