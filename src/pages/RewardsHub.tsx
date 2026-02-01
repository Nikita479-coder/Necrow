import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { Gift, TrendingUp, Target, Award, Trophy, CheckCircle2, XCircle, ExternalLink } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface Task {
  id: string;
  title: string;
  description: string;
  reward: number;
  rewardType: 'fee_rebate' | 'balance' | 'locked_bonus';
  target: number;
  icon: string;
  type: 'volume' | 'referral' | 'trade' | 'external';
  externalLink?: string;
}

interface CopyBonusStatus {
  eligible: boolean;
  already_claimed: boolean;
  claimed_at?: string;
  claim_amount?: number;
  forfeited?: boolean;
  eligible_relationship_id?: string;
  eligible_trader_name?: string;
  current_allocation?: string;
  bonus_locked_until?: string;
  is_vested?: boolean;
}

function RewardsHub() {
  const { user } = useAuth();
  const [currentVolume, setCurrentVolume] = useState(0);
  const [totalReferrals, setTotalReferrals] = useState(0);
  const [qualifiedReferrals, setQualifiedReferrals] = useState(0);
  const [totalTrades, setTotalTrades] = useState(0);
  const [totalEarned, setTotalEarned] = useState(0);
  const [pendingRewards, setPendingRewards] = useState<any[]>([]);
  const [claimedTaskIds, setClaimedTaskIds] = useState<Set<string>>(new Set());
  const [feeRebatesTotal, setFeeRebatesTotal] = useState(0);
  const [feeRebatesUsed, setFeeRebatesUsed] = useState(0);
  const [feeRebatesAvailable, setFeeRebatesAvailable] = useState(0);
  const [loading, setLoading] = useState(true);
  const [notification, setNotification] = useState<{type: 'success' | 'error', message: string} | null>(null);
  const [copyTradingAllocated, setCopyTradingAllocated] = useState(0);
  const [copyBonusStatus, setCopyBonusStatus] = useState<CopyBonusStatus | null>(null);
  const [allTasks] = useState<Task[]>([
    {
      id: 'first_referral',
      title: 'First Referral Bonus',
      description: 'Bring your first active trader onboard - requires $100+ deposit',
      reward: 5,
      rewardType: 'balance',
      target: 1,
      icon: '✨',
      type: 'referral'
    },
    {
      id: 'referral_5',
      title: 'Growing Network Bonus',
      description: 'Invite 5 friends who each deposit $100+ to qualify',
      reward: 25,
      rewardType: 'balance',
      target: 5,
      icon: '🌱',
      type: 'referral'
    },
    {
      id: 'referral_10',
      title: 'Network Champion Bonus',
      description: 'Invite 10 friends who each deposit $100+ to qualify',
      reward: 70,
      rewardType: 'balance',
      target: 10,
      icon: '🏆',
      type: 'referral'
    },
    {
      id: 'first_trade',
      title: 'First Trade Welcome',
      description: 'Complete your first futures trade',
      reward: 3,
      rewardType: 'fee_rebate',
      target: 1,
      icon: '🎯',
      type: 'trade'
    },
    {
      id: 'kyc_trustpilot_bonus',
      title: 'Verification Bonus',
      description: 'Complete KYC verification ($20) + Leave a TrustPilot review ($5) for $25 total',
      reward: 25,
      rewardType: 'locked_bonus',
      target: 1,
      icon: '🎁',
      type: 'external',
      externalLink: '/review-bonus'
    },
    {
      id: 'mobile_app_download',
      title: 'Download Mobile App',
      description: 'Get the Shark Trades mobile app and trade on the go',
      reward: 3,
      rewardType: 'locked_bonus',
      target: 1,
      icon: '📱',
      type: 'external',
      externalLink: 'https://play.google.com/store/apps/details?id=com.sharktrading.app'
    },
    {
      id: 'copy_trading_allocation_v2',
      title: 'Copy Trading Bonus',
      description: 'Start copy trading with 500+ USDT to get 100 USDT added on top. Keep everything after 30 days!',
      reward: 100,
      rewardType: 'locked_bonus',
      target: 500,
      icon: '🚀',
      type: 'volume'
    },
    {
      id: 'volume_10m',
      title: 'Million Dollar Club',
      description: 'Trade $10,000,000 in volume within 30 days',
      reward: 500,
      rewardType: 'fee_rebate',
      target: 10000000,
      icon: '🏆',
      type: 'volume'
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


      const { data: copyRelationshipsData } = await supabase
        .from('copy_relationships')
        .select('initial_balance, bonus_amount')
        .eq('follower_id', user.id)
        .eq('is_mock', false)
        .eq('is_active', true);

      if (copyRelationshipsData && copyRelationshipsData.length > 0) {
        const totalAllocated = copyRelationshipsData.reduce((sum, rel) => {
          const initialBalance = parseFloat(rel.initial_balance || '0');
          const bonusAmount = parseFloat(rel.bonus_amount || '0');
          return sum + (initialBalance - bonusAmount);
        }, 0);
        setCopyTradingAllocated(totalAllocated);
      }

      const { data: bonusStatusData } = await supabase.rpc('get_copy_trading_bonus_status');
      if (bonusStatusData) {
        setCopyBonusStatus(bonusStatusData as CopyBonusStatus);
        if (bonusStatusData.already_claimed) {
          setClaimedTaskIds(prev => new Set([...prev, 'copy_trading_allocation_v2']));
        }
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
        if (bonusStatusData?.already_claimed) {
          claimedIds.add('copy_trading_allocation_v2');
        }
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

      const { count: tradesCount } = await supabase
        .from('futures_positions')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .in('status', ['closed', 'liquidated']);

      if (tradesCount !== null) {
        setTotalTrades(tradesCount);
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
      if (task.id === 'copy_trading_allocation_v2') {
        const { data: result, error } = await supabase.rpc('claim_copy_trading_bonus');

        if (error) {
          throw error;
        }

        if (!result?.success) {
          setNotification({type: 'error', message: result?.error || 'Failed to claim bonus'});
          setTimeout(() => setNotification(null), 3000);
          return;
        }

        const { error: rewardError } = await supabase
          .from('user_rewards')
          .insert({
            user_id: user.id,
            task_type: task.type,
            amount: task.reward.toString(),
            status: 'claimed',
            task_id: task.id,
            reward_type: 'copy_bonus',
            description: `Copy Trading Bonus - ${result.trader_name}`,
            claimed_at: new Date().toISOString()
          });

        if (rewardError) {
          console.error('Reward record error:', rewardError);
        }

        setNotification({type: 'success', message: `100 USDT bonus added to your copy trading with ${result.trader_name}! Locked for 30 days.`});
        setTimeout(() => setNotification(null), 5000);
        setClaimedTaskIds(prev => new Set([...prev, task.id]));
        loadUserStats();
        return;
      }

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
      } else if (task.rewardType === 'locked_bonus') {
        const bonusTypeMap: Record<string, string> = {
          'copy_trading_allocation_v2': 'Copy Trading Wallet Bonus V2',
          'first_referral': 'First Referral Bonus',
          'referral_5': 'Growing Network Bonus',
          'referral_10': 'Network Champion Bonus',
          'trustpilot_review': 'Reward Task Bonus'
        };
        const bonusTypeName = bonusTypeMap[task.id] || 'Reward Task Bonus';

        const { data: bonusType } = await supabase
          .from('bonus_types')
          .select('id')
          .eq('name', bonusTypeName)
          .maybeSingle();

        if (!bonusType) {
          throw new Error('Bonus type not found');
        }

        const { error: bonusError } = await supabase.rpc('award_locked_bonus', {
          p_user_id: user.id,
          p_bonus_type_id: bonusType.id,
          p_amount: task.reward,
          p_awarded_by: null,
          p_notes: task.title,
          p_expiry_days: 7
        });

        if (bonusError) {
          console.error('Locked bonus error:', bonusError);
          throw bonusError;
        }
      } else {
        const { data: wallet, error: walletFetchError } = await supabase
          .from('wallets')
          .select('*')
          .eq('user_id', user.id)
          .eq('currency', 'USDT')
          .eq('wallet_type', 'main')
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
            .eq('wallet_type', 'main');

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
              wallet_type: 'main',
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

      const rewardTypeLabel = task.rewardType === 'fee_rebate'
        ? 'Fee Rebate'
        : task.rewardType === 'locked_bonus'
        ? 'Locked Trading Bonus'
        : 'Balance Reward';
      await supabase
        .from('notifications')
        .insert({
          user_id: user.id,
          type: 'reward_claimed',
          title: `Reward Claimed: ${task.title}`,
          message: `You've successfully claimed $${task.reward} USDT ${rewardTypeLabel}!`,
          read: false
        });

      const rewardTypeText = task.rewardType === 'fee_rebate'
        ? 'fee rebate'
        : task.rewardType === 'locked_bonus'
        ? 'locked trading bonus'
        : 'balance reward';
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

  const tasks = allTasks;

  const completedTasks = tasks.filter(task => {
    if (task.id === 'copy_trading_allocation_v2') {
      return copyBonusStatus?.eligible || copyBonusStatus?.already_claimed;
    }
    let progress = 0;
    if (task.type === 'volume') {
      progress = currentVolume;
    } else if (task.type === 'referral') {
      progress = (task.id === 'referral_5' || task.id === 'referral_10') ? qualifiedReferrals : totalReferrals;
    } else if (task.type === 'trade') {
      if (task.id === 'first_trade') progress = totalTrades;
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
              let isCompleted = false;
              let isCopyTradingTask = task.id === 'copy_trading_allocation_v2';

              if (isCopyTradingTask) {
                isCompleted = copyBonusStatus?.eligible || copyBonusStatus?.already_claimed || false;
                progress = copyBonusStatus?.eligible || copyBonusStatus?.already_claimed ? task.target : copyTradingAllocated;
              } else if (task.type === 'volume') {
                progress = currentVolume;
                isCompleted = progress >= task.target;
              } else if (task.type === 'referral') {
                if (task.id === 'referral_5' || task.id === 'referral_10') {
                  progress = qualifiedReferrals;
                } else {
                  progress = totalReferrals;
                }
                isCompleted = progress >= task.target;
              } else if (task.type === 'trade') {
                if (task.id === 'first_trade') {
                  progress = totalTrades;
                }
                isCompleted = progress >= task.target;
              } else if (task.type === 'external') {
                isCompleted = false;
                progress = 0;
              }
              const percentage = Math.min((progress / task.target) * 100, 100);
              const isClaimed = claimedTaskIds.has(task.id);
              const isForfeited = isCopyTradingTask && copyBonusStatus?.forfeited;
              const isExternalTask = task.type === 'external';

              return (
                <div key={task.id} className={`bg-[#181a20] rounded-lg p-4 transition-all ${
                  isClaimed ? 'opacity-60' : 'hover:bg-[#1e2329]'
                }`}>
                  <div className="flex items-start justify-between mb-3">
                    <div className="text-3xl">{task.icon}</div>
                    <div className="text-right">
                      <div className={`text-xs px-2 py-1 rounded font-medium mb-1 ${
                        isForfeited
                          ? 'bg-[#f6465d]/10 text-[#f6465d]'
                          : isClaimed
                          ? 'bg-[#848e9c]/10 text-[#848e9c]'
                          : 'bg-[#0ecb81]/10 text-[#0ecb81]'
                      }`}>
                        {isForfeited ? 'Forfeited' : isClaimed ? 'Claimed' : `+$${task.reward} USDT`}
                      </div>
                      <div className="text-[10px] text-[#848e9c]">
                        {task.rewardType === 'fee_rebate' ? 'Fee Rebate' : task.rewardType === 'locked_bonus' ? 'Locked Bonus' : 'Instant Withdrawal'}
                      </div>
                    </div>
                  </div>

                  <h3 className="text-sm font-medium text-white mb-1">{task.title}</h3>
                  <p className="text-xs text-[#848e9c] mb-2">{task.description}</p>

                  {!isClaimed && !isExternalTask && (
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

                  {isExternalTask && !isClaimed ? (
                    <div className="space-y-2">
                      <a
                        href={task.externalLink}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="w-full text-xs font-medium py-2 rounded transition-all bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] flex items-center justify-center gap-2"
                      >
                        <ExternalLink className="w-3.5 h-3.5" />
                        {task.id === 'mobile_app_download' ? 'Download App' : 'Leave a Review'}
                      </a>
                      <p className="text-[10px] text-[#848e9c] text-center">
                        {task.id === 'mobile_app_download'
                          ? 'After downloading, contact support with a screenshot to claim your bonus'
                          : 'After leaving your review, contact support with your Trustpilot username to claim your bonus'}
                      </p>
                    </div>
                  ) : (
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
                      {isForfeited ? 'Bonus Forfeited' : isClaimed ? 'Claimed' : isCompleted ? 'Claim Reward' : `${percentage.toFixed(0)}% Complete`}
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        <div className="bg-[#2b3139] rounded-lg p-6">
          <h2 className="text-xl font-medium text-white mb-4">How Rewards Work</h2>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            <div className="bg-[#181a20] rounded-lg p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="text-3xl">🤝</div>
                <h3 className="text-base font-medium text-[#eaecef]">Referral Bonuses</h3>
              </div>
              <p className="text-sm text-[#848e9c] mb-3">$5 for your first referral, $25 for 5 referrals, $70 for 10 referrals. Referrals must deposit $100+ to qualify.</p>
              <div className="text-xs text-[#0ecb81]">Instant withdrawal - goes directly to your wallet</div>
            </div>

            <div className="bg-[#181a20] rounded-lg p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="text-3xl">🚀</div>
                <h3 className="text-base font-medium text-[#eaecef]">Copy Trading Bonus</h3>
              </div>
              <p className="text-sm text-[#848e9c] mb-3">Start copy trading with 500+ USDT and we add $100 on top! After 30 days, keep everything including profits.</p>
              <div className="text-xs text-[#f6465d]">Early withdrawal forfeits the bonus portion only</div>
            </div>

            <div className="bg-[#181a20] rounded-lg p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="text-3xl">🎟️</div>
                <h3 className="text-base font-medium text-[#eaecef]">Fee Rebates</h3>
              </div>
              <p className="text-sm text-[#848e9c] mb-3">Credits that automatically reduce your trading fees on every trade.</p>
              <div className="text-xs text-[#fcd535]">Earned from: First Trade, Million Dollar Club</div>
            </div>
          </div>

          <div className="bg-[#0ecb81]/10 border border-[#0ecb81]/20 rounded-lg p-4">
            <div className="flex items-start gap-3">
              <div className="text-2xl">💡</div>
              <div className="text-sm text-[#eaecef]">
                <p className="font-medium mb-2">Quick Tips:</p>
                <ul className="space-y-1 text-xs text-[#848e9c]">
                  <li>• Referral bonuses go directly to your wallet - instantly withdrawable!</li>
                  <li>• Referrals must deposit $100+ to qualify for your bonus</li>
                  <li>• Copy Trading bonus: 100 USDT added ON TOP of your 500+ USDT allocation</li>
                  <li>• After 30 days, the bonus vests and you keep everything including profits</li>
                  <li>• One-time bonus per account, applies to your first eligible copy trading</li>
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
