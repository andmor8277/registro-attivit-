<template>
  <div class="print-sheet" :style="{ zoom: scale }">
    <header class="sheet-header">
      <div class="sheet-brand">
        <img v-if="societa?.logo" :src="`/uploads/${societa.logo}`" alt="Logo" class="sheet-logo" />
        <div v-else class="sheet-logo sheet-logo-placeholder"></div>
        <div>
          <div class="sheet-societa">{{ societa?.nome || 'Società' }}</div>
          <div class="sheet-title">Registro presenze</div>
        </div>
      </div>
      <div class="sheet-meta">
        <span><small>Categoria</small> <strong>{{ categoria?.nome || '—' }}</strong></span>
        <span><small>Stagione</small> <strong>{{ categoria?.anno || '—' }}</strong></span>
        <span><small>Periodo</small> <strong>{{ meseLabel }} {{ anno }}</strong></span>
      </div>
    </header>

    <table class="sheet-table">
      <thead>
        <tr>
          <th class="col-num">#</th>
          <th class="col-nome">Cognome Nome</th>
          <th v-for="g in giorni" :key="g.num" class="col-day">
            <span>{{ g.num }}</span>
            <small>{{ g.gg }}</small>
          </th>
          <th class="col-tot">Tot</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(persona, idx) in persone" :key="persona.id">
          <td class="col-num">{{ idx + 1 }}</td>
          <td class="col-nome">
            {{ persona.cognome }} {{ persona.nome }}
            <span v-if="isPortieri && persona.categoria_nome" class="cat-tag">{{ persona.categoria_nome }}</span>
          </td>
          <td v-for="g in giorni" :key="g.num" class="col-day cell">
            <span v-if="tipo === 'corrente'">{{ getCodice(persona.id, g.num) }}</span>
          </td>
          <td class="col-tot">
            <span v-if="tipo === 'corrente'">{{ totalePresenze(persona.id) }}</span>
          </td>
        </tr>
        <tr v-for="n in 6" :key="`riga-vuota-${n}`" class="row-extra">
          <td class="col-num"></td>
          <td class="col-nome"></td>
          <td v-for="g in giorni" :key="g.num" class="col-day cell"></td>
          <td class="col-tot"></td>
        </tr>
      </tbody>
      <tfoot v-if="tipo === 'corrente'">
        <tr>
          <td></td>
          <td class="col-nome">Presenti</td>
          <td v-for="g in giorni" :key="g.num">{{ totaliGiorno[g.num]?.pres || '' }}</td>
          <td></td>
        </tr>
      </tfoot>
    </table>

    <footer class="sheet-footer">
      <div class="signature">
        <span>Firma allenatore / responsabile</span>
        <i></i>
      </div>
      <div class="signature">
        <span>Data</span>
        <i></i>
      </div>
    </footer>
  </div>
</template>

<script setup>
defineProps({
  societa: { type: Object, default: null },
  categoria: { type: Object, default: null },
  meseLabel: { type: String, default: '' },
  anno: { type: Number, default: new Date().getFullYear() },
  persone: { type: Array, default: () => [] },
  giorni: { type: Array, default: () => [] },
  codici: { type: Array, default: () => [] },
  tipo: { type: String, default: 'vuoto' },
  isPortieri: { type: Boolean, default: false },
  getCodice: { type: Function, required: true },
  totalePresenze: { type: Function, required: true },
  totaliGiorno: { type: Object, default: () => ({}) },
  scale: { type: Number, default: 1 }
})
</script>

<style scoped>
.print-sheet {
  background: #fff;
  color: #111;
  width: 194mm;
  box-sizing: border-box;
  padding: 3mm;
  font-family: var(--font-sans, 'Schibsted Grotesk', system-ui, sans-serif);
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

.sheet-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 4mm;
  padding-bottom: 2.5mm;
  margin-bottom: 3mm;
  border-bottom: 1.5pt solid #111;
}

.sheet-brand {
  display: flex;
  align-items: center;
  gap: 3mm;
}

.sheet-logo {
  width: 10mm;
  height: 10mm;
  object-fit: contain;
  border-radius: 1.5mm;
  border: 0.5pt solid #e5e7eb;
}

.sheet-logo-placeholder {
  background: #f3f4f6;
}

.sheet-societa {
  font-size: 7.5pt;
  font-weight: 700;
  color: #555;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.sheet-title {
  font-size: 12pt;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.1;
}

.sheet-meta {
  display: flex;
  align-items: center;
  flex-wrap: nowrap;
  gap: 5mm;
  text-align: right;
  white-space: nowrap;
}

.sheet-meta span {
  display: inline-flex;
  align-items: baseline;
  gap: 1.5mm;
  font-size: 8.5pt;
  color: #111;
}

.sheet-meta small {
  font-size: 6.5pt;
  font-weight: 700;
  color: #777;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.sheet-meta strong {
  font-size: 8.5pt;
  font-weight: 800;
  color: #111;
}

.sheet-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 7.5pt;
}

.sheet-table thead {
  display: table-header-group;
}

.sheet-table tr {
  page-break-inside: avoid;
}

.sheet-table th {
  background: #111;
  color: #fff;
  border: 0.5pt solid #111;
  padding: 1.2mm 1.5mm;
  font-size: 6.5pt;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  text-align: center;
}

.sheet-table th.col-nome,
.sheet-table td.col-nome {
  text-align: left;
}

.sheet-table td {
  border: 0.5pt solid #d4d4d4;
  padding: 0.8mm 1.5mm;
  text-align: center;
  vertical-align: middle;
}

.sheet-table tbody tr:nth-child(even) td {
  background: #f7f7f5;
}

.col-num {
  width: 7mm;
  color: #777;
  font-size: 6.5pt;
  font-weight: 600;
}

.col-nome {
  min-width: 36mm;
  font-weight: 600;
}

.cat-tag {
  display: inline-block;
  margin-left: 2mm;
  padding: 0.4mm 1.5mm;
  border: 0.5pt solid #9ca3af;
  border-radius: 1mm;
  font-size: 6.5pt;
  color: #555;
  font-weight: 700;
}

.col-day {
  width: 7mm;
  min-width: 7mm;
}

.col-day small {
  display: block;
  font-size: 5.5pt;
  color: #d4d4d4;
  text-transform: uppercase;
}

.sheet-table td.col-day small,
.sheet-table td.col-day span {
  color: inherit;
}

.cell {
  height: 5.5mm;
}

.row-extra td {
  height: 6mm;
}

.col-tot {
  width: 9mm;
  font-family: var(--font-mono, monospace);
  font-weight: 700;
}

.sheet-table tfoot td {
  background: #f3f4f6 !important;
  border-top: 1pt solid #111;
  font-weight: 800;
}

.sheet-footer {
  display: flex;
  justify-content: space-between;
  margin-top: 6mm;
  font-size: 7pt;
  color: #333;
}

.signature {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.5mm;
  width: 46mm;
}

.signature i {
  display: block;
  width: 100%;
  height: 6mm;
  border-bottom: 0.75pt solid #111;
}
</style>

<style>
.print-root {
  display: none;
}

@media print {
  @page {
    size: A4 portrait;
    margin: 8mm;
  }

  html,
  body {
    margin: 0 !important;
    padding: 0 !important;
    background: #fff !important;
  }

  body > *:not(.print-root) {
    display: none !important;
  }

  .print-root {
    display: block !important;
  }
}
</style>