import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { Gift, TrendingUp, Target, Award, Trophy, CheckCircle2, XCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface Task {
  id: string;
  title: string;
  description: string;
  reward: number;
  rewardType: 'fee_rebate' | 'balance';
  target: number;
  icon: string;
  type: 'volume' | 'referral' | 'trade';
}

function RewardsHub() {
  const { user } = useAuth();
  const [currentVolume, setCurrentVolume] = useState(0);
  const [totalReferrals, setTotalReferrals] = useState(0);
  const [qualifiedReferrals, setQualifiedReferrals] = useState(0);
  const [totalTrades, setTotalTrades] = useState(0);
  const [consecutiveDays, setConsecutiveDays] = useState(0);
  const [totalEarned, setTotalEarned] = useState(0);
  const [pendingRewards, setPendingRewards] = useState<any[]>([]);
  const [claimedTaskIds, setClaimedTaskIds] = useState<Set<string>>(new Set());
  const [feeRebatesTotal, setFeeRebatesTotal] = useState(0);
  const [feeRebatesUsed, setFeeRebatesUsed] = useState(0);
  const [feeRebatesAvailable, setFeeRebatesAvailable] = useState(0);
  const [loading, setLoading] = useState(true);
  const [notification, setNotification] = useState<{type: 'success' | 'error', message: string} | null>(null);
  const [kycVerified, setKycVerified] = useState(false);
  const [copyTradingBalance, setCopyTradingBalance] = useState(0);
  const [tasks] = useState<Task[]>([
    {
      id: 'volume_25k',
      title: 'Trading Volume Milestone',
      description: 'Complete $25,000 in trading volume',
      reward: 10,
      rewardType: 'fee_rebate',
      target: 25000,
      icon: '📊',
      type: 'volume'
    },
    {
      id: 'volume_100k',
      title: 'High Volume Trader',
      description: 'Achieve $100,000 trading volume in 30 days',
      reward: 50,
      rewardType: 'fee_rebate',
      target: 100000,
      icon: '🚀',
      type: 'volume'
    },
    {
      id: 'volume_500k',
      title: 'Elite Trader Status',
      description: 'Complete $500,000 in trading volume',
      reward: 250,
      rewardType: 'fee_rebate',
      target: 500000,
      icon: '💎',
      type: 'volume'
    },
    {
      id: 'kyc_verification',
      title: 'KYC Verification Bonus',
      description: 'Complete KYC verification and unlock full trading',
      reward: 20,
      rewardType: 'balance',
      target: 1,
      icon: '✅',
      type: 'trade'
    },
    {
      id: 'first_referral',
      title: 'First Referral Bonus',
      description: 'Invite your first active trader',
      reward: 5,
      rewardType: 'balance',
      target: 1,
      icon: '🎁',
      type: 'referral'
    },
    {
      id: 'referral_5',
      title: 'Growing Network',
      description: 'Invite 5 friends who deposit at least $100 USD',
      reward: 100,
      rewardType: 'balance',
      target: 5,
      icon: '👥',
      type: 'referral'
    },
    {
      id: 'daily_trade',
      title: 'Daily Trader',
      description: 'Complete at least 1 trade for 7 consecutive days',
      reward: 15,
      rewardType: 'fee_rebate',
      target: 7,
      icon: '⚡',
      type: 'trade'
    },
    {
      id: 'first_trade',
      title: 'First Trade Welcome',
      description: 'Complete your first futures trade',
      reward: 3,
      rewardType: 'balance',
      target: 1,
      icon: '🎯',
      type: 'trade'
    },
    {
      id: 'copy_trading_allocation',
      title: 'Copy Trading Wallet Bonus',
      description: 'Allocate 200 USDT to Copy Trading wallet',
      reward: 50,
      rewardType: 'balance',
      target: 200,
      icon: '👥',
      type: 'volume'
    },
    {
      id: 'volume_10m',
      title: 'Million Dollar Club',
      description: 'Trade $10,000,000 in volume within 30 days',
      reward: 500,
      rewardType: 'balance',
      target: 10000000,
      icon: '🏆',
      type: 'volume'
    },
    {
      id: 'trustpilot_review',
      title: 'Trustpilot Review Bonus',
      description: 'Leave a review on Trustpilot and get rewarded',
      reward: 5,
      rewardType: 'balance',
      target: 1,
      icon: '⭐',
      type: 'trade'
    }
  ]);

  useEffect(() => {
    if (user) {
      loadUserStats();
    }
  }, [user]);

  const loadUserStats = async () => {
    if (!user) return;

    try {
      const { data: statsData, error: statsError } = await supabase
        .from('referral_stats')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      if (statsError && statsError.code !== 'PGRST116') {
        console.error('Error loading stats:', statsError);
      }

      if (statsData) {
        setCurrentVolume(parseFloat(statsData.total_volume_30d));
        setTotalReferrals(statsData.total_referrals);
      }

      const { data: qualifiedData } = await supabase
        .rpc('get_qualified_referral_count', { p_user_id: user.id });

      if (qualifiedData !== null) {
        setQualifiedReferrals(qualifiedData);
      }

      // Check KYC verification status
      const { data: profileData } = await supabase
        .from('user_profiles')
        .select('kyc_verified')
        .eq('user_id', user.id)
        .maybeSingle();

      if (profileData) {
        setKycVerified(profileData.kyc_verified === true);
      }

      // Get copy trading wallet balance
      const { data: copyWalletData } = await supabase
        .from('wallets')
        .select('balance')
        .eq('user_id', user.id)
        .eq('currency', 'USDT')
        .eq('wallet_type', 'copy')
        .maybeSingle();

      if (copyWalletData) {
        setCopyTradingBalance(parseFloat(copyWalletData.balance));
      }

      const { data: rewardsData, error: rewardsError } = await supabase
        .from('user_rewards')
        .select('*')
        .eq('user_id', user.id);

      if (rewardsError) {
        console.error('Error loading rewards:', rewardsError);
      }

      if (rewardsData) {
        const total = rewardsData.reduce((sum, reward) => {
          return sum + parseFloat(reward.amount);
        }, 0);
        setTotalEarned(total);
        setPendingRewards(rewardsData.filter(r => r.status === 'pending'));

        const claimedIds = new Set(
          rewardsData
            .filter(r => r.task_id && r.status === 'claimed')
            .map(r => r.task_id)
        );
        setClaimedTaskIds(claimedIds);
      }

      const { data: feeRebatesData, error: rebatesError } = await supabase
        .from('user_fee_rebates')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      if (rebatesError && rebatesError.code !== 'PGRST116') {
        console.error('Error loading fee rebates:', rebatesError);
      }

      if (feeRebatesData) {
        setFeeRebatesTotal(parseFloat(feeRebatesData.total_rebates));
        setFeeRebatesUsed(parseFloat(feeRebatesData.used_rebates));
        setFeeRebatesAvailable(parseFloat(feeRebatesData.available_rebates));
      }

      // Get total number of trades
      const { count: tradesCount } = await supabase
        .from('futures_positions')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .in('status', ['closed', 'liquidated']);

      if (tradesCount !== null) {
        setTotalTrades(tradesCount);
      }

      // Calculate consecutive trading days (count any position opened)
      const { data: tradeDays } = await supabase
        .from('futures_positions')
        .select('opened_at')
        .eq('user_id', user.id)
        .order('opened_at', { ascending: false });

      if (tradeDays && tradeDays.length > 0) {
        const uniqueDays = new Set<string>();
        tradeDays.forEach(trade => {
          const date = new Date(trade.opened_at).toISOString().split('T')[0];
          uniqueDays.add(date);
        });

        const sortedDays = Array.from(uniqueDays).sort().reverse();
        let consecutive = 0;

        for (let i = 0; i < sortedDays.length; i++) {
          const expectedDate = new Date();
          expectedDate.setDate(expectedDate.getDate() - i);
          const expectedDateStr = expectedDate.toISOString().split('T')[0];

          if (sortedDays[i] === expectedDateStr) {
            consecutive++;
          } else {
            break;
          }
        }

        setConsecutiveDays(consecutive);
      }
    } catch (error) {
      console.error('Error loading user stats:', error);
    } finally {
      setLoading(false);
    }
  };

  const claimReward = async (task: Task) => {
    if (!user) return;

    try {
      const { data: existingClaim } = await supabase
        .from('user_rewards')
        .select('*')
        .eq('user_id', user.id)
        .eq('task_id', task.id)
        .maybeSingle();

      if (existingClaim) {
        setNotification({type: 'error', message: 'You have already claimed this reward!'});
        setTimeout(() => setNotification(null), 3000);
        return;
      }

      if (task.rewardType === 'fee_rebate') {
        const { data: existingRebates } = await supabase
          .from('user_fee_rebates')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

        if (existingRebates) {
          const newTotal = parseFloat(existingRebates.total_rebates) + task.reward;
          const newAvailable = parseFloat(existingRebates.available_rebates) + task.reward;

          const { error: updateError } = await supabase
            .from('user_fee_rebates')
            .update({
              total_rebates: newTotal,
              available_rebates: newAvailable
            })
            .eq('user_id', user.id);

          if (updateError) {
            console.error('Fee rebates update error:', updateError);
            throw updateError;
          }
        } else {
          const { error: insertError } = await supabase
            .from('user_fee_rebates')
            .insert({
              user_id: user.id,
              total_rebates: task.reward,
              available_rebates: task.reward,
              used_rebates: 0
            });

          if (insertError) {
            console.error('Fee rebates insert error:', insertError);
            throw insertError;
          }
        }
      } else {
        // Determine wallet type based on task
        const walletType = task.id === 'copy_trading_allocation' ? 'copy' : 'main';

        const { data: wallet, error: walletFetchError } = await supabase
          .from('wallets')
          .select('*')
          .eq('user_id', user.id)
          .eq('currency', 'USDT')
          .eq('wallet_type', walletType)
          .maybeSingle();

        if (walletFetchError) {
          console.error('Wallet fetch error:', walletFetchError);
          throw walletFetchError;
        }

        if (wallet) {
          const newBalance = parseFloat(wallet.balance) + task.reward;
          const { error: walletError } = await supabase
            .from('wallets')
            .update({
              balance: newBalance.toString()
            })
            .eq('user_id', user.id)
            .eq('currency', 'USDT')
            .eq('wallet_type', walletType);

          if (walletError) {
            console.error('Wallet update error:', walletError);
            throw walletError;
          }
        } else {
          const { error: insertWalletError } = await supabase
            .from('wallets')
            .insert({
              user_id: user.id,
              currency: 'USDT',
              wallet_type: walletType,
              balance: task.reward.toString(),
              locked_balance: '0',
              total_deposited: '0',
              total_withdrawn: '0'
            });

          if (insertWalletError) {
            console.error('Wallet insert error:', insertWalletError);
            throw insertWalletError;
          }
        }
      }

      const description = `${task.title} - ${task.description}`;

      const { error: rewardError } = await supabase
        .from('user_rewards')
        .insert({
          user_id: user.id,
          task_type: task.type,
          amount: task.reward.toString(),
          status: 'claimed',
          task_id: task.id,
          reward_type: task.rewardType,
          description: description,
          claimed_at: new Date().toISOString()
        });

      if (rewardError) {
        console.error('Reward record error:', rewardError);
        throw rewardError;
      }

      const transactionType = task.rewardType === 'fee_rebate' ? 'fee_rebate' : 'reward';
      const { error: txError } = await supabase
        .from('transactions')
        .insert({
          user_id: user.id,
          transaction_type: transactionType,
          currency: 'USDT',
          amount: task.reward.toString(),
          fee: '0',
          status: 'completed',
          address: description,
          confirmed_at: new Date().toISOString()
        });

      if (txError) {
        console.error('Transaction record error:', txError);
      }

      // Send notification to user
      const rewardTypeLabel = task.rewardType === 'fee_rebate' ? 'Fee Rebate' : 'Balance Reward';
      await supabase
        .from('notifications')
        .insert({
          user_id: user.id,
          type: 'reward_claimed',
          title: `Reward Claimed: ${task.title}`,
          message: `You've successfully claimed $${task.reward} USDT ${rewardTypeLabel}!`,
          read: false
        });

      const rewardTypeText = task.rewardType === 'fee_rebate' ? 'fee rebate' : 'balance reward';
      setNotification({type: 'success', message: `Successfully claimed $${task.reward} USDT ${rewardTypeText}!`});
      setTimeout(() => setNotification(null), 3000);
      setClaimedTaskIds(prev => new Set([...prev, task.id]));
      loadUserStats();
    } catch (error: any) {
      console.error('Error claiming reward:', error);
      if (error.code === '23505') {
        setNotification({type: 'error', message: 'You have already claimed this reward!'});
      } else {
        setNotification({type: 'error', message: `Failed to claim reward: ${error.message || 'Please try again.'}`});
      }
      setTimeout(() => setNotification(null), 3000);
    }
  };

  const completedTasks = tasks.filter(task => {
    let progress = 0;
    if (task.type === 'volume') {
      progress = task.id === 'copy_trading_allocation' ? copyTradingBalance : currentVolume;
    } else if (task.type === 'referral') {
      progress = task.id === 'referral_5' ? qualifiedReferrals : totalReferrals;
    } else if (task.type === 'trade') {
      if (task.id === 'kyc_verification') progress = kycVerified ? 1 : 0;
      else if (task.id === 'first_trade') progress = totalTrades;
      else if (task.id === 'daily_trade') progress = consecutiveDays;
    }
    return progress >= task.target;
  });

  return (
    <div className="min-h-screen bg-[#181a20] text-white">
      <Navbar />

      {notification && (
        <div className={`fixed top-20 right-6 z-50 ${notification.type === 'success' ? 'bg-emerald-500' : 'bg-red-500'} text-white px-6 py-4 rounded-lg shadow-lg flex items-center gap-3 animate-slide-in-right`}>
          {notification.type === 'success' ? (
            <CheckCircle2 className="w-5 h-5" />
          ) : (
            <XCircle className="w-5 h-5" />
          )}
          <span className="font-medium">{notification.message}</span>
        </div>
      )}

      <div className="max-w-[1400px] mx-auto px-6 py-6">
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-8">
            <button className="pb-2 text-base text-white font-medium transition-colors relative">
              Rewards Hub
              <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-[#fcd535]"></div>
            </button>
          </div>

          <div className="flex items-center gap-2 text-sm">
            <Trophy className="w-4 h-4 text-[#fcd535]" />
            <span className="text-[#848e9c]">Total Rewards:</span>
            <span className="text-[#fcd535] font-semibold">${totalEarned.toFixed(2)} USDT</span>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-4 gap-4 mb-8">
          <div className="bg-[#2b3139] rounded-lg p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-[#0ecb81]/10 rounded-lg flex items-center justify-center">
                <Award className="w-5 h-5 text-[#0ecb81]" />
              </div>
              <div>
                <div className="text-[#848e9c] text-xs">Available Rewards</div>
                <div className="text-xl font-semibold text-[#eaecef]">${totalEarned.toFixed(2)}</div>
              </div>
            </div>
          </div>

          <div className="bg-[#2b3139] rounded-lg p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-[#fcd535]/10 rounded-lg flex items-center justify-center">
                <Target className="w-5 h-5 text-[#fcd535]" />
              </div>
              <div>
                <div className="text-[#848e9c] text-xs">Completed Tasks</div>
                <div className="text-xl font-semibold text-[#eaecef]">{completedTasks.length} / {tasks.length}</div>
              </div>
            </div>
          </div>

          <div className="bg-[#2b3139] rounded-lg p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-[#0ecb81]/10 rounded-lg flex items-center justify-center">
                <TrendingUp className="w-5 h-5 text-[#0ecb81]" />
              </div>
              <div>
                <div className="text-[#848e9c] text-xs">30-Day Volume</div>
                <div className="text-xl font-semibold text-[#eaecef]">${currentVolume.toLocaleString()}</div>
              </div>
            </div>
          </div>

          <div className="bg-gradient-to-br from-[#fcd535]/20 to-[#f0b90b]/10 border border-[#fcd535]/30 rounded-lg p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-[#fcd535] rounded-lg flex items-center justify-center">
                <span className="text-lg">🎟️</span>
              </div>
              <div>
                <div className="text-[#fcd535] text-xs font-medium">Fee Rebates (USDT)</div>
                <div className="text-xl font-bold text-white">${feeRebatesAvailable.toFixed(2)}</div>
              </div>
            </div>
            <div className="mt-3 pt-3 border-t border-[#fcd535]/20">
              <div className="flex justify-between text-xs">
                <span className="text-[#848e9c]">Total Earned:</span>
                <span className="text-[#eaecef] font-medium">${feeRebatesTotal.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-xs mt-1">
                <span className="text-[#848e9c]">Used:</span>
                <span className="text-[#f6465d] font-medium">${feeRebatesUsed.toFixed(2)}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-[#2b3139] rounded-lg p-6 mb-8">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-medium text-white flex items-center gap-2">
              <Gift className="w-5 h-5 text-[#fcd535]" />
              Available Tasks
            </h2>
            <span className="text-xs text-[#848e9c]">Complete tasks to earn USDT rewards</span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {tasks.map((task) => {
              let progress = 0;
              if (task.type === 'volume') {
                if (task.id === 'copy_trading_allocation') {
                  progress = copyTradingBalance;
                } else {
                  progress = currentVolume;
                }
              } else if (task.type === 'referral') {
                if (task.id === 'referral_5') {
                  progress = qualifiedReferrals;
                } else {
                  progress = totalReferrals;
                }
              } else if (task.type === 'trade') {
                if (task.id === 'kyc_verification') {
                  progress = kycVerified ? 1 : 0;
                } else if (task.id === 'first_trade') {
                  progress = totalTrades;
                } else if (task.id === 'daily_trade') {
                  progress = consecutiveDays;
                }
              }
              const percentage = Math.min((progress / task.target) * 100, 100);
              const isCompleted = progress >= task.target;
              const isClaimed = claimedTaskIds.has(task.id);

              return (
                <div key={task.id} className={`bg-[#181a20] rounded-lg p-4 transition-all ${
                  isClaimed ? 'opacity-60' : 'hover:bg-[#1e2329]'
                }`}>
                  <div className="flex items-start justify-between mb-3">
                    <div className="text-3xl">{task.icon}</div>
                    <div className="text-right">
                      <div className={`text-xs px-2 py-1 rounded font-medium mb-1 ${
                        isClaimed
                          ? 'bg-[#848e9c]/10 text-[#848e9c]'
                          : 'bg-[#0ecb81]/10 text-[#0ecb81]'
                      }`}>
                        {isClaimed ? 'Claimed' : `+$${task.reward} USDT`}
                      </div>
                      <div className="text-[10px] text-[#848e9c]">
                        {task.rewardType === 'fee_rebate' ? 'Fee Rebate' : 'Balance'}
                      </div>
                    </div>
                  </div>

                  <h3 className="text-sm font-medium text-white mb-1">{task.title}</h3>
                  <p className="text-xs text-[#848e9c] mb-2">{task.description}</p>
                  {task.id === 'trustpilot_review' && !isClaimed && (
                    <a
                      href="https://www.trustpilot.com/review/shark-trades.com"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 text-xs text-[#fcd535] hover:text-[#f0b90b] mb-2"
                    >
                      Leave a Review on Trustpilot
                      <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </a>
                  )}

                  {!isClaimed && (
                    <div className="mb-2">
                      <div className="flex items-center justify-between text-xs mb-1">
                        <span className="text-[#848e9c]">Progress</span>
                        <span className="text-[#eaecef] font-medium">
                          {task.type === 'volume' ? `$${progress.toLocaleString()}` : progress} / {task.type === 'volume' ? `$${task.target.toLocaleString()}` : task.target}
                        </span>
                      </div>
                      <div className="w-full bg-[#2b3139] rounded-full h-1.5">
                        <div
                          className={`h-1.5 rounded-full transition-all ${
                            isCompleted ? 'bg-[#0ecb81]' : 'bg-[#fcd535]'
                          }`}
                          style={{ width: `${percentage}%` }}
                        />
                      </div>
                    </div>
                  )}

                  <button
                    disabled={!isCompleted || isClaimed}
                    onClick={() => isCompleted && !isClaimed && claimReward(task)}
                    className={`w-full text-xs font-medium py-2 rounded transition-all ${
                      isClaimed
                        ? 'bg-[#2b3139] text-[#848e9c] cursor-not-allowed'
                        : isCompleted
                        ? 'bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11]'
                        : 'bg-[#2b3139] text-[#848e9c] cursor-not-allowed'
                    }`}
                  >
                    {isClaimed ? 'Claimed ✓' : isCompleted ? 'Claim Reward' : `${percentage.toFixed(0)}% Complete`}
                  </button>
                </div>
              );
            })}
          </div>
        </div>

        <div className="bg-[#2b3139] rounded-lg p-6">
          <h2 className="text-xl font-medium text-white mb-4">How Rewards Work</h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <div className="bg-[#181a20] rounded-lg p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="text-3xl">💰</div>
                <h3 className="text-base font-medium text-[#eaecef]">Balance Rewards</h3>
              </div>
              <p className="text-sm text-[#848e9c] mb-3">Direct USDT added to your wallet balance that you can use for trading or withdraw immediately</p>
              <div className="text-xs text-[#0ecb81]">Examples: KYC Verification, Copy Trading Bonus, Referral bonuses, First trade welcome, Million Dollar Club</div>
            </div>

            <div className="bg-[#181a20] rounded-lg p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="text-3xl">🎟️</div>
                <h3 className="text-base font-medium text-[#eaecef]">Fee Rebates</h3>
              </div>
              <p className="text-sm text-[#848e9c] mb-3">Credits that reduce your future trading fees, helping you save on transaction costs</p>
              <div className="text-xs text-[#fcd535]">Examples: Trading volume milestones, Daily trader streak</div>
            </div>
          </div>

          <div className="bg-[#0ecb81]/10 border border-[#0ecb81]/20 rounded-lg p-4">
            <div className="flex items-start gap-3">
              <div className="text-2xl">💡</div>
              <div className="text-sm text-[#eaecef]">
                <p className="font-medium mb-2">Quick Tips:</p>
                <ul className="space-y-1 text-xs text-[#848e9c]">
                  <li>• Complete tasks to unlock both types of rewards</li>
                  <li>• Balance rewards can be withdrawn or traded immediately</li>
                  <li>• Fee rebates automatically reduce your trading costs</li>
                  <li>• Track your progress in real-time on this page</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default RewardsHub;
