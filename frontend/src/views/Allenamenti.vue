<template>
  <div class="rotate-device-overlay" v-if="showRotateMessage">
    <div class="rotate-device-message">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="4" y="2" width="16" height="20" rx="2" ry="2"/>
        <line x1="12" y1="18" x2="12" y2="18"/>
      </svg>
      <span>Ruota il dispositivo in orizzontale</span>
    </div>
  </div>
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
          <button class="btn-catalogo" @click="openCatalogo">📚 Catalogo</button>
          <button class="btn-save-exercise" @click="saveCurrentExercise" title="Salva">💾 Salva</button>
          <button class="btn-save-catalogo-explicit" @click="openSaveToCatalogoDialog" title="Salva nel Catalogo">💾 Salva nel Catalogo</button>
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

            <div class="esercizio-meta">
              <div class="focus-field">
                <label>Focus:</label>
                <select v-model="ex.focus" @change="saveEsercizio(ex)">
                  <option value="">Nessuno</option>
                  <option value="attivazione">Attivazione</option>
                  <option value="tecnica">Tecnica</option>
                  <option value="tattica">Tattica</option>
                  <option value="fisico">Fisico</option>
                  <option value="capacita-coordinativa">Capacità Coordinativa</option>
                  <option value="palleggio">Palleggio</option>
                  <option value="passaggio">Passaggio</option>
                  <option value="conclusione">Conclusione</option>
                  <option value="difesa">Difesa</option>
                  <option value="attacco">Attacco</option>
                  <option value="possessione">Possesso</option>
                  <option value="set-piece">Set Piece</option>
                </select>
              </div>
              <div class="meta-row">
                <div class="meta-field">
                  <label>Spazio:</label>
                  <input type="text" v-model="ex.spazio" placeholder="es. 20x30m" @change="saveEsercizio(ex)" />
                </div>
                <div class="meta-field">
                  <label>Tempo:</label>
                  <input type="text" v-model="ex.tempo" placeholder="es. 3x4'" @change="saveEsercizio(ex)" />
                </div>
              </div>
              <textarea v-model="ex.descrizione" placeholder="Descrizione dell'esercizio..." @change="saveEsercizio(ex)"></textarea>
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
                <div v-if="selectedElement && selectedElementExercise?.id === ex.id" class="element-controls" @click.stop>
                  <div class="element-controls-header" @click.stop="elementControlsOpen = !elementControlsOpen">
                    <span>MODIFICA OGGETTO</span>
                    <span class="toggle-icon">{{ elementControlsOpen ? '▼' : '▶' }}</span>
                  </div>
                  <div v-if="elementControlsOpen" class="element-controls-body">
                    <div class="control-row">
                      <label>Colore:</label>
                      <div class="color-picker">
                        <button v-for="c in colors" :key="c" class="color-btn" :class="{ active: selectedElement.colore === c }" :style="{ background: c }" @click.stop="changeColor(c)"></button>
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
                      <input type="range" v-model="selectedElement.length" min="20" max="150" step="5" @input="updateSize" />
                    </div>
                    <div v-if="selectedElement.tipo?.startsWith('tactic-')" class="control-row">
                      <label>Ondulata:</label>
                      <button class="toggle-btn" :class="{ active: selectedElement.wavy }" @click.stop="toggleWavy">
                        {{ selectedElement.wavy ? 'Sì' : 'No' }}
                      </button>
                    </div>
                    <div class="element-actions">
                      <button class="action-btn btn-copy-element" @click.stop="copySelected" :disabled="!selectedElement">📋 Copia</button>
                      <button class="action-btn btn-paste-element" @click.stop="pasteElement" :disabled="!copiedElement">📄 Incolla</button>
                      <button class="action-btn btn-delete-element" @click.stop="deleteSelected">🗑️ Elimina</button>
                    </div>
                  </div>
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

    <div v-if="showCatalogo" class="catalogo-overlay" @click.self="closeCatalogo">
      <div class="catalogo-modal">
        <div class="catalogo-header">
          <h2>📚 Catalogo Esercizi</h2>
          <button class="catalogo-close" @click="closeCatalogo">×</button>
        </div>
        <div class="catalogo-filters">
          <select v-model="catalogoFocus" @change="loadCatalogo">
            <option v-for="opt in focusOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
          </select>
          <span class="catalogo-count">{{ catalogoEsercizi.length }} esercizi unici</span>
        </div>
        <div class="catalogo-list">
          <div v-for="(ex, idx) in catalogoEsercizi" :key="idx" class="catalogo-item" :class="{ 'already-added': titoloGiaPresente(ex.titolo) }" @click="selezionaDaCatalogo(ex)">
            <div class="catalogo-item-header">
              <span class="catalogo-item-title">{{ ex.titolo }}</span>
              <span class="catalogo-item-focus" :class="'focus-' + ex.focus">{{ ex.focus_label }}</span>
            </div>
            <div v-if="ex.descrizione" class="catalogo-item-desc">{{ ex.descrizione }}</div>
            <div class="catalogo-item-footer">
              <span class="catalogo-item-count">Creato {{ formatDateShort(ex.creato_il) }}</span>
              <span v-if="titoloGiaPresente(ex.titolo)" class="catalogo-item-already">✓ Già nell'allenamento</span>
              <button v-if="ex.can_delete" class="catalogo-delete-btn" @click.stop="deleteFromCatalogo(ex)" title="Elimina dal catalogo">🗑️</button>
            </div>
          </div>
          <div v-if="catalogoEsercizi.length === 0" class="catalogo-empty">
            Nessun esercizio trovato per questo focus
          </div>
        </div>
      </div>
    </div>

    <div v-if="showSaveDialog" class="catalogo-overlay" @click.self="closeSaveDialog">
      <div class="save-dialog">
        <div class="save-dialog-header">
          <h3>💾 Salva nel Catalogo</h3>
        </div>
        <div class="save-dialog-body">
          <p>Salva questo esercizio nel catalogo condiviso. Gli altri allenatori potranno usarlo.</p>
          <div class="save-dialog-titolo">
            <label>Titolo:</label>
            <input v-model="saveDialogTitolo" @input="onSaveDialogTitoloChange" class="save-dialog-input" placeholder="Titolo esercizio..." />
          </div>
          <div v-if="saveDialogTitoloEsistente" class="save-dialog-warning">
            ⚠️ Esiste già un esercizio con questo titolo - verrà aggiornato
          </div>
        </div>
        <div class="save-dialog-actions">
          <button class="btn-save-catalogo" @click="confirmSaveEsercizio('catalogo')">💾 Salva</button>
          <button class="btn-cancel" @click="closeSaveDialog">Annulla</button>
        </div>
      </div>
    </div>

    <div v-if="showCatalogoSelectDialog" class="catalogo-overlay" @click.self="closeCatalogoSelectDialog">
      <div class="save-dialog">
        <div class="save-dialog-header">
          <h3>💾 Salva nel Catalogo</h3>
        </div>
        <div class="save-dialog-body">
          <p>Seleziona gli esercizi da salvare nel catalogo:</p>
          <div class="esercizi-selezione">
            <label class="esercizio-checkbox" v-for="ex in eserciziSenzaTitolo" :key="ex.id">
              <input type="checkbox" v-model="selectedForCatalogo[ex.id]" :disabled="!ex.titolo || !ex.titolo.trim()" />
              <span class="checkbox-titolo" :class="{ 'no-titolo': !ex.titolo || !ex.titolo.trim() }">{{ ex.titolo || 'Esercizio senza titolo' }}</span>
            </label>
            <div v-if="eserciziSenzaTitolo.length === 0" class="no-esercizi-selezione">
              Non ci sono esercizi in questo allenamento
            </div>
          </div>
        </div>
        <div class="save-dialog-actions">
          <button class="btn-save-catalogo" @click="confirmSaveSelectedToCatalogo" :disabled="!hasSelectedForCatalogo">💾 Salva selezionati</button>
          <button class="btn-cancel" @click="closeCatalogoSelectDialog">Annulla</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'
import { getAllCategorie, getAllenamentiGiornoByData, saveAllenamenti, getCatalogoEsercizi, getCatalogoEserciziNew, saveEsercizioToCatalogo, deleteEsercizioFromCatalogo, getFocusList } from '../api/index.js'
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
const showRotateMessage = ref(false)
const showCatalogo = ref(false)
const catalogoFocus = ref('')
const catalogoEsercizi = ref([])
const focusOptions = ref([])
const showSaveDialog = ref(false)
const saveDialogTitolo = ref('')
const saveDialogExercising = ref(null)
const saveDialogTitoloEsistente = ref(false)
const currentUserId = ref(null)
const isSuperAdmin = ref(false)
const showCatalogoSelectDialog = ref(false)
const selectedForCatalogo = ref({})
const eserciziSenzaTitolo = computed(() => {
  return esercizi.value
})
const hasSelectedForCatalogo = computed(() => {
  return esercizi.value.some(ex => selectedForCatalogo.value[ex.id] && ex.titolo && ex.titolo.trim())
})


const colors = ['#ef4444', '#3b82f6', '#eab308', '#22c55e', '#ffffff', '#000000', '#a855f7', '#f97316']

const monthNames = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre']
const currentMonthName = computed(() => monthNames[currentMonth.value - 1])

const weeksInMonth = computed(() => {
  const weeks = []
  const firstDay = new Date(currentYear.value, currentMonth.value - 1, 1)
  const lastDay = new Date(currentYear.value, currentMonth.value, 0)
  const dayNames = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab']
  
  let firstMonday = new Date(firstDay)
  const dayOfWeek = firstMonday.getDay()
  const daysToSubtract = dayOfWeek === 0 ? 6 : dayOfWeek - 1
  firstMonday.setDate(firstMonday.getDate() - daysToSubtract)
  
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
        const weekLabel = `Sett ${weekNum} (Lun-Ven)`
        const fmt = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
        weeks.push({ num: weekNum, label: weekLabel, start: fmt(currentWeekStart), end: fmt(weekEnd), days })
        weekNum++
      }
    }
    
    currentWeekStart.setDate(currentWeekStart.getDate() + 7)
  }
  return weeks
})

function formatDateRange(start, end) {
  const [sy, sm, sd] = start.split('-').map(Number)
  const [ey, em, ed] = end.split('-').map(Number)
  const s = new Date(sy, sm - 1, sd)
  const e = new Date(ey, em - 1, ed)
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
    console.log('Loaded from server:', JSON.stringify(dayData.esercizi, null, 2))
    let loadedEsercizi = []
    
    if (dayData.esercizi && dayData.esercizi.length > 0) {
      loadedEsercizi = dayData.esercizi.map((e, idx) => ({
        ...e,
        id: e.id || ('loaded_' + idx + '_' + Date.now()),
        fromCatalogo: false
      }))
    }
    
    esercizi.value = loadedEsercizi
    selectedExercise.value = loadedEsercizi.length > 0 ? loadedEsercizi[0] : null
    nextTick(() => {
      esercizi.value.forEach(ex => drawBoard(ex))
    })
  }).catch(() => {
    esercizi.value = []
    selectedExercise.value = null
    nextTick(() => {
      esercizi.value.forEach(ex => drawBoard(ex))
    })
  })
}

async function openCatalogo() {
  showCatalogo.value = true
  try {
    const res = await getFocusList()
    focusOptions.value = res.data.focus_options
  } catch (e) {
    console.error('Errore caricamento focus:', e)
  }
  await loadCatalogo()
}

async function loadCatalogo() {
  try {
    const res = await getCatalogoEserciziNew(catalogoFocus.value)
    catalogoEsercizi.value = res.data.esercizi || []
    currentUserId.value = res.data.current_user_id
    isSuperAdmin.value = res.data.is_super_admin
  } catch (e) {
    console.error('Errore caricamento catalogo:', e)
    catalogoEsercizi.value = []
  }
}

function closeCatalogo() {
  showCatalogo.value = false
}

function titoloGiaPresente(titolo) {
  if (!titolo) return false
  const titoloNorm = titolo.trim().toLowerCase()
  return esercizi.value.some(e => e.titolo && e.titolo.trim().toLowerCase() === titoloNorm)
}

function formatDateShort(dateStr) {
  if (!dateStr) return '?'
  const d = new Date(dateStr)
  return d.toLocaleDateString('it-IT', { day: 'numeric', month: 'short' })
}

async function deleteFromCatalogo(ex) {
  if (!confirm(`Eliminare "${ex.titolo}" dal catalogo?`)) return
  try {
    await deleteEsercizioFromCatalogo(ex.id)
    await loadCatalogo()
  } catch (e) {
    console.error('Errore eliminazione:', e)
    alert('Errore durante l\'eliminazione')
  }
}

function selezionaDaCatalogo(ex) {
  if (titoloGiaPresente(ex.titolo)) {
    return
  }
  
  const newId = Date.now()
  esercizi.value.push({
    id: newId,
    ordine: esercizi.value.length + 1,
    titolo: ex.titolo,
    descrizione: ex.descrizione || '',
    focus: ex.focus || '',
    campo_con_righe: ex.campo_con_righe !== false,
    elementi: (ex.elementi || []).map(el => ({
      ...el,
      id: Date.now() + Math.random()
    })),
    fromCatalogo: true,
    catalogoTitolo: ex.titolo
  })
  selectedExercise.value = esercizi.value[esercizi.value.length - 1]
  closeCatalogo()
  nextTick(() => {
    drawBoard(selectedExercise.value)
  })
}

function addEsercizio() {
  const newId = Date.now()
  esercizi.value.push({ id: newId, ordine: esercizi.value.length + 1, titolo: '', descrizione: '', focus: '', campo_con_righe: true, elementi: [] })
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
  console.log('Export PDF clicked')
  
  const doc = new jsPDF('portrait', 'mm', 'a4')
  const pageWidth = doc.internal.pageSize.getWidth()
  const pageHeight = doc.internal.pageSize.getHeight()
  let y = 20
  
  doc.setFontSize(18)
  doc.setTextColor(220, 38, 38)
  doc.text('Allenamento del ' + formatDate(selectedDay.value?.data || ''), pageWidth / 2, y, { align: 'center' })
  y += 12
  
  const eserciziCorrenti = esercizi.value || []
  
  if (eserciziCorrenti.length === 0) {
    doc.setFontSize(12)
    doc.setTextColor(0, 0, 0)
    doc.text('Nessun esercizio', 15, y)
  } else {
    for (let idx = 0; idx < eserciziCorrenti.length; idx++) {
      const ex = eserciziCorrenti[idx]
      console.log('Esercizio', idx, ':', ex.titolo, '- elementi:', ex.elementi?.length)
        
        if (y > pageHeight - 120) {
          doc.addPage()
          y = 20
        }
        
        doc.setFontSize(14)
        doc.setTextColor(220, 38, 38)
        doc.text('Esercizio ' + (idx + 1) + ': ' + (ex.titolo || 'Senza titolo'), 15, y)
        y += 8
        
        if (ex.focus) {
          const focusLabels = {
            'tecnica': 'Tecnica',
            'tattica': 'Tattica',
            'fisico': 'Fisico',
            'capacita-coordinativa': 'Cap. Coordinativa',
            'palleggio': 'Palleggio',
            'passaggio': 'Passaggio',
            'conclusione': 'Conclusione',
            'difesa': 'Difesa',
            'attacco': 'Attacco',
            'possessione': 'Possesso',
            'set-piece': 'Set Piece',
            'attivazione': 'Attivazione'
          }
          const focusLabel = focusLabels[ex.focus] || ex.focus
          doc.setFontSize(10)
          doc.setTextColor(100, 100, 100)
          doc.text('Focus: ' + focusLabel, 15, y)
          y += 6
          
          if (ex.spazio) {
            doc.text('Spazio: ' + ex.spazio, 15, y)
            y += 6
          }
          if (ex.tempo) {
            doc.text('Tempo: ' + ex.tempo, 15, y)
            y += 6
          }
        }
        
        if (ex.descrizione) {
          doc.setFontSize(10)
          doc.setTextColor(50, 50, 50)
          const descLines = doc.splitTextToSize(ex.descrizione, pageWidth - 30)
          doc.text(descLines, 15, y)
          y += descLines.length * 5 + 5
        }
        
        y += 5
        
        const canvasWidth = 400
        const canvasHeight = 260
        
        const fieldWidth = pageWidth - 30
        const fieldX = 15
        const fieldHeight = fieldWidth * (canvasHeight / canvasWidth)
        
        if (y + fieldHeight > pageHeight - 20) {
          doc.addPage()
          y = 20
        }
        
        try {
          const tempCanvas = document.createElement('canvas')
          tempCanvas.width = 800
          tempCanvas.height = 500
          const ctx = tempCanvas.getContext('2d')
          
          const marginX = 800 * 0.03
          const marginY = 500 * 0.03
          const fieldW = 800 - marginX * 2
          const fieldH = 500 - marginY * 2
          
          const stripeCount = 12
          const stripeWidth = fieldW / stripeCount
          for (let i = 0; i < stripeCount; i++) {
            ctx.fillStyle = i % 2 === 0 ? '#2d5a1b' : '#3a7a24'
            ctx.fillRect(marginX + i * stripeWidth, marginY, stripeWidth, fieldH)
          }
          
          if (ex.campo_con_righe !== false) {
            ctx.strokeStyle = '#fff'
            ctx.lineWidth = 2
            
            ctx.strokeRect(marginX, marginY, fieldW, fieldH)
            
            ctx.beginPath()
            ctx.moveTo(800 / 2, marginY)
            ctx.lineTo(800 / 2, 500 - marginY)
            ctx.stroke()
            
            const centerR = fieldW * 0.15
            ctx.beginPath()
            ctx.arc(800 / 2, 500 / 2, centerR, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(800 / 2, 500 / 2, 5, 0, Math.PI * 2)
            ctx.fillStyle = '#fff'
            ctx.fill()
            
            const smallDepth = fieldW * 0.05
            const smallHeight = fieldH * 0.27
            const penaltyDepth = fieldW * 0.16
            const penaltyHeight = fieldH * 0.59
            const arcR = fieldW * 0.09
            const goalHeight = fieldH * 0.07
            const goalDepth = fieldW * 0.02
            
            const smallTop = 500 / 2 - smallHeight / 2
            const penaltyTop = 500 / 2 - penaltyHeight / 2
            
            ctx.strokeRect(marginX, smallTop, smallDepth, smallHeight)
            ctx.strokeRect(800 - marginX - smallDepth, smallTop, smallDepth, smallHeight)
            
            ctx.strokeRect(marginX, penaltyTop, penaltyDepth, penaltyHeight)
            ctx.strokeRect(800 - marginX - penaltyDepth, penaltyTop, penaltyDepth, penaltyHeight)
            
            const lunetteCenterX = marginX + penaltyDepth
            const lunetteCenterXRight = 800 - marginX - penaltyDepth
            
            ctx.beginPath()
            ctx.arc(lunetteCenterX, 500 / 2, arcR, -Math.PI / 2, Math.PI / 2)
            ctx.strokeStyle = '#fff'
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(lunetteCenterXRight, 500 / 2, arcR, Math.PI / 2, -Math.PI / 2)
            ctx.stroke()
            
            const penaltySpotX = fieldW * 0.105
            
            ctx.beginPath()
            ctx.arc(marginX + penaltySpotX, 500 / 2, 5, 0, Math.PI * 2)
            ctx.fillStyle = '#fff'
            ctx.fill()
            ctx.beginPath()
            ctx.arc(800 - marginX - penaltySpotX, 500 / 2, 5, 0, Math.PI * 2)
            ctx.fill()
            
            ctx.strokeRect(marginX - goalDepth, 500 / 2 - goalHeight / 2, goalDepth, goalHeight)
            ctx.strokeRect(800 - marginX, 500 / 2 - goalHeight / 2, goalDepth, goalHeight)
          }
          
          const elementi = ex.elementi || []
          
          for (const el of elementi) {
            const x = el.x * 800 / 100
            const yPos = el.y * 500 / 100
            const size = el.size || 1
            const rot = (el.rotazione || 0) * Math.PI / 180
            
            ctx.save()
            ctx.translate(x, yPos)
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
                if (el.numero) {
                  ctx.fillStyle = '#000'
                  ctx.font = 'bold 14px Arial'
                  ctx.textAlign = 'center'
                  ctx.textBaseline = 'middle'
                  ctx.fillText(el.numero.toString(), 0, 1)
                }
                break
              case 'arrow-pass':
                ctx.strokeStyle = el.colore || '#ef4444'
                ctx.fillStyle = el.colore || '#ef4444'
                ctx.lineWidth = 5
                ctx.beginPath()
                ctx.moveTo(-35, 0)
                ctx.lineTo(25, 0)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(25, 0)
                ctx.lineTo(10, -10)
                ctx.lineTo(10, 10)
                ctx.closePath()
                ctx.fill()
                break
              case 'arrow-dribble':
                ctx.strokeStyle = el.colore || '#eab308'
                ctx.lineWidth = 5
                ctx.setLineDash([10, 8])
                ctx.beginPath()
                ctx.moveTo(-35, 0)
                ctx.lineTo(25, 0)
                ctx.stroke()
                ctx.setLineDash([])
                ctx.fillStyle = el.colore || '#eab308'
                ctx.beginPath()
                ctx.moveTo(25, 0)
                ctx.lineTo(10, -10)
                ctx.lineTo(10, 10)
                ctx.closePath()
                ctx.fill()
                break
              case 'arrow-wall':
                ctx.strokeStyle = el.colore || '#3b82f6'
                ctx.fillStyle = el.colore || '#3b82f6'
                ctx.lineWidth = 5
                ctx.beginPath()
                ctx.moveTo(-35, 0)
                ctx.lineTo(25, 0)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(25, 0)
                ctx.lineTo(10, -10)
                ctx.lineTo(10, 10)
                ctx.closePath()
                ctx.fill()
                ctx.beginPath()
                ctx.moveTo(35, 0)
                ctx.lineTo(-25, 0)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(-25, 0)
                ctx.lineTo(-10, -10)
                ctx.lineTo(-10, 10)
                ctx.closePath()
                ctx.fill()
                break
              case 'arrow-shot':
                ctx.strokeStyle = el.colore || '#22c55e'
                ctx.fillStyle = el.colore || '#22c55e'
                ctx.lineWidth = 7
                ctx.beginPath()
                ctx.moveTo(-35, 0)
                ctx.lineTo(25, 0)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(25, 0)
                ctx.lineTo(10, -12)
                ctx.lineTo(10, 12)
                ctx.closePath()
                ctx.fill()
                break
              case 'arrow-run':
                ctx.strokeStyle = el.colore || '#a855f7'
                ctx.fillStyle = el.colore || '#a855f7'
                ctx.lineWidth = 5
                ctx.beginPath()
                ctx.moveTo(-35, 0)
                ctx.lineTo(25, 0)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(30, 0, 10, -Math.PI / 2, Math.PI / 2)
                ctx.fill()
                break
              case 'arrow-up': drawArrow(ctx, 0, -1, el.colore || '#ef4444', false, false, el.length || 60); break
              case 'arrow-down': drawArrow(ctx, 0, 1, el.colore || '#ef4444', false, false, el.length || 60); break
              case 'arrow-left': drawArrow(ctx, -1, 0, el.colore || '#ef4444', false, false, el.length || 60); break
              case 'arrow-right': drawArrow(ctx, 1, 0, el.colore || '#ef4444', false, false, el.length || 60); break
              case 'arrow-dashed-up': drawArrow(ctx, 0, -1, el.colore || '#eab308', true, false, el.length || 60); break
              case 'arrow-dashed-down': drawArrow(ctx, 0, 1, el.colore || '#eab308', true, false, el.length || 60); break
              case 'arrow-dashed-left': drawArrow(ctx, -1, 0, el.colore || '#eab308', true, false, el.length || 60); break
              case 'arrow-dashed-right': drawArrow(ctx, 1, 0, el.colore || '#eab308', true, false, el.length || 60); break
              case 'arrow-wavy-up': drawArrow(ctx, 0, -1, el.colore || '#a855f7', false, true, el.length || 60); break
              case 'arrow-wavy-down': drawArrow(ctx, 0, 1, el.colore || '#a855f7', false, true, el.length || 60); break
              case 'arrow-wavy-left': drawArrow(ctx, -1, 0, el.colore || '#a855f7', false, true, el.length || 60); break
              case 'arrow-wavy-right': drawArrow(ctx, 1, 0, el.colore || '#a855f7', false, true, el.length || 60); break
              case 'tactic-pass': case 'tactic-dribble': case 'tactic-wall': case 'tactic-shot': case 'tactic-run':
                drawTacticalArrow(ctx, el)
                break
              case 'cone': case 'cone-yellow': case 'cone-red': case 'cone-blue': case 'cone-green': case 'cone-white':
                const pdfBaseW = 22
                const pdfTopW = 3
                const pdfHeight = 36
                const pdfRimH = 4
                const pdfConeColor = el.colore || '#ff6600'
                ctx.fillStyle = pdfConeColor
                ctx.beginPath()
                ctx.moveTo(-pdfBaseW/2, 0)
                ctx.quadraticCurveTo(-pdfBaseW/2 - 3, -pdfHeight/3, -pdfTopW, -pdfHeight)
                ctx.quadraticCurveTo(0, -pdfHeight + 2, pdfTopW, -pdfHeight)
                ctx.quadraticCurveTo(pdfBaseW/2 + 3, -pdfHeight/3, pdfBaseW/2, 0)
                ctx.closePath()
                ctx.fill()
                ctx.fillStyle = pdfConeColor
                ctx.beginPath()
                ctx.ellipse(0, 0, pdfBaseW/2 + 1, pdfRimH/2, 0, 0, Math.PI * 2)
                ctx.fill()
                break
              case 'cone-small':
                const pdfSmBaseW = 14
                const pdfSmTopW = 2
                const pdfSmHeight = 24
                const pdfSmRimH = 3
                const pdfSmConeColor = el.colore || '#eab308'
                ctx.fillStyle = pdfSmConeColor
                ctx.beginPath()
                ctx.moveTo(-pdfSmBaseW/2, 0)
                ctx.quadraticCurveTo(-pdfSmBaseW/2 - 2, -pdfSmHeight/3, -pdfSmTopW, -pdfSmHeight)
                ctx.quadraticCurveTo(0, -pdfSmHeight + 1.5, pdfSmTopW, -pdfSmHeight)
                ctx.quadraticCurveTo(pdfSmBaseW/2 + 2, -pdfSmHeight/3, pdfSmBaseW/2, 0)
                ctx.closePath()
                ctx.fill()
                ctx.fillStyle = pdfSmConeColor
                ctx.beginPath()
                ctx.ellipse(0, 0, pdfSmBaseW/2 + 0.5, pdfSmRimH/2, 0, 0, Math.PI * 2)
                ctx.fill()
                break
              case 'cone-striped':
                const strPdfBaseW = 22
                const strPdfTopW = 3
                const strPdfHeight = 36
                const strPdfRimH = 4
                const strPdfConeColor = el.colore || '#ffffff'
                ctx.fillStyle = strPdfConeColor
                ctx.beginPath()
                ctx.moveTo(-strPdfBaseW/2, 0)
                ctx.quadraticCurveTo(-strPdfBaseW/2 - 3, -strPdfHeight/3, -strPdfTopW, -strPdfHeight)
                ctx.quadraticCurveTo(0, -strPdfHeight + 2, strPdfTopW, -strPdfHeight)
                ctx.quadraticCurveTo(strPdfBaseW/2 + 3, -strPdfHeight/3, strPdfBaseW/2, 0)
                ctx.closePath()
                ctx.fill()
                ctx.save()
                ctx.clip()
                ctx.strokeStyle = '#ef4444'
                ctx.lineWidth = 3
                for (let i = -30; i < 60; i += 12) {
                  ctx.beginPath()
                  ctx.moveTo(-strPdfBaseW + i, 0)
                  ctx.lineTo(i, -strPdfHeight)
                  ctx.stroke()
                }
                ctx.restore()
                ctx.fillStyle = strPdfConeColor
                ctx.beginPath()
                ctx.ellipse(0, 0, strPdfBaseW/2 + 1, strPdfRimH/2, 0, 0, Math.PI * 2)
                ctx.fill()
                break
              case 'ball': case 'ball-blue': case 'ball-red': case 'ball-yellow': case 'ball-orange':
                const ballP = el.colore || '#111111'
                const ballS = '#ffffff'
                const ballO = el.tipo === 'ball-blue' ? '#002277' : el.tipo === 'ball-red' ? '#990000' : el.tipo === 'ball-orange' ? '#cc4400' : el.tipo === 'ball-yellow' ? '#000000' : '#111111'
                const r = 18 * (el.size || 1)
                ctx.beginPath()
                ctx.arc(0, 0, r, 0, Math.PI * 2)
                ctx.fillStyle = ballS
                ctx.fill()
                ctx.strokeStyle = ballO
                ctx.lineWidth = 2.5
                ctx.stroke()
                const pentSize = r * 0.22
                const hexSize = r * 0.35
                const centerOffset = r * 0.35
                ctx.lineWidth = 2
                ctx.strokeStyle = ballO
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
                  ctx.fillStyle = ballS
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
                ctx.fillStyle = ballP
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
                  ctx.fillStyle = ballP
                  ctx.fill()
                  ctx.stroke()
                }
                break
              case 'palla':
                const pallaR = 18 * (el.size || 1)
                const pallaP = el.colore || '#111111'
                const pallaS = '#ffffff'
                const pallaO = '#111111'
                ctx.beginPath()
                ctx.arc(0, 0, pallaR, 0, Math.PI * 2)
                ctx.fillStyle = pallaS
                ctx.fill()
                ctx.strokeStyle = pallaO
                ctx.lineWidth = 2.5
                ctx.stroke()
                const pPentSize = pallaR * 0.22
                const pHexSize = pallaR * 0.35
                const pCenterOffset = pallaR * 0.35
                ctx.lineWidth = 2
                ctx.strokeStyle = pallaO
                for (let i = 0; i < 5; i++) {
                  const angle = (i * 72 - 90) * Math.PI / 180
                  const hx = Math.cos(angle) * pCenterOffset
                  const hy = Math.sin(angle) * pCenterOffset
                  ctx.beginPath()
                  for (let j = 0; j < 6; j++) {
                    const a = (angle + (j * 60 - 30) * Math.PI / 180)
                    const px = hx + Math.cos(a) * pHexSize
                    const py = hy + Math.sin(a) * pHexSize
                    if (j === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                  }
                  ctx.closePath()
                  ctx.fillStyle = pallaS
                  ctx.fill()
                  ctx.stroke()
                }
                ctx.beginPath()
                for (let j = 0; j < 5; j++) {
                  const a = (j * 72 - 90 + 36) * Math.PI / 180
                  const px = Math.cos(a) * pPentSize
                  const py = Math.sin(a) * pPentSize
                  if (j === 0) ctx.moveTo(px, py)
                  else ctx.lineTo(px, py)
                }
                ctx.closePath()
                ctx.fillStyle = pallaP
                ctx.fill()
                ctx.stroke()
                for (let i = 0; i < 5; i++) {
                  const angle = (i * 72 - 90) * Math.PI / 180
                  const hx = Math.cos(angle) * pCenterOffset
                  const hy = Math.sin(angle) * pCenterOffset
                  const outerAngle = angle + 30 * Math.PI / 180
                  const ox = hx + Math.cos(outerAngle) * pHexSize * 0.8
                  const oy = hy + Math.sin(outerAngle) * pHexSize * 0.8
                  ctx.beginPath()
                  for (let j = 0; j < 5; j++) {
                    const a = (outerAngle + (j * 72) * Math.PI / 180)
                    const px = ox + Math.cos(a) * pPentSize * 0.7
                    const py = oy + Math.sin(a) * pPentSize * 0.7
                    if (j === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                  }
                  ctx.closePath()
                  ctx.fillStyle = pallaP
                  ctx.fill()
                  ctx.stroke()
                }
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
                for (let gy = -9; gy <= 9; gy += 4) {
                  ctx.beginPath()
                  ctx.moveTo(-15, gy)
                  ctx.lineTo(15, gy)
                  ctx.stroke()
                }
                for (let gx = -12; gx <= 12; gx += 4) {
                  ctx.beginPath()
                  ctx.moveTo(gx, -9)
                  ctx.lineTo(gx, 9)
                  ctx.stroke()
                }
                break
              case 'stairs':
                ctx.fillStyle = el.colore || '#ff6600'
                for (let s = 0; s < 4; s++) {
                  ctx.fillRect(-36 + s * 24, -24 + s * 12, 20, 10)
                }
                break
              case 'ladder':
                ctx.fillStyle = el.colore || '#ff6600'
                for (let s = 0; s < 4; s++) {
                  ctx.fillRect(-24 + s * 16, -12, 12, 24)
                }
                break
              case 'disk-orange': case 'disk-blue': case 'disk-yellow': case 'disk':
                ctx.fillStyle = el.colore || '#ff6600'
                ctx.beginPath()
                ctx.ellipse(0, 0, 28, 10, 0, 0, Math.PI * 2)
                ctx.fill()
                ctx.strokeStyle = '#fff'
                ctx.lineWidth = 2
                ctx.stroke()
                ctx.beginPath()
                ctx.ellipse(0, 0, 12, 4, 0, 0, Math.PI * 2)
                ctx.fillStyle = el.colore === '#3b82f6' ? '#1d4ed8' : el.colore === '#eab308' ? '#a16207' : '#cc5200'
                ctx.fill()
                break
              case 'pole-red': case 'pole-yellow': case 'pole-white': case 'pole':
                ctx.fillStyle = el.colore || '#ff6600'
                ctx.fillRect(-6, -40, 12, 80)
                ctx.strokeStyle = '#000'
                ctx.lineWidth = 2
                ctx.strokeRect(-6, -40, 12, 80)
                ctx.beginPath()
                ctx.arc(0, -40, 10, 0, Math.PI * 2)
                ctx.fill()
                ctx.stroke()
                break
              case 'flag-red': case 'flag-yellow': case 'flag':
                ctx.strokeStyle = '#fff'
                ctx.lineWidth = 3
                ctx.beginPath()
                ctx.moveTo(0, 30)
                ctx.lineTo(0, -40)
                ctx.stroke()
                ctx.fillStyle = el.colore || '#ff6600'
                ctx.beginPath()
                ctx.moveTo(0, -40)
                ctx.lineTo(30, -30)
                ctx.lineTo(0, -20)
                ctx.closePath()
                ctx.fill()
                break
              case 'ring-red': case 'ring-blue': case 'ring-yellow': case 'ring':
                ctx.strokeStyle = el.colore || '#ef4444'
                ctx.lineWidth = 6
                ctx.beginPath()
                ctx.arc(0, 0, 24, 0, Math.PI * 2)
                ctx.stroke()
                ctx.fillStyle = el.colore || '#ef4444'
                ctx.beginPath()
                ctx.arc(0, 0, 8, 0, Math.PI * 2)
                ctx.fill()
                break
              case 'coin-yellow': case 'coin-brown': case 'coin-gold': case 'coin':
                ctx.fillStyle = el.colore || '#ffd700'
                ctx.beginPath()
                ctx.arc(0, 0, 20, 0, Math.PI * 2)
                ctx.fill()
                ctx.strokeStyle = '#000'
                ctx.lineWidth = 2
                ctx.stroke()
                ctx.fillStyle = '#000'
                ctx.font = 'bold 16px Arial'
                ctx.textAlign = 'center'
                ctx.textBaseline = 'middle'
                ctx.fillText('$', 0, 1)
                break
              case 'ladder-gray': case 'ladder-yellow': case 'ladder-red':
                ctx.strokeStyle = el.colore || '#888'
                ctx.lineWidth = 4
                ctx.beginPath()
                ctx.roundRect(-80, -6, 160, 12, 4)
                ctx.stroke()
                ctx.strokeStyle = '#666'
                ctx.lineWidth = 3
                ctx.beginPath()
                ctx.moveTo(-56, -14)
                ctx.lineTo(-56, 14)
                ctx.moveTo(0, -14)
                ctx.lineTo(0, 14)
                ctx.moveTo(56, -14)
                ctx.lineTo(56, 14)
                ctx.stroke()
                break
              case 'barre': case 'griglia': case 'piattaforma':
                ctx.strokeStyle = el.colore || '#888'
                ctx.lineWidth = 4
                ctx.beginPath()
                ctx.moveTo(-40, -10)
                ctx.lineTo(40, -10)
                ctx.moveTo(-40, 10)
                ctx.lineTo(40, 10)
                ctx.stroke()
                break
              case 'ostacolo': case 'telaio': case 'attrezzo':
                ctx.fillStyle = el.colore || '#ff6600'
                ctx.fillRect(-30, -16, 60, 32)
                ctx.strokeStyle = '#000'
                ctx.lineWidth = 2
                ctx.strokeRect(-30, -16, 60, 32)
                break
              case 'fitness': case 'pallone-sport':
                ctx.beginPath()
                ctx.arc(0, 0, 24, 0, Math.PI * 2)
                ctx.fillStyle = el.colore || '#333'
                ctx.fill()
                ctx.strokeStyle = '#000'
                ctx.lineWidth = 2
                ctx.stroke()
                break
              case 'hurdle':
                ctx.fillStyle = '#eab308'
                ctx.fillRect(-70, -12, 140, 16)
                ctx.strokeStyle = '#000'
                ctx.lineWidth = 2
                ctx.strokeRect(-70, -12, 140, 16)
                ctx.fillStyle = '#333'
                ctx.fillRect(-56, 8, 12, 32)
                ctx.fillRect(44, 8, 12, 32)
                break
              case 'disc':
                ctx.fillStyle = el.colore || '#ff6600'
                ctx.beginPath()
                ctx.ellipse(0, 0, 36, 12, 0, 0, Math.PI * 2)
                ctx.fill()
                ctx.strokeStyle = '#000'
                ctx.lineWidth = 2
                ctx.stroke()
                break
            }
            
            ctx.restore()
          }
          
          doc.addImage(tempCanvas.toDataURL('image/png'), 'PNG', fieldX, y, fieldWidth, fieldHeight)
        } catch (e) {
          console.error('Errore disegno campo PDF:', e)
        }
        
        y += fieldHeight + 15
      }
    }
    
    const categoriaNome = categoriaAttiva.value?.nome || 'Categoria'
    const dataSelezionata = selectedDay.value?.data || 'data'
    const dataFormattata = dataSelezionata.split('-').reverse().join('/')
    doc.save('Scheda ' + categoriaNome + ' del ' + dataFormattata + '.pdf')
  }

function saveEsercizio(ex) {
  if (!selectedDay.value) return
  
  if (ex && ex.fromCatalogo && ex.titolo === ex.catalogoTitolo) {
    saveDialogExercising.value = ex
    saveDialogTitolo.value = ex.titolo
    saveDialogTitoloEsistente.value = false
    showSaveDialog.value = true
    return
  }
  
  saveDataToServer()
}

function saveDataToServer() {
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
          focus: e.focus || '',
          spazio: e.spazio || '',
          tempo: e.tempo || '',
          campo_con_righe: e.campo_con_righe,
          elementi: e.elementi.map(el => ({
            tipo: el.tipo,
            x: el.x,
            y: el.y,
            rotazione: el.rotazione,
            colore: el.colore,
            numero: el.numero,
            length: el.length ?? 60,
            wavy: el.wavy ?? false,
            size: el.size ?? 1
          }))
        }))
      }]
    }]
  }
  
  console.log('Saving data:', JSON.stringify(data.settimane[0].giorni[0].esercizi[0]?.elementi, null, 2))
  
  saveAllenamenti(categoriaId, data).then(() => {
    console.log('Allenamenti salvati!')
  }).catch(err => {
    console.error('Errore nel salvataggio:', err)
  })
}

function openSaveToCatalogoDialog() {
  if (esercizi.value.length === 0) {
    alert('Non ci sono esercizi da salvare nel catalogo')
    return
  }
  esercizi.value.forEach(ex => {
    if (selectedForCatalogo.value[ex.id] === undefined) {
      selectedForCatalogo.value[ex.id] = true
    }
  })
  showCatalogoSelectDialog.value = true
}

function closeCatalogoSelectDialog() {
  showCatalogoSelectDialog.value = false
  selectedForCatalogo.value = {}
}

function confirmSaveSelectedToCatalogo() {
  const selectedExercises = esercizi.value.filter(ex => selectedForCatalogo.value[ex.id])
  if (selectedExercises.length === 0) {
    alert('Seleziona almeno un esercizio')
    return
  }
  
  closeCatalogoSelectDialog()
  
  let savedCount = 0
  let skippedCount = 0
  const promises = selectedExercises.map(ex => {
    if (!ex.titolo || !ex.titolo.trim()) {
      skippedCount++
      return Promise.resolve()
    }
    return saveEsercizioToCatalogo({
      titolo: ex.titolo,
      focus: ex.focus || '',
      spazio: ex.spazio || '',
      tempo: ex.tempo || '',
      descrizione: ex.descrizione || '',
      campo_con_righe: ex.campo_con_righe,
      elementi: ex.elementi || []
    }).then(() => {
      savedCount++
    }).catch(e => {
      console.error('Errore salvataggio:', e)
    })
  })
  
  Promise.all(promises).then(() => {
    if (savedCount > 0) {
      alert(`Salvati ${savedCount} esercizi nel catalogo!`)
    } else {
      alert('Nessun esercizio con titolo è stato salvato')
    }
  })
}

function closeSaveDialog() {
  showSaveDialog.value = false
  saveDialogExercising.value = null
  saveDialogTitolo.value = ''
}

function confirmSaveEsercizio(tipo) {
  if (!saveDialogExercising.value) return
  
  if (tipo === 'catalogo' && !saveDialogTitolo.value.trim()) {
    alert('Inserisci un titolo per salvare nel catalogo')
    return
  }
  
  const ex = saveDialogExercising.value
  
  if (tipo === 'catalogo') {
    saveEsercizioToCatalogo({
      titolo: saveDialogTitolo.value.trim() || ex.titolo,
      focus: ex.focus || '',
      spazio: ex.spazio || '',
      tempo: ex.tempo || '',
      descrizione: ex.descrizione || '',
      campo_con_righe: ex.campo_con_righe,
      elementi: ex.elementi || []
    }).then(() => {
      ex.fromCatalogo = false
      ex.titolo = saveDialogTitolo.value.trim() || ex.titolo
      closeSaveDialog()
      saveDataToServer()
    }).catch(e => {
      console.error('Errore salvataggio catalogo:', e)
      alert('Errore durante il salvataggio nel catalogo')
    })
  } else {
    ex.fromCatalogo = false
    ex.titolo = saveDialogTitolo.value.trim() || ex.titolo
    closeSaveDialog()
    saveDataToServer()
  }
}

function onSaveDialogTitoloChange() {
  if (!saveDialogTitolo.value.trim()) {
    saveDialogTitoloEsistente.value = false
    return
  }
  saveDialogTitoloEsistente.value = titoloGiaPresente(saveDialogTitolo.value) && saveDialogTitolo.value !== saveDialogExercising.value?.catalogoTitolo
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
  event.stopPropagation()
  if (!ex) ex = getCurrentExercise()
  if (!ex) return
  const rect = event.target.getBoundingClientRect()
  const x = (event.clientX - rect.left) / rect.width * 100
  const y = (event.clientY - rect.top) / rect.height * 100
  
  const clickedEl = (ex.elementi || []).find(el => {
    const elX = el.x * rect.width / 100
    const elY = el.y * rect.height / 100
    const dist = Math.sqrt((event.clientX - rect.left - elX) ** 2 + (event.clientY - rect.top - elY) ** 2)
    return dist < 25
  })
  
  if (isDragging.value) return
  
  if (clickedEl) {
    selectedElement.value = clickedEl
    selectedElementExercise.value = ex
    elementControlsOpen.value = true
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
    elementControlsOpen.value = true
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
    'arrow-up': '#ef4444', 'arrow-down': '#ef4444', 'arrow-left': '#ef4444', 'arrow-right': '#ef4444',
    'arrow-dashed-up': '#eab308', 'arrow-dashed-down': '#eab308', 'arrow-dashed-left': '#eab308', 'arrow-dashed-right': '#eab308',
    'arrow-wavy-up': '#a855f7', 'arrow-wavy-down': '#a855f7', 'arrow-wavy-left': '#a855f7', 'arrow-wavy-right': '#a855f7',
    'tactic-pass': '#ef4444', 'tactic-dribble': '#eab308', 'tactic-wall': '#3b82f6', 'tactic-shot': '#22c55e', 'tactic-run': '#a855f7'
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
    
    ctx.beginPath()
    ctx.arc(lunetteCenterX, h / 2, arcR, -Math.PI / 2, Math.PI / 2)
    ctx.strokeStyle = '#fff'
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(lunetteCenterXRight, h / 2, arcR, Math.PI / 2, -Math.PI / 2)
    ctx.stroke()
    
    const penaltySpotX = fieldW * 0.105
    
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
        const baseW = 20
        const topW = 2.5
        const height = 34
        const rimH = 3
        const coneColor = el.colore || '#ff6600'
        
        ctx.fillStyle = coneColor
        ctx.beginPath()
        ctx.moveTo(-baseW/2, 0)
        ctx.quadraticCurveTo(-baseW/2 - 2.5, -height/3, -topW, -height)
        ctx.quadraticCurveTo(0, -height + 1.5, topW, -height)
        ctx.quadraticCurveTo(baseW/2 + 2.5, -height/3, baseW/2, 0)
        ctx.closePath()
        ctx.fill()
        
        const grad = ctx.createLinearGradient(-baseW/2, 0, baseW/2, 0)
        grad.addColorStop(0, 'rgba(0,0,0,0.3)')
        grad.addColorStop(0.3, 'rgba(0,0,0,0)')
        grad.addColorStop(0.7, 'rgba(0,0,0,0)')
        grad.addColorStop(1, 'rgba(0,0,0,0.4)')
        ctx.fillStyle = grad
        ctx.fill()
        
        ctx.fillStyle = coneColor
        ctx.beginPath()
        ctx.ellipse(0, 0, baseW/2 + 1, rimH/2, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = 'rgba(0,0,0,0.3)'
        ctx.lineWidth = 1
        ctx.stroke()
        break
      case 'cone-small':
        const smBaseW = 12
        const smTopW = 1.5
        const smHeight = 20
        const smRimH = 2
        const smConeColor = el.colore || '#eab308'
        
        ctx.fillStyle = smConeColor
        ctx.beginPath()
        ctx.moveTo(-smBaseW/2, 0)
        ctx.quadraticCurveTo(-smBaseW/2 - 1.5, -smHeight/3, -smTopW, -smHeight)
        ctx.quadraticCurveTo(0, -smHeight + 1, smTopW, -smHeight)
        ctx.quadraticCurveTo(smBaseW/2 + 1.5, -smHeight/3, smBaseW/2, 0)
        ctx.closePath()
        ctx.fill()
        
        const smGrad = ctx.createLinearGradient(-smBaseW/2, 0, smBaseW/2, 0)
        smGrad.addColorStop(0, 'rgba(0,0,0,0.3)')
        smGrad.addColorStop(0.3, 'rgba(0,0,0,0)')
        smGrad.addColorStop(0.7, 'rgba(0,0,0,0)')
        smGrad.addColorStop(1, 'rgba(0,0,0,0.4)')
        ctx.fillStyle = smGrad
        ctx.fill()
        
        ctx.fillStyle = smConeColor
        ctx.beginPath()
        ctx.ellipse(0, 0, smBaseW/2 + 0.5, smRimH/2, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = 'rgba(0,0,0,0.3)'
        ctx.lineWidth = 0.5
        ctx.stroke()
        break
      case 'cone-striped':
        const strBaseW = 20
        const strTopW = 2.5
        const strHeight = 34
        const strRimH = 3
        const strConeColor = el.colore || '#ffffff'
        
        ctx.fillStyle = strConeColor
        ctx.beginPath()
        ctx.moveTo(-strBaseW/2, 0)
        ctx.quadraticCurveTo(-strBaseW/2 - 2.5, -strHeight/3, -strTopW, -strHeight)
        ctx.quadraticCurveTo(0, -strHeight + 1.5, strTopW, -strHeight)
        ctx.quadraticCurveTo(strBaseW/2 + 2.5, -strHeight/3, strBaseW/2, 0)
        ctx.closePath()
        ctx.fill()
        
        ctx.save()
        ctx.clip()
        ctx.strokeStyle = '#ef4444'
        ctx.lineWidth = 3
        const stripeOffset = ((Date.now() / 100) % 20) - 10
        for (let i = -20; i < 40; i += 8) {
          ctx.beginPath()
          ctx.moveTo(-strBaseW + i + stripeOffset, 0)
          ctx.lineTo(i + stripeOffset, -strHeight)
          ctx.stroke()
        }
        ctx.restore()
        
        const strGrad = ctx.createLinearGradient(-strBaseW/2, 0, strBaseW/2, 0)
        strGrad.addColorStop(0, 'rgba(0,0,0,0.3)')
        strGrad.addColorStop(0.3, 'rgba(0,0,0,0)')
        strGrad.addColorStop(0.7, 'rgba(0,0,0,0)')
        strGrad.addColorStop(1, 'rgba(0,0,0,0.4)')
        ctx.fillStyle = strGrad
        ctx.fill()
        
        ctx.fillStyle = strConeColor
        ctx.beginPath()
        ctx.ellipse(0, 0, strBaseW/2 + 1, strRimH/2, 0, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = 'rgba(0,0,0,0.3)'
        ctx.lineWidth = 1
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
      case 'arrow-up': drawArrow(ctx, 0, -1, el.colore || '#ef4444', false, false, el.length || 60); break
      case 'arrow-down': drawArrow(ctx, 0, 1, el.colore || '#ef4444', false, false, el.length || 60); break
      case 'arrow-left': drawArrow(ctx, -1, 0, el.colore || '#ef4444', false, false, el.length || 60); break
      case 'arrow-right': drawArrow(ctx, 1, 0, el.colore || '#ef4444', false, false, el.length || 60); break
      case 'arrow-dashed-up': drawArrow(ctx, 0, -1, el.colore || '#eab308', true, false, el.length || 60); break
      case 'arrow-dashed-down': drawArrow(ctx, 0, 1, el.colore || '#eab308', true, false, el.length || 60); break
      case 'arrow-dashed-left': drawArrow(ctx, -1, 0, el.colore || '#eab308', true, false, el.length || 60); break
      case 'arrow-dashed-right': drawArrow(ctx, 1, 0, el.colore || '#eab308', true, false, el.length || 60); break
      case 'arrow-wavy-up': drawArrow(ctx, 0, -1, el.colore || '#a855f7', false, true, el.length || 60); break
      case 'arrow-wavy-down': drawArrow(ctx, 0, 1, el.colore || '#a855f7', false, true, el.length || 60); break
      case 'arrow-wavy-left': drawArrow(ctx, -1, 0, el.colore || '#a855f7', false, true, el.length || 60); break
      case 'arrow-wavy-right': drawArrow(ctx, 1, 0, el.colore || '#a855f7', false, true, el.length || 60); break
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
  const color = el.colore || '#000'
  const length = el.length || 60
  const startX = -length / 2
  const endX = length / 2
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
  
  ctx.shadowColor = 'transparent'
  ctx.shadowBlur = 0
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
  
  const checkRotate = () => {
    const isMobile = window.innerWidth <= 768
    const isPortrait = window.innerHeight > window.innerWidth
    showRotateMessage.value = isMobile && isPortrait
  }
  checkRotate()
  window.addEventListener('resize', checkRotate)
})
</script>

<style scoped>
.allenamenti-page { display: flex; flex-direction: column; height: 100vh; background: #0a0a0a; min-width: 100%; }
.allenamenti-body { flex: 1; overflow-y: auto; padding: 1rem; width: 100%; box-sizing: border-box; }
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
.day-detail { background: #141414; border-radius: 12px; padding: 1rem; width: 100%; box-sizing: border-box; }
.day-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
.day-header h3 { color: #fff; margin: 0; }
.btn-add-exercise { padding: 0.5rem 1rem; background: var(--color-primary); border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; }
.btn-save-exercise { padding: 0.5rem 1rem; background: #22c55e; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; margin-left: 0.5rem; }
.btn-save-exercise:hover { background: #16a34a; }
.btn-save-catalogo-explicit { padding: 0.5rem 1rem; background: #8b5cf6; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; margin-left: 0.5rem; }
.btn-save-catalogo-explicit:hover { background: #7c3aed; }
.esercizi-list { display: flex; flex-direction: column; gap: 2rem; }
.esercizio-card { background: #1a1a1a; border-radius: 12px; padding: 1rem; width: 100%; box-sizing: border-box; }
.esercizio-header { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.75rem; flex-shrink: 0; }
.esercizio-num { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; background: var(--color-primary); border-radius: 50%; color: white; font-weight: bold; font-size: 1rem; flex-shrink: 0; }
.esercizio-titolo { flex: 1; min-width: 200px; background: #252525; border: 1px solid #333; border-radius: 8px; padding: 0.6rem 0.8rem; color: #fff; font-size: 1rem; }
.btn-toggle-lines { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; background: #252525; border: 1px solid #333; border-radius: 8px; color: white; cursor: pointer; font-size: 1.1rem; flex-shrink: 0; }
.btn-toggle-lines.active { background: var(--color-primary); border-color: var(--color-primary); }
.btn-delete { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; background: #dc2626; border: none; border-radius: 8px; color: white; cursor: pointer; font-size: 1.25rem; flex-shrink: 0; }

.board-area { display: flex; gap: 1rem; width: 100%; box-sizing: border-box; }
.board-main { flex: 1; display: flex; flex-direction: column; gap: 1rem; min-width: 0; }
.board-sidebar { width: 280px; display: flex; flex-direction: column; gap: 1rem; flex-shrink: 0; }
.tools-panel { background: #0f0f0f; border-radius: 12px; padding: 0.75rem; display: flex; flex-wrap: wrap; gap: 1rem; align-items: flex-start; width: 100%; box-sizing: border-box; }
.esercizi-list { display: flex; flex-direction: column; gap: 1.5rem; width: 100%; }
.tools-section { display: flex; flex-direction: column; gap: 0.35rem; }
.tools-label { font-size: 0.65rem; font-weight: 600; color: #666; text-transform: uppercase; letter-spacing: 0.05em; }
.tools-grid { display: flex; gap: 0.25rem; flex-wrap: wrap; }
.tool-btn { width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 6px; color: white; cursor: pointer; transition: all 0.15s; flex-shrink: 0; }
.tool-btn:hover { background: #252525; border-color: #444; }
.tool-btn.active { background: var(--color-primary); border-color: var(--color-primary); }
.tool-icon { width: 18px; height: 18px; }
.tool-btn.active { background: var(--color-primary); border-color: var(--color-primary); }
.tool-shape { width: 16px; height: 16px; display: inline-block; border-radius: 50%; }
.tool-shape.player-red { background: #ef4444; }
.tool-shape.player-blue { background: #3b82f6; }
.tool-shape.player-yellow { background: #eab308; }
.tool-shape.player-green { background: #22c55e; }
.tool-shape.player-white { background: #fff; border: 1px solid #333; }
.tool-shape.player-black { background: #000; border: 1px solid #333; }
.tool-shape.goal-large { width: 28px; height: 16px; background: #8B4513; border-radius: 2px; }
.tool-shape.goal-small { width: 16px; height: 10px; background: #666; border-radius: 2px; }
.tool-shape.cone { width: 0; height: 0; border-left: 7px solid transparent; border-right: 7px solid transparent; border-bottom: 14px solid #ff6600; background: transparent; }
.tool-shape.disc { width: 12px; height: 12px; background: #ff6600; border-radius: 50%; }
.tool-shape.barrier { width: 24px; height: 8px; background: #ff6600; border-radius: 2px; }
.tool-shape.ladder { width: 20px; height: 8px; background: linear-gradient(90deg, #aaa 1px, transparent 1px); }
.tool-shape.ball { font-size: 12px; }
.tool-shape.zone { width: 14px; height: 14px; background: rgba(255,255,0,0.5); border-radius: 50%; border: 2px solid #eab308; }
.tools-actions { display: flex; gap: 0.5rem; margin-left: auto; flex-shrink: 0; }
.action-btn { padding: 0.4rem 0.6rem; background: #252525; border: 1px solid #333; border-radius: 6px; color: #fff; cursor: pointer; font-size: 0.8rem; flex-shrink: 0; }
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

.tactical-board-container { border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.3); width: 100%; max-width: none; }
.tactical-board-wrapper { position: relative; width: 100%; max-width: none; }
.tactical-board-wrapper canvas { display: block; width: 100%; max-width: none; height: auto; cursor: grab; }
.tactical-board-wrapper canvas.tool-selected { cursor: crosshair; }
.tactical-board-wrapper canvas.dragging { cursor: grabbing; }
.tactical-board-container.no-lines .tactical-board-wrapper canvas { background: #2d5a27; }

.esercizio-meta { padding: 0 0 0.75rem 0; display: flex; flex-direction: row; align-items: flex-start; gap: 1rem; }
.esercizio-meta textarea { flex: 1; min-height: 60px; background: #252525; border: 1px solid #333; border-radius: 6px; padding: 0.5rem 0.75rem; color: #ddd; font-size: 0.85rem; resize: vertical; font-family: inherit; }
.esercizio-description { flex: 1; display: flex; flex-direction: column; }
.esercizio-description textarea { width: 100%; flex: 1; min-height: 150px; background: #252525; border: 1px solid #333; border-radius: 8px; padding: 0.75rem; color: #ddd; font-size: 0.9rem; resize: vertical; }

.focus-field { display: flex; align-items: center; gap: 0.5rem; flex-shrink: 0; }
.focus-field label { font-size: 0.75rem; color: #888; font-weight: 500; white-space: nowrap; }
.focus-field select { max-width: 160px; padding: 0.3rem 0.5rem; background: #252525; border: 1px solid #333; border-radius: 6px; color: #ddd; font-size: 0.8rem; cursor: pointer; }
.focus-field select:focus { outline: none; border-color: var(--color-primary); }
.focus-field select option { background: #1a1a1a; color: #ddd; }
.meta-row { display: flex; gap: 1rem; margin: 0.5rem 0; }
.meta-field { display: flex; align-items: center; gap: 0.5rem; }
.meta-field label { font-size: 0.75rem; color: #888; font-weight: 500; white-space: nowrap; }
.meta-field input { padding: 0.3rem 0.5rem; background: #252525; border: 1px solid #333; border-radius: 6px; color: #ddd; font-size: 0.8rem; width: 80px; }
.meta-field input:focus { outline: none; border-color: var(--color-primary); }
.meta-field input::placeholder { color: #555; }

.no-esercizi { text-align: center; padding: 2rem; color: #666; }

.catalogo-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.8); z-index: 1000; display: flex; align-items: center; justify-content: center; }
.catalogo-modal { background: #1a1a1a; border-radius: 12px; width: 90%; max-width: 800px; max-height: 80vh; display: flex; flex-direction: column; }
.catalogo-header { display: flex; justify-content: space-between; align-items: center; padding: 1rem 1.5rem; border-bottom: 1px solid #333; }
.catalogo-header h2 { margin: 0; color: #fff; font-size: 1.25rem; }
.catalogo-close { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; background: #dc2626; border: none; border-radius: 8px; color: white; cursor: pointer; font-size: 1.5rem; }
.catalogo-close:hover { background: #b91c1c; }
.catalogo-filters { display: flex; align-items: center; gap: 1rem; padding: 1rem 1.5rem; border-bottom: 1px solid #333; }
.catalogo-filters select { flex: 1; max-width: 300px; padding: 0.5rem 0.75rem; background: #252525; border: 1px solid #333; border-radius: 8px; color: #fff; font-size: 0.9rem; }
.catalogo-filters select:focus { outline: none; border-color: var(--color-primary); }
.catalogo-count { color: #888; font-size: 0.85rem; }
.catalogo-list { flex: 1; overflow-y: auto; padding: 1rem 1.5rem; display: flex; flex-direction: column; gap: 0.75rem; }
.catalogo-item { background: #252525; border: 1px solid #333; border-radius: 8px; padding: 1rem; cursor: pointer; transition: all 0.2s; }
.catalogo-item:hover { border-color: var(--color-primary); background: #2a2a2a; }
.catalogo-item-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
.catalogo-item-title { color: #fff; font-weight: 600; font-size: 1rem; }
.catalogo-item-focus { padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.75rem; font-weight: 500; background: #374151; color: #fff; }
.catalogo-item-focus.focus-tecnica { background: #3b82f6; }
.catalogo-item-focus.focus-tattica { background: #8b5cf6; }
.catalogo-item-focus.focus-fisico { background: #ef4444; }
.catalogo-item-focus.focus-capacita-coordinativa { background: #f59e0b; }
.catalogo-item-focus.focus-palleggio { background: #10b981; }
.catalogo-item-focus.focus-passaggio { background: #06b6d4; }
.catalogo-item-focus.focus-conclusione { background: #f97316; }
.catalogo-item-focus.focus-difesa { background: #6366f1; }
.catalogo-item-focus.focus-attacco { background: #ec4899; }
.catalogo-item-focus.focus-possessione { background: #84cc16; }
.catalogo-item-focus.focus-set-piece { background: #a855f7; }
.catalogo-item-desc { color: #888; font-size: 0.85rem; margin-bottom: 0.5rem; }
.catalogo-item-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 0.5rem; gap: 0.5rem; }
.catalogo-item-count { color: #666; font-size: 0.75rem; flex: 1; }
.catalogo-item-already { color: #22c55e; font-size: 0.75rem; font-weight: 500; }
.catalogo-delete-btn { background: none; border: none; cursor: pointer; padding: 4px 8px; font-size: 0.9rem; opacity: 0.6; transition: opacity 0.2s; }
.catalogo-delete-btn:hover { opacity: 1; }
.catalogo-empty { text-align: center; padding: 2rem; color: #666; }
.catalogo-item.already-added { opacity: 0.6; cursor: not-allowed; }
.catalogo-item.already-added:hover { border-color: #333; background: #252525; }

.btn-catalogo { padding: 0.5rem 1rem; background: #8b5cf6; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 600; margin-left: 0.5rem; }
.btn-catalogo:hover { background: #7c3aed; }

.save-dialog { background: #1a1a1a; border-radius: 12px; width: 90%; max-width: 450px; }
.save-dialog-header { padding: 1rem 1.5rem; border-bottom: 1px solid #333; }
.save-dialog-header h3 { margin: 0; color: #fff; font-size: 1.1rem; }
.save-dialog-body { padding: 1.5rem; }
.save-dialog-body p { color: #ccc; margin-bottom: 1rem; line-height: 1.5; }
.save-dialog-titolo { display: flex; flex-direction: column; gap: 0.5rem; }
.save-dialog-titolo label { color: #888; font-size: 0.85rem; }
.save-dialog-input { width: 100%; padding: 0.75rem; background: #252525; border: 1px solid #333; border-radius: 8px; color: #fff; font-size: 0.95rem; box-sizing: border-box; }
.save-dialog-input:focus { outline: none; border-color: var(--color-primary); }
.save-dialog-warning { margin-top: 0.75rem; padding: 0.5rem; background: rgba(234, 179, 8, 0.2); border: 1px solid #eab308; border-radius: 6px; color: #eab308; font-size: 0.85rem; }
.save-dialog-actions { padding: 1rem 1.5rem; border-top: 1px solid #333; display: flex; gap: 0.75rem; justify-content: flex-end; }
.btn-save-private { padding: 0.5rem 1rem; background: #374151; border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 500; }
.btn-save-private:hover { background: #4b5563; }
.btn-save-catalogo { padding: 0.5rem 1rem; background: var(--color-primary); border: none; border-radius: 8px; color: white; cursor: pointer; font-weight: 500; }
.btn-save-catalogo:hover { background: #059669; }
.btn-save-catalogo:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-cancel { padding: 0.5rem 1rem; background: transparent; border: 1px solid #444; border-radius: 8px; color: #888; cursor: pointer; }
.btn-cancel:hover { background: #252525; }
.esercizi-selezione { max-height: 300px; overflow-y: auto; margin-top: 1rem; }
.esercizio-checkbox { display: flex; align-items: center; gap: 0.75rem; padding: 0.5rem; border-radius: 6px; cursor: pointer; }
.esercizio-checkbox:hover { background: #252525; }
.esercizio-checkbox input[type="checkbox"] { width: 18px; height: 18px; cursor: pointer; }
.checkbox-titolo { color: #ccc; font-size: 0.95rem; }
.no-esercizi-selezione { color: #666; text-align: center; padding: 1rem; }
.checkbox-titolo.no-titolo { color: #666; font-style: italic; }

.rotate-device-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.95);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  flex-direction: column;
  gap: 1rem;
}

.rotate-device-message {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  color: white;
  text-align: center;
  padding: 2rem;
}

.rotate-device-message svg {
  width: 80px;
  height: 80px;
  animation: rotate-hint 1.5s ease-in-out infinite;
}

.rotate-device-message span {
  font-size: 1.25rem;
  font-weight: 600;
}

@keyframes rotate-hint {
  0%, 100% { transform: rotate(0deg); }
  25% { transform: rotate(-20deg); }
  75% { transform: rotate(20deg); }
}
</style>
