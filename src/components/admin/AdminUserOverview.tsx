import { useState, useEffect } from 'react';
import { Wallet, TrendingUp, Users, Calendar, DollarSign, Award } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Props {
  userId: string;
  userData: any;
  onRefresh: () => void;
}

export default function AdminUserOverview({ userId, userData, onRefresh }: Props) {
  const [stats, setStats] = useState({
    totalBalance: 0,
    totalDeposited: 0,
    totalWithdrawn: 0,
    netDeposit: 0,
    openPositionsCount: 0,
    totalUnrealizedPnl: 0,
    totalRealizedPnl: 0,
    lifetimeTrades: 0,
    lifetimeVolume: 0,
    lifetimeFees: 0,
    referralEarnings: 0,
    rewardsEarned: 0
  });

  useEffect(() => {
    loadStats();
  }, [userId]);

  const loadStats = async () => {
    // Get total portfolio value in USD using the database function
    const { data: portfolioData } = await supabase.rpc('calculate_total_portfolio_value_usd', {
      p_user_id: userId
    });

    const totalBalance = portfolioData || 0;

    const { data: wallets } = await supabase
      .from('wallets')
      .select('balance, total_deposited, total_withdrawn')
      .eq('user_id', userId);

    const totalDeposited = wallets?.reduce((sum, w) => sum + parseFloat(w.total_deposited || '0'), 0) || 0;
    const totalWithdrawn = wallets?.reduce((sum, w) => sum + parseFloat(w.total_withdrawn || '0'), 0) || 0;

    const { count: openPositionsCount } = await supabase
      .from('futures_positions')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('status', 'open');

    const { data: openPositions } = await supabase
      .from('futures_positions')
      .select('unrealized_pnl')
      .eq('user_id', userId)
      .eq('status', 'open');

    const totalUnrealizedPnl = openPositions?.reduce((sum, p) => sum + parseFloat(p.unrealized_pnl || '0'), 0) || 0;

    const { data: closedPositions } = await supabase
      .from('futures_positions')
      .select('realized_pnl')
      .eq('user_id', userId)
      .eq('status', 'closed');

    const totalRealizedPnl = closedPositions?.reduce((sum, p) => sum + parseFloat(p.realized_pnl || '0'), 0) || 0;

    const { count: lifetimeTrades } = await supabase
      .from('trades')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId);

    const { data: trades } = await supabase
      .from('trades')
      .select('quantity, price, fee')
      .eq('user_id', userId);

    const lifetimeVolume = trades?.reduce((sum, t) =>
      sum + (parseFloat(t.quantity) * parseFloat(t.price)), 0
    ) || 0;

    const lifetimeFees = trades?.reduce((sum, t) => sum + parseFloat(t.fee || '0'), 0) || 0;

    const { data: referralCommissions } = await supabase
      .from('referral_commissions')
      .select('commission_amount')
      .eq('referrer_id', userId);

    const referralEarnings = referralCommissions?.reduce((sum, c) => sum + parseFloat(c.commission_amount), 0) || 0;

    const { data: rewards } = await supabase
      .from('user_rewards')
      .select('amount')
      .eq('user_id', userId)
      .eq('status', 'claimed');

    const rewardsEarned = rewards?.reduce((sum, r) => sum + parseFloat(r.amount), 0) || 0;

    setStats({
      totalBalance,
      totalDeposited,
      totalWithdrawn,
      netDeposit: totalDeposited - totalWithdrawn,
      openPositionsCount: openPositionsCount || 0,
      totalUnrealizedPnl,
      totalRealizedPnl,
      lifetimeTrades: lifetimeTrades || 0,
      lifetimeVolume,
      lifetimeFees,
      referralEarnings,
      rewardsEarned
    });
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white mb-4">Client Snapshot</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 bg-green-500/10 rounded-lg flex items-center justify-center">
                <Wallet className="w-5 h-5 text-green-400" />
              </div>
              <span className="text-sm text-gray-400">Total Balance</span>
            </div>
            <p className="text-2xl font-bold text-white">
              ${stats.totalBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 bg-blue-500/10 rounded-lg flex items-center justify-center">
                <TrendingUp className="w-5 h-5 text-blue-400" />
              </div>
              <span className="text-sm text-gray-400">Open Positions</span>
            </div>
            <p className="text-2xl font-bold text-white">{stats.openPositionsCount}</p>
            <p className={`text-sm mt-1 ${stats.totalUnrealizedPnl >= 0 ? 'text-green-400' : 'text-red-400'}`}>
              {stats.totalUnrealizedPnl >= 0 ? '+' : ''}${Math.abs(stats.totalUnrealizedPnl).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} P&L
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 bg-purple-500/10 rounded-lg flex items-center justify-center">
                <DollarSign className="w-5 h-5 text-purple-400" />
              </div>
              <span className="text-sm text-gray-400">Realized P&L</span>
            </div>
            <p className={`text-2xl font-bold ${stats.totalRealizedPnl >= 0 ? 'text-green-400' : 'text-red-400'}`}>
              {stats.totalRealizedPnl >= 0 ? '+' : ''}${Math.abs(stats.totalRealizedPnl).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 bg-yellow-500/10 rounded-lg flex items-center justify-center">
                <Calendar className="w-5 h-5 text-yellow-400" />
              </div>
              <span className="text-sm text-gray-400">Account Age</span>
            </div>
            <p className="text-2xl font-bold text-white">
              {Math.floor((Date.now() - new Date(userData?.profile?.created_at).getTime()) / (1000 * 60 * 60 * 24))} days
            </p>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">User Information</h2>
        <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <p className="text-sm text-gray-400 mb-1">Full Name</p>
              <p className="text-white">{userData?.profile?.full_name || 'Not provided'}</p>
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">Phone</p>
              <p className="text-white">{userData?.profile?.phone || 'Not provided'}</p>
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">Country</p>
              <p className="text-white">{userData?.profile?.country || 'Not provided'}</p>
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">Referral Code</p>
              <p className="text-white font-mono">{userData?.profile?.referral_code || 'N/A'}</p>
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">Account Created</p>
              <p className="text-white">{formatDate(userData?.profile?.created_at)}</p>
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">Last Updated</p>
              <p className="text-white">{formatDate(userData?.profile?.updated_at)}</p>
            </div>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Financial Summary</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <p className="text-sm text-gray-400 mb-2">Total Deposited</p>
            <p className="text-xl font-bold text-white">
              ${stats.totalDeposited.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <p className="text-sm text-gray-400 mb-2">Total Withdrawn</p>
            <p className="text-xl font-bold text-white">
              ${stats.totalWithdrawn.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <p className="text-sm text-gray-400 mb-2">Net Deposit</p>
            <p className={`text-xl font-bold ${stats.netDeposit >= 0 ? 'text-green-400' : 'text-red-400'}`}>
              {stats.netDeposit >= 0 ? '+' : ''}${Math.abs(stats.netDeposit).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Trading Performance</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <p className="text-sm text-gray-400 mb-2">Lifetime Trades</p>
            <p className="text-xl font-bold text-white">{stats.lifetimeTrades.toLocaleString()}</p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <p className="text-sm text-gray-400 mb-2">Lifetime Volume</p>
            <p className="text-xl font-bold text-white">
              ${stats.lifetimeVolume.toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <p className="text-sm text-gray-400 mb-2">Lifetime Fees Paid</p>
            <p className="text-xl font-bold text-white">
              ${stats.lifetimeFees.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-2 mb-2">
              <Award className="w-4 h-4 text-yellow-400" />
              <p className="text-sm text-gray-400">Total Earnings</p>
            </div>
            <p className="text-xl font-bold text-green-400">
              ${(stats.referralEarnings + stats.rewardsEarned).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
            <p className="text-xs text-gray-500 mt-1">
              Referrals: ${stats.referralEarnings.toFixed(2)} • Rewards: ${stats.rewardsEarned.toFixed(2)}
            </p>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Referral Statistics</h2>
        <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <p className="text-sm text-gray-400 mb-1">VIP Level</p>
              <p className="text-2xl font-bold text-[#f0b90b]">{userData?.referralStats?.vip_level || 1}</p>
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">Total Referrals</p>
              <p className="text-2xl font-bold text-white">{userData?.referralStats?.total_referrals || 0}</p>
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">30d Volume from Referrals</p>
              <p className="text-2xl font-bold text-white">
                ${(userData?.referralStats?.total_volume_30d || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
