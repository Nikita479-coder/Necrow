import { useState, useEffect } from 'react';
import {
  Activity, DollarSign, Shield, AlertCircle, FileText, RefreshCw, Search, Filter,
  Users, TrendingUp, Download, Tag, BarChart3, UserCheck, UserX, Clock,
  ChevronDown, Check, X, Eye, Mail, Ban, Unlock, Bell, LogIn, Copy, ExternalLink, Image
} from 'lucide-react';
import Navbar from '../components/Navbar';
import PopupBannerManager from '../components/admin/PopupBannerManager';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';

type MainTab = 'analytics' | 'users' | 'segments' | 'logs' | 'popups';
type LogType = 'admin' | 'financial' | 'kyc' | 'security' | 'system';

interface DashboardStats {
  totalUsers: number;
  activeUsers24h: number;
  activeUsers7d: number;
  newUsers24h: number;
  newUsers7d: number;
  kycPending: number;
  kycVerified: number;
  totalDeposits24h: number;
  totalWithdrawals24h: number;
  totalVolume24h: number;
  totalFees24h: number;
  openSupportTickets: number;
  avgResponseTime: number;
  vipBreakdown: Record<string, number>;
}

interface FilteredUser {
  id: string;
  username: string;
  email: string;
  full_name: string | null;
  kyc_status: string;
  vip_tier: string | null;
  created_at: string;
  withdrawal_blocked: boolean;
  total_balance: number;
  open_positions: number;
  tags: string[] | null;
  is_online?: boolean;
  last_activity?: string;
}

interface UserTag {
  id: string;
  name: string;
  color: string;
}

interface UserSegment {
  id: string;
  name: string;
  description: string;
  user_count: number;
  is_dynamic: boolean;
  filter_criteria: any;
}

interface SavedFilter {
  id: string;
  name: string;
  filter_config: any;
  is_shared: boolean;
}

export default function AdminCRM() {
  const { user, profile } = useAuth();
  const { navigateTo } = useNavigation();
  const [mainTab, setMainTab] = useState<MainTab>('analytics');
  const [logTab, setLogTab] = useState<LogType>('admin');
  const [loading, setLoading] = useState(true);

  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [users, setUsers] = useState<FilteredUser[]>([]);
  const [totalUsers, setTotalUsers] = useState(0);
  const [selectedUsers, setSelectedUsers] = useState<Set<string>>(new Set());
  const [tags, setTags] = useState<UserTag[]>([]);
  const [segments, setSegments] = useState<UserSegment[]>([]);
  const [savedFilters, setSavedFilters] = useState<SavedFilter[]>([]);

  const [filters, setFilters] = useState({
    search: '',
    kycStatus: 'all',
    vipTier: 'all',
    hasTag: '',
    minBalance: '',
    maxBalance: '',
    withdrawalBlocked: 'all',
    onlineStatus: 'all',
  });

  const [page, setPage] = useState(0);
  const [showBulkActions, setShowBulkActions] = useState(false);
  const [bulkActionType, setBulkActionType] = useState('');
  const [bulkActionLoading, setBulkActionLoading] = useState(false);

  const [logs, setLogs] = useState<any[]>([]);
  const [dateFilter, setDateFilter] = useState('7d');

  const [loginAsModal, setLoginAsModal] = useState<{
    show: boolean;
    loading: boolean;
    userId: string;
    username: string;
    accessToken: string | null;
    refreshToken: string | null;
    error: string | null;
  }>({
    show: false,
    loading: false,
    userId: '',
    username: '',
    accessToken: null,
    refreshToken: null,
    error: null,
  });

  useEffect(() => {
    if (profile?.is_admin) {
      loadInitialData();
    }
  }, [profile]);

  useEffect(() => {
    if (mainTab === 'users') {
      loadFilteredUsers();
    } else if (mainTab === 'logs') {
      loadLogs();
    }
  }, [mainTab, filters, page, logTab, dateFilter]);

  useEffect(() => {
    if (!profile?.is_admin) return;

    const channel = supabase
      .channel('admin-crm-user-sessions')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_sessions',
        },
        (payload) => {
          const session = payload.new as any;
          if (session) {
            const heartbeat = new Date(session.heartbeat || session.last_activity);
            const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
            const isOnline = session.is_online && heartbeat > twoMinutesAgo;

            setUsers(prevUsers => prevUsers.map(user =>
              user.id === session.user_id
                ? { ...user, is_online: isOnline, last_activity: session.last_activity }
                : user
            ));
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [profile]);

  const loadInitialData = async () => {
    setLoading(true);
    try {
      const [statsResult, tagsResult, segmentsResult, filtersResult] = await Promise.all([
        supabase.rpc('get_crm_dashboard_stats'),
        supabase.from('user_tags').select('*').order('name'),
        supabase.from('user_segments').select('*').eq('is_active', true).order('name'),
        supabase.from('saved_filters').select('*').or(`admin_id.eq.${user?.id},is_shared.eq.true`),
      ]);

      if (statsResult.data) setStats(statsResult.data);
      if (tagsResult.data) setTags(tagsResult.data);
      if (segmentsResult.data) setSegments(segmentsResult.data);
      if (filtersResult.data) setSavedFilters(filtersResult.data);
    } catch (error) {
      console.error('Error loading CRM data:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadFilteredUsers = async () => {
    setLoading(true);
    try {
      const filterObj: any = {};
      if (filters.search) filterObj.search = filters.search;
      if (filters.kycStatus !== 'all') filterObj.kycStatus = filters.kycStatus;
      if (filters.vipTier !== 'all') filterObj.vipTier = filters.vipTier;
      if (filters.hasTag) filterObj.hasTag = filters.hasTag;
      if (filters.minBalance) filterObj.minBalance = parseFloat(filters.minBalance);
      if (filters.maxBalance) filterObj.maxBalance = parseFloat(filters.maxBalance);
      if (filters.withdrawalBlocked !== 'all') filterObj.withdrawalBlocked = filters.withdrawalBlocked === 'true';

      const { data } = await supabase.rpc('get_filtered_users', {
        p_filters: filterObj,
        p_limit: 20,
        p_offset: page * 20
      });

      if (data) {
        const { data: sessions } = await supabase
          .from('user_sessions')
          .select('user_id, is_online, last_activity, heartbeat');

        const sessionsMap = new Map(
          sessions?.map(s => {
            const heartbeat = new Date(s.heartbeat || s.last_activity);
            const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
            const isOnline = s.is_online && heartbeat > twoMinutesAgo;
            return [s.user_id, { is_online: isOnline, last_activity: s.last_activity }];
          }) || []
        );

        let usersWithOnlineStatus = (data.users || []).map((u: FilteredUser) => ({
          ...u,
          is_online: sessionsMap.get(u.id)?.is_online || false,
          last_activity: sessionsMap.get(u.id)?.last_activity,
        }));

        if (filters.onlineStatus === 'online') {
          usersWithOnlineStatus = usersWithOnlineStatus.filter(u => u.is_online);
        } else if (filters.onlineStatus === 'offline') {
          usersWithOnlineStatus = usersWithOnlineStatus.filter(u => !u.is_online);
        }

        setUsers(usersWithOnlineStatus);
        setTotalUsers(data.total || 0);
      }
    } catch (error) {
      console.error('Error loading users:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadLogs = async () => {
    setLoading(true);
    try {
      const dateThreshold = getDateThreshold();
      let table = '';

      switch (logTab) {
        case 'admin': table = 'admin_activity_logs'; break;
        case 'financial': table = 'financial_transaction_logs'; break;
        case 'kyc': table = 'kyc_action_logs'; break;
        case 'security': table = 'security_logs'; break;
        case 'system': table = 'system_audit_logs'; break;
      }

      const { data } = await supabase
        .from(table)
        .select('*')
        .gte('created_at', dateThreshold)
        .order('created_at', { ascending: false })
        .limit(100);

      setLogs(data || []);
    } catch (error) {
      console.error('Error loading logs:', error);
    } finally {
      setLoading(false);
    }
  };

  const getDateThreshold = () => {
    const now = new Date();
    switch (dateFilter) {
      case '24h': return new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
      case '7d': return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
      case '30d': return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
      default: return new Date(0).toISOString();
    }
  };

  const handleSelectUser = (userId: string) => {
    const newSelected = new Set(selectedUsers);
    if (newSelected.has(userId)) {
      newSelected.delete(userId);
    } else {
      newSelected.add(userId);
    }
    setSelectedUsers(newSelected);
  };

  const handleSelectAll = () => {
    if (selectedUsers.size === users.length) {
      setSelectedUsers(new Set());
    } else {
      setSelectedUsers(new Set(users.map(u => u.id)));
    }
  };

  const handleBulkAction = async (actionType: string, details: any = {}) => {
    if (selectedUsers.size === 0) return;

    setBulkActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('execute_bulk_action', {
        p_admin_id: user?.id,
        p_action_type: actionType,
        p_user_ids: Array.from(selectedUsers),
        p_details: details
      });

      if (error) throw error;

      setSelectedUsers(new Set());
      setShowBulkActions(false);
      loadFilteredUsers();
    } catch (error) {
      console.error('Bulk action error:', error);
    } finally {
      setBulkActionLoading(false);
    }
  };

  const handleExport = (format: 'csv' | 'json') => {
    const dataToExport = mainTab === 'users' ? users : logs;

    if (format === 'csv') {
      const headers = Object.keys(dataToExport[0] || {}).join(',');
      const rows = dataToExport.map(item =>
        Object.values(item).map(v =>
          typeof v === 'string' ? `"${v.replace(/"/g, '""')}"` : v
        ).join(',')
      );
      const csv = [headers, ...rows].join('\n');
      downloadFile(csv, `crm_export_${Date.now()}.csv`, 'text/csv');
    } else {
      const json = JSON.stringify(dataToExport, null, 2);
      downloadFile(json, `crm_export_${Date.now()}.json`, 'application/json');
    }
  };

  const downloadFile = (content: string, filename: string, type: string) => {
    const blob = new Blob([content], { type });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleViewUser = (userId: string) => {
    localStorage.setItem('adminSelectedUserId', userId);
    navigateTo('adminuserdetail');
  };

  const handleLoginAs = async (userId: string, username: string) => {
    setLoginAsModal({
      show: true,
      loading: true,
      userId,
      username,
      accessToken: null,
      refreshToken: null,
      error: null,
    });

    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const accessToken = sessionData?.session?.access_token;

      if (!accessToken) {
        throw new Error('No active session');
      }

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/login-as-user`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
            'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
          },
          body: JSON.stringify({
            target_user_id: userId,
            reason: 'Admin support session from CRM',
          }),
        }
      );

      const result = await response.json();

      if (!result.success) {
        throw new Error(result.error || 'Failed to generate login token');
      }

      setLoginAsModal(prev => ({
        ...prev,
        loading: false,
        accessToken: result.access_token,
        refreshToken: result.refresh_token,
      }));
    } catch (error: any) {
      setLoginAsModal(prev => ({
        ...prev,
        loading: false,
        error: error.message || 'Failed to generate login token',
      }));
    }
  };

  const handleImpersonateUser = () => {
    if (loginAsModal.accessToken && loginAsModal.refreshToken) {
      localStorage.setItem('impersonation_tokens', JSON.stringify({
        access_token: loginAsModal.accessToken,
        refresh_token: loginAsModal.refreshToken,
        target_username: loginAsModal.username,
      }));
      window.open('/wallet?impersonated=true', '_blank');
      setLoginAsModal(prev => ({ ...prev, show: false }));
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  const formatNumber = (num: number) => {
    if (num >= 1000000) return (num / 1000000).toFixed(2) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(2) + 'K';
    return num.toFixed(2);
  };

  if (!profile?.is_admin) {
    return (
      <div className="min-h-screen bg-[#0a0d10] text-white">
        <Navbar />
        <div className="max-w-7xl mx-auto px-4 py-12 text-center">
          <h1 className="text-3xl font-bold text-red-400 mb-4">Access Denied</h1>
          <p className="text-gray-400">You do not have permission to view this page.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0a0d10] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold mb-2">CRM Dashboard</h1>
            <p className="text-gray-400">Manage users, view analytics, and track platform activity</p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={() => handleExport('csv')}
              className="flex items-center gap-2 px-4 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-xl border border-green-500/30 transition-colors"
            >
              <Download className="w-4 h-4" />
              Export CSV
            </button>
            <button
              onClick={loadInitialData}
              disabled={loading}
              className="flex items-center gap-2 px-4 py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-xl border border-blue-500/30 transition-colors"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
        </div>

        <div className="flex flex-wrap gap-2 mb-6">
          {[
            { id: 'analytics', label: 'Analytics', icon: BarChart3 },
            { id: 'users', label: 'User Management', icon: Users },
            { id: 'segments', label: 'Segments & Tags', icon: Tag },
            { id: 'popups', label: 'Popup Banners', icon: Image },
            { id: 'logs', label: 'Activity Logs', icon: Activity },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setMainTab(tab.id as MainTab)}
              className={`flex items-center gap-2 px-5 py-3 rounded-xl font-medium transition-all ${
                mainTab === tab.id
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-[#0b0e11] text-gray-400 hover:text-white border border-gray-800 hover:border-gray-700'
              }`}
            >
              <tab.icon className="w-5 h-5" />
              {tab.label}
            </button>
          ))}
        </div>

        {mainTab === 'analytics' && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-white">Platform Analytics</h2>
              <button
                onClick={() => {
                  if (!stats) return;
                  const reportData = {
                    generatedAt: new Date().toISOString(),
                    summary: stats,
                  };
                  const json = JSON.stringify(reportData, null, 2);
                  const blob = new Blob([json], { type: 'application/json' });
                  const url = URL.createObjectURL(blob);
                  const a = document.createElement('a');
                  a.href = url;
                  a.download = `analytics_report_${Date.now()}.json`;
                  a.click();
                  URL.revokeObjectURL(url);
                }}
                className="flex items-center gap-2 px-4 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors text-sm"
              >
                <Download className="w-4 h-4" />
                Export Analytics Report
              </button>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <StatCard
                title="Total Users"
                value={stats?.totalUsers || 0}
                icon={Users}
                color="blue"
              />
              <StatCard
                title="Active (24h)"
                value={stats?.activeUsers24h || 0}
                icon={Activity}
                color="green"
                subtitle={`${stats?.activeUsers7d || 0} in 7 days`}
              />
              <StatCard
                title="New Users (24h)"
                value={stats?.newUsers24h || 0}
                icon={UserCheck}
                color="cyan"
                subtitle={`${stats?.newUsers7d || 0} in 7 days`}
              />
              <StatCard
                title="KYC Pending"
                value={stats?.kycPending || 0}
                icon={Clock}
                color="yellow"
                subtitle={`${stats?.kycVerified || 0} verified`}
              />
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <StatCard
                title="Deposits (24h)"
                value={`$${formatNumber(stats?.totalDeposits24h || 0)}`}
                icon={TrendingUp}
                color="green"
                isAmount
              />
              <StatCard
                title="Withdrawals (24h)"
                value={`$${formatNumber(stats?.totalWithdrawals24h || 0)}`}
                icon={DollarSign}
                color="red"
                isAmount
              />
              <StatCard
                title="Volume (24h)"
                value={`$${formatNumber(stats?.totalVolume24h || 0)}`}
                icon={BarChart3}
                color="blue"
                isAmount
              />
              <StatCard
                title="Fees (24h)"
                value={`$${formatNumber(stats?.totalFees24h || 0)}`}
                icon={DollarSign}
                color="yellow"
                isAmount
              />
            </div>

            <div className="grid md:grid-cols-2 gap-6">
              <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
                <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                  <Shield className="w-5 h-5 text-[#f0b90b]" />
                  VIP Distribution
                </h3>
                <div className="space-y-3">
                  {stats?.vipBreakdown && Object.entries(stats.vipBreakdown).map(([tier, count]) => (
                    <div key={tier} className="flex items-center justify-between">
                      <span className="text-gray-300">{tier}</span>
                      <div className="flex items-center gap-3">
                        <div className="w-32 h-2 bg-gray-800 rounded-full overflow-hidden">
                          <div
                            className="h-full bg-[#f0b90b] rounded-full"
                            style={{ width: `${(count / (stats?.totalUsers || 1)) * 100}%` }}
                          />
                        </div>
                        <span className="text-white font-medium w-12 text-right">{count}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
                <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                  <AlertCircle className="w-5 h-5 text-[#f0b90b]" />
                  Support Overview
                </h3>
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-[#1a1d24] rounded-xl p-4 text-center">
                    <p className="text-3xl font-bold text-orange-400">{stats?.openSupportTickets || 0}</p>
                    <p className="text-gray-400 text-sm mt-1">Open Tickets</p>
                  </div>
                  <div className="bg-[#1a1d24] rounded-xl p-4 text-center">
                    <p className="text-3xl font-bold text-green-400">
                      {stats?.avgResponseTime ? `${Math.round(stats.avgResponseTime)}m` : 'N/A'}
                    </p>
                    <p className="text-gray-400 text-sm mt-1">Avg Response</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {mainTab === 'users' && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-white">User Management</h2>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => handleExport('csv')}
                  className="flex items-center gap-2 px-4 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors text-sm"
                >
                  <Download className="w-4 h-4" />
                  Export Users CSV
                </button>
                <button
                  onClick={() => handleExport('json')}
                  className="flex items-center gap-2 px-4 py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors text-sm"
                >
                  <Download className="w-4 h-4" />
                  Export JSON
                </button>
              </div>
            </div>
            <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
              <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3">
                <div className="col-span-2">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                    <input
                      type="text"
                      placeholder="Search by email, username, or user ID..."
                      value={filters.search}
                      onChange={(e) => setFilters({ ...filters, search: e.target.value })}
                      className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
                    />
                  </div>
                </div>
                <select
                  value={filters.kycStatus}
                  onChange={(e) => setFilters({ ...filters, kycStatus: e.target.value })}
                  className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
                >
                  <option value="all">All KYC Status</option>
                  <option value="pending">Pending</option>
                  <option value="verified">Verified</option>
                  <option value="rejected">Rejected</option>
                </select>
                <select
                  value={filters.vipTier}
                  onChange={(e) => setFilters({ ...filters, vipTier: e.target.value })}
                  className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
                >
                  <option value="all">All VIP Tiers</option>
                  <option value="Bronze">Bronze</option>
                  <option value="Silver">Silver</option>
                  <option value="Gold">Gold</option>
                  <option value="Platinum">Platinum</option>
                  <option value="Diamond">Diamond</option>
                </select>
                <input
                  type="number"
                  placeholder="Min Balance"
                  value={filters.minBalance}
                  onChange={(e) => setFilters({ ...filters, minBalance: e.target.value })}
                  className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
                />
                <input
                  type="number"
                  placeholder="Max Balance"
                  value={filters.maxBalance}
                  onChange={(e) => setFilters({ ...filters, maxBalance: e.target.value })}
                  className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
                />
              </div>
            </div>

            {selectedUsers.size > 0 && (
              <div className="bg-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-xl p-4 flex items-center justify-between">
                <span className="text-[#f0b90b] font-medium">
                  {selectedUsers.size} user{selectedUsers.size > 1 ? 's' : ''} selected
                </span>
                <div className="flex items-center gap-2">
                  <select
                    value={bulkActionType}
                    onChange={(e) => setBulkActionType(e.target.value)}
                    className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
                  >
                    <option value="">Select Action</option>
                    <option value="send_notification">Send Notification</option>
                    <option value="block_withdrawal">Block Withdrawals</option>
                    <option value="unblock_withdrawal">Unblock Withdrawals</option>
                    <option value="add_tag">Add Tag</option>
                  </select>
                  <button
                    onClick={() => handleBulkAction(bulkActionType)}
                    disabled={!bulkActionType || bulkActionLoading}
                    className="px-4 py-2 bg-[#f0b90b] text-black rounded-lg font-medium disabled:opacity-50"
                  >
                    {bulkActionLoading ? 'Processing...' : 'Apply'}
                  </button>
                  <button
                    onClick={() => setSelectedUsers(new Set())}
                    className="px-4 py-2 text-gray-400 hover:text-white"
                  >
                    Clear
                  </button>
                </div>
              </div>
            )}

            <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden">
              <table className="w-full">
                <thead className="bg-[#1a1d24]">
                  <tr>
                    <th className="px-4 py-3 text-left">
                      <input
                        type="checkbox"
                        checked={selectedUsers.size === users.length && users.length > 0}
                        onChange={handleSelectAll}
                        className="rounded border-gray-600"
                      />
                    </th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">User</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Status</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">VIP</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Balance</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Tags</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Joined</th>
                    <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-800">
                  {users.map((u) => (
                    <tr key={u.id} className="hover:bg-[#1a1d24]/50 transition-colors">
                      <td className="px-4 py-3">
                        <input
                          type="checkbox"
                          checked={selectedUsers.has(u.id)}
                          onChange={() => handleSelectUser(u.id)}
                          className="rounded border-gray-600"
                        />
                      </td>
                      <td className="px-4 py-3">
                        <div>
                          <p className="text-white font-medium">
                            {u.full_name || 'No name'}
                          </p>
                          {u.username && (
                            <p className="text-gray-400 text-sm">@{u.username}</p>
                          )}
                          <p className="text-gray-500 text-sm">{u.email}</p>
                          <p className="text-gray-600 text-xs font-mono">ID: {u.id.slice(0, 8)}...</p>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <span className={`px-2 py-1 rounded-lg text-xs font-medium ${
                            u.kyc_status === 'verified'
                              ? 'bg-green-500/10 text-green-400'
                              : u.kyc_status === 'pending'
                              ? 'bg-yellow-500/10 text-yellow-400'
                              : 'bg-gray-500/10 text-gray-400'
                          }`}>
                            {u.kyc_status}
                          </span>
                          {u.withdrawal_blocked && (
                            <span className="px-2 py-1 bg-red-500/10 text-red-400 rounded-lg text-xs">
                              Blocked
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <span className={`px-2 py-1 rounded-lg text-xs font-medium ${
                          u.vip_tier ? 'bg-[#f0b90b]/10 text-[#f0b90b]' : 'text-gray-500'
                        }`}>
                          {u.vip_tier || 'Standard'}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <span className="text-white font-medium">
                          ${formatNumber(u.total_balance || 0)}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap gap-1">
                          {u.tags?.slice(0, 2).map((tag) => (
                            <span key={tag} className="px-2 py-0.5 bg-blue-500/10 text-blue-400 rounded-full text-xs">
                              {tag}
                            </span>
                          ))}
                          {(u.tags?.length || 0) > 2 && (
                            <span className="text-gray-500 text-xs">+{u.tags!.length - 2}</span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-gray-400 text-sm">
                        {new Date(u.created_at).toLocaleDateString()}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => handleViewUser(u.id)}
                            className="p-2 hover:bg-gray-800 rounded-lg text-gray-400 hover:text-white transition-colors"
                            title="View User Details"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleLoginAs(u.id, u.username || 'User')}
                            className="p-2 hover:bg-[#f0b90b]/20 rounded-lg text-gray-400 hover:text-[#f0b90b] transition-colors"
                            title="Login As User"
                          >
                            <LogIn className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {users.length === 0 && !loading && (
                <div className="text-center py-12">
                  <Users className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                  <p className="text-gray-400">No users found matching your filters</p>
                </div>
              )}
            </div>

            <div className="flex items-center justify-between">
              <p className="text-gray-400 text-sm">
                Showing {users.length} of {totalUsers} users
              </p>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setPage(Math.max(0, page - 1))}
                  disabled={page === 0}
                  className="px-4 py-2 bg-[#1a1d24] text-gray-400 rounded-lg disabled:opacity-50"
                >
                  Previous
                </button>
                <span className="px-4 py-2 text-white">Page {page + 1}</span>
                <button
                  onClick={() => setPage(page + 1)}
                  disabled={users.length < 20}
                  className="px-4 py-2 bg-[#1a1d24] text-gray-400 rounded-lg disabled:opacity-50"
                >
                  Next
                </button>
              </div>
            </div>
          </div>
        )}

        {mainTab === 'segments' && (
          <div className="grid md:grid-cols-2 gap-6">
            <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
              <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                <Tag className="w-5 h-5 text-[#f0b90b]" />
                User Tags ({tags.length})
              </h3>
              <div className="space-y-2">
                {tags.map((tag) => (
                  <div
                    key={tag.id}
                    className="flex items-center justify-between p-3 bg-[#1a1d24] rounded-lg border border-gray-800"
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className="w-3 h-3 rounded-full"
                        style={{ backgroundColor: tag.color }}
                      />
                      <span className="text-white font-medium">{tag.name}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
              <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                <Users className="w-5 h-5 text-[#f0b90b]" />
                Segments ({segments.length})
              </h3>
              <div className="space-y-2">
                {segments.map((segment) => (
                  <div
                    key={segment.id}
                    className="p-3 bg-[#1a1d24] rounded-lg border border-gray-800"
                  >
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-white font-medium">{segment.name}</span>
                      <span className="text-[#f0b90b] text-sm">{segment.user_count} users</span>
                    </div>
                    <p className="text-gray-500 text-sm">{segment.description}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {mainTab === 'popups' && (
          <PopupBannerManager />
        )}

        {mainTab === 'logs' && (
          <div className="space-y-4">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-white">Activity Logs</h2>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => handleExport('csv')}
                  className="flex items-center gap-2 px-4 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors text-sm"
                >
                  <Download className="w-4 h-4" />
                  Export Logs CSV
                </button>
                <button
                  onClick={() => handleExport('json')}
                  className="flex items-center gap-2 px-4 py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors text-sm"
                >
                  <Download className="w-4 h-4" />
                  Export JSON
                </button>
              </div>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex flex-wrap gap-2">
                {[
                  { id: 'admin', label: 'Admin', icon: Activity },
                  { id: 'financial', label: 'Financial', icon: DollarSign },
                  { id: 'kyc', label: 'KYC', icon: Shield },
                  { id: 'security', label: 'Security', icon: AlertCircle },
                  { id: 'system', label: 'System', icon: FileText },
                ].map((tab) => (
                  <button
                    key={tab.id}
                    onClick={() => setLogTab(tab.id as LogType)}
                    className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all text-sm ${
                      logTab === tab.id
                        ? 'bg-[#f0b90b]/20 text-[#f0b90b] border border-[#f0b90b]/30'
                        : 'bg-[#1a1d24] text-gray-400 hover:text-white border border-gray-800'
                    }`}
                  >
                    <tab.icon className="w-4 h-4" />
                    {tab.label}
                  </button>
                ))}
              </div>
              <select
                value={dateFilter}
                onChange={(e) => setDateFilter(e.target.value)}
                className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
              >
                <option value="24h">Last 24 Hours</option>
                <option value="7d">Last 7 Days</option>
                <option value="30d">Last 30 Days</option>
                <option value="all">All Time</option>
              </select>
            </div>

            <div className="space-y-3">
              {logs.map((log) => (
                <div
                  key={log.id}
                  className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800 hover:border-gray-700 transition-colors"
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <p className="text-white font-medium">
                        {log.action_type || log.transaction_type || log.event_type}
                      </p>
                      <p className="text-gray-400 text-sm mt-1">
                        {log.action_description || log.description || log.reason || 'No description'}
                      </p>
                    </div>
                    <span className="text-gray-500 text-sm">
                      {new Date(log.created_at).toLocaleString()}
                    </span>
                  </div>
                </div>
              ))}

              {logs.length === 0 && !loading && (
                <div className="bg-[#0b0e11] rounded-xl p-12 text-center border border-gray-800">
                  <FileText className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                  <p className="text-gray-400">No logs found for the selected period</p>
                </div>
              )}
            </div>
          </div>
        )}

        {loading && (
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b] mx-auto"></div>
            <p className="text-gray-400 mt-4">Loading...</p>
          </div>
        )}
      </div>

      {loginAsModal.show && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#0b0e11] rounded-2xl border border-gray-800 max-w-lg w-full p-6">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#f0b90b]/10 flex items-center justify-center">
                  <LogIn className="w-5 h-5 text-[#f0b90b]" />
                </div>
                <div>
                  <h3 className="text-lg font-bold text-white">Login As User</h3>
                  <p className="text-gray-400 text-sm">{loginAsModal.username}</p>
                </div>
              </div>
              <button
                onClick={() => setLoginAsModal(prev => ({ ...prev, show: false }))}
                className="p-2 hover:bg-gray-800 rounded-lg text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {loginAsModal.loading && (
              <div className="text-center py-8">
                <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-[#f0b90b] mx-auto mb-4"></div>
                <p className="text-gray-400">Generating login link...</p>
              </div>
            )}

            {loginAsModal.error && (
              <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 mb-4">
                <div className="flex items-center gap-3">
                  <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0" />
                  <div>
                    <p className="text-red-400 font-medium">Access Denied</p>
                    <p className="text-red-400/70 text-sm mt-1">{loginAsModal.error}</p>
                  </div>
                </div>
              </div>
            )}

            {loginAsModal.accessToken && (
              <div className="space-y-4">
                <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-4">
                  <div className="flex items-center gap-3 mb-3">
                    <Check className="w-5 h-5 text-green-400" />
                    <p className="text-green-400 font-medium">Login Session Ready</p>
                  </div>
                  <p className="text-gray-400 text-sm">
                    Session tokens have been generated for {loginAsModal.username}.
                    Click the button below to open a new window and sign in as this user.
                  </p>
                </div>

                <div className="flex items-center gap-3">
                  <button
                    onClick={handleImpersonateUser}
                    className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-[#f0b90b] text-black rounded-xl font-medium hover:bg-[#d4a50a] transition-colors"
                  >
                    <ExternalLink className="w-4 h-4" />
                    Login As {loginAsModal.username}
                  </button>
                  <button
                    onClick={() => setLoginAsModal(prev => ({ ...prev, show: false }))}
                    className="px-4 py-3 bg-gray-800 text-white rounded-xl font-medium hover:bg-gray-700 transition-colors"
                  >
                    Close
                  </button>
                </div>

                <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-3">
                  <p className="text-yellow-400 text-xs">
                    This action has been logged for security purposes. All activities performed while impersonating this user will be tracked.
                  </p>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function StatCard({ title, value, icon: Icon, color, subtitle, isAmount }: {
  title: string;
  value: number | string;
  icon: any;
  color: string;
  subtitle?: string;
  isAmount?: boolean;
}) {
  const colorClasses: Record<string, string> = {
    blue: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
    green: 'bg-green-500/10 text-green-400 border-green-500/30',
    red: 'bg-red-500/10 text-red-400 border-red-500/30',
    yellow: 'bg-[#f0b90b]/10 text-[#f0b90b] border-[#f0b90b]/30',
    cyan: 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30',
  };

  return (
    <div className={`rounded-xl p-5 border ${colorClasses[color]}`}>
      <div className="flex items-center justify-between mb-3">
        <Icon className="w-5 h-5" />
        <span className="text-xs opacity-70">{title}</span>
      </div>
      <p className={`text-2xl font-bold ${isAmount ? '' : 'text-white'}`}>
        {value}
      </p>
      {subtitle && (
        <p className="text-xs opacity-60 mt-1">{subtitle}</p>
      )}
    </div>
  );
}
