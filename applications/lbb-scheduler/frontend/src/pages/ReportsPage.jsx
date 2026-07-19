/**
 * Reports Page — Analytics Dashboard for LBB Admins
 *
 * Features:
 *   - Tab navigation: Events Summary | Volunteer Engagement
 *   - KPI summary cards
 *   - Interactive charts (bar, line, pie)
 *   - Date range + academic year filters
 *   - Download buttons: CSV and PDF
 */

import { useState, useEffect } from "react";
import {
  BarChart3,
  Download,
  FileText,
  RefreshCw,
  Users,
  Calendar,
  TrendingUp,
  School as SchoolIcon,
} from "lucide-react";
import {
  BarChart, Bar,
  LineChart, Line,
  PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip,
  ResponsiveContainer, CartesianGrid,
} from "recharts";
import toast from "react-hot-toast";
import api from "../services/api";

const CHART_COLORS = [
  "#1F4E79", "#2E86AB", "#A23B72", "#F18F01",
  "#C73E1D", "#3B8D8D", "#6A4C93", "#E07A5F",
];

export default function ReportsPage() {
  const [activeTab, setActiveTab] = useState("events");
  const [years, setYears] = useState([]);
  const [selectedYear, setSelectedYear] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [loading, setLoading] = useState(false);
  const [report, setReport] = useState(null);

  useEffect(() => {
    fetchYears();
  }, []);

  useEffect(() => {
    fetchReport();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab, selectedYear, startDate, endDate]);

  const fetchYears = async () => {
    try {
      const response = await api.get("/events/years");
      setYears(response.data);
    } catch (error) {
      console.error("Failed to fetch years:", error);
    }
  };

  const buildQueryString = () => {
    const params = new URLSearchParams();
    if (selectedYear) params.append("academic_year_id", selectedYear);
    if (startDate) params.append("start_date", startDate);
    if (endDate) params.append("end_date", endDate);
    return params.toString() ? `?${params.toString()}` : "";
  };

  const fetchReport = async () => {
    setLoading(true);
    try {
      const endpoint = activeTab === "events"
        ? "events-summary"
        : "volunteer-engagement";
      const response = await api.get(`/reports/${endpoint}${buildQueryString()}`);
      setReport(response.data);
    } catch (error) {
      console.error("Failed to fetch report:", error);
      toast.error("Failed to load report");
      setReport(null);
    }
    setLoading(false);
  };

  const handleDownload = async (format) => {
    const endpoint = activeTab === "events"
      ? "events-summary"
      : "volunteer-engagement";
    const url = `/reports/${endpoint}.${format}${buildQueryString()}`;

    try {
      const response = await api.get(url, { responseType: "blob" });
      const blob = new Blob([response.data], {
        type: format === "pdf" ? "application/pdf" : "text/csv",
      });
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = downloadUrl;
      link.download = `lbb_${endpoint}_${new Date().toISOString().slice(0, 10)}.${format}`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(downloadUrl);
      toast.success(`${format.toUpperCase()} downloaded`);
    } catch (error) {
      console.error("Download failed:", error);
      toast.error(`Failed to download ${format.toUpperCase()}`);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <BarChart3 size={28} />
            <span>Reports and Analytics</span>
          </h1>
          <p className="text-gray-500 mt-1">
            Insights into program performance and volunteer engagement
          </p>
        </div>
        <button
          onClick={fetchReport}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="flex space-x-6">
          <button
            onClick={() => setActiveTab("events")}
            className={`pb-3 px-1 border-b-2 text-sm font-medium transition ${
              activeTab === "events"
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
            }`}
          >
            <Calendar size={16} className="inline mr-1" />
            Events Summary
          </button>
          <button
            onClick={() => setActiveTab("volunteers")}
            className={`pb-3 px-1 border-b-2 text-sm font-medium transition ${
              activeTab === "volunteers"
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
            }`}
          >
            <Users size={16} className="inline mr-1" />
            Volunteer Engagement
          </button>
        </nav>
      </div>

      {/* Filters + Download */}
      <div className="card flex flex-wrap items-end gap-4">
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">
            Academic Year
          </label>
          <select
            value={selectedYear}
            onChange={(e) => setSelectedYear(e.target.value)}
            className="input-field w-48"
          >
            <option value="">All years</option>
            {years.map((y) => (
              <option key={y.id} value={y.id}>{y.name}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">
            Start Date
          </label>
          <input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            className="input-field w-40"
          />
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">
            End Date
          </label>
          <input
            type="date"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            className="input-field w-40"
          />
        </div>
        <div className="flex-1" />
        <button
          onClick={() => handleDownload("csv")}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-green-600 text-white rounded-lg hover:bg-green-700"
        >
          <Download size={16} />
          <span>Download CSV</span>
        </button>
        <button
          onClick={() => handleDownload("pdf")}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-red-600 text-white rounded-lg hover:bg-red-700"
        >
          <FileText size={16} />
          <span>Download PDF</span>
        </button>
      </div>

      {/* Report Content */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600"></div>
        </div>
      ) : !report ? (
        <div className="card text-center py-12 text-gray-500">
          <BarChart3 className="mx-auto mb-3 text-gray-300" size={48} />
          <p>No data available for the selected filters.</p>
        </div>
      ) : activeTab === "events" ? (
        <EventsReport report={report} />
      ) : (
        <VolunteerReport report={report} />
      )}
    </div>
  );
}

/* ==========================================================
 * Events Summary Report View
 * ========================================================== */
function EventsReport({ report }) {
  const { kpis, by_status, by_month, by_district, top_schools } = report;

  return (
    <div className="space-y-6">
      {/* KPI Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard icon={Calendar} label="Total Events" value={kpis.total_events} color="blue" />
        <KpiCard icon={TrendingUp} label="Fill Rate" value={`${kpis.fill_rate_pct}%`} color="green" />
        <KpiCard icon={Users} label="Students Served" value={kpis.total_students_served.toLocaleString()} color="purple" />
        <KpiCard icon={SchoolIcon} label="Schools" value={kpis.schools_participating} color="orange" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Events by Status Pie */}
        <ChartCard title="Events by Status">
          <ResponsiveContainer width="100%" height={280}>
            <PieChart>
              <Pie
                data={by_status}
                dataKey="count"
                nameKey="status"
                cx="50%"
                cy="50%"
                outerRadius={90}
                label={({ status, count }) => `${status}: ${count}`}
              >
                {by_status.map((_, idx) => (
                  <Cell key={idx} fill={CHART_COLORS[idx % CHART_COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Events by Month Line */}
        <ChartCard title="Events by Month">
          <ResponsiveContainer width="100%" height={280}>
            <LineChart data={by_month}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="month" fontSize={11} />
              <YAxis fontSize={11} />
              <Tooltip />
              <Line type="monotone" dataKey="events" stroke="#1F4E79" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Events by District */}
        <ChartCard title="Events by District">
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={by_district} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis type="number" fontSize={11} />
              <YAxis type="category" dataKey="district" fontSize={11} width={120} />
              <Tooltip />
              <Bar dataKey="events" fill="#2E86AB" />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Top Schools */}
        <ChartCard title="Top 10 Schools by Participation">
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={top_schools} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis type="number" fontSize={11} />
              <YAxis type="category" dataKey="school" fontSize={10} width={140} />
              <Tooltip />
              <Bar dataKey="events" fill="#A23B72" />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      {/* Additional KPIs */}
      <div className="card">
        <h3 className="font-semibold text-gray-900 mb-3">Additional Metrics</h3>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4 text-sm">
          <Stat label="Registered Events" value={kpis.registered_events} />
          <Stat label="Available Events" value={kpis.available_events} />
          <Stat label="Completed Events" value={kpis.completed_events} />
          <Stat label="Cancelled Events" value={kpis.cancelled_events} />
          <Stat label="Avg Students per Event" value={kpis.avg_students_per_event} />
          <Stat label="Districts Participating" value={kpis.districts_participating} />
        </div>
      </div>
    </div>
  );
}

/* ==========================================================
 * Volunteer Engagement Report View
 * ========================================================== */
function VolunteerReport({ report }) {
  const { kpis, signups_by_month, top_volunteers, by_district } = report;

  return (
    <div className="space-y-6">
      {/* KPI Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard icon={Users} label="Active Volunteers" value={kpis.total_active_volunteers} color="blue" />
        <KpiCard icon={TrendingUp} label="Participation Rate" value={`${kpis.participation_rate_pct}%`} color="green" />
        <KpiCard icon={Calendar} label="Total Signups" value={kpis.total_signups} color="purple" />
        <KpiCard icon={BarChart3} label="Avg per Volunteer" value={kpis.avg_events_per_volunteer} color="orange" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Signups by Month */}
        <ChartCard title="Signups by Month">
          <ResponsiveContainer width="100%" height={280}>
            <LineChart data={signups_by_month}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="month" fontSize={11} />
              <YAxis fontSize={11} />
              <Tooltip />
              <Line type="monotone" dataKey="signups" stroke="#1F4E79" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Volunteers by District */}
        <ChartCard title="Volunteers by District">
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={by_district} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis type="number" fontSize={11} />
              <YAxis type="category" dataKey="district" fontSize={11} width={120} />
              <Tooltip />
              <Bar dataKey="signups" fill="#2E86AB" />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      {/* Top Volunteers Table */}
      <div className="card">
        <h3 className="font-semibold text-gray-900 mb-3">Top 10 Volunteers</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-3 py-2 text-left font-medium text-gray-700">Rank</th>
                <th className="px-3 py-2 text-left font-medium text-gray-700">Name</th>
                <th className="px-3 py-2 text-right font-medium text-gray-700">Events Signed Up</th>
              </tr>
            </thead>
            <tbody>
              {top_volunteers.map((v, idx) => (
                <tr key={v.volunteer_id} className="border-b">
                  <td className="px-3 py-2 font-medium">{idx + 1}</td>
                  <td className="px-3 py-2">{v.name}</td>
                  <td className="px-3 py-2 text-right font-mono">{v.events_signed_up}</td>
                </tr>
              ))}
              {top_volunteers.length === 0 && (
                <tr>
                  <td colSpan={3} className="px-3 py-6 text-center text-gray-500">
                    No volunteer signups in this period
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

/* ==========================================================
 * Reusable Components
 * ========================================================== */
function KpiCard({ icon: Icon, label, value, color }) {
  const colorMap = {
    blue: "bg-blue-50 text-blue-700",
    green: "bg-green-50 text-green-700",
    purple: "bg-purple-50 text-purple-700",
    orange: "bg-orange-50 text-orange-700",
  };
  return (
    <div className="card">
      <div className={`inline-flex p-2 rounded-lg ${colorMap[color]} mb-2`}>
        <Icon size={20} />
      </div>
      <p className="text-2xl font-bold text-gray-900">{value}</p>
      <p className="text-sm text-gray-500">{label}</p>
    </div>
  );
}

function ChartCard({ title, children }) {
  return (
    <div className="card">
      <h3 className="font-semibold text-gray-900 mb-3">{title}</h3>
      {children}
    </div>
  );
}

function Stat({ label, value }) {
  return (
    <div>
      <p className="text-gray-500">{label}</p>
      <p className="font-semibold text-gray-900">{value}</p>
    </div>
  );
}
