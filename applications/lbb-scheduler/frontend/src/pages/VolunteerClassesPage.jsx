/**
 * Volunteer Classes Page — My Life Skills Classes
 */

import { useState, useEffect } from "react";
import {
  BookOpen,
  RefreshCw,
  Edit2,
  Save,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";
import { useAuth } from "../hooks/useAuth";

export default function VolunteerClassesPage() {
  const { user } = useAuth();
  const [classes, setClasses] = useState([]);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [editingProfile, setEditingProfile] = useState(false);
  const [profileForm, setProfileForm] = useState({
    bio: "",
    organization: "",
    is_available: true,
  });

  const fetchProfile = async () => {
    try {
      const response = await api.get("/volunteers/my-profile");
      setProfile(response.data);
      setProfileForm({
        bio: response.data.bio || "",
        organization: response.data.organization || "",
        is_available: response.data.is_available !== false,
      });
    } catch (error) {
      // Profile does not exist yet — that is OK
      setProfile(null);
    }
  };

  const fetchClasses = async () => {
    setLoading(true);
    try {
      const response = await api.get("/volunteers/my-classes");
      setClasses(response.data.classes || response.data || []);
    } catch (error) {
      console.error("Failed to fetch classes:", error);
      setClasses([]);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchProfile();
    fetchClasses();
  }, []);

  const handleCreateProfile = async () => {
    try {
      await api.post("/volunteers/profile", profileForm);
      toast.success("Volunteer profile created!");
      fetchProfile();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to create profile");
    }
  };

  const handleUpdateProfile = async () => {
    try {
      await api.patch("/volunteers/my-profile", profileForm);
      toast.success("Profile updated!");
      setEditingProfile(false);
      fetchProfile();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to update profile");
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <BookOpen size={28} />
            <span>My Classes</span>
          </h1>
          <p className="text-gray-500 mt-1">Life skills classes you lead</p>
        </div>
        <button
          onClick={() => { fetchProfile(); fetchClasses(); }}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Volunteer Profile */}
      <div className="card">
        <h2 className="font-semibold text-gray-900 mb-3">My Volunteer Profile</h2>
        {profile && !editingProfile ? (
          <div>
            <div className="grid md:grid-cols-2 gap-3 text-sm text-gray-600">
              <p><span className="font-medium">Name:</span> {user.first_name} {user.last_name}</p>
              <p><span className="font-medium">Organization:</span> {profile.organization || "—"}</p>
              <p><span className="font-medium">Status:</span> {profile.is_available ? "Available" : "Unavailable"}</p>
              <p><span className="font-medium">Bio:</span> {profile.bio || "—"}</p>
            </div>
            <button
              onClick={() => setEditingProfile(true)}
              className="flex items-center space-x-1 mt-3 text-sm text-blue-600 hover:text-blue-700"
            >
              <Edit2 size={14} />
              <span>Edit Profile</span>
            </button>
          </div>
        ) : (
          <div className="space-y-3">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Organization</label>
              <input
                value={profileForm.organization}
                onChange={(e) => setProfileForm((p) => ({ ...p, organization: e.target.value }))}
                className="input-field"
                placeholder="Your company or organization"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Bio</label>
              <textarea
                value={profileForm.bio}
                onChange={(e) => setProfileForm((p) => ({ ...p, bio: e.target.value }))}
                className="input-field"
                rows={3}
                placeholder="Tell us about your expertise and what you would like to teach..."
              />
            </div>
            <div className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={profileForm.is_available}
                onChange={(e) => setProfileForm((p) => ({ ...p, is_available: e.target.checked }))}
                className="rounded"
              />
              <label className="text-sm text-gray-700">I am available to volunteer</label>
            </div>
            <div className="flex space-x-2">
              {profile ? (
                <>
                  <button onClick={handleUpdateProfile} className="flex items-center space-x-1 px-3 py-1.5 bg-green-600 text-white text-sm rounded-lg hover:bg-green-700">
                    <Save size={14} />
                    <span>Save Changes</span>
                  </button>
                  <button onClick={() => setEditingProfile(false)} className="px-3 py-1.5 text-sm text-gray-600 border rounded-lg hover:bg-gray-50">
                    Cancel
                  </button>
                </>
              ) : (
                <button onClick={handleCreateProfile} className="btn-primary">
                  Create My Profile
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* My Classes */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Classes I Lead</h2>
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        ) : classes.length === 0 ? (
          <div className="card text-center py-8 text-gray-500">
            <BookOpen className="mx-auto mb-3 text-gray-300" size={48} />
            <p>You have not been assigned any classes yet.</p>
            <p className="text-xs mt-2">Contact an LBB admin to be assigned as a class leader.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {classes.map((cls) => (
              <div key={cls.id} className="card">
                <div className="flex items-start justify-between">
                  <div>
                    <h3 className="font-semibold text-gray-900">{cls.class_name}</h3>
                    <p className="text-sm text-gray-600 mt-1">{cls.description || "No description"}</p>
                    <div className="grid grid-cols-2 gap-2 mt-2 text-xs text-gray-500">
                      <p>Max students: {cls.max_students || "—"}</p>
                      <p>Take-home items: {cls.take_home_items || "—"}</p>
                      <p>Equipment (you bring): {cls.equipment_by_professional || "—"}</p>
                      <p>Equipment (LBB provides): {cls.equipment_by_lbb || "—"}</p>
                    </div>
                  </div>
                  <span className="px-2 py-1 bg-blue-100 text-blue-700 rounded-full text-xs font-medium">
                    Lead
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
