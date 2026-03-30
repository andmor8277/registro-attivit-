const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Serve uploaded files
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Configure multer for file uploads
const upload = multer({ storage: multer.memoryStorage() });

// Remove /api prefix from requests
app.use((req, res, next) => {
  if (req.path.startsWith('/api')) {
    req.url = req.url.slice(4);
  }
  next();
});

const DATA_FILE = path.join(__dirname, 'mock-data.json');
console.log('File dati:', DATA_FILE);

function loadData() {
  try {
    if (fs.existsSync(DATA_FILE)) {
      const raw = fs.readFileSync(DATA_FILE, 'utf8');
      return JSON.parse(raw);
    }
  } catch (e) {
    console.error('Errore nel caricamento dati:', e);
  }
  return getDefaultData();
}

function saveData(data) {
  try {
    console.log('Salvando dati in:', DATA_FILE);
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
    console.log('Dati salvati!');
  } catch (e) {
    console.error('Errore nel salvataggio dati:', e);
  }
}

function getDefaultData() {
  return {
    societa: [
      { id: 1, nome: 'RedTigers 1957', nome_breve: 'RedTigers', logo: '', logosponsor: '', colore_primario: '#dc2626', colore_secondario: '#1f2937', is_attiva: 1 }
    ],
    utenti: [
      { id: 1, username: 'admin', is_admin: true, is_super_admin: true, societa_id: 1, password: 'admin123', categorie_ids: null, nome: 'Admin', cognome: 'Sistema', data_nascita: '1990-01-01', codice_fiscale: 'ADMTTA90A01A000A', cellulare: '3331234567', tesserino: 'ADMIN001', ruolo: 'admin' },
      { id: 2, username: 'asergi', is_admin: true, is_super_admin: false, societa_id: 1, password: 'password', categorie_ids: null, nome: 'Alessandro', cognome: 'Sergi', data_nascita: '1985-06-15', codice_fiscale: 'SRGLSN85H15A000A', cellulare: '3332345678', tesserino: 'ASERGI01', ruolo: 'admin' },
      { id: 3, username: 'agrillo', is_admin: false, is_super_admin: false, societa_id: 1, password: 'password', categorie_ids: [1, 2], nome: 'Antonio', cognome: 'Grillo', data_nascita: '1980-03-22', codice_fiscale: 'GRLNTN80C22A000A', cellulare: '3333456789', tesserino: 'AGRILLO01', ruolo: 'mister' }
    ],
    categorie: [
      { id: 1, nome: 'Esordienti', anno: 2014, stagione: 2025, giorni: '1,2,4', is_portieri: 0, is_archiviata: 0 },
      { id: 2, nome: '2013', anno: 2013, stagione: 2025, giorni: '3,5', is_portieri: 0, is_archiviata: 0 }
    ],
    persone: [
      { id: 1, nome: 'Marco', cognome: 'Rossi', categoria_id: 1, gruppo_id: 1, gruppo_nome: 'PRIMO GRUPPO', data_nascita: '2014-03-15', codice_fiscale: 'RSSMRC14C15A000A', telefono: '3331111111', matricola: 'RT001' },
      { id: 2, nome: 'Luca', cognome: 'Bianchi', categoria_id: 1, gruppo_id: 1, gruppo_nome: 'PRIMO GRUPPO', data_nascita: '2014-07-22', codice_fiscale: 'BNCLCU14L22A000B', telefono: '3332222222', matricola: 'RT002' },
      { id: 3, nome: 'Anna', cognome: 'Verdi', categoria_id: 1, gruppo_id: 2, gruppo_nome: 'SECONDO GRUPPO', data_nascita: '2014-01-10', codice_fiscale: 'VRDNNN14A10A000C', telefono: '3333333333', matricola: 'RT003' },
      { id: 4, nome: 'Sara', cognome: 'Neri', categoria_id: 1, gruppo_id: 2, gruppo_nome: 'SECONDO GRUPPO', data_nascita: '2014-05-28', codice_fiscale: 'NRISRA14E28A000D', telefono: '3334444444', matricola: 'RT004' }
    ],
    registro: [],
    convocazioni: [],
    allenatori: [],
    allenamenti: []
  };
}

// Ricarica i dati ad ogni richiesta per development
function getData() {
  return loadData();
}

// Use a getter so we reload data on each request during development
let data = loadData();
const MOCK_TOKEN = 'mock-token-12345';

let nextId = Math.max(
  ...data.utenti.map(u => u.id),
  ...data.categorie.map(c => c.id),
  ...data.persone.map(p => p.id)
) + 1;
const genId = () => nextId++;

function getUtenti() { data = loadData(); return data.utenti; }
function getPersone() { data = loadData(); return data.persone; }
function getSocieta() { data = loadData(); return data.societa || []; }
function getRegistro() { data = loadData(); return data.registro; }
function getConvocazioni() { data = loadData(); return data.convocazioni; }
function getAllenatori() { data = loadData(); return data.allenatori || []; }
function getCodici() {
  return [
    { codice: 'X', tipo: 'presenza', descrizione: 'Presente' },
    { codice: 'AG', tipo: 'assenza', descrizione: 'Assente giustificato' },
    { codice: 'AI', tipo: 'assenza', descrizione: 'Assente ingiustificato' },
    { codice: 'P', tipo: 'extra', descrizione: 'Allen. Portieri' },
    { codice: 'R', tipo: 'extra', descrizione: 'Recupero altra cat.' }
  ];
}

// ============ AUTH ============
app.post('/auth/token', (req, res) => {
  console.log('Login request body:', req.body);
  const { username, password } = req.body;
  console.log('Username:', username, 'Password:', password);
  console.log('Utenti:', getUtenti().map(u => u.username + '/' + u.password));
  const user = getUtenti().find(u => u.username === username && u.password === password);
  if (user) {
    const { password: _, ...safeUser } = user;
    res.json({ access_token: MOCK_TOKEN + '-' + user.id, token_type: 'bearer', user: safeUser });
  } else {
    res.status(401).json({ detail: 'Credenziali non valide' });
  }
});

const userTokens = {};

app.get('/auth/me', (req, res) => {
  const auth = req.headers.authorization;
  console.log('Auth header:', auth);
  if (auth && auth.startsWith('Bearer ')) {
    const token = auth.replace('Bearer ', '');
    const parts = token.split('-');
    const userId = parseInt(parts[parts.length - 1]);
    console.log('Extracted userId:', userId);
    const user = getUtenti().find(u => u.id === userId);
    if (user) {
      const { password, ...safeUser } = user;
      res.json(safeUser);
    } else {
      console.log('User not found for id:', userId);
      res.status(401).json({ detail: 'Token non valido' });
    }
  } else {
    res.status(401).json({ detail: 'Non autenticato' });
  }
});

app.get('/auth/utenti', (req, res) => {
  // Ricarica i dati per avere le ultime modifiche
  data = loadData();
  let utenti = getUtenti();
  // Filtra per societa_id se specificato
  const societaId = req.query.societa_id;
  console.log('GET /auth/utenti - societaId richiesto:', societaId);
  console.log('Utenti totali:', utenti.length, utenti.map(u => ({id: u.id, username: u.username, societa_id: u.societa_id})));
  if (societaId) {
    utenti = utenti.filter(u => u.societa_id && u.societa_id === parseInt(societaId));
  }
  res.json(utenti.map(({ password, ...u }) => u));
});

app.post('/auth/utenti', (req, res) => {
  const newUser = {
    id: genId(),
    username: req.body.username,
    password: req.body.password,
    is_admin: (req.body.ruolo === 'admin' || req.body.ruolo === 'super_admin') ? 1 : 0,
    is_super_admin: req.body.is_super_admin || (req.body.ruolo === 'super_admin' ? 1 : 0),
    categorie_ids: [],
    nome: req.body.nome,
    cognome: req.body.cognome,
    data_nascita: req.body.data_nascita,
    codice_fiscale: req.body.codice_fiscale,
    cellulare: req.body.cellulare,
    tesserino: req.body.tesserino,
    ruolo: req.body.ruolo,
    societa_id: req.body.societa_id || null
  };
  data.utenti.push(newUser);
  saveData(data);
  res.json(newUser);
});

app.put('/auth/utenti/:id', (req, res) => {
  // Ricarica i dati prima dell'operazione
  data = loadData();
  const idx = data.utenti.findIndex(u => u.id === parseInt(req.params.id));
  if (idx >= 0) {
    data.utenti[idx].nome = req.body.nome;
    data.utenti[idx].cognome = req.body.cognome;
    data.utenti[idx].data_nascita = req.body.data_nascita;
    data.utenti[idx].codice_fiscale = req.body.codice_fiscale;
    data.utenti[idx].cellulare = req.body.cellulare;
    data.utenti[idx].tesserino = req.body.tesserino;
    data.utenti[idx].ruolo = req.body.ruolo;
    data.utenti[idx].is_admin = (req.body.ruolo === 'admin' || req.body.ruolo === 'super_admin') ? 1 : 0;
    if (req.body.is_super_admin !== undefined) {
      data.utenti[idx].is_super_admin = req.body.is_super_admin;
    }
    // Aggiorna societa_id se fornito
    console.log('PUT utenti - societa_id ricevuto:', req.body.societa_id, 'tipo:', typeof req.body.societa_id);
    if (req.body.societa_id !== undefined && req.body.societa_id !== null && req.body.societa_id !== '') {
      data.utenti[idx].societa_id = parseInt(req.body.societa_id);
    } else if (req.body.societa_id === '') {
      // Se è una stringa vuota, imposta a null
      data.utenti[idx].societa_id = null;
    }
    if (req.body.categorie_ids !== undefined) {
      data.utenti[idx].categorie_ids = req.body.categorie_ids;
    }
    saveData(data);
    console.log('Utente aggiornato:', data.utenti[idx]);
    res.json(data.utenti[idx]);
  } else {
    res.status(404).json({ detail: 'Utente non trovato' });
  }
});

app.delete('/auth/utenti/:id', (req, res) => {
  const id = parseInt(req.params.id);
  data.utenti = data.utenti.filter(u => u.id !== id);
  data.persone = data.persone.filter(p => p.utente_id !== id);
  saveData(data);
  res.json({ ok: true });
});

app.put('/auth/utenti/:id/reset-password', (req, res) => {
  const id = parseInt(req.params.id);
  const user = data.utenti.find(u => u.id === id);
  if (user) {
    user.password = 'password';
    saveData(data);
    res.json({ ok: true, message: 'Password resettata a "password"' });
  } else {
    res.status(404).json({ detail: 'Utente non trovato' });
  }
});

app.put('/auth/utenti/:id/password', (req, res) => {
  const id = parseInt(req.params.id);
  const { vecchia, nuova } = req.body;
  const user = data.utenti.find(u => u.id === id);
  if (user) {
    if (user.password !== vecchia) {
      res.status(400).json({ detail: 'Password attuale non corretta' });
    } else {
      user.password = nuova;
      saveData(data);
      res.json({ ok: true, message: 'Password cambiata con successo' });
    }
  } else {
    res.status(404).json({ detail: 'Utente non trovato' });
  }
});

app.put('/auth/utenti/:id/categorie', (req, res) => {
  const user = data.utenti.find(u => u.id === parseInt(req.params.id));
  if (user) {
    user.categorie_ids = req.body.categoria_ids;
    saveData(data);
    res.json({ ok: true });
  } else {
    res.status(404).json({ detail: 'Utente non trovato' });
  }
});

// ============ CATEGORIE ============
app.get('/categorie/', (req, res) => {
  // Ricarica i dati
  data = loadData();
  let cats = data.categorie.filter(c => !c.is_archiviata);
  // Filtra per societa_id se specificato
  // Mostra anche categorie senza societa_id (retrocompatibilità)
  const societaId = req.query.societa_id;
  console.log('GET /categorie - societaId richiesto:', societaId);
  if (societaId && societaId !== 'null' && societaId !== 'undefined') {
    const parsedId = parseInt(societaId);
    cats = cats.filter(c => !c.societa_id || c.societa_id === parsedId);
  }
  console.log('Categorie totali:', cats.length, cats.map(c => ({id: c.id, nome: c.nome, societa_id: c.societa_id})));
  res.json(cats);
});

app.get('/categorie/all', (req, res) => {
  // Ricarica i dati
  data = loadData();
  let cats = data.categorie.filter(c => !c.is_archiviata);
  // Filtra per societa_id se specificato
  // Mostra anche categorie senza societa_id (retrocompatibilità)
  const societaId = req.query.societa_id;
  if (societaId && societaId !== 'null' && societaId !== 'undefined') {
    const parsedId = parseInt(societaId);
    cats = cats.filter(c => !c.societa_id || c.societa_id === parsedId);
  }
  res.json(cats);
});

app.post('/categorie/', (req, res) => {
  const newCat = { id: genId(), ...req.body };
  data.categorie.push(newCat);
  saveData(data);
  res.json(newCat);
});

app.put('/categorie/:id', (req, res) => {
  const idx = data.categorie.findIndex(c => c.id === parseInt(req.params.id));
  if (idx >= 0) {
    data.categorie[idx] = { ...data.categorie[idx], ...req.body };
    saveData(data);
    res.json(data.categorie[idx]);
  } else {
    res.status(404).json({ detail: 'Categoria non trovata' });
  }
});

app.delete('/categorie/:id', (req, res) => {
  const id = parseInt(req.params.id);
  data.categorie = data.categorie.filter(c => c.id !== id);
  data.persone = data.persone.filter(p => p.categoria_id !== id);
  saveData(data);
  res.json({ ok: true });
});

app.post('/categorie/importa-giocatori/:nuovaCatId', (req, res) => {
  const nuovaCatId = parseInt(req.params.nuovaCatId);
  const nuovaCat = data.categorie.find(c => c.id === nuovaCatId);
  if (!nuovaCat) {
    return res.status(404).json({ detail: 'Categoria non trovata' });
  }
  
  let vecchie;
  if (nuovaCat.is_portieri) {
    vecchie = data.categorie.filter(c => c.is_portieri && c.is_archiviata && c.id !== nuovaCatId);
  } else {
    vecchie = data.categorie.filter(c => c.anno === nuovaCat.anno && !c.is_portieri && c.is_archiviata && c.id !== nuovaCatId);
  }
  
  if (!vecchie || vecchie.length === 0) {
    return res.json({ ok: true, giocatori_importati: 0, messaggio: 'Nessuna categoria precedente trovata' });
  }
  
  const vecchiaCat = vecchie[0];
  const giocatori = data.persone.filter(p => p.categoria_id === vecchiaCat.id);
  
  let importati = 0;
  giocatori.forEach(g => {
    const nuovoGiocatore = { ...g, id: genId(), categoria_id: nuovaCatId };
    delete nuovoGiocatore.utente_id;
    data.persone.push(nuovoGiocatore);
    importati++;
  });
  
  saveData(data);
  return res.json({ 
    ok: true, 
    giocatori_importati: importati, 
    messaggio: `Importati ${importati} giocatori dalla categoria '${vecchiaCat.nome}'` 
  });
});

app.get('/categorie/stagioni', (req, res) => {
  const attive = [...new Set(data.categorie.filter(c => !c.is_archiviata && c.stagione).map(c => c.stagione))].sort((a, b) => b - a);
  const archiviate = [...new Set(data.categorie.filter(c => c.is_archiviata && c.stagione).map(c => c.stagione))].sort((a, b) => b - a);
  res.json({ attiva: attive, archiviate: archiviate });
});

app.get('/categorie/archived', (req, res) => {
  res.json(data.categorie.filter(c => c.is_archiviata));
});

app.get('/categorie/by-stagione/:stagione', (req, res) => {
  const stagione = parseInt(req.params.stagione);
  const cats = data.categorie.filter(c => c.stagione === stagione);
  if (cats.length === 0) {
    res.status(404).json({ detail: 'Nessuna categoria per questa stagione' });
  } else {
    res.json(cats);
  }
});

app.post('/categorie/archivia/:stagione', (req, res) => {
  const stagione = parseInt(req.params.stagione);
  data.categorie.forEach(c => {
    if (c.stagione === stagione) c.is_archiviata = 1;
  });
  saveData(data);
  res.json({ ok: true, messaggio: `Stagione ${stagione}/${stagione+1} archiviata` });
});

app.post('/categorie/ripristina/:stagione', (req, res) => {
  const stagione = parseInt(req.params.stagione);
  data.categorie.forEach(c => {
    if (c.stagione === stagione) c.is_archiviata = 0;
  });
  saveData(data);
  res.json({ ok: true, messaggio: `Stagione ${stagione}/${stagione+1} ripristinata` });
});

app.get('/categorie/:id/utenti', (req, res) => {
  data = loadData();
  const catId = parseInt(req.params.id);
  const utentiIds = data.utenti.filter(u => u.categorie_ids && u.categorie_ids.includes(catId)).map(u => u.id);
  console.log('GET /categorie/:id/utenti - catId:', catId, 'utentiIds:', utentiIds);
  res.json(utentiIds);
});

app.put('/categorie/:id/utenti', (req, res) => {
  data = loadData();
  const catId = parseInt(req.params.id);
  const utenteIds = req.body.utente_ids || [];
  data.utenti.forEach(u => {
    if (u.is_admin) return;
    if (utenteIds.includes(u.id)) {
      if (!u.categorie_ids) u.categorie_ids = [];
      if (!u.categorie_ids.includes(catId)) {
        u.categorie_ids.push(catId);
      }
    } else {
      if (u.categorie_ids) {
        u.categorie_ids = u.categorie_ids.filter(id => id !== catId);
      }
    }
  });
  saveData(data);
  res.json({ ok: true });
});

app.get('/categorie/:id/responsabili', (req, res) => {
  data = loadData();
  const catId = parseInt(req.params.id);
  const responsabili = data.utenti.filter(u => 
    u.categorie_ids && u.categorie_ids.includes(catId) &&
    (u.ruolo === 'mister' || u.ruolo === 'dirigente')
  ).map(u => ({
    id: u.id,
    cognome: u.cognome,
    cellulare: u.cellulare,
    ruolo: u.ruolo
  }));
  console.log('GET /categorie/:id/responsabili - catId:', catId, 'responsabili:', responsabili);
  res.json(responsabili);
});

// ============ PERSONE ============
app.get('/persone/', (req, res) => {
  const catId = parseInt(req.query.categoria_id);
  if (catId) {
    res.json(getPersone().filter(p => p.categoria_id === catId));
  } else {
    res.json(getPersone());
  }
});

app.post('/persone/', (req, res) => {
  const newPersona = { id: genId(), ...req.body };
  data.persone.push(newPersona);
  saveData(data);
  res.json(newPersona);
});

app.put('/persone/:id', (req, res) => {
  const idx = data.persone.findIndex(p => p.id === parseInt(req.params.id));
  if (idx === -1) return res.status(404).json({ detail: 'Not found' });
  data.persone[idx] = { ...data.persone[idx], ...req.body };
  saveData(data);
  res.json(data.persone[idx]);
});

app.delete('/persone/:id', (req, res) => {
  data.persone = data.persone.filter(p => p.id !== parseInt(req.params.id));
  saveData(data);
  res.json({ ok: true });
});

// ============ CODICI ============
app.get('/codici/', (req, res) => {
  res.json(getCodici());
});

// ============ REGISTRO ============
app.get('/registro/mese/:categoriaId/:anno/:mese', (req, res) => {
  const { categoriaId } = req.params;
  res.json(getRegistro().filter(r => r.categoria_id === parseInt(categoriaId)));
});

app.post('/registro/', (req, res) => {
  const entry = req.body;
  const existingIdx = data.registro.findIndex(r => 
    r.persona_id === entry.persona_id && r.data === entry.data
  );
  
  if (existingIdx >= 0) {
    if (entry.codice) {
      data.registro[existingIdx] = entry;
    } else {
      data.registro.splice(existingIdx, 1);
    }
  } else if (entry.codice) {
    data.registro.push(entry);
  }
  
  saveData(data);
  res.json(entry);
});

// ============ CONVOCAZIONI ============
app.get('/convocazioni/', (req, res) => {
  const catId = parseInt(req.query.categoria_id);
  if (catId) {
    res.json(getConvocazioni().filter(c => c.categoria_id === catId));
  } else {
    res.json(getConvocazioni());
  }
});

app.get('/convocazioni/:id', (req, res) => {
  const conv = getConvocazioni().find(c => c.id === parseInt(req.params.id));
  if (conv) res.json(conv);
  else res.status(404).json({ detail: 'Non trovata' });
});

app.post('/convocazioni/', (req, res) => {
  const newConv = { id: genId(), ...req.body };
  data.convocazioni.push(newConv);
  saveData(data);
  res.json(newConv);
});

app.put('/convocazioni/:id', (req, res) => {
  const idx = data.convocazioni.findIndex(c => c.id === parseInt(req.params.id));
  if (idx >= 0) {
    data.convocazioni[idx] = { ...data.convocazioni[idx], ...req.body };
    saveData(data);
    res.json(data.convocazioni[idx]);
  } else {
    res.status(404).json({ detail: 'Non trovata' });
  }
});

app.delete('/convocazioni/:id', (req, res) => {
  data.convocazioni = data.convocazioni.filter(c => c.id !== parseInt(req.params.id));
  saveData(data);
  res.json({ ok: true });
});

// ============ ALLENATORI ============
app.get('/allenatori/', (req, res) => {
  const all = getAllenatori().sort((a, b) => a.cognome.localeCompare(b.cognome));
  res.json(all);
});

app.post('/allenatori/', (req, res) => {
  const newAllenatore = { id: genId(), cognome: req.body.cognome };
  data.allenatori.push(newAllenatore);
  saveData(data);
  res.json(newAllenatore);
});

app.put('/allenatori/:id', (req, res) => {
  const idx = data.allenatori.findIndex(a => a.id === parseInt(req.params.id));
  if (idx >= 0) {
    data.allenatori[idx].cognome = req.body.cognome;
    saveData(data);
    res.json(data.allenatori[idx]);
  } else {
    res.status(404).json({ detail: 'Allenatore non trovato' });
  }
});

app.delete('/allenatori/:id', (req, res) => {
  data.allenatori = data.allenatori.filter(a => a.id !== parseInt(req.params.id));
  saveData(data);
  res.json({ ok: true });
});

// ============ ALLENAMENTI ============
app.get('/allenamenti/', (req, res) => {
  const { categoria_id, week } = req.query;
  if (!data.allenamenti) data.allenamenti = [];
  const result = data.allenamenti.filter(a => 
    a.categoria_id === parseInt(categoria_id) && a.week === week
  );
  res.json(result);
});

app.post('/allenamenti/', (req, res) => {
  const { categoria_id, week, presenze } = req.body;
  if (!data.allenamenti) data.allenamenti = [];
  
  presenze.forEach(p => {
    const existingIdx = data.allenamenti.findIndex(a => 
      a.categoria_id === parseInt(categoria_id) && 
      a.week === week && 
      a.persona_id === p.persona_id && 
      a.giorno === p.giorno
    );
    
    if (existingIdx >= 0) {
      data.allenamenti[existingIdx] = { ...data.allenamenti[existingIdx], codice: p.codice };
    } else {
      data.allenamenti.push({
        id: genId(),
        categoria_id: parseInt(categoria_id),
        week,
        persona_id: p.persona_id,
        giorno: p.giorno,
        codice: p.codice
      });
    }
  });
  
  saveData(data);
  res.json({ ok: true });
});

// Societa endpoints
app.get('/societa/', (req, res) => {
  res.json(data.societa || []);
});

app.get('/societa/:id', (req, res) => {
  const s = (data.societa || []).find(s => s.id === parseInt(req.params.id));
  if (s) {
    res.json(s);
  } else {
    res.status(404).json({ detail: 'Società non trovata' });
  }
});

app.post('/societa/', (req, res) => {
  const maxId = Math.max(...(data.societa || []).map(s => s.id), 0);
  const newSocieta = { id: maxId + 1, ...req.body };
  if (!data.societa) data.societa = [];
  data.societa.push(newSocieta);
  saveData(data);
  res.json(newSocieta);
});

app.put('/societa/:id', (req, res) => {
  const idx = (data.societa || []).findIndex(s => s.id === parseInt(req.params.id));
  if (idx >= 0) {
    data.societa[idx] = { ...data.societa[idx], ...req.body };
    saveData(data);
    res.json(data.societa[idx]);
  } else {
    res.status(404).json({ detail: 'Società non trovata' });
  }
});

// Upload endpoint for societa logos
app.post('/societa/upload/:tipo', upload.single('file'), (req, res) => {
  const tipo = req.params.tipo;
  const filename = `${tipo}_${Date.now()}.png`;
  const uploadsDir = path.join(__dirname, 'uploads');
  
  // Create uploads dir if not exists
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }
  
  // Save the file
  if (req.file) {
    const filepath = path.join(uploadsDir, filename);
    fs.writeFileSync(filepath, req.file.buffer);
    console.log('File uploaded:', filepath);
  } else {
    console.log('No file uploaded, using placeholder');
  }
  
  res.json({ filename });
});

app.delete('/societa/:id', (req, res) => {
  const idx = (data.societa || []).findIndex(s => s.id === parseInt(req.params.id));
  if (idx >= 0) {
    data.societa.splice(idx, 1);
    saveData(data);
    res.json({ ok: true });
  } else {
    res.status(404).json({ detail: 'Società non trovata' });
  }
});

const PORT = 8000;
app.listen(PORT, () => {
  console.log(`\n🚀 Mock API Server running at http://localhost:${PORT}`);
  console.log(`📝 Login con: admin / admin123`);
  console.log(`💾 Dati salvati in: ${DATA_FILE}\n`);
});
