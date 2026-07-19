import { Routes, Route } from "react-router-dom";
import HelpPage from "./pages/HelpPage";
import ProfilePage from "./pages/ProfilePage";
import Navbar from "./components/layout/Navbar";
import ReportsPage from "./pages/ReportsPage";
import LandingPage from "./pages/LandingPage";
import LoginPage from "./pages/LoginPage";
import RegisterPage from "./pages/RegisterPage";
import ForgotPasswordPage from "./pages/ForgotPasswordPage";
import DashboardPage from "./pages/DashboardPage";
import AdminUsersPage from "./pages/AdminUsersPage";
import AdminEventsPage from "./pages/AdminEventsPage";
import AdminSchoolsPage from "./pages/AdminSchoolsPage";
import AdminVolunteersPage from "./pages/AdminVolunteersPage";
import AdminDonationsPage from "./pages/AdminDonationsPage";
import AdminSurveysPage from "./pages/AdminSurveysPage";
import AdminReportsPage from "./pages/AdminReportsPage";
import VolunteerEventsPage from "./pages/VolunteerEventsPage";
import VolunteerSchedulePage from "./pages/VolunteerSchedulePage";
import VolunteerClassesPage from "./pages/VolunteerClassesPage";
import SchoolRegisterPage from "./pages/SchoolRegisterPage";
import SchoolSchedulePage from "./pages/SchoolSchedulePage";
import NotFoundPage from "./pages/NotFoundPage";

import ProtectedRoute from "./components/auth/ProtectedRoute";

export default function App() {
  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />

      <main className="container mx-auto px-4 py-8">
        <Routes>
          {/* Public */}
          <Route path="/" element={<LandingPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/forgot-password" element={<ForgotPasswordPage />} />
          <Route path="/help" element={<HelpPage />} />
          <Route path="/profile" element={<ProtectedRoute><ProfilePage /></ProtectedRoute>} />
          {/* Protected */}
          <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
          {/* Admin */}
          <Route path="/admin/users" element={<ProtectedRoute><AdminUsersPage /></ProtectedRoute>} />
          <Route path="/admin/events" element={<ProtectedRoute><AdminEventsPage /></ProtectedRoute>} />
          <Route path="/reports" element={<ReportsPage />} />
          <Route path="/admin/schools" element={<ProtectedRoute><AdminSchoolsPage /></ProtectedRoute>} />
          <Route path="/admin/volunteers" element={<ProtectedRoute><AdminVolunteersPage /></ProtectedRoute>} />
          <Route path="/admin/donations" element={<ProtectedRoute><AdminDonationsPage /></ProtectedRoute>} />
          <Route path="/admin/surveys" element={<ProtectedRoute><AdminSurveysPage /></ProtectedRoute>} />
          <Route path="/admin/reports" element={<ProtectedRoute><AdminReportsPage /></ProtectedRoute>} />
          <Route path="/volunteer/profile" element={<ProtectedRoute><ProfilePage /></ProtectedRoute>} />
          {/* Volunteer */}
          <Route path="/volunteer/events" element={<ProtectedRoute><VolunteerEventsPage /></ProtectedRoute>} />
          <Route path="/volunteer/schedule" element={<ProtectedRoute><VolunteerSchedulePage /></ProtectedRoute>} />
          <Route path="/volunteer/classes" element={<ProtectedRoute><VolunteerClassesPage /></ProtectedRoute>} />

          {/* School Admin */}
          <Route path="/school/register" element={<ProtectedRoute><SchoolRegisterPage /></ProtectedRoute>} />
          <Route path="/school/schedule" element={<ProtectedRoute><SchoolSchedulePage /></ProtectedRoute>} />

          {/* 404 */}
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </main>
    </div>
  );
}

