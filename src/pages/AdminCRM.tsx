import { useState, useEffect, useCallback } from 'react';
import {
  Activity, DollarSign, Shield, AlertCircle, FileText, RefreshCw, Search, Filter,
  Users, TrendingUp, Download, Tag, BarChart3, UserCheck, UserX, Clock,
  ChevronDown, Check, X, Eye, Mail, Ban, Unlock, Bell, LogIn, Copy, ExternalLink, Image,
  UserPlus, Phone, Lock
} from 'lucide-react';
import Navbar from '../components/Navbar';
import PopupBannerManager from '../components/admin/PopupBannerManager';
import PhoneRevealButton from '../components/admin/PhoneRevealButton';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { loggingService } from '../services/loggingService';

type MainTab = 'analytics' | 'users' | 'segments' | 'referrers' | 'logs' | 'popups' | 'phones';
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

interface ReferrerStats {
  id: string;
  full_name: string;
  email: string;
  referral_code: string;
  total_referrals: number;
  tier_2_referrals: number;
  tier_3_referrals: number;
  tier_4_referrals: number;
  tier_5_referrals: number;
  total_earnings: string;
  lifetime_earnings: string;
  this_month_earnings: string;
  cpa_earnings: string;
  total_volume_30d: string;
  total_volume_all_time: string;
}

interface UserPhone {
  id: string;
  full_name: string;
  phone: string;
  email: string;
  country: string | null;
  kyc_status: string;
  created_at: string;
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
  const [referrers, setReferrers] = useState<ReferrerStats[]>([]);
  const [phoneNumbers, setPhoneNumbers] = useState<UserPhone[]>([]);
  const [phoneSearch, setPhoneSearch] = useState('');

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
  const [pageSize, setPageSize] = useState(100);
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

  const [isSuperAdmin, setIsSuperAdmin] = useState(false);
  const [hasPhoneAccess, setHasPhoneAccess] = useState(false);
  const [searchDebounceTimer, setSearchDebounceTimer] = useState<NodeJS.Timeout | null>(null);

  useEffect(() => {
    const checkPermissions = async () => {
      if (!user) return;

      setIsSuperAdmin(profile?.is_admin === true);

      if (profile?.is_admin) {
        setHasPhoneAccess(true);
        return;
      }

      const { data: staffData } = await supabase
        .from('admin_staff')
        .select('id, role_id')
        .eq('id', user.id)
        .eq('is_active', true)
        .maybeSingle();

      if (staffData) {
        const { data: overrides } = await supabase
          .from('staff_permission_overrides')
          .select('permission_id, is_granted, admin_permissions!inner(code)')
          .eq('staff_id', user.id);

        const hasPhonePerm = overrides?.some(
          (o: any) => o.admin_permissions?.code === 'view_phones_masked' && o.is_granted
        );
        setHasPhoneAccess(hasPhonePerm || false);
      }
    };

    checkPermissions();
  }, [user, profile]);

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
    } else if (mainTab === 'referrers') {
      loadReferrers();
    } else if (mainTab === 'phones') {
      loadPhoneNumbers();
    }
  }, [mainTab, filters, page, pageSize, logTab, dateFilter, phoneSearch]);

  const handleTabChange = useCallback((newTab: MainTab) => {
    setMainTab(newTab);
    if (!isSuperAdmin) {
      loggingService.logStaffPageView(`CRM - ${newTab}`);
    }
  }, [isSuperAdmin]);

  const handleSearchWithLogging = useCallback((query: string, pageName: string) => {
    if (searchDebounceTimer) {
      clearTimeout(searchDebounceTimer);
    }
    const timer = setTimeout(() => {
      if (query && !isSuperAdmin) {
        loggingService.logStaffSearch(query, pageName);
      }
    }, 1000);
    setSearchDebounceTimer(timer);
  }, [searchDebounceTimer, isSuperAdmin]);

  useEffect(() => {
    setPage(0);
  }, [filters]);

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

      console.log('CRM Stats result:', statsResult);
      if (statsResult.error) {
        console.error('CRM Stats error:', statsResult.error);
      }
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
        p_limit: pageSize,
        p_offset: page * pageSize
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

  const loadReferrers = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('execute_sql', {
        query: `
          SELECT
            up.id,
            up.full_name,
            au.email,
            up.referral_code,
            rs.total_referrals,
            rs.tier_2_referrals,
            rs.tier_3_referrals,
            rs.tier_4_referrals,
            rs.tier_5_referrals,
            rs.total_earnings,
            rs.lifetime_earnings,
            rs.this_month_earnings,
            rs.cpa_earnings,
            rs.total_volume_30d,
            rs.total_volume_all_time
          FROM user_profiles up
          INNER JOIN referral_stats rs ON up.id = rs.user_id
          LEFT JOIN auth.users au ON up.id = au.id
          WHERE rs.total_referrals > 0
          ORDER BY rs.total_referrals DESC
        `
      });

      if (error) throw error;
      setReferrers(data || []);
    } catch (error) {
      console.error('Error loading referrers:', error);
      try {
        const { data } = await supabase
          .from('user_profiles')
          .select(`
            id,
            full_name,
            referral_code,
            referral_stats!inner(
              total_referrals,
              tier_2_referrals,
              tier_3_referrals,
              tier_4_referrals,
              tier_5_referrals,
              total_earnings,
              lifetime_earnings,
              this_month_earnings,
              cpa_earnings,
              total_volume_30d,
              total_volume_all_time
            )
          `)
          .gt('referral_stats.total_referrals', 0)
          .order('referral_stats.total_referrals', { ascending: false });

        if (data) {
          const mappedData = data.map((item: any) => ({
            id: item.id,
            full_name: item.full_name,
            email: '',
            referral_code: item.referral_code,
            total_referrals: item.referral_stats.total_referrals,
            tier_2_referrals: item.referral_stats.tier_2_referrals,
            tier_3_referrals: item.referral_stats.tier_3_referrals,
            tier_4_referrals: item.referral_stats.tier_4_referrals,
            tier_5_referrals: item.referral_stats.tier_5_referrals,
            total_earnings: item.referral_stats.total_earnings,
            lifetime_earnings: item.referral_stats.lifetime_earnings,
            this_month_earnings: item.referral_stats.this_month_earnings,
            cpa_earnings: item.referral_stats.cpa_earnings,
            total_volume_30d: item.referral_stats.total_volume_30d,
            total_volume_all_time: item.referral_stats.total_volume_all_time,
          }));
          setReferrers(mappedData);
        }
      } catch (fallbackError) {
        console.error('Fallback query also failed:', fallbackError);
      }
    } finally {
      setLoading(false);
    }
  };

  const loadPhoneNumbers = async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('user_profiles')
        .select('id, full_name, phone, country, kyc_status, created_at')
        .not('phone', 'is', null)
        .neq('phone', '');

      if (phoneSearch) {
        query = query.or(`full_name.ilike.%${phoneSearch}%,phone.ilike.%${phoneSearch}%,country.ilike.%${phoneSearch}%`);
      }

      const { data: profilesData } = await query.order('created_at', { ascending: false });

      if (profilesData) {
        const userIds = profilesData.map(p => p.id);
        const { data: authData } = await supabase.auth.admin.listUsers();

        const emailMap = new Map(
          authData?.users.map(u => [u.id, u.email || '']) || []
        );

        const phoneData: UserPhone[] = profilesData.map(profile => ({
          id: profile.id,
          full_name: profile.full_name || 'No name',
          phone: profile.phone,
          email: emailMap.get(profile.id) || '',
          country: profile.country,
          kyc_status: profile.kyc_status,
          created_at: profile.created_at,
        }));

        setPhoneNumbers(phoneData);
      }
    } catch (error) {
      console.error('Error loading phone numbers:', error);
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
    const dataToExport = mainTab === 'users' ? users
      : mainTab === 'referrers' ? referrers
      : mainTab === 'phones' ? phoneNumbers
      : logs;

    if (!isSuperAdmin) {
      loggingService.logStaffExport(`${mainTab}_${format}`, dataToExport.length);
    }

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

  const handleViewUser = (userId: string, userName?: string) => {
    localStorage.setItem('adminSelectedUserId', userId);
    if (!isSuperAdmin) {
      loggingService.logStaffUserView(userId, userName);
    }
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
            { id: 'analytics', label: 'Analytics', icon: BarChart3, requiresPhoneAccess: false },
            { id: 'users', label: 'User Management', icon: Users, requiresPhoneAccess: false },
            { id: 'referrers', label: 'Referrers', icon: UserPlus, requiresPhoneAccess: false },
            { id: 'phones', label: 'Phone Numbers', icon: Phone, requiresPhoneAccess: true },
            { id: 'segments', label: 'Segments & Tags', icon: Tag, requiresPhoneAccess: false },
            { id: 'popups', label: 'Popup Banners', icon: Image, requiresPhoneAccess: false },
            { id: 'logs', label: 'Activity Logs', icon: Activity, requiresPhoneAccess: false, superAdminOnly: true },
          ]
            .filter(tab => !tab.requiresPhoneAccess || hasPhoneAccess)
            .filter(tab => !tab.superAdminOnly || isSuperAdmin)
            .map((tab) => (
            <button
              key={tab.id}
              onClick={() => handleTabChange(tab.id as MainTab)}
              className={`flex items-center gap-2 px-5 py-3 rounded-xl font-medium transition-all ${
                mainTab === tab.id
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-[#0b0e11] text-gray-400 hover:text-white border border-gray-800 hover:border-gray-700'
              }`}
            >
              <tab.icon className="w-5 h-5" />
              {tab.label}
              {tab.id === 'phones' && !isSuperAdmin && (
                <Lock className="w-3 h-3 text-yellow-400" />
              )}
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
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-lg font-bold text-white">User Management</h2>
                <p className="text-gray-400 text-sm mt-1">
                  Total: <span className="text-[#f0b90b] font-medium">{totalUsers}</span> users registered
                </p>
              </div>
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
            {totalUsers > pageSize && (
              <div className="bg-blue-500/10 border border-blue-500/30 rounded-xl p-4 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Users className="w-5 h-5 text-blue-400" />
                  <div>
                    <p className="text-blue-400 font-medium">
                      Showing {Math.min(pageSize, totalUsers)} of {totalUsers} users
                    </p>
                    <p className="text-blue-400/70 text-sm">
                      Use pagination controls below or change page size to view more users
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => {
                    setPageSize(1000);
                    setPage(0);
                  }}
                  className="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition-colors"
                >
                  Show All Users
                </button>
              </div>
            )}

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
              <div className="overflow-x-auto max-h-[600px] overflow-y-auto">
                <table className="w-full">
                  <thead className="bg-[#1a1d24] sticky top-0 z-10">
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
                              onClick={() => handleViewUser(u.id, u.full_name || u.username)}
                              className="p-2 hover:bg-gray-800 rounded-lg text-gray-400 hover:text-white transition-colors"
                              title="View User Details"
                            >
                              <Eye className="w-4 h-4" />
                            </button>
                            {isSuperAdmin && (
                              <button
                                onClick={() => handleLoginAs(u.id, u.username || 'User')}
                                className="p-2 hover:bg-[#f0b90b]/20 rounded-lg text-gray-400 hover:text-[#f0b90b] transition-colors"
                                title="Login As User"
                              >
                                <LogIn className="w-4 h-4" />
                              </button>
                            )}
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
            </div>

            <div className="bg-[#f0b90b]/10 border-2 border-[#f0b90b]/30 rounded-xl p-5 mt-4">
              <div className="flex items-center justify-between flex-wrap gap-4">
                <div className="flex items-center gap-4">
                  <div className="flex items-center gap-2">
                    <span className="text-gray-300 font-medium text-sm">Show:</span>
                    <select
                      value={pageSize}
                      onChange={(e) => {
                        const value = parseInt(e.target.value);
                        setPageSize(value);
                        setPage(0);
                      }}
                      className="bg-[#0b0e11] border-2 border-[#f0b90b]/50 rounded-lg px-4 py-2 text-white font-medium text-sm outline-none focus:border-[#f0b90b]"
                    >
                      <option value="50">50 users</option>
                      <option value="100">100 users</option>
                      <option value="200">200 users</option>
                      <option value="500">500 users</option>
                      <option value="1000">All users</option>
                    </select>
                  </div>
                  <div className="h-6 w-px bg-[#f0b90b]/30"></div>
                  <p className="text-gray-300 text-sm font-medium">
                    Showing <span className="text-[#f0b90b] font-bold">{page * pageSize + 1}</span> to{' '}
                    <span className="text-[#f0b90b] font-bold">{Math.min((page + 1) * pageSize, totalUsers)}</span> of{' '}
                    <span className="text-[#f0b90b] font-bold">{totalUsers}</span> total users
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setPage(0)}
                    disabled={page === 0}
                    className="px-4 py-2 bg-[#0b0e11] text-white rounded-lg disabled:opacity-30 disabled:cursor-not-allowed hover:bg-[#1f2329] transition-colors font-medium border border-[#f0b90b]/30"
                  >
                    First
                  </button>
                  <button
                    onClick={() => setPage(Math.max(0, page - 1))}
                    disabled={page === 0}
                    className="px-4 py-2 bg-[#0b0e11] text-white rounded-lg disabled:opacity-30 disabled:cursor-not-allowed hover:bg-[#1f2329] transition-colors font-medium border border-[#f0b90b]/30"
                  >
                    Previous
                  </button>
                  <div className="flex items-center gap-2 px-4 py-2 bg-[#0b0e11] border-2 border-[#f0b90b]/50 rounded-lg">
                    <span className="text-white font-medium text-sm">Page</span>
                    <input
                      type="number"
                      min="1"
                      max={Math.ceil(totalUsers / pageSize)}
                      value={page + 1}
                      onChange={(e) => {
                        const newPage = parseInt(e.target.value) - 1;
                        if (newPage >= 0 && newPage < Math.ceil(totalUsers / pageSize)) {
                          setPage(newPage);
                        }
                      }}
                      className="w-16 bg-[#1a1d24] border border-[#f0b90b]/50 rounded px-2 py-1 text-[#f0b90b] font-bold text-sm text-center outline-none focus:border-[#f0b90b]"
                    />
                    <span className="text-white font-medium text-sm">of {Math.ceil(totalUsers / pageSize)}</span>
                  </div>
                  <button
                    onClick={() => setPage(page + 1)}
                    disabled={users.length < pageSize || (page + 1) * pageSize >= totalUsers}
                    className="px-4 py-2 bg-[#0b0e11] text-white rounded-lg disabled:opacity-30 disabled:cursor-not-allowed hover:bg-[#1f2329] transition-colors font-medium border border-[#f0b90b]/30"
                  >
                    Next
                  </button>
                  <button
                    onClick={() => setPage(Math.ceil(totalUsers / pageSize) - 1)}
                    disabled={(page + 1) * pageSize >= totalUsers}
                    className="px-4 py-2 bg-[#0b0e11] text-white rounded-lg disabled:opacity-30 disabled:cursor-not-allowed hover:bg-[#1f2329] transition-colors font-medium border border-[#f0b90b]/30"
                  >
                    Last
                  </button>
                </div>
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

        {mainTab === 'referrers' && (
          <div className="space-y-4">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-lg font-bold text-white">Top Referrers</h2>
                <p className="text-gray-400 text-sm mt-1">
                  Users with active referrals ranked by total referral count
                </p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    const csv = [
                      ['Rank', 'Name', 'Email', 'Referral Code', 'Total Referrals', 'Tier 2', 'Tier 3', 'Tier 4', 'Tier 5', 'Lifetime Earnings', 'This Month', 'CPA Earnings', 'Volume 30d', 'Volume All Time'].join(','),
                      ...referrers.map((r, i) => [
                        i + 1,
                        `"${r.full_name}"`,
                        `"${r.email}"`,
                        r.referral_code,
                        r.total_referrals,
                        r.tier_2_referrals,
                        r.tier_3_referrals,
                        r.tier_4_referrals,
                        r.tier_5_referrals,
                        r.lifetime_earnings,
                        r.this_month_earnings,
                        r.cpa_earnings,
                        r.total_volume_30d,
                        r.total_volume_all_time
                      ].join(','))
                    ].join('\n');
                    downloadFile(csv, `referrers_${Date.now()}.csv`, 'text/csv');
                  }}
                  className="flex items-center gap-2 px-4 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors text-sm"
                >
                  <Download className="w-4 h-4" />
                  Export CSV
                </button>
              </div>
            </div>

            <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-[#1a1d24]">
                    <tr>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Rank</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">User</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Referral Code</th>
                      <th className="px-4 py-3 text-center text-sm font-medium text-gray-400">Total Referrals</th>
                      <th className="px-4 py-3 text-center text-sm font-medium text-gray-400">Tier 2</th>
                      <th className="px-4 py-3 text-center text-sm font-medium text-gray-400">Tier 3+</th>
                      <th className="px-4 py-3 text-right text-sm font-medium text-gray-400">Lifetime Earnings</th>
                      <th className="px-4 py-3 text-right text-sm font-medium text-gray-400">This Month</th>
                      <th className="px-4 py-3 text-right text-sm font-medium text-gray-400">Volume (All Time)</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-800">
                    {referrers.map((referrer, index) => (
                      <tr key={referrer.id} className="hover:bg-[#1a1d24]/50 transition-colors">
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            {index === 0 && <span className="text-2xl">🥇</span>}
                            {index === 1 && <span className="text-2xl">🥈</span>}
                            {index === 2 && <span className="text-2xl">🥉</span>}
                            {index > 2 && <span className="text-gray-400 font-medium">{index + 1}</span>}
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <div>
                            <p className="text-white font-medium">{referrer.full_name}</p>
                            {referrer.email && (
                              <p className="text-gray-500 text-sm">{referrer.email}</p>
                            )}
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <code className="px-2 py-1 bg-[#f0b90b]/10 text-[#f0b90b] rounded font-mono text-sm">
                              {referrer.referral_code}
                            </code>
                            <button
                              onClick={() => copyToClipboard(referrer.referral_code)}
                              className="p-1 hover:bg-gray-800 rounded text-gray-400 hover:text-white"
                              title="Copy code"
                            >
                              <Copy className="w-3 h-3" />
                            </button>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className="px-3 py-1 bg-blue-500/10 text-blue-400 rounded-lg font-bold text-sm">
                            {referrer.total_referrals}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className="text-gray-300 font-medium">{referrer.tier_2_referrals}</span>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className="text-gray-400 text-sm">
                            {referrer.tier_3_referrals + referrer.tier_4_referrals + referrer.tier_5_referrals}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right">
                          <span className="text-green-400 font-medium">
                            ${parseFloat(referrer.lifetime_earnings || '0').toFixed(2)}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right">
                          <span className="text-[#f0b90b] font-medium">
                            ${parseFloat(referrer.this_month_earnings || '0').toFixed(2)}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right">
                          <span className="text-white font-medium">
                            ${formatNumber(parseFloat(referrer.total_volume_all_time || '0'))}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <button
                            onClick={() => handleViewUser(referrer.id, referrer.full_name)}
                            className="p-2 hover:bg-gray-800 rounded-lg text-gray-400 hover:text-white transition-colors"
                            title="View User Details"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>

                {referrers.length === 0 && !loading && (
                  <div className="text-center py-12">
                    <UserPlus className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                    <p className="text-gray-400">No referrers found</p>
                  </div>
                )}
              </div>
            </div>

            {referrers.length > 0 && (
              <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
                <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                  <TrendingUp className="w-5 h-5 text-[#f0b90b]" />
                  Referral Summary
                </h3>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="bg-[#1a1d24] rounded-xl p-4 text-center">
                    <p className="text-3xl font-bold text-blue-400">{referrers.length}</p>
                    <p className="text-gray-400 text-sm mt-1">Total Referrers</p>
                  </div>
                  <div className="bg-[#1a1d24] rounded-xl p-4 text-center">
                    <p className="text-3xl font-bold text-[#f0b90b]">
                      {referrers.reduce((sum, r) => sum + r.total_referrals, 0)}
                    </p>
                    <p className="text-gray-400 text-sm mt-1">Total Referrals</p>
                  </div>
                  <div className="bg-[#1a1d24] rounded-xl p-4 text-center">
                    <p className="text-3xl font-bold text-green-400">
                      ${referrers.reduce((sum, r) => sum + parseFloat(r.lifetime_earnings || '0'), 0).toFixed(2)}
                    </p>
                    <p className="text-gray-400 text-sm mt-1">Total Paid Out</p>
                  </div>
                  <div className="bg-[#1a1d24] rounded-xl p-4 text-center">
                    <p className="text-3xl font-bold text-cyan-400">
                      ${formatNumber(referrers.reduce((sum, r) => sum + parseFloat(r.total_volume_all_time || '0'), 0))}
                    </p>
                    <p className="text-gray-400 text-sm mt-1">Total Volume</p>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {mainTab === 'phones' && (
          <div className="space-y-4">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-lg font-bold text-white">User Phone Numbers</h2>
                <p className="text-gray-400 text-sm mt-1">
                  Total: <span className="text-[#f0b90b] font-medium">{phoneNumbers.length}</span> users with phone numbers
                </p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => handleExport('csv')}
                  className="flex items-center gap-2 px-4 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors text-sm"
                >
                  <Download className="w-4 h-4" />
                  Export CSV
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
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                <input
                  type="text"
                  placeholder="Search by name, phone number, or country..."
                  value={phoneSearch}
                  onChange={(e) => setPhoneSearch(e.target.value)}
                  className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg pl-10 pr-4 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
                />
              </div>
            </div>

            <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden">
              <div className="overflow-x-auto max-h-[600px] overflow-y-auto">
                <table className="w-full">
                  <thead className="bg-[#1a1d24] sticky top-0 z-10">
                    <tr>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Full Name</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Phone Number</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Email</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Country</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">KYC Status</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Registered</th>
                      <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-800">
                    {phoneNumbers.map((phone) => (
                      <tr key={phone.id} className="hover:bg-[#1a1d24]/50 transition-colors">
                        <td className="px-4 py-3">
                          <span className="text-white font-medium">{phone.full_name}</span>
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <PhoneRevealButton
                              userId={phone.id}
                              phone={phone.phone}
                              isSuperAdmin={isSuperAdmin}
                              userName={phone.full_name}
                              compact
                            />
                            {isSuperAdmin && (
                              <button
                                onClick={() => copyToClipboard(phone.phone)}
                                className="p-1 hover:bg-gray-800 rounded text-gray-400 hover:text-white"
                                title="Copy phone number"
                              >
                                <Copy className="w-3 h-3" />
                              </button>
                            )}
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <span className="text-gray-400 text-sm">{phone.email}</span>
                        </td>
                        <td className="px-4 py-3">
                          <span className="text-gray-300">{phone.country || 'N/A'}</span>
                        </td>
                        <td className="px-4 py-3">
                          <span className={`px-2 py-1 rounded-lg text-xs font-medium ${
                            phone.kyc_status === 'verified'
                              ? 'bg-green-500/10 text-green-400'
                              : phone.kyc_status === 'pending'
                              ? 'bg-yellow-500/10 text-yellow-400'
                              : 'bg-gray-500/10 text-gray-400'
                          }`}>
                            {phone.kyc_status}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-gray-400 text-sm">
                          {new Date(phone.created_at).toLocaleDateString()}
                        </td>
                        <td className="px-4 py-3">
                          <button
                            onClick={() => handleViewUser(phone.id, phone.full_name)}
                            className="p-2 hover:bg-gray-800 rounded-lg text-gray-400 hover:text-white transition-colors"
                            title="View User Details"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>

                {phoneNumbers.length === 0 && !loading && (
                  <div className="text-center py-12">
                    <Phone className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                    <p className="text-gray-400">No phone numbers found</p>
                  </div>
                )}
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
