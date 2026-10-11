import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 5174,
    proxy: {
      // Forward API calls to the backend — avoids mixed-content (HTTPS page → HTTP API)
      "/api": {
        target: "http://localhost:8001",
        changeOrigin: true,
        secure: false,
      },
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes("node_modules")) return;

          if (id.includes("react") || id.includes("react-dom")) return "react";
          if (id.includes("@mui")) return "mui";
          if (id.includes("react-markdown") || id.includes("remark-gfm") || id.includes("micromark")) return "markdown";
          if (id.includes("axios")) return "http";
          return "vendor";
        },
      },
    },
  },
});
