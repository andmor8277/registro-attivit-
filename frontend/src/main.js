import { createApp } from 'vue'
import App from './App.vue'
import './global.css'

import { initVersionChecker } from './core/versionCheck.js'

// Pulizia immediata Service Worker e Cache Storage residui da vecchie PWA
if (typeof window !== 'undefined') {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(regs => {
      for (const reg of regs) reg.unregister()
    })
  }
  if ('caches' in window) {
    caches.keys().then(keys => {
      for (const key of keys) caches.delete(key)
    })
  }
  initVersionChecker()
}

import { router } from './core/router.js'

if (typeof window !== 'undefined') {
  const nativePrint = window.print
  window.print = function() {
    if (window.AndroidPrinter && typeof window.AndroidPrinter.print === 'function') {
      window.AndroidPrinter.print()
    } else if (typeof nativePrint === 'function') {
      nativePrint.call(window)
    }
  }
}

createApp(App).use(router).mount('#app')

