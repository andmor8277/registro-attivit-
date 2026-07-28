<template>
  <div class="spogliatoi-page" @click="chiudiCampoMenu">
    <div class="print-header">
      <h1>Gestione Spogliatoi e Campi da gioco — {{ societaAttiva?.nome || '' }}</h1>
      <p v-if="tabAttivo === 'settimanale'">Settimana {{ formatDate(settimanaInizio) }} - {{ formatDate(settimanaFine) }}</p>
      <p v-else-if="weekendSelezionatoId">{{ getWeekendLabel() }}</p>
    </div>
    <header class="page-header">
      <div class="header-content">
        <button class="btn-back" @click="router.push('/responsabili')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <div>
          <h1>Gestione Spogliatoi e Campi da gioco</h1>
          <p class="page-subtitle">Assegnazione settimanale e weekend</p>
        </div>
      </div>
    </header>

    <div class="tabs-bar">
      <button class="tab-btn" :class="{ active: tabAttivo === 'settimanale' }" @click="tabAttivo = 'settimanale'">Settimanale</button>
      <button class="tab-btn" :class="{ active: tabAttivo === 'default' }" @click="tabAttivo = 'default'">Settimana Tipo</button>
      <button class="tab-btn" :class="{ active: tabAttivo === 'weekend' }" @click="tabAttivo = 'weekend'">Weekend</button>
    </div>

    <!-- SETTIMANALE TAB -->
    <div v-if="tabAttivo === 'settimanale'">
      <div class="week-selector">
        <button class="btn-nav" @click="cambiaSettimana(-1)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>
        <span class="week-label">Settimana {{ formatDate(settimanaInizio) }} - {{ formatDate(settimanaFine) }}</span>
        <button class="btn-nav" @click="cambiaSettimana(1)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <polyline points="9 18 15 12 9 6"/>
          </svg>
        </button>
        <button class="btn-save" @click="salvaAssegnazioniSettimana">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
          Salva
        </button>
        <button class="btn-default-apply" @click="applicaSettimanaTipo" :disabled="!haSettimanaTipo">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <path d="M12 5v14M5 12h14"/>
          </svg>
          Applica Settimana Tipo
        </button>
        <button class="btn-save" @click="stampaGiornoSingolo(giornoAttivo)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <polyline points="6 9 6 2 18 2 18 9"/>
            <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
            <rect x="6" y="14" width="12" height="8"/>
          </svg>
          Stampa Giorno
        </button>
        <button class="btn-save" @click="stampa">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <polyline points="6 9 6 2 18 2 18 9"/>
            <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
            <rect x="6" y="14" width="12" height="8"/>
          </svg>
          Stampa Settimana
        </button>
      </div>

      <!-- Day tabs -->
      <div class="day-tabs" v-if="giorniSettimana.length > 0">
        <button v-for="g in giorniSettimana" :key="g.data" class="day-tab" :class="{ active: giornoAttivo === g.data, empty: g.categorie.length === 0 }" @click="selezionaGiorno(g.data)">
          <span class="day-name">{{ g.nomeBreve }}</span>
          <span class="day-date">{{ g.giorno }}</span>
          <span class="day-count" v-if="g.categorie.length > 0">{{ g.categorie.length }}</span>
        </button>
      </div>

      <div v-if="giornoAttivo" class="day-view">
        <div v-if="getCategorieGiorno(giornoAttivo).length === 0" class="empty-state">
          <p>Nessuna categoria si allena questo giorno</p>
        </div>
        <template v-else>
          <div v-for="(slot, ora) in categoriePerOrario(giornoAttivo)" :key="ora" class="time-slot-section">
            <div class="time-slot-header">{{ ora || 'Senza orario' }}</div>
            <div class="assegnazioni-table">
              <div class="table-header">
                <div class="col-cat">Categoria</div>
                <div class="col-spo">Spogliatoio</div>
                <div class="col-campo">Campo da gioco</div>
              </div>
              <div v-for="cat in slot" :key="'s-' + cat.id" class="table-row">
                <div class="col-cat">
                  <span class="cat-anno">{{ cat.anno }}</span>
                  <span class="cat-nome">{{ cat.nome }}</span>
                </div>
                <div class="col-spo multi-select">
                  <div v-for="item in spogliatoi" :key="item.id"
                       class="select-chip"
                       :class="{
                         active: getAssegnazioneSpogliatoioGiorno(cat.id, item.id, giornoAttivo),
                         occupied: isSpogliatoioOccupatoFascia(cat.id, item.id, giornoAttivo)
                       }"
                       @click="!isSpogliatoioOccupatoFascia(cat.id, item.id, giornoAttivo) && toggleAssegnazioneSpogliatoioGiorno(cat.id, item.id, giornoAttivo)">
                    {{ item.etichetta }}
                  </div>
                  <span v-if="spogliatoi.length === 0" class="no-items">Nessuno disponibile</span>
                </div>
                <div class="col-campo multi-select">
                  <div v-for="item in campi" :key="item.id" class="campo-menu-wrapper">
                    <div class="select-chip campo-chip-main"
                         :class="{
                           active: getCampoAssegnato(cat.id, item.id, giornoAttivo),
                           occupied: isCampoTuttoOccupatoFascia(cat.id, item.id, giornoAttivo) && !getCampoAssegnato(cat.id, item.id, giornoAttivo)
                         }"
                         @click.stop="toggleCampoMenu(cat.id, item.id, giornoAttivo)">
                       {{ item.etichetta }}{{ getCampoLabelSuffisso(cat.id, item.id, giornoAttivo) }}
                       <svg v-if="getCampoMenuOpzioni(item).length > 1" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="10" height="10">
                         <polyline points="6 9 12 15 18 9"/>
                       </svg>
                     </div>
                     <div v-if="campoMenuAperto === `${cat.id}_${item.id}_${giornoAttivo}`" class="campo-dropdown" @click.stop>
                       <div v-for="opt in getCampoMenuOpzioni(item)" :key="opt.metacampo || 'full'"
                            class="campo-dropdown-item"
                            :class="{
                              active: getCampoAssegnato(cat.id, item.id, giornoAttivo) === (opt.metacampo || 'FULL'),
                              disabled: isCampoOccupatoFascia(cat.id, item.id, giornoAttivo, opt.metacampo) && getCampoAssegnato(cat.id, item.id, giornoAttivo) !== (opt.metacampo || 'FULL')
                            }"
                            @click="!isCampoOccupatoFascia(cat.id, item.id, giornoAttivo, opt.metacampo) || getCampoAssegnato(cat.id, item.id, giornoAttivo) === (opt.metacampo || 'FULL') ? assegnaCampoDaMenu(cat.id, item.id, giornoAttivo, opt.metacampo) : null">
                         {{ opt.label }}
                       </div>
                       <div v-if="getCampoAssegnato(cat.id, item.id, giornoAttivo)" class="campo-dropdown-item rimuovi" @click="assegnaCampoDaMenu(cat.id, item.id, giornoAttivo, getCampoAssegnato(cat.id, item.id, giornoAttivo) === 'FULL' ? null : getCampoAssegnato(cat.id, item.id, giornoAttivo))">
                         Rimuovi
                       </div>
                     </div>
                   </div>
                  <span v-if="campi.length === 0" class="no-items">Nessuno disponibile</span>
                </div>
              </div>
               <!-- Non censite rows -->
                <div v-for="(squadra, fidx) in squadreNonCensiteSettimanali.filter(s => s.ora === ora && s.dataGiorno === giornoAttivo)" :key="'nc-s-' + squadra.id" class="table-row non-censite-row">
                  <div class="col-cat non-censita-cell">
                    <span class="print-team-name">{{ squadra.nome || 'Squadra non censita' }}</span>
                    <input type="text" v-model="squadra.nome" placeholder="Nome squadra" class="non-censita-input" />
                    <button class="btn-rimuovi-squadra" @click.stop="rimuoviSquadraNonCensita(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), 'settimanale')" title="Rimuovi">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                      </svg>
                    </button>
                  </div>
                  <div class="col-spo multi-select">
                    <div v-for="item in spogliatoi" :key="item.id"
                         class="select-chip"
                         :class="{
                           active: getAssegnazioneSpogliatoioNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo),
                           occupied: isSpogliatoioOccupatoNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo)
                         }"
                         @click="!isSpogliatoioOccupatoNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo) && toggleAssegnazioneSpogliatoioNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo)">
                      {{ item.etichetta }}
                    </div>
                    <span v-if="spogliatoi.length === 0" class="no-items">Nessuno disponibile</span>
                  </div>
                  <div class="col-campo multi-select">
                    <div v-for="item in campi" :key="item.id" class="campo-menu-wrapper">
                      <div class="select-chip campo-chip-main"
                           :class="{
                             active: getCampoAssegnatoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo),
                             occupied: isCampoTuttoOccupatoNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo) && !getCampoAssegnatoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo)
                           }"
                           @click.stop="toggleCampoMenuNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo)">
                         {{ item.etichetta }}{{ getCampoLabelSuffissoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo) }}
                         <svg v-if="getCampoMenuOpzioni(item).length > 1" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="10" height="10">
                           <polyline points="6 9 12 15 18 9"/>
                         </svg>
                       </div>
                       <div v-if="campoMenuAperto === `nc_${squadra.id}_${item.id}_${giornoAttivo}`" class="campo-dropdown" @click.stop>
                         <div v-for="opt in getCampoMenuOpzioni(item)" :key="opt.metacampo || 'full'"
                              class="campo-dropdown-item"
                              :class="{
                                active: getCampoAssegnatoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo) === (opt.metacampo || 'FULL'),
                                disabled: isCampoOccupatoNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo, opt.metacampo) && getCampoAssegnatoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo) !== (opt.metacampo || 'FULL')
                              }"
                              @click="!isCampoOccupatoNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo, opt.metacampo) || getCampoAssegnatoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo) === (opt.metacampo || 'FULL') ? assegnaCampoDaMenuNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo, opt.metacampo) : null">
                           {{ opt.label }}
                         </div>
                         <div v-if="getCampoAssegnatoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo)" class="campo-dropdown-item rimuovi" @click="assegnaCampoDaMenuNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo, getCampoAssegnatoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo) === 'FULL' ? null : getCampoAssegnatoNC(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, giornoAttivo))">
                           Rimuovi
                         </div>
                       </div>
                     </div>
                    <span v-if="campi.length === 0" class="no-items">Nessuno disponibile</span>
                  </div>
                </div>
              <div class="table-row add-row">
                <div class="col-cat">
                  <button class="btn-add-squadra" @click="aggiungiSquadraNonCensita('settimanale', ora)">+ Squadra non censita</button>
                </div>
                <div class="col-spo"></div>
                <div class="col-campo"></div>
              </div>
            </div>
          </div>
        </template>
      </div>
      <div v-else class="empty-state">
        <p>Crea almeno uno spogliatoio o un campo per iniziare</p>
      </div>

      <!-- Print-only: all days -->
      <div class="print-all-days">
        <div v-for="g in giorniSettimana" :key="'print-' + g.data" class="print-day-section">
          <div class="print-day-header">{{ g.nomeLungo }} {{ g.giorno }} - {{ getCategorieGiorno(g.data).length }} categorie</div>
          <div v-for="(slot, ora) in categoriePerOrario(g.data)" :key="'print-slot-' + g.data + '-' + ora" class="print-slot-wrapper">
            <div class="print-time-slot">{{ ora || 'Senza orario' }}</div>
            <div class="assegnazioni-table">
              <div class="table-header">
                <div class="col-cat">Categoria</div>
                <div class="col-spo">Spogliatoio</div>
                <div class="col-campo">Campo da gioco</div>
              </div>
               <div v-for="cat in slot" :key="'ps-' + cat.id" class="table-row">
                 <div class="col-cat">
                   <span class="cat-anno">{{ cat.anno }}</span>
                   <span class="cat-nome">{{ cat.nome }}</span>
                 </div>
                 <div class="col-spo print-chips">
                   <template v-for="item in spogliatoi" :key="item.id">
                     <span v-if="getAssegnazioneSpogliatoioGiorno(cat.id, item.id, g.data)" class="print-chip spo-chip">{{ item.etichetta }}</span>
                   </template>
                   <span v-if="spogliatoi.length === 0" class="no-items">—</span>
                 </div>
                  <div class="col-campo print-chips">
                    <template v-for="item in campi" :key="item.id">
                      <span v-if="getAssegnazioneCampoGiorno(cat.id, item.id, g.data)" class="print-chip campo-chip">{{ item.etichetta }}</span>
                      <span v-if="getAssegnazioneCampoGiorno(cat.id, item.id, g.data, 'A')" class="print-chip campo-chip">{{ item.etichetta }} A</span>
                      <span v-if="getAssegnazioneCampoGiorno(cat.id, item.id, g.data, 'B')" class="print-chip campo-chip">{{ item.etichetta }} B</span>
                    </template>
                    <span v-if="campi.length === 0" class="no-items">—</span>
                  </div>
               </div>
                <div v-for="(squadra, fidx) in squadreNonCensiteSettimanali.filter(s => s.ora === ora && s.dataGiorno === g.data)" :key="'pnc-' + squadra.id" class="table-row non-censite-row">
                 <div class="col-cat non-censita-cell">
                   <span class="print-team-name">{{ squadra.nome || 'Squadra non censita' }}</span>
                 </div>
                 <div class="col-spo print-chips">
                   <template v-for="item in spogliatoi" :key="item.id">
                     <span v-if="getAssegnazioneSpogliatoioNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, g.data)" class="print-chip spo-chip">{{ item.etichetta }}</span>
                   </template>
                 </div>
                  <div class="col-campo print-chips">
                    <template v-for="item in campi" :key="item.id">
                      <span v-if="getAssegnazioneCampoNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, g.data)" class="print-chip campo-chip">{{ item.etichetta }}</span>
                      <span v-if="getAssegnazioneCampoNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, g.data, 'A')" class="print-chip campo-chip">{{ item.etichetta }} A</span>
                      <span v-if="getAssegnazioneCampoNonCensitaGiorno(getNonCensitaGlobalIdx(squadreNonCensiteSettimanali, squadra), item.id, g.data, 'B')" class="print-chip campo-chip">{{ item.etichetta }} B</span>
                    </template>
                  </div>
               </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- SETTIMANA TIPO TAB -->
    <div v-if="tabAttivo === 'default'">
      <div class="week-selector">
        <span class="week-label">📋 Settimana Tipo — Modello predefinito</span>
        <button class="btn-save" @click="salvaAssegnazioniDefault">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
          Salva Modello
        </button>
      </div>
      <div class="default-info-banner">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>
        </svg>
        <span>Configura qui il modello settimanale. Poi dalla tabella "Settimanale" puoi applicarlo a qualsiasi settimana.</span>
      </div>

      <!-- Day tabs -->
      <div class="day-tabs" v-if="giorniDefault.length > 0">
        <button v-for="g in giorniDefault" :key="g.data" class="day-tab" :class="{ active: giornoDefaultAttivo === g.data, empty: g.categorie.length === 0 }" @click="giornoDefaultAttivo = g.data">
          <span class="day-name">{{ g.nomeBreve }}</span>
          <span class="day-date">{{ g.giorno }}</span>
          <span class="day-count" v-if="g.categorie.length > 0">{{ g.categorie.length }}</span>
        </button>
      </div>

      <div v-if="giornoDefaultAttivo" class="day-view">
        <div v-if="getCategorieGiorno(giornoDefaultAttivo).length === 0" class="empty-state">
          <p>Nessuna categoria si allena questo giorno</p>
        </div>
        <template v-else>
          <div v-for="(slot, ora) in categoriePerOrario(giornoDefaultAttivo)" :key="ora" class="time-slot-section">
            <div class="time-slot-header">{{ ora || 'Senza orario' }}</div>
            <div class="assegnazioni-table">
              <div class="table-header">
                <div class="col-cat">Categoria</div>
                <div class="col-spo">Spogliatoio</div>
                <div class="col-campo">Campo da gioco</div>
              </div>
              <div v-for="cat in slot" :key="'d-s-' + cat.id" class="table-row">
                <div class="col-cat">
                  <span class="cat-anno">{{ cat.anno }}</span>
                  <span class="cat-nome">{{ cat.nome }}</span>
                </div>
                <div class="col-spo multi-select">
                  <div v-for="item in spogliatoi" :key="item.id"
                       class="select-chip"
                       :class="{
                         active: getAssegnazioneSpogliatoioDefault(cat.id, item.id, giornoDefaultAttivo),
                         occupied: isSpogliatoioOccupatoDefault(cat.id, item.id, giornoDefaultAttivo)
                       }"
                       @click="!isSpogliatoioOccupatoDefault(cat.id, item.id, giornoDefaultAttivo) && toggleAssegnazioneSpogliatoioDefault(cat.id, item.id, giornoDefaultAttivo)">
                    {{ item.etichetta }}
                  </div>
                  <span v-if="spogliatoi.length === 0" class="no-items">Nessuno disponibile</span>
                </div>
                <div class="col-campo multi-select">
                  <div v-for="item in campi" :key="item.id" class="campo-menu-wrapper">
                    <div class="select-chip campo-chip-main"
                         :class="{
                           active: getCampoAssegnatoDefault(cat.id, item.id, giornoDefaultAttivo),
                           occupied: isCampoTuttoOccupatoDefault(cat.id, item.id, giornoDefaultAttivo) && !getCampoAssegnatoDefault(cat.id, item.id, giornoDefaultAttivo)
                         }"
                         @click.stop="toggleCampoMenuDefault(cat.id, item.id, giornoDefaultAttivo)">
                      {{ item.etichetta }}{{ getCampoLabelSuffissoDefault(cat.id, item.id, giornoDefaultAttivo) }}
                      <svg v-if="getCampoMenuOpzioni(item).length > 1" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="10" height="10">
                        <polyline points="6 9 12 15 18 9"/>
                      </svg>
                    </div>
                    <div v-if="campoMenuDefaultAperto === `${cat.id}_${item.id}_${giornoDefaultAttivo}`" class="campo-dropdown" @click.stop>
                      <div v-for="opt in getCampoMenuOpzioni(item)" :key="opt.metacampo || 'full'"
                           class="campo-dropdown-item"
                           :class="{
                             active: getCampoAssegnatoDefault(cat.id, item.id, giornoDefaultAttivo) === (opt.metacampo || 'FULL'),
                             disabled: isCampoOccupatoDefault(cat.id, item.id, giornoDefaultAttivo, opt.metacampo) && getCampoAssegnatoDefault(cat.id, item.id, giornoDefaultAttivo) !== (opt.metacampo || 'FULL')
                           }"
                           @click="!isCampoOccupatoDefault(cat.id, item.id, giornoDefaultAttivo, opt.metacampo) || getCampoAssegnatoDefault(cat.id, item.id, giornoDefaultAttivo) === (opt.metacampo || 'FULL') ? assegnaCampoDaMenuDefault(cat.id, item.id, giornoDefaultAttivo, opt.metacampo) : null">
                        {{ opt.label }}
                      </div>
                      <div v-if="getCampoAssegnatoDefault(cat.id, item.id, giornoDefaultAttivo)" class="campo-dropdown-item rimuovi" @click="assegnaCampoDaMenuDefault(cat.id, item.id, giornoDefaultAttivo, getCampoAssegnatoDefault(cat.id, item.id, giornoDefaultAttivo) === 'FULL' ? null : getCampoAssegnatoDefault(cat.id, item.id, giornoDefaultAttivo))">
                        Rimuovi
                      </div>
                    </div>
                  </div>
                  <span v-if="campi.length === 0" class="no-items">Nessuno disponibile</span>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>
    </div>

    <!-- WEEKEND TAB -->
    <div v-if="tabAttivo === 'weekend'">
      <div class="weekend-selector">
        <select v-model="weekendSelezionatoId" class="filter-select" @change="caricaWeekendData">
          <option :value="null">— Seleziona Weekend —</option>
          <option v-for="w in weekend" :key="w.id" :value="w.id">{{ w.nome }} ({{ formatDate(w.data_inizio) }} - {{ formatDate(w.data_fine) }})</option>
        </select>
        <button v-if="weekendSelezionatoId" class="btn-save" @click="salvaAssegnazioniWeekend">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
          Salva
        </button>
        <button v-if="weekendSelezionatoId" class="btn-save" @click="stampa">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <polyline points="6 9 6 2 18 2 18 9"/>
            <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
            <rect x="6" y="14" width="12" height="8"/>
          </svg>
          Stampa
        </button>
      </div>

      <div v-if="weekendSelezionatoId" class="weekend-info">
        <div class="info-section" v-if="weekendPartite.length > 0">
          <h3>Partite programmate</h3>
          <div v-for="p in weekendPartite" :key="p.id" class="partita-info-chip">
            <span class="chip-cat">{{ getCatLabel(p.categoria_id) }}</span>
            <span class="chip-match">{{ p.avversario || 'TBD' }} {{ p.casa_fuori === 'fuori' ? '(in trasferta)' : '(in casa)' }}</span>
            <span class="chip-date">{{ formatDate(p.data_partite) }} {{ p.ora ? p.ora.slice(0,5) : '' }}</span>
          </div>
        </div>
        <div class="info-section" v-if="weekendAllenamenti.length > 0">
          <h3>Allenamenti in settimana</h3>
          <div v-for="a in weekendAllenamenti" :key="a.id" class="allenamento-info-chip">
            <span class="chip-cat">{{ getCatLabel(a.categoria_id) }}</span>
            <span class="chip-date">{{ formatDate(a.data) }}</span>
          </div>
        </div>
      </div>

      <div v-if="weekendSelezionatoId" class="assegnazioni-table">
        <div class="table-header">
          <div class="col-cat">Squadra</div>
          <div class="col-spo">Spogliatoio</div>
          <div class="col-campo">Campo da gioco</div>
        </div>
        <div v-for="p in weekendPartiteCasa" :key="'wc-' + p.id" class="table-row">
          <div class="col-cat casa-cell">
            <span class="cat-anno">{{ getCatLabel(p.categoria_id) }}</span>
            <span class="tipo-badge casa">Casa</span>
          </div>
          <div class="col-spo multi-select">
            <div v-for="item in spogliatoi" :key="item.id"
                 class="select-chip"
                 :class="{
                   active: getAssegnazioneSpogliatoio(p.categoria_id, item.id, 'casa', p.id),
                   occupied: isSpogliatoioOccupatoWeekend(p.categoria_id, item.id, 'casa', p.id)
                 }"
                 @click="!isSpogliatoioOccupatoWeekend(p.categoria_id, item.id, 'casa', p.id) && toggleAssegnazioneSpogliatoio(p.categoria_id, item.id, 'casa', p.id)">
              {{ item.etichetta }}
            </div>
            <span v-if="spogliatoi.length === 0" class="no-items">Nessuno disponibile</span>
          </div>
          <div class="col-campo multi-select">
            <div v-for="item in campi" :key="item.id" class="campo-menu-wrapper">
              <div class="select-chip campo-chip-main"
                   :class="{
                     active: getCampoAssegnatoWeekend(p.categoria_id, item.id, 'casa', p.id),
                     occupied: isCampoTuttoOccupatoWeekend(p.categoria_id, item.id, 'casa', p.id) && !getCampoAssegnatoWeekend(p.categoria_id, item.id, 'casa', p.id)
                   }"
                   @click.stop="toggleCampoMenuWeekend(p.categoria_id, item.id, 'casa', p.id)">
                 {{ item.etichetta }}{{ getCampoLabelSuffissoWeekend(p.categoria_id, item.id, 'casa', p.id) }}
                 <svg v-if="getCampoMenuOpzioni(item).length > 1" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="10" height="10">
                   <polyline points="6 9 12 15 18 9"/>
                 </svg>
               </div>
               <div v-if="campoMenuAperto === `casa_${p.id || ''}_${item.id}`" class="campo-dropdown" @click.stop>
                 <div v-for="opt in getCampoMenuOpzioni(item)" :key="opt.metacampo || 'full'"
                      class="campo-dropdown-item"
                      :class="{
                        active: getCampoAssegnatoWeekend(p.categoria_id, item.id, 'casa', p.id) === (opt.metacampo || 'FULL'),
                        disabled: isCampoOccupatoWeekend(p.categoria_id, item.id, 'casa', p.id, opt.metacampo) && getCampoAssegnatoWeekend(p.categoria_id, item.id, 'casa', p.id) !== (opt.metacampo || 'FULL')
                      }"
                      @click="!isCampoOccupatoWeekend(p.categoria_id, item.id, 'casa', p.id, opt.metacampo) || getCampoAssegnatoWeekend(p.categoria_id, item.id, 'casa', p.id) === (opt.metacampo || 'FULL') ? assegnaCampoDaMenuWeekend(p.categoria_id, item.id, 'casa', p.id, opt.metacampo) : null">
                   {{ opt.label }}
                 </div>
                 <div v-if="getCampoAssegnatoWeekend(p.categoria_id, item.id, 'casa', p.id)" class="campo-dropdown-item rimuovi" @click="assegnaCampoDaMenuWeekend(p.categoria_id, item.id, 'casa', p.id, getCampoAssegnatoWeekend(p.categoria_id, item.id, 'casa', p.id) === 'FULL' ? null : getCampoAssegnatoWeekend(p.categoria_id, item.id, 'casa', p.id))">
                   Rimuovi
                 </div>
               </div>
             </div>
            <span v-if="campi.length === 0" class="no-items">Nessuno disponibile</span>
          </div>
        </div>
        <div v-for="p in weekendPartiteFuori" :key="'wf-' + p.id" class="table-row">
          <div class="col-cat fuori-cell">
            <span class="cat-nome">{{ p.avversario || 'TBD' }}</span>
            <span class="tipo-badge fuori">Ospite</span>
          </div>
          <div class="col-spo multi-select">
            <div v-for="item in spogliatoi" :key="item.id"
                 class="select-chip"
                 :class="{
                   active: getAssegnazioneSpogliatoio(p.categoria_id, item.id, 'ospite', p.id),
                   occupied: isSpogliatoioOccupatoWeekend(p.categoria_id, item.id, 'ospite', p.id)
                 }"
                 @click="!isSpogliatoioOccupatoWeekend(p.categoria_id, item.id, 'ospite', p.id) && toggleAssegnazioneSpogliatoio(p.categoria_id, item.id, 'ospite', p.id)">
              {{ item.etichetta }}
            </div>
            <span v-if="spogliatoi.length === 0" class="no-items">Nessuno disponibile</span>
          </div>
          <div class="col-campo multi-select">
            <div v-for="item in campi" :key="item.id" class="campo-menu-wrapper">
              <div class="select-chip campo-chip-main"
                   :class="{
                     active: getCampoAssegnatoWeekend(p.categoria_id, item.id, 'ospite', p.id),
                     occupied: isCampoTuttoOccupatoWeekend(p.categoria_id, item.id, 'ospite', p.id) && !getCampoAssegnatoWeekend(p.categoria_id, item.id, 'ospite', p.id)
                   }"
                   @click.stop="toggleCampoMenuWeekend(p.categoria_id, item.id, 'ospite', p.id)">
                 {{ item.etichetta }}{{ getCampoLabelSuffissoWeekend(p.categoria_id, item.id, 'ospite', p.id) }}
                 <svg v-if="getCampoMenuOpzioni(item).length > 1" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="10" height="10">
                   <polyline points="6 9 12 15 18 9"/>
                 </svg>
               </div>
               <div v-if="campoMenuAperto === `ospite_${p.id || ''}_${item.id}`" class="campo-dropdown" @click.stop>
                 <div v-for="opt in getCampoMenuOpzioni(item)" :key="opt.metacampo || 'full'"
                      class="campo-dropdown-item"
                      :class="{
                        active: getCampoAssegnatoWeekend(p.categoria_id, item.id, 'ospite', p.id) === (opt.metacampo || 'FULL'),
                        disabled: isCampoOccupatoWeekend(p.categoria_id, item.id, 'ospite', p.id, opt.metacampo) && getCampoAssegnatoWeekend(p.categoria_id, item.id, 'ospite', p.id) !== (opt.metacampo || 'FULL')
                      }"
                      @click="!isCampoOccupatoWeekend(p.categoria_id, item.id, 'ospite', p.id, opt.metacampo) || getCampoAssegnatoWeekend(p.categoria_id, item.id, 'ospite', p.id) === (opt.metacampo || 'FULL') ? assegnaCampoDaMenuWeekend(p.categoria_id, item.id, 'ospite', p.id, opt.metacampo) : null">
                   {{ opt.label }}
                 </div>
                 <div v-if="getCampoAssegnatoWeekend(p.categoria_id, item.id, 'ospite', p.id)" class="campo-dropdown-item rimuovi" @click="assegnaCampoDaMenuWeekend(p.categoria_id, item.id, 'ospite', p.id, getCampoAssegnatoWeekend(p.categoria_id, item.id, 'ospite', p.id) === 'FULL' ? null : getCampoAssegnatoWeekend(p.categoria_id, item.id, 'ospite', p.id))">
                   Rimuovi
                 </div>
               </div>
             </div>
            <span v-if="campi.length === 0" class="no-items">Nessuno disponibile</span>
          </div>
        </div>
        <!-- Non censite rows -->
        <div v-for="(squadra, idx) in squadreNonCensiteWeekend" :key="'nc-w-' + idx" class="table-row non-censite-row">
          <div class="col-cat non-censita-cell">
            <span class="print-team-name">{{ squadra.nome || 'Squadra non censita' }}</span>
            <input type="text" v-model="squadreNonCensiteWeekend[idx].nome" placeholder="Nome squadra" class="non-censita-input" />
            <button class="btn-rimuovi-squadra" @click.stop="rimuoviSquadraNonCensita(idx, 'weekend')" title="Rimuovi">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="col-spo multi-select">
            <div v-for="item in spogliatoi" :key="item.id"
                 class="select-chip"
                 :class="{
                   active: getAssegnazioneSpogliatoioNonCensita(idx, item.id, 'weekend'),
                   occupied: isSpogliatoioOccupatoNonCensitaWeekend(idx, item.id)
                 }"
                 @click="!isSpogliatoioOccupatoNonCensitaWeekend(idx, item.id) && toggleAssegnazioneSpogliatoioNonCensita(idx, item.id, 'weekend')">
              {{ item.etichetta }}
            </div>
            <span v-if="spogliatoi.length === 0" class="no-items">Nessuno disponibile</span>
          </div>
          <div class="col-campo multi-select">
            <div v-for="item in campi" :key="item.id" class="campo-menu-wrapper">
              <div class="select-chip campo-chip-main"
                   :class="{
                     active: getCampoAssegnatoNCWeekend(idx, item.id),
                     occupied: isCampoTuttoOccupatoNonCensitaWeekend(idx, item.id) && !getCampoAssegnatoNCWeekend(idx, item.id)
                   }"
                   @click.stop="toggleCampoMenuNCWeekend(idx, item.id)">
                 {{ item.etichetta }}{{ getCampoLabelSuffissoNCWeekend(idx, item.id) }}
                 <svg v-if="getCampoMenuOpzioni(item).length > 1" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="10" height="10">
                   <polyline points="6 9 12 15 18 9"/>
                 </svg>
               </div>
               <div v-if="campoMenuAperto === `nc_weekend_${idx}_${item.id}`" class="campo-dropdown" @click.stop>
                 <div v-for="opt in getCampoMenuOpzioni(item)" :key="opt.metacampo || 'full'"
                      class="campo-dropdown-item"
                      :class="{
                        active: getCampoAssegnatoNCWeekend(idx, item.id) === (opt.metacampo || 'FULL'),
                        disabled: isCampoOccupatoNonCensitaWeekend(idx, item.id, opt.metacampo) && getCampoAssegnatoNCWeekend(idx, item.id) !== (opt.metacampo || 'FULL')
                      }"
                      @click="!isCampoOccupatoNonCensitaWeekend(idx, item.id, opt.metacampo) || getCampoAssegnatoNCWeekend(idx, item.id) === (opt.metacampo || 'FULL') ? assegnaCampoDaMenuNCWeekend(idx, item.id, opt.metacampo) : null">
                   {{ opt.label }}
                 </div>
                 <div v-if="getCampoAssegnatoNCWeekend(idx, item.id)" class="campo-dropdown-item rimuovi" @click="assegnaCampoDaMenuNCWeekend(idx, item.id, getCampoAssegnatoNCWeekend(idx, item.id) === 'FULL' ? null : getCampoAssegnatoNCWeekend(idx, item.id))">
                   Rimuovi
                 </div>
               </div>
             </div>
            <span v-if="campi.length === 0" class="no-items">Nessuno disponibile</span>
          </div>
        </div>
        <div class="table-row add-row">
          <div class="col-cat">
            <button class="btn-add-squadra" @click="aggiungiSquadraNonCensita('weekend')">+ Squadra non censita</button>
          </div>
          <div class="col-spo"></div>
          <div class="col-campo"></div>
        </div>
      </div>
      <div v-if="!weekendSelezionatoId" class="empty-state">
        <p>Seleziona un weekend per gestire le assegnazioni</p>
      </div>
    </div>

    <!-- Spogliatoi chips -->
    <div class="items-list">
      <div class="items-section">
        <span class="items-section-label">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
          </svg>
          Spogliatoi
        </span>
        <div v-for="item in spogliatoi" :key="item.id" class="item-chip">
          <span class="chip-label">{{ item.etichetta }}</span>
          <button class="btn-icon-xs" @click="apriModal(item, 'spogliatoi')" title="Modifica">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12">
              <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
          </button>
          <button class="btn-icon-xs btn-delete" @click="eliminaFn(item.id, 'spogliatoi')" title="Elimina">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12">
              <polyline points="3 6 5 6 21 6"/>
              <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
            </svg>
          </button>
        </div>
        <button class="btn-add-chip" @click="apriModal(null, 'spogliatoi')">+ Spogliatoio</button>
      </div>
    </div>

    <!-- Campi chips -->
    <div class="items-list">
      <div class="items-section">
        <span class="items-section-label">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
            <rect x="3" y="3" width="18" height="18" rx="2"/>
            <path d="M3 12h18M12 3v18"/>
          </svg>
          Campi da gioco
        </span>
        <div v-for="item in campi" :key="item.id" class="item-chip">
          <span class="chip-label">{{ item.etichetta }} <span class="campo-tipo-badge" v-if="item.tipo_campo">({{ item.tipo_campo }})</span></span>
          <button class="btn-icon-xs" @click="apriModal(item, 'campi')" title="Modifica">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12">
              <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
          </button>
          <button class="btn-icon-xs btn-delete" @click="eliminaFn(item.id, 'campi')" title="Elimina">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12">
              <polyline points="3 6 5 6 21 6"/>
              <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
            </svg>
          </button>
        </div>
        <button class="btn-add-chip" @click="apriModal(null, 'campi')">+ Campo</button>
      </div>
    </div>

    <!-- Modal -->
    <Teleport to="body">
      <div v-if="modal.show" class="modal-overlay" @click.self="modal.show = false">
        <div class="modal">
          <div class="modal-header">
            <h3>{{ modal.id ? (modal.tipo === 'spogliatoi' ? 'Modifica Spogliatoio' : 'Modifica Campo') : (modal.tipo === 'spogliatoi' ? 'Nuovo Spogliatoio' : 'Nuovo Campo') }}</h3>
            <button class="modal-close" @click="modal.show = false">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"/>
                <line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Etichetta</label>
              <input type="text" v-model="modal.etichetta" :placeholder="modal.tipo === 'spogliatoi' ? 'Es. Spogliatoio A, Casa 1, Ospiti...' : 'Es. Campo principale, Campo B...'" />
            </div>
            <div class="form-group">
              <label>Ordine</label>
              <input type="number" v-model.number="modal.ordine" min="0" />
            </div>
            <div class="form-group" v-if="modal.tipo === 'campi'">
              <label>Tipo campo</label>
              <select v-model="modal.tipo_campo" class="form-select">
                <option value="11">11</option>
                <option value="9">9</option>
                <option value="8">8</option>
                <option value="7">7</option>
                <option value="5">5</option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="modal.show = false">Annulla</button>
            <button class="btn-primary" @click="salvaModal">{{ modal.id ? 'Salva' : 'Crea' }}</button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue"
import { useRouter } from "vue-router"
import { useStore } from "../store.js"
import {
  getAllCategorie,
  getSpogliatoi,
  creaSpogliatoio,
  aggiornaSpogliatoio,
  eliminaSpogliatoio,
  getAssegnazioniSettimana,
  getAssegnazioniWeekend,
  creaAssegnazione,
  aggiornaAssegnazione,
  getWeekend,
  getCampi,
  creaCampo,
  aggiornaCampo,
  eliminaCampo,
  getCampiAssegnazioniSettimana,
  getCampiAssegnazioniWeekend,
  creaCampoAssegnazione,
  aggiornaCampoAssegnazione,
  getWeekendPartite,
  getAssegnazioniDefault,
  applyDefaultWeekSpogliatoi,
  getCampiAssegnazioniDefault,
  applyDefaultWeekCampi
} from "../api/index.js"

const router = useRouter()
const { societaAttiva } = useStore()

const tabAttivo = ref('settimanale')
const spogliatoi = ref([])
const campi = ref([])
const categorie = ref([])
const weekend = ref([])
const weekendSelezionatoId = ref(null)
const weekendPartite = ref([])
const weekendAllenamenti = ref([])

const settimanaInizio = ref(getLunesdiCorrente())
const giornoAttivo = ref(null)

// Assegnazioni separate per spogliatoi e campi
const assegSpogliatoioSettimanali = ref({})
const assegCampoSettimanali = ref({})
const squadreNonCensiteSettimanali = ref([])

const assegSpogliatoioWeekend = ref({})
const assegCampoWeekend = ref({})
const squadreNonCensiteWeekend = ref([])

// Default week assignments
const assegSpogliatoioDefault = ref({})
const assegCampoDefault = ref({})
const giornoDefaultAttivo = ref(null)
const campoMenuDefaultAperto = ref(null)
const haSettimanaTipo = ref(false)

const modal = ref({ show: false, id: null, tipo: 'spogliatoi', etichetta: '', ordine: 0, tipo_campo: '11' })
const campoMenuAperto = ref(null)

const categorieOrdinate = computed(() =>
  categorie.value.sort((a, b) => (a.anno || 9999) - (b.anno || 9999))
)

const giorniSettimana = computed(() => {
  const giorni = []
  const nomi = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven']
  const nomiLunghi = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì']
  const d = new Date(settimanaInizio.value)
  for (let i = 0; i < 5; i++) {
    const dataStr = d.toISOString().split('T')[0]
    const dow = d.getDay()
    const cats = getCategoriePerGiornoSettimana(dow)
    giorni.push({
      data: dataStr,
      nomeBreve: nomi[i],
      nomeLungo: nomiLunghi[i],
      giorno: d.getDate(),
      categorie: cats
    })
    d.setDate(d.getDate() + 1)
  }
  return giorni
})

function getCategoriePerGiornoSettimana(dow) {
  return categorie.value.filter(c => {
    if (!c.giorni) return false
    return c.giorni.split(',').map(Number).includes(dow)
  })
}

const giorniDefault = computed(() => {
  const giorni = []
  const nomi = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven']
  const d = new Date()
  const giorno = d.getDay()
  const diff = giorno === 0 ? -6 : 1 - giorno
  d.setDate(d.getDate() + diff)
  for (let i = 0; i < 5; i++) {
    const dataStr = d.toISOString().split('T')[0]
    const dow = d.getDay()
    const cats = getCategoriePerGiornoSettimana(dow)
    giorni.push({
      data: dataStr,
      nomeBreve: nomi[i],
      giorno: d.getDate(),
      categorie: cats
    })
    d.setDate(d.getDate() + 1)
  }
  return giorni
})

function getCategorieGiorno(dataGiorno) {
  const d = new Date(dataGiorno)
  const dow = d.getDay()
  return getCategoriePerGiornoSettimana(dow)
}

function categoriePerOrario(dataGiorno) {
  const cats = getCategorieGiorno(dataGiorno)
  const grouped = {}
  cats.forEach(c => {
    const ora = c.ora_allenamento || 'Senza orario'
    if (!grouped[ora]) grouped[ora] = []
    grouped[ora].push(c)
  })
  const sorted = Object.entries(grouped).sort((a, b) => a[0].localeCompare(b[0]))
  const result = {}
  sorted.forEach(([ora, cats]) => {
    result[ora] = cats.sort((a, b) => (a.anno || 9999) - (b.anno || 9999))
  })
  return result
}

function selezionaGiorno(data) {
  giornoAttivo.value = data
}

const settimanaFine = computed(() => {
  const d = new Date(settimanaInizio.value)
  d.setDate(d.getDate() + 4)
  return d.toISOString().split('T')[0]
})

const weekendPartiteCasa = computed(() =>
  (weekendPartite.value || []).filter(p => p && p.id && p.categoria_id && p.casa_fuori !== 'fuori')
)

const weekendPartiteFuori = computed(() =>
  (weekendPartite.value || []).filter(p => p && p.id && p.categoria_id && p.casa_fuori === 'fuori')
)

function getLunesdiCorrente() {
  const oggi = new Date()
  const giorno = oggi.getDay()
  const diff = giorno === 0 ? -6 : 1 - giorno
  const lunedi = new Date(oggi)
  lunedi.setDate(oggi.getDate() + diff)
  return lunedi.toISOString().split('T')[0]
}

function getWeekendLabel() {
  const w = weekend.value.find(w => w.id === weekendSelezionatoId.value)
  return w ? `Weekend: ${w.nome} (${formatDate(w.data_inizio)} - ${formatDate(w.data_fine)})` : ''
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  const [y, m, d] = dateStr.split('-')
  return `${d}/${m}/${y}`
}

function getCatLabel(catId) {
  const cat = categorie.value.find(c => c.id === catId)
  return cat ? `${cat.anno} - ${cat.nome}` : 'N/D'
}

function cambiaSettimana(delta) {
  const d = new Date(settimanaInizio.value)
  d.setDate(d.getDate() + delta * 7)
  settimanaInizio.value = d.toISOString().split('T')[0]
  caricaAssegnazioniSettimana()
  // Auto-select today's day if in current week
  const oggi = new Date().toISOString().split('T')[0]
  if (giorniSettimana.value.length > 0) {
    const todayMatch = giorniSettimana.value.find(g => g.data === oggi)
    giornoAttivo.value = todayMatch ? todayMatch.data : giorniSettimana.value[0].data
  }
}

// ── Assignment helpers: SPOGLIATOI (settimanale per giorno) ──

function getAssegnazioneSpogliatoioGiorno(catId, itemId, dataGiorno) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  return assegSpogliatoioSettimanali.value[key] !== undefined
}

function getOraCategoria(catId) {
  const cat = categorie.value.find(c => c.id === catId)
  return cat ? (cat.ora_allenamento || 'Senza orario') : 'Senza orario'
}

function getNonCensitaGlobalIdx(lista, squadra) {
  return lista.findIndex(s => s.id === squadra.id)
}

function isSpogliatoioOccupatoFascia(catId, itemId, dataGiorno) {
  const ora = getOraCategoria(catId)
  const dow = new Date(dataGiorno).getDay()
  if (categorie.value.some(c =>
    c.id !== catId &&
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora &&
    assegSpogliatoioSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`] !== undefined
  )) return true
  return squadreNonCensiteSettimanali.value.some(s =>
    s.ora === ora && s.dataGiorno === dataGiorno &&
    assegSpogliatoioSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`] !== undefined
  )
}

function isCampoOccupatoFascia(catId, itemId, dataGiorno, metacampo) {
  const ora = getOraCategoria(catId)
  const dow = new Date(dataGiorno).getDay()
  const allCats = categorie.value.filter(c =>
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  const ncSquadre = squadreNonCensiteSettimanali.value.filter(s =>
    s.ora === ora && s.dataGiorno === dataGiorno
  )
  if (metacampo === 'A' || metacampo === 'B') {
    for (const c of allCats) {
      if (c.id === catId) continue
      const a = assegCampoSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    for (const s of ncSquadre) {
      const a = assegCampoSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    return false
  }
  for (const c of allCats) {
    if (c.id === catId) continue
    const a = assegCampoSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`]
    if (a) return true
  }
  for (const s of ncSquadre) {
    if (assegCampoSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`]) return true
  }
  return false
}

function isCampoTuttoOccupatoFascia(catId, itemId, dataGiorno) {
  const ora = getOraCategoria(catId)
  const dow = new Date(dataGiorno).getDay()
  const allCats = categorie.value.filter(c =>
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  const ncSquadre = squadreNonCensiteSettimanali.value.filter(s =>
    s.ora === ora && s.dataGiorno === dataGiorno
  )
  for (const c of allCats) {
    if (c.id === catId) continue
    const a = assegCampoSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  for (const s of ncSquadre) {
    const a = assegCampoSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  return false
}

function isSpogliatoioOccupatoNonCensitaGiorno(idx, itemId, dataGiorno) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  if (!squadra) return false
  const ora = squadra.ora || 'Senza orario'
  const dow = new Date(dataGiorno).getDay()
  if (categorie.value.some(c =>
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora &&
    assegSpogliatoioSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`] !== undefined
  )) return true
  return squadreNonCensiteSettimanali.value.some(s =>
    s.id !== squadra.id && s.ora === ora && s.dataGiorno === dataGiorno &&
    assegSpogliatoioSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`] !== undefined
  )
}

function isCampoOccupatoNonCensitaGiorno(idx, itemId, dataGiorno, metacampo) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  if (!squadra) return false
  const ora = squadra.ora || 'Senza orario'
  const dow = new Date(dataGiorno).getDay()
  const allCats = categorie.value.filter(c =>
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  const ncSquadre = squadreNonCensiteSettimanali.value.filter(s =>
    s.ora === ora && s.dataGiorno === dataGiorno
  )
  if (metacampo === 'A' || metacampo === 'B') {
    for (const c of allCats) {
      const a = assegCampoSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    for (const s of ncSquadre) {
      if (s.id === squadra.id) continue
      const a = assegCampoSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    return false
  }
  for (const c of allCats) {
    if (assegCampoSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`]) return true
  }
  for (const s of ncSquadre) {
    if (s.id !== squadra.id && assegCampoSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`]) return true
  }
  return false
}

function isCampoTuttoOccupatoNonCensitaGiorno(idx, itemId, dataGiorno) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  if (!squadra) return false
  const ora = squadra.ora || 'Senza orario'
  const dow = new Date(dataGiorno).getDay()
  const allCats = categorie.value.filter(c =>
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  const ncSquadre = squadreNonCensiteSettimanali.value.filter(s =>
    s.ora === ora && s.dataGiorno === dataGiorno
  )
  for (const c of allCats) {
    const a = assegCampoSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  for (const s of ncSquadre) {
    if (s.id === squadra.id) continue
    const a = assegCampoSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  return false
}

function isSpogliatoioOccupatoWeekend(catId, itemId, tipo, partitaId) {
  const altrePartite = tipo === 'ospite' ? weekendPartiteFuori.value : weekendPartiteCasa.value
  return altrePartite.some(p =>
    p.id !== partitaId &&
    assegSpogliatoioWeekend.value[`${tipo}_${p.id || ''}_${itemId}`] !== undefined
  )
}

function isCampoOccupatoWeekend(catId, itemId, tipo, partitaId, metacampo) {
  const altrePartite = tipo === 'ospite' ? weekendPartiteFuori.value : weekendPartiteCasa.value
  const ncSquadre = squadreNonCensiteWeekend.value
  if (metacampo === 'A' || metacampo === 'B') {
    for (const p of altrePartite) {
      if (p.id === partitaId) continue
      const a = assegCampoWeekend.value[`${tipo}_${p.id || ''}_${itemId}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    for (let i = 0; i < ncSquadre.length; i++) {
      const a = assegCampoWeekend.value[`noncensita_weekend_${i}_${itemId}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    return false
  }
  for (const p of altrePartite) {
    if (p.id === partitaId && assegCampoWeekend.value[`${tipo}_${p.id || ''}_${itemId}`]) return true
  }
  for (const p of altrePartite) {
    if (p.id !== partitaId && assegCampoWeekend.value[`${tipo}_${p.id || ''}_${itemId}`]) return true
  }
  for (let i = 0; i < ncSquadre.length; i++) {
    if (assegCampoWeekend.value[`noncensita_weekend_${i}_${itemId}`]) return true
  }
  return false
}

function isCampoTuttoOccupatoWeekend(catId, itemId, tipo, partitaId) {
  const altrePartite = tipo === 'ospite' ? weekendPartiteFuori.value : weekendPartiteCasa.value
  const ncSquadre = squadreNonCensiteWeekend.value
  for (const p of altrePartite) {
    if (p.id === partitaId) continue
    const a = assegCampoWeekend.value[`${tipo}_${p.id || ''}_${itemId}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  for (let i = 0; i < ncSquadre.length; i++) {
    const a = assegCampoWeekend.value[`noncensita_weekend_${i}_${itemId}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  return false
}

function isSpogliatoioOccupatoNonCensitaWeekend(idx, itemId) {
  return weekendPartiteCasa.value.some(p =>
    assegSpogliatoioWeekend.value[`casa_${p.id || ''}_${itemId}`] !== undefined
  ) || weekendPartiteFuori.value.some(p =>
    assegSpogliatoioWeekend.value[`ospite_${p.id || ''}_${itemId}`] !== undefined
  ) || squadreNonCensiteWeekend.value.some((_, i) =>
    i !== idx && assegSpogliatoioWeekend.value[`noncensita_weekend_${i}_${itemId}`] !== undefined
  )
}

function isCampoOccupatoNonCensitaWeekend(idx, itemId, metacampo) {
  const allPartite = [...weekendPartiteCasa.value, ...weekendPartiteFuori.value]
  if (metacampo === 'A' || metacampo === 'B') {
    for (const p of allPartite) {
      const tipo = p.casa_fuori === 'fuori' ? 'ospite' : 'casa'
      const a = assegCampoWeekend.value[`${tipo}_${p.id || ''}_${itemId}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    for (let i = 0; i < squadreNonCensiteWeekend.value.length; i++) {
      if (i === idx) continue
      const a = assegCampoWeekend.value[`noncensita_weekend_${i}_${itemId}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    return false
  }
  for (const p of allPartite) {
    const tipo = p.casa_fuori === 'fuori' ? 'ospite' : 'casa'
    if (assegCampoWeekend.value[`${tipo}_${p.id || ''}_${itemId}`]) return true
  }
  for (let i = 0; i < squadreNonCensiteWeekend.value.length; i++) {
    if (i !== idx && assegCampoWeekend.value[`noncensita_weekend_${i}_${itemId}`]) return true
  }
  return false
}

function isCampoTuttoOccupatoNonCensitaWeekend(idx, itemId) {
  const allPartite = [...weekendPartiteCasa.value, ...weekendPartiteFuori.value]
  for (const p of allPartite) {
    const tipo = p.casa_fuori === 'fuori' ? 'ospite' : 'casa'
    const a = assegCampoWeekend.value[`${tipo}_${p.id || ''}_${itemId}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  for (let i = 0; i < squadreNonCensiteWeekend.value.length; i++) {
    if (i === idx) continue
    const a = assegCampoWeekend.value[`noncensita_weekend_${i}_${itemId}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  return false
}

function toggleAssegnazioneSpogliatoioGiorno(catId, itemId, dataGiorno) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  if (assegSpogliatoioSettimanali.value[key]) {
    delete assegSpogliatoioSettimanali.value[key]
  } else {
    const ora = getOraCategoria(catId)
    const dow = new Date(dataGiorno).getDay()
    const categorieStessaFascia = categorie.value.filter(c =>
      c.id !== catId &&
      (c.giorni || '').split(',').map(Number).includes(dow) &&
      (c.ora_allenamento || 'Senza orario') === ora
    )
    categorieStessaFascia.forEach(c => {
      const otherKey = `${c.id}_${itemId}_${dataGiorno}`
      delete assegSpogliatoioSettimanali.value[otherKey]
    })
    squadreNonCensiteSettimanali.value.forEach(s => {
      if (s.ora === ora && s.dataGiorno === dataGiorno) {
        const ncKey = `noncensita_${s.id}_${itemId}_${dataGiorno}`
        delete assegSpogliatoioSettimanali.value[ncKey]
      }
    })
    assegSpogliatoioSettimanali.value[key] = { categoria_id: catId, spogliatoio_id: itemId, data: dataGiorno }
  }
}

function getAssegnazioneSpogliatoioNonCensitaGiorno(idx, itemId, dataGiorno) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  const key = `noncensita_${squadra.id}_${itemId}_${dataGiorno}`
  return assegSpogliatoioSettimanali.value[key] !== undefined
}

function toggleAssegnazioneSpogliatoioNonCensitaGiorno(idx, itemId, dataGiorno) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  const key = `noncensita_${squadra.id}_${itemId}_${dataGiorno}`
  if (assegSpogliatoioSettimanali.value[key]) {
    delete assegSpogliatoioSettimanali.value[key]
  } else {
    const ora = squadra.ora || 'Senza orario'
    const dow = new Date(dataGiorno).getDay()
    categorie.value.filter(c =>
      (c.giorni || '').split(',').map(Number).includes(dow) &&
      (c.ora_allenamento || 'Senza orario') === ora
    ).forEach(c => {
      const otherKey = `${c.id}_${itemId}_${dataGiorno}`
      delete assegSpogliatoioSettimanali.value[otherKey]
    })
    squadreNonCensiteSettimanali.value.forEach(s => {
      if (s.id !== squadra.id && s.ora === ora && s.dataGiorno === dataGiorno) {
        const ncKey = `noncensita_${s.id}_${itemId}_${dataGiorno}`
        delete assegSpogliatoioSettimanali.value[ncKey]
      }
    })
    assegSpogliatoioSettimanali.value[key] = {
      spogliatoio_id: itemId,
      nome_squadra_esterna: squadra.nome,
      tipo: 'esterna',
      data: dataGiorno
    }
  }
}

function getCampoChips(campo) {
  const tipo = parseInt(campo.tipo_campo) || 11
  if (tipo <= 5) return [{ campo, label: campo.etichetta, metacampo: null }]
  return [
    { campo, label: campo.etichetta, metacampo: null },
    { campo, label: `${campo.etichetta} A`, metacampo: 'A' },
    { campo, label: `${campo.etichetta} B`, metacampo: 'B' },
  ]
}

function getCampoMenuOpzioni(campo) {
  const tipo = parseInt(campo.tipo_campo) || 11
  if (tipo <= 5) return [{ label: 'Tutto', metacampo: null }]
  return [
    { label: 'Tutto', metacampo: null },
    { label: 'Metà A', metacampo: 'A' },
    { label: 'Metà B', metacampo: 'B' },
  ]
}

function getCampoAssegnato(catId, itemId, dataGiorno) {
  const a = assegCampoSettimanali.value[`${catId}_${itemId}_${dataGiorno}`]
  if (!a) return null
  return a.metacampo || 'FULL'
}

function getCampoLabelSuffisso(catId, itemId, dataGiorno) {
  const asg = getCampoAssegnato(catId, itemId, dataGiorno)
  if (asg === 'A') return ' A'
  if (asg === 'B') return ' B'
  return ''
}

function toggleCampoMenu(catId, itemId, dataGiorno) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  campoMenuAperto.value = campoMenuAperto.value === key ? null : key
}

function chiudiCampoMenu() {
  campoMenuAperto.value = null
  campoMenuDefaultAperto.value = null
}

function assegnaCampoDaMenu(catId, itemId, dataGiorno, metacampo) {
  toggleAssegnazioneCampoGiorno(catId, itemId, dataGiorno, metacampo)
  campoMenuAperto.value = null
}

function getCampoAssegnatoNC(idx, itemId, dataGiorno) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  const a = assegCampoSettimanali.value[`noncensita_${squadra.id}_${itemId}_${dataGiorno}`]
  if (!a) return null
  return a.metacampo || 'FULL'
}

function getCampoLabelSuffissoNC(idx, itemId, dataGiorno) {
  const asg = getCampoAssegnatoNC(idx, itemId, dataGiorno)
  if (asg === 'A') return ' A'
  if (asg === 'B') return ' B'
  return ''
}

function toggleCampoMenuNC(idx, itemId, dataGiorno) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  const key = `nc_${squadra.id}_${itemId}_${dataGiorno}`
  campoMenuAperto.value = campoMenuAperto.value === key ? null : key
}

function assegnaCampoDaMenuNC(idx, itemId, dataGiorno, metacampo) {
  toggleAssegnazioneCampoNonCensitaGiorno(idx, itemId, dataGiorno, metacampo)
  campoMenuAperto.value = null
}

function getCampoAssegnatoWeekend(catId, itemId, tipo, partitaId) {
  const a = assegCampoWeekend.value[`${tipo}_${partitaId || ''}_${itemId}`]
  if (!a) return null
  return a.metacampo || 'FULL'
}

function getCampoLabelSuffissoWeekend(catId, itemId, tipo, partitaId) {
  const asg = getCampoAssegnatoWeekend(catId, itemId, tipo, partitaId)
  if (asg === 'A') return ' A'
  if (asg === 'B') return ' B'
  return ''
}

function toggleCampoMenuWeekend(catId, itemId, tipo, partitaId) {
  const key = `${tipo}_${partitaId || ''}_${itemId}`
  campoMenuAperto.value = campoMenuAperto.value === key ? null : key
}

function assegnaCampoDaMenuWeekend(catId, itemId, tipo, partitaId, metacampo) {
  toggleAssegnazioneCampo(catId, itemId, tipo, partitaId, metacampo)
  campoMenuAperto.value = null
}

function getCampoAssegnatoNCWeekend(idx, itemId) {
  const a = assegCampoWeekend.value[`noncensita_weekend_${idx}_${itemId}`]
  if (!a) return null
  return a.metacampo || 'FULL'
}

function getCampoLabelSuffissoNCWeekend(idx, itemId) {
  const asg = getCampoAssegnatoNCWeekend(idx, itemId)
  if (asg === 'A') return ' A'
  if (asg === 'B') return ' B'
  return ''
}

function toggleCampoMenuNCWeekend(idx, itemId) {
  const key = `nc_weekend_${idx}_${itemId}`
  campoMenuAperto.value = campoMenuAperto.value === key ? null : key
}

function assegnaCampoDaMenuNCWeekend(idx, itemId, metacampo) {
  toggleAssegnazioneCampoNonCensita(idx, itemId, 'weekend', metacampo)
  campoMenuAperto.value = null
}

// ── Assignment helpers: CAMPI (settimanale per giorno) ──

function getAssegnazioneCampoGiorno(catId, itemId, dataGiorno, metacampo) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  const a = assegCampoSettimanali.value[key]
  if (!a) return false
  if (metacampo == null) return a.metacampo == null || a.metacampo === 'FULL'
  return a.metacampo === metacampo
}

function toggleAssegnazioneCampoGiorno(catId, itemId, dataGiorno, metacampo) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  const existing = assegCampoSettimanali.value[key]
  if (existing && (metacampo == null ? (existing.metacampo == null || existing.metacampo === 'FULL') : existing.metacampo === metacampo)) {
    delete assegCampoSettimanali.value[key]
    return
  }
  const ora = getOraCategoria(catId)
  const dow = new Date(dataGiorno).getDay()
  const categorieStessaFascia = categorie.value.filter(c =>
    c.id !== catId &&
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  if (metacampo == null || metacampo === 'FULL') {
    categorieStessaFascia.forEach(c => {
      const otherKey = `${c.id}_${itemId}_${dataGiorno}`
      delete assegCampoSettimanali.value[otherKey]
    })
    squadreNonCensiteSettimanali.value.forEach(s => {
      if (s.ora === ora && s.dataGiorno === dataGiorno) {
        delete assegCampoSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`]
      }
    })
  } else {
    categorieStessaFascia.forEach(c => {
      const otherKey = `${c.id}_${itemId}_${dataGiorno}`
      const other = assegCampoSettimanali.value[otherKey]
      if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
        delete assegCampoSettimanali.value[otherKey]
      }
    })
    squadreNonCensiteSettimanali.value.forEach(s => {
      if (s.ora === ora && s.dataGiorno === dataGiorno) {
        const ncKey = `noncensita_${s.id}_${itemId}_${dataGiorno}`
        const other = assegCampoSettimanali.value[ncKey]
        if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
          delete assegCampoSettimanali.value[ncKey]
        }
      }
    })
  }
  const payload = { categoria_id: catId, campo_id: itemId, data: dataGiorno }
  if (metacampo && metacampo !== 'FULL') payload.metacampo = metacampo
  assegCampoSettimanali.value[key] = payload
}

function getAssegnazioneCampoNonCensitaGiorno(idx, itemId, dataGiorno, metacampo) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  const key = `noncensita_${squadra.id}_${itemId}_${dataGiorno}`
  const a = assegCampoSettimanali.value[key]
  if (!a) return false
  if (metacampo == null) return a.metacampo == null || a.metacampo === 'FULL'
  return a.metacampo === metacampo
}

function toggleAssegnazioneCampoNonCensitaGiorno(idx, itemId, dataGiorno, metacampo) {
  const squadra = squadreNonCensiteSettimanali.value[idx]
  const key = `noncensita_${squadra.id}_${itemId}_${dataGiorno}`
  const existing = assegCampoSettimanali.value[key]
  if (existing && (metacampo == null ? (existing.metacampo == null || existing.metacampo === 'FULL') : existing.metacampo === metacampo)) {
    delete assegCampoSettimanali.value[key]
    return
  }
  const ora = squadra.ora || 'Senza orario'
  const dow = new Date(dataGiorno).getDay()
  const allCats = categorie.value.filter(c =>
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  if (metacampo == null || metacampo === 'FULL') {
    allCats.forEach(c => {
      delete assegCampoSettimanali.value[`${c.id}_${itemId}_${dataGiorno}`]
    })
    squadreNonCensiteSettimanali.value.forEach(s => {
      if (s.id !== squadra.id && s.ora === ora && s.dataGiorno === dataGiorno) {
        delete assegCampoSettimanali.value[`noncensita_${s.id}_${itemId}_${dataGiorno}`]
      }
    })
  } else {
    allCats.forEach(c => {
      const otherKey = `${c.id}_${itemId}_${dataGiorno}`
      const other = assegCampoSettimanali.value[otherKey]
      if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
        delete assegCampoSettimanali.value[otherKey]
      }
    })
    squadreNonCensiteSettimanali.value.forEach(s => {
      if (s.id !== squadra.id && s.ora === ora && s.dataGiorno === dataGiorno) {
        const ncKey = `noncensita_${s.id}_${itemId}_${dataGiorno}`
        const other = assegCampoSettimanali.value[ncKey]
        if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
          delete assegCampoSettimanali.value[ncKey]
        }
      }
    })
  }
  const payload = {
    campo_id: itemId,
    nome_squadra_esterna: squadra.nome,
    tipo: 'esterna',
    data: dataGiorno
  }
  if (metacampo && metacampo !== 'FULL') payload.metacampo = metacampo
  assegCampoSettimanali.value[key] = payload
}

// ── Assignment helpers: SPOGLIATOI (weekend) ──

function getAssegnazioneSpogliatoio(catId, itemId, tipo, partitaId) {
  const key = `${tipo}_${partitaId || ''}_${itemId}`
  return assegSpogliatoioWeekend.value[key] !== undefined
}

function toggleAssegnazioneSpogliatoio(catId, itemId, tipo, partitaId) {
  const key = `${tipo}_${partitaId || ''}_${itemId}`
  if (assegSpogliatoioWeekend.value[key]) {
    delete assegSpogliatoioWeekend.value[key]
  } else {
    // Rimuovi da altre partite dello stesso tipo (casa/casa o ospite/ospite)
    const altrePartite = tipo === 'ospite' ? weekendPartiteFuori.value : weekendPartiteCasa.value
    altrePartite.filter(p => p.id !== partitaId).forEach(p => {
      const otherKey = `${tipo}_${p.id || ''}_${itemId}`
      delete assegSpogliatoioWeekend.value[otherKey]
    })
    // Rimuovi da non censite
    squadreNonCensiteWeekend.value.forEach((_, idx) => {
      const ncKey = `noncensita_weekend_${idx}_${itemId}`
      delete assegSpogliatoioWeekend.value[ncKey]
    })
    assegSpogliatoioWeekend.value[key] = {
      categoria_id: catId,
      spogliatoio_id: itemId,
      tipo: tipo,
      partita_id: partitaId
    }
  }
}

function getAssegnazioneSpogliatoioNonCensita(idx, itemId, contesto) {
  const key = `noncensita_weekend_${idx}_${itemId}`
  return assegSpogliatoioWeekend.value[key] !== undefined
}

function toggleAssegnazioneSpogliatoioNonCensita(idx, itemId, contesto) {
  const key = `noncensita_weekend_${idx}_${itemId}`
  const squadra = squadreNonCensiteWeekend.value[idx]
  if (assegSpogliatoioWeekend.value[key]) {
    delete assegSpogliatoioWeekend.value[key]
  } else {
    weekendPartiteCasa.value.forEach(p => {
      delete assegSpogliatoioWeekend.value[`casa_${p.id || ''}_${itemId}`]
    })
    weekendPartiteFuori.value.forEach(p => {
      delete assegSpogliatoioWeekend.value[`ospite_${p.id || ''}_${itemId}`]
    })
    squadreNonCensiteWeekend.value.forEach((_, i) => {
      if (i !== idx) delete assegSpogliatoioWeekend.value[`noncensita_weekend_${i}_${itemId}`]
    })
    assegSpogliatoioWeekend.value[key] = {
      spogliatoio_id: itemId,
      nome_squadra_esterna: squadra.nome,
      tipo: 'esterna'
    }
  }
}

// ── Assignment helpers: CAMPI (weekend) ──

function getAssegnazioneCampo(catId, itemId, tipo, partitaId, metacampo) {
  const key = `${tipo}_${partitaId || ''}_${itemId}`
  const a = assegCampoWeekend.value[key]
  if (!a) return false
  if (metacampo == null) return a.metacampo == null || a.metacampo === 'FULL'
  return a.metacampo === metacampo
}

function toggleAssegnazioneCampo(catId, itemId, tipo, partitaId, metacampo) {
  const key = `${tipo}_${partitaId || ''}_${itemId}`
  const existing = assegCampoWeekend.value[key]
  if (existing && (metacampo == null ? (existing.metacampo == null || existing.metacampo === 'FULL') : existing.metacampo === metacampo)) {
    delete assegCampoWeekend.value[key]
    return
  }
  const altrePartite = tipo === 'ospite' ? weekendPartiteFuori.value : weekendPartiteCasa.value
  if (metacampo == null || metacampo === 'FULL') {
    altrePartite.filter(p => p.id !== partitaId).forEach(p => {
      delete assegCampoWeekend.value[`${tipo}_${p.id || ''}_${itemId}`]
    })
    squadreNonCensiteWeekend.value.forEach((_, idx) => {
      delete assegCampoWeekend.value[`noncensita_weekend_${idx}_${itemId}`]
    })
  } else {
    altrePartite.filter(p => p.id !== partitaId).forEach(p => {
      const otherKey = `${tipo}_${p.id || ''}_${itemId}`
      const other = assegCampoWeekend.value[otherKey]
      if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
        delete assegCampoWeekend.value[otherKey]
      }
    })
    squadreNonCensiteWeekend.value.forEach((_, idx) => {
      const ncKey = `noncensita_weekend_${idx}_${itemId}`
      const other = assegCampoWeekend.value[ncKey]
      if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
        delete assegCampoWeekend.value[ncKey]
      }
    })
  }
  const payload = {
    categoria_id: catId,
    campo_id: itemId,
    tipo: tipo,
    partita_id: partitaId
  }
  if (metacampo && metacampo !== 'FULL') payload.metacampo = metacampo
  assegCampoWeekend.value[key] = payload
}

function getAssegnazioneCampoNonCensita(idx, itemId, contesto, metacampo) {
  const key = `noncensita_weekend_${idx}_${itemId}`
  const a = assegCampoWeekend.value[key]
  if (!a) return false
  if (metacampo == null) return a.metacampo == null || a.metacampo === 'FULL'
  return a.metacampo === metacampo
}

function toggleAssegnazioneCampoNonCensita(idx, itemId, contesto, metacampo) {
  const key = `noncensita_weekend_${idx}_${itemId}`
  const squadra = squadreNonCensiteWeekend.value[idx]
  const existing = assegCampoWeekend.value[key]
  if (existing && (metacampo == null ? (existing.metacampo == null || existing.metacampo === 'FULL') : existing.metacampo === metacampo)) {
    delete assegCampoWeekend.value[key]
    return
  }
  if (metacampo == null || metacampo === 'FULL') {
    weekendPartiteCasa.value.forEach(p => {
      delete assegCampoWeekend.value[`casa_${p.id || ''}_${itemId}`]
    })
    weekendPartiteFuori.value.forEach(p => {
      delete assegCampoWeekend.value[`ospite_${p.id || ''}_${itemId}`]
    })
    squadreNonCensiteWeekend.value.forEach((_, i) => {
      if (i !== idx) delete assegCampoWeekend.value[`noncensita_weekend_${i}_${itemId}`]
    })
  } else {
    weekendPartiteCasa.value.forEach(p => {
      const otherKey = `casa_${p.id || ''}_${itemId}`
      const other = assegCampoWeekend.value[otherKey]
      if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
        delete assegCampoWeekend.value[otherKey]
      }
    })
    weekendPartiteFuori.value.forEach(p => {
      const otherKey = `ospite_${p.id || ''}_${itemId}`
      const other = assegCampoWeekend.value[otherKey]
      if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
        delete assegCampoWeekend.value[otherKey]
      }
    })
    squadreNonCensiteWeekend.value.forEach((_, i) => {
      if (i !== idx) {
        const ncKey = `noncensita_weekend_${i}_${itemId}`
        const other = assegCampoWeekend.value[ncKey]
        if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
          delete assegCampoWeekend.value[ncKey]
        }
      }
    })
  }
  const payload = {
    campo_id: itemId,
    nome_squadra_esterna: squadra.nome,
    tipo: 'esterna'
  }
  if (metacampo && metacampo !== 'FULL') payload.metacampo = metacampo
  assegCampoWeekend.value[key] = payload
}

let ncIdCounter = 0
function aggiungiSquadraNonCensita(contesto, ora) {
  if (contesto === 'settimanale') {
    squadreNonCensiteSettimanali.value.push({ id: ++ncIdCounter, nome: '', ora: ora || 'Senza orario', dataGiorno: giornoAttivo.value })
  } else {
    squadreNonCensiteWeekend.value.push({ id: ++ncIdCounter, nome: '', ora: ora || 'Senza orario' })
  }
}

function rimuoviSquadraNonCensita(idx, contesto) {
  if (contesto === 'settimanale') {
    const squadra = squadreNonCensiteSettimanali.value[idx]
    squadreNonCensiteSettimanali.value.splice(idx, 1)
    const keys = Object.keys(assegSpogliatoioSettimanali.value)
    keys.forEach(k => { if (k.startsWith(`noncensita_${squadra.id}_`)) delete assegSpogliatoioSettimanali.value[k] })
    const keys2 = Object.keys(assegCampoSettimanali.value)
    keys2.forEach(k => { if (k.startsWith(`noncensita_${squadra.id}_`)) delete assegCampoSettimanali.value[k] })
  } else {
    squadreNonCensiteWeekend.value.splice(idx, 1)
    const keys = Object.keys(assegSpogliatoioWeekend.value)
    keys.forEach(k => { if (k.startsWith(`noncensita_weekend_${idx}_`)) delete assegSpogliatoioWeekend.value[k] })
    const keys2 = Object.keys(assegCampoWeekend.value)
    keys2.forEach(k => { if (k.startsWith(`noncensita_weekend_${idx}_`)) delete assegCampoWeekend.value[k] })
  }
}

// ── Load data ──

// ── Default Week Helpers ──

function getAssegnazioneSpogliatoioDefault(catId, itemId, dataGiorno) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  return !!assegSpogliatoioDefault.value[key]
}

function isSpogliatoioOccupatoDefault(catId, itemId, dataGiorno) {
  const ora = getOraCategoria(catId)
  const dow = new Date(dataGiorno).getDay()
  return categorie.value.some(c =>
    c.id !== catId &&
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora &&
    !!assegSpogliatoioDefault.value[`${c.id}_${itemId}_${dataGiorno}`]
  )
}

function toggleAssegnazioneSpogliatoioDefault(catId, itemId, dataGiorno) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  if (assegSpogliatoioDefault.value[key]) {
    delete assegSpogliatoioDefault.value[key]
  } else {
    const ora = getOraCategoria(catId)
    const dow = new Date(dataGiorno).getDay()
    categorie.value.filter(c =>
      c.id !== catId &&
      (c.giorni || '').split(',').map(Number).includes(dow) &&
      (c.ora_allenamento || 'Senza orario') === ora
    ).forEach(c => {
      delete assegSpogliatoioDefault.value[`${c.id}_${itemId}_${dataGiorno}`]
    })
    assegSpogliatoioDefault.value[key] = {
      categoria_id: catId,
      spogliatoio_id: itemId,
      data: dataGiorno,
      tipo: 'casa',
      is_default: true
    }
  }
}

function getCampoAssegnatoDefault(catId, itemId, dataGiorno) {
  const a = assegCampoDefault.value[`${catId}_${itemId}_${dataGiorno}`]
  if (!a) return null
  return a.metacampo || 'FULL'
}

function getCampoLabelSuffissoDefault(catId, itemId, dataGiorno) {
  const asg = getCampoAssegnatoDefault(catId, itemId, dataGiorno)
  if (asg === 'A') return ' A'
  if (asg === 'B') return ' B'
  return ''
}

function isCampoOccupatoDefault(catId, itemId, dataGiorno, metacampo) {
  const ora = getOraCategoria(catId)
  const dow = new Date(dataGiorno).getDay()
  const allCats = categorie.value.filter(c =>
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  if (metacampo === 'A' || metacampo === 'B') {
    for (const c of allCats) {
      if (c.id === catId) continue
      const a = assegCampoDefault.value[`${c.id}_${itemId}_${dataGiorno}`]
      if (a && (a.metacampo == null || a.metacampo === 'FULL' || a.metacampo === metacampo)) return true
    }
    return false
  }
  for (const c of allCats) {
    if (c.id === catId) continue
    if (assegCampoDefault.value[`${c.id}_${itemId}_${dataGiorno}`]) return true
  }
  return false
}

function isCampoTuttoOccupatoDefault(catId, itemId, dataGiorno) {
  const ora = getOraCategoria(catId)
  const dow = new Date(dataGiorno).getDay()
  const allCats = categorie.value.filter(c =>
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  for (const c of allCats) {
    if (c.id === catId) continue
    const a = assegCampoDefault.value[`${c.id}_${itemId}_${dataGiorno}`]
    if (a && (a.metacampo == null || a.metacampo === 'FULL')) return true
  }
  return false
}

function toggleAssegnazioneCampoDefault(catId, itemId, dataGiorno, metacampo) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  const existing = assegCampoDefault.value[key]
  if (existing && (metacampo == null ? (existing.metacampo == null || existing.metacampo === 'FULL') : existing.metacampo === metacampo)) {
    delete assegCampoDefault.value[key]
    return
  }
  const ora = getOraCategoria(catId)
  const dow = new Date(dataGiorno).getDay()
  const categorieStessaFascia = categorie.value.filter(c =>
    c.id !== catId &&
    (c.giorni || '').split(',').map(Number).includes(dow) &&
    (c.ora_allenamento || 'Senza orario') === ora
  )
  if (metacampo == null || metacampo === 'FULL') {
    categorieStessaFascia.forEach(c => {
      delete assegCampoDefault.value[`${c.id}_${itemId}_${dataGiorno}`]
    })
  } else {
    categorieStessaFascia.forEach(c => {
      const otherKey = `${c.id}_${itemId}_${dataGiorno}`
      const other = assegCampoDefault.value[otherKey]
      if (other && (other.metacampo == null || other.metacampo === 'FULL' || other.metacampo === metacampo)) {
        delete assegCampoDefault.value[otherKey]
      }
    })
  }
  const payload = {
    campo_id: itemId,
    categoria_id: catId,
    tipo: 'casa',
    data: dataGiorno,
    is_default: true
  }
  if (metacampo && metacampo !== 'FULL') payload.metacampo = metacampo
  assegCampoDefault.value[key] = payload
}

function toggleCampoMenuDefault(catId, itemId, dataGiorno) {
  const key = `${catId}_${itemId}_${dataGiorno}`
  campoMenuDefaultAperto.value = campoMenuDefaultAperto.value === key ? null : key
}

function assegnaCampoDaMenuDefault(catId, itemId, dataGiorno, metacampo) {
  toggleAssegnazioneCampoDefault(catId, itemId, dataGiorno, metacampo)
  campoMenuDefaultAperto.value = null
}

// ── Load ──

async function loadSpogliatoi() {
  try {
    const res = await getSpogliatoi(societaAttiva.value?.id || null)
    spogliatoi.value = (res.data || []).filter(Boolean)
  } catch (e) {
    console.error('Errore caricamento spogliatoi:', e)
  }
}

async function loadCampi() {
  try {
    const res = await getCampi(societaAttiva.value?.id || null)
    campi.value = (res.data || []).filter(Boolean)
  } catch (e) {
    console.error('Errore caricamento campi:', e)
  }
}

async function loadCategorie() {
  try {
    const res = await getAllCategorie(societaAttiva.value?.id || null)
    categorie.value = (res.data || []).filter(Boolean)
  } catch (e) {
    console.error('Errore caricamento categorie:', e)
  }
}

async function loadWeekend() {
  try {
    const res = await getWeekend(societaAttiva.value?.id || null)
    weekend.value = (res.data || []).filter(Boolean)
  } catch (e) {
    console.error('Errore caricamento weekend:', e)
  }
}

async function caricaAssegnazioniSettimana() {
  assegSpogliatoioSettimanali.value = {}
  assegCampoSettimanali.value = {}
  squadreNonCensiteSettimanali.value = []
  try {
    const [spRes, caRes] = await Promise.all([
      getAssegnazioniSettimana(settimanaInizio.value),
      getCampiAssegnazioniSettimana(settimanaInizio.value)
    ])
    // Process spogliatoi
    const spData = spRes.data || []
    const nomiUnici = new Set()
    spData.forEach(a => {
      if (a.categoria_id) {
        const dataKey = a.data || settimanaInizio.value
        assegSpogliatoioSettimanali.value[`${a.categoria_id}_${a.spogliatoio_id}_${dataKey}`] = a
      } else if (a.nome_squadra_esterna) {
        const dataKey = a.data || settimanaInizio.value
        const existing = squadreNonCensiteSettimanali.value.find(s => s.nome === a.nome_squadra_esterna && s.dataGiorno === dataKey)
        if (!existing && !nomiUnici.has(a.nome_squadra_esterna + '_' + dataKey)) {
          nomiUnici.add(a.nome_squadra_esterna + '_' + dataKey)
          squadreNonCensiteSettimanali.value.push({ id: ++ncIdCounter, nome: a.nome_squadra_esterna, ora: 'Senza orario', dataGiorno: dataKey })
        }
      }
    })
    squadreNonCensiteSettimanali.value.forEach(squadra => {
      spData.forEach(a => {
        if (a.nome_squadra_esterna === squadra.nome) {
          const dataKey = a.data || settimanaInizio.value
          assegSpogliatoioSettimanali.value[`noncensita_${squadra.id}_${a.spogliatoio_id}_${dataKey}`] = a
        }
      })
    })
    // Process campi
    const caData = caRes.data || []
    const nomiUnici2 = new Set()
    caData.forEach(a => {
      if (a.categoria_id) {
        const dataKey = a.data || settimanaInizio.value
        assegCampoSettimanali.value[`${a.categoria_id}_${a.campo_id}_${dataKey}`] = a
      } else if (a.nome_squadra_esterna) {
        const dataKey = a.data || settimanaInizio.value
        const existing = squadreNonCensiteSettimanali.value.find(s => s.nome === a.nome_squadra_esterna && s.dataGiorno === dataKey)
        if (!existing && !nomiUnici2.has(a.nome_squadra_esterna + '_' + dataKey)) {
          nomiUnici2.add(a.nome_squadra_esterna + '_' + dataKey)
          squadreNonCensiteSettimanali.value.push({ id: ++ncIdCounter, nome: a.nome_squadra_esterna, ora: 'Senza orario', dataGiorno: dataKey })
        }
      }
    })
    squadreNonCensiteSettimanali.value.forEach(squadra => {
      caData.forEach(a => {
        if (a.nome_squadra_esterna === squadra.nome) {
          const dataKey = a.data || settimanaInizio.value
          assegCampoSettimanali.value[`noncensita_${squadra.id}_${a.campo_id}_${dataKey}`] = a
        }
      })
    })
    if (giorniSettimana.value.length > 0) {
      const firstDay = giorniSettimana.value.find(g => g.categorie.length > 0)
      if (firstDay) {
        giornoAttivo.value = firstDay.data
      } else {
        giornoAttivo.value = giorniSettimana.value[0].data
      }
    }
  } catch (e) {
    console.error('Errore caricamento assegnazioni settimanali:', e)
  }
}

async function caricaWeekendData() {
  assegSpogliatoioWeekend.value = {}
  assegCampoWeekend.value = {}
  weekendPartite.value = []
  weekendAllenamenti.value = []
  squadreNonCensiteWeekend.value = []
  if (!weekendSelezionatoId.value) return

  try {
    const [spRes, caRes, partiteRes] = await Promise.all([
      getAssegnazioniWeekend(weekendSelezionatoId.value),
      getCampiAssegnazioniWeekend(weekendSelezionatoId.value),
      getWeekendPartite(weekendSelezionatoId.value)
    ])
    weekendPartite.value = (partiteRes.data || []).filter(Boolean)

    // Process spogliatoi
    const spData = spRes.data || []
    const nomiUnici = new Set()
    spData.forEach(a => {
      if (a.categoria_id && a.tipo === 'ospite') {
        assegSpogliatoioWeekend.value[`ospite_${a.partita_id || ''}_${a.spogliatoio_id}`] = a
      } else if (a.categoria_id) {
        assegSpogliatoioWeekend.value[`casa_${a.partita_id || ''}_${a.spogliatoio_id}`] = a
      } else if (a.nome_squadra_esterna) {
        if (!nomiUnici.has(a.nome_squadra_esterna)) {
          nomiUnici.add(a.nome_squadra_esterna)
          squadreNonCensiteWeekend.value.push({ nome: a.nome_squadra_esterna })
        }
      }
    })
    squadreNonCensiteWeekend.value.forEach((squadra, idx) => {
      spData.forEach(a => {
        if (a.nome_squadra_esterna === squadra.nome) {
          assegSpogliatoioWeekend.value[`noncensita_weekend_${idx}_${a.spogliatoio_id}`] = a
        }
      })
    })

    // Process campi
    const caData = caRes.data || []
    const nomiUnici2 = new Set()
    caData.forEach(a => {
      if (a.categoria_id && a.tipo === 'ospite') {
        assegCampoWeekend.value[`ospite_${a.partita_id || ''}_${a.campo_id}`] = a
      } else if (a.categoria_id) {
        assegCampoWeekend.value[`casa_${a.partita_id || ''}_${a.campo_id}`] = a
      } else if (a.nome_squadra_esterna) {
        if (!nomiUnici2.has(a.nome_squadra_esterna)) {
          nomiUnici2.add(a.nome_squadra_esterna)
          squadreNonCensiteWeekend.value.push({ nome: a.nome_squadra_esterna })
        }
      }
    })
    squadreNonCensiteWeekend.value.forEach((squadra, idx) => {
      caData.forEach(a => {
        if (a.nome_squadra_esterna === squadra.nome) {
          assegCampoWeekend.value[`noncensita_weekend_${idx}_${a.campo_id}`] = a
        }
      })
    })
  } catch (e) {
    console.error('Errore caricamento assegnazioni weekend:', e)
  }
}

// ── Save ──

async function salvaAssegnazioniSettimana() {
  // Save spogliatoi
  for (const [, val] of Object.entries(assegSpogliatoioSettimanali.value)) {
    const payload = {
      ...val,
      data_inizio: settimanaInizio.value,
      societa_id: societaAttiva.value?.id || null
    }
    if (val.id) {
      await aggiornaAssegnazione(val.id, payload)
    } else {
      const res = await creaAssegnazione(payload)
      const key = Object.keys(assegSpogliatoioSettimanali.value).find(k => assegSpogliatoioSettimanali.value[k] === val)
      if (key) assegSpogliatoioSettimanali.value[key] = res.data
    }
  }
  // Save campi
  for (const [, val] of Object.entries(assegCampoSettimanali.value)) {
    const payload = {
      ...val,
      data_inizio: settimanaInizio.value,
      societa_id: societaAttiva.value?.id || null
    }
    if (val.id) {
      await aggiornaCampoAssegnazione(val.id, payload)
    } else {
      const res = await creaCampoAssegnazione(payload)
      const key = Object.keys(assegCampoSettimanali.value).find(k => assegCampoSettimanali.value[k] === val)
      if (key) assegCampoSettimanali.value[key] = res.data
    }
  }
  alert('Assegnazioni settimanali salvate!')
}

async function salvaAssegnazioniWeekend() {
  // Save spogliatoi
  for (const [, val] of Object.entries(assegSpogliatoioWeekend.value)) {
    const payload = {
      ...val,
      weekend_id: weekendSelezionatoId.value,
      societa_id: societaAttiva.value?.id || null
    }
    if (val.id) {
      await aggiornaAssegnazione(val.id, payload)
    } else {
      const res = await creaAssegnazione(payload)
      const key = Object.keys(assegSpogliatoioWeekend.value).find(k => assegSpogliatoioWeekend.value[k] === val)
      if (key) assegSpogliatoioWeekend.value[key] = res.data
    }
  }
  // Save campi
  for (const [, val] of Object.entries(assegCampoWeekend.value)) {
    const payload = {
      ...val,
      weekend_id: weekendSelezionatoId.value,
      societa_id: societaAttiva.value?.id || null
    }
    if (val.id) {
      await aggiornaCampoAssegnazione(val.id, payload)
    } else {
      const res = await creaCampoAssegnazione(payload)
      const key = Object.keys(assegCampoWeekend.value).find(k => assegCampoWeekend.value[k] === val)
      if (key) assegCampoWeekend.value[key] = res.data
    }
  }
  alert('Assegnazioni weekend salvate!')
}

// ── Default Week Save & Load ──

async function salvaAssegnazioniDefault() {
  // Clear existing default assignments
  const spRes = await getAssegnazioniDefault()
  const caRes = await getCampiAssegnazioniDefault()
  ;(spRes.data || []).forEach(a => { if (a.id) eliminaAssegnazione(a.id) })
  ;(caRes.data || []).forEach(a => { if (a.id) eliminaCampoAssegnazione(a.id) })

  // Save spogliatoi
  for (const [, val] of Object.entries(assegSpogliatoioDefault.value)) {
    await creaAssegnazione({
      ...val,
      societa_id: societaAttiva.value?.id || null,
      is_default: true
    })
  }
  // Save campi
  for (const [, val] of Object.entries(assegCampoDefault.value)) {
    await creaCampoAssegnazione({
      ...val,
      societa_id: societaAttiva.value?.id || null,
      is_default: true
    })
  }
  alert('Settimana tipo salvata!')
  await caricaAssegnazioniDefault()
}

async function caricaAssegnazioniDefault() {
  assegSpogliatoioDefault.value = {}
  assegCampoDefault.value = {}
  haSettimanaTipo.value = false
  try {
    const [spRes, caRes] = await Promise.all([
      getAssegnazioniDefault(),
      getCampiAssegnazioniDefault()
    ])
    const spData = spRes.data || []
    const caData = caRes.data || []
    if (spData.length > 0 || caData.length > 0) {
      haSettimanaTipo.value = true
    }
    spData.forEach(a => {
      const dataKey = a.data || getLunesdiCorrente()
      const key = `${a.categoria_id}_${a.spogliatoio_id}_${dataKey}`
      assegSpogliatoioDefault.value[key] = a
    })
    caData.forEach(a => {
      const dataKey = a.data || getLunesdiCorrente()
      const key = `${a.categoria_id}_${a.campo_id}_${dataKey}`
      assegCampoDefault.value[key] = a
    })
    if (giorniDefault.value.length > 0 && !giornoDefaultAttivo.value) {
      const oggi = new Date().toISOString().split('T')[0]
      const todayMatch = giorniDefault.value.find(g => g.data === oggi)
      giornoDefaultAttivo.value = todayMatch ? todayMatch.data : giorniDefault.value[0].data
    }
  } catch (e) {
    console.error('Errore caricamento settimana tipo:', e)
  }
}

async function applicaSettimanaTipo() {
  if (!haSettimanaTipo.value) {
    alert('Nessuna settimana tipo configurata. Vai su "Settimana Tipo" per crearla.')
    return
  }
  if (!confirm('Applicare la settimana tipo a questa settimana? Sostituirà le assegnazioni esistenti.')) return
  try {
    await applyDefaultWeekSpogliatoi(settimanaInizio.value)
    await applyDefaultWeekCampi(settimanaInizio.value)
    await caricaAssegnazioniSettimana()
    alert('Settimana tipo applicata!')
  } catch (e) {
    console.error('Errore applicazione settimana tipo:', e)
    alert('Errore nell\'applicazione della settimana tipo.')
  }
}

// ── Modal CRUD ──

function apriModal(item, tipo) {
  if (item) {
    modal.value = { show: true, id: item.id, tipo: tipo, etichetta: item.etichetta, ordine: item.ordine || 0, tipo_campo: item.tipo_campo || '11' }
  } else {
    const list = tipo === 'spogliatoi' ? spogliatoi.value : campi.value
    modal.value = { show: true, id: null, tipo: tipo, etichetta: '', ordine: list.length, tipo_campo: '11' }
  }
}

async function salvaModal() {
  const payload = { ...modal.value, societa_id: societaAttiva.value?.id || null }
  if (modal.value.tipo === 'spogliatoi') {
    if (modal.value.id) {
      await aggiornaSpogliatoio(modal.value.id, payload)
    } else {
      await creaSpogliatoio(payload)
    }
    await loadSpogliatoi()
  } else {
    if (modal.value.id) {
      await aggiornaCampo(modal.value.id, payload)
    } else {
      await creaCampo(payload)
    }
    await loadCampi()
  }
  modal.value.show = false
}

async function eliminaFn(id, tipo) {
  if (!confirm('Eliminare questo elemento e le sue assegnazioni?')) return
  if (tipo === 'spogliatoi') {
    await eliminaSpogliatoio(id)
    await loadSpogliatoi()
  } else {
    await eliminaCampo(id)
    await loadCampi()
  }
}

function esc(s) {
  if (s == null) return ''
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
}

function stampa() {
  window.print()
}

function stampaGiornoSingolo(dataGiorno) {
  if (!dataGiorno) return
  const w = window.open('', '_blank', 'noopener,noreferrer')
  const g = giorniSettimana.value.find(d => d.data === dataGiorno)
  if (!g) return
  const slots = categoriePerOrario(dataGiorno)
  let html = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${esc(g.nomeLungo)} ${esc(g.giorno)}</title>
  <style>
    body { font-family: -apple-system, sans-serif; margin: 20px; color: #111; }
    h1 { font-size: 18px; margin: 0 0 4px; }
    h2 { font-size: 13px; margin: 0 0 16px; color: #555; font-weight: 400; }
    .slot { margin-bottom: 14px; }
    .slot-title { font-size: 13px; font-weight: 700; margin-bottom: 4px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
    th { background: #f3f4f6; font-weight: 700; font-size: 13px; }
    th.spo { background: #6366f1; color: #fff; }
    th.cam { background: #10b981; color: #fff; }
    .spo-chip { display: inline-block; background: #6366f1; color: #fff; padding: 2px 8px; border-radius: 999px; font-size: 12px; font-weight: 600; margin: 1px; }
    .cam-chip { display: inline-block; background: #10b981; color: #fff; padding: 2px 8px; border-radius: 999px; font-size: 12px; font-weight: 600; margin: 1px; }
    .cat-anno { font-weight: 700; font-size: 13px; }
    .cat-nome { color: #555; font-size: 12px; }
    @media print {
      body { margin: 10px; }
      * { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
    }
  </style></head><body>
  <h1>${esc(g.nomeLungo)} ${esc(g.giorno)}</h1>
  <h2>${esc(societaAttiva?.value?.nome || '')} - Assegnazioni Spogliatoi e Campi</h2>`
  for (const [ora, cats] of Object.entries(slots)) {
    html += `<div class="slot"><div class="slot-title">${esc(ora || 'Senza orario')}</div><table>
      <tr><th>Categoria</th><th class="spo">Spogliatoio</th><th class="cam">Campo da gioco</th></tr>`
    for (const cat of cats) {
      const spoItems = spogliatoi.value.filter(item => getAssegnazioneSpogliatoioGiorno(cat.id, item.id, dataGiorno))
      const camFull = campi.value.filter(item => getAssegnazioneCampoGiorno(cat.id, item.id, dataGiorno, null))
      const camA = campi.value.filter(item => getAssegnazioneCampoGiorno(cat.id, item.id, dataGiorno, 'A'))
      const camB = campi.value.filter(item => getAssegnazioneCampoGiorno(cat.id, item.id, dataGiorno, 'B'))
      const camChips = [...camFull.map(i => `<span class="cam-chip">${esc(i.etichetta)}</span>`), ...camA.map(i => `<span class="cam-chip">${esc(i.etichetta)} A</span>`), ...camB.map(i => `<span class="cam-chip">${esc(i.etichetta)} B</span>`)]
      html += `<tr>
        <td><span class="cat-anno">${esc(cat.anno)}</span> <span class="cat-nome">${esc(cat.nome)}</span></td>
        <td>${spoItems.map(i => `<span class="spo-chip">${esc(i.etichetta)}</span>`).join(' ') || '—'}</td>
        <td>${camChips.join(' ') || '—'}</td>
      </tr>`
    }
    const ncSquadre = squadreNonCensiteSettimanali.value.filter(s => s.ora === ora && s.dataGiorno === dataGiorno)
    for (const squadra of ncSquadre) {
      const gidx = squadreNonCensiteSettimanali.value.findIndex(s => s.id === squadra.id)
      const spoItems = spogliatoi.value.filter(item => getAssegnazioneSpogliatoioNonCensitaGiorno(gidx, item.id, dataGiorno))
      const camFull = campi.value.filter(item => getAssegnazioneCampoNonCensitaGiorno(gidx, item.id, dataGiorno, null))
      const camA = campi.value.filter(item => getAssegnazioneCampoNonCensitaGiorno(gidx, item.id, dataGiorno, 'A'))
      const camB = campi.value.filter(item => getAssegnazioneCampoNonCensitaGiorno(gidx, item.id, dataGiorno, 'B'))
      const camChips = [...camFull.map(i => `<span class="cam-chip">${esc(i.etichetta)}</span>`), ...camA.map(i => `<span class="cam-chip">${esc(i.etichetta)} A</span>`), ...camB.map(i => `<span class="cam-chip">${esc(i.etichetta)} B</span>`)]
      html += `<tr>
        <td>${esc(squadra.nome || 'Squadra non censita')}</td>
        <td>${spoItems.map(i => `<span class="spo-chip">${esc(i.etichetta)}</span>`).join(' ') || '—'}</td>
        <td>${camChips.join(' ') || '—'}</td>
      </tr>`
    }
    html += `</table></div>`
  }
  html += `</body></html>`
  w.document.write(html)
  w.document.close()
  w.print()
}

onMounted(() => {
  loadSpogliatoi()
  loadCampi()
  loadCategorie()
  loadWeekend()
  caricaAssegnazioniSettimana()
  caricaAssegnazioniDefault()
  // Auto-select today's day
  const oggi = new Date().toISOString().split('T')[0]
  if (giorniSettimana.value.length > 0) {
    const todayMatch = giorniSettimana.value.find(g => g.data === oggi)
    giornoAttivo.value = todayMatch ? todayMatch.data : giorniSettimana.value[0].data
  }
})
</script>

<style scoped>
.spogliatoi-page {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1.5rem;
  animation: slideUp 0.4s ease-out;
}

.header-content {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
}

.btn-back {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.btn-back:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-back svg {
  width: 20px;
  height: 20px;
  color: var(--color-text);
}

.header-content h1 {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: -0.02em;
  margin-bottom: 0.25rem;
}

.page-subtitle {
  color: var(--color-text-muted);
  font-size: 1rem;
}

/* Items sections */
.items-section {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.items-section-label {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  font-size: 0.8125rem;
  font-weight: 700;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin-right: 0.25rem;
}

.btn-add-chip {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.625rem;
  background: none;
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-full);
  color: var(--color-text-muted);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-add-chip:hover {
  color: var(--color-primary);
  border-color: var(--color-primary);
}

/* Items list */
.items-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  padding: 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
}

.item-chip {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.75rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-full);
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-text);
}

.campo-tipo-badge {
  font-size: 0.6875rem;
  color: #10b981;
  font-weight: 700;
}

.campo-menu-wrapper {
  position: relative;
  display: inline-block;
}

.campo-chip-main {
  display: inline-flex !important;
  align-items: center;
  gap: 0.25rem;
  cursor: pointer;
}

.campo-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  z-index: 100;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  min-width: 130px;
  margin-top: 4px;
  overflow: hidden;
}

.campo-dropdown-item {
  padding: 0.5rem 0.75rem;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  color: var(--color-text);
  transition: all var(--transition-fast);
}

.campo-dropdown-item:hover:not(.disabled):not(.active) {
  background: var(--color-surface-elevated);
  color: var(--color-primary);
}

.campo-dropdown-item.active {
  background: var(--color-primary);
  color: white;
}

.campo-dropdown-item.disabled {
  opacity: 0.3;
  cursor: not-allowed;
}

.campo-dropdown-item.rimuovi {
  border-top: 1px solid var(--color-border);
  color: #ef4444;
}

.campo-dropdown-item.rimuovi:hover {
  background: rgba(239,68,68,0.1);
}

.form-select {
  width: 100%;
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
}

.btn-icon-xs {
  width: 18px;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  cursor: pointer;
  color: var(--color-text-muted);
  border-radius: 50%;
  transition: all var(--transition-fast);
}

.btn-icon-xs:hover { color: var(--color-text); background: var(--color-border); }
.btn-icon-xs.btn-delete:hover { color: #ef4444; background: rgba(239,68,68,0.1); }

.btn-add-sm {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.75rem;
  background: none;
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-full);
  color: var(--color-text-muted);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  margin-bottom: 1rem;
}

.btn-add-sm:hover {
  color: var(--color-primary);
  border-color: var(--color-primary);
}

/* Tabs */
.tabs-bar {
  display: flex;
  gap: 0.25rem;
  margin-bottom: 1.5rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 0.375rem;
}

.tab-btn {
  flex: 1;
  padding: 0.625rem 1rem;
  background: none;
  border: none;
  border-radius: var(--radius-md);
  color: var(--color-text-muted);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.tab-btn.active {
  background: var(--color-primary);
  color: white;
}

.tab-btn:hover:not(.active) {
  color: var(--color-text);
  background: var(--color-surface-elevated);
}

/* Week selector */
.week-selector {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.week-label {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--color-text);
  min-width: 280px;
  text-align: center;
}

.btn-nav {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-nav:hover {
  background: var(--color-primary);
  border-color: var(--color-primary);
}

.btn-nav:hover svg { color: white; }
.btn-nav svg { color: var(--color-text-muted); }

.btn-save {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 0.875rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-save:hover { opacity: 0.9; }
.btn-save svg { color: white; }

/* Weekend selector */
.weekend-selector {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.filter-select {
  padding: 0.5rem 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
  min-width: 300px;
}

/* Day tabs */
.day-tabs {
  display: flex;
  gap: 0.25rem;
  margin-bottom: 1rem;
  overflow-x: auto;
  padding-bottom: 0.25rem;
}

.day-tab {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0.5rem 1rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  min-width: 60px;
}

.day-tab.active {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

.day-tab.empty {
  opacity: 0.4;
}

.day-name {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}

.day-date {
  font-size: 1rem;
  font-weight: 700;
}

.day-count {
  font-size: 0.625rem;
  background: var(--color-primary);
  color: white;
  border-radius: 10px;
  padding: 1px 6px;
  margin-top: 2px;
}

.day-tab.active .day-count {
  background: white;
  color: var(--color-primary);
}

/* Time slot sections */
.time-slot-section {
  margin-bottom: 1.5rem;
}

.time-slot-header {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text);
  margin-bottom: 0.5rem;
  padding: 0.25rem 0.5rem;
  background: var(--color-surface);
  border-radius: var(--radius-sm);
  display: inline-block;
}

/* 3-column table */
.assegnazioni-table {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  overflow: hidden;
  margin-bottom: 1rem;
}

.table-header {
  display: grid;
  grid-template-columns: 180px 1fr 1fr;
  background: var(--color-surface);
}

.table-header > div {
  padding: 0.625rem 0.75rem;
  font-weight: 700;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border-bottom: 2px solid var(--color-border);
}

.table-header .col-spo {
  color: #6366f1;
  border-bottom-color: #6366f1;
  background: rgba(99,102,241,0.05);
}

.table-header .col-campo {
  color: #10b981;
  border-bottom-color: #10b981;
  background: rgba(16,185,129,0.05);
}

.table-row {
  display: grid;
  grid-template-columns: 180px 1fr 1fr;
}

.table-row > div {
  padding: 0.5rem 0.75rem;
  border-bottom: 1px solid var(--color-border);
  border-right: 1px solid var(--color-border);
}

.table-row > div:nth-child(3) {
  border-right: none;
}

.table-row:last-child > div {
  border-bottom: none;
}

.col-cat {
  display: flex;
  flex-direction: column;
  gap: 2px;
  background: var(--color-surface);
  font-weight: 600;
  justify-content: center;
}

.multi-select {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
  align-items: center;
}

.select-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.625rem;
  border-radius: var(--radius-full);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  border: 1px solid var(--color-border);
  background: var(--color-bg);
  color: var(--color-text-muted);
  user-select: none;
}

.select-chip:hover {
  border-color: var(--color-primary);
  color: var(--color-text);
}

.select-chip.active {
  color: white;
  border-color: transparent;
}

.col-spo .select-chip.active {
  background: #6366f1;
}

.col-campo .select-chip.active {
  background: #10b981;
}

.select-chip.occupied {
  opacity: 0.35;
  cursor: not-allowed;
  position: relative;
}

.select-chip.occupied::after {
  content: '🔒';
  font-size: 0.6rem;
  margin-left: 0.25rem;
}

.no-items {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  font-style: italic;
}

/* Print chips */
.print-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
  align-items: center;
}

.print-chip {
  display: inline-block;
  padding: 0.125rem 0.5rem;
  border-radius: var(--radius-full);
  font-size: 0.6875rem;
  font-weight: 600;
}

.print-chip.spo-chip {
  background: #6366f1;
  color: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

.print-chip.campo-chip {
  background: #10b981;
  color: #fff;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

.cat-anno {
  font-size: 0.875rem;
  font-weight: 700;
}

.cat-nome {
  font-size: 0.6875rem;
  color: var(--color-text-muted);
}

.assignment-cell {
  cursor: pointer;
  transition: all var(--transition-fast);
  background: var(--color-surface);
}

.assignment-cell:hover {
  background: var(--color-primary-light);
}

.assignment-cell.assigned {
  background: var(--color-primary);
}

.assignment-cell.assigned svg {
  color: white;
}

/* Non censite */
.non-censite-row .cat-cell {
  flex-direction: row;
  gap: 0.5rem;
  padding: 0.375rem;
}

.non-censita-input {
  flex: 1;
  padding: 0.25rem 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  font-size: 0.75rem;
  background: var(--color-bg);
  color: var(--color-text);
}

.btn-rimuovi-squadra {
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  cursor: pointer;
  color: #ef4444;
  border-radius: 50%;
  flex-shrink: 0;
}

.btn-add-squadra {
  background: none;
  border: none;
  color: var(--color-text-muted);
  font-size: 0.75rem;
  cursor: pointer;
  padding: 0.25rem 0.5rem;
  border-radius: var(--radius-sm);
}

.btn-add-squadra:hover {
  color: var(--color-primary);
}

.add-row .grid-cell {
  border-bottom: none;
}

/* Weekend info */
.weekend-info {
  margin-bottom: 1.5rem;
}

.info-section {
  margin-bottom: 1rem;
}

.info-section h3 {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text);
  margin-bottom: 0.5rem;
}

.partita-info-chip, .allenamento-info-chip {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0.75rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  margin-bottom: 0.375rem;
  font-size: 0.8125rem;
}

.chip-cat {
  font-weight: 700;
  color: var(--color-primary);
}

.tipo-badge {
  font-size: 0.625rem;
  padding: 1px 6px;
  border-radius: 10px;
  font-weight: 600;
  text-transform: uppercase;
}

.tipo-badge.casa {
  background: rgba(16,185,129,0.1);
  color: #10b981;
}

.tipo-badge.fuori {
  background: rgba(239,68,68,0.1);
  color: #ef4444;
}

/* Empty state */
.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--color-text-muted);
}

/* Modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal {
  background: var(--color-surface);
  border-radius: var(--radius-xl);
  width: 90%;
  max-width: 420px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--color-border);
}

.modal-header h3 {
  font-size: 1rem;
  font-weight: 700;
}

.modal-close {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  cursor: pointer;
  color: var(--color-text-muted);
  border-radius: 50%;
}

.modal-close:hover {
  background: var(--color-border);
}

.modal-body {
  padding: 1.5rem;
}

.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-text);
  margin-bottom: 0.375rem;
}

.form-group input {
  width: 100%;
  padding: 0.5rem 0.75rem;
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.875rem;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--color-border);
}

.btn-secondary {
  padding: 0.5rem 1rem;
  background: var(--color-surface-elevated);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}

.btn-primary {
  padding: 0.5rem 1rem;
  background: var(--color-primary);
  border: none;
  border-radius: var(--radius-md);
  color: white;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}

/* Print */
.print-header {
  display: none;
}

.print-team-name {
  display: none;
}

.print-all-days {
  display: none;
}

@media print {
  .print-header {
    display: none !important;
  }

  .page-header,
  .items-list,
  .btn-add-sm,
  .tabs-bar,
  .week-selector button,
  .weekend-selector,
  .btn-save,
  .btn-add-squadra,
  .btn-rimuovi-squadra,
  .add-row,
  .non-censita-input,
  .day-tabs,
  .section-toggle {
    display: none !important;
  }

  .week-label {
    display: inline !important;
  }

  .print-team-name {
    display: inline !important;
    font-size: 10px;
  }
  .empty-state,
  .modal-overlay,
  .modal,
  .time-slot-section,
  .day-view {
    display: none !important;
  }

  .print-all-days {
    display: block !important;
  }

  .print-day-section {
    page-break-inside: avoid;
    page-break-after: always;
    margin-bottom: 1rem;
  }

  .print-day-section:last-child {
    page-break-after: auto;
  }

  .print-day-header {
    font-size: 14px;
    font-weight: 700;
    color: #111;
    margin-bottom: 4px;
    padding: 4px 8px;
    background: #f3f4f6;
  }

  .print-time-slot {
    font-size: 12px;
    font-weight: 700;
    color: #333;
    margin-bottom: 2px;
    padding: 2px 8px;
    display: inline-block;
  }

  .spogliatoi-page {
    padding: 0 !important;
    max-width: 100% !important;
  }

  .assegnazioni-grid {
    font-size: 10px !important;
    page-break-inside: avoid;
  }

  .grid-cell {
    padding: 6px 10px !important;
    border: 1px solid #ccc !important;
    font-size: 13px !important;
  }

  .grid-header .grid-cell {
    background: #f3f4f6 !important;
    color: #111 !important;
    font-weight: 700;
  }

  .assignment-cell.assigned::after {
    content: '✓';
    font-weight: 700;
    color: #111;
  }

  .assignment-cell.assigned svg {
    display: none !important;
  }

  .weekend-info {
    page-break-inside: avoid;
    margin-bottom: 1rem;
  }

  .weekend-info h3 {
    font-size: 12px;
    margin-bottom: 4px;
  }

  .partita-info-chip, .allenamento-info-chip {
    font-size: 10px;
    padding: 3px 6px;
  }

  .week-selector {
    margin-bottom: 0.5rem;
  }

  .assegnazioni-table {
    font-size: 13px !important;
    page-break-inside: avoid;
  }

  .table-header > div {
    background: #f3f4f6 !important;
    color: #111 !important;
    font-weight: 700 !important;
    padding: 6px 10px !important;
    font-size: 13px !important;
  }

  .table-header .col-spo {
    background: #6366f1 !important;
    color: #fff !important;
    border-bottom-color: #6366f1 !important;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .table-header .col-campo {
    background: #10b981 !important;
    color: #fff !important;
    border-bottom-color: #10b981 !important;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .print-chip {
    font-size: 12px !important;
    padding: 2px 8px !important;
    font-weight: 700 !important;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .print-chip.spo-chip {
    background: #6366f1 !important;
    color: #fff !important;
  }

  .print-chip.campo-chip {
    background: #10b981 !important;
    color: #fff !important;
  }
}

.btn-default-apply {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 1rem;
  background: linear-gradient(135deg, #f59e0b, #d97706);
  color: #fff;
  border: none;
  border-radius: var(--radius-md);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
  white-space: nowrap;
}

.btn-default-apply:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
}

.btn-default-apply:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.default-info-banner {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.1), rgba(217, 119, 6, 0.05));
  border: 1px solid rgba(245, 158, 11, 0.2);
  border-radius: var(--radius-md);
  margin-bottom: 1rem;
  font-size: 0.875rem;
  color: #92400e;
}

.default-info-banner svg {
  flex-shrink: 0;
  color: #f59e0b;
}
</style>
