/**
 * Register Page — Account Request Form
 * ========================================
 * New users fill out this form to request an account.
 * ConOps 6.5.1: Account is NOT immediately active.
 * An admin must approve each new account.
 *
 * Form sections:
 * 1. Account Credentials (username, email, password, confirm)
 * 2. Security Questions (2 questions + answers for recovery)
 * 3. Personal Info (name, phone, role, affiliation)
 */

import { useState } from "react";
import { Link } from "react-router-dom";
import { UserPlus, CheckCircle } from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

// Predefined security questions for the dropdown
const SECURITY_QUESTIONS = [
  "What was the name of your first pet?",
  "What city were you born in?",
  "What is your mother's maiden name?",
  "What was the name of your elementary school?",
  "What is your favorite book?",
  "What street did you grow up on?",
];

export default function RegisterPage() {
  // ---------------------------------------------------------------
  // Form state — one state variable per field
  // ---------------------------------------------------------------
  const [formData, setFormData] = useState({
    username: "",
    email: "",
    password: "",
    confirmPassword: "",
    security_question_1: "",
    security_answer_1: "",
    security_question_2: "",
    security_answer_2: "",
    first_name: "",
    last_name: "",
    phone_number: "",
    role: "volunteer",
    affiliation: "",
  });

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  // ---------------------------------------------------------------
  // Generic change handler for all form fields
  // ---------------------------------------------------------------
  // Instead of writing a separate handler for each field,
  // we use the input's 'name' attribute to update the right
  // field in formData. One handler for all 13 fields.
  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  // ---------------------------------------------------------------
  // Form submission
  // ---------------------------------------------------------------
  const handleSubmit = async () => {
    // Client-side validation
    if (!formData.username || !formData.email || !formData.password) {
      toast.error("Please fill in all required fields");
      return;
    }

    if (formData.password !== formData.confirmPassword) {
      toast.error("Passwords do not match");
      return;
    }

    if (formData.password.length < 8) {
      toast.error("Password must be at least 8 characters");
      return;
    }

    if (!formData.security_question_1 || !formData.security_answer_1) {
      toast.error("Please complete both security questions");
      return;
    }

    if (formData.security_question_1 === formData.security_question_2) {
      toast.error("Please choose two different security questions");
      return;
    }

    setIsSubmitting(true);

    try {
      await api.post("/auth/register", formData);
      setIsSuccess(true);
    } catch (error) {
      const message =
        error.response?.data?.detail || "Registration failed. Please try again.";
      toast.error(message);
    }

    setIsSubmitting(false);
  };

  // ---------------------------------------------------------------
  // Success state — show confirmation message
  // ---------------------------------------------------------------
  if (isSuccess) {
    return (
      <div className="max-w-md mx-auto mt-16">
        <div className="card text-center">
          <CheckCircle className="text-lbb-secondary mx-auto mb-4" size={48} />
          <h2 className="text-xl font-bold text-gray-900 mb-2">
            Account Request Submitted!
          </h2>
          <p className="text-gray-600 mb-6">
            Your account request has been submitted successfully. An LBB
            administrator will review and approve your account. You will be
            notified by email once your account is active.
          </p>
          <Link to="/login" className="btn-primary">
            Return to Login
          </Link>
        </div>
      </div>
    );
  }

  // ---------------------------------------------------------------
  // Registration form
  // ---------------------------------------------------------------
  return (
    <div className="max-w-2xl mx-auto mt-8 mb-16">
      <div className="card">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-gray-900">Request Access</h1>
          <p className="text-gray-500 mt-1">
            Fill out this form to request an LBB Scheduler account.
            Your account will be reviewed by an administrator.
          </p>
        </div>

        <div className="space-y-8">
          {/* ===== SECTION 1: Account Credentials ===== */}
          <div>
            <h3 className="text-lg font-semibold text-gray-800 mb-4 border-b pb-2">
              Account Credentials
            </h3>
            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Username *
                </label>
                <input
                  name="username"
                  value={formData.username}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="Choose a username"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email *
                </label>
                <input
                  name="email"
                  type="email"
                  value={formData.email}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="your.email@example.com"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Password *
                </label>
                <input
                  name="password"
                  type="password"
                  value={formData.password}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="Minimum 8 characters"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Confirm Password *
                </label>
                <input
                  name="confirmPassword"
                  type="password"
                  value={formData.confirmPassword}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="Re-enter your password"
                />
              </div>
            </div>
          </div>

          {/* ===== SECTION 2: Security Questions ===== */}
          <div>
            <h3 className="text-lg font-semibold text-gray-800 mb-4 border-b pb-2">
              Security Questions
            </h3>
            <p className="text-sm text-gray-500 mb-4">
              These will be used to verify your identity if you forget your password.
            </p>
            <div className="space-y-4">
              {/* Security Question 1 */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Security Question 1 *
                </label>
                <select
                  name="security_question_1"
                  value={formData.security_question_1}
                  onChange={handleChange}
                  className="input-field"
                >
                  <option value="">Select a question...</option>
                  {SECURITY_QUESTIONS.map((q) => (
                    <option key={q} value={q}>
                      {q}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Answer 1 *
                </label>
                <input
                  name="security_answer_1"
                  value={formData.security_answer_1}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="Your answer"
                />
              </div>

              {/* Security Question 2 */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Security Question 2 *
                </label>
                <select
                  name="security_question_2"
                  value={formData.security_question_2}
                  onChange={handleChange}
                  className="input-field"
                >
                  <option value="">Select a question...</option>
                  {SECURITY_QUESTIONS.filter(
                    (q) => q !== formData.security_question_1
                  ).map((q) => (
                    <option key={q} value={q}>
                      {q}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Answer 2 *
                </label>
                <input
                  name="security_answer_2"
                  value={formData.security_answer_2}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="Your answer"
                />
              </div>
            </div>
          </div>

          {/* ===== SECTION 3: Personal Information ===== */}
          <div>
            <h3 className="text-lg font-semibold text-gray-800 mb-4 border-b pb-2">
              Personal Information
            </h3>
            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  First Name *
                </label>
                <input
                  name="first_name"
                  value={formData.first_name}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="First name"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Last Name *
                </label>
                <input
                  name="last_name"
                  value={formData.last_name}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="Last name"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Phone Number *
                </label>
                <input
                  name="phone_number"
                  value={formData.phone_number}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="+1-520-555-0123"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Role *
                </label>
                <select
                  name="role"
                  value={formData.role}
                  onChange={handleChange}
                  className="input-field"
                >
                  <option value="volunteer">Professional / Volunteer</option>
                  <option value="school_admin">School Administrator</option>
                </select>
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Affiliation
                </label>
                <input
                  name="affiliation"
                  value={formData.affiliation}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="School name or professional organization (optional)"
                />
              </div>
            </div>
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
                <UserPlus size={18} />
                <span>Submit Request</span>
              </>
            )}
          </button>
        </div>

        {/* Login link */}
        <div className="text-center mt-6 text-sm text-gray-500">
          Already have an account?{" "}
          <Link to="/login" className="text-lbb-primary hover:underline">
            Sign In
          </Link>
        </div>
      </div>
    </div>
  );
}
