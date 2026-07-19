/**
 * LBBS Frontend — React Entry Point
 * ====================================
 * This is the very first file that runs when the app loads.
 * It mounts the React component tree into the DOM element
 * with id="root" (defined in index.html).
 *
 * BrowserRouter enables client-side routing (react-router-dom).
 * Toaster provides toast notifications across the entire app.
 */

import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { Toaster } from "react-hot-toast";
import App from "./App";
import { AuthProvider } from "./hooks/useAuth";
import "./styles/index.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
      {/* Toast notifications (success, error messages) */}
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 4000,
          style: {
            background: "#1E293B",
            color: "#F8FAFC",
          },
        }}
      />
    </BrowserRouter>
  </React.StrictMode>
);


