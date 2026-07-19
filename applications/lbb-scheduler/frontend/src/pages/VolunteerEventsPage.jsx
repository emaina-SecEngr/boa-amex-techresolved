/**
 * Volunteer Events Page — Browse and Sign Up for Events
 */

import { useState, useEffect } from "react";
import {
  Calendar,
  CheckCircle,
  Clock,
  RefreshCw,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

export default function VolunteerEventsPage() {
  const [events, setEvents] = useState([]);
  const [years, setYears] = useState([]);
  const [selectedYear, setSelectedYear] = useState("");
  const [loading, setLoading] = useState(true);
  const [mySignups, setMySignups] = useState([]);

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

  const fetchMySignups = async () => {
    try {
      const response = await api.get("/events/my-volunteer-signups");
      setMySignups(response.data.signups || response.data || []);
    } catch (error) {
      console.error("Failed to fetch signups:", error);
      setMySignups([]);
    }
  };

  useEffect(() => {
    fetchYears();
    fetchMySignups();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (selectedYear) fetchEvents();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedYear]);

  const handleSignup = async (eventId) => {
    try {
      await api.post(`/events/${eventId}/signup`, { class_id: null });
      toast.success("Signed up for event!");
      fetchMySignups();
      fetchEvents();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to sign up");
    }
  };

  const handleWithdraw = async (eventId) => {
    try {
      await api.delete(`/events/${eventId}/signup`);
      toast.success("Withdrawn from event");
      fetchMySignups();
      fetchEvents();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to withdraw");
    }
  };

  const isSignedUp = (eventId) => {
    return mySignups.some((s) => s.event_id === eventId || s.id === eventId);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <Calendar size={28} />
            <span>Browse Events</span>
          </h1>
          <p className="text-gray-500 mt-1">Find and sign up for upcoming LBB events</p>
        </div>
        <button
          onClick={() => { fetchEvents(); fetchMySignups(); }}
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

      {/* Events List */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      ) : events.length === 0 ? (
        <div className="card text-center py-12 text-gray-500">
          <Calendar className="mx-auto mb-3 text-gray-300" size={48} />
          <p>No events available yet. Check back soon!</p>
        </div>
      ) : (
        <div className="grid md:grid-cols-2 gap-4">
          {events.map((event) => (
            <div key={event.id} className="card hover:shadow-md transition-shadow">
              <div className="flex items-start justify-between">
                <div>
                  <p className="font-semibold text-gray-900">
                    {new Date(event.event_date).toLocaleDateString("en-US", {
                      weekday: "long",
                      month: "long",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </p>
                  {event.event_time && (
                    <p className="text-sm text-gray-500 flex items-center space-x-1 mt-1">
                      <Clock size={14} />
                      <span>{event.event_time}</span>
                    </p>
                  )}
                  {event.notes && (
                    <p className="text-sm text-gray-600 mt-2">{event.notes}</p>
                  )}
                  <span className={`inline-block mt-2 px-2 py-1 rounded-full text-xs font-medium ${
                    event.status === "available" ? "bg-green-100 text-green-700" :
                    event.status === "reserved" ? "bg-blue-100 text-blue-700" :
                    "bg-gray-100 text-gray-700"
                  }`}>
                    {event.status}
                  </span>
                </div>
                <div>
                  {isSignedUp(event.id) ? (
                    <div className="text-center">
                      <span className="flex items-center space-x-1 text-green-600 text-sm mb-2">
                        <CheckCircle size={16} />
                        <span>Signed Up</span>
                      </span>
                      <button
                        onClick={() => handleWithdraw(event.id)}
                        className="text-xs text-red-500 hover:text-red-600"
                      >
                        Withdraw
                      </button>
                    </div>
                  ) : event.status === "available" ? (
                    <button
                      onClick={() => handleSignup(event.id)}
                      className="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700"
                    >
                      Sign Up
                    </button>
                  ) : null}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
