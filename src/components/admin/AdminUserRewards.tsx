import { useState, useEffect } from 'react';
import { Gift, DollarSign, Award, TrendingUp } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Props {
  userId: string;
}

export default function AdminUserRewards({ userId }: Props) {
  const [rewards, setRewards] = useState<any[]>([]);
  const [referralCommissions, setReferralCommissions] = useState<any[]>([]);
  const [stats, setStats] = useState({
    totalRewards: 0,
    claimedRewards: 0,
    pendingRewards: 0,
    totalReferralEarnings: 0,
    totalReferrals: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadRewardsData();
  }, [userId]);

  const loadRewardsData = async () => {
    setLoading(true);
    try {
      const [rewardsRes, commissionsRes, referralStatsRes] = await Promise.all([
        supabase
          .from('user_rewards')
          .select('*')
          .eq('user_id', userId)
          .order('earned_at', { ascending: false }),
        supabase
          .from('referral_commissions')
          .select(`
            *,
            referred:referred_user_id (
              username,
              full_name
            )
          `)
          .eq('referrer_id', userId)
          .order('created_at', { ascending: false }),
        supabase
          .from('referral_stats')
          .select('*')
          .eq('user_id', userId)
          .single()
      ]);

      const allRewards = rewardsRes.data || [];
      const totalRewards = allRewards.reduce((sum, r) => sum + parseFloat(r.amount), 0);
      const claimedRewards = allRewards
        .filter(r => r.status === 'claimed')
        .reduce((sum, r) => sum + parseFloat(r.amount), 0);
      const pendingRewards = allRewards
        .filter(r => r.status === 'pending')
        .reduce((sum, r) => sum + parseFloat(r.amount), 0);

      const totalReferralEarnings = (commissionsRes.data || [])
        .reduce((sum, c) => sum + parseFloat(c.commission_amount), 0);

      setRewards(allRewards);
      setReferralCommissions(commissionsRes.data || []);
      setStats({
        totalRewards,
        claimedRewards,
        pendingRewards,
        totalReferralEarnings,
        totalReferrals: referralStatsRes.data?.total_referrals || 0
      });
    } catch (error) {
      console.error('Error loading rewards data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white mb-4">Rewards Summary</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-yellow-500/10 rounded-lg flex items-center justify-center">
                <Gift className="w-5 h-5 text-yellow-400" />
              </div>
              <span className="text-sm text-gray-400">Total Rewards</span>
            </div>
            <p className="text-2xl font-bold text-white">
              ${stats.totalRewards.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-green-500/10 rounded-lg flex items-center justify-center">
                <DollarSign className="w-5 h-5 text-green-400" />
              </div>
              <span className="text-sm text-gray-400">Claimed</span>
            </div>
            <p className="text-2xl font-bold text-green-400">
              ${stats.claimedRewards.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-orange-500/10 rounded-lg flex items-center justify-center">
                <Award className="w-5 h-5 text-orange-400" />
              </div>
              <span className="text-sm text-gray-400">Pending</span>
            </div>
            <p className="text-2xl font-bold text-orange-400">
              ${stats.pendingRewards.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-blue-500/10 rounded-lg flex items-center justify-center">
                <TrendingUp className="w-5 h-5 text-blue-400" />
              </div>
              <span className="text-sm text-gray-400">Referral Earnings</span>
            </div>
            <p className="text-2xl font-bold text-blue-400">
              ${stats.totalReferralEarnings.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
            <p className="text-xs text-gray-500 mt-1">{stats.totalReferrals} referrals</p>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Reward History</h2>
        {rewards.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <p className="text-gray-400">No rewards earned yet</p>
          </div>
        ) : (
          <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-gray-800">
                <tr>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Date</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Type</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Description</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Amount</th>
                  <th className="text-center py-3 px-4 text-sm font-medium text-gray-400">Status</th>
                </tr>
              </thead>
              <tbody>
                {rewards.map((reward) => (
                  <tr key={reward.id} className="border-b border-gray-800/50">
                    <td className="py-3 px-4 text-sm text-gray-400">
                      {new Date(reward.earned_at).toLocaleString()}
                    </td>
                    <td className="py-3 px-4">
                      <span className="px-2 py-1 bg-purple-500/20 text-purple-400 rounded text-xs font-medium">
                        {reward.reward_type}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-white text-sm">{reward.description || 'N/A'}</td>
                    <td className="py-3 px-4 text-right text-green-400 font-bold">
                      +${parseFloat(reward.amount).toFixed(2)}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <span className={`px-2 py-1 rounded text-xs font-medium ${
                        reward.status === 'claimed'
                          ? 'bg-green-500/20 text-green-400'
                          : reward.status === 'pending'
                          ? 'bg-yellow-500/20 text-yellow-400'
                          : 'bg-gray-500/20 text-gray-400'
                      }`}>
                        {reward.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Referral Commissions</h2>
        {referralCommissions.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <p className="text-gray-400">No referral commissions earned yet</p>
          </div>
        ) : (
          <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-gray-800">
                <tr>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Date</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Referred User</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Trade Type</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Trade Volume</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Commission</th>
                </tr>
              </thead>
              <tbody>
                {referralCommissions.map((commission) => (
                  <tr key={commission.id} className="border-b border-gray-800/50">
                    <td className="py-3 px-4 text-sm text-gray-400">
                      {new Date(commission.created_at).toLocaleString()}
                    </td>
                    <td className="py-3 px-4">
                      <div>
                        <div className="text-white font-medium">
                          {commission.referred?.username || 'Unknown User'}
                        </div>
                        <div className="text-xs text-gray-400">
                          {commission.referred?.full_name || 'N/A'}
                        </div>
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <span className="px-2 py-1 bg-blue-500/20 text-blue-400 rounded text-xs font-medium">
                        {commission.trade_type || 'N/A'}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right text-white">
                      ${parseFloat(commission.trade_volume || '0').toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </td>
                    <td className="py-3 px-4 text-right text-green-400 font-bold">
                      +${parseFloat(commission.commission_amount).toFixed(2)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
