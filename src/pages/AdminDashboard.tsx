import { useState, useEffect } from 'react';
import { Users, Search, TrendingUp, DollarSign, AlertTriangle, Activity, Shield, Filter, X, ArrowUpDown, LogIn, Copy, ExternalLink, AlertCircle, Check, Bot, UserPlus, Eye, Image, Megaphone, Send, RefreshCw, Gift } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';

interface UserSummary {
  id: string;
  email: string;
  username: string | null;
  full_name: string | null;
  kyc_status: string;
  kyc_level: number;
  created_at: string;
  total_balance: number;
  open_positions: number;
  unrealized_pnl: number;
  vip_tier?: string;
  is_online?: boolean;
  last_activity?: string;
  has_referrer?: boolean;
  referral_count?: number;
}

export default function AdminDashboard() {
  const { user, canAccessAdmin, hasPermission, staffInfo, profile, loading: authLoading } = useAuth();
  const { navigateTo } = useNavigation();
  const [users, setUsers] = useState<UserSummary[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalUsers: 0,
    activeTraders: 0,
    totalVolume24h: 0,
    totalPnl24h: 0,
    pendingKyc: 0,
    atRiskPositions: 0
  });
  const [hasAccess, setHasAccess] = useState(false);
  const [showFilters, setShowFilters] = useState(false);

  // Filter states
  const [filterVipTier, setFilterVipTier] = useState<string>('all');
  const [filterKycStatus, setFilterKycStatus] = useState<string>('all');
  const [filterBalance, setFilterBalance] = useState<string>('all');
  const [filterPositions, setFilterPositions] = useState<string>('all');
  const [filterOnlineStatus, setFilterOnlineStatus] = useState<string>('all');
  const [filterReferralStatus, setFilterReferralStatus] = useState<string>('all');
  const [sortBy, setSortBy] = useState<string>('newest');

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

  const [broadcastModal, setBroadcastModal] = useState<{
    show: boolean;
    loading: boolean;
    title: string;
    message: string;
    notificationType: string;
    redirectUrl: string;
    success: string | null;
    error: string | null;
  }>({
    show: false,
    loading: false,
    title: '',
    message: '',
    notificationType: 'reward',
    redirectUrl: 'referral',
    success: null,
    error: null,
  });

  const broadcastTemplates = [
    {
      id: 'first_deposit_bonus',
      name: '100% Deposit Bonus',
      title: 'Get 100% Bonus on Your Deposit!',
      message: 'Deposit now and get a 100% bonus match up to $500 USD! Double your trading power and maximize your potential profits. Limited time offer - deposit today!',
      notificationType: 'reward',
      redirectUrl: 'deposit',
    },
    {
      id: 'referral_reward',
      name: 'Referral Reward Reminder',
      title: 'Earn 20 USDT - Refer a Friend Today!',
      message: 'When your verified referral deposits $100 USD, you BOTH receive 20 USDT each. Share your referral link now and start earning!',
      notificationType: 'reward',
      redirectUrl: 'referral',
    },
    {
      id: 'copy_trading_promo',
      name: 'Copy Trading Promotion',
      title: 'Start Copy Trading Today!',
      message: 'Follow top traders and automatically copy their trades. Let the experts work for you while you earn!',
      notificationType: 'reward',
      redirectUrl: 'copytrading',
    },
    {
      id: 'vip_upgrade',
      name: 'VIP Benefits Reminder',
      title: 'Unlock VIP Trading Benefits!',
      message: 'Increase your trading volume to unlock VIP status! Enjoy lower fees, higher rebates, and exclusive perks. Check your VIP progress now.',
      notificationType: 'reward',
      redirectUrl: 'vip',
    },
    {
      id: 'market_opportunity',
      name: 'Market Opportunity Alert',
      title: 'Market Volatility = Trading Opportunity!',
      message: 'Markets are moving! High volatility periods offer exceptional trading opportunities. Open positions now and capitalize on price swings.',
      notificationType: 'system',
      redirectUrl: 'futures',
    },
    {
      id: 'kyc_reminder',
      name: 'KYC Verification Reminder',
      title: 'Complete Your Verification',
      message: 'Verify your identity to unlock full platform features including higher withdrawal limits and exclusive bonuses. Takes less than 5 minutes!',
      notificationType: 'system',
      redirectUrl: 'kyc',
    },
    {
      id: 'inactive_user',
      name: 'We Miss You!',
      title: 'Welcome Back - Special Offer Inside!',
      message: 'We noticed you have been away. Come back and trade today - the markets are waiting for you! Check out our latest promotions.',
      notificationType: 'reward',
      redirectUrl: 'deposit',
    },
    {
      id: 'new_feature',
      name: 'New Feature Announcement',
      title: 'New Features Available!',
      message: 'We have added exciting new features to improve your trading experience. Explore the latest updates and enhancements now!',
      notificationType: 'system',
      redirectUrl: 'futures',
    },
  ];

  // Pagination state
  const [currentPage, setCurrentPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);

  useEffect(() => {
    if (authLoading) return;
    checkAccess();
  }, [user, staffInfo, authLoading]);

  useEffect(() => {
    if (hasAccess) {
      loadData();
    }
  }, [hasAccess, profile, staffInfo]);

  useEffect(() => {
    if (!hasAccess) return;

    const channel = supabase
      .channel('admin-user-sessions')
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
  }, [hasAccess]);

  useEffect(() => {
    if (!hasAccess) return;

    const refreshOnlineStatus = async () => {
      try {
        const { data: sessions } = await supabase
          .from('user_sessions')
          .select('user_id, is_online, last_activity, heartbeat');

        if (sessions) {
          const now = Date.now();
          const sessionsMap = new Map(
            sessions.map(s => {
              const heartbeat = new Date(s.heartbeat || s.last_activity).getTime();
              const isOnline = s.is_online && (now - heartbeat) < 2 * 60 * 1000;
              return [s.user_id, { is_online: isOnline, last_activity: s.last_activity }];
            })
          );

          setUsers(prevUsers => prevUsers.map(user => ({
            ...user,
            is_online: sessionsMap.get(user.id)?.is_online || false,
            last_activity: sessionsMap.get(user.id)?.last_activity || user.last_activity,
          })));
        }
      } catch (error) {
        console.error('Failed to refresh online status:', error);
      }
    };

    const interval = setInterval(refreshOnlineStatus, 15000);

    return () => clearInterval(interval);
  }, [hasAccess]);

  const checkAccess = async () => {
    if (authLoading) return;

    if (!user) {
      navigateTo('signin');
      return;
    }

    if (canAccessAdmin()) {
      setHasAccess(true);
    } else {
      navigateTo('home');
    }
  };

  const loadData = async () => {
    setLoading(true);
    try {
      await Promise.all([
        loadUsers(),
        loadStats()
      ]);
    } catch (error) {
      console.error('Error loading admin data:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadUsers = async () => {
    if (!hasPermission('view_users')) {
      setUsers([]);
      return;
    }

    try {
      const [usersResult, sessionsResult] = await Promise.all([
        supabase.rpc('get_admin_users_list'),
        supabase.from('user_sessions').select('user_id, is_online, last_activity, heartbeat')
      ]);

      if (usersResult.error || !usersResult.data) {
        console.error('Error loading users with RPC:', usersResult.error);
        await loadUsersDirectly();
        return;
      }

      const now = Date.now();
      const sessionsMap = new Map(
        sessionsResult.data?.map(s => {
          const heartbeat = new Date(s.heartbeat || s.last_activity).getTime();
          const isOnline = s.is_online && (now - heartbeat) < 2 * 60 * 1000;
          return [s.user_id, { is_online: isOnline, last_activity: s.last_activity }];
        }) || []
      );

      const usersWithOnlineStatus = usersResult.data.map(u => ({
        ...u,
        is_online: sessionsMap.get(u.id)?.is_online || false,
        last_activity: sessionsMap.get(u.id)?.last_activity,
      }));

      setUsers(usersWithOnlineStatus);
    } catch (err) {
      console.error('Failed to load users:', err);
      await loadUsersDirectly();
    }
  };

  const loadUsersDirectly = async () => {
    const { data: profiles } = await supabase
      .from('user_profiles')
      .select(`
        id,
        username,
        full_name,
        kyc_status,
        kyc_level,
        created_at,
        referred_by
      `)
      .order('created_at', { ascending: false });

    if (!profiles) return;

    const [walletsRes, positionsRes, vipRes, referralRes, sessionsRes] = await Promise.all([
      supabase.from('wallets').select('user_id, balance'),
      supabase.from('futures_positions').select('user_id, unrealized_pnl').eq('status', 'open'),
      supabase.from('user_vip_status').select('user_id, current_level'),
      supabase.from('referral_stats').select('user_id, total_referrals'),
      supabase.from('user_sessions').select('user_id, is_online, last_activity, heartbeat')
    ]);

    const walletMap = new Map<string, number>();
    walletsRes.data?.forEach(w => {
      const current = walletMap.get(w.user_id) || 0;
      walletMap.set(w.user_id, current + parseFloat(w.balance || '0'));
    });

    const positionMap = new Map<string, { count: number; pnl: number }>();
    positionsRes.data?.forEach(p => {
      const current = positionMap.get(p.user_id) || { count: 0, pnl: 0 };
      positionMap.set(p.user_id, {
        count: current.count + 1,
        pnl: current.pnl + parseFloat(p.unrealized_pnl || '0')
      });
    });

    const vipMap = new Map(vipRes.data?.map(v => [v.user_id, v.current_level]) || []);
    const referralMap = new Map(referralRes.data?.map(r => [r.user_id, r.total_referrals]) || []);

    const now = Date.now();
    const sessionsMap = new Map(
      sessionsRes.data?.map(s => {
        const heartbeat = new Date(s.heartbeat || s.last_activity).getTime();
        const isOnline = s.is_online && (now - heartbeat) < 2 * 60 * 1000;
        return [s.user_id, { is_online: isOnline, last_activity: s.last_activity }];
      }) || []
    );

    const emailMap = new Map<string, string>();
    const userIds = profiles.map(p => p.id);
    const { data: emailsData } = await supabase.rpc('get_user_emails_bulk', { user_ids: userIds });
    emailsData?.forEach((e: { user_id: string; email: string }) => emailMap.set(e.user_id, e.email || 'N/A'));

    const usersWithData = profiles.map(profile => ({
      id: profile.id,
      email: emailMap.get(profile.id) || 'N/A',
      username: profile.username,
      full_name: profile.full_name,
      kyc_status: profile.kyc_status,
      kyc_level: profile.kyc_level,
      created_at: profile.created_at,
      total_balance: walletMap.get(profile.id) || 0,
      open_positions: positionMap.get(profile.id)?.count || 0,
      unrealized_pnl: positionMap.get(profile.id)?.pnl || 0,
      vip_tier: vipMap.get(profile.id) || 'None',
      has_referrer: !!profile.referred_by,
      referral_count: referralMap.get(profile.id) || 0,
      is_online: sessionsMap.get(profile.id)?.is_online || false,
      last_activity: sessionsMap.get(profile.id)?.last_activity
    }));

    setUsers(usersWithData);
  };

  const loadStats = async () => {
    try {
      const { data: statsData, error } = await supabase.rpc('get_admin_stats_v2');

      if (error) {
        console.error('Error loading stats:', error);
        return;
      }

      setStats({
        totalUsers: statsData.total_users || 0,
        activeTraders: statsData.active_traders || 0,
        totalVolume24h: parseFloat(statsData.volume_24h) || 0,
        totalPnl24h: parseFloat(statsData.pnl_24h) || 0,
        pendingKyc: statsData.pending_kyc || 0,
        atRiskPositions: statsData.at_risk_positions || 0
      });
    } catch (err) {
      console.error('Failed to load stats:', err);
    }
  };

  const allFilteredUsers = users
    .filter(u => {
      // Search filter
      const matchesSearch = u.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (u.username || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
        (u.full_name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
        u.id.includes(searchTerm);

      if (!matchesSearch) return false;

      // VIP tier filter
      if (filterVipTier !== 'all') {
        if (filterVipTier === 'none' && u.vip_tier !== 'None') return false;
        if (filterVipTier !== 'none' && u.vip_tier !== filterVipTier) return false;
      }

      // KYC status filter
      if (filterKycStatus !== 'all' && u.kyc_status !== filterKycStatus) return false;

      // Balance filter
      if (filterBalance === 'has_balance' && u.total_balance <= 0) return false;
      if (filterBalance === 'no_balance' && u.total_balance > 0) return false;
      if (filterBalance === 'high_balance' && u.total_balance < 1000) return false;
      if (filterBalance === 'very_high' && u.total_balance < 10000) return false;

      // Positions filter
      if (filterPositions === 'has_positions' && u.open_positions === 0) return false;
      if (filterPositions === 'no_positions' && u.open_positions > 0) return false;
      if (filterPositions === 'multiple_positions' && u.open_positions < 2) return false;

      // Online status filter
      if (filterOnlineStatus === 'online' && !u.is_online) return false;
      if (filterOnlineStatus === 'offline' && u.is_online) return false;

      // Referral status filter
      if (filterReferralStatus === 'no_referrer' && u.has_referrer) return false;
      if (filterReferralStatus === 'has_referrer' && !u.has_referrer) return false;
      if (filterReferralStatus === 'has_referrals' && (u.referral_count || 0) === 0) return false;
      if (filterReferralStatus === 'no_referrals' && (u.referral_count || 0) > 0) return false;

      return true;
    })
    .sort((a, b) => {
      switch (sortBy) {
        case 'newest':
          return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
        case 'oldest':
          return new Date(a.created_at).getTime() - new Date(b.created_at).getTime();
        case 'highest_balance':
          return b.total_balance - a.total_balance;
        case 'lowest_balance':
          return a.total_balance - b.total_balance;
        case 'most_positions':
          return b.open_positions - a.open_positions;
        case 'highest_pnl':
          return b.unrealized_pnl - a.unrealized_pnl;
        case 'lowest_pnl':
          return a.unrealized_pnl - b.unrealized_pnl;
        case 'username_az':
          return a.username.localeCompare(b.username);
        case 'username_za':
          return b.username.localeCompare(a.username);
        default:
          return 0;
      }
    });

  // Paginate the filtered results
  const totalFilteredUsers = allFilteredUsers.length;
  const totalPages = Math.ceil(totalFilteredUsers / pageSize);
  const startIndex = currentPage * pageSize;
  const endIndex = startIndex + pageSize;
  const filteredUsers = allFilteredUsers.slice(startIndex, endIndex);

  // Reset to first page when filters change
  useEffect(() => {
    setCurrentPage(0);
  }, [searchTerm, filterVipTier, filterKycStatus, filterBalance, filterPositions, filterOnlineStatus, filterReferralStatus, sortBy]);

  const clearFilters = () => {
    setFilterVipTier('all');
    setFilterKycStatus('all');
    setFilterBalance('all');
    setFilterPositions('all');
    setFilterOnlineStatus('all');
    setFilterReferralStatus('all');
    setSortBy('newest');
  };

  const activeFilterCount = [
    filterVipTier !== 'all',
    filterKycStatus !== 'all',
    filterBalance !== 'all',
    filterPositions !== 'all',
    filterOnlineStatus !== 'all',
    filterReferralStatus !== 'all',
    sortBy !== 'newest'
  ].filter(Boolean).length;

  const getKycBadgeColor = (status: string) => {
    switch (status) {
      case 'verified': return 'bg-green-500/20 text-green-400 border-green-500/30';
      case 'pending': return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30';
      case 'rejected': return 'bg-red-500/20 text-red-400 border-red-500/30';
      default: return 'bg-gray-500/20 text-gray-400 border-gray-500/30';
    }
  };

  const isSuperAdmin = profile?.is_admin || staffInfo?.is_super_admin;

  const handleSelectTemplate = (templateId: string) => {
    const template = broadcastTemplates.find(t => t.id === templateId);
    if (template) {
      setBroadcastModal(prev => ({
        ...prev,
        title: template.title,
        message: template.message,
        notificationType: template.notificationType,
        redirectUrl: template.redirectUrl,
      }));
    }
  };

  const handleBroadcastNotification = async () => {
    if (!user || !broadcastModal.title || !broadcastModal.message) {
      setBroadcastModal(prev => ({
        ...prev,
        error: 'Title and message are required',
      }));
      return;
    }

    setBroadcastModal(prev => ({ ...prev, loading: true, error: null, success: null }));

    try {
      const { data, error } = await supabase.rpc('broadcast_notification_to_all_users', {
        p_admin_id: user.id,
        p_title: broadcastModal.title,
        p_message: broadcastModal.message,
        p_notification_type: broadcastModal.notificationType,
        p_redirect_url: broadcastModal.redirectUrl || null,
      });

      if (error) throw error;

      if (data?.success) {
        setBroadcastModal(prev => ({
          ...prev,
          loading: false,
          success: `Successfully sent notification to ${data.user_count} users!`,
          title: '',
          message: '',
        }));
      } else {
        throw new Error(data?.error || 'Failed to broadcast notification');
      }
    } catch (error: any) {
      setBroadcastModal(prev => ({
        ...prev,
        loading: false,
        error: error.message || 'Failed to send broadcast notification',
      }));
    }
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
            reason: 'Admin support session from Dashboard',
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

  if (!hasAccess) {
    return null;
  }

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="mb-8">
          <div className="flex items-center justify-between flex-wrap gap-4">
            <div>
              <div className="flex items-center gap-3 mb-2">
                <h1 className="text-3xl font-bold text-white">Admin Dashboard</h1>
                {staffInfo?.role_name && !staffInfo.is_super_admin && (
                  <span className="px-3 py-1 bg-[#f0b90b]/10 text-[#f0b90b] border border-[#f0b90b]/30 rounded-lg text-sm font-medium">
                    {staffInfo.role_name}
                  </span>
                )}
              </div>
              <p className="text-gray-400">Manage users, monitor trading activity, and oversee platform operations</p>
            </div>
            <div className="flex gap-3 flex-wrap">
              {isSuperAdmin && (
                <button
                  onClick={() => setBroadcastModal(prev => ({ ...prev, show: true, error: null, success: null }))}
                  className="bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 text-white px-6 py-3 rounded-lg font-bold transition-all flex items-center gap-2 shadow-lg"
                >
                  <Megaphone className="w-5 h-5" />
                  Broadcast
                </button>
              )}

              {isSuperAdmin && (
                <button
                  onClick={() => navigateTo('adminstaff')}
                  className="bg-[#f0b90b] hover:bg-[#f8d12f] text-black px-6 py-3 rounded-lg font-bold transition-all flex items-center gap-2"
                >
                  <Shield className="w-5 h-5" />
                  Staff Management
                </button>
              )}

              {hasPermission('manage_support') && (
                <button
                  onClick={() => navigateTo('adminsupport')}
                  className="bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 px-6 py-3 rounded-lg font-bold transition-all border border-cyan-500/30"
                >
                  Support
                </button>
              )}

              {hasPermission('manage_email_templates') && (
                <button
                  onClick={() => navigateTo('adminemails')}
                  className="bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 px-6 py-3 rounded-lg font-bold transition-all border border-blue-500/30"
                >
                  Email Templates
                </button>
              )}

              {hasPermission('manage_bonus_types') && (
                <button
                  onClick={() => navigateTo('adminbonuses')}
                  className="bg-green-500/10 hover:bg-green-500/20 text-green-400 px-6 py-3 rounded-lg font-bold transition-all border border-green-500/30"
                >
                  Bonus Types
                </button>
              )}

              {hasPermission('view_vip') && (
                <button
                  onClick={() => navigateTo('adminviptracking')}
                  className="bg-yellow-500/10 hover:bg-yellow-500/20 text-yellow-400 px-6 py-3 rounded-lg font-bold transition-all border border-yellow-500/30"
                >
                  VIP Tracking
                </button>
              )}

              {isSuperAdmin && (
                <button
                  onClick={() => navigateTo('admintelegram')}
                  className="bg-[#00bcd4]/10 hover:bg-[#00bcd4]/20 text-[#00bcd4] px-6 py-3 rounded-lg font-bold transition-all border border-[#00bcd4]/30 flex items-center gap-2"
                >
                  <Bot className="w-5 h-5" />
                  Telegram CRM
                </button>
              )}

              {hasPermission('view_shark_cards') && (
                <button
                  onClick={() => navigateTo('adminsharkcards')}
                  className="bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 px-6 py-3 rounded-lg font-bold transition-all border border-amber-500/30"
                >
                  Shark Cards
                </button>
              )}

              {hasPermission('view_function_logs') && (
                <button
                  onClick={() => navigateTo('adminlogs')}
                  className="bg-teal-500/10 hover:bg-teal-500/20 text-teal-400 px-6 py-3 rounded-lg font-bold transition-all border border-teal-500/30"
                >
                  Function Logs
                </button>
              )}

              {hasPermission('view_logs') && (
                <button
                  onClick={() => navigateTo('admincrm')}
                  className="bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 px-6 py-3 rounded-lg font-bold transition-all border border-rose-500/30"
                >
                  CRM & Logs
                </button>
              )}

              {hasPermission('manage_traders') && (
                <button
                  onClick={() => navigateTo('admintrader')}
                  className="bg-orange-500/10 hover:bg-orange-500/20 text-orange-400 px-6 py-3 rounded-lg font-bold transition-all border border-orange-500/30"
                >
                  Manage Trader
                </button>
              )}

              {(isSuperAdmin || hasPermission('view_users')) && (
                <button
                  onClick={() => navigateTo('adminwithdrawals')}
                  className="bg-purple-500/10 hover:bg-purple-500/20 text-purple-400 px-6 py-3 rounded-lg font-bold transition-all border border-purple-500/30"
                >
                  Withdrawals
                </button>
              )}

              {(isSuperAdmin || hasPermission('view_wallets')) && (
                <button
                  onClick={() => navigateTo('admindeposits')}
                  className="bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 px-6 py-3 rounded-lg font-bold transition-all border border-emerald-500/30"
                >
                  Deposits
                </button>
              )}

              {isSuperAdmin && (
                <button
                  onClick={() => navigateTo('adminreferrals')}
                  className="bg-pink-500/10 hover:bg-pink-500/20 text-pink-400 px-6 py-3 rounded-lg font-bold transition-all border border-pink-500/30 flex items-center gap-2"
                >
                  <UserPlus className="w-5 h-5" />
                  Referral Tracking
                </button>
              )}

              {isSuperAdmin && (
                <button
                  onClick={() => navigateTo('adminpopups')}
                  className="bg-sky-500/10 hover:bg-sky-500/20 text-sky-400 px-6 py-3 rounded-lg font-bold transition-all border border-sky-500/30 flex items-center gap-2"
                >
                  <Image className="w-5 h-5" />
                  Popup Banners
                </button>
              )}

              {isSuperAdmin && (
                <button
                  onClick={() => navigateTo('admingiveaway')}
                  className="bg-yellow-500/10 hover:bg-yellow-500/20 text-yellow-400 px-6 py-3 rounded-lg font-bold transition-all border border-yellow-500/30 flex items-center gap-2"
                >
                  <TrendingUp className="w-5 h-5" />
                  Giveaway
                </button>
              )}

              {(isSuperAdmin || hasPermission('view_acquisition')) && (
                <button
                  onClick={() => navigateTo('adminacquisition')}
                  className="bg-teal-500/10 hover:bg-teal-500/20 text-teal-400 px-6 py-3 rounded-lg font-bold transition-all border border-teal-500/30 flex items-center gap-2"
                >
                  <Activity className="w-5 h-5" />
                  User Acquisition
                </button>
              )}

              {isSuperAdmin && (
                <button
                  onClick={() => navigateTo('adminexclusiveaffiliates')}
                  className="bg-[#f0b90b]/10 hover:bg-[#f0b90b]/20 text-[#f0b90b] px-6 py-3 rounded-lg font-bold transition-all border border-[#f0b90b]/30 flex items-center gap-2"
                >
                  <Shield className="w-5 h-5" />
                  Exclusive Affiliates
                </button>
              )}
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-blue-500/10 rounded-xl flex items-center justify-center">
                <Users className="w-6 h-6 text-blue-400" />
              </div>
              <span className="text-sm text-gray-400">Total</span>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stats.totalUsers.toLocaleString()}</h3>
            <p className="text-sm text-gray-400">Registered Users</p>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-green-500/10 rounded-xl flex items-center justify-center">
                <Activity className="w-6 h-6 text-green-400" />
              </div>
              <span className="text-sm text-gray-400">Active</span>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stats.activeTraders.toLocaleString()}</h3>
            <p className="text-sm text-gray-400">Active Traders</p>
          </div>

          {hasPermission('view_trading') && (
            <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
              <div className="flex items-center justify-between mb-4">
                <div className="w-12 h-12 bg-[#f0b90b]/10 rounded-xl flex items-center justify-center">
                  <TrendingUp className="w-6 h-6 text-[#f0b90b]" />
                </div>
                <span className="text-sm text-gray-400">24h</span>
              </div>
              <h3 className="text-2xl font-bold text-white mb-1">${stats.totalVolume24h.toLocaleString(undefined, { maximumFractionDigits: 0 })}</h3>
              <p className="text-sm text-gray-400">Trading Volume</p>
            </div>
          )}

          {hasPermission('view_wallets') && (
            <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
              <div className="flex items-center justify-between mb-4">
                <div className="w-12 h-12 bg-yellow-500/10 rounded-xl flex items-center justify-center">
                  <DollarSign className="w-6 h-6 text-yellow-400" />
                </div>
                <span className="text-sm text-gray-400">24h</span>
              </div>
              <h3 className={`text-2xl font-bold mb-1 ${stats.totalPnl24h >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                ${Math.abs(stats.totalPnl24h).toLocaleString(undefined, { maximumFractionDigits: 2 })}
              </h3>
              <p className="text-sm text-gray-400">Total P&L</p>
            </div>
          )}

          {hasPermission('view_kyc') && (
            <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
              <div className="flex items-center justify-between mb-4">
                <div className="w-12 h-12 bg-orange-500/10 rounded-xl flex items-center justify-center">
                  <Users className="w-6 h-6 text-orange-400" />
                </div>
                <span className="text-sm text-gray-400">Pending</span>
              </div>
              <h3 className="text-2xl font-bold text-white mb-1">{stats.pendingKyc}</h3>
              <p className="text-sm text-gray-400">KYC Verifications</p>
            </div>
          )}

          {hasPermission('view_risk') && (
            <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
              <div className="flex items-center justify-between mb-4">
                <div className="w-12 h-12 bg-red-500/10 rounded-xl flex items-center justify-center">
                  <AlertTriangle className="w-6 h-6 text-red-400" />
                </div>
                <span className="text-sm text-gray-400">At Risk</span>
              </div>
              <h3 className="text-2xl font-bold text-white mb-1">{stats.atRiskPositions}</h3>
              <p className="text-sm text-gray-400">Liquidation Queue</p>
            </div>
          )}
        </div>

        {hasPermission('view_users') && (
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="mb-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-bold text-white">User Management</h2>
                <button
                  onClick={() => setShowFilters(!showFilters)}
                  className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all ${
                    showFilters
                      ? 'bg-[#f0b90b] text-black'
                      : 'bg-[#0b0e11] text-white hover:bg-[#0f1318] border border-gray-700'
                  }`}
                >
                  <Filter className="w-4 h-4" />
                  Filters
                  {activeFilterCount > 0 && (
                    <span className="bg-black/30 px-2 py-0.5 rounded-full text-xs">
                      {activeFilterCount}
                    </span>
                  )}
                </button>
              </div>

              <div className="relative mb-4">
                <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search by email, username, or user ID..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl pl-12 pr-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors"
                />
              </div>

              {showFilters && (
                <div className="bg-[#0b0e11] border border-gray-700 rounded-xl p-4 mb-4">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-white font-semibold flex items-center gap-2">
                      <Filter className="w-4 h-4" />
                      Filter & Sort Options
                    </h3>
                    {activeFilterCount > 0 && (
                      <button
                        onClick={clearFilters}
                        className="text-sm text-gray-400 hover:text-white flex items-center gap-1"
                      >
                        <X className="w-4 h-4" />
                        Clear All
                      </button>
                    )}
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {/* VIP Tier Filter */}
                    <div>
                      <label className="block text-sm text-gray-400 mb-2">VIP Tier</label>
                      <select
                        value={filterVipTier}
                        onChange={(e) => setFilterVipTier(e.target.value)}
                        className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      >
                        <option value="all">All Tiers</option>
                        <option value="none">No VIP</option>
                        <option value="VIP 1">VIP 1</option>
                        <option value="VIP 2">VIP 2</option>
                        <option value="VIP 3">VIP 3</option>
                        <option value="VIP 4">VIP 4</option>
                        <option value="VIP 5">VIP 5</option>
                        <option value="VIP 6">VIP 6</option>
                        <option value="VIP 7">VIP 7</option>
                        <option value="VIP 8">VIP 8</option>
                      </select>
                    </div>

                    {/* KYC Status Filter */}
                    <div>
                      <label className="block text-sm text-gray-400 mb-2">KYC Status</label>
                      <select
                        value={filterKycStatus}
                        onChange={(e) => setFilterKycStatus(e.target.value)}
                        className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      >
                        <option value="all">All Statuses</option>
                        <option value="verified">Verified Only</option>
                        <option value="pending">Pending Only</option>
                        <option value="rejected">Rejected Only</option>
                        <option value="none">Not Submitted</option>
                      </select>
                    </div>

                    {/* Balance Filter */}
                    <div>
                      <label className="block text-sm text-gray-400 mb-2">Balance</label>
                      <select
                        value={filterBalance}
                        onChange={(e) => setFilterBalance(e.target.value)}
                        className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      >
                        <option value="all">All Balances</option>
                        <option value="has_balance">Has Balance (&gt; $0)</option>
                        <option value="no_balance">No Balance ($0)</option>
                        <option value="high_balance">High Balance (&gt; $1,000)</option>
                        <option value="very_high">Very High (&gt; $10,000)</option>
                      </select>
                    </div>

                    {/* Positions Filter */}
                    <div>
                      <label className="block text-sm text-gray-400 mb-2">Active Positions</label>
                      <select
                        value={filterPositions}
                        onChange={(e) => setFilterPositions(e.target.value)}
                        className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      >
                        <option value="all">All Users</option>
                        <option value="has_positions">Has Positions</option>
                        <option value="no_positions">No Positions</option>
                        <option value="multiple_positions">Multiple Positions (2+)</option>
                      </select>
                    </div>

                    {/* Online Status Filter */}
                    <div>
                      <label className="block text-sm text-gray-400 mb-2">Online Status</label>
                      <select
                        value={filterOnlineStatus}
                        onChange={(e) => setFilterOnlineStatus(e.target.value)}
                        className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      >
                        <option value="all">All Users</option>
                        <option value="online">Online Only</option>
                        <option value="offline">Offline Only</option>
                      </select>
                    </div>

                    {/* Referral Status Filter */}
                    <div>
                      <label className="block text-sm text-gray-400 mb-2">Referral Status</label>
                      <select
                        value={filterReferralStatus}
                        onChange={(e) => setFilterReferralStatus(e.target.value)}
                        className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      >
                        <option value="all">All Users</option>
                        <option value="no_referrer">No Referrer (Organic)</option>
                        <option value="has_referrer">Has Referrer</option>
                        <option value="has_referrals">Has Referred Others</option>
                        <option value="no_referrals">Has Not Referred Anyone</option>
                      </select>
                    </div>

                    {/* Sort By */}
                    <div className="md:col-span-2">
                      <label className="block text-sm text-gray-400 mb-2 flex items-center gap-2">
                        <ArrowUpDown className="w-4 h-4" />
                        Sort By
                      </label>
                      <select
                        value={sortBy}
                        onChange={(e) => setSortBy(e.target.value)}
                        className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      >
                        <option value="newest">Newest First</option>
                        <option value="oldest">Oldest First</option>
                        <option value="highest_balance">Highest Balance</option>
                        <option value="lowest_balance">Lowest Balance</option>
                        <option value="most_positions">Most Positions</option>
                        <option value="highest_pnl">Highest P&L</option>
                        <option value="lowest_pnl">Lowest P&L</option>
                        <option value="username_az">Username (A-Z)</option>
                        <option value="username_za">Username (Z-A)</option>
                      </select>
                    </div>
                  </div>

                  <div className="mt-4 pt-4 border-t border-gray-700 text-sm text-gray-400">
                    Showing {totalFilteredUsers} of {users.length} users
                  </div>
                </div>
              )}
            </div>

            {loading ? (
              <div className="text-center py-12">
                <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
                <p className="text-gray-400 mt-4">Loading users...</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-800">
                      <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">User</th>
                      <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">VIP</th>
                      <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">KYC Status</th>
                      {hasPermission('view_wallets') && (
                        <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Balance (USDT)</th>
                      )}
                      {hasPermission('view_trading') && (
                        <>
                          <th className="text-center py-3 px-4 text-sm font-medium text-gray-400">Positions</th>
                          <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Unrealized P&L</th>
                        </>
                      )}
                      <th className="text-center py-3 px-4 text-sm font-medium text-gray-400">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredUsers.map((user) => (
                      <tr key={user.id} className="border-b border-gray-800/50 hover:bg-[#0b0e11] transition-colors">
                        <td className="py-4 px-4">
                          <div>
                            <div className="flex items-center gap-2">
                              <div className={`w-2 h-2 rounded-full ${user.is_online ? 'bg-green-400' : 'bg-gray-600'}`} title={user.is_online ? 'Online' : 'Offline'}></div>
                              <div>
                                <div className="text-white font-medium">{user.full_name || 'No name'}</div>
                                {user.username && (
                                  <div className="text-gray-400 text-sm">@{user.username}</div>
                                )}
                              </div>
                            </div>
                            <div className="text-sm text-gray-400">{user.email}</div>
                            <div className="text-xs text-gray-500 mt-1">ID: {user.id.slice(0, 8)}...</div>
                          </div>
                        </td>
                        <td className="py-4 px-4">
                          {user.vip_tier && user.vip_tier !== 'None' ? (
                            <span className="inline-flex items-center px-2 py-1 rounded-lg border bg-[#f0b90b]/10 text-[#f0b90b] border-[#f0b90b]/30 text-xs font-medium">
                              {user.vip_tier}
                            </span>
                          ) : (
                            <span className="text-xs text-gray-500">-</span>
                          )}
                        </td>
                        <td className="py-4 px-4">
                          <div className="flex flex-col gap-1">
                            <span className={`inline-flex items-center px-2 py-1 rounded-lg border text-xs font-medium w-fit ${getKycBadgeColor(user.kyc_status)}`}>
                              {user.kyc_status.toUpperCase()}
                            </span>
                            <span className="text-xs text-gray-400">Level {user.kyc_level}</span>
                          </div>
                        </td>
                        {hasPermission('view_wallets') && (
                          <td className="py-4 px-4 text-right text-white font-medium">
                            ${(user.total_balance || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          </td>
                        )}
                        {hasPermission('view_trading') && (
                          <>
                            <td className="py-4 px-4 text-center">
                              <span className="inline-flex items-center justify-center w-8 h-8 bg-blue-500/10 text-blue-400 rounded-lg font-medium">
                                {user.open_positions || 0}
                              </span>
                            </td>
                            <td className={`py-4 px-4 text-right font-medium ${(user.unrealized_pnl || 0) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                              {(user.unrealized_pnl || 0) >= 0 ? '+' : ''}${(user.unrealized_pnl || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                            </td>
                          </>
                        )}
                        <td className="py-4 px-4 text-center">
                          <div className="flex items-center justify-center gap-2">
                            <button
                              onClick={() => {
                                localStorage.setItem('adminSelectedUserId', user.id);
                                navigateTo('adminuser');
                              }}
                              className="px-4 py-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-medium rounded-lg transition-colors text-sm"
                            >
                              View Details
                            </button>
                            <button
                              onClick={() => handleLoginAs(user.id, user.full_name || user.username || user.email)}
                              className="p-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg transition-colors border border-blue-500/30"
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

                {filteredUsers.length === 0 && (
                  <div className="text-center py-12">
                    <p className="text-gray-400">No users found matching your search.</p>
                  </div>
                )}
              </div>
            )}

            {/* Pagination Controls */}
            {totalFilteredUsers > 0 && (
              <div className="bg-[#f0b90b]/10 border-2 border-[#f0b90b]/30 rounded-xl p-5 mt-6">
                <div className="flex items-center justify-between flex-wrap gap-4">
                  <div className="flex items-center gap-4">
                    <div className="flex items-center gap-2">
                      <span className="text-gray-300 font-medium text-sm">Show:</span>
                      <select
                        value={pageSize}
                        onChange={(e) => {
                          const value = parseInt(e.target.value);
                          setPageSize(value);
                          setCurrentPage(0);
                        }}
                        className="bg-[#0b0e11] border-2 border-[#f0b90b]/50 rounded-lg px-4 py-2 text-white font-medium text-sm outline-none focus:border-[#f0b90b]"
                      >
                        <option value="25">25 users</option>
                        <option value="50">50 users</option>
                        <option value="100">100 users</option>
                        <option value="200">200 users</option>
                        <option value="500">All users</option>
                      </select>
                    </div>
                    <div className="h-6 w-px bg-[#f0b90b]/30"></div>
                    <p className="text-gray-300 text-sm font-medium">
                      Showing <span className="text-[#f0b90b] font-bold">{startIndex + 1}</span> to{' '}
                      <span className="text-[#f0b90b] font-bold">{Math.min(endIndex, totalFilteredUsers)}</span> of{' '}
                      <span className="text-[#f0b90b] font-bold">{totalFilteredUsers}</span> users
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => setCurrentPage(0)}
                      disabled={currentPage === 0}
                      className="px-4 py-2 bg-[#0b0e11] text-white rounded-lg disabled:opacity-30 disabled:cursor-not-allowed hover:bg-[#1f2329] transition-colors font-medium border border-[#f0b90b]/30"
                    >
                      First
                    </button>
                    <button
                      onClick={() => setCurrentPage(Math.max(0, currentPage - 1))}
                      disabled={currentPage === 0}
                      className="px-4 py-2 bg-[#0b0e11] text-white rounded-lg disabled:opacity-30 disabled:cursor-not-allowed hover:bg-[#1f2329] transition-colors font-medium border border-[#f0b90b]/30"
                    >
                      Previous
                    </button>
                    <div className="flex items-center gap-2 px-4 py-2 bg-[#0b0e11] border-2 border-[#f0b90b]/50 rounded-lg">
                      <span className="text-white font-medium text-sm">Page</span>
                      <input
                        type="number"
                        min="1"
                        max={totalPages}
                        value={currentPage + 1}
                        onChange={(e) => {
                          const newPage = parseInt(e.target.value) - 1;
                          if (newPage >= 0 && newPage < totalPages) {
                            setCurrentPage(newPage);
                          }
                        }}
                        className="w-16 bg-[#1a1d24] border border-[#f0b90b]/50 rounded px-2 py-1 text-[#f0b90b] font-bold text-sm text-center outline-none focus:border-[#f0b90b]"
                      />
                      <span className="text-white font-medium text-sm">of {totalPages}</span>
                    </div>
                    <button
                      onClick={() => setCurrentPage(currentPage + 1)}
                      disabled={currentPage >= totalPages - 1}
                      className="px-4 py-2 bg-[#0b0e11] text-white rounded-lg disabled:opacity-30 disabled:cursor-not-allowed hover:bg-[#1f2329] transition-colors font-medium border border-[#f0b90b]/30"
                    >
                      Next
                    </button>
                    <button
                      onClick={() => setCurrentPage(totalPages - 1)}
                      disabled={currentPage >= totalPages - 1}
                      className="px-4 py-2 bg-[#0b0e11] text-white rounded-lg disabled:opacity-30 disabled:cursor-not-allowed hover:bg-[#1f2329] transition-colors font-medium border border-[#f0b90b]/30"
                    >
                      Last
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

      </div>

      {loginAsModal.show && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-2xl border border-gray-800 max-w-lg w-full p-6">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
                  <LogIn className="w-5 h-5 text-blue-400" />
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
                    className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-[#f0b90b] text-black rounded-xl font-medium hover:bg-[#f8d12f] transition-colors"
                  >
                    <ExternalLink className="w-4 h-4" />
                    Login As {loginAsModal.username}
                  </button>
                  <button
                    onClick={() => setLoginAsModal(prev => ({ ...prev, show: false }))}
                    className="px-4 py-3 bg-gray-700 text-white rounded-xl font-medium hover:bg-gray-600 transition-colors"
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

      {broadcastModal.show && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-2xl border border-gray-800 max-w-2xl w-full p-6 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-r from-orange-500 to-red-500 flex items-center justify-center">
                  <Megaphone className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="text-lg font-bold text-white">Broadcast Notification</h3>
                  <p className="text-gray-400 text-sm">Send a notification to all users</p>
                </div>
              </div>
              <button
                onClick={() => setBroadcastModal(prev => ({ ...prev, show: false }))}
                className="p-2 hover:bg-gray-800 rounded-lg text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {broadcastModal.success && (
              <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-4 mb-4">
                <div className="flex items-center gap-3">
                  <Check className="w-5 h-5 text-green-400 flex-shrink-0" />
                  <p className="text-green-400 font-medium">{broadcastModal.success}</p>
                </div>
              </div>
            )}

            {broadcastModal.error && (
              <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 mb-4">
                <div className="flex items-center gap-3">
                  <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0" />
                  <p className="text-red-400 font-medium">{broadcastModal.error}</p>
                </div>
              </div>
            )}

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Quick Templates
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                  {broadcastTemplates.map((template) => (
                    <button
                      key={template.id}
                      onClick={() => handleSelectTemplate(template.id)}
                      className="p-3 bg-[#0b0e11] hover:bg-[#22262e] border border-gray-700 rounded-xl text-left transition-colors"
                    >
                      <div className="flex items-center gap-2 mb-1">
                        <Gift className="w-4 h-4 text-[#f0b90b]" />
                        <span className="text-white text-sm font-medium">{template.name}</span>
                      </div>
                      <p className="text-gray-500 text-xs line-clamp-2">{template.message.slice(0, 60)}...</p>
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Notification Title *
                </label>
                <input
                  type="text"
                  value={broadcastModal.title}
                  onChange={(e) => setBroadcastModal(prev => ({ ...prev, title: e.target.value }))}
                  placeholder="Enter notification title..."
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b]"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Message *
                </label>
                <textarea
                  value={broadcastModal.message}
                  onChange={(e) => setBroadcastModal(prev => ({ ...prev, message: e.target.value }))}
                  placeholder="Enter your message..."
                  rows={4}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] resize-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Notification Type
                  </label>
                  <select
                    value={broadcastModal.notificationType}
                    onChange={(e) => setBroadcastModal(prev => ({ ...prev, notificationType: e.target.value }))}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b]"
                  >
                    <option value="reward">Reward / Promotion</option>
                    <option value="system">System Announcement</option>
                    <option value="referral_payout">Referral</option>
                    <option value="account_update">Account Update</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Redirect To
                  </label>
                  <select
                    value={broadcastModal.redirectUrl}
                    onChange={(e) => setBroadcastModal(prev => ({ ...prev, redirectUrl: e.target.value }))}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b]"
                  >
                    <option value="">No redirect</option>
                    <option value="referral">Referral Page</option>
                    <option value="deposit">Deposit Page</option>
                    <option value="rewardshub">Rewards Hub</option>
                    <option value="copytrading">Copy Trading</option>
                    <option value="futures">Futures Trading</option>
                    <option value="earn">Earn / Staking</option>
                    <option value="vip">VIP Program</option>
                    <option value="wallet">Wallet</option>
                  </select>
                </div>
              </div>

              {broadcastModal.title && broadcastModal.message && (
                <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-700">
                  <p className="text-gray-400 text-xs mb-2 uppercase tracking-wide">Preview</p>
                  <div className="flex items-start gap-3">
                    <span className="text-2xl">
                      {broadcastModal.notificationType === 'reward' ? '🎁' :
                       broadcastModal.notificationType === 'referral_payout' ? '💰' : '🔔'}
                    </span>
                    <div>
                      <h4 className="text-white font-semibold text-sm">{broadcastModal.title}</h4>
                      <p className="text-gray-400 text-xs mt-1">{broadcastModal.message}</p>
                      {broadcastModal.redirectUrl && (
                        <p className="text-[#f0b90b] text-xs mt-2">
                          Redirects to: {broadcastModal.redirectUrl}
                        </p>
                      )}
                    </div>
                  </div>
                </div>
              )}

              <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-3">
                <div className="flex items-start gap-2">
                  <AlertCircle className="w-4 h-4 text-yellow-400 flex-shrink-0 mt-0.5" />
                  <p className="text-yellow-400 text-xs">
                    This will send a notification to ALL users on the platform. This action cannot be undone.
                    Total users: <span className="font-bold">{stats.totalUsers.toLocaleString()}</span>
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-3 pt-2">
                <button
                  onClick={handleBroadcastNotification}
                  disabled={broadcastModal.loading || !broadcastModal.title || !broadcastModal.message}
                  className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 text-white rounded-xl font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {broadcastModal.loading ? (
                    <>
                      <RefreshCw className="w-4 h-4 animate-spin" />
                      Sending...
                    </>
                  ) : (
                    <>
                      <Send className="w-4 h-4" />
                      Send to All Users
                    </>
                  )}
                </button>
                <button
                  onClick={() => setBroadcastModal(prev => ({ ...prev, show: false }))}
                  className="px-4 py-3 bg-gray-700 text-white rounded-xl font-medium hover:bg-gray-600 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
