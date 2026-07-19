/**
 * Forgot Password Page — Security Question Verification + Reset
 * ================================================================
 * Two-step flow:
 *   Step 1: Enter username + answer security questions
 *   Step 2: Enter new password using reset token
 *
 * ConOps 6.5.3: Password recovery via security questions
 */

import { useState } from "react";
import { Link } from "react-router-dom";
import { KeyRound, CheckCircle, ArrowLeft, ShieldCheck } from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

export default function ForgotPasswordPage() {
  // Which step are we on?
  const [step, setStep] = useState(1); // 1 = verify, 2 = reset, 3 = success

  // Step 1: Verify identity
  const [username, setUsername] = useState("");
  const [answer1, setAnswer1] = useState("");
  const [answer2, setAnswer2] = useState("");
  const [isVerifying, setIsVerifying] = useState(false);

  // Step 2: Reset password
  const [resetToken, setResetToken] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isResetting, setIsResetting] = useState(false);

  // ── Step 1: Verify security questions ──
  const handleVerify = async () => {
    if (!username.trim() || !answer1.trim() || !answer2.trim()) {
      toast.error("Please fill in all fields");
      return;
    }

    setIsVerifying(true);

    try {
      const response = await api.post("/auth/verify", {
        username,
        security_answer_1: answer1,
        security_answer_2: answer2,
      });

      setResetToken(response.data.reset_token);
      setStep(2);
      toast.success("Identity verified! Set your new password.");
    } catch (error) {
      const message =
        error.response?.data?.detail || "Verification failed. Check your answers.";
      toast.error(message);
    }

    setIsVerifying(false);
  };

  // ── Step 2: Reset password ──
  const handleReset = async () => {
    if (!newPassword.trim() || !confirmPassword.trim()) {
      toast.error("Please enter your new password");
      return;
    }

    if (newPassword !== confirmPassword) {
      toast.error("Passwords do not match");
      return;
    }

    if (newPassword.length < 8) {
      toast.error("Password must be at least 8 characters");
      return;
    }

    setIsResetting(true);

    try {
      await api.post("/auth/reset", {
        reset_token: resetToken,
        new_password: newPassword,
      });

      setStep(3);
    } catch (error) {
      const message =
        error.response?.data?.detail || "Password reset failed. Token may have expired.";
      toast.error(message);
    }

    setIsResetting(false);
  };

  // ── Step 3: Success ──
  if (step === 3) {
    return (
      <div className="max-w-md mx-auto mt-16">
        <div className="card text-center">
          <CheckCircle className="text-green-500 mx-auto mb-4" size={48} />
          <h2 className="text-xl font-bold text-gray-900 mb-2">
            Password Reset Successful!
          </h2>
          <p className="text-gray-600 mb-6">
            Your password has been changed. You can now log in with your new password.
          </p>
          <Link to="/login" className="btn-primary">
            Go to Login
          </Link>
        </div>
      </div>
    );
  }

  // ── Step 2: New password form ──
  if (step === 2) {
    return (
      <div className="max-w-md mx-auto mt-16">
        <div className="card">
          <div className="text-center mb-8">
            <KeyRound className="text-blue-600 mx-auto mb-3" size={40} />
            <h1 className="text-2xl font-bold text-gray-900">Set New Password</h1>
            <p className="text-gray-500 mt-1">
              Choose a strong password for your account
            </p>
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                New Password *
              </label>
              <input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="input-field"
                placeholder="Minimum 8 characters"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Confirm New Password *
              </label>
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="input-field"
                placeholder="Re-enter new password"
              />
            </div>

            <button
              onClick={handleReset}
              disabled={isResetting}
              className="btn-primary w-full flex items-center justify-center space-x-2"
            >
              {isResetting ? (
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
              ) : (
                <>
                  <KeyRound size={18} />
                  <span>Reset Password</span>
                </>
              )}
            </button>
          </div>

          <p className="text-xs text-gray-400 text-center mt-4">
            Reset token expires in 5 minutes
          </p>
        </div>
      </div>
    );
  }

  // ── Step 1: Verify identity form ──
  return (
    <div className="max-w-md mx-auto mt-16">
      <div className="card">
        <div className="text-center mb-8">
          <ShieldCheck className="text-blue-600 mx-auto mb-3" size={40} />
          <h1 className="text-2xl font-bold text-gray-900">Forgot Password</h1>
          <p className="text-gray-500 mt-1">
            Verify your identity using your security questions
          </p>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Username *
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="input-field"
              placeholder="Enter your username"
              autoFocus
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Security Answer 1 *
            </label>
            <input
              type="text"
              value={answer1}
              onChange={(e) => setAnswer1(e.target.value)}
              className="input-field"
              placeholder="Answer to your first security question"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Security Answer 2 *
            </label>
            <input
              type="text"
              value={answer2}
              onChange={(e) => setAnswer2(e.target.value)}
              className="input-field"
              placeholder="Answer to your second security question"
            />
          </div>

          <button
            onClick={handleVerify}
            disabled={isVerifying}
            className="btn-primary w-full flex items-center justify-center space-x-2"
          >
            {isVerifying ? (
              <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
            ) : (
              <>
                <ShieldCheck size={18} />
                <span>Verify Identity</span>
              </>
            )}
          </button>
        </div>

        <div className="text-center mt-6 text-sm text-gray-500">
          <Link to="/login" className="text-lbb-primary hover:underline flex items-center justify-center space-x-1">
            <ArrowLeft size={14} />
            <span>Back to Login</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
