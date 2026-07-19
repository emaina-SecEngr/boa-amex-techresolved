/**
 * Admin Events Page — Event & Academic Year Management
 * ======================================================
 * Allows LBB admins to:
 * - Create/view academic years
 * - Create event dates within academic years
 * - View event status and registrations
 * - Cancel events
 *
 * ConOps 6.7: Event scheduling and management
 */

import { useState, useEffect, useCallback } from "react";
import {
  Calendar,
  Plus,
  ChevronDown,
  ChevronUp,
  CheckCircle,
  XCircle,
  School,
  RefreshCw,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

// ── Create Academic Year Modal ──
function CreateYearForm({ onCreated }) {
  const [name, setName] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isOpen, setIsOpen] = useState(false);

  const handleSubmit = async () => {
    if (!name || !startDate || !endDate) {
      toast.error("Please fill in all fields");
      return;
    }

    setIsSubmitting(true);
    try {
      await api.post("/events/years", {
        name,
        start_date: startDate,
        end_date: endDate,
        is_active: true,
      });
      toast.success(`Academic year "${name}" created!`);
      setName("");
      setStartDate("");
      setEndDate("");
      setIsOpen(false);
      onCreated();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to create academic year");
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
          <span className="font-semibold text-gray-900">Create Academic Year</span>
        </div>
        {isOpen ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>

      {isOpen && (
        <div className="mt-4 grid md:grid-cols-4 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Year Name *
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="input-field"
              placeholder="2025-2026"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Start Date *
            </label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="input-field"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              End Date *
            </label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="input-field"
            />
          </div>
          <div className="flex items-end">
            <button
              onClick={handleSubmit}
              disabled={isSubmitting}
              className="btn-primary w-full"
            >
              {isSubmitting ? "Creating..." : "Create Year"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Create Event Form ──
function CreateEventForm({ years, onCreated }) {
  const [yearId, setYearId] = useState("");
  const [eventDate, setEventDate] = useState("");
  const [eventTime, setEventTime] = useState("");
  const [notes, setNotes] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isOpen, setIsOpen] = useState(false);

  const handleSubmit = async () => {
    if (!yearId || !eventDate) {
      toast.error("Please select a year and date");
      return;
    }

    setIsSubmitting(true);
    try {
      await api.post("/events", {
        academic_year_id: yearId,
        event_date: eventDate,
        event_time: eventTime || undefined,
        notes: notes || undefined,
      });
      toast.success("Event created!");
      setEventDate("");
      setEventTime("");
      setNotes("");
      setIsOpen(false);
      onCreated();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to create event");
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
          <Calendar size={18} className="text-green-600" />
          <span className="font-semibold text-gray-900">Create Event Date</span>
        </div>
        {isOpen ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>

      {isOpen && (
        <div className="mt-4 space-y-4">
          <div className="grid md:grid-cols-4 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Academic Year *
              </label>
              <select
                value={yearId}
                onChange={(e) => setYearId(e.target.value)}
                className="input-field"
              >
                <option value="">Select year...</option>
                {years.map((y) => (
                  <option key={y.id} value={y.id}>
                    {y.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Event Date *
              </label>
              <input
                type="date"
                value={eventDate}
                onChange={(e) => setEventDate(e.target.value)}
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Time (optional)
              </label>
              <input
                type="time"
                value={eventTime}
                onChange={(e) => setEventTime(e.target.value)}
                className="input-field"
              />
            </div>
            <div className="flex items-end">
              <button
                onClick={handleSubmit}
                disabled={isSubmitting}
                className="btn-primary w-full"
              >
                {isSubmitting ? "Creating..." : "Create Event"}
              </button>
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Notes (optional)
            </label>
            <input
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              className="input-field"
              placeholder="e.g., Fall kickoff event"
            />
          </div>
        </div>
      )}
    </div>
  );
}

// ── Status Badge ──
function StatusBadge({ status }) {
  const styles = {
    available: "bg-green-100 text-green-700",
    reserved: "bg-blue-100 text-blue-700",
    completed: "bg-gray-100 text-gray-700",
    cancelled: "bg-red-100 text-red-700",
  };
  const icons = {
    available: <CheckCircle size={12} />,
    reserved: <School size={12} />,
    completed: <CheckCircle size={12} />,
    cancelled: <XCircle size={12} />,
  };

  return (
    <span
      className={`inline-flex items-center space-x-1 px-2 py-1 rounded-full text-xs font-medium ${
        styles[status] || "bg-gray-100 text-gray-700"
      }`}
    >
      {icons[status]}
      <span className="capitalize">{status}</span>
    </span>
  );
}

// ── Main Page ──
export default function AdminEventsPage() {
  const [years, setYears] = useState([]);
  const [events, setEvents] = useState([]);
  const [selectedYear, setSelectedYear] = useState("");
  const [loading, setLoading] = useState(true);

  // Fetch academic years
  const fetchYears = useCallback(async () => {
    try {
      const response = await api.get("/events/years");
      setYears(response.data);
      setSelectedYear((prev) => {
        if (response.data.length > 0 && !prev) {
          return response.data[0].id;
        }
        return prev;
      });
    } catch (error) {
      console.error("Failed to fetch years:", error);
    }
  }, []);

  // Fetch events
  const fetchEvents = useCallback(async () => {
    if (!selectedYear) return;
    setLoading(true);
    try {
      let url = "/events";
      url += `?academic_year_id=${selectedYear}`;
      const response = await api.get(url);
      setEvents(response.data.events || response.data);
    } catch (error) {
      console.error("Failed to fetch events:", error);
    }
    setLoading(false);
  }, [selectedYear]);

  useEffect(() => {
    fetchYears();
  }, [fetchYears]);

  useEffect(() => {
    if (selectedYear) {
      fetchEvents();
    }
  }, [selectedYear, fetchEvents]);

  const handleRefresh = () => {
    fetchYears();
    fetchEvents();
  };

  // Cancel event
  const handleCancel = async (eventId) => {
    if (!window.confirm("Are you sure you want to cancel this event?")) return;
    try {
      await api.delete(`/events/${eventId}`);
      toast.success("Event cancelled");
      fetchEvents();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to cancel event");
    }
  };

  // Count by status
  const available = events.filter((e) => e.status === "available").length;
  const reserved = events.filter((e) => e.status === "reserved").length;
  const completed = events.filter((e) => e.status === "completed").length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <Calendar size={28} />
            <span>Event Management</span>
          </h1>
          <p className="text-gray-500 mt-1">
            Create and manage academic years and event dates
          </p>
        </div>
        <button
          onClick={handleRefresh}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Create Forms */}
      <CreateYearForm onCreated={handleRefresh} />
      <CreateEventForm years={years} onCreated={handleRefresh} />

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        <div className="card text-center">
          <p className="text-2xl font-bold text-green-600">{available}</p>
          <p className="text-sm text-gray-500">Available</p>
        </div>
        <div className="card text-center">
          <p className="text-2xl font-bold text-blue-600">{reserved}</p>
          <p className="text-sm text-gray-500">Reserved</p>
        </div>
        <div className="card text-center">
          <p className="text-2xl font-bold text-gray-600">{completed}</p>
          <p className="text-sm text-gray-500">Completed</p>
        </div>
      </div>

      {/* Year Filter */}
      <div className="flex items-center space-x-4">
        <label className="text-sm font-medium text-gray-700">Academic Year:</label>
        <select
          value={selectedYear}
          onChange={(e) => setSelectedYear(e.target.value)}
          className="input-field w-48"
        >
          {years.map((y) => (
            <option key={y.id} value={y.id}>
              {y.name}
            </option>
          ))}
        </select>
      </div>

      {/* Events Table */}
      <div className="card overflow-hidden p-0">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        ) : events.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <Calendar className="mx-auto mb-3 text-gray-300" size={48} />
            <p>No events yet. Create one above!</p>
          </div>
        ) : (
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Date
                </th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Time
                </th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Status
                </th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Notes
                </th>
                <th className="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {events.map((event) => (
                <tr key={event.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium text-gray-900">
                    {new Date(event.event_date).toLocaleDateString("en-US", {
                      weekday: "short",
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {event.event_time || "—"}
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge status={event.status} />
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {event.notes || "—"}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {event.status === "available" && (
                      <button
                        onClick={() => handleCancel(event.id)}
                        className="text-red-500 hover:text-red-600 text-sm font-medium"
                      >
                        Cancel
                      </button>
                    )}
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
