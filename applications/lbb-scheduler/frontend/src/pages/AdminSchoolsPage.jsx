/**
 * Admin Schools Page — School Management
 * =========================================
 * Allows LBB admins to:
 * - Create new schools
 * - View/edit school details
 * - Add/remove principals
 * - Add/remove photo restrictions
 * - Delete schools
 *
 * ConOps 6.7.3: School record management
 */

import React, { useState, useEffect, useCallback } from "react";
import {
  School,
  Plus,
  Edit2,
  Trash2,
  UserPlus,
  CameraOff,
  ChevronDown,
  ChevronUp,
  RefreshCw,
  Search,
  X,
  Save,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

/** Coerce API school rows so list cards never receive non-array relations. */
function normalizeSchoolRecord(s) {
  if (!s || typeof s !== "object") return null;
  return {
    ...s,
    principals: Array.isArray(s.principals) ? s.principals : [],
    photo_restrictions: Array.isArray(s.photo_restrictions) ? s.photo_restrictions : [],
  };
}

class AdminSchoolsErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error, info) {
    console.error("AdminSchoolsPage render error:", error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="card p-8 text-center space-y-4 max-w-lg mx-auto">
          <p className="text-gray-800">
            Something went wrong while showing schools. Try reloading the page.
          </p>
          <button type="button" className="btn-primary" onClick={() => window.location.reload()}>
            Reload
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

// ── Create School Form ──
function CreateSchoolForm({ onCreated }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [form, setForm] = useState({
    school_name: "",
    school_district: "",
    school_address: "",
    poc_name: "",
    poc_phone: "",
    poc_email: "",
    comments: "",
  });

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async () => {
    if (!form.school_name || !form.school_district || !form.poc_name) {
      toast.error("Please fill in school name, district, and POC name");
      return;
    }

    setIsSubmitting(true);
    try {
      await api.post("/schools", form);
      toast.success(`"${form.school_name}" created!`);
      setForm({
        school_name: "",
        school_district: "",
        school_address: "",
        poc_name: "",
        poc_phone: "",
        poc_email: "",
        comments: "",
      });
      setIsOpen(false);
      onCreated();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to create school");
    }
    setIsSubmitting(false);
  };

  return (
    <div className="card">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center justify-between w-full"
      >
        <div className="flex items-center space-x-2">
          <Plus size={18} className="text-blue-600" />
          <span className="font-semibold text-gray-900">Add New School</span>
        </div>
        {isOpen ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>

      {isOpen && (
        <div className="mt-4 space-y-4">
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">School Name *</label>
              <input name="school_name" value={form.school_name} onChange={handleChange} className="input-field" placeholder="Tucson Magnet High" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">District *</label>
              <input name="school_district" value={form.school_district} onChange={handleChange} className="input-field" placeholder="Tucson Unified" />
            </div>
            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-1">Address</label>
              <input name="school_address" value={form.school_address} onChange={handleChange} className="input-field" placeholder="123 Main St, Tucson AZ" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">POC Name *</label>
              <input name="poc_name" value={form.poc_name} onChange={handleChange} className="input-field" placeholder="Jane Doe" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">POC Phone</label>
              <input name="poc_phone" value={form.poc_phone} onChange={handleChange} className="input-field" placeholder="520-555-1234" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">POC Email</label>
              <input name="poc_email" value={form.poc_email} onChange={handleChange} className="input-field" placeholder="jane@school.org" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Comments</label>
              <input name="comments" value={form.comments} onChange={handleChange} className="input-field" placeholder="Optional notes" />
            </div>
          </div>
          <button onClick={handleSubmit} disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? "Creating..." : "Create School"}
          </button>
        </div>
      )}
    </div>
  );
}

// ── School Detail Card ──
function SchoolCard({ school, onRefresh }) {
  const [expanded, setExpanded] = useState(false);
  const [editing, setEditing] = useState(false);
  const [editForm, setEditForm] = useState({});

  // Principal state
  const [newPrincipal, setNewPrincipal] = useState("");
  const [newPrincipalTitle, setNewPrincipalTitle] = useState("");

  // Photo restriction state
  const [newStudent, setNewStudent] = useState("");
  const [newClass, setNewClass] = useState("");

  const handleEdit = () => {
    setEditForm({
      poc_name: school.poc_name || "",
      poc_phone: school.poc_phone || "",
      poc_email: school.poc_email || "",
      school_address: school.school_address || "",
    });
    setEditing(true);
  };

  const handleSave = async () => {
    try {
      await api.patch(`/schools/${school.id}`, editForm);
      toast.success("School updated!");
      setEditing(false);
      onRefresh();
    } catch (error) {
      toast.error("Failed to update school");
    }
  };

  const handleDelete = async () => {
    if (!window.confirm(`Delete "${school.school_name}"? This removes all principals and photo restrictions too.`)) return;
    try {
      await api.delete(`/schools/${school.id}`);
      toast.success(`"${school.school_name}" deleted`);
      onRefresh();
    } catch (error) {
      toast.error("Failed to delete school");
    }
  };

  const handleAddPrincipal = async () => {
    if (!newPrincipal.trim()) return;
    try {
      await api.post(`/schools/${school.id}/principals`, {
        name: newPrincipal,
        title: newPrincipalTitle || undefined,
      });
      toast.success("Principal added!");
      setNewPrincipal("");
      setNewPrincipalTitle("");
      onRefresh();
    } catch (error) {
      toast.error("Failed to add principal");
    }
  };

  const handleRemovePrincipal = async (principalId, name) => {
    try {
      await api.delete(`/schools/${school.id}/principals/${principalId}`);
      toast.success(`${name} removed`);
      onRefresh();
    } catch (error) {
      toast.error("Failed to remove principal");
    }
  };

  const handleAddRestriction = async () => {
    if (!newStudent.trim()) return;
    try {
      await api.post(`/schools/${school.id}/photo-restrictions`, {
        student_name: newStudent,
        class_assignment: newClass || undefined,
      });
      toast.success("Photo restriction added!");
      setNewStudent("");
      setNewClass("");
      onRefresh();
    } catch (error) {
      toast.error("Failed to add restriction");
    }
  };

  const handleRemoveRestriction = async (restrictionId, name) => {
    try {
      await api.delete(`/schools/${school.id}/photo-restrictions/${restrictionId}`);
      toast.success(`${name} removed from no-photo list`);
      onRefresh();
    } catch (error) {
      toast.error("Failed to remove restriction");
    }
  };

  const principals = Array.isArray(school.principals) ? school.principals : [];
  const restrictions = Array.isArray(school.photo_restrictions)
    ? school.photo_restrictions
    : [];

  return (
    <div className="card">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="cursor-pointer flex-1" onClick={() => setExpanded(!expanded)}>
          <div className="flex items-center space-x-2">
            <School size={20} className="text-purple-600" />
            <h3 className="font-semibold text-gray-900">{school.school_name}</h3>
          </div>
          <p className="text-sm text-gray-500 mt-1">
            {school.school_district} &middot; POC: {school.poc_name}
            {principals.length > 0 && ` · ${principals.length} principal(s)`}
            {restrictions.length > 0 && ` · ${restrictions.length} photo restriction(s)`}
          </p>
        </div>
        <div className="flex items-center space-x-2">
          <button onClick={() => setExpanded(!expanded)} className="text-gray-400 hover:text-gray-600">
            {expanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
          </button>
        </div>
      </div>

      {/* Expanded Details */}
      {expanded && (
        <div className="mt-4 border-t pt-4 space-y-6">
          {/* School Info */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <h4 className="font-medium text-gray-800">School Details</h4>
              <div className="flex space-x-2">
                {!editing && (
                  <button onClick={handleEdit} className="flex items-center space-x-1 text-sm text-blue-600 hover:text-blue-700">
                    <Edit2 size={14} />
                    <span>Edit</span>
                  </button>
                )}
                <button onClick={handleDelete} className="flex items-center space-x-1 text-sm text-red-500 hover:text-red-600">
                  <Trash2 size={14} />
                  <span>Delete</span>
                </button>
              </div>
            </div>

            {editing ? (
              <div className="grid md:grid-cols-2 gap-3">
                <input value={editForm.poc_name} onChange={(e) => setEditForm(p => ({...p, poc_name: e.target.value}))} className="input-field" placeholder="POC Name" />
                <input value={editForm.poc_phone} onChange={(e) => setEditForm(p => ({...p, poc_phone: e.target.value}))} className="input-field" placeholder="POC Phone" />
                <input value={editForm.poc_email} onChange={(e) => setEditForm(p => ({...p, poc_email: e.target.value}))} className="input-field" placeholder="POC Email" />
                <input value={editForm.school_address} onChange={(e) => setEditForm(p => ({...p, school_address: e.target.value}))} className="input-field" placeholder="Address" />
                <div className="md:col-span-2 flex space-x-2">
                  <button onClick={handleSave} className="flex items-center space-x-1 px-3 py-1.5 bg-green-600 text-white text-sm rounded-lg hover:bg-green-700">
                    <Save size={14} />
                    <span>Save</span>
                  </button>
                  <button onClick={() => setEditing(false)} className="px-3 py-1.5 text-sm text-gray-600 border rounded-lg hover:bg-gray-50">
                    Cancel
                  </button>
                </div>
              </div>
            ) : (
              <div className="grid md:grid-cols-2 gap-2 text-sm text-gray-600">
                <p><span className="font-medium">Address:</span> {school.school_address || "—"}</p>
                <p><span className="font-medium">POC:</span> {school.poc_name}</p>
                <p><span className="font-medium">Phone:</span> {school.poc_phone || "—"}</p>
                <p><span className="font-medium">Email:</span> {school.poc_email || "—"}</p>
              </div>
            )}
          </div>

          {/* Principals */}
          <div>
            <h4 className="font-medium text-gray-800 flex items-center space-x-2 mb-2">
              <UserPlus size={16} className="text-blue-600" />
              <span>Principals ({principals.length})</span>
            </h4>
            {principals.map((p) => (
              <div key={p.id} className="flex items-center justify-between py-1.5 border-b border-gray-100 last:border-0">
                <p className="text-sm text-gray-700">{p.name} {p.title && `— ${p.title}`}</p>
                <button onClick={() => handleRemovePrincipal(p.id, p.name)} className="text-red-400 hover:text-red-600">
                  <X size={14} />
                </button>
              </div>
            ))}
            <div className="flex space-x-2 mt-2">
              <input value={newPrincipal} onChange={(e) => setNewPrincipal(e.target.value)} className="input-field flex-1" placeholder="Principal name" />
              <input value={newPrincipalTitle} onChange={(e) => setNewPrincipalTitle(e.target.value)} className="input-field w-32" placeholder="Title" />
              <button onClick={handleAddPrincipal} className="px-3 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700">
                Add
              </button>
            </div>
          </div>

          {/* Photo Restrictions */}
          <div>
            <h4 className="font-medium text-gray-800 flex items-center space-x-2 mb-2">
              <CameraOff size={16} className="text-red-500" />
              <span>Photo Restrictions ({restrictions.length})</span>
            </h4>
            {restrictions.map((r) => (
              <div key={r.id} className="flex items-center justify-between py-1.5 border-b border-gray-100 last:border-0">
                <p className="text-sm text-gray-700">{r.student_name} {r.class_assignment && `— ${r.class_assignment}`}</p>
                <button onClick={() => handleRemoveRestriction(r.id, r.student_name)} className="text-red-400 hover:text-red-600">
                  <X size={14} />
                </button>
              </div>
            ))}
            <div className="flex space-x-2 mt-2">
              <input value={newStudent} onChange={(e) => setNewStudent(e.target.value)} className="input-field flex-1" placeholder="Student name" />
              <input value={newClass} onChange={(e) => setNewClass(e.target.value)} className="input-field w-40" placeholder="Class (optional)" />
              <button onClick={handleAddRestriction} className="px-3 py-2 bg-red-600 text-white text-sm rounded-lg hover:bg-red-700">
                Add
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Main Page ──
function AdminSchoolsPageContent() {
  const [schools, setSchools] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterDistrict, setFilterDistrict] = useState("");

  const fetchSchools = useCallback(async () => {
    setLoading(true);
    try {
      let url = "/schools";
      if (filterDistrict) url += `?district=${filterDistrict}`;
      const response = await api.get(url);
      const raw = response.data?.schools ?? response.data;
      const list = Array.isArray(raw) ? raw : [];
      setSchools(list.map(normalizeSchoolRecord).filter(Boolean));
    } catch (error) {
      toast.error("Failed to load schools");
      setSchools([]);
    }
    setLoading(false);
  }, [filterDistrict]);

  useEffect(() => {
    fetchSchools();
  }, [fetchSchools]);

  const schoolList = Array.isArray(schools) ? schools : [];
  const filteredSchools = schoolList.filter((s) => {
    const q = searchTerm.toLowerCase();
    return (
      (s.school_name || "").toLowerCase().includes(q) ||
      (s.school_district || "").toLowerCase().includes(q) ||
      (s.poc_name || "").toLowerCase().includes(q)
    );
  });

  // Get unique districts for filter
  const districts = [...new Set(schoolList.map((s) => s.school_district).filter(Boolean))].sort();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <School size={28} />
            <span>School Management</span>
          </h1>
          <p className="text-gray-500 mt-1">
            {schoolList.length} registered schools
          </p>
        </div>
        <button
          onClick={fetchSchools}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Create Form */}
      <CreateSchoolForm onCreated={fetchSchools} />

      {/* Filters */}
      <div className="card">
        <div className="grid md:grid-cols-2 gap-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
            <input
              type="text"
              placeholder="Search schools..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-field pl-9"
            />
          </div>
          <select
            value={filterDistrict}
            onChange={(e) => setFilterDistrict(e.target.value)}
            className="input-field"
          >
            <option value="">All Districts</option>
            {districts.map((d) => (
              <option key={d} value={d}>{d}</option>
            ))}
          </select>
        </div>
      </div>

      {/* School Cards */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      ) : filteredSchools.length === 0 ? (
        <div className="card text-center py-12 text-gray-500">
          <School className="mx-auto mb-3 text-gray-300" size={48} />
          <p>No schools found. Create one above!</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredSchools.map((school, idx) => (
            <SchoolCard
              key={school.id != null ? String(school.id) : `school-${idx}`}
              school={school}
              onRefresh={fetchSchools}
            />
          ))}
        </div>
      )}
    </div>
  );
}

export default function AdminSchoolsPage() {
  return (
    <AdminSchoolsErrorBoundary>
      <AdminSchoolsPageContent />
    </AdminSchoolsErrorBoundary>
  );
}
