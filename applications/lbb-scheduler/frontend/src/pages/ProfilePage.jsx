/**
 * Profile Page — User Self-Edit Profile
 * ConOps 6.5.5 — Update User Information
 *
 * Users can view and edit their own personal information:
 *   - First name, Last name
 *   - Phone number, Email
 *   - Affiliation
 *   - Password change
 */

import { useState, useEffect } from "react";
import {
  User,
  Save,
  Edit2,
  Lock,
  CheckCircle,
  AlertCircle,
  Shield,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";
import { useAuth } from "../hooks/useAuth";

export default function ProfilePage() {
  const { user, setUser } = useAuth();
  const [editing, setEditing] = useState(false);
  const [changingPassword, setChangingPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [profile, setProfile] = useState(null);

  const [form, setForm] = useState({
    first_name: "",
    last_name: "",
    phone_number: "",
    email: "",
    affiliation: "",
  });

  const [passwordForm, setPasswordForm] = useState({
    current_password: "",
    new_password: "",
    confirm_password: "",
  });

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    try {
      const response = await api.get("/users/me");
      const data = response.data;
      setProfile(data);
      setForm({
        first_name: data.first_name || "",
        last_name: data.last_name || "",
        phone_number: data.phone_number || "",
        email: data.email || "",
        affiliation: data.affiliation || "",
      });
    } catch (error) {
      console.error("Failed to fetch profile:", error);
      toast.error("Failed to load profile");
    }
  };

  const handleUpdate = async () => {
    setLoading(true);
    try {
      const response = await api.patch("/users/me", form);
      setProfile(response.data);
      setEditing(false);
      toast.success("Profile updated successfully");

      // Update local auth state
      if (setUser && user) {
        setUser({ ...user, ...form });
      }
      const stored = localStorage.getItem("user");
      if (stored) {
        const parsed = JSON.parse(stored);
        localStorage.setItem("user", JSON.stringify({ ...parsed, ...form }));
      }
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to update profile");
    }
    setLoading(false);
  };

  const handleChangePassword = async () => {
    if (passwordForm.new_password !== passwordForm.confirm_password) {
      toast.error("New passwords do not match");
      return;
    }
    if (passwordForm.new_password.length < 8) {
      toast.error("Password must be at least 8 characters");
      return;
    }
    setLoading(true);
    try {
      await api.post("/users/me/change-password", {
        current_password: passwordForm.current_password,
        new_password: passwordForm.new_password,
      });
      setChangingPassword(false);
      setPasswordForm({ current_password: "", new_password: "", confirm_password: "" });
      toast.success("Password changed successfully");
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to change password");
    }
    setLoading(false);
  };

  const handleCancel = () => {
    setEditing(false);
    if (profile) {
      setForm({
        first_name: profile.first_name || "",
        last_name: profile.last_name || "",
        phone_number: profile.phone_number || "",
        email: profile.email || "",
        affiliation: profile.affiliation || "",
      });
    }
  };

  const roleLabels = {
    lbb_admin: "LBB Program Administrator",
    school_admin: "School Administrator",
    volunteer: "Professional / Volunteer",
    it_support: "IT Support Staff",
  };

  if (!profile) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <User size={28} />
            <span>My Profile</span>
          </h1>
          <p className="text-gray-500 mt-1">View and update your personal information</p>
        </div>
        {!editing && (
          <button
            onClick={() => setEditing(true)}
            className="flex items-center space-x-2 px-3 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <Edit2 size={16} />
            <span>Edit Profile</span>
          </button>
        )}
      </div>

      {/* Account Info (read-only) */}
      <div className="card">
        <h2 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
          <Shield size={18} />
          <span>Account Information</span>
        </h2>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <p className="text-gray-500">Username</p>
            <p className="font-medium text-gray-900">{profile.username}</p>
          </div>
          <div>
            <p className="text-gray-500">Role</p>
            <p className="font-medium text-gray-900">{roleLabels[profile.role] || profile.role}</p>
          </div>
          <div>
            <p className="text-gray-500">Account Status</p>
            <p className="font-medium flex items-center space-x-1">
              {profile.is_active ? (
                <><CheckCircle size={14} className="text-green-600" /><span className="text-green-700">Active</span></>
              ) : (
                <><AlertCircle size={14} className="text-yellow-600" /><span className="text-yellow-700">Pending Approval</span></>
              )}
            </p>
          </div>
          <div>
            <p className="text-gray-500">Member Since</p>
            <p className="font-medium text-gray-900">
              {profile.created_at ? new Date(profile.created_at).toLocaleDateString() : "N/A"}
            </p>
          </div>
        </div>
      </div>

      {/* Personal Info (editable) */}
      <div className="card">
        <h2 className="font-semibold text-gray-900 mb-4 flex items-center space-x-2">
          <User size={18} />
          <span>Personal Information</span>
        </h2>

        {editing ? (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">First Name</label>
                <input
                  value={form.first_name}
                  onChange={(e) => setForm({ ...form, first_name: e.target.value })}
                  className="input-field"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Last Name</label>
                <input
                  value={form.last_name}
                  onChange={(e) => setForm({ ...form, last_name: e.target.value })}
                  className="input-field"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Phone Number</label>
              <input
                value={form.phone_number}
                onChange={(e) => setForm({ ...form, phone_number: e.target.value })}
                className="input-field"
                placeholder="(520) 555-0100"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email Address</label>
              <input
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Affiliation</label>
              <input
                value={form.affiliation}
                onChange={(e) => setForm({ ...form, affiliation: e.target.value })}
                className="input-field"
                placeholder="School district or organization"
              />
            </div>
            <div className="flex space-x-3 pt-2">
              <button
                onClick={handleUpdate}
                disabled={loading}
                className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white text-sm rounded-lg hover:bg-green-700"
              >
                <Save size={16} />
                <span>{loading ? "Saving..." : "Save Changes"}</span>
              </button>
              <button
                onClick={handleCancel}
                className="px-4 py-2 text-sm text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <p className="text-gray-500">First Name</p>
              <p className="font-medium text-gray-900">{profile.first_name || "Not set"}</p>
            </div>
            <div>
              <p className="text-gray-500">Last Name</p>
              <p className="font-medium text-gray-900">{profile.last_name || "Not set"}</p>
            </div>
            <div>
              <p className="text-gray-500">Phone Number</p>
              <p className="font-medium text-gray-900">{profile.phone_number || "Not set"}</p>
            </div>
            <div>
              <p className="text-gray-500">Email Address</p>
              <p className="font-medium text-gray-900">{profile.email || "Not set"}</p>
            </div>
            <div className="col-span-2">
              <p className="text-gray-500">Affiliation</p>
              <p className="font-medium text-gray-900">{profile.affiliation || "Not set"}</p>
            </div>
          </div>
        )}
      </div>

      {/* Change Password */}
      <div className="card">
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-semibold text-gray-900 flex items-center space-x-2">
            <Lock size={18} />
            <span>Password</span>
          </h2>
          {!changingPassword && (
            <button
              onClick={() => setChangingPassword(true)}
              className="text-sm text-blue-600 hover:text-blue-700"
            >
              Change Password
            </button>
          )}
        </div>

        {changingPassword ? (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Current Password</label>
              <input
                type="password"
                value={passwordForm.current_password}
                onChange={(e) => setPasswordForm({ ...passwordForm, current_password: e.target.value })}
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">New Password</label>
              <input
                type="password"
                value={passwordForm.new_password}
                onChange={(e) => setPasswordForm({ ...passwordForm, new_password: e.target.value })}
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Confirm New Password</label>
              <input
                type="password"
                value={passwordForm.confirm_password}
                onChange={(e) => setPasswordForm({ ...passwordForm, confirm_password: e.target.value })}
                className="input-field"
              />
            </div>
            <div className="flex space-x-3">
              <button
                onClick={handleChangePassword}
                disabled={loading}
                className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700"
              >
                <Lock size={16} />
                <span>{loading ? "Updating..." : "Update Password"}</span>
              </button>
              <button
                onClick={() => { setChangingPassword(false); setPasswordForm({ current_password: "", new_password: "", confirm_password: "" }); }}
                className="px-4 py-2 text-sm text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <p className="text-sm text-gray-500">Last updated: {profile.updated_at ? new Date(profile.updated_at).toLocaleDateString() : "Never"}</p>
        )}
      </div>
    </div>
  );
}
