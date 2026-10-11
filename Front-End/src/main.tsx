import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import App from "./App";
import { AuthProvider } from "./context/AuthContext";
import { SpaceProvider } from "./context/SpaceContext";
import "./index.css";
import "./i18n";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <AuthProvider>
      <SpaceProvider>
        <App />
      </SpaceProvider>
    </AuthProvider>
  </StrictMode>,
);

// Register service worker for PWA support (PROD only).
// In development, ensure any existing SW is unregistered to avoid cached old UI.
if ("serviceWorker" in navigator) {
  if (import.meta.env.PROD) {
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("/service-worker.js").then(
        (registration) => {
          console.log("ServiceWorker registration successful:", registration.scope);
        },
        (error) => {
          console.log("ServiceWorker registration failed:", error);
        },
      );
    });
  } else {
    navigator.serviceWorker.getRegistrations().then((registrations) => {
      registrations.forEach((registration) => registration.unregister());
    });
  }
}
