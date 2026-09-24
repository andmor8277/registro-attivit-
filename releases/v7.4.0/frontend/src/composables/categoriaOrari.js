// Helper condivisi per giorni e orari di allenamento delle categorie.
// Convenzione giorno: JS getDay() -> 0=Domenica ... 6=Sabato (stessa di Categoria.giorni).

// Restituisce i giorni di allenamento della categoria come array di numeri (0-6).
export function giorniDi(cat) {
  if (!cat || !cat.giorni) return []
  return String(cat.giorni).split(',').map(Number).filter(n => !isNaN(n))
}

// La categoria allena nel giorno `dow` (0-6)?
export function catAllenaGiorno(cat, dow) {
  return giorniDi(cat).includes(dow)
}

// Orario di allenamento della categoria nel giorno `dow` (0-6).
// Usa l'orario specifico del giorno (orari_giorni) se presente, altrimenti il default (ora_allenamento).
export function oraPerGiorno(cat, dow) {
  if (!cat) return 'Senza orario'
  const map = cat.orari_giorni || {}
  const specifico = map[String(dow)]
  if (specifico) return specifico
  return cat.ora_allenamento || 'Senza orario'
}
