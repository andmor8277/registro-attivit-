import { Capacitor } from '@capacitor/core'

export const INACTIVITY_TIMEOUT_MS = 30 * 60 * 1000 // 30 minuti
export const INACTIVITY_STORAGE_KEY = 'thof_last_activity'

let lastThrottleUpdate = 0
let checkInterval = null
let initialized = false
let onTimeoutCallback = null

export function isNativeApp() {
  try {
    return Capacitor.isNativePlatform()
  } catch (e) {
    return false
  }
}

export function recordActivity() {
  if (isNativeApp()) return
  const now = Date.now()
  if (now - lastThrottleUpdate > 10000) {
    lastThrottleUpdate = now
    try {
      localStorage.setItem(INACTIVITY_STORAGE_KEY, now.toString())
    } catch (e) {}
  }
}

export function resetActivity() {
  if (isNativeApp()) return
  const now = Date.now()
  lastThrottleUpdate = now
  try {
    localStorage.setItem(INACTIVITY_STORAGE_KEY, now.toString())
  } catch (e) {}
}

export function clearActivity() {
  try {
    localStorage.removeItem(INACTIVITY_STORAGE_KEY)
  } catch (e) {}
}

export function isSessionExpired() {
  if (isNativeApp()) return false
  const token = localStorage.getItem('token')
  if (!token) return false
  const lastActStr = localStorage.getItem(INACTIVITY_STORAGE_KEY)
  if (!lastActStr) return false
  const elapsed = Date.now() - parseInt(lastActStr, 10)
  return elapsed >= INACTIVITY_TIMEOUT_MS
}

export function initInactivityTracker(onTimeout) {
  if (isNativeApp()) return
  onTimeoutCallback = onTimeout

  if (!initialized) {
    initialized = true
    const events = ['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll', 'click']
    events.forEach(evt => {
      window.addEventListener(evt, recordActivity, { passive: true })
    })

    const handleVisibilityOrFocus = () => {
      if (document.visibilityState === 'visible') {
        if (isSessionExpired()) {
          if (typeof onTimeoutCallback === 'function') onTimeoutCallback()
        } else {
          recordActivity()
        }
      }
    }

    document.addEventListener('visibilitychange', handleVisibilityOrFocus)
    window.addEventListener('focus', handleVisibilityOrFocus)

    window.addEventListener('storage', (e) => {
      if (e.key === 'token' && !e.newValue) {
        if (typeof onTimeoutCallback === 'function') onTimeoutCallback()
      }
    })
  }

  // Se l'utente è loggato e non c'è ancora un timestamp, inizializzalo
  if (localStorage.getItem('token') && !localStorage.getItem(INACTIVITY_STORAGE_KEY)) {
    resetActivity()
  }

  if (!checkInterval) {
    checkInterval = setInterval(() => {
      if (isSessionExpired()) {
        if (typeof onTimeoutCallback === 'function') onTimeoutCallback()
      }
    }, 15000)
  }
}
