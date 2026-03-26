const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Token fittizio per login
const MOCK_TOKEN = 'mock-token-12345';

// Utente admin mock
const mockUser = {
  id: 1,
  username: 'admin',
  is_admin: true,
  categorie_ids: null
};

// Utenti
let utenti = [
  { id: 1, username: 'admin', is_admin: true, password: 'admin123', categorie_ids: null },
  { id: 2, username: 'allenatore', is_admin: false, password: 'all123', categorie_ids: [1, 2] }
];

// Categorie
let categorie = [
  { id: 1, nome: 'Esordienti', anno: 2014, giorni: '2,4' },
  { id: 2, nome: 'Pulcini', anno: 2016, giorni: '3,5' },
  { id: 3, nome: 'Primi Calci', anno: 2018, giorni: '1' }
];

// Persone
let persone = [
  { id: 1, nome: 'Marco', cognome: 'Rossi', categoria_id: 1, gruppo_id: 1, gruppo_nome: 'PRIMO GRUPPO' },
  { id: 2, nome: 'Luca', cognome: 'Bianchi', categoria_id: 1, gruppo_id: 1, gruppo_nome: 'PRIMO GRUPPO' },
  { id: 3, nome: 'Anna', cognome: 'Verdi', categoria_id: 1, gruppo_id: 2, gruppo_nome: 'SECONDO GRUPPO' },
  { id: 4, nome: 'Sara', cognome: 'Neri', categoria_id: 1, gruppo_id: 2, gruppo_nome: 'SECONDO GRUPPO' }
];

// Registro presenze
let registro = [];

// Codici
const codici = [
  { codice: 'X', tipo: 'presenza', descrizione: 'Presente' },
  { codice: 'P', tipo: 'extra', descrizione: 'Presente con ritardo' },
  { codice: 'R', tipo: 'extra', descrizione: 'Recupero' },
  { codice: 'A', tipo: 'assenza', descrizione: 'Assente' },
  { codice: 'AG', tipo: 'assenza', descrizione: 'Assente per gadget' },
  { codice: 'AI', tipo: 'assenza', descrizione: 'Assente per infortunio' }
];

// Convocazioni
let convocazioni = [
  { id: 1, categoria_id: 1, titolo: 'Allenamento speciale', data: '2026-03-28', ora: '15:00', luogo: 'Campo A' }
];

// Utility per generare ID
let nextId = 100;
const genId = () => nextId++;

// ============ AUTH ============
app.post('/auth/token', (req, res) => {
  const { username, password } = req.body;
  const user = utenti.find(u => u.username === username && u.password === password);
  if (user) {
    res.json({ access_token: MOCK_TOKEN, token_type: 'bearer' });
  } else {
    res.status(401).json({ detail: 'Credenziali non valide' });
  }
});

app.get('/auth/me', (req, res) => {
  const auth = req.headers.authorization;
  if (auth === `Bearer ${MOCK_TOKEN}`) {
    const { password, ...safeUser } = utenti[0];
    res.json(safeUser);
  } else {
    res.status(401).json({ detail: 'Non autenticato' });
  }
});

app.get('/auth/utenti', (req, res) => {
  res.json(utenti.map(({ password, ...u }) => u));
});

app.post('/auth/utenti', (req, res) => {
  const newUser = { id: genId(), ...req.body, categorie_ids: [] };
  utenti.push(newUser);
  res.json(newUser);
});

app.delete('/auth/utenti/:id', (req, res) => {
  utenti = utenti.filter(u => u.id !== parseInt(req.params.id));
  res.json({ ok: true });
});

app.put('/auth/utenti/:id/categorie', (req, res) => {
  const user = utenti.find(u => u.id === parseInt(req.params.id));
  if (user) {
    user.categorie_ids = req.body.categorie_ids;
    res.json(user);
  } else {
    res.status(404).json({ detail: 'Utente non trovato' });
  }
});

// ============ CATEGORIE ============
app.get('/categorie/', (req, res) => {
  res.json(categorie);
});

app.post('/categorie/', (req, res) => {
  const newCat = { id: genId(), ...req.body };
  categorie.push(newCat);
  res.json(newCat);
});

app.put('/categorie/:id', (req, res) => {
  const idx = categorie.findIndex(c => c.id === parseInt(req.params.id));
  if (idx >= 0) {
    categorie[idx] = { ...categorie[idx], ...req.body };
    res.json(categorie[idx]);
  } else {
    res.status(404).json({ detail: 'Categoria non trovata' });
  }
});

app.delete('/categorie/:id', (req, res) => {
  categorie = categorie.filter(c => c.id !== parseInt(req.params.id));
  persone = persone.filter(p => p.categoria_id !== parseInt(req.params.id));
  res.json({ ok: true });
});

// ============ PERSONE ============
app.get('/persone/', (req, res) => {
  const catId = parseInt(req.query.categoria_id);
  if (catId) {
    res.json(persone.filter(p => p.categoria_id === catId));
  } else {
    res.json(persone);
  }
});

app.post('/persone/', (req, res) => {
  const newPersona = { id: genId(), ...req.body };
  persone.push(newPersona);
  res.json(newPersona);
});

app.delete('/persone/:id', (req, res) => {
  persone = persone.filter(p => p.id !== parseInt(req.params.id));
  res.json({ ok: true });
});

// ============ CODICI ============
app.get('/codici/', (req, res) => {
  res.json(codici);
});

// ============ REGISTRO ============
app.get('/registro/mese/:categoriaId/:anno/:mese', (req, res) => {
  const { categoriaId, anno, mese } = req.params;
  const filtered = registro.filter(r => 
    r.categoria_id === parseInt(categoriaId)
  );
  res.json(filtered);
});

app.post('/registro/', (req, res) => {
  const entry = req.body;
  const existingIdx = registro.findIndex(r => 
    r.persona_id === entry.persona_id && r.data === entry.data
  );
  
  if (existingIdx >= 0) {
    if (entry.codice) {
      registro[existingIdx] = entry;
    } else {
      registro.splice(existingIdx, 1);
    }
  } else if (entry.codice) {
    registro.push(entry);
  }
  
  res.json(entry);
});

// ============ CONVOCAZIONI ============
app.get('/convocazioni/', (req, res) => {
  const catId = parseInt(req.query.categoria_id);
  if (catId) {
    res.json(convocazioni.filter(c => c.categoria_id === catId));
  } else {
    res.json(convocazioni);
  }
});

app.get('/convocazioni/:id', (req, res) => {
  const conv = convocazioni.find(c => c.id === parseInt(req.params.id));
  if (conv) res.json(conv);
  else res.status(404).json({ detail: 'Non trovata' });
});

app.post('/convocazioni/', (req, res) => {
  const newConv = { id: genId(), ...req.body };
  convocazioni.push(newConv);
  res.json(newConv);
});

app.put('/convocazioni/:id', (req, res) => {
  const idx = convocazioni.findIndex(c => c.id === parseInt(req.params.id));
  if (idx >= 0) {
    convocazioni[idx] = { ...convocazioni[idx], ...req.body };
    res.json(convocazioni[idx]);
  } else {
    res.status(404).json({ detail: 'Non trovata' });
  }
});

app.delete('/convocazioni/:id', (req, res) => {
  convocazioni = convocazioni.filter(c => c.id !== parseInt(req.params.id));
  res.json({ ok: true });
});

const PORT = 8000;
app.listen(PORT, () => {
  console.log(`\n🚀 Mock API Server running at http://localhost:${PORT}`);
  console.log(`📝 Login con: admin / admin123\n`);
});
