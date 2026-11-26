import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Built into the Flutter web folder, so `flutter build web` copies it to /demo/.
export default defineConfig({
  base: './',
  plugins: [react()],
  build: { target: 'es2022', outDir: '../flutter_app/web/demo', emptyOutDir: true },
  resolve: { dedupe: ['react', 'react-dom'] },
})
