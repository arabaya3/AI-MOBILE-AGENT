import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
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
