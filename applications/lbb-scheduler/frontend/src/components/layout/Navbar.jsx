/**
 * Navbar Component — Role-Based Navigation
 * ============================================
 */

import { Link, useLocation } from "react-router-dom";
import { User, HelpCircle } from "lucide-react";
import { useAuth } from "../../hooks/useAuth";
import {
  LayoutDashboard,
  Calendar,
  School,
  Users,
  BarChart3,
  ClipboardList,
  DollarSign,
  LogOut,
  Menu,
  X,
  Shield,
} from "lucide-react";
import { useState } from "react";

export default function Navbar() {
  const { user, isAuthenticated, logout } = useAuth();
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const getNavItems = () => {
    if (!isAuthenticated) return [];

    const role = user?.role;

    if (role === "lbb_admin" || role === "it_support") {
      const items = [
        { label: "Dashboard", path: "/dashboard", icon: LayoutDashboard },
        { label: "Users", path: "/admin/users", icon: Shield },
        { label: "Events", path: "/admin/events", icon: Calendar },
        { label: "Schools", path: "/admin/schools", icon: School },
        { label: "Volunteers", path: "/admin/volunteers", icon: Users },
        { label: "Donations", path: "/admin/donations", icon: DollarSign },
        { label: "Surveys", path: "/admin/surveys", icon: ClipboardList },
      ];
      if (role === "lbb_admin") {
        items.push({ label: "Reports", path: "/admin/reports", icon: BarChart3 });
        // Add to ALL roles (put before the role-specific items)
        items.push({ label: "My Profile", path: "/profile", icon: User });
        items.push({ label: "Help", path: "/help", icon: HelpCircle });
        items.push({ label: "Help", path: "/help", icon: HelpCircle });
      }
      return items;
    }

    if (role === "school_admin") {
      return [
        { label: "Dashboard", path: "/dashboard", icon: LayoutDashboard },
        { label: "Register for Event", path: "/school/register", icon: Calendar },
        { label: "Our Schedule", path: "/school/schedule", icon: ClipboardList },
      ];
    }

    if (role === "volunteer") {
      return [
        { label: "Dashboard", path: "/dashboard", icon: LayoutDashboard },
        { label: "My Profile", path: "/volunteer/profile", icon: User },
        { label: "Browse Events", path: "/volunteer/events", icon: Calendar },
        { label: "My Schedule", path: "/volunteer/schedule", icon: ClipboardList },
        { label: "My Classes", path: "/volunteer/classes", icon: School },
      ];
    }

    return [];
  };

  const navItems = getNavItems();
  const isActive = (path) => location.pathname === path;

  return (
    <nav className="bg-white border-b border-gray-200 shadow-sm">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link to="/" className="flex items-center space-x-2">
            <span className="text-xl font-bold text-lbb-primary">
              LBB Scheduler
            </span>
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center space-x-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className={`flex items-center space-x-1 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                    isActive(item.path)
                      ? "bg-blue-50 text-lbb-primary"
                      : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
                  }`}
                >
                  <Icon size={16} />
                  <span>{item.label}</span>
                </Link>
              );
            })}
          </div>

          {/* Auth Actions */}
          <div className="hidden md:flex items-center space-x-3">
            {isAuthenticated ? (
              <div className="flex items-center space-x-3">
                <span className="text-sm text-gray-600">
                  {user?.first_name} ({user?.role?.replace("_", " ")})
                </span>
                <button
                  onClick={logout}
                  className="flex items-center space-x-1 text-sm text-gray-500 hover:text-red-600 transition-colors"
                >
                  <LogOut size={16} />
                  <span>Logout</span>
                </button>
              </div>
            ) : (
              <div className="flex items-center space-x-2">
                <Link to="/login" className="btn-secondary text-sm py-1.5">
                  Login
                </Link>
                <Link to="/register" className="btn-primary text-sm py-1.5">
                  Register
                </Link>
              </div>
            )}
          </div>

          {/* Mobile menu toggle */}
          <button
            className="md:hidden p-2"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          >
            {mobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>

        {/* Mobile Navigation */}
        {mobileMenuOpen && (
          <div className="md:hidden pb-4 border-t border-gray-100 mt-2 pt-2">
            {navItems.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  onClick={() => setMobileMenuOpen(false)}
                  className={`flex items-center space-x-2 px-3 py-2 rounded-lg text-sm ${
                    isActive(item.path)
                      ? "bg-blue-50 text-lbb-primary"
                      : "text-gray-600"
                  }`}
                >
                  <Icon size={16} />
                  <span>{item.label}</span>
                </Link>
              );
            })}
            {isAuthenticated && (
              <button
                onClick={() => {
                  logout();
                  setMobileMenuOpen(false);
                }}
                className="flex items-center space-x-2 px-3 py-2 text-sm text-red-600 w-full"
              >
                <LogOut size={16} />
                <span>Logout</span>
              </button>
            )}
          </div>
        )}
      </div>
    </nav>
  );
}
