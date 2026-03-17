import { useState, useEffect } from 'react';
import { LayoutDashboard, Users, MessageSquare, ArrowDownToLine, ArrowUpFromLine, GitBranch, Star, DollarSign, TrendingUp, TrendingDown, UserCheck, Activity, RefreshCw } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';
import PromoterUsers from '../components/promoter/PromoterUsers';
import PromoterSupport from '../components/promoter/PromoterSupport';
import PromoterDeposits from '../components/promoter/PromoterDeposits';
import PromoterWithdrawals from '../components/promoter/PromoterWithdrawals';
import PromoterReferralTree from '../components/promoter/PromoterReferralTree';
import PromoterExclusiveAffiliates from '../components/promoter/PromoterExclusiveAffiliates';

type PromoterTab = 'dashboard' | 'users' | 'support' | 'deposits' | 'withdrawals' | 'referraltree' | 'exclusiveaffiliates';

interface DashboardStats {
  total_deposits: number;
  total_withdrawals: number;
  earnings: number;
  tree_user_count: number;
  depositor_count: number;
  active_traders: number;
}

const NAV_ITEMS: { key: PromoterTab; label: string; icon: typeof LayoutDashboard }[] = [
  { key: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { key: 'users', label: 'Users', icon: Users },
  { key: 'support', label: 'Support', icon: MessageSquare },
  { key: 'deposits', label: 'Deposits', icon: ArrowDownToLine },
  { key: 'withdrawals', label: 'Withdrawals', icon: ArrowUpFromLine },
  { key: 'referraltree', label: 'Referral Tree', icon: GitBranch },
  { key: 'exclusiveaffiliates', label: 'Exclusive Affiliates', icon: Star },
];

export default function PromoterDashboard() {
  const { user, canAccessAdmin, hasPermission } = useAuth();
  const { navigateTo } = useNavigation();
  const [activeTab, setActiveTab] = useState<PromoterTab>('dashboard');
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [hasAccess, setHasAccess] = useState(false);

  useEffect(() => {
    if (!user) {
      navigateTo('signin');
      return;
    }
    if (canAccessAdmin() && hasPermission('promoter_access')) {
      setHasAccess(true);
    } else {
      navigateTo('home');
    }
  }, [user]);

  useEffect(() => {
    if (hasAccess) {
      loadStats();
    }
  }, [hasAccess]);

  const loadStats = async () => {
    try {
      const { data, error } = await supabase.rpc('promoter_get_dashboard_stats');
      if (error) throw error;
      if (data?.success) {
        setStats(data);
      }
    } catch (err) {
      console.error('Failed to load stats:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const handleRefresh = () => {
    setRefreshing(true);
    loadStats();
  };

  const formatCurrency = (val: number) => {
    if (val >= 1000000) return '$' + (val / 1000000).toFixed(2) + 'M';
    if (val >= 1000) return '$' + (val / 1000).toFixed(2) + 'K';
    return '$' + val.toFixed(2);
  };

  if (!hasAccess) {
    return (
      <div className="min-h-screen bg-[#0b0e11] flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]" />
      </div>
    );
  }

  const renderDashboardContent = () => {
    if (loading) {
      return (
        <div className="text-center py-20">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]" />
          <p className="text-gray-400 mt-4">Loading dashboard...</p>
        </div>
      );
    }

    if (!stats) return null;

    return (
      <div className="space-y-8">
        <div className="bg-gradient-to-br from-[#1a1d24] to-[#1e2330] rounded-2xl p-8 border border-gray-800 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-64 h-64 bg-[#f0b90b]/5 rounded-full -translate-y-1/2 translate-x-1/2" />
          <div className="relative">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h2 className="text-lg text-gray-400 mb-1">Your Earnings</h2>
                <p className="text-xs text-gray-500">Formula: (Total Deposits - Total Withdrawals) / 2</p>
              </div>
              <button
                onClick={handleRefresh}
                disabled={refreshing}
                className="p-2 rounded-lg bg-white/5 hover:bg-white/10 transition-colors"
              >
                <RefreshCw className={`w-4 h-4 text-gray-400 ${refreshing ? 'animate-spin' : ''}`} />
              </button>
            </div>
            <div className="text-5xl font-bold text-[#f0b90b] mb-6 tracking-tight">
              {formatCurrency(stats.earnings)}
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="bg-black/20 rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <TrendingUp className="w-4 h-4 text-emerald-400" />
                  <span className="text-sm text-gray-400">Total Deposits</span>
                </div>
                <span className="text-xl font-semibold text-emerald-400">{formatCurrency(stats.total_deposits)}</span>
              </div>
              <div className="bg-black/20 rounded-xl p-4">
                <div className="flex items-center gap-2 mb-2">
                  <TrendingDown className="w-4 h-4 text-red-400" />
                  <span className="text-sm text-gray-400">Total Withdrawals</span>
                </div>
                <span className="text-xl font-semibold text-red-400">{formatCurrency(stats.total_withdrawals)}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-blue-500/10 rounded-xl flex items-center justify-center">
                <Users className="w-6 h-6 text-blue-400" />
              </div>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stats.tree_user_count.toLocaleString()}</h3>
            <p className="text-sm text-gray-400">Total Users in Tree</p>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-emerald-500/10 rounded-xl flex items-center justify-center">
                <UserCheck className="w-6 h-6 text-emerald-400" />
              </div>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stats.depositor_count.toLocaleString()}</h3>
            <p className="text-sm text-gray-400">Users Who Deposited</p>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-[#f0b90b]/10 rounded-xl flex items-center justify-center">
                <Activity className="w-6 h-6 text-[#f0b90b]" />
              </div>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stats.active_traders.toLocaleString()}</h3>
            <p className="text-sm text-gray-400">Active Traders</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <button
            onClick={() => setActiveTab('users')}
            className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800 hover:border-gray-700 transition-colors text-left group"
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-white font-medium mb-1">View Users</h3>
                <p className="text-sm text-gray-500">Browse all {stats.tree_user_count} users in your referral network</p>
              </div>
              <Users className="w-8 h-8 text-gray-600 group-hover:text-blue-400 transition-colors" />
            </div>
          </button>
          <button
            onClick={() => setActiveTab('support')}
            className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800 hover:border-gray-700 transition-colors text-left group"
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-white font-medium mb-1">Support Tickets</h3>
                <p className="text-sm text-gray-500">View and respond to your users' support requests</p>
              </div>
              <MessageSquare className="w-8 h-8 text-gray-600 group-hover:text-cyan-400 transition-colors" />
            </div>
          </button>
          <button
            onClick={() => setActiveTab('deposits')}
            className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800 hover:border-gray-700 transition-colors text-left group"
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-white font-medium mb-1">Deposits</h3>
                <p className="text-sm text-gray-500">Track deposit activity across your referral tree</p>
              </div>
              <ArrowDownToLine className="w-8 h-8 text-gray-600 group-hover:text-emerald-400 transition-colors" />
            </div>
          </button>
          <button
            onClick={() => setActiveTab('referraltree')}
            className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800 hover:border-gray-700 transition-colors text-left group"
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-white font-medium mb-1">Referral Tree</h3>
                <p className="text-sm text-gray-500">Level-by-level breakdown of your entire network</p>
              </div>
              <GitBranch className="w-8 h-8 text-gray-600 group-hover:text-[#f0b90b] transition-colors" />
            </div>
          </button>
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-2xl font-bold text-white">Promoter Dashboard</h1>
            <p className="text-gray-400 text-sm mt-1">Manage your referral network and track earnings</p>
          </div>
        </div>

        <div className="flex gap-2 flex-wrap mb-8">
          {NAV_ITEMS.map(item => {
            const Icon = item.icon;
            const isActive = activeTab === item.key;
            return (
              <button
                key={item.key}
                onClick={() => setActiveTab(item.key)}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${
                  isActive
                    ? 'bg-[#f0b90b] text-black'
                    : 'bg-[#1a1d24] text-gray-400 hover:text-white hover:bg-[#252830] border border-gray-800'
                }`}
              >
                <Icon className="w-4 h-4" />
                {item.label}
              </button>
            );
          })}
        </div>

        {activeTab === 'dashboard' && renderDashboardContent()}
        {activeTab === 'users' && <PromoterUsers />}
        {activeTab === 'support' && <PromoterSupport />}
        {activeTab === 'deposits' && <PromoterDeposits />}
        {activeTab === 'withdrawals' && <PromoterWithdrawals />}
        {activeTab === 'referraltree' && <PromoterReferralTree />}
        {activeTab === 'exclusiveaffiliates' && <PromoterExclusiveAffiliates />}
      </div>
    </div>
  );
}
