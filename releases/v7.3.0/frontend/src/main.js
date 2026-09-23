import { createApp } from 'vue'
import App from './App.vue'
import './global.css'

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(regs => {
    for (const reg of regs) reg.unregister()
  })
}

import { router } from './core/router.js'

createApp(App).use(router).mount('#app')
