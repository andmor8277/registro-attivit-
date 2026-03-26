<template>
  <div class="app-layout">
    <nav v-if="token" class="topbar">
      <div class="topbar-brand">
        <img src="/logo.jpg" alt="RedTigers" class="logo-img" />
        <span class="brand-text">RED<span class="brand-red">TIGERS</span></span>
      </div>
      <div class="topbar-season" :class="{ empty: !stagioneCorrente }">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/>
          <path d="M12 6v6l4 2"/>
        </svg>
        <span>{{ stagioneCorrente ? `${stagioneCorrente}/${stagioneCorrente + 1}` : 'Stagione non impostata' }}</span>
      </div>
      <div class="topbar-actions">
        <span class="user-badge">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="8" r="4"/>
            <path d="M4 20c0-4 4-6 8-6s8 2 8 6"/>
          </svg>
          {{ utenteAttivo?.username }}
        </span>
        <router-link v-if="utenteAttivo?.is_admin" to="/admin" class="btn-nav btn-admin">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="3"/>
            <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-2 2 2 2 0 01-2-2v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 01-2-2 2 2 0 012-2h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 010-2.83 2 2 0 012.83 0l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 012-2 2 2 0 012 2v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 0 2 2 0 010 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 012 2 2 2 0 01-2 2h-.09a1.65 1.65 0 00-1.51 1z"/>
          </svg>
          Admin
        </router-link>
        <router-link to="/" class="btn-nav">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
          Home
        </router-link>
        <button @click="logout" class="btn-logout">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/>
            <polyline points="16 17 21 12 16 7"/>
            <line x1="21" y1="12" x2="9" y2="12"/>
          </svg>
          Esci
        </button>
      </div>
    </nav>
    <main class="main-content">
      <router-view />
    </main>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useStore } from './store.js'
import { useRouter } from 'vue-router'
import { getMe, getStagioni } from './api/index.js'

const { token, utenteAttivo, clearToken, setStagioneCorrente,stagioneCorrente } = useStore()
const router = useRouter()

async function logout() {
  clearToken()
  router.push('/login')
}

async function loadStagione() {
  try {
    const res = await getStagioni()
    console.log('Stagioni risposta:', res.data)
    const stagioniAttive = res.data?.attiva || []
    if (stagioniAttive.length > 0) {
      setStagioneCorrente(stagioniAttive[0])
    }
  } catch (e) {
    console.error('Errore nel caricamento stagione:', e)
  }
}

onMounted(async () => {
  if (token.value) {
    try {
      const res = await getMe()
      utenteAttivo.value = res.data
      await loadStagione()
    } catch {
      clearToken()
      router.push('/login')
    }
  }
})
</script>

<style scoped>
.app-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.topbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1.5rem;
  background: #000000;
  color: white;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: 0 4px 20px rgba(0,0,0,0.5);
}

.topbar-brand {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.logo-img {
  height: 42px;
  width: auto;
  object-fit: contain;
}

.brand-text {
  font-size: 1.4rem;
  font-weight: 900;
  letter-spacing: 0.05em;
  color: white;
  font-family: var(--font-sans);
}

.brand-red {
  color: #dc2626;
}

.topbar-season {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(220, 38, 38, 0.2);
  border: 1px solid rgba(220, 38, 38, 0.4);
  border-radius: 50px;
  font-size: 0.875rem;
  font-weight: 600;
  color: #fca5a5;
}

.topbar-season.empty {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.2);
  color: rgba(255, 255, 255, 0.7);
}

.topbar-season svg {
  width: 16px;
  height: 16px;
}

.topbar-actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.user-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: rgba(255,255,255,0.1);
  border-radius: 50px;
  font-size: 0.875rem;
  font-weight: 500;
  border: 1px solid rgba(255,255,255,0.15);
}

.user-badge svg {
  width: 18px;
  height: 18px;
}

.btn-nav {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: rgba(255,255,255,0.08);
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 50px;
  color: white;
  font-size: 0.875rem;
  font-weight: 500;
  transition: all var(--transition-base);
  cursor: pointer;
}

.btn-nav:hover {
  background: rgba(255,255,255,0.15);
  transform: translateY(-1px);
}

.btn-nav.btn-admin {
  background: rgba(220, 38, 38, 0.2);
  border-color: rgba(220, 38, 38, 0.4);
}

.btn-nav.btn-admin:hover {
  background: rgba(220, 38, 38, 0.35);
}

.btn-nav svg {
  width: 16px;
  height: 16px;
}

.btn-logout {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1.25rem;
  background: transparent;
  border: 2px solid rgba(255,255,255,0.4);
  border-radius: 50px;
  color: white;
  font-size: 0.875rem;
  font-weight: 600;
  transition: all var(--transition-base);
  cursor: pointer;
}

.btn-logout:hover {
  background: rgba(220, 38, 38, 0.8);
  border-color: #dc2626;
  transform: translateY(-1px);
}

.btn-logout svg {
  width: 16px;
  height: 16px;
}

.main-content {
  flex: 1;
  animation: fadeIn var(--transition-base);
}

@media (max-width: 768px) {
  .topbar {
    padding: 0.75rem 1rem;
    flex-wrap: wrap;
    gap: 0.75rem;
  }
  
  .topbar-actions {
    flex-wrap: wrap;
    gap: 0.5rem;
  }
  
  .user-badge span:last-child,
  .btn-nav span,
  .btn-logout span {
    display: none;
  }
  
  .brand-text {
    font-size: 1.1rem;
  }
  
  .logo-img {
    height: 36px;
  }
  
  .btn-nav,
  .btn-logout {
    padding: 0.5rem 0.75rem;
  }
}
</style>
