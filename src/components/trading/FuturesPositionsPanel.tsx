import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';
import { X, Edit2, FileText } from 'lucide-react';
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
        .select('position_id, user_id, pair, side, entry_price, mark_price, quantity, leverage, margin_mode, unrealized_pnl, liquidation_price, stop_loss, take_profit, margin_allocated, overnight_fees_accrued, opened_at, status')
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

  const fetchHistory = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('futures_positions')
        .select('*')
        .eq('user_id', user.id)
        .eq('status', 'closed')
        .order('closed_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      setHistory(data || []);
    } catch (error) {
      console.error('Error fetching history:', error);
    }
  };

  const handleClosePosition = async (positionId: string) => {
    setClosingPosition(positionId);
    try {
      const position = positions.find(p => p.position_id === positionId);

      const { data, error } = await supabase.rpc('close_position', {
        p_position_id: positionId,
        p_close_quantity: null,
        p_close_price: null
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

  const calculateRealTimePnL = (position: Position, currentPrice: number): number => {
    if (currentPrice === 0) return position.unrealized_pnl;

    const priceDiff = position.side === 'long'
      ? currentPrice - position.entry_price
      : position.entry_price - currentPrice;

    return priceDiff * position.quantity;
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
        <div className="p-8 flex flex-col items-center justify-center text-center">
          <div className="w-16 h-16 mb-4 bg-gray-800 rounded-full flex items-center justify-center">
            <svg className="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <p className="text-gray-400 text-sm">No open positions</p>
        </div>
      );
    }

    return (
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="border-b border-gray-800">
            <tr className="text-gray-400 text-xs">
              <th className="text-left px-4 py-2 font-medium">Pair</th>
              <th className="text-left px-4 py-2 font-medium">Side</th>
              <th className="text-right px-4 py-2 font-medium">Size</th>
              <th className="text-right px-4 py-2 font-medium">Entry</th>
              <th className="text-right px-4 py-2 font-medium">Mark</th>
              <th className="text-right px-4 py-2 font-medium">Liq. Price</th>
              <th className="text-right px-4 py-2 font-medium">Margin</th>
              <th className="text-right px-4 py-2 font-medium">PnL (USDT)</th>
              <th className="text-right px-4 py-2 font-medium">ROE</th>
              <th className="text-right px-4 py-2 font-medium">Fees</th>
              <th className="text-center px-4 py-2 font-medium">TP/SL</th>
              <th className="text-center px-4 py-2 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody>
            {positions.map((position) => {
              const realTimeMarkPrice = getRealTimeMarkPrice(position.pair);
              const currentMarkPrice = realTimeMarkPrice > 0 ? realTimeMarkPrice : position.mark_price;
              const realTimePnL = realTimeMarkPrice > 0 ? calculateRealTimePnL(position, realTimeMarkPrice) : position.unrealized_pnl;
              const roe = calculateROE(realTimePnL, position.margin_allocated);
              const liqDistance = getLiquidationDistance(position.side, currentMarkPrice, position.liquidation_price ?? 0);
              const pnlColor = realTimePnL >= 0 ? 'text-green-500' : 'text-red-500';
              const sideColor = position.side === 'long' ? 'text-green-500' : 'text-red-500';

              return (
                <tr key={position.position_id} className="border-b border-gray-800 hover:bg-gray-900/30">
                  <td className="px-4 py-3 text-white font-medium">{position.pair}</td>
                  <td className={`px-4 py-3 font-semibold ${sideColor}`}>
                    {position.side.toUpperCase()}
                  </td>
                  <td className="px-4 py-3 text-right text-gray-300">
                    {position.quantity.toFixed(4)}
                    <div className="text-xs text-gray-500">{position.leverage}x</div>
                  </td>
                  <td className="px-4 py-3 text-right text-gray-300">
                    ${position.entry_price.toFixed(2)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex items-center justify-end gap-1">
                      <span className="text-gray-300">${currentMarkPrice.toFixed(2)}</span>
                      {realTimeMarkPrice > 0 && (
                        <div className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" title="Real-time price"></div>
                      )}
                    </div>
                  </td>
                  <td className={`px-4 py-3 text-right ${getMarginHealthColor(liqDistance)}`}>
                    ${(position.liquidation_price ?? 0).toFixed(2)}
                    <div className="text-xs text-gray-500">
                      {liqDistance.toFixed(1)}%
                    </div>
                  </td>
                  <td className="px-4 py-3 text-right text-gray-300">
                    <div className="text-xs text-gray-500">{position.margin_mode}</div>
                    <div>${position.margin_allocated.toFixed(2)}</div>
                  </td>
                  <td className={`px-4 py-3 text-right font-semibold ${pnlColor}`}>
                    {realTimePnL >= 0 ? '+' : ''}
                    {realTimePnL.toFixed(2)}
                  </td>
                  <td className={`px-4 py-3 text-right font-semibold ${pnlColor}`}>
                    {roe >= 0 ? '+' : ''}
                    {roe.toFixed(2)}%
                  </td>
                  <td className="px-4 py-3 text-right text-orange-400">
                    -${(position.overnight_fees_accrued || 0).toFixed(2)}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <div className="flex flex-col gap-1">
                      <button
                        onClick={() => setTpslModal({ position, mode: 'TP' })}
                        className="text-xs hover:bg-green-500/10 px-2 py-1 rounded transition-colors"
                      >
                        {position.take_profit ? (
                          <div className="flex flex-col">
                            <span className="text-green-500">${position.take_profit.toFixed(2)}</span>
                            <span className="text-green-400 text-[10px]">
                              +${((position.take_profit - position.entry_price) * position.quantity * (position.side === 'long' ? 1 : -1)).toFixed(2)}
                            </span>
                            <span className={`text-[10px] ${
                              Math.abs(((position.take_profit - currentMarkPrice) / currentMarkPrice) * 100) < 0.5
                                ? 'text-yellow-400 animate-pulse'
                                : 'text-gray-500'
                            }`}>
                              {position.side === 'long'
                                ? ((position.take_profit - currentMarkPrice) / currentMarkPrice * 100).toFixed(2)
                                : ((currentMarkPrice - position.take_profit) / currentMarkPrice * 100).toFixed(2)
                              }% away
                            </span>
                          </div>
                        ) : (
                          <span className="text-gray-500">Set TP</span>
                        )}
                      </button>
                      <button
                        onClick={() => setTpslModal({ position, mode: 'SL' })}
                        className="text-xs hover:bg-red-500/10 px-2 py-1 rounded transition-colors"
                      >
                        {position.stop_loss ? (
                          <div className="flex flex-col">
                            <span className="text-red-500">${position.stop_loss.toFixed(2)}</span>
                            <span className="text-red-400 text-[10px]">
                              -${Math.abs((position.stop_loss - position.entry_price) * position.quantity * (position.side === 'long' ? 1 : -1)).toFixed(2)}
                            </span>
                            <span className={`text-[10px] ${
                              Math.abs(((position.stop_loss - currentMarkPrice) / currentMarkPrice) * 100) < 0.5
                                ? 'text-yellow-400 animate-pulse'
                                : 'text-gray-500'
                            }`}>
                              {position.side === 'long'
                                ? ((currentMarkPrice - position.stop_loss) / currentMarkPrice * 100).toFixed(2)
                                : ((position.stop_loss - currentMarkPrice) / currentMarkPrice * 100).toFixed(2)
                              }% away
                            </span>
                          </div>
                        ) : (
                          <span className="text-gray-500">Set SL</span>
                        )}
                      </button>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-center">
                    <div className="flex items-center justify-center gap-2">
                      <button
                        onClick={() => setDetailsModal(position)}
                        className="p-2 bg-gray-700/50 hover:bg-gray-700 text-gray-300 rounded transition-colors"
                        title="View Details"
                      >
                        <FileText className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleClosePosition(position.position_id)}
                        disabled={closingPosition === position.position_id}
                        className="px-3 py-1 bg-red-500/20 hover:bg-red-500/30 disabled:bg-gray-700 disabled:cursor-not-allowed text-red-500 disabled:text-gray-500 rounded text-xs font-medium transition-colors"
                      >
                        {closingPosition === position.position_id ? 'Closing...' : 'Close'}
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    );
  };

  const renderOrders = () => {
    if (orders.length === 0) {
      return (
        <div className="p-8 flex flex-col items-center justify-center text-center">
          <div className="w-16 h-16 mb-4 bg-gray-800 rounded-full flex items-center justify-center">
            <svg className="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
          </div>
          <p className="text-gray-400 text-sm">No pending orders</p>
        </div>
      );
    }

    return (
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="border-b border-gray-800">
            <tr className="text-gray-400 text-xs">
              <th className="text-left px-4 py-2 font-medium">Time</th>
              <th className="text-left px-4 py-2 font-medium">Pair</th>
              <th className="text-left px-4 py-2 font-medium">Type</th>
              <th className="text-left px-4 py-2 font-medium">Side</th>
              <th className="text-right px-4 py-2 font-medium">Price</th>
              <th className="text-right px-4 py-2 font-medium">Amount</th>
              <th className="text-center px-4 py-2 font-medium">Leverage</th>
              <th className="text-center px-4 py-2 font-medium">Status</th>
              <th className="text-center px-4 py-2 font-medium">Action</th>
            </tr>
          </thead>
          <tbody>
            {orders.map((order) => {
              const sideColor = order.side === 'long' ? 'text-green-500' : 'text-red-500';

              return (
                <tr key={order.order_id} className="border-b border-gray-800 hover:bg-gray-900/30">
                  <td className="px-4 py-3 text-gray-400 text-xs">
                    {new Date(order.created_at).toLocaleString()}
                  </td>
                  <td className="px-4 py-3 text-white font-medium">{order.pair}</td>
                  <td className="px-4 py-3 text-gray-300 capitalize">{order.order_type}</td>
                  <td className={`px-4 py-3 font-semibold ${sideColor}`}>
                    {order.side.toUpperCase()}
                  </td>
                  <td className="px-4 py-3 text-right text-gray-300">
                    {order.price ? `$${order.price.toFixed(2)}` : 'Market'}
                  </td>
                  <td className="px-4 py-3 text-right text-gray-300">
                    {order.quantity.toFixed(4)}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <span className="px-2 py-1 bg-[#f0b90b]/10 text-[#f0b90b] rounded text-xs font-semibold">
                      {order.leverage}x
                    </span>
                  </td>
                  <td className="px-4 py-3 text-center">
                    <span className="px-2 py-1 bg-yellow-500/10 text-yellow-500 rounded text-xs">
                      {order.order_status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-center">
                    <button
                      onClick={() => handleCancelOrder(order.order_id)}
                      className="px-3 py-1 bg-gray-700 hover:bg-gray-600 text-gray-300 rounded text-xs font-medium transition-colors"
                    >
                      Cancel
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    );
  };

  const renderHistory = () => {
    if (history.length === 0) {
      return (
        <div className="p-8 flex flex-col items-center justify-center text-center">
          <div className="w-16 h-16 mb-4 bg-gray-800 rounded-full flex items-center justify-center">
            <svg className="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <p className="text-gray-400 text-sm">No position history</p>
        </div>
      );
    }

    return (
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="border-b border-gray-800">
            <tr className="text-gray-400 text-xs">
              <th className="text-left px-4 py-2 font-medium">Closed At</th>
              <th className="text-left px-4 py-2 font-medium">Pair</th>
              <th className="text-left px-4 py-2 font-medium">Side</th>
              <th className="text-right px-4 py-2 font-medium">Entry</th>
              <th className="text-right px-4 py-2 font-medium">Close</th>
              <th className="text-right px-4 py-2 font-medium">Size</th>
              <th className="text-center px-4 py-2 font-medium">Leverage</th>
              <th className="text-right px-4 py-2 font-medium">Realized PnL</th>
              <th className="text-center px-4 py-2 font-medium">Details</th>
            </tr>
          </thead>
          <tbody>
            {history.map((position) => {
              const pnlColor = parseFloat(position.realized_pnl || 0) >= 0 ? 'text-green-500' : 'text-red-500';
              const sideColor = position.side === 'long' ? 'text-green-500' : 'text-red-500';

              return (
                <tr key={position.position_id} className="border-b border-gray-800 hover:bg-gray-900/30">
                  <td className="px-4 py-3 text-gray-400 text-xs">
                    {new Date(position.closed_at).toLocaleString()}
                  </td>
                  <td className="px-4 py-3 text-white font-medium">{position.pair}</td>
                  <td className={`px-4 py-3 font-semibold ${sideColor}`}>
                    {position.side.toUpperCase()}
                  </td>
                  <td className="px-4 py-3 text-right text-gray-300">
                    ${parseFloat(position.entry_price || 0).toFixed(2)}
                  </td>
                  <td className="px-4 py-3 text-right text-gray-300">
                    ${parseFloat(position.mark_price || position.entry_price || 0).toFixed(2)}
                  </td>
                  <td className="px-4 py-3 text-right text-gray-300">
                    {parseFloat(position.quantity || 0).toFixed(4)}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <span className="px-2 py-1 bg-[#f0b90b]/10 text-[#f0b90b] rounded text-xs font-semibold">
                      {position.leverage}x
                    </span>
                  </td>
                  <td className={`px-4 py-3 text-right font-semibold ${pnlColor}`}>
                    {parseFloat(position.realized_pnl || 0) >= 0 ? '+' : ''}
                    ${parseFloat(position.realized_pnl || 0).toFixed(2)}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <button
                      onClick={() => setDetailsModal(position)}
                      className="p-2 bg-gray-700/50 hover:bg-gray-700 text-gray-300 rounded transition-colors"
                      title="View Details"
                    >
                      <FileText className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
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
      <div className="bg-[#0b0e11] border-t border-gray-800 overflow-hidden flex flex-col">
        <div className="px-4 py-3 border-b border-gray-800 flex items-center justify-between">
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

      <div className="flex-1 overflow-auto">
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
