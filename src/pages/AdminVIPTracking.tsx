import { useState, useEffect } from 'react';
import { TrendingDown, TrendingUp, AlertTriangle, History, Target, Users, Activity, ArrowLeft, RefreshCw } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';

interface VIPDowngrade {
  id: string;
  user_id: string;
  previous_level: number;
  new_level: number;
  previous_tier_name: string;
  new_tier_name: string;
  tier_difference: number;
  volume_30d: number;
  detected_at: string;
  user_profiles: {
    email: string;
    full_name: string | null;
  };
}

interface VIPHistory {
  id: string;
  user_id: string;
  previous_level: number;
  new_level: number;
  previous_tier_name: string;
  new_tier_name: string;
  change_type: string;
  volume_30d: number;
  changed_at: string;
  user_profiles: {
    email: string;
    full_name: string | null;
  };
}

export default function AdminVIPTracking() {
  const { user } = useAuth();
  const { navigateTo } = useNavigation();
  const [downgrades, setDowngrades] = useState<VIPDowngrade[]>([]);
  const [history, setHistory] = useState<VIPHistory[]>([]);
  const [activeTab, setActiveTab] = useState<'downgrades' | 'upgrades' | 'history'>('downgrades');
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [stats, setStats] = useState({
    totalDowngrades: 0,
    totalUpgrades: 0,
    last7Days: 0,
    last30Days: 0
  });

  useEffect(() => {
    loadData();
    loadStats();
  }, [activeTab]);

  const loadData = async () => {
    setLoading(true);
    try {
      if (activeTab === 'downgrades') {
        const { data: downgrades, error } = await supabase
          .from('vip_tier_downgrades')
          .select('*')
          .order('detected_at', { ascending: false })
          .limit(100);

        if (error) throw error;

        // Fetch user details separately
        if (downgrades && downgrades.length > 0) {
          const userIds = downgrades.map(d => d.user_id);
          const { data: users } = await supabase.auth.admin.listUsers();
          const { data: profiles } = await supabase
            .from('user_profiles')
            .select('id, full_name')
            .in('id', userIds);

          const enrichedDowngrades = downgrades.map(d => {
            const user = users?.users.find(u => u.id === d.user_id);
            const profile = profiles?.find(p => p.id === d.user_id);
            return {
              ...d,
              user_profiles: {
                email: user?.email || 'Unknown',
                full_name: profile?.full_name || null
              }
            };
          });
          setDowngrades(enrichedDowngrades);
        } else {
          setDowngrades([]);
        }
      } else if (activeTab === 'upgrades') {
        const { data: history, error } = await supabase
          .from('vip_level_history')
          .select('*')
          .eq('change_type', 'upgrade')
          .order('changed_at', { ascending: false })
          .limit(100);

        if (error) throw error;

        // Fetch user details separately
        if (history && history.length > 0) {
          const userIds = history.map(h => h.user_id);
          const { data: users } = await supabase.auth.admin.listUsers();
          const { data: profiles } = await supabase
            .from('user_profiles')
            .select('id, full_name')
            .in('id', userIds);

          const enrichedHistory = history.map(h => {
            const user = users?.users.find(u => u.id === h.user_id);
            const profile = profiles?.find(p => p.id === h.user_id);
            return {
              ...h,
              user_profiles: {
                email: user?.email || 'Unknown',
                full_name: profile?.full_name || null
              }
            };
          });
          setHistory(enrichedHistory);
        } else {
          setHistory([]);
        }
      } else {
        const { data: history, error } = await supabase
          .from('vip_level_history')
          .select('*')
          .order('changed_at', { ascending: false })
          .limit(200);

        if (error) throw error;

        // Fetch user details separately
        if (history && history.length > 0) {
          const userIds = history.map(h => h.user_id);
          const { data: users } = await supabase.auth.admin.listUsers();
          const { data: profiles } = await supabase
            .from('user_profiles')
            .select('id, full_name')
            .in('id', userIds);

          const enrichedHistory = history.map(h => {
            const user = users?.users.find(u => u.id === h.user_id);
            const profile = profiles?.find(p => p.id === h.user_id);
            return {
              ...h,
              user_profiles: {
                email: user?.email || 'Unknown',
                full_name: profile?.full_name || null
              }
            };
          });
          setHistory(enrichedHistory);
        } else {
          setHistory([]);
        }
      }
    } catch (error) {
      console.error('Error loading VIP data:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadStats = async () => {
    try {
      const { data: allDowngrades } = await supabase
        .from('vip_tier_downgrades')
        .select('detected_at');

      const { data: allHistory } = await supabase
        .from('vip_level_history')
        .select('changed_at, change_type');

      const now = new Date();
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

      const downgrades7d = allDowngrades?.filter(d => new Date(d.detected_at) > sevenDaysAgo).length || 0;
      const downgrades30d = allDowngrades?.filter(d => new Date(d.detected_at) > thirtyDaysAgo).length || 0;
      const totalUpgrades = allHistory?.filter(h => h.change_type === 'upgrade').length || 0;

      setStats({
        totalDowngrades: allDowngrades?.length || 0,
        totalUpgrades,
        last7Days: downgrades7d,
        last30Days: downgrades30d
      });
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  };

  const getSuggestedBonus = (tierDrop: number, newLevel: number) => {
    if (tierDrop >= 3) return 500;
    if (tierDrop === 2) return 250;
    if (newLevel === 0) return 150;
    return 100;
  };

  const getSeverityColor = (tierDrop: number) => {
    if (tierDrop >= 3) return 'text-red-500';
    if (tierDrop === 2) return 'text-orange-500';
    return 'text-yellow-500';
  };

  const handleManualSync = async () => {
    setSyncing(true);
    try {
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/track-vip-levels`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
            'Content-Type': 'application/json',
          },
        }
      );

      if (!response.ok) throw new Error('Failed to sync VIP levels');

      const result = await response.json();
      alert(`VIP tracking completed!\n\nUsers processed: ${result.stats.totalUsers}\nUpdates: ${result.stats.updatedUsers}\nDowngrades: ${result.stats.downgrades}\nUpgrades: ${result.stats.upgrades}`);

      loadData();
      loadStats();
    } catch (error) {
      console.error('Error syncing VIP levels:', error);
      alert('Failed to sync VIP levels');
    } finally {
      setSyncing(false);
    }
  };

  const getChangeColor = (changeType: string) => {
    switch (changeType) {
      case 'upgrade': return 'text-green-500';
      case 'downgrade': return 'text-red-500';
      case 'maintained': return 'text-gray-500';
      default: return 'text-gray-500';
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <>
      <Navbar />
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 pt-24">
        <div className="max-w-7xl mx-auto">
          <div className="mb-8 flex items-center justify-between">
            <div>
              <div className="flex items-center gap-4 mb-2">
                <button
                  onClick={() => navigateTo('admin')}
                  className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
                >
                  <ArrowLeft className="w-5 h-5 text-gray-400" />
                </button>
                <h1 className="text-3xl font-bold text-white">VIP Tier Monitoring</h1>
              </div>
              <p className="text-gray-400 ml-14">Track VIP level changes and identify users for retention campaigns</p>
            </div>
            <button
              onClick={handleManualSync}
              disabled={syncing}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            >
              <RefreshCw className={`w-4 h-4 ${syncing ? 'animate-spin' : ''}`} />
              {syncing ? 'Syncing...' : 'Sync Now'}
            </button>
          </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
            <div className="flex items-center justify-between mb-2">
              <div className="text-gray-400 text-sm">Total Downgrades</div>
              <TrendingDown className="w-5 h-5 text-red-500" />
            </div>
            <div className="text-3xl font-bold text-white">{stats.totalDowngrades}</div>
          </div>
          <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
            <div className="flex items-center justify-between mb-2">
              <div className="text-gray-400 text-sm">Total Upgrades</div>
              <TrendingUp className="w-5 h-5 text-green-500" />
            </div>
            <div className="text-3xl font-bold text-white">{stats.totalUpgrades}</div>
          </div>
          <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
            <div className="flex items-center justify-between mb-2">
              <div className="text-gray-400 text-sm">Last 7 Days</div>
              <Activity className="w-5 h-5 text-yellow-500" />
            </div>
            <div className="text-3xl font-bold text-white">{stats.last7Days}</div>
          </div>
          <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
            <div className="flex items-center justify-between mb-2">
              <div className="text-gray-400 text-sm">Last 30 Days</div>
              <Users className="w-5 h-5 text-blue-500" />
            </div>
            <div className="text-3xl font-bold text-white">{stats.last30Days}</div>
          </div>
        </div>

        <div className="flex gap-4 mb-6">
          <button
            onClick={() => setActiveTab('downgrades')}
            className={`px-6 py-3 rounded-lg font-medium transition-colors flex items-center gap-2 ${
              activeTab === 'downgrades'
                ? 'bg-red-600 text-white'
                : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
            }`}
          >
            <TrendingDown className="w-5 h-5" />
            Downgrades
          </button>
          <button
            onClick={() => setActiveTab('upgrades')}
            className={`px-6 py-3 rounded-lg font-medium transition-colors flex items-center gap-2 ${
              activeTab === 'upgrades'
                ? 'bg-green-600 text-white'
                : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
            }`}
          >
            <TrendingUp className="w-5 h-5" />
            Upgrades
          </button>
          <button
            onClick={() => setActiveTab('history')}
            className={`px-6 py-3 rounded-lg font-medium transition-colors flex items-center gap-2 ${
              activeTab === 'history'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
            }`}
          >
            <History className="w-5 h-5" />
            All Changes
          </button>
        </div>

        {activeTab === 'downgrades' ? (
          <div className="space-y-4">
            {downgrades.length === 0 ? (
              <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-12 text-center">
                <TrendingDown className="w-16 h-16 text-gray-600 mx-auto mb-4" />
                <h3 className="text-xl font-semibold text-white mb-2">No Downgrades</h3>
                <p className="text-gray-400">No VIP tier downgrades detected</p>
              </div>
            ) : (
              downgrades.map((downgrade) => {
                const suggestedBonus = getSuggestedBonus(downgrade.tier_difference, downgrade.new_level);
                return (
                  <div
                    key={downgrade.id}
                    className="bg-gray-800/50 border border-gray-700 rounded-lg p-6 hover:border-gray-600 transition-colors"
                  >
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-2">
                          <TrendingDown className={`w-6 h-6 ${getSeverityColor(downgrade.tier_difference)}`} />
                          <div>
                            <h3 className="text-lg font-semibold text-white">
                              {downgrade.user_profiles.full_name || downgrade.user_profiles.email}
                            </h3>
                            <p className="text-sm text-gray-400">{downgrade.user_profiles.email}</p>
                          </div>
                        </div>

                        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mt-4">
                          <div>
                            <div className="text-xs text-gray-500 mb-1">Previous Tier</div>
                            <div className="text-sm font-medium text-white">{downgrade.previous_tier_name}</div>
                            <div className="text-xs text-gray-600">Level {downgrade.previous_level}</div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-500 mb-1">Current Tier</div>
                            <div className="text-sm font-medium text-red-400">{downgrade.new_tier_name}</div>
                            <div className="text-xs text-gray-600">Level {downgrade.new_level}</div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-500 mb-1">Severity</div>
                            <div className={`text-sm font-bold ${getSeverityColor(downgrade.tier_difference)}`}>
                              {downgrade.tier_difference === 1 ? 'Minor' : downgrade.tier_difference === 2 ? 'Moderate' : 'Major'}
                            </div>
                            <div className="text-xs text-gray-600">{downgrade.tier_difference} level{downgrade.tier_difference > 1 ? 's' : ''}</div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-500 mb-1">30-Day Volume</div>
                            <div className="text-sm font-medium text-white">${downgrade.volume_30d.toFixed(2)}</div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-500 mb-1">Suggested Bonus</div>
                            <div className="text-sm font-bold text-green-400">${suggestedBonus} USDT</div>
                            <div className="text-xs text-gray-600">Retention offer</div>
                          </div>
                        </div>

                        <div className="mt-4 pt-4 border-t border-gray-700 flex items-center justify-between">
                          <div className="text-sm text-gray-400">
                            Detected: {new Date(downgrade.detected_at).toLocaleDateString()} at {new Date(downgrade.detected_at).toLocaleTimeString()}
                          </div>
                          {downgrade.tier_difference >= 2 && (
                            <div className="flex items-center gap-2 text-orange-500">
                              <AlertTriangle className="w-4 h-4" />
                              <span className="text-sm font-medium">High Priority</span>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        ) : activeTab === 'upgrades' ? (
          <div className="bg-gray-800/50 border border-gray-700 rounded-lg overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-900/50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">User</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Change</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Volume</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-700">
                  {history.map((record) => (
                    <tr key={record.id} className="hover:bg-gray-800/30">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-white">
                          {record.user_profiles.full_name || record.user_profiles.email}
                        </div>
                        <div className="text-xs text-gray-500">{record.user_profiles.email}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center gap-2">
                          <TrendingUp className="w-4 h-4 text-green-500" />
                          <div>
                            <div className="text-sm text-white">
                              {record.previous_tier_name} → {record.new_tier_name}
                            </div>
                            <div className="text-xs text-gray-500">
                              Level {record.previous_level} → {record.new_level}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-white">
                        ${record.volume_30d.toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-400">
                        {new Date(record.changed_at).toLocaleDateString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        ) : (
          <div className="bg-gray-800/50 border border-gray-700 rounded-lg overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-900/50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">User</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Change</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Type</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Volume</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-700">
                  {history.map((record) => (
                    <tr key={record.id} className="hover:bg-gray-800/30">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-white">
                          {record.user_profiles.full_name || record.user_profiles.email}
                        </div>
                        <div className="text-xs text-gray-500">{record.user_profiles.email}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-white">
                          {record.previous_tier_name} → {record.new_tier_name}
                        </div>
                        <div className="text-xs text-gray-500">
                          Level {record.previous_level} → {record.new_level}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`text-sm font-medium capitalize ${getChangeColor(record.change_type)}`}>
                          {record.change_type}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-white">
                        ${record.volume_30d.toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-400">
                        {new Date(record.changed_at).toLocaleString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </div>
    </>
  );
}
