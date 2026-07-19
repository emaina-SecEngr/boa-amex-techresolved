/**
 * Admin Volunteers Page — Volunteer & Life Skills Class Management
 * ==================================================================
 * Allows LBB admins to:
 * - View volunteer profiles and availability
 * - Create/edit/delete life skills classes
 * - Assign lead volunteers to classes
 *
 * ConOps 6.7.5: Volunteer and class management
 */

import { useState, useEffect, useCallback } from "react";
import {
  Users,
  BookOpen,
  Plus,
  ChevronDown,
  ChevronUp,
  RefreshCw,
  Search,
  CheckCircle,
  XCircle,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

// ── Tabs ──
function VolunteerTabs({ activeTab, onTabChange }) {
  const tabs = [
    { id: "volunteers", label: "Volunteer Profiles", icon: Users },
    { id: "classes", label: "Life Skills Classes", icon: BookOpen },
  ];

  return (
    <div className="flex space-x-1 bg-gray-100 rounded-lg p-1">
      {tabs.map((tab) => {
        const Icon = tab.icon;
        return (
          <button
            key={tab.id}
            onClick={() => onTabChange(tab.id)}
            className={`flex items-center space-x-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors flex-1 justify-center ${activeTab === tab.id
              ? "bg-white shadow text-gray-900"
              : "text-gray-500 hover:text-gray-700"
              }`}
          >
            <Icon size={16} />
            <span>{tab.label}</span>
          </button>
        );
      })}
    </div>
  );
}

// ── Create Life Skills Class Form ──
function CreateClassForm({ volunteers, onCreated }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [form, setForm] = useState({
    class_name: "",
    lead_volunteer_id: "",
    description: "",
    equipment_by_professional: "",
    equipment_by_lbb: "",
    max_students: "",
    take_home_items: "",
    logistics: "",
  });

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async () => {
    if (!form.class_name || !form.lead_volunteer_id) {
      toast.error("Please enter class name and select a lead volunteer");
      return;
    }

    setIsSubmitting(true);
    try {
      await api.post("/volunteers/classes", {
        ...form,
        max_students: form.max_students ? parseInt(form.max_students) : undefined,
      });
      toast.success(`"${form.class_name}" created!`);
      setForm({
        class_name: "", lead_volunteer_id: "", description: "",
        equipment_by_professional: "", equipment_by_lbb: "",
        max_students: "", take_home_items: "", logistics: "",
      });
      setIsOpen(false);
      onCreated();
    } catch (error) {
      const detail = error.response?.data?.detail;

      if (Array.isArray(detail)) {
        const message = detail.map(err => err.msg).join(", ");
        toast.error(message);
      } else {
        toast.error(detail || "Failed to create class");
      }
    }
    setIsSubmitting(false);
  };

  return (
    <div className="card">
      <button onClick={() => setIsOpen(!isOpen)} className="flex items-center justify-between w-full">
        <div className="flex items-center space-x-2">
          <Plus size={18} className="text-green-600" />
          <span className="font-semibold text-gray-900">Create Life Skills Class</span>
        </div>
        {isOpen ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>

      {isOpen && (
        <div className="mt-4 space-y-4">
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Class Name *</label>
              <input name="class_name" value={form.class_name} onChange={handleChange} className="input-field" placeholder="Financial Literacy 101" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Lead Volunteer *</label>
              <select name="lead_volunteer_id" value={form.lead_volunteer_id} onChange={handleChange} className="input-field">
                <option value="">Select volunteer...</option>
                {volunteers.map((v) => (
                  <option key={v.id} value={v.user_id || v.id}>
                    {v.first_name ? `${v.first_name} ${v.last_name}` : v.organization || v.id}
                  </option>
                ))}
              </select>
            </div>
            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea name="description" value={form.description} onChange={handleChange} className="input-field" rows={2} placeholder="Teach students about budgeting and saving" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Equipment (by professional)</label>
              <input name="equipment_by_professional" value={form.equipment_by_professional} onChange={handleChange} className="input-field" placeholder="Laptop, handouts" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Equipment (by LBB)</label>
              <input name="equipment_by_lbb" value={form.equipment_by_lbb} onChange={handleChange} className="input-field" placeholder="Projector, screen" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Max Students</label>
              <input name="max_students" type="number" min="1" value={form.max_students} onChange={handleChange} className="input-field" placeholder="25" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Take-Home Items</label>
              <input name="take_home_items" value={form.take_home_items} onChange={handleChange} className="input-field" placeholder="Budget worksheet" />
            </div>
            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-1">Logistics</label>
              <input name="logistics" value={form.logistics} onChange={handleChange} className="input-field" placeholder="Need classroom with tables" />
            </div>
          </div>
          <button onClick={handleSubmit} disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? "Creating..." : "Create Class"}
          </button>
        </div>
      )}
    </div>
  );
}

// ── Main Page ──
export default function AdminVolunteersPage() {
  const [activeTab, setActiveTab] = useState("volunteers");
  const [volunteers, setVolunteers] = useState([]);
  const [classes, setClasses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  const fetchVolunteers = useCallback(async () => {
    try {
      const response = await api.get("/volunteers/available");
      setVolunteers(response.data.profiles || response.data);
    } catch (error) {
      console.error("Failed to fetch volunteers:", error);
      setVolunteers([]);
    }
  }, []);

  const fetchClasses = useCallback(async () => {
    try {
      const response = await api.get("/volunteers/classes");
      setClasses(response.data.classes || response.data);
    } catch (error) {
      console.error("Failed to fetch classes:", error);
      setClasses([]);
    }
  }, []);

  const fetchAll = useCallback(async () => {
    setLoading(true);
    await Promise.all([fetchVolunteers(), fetchClasses()]);
    setLoading(false);
  }, [fetchVolunteers, fetchClasses]);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  const handleDeleteClass = async (classId, className) => {
    if (!window.confirm(`Delete "${className}"?`)) return;
    try {
      await api.delete(`/volunteers/classes/${classId}`);
      toast.success(`"${className}" deleted`);
      fetchClasses();
    } catch (error) {
      toast.error("Failed to delete class");
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <Users size={28} />
            <span>Volunteer Management</span>
          </h1>
          <p className="text-gray-500 mt-1">
            {volunteers.length} available volunteers &middot; {classes.length} life skills classes
          </p>
        </div>
        <button
          onClick={fetchAll}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Tabs */}
      <VolunteerTabs activeTab={activeTab} onTabChange={setActiveTab} />

      {/* ── Volunteers Tab ── */}
      {activeTab === "volunteers" && (
        <>
          {/* Search */}
          <div className="card">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
              <input
                type="text"
                placeholder="Search volunteers..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="input-field pl-9"
              />
            </div>
          </div>

          {/* Volunteer List */}
          <div className="card overflow-hidden p-0">
            {loading ? (
              <div className="flex items-center justify-center py-12">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              </div>
            ) : volunteers.length === 0 ? (
              <div className="text-center py-12 text-gray-500">
                <Users className="mx-auto mb-3 text-gray-300" size={48} />
                <p>No volunteer profiles yet</p>
              </div>
            ) : (
              <table className="w-full">
                <thead className="bg-gray-50 border-b">
                  <tr>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Volunteer</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Organization</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Bio</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Available</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {volunteers
                    .filter((v) =>
                      JSON.stringify(v).toLowerCase().includes(searchTerm.toLowerCase())
                    )
                    .map((v) => (
                      <tr key={v.id} className="hover:bg-gray-50">
                        <td className="px-4 py-3">
                          <p className="font-medium text-gray-900">
                            {v.first_name ? `${v.first_name} ${v.last_name}` : `Profile ${v.id.slice(0, 8)}`}
                          </p>
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-600">{v.organization || "—"}</td>
                        <td className="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">{v.bio || "—"}</td>
                        <td className="px-4 py-3">
                          {v.is_available ? (
                            <span className="flex items-center space-x-1 text-green-600">
                              <CheckCircle size={14} />
                              <span className="text-xs">Available</span>
                            </span>
                          ) : (
                            <span className="flex items-center space-x-1 text-gray-400">
                              <XCircle size={14} />
                              <span className="text-xs">Unavailable</span>
                            </span>
                          )}
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}

      {/* ── Classes Tab ── */}
      {activeTab === "classes" && (
        <>
          <CreateClassForm volunteers={volunteers} onCreated={fetchClasses} />

          <div className="card overflow-hidden p-0">
            {loading ? (
              <div className="flex items-center justify-center py-12">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              </div>
            ) : classes.length === 0 ? (
              <div className="text-center py-12 text-gray-500">
                <BookOpen className="mx-auto mb-3 text-gray-300" size={48} />
                <p>No life skills classes yet. Create one above!</p>
              </div>
            ) : (
              <table className="w-full">
                <thead className="bg-gray-50 border-b">
                  <tr>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Class Name</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Description</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Max Students</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Equipment</th>
                    <th className="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {classes.map((c) => (
                    <tr key={c.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <p className="font-medium text-gray-900">{c.class_name}</p>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">
                        {c.description || "—"}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600">
                        {c.max_students || "—"}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600">
                        {c.equipment_by_professional || c.equipment_by_lbb || "—"}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <button
                          onClick={() => handleDeleteClass(c.id, c.class_name)}
                          className="text-red-500 hover:text-red-600 text-sm font-medium"
                        >
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}
    </div>
  );
}
