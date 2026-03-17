import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { useNavigation } from '../App';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { usePrices } from '../hooks/usePrices';
import {
  ArrowLeft,
  Wallet,
  TrendingUp,
  TrendingDown,
  Trophy,
  Target,
  BarChart3,
  X,
  Play,
  Square,
  RefreshCw
} from 'lucide-react';

interface MockPosition {
  position_id: string;
  pair: string;
  side: 'long' | 'short';
  quantity: number;
  entry_price: number;
  leverage: number;
  margin_allocated: number;
  liquidation_price: number;
  take_profit: number | null;
  stop_loss: number | null;
  opened_at: string;
}

interface MockSummary {
  wallet: {
    balance: number;
    locked_balance: number;
    total_equity: number;
  };
  positions: {
    open_count: number;
    total_margin: number;
  };
  performance: {
    total_trades: number;
    winning_trades: number;
    win_rate: number;
    total_pnl: number;
    roi: number;
  };
}

function MockTrading() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const { getTokenPrice } = usePrices();
  const [positions, setPositions] = useState<MockPosition[]>([]);
  const [summary, setSummary] = useState<MockSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [closingPosition, setClosingPosition] = useState<string | null>(null);
  const [stopping, setStopping] = useState(false);

  useEffect(() => {
    if (user) {
      loadMockData();
    }
  }, [user]);

  const loadMockData = async () => {
    if (!user) return;

    try {
      const [summaryResult, positionsResult] = await Promise.all([
        supabase.rpc('get_mock_trading_summary'),
        supabase
          .from('mock_futures_positions')
          .select('*')
          .eq('user_id', user.id)
          .eq('status', 'open')
          .order('opened_at', { ascending: false })
      ]);

      if (summaryResult.data?.success) {
        setSummary(summaryResult.data as MockSummary);
      }

      if (positionsResult.data) {
        setPositions(positionsResult.data.map(p => ({
          position_id: p.position_id,
          pair: p.pair,
          side: p.side,
          quantity: parseFloat(p.quantity),
          entry_price: parseFloat(p.entry_price),
          leverage: p.leverage,
          margin_allocated: parseFloat(p.margin_allocated),
          liquidation_price: parseFloat(p.liquidation_price),
          take_profit: p.take_profit ? parseFloat(p.take_profit) : null,
          stop_loss: p.stop_loss ? parseFloat(p.stop_loss) : null,
          opened_at: p.opened_at
        })));
      }
    } catch (error) {
      console.error('Error loading mock data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleClosePosition = async (positionId: string, pair: string) => {
    setClosingPosition(positionId);
    try {
      const symbol = pair.replace('USDT', '');
      const currentPrice = getTokenPrice(symbol);

      const { data, error } = await supabase.rpc('close_mock_position', {
        p_position_id: positionId,
        p_close_price: currentPrice
      });

      if (error) throw error;

      if (data?.success) {
        await loadMockData();
      } else {
        alert(data?.error || 'Failed to close position');
      }
    } catch (error: any) {
      console.error('Error closing position:', error);
      alert(error.message || 'Failed to close position');
    } finally {
      setClosingPosition(null);
    }
  };

  const handleStopMockTrading = async () => {
    if (!confirm('This will close all positions and reset your mock balance to $10,000. Continue?')) {
      return;
    }

    setStopping(true);
    try {
      const { data, error } = await supabase.rpc('stop_mock_trading');

      if (error) throw error;

      if (data?.success) {
        await loadMockData();
      } else {
        alert(data?.error || 'Failed to stop mock trading');
      }
    } catch (error: any) {
      console.error('Error stopping mock trading:', error);
      alert(error.message || 'Failed to stop mock trading');
    } finally {
      setStopping(false);
    }
  };

  const calculatePnL = (position: MockPosition) => {
    const symbol = position.pair.replace('USDT', '');
    const currentPrice = getTokenPrice(symbol);

    if (position.side === 'long') {
      return (currentPrice - position.entry_price) * position.quantity;
    } else {
      return (position.entry_price - currentPrice) * position.quantity;
    }
  };

  const calculateROE = (position: MockPosition) => {
    const pnl = calculatePnL(position);
    return (pnl / position.margin_allocated) * 100;
  };

  const totalUnrealizedPnL = positions.reduce((sum, p) => sum + calculatePnL(p), 0);

  if (!user) {
    return (
      <div className="min-h-screen bg-[#0b0e11] text-white">
        <Navbar />
        <div className="max-w-[1400px] mx-auto px-6 py-12 text-center">
          <p className="text-[#848e9c]">Please sign in to access mock trading</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-4 md:px-6 py-4">
        <button
          onClick={() => navigateTo('futures')}
          className="flex items-center gap-1 text-gray-400 hover:text-white transition-colors text-sm mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Trading
        </button>

        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
          <div>
            <h1 className="text-2xl font-bold text-white mb-1">Mock Trading</h1>
            <p className="text-[#848e9c] text-sm">Practice trading with virtual funds - no real money at risk</p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={() => navigateTo('futures')}
              className="flex items-center gap-2 bg-[#fcd535] hover:bg-[#f0b90b] text-black font-medium px-4 py-2 rounded-lg transition-colors"
            >
              <Play className="w-4 h-4" />
              Open Mock Trade
            </button>
            <button
              onClick={handleStopMockTrading}
              disabled={stopping}
              className="flex items-center gap-2 bg-transparent hover:bg-[#f6465d]/10 border border-[#f6465d] text-[#f6465d] font-medium px-4 py-2 rounded-lg transition-colors disabled:opacity-50"
            >
              {stopping ? (
                <RefreshCw className="w-4 h-4 animate-spin" />
              ) : (
                <Square className="w-4 h-4" />
              )}
              {stopping ? 'Resetting...' : 'Reset Mock Trading'}
            </button>
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="w-8 h-8 border-2 border-[#fcd535] border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <>
            {summary && (
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                <div className="bg-[#1e2329] rounded-xl p-4 border border-[#2b3139]">
                  <div className="flex items-center gap-2 mb-2">
                    <Wallet className="w-4 h-4 text-[#fcd535]" />
                    <span className="text-[#848e9c] text-sm">Available Balance</span>
                  </div>
                  <div className="text-xl font-bold text-white">
                    ${summary.wallet.balance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </div>
                  <div className="text-xs text-[#848e9c] mt-1">
                    Locked: ${summary.wallet.locked_balance.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                  </div>
                </div>

                <div className="bg-[#1e2329] rounded-xl p-4 border border-[#2b3139]">
                  <div className="flex items-center gap-2 mb-2">
                    <BarChart3 className="w-4 h-4 text-[#fcd535]" />
                    <span className="text-[#848e9c] text-sm">Total Equity</span>
                  </div>
                  <div className="text-xl font-bold text-white">
                    ${(summary.wallet.total_equity + totalUnrealizedPnL).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </div>
                  <div className={`text-xs mt-1 ${summary.performance.roi >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                    {summary.performance.roi >= 0 ? '+' : ''}{((summary.wallet.total_equity + totalUnrealizedPnL - 10000) / 100).toFixed(2)}% from start
                  </div>
                </div>

                <div className="bg-[#1e2329] rounded-xl p-4 border border-[#2b3139]">
                  <div className="flex items-center gap-2 mb-2">
                    <Trophy className="w-4 h-4 text-[#fcd535]" />
                    <span className="text-[#848e9c] text-sm">Win Rate</span>
                  </div>
                  <div className="text-xl font-bold text-white">
                    {summary.performance.win_rate}%
                  </div>
                  <div className="text-xs text-[#848e9c] mt-1">
                    {summary.performance.winning_trades}/{summary.performance.total_trades} trades won
                  </div>
                </div>

                <div className="bg-[#1e2329] rounded-xl p-4 border border-[#2b3139]">
                  <div className="flex items-center gap-2 mb-2">
                    <Target className="w-4 h-4 text-[#fcd535]" />
                    <span className="text-[#848e9c] text-sm">Realized PnL</span>
                  </div>
                  <div className={`text-xl font-bold ${summary.performance.total_pnl >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                    {summary.performance.total_pnl >= 0 ? '+' : ''}${summary.performance.total_pnl.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </div>
                  <div className={`text-xs mt-1 ${totalUnrealizedPnL >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                    Unrealized: {totalUnrealizedPnL >= 0 ? '+' : ''}${totalUnrealizedPnL.toFixed(2)}
                  </div>
                </div>
              </div>
            )}

            <div className="bg-[#1e2329] rounded-xl border border-[#2b3139]">
              <div className="px-4 py-3 border-b border-[#2b3139] flex items-center justify-between">
                <h2 className="text-white font-semibold">Open Positions ({positions.length})</h2>
              </div>

              {positions.length === 0 ? (
                <div className="text-center py-12">
                  <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-[#2b3139] flex items-center justify-center">
                    <BarChart3 className="w-8 h-8 text-[#848e9c]" />
                  </div>
                  <p className="text-[#848e9c] mb-4">No open mock positions</p>
                  <button
                    onClick={() => navigateTo('futures')}
                    className="bg-[#fcd535] hover:bg-[#f0b90b] text-black font-medium px-6 py-2 rounded-lg transition-colors"
                  >
                    Start Mock Trading
                  </button>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="text-[#848e9c] text-xs border-b border-[#2b3139]">
                        <th className="text-left px-4 py-3 font-normal">Pair</th>
                        <th className="text-left px-4 py-3 font-normal">Side</th>
                        <th className="text-right px-4 py-3 font-normal">Size</th>
                        <th className="text-right px-4 py-3 font-normal">Entry Price</th>
                        <th className="text-right px-4 py-3 font-normal">Mark Price</th>
                        <th className="text-right px-4 py-3 font-normal">Liq. Price</th>
                        <th className="text-right px-4 py-3 font-normal">Margin</th>
                        <th className="text-right px-4 py-3 font-normal">PnL (ROE%)</th>
                        <th className="text-center px-4 py-3 font-normal">Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {positions.map((position) => {
                        const symbol = position.pair.replace('USDT', '');
                        const currentPrice = getTokenPrice(symbol);
                        const pnl = calculatePnL(position);
                        const roe = calculateROE(position);

                        return (
                          <tr key={position.position_id} className="border-b border-[#2b3139] hover:bg-[#2b3139]/30">
                            <td className="px-4 py-3">
                              <div className="flex items-center gap-2">
                                <span className="text-white font-medium">{position.pair}</span>
                                <span className="text-[#fcd535] text-xs">{position.leverage}x</span>
                              </div>
                            </td>
                            <td className="px-4 py-3">
                              <span className={`flex items-center gap-1 text-sm ${
                                position.side === 'long' ? 'text-[#0ecb81]' : 'text-[#f6465d]'
                              }`}>
                                {position.side === 'long' ? (
                                  <TrendingUp className="w-3 h-3" />
                                ) : (
                                  <TrendingDown className="w-3 h-3" />
                                )}
                                {position.side.toUpperCase()}
                              </span>
                            </td>
                            <td className="px-4 py-3 text-right text-white">
                              {position.quantity.toFixed(4)}
                            </td>
                            <td className="px-4 py-3 text-right text-white">
                              ${position.entry_price.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                            </td>
                            <td className="px-4 py-3 text-right text-white">
                              ${currentPrice.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                            </td>
                            <td className="px-4 py-3 text-right text-[#f6465d]">
                              ${position.liquidation_price.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                            </td>
                            <td className="px-4 py-3 text-right text-white">
                              ${position.margin_allocated.toFixed(2)}
                            </td>
                            <td className="px-4 py-3 text-right">
                              <div className={pnl >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}>
                                <div>{pnl >= 0 ? '+' : ''}{pnl.toFixed(2)} USDT</div>
                                <div className="text-xs">({roe >= 0 ? '+' : ''}{roe.toFixed(2)}%)</div>
                              </div>
                            </td>
                            <td className="px-4 py-3 text-center">
                              <button
                                onClick={() => handleClosePosition(position.position_id, position.pair)}
                                disabled={closingPosition === position.position_id}
                                className="flex items-center gap-1 mx-auto bg-transparent hover:bg-[#f6465d]/10 border border-[#f6465d] text-[#f6465d] px-3 py-1 rounded text-sm transition-colors disabled:opacity-50"
                              >
                                {closingPosition === position.position_id ? (
                                  <RefreshCw className="w-3 h-3 animate-spin" />
                                ) : (
                                  <X className="w-3 h-3" />
                                )}
                                Close
                              </button>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

            <div className="mt-6 bg-[#fcd535]/10 border border-[#fcd535]/30 rounded-xl p-4">
              <div className="flex items-start gap-3">
                <div className="w-8 h-8 rounded-full bg-[#fcd535]/20 flex items-center justify-center flex-shrink-0">
                  <Target className="w-4 h-4 text-[#fcd535]" />
                </div>
                <div>
                  <h3 className="text-white font-medium mb-1">About Mock Trading</h3>
                  <p className="text-[#848e9c] text-sm">
                    Mock trading lets you practice with $10,000 in virtual funds. Your trades work exactly like real trades
                    but without any financial risk. Perfect for testing strategies before using real money.
                  </p>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export default MockTrading;
