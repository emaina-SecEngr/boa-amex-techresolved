/**
 * Admin Users Page — User Management & Approval
 * =================================================
 * Allows LBB admins to:
 * - View all registered users
 * - Approve pending accounts (is_active: false → true)
 * - Deactivate user accounts
 * - Filter by role and status
 *
 * ConOps 6.5.1: Admin must approve new accounts
 * ConOps 6.6.1: Admin can deactivate accounts
 */

import { useState, useEffect, useCallback } from "react";
import {
  Users,
  CheckCircle,
  XCircle,
  Clock,
  Search,
  RefreshCw,
} from "lucide-react";
import toast from "react-hot-toast";
import api from "../services/api";

export default function AdminUsersPage() {
  // ── State ──
  const [users, setUsers] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [filterRole, setFilterRole] = useState("");
  const [filterStatus, setFilterStatus] = useState("");
  const [searchTerm, setSearchTerm] = useState("");

  // ── Fetch users from API ──
  const fetchUsers = useCallback(async () => {
    setLoading(true);
    try {
      let url = "/users?page=1&per_page=50";
      if (filterRole) url += `&role=${filterRole}`;
      if (filterStatus) url += `&is_active=${filterStatus}`;

      const response = await api.get(url);
      setUsers(response.data.users);
      setTotal(response.data.total);
    } catch (error) {
      toast.error("Failed to load users");
    }
    setLoading(false);
  }, [filterRole, filterStatus]);

  // Fetch on mount and when filters change
  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  // ── Approve user ──
  const handleApprove = async (userId, username) => {
    try {
      await api.patch(`/users/${userId}`, { is_active: true });
      toast.success(`${username} approved!`);
      fetchUsers(); // Refresh the list
    } catch (error) {
      toast.error("Failed to approve user");
    }
  };

  // ── Deactivate user ──
  const handleDeactivate = async (userId, username) => {
    if (!window.confirm(`Are you sure you want to deactivate ${username}?`)) {
      return;
    }
    try {
      await api.delete(`/users/${userId}`);
      toast.success(`${username} deactivated`);
      fetchUsers();
    } catch (error) {
      toast.error("Failed to deactivate user");
    }
  };

  // ── Filter users by search term ──
  const filteredUsers = users.filter(
    (user) =>
      user.username.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.first_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.last_name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // ── Count pending approvals ──
  const pendingCount = users.filter((u) => !u.is_active).length;

  // ── Role badge colors ──
  const roleBadge = (role) => {
    const styles = {
      lbb_admin: "bg-red-100 text-red-700",
      it_support: "bg-orange-100 text-orange-700",
      school_admin: "bg-purple-100 text-purple-700",
      volunteer: "bg-blue-100 text-blue-700",
    };
    const labels = {
      lbb_admin: "LBB Admin",
      it_support: "IT Support",
      school_admin: "School Admin",
      volunteer: "Volunteer",
    };
    return (
      <span
        className={`px-2 py-1 rounded-full text-xs font-medium ${
          styles[role] || "bg-gray-100 text-gray-700"
        }`}
      >
        {labels[role] || role}
      </span>
    );
  };

  // ── Status badge ──
  const statusBadge = (isActive) => {
    if (isActive) {
      return (
        <span className="flex items-center space-x-1 text-green-600">
          <CheckCircle size={14} />
          <span className="text-xs font-medium">Active</span>
        </span>
      );
    }
    return (
      <span className="flex items-center space-x-1 text-amber-600">
        <Clock size={14} />
        <span className="text-xs font-medium">Pending</span>
      </span>
    );
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
            <Users size={28} />
            <span>User Management</span>
          </h1>
          <p className="text-gray-500 mt-1">
            {total} total users{" "}
            {pendingCount > 0 && (
              <span className="text-amber-600 font-medium">
                ({pendingCount} pending approval)
              </span>
            )}
          </p>
        </div>
        <button
          onClick={fetchUsers}
          className="flex items-center space-x-2 px-3 py-2 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <RefreshCw size={16} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Filters */}
      <div className="card">
        <div className="grid md:grid-cols-3 gap-4">
          {/* Search */}
          <div className="relative">
            <Search
              className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
              size={16}
            />
            <input
              type="text"
              placeholder="Search by name, username, or email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-field pl-9"
            />
          </div>

          {/* Role filter */}
          <select
            value={filterRole}
            onChange={(e) => setFilterRole(e.target.value)}
            className="input-field"
          >
            <option value="">All Roles</option>
            <option value="lbb_admin">LBB Admin</option>
            <option value="it_support">IT Support</option>
            <option value="school_admin">School Admin</option>
            <option value="volunteer">Volunteer</option>
          </select>

          {/* Status filter */}
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="input-field"
          >
            <option value="">All Statuses</option>
            <option value="true">Active</option>
            <option value="false">Pending Approval</option>
          </select>
        </div>
      </div>

      {/* Pending Approvals Section */}
      {pendingCount > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
          <h3 className="font-semibold text-amber-800 flex items-center space-x-2 mb-3">
            <Clock size={18} />
            <span>Pending Approvals ({pendingCount})</span>
          </h3>
          <div className="space-y-2">
            {users
              .filter((u) => !u.is_active)
              .map((user) => (
                <div
                  key={user.id}
                  className="flex items-center justify-between bg-white rounded-lg p-3 border border-amber-100"
                >
                  <div>
                    <p className="font-medium text-gray-900">
                      {user.first_name} {user.last_name}
                    </p>
                    <p className="text-sm text-gray-500">
                      {user.username} &middot; {user.email} &middot;{" "}
                      {roleBadge(user.role)}
                    </p>
                  </div>
                  <div className="flex space-x-2">
                    <button
                      onClick={() => handleApprove(user.id, user.username)}
                      className="flex items-center space-x-1 px-3 py-1.5 bg-green-600 text-white text-sm rounded-lg hover:bg-green-700"
                    >
                      <CheckCircle size={14} />
                      <span>Approve</span>
                    </button>
                    <button
                      onClick={() => handleDeactivate(user.id, user.username)}
                      className="flex items-center space-x-1 px-3 py-1.5 bg-red-50 text-red-600 text-sm rounded-lg hover:bg-red-100 border border-red-200"
                    >
                      <XCircle size={14} />
                      <span>Deny</span>
                    </button>
                  </div>
                </div>
              ))}
          </div>
        </div>
      )}

      {/* Users Table */}
      <div className="card overflow-hidden p-0">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        ) : filteredUsers.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <Users className="mx-auto mb-3 text-gray-300" size={48} />
            <p>No users found</p>
          </div>
        ) : (
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  User
                </th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Role
                </th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Status
                </th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Affiliation
                </th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Joined
                </th>
                <th className="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-gray-50">
                  {/* User info */}
                  <td className="px-4 py-3">
                    <div>
                      <p className="font-medium text-gray-900">
                        {user.first_name} {user.last_name}
                      </p>
                      <p className="text-sm text-gray-500">
                        @{user.username} &middot; {user.email}
                      </p>
                    </div>
                  </td>
                  {/* Role */}
                  <td className="px-4 py-3">{roleBadge(user.role)}</td>
                  {/* Status */}
                  <td className="px-4 py-3">{statusBadge(user.is_active)}</td>
                  {/* Affiliation */}
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {user.affiliation || "—"}
                  </td>
                  {/* Joined date */}
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {new Date(user.created_at).toLocaleDateString()}
                  </td>
                  {/* Actions */}
                  <td className="px-4 py-3 text-right">
                    {!user.is_active ? (
                      <button
                        onClick={() => handleApprove(user.id, user.username)}
                        className="text-green-600 hover:text-green-700 text-sm font-medium"
                      >
                        Approve
                      </button>
                    ) : (
                      <button
                        onClick={() =>
                          handleDeactivate(user.id, user.username)
                        }
                        className="text-red-500 hover:text-red-600 text-sm font-medium"
                      >
                        Deactivate
                      </button>
                    )}
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
