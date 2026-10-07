// Version checker for seamless production updates without manual hard refresh
// Evita che gli utenti debbano fare Ctrl+Shift+R quando viene rilasciata una nuova versione.

/* global __APP_VERSION__ */
const clientVersion = typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : null

let isChecking = false

export async function checkAppVersion() {
  if (!clientVersion || isChecking) return
  isChecking = true
  try {
    const res = await fetch(`/version.json?_t=${Date.now()}`, {
      cache: 'no-store',
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache'
      }
    })
    if (!res.ok) return
    const data = await res.json()
    if (data?.version && data.version !== clientVersion) {
      const lastReload = sessionStorage.getItem('thof_last_reload_version')
      if (lastReload !== data.version) {
        sessionStorage.setItem('thof_last_reload_version', data.version)
        console.log(`[THOF] Nuova versione rilevata (${data.version} vs ${clientVersion}), aggiornamento automatico...`)
        window.location.reload()
      }
    }
  } catch (e) {
    // Errori di rete temporanei ignorati silenziosamente
  } finally {
    isChecking = false
  }
}

export function initVersionChecker() {
  if (typeof window === 'undefined') return

  // 1. Controlla quando la scheda torna attiva/visibile (utente torna sull'app o sblocca il telefono)
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      checkAppVersion()
    }
  })

  // 2. Controllo periodico delicato ogni 3 minuti
  setInterval(checkAppVersion, 3 * 60 * 1000)
}
