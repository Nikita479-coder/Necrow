import { useState, useEffect } from 'react';
import { TrendingUp, TrendingDown, Edit2, Save, X, DollarSign, Gift } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';

interface Props {
  userId: string;
  userData: any;
}

interface EditingPosition {
  positionId: string;
  mode: 'entry' | 'pnl';
  value: string;
}

export default function AdminUserTrading({ userId, userData }: Props) {
  const { user: adminUser } = useAuth();
  const [positions, setPositions] = useState<any[]>([]);
  const [orders, setOrders] = useState<any[]>([]);
  const [trades, setTrades] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<EditingPosition | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadTradingData();
    const interval = setInterval(loadTradingData, 3000);
    return () => clearInterval(interval);
  }, [userId]);

  const loadTradingData = async () => {
    setLoading(true);
    try {
      const [positionsRes, ordersRes, closedPositionsRes] = await Promise.all([
        supabase
          .from('futures_positions')
          .select('*')
          .eq('user_id', userId)
          .eq('status', 'open')
          .order('opened_at', { ascending: false }),
        supabase
          .from('futures_orders')
          .select('*')
          .eq('user_id', userId)
          .in('order_status', ['pending', 'partially_filled'])
          .order('created_at', { ascending: false })
          .limit(20),
        supabase
          .from('futures_positions')
          .select('position_id, pair, side, entry_price, mark_price, quantity, leverage, realized_pnl, closed_at, margin_allocated, margin_from_locked_bonus, cumulative_fees, opened_at')
          .eq('user_id', userId)
          .eq('status', 'closed')
          .order('closed_at', { ascending: false })
          .limit(50)
      ]);

      setPositions(positionsRes.data || []);
      setOrders(ordersRes.data || []);
      setTrades(closedPositionsRes.data || []);
    } catch (error) {
      console.error('Error loading trading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const startEditing = (positionId: string, mode: 'entry' | 'pnl', currentValue: number) => {
    setEditing({
      positionId,
      mode,
      value: currentValue.toString()
    });
  };

  const cancelEditing = () => {
    setEditing(null);
  };

  const saveEdit = async () => {
    if (!editing || !adminUser) return;

    setSaving(true);
    try {
      const value = parseFloat(editing.value);
      if (isNaN(value)) {
        alert('Invalid value');
        return;
      }

      if (editing.mode === 'entry') {
        const { data, error } = await supabase.rpc('admin_update_position_entry_price', {
          p_position_id: editing.positionId,
          p_new_entry_price: value,
          p_admin_user_id: adminUser.id
        });

        if (error) throw error;
        alert(`Entry price updated successfully!\nNew PnL: $${data.new_pnl.toFixed(2)}`);
      } else {
        const { data, error } = await supabase.rpc('admin_update_position_pnl', {
          p_position_id: editing.positionId,
          p_target_pnl: value,
          p_admin_user_id: adminUser.id
        });

        if (error) throw error;
        alert(`PnL updated successfully!\nNew Entry Price: $${data.new_entry_price.toFixed(2)}`);
      }

      setEditing(null);
      await loadTradingData();
    } catch (error: any) {
      console.error('Error updating position:', error);
      alert(`Error: ${error.message}`);
    } finally {
      setSaving(false);
    }
  };

  if (loading && positions.length === 0) {
    return (
      <div className="flex justify-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white mb-4">Open Positions ({positions.length})</h2>
        {positions.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <p className="text-gray-400">No open positions</p>
          </div>
        ) : (
          <div className="space-y-3">
            {positions.map((position) => {
              const isEditingEntry = editing?.positionId === position.position_id && editing?.mode === 'entry';
              const isEditingPnL = editing?.positionId === position.position_id && editing?.mode === 'pnl';

              return (
                <div key={position.position_id} className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800 hover:border-gray-700 transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-3">
                      <div className={`px-3 py-1 rounded-lg font-bold ${
                        position.side === 'long' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
                      }`}>
                        {position.side === 'long' ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
                      </div>
                      <div>
                        <div className="flex items-center gap-2">
                          <h3 className="text-white font-bold">{position.pair}</h3>
                          {parseFloat(position.margin_from_locked_bonus || 0) > 0 && (
                            <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-amber-500/10 text-amber-500 rounded text-[10px] font-medium" title="Bonus margin used">
                              <Gift className="w-3 h-3" />
                            </span>
                          )}
                        </div>
                        <p className="text-sm text-gray-400">{position.leverage}x {position.margin_mode}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="flex items-center gap-2">
                        {isEditingPnL ? (
                          <div className="flex items-center gap-2">
                            <input
                              type="number"
                              value={editing.value}
                              onChange={(e) => setEditing({ ...editing, value: e.target.value })}
                              className="w-32 px-2 py-1 bg-[#1a1d24] border border-gray-600 rounded text-white text-right"
                              step="0.01"
                              autoFocus
                            />
                            <button
                              onClick={saveEdit}
                              disabled={saving}
                              className="p-1 bg-green-500 hover:bg-green-600 rounded transition-colors disabled:opacity-50"
                            >
                              <Save className="w-4 h-4" />
                            </button>
                            <button
                              onClick={cancelEditing}
                              className="p-1 bg-gray-600 hover:bg-gray-700 rounded transition-colors"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                        ) : (
                          <>
                            <p className={`text-lg font-bold ${parseFloat(position.unrealized_pnl) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                              {parseFloat(position.unrealized_pnl) >= 0 ? '+' : ''}${parseFloat(position.unrealized_pnl).toFixed(2)}
                            </p>
                            <button
                              onClick={() => startEditing(position.position_id, 'pnl', parseFloat(position.unrealized_pnl))}
                              className="p-1 text-gray-400 hover:text-[#f0b90b] transition-colors"
                              title="Edit PnL (will calculate entry price)"
                            >
                              <DollarSign className="w-4 h-4" />
                            </button>
                          </>
                        )}
                      </div>
                      <p className="text-sm text-gray-400">Unrealized P&L</p>
                    </div>
                  </div>
                  <div className="grid grid-cols-4 gap-4 pt-3 border-t border-gray-800">
                    <div>
                      <p className="text-xs text-gray-400 mb-1">Entry Price</p>
                      {isEditingEntry ? (
                        <div className="flex items-center gap-1">
                          <input
                            type="number"
                            value={editing.value}
                            onChange={(e) => setEditing({ ...editing, value: e.target.value })}
                            className="w-24 px-2 py-1 bg-[#1a1d24] border border-gray-600 rounded text-white text-sm"
                            step="0.01"
                            autoFocus
                          />
                          <button
                            onClick={saveEdit}
                            disabled={saving}
                            className="p-1 bg-green-500 hover:bg-green-600 rounded transition-colors disabled:opacity-50"
                          >
                            <Save className="w-3 h-3" />
                          </button>
                          <button
                            onClick={cancelEditing}
                            className="p-1 bg-gray-600 hover:bg-gray-700 rounded transition-colors"
                          >
                            <X className="w-3 h-3" />
                          </button>
                        </div>
                      ) : (
                        <div className="flex items-center gap-2">
                          <p className="text-white font-medium">${parseFloat(position.entry_price).toFixed(2)}</p>
                          <button
                            onClick={() => startEditing(position.position_id, 'entry', parseFloat(position.entry_price))}
                            className="text-gray-400 hover:text-[#f0b90b] transition-colors"
                            title="Edit entry price"
                          >
                            <Edit2 className="w-3 h-3" />
                          </button>
                        </div>
                      )}
                    </div>
                    <div>
                      <p className="text-xs text-gray-400">Mark Price</p>
                      <p className="text-white font-medium">${parseFloat(position.mark_price || position.entry_price).toFixed(2)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-400">Liq. Price</p>
                      <p className="text-red-400 font-medium">${parseFloat(position.liquidation_price).toFixed(2)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-400">Margin</p>
                      <p className="text-white font-medium">${parseFloat(position.margin_allocated).toFixed(2)}</p>
                      {parseFloat(position.margin_from_locked_bonus || 0) > 0 && (
                        <div className="text-amber-500 text-xs flex items-center gap-1 mt-0.5">
                          <Gift className="w-3 h-3" />
                          ${parseFloat(position.margin_from_locked_bonus).toFixed(2)} bonus
                        </div>
                      )}
                    </div>
                  </div>
                  <div className="grid grid-cols-3 gap-4 pt-2">
                    <div>
                      <p className="text-xs text-gray-400">Quantity</p>
                      <p className="text-white text-sm">{parseFloat(position.quantity).toFixed(4)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-400">Opened</p>
                      <p className="text-white text-sm">{new Date(position.opened_at).toLocaleDateString()}</p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-400">Position ID</p>
                      <p className="text-white text-xs font-mono">{position.position_id.slice(0, 8)}...</p>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Active Orders ({orders.length})</h2>
        {orders.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <p className="text-gray-400">No active orders</p>
          </div>
        ) : (
          <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-gray-800">
                <tr>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Pair</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Side</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Type</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Price</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Quantity</th>
                  <th className="text-center py-3 px-4 text-sm font-medium text-gray-400">Status</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((order) => (
                  <tr key={order.order_id} className="border-b border-gray-800/50">
                    <td className="py-3 px-4 text-white font-medium">{order.pair}</td>
                    <td className="py-3 px-4">
                      <span className={`px-2 py-1 rounded text-xs font-bold ${
                        order.side === 'long' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
                      }`}>
                        {order.side.toUpperCase()}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-gray-400 text-sm">{order.order_type}</td>
                    <td className="py-3 px-4 text-right text-white">${parseFloat(order.price || 0).toFixed(2)}</td>
                    <td className="py-3 px-4 text-right text-white">{parseFloat(order.quantity).toFixed(4)}</td>
                    <td className="py-3 px-4 text-center">
                      <span className="px-2 py-1 bg-yellow-500/20 text-yellow-400 rounded text-xs">
                        {order.order_status}
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
        <h2 className="text-xl font-bold text-white mb-4">Recent Trades (Last 50)</h2>
        {trades.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <p className="text-gray-400">No closed positions</p>
          </div>
        ) : (
          <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-gray-800">
                <tr>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Closed</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Pair</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Side</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Entry</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Exit</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Size</th>
                  <th className="text-center py-3 px-4 text-sm font-medium text-gray-400">Leverage</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Margin</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Fees</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">P&L</th>
                </tr>
              </thead>
              <tbody>
                {trades.map((trade) => {
                  const usedBonusMargin = parseFloat(trade.margin_from_locked_bonus || 0) > 0;
                  const pnl = parseFloat(trade.realized_pnl || 0);
                  const bonusMarginPercent = trade.margin_allocated > 0
                    ? (parseFloat(trade.margin_from_locked_bonus || 0) / parseFloat(trade.margin_allocated || 1)) * 100
                    : 0;

                  return (
                    <tr key={trade.position_id} className="border-b border-gray-800/50 hover:bg-[#1a1d24]/30">
                      <td className="py-3 px-4 text-sm text-gray-400">
                        <div>{new Date(trade.closed_at).toLocaleDateString()}</div>
                        <div className="text-gray-500 text-xs">{new Date(trade.closed_at).toLocaleTimeString()}</div>
                      </td>
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2">
                          <span className="text-white font-medium">{trade.pair}</span>
                          {usedBonusMargin && (
                            <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-amber-500/10 text-amber-500 rounded text-[10px] font-medium" title="Bonus margin used">
                              <Gift className="w-3 h-3" />
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-3 px-4">
                        <span className={`px-2 py-1 rounded text-xs font-bold ${
                          trade.side === 'long' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
                        }`}>
                          {trade.side.toUpperCase()}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-right text-white">${parseFloat(trade.entry_price).toFixed(2)}</td>
                      <td className="py-3 px-4 text-right text-white">${parseFloat(trade.mark_price || trade.entry_price).toFixed(2)}</td>
                      <td className="py-3 px-4 text-right text-white">{parseFloat(trade.quantity).toFixed(4)}</td>
                      <td className="py-3 px-4 text-center">
                        <span className="px-2 py-1 bg-[#f0b90b]/10 text-[#f0b90b] rounded text-xs font-semibold">
                          {trade.leverage}x
                        </span>
                      </td>
                      <td className="py-3 px-4 text-right">
                        <div className="text-white">${parseFloat(trade.margin_allocated || 0).toFixed(2)}</div>
                        {usedBonusMargin && (
                          <div className="text-amber-500 text-xs flex items-center justify-end gap-1">
                            <Gift className="w-3 h-3" />
                            ${parseFloat(trade.margin_from_locked_bonus || 0).toFixed(2)}
                            <span className="text-gray-500">({bonusMarginPercent.toFixed(0)}%)</span>
                          </div>
                        )}
                      </td>
                      <td className="py-3 px-4 text-right text-orange-400">
                        -${parseFloat(trade.cumulative_fees || 0).toFixed(2)}
                      </td>
                      <td className={`py-3 px-4 text-right font-medium ${pnl >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                        {pnl >= 0 ? '+' : ''}${pnl.toFixed(2)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
