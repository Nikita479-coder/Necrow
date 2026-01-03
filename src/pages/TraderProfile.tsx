import { useState, useEffect } from 'react';
import { useNavigation } from '../App';
import { ArrowLeft, Star, TrendingUp, TrendingDown, Users, Shield, Activity, Lock, History } from 'lucide-react';
import { supabase } from '../lib/supabase';
import Navbar from '../components/Navbar';
import CryptoIcon from '../components/CryptoIcon';
import CopyTradingModal from '../components/CopyTradingModal';

interface TraderData {
  id: string;
  name: string;
  avatar: string;
  rank: number;
  total_rank: number;
  api_verified: boolean;
  pnl_30d: number;
  roi_30d: number;
  roi_7d: number;
  roi_90d: number;
  roi_all_time: number;
  pnl_7d: number;
  pnl_90d: number;
  pnl_all_time: number;
  aum: number;
  mdd_30d: number;
  sharpe_ratio: number;
  followers_count: number;
  win_rate: number;
  total_trades: number;
  win_streak: number;
  loss_streak: number;
  max_win_streak: number;
  profitable_days: number;
  trading_days: number;
  avg_win_rate_7d: number;
  avg_win_rate_90d: number;
  best_trade_pnl: number;
  worst_trade_pnl: number;
  volatility_score: number;
  consistency_score: number;
  trading_style: string;
  risk_level: string;
  avg_leverage: number;
  favorite_pairs: string[];
  monthly_return: number;
  total_volume: number;
  avg_hold_time_hours: number;
}

const generateRandomUserIds = () => {
  const prefixes = ['Use***', 'Pro***', 'Mer**', 'Tra**', 'Inv***'];
  const names = ['857', '1d7', 'efd', '91d', '154', '024', 'a8c', 'f23', '7x9', 'k5m', 'p2w', 'q8r'];
  const specialChars = ['小草', '山**本', '李**明', '王**芳', '陈**华', '张**伟'];

  const allOptions = [
    ...prefixes.map(p => p + names[Math.floor(Math.random() * names.length)]),
    ...specialChars
  ];

  return allOptions.sort(() => Math.random() - 0.5).slice(0, 9);
};

const generateCopyTraders = (traderId: string) => {
  const seed = traderId.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
  const random = (min: number, max: number, index: number) => {
    const x = Math.sin(seed + index) * 10000;
    return min + (x - Math.floor(x)) * (max - min);
  };

  const userIds = generateRandomUserIds();

  return Array.from({ length: 9 }, (_, i) => {
    const balance = random(2000, 12000, i);
    const roiPercent = random(20, 95, i + 100);
    const pnl = (balance * roiPercent) / (100 + roiPercent);

    return {
      id: i + 1,
      userId: userIds[i],
      balance: parseFloat(balance.toFixed(2)),
      pnl: parseFloat(pnl.toFixed(2)),
      roi: parseFloat(roiPercent.toFixed(2)),
      duration: Math.floor(random(10, 25, i + 200))
    };
  }).sort((a, b) => b.pnl - a.pnl);
};

interface TraderPosition {
  id: string;
  symbol: string;
  side: string;
  entry_price: number;
  quantity: number;
  leverage: number;
  status: string;
  opened_at: string;
}

export default function TraderProfile() {
  const { navigateTo } = useNavigation();
  const [trader, setTrader] = useState<TraderData | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedPeriod, setSelectedPeriod] = useState<'7d' | '30d' | '90d' | 'all'>('30d');
  const [isFavorite, setIsFavorite] = useState(false);
  const [activeTab, setActiveTab] = useState<'positions' | 'history' | 'records' | 'transfer' | 'copytraders'>('positions');
  const [showCopyModal, setShowCopyModal] = useState(false);
  const [showMockCopyModal, setShowMockCopyModal] = useState(false);
  const [openPositions, setOpenPositions] = useState<TraderPosition[]>([]);
  const [closedPositions, setClosedPositions] = useState<TraderPosition[]>([]);
  const [copyTraders, setCopyTraders] = useState<Array<{
    id: number;
    userId: string;
    balance: number;
    pnl: number;
    roi: number;
    duration: number;
  }>>([]);

  useEffect(() => {
    const checkAndFetchTrader = () => {
      const params = new URLSearchParams(window.location.search);
      const traderId = params.get('id');

      if (traderId) {
        fetchTraderData(traderId);
      } else {
        navigateTo('copytrading');
      }
    };

    checkAndFetchTrader();

    const handlePopState = () => {
      checkAndFetchTrader();
    };

    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, [navigateTo]);

  const fetchTraderData = async (traderId: string) => {
    try {
      const { data, error } = await supabase
        .from('traders')
        .select('*')
        .eq('id', traderId)
        .maybeSingle();

      if (error) throw error;

      if (data) {
        setTrader(data);
        setCopyTraders(generateCopyTraders(traderId));
        loadTraderPositions(traderId);
      }
    } catch (error) {
      console.error('Error fetching trader:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadTraderPositions = async (traderId: string) => {
    try {
      // Load open positions
      const { data: openData, error: openError } = await supabase
        .from('trader_trades')
        .select('*')
        .eq('trader_id', traderId)
        .eq('status', 'open')
        .order('opened_at', { ascending: false });

      if (openError) throw openError;
      setOpenPositions(openData || []);

      // Load closed positions (last 20)
      const { data: closedData, error: closedError } = await supabase
        .from('trader_trades')
        .select('*')
        .eq('trader_id', traderId)
        .in('status', ['closed', 'liquidated'])
        .order('closed_at', { ascending: false })
        .limit(20);

      if (closedError) throw closedError;
      setClosedPositions(closedData || []);
    } catch (error) {
      console.error('Error loading trader positions:', error);
    }
  };

  const getROIByPeriod = () => {
    if (!trader) return 0;
    switch (selectedPeriod) {
      case '7d': return trader.roi_7d;
      case '30d': return trader.roi_30d;
      case '90d': return trader.roi_90d;
      case 'all': return trader.roi_all_time;
      default: return trader.roi_30d;
    }
  };

  const getPNLByPeriod = () => {
    if (!trader) return 0;
    switch (selectedPeriod) {
      case '7d': return trader.pnl_7d;
      case '30d': return trader.pnl_30d;
      case '90d': return trader.pnl_90d;
      case 'all': return trader.pnl_all_time;
      default: return trader.pnl_30d;
    }
  };

  const getWinRateByPeriod = () => {
    if (!trader) return 0;
    switch (selectedPeriod) {
      case '7d': return trader.avg_win_rate_7d;
      case '30d': return trader.win_rate;
      case '90d': return trader.avg_win_rate_90d;
      case 'all': return trader.win_rate;
      default: return trader.win_rate;
    }
  };

  const getRiskBadgeColor = (risk: string) => {
    switch (risk) {
      case 'low': return 'bg-green-500/20 text-green-400';
      case 'medium': return 'bg-yellow-500/20 text-yellow-400';
      case 'high': return 'bg-red-500/20 text-red-400';
      default: return 'bg-gray-500/20 text-gray-400';
    }
  };

  const getStyleBadgeColor = (style: string) => {
    switch (style) {
      case 'scalper': return 'bg-purple-500/20 text-purple-400';
      case 'day_trader': return 'bg-blue-500/20 text-blue-400';
      case 'swing': return 'bg-cyan-500/20 text-cyan-400';
      case 'position': return 'bg-indigo-500/20 text-indigo-400';
      default: return 'bg-gray-500/20 text-gray-400';
    }
  };

  const formatHoldTime = (hours: number) => {
    if (hours < 1) return `${Math.round(hours * 60)}m`;
    if (hours < 24) return `${Math.round(hours)}h`;
    return `${Math.round(hours / 24)}d`;
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0b0e11] flex items-center justify-center">
        <div className="text-white">Loading...</div>
      </div>
    );
  }

  if (!trader) {
    return (
      <div className="min-h-screen bg-[#0b0e11] flex items-center justify-center">
        <div className="text-white">Trader not found</div>
      </div>
    );
  }

  const roi = getROIByPeriod();
  const pnl = getPNLByPeriod();
  const winRate = getWinRateByPeriod();

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />
      <div className="p-3 sm:p-6">
      <button
        onClick={() => {
          window.history.back();
          navigateTo('copytrading');
        }}
        className="flex items-center gap-2 text-[#848e9c] hover:text-white mb-6 transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to Copy Trading
      </button>

      <div className="max-w-7xl mx-auto space-y-4 sm:space-y-6">
        <div className="bg-[#2b3139] rounded-lg p-4 sm:p-6">
          <div className="flex items-start justify-between mb-4 sm:mb-6">
            <div className="flex items-start gap-3 sm:gap-4">
              <div className="text-4xl sm:text-5xl">{trader.avatar}</div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 sm:gap-3 mb-2 flex-wrap">
                  <h1 className="text-xl sm:text-3xl font-bold">{trader.name}</h1>
                  {trader.api_verified && (
                    <span className="bg-blue-500/20 text-blue-400 text-[10px] sm:text-xs px-1.5 sm:px-2 py-0.5 sm:py-1 rounded font-medium whitespace-nowrap">API Verified</span>
                  )}
                </div>
                <div className="flex flex-wrap gap-1.5 sm:gap-2 mb-2">
                  <span className={`text-[10px] sm:text-xs px-1.5 sm:px-2 py-0.5 sm:py-1 rounded font-medium whitespace-nowrap ${getRiskBadgeColor(trader.risk_level)}`}>
                    {trader.risk_level.toUpperCase()} RISK
                  </span>
                  <span className={`text-[10px] sm:text-xs px-1.5 sm:px-2 py-0.5 sm:py-1 rounded font-medium whitespace-nowrap ${getStyleBadgeColor(trader.trading_style)}`}>
                    {trader.trading_style.replace('_', ' ').toUpperCase()}
                  </span>
                </div>
                <div className="flex items-center gap-2 sm:gap-4 text-xs sm:text-sm text-[#848e9c]">
                  <div className="flex items-center gap-1">
                    <Users className="w-3 h-3 sm:w-4 sm:h-4" />
                    <span>{trader.followers_count.toLocaleString()} followers</span>
                  </div>
                  <span className="hidden sm:inline">•</span>
                  <span className="hidden sm:inline">Rank #{trader.rank} / {trader.total_rank}</span>
                </div>
              </div>
            </div>

            <button
              onClick={() => setIsFavorite(!isFavorite)}
              className="text-gray-400 hover:text-[#fcd535] transition-colors flex-shrink-0"
            >
              <Star className={`w-5 h-5 sm:w-6 sm:h-6 ${isFavorite ? 'fill-[#fcd535] text-[#fcd535]' : ''}`} />
            </button>
          </div>

          <div className="flex gap-2 mb-6">
            {(['7d', '30d', '90d', 'all'] as const).map((period) => (
              <button
                key={period}
                onClick={() => setSelectedPeriod(period)}
                className={`px-4 py-2 rounded text-sm font-medium transition-colors ${
                  selectedPeriod === period
                    ? 'bg-[#fcd535] text-[#0b0e11]'
                    : 'bg-[#1e2329] text-[#848e9c] hover:text-white'
                }`}
              >
                {period === 'all' ? 'All Time' : period.toUpperCase()}
              </button>
            ))}
          </div>

          <div className="grid grid-cols-2 gap-3 sm:gap-4">
            <div className="bg-[#1e2329] rounded-lg p-3 sm:p-4">
              <div className="text-[#848e9c] text-xs mb-1">ROI</div>
              <div className={`text-xl sm:text-2xl font-bold ${roi >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                {roi >= 0 ? '+' : ''}{roi.toFixed(2)}%
              </div>
            </div>

            <div className="bg-[#1e2329] rounded-lg p-3 sm:p-4">
              <div className="text-[#848e9c] text-xs mb-1">PNL (USDT)</div>
              <div className={`text-lg sm:text-2xl font-bold truncate ${pnl >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                {pnl >= 0 ? '+' : ''}{pnl >= 1000000 ? `${(pnl / 1000000).toFixed(2)}M` : pnl.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
            </div>

            <div className="bg-[#1e2329] rounded-lg p-3 sm:p-4">
              <div className="text-[#848e9c] text-xs mb-1">Win Rate</div>
              <div className="text-xl sm:text-2xl font-bold text-white">{winRate.toFixed(1)}%</div>
            </div>

            <div className="bg-[#1e2329] rounded-lg p-3 sm:p-4">
              <div className="text-[#848e9c] text-xs mb-1">AUM (USDT)</div>
              <div className="text-lg sm:text-2xl font-bold text-white truncate">
                {trader.aum >= 1000000 ? `${(trader.aum / 1000000).toFixed(2)}M` : trader.aum.toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-[#2b3139] rounded-lg p-6">
            <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Activity className="w-5 h-5 text-[#fcd535]" />
              Trading Statistics
            </h2>

            <div className="space-y-3">
              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Total Trades</span>
                <span className="text-white font-medium">{trader.total_trades.toLocaleString()}</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Current Win Streak</span>
                <span className="text-[#0ecb81] font-medium flex items-center gap-1">
                  <TrendingUp className="w-4 h-4" />
                  {trader.win_streak}
                </span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Max Win Streak</span>
                <span className="text-white font-medium">{trader.max_win_streak}</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Profitable Days</span>
                <span className="text-white font-medium">{trader.profitable_days || 0} / {trader.trading_days || 0}</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Best Trade</span>
                <span className="text-[#0ecb81] font-medium">+{trader.best_trade_pnl?.toFixed(2) || '0.00'} USDT</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Worst Trade</span>
                <span className="text-[#f6465d] font-medium">{trader.worst_trade_pnl?.toFixed(2) || '0.00'} USDT</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Avg Hold Time</span>
                <span className="text-white font-medium">{formatHoldTime(trader.avg_hold_time_hours || 0)}</span>
              </div>

              <div className="flex justify-between items-center py-2">
                <span className="text-[#848e9c] text-sm">Avg Leverage</span>
                <span className="text-white font-medium">{trader.avg_leverage?.toFixed(1) || '0.0'}x</span>
              </div>
            </div>
          </div>

          <div className="bg-[#2b3139] rounded-lg p-6">
            <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Shield className="w-5 h-5 text-[#fcd535]" />
              Risk Metrics
            </h2>

            <div className="space-y-3">
              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Sharpe Ratio</span>
                <span className="text-white font-medium">{trader.sharpe_ratio?.toFixed(2) || '0.00'}</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Max Drawdown (30d)</span>
                <span className="text-[#f6465d] font-medium">{trader.mdd_30d?.toFixed(2) || '0.00'}%</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Volatility Score</span>
                <span className="text-white font-medium">{trader.volatility_score?.toFixed(1) || '0.0'}/100</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Consistency Score</span>
                <span className="text-white font-medium">{trader.consistency_score?.toFixed(1) || '0.0'}/100</span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Monthly Return</span>
                <span className={`font-medium ${(trader.monthly_return || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                  {(trader.monthly_return || 0) >= 0 ? '+' : ''}{trader.monthly_return?.toFixed(2) || '0.00'}%
                </span>
              </div>

              <div className="flex justify-between items-center py-2 border-b border-[#1e2329]">
                <span className="text-[#848e9c] text-sm">Total Volume</span>
                <span className="text-white font-medium">
                  {((trader.total_volume || 0) / 1000000).toFixed(2)}M USDT
                </span>
              </div>

              <div className="py-2">
                <div className="text-[#848e9c] text-sm mb-2">Favorite Pairs</div>
                <div className="flex flex-wrap gap-2">
                  {(trader.favorite_pairs || []).map((pair) => (
                    <span key={pair} className="bg-[#1e2329] px-2 py-1 rounded text-xs text-white">
                      {pair}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-[#2b3139] rounded-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold">Start Copying</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button
              onClick={() => setShowCopyModal(true)}
              className="bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] px-6 py-3 rounded-lg font-medium transition-all"
            >
              Copy Trade
            </button>
            <button
              onClick={() => setShowMockCopyModal(true)}
              className="bg-[#1e2329] hover:bg-[#2b3139] text-white px-6 py-3 rounded-lg font-medium transition-all"
            >
              Mock Copy
            </button>
            <button
              onClick={() => setActiveTab('history')}
              className="bg-[#1e2329] hover:bg-[#2b3139] text-white px-6 py-3 rounded-lg font-medium transition-all"
            >
              View History
            </button>
          </div>
        </div>

        <div className="bg-[#2b3139] rounded-lg p-4 sm:p-6">
          <div className="relative mb-6">
            <div className="flex gap-4 sm:gap-8 border-b border-[#1e2329] overflow-x-auto pb-0" style={{ scrollbarWidth: 'none', msOverflowStyle: 'none', WebkitOverflowScrolling: 'touch' }}>
              <button
                onClick={() => setActiveTab('positions')}
                className={`pb-3 px-1 text-xs sm:text-sm font-medium transition-colors relative whitespace-nowrap ${
                  activeTab === 'positions'
                    ? 'text-white'
                    : 'text-[#848e9c] hover:text-white'
                }`}
              >
                Positions
                {activeTab === 'positions' && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#fcd535]" />
                )}
              </button>
              <button
                onClick={() => setActiveTab('history')}
                className={`pb-3 px-1 text-xs sm:text-sm font-medium transition-colors relative whitespace-nowrap ${
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
                onClick={() => setActiveTab('records')}
                className={`pb-3 px-1 text-xs sm:text-sm font-medium transition-colors relative whitespace-nowrap ${
                  activeTab === 'records'
                    ? 'text-white'
                    : 'text-[#848e9c] hover:text-white'
                }`}
              >
                Latest Records
                {activeTab === 'records' && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#fcd535]" />
                )}
              </button>
              <button
                onClick={() => setActiveTab('transfer')}
                className={`pb-3 px-1 text-xs sm:text-sm font-medium transition-colors relative whitespace-nowrap ${
                  activeTab === 'transfer'
                    ? 'text-white'
                    : 'text-[#848e9c] hover:text-white'
                }`}
              >
                Transfer History
                {activeTab === 'transfer' && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#fcd535]" />
                )}
              </button>
              <button
                onClick={() => setActiveTab('copytraders')}
                className={`pb-3 px-1 text-xs sm:text-sm font-medium transition-colors relative whitespace-nowrap pr-4 ${
                  activeTab === 'copytraders'
                    ? 'text-white'
                    : 'text-[#848e9c] hover:text-white'
                }`}
              >
                Copy Traders
                {activeTab === 'copytraders' && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#fcd535]" />
                )}
              </button>
            </div>
            <div className="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-[#2b3139] to-transparent pointer-events-none sm:hidden" />
          </div>

          {activeTab === 'copytraders' && (
            <>
              <div className="hidden sm:block overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="text-[#848e9c] text-sm">
                      <th className="text-left pb-4 font-medium">User ID</th>
                      <th className="text-right pb-4 font-medium">Copy Margin Balance</th>
                      <th className="text-right pb-4 font-medium">Total PNL</th>
                      <th className="text-right pb-4 font-medium">Total ROI</th>
                      <th className="text-right pb-4 font-medium">Duration</th>
                    </tr>
                  </thead>
                  <tbody>
                    {copyTraders.map((copyTrader, index) => (
                      <tr
                        key={copyTrader.id}
                        className={`border-t border-[#1e2329] ${
                          index % 2 === 0 ? 'bg-[#1e2329]/30' : ''
                        }`}
                      >
                        <td className="py-4 text-white">{copyTrader.userId}</td>
                        <td className="py-4 text-right text-white">
                          {copyTrader.balance.toLocaleString(undefined, {
                            minimumFractionDigits: 2,
                            maximumFractionDigits: 2
                          })}{' '}
                          USDT
                        </td>
                        <td className="py-4 text-right text-[#0ecb81]">
                          +{copyTrader.pnl.toLocaleString(undefined, {
                            minimumFractionDigits: 2,
                            maximumFractionDigits: 2
                          })}{' '}
                          USDT
                        </td>
                        <td className="py-4 text-right text-[#0ecb81]">
                          +{copyTrader.roi.toFixed(2)}%
                        </td>
                        <td className="py-4 text-right text-white">
                          {copyTrader.duration} Days
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="sm:hidden space-y-3">
                {copyTraders.map((copyTrader) => (
                  <div key={copyTrader.id} className="bg-[#1e2329] rounded-lg p-4">
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-white font-medium">{copyTrader.userId}</span>
                      <span className="text-xs text-[#848e9c]">{copyTrader.duration} Days</span>
                    </div>
                    <div className="grid grid-cols-3 gap-2 text-sm">
                      <div>
                        <div className="text-[#848e9c] text-xs mb-1">Balance</div>
                        <div className="text-white font-medium">{copyTrader.balance.toLocaleString(undefined, { maximumFractionDigits: 0 })}</div>
                      </div>
                      <div>
                        <div className="text-[#848e9c] text-xs mb-1">PNL</div>
                        <div className="text-[#0ecb81] font-medium">+{copyTrader.pnl.toFixed(0)}</div>
                      </div>
                      <div>
                        <div className="text-[#848e9c] text-xs mb-1">ROI</div>
                        <div className="text-[#0ecb81] font-medium">+{copyTrader.roi.toFixed(1)}%</div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}

          {activeTab === 'positions' && (
            <div className="space-y-4">
              {openPositions.length === 0 ? (
                <div className="bg-[#1e2329] rounded-lg p-6 text-center">
                  <div className="text-[#848e9c] mb-2">
                    No open positions
                  </div>
                  <div className="text-sm text-[#848e9c]/70">
                    This trader currently has no open positions
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  {openPositions.map((position) => (
                    <div key={position.id} className="bg-[#1e2329] rounded-lg p-4">
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-2">
                          <span className="text-white font-medium">{position.symbol}</span>
                          <span className={`px-2 py-0.5 rounded text-xs ${
                            position.side === 'long'
                              ? 'bg-[#0ecb81]/20 text-[#0ecb81]'
                              : 'bg-[#f6465d]/20 text-[#f6465d]'
                          }`}>
                            {position.side.toUpperCase()}
                          </span>
                          <span className="text-[#848e9c] text-xs">{position.leverage}x</span>
                        </div>
                        <span className="text-xs text-[#848e9c]">
                          {new Date(position.opened_at).toLocaleDateString()}
                        </span>
                      </div>
                      <div className="grid grid-cols-2 gap-3 text-sm">
                        <div>
                          <div className="text-[#848e9c] text-xs mb-1">Entry</div>
                          <div className="text-white font-medium">${parseFloat(position.entry_price.toString()).toFixed(2)}</div>
                        </div>
                        <div>
                          <div className="text-[#848e9c] text-xs mb-1">Size</div>
                          <div className="text-white font-medium truncate">{parseFloat(position.quantity.toString()).toLocaleString(undefined, { maximumFractionDigits: 4 })}</div>
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
              {closedPositions.length === 0 ? (
                <div className="bg-[#1e2329] rounded-lg p-6 text-center">
                  <div className="text-[#848e9c] mb-2">
                    No trading history
                  </div>
                  <div className="text-sm text-[#848e9c]/70">
                    This trader has no closed positions yet
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  {closedPositions.map((position) => {
                    const pnl = position.pnl ? parseFloat(position.pnl.toString()) : 0;
                    const pnlPercent = position.pnl_percent ? parseFloat(position.pnl_percent.toString()) : 0;
                    const isProfit = pnl >= 0;

                    return (
                      <div key={position.id} className="bg-[#1e2329] rounded-lg p-4">
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-2">
                            <span className="text-white font-medium">{position.symbol}</span>
                            <span className={`px-2 py-0.5 rounded text-xs ${
                              position.side === 'long'
                                ? 'bg-[#0ecb81]/20 text-[#0ecb81]'
                                : 'bg-[#f6465d]/20 text-[#f6465d]'
                            }`}>
                              {position.side.toUpperCase()}
                            </span>
                            <span className="text-[#848e9c] text-xs">{position.leverage}x</span>
                          </div>
                          <span className={`text-sm font-medium ${isProfit ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                            {isProfit ? '+' : ''}{pnlPercent.toFixed(2)}%
                          </span>
                        </div>
                        <div className="grid grid-cols-2 gap-3 text-sm">
                          <div>
                            <div className="text-[#848e9c] text-xs mb-1">Entry</div>
                            <div className="text-white font-medium">${parseFloat(position.entry_price.toString()).toFixed(2)}</div>
                          </div>
                          <div>
                            <div className="text-[#848e9c] text-xs mb-1">Exit</div>
                            <div className="text-white font-medium">${position.exit_price ? parseFloat(position.exit_price.toString()).toFixed(2) : 'N/A'}</div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {activeTab === 'records' && (
            <div className="text-center text-[#848e9c] py-8">
              No records available
            </div>
          )}

          {activeTab === 'transfer' && (
            <div className="text-center text-[#848e9c] py-8">
              No transfer history
            </div>
          )}
        </div>
      </div>
      </div>

      {trader && (
        <>
          <CopyTradingModal
            isOpen={showCopyModal}
            onClose={() => setShowCopyModal(false)}
            traderId={trader.id}
            traderName={trader.name}
            isMock={false}
          />
          <CopyTradingModal
            isOpen={showMockCopyModal}
            onClose={() => setShowMockCopyModal(false)}
            traderId={trader.id}
            traderName={trader.name}
            isMock={true}
          />
        </>
      )}
    </div>
  );
}
