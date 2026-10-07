import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import fs from 'fs'
import path from 'path'

const appBuildTime = Date.now().toString()

function versionPlugin() {
  return {
    name: 'generate-version-file',
    configureServer(server) {
      server.middlewares.use('/version.json', (req, res) => {
        res.setHeader('Content-Type', 'application/json')
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate')
        res.end(JSON.stringify({ version: appBuildTime }))
      })
    },
    generateBundle() {
      this.emitFile({
        type: 'asset',
        fileName: 'version.json',
        source: JSON.stringify({ version: appBuildTime })
      })
    }
  }
}

export default defineConfig({
  define: {
    __APP_VERSION__: JSON.stringify(appBuildTime)
  },
  plugins: [
    vue(),
    versionPlugin()
  ],
  server: {
    port: 5173,
    host: '0.0.0.0',
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
      '/uploads': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        secure: false,
      }
    }
  }
})
