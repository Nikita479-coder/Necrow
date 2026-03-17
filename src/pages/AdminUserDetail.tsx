import { useState, useEffect, useMemo } from 'react';
import { ArrowLeft, User, Wallet, TrendingUp, Copy, Gift, FileText, Shield, Settings, AlertTriangle, Activity, MessageSquare, Tag, Bell } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';
import AdminUserOverview from '../components/admin/AdminUserOverview';
import AdminUserWallets from '../components/admin/AdminUserWallets';
import AdminUserTrading from '../components/admin/AdminUserTrading';
import AdminUserCopyTrading from '../components/admin/AdminUserCopyTrading';
import AdminUserRewards from '../components/admin/AdminUserRewards';
import AdminUserTransactions from '../components/admin/AdminUserTransactions';
import AdminUserKYC from '../components/admin/AdminUserKYC';
import AdminUserActions from '../components/admin/AdminUserActions';
import AdminUserActivity from '../components/admin/AdminUserActivity';
import AdminUserRisk from '../components/admin/AdminUserRisk';
import AdminUserNotes from '../components/admin/AdminUserNotes';
import AdminUserTags from '../components/admin/AdminUserTags';
import SendNotificationModal from '../components/admin/SendNotificationModal';

type TabType = 'overview' | 'wallets' | 'trading' | 'copy' | 'rewards' | 'transactions' | 'kyc' | 'risk' | 'actions' | 'activity' | 'notes';

interface TabConfig {
  id: TabType;
  label: string;
  icon: any;
  permissions: string[];
}

export default function AdminUserDetail() {
  const { user: adminUser, profile, canAccessAdmin, hasPermission, hasAnyPermission, staffInfo, loading: authLoading } = useAuth();
  const isSuperAdmin = profile?.is_admin === true;
  const { navigateTo } = useNavigation();
  const [userId, setUserId] = useState<string | null>(null);
  const [userData, setUserData] = useState<any>(null);
  const [activeTab, setActiveTab] = useState<TabType>('overview');
  const [loading, setLoading] = useState(true);
  const [hasAccess, setHasAccess] = useState(false);
  const [isOnline, setIsOnline] = useState(false);
  const [lastActivity, setLastActivity] = useState<Date | null>(null);
  const [showNotificationModal, setShowNotificationModal] = useState(false);

  const allTabs: TabConfig[] = [
    { id: 'overview', label: 'Overview', icon: User, permissions: ['view_user_details'] },
    { id: 'notes', label: 'Notes & Tags', icon: MessageSquare, permissions: ['view_user_details'] },
    { id: 'activity', label: 'Live Activity', icon: Activity, permissions: ['view_activity'] },
    { id: 'wallets', label: 'Wallets', icon: Wallet, permissions: ['view_wallets'] },
    { id: 'trading', label: 'Trading', icon: TrendingUp, permissions: ['view_trading'] },
    { id: 'copy', label: 'Copy Trading', icon: Copy, permissions: ['view_copy_trading'] },
    { id: 'rewards', label: 'Rewards', icon: Gift, permissions: ['view_bonuses'] },
    { id: 'transactions', label: 'Transactions', icon: FileText, permissions: ['view_transactions'] },
    { id: 'kyc', label: 'KYC & Docs', icon: Shield, permissions: ['view_kyc'] },
    { id: 'risk', label: 'Risk Management', icon: AlertTriangle, permissions: ['view_risk'] },
    { id: 'actions', label: 'Admin Actions', icon: Settings, permissions: ['manage_accounts', 'modify_balances', 'manage_kyc', 'send_emails', 'award_bonuses'] }
  ];

  const visibleTabs = useMemo(() => {
    return allTabs.filter(tab => hasAnyPermission(tab.permissions));
  }, [staffInfo]);

  useEffect(() => {
    if (authLoading) return;
    checkAccessAndLoadUser();
  }, [adminUser, staffInfo, authLoading]);

  useEffect(() => {
    if (!userId) return;

    const checkStatus = async () => {
      const { data } = await supabase
        .from('user_sessions')
        .select('is_online, last_activity, heartbeat')
        .eq('user_id', userId)
        .single();

      if (data) {
        const now = new Date();
        const heartbeat = new Date(data.heartbeat || data.last_activity);
        const diffMinutes = (now.getTime() - heartbeat.getTime()) / 1000 / 60;

        setIsOnline(data.is_online && diffMinutes < 2);
        setLastActivity(new Date(data.last_activity));
      }
    };

    checkStatus();

    const channel = supabase
      .channel(`user-session-${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_sessions',
          filter: `user_id=eq.${userId}`,
        },
        (payload) => {
          const session = payload.new as any;
          if (session) {
            const heartbeat = new Date(session.heartbeat || session.last_activity);
            const now = new Date();
            const diffMinutes = (now.getTime() - heartbeat.getTime()) / 1000 / 60;

            setIsOnline(session.is_online && diffMinutes < 2);
            setLastActivity(new Date(session.last_activity));
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId]);

  const checkAccessAndLoadUser = async () => {
    if (authLoading) return;

    if (!adminUser) {
      navigateTo('signin');
      return;
    }

    if (!canAccessAdmin()) {
      navigateTo('home');
      return;
    }

    setHasAccess(true);

    const selectedUserId = localStorage.getItem('adminSelectedUserId');
    if (!selectedUserId) {
      navigateTo('admindashboard');
      return;
    }

    setUserId(selectedUserId);
    await loadUserData(selectedUserId);
  };

  const loadUserData = async (uid: string) => {
    setLoading(true);
    try {
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('*')
        .eq('id', uid)
        .single();

      const { data: userEmail } = await supabase.rpc('get_user_email_for_admin', {
        p_user_id: uid
      });

      let referrerInfo = null;
      if (profile?.referred_by) {
        const { data: referrerProfile } = await supabase
          .from('user_profiles')
          .select('id, full_name, username, referral_code')
          .eq('id', profile.referred_by)
          .single();

        if (referrerProfile) {
          const { data: referrerEmail } = await supabase.rpc('get_user_email_for_admin', {
            p_user_id: profile.referred_by
          });
          referrerInfo = {
            ...referrerProfile,
            email: referrerEmail
          };
        }
      }

      const { data: wallets } = await supabase
        .from('wallets')
        .select('*')
        .eq('user_id', uid);

      const { data: futuresWallet } = await supabase
        .from('futures_margin_wallets')
        .select('*')
        .eq('user_id', uid)
        .single();

      const { data: positions } = await supabase
        .from('futures_positions')
        .select('*')
        .eq('user_id', uid)
        .eq('status', 'open');

      const { data: referralStats } = await supabase
        .from('referral_stats')
        .select('*')
        .eq('user_id', uid)
        .maybeSingle();

      setUserData({
        profile,
        userEmail,
        referrerInfo,
        wallets: wallets || [],
        futuresWallet,
        openPositions: positions || [],
        referralStats
      });
    } catch (error) {
      console.error('Error loading user data:', error);
    } finally {
      setLoading(false);
    }
  };

  const renderTabContent = () => {
    if (!userId) return null;

    switch (activeTab) {
      case 'overview':
        return hasPermission('view_user_details') ? (
          <AdminUserOverview userId={userId} userData={userData} onRefresh={() => loadUserData(userId)} isSuperAdmin={isSuperAdmin} />
        ) : <AccessDenied />;
      case 'notes':
        return hasPermission('view_user_details') ? (
          <div className="space-y-6">
            <AdminUserTags userId={userId} />
            <AdminUserNotes userId={userId} />
          </div>
        ) : <AccessDenied />;
      case 'activity':
        return hasPermission('view_activity') ? (
          <AdminUserActivity userId={userId} />
        ) : <AccessDenied />;
      case 'wallets':
        return hasPermission('view_wallets') ? (
          <AdminUserWallets userId={userId} userData={userData} onRefresh={() => loadUserData(userId)} />
        ) : <AccessDenied />;
      case 'trading':
        return hasPermission('view_trading') ? (
          <AdminUserTrading userId={userId} userData={userData} />
        ) : <AccessDenied />;
      case 'copy':
        return hasPermission('view_copy_trading') ? (
          <AdminUserCopyTrading userId={userId} />
        ) : <AccessDenied />;
      case 'rewards':
        return hasPermission('view_bonuses') ? (
          <AdminUserRewards userId={userId} />
        ) : <AccessDenied />;
      case 'transactions':
        return hasPermission('view_transactions') ? (
          <AdminUserTransactions userId={userId} />
        ) : <AccessDenied />;
      case 'kyc':
        return hasPermission('view_kyc') ? (
          <AdminUserKYC userId={userId} userData={userData} onRefresh={() => loadUserData(userId)} />
        ) : <AccessDenied />;
      case 'risk':
        return hasPermission('view_risk') ? (
          <AdminUserRisk userId={userId} />
        ) : <AccessDenied />;
      case 'actions':
        return hasAnyPermission(['manage_accounts', 'modify_balances', 'manage_kyc', 'send_emails', 'award_bonuses']) ? (
          <AdminUserActions userId={userId} userData={userData} onRefresh={() => loadUserData(userId)} />
        ) : <AccessDenied />;
      default:
        return null;
    }
  };

  if (!hasAccess || !userId) {
    return null;
  }

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('admindashboard')}
          className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-6"
        >
          <ArrowLeft className="w-5 h-5" />
          <span>Back to Dashboard</span>
        </button>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b]"></div>
          </div>
        ) : userData ? (
          <>
            <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800 mb-6">
              <div className="flex items-start justify-between mb-4">
                <div>
                  <div className="flex items-center gap-3 mb-2">
                    <h1 className="text-2xl font-bold text-white">{userData.profile?.full_name || userData.profile?.username || 'No Username'}</h1>
                    {hasPermission('view_activity') && (
                      <div className="flex items-center gap-2">
                        <div className={`w-3 h-3 rounded-full ${isOnline ? 'bg-green-400 animate-pulse' : 'bg-gray-600'}`}></div>
                        <span className={`text-sm font-medium ${isOnline ? 'text-green-400' : 'text-gray-500'}`}>
                          {isOnline ? 'Online' : 'Offline'}
                        </span>
                      </div>
                    )}
                  </div>
                  <p className="text-gray-400">{userData.userEmail || 'Email not available'}</p>
                  <div className="flex items-center gap-3 mt-1">
                    <p className="text-sm text-gray-500">User ID: {userId}</p>
                    {hasPermission('view_activity') && lastActivity && (
                      <p className="text-sm text-gray-500">
                        Last seen: {lastActivity.toLocaleString()}
                      </p>
                    )}
                  </div>
                </div>
                <div className="flex flex-col items-end gap-2">
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => setShowNotificationModal(true)}
                      className="flex items-center gap-2 px-3 py-1.5 bg-[#f0b90b]/20 hover:bg-[#f0b90b]/30 text-[#f0b90b] border border-[#f0b90b]/30 rounded-lg text-sm font-medium transition-colors"
                    >
                      <Bell className="w-4 h-4" />
                      Send Notification
                    </button>
                    {userData.profile?.is_admin && (
                      <span className="px-3 py-1 bg-[#f0b90b]/20 text-[#f0b90b] border border-[#f0b90b]/30 rounded-lg text-sm font-medium">
                        ADMIN
                      </span>
                    )}
                    {hasPermission('view_kyc') && (
                      <span className={`px-3 py-1 rounded-lg border text-sm font-medium ${
                        userData.profile?.kyc_status === 'verified'
                          ? 'bg-green-500/20 text-green-400 border-green-500/30'
                          : userData.profile?.kyc_status === 'pending'
                          ? 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30'
                          : 'bg-gray-500/20 text-gray-400 border-gray-500/30'
                      }`}>
                        KYC: {userData.profile?.kyc_status?.toUpperCase() || 'UNVERIFIED'}
                      </span>
                    )}
                  </div>
                  {hasPermission('view_vip') && (
                    <span className="text-sm text-gray-400">
                      Level {userData.profile?.kyc_level || 0} - VIP {userData.referralStats?.vip_level || 1}
                    </span>
                  )}
                </div>
              </div>

              {hasPermission('view_trading') && userData.openPositions.length > 0 && (
                <div className="flex items-center gap-2 p-3 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
                  <AlertTriangle className="w-5 h-5 text-yellow-400" />
                  <span className="text-yellow-400 text-sm font-medium">
                    {userData.openPositions.length} Open Position{userData.openPositions.length !== 1 ? 's' : ''}
                  </span>
                </div>
              )}
            </div>

            <div className="bg-[#1a1d24] rounded-xl border border-gray-800 mb-6">
              <div className="border-b border-gray-800 overflow-x-auto">
                <div className="flex gap-1 p-2 min-w-max">
                  {visibleTabs.map((tab) => {
                    const Icon = tab.icon;
                    return (
                      <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id)}
                        className={`flex items-center gap-2 px-4 py-3 rounded-lg font-medium transition-all ${
                          activeTab === tab.id
                            ? 'bg-[#f0b90b] text-black'
                            : 'text-gray-400 hover:text-white hover:bg-[#0b0e11]'
                        }`}
                      >
                        <Icon className="w-4 h-4" />
                        {tab.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className="p-6">
                {renderTabContent()}
              </div>
            </div>
          </>
        ) : (
          <div className="text-center py-20">
            <p className="text-gray-400">User not found</p>
          </div>
        )}
      </div>

      {userId && userData && (
        <SendNotificationModal
          isOpen={showNotificationModal}
          onClose={() => setShowNotificationModal(false)}
          userId={userId}
          userName={userData.profile?.full_name || userData.profile?.username || ''}
          userEmail={userData.userEmail || ''}
        />
      )}
    </div>
  );
}

function AccessDenied() {
  return (
    <div className="text-center py-12">
      <Shield className="w-16 h-16 text-gray-600 mx-auto mb-4" />
      <h3 className="text-xl font-bold text-white mb-2">Access Denied</h3>
      <p className="text-gray-400">You don't have permission to view this section.</p>
    </div>
  );
}
