import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { useNavigation } from '../App';
import { ArrowLeft, TrendingUp, TrendingDown, X, Bell, ChevronRight, Wallet, Target, Percent, BarChart3, Clock, DollarSign, Activity, AlertTriangle, Info, Zap, Plus, ToggleLeft, ToggleRight, Timer, Shield, CheckCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../hooks/useToast';
import { ToastContainer } from '../components/Toast';
import PendingTradeCard from '../components/PendingTradeCard';
import AddFundsToCopyModal from '../components/AddFundsToCopyModal';

interface Trade {
  id: string;
  symbol: string;
  side: 'long' | 'short';
  entry_price: number;
  exit_price: number | null;
  quantity: number;
  leverage: number;
  pnl: number | null;
  realized_pnl: number | null;
  pnl_percentage: number | null;
  pnl_percent: number | null;
  status: 'open' | 'closed';
  opened_at: string;
  closed_at: string | null;
}

interface PendingTrade {
  id: string;
  trader_id: string;
  pair: string;
  side: 'long' | 'short';
  entry_price: number;
  quantity: number;
  leverage: number;
  margin_used: number;
  margin_percentage: number;
  expires_at: string;
  notes: string | null;
  trader_name: string;
  trader_avatar: string;
}

interface MyAllocation {
  id: string;
  allocated_amount: number;
  realized_pnl: number;
  pnl_percentage: number;
  status: 'open' | 'closed';
  created_at: string;
  closed_at: string | null;
  side: 'long' | 'short';
  entry_price: number;
  exit_price: number | null;
  follower_leverage: number;
  symbol?: string;
  quantity?: number;
}

interface CopyRelationship {
  id: string;
  trader_id: string;
  allocation_percentage: number;
  leverage: number;
  initial_balance: string;
  current_balance: string;
  cumulative_pnl: string;
  total_pnl: string;
  is_active: boolean;
  is_mock: boolean;
  created_at: string;
  bonus_amount: number;
  bonus_claimed_at: string | null;
  bonus_locked_until: string | null;
  auto_accept_enabled: boolean;
  auto_accept_until: string | null;
  auto_accept_max_leverage: number;
  auto_accept_count: number;
  trader: {
    id: string;
    name: string;
    avatar: string;
    roi_30d: string;
  };
}

function ActiveCopyTrading() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const { toasts, removeToast, showSuccess, showError } = useToast();
  const [selectedCopy, setSelectedCopy] = useState<CopyRelationship | null>(null);
  const [trades, setTrades] = useState<Trade[]>([]);
  const [openTrades, setOpenTrades] = useState<Trade[]>([]);
  const [closedTrades, setClosedTrades] = useState<Trade[]>([]);
  const [myAllocations, setMyAllocations] = useState<MyAllocation[]>([]);
  const [pendingTrades, setPendingTrades] = useState<PendingTrade[]>([]);
  const [loading, setLoading] = useState(true);
  const [showWithdrawModal, setShowWithdrawModal] = useState(false);
  const [showAddFundsModal, setShowAddFundsModal] = useState(false);
  const [withdrawing, setWithdrawing] = useState(false);
  const [withdrawalPreview, setWithdrawalPreview] = useState<{
    isBonusLocked: boolean;
    daysRemaining: number;
    forfeitedAmount: number;
    youWillReceive: number;
    isPromoOnly: boolean;
    hasPromo: boolean;
    promoBonusAmount: number;
    userAllocation: number;
    profit: number;
    userProfit: number;
    platformFee: number;
    hasOpenPositions: boolean;
    openPositionsCount: number;
    openPositions: Array<{
      id: string;
      symbol: string;
      side: string;
      allocated_amount: number;
      entry_price: number;
    }>;
  } | null>(null);
  const [respondingToTrade, setRespondingToTrade] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'positions' | 'history' | 'allocations'>('positions');
  const [showAutoAcceptModal, setShowAutoAcceptModal] = useState(false);
  const [showAutoAcceptConfirm, setShowAutoAcceptConfirm] = useState(false);
  const [togglingAutoAccept, setTogglingAutoAccept] = useState(false);
  const [autoAcceptMaxLeverage, setAutoAcceptMaxLeverage] = useState(50);

  useEffect(() => {
    loadCopyRelationship();
  }, [user]);

  useEffect(() => {
    if (selectedCopy) {
      loadTraderTrades();
      loadMyAllocations();
      loadPendingTrades();

      const interval = setInterval(() => {
        loadTraderTrades();
        loadMyAllocations();
        loadPendingTrades();
        updateBalance();
      }, 5000);

      const expireInterval = setInterval(async () => {
        try {
          await fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/expire-pending-trades`,
            { method: 'POST' }
          );
          loadPendingTrades();
        } catch (error) {
          console.error('Error expiring trades:', error);
        }
      }, 30000);

      return () => {
        clearInterval(interval);
        clearInterval(expireInterval);
      };
    }
  }, [selectedCopy]);

  const loadCopyRelationship = async () => {
    if (!user) return;

    try {
      const urlParams = new URLSearchParams(window.location.search);
      const copyId = urlParams.get('id');

      if (!copyId) {
        navigateTo('copytrading');
        return;
      }

      const { data, error } = await supabase
        .from('copy_relationships')
        .select(`
          id, trader_id, allocation_percentage, leverage, initial_balance,
          current_balance, cumulative_pnl, total_pnl, is_active, is_mock, created_at,
          bonus_amount, bonus_claimed_at, bonus_locked_until,
          auto_accept_enabled, auto_accept_until, auto_accept_max_leverage, auto_accept_count,
          traders:trader_id (id, name, avatar, roi_30d)
        `)
        .eq('id', copyId)
        .eq('follower_id', user.id)
        .maybeSingle();

      if (error) throw error;

      if (!data) {
        showError('Copy relationship not found');
        navigateTo('copytrading');
        return;
      }

      const copyData: CopyRelationship = {
        id: data.id,
        trader_id: data.trader_id,
        allocation_percentage: data.allocation_percentage,
        leverage: data.leverage,
        initial_balance: data.initial_balance || '0',
        current_balance: data.current_balance || '0',
        cumulative_pnl: data.cumulative_pnl || '0',
        total_pnl: data.total_pnl || '0',
        is_active: data.is_active,
        is_mock: data.is_mock || false,
        created_at: data.created_at,
        bonus_amount: parseFloat(data.bonus_amount || '0'),
        bonus_claimed_at: data.bonus_claimed_at,
        bonus_locked_until: data.bonus_locked_until,
        auto_accept_enabled: data.auto_accept_enabled || false,
        auto_accept_until: data.auto_accept_until,
        auto_accept_max_leverage: data.auto_accept_max_leverage || 50,
        auto_accept_count: data.auto_accept_count || 0,
        trader: {
          id: (data.traders as any).id,
          name: (data.traders as any).name,
          avatar: (data.traders as any).avatar,
          roi_30d: (data.traders as any).roi_30d
        }
      };

      setSelectedCopy(copyData);
    } catch (error: any) {
      console.error('Error loading copy relationship:', error);
      showError(error.message || 'Failed to load copy trading details');
    } finally {
      setLoading(false);
    }
  };

  const loadTraderTrades = async () => {
    if (!selectedCopy) return;

    try {
      const { data: openData, error: openError } = await supabase
        .from('trader_trades')
        .select('*')
        .eq('trader_id', selectedCopy.trader_id)
        .eq('status', 'open')
        .gte('opened_at', selectedCopy.created_at)
        .order('opened_at', { ascending: false });

      if (openError) throw openError;
      setOpenTrades(openData || []);

      const { data: closedData, error: closedError } = await supabase
        .from('trader_trades')
        .select('*')
        .eq('trader_id', selectedCopy.trader_id)
        .in('status', ['closed', 'liquidated'])
        .gte('opened_at', selectedCopy.created_at)
        .order('closed_at', { ascending: false })
        .limit(50);

      if (closedError) throw closedError;
      setClosedTrades(closedData || []);
      setTrades(closedData || []);
    } catch (error) {
      console.error('Error loading trades:', error);
    }
  };

  const loadMyAllocations = async () => {
    if (!selectedCopy || !user) return;

    try {
      const { data, error } = await supabase
        .from('copy_trade_allocations')
        .select(`
          *,
          trader_trades:trader_trade_id (symbol)
        `)
        .eq('follower_id', user.id)
        .eq('copy_relationship_id', selectedCopy.id)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const allocationsWithQuantity = (data || []).map(allocation => {
        const quantity = allocation.entry_price > 0
          ? (allocation.allocated_amount * allocation.follower_leverage) / allocation.entry_price
          : 0;

        return {
          ...allocation,
          symbol: allocation.trader_trades?.symbol,
          quantity
        };
      });

      setMyAllocations(allocationsWithQuantity);
    } catch (error) {
      console.error('Error loading allocations:', error);
    }
  };

  const loadPendingTrades = async () => {
    if (!selectedCopy || !user) return;

    try {
      const { data: trades, error: tradesError } = await supabase
        .from('pending_copy_trades')
        .select('*')
        .eq('trader_id', selectedCopy.trader_id)
        .eq('status', 'pending')
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false });

      if (tradesError) throw tradesError;

      if (!trades || trades.length === 0) {
        setPendingTrades([]);
        return;
      }

      const { data: responses, error: responsesError } = await supabase
        .from('pending_trade_responses')
        .select('pending_trade_id')
        .eq('follower_id', user.id)
        .in('pending_trade_id', trades.map(t => t.id));

      if (responsesError) throw responsesError;

      const respondedTradeIds = new Set(
        responses?.map(r => r.pending_trade_id) || []
      );

      const pending: PendingTrade[] = trades
        .filter(trade => !respondedTradeIds.has(trade.id))
        .map(trade => ({
          id: trade.id,
          trader_id: trade.trader_id,
          pair: trade.pair,
          side: trade.side,
          entry_price: parseFloat(trade.entry_price),
          quantity: parseFloat(trade.quantity),
          leverage: trade.leverage,
          margin_used: parseFloat(trade.margin_used),
          margin_percentage: parseFloat(trade.margin_percentage),
          expires_at: trade.expires_at,
          notes: trade.notes,
          trader_name: selectedCopy.trader.name,
          trader_avatar: selectedCopy.trader.avatar
        }));

      setPendingTrades(pending);
    } catch (error) {
      console.error('Error loading pending trades:', error);
    }
  };

  const handleAcceptTrade = async (tradeId: string) => {
    if (!user) return;
    setRespondingToTrade(tradeId);

    try {
      const { error } = await supabase.rpc('respond_to_copy_trade', {
        p_trade_id: tradeId,
        p_follower_id: user.id,
        p_response: 'accepted',
        p_risk_acknowledged: true
      });

      if (error) throw error;

      showSuccess('Trade accepted successfully!');
      loadPendingTrades();
      loadTraderTrades();
      loadMyAllocations();
    } catch (error: any) {
      showError(error.message || 'Failed to accept trade');
    } finally {
      setRespondingToTrade(null);
    }
  };

  const handleDeclineTrade = async (tradeId: string) => {
    if (!user) return;
    setRespondingToTrade(tradeId);

    try {
      const { error } = await supabase.rpc('respond_to_copy_trade', {
        p_trade_id: tradeId,
        p_follower_id: user.id,
        p_response: 'declined',
        p_decline_reason: 'Manual decline'
      });

      if (error) throw error;

      showSuccess('Trade declined');
      loadPendingTrades();
    } catch (error: any) {
      showError(error.message || 'Failed to decline trade');
    } finally {
      setRespondingToTrade(null);
    }
  };

  const updateBalance = async () => {
    if (!selectedCopy || !user) return;

    try {
      const { data: relationshipData, error: relationshipError } = await supabase
        .from('copy_relationships')
        .select('initial_balance, current_balance, cumulative_pnl, total_pnl')
        .eq('id', selectedCopy.id)
        .maybeSingle();

      if (relationshipError) throw relationshipError;

      if (relationshipData) {
        setSelectedCopy(prev => prev ? {
          ...prev,
          initial_balance: relationshipData.initial_balance || '0',
          current_balance: relationshipData.current_balance || '0',
          cumulative_pnl: relationshipData.cumulative_pnl || '0',
          total_pnl: relationshipData.total_pnl || '0'
        } : null);
      }
    } catch (error) {
      console.error('Error updating balance:', error);
    }
  };

  const loadWithdrawalPreview = async () => {
    if (!selectedCopy) return;

    try {
      const { data, error } = await supabase.rpc('calculate_copy_trading_early_withdrawal', {
        p_relationship_id: selectedCopy.id
      });

      if (error) throw error;

      if (data?.success) {
        setWithdrawalPreview({
          isBonusLocked: data.is_bonus_locked || false,
          daysRemaining: data.days_remaining || 0,
          forfeitedAmount: data.forfeited_amount || 0,
          youWillReceive: data.you_will_receive || 0,
          isPromoOnly: data.is_promo_only || false,
          hasPromo: data.has_promo || false,
          promoBonusAmount: data.promo_bonus_amount || 0,
          userAllocation: data.user_allocation || 0,
          profit: data.profit || 0,
          userProfit: data.user_profit || 0,
          platformFee: data.platform_fee || 0,
          hasOpenPositions: data.has_open_positions || false,
          openPositionsCount: data.open_positions_count || 0,
          openPositions: data.open_positions || []
        });
      }
    } catch (error) {
      console.error('Error loading withdrawal preview:', error);
    }
  };

  const openWithdrawModal = async () => {
    setShowWithdrawModal(true);
    await loadWithdrawalPreview();
  };

  const handleWithdraw = async () => {
    if (!user || !selectedCopy) return;

    setWithdrawing(true);

    try {
      const { data, error } = await supabase.rpc('stop_and_withdraw_copy_trading', {
        p_relationship_id: selectedCopy.id
      });

      if (error) throw error;

      if (!data?.success) {
        if (data?.error_code === 'OPEN_POSITIONS_EXIST') {
          showError(`Cannot withdraw: You have ${data.open_positions_count} open position(s). Wait for positions to close.`);
          await loadWithdrawalPreview();
          return;
        }
        throw new Error(data?.error || 'Failed to stop copy trading');
      }

      if (data.is_mock) {
        showSuccess(`Mock copy trading with ${selectedCopy.trader.name} has been stopped`);
      } else {
        const withdrawAmount = data.withdraw_amount || 0;
        const platformFee = data.platform_fee || 0;
        const forfeitedAmount = data.forfeited_amount || 0;

        let message = `Successfully withdrawn ${withdrawAmount.toFixed(2)} USDT to your wallet`;
        if (platformFee > 0) {
          message += `. Platform fee: ${platformFee.toFixed(2)} USDT (20% of profits)`;
        }
        if (forfeitedAmount > 0) {
          message += `. Bonus forfeited: ${forfeitedAmount.toFixed(2)} USDT (early withdrawal)`;
        }
        showSuccess(message);
      }

      setShowWithdrawModal(false);

      setTimeout(() => {
        navigateTo('copytrading');
      }, 2000);
    } catch (error: any) {
      console.error('Error withdrawing:', error);
      showError(error.message || 'Failed to withdraw');
    } finally {
      setWithdrawing(false);
    }
  };

  const calculateROI = () => {
    if (!selectedCopy) return '0.00';
    const initial = parseFloat(selectedCopy.initial_balance);
    const current = parseFloat(selectedCopy.current_balance);
    if (initial === 0) return '0.00';
    return (((current - initial) / initial) * 100).toFixed(2);
  };

  const calculateProfit = () => {
    if (!selectedCopy) return 0;
    return parseFloat(selectedCopy.current_balance) - parseFloat(selectedCopy.initial_balance);
  };

  const calculateWithdrawalAmount = () => {
    if (!selectedCopy) return { total: 0, fee: 0, net: 0 };
    const profit = calculateProfit();
    const currentBalance = parseFloat(selectedCopy.current_balance);

    if (profit > 0) {
      const fee = profit * 0.20;
      return {
        total: currentBalance,
        fee: fee,
        net: currentBalance - fee
      };
    }

    return {
      total: currentBalance,
      fee: 0,
      net: currentBalance
    };
  };

  const getDaysSinceCopying = () => {
    if (!selectedCopy) return 0;
    const start = new Date(selectedCopy.created_at);
    const now = new Date();
    const diffTime = Math.abs(now.getTime() - start.getTime());
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  };

  const getAutoAcceptTimeRemaining = () => {
    if (!selectedCopy?.auto_accept_until) return null;
    const until = new Date(selectedCopy.auto_accept_until);
    const now = new Date();
    const diff = until.getTime() - now.getTime();
    if (diff <= 0) return null;
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  };

  const isAutoAcceptActive = () => {
    if (!selectedCopy?.auto_accept_enabled || !selectedCopy?.auto_accept_until) return false;
    return new Date(selectedCopy.auto_accept_until) > new Date();
  };

  const handleToggleAutoAccept = async (enable: boolean) => {
    if (!selectedCopy || togglingAutoAccept) return;
    setTogglingAutoAccept(true);
    try {
      const { data, error } = await supabase.rpc('toggle_auto_accept', {
        p_relationship_id: selectedCopy.id,
        p_enable: enable,
        p_max_leverage: autoAcceptMaxLeverage
      });
      if (error) throw error;
      if (data?.success) {
        setSelectedCopy(prev => prev ? {
          ...prev,
          auto_accept_enabled: enable,
          auto_accept_until: enable ? data.auto_accept_until : null,
          auto_accept_max_leverage: enable ? data.max_leverage : prev.auto_accept_max_leverage,
          auto_accept_count: enable ? 0 : prev.auto_accept_count
        } : null);
        if (enable) {
          showSuccess('Auto-accept enabled for 24 hours');
        } else {
          showSuccess('Auto-accept disabled');
        }
        setShowAutoAcceptModal(false);
        setShowAutoAcceptConfirm(false);
      } else {
        throw new Error(data?.error || 'Failed to toggle auto-accept');
      }
    } catch (error: any) {
      console.error('Error toggling auto-accept:', error);
      showError(error.message || 'Failed to toggle auto-accept');
    } finally {
      setTogglingAutoAccept(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0b0e11] text-white">
        <Navbar />
        <div className="flex items-center justify-center py-20">
          <div className="animate-spin w-12 h-12 border-4 border-[#f0b90b] border-t-transparent rounded-full"></div>
        </div>
      </div>
    );
  }

  if (!selectedCopy) {
    return null;
  }

  const roi = calculateROI();
  const profit = calculateProfit();
  const withdrawal = calculateWithdrawalAmount();
  const daysCopying = getDaysSinceCopying();

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />
      <ToastContainer toasts={toasts} removeToast={removeToast} />

      <div className="max-w-[1400px] mx-auto px-4 sm:px-6 py-6">
        <button
          onClick={() => navigateTo('copytrading')}
          className="inline-flex items-center gap-2 text-[#848e9c] hover:text-white transition-colors text-sm mb-6 group"
        >
          <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
          Back to Copy Trading
        </button>

        <div className="bg-gradient-to-r from-[#1e2329] to-[#252930] rounded-2xl border border-[#2b3139] overflow-hidden mb-6">
          <div className="p-6 sm:p-8">
            <div className="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-6">
              <div className="flex items-start gap-4">
                <div
                  className="text-5xl cursor-pointer hover:scale-110 transition-transform"
                  onClick={() => {
                    window.history.pushState({}, '', `?page=traderprofile&id=${selectedCopy.trader_id}`);
                    navigateTo('traderprofile');
                  }}
                >
                  {selectedCopy.trader.avatar}
                </div>
                <div>
                  <div className="flex items-center gap-3 mb-1">
                    <h1
                      className="text-2xl sm:text-3xl font-bold cursor-pointer hover:text-[#f0b90b] transition-colors"
                      onClick={() => {
                        window.history.pushState({}, '', `?page=traderprofile&id=${selectedCopy.trader_id}`);
                        navigateTo('traderprofile');
                      }}
                    >
                      {selectedCopy.trader.name}
                    </h1>
                    {selectedCopy.is_mock && (
                      <span className="px-2.5 py-1 bg-blue-500/20 text-blue-400 text-xs font-medium rounded-full border border-blue-500/30">
                        MOCK
                      </span>
                    )}
                    {selectedCopy.is_active && (
                      <span className="px-2.5 py-1 bg-[#0ecb81]/20 text-[#0ecb81] text-xs font-medium rounded-full border border-[#0ecb81]/30 flex items-center gap-1">
                        <span className="w-1.5 h-1.5 bg-[#0ecb81] rounded-full animate-pulse"></span>
                        ACTIVE
                      </span>
                    )}
                    {selectedCopy.bonus_amount > 0 && (
                      <span className={`px-2.5 py-1 text-xs font-medium rounded-full flex items-center gap-1 ${
                        selectedCopy.bonus_locked_until && new Date(selectedCopy.bonus_locked_until) > new Date()
                          ? 'bg-[#f0b90b]/20 text-[#f0b90b] border border-[#f0b90b]/30'
                          : 'bg-[#0ecb81]/20 text-[#0ecb81] border border-[#0ecb81]/30'
                      }`}>
                        +{selectedCopy.bonus_amount} USDT Bonus
                        {selectedCopy.bonus_locked_until && new Date(selectedCopy.bonus_locked_until) > new Date()
                          ? ` (${Math.ceil((new Date(selectedCopy.bonus_locked_until).getTime() - Date.now()) / (1000 * 60 * 60 * 24))}d lock)`
                          : ' (Vested)'
                        }
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-2 text-[#848e9c] text-sm">
                    <Clock className="w-4 h-4" />
                    <span>Copying for {daysCopying} day{daysCopying !== 1 ? 's' : ''}</span>
                    <span className="text-[#474d57]">|</span>
                    <span>Since {new Date(selectedCopy.created_at).toLocaleDateString()}</span>
                  </div>
                </div>
              </div>

              {selectedCopy.is_active && (
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => setShowAddFundsModal(true)}
                    className="flex items-center justify-center gap-2 bg-gradient-to-r from-[#0ecb81] to-[#0db777] hover:from-[#10d889] hover:to-[#0fc982] text-white px-6 py-3 rounded-xl font-semibold transition-all shadow-lg shadow-[#0ecb81]/20 hover:shadow-[#0ecb81]/30"
                  >
                    <Plus className="w-5 h-5" />
                    Add Funds
                  </button>
                  <button
                    onClick={openWithdrawModal}
                    className="flex items-center justify-center gap-2 bg-gradient-to-r from-[#f6465d] to-[#d93547] hover:from-[#ff4d63] hover:to-[#e03a4c] text-white px-6 py-3 rounded-xl font-semibold transition-all shadow-lg shadow-[#f6465d]/20 hover:shadow-[#f6465d]/30"
                  >
                    <Wallet className="w-5 h-5" />
                    {selectedCopy.is_mock ? 'Stop Mock Copy' : 'Withdraw & Stop'}
                  </button>
                </div>
              )}
            </div>
          </div>

          <div className="grid grid-cols-2 lg:grid-cols-5 gap-px bg-[#2b3139]">
            <div className="bg-[#1e2329] p-4 sm:p-6">
              <div className="flex items-center gap-2 text-[#848e9c] text-xs sm:text-sm mb-2">
                <DollarSign className="w-4 h-4" />
                Initial Balance
              </div>
              <div className="text-white text-lg sm:text-2xl font-bold">
                {parseFloat(selectedCopy.initial_balance).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                <span className="text-[#848e9c] text-sm ml-1">USDT</span>
              </div>
            </div>

            <div className="bg-[#1e2329] p-4 sm:p-6">
              <div className="flex items-center gap-2 text-[#848e9c] text-xs sm:text-sm mb-2">
                <Wallet className="w-4 h-4" />
                Current Balance
              </div>
              <div className="text-white text-lg sm:text-2xl font-bold">
                {parseFloat(selectedCopy.current_balance).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                <span className="text-[#848e9c] text-sm ml-1">USDT</span>
              </div>
            </div>

            <div className="bg-[#1e2329] p-4 sm:p-6">
              <div className="flex items-center gap-2 text-[#848e9c] text-xs sm:text-sm mb-2">
                <BarChart3 className="w-4 h-4" />
                Total PNL
              </div>
              <div className={`text-lg sm:text-2xl font-bold ${profit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                {profit >= 0 ? '+' : ''}{profit.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                <span className="text-sm ml-1">USDT</span>
              </div>
            </div>

            <div className="bg-[#1e2329] p-4 sm:p-6">
              <div className="flex items-center gap-2 text-[#848e9c] text-xs sm:text-sm mb-2">
                <Percent className="w-4 h-4" />
                ROI
              </div>
              <div className={`text-lg sm:text-2xl font-bold ${parseFloat(roi) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                {parseFloat(roi) >= 0 ? '+' : ''}{roi}%
              </div>
            </div>

            <div className="bg-[#1e2329] p-4 sm:p-6 col-span-2 lg:col-span-1">
              <div className="flex items-center gap-2 text-[#848e9c] text-xs sm:text-sm mb-2">
                <Target className="w-4 h-4" />
                Leverage
              </div>
              <div className="text-white text-lg sm:text-2xl font-bold">
                {selectedCopy.leverage}x
              </div>
            </div>
          </div>
        </div>

        {pendingTrades.length > 0 && (
          <div className="mb-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="relative">
                  <Bell className="w-6 h-6 text-[#f0b90b]" />
                  <span className="absolute -top-1 -right-1 w-4 h-4 bg-[#f6465d] rounded-full text-[10px] font-bold flex items-center justify-center">
                    {pendingTrades.length}
                  </span>
                </div>
                <h2 className="text-xl font-bold">Pending Trade Signals</h2>
                <span className="text-[#848e9c] text-sm">Action required</span>
              </div>
              {!selectedCopy.is_mock && (
                <div className="flex items-center gap-3">
                  {isAutoAcceptActive() ? (
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => handleToggleAutoAccept(false)}
                        disabled={togglingAutoAccept}
                        className="flex items-center gap-2 px-4 py-2 bg-[#0ecb81]/10 border border-[#0ecb81]/30 rounded-lg hover:bg-[#0ecb81]/20 transition-all"
                      >
                        <ToggleRight className="w-5 h-5 text-[#0ecb81]" />
                        <span className="text-[#0ecb81] text-sm font-medium">Auto-Accept ON</span>
                      </button>
                      <div className="flex items-center gap-1.5 text-xs text-[#848e9c]">
                        <Timer className="w-3.5 h-3.5" />
                        <span>{getAutoAcceptTimeRemaining()} remaining</span>
                      </div>
                      {selectedCopy.auto_accept_count > 0 && (
                        <span className="text-xs text-[#848e9c]">
                          ({selectedCopy.auto_accept_count} auto-accepted)
                        </span>
                      )}
                    </div>
                  ) : (
                    <button
                      onClick={() => setShowAutoAcceptModal(true)}
                      disabled={togglingAutoAccept}
                      className="flex items-center gap-2 px-4 py-2 bg-[#2b3139] border border-[#474d57] rounded-lg hover:border-[#f0b90b] hover:bg-[#f0b90b]/10 transition-all group"
                    >
                      <ToggleLeft className="w-5 h-5 text-[#848e9c] group-hover:text-[#f0b90b]" />
                      <span className="text-[#848e9c] text-sm font-medium group-hover:text-[#f0b90b]">Enable Auto-Accept</span>
                    </button>
                  )}
                </div>
              )}
            </div>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {pendingTrades.map((trade) => {
                const allocatedAmount = (parseFloat(selectedCopy.current_balance) * trade.margin_percentage) / 100;

                return (
                  <PendingTradeCard
                    key={trade.id}
                    trade={{
                      id: trade.id,
                      trader_id: trade.trader_id,
                      trader_name: trade.trader_name,
                      trader_avatar: trade.trader_avatar,
                      pair: trade.pair,
                      side: trade.side,
                      entry_price: trade.entry_price,
                      quantity: trade.quantity,
                      leverage: trade.leverage,
                      margin_used: trade.margin_used,
                      margin_percentage: trade.margin_percentage,
                      expires_at: trade.expires_at,
                      notes: trade.notes || undefined
                    }}
                    allocatedAmount={allocatedAmount}
                    followerLeverage={trade.leverage * selectedCopy.leverage}
                    onAccept={() => handleAcceptTrade(trade.id)}
                    onDecline={() => handleDeclineTrade(trade.id)}
                    disabled={respondingToTrade === trade.id}
                  />
                );
              })}
            </div>
          </div>
        )}

        <div className="bg-[#1e2329]/50 border border-[#f0b90b]/20 rounded-xl p-4 mb-6">
          <div className="flex items-start gap-3">
            <Info className="w-5 h-5 text-[#f0b90b] flex-shrink-0 mt-0.5" />
            <div className="flex-1">
              <h4 className="text-[#f0b90b] font-semibold text-sm mb-2">Important Information</h4>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs text-[#848e9c]">
                <div className="flex items-start gap-2">
                  <DollarSign className="w-4 h-4 text-[#474d57] flex-shrink-0" />
                  <span>20% platform fee applies only to profits when withdrawing</span>
                </div>
                <div className="flex items-start gap-2">
                  <Clock className="w-4 h-4 text-[#474d57] flex-shrink-0" />
                  <span>Trades shown are from {new Date(selectedCopy.created_at).toLocaleDateString()} onwards</span>
                </div>
                <div className="flex items-start gap-2">
                  <AlertTriangle className="w-4 h-4 text-[#474d57] flex-shrink-0" />
                  <span>Past performance does not guarantee future results</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-[#1e2329] rounded-2xl border border-[#2b3139] overflow-hidden">
          <div className="flex border-b border-[#2b3139]">
            {[
              { key: 'positions', label: 'Live Positions', count: openTrades.length },
              { key: 'history', label: 'Position History', count: closedTrades.length },
              { key: 'allocations', label: 'My Copy Trades', count: myAllocations.length }
            ].map((tab) => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key as typeof activeTab)}
                className={`flex-1 sm:flex-none px-6 py-4 text-sm font-medium transition-all relative ${
                  activeTab === tab.key
                    ? 'text-white bg-[#252930]'
                    : 'text-[#848e9c] hover:text-white hover:bg-[#252930]/50'
                }`}
              >
                <span className="flex items-center justify-center gap-2">
                  {tab.label}
                  {tab.count > 0 && (
                    <span className={`px-2 py-0.5 rounded-full text-xs ${
                      activeTab === tab.key
                        ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                        : 'bg-[#2b3139] text-[#848e9c]'
                    }`}>
                      {tab.count}
                    </span>
                  )}
                </span>
                {activeTab === tab.key && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#f0b90b]" />
                )}
              </button>
            ))}
          </div>

          <div className="p-4 sm:p-6">
            {activeTab === 'positions' && (
              <div>
                {openTrades.length === 0 ? (
                  <div className="text-center py-16">
                    <Activity className="w-16 h-16 text-[#2b3139] mx-auto mb-4" />
                    <h3 className="text-lg font-semibold text-white mb-2">No Open Positions</h3>
                    <p className="text-[#848e9c] text-sm">
                      Waiting for {selectedCopy.trader.name} to open new positions
                    </p>
                  </div>
                ) : (
                  <div className="space-y-2.5 sm:space-y-3">
                    {openTrades.map((position) => (
                      <div
                        key={position.id}
                        className="bg-[#252930] hover:bg-[#2b3139] rounded-lg sm:rounded-xl p-3 sm:p-5 transition-colors border border-[#2b3139] hover:border-[#474d57]"
                      >
                        <div className="flex items-center justify-between mb-2.5 sm:mb-4 gap-2">
                          <div className="flex items-center gap-2 sm:gap-3">
                            <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-lg sm:rounded-xl bg-[#f0b90b]/10 flex items-center justify-center flex-shrink-0">
                              <Zap className="w-4 h-4 sm:w-5 sm:h-5 text-[#f0b90b]" />
                            </div>
                            <div>
                              <div className="text-white font-bold text-sm sm:text-lg">{position.symbol}</div>
                              <div className="flex items-center gap-1.5 mt-0.5">
                                <span className="text-[10px] sm:text-xs text-[#f0b90b] font-bold bg-[#f0b90b]/10 px-1.5 py-0.5 rounded">{position.leverage}x</span>
                              </div>
                            </div>
                          </div>
                          <div className="text-right flex-shrink-0">
                            <div className="text-[9px] sm:text-xs text-[#848e9c]">Opened</div>
                            <div className="text-[10px] sm:text-sm text-white font-medium whitespace-nowrap">
                              {new Date(position.opened_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                            </div>
                          </div>
                        </div>
                        <div className="grid grid-cols-3 gap-1.5 sm:gap-3">
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Entry Price</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">${position.entry_price.toLocaleString(undefined, { maximumFractionDigits: 2 })}</div>
                          </div>
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Quantity</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">{position.quantity.toLocaleString(undefined, { maximumFractionDigits: 2 })}</div>
                          </div>
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Position Size</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">${(position.entry_price * position.quantity).toLocaleString(undefined, { maximumFractionDigits: 0 })}</div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {activeTab === 'history' && (
              <div>
                {closedTrades.length === 0 ? (
                  <div className="text-center py-16">
                    <BarChart3 className="w-16 h-16 text-[#2b3139] mx-auto mb-4" />
                    <h3 className="text-lg font-semibold text-white mb-2">No Closed Positions</h3>
                    <p className="text-[#848e9c] text-sm">
                      Closed positions will appear here
                    </p>
                  </div>
                ) : (
                  <div className="space-y-2.5 sm:space-y-3">
                    {closedTrades.map((position) => (
                      <div
                        key={position.id}
                        className="bg-[#252930] rounded-lg sm:rounded-xl p-3 sm:p-5 border border-[#2b3139]"
                      >
                        <div className="flex items-center justify-between mb-2.5 sm:mb-4 gap-2">
                          <div className="flex items-center gap-1.5 sm:gap-3 flex-wrap">
                            <span className="text-white font-bold text-sm sm:text-lg">{position.symbol}</span>
                            <span className="text-[10px] sm:text-xs text-[#f0b90b] font-bold bg-[#f0b90b]/10 px-1.5 py-0.5 rounded">{position.leverage}x</span>
                          </div>
                          <span className="text-[10px] sm:text-xs text-[#848e9c] flex-shrink-0 whitespace-nowrap">
                            {position.closed_at ? new Date(position.closed_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : 'N/A'}
                          </span>
                        </div>
                        <div className="grid grid-cols-2 gap-1.5 sm:gap-3">
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Entry</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">${position.entry_price.toLocaleString(undefined, { maximumFractionDigits: 2 })}</div>
                          </div>
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Exit</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">${position.exit_price?.toLocaleString(undefined, { maximumFractionDigits: 2 }) || 'N/A'}</div>
                          </div>
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Quantity</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">{position.quantity.toLocaleString(undefined, { maximumFractionDigits: 2 })}</div>
                          </div>
                          <div className={`rounded-md sm:rounded-lg p-2 sm:p-3 ${position.pnl && position.pnl >= 0 ? 'bg-[#0ecb81]/10' : 'bg-[#f6465d]/10'}`}>
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">PNL</div>
                            {position.pnl !== null && position.pnl !== undefined ? (
                              <div className={`font-bold flex flex-col sm:flex-row sm:items-center gap-0.5 ${position.pnl >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                                <span className="flex items-center gap-0.5 sm:gap-1 text-[11px] sm:text-base">
                                  {position.pnl >= 0 ? <TrendingUp className="w-3 h-3 sm:w-4 sm:h-4" /> : <TrendingDown className="w-3 h-3 sm:w-4 sm:h-4" />}
                                  {position.pnl >= 0 ? '+' : ''}{position.pnl.toFixed(2)}
                                </span>
                                {(position.pnl_percent || position.pnl_percentage) && (
                                  <span className="text-[9px] sm:text-xs opacity-75">
                                    ({(position.pnl_percent || position.pnl_percentage || 0) >= 0 ? '+' : ''}{(position.pnl_percent || position.pnl_percentage || 0).toFixed(1)}%)
                                  </span>
                                )}
                              </div>
                            ) : (
                              <div className="text-[#848e9c] text-[11px] sm:text-base">N/A</div>
                            )}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {activeTab === 'allocations' && (
              <div>
                {myAllocations.length === 0 ? (
                  <div className="text-center py-16">
                    <Target className="w-16 h-16 text-[#2b3139] mx-auto mb-4" />
                    <h3 className="text-lg font-semibold text-white mb-2">No Allocations Yet</h3>
                    <p className="text-[#848e9c] text-sm">
                      Your copy trade allocations will appear when you accept trades
                    </p>
                  </div>
                ) : (
                  <div className="space-y-2.5 sm:space-y-3">
                    {myAllocations.map((allocation) => (
                      <div
                        key={allocation.id}
                        className="bg-[#252930] rounded-lg sm:rounded-xl p-3 sm:p-5 border border-[#2b3139]"
                      >
                        <div className="flex items-center justify-between mb-2.5 sm:mb-4 gap-2">
                          <div className="flex items-center gap-1.5 sm:gap-3 flex-wrap">
                            <span className="text-white font-bold text-sm sm:text-lg">{allocation.symbol || 'N/A'}</span>
                            <span className={`text-[10px] sm:text-xs px-1.5 sm:px-2 py-0.5 rounded font-bold ${
                              allocation.status === 'open'
                                ? 'bg-blue-500/10 text-blue-400'
                                : 'bg-[#474d57]/20 text-[#848e9c]'
                            }`}>
                              {allocation.status.toUpperCase()}
                            </span>
                          </div>
                          <span className="text-[10px] sm:text-xs text-[#848e9c] flex-shrink-0 whitespace-nowrap">
                            {allocation.status === 'closed' && allocation.closed_at
                              ? new Date(allocation.closed_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                              : new Date(allocation.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                            }
                          </span>
                        </div>
                        <div className="grid grid-cols-2 gap-1.5 sm:gap-3">
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Allocated</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">{allocation.allocated_amount.toFixed(2)}</div>
                          </div>
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Entry</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">${allocation.entry_price.toLocaleString(undefined, { maximumFractionDigits: 2 })}</div>
                          </div>
                          <div className="bg-[#1e2329] rounded-md sm:rounded-lg p-2 sm:p-3">
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">Exit</div>
                            <div className="text-white font-bold text-[11px] sm:text-base">{allocation.exit_price ? `$${allocation.exit_price.toLocaleString(undefined, { maximumFractionDigits: 2 })}` : '-'}</div>
                          </div>
                          <div className={`rounded-md sm:rounded-lg p-2 sm:p-3 ${
                            allocation.realized_pnl !== null && allocation.realized_pnl >= 0
                              ? 'bg-[#0ecb81]/10'
                              : allocation.realized_pnl !== null
                                ? 'bg-[#f6465d]/10'
                                : 'bg-[#1e2329]'
                          }`}>
                            <div className="text-[#848e9c] text-[9px] sm:text-xs mb-0.5 sm:mb-1 uppercase tracking-wide">PNL</div>
                            {allocation.realized_pnl !== null && allocation.realized_pnl !== undefined && allocation.realized_pnl !== 0 ? (
                              <div className={`font-bold flex flex-col sm:flex-row sm:items-center gap-0.5 ${allocation.realized_pnl >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                                <span className="flex items-center gap-0.5 sm:gap-1 text-[11px] sm:text-base">
                                  {allocation.realized_pnl >= 0 ? <TrendingUp className="w-3 h-3 sm:w-4 sm:h-4" /> : <TrendingDown className="w-3 h-3 sm:w-4 sm:h-4" />}
                                  {allocation.realized_pnl >= 0 ? '+' : ''}{allocation.realized_pnl.toFixed(2)}
                                </span>
                                {allocation.pnl_percentage !== null && allocation.pnl_percentage !== undefined && (
                                  <span className="text-[9px] sm:text-xs opacity-75">
                                    ({allocation.pnl_percentage >= 0 ? '+' : ''}{allocation.pnl_percentage.toFixed(1)}%)
                                  </span>
                                )}
                              </div>
                            ) : allocation.pnl_percentage !== null && allocation.pnl_percentage !== undefined ? (
                              <div className={`flex items-center gap-0.5 sm:gap-1 font-bold text-[11px] sm:text-base ${allocation.pnl_percentage >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                                {allocation.pnl_percentage >= 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                                {allocation.pnl_percentage >= 0 ? '+' : ''}{allocation.pnl_percentage.toFixed(2)}%
                              </div>
                            ) : (
                              <div className="text-[#848e9c] text-[11px] sm:text-base">-</div>
                            )}
                          </div>
                        </div>
                        {allocation.quantity && (
                          <div className="mt-2 pt-2 sm:mt-3 sm:pt-3 border-t border-[#2b3139] flex flex-wrap items-center gap-3 sm:gap-4 text-[10px] sm:text-xs text-[#848e9c]">
                            <span>Qty: {allocation.quantity.toLocaleString(undefined, { maximumFractionDigits: 2 })}</span>
                            <span>Leverage: {allocation.follower_leverage}x</span>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {showWithdrawModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2329] rounded-2xl max-w-md w-full border border-[#2b3139] shadow-2xl">
            <div className="flex items-center justify-between p-6 border-b border-[#2b3139]">
              <h3 className="text-xl font-bold">
                {selectedCopy.is_mock ? 'Stop Mock Copy Trading' : 'Withdraw & Stop'}
              </h3>
              <button
                onClick={() => setShowWithdrawModal(false)}
                className="text-[#848e9c] hover:text-white transition-colors p-1 hover:bg-[#2b3139] rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6">
              {withdrawalPreview?.hasOpenPositions ? (
                <div className="space-y-4">
                  <div className="bg-[#f6465d]/20 border-2 border-[#f6465d] rounded-xl p-5">
                    <div className="flex items-center gap-3 mb-4">
                      <div className="w-12 h-12 bg-[#f6465d]/20 rounded-full flex items-center justify-center">
                        <AlertTriangle className="w-6 h-6 text-[#f6465d]" />
                      </div>
                      <div>
                        <h4 className="text-[#f6465d] font-bold text-lg">Cannot Withdraw Yet</h4>
                        <p className="text-sm text-[#848e9c]">
                          You have {withdrawalPreview.openPositionsCount} open position{withdrawalPreview.openPositionsCount !== 1 ? 's' : ''}
                        </p>
                      </div>
                    </div>
                    <p className="text-sm text-white mb-4">
                      You cannot stop copy trading or withdraw funds while you have active positions. Please wait for all positions to be closed by the trader.
                    </p>
                    <div className="bg-[#0b0e11] rounded-lg p-3 space-y-2">
                      <div className="text-xs text-[#848e9c] font-semibold uppercase mb-2">Open Positions</div>
                      {withdrawalPreview.openPositions.map((pos, idx) => (
                        <div key={pos.id || idx} className="flex items-center justify-between text-sm">
                          <span className="text-white font-medium">{pos.symbol}</span>
                          <span className="text-[#848e9c]">${pos.allocated_amount?.toFixed(2)} allocated</span>
                        </div>
                      ))}
                    </div>
                  </div>
                  <div className="bg-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-xl p-4 flex items-start gap-3">
                    <Info className="w-5 h-5 text-[#f0b90b] flex-shrink-0 mt-0.5" />
                    <p className="text-xs text-[#f0b90b]">
                      Positions will be closed when the trader closes them. Check back once all positions are settled.
                    </p>
                  </div>
                </div>
              ) : selectedCopy.is_mock ? (
                <div className="space-y-4">
                  <div className="bg-[#0b0e11] rounded-xl p-5">
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-[#848e9c]">Mock Balance</span>
                      <span className="text-white text-xl font-bold">
                        {parseFloat(selectedCopy.current_balance).toFixed(2)} USDT
                      </span>
                    </div>
                    <div className="flex items-center justify-between mb-3 pb-3 border-b border-[#2b3139]">
                      <span className="text-[#848e9c] text-sm">Initial Balance</span>
                      <span className="text-[#848e9c] text-sm">
                        {parseFloat(selectedCopy.initial_balance).toFixed(2)} USDT
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-[#848e9c] text-sm">Mock P&L</span>
                      <span className={`font-semibold ${profit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                        {profit >= 0 ? '+' : ''}{profit.toFixed(2)} USDT
                      </span>
                    </div>
                  </div>

                  <div className="bg-blue-500/10 border border-blue-500/30 rounded-xl p-4">
                    <p className="text-sm text-blue-400">
                      This is mock copy trading with virtual funds. Stopping will end your session with {selectedCopy.trader.name}.
                    </p>
                  </div>
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="bg-[#0b0e11] rounded-xl p-5">
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-[#848e9c]">Current Balance</span>
                      <span className="text-white text-xl font-bold">
                        {withdrawal.total.toFixed(2)} USDT
                      </span>
                    </div>
                    <div className="flex items-center justify-between mb-3 pb-3 border-b border-[#2b3139]">
                      <span className="text-[#848e9c] text-sm">Initial Balance</span>
                      <span className="text-[#848e9c] text-sm">
                        {parseFloat(selectedCopy.initial_balance).toFixed(2)} USDT
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-[#848e9c] text-sm">Total P&L</span>
                      <span className={`font-semibold ${profit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                        {profit >= 0 ? '+' : ''}{profit.toFixed(2)} USDT
                      </span>
                    </div>
                  </div>

                  {/* PROMO BONUS ONLY: Early withdrawal - LOSE ALL */}
                  {withdrawalPreview?.hasPromo && withdrawalPreview.isPromoOnly && withdrawalPreview.isBonusLocked && (
                    <div className="bg-[#f6465d]/20 border-2 border-[#f6465d] rounded-xl p-4">
                      <div className="flex items-center gap-2 mb-3">
                        <AlertTriangle className="w-5 h-5 text-[#f6465d]" />
                        <span className="text-[#f6465d] font-bold">WARNING: Early Withdrawal</span>
                      </div>
                      <p className="text-sm text-white mb-3">
                        Your ${withdrawalPreview.promoBonusAmount} promo bonus has <span className="text-[#f6465d] font-bold">{withdrawalPreview.daysRemaining} days</span> remaining.
                      </p>
                      <p className="text-sm text-[#f6465d] font-semibold mb-2">
                        If you withdraw now, you will lose ALL funds:
                      </p>
                      <div className="bg-[#f6465d]/10 rounded-lg p-3">
                        <div className="flex items-center justify-between">
                          <span className="text-[#848e9c] text-sm">Amount forfeited</span>
                          <span className="text-[#f6465d] font-bold">-{withdrawalPreview.forfeitedAmount.toFixed(2)} USDT</span>
                        </div>
                      </div>
                      <p className="text-xs text-[#848e9c] mt-3">
                        Wait {withdrawalPreview.daysRemaining} more days to keep your profits.
                      </p>
                    </div>
                  )}

                  {/* PROMO + USER FUNDS: Early withdrawal - lose promo, keep user funds */}
                  {withdrawalPreview?.hasPromo && !withdrawalPreview.isPromoOnly && withdrawalPreview.isBonusLocked && (
                    <div className="bg-[#f0b90b]/20 border-2 border-[#f0b90b] rounded-xl p-4">
                      <div className="flex items-center gap-2 mb-3">
                        <AlertTriangle className="w-5 h-5 text-[#f0b90b]" />
                        <span className="text-[#f0b90b] font-bold">Early Withdrawal Notice</span>
                      </div>
                      <p className="text-sm text-white mb-3">
                        Your ${withdrawalPreview.promoBonusAmount} promo bonus has <span className="text-[#f0b90b] font-bold">{withdrawalPreview.daysRemaining} days</span> remaining.
                      </p>
                      <p className="text-sm text-[#848e9c] mb-3">
                        If you withdraw now, the promo bonus will be forfeited but you keep your own funds:
                      </p>
                      <div className="space-y-2 bg-[#1e2329] rounded-lg p-3">
                        <div className="flex items-center justify-between text-sm">
                          <span className="text-[#848e9c]">Your funds</span>
                          <span className="text-white font-semibold">{withdrawalPreview.userAllocation.toFixed(2)} USDT</span>
                        </div>
                        <div className="flex items-center justify-between text-sm">
                          <span className="text-[#848e9c]">Your profit share</span>
                          <span className={withdrawalPreview.userProfit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}>
                            {withdrawalPreview.userProfit >= 0 ? '+' : ''}{withdrawalPreview.userProfit.toFixed(2)} USDT
                          </span>
                        </div>
                        {withdrawalPreview.platformFee > 0 && (
                          <div className="flex items-center justify-between text-sm">
                            <span className="text-[#848e9c]">Platform fee (20%)</span>
                            <span className="text-[#f6465d]">-{withdrawalPreview.platformFee.toFixed(2)} USDT</span>
                          </div>
                        )}
                        <div className="border-t border-[#2b3139] pt-2 mt-2">
                          <div className="flex items-center justify-between text-sm">
                            <span className="text-[#f6465d]">Promo bonus forfeited</span>
                            <span className="text-[#f6465d] font-bold">-{withdrawalPreview.promoBonusAmount.toFixed(2)} USDT</span>
                          </div>
                        </div>
                      </div>
                      <p className="text-xs text-[#848e9c] mt-3">
                        Wait {withdrawalPreview.daysRemaining} more days to keep the promo bonus profits too.
                      </p>
                    </div>
                  )}

                  {/* PROMO ONLY: 30 days passed - bonus expires, keep profits */}
                  {withdrawalPreview?.hasPromo && withdrawalPreview.isPromoOnly && !withdrawalPreview.isBonusLocked && (
                    <div className="bg-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-xl p-4">
                      <div className="flex items-center gap-2 mb-3">
                        <Info className="w-5 h-5 text-[#f0b90b]" />
                        <span className="text-[#f0b90b] font-semibold">Promo Bonus Period Complete</span>
                      </div>
                      <p className="text-sm text-[#848e9c] mb-3">
                        Your ${withdrawalPreview.promoBonusAmount} promo bonus period has ended. The bonus will expire but you keep your profits.
                      </p>
                      <div className="space-y-2">
                        <div className="flex items-center justify-between text-sm">
                          <span className="text-[#848e9c]">Promo bonus (expires)</span>
                          <span className="text-[#f6465d]">-{withdrawalPreview.promoBonusAmount.toFixed(2)} USDT</span>
                        </div>
                        <div className="flex items-center justify-between text-sm">
                          <span className="text-[#848e9c]">Your profits</span>
                          <span className={withdrawalPreview.profit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}>
                            {withdrawalPreview.profit >= 0 ? '+' : ''}{withdrawalPreview.profit.toFixed(2)} USDT
                          </span>
                        </div>
                        {withdrawalPreview.platformFee > 0 && (
                          <div className="flex items-center justify-between text-sm">
                            <span className="text-[#848e9c]">Platform fee (20%)</span>
                            <span className="text-[#f6465d]">-{withdrawalPreview.platformFee.toFixed(2)} USDT</span>
                          </div>
                        )}
                      </div>
                    </div>
                  )}

                  {/* PROMO + USER FUNDS: 30 days passed - bonus expires, keep user funds + all profits */}
                  {withdrawalPreview?.hasPromo && !withdrawalPreview.isPromoOnly && !withdrawalPreview.isBonusLocked && (
                    <div className="bg-[#0ecb81]/10 border border-[#0ecb81]/30 rounded-xl p-4">
                      <div className="flex items-center gap-2 mb-3">
                        <Info className="w-5 h-5 text-[#0ecb81]" />
                        <span className="text-[#0ecb81] font-semibold">Promo Period Complete!</span>
                      </div>
                      <p className="text-sm text-[#848e9c] mb-3">
                        Your promo bonus period has ended. The ${withdrawalPreview.promoBonusAmount} bonus expires but you keep all profits!
                      </p>
                      <div className="space-y-2">
                        <div className="flex items-center justify-between text-sm">
                          <span className="text-[#848e9c]">Your funds</span>
                          <span className="text-white font-semibold">{withdrawalPreview.userAllocation.toFixed(2)} USDT</span>
                        </div>
                        <div className="flex items-center justify-between text-sm">
                          <span className="text-[#848e9c]">Total profits (all positions)</span>
                          <span className={withdrawalPreview.profit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}>
                            {withdrawalPreview.profit >= 0 ? '+' : ''}{withdrawalPreview.profit.toFixed(2)} USDT
                          </span>
                        </div>
                        {withdrawalPreview.platformFee > 0 && (
                          <div className="flex items-center justify-between text-sm">
                            <span className="text-[#848e9c]">Platform fee (20%)</span>
                            <span className="text-[#f6465d]">-{withdrawalPreview.platformFee.toFixed(2)} USDT</span>
                          </div>
                        )}
                        <div className="border-t border-[#2b3139] pt-2 mt-2">
                          <div className="flex items-center justify-between text-sm">
                            <span className="text-[#848e9c]">Promo bonus (expires)</span>
                            <span className="text-[#f6465d]">-{withdrawalPreview.promoBonusAmount.toFixed(2)} USDT</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Standard platform fee for non-promo */}
                  {!withdrawalPreview?.hasPromo && withdrawal.fee > 0 && (
                    <div className="bg-[#f6465d]/10 border border-[#f6465d]/30 rounded-xl p-4">
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-[#848e9c] text-sm">Platform Fee (20% of profit)</span>
                        <span className="text-[#f6465d] font-semibold">
                          -{withdrawal.fee.toFixed(2)} USDT
                        </span>
                      </div>
                      <p className="text-xs text-[#848e9c]">
                        We charge 20% on profits made through copy trading
                      </p>
                    </div>
                  )}

                  {/* Standard bonus forfeiture warning (for $500+ bonus, not promo) */}
                  {!withdrawalPreview?.hasPromo && withdrawalPreview?.isBonusLocked && withdrawalPreview.forfeitedAmount > 0 && (
                    <div className="bg-[#f6465d]/10 border border-[#f6465d]/30 rounded-xl p-4">
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-[#848e9c] text-sm">Bonus Forfeiture (Early Withdrawal)</span>
                        <span className="text-[#f6465d] font-semibold">
                          -{withdrawalPreview.forfeitedAmount.toFixed(2)} USDT
                        </span>
                      </div>
                      <p className="text-xs text-[#f6465d]">
                        Your bonus is locked for {withdrawalPreview.daysRemaining} more days. Withdrawing now forfeits the bonus portion and its proportional profits.
                      </p>
                    </div>
                  )}

                  {!withdrawalPreview?.hasPromo && selectedCopy.bonus_amount > 0 && selectedCopy.bonus_locked_until && new Date(selectedCopy.bonus_locked_until) <= new Date() && (
                    <div className="bg-[#0ecb81]/10 border border-[#0ecb81]/30 rounded-xl p-4">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-[#0ecb81] font-semibold">Bonus Vested!</span>
                      </div>
                      <p className="text-xs text-[#848e9c]">
                        Your {selectedCopy.bonus_amount} USDT bonus has fully vested. You keep everything including profits!
                      </p>
                    </div>
                  )}

                  <div className={`rounded-xl p-5 ${
                    withdrawalPreview?.youWillReceive === 0
                      ? 'bg-[#f6465d]/10 border border-[#f6465d]/30'
                      : 'bg-[#0ecb81]/10 border border-[#0ecb81]/30'
                  }`}>
                    <div className="text-sm text-[#848e9c] mb-1">You will receive</div>
                    <div className={`text-3xl font-bold ${
                      withdrawalPreview?.youWillReceive === 0 ? 'text-[#f6465d]' : 'text-[#0ecb81]'
                    }`}>
                      {withdrawalPreview ? withdrawalPreview.youWillReceive.toFixed(2) : withdrawal.net.toFixed(2)} USDT
                    </div>
                  </div>

                  <div className="bg-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-xl p-4 flex items-start gap-3">
                    <AlertTriangle className="w-5 h-5 text-[#f0b90b] flex-shrink-0 mt-0.5" />
                    <p className="text-xs text-[#f0b90b]">
                      This will stop copying {selectedCopy.trader.name} and withdraw all funds to your wallet. This action cannot be undone.
                    </p>
                  </div>
                </div>
              )}

              {withdrawalPreview?.hasOpenPositions ? (
                <button
                  onClick={() => setShowWithdrawModal(false)}
                  className="w-full mt-6 bg-[#2b3139] hover:bg-[#363d47] text-white font-bold py-4 rounded-xl transition-all"
                >
                  Close
                </button>
              ) : (
                <button
                  onClick={handleWithdraw}
                  disabled={withdrawing}
                  className="w-full mt-6 bg-gradient-to-r from-[#f6465d] to-[#d93547] hover:from-[#ff4d63] hover:to-[#e03a4c] disabled:from-[#474d57] disabled:to-[#474d57] disabled:cursor-not-allowed text-white font-bold py-4 rounded-xl transition-all"
                >
                  {withdrawing ? (
                    <span className="flex items-center justify-center gap-2">
                      <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      Processing...
                    </span>
                  ) : (
                    selectedCopy.is_mock ? 'Stop Mock Copy Trading' : 'Confirm Withdrawal'
                  )}
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {showAddFundsModal && selectedCopy && (
        <AddFundsToCopyModal
          isOpen={showAddFundsModal}
          onClose={() => setShowAddFundsModal(false)}
          relationshipId={selectedCopy.id}
          traderName={selectedCopy.trader.name}
          currentInitialBalance={parseFloat(selectedCopy.initial_balance)}
          currentBalance={parseFloat(selectedCopy.current_balance)}
          isMock={selectedCopy.is_mock}
          onSuccess={() => {
            showSuccess('Funds added successfully!');
            loadCopyRelationship();
            updateBalance();
          }}
        />
      )}

      {showAutoAcceptModal && selectedCopy && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2329] rounded-2xl max-w-md w-full border border-[#2b3139] shadow-2xl">
            <div className="flex items-center justify-between p-6 border-b border-[#2b3139]">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-[#f0b90b]/20 rounded-xl flex items-center justify-center">
                  <Zap className="w-5 h-5 text-[#f0b90b]" />
                </div>
                <h3 className="text-xl font-bold">Enable Auto-Accept</h3>
              </div>
              <button
                onClick={() => setShowAutoAcceptModal(false)}
                className="text-[#848e9c] hover:text-white transition-colors p-1 hover:bg-[#2b3139] rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-5">
              <div className="bg-[#0b0e11] rounded-xl p-4 border border-[#2b3139]">
                <div className="flex items-center gap-3 mb-3">
                  <Timer className="w-5 h-5 text-[#f0b90b]" />
                  <span className="text-white font-semibold">24-Hour Auto-Accept</span>
                </div>
                <p className="text-sm text-[#848e9c] leading-relaxed">
                  Trade signals from {selectedCopy.trader.name} will be automatically accepted for the next 24 hours.
                </p>
              </div>

              <div className="space-y-3">
                <label className="block text-sm font-medium text-[#848e9c]">
                  Maximum Leverage Limit
                </label>
                <div className="relative">
                  <select
                    value={autoAcceptMaxLeverage}
                    onChange={(e) => setAutoAcceptMaxLeverage(Number(e.target.value))}
                    className="w-full bg-[#0b0e11] border border-[#2b3139] rounded-xl px-4 py-3 text-white appearance-none cursor-pointer focus:border-[#f0b90b] focus:outline-none"
                  >
                    <option value={10}>Up to 10x leverage</option>
                    <option value={20}>Up to 20x leverage</option>
                    <option value={50}>Up to 50x leverage</option>
                    <option value={75}>Up to 75x leverage</option>
                    <option value={100}>Up to 100x leverage</option>
                    <option value={125}>All trades (up to 125x)</option>
                  </select>
                  <ChevronRight className="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-[#848e9c] rotate-90 pointer-events-none" />
                </div>
              </div>

              <div className="bg-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-xl p-4 space-y-2">
                <div className="flex items-center gap-2">
                  <Shield className="w-4 h-4 text-[#f0b90b]" />
                  <span className="text-sm text-[#f0b90b] font-semibold">Safety Features</span>
                </div>
                <ul className="text-xs text-[#848e9c] space-y-1 ml-6">
                  <li>Balance checks prevent over-allocation</li>
                  <li>You can disable anytime</li>
                  <li>Auto-expires after 24 hours</li>
                </ul>
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setShowAutoAcceptModal(false)}
                  className="flex-1 px-6 py-3 border border-[#474d57] rounded-xl text-white font-semibold hover:bg-[#2b3139] transition-all"
                >
                  Cancel
                </button>
                <button
                  onClick={() => {
                    setShowAutoAcceptModal(false);
                    setShowAutoAcceptConfirm(true);
                  }}
                  className="flex-1 px-6 py-3 bg-gradient-to-r from-[#f0b90b] to-[#d4a20a] hover:from-[#f5c423] hover:to-[#e0ac0e] text-black font-bold rounded-xl transition-all flex items-center justify-center gap-2"
                >
                  <Zap className="w-4 h-4" />
                  Continue
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showAutoAcceptConfirm && selectedCopy && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2329] rounded-2xl max-w-md w-full border border-[#f6465d]/50 shadow-2xl">
            <div className="flex items-center justify-between p-6 border-b border-[#2b3139]">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-[#f6465d]/20 rounded-xl flex items-center justify-center">
                  <AlertTriangle className="w-5 h-5 text-[#f6465d]" />
                </div>
                <h3 className="text-xl font-bold">Confirm Auto-Accept</h3>
              </div>
              <button
                onClick={() => setShowAutoAcceptConfirm(false)}
                className="text-[#848e9c] hover:text-white transition-colors p-1 hover:bg-[#2b3139] rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-5">
              <div className="bg-[#f6465d]/10 border border-[#f6465d]/30 rounded-xl p-5">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="w-6 h-6 text-[#f6465d] flex-shrink-0 mt-0.5" />
                  <div>
                    <h4 className="text-[#f6465d] font-bold text-lg mb-2">Important Warning</h4>
                    <p className="text-white text-sm leading-relaxed">
                      By enabling auto-accept, <span className="text-[#f6465d] font-semibold">ALL trade signals</span> from {selectedCopy.trader.name} will be <span className="text-[#f6465d] font-semibold">automatically executed</span> using your funds for the next 24 hours.
                    </p>
                  </div>
                </div>
              </div>

              <div className="bg-[#0b0e11] rounded-xl p-4 space-y-3">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-[#848e9c]">Max Leverage</span>
                  <span className="text-white font-semibold">{autoAcceptMaxLeverage}x</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-[#848e9c]">Duration</span>
                  <span className="text-white font-semibold">24 hours</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-[#848e9c]">Your Balance</span>
                  <span className="text-white font-semibold">{parseFloat(selectedCopy.current_balance).toFixed(2)} USDT</span>
                </div>
              </div>

              <p className="text-xs text-[#848e9c] text-center">
                You understand that trades will be executed automatically and you accept the associated risks.
              </p>

              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setShowAutoAcceptConfirm(false)}
                  className="flex-1 px-6 py-3 border border-[#474d57] rounded-xl text-white font-semibold hover:bg-[#2b3139] transition-all"
                >
                  Go Back
                </button>
                <button
                  onClick={() => handleToggleAutoAccept(true)}
                  disabled={togglingAutoAccept}
                  className="flex-1 px-6 py-3 bg-gradient-to-r from-[#f6465d] to-[#d93547] hover:from-[#ff4d63] hover:to-[#e03a4c] disabled:from-[#474d57] disabled:to-[#474d57] disabled:cursor-not-allowed text-white font-bold rounded-xl transition-all flex items-center justify-center gap-2"
                >
                  {togglingAutoAccept ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      Enabling...
                    </>
                  ) : (
                    <>
                      <CheckCircle className="w-4 h-4" />
                      I Understand, Enable
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default ActiveCopyTrading;
