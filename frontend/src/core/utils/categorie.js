/**
 * Helper per identificare se una categoria è una categoria padre (es. Agonistica, Scuola Calcio)
 * e non una squadra/categoria operativa reale.
 */
export function isParentCategory(cat, allCats = []) {
  if (!cat) return false
  const name = (cat.nome || '').trim().toLowerCase()
  if (name === 'agonistica' || name === 'scuola calcio') return true
  if (cat.parent_id == null || cat.parent_id === undefined) {
    if (!cat.anno && !cat.is_portieri) return true
    if (Array.isArray(allCats) && allCats.length > 0 && allCats.some(c => c && c.parent_id === cat.id)) return true
  }
  return false
}
