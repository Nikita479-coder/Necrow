import { useState, useEffect } from 'react';
import { Activity, User, Search, Filter, RefreshCw, Eye, Calendar, Download, ChevronDown } from 'lucide-react';
import Navbar from '../components/Navbar';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';

interface StaffActivityLog {
  id: string;
  staff_id: string;
  staff_name: string;
  staff_email: string;
  action_type: string;
  action_description: string;
  target_user_id: string | null;
  target_user_name: string | null;
  page_visited: string | null;
  search_query: string | null;
  ip_address: string | null;
  metadata: Record<string, any>;
  created_at: string;
}

interface StaffMember {
  id: string;
  full_name: string;
  email: string;
}

const ACTION_TYPES = [
  { value: '', label: 'All Actions' },
  { value: 'page_view', label: 'Page Views' },
  { value: 'user_profile_view', label: 'User Profile Views' },
  { value: 'search_performed', label: 'Searches' },
  { value: 'ticket_viewed', label: 'Ticket Views' },
  { value: 'ticket_response', label: 'Ticket Responses' },
  { value: 'template_created', label: 'Template Created' },
  { value: 'email_sent', label: 'Emails Sent' },
  { value: 'bonus_awarded', label: 'Bonuses Awarded' },
  { value: 'phone_reveal_request', label: 'Phone Reveal Requests' },
  { value: 'export_data', label: 'Data Exports' },
];

export default function AdminStaffActivityLogs() {
  const { profile } = useAuth();
  const { navigateTo } = useNavigation();
  const [logs, setLogs] = useState<StaffActivityLog[]>([]);
  const [staffMembers, setStaffMembers] = useState<StaffMember[]>([]);
  const [loading, setLoading] = useState(true);

  const [filters, setFilters] = useState({
    staffId: '',
    actionType: '',
    fromDate: '',
    toDate: '',
    search: ''
  });

  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    if (profile?.is_admin) {
      loadStaffMembers();
      loadLogs();
    }
  }, [profile]);

  useEffect(() => {
    if (profile?.is_admin) {
      loadLogs();
    }
  }, [filters.staffId, filters.actionType, filters.fromDate, filters.toDate]);

  const loadStaffMembers = async () => {
    try {
      const { data } = await supabase
        .from('admin_staff')
        .select('id')
        .eq('is_active', true);

      if (data) {
        const staffIds = data.map(s => s.id);
        const { data: profiles } = await supabase
          .from('user_profiles')
          .select('id, full_name')
          .in('id', staffIds);

        const { data: authData } = await supabase.auth.admin.listUsers();
        const emailMap = new Map(authData?.users?.map(u => [u.id, u.email || '']) || []);

        const members: StaffMember[] = (profiles || []).map(p => ({
          id: p.id,
          full_name: p.full_name || 'Unknown',
          email: emailMap.get(p.id) || ''
        }));

        setStaffMembers(members);
      }
    } catch (error) {
      console.error('Error loading staff members:', error);
    }
  };

  const loadLogs = async () => {
    setLoading(true);
    try {
      const params: any = {
        p_limit: 200,
        p_offset: 0
      };

      if (filters.staffId) params.p_staff_id = filters.staffId;
      if (filters.actionType) params.p_action_type = filters.actionType;
      if (filters.fromDate) params.p_from_date = new Date(filters.fromDate).toISOString();
      if (filters.toDate) params.p_to_date = new Date(filters.toDate + 'T23:59:59').toISOString();

      const { data, error } = await supabase.rpc('get_staff_activity_logs', params);

      if (error) throw error;
      setLogs(data || []);
    } catch (error) {
      console.error('Error loading logs:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleViewUser = (userId: string) => {
    localStorage.setItem('adminSelectedUserId', userId);
    navigateTo('adminuserdetail');
  };

  const handleExport = () => {
    const headers = ['Date', 'Staff', 'Email', 'Action', 'Description', 'Target User', 'Page', 'Search Query', 'IP'];
    const rows = filteredLogs.map(log => [
      formatDate(log.created_at),
      log.staff_name,
      log.staff_email,
      log.action_type,
      log.action_description,
      log.target_user_name || '',
      log.page_visited || '',
      log.search_query || '',
      log.ip_address || ''
    ]);

    const csv = [headers.join(','), ...rows.map(r => r.map(c => `"${c}"`).join(','))].join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `staff_activity_logs_${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const getActionColor = (actionType: string) => {
    switch (actionType) {
      case 'page_view':
        return 'bg-blue-500/10 text-blue-400 border-blue-500/30';
      case 'user_profile_view':
        return 'bg-purple-500/10 text-purple-400 border-purple-500/30';
      case 'search_performed':
        return 'bg-gray-500/10 text-gray-400 border-gray-500/30';
      case 'ticket_response':
        return 'bg-green-500/10 text-green-400 border-green-500/30';
      case 'email_sent':
        return 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30';
      case 'bonus_awarded':
        return 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30';
      case 'phone_reveal_request':
        return 'bg-orange-500/10 text-orange-400 border-orange-500/30';
      case 'export_data':
        return 'bg-red-500/10 text-red-400 border-red-500/30';
      default:
        return 'bg-gray-500/10 text-gray-400 border-gray-500/30';
    }
  };

  const filteredLogs = logs.filter(log => {
    if (!filters.search) return true;
    const query = filters.search.toLowerCase();
    return (
      log.staff_name?.toLowerCase().includes(query) ||
      log.staff_email?.toLowerCase().includes(query) ||
      log.action_description?.toLowerCase().includes(query) ||
      log.target_user_name?.toLowerCase().includes(query) ||
      log.search_query?.toLowerCase().includes(query)
    );
  });

  if (!profile?.is_admin) {
    return (
      <div className="min-h-screen bg-[#0a0d10] text-white">
        <Navbar />
        <div className="max-w-7xl mx-auto px-4 py-12">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-red-400 mb-4">Access Denied</h1>
            <p className="text-gray-400">Only super admins can access this page.</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0a0d10] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-3">
            <Activity className="w-8 h-8 text-[#f0b90b]" />
            <div>
              <h1 className="text-3xl font-bold">Staff Activity Logs</h1>
              <p className="text-gray-400 mt-1">
                Monitor all staff CRM activities and actions
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={handleExport}
              className="flex items-center gap-2 px-4 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors"
            >
              <Download className="w-4 h-4" />
              Export CSV
            </button>
            <button
              onClick={loadLogs}
              disabled={loading}
              className="flex items-center gap-2 px-4 py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
        </div>

        <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800 mb-6">
          <div className="flex items-center gap-4 flex-wrap">
            <div className="flex-1 min-w-[200px] relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
              <input
                type="text"
                placeholder="Search logs..."
                value={filters.search}
                onChange={(e) => setFilters(prev => ({ ...prev, search: e.target.value }))}
                className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
              />
            </div>

            <select
              value={filters.staffId}
              onChange={(e) => setFilters(prev => ({ ...prev, staffId: e.target.value }))}
              className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
            >
              <option value="">All Staff</option>
              {staffMembers.map(staff => (
                <option key={staff.id} value={staff.id}>
                  {staff.full_name} ({staff.email})
                </option>
              ))}
            </select>

            <select
              value={filters.actionType}
              onChange={(e) => setFilters(prev => ({ ...prev, actionType: e.target.value }))}
              className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
            >
              {ACTION_TYPES.map(type => (
                <option key={type.value} value={type.value}>{type.label}</option>
              ))}
            </select>

            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-3 py-2 rounded-lg border transition-colors ${
                showFilters || filters.fromDate || filters.toDate
                  ? 'bg-[#f0b90b]/10 text-[#f0b90b] border-[#f0b90b]/30'
                  : 'bg-[#1a1d24] text-gray-400 border-gray-700 hover:text-white'
              }`}
            >
              <Calendar className="w-4 h-4" />
              Date Range
              <ChevronDown className={`w-4 h-4 transition-transform ${showFilters ? 'rotate-180' : ''}`} />
            </button>
          </div>

          {showFilters && (
            <div className="flex items-center gap-4 mt-4 pt-4 border-t border-gray-800">
              <div>
                <label className="block text-xs text-gray-500 mb-1">From Date</label>
                <input
                  type="date"
                  value={filters.fromDate}
                  onChange={(e) => setFilters(prev => ({ ...prev, fromDate: e.target.value }))}
                  className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
                />
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">To Date</label>
                <input
                  type="date"
                  value={filters.toDate}
                  onChange={(e) => setFilters(prev => ({ ...prev, toDate: e.target.value }))}
                  className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
                />
              </div>
              {(filters.fromDate || filters.toDate) && (
                <button
                  onClick={() => setFilters(prev => ({ ...prev, fromDate: '', toDate: '' }))}
                  className="text-gray-400 hover:text-white text-sm mt-5"
                >
                  Clear dates
                </button>
              )}
            </div>
          )}
        </div>

        <div className="mb-4">
          <p className="text-gray-400 text-sm">
            Showing <span className="text-[#f0b90b] font-medium">{filteredLogs.length}</span> log entries
          </p>
        </div>

        {loading ? (
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b] mx-auto"></div>
            <p className="text-gray-400 mt-4">Loading logs...</p>
          </div>
        ) : filteredLogs.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-12 text-center border border-gray-800">
            <Activity className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400">No activity logs found</p>
          </div>
        ) : (
          <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden">
            <div className="overflow-x-auto max-h-[600px] overflow-y-auto">
              <table className="w-full">
                <thead className="bg-[#1a1d24] sticky top-0 z-10">
                  <tr>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Timestamp</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Staff Member</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Action</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Description</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Target User</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">IP Address</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-800">
                  {filteredLogs.map((log) => (
                    <tr key={log.id} className="hover:bg-[#1a1d24]/50 transition-colors">
                      <td className="px-4 py-3">
                        <span className="text-gray-400 text-sm whitespace-nowrap">
                          {formatDate(log.created_at)}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div>
                          <p className="text-white font-medium text-sm">{log.staff_name || 'Unknown'}</p>
                          <p className="text-gray-500 text-xs">{log.staff_email}</p>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <span className={`px-2 py-1 rounded-lg text-xs font-medium border ${getActionColor(log.action_type)}`}>
                          {log.action_type.replace(/_/g, ' ')}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <p className="text-white text-sm">{log.action_description}</p>
                        {log.page_visited && (
                          <p className="text-gray-500 text-xs mt-0.5">Page: {log.page_visited}</p>
                        )}
                        {log.search_query && (
                          <p className="text-gray-500 text-xs mt-0.5">Query: "{log.search_query}"</p>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        {log.target_user_id ? (
                          <button
                            onClick={() => handleViewUser(log.target_user_id!)}
                            className="text-[#f0b90b] text-sm hover:underline flex items-center gap-1"
                          >
                            <Eye className="w-3 h-3" />
                            {log.target_user_name || 'View User'}
                          </button>
                        ) : (
                          <span className="text-gray-500 text-sm">-</span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <span className="text-gray-400 text-sm font-mono">
                          {log.ip_address || '-'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
