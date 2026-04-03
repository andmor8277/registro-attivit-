<template>
  <div class="allenamenti-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/scelta/' + route.params.id)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>
        </button>
        <button class="btn-home" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
        </button>
      </div>
      <span class="titolo-toolbar">Allenamenti — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
    </header>

    <div class="allenamenti-body">
      <div class="month-nav">
        <button class="nav-btn" @click="prevMonth"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"/></svg></button>
        <div class="current-month">{{ currentMonthName }} {{ currentYear }}</div>
        <button class="nav-btn" @click="nextMonth"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg></button>
      </div>

      <div class="weeks-grid">
        <div v-for="week in weeksInMonth" :key="week.num" class="week-card" :class="{ active: selectedWeek?.num === week.num }" @click="selectWeek(week)">
          <div class="week-header">Settimana {{ week.num }}</div>
          <div class="week-dates">{{ formatDateRange(week.start, week.end) }}</div>
          <div class="week-days">
            <span v-for="day in week.days" :key="day.date" class="day-chip" :class="{ 'has-training': day.isSelectable, 'today': day.isToday, 'other-month': day.month !== currentMonth }" @click.stop="selectDay(day)">{{ day.dayNum }}</span>
          </div>
        </div>
      </div>

      <div v-if="selectedDay" class="day-detail">
        <div class="day-header">
          <h3>Allenamento del {{ formatDate(selectedDay.data) }}</h3>
          <button class="btn-add-exercise" @click="addEsercizio">+ Esercizio</button>
          <button class="btn-save-exercise" @click="saveCurrentExercise" title="Salva">💾 Salva</button>
          <button class="btn-save-exercise" @click="exportPdf" title="Esporta PDF">📄 PDF</button>
        </div>

        <div class="esercizi-list">
          <div v-for="(ex, idx) in esercizi" :key="ex.id" class="esercizio-card" :class="{ active: selectedExercise?.id === ex.id }" :data-ex-id="ex.id" @click="selectExercise(ex)">
            <div class="esercizio-header">
              <span class="esercizio-num">{{ idx + 1 }}</span>
              <input v-model="ex.titolo" class="esercizio-titolo" placeholder="Titolo esercizio..." @change="saveEsercizio(ex)" />
              <button class="btn-toggle-lines" :class="{ active: ex.campo_con_righe }" @click="toggleFieldLines(ex)" title="Mostra righe">⚽</button>
              <button class="btn-delete" @click="deleteEsercizio(ex)">×</button>
            </div>

            <div class="board-area">
              <div class="board-main">
                <div class="tools-panel">
                  <div class="tools-section">
                    <div class="tools-label">GIOCATORI</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'player-red' }" @click="selectTool('player-red')" title="Giocatore Rosso">
                        <span class="tool-shape player-red"></span>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'player-blue' }" @click="selectTool('player-blue')" title="Giocatore Blu">
                        <span class="tool-shape player-blue"></span>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'player-yellow' }" @click="selectTool('player-yellow')" title="Giocatore Giallo">
                        <span class="tool-shape player-yellow"></span>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'player-green' }" @click="selectTool('player-green')" title="Giocatore Verde">
                        <span class="tool-shape player-green"></span>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'player-white' }" @click="selectTool('player-white')" title="Giocatore Bianco">
                        <span class="tool-shape player-white"></span>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'player-black' }" @click="selectTool('player-black')" title="Giocatore Nero">
                        <span class="tool-shape player-black"></span>
                      </button>
                    </div>
                  </div>
                  
                  <div class="tools-section">
                    <div class="tools-label">PORTE</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'goal-large' }" @click="selectTool('goal-large')" title="Porta Intera">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="4" y="6" width="16" height="14" fill="none" stroke="#fff" stroke-width="2"/><line x1="4" y1="6" x2="4" y2="20" stroke="#fff" stroke-width="2"/><line x1="20" y1="6" x2="20" y2="20" stroke="#fff" stroke-width="2"/><line x1="4" y1="20" x2="20" y2="20" stroke="#fff" stroke-width="2"/><line x1="6" y1="8" x2="18" y2="8" stroke="#aaa" stroke-width="0.5"/><line x1="6" y1="11" x2="18" y2="11" stroke="#aaa" stroke-width="0.5"/><line x1="6" y1="14" x2="18" y2="14" stroke="#aaa" stroke-width="0.5"/><line x1="6" y1="17" x2="18" y2="17" stroke="#aaa" stroke-width="0.5"/><line x1="8" y1="6" x2="8" y2="20" stroke="#aaa" stroke-width="0.5"/><line x1="12" y1="6" x2="12" y2="20" stroke="#aaa" stroke-width="0.5"/><line x1="16" y1="6" x2="16" y2="20" stroke="#aaa" stroke-width="0.5"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'goal-small' }" @click="selectTool('goal-small')" title="Porticina">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="6" y="10" width="12" height="8" fill="none" stroke="#fff" stroke-width="2"/><line x1="6" y1="10" x2="6" y2="18" stroke="#fff" stroke-width="2"/><line x1="18" y1="10" x2="18" y2="18" stroke="#fff" stroke-width="2"/><line x1="6" y1="18" x2="18" y2="18" stroke="#fff" stroke-width="2"/><line x1="8" y1="11" x2="16" y2="11" stroke="#aaa" stroke-width="0.5"/><line x1="8" y1="14" x2="16" y2="14" stroke="#aaa" stroke-width="0.5"/><line x1="10" y1="10" x2="10" y2="18" stroke="#aaa" stroke-width="0.5"/><line x1="14" y1="10" x2="14" y2="18" stroke="#aaa" stroke-width="0.5"/></svg>
                      </button>
                    </div>
                  </div>
                  
                  <div class="tools-section">
                    <div class="tools-label">PALLONI</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'ball' }" @click="selectTool('ball')" title="Pallone Bianco/Nero">
                        <svg viewBox="0 0 24 24" class="tool-icon">
                          <circle cx="12" cy="12" r="10" fill="#fff" stroke="#000" stroke-width="2"/>
                          <polygon points="12,7 8,10 8,14 12,17 16,14 16,10" fill="#000"/>
                          <polygon points="7,8 4,11 4,13 7,16" fill="#000"/>
                          <polygon points="17,8 20,11 20,13 17,16" fill="#000"/>
                          <polygon points="8,5 5,9 5,11 8,14" fill="#000"/>
                          <polygon points="16,5 19,9 19,11 16,14" fill="#000"/>
                        </svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ball-blue' }" @click="selectTool('ball-blue')" title="Pallone Blu">
                        <svg viewBox="0 0 24 24" class="tool-icon">
                          <circle cx="12" cy="12" r="10" fill="#fff" stroke="#003399" stroke-width="2"/>
                          <polygon points="12,7 8,10 8,14 12,17 16,14 16,10" fill="#003399"/>
                          <polygon points="7,8 4,11 4,13 7,16" fill="#003399"/>
                          <polygon points="17,8 20,11 20,13 17,16" fill="#003399"/>
                          <polygon points="8,5 5,9 5,11 8,14" fill="#003399"/>
                          <polygon points="16,5 19,9 19,11 16,14" fill="#003399"/>
                        </svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ball-red' }" @click="selectTool('ball-red')" title="Pallone Rosso">
                        <svg viewBox="0 0 24 24" class="tool-icon">
                          <circle cx="12" cy="12" r="10" fill="#fff" stroke="#990000" stroke-width="2"/>
                          <polygon points="12,7 8,10 8,14 12,17 16,14 16,10" fill="#cc0000"/>
                          <polygon points="7,8 4,11 4,13 7,16" fill="#cc0000"/>
                          <polygon points="17,8 20,11 20,13 17,16" fill="#cc0000"/>
                          <polygon points="8,5 5,9 5,11 8,14" fill="#cc0000"/>
                          <polygon points="16,5 19,9 19,11 16,14" fill="#cc0000"/>
                        </svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ball-yellow' }" @click="selectTool('ball-yellow')" title="Pallone Giallo">
                        <svg viewBox="0 0 24 24" class="tool-icon">
                          <circle cx="12" cy="12" r="10" fill="#ffd700" stroke="#000" stroke-width="2"/>
                          <polygon points="12,7 8,10 8,14 12,17 16,14 16,10" fill="#000"/>
                          <polygon points="7,8 4,11 4,13 7,16" fill="#000"/>
                          <polygon points="17,8 20,11 20,13 17,16" fill="#000"/>
                          <polygon points="8,5 5,9 5,11 8,14" fill="#000"/>
                          <polygon points="16,5 19,9 19,11 16,14" fill="#000"/>
                        </svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ball-orange' }" @click="selectTool('ball-orange')" title="Pallone Arancione">
                        <svg viewBox="0 0 24 24" class="tool-icon">
                          <circle cx="12" cy="12" r="10" fill="#fff" stroke="#cc4400" stroke-width="2"/>
                          <polygon points="12,7 8,10 8,14 12,17 16,14 16,10" fill="#ff6600"/>
                          <polygon points="7,8 4,11 4,13 7,16" fill="#ff6600"/>
                          <polygon points="17,8 20,11 20,13 17,16" fill="#ff6600"/>
                          <polygon points="8,5 5,9 5,11 8,14" fill="#ff6600"/>
                          <polygon points="16,5 19,9 19,11 16,14" fill="#ff6600"/>
                        </svg>
                      </button>
                    </div>
                  </div>
                  
                  <div class="tools-section">
                    <div class="tools-label">CONI</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'cone' }" @click="selectTool('cone')" title="Cono Arancione">
                        <svg viewBox="0 0 24 24" class="tool-icon"><polygon points="12,2 21,22 3,22" fill="#ff6600" stroke="#000" stroke-width="1.5"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'cone-small' }" @click="selectTool('cone-small')" title="Cono Piccolo">
                        <svg viewBox="0 0 24 24" class="tool-icon"><polygon points="12,6 18,22 6,22" fill="#eab308" stroke="#000" stroke-width="1.5"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'cone-striped' }" @click="selectTool('cone-striped')" title="Cono Strisciato">
                        <svg viewBox="0 0 24 24" class="tool-icon"><polygon points="12,2 21,22 3,22" fill="#fff" stroke="#000" stroke-width="1.5"/><line x1="12" y1="8" x2="16" y2="16" stroke="#ef4444" stroke-width="2"/><line x1="12" y1="8" x2="8" y2="16" stroke="#3b82f6" stroke-width="2"/></svg>
                      </button>
                    </div>
                  </div>
                  
                  <div class="tools-section">
                    <div class="tools-label">PALETTI</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'pole-red' }" @click="selectTool('pole-red')" title="Paletto Rosso">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="10" y="8" width="4" height="14" fill="#ef4444"/><rect x="6" y="18" width="12" height="4" rx="1" fill="#666"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'pole-yellow' }" @click="selectTool('pole-yellow')" title="Paletto Giallo">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="10" y="8" width="4" height="14" fill="#eab308"/><rect x="6" y="18" width="12" height="4" rx="1" fill="#666"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'pole-white' }" @click="selectTool('pole-white')" title="Paletto Bianco">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="10" y="4" width="4" height="18" fill="#fff" stroke="#000" stroke-width="1"/><rect x="6" y="18" width="12" height="4" rx="1" fill="#666"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'flag-red' }" @click="selectTool('flag-red')" title="Bandierina Rossa">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="12" y1="4" x2="12" y2="22" stroke="#666" stroke-width="1.5"/><path d="M12,4 L20,8 L12,12 Z" fill="#ef4444" stroke="#000" stroke-width="1"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'flag-yellow' }" @click="selectTool('flag-yellow')" title="Bandierina Gialla">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="12" y1="4" x2="12" y2="22" stroke="#666" stroke-width="1.5"/><path d="M12,4 L20,8 L12,12 Z" fill="#eab308" stroke="#000" stroke-width="1"/></svg>
                      </button>
                    </div>
                  </div>
                  
                  <div class="tools-section">
                    <div class="tools-label">DISCHI</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'disk-orange' }" @click="selectTool('disk-orange')" title="Disco Arancione">
                        <svg viewBox="0 0 24 24" class="tool-icon"><ellipse cx="12" cy="14" rx="10" ry="4" fill="#ff6600" stroke="#000" stroke-width="1.5"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'disk-blue' }" @click="selectTool('disk-blue')" title="Disco Blu">
                        <svg viewBox="0 0 24 24" class="tool-icon"><ellipse cx="12" cy="14" rx="10" ry="4" fill="#3b82f6" stroke="#000" stroke-width="1.5"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'disk-yellow' }" @click="selectTool('disk-yellow')" title="Disco Giallo">
                        <svg viewBox="0 0 24 24" class="tool-icon"><ellipse cx="12" cy="14" rx="10" ry="4" fill="#eab308" stroke="#000" stroke-width="1.5"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ring-red' }" @click="selectTool('ring-red')" title="Cerchio Rosso">
                        <svg viewBox="0 0 24 24" class="tool-icon"><circle cx="12" cy="12" r="9" fill="none" stroke="#ef4444" stroke-width="3"/><circle cx="12" cy="12" r="3" fill="#ef4444"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ring-blue' }" @click="selectTool('ring-blue')" title="Cerchio Blu">
                        <svg viewBox="0 0 24 24" class="tool-icon"><circle cx="12" cy="12" r="9" fill="none" stroke="#3b82f6" stroke-width="3"/><circle cx="12" cy="12" r="3" fill="#3b82f6"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ring-yellow' }" @click="selectTool('ring-yellow')" title="Cerchio Giallo">
                        <svg viewBox="0 0 24 24" class="tool-icon"><circle cx="12" cy="12" r="9" fill="none" stroke="#eab308" stroke-width="3"/><circle cx="12" cy="12" r="3" fill="#eab308"/></svg>
                      </button>
                    </div>
                  </div>
                  
                  <div class="tools-section">
                    <div class="tools-label">VARIE</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'ladder' }" @click="selectTool('ladder')" title="Scaletta">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="2" y1="12" x2="22" y2="12" stroke="#666" stroke-width="2"/><line x1="6" y1="6" x2="6" y2="18" stroke="#eab308" stroke-width="2"/><line x1="12" y1="6" x2="12" y2="18" stroke="#eab308" stroke-width="2"/><line x1="18" y1="6" x2="18" y2="18" stroke="#eab308" stroke-width="2"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'hurdle' }" @click="selectTool('hurdle')" title="Ostacolo">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="8" width="20" height="4" fill="#eab308" stroke="#000" stroke-width="1.5" rx="1"/><rect x="4" y="12" width="2" height="10" fill="#333"/><rect x="18" y="12" width="2" height="10" fill="#333"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'zone' }" @click="selectTool('zone')" title="Zona">
                        <svg viewBox="0 0 24 24" class="tool-icon"><ellipse cx="12" cy="12" rx="10" ry="6" fill="rgba(255,255,0,0.3)" stroke="#eab308" stroke-width="2"/></svg>
                      </button>
                    </div>
                  </div>

                  <div class="tools-section">
                    <div class="tools-label">PALETTI E ARCHI</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'pole-single' }" @click="selectTool('pole-single')" title="Paletto Singolo">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="10" y="4" width="4" height="16" fill="#888"/><rect x="8" y="18" width="8" height="4" fill="#555"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'arch-small' }" @click="selectTool('arch-small')" title="Arco Piccolo">
                        <svg viewBox="0 0 24 24" class="tool-icon"><path d="M4,20 L4,12 Q4,4 12,4 Q20,4 20,12 L20,20" fill="none" stroke="#eab308" stroke-width="2.5"/><rect x="3" y="18" width="4" height="4" fill="#666"/><rect x="17" y="18" width="4" height="4" fill="#666"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'pole-variant' }" @click="selectTool('pole-variant')" title="Paletto Variante">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="10" y="2" width="4" height="20" fill="#ef4444" stroke="#000" stroke-width="1"/><rect x="8" y="18" width="8" height="4" rx="1" fill="#444"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'rock-dark' }" @click="selectTool('rock-dark')" title="Roccia Scura">
                        <svg viewBox="0 0 24 24" class="tool-icon"><polygon points="12,2 20,10 18,18 6,18 4,10" fill="#4a4a4a" stroke="#222" stroke-width="1.5"/><polygon points="12,6 16,10 14,14 10,14 8,10" fill="#5a5a5a"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'rock-dark-2' }" @click="selectTool('rock-dark-2')" title="Roccia Scura 2">
                        <svg viewBox="0 0 24 24" class="tool-icon"><polygon points="6,8 12,2 20,6 18,16 8,18 2,14" fill="#3a3a3a" stroke="#1a1a1a" stroke-width="1.5"/><polygon points="8,12 12,8 16,10 14,14 10,15" fill="#4a4a4a"/></svg>
                      </button>
                    </div>
                  </div>

                  <div class="tools-section">
                    <div class="tools-label">PORTE E TOKEN</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'mini-goal' }" @click="selectTool('mini-goal')" title="Porta Mini">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="4" y="8" width="16" height="12" fill="none" stroke="#fff" stroke-width="2"/><line x1="4" y1="8" x2="4" y2="20" stroke="#fff" stroke-width="2"/><line x1="20" y1="8" x2="20" y2="20" stroke="#fff" stroke-width="2"/><line x1="4" y1="20" x2="20" y2="20" stroke="#fff" stroke-width="2"/><line x1="6" y1="10" x2="18" y2="10" stroke="#aaa" stroke-width="0.5"/><line x1="6" y1="14" x2="18" y2="14" stroke="#aaa" stroke-width="0.5"/><line x1="6" y1="17" x2="18" y2="17" stroke="#aaa" stroke-width="0.5"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'coin-yellow' }" @click="selectTool('coin-yellow')" title="Token Giallo">
                        <svg viewBox="0 0 24 24" class="tool-icon"><ellipse cx="12" cy="12" rx="9" ry="9" fill="#eab308" stroke="#b45309" stroke-width="1.5"/><ellipse cx="12" cy="12" rx="6" ry="6" fill="none" stroke="#fef08a" stroke-width="1"/><text x="12" y="15" text-anchor="middle" font-size="8" font-weight="bold" fill="#78350f">C</text></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'coin-brown' }" @click="selectTool('coin-brown')" title="Token Marrone">
                        <svg viewBox="0 0 24 24" class="tool-icon"><ellipse cx="12" cy="12" rx="9" ry="9" fill="#78350f" stroke="#451a03" stroke-width="1.5"/><ellipse cx="12" cy="12" rx="6" ry="6" fill="none" stroke="#a16207" stroke-width="1"/><text x="12" y="15" text-anchor="middle" font-size="8" font-weight="bold" fill="#fef3c7">C</text></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'coin-gold' }" @click="selectTool('coin-gold')" title="Token Dorato">
                        <svg viewBox="0 0 24 24" class="tool-icon"><ellipse cx="12" cy="12" rx="9" ry="9" fill="#fbbf24" stroke="#d97706" stroke-width="1.5"/><ellipse cx="12" cy="12" rx="6" ry="6" fill="none" stroke="#fef3c7" stroke-width="1"/><text x="12" y="15" text-anchor="middle" font-size="8" font-weight="bold" fill="#78350f">C</text></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'fence-wood' }" @click="selectTool('fence-wood')" title="Staccionata Legno">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="10" width="20" height="3" fill="#a16207" stroke="#713f12" stroke-width="1"/><rect x="4" y="13" width="2" height="8" fill="#a16207" stroke="#713f12" stroke-width="1"/><rect x="11" y="13" width="2" height="8" fill="#a16207" stroke="#713f12" stroke-width="1"/><rect x="18" y="13" width="2" height="8" fill="#a16207" stroke="#713f12" stroke-width="1"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'fence-large' }" @click="selectTool('fence-large')" title="Staccionata Grande">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="1" y="8" width="22" height="4" fill="#78350f" stroke="#451a03" stroke-width="1.5"/><rect x="3" y="12" width="3" height="10" fill="#78350f" stroke="#451a03" stroke-width="1.5"/><rect x="10" y="12" width="3" height="10" fill="#78350f" stroke="#451a03" stroke-width="1.5"/><rect x="17" y="12" width="3" height="10" fill="#78350f" stroke="#451a03" stroke-width="1.5"/></svg>
                      </button>
                    </div>
                  </div>

                  <div class="tools-section">
                    <div class="tools-label">OSTACOLI E TELAI</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'frame-orange' }" @click="selectTool('frame-orange')" title="Telaio Arancione">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="6" y="3" width="12" height="18" fill="none" stroke="#f97316" stroke-width="2.5"/><line x1="6" y1="3" x2="6" y2="21" stroke="#f97316" stroke-width="2.5"/><line x1="18" y1="3" x2="18" y2="21" stroke="#f97316" stroke-width="2.5"/><line x1="6" y1="21" x2="18" y2="21" stroke="#f97316" stroke-width="2.5"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'barrier-low' }" @click="selectTool('barrier-low')" title="Ostacolo Basso">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="14" width="20" height="4" fill="#78350f" stroke="#451a03" stroke-width="1.5" rx="1"/><rect x="4" y="18" width="2" height="4" fill="#451a03"/><rect x="18" y="18" width="2" height="4" fill="#451a03"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'hurdle-wood' }" @click="selectTool('hurdle-wood')" title="Ostacolo a H">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="4" y1="8" x2="20" y2="8" stroke="#a16207" stroke-width="3"/><line x1="4" y1="8" x2="4" y2="20" stroke="#78350f" stroke-width="2"/><line x1="20" y1="8" x2="20" y2="20" stroke="#78350f" stroke-width="2"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'platform-gray' }" @click="selectTool('platform-gray')" title="Piattaforma Grigia">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="12" width="20" height="6" fill="#6b7280" stroke="#374151" stroke-width="1.5" rx="1"/><line x1="6" y1="12" x2="6" y2="18" stroke="#374151" stroke-width="1"/><line x1="12" y1="12" x2="12" y2="18" stroke="#374151" stroke-width="1"/><line x1="18" y1="12" x2="18" y2="18" stroke="#374151" stroke-width="1"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'bar-gray' }" @click="selectTool('bar-gray')" title="Barra Grigia">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="8" y="4" width="8" height="16" fill="#6b7280" stroke="#374151" stroke-width="1.5" rx="2"/><ellipse cx="12" cy="4" rx="4" ry="2" fill="#6b7280" stroke="#374151" stroke-width="1"/><ellipse cx="12" cy="20" rx="4" ry="2" fill="#6b7280" stroke="#374151" stroke-width="1"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'grid-square' }" @click="selectTool('grid-square')" title="Griglia Coordinazione">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="3" y="3" width="18" height="18" fill="none" stroke="#6b7280" stroke-width="2"/><line x1="9" y1="3" x2="9" y2="21" stroke="#6b7280" stroke-width="1.5"/><line x1="15" y1="3" x2="15" y2="21" stroke="#6b7280" stroke-width="1.5"/><line x1="3" y1="9" x2="21" y2="9" stroke="#6b7280" stroke-width="1.5"/><line x1="3" y1="15" x2="21" y2="15" stroke="#6b7280" stroke-width="1.5"/></svg>
                      </button>
                    </div>
                  </div>

                  <div class="tools-section">
                    <div class="tools-label">FITNESS</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'dumbbell' }" @click="selectTool('dumbbell')" title="Manubrio">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="8" width="4" height="8" fill="#9ca3af" stroke="#4b5563" stroke-width="1"/><rect x="18" y="8" width="4" height="8" fill="#9ca3af" stroke="#4b5563" stroke-width="1"/><rect x="6" y="10" width="12" height="4" fill="#d1d5db" stroke="#6b7280" stroke-width="1"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'trampoline' }" @click="selectTool('trampoline')" title="Tappeto Elastico">
                        <svg viewBox="0 0 24 24" class="tool-icon"><ellipse cx="12" cy="14" rx="10" ry="4" fill="none" stroke="#22c55e" stroke-width="2"/><ellipse cx="12" cy="14" rx="6" ry="2" fill="#4ade80"/><line x1="4" y1="14" x2="4" y2="20" stroke="#22c55e" stroke-width="2"/><line x1="20" y1="14" x2="20" y2="20" stroke="#22c55e" stroke-width="2"/><line x1="2" y1="20" x2="6" y2="20" stroke="#22c55e" stroke-width="2"/><line x1="18" y1="20" x2="22" y2="20" stroke="#22c55e" stroke-width="2"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'mat-gray' }" @click="selectTool('mat-gray')" title="Materassino">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="8" width="20" height="10" fill="#475569" stroke="#1e293b" stroke-width="1.5" rx="2"/><line x1="6" y1="8" x2="6" y2="18" stroke="#64748b" stroke-width="1"/><line x1="18" y1="8" x2="18" y2="18" stroke="#64748b" stroke-width="1"/></svg>
                      </button>
                    </div>
                  </div>

                  <div class="tools-section">
                    <div class="tools-label">SCALE</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'ladder-gray' }" @click="selectTool('ladder-gray')" title="Scala Grigia">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="10" width="20" height="4" fill="#6b7280" stroke="#374151" stroke-width="1"/><line x1="5" y1="10" x2="5" y2="14" stroke="#374151" stroke-width="2"/><line x1="9" y1="10" x2="9" y2="14" stroke="#374151" stroke-width="2"/><line x1="13" y1="10" x2="13" y2="14" stroke="#374151" stroke-width="2"/><line x1="17" y1="10" x2="17" y2="14" stroke="#374151" stroke-width="2"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ladder-yellow' }" @click="selectTool('ladder-yellow')" title="Scala Gialla">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="10" width="20" height="4" fill="#eab308" stroke="#a16207" stroke-width="1"/><line x1="5" y1="10" x2="5" y2="14" stroke="#a16207" stroke-width="2"/><line x1="9" y1="10" x2="9" y2="14" stroke="#a16207" stroke-width="2"/><line x1="13" y1="10" x2="13" y2="14" stroke="#a16207" stroke-width="2"/><line x1="17" y1="10" x2="17" y2="14" stroke="#a16207" stroke-width="2"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'ladder-red' }" @click="selectTool('ladder-red')" title="Scala Rossa">
                        <svg viewBox="0 0 24 24" class="tool-icon"><rect x="2" y="10" width="20" height="4" fill="#ef4444" stroke="#b91c1c" stroke-width="1"/><line x1="5" y1="10" x2="5" y2="14" stroke="#b91c1c" stroke-width="2"/><line x1="9" y1="10" x2="9" y2="14" stroke="#b91c1c" stroke-width="2"/><line x1="13" y1="10" x2="13" y2="14" stroke="#b91c1c" stroke-width="2"/><line x1="17" y1="10" x2="17" y2="14" stroke="#b91c1c" stroke-width="2"/></svg>
                      </button>
                    </div>
                  </div>
                    
                    <div class="tools-section">
                    <div class="tools-label">FRECCE TATTICHE</div>
                    <div class="tools-grid">
                      <button class="tool-btn" :class="{ active: currentTool === 'tactic-pass' }" @click="selectTool('tactic-pass')" title="Passaggio">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="2" y1="12" x2="20" y2="12" stroke="#1a5276" stroke-width="2"/><polygon points="20,12 16,9 16,15" fill="#1a5276"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'tactic-dribble' }" @click="selectTool('tactic-dribble')" title="Conduzione Palla">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="2" y1="12" x2="20" y2="12" stroke="#1a5276" stroke-width="2" stroke-dasharray="4,3"/><polygon points="20,12 16,9 16,15" fill="#1a5276"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'tactic-wall' }" @click="selectTool('tactic-wall')" title="Combinazione Muro">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="2" y1="12" x2="22" y2="12" stroke="#1a5276" stroke-width="2"/><polygon points="2,12 6,9 6,15" fill="#1a5276"/><polygon points="22,12 18,9 18,15" fill="#1a5276"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'tactic-shot' }" @click="selectTool('tactic-shot')" title="Tiro in Porta">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="2" y1="12" x2="18" y2="12" stroke="#1a5276" stroke-width="3.5"/><polygon points="18,12 13,7 13,17" fill="#1a5276"/></svg>
                      </button>
                      <button class="tool-btn" :class="{ active: currentTool === 'tactic-run' }" @click="selectTool('tactic-run')" title="Movimento senza Palla">
                        <svg viewBox="0 0 24 24" class="tool-icon"><line x1="2" y1="12" x2="16" y2="12" stroke="#1a5276" stroke-width="2" stroke-dasharray="4,3"/><circle cx="18" cy="12" r="3" fill="#1a5276"/></svg>
                      </button>
                    </div>
                  </div>
                   
                  <div class="tools-actions">
                    <button class="action-btn btn-clear" @click="clearBoard(ex)" title="Pulisci">🗑️ Pulisci</button>
                    <button class="action-btn btn-undo" @click="undoLast(ex)" title="Annulla">↩️ Undo</button>
                  </div>
                </div>

                <div class="tactical-board-container" :class="{ 'no-lines': !ex.campo_con_righe }">
                  <div class="tactical-board-wrapper">
                    <canvas 
                      :ref="el => { if (el) boardCanvasRefs[ex.id] = el }" 
                      width="800" 
                      height="500"
                      :class="[currentTool ? 'tool-selected' : '', isDragging ? 'dragging' : '']"
                      @click="handleBoardClick($event, ex)"
                      @mousedown="handleMouseDown($event, ex)"
                      @mousemove="handleMouseMove($event, ex)"
                      @mouseup="handleMouseUp($event, ex)"
                    ></canvas>
                  </div>
                </div>
              </div>

              <div class="board-sidebar">
                <div v-if="selectedElement && selectedElementExercise?.id === ex.id" class="element-controls">
                  <div class="element-controls-header" @click="elementControlsOpen = !elementControlsOpen">
                    <span>MODIFICA OGGETTO</span>
                    <span class="toggle-icon">{{ elementControlsOpen ? '▼' : '▶' }}</span>
                  </div>
                  <div v-if="elementControlsOpen" class="element-controls-body">
                    <div class="control-row">
                      <label>Colore:</label>
                      <div class="color-picker">
                        <button v-for="c in colors" :key="c" class="color-btn" :class="{ active: selectedElement.colore === c }" :style="{ background: c }" @click="changeColor(c)"></button>
                      </div>
                    </div>
                    <div class="control-row">
                      <label>Grandezza:</label>
                      <input type="range" v-model="selectedElement.size" min="0.5" max="2" step="0.1" @input="updateSize" />
                    </div>
                    <div class="control-row">
                      <label>Rotazione:</label>
                      <input type="range" v-model="selectedElement.rotazione" min="0" max="360" step="15" @input="updateRotation" />
                    </div>
                    <div v-if="isArrow(selectedElement)" class="control-row">
                      <label>Lunghezza:</label>
                      <input type="range" v-model="selectedElement.length" min="20" max="80" step="5" @input="updateSize" />
                    </div>
                    <div v-if="selectedElement.tipo?.startsWith('tactic-')" class="control-row">
                      <label>Ondulata:</label>
                      <button class="toggle-btn" :class="{ active: selectedElement.wavy }" @click="toggleWavy">
                        {{ selectedElement.wavy ? 'Sì' : 'No' }}
                      </button>
                    </div>
                    <div class="element-actions">
                      <button class="action-btn btn-copy-element" @click="copySelected" :disabled="!selectedElement">📋 Copia</button>
                      <button class="action-btn btn-paste-element" @click="pasteElement" :disabled="!copiedElement">📄 Incolla</button>
                      <button class="action-btn btn-delete-element" @click="deleteSelected">🗑️ Elimina</button>
                    </div>
                  </div>
                </div>

                <div class="esercizio-description">
                  <textarea v-model="ex.descrizione" placeholder="Descrizione dell'esercizio..." @change="saveEsercizio(ex)"></textarea>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div v-if="esercizi.length === 0" class="no-esercizi">
          <p>Nessun esercizio. Clicca "Esercizio" per iniziare.</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getAllCategorie, getAllenamentiGiornoByData, saveAllenamenti } from '../api/index.js'
import { jsPDF } from 'jspdf'
import html2canvas from 'html2canvas'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva, setCategoria } = useStore()
const categoriaId = parseInt(route.params.id)

const trainingDays = computed(() => {
  if (!categoriaAttiva.value?.giorni) return []
  return categoriaAttiva.value.giorni.split(',').map(Number)
})

const currentDate = new Date()
const currentYear = ref(currentDate.getFullYear())
const currentMonth = ref(currentDate.getMonth() + 1)
const selectedWeek = ref(null)
const selectedDay = ref(null)
const esercizi = ref([])
const currentTool = ref(null)
const boardCanvasRefs = ref({})
const selectedElement = ref(null)
const selectedExercise = ref(null)
const isDragging = ref(false)
const dragOffset = ref({ x: 0, y: 0 })
const elementControlsOpen = ref(false)
const selectedElementExercise = ref(null)
const copiedElement = ref(null)

const colors = ['#ef4444', '#3b82f6', '#eab308', '#22c55e', '#ffffff', '#000000', '#a855f7', '#f97316']

const monthNames = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre']
const currentMonthName = computed(() => monthNames[currentMonth.value - 1])

const weeksInMonth = computed(() => {
  const weeks = []
  const firstDay = new Date(currentYear.value, currentMonth.value - 1, 1)
  const lastDay = new Date(currentYear.value, currentMonth.value, 0)
  const dayNames = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab']
  
  let firstMonday = new Date(firstDay)
  while (firstMonday.getDay() !== 1) {
    firstMonday.setDate(firstMonday.getDate() - 1)
  }
  
  let currentWeekStart = new Date(firstMonday)
  let weekNum = 1
  
  while (currentWeekStart <= lastDay) {
    const weekEnd = new Date(currentWeekStart)
    weekEnd.setDate(weekEnd.getDate() + 4)
    
    const firstDayOfWeek = new Date(currentWeekStart)
    const weekStartsInMonth = firstDayOfWeek.getMonth() + 1 === currentMonth.value
    
    if (weekStartsInMonth) {
      const days = []
      for (let i = 0; i < 5; i++) {
        const d = new Date(currentWeekStart)
        d.setDate(d.getDate() + i)
        const dayOfWeek = d.getDay()
        const isTrainingDay = trainingDays.value.includes(dayOfWeek === 0 ? 7 : dayOfWeek)
        if (isTrainingDay) {
          const year = d.getFullYear()
          const month = String(d.getMonth() + 1).padStart(2, '0')
          const day = String(d.getDate()).padStart(2, '0')
          const dateStr = `${year}-${month}-${day}`
          const today = new Date()
          const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
          days.push({ 
            date: dateStr, 
            dayNum: d.getDate(),
            dayName: dayNames[dayOfWeek],
            month: d.getMonth() + 1,
            isToday: dateStr === todayStr, 
            hasTraining: true, 
            isSelectable: true, 
            data: dateStr 
          })
        }
      }
      
      if (days.length > 0) {
        const weekLabel = `Sett ${weekNum} (${dayNames[currentWeekStart.getDay()]}-${dayNames[weekEnd.getDay()]})`
        weeks.push({ num: weekNum, label: weekLabel, start: currentWeekStart.toISOString().split('T')[0], end: weekEnd.toISOString().split('T')[0], days })
        weekNum++
      }
    }
    
    currentWeekStart.setDate(currentWeekStart.getDate() + 7)
  }
  return weeks
})

function formatDateRange(start, end) {
  const s = new Date(start), e = new Date(end)
  const sMonth = s.toLocaleDateString('it-IT', { month: 'short' })
  const eMonth = e.toLocaleDateString('it-IT', { month: 'short' })
  if (s.getMonth() !== e.getMonth()) {
    return `${s.getDate()} ${sMonth} - ${e.getDate()} ${eMonth}`
  }
  return `${s.getDate()} - ${e.getDate()} ${eMonth}`
}

function prevMonth() {
  if (currentMonth.value === 1) { currentMonth.value = 12; currentYear.value-- } else { currentMonth.value-- }
}

function nextMonth() {
  if (currentMonth.value === 12) { currentMonth.value = 1; currentYear.value++ } else { currentMonth.value++ }
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  const [year, month, day] = dateStr.split('-')
  const d = new Date(parseInt(year), parseInt(month) - 1, parseInt(day))
  return d.toLocaleDateString('it-IT', { day: 'numeric', month: 'long', year: 'numeric' })
}

function selectWeek(week) { selectedWeek.value = week }

function selectExercise(ex) { selectedExercise.value = ex; drawBoard(ex) }

function selectDay(day) {
  if (!day.isSelectable) return
  selectedDay.value = day
  loadEsercizi(day.data)
}

function selectTool(tool) { currentTool.value = tool }

function getCurrentExercise() {
  return selectedExercise.value || esercizi.value[0]
}

function loadEsercizi(data) {
  selectedExercise.value = null
  selectedElement.value = null
  selectedElementExercise.value = null
  
  getAllenamentiGiornoByData(categoriaId, data).then(res => {
    const dayData = res.data
    let loadedEsercizi = []
    
    if (dayData.esercizi && dayData.esercizi.length > 0) {
      loadedEsercizi = dayData.esercizi.map((e, idx) => ({
        ...e,
        id: e.id || ('loaded_' + idx + '_' + Date.now())
      }))
    }
    
    if (loadedEsercizi.length === 0) {
      loadedEsercizi = [{ id: Date.now(), ordine: 1, titolo: '', descrizione: '', campo_con_righe: true, elementi: [] }]
    }
    
    esercizi.value = loadedEsercizi
    selectedExercise.value = esercizi.value[0]
    nextTick(() => {
      esercizi.value.forEach(ex => drawBoard(ex))
    })
  }).catch(() => {
    esercizi.value = [
      { id: Date.now(), ordine: 1, titolo: '', descrizione: '', campo_con_righe: true, elementi: [] }
    ]
    selectedExercise.value = esercizi.value[0]
    nextTick(() => {
      esercizi.value.forEach(ex => drawBoard(ex))
    })
  })
}

function addEsercizio() {
  const newId = Date.now()
  esercizi.value.push({ id: newId, ordine: esercizi.value.length + 1, titolo: '', descrizione: '', campo_con_righe: true, elementi: [] })
  selectedExercise.value = esercizi.value[esercizi.value.length - 1]
  nextTick(() => {
    drawBoard(selectedExercise.value)
  })
}

function deleteEsercizio(ex) { 
  esercizi.value = esercizi.value.filter(e => e.id !== ex.id)
  if (esercizi.value.length > 0) {
    selectedExercise.value = esercizi.value[0]
    nextTick(() => {
      drawBoard(selectedExercise.value)
    })
  }
}

function saveCurrentExercise() {
  if (selectedExercise.value) {
    saveEsercizio(selectedExercise.value)
    alert('Esercizio salvato!')
  } else if (esercizi.value.length > 0) {
    saveEsercizio(esercizi.value[0])
    alert('Esercizio salvato!')
  }
}

function exportPdf() {
  const eserciziOriginali = [...esercizi.value]
  const selectedOriginal = selectedExercise.value
  
  getAllenamentiGiornoByData(categoriaId, selectedDay.value.data).then(async res => {
    const eserciziSalvati = res.data.esercizi || []
    
    const doc = new jsPDF('portrait', 'mm', 'a4')
    const pageWidth = doc.internal.pageSize.getWidth()
    const pageHeight = doc.internal.pageSize.getHeight()
    let y = 20
    
    doc.setFontSize(18)
    doc.text('Allenamento del ' + formatDate(selectedDay.value?.data || ''), pageWidth / 2, y, { align: 'center' })
    y += 15
    
    if (eserciziSalvati.length === 0) {
      doc.setFontSize(12)
      doc.text('Nessun esercizio salvato', 15, y)
    } else {
      for (let idx = 0; idx < eserciziSalvati.length; idx++) {
        const ex = eserciziSalvati[idx]
        
        if (y > pageHeight - 80) {
          doc.addPage()
          y = 20
        }
        
        doc.setFontSize(14)
        doc.setTextColor(220, 38, 38)
        doc.text('Esercizio ' + (idx + 1) + ': ' + (ex.titolo || 'Senza titolo'), 15, y)
        y += 8
        
        try {
          const exData = eserciziOriginali.find(e => e.id === ex.id)
          if (exData) {
            selectedExercise.value = exData
            await nextTick()
            await new Promise(r => setTimeout(r, 300))
            
            const cardEl = document.querySelector(`.esercizio-card[data-ex-id="${ex.id}"]`)
            if (cardEl) {
              cardEl.click()
              await new Promise(r => setTimeout(r, 300))
            }
          }
          
          const activeBoard = document.querySelector('.tactical-board-container:not([style*="display: none"])')
          const boardCanvas = activeBoard ? activeBoard.querySelector('canvas') : null
          
          const fieldWidth = (pageWidth - 30) * 0.55
          const fieldX = 15
          let fieldHeight = 0
          
          if (boardCanvas) {
            const tempCanvas = document.createElement('canvas')
            tempCanvas.width = boardCanvas.width
            tempCanvas.height = boardCanvas.height
            const ctx = tempCanvas.getContext('2d')
            ctx.fillStyle = '#1a5c1a'
            ctx.fillRect(0, 0, tempCanvas.width, tempCanvas.height)
            ctx.drawImage(boardCanvas, 0, 0)
            
            const imgData = tempCanvas.toDataURL('image/png')
            fieldHeight = fieldWidth * (boardCanvas.height / boardCanvas.width)
            
            if (y + fieldHeight > pageHeight - 20) {
              doc.addPage()
              y = 20
            }
            
            doc.addImage(imgData, 'PNG', fieldX, y, fieldWidth, fieldHeight)
          }
          
          const descX = fieldX + fieldWidth + 8
          const descWidth = pageWidth - descX - 15
          
          doc.setFontSize(11)
          doc.setTextColor(0, 0, 0)
          if (ex.descrizione) {
            const descLines = doc.splitTextToSize(ex.descrizione, descWidth)
            doc.text(descLines, descX, y + 5)
          }
          
          y += Math.max(fieldHeight, 30) + 10
        } catch (e) {
          console.error('Errore cattura campo:', e)
          y += 30
        }
      }
      
      selectedExercise.value = selectedOriginal
      await nextTick()
    }
    
    doc.save('allenamento-' + (selectedDay.value?.data || 'data') + '.pdf')
  })
}

function saveEsercizio(ex) {
  if (!selectedDay.value) return
  
  const data = {
    nome_mese: `${currentYear.value}-${String(currentMonth.value).padStart(2, '0')}`,
    settimane: [{
      numero_settimana: selectedWeek.value?.num || 1,
      data_inizio: selectedWeek.value?.start || selectedDay.value.data,
      giorni: [{
        data: selectedDay.value.data,
        esercizi: esercizi.value.map((e, idx) => ({
          ordine: idx + 1,
          titolo: e.titolo,
          descrizione: e.descrizione,
          campo_con_righe: e.campo_con_righe,
          elementi: e.elementi.map(el => ({
            tipo: el.tipo,
            x: el.x,
            y: el.y,
            rotazione: el.rotazione,
            colore: el.colore,
            numero: el.numero
          }))
        }))
      }]
    }]
  }
  
  saveAllenamenti(categoriaId, data).then(() => {
    console.log('Allenamenti salvati!')
    loadEsercizi(selectedDay.value.data)
  }).catch(err => {
    console.error('Errore nel salvataggio:', err)
  })
}

function toggleFieldLines(ex) { ex.campo_con_righe = !ex.campo_con_righe; drawBoard(ex); saveEsercizio(ex) }

function clearBoard(ex) { ex.elementi = []; selectedElement.value = null; selectedElementExercise.value = null; drawBoard(ex); saveEsercizio(ex) }

function undoLast(ex) {
  if (ex.elementi.length > 0) {
    ex.elementi.pop()
    selectedElement.value = null
    selectedElementExercise.value = null
    drawBoard(ex)
  }
}

function changeColor(color) {
  if (selectedElement.value) {
    selectedElement.value.colore = color
    const ex = esercizi.value.find(e => e.elementi.includes(selectedElement.value))
    if (ex) { drawBoard(ex); saveEsercizio(ex) }
  }
}

function updateSize() {
  if (selectedElement.value) {
    const ex = esercizi.value.find(e => e.elementi.includes(selectedElement.value))
    if (ex) { drawBoard(ex); saveEsercizio(ex) }
  }
}

function updateRotation() {
  if (selectedElement.value) {
    const ex = esercizi.value.find(e => e.elementi.includes(selectedElement.value))
    if (ex) { drawBoard(ex); saveEsercizio(ex) }
  }
}

function toggleWavy() {
  if (selectedElement.value && selectedElement.value.tipo?.startsWith('tactic-')) {
    selectedElement.value.wavy = !selectedElement.value.wavy
    const ex = esercizi.value.find(e => e.elementi.includes(selectedElement.value))
    if (ex) { drawBoard(ex); saveEsercizio(ex) }
  }
}

function deleteSelected() {
  if (selectedElement.value) {
    const ex = selectedElementExercise.value
    if (ex) {
      ex.elementi = ex.elementi.filter(el => el !== selectedElement.value)
      selectedElement.value = null
      selectedElementExercise.value = null
      drawBoard(ex)
      saveEsercizio(ex)
    }
  }
}

function copySelected() {
  if (selectedElement.value) {
    copiedElement.value = JSON.parse(JSON.stringify(selectedElement.value))
  }
}

function pasteElement() {
  if (copiedElement.value) {
    const ex = selectedExercise.value || esercizi.value[0]
    if (ex) {
      const newEl = JSON.parse(JSON.stringify(copiedElement.value))
      newEl.id = Date.now()
      newEl.x = (newEl.x + 5) % 100
      newEl.y = (newEl.y + 5) % 100
      ex.elementi = ex.elementi || []
      ex.elementi.push(newEl)
      drawBoard(ex)
      saveEsercizio(ex)
    }
  }
}

function handleBoardClick(event, ex) {
  event.preventDefault()
  if (!ex) ex = getCurrentExercise()
  if (!ex) return
  if (isDragging.value) return
  const rect = event.target.getBoundingClientRect()
  const x = (event.clientX - rect.left) / rect.width * 100
  const y = (event.clientY - rect.top) / rect.height * 100
  
  const clickedEl = (ex.elementi || []).find(el => {
    const elX = el.x * rect.width / 100
    const elY = el.y * rect.height / 100
    const dist = Math.sqrt((event.clientX - rect.left - elX) ** 2 + (event.clientY - rect.top - elY) ** 2)
    return dist < 25
  })
  
  if (clickedEl) {
    selectedElement.value = clickedEl
    selectedElementExercise.value = ex
    drawBoard(ex)
    return
  }
  
  if (currentTool.value && ex) {
    ex.elementi = ex.elementi || []
    const isArrowTool = currentTool.value.startsWith('arrow-') || currentTool.value.startsWith('tactic-')
    const newEl = { 
      id: Date.now(), 
      tipo: currentTool.value, 
      x, 
      y, 
      rotazione: 0, 
      colore: getToolColor(currentTool.value), 
      size: 1,
      ...(isArrowTool && { length: 60 })
    }
    ex.elementi.push(newEl)
    drawBoard(ex)
    saveEsercizio(ex)
    currentTool.value = null
  } else {
    if (selectedElement.value && selectedElementExercise.value?.id !== ex.id) {
      selectedElement.value = null
      selectedElementExercise.value = null
    }
    if (ex) drawBoard(ex)
  }
}

function handleMouseDown(event, ex) {
  event.preventDefault()
  if (!ex) ex = getCurrentExercise()
  if (!ex) return
  
  const rect = event.target.getBoundingClientRect()
  const clickedEl = (ex.elementi || []).find(el => {
    const elX = el.x * rect.width / 100
    const elY = el.y * rect.height / 100
    const dist = Math.sqrt((event.clientX - rect.left - elX) ** 2 + (event.clientY - rect.top - elY) ** 2)
    return dist < 25
  })
  
  if (clickedEl) {
    event.stopPropagation()
    selectedElement.value = clickedEl
    selectedElementExercise.value = ex
    isDragging.value = true
    dragOffset.value = { x: event.clientX - clickedEl.x * rect.width / 100, y: event.clientY - clickedEl.y * rect.height / 100 }
    drawBoard(ex)
  }
}

function handleMouseMove(event, ex) {
  event.preventDefault()
  if (!isDragging.value || !selectedElement.value) return
  if (!ex) ex = getCurrentExercise()
  if (!ex) return
  const rect = event.target.getBoundingClientRect()
  selectedElement.value.x = (event.clientX - dragOffset.value.x) / rect.width * 100
  selectedElement.value.y = (event.clientY - dragOffset.value.y) / rect.height * 100
  drawBoard(ex)
}

function handleMouseUp(event, ex) { 
  event.preventDefault()
  if (isDragging.value && selectedElement.value) {
    const foundEx = ex || esercizi.value.find(e => e.elementi.includes(selectedElement.value))
    if (foundEx) saveEsercizio(foundEx)
  }
  isDragging.value = false 
}

function getToolColor(tool) {
  const colors = { 
    'player-red': '#ef4444', 'player-blue': '#3b82f6', 'player-yellow': '#eab308', 'player-green': '#22c55e', 'player-white': '#ffffff', 'player-black': '#000000',
    'ball': '#111111', 'ball-blue': '#003399', 'ball-red': '#cc0000', 'ball-yellow': '#1a1a1a', 'ball-orange': '#ff6600',
    'cone': '#ff6600', 'cone-small': '#eab308', 'cone-striped': '#ffffff',
    'pole-red': '#ef4444', 'pole-yellow': '#eab308', 'pole-white': '#ffffff',
    'flag-red': '#ef4444', 'flag-yellow': '#eab308',
    'disk-orange': '#ff6600', 'disk-blue': '#3b82f6', 'disk-yellow': '#eab308',
    'ring-red': '#ef4444', 'ring-blue': '#3b82f6', 'ring-yellow': '#eab308',
    'pole-single': '#888888', 'pole-variant': '#ef4444',
    'arch-small': '#eab308', 'rock-dark': '#4a4a4a', 'rock-dark-2': '#3a3a3a',
    'mini-goal': '#ffffff', 'coin-yellow': '#eab308', 'coin-brown': '#78350f', 'coin-gold': '#fbbf24',
    'fence-wood': '#a16207', 'fence-large': '#78350f',
    'frame-orange': '#f97316', 'barrier-low': '#78350f', 'hurdle-wood': '#a16207',
    'platform-gray': '#6b7280', 'bar-gray': '#6b7280', 'grid-square': '#6b7280',
    'dumbbell': '#9ca3af', 'trampoline': '#22c55e', 'mat-gray': '#475569',
    'ball-tennis': '#ccff00', 'ball-volleyball': '#fef08a', 'ball-basket': '#f97316',
    'ball-futsal': '#ffffff', 'ball-hockey': '#1f2937', 'ball-football-us': '#78350f',
    'ball-rugby': '#ffffff', 'ball-golf': '#ffffff',
    'ladder-gray': '#6b7280', 'ladder-yellow': '#eab308', 'ladder-red': '#ef4444',
    'tactic-pass': '#000000', 'tactic-dribble': '#000000', 'tactic-wall': '#000000', 'tactic-shot': '#000000', 'tactic-run': '#000000'
  }
  return colors[tool] || '#ffffff'
}

function isArrow(el) {
  return el && (el.tipo?.startsWith('arrow-') || el.tipo?.startsWith('tactic-'))
}

function drawBoard(ex) {
  const canvas = boardCanvasRefs.value[ex.id]
  if (!canvas) return
  
  const ctx = canvas.getContext('2d')
  const w = canvas.width
  const h = canvas.height
  
  const marginX = w * 0.03
  const marginY = h * 0.03
  const fieldW = w - marginX * 2
  const fieldH = h - marginY * 2
  
  const stripeCount = 12
  const stripeWidth = fieldW / stripeCount
  for (let i = 0; i < stripeCount; i++) {
    ctx.fillStyle = i % 2 === 0 ? '#2d5a1b' : '#3a7a24'
    ctx.fillRect(marginX + i * stripeWidth, marginY, stripeWidth, fieldH)
  }
  
  if (ex.campo_con_righe) {
    ctx.strokeStyle = '#fff'
    ctx.lineWidth = 2
    
    ctx.strokeRect(marginX, marginY, fieldW, fieldH)
    
    ctx.beginPath()
    ctx.moveTo(w / 2, marginY)
    ctx.lineTo(w / 2, h - marginY)
    ctx.stroke()
    
    const centerR = fieldW * 0.15
    ctx.beginPath()
    ctx.arc(w / 2, h / 2, centerR, 0, Math.PI * 2)
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(w / 2, h / 2, 3, 0, Math.PI * 2)
    ctx.fillStyle = '#fff'
    ctx.fill()
    
    const smallDepth = fieldW * 0.05
    const smallHeight = fieldH * 0.27
    const penaltyDepth = fieldW * 0.16
    const penaltyHeight = fieldH * 0.59
    const arcR = fieldW * 0.09
    const goalHeight = fieldH * 0.07
    const goalDepth = fieldW * 0.02
    
    const smallTop = h / 2 - smallHeight / 2
    const penaltyTop = h / 2 - penaltyHeight / 2
    
    ctx.strokeRect(marginX, smallTop, smallDepth, smallHeight)
    ctx.strokeRect(w - marginX - smallDepth, smallTop, smallDepth, smallHeight)
    
    ctx.strokeRect(marginX, penaltyTop, penaltyDepth, penaltyHeight)
    ctx.strokeRect(w - marginX - penaltyDepth, penaltyTop, penaltyDepth, penaltyHeight)
    
    const lunetteCenterX = marginX + penaltyDepth
    const lunetteCenterXRight = w - marginX - penaltyDepth
    
    ctx.strokeRect(marginX, smallTop, smallDepth, smallHeight)
    ctx.strokeRect(w - marginX - smallDepth, smallTop, smallDepth, smallHeight)
    
    ctx.strokeRect(marginX, penaltyTop, penaltyDepth, penaltyHeight)
    ctx.strokeRect(w - marginX - penaltyDepth, penaltyTop, penaltyDepth, penaltyHeight)
    
    const penaltySpotX = fieldW * 0.105
    
    ctx.beginPath()
    ctx.arc(lunetteCenterX, h / 2, arcR, -Math.PI / 2, Math.PI / 2)
    ctx.strokeStyle = '#fff'
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(lunetteCenterXRight, h / 2, arcR, Math.PI / 2, -Math.PI / 2)
    ctx.stroke()
    
    ctx.beginPath()
    ctx.arc(marginX + penaltySpotX, h / 2, 3, 0, Math.PI * 2)
    ctx.fillStyle = '#fff'
    ctx.fill()
    ctx.beginPath()
    ctx.arc(w - marginX - penaltySpotX, h / 2, 3, 0, Math.PI * 2)
    ctx.fill()
    
    ctx.strokeRect(marginX - goalDepth, h / 2 - goalHeight / 2, goalDepth, goalHeight)
    ctx.strokeRect(w - marginX, h / 2 - goalHeight / 2, goalDepth, goalHeight)
  }
  
  for (const el of ex.elementi) {
    const x = el.x * w / 100
    const y = el.y * h / 100
    const size = el.size || 1
    const rot = (el.rotazione || 0) * Math.PI / 180
    
    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(rot)
    ctx.scale(size, size)
    
    switch (el.tipo) {
      case 'player-red': case 'player-blue': case 'player-yellow': case 'player-green': case 'player-white': case 'player-black':
        ctx.beginPath()
        ctx.arc(0, 0, 18, 0, Math.PI * 2)
        ctx.fillStyle = el.colore || '#fff'
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 2
        ctx.stroke()
        break
      case 'goal-large':
        ctx.strokeStyle = '#fff'
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.moveTo(-45, -25)
        ctx.lineTo(-45, 25)
        ctx.lineTo(45, 25)
        ctx.lineTo(45, -25)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(-45, -25)
        ctx.lineTo(-40, -25)
        ctx.lineTo(-40, 20)
        ctx.lineTo(40, 20)
        ctx.lineTo(40, -25)
        ctx.lineTo(45, -25)
        ctx.stroke()
        ctx.strokeStyle = 'rgba(255,255,255,0.4)'
        ctx.lineWidth = 1
        for (let gy = -20; gy <= 15; gy += 7) {
          ctx.beginPath()
          ctx.moveTo(-40, gy)
          ctx.lineTo(40, gy)
          ctx.stroke()
        }
        for (let gx = -35; gx <= 35; gx += 7) {
          ctx.beginPath()
          ctx.moveTo(gx, -20)
          ctx.lineTo(gx, 20)
          ctx.stroke()
        }
        break
      case 'goal-small':
        ctx.strokeStyle = '#fff'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(-18, -12)
        ctx.lineTo(-18, 12)
        ctx.lineTo(18, 12)
        ctx.lineTo(18, -12)
        ctx.stroke()
        ctx.strokeStyle = 'rgba(255,255,255,0.4)'
        ctx.lineWidth = 1
        for (let gy = -8; gy <= 8; gy += 4) {
          ctx.beginPath()
          ctx.moveTo(-15, gy)
          ctx.lineTo(15, gy)
          ctx.stroke()
        }
        for (let gx = -12; gx <= 12; gx += 4) {
          ctx.beginPath()
          ctx.moveTo(gx, -8)
          ctx.lineTo(gx, 8)
          ctx.stroke()
        }
        break
      case 'cone':
        ctx.fillStyle = el.colore || '#ff6600'
        ctx.beginPath()
        ctx.ellipse(0, 0, 8, 14, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(0, -12)
        ctx.lineTo(0, 12)
        ctx.strokeStyle = '#fff'
        ctx.lineWidth = 1
        ctx.stroke()
        break
      case 'cone-small':
        ctx.fillStyle = el.colore || '#eab308'
        ctx.beginPath()
        ctx.ellipse(0, 0, 5, 10, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        break
      case 'cone-striped':
        ctx.fillStyle = el.colore || '#ffffff'
        ctx.beginPath()
        ctx.ellipse(0, 0, 8, 14, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        ctx.strokeStyle = '#ef4444'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(-6, -4)
        ctx.lineTo(6, -4)
        ctx.moveTo(-7, 2)
        ctx.lineTo(7, 2)
        ctx.moveTo(-6, 8)
        ctx.lineTo(6, 8)
        ctx.stroke()
        break
      case 'pole-red': case 'pole-yellow': case 'pole-white':
        ctx.fillStyle = el.colore || '#ef4444'
        ctx.beginPath()
        ctx.roundRect(-3, -30, 6, 60, 1)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        ctx.fillStyle = '#666'
        ctx.beginPath()
        ctx.roundRect(-8, 26, 16, 6, 2)
        ctx.fill()
        break
      case 'flag-red': case 'flag-yellow':
        ctx.strokeStyle = '#666'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(0, -25)
        ctx.lineTo(0, 25)
        ctx.stroke()
        ctx.fillStyle = el.colore || '#ef4444'
        ctx.beginPath()
        ctx.moveTo(0, -25)
        ctx.lineTo(15, -18)
        ctx.lineTo(0, -10)
        ctx.closePath()
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        break
      case 'disk-orange': case 'disk-blue': case 'disk-yellow':
        ctx.fillStyle = el.colore || '#ff6600'
        ctx.beginPath()
        ctx.ellipse(0, 0, 18, 6, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        ctx.beginPath()
        ctx.ellipse(0, 0, 8, 3, 0, 0, Math.PI * 2)
        ctx.fillStyle = el.colore === '#3b82f6' ? '#1d4ed8' : el.colore === '#eab308' ? '#a16207' : '#cc5200'
        ctx.fill()
        break
      case 'ring-red': case 'ring-blue': case 'ring-yellow':
        ctx.strokeStyle = el.colore || '#ef4444'
        ctx.lineWidth = 4
        ctx.beginPath()
        ctx.arc(0, 0, 18, 0, Math.PI * 2)
        ctx.stroke()
        ctx.fillStyle = el.colore || '#ef4444'
        ctx.beginPath()
        ctx.arc(0, 0, 5, 0, Math.PI * 2)
        ctx.fill()
        break
      case 'disc':
        ctx.fillStyle = el.colore || '#ff6600'
        ctx.beginPath()
        ctx.ellipse(0, 0, 18, 6, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        ctx.beginPath()
        ctx.ellipse(0, 0, 8, 3, 0, 0, Math.PI * 2)
        ctx.fillStyle = '#cc5200'
        ctx.fill()
        break
      case 'ladder':
        ctx.strokeStyle = '#ff6600'
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.roundRect(-40, -3, 80, 6, 2)
        ctx.stroke()
        ctx.strokeStyle = '#888'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(-28, -8)
        ctx.lineTo(-28, 8)
        ctx.moveTo(0, -8)
        ctx.lineTo(0, 8)
        ctx.moveTo(28, -8)
        ctx.lineTo(28, 8)
        ctx.stroke()
        break
      case 'hurdle':
        ctx.fillStyle = '#eab308'
        ctx.fillRect(-35, -6, 70, 8)
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.strokeRect(-35, -6, 70, 8)
        ctx.fillStyle = '#333'
        ctx.fillRect(-28, 4, 6, 16)
        ctx.fillRect(22, 4, 6, 16)
        break
      case 'pole':
        ctx.strokeStyle = '#888'
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.moveTo(0, -35)
        ctx.lineTo(0, 35)
        ctx.stroke()
        ctx.fillStyle = '#ef4444'
        ctx.beginPath()
        ctx.arc(0, -30, 5, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        break
      case 'ball': case 'ball-blue': case 'ball-red': case 'ball-yellow': case 'ball-orange':
        const ballPrimary = el.colore || '#111111'
        const ballSecondary = '#ffffff'
        const ballOutline = el.tipo === 'ball-blue' ? '#002277' : el.tipo === 'ball-red' ? '#990000' : el.tipo === 'ball-orange' ? '#cc4400' : el.tipo === 'ball-yellow' ? '#000000' : '#111111'
        const r = 18
        ctx.beginPath()
        ctx.arc(0, 0, r, 0, Math.PI * 2)
        ctx.fillStyle = ballSecondary
        ctx.fill()
        ctx.strokeStyle = ballOutline
        ctx.lineWidth = 2.5
        ctx.stroke()
        
        const pentSize = r * 0.22
        const hexSize = r * 0.35
        const centerOffset = r * 0.35
        
        ctx.lineWidth = 2
        ctx.strokeStyle = ballOutline
        
        for (let i = 0; i < 5; i++) {
          const angle = (i * 72 - 90) * Math.PI / 180
          const hx = Math.cos(angle) * centerOffset
          const hy = Math.sin(angle) * centerOffset
          
          ctx.beginPath()
          for (let j = 0; j < 6; j++) {
            const a = (angle + (j * 60 - 30) * Math.PI / 180)
            const px = hx + Math.cos(a) * hexSize
            const py = hy + Math.sin(a) * hexSize
            if (j === 0) ctx.moveTo(px, py)
            else ctx.lineTo(px, py)
          }
          ctx.closePath()
          ctx.fillStyle = ballSecondary
          ctx.fill()
          ctx.stroke()
        }
        
        ctx.beginPath()
        for (let j = 0; j < 5; j++) {
          const a = (j * 72 - 90 + 36) * Math.PI / 180
          const px = Math.cos(a) * pentSize
          const py = Math.sin(a) * pentSize
          if (j === 0) ctx.moveTo(px, py)
          else ctx.lineTo(px, py)
        }
        ctx.closePath()
        ctx.fillStyle = ballPrimary
        ctx.fill()
        ctx.stroke()
        
        for (let i = 0; i < 5; i++) {
          const angle = (i * 72 - 90) * Math.PI / 180
          const hx = Math.cos(angle) * centerOffset
          const hy = Math.sin(angle) * centerOffset
          const outerAngle = angle + 30 * Math.PI / 180
          const ox = hx + Math.cos(outerAngle) * hexSize * 0.8
          const oy = hy + Math.sin(outerAngle) * hexSize * 0.8
          
          ctx.beginPath()
          for (let j = 0; j < 5; j++) {
            const a = (outerAngle + (j * 72) * Math.PI / 180)
            const px = ox + Math.cos(a) * pentSize * 0.7
            const py = oy + Math.sin(a) * pentSize * 0.7
            if (j === 0) ctx.moveTo(px, py)
            else ctx.lineTo(px, py)
          }
          ctx.closePath()
          ctx.fillStyle = ballPrimary
          ctx.fill()
          ctx.stroke()
        }
        break
      case 'zone':
        ctx.beginPath()
        ctx.ellipse(0, 0, 50, 30, 0, 0, Math.PI * 2)
        ctx.fillStyle = 'rgba(255,255,0,0.25)'
        ctx.fill()
        ctx.strokeStyle = '#eab308'
        ctx.lineWidth = 2
        ctx.stroke()
        break
      case 'pole-single':
        ctx.fillStyle = '#888'
        ctx.beginPath()
        ctx.roundRect(-2, -20, 4, 40, 1)
        ctx.fill()
        ctx.strokeStyle = '#444'
        ctx.lineWidth = 1
        ctx.stroke()
        ctx.fillStyle = '#555'
        ctx.beginPath()
        ctx.roundRect(-5, 16, 10, 5, 1)
        ctx.fill()
        break
      case 'arch-small':
        ctx.strokeStyle = el.colore || '#eab308'
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.moveTo(-12, 20)
        ctx.lineTo(-12, 8)
        ctx.quadraticCurveTo(-12, -8, 0, -8)
        ctx.quadraticCurveTo(12, -8, 12, 8)
        ctx.lineTo(12, 20)
        ctx.stroke()
        ctx.fillStyle = '#666'
        ctx.fillRect(-12, 16, 4, 6)
        ctx.fillRect(8, 16, 4, 6)
        break
      case 'pole-variant':
        ctx.fillStyle = el.colore || '#ef4444'
        ctx.beginPath()
        ctx.roundRect(-2, -22, 4, 44, 1)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1
        ctx.stroke()
        ctx.fillStyle = '#444'
        ctx.beginPath()
        ctx.roundRect(-5, 16, 10, 5, 1)
        ctx.fill()
        break
      case 'rock-dark': case 'rock-dark-2':
        ctx.fillStyle = '#4a4a4a'
        ctx.beginPath()
        ctx.moveTo(0, -18)
        ctx.lineTo(18, -6)
        ctx.lineTo(14, 14)
        ctx.lineTo(-14, 14)
        ctx.lineTo(-18, -6)
        ctx.closePath()
        ctx.fill()
        ctx.strokeStyle = '#222'
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.fillStyle = '#5a5a5a'
        ctx.beginPath()
        ctx.moveTo(0, -12)
        ctx.lineTo(10, -4)
        ctx.lineTo(6, 10)
        ctx.lineTo(-6, 10)
        ctx.lineTo(-10, -4)
        ctx.closePath()
        ctx.fill()
        break
      case 'mini-goal':
        ctx.strokeStyle = '#fff'
        ctx.lineWidth = 2.5
        ctx.beginPath()
        ctx.moveTo(-22, -14)
        ctx.lineTo(-22, 14)
        ctx.lineTo(22, 14)
        ctx.lineTo(22, -14)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(-22, -14)
        ctx.lineTo(-18, -14)
        ctx.lineTo(-18, 10)
        ctx.lineTo(18, 10)
        ctx.lineTo(18, -14)
        ctx.lineTo(22, -14)
        ctx.stroke()
        ctx.strokeStyle = 'rgba(255,255,255,0.3)'
        ctx.lineWidth = 1
        for (let gy = -10; gy <= 6; gy += 4) {
          ctx.beginPath()
          ctx.moveTo(-16, gy)
          ctx.lineTo(16, gy)
          ctx.stroke()
        }
        for (let gx = -14; gx <= 14; gx += 4) {
          ctx.beginPath()
          ctx.moveTo(gx, -10)
          ctx.lineTo(gx, 10)
          ctx.stroke()
        }
        break
      case 'coin-yellow': case 'coin-brown': case 'coin-gold':
        const coinColor = el.tipo === 'coin-yellow' ? '#eab308' : el.tipo === 'coin-brown' ? '#78350f' : '#fbbf24'
        const coinStroke = el.tipo === 'coin-yellow' ? '#b45309' : el.tipo === 'coin-brown' ? '#451a03' : '#d97706'
        const coinInner = el.tipo === 'coin-yellow' ? '#fef08a' : el.tipo === 'coin-brown' ? '#a16207' : '#fef3c7'
        const coinText = el.tipo === 'coin-yellow' ? '#78350f' : el.tipo === 'coin-brown' ? '#fef3c7' : '#78350f'
        ctx.fillStyle = coinColor
        ctx.beginPath()
        ctx.ellipse(0, 0, 18, 18, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = coinStroke
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.strokeStyle = coinInner
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.ellipse(0, 0, 12, 12, 0, 0, Math.PI * 2)
        ctx.stroke()
        ctx.fillStyle = coinText
        ctx.font = 'bold 14px sans-serif'
        ctx.textAlign = 'center'
        ctx.textBaseline = 'middle'
        ctx.fillText('C', 0, 0)
        break
      case 'fence-wood': case 'fence-large':
        const fenceColor = el.tipo === 'fence-wood' ? '#a16207' : '#78350f'
        const fenceStroke = el.tipo === 'fence-wood' ? '#713f12' : '#451a03'
        ctx.fillStyle = fenceColor
        ctx.strokeStyle = fenceStroke
        ctx.lineWidth = 1
        const fH = el.tipo === 'fence-wood' ? 3 : 4
        const fY = el.tipo === 'fence-wood' ? 8 : 6
        ctx.fillRect(-22, fY, 44, fH)
        ctx.strokeRect(-22, fY, 44, fH)
        ctx.fillStyle = fenceColor
        const posts = el.tipo === 'fence-wood' ? [-14, 0, 14] : [-10, 5, 12]
        const postH = el.tipo === 'fence-wood' ? 8 : 10
        posts.forEach(px => {
          ctx.fillRect(px, fY + fH, 3, postH)
          ctx.strokeRect(px, fY + fH, 3, postH)
        })
        break
      case 'frame-orange':
        ctx.strokeStyle = '#f97316'
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.moveTo(-10, -18)
        ctx.lineTo(-10, 18)
        ctx.lineTo(10, 18)
        ctx.lineTo(10, -18)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(-10, -18)
        ctx.lineTo(10, -18)
        ctx.stroke()
        break
      case 'barrier-low':
        ctx.fillStyle = '#78350f'
        ctx.strokeStyle = '#451a03'
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.roundRect(-18, 8, 36, 6, 2)
        ctx.fill()
        ctx.stroke()
        ctx.fillStyle = '#451a03'
        ctx.fillRect(-14, 14, 4, 6)
        ctx.fillRect(10, 14, 4, 6)
        break
      case 'hurdle-wood':
        ctx.strokeStyle = '#a16207'
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.moveTo(-16, -6)
        ctx.lineTo(16, -6)
        ctx.stroke()
        ctx.strokeStyle = '#78350f'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(-16, -6)
        ctx.lineTo(-16, 14)
        ctx.moveTo(16, -6)
        ctx.lineTo(16, 14)
        ctx.stroke()
        break
      case 'platform-gray':
        ctx.fillStyle = '#6b7280'
        ctx.strokeStyle = '#374151'
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.roundRect(-20, 6, 40, 12, 2)
        ctx.fill()
        ctx.stroke()
        ctx.strokeStyle = '#374151'
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(-10, 6)
        ctx.lineTo(-10, 18)
        ctx.moveTo(0, 6)
        ctx.lineTo(0, 18)
        ctx.moveTo(10, 6)
        ctx.lineTo(10, 18)
        ctx.stroke()
        break
      case 'bar-gray':
        ctx.fillStyle = '#6b7280'
        ctx.strokeStyle = '#374151'
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.roundRect(-4, -16, 8, 32, 2)
        ctx.fill()
        ctx.stroke()
        ctx.beginPath()
        ctx.ellipse(0, -16, 4, 2, 0, 0, Math.PI * 2)
        ctx.fillStyle = '#9ca3af'
        ctx.fill()
        ctx.stroke()
        ctx.beginPath()
        ctx.ellipse(0, 16, 4, 2, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.stroke()
        break
      case 'grid-square':
        ctx.strokeStyle = '#6b7280'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.strokeRect(-18, -18, 36, 36)
        ctx.strokeStyle = '#9ca3af'
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.moveTo(-6, -18)
        ctx.lineTo(-6, 18)
        ctx.moveTo(6, -18)
        ctx.lineTo(6, 18)
        ctx.moveTo(-18, -6)
        ctx.lineTo(18, -6)
        ctx.moveTo(-18, 6)
        ctx.lineTo(18, 6)
        ctx.stroke()
        break
      case 'dumbbell':
        ctx.fillStyle = '#9ca3af'
        ctx.strokeStyle = '#4b5563'
        ctx.lineWidth = 1
        ctx.fillRect(-10, -8, 6, 16)
        ctx.strokeRect(-10, -8, 6, 16)
        ctx.fillRect(4, -8, 6, 16)
        ctx.strokeRect(4, -8, 6, 16)
        ctx.fillStyle = '#d1d5db'
        ctx.strokeStyle = '#6b7280'
        ctx.fillRect(-4, -4, 8, 8)
        ctx.strokeRect(-4, -4, 8, 8)
        break
      case 'trampoline':
        ctx.strokeStyle = '#22c55e'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.ellipse(0, 4, 22, 8, 0, 0, Math.PI * 2)
        ctx.stroke()
        ctx.fillStyle = '#4ade80'
        ctx.beginPath()
        ctx.ellipse(0, 4, 14, 5, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#16a34a'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(-14, 4)
        ctx.lineTo(-14, 14)
        ctx.moveTo(14, 4)
        ctx.lineTo(14, 14)
        ctx.stroke()
        break
      case 'mat-gray':
        ctx.fillStyle = '#475569'
        ctx.strokeStyle = '#1e293b'
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.roundRect(-20, -8, 40, 16, 3)
        ctx.fill()
        ctx.stroke()
        ctx.strokeStyle = '#64748b'
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(-12, -8)
        ctx.lineTo(-12, 8)
        ctx.moveTo(12, -8)
        ctx.lineTo(12, 8)
        ctx.stroke()
        break
      case 'ball-tennis':
        ctx.fillStyle = '#ccff00'
        ctx.beginPath()
        ctx.arc(0, 0, 14, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#86efac'
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.strokeStyle = '#fff'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(-10, -6)
        ctx.quadraticCurveTo(0, 0, 10, -6)
        ctx.quadraticCurveTo(0, -12, -10, -6)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(-10, 6)
        ctx.quadraticCurveTo(0, 0, 10, 6)
        ctx.quadraticCurveTo(0, 12, -10, 6)
        ctx.stroke()
        break
      case 'ball-volleyball':
        ctx.fillStyle = '#fef08a'
        ctx.beginPath()
        ctx.arc(0, 0, 14, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#eab308'
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.strokeStyle = '#2563eb'
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.moveTo(-12, -10)
        ctx.lineTo(12, 10)
        ctx.moveTo(12, -10)
        ctx.lineTo(-12, 10)
        ctx.moveTo(-10, -12)
        ctx.lineTo(10, 12)
        ctx.moveTo(10, -12)
        ctx.lineTo(-10, 12)
        ctx.stroke()
        break
      case 'ball-basket':
        ctx.fillStyle = '#f97316'
        ctx.beginPath()
        ctx.arc(0, 0, 14, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#ea580c'
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.arc(0, 0, 10, 0, Math.PI)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(0, -10)
        ctx.lineTo(0, 10)
        ctx.stroke()
        break
      case 'ball-futsal':
        ctx.fillStyle = '#fff'
        ctx.beginPath()
        ctx.arc(0, 0, 14, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.fillStyle = '#666'
        ctx.beginPath()
        ctx.moveTo(-8, -10)
        ctx.lineTo(-4, -10)
        ctx.lineTo(-6, -4)
        ctx.lineTo(-10, -4)
        ctx.lineTo(-12, 0)
        ctx.lineTo(-10, 4)
        ctx.lineTo(-6, 4)
        ctx.lineTo(-4, 10)
        ctx.lineTo(-8, 10)
        ctx.lineTo(-8, 4)
        ctx.lineTo(-12, 4)
        ctx.lineTo(-12, 0)
        ctx.lineTo(-8, -4)
        ctx.closePath()
        ctx.fill()
        ctx.beginPath()
        ctx.moveTo(8, -10)
        ctx.lineTo(4, -10)
        ctx.lineTo(6, -4)
        ctx.lineTo(10, -4)
        ctx.lineTo(12, 0)
        ctx.lineTo(10, 4)
        ctx.lineTo(6, 4)
        ctx.lineTo(4, 10)
        ctx.lineTo(8, 10)
        ctx.lineTo(8, 4)
        ctx.lineTo(12, 4)
        ctx.lineTo(12, 0)
        ctx.lineTo(8, -4)
        ctx.closePath()
        ctx.fill()
        break
      case 'ball-hockey':
        ctx.fillStyle = '#1f2937'
        ctx.beginPath()
        ctx.ellipse(0, 0, 16, 6, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1.5
        ctx.stroke()
        break
      case 'ball-football-us':
        ctx.fillStyle = '#78350f'
        ctx.beginPath()
        ctx.ellipse(0, 0, 16, 10, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#451a03'
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.strokeStyle = '#fff'
        ctx.lineWidth = 1.5
        ctx.setLineDash([3, 3])
        ctx.beginPath()
        ctx.moveTo(-10, -6)
        ctx.lineTo(10, -6)
        ctx.moveTo(-10, 6)
        ctx.lineTo(10, 6)
        ctx.stroke()
        ctx.setLineDash([])
        break
      case 'ball-rugby':
        ctx.fillStyle = '#fff'
        ctx.beginPath()
        ctx.ellipse(0, 0, 16, 10, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#000'
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.strokeStyle = '#ef4444'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(-8, -6)
        ctx.lineTo(8, 6)
        ctx.moveTo(8, -6)
        ctx.lineTo(-8, 6)
        ctx.stroke()
        break
      case 'ball-golf':
        ctx.fillStyle = '#fff'
        ctx.beginPath()
        ctx.arc(0, 0, 10, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = '#d1d5db'
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.fillStyle = '#e5e7eb'
        ctx.beginPath()
        ctx.arc(-3, -3, 1.5, 0, Math.PI * 2)
        ctx.arc(3, -1, 1.5, 0, Math.PI * 2)
        ctx.arc(0, 4, 1.5, 0, Math.PI * 2)
        ctx.fill()
        break
      case 'ladder-gray': case 'ladder-yellow': case 'ladder-red':
        const ladderColor = el.tipo === 'ladder-gray' ? '#6b7280' : el.tipo === 'ladder-yellow' ? '#eab308' : '#ef4444'
        const ladderStroke = el.tipo === 'ladder-gray' ? '#374151' : el.tipo === 'ladder-yellow' ? '#a16207' : '#b91c1c'
        ctx.fillStyle = ladderColor
        ctx.strokeStyle = ladderStroke
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.roundRect(-22, -3, 44, 6, 2)
        ctx.fill()
        ctx.stroke()
        ctx.strokeStyle = ladderStroke
        ctx.lineWidth = 2
        for (let lx = -16; lx <= 16; lx += 8) {
          ctx.beginPath()
          ctx.moveTo(lx, -3)
          ctx.lineTo(lx, 3)
          ctx.stroke()
        }
        break
      case 'tactic-pass': case 'tactic-dribble': case 'tactic-wall': case 'tactic-shot': case 'tactic-run':
        drawTacticalArrow(ctx, el)
        break
      case 'arrow-up': drawArrow(ctx, 0, -1, el.colore, false, false, el.length || 60); break
      case 'arrow-down': drawArrow(ctx, 0, 1, el.colore, false, false, el.length || 60); break
      case 'arrow-left': drawArrow(ctx, -1, 0, el.colore, false, false, el.length || 60); break
      case 'arrow-right': drawArrow(ctx, 1, 0, el.colore, false, false, el.length || 60); break
      case 'arrow-dashed-up': drawArrow(ctx, 0, -1, el.colore, true, false, el.length || 60); break
      case 'arrow-dashed-right': drawArrow(ctx, 1, 0, el.colore, true, false, el.length || 60); break
      case 'arrow-wavy-up': drawArrow(ctx, 0, -1, el.colore, false, true, el.length || 60); break
      case 'arrow-wavy-right': drawArrow(ctx, 1, 0, el.colore, false, true, el.length || 60); break
    }
    
    if (selectedElement.value === el) {
      ctx.strokeStyle = '#fff'
      ctx.lineWidth = 3
      ctx.setLineDash([5, 5])
      ctx.beginPath()
      ctx.arc(0, 0, 25, 0, Math.PI * 2)
      ctx.stroke()
      ctx.setLineDash([])
    }
    
    ctx.restore()
  }
}

function drawArrow(ctx, dx, dy, color = '#ffff00', dashed = false, wavy = false, length = 40) {
  const width = 15
  ctx.strokeStyle = color
  ctx.fillStyle = color
  ctx.lineWidth = 3
  if (dashed) {
    ctx.setLineDash([6, 4])
  }
  if (wavy) {
    ctx.beginPath()
    ctx.moveTo(-dx * length, -dy * length)
    if (dx === 0) {
      ctx.quadraticCurveTo(dx * length + 10, -dy * length / 2, 0, 0)
      ctx.quadraticCurveTo(dx * length - 10, dy * length / 2, dx * length, dy * length)
    } else {
      ctx.quadraticCurveTo(dx * length / 2, -dy * length + 10, 0, 0)
      ctx.quadraticCurveTo(dx * length / 2, dy * length - 10, dx * length, dy * length)
    }
    ctx.stroke()
  } else {
    ctx.beginPath()
    ctx.moveTo(-dx * length, -dy * length)
    ctx.lineTo(dx * length, dy * length)
    ctx.stroke()
  }
  ctx.setLineDash([])
  ctx.beginPath()
  ctx.moveTo(dx * length, dy * length)
  ctx.lineTo(dx * length - dy * width, dy * length - dx * width)
  ctx.lineTo(dx * length + dy * width, dy * length + dx * width)
  ctx.closePath()
  ctx.fill()
}

function drawTacticalArrow(ctx, el) {
  const color = el.colore || '#000000'
  const startX = -el.length / 2
  const endX = el.length / 2
  const y = 0
  const rot = (el.rotazione || 0) * Math.PI / 180
  const isWavy = el.wavy
  
  ctx.save()
  ctx.rotate(rot)
  
  const isDashed = el.tipo === 'tactic-dribble' || el.tipo === 'tactic-run'
  const hasDoubleArrow = el.tipo === 'tactic-wall'
  const hasDot = el.tipo === 'tactic-run'
  const isThick = el.tipo === 'tactic-shot'
  
  ctx.strokeStyle = color
  ctx.fillStyle = color
  ctx.lineWidth = isThick ? 5 : 3
  
  if (isDashed) {
    ctx.setLineDash([6, 4])
  }
  
  if (hasDoubleArrow) {
    if (isWavy) {
      ctx.beginPath()
      ctx.moveTo(startX, y)
      ctx.quadraticCurveTo(startX + (endX - startX) * 0.25, y - 15, startX + (endX - startX) * 0.5, y)
      ctx.quadraticCurveTo(startX + (endX - startX) * 0.75, y + 15, endX, y)
      ctx.stroke()
    } else {
      ctx.beginPath()
      ctx.moveTo(startX, y)
      ctx.lineTo(endX, y)
      ctx.stroke()
    }
    ctx.setLineDash([])
    
    ctx.beginPath()
    ctx.moveTo(startX, y)
    ctx.lineTo(startX + 12, y - 6)
    ctx.lineTo(startX + 12, y + 6)
    ctx.closePath()
    ctx.fill()
    
    ctx.beginPath()
    ctx.moveTo(endX, y)
    ctx.lineTo(endX - 12, y - 6)
    ctx.lineTo(endX - 12, y + 6)
    ctx.closePath()
    ctx.fill()
  } else {
    if (isWavy) {
      ctx.beginPath()
      ctx.moveTo(startX, y)
      ctx.quadraticCurveTo(startX + (endX - startX) * 0.25, y - 15, startX + (endX - startX) * 0.5, y)
      ctx.quadraticCurveTo(startX + (endX - startX) * 0.75, y + 15, hasDot ? endX - 8 : endX, y)
      ctx.stroke()
    } else {
      ctx.beginPath()
      ctx.moveTo(startX, y)
      ctx.lineTo(hasDot ? endX - 8 : endX, y)
      ctx.stroke()
    }
    ctx.setLineDash([])
    
    if (hasDot) {
      ctx.beginPath()
      ctx.arc(endX, y, 5, 0, Math.PI * 2)
      ctx.fill()
    } else {
      const arrowLength = isThick ? 14 : 10
      const arrowWidth = isThick ? 10 : 7
      
      ctx.beginPath()
      ctx.moveTo(endX, y)
      ctx.lineTo(endX - arrowLength, y - arrowWidth)
      ctx.lineTo(endX - arrowLength, y + arrowWidth)
      ctx.closePath()
      ctx.fill()
    }
  }
  
  ctx.restore()
}

onMounted(async () => {
  currentMonth.value = currentDate.getMonth() + 1
  currentYear.value = currentDate.getFullYear()
  
  if (!categoriaAttiva.value || categoriaAttiva.value.id !== categoriaId) {
    const societaId = (await import('../store.js')).useStore().societaAttiva.value?.id
    const res = await getAllCategorie(societaId)
    const cats = res.data || []
    const cat = cats.find(c => c.id === categoriaId)
    if (cat) setCategoria(cat)
  }
})
</script>

<style scoped>
.allenamenti-page { display: flex; flex-direction: column; height: 100vh; background: #0a0a0a; }
.page-header { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1rem; background: var(--color-primary); }
.header-left { display: flex; gap: 0.25rem; }
.btn-back, .btn-home { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; }
.btn-back svg, .btn-home svg { width: 18px; height: 18px; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 1rem; color: white; }
.allenamenti-body { flex: 1; overflow-y: auto; padding: 1rem; }
.month-nav { display: flex; align-items: center; justify-content: center; gap: 1rem; margin-bottom: 1.5rem; }
.nav-btn { width: 40px; height: 40px; display: flex; align-items: center; justify-content: center; background: #1a1a1a; border: 1px solid #333; border-radius: 8px; color: white; cursor: pointer; }
.nav-btn svg { width: 20px; height: 20px; }
.current-month { font-size: 1.25rem; font-weight: bold; color: white; min-width: 180px; text-align: center; }
.weeks-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
.week-card { background: #141414; border: 1px solid #222; border-radius: 12px; padding: 1rem; cursor: pointer; transition: all 0.2s; }
.week-card:hover { border-color: var(--color-primary); }
.week-card.active { border-color: var(--color-primary); background: rgba(16, 185, 129, 0.1); }
.week-header { font-weight: bold; color: #fff; margin-bottom: 0.25rem; }
.week-dates { font-size: 0.85rem; color: #666; margin-bottom: 0.75rem; }
.week-days { display: flex; gap: 0.25rem; flex-wrap: wrap; }
.day-chip { width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; background: #1a1a1a; border-radius: 6px; font-size: 0.8rem; color: #444; cursor: not-allowed; opacity: 0.4; }
.day-chip.has-training { background: var(--color-primary); color: white; cursor: pointer; opacity: 1; }
.day-chip.has-training:hover { transform: scale(1.1); }
.day-chip.today { border: 2px solid #fff; }
.day-chip.other-month { opacity: 0.6; }
.day-detail { background: #141414; border-radius: 12px; padding: 1.5rem; }
.day-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
.day-header h3 { color: #fff; margin: 0; }
.btn-add-exercise { padding: 0.5rem 1rem; background: var(--color-primary); border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; }
.btn-save-exercise { padding: 0.5rem 1rem; background: #22c55e; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; margin-left: 0.5rem; }
.btn-save-exercise:hover { background: #16a34a; }
.esercizi-list { display: flex; flex-direction: column; gap: 2rem; }
.esercizio-card { background: #1a1a1a; border-radius: 12px; padding: 1.25rem; }
.esercizio-header { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 1rem; }
.esercizio-num { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; background: var(--color-primary); border-radius: 50%; color: white; font-weight: bold; font-size: 1rem; }
.esercizio-titolo { flex: 1; background: #252525; border: 1px solid #333; border-radius: 8px; padding: 0.6rem 0.8rem; color: #fff; font-size: 1rem; }
.btn-toggle-lines { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; background: #252525; border: 1px solid #333; border-radius: 8px; color: white; cursor: pointer; font-size: 1.1rem; }
.btn-toggle-lines.active { background: var(--color-primary); border-color: var(--color-primary); }
.btn-delete { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; background: #dc2626; border: none; border-radius: 8px; color: white; cursor: pointer; font-size: 1.25rem; }

.board-area { display: flex; gap: 1rem; }
.board-main { flex: 1; display: flex; flex-direction: column; gap: 1rem; }
.board-sidebar { width: 280px; display: flex; flex-direction: column; gap: 1rem; flex-shrink: 0; }
.tools-panel { background: #0f0f0f; border-radius: 12px; padding: 1rem; display: flex; flex-wrap: wrap; gap: 1.5rem; align-items: flex-start; }
.tools-section { display: flex; flex-direction: column; gap: 0.5rem; }
.tools-label { font-size: 0.7rem; font-weight: 600; color: #666; text-transform: uppercase; letter-spacing: 0.05em; }
.tools-grid { display: flex; gap: 0.35rem; flex-wrap: wrap; }
.tool-btn { width: 38px; height: 38px; display: flex; align-items: center; justify-content: center; background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; color: white; cursor: pointer; transition: all 0.15s; }
.tool-btn:hover { background: #252525; border-color: #444; }
.tool-btn.active { background: var(--color-primary); border-color: var(--color-primary); }
.tool-icon { width: 20px; height: 20px; }
.tool-btn.active { background: var(--color-primary); border-color: var(--color-primary); }
.tool-shape { width: 18px; height: 18px; display: inline-block; border-radius: 50%; }
.tool-shape.player-red { background: #ef4444; }
.tool-shape.player-blue { background: #3b82f6; }
.tool-shape.player-yellow { background: #eab308; }
.tool-shape.player-green { background: #22c55e; }
.tool-shape.player-white { background: #fff; border: 1px solid #333; }
.tool-shape.player-black { background: #000; border: 1px solid #333; }
.tool-shape.goal-large { width: 30px; height: 18px; background: #8B4513; border-radius: 2px; }
.tool-shape.goal-small { width: 18px; height: 12px; background: #666; border-radius: 2px; }
.tool-shape.cone { width: 0; height: 0; border-left: 8px solid transparent; border-right: 8px solid transparent; border-bottom: 16px solid #ff6600; background: transparent; }
.tool-shape.disc { width: 14px; height: 14px; background: #ff6600; border-radius: 50%; }
.tool-shape.barrier { width: 28px; height: 10px; background: #ff6600; border-radius: 2px; }
.tool-shape.ladder { width: 24px; height: 10px; background: linear-gradient(90deg, #aaa 1px, transparent 1px); }
.tool-shape.ball { font-size: 14px; }
.tool-shape.zone { width: 16px; height: 16px; background: rgba(255,255,0,0.5); border-radius: 50%; border: 2px solid #eab308; }
.tools-actions { display: flex; gap: 0.5rem; margin-left: auto; }
.action-btn { padding: 0.5rem 0.75rem; background: #252525; border: 1px solid #333; border-radius: 8px; color: #fff; cursor: pointer; font-size: 0.85rem; }
.action-btn:hover { background: #333; }
.btn-clear { background: #dc2626; border-color: #dc2626; }
.btn-undo { }

.element-controls { background: #0f0f0f; border-radius: 8px; overflow: hidden; min-width: 200px; }
.element-controls-header { display: flex; justify-content: space-between; align-items: center; padding: 1rem; cursor: pointer; background: #1a1a1a; }
.element-controls-header:hover { background: #252525; }
.element-controls-header .tools-label { font-size: 0.7rem; font-weight: 600; color: #666; text-transform: uppercase; letter-spacing: 0.05em; margin: 0; }
.toggle-icon { font-size: 0.7rem; color: #666; }
.element-controls-body { padding: 1rem; display: flex; flex-direction: column; gap: 0.75rem; }
.control-row { display: flex; align-items: center; gap: 0.5rem; }
.control-row label { font-size: 0.8rem; color: #888; min-width: 60px; }
.color-picker { display: flex; gap: 0.25rem; }
.color-btn { width: 22px; height: 22px; border-radius: 4px; border: 2px solid transparent; cursor: pointer; }
.color-btn.active { border-color: #fff; }
.control-row input[type="range"] { flex: 1; accent-color: var(--color-primary); }
.toggle-btn { padding: 0.25rem 0.75rem; border-radius: 4px; border: 1px solid #444; background: #1a1a1a; color: #888; font-size: 0.75rem; cursor: pointer; }
.toggle-btn.active { background: var(--color-primary); border-color: var(--color-primary); color: white; }
.btn-delete-element { background: #dc2626; border-color: #dc2626; margin-top: 0.5rem; }
.element-actions { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 0.5rem; }
.btn-copy-element { flex: 1; padding: 0.4rem 0.8rem; background: #6366f1; border: none; border-radius: 6px; color: white; cursor: pointer; font-size: 0.8rem; }
.btn-paste-element { flex: 1; padding: 0.4rem 0.8rem; background: #22c55e; border: none; border-radius: 6px; color: white; cursor: pointer; font-size: 0.8rem; }
.btn-copy-element:disabled, .btn-paste-element:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-copy-element:hover:not(:disabled), .btn-paste-element:hover:not(:disabled) { opacity: 0.9; }

.tactical-board-container { border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.3); }
.tactical-board-wrapper { position: relative; width: 100%; }
.tactical-board-wrapper canvas { display: block; width: 100%; height: auto; cursor: grab; }
.tactical-board-wrapper canvas.tool-selected { cursor: crosshair; }
.tactical-board-wrapper canvas.dragging { cursor: grabbing; }
.tactical-board-container.no-lines .tactical-board-wrapper canvas { background: #2d5a27; }

.esercizio-description { flex: 1; display: flex; flex-direction: column; }
.esercizio-description textarea { width: 100%; flex: 1; min-height: 150px; background: #252525; border: 1px solid #333; border-radius: 8px; padding: 0.75rem; color: #ddd; font-size: 0.9rem; resize: vertical; }

.no-esercizi { text-align: center; padding: 2rem; color: #666; }
</style>
