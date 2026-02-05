import { useState, useEffect } from 'react';
import { GitBranch, ChevronDown, ChevronRight, Users, DollarSign } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface LevelStats {
  level: number;
  user_count: number;
  total_deposits: number;
  total_withdrawals: number;
}

interface LevelUser {
  user_id: string;
  username: string | null;
  full_name: string | null;
  email: string;
  created_at: string;
  total_deposits: number;
  total_withdrawals: number;
}

export default function PromoterReferralTree() {
  const [levels, setLevels] = useState<LevelStats[]>([]);
  const [totalUsers, setTotalUsers] = useState(0);
  const [loading, setLoading] = useState(true);
  const [expandedLevel, setExpandedLevel] = useState<number | null>(null);
  const [levelUsers, setLevelUsers] = useState<LevelUser[]>([]);
  const [levelUsersLoading, setLevelUsersLoading] = useState(false);

  useEffect(() => {
    loadTreeStats();
  }, []);

  const loadTreeStats = async () => {
    try {
      const { data, error } = await supabase.rpc('promoter_get_referral_tree_stats');
      if (error) throw error;
      if (data?.success) {
        setLevels(data.levels || []);
        setTotalUsers(data.total_users || 0);
      }
    } catch (err) {
      console.error('Failed to load tree stats:', err);
    } finally {
      setLoading(false);
    }
  };

  const toggleLevel = async (level: number) => {
    if (expandedLevel === level) {
      setExpandedLevel(null);
      setLevelUsers([]);
      return;
    }
    setExpandedLevel(level);
    setLevelUsersLoading(true);
    try {
      const { data, error } = await supabase.rpc('promoter_get_users_at_level', {
        p_level: level,
        p_limit: 50,
        p_offset: 0,
      });
      if (error) throw error;
      if (data?.success) {
        setLevelUsers(data.users || []);
      }
    } catch (err) {
      console.error('Failed to load level users:', err);
    } finally {
      setLevelUsersLoading(false);
    }
  };

  const totalDeposits = levels.reduce((sum, l) => sum + Number(l.total_deposits), 0);
  const totalWithdrawals = levels.reduce((sum, l) => sum + Number(l.total_withdrawals), 0);

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white">Referral Tree</h2>
        <p className="text-sm text-gray-400">Level-by-level breakdown of your entire network</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-[#1a1d24] rounded-xl p-4 border border-gray-800">
          <p className="text-xs text-gray-400 mb-1">Total Users</p>
          <p className="text-lg font-bold text-white">{totalUsers.toLocaleString()}</p>
        </div>
        <div className="bg-[#1a1d24] rounded-xl p-4 border border-gray-800">
          <p className="text-xs text-gray-400 mb-1">Total Levels</p>
          <p className="text-lg font-bold text-blue-400">{levels.length}</p>
        </div>
        <div className="bg-[#1a1d24] rounded-xl p-4 border border-gray-800">
          <p className="text-xs text-gray-400 mb-1">Total Deposits</p>
          <p className="text-lg font-bold text-emerald-400">${totalDeposits.toFixed(2)}</p>
        </div>
        <div className="bg-[#1a1d24] rounded-xl p-4 border border-gray-800">
          <p className="text-xs text-gray-400 mb-1">Total Withdrawals</p>
          <p className="text-lg font-bold text-red-400">${totalWithdrawals.toFixed(2)}</p>
        </div>
      </div>

      {levels.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          <GitBranch className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>No referrals yet</p>
        </div>
      ) : (
        <div className="space-y-2">
          {levels.map(level => {
            const isExpanded = expandedLevel === level.level;
            const depositPct = totalDeposits > 0 ? (Number(level.total_deposits) / totalDeposits) * 100 : 0;

            return (
              <div key={level.level} className="bg-[#1a1d24] rounded-xl border border-gray-800 overflow-hidden">
                <button
                  onClick={() => toggleLevel(level.level)}
                  className="w-full flex items-center justify-between p-4 hover:bg-[#0b0e11] transition-colors text-left"
                >
                  <div className="flex items-center gap-4">
                    {isExpanded ? (
                      <ChevronDown className="w-4 h-4 text-gray-400" />
                    ) : (
                      <ChevronRight className="w-4 h-4 text-gray-400" />
                    )}
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-white font-medium">Level {level.level}</span>
                        <span className="text-xs bg-blue-500/15 text-blue-400 px-2 py-0.5 rounded-md">
                          {level.user_count} users
                        </span>
                      </div>
                      <div className="flex items-center gap-4 mt-1">
                        <span className="text-xs text-emerald-400">
                          Deposits: ${Number(level.total_deposits).toFixed(2)}
                        </span>
                        <span className="text-xs text-red-400">
                          Withdrawals: ${Number(level.total_withdrawals).toFixed(2)}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium text-[#f0b90b]">
                      ${((Number(level.total_deposits) - Number(level.total_withdrawals)) / 2).toFixed(2)}
                    </div>
                    <div className="text-xs text-gray-500">earnings</div>
                  </div>
                </button>

                {isExpanded && (
                  <div className="border-t border-gray-800">
                    <div className="w-full h-1 bg-gray-800">
                      <div className="h-full bg-[#f0b90b]/40 rounded-r" style={{ width: `${Math.min(depositPct, 100)}%` }} />
                    </div>
                    {levelUsersLoading ? (
                      <div className="text-center py-6">
                        <div className="inline-block animate-spin rounded-full h-5 w-5 border-b-2 border-[#f0b90b]" />
                      </div>
                    ) : levelUsers.length === 0 ? (
                      <p className="text-center py-6 text-gray-500 text-sm">No users at this level</p>
                    ) : (
                      <div className="overflow-x-auto">
                        <table className="w-full">
                          <thead>
                            <tr className="border-b border-gray-800/50">
                              <th className="text-left py-2 px-4 text-xs text-gray-500">User</th>
                              <th className="text-right py-2 px-4 text-xs text-gray-500">Deposits</th>
                              <th className="text-right py-2 px-4 text-xs text-gray-500">Withdrawals</th>
                              <th className="text-left py-2 px-4 text-xs text-gray-500">Joined</th>
                            </tr>
                          </thead>
                          <tbody>
                            {levelUsers.map(u => (
                              <tr key={u.user_id} className="border-b border-gray-800/30 hover:bg-[#0b0e11]/50">
                                <td className="py-2 px-4">
                                  <div className="text-sm text-white">{u.full_name || u.username || 'N/A'}</div>
                                  <div className="text-xs text-gray-500">{u.email}</div>
                                </td>
                                <td className="py-2 px-4 text-right text-sm text-emerald-400">
                                  ${Number(u.total_deposits).toFixed(2)}
                                </td>
                                <td className="py-2 px-4 text-right text-sm text-red-400">
                                  ${Number(u.total_withdrawals).toFixed(2)}
                                </td>
                                <td className="py-2 px-4 text-xs text-gray-400">
                                  {new Date(u.created_at).toLocaleDateString()}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
