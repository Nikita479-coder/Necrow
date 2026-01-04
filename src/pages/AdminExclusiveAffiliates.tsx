import { useState, useEffect } from 'react';
import {
  ArrowLeft,
  Users,
  Crown,
  DollarSign,
  TrendingUp,
  CheckCircle,
  XCircle,
  Search,
  RefreshCw,
  Wallet,
  UserPlus,
  UserMinus,
  Clock,
  AlertCircle,
  Gift,
  Percent,
  Network,
  X,
  ChevronDown,
  ChevronRight
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';

interface ExclusiveAffiliate {
  affiliate_id: string;
  user_id: string;
  email: string;
  full_name: string | null;
  username: string | null;
  referral_code: string | null;
  deposit_commission_rates: {
    level_1: number;
    level_2: number;
    level_3: number;
    level_4: number;
    level_5: number;
  };
  fee_share_rates: {
    level_1: number;
    level_2: number;
    level_3: number;
    level_4: number;
    level_5: number;
  };
  is_active: boolean;
  enrolled_at: string;
  enrolled_by_email: string | null;
  available_balance: number;
  pending_balance: number;
  total_earned: number;
  total_withdrawn: number;
  deposit_commissions_earned: number;
  fee_share_earned: number;
  network_size: number;
  this_month_earnings: number;
}

interface Withdrawal {
  withdrawal_id: string;
  user_id: string;
  email: string;
  full_name: string | null;
  amount: number;
  currency: string;
  wallet_address: string;
  network: string;
  status: string;
  created_at: string;
  processed_by_email: string | null;
  processed_at: string | null;
  rejection_reason: string | null;
}

interface NetworkStats {
  level_1_count: number;
  level_2_count: number;
  level_3_count: number;
  level_4_count: number;
  level_5_count: number;
  level_1_earnings: number;
  level_2_earnings: number;
  level_3_earnings: number;
  level_4_earnings: number;
  level_5_earnings: number;
}

interface NetworkMember {
  user_id: string;
  email: string;
  full_name: string | null;
  username: string | null;
  level: number;
  registered_at: string;
  total_deposits: number;
  trading_volume: number;
  eligible: boolean;
}

export default function AdminExclusiveAffiliates() {
  const { user, profile } = useAuth();
  const { navigateTo } = useNavigation();

  const [affiliates, setAffiliates] = useState<ExclusiveAffiliate[]>([]);
  const [withdrawals, setWithdrawals] = useState<Withdrawal[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'affiliates' | 'withdrawals'>('affiliates');
  const [searchTerm, setSearchTerm] = useState('');

  const [showEnrollModal, setShowEnrollModal] = useState(false);
  const [enrollEmail, setEnrollEmail] = useState('');
  const [enrolling, setEnrolling] = useState(false);
  const [enrollError, setEnrollError] = useState<string | null>(null);

  const [showWithdrawalModal, setShowWithdrawalModal] = useState(false);
  const [selectedWithdrawal, setSelectedWithdrawal] = useState<Withdrawal | null>(null);
  const [rejectionReason, setRejectionReason] = useState('');
  const [processingWithdrawal, setProcessingWithdrawal] = useState(false);

  const [depositRates, setDepositRates] = useState({ level_1: 5, level_2: 4, level_3: 3, level_4: 2, level_5: 1 });
  const [feeRates, setFeeRates] = useState({ level_1: 50, level_2: 40, level_3: 30, level_4: 20, level_5: 10 });

  const [showNetworkModal, setShowNetworkModal] = useState(false);
  const [selectedAffiliateForNetwork, setSelectedAffiliateForNetwork] = useState<ExclusiveAffiliate | null>(null);
  const [networkStats, setNetworkStats] = useState<NetworkStats | null>(null);
  const [networkMembers, setNetworkMembers] = useState<NetworkMember[]>([]);
  const [loadingNetwork, setLoadingNetwork] = useState(false);
  const [expandedLevels, setExpandedLevels] = useState<Set<number>>(new Set([1]));
  const [showAllReferrals, setShowAllReferrals] = useState(false);

  useEffect(() => {
    if (!profile?.is_admin) {
      navigateTo('home');
      return;
    }
    loadData();
  }, [user, profile]);

  const loadData = async () => {
    setLoading(true);
    try {
      const [affiliatesRes, withdrawalsRes] = await Promise.all([
        supabase.rpc('admin_get_exclusive_affiliates'),
        supabase.rpc('admin_get_exclusive_withdrawals')
      ]);

      if (affiliatesRes.error) throw affiliatesRes.error;
      if (withdrawalsRes.error) throw withdrawalsRes.error;

      setAffiliates(affiliatesRes.data || []);
      setWithdrawals(withdrawalsRes.data || []);
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleEnroll = async () => {
    if (!enrollEmail.trim() || !user) return;

    setEnrolling(true);
    setEnrollError(null);

    try {
      const { data, error } = await supabase.rpc('admin_enroll_exclusive_affiliate', {
        p_admin_id: user.id,
        p_user_email: enrollEmail.trim(),
        p_deposit_rates: depositRates,
        p_fee_rates: feeRates
      });

      if (error) throw error;

      if (data?.success) {
        setShowEnrollModal(false);
        setEnrollEmail('');
        setDepositRates({ level_1: 5, level_2: 4, level_3: 3, level_4: 2, level_5: 1 });
        setFeeRates({ level_1: 50, level_2: 40, level_3: 30, level_4: 20, level_5: 10 });
        loadData();
      } else {
        setEnrollError(data?.error || 'Failed to enroll user');
      }
    } catch (err: any) {
      setEnrollError(err.message || 'Failed to enroll user');
    } finally {
      setEnrolling(false);
    }
  };

  const handleRemove = async (email: string) => {
    if (!user || !confirm(`Remove ${email} from the exclusive affiliate program?`)) return;

    try {
      const { data, error } = await supabase.rpc('admin_remove_exclusive_affiliate', {
        p_admin_id: user.id,
        p_user_email: email
      });

      if (error) throw error;

      if (data?.success) {
        loadData();
      }
    } catch (err) {
      console.error('Error removing affiliate:', err);
    }
  };

  const handleProcessWithdrawal = async (action: 'approve' | 'reject') => {
    if (!selectedWithdrawal || !user) return;

    setProcessingWithdrawal(true);
    try {
      const { data, error } = await supabase.rpc('admin_process_exclusive_withdrawal', {
        p_admin_id: user.id,
        p_withdrawal_id: selectedWithdrawal.withdrawal_id,
        p_action: action,
        p_rejection_reason: action === 'reject' ? rejectionReason : null
      });

      if (error) throw error;

      if (data?.success) {
        setShowWithdrawalModal(false);
        setSelectedWithdrawal(null);
        setRejectionReason('');
        loadData();
      }
    } catch (err) {
      console.error('Error processing withdrawal:', err);
    } finally {
      setProcessingWithdrawal(false);
    }
  };

  const handleViewNetwork = async (affiliate: ExclusiveAffiliate) => {
    setSelectedAffiliateForNetwork(affiliate);
    setShowNetworkModal(true);
    setLoadingNetwork(true);
    setExpandedLevels(new Set([1]));

    try {
      const [statsRes, membersRes] = await Promise.all([
        supabase
          .from('exclusive_affiliate_network_stats')
          .select('*')
          .eq('affiliate_id', affiliate.user_id)
          .single(),
        supabase.rpc('get_exclusive_affiliate_referrals', {
          p_affiliate_id: affiliate.user_id
        })
      ]);

      if (statsRes.error && statsRes.error.code !== 'PGRST116') throw statsRes.error;
      setNetworkStats(statsRes.data || null);
      setNetworkMembers(membersRes.data || []);
    } catch (err) {
      console.error('Error loading network:', err);
      setNetworkStats(null);
      setNetworkMembers([]);
    } finally {
      setLoadingNetwork(false);
    }
  };

  const toggleLevel = (level: number) => {
    setExpandedLevels(prev => {
      const newSet = new Set(prev);
      if (newSet.has(level)) {
        newSet.delete(level);
      } else {
        newSet.add(level);
      }
      return newSet;
    });
  };

  const getFilteredMembers = () => {
    if (showAllReferrals) return networkMembers;
    return networkMembers.filter(m => m.eligible);
  };

  const getLevelCount = (level: number) => {
    return getFilteredMembers().filter(m => m.level === level).length;
  };

  const getLevelEarnings = (level: number) => {
    if (!networkStats) return 0;
    return Number(networkStats[`level_${level}_earnings` as keyof NetworkStats]) || 0;
  };

  const getMembersByLevel = (level: number) => {
    return getFilteredMembers().filter(m => m.level === level);
  };

  const eligibleCount = networkMembers.filter(m => m.eligible).length;
  const ineligibleCount = networkMembers.filter(m => !m.eligible).length;

  const filteredAffiliates = affiliates.filter(a =>
    a.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    a.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    a.username?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const pendingWithdrawals = withdrawals.filter(w => w.status === 'pending');
  const processedWithdrawals = withdrawals.filter(w => w.status !== 'pending');

  const totalEarned = affiliates.reduce((sum, a) => sum + (a.total_earned || 0), 0);
  const totalWithdrawn = affiliates.reduce((sum, a) => sum + (a.total_withdrawn || 0), 0);
  const totalPending = affiliates.reduce((sum, a) => sum + (a.pending_balance || 0), 0);
  const totalNetwork = affiliates.reduce((sum, a) => sum + (a.network_size || 0), 0);

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0b0e11]">
        <Navbar />
        <div className="flex items-center justify-center py-20">
          <div className="w-10 h-10 border-4 border-[#fcd535] border-t-transparent rounded-full animate-spin" />
        </div>
      </div>
    );
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

        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white flex items-center gap-3">
              <Crown className="w-8 h-8 text-[#fcd535]" />
              Exclusive Affiliate Program
            </h1>
            <p className="text-gray-400 mt-1">Manage VIP affiliates with 5-level commissions</p>
          </div>
          <button
            onClick={() => setShowEnrollModal(true)}
            className="flex items-center gap-2 px-6 py-3 bg-[#fcd535] hover:bg-[#fcd535]/90 text-black font-bold rounded-lg transition-all"
          >
            <UserPlus className="w-5 h-5" />
            Enroll New Affiliate
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <Users className="w-8 h-8 text-[#fcd535]" />
            </div>
            <div className="text-3xl font-bold text-white">{affiliates.filter(a => a.is_active).length}</div>
            <div className="text-sm text-gray-400">Active Affiliates</div>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <DollarSign className="w-8 h-8 text-green-400" />
            </div>
            <div className="text-3xl font-bold text-white">${totalEarned.toFixed(2)}</div>
            <div className="text-sm text-gray-400">Total Commissions Paid</div>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <Wallet className="w-8 h-8 text-blue-400" />
            </div>
            <div className="text-3xl font-bold text-white">${totalPending.toFixed(2)}</div>
            <div className="text-sm text-gray-400">Pending Withdrawals</div>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <TrendingUp className="w-8 h-8 text-cyan-400" />
            </div>
            <div className="text-3xl font-bold text-white">{totalNetwork}</div>
            <div className="text-sm text-gray-400">Total Network Size</div>
          </div>
        </div>

        <div className="bg-[#1a1d24] rounded-xl border border-gray-800 overflow-hidden">
          <div className="flex border-b border-gray-800">
            <button
              onClick={() => setActiveTab('affiliates')}
              className={`flex-1 px-6 py-4 font-semibold transition-all ${
                activeTab === 'affiliates'
                  ? 'bg-[#fcd535] text-black'
                  : 'text-gray-400 hover:text-white hover:bg-[#2b3139]'
              }`}
            >
              <div className="flex items-center justify-center gap-2">
                <Users className="w-5 h-5" />
                Affiliates ({affiliates.length})
              </div>
            </button>
            <button
              onClick={() => setActiveTab('withdrawals')}
              className={`flex-1 px-6 py-4 font-semibold transition-all relative ${
                activeTab === 'withdrawals'
                  ? 'bg-[#fcd535] text-black'
                  : 'text-gray-400 hover:text-white hover:bg-[#2b3139]'
              }`}
            >
              <div className="flex items-center justify-center gap-2">
                <Wallet className="w-5 h-5" />
                Withdrawals
                {pendingWithdrawals.length > 0 && (
                  <span className="px-2 py-0.5 bg-red-500 text-white text-xs rounded-full">
                    {pendingWithdrawals.length}
                  </span>
                )}
              </div>
            </button>
          </div>

          <div className="p-6">
            {activeTab === 'affiliates' && (
              <>
                <div className="flex flex-col md:flex-row gap-4 mb-6">
                  <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                    <input
                      type="text"
                      placeholder="Search by email, name, or username..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg pl-10 pr-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-[#fcd535]"
                    />
                  </div>
                  <button
                    onClick={loadData}
                    className="px-4 py-3 bg-[#2b3139] hover:bg-[#363e47] text-gray-300 rounded-lg transition-all"
                  >
                    <RefreshCw className="w-5 h-5" />
                  </button>
                </div>

                <div className="space-y-4">
                  {filteredAffiliates.map((affiliate) => (
                    <div
                      key={affiliate.affiliate_id}
                      className={`p-6 rounded-xl border ${
                        affiliate.is_active
                          ? 'bg-gradient-to-r from-[#fcd535]/5 to-transparent border-[#fcd535]/30'
                          : 'bg-[#0b0e11] border-gray-700 opacity-60'
                      }`}
                    >
                      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                        <div className="flex-1">
                          <div className="flex items-center gap-3 mb-2">
                            <h3 className="text-xl font-bold text-white">
                              {affiliate.full_name || affiliate.username || 'No Name'}
                            </h3>
                            {affiliate.is_active ? (
                              <span className="px-2 py-1 bg-green-500/20 text-green-400 text-xs font-semibold rounded-full">
                                ACTIVE
                              </span>
                            ) : (
                              <span className="px-2 py-1 bg-gray-500/20 text-gray-400 text-xs font-semibold rounded-full">
                                INACTIVE
                              </span>
                            )}
                          </div>
                          <p className="text-gray-400 text-sm">{affiliate.email}</p>
                          <p className="text-[#fcd535] text-sm mt-1">Code: {affiliate.referral_code || 'N/A'}</p>
                          <p className="text-gray-500 text-xs mt-1">
                            Enrolled: {new Date(affiliate.enrolled_at).toLocaleDateString()}
                            {affiliate.enrolled_by_email && ` by ${affiliate.enrolled_by_email}`}
                          </p>
                        </div>

                        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                          <div className="text-center p-3 bg-[#0b0e11] rounded-lg">
                            <div className="text-lg font-bold text-green-400">
                              ${(affiliate.available_balance || 0).toFixed(2)}
                            </div>
                            <div className="text-xs text-gray-400">Available</div>
                          </div>
                          <div className="text-center p-3 bg-[#0b0e11] rounded-lg">
                            <div className="text-lg font-bold text-[#fcd535]">
                              ${(affiliate.total_earned || 0).toFixed(2)}
                            </div>
                            <div className="text-xs text-gray-400">Total Earned</div>
                          </div>
                          <div className="text-center p-3 bg-[#0b0e11] rounded-lg">
                            <div className="text-lg font-bold text-cyan-400">
                              {affiliate.network_size || 0}
                            </div>
                            <div className="text-xs text-gray-400">Network</div>
                          </div>
                          <div className="text-center p-3 bg-[#0b0e11] rounded-lg">
                            <div className="text-lg font-bold text-blue-400">
                              ${(affiliate.this_month_earnings || 0).toFixed(2)}
                            </div>
                            <div className="text-xs text-gray-400">This Month</div>
                          </div>
                        </div>

                        <div className="flex gap-2">
                          <button
                            onClick={() => handleViewNetwork(affiliate)}
                            className="px-4 py-2 bg-cyan-500/20 hover:bg-cyan-500/30 text-cyan-400 rounded-lg transition-all flex items-center gap-2"
                          >
                            <Network className="w-4 h-4" />
                            View Network
                          </button>
                          {affiliate.is_active && (
                            <button
                              onClick={() => handleRemove(affiliate.email)}
                              className="px-4 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 rounded-lg transition-all flex items-center gap-2"
                            >
                              <UserMinus className="w-4 h-4" />
                              Remove
                            </button>
                          )}
                        </div>
                      </div>

                      <div className="mt-4 pt-4 border-t border-gray-700/50 grid grid-cols-2 lg:grid-cols-5 gap-4">
                        <div className="flex items-center gap-2">
                          <Gift className="w-4 h-4 text-green-400" />
                          <span className="text-sm text-gray-400">Deposit Rates:</span>
                          <span className="text-sm text-white">
                            {affiliate.deposit_commission_rates?.level_1 || 5}% -&gt; {affiliate.deposit_commission_rates?.level_5 || 1}%
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Percent className="w-4 h-4 text-blue-400" />
                          <span className="text-sm text-gray-400">Fee Share:</span>
                          <span className="text-sm text-white">
                            {affiliate.fee_share_rates?.level_1 || 50}% -&gt; {affiliate.fee_share_rates?.level_5 || 10}%
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Gift className="w-4 h-4 text-green-400" />
                          <span className="text-sm text-gray-400">Deposit Commissions:</span>
                          <span className="text-sm text-green-400">
                            ${(affiliate.deposit_commissions_earned || 0).toFixed(2)}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Percent className="w-4 h-4 text-blue-400" />
                          <span className="text-sm text-gray-400">Fee Revenue:</span>
                          <span className="text-sm text-blue-400">
                            ${(affiliate.fee_share_earned || 0).toFixed(2)}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Wallet className="w-4 h-4 text-amber-400" />
                          <span className="text-sm text-gray-400">Withdrawn:</span>
                          <span className="text-sm text-amber-400">
                            ${(affiliate.total_withdrawn || 0).toFixed(2)}
                          </span>
                        </div>
                      </div>
                    </div>
                  ))}

                  {filteredAffiliates.length === 0 && (
                    <div className="text-center py-12 text-gray-400">
                      <Crown className="w-16 h-16 mx-auto mb-4 opacity-50" />
                      <p>No exclusive affiliates found</p>
                      <button
                        onClick={() => setShowEnrollModal(true)}
                        className="mt-4 px-6 py-2 bg-[#fcd535] text-black rounded-lg font-semibold"
                      >
                        Enroll First Affiliate
                      </button>
                    </div>
                  )}
                </div>
              </>
            )}

            {activeTab === 'withdrawals' && (
              <div className="space-y-6">
                {pendingWithdrawals.length > 0 && (
                  <div>
                    <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                      <Clock className="w-5 h-5 text-amber-400" />
                      Pending Withdrawals ({pendingWithdrawals.length})
                    </h3>
                    <div className="space-y-3">
                      {pendingWithdrawals.map((w) => (
                        <div key={w.withdrawal_id} className="p-4 bg-amber-500/10 border border-amber-500/30 rounded-xl">
                          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                            <div>
                              <div className="font-semibold text-white">
                                {w.full_name || w.email}
                              </div>
                              <div className="text-sm text-gray-400">{w.email}</div>
                              <div className="text-xs text-gray-500 mt-1">
                                {new Date(w.created_at).toLocaleString()}
                              </div>
                            </div>
                            <div className="text-right">
                              <div className="text-2xl font-bold text-amber-400">
                                ${w.amount.toFixed(2)} {w.currency}
                              </div>
                              <div className="text-sm text-gray-400">{w.network}</div>
                              <div className="text-xs font-mono text-gray-500 max-w-[200px] truncate">
                                {w.wallet_address}
                              </div>
                            </div>
                            <div className="flex gap-2">
                              <button
                                onClick={() => {
                                  setSelectedWithdrawal(w);
                                  setShowWithdrawalModal(true);
                                }}
                                className="px-4 py-2 bg-[#fcd535] hover:bg-[#fcd535]/90 text-black font-semibold rounded-lg transition-all"
                              >
                                Process
                              </button>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {processedWithdrawals.length > 0 && (
                  <div>
                    <h3 className="text-lg font-bold text-white mb-4">Processed Withdrawals</h3>
                    <div className="space-y-3">
                      {processedWithdrawals.map((w) => (
                        <div key={w.withdrawal_id} className="p-4 bg-[#0b0e11] border border-gray-700 rounded-xl">
                          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                            <div>
                              <div className="font-semibold text-white">
                                {w.full_name || w.email}
                              </div>
                              <div className="text-sm text-gray-400">{w.email}</div>
                              <div className="text-xs text-gray-500 mt-1">
                                {new Date(w.created_at).toLocaleString()}
                              </div>
                            </div>
                            <div className="text-center">
                              <div className="text-xl font-bold text-white">
                                ${w.amount.toFixed(2)} {w.currency}
                              </div>
                              <div className="text-sm text-gray-400">{w.network}</div>
                            </div>
                            <div className="text-right">
                              <span className={`px-3 py-1 rounded-full text-sm font-semibold ${
                                w.status === 'completed' ? 'bg-green-500/20 text-green-400' :
                                w.status === 'rejected' ? 'bg-red-500/20 text-red-400' :
                                'bg-blue-500/20 text-blue-400'
                              }`}>
                                {w.status.toUpperCase()}
                              </span>
                              {w.processed_at && (
                                <div className="text-xs text-gray-500 mt-1">
                                  {new Date(w.processed_at).toLocaleDateString()}
                                </div>
                              )}
                              {w.rejection_reason && (
                                <div className="text-xs text-red-400 mt-1">
                                  Reason: {w.rejection_reason}
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {withdrawals.length === 0 && (
                  <div className="text-center py-12 text-gray-400">
                    <Wallet className="w-16 h-16 mx-auto mb-4 opacity-50" />
                    <p>No withdrawal requests</p>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {showEnrollModal && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-2xl p-8 w-full max-w-lg border border-gray-800">
            <h2 className="text-2xl font-bold text-white mb-6 flex items-center gap-3">
              <UserPlus className="w-6 h-6 text-[#fcd535]" />
              Enroll Exclusive Affiliate
            </h2>

            {enrollError && (
              <div className="mb-4 p-4 bg-red-500/20 border border-red-500/30 rounded-lg flex items-center gap-3">
                <AlertCircle className="w-5 h-5 text-red-400" />
                <span className="text-red-400">{enrollError}</span>
              </div>
            )}

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-semibold text-gray-300 mb-2">User Email</label>
                <input
                  type="email"
                  value={enrollEmail}
                  onChange={(e) => setEnrollEmail(e.target.value)}
                  placeholder="user@example.com"
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#fcd535]"
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-300 mb-2">
                  <Gift className="inline w-4 h-4 mr-1 text-green-400" />
                  Deposit Commission Rates (%)
                </label>
                <div className="grid grid-cols-5 gap-2">
                  {[1, 2, 3, 4, 5].map((level) => (
                    <div key={level} className="text-center">
                      <div className="text-xs text-gray-500 mb-1">L{level}</div>
                      <input
                        type="number"
                        min="0"
                        max="100"
                        value={depositRates[`level_${level}` as keyof typeof depositRates]}
                        onChange={(e) => setDepositRates({ ...depositRates, [`level_${level}`]: parseFloat(e.target.value) || 0 })}
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded px-2 py-1 text-white text-center text-sm focus:outline-none focus:border-[#fcd535]"
                      />
                    </div>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-300 mb-2">
                  <Percent className="inline w-4 h-4 mr-1 text-blue-400" />
                  Trading Fee Revenue Share (%)
                </label>
                <div className="grid grid-cols-5 gap-2">
                  {[1, 2, 3, 4, 5].map((level) => (
                    <div key={level} className="text-center">
                      <div className="text-xs text-gray-500 mb-1">L{level}</div>
                      <input
                        type="number"
                        min="0"
                        max="100"
                        value={feeRates[`level_${level}` as keyof typeof feeRates]}
                        onChange={(e) => setFeeRates({ ...feeRates, [`level_${level}`]: parseFloat(e.target.value) || 0 })}
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded px-2 py-1 text-white text-center text-sm focus:outline-none focus:border-[#fcd535]"
                      />
                    </div>
                  ))}
                </div>
              </div>

              <div className="p-4 bg-[#fcd535]/10 border border-[#fcd535]/30 rounded-lg">
                <h4 className="font-semibold text-[#fcd535] mb-2">Commission Structure</h4>
                <ul className="text-sm text-gray-300 space-y-1">
                  <li>Level 1 (Direct Referrals): {depositRates.level_1}% deposit, {feeRates.level_1}% fees</li>
                  <li>Level 2: {depositRates.level_2}% deposit, {feeRates.level_2}% fees</li>
                  <li>Level 3: {depositRates.level_3}% deposit, {feeRates.level_3}% fees</li>
                  <li>Level 4: {depositRates.level_4}% deposit, {feeRates.level_4}% fees</li>
                  <li>Level 5: {depositRates.level_5}% deposit, {feeRates.level_5}% fees</li>
                </ul>
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => {
                  setShowEnrollModal(false);
                  setEnrollError(null);
                  setEnrollEmail('');
                }}
                className="flex-1 py-3 bg-[#2b3139] hover:bg-[#363e47] text-white rounded-lg font-semibold transition-all"
              >
                Cancel
              </button>
              <button
                onClick={handleEnroll}
                disabled={enrolling || !enrollEmail.trim()}
                className="flex-1 py-3 bg-[#fcd535] hover:bg-[#fcd535]/90 disabled:bg-gray-600 text-black font-bold rounded-lg transition-all flex items-center justify-center gap-2"
              >
                {enrolling ? (
                  <>
                    <RefreshCw className="w-5 h-5 animate-spin" />
                    Enrolling...
                  </>
                ) : (
                  <>
                    <CheckCircle className="w-5 h-5" />
                    Enroll
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {showWithdrawalModal && selectedWithdrawal && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-2xl p-8 w-full max-w-lg border border-gray-800">
            <h2 className="text-2xl font-bold text-white mb-6 flex items-center gap-3">
              <Wallet className="w-6 h-6 text-[#fcd535]" />
              Process Withdrawal
            </h2>

            <div className="space-y-4 mb-6">
              <div className="p-4 bg-[#0b0e11] rounded-lg">
                <div className="text-sm text-gray-400 mb-1">User</div>
                <div className="font-semibold text-white">{selectedWithdrawal.full_name || selectedWithdrawal.email}</div>
                <div className="text-sm text-gray-400">{selectedWithdrawal.email}</div>
              </div>

              <div className="p-4 bg-[#0b0e11] rounded-lg">
                <div className="text-sm text-gray-400 mb-1">Amount</div>
                <div className="text-3xl font-bold text-[#fcd535]">
                  ${selectedWithdrawal.amount.toFixed(2)} {selectedWithdrawal.currency}
                </div>
              </div>

              <div className="p-4 bg-[#0b0e11] rounded-lg">
                <div className="text-sm text-gray-400 mb-1">Wallet Address ({selectedWithdrawal.network})</div>
                <div className="font-mono text-sm text-white break-all">{selectedWithdrawal.wallet_address}</div>
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-300 mb-2">
                  Rejection Reason (if rejecting)
                </label>
                <textarea
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  placeholder="Enter reason for rejection..."
                  rows={3}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#fcd535]"
                />
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => {
                  setShowWithdrawalModal(false);
                  setSelectedWithdrawal(null);
                  setRejectionReason('');
                }}
                className="flex-1 py-3 bg-[#2b3139] hover:bg-[#363e47] text-white rounded-lg font-semibold transition-all"
              >
                Cancel
              </button>
              <button
                onClick={() => handleProcessWithdrawal('reject')}
                disabled={processingWithdrawal}
                className="py-3 px-6 bg-red-500/20 hover:bg-red-500/30 text-red-400 rounded-lg font-semibold transition-all flex items-center gap-2"
              >
                <XCircle className="w-5 h-5" />
                Reject
              </button>
              <button
                onClick={() => handleProcessWithdrawal('approve')}
                disabled={processingWithdrawal}
                className="flex-1 py-3 bg-green-500 hover:bg-green-600 text-white font-bold rounded-lg transition-all flex items-center justify-center gap-2"
              >
                {processingWithdrawal ? (
                  <>
                    <RefreshCw className="w-5 h-5 animate-spin" />
                    Processing...
                  </>
                ) : (
                  <>
                    <CheckCircle className="w-5 h-5" />
                    Approve
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {showNetworkModal && selectedAffiliateForNetwork && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-2xl w-full max-w-4xl max-h-[85vh] overflow-hidden border border-gray-800 flex flex-col">
            <div className="p-6 border-b border-gray-800">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h2 className="text-2xl font-bold text-white flex items-center gap-3">
                    <Network className="w-6 h-6 text-cyan-400" />
                    Referral Network
                  </h2>
                  <p className="text-gray-400 mt-1">
                    {selectedAffiliateForNetwork.full_name || selectedAffiliateForNetwork.email}
                  </p>
                </div>
                <button
                  onClick={() => {
                    setShowNetworkModal(false);
                    setSelectedAffiliateForNetwork(null);
                    setNetworkStats(null);
                    setNetworkMembers([]);
                    setShowAllReferrals(false);
                  }}
                  className="p-2 hover:bg-[#2b3139] rounded-lg transition-all"
                >
                  <X className="w-6 h-6 text-gray-400" />
                </button>
              </div>

              <div className="flex items-center justify-between">
                <div className="flex gap-4">
                  <div className="px-3 py-1.5 bg-green-500/20 border border-green-500/30 rounded-lg">
                    <span className="text-green-400 font-semibold">{eligibleCount}</span>
                    <span className="text-gray-400 text-sm ml-2">Eligible (after enrollment)</span>
                  </div>
                  <div className="px-3 py-1.5 bg-gray-500/20 border border-gray-500/30 rounded-lg">
                    <span className="text-gray-300 font-semibold">{ineligibleCount}</span>
                    <span className="text-gray-400 text-sm ml-2">Before enrollment</span>
                  </div>
                </div>
                <button
                  onClick={() => setShowAllReferrals(!showAllReferrals)}
                  className={`px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
                    showAllReferrals
                      ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                      : 'bg-[#2b3139] text-gray-300 hover:bg-[#363d47]'
                  }`}
                >
                  {showAllReferrals ? 'Showing All' : 'Show All Referrals'}
                </button>
              </div>
            </div>

            <div className="flex-1 overflow-y-auto p-6">
              {loadingNetwork ? (
                <div className="flex items-center justify-center py-12">
                  <div className="w-10 h-10 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin" />
                </div>
              ) : getFilteredMembers().length === 0 ? (
                <div className="text-center py-12 text-gray-400">
                  <Users className="w-16 h-16 mx-auto mb-4 opacity-50" />
                  <p>{showAllReferrals ? 'No referrals found' : 'No eligible referrals (signed up after enrollment)'}</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {[1, 2, 3, 4, 5].map((level) => {
                    const count = getLevelCount(level);
                    if (count === 0) return null;
                    const isExpanded = expandedLevels.has(level);
                    const members = getMembersByLevel(level);
                    const levelColors = {
                      1: { bg: 'bg-cyan-500/20', text: 'text-cyan-400', border: 'border-cyan-500/30' },
                      2: { bg: 'bg-blue-500/20', text: 'text-blue-400', border: 'border-blue-500/30' },
                      3: { bg: 'bg-green-500/20', text: 'text-green-400', border: 'border-green-500/30' },
                      4: { bg: 'bg-amber-500/20', text: 'text-amber-400', border: 'border-amber-500/30' },
                      5: { bg: 'bg-orange-500/20', text: 'text-orange-400', border: 'border-orange-500/30' }
                    };
                    const colors = levelColors[level as keyof typeof levelColors];

                    return (
                      <div key={level} className={`rounded-xl border ${colors.border} overflow-hidden`}>
                        <button
                          onClick={() => toggleLevel(level)}
                          className={`w-full p-4 ${colors.bg} flex items-center justify-between hover:opacity-90 transition-all`}
                        >
                          <div className="flex items-center gap-3">
                            {isExpanded ? (
                              <ChevronDown className={`w-5 h-5 ${colors.text}`} />
                            ) : (
                              <ChevronRight className={`w-5 h-5 ${colors.text}`} />
                            )}
                            <span className={`font-bold ${colors.text}`}>Level {level}</span>
                            <span className="text-gray-400 text-sm">
                              {level === 1 ? '(Direct Referrals)' : `(Referrals of L${level - 1})`}
                            </span>
                          </div>
                          <span className={`px-3 py-1 rounded-full text-sm font-bold ${colors.bg} ${colors.text}`}>
                            {count} users
                          </span>
                        </button>

                        {isExpanded && (
                          <div className="bg-[#0b0e11]">
                            <div className="overflow-x-auto">
                              <table className="w-full">
                                <thead>
                                  <tr className="border-b border-gray-800">
                                    <th className="text-left p-3 text-xs font-semibold text-gray-400">User</th>
                                    <th className="text-left p-3 text-xs font-semibold text-gray-400">Registered</th>
                                    {showAllReferrals && (
                                      <th className="text-center p-3 text-xs font-semibold text-gray-400">Status</th>
                                    )}
                                    <th className="text-right p-3 text-xs font-semibold text-gray-400">Volume</th>
                                  </tr>
                                </thead>
                                <tbody>
                                  {members.map((member) => (
                                    <tr key={member.user_id} className={`border-b border-gray-800/50 hover:bg-[#1a1d24]/50 ${!member.eligible && showAllReferrals ? 'opacity-60' : ''}`}>
                                      <td className="p-3">
                                        <div>
                                          <div className="font-semibold text-white text-sm">
                                            {member.full_name || member.username || 'No Name'}
                                          </div>
                                          <div className="text-xs text-gray-400">{member.email}</div>
                                        </div>
                                      </td>
                                      <td className="p-3 text-sm text-gray-400">
                                        {new Date(member.registered_at).toLocaleDateString()}
                                      </td>
                                      {showAllReferrals && (
                                        <td className="p-3 text-center">
                                          <span className={`px-2 py-0.5 rounded text-xs font-semibold ${
                                            member.eligible
                                              ? 'bg-green-500/20 text-green-400'
                                              : 'bg-gray-500/20 text-gray-400'
                                          }`}>
                                            {member.eligible ? 'Eligible' : 'Before'}
                                          </span>
                                        </td>
                                      )}
                                      <td className="p-3 text-right">
                                        <span className="text-sm text-gray-300">
                                          ${(member.trading_volume || 0).toLocaleString()}
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
                    );
                  })}

                  <div className="mt-6 p-4 bg-[#0b0e11] rounded-xl">
                    <h4 className="font-semibold text-white mb-3">
                      {showAllReferrals ? 'All Referrals Summary' : 'Eligible Referrals Summary'}
                    </h4>
                    <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                      {[1, 2, 3, 4, 5].map((level) => {
                        const count = getLevelCount(level);
                        const rate = selectedAffiliateForNetwork.deposit_commission_rates?.[`level_${level}` as keyof typeof selectedAffiliateForNetwork.deposit_commission_rates] || 0;
                        const feeRate = selectedAffiliateForNetwork.fee_share_rates?.[`level_${level}` as keyof typeof selectedAffiliateForNetwork.fee_share_rates] || 0;
                        return (
                          <div key={level} className="text-center p-3 bg-[#1a1d24] rounded-lg">
                            <div className="text-2xl font-bold text-white">{count}</div>
                            <div className="text-xs text-gray-400 mb-1">Level {level}</div>
                            <div className="text-xs text-green-400">{rate}% deposit</div>
                            <div className="text-xs text-blue-400">{feeRate}% fees</div>
                          </div>
                        );
                      })}
                    </div>
                    <div className="mt-4 pt-4 border-t border-gray-700 grid grid-cols-3 gap-4">
                      <div className="text-center">
                        <div className="text-2xl font-bold text-white">{getFilteredMembers().length}</div>
                        <div className="text-sm text-gray-400">{showAllReferrals ? 'Total' : 'Eligible'}</div>
                      </div>
                      <div className="text-center">
                        <div className="text-2xl font-bold text-green-400">{eligibleCount}</div>
                        <div className="text-sm text-gray-400">Commission Eligible</div>
                      </div>
                      <div className="text-center">
                        <div className="text-2xl font-bold text-[#fcd535]">
                          ${(getLevelEarnings(1) + getLevelEarnings(2) + getLevelEarnings(3) + getLevelEarnings(4) + getLevelEarnings(5)).toFixed(2)}
                        </div>
                        <div className="text-sm text-gray-400">Total Earnings</div>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
