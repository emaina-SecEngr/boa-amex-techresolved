/**
 * Volunteer Profile — Create / view / update extended profile (MVP2)
 * POST /volunteers/profile · GET /volunteers/profile · PATCH /volunteers/profile
 */

import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import toast from "react-hot-toast";
import { User, Save, Loader2, ArrowLeft } from "lucide-react";
import api from "../services/api";
import { useAuth } from "../hooks/useAuth";

const emptyForm = {
  organization: "",
  bio: "",
  special_requirements: "",
  background_check_status: "",
  is_available: true,
};

export default function VolunteerProfilePage() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [exists, setExists] = useState(false);
  const [form, setForm] = useState(emptyForm);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        const { data } = await api.get("/volunteers/profile");
        if (cancelled) return;
        setExists(true);
        setForm({
          organization: data.organization ?? "",
          bio: data.bio ?? "",
          special_requirements: data.special_requirements ?? "",
          background_check_status: data.background_check_status ?? "",
          is_available: Boolean(data.is_available),
        });
      } catch (err) {
        if (err.response?.status === 404) {
          setExists(false);
          setForm(emptyForm);
        } else {
          toast.error(err.response?.data?.detail || "Could not load profile");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => {
      cancelled = true;
    };
  }, []);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setForm((prev) => ({
      ...prev,
      [name]: type === "checkbox" ? checked : value,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload = {
        organization: form.organization || null,
        bio: form.bio || null,
        special_requirements: form.special_requirements || null,
        background_check_status: form.background_check_status || null,
        is_available: form.is_available,
      };
      if (!exists) {
        await api.post("/volunteers/profile", payload);
        setExists(true);
        toast.success("Profile created");
      } else {
        await api.patch("/volunteers/profile", payload);
        toast.success("Profile updated");
      }
    } catch (err) {
      const msg = err.response?.data?.detail;
      toast.error(typeof msg === "string" ? msg : "Save failed");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-16">
        <Loader2 className="animate-spin text-lbb-primary" size={40} />
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div>
        <Link
          to="/dashboard"
          className="inline-flex items-center text-sm text-gray-500 hover:text-gray-800 mb-4"
        >
          <ArrowLeft size={16} className="mr-1" />
          Back to dashboard
        </Link>
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <User className="text-lbb-primary" size={28} />
          My volunteer profile
        </h1>
        <p className="text-gray-500 mt-1">
          {user?.first_name} {user?.last_name} · {user?.email}
        </p>
      </div>

      <form onSubmit={handleSubmit} className="card space-y-5">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Organization / affiliation
          </label>
          <input
            name="organization"
            value={form.organization}
            onChange={handleChange}
            className="input-field"
            placeholder="Company or group you represent"
            maxLength={255}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Bio</label>
          <textarea
            name="bio"
            value={form.bio}
            onChange={handleChange}
            className="input-field min-h-[120px]"
            placeholder="Experience, topics you teach, and what you bring to the classroom"
            maxLength={2000}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Special requirements
          </label>
          <textarea
            name="special_requirements"
            value={form.special_requirements}
            onChange={handleChange}
            className="input-field min-h-[80px]"
            placeholder="e.g. outdoor space, projector, classroom size"
            maxLength={500}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Background check status
          </label>
          <select
            name="background_check_status"
            value={form.background_check_status}
            onChange={handleChange}
            className="input-field"
          >
            <option value="">Not specified</option>
            <option value="pending">Pending</option>
            <option value="cleared">Cleared</option>
            <option value="expired">Expired</option>
            <option value="not_applicable">Not applicable</option>
          </select>
          <p className="text-xs text-gray-500 mt-1">
            Used by program staff for scheduling decisions (no automated matching).
          </p>
        </div>

        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            name="is_available"
            checked={form.is_available}
            onChange={handleChange}
            className="rounded border-gray-300"
          />
          <span className="text-sm text-gray-800">
            I am available for scheduling this school year
          </span>
        </label>

        <button
          type="submit"
          disabled={saving}
          className="btn-primary inline-flex items-center gap-2"
        >
          {saving ? (
            <Loader2 className="animate-spin" size={18} />
          ) : (
            <Save size={18} />
          )}
          {exists ? "Save changes" : "Create profile"}
        </button>
      </form>
    </div>
  );
}
