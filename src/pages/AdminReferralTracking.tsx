import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { Users, TrendingUp, DollarSign, MapPin, Activity, Search, ArrowLeft, ChevronDown, ChevronUp } from 'lucide-react';

interface ReferrerDetails {
  referrer_id: string;
  referrer_name: string;
  referrer_email: string;
  referrer_code: string;
  total_referrals: number;
  active_traders: number;
  depositors: number;
  total_deposit_amount: number;
  total_trading_volume: number;
  total_commissions_earned: number;
  avg_user_value: number;
}

interface ReferredUser {
  id: string;
  full_name: string;
  email: string;
  country: string;
  created_at: string;
  is_trader: boolean;
  has_deposited: boolean;
  total_deposits: number;
  trading_volume: number;
  kyc_status: string;
}

export default function AdminReferralTracking() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const [referrers, setReferrers] = useState<ReferrerDetails[]>([]);
  const [expandedReferrer, setExpandedReferrer] = useState<string | null>(null);
  const [referredUsers, setReferredUsers] = useState<{ [key: string]: ReferredUser[] }>({});
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortBy, setSortBy] = useState<'referrals' | 'volume' | 'commissions'>('referrals');

  useEffect(() => {
    checkAdminAndLoadData();
  }, [user]);

  const checkAdminAndLoadData = async () => {
    if (!user) {
      navigateTo('home');
      return;
    }

    const { data: profile } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();

    if (!profile?.is_admin) {
      navigateTo('home');
      return;
    }

    await loadReferrers();
  };

  const loadReferrers = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('get_referrer_statistics');

      if (error) throw error;

      setReferrers(data || []);
    } catch (error) {
      console.error('Error loading referrers:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadReferredUsers = async (referrerId: string) => {
    if (referredUsers[referrerId]) {
      setExpandedReferrer(expandedReferrer === referrerId ? null : referrerId);
      return;
    }

    try {
      const { data, error } = await supabase.rpc('get_referred_users_details', {
        p_referrer_id: referrerId
      });

      if (error) throw error;

      setReferredUsers(prev => ({ ...prev, [referrerId]: data || [] }));
      setExpandedReferrer(referrerId);
    } catch (error) {
      console.error('Error loading referred users:', error);
    }
  };

  const filteredReferrers = referrers
    .filter(r =>
      r.referrer_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      r.referrer_email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      r.referrer_code?.toLowerCase().includes(searchTerm.toLowerCase())
    )
    .sort((a, b) => {
      switch (sortBy) {
        case 'volume':
          return b.total_trading_volume - a.total_trading_volume;
        case 'commissions':
          return b.total_commissions_earned - a.total_commissions_earned;
        default:
          return b.total_referrals - a.total_referrals;
      }
    });

  const getCountryFlag = (countryCode: string) => {
    if (!countryCode || countryCode.length !== 2) return '🌍';
    const codePoints = countryCode
      .toUpperCase()
      .split('')
      .map(char => 127397 + char.charCodeAt(0));
    return String.fromCodePoint(...codePoints);
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 flex items-center justify-center">
        <div className="text-white text-xl">Loading referral data...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 text-white p-8">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-4">
            <button
              onClick={() => navigateTo('admindashboard')}
              className="p-2 hover:bg-white/10 rounded-lg transition-colors"
            >
              <ArrowLeft className="w-6 h-6" />
            </button>
            <div>
              <h1 className="text-3xl font-bold">Referral Tracking</h1>
              <p className="text-gray-400 mt-1">Monitor affiliate performance and referred users</p>
            </div>
          </div>
        </div>

        {/* Summary Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white/5 rounded-xl p-6 border border-white/10">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Total Referrers</p>
                <p className="text-3xl font-bold mt-2">{referrers.length}</p>
              </div>
              <div className="p-3 bg-blue-500/20 rounded-lg">
                <Users className="w-6 h-6 text-blue-400" />
              </div>
            </div>
          </div>

          <div className="bg-white/5 rounded-xl p-6 border border-white/10">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Total Referrals</p>
                <p className="text-3xl font-bold mt-2">
                  {referrers.reduce((sum, r) => sum + r.total_referrals, 0)}
                </p>
              </div>
              <div className="p-3 bg-green-500/20 rounded-lg">
                <TrendingUp className="w-6 h-6 text-green-400" />
              </div>
            </div>
          </div>

          <div className="bg-white/5 rounded-xl p-6 border border-white/10">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Total Trading Volume</p>
                <p className="text-3xl font-bold mt-2">
                  {formatCurrency(referrers.reduce((sum, r) => sum + r.total_trading_volume, 0))}
                </p>
              </div>
              <div className="p-3 bg-purple-500/20 rounded-lg">
                <Activity className="w-6 h-6 text-purple-400" />
              </div>
            </div>
          </div>

          <div className="bg-white/5 rounded-xl p-6 border border-white/10">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Total Commissions</p>
                <p className="text-3xl font-bold mt-2">
                  {formatCurrency(referrers.reduce((sum, r) => sum + r.total_commissions_earned, 0))}
                </p>
              </div>
              <div className="p-3 bg-yellow-500/20 rounded-lg">
                <DollarSign className="w-6 h-6 text-yellow-400" />
              </div>
            </div>
          </div>
        </div>

        {/* Search and Sort */}
        <div className="flex flex-col md:flex-row gap-4 mb-6">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="Search by name, email, or referral code..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded-lg pl-10 pr-4 py-3 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setSortBy('referrals')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                sortBy === 'referrals'
                  ? 'bg-blue-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              By Referrals
            </button>
            <button
              onClick={() => setSortBy('volume')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                sortBy === 'volume'
                  ? 'bg-blue-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              By Volume
            </button>
            <button
              onClick={() => setSortBy('commissions')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                sortBy === 'commissions'
                  ? 'bg-blue-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              By Commissions
            </button>
          </div>
        </div>

        {/* Referrers List */}
        <div className="space-y-4">
          {filteredReferrers.map((referrer) => (
            <div key={referrer.referrer_id} className="bg-white/5 rounded-xl border border-white/10 overflow-hidden">
              <div
                className="p-6 cursor-pointer hover:bg-white/5 transition-colors"
                onClick={() => loadReferredUsers(referrer.referrer_id)}
              >
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-4">
                      <div>
                        <h3 className="text-xl font-bold">{referrer.referrer_name}</h3>
                        <p className="text-gray-400 text-sm">{referrer.referrer_email}</p>
                        <p className="text-blue-400 text-sm mt-1">Code: {referrer.referrer_code}</p>
                      </div>
                    </div>
                  </div>

                  <div className="grid grid-cols-6 gap-8 mr-8">
                    <div className="text-center">
                      <p className="text-2xl font-bold text-blue-400">{referrer.total_referrals}</p>
                      <p className="text-xs text-gray-400 mt-1">Total Referrals</p>
                    </div>
                    <div className="text-center">
                      <p className="text-2xl font-bold text-green-400">{referrer.active_traders}</p>
                      <p className="text-xs text-gray-400 mt-1">Active Traders</p>
                    </div>
                    <div className="text-center">
                      <p className="text-2xl font-bold text-yellow-400">{referrer.depositors}</p>
                      <p className="text-xs text-gray-400 mt-1">Depositors</p>
                    </div>
                    <div className="text-center">
                      <p className="text-lg font-bold text-purple-400">{formatCurrency(referrer.total_deposit_amount)}</p>
                      <p className="text-xs text-gray-400 mt-1">Total Deposits</p>
                    </div>
                    <div className="text-center">
                      <p className="text-lg font-bold text-cyan-400">{formatCurrency(referrer.total_trading_volume)}</p>
                      <p className="text-xs text-gray-400 mt-1">Trading Volume</p>
                    </div>
                    <div className="text-center">
                      <p className="text-lg font-bold text-orange-400">{formatCurrency(referrer.total_commissions_earned)}</p>
                      <p className="text-xs text-gray-400 mt-1">Commissions</p>
                    </div>
                  </div>

                  <div className="p-2">
                    {expandedReferrer === referrer.referrer_id ? (
                      <ChevronUp className="w-6 h-6 text-gray-400" />
                    ) : (
                      <ChevronDown className="w-6 h-6 text-gray-400" />
                    )}
                  </div>
                </div>
              </div>

              {/* Expanded Details - Referred Users */}
              {expandedReferrer === referrer.referrer_id && referredUsers[referrer.referrer_id] && (
                <div className="border-t border-white/10 p-6 bg-black/20">
                  <h4 className="text-lg font-semibold mb-4">Referred Users ({referredUsers[referrer.referrer_id].length})</h4>
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-white/10">
                          <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">User</th>
                          <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Country</th>
                          <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Status</th>
                          <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Joined</th>
                          <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Deposits</th>
                          <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Trading Volume</th>
                        </tr>
                      </thead>
                      <tbody>
                        {referredUsers[referrer.referrer_id].map((user) => (
                          <tr key={user.id} className="border-b border-white/5 hover:bg-white/5">
                            <td className="py-4 px-4">
                              <div>
                                <p className="font-medium">{user.full_name}</p>
                                <p className="text-sm text-gray-400">{user.email}</p>
                              </div>
                            </td>
                            <td className="py-4 px-4">
                              <div className="flex items-center gap-2">
                                <span className="text-2xl">{getCountryFlag(user.country)}</span>
                                <span className="text-sm">{user.country || 'Unknown'}</span>
                              </div>
                            </td>
                            <td className="py-4 px-4">
                              <div className="flex flex-col gap-1">
                                {user.is_trader && (
                                  <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs bg-green-500/20 text-green-400">
                                    <Activity className="w-3 h-3" />
                                    Trader
                                  </span>
                                )}
                                {user.has_deposited && (
                                  <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs bg-blue-500/20 text-blue-400">
                                    <DollarSign className="w-3 h-3" />
                                    Depositor
                                  </span>
                                )}
                                {user.kyc_status === 'verified' && (
                                  <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs bg-purple-500/20 text-purple-400">
                                    KYC Verified
                                  </span>
                                )}
                              </div>
                            </td>
                            <td className="py-4 px-4 text-sm text-gray-400">
                              {new Date(user.created_at).toLocaleDateString()}
                            </td>
                            <td className="py-4 px-4 text-right font-medium">
                              {formatCurrency(user.total_deposits)}
                            </td>
                            <td className="py-4 px-4 text-right font-medium">
                              {formatCurrency(user.trading_volume)}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>
          ))}

          {filteredReferrers.length === 0 && (
            <div className="text-center py-12 text-gray-400">
              <Users className="w-16 h-16 mx-auto mb-4 opacity-50" />
              <p>No referrers found</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
