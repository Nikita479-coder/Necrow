import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import {
  Users,
  TrendingUp,
  DollarSign,
  Award,
  Calculator,
  Network,
  Copy,
  CheckCircle,
  ChevronDown,
  ChevronUp,
  Settings,
  Info,
  ArrowRight,
  Download,
  AlertCircle,
  RefreshCw,
  Zap,
  Target,
  Percent,
  ArrowLeft
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface AffiliateStats {
  user_id: string;
  vip_level: number;
  compensation_plan: string;
  total_network_size: number;
  tier_stats: {
    tier_1: { count: number; earnings: number };
    tier_2: { count: number; earnings: number };
    tier_3: { count: number; earnings: number };
    tier_4: { count: number; earnings: number };
    tier_5: { count: number; earnings: number };
  };
  lifetime_earnings: number;
  cpa_earnings: number;
  this_month_earnings: number;
  pending_payout: number;
  volume_30d: number;
  commission_rate: number;
  recent_commissions: any[];
}

interface NetworkMember {
  user_id: string;
  username: string;
  email_masked: string;
  tier_level: number;
  vip_level: number;
  joined_at: string;
  total_volume: number;
  commission_earned: number;
}

function AffiliateProgram() {
  const { user, profile, refreshProfile } = useAuth();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stats, setStats] = useState<AffiliateStats | null>(null);
  const [network, setNetwork] = useState<NetworkMember[]>([]);
  const [selectedTier, setSelectedTier] = useState<number | null>(null);
  const [copiedLink, setCopiedLink] = useState(false);
  const [activeTab, setActiveTab] = useState<'overview' | 'network' | 'earnings' | 'calculator' | 'settings' | 'terms' | 'cpa'>('overview');
  const [changingPlan, setChangingPlan] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState<string>('revshare');
  const [showPlanModal, setShowPlanModal] = useState(false);
  const [activeProgram, setActiveProgram] = useState<'referral' | 'affiliate'>('affiliate');
  const [switching, setSwitching] = useState(false);
  const [cpaProgress, setCpaProgress] = useState<any[]>([]);
  const [planAnalysis, setPlanAnalysis] = useState<any>(null);

  const [calculatorInputs, setCalculatorInputs] = useState({
    vipLevel: 1,
    tradeVolume: 10000,
    feeRate: 0.001
  });

  const vipLevels = [
    { level: 1, name: 'Beginner', commission: 10, rebate: 5, icon: '🥉' },
    { level: 2, name: 'Intermediate', commission: 20, rebate: 6, icon: '🥈' },
    { level: 3, name: 'Advanced', commission: 30, rebate: 7, icon: '🥇' },
    { level: 4, name: 'VIP 1', commission: 40, rebate: 8, icon: '💫' },
    { level: 5, name: 'VIP 2', commission: 50, rebate: 10, icon: '👑' },
    { level: 6, name: 'Diamond', commission: 70, rebate: 15, icon: '💎' }
  ];

  useEffect(() => {
    if (user && profile) {
      loadAffiliateData();
    }
  }, [user, profile]);

  const loadAffiliateData = async () => {
    if (!user || !profile) return;
    setLoading(true);
    setError(null);

    try {
      setActiveProgram(profile.active_program || 'affiliate');

      const { data: statsData, error: statsError } = await supabase.rpc('get_affiliate_program_stats', {
        p_user_id: user.id
      });

      if (statsError) {
        const { data: fallbackStats } = await supabase.rpc('get_affiliate_stats', {
          p_user_id: user.id
        });
        if (fallbackStats) {
          setStats(fallbackStats);
          if (fallbackStats?.compensation_plan) {
            setSelectedPlan(fallbackStats.compensation_plan);
          }
        }
      } else {
        setStats(statsData);
        if (statsData?.compensation_plan) {
          setSelectedPlan(statsData.compensation_plan);
        }
        if (statsData?.plan_analysis) {
          setPlanAnalysis(statsData.plan_analysis);
        }
      }

      const { data: networkData, error: networkError } = await supabase.rpc('get_affiliate_network', {
        p_user_id: user.id
      });

      if (networkError) throw networkError;
      setNetwork(networkData || []);

      const { data: cpaData } = await supabase.rpc('get_cpa_progress', {
        p_user_id: user.id
      });
      if (cpaData) {
        setCpaProgress(cpaData);
      }

    } catch (err: any) {
      console.error('Error loading affiliate data:', err);
      setError(err.message || 'Failed to load affiliate data');
    } finally {
      setLoading(false);
    }
  };

  const handleSwitchProgram = async (program: 'referral' | 'affiliate') => {
    if (!user || program === activeProgram) return;

    setActiveProgram(program);
    setSwitching(true);
    try {
      const { data, error } = await supabase.rpc('switch_active_program', {
        p_user_id: user.id,
        p_program: program
      });

      if (error) throw error;

      if (data?.success) {
        await refreshProfile();
        if (program === 'referral') {
          window.location.href = '/referral';
        }
      }
    } catch (error) {
      console.error('Error switching program:', error);
      setActiveProgram(activeProgram === 'referral' ? 'affiliate' : 'referral');
    } finally {
      setSwitching(false);
    }
  };

  const handleChangePlan = async (planType: string) => {
    if (!user) return;
    setChangingPlan(true);

    try {
      const { data, error } = await supabase.rpc('set_compensation_plan', {
        p_user_id: user.id,
        p_plan_type: planType
      });

      if (error) throw error;

      if (data?.success) {
        setSelectedPlan(planType);
        setStats(prev => prev ? { ...prev, compensation_plan: planType } : prev);
        setShowPlanModal(false);
      } else {
        throw new Error(data?.error || 'Failed to update plan');
      }
    } catch (err: any) {
      console.error('Error changing plan:', err);
      alert(err.message || 'Failed to change compensation plan');
    } finally {
      setChangingPlan(false);
    }
  };

  const copyAffiliateLink = () => {
    const link = `${window.location.origin}/signup?ref=${profile?.referral_code}`;
    navigator.clipboard.writeText(link);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  };

  const calculateEarnings = () => {
    const { vipLevel, tradeVolume, feeRate } = calculatorInputs;
    const currentVip = vipLevels.find(v => v.level === vipLevel);
    if (!currentVip) return [];

    const feeAmount = tradeVolume * feeRate;
    const tier1Commission = (feeAmount * currentVip.commission) / 100;

    const tierRates = [1.0, 0.20, 0.10, 0.05, 0.02];
    return tierRates.map((rate, index) => ({
      tier: index + 1,
      overrideRate: rate * 100,
      earnings: tier1Commission * rate
    }));
  };

  const filteredNetwork = selectedTier
    ? network.filter(m => m.tier_level === selectedTier)
    : network;

  const getStatValue = (value: number | undefined | null, decimals: number = 2): string => {
    if (value === undefined || value === null) return '0.00';
    return typeof value === 'number' ? value.toFixed(decimals) : '0.00';
  };

  const getTierData = (tierNum: number) => {
    const tierKey = `tier_${tierNum}` as keyof typeof stats.tier_stats;
    return stats?.tier_stats?.[tierKey] || { count: 0, earnings: 0 };
  };

  const compensationPlans = [
    {
      id: 'revshare',
      name: 'Revenue Share',
      description: 'Earn a percentage of trading fees from your network',
      icon: Percent,
      benefits: ['10-70% of fees based on VIP level', 'Lifetime earnings', 'All 5 tiers active']
    },
    {
      id: 'cpa',
      name: 'CPA Only',
      description: 'Earn fixed bonuses when referrals hit milestones',
      icon: Target,
      benefits: ['$10 on KYC verification', '$25 on first deposit', '$50 on first trade', '$100 on volume threshold']
    },
    {
      id: 'hybrid',
      name: 'Hybrid',
      description: 'Combination of CPA and reduced rev-share',
      icon: Zap,
      benefits: ['40% of rev-share rate', 'Full CPA bonuses', 'Best of both worlds']
    },
    {
      id: 'auto_optimize',
      name: 'Auto-Optimize',
      description: 'System automatically picks the best plan for you',
      icon: RefreshCw,
      benefits: ['AI-driven optimization', 'Maximizes your earnings', 'Monthly recalculation']
    }
  ];

  const renderOverview = () => {
    const currentVip = vipLevels.find(v => v.level === (stats?.vip_level || 1)) || vipLevels[0];
    const lifetimeEarnings = getStatValue(stats?.lifetime_earnings);
    const thisMonthEarnings = getStatValue(stats?.this_month_earnings);

    return (
      <div className="space-y-6">
        <div className="bg-gradient-to-br from-blue-600 to-cyan-600 rounded-2xl p-8 text-white">
          <div className="flex flex-col lg:flex-row justify-between items-start gap-6">
            <div>
              <h2 className="text-3xl font-bold mb-2">Affiliate Dashboard</h2>
              <p className="text-blue-100 mb-6">Your multi-tier affiliate performance</p>
              <div className="flex items-center gap-4 mb-6">
                <div className="text-5xl">{currentVip.icon}</div>
                <div>
                  <div className="text-sm text-blue-100">Current Status</div>
                  <div className="text-2xl font-bold">{currentVip.name}</div>
                  <div className="text-sm text-blue-100">
                    {currentVip.commission}% Commission · {currentVip.rebate}% Rebate
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2 text-sm">
                <span className="text-blue-100">Compensation Plan:</span>
                <span className="px-3 py-1 bg-white/20 rounded-full font-semibold capitalize">
                  {stats?.compensation_plan || 'Revenue Share'}
                </span>
                <button
                  onClick={() => setActiveTab('settings')}
                  className="ml-2 px-3 py-1 bg-white/10 hover:bg-white/20 rounded-full text-sm transition-all"
                >
                  Change
                </button>
              </div>
            </div>
            <div className="text-right">
              <div className="text-sm text-blue-100 mb-1">Lifetime Earnings</div>
              <div className="text-4xl font-bold">${lifetimeEarnings}</div>
              <div className="text-sm text-blue-100 mt-2">
                This Month: ${thisMonthEarnings}
              </div>
            </div>
          </div>

          <div className="mt-6 p-4 bg-white/10 rounded-xl backdrop-blur-sm">
            <div className="flex items-center justify-between mb-2">
              <div className="text-sm text-blue-100">Your Affiliate Link</div>
              <button
                onClick={copyAffiliateLink}
                className="px-4 py-2 bg-white/20 hover:bg-white/30 rounded-lg transition-all flex items-center gap-2"
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
            <div className="text-sm font-mono break-all bg-black/20 p-3 rounded-lg">
              {window.location.origin}/signup?ref={profile?.referral_code}
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <Network className="w-8 h-8 text-blue-400" />
            </div>
            <div className="text-3xl font-bold mb-1">{stats?.total_network_size || 0}</div>
            <div className="text-sm text-gray-400">Total Network Size</div>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <TrendingUp className="w-8 h-8 text-green-400" />
            </div>
            <div className="text-3xl font-bold mb-1">${thisMonthEarnings}</div>
            <div className="text-sm text-gray-400">This Month</div>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <DollarSign className="w-8 h-8 text-yellow-400" />
            </div>
            <div className="text-3xl font-bold mb-1">${getStatValue(stats?.cpa_earnings)}</div>
            <div className="text-sm text-gray-400">CPA Bonuses</div>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-3">
              <Award className="w-8 h-8 text-cyan-400" />
            </div>
            <div className="text-3xl font-bold mb-1">{stats?.commission_rate || 10}%</div>
            <div className="text-sm text-gray-400">Commission Rate</div>
          </div>
        </div>

        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-xl font-bold mb-6">5-Tier Breakdown</h3>
          <div className="space-y-4">
            {[1, 2, 3, 4, 5].map((tier) => {
              const tierData = getTierData(tier);
              const overrideRates = [100, 20, 10, 5, 2];

              return (
                <div key={tier} className="flex items-center justify-between p-4 bg-[#0b0e11] rounded-lg hover:bg-[#0b0e11]/80 transition-all">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-full bg-blue-500/20 flex items-center justify-center text-blue-400 font-bold">
                      T{tier}
                    </div>
                    <div>
                      <div className="font-semibold">Tier {tier}</div>
                      <div className="text-sm text-gray-400">{overrideRates[tier - 1]}% override rate</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-bold">{tierData.count} members</div>
                    <div className="text-sm text-green-400">${getStatValue(tierData.earnings)} earned</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {stats?.recent_commissions && stats.recent_commissions.length > 0 && (
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold">Recent Activity</h3>
              <button
                onClick={() => setActiveTab('earnings')}
                className="text-blue-400 hover:text-blue-300 text-sm flex items-center gap-1"
              >
                View All <ArrowRight className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              {stats.recent_commissions.slice(0, 5).map((commission: any, index: number) => (
                <div key={commission.id || index} className="flex justify-between items-center p-3 bg-[#0b0e11] rounded-lg">
                  <div>
                    <div className="font-semibold text-sm">Tier {commission.tier_level} Commission</div>
                    <div className="text-xs text-gray-400">
                      {new Date(commission.created_at).toLocaleString()}
                    </div>
                  </div>
                  <div className="text-green-400 font-bold">
                    +${getStatValue(commission.commission_amount)}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    );
  };

  const renderNetwork = () => (
    <div className="space-y-6">
      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-xl font-bold">Affiliate Network</h3>
          <div className="flex gap-2">
            <button
              onClick={() => setSelectedTier(null)}
              className={`px-4 py-2 rounded-lg transition-all ${
                selectedTier === null
                  ? 'bg-blue-500 text-white'
                  : 'bg-[#0b0e11] text-gray-400 hover:text-white'
              }`}
            >
              All Tiers
            </button>
            {[1, 2, 3, 4, 5].map((tier) => (
              <button
                key={tier}
                onClick={() => setSelectedTier(tier)}
                className={`px-4 py-2 rounded-lg transition-all ${
                  selectedTier === tier
                    ? 'bg-blue-500 text-white'
                    : 'bg-[#0b0e11] text-gray-400 hover:text-white'
                }`}
              >
                T{tier}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-800">
                <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">User</th>
                <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">Tier</th>
                <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">VIP Level</th>
                <th className="text-right py-3 px-4 text-sm font-semibold text-gray-400">Volume</th>
                <th className="text-right py-3 px-4 text-sm font-semibold text-gray-400">Earnings</th>
                <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">Joined</th>
              </tr>
            </thead>
            <tbody>
              {filteredNetwork.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-8 text-gray-400">
                    <Users className="w-12 h-12 mx-auto mb-2 opacity-50" />
                    <div>No network members yet</div>
                    <div className="text-sm">Share your affiliate link to start building your network</div>
                  </td>
                </tr>
              ) : (
                filteredNetwork.map((member) => (
                  <tr key={member.user_id} className="border-b border-gray-800 hover:bg-[#0b0e11]/50">
                    <td className="py-3 px-4">
                      <div className="font-semibold">{member.username}</div>
                      <div className="text-sm text-gray-400">{member.email_masked}</div>
                    </td>
                    <td className="py-3 px-4">
                      <span className="px-2 py-1 bg-blue-500/20 text-blue-400 rounded text-sm font-semibold">
                        Tier {member.tier_level}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      {vipLevels.find(v => v.level === member.vip_level)?.icon}{' '}
                      {vipLevels.find(v => v.level === member.vip_level)?.name}
                    </td>
                    <td className="py-3 px-4 text-right font-mono">
                      ${member.total_volume.toFixed(2)}
                    </td>
                    <td className="py-3 px-4 text-right font-mono text-green-400">
                      ${member.commission_earned.toFixed(2)}
                    </td>
                    <td className="py-3 px-4 text-sm text-gray-400">
                      {new Date(member.joined_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );

  const renderEarnings = () => (
    <div className="space-y-6">
      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-xl font-bold mb-6">Recent Commissions</h3>
        <div className="space-y-3">
          {stats?.recent_commissions && stats.recent_commissions.length > 0 ? (
            stats.recent_commissions.map((commission: any) => (
              <div key={commission.id} className="flex justify-between items-center p-4 bg-[#0b0e11] rounded-lg">
                <div>
                  <div className="font-semibold">Tier {commission.tier_level} Commission</div>
                  <div className="text-sm text-gray-400">
                    {new Date(commission.created_at).toLocaleString()}
                  </div>
                  <div className="text-sm text-gray-400">
                    Trade Volume: ${commission.trade_amount.toFixed(2)}
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-xl font-bold text-green-400">
                    +${commission.commission_amount.toFixed(2)}
                  </div>
                </div>
              </div>
            ))
          ) : (
            <div className="text-center py-12 text-gray-400">
              <DollarSign className="w-12 h-12 mx-auto mb-2 opacity-50" />
              <div>No commissions yet</div>
              <div className="text-sm">Commissions will appear here when your referrals trade</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );

  const renderCalculator = () => {
    const earnings = calculateEarnings();

    return (
      <div className="space-y-6">
        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <h3 className="text-xl font-bold mb-6 flex items-center gap-2">
            <Calculator className="w-6 h-6" />
            Commission Calculator
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div>
              <label className="block text-sm font-semibold mb-2">VIP Level</label>
              <select
                value={calculatorInputs.vipLevel}
                onChange={(e) => setCalculatorInputs({ ...calculatorInputs, vipLevel: parseInt(e.target.value) })}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 focus:outline-none focus:border-blue-500"
              >
                {vipLevels.map((vip) => (
                  <option key={vip.level} value={vip.level}>
                    {vip.icon} {vip.name} ({vip.commission}%)
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-semibold mb-2">Trade Volume ($)</label>
              <input
                type="number"
                value={calculatorInputs.tradeVolume}
                onChange={(e) => setCalculatorInputs({ ...calculatorInputs, tradeVolume: parseFloat(e.target.value) || 0 })}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 focus:outline-none focus:border-blue-500"
                placeholder="10000"
              />
            </div>

            <div>
              <label className="block text-sm font-semibold mb-2">Fee Rate (%)</label>
              <input
                type="number"
                step="0.001"
                value={calculatorInputs.feeRate * 100}
                onChange={(e) => setCalculatorInputs({ ...calculatorInputs, feeRate: parseFloat(e.target.value) / 100 || 0.001 })}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 focus:outline-none focus:border-blue-500"
                placeholder="0.1"
              />
            </div>
          </div>

          <div className="bg-gradient-to-br from-blue-500/10 to-purple-500/10 border border-blue-500/20 rounded-xl p-6">
            <h4 className="text-lg font-bold mb-4">Estimated Earnings by Tier</h4>
            <div className="space-y-3">
              {earnings.map((tier) => (
                <div key={tier.tier} className="flex justify-between items-center p-4 bg-[#0b0e11] rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-blue-500/20 flex items-center justify-center text-blue-400 font-bold">
                      T{tier.tier}
                    </div>
                    <div>
                      <div className="font-semibold">Tier {tier.tier}</div>
                      <div className="text-sm text-gray-400">{tier.overrideRate}% override</div>
                    </div>
                  </div>
                  <div className="text-2xl font-bold text-green-400">
                    ${tier.earnings.toFixed(2)}
                  </div>
                </div>
              ))}
              <div className="mt-4 pt-4 border-t border-gray-800">
                <div className="flex justify-between items-center">
                  <div className="text-lg font-semibold">Total Per Referral</div>
                  <div className="text-3xl font-bold text-green-400">
                    ${earnings.reduce((sum, tier) => sum + tier.earnings, 0).toFixed(2)}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const renderSettings = () => (
    <div className="space-y-6">
      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-xl font-bold mb-2">Compensation Plan</h3>
        <p className="text-gray-400 mb-6">Choose how you want to earn from your affiliate network</p>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {compensationPlans.map((plan) => {
            const isSelected = (stats?.compensation_plan || 'revshare') === plan.id;
            const IconComponent = plan.icon;

            return (
              <div
                key={plan.id}
                className={`relative p-6 rounded-xl border-2 transition-all cursor-pointer ${
                  isSelected
                    ? 'border-blue-500 bg-blue-500/10'
                    : 'border-gray-700 bg-[#0b0e11] hover:border-gray-600'
                }`}
                onClick={() => !changingPlan && handleChangePlan(plan.id)}
              >
                {isSelected && (
                  <div className="absolute top-3 right-3">
                    <CheckCircle className="w-6 h-6 text-blue-500" />
                  </div>
                )}

                <div className="flex items-center gap-3 mb-3">
                  <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                    isSelected ? 'bg-blue-500' : 'bg-gray-700'
                  }`}>
                    <IconComponent className="w-6 h-6 text-white" />
                  </div>
                  <div>
                    <div className="font-bold text-lg">{plan.name}</div>
                    <div className="text-sm text-gray-400">{plan.description}</div>
                  </div>
                </div>

                <ul className="space-y-2 mt-4">
                  {plan.benefits.map((benefit, index) => (
                    <li key={index} className="flex items-center gap-2 text-sm text-gray-300">
                      <CheckCircle className="w-4 h-4 text-green-400 flex-shrink-0" />
                      {benefit}
                    </li>
                  ))}
                </ul>

                {changingPlan && (
                  <div className="absolute inset-0 bg-black/50 rounded-xl flex items-center justify-center">
                    <RefreshCw className="w-6 h-6 text-white animate-spin" />
                  </div>
                )}
              </div>
            );
          })}
        </div>

        <div className="mt-6 p-4 bg-blue-500/10 border border-blue-500/30 rounded-lg">
          <div className="flex items-start gap-3">
            <Info className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
            <div className="text-sm text-gray-300">
              <strong className="text-blue-400">Note:</strong> Changing your compensation plan takes effect immediately.
              Your existing earnings are not affected. We recommend "Auto-Optimize" for most affiliates to maximize earnings.
            </div>
          </div>
        </div>
      </div>

      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-xl font-bold mb-4">Current Statistics</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="p-4 bg-[#0b0e11] rounded-lg">
            <div className="text-sm text-gray-400 mb-1">VIP Level</div>
            <div className="text-2xl font-bold">
              {vipLevels.find(v => v.level === (stats?.vip_level || 1))?.icon}{' '}
              {vipLevels.find(v => v.level === (stats?.vip_level || 1))?.name}
            </div>
          </div>
          <div className="p-4 bg-[#0b0e11] rounded-lg">
            <div className="text-sm text-gray-400 mb-1">Commission Rate</div>
            <div className="text-2xl font-bold text-green-400">{stats?.commission_rate || 10}%</div>
          </div>
          <div className="p-4 bg-[#0b0e11] rounded-lg">
            <div className="text-sm text-gray-400 mb-1">Network Size</div>
            <div className="text-2xl font-bold">{stats?.total_network_size || 0}</div>
          </div>
          <div className="p-4 bg-[#0b0e11] rounded-lg">
            <div className="text-sm text-gray-400 mb-1">30-Day Volume</div>
            <div className="text-2xl font-bold">${getStatValue(stats?.volume_30d, 0)}</div>
          </div>
        </div>
      </div>

      <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
        <h3 className="text-xl font-bold mb-4">Plan Comparison</h3>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-700">
                <th className="text-left py-3 px-4">Feature</th>
                <th className="text-center py-3 px-4">Rev-Share</th>
                <th className="text-center py-3 px-4">CPA</th>
                <th className="text-center py-3 px-4">Hybrid</th>
                <th className="text-center py-3 px-4">Auto</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b border-gray-800">
                <td className="py-3 px-4">Trading Fee Commission</td>
                <td className="text-center py-3 px-4 text-green-400">10-70%</td>
                <td className="text-center py-3 px-4 text-gray-500">-</td>
                <td className="text-center py-3 px-4 text-yellow-400">4-28%</td>
                <td className="text-center py-3 px-4 text-blue-400">Optimized</td>
              </tr>
              <tr className="border-b border-gray-800">
                <td className="py-3 px-4">KYC Bonus</td>
                <td className="text-center py-3 px-4 text-gray-500">-</td>
                <td className="text-center py-3 px-4 text-green-400">$10</td>
                <td className="text-center py-3 px-4 text-green-400">$10</td>
                <td className="text-center py-3 px-4 text-blue-400">Optimized</td>
              </tr>
              <tr className="border-b border-gray-800">
                <td className="py-3 px-4">First Deposit Bonus</td>
                <td className="text-center py-3 px-4 text-gray-500">-</td>
                <td className="text-center py-3 px-4 text-green-400">$25</td>
                <td className="text-center py-3 px-4 text-green-400">$25</td>
                <td className="text-center py-3 px-4 text-blue-400">Optimized</td>
              </tr>
              <tr className="border-b border-gray-800">
                <td className="py-3 px-4">First Trade Bonus</td>
                <td className="text-center py-3 px-4 text-gray-500">-</td>
                <td className="text-center py-3 px-4 text-green-400">$50</td>
                <td className="text-center py-3 px-4 text-green-400">$50</td>
                <td className="text-center py-3 px-4 text-blue-400">Optimized</td>
              </tr>
              <tr className="border-b border-gray-800">
                <td className="py-3 px-4">Volume Threshold Bonus</td>
                <td className="text-center py-3 px-4 text-gray-500">-</td>
                <td className="text-center py-3 px-4 text-green-400">$100</td>
                <td className="text-center py-3 px-4 text-green-400">$100</td>
                <td className="text-center py-3 px-4 text-blue-400">Optimized</td>
              </tr>
              <tr>
                <td className="py-3 px-4">5-Tier Override</td>
                <td className="text-center py-3 px-4 text-green-400">Full</td>
                <td className="text-center py-3 px-4 text-gray-500">-</td>
                <td className="text-center py-3 px-4 text-yellow-400">40%</td>
                <td className="text-center py-3 px-4 text-blue-400">Optimized</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );

  const renderCpaProgress = () => {
    const cpaMilestones = [
      { key: 'kyc_completed', label: 'KYC Verified', amount: 10, icon: '✓' },
      { key: 'first_deposit', label: 'First Deposit', amount: 25, icon: '$' },
      { key: 'first_trade', label: 'First Trade', amount: 50, icon: '↗' },
      { key: 'volume_threshold', label: 'Volume $10K', amount: 100, icon: '★' }
    ];

    const totalPotential = cpaProgress.reduce((sum, ref) => sum + (ref.potential_remaining || 0), 0);
    const totalEarned = cpaProgress.reduce((sum, ref) => sum + (ref.total_earned || 0), 0);

    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="text-sm text-gray-400 mb-2">CPA Earnings</div>
            <div className="text-3xl font-bold text-green-400">${getStatValue(stats?.cpa_earnings)}</div>
            <div className="text-sm text-gray-500 mt-1">From milestone bonuses</div>
          </div>
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="text-sm text-gray-400 mb-2">Potential Remaining</div>
            <div className="text-3xl font-bold text-yellow-400">${totalPotential.toFixed(0)}</div>
            <div className="text-sm text-gray-500 mt-1">If all referrals complete milestones</div>
          </div>
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="text-sm text-gray-400 mb-2">Referrals Tracked</div>
            <div className="text-3xl font-bold text-blue-400">{cpaProgress.length}</div>
            <div className="text-sm text-gray-500 mt-1">With CPA milestone tracking</div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-yellow-500/10 to-orange-500/10 border border-yellow-500/20 rounded-xl p-6">
          <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
            <Target className="w-5 h-5 text-yellow-400" />
            CPA Milestone Bonuses
          </h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {cpaMilestones.map((milestone) => (
              <div key={milestone.key} className="bg-[#0b0e11] rounded-lg p-4 text-center">
                <div className="text-3xl mb-2">{milestone.icon}</div>
                <div className="font-bold text-lg text-green-400">${milestone.amount}</div>
                <div className="text-sm text-gray-400">{milestone.label}</div>
              </div>
            ))}
          </div>
          <div className="mt-4 text-sm text-gray-400 text-center">
            Max potential per referral: <span className="text-white font-bold">$185</span> (if all milestones completed)
          </div>
        </div>

        {(selectedPlan === 'cpa' || selectedPlan === 'hybrid') ? (
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <h3 className="text-xl font-bold mb-4">Referral CPA Progress</h3>
            {cpaProgress.length === 0 ? (
              <div className="text-center py-12 text-gray-400">
                <Target className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <div>No referrals yet</div>
                <div className="text-sm">Share your link to start tracking CPA milestones</div>
              </div>
            ) : (
              <div className="space-y-3">
                {cpaProgress.map((ref: any) => (
                  <div key={ref.referred_user_id} className="bg-[#0b0e11] rounded-lg p-4">
                    <div className="flex items-center justify-between mb-3">
                      <div>
                        <div className="font-semibold">{ref.username}</div>
                        <div className="text-sm text-gray-400">
                          Joined {new Date(ref.joined_at).toLocaleDateString()}
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="text-green-400 font-bold">${ref.total_earned || 0} earned</div>
                        <div className="text-sm text-yellow-400">${ref.potential_remaining || 0} remaining</div>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      {cpaMilestones.map((milestone) => {
                        const isCompleted = ref[milestone.key];
                        return (
                          <div
                            key={milestone.key}
                            className={`flex-1 p-2 rounded text-center text-xs ${
                              isCompleted
                                ? 'bg-green-500/20 text-green-400 border border-green-500/30'
                                : 'bg-gray-800 text-gray-500'
                            }`}
                          >
                            <div className="font-bold">{isCompleted ? '✓' : '-'}</div>
                            <div>{milestone.label}</div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-6">
            <div className="flex items-start gap-3">
              <AlertCircle className="w-6 h-6 text-yellow-400 flex-shrink-0" />
              <div>
                <div className="font-bold text-yellow-400 mb-2">CPA Not Active</div>
                <p className="text-sm text-gray-300 mb-3">
                  You're currently on the {selectedPlan === 'revshare' ? 'Revenue Share' : 'Auto-Optimize'} plan.
                  To earn CPA bonuses when your referrals complete milestones, switch to CPA or Hybrid plan.
                </p>
                <button
                  onClick={() => setActiveTab('settings')}
                  className="px-4 py-2 bg-yellow-500 hover:bg-yellow-600 text-black font-medium rounded-lg transition-all"
                >
                  Change Compensation Plan
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  };

  const renderTerms = () => (
    <div className="space-y-6">
      <div className="bg-[#1a1d24] rounded-xl p-8 border border-gray-800">
        <h3 className="text-2xl font-bold mb-6">Affiliate Program Guide & Terms</h3>

        <div className="space-y-6">
          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">What is the Affiliate Program?</h4>
            <p className="text-gray-300 leading-relaxed mb-4">
              The Shark Trades Affiliate Program is a multi-tier commission system that rewards you for referring
              traders and building a network of sub-affiliates. Unlike traditional referral programs, our affiliate
              system provides passive income from up to 5 levels deep in your network, creating exponential earning potential.
            </p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="bg-[#0b0e11] rounded-lg p-4 border border-gray-700">
                <div className="flex items-start gap-3">
                  <Users className="w-6 h-6 text-blue-400 flex-shrink-0 mt-1" />
                  <div>
                    <h5 className="font-bold mb-2">Multi-Tier Network</h5>
                    <p className="text-sm text-gray-400">
                      Earn commissions not only from your direct referrals, but also from traders referred by your
                      referrals, up to 5 levels deep. Build a network that generates passive income continuously.
                    </p>
                  </div>
                </div>
              </div>
              <div className="bg-[#0b0e11] rounded-lg p-4 border border-gray-700">
                <div className="flex items-start gap-3">
                  <Award className="w-6 h-6 text-green-400 flex-shrink-0 mt-1" />
                  <div>
                    <h5 className="font-bold mb-2">VIP Progression</h5>
                    <p className="text-sm text-gray-400">
                      As your network grows and generates more volume, you automatically advance through VIP levels,
                      unlocking higher commission rates and additional benefits.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">How It Works</h4>
            <p className="text-gray-300 leading-relaxed mb-4">
              The affiliate system is designed to be simple yet powerful:
            </p>
            <div className="space-y-3">
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-bold">Step 1: Share Your Link</div>
                  <div className="text-sm text-gray-400 flex items-center gap-2">
                    <Copy className="w-4 h-4" />
                    One-Time Setup
                  </div>
                </div>
                <p className="text-sm text-gray-400">
                  Copy your unique referral link from your dashboard and share it with traders, on social media,
                  or through your content channels. Each user who signs up through your link becomes your Tier 1 referral.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-bold">Step 2: Earn From Trading Activity</div>
                  <div className="text-sm text-gray-400">Automatic</div>
                </div>
                <p className="text-sm text-gray-400">
                  When your referrals trade (spot, futures, or swaps), you automatically earn a percentage of the
                  trading fees they generate. The commission is calculated in real-time and credited to your account.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-bold">Step 3: Build Your Network</div>
                  <div className="text-sm text-gray-400">Exponential Growth</div>
                </div>
                <p className="text-sm text-gray-400">
                  When your referrals share their own links and recruit sub-affiliates, those become your Tier 2, 3, 4,
                  and 5 referrals. You earn override commissions on all trading activity in your network.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-bold">Step 4: Withdraw Earnings</div>
                  <div className="text-sm text-gray-400">Weekly Payouts</div>
                </div>
                <p className="text-sm text-gray-400">
                  Your commissions accumulate in real-time. Withdraw your earnings weekly in USDT, USDC, BTC, or ETH
                  with a minimum threshold of just $10. No waiting, no complications.
                </p>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">Program Overview</h4>
            <p className="text-gray-300 leading-relaxed">
              The Affiliate Program enables you to earn lifetime commissions for referring users and sub-affiliates
              who engage in trading activity. This is a comprehensive 5-tier system with VIP-based rewards.
            </p>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">VIP Levels & Commission Rates</h4>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="text-left py-3 px-4">Level</th>
                    <th className="text-left py-3 px-4">Tier-1 Commission</th>
                    <th className="text-left py-3 px-4">Rebate</th>
                    <th className="text-left py-3 px-4">Description</th>
                  </tr>
                </thead>
                <tbody>
                  {vipLevels.map((vip) => (
                    <tr key={vip.level} className="border-b border-gray-800">
                      <td className="py-3 px-4">
                        <span className="text-2xl mr-2">{vip.icon}</span>
                        {vip.name}
                      </td>
                      <td className="py-3 px-4 font-bold text-green-400">{vip.commission}%</td>
                      <td className="py-3 px-4 font-bold text-blue-400">{vip.rebate}%</td>
                      <td className="py-3 px-4 text-gray-400 text-sm">
                        {vip.level === 1 && 'Entry level — automatically granted'}
                        {vip.level === 2 && 'Moderate performers'}
                        {vip.level === 3 && 'Consistent affiliates'}
                        {vip.level === 4 && 'Increased reward tier'}
                        {vip.level === 5 && 'High-performance tier'}
                        {vip.level === 6 && 'Maximum commissions, VIP support'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">5-Tier Commission Structure</h4>
            <p className="text-gray-300 mb-4">
              Earn override commissions from sub-affiliates up to 5 tiers deep:
            </p>
            <div className="space-y-3">
              <div className="p-4 bg-[#0b0e11] rounded-lg">
                <div className="flex justify-between items-center">
                  <div>
                    <div className="font-bold">Tier 1 - Direct Referrals</div>
                    <div className="text-sm text-gray-400">Users who sign up with your link</div>
                  </div>
                  <div className="text-2xl font-bold text-green-400">10-70%</div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg">
                <div className="flex justify-between items-center">
                  <div>
                    <div className="font-bold">Tier 2 - Sub-Affiliates</div>
                    <div className="text-sm text-gray-400">Affiliates referred by your Tier 1</div>
                  </div>
                  <div className="text-2xl font-bold text-green-400">20%</div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg">
                <div className="flex justify-between items-center">
                  <div>
                    <div className="font-bold">Tier 3</div>
                    <div className="text-sm text-gray-400">Sub-affiliates of Tier 2</div>
                  </div>
                  <div className="text-2xl font-bold text-green-400">10%</div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg">
                <div className="flex justify-between items-center">
                  <div>
                    <div className="font-bold">Tier 4</div>
                    <div className="text-sm text-gray-400">Sub-affiliates of Tier 3</div>
                  </div>
                  <div className="text-2xl font-bold text-green-400">5%</div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg">
                <div className="flex justify-between items-center">
                  <div>
                    <div className="font-bold">Tier 5</div>
                    <div className="text-sm text-gray-400">Sub-affiliates of Tier 4</div>
                  </div>
                  <div className="text-2xl font-bold text-green-400">2%</div>
                </div>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">Payment Terms</h4>
            <ul className="space-y-2 text-gray-300">
              <li className="flex items-start gap-2">
                <CheckCircle className="w-5 h-5 text-green-400 mt-0.5 flex-shrink-0" />
                <span>Commissions calculated in real-time and paid weekly</span>
              </li>
              <li className="flex items-start gap-2">
                <CheckCircle className="w-5 h-5 text-green-400 mt-0.5 flex-shrink-0" />
                <span>Payout assets: USDT, USDC, BTC, ETH</span>
              </li>
              <li className="flex items-start gap-2">
                <CheckCircle className="w-5 h-5 text-green-400 mt-0.5 flex-shrink-0" />
                <span>Minimum withdrawal threshold: $10 equivalent</span>
              </li>
              <li className="flex items-start gap-2">
                <CheckCircle className="w-5 h-5 text-green-400 mt-0.5 flex-shrink-0" />
                <span>Lifetime commissions on all referred users</span>
              </li>
            </ul>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">Understanding Commission Calculations</h4>
            <p className="text-gray-300 leading-relaxed mb-4">
              Commissions are calculated based on the trading fees generated by your network:
            </p>
            <div className="bg-gradient-to-br from-blue-500/10 to-purple-500/10 border border-blue-500/20 rounded-xl p-6">
              <div className="space-y-4">
                <div>
                  <h5 className="font-bold mb-2">Example Calculation</h5>
                  <div className="text-sm text-gray-300 space-y-2">
                    <div className="flex justify-between items-center p-3 bg-[#0b0e11] rounded-lg">
                      <span>Your Tier 1 referral trades:</span>
                      <span className="font-mono text-green-400">$10,000</span>
                    </div>
                    <div className="flex justify-between items-center p-3 bg-[#0b0e11] rounded-lg">
                      <span>Trading fee (0.1%):</span>
                      <span className="font-mono text-green-400">$10</span>
                    </div>
                    <div className="flex justify-between items-center p-3 bg-[#0b0e11] rounded-lg">
                      <span>Your commission (40% at VIP 4):</span>
                      <span className="font-mono text-green-400 text-lg font-bold">$4.00</span>
                    </div>
                  </div>
                </div>
                <div className="border-t border-gray-700 pt-4">
                  <h5 className="font-bold mb-2">Multi-Tier Example</h5>
                  <p className="text-sm text-gray-400 mb-3">
                    If your Tier 1 referral also becomes an affiliate and recruits their own users:
                  </p>
                  <div className="text-sm text-gray-300 space-y-2">
                    <div className="flex justify-between items-center p-3 bg-[#0b0e11] rounded-lg">
                      <span>Tier 1 earns $4 from their Tier 1</span>
                      <span className="font-mono text-blue-400">$4.00</span>
                    </div>
                    <div className="flex justify-between items-center p-3 bg-[#0b0e11] rounded-lg">
                      <span>You earn 20% override (Tier 2):</span>
                      <span className="font-mono text-green-400 font-bold">$0.80</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">Best Practices for Success</h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <div className="flex items-start gap-3">
                  <TrendingUp className="w-5 h-5 text-green-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="font-bold mb-1">Target Active Traders</div>
                    <p className="text-sm text-gray-400">
                      Focus on referring users who actively trade. One active trader is worth more than 100 inactive signups.
                      Quality over quantity is key to sustainable income.
                    </p>
                  </div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <div className="flex items-start gap-3">
                  <Users className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="font-bold mb-1">Build a Community</div>
                    <p className="text-sm text-gray-400">
                      Create value through content, education, or trading signals. A loyal community generates
                      consistent volume and attracts sub-affiliates.
                    </p>
                  </div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <div className="flex items-start gap-3">
                  <Network className="w-5 h-5 text-purple-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="font-bold mb-1">Recruit Sub-Affiliates</div>
                    <p className="text-sm text-gray-400">
                      The real power is in building depth. Identify promising affiliates in your Tier 1 and help
                      them succeed. Their growth multiplies your earnings.
                    </p>
                  </div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <div className="flex items-start gap-3">
                  <DollarSign className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="font-bold mb-1">Leverage Multiple Channels</div>
                    <p className="text-sm text-gray-400">
                      Share your link on social media, blogs, YouTube, Discord, Telegram, and trading communities.
                      Diversify your traffic sources for consistent growth.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-blue-400">Frequently Asked Questions</h4>
            <div className="space-y-3">
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <h5 className="font-bold mb-2 flex items-center gap-2">
                  <Info className="w-5 h-5 text-blue-400" />
                  How long do commissions last?
                </h5>
                <p className="text-sm text-gray-400">
                  Commissions are lifetime. Once someone signs up with your link, you earn from their trading activity
                  forever, as long as they remain active on the platform.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <h5 className="font-bold mb-2 flex items-center gap-2">
                  <Info className="w-5 h-5 text-blue-400" />
                  Can I upgrade my VIP level?
                </h5>
                <p className="text-sm text-gray-400">
                  Yes, VIP levels are automatically upgraded based on your network's 30-day trading volume and other
                  performance metrics. There's no application needed - the system tracks and upgrades you automatically.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <h5 className="font-bold mb-2 flex items-center gap-2">
                  <Info className="w-5 h-5 text-blue-400" />
                  What types of trading generate commissions?
                </h5>
                <p className="text-sm text-gray-400">
                  You earn commissions from all trading activities: spot trading, futures trading, perpetual contracts,
                  and crypto swaps. Every fee generated by your network contributes to your earnings.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <h5 className="font-bold mb-2 flex items-center gap-2">
                  <Info className="w-5 h-5 text-blue-400" />
                  Is there a limit to how many people I can refer?
                </h5>
                <p className="text-sm text-gray-400">
                  No limits! You can refer unlimited users and build an unlimited network. The more you grow your
                  network, the more you earn. Your earning potential is completely uncapped.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-gray-700">
                <h5 className="font-bold mb-2 flex items-center gap-2">
                  <Info className="w-5 h-5 text-blue-400" />
                  What if my referral stops trading?
                </h5>
                <p className="text-sm text-gray-400">
                  You only earn when there's trading activity. If a referral becomes inactive, you simply won't earn
                  from them during that period. Focus on quality referrals who are genuinely interested in trading.
                </p>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-red-400">Prohibited Conduct</h4>
            <ul className="space-y-2 text-gray-300">
              <li className="flex items-start gap-2">
                <span className="text-red-400 font-bold">✗</span>
                <span>Wash trading or artificial volume generation</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-red-400 font-bold">✗</span>
                <span>Spam, misleading advertising, or impersonation</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-red-400 font-bold">✗</span>
                <span>Creating fake or fraudulent user accounts</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-red-400 font-bold">✗</span>
                <span>Using incentives that violate local regulations</span>
              </li>
            </ul>
            <div className="mt-4 p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
              <p className="text-sm text-gray-300">
                <strong className="text-red-400">Important:</strong> Violation of these rules may result in immediate
                termination of your affiliate account and forfeiture of pending commissions. We actively monitor for
                fraudulent activity to maintain a fair ecosystem for all affiliates.
              </p>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-green-400">Getting Started</h4>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="bg-[#0b0e11] rounded-lg p-4 text-center border border-gray-700">
                <div className="w-12 h-12 rounded-full bg-blue-500/20 flex items-center justify-center mx-auto mb-3">
                  <span className="text-2xl font-bold text-blue-400">1</span>
                </div>
                <div className="font-bold mb-2">Copy Your Link</div>
                <p className="text-sm text-gray-400">Get your unique affiliate link from the Overview tab</p>
              </div>
              <div className="bg-[#0b0e11] rounded-lg p-4 text-center border border-gray-700">
                <div className="w-12 h-12 rounded-full bg-blue-500/20 flex items-center justify-center mx-auto mb-3">
                  <span className="text-2xl font-bold text-blue-400">2</span>
                </div>
                <div className="font-bold mb-2">Share & Promote</div>
                <p className="text-sm text-gray-400">Distribute your link through your channels</p>
              </div>
              <div className="bg-[#0b0e11] rounded-lg p-4 text-center border border-gray-700">
                <div className="w-12 h-12 rounded-full bg-blue-500/20 flex items-center justify-center mx-auto mb-3">
                  <span className="text-2xl font-bold text-blue-400">3</span>
                </div>
                <div className="font-bold mb-2">Track Performance</div>
                <p className="text-sm text-gray-400">Monitor your network and earnings in real-time</p>
              </div>
              <div className="bg-[#0b0e11] rounded-lg p-4 text-center border border-gray-700">
                <div className="w-12 h-12 rounded-full bg-blue-500/20 flex items-center justify-center mx-auto mb-3">
                  <span className="text-2xl font-bold text-blue-400">4</span>
                </div>
                <div className="font-bold mb-2">Withdraw Earnings</div>
                <p className="text-sm text-gray-400">Request weekly payouts to your wallet</p>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  );

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0b0e11] text-white">
        <Navbar />
        <div className="flex items-center justify-center py-20">
          <div className="text-center">
            <div className="w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-gray-400">Loading affiliate data...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-[#0b0e11] text-white">
        <Navbar />
        <div className="flex items-center justify-center py-20">
          <div className="text-center">
            <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
            <p className="text-gray-400 mb-4">{error}</p>
            <button
              onClick={loadAffiliateData}
              className="px-6 py-3 bg-blue-500 hover:bg-blue-600 rounded-lg transition-all flex items-center gap-2 mx-auto"
            >
              <RefreshCw className="w-5 h-5" />
              Retry
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Network className="w-10 h-10 text-blue-400" />
              <div>
                <h1 className="text-3xl font-bold">Affiliate Program</h1>
                <p className="text-gray-400">Multi-tier affiliate system with lifetime commissions</p>
              </div>
            </div>
            <button
              onClick={loadAffiliateData}
              className="p-2 bg-[#1a1d24] hover:bg-[#2b3139] rounded-lg transition-all"
              title="Refresh data"
            >
              <RefreshCw className="w-5 h-5 text-gray-400" />
            </button>
          </div>
        </div>

        <div className="bg-gradient-to-r from-[#1a1d24] to-[#0b0e11] rounded-xl p-4 mb-6 border border-gray-800">
          <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
            <div className="flex items-center gap-3">
              <button
                onClick={() => {
                  setActiveProgram('referral');
                  handleSwitchProgram('referral');
                }}
                disabled={switching}
                className={`px-5 py-2.5 rounded-lg font-medium transition-all flex items-center gap-2 text-sm ${
                  activeProgram === 'referral'
                    ? 'bg-[#fcd535] text-[#0b0e11]'
                    : 'bg-[#2b3139] text-gray-400 hover:text-white hover:bg-[#3d4450]'
                }`}
              >
                <Users className="w-4 h-4" />
                Simple Referral
                {activeProgram === 'referral' && <CheckCircle className="w-4 h-4" />}
              </button>
              <button
                disabled={true}
                className={`px-5 py-2.5 rounded-lg font-medium transition-all flex items-center gap-2 text-sm ${
                  activeProgram === 'affiliate'
                    ? 'bg-[#fcd535] text-[#0b0e11]'
                    : 'bg-[#2b3139] text-gray-400 hover:text-white hover:bg-[#3d4450]'
                }`}
              >
                <Zap className="w-4 h-4" />
                Affiliate Program
                {activeProgram === 'affiliate' && <CheckCircle className="w-4 h-4" />}
              </button>
            </div>
            <div className="text-sm text-gray-400">
              {activeProgram === 'affiliate' ? (
                <span>5-tier network with {selectedPlan === 'revshare' ? 'Revenue Share' : selectedPlan === 'cpa' ? 'CPA Only' : selectedPlan === 'hybrid' ? 'Hybrid' : 'Auto-Optimize'}</span>
              ) : (
                <span>Single-tier direct commissions</span>
              )}
            </div>
          </div>
        </div>

        <div className="flex gap-2 mb-6 overflow-x-auto pb-2">
          {[
            { id: 'overview', label: 'Overview', icon: TrendingUp },
            { id: 'network', label: 'Network', icon: Users },
            { id: 'earnings', label: 'Earnings', icon: DollarSign },
            { id: 'cpa', label: 'CPA Progress', icon: Target },
            { id: 'calculator', label: 'Calculator', icon: Calculator },
            { id: 'settings', label: 'Settings', icon: Settings },
            { id: 'terms', label: 'Guide', icon: Info }
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`flex items-center gap-2 px-6 py-3 rounded-lg transition-all whitespace-nowrap ${
                activeTab === tab.id
                  ? 'bg-blue-500 text-white'
                  : 'bg-[#1a1d24] text-gray-400 hover:bg-[#2b3139] hover:text-white'
              }`}
            >
              <tab.icon className="w-5 h-5" />
              {tab.label}
            </button>
          ))}
        </div>

        {activeTab === 'overview' && renderOverview()}
        {activeTab === 'network' && renderNetwork()}
        {activeTab === 'earnings' && renderEarnings()}
        {activeTab === 'cpa' && renderCpaProgress()}
        {activeTab === 'calculator' && renderCalculator()}
        {activeTab === 'settings' && renderSettings()}
        {activeTab === 'terms' && renderTerms()}
      </div>
    </div>
  );
}

export default AffiliateProgram;
