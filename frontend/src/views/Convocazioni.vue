<template>
  <div class="conv-page">
    <div class="toolbar">
      <button class="btn-back" @click="router.push('/scelta/' + route.params.id)">← Indietro</button>
      <button class="btn-back" @click="router.push('/')">🏠 Home</button>
      <span class="titolo-toolbar">Convocazioni — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
      <button class="btn-nuovo" @click="nuovaConvocazione">+ Nuovo Weekend</button>
    </div>

    <div class="conv-body">
      <!-- SIDEBAR SINISTRA -->
      <div class="left-sidebar">
        <!-- STORICO -->
        <div class="sidebar-section">
          <div class="sidebar-title">📅 Storico</div>
          <div v-for="c in storico" :key="c.id"
            :class="['storico-item', { attivo: convocazioneId === c.id }]"
            @click="caricaConvocazione(c.id)">
            {{ formatData(c.data_inizio) }}
          </div>
        </div>

        <!-- RESPONSABILI -->
        <div class="sidebar-section misters-section">
          <div class="sidebar-title">👥 Mister</div>
          <div v-for="r in responsabili" :key="r.id" class="mister-item">
            <span class="mister-cognome">{{ r.cognome }}</span>
            <span class="mister-tel">{{ r.cellulare }}</span>
          </div>
          <div v-if="responsabili.length === 0" class="empty-misters">
            Nessun mister assegnato
          </div>
        </div>
      </div>

      <!-- EDITOR -->
      <div class="editor" v-if="convocazione">
        <div class="editor-header">
          <div class="field-row">
            <label>Data weekend</label>
            <input type="date" v-model="convocazione.data_inizio" />
          </div>
          <div class="field-row">
            <label>Numero partite</label>
            <input type="number" min="1" max="7" v-model.number="numPartite" @change="aggiustaGare" style="width:60px" />
          </div>
          <div class="actions">
            <button class="btn-salva" @click="salva">💾 Salva</button>
            <button class="btn-del" @click="elimina">🗑 Elimina</button>
          </div>
        </div>

        <!-- GARE -->
        <div class="gare-scroll">
          <div class="gare-grid" :style="{ gridTemplateColumns: 'repeat(' + convocazione.gare.length + ', minmax(220px, 1fr))' }">
            <div v-for="(gara, gi) in convocazione.gare" :key="gi" class="gara-col">
              <div class="gara-header">GARA {{ gi + 1 }}</div>
              <div class="gara-fields">
                <div class="gf"><span>GARA</span><input v-model="gara.gara" /></div>
                <div class="gf"><span>DATA</span><input type="date" v-model="gara.data" /></div>
                <div class="gf"><span>CAMPO</span><input v-model="gara.campo" /></div>
                <div class="gf"><span>INDIRIZZO</span><input v-model="gara.indirizzo" /></div>
                <div class="gf"><span>APPUNTAMENTO</span><input v-model="gara.appuntamento" /></div>
                <div class="gf"><span>INIZIO GARA</span><input v-model="gara.inizio_gara" /></div>
                <div class="gf allenatore">
                  <span>MISTER / DIRIGENTE</span>
                  <select v-model="gara.allenatore">
                    <option value="">— Seleziona —</option>
                    <option v-for="r in responsabili" :key="r.id" :value="r.cognome">
                      {{ r.cognome }} - {{ r.cellulare }}
                    </option>
                  </select>
                </div>
              </div>
              <div class="giocatori-list">
                <div v-for="pos in 14" :key="pos" class="giocatore-row">
                  <span class="pos-num">{{ pos }}</span>
                  <select v-model="gara.giocatori[pos-1]">
                    <option :value="null">—</option>
                    <option v-for="p in getGiocatoriSettimanaPrecedente(gara.data)" :key="p.id" :value="p.id">{{ p.cognome }} {{ p.nome }}</option>
                  </select>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- NOTE -->
        <div class="note-section">
          <label>NOTE</label>
          <textarea v-model="convocazione.note" rows="3"></textarea>
        </div>
      </div>

      <div v-else class="empty-state">
        Seleziona un weekend dallo storico oppure crea una nuova convocazione.
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getPersone, getRegistroMese } from '../api/index.js'
import axios from 'axios'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva } = useStore()
const categoriaId = parseInt(route.params.id)

const base = '/api'
const token = () => localStorage.getItem('token')
const headers = () => ({ Authorization: 'Bearer ' + token() })

const storico = ref([])
const convocazioneId = ref(null)
const convocazione = ref(null)
const persone = ref([])
const responsabili = ref([])
const numPartite = ref(1)
const registro = ref([])

const oggi = new Date()
const annoCorrente = oggi.getFullYear()
const meseCorrente = oggi.getMonth() + 1

function getGiocatoriSettimanaPrecedente(dataGara) {
  if (!dataGara) return persone.value
  
  const data = new Date(dataGara)
  const startPrevWeek = new Date(data)
  startPrevWeek.setDate(data.getDate() - 7)
  const endPrevWeek = new Date(data)
  endPrevWeek.setDate(data.getDate() - 1)
  
  const startStr = startPrevWeek.toISOString().split('T')[0]
  const endStr = endPrevWeek.toISOString().split('T')[0]
  
  const presenzeCount = {}
  const assentiIds = new Set()
  
  registro.value
    .filter(r => r.data >= startStr && r.data <= endStr)
    .forEach(r => {
      if (['X', 'P', 'R'].includes(r.codice)) {
        presenzeCount[r.persona_id] = (presenzeCount[r.persona_id] || 0) + 1
      }
      if (['AI', 'AG'].includes(r.codice)) {
        assentiIds.add(r.persona_id)
      }
    })
  
  return persone.value.filter(p => presenzeCount[p.id] >= 2 && !assentiIds.has(p.id))
}

function aggiustaGare() {
  const n = numPartite.value
  const gare = convocazione.value.gare
  while (gare.length < n) gare.push(garaVuota(gare.length + 1))
  if (gare.length > n) gare.splice(n)
}

function formatData(d) {
  if (!d) return ''
  const [y, m, g] = d.split('-')
  return `${g}/${m}/${y}`
}

function garaVuota(numero) {
  return {
    numero,
    gara: '', data: '', campo: '', indirizzo: '',
    appuntamento: '', inizio_gara: '', allenatore: '',
    giocatori: Array(14).fill(null)
  }
}

function nuovaConvocazione() {
  convocazioneId.value = null
  numPartite.value = 1
  const oggi = new Date().toISOString().split('T')[0]
  convocazione.value = {
    data_inizio: oggi,
    note: 'NOTE | PRESENTARSI ALL\'APPUNTAMENTO IN ORARIO STABILITO ED IN TENUTA DA RAPPRESENTANZA GEMS (NO GIA CAMBIATI). SI GIOCA CON KIT GARA* (MAGLIA CALZONCINI E CALZETTONI) PORTARE FELPA D\'ALLENAMENTO PER RISCALDAMENTO E K-WAY IN BORSA PER L\'EVENIENZA. AVVISARE TEMPESTIVAMENTE L\'ALLENATORE PRESENTE IN GARA IN CASO DI RITARDO O ASSENZA. *PORTARE COMUNQUE MAGLIA DI RICAMBIO, CALZONCINI E CALZETTONI PER MODIFICARE I COLORI IN BASE ALL\'AVVERSARIO.',
    gare: [garaVuota(1)]
  }
}

async function caricaConvocazione(id) {
  convocazioneId.value = id
  const res = await axios.get(base + '/convocazioni/' + id, { headers: headers() })
  const d = res.data
  convocazione.value = {
    data_inizio: d.data_inizio,
    note: d.note || '',
    gare: d.gare.map(g => ({
      ...g,
      data: g.data || '',
      giocatori: Array.from({ length: 14 }, (_, i) => {
        const gk = g.giocatori.find(x => x.posizione === i + 1)
        return gk ? gk.persona_id : null
      })
    }))
  }
  numPartite.value = convocazione.value.gare.length
}

async function loadStorico() {
  const res = await axios.get(base + '/convocazioni/?categoria_id=' + categoriaId, { headers: headers() })
  storico.value = res.data
}

async function loadMisters() {
  try {
    const res = await axios.get(base + '/categorie/' + categoriaId + '/responsabili', { headers: headers() })
    responsabili.value = res.data
  } catch (e) {
    console.error('Errore caricamento responsabili:', e)
    responsabili.value = []
  }
}

async function salva() {
  const payload = {
    categoria_id: categoriaId,
    data_inizio: convocazione.value.data_inizio,
    note: convocazione.value.note,
    gare: convocazione.value.gare.map((g, gi) => ({
      numero: gi + 1,
      gara: g.gara, data: g.data || null, campo: g.campo,
      indirizzo: g.indirizzo, appuntamento: g.appuntamento,
      inizio_gara: g.inizio_gara, allenatore: g.allenatore,
      giocatori: g.giocatori
        .map((pid, i) => pid ? { persona_id: pid, posizione: i + 1 } : null)
        .filter(Boolean)
    }))
  }
  if (convocazioneId.value) {
    await axios.put(base + '/convocazioni/' + convocazioneId.value, payload, { headers: headers() })
  } else {
    const res = await axios.post(base + '/convocazioni/', payload, { headers: headers() })
    convocazioneId.value = res.data.id
  }
  await loadStorico()
  alert('Salvato!')
}

async function elimina() {
  if (!convocazioneId.value) return
  if (!confirm('Eliminare questa convocazione?')) return
  await axios.delete(base + '/convocazioni/' + convocazioneId.value, { headers: headers() })
  convocazione.value = null
  convocazioneId.value = null
  await loadStorico()
}

onMounted(async () => {
  const res = await getPersone(categoriaId)
  persone.value = res.data.sort((a, b) => a.cognome.localeCompare(b.cognome))
  const regRes = await getRegistroMese(categoriaId, annoCorrente, meseCorrente)
  registro.value = regRes.data
  await loadStorico()
  await loadMisters()
})
</script>

<style scoped>
.conv-page { display: flex; flex-direction: column; height: 100vh; }
.toolbar { display: flex; align-items: center; gap: 0.8rem; padding: 0.5rem 1rem; background: #8B0000; color: white; flex-shrink: 0; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 0.95rem; }
.btn-back { padding: 4px 12px; border-radius: 4px; border: 1px solid #555; background: #2a2a4a; color: white; cursor: pointer; }
.btn-nuovo { padding: 4px 14px; border-radius: 4px; border: none; background: #e94560; color: white; cursor: pointer; font-weight: bold; }
.conv-body { display: flex; flex: 1; overflow: hidden; }

.left-sidebar {
  width: 180px;
  flex-shrink: 0;
  background: #f5f5f5;
  border-right: 1px solid #ddd;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
}

.sidebar-section {
  padding: 0.75rem;
  border-bottom: 1px solid #ddd;
}

.sidebar-section:last-child {
  border-bottom: none;
  flex: 1;
}

.sidebar-title {
  font-weight: bold;
  font-size: 0.75rem;
  color: #555;
  margin-bottom: 0.5rem;
  padding-bottom: 0.3rem;
  border-bottom: 1px solid #ddd;
}

.storico-item { padding: 6px 8px; border-radius: 4px; cursor: pointer; font-size: 0.8rem; margin-bottom: 3px; }
.storico-item:hover { background: #e0e0e0; }
.storico-item.attivo { background: #CC0000; color: white; }

.misters-section { background: #fff8f8; }
.mister-item {
  background: white;
  border: 1px solid #eee;
  border-radius: 6px;
  padding: 8px 10px;
  margin-bottom: 6px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.mister-cognome { font-weight: 600; font-size: 0.85rem; color: #333; display: flex; align-items: center; gap: 4px; }
.badge-dir { font-size: 0.6rem; background: #2563eb; color: white; padding: 1px 4px; border-radius: 3px; font-weight: 700; }
.mister-tel { font-size: 0.75rem; color: #666; }
.empty-misters { font-size: 0.75rem; color: #aaa; text-align: center; padding: 0.5rem; }

.editor { flex: 1; overflow-y: auto; padding: 1rem; }
.editor-header { display: flex; align-items: center; gap: 1.5rem; flex-wrap: wrap; margin-bottom: 1rem; padding-bottom: 0.8rem; border-bottom: 2px solid #eee; }
.field-row { display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem; }
.field-row input { padding: 4px 8px; border: 1px solid #ddd; border-radius: 4px; }
.actions { display: flex; gap: 0.5rem; margin-left: auto; }
.btn-salva { padding: 6px 18px; background: #CC0000; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; }
.btn-del { padding: 6px 14px; background: #e94560; color: white; border: none; border-radius: 4px; cursor: pointer; }
.gare-scroll { overflow-x: auto; }
.gare-grid { display: grid; gap: 1rem; min-width: max-content; }
.gara-col { background: white; border: 1px solid #ddd; border-radius: 8px; overflow: hidden; min-width: 220px; }
.gara-header { background: #CC0000; color: white; text-align: center; font-weight: bold; padding: 6px; font-size: 0.9rem; }
.gara-fields { padding: 0.5rem; border-bottom: 2px solid #eee; }
.gf { display: flex; flex-direction: column; margin-bottom: 4px; }
.gf span { font-size: 0.65rem; color: #888; font-weight: bold; text-transform: uppercase; }
.gf input { border: 1px solid #eee; border-radius: 3px; padding: 3px 6px; font-size: 0.82rem; }
.gf select { border: 1px solid #eee; border-radius: 3px; padding: 3px 6px; font-size: 0.82rem; width: 100%; }
.gf.allenatore { background: #fffde7; padding: 4px; border-radius: 4px; }
.giocatori-list { padding: 0.5rem; }
.giocatore-row { display: flex; align-items: center; gap: 6px; margin-bottom: 3px; }
.pos-num { width: 18px; text-align: right; font-size: 0.8rem; color: #888; flex-shrink: 0; }
.giocatore-row select { flex: 1; font-size: 0.8rem; padding: 2px 4px; border: 1px solid #eee; border-radius: 3px; }
.note-section { margin-top: 1rem; }
.note-section label { font-size: 0.8rem; font-weight: bold; color: #555; display: block; margin-bottom: 4px; }
.note-section textarea { width: 100%; border: 1px solid #CC0000; border-radius: 4px; padding: 6px; font-size: 0.85rem; resize: vertical; background: #CC0000; color: white; font-weight: bold; }
.empty-state { flex: 1; display: flex; align-items: center; justify-content: center; color: #aaa; font-size: 1rem; }
</style>
