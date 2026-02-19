import { useState, useEffect } from 'react';
import {
  DollarSign,
  TrendingUp,
  Users,
  Copy,
  CheckCircle,
  RefreshCw,
  AlertCircle,
  Wallet,
  ArrowUpRight,
  Gift,
  Percent,
  Zap,
  Info,
  Lock,
  ChevronUp,
  BookOpen
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

interface BoostTier {
  min_ftds: number;
  max_ftds: number | null;
  multiplier: number;
  label: string;
  boost_pct: number;
}

interface BoostInfo {
  ftd_count: number;
  multiplier: number;
  boost_percentage: number;
  tier_label: string;
  next_tier_threshold: number;
  ftds_to_next_tier: number;
  eligible: boolean;
  all_tiers: BoostTier[];
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
  boost?: BoostInfo;
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
  const [activeTab, setActiveTab] = useState<'overview' | 'earnings' | 'withdraw' | 'boost-guide'>('overview');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [withdrawing, setWithdrawing] = useState(false);
  const [withdrawError, setWithdrawError] = useState<string | null>(null);
  const [withdrawSuccess, setWithdrawSuccess] = useState(false);
  const [showBoostInfo, setShowBoostInfo] = useState(false);

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
    if (!user || !withdrawAmount) return;

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
        p_amount: amount
      });

      if (error) throw error;

      if (data?.success) {
        setWithdrawSuccess(true);
        setWithdrawAmount('');
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
  const boost: BoostInfo = stats.boost || { ftd_count: 0, multiplier: 1.0, boost_percentage: 0, tier_label: 'No boost', next_tier_threshold: 5, ftds_to_next_tier: 5, eligible: true, all_tiers: [] };
  const hasActiveBoost = boost.multiplier > 1.0;

  const getBoostTierColor = (boostPct: number) => {
    if (boostPct >= 100) return { bg: 'bg-red-500/20', text: 'text-red-400', border: 'border-red-500/30', ring: 'ring-red-500/40' };
    if (boostPct >= 50) return { bg: 'bg-orange-500/20', text: 'text-orange-400', border: 'border-orange-500/30', ring: 'ring-orange-500/40' };
    if (boostPct >= 35) return { bg: 'bg-amber-500/20', text: 'text-amber-400', border: 'border-amber-500/30', ring: 'ring-amber-500/40' };
    if (boostPct >= 20) return { bg: 'bg-teal-500/20', text: 'text-teal-400', border: 'border-teal-500/30', ring: 'ring-teal-500/40' };
    return { bg: 'bg-gray-500/20', text: 'text-gray-400', border: 'border-gray-500/30', ring: 'ring-gray-500/40' };
  };

  const boostColors = getBoostTierColor(boost.boost_percentage);

  const getActiveLevels = () => {
    const levels: number[] = [];
    for (let i = 1; i <= 10; i++) {
      const count = network[`level_${i}_count`] || 0;
      const rate = depositRates[`level_${i}`] || feeRates[`level_${i}`] || copyProfitRates[`level_${i}`] || 0;
      if (count > 0 || rate > 0) levels.push(i);
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

      {boost.eligible ? (
        <div className={`rounded-2xl border ${boostColors.border} overflow-hidden`}>
          <div className={`${boostColors.bg} p-4 sm:p-6`}>
            <div className="flex flex-col lg:flex-row justify-between items-start gap-4">
              <div className="flex-1 w-full">
                <div className="flex items-center gap-3 mb-3">
                  <div className={`w-9 h-9 sm:w-10 sm:h-10 rounded-xl ${boostColors.bg} border ${boostColors.border} flex items-center justify-center shrink-0`}>
                    <Zap className={`w-4 h-4 sm:w-5 sm:h-5 ${boostColors.text}`} />
                  </div>
                  <div className="min-w-0">
                    <h3 className="text-base sm:text-lg font-bold text-white flex items-center gap-2">
                      Recruitment Boost
                      <button
                        onClick={() => setShowBoostInfo(!showBoostInfo)}
                        className="text-gray-400 hover:text-white transition-colors"
                      >
                        <Info className="w-4 h-4" />
                      </button>
                    </h3>
                    <p className="text-sm text-gray-400">Based on your Level-1 FTDs in the last 30 days</p>
                  </div>
                </div>

                {showBoostInfo && (
                  <div className="mb-4 p-3 bg-black/20 rounded-lg text-sm text-gray-300 space-y-1">
                    <p>- A qualifying FTD is a first deposit of $100+ from a KYC-verified direct referral</p>
                    <p>- Only deposits made in the last 30 days count (rolling window)</p>
                    <p>- Boost applies to deposit and copy trading commissions only</p>
                    <p>- Fee revenue share is not affected by the boost</p>
                    <p>- Your boost tier updates daily</p>
                  </div>
                )}

                <div className="grid grid-cols-3 gap-3 sm:gap-4 mb-4">
                  <div className="min-w-0">
                    <div className="text-xs sm:text-sm text-gray-400 mb-1">Current Boost</div>
                    <div className={`text-2xl sm:text-3xl font-bold ${hasActiveBoost ? boostColors.text : 'text-gray-500'}`}>
                      {hasActiveBoost ? `+${boost.boost_percentage}%` : 'None'}
                    </div>
                  </div>
                  <div className="min-w-0 border-l border-gray-700 pl-3 sm:pl-4">
                    <div className="text-xs sm:text-sm text-gray-400 mb-1">Multiplier</div>
                    <div className={`text-2xl sm:text-3xl font-bold ${hasActiveBoost ? 'text-white' : 'text-gray-500'}`}>
                      x{boost.multiplier.toFixed(2)}
                    </div>
                  </div>
                  <div className="min-w-0 border-l border-gray-700 pl-3 sm:pl-4">
                    <div className="text-xs sm:text-sm text-gray-400 mb-1">30-Day FTDs</div>
                    <div className="text-2xl sm:text-3xl font-bold text-white">{boost.ftd_count}</div>
                  </div>
                </div>

                {boost.ftds_to_next_tier > 0 && (
                  <div>
                    <div className="flex justify-between text-xs sm:text-sm mb-1.5 gap-2">
                      <span className="text-gray-400 whitespace-nowrap">
                        {boost.ftd_count} / {boost.next_tier_threshold} FTDs for next tier
                      </span>
                      <span className={`${boostColors.text} whitespace-nowrap`}>
                        {boost.ftds_to_next_tier} more needed
                      </span>
                    </div>
                    <div className="h-2.5 bg-black/30 rounded-full overflow-hidden">
                      <div
                        className={`h-full rounded-full transition-all duration-500 ${
                          hasActiveBoost ? 'bg-gradient-to-r from-teal-500 to-amber-500' : 'bg-gray-600'
                        }`}
                        style={{ width: `${Math.min((boost.ftd_count / boost.next_tier_threshold) * 100, 100)}%` }}
                      />
                    </div>
                  </div>
                )}
                {boost.ftds_to_next_tier === 0 && boost.next_tier_threshold === 0 && (
                  <div className="flex items-center gap-2 text-sm text-amber-400">
                    <ChevronUp className="w-4 h-4" />
                    Maximum tier reached!
                  </div>
                )}
                {!hasActiveBoost && boost.ftds_to_next_tier > 0 && (
                  <p className="text-sm text-gray-400 mt-2">
                    Refer {boost.ftds_to_next_tier} qualified traders to unlock your first boost (+20%)
                  </p>
                )}
              </div>
            </div>
          </div>

          {boost.all_tiers && boost.all_tiers.length > 0 && (
            <div className="bg-[#1a1d24] p-3 sm:p-4">
              <div className="flex sm:grid sm:grid-cols-5 gap-2 overflow-x-auto pb-1 sm:pb-0 snap-x snap-mandatory">
                {boost.all_tiers.map((tier) => {
                  const isCurrent = boost.boost_percentage === tier.boost_pct && (tier.boost_pct > 0 || boost.ftd_count <= 4);
                  const isAchieved = boost.ftd_count >= tier.min_ftds;
                  const tierColor = getBoostTierColor(tier.boost_pct);
                  return (
                    <div
                      key={tier.label}
                      className={`flex-shrink-0 w-[calc(33%-4px)] sm:w-auto snap-start p-2.5 sm:p-3 rounded-lg text-center transition-all ${
                        isCurrent
                          ? `${tierColor.bg} border-2 ${tierColor.border}`
                          : isAchieved
                            ? 'bg-[#0b0e11] border border-gray-700'
                            : 'bg-[#0b0e11] border border-gray-800 opacity-50'
                      }`}
                    >
                      <div className={`text-base sm:text-lg font-bold mb-0.5 ${
                        isCurrent ? tierColor.text : isAchieved ? 'text-white' : 'text-gray-500'
                      }`}>
                        {tier.boost_pct > 0 ? `+${tier.boost_pct}%` : '--'}
                      </div>
                      <div className="text-[10px] sm:text-xs text-gray-400">{tier.label}</div>
                      <div className="mt-1">
                        {isCurrent ? (
                          <span className={`text-[10px] sm:text-xs font-semibold ${tierColor.text}`}>CURRENT</span>
                        ) : isAchieved ? (
                          <CheckCircle className="w-3 h-3 sm:w-3.5 sm:h-3.5 text-green-400 mx-auto" />
                        ) : (
                          <Lock className="w-3 h-3 sm:w-3.5 sm:h-3.5 text-gray-600 mx-auto" />
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      ) : (
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gray-500/20 flex items-center justify-center">
              <Zap className="w-5 h-5 text-gray-500" />
            </div>
            <div>
              <h3 className="font-bold text-gray-400">Recruitment Boost</h3>
              <p className="text-sm text-gray-500">Boost not active for this account</p>
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
            <Gift className="w-5 h-5 text-green-400" />
            Deposit Commission Rates
            {hasActiveBoost && (
              <span className={`ml-2 px-2 py-0.5 text-xs font-semibold rounded-full ${boostColors.bg} ${boostColors.text}`}>
                +{boost.boost_percentage}% boost
              </span>
            )}
          </h3>
          <div className="space-y-2 max-h-[400px] overflow-y-auto">
            {activeLevels.map((level) => {
              const rate = depositRates[`level_${level}`] || 0;
              const count = network[`level_${level}_count`] || 0;
              const boostedRate = hasActiveBoost ? +(rate * boost.multiplier).toFixed(2) : rate;
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
                  {hasActiveBoost && rate > 0 ? (
                    <div className="text-right">
                      <div className={`text-xl font-bold ${boostColors.text}`}>{boostedRate}%</div>
                      <div className="text-xs text-gray-500 line-through">{rate}%</div>
                    </div>
                  ) : (
                    <div className="text-xl font-bold text-green-400">{rate}%</div>
                  )}
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
          {hasActiveBoost && (
            <p className="text-xs text-gray-500 -mt-2 mb-4">Fee revenue share is not affected by the recruitment boost</p>
          )}
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
            {hasActiveBoost && (
              <span className={`ml-2 px-2 py-0.5 text-xs font-semibold rounded-full ${boostColors.bg} ${boostColors.text}`}>
                +{boost.boost_percentage}% boost
              </span>
            )}
          </h3>
          <p className="text-sm text-gray-400 mb-4">
            Earn commission when your referred users make profits from copy trading.
          </p>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
            {activeLevels.map((level) => {
              const rate = copyProfitRates[`level_${level}`] || 0;
              const boostedRate = hasActiveBoost ? +(rate * boost.multiplier).toFixed(2) : rate;
              return (
                <div key={level} className="p-3 bg-[#0b0e11] rounded-lg text-center">
                  <div className="text-xs text-gray-400 mb-1">Level {level}</div>
                  {hasActiveBoost && rate > 0 ? (
                    <>
                      <div className={`text-xl font-bold ${boostColors.text}`}>{boostedRate}%</div>
                      <div className="text-xs text-gray-500 line-through">{rate}%</div>
                    </>
                  ) : (
                    <div className="text-xl font-bold text-cyan-400">{rate}%</div>
                  )}
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
              const wasBoosted = commission.boost_multiplier && commission.boost_multiplier > 1;
              return (
                <div key={commission.id} className="flex justify-between items-center p-3 bg-[#0b0e11] rounded-lg">
                  <div>
                    <div className="font-semibold text-sm flex items-center gap-2">
                      {getTypeLabel()} - Level {commission.tier_level}
                      {wasBoosted && (
                        <span className="px-1.5 py-0.5 text-[10px] font-semibold rounded bg-amber-500/20 text-amber-400 flex items-center gap-0.5">
                          <Zap className="w-2.5 h-2.5" />
                          x{commission.boost_multiplier}
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-gray-400">
                      {new Date(commission.created_at).toLocaleString()}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className={`font-bold ${getTypeColor()}`}>
                      +${commission.commission_amount.toFixed(2)}
                    </div>
                    {wasBoosted ? (
                      <div className="text-xs text-gray-500">
                        base ${commission.base_commission_amount?.toFixed(2)}
                      </div>
                    ) : (
                      <div className="text-xs text-gray-400">{commission.commission_rate}%</div>
                    )}
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
            stats.recent_commissions.map((commission: any) => {
              const typeLabel = commission.commission_type === 'deposit'
                ? 'Deposit Commission'
                : commission.commission_type === 'copy_profit'
                  ? 'Copy Trading Profit'
                  : 'Trading Fee Share';
              const typeColor = commission.commission_type === 'deposit'
                ? 'text-green-400'
                : commission.commission_type === 'copy_profit'
                  ? 'text-cyan-400'
                  : 'text-blue-400';
              const wasBoosted = commission.boost_multiplier && commission.boost_multiplier > 1;
              return (
                <div key={commission.id} className="flex justify-between items-center p-4 bg-[#0b0e11] rounded-lg">
                  <div>
                    <div className="font-semibold flex items-center gap-2">
                      {typeLabel}
                      {wasBoosted && (
                        <span className="px-1.5 py-0.5 text-[10px] font-semibold rounded bg-amber-500/20 text-amber-400 flex items-center gap-0.5">
                          <Zap className="w-2.5 h-2.5" />
                          {commission.boost_tier}
                        </span>
                      )}
                    </div>
                    <div className="text-sm text-gray-400">
                      Level {commission.tier_level} - {commission.commission_rate}% of ${commission.source_amount.toFixed(2)}
                      {wasBoosted && (
                        <span className="text-amber-400/70 ml-1">
                          (x{commission.boost_multiplier} boost)
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-gray-500">
                      {new Date(commission.created_at).toLocaleString()}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className={`text-xl font-bold ${typeColor}`}>
                      +${commission.commission_amount.toFixed(2)}
                    </div>
                    {wasBoosted && (
                      <div className="text-xs text-gray-500">
                        base ${commission.base_commission_amount?.toFixed(2)}
                      </div>
                    )}
                  </div>
                </div>
              );
            })
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
            <span className="text-green-400">Funds transferred to your main wallet successfully!</span>
          </div>
        )}

        {withdrawError && (
          <div className="mb-4 p-4 bg-red-500/20 border border-red-500/30 rounded-lg flex items-center gap-3">
            <AlertCircle className="w-5 h-5 text-red-400" />
            <span className="text-red-400">{withdrawError}</span>
          </div>
        )}

        <div className="space-y-4">
          <div className="bg-[#0b0e11] border border-gray-700 rounded-lg p-4 mb-4">
            <div className="flex items-center gap-3 text-blue-400">
              <Wallet className="w-5 h-5" />
              <div>
                <div className="font-semibold">Direct Transfer to Main Wallet</div>
                <div className="text-sm text-gray-400">Funds will be instantly transferred to your main trading wallet</div>
              </div>
            </div>
          </div>

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

          <button
            onClick={handleWithdraw}
            disabled={withdrawing || !withdrawAmount || parseFloat(withdrawAmount) > balance.available}
            className="w-full py-4 bg-[#fcd535] hover:bg-[#fcd535]/90 disabled:bg-gray-600 disabled:cursor-not-allowed text-black font-bold rounded-lg transition-all flex items-center justify-center gap-2"
          >
            {withdrawing ? (
              <>
                <RefreshCw className="w-5 h-5 animate-spin" />
                Processing...
              </>
            ) : (
              <>
                <Wallet className="w-5 h-5" />
                Transfer to Main Wallet
              </>
            )}
          </button>

          <p className="text-sm text-gray-400 text-center">
            Minimum withdrawal: $10 USDT. Transfers are instant and go directly to your main wallet.
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
                  <div className="text-sm text-gray-400 flex items-center gap-2">
                    <Wallet className="w-4 h-4" />
                    {w.wallet_address === 'Main Wallet Transfer' ? 'Main Wallet Transfer' : w.wallet_address}
                  </div>
                  {w.wallet_address !== 'Main Wallet Transfer' && (
                    <div className="text-xs text-gray-500">{w.network}</div>
                  )}
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

  const boostTiers = boost.all_tiers && boost.all_tiers.length > 0
    ? boost.all_tiers
    : [
        { min_ftds: 0, max_ftds: 4, multiplier: 1.0, label: 'Base', boost_pct: 0 },
        { min_ftds: 5, max_ftds: 10, multiplier: 1.2, label: 'Silver', boost_pct: 20 },
        { min_ftds: 11, max_ftds: 20, multiplier: 1.35, label: 'Gold', boost_pct: 35 },
        { min_ftds: 21, max_ftds: 50, multiplier: 1.5, label: 'Diamond', boost_pct: 50 },
        { min_ftds: 51, max_ftds: null, multiplier: 2.0, label: 'Elite', boost_pct: 100 },
      ];

  const renderBoostGuide = () => (
    <div className="space-y-6">
      <div className="bg-gradient-to-br from-amber-500/10 to-orange-600/10 rounded-2xl p-8 border border-amber-500/20">
        <div className="flex items-center gap-4 mb-4">
          <div className="w-14 h-14 rounded-2xl bg-amber-500/20 border border-amber-500/30 flex items-center justify-center">
            <Zap className="w-7 h-7 text-amber-400" />
          </div>
          <div>
            <h2 className="text-2xl font-bold text-white">Recruitment Boost</h2>
            <p className="text-gray-400">Earn more by referring active traders</p>
          </div>
        </div>
        <p className="text-gray-300 leading-relaxed">
          The Recruitment Boost rewards you for bringing in new traders who make their first deposit.
          The more qualified referrals you generate in a rolling 30-day window, the higher your
          commission multiplier climbs -- up to 2x on deposit and copy trading commissions.
        </p>
      </div>

      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-xl font-bold text-white mb-2">What counts as a qualifying FTD?</h3>
        <p className="text-gray-400 mb-5 text-sm">
          A qualifying First-Time Deposit (FTD) is counted when ALL of these conditions are met:
        </p>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="p-4 bg-[#0b0e11] rounded-xl border border-gray-800">
            <div className="w-10 h-10 rounded-lg bg-green-500/20 flex items-center justify-center mb-3">
              <Users className="w-5 h-5 text-green-400" />
            </div>
            <div className="font-semibold text-white mb-1">Direct Referral</div>
            <p className="text-sm text-gray-400">
              The user signed up using your referral link (Level 1 only).
            </p>
          </div>
          <div className="p-4 bg-[#0b0e11] rounded-xl border border-gray-800">
            <div className="w-10 h-10 rounded-lg bg-blue-500/20 flex items-center justify-center mb-3">
              <DollarSign className="w-5 h-5 text-blue-400" />
            </div>
            <div className="font-semibold text-white mb-1">$100+ First Deposit</div>
            <p className="text-sm text-gray-400">
              Their first deposit must be at least $100 USD equivalent.
            </p>
          </div>
          <div className="p-4 bg-[#0b0e11] rounded-xl border border-gray-800">
            <div className="w-10 h-10 rounded-lg bg-amber-500/20 flex items-center justify-center mb-3">
              <CheckCircle className="w-5 h-5 text-amber-400" />
            </div>
            <div className="font-semibold text-white mb-1">KYC Verified</div>
            <p className="text-sm text-gray-400">
              The referred user must have completed KYC verification.
            </p>
          </div>
        </div>
      </div>

      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-xl font-bold text-white mb-5">Boost Tiers</h3>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-700">
                <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">Tier</th>
                <th className="text-center py-3 px-4 text-sm font-semibold text-gray-400">FTDs Required</th>
                <th className="text-center py-3 px-4 text-sm font-semibold text-gray-400">Multiplier</th>
                <th className="text-center py-3 px-4 text-sm font-semibold text-gray-400">Boost</th>
                <th className="text-right py-3 px-4 text-sm font-semibold text-gray-400">Example (5% base)</th>
              </tr>
            </thead>
            <tbody>
              {boostTiers.map((tier) => {
                const isCurrent = boost.boost_percentage === tier.boost_pct && (tier.boost_pct > 0 || boost.ftd_count <= 4);
                const tierColor = getBoostTierColor(tier.boost_pct);
                const exampleRate = +(5 * tier.multiplier).toFixed(2);
                return (
                  <tr
                    key={tier.label}
                    className={`border-b border-gray-800 transition-colors ${
                      isCurrent ? `${tierColor.bg}` : 'hover:bg-[#0b0e11]/50'
                    }`}
                  >
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-2">
                        <span className={`font-bold ${isCurrent ? tierColor.text : 'text-white'}`}>
                          {tier.label}
                        </span>
                        {isCurrent && (
                          <span className={`px-2 py-0.5 text-[10px] font-bold rounded-full ${tierColor.bg} ${tierColor.text} border ${tierColor.border}`}>
                            YOU
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="py-4 px-4 text-center text-gray-300">
                      {tier.max_ftds ? `${tier.min_ftds} - ${tier.max_ftds}` : `${tier.min_ftds}+`}
                    </td>
                    <td className="py-4 px-4 text-center">
                      <span className={`font-bold ${tier.multiplier > 1 ? tierColor.text : 'text-gray-500'}`}>
                        x{tier.multiplier}
                      </span>
                    </td>
                    <td className="py-4 px-4 text-center">
                      <span className={`font-semibold ${tier.boost_pct > 0 ? tierColor.text : 'text-gray-500'}`}>
                        {tier.boost_pct > 0 ? `+${tier.boost_pct}%` : '--'}
                      </span>
                    </td>
                    <td className="py-4 px-4 text-right">
                      <span className={`font-bold ${tier.multiplier > 1 ? 'text-white' : 'text-gray-400'}`}>
                        {exampleRate}%
                      </span>
                      {tier.multiplier > 1 && (
                        <span className="text-gray-500 text-xs ml-1">
                          (was 5%)
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
            <Zap className="w-5 h-5 text-green-400" />
            What gets boosted
          </h3>
          <ul className="space-y-3">
            <li className="flex items-start gap-3">
              <CheckCircle className="w-5 h-5 text-green-400 mt-0.5 shrink-0" />
              <div>
                <div className="text-white font-medium">Deposit Commissions</div>
                <p className="text-sm text-gray-400">All levels of deposit commission earnings are multiplied</p>
              </div>
            </li>
            <li className="flex items-start gap-3">
              <CheckCircle className="w-5 h-5 text-green-400 mt-0.5 shrink-0" />
              <div>
                <div className="text-white font-medium">Copy Trading Profit Commissions</div>
                <p className="text-sm text-gray-400">Earnings from copy trading profits across all levels</p>
              </div>
            </li>
          </ul>
        </div>

        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
            <Info className="w-5 h-5 text-blue-400" />
            What is NOT boosted
          </h3>
          <ul className="space-y-3">
            <li className="flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-gray-500 mt-0.5 shrink-0" />
              <div>
                <div className="text-white font-medium">Trading Fee Revenue Share</div>
                <p className="text-sm text-gray-400">Fee revenue share rates remain at their configured base rates regardless of boost tier</p>
              </div>
            </li>
          </ul>
        </div>
      </div>

      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-lg font-bold text-white mb-4">How the rolling window works</h3>
        <div className="space-y-4">
          <div className="flex items-start gap-4 p-4 bg-[#0b0e11] rounded-xl">
            <div className="w-8 h-8 rounded-lg bg-amber-500/20 flex items-center justify-center shrink-0 mt-0.5">
              <span className="text-amber-400 font-bold text-sm">1</span>
            </div>
            <div>
              <div className="font-semibold text-white">30-Day Rolling Count</div>
              <p className="text-sm text-gray-400">
                Only FTDs from the past 30 days count toward your tier. If a referral deposited 31 days ago,
                they no longer count -- but any new FTDs immediately raise your count.
              </p>
            </div>
          </div>
          <div className="flex items-start gap-4 p-4 bg-[#0b0e11] rounded-xl">
            <div className="w-8 h-8 rounded-lg bg-amber-500/20 flex items-center justify-center shrink-0 mt-0.5">
              <span className="text-amber-400 font-bold text-sm">2</span>
            </div>
            <div>
              <div className="font-semibold text-white">Daily Tier Updates</div>
              <p className="text-sm text-gray-400">
                Your boost tier is recalculated daily. When your tier changes, you will receive a notification.
                Upgrades take effect on the next commission calculation.
              </p>
            </div>
          </div>
          <div className="flex items-start gap-4 p-4 bg-[#0b0e11] rounded-xl">
            <div className="w-8 h-8 rounded-lg bg-amber-500/20 flex items-center justify-center shrink-0 mt-0.5">
              <span className="text-amber-400 font-bold text-sm">3</span>
            </div>
            <div>
              <div className="font-semibold text-white">Boost Applied at Commission Time</div>
              <p className="text-sm text-gray-400">
                The multiplier is applied the moment a commission is calculated, not retroactively.
                Each commission entry records the exact multiplier that was used for full transparency.
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="bg-gradient-to-r from-amber-500/10 to-orange-600/10 rounded-xl p-6 border border-amber-500/20">
        <h3 className="text-lg font-bold text-white mb-3">Quick Example</h3>
        <div className="text-gray-300 text-sm leading-relaxed space-y-2">
          <p>
            Suppose your Level-1 deposit commission rate is <span className="text-white font-semibold">5%</span> and you bring in
            <span className="text-amber-400 font-semibold"> 12 qualifying FTDs</span> this month.
          </p>
          <p>
            That puts you in the <span className="text-amber-400 font-semibold">Gold tier (x1.35)</span>.
            When a Level-1 referral deposits $1,000, instead of earning $50 (5%), you earn:
          </p>
          <div className="bg-black/20 rounded-lg p-4 font-mono text-center">
            <span className="text-gray-400">$1,000</span>
            <span className="text-gray-500 mx-2">x</span>
            <span className="text-white">5%</span>
            <span className="text-gray-500 mx-2">x</span>
            <span className="text-amber-400">1.35</span>
            <span className="text-gray-500 mx-2">=</span>
            <span className="text-green-400 text-lg font-bold">$67.50</span>
            <span className="text-gray-500 text-xs ml-2">(+$17.50 bonus)</span>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="flex gap-2 overflow-x-auto pb-2">
        {[
          { id: 'overview', label: 'Overview', icon: TrendingUp },
          { id: 'earnings', label: 'Earnings', icon: DollarSign },
          { id: 'withdraw', label: 'Withdraw', icon: Wallet },
          { id: 'boost-guide', label: 'How Boost Works', icon: BookOpen }
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
      {activeTab === 'boost-guide' && renderBoostGuide()}
    </div>
  );
}

export default ExclusiveAffiliateDashboard;
