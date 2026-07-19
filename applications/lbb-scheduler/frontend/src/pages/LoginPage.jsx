/**
 * Login Page — User Authentication
 * ===================================
 * Form for username/password login.
 * On success, stores JWT token and redirects to dashboard.
 * On failure, shows error message.
 *
 * ConOps 6.5.2: Login with username and password.
 * ConOps 6.5.4: Admin accounts require additional 2FA
 * (2FA will be added in a future sprint).
 */

import { useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";
import { Eye, EyeOff, LogIn } from "lucide-react";
import toast from "react-hot-toast";

export default function LoginPage() {
  // Form field state
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Get the login function from our auth hook
  const { login } = useAuth();

  // ---------------------------------------------------------------
  // Handle form submission
  // ---------------------------------------------------------------
  const handleSubmit = async (e) => {
    // Prevent the browser from doing a full page reload
    // (default behavior for HTML form submission)
    e.preventDefault();

    // Basic client-side validation
    if (!username.trim() || !password.trim()) {
      toast.error("Please enter both username and password");
      return;
    }

    setIsSubmitting(true);

    // Call the login function from useAuth hook
    const result = await login(username, password);

    if (result.success) {
      toast.success("Welcome back!");
    } else {
      toast.error(result.error);
    }

    setIsSubmitting(false);
  };

  return (
    <div className="max-w-md mx-auto mt-16">
      <div className="card">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-gray-900">Welcome Back</h1>
          <p className="text-gray-500 mt-1">
            Sign in to your LBB Scheduler account
          </p>
        </div>

        {/* Login Form */}
        <div className="space-y-5">
          {/* Username */}
          <div>
            <label
              htmlFor="username"
              className="block text-sm font-medium text-gray-700 mb-1"
            >
              Username
            </label>
            <input
              id="username"
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="input-field"
              placeholder="Enter your username"
              autoComplete="username"
              autoFocus
            />
          </div>

          {/* Password with show/hide toggle */}
          <div>
            <label
              htmlFor="password"
              className="block text-sm font-medium text-gray-700 mb-1"
            >
              Password
            </label>
            <div className="relative">
              <input
                id="password"
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="input-field pr-10"
                placeholder="Enter your password"
                autoComplete="current-password"
              />
              {/* Eye icon to toggle password visibility */}
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {/* Forgot password link */}
          <div className="text-right">
            <Link
              to="/forgot-password"
              className="text-sm text-lbb-primary hover:underline"
            >
              Forgot password?
            </Link>
          </div>

          {/* Submit Button */}
          <button
            onClick={handleSubmit}
            disabled={isSubmitting}
            className="btn-primary w-full flex items-center justify-center space-x-2"
          >
            {isSubmitting ? (
              <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
            ) : (
              <>
                <LogIn size={18} />
                <span>Sign In</span>
              </>
            )}
          </button>
        </div>

        {/* Register link */}
        <div className="text-center mt-6 text-sm text-gray-500">
          Don&apos;t have an account?{" "}
          <Link to="/register" className="text-lbb-primary hover:underline">
            Request Access
          </Link>
        </div>
      </div>
    </div>
  );
}