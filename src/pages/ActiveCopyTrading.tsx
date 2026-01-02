import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { useNavigation } from '../App';
import { ArrowLeft, TrendingUp, TrendingDown, X, Bell } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../hooks/useToast';
import { ToastContainer } from '../components/Toast';
import PendingTradeCard from '../components/PendingTradeCard';

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
  total_pnl: string;
  is_active: boolean;
  is_mock: boolean;
  created_at: string;
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
  const [withdrawing, setWithdrawing] = useState(false);
  const [respondingToTrade, setRespondingToTrade] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'positions' | 'history' | 'allocations'>('positions');

  useEffect(() => {
    loadCopyRelationship();
  }, [user]);

  useEffect(() => {
    if (selectedCopy) {
      loadTraderTrades();
      loadMyAllocations();
      loadPendingTrades();

      // Regular data refresh
      const interval = setInterval(() => {
        loadTraderTrades();
        loadMyAllocations();
        loadPendingTrades();
        updateBalance();
      }, 5000);

      // Periodically expire old trades (every 30 seconds)
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
          *,
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
        total_pnl: data.total_pnl || '0',
        is_active: data.is_active,
        is_mock: data.is_mock || false,
        created_at: data.created_at,
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

      // Calculate quantity for each allocation
      // Quantity = (allocated_amount * leverage) / entry_price
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

      // Get user's responses to filter out already responded trades
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
        .select('initial_balance, current_balance, total_pnl')
        .eq('id', selectedCopy.id)
        .maybeSingle();

      if (relationshipError) throw relationshipError;

      if (relationshipData) {
        setSelectedCopy(prev => prev ? {
          ...prev,
          initial_balance: relationshipData.initial_balance || '0',
          current_balance: relationshipData.current_balance || '0',
          total_pnl: relationshipData.total_pnl || '0'
        } : null);
      }
    } catch (error) {
      console.error('Error updating balance:', error);
    }
  };

  const handleWithdraw = async () => {
    if (!user || !selectedCopy) return;

    setWithdrawing(true);

    try {
      // For mock copy trading, just stop without transferring funds
      if (selectedCopy.is_mock) {
        const { error: copyError } = await supabase
          .from('copy_relationships')
          .update({
            is_active: false,
            status: 'stopped',
            ended_at: new Date().toISOString()
          })
          .eq('id', selectedCopy.id);

        if (copyError) throw copyError;

        showSuccess(`Mock copy trading with ${selectedCopy.trader.name} has been stopped`);
        setShowWithdrawModal(false);

        setTimeout(() => {
          navigateTo('copytrading');
        }, 2000);
        return;
      }

      const initialBalance = parseFloat(selectedCopy.initial_balance);
      const currentBalance = parseFloat(selectedCopy.current_balance);
      const profit = currentBalance - initialBalance;

      let withdrawAmount = currentBalance;
      let platformFee = 0;

      if (profit > 0) {
        platformFee = profit * 0.20;
        withdrawAmount = currentBalance - platformFee;
      }

      // Use the transfer_between_wallets function to properly handle both wallets
      const { data: transferData, error: transferError } = await supabase.rpc(
        'transfer_between_wallets',
        {
          user_id_param: user.id,
          currency_param: 'USDT',
          amount_param: withdrawAmount,
          from_wallet_type_param: 'copy',
          to_wallet_type_param: 'main'
        }
      );

      if (transferError) throw transferError;
      if (!transferData?.success) throw new Error(transferData?.error || 'Transfer failed');

      // Update copy relationship status
      const { error: copyError } = await supabase
        .from('copy_relationships')
        .update({
          is_active: false,
          current_balance: '0'
        })
        .eq('id', selectedCopy.id);

      if (copyError) throw copyError;

      showSuccess(`Successfully withdrawn ${withdrawAmount.toFixed(2)} USDT to your wallet${platformFee > 0 ? `. Platform fee: ${platformFee.toFixed(2)} USDT (20% of profits)` : ''}`);
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

  if (loading) {
    return (
      <div className="min-h-screen bg-[#181a20] text-white">
        <Navbar />
        <div className="flex items-center justify-center py-20">
          <div className="animate-spin w-12 h-12 border-4 border-[#fcd535] border-t-transparent rounded-full"></div>
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

  return (
    <div className="min-h-screen bg-[#181a20] text-white">
      <Navbar />
      <ToastContainer toasts={toasts} removeToast={removeToast} />

      <div className="max-w-[1400px] mx-auto px-6 py-6">
        <button
          onClick={() => navigateTo('copytrading')}
          className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Copy Trading
        </button>

        <div className="bg-[#2b3139] rounded-lg p-6 mb-6">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-4">
              <div
                className="text-4xl cursor-pointer hover:opacity-80 transition-opacity"
                onClick={() => {
                  window.history.pushState({}, '', `?page=traderprofile&id=${selectedCopy.trader_id}`);
                  navigateTo('traderprofile');
                }}
              >
                {selectedCopy.trader.avatar}
              </div>
              <div>
                <h2
                  className="text-2xl font-semibold mb-1 cursor-pointer hover:text-[#fcd535] transition-colors"
                  onClick={() => {
                    window.history.pushState({}, '', `?page=traderprofile&id=${selectedCopy.trader_id}`);
                    navigateTo('traderprofile');
                  }}
                >
                  {selectedCopy.trader.name}
                </h2>
                <p className="text-sm text-[#848e9c]">
                  Copying since {new Date(selectedCopy.created_at).toLocaleDateString()}
                </p>
              </div>
            </div>

            {selectedCopy.is_active && (
              <button
                onClick={() => setShowWithdrawModal(true)}
                className="bg-[#f6465d] hover:bg-[#ff4757] text-white px-6 py-2.5 rounded-lg font-medium transition-all"
              >
                {selectedCopy.is_mock ? 'Stop Mock Copy' : 'Withdraw & Stop'}
              </button>
            )}
          </div>

          <div className="grid grid-cols-2 md:grid-cols-5 gap-6">
            <div>
              <div className="text-[#848e9c] text-xs mb-2">Initial Balance</div>
              <div className="text-white text-lg font-semibold">
                {parseFloat(selectedCopy.initial_balance).toFixed(2)} USDT
              </div>
            </div>

            <div>
              <div className="text-[#848e9c] text-xs mb-2">Current Balance</div>
              <div className="text-white text-lg font-semibold">
                {parseFloat(selectedCopy.current_balance).toFixed(2)} USDT
              </div>
            </div>

            <div>
              <div className="text-[#848e9c] text-xs mb-2">Total PNL</div>
              <div className={`text-lg font-semibold ${profit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                {profit >= 0 ? '+' : ''}{profit.toFixed(2)} USDT
              </div>
            </div>

            <div>
              <div className="text-[#848e9c] text-xs mb-2">ROI</div>
              <div className={`text-lg font-semibold ${parseFloat(roi) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                {parseFloat(roi) >= 0 ? '+' : ''}{roi}%
              </div>
            </div>

            <div>
              <div className="text-[#848e9c] text-xs mb-2">Leverage</div>
              <div className="text-white text-lg font-semibold">{selectedCopy.leverage}x</div>
            </div>
          </div>

        </div>

        {pendingTrades.length > 0 && (
          <div className="mb-6">
            <div className="flex items-center gap-3 mb-4">
              <Bell className="w-5 h-5 text-[#fcd535]" />
              <h3 className="text-xl font-bold text-white">Pending Trade Signals ({pendingTrades.length})</h3>
            </div>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {pendingTrades.map((trade) => {
                const walletType = selectedCopy.is_mock ? 'mock' : 'copy';
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

        <div className="bg-[#fcd535]/10 border border-[#fcd535]/30 rounded-lg p-4 mb-6">
          <div className="flex items-start gap-3">
            <div className="text-[#fcd535] text-xl">ℹ️</div>
            <div>
              <h4 className="text-[#fcd535] font-semibold text-sm mb-1">Important Information</h4>
              <ul className="text-[#848e9c] text-xs space-y-1">
                <li>• When you withdraw, the platform charges a 20% fee on profits only (no fee on losses)</li>
                <li>• Trades shown below are only from the moment you started copying ({new Date(selectedCopy.created_at).toLocaleDateString()})</li>
                <li>• Past performance does not guarantee future results</li>
              </ul>
            </div>
          </div>
        </div>

        <div className="bg-[#2b3139] rounded-lg p-6">
          <div className="flex gap-8 border-b border-[#1e2329] mb-6">
            <button
              onClick={() => setActiveTab('positions')}
              className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
                activeTab === 'positions'
                  ? 'text-white'
                  : 'text-[#848e9c] hover:text-white'
              }`}
            >
              Live Positions
              {activeTab === 'positions' && (
                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#fcd535]" />
              )}
            </button>
            <button
              onClick={() => setActiveTab('history')}
              className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
                activeTab === 'history'
                  ? 'text-white'
                  : 'text-[#848e9c] hover:text-white'
              }`}
            >
              Position History
              {activeTab === 'history' && (
                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#fcd535]" />
              )}
            </button>
            <button
              onClick={() => setActiveTab('allocations')}
              className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
                activeTab === 'allocations'
                  ? 'text-white'
                  : 'text-[#848e9c] hover:text-white'
              }`}
            >
              My Copy Trades
              {activeTab === 'allocations' && (
                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#fcd535]" />
              )}
            </button>
          </div>

          {activeTab === 'positions' && (
            <div className="space-y-4">
              <p className="text-sm text-[#848e9c] mb-4">
                Showing current open positions from {selectedCopy.trader.name} since you started copying.
              </p>

              {openTrades.length === 0 ? (
                <div className="bg-[#0b0e11] rounded-lg p-8 mt-4">
                  <div className="text-[#848e9c] text-sm text-center">
                    No open positions. The trader will appear here when they open new positions.
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  {openTrades.map((position) => (
                    <div key={position.id} className="bg-[#1e2329] rounded-lg p-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <span className="text-white font-medium">{position.symbol}</span>
                        </div>
                        <div className="flex items-center gap-6 text-sm">
                          <div className="text-[#848e9c]">
                            Leverage: <span className="text-white">{position.leverage}x</span>
                          </div>
                          <div className="text-[#848e9c]">
                            Entry: <span className="text-white">${position.entry_price.toLocaleString()}</span>
                          </div>
                          <div className="text-[#848e9c]">
                            Qty: <span className="text-white">{position.quantity}</span>
                          </div>
                          <div className="text-xs text-[#848e9c]">
                            Opened: {new Date(position.opened_at).toLocaleString()}
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {activeTab === 'history' && (
            <div className="space-y-4">
              <p className="text-sm text-[#848e9c] mb-4">
                Showing all closed positions from {selectedCopy.trader.name} since you started copying.
              </p>

              {closedTrades.length === 0 ? (
                <div className="bg-[#0b0e11] rounded-lg p-8">
                  <div className="text-[#848e9c] text-sm text-center">
                    No closed positions yet
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  {closedTrades.map((position) => (
                    <div key={position.id} className="bg-[#1e2329] rounded-lg p-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <span className="text-white font-medium">{position.symbol}</span>
                          <span className={`text-xs px-2 py-0.5 rounded ${
                            position.side === 'long' ? 'bg-[#0ecb81]/10 text-[#0ecb81]' : 'bg-[#f6465d]/10 text-[#f6465d]'
                          }`}>
                            {position.side?.toUpperCase()}
                          </span>
                        </div>
                        <div className="flex items-center gap-6 text-sm">
                          <div className="text-[#848e9c]">
                            Leverage: <span className="text-white">{position.leverage}x</span>
                          </div>
                          <div className="text-[#848e9c]">
                            Entry: <span className="text-white">${position.entry_price.toLocaleString()}</span>
                          </div>
                          <div className="text-[#848e9c]">
                            Exit: <span className="text-white">${position.exit_price?.toLocaleString() || 'N/A'}</span>
                          </div>
                          <div className="text-[#848e9c]">
                            PNL: {position.pnl ? (
                              <span className={(position.pnl >= 0) ? 'text-[#0ecb81]' : 'text-[#f6465d]'}>
                                {(position.pnl >= 0) ? '+' : ''}{position.pnl.toFixed(2)} USDT
                                {(position.pnl_percent || position.pnl_percentage) && ` (${(position.pnl_percent || position.pnl_percentage || 0) >= 0 ? '+' : ''}${(position.pnl_percent || position.pnl_percentage || 0).toFixed(2)}%)`}
                              </span>
                            ) : (
                              <span className="text-[#848e9c]">N/A</span>
                            )}
                          </div>
                        </div>
                      </div>
                      <div className="text-xs text-[#848e9c] mt-2">
                        Closed at: {position.closed_at ? new Date(position.closed_at).toLocaleString() : 'N/A'}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {activeTab === 'allocations' && (
            <div>
              <p className="text-sm text-[#848e9c] mb-6">
                Your personal copy trading allocations and P&L. This shows the exact amounts you've invested in each trade and your actual profits/losses.
              </p>

              {myAllocations.length === 0 ? (
                <div className="text-center py-12">
                  <div className="text-gray-500">No allocations yet. Allocations will appear when the trader opens positions.</div>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-[#474d57]">
                        <th className="text-left text-[#848e9c] text-xs font-medium pb-3 px-2">Symbol</th>
                        <th className="text-center text-[#848e9c] text-xs font-medium pb-3 px-2">Side</th>
                        <th className="text-right text-[#848e9c] text-xs font-medium pb-3 px-2">Quantity</th>
                        <th className="text-right text-[#848e9c] text-xs font-medium pb-3 px-2">Entry</th>
                        <th className="text-right text-[#848e9c] text-xs font-medium pb-3 px-2">Exit</th>
                        <th className="text-right text-[#848e9c] text-xs font-medium pb-3 px-2">Allocated</th>
                        <th className="text-right text-[#848e9c] text-xs font-medium pb-3 px-2">PNL</th>
                        <th className="text-center text-[#848e9c] text-xs font-medium pb-3 px-2">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {myAllocations.map((allocation) => (
                        <tr key={allocation.id} className="border-b border-[#474d57]/50 hover:bg-[#353c47] transition-colors">
                          <td className="py-3 px-2 text-white text-sm font-medium">
                            {allocation.symbol || 'N/A'}
                          </td>
                          <td className="py-3 px-2 text-center">
                            {allocation.status === 'closed' ? (
                              <span className={`text-xs px-2 py-0.5 rounded ${
                                allocation.side === 'long' ? 'bg-[#0ecb81]/10 text-[#0ecb81]' : 'bg-[#f6465d]/10 text-[#f6465d]'
                              }`}>
                                {allocation.side?.toUpperCase()}
                              </span>
                            ) : (
                              <span className="text-xs text-[#848e9c]">-</span>
                            )}
                          </td>
                          <td className="py-3 px-2 text-right text-[#848e9c] text-sm">
                            {allocation.quantity?.toFixed(4) || 'N/A'}
                          </td>
                          <td className="py-3 px-2 text-right text-[#848e9c] text-sm">
                            ${allocation.entry_price.toLocaleString()}
                          </td>
                          <td className="py-3 px-2 text-right text-[#848e9c] text-sm">
                            {allocation.exit_price ? `$${allocation.exit_price.toLocaleString()}` : '-'}
                          </td>
                          <td className="py-3 px-2 text-right text-[#848e9c] text-sm">
                            {allocation.allocated_amount.toFixed(2)} USDT
                          </td>
                          <td className="py-3 px-2 text-right text-sm">
                            {allocation.realized_pnl !== null && allocation.realized_pnl !== undefined && allocation.realized_pnl !== 0 ? (
                              <div className="flex flex-col items-end gap-0.5">
                                <span className={allocation.realized_pnl >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}>
                                  {allocation.realized_pnl >= 0 ? '+' : ''}{allocation.realized_pnl.toFixed(2)} USDT
                                </span>
                                {allocation.pnl_percentage !== null && allocation.pnl_percentage !== undefined && (
                                  <span className={`text-xs ${allocation.pnl_percentage >= 0 ? 'text-[#0ecb81]/70' : 'text-[#f6465d]/70'}`}>
                                    {allocation.pnl_percentage >= 0 ? '+' : ''}{allocation.pnl_percentage.toFixed(2)}%
                                  </span>
                                )}
                              </div>
                            ) : allocation.pnl_percentage !== null && allocation.pnl_percentage !== undefined ? (
                              <div className="flex items-center justify-end gap-1">
                                {allocation.pnl_percentage >= 0 ? (
                                  <TrendingUp className="w-4 h-4 text-[#0ecb81]" />
                                ) : (
                                  <TrendingDown className="w-4 h-4 text-[#f6465d]" />
                                )}
                                <span className={allocation.pnl_percentage >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}>
                                  {allocation.pnl_percentage >= 0 ? '+' : ''}{allocation.pnl_percentage.toFixed(2)}%
                                </span>
                              </div>
                            ) : (
                              <span className="text-[#848e9c]">-</span>
                            )}
                          </td>
                          <td className="py-3 px-2 text-center">
                            <span className={`px-2 py-1 rounded text-xs ${
                              allocation.status === 'open'
                                ? 'bg-blue-500/20 text-blue-400'
                                : 'bg-gray-500/20 text-gray-400'
                            }`}>
                              {allocation.status.toUpperCase()}
                            </span>
                          </td>
                          <td className="py-3 px-2 text-right text-[#848e9c] text-xs">
                            {allocation.status === 'closed' && allocation.closed_at
                              ? new Date(allocation.closed_at).toLocaleString()
                              : new Date(allocation.created_at).toLocaleString()
                            }
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
      </div>

      {showWithdrawModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#181a20] rounded-2xl p-6 max-w-md w-full border border-gray-800">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold">{selectedCopy.is_mock ? 'Stop Mock Copy Trading' : 'Withdraw Funds'}</h3>
              <button
                onClick={() => setShowWithdrawModal(false)}
                className="text-gray-400 hover:text-white transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            {selectedCopy.is_mock ? (
              <div className="space-y-4 mb-6">
                <div className="bg-[#0b0e11] rounded-xl p-4">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-gray-400 text-sm">Mock Balance</span>
                    <span className="text-white text-lg font-bold">
                      {parseFloat(selectedCopy.current_balance).toFixed(2)} USDT
                    </span>
                  </div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-gray-400 text-sm">Initial Balance</span>
                    <span className="text-gray-400 text-sm">
                      {parseFloat(selectedCopy.initial_balance).toFixed(2)} USDT
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-400 text-sm">Mock Profit/Loss</span>
                    <span className={`text-sm font-semibold ${profit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                      {profit >= 0 ? '+' : ''}{profit.toFixed(2)} USDT
                    </span>
                  </div>
                </div>

                <div className="bg-blue-900/20 border border-blue-700/30 rounded-xl p-4">
                  <p className="text-xs text-blue-400">
                    This is mock copy trading with virtual funds. No real money is involved.
                    Stopping will end your mock copy trading session with {selectedCopy.trader.name}.
                  </p>
                </div>
              </div>
            ) : (
              <div className="space-y-4 mb-6">
                <div className="bg-[#0b0e11] rounded-xl p-4">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-gray-400 text-sm">Current Balance</span>
                    <span className="text-white text-lg font-bold">
                      {withdrawal.total.toFixed(2)} USDT
                    </span>
                  </div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-gray-400 text-sm">Initial Balance</span>
                    <span className="text-gray-400 text-sm">
                      {parseFloat(selectedCopy.initial_balance).toFixed(2)} USDT
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-400 text-sm">Profit/Loss</span>
                    <span className={`text-sm font-semibold ${profit >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                      {profit >= 0 ? '+' : ''}{profit.toFixed(2)} USDT
                    </span>
                  </div>
                </div>

                {withdrawal.fee > 0 && (
                  <div className="bg-[#f6465d]/10 border border-[#f6465d]/30 rounded-xl p-4">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-gray-400 text-sm">Platform Fee (20% of profit)</span>
                      <span className="text-[#f6465d] text-sm font-semibold">
                        -{withdrawal.fee.toFixed(2)} USDT
                      </span>
                    </div>
                    <p className="text-xs text-gray-500">
                      We charge 20% commission on profits made through copy trading
                    </p>
                  </div>
                )}

                <div className="bg-[#0ecb81]/10 border border-[#0ecb81]/30 rounded-xl p-4">
                  <div className="text-sm text-gray-400 mb-1">You will receive</div>
                  <div className="text-[#0ecb81] text-2xl font-bold">
                    {withdrawal.net.toFixed(2)} USDT
                  </div>
                </div>

                <div className="bg-yellow-900/20 border border-yellow-700/30 rounded-xl p-4">
                  <p className="text-xs text-yellow-400">
                    Warning: This will stop copying {selectedCopy.trader.name} and withdraw all funds to your wallet. This action cannot be undone.
                  </p>
                </div>
              </div>
            )}

            <button
              onClick={handleWithdraw}
              disabled={withdrawing}
              className="w-full bg-[#f6465d] hover:bg-[#ff4757] disabled:bg-gray-700 disabled:cursor-not-allowed text-white disabled:text-gray-500 font-bold py-3 rounded-xl transition-all"
            >
              {withdrawing ? 'Processing...' : (selectedCopy.is_mock ? 'Stop Mock Copy Trading' : 'Confirm Withdrawal')}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default ActiveCopyTrading;
