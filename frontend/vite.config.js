import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

const host = process.env.VITE_USE_MOCK === 'true' 
  ? 'http://localhost:8000' 
  : 'https://redtigers1957.crickethouse.mywire.org';

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: host,
        changeOrigin: true,
        secure: host !== 'http://localhost:8000',
      },
      '/uploads': {
        target: host,
        changeOrigin: true,
        secure: host !== 'http://localhost:8000',
      }
    }
  }
})
