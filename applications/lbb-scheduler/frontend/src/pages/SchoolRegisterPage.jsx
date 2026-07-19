/**
 * School Register Page — Register School for Events
 */

import { useState, useEffect } from "react";
import {
  Calendar,
  CheckCircle,
  School,
  RefreshCw,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

export default function SchoolRegisterPage() {
  const [events, setEvents] = useState([]);
  const [years, setYears] = useState([]);
  const [selectedYear, setSelectedYear] = useState("");
  const [loading, setLoading] = useState(true);
  const [myRegistrations, setMyRegistrations] = useState([]);

  const fetchYears = async () => {
    try {
      const response = await api.get("/events/years");
      setYears(response.data);
      if (response.data.length > 0 && !selectedYear) {
        setSelectedYear(response.data[0].id);
      }
    } catch (error) {
      console.error("Failed to fetch years:", error);
    }
  };

  const fetchEvents = async () => {
    setLoading(true);
    try {
      let url = "/events";
      if (selectedYear) url += `?academic_year_id=${selectedYear}`;
      const response = await api.get(url);
      setEvents(response.data.events || response.data || []);
    } catch (error) {
      console.error("Failed to fetch events:", error);
      setEvents([]);
    }
    setLoading(false);
  };

  const fetchRegistrations = async () => {
    try {
      const response = await api.get("/events/my-registrations");
      setMyRegistrations(response.data.registrations || response.data || []);
    } catch (error) {
      console.error("Failed to fetch registrations:", error);
      setMyRegistrations([]);
    }
  };

  useEffect(() => {
    fetchYears();
    fetchRegistrations();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (selectedYear) fetchEvents();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedYear]);

  const handleRegister = async (eventId) => {
    try {
      await api.post(`/events/${eventId}/register`);
      toast.success("Registered for event!");
      fetchRegistrations();
      fetchEvents();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to register");
    }
  };

  const isRegistered = (eventId) => {
    return myRegistrations.some((r) => r.event_id === eventId || r.id === eventId);
  };

  const availableEvents = events.filter((e) => e.status === "available");

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <School size={28} />
            <span>Register for Events</span>
          </h1>
          <p className="text-gray-500 mt-1">Sign your school up for upcoming LBB events</p>
        </div>
        <button
          onClick={() => { fetchEvents(); fetchRegistrations(); }}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Year Filter */}
      {years.length > 0 && (
        <div className="flex items-center space-x-4">
          <label className="text-sm font-medium text-gray-700">Academic Year:</label>
          <select
            value={selectedYear}
            onChange={(e) => setSelectedYear(e.target.value)}
            className="input-field w-48"
          >
            {years.map((y) => (
              <option key={y.id} value={y.id}>{y.name}</option>
            ))}
          </select>
        </div>
      )}

      {/* Available Events */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      ) : availableEvents.length === 0 ? (
        <div className="card text-center py-12 text-gray-500">
          <Calendar className="mx-auto mb-3 text-gray-300" size={48} />
          <p>No events available for registration. Check back soon!</p>
        </div>
      ) : (
        <div className="grid md:grid-cols-2 gap-4">
          {availableEvents.map((event) => (
            <div key={event.id} className="card hover:shadow-md transition-shadow">
              <div className="flex items-start justify-between">
                <div>
                  <p className="font-semibold text-gray-900">
                    {new Date(event.event_date).toLocaleDateString("en-US", {
                      weekday: "long", month: "long", day: "numeric", year: "numeric",
                    })}
                  </p>
                  {event.event_time && (
                    <p className="text-sm text-gray-500 mt-1">{event.event_time}</p>
                  )}
                  {event.notes && (
                    <p className="text-sm text-gray-600 mt-2">{event.notes}</p>
                  )}
                </div>
                {isRegistered(event.id) ? (
                  <span className="flex items-center space-x-1 text-green-600 text-sm">
                    <CheckCircle size={16} />
                    <span>Registered</span>
                  </span>
                ) : (
                  <button
                    onClick={() => handleRegister(event.id)}
                    className="px-4 py-2 bg-purple-600 text-white text-sm rounded-lg hover:bg-purple-700"
                  >
                    Register School
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
