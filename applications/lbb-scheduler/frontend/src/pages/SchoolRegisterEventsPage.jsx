/**
 * School admin: browse available LBB event dates and register their school.
 * POST /events/{event_id}/register
 */

import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import toast from "react-hot-toast";
import {
  Calendar,
  Loader2,
  ArrowLeft,
  School,
  ClipboardCheck,
} from "lucide-react";
import api from "../services/api";

function RegisterModal({ event: ev, schoolId, onClose, onSuccess }) {
  const [anticipated, setAnticipated] = useState(30);
  const [requestedTime, setRequestedTime] = useState("");
  const [specialRequests, setSpecialRequests] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!anticipated || anticipated < 1) {
      toast.error("Enter anticipated number of students (1–500)");
      return;
    }
    setSubmitting(true);
    try {
      await api.post(`/events/${ev.id}/register`, {
        school_id: schoolId,
        anticipated_students: Number(anticipated),
        requested_time: requestedTime || null,
        special_requests: specialRequests || null,
      });
      toast.success("Your school is registered for this event date.");
      onSuccess();
      onClose();
    } catch (err) {
      const d = err.response?.data?.detail;
      toast.error(typeof d === "string" ? d : "Registration failed");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6 space-y-4">
        <h3 className="text-lg font-semibold text-gray-900">Register for event</h3>
        <p className="text-sm text-gray-500">
          {ev.event_date} {ev.event_time ? `· ${ev.event_time}` : ""}
        </p>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Anticipated students *
            </label>
            <input
              type="number"
              min={1}
              max={500}
              value={anticipated}
              onChange={(e) => setAnticipated(e.target.value)}
              className="input-field"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Preferred start time (optional)
            </label>
            <input
              type="time"
              value={requestedTime}
              onChange={(e) => setRequestedTime(e.target.value)}
              className="input-field"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Special requests (optional)
            </label>
            <textarea
              value={specialRequests}
              onChange={(e) => setSpecialRequests(e.target.value)}
              className="input-field min-h-[80px]"
              maxLength={500}
              placeholder="Logistics, room needs, etc."
            />
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button type="button" onClick={onClose} className="btn-secondary">
              Cancel
            </button>
            <button type="submit" disabled={submitting} className="btn-primary">
              {submitting ? <Loader2 className="animate-spin" size={18} /> : "Confirm registration"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function SchoolRegisterEventsPage() {
  const [loading, setLoading] = useState(true);
  const [school, setSchool] = useState(null);
  const [events, setEvents] = useState([]);
  const [modalEvent, setModalEvent] = useState(null);

  const load = async () => {
    setLoading(true);
    try {
      const schoolsRes = await api.get("/schools");
      const schools = schoolsRes.data.schools || [];
      setSchool(schools[0] || null);

      const evRes = await api.get("/events?event_status=available");
      setEvents(evRes.data.events || []);
    } catch (err) {
      toast.error(err.response?.data?.detail || "Failed to load data");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  if (loading) {
    return (
      <div className="flex justify-center py-16">
        <Loader2 className="animate-spin text-lbb-primary" size={40} />
      </div>
    );
  }

  if (!school) {
    return (
      <div className="max-w-xl mx-auto space-y-4">
        <Link to="/dashboard" className="inline-flex items-center text-sm text-gray-500 hover:text-gray-800">
          <ArrowLeft size={16} className="mr-1" />
          Back to dashboard
        </Link>
        <div className="card border-amber-200 bg-amber-50">
          <School className="text-amber-600 mb-2" size={32} />
          <h1 className="text-lg font-semibold text-gray-900">No school linked to your account</h1>
          <p className="text-gray-600 text-sm mt-2">
            An LBB program administrator must create your school record and assign you as the school administrator before you can register for events.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div>
        <Link to="/dashboard" className="inline-flex items-center text-sm text-gray-500 hover:text-gray-800 mb-4">
          <ArrowLeft size={16} className="mr-1" />
          Back to dashboard
        </Link>
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <Calendar className="text-lbb-primary" size={28} />
          Register for an LBB event
        </h1>
        <p className="text-gray-500 mt-1 flex items-center gap-2">
          <School size={16} />
          {school.school_name} · {school.school_district}
        </p>
      </div>

      <div className="card overflow-hidden p-0">
        {events.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <Calendar className="mx-auto mb-3 text-gray-300" size={48} />
            <p>There are no open event dates right now.</p>
            <p className="text-sm mt-2">Check back after administrators publish new dates.</p>
          </div>
        ) : (
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Date</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Time</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Notes</th>
                <th className="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {events.map((ev) => (
                <tr key={ev.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium text-gray-900">{ev.event_date}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">{ev.event_time || "—"}</td>
                  <td className="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">{ev.notes || "—"}</td>
                  <td className="px-4 py-3 text-right">
                    <button
                      type="button"
                      onClick={() => setModalEvent(ev)}
                      className="btn-primary text-sm py-1.5 inline-flex items-center gap-1"
                    >
                      <ClipboardCheck size={16} />
                      Register
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {modalEvent && (
        <RegisterModal
          event={modalEvent}
          schoolId={school.id}
          onClose={() => setModalEvent(null)}
          onSuccess={load}
        />
      )}
    </div>
  );
}
