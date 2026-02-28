import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { useNavigation } from '../App';
import { Star, Search, TrendingUp, TrendingDown, Users as UsersIcon, Bell, RefreshCw, Send, TestTube2, Zap, Clock, AlertTriangle, X, CheckCircle, Shield, Timer } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../hooks/useToast';
import { ToastContainer } from '../components/Toast';
import CopyTradingModal from '../components/CopyTradingModal';
import PendingTradeCard from '../components/PendingTradeCard';
import TradeResponseModal from '../components/TradeResponseModal';

interface Trader {
  id: string;
  name: string;
  avatar: string;
  rank: number;
  total_rank: number;
  api_verified: boolean;
  pnl_7d: number;
  pnl_30d: number;
  pnl_90d: number;
  roi_7d: number;
  roi_30d: number;
  roi_90d: number;
  aum: number;
  mdd_30d: number;
  sharpe_ratio: number | null;
  followers_count: number;
}

type TimePeriod = '7' | '30' | '90';
type SortStat = 'pnl' | 'roi' | 'sharpe';

interface CopyRelationship {
  id: string;
  trader_id: string;
  initial_balance: string;
  current_balance: string;
  cumulative_pnl: string;
  leverage: number;
  is_active: boolean;
  is_mock: boolean;
  created_at: string;
  trader?: Trader;
  user_roi_30d?: number;
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
  status: string;
  total_accepted: number;
  total_declined: number;
  trader_name: string;
  trader_avatar: string;
  allocated_amount: number;
  follower_leverage: number;
  relationship_id: string;
}

function CopyTrading() {
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const { toasts, removeToast, showSuccess, showError } = useToast();
  const [activeTab, setActiveTab] = useState<'all' | 'favorites' | 'active' | 'pending' | 'mock'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [favorites, setFavorites] = useState<Set<string>>(new Set());
  const [traders, setTraders] = useState<Trader[]>([]);
  const [activeCopies, setActiveCopies] = useState<CopyRelationship[]>([]);
  const [mockCopies, setMockCopies] = useState<CopyRelationship[]>([]);
  const [hasAnyActiveRelationship, setHasAnyActiveRelationship] = useState(false);
  const [pendingTrades, setPendingTrades] = useState<PendingTrade[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedTrader, setSelectedTrader] = useState<Trader | null>(null);
  const [showCopyModal, setShowCopyModal] = useState(false);
  const [showMockCopyModal, setShowMockCopyModal] = useState(false);
  const [selectedTrade, setSelectedTrade] = useState<PendingTrade | null>(null);
  const [showResponseModal, setShowResponseModal] = useState(false);
  const [responseMode, setResponseMode] = useState<'accept' | 'decline'>('accept');
  const [submittingResponse, setSubmittingResponse] = useState(false);
  const [timePeriod, setTimePeriod] = useState<TimePeriod>('30');
  const [sortStat, setSortStat] = useState<SortStat>('pnl');
  const [pendingTradeIdFromUrl, setPendingTradeIdFromUrl] = useState<string | null>(null);
  const [hasTelegram, setHasTelegram] = useState(false);
  const [mockLoading, setMockLoading] = useState(false);
  const [autoAcceptEnabled, setAutoAcceptEnabled] = useState(false);
  const [autoAcceptUntil, setAutoAcceptUntil] = useState<string | null>(null);
  const [togglingAutoAccept, setTogglingAutoAccept] = useState(false);
  const [showAutoAcceptConfirmModal, setShowAutoAcceptConfirmModal] = useState(false);

  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const tradeId = urlParams.get('trade');
    if (tradeId) {
      setPendingTradeIdFromUrl(tradeId);
      setActiveTab('pending');
    }
  }, []);

  useEffect(() => {
    if (user && activeTab === 'mock') {
      loadMockCopies();
    }
  }, [user, activeTab]);

  useEffect(() => {
    if (pendingTradeIdFromUrl && pendingTrades.length > 0) {
      const targetTrade = pendingTrades.find(t => t.id === pendingTradeIdFromUrl);
      if (targetTrade) {
        setSelectedTrade(targetTrade);
        setResponseMode('accept');
        setShowResponseModal(true);
        setPendingTradeIdFromUrl(null);
        const url = new URL(window.location.href);
        url.searchParams.delete('trade');
        window.history.replaceState({}, '', url.toString());
      }
    }
  }, [pendingTradeIdFromUrl, pendingTrades]);

  useEffect(() => {
    loadTraders();
  }, [timePeriod, sortStat]);

  useEffect(() => {
    loadTraders();
    if (user) {
      loadFavorites();
      loadActiveCopies();
      loadPendingTrades();
      checkTelegramStatus();
      loadAutoAcceptStatus();

      // Periodically expire old trades and check auto-accept (every 30 seconds)
      const expireInterval = setInterval(async () => {
        try {
          await fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/expire-pending-trades`,
            { method: 'POST' }
          );
          loadPendingTrades();
          loadAutoAcceptStatus();
        } catch (error) {
          console.error('Error expiring trades:', error);
        }
      }, 30000);

      // Set up real-time subscription for pending trades
      const channel = supabase
        .channel('pending_trades_changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'pending_copy_trades'
          },
          () => {
            loadPendingTrades();
          }
        )
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'copy_trade_notifications',
            filter: `follower_id=eq.${user.id}`
          },
          () => {
            loadPendingTrades();
          }
        )
        .subscribe();

      return () => {
        clearInterval(expireInterval);
        supabase.removeChannel(channel);
      };
    }
  }, [user]);

  const loadTraders = async () => {
    try {
      const { data, error } = await supabase
        .from('traders')
        .select('*')
        .eq('is_featured', true);

      if (error) throw error;

      if (data) {
        const formattedTraders: Trader[] = data.map(trader => ({
          id: trader.id,
          name: trader.name,
          avatar: trader.avatar,
          rank: trader.rank,
          total_rank: trader.total_rank,
          api_verified: trader.api_verified,
          pnl_7d: parseFloat(trader.pnl_7d || '0'),
          pnl_30d: parseFloat(trader.pnl_30d || '0'),
          pnl_90d: parseFloat(trader.pnl_90d || '0'),
          roi_7d: parseFloat(trader.roi_7d || '0'),
          roi_30d: parseFloat(trader.roi_30d || '0'),
          roi_90d: parseFloat(trader.roi_90d || '0'),
          aum: parseFloat(trader.aum || '0'),
          mdd_30d: parseFloat(trader.mdd_30d || '0'),
          sharpe_ratio: trader.sharpe_ratio ? parseFloat(trader.sharpe_ratio) : null,
          followers_count: trader.followers_count
        }));

        const sortedTraders = formattedTraders.sort((a, b) => {
          if (a.name === 'Satoshi Academy') return -1;
          if (b.name === 'Satoshi Academy') return 1;

          let aValue: number;
          let bValue: number;

          if (sortStat === 'pnl') {
            aValue = timePeriod === '7' ? a.pnl_7d : timePeriod === '90' ? a.pnl_90d : a.pnl_30d;
            bValue = timePeriod === '7' ? b.pnl_7d : timePeriod === '90' ? b.pnl_90d : b.pnl_30d;
          } else if (sortStat === 'roi') {
            aValue = timePeriod === '7' ? a.roi_7d : timePeriod === '90' ? a.roi_90d : a.roi_30d;
            bValue = timePeriod === '7' ? b.roi_7d : timePeriod === '90' ? b.roi_90d : b.roi_30d;
          } else {
            aValue = a.sharpe_ratio || 0;
            bValue = b.sharpe_ratio || 0;
          }

          return bValue - aValue;
        });

        setTraders(sortedTraders);
      }
    } catch (error) {
      console.error('Error loading traders:', error);
      showError('Failed to load traders');
    } finally {
      setLoading(false);
    }
  };

  const loadFavorites = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('favorites')
        .select('trader_id')
        .eq('user_id', user.id);

      if (error) throw error;

      setFavorites(new Set(data?.map(f => f.trader_id) || []));
    } catch (error) {
      console.error('Error loading favorites:', error);
    }
  };

  const loadActiveCopies = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('copy_relationships')
        .select(`
          *,
          traders:trader_id (*)
        `)
        .eq('follower_id', user.id)
        .eq('is_active', true)
        .eq('is_mock', false)
        .order('created_at', { ascending: false });

      if (error) throw error;

      if (data) {
        const formattedCopiesPromises = data.map(async (copy) => {
          const initialBalance = parseFloat(copy.initial_balance || '0');
          const currentBalance = parseFloat(copy.current_balance || '0');

          let userRoi30d = 0;
          if (initialBalance > 0) {
            userRoi30d = ((currentBalance - initialBalance) / initialBalance) * 100;
          }

          return {
            id: copy.id,
            trader_id: copy.trader_id,
            initial_balance: copy.initial_balance || '0',
            current_balance: copy.current_balance || '0',
            cumulative_pnl: copy.cumulative_pnl || '0',
            leverage: copy.leverage,
            is_active: copy.is_active,
            is_mock: copy.is_mock,
            created_at: copy.created_at,
            user_roi_30d: userRoi30d,
            trader: copy.traders ? {
              id: (copy.traders as any).id,
              name: (copy.traders as any).name,
              avatar: (copy.traders as any).avatar,
              rank: (copy.traders as any).rank,
              total_rank: (copy.traders as any).total_rank,
              api_verified: (copy.traders as any).api_verified,
              pnl_7d: parseFloat((copy.traders as any).pnl_7d || '0'),
              pnl_30d: parseFloat((copy.traders as any).pnl_30d || '0'),
              pnl_90d: parseFloat((copy.traders as any).pnl_90d || '0'),
              roi_7d: parseFloat((copy.traders as any).roi_7d || '0'),
              roi_30d: parseFloat((copy.traders as any).roi_30d || '0'),
              roi_90d: parseFloat((copy.traders as any).roi_90d || '0'),
              aum: parseFloat((copy.traders as any).aum || '0'),
              mdd_30d: parseFloat((copy.traders as any).mdd_30d || '0'),
              sharpe_ratio: (copy.traders as any).sharpe_ratio ? parseFloat((copy.traders as any).sharpe_ratio) : null,
              followers_count: (copy.traders as any).followers_count
            } : undefined
          };
        });

        const formattedCopies = await Promise.all(formattedCopiesPromises);
        setActiveCopies(formattedCopies);
        if (formattedCopies.length > 0) {
          setHasAnyActiveRelationship(true);
          return;
        }
      }

      const { count } = await supabase
        .from('copy_relationships')
        .select('id', { count: 'exact', head: true })
        .eq('follower_id', user.id)
        .eq('is_active', true)
        .eq('is_mock', true);

      setHasAnyActiveRelationship((count || 0) > 0);
    } catch (error) {
      console.error('Error loading active copies:', error);
    }
  };

  const loadMockCopies = async () => {
    if (!user) return;
    setMockLoading(true);

    try {
      const { data, error } = await supabase
        .from('copy_relationships')
        .select(`
          *,
          traders:trader_id (*)
        `)
        .eq('follower_id', user.id)
        .eq('is_active', true)
        .eq('is_mock', true)
        .order('created_at', { ascending: false });

      if (error) throw error;

      if (data) {
        const formattedCopiesPromises = data.map(async (copy) => {
          const initialBalance = parseFloat(copy.initial_balance || '0');
          const currentBalance = parseFloat(copy.current_balance || '0');

          let userRoi30d = 0;
          if (initialBalance > 0) {
            userRoi30d = ((currentBalance - initialBalance) / initialBalance) * 100;
          }

          return {
            id: copy.id,
            trader_id: copy.trader_id,
            initial_balance: copy.initial_balance || '0',
            current_balance: copy.current_balance || '0',
            cumulative_pnl: copy.cumulative_pnl || '0',
            leverage: copy.leverage,
            is_active: copy.is_active,
            is_mock: copy.is_mock,
            created_at: copy.created_at,
            user_roi_30d: userRoi30d,
            trader: copy.traders ? {
              id: (copy.traders as any).id,
              name: (copy.traders as any).name,
              avatar: (copy.traders as any).avatar,
              rank: (copy.traders as any).rank,
              total_rank: (copy.traders as any).total_rank,
              api_verified: (copy.traders as any).api_verified,
              pnl_7d: parseFloat((copy.traders as any).pnl_7d || '0'),
              pnl_30d: parseFloat((copy.traders as any).pnl_30d || '0'),
              pnl_90d: parseFloat((copy.traders as any).pnl_90d || '0'),
              roi_7d: parseFloat((copy.traders as any).roi_7d || '0'),
              roi_30d: parseFloat((copy.traders as any).roi_30d || '0'),
              roi_90d: parseFloat((copy.traders as any).roi_90d || '0'),
              aum: parseFloat((copy.traders as any).aum || '0'),
              mdd_30d: parseFloat((copy.traders as any).mdd_30d || '0'),
              sharpe_ratio: (copy.traders as any).sharpe_ratio ? parseFloat((copy.traders as any).sharpe_ratio) : null,
              followers_count: (copy.traders as any).followers_count
            } : undefined
          };
        });

        const formattedCopies = await Promise.all(formattedCopiesPromises);
        setMockCopies(formattedCopies);
      }
    } catch (error) {
      console.error('Error loading mock copies:', error);
    } finally {
      setMockLoading(false);
    }
  };

  const handleStopMockCopy = async (copyId: string, traderName: string) => {
    if (!user) return;

    try {
      const { error } = await supabase
        .from('copy_relationships')
        .update({ is_active: false })
        .eq('id', copyId);

      if (error) throw error;

      showSuccess(`Stopped mock copying ${traderName}`);
      await loadMockCopies();
    } catch (error: any) {
      console.error('Error stopping mock copy:', error);
      showError(error.message || 'Failed to stop mock copying');
    }
  };

  const toggleFavorite = async (traderId: string) => {
    if (!user) {
      showError('Please sign in to add favorites');
      return;
    }

    const isFavorite = favorites.has(traderId);

    try {
      if (isFavorite) {
        const { error } = await supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('trader_id', traderId);

        if (error) throw error;

        setFavorites(prev => {
          const next = new Set(prev);
          next.delete(traderId);
          return next;
        });
        showSuccess('Removed from favorites');
      } else {
        const { error } = await supabase
          .from('favorites')
          .insert({ user_id: user.id, trader_id: traderId });

        if (error) throw error;

        setFavorites(prev => new Set(prev).add(traderId));
        showSuccess('Added to favorites');
      }
    } catch (error: any) {
      console.error('Error toggling favorite:', error);
      showError(error.message || 'Failed to update favorites');
    }
  };

  const handleStopCopy = async (copyId: string, traderName: string) => {
    if (!user) return;

    try {
      const { error } = await supabase
        .from('copy_relationships')
        .update({ is_active: false })
        .eq('id', copyId);

      if (error) throw error;

      showSuccess(`Stopped copying ${traderName}`);
      await loadActiveCopies();
    } catch (error: any) {
      console.error('Error stopping copy:', error);
      showError(error.message || 'Failed to stop copying');
    }
  };

  const loadPendingTrades = async () => {
    if (!user) return;

    try {
      const { data: relationships, error: relError } = await supabase
        .from('copy_relationships')
        .select('*, traders:trader_id(id, name, avatar)')
        .eq('follower_id', user.id)
        .eq('status', 'active')
        .eq('is_active', true);

      if (relError) throw relError;

      if (!relationships || relationships.length === 0) {
        setPendingTrades([]);
        return;
      }

      const traderIds = relationships.map(r => r.trader_id);

      const { data: trades, error: tradesError } = await supabase
        .from('pending_copy_trades')
        .select('*')
        .or(`trader_id.in.(${traderIds.join(',')}),admin_trader_id.in.(${traderIds.join(',')})`)
        .eq('status', 'pending')
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false });

      if (tradesError) throw tradesError;

      if (!trades || trades.length === 0) {
        setPendingTrades([]);
        return;
      }

      const tradeIds = trades.map(t => t.id);
      const { data: responses, error: responsesError } = await supabase
        .from('pending_trade_responses')
        .select('pending_trade_id')
        .eq('follower_id', user.id)
        .in('pending_trade_id', tradeIds);

      if (responsesError) throw responsesError;

      const respondedTradeIds = new Set(responses?.map(r => r.pending_trade_id) || []);

      const enrichedTradesPromises = trades
        .filter(trade => !respondedTradeIds.has(trade.id))
        .map(async (trade) => {
          const relationship = relationships.find(r =>
            r.trader_id === trade.trader_id || r.trader_id === trade.admin_trader_id
          );
          const trader = relationship?.traders as any;

          let followerBalance = 0;
          if (relationship?.is_mock) {
            followerBalance = relationship?.current_balance || 0;
          } else {
            const { data: walletData } = await supabase
              .from('wallets')
              .select('balance')
              .eq('user_id', user.id)
              .eq('currency', 'USDT')
              .eq('wallet_type', 'copy')
              .maybeSingle();
            followerBalance = walletData?.balance || 0;
          }

          let allocatedAmount = (followerBalance * parseFloat(trade.margin_percentage)) / 100;

          if (relationship?.allocation_percentage && relationship.allocation_percentage > 0) {
            allocatedAmount = allocatedAmount * (relationship.allocation_percentage / 100);
          }

          const followerLeverage = trade.leverage * (relationship?.leverage || 1);

          return {
            ...trade,
            entry_price: parseFloat(trade.entry_price),
            quantity: parseFloat(trade.quantity),
            margin_used: parseFloat(trade.margin_used),
            margin_percentage: parseFloat(trade.margin_percentage),
            trader_name: trader?.name || 'Unknown Trader',
            trader_avatar: trader?.avatar || '🤖',
            allocated_amount: allocatedAmount,
            follower_leverage: followerLeverage,
            relationship_id: relationship?.id || ''
          };
        });

      const enrichedTrades = await Promise.all(enrichedTradesPromises);

      setPendingTrades(enrichedTrades);
    } catch (error) {
      console.error('Error loading pending trades:', error);
    }
  };

  const checkTelegramStatus = async () => {
    if (!user) return;
    try {
      const { data } = await supabase
        .from('user_profiles')
        .select('telegram_chat_id')
        .eq('id', user.id)
        .maybeSingle();
      setHasTelegram(!!data?.telegram_chat_id);
    } catch (error) {
      console.error('Error checking telegram status:', error);
    }
  };

  const loadAutoAcceptStatus = async () => {
    if (!user) return;
    try {
      const { data, error } = await supabase.rpc('get_copy_auto_accept_status');
      if (error) throw error;
      setAutoAcceptEnabled(data?.is_active || false);
      setAutoAcceptUntil(data?.until || null);
    } catch (error) {
      console.error('Error loading auto-accept status:', error);
    }
  };

  const handleAutoAcceptToggleClick = () => {
    if (autoAcceptEnabled) {
      toggleAutoAccept(false);
    } else {
      setShowAutoAcceptConfirmModal(true);
    }
  };

  const toggleAutoAccept = async (enable: boolean) => {
    if (!user || togglingAutoAccept) return;
    setTogglingAutoAccept(true);
    setShowAutoAcceptConfirmModal(false);
    try {
      const { data, error } = await supabase.rpc('toggle_copy_auto_accept', {
        p_enable: enable
      });
      if (error) throw error;
      setAutoAcceptEnabled(data?.enabled || false);
      setAutoAcceptUntil(data?.until || null);
      if (enable) {
        showSuccess('Auto-accept enabled for 24 hours');
      } else {
        showSuccess('Auto-accept disabled');
      }
    } catch (error: any) {
      console.error('Error toggling auto-accept:', error);
      showError(error.message || 'Failed to toggle auto-accept');
    } finally {
      setTogglingAutoAccept(false);
    }
  };

  const getTimeRemaining = () => {
    if (!autoAcceptUntil) return '';
    const now = new Date();
    const until = new Date(autoAcceptUntil);
    const diff = until.getTime() - now.getTime();
    if (diff <= 0) return 'Expired';
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    return `${hours}h ${minutes}m`;
  };

  const handleAcceptClick = (trade: PendingTrade) => {
    setSelectedTrade(trade);
    setResponseMode('accept');
    setShowResponseModal(true);
  };

  const handleDeclineClick = (trade: PendingTrade) => {
    setSelectedTrade(trade);
    setResponseMode('decline');
    setShowResponseModal(true);
  };

  const handleConfirmResponse = async (riskAcknowledged: boolean, declineReason?: string) => {
    if (!user || !selectedTrade) return;

    setSubmittingResponse(true);
    try {
      const { error } = await supabase.rpc('respond_to_copy_trade', {
        p_trade_id: selectedTrade.id,
        p_follower_id: user.id,
        p_response: responseMode === 'accept' ? 'accepted' : 'declined',
        p_decline_reason: declineReason || null,
        p_risk_acknowledged: riskAcknowledged
      });

      if (error) throw error;

      showSuccess(
        responseMode === 'accept'
          ? 'Trade accepted successfully!'
          : 'Trade declined'
      );

      await loadPendingTrades();

      setShowResponseModal(false);
      setSelectedTrade(null);
    } catch (error: any) {
      console.error('Error responding to trade:', error);
      showError(error.message || 'Failed to respond to trade');
    } finally {
      setSubmittingResponse(false);
    }
  };

  const filteredTraders = traders.filter(trader => {
    if (activeTab === 'favorites' && !favorites.has(trader.id)) {
      return false;
    }
    if (searchQuery && !trader.name.toLowerCase().includes(searchQuery.toLowerCase())) {
      return false;
    }
    return true;
  });

  return (
    <div className="min-h-screen bg-[#181a20] text-white relative overflow-hidden">
      <div className="fixed inset-0 pointer-events-none">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-[#fcd535]/5 rounded-full blur-[120px] animate-pulse"></div>
        <div className="absolute top-1/3 right-1/4 w-[500px] h-[500px] bg-[#0ecb81]/5 rounded-full blur-[140px] animate-pulse" style={{ animationDelay: '1s' }}></div>
        <div className="absolute bottom-1/4 left-1/2 w-96 h-96 bg-blue-500/5 rounded-full blur-[100px] animate-pulse" style={{ animationDelay: '2s' }}></div>
      </div>

      <Navbar />
      <ToastContainer toasts={toasts} removeToast={removeToast} />

      <div className="max-w-[1400px] mx-auto px-3 sm:px-6 py-4 sm:py-6 relative z-10">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-0 mb-4 sm:mb-6">
          <div className="relative">
            <div className="flex items-center gap-4 sm:gap-8 overflow-x-auto pb-1 pr-4 -mr-3 sm:mr-0 sm:pr-0" style={{ scrollbarWidth: 'none', msOverflowStyle: 'none', WebkitOverflowScrolling: 'touch' }}>
            <button
              onClick={() => setActiveTab('all')}
              className={`pb-2 text-sm sm:text-base transition-colors relative whitespace-nowrap ${
                activeTab === 'all'
                  ? 'text-white font-medium'
                  : 'text-gray-400 hover:text-gray-300'
              }`}
            >
              All Portfolios
              {activeTab === 'all' && (
                <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-[#fcd535]"></div>
              )}
            </button>
            <button
              onClick={() => setActiveTab('favorites')}
              className={`pb-2 text-sm sm:text-base transition-colors relative whitespace-nowrap ${
                activeTab === 'favorites'
                  ? 'text-white font-medium'
                  : 'text-gray-400 hover:text-gray-300'
              }`}
            >
              My Favorites
              {activeTab === 'favorites' && (
                <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-[#fcd535]"></div>
              )}
            </button>
            <button
              onClick={() => setActiveTab('active')}
              className={`pb-2 text-sm sm:text-base transition-colors relative flex items-center gap-2 whitespace-nowrap ${
                activeTab === 'active'
                  ? 'text-white font-medium'
                  : 'text-gray-400 hover:text-gray-300'
              }`}
            >
              <span className="hidden sm:inline">Active</span> Copying
              {activeCopies.length > 0 && (
                <span className="bg-[#fcd535] text-[#0b0e11] text-xs px-1.5 py-0.5 rounded-full font-semibold">
                  {activeCopies.length}
                </span>
              )}
              {activeTab === 'active' && (
                <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-[#fcd535]"></div>
              )}
            </button>
            <button
              onClick={() => setActiveTab('pending')}
              className={`pb-2 text-sm sm:text-base transition-colors relative flex items-center gap-2 whitespace-nowrap ${
                activeTab === 'pending'
                  ? 'text-white font-medium'
                  : 'text-gray-400 hover:text-gray-300'
              }`}
            >
              <Bell className="w-4 h-4" />
              <span className="hidden sm:inline">Pending</span> Signals
              {pendingTrades.length > 0 && (
                <span className="bg-[#fcd535] text-[#0b0e11] text-xs px-1.5 py-0.5 rounded-full font-semibold animate-pulse">
                  {pendingTrades.length}
                </span>
              )}
              {activeTab === 'pending' && (
                <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-[#fcd535]"></div>
              )}
            </button>
            <button
              onClick={() => setActiveTab('mock')}
              className={`pb-2 text-sm sm:text-base transition-colors relative flex items-center gap-2 whitespace-nowrap ${
                activeTab === 'mock'
                  ? 'text-white font-medium'
                  : 'text-gray-400 hover:text-gray-300'
              }`}
            >
              <TestTube2 className="w-4 h-4" />
              <span className="hidden sm:inline">Mock</span> Trading
              {mockCopies.length > 0 && (
                <span className="bg-[#fcd535] text-[#0b0e11] text-xs px-1.5 py-0.5 rounded-full font-semibold">
                  {mockCopies.length}
                </span>
              )}
              {activeTab === 'mock' && (
                <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-[#fcd535]"></div>
              )}
            </button>
            </div>
            <div className="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-[#181a20] to-transparent pointer-events-none sm:hidden" />
          </div>

          {user && !hasTelegram && (
            <button
              onClick={() => navigateTo('profile', { section: 'notifications' })}
              className="flex items-center gap-2 bg-[#0088cc]/20 hover:bg-[#0088cc]/30 text-[#0088cc] px-3 py-1.5 rounded-lg text-sm font-medium transition-all border border-[#0088cc]/30"
            >
              <Send className="w-4 h-4" />
              <span>Connect Telegram</span>
            </button>
          )}
        </div>

        {activeTab !== 'active' && activeTab !== 'pending' && activeTab !== 'mock' && (
          <div className="mb-4 sm:mb-6 flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1 sm:max-w-xs">
              <Search className="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-[#848e9c]" />
              <input
                type="text"
                placeholder="Trader's Name"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-[#2b3139]/80 backdrop-blur-sm border border-[#3a4149]/50 rounded-lg pl-9 pr-3 py-2 text-[#eaecef] text-sm outline-none focus:bg-[#353c47]/90 focus:border-[#fcd535]/50 transition-all placeholder:text-[#848e9c] shadow-sm"
              />
            </div>

            <div className="flex items-center gap-2 overflow-x-auto scrollbar-hide">
              <select
                value={timePeriod}
                onChange={(e) => setTimePeriod(e.target.value as TimePeriod)}
                className="bg-[#2b3139]/80 backdrop-blur-sm border border-[#3a4149]/50 rounded-lg px-3 py-2 text-[#eaecef] text-sm outline-none focus:bg-[#353c47]/90 focus:border-[#fcd535]/50 transition-all cursor-pointer flex-shrink-0 shadow-sm"
              >
                <option value="7">7 Days</option>
                <option value="30">30 Days</option>
                <option value="90">90 Days</option>
              </select>

              <select
                value={sortStat}
                onChange={(e) => setSortStat(e.target.value as SortStat)}
                className="bg-[#2b3139]/80 backdrop-blur-sm border border-[#3a4149]/50 rounded-lg px-3 py-2 text-[#eaecef] text-sm outline-none focus:bg-[#353c47]/90 focus:border-[#fcd535]/50 transition-all cursor-pointer flex-shrink-0 shadow-sm"
              >
                <option value="pnl">PnL</option>
                <option value="roi">ROI</option>
                <option value="sharpe">Sharpe Ratio</option>
              </select>
            </div>
          </div>
        )}

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="animate-spin w-12 h-12 border-4 border-[#fcd535] border-t-transparent rounded-full"></div>
          </div>
        ) : activeTab === 'pending' ? (
          <div>
            {user && hasAnyActiveRelationship && (
              <div className="mb-6 p-4 bg-gradient-to-r from-[#2b3139]/80 to-[#252931]/80 rounded-xl border border-[#3a4149]/50">
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded-lg ${autoAcceptEnabled ? 'bg-[#0ecb81]/20' : 'bg-[#3a4149]/50'}`}>
                      <Zap className={`w-5 h-5 ${autoAcceptEnabled ? 'text-[#0ecb81]' : 'text-gray-400'}`} />
                    </div>
                    <div>
                      <h3 className="text-white font-semibold text-sm sm:text-base">Auto-Accept Trades</h3>
                      <p className="text-gray-400 text-xs sm:text-sm">
                        {autoAcceptEnabled
                          ? `Active for ${getTimeRemaining()} - trades are automatically accepted`
                          : 'Enable to auto-accept all trades for 24 hours'}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    {autoAcceptEnabled && (
                      <div className="flex items-center gap-1.5 text-[#0ecb81] text-xs sm:text-sm bg-[#0ecb81]/10 px-3 py-1.5 rounded-lg">
                        <Clock className="w-4 h-4" />
                        <span className="font-medium">{getTimeRemaining()}</span>
                      </div>
                    )}
                    <button
                      onClick={handleAutoAcceptToggleClick}
                      disabled={togglingAutoAccept}
                      className={`relative inline-flex h-7 w-14 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-[#fcd535]/50 ${
                        autoAcceptEnabled ? 'bg-[#0ecb81]' : 'bg-[#3a4149]'
                      } ${togglingAutoAccept ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
                    >
                      <span
                        className={`inline-block h-5 w-5 transform rounded-full bg-white shadow-lg transition-transform ${
                          autoAcceptEnabled ? 'translate-x-8' : 'translate-x-1'
                        }`}
                      />
                    </button>
                  </div>
                </div>
                {autoAcceptEnabled && (
                  <div className="mt-3 pt-3 border-t border-[#3a4149]/50">
                    <p className="text-xs text-gray-500">
                      When enabled, all incoming trade signals from traders you follow will be automatically accepted using your configured allocation settings.
                      This will turn off automatically after 24 hours.
                    </p>
                  </div>
                )}
              </div>
            )}
            {pendingTrades.length === 0 ? (
              <div className="text-center py-12 sm:py-20 px-4">
                <Bell className="w-12 sm:w-16 h-12 sm:h-16 mx-auto mb-4 text-gray-600" />
                <h3 className="text-lg sm:text-xl font-semibold mb-2">No Pending Signals</h3>
                <p className="text-gray-400 mb-6 text-sm sm:text-base">
                  {autoAcceptEnabled
                    ? 'Auto-accept is enabled. New trades will be automatically accepted.'
                    : "You'll see trade signals here when traders you follow post new trades"}
                </p>
                <button
                  onClick={() => setActiveTab('all')}
                  className="bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] px-5 sm:px-6 py-2.5 sm:py-3 rounded-lg font-medium transition-all text-sm sm:text-base"
                >
                  Browse Traders
                </button>
              </div>
            ) : (
              <div className="grid gap-4 sm:gap-6 grid-cols-1 md:grid-cols-2">
                {pendingTrades.map((trade) => (
                  <PendingTradeCard
                    key={trade.id}
                    trade={trade}
                    allocatedAmount={trade.allocated_amount}
                    followerLeverage={trade.follower_leverage}
                    onAccept={() => handleAcceptClick(trade)}
                    onDecline={() => handleDeclineClick(trade)}
                    disabled={submittingResponse}
                  />
                ))}
              </div>
            )}
          </div>
        ) : activeTab === 'active' ? (
          <div>
            {activeCopies.length === 0 ? (
              <div className="text-center py-12 sm:py-20 px-4">
                <div className="text-gray-500 text-base sm:text-lg mb-2">No active copy trading</div>
                <p className="text-gray-600 text-xs sm:text-sm mb-6">
                  Start copying successful traders to begin earning
                </p>
                <button
                  onClick={() => setActiveTab('all')}
                  className="bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] px-5 sm:px-6 py-2.5 sm:py-3 rounded-lg font-medium transition-all text-sm sm:text-base"
                >
                  Browse Traders
                </button>
              </div>
            ) : (
              <div className="space-y-4">
                {activeCopies.map((copy) => (
                  <div
                    key={copy.id}
                    className="relative bg-gradient-to-br from-[#2b3139]/80 to-[#252931]/80 backdrop-blur-xl rounded-xl p-4 sm:p-6 hover:from-[#353c47]/90 hover:to-[#2d323b]/90 transition-all duration-300 cursor-pointer border border-[#3a4149]/50 hover:border-[#0ecb81]/60 group shadow-lg hover:shadow-2xl hover:shadow-[#0ecb81]/10"
                    onClick={() => {
                      window.history.pushState({}, '', `?page=activecopying&id=${copy.id}`);
                      navigateTo('activecopying');
                    }}
                  >
                    <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-[#0ecb81]/0 via-[#0ecb81]/0 to-[#0ecb81]/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                    <div className="absolute inset-0 rounded-xl bg-gradient-to-tr from-transparent via-white/0 to-white/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                    <div className="relative z-10">
                    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                      <div className="flex items-center gap-3 sm:gap-4 flex-1">
                        <div className="relative">
                          <div
                            className="text-3xl sm:text-4xl cursor-pointer transform transition-transform group-hover:scale-110"
                            onClick={(e) => {
                              e.stopPropagation();
                              window.history.pushState({}, '', `?page=traderprofile&id=${copy.trader_id}`);
                              navigateTo('traderprofile');
                            }}
                          >
                            {copy.trader?.avatar}
                          </div>
                          {copy.trader?.api_verified && (
                            <div className="absolute -bottom-1 -right-1 bg-blue-500 rounded-full p-0.5 ring-2 ring-[#2b3139]">
                              <svg className="w-2.5 h-2.5 text-white" fill="currentColor" viewBox="0 0 16 16">
                                <path d="M10.97 4.97a.75.75 0 0 1 1.07 1.05l-3.99 4.99a.75.75 0 0 1-1.08.02L4.324 8.384a.75.75 0 1 1 1.06-1.06l2.094 2.093 3.473-4.425a.267.267 0 0 1 .02-.022z"/>
                              </svg>
                            </div>
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-2">
                            <span
                              className="text-white text-base sm:text-lg font-bold cursor-pointer hover:text-[#fcd535] transition-colors truncate"
                              onClick={(e) => {
                                e.stopPropagation();
                                window.history.pushState({}, '', `?page=traderprofile&id=${copy.trader_id}`);
                                navigateTo('traderprofile');
                              }}
                            >
                              {copy.trader?.name}
                            </span>
                            <span className="bg-[#0ecb81]/20 text-[#0ecb81] text-[10px] px-2 py-0.5 rounded-full font-bold flex-shrink-0 animate-pulse">
                              LIVE
                            </span>
                          </div>
                          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs sm:text-sm text-[#848e9c]">
                            <span className="font-medium">{parseFloat(copy.initial_balance).toFixed(2)} USDT</span>
                            <span className="text-[#5a6169]">•</span>
                            <span className="font-medium">{copy.leverage}x Leverage</span>
                            <span className="text-[#5a6169]">•</span>
                            <span className="hidden sm:inline">{new Date(copy.created_at).toLocaleDateString()}</span>
                          </div>
                        </div>
                        <div className="sm:hidden text-right bg-black/30 backdrop-blur-sm rounded-lg px-3 py-2 border border-[#3a4149]/30 shadow-inner">
                          <div className={`text-lg font-bold ${(copy.user_roi_30d || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                            {(copy.user_roi_30d || 0) >= 0 ? '+' : ''}{(copy.user_roi_30d || 0).toFixed(2)}%
                          </div>
                          <div className="text-[#848e9c] text-[10px] uppercase tracking-wider font-semibold">Your ROI</div>
                        </div>
                      </div>

                      <div className="flex items-center justify-between sm:justify-end gap-4">
                        <div className="hidden sm:block text-right bg-black/30 backdrop-blur-sm rounded-lg px-4 py-3 border border-[#3a4149]/30 shadow-inner">
                          <div className="text-[#848e9c] text-[10px] uppercase tracking-wider font-semibold mb-1">Your ROI</div>
                          <div className={`text-2xl font-bold ${(copy.user_roi_30d || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                            {(copy.user_roi_30d || 0) >= 0 ? '+' : ''}{(copy.user_roi_30d || 0).toFixed(2)}%
                          </div>
                        </div>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            window.history.pushState({}, '', `?page=activecopying&id=${copy.id}`);
                            navigateTo('activecopying');
                          }}
                          className="bg-gradient-to-r from-[#fcd535] to-[#f0b90b] hover:from-[#f0b90b] hover:to-[#fcd535] text-[#0b0e11] px-4 sm:px-6 py-2.5 rounded-lg text-sm font-bold transition-all flex-1 sm:flex-none hover:shadow-lg hover:shadow-[#fcd535]/20"
                        >
                          View Details
                        </button>
                      </div>
                    </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : activeTab === 'mock' ? (
          <div>
            {mockLoading ? (
              <div className="flex items-center justify-center py-20">
                <div className="animate-spin w-12 h-12 border-4 border-[#fcd535] border-t-transparent rounded-full"></div>
              </div>
            ) : mockCopies.length === 0 ? (
              <div className="text-center py-12 sm:py-20 px-4">
                <TestTube2 className="w-12 sm:w-16 h-12 sm:h-16 mx-auto mb-4 text-gray-600" />
                <h3 className="text-lg sm:text-xl font-semibold mb-2">No Mock Copy Trading</h3>
                <p className="text-gray-400 mb-6 text-sm sm:text-base max-w-md mx-auto">
                  Practice copy trading without risking real funds. Start mock copying a trader to see how their strategies perform.
                </p>
                <button
                  onClick={() => setActiveTab('all')}
                  className="bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] px-5 sm:px-6 py-2.5 sm:py-3 rounded-lg font-medium transition-all text-sm sm:text-base"
                >
                  Browse Traders
                </button>
              </div>
            ) : (
              <div className="space-y-4">
                <div className="bg-gradient-to-r from-[#fcd535]/10 to-[#f0b90b]/5 rounded-xl p-4 mb-4 border border-[#fcd535]/30 shadow-lg">
                  <div className="flex items-center gap-2 text-[#fcd535] text-sm mb-2">
                    <TestTube2 className="w-5 h-5" />
                    <span className="font-bold">Mock Copy Trading</span>
                  </div>
                  <p className="text-[#848e9c] text-xs">
                    These are simulated copy trading relationships. Practice risk-free with virtual funds.
                  </p>
                </div>
                {mockCopies.map((copy) => (
                  <div
                    key={copy.id}
                    className="relative bg-gradient-to-br from-[#2b3139]/80 to-[#252931]/80 backdrop-blur-xl rounded-xl p-4 sm:p-6 hover:from-[#353c47]/90 hover:to-[#2d323b]/90 transition-all duration-300 cursor-pointer border border-[#fcd535]/30 hover:border-[#fcd535]/60 group shadow-lg hover:shadow-2xl hover:shadow-[#fcd535]/10"
                    onClick={() => {
                      window.history.pushState({}, '', `?page=activecopying&id=${copy.id}`);
                      navigateTo('activecopying');
                    }}
                  >
                    <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-[#fcd535]/0 via-[#fcd535]/0 to-[#fcd535]/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                    <div className="absolute inset-0 rounded-xl bg-gradient-to-tr from-transparent via-white/0 to-white/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                    <div className="relative z-10">
                    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                      <div className="flex items-center gap-3 sm:gap-4 flex-1">
                        <div className="relative">
                          <div
                            className="text-3xl sm:text-4xl cursor-pointer transform transition-transform group-hover:scale-110"
                            onClick={(e) => {
                              e.stopPropagation();
                              window.history.pushState({}, '', `?page=traderprofile&id=${copy.trader_id}`);
                              navigateTo('traderprofile');
                            }}
                          >
                            {copy.trader?.avatar}
                          </div>
                          <div className="absolute -top-1 -right-1 bg-gradient-to-r from-[#fcd535] to-[#f0b90b] rounded-full p-1 ring-2 ring-[#2b3139]">
                            <TestTube2 className="w-2.5 h-2.5 text-[#0b0e11]" />
                          </div>
                          {copy.trader?.api_verified && (
                            <div className="absolute -bottom-1 -right-1 bg-blue-500 rounded-full p-0.5 ring-2 ring-[#2b3139]">
                              <svg className="w-2.5 h-2.5 text-white" fill="currentColor" viewBox="0 0 16 16">
                                <path d="M10.97 4.97a.75.75 0 0 1 1.07 1.05l-3.99 4.99a.75.75 0 0 1-1.08.02L4.324 8.384a.75.75 0 1 1 1.06-1.06l2.094 2.093 3.473-4.425a.267.267 0 0 1 .02-.022z"/>
                              </svg>
                            </div>
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-2">
                            <span
                              className="text-white text-base sm:text-lg font-bold cursor-pointer hover:text-[#fcd535] transition-colors truncate"
                              onClick={(e) => {
                                e.stopPropagation();
                                window.history.pushState({}, '', `?page=traderprofile&id=${copy.trader_id}`);
                                navigateTo('traderprofile');
                              }}
                            >
                              {copy.trader?.name}
                            </span>
                            <span className="bg-[#fcd535]/20 text-[#fcd535] text-[10px] px-2 py-0.5 rounded-full font-bold flex-shrink-0">
                              MOCK
                            </span>
                          </div>
                          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs sm:text-sm text-[#848e9c]">
                            <span className="font-medium">{parseFloat(copy.initial_balance).toFixed(2)} USDT</span>
                            <span className="text-[#5a6169]">•</span>
                            <span className="font-medium">{copy.leverage}x Leverage</span>
                            <span className="text-[#5a6169]">•</span>
                            <span className="hidden sm:inline">{new Date(copy.created_at).toLocaleDateString()}</span>
                          </div>
                        </div>
                        <div className="sm:hidden text-right bg-black/30 backdrop-blur-sm rounded-lg px-3 py-2 border border-[#3a4149]/30 shadow-inner">
                          <div className={`text-lg font-bold ${(copy.user_roi_30d || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                            {(copy.user_roi_30d || 0) >= 0 ? '+' : ''}{(copy.user_roi_30d || 0).toFixed(2)}%
                          </div>
                          <div className="text-[#848e9c] text-[10px] uppercase tracking-wider font-semibold">Your ROI</div>
                        </div>
                      </div>

                      <div className="flex items-center justify-between sm:justify-end gap-3">
                        <div className="hidden sm:block text-right bg-black/30 backdrop-blur-sm rounded-lg px-4 py-3 border border-[#3a4149]/30 shadow-inner">
                          <div className="text-[#848e9c] text-[10px] uppercase tracking-wider font-semibold mb-1">Your ROI</div>
                          <div className={`text-2xl font-bold ${(copy.user_roi_30d || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                            {(copy.user_roi_30d || 0) >= 0 ? '+' : ''}{(copy.user_roi_30d || 0).toFixed(2)}%
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              window.history.pushState({}, '', `?page=activecopying&id=${copy.id}`);
                              navigateTo('activecopying');
                            }}
                            className="bg-gradient-to-r from-[#fcd535] to-[#f0b90b] hover:from-[#f0b90b] hover:to-[#fcd535] text-[#0b0e11] px-4 sm:px-6 py-2.5 rounded-lg text-sm font-bold transition-all hover:shadow-lg hover:shadow-[#fcd535]/20"
                          >
                            View Details
                          </button>
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              if (confirm(`Stop mock copying ${copy.trader?.name}?`)) {
                                handleStopMockCopy(copy.id, copy.trader?.name || 'trader');
                              }
                            }}
                            className="bg-[#f6465d]/20 hover:bg-[#f6465d]/30 text-[#f6465d] px-4 py-2.5 rounded-lg text-sm font-bold transition-all border border-[#f6465d]/30"
                          >
                            Stop
                          </button>
                        </div>
                      </div>
                    </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
              {filteredTraders.map((trader) => (
                <div
                  key={trader.id}
                  className="relative bg-gradient-to-br from-[#2b3139]/80 to-[#252931]/80 backdrop-blur-xl rounded-xl p-5 hover:from-[#353c47]/90 hover:to-[#2d323b]/90 transition-all duration-300 cursor-pointer border border-[#3a4149]/50 hover:border-[#fcd535]/50 group shadow-lg hover:shadow-2xl hover:shadow-[#fcd535]/10"
                  onClick={() => {
                    window.history.pushState({}, '', `?page=traderprofile&id=${trader.id}`);
                    navigateTo('traderprofile');
                  }}
                >
                  <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-[#fcd535]/0 via-[#fcd535]/0 to-[#fcd535]/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                  <div className="absolute inset-0 rounded-xl bg-gradient-to-tr from-transparent via-white/0 to-white/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                  <div className="relative z-10">
                  <div className="flex items-start justify-between mb-5">
                    <div className="flex items-center gap-3">
                      <div className="relative">
                        <div className="text-4xl transform transition-transform group-hover:scale-110">{trader.avatar}</div>
                        {trader.api_verified && (
                          <div className="absolute -bottom-1 -right-1 bg-blue-500 rounded-full p-0.5 ring-2 ring-[#2b3139]">
                            <svg className="w-2.5 h-2.5 text-white" fill="currentColor" viewBox="0 0 16 16">
                              <path d="M10.97 4.97a.75.75 0 0 1 1.07 1.05l-3.99 4.99a.75.75 0 0 1-1.08.02L4.324 8.384a.75.75 0 1 1 1.06-1.06l2.094 2.093 3.473-4.425a.267.267 0 0 1 .02-.022z"/>
                            </svg>
                          </div>
                        )}
                      </div>
                      <div>
                        <div className="flex items-center gap-2 mb-1.5">
                          <span className="text-white text-base font-bold group-hover:text-[#fcd535] transition-colors">{trader.name}</span>
                        </div>
                        <div className="flex items-center gap-1.5 text-xs text-[#848e9c]">
                          <UsersIcon className="w-3.5 h-3.5" />
                          <span className="font-medium">{trader.followers_count}</span>
                          <span className="text-[#5a6169]">•</span>
                          <span>#{trader.rank}/{trader.total_rank}</span>
                        </div>
                      </div>
                    </div>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        toggleFavorite(trader.id);
                      }}
                      className="text-gray-500 hover:text-[#fcd535] transition-all hover:scale-110"
                    >
                      <Star
                        className={`w-5 h-5 ${
                          favorites.has(trader.id) ? 'fill-[#fcd535] text-[#fcd535]' : ''
                        }`}
                      />
                    </button>
                  </div>

                  <div className="mb-5 bg-black/30 backdrop-blur-sm rounded-lg p-4 border border-[#3a4149]/30 shadow-inner">
                    <div className="flex items-center justify-between mb-2">
                      <div className="text-[#848e9c] text-[11px] uppercase tracking-wider font-semibold">ROI ({timePeriod}d)</div>
                      <span className="text-[10px] text-[#848e9c]">{timePeriod}d</span>
                    </div>
                    {(() => {
                      const roi = timePeriod === '7' ? trader.roi_7d : timePeriod === '90' ? trader.roi_90d : trader.roi_30d;
                      const isPositive = roi >= 0;
                      return (
                        <div className={`text-3xl font-bold mb-1 ${isPositive ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                          {isPositive ? '+' : ''}{roi.toFixed(2)}%
                        </div>
                      );
                    })()}
                    {(() => {
                      const pnl = timePeriod === '7' ? trader.pnl_7d : timePeriod === '90' ? trader.pnl_90d : trader.pnl_30d;
                      const isPositive = pnl >= 0;
                      return (
                        <div className="flex items-center gap-2">
                          {isPositive ? (
                            <TrendingUp className="w-4 h-4 text-[#0ecb81]" />
                          ) : (
                            <TrendingDown className="w-4 h-4 text-[#f6465d]" />
                          )}
                          <span className={`text-sm font-medium ${isPositive ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                            {isPositive ? '+' : ''}{pnl.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USDT
                          </span>
                        </div>
                      );
                    })()}
                  </div>

                  <div className="grid grid-cols-3 gap-4 mb-5">
                    <div className="text-center">
                      <div className="text-[#848e9c] text-[10px] uppercase tracking-wider font-semibold mb-1.5">AUM</div>
                      <div className="text-[#eaecef] text-sm font-bold">{(trader.aum / 1000).toFixed(1)}K</div>
                    </div>
                    <div className="text-center border-x border-[#3a4149]/50">
                      <div className="text-[#848e9c] text-[10px] uppercase tracking-wider font-semibold mb-1.5">Drawdown</div>
                      <div className="text-[#eaecef] text-sm font-bold">{trader.mdd_30d.toFixed(2)}%</div>
                      <div className="text-[9px] text-[#5a6169]">30d</div>
                    </div>
                    <div className="text-center">
                      <div className="text-[#848e9c] text-[10px] uppercase tracking-wider font-semibold mb-1.5">Sharpe</div>
                      <div className="text-[#eaecef] text-sm font-bold">{trader.sharpe_ratio !== null ? trader.sharpe_ratio.toFixed(2) : '-'}</div>
                      <div className="text-[9px] text-[#5a6169]">30d</div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2.5">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedTrader(trader);
                        setShowMockCopyModal(true);
                      }}
                      className="flex-1 bg-[#2b3139] hover:bg-[#474d57] border border-[#474d57] hover:border-[#5a6169] text-[#eaecef] py-2.5 rounded-lg text-sm font-semibold transition-all hover:shadow-md"
                    >
                      Mock
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedTrader(trader);
                        setShowCopyModal(true);
                      }}
                      className="flex-1 bg-gradient-to-r from-[#fcd535] to-[#f0b90b] hover:from-[#f0b90b] hover:to-[#fcd535] text-[#0b0e11] py-2.5 rounded-lg text-sm font-bold transition-all hover:shadow-lg hover:shadow-[#fcd535]/20"
                    >
                      Copy
                    </button>
                  </div>
                  </div>
                </div>
              ))}
            </div>

            {filteredTraders.length === 0 && (
              <div className="text-center py-12 sm:py-20 px-4">
                <div className="text-gray-500 text-base sm:text-lg">
                  {activeTab === 'favorites' ? 'No favorites yet' : 'No traders found'}
                </div>
                {activeTab === 'favorites' && (
                  <p className="text-gray-600 text-xs sm:text-sm mt-2">
                    Star traders from the "All Portfolios" tab to add them to your favorites
                  </p>
                )}
              </div>
            )}
          </>
        )}
      </div>

      {selectedTrader && (
        <>
          <CopyTradingModal
            isOpen={showCopyModal}
            onClose={() => {
              setShowCopyModal(false);
              setSelectedTrader(null);
            }}
            traderId={selectedTrader.id}
            traderName={selectedTrader.name}
            isMock={false}
          />
          <CopyTradingModal
            isOpen={showMockCopyModal}
            onClose={() => {
              setShowMockCopyModal(false);
              setSelectedTrader(null);
            }}
            traderId={selectedTrader.id}
            traderName={selectedTrader.name}
            isMock={true}
          />
        </>
      )}

      {selectedTrade && (
        <TradeResponseModal
          isOpen={showResponseModal}
          onClose={() => {
            setShowResponseModal(false);
            setSelectedTrade(null);
          }}
          mode={responseMode}
          trade={selectedTrade}
          allocatedAmount={selectedTrade.allocated_amount}
          onConfirm={handleConfirmResponse}
        />
      )}

      {showAutoAcceptConfirmModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2329] rounded-2xl max-w-md w-full border border-[#f6465d]/50 shadow-2xl">
            <div className="flex items-center justify-between p-6 border-b border-[#2b3139]">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-[#f6465d]/20 rounded-xl flex items-center justify-center">
                  <AlertTriangle className="w-5 h-5 text-[#f6465d]" />
                </div>
                <h3 className="text-xl font-bold">Enable Auto-Accept</h3>
              </div>
              <button
                onClick={() => setShowAutoAcceptConfirmModal(false)}
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
                      By enabling auto-accept, <span className="text-[#f6465d] font-semibold">ALL trade signals</span> from traders you follow will be <span className="text-[#f6465d] font-semibold">automatically executed</span> using your funds for the next 24 hours.
                    </p>
                  </div>
                </div>
              </div>

              <div className="bg-[#0b0e11] rounded-xl p-4 space-y-3">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-[#848e9c]">Duration</span>
                  <span className="text-white font-semibold">24 hours</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-[#848e9c]">Applies to</span>
                  <span className="text-white font-semibold">All followed traders</span>
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

              <p className="text-xs text-[#848e9c] text-center">
                You understand that trades will be executed automatically and you accept the associated risks.
              </p>

              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setShowAutoAcceptConfirmModal(false)}
                  className="flex-1 px-6 py-3 border border-[#474d57] rounded-xl text-white font-semibold hover:bg-[#2b3139] transition-all"
                >
                  Cancel
                </button>
                <button
                  onClick={() => toggleAutoAccept(true)}
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

export default CopyTrading;
