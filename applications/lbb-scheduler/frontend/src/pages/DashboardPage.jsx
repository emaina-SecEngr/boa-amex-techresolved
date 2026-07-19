/**
 * Dashboard Page — Role-Aware Landing Page with Real Data
 * =========================================================
 */

import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";
import api from "../services/api";
import {
  Calendar,
  Users,
  School,
  DollarSign,
  Clock,
  CheckCircle,
  AlertCircle,
  Shield,
  ClipboardList,
} from "lucide-react";

// ---------------------------------------------------------------
// Admin Dashboard — full program overview with real data
// ---------------------------------------------------------------
function AdminDashboard({ user }) {
  const [metrics, setMetrics] = useState({
    totalUsers: "—",
    pendingUsers: "—",
    activeUsers: "—",
  });
  const [pendingUsers, setPendingUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        // Fetch all users
        const usersRes = await api.get("/users?page=1&per_page=100");
        const users = usersRes.data.users;

        const pending = users.filter((u) => !u.is_active);
        const active = users.filter((u) => u.is_active);

        setMetrics({
          totalUsers: usersRes.data.total,
          pendingUsers: pending.length,
          activeUsers: active.length,
        });

        setPendingUsers(pending.slice(0, 5)); // Show max 5
      } catch (error) {
        console.error("Failed to fetch dashboard data:", error);
      }
      setLoading(false);
    };

    fetchData();
  }, []);

  const metricCards = [
    { label: "Total Users", value: metrics.totalUsers, icon: Users, color: "text-blue-600", bg: "bg-blue-50" },
    { label: "Active Users", value: metrics.activeUsers, icon: CheckCircle, color: "text-green-600", bg: "bg-green-50" },
    { label: "Pending Approval", value: metrics.pendingUsers, icon: Clock, color: "text-amber-600", bg: "bg-amber-50" },
    { label: "Admin Panel", value: "→", icon: Shield, color: "text-purple-600", bg: "bg-purple-50", link: "/admin/users" },
  ];

  return (
    <div className="space-y-6">
      {/* Welcome header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">
          Welcome back, {user.first_name}!
        </h1>
        <p className="text-gray-500">LBB Program Administrator Dashboard</p>
      </div>

      {/* Metrics Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {metricCards.map((metric) => {
          const Icon = metric.icon;
          const content = (
            <div className="card hover:shadow-md transition-shadow">
              <div className="flex items-center space-x-3">
                <div className={`p-2 rounded-lg ${metric.bg}`}>
                  <Icon className={metric.color} size={24} />
                </div>
                <div>
                  <p className="text-2xl font-bold text-gray-900">
                    {loading ? "..." : metric.value}
                  </p>
                  <p className="text-sm text-gray-500">{metric.label}</p>
                </div>
              </div>
            </div>
          );

          if (metric.link) {
            return (
              <Link key={metric.label} to={metric.link}>
                {content}
              </Link>
            );
          }
          return <div key={metric.label}>{content}</div>;
        })}
      </div>

      {/* Quick action cards */}
      <div className="grid md:grid-cols-2 gap-6">
        {/* Pending Approvals */}
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center space-x-2">
              <AlertCircle className="text-amber-500" size={20} />
              <h3 className="font-semibold text-gray-900">Pending Approvals</h3>
            </div>
            {pendingUsers.length > 0 && (
              <Link
                to="/admin/users"
                className="text-sm text-blue-600 hover:underline"
              >
                View all →
              </Link>
            )}
          </div>
          {loading ? (
            <div className="animate-pulse space-y-2">
              <div className="h-4 bg-gray-200 rounded w-3/4"></div>
              <div className="h-4 bg-gray-200 rounded w-1/2"></div>
            </div>
          ) : pendingUsers.length === 0 ? (
            <p className="text-gray-500 text-sm">
              No pending account requests. All caught up!
            </p>
          ) : (
            <div className="space-y-2">
              {pendingUsers.map((u) => (
                <div
                  key={u.id}
                  className="flex items-center justify-between py-2 border-b border-gray-100 last:border-0"
                >
                  <div>
                    <p className="text-sm font-medium text-gray-900">
                      {u.first_name} {u.last_name}
                    </p>
                    <p className="text-xs text-gray-500">
                      @{u.username} · {u.role.replace("_", " ")}
                    </p>
                  </div>
                  <span className="text-xs bg-amber-100 text-amber-700 px-2 py-1 rounded-full">
                    Pending
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Quick Links */}
        <div className="card">
          <div className="flex items-center space-x-2 mb-4">
            <Calendar className="text-blue-500" size={20} />
            <h3 className="font-semibold text-gray-900">Quick Actions</h3>
          </div>
          <div className="space-y-2">
            <Link
              to="/admin/users"
              className="flex items-center space-x-2 p-3 rounded-lg hover:bg-gray-50 border border-gray-100"
            >
              <Users size={18} className="text-blue-600" />
              <span className="text-sm text-gray-700">Manage Users & Approvals</span>
            </Link>
            <Link
              to="/admin/events"
              className="flex items-center space-x-2 p-3 rounded-lg hover:bg-gray-50 border border-gray-100"
            >
              <Calendar size={18} className="text-green-600" />
              <span className="text-sm text-gray-700">Manage Events</span>
            </Link>
            <Link
              to="/admin/schools"
              className="flex items-center space-x-2 p-3 rounded-lg hover:bg-gray-50 border border-gray-100"
            >
              <School size={18} className="text-purple-600" />
              <span className="text-sm text-gray-700">Manage Schools</span>
            </Link>
            <Link
              to="/admin/donations"
              className="flex items-center space-x-2 p-3 rounded-lg hover:bg-gray-50 border border-gray-100"
            >
              <DollarSign size={18} className="text-amber-600" />
              <span className="text-sm text-gray-700">Track Donations</span>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------
// School Admin Dashboard
// ---------------------------------------------------------------
function SchoolDashboard({ user }) {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">
          Welcome, {user.first_name}!
        </h1>
        <p className="text-gray-500">School Administrator Dashboard</p>
      </div>

      <div className="grid md:grid-cols-2 gap-6">
        <Link
          to="/school/register"
          className="card block hover:shadow-md transition-shadow border-l-4 border-lbb-primary"
        >
          <div className="flex items-center space-x-2 mb-2">
            <Calendar className="text-blue-500" size={20} />
            <h3 className="font-semibold text-gray-900">Register for an event</h3>
          </div>
          <p className="text-gray-500 text-sm">
            Choose an available LBB date and register your school (one school per date).
          </p>
          <span className="text-lbb-primary text-sm font-medium mt-2 inline-block">Open registration →</span>
        </Link>

        <Link
          to="/school/schedule"
          className="card block hover:shadow-md transition-shadow border-l-4 border-green-500"
        >
          <div className="flex items-center space-x-2 mb-2">
            <CheckCircle className="text-green-500" size={20} />
            <h3 className="font-semibold text-gray-900">Our schedule</h3>
          </div>
          <p className="text-gray-500 text-sm">
            View event dates your school has already registered for.
          </p>
          <span className="text-green-700 text-sm font-medium mt-2 inline-block">View schedule →</span>
        </Link>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------
// Volunteer Dashboard
// ---------------------------------------------------------------
function VolunteerDashboard({ user }) {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">
          Welcome, {user.first_name}!
        </h1>
        <p className="text-gray-500">Volunteer Dashboard</p>
      </div>

      <Link
        to="/volunteer/profile"
        className="card block hover:shadow-md transition-shadow border-l-4 border-lbb-primary"
      >
        <h3 className="font-semibold text-gray-900">My volunteer profile</h3>
        <p className="text-gray-500 text-sm mt-1">
          Add your organization, bio, availability, and special requirements so administrators can schedule you.
        </p>
        <span className="text-lbb-primary text-sm font-medium mt-2 inline-block">Edit profile →</span>
      </Link>

      <div className="grid md:grid-cols-2 gap-6">
        <Link
          to="/volunteer/events"
          className="card block hover:shadow-md transition-shadow border-l-4 border-blue-500"
        >
          <div className="flex items-center space-x-2 mb-2">
            <Calendar className="text-blue-500" size={20} />
            <h3 className="font-semibold text-gray-900">Browse & sign up for events</h3>
          </div>
          <p className="text-gray-500 text-sm">
            See published LBB dates and volunteer for sessions that fit your schedule.
          </p>
          <span className="text-blue-700 text-sm font-medium mt-2 inline-block">Open events →</span>
        </Link>

        <Link
          to="/volunteer/schedule"
          className="card block hover:shadow-md transition-shadow border-l-4 border-green-500"
        >
          <div className="flex items-center space-x-2 mb-2">
            <ClipboardList className="text-green-600" size={20} />
            <h3 className="font-semibold text-gray-900">My schedule</h3>
          </div>
          <p className="text-gray-500 text-sm">
            View event dates you have already signed up for.
          </p>
          <span className="text-green-700 text-sm font-medium mt-2 inline-block">View schedule →</span>
        </Link>

        <Link
          to="/volunteer/classes"
          className="card block hover:shadow-md transition-shadow border-l-4 border-purple-500 md:col-span-2"
        >
          <div className="flex items-center space-x-2 mb-2">
            <School className="text-purple-500" size={20} />
            <h3 className="font-semibold text-gray-900">My classes</h3>
          </div>
          <p className="text-gray-500 text-sm">
            View life skills sessions you are assigned to lead in the program catalog.
          </p>
          <span className="text-purple-700 text-sm font-medium mt-2 inline-block">View classes →</span>
        </Link>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------
// Main Dashboard — renders based on role
// ---------------------------------------------------------------
export default function DashboardPage() {
  const { user } = useAuth();

  if (user?.role === "lbb_admin" || user?.role === "it_support") {
    return <AdminDashboard user={user} />;
  }

  if (user?.role === "school_admin") {
    return <SchoolDashboard user={user} />;
  }

  if (user?.role === "volunteer") {
    return <VolunteerDashboard user={user} />;
  }

  return (
    <div className="text-center py-12">
      <p className="text-gray-500">Unknown role. Please contact an administrator.</p>
    </div>
  );
}
