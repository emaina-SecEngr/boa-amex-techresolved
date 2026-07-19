/**
 * useAuth — shared authentication state (React Context)
 * =====================================================
 * All components use the same user session. Login updates
 * Navbar, ProtectedRoute, etc. without requiring a full page reload.
 */

import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useMemo,
} from "react";
import { useNavigate } from "react-router-dom";
import api from "../services/api";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const storedUser = localStorage.getItem("user");
    const token = localStorage.getItem("access_token");

    if (storedUser && token) {
      try {
        setUser(JSON.parse(storedUser));
      } catch {
        localStorage.removeItem("user");
        localStorage.removeItem("access_token");
      }
    }

    setLoading(false);
  }, []);

  const login = useCallback(
    async (username, password) => {
      try {
        const formData = new URLSearchParams();
        formData.append("username", username);
        formData.append("password", password);

        const response = await api.post("/auth/login", formData, {
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
        });

        const { access_token, user: userData } = response.data;

        localStorage.setItem("access_token", access_token);
        localStorage.setItem("user", JSON.stringify(userData));
        setUser(userData);

        navigate("/dashboard");

        return { success: true };
      } catch (error) {
        const message =
          error.response?.data?.detail || "Login failed. Please try again.";
        return { success: false, error: message };
      }
    },
    [navigate]
  );

  const logout = useCallback(() => {
    localStorage.removeItem("access_token");
    localStorage.removeItem("user");
    setUser(null);
    navigate("/login");
  }, [navigate]);

  const hasRole = useCallback(
    (role) => {
      if (!user) return false;
      if (Array.isArray(role)) {
        return role.includes(user.role);
      }
      return user.role === role;
    },
    [user]
  );

  const value = useMemo(
    () => ({
      user,
      loading,
      isAuthenticated: !!user,
      login,
      logout,
      hasRole,
    }),
    [user, loading, login, logout, hasRole]
  );

  return React.createElement(
    AuthContext.Provider,
    { value },
    children
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return ctx;
}
