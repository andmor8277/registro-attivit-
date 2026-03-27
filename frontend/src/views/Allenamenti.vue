<template>
  <div class="drive-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/scelta/' + route.params.id)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="19" y1="12" x2="5" y2="12"/>
            <polyline points="12 19 5 12 12 5"/>
          </svg>
        </button>
        <button class="btn-home" @click="router.push('/')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
        </button>
      </div>
      <span class="titolo-toolbar">Allenamenti — {{ categoriaAttiva?.nome }} {{ categoriaAttiva?.anno }}</span>
    </header>

    <div class="drive-container" v-if="driveFolderId">
      <div class="drive-header-bar">
        <span class="drive-title">📁 Cartella Allenamenti</span>
        <a :href="'https://drive.google.com/drive/folders/' + driveFolderId" target="_blank" class="drive-link">
          Apri in Google Drive ↗
        </a>
      </div>
      <iframe 
        :src="'https://drive.google.com/embeddedfolderview?id=' + driveFolderId + '#grid'" 
        class="drive-iframe"
        title="Google Drive - Allenamenti"
      ></iframe>
    </div>

    <div v-else class="no-drive">
      <div class="no-drive-content">
        <span class="no-drive-icon">📁</span>
        <h3>Nessuna cartella Google Drive</h3>
        <p>Per visualizzare la cartella allenamenti, aggiungi l'ID della cartella Drive nella configurazione della categoria.</p>
        <p class="no-drive-hint">Home → Modifica Categoria → Google Drive Folder ID</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useStore } from '../store.js'

const router = useRouter()
const route = useRoute()
const { categoriaAttiva } = useStore()

const driveFolderId = computed(() => categoriaAttiva.value?.drive_folder_id || '')
</script>

<style scoped>
.drive-page { 
  display: flex; 
  flex-direction: column; 
  height: 100vh; 
  background: #111; 
  --color-primary: #dc2626;
}
.toolbar { 
  display: flex; 
  align-items: center; 
  gap: 0.8rem; 
  padding: 0.75rem 1rem; 
  background: #dc2626; 
  color: white; 
  flex-shrink: 0; 
}
.titolo-toolbar { 
  flex: 1; 
  font-weight: bold; 
  font-size: 1rem; 
}
.btn-back { 
  padding: 6px 14px; 
  border-radius: 4px; 
  border: 1px solid rgba(255,255,255,0.3); 
  background: rgba(255,255,255,0.1); 
  color: white; 
  cursor: pointer; 
  font-size: 0.85rem; 
}
.btn-back:hover { 
  background: rgba(255,255,255,0.2); 
}

.drive-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 1rem;
  overflow: hidden;
}

.drive-header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1rem;
  background: #1a1a1a;
  border: 1px solid #333;
  border-radius: 8px 8px 0 0;
  border-bottom: none;
}

.drive-title {
  font-weight: 600;
  font-size: 0.95rem;
  color: #ddd;
}

.drive-link {
  font-size: 0.85rem;
  color: #3b82f6;
  text-decoration: none;
  padding: 6px 12px;
  background: rgba(59, 130, 246, 0.1);
  border-radius: 6px;
}
.drive-link:hover {
  background: rgba(59, 130, 246, 0.2);
  text-decoration: underline;
}

.drive-iframe {
  flex: 1;
  width: 100%;
  border: 1px solid #333;
  border-radius: 0 0 8px 8px;
  background: white;
  min-height: 600px;
}

.no-drive {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
}

.no-drive-content {
  text-align: center;
  background: #1a1a1a;
  padding: 3rem;
  border-radius: 12px;
  border: 1px solid #333;
  max-width: 500px;
}

.no-drive-icon {
  font-size: 4rem;
  display: block;
  margin-bottom: 1rem;
}

.no-drive-content h3 {
  color: #ddd;
  margin: 0 0 1rem;
  font-size: 1.25rem;
}

.no-drive-content p {
  color: #888;
  margin: 0 0 0.5rem;
  line-height: 1.5;
}

.no-drive-hint {
  margin-top: 1.5rem !important;
  padding: 0.75rem;
  background: rgba(59, 130, 246, 0.1);
  border-radius: 6px;
  font-size: 0.85rem;
  color: #3b82f6 !important;
}

.page-header { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1rem; background: #dc2626; }
.header-left { display: flex; gap: 0.25rem; }
.btn-back, .btn-home { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.1); color: white; cursor: pointer; transition: background 0.2s; }
.btn-back:hover, .btn-home:hover { background: rgba(255,255,255,0.2); }
.btn-back svg, .btn-home svg { width: 18px; height: 18px; }
.titolo-toolbar { flex: 1; font-weight: bold; font-size: 1rem; color: white; }
</style>
