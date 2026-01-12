import { useState, useEffect } from 'react';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';
import { ArrowLeft, Plus, X, TrendingUp, TrendingDown, Edit2, Trash2, Users, Zap, MessageCircle, Send, Search, RefreshCw } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../hooks/useToast';
import { ToastContainer } from '../components/Toast';
import { usePrices } from '../hooks/usePrices';
import TelegramNotificationStatus from '../components/admin/TelegramNotificationStatus';
import { ALL_CRYPTO_PAIRS } from '../constants/tradingPairs';

interface ManagedTrader {
  id: string;
  name: string;
  avatar: string;
  rank: number;
  total_rank: number;
  api_verified: boolean;
  pnl_30d: number;
  roi_30d: number;
  aum: number;
  mdd_30d: number;
  sharpe_ratio: number | null;
  is_featured: boolean;
  followers_count: number;
  real_followers_count?: number;
  mock_followers_count?: number;
}

interface Follower {
  user_id: string;
  email: string;
  username: string;
  allocated_balance: number;
  is_active: boolean;
  is_mock: boolean;
  created_at: string;
}

interface Position {
  id: string;
  pair: string;
  side: 'long' | 'short';
  entry_price: number;
  exit_price: number | null;
  quantity: number;
  leverage: number;
  margin_used: number;
  realized_pnl: number;
  pnl_percentage: number;
  status: 'open' | 'closed';
  opened_at: string;
  closed_at: string | null;
  notes: string | null;
}

export default function AdminManagedTrader() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const { toasts, removeToast, showSuccess, showError } = useToast();
  const prices = usePrices();

  const [allTraders, setAllTraders] = useState<ManagedTrader[]>([]);
  const [selectedTrader, setSelectedTrader] = useState<ManagedTrader | null>(null);
  const [followers, setFollowers] = useState<Follower[]>([]);
  const [positions, setPositions] = useState<Position[]>([]);
  const [loading, setLoading] = useState(true);

  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showBulkCreateModal, setShowBulkCreateModal] = useState(false);
  const [showTradeModal, setShowTradeModal] = useState(false);
  const [showCloseModal, setShowCloseModal] = useState(false);
  const [showPercentageModal, setShowPercentageModal] = useState(false);
  const [showFollowersModal, setShowFollowersModal] = useState(false);
  const [showNotificationModal, setShowNotificationModal] = useState(false);
  const [notificationPendingTradeId, setNotificationPendingTradeId] = useState<string | null>(null);
  const [sendingNotifications, setSendingNotifications] = useState(false);
  const [flippingPosition, setFlippingPosition] = useState<string | null>(null);
  const [selectedPosition, setSelectedPosition] = useState<Position | null>(null);
  const [bulkTraderCount, setBulkTraderCount] = useState('5');

  const [percentageForm, setPercentageForm] = useState({
    percentage: '1.2'
  });

  const [tradeForm, setTradeForm] = useState({
    pair: 'BTC/USDT',
    side: 'long',
    entry_price: '',
    quantity: '',
    leverage: '10',
    margin_used: '',
    notes: '',
    use_percentage: false,
    percentage: '20',
    auto_notify: true
  });

  const [traderBalance, setTraderBalance] = useState(0);

  const [closeForm, setCloseForm] = useState({
    exit_price: '',
    pnl_percentage: '',
    auto_notify: true
  });

  useEffect(() => {
    if (selectedTrader) {
      setTraderBalance(100000);
    }
  }, [selectedTrader]);

  useEffect(() => {
    if (tradeForm.use_percentage && tradeForm.percentage && tradeForm.entry_price && tradeForm.leverage) {
      const entryPrice = parseFloat(tradeForm.entry_price);
      const percentage = parseFloat(tradeForm.percentage);
      const leverage = parseFloat(tradeForm.leverage);

      if (!isNaN(entryPrice) && !isNaN(percentage) && !isNaN(leverage) && entryPrice > 0 && percentage > 0 && leverage > 0) {
        const marginFromPercentage = (traderBalance * percentage) / 100;
        const positionValue = marginFromPercentage * leverage;
        const quantity = positionValue / entryPrice;

        setTradeForm(prev => ({
          ...prev,
          quantity: quantity.toFixed(4),
          margin_used: marginFromPercentage.toFixed(2)
        }));
      }
    } else if (!tradeForm.use_percentage && tradeForm.entry_price && tradeForm.quantity && tradeForm.leverage) {
      const entryPrice = parseFloat(tradeForm.entry_price);
      const quantity = parseFloat(tradeForm.quantity);
      const leverage = parseFloat(tradeForm.leverage);

      if (!isNaN(entryPrice) && !isNaN(quantity) && !isNaN(leverage) && entryPrice > 0 && quantity > 0 && leverage > 0) {
        const positionValue = entryPrice * quantity;
        const marginRequired = positionValue / leverage;

        setTradeForm(prev => ({
          ...prev,
          margin_used: marginRequired.toFixed(2)
        }));
      }
    }
  }, [tradeForm.entry_price, tradeForm.quantity, tradeForm.leverage, tradeForm.use_percentage, tradeForm.percentage, traderBalance]);

  useEffect(() => {
    if (showCloseModal && selectedPosition) {
      const symbol = selectedPosition.pair.replace('/', '');
      const priceData = prices.get(symbol);

      if (priceData && !closeForm.exit_price) {
        setCloseForm(prev => ({
          ...prev,
          exit_price: priceData.price.toString()
        }));
      }
    }
  }, [showCloseModal, selectedPosition, prices]);

  useEffect(() => {
    if (selectedPosition && closeForm.exit_price) {
      const exitPrice = parseFloat(closeForm.exit_price);
      const entryPrice = selectedPosition.entry_price;
      const leverage = selectedPosition.leverage;

      if (!isNaN(exitPrice) && exitPrice > 0) {
        let pnlPercentage = 0;

        if (selectedPosition.side === 'long') {
          pnlPercentage = ((exitPrice - entryPrice) / entryPrice) * 100 * leverage;
        } else {
          pnlPercentage = ((entryPrice - exitPrice) / entryPrice) * 100 * leverage;
        }

        setCloseForm(prev => ({
          ...prev,
          pnl_percentage: pnlPercentage.toFixed(2)
        }));
      }
    }
  }, [closeForm.exit_price, selectedPosition]);

  const [traderForm, setTraderForm] = useState({
    name: '',
    avatar: '🤖',
    rank: 1,
    total_rank: 1000,
    api_verified: false
  });

  useEffect(() => {
    loadTraders();
  }, []);

  useEffect(() => {
    if (selectedTrader) {
      loadPositions();
      loadFollowers();
      const interval = setInterval(() => {
        loadPositions();
        loadFollowers();
      }, 5000);
      return () => clearInterval(interval);
    }
  }, [selectedTrader]);

  useEffect(() => {
    if (showTradeModal && tradeForm.pair) {
      const symbol = tradeForm.pair.replace('/', '');
      const priceData = prices.get(symbol);
      if (priceData) {
        setTradeForm(prev => ({
          ...prev,
          entry_price: priceData.price.toString()
        }));
      }
    }
  }, [showTradeModal, tradeForm.pair, prices]);

  const loadTraders = async () => {
    try {
      const { data, error } = await supabase
        .from('traders')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;

      const { data: followerCounts, error: countError } = await supabase
        .from('copy_relationships')
        .select('trader_id, is_mock');

      if (countError) {
        console.error('Error loading follower counts:', countError);
      }

      const tradersWithCounts = (data || []).map(trader => {
        const traderFollowers = (followerCounts || []).filter(f => f.trader_id === trader.id);
        const realCount = traderFollowers.filter(f => !f.is_mock).length;
        const mockCount = traderFollowers.filter(f => f.is_mock).length;

        return {
          ...trader,
          real_followers_count: realCount,
          mock_followers_count: mockCount
        };
      });

      setAllTraders(tradersWithCounts);

      if (tradersWithCounts && tradersWithCounts.length > 0 && !selectedTrader) {
        setSelectedTrader(tradersWithCounts[0]);
      }
    } catch (error: any) {
      console.error('Error loading traders:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadFollowers = async () => {
    if (!selectedTrader) return;

    try {
      const { data, error } = await supabase
        .from('copy_relationships')
        .select(`
          follower_id,
          current_balance,
          is_active,
          is_mock,
          created_at,
          user_profiles!follower_id(email, username)
        `)
        .eq('trader_id', selectedTrader.id);

      if (error) throw error;

      const formattedFollowers = (data || []).map((rel: any) => ({
        user_id: rel.follower_id,
        email: rel.user_profiles?.email || 'Unknown',
        username: rel.user_profiles?.username || 'Unknown',
        allocated_balance: parseFloat(rel.current_balance || '0'),
        is_active: rel.is_active,
        is_mock: rel.is_mock || false,
        created_at: rel.created_at
      }));

      setFollowers(formattedFollowers);
    } catch (error) {
      console.error('Error loading followers:', error);
    }
  };

  const loadPositions = async () => {
    if (!selectedTrader) return;

    try {
      const { data: traderTradesData, error: traderTradesError } = await supabase
        .from('trader_trades')
        .select('*')
        .eq('trader_id', selectedTrader.id)
        .order('opened_at', { ascending: false });

      if (traderTradesError) throw traderTradesError;

      const convertedPositions = (traderTradesData || []).map(trade => ({
        id: trade.id,
        trader_id: trade.trader_id,
        pair: trade.symbol,
        side: trade.side,
        entry_price: trade.entry_price,
        exit_price: trade.exit_price,
        quantity: trade.quantity,
        leverage: trade.leverage,
        margin_used: trade.margin_used,
        status: trade.status,
        realized_pnl: trade.pnl,
        pnl_percentage: trade.pnl_percent,
        notes: null,
        opened_at: trade.opened_at,
        closed_at: trade.closed_at,
        created_at: trade.created_at,
        updated_at: trade.updated_at
      }));

      setPositions(convertedPositions);
    } catch (error) {
      console.error('Error loading positions:', error);
    }
  };

  const handleCreateTrader = async () => {
    if (!user) return;

    try {
      const { data, error} = await supabase
        .from('traders')
        .insert({
          name: traderForm.name,
          avatar: traderForm.avatar,
          rank: traderForm.rank,
          total_rank: traderForm.total_rank,
          api_verified: traderForm.api_verified,
          pnl_30d: 0,
          roi_30d: 0,
          aum: 0,
          mdd_30d: 0,
          sharpe_ratio: null,
          is_featured: true,
          followers_count: 0
        })
        .select()
        .single();

      if (error) throw error;

      showSuccess('Trader created successfully');
      setShowCreateModal(false);
      loadTraders();
      setTraderForm({ name: '', avatar: '🤖', rank: 1, total_rank: 1000, api_verified: false });
    } catch (error: any) {
      showError(error.message || 'Failed to create trader');
    }
  };

  const handleBulkCreateTraders = async () => {
    if (!user) return;

    const count = parseInt(bulkTraderCount);
    if (isNaN(count) || count < 1 || count > 50) {
      showError('Please enter a number between 1 and 50');
      return;
    }

    const traderNames = [
      'CryptoMaster88', 'MoonWhale', 'SatoshiFan', 'DiamondHands', 'BullRunner',
      'CryptoKing', 'TogetherWin', 'ProTrader', 'WhaleWatcher', 'RocketMoon',
      'SmartInvestor', 'TradingPro', 'BlockchainBoss', 'CryptoGuru', 'MarketMaker',
      'ProfitSeeker', 'TrendFollower', 'SwingMaster', 'DayTrader', 'HodlKing',
      'TokenHunter', 'ChartWizard', 'TechAnalyst', 'FuturesMaster', 'VolatilityKing',
      'LeverageLord', 'CryptoNinja', 'MarketShark', 'BullBear', 'TradeSmart',
      'WealthBuilder', 'PortfolioKing', 'RiskManager', 'GainSeeker', 'AlgoTrader',
      'PatternReader', 'PriceAction', 'BreakoutPro', 'TrendRider', 'SwingKing',
      'ScalpMaster', 'PositionTrader', 'MomentumKing', 'VolumeTrader', 'OptionsKing',
      'DerivativesPro', 'HedgeFund', 'InstitutionalPro', 'RetailKing', 'WhaleAlert'
    ];

    const avatars = [
      '🚀', '💎', '👑', '🌟', '⚡', '🔥', '💰', '🎯', '🏆', '🤖',
      '🐋', '🦈', '🐂', '🐻', '🎲', '🎰', '🎪', '🎭', '🎨', '🎬',
      '🌈', '⭐', '✨', '💫', '🌙', '☀️', '🌍', '🌊', '🔮', '💡'
    ];

    const descriptions = [
      'Professional crypto trader specializing in technical analysis',
      'Expert in risk management and portfolio optimization',
      'Algorithmic trading specialist with proven track record',
      'Derivatives and futures trading expert',
      'Experienced in market-making and liquidity provision',
      'Multi-asset portfolio manager with global expertise',
      'Quantitative analyst using advanced statistical models',
      'Institutional-grade trading strategies',
      'Swing trading specialist focusing on major pairs',
      'Day trader with high-frequency execution capabilities',
      'Options and volatility trading expert',
      'Technical analysis guru with 10+ years experience',
      'Fundamental analyst combining on-chain metrics',
      'Pattern recognition specialist',
      'Momentum-based trading strategies',
      'Scalping expert with precision execution',
      'Position trader for long-term gains',
      'Breakout trader capturing major moves',
      'Range-bound market specialist',
      'Trend-following systematic approach'
    ];

    try {
      const tradersToCreate = [];
      for (let i = 0; i < count; i++) {
        const randomName = traderNames[Math.floor(Math.random() * traderNames.length)] + Math.floor(Math.random() * 1000);
        const randomAvatar = avatars[Math.floor(Math.random() * avatars.length)];

        const roi = (Math.random() * 40) + 2;
        const aum = (Math.random() * 200000000) + 5000000;
        const pnl = (aum * roi) / 100;
        const mdd = Math.random() * 30;
        const sharpe = Math.random() * 5;
        const followers = Math.floor(Math.random() * 2000);
        const rank = Math.floor(Math.random() * 900) + 1;
        const totalRank = [300, 400, 500, 600, 800, 1000][Math.floor(Math.random() * 6)];

        tradersToCreate.push({
          name: randomName,
          avatar: randomAvatar,
          rank: rank,
          total_rank: totalRank,
          api_verified: Math.random() > 0.5,
          pnl_30d: parseFloat(pnl.toFixed(2)),
          roi_30d: parseFloat(roi.toFixed(2)),
          aum: parseFloat(aum.toFixed(2)),
          mdd_30d: parseFloat(mdd.toFixed(2)),
          sharpe_ratio: sharpe > 4.5 ? null : parseFloat(sharpe.toFixed(2)),
          is_featured: true,
          followers_count: followers
        });
      }

      const { error } = await supabase
        .from('traders')
        .insert(tradersToCreate);

      if (error) throw error;

      showSuccess(`Successfully created ${count} traders`);
      setShowBulkCreateModal(false);
      loadTraders();
      setBulkTraderCount('5');
    } catch (error: any) {
      showError(error.message);
    }
  };

  const handleExecutePercentageTrade = async () => {
    if (!selectedTrader || !user) return;

    try {
      const targetPercentage = parseFloat(percentageForm.percentage);

      if (isNaN(targetPercentage) || targetPercentage === 0) {
        showError('Please enter a valid percentage');
        return;
      }

      const { data, error } = await supabase.functions.invoke('execute-percentage-trade', {
        body: {
          trader_id: selectedTrader.id,
          target_percentage: targetPercentage,
          trader_balance: traderBalance
        }
      });

      if (error) throw error;

      if (data.success) {
        showSuccess(`Trade executed! ${data.side.toUpperCase()} ${data.pair} - ${targetPercentage >= 0 ? '+' : ''}${targetPercentage}%`);
        setShowPercentageModal(false);
        setPercentageForm({ percentage: '1.2' });
        loadPositions();
      } else {
        showError(data.error || 'Failed to execute trade');
      }
    } catch (error: any) {
      showError(error.message || 'Failed to execute percentage trade');
    }
  };

  const handleOpenTrade = async () => {
    if (!selectedTrader || !user) return;

    try {
      const { data, error } = await supabase.rpc('create_pending_trade_only', {
        p_trader_id: selectedTrader.id,
        p_pair: tradeForm.pair,
        p_side: tradeForm.side,
        p_entry_price: parseFloat(tradeForm.entry_price),
        p_quantity: parseFloat(tradeForm.quantity),
        p_leverage: parseInt(tradeForm.leverage),
        p_margin_used: parseFloat(tradeForm.margin_used),
        p_notes: tradeForm.notes || null,
        p_admin_id: user.id
      });

      if (error) throw error;

      const shouldNotify = tradeForm.auto_notify;

      showSuccess('Trade signal created! Sending notifications to followers...');
      setShowTradeModal(false);
      setTradeForm({
        pair: 'BTC/USDT',
        side: 'long',
        entry_price: '',
        quantity: '',
        leverage: '10',
        margin_used: '',
        notes: '',
        use_percentage: false,
        percentage: '20',
        auto_notify: true
      });
      loadPositions();

      if (shouldNotify && data && data.length > 0) {
        try {
          const result = data[0];
          setNotificationPendingTradeId(result.pending_trade_id);

          const response = await fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/telegram-notify-trade`,
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                pending_trade_id: result.pending_trade_id,
              }),
            }
          );

          const notifyResult = await response.json();

          if (notifyResult.success && notifyResult.notifications?.sent > 0) {
            showSuccess(`Telegram notifications sent to ${notifyResult.notifications.sent} followers! They have 5 minutes to respond.`);
            setShowNotificationModal(true);
          } else if (notifyResult.error) {
            showError(`Failed to send notifications: ${notifyResult.error}`);
          }
        } catch (telegramError: any) {
          console.error('Telegram notification error:', telegramError);
          showError(`Failed to send Telegram notifications: ${telegramError.message}`);
        }
      }
    } catch (error: any) {
      showError(error.message || 'Failed to open trade');
    }
  };

  const handleCloseTrade = async () => {
    if (!selectedPosition || !user || !selectedTrader) return;

    const exitPrice = parseFloat(closeForm.exit_price);
    const pnlPercentage = parseFloat(closeForm.pnl_percentage);

    if (isNaN(exitPrice) || exitPrice <= 0) {
      showError('Please enter a valid exit price');
      return;
    }

    if (isNaN(pnlPercentage)) {
      showError('PNL percentage is required');
      return;
    }

    try {
      const { error } = await supabase.rpc('close_trader_trade', {
        p_trade_id: selectedPosition.id,
        p_exit_price: exitPrice,
        p_pnl_percentage: pnlPercentage,
        p_admin_id: user.id
      });

      if (error) throw error;

      const shouldNotify = closeForm.auto_notify;
      const tradeDetails = {
        trader_id: selectedTrader.id,
        trader_trade_id: selectedPosition.id,
        pair: selectedPosition.pair,
        side: selectedPosition.side,
        entry_price: selectedPosition.entry_price,
        exit_price: exitPrice,
        pnl_percentage: pnlPercentage,
        leverage: selectedPosition.leverage
      };

      showSuccess('Trade closed successfully!');
      setShowCloseModal(false);
      setSelectedPosition(null);
      setCloseForm({ exit_price: '', pnl_percentage: '', auto_notify: true });
      loadPositions();

      if (shouldNotify) {
        try {
          const response = await fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/telegram-notify-trade-close`,
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
              },
              body: JSON.stringify(tradeDetails),
            }
          );

          const notifyResult = await response.json();

          if (notifyResult.success && notifyResult.notifications?.sent > 0) {
            showSuccess(`Trade closure notifications sent to ${notifyResult.notifications.sent} followers`);
          }
        } catch (telegramError) {
          console.error('Telegram close notification error:', telegramError);
        }
      }
    } catch (error: any) {
      showError(error.message || 'Failed to close trade');
    }
  };

  const handleSendTelegramNotifications = async (position: Position) => {
    if (!selectedTrader || !user) return;

    setSendingNotifications(true);
    try {
      const { data, error } = await supabase.rpc('notify_followers_for_trade', {
        p_trader_id: selectedTrader.id,
        p_pair: position.pair,
        p_side: position.side,
        p_entry_price: position.entry_price,
        p_leverage: position.leverage,
        p_admin_id: user.id
      });

      if (error) throw error;

      if (data && data.length > 0) {
        const result = data[0];
        setNotificationPendingTradeId(result.pending_trade_id);

        const response = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/telegram-notify-trade`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              pending_trade_id: result.pending_trade_id,
            }),
          }
        );

        const notifyResult = await response.json();

        if (notifyResult.success) {
          showSuccess(`Notifications sent! ${notifyResult.notifications?.sent || 0} delivered`);
          setShowNotificationModal(true);
        } else {
          showError(notifyResult.error || 'Failed to send notifications');
        }
      }
    } catch (error: any) {
      showError(error.message || 'Failed to send notifications');
    } finally {
      setSendingNotifications(false);
    }
  };

  const handleFlipPosition = async (position: Position) => {
    if (!user || flippingPosition) return;

    setFlippingPosition(position.id);
    try {
      const { data, error } = await supabase.rpc('flip_trader_trade_side', {
        p_trade_id: position.id,
        p_admin_id: user.id
      });

      if (error) throw error;

      if (data?.success) {
        showSuccess(data.message || `Position flipped to ${data.new_side}`);
        loadPositions();
      } else {
        showError(data?.error || 'Failed to flip position');
      }
    } catch (error: any) {
      showError(error.message || 'Failed to flip position');
    } finally {
      setFlippingPosition(null);
    }
  };

  const calculateLivePnL = (position: Position) => {
    const symbol = position.pair.replace('/', '');
    const priceData = prices.get(symbol);

    if (!priceData) return null;

    const currentPrice = priceData.price;
    const entryPrice = position.entry_price;
    const quantity = position.quantity;
    const leverage = position.leverage;

    let pnl = 0;
    let pnlPercentage = 0;

    if (position.side === 'long') {
      pnl = (currentPrice - entryPrice) * quantity;
      pnlPercentage = ((currentPrice - entryPrice) / entryPrice) * 100 * leverage;
    } else {
      pnl = (entryPrice - currentPrice) * quantity;
      pnlPercentage = ((entryPrice - currentPrice) / entryPrice) * 100 * leverage;
    }

    return {
      pnl,
      pnlPercentage,
      currentPrice
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

  if (allTraders.length === 0) {
    return (
      <div className="min-h-screen bg-[#181a20] text-white">
        <Navbar />
        <ToastContainer toasts={toasts} removeToast={removeToast} />

        <div className="max-w-4xl mx-auto px-6 py-12">
          <button
            onClick={() => navigateTo('admin')}
            className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm mb-6"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Admin Dashboard
          </button>

          <div className="bg-[#2b3139] rounded-xl p-12 text-center">
            <div className="text-6xl mb-4">🤖</div>
            <h2 className="text-2xl font-bold mb-4">No Managed Traders Yet</h2>
            <p className="text-gray-400 mb-8">
              Create your first managed trader to start accepting followers and managing trades
            </p>
            <div className="flex gap-4 justify-center">
              <button
                onClick={() => setShowCreateModal(true)}
                className="bg-[#fcd535] hover:bg-[#fcd535]/90 text-black px-6 py-3 rounded-lg font-bold transition-all"
              >
                Create Trader
              </button>
              <button
                onClick={() => setShowBulkCreateModal(true)}
                className="bg-[#0ecb81] hover:bg-[#0ecb81]/90 text-black px-6 py-3 rounded-lg font-bold transition-all"
              >
                Bulk Create
              </button>
            </div>
          </div>
        </div>

        {showCreateModal && (
          <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
            <div className="bg-[#2b3139] rounded-xl p-6 max-w-md w-full">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold">Create Managed Trader</h3>
                <button onClick={() => setShowCreateModal(false)} className="text-gray-400 hover:text-white">
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Name</label>
                  <input
                    type="text"
                    value={traderForm.name}
                    onChange={(e) => setTraderForm({ ...traderForm, name: e.target.value })}
                    className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                    placeholder="Pro Trader"
                  />
                </div>

                <div>
                  <label className="block text-sm text-gray-400 mb-2">Avatar Emoji</label>
                  <input
                    type="text"
                    value={traderForm.avatar}
                    onChange={(e) => setTraderForm({ ...traderForm, avatar: e.target.value })}
                    className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                    placeholder="🤖"
                  />
                </div>

                <div>
                  <label className="block text-sm text-gray-400 mb-2">Description</label>
                  <textarea
                    value={traderForm.description}
                    onChange={(e) => setTraderForm({ ...traderForm, description: e.target.value })}
                    className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                    rows={3}
                    placeholder="Professional crypto trader with 5+ years experience..."
                  />
                </div>
              </div>

              <button
                onClick={handleCreateTrader}
                className="w-full bg-[#fcd535] hover:bg-[#fcd535]/90 text-black font-bold py-3 rounded-lg mt-6"
              >
                Create Trader
              </button>
            </div>
          </div>
        )}
      </div>
    );
  }

  const openPositions = positions.filter(p => p.status === 'open');
  const closedPositions = positions.filter(p => p.status === 'closed');

  return (
    <div className="min-h-screen bg-[#181a20] text-white">
      <Navbar />
      <ToastContainer toasts={toasts} removeToast={removeToast} />

      <div className="max-w-7xl mx-auto px-6 py-6">
        <button
          onClick={() => navigateTo('admin')}
          className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Admin Dashboard
        </button>

        <div className="flex items-center justify-between mb-6">
          <h1 className="text-3xl font-bold">Manage Traders</h1>
          <div className="flex gap-3">
            <button
              onClick={() => setShowCreateModal(true)}
              className="flex items-center gap-2 bg-[#fcd535] hover:bg-[#fcd535]/90 text-black px-4 py-2 rounded-lg font-bold transition-all"
            >
              <Plus className="w-4 h-4" />
              New Trader
            </button>
            <button
              onClick={() => setShowBulkCreateModal(true)}
              className="flex items-center gap-2 bg-[#0ecb81] hover:bg-[#0ecb81]/90 text-black px-4 py-2 rounded-lg font-bold transition-all"
            >
              <Plus className="w-4 h-4" />
              Bulk Create
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-4 gap-4 mb-6">
          {allTraders.map((trader) => (
            <button
              key={trader.id}
              onClick={() => setSelectedTrader(trader)}
              className={`bg-[#2b3139] rounded-xl p-4 text-left transition-all border-2 ${
                selectedTrader?.id === trader.id
                  ? 'border-[#fcd535] shadow-lg shadow-[#fcd535]/20'
                  : 'border-transparent hover:border-gray-700'
              }`}
            >
              <div className="text-3xl mb-2">{trader.avatar}</div>
              <div className="font-bold text-lg mb-1">{trader.name}</div>
              <div className="text-sm text-gray-400 flex items-center gap-2 mb-1">
                <Users className="w-4 h-4" />
                <span className="text-[#0ecb81] font-semibold">{trader.real_followers_count || 0}</span> real
                <span className="text-gray-500 mx-1">|</span>
                <span className="text-gray-500">{trader.mock_followers_count || 0}</span> mock
              </div>
              <div className="text-xs text-gray-500">
                Displayed: {trader.followers_count} (fake)
              </div>
            </button>
          ))}
        </div>

        {selectedTrader && (
          <>
            <div className="bg-[#2b3139] rounded-xl p-6 mb-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-4">
                  <div className="text-5xl">{selectedTrader.avatar}</div>
                  <div>
                    <h2 className="text-3xl font-bold mb-1">{selectedTrader.name}</h2>
                    <p className="text-gray-400">{selectedTrader.description}</p>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={() => setShowFollowersModal(true)}
                    className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-bold transition-all"
                  >
                    <Users className="w-4 h-4" />
                    View Followers ({followers.filter(f => !f.is_mock).length} real, {followers.filter(f => f.is_mock).length} mock)
                  </button>
                  <button
                    onClick={() => setShowPercentageModal(true)}
                    className="flex items-center gap-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black px-4 py-2 rounded-lg font-bold transition-all"
                  >
                    <Zap className="w-4 h-4" />
                    Quick % Trade
                  </button>
                  <button
                    onClick={() => setShowTradeModal(true)}
                    className="flex items-center gap-2 bg-[#0ecb81] hover:bg-[#0ecb81]/90 text-white px-4 py-2 rounded-lg font-bold transition-all"
                  >
                    <Plus className="w-4 h-4" />
                    Manual Trade
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-6 pt-6 border-t border-gray-700">
                <div>
                  <div className="text-gray-400 text-sm mb-1">Real Followers</div>
                  <div className="text-[#0ecb81] text-xl font-bold">{selectedTrader.real_followers_count || 0}</div>
                </div>
                <div>
                  <div className="text-gray-400 text-sm mb-1">Mock Followers</div>
                  <div className="text-gray-500 text-xl font-bold">{selectedTrader.mock_followers_count || 0}</div>
                </div>
                <div>
                  <div className="text-gray-400 text-sm mb-1">Total AUM</div>
                  <div className="text-white text-xl font-bold">${selectedTrader.aum.toLocaleString()}</div>
                </div>
                <div>
                  <div className="text-gray-400 text-sm mb-1">Rank</div>
                  <div className="text-white text-xl font-bold">{selectedTrader.rank} / {selectedTrader.total_rank}</div>
                </div>
                <div>
                  <div className="text-gray-400 text-sm mb-1">30D P&L</div>
                  <div className={`text-xl font-bold ${selectedTrader.pnl_30d >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                    {selectedTrader.pnl_30d >= 0 ? '+' : ''}${selectedTrader.pnl_30d.toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })}
                  </div>
                </div>
                <div>
                  <div className="text-gray-400 text-sm mb-1">30D ROI</div>
                  <div className={`text-xl font-bold ${selectedTrader.roi_30d >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                    {selectedTrader.roi_30d >= 0 ? '+' : ''}{selectedTrader.roi_30d.toFixed(2)}%
                  </div>
                </div>
                <div>
                  <div className="text-gray-400 text-sm mb-1">MDD 30D</div>
                  <div className="text-white text-xl font-bold">{selectedTrader.mdd_30d.toFixed(2)}%</div>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="bg-[#2b3139] rounded-xl p-6">
                <h2 className="text-xl font-bold mb-4 flex items-center gap-2">
                  <TrendingUp className="w-5 h-5 text-[#0ecb81]" />
                  Open Positions ({openPositions.length})
                </h2>

                {openPositions.length === 0 ? (
                  <div className="text-center py-12 text-gray-400">
                    <div className="mb-2">No open positions</div>
                    <div className="text-xs text-gray-500">Open a trade to see it appear here</div>
                  </div>
                ) : (
                  <div className="space-y-3 max-h-[600px] overflow-y-auto">
                    {openPositions.map((position) => {
                      const livePnL = calculateLivePnL(position);

                      return (
                        <div key={position.id} className="bg-[#0b0e11] rounded-lg p-4 border border-gray-800">
                          <div className="flex items-center justify-between mb-3">
                            <div className="flex items-center gap-2">
                              <span className="font-bold">{position.pair}</span>
                              <span className={`text-xs px-2 py-0.5 rounded font-bold ${
                                position.side === 'long'
                                  ? 'bg-[#0ecb81]/20 text-[#0ecb81]'
                                  : 'bg-[#f6465d]/20 text-[#f6465d]'
                              }`}>
                                {position.side.toUpperCase()}
                              </span>
                            </div>
                            <div className="flex gap-2">
                              <button
                                onClick={() => handleSendTelegramNotifications(position)}
                                disabled={sendingNotifications}
                                className="flex items-center gap-1 bg-[#0088cc] hover:bg-[#0077b5] text-white px-2 py-1 rounded text-sm font-bold disabled:opacity-50"
                                title="Send Telegram notifications to followers"
                              >
                                <MessageCircle className="w-3 h-3" />
                                Notify
                              </button>
                              <button
                                onClick={() => handleFlipPosition(position)}
                                disabled={flippingPosition === position.id}
                                className="flex items-center gap-1 bg-[#f0b90b] hover:bg-[#f8d12f] text-black px-2 py-1 rounded text-sm font-bold disabled:opacity-50"
                                title={`Flip to ${position.side === 'long' ? 'SHORT' : 'LONG'}`}
                              >
                                <RefreshCw className={`w-3 h-3 ${flippingPosition === position.id ? 'animate-spin' : ''}`} />
                                Flip
                              </button>
                              <button
                                onClick={() => {
                                  setSelectedPosition(position);
                                  setCloseForm({ exit_price: '', pnl_percentage: '', auto_notify: true });
                                  setShowCloseModal(true);
                                }}
                                className="bg-[#f6465d] hover:bg-[#f6465d]/90 text-white px-3 py-1 rounded text-sm font-bold"
                              >
                                Close
                              </button>
                            </div>
                          </div>

                          {livePnL && (
                            <div className="bg-[#1e2329] rounded-lg p-2 mb-2 grid grid-cols-3 gap-2 text-sm">
                              <div>
                                <div className="text-gray-400 text-xs">Price</div>
                                <div className="text-white font-bold">${livePnL.currentPrice.toLocaleString()}</div>
                              </div>
                              <div>
                                <div className="text-gray-400 text-xs">PNL</div>
                                <div className={`font-bold ${livePnL.pnl >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                                  ${livePnL.pnl.toFixed(2)}
                                </div>
                              </div>
                              <div>
                                <div className="text-gray-400 text-xs">ROI</div>
                                <div className={`font-bold ${livePnL.pnlPercentage >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                                  {livePnL.pnlPercentage >= 0 ? '+' : ''}{livePnL.pnlPercentage.toFixed(2)}%
                                </div>
                              </div>
                            </div>
                          )}

                          <div className="grid grid-cols-3 gap-2 text-xs">
                            <div>
                              <div className="text-gray-400">Entry</div>
                              <div className="text-white">${position.entry_price.toLocaleString()}</div>
                            </div>
                            <div>
                              <div className="text-gray-400">Leverage</div>
                              <div className="text-white">{position.leverage}x</div>
                            </div>
                            <div>
                              <div className="text-gray-400">Margin</div>
                              <div className="text-white">${position.margin_used.toFixed(2)}</div>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              <div className="bg-[#2b3139] rounded-xl p-6">
                <h2 className="text-xl font-bold mb-4 flex items-center gap-2">
                  <TrendingDown className="w-5 h-5 text-gray-400" />
                  Closed Positions ({closedPositions.length})
                </h2>

                {closedPositions.length === 0 ? (
                  <div className="text-center py-12 text-gray-400">
                    No closed positions yet
                  </div>
                ) : (
                  <div className="space-y-3 max-h-[600px] overflow-y-auto">
                    {closedPositions.slice(0, 10).map((position) => (
                      <div key={position.id} className="bg-[#0b0e11] rounded-lg p-3 border border-gray-800">
                        <div className="flex items-center justify-between mb-2">
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-sm">{position.pair}</span>
                          </div>
                          <div className={`font-bold text-sm ${(position.pnl_percentage || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                            {(position.pnl_percentage || 0) >= 0 ? '+' : ''}{(position.pnl_percentage || 0).toFixed(2)}%
                          </div>
                        </div>
                        <div className="grid grid-cols-3 gap-2 text-xs">
                          <div>
                            <div className="text-gray-400">Entry</div>
                            <div className="text-white">${position.entry_price.toLocaleString()}</div>
                          </div>
                          <div>
                            <div className="text-gray-400">Exit</div>
                            <div className="text-white">${position.exit_price?.toLocaleString() || 'N/A'}</div>
                          </div>
                          <div>
                            <div className="text-gray-400">P&L</div>
                            <div className={(position.realized_pnl || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}>
                              ${(position.realized_pnl || 0).toFixed(2)}
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </>
        )}
      </div>

      {showPercentageModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-xl p-6 max-w-md w-full">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold">Execute % Trade</h3>
              <button onClick={() => setShowPercentageModal(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="bg-[#0b0e11] rounded-lg p-4 mb-4 border border-gray-700">
              <p className="text-sm text-gray-400 mb-2">
                Enter a target percentage gain or loss. The system will:
              </p>
              <ul className="text-xs text-gray-500 space-y-1">
                <li>• Pick a random trading pair</li>
                <li>• Calculate entry and exit prices</li>
                <li>• Execute and close the trade instantly</li>
                <li>• Update all follower balances</li>
              </ul>
            </div>

            <div className="mb-4">
              <label className="block text-sm text-gray-400 mb-2">Target Percentage</label>
              <div className="relative">
                <input
                  type="number"
                  step="0.1"
                  value={percentageForm.percentage}
                  onChange={(e) => setPercentageForm({ percentage: e.target.value })}
                  className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none pr-12"
                  placeholder="1.2"
                />
                <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400">%</span>
              </div>
              <p className="text-xs text-gray-500 mt-2">
                Examples: +1.2 (gain), -0.5 (loss), +5.0 (big win)
              </p>
            </div>

            {percentageForm.percentage && (
              <div className="bg-[#1a1d24] rounded-lg p-3 mb-4">
                <div className="text-xs text-gray-400 mb-1">If follower has 1000 USDT:</div>
                <div className={`text-lg font-bold ${parseFloat(percentageForm.percentage) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                  {parseFloat(percentageForm.percentage) >= 0 ? '+' : ''}${(1000 * parseFloat(percentageForm.percentage) / 100).toFixed(2)} USDT
                </div>
              </div>
            )}

            <button
              onClick={handleExecutePercentageTrade}
              className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold py-3 rounded-lg transition-all"
            >
              Execute Trade
            </button>
          </div>
        </div>
      )}

      {showFollowersModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-xl p-6 max-w-2xl w-full max-h-[80vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold">Followers ({followers.length})</h3>
              <button onClick={() => setShowFollowersModal(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="flex gap-4 mb-6 text-sm">
              <div className="bg-[#0ecb81]/10 text-[#0ecb81] px-4 py-2 rounded-lg font-semibold">
                {followers.filter(f => !f.is_mock).length} Real Copy Traders
              </div>
              <div className="bg-gray-700/50 text-gray-400 px-4 py-2 rounded-lg font-semibold">
                {followers.filter(f => f.is_mock).length} Mock Copy Traders
              </div>
            </div>

            {followers.length === 0 ? (
              <div className="text-center py-12 text-gray-400">
                No followers yet
              </div>
            ) : (
              <div className="space-y-3">
                {followers.filter(f => !f.is_mock).length > 0 && (
                  <>
                    <div className="text-sm font-semibold text-[#0ecb81] mb-2">Real Copy Traders</div>
                    {followers.filter(f => !f.is_mock).map((follower) => (
                      <div key={follower.user_id} className="bg-[#0b0e11] rounded-lg p-4 border border-[#0ecb81]/30">
                        <div className="flex items-center justify-between">
                          <div>
                            <div className="font-bold text-white flex items-center gap-2">
                              {follower.username || follower.email}
                              <span className="text-xs bg-[#0ecb81]/20 text-[#0ecb81] px-2 py-0.5 rounded font-semibold">REAL</span>
                            </div>
                            <div className="text-sm text-gray-400">{follower.email}</div>
                          </div>
                          <div className="text-right">
                            <div className="text-lg font-bold text-white">${follower.allocated_balance.toFixed(2)}</div>
                            <div className="text-xs text-gray-400">Allocated</div>
                          </div>
                        </div>
                        <div className="mt-2 pt-2 border-t border-gray-800 flex items-center justify-between text-xs">
                          <span className="text-gray-400">Joined {new Date(follower.created_at).toLocaleDateString()}</span>
                          <span className={`px-2 py-1 rounded font-bold ${
                            follower.is_active ? 'bg-[#0ecb81]/20 text-[#0ecb81]' : 'bg-gray-700 text-gray-400'
                          }`}>
                            {follower.is_active ? 'Active' : 'Paused'}
                          </span>
                        </div>
                      </div>
                    ))}
                  </>
                )}

                {followers.filter(f => f.is_mock).length > 0 && (
                  <>
                    <div className="text-sm font-semibold text-gray-500 mb-2 mt-4">Mock Copy Traders</div>
                    {followers.filter(f => f.is_mock).map((follower) => (
                      <div key={follower.user_id} className="bg-[#0b0e11] rounded-lg p-4 border border-gray-800 opacity-60">
                        <div className="flex items-center justify-between">
                          <div>
                            <div className="font-bold text-white flex items-center gap-2">
                              {follower.username || follower.email}
                              <span className="text-xs bg-gray-700/50 text-gray-400 px-2 py-0.5 rounded font-semibold">MOCK</span>
                            </div>
                            <div className="text-sm text-gray-400">{follower.email}</div>
                          </div>
                          <div className="text-right">
                            <div className="text-lg font-bold text-white">${follower.allocated_balance.toFixed(2)}</div>
                            <div className="text-xs text-gray-400">Allocated (Mock)</div>
                          </div>
                        </div>
                        <div className="mt-2 pt-2 border-t border-gray-800 flex items-center justify-between text-xs">
                          <span className="text-gray-400">Joined {new Date(follower.created_at).toLocaleDateString()}</span>
                          <span className={`px-2 py-1 rounded font-bold ${
                            follower.is_active ? 'bg-[#0ecb81]/20 text-[#0ecb81]' : 'bg-gray-700 text-gray-400'
                          }`}>
                            {follower.is_active ? 'Active' : 'Paused'}
                          </span>
                        </div>
                      </div>
                    ))}
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {showCloseModal && selectedPosition && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-xl p-6 max-w-md w-full">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold">Close Trade</h3>
              <button onClick={() => setShowCloseModal(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="bg-[#0b0e11] rounded-lg p-4 mb-6">
              <div className="flex items-center gap-2 mb-2">
                <span className="font-bold text-lg">{selectedPosition.pair}</span>
              </div>
              <div className="text-sm text-gray-400">
                Entry: ${selectedPosition.entry_price.toLocaleString()} | {selectedPosition.leverage}x Leverage
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Exit Price</label>
                <input
                  type="number"
                  step="0.01"
                  value={closeForm.exit_price}
                  onChange={(e) => setCloseForm({ ...closeForm, exit_price: e.target.value })}
                  className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                  placeholder="45000"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">P&L Percentage</label>
                <input
                  type="text"
                  value={closeForm.pnl_percentage}
                  readOnly
                  className="w-full bg-[#0b0e11]/50 text-white px-4 py-3 rounded-lg border border-gray-700 outline-none"
                />
                {closeForm.pnl_percentage && (
                  <div className="mt-2 p-3 bg-[#1a1d24] rounded-lg">
                    <p className={`text-lg font-bold ${parseFloat(closeForm.pnl_percentage) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                      {parseFloat(closeForm.pnl_percentage) >= 0 ? '+' : ''}${(selectedPosition.margin_used * parseFloat(closeForm.pnl_percentage) / 100).toFixed(2)} USDT
                    </p>
                  </div>
                )}
              </div>

              <div className="flex items-center gap-3 py-2 px-3 bg-[#0088cc]/10 rounded-lg border border-[#0088cc]/30">
                <input
                  type="checkbox"
                  id="close_auto_notify"
                  checked={closeForm.auto_notify}
                  onChange={(e) => setCloseForm({ ...closeForm, auto_notify: e.target.checked })}
                  className="w-5 h-5 rounded bg-[#0b0e11] border-gray-700 text-[#0088cc] focus:ring-[#0088cc]"
                />
                <label htmlFor="close_auto_notify" className="text-sm text-gray-300 flex items-center gap-2">
                  <Send className="w-4 h-4 text-[#0088cc]" />
                  Notify followers of trade closure
                </label>
              </div>
            </div>

            <button
              onClick={handleCloseTrade}
              disabled={!closeForm.exit_price || parseFloat(closeForm.exit_price) <= 0}
              className="w-full bg-[#f6465d] hover:bg-[#f6465d]/90 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-bold py-3 rounded-lg mt-6"
            >
              Close Trade
            </button>
          </div>
        </div>
      )}

      {showCreateModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-xl p-6 max-w-md w-full">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold">Create Managed Trader</h3>
              <button onClick={() => setShowCreateModal(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Name</label>
                <input
                  type="text"
                  value={traderForm.name}
                  onChange={(e) => setTraderForm({ ...traderForm, name: e.target.value })}
                  className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                  placeholder="Pro Trader"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">Avatar Emoji</label>
                <input
                  type="text"
                  value={traderForm.avatar}
                  onChange={(e) => setTraderForm({ ...traderForm, avatar: e.target.value })}
                  className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                  placeholder="🤖"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Rank</label>
                  <input
                    type="number"
                    value={traderForm.rank}
                    onChange={(e) => setTraderForm({ ...traderForm, rank: parseInt(e.target.value) || 1 })}
                    className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                    placeholder="1"
                    min="1"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Total Rank</label>
                  <select
                    value={traderForm.total_rank}
                    onChange={(e) => setTraderForm({ ...traderForm, total_rank: parseInt(e.target.value) })}
                    className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                  >
                    <option value="300">300</option>
                    <option value="400">400</option>
                    <option value="500">500</option>
                    <option value="600">600</option>
                    <option value="800">800</option>
                    <option value="1000">1000</option>
                  </select>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="api_verified"
                  checked={traderForm.api_verified}
                  onChange={(e) => setTraderForm({ ...traderForm, api_verified: e.target.checked })}
                  className="w-5 h-5 rounded bg-[#0b0e11] border-gray-700 text-[#fcd535] focus:ring-[#fcd535]"
                />
                <label htmlFor="api_verified" className="text-sm text-gray-300">API Verified</label>
              </div>
            </div>

            <button
              onClick={handleCreateTrader}
              className="w-full bg-[#fcd535] hover:bg-[#fcd535]/90 text-black font-bold py-3 rounded-lg mt-6"
            >
              Create Trader
            </button>
          </div>
        </div>
      )}

      {showBulkCreateModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-xl p-6 max-w-md w-full">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold">Bulk Create Traders</h3>
              <button onClick={() => setShowBulkCreateModal(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Number of Traders</label>
                <input
                  type="number"
                  min="1"
                  max="50"
                  value={bulkTraderCount}
                  onChange={(e) => setBulkTraderCount(e.target.value)}
                  className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                  placeholder="5"
                />
                <p className="text-xs text-gray-500 mt-1">Create between 1-50 traders at once</p>
              </div>

              <div className="bg-[#0b0e11] rounded-lg p-4 space-y-2">
                <h4 className="text-sm font-semibold text-gray-300 mb-2">What will be created:</h4>
                <div className="text-xs text-gray-400 space-y-1">
                  <p>- Random professional trader names</p>
                  <p>- Unique avatars and descriptions</p>
                  <p>- Ready to accept followers immediately</p>
                  <p>- Fully configured trading profiles</p>
                </div>
              </div>
            </div>

            <button
              onClick={handleBulkCreateTraders}
              className="w-full bg-[#0ecb81] hover:bg-[#0ecb81]/90 text-black font-bold py-3 rounded-lg mt-6"
            >
              Create {bulkTraderCount} Traders
            </button>
          </div>
        </div>
      )}

      {showTradeModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-xl p-6 max-w-md w-full max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold">Open Manual Trade</h3>
              <button onClick={() => setShowTradeModal(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Trading Pair ({ALL_CRYPTO_PAIRS.length} available)</label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                  <select
                    value={tradeForm.pair}
                    onChange={(e) => setTradeForm({ ...tradeForm, pair: e.target.value })}
                    className="w-full bg-[#0b0e11] text-white pl-10 pr-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none appearance-none cursor-pointer"
                  >
                    {ALL_CRYPTO_PAIRS.map(pair => (
                      <option key={pair} value={pair}>{pair}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">Entry Price</label>
                <input
                  type="number"
                  step="0.01"
                  value={tradeForm.entry_price}
                  onChange={(e) => setTradeForm({ ...tradeForm, entry_price: e.target.value })}
                  className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                  placeholder="Current market price"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">Leverage</label>
                <select
                  value={tradeForm.leverage}
                  onChange={(e) => setTradeForm({ ...tradeForm, leverage: e.target.value })}
                  className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                >
                  {[5, 10, 15, 20, 25, 50, 75, 100, 125].map(lev => (
                    <option key={lev} value={lev}>{lev}x</option>
                  ))}
                </select>
              </div>

              <div className="flex items-center gap-3 py-2">
                <input
                  type="checkbox"
                  id="use_percentage"
                  checked={tradeForm.use_percentage}
                  onChange={(e) => setTradeForm({ ...tradeForm, use_percentage: e.target.checked })}
                  className="w-5 h-5 rounded bg-[#0b0e11] border-gray-700 text-[#fcd535] focus:ring-[#fcd535]"
                />
                <label htmlFor="use_percentage" className="text-sm text-gray-300">Use % of trader balance</label>
              </div>

              {tradeForm.use_percentage ? (
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Percentage of Balance</label>
                  <div className="relative">
                    <input
                      type="number"
                      step="1"
                      value={tradeForm.percentage}
                      onChange={(e) => setTradeForm({ ...tradeForm, percentage: e.target.value })}
                      className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none pr-12"
                      placeholder="20"
                    />
                    <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400">%</span>
                  </div>
                </div>
              ) : (
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Quantity</label>
                  <input
                    type="number"
                    step="0.0001"
                    value={tradeForm.quantity}
                    onChange={(e) => setTradeForm({ ...tradeForm, quantity: e.target.value })}
                    className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                    placeholder="0.01"
                  />
                </div>
              )}

              {tradeForm.margin_used && (
                <div className="bg-[#0b0e11] rounded-lg p-3 border border-gray-700">
                  <div className="text-xs text-gray-400 mb-1">Margin Required</div>
                  <div className="text-lg font-bold text-white">${tradeForm.margin_used} USDT</div>
                </div>
              )}

              <div>
                <label className="block text-sm text-gray-400 mb-2">Notes (optional)</label>
                <input
                  type="text"
                  value={tradeForm.notes}
                  onChange={(e) => setTradeForm({ ...tradeForm, notes: e.target.value })}
                  className="w-full bg-[#0b0e11] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-[#fcd535] outline-none"
                  placeholder="Trade notes..."
                />
              </div>

              <div className="flex items-center gap-3 py-2 px-3 bg-[#0088cc]/10 rounded-lg border border-[#0088cc]/30">
                <input
                  type="checkbox"
                  id="auto_notify"
                  checked={tradeForm.auto_notify}
                  onChange={(e) => setTradeForm({ ...tradeForm, auto_notify: e.target.checked })}
                  className="w-5 h-5 rounded bg-[#0b0e11] border-gray-700 text-[#0088cc] focus:ring-[#0088cc]"
                />
                <label htmlFor="auto_notify" className="text-sm text-gray-300 flex items-center gap-2">
                  <Send className="w-4 h-4 text-[#0088cc]" />
                  Auto-send Telegram notifications
                </label>
              </div>
            </div>

            <button
              onClick={handleOpenTrade}
              disabled={!tradeForm.entry_price || !tradeForm.margin_used}
              className="w-full bg-[#0ecb81] hover:bg-[#0ecb81]/90 text-black font-bold py-3 rounded-lg mt-6 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Open Trade
            </button>
          </div>
        </div>
      )}

      {showNotificationModal && notificationPendingTradeId && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-xl p-6 max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold flex items-center gap-2">
                <MessageCircle className="w-5 h-5 text-[#0088cc]" />
                Telegram Notification Status
              </h3>
              <button
                onClick={() => {
                  setShowNotificationModal(false);
                  setNotificationPendingTradeId(null);
                }}
                className="text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <TelegramNotificationStatus
              pendingTradeId={notificationPendingTradeId}
              onResendComplete={() => {
                showSuccess('Notifications resent successfully');
              }}
            />

            <button
              onClick={() => {
                setShowNotificationModal(false);
                setNotificationPendingTradeId(null);
              }}
              className="w-full bg-[#2b3139] border border-gray-600 hover:border-gray-500 text-white font-bold py-3 rounded-lg mt-6"
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
