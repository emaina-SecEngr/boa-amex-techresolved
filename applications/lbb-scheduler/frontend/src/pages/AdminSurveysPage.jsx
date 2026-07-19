/**
 * Admin Surveys Page — Survey Management
 * =========================================
 * Allows LBB admins to:
 * - Enter volunteer, student, and school surveys
 * - View submitted surveys by type and academic year
 *
 * ConOps 6.9: Survey data collection
 */

import { useState, useEffect, useCallback } from "react";
import {
  ClipboardList,
  Plus,
  ChevronDown,
  ChevronUp,
  RefreshCw,
  Users,
  GraduationCap,
  School,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

// ── Survey Type Tabs ──
function SurveyTabs({ activeTab, onTabChange, counts }) {
  const tabs = [
    { id: "volunteer", label: "Volunteer Surveys", icon: Users, color: "text-blue-600", count: counts.volunteer },
    { id: "student", label: "Student Surveys", icon: GraduationCap, color: "text-green-600", count: counts.student },
    { id: "school", label: "School Surveys", icon: School, color: "text-purple-600", count: counts.school },
  ];

  return (
    <div className="flex space-x-1 bg-gray-100 rounded-lg p-1">
      {tabs.map((tab) => {
        const Icon = tab.icon;
        return (
          <button
            key={tab.id}
            onClick={() => onTabChange(tab.id)}
            className={`flex items-center space-x-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors flex-1 justify-center ${activeTab === tab.id
              ? "bg-white shadow text-gray-900"
              : "text-gray-500 hover:text-gray-700"
              }`}
          >
            <Icon size={16} className={activeTab === tab.id ? tab.color : ""} />
            <span>{tab.label}</span>
            <span className={`px-1.5 py-0.5 rounded-full text-xs ${activeTab === tab.id ? "bg-blue-100 text-blue-700" : "bg-gray-200 text-gray-600"
              }`}>
              {tab.count}
            </span>
          </button>
        );
      })}
    </div>
  );
}

// ── Enter Volunteer Survey Form ──
function VolunteerSurveyForm({ years, onCreated }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [form, setForm] = useState({
    academic_year_id: "",
    q1_participate_next_year: "",
    q2_recruit_contacts: "",
    q3_time_feedback: "",
    q4_take_home_items: "",
    q5_hands_on_satisfaction: "",
    q6_comments: "",
  });

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async () => {
    if (!form.academic_year_id) {
      toast.error("Please select an academic year");
      return;
    }
    setIsSubmitting(true);
    try {
      await api.post("/surveys/volunteer", form);
      toast.success("Volunteer survey submitted!");
      setForm({ academic_year_id: "", q1_participate_next_year: "", q2_recruit_contacts: "", q3_time_feedback: "", q4_take_home_items: "", q5_hands_on_satisfaction: "", q6_comments: "" });
      setIsOpen(false);
      onCreated();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to submit survey");
    }
    setIsSubmitting(false);
  };

  return (
    <div className="card">
      <button onClick={() => setIsOpen(!isOpen)} className="flex items-center justify-between w-full">
        <div className="flex items-center space-x-2">
          <Plus size={18} className="text-blue-600" />
          <span className="font-semibold text-gray-900">Enter Volunteer Survey</span>
        </div>
        {isOpen ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>
      {isOpen && (
        <div className="mt-4 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Academic Year *</label>
            <select name="academic_year_id" value={form.academic_year_id} onChange={handleChange} className="input-field">
              <option value="">Select year...</option>
              {years.map((y) => <option key={y.id} value={y.id}>{y.name}</option>)}
            </select>
          </div>
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Participate next year?</label>
              <select name="q1_participate_next_year" value={form.q1_participate_next_year} onChange={handleChange} className="input-field">
                <option value="">Select...</option>
                <option value="yes">Yes</option>
                <option value="no">No</option>
                <option value="maybe">Maybe</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Time feedback</label>
              <select name="q3_time_feedback" value={form.q3_time_feedback} onChange={handleChange} className="input-field">
                <option value="">Select...</option>
                <option value="too_short">Too Short</option>
                <option value="just_right">Just Right</option>
                <option value="too_long">Too Long</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Take-home items useful?</label>
              <select name="q4_take_home_items" value={form.q4_take_home_items} onChange={handleChange} className="input-field">
                <option value="">Select...</option>
                <option value="yes">Yes</option>
                <option value="no">No</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Recruit contacts?</label>
              <input name="q2_recruit_contacts" value={form.q2_recruit_contacts} onChange={handleChange} className="input-field" placeholder="I can bring 3 colleagues" />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Hands-on satisfaction</label>
            <input name="q5_hands_on_satisfaction" value={form.q5_hands_on_satisfaction} onChange={handleChange} className="input-field" placeholder="Students were very engaged" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Additional comments</label>
            <textarea name="q6_comments" value={form.q6_comments} onChange={handleChange} className="input-field" rows={2} placeholder="Any feedback..." />
          </div>
          <button onClick={handleSubmit} disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? "Submitting..." : "Submit Survey"}
          </button>
        </div>
      )}
    </div>
  );
}

// ── Enter Student Survey Form ──
function StudentSurveyForm({ years, onCreated }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [form, setForm] = useState({
    academic_year_id: "",
    q1_learned_new_skill: "",
    q2_speaker_engaging: "",
    q3_share_with_family: "",
    q4_sessions_attended: "",
    q5_favorite_session: "",
    q6_improvement_suggestions: "",
  });

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async () => {
    if (!form.academic_year_id) {
      toast.error("Please select an academic year");
      return;
    }
    setIsSubmitting(true);
    try {
      await api.post("/surveys/student", {
        ...form,
        q4_sessions_attended: form.q4_sessions_attended || undefined,
      });
      toast.success("Student survey entered!");
      setForm({ academic_year_id: "", q1_learned_new_skill: "", q2_speaker_engaging: "", q3_share_with_family: "", q4_sessions_attended: "", q5_favorite_session: "", q6_improvement_suggestions: "" });
      setIsOpen(false);
      onCreated();
    } catch (error) {
      const detail = error.response?.data?.detail;

      if (Array.isArray(detail)) {
        const message = detail.map(err => err.msg).join(", ");
        toast.error(message);
      } else {
        toast.error(detail || "Failed to enter survey");
      }
    }
    setIsSubmitting(false);
  };

  return (
    <div className="card">
      <button onClick={() => setIsOpen(!isOpen)} className="flex items-center justify-between w-full">
        <div className="flex items-center space-x-2">
          <Plus size={18} className="text-green-600" />
          <span className="font-semibold text-gray-900">Enter Student Survey (from paper)</span>
        </div>
        {isOpen ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>
      {isOpen && (
        <div className="mt-4 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Academic Year *</label>
            <select name="academic_year_id" value={form.academic_year_id} onChange={handleChange} className="input-field">
              <option value="">Select year...</option>
              {years.map((y) => <option key={y.id} value={y.id}>{y.name}</option>)}
            </select>
          </div>
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Learned a new skill?</label>
              <select name="q1_learned_new_skill" value={form.q1_learned_new_skill} onChange={handleChange} className="input-field">
                <option value="">Select...</option>
                <option value="yes">Yes</option>
                <option value="no">No</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Speaker engaging?</label>
              <select name="q2_speaker_engaging" value={form.q2_speaker_engaging} onChange={handleChange} className="input-field">
                <option value="">Select...</option>
                <option value="very">Very</option>
                <option value="somewhat">Somewhat</option>
                <option value="not_really">Not Really</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Share with family?</label>
              <select name="q3_share_with_family" value={form.q3_share_with_family} onChange={handleChange} className="input-field">
                <option value="">Select...</option>
                <option value="yes">Yes</option>
                <option value="no">No</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Sessions attended</label>
              <input name="q4_sessions_attended" type="number" min="0" value={form.q4_sessions_attended} onChange={handleChange} className="input-field" placeholder="3" />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Favorite session</label>
            <input name="q5_favorite_session" value={form.q5_favorite_session} onChange={handleChange} className="input-field" placeholder="Financial Literacy" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Improvement suggestions</label>
            <textarea name="q6_improvement_suggestions" value={form.q6_improvement_suggestions} onChange={handleChange} className="input-field" rows={2} placeholder="More hands-on activities" />
          </div>
          <button onClick={handleSubmit} disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? "Entering..." : "Enter Student Survey"}
          </button>
        </div>
      )}
    </div>
  );
}

// ── Enter School Survey Form ──
function SchoolSurveyForm({ years, onCreated }) {
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [form, setForm] = useState({
    academic_year_id: "",
    q1_school_name: "",
    q2_role: "",
    q3_fills_gap: "",
    q4_improvements: "",
    q5_additional_comments: "",
  });

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async () => {
    if (!form.academic_year_id) {
      toast.error("Please select an academic year");
      return;
    }
    setIsSubmitting(true);
    try {
      await api.post("/surveys/school", form);
      toast.success("School survey entered!");
      setForm({ academic_year_id: "", q1_school_name: "", q2_role: "", q3_fills_gap: "", q4_improvements: "", q5_additional_comments: "" });
      setIsOpen(false);
      onCreated();
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to enter survey");
    }
    setIsSubmitting(false);
  };

  return (
    <div className="card">
      <button onClick={() => setIsOpen(!isOpen)} className="flex items-center justify-between w-full">
        <div className="flex items-center space-x-2">
          <Plus size={18} className="text-purple-600" />
          <span className="font-semibold text-gray-900">Enter School Survey</span>
        </div>
        {isOpen ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>
      {isOpen && (
        <div className="mt-4 space-y-4">
          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Academic Year *</label>
              <select name="academic_year_id" value={form.academic_year_id} onChange={handleChange} className="input-field">
                <option value="">Select year...</option>
                {years.map((y) => <option key={y.id} value={y.id}>{y.name}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">School Name</label>
              <input name="q1_school_name" value={form.q1_school_name} onChange={handleChange} className="input-field" placeholder="Tucson Magnet High" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Your Role</label>
              <input name="q2_role" value={form.q2_role} onChange={handleChange} className="input-field" placeholder="Principal" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Fills curriculum gap?</label>
              <select name="q3_fills_gap" value={form.q3_fills_gap} onChange={handleChange} className="input-field">
                <option value="">Select...</option>
                <option value="yes">Yes</option>
                <option value="no">No</option>
                <option value="somewhat">Somewhat</option>
              </select>
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Improvements suggested</label>
            <textarea name="q4_improvements" value={form.q4_improvements} onChange={handleChange} className="input-field" rows={2} placeholder="Would love more session options" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Additional comments</label>
            <textarea name="q5_additional_comments" value={form.q5_additional_comments} onChange={handleChange} className="input-field" rows={2} placeholder="Students really enjoyed it" />
          </div>
          <button onClick={handleSubmit} disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? "Entering..." : "Enter School Survey"}
          </button>
        </div>
      )}
    </div>
  );
}

// ── Main Page ──
export default function AdminSurveysPage() {
  const [activeTab, setActiveTab] = useState("volunteer");
  const [years, setYears] = useState([]);
  const [surveys, setSurveys] = useState([]);
  const [loading, setLoading] = useState(true);
  const [counts, setCounts] = useState({ volunteer: 0, student: 0, school: 0 });

  const fetchYears = useCallback(async () => {
    try {
      const response = await api.get("/events/years");
      setYears(response.data);
    } catch (error) {
      console.error("Failed to fetch years:", error);
    }
  }, []);

  const fetchSurveys = useCallback(async () => {
    setLoading(true);
    try {
      const response = await api.get(`/surveys/${activeTab}`);
      const data = response.data.surveys || response.data;
      setSurveys(Array.isArray(data) ? data : []);
      setCounts((prev) => ({ ...prev, [activeTab]: Array.isArray(data) ? data.length : 0 }));
    } catch (error) {
      console.error("Failed to fetch surveys:", error);
      setSurveys([]);
    }
    setLoading(false);
  }, [activeTab]);

  // Fetch all counts
  const fetchCounts = useCallback(async () => {
    try {
      const [vol, stu, sch] = await Promise.all([
        api.get("/surveys/volunteer").catch(() => ({ data: { total: 0 } })),
        api.get("/surveys/student").catch(() => ({ data: { total: 0 } })),
        api.get("/surveys/school").catch(() => ({ data: { total: 0 } })),
      ]);
      setCounts({
        volunteer: vol.data.total || (vol.data.surveys || []).length || 0,
        student: stu.data.total || (stu.data.surveys || []).length || 0,
        school: sch.data.total || (sch.data.surveys || []).length || 0,
      });
    } catch (error) {
      console.error("Failed to fetch counts:", error);
    }
  }, []);

  useEffect(() => {
    fetchYears();
    fetchCounts();
  }, [fetchYears, fetchCounts]);

  useEffect(() => {
    fetchSurveys();
  }, [fetchSurveys]);

  const handleRefresh = () => {
    fetchSurveys();
    fetchCounts();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <ClipboardList size={28} />
            <span>Survey Management</span>
          </h1>
          <p className="text-gray-500 mt-1">Enter and review program feedback</p>
        </div>
        <button
          onClick={handleRefresh}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Tabs */}
      <SurveyTabs activeTab={activeTab} onTabChange={setActiveTab} counts={counts} />

      {/* Entry Forms */}
      {activeTab === "volunteer" && <VolunteerSurveyForm years={years} onCreated={handleRefresh} />}
      {activeTab === "student" && <StudentSurveyForm years={years} onCreated={handleRefresh} />}
      {activeTab === "school" && <SchoolSurveyForm years={years} onCreated={handleRefresh} />}

      {/* Survey List */}
      <div className="card overflow-hidden p-0">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        ) : surveys.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <ClipboardList className="mx-auto mb-3 text-gray-300" size={48} />
            <p>No {activeTab} surveys yet</p>
          </div>
        ) : (
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">#</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Submitted</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Key Response</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Comments</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {surveys.map((survey, idx) => (
                <tr key={survey.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm text-gray-500">{idx + 1}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {new Date(survey.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-900">
                    {activeTab === "volunteer" && (survey.q1_participate_next_year ? `Next year: ${survey.q1_participate_next_year}` : "—")}
                    {activeTab === "student" && (survey.q1_learned_new_skill ? `Learned: ${survey.q1_learned_new_skill}` : "—")}
                    {activeTab === "school" && (survey.q1_school_name || "—")}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600 max-w-xs truncate">
                    {activeTab === "volunteer" && (survey.q6_comments || "—")}
                    {activeTab === "student" && (survey.q6_improvement_suggestions || "—")}
                    {activeTab === "school" && (survey.q5_additional_comments || "—")}
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
