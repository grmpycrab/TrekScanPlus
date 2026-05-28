import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    headers: {
      // Allows Google sign-in popups to communicate back to this window.
      // 'same-origin' (the browser default) blocks window.postMessage from
      // cross-origin popups, which breaks signInWithPopup.
      'Cross-Origin-Opener-Policy': 'same-origin-allow-popups',
    },
  },
})
