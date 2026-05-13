import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: './', // Gitee Pages需要相对路径
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
  },
})
