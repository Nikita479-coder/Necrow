import { useState, useEffect } from 'react';
import { ArrowLeft, Users, Plus, Shield, UserCheck, UserX, Trash2, RefreshCw, Search, Eye, Edit, Lock } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { useToast } from '../hooks/useToast';
import Navbar from '../components/Navbar';

interface StaffMember {
  id: string;
  email: string;
  username: string;
  full_name: string | null;
  role_id: string;
  role_name: string;
  is_active: boolean;
  created_at: string;
  created_by_username: string | null;
}

interface Role {
  id: string;
  name: string;
  description: string;
  permission_count: number;
}

interface Permission {
  permission_code: string;
  permission_name: string;
  category: string;
}

interface StaffPermission {
  permission_code: string;
  permission_name: string;
  category: string;
  description: string;
  has_permission: boolean;
  source: string;
}

interface UserToAdd {
  id: string;
  email: string;
  username: string;
  full_name: string | null;
}

export default function AdminStaffManagement() {
  const { profile, hasPermission } = useAuth();
  const { navigateTo } = useNavigation();
  const { showToast } = useToast();

  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [showPermissionsModal, setShowPermissionsModal] = useState(false);
  const [selectedRole, setSelectedRole] = useState<Role | null>(null);
  const [rolePermissions, setRolePermissions] = useState<Permission[]>([]);

  const [showEditPermissionsModal, setShowEditPermissionsModal] = useState(false);
  const [selectedStaff, setSelectedStaff] = useState<StaffMember | null>(null);
  const [staffPermissions, setStaffPermissions] = useState<StaffPermission[]>([]);
  const [permissionLoading, setPermissionLoading] = useState(false);

  const [userSearch, setUserSearch] = useState('');
  const [searchResults, setSearchResults] = useState<UserToAdd[]>([]);
  const [selectedUser, setSelectedUser] = useState<UserToAdd | null>(null);
  const [selectedRoleId, setSelectedRoleId] = useState('');
  const [searching, setSearching] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    if (profile?.is_admin) {
      loadData();
    }
  }, [profile]);

  const loadData = async () => {
    console.log('[Staff Management] Loading data...');
    setLoading(true);
    try {
      const [staffRes, rolesRes] = await Promise.all([
        supabase.rpc('get_all_staff'),
        supabase.rpc('get_available_roles'),
      ]);

      console.log('[Staff Management] Staff response:', staffRes);
      console.log('[Staff Management] Roles response:', rolesRes);

      if (staffRes.error) {
        console.error('[Staff Management] Staff error:', staffRes.error);
        throw staffRes.error;
      }
      if (rolesRes.error) {
        console.error('[Staff Management] Roles error:', rolesRes.error);
        throw rolesRes.error;
      }

      setStaff(staffRes.data || []);
      setRoles(rolesRes.data || []);
      console.log('[Staff Management] Loaded staff:', staffRes.data?.length, 'roles:', rolesRes.data?.length);
    } catch (error: any) {
      console.error('[Staff Management] Load error:', error);
      showToast('Failed to load staff data: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const searchUsers = async () => {
    if (!userSearch.trim()) {
      console.log('[Staff Search] Empty search term, clearing results');
      setSearchResults([]);
      return;
    }

    console.log('[Staff Search] Searching for:', userSearch);
    setSearching(true);
    try {
      const { data, error } = await supabase.rpc('admin_list_all_users', {
        p_search: userSearch,
        p_limit: 10,
        p_offset: 0,
      });

      console.log('[Staff Search] Query result:', { data, error });

      if (error) {
        console.error('[Staff Search] Query error:', error);
        throw error;
      }

      const staffIds = new Set(staff.map(s => s.id));
      console.log('[Staff Search] Existing staff IDs:', Array.from(staffIds));

      const filteredUsers: UserToAdd[] = [];

      for (const user of data || []) {
        console.log('[Staff Search] Processing user:', user);
        if (staffIds.has(user.user_id)) {
          console.log('[Staff Search] Skipping staff member:', user.user_id);
          continue;
        }

        filteredUsers.push({
          id: user.user_id,
          email: user.email || 'N/A',
          username: user.username || 'No username',
          full_name: user.full_name,
        });
      }

      console.log('[Staff Search] Final filtered users:', filteredUsers);
      setSearchResults(filteredUsers);
    } catch (error: any) {
      console.error('[Staff Search] Error:', error);
      showToast('Search failed: ' + error.message, 'error');
    } finally {
      setSearching(false);
    }
  };

  const handleAddStaff = async () => {
    if (!selectedUser || !selectedRoleId) {
      showToast('Please select a user and role', 'error');
      return;
    }

    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('create_staff_user', {
        p_user_id: selectedUser.id,
        p_role_id: selectedRoleId,
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error);

      showToast(data.message, 'success');
      setShowAddModal(false);
      setSelectedUser(null);
      setSelectedRoleId('');
      setUserSearch('');
      setSearchResults([]);
      await loadData();
    } catch (error: any) {
      showToast('Failed to add staff: ' + error.message, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleToggleActive = async (staffId: string, currentStatus: boolean) => {
    const action = currentStatus ? 'deactivate' : 'activate';
    if (!confirm(`Are you sure you want to ${action} this staff member?`)) return;

    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('toggle_staff_active', {
        p_staff_id: staffId,
        p_is_active: !currentStatus,
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error);

      showToast(data.message, 'success');
      await loadData();
    } catch (error: any) {
      showToast('Failed to update status: ' + error.message, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleUpdateRole = async (staffId: string, newRoleId: string) => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('update_staff_role', {
        p_staff_id: staffId,
        p_new_role_id: newRoleId,
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error);

      showToast(data.message, 'success');
      await loadData();
    } catch (error: any) {
      showToast('Failed to update role: ' + error.message, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeleteStaff = async (staffId: string) => {
    if (!confirm('Are you sure you want to remove this staff member? This action cannot be undone.')) return;

    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('delete_staff_member', {
        p_staff_id: staffId,
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error);

      showToast(data.message, 'success');
      await loadData();
    } catch (error: any) {
      showToast('Failed to remove staff: ' + error.message, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const viewRolePermissions = async (role: Role) => {
    try {
      const { data, error } = await supabase.rpc('get_role_permissions', {
        p_role_id: role.id,
      });

      if (error) throw error;

      setSelectedRole(role);
      setRolePermissions(data || []);
      setShowPermissionsModal(true);
    } catch (error: any) {
      showToast('Failed to load permissions: ' + error.message, 'error');
    }
  };

  const groupPermissionsByCategory = (permissions: Permission[]) => {
    return permissions.reduce((acc, perm) => {
      if (!acc[perm.category]) acc[perm.category] = [];
      acc[perm.category].push(perm);
      return acc;
    }, {} as Record<string, Permission[]>);
  };

  const groupStaffPermissionsByCategory = (permissions: StaffPermission[]) => {
    return permissions.reduce((acc, perm) => {
      if (!acc[perm.category]) acc[perm.category] = [];
      acc[perm.category].push(perm);
      return acc;
    }, {} as Record<string, StaffPermission[]>);
  };

  const editStaffPermissions = async (staff: StaffMember) => {
    setSelectedStaff(staff);
    setPermissionLoading(true);
    setShowEditPermissionsModal(true);

    try {
      const { data, error } = await supabase.rpc('get_staff_permissions_detail', {
        p_staff_id: staff.id,
      });

      if (error) throw error;

      setStaffPermissions(data || []);
    } catch (error: any) {
      showToast('Failed to load permissions: ' + error.message, 'error');
    } finally {
      setPermissionLoading(false);
    }
  };

  const toggleStaffPermission = async (permissionCode: string, currentValue: boolean) => {
    if (!selectedStaff) return;

    setPermissionLoading(true);
    try {
      const { data, error } = await supabase.rpc('set_staff_permission', {
        p_staff_id: selectedStaff.id,
        p_permission_code: permissionCode,
        p_is_granted: !currentValue,
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error);

      showToast(data.message, 'success');

      // Reload permissions
      const { data: updatedPerms, error: loadError } = await supabase.rpc('get_staff_permissions_detail', {
        p_staff_id: selectedStaff.id,
      });

      if (loadError) throw loadError;
      setStaffPermissions(updatedPerms || []);
    } catch (error: any) {
      showToast('Failed to update permission: ' + error.message, 'error');
    } finally {
      setPermissionLoading(false);
    }
  };

  if (!profile?.is_admin) {
    return (
      <div className="min-h-screen bg-[#0a0d10] text-white">
        <Navbar />
        <div className="max-w-7xl mx-auto px-4 py-12">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-red-400 mb-4">Access Denied</h1>
            <p className="text-gray-400">Only super admins can manage staff.</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0a0d10] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('admindashboard')}
          className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-6"
        >
          <ArrowLeft className="w-5 h-5" />
          <span>Back to Dashboard</span>
        </button>

        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold mb-2">Staff Management</h1>
            <p className="text-gray-400">Create and manage staff accounts with different permission levels</p>
          </div>
          <button
            onClick={() => setShowAddModal(true)}
            className="flex items-center gap-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black px-6 py-3 rounded-lg font-bold transition-all"
          >
            <Plus className="w-5 h-5" />
            Add Staff Member
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          {roles.filter(r => r.name !== 'Super Admin').map((role) => (
            <div key={role.id} className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-[#f0b90b]/10 rounded-xl flex items-center justify-center">
                    <Shield className="w-6 h-6 text-[#f0b90b]" />
                  </div>
                  <div>
                    <h3 className="text-lg font-bold text-white">{role.name}</h3>
                    <p className="text-sm text-gray-400">{role.permission_count} permissions</p>
                  </div>
                </div>
                <button
                  onClick={() => viewRolePermissions(role)}
                  className="p-2 hover:bg-gray-700 rounded-lg transition-colors"
                  title="View Permissions"
                >
                  <Eye className="w-5 h-5 text-gray-400" />
                </button>
              </div>
              <p className="text-sm text-gray-400">{role.description}</p>
              <div className="mt-4 pt-4 border-t border-gray-800">
                <p className="text-xs text-gray-500">
                  {staff.filter(s => s.role_id === role.id).length} staff members
                </p>
              </div>
            </div>
          ))}
        </div>

        <div className="bg-[#1a1d24] rounded-xl border border-gray-800">
          <div className="p-6 border-b border-gray-800">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-bold flex items-center gap-2">
                <Users className="w-5 h-5 text-[#f0b90b]" />
                Staff Members ({staff.length})
              </h2>
              <button
                onClick={loadData}
                disabled={loading}
                className="flex items-center gap-2 px-4 py-2 bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
              >
                <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
                Refresh
              </button>
            </div>
          </div>

          {loading ? (
            <div className="p-12 text-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b] mx-auto"></div>
              <p className="text-gray-400 mt-4">Loading staff...</p>
            </div>
          ) : staff.length === 0 ? (
            <div className="p-12 text-center">
              <Users className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <h3 className="text-xl font-bold text-white mb-2">No Staff Members</h3>
              <p className="text-gray-400">Click "Add Staff Member" to create your first staff account.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-[#0b0e11]">
                  <tr>
                    <th className="text-left py-4 px-6 text-sm font-medium text-gray-400">User</th>
                    <th className="text-left py-4 px-6 text-sm font-medium text-gray-400">Role</th>
                    <th className="text-center py-4 px-6 text-sm font-medium text-gray-400">Status</th>
                    <th className="text-left py-4 px-6 text-sm font-medium text-gray-400">Created</th>
                    <th className="text-center py-4 px-6 text-sm font-medium text-gray-400">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {staff.map((member) => (
                    <tr key={member.id} className="border-b border-gray-800/50 hover:bg-[#0b0e11] transition-colors">
                      <td className="py-4 px-6">
                        <div>
                          <div className="text-white font-medium">{member.username}</div>
                          <div className="text-sm text-gray-400">{member.email}</div>
                          {member.full_name && (
                            <div className="text-xs text-gray-500">{member.full_name}</div>
                          )}
                        </div>
                      </td>
                      <td className="py-4 px-6">
                        <select
                          value={member.role_id}
                          onChange={(e) => handleUpdateRole(member.id, e.target.value)}
                          disabled={actionLoading}
                          className="bg-[#0b0e11] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b] transition-colors"
                        >
                          {roles.filter(r => r.name !== 'Super Admin').map((role) => (
                            <option key={role.id} value={role.id}>
                              {role.name}
                            </option>
                          ))}
                        </select>
                      </td>
                      <td className="py-4 px-6 text-center">
                        <span className={`inline-flex items-center gap-1 px-3 py-1 rounded-lg border text-sm font-medium ${
                          member.is_active
                            ? 'bg-green-500/10 text-green-400 border-green-500/30'
                            : 'bg-red-500/10 text-red-400 border-red-500/30'
                        }`}>
                          {member.is_active ? (
                            <>
                              <UserCheck className="w-4 h-4" />
                              Active
                            </>
                          ) : (
                            <>
                              <UserX className="w-4 h-4" />
                              Inactive
                            </>
                          )}
                        </span>
                      </td>
                      <td className="py-4 px-6">
                        <div className="text-sm text-gray-300">
                          {new Date(member.created_at).toLocaleDateString()}
                        </div>
                        {member.created_by_username && (
                          <div className="text-xs text-gray-500">
                            by {member.created_by_username}
                          </div>
                        )}
                      </td>
                      <td className="py-4 px-6">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => editStaffPermissions(member)}
                            disabled={actionLoading}
                            className="p-2 hover:bg-[#f0b90b]/10 text-[#f0b90b] rounded-lg transition-colors"
                            title="Edit Permissions"
                          >
                            <Edit className="w-5 h-5" />
                          </button>
                          <button
                            onClick={() => handleToggleActive(member.id, member.is_active)}
                            disabled={actionLoading}
                            className={`p-2 rounded-lg transition-colors ${
                              member.is_active
                                ? 'hover:bg-red-500/10 text-red-400'
                                : 'hover:bg-green-500/10 text-green-400'
                            }`}
                            title={member.is_active ? 'Deactivate' : 'Activate'}
                          >
                            {member.is_active ? <UserX className="w-5 h-5" /> : <UserCheck className="w-5 h-5" />}
                          </button>
                          <button
                            onClick={() => handleDeleteStaff(member.id)}
                            disabled={actionLoading}
                            className="p-2 hover:bg-red-500/10 text-red-400 rounded-lg transition-colors"
                            title="Remove Staff"
                          >
                            <Trash2 className="w-5 h-5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {showAddModal && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-xl border border-gray-800 max-w-lg w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-800">
              <h2 className="text-2xl font-bold text-white">Add Staff Member</h2>
              <p className="text-gray-400 text-sm mt-1">Search for a user and assign them a role</p>
            </div>

            <div className="p-6 space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Search User</label>
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                    <input
                      type="text"
                      value={userSearch}
                      onChange={(e) => setUserSearch(e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && searchUsers()}
                      placeholder="Search by username, email, or name..."
                      className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg pl-10 pr-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                    />
                  </div>
                  <button
                    onClick={searchUsers}
                    disabled={searching}
                    className="px-4 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg font-medium transition-colors disabled:opacity-50"
                  >
                    {searching ? 'Searching...' : 'Search'}
                  </button>
                </div>
              </div>

              {searchResults.length > 0 && (
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2">Select User</label>
                  <div className="space-y-2 max-h-48 overflow-y-auto">
                    {searchResults.map((user) => (
                      <button
                        key={user.id}
                        onClick={() => setSelectedUser(user)}
                        className={`w-full text-left p-3 rounded-lg border transition-colors ${
                          selectedUser?.id === user.id
                            ? 'bg-[#f0b90b]/10 border-[#f0b90b] text-white'
                            : 'bg-[#0b0e11] border-gray-700 text-gray-300 hover:border-gray-600'
                        }`}
                      >
                        <div className="font-medium">{user.username}</div>
                        <div className="text-sm text-gray-400">{user.email}</div>
                        {user.full_name && (
                          <div className="text-xs text-gray-500">{user.full_name}</div>
                        )}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {selectedUser && (
                <div className="p-4 bg-[#0b0e11] rounded-lg border border-[#f0b90b]/30">
                  <p className="text-sm text-gray-400 mb-1">Selected User:</p>
                  <p className="text-white font-medium">{selectedUser.username}</p>
                  <p className="text-sm text-gray-400">{selectedUser.email}</p>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Assign Role</label>
                <select
                  value={selectedRoleId}
                  onChange={(e) => setSelectedRoleId(e.target.value)}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                >
                  <option value="">Select a role...</option>
                  {roles.filter(r => r.name !== 'Super Admin').map((role) => (
                    <option key={role.id} value={role.id}>
                      {role.name} - {role.description}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex gap-3 pt-4">
                <button
                  onClick={() => {
                    setShowAddModal(false);
                    setSelectedUser(null);
                    setSelectedRoleId('');
                    setUserSearch('');
                    setSearchResults([]);
                  }}
                  className="flex-1 px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleAddStaff}
                  disabled={!selectedUser || !selectedRoleId || actionLoading}
                  className="flex-1 px-6 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg font-bold transition-colors disabled:opacity-50"
                >
                  {actionLoading ? 'Adding...' : 'Add Staff Member'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showPermissionsModal && selectedRole && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-xl border border-gray-800 max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-800">
              <h2 className="text-2xl font-bold text-white">{selectedRole.name} Permissions</h2>
              <p className="text-gray-400 text-sm mt-1">{selectedRole.description}</p>
            </div>

            <div className="p-6">
              {Object.entries(groupPermissionsByCategory(rolePermissions)).map(([category, perms]) => (
                <div key={category} className="mb-6">
                  <h3 className="text-sm font-bold text-[#f0b90b] uppercase tracking-wider mb-3">
                    {category}
                  </h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                    {perms.map((perm) => (
                      <div
                        key={perm.permission_code}
                        className="flex items-center gap-2 p-3 bg-[#0b0e11] rounded-lg border border-gray-800"
                      >
                        <Shield className="w-4 h-4 text-green-400 flex-shrink-0" />
                        <span className="text-white text-sm">{perm.permission_name}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}

              {rolePermissions.length === 0 && (
                <div className="text-center py-8">
                  <p className="text-gray-400">No permissions assigned to this role.</p>
                </div>
              )}

              <div className="flex justify-end pt-4 border-t border-gray-800">
                <button
                  onClick={() => {
                    setShowPermissionsModal(false);
                    setSelectedRole(null);
                    setRolePermissions([]);
                  }}
                  className="px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showEditPermissionsModal && selectedStaff && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-xl border border-gray-800 max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-800">
              <div className="flex items-start justify-between">
                <div>
                  <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                    <Lock className="w-6 h-6 text-[#f0b90b]" />
                    Edit Permissions: {selectedStaff.username}
                  </h2>
                  <p className="text-gray-400 text-sm mt-1">
                    Base Role: <span className="text-[#f0b90b]">{selectedStaff.role_name}</span>
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    Toggle permissions to grant or revoke access. Custom permissions override role defaults.
                  </p>
                </div>
              </div>
            </div>

            <div className="p-6">
              {permissionLoading ? (
                <div className="text-center py-12">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b] mx-auto"></div>
                  <p className="text-gray-400 mt-4">Loading permissions...</p>
                </div>
              ) : (
                <>
                  {Object.entries(groupStaffPermissionsByCategory(staffPermissions)).map(([category, perms]) => (
                    <div key={category} className="mb-6">
                      <h3 className="text-sm font-bold text-[#f0b90b] uppercase tracking-wider mb-3">
                        {category}
                      </h3>
                      <div className="space-y-2">
                        {perms.map((perm) => (
                          <div
                            key={perm.permission_code}
                            className="flex items-center justify-between p-4 bg-[#0b0e11] rounded-lg border border-gray-800 hover:border-gray-700 transition-colors"
                          >
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-1">
                                <span className="text-white font-medium">{perm.permission_name}</span>
                                <span className={`text-xs px-2 py-1 rounded ${
                                  perm.source.startsWith('Custom:')
                                    ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                                    : perm.source.startsWith('From Role:')
                                    ? 'bg-blue-500/20 text-blue-400'
                                    : 'bg-gray-700 text-gray-400'
                                }`}>
                                  {perm.source}
                                </span>
                              </div>
                              <p className="text-sm text-gray-400">{perm.description}</p>
                            </div>
                            <button
                              onClick={() => toggleStaffPermission(perm.permission_code, perm.has_permission)}
                              disabled={permissionLoading}
                              className={`ml-4 relative inline-flex h-8 w-14 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-[#f0b90b] focus:ring-offset-2 focus:ring-offset-[#1a1d24] ${
                                perm.has_permission ? 'bg-[#f0b90b]' : 'bg-gray-700'
                              }`}
                            >
                              <span
                                className={`inline-block h-6 w-6 transform rounded-full bg-white transition-transform ${
                                  perm.has_permission ? 'translate-x-7' : 'translate-x-1'
                                }`}
                              />
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}

                  {staffPermissions.length === 0 && (
                    <div className="text-center py-8">
                      <p className="text-gray-400">No permissions available.</p>
                    </div>
                  )}
                </>
              )}

              <div className="flex justify-end gap-3 pt-6 border-t border-gray-800">
                <button
                  onClick={() => {
                    setShowEditPermissionsModal(false);
                    setSelectedStaff(null);
                    setStaffPermissions([]);
                  }}
                  className="px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
