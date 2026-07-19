/**
 * School Schedule Page — Our Registered Events
 */

import { useState, useEffect } from "react";
import {
  Calendar,
  CheckCircle,
  Clock,
  RefreshCw,
} from "lucide-react";
import api from "../services/api";

export default function SchoolSchedulePage() {
  const [registrations, setRegistrations] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchRegistrations = async () => {
    setLoading(true);
    try {
      const response = await api.get("/events/my-registrations");
      setRegistrations(response.data.registrations || response.data || []);
    } catch (error) {
      console.error("Failed to fetch registrations:", error);
      setRegistrations([]);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchRegistrations();
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <Calendar size={28} />
            <span>Our Schedule</span>
          </h1>
          <p className="text-gray-500 mt-1">Events your school is registered for</p>
        </div>
        <button
          onClick={fetchRegistrations}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Stats */}
      <div className="card text-center">
        <p className="text-2xl font-bold text-purple-600">{registrations.length}</p>
        <p className="text-sm text-gray-500">Registered Events</p>
      </div>

      {/* Registrations */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      ) : registrations.length === 0 ? (
        <div className="card text-center py-12 text-gray-500">
          <Calendar className="mx-auto mb-3 text-gray-300" size={48} />
          <p>No events registered yet. Go to Register for Event to sign up!</p>
        </div>
      ) : (
        <div className="space-y-3">
          {registrations.map((reg) => (
            <div key={reg.id} className="card flex items-center justify-between">
              <div>
                <p className="font-medium text-gray-900">
                  {reg.event_date
                    ? new Date(reg.event_date).toLocaleDateString("en-US", {
                        weekday: "long", month: "long", day: "numeric", year: "numeric",
                      })
                    : "Event"}
                </p>
                {reg.event_time && (
                  <p className="text-sm text-gray-500 flex items-center space-x-1 mt-1">
                    <Clock size={14} />
                    <span>{reg.event_time}</span>
                  </p>
                )}
                <p className="text-xs text-gray-400 mt-1">
                  Registered: {new Date(reg.created_at).toLocaleDateString()}
                </p>
              </div>
              <span className="flex items-center space-x-1 text-green-600 text-sm">
                <CheckCircle size={16} />
                <span>Confirmed</span>
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
