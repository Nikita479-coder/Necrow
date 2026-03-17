import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';
import { X, Edit2, FileText, Gift, ChevronLeft, ChevronRight, TrendingUp, TrendingDown, Activity, BarChart3 } from 'lucide-react';
import { usePrices } from '../../hooks/usePrices';
import { useToast } from '../../hooks/useToast';
import { ToastContainer } from '../Toast';
import TPSLModal from './TPSLModal';
import PositionDetailsModal from './PositionDetailsModal';
import { tpslMonitorService, TPSLCloseEvent } from '../../services/tpslMonitorService';

interface Position {
  position_id: string;
  pair: string;
  side: string;
  entry_price: number;
  mark_price: number;
  quantity: number;
  leverage: number;
  margin_mode: string;
  unrealized_pnl: number;
  liquidation_price: number;
  stop_loss: number | null;
  take_profit: number | null;
  margin_allocated: number;
  overnight_fees_accrued: number;
  cumulative_fees: number;
  margin_from_locked_bonus: number;
}

interface Order {
  order_id: string;
  pair: string;
  side: string;
  order_type: string;
  quantity: number;
  price: number | null;
  leverage: number;
  order_status: string;
  created_at: string;
}

interface PositionHistory {
  position_id: string;
  pair: string;
  side: string;
  entry_price: number;
  close_price: number;
  quantity: number;
  leverage: number;
  realized_pnl: number;
  closed_at: string;
  margin_allocated: number;
  margin_from_locked_bonus: number;
  opened_at: string;
  cumulative_fees: number;
  status: string;
}

type TabType = 'positions' | 'orders' | 'history';

function FuturesPositionsPanel() {
  const { user } = useAuth();
  const prices = usePrices();
  const { toasts, removeToast, showSuccess, showError } = useToast();
  const [activeTab, setActiveTab] = useState<TabType>('positions');
  const [positions, setPositions] = useState<Position[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [history, setHistory] = useState<PositionHistory[]>([]);
  const [loading, setLoading] = useState(true);
  const [closingPosition, setClosingPosition] = useState<string | null>(null);
  const [tpslModal, setTpslModal] = useState<{ position: Position; mode: 'TP' | 'SL' } | null>(null);
  const [detailsModal, setDetailsModal] = useState<Position | null>(null);
  const [historyPage, setHistoryPage] = useState(1);
  const [historyTotal, setHistoryTotal] = useState(0);
  const historyPerPage = 10;

  useEffect(() => {
    if (!user) return;

    fetchData();

    tpslMonitorService.start(user.id);

    const handleTPSLTriggered = (event: TPSLCloseEvent) => {
      const pnlFormatted = event.pnl >= 0
        ? `+$${event.pnl.toFixed(2)}`
        : `-$${Math.abs(event.pnl).toFixed(2)}`;

      if (event.reason === 'Take Profit') {
        showSuccess(`Take Profit hit! ${event.pair} ${event.side.toUpperCase()} closed at $${event.closePrice.toLocaleString()}. P&L: ${pnlFormatted}`);
      } else {
        showError(`Stop Loss hit! ${event.pair} ${event.side.toUpperCase()} closed at $${event.closePrice.toLocaleString()}. P&L: ${pnlFormatted}`);
      }

      fetchPositions();
      fetchHistory();
    };

    const unsubscribeTPSL = tpslMonitorService.onTPSLTriggered(handleTPSLTriggered);

    const positionsChannel = supabase
      .channel('positions_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'futures_positions',
          filter: `user_id=eq.${user.id}`
        },
        () => {
          fetchPositions();
        }
      )
      .subscribe();

    const ordersChannel = supabase
      .channel('orders_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'futures_orders',
          filter: `user_id=eq.${user.id}`
        },
        () => {
          fetchOrders();
        }
      )
      .subscribe();

    const refreshInterval = setInterval(() => {
      fetchPositions();
    }, 1000);

    return () => {
      unsubscribeTPSL();
      tpslMonitorService.stop();
      supabase.removeChannel(positionsChannel);
      supabase.removeChannel(ordersChannel);
      clearInterval(refreshInterval);
    };
  }, [user]);

  const fetchData = async () => {
    await Promise.all([fetchPositions(), fetchOrders(), fetchHistory()]);
    setLoading(false);
  };

  const fetchPositions = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('futures_positions')
        .select('position_id, user_id, pair, side, entry_price, mark_price, quantity, leverage, margin_mode, unrealized_pnl, liquidation_price, stop_loss, take_profit, margin_allocated, overnight_fees_accrued, cumulative_fees, opened_at, status, margin_from_locked_bonus')
        .eq('user_id', user.id)
        .eq('status', 'open')
        .order('opened_at', { ascending: false });

      if (error) {
        console.error('Error fetching positions:', error);
        showError('Failed to load positions');
        return;
      }
      setPositions(data || []);
    } catch (error: any) {
      console.error('Error fetching positions:', error);
      showError(error.message || 'Failed to load positions');
    }
  };

  const fetchOrders = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('futures_orders')
        .select('*')
        .eq('user_id', user.id)
        .in('order_status', ['pending', 'partial'])
        .order('created_at', { ascending: false });

      if (error) throw error;
      setOrders(data || []);
    } catch (error) {
      console.error('Error fetching orders:', error);
    }
  };

  const fetchHistory = async (page: number = 1) => {
    if (!user) return;

    try {
      const from = (page - 1) * historyPerPage;
      const to = from + historyPerPage - 1;

      const { count, error: countError } = await supabase
        .from('futures_positions')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .in('status', ['closed', 'liquidated']);

      if (countError) throw countError;
      setHistoryTotal(count || 0);

      const { data, error } = await supabase
        .from('futures_positions')
        .select('position_id, pair, side, entry_price, mark_price, quantity, leverage, realized_pnl, closed_at, margin_allocated, margin_from_locked_bonus, opened_at, cumulative_fees, status')
        .eq('user_id', user.id)
        .in('status', ['closed', 'liquidated'])
        .order('closed_at', { ascending: false })
        .range(from, to);

      if (error) throw error;
      setHistory(data || []);
    } catch (error) {
      console.error('Error fetching history:', error);
    }
  };

  useEffect(() => {
    if (user && activeTab === 'history') {
      fetchHistory(historyPage);
    }
  }, [historyPage]);

  const handleClosePosition = async (positionId: string) => {
    setClosingPosition(positionId);
    try {
      const position = positions.find(p => p.position_id === positionId);

      let currentMarketPrice = null;
      if (position) {
        const priceData = prices.get(position.pair);
        if (priceData) {
          currentMarketPrice = priceData.price;
        }
      }

      const { data, error } = await supabase.rpc('close_position', {
        p_position_id: positionId,
        p_close_quantity: null,
        p_close_price: currentMarketPrice
      });

      if (error) {
        showError(error.message || 'Failed to close position');
        return;
      }

      if (data && !data.success) {
        showError(data.error || 'Failed to close position');
        return;
      }

      if (data && data.success) {
        const pnl = data.net_pnl ?? 0;
        showSuccess(`Position closed. P&L: ${pnl >= 0 ? '+' : ''}${pnl.toFixed(2)} USDT`);

        if (user && position) {
          const pnlFormatted = pnl >= 0 ? `+${pnl.toFixed(2)}` : pnl.toFixed(2);
          await supabase.rpc('send_notification', {
            p_user_id: user.id,
            p_type: 'position_closed',
            p_title: 'Position Closed',
            p_message: `Your ${position.pair} ${position.side.toUpperCase()} position was closed. P&L: ${pnlFormatted} USDT`,
            p_data: {
              position_id: positionId,
              pair: position.pair,
              side: position.side,
              pnl: pnl,
              reason: 'manual'
            }
          });
        }

        await fetchData();
      }
    } catch (error: any) {
      showError(error.message || 'Error closing position');
      console.error('Error closing position:', error);
    } finally {
      setClosingPosition(null);
    }
  };

  const handleCancelOrder = async (orderId: string) => {
    try {
      const { data, error } = await supabase.rpc('cancel_futures_order', {
        p_order_id: orderId
      });

      if (error) throw error;

      if (data && !data.success) {
        console.error('Failed to cancel order:', data.error);
        return;
      }

      await fetchOrders();
    } catch (error) {
      console.error('Error cancelling order:', error);
    }
  };

  const calculateROE = (pnl: number, margin: number): number => {
    if (margin <= 0) return 0;
    return (pnl / margin) * 100;
  };

  const getRealTimeMarkPrice = (pair: string): number => {
    const symbol = pair.replace('USDT', '/USDT');
    const priceData = prices.get(symbol);
    return priceData ? parseFloat(priceData.price) : 0;
  };

  const calculateRealTimePnL = (position: Position, currentPrice: number, includeFees: boolean = true): number => {
    const totalFees = position.cumulative_fees || position.overnight_fees_accrued || 0;

    if (currentPrice === 0) return position.unrealized_pnl - (includeFees ? totalFees : 0);

    const priceDiff = position.side === 'long'
      ? currentPrice - position.entry_price
      : position.entry_price - currentPrice;

    const pricePnL = priceDiff * position.quantity;
    return includeFees ? pricePnL - totalFees : pricePnL;
  };

  const getLiquidationDistance = (side: string, markPrice: number, liqPrice: number): number => {
    if (side === 'long') {
      return ((markPrice - liqPrice) / markPrice) * 100;
    } else {
      return ((liqPrice - markPrice) / markPrice) * 100;
    }
  };

  const getMarginHealthColor = (distance: number): string => {
    if (distance > 50) return 'text-green-500';
    if (distance > 20) return 'text-yellow-500';
    return 'text-red-500';
  };

  const renderPositions = () => {
    if (positions.length === 0) {
      return (
        <div className="text-center py-16">
          <Activity className="w-16 h-16 text-[#2b3139] mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-white mb-2">No Open Positions</h3>
          <p className="text-[#848e9c] text-sm">Open a position to start trading</p>
        </div>
      );
    }

    return (
      <div className="space-y-3">
        {positions.map((position) => {
          const realTimeMarkPrice = getRealTimeMarkPrice(position.pair);
          const currentMarkPrice = realTimeMarkPrice > 0 ? realTimeMarkPrice : position.mark_price;
          const realTimePnL = realTimeMarkPrice > 0 ? calculateRealTimePnL(position, realTimeMarkPrice) : position.unrealized_pnl;
          const roe = calculateROE(realTimePnL, position.margin_allocated);
          const liqDistance = getLiquidationDistance(position.side, currentMarkPrice, position.liquidation_price ?? 0);
          const pnlColor = realTimePnL >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]';
          const sideColor = position.side === 'long' ? 'text-[#0ecb81]' : 'text-[#f6465d]';
          const usedBonusMargin = (position.margin_from_locked_bonus || 0) > 0;

          return (
            <div
              key={position.position_id}
              className="bg-[#1e2329] hover:bg-[#252930] rounded-xl p-5 transition-all border border-[#2b3139] hover:border-[#474d57]"
            >
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                    position.side === 'long' ? 'bg-[#0ecb81]/10' : 'bg-[#f6465d]/10'
                  }`}>
                    {position.side === 'long' ? (
                      <TrendingUp className="w-5 h-5 text-[#0ecb81]" />
                    ) : (
                      <TrendingDown className="w-5 h-5 text-[#f6465d]" />
                    )}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-white font-semibold text-lg">{position.pair}</span>
                      {usedBonusMargin && (
                        <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-amber-500/10 text-amber-500 rounded text-[10px] font-medium" title={`Bonus margin: $${position.margin_from_locked_bonus.toFixed(2)}`}>
                          <Gift className="w-3 h-3" />
                        </span>
                      )}
                      {realTimeMarkPrice > 0 && (
                        <div className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" title="Real-time price"></div>
                      )}
                    </div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className={`text-xs px-2 py-0.5 rounded font-medium ${
                        position.side === 'long'
                          ? 'bg-[#0ecb81]/10 text-[#0ecb81]'
                          : 'bg-[#f6465d]/10 text-[#f6465d]'
                      }`}>
                        {position.side.toUpperCase()}
                      </span>
                      <span className="text-xs text-[#f0b90b] font-medium">{position.leverage}x</span>
                      <span className="text-xs text-[#848e9c]">{position.margin_mode}</span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setDetailsModal(position)}
                    className="p-2 bg-[#2b3139] hover:bg-[#474d57] text-[#848e9c] hover:text-white rounded-lg transition-colors"
                    title="View Details"
                  >
                    <FileText className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleClosePosition(position.position_id)}
                    disabled={closingPosition === position.position_id}
                    className="px-4 py-2 bg-[#f6465d]/20 hover:bg-[#f6465d]/30 disabled:bg-[#2b3139] disabled:cursor-not-allowed text-[#f6465d] disabled:text-[#848e9c] rounded-lg text-sm font-medium transition-colors"
                  >
                    {closingPosition === position.position_id ? 'Closing...' : 'Close'}
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-4">
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Entry Price</div>
                  <div className="text-white font-semibold">${position.entry_price.toLocaleString()}</div>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Mark Price</div>
                  <div className="text-white font-semibold">${currentMarkPrice.toLocaleString()}</div>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Liq. Price</div>
                  <div className={`font-semibold ${getMarginHealthColor(liqDistance)}`}>
                    ${(position.liquidation_price ?? 0).toLocaleString()}
                  </div>
                  <div className="text-xs text-[#848e9c]">{liqDistance.toFixed(1)}% away</div>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Size</div>
                  <div className="text-white font-semibold">{position.quantity.toFixed(4)}</div>
                </div>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-4">
                <div className={`rounded-lg p-3 ${realTimePnL >= 0 ? 'bg-[#0ecb81]/10' : 'bg-[#f6465d]/10'}`}>
                  <div className="text-[#848e9c] text-xs mb-1">PnL</div>
                  <div className={`font-semibold flex items-center gap-1 ${pnlColor}`}>
                    {realTimePnL >= 0 ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
                    {realTimePnL >= 0 ? '+' : ''}{realTimePnL.toFixed(2)}
                  </div>
                </div>
                <div className={`rounded-lg p-3 ${roe >= 0 ? 'bg-[#0ecb81]/10' : 'bg-[#f6465d]/10'}`}>
                  <div className="text-[#848e9c] text-xs mb-1">ROE</div>
                  <div className={`font-semibold ${pnlColor}`}>
                    {roe >= 0 ? '+' : ''}{roe.toFixed(2)}%
                  </div>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Margin</div>
                  <div className="text-white font-semibold">${position.margin_allocated.toFixed(2)}</div>
                  {usedBonusMargin && (
                    <div className="text-amber-500 text-xs flex items-center gap-1 mt-1">
                      <Gift className="w-3 h-3" />
                      ${position.margin_from_locked_bonus.toFixed(2)}
                    </div>
                  )}
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Fees Paid</div>
                  <div className="text-orange-400 font-semibold">
                    -${(position.cumulative_fees || position.overnight_fees_accrued || 0).toFixed(2)}
                  </div>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3 col-span-2 sm:col-span-1">
                  <div className="text-[#848e9c] text-xs mb-2">TP/SL</div>
                  <div className="flex gap-2">
                    <button
                      onClick={() => setTpslModal({ position, mode: 'TP' })}
                      className="flex-1 text-xs hover:bg-[#0ecb81]/10 px-2 py-1.5 rounded transition-colors border border-[#2b3139] hover:border-[#0ecb81]/30"
                    >
                      {position.take_profit ? (
                        <div className="flex flex-col">
                          <span className="text-[#0ecb81] font-medium">${position.take_profit.toFixed(0)}</span>
                        </div>
                      ) : (
                        <span className="text-[#848e9c]">Set TP</span>
                      )}
                    </button>
                    <button
                      onClick={() => setTpslModal({ position, mode: 'SL' })}
                      className="flex-1 text-xs hover:bg-[#f6465d]/10 px-2 py-1.5 rounded transition-colors border border-[#2b3139] hover:border-[#f6465d]/30"
                    >
                      {position.stop_loss ? (
                        <div className="flex flex-col">
                          <span className="text-[#f6465d] font-medium">${position.stop_loss.toFixed(0)}</span>
                        </div>
                      ) : (
                        <span className="text-[#848e9c]">Set SL</span>
                      )}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    );
  };

  const renderOrders = () => {
    if (orders.length === 0) {
      return (
        <div className="text-center py-16">
          <Edit2 className="w-16 h-16 text-[#2b3139] mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-white mb-2">No Pending Orders</h3>
          <p className="text-[#848e9c] text-sm">Limit orders will appear here</p>
        </div>
      );
    }

    return (
      <div className="space-y-3">
        {orders.map((order) => {
          const sideColor = order.side === 'long' ? 'text-[#0ecb81]' : 'text-[#f6465d]';

          return (
            <div
              key={order.order_id}
              className="bg-[#1e2329] hover:bg-[#252930] rounded-xl p-5 transition-all border border-[#2b3139] hover:border-[#474d57]"
            >
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                    order.side === 'long' ? 'bg-[#0ecb81]/10' : 'bg-[#f6465d]/10'
                  }`}>
                    {order.side === 'long' ? (
                      <TrendingUp className="w-5 h-5 text-[#0ecb81]" />
                    ) : (
                      <TrendingDown className="w-5 h-5 text-[#f6465d]" />
                    )}
                  </div>
                  <div>
                    <span className="text-white font-semibold text-lg">{order.pair}</span>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className={`text-xs px-2 py-0.5 rounded font-medium ${
                        order.side === 'long'
                          ? 'bg-[#0ecb81]/10 text-[#0ecb81]'
                          : 'bg-[#f6465d]/10 text-[#f6465d]'
                      }`}>
                        {order.side.toUpperCase()}
                      </span>
                      <span className="text-xs text-[#f0b90b] font-medium">{order.leverage}x</span>
                      <span className="text-xs px-2 py-0.5 rounded font-medium bg-yellow-500/10 text-yellow-500 capitalize">
                        {order.order_type}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="px-2 py-1 bg-yellow-500/10 text-yellow-500 rounded text-xs font-medium">
                    {order.order_status}
                  </span>
                  <button
                    onClick={() => handleCancelOrder(order.order_id)}
                    className="px-4 py-2 bg-[#2b3139] hover:bg-[#474d57] text-white rounded-lg text-sm font-medium transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Order Price</div>
                  <div className="text-white font-semibold">
                    {order.price ? `$${order.price.toLocaleString()}` : 'Market'}
                  </div>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Amount</div>
                  <div className="text-white font-semibold">{order.quantity.toFixed(4)}</div>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Total Value</div>
                  <div className="text-white font-semibold">
                    ${order.price ? (order.price * order.quantity).toLocaleString() : 'N/A'}
                  </div>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <div className="text-[#848e9c] text-xs mb-1">Created</div>
                  <div className="text-white font-semibold text-xs">
                    {new Date(order.created_at).toLocaleString()}
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    );
  };

  const renderHistory = () => {
    const totalPages = Math.ceil(historyTotal / historyPerPage);

    if (history.length === 0 && historyTotal === 0) {
      return (
        <div className="text-center py-16">
          <BarChart3 className="w-16 h-16 text-[#2b3139] mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-white mb-2">No Position History</h3>
          <p className="text-[#848e9c] text-sm">Closed positions will appear here</p>
        </div>
      );
    }

    return (
      <div className="flex flex-col h-full">
        <div className="flex-1 overflow-y-auto min-h-0 space-y-3">
          {history.map((position) => {
            const pnlColor = parseFloat(position.realized_pnl || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]';
            const sideColor = position.side === 'long' ? 'text-[#0ecb81]' : 'text-[#f6465d]';
            const usedBonusMargin = parseFloat(position.margin_from_locked_bonus || 0) > 0;

            return (
              <div
                key={position.position_id}
                className="bg-[#1e2329] rounded-xl p-5 border border-[#2b3139]"
              >
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                      position.side === 'long' ? 'bg-[#0ecb81]/10' : 'bg-[#f6465d]/10'
                    }`}>
                      {position.side === 'long' ? (
                        <TrendingUp className="w-5 h-5 text-[#0ecb81]" />
                      ) : (
                        <TrendingDown className="w-5 h-5 text-[#f6465d]" />
                      )}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-white font-semibold text-lg">{position.pair}</span>
                        {position.status === 'liquidated' && (
                          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-[#f6465d]/20 text-[#f6465d] rounded text-[10px] font-bold">
                            LIQ
                          </span>
                        )}
                        {usedBonusMargin && (
                          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-amber-500/10 text-amber-500 rounded text-[10px] font-medium">
                            <Gift className="w-3 h-3" />
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-2 mt-0.5">
                        <span className={`text-xs px-2 py-0.5 rounded font-medium ${
                          position.side === 'long'
                            ? 'bg-[#0ecb81]/10 text-[#0ecb81]'
                            : 'bg-[#f6465d]/10 text-[#f6465d]'
                        }`}>
                          {position.side.toUpperCase()}
                        </span>
                        <span className="text-xs text-[#f0b90b] font-medium">{position.leverage}x</span>
                      </div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs text-[#848e9c]">Closed</div>
                    <div className="text-sm text-white">
                      {new Date(position.closed_at).toLocaleDateString()}
                    </div>
                    <div className="text-xs text-[#848e9c]">
                      {new Date(position.closed_at).toLocaleTimeString()}
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  <div className="bg-[#0b0e11] rounded-lg p-3">
                    <div className="text-[#848e9c] text-xs mb-1">Entry</div>
                    <div className="text-white font-semibold">${parseFloat(position.entry_price || 0).toLocaleString()}</div>
                  </div>
                  <div className="bg-[#0b0e11] rounded-lg p-3">
                    <div className="text-[#848e9c] text-xs mb-1">Close</div>
                    <div className="text-white font-semibold">${parseFloat(position.mark_price || position.entry_price || 0).toLocaleString()}</div>
                  </div>
                  <div className="bg-[#0b0e11] rounded-lg p-3">
                    <div className="text-[#848e9c] text-xs mb-1">Margin</div>
                    <div className="text-white font-semibold">${parseFloat(position.margin_allocated || 0).toFixed(2)}</div>
                    {usedBonusMargin && (
                      <div className="text-amber-500 text-xs flex items-center gap-1 mt-1">
                        <Gift className="w-3 h-3" />
                        ${parseFloat(position.margin_from_locked_bonus || 0).toFixed(2)}
                      </div>
                    )}
                  </div>
                  <div className={`rounded-lg p-3 ${parseFloat(position.realized_pnl || 0) >= 0 ? 'bg-[#0ecb81]/10' : 'bg-[#f6465d]/10'}`}>
                    <div className="text-[#848e9c] text-xs mb-1">PNL</div>
                    <div className={`font-semibold flex items-center gap-1 ${pnlColor}`}>
                      {parseFloat(position.realized_pnl || 0) >= 0 ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
                      {parseFloat(position.realized_pnl || 0) >= 0 ? '+' : ''}${parseFloat(position.realized_pnl || 0).toFixed(2)}
                    </div>
                  </div>
                </div>

                <div className="mt-3 pt-3 border-t border-[#2b3139] flex items-center justify-between text-xs text-[#848e9c]">
                  <div className="flex items-center gap-4">
                    <span>Size: {parseFloat(position.quantity || 0).toFixed(4)}</span>
                    <span>Fees: -${parseFloat(position.cumulative_fees || 0).toFixed(2)}</span>
                  </div>
                  <button
                    onClick={() => setDetailsModal(position)}
                    className="p-2 bg-[#2b3139] hover:bg-[#474d57] text-[#848e9c] hover:text-white rounded-lg transition-colors"
                    title="View Details"
                  >
                    <FileText className="w-4 h-4" />
                  </button>
                </div>
              </div>
            );
          })}
        </div>

        {totalPages > 1 && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-[#2b3139] bg-[#0b0e11] flex-shrink-0 mt-4">
            <div className="text-sm text-[#848e9c]">
              Showing {((historyPage - 1) * historyPerPage) + 1}-{Math.min(historyPage * historyPerPage, historyTotal)} of {historyTotal} positions
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setHistoryPage(p => Math.max(1, p - 1))}
                disabled={historyPage === 1}
                className="p-2 bg-[#2b3139] hover:bg-[#474d57] disabled:bg-[#1e2329] disabled:text-[#848e9c] text-white rounded transition-colors"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <div className="flex items-center gap-1">
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  let pageNum: number;
                  if (totalPages <= 5) {
                    pageNum = i + 1;
                  } else if (historyPage <= 3) {
                    pageNum = i + 1;
                  } else if (historyPage >= totalPages - 2) {
                    pageNum = totalPages - 4 + i;
                  } else {
                    pageNum = historyPage - 2 + i;
                  }
                  return (
                    <button
                      key={pageNum}
                      onClick={() => setHistoryPage(pageNum)}
                      className={`w-8 h-8 rounded text-sm font-medium transition-colors ${
                        historyPage === pageNum
                          ? 'bg-[#f0b90b] text-[#0b0e11]'
                          : 'bg-[#2b3139] hover:bg-[#474d57] text-white'
                      }`}
                    >
                      {pageNum}
                    </button>
                  );
                })}
              </div>
              <button
                onClick={() => setHistoryPage(p => Math.min(totalPages, p + 1))}
                disabled={historyPage === totalPages}
                className="p-2 bg-[#2b3139] hover:bg-[#474d57] disabled:bg-[#1e2329] disabled:text-[#848e9c] text-white rounded transition-colors"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>
    );
  };

  if (loading) {
    return (
      <div className="h-64 bg-[#0b0e11] border-t border-gray-800 flex items-center justify-center">
        <p className="text-gray-400 text-sm">Loading...</p>
      </div>
    );
  }

  return (
    <>
      <ToastContainer toasts={toasts} removeToast={removeToast} />
      <div className="bg-[#0b0e11] border-t border-[#2b3139] flex flex-col h-full">
        <div className="px-4 py-3 border-b border-[#2b3139] flex items-center justify-between flex-shrink-0">
          <div className="flex items-center gap-6">
            <button
              onClick={() => setActiveTab('positions')}
              className={`text-sm font-medium pb-1 border-b-2 transition-colors ${
                activeTab === 'positions'
                  ? 'text-white border-[#f0b90b]'
                  : 'text-gray-400 border-transparent hover:text-gray-300'
              }`}
            >
              Positions ({positions.length})
            </button>
        <button
          onClick={() => setActiveTab('orders')}
          className={`text-sm font-medium pb-1 border-b-2 transition-colors ${
            activeTab === 'orders'
              ? 'text-white border-[#f0b90b]'
              : 'text-gray-400 border-transparent hover:text-gray-300'
          }`}
        >
          Open Orders ({orders.length})
        </button>
            <button
              onClick={() => setActiveTab('history')}
              className={`text-sm font-medium pb-1 border-b-2 transition-colors ${
                activeTab === 'history'
                  ? 'text-white border-[#f0b90b]'
                  : 'text-gray-400 border-transparent hover:text-gray-300'
              }`}
            >
              Position History
            </button>
          </div>
          {user && tpslMonitorService.isActive() && positions.some(p => p.take_profit || p.stop_loss) && (
            <div className="flex items-center gap-2 text-xs">
              <div className="relative">
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <div className="absolute inset-0 w-2 h-2 bg-green-500 rounded-full animate-ping"></div>
              </div>
              <span className="text-green-500 font-medium">TP/SL Monitor Active</span>
            </div>
          )}
        </div>

      <div className="flex-1 overflow-auto min-h-0 p-6">
        {activeTab === 'positions' && renderPositions()}
        {activeTab === 'orders' && renderOrders()}
        {activeTab === 'history' && renderHistory()}
      </div>
      </div>

      {tpslModal && (
        <TPSLModal
          position={tpslModal.position}
          mode={tpslModal.mode}
          onClose={() => setTpslModal(null)}
          onUpdate={() => {
            fetchPositions();
            showSuccess(`${tpslModal.mode === 'TP' ? 'Take Profit' : 'Stop Loss'} updated successfully`);
          }}
        />
      )}

      {detailsModal && (
        <PositionDetailsModal
          position={detailsModal}
          onClose={() => setDetailsModal(null)}
        />
      )}
    </>
  );
}

export default FuturesPositionsPanel;
