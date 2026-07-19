/**
 * Admin Donations Page — Donation Tracking
 * ==========================================
 * Allows LBB admins to:
 * - Record cash and in-kind donations
 * - View donation list with filters
 * - Mark thank-you letters as sent
 * - View donation summary report
 *
 * ConOps 6.8: Donation management
 */

import { useState, useEffect, useCallback } from "react";
import {
  DollarSign,
  Plus,
  ChevronDown,
  ChevronUp,
  Mail,
  MailCheck,
  RefreshCw,
  Search,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

// ── Create Donation Form ──
function CreateDonationForm({ onCreated }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [form, setForm] = useState({
    donor_name: "",
    donor_email: "",
    donor_phone: "",
    organization: "",
    amount: "",
    donation_date: new Date().toISOString().split("T")[0],
    donation_kind: "cash",
    description: "",
  });

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async () => {
    if (!form.donor_name || !form.amount || !form.donation_date) {
      toast.error("Please fill in donor name, amount, and date");
      return;
    }

    setIsSubmitting(true);
    try {
      await api.post("/donations", {
        ...form,
        amount: parseFloat(form.amount),
      });
      toast.success("Donation recorded!");
      setForm({
        donor_name: "",
        donor_email: "",
        donor_phone: "",
        organization: "",
        amount: "",
        donation_date: new Date().toISOString().split("T")[0],
        donation_kind: "cash",
        description: "",
      });
      setIsOpen(false);
      onCreated();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to record donation");
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
          <Plus size={18} className="text-green-600" />
          <span className="font-semibold text-gray-900">Record New Donation</span>
        </div>
        {isOpen ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>

      {isOpen && (
        <div className="mt-4 space-y-4">
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Donor Name *</label>
              <input name="donor_name" value={form.donor_name} onChange={handleChange} className="input-field" placeholder="John Smith" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Donor Email</label>
              <input name="donor_email" type="email" value={form.donor_email} onChange={handleChange} className="input-field" placeholder="john@example.com" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
              <input name="donor_phone" value={form.donor_phone} onChange={handleChange} className="input-field" placeholder="520-555-1234" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Organization</label>
              <input name="organization" value={form.organization} onChange={handleChange} className="input-field" placeholder="Smith Foundation" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Amount ($) *</label>
              <input name="amount" type="number" step="0.01" min="0" value={form.amount} onChange={handleChange} className="input-field" placeholder="500.00" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Date *</label>
              <input name="donation_date" type="date" value={form.donation_date} onChange={handleChange} className="input-field" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Type *</label>
              <select name="donation_kind" value={form.donation_kind} onChange={handleChange} className="input-field">
                <option value="cash">Cash</option>
                <option value="in_kind">In-Kind</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <input name="description" value={form.description} onChange={handleChange} className="input-field" placeholder="Annual contribution" />
            </div>
          </div>
          <button onClick={handleSubmit} disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? "Recording..." : "Record Donation"}
          </button>
        </div>
      )}
    </div>
  );
}

// ── Main Page ──
export default function AdminDonationsPage() {
  const [donations, setDonations] = useState([]);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [filterKind, setFilterKind] = useState("");
  const [filterLetter, setFilterLetter] = useState("");
  const [searchTerm, setSearchTerm] = useState("");

  const fetchDonations = useCallback(async () => {
    setLoading(true);
    try {
      let url = "/donations";
      const params = [];
      if (filterKind) params.push(`donation_kind=${filterKind}`);
      if (filterLetter) params.push(`letter_sent=${filterLetter}`);
      if (params.length > 0) url += "?" + params.join("&");

      const response = await api.get(url);
      setDonations(response.data.donations || response.data);
    } catch (error) {
      console.error("Failed to fetch donations:", error);
    }
    setLoading(false);
  }, [filterKind, filterLetter]);

  const fetchSummary = useCallback(async () => {
    try {
      const response = await api.get("/donations/summary");
      setSummary(response.data);
    } catch (error) {
      console.error("Failed to fetch summary:", error);
    }
  }, []);

  useEffect(() => {
    fetchDonations();
    fetchSummary();
  }, [fetchDonations, fetchSummary]);

  const handleRefresh = () => {
    fetchDonations();
    fetchSummary();
  };

  // Mark letter as sent
  const handleMarkLetterSent = async (donationId, donorName) => {
    try {
      await api.patch(`/donations/${donationId}`, { letter_sent: true });
      toast.success(`Thank-you letter marked as sent for ${donorName}`);
      handleRefresh();
    } catch (error) {
      toast.error("Failed to update letter status");
    }
  };

  // Delete donation
  const handleDelete = async (donationId, donorName) => {
    if (!window.confirm(`Delete donation from ${donorName}?`)) return;
    try {
      await api.delete(`/donations/${donationId}`);
      toast.success("Donation deleted");
      handleRefresh();
    } catch (error) {
      toast.error("Failed to delete donation");
    }
  };

  const filteredDonations = donations.filter(
    (d) =>
      (d.donor_name || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
      (d.organization || "").toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <DollarSign size={28} />
            <span>Donation Tracking</span>
          </h1>
          <p className="text-gray-500 mt-1">Record and manage donations</p>
        </div>
        <button
          onClick={handleRefresh}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Summary Cards */}
      {summary && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="card text-center">
            <p className="text-2xl font-bold text-blue-600">{summary.total_donations}</p>
            <p className="text-sm text-gray-500">Total Donations</p>
          </div>
          <div className="card text-center">
            <p className="text-2xl font-bold text-green-600">
              ${parseFloat(summary.total_cash || 0).toLocaleString("en-US", { minimumFractionDigits: 2 })}
            </p>
            <p className="text-sm text-gray-500">Cash Total</p>
          </div>
          <div className="card text-center">
            <p className="text-2xl font-bold text-purple-600">
              ${parseFloat(summary.total_in_kind || 0).toLocaleString("en-US", { minimumFractionDigits: 2 })}
            </p>
            <p className="text-sm text-gray-500">In-Kind Total</p>
          </div>
          <div className="card text-center">
            <p className="text-2xl font-bold text-amber-600">{summary.letters_pending || 0}</p>
            <p className="text-sm text-gray-500">Letters Pending</p>
          </div>
        </div>
      )}

      {/* Create Form */}
      <CreateDonationForm onCreated={handleRefresh} />

      {/* Filters */}
      <div className="card">
        <div className="grid md:grid-cols-3 gap-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
            <input
              type="text"
              placeholder="Search by donor or organization..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-field pl-9"
            />
          </div>
          <select value={filterKind} onChange={(e) => setFilterKind(e.target.value)} className="input-field">
            <option value="">All Types</option>
            <option value="cash">Cash</option>
            <option value="in_kind">In-Kind</option>
          </select>
          <select value={filterLetter} onChange={(e) => setFilterLetter(e.target.value)} className="input-field">
            <option value="">All Letter Status</option>
            <option value="true">Letter Sent</option>
            <option value="false">Letter Pending</option>
          </select>
        </div>
      </div>

      {/* Donations Table */}
      <div className="card overflow-hidden p-0">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        ) : filteredDonations.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <DollarSign className="mx-auto mb-3 text-gray-300" size={48} />
            <p>No donations recorded yet</p>
          </div>
        ) : (
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Donor</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Amount</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Type</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Date</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Letter</th>
                <th className="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {filteredDonations.map((d) => (
                <tr key={d.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3">
                    <p className="font-medium text-gray-900">{d.donor_name}</p>
                    <p className="text-xs text-gray-500">{d.organization || d.donor_email || "—"}</p>
                  </td>
                  <td className="px-4 py-3 font-medium text-gray-900">
                    ${parseFloat(d.amount).toLocaleString("en-US", { minimumFractionDigits: 2 })}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                      d.donation_kind === "cash" ? "bg-green-100 text-green-700" : "bg-purple-100 text-purple-700"
                    }`}>
                      {d.donation_kind === "cash" ? "Cash" : "In-Kind"}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {new Date(d.donation_date).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3">
                    {d.letter_sent ? (
                      <span className="flex items-center space-x-1 text-green-600">
                        <MailCheck size={14} />
                        <span className="text-xs">Sent</span>
                      </span>
                    ) : (
                      <button
                        onClick={() => handleMarkLetterSent(d.id, d.donor_name)}
                        className="flex items-center space-x-1 text-amber-600 hover:text-amber-700"
                      >
                        <Mail size={14} />
                        <span className="text-xs">Mark Sent</span>
                      </button>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => handleDelete(d.id, d.donor_name)}
                      className="text-red-500 hover:text-red-600 text-sm"
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
    </div>
  );
}
