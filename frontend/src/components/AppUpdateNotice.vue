<template>
  <Teleport to="body">
    <div v-if="update" class="upd-overlay">
      <div class="upd-card" role="dialog" aria-modal="true" aria-labelledby="upd-title">
        <div class="upd-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
        </div>

        <h3 id="upd-title" class="upd-title">Aggiornamento disponibile</h3>

        <p class="upd-lead">
          È disponibile <b>{{ update.releaseName }}</b>
          <span v-if="update.currentVersion" class="upd-from">
            (adesso hai la {{ update.currentVersion }}{{ update.currentBuild ? ' · build ' + update.currentBuild : '' }})
          </span>
        </p>

        <div v-if="updateMeta" class="upd-meta">{{ updateMeta }}</div>

        <div v-if="notesLines.length" class="upd-notes">
          <div v-for="(line, i) in notesLines" :key="i" class="upd-note">{{ line }}</div>
        </div>

        <p class="upd-hint">
          Al download, Android ti chiederà di consentire l'installazione da questa origine: è normale,
          l'app non passa dal Play Store. I dati non vengono toccati.
        </p>

        <div class="upd-actions">
          <button class="upd-btn upd-btn-secondary" @click="nonOra">Non ora</button>
          <button class="upd-btn upd-btn-primary" :disabled="opening" @click="scarica">
            <span v-if="opening" class="upd-spinner"></span>
            <template v-else>Scarica aggiornamento</template>
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { checkForAppUpdate, openAppUpdateDownload, skipAppUpdateVersion, initAppUpdateChecker } from '../core/appUpdate.js'

const update = ref(null)
const opening = ref(false)
let stopChecker = null

const notesLines = computed(() => {
  const raw = update.value?.releaseNotes || ''
  return raw
    .split('\n')
    .map((l) => l.replace(/^[-*•]\s*/, '').trim())
    .filter(Boolean)
    .slice(0, 8)
})

const updateMeta = computed(() => {
  const bits = []
  if (update.value?.apkSizeMb) bits.push(`${update.value.apkSizeMb} MB`)
  if (update.value?.publishedAt) {
    const d = new Date(update.value.publishedAt)
    if (!isNaN(d.getTime())) bits.push(d.toLocaleDateString('it-IT', { day: 'numeric', month: 'long', year: 'numeric' }))
  }
  return bits.join(' · ')
})

async function scarica() {
  if (!update.value) return
  opening.value = true
  try {
    await openAppUpdateDownload(update.value)
  } finally {
    opening.value = false
  }
}

function nonOra() {
  if (update.value) skipAppUpdateVersion(update.value.latestVersion)
  update.value = null
}

onMounted(() => {
  // Primo controllo subito (serve anche se il telefono non è mai andato in background)
  checkForAppUpdate().then((info) => {
    if (info) update.value = info
  })
  stopChecker = initAppUpdateChecker((info) => {
    if (!update.value) update.value = info
  })
})

onUnmounted(() => {
  if (typeof stopChecker === 'function') stopChecker()
})

defineExpose({ update, scarica, nonOra })
</script>

<style scoped>
.upd-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.55);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1200;
  padding: 1rem;
  animation: updFade 0.2s ease-out;
  backdrop-filter: blur(4px);
}

.upd-card {
  background: var(--color-surface);
  border-radius: var(--radius-xl);
  width: 100%;
  max-width: 420px;
  padding: 1.5rem;
  box-shadow: var(--shadow-xl);
  animation: updScale 0.28s ease-out;
  max-height: 88vh;
  overflow-y: auto;
}

.upd-icon {
  width: 46px;
  height: 46px;
  border-radius: 14px;
  background: var(--color-primary-soft);
  color: var(--color-primary);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 0.9rem;
}

.upd-icon svg {
  width: 24px;
  height: 24px;
}

.upd-title {
  font-size: 1.2rem;
  font-weight: 800;
  color: var(--color-text);
  margin: 0 0 0.35rem;
}

.upd-lead {
  font-size: 0.9375rem;
  color: var(--color-text-secondary);
  margin: 0 0 0.75rem;
  line-height: 1.45;
}

.upd-lead b {
  color: var(--color-text);
  font-weight: 700;
}

.upd-from {
  display: block;
  font-size: 0.8125rem;
  color: var(--color-text-muted);
  margin-top: 0.15rem;
}

.upd-meta {
  display: inline-block;
  font-family: var(--font-mono, monospace);
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  padding: 4px 10px;
  margin-bottom: 0.85rem;
}

.upd-notes {
  background: var(--color-bg);
  border: 1px solid var(--color-border-light);
  border-radius: var(--radius-md);
  padding: 0.75rem 0.9rem;
  margin-bottom: 0.85rem;
}

.upd-note {
  font-size: 0.875rem;
  color: var(--color-text-secondary);
  line-height: 1.5;
  padding-left: 0.9rem;
  position: relative;
}

.upd-note::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0.55em;
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: var(--color-primary);
}

.upd-hint {
  font-size: 0.75rem;
  color: var(--color-text-muted);
  line-height: 1.45;
  margin: 0 0 1.1rem;
}

.upd-actions {
  display: flex;
  gap: 0.6rem;
}

.upd-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border-radius: var(--radius-md);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.upd-btn-primary {
  background: var(--color-primary);
  border: none;
  color: #fff;
}

.upd-btn-primary:hover {
  background: var(--color-primary-dark);
}

.upd-btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.upd-btn-secondary {
  background: var(--color-bg);
  border: 2px solid var(--color-border);
  color: var(--color-text-secondary);
}

.upd-btn-secondary:hover {
  background: var(--color-border);
}

.upd-spinner {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255, 255, 255, 0.35);
  border-top-color: #fff;
  border-radius: 50%;
  animation: updSpin 0.8s linear infinite;
}

@keyframes updSpin {
  to {
    transform: rotate(360deg);
  }
}

@keyframes updFade {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes updScale {
  from {
    opacity: 0;
    transform: scale(0.96);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}
</style>
