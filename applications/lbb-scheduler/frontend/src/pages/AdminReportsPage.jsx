/**
 * Admin Reports — Complete Analytics Dashboard
 * ConOps 6.5.16, 6.6.12, 6.6.13
 *
 * Tabs: Events | Volunteers | Donations | Open Slots | Class Frequency | Raw Data
 */

import { useState, useEffect } from "react";
import {
  BarChart3, Download, FileText, Loader2, RefreshCw, Users,
  Calendar, TrendingUp, School as SchoolIcon, DollarSign, BookOpen,
} from "lucide-react";
import {
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from "recharts";
import toast from "react-hot-toast";
import api from "../services/api";

const COLORS = ["#1F4E79", "#2E86AB", "#A23B72", "#F18F01", "#C73E1D", "#3B8D8D", "#6A4C93", "#E07A5F"];

export default function AdminReportsPage() {
  const [tab, setTab] = useState("events");
  const [years, setYears] = useState([]);
  const [yearId, setYearId] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [loading, setLoading] = useState(false);
  const [report, setReport] = useState(null);

  // Legacy
  const [mvp2, setMvp2] = useState(null);
  const [attendance, setAttendance] = useState(null);
  const [loadingLeg, setLoadingLeg] = useState(false);

  useEffect(() => { fetchYears(); }, []);

  useEffect(() => {
    if (["events", "volunteers", "donations", "openslots", "classfreq"].includes(tab)) {
      fetchReport();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, yearId]);

  const fetchYears = async () => {
    try { const r = await api.get("/events/years"); setYears(r.data); }
    catch (e) { console.error(e); }
  };

  const qs = () => {
    const p = new URLSearchParams();
    if (yearId) p.append("academic_year_id", yearId);
    if (startDate) p.append("start_date", startDate);
    if (endDate) p.append("end_date", endDate);
    return p.toString() ? `?${p.toString()}` : "";
  };

  const endpointMap = {
    events: "events-summary", volunteers: "volunteer-engagement",
    donations: "donations-summary", openslots: "open-slots", classfreq: "class-frequency",
  };

  const fetchReport = async () => {
    setLoading(true);
    try {
      const r = await api.get(`/reports/${endpointMap[tab]}${qs()}`);
      setReport(r.data);
    } catch (e) {
      console.error(e);
      toast.error("Failed to load report");
      setReport(null);
    }
    setLoading(false);
  };

  const dl = async (fmt) => {
    const ep = tab === "events" ? "events-summary" : "volunteer-engagement";
    try {
      const r = await api.get(`/reports/${ep}.${fmt}${qs()}`, { responseType: "blob" });
      const blob = new Blob([r.data], { type: fmt === "pdf" ? "application/pdf" : "text/csv" });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a"); a.href = url;
      a.download = `lbb_${ep}_${new Date().toISOString().slice(0, 10)}.${fmt}`;
      document.body.appendChild(a); a.click(); a.remove();
      window.URL.revokeObjectURL(url);
      toast.success(`${fmt.toUpperCase()} downloaded`);
    } catch (e) { toast.error(`Download failed`); }
  };

  const loadLegacy = async (ep, setter) => {
    setLoadingLeg(true);
    try {
      const p = {};
      if (startDate) p.start_date = startDate;
      if (endDate) p.end_date = endDate;
      const r = await api.get(`/reports/${ep}`, { params: p });
      setter(r.data);
    } catch (e) { toast.error("Failed to load"); setter(null); }
    setLoadingLeg(false);
  };

  const dlLegacy = async (ep, fn) => {
    try {
      const p = new URLSearchParams({ format: "csv" });
      if (startDate) p.set("start_date", startDate);
      if (endDate) p.set("end_date", endDate);
      const r = await api.get(`/reports/${ep}?${p.toString()}`, { responseType: "blob" });
      const blob = new Blob([r.data], { type: "text/csv" });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a"); a.href = url; a.download = fn;
      document.body.appendChild(a); a.click(); a.remove();
      window.URL.revokeObjectURL(url);
    } catch (e) { toast.error("CSV export failed"); }
  };

  const tabs = [
    { id: "events", label: "Events", icon: Calendar },
    { id: "volunteers", label: "Volunteers", icon: Users },
    { id: "donations", label: "Donations", icon: DollarSign },
    { id: "openslots", label: "Open Slots", icon: BookOpen },
    { id: "classfreq", label: "Class Frequency", icon: BarChart3 },
    { id: "raw", label: "Raw Export", icon: Download },
  ];

  const showFilters = tab !== "raw";
  const showDl = tab === "events" || tab === "volunteers";

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <BarChart3 size={28} /><span>Reports and Analytics</span>
          </h1>
          <p className="text-gray-500 mt-1">Program performance insights</p>
        </div>
        {showFilters && <button onClick={fetchReport} className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          <RefreshCw size={16} /><span>Refresh</span>
        </button>}
      </div>

      <div className="border-b border-gray-200">
        <nav className="flex space-x-4 overflow-x-auto">
          {tabs.map(t => (
            <button key={t.id} onClick={() => { setTab(t.id); setReport(null); }}
              className={`pb-3 px-1 border-b-2 text-sm font-medium transition flex items-center space-x-1 whitespace-nowrap ${tab === t.id ? "border-blue-600 text-blue-600" : "border-transparent text-gray-500 hover:text-gray-700"}`}>
              <t.icon size={16} /><span>{t.label}</span>
            </button>
          ))}
        </nav>
      </div>

      {showFilters && (
        <div className="card flex flex-wrap items-end gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Academic Year</label>
            <select value={yearId} onChange={e => setYearId(e.target.value)} className="input-field w-48">
              <option value="">All years</option>
              {years.map(y => <option key={y.id} value={y.id}>{y.name}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Start</label>
            <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} className="input-field w-40" />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">End</label>
            <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)} className="input-field w-40" />
          </div>
          <div className="flex-1" />
          {showDl && <>
            <button onClick={() => dl("csv")} className="flex items-center space-x-2 px-3 py-2 text-sm bg-green-600 text-white rounded-lg hover:bg-green-700">
              <Download size={16} /><span>CSV</span>
            </button>
            <button onClick={() => dl("pdf")} className="flex items-center space-x-2 px-3 py-2 text-sm bg-red-600 text-white rounded-lg hover:bg-red-700">
              <FileText size={16} /><span>PDF</span>
            </button>
          </>}
        </div>
      )}

      {loading ? <Spinner /> : !report && tab !== "raw" ? <Empty /> : null}

      {tab === "events" && report && <EventsTab r={report} />}
      {tab === "volunteers" && report && <VolunteersTab r={report} />}
      {tab === "donations" && report && <DonationsTab r={report} />}
      {tab === "openslots" && report && <OpenSlotsTab r={report} />}
      {tab === "classfreq" && report && <ClassFreqTab r={report} />}
      {tab === "raw" && <RawTab sd={startDate} ed={endDate} setSd={setStartDate} setEd={setEndDate}
        mvp2={mvp2} att={attendance} ll={loadingLeg}
        loadMvp2={() => loadLegacy("mvp2", setMvp2)}
        loadAtt={() => loadLegacy("attendance", setAttendance)}
        dlMvp2={() => dlLegacy("mvp2", "lbbs-mvp2.csv")}
        dlAtt={() => dlLegacy("attendance", "lbbs-attendance.csv")} />}
    </div>
  );
}

function EventsTab({ r }) {
  const { kpis, by_status = [], by_month = [], by_district = [], top_schools = [] } = r;
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi icon={Calendar} label="Total Events" value={kpis.total_events} c="blue" />
        <Kpi icon={TrendingUp} label="Fill Rate" value={`${kpis.fill_rate_pct}%`} c="green" />
        <Kpi icon={Users} label="Students Served" value={(kpis.total_students_served || 0).toLocaleString()} c="purple" />
        <Kpi icon={SchoolIcon} label="Schools" value={kpis.schools_participating} c="orange" />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Chart title="Events by Status">{by_status.length > 0 ? <ResponsiveContainer width="100%" height={260}><PieChart><Pie data={by_status} dataKey="count" nameKey="status" cx="50%" cy="50%" outerRadius={85} label={({ status, count }) => `${status}: ${count}`}>{by_status.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}</Pie><Tooltip /></PieChart></ResponsiveContainer> : <NoData />}</Chart>
        <Chart title="Events by Month">{by_month.length > 0 ? <ResponsiveContainer width="100%" height={260}><LineChart data={by_month}><CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" /><XAxis dataKey="month" fontSize={11} /><YAxis fontSize={11} /><Tooltip /><Line type="monotone" dataKey="events" stroke="#1F4E79" strokeWidth={2} /></LineChart></ResponsiveContainer> : <NoData />}</Chart>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Chart title="By District">{by_district.length > 0 ? <ResponsiveContainer width="100%" height={260}><BarChart data={by_district} layout="vertical"><CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" /><XAxis type="number" fontSize={11} /><YAxis type="category" dataKey="district" fontSize={11} width={120} /><Tooltip /><Bar dataKey="events" fill="#2E86AB" /></BarChart></ResponsiveContainer> : <NoData />}</Chart>
        <Chart title="Top Schools">{top_schools.length > 0 ? <ResponsiveContainer width="100%" height={260}><BarChart data={top_schools} layout="vertical"><CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" /><XAxis type="number" fontSize={11} /><YAxis type="category" dataKey="school" fontSize={10} width={140} /><Tooltip /><Bar dataKey="events" fill="#A23B72" /></BarChart></ResponsiveContainer> : <NoData />}</Chart>
      </div>
    </div>
  );
}

function VolunteersTab({ r }) {
  const { kpis, signups_by_month = [], top_volunteers = [], by_district = [] } = r;
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi icon={Users} label="Active Volunteers" value={kpis.total_active_volunteers} c="blue" />
        <Kpi icon={TrendingUp} label="Participation" value={`${kpis.participation_rate_pct}%`} c="green" />
        <Kpi icon={Calendar} label="Total Signups" value={kpis.total_signups} c="purple" />
        <Kpi icon={BarChart3} label="Avg/Volunteer" value={kpis.avg_events_per_volunteer} c="orange" />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Chart title="Signups by Month">{signups_by_month.length > 0 ? <ResponsiveContainer width="100%" height={260}><LineChart data={signups_by_month}><CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" /><XAxis dataKey="month" fontSize={11} /><YAxis fontSize={11} /><Tooltip /><Line type="monotone" dataKey="signups" stroke="#1F4E79" strokeWidth={2} /></LineChart></ResponsiveContainer> : <NoData />}</Chart>
        <Chart title="By District">{by_district.length > 0 ? <ResponsiveContainer width="100%" height={260}><BarChart data={by_district} layout="vertical"><CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" /><XAxis type="number" fontSize={11} /><YAxis type="category" dataKey="district" fontSize={11} width={120} /><Tooltip /><Bar dataKey="signups" fill="#2E86AB" /></BarChart></ResponsiveContainer> : <NoData />}</Chart>
      </div>
      <DataTable title="Top 10 Volunteers" cols={["Rank", "Name", "Events"]}
        rows={top_volunteers.map((v, i) => [i + 1, v.name, v.events_signed_up])} />
    </div>
  );
}

function DonationsTab({ r }) {
  const { kpis, by_kind = [], by_month = [], top_donors = [] } = r;
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <Kpi icon={DollarSign} label="Total Amount" value={`$${(kpis.total_amount || 0).toLocaleString()}`} c="green" />
        <Kpi icon={Users} label="Unique Donors" value={kpis.unique_donors} c="blue" />
        <Kpi icon={FileText} label="Letters Pending" value={kpis.letters_pending} c="orange" />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Chart title="Donations by Type">{by_kind.length > 0 ? <ResponsiveContainer width="100%" height={260}><PieChart><Pie data={by_kind} dataKey="amount" nameKey="kind" cx="50%" cy="50%" outerRadius={85} label={({ kind, amount }) => `${kind}: $${amount}`}>{by_kind.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}</Pie><Tooltip /></PieChart></ResponsiveContainer> : <NoData />}</Chart>
        <Chart title="Donations by Month">{by_month.length > 0 ? <ResponsiveContainer width="100%" height={260}><BarChart data={by_month}><CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" /><XAxis dataKey="month" fontSize={11} /><YAxis fontSize={11} /><Tooltip /><Bar dataKey="amount" fill="#2E7D32" /></BarChart></ResponsiveContainer> : <NoData />}</Chart>
      </div>
      <DataTable title="Top Donors" cols={["Rank", "Donor", "Total"]}
        rows={top_donors.map((d, i) => [i + 1, d.donor, `$${d.total.toLocaleString()}`])} />
    </div>
  );
}

function OpenSlotsTab({ r }) {
  const evts = r.events || [];
  return (
    <div className="space-y-4">
      <div className="card"><p className="text-2xl font-bold text-orange-600">{r.total_events_with_open_slots}</p>
        <p className="text-sm text-gray-500">Events with unfilled slots</p></div>
      <DataTable title="Events Needing Volunteers" cols={["Date", "Status", "School", "Signups", "Unfilled"]}
        rows={evts.map(e => [e.event_date, e.status, e.school, e.volunteer_signups, e.unfilled_slots])} />
    </div>
  );
}

function ClassFreqTab({ r }) {
  const cls = r.classes || [];
  return (
    <div className="space-y-4">
      <div className="card"><p className="text-2xl font-bold text-blue-600">{r.total_classes}</p>
        <p className="text-sm text-gray-500">Life Skills Classes</p></div>
      {cls.length > 0 && <Chart title="Class Frequency"><ResponsiveContainer width="100%" height={Math.max(200, cls.length * 35)}><BarChart data={cls} layout="vertical"><CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" /><XAxis type="number" fontSize={11} /><YAxis type="category" dataKey="class_name" fontSize={10} width={160} /><Tooltip /><Bar dataKey="times_scheduled" fill="#6A4C93" /></BarChart></ResponsiveContainer></Chart>}
      <DataTable title="All Classes" cols={["Class", "Lead", "Times Taught", "Max Students", "Take-Home Items"]}
        rows={cls.map(c => [c.class_name, c.lead_volunteer, c.times_scheduled, c.max_students || "N/A", c.take_home_items || "None"])} />
    </div>
  );
}

function RawTab({ sd, ed, setSd, setEd, mvp2, att, ll, loadMvp2, loadAtt, dlMvp2, dlAtt }) {
  return (
    <div className="space-y-6">
      <div className="card flex flex-wrap gap-4 items-end">
        <div><label className="block text-xs font-medium text-gray-700 mb-1">Start</label>
          <input type="date" value={sd} onChange={e => setSd(e.target.value)} className="input-field" /></div>
        <div><label className="block text-xs font-medium text-gray-700 mb-1">End</label>
          <input type="date" value={ed} onChange={e => setEd(e.target.value)} className="input-field" /></div>
      </div>
      <div className="card space-y-3">
        <h2 className="text-lg font-semibold">MVP2 Aggregate</h2>
        <div className="flex gap-3">
          <button onClick={loadMvp2} disabled={ll} className="btn-primary inline-flex items-center gap-2">
            {ll ? <Loader2 className="animate-spin" size={18} /> : <RefreshCw size={18} />} Load</button>
          <button onClick={dlMvp2} className="btn-secondary inline-flex items-center gap-2"><Download size={18} /> CSV</button>
        </div>
        {mvp2 && <pre className="bg-gray-50 rounded-lg p-4 text-sm overflow-x-auto">{JSON.stringify(mvp2, null, 2)}</pre>}
      </div>
      <div className="card space-y-3">
        <h2 className="text-lg font-semibold">Event Attendance</h2>
        <div className="flex gap-3">
          <button onClick={loadAtt} disabled={ll} className="btn-primary inline-flex items-center gap-2">
            {ll ? <Loader2 className="animate-spin" size={18} /> : <RefreshCw size={18} />} Load</button>
          <button onClick={dlAtt} className="btn-secondary inline-flex items-center gap-2"><Download size={18} /> CSV</button>
        </div>
        {att && <pre className="bg-gray-50 rounded-lg p-4 text-sm overflow-x-auto">{JSON.stringify(att, null, 2)}</pre>}
      </div>
    </div>
  );
}

// Reusable components
function Kpi({ icon: Icon, label, value, c }) {
  const bg = { blue: "bg-blue-50 text-blue-700", green: "bg-green-50 text-green-700", purple: "bg-purple-50 text-purple-700", orange: "bg-orange-50 text-orange-700" };
  return (<div className="card"><div className={`inline-flex p-2 rounded-lg ${bg[c]} mb-2`}><Icon size={20} /></div>
    <p className="text-2xl font-bold text-gray-900">{value}</p><p className="text-sm text-gray-500">{label}</p></div>);
}
function Chart({ title, children }) { return (<div className="card"><h3 className="font-semibold text-gray-900 mb-3">{title}</h3>{children}</div>); }
function DataTable({ title, cols, rows }) {
  return (<div className="card"><h3 className="font-semibold text-gray-900 mb-3">{title}</h3><div className="overflow-x-auto">
    <table className="w-full text-sm"><thead className="bg-gray-50"><tr>{cols.map((c, i) => <th key={i} className="px-3 py-2 text-left font-medium text-gray-700">{c}</th>)}</tr></thead>
    <tbody>{rows.length > 0 ? rows.map((row, i) => <tr key={i} className="border-b hover:bg-gray-50">{row.map((cell, j) => <td key={j} className="px-3 py-2">{cell}</td>)}</tr>) :
      <tr><td colSpan={cols.length} className="px-3 py-6 text-center text-gray-500">No data</td></tr>}</tbody></table></div></div>);
}
function Spinner() { return (<div className="flex items-center justify-center py-20"><div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600"></div></div>); }
function Empty() { return (<div className="card text-center py-12 text-gray-500"><BarChart3 className="mx-auto mb-3 text-gray-300" size={48} /><p>No data available. Try adjusting filters or loading the report.</p></div>); }
function NoData() { return (<div className="flex items-center justify-center h-48 text-gray-400 text-sm">No data for this chart</div>); }
