/**
 * LBBS API Client
 * =================
 * Centralized HTTP client for all backend API calls.
 * Uses Axios with automatic JWT token injection and
 * response/error interceptors.
 *
 * HOW IT WORKS:
 * 1. On login, JWT token is stored in localStorage
 * 2. Every API request automatically includes the token
 *    in the Authorization header
 * 3. If a 401 response comes back (token expired), the
 *    user is redirected to /login
 *
 * USAGE:
 *   import api from '../services/api';
 *
 *   // GET request
 *   const users = await api.get('/users');
 *
 *   // POST request with body
 *   const newUser = await api.post('/auth/register', {
 *     username: 'john',
 *     password: 'secret',
 *   });
 */

import axios from "axios";

// ---------------------------------------------------------------
// Create Axios instance with base configuration
// ---------------------------------------------------------------
const api = axios.create({
  // In development, Vite proxy forwards /api to localhost:8000
  // In production, this points to the deployed backend URL
  baseURL: "/api/v1",
  headers: {
    "Content-Type": "application/json",
  },
  timeout: 10000, // 10 second timeout
});

// ---------------------------------------------------------------
// Request Interceptor — Attach JWT token to every request
// ---------------------------------------------------------------
// An interceptor is a function that runs BEFORE every request
// is sent. We use it to automatically add the JWT token so
// you don't have to manually include it in every API call.
api.interceptors.request.use(
  (config) => {
    // Retrieve the stored JWT token
    const token = localStorage.getItem("access_token");

    // If token exists, add it to the Authorization header
    // Format: "Bearer eyJhbGciOiJIUzI1NiIs..."
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// ---------------------------------------------------------------
// Response Interceptor — Handle common errors globally
// ---------------------------------------------------------------
// This runs AFTER every response comes back. We use it to
// catch common errors so individual components don't have to.
api.interceptors.response.use(
  // Success: just return the response as-is
  (response) => response,

  // Error: handle common HTTP errors
  (error) => {
    if (error.response) {
      switch (error.response.status) {
        case 401:
          // Token expired or invalid → clear storage and redirect
          localStorage.removeItem("access_token");
          localStorage.removeItem("user");
          // Only redirect if not already on login page
          if (window.location.pathname !== "/login") {
            window.location.href = "/login";
          }
          break;

        case 403:
          // User doesn't have permission for this action
          console.error("Access denied:", error.response.data.detail);
          break;

        case 422:
          // Validation error from FastAPI/Pydantic
          console.error("Validation error:", error.response.data.detail);
          break;

        default:
          console.error("API error:", error.response.data);
      }
    } else if (error.request) {
      // Request was made but no response received (network error)
      console.error("Network error — is the backend running?");
    }

    return Promise.reject(error);
  }
);

export default api;

