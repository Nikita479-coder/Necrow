import { useState, useEffect } from 'react';
import {
  DollarSign,
  TrendingUp,
  Users,
  Download,
  Copy,
  CheckCircle,
  RefreshCw,
  AlertCircle,
  Wallet,
  ArrowUpRight,
  Gift,
  Percent
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface LevelRates {
  level_1: number;
  level_2: number;
  level_3: number;
  level_4: number;
  level_5: number;
  level_6?: number;
  level_7?: number;
  level_8?: number;
  level_9?: number;
  level_10?: number;
  [key: string]: number | undefined;
}

interface NetworkStats {
  level_1_count: number;
  level_2_count: number;
  level_3_count: number;
  level_4_count: number;
  level_5_count: number;
  level_6_count?: number;
  level_7_count?: number;
  level_8_count?: number;
  level_9_count?: number;
  level_10_count?: number;
  level_1_earnings: number;
  level_2_earnings: number;
  level_3_earnings: number;
  level_4_earnings: number;
  level_5_earnings: number;
  level_6_earnings?: number;
  level_7_earnings?: number;
  level_8_earnings?: number;
  level_9_earnings?: number;
  level_10_earnings?: number;
  this_month: number;
  [key: string]: number | undefined;
}

interface ExclusiveStats {
  enrolled: boolean;
  referral_code?: string;
  deposit_rates?: LevelRates;
  fee_rates?: LevelRates;
  balance?: {
    available: number;
    pending: number;
    total_earned: number;
    total_withdrawn: number;
    deposit_commissions: number;
    fee_share: number;
    copy_profit: number;
  };
  copy_profit_rates?: LevelRates;
  network?: NetworkStats;
  recent_commissions?: any[];
}

interface WithdrawalHistory {
  id: string;
  amount: number;
  currency: string;
  wallet_address: string;
  network: string;
  status: string;
  created_at: string;
}

function ExclusiveAffiliateDashboard() {
  const { user, profile } = useAuth();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stats, setStats] = useState<ExclusiveStats | null>(null);
  const [withdrawals, setWithdrawals] = useState<WithdrawalHistory[]>([]);
  const [copiedLink, setCopiedLink] = useState(false);
  const [activeTab, setActiveTab] = useState<'overview' | 'earnings' | 'withdraw'>('overview');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [withdrawAddress, setWithdrawAddress] = useState('');
  const [withdrawNetwork, setWithdrawNetwork] = useState('TRC20');
  const [withdrawing, setWithdrawing] = useState(false);
  const [withdrawError, setWithdrawError] = useState<string | null>(null);
  const [withdrawSuccess, setWithdrawSuccess] = useState(false);

  useEffect(() => {
    if (user) {
      loadStats();
    }
  }, [user]);

  const loadStats = async (retryCount = 0) => {
    if (!user) return;
    setLoading(true);
    setError(null);

    const maxRetries = 3;
    const retryDelay = (attempt: number) => Math.min(1000 * Math.pow(2, attempt), 5000);

    try {
      const { data, error: rpcError } = await supabase.rpc('get_exclusive_affiliate_stats', {
        p_user_id: user.id
      });

      if (rpcError) throw rpcError;
      setStats(data);

      const { data: withdrawalData } = await supabase
        .from('exclusive_affiliate_withdrawals')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(10);

      setWithdrawals(withdrawalData || []);
      setLoading(false);
    } catch (err: any) {
      console.error('Error loading exclusive affiliate stats:', err);

      if (retryCount < maxRetries && (err.message?.includes('fetch') || err.message?.includes('Failed to fetch') || err.code === 'NETWORK_ERROR')) {
        setTimeout(() => {
          loadStats(retryCount + 1);
        }, retryDelay(retryCount));
      } else {
        setError(err.message || 'Failed to load data');
        setLoading(false);
      }
    }
  };

  const copyAffiliateLink = () => {
    const link = `${window.location.origin}/signup?ref=${stats?.referral_code || profile?.referral_code}`;
    navigator.clipboard.writeText(link);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  };

  const handleWithdraw = async () => {
    if (!user || !withdrawAmount || !withdrawAddress) return;

    const amount = parseFloat(withdrawAmount);
    if (isNaN(amount) || amount < 10) {
      setWithdrawError('Minimum withdrawal is $10');
      return;
    }

    if (amount > (stats?.balance?.available || 0)) {
      setWithdrawError('Insufficient balance');
      return;
    }

    setWithdrawing(true);
    setWithdrawError(null);

    try {
      const { data, error } = await supabase.rpc('request_exclusive_affiliate_withdrawal', {
        p_user_id: user.id,
        p_amount: amount,
        p_wallet_address: withdrawAddress,
        p_network: withdrawNetwork
      });

      if (error) throw error;

      if (data?.success) {
        setWithdrawSuccess(true);
        setWithdrawAmount('');
        setWithdrawAddress('');
        loadStats();
        setTimeout(() => setWithdrawSuccess(false), 3000);
      } else {
        setWithdrawError(data?.error || 'Withdrawal failed');
      }
    } catch (err: any) {
      setWithdrawError(err.message || 'Withdrawal failed');
    } finally {
      setWithdrawing(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="text-center">
          <div className="w-10 h-10 border-4 border-[#fcd535] border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-400">Loading affiliate dashboard...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="text-center">
          <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
          <p className="text-gray-400 mb-4">Unable to load dashboard data</p>
          <button
            onClick={() => loadStats()}
            className="px-6 py-3 bg-[#fcd535] hover:bg-[#fcd535]/90 text-black rounded-lg transition-all flex items-center gap-2 mx-auto"
          >
            <RefreshCw className="w-5 h-5" />
            Try Again
          </button>
        </div>
      </div>
    );
  }

  if (!stats?.enrolled) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="text-center">
          <AlertCircle className="w-12 h-12 text-amber-500 mx-auto mb-4" />
          <p className="text-gray-400 mb-2">Exclusive affiliate data not available</p>
          <p className="text-gray-500 text-sm">Please contact support if you believe this is an error</p>
        </div>
      </div>
    );
  }

  const depositRates = stats.deposit_rates || { level_1: 5, level_2: 4, level_3: 3, level_4: 2, level_5: 1, level_6: 0, level_7: 0, level_8: 0, level_9: 0, level_10: 0 };
  const feeRates = stats.fee_rates || { level_1: 50, level_2: 40, level_3: 30, level_4: 20, level_5: 10, level_6: 0, level_7: 0, level_8: 0, level_9: 0, level_10: 0 };
  const copyProfitRates = stats.copy_profit_rates || { level_1: 0, level_2: 0, level_3: 0, level_4: 0, level_5: 0, level_6: 0, level_7: 0, level_8: 0, level_9: 0, level_10: 0 };
  const balance = stats.balance || { available: 0, pending: 0, total_earned: 0, total_withdrawn: 0, deposit_commissions: 0, fee_share: 0, copy_profit: 0 };
  const network = stats.network || { level_1_count: 0, level_2_count: 0, level_3_count: 0, level_4_count: 0, level_5_count: 0, level_6_count: 0, level_7_count: 0, level_8_count: 0, level_9_count: 0, level_10_count: 0, level_1_earnings: 0, level_2_earnings: 0, level_3_earnings: 0, level_4_earnings: 0, level_5_earnings: 0, level_6_earnings: 0, level_7_earnings: 0, level_8_earnings: 0, level_9_earnings: 0, level_10_earnings: 0, this_month: 0 };

  const getActiveLevels = () => {
    const levels: number[] = [];
    for (let i = 1; i <= 10; i++) {
      const rate = depositRates[`level_${i}`] || feeRates[`level_${i}`] || 0;
      if (rate > 0) levels.push(i);
    }
    return levels.length > 0 ? levels : [1, 2, 3, 4, 5];
  };
  const activeLevels = getActiveLevels();

  const totalNetwork = activeLevels.reduce((sum, level) => sum + (network[`level_${level}_count`] || 0), 0);

  const renderOverview = () => (
    <div className="space-y-6">
      <div className="bg-gradient-to-br from-[#fcd535] to-amber-600 rounded-2xl p-8 text-black">
        <div className="flex flex-col lg:flex-row justify-between items-start gap-6">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="px-3 py-1 bg-black/20 rounded-full text-sm font-bold">VIP EXCLUSIVE</span>
            </div>
            <h2 className="text-3xl font-bold mb-2">Exclusive Affiliate Program</h2>
            <p className="text-black/70 mb-6">Your premium multi-level commission dashboard</p>
          </div>
          <div className="text-right">
            <div className="text-sm text-black/70 mb-1">Available Balance</div>
            <div className="text-4xl font-bold">${balance.available.toFixed(2)}</div>
            <div className="text-sm text-black/70 mt-2">
              Total Earned: ${balance.total_earned.toFixed(2)}
            </div>
          </div>
        </div>

        <div className="mt-6 p-4 bg-black/10 rounded-xl">
          <div className="flex items-center justify-between mb-2">
            <div className="text-sm text-black/70">Your Affiliate Link</div>
            <button
              onClick={copyAffiliateLink}
              className="px-4 py-2 bg-black/20 hover:bg-black/30 rounded-lg transition-all flex items-center gap-2"
            >
              {copiedLink ? (
                <>
                  <CheckCircle className="w-4 h-4" />
                  Copied!
                </>
              ) : (
                <>
                  <Copy className="w-4 h-4" />
                  Copy Link
                </>
              )}
            </button>
          </div>
          <div className="text-sm font-mono break-all bg-black/10 p-3 rounded-lg">
            {window.location.origin}/signup?ref={stats?.referral_code || profile?.referral_code}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <div className="flex items-center justify-between mb-3">
            <Users className="w-8 h-8 text-[#fcd535]" />
          </div>
          <div className="text-3xl font-bold mb-1">{totalNetwork}</div>
          <div className="text-sm text-gray-400">Total Network</div>
        </div>

        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <div className="flex items-center justify-between mb-3">
            <Gift className="w-8 h-8 text-green-400" />
          </div>
          <div className="text-3xl font-bold mb-1">${balance.deposit_commissions.toFixed(2)}</div>
          <div className="text-sm text-gray-400">Deposit Commissions</div>
        </div>

        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <div className="flex items-center justify-between mb-3">
            <Percent className="w-8 h-8 text-blue-400" />
          </div>
          <div className="text-3xl font-bold mb-1">${balance.fee_share.toFixed(2)}</div>
          <div className="text-sm text-gray-400">Fee Revenue Share</div>
        </div>

        {[1,2,3,4,5,6,7,8,9,10].some(level => (copyProfitRates[`level_${level}`] || 0) > 0) && (
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <TrendingUp className="w-8 h-8 text-cyan-400" />
            </div>
            <div className="text-3xl font-bold mb-1">${(balance.copy_profit || 0).toFixed(2)}</div>
            <div className="text-sm text-gray-400">Copy Trading Profits</div>
          </div>
        )}

        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <div className="flex items-center justify-between mb-3">
            <ArrowUpRight className="w-8 h-8 text-emerald-400" />
          </div>
          <div className="text-3xl font-bold mb-1">${network.this_month.toFixed(2)}</div>
          <div className="text-sm text-gray-400">This Month</div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
            <Gift className="w-5 h-5 text-green-400" />
            Deposit Commission Rates
          </h3>
          <div className="space-y-2 max-h-[400px] overflow-y-auto">
            {activeLevels.map((level) => {
              const rate = depositRates[`level_${level}`] || 0;
              const count = network[`level_${level}_count`] || 0;
              return (
                <div key={level} className="flex items-center justify-between p-3 bg-[#0b0e11] rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-full bg-green-500/20 flex items-center justify-center text-green-400 font-bold text-sm">
                      L{level}
                    </div>
                    <div>
                      <div className="font-semibold text-sm">Level {level}</div>
                      <div className="text-xs text-gray-400">{count} members</div>
                    </div>
                  </div>
                  <div className="text-xl font-bold text-green-400">{rate}%</div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
            <Percent className="w-5 h-5 text-blue-400" />
            Trading Fee Revenue Share
          </h3>
          <div className="space-y-2 max-h-[400px] overflow-y-auto">
            {activeLevels.map((level) => {
              const rate = feeRates[`level_${level}`] || 0;
              const earnings = network[`level_${level}_earnings`] || 0;
              return (
                <div key={level} className="flex items-center justify-between p-3 bg-[#0b0e11] rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-full bg-blue-500/20 flex items-center justify-center text-blue-400 font-bold text-sm">
                      L{level}
                    </div>
                    <div>
                      <div className="font-semibold text-sm">Level {level}</div>
                      <div className="text-xs text-gray-400">${(earnings as number).toFixed(2)} earned</div>
                    </div>
                  </div>
                  <div className="text-xl font-bold text-blue-400">{rate}%</div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {activeLevels.some(level => (copyProfitRates[`level_${level}`] || 0) > 0) && (
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-cyan-400" />
            Copy Trading Profit Commissions
          </h3>
          <p className="text-sm text-gray-400 mb-4">
            Earn commission when your referred users make profits from copy trading.
          </p>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
            {activeLevels.map((level) => {
              const rate = copyProfitRates[`level_${level}`] || 0;
              return (
                <div key={level} className="p-3 bg-[#0b0e11] rounded-lg text-center">
                  <div className="text-xs text-gray-400 mb-1">Level {level}</div>
                  <div className="text-xl font-bold text-cyan-400">{rate}%</div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {stats.recent_commissions && stats.recent_commissions.length > 0 && (
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-xl font-bold mb-4">Recent Commissions</h3>
          <div className="space-y-3">
            {stats.recent_commissions.slice(0, 5).map((commission: any) => {
              const getTypeLabel = () => {
                switch (commission.commission_type) {
                  case 'deposit': return 'Deposit Commission';
                  case 'copy_profit': return 'Copy Trading Profit';
                  default: return 'Trading Fee Share';
                }
              };
              const getTypeColor = () => {
                switch (commission.commission_type) {
                  case 'deposit': return 'text-green-400';
                  case 'copy_profit': return 'text-cyan-400';
                  default: return 'text-blue-400';
                }
              };
              return (
                <div key={commission.id} className="flex justify-between items-center p-3 bg-[#0b0e11] rounded-lg">
                  <div>
                    <div className="font-semibold text-sm">
                      {getTypeLabel()} - Level {commission.tier_level}
                    </div>
                    <div className="text-xs text-gray-400">
                      {new Date(commission.created_at).toLocaleString()}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className={`font-bold ${getTypeColor()}`}>
                      +${commission.commission_amount.toFixed(2)}
                    </div>
                    <div className="text-xs text-gray-400">{commission.commission_rate}%</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );

  const renderEarnings = () => (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-gradient-to-br from-green-600/20 to-green-800/20 rounded-xl p-6 border border-green-500/30">
          <div className="text-sm text-green-400 mb-2">Total Earned</div>
          <div className="text-3xl font-bold text-green-400">${balance.total_earned.toFixed(2)}</div>
        </div>
        <div className="bg-gradient-to-br from-blue-600/20 to-blue-800/20 rounded-xl p-6 border border-blue-500/30">
          <div className="text-sm text-blue-400 mb-2">Total Withdrawn</div>
          <div className="text-3xl font-bold text-blue-400">${balance.total_withdrawn.toFixed(2)}</div>
        </div>
        <div className="bg-gradient-to-br from-amber-600/20 to-amber-800/20 rounded-xl p-6 border border-amber-500/30">
          <div className="text-sm text-amber-400 mb-2">Pending Withdrawals</div>
          <div className="text-3xl font-bold text-amber-400">${balance.pending.toFixed(2)}</div>
        </div>
      </div>

      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-xl font-bold mb-4">All Commissions</h3>
        <div className="space-y-3 max-h-[500px] overflow-y-auto">
          {stats.recent_commissions && stats.recent_commissions.length > 0 ? (
            stats.recent_commissions.map((commission: any) => (
              <div key={commission.id} className="flex justify-between items-center p-4 bg-[#0b0e11] rounded-lg">
                <div>
                  <div className="font-semibold">
                    {commission.commission_type === 'deposit' ? 'Deposit Commission' : 'Trading Fee Share'}
                  </div>
                  <div className="text-sm text-gray-400">
                    Level {commission.tier_level} - {commission.commission_rate}% of ${commission.source_amount.toFixed(2)}
                  </div>
                  <div className="text-xs text-gray-500">
                    {new Date(commission.created_at).toLocaleString()}
                  </div>
                </div>
                <div className={`text-xl font-bold ${commission.commission_type === 'deposit' ? 'text-green-400' : 'text-blue-400'}`}>
                  +${commission.commission_amount.toFixed(2)}
                </div>
              </div>
            ))
          ) : (
            <div className="text-center py-12 text-gray-400">
              <DollarSign className="w-12 h-12 mx-auto mb-2 opacity-50" />
              <div>No commissions yet</div>
              <div className="text-sm">Share your link to start earning</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );

  const renderWithdraw = () => (
    <div className="space-y-6">
      <div className="bg-gradient-to-br from-[#fcd535]/20 to-amber-600/20 rounded-xl p-6 border border-[#fcd535]/30">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-sm text-gray-400 mb-1">Available for Withdrawal</div>
            <div className="text-4xl font-bold text-[#fcd535]">${balance.available.toFixed(2)}</div>
          </div>
          <Wallet className="w-12 h-12 text-[#fcd535]/50" />
        </div>
      </div>

      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-xl font-bold mb-6">Request Withdrawal</h3>

        {withdrawSuccess && (
          <div className="mb-4 p-4 bg-green-500/20 border border-green-500/30 rounded-lg flex items-center gap-3">
            <CheckCircle className="w-5 h-5 text-green-400" />
            <span className="text-green-400">Withdrawal request submitted successfully!</span>
          </div>
        )}

        {withdrawError && (
          <div className="mb-4 p-4 bg-red-500/20 border border-red-500/30 rounded-lg flex items-center gap-3">
            <AlertCircle className="w-5 h-5 text-red-400" />
            <span className="text-red-400">{withdrawError}</span>
          </div>
        )}

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-semibold mb-2">Amount (USDT)</label>
            <div className="relative">
              <input
                type="number"
                value={withdrawAmount}
                onChange={(e) => setWithdrawAmount(e.target.value)}
                placeholder="Minimum $10"
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 focus:outline-none focus:border-[#fcd535]"
              />
              <button
                onClick={() => setWithdrawAmount(balance.available.toString())}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-[#fcd535] hover:underline"
              >
                MAX
              </button>
            </div>
          </div>

          <div>
            <label className="block text-sm font-semibold mb-2">Network</label>
            <select
              value={withdrawNetwork}
              onChange={(e) => setWithdrawNetwork(e.target.value)}
              className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 focus:outline-none focus:border-[#fcd535]"
            >
              <option value="TRC20">USDT (TRC20)</option>
              <option value="ERC20">USDT (ERC20)</option>
              <option value="BEP20">USDT (BEP20)</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-semibold mb-2">Wallet Address</label>
            <input
              type="text"
              value={withdrawAddress}
              onChange={(e) => setWithdrawAddress(e.target.value)}
              placeholder="Enter your wallet address"
              className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 focus:outline-none focus:border-[#fcd535]"
            />
          </div>

          <button
            onClick={handleWithdraw}
            disabled={withdrawing || !withdrawAmount || !withdrawAddress || parseFloat(withdrawAmount) > balance.available}
            className="w-full py-4 bg-[#fcd535] hover:bg-[#fcd535]/90 disabled:bg-gray-600 disabled:cursor-not-allowed text-black font-bold rounded-lg transition-all flex items-center justify-center gap-2"
          >
            {withdrawing ? (
              <>
                <RefreshCw className="w-5 h-5 animate-spin" />
                Processing...
              </>
            ) : (
              <>
                <ArrowUpRight className="w-5 h-5" />
                Request Withdrawal
              </>
            )}
          </button>

          <p className="text-sm text-gray-400 text-center">
            Minimum withdrawal: $10 USDT. Withdrawals are processed within 24-48 hours.
          </p>
        </div>
      </div>

      {withdrawals.length > 0 && (
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-xl font-bold mb-4">Withdrawal History</h3>
          <div className="space-y-3">
            {withdrawals.map((w) => (
              <div key={w.id} className="flex justify-between items-center p-4 bg-[#0b0e11] rounded-lg">
                <div>
                  <div className="font-semibold">${w.amount.toFixed(2)} USDT</div>
                  <div className="text-sm text-gray-400">{w.network}</div>
                  <div className="text-xs text-gray-500 font-mono truncate max-w-[200px]">
                    {w.wallet_address}
                  </div>
                </div>
                <div className="text-right">
                  <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
                    w.status === 'completed' ? 'bg-green-500/20 text-green-400' :
                    w.status === 'pending' ? 'bg-amber-500/20 text-amber-400' :
                    w.status === 'rejected' ? 'bg-red-500/20 text-red-400' :
                    'bg-blue-500/20 text-blue-400'
                  }`}>
                    {w.status.toUpperCase()}
                  </span>
                  <div className="text-xs text-gray-500 mt-1">
                    {new Date(w.created_at).toLocaleDateString()}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="flex gap-2 overflow-x-auto pb-2">
        {[
          { id: 'overview', label: 'Overview', icon: TrendingUp },
          { id: 'earnings', label: 'Earnings', icon: DollarSign },
          { id: 'withdraw', label: 'Withdraw', icon: Wallet }
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`flex items-center gap-2 px-6 py-3 rounded-lg transition-all whitespace-nowrap ${
              activeTab === tab.id
                ? 'bg-[#fcd535] text-black'
                : 'bg-[#1a1d24] text-gray-400 hover:bg-[#2b3139] hover:text-white'
            }`}
          >
            <tab.icon className="w-5 h-5" />
            {tab.label}
          </button>
        ))}
        <button
          onClick={loadStats}
          className="p-3 bg-[#1a1d24] hover:bg-[#2b3139] rounded-lg transition-all ml-auto"
          title="Refresh"
        >
          <RefreshCw className="w-5 h-5 text-gray-400" />
        </button>
      </div>

      {activeTab === 'overview' && renderOverview()}
      {activeTab === 'earnings' && renderEarnings()}
      {activeTab === 'withdraw' && renderWithdraw()}
    </div>
  );
}

export default ExclusiveAffiliateDashboard;
