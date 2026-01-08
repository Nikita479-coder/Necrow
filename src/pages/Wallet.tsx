import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { Wallet as WalletIcon, TrendingUp, TrendingDown, Eye, EyeOff, ArrowRight, Copy, History, ArrowLeftRight, ArrowDownToLine, CreditCard, Lock, Clock } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import CryptoIcon from '../components/CryptoIcon';
import { usePrices } from '../hooks/usePrices';
import { useNavigation } from '../App';
import WalletTransferModal from '../components/WalletTransferModal';
import SharkCardDisplay from '../components/SharkCardDisplay';
import { useToast } from '../hooks/useToast';

interface Asset {
  symbol: string;
  name: string;
  balance: number;
  value: number;
  currentPrice: number;
}

interface Position {
  position_id: string;
  symbol: string;
  side: string;
  size: number;
  entry_price: number;
  current_price: number;
  unrealized_pnl: number;
  leverage: number;
  margin: number;
}

interface Stake {
  id: string;
  coin: string;
  amount: number;
  apr_locked: number;
  earned_rewards: number;
  start_date: string;
  end_date: string | null;
  product_type: string;
  duration_days: number;
  pending_rewards: number;
}

interface Trade {
  order_id: string;
  symbol: string;
  side: string;
  size: number;
  entry_price: number;
  exit_price: number;
  realized_pnl: number;
  closed_at: string;
}

interface LockedBonus {
  id: string;
  original_amount: number;
  current_amount: number;
  realized_profits: number;
  bonus_type_name: string;
  status: string;
  expires_at: string;
  days_remaining: number;
  created_at: string;
}

interface RawWallet {
  currency: string;
  balance: number;
  locked_balance: number;
  wallet_type: string;
}

interface RawPosition {
  position_id: string;
  pair: string;
  side: string;
  quantity: number;
  entry_price: number;
  leverage: number;
  margin: number;
}

interface PendingDeposit {
  payment_id: string;
  pay_address: string;
  pay_amount?: number;
  pay_currency: string;
  status: string;
  actually_paid?: number;
  created_at: string;
}

function Wallet() {
  const { user } = useAuth();
  const { navigateTo } = useNavigation();
  const prices = usePrices();
  const { showToast } = useToast();
  const [showBalance, setShowBalance] = useState(true);
  const [selectedTab, setSelectedTab] = useState<'main' | 'assets' | 'copy' | 'futures' | 'card'>('main');

  const [rawWallets, setRawWallets] = useState<RawWallet[]>([]);
  const [rawPositions, setRawPositions] = useState<RawPosition[]>([]);
  const [rawFuturesWallet, setRawFuturesWallet] = useState<{ available: number; locked: number }>({ available: 0, locked: 0 });

  const [mainWalletAssets, setMainWalletAssets] = useState<Asset[]>([]);
  const [mainWalletTotal, setMainWalletTotal] = useState(0);

  const [assetsWalletAssets, setAssetsWalletAssets] = useState<Asset[]>([]);
  const [assetsWalletTotal, setAssetsWalletTotal] = useState(0);
  const [activeStakes, setActiveStakes] = useState<Stake[]>([]);
  const [totalStaked, setTotalStaked] = useState(0);
  const [totalRewards, setTotalRewards] = useState(0);

  const [copyTradingAssets, setCopyTradingAssets] = useState<Asset[]>([]);
  const [copyTradingTotal, setCopyTradingTotal] = useState(0);
  const [copyRelationshipsTotal, setCopyRelationshipsTotal] = useState(0);
  const [activeCopyCount, setActiveCopyCount] = useState(0);


  const [futuresPositions, setFuturesPositions] = useState<Position[]>([]);
  const [futuresMargin, setFuturesMargin] = useState(0);
  const [futuresPnL, setFuturesPnL] = useState(0);
  const [futuresWalletBalance, setFuturesWalletBalance] = useState(0);
  const [futuresAvailableBalance, setFuturesAvailableBalance] = useState(0);
  const [futuresLockedBalance, setFuturesLockedBalance] = useState(0);

  const [hasCard, setHasCard] = useState(false);
  const [cardData, setCardData] = useState<any>(null);
  const [cardWalletBalance, setCardWalletBalance] = useState(0);

  const [pastTrades, setPastTrades] = useState<Trade[]>([]);

  const [lockedBonuses, setLockedBonuses] = useState<LockedBonus[]>([]);
  const [lockedBonusTotal, setLockedBonusTotal] = useState(0);

  const [loading, setLoading] = useState(true);
  const [showTransferModal, setShowTransferModal] = useState(false);
  const [pendingDeposits, setPendingDeposits] = useState<PendingDeposit[]>([]);

  const getCryptoData = (symbol: string, balance: number) => {
    const cryptoNetworks: Record<string, { name: string; networks: string[]; fee: string; minWithdraw: string }> = {
      USDT: { name: 'Tether', networks: ['TRC20', 'ERC20', 'BEP20', 'Polygon', 'Solana'], fee: '1', minWithdraw: '10' },
      USDC: { name: 'USD Coin', networks: ['ERC20', 'TRC20', 'BEP20', 'Polygon', 'Solana'], fee: '1', minWithdraw: '10' },
      BTC: { name: 'Bitcoin', networks: ['Bitcoin', 'BEP20', 'ERC20'], fee: '0.0005', minWithdraw: '0.001' },
      ETH: { name: 'Ethereum', networks: ['Ethereum', 'BEP20', 'Arbitrum'], fee: '0.003', minWithdraw: '0.01' },
      BNB: { name: 'Binance Coin', networks: ['BEP20', 'BEP2'], fee: '0.0001', minWithdraw: '0.01' },
      SOL: { name: 'Solana', networks: ['Solana'], fee: '0.01', minWithdraw: '0.1' },
      XRP: { name: 'Ripple', networks: ['Ripple'], fee: '0.1', minWithdraw: '10' },
      ADA: { name: 'Cardano', networks: ['Cardano'], fee: '1', minWithdraw: '10' },
      DOT: { name: 'Polkadot', networks: ['Polkadot'], fee: '0.1', minWithdraw: '1' },
      MATIC: { name: 'Polygon', networks: ['Polygon', 'Ethereum'], fee: '0.1', minWithdraw: '1' },
      DOGE: { name: 'Dogecoin', networks: ['Dogecoin'], fee: '5', minWithdraw: '50' },
      LTC: { name: 'Litecoin', networks: ['Litecoin'], fee: '0.001', minWithdraw: '0.01' },
      LINK: { name: 'Chainlink', networks: ['Ethereum', 'BEP20'], fee: '0.1', minWithdraw: '1' },
      UNI: { name: 'Uniswap', networks: ['Ethereum', 'BEP20'], fee: '0.1', minWithdraw: '1' },
      AVAX: { name: 'Avalanche', networks: ['Avalanche', 'BEP20'], fee: '0.01', minWithdraw: '0.1' },
      ATOM: { name: 'Cosmos', networks: ['Cosmos'], fee: '0.01', minWithdraw: '0.1' },
      ARB: { name: 'Arbitrum', networks: ['Arbitrum'], fee: '0.0001', minWithdraw: '0.001' },
      OP: { name: 'Optimism', networks: ['Optimism'], fee: '0.0001', minWithdraw: '0.001' },
    };

    const data = cryptoNetworks[symbol] || {
      name: symbol,
      networks: ['ERC20'],
      fee: '0.001',
      minWithdraw: '0.01'
    };

    return {
      symbol,
      name: data.name,
      balance: balance.toString(),
      networks: data.networks,
      fee: data.fee,
      minWithdraw: data.minWithdraw
    };
  };

  useEffect(() => {
    if (user) {
      loadRawData();
      loadCardData();
      loadPastTrades();
      loadStakes();
      loadLockedBonuses();
      loadPendingDeposits();
      loadCopyRelationshipsTotal();
    }
  }, [user]);

  useEffect(() => {
    if (!user) return;

    const channel = supabase
      .channel('wallet_pending_deposits')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'crypto_deposits',
          filter: `user_id=eq.${user.id}`
        },
        () => {
          loadPendingDeposits();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user]);

  useEffect(() => {
    if (rawWallets.length > 0 || rawPositions.length > 0 || rawFuturesWallet.available > 0 || rawFuturesWallet.locked > 0) {
      calculateWalletValues();
      calculateFuturesValues();
    }
  }, [prices, rawWallets, rawPositions, rawFuturesWallet]);

  const getTokenPrice = (symbol: string): number => {
    let priceData = prices.get(symbol);
    if (!priceData) priceData = prices.get(`${symbol}/USDT`);
    if (!priceData) priceData = prices.get(`${symbol}USDT`);
    if (priceData) return priceData.price;
    if (['USDT', 'USDC', 'DAI'].includes(symbol)) return 1.0;
    return 0;
  };

  const getCoinName = (symbol: string): string => {
    const names: { [key: string]: string } = {
      'BTC': 'Bitcoin',
      'ETH': 'Ethereum',
      'BNB': 'BNB',
      'USDT': 'Tether',
      'SOL': 'Solana',
      'XRP': 'Ripple',
      'USDC': 'USD Coin',
      'ADA': 'Cardano',
      'DOGE': 'Dogecoin',
      'DOT': 'Polkadot',
      'MATIC': 'Polygon',
      'LTC': 'Litecoin'
    };
    return names[symbol] || symbol;
  };

  const loadRawData = async () => {
    if (!user) return;

    try {
      const [walletsResult, futuresWalletResult, positionsResult] = await Promise.all([
        supabase
          .from('wallets')
          .select('currency, balance, locked_balance, wallet_type')
          .eq('user_id', user.id),
        supabase
          .from('futures_margin_wallets')
          .select('available_balance, locked_balance')
          .eq('user_id', user.id)
          .maybeSingle(),
        supabase
          .from('futures_positions')
          .select('position_id, pair, side, quantity, entry_price, leverage, margin_allocated')
          .eq('user_id', user.id)
          .eq('status', 'open')
      ]);

      if (walletsResult.data) {
        setRawWallets(walletsResult.data.map(w => ({
          currency: w.currency,
          balance: parseFloat(w.balance),
          locked_balance: parseFloat(w.locked_balance),
          wallet_type: w.wallet_type
        })));
      }

      if (futuresWalletResult.data) {
        setRawFuturesWallet({
          available: parseFloat(futuresWalletResult.data.available_balance || '0'),
          locked: parseFloat(futuresWalletResult.data.locked_balance || '0')
        });
      }

      if (positionsResult.data) {
        setRawPositions(positionsResult.data
          .filter(pos => pos.pair && pos.entry_price && pos.quantity)
          .map(pos => ({
            position_id: pos.position_id,
            pair: pos.pair,
            side: pos.side,
            quantity: parseFloat(pos.quantity),
            entry_price: parseFloat(pos.entry_price),
            leverage: pos.leverage,
            margin: parseFloat(pos.margin_allocated)
          }))
        );
      }
    } catch (error) {
      console.error('Error loading raw data:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadPendingDeposits = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('crypto_deposits')
        .select('*')
        .eq('user_id', user.id)
        .in('status', ['waiting', 'confirming', 'confirmed', 'sending'])
        .order('created_at', { ascending: false });

      if (error) throw error;

      if (data) {
        setPendingDeposits(data);
      }
    } catch (error) {
      console.error('Error loading pending deposits:', error);
    }
  };

  const loadCopyRelationshipsTotal = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('copy_relationships')
        .select('current_balance')
        .eq('follower_id', user.id)
        .eq('is_active', true)
        .eq('is_mock', false);

      if (error) throw error;

      if (data && data.length > 0) {
        const total = data.reduce((sum, rel) => sum + parseFloat(rel.current_balance || '0'), 0);
        setCopyRelationshipsTotal(total);
        setActiveCopyCount(data.length);
      } else {
        setCopyRelationshipsTotal(0);
        setActiveCopyCount(0);
      }
    } catch (error) {
      console.error('Error loading copy relationships total:', error);
    }
  };

  const calculateWalletValues = () => {
    const mainAssets: Asset[] = [];
    const assetsAssets: Asset[] = [];
    const copyAssets: Asset[] = [];
    let cardBalance = 0;

    rawWallets.forEach(wallet => {
      const balance = wallet.balance;
      const lockedBalance = wallet.locked_balance;
      const availableBalance = balance - lockedBalance;

      if (balance <= 0 && lockedBalance <= 0) return;

      const currentPrice = getTokenPrice(wallet.currency);
      const totalValue = balance * currentPrice;

      const asset: Asset = {
        symbol: wallet.currency,
        name: getCoinName(wallet.currency),
        balance: availableBalance,
        value: totalValue,
        currentPrice
      };

      if (wallet.wallet_type === 'main' && availableBalance > 0) {
        mainAssets.push(asset);
      } else if (wallet.wallet_type === 'assets' && (balance > 0 || lockedBalance > 0)) {
        assetsAssets.push({
          ...asset,
          balance: balance
        });
      } else if (wallet.wallet_type === 'copy' && availableBalance > 0) {
        copyAssets.push(asset);
      } else if (wallet.wallet_type === 'card') {
        cardBalance = totalValue;
      }
    });

    setMainWalletAssets(mainAssets);
    setMainWalletTotal(mainAssets.reduce((sum, a) => sum + a.value, 0));

    setAssetsWalletAssets(assetsAssets);
    setAssetsWalletTotal(assetsAssets.reduce((sum, a) => sum + a.value, 0));

    setCopyTradingAssets(copyAssets);
    setCopyTradingTotal(copyAssets.reduce((sum, a) => sum + a.value, 0));

    setCardWalletBalance(cardBalance);
  };

  const calculateFuturesValues = () => {
    const positions: Position[] = rawPositions.map(pos => {
      const symbol = pos.pair.replace('USDT', '');
      const currentPrice = getTokenPrice(symbol);
      const priceDiff = pos.side === 'long'
        ? currentPrice - pos.entry_price
        : pos.entry_price - currentPrice;
      const unrealizedPnl = priceDiff * pos.quantity;

      return {
        position_id: pos.position_id,
        symbol: symbol,
        side: pos.side,
        size: pos.quantity,
        entry_price: pos.entry_price,
        current_price: currentPrice,
        unrealized_pnl: unrealizedPnl,
        leverage: pos.leverage,
        margin: pos.margin
      };
    });

    setFuturesPositions(positions);
    setFuturesMargin(positions.reduce((sum, p) => sum + p.margin, 0));
    setFuturesPnL(positions.reduce((sum, p) => sum + p.unrealized_pnl, 0));

    const total = rawFuturesWallet.available + rawFuturesWallet.locked;
    setFuturesAvailableBalance(rawFuturesWallet.available);
    setFuturesLockedBalance(rawFuturesWallet.locked);
    setFuturesWalletBalance(total);
  };

  const loadLockedBonuses = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase.rpc('get_user_locked_bonuses', {
        p_user_id: user.id
      });

      if (error) throw error;

      if (data) {
        setLockedBonuses(data);
        const activeTotal = data
          .filter((b: LockedBonus) => b.status === 'active')
          .reduce((sum: number, b: LockedBonus) => sum + b.current_amount, 0);
        setLockedBonusTotal(activeTotal);
      }
    } catch (error) {
      console.error('Error loading locked bonuses:', error);
    }
  };

  const loadPastTrades = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('futures_positions')
        .select('*')
        .eq('user_id', user.id)
        .in('status', ['closed', 'liquidated'])
        .order('closed_at', { ascending: false })
        .limit(20);

      if (error) throw error;

      if (data) {
        const trades: Trade[] = data
          .filter(pos => pos.pair && pos.entry_price && pos.quantity && pos.closed_at)
          .map(pos => {
            const symbol = pos.pair.replace('USDT', '');
            return {
              order_id: pos.position_id,
              symbol: symbol,
              side: pos.side,
              size: parseFloat(pos.quantity),
              entry_price: parseFloat(pos.entry_price),
              exit_price: parseFloat(pos.mark_price || 0),
              realized_pnl: parseFloat(pos.realized_pnl || 0),
              closed_at: pos.closed_at
            };
          });

        setPastTrades(trades);
      }
    } catch (error) {
      console.error('Error loading past trades:', error);
    }
  };

  const loadCardData = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase.rpc('get_user_shark_card', {
        p_user_id: user.id
      });

      if (error) {
        console.error('Error loading card:', error);
        return;
      }

      if (data && data.has_card) {
        setHasCard(true);
        setCardData(data.card);
        setCardWalletBalance(data.card.available_credit || 0);
      } else {
        setHasCard(false);
        setCardData(null);
      }
    } catch (error) {
      console.error('Error loading card data:', error);
    }
  };

  const loadStakes = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('user_stakes')
        .select(`
          *,
          product:earn_products(
            coin,
            product_type,
            duration_days
          )
        `)
        .eq('user_id', user.id)
        .eq('status', 'active');

      if (error) throw error;

      if (data) {
        const stakes: Stake[] = data.map(stake => {
          const timeElapsedSeconds = (Date.now() - new Date(stake.last_reward_date).getTime()) / 1000;
          const timeElapsedYears = timeElapsedSeconds / (365.25 * 24 * 60 * 60);
          const pendingRewards = parseFloat(stake.amount) * (parseFloat(stake.apr_locked) / 100) * timeElapsedYears;

          return {
            id: stake.id,
            coin: stake.product.coin,
            amount: parseFloat(stake.amount),
            apr_locked: parseFloat(stake.apr_locked),
            earned_rewards: parseFloat(stake.earned_rewards),
            start_date: stake.start_date,
            end_date: stake.end_date,
            product_type: stake.product.product_type,
            duration_days: stake.product.duration_days,
            pending_rewards: Math.max(pendingRewards, 0)
          };
        });

        setActiveStakes(stakes);

        const totalStakedValue = stakes.reduce((sum, stake) => {
          const price = getTokenPrice(stake.coin);
          return sum + (stake.amount * price);
        }, 0);

        const totalRewardsValue = stakes.reduce((sum, stake) => {
          const price = getTokenPrice(stake.coin);
          return sum + ((stake.earned_rewards + stake.pending_rewards) * price);
        }, 0);

        setTotalStaked(totalStakedValue);
        setTotalRewards(totalRewardsValue);
      }
    } catch (error) {
      console.error('Error loading stakes:', error);
    }
  };

  const formatTimeAgo = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffInSeconds < 60) return 'Just now';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`;
    if (diffInSeconds < 172800) return 'Yesterday';
    return `${Math.floor(diffInSeconds / 86400)}d ago`;
  };

  const earnWalletTotal = totalStaked + totalRewards + assetsWalletTotal;
  const copyWalletDisplayTotal = copyTradingTotal;
  const totalBalance = mainWalletTotal + earnWalletTotal + copyWalletDisplayTotal + futuresWalletBalance + (hasCard ? cardWalletBalance : 0);

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6 sm:mb-8">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold text-white mb-1 sm:mb-2 flex items-center gap-2 sm:gap-3">
                <WalletIcon className="w-7 h-7 sm:w-10 sm:h-10 text-[#f0b90b]" />
                My Wallets
              </h1>
              <p className="text-gray-400 text-sm sm:text-base">Manage your cryptocurrency across all wallets</p>
            </div>
            <div className="flex items-center gap-2 sm:gap-3">
              <button
                onClick={() => navigateTo('deposit')}
                className="flex items-center gap-1.5 sm:gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold px-4 py-2.5 sm:px-6 sm:py-3 rounded-xl transition-all text-sm sm:text-base"
              >
                <ArrowDownToLine className="w-4 h-4 sm:w-5 sm:h-5" />
                Deposit
              </button>
              <button
                onClick={() => setShowTransferModal(true)}
                className="flex items-center gap-1.5 sm:gap-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold px-4 py-2.5 sm:px-6 sm:py-3 rounded-xl transition-all text-sm sm:text-base"
              >
                <ArrowLeftRight className="w-4 h-4 sm:w-5 sm:h-5" />
                Transfer
              </button>
            </div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-[#f0b90b] to-[#f8d12f] rounded-xl sm:rounded-2xl p-4 sm:p-6 mb-6 sm:mb-8">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4">
            <div>
              <p className="text-black/70 text-xs sm:text-sm mb-1">Total Balance (All Wallets)</p>
              <div className="flex items-center gap-2 sm:gap-3">
                <h2 className="text-2xl sm:text-3xl lg:text-4xl font-bold text-black break-all">
                  {showBalance ? `$${totalBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : '••••••'}
                </h2>
                <button
                  onClick={() => setShowBalance(!showBalance)}
                  className="p-1.5 sm:p-2 hover:bg-black/10 rounded-lg transition-colors flex-shrink-0"
                >
                  {showBalance ? <Eye className="w-4 h-4 sm:w-5 sm:h-5 text-black" /> : <EyeOff className="w-4 h-4 sm:w-5 sm:h-5 text-black" />}
                </button>
              </div>
            </div>
            {futuresPnL !== 0 && (
              <div className="text-left sm:text-right">
                <p className="text-black/70 text-xs sm:text-sm mb-1">Futures Unrealized P&L</p>
                <div className="flex items-center gap-2">
                  {futuresPnL >= 0 ? (
                    <TrendingUp className="w-4 h-4 sm:w-5 sm:h-5 text-emerald-700" />
                  ) : (
                    <TrendingDown className="w-4 h-4 sm:w-5 sm:h-5 text-red-700" />
                  )}
                  <span className={`text-lg sm:text-xl lg:text-2xl font-bold ${futuresPnL >= 0 ? 'text-emerald-700' : 'text-red-700'}`}>
                    {futuresPnL >= 0 ? '+' : ''}${futuresPnL.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="mb-6 sm:mb-8 -mx-4 px-4 sm:mx-0 sm:px-0 overflow-x-auto scrollbar-hide">
          <div className={`flex sm:grid gap-3 sm:gap-4 min-w-max sm:min-w-0 ${hasCard ? 'sm:grid-cols-2 lg:grid-cols-5' : 'sm:grid-cols-2 lg:grid-cols-4'}`}>
            <button
              onClick={() => setSelectedTab('main')}
              className={`p-4 sm:p-5 rounded-xl border-2 transition-all flex-shrink-0 w-[160px] sm:w-auto text-left ${
                selectedTab === 'main'
                  ? 'bg-[#181a20] border-[#f0b90b]'
                  : 'bg-[#181a20] border-gray-800 hover:border-gray-700'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-400 text-xs sm:text-sm">Main Wallet</span>
                <WalletIcon className="w-4 h-4 sm:w-5 sm:h-5 text-blue-400" />
              </div>
              <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-1 truncate">
                ${mainWalletTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div className="text-xs sm:text-sm text-gray-400">{mainWalletAssets.length} assets</div>
            </button>

            <button
              onClick={() => setSelectedTab('assets')}
              className={`p-4 sm:p-5 rounded-xl border-2 transition-all flex-shrink-0 w-[160px] sm:w-auto text-left ${
                selectedTab === 'assets'
                  ? 'bg-[#181a20] border-[#f0b90b]'
                  : 'bg-[#181a20] border-gray-800 hover:border-gray-700'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-400 text-xs sm:text-sm">Earn Wallet</span>
                <TrendingUp className="w-4 h-4 sm:w-5 sm:h-5 text-emerald-400" />
              </div>
              <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-1 truncate">
                ${(totalStaked + totalRewards + assetsWalletTotal).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div className="text-xs sm:text-sm text-gray-400">{activeStakes.length} stakes</div>
            </button>

            <button
              onClick={() => setSelectedTab('copy')}
              className={`p-4 sm:p-5 rounded-xl border-2 transition-all flex-shrink-0 w-[160px] sm:w-auto text-left ${
                selectedTab === 'copy'
                  ? 'bg-[#181a20] border-[#f0b90b]'
                  : 'bg-[#181a20] border-gray-800 hover:border-gray-700'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-400 text-xs sm:text-sm">Copy Trading</span>
                <Copy className="w-4 h-4 sm:w-5 sm:h-5 text-purple-400" />
              </div>
              <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-1 truncate">
                ${copyWalletDisplayTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div className="text-xs sm:text-sm text-gray-400">{activeCopyCount > 0 ? `${activeCopyCount} active` : `${copyTradingAssets.length} assets`}</div>
            </button>

            <button
              onClick={() => setSelectedTab('futures')}
              className={`p-4 sm:p-5 rounded-xl border-2 transition-all flex-shrink-0 w-[160px] sm:w-auto text-left ${
                selectedTab === 'futures'
                  ? 'bg-[#181a20] border-[#f0b90b]'
                  : 'bg-[#181a20] border-gray-800 hover:border-gray-700'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-400 text-xs sm:text-sm">Futures Wallet</span>
                <TrendingUp className="w-4 h-4 sm:w-5 sm:h-5 text-orange-400" />
              </div>
              <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-1 truncate">
                ${futuresWalletBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div className="text-xs sm:text-sm text-gray-400">{futuresPositions.length} positions</div>
            </button>

            {hasCard && (
              <button
                onClick={() => setSelectedTab('card')}
                className={`p-4 sm:p-5 rounded-xl border-2 transition-all flex-shrink-0 w-[160px] sm:w-auto text-left ${
                  selectedTab === 'card'
                    ? 'bg-[#181a20] border-[#f0b90b]'
                    : 'bg-[#181a20] border-gray-800 hover:border-gray-700'
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <span className="text-gray-400 text-xs sm:text-sm">Shark Card</span>
                  <CreditCard className="w-4 h-4 sm:w-5 sm:h-5 text-[#f0b90b]" />
                </div>
                <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-1 truncate">
                  ${cardWalletBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
                <div className="text-xs sm:text-sm text-gray-400">Active</div>
              </button>
            )}
          </div>
        </div>

        <div className="bg-[#181a20] border border-gray-800 rounded-xl sm:rounded-2xl p-4 sm:p-6">
          {selectedTab === 'main' && (
            <div>
              <h3 className="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">Main Wallet Assets</h3>
              {loading ? (
                <div className="text-center py-8 text-gray-400">Loading...</div>
              ) : mainWalletAssets.length === 0 ? (
                <div className="text-center py-8 text-gray-400">No assets in main wallet</div>
              ) : (
                <div className="space-y-3">
                  {mainWalletAssets.map((asset) => (
                    <div key={asset.symbol} className="bg-[#0b0e11] border border-gray-800 rounded-xl p-3 sm:p-4 hover:border-[#f0b90b]/30 transition-all">
                      <div className="flex items-center justify-between mb-3 sm:mb-0">
                        <div className="flex items-center gap-3 sm:gap-4">
                          <CryptoIcon symbol={asset.symbol} size={36} className="sm:w-10 sm:h-10" />
                          <div>
                            <div className="font-bold text-white text-base sm:text-lg">{asset.symbol}</div>
                            <div className="text-gray-400 text-xs sm:text-sm">{asset.name}</div>
                          </div>
                        </div>
                        <div className="text-right sm:hidden">
                          <div className="text-white font-bold text-base">
                            ${asset.value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          </div>
                          <div className="text-gray-400 text-xs">
                            {asset.balance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {asset.symbol}
                          </div>
                        </div>
                      </div>
                      <div className="hidden sm:flex items-center justify-end gap-6 lg:gap-8">
                        <div>
                          <div className="text-gray-400 text-xs mb-1">Balance</div>
                          <div className="text-white font-semibold text-sm lg:text-base">
                            {asset.balance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 8 })} {asset.symbol}
                          </div>
                        </div>
                        <div>
                          <div className="text-gray-400 text-xs mb-1">Value</div>
                          <div className="text-white font-bold text-sm lg:text-base">
                            ${asset.value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          </div>
                        </div>
                        <div>
                          <div className="text-gray-400 text-xs mb-1">Price</div>
                          <div className="text-white font-semibold text-sm lg:text-base">
                            ${asset.currentPrice.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          </div>
                        </div>
                      </div>
                      <div className="sm:hidden grid grid-cols-2 gap-3 pt-2 border-t border-gray-800 mt-2">
                        <div>
                          <div className="text-gray-500 text-xs">Price</div>
                          <div className="text-white text-sm font-medium">
                            ${asset.currentPrice.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {selectedTab === 'assets' && (
            <div>
              {/* Pending Deposits */}
              {pendingDeposits.length > 0 && (
                <div className="mb-4 sm:mb-6 bg-[#181a20] border border-gray-800 rounded-xl p-4 sm:p-6">
                  <h3 className="text-base sm:text-lg font-bold text-white mb-3 sm:mb-4 flex items-center gap-2">
                    <Clock className="w-5 h-5 text-[#f0b90b]" />
                    Pending Deposits
                  </h3>
                  <div className="space-y-3">
                    {pendingDeposits.map((deposit) => (
                      <div key={deposit.payment_id} className="bg-[#0b0e11] border border-gray-700 rounded-xl p-3 sm:p-4">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <CryptoIcon symbol={deposit.pay_currency.toUpperCase()} size={32} />
                            <div>
                              <div className="text-white font-medium">{deposit.pay_currency.toUpperCase()}</div>
                              <div className="text-gray-400 text-xs sm:text-sm">
                                {deposit.status === 'waiting' && 'Waiting for payment'}
                                {deposit.status === 'confirming' && 'Confirming...'}
                                {deposit.status === 'confirmed' && 'Confirmed'}
                                {deposit.status === 'sending' && 'Processing...'}
                              </div>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className={`px-2 sm:px-3 py-1 rounded-full text-[10px] sm:text-xs font-medium ${
                              deposit.status === 'waiting' ? 'bg-yellow-500/20 text-yellow-400' :
                              'bg-blue-500/20 text-blue-400'
                            }`}>
                              {deposit.status.replace('_', ' ').toUpperCase()}
                            </div>
                            {deposit.actually_paid && (
                              <div className="text-green-400 text-xs sm:text-sm mt-1">{deposit.actually_paid} {deposit.pay_currency.toUpperCase()}</div>
                            )}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="mb-4 sm:mb-6">
                <h3 className="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">Earn Wallet Overview</h3>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 sm:gap-4">
                  <div className="bg-[#0b0e11] border border-gray-800 rounded-lg p-3 sm:p-4">
                    <div className="text-gray-400 text-xs sm:text-sm mb-1">Total Staked</div>
                    <div className="text-base sm:text-xl font-bold text-white">
                      ${totalStaked.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </div>
                  </div>
                  <div className="bg-[#0b0e11] border border-gray-800 rounded-lg p-3 sm:p-4">
                    <div className="text-gray-400 text-xs sm:text-sm mb-1">Total Rewards</div>
                    <div className="text-base sm:text-xl font-bold text-emerald-400">
                      ${totalRewards.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </div>
                  </div>
                  <div className="bg-[#0b0e11] border border-gray-800 rounded-lg p-3 sm:p-4 col-span-2 sm:col-span-1">
                    <div className="text-gray-400 text-xs sm:text-sm mb-1">Active Stakes</div>
                    <div className="text-base sm:text-xl font-bold text-[#f0b90b]">
                      {activeStakes.length}
                    </div>
                  </div>
                </div>
              </div>

              {activeStakes.length > 0 && (
                <div className="mb-4 sm:mb-6">
                  <h4 className="text-base sm:text-lg font-semibold text-white mb-3">Active Stakes</h4>
                  <div className="space-y-3">
                    {activeStakes.map((stake) => {
                      const currentPrice = getTokenPrice(stake.coin);
                      const totalValue = (stake.amount + stake.pending_rewards) * currentPrice;
                      const daysRemaining = stake.end_date
                        ? Math.ceil((new Date(stake.end_date).getTime() - Date.now()) / (1000 * 60 * 60 * 24))
                        : null;

                      return (
                        <div key={stake.id} className="bg-[#0b0e11] border border-gray-800 rounded-xl p-3 sm:p-4 hover:border-[#f0b90b]/30 transition-all">
                          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 sm:gap-0 mb-3">
                            <div className="flex items-center gap-3">
                              <CryptoIcon symbol={stake.coin} size={36} />
                              <div>
                                <div className="flex flex-wrap items-center gap-1 sm:gap-2">
                                  <span className="font-bold text-white text-base sm:text-lg">{stake.coin}</span>
                                  <span className="text-xs bg-emerald-500/20 text-emerald-400 px-2 py-0.5 rounded">
                                    {stake.apr_locked.toFixed(2)}% APR
                                  </span>
                                  <span className="text-xs bg-blue-500/20 text-blue-400 px-2 py-0.5 rounded">
                                    {stake.product_type === 'flexible' ? 'Flexible' : `${stake.duration_days}d`}
                                  </span>
                                </div>
                                <div className="text-xs sm:text-sm text-gray-400">
                                  {getCoinName(stake.coin)}
                                  {daysRemaining !== null && daysRemaining > 0 && (
                                    <span className="ml-2">- {daysRemaining}d left</span>
                                  )}
                                </div>
                              </div>
                            </div>
                            <div className="text-left sm:text-right ml-12 sm:ml-0">
                              <div className="text-white font-bold text-base sm:text-lg">
                                ${totalValue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                              </div>
                              <div className="text-xs text-gray-400">Total Value</div>
                            </div>
                          </div>
                          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
                            <div>
                              <div className="text-xs text-gray-400 mb-1">Staked</div>
                              <div className="text-xs sm:text-sm font-semibold text-white truncate">
                                {stake.amount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {stake.coin}
                              </div>
                            </div>
                            <div>
                              <div className="text-xs text-gray-400 mb-1">Pending</div>
                              <div className="text-xs sm:text-sm font-bold text-emerald-400 truncate">
                                {stake.pending_rewards.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {stake.coin}
                              </div>
                            </div>
                            <div>
                              <div className="text-xs text-gray-400 mb-1">Earned</div>
                              <div className="text-xs sm:text-sm font-bold text-emerald-400 truncate">
                                {stake.earned_rewards.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {stake.coin}
                              </div>
                            </div>
                            <div>
                              <div className="text-xs text-gray-400 mb-1">Started</div>
                              <div className="text-xs sm:text-sm text-white">
                                {formatTimeAgo(stake.start_date)}
                              </div>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              <div>
                <h4 className="text-base sm:text-lg font-semibold text-white mb-3">Available Balance</h4>
                {assetsWalletAssets.length === 0 ? (
                  <div className="text-center py-8 text-gray-400">No available balance in assets wallet</div>
                ) : (
                  <div className="space-y-3">
                    {assetsWalletAssets.map((asset) => (
                      <div key={asset.symbol} className="bg-[#0b0e11] border border-gray-800 rounded-xl p-3 sm:p-4 hover:border-gray-700 transition-all">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3 sm:gap-4">
                            <CryptoIcon symbol={asset.symbol} size={36} />
                            <div>
                              <div className="font-bold text-white text-base sm:text-lg">{asset.symbol}</div>
                              <div className="text-gray-400 text-xs sm:text-sm">{asset.name}</div>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="text-white font-bold text-sm sm:text-base">
                              ${asset.value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                            </div>
                            <div className="text-gray-400 text-xs sm:text-sm">
                              {asset.balance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {asset.symbol}
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {selectedTab === 'copy' && (
            <div>
              <h3 className="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">Copy Trading Wallet</h3>
              {activeCopyCount > 0 ? (
                <div className="space-y-4">
                  <div className="bg-[#0b0e11] border border-purple-500/30 rounded-xl p-4 sm:p-6">
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-4">
                      <div>
                        <div className="text-gray-400 text-sm mb-1">Total Balance</div>
                        <div className="text-2xl sm:text-3xl font-bold text-white">
                          ${copyTradingTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </div>
                      </div>
                      <div>
                        <div className="text-gray-400 text-sm mb-1">Allocated to Traders</div>
                        <div className="text-xl sm:text-2xl font-bold text-purple-400">
                          ${copyRelationshipsTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </div>
                      </div>
                      <div className="col-span-2 sm:col-span-1">
                        <div className="text-gray-400 text-sm mb-1">Available</div>
                        <div className="text-xl sm:text-2xl font-bold text-emerald-400">
                          ${Math.max(0, copyTradingTotal - copyRelationshipsTotal).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center justify-between text-sm text-gray-400 mb-4">
                      <span>Active Traders</span>
                      <span className="font-bold text-purple-400">{activeCopyCount}</span>
                    </div>
                    <div className="bg-purple-500/10 border border-purple-500/20 rounded-lg p-3">
                      <div className="flex items-start gap-2">
                        <Lock className="w-4 h-4 text-purple-400 mt-0.5 flex-shrink-0" />
                        <div>
                          <p className="text-sm text-purple-200">
                            Allocated funds cannot be transferred directly.
                          </p>
                          <p className="text-xs text-gray-400 mt-1">
                            To withdraw allocated funds, use "Withdraw & Stop" on the Copy Trading page.
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                  <button
                    onClick={() => navigateTo('active-copy-trading')}
                    className="w-full bg-purple-600 hover:bg-purple-500 text-white font-semibold py-3 rounded-xl transition-all flex items-center justify-center gap-2"
                  >
                    <Copy className="w-5 h-5" />
                    Manage Copy Trading
                  </button>
                </div>
              ) : copyTradingAssets.length > 0 ? (
                <div className="space-y-3">
                  {copyTradingAssets.map((asset) => (
                    <div key={asset.symbol} className="bg-[#0b0e11] border border-gray-800 rounded-xl p-3 sm:p-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3 sm:gap-4">
                          <CryptoIcon symbol={asset.symbol} size={36} />
                          <div>
                            <div className="font-bold text-white text-base sm:text-lg">{asset.symbol}</div>
                            <div className="text-gray-400 text-xs sm:text-sm">{asset.name}</div>
                          </div>
                        </div>
                        <div className="text-right">
                          <div className="text-white font-bold text-sm sm:text-base">
                            ${asset.value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          </div>
                          <div className="text-gray-400 text-xs sm:text-sm">
                            {asset.balance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {asset.symbol}
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-gray-400">No copy trading activity</div>
              )}
            </div>
          )}

          {selectedTab === 'futures' && (
            <div>
              <div className="mb-4 sm:mb-6">
                <h3 className="text-lg sm:text-xl font-bold text-white mb-3 sm:mb-4">Futures Margin Wallet</h3>
                <div className="grid grid-cols-2 gap-3 sm:gap-4">
                  <div className="bg-[#0b0e11] border border-gray-800 rounded-lg p-3 sm:p-4">
                    <div className="text-gray-400 text-xs sm:text-sm mb-1">Available Balance</div>
                    <div className="text-base sm:text-xl font-bold text-emerald-400">
                      ${futuresAvailableBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </div>
                  </div>
                  <div className="bg-[#0b0e11] border border-gray-800 rounded-lg p-3 sm:p-4">
                    <div className="text-gray-400 text-xs sm:text-sm mb-1">Locked in Positions</div>
                    <div className="text-base sm:text-xl font-bold text-orange-400">
                      ${futuresLockedBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </div>
                  </div>
                  <div className="bg-[#0b0e11] border border-gray-800 rounded-lg p-3 sm:p-4">
                    <div className="text-gray-400 text-xs sm:text-sm mb-1">Total Deposited</div>
                    <div className="text-base sm:text-xl font-bold text-white">
                      ${futuresWalletBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </div>
                  </div>
                  <div className="bg-[#0b0e11] border border-[#f0b90b]/30 rounded-lg p-3 sm:p-4">
                    <div className="text-gray-400 text-xs sm:text-sm mb-1 flex items-center gap-1">
                      <Lock className="w-3 h-3 text-[#f0b90b]" />
                      Locked Bonus
                    </div>
                    <div className="text-base sm:text-xl font-bold text-[#f0b90b]">
                      ${lockedBonusTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </div>
                    {lockedBonusTotal > 0 && (
                      <div className="text-xs text-gray-500 mt-1">For trading only</div>
                    )}
                  </div>
                </div>
              </div>

              {lockedBonuses.filter(b => b.status === 'active').length > 0 && (
                <div className="mb-4 sm:mb-6">
                  <h4 className="text-base sm:text-lg font-semibold text-white mb-3 flex items-center gap-2">
                    <Lock className="w-4 h-4 sm:w-5 sm:h-5 text-[#f0b90b]" />
                    Active Locked Bonuses
                    <span className="text-xs bg-[#f0b90b] text-black px-2 py-0.5 rounded">
                      {lockedBonuses.filter(b => b.status === 'active').length}
                    </span>
                  </h4>
                  <div className="space-y-3">
                    {lockedBonuses.filter(b => b.status === 'active').map((bonus) => (
                      <div
                        key={bonus.id}
                        className="bg-[#0b0e11] border border-[#f0b90b]/30 rounded-xl p-3 sm:p-4"
                      >
                        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 sm:gap-0 mb-3">
                          <div className="flex items-center gap-3">
                            <div className="w-9 h-9 sm:w-10 sm:h-10 bg-[#f0b90b]/10 rounded-full flex items-center justify-center flex-shrink-0">
                              <Lock className="w-4 h-4 sm:w-5 sm:h-5 text-[#f0b90b]" />
                            </div>
                            <div>
                              <div className="font-bold text-white text-sm sm:text-base">{bonus.bonus_type_name}</div>
                              <div className="text-xs text-gray-400">
                                Original: ${bonus.original_amount.toFixed(2)}
                              </div>
                            </div>
                          </div>
                          <div className="text-left sm:text-right ml-12 sm:ml-0">
                            <div className="flex items-center gap-1 text-yellow-400 text-xs sm:text-sm">
                              <Clock className="w-3 h-3 sm:w-4 sm:h-4" />
                              {bonus.days_remaining} days left
                            </div>
                          </div>
                        </div>
                        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-4">
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Current Balance</div>
                            <div className="text-sm sm:text-lg font-bold text-[#f0b90b]">
                              ${bonus.current_amount.toFixed(2)}
                            </div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Original</div>
                            <div className="text-sm sm:text-lg font-bold text-gray-300">
                              ${bonus.original_amount.toFixed(2)}
                            </div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Profits Earned</div>
                            <div className="text-sm sm:text-lg font-bold text-emerald-400">
                              +${(bonus.realized_profits || 0).toFixed(2)}
                            </div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Losses</div>
                            <div className="text-sm sm:text-lg font-bold text-red-400">
                              -${Math.max(0, bonus.original_amount + (bonus.realized_profits || 0) - bonus.current_amount).toFixed(2)}
                            </div>
                          </div>
                        </div>
                        <div className="grid grid-cols-2 gap-2 sm:gap-4 mt-2">
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Net P&L</div>
                            <div className={`text-sm sm:text-lg font-bold ${
                              (bonus.current_amount - bonus.original_amount) >= 0 ? 'text-emerald-400' : 'text-red-400'
                            }`}>
                              {(bonus.current_amount - bonus.original_amount) >= 0 ? '+' : ''}${(bonus.current_amount - bonus.original_amount).toFixed(2)}
                            </div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Expires</div>
                            <div className="text-xs sm:text-sm font-medium text-white">
                              {new Date(bonus.expires_at).toLocaleDateString()}
                            </div>
                          </div>
                        </div>
                        <div className="mt-3 p-2 bg-[#f0b90b]/5 rounded-lg border border-[#f0b90b]/10">
                          <p className="text-xs text-gray-400 mb-2">
                            This bonus can be used for futures trading. Profits are withdrawable, but the bonus balance cannot be withdrawn.
                          </p>
                          <button
                            onClick={() => navigateTo('bonusterms')}
                            className="text-xs text-[#f0b90b] hover:text-[#d9a506] underline transition-colors"
                          >
                            View unlock requirements & terms
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {futuresPositions.length > 0 && (
                <div className="mb-6 sm:mb-8">
                  <h4 className="text-base sm:text-lg font-semibold text-white mb-3 flex items-center gap-2">
                    Active Positions
                    <span className="text-xs bg-[#f0b90b] text-black px-2 py-0.5 rounded">
                      {futuresPositions.length}
                    </span>
                  </h4>
                  <div className="space-y-3">
                    {futuresPositions.map((position) => (
                      <button
                        key={position.position_id}
                        onClick={() => navigateTo('futures')}
                        className="w-full bg-[#0b0e11] border border-gray-800 rounded-xl p-3 sm:p-4 hover:border-[#f0b90b] transition-all text-left"
                      >
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-2 sm:gap-3">
                            <CryptoIcon symbol={position.symbol} size={28} />
                            <div>
                              <div className="flex flex-wrap items-center gap-1 sm:gap-2">
                                <span className="font-bold text-white text-sm sm:text-base">{position.symbol}/USDT</span>
                                <span className={`text-xs font-semibold px-1.5 py-0.5 rounded ${
                                  position.side === 'long' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'
                                }`}>
                                  {position.side.toUpperCase()} {position.leverage}x
                                </span>
                              </div>
                              <div className="text-xs sm:text-sm text-gray-400">
                                Size: {position.size.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })}
                              </div>
                            </div>
                          </div>
                          <ArrowRight className="w-4 h-4 sm:w-5 sm:h-5 text-gray-400" />
                        </div>
                        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-4">
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Entry</div>
                            <div className="text-xs sm:text-sm font-semibold text-white">
                              ${position.entry_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                            </div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Current</div>
                            <div className="text-xs sm:text-sm font-semibold text-white">
                              ${position.current_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                            </div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-400 mb-1">Margin</div>
                            <div className="text-xs sm:text-sm font-semibold text-white">
                              ${position.margin.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                            </div>
                          </div>
                          <div>
                            <div className="text-xs text-gray-400 mb-1">P&L</div>
                            <div className={`text-xs sm:text-sm font-bold ${
                              position.unrealized_pnl >= 0 ? 'text-emerald-400' : 'text-red-400'
                            }`}>
                              {position.unrealized_pnl >= 0 ? '+' : ''}${position.unrealized_pnl.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                            </div>
                          </div>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              <div>
                <h4 className="text-base sm:text-lg font-semibold text-white mb-3 flex items-center gap-2">
                  <History className="w-4 h-4 sm:w-5 sm:h-5 text-gray-400" />
                  Past Trades
                </h4>
                {pastTrades.length === 0 ? (
                  <div className="text-center py-8 text-gray-400">No past trades</div>
                ) : (
                  <div className="space-y-2">
                    {pastTrades.map((trade) => (
                      <div key={trade.order_id} className="bg-[#0b0e11] border border-gray-800 rounded-xl p-3 sm:p-4">
                        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                          <div className="flex items-center justify-between sm:justify-start gap-3">
                            <div className="flex items-center gap-2 sm:gap-3">
                              <CryptoIcon symbol={trade.symbol} size={24} />
                              <div>
                                <div className="flex items-center gap-1.5 sm:gap-2">
                                  <span className="font-semibold text-white text-sm sm:text-base">{trade.symbol}/USDT</span>
                                  <span className={`text-xs font-semibold px-1.5 py-0.5 rounded ${
                                    trade.side === 'long' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'
                                  }`}>
                                    {trade.side.toUpperCase()}
                                  </span>
                                </div>
                                <div className="text-xs text-gray-400">{formatTimeAgo(trade.closed_at)}</div>
                              </div>
                            </div>
                            <div className={`sm:hidden text-sm font-bold ${
                              trade.realized_pnl >= 0 ? 'text-emerald-400' : 'text-red-400'
                            }`}>
                              {trade.realized_pnl >= 0 ? '+' : ''}${trade.realized_pnl.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                            </div>
                          </div>
                          <div className="hidden sm:flex items-center gap-4 sm:gap-6">
                            <div className="text-right">
                              <div className="text-xs text-gray-400">Entry / Exit</div>
                              <div className="text-sm text-white">
                                ${trade.entry_price.toFixed(2)} / ${trade.exit_price.toFixed(2)}
                              </div>
                            </div>
                            <div className="text-right">
                              <div className="text-xs text-gray-400">Size</div>
                              <div className="text-sm text-white">{trade.size.toFixed(4)}</div>
                            </div>
                            <div className="text-right">
                              <div className="text-xs text-gray-400">Realized P&L</div>
                              <div className={`text-sm font-bold ${
                                trade.realized_pnl >= 0 ? 'text-emerald-400' : 'text-red-400'
                              }`}>
                                {trade.realized_pnl >= 0 ? '+' : ''}${trade.realized_pnl.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                              </div>
                            </div>
                          </div>
                          <div className="sm:hidden grid grid-cols-3 gap-2 pt-2 border-t border-gray-800">
                            <div>
                              <div className="text-xs text-gray-400">Entry</div>
                              <div className="text-xs text-white">${trade.entry_price.toFixed(2)}</div>
                            </div>
                            <div>
                              <div className="text-xs text-gray-400">Exit</div>
                              <div className="text-xs text-white">${trade.exit_price.toFixed(2)}</div>
                            </div>
                            <div>
                              <div className="text-xs text-gray-400">Size</div>
                              <div className="text-xs text-white">{trade.size.toFixed(4)}</div>
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {selectedTab === 'card' && (
            <div>
              <h3 className="text-lg sm:text-xl font-bold text-white mb-4 sm:mb-6">Shark Card</h3>
              {hasCard && cardData ? (
                <div className="max-w-4xl mx-auto">
                  <SharkCardDisplay
                    cardNumber={cardData.card_number}
                    cardholderName={cardData.cardholder_name}
                    expiryMonth={cardData.expiry_month}
                    expiryYear={cardData.expiry_year}
                    cvv={cardData.cvv}
                    cardType={cardData.card_type}
                    walletBalance={cardData.available_credit}
                    cardId={cardData.card_id}
                    onCopyNumber={() => showToast('Card number copied to clipboard', 'success')}
                  />
                </div>
              ) : (
                <div className="text-center py-8 sm:py-12">
                  <div className="w-16 h-16 sm:w-20 sm:h-20 bg-gray-800 rounded-full flex items-center justify-center mx-auto mb-3 sm:mb-4">
                    <CreditCard className="w-8 h-8 sm:w-10 sm:h-10 text-gray-600" />
                  </div>
                  <h4 className="text-lg sm:text-xl font-semibold text-white mb-2">No Shark Card Yet</h4>
                  <p className="text-gray-400 text-sm sm:text-base mb-4 sm:mb-6">Apply for a Shark Card to access exclusive benefits</p>
                  <button
                    onClick={() => navigateTo('vip-program')}
                    className="px-5 py-2.5 sm:px-6 sm:py-3 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black font-bold text-sm sm:text-base rounded-xl hover:from-[#f8d12f] hover:to-[#f0b90b] transition-all"
                  >
                    Learn More
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      <WalletTransferModal
        isOpen={showTransferModal}
        onClose={() => setShowTransferModal(false)}
        onSuccess={() => {
          loadRawData();
          loadStakes();
        }}
      />
    </div>
  );
}

export default Wallet;
