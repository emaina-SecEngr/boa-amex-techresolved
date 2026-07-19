/**
 * ProtectedRoute Component — Route Guard
 * ==========================================
 * Wraps route components to enforce authentication and
 * role-based access control (RBAC).
 *
 * If the user is not logged in → redirect to /login
 * If the user doesn't have the right role → redirect to /dashboard
 *
 * USAGE:
 *   // Any authenticated user can access
 *   <ProtectedRoute><DashboardPage /></ProtectedRoute>
 *
 *   // Only LBB admins can access
 *   <ProtectedRoute allowedRoles={["lbb_admin"]}>
 *     <AdminPanel />
 *   </ProtectedRoute>
 *
 *   // Multiple roles allowed
 *   <ProtectedRoute allowedRoles={["lbb_admin", "school_admin"]}>
 *     <ScheduleView />
 *   </ProtectedRoute>
 */

import { Navigate } from "react-router-dom";
import { useAuth } from "../../hooks/useAuth";

export default function ProtectedRoute({ children, allowedRoles = null }) {
  const { user, loading, isAuthenticated } = useAuth();

  // Show loading spinner while checking auth state
  // (prevents a flash of the login page before redirect)
  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[50vh]">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-lbb-primary"></div>
      </div>
    );
  }

  // Not logged in → redirect to login page
  // 'replace' means the login page replaces the current history entry
  // so pressing "back" doesn't send them to the protected page again
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // Logged in but wrong role → redirect to dashboard
  if (allowedRoles && !allowedRoles.includes(user.role)) {
    return <Navigate to="/dashboard" replace />;
  }

  // All checks passed → render the protected content
  // 'children' is whatever component was wrapped inside ProtectedRoute
  return children;
}

