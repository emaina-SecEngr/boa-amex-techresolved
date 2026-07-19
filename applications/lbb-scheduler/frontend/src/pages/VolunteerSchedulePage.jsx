/**
 * Volunteer Schedule Page — My Upcoming Events
 */

import { useState, useEffect } from "react";
import {
  Calendar,
  Clock,
  CheckCircle,
  XCircle,
  RefreshCw,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

export default function VolunteerSchedulePage() {
  const [signups, setSignups] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchSignups = async () => {
    setLoading(true);
    try {
      const response = await api.get("/events/my-volunteer-signups");
      setSignups(response.data.signups || response.data || []);
    } catch (error) {
      console.error("Failed to fetch schedule:", error);
      setSignups([]);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchSignups();
  }, []);

  const handleWithdraw = async (eventId) => {
    if (!window.confirm("Are you sure you want to withdraw from this event?")) return;
    try {
      await api.delete(`/events/${eventId}/volunteer-signup`);
      toast.success("Withdrawn from event");
      fetchSignups();
    } catch (error) {
      toast.error("Failed to withdraw");
    }
  };

  const upcomingEvents = signups.filter(
    (s) => new Date(s.event_date || s.created_at) >= new Date()
  );
  const pastEvents = signups.filter(
    (s) => new Date(s.event_date || s.created_at) < new Date()
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <Calendar size={28} />
            <span>My Schedule</span>
          </h1>
          <p className="text-gray-500 mt-1">Events you have signed up for</p>
        </div>
        <button
          onClick={fetchSignups}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-4">
        <div className="card text-center">
          <p className="text-2xl font-bold text-blue-600">{upcomingEvents.length}</p>
          <p className="text-sm text-gray-500">Upcoming Events</p>
        </div>
        <div className="card text-center">
          <p className="text-2xl font-bold text-green-600">{pastEvents.length}</p>
          <p className="text-sm text-gray-500">Events Completed</p>
        </div>
      </div>

      {/* Upcoming Events */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Upcoming Events</h2>
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        ) : upcomingEvents.length === 0 ? (
          <div className="card text-center py-8 text-gray-500">
            <Calendar className="mx-auto mb-3 text-gray-300" size={48} />
            <p>No upcoming events. Browse events to sign up!</p>
          </div>
        ) : (
          <div className="space-y-3">
            {upcomingEvents.map((signup) => (
              <div key={signup.id} className="card flex items-center justify-between">
                <div>
                  <p className="font-medium text-gray-900">
                    {signup.event_date
                      ? new Date(signup.event_date).toLocaleDateString("en-US", {
                          weekday: "long", month: "long", day: "numeric", year: "numeric",
                        })
                      : "Event date pending"}
                  </p>
                  {signup.event_time && (
                    <p className="text-sm text-gray-500 flex items-center space-x-1 mt-1">
                      <Clock size={14} />
                      <span>{signup.event_time}</span>
                    </p>
                  )}
                </div>
                <button
                  onClick={() => handleWithdraw(signup.event_id || signup.id)}
                  className="flex items-center space-x-1 px-3 py-1.5 text-sm text-red-600 border border-red-200 rounded-lg hover:bg-red-50"
                >
                  <XCircle size={14} />
                  <span>Withdraw</span>
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Past Events */}
      {pastEvents.length > 0 && (
        <div>
          <h2 className="text-lg font-semibold text-gray-900 mb-3">Completed Events</h2>
          <div className="space-y-3">
            {pastEvents.map((signup) => (
              <div key={signup.id} className="card flex items-center justify-between opacity-75">
                <div>
                  <p className="font-medium text-gray-700">
                    {signup.event_date
                      ? new Date(signup.event_date).toLocaleDateString("en-US", {
                          weekday: "long", month: "long", day: "numeric", year: "numeric",
                        })
                      : "Event"}
                  </p>
                </div>
                <span className="flex items-center space-x-1 text-green-600 text-sm">
                  <CheckCircle size={14} />
                  <span>Completed</span>
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

