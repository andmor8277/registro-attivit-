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
      <!-- Due pulsanti di export, come in Programmazione Partite: questo prende tutto, quello
           nell'intestazione di ogni sezione prende solo quella categoria. Sono lo stesso documento
           che oggi si ottiene aprendo Liste Tornei, selezionando il torneo e premendo esporta -->
      <button class="btn-esporta" :disabled="!tornei.length || esportazione" @click="esportaPDF()"
              title="Esporta il PDF di tutti i tornei: calendario e foglio giocatori di ogni categoria">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
          <polyline points="14 2 14 8 20 8"/>
          <line x1="12" y1="18" x2="12" y2="12"/><polyline points="9 15 12 18 15 15"/>
        </svg>
        <span>{{ esportazione ? 'Genero…' : 'Esporta PDF' }}</span>
      </button>
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
        <button class="btn-esporta" :disabled="esportazione" @click="esportaPDF(sez)"
                :title="'Esporta il PDF di ' + sez.titolo + ': calendario e foglio giocatori di ogni torneo'">
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
            <button class="btn-azione" @click="apriModalTorneo(t)">Modifica</button>
            <button class="btn-azione pericolo" @click="elimina(t, sez)">Elimina</button>
          </template>
          <!-- Terzo livello di export: questo torneo, in questa categoria. Serve perche' il
               responsabile che deve mandare "il suo" all'organizzatore non gli interessa il resto
               della giornata: un PDF con dentro anche l'altra categoria e' un documento che va
               tagliato a mano prima di essere inviato -->
          <button class="btn-esporta" :disabled="esportazione" @click="esportaPDF(sez, t)"
                  :title="'Esporta il PDF di ' + t.nome + ' per ' + etichettaCategoria(sez) + ': calendario e foglio giocatori'">
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
                  {{ misterFuoriLista.nome }} (non piu' tra i responsabili di queste categorie)
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
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getTornei, getTorneo, creaTorneo, aggiornaTorneo, eliminaTorneo,
  aggiungiGaraTorneo, modificaGaraTorneo, eliminaGaraTorneo, getAllCategorie, isParentCategory,
  iscriviCategoriaTorneo, rimuoviCategoriaTorneo, getGiocatoriLista, saveOrSharePdf,
  getCategoriaResponsabili
} from '../../api/index.js'
import { jsPDF } from 'jspdf'
// Il plugin va importato ANCHE qui, non basta che lo importino Liste Tornei o Programmazione Partite:
// le pagine sono chunk caricati al bisogno, e senza questa riga doc.autoTable e' undefined. E' un
// errore che non si vede in nessun posto, perche' la chiamata cade dentro il try/catch dell'export
import 'jspdf-autotable'
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

// Le categorie a cui il mister deve appartenere: quelle gia' iscritte se sto modificando, quelle
// spuntate adesso se sto creando. Non si chiedono i responsabili di tutte le categorie della
// societa' a ogni apertura di pagina: sono N richieste per un menu che serve solo a modal aperto
const categorieDelModal = computed(() => {
  if (torneoDaModificare.value) return categorieDel(torneoDaModificare.value)
  return (formTorneo.value.categorie_id || []).map(Number).map(id => ({ id }))
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

const suggerimentoMister = computed(() => {
  if (misterScelta.value === '__manuale__') return 'Verrà stampato nel PDF così com\'è scritto.'
  if (misterDisponibili.value.length) return 'Le persone delle categorie iscritte al torneo.'
  return 'Nessun responsabile censito per queste categorie: scegli "Inserisci manualmente".'
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
  return { id, nome }
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

// ------------------------------------------------------- esportazione PDF
// Stesso schema dell'export del weekend: UNA funzione e TRE pulsanti (tutte le categorie, questa
// categoria, questo torneo in questa categoria), perche' sono lo stesso documento con perimetro
// diverso. Tre funzioni che si duplicano il foglio di stile sono tre documenti che il giorno dopo
// non si assomigliano piu'.
// Perche' il foglio giocatori sta qui dentro: il documento che il responsabile consegna
// all'organizzatore e' il calendario delle gare PIU' la lista dei giocatori di quella categoria.
// Finora per averlo bisognava aprire Liste Tornei, selezionare il torneo e premere esporta: due
// passaggi in piu' per prendere un documento che questa pagina ha gia' davanti agli occhi.
// Le colonne del foglio sono #, Cognome, Nome e null'altro: sono esattamente le colonne che
// ListeTornei.vue stampa di default. Data di nascita, codice fiscale e telefoni la' stanno dietro
// il lucchetto GDPR, e un secondo export che li stampasse senza lucchetto sarebbe il modo piu'
// semplice per aggirarlo senza passare dallo sblocco.
async function esportaPDF(sez = null, torneo = null) {
  const sezioni = sez ? [sez] : sezioniPerCategoria.value
  if (!sezioni.length || esportazione.value) return
  esportazione.value = true
  errore.value = ''
  try {
    const doc = new jsPDF({ orientation: 'landscape' })
    const larga = doc.internal.pageSize.getWidth()
    const alta = doc.internal.pageSize.getHeight()

    doc.setFontSize(16); doc.setFont(undefined, 'bold')
    doc.text(torneo ? `${torneo.nome} — ${sez.titolo}`
                    : sez ? `Tornei — ${sez.titolo}`
                    : 'Tornei — tutte le categorie', 14, 15)
    doc.setFontSize(9); doc.setFont(undefined, 'normal'); doc.setTextColor(110)
    doc.text(`Generato il ${new Date().toLocaleDateString('it-IT')}`, 14, 21)
    doc.setTextColor(0)
    let y = 28
    // autotable va a capo da solo DENTRO una tabella; fra un blocco e l'altro il salto pagina va
    // deciso qui, o l'intestazione di un torneo resta orfana in fondo al foglio
    const respira = (serve) => { if (y + serve > alta - 16) { doc.addPage(); y = 18 } }
    // Le orfane si stampano una volta sola per torneo: in "tutte le categorie" lo stesso torneo sta
    // in piu' sezioni, e ripetere due volte le stesse gare in un documento da consegnare e' peggio
    // che non ripeterle a schermo
    const orfaneStampate = new Set()

    for (const s of sezioni) {
      respira(24)
      doc.setFillColor(220, 38, 38); doc.setTextColor(255)
      doc.setFontSize(11); doc.setFont(undefined, 'bold')
      doc.rect(14, y, larga - 28, 8, 'F')
      doc.text(s.titolo, 17, y + 5.6)
      doc.setTextColor(0); doc.setFont(undefined, 'normal')
      y += 13

      for (const t of (torneo ? [torneo] : s.tornei)) {
        // null vuol dire "non sono riuscita a leggerle", [] vuol dire "non ce ne sono": stampare
        // "nessuna gara" quando la richiesta era fallita consegnerebbe un calendario falso
        const tutte = await gareDel(t)
        const gare = tutte === null ? null
          : tutte.filter(g => g.categoria_id && String(g.categoria_id) === String(s.catId))
        const riga = [t.nome, formatoPeriodo(t), t.luogo, t.organizzatore ? 'a cura di ' + t.organizzatore : '']
          .filter(Boolean).join('   ·   ')
        respira(26)
        doc.setFontSize(10); doc.setFont(undefined, 'bold')
        doc.text(String(doc.splitTextToSize(riga, larga - 28)[0]), 14, y)
        doc.setFont(undefined, 'normal'); y += 4

        // Il referente del torneo, in un documento che l'organizzatore riceve e con cui deve
        // sapere chi chiamare. Il nome arriva dal backend (mister_nome), cosi' la card e il PDF
        // dicono la stessa cosa; se non c'e' lo si scrive, perche' un documento senza referente
        // e' il caso in cui il buco va mostrato e non taciuto
        respira(10)
        doc.setFontSize(9)
        if (t.mister_nome) {
          doc.setTextColor(0)
          doc.text(`Mister: ${t.mister_nome}${t.mister_cellulare ? '  (' + t.mister_cellulare + ')' : ''}`, 14, y + 1)
        } else {
          doc.setTextColor(180, 83, 9)
          doc.text('Mister: non assegnato — indicare il referente del torneo', 14, y + 1)
        }
        doc.setTextColor(0); y += 7

        if (tutte === null) {
          doc.setTextColor(180, 83, 9)
          doc.text('Calendario non disponibile: la richiesta alle API e\' fallita. Non consegnare questo documento.', 14, y + 2)
          doc.setTextColor(0); y += 10
        } else if (!gare.length) {
          doc.setTextColor(110); doc.text('Nessuna gara per questa categoria.', 14, y + 2)
          doc.setTextColor(0); y += 9
        } else {
          // spazio minimo prima di una tabella: autotable va a capo da solo, ma iniziare una tabella
          // a fondo pagina vuol dire stampare l'intestazione e una riga, poi saltare pagina — che in
          // un documento da consegnare sembra un errore di stampa
          respira(42)
          doc.autoTable({
            head: [['N.', 'Avversario', 'Data', 'Inizio', 'Appuntamento', 'Campo', 'Note']],
            body: gare.map(g => [
              g.numero || '–', g.avversario || 'Da definire', g.data ? formatoData(g.data) : '–',
              g.ora || '–', g.ora_appuntamento || '–',
              [g.campo, g.indirizzo].filter(Boolean).join(' — ') || '–', g.note || '–'
            ]),
            startY: y, theme: 'grid', margin: { left: 14, right: 14 },
            styles: { fontSize: 8.5, cellPadding: 2.5 },
            headStyles: { fillColor: [220, 38, 38], textColor: 255, fontStyle: 'bold', halign: 'center', fontSize: 9 },
            // le larghezze sono misurate sulle parole dell'intestazione: "Appuntamento" in una
            // colonna da 24 mm si spezzava a meta' ("Appuntamen / to"), che e' il genere di dettaglio
            // che fa sembrare il documento fatto a mano
            columnStyles: {
              0: { cellWidth: 10, halign: 'center' }, 2: { cellWidth: 22, halign: 'center' },
              3: { cellWidth: 14, halign: 'center' }, 4: { cellWidth: 30, halign: 'center' }
            }
          })
          y = doc.lastAutoTable.finalY + 6
        }

        // il foglio giocatori di QUESTA categoria: e' il pezzo che all'organizzatore serve davvero
        const foglio = foglioDi(t, s.catId)
        let giocatori = null
        if (foglio) {
          try { giocatori = (await getGiocatoriLista(foglio.id)).data || [] } catch (e) { giocatori = null }
        }
        respira(24)
        doc.setFontSize(9); doc.setFont(undefined, 'bold')
        doc.text(foglio ? `Foglio giocatori — ${foglio.nome}` : 'Foglio giocatori assente', 14, y)
        doc.setFont(undefined, 'normal'); y += 4

        if (!foglio) {
          doc.setTextColor(180, 83, 9)
          doc.text('Nessun foglio collegato a questa categoria nel torneo: senza questo documento l\'organizzatore non riceve i giocatori.', 14, y)
          doc.setTextColor(0); y += 10
        } else if (giocatori === null) {
          doc.setTextColor(180, 83, 9)
          doc.text('Elenco giocatori non disponibile: la richiesta alle API e\' fallita. Non consegnare questo documento.', 14, y)
          doc.setTextColor(0); y += 10
        } else if (!giocatori.length) {
          doc.setTextColor(110); doc.text('Nessun giocatore scelto.', 14, y)
          doc.setTextColor(0); y += 9
        } else {
          respira(42)
          doc.autoTable({
            head: [['N.', 'Cognome', 'Nome']],
            body: giocatori.map((g, i) => [i + 1, g.cognome || '–', g.nome || '–']),
            startY: y, theme: 'grid', margin: { left: 14, right: 14 }, tableWidth: 130,
            styles: { fontSize: 9, cellPadding: 2.5 },
            headStyles: { fillColor: [220, 38, 38], textColor: 255, fontStyle: 'bold', halign: 'center', fontSize: 9 },
            // larghezze fisse: lasciate a 'auto' le due colonne del nome si allargavano a tutta la
            // tabella, e un foglio con le colonne larghissime sembra compilato a caso
            columnStyles: { 0: { cellWidth: 12, halign: 'center' }, 1: { cellWidth: 60 }, 2: { cellWidth: 58 } },
            alternateRowStyles: { fillColor: [245, 245, 245] }
          })
          y = doc.lastAutoTable.finalY + 10
        }

        // Le gare senza categoria, o con una categoria non piu' iscritta: una sezione loro non ce
        // l'hanno, quindi qui tendono a sparire. Se l'export le tacesse, il documento consegnato
        // all'organizzatore sarebbe un calendario che ne mostra sei su otto: si stampano, etichettate
        const iscritte = new Set(categorieDel(t).map(c => String(c.id)))
        const orfane = tutte === null ? []
          : tutte.filter(g => !g.categoria_id || !iscritte.has(String(g.categoria_id)))
        if (tutte !== null && orfane.length && !orfaneStampate.has(t.id)) {
          orfaneStampate.add(t.id)
          respira(24)
          doc.setFontSize(9); doc.setFont(undefined, 'bold'); doc.setTextColor(180, 83, 9)
          doc.text(`Gare senza categoria (${orfane.length}) — da assegnare a una categoria`, 14, y)
          doc.setTextColor(0); doc.setFont(undefined, 'normal'); y += 4
          respira(42)
          doc.autoTable({
            head: [['N.', 'Avversario', 'Data', 'Inizio', 'Campo']],
            body: orfane.map(g => [
              g.numero || '–', g.avversario || 'Da definire', g.data ? formatoData(g.data) : '–',
              g.ora || '–', [g.campo, g.indirizzo].filter(Boolean).join(' — ') || '–'
            ]),
            startY: y, theme: 'grid', margin: { left: 14, right: 14 }, tableWidth: 200,
            styles: { fontSize: 8.5, cellPadding: 2.5 },
            headStyles: { fillColor: [180, 83, 9], textColor: 255, fontStyle: 'bold', halign: 'center', fontSize: 9 },
            columnStyles: { 0: { cellWidth: 10, halign: 'center' }, 2: { cellWidth: 24, halign: 'center' },
                            3: { cellWidth: 16, halign: 'center' } }
          })
          y = doc.lastAutoTable.finalY + 10
        }
      }
    }

    // Nomi file diversi per i tre livelli, perche' finiscono in una chat e "tornei.pdf" non dice
    // cosa c'e' dentro. I caratteri illegali li toglie sanitizeFilename dentro saveOrSharePdf; qui
    // si tolgono solo gli spazi e la punteggiatura, che rendono il nome illeggibile
    const pulito = s => String(s || '').replace(/[^\w]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase()
    const nomeFile = torneo
      ? `tornei_${pulito(torneo.nome)}_${pulito(`${sez.anno || ''} ${sez.nome || ''}`)}.pdf`
      : sez ? `tornei_${pulito(`${sez.anno || ''} ${sez.nome || ''}`)}.pdf`
            : 'tornei_tutte_categorie.pdf'
    const titolo = torneo ? `${torneo.nome} — ${sez.titolo}`
                          : sez ? `Tornei ${sez.titolo}` : 'Tornei — tutte le categorie'
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

@media (max-width: 560px) {
  .form-riga { flex-direction: column; gap: 0; }
  .modal { max-width: 100%; }
  .aggiungi-categoria { flex-direction: column; align-items: stretch; }
}
</style>