import { useState, useEffect } from 'react';
import {
  Home,
  Wallet,
  Gift,
  Users,
  Settings,
  Copy,
  Eye,
  EyeOff,
  ChevronDown,
  ChevronRight,
  Search,
  ArrowUpRight,
  ArrowDownRight,
  TrendingUp,
  Shield,
  CreditCard,
  Clock,
  CheckCircle,
  MessageCircle,
  Crown,
  Network,
  Menu,
  X
} from 'lucide-react';
import Navbar from '../components/Navbar';
import { useNavigation } from '../App';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import CryptoIcon from '../components/CryptoIcon';
import { usePrices } from '../hooks/usePrices';
import TransferModal from '../components/TransferModal';
import WithdrawModal from '../components/WithdrawModal';
import { useToast } from '../hooks/useToast';
import { ToastContainer } from '../components/Toast';
import UserSupportTickets from '../components/support/UserSupportTickets';
import SharkCardApplicationModal from '../components/SharkCardApplicationModal';
import SecuritySettings from '../components/SecuritySettings';
import SharkCardDisplay from '../components/SharkCardDisplay';
import TelegramLinkingSection from '../components/settings/TelegramLinkingSection';
import EmailNotificationSettings from '../components/settings/EmailNotificationSettings';

interface Transaction {
  id: string;
  transaction_type: string;
  currency: string;
  amount: string;
  status: string;
  created_at: string;
  address?: string;
  details?: string;
}

interface Asset {
  symbol: string;
  name: string;
  balance: number;
  mainWalletBalance: number;
  availableBalance: number;
  usdValue: number;
  price: number;
}

const ALL_TRADING_COINS = [
  { symbol: 'BTC', name: 'Bitcoin', category: 'Layer 1' },
  { symbol: 'ETH', name: 'Ethereum', category: 'Layer 1' },
  { symbol: 'BNB', name: 'BNB', category: 'Exchange' },
  { symbol: 'SOL', name: 'Solana', category: 'Layer 1' },
  { symbol: 'XRP', name: 'Ripple', category: 'Payment' },
  { symbol: 'ADA', name: 'Cardano', category: 'Layer 1' },
  { symbol: 'DOGE', name: 'Dogecoin', category: 'Meme' },
  { symbol: 'MATIC', name: 'Polygon', category: 'Layer 2' },
  { symbol: 'DOT', name: 'Polkadot', category: 'Layer 0' },
  { symbol: 'LTC', name: 'Litecoin', category: 'Payment' },
  { symbol: 'AVAX', name: 'Avalanche', category: 'Layer 1' },
  { symbol: 'LINK', name: 'Chainlink', category: 'Oracle' },
  { symbol: 'UNI', name: 'Uniswap', category: 'DeFi' },
  { symbol: 'ATOM', name: 'Cosmos', category: 'Layer 0' },
  { symbol: 'ALGO', name: 'Algorand', category: 'Layer 1' },
  { symbol: 'FTM', name: 'Fantom', category: 'Layer 1' },
  { symbol: 'NEAR', name: 'NEAR', category: 'Layer 1' },
  { symbol: 'APT', name: 'Aptos', category: 'Layer 1' },
  { symbol: 'ARB', name: 'Arbitrum', category: 'Layer 2' },
  { symbol: 'OP', name: 'Optimism', category: 'Layer 2' },
  { symbol: 'INJ', name: 'Injective', category: 'DeFi' },
  { symbol: 'SUI', name: 'Sui', category: 'Layer 1' },
  { symbol: 'TIA', name: 'Celestia', category: 'Modular' },
  { symbol: 'SEI', name: 'Sei', category: 'Layer 1' },
  { symbol: 'PEPE', name: 'Pepe', category: 'Meme' },
  { symbol: 'SHIB', name: 'Shiba Inu', category: 'Meme' },
  { symbol: 'TRX', name: 'Tron', category: 'Layer 1' },
  { symbol: 'TON', name: 'Toncoin', category: 'Layer 1' },
  { symbol: 'ICP', name: 'Internet Computer', category: 'Layer 1' },
  { symbol: 'VET', name: 'VeChain', category: 'Enterprise' },
  { symbol: 'FIL', name: 'Filecoin', category: 'Storage' },
  { symbol: 'HBAR', name: 'Hedera', category: 'Enterprise' },
  { symbol: 'STX', name: 'Stacks', category: 'Bitcoin L2' },
  { symbol: 'IMX', name: 'Immutable X', category: 'Gaming' },
  { symbol: 'RUNE', name: 'THORChain', category: 'DeFi' },
  { symbol: 'ETC', name: 'Ethereum Classic', category: 'Layer 1' },
  { symbol: 'BCH', name: 'Bitcoin Cash', category: 'Payment' },
  { symbol: 'XLM', name: 'Stellar', category: 'Payment' },
  { symbol: 'AAVE', name: 'Aave', category: 'DeFi' },
  { symbol: 'MKR', name: 'Maker', category: 'DeFi' },
  { symbol: 'CRV', name: 'Curve', category: 'DeFi' },
  { symbol: 'SUSHI', name: 'SushiSwap', category: 'DeFi' },
  { symbol: 'COMP', name: 'Compound', category: 'DeFi' },
  { symbol: 'SNX', name: 'Synthetix', category: 'DeFi' },
  { symbol: 'LDO', name: 'Lido DAO', category: 'DeFi' },
  { symbol: 'CAKE', name: 'PancakeSwap', category: 'DeFi' },
  { symbol: 'SAND', name: 'The Sandbox', category: 'Gaming' },
  { symbol: 'MANA', name: 'Decentraland', category: 'Gaming' },
  { symbol: 'AXS', name: 'Axie Infinity', category: 'Gaming' },
  { symbol: 'GALA', name: 'Gala', category: 'Gaming' },
  { symbol: 'ENJ', name: 'Enjin', category: 'Gaming' },
  { symbol: 'CHZ', name: 'Chiliz', category: 'Gaming' },
  { symbol: 'FET', name: 'Fetch.ai', category: 'AI' },
  { symbol: 'RENDER', name: 'Render', category: 'AI' },
  { symbol: 'AGIX', name: 'SingularityNET', category: 'AI' },
  { symbol: 'OCEAN', name: 'Ocean Protocol', category: 'AI' },
  { symbol: 'GRT', name: 'The Graph', category: 'AI' },
  { symbol: 'XTZ', name: 'Tezos', category: 'Layer 1' },
  { symbol: 'EOS', name: 'EOS', category: 'Layer 1' },
  { symbol: 'THETA', name: 'Theta', category: 'Media' },
  { symbol: 'FLOW', name: 'Flow', category: 'Layer 1' },
  { symbol: 'EGLD', name: 'MultiversX', category: 'Layer 1' },
  { symbol: 'KAVA', name: 'Kava', category: 'DeFi' },
  { symbol: 'ZIL', name: 'Zilliqa', category: 'Layer 1' },
  { symbol: 'MINA', name: 'Mina', category: 'Layer 1' },
  { symbol: 'ROSE', name: 'Oasis', category: 'Privacy' },
  { symbol: 'AR', name: 'Arweave', category: 'Storage' },
  { symbol: 'WIF', name: 'dogwifhat', category: 'Meme' },
  { symbol: 'BONK', name: 'Bonk', category: 'Meme' },
  { symbol: 'FLOKI', name: 'Floki', category: 'Meme' },
  { symbol: 'JUP', name: 'Jupiter', category: 'DeFi' },
  { symbol: 'RAY', name: 'Raydium', category: 'DeFi' },
  { symbol: 'APE', name: 'ApeCoin', category: 'Gaming' },
  { symbol: 'GMT', name: 'STEPN', category: 'Gaming' },
  { symbol: 'DYDX', name: 'dYdX', category: 'DeFi' },
  { symbol: 'USDT', name: 'Tether', category: 'Stablecoin' },
  { symbol: 'USDC', name: 'USD Coin', category: 'Stablecoin' },
  { symbol: 'DAI', name: 'Dai', category: 'Stablecoin' },
  { symbol: 'BUSD', name: 'Binance USD', category: 'Stablecoin' },
];

const COIN_CATEGORIES = ['All', 'Layer 1', 'Layer 2', 'DeFi', 'Gaming', 'Meme', 'AI', 'Payment', 'Stablecoin', 'Storage', 'Oracle', 'Exchange'];

function Profile() {
  const { user, profile, refreshProfile } = useAuth();
  const prices = usePrices();
  const [showBalance, setShowBalance] = useState(true);
  const [activeSection, setActiveSection] = useState('Dashboard');
  const [assetsExpanded, setAssetsExpanded] = useState(false);
  const [assetsSubSection, setAssetsSubSection] = useState('Overview');
  const [accountExpanded, setAccountExpanded] = useState(false);
  const [activeTab, setActiveTab] = useState('coin');
  const [hideSmallAssets, setHideSmallAssets] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [recentTransactions, setRecentTransactions] = useState<Transaction[]>([]);
  const [assets, setAssets] = useState<Asset[]>([]);
  const [totalBalance, setTotalBalance] = useState(0);
  const [selectedCurrency, setSelectedCurrency] = useState('BTC');
  const [showCurrencyDropdown, setShowCurrencyDropdown] = useState(false);
  const [loading, setLoading] = useState(true);
  const { navigateTo, navigationState } = useNavigation();
  const [accountSubSection, setAccountSubSection] = useState('Profile Settings');
  const [showTransferModal, setShowTransferModal] = useState(false);
  const [showWithdrawModal, setShowWithdrawModal] = useState(false);
  const [selectedWithdrawAsset, setSelectedWithdrawAsset] = useState<{
    symbol: string;
    name: string;
    balance: string;
    networks: string[];
    fee: string;
    minWithdraw: string;
  } | null>(null);
  const { toasts, removeToast, showSuccess } = useToast();

  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [profileFormData, setProfileFormData] = useState({
    username: '',
    avatar: '',
  });
  const [hasProfileChanges, setHasProfileChanges] = useState(false);

  const AVATAR_OPTIONS = [
    { id: 'smile', emoji: '😊', label: 'Smile' },
    { id: 'cool', emoji: '😎', label: 'Cool' },
    { id: 'rocket', emoji: '🚀', label: 'Rocket' },
    { id: 'fire', emoji: '🔥', label: 'Fire' },
    { id: 'star', emoji: '⭐', label: 'Star' },
    { id: 'diamond', emoji: '💎', label: 'Diamond' },
    { id: 'money', emoji: '💰', label: 'Money' },
    { id: 'chart', emoji: '📈', label: 'Chart' },
    { id: 'trophy', emoji: '🏆', label: 'Trophy' },
    { id: 'crown', emoji: '👑', label: 'Crown' },
    { id: 'lightning', emoji: '⚡', label: 'Lightning' },
    { id: 'target', emoji: '🎯', label: 'Target' },
  ];

  const getAvatarEmoji = (avatarId: string) => {
    const avatar = AVATAR_OPTIONS.find(a => a.id === avatarId);
    return avatar?.emoji || '😊';
  };

  const [vipTierName, setVipTierName] = useState('');
  const [sharkCardApplication, setSharkCardApplication] = useState<any>(null);
  const [sharkCard, setSharkCard] = useState<any>(null);
  const [showSharkCardModal, setShowSharkCardModal] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [showAllCoinsModal, setShowAllCoinsModal] = useState(false);
  const [coinSearchQuery, setCoinSearchQuery] = useState('');
  const [selectedCoinCategory, setSelectedCoinCategory] = useState('All');
  const [isExclusiveAffiliate, setIsExclusiveAffiliate] = useState(false);

  const availableCurrencies = ['BTC', 'ETH', 'USDT', 'BNB'];

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
      loadAssets();
    }
  }, [user, prices]);

  useEffect(() => {
    if (user) {
      loadRecentTransactions();
      loadVIPStatus();
      loadSharkCardData();

      const vipSubscription = supabase
        .channel('vip_status_updates')
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'user_vip_status',
          filter: `user_id=eq.${user.id}`
        }, () => {
          loadVIPStatus();
        })
        .subscribe();

      return () => {
        vipSubscription.unsubscribe();
      };
    }
  }, [user]);

  useEffect(() => {
    if (profile) {
      setProfileFormData({
        username: profile.username || '',
      });
    }
  }, [profile]);

  useEffect(() => {
    if (navigationState?.section === 'notifications') {
      setActiveSection('Account');
      setAccountExpanded(true);
      setAccountSubSection('Notifications');
    }
  }, [navigationState]);

  useEffect(() => {
    const checkExclusiveAffiliate = async () => {
      if (!user) return;
      try {
        const { data } = await supabase.rpc('get_exclusive_affiliate_stats', {
          p_user_id: user.id
        });
        setIsExclusiveAffiliate(data?.enrolled === true);
      } catch (error) {
        setIsExclusiveAffiliate(false);
      }
    };
    checkExclusiveAffiliate();
  }, [user]);

  const loadAssets = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('wallets')
        .select('*')
        .eq('user_id', user.id);

      if (error) throw error;

      if (data) {
        // Group balances by currency (total) and track main wallet balance separately
        const currencyTotals = new Map<string, number>();
        const mainWalletBalances = new Map<string, number>();
        const mainWalletLockedBalances = new Map<string, number>();

        data.forEach(wallet => {
          const balance = parseFloat(wallet.balance);
          const lockedBalance = parseFloat(wallet.locked_balance || '0');

          // Add to total
          const current = currencyTotals.get(wallet.currency) || 0;
          currencyTotals.set(wallet.currency, current + balance);

          // Track main wallet balance separately
          if (wallet.wallet_type === 'main') {
            mainWalletBalances.set(wallet.currency, balance);
            mainWalletLockedBalances.set(wallet.currency, lockedBalance);
          }
        });

        // Convert to formatted assets
        const formattedAssets = Array.from(currencyTotals.entries()).map(([currency, totalBalance]) => {
          const priceData = prices.get(currency);
          const currentPrice = priceData?.price || 1;
          const usdValue = totalBalance * currentPrice;
          const mainBalance = mainWalletBalances.get(currency) || 0;
          const mainLockedBalance = mainWalletLockedBalances.get(currency) || 0;

          // Calculate available balance: main balance - locked balance (pending withdrawals)
          // Note: Locked bonuses are stored separately and don't affect withdrawal availability
          const availableBalance = Math.max(mainBalance - mainLockedBalance, 0);

          return {
            symbol: currency,
            name: currency === 'BTC' ? 'Bitcoin' :
                  currency === 'ETH' ? 'Ethereum' :
                  currency === 'BNB' ? 'BNB' :
                  currency === 'USDT' ? 'TetherUS' :
                  currency === 'USDC' ? 'USDC' :
                  currency === 'SOL' ? 'Solana' :
                  currency === 'XRP' ? 'Ripple' :
                  currency === 'ADA' ? 'Cardano' :
                  currency === 'DOGE' ? 'Dogecoin' : currency,
            balance: totalBalance,
            mainWalletBalance: mainBalance,
            availableBalance: availableBalance,
            usdValue: usdValue,
            price: currentPrice
          };
        }).filter(asset => asset.balance > 0);

        const totalUSD = formattedAssets.reduce((sum, asset) => sum + asset.usdValue, 0);
        setAssets(formattedAssets);
        setTotalBalance(totalUSD);
      }
    } catch (error) {
      console.error('Error loading assets:', error);
    }
  };

  const loadRecentTransactions = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('transactions')
        .select('id, transaction_type, currency, amount, status, created_at, address, details')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(3);

      if (error) throw error;

      if (data) {
        setRecentTransactions(data);
      }
    } catch (error) {
      console.error('Error loading transactions:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadSharkCardData = async () => {
    if (!user) return;

    try {
      const { data: applicationData, error: appError } = await supabase
        .from('shark_card_applications')
        .select('*')
        .eq('user_id', user.id)
        .order('application_date', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (appError && !appError.message?.includes('Failed to fetch')) {
        console.error('Error loading application:', appError);
      }

      if (applicationData) {
        setSharkCardApplication(applicationData);
      }

      // Add delay before next query
      await new Promise(resolve => setTimeout(resolve, 200));

      const { data: cardData, error: cardError } = await supabase.rpc('get_user_shark_card', {
        p_user_id: user.id
      });

      if (cardError && !cardError.message?.includes('Failed to fetch')) {
        console.error('Error loading card:', cardError);
      }

      if (cardData && cardData.has_card) {
        setSharkCard(cardData.card);
      }
    } catch (error: any) {
      if (!error.message?.includes('Failed to fetch')) {
        console.error('Error loading shark card data:', error);
      }
    }
  };

  const loadVIPStatus = async () => {
    if (!user) return;

    try {
      const { data: vipStatus, error: vipError } = await supabase
        .from('user_vip_status')
        .select('current_level')
        .eq('user_id', user.id)
        .maybeSingle();

      if (vipError && vipError.code !== 'PGRST116' && !vipError.message?.includes('Failed to fetch')) {
        console.error('Error loading VIP status:', vipError);
      }

      const levelNumber = vipStatus?.current_level || 1;

      const { data: levelData, error: levelError } = await supabase
        .from('vip_levels')
        .select('level_name')
        .eq('level_number', levelNumber)
        .maybeSingle();

      if (levelError && !levelError.message?.includes('Failed to fetch')) {
        console.error('Error loading VIP level:', levelError);
        return;
      }

      if (levelData) {
        setVipTierName(levelData.level_name);
      } else {
        setVipTierName('Beginner');
      }
    } catch (error: any) {
      if (!error.message?.includes('Failed to fetch')) {
        console.error('Error loading VIP status:', error);
      }
    }
  };

  const formatTimeAgo = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffInSeconds < 60) return 'Just now';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)} minutes ago`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)} hours ago`;
    if (diffInSeconds < 172800) return 'Yesterday';
    return `${Math.floor(diffInSeconds / 86400)} days ago`;
  };

  const handleProfileInputChange = (field: string, value: string) => {
    setProfileFormData(prev => ({ ...prev, [field]: value }));
    setHasProfileChanges(true);
  };

  const handleProfileCancel = () => {
    if (profile) {
      setProfileFormData({
        username: profile.username || '',
        avatar: profile.avatar_url || 'smile',
      });
    }
    setIsEditingProfile(false);
    setHasProfileChanges(false);
  };

  const handleProfileSave = async () => {
    if (!user) return;

    setIsSavingProfile(true);
    try {
      const { error } = await supabase
        .from('user_profiles')
        .update({
          username: profileFormData.username || null,
          avatar_url: profileFormData.avatar || 'smile',
          updated_at: new Date().toISOString(),
        })
        .eq('id', user.id);

      if (error) throw error;

      await refreshProfile();
      await loadVIPStatus();
      setIsEditingProfile(false);
      setHasProfileChanges(false);
      alert('Profile updated successfully!');
    } catch (error) {
      console.error('Error updating profile:', error);
      alert('Failed to update profile. Please try again.');
    } finally {
      setIsSavingProfile(false);
    }
  };

  const filteredAssets = assets.filter(asset => {
    const matchesSearch = asset.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         asset.symbol.toLowerCase().includes(searchQuery.toLowerCase());
    const meetsMinValue = !hideSmallAssets || asset.usdValue >= 1;
    return matchesSearch && meetsMinValue;
  });

  const handleAssetsClick = () => {
    setActiveSection('Assets');
    setAssetsExpanded(!assetsExpanded);
    if (!assetsExpanded) {
      setAssetsSubSection('Overview');
    }
  };

  const handleAccountClick = () => {
    setActiveSection('Account');
    setAccountExpanded(!accountExpanded);
    if (!accountExpanded) {
      setAccountSubSection('Profile Settings');
    }
  };

  const renderAssetsOverview = () => (
    <div className="space-y-4 sm:space-y-6">
      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-4 sm:p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-4 sm:mb-6">
          <div className="flex items-center gap-2">
            <h3 className="text-lg sm:text-xl font-semibold">Estimated Balance</h3>
            <button
              onClick={() => setShowBalance(!showBalance)}
              className="text-gray-400 hover:text-gray-300 transition-colors"
            >
              {showBalance ? <Eye className="w-4 h-4 sm:w-5 sm:h-5" /> : <EyeOff className="w-4 h-4 sm:w-5 sm:h-5" />}
            </button>
          </div>
          <div className="flex gap-2 sm:gap-3 overflow-x-auto scrollbar-hide">
            <button
              onClick={() => navigateTo('deposit')}
              className="px-3 sm:px-4 py-2 bg-[#2b3139] hover:bg-[#3b4149] text-white rounded transition-colors text-xs sm:text-sm font-medium whitespace-nowrap flex-shrink-0"
            >
              Deposit
            </button>
            <button
              onClick={() => setShowTransferModal(true)}
              className="px-3 sm:px-4 py-2 bg-[#2b3139] hover:bg-[#3b4149] text-white rounded transition-colors text-xs sm:text-sm font-medium whitespace-nowrap flex-shrink-0"
            >
              Transfer
            </button>
            <button
              onClick={() => navigateTo('transactions')}
              className="px-3 sm:px-4 py-2 bg-[#2b3139] hover:bg-[#3b4149] text-white rounded transition-colors text-xs sm:text-sm font-medium whitespace-nowrap flex-shrink-0"
            >
              History
            </button>
          </div>
        </div>

        <div className="space-y-2">
          <div className="flex items-baseline gap-2">
            <span className="text-2xl sm:text-4xl font-semibold">
              {showBalance ? (() => {
                const selectedPriceData = prices.get(selectedCurrency);
                const selectedPrice = selectedPriceData?.price || 1;
                const balanceInSelectedCurrency = totalBalance / selectedPrice;
                return balanceInSelectedCurrency.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 8});
              })() : '****'}
            </span>
            <div className="relative">
              <button
                onClick={() => setShowCurrencyDropdown(!showCurrencyDropdown)}
                className="flex items-center gap-1 text-gray-400 hover:text-gray-300 transition-colors"
              >
                <span>{selectedCurrency}</span>
                <ChevronDown className="w-4 h-4" />
              </button>
              {showCurrencyDropdown && (
                <div className="absolute top-full right-0 mt-1 bg-[#181a20] border border-gray-700 rounded-lg shadow-lg z-10 min-w-[100px]">
                  {availableCurrencies.map((currency) => (
                    <button
                      key={currency}
                      onClick={() => {
                        setSelectedCurrency(currency);
                        setShowCurrencyDropdown(false);
                      }}
                      className={`w-full text-left px-4 py-2 hover:bg-[#2b3139] transition-colors first:rounded-t-lg last:rounded-b-lg ${
                        selectedCurrency === currency ? 'text-[#f0b90b]' : 'text-white'
                      }`}
                    >
                      {currency}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
          <div className="text-gray-400">
            ≈ ${showBalance ? totalBalance.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2}) : '****'}
          </div>
        </div>
      </div>

      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-4 sm:p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 sm:gap-0 mb-4 sm:mb-6">
          <h3 className="text-lg sm:text-xl font-semibold">My Assets</h3>
          <button
            onClick={() => setShowAllCoinsModal(true)}
            className="text-[#f0b90b] hover:text-[#f8d12f] text-xs sm:text-sm font-medium"
          >
            View All 350+ Coins
          </button>
        </div>

        <div className="flex flex-col gap-4 mb-4 sm:mb-6">
          <div className="flex gap-4 overflow-x-auto scrollbar-hide">
            <button
              onClick={() => setActiveTab('coin')}
              className={`pb-2 font-medium transition-all text-sm whitespace-nowrap ${
                activeTab === 'coin'
                  ? 'text-white border-b-2 border-[#f0b90b]'
                  : 'text-gray-400 hover:text-gray-300'
              }`}
            >
              Coin View
            </button>
            <button
              onClick={() => setActiveTab('account')}
              className={`pb-2 font-medium transition-all text-sm whitespace-nowrap ${
                activeTab === 'account'
                  ? 'text-white border-b-2 border-[#f0b90b]'
                  : 'text-gray-400 hover:text-gray-300'
              }`}
            >
              Account View
            </button>
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center gap-3 sm:gap-4">
            <div className="relative flex-1 sm:flex-none">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full sm:w-48 bg-[#0b0e11] border border-gray-700 rounded-lg pl-9 pr-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b] transition-colors"
              />
            </div>
            <label className="flex items-center gap-2 text-xs sm:text-sm text-gray-400 cursor-pointer whitespace-nowrap">
              <input
                type="checkbox"
                checked={hideSmallAssets}
                onChange={(e) => setHideSmallAssets(e.target.checked)}
                className="w-4 h-4 rounded border-gray-700 bg-[#0b0e11] text-[#f0b90b] focus:ring-[#f0b90b] focus:ring-offset-0"
              />
              Hide assets &lt;1 USD
            </label>
          </div>
        </div>

        <div className="hidden sm:block overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="text-left text-gray-400 text-sm border-b border-gray-800">
                <th className="pb-3 font-medium">Coin</th>
                <th className="pb-3 font-medium text-right">Amount</th>
                <th className="pb-3 font-medium text-right">Coin Price</th>
                <th className="pb-3 font-medium text-right">Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredAssets.map((asset) => (
                <tr key={asset.symbol} className="border-b border-gray-800 hover:bg-[#0b0e11]/50 transition-colors">
                  <td className="py-4">
                    <div className="flex items-center gap-3">
                      <CryptoIcon symbol={asset.symbol} size={32} />
                      <div>
                        <div className="font-semibold text-white">{asset.symbol}</div>
                        <div className="text-gray-400 text-sm">{asset.name}</div>
                      </div>
                    </div>
                  </td>
                  <td className="py-4 text-right">
                    <div className="font-semibold text-white">{asset.balance.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 8})}</div>
                    <div className="text-gray-400 text-sm">${asset.usdValue.toFixed(2)}</div>
                  </td>
                  <td className="py-4 text-right">
                    <div className="font-semibold text-white">${asset.price.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}</div>
                  </td>
                  <td className="py-4 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <button
                        onClick={() => navigateTo('deposit')}
                        className="text-emerald-500 hover:text-emerald-400 font-medium text-sm"
                      >
                        Deposit
                      </button>
                      <span className="text-gray-700">|</span>
                      <button
                        onClick={() => {
                          setSelectedWithdrawAsset(getCryptoData(asset.symbol, asset.availableBalance));
                          setShowWithdrawModal(true);
                        }}
                        className="text-blue-500 hover:text-blue-400 font-medium text-sm"
                      >
                        Withdraw
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="sm:hidden space-y-3">
          {filteredAssets.map((asset) => (
            <div key={asset.symbol} className="bg-[#0b0e11] rounded-lg p-4">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol={asset.symbol} size={28} />
                  <div>
                    <div className="font-semibold text-white text-sm">{asset.symbol}</div>
                    <div className="text-gray-400 text-xs">{asset.name}</div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-white text-sm">{asset.balance.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 4})}</div>
                  <div className="text-gray-400 text-xs">${asset.usdValue.toFixed(2)}</div>
                </div>
              </div>
              <div className="flex items-center justify-between pt-3 border-t border-gray-800">
                <div className="text-gray-400 text-xs">${asset.price.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}</div>
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => navigateTo('deposit')}
                    className="text-emerald-500 hover:text-emerald-400 font-medium text-xs"
                  >
                    Deposit
                  </button>
                  <button
                    onClick={() => {
                      setSelectedWithdrawAsset(getCryptoData(asset.symbol, asset.availableBalance));
                      setShowWithdrawModal(true);
                    }}
                    className="text-blue-500 hover:text-blue-400 font-medium text-xs"
                  >
                    Withdraw
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-4 sm:p-6">
        <div className="flex items-center justify-between mb-4 sm:mb-6">
          <h3 className="text-lg sm:text-xl font-semibold">Recent Transactions</h3>
          <button
            onClick={() => navigateTo('transactions')}
            className="text-[#f0b90b] hover:text-[#f8d12f] text-xs sm:text-sm font-medium"
          >
            More
          </button>
        </div>

        {loading ? (
          <div className="text-center py-8 text-gray-400 text-sm">Loading...</div>
        ) : recentTransactions.length === 0 ? (
          <div className="text-center py-8 text-gray-400 text-sm">No transactions yet</div>
        ) : (
          <div className="space-y-3">
            {recentTransactions.map((tx) => {
              const isPositive = tx.transaction_type === 'deposit' || tx.transaction_type === 'transfer' || tx.transaction_type === 'reward' || tx.transaction_type === 'fee_rebate' || tx.transaction_type === 'admin_credit';
              const amount = parseFloat(tx.amount);

              let displayType = '';
              if (tx.details) {
                displayType = tx.details;
              } else if (tx.transaction_type === 'fee_rebate') {
                displayType = 'Fee Rebate';
              } else if (tx.transaction_type === 'admin_credit') {
                displayType = 'Account Credit';
              } else if (tx.transaction_type === 'admin_debit') {
                displayType = 'Balance Adjustment';
              } else {
                displayType = tx.transaction_type.charAt(0).toUpperCase() + tx.transaction_type.slice(1);
              }

              return (
                <div key={tx.id} className="flex items-center justify-between p-3 sm:p-4 bg-[#0b0e11] rounded-lg gap-3">
                  <div className="flex items-center gap-3 sm:gap-4 min-w-0">
                    <div className={`w-8 h-8 sm:w-10 sm:h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
                      tx.transaction_type === 'deposit' || tx.transaction_type === 'reward' || tx.transaction_type === 'fee_rebate' || tx.transaction_type === 'admin_credit'
                        ? 'bg-emerald-500/20'
                        : tx.transaction_type === 'withdraw' || tx.transaction_type === 'admin_debit'
                        ? 'bg-red-500/20'
                        : 'bg-blue-500/20'
                    }`}>
                      {tx.transaction_type === 'deposit' || tx.transaction_type === 'reward' || tx.transaction_type === 'fee_rebate' || tx.transaction_type === 'admin_credit' ? (
                        <ArrowDownRight className="w-4 h-4 sm:w-5 sm:h-5 text-emerald-400" />
                      ) : tx.transaction_type === 'withdraw' || tx.transaction_type === 'admin_debit' ? (
                        <ArrowUpRight className="w-4 h-4 sm:w-5 sm:h-5 text-red-400" />
                      ) : (
                        <TrendingUp className="w-4 h-4 sm:w-5 sm:h-5 text-blue-400" />
                      )}
                    </div>
                    <div className="min-w-0">
                      <div className="font-semibold text-white text-sm truncate">{displayType}</div>
                      {tx.address && (
                        <div className="text-gray-400 text-xs max-w-[120px] sm:max-w-[200px] truncate">{tx.address}</div>
                      )}
                      <div className="text-gray-400 text-xs sm:text-sm">{formatTimeAgo(tx.created_at)}</div>
                    </div>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <div className={`font-bold text-sm sm:text-base ${
                      isPositive ? 'text-emerald-400' : 'text-red-400'
                    }`}>
                      {isPositive ? '+' : ''}{amount} {tx.currency}
                    </div>
                    <div className="text-gray-400 text-xs sm:text-sm capitalize">{tx.status}</div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );

  const fetchAssets = async () => {
    await loadAssets();
  };

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

  const renderMainWallet = () => (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold mb-6">Main Wallet</h2>
      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
        <h3 className="text-xl font-semibold mb-4">Assets</h3>
        <div className="space-y-3">
          {assets.length === 0 ? (
            <div className="text-center py-8 text-gray-400">No assets in main wallet</div>
          ) : (
            assets.map((asset) => (
              <div key={asset.symbol} className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4 hover:border-[#f0b90b]/30 transition-all">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <CryptoIcon symbol={asset.symbol} size={40} />
                    <div>
                      <div className="font-bold text-white text-lg">{asset.symbol}</div>
                      <div className="text-gray-400 text-sm">{asset.name}</div>
                    </div>
                  </div>
                  <div className="flex items-center gap-8">
                    <div>
                      <div className="text-gray-400 text-xs mb-1">Balance</div>
                      <div className="text-white font-semibold">
                        {asset.balance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 8 })} {asset.symbol}
                      </div>
                    </div>
                    <div>
                      <div className="text-gray-400 text-xs mb-1">Value</div>
                      <div className="text-white font-bold">
                        ${asset.usdValue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </div>
                    </div>
                    <div>
                      <div className="text-gray-400 text-xs mb-1">Price</div>
                      <div className="text-white font-semibold">
                        ${asset.price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );

  const renderAssetsWallet = () => (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold mb-6">Assets Wallet</h2>
      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
        <div className="text-center py-12 text-gray-400">
          <Wallet className="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p className="text-lg">No assets in assets wallet</p>
          <p className="text-sm mt-2">This wallet is for storing investment assets separately</p>
        </div>
      </div>
    </div>
  );

  const renderCopyTradingWallet = () => (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold mb-6">Copy Trading Wallet</h2>
      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
        <div className="text-center py-12 text-gray-400">
          <Copy className="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p className="text-lg">No assets in copy trading wallet</p>
          <p className="text-sm mt-2">Transfer funds here to start copy trading</p>
          <button
            onClick={() => navigateTo('copytrading')}
            className="mt-4 px-6 py-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold rounded transition-colors"
          >
            Browse Traders
          </button>
        </div>
      </div>
    </div>
  );

  const renderFuturesWallet = () => {
    const [futuresPositions, setFuturesPositions] = useState<any[]>([]);
    const [pastTrades, setPastTrades] = useState<any[]>([]);
    const [futuresMargin, setFuturesMargin] = useState(0);
    const [futuresWalletBalance, setFuturesWalletBalance] = useState(0);
    const [futuresAvailableBalance, setFuturesAvailableBalance] = useState(0);
    const [futuresLockedBalance, setFuturesLockedBalance] = useState(0);

    useEffect(() => {
      const loadFuturesData = async () => {
        if (!user) return;

        try {
          const { data: walletData, error: walletError } = await supabase
            .from('futures_margin_wallets')
            .select('available_balance, locked_balance')
            .eq('user_id', user.id)
            .maybeSingle();

          if (walletError) throw walletError;

          const { data, error } = await supabase
            .from('futures_positions')
            .select('*')
            .eq('user_id', user.id)
            .eq('status', 'open');

          if (error) throw error;

          let marginInUse = 0;
          if (data) {
            const positions = data
              .filter(pos => pos.pair && pos.entry_price && pos.quantity)
              .map(pos => {
                const symbol = pos.pair.replace('USDT', '');
                const currentPrice = getTokenPrice(symbol);
                const priceDiff = pos.side === 'long'
                  ? currentPrice - parseFloat(pos.entry_price)
                  : parseFloat(pos.entry_price) - currentPrice;
                const unrealizedPnl = priceDiff * parseFloat(pos.quantity);

                return {
                  position_id: pos.position_id,
                  symbol: symbol,
                  side: pos.side,
                  size: parseFloat(pos.quantity),
                  entry_price: parseFloat(pos.entry_price),
                  current_price: currentPrice,
                  unrealized_pnl: unrealizedPnl,
                  leverage: pos.leverage,
                  margin: parseFloat(pos.margin_allocated)
                };
              });

            setFuturesPositions(positions);
            marginInUse = positions.reduce((sum, p) => sum + p.margin, 0);
            setFuturesMargin(marginInUse);
          }

          if (walletData) {
            const available = parseFloat(walletData.available_balance || '0');
            const total = available + marginInUse;

            setFuturesAvailableBalance(available);
            setFuturesLockedBalance(marginInUse);
            setFuturesWalletBalance(total);
          }

          const { data: tradesData, error: tradesError } = await supabase
            .from('futures_positions')
            .select('*')
            .eq('user_id', user.id)
            .in('status', ['closed', 'liquidated'])
            .order('closed_at', { ascending: false })
            .limit(10);

          if (tradesError) throw tradesError;

          if (tradesData) {
            setPastTrades(tradesData
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
              }));
          }
        } catch (error) {
          console.error('Error loading futures data:', error);
        }
      };

      loadFuturesData();
    }, [user, prices]);

    return (
      <div className="space-y-6">
        <h2 className="text-2xl font-bold mb-6">Futures Wallet</h2>

        <div className="bg-[#181a20] border border-gray-800 rounded-lg p-4 sm:p-6">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <div className="text-gray-400 text-xs sm:text-sm mb-1">Total Balance</div>
              <div className="text-lg sm:text-xl font-bold text-white">
                ${futuresWalletBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USDT
              </div>
            </div>
            <div>
              <div className="text-gray-400 text-xs sm:text-sm mb-1">Available</div>
              <div className="text-lg sm:text-xl font-bold text-emerald-400">
                ${futuresAvailableBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USDT
              </div>
            </div>
            <div>
              <div className="text-gray-400 text-xs sm:text-sm mb-1">Margin in Use</div>
              <div className="text-lg sm:text-xl font-bold text-orange-400">
                ${futuresLockedBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USDT
              </div>
            </div>
          </div>
        </div>

        {futuresPositions.length > 0 && (
          <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
            <h3 className="text-xl font-semibold mb-4 flex items-center gap-2">
              Active Positions
              <span className="text-xs bg-[#f0b90b] text-black px-2 py-1 rounded">
                {futuresPositions.length}
              </span>
            </h3>
            <div className="space-y-3">
              {futuresPositions.map((position) => (
                <button
                  key={position.position_id}
                  onClick={() => navigateTo('futures')}
                  className="w-full bg-[#0b0e11] border border-gray-800 rounded-xl p-4 hover:border-[#f0b90b] transition-all text-left"
                >
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-3">
                      <CryptoIcon symbol={position.symbol} size={32} />
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-bold text-white">{position.symbol}/USDT</span>
                          <span className={`text-xs font-semibold px-2 py-0.5 rounded ${
                            position.side === 'long' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'
                          }`}>
                            {position.side.toUpperCase()} {position.leverage}x
                          </span>
                        </div>
                        <div className="text-sm text-gray-400">
                          Size: {position.size.toLocaleString(undefined, { minimumFractionDigits: 4, maximumFractionDigits: 4 })}
                        </div>
                      </div>
                    </div>
                    <ArrowUpRight className="w-5 h-5 text-gray-400" />
                  </div>
                  <div className="grid grid-cols-4 gap-4">
                    <div>
                      <div className="text-xs text-gray-400 mb-1">Entry Price</div>
                      <div className="text-sm font-semibold text-white">
                        ${position.entry_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-400 mb-1">Current Price</div>
                      <div className="text-sm font-semibold text-white">
                        ${position.current_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-400 mb-1">Margin</div>
                      <div className="text-sm font-semibold text-white">
                        ${position.margin.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-400 mb-1">Unrealized P&L</div>
                      <div className={`text-sm font-bold ${
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

        {pastTrades.length > 0 && (
          <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
            <h3 className="text-xl font-semibold mb-4">Past Trades</h3>
            <div className="space-y-2">
              {pastTrades.map((trade) => (
                <div key={trade.order_id} className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <CryptoIcon symbol={trade.symbol} size={28} />
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-semibold text-white">{trade.symbol}/USDT</span>
                          <span className={`text-xs font-semibold px-2 py-0.5 rounded ${
                            trade.side === 'long' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'
                          }`}>
                            {trade.side.toUpperCase()}
                          </span>
                        </div>
                        <div className="text-xs text-gray-400">{formatTimeAgo(trade.closed_at)}</div>
                      </div>
                    </div>
                    <div className="flex items-center gap-6">
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
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {futuresPositions.length === 0 && pastTrades.length === 0 && (
          <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
            <div className="text-center py-12 text-gray-400">
              <TrendingUp className="w-16 h-16 mx-auto mb-4 opacity-50" />
              <p className="text-lg">No futures positions or trades</p>
              <p className="text-sm mt-2">Start futures trading to see your positions here</p>
              <button
                onClick={() => navigateTo('futures')}
                className="mt-4 px-6 py-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold rounded transition-colors"
              >
                Start Trading
              </button>
            </div>
          </div>
        )}
      </div>
    );
  };

  const renderProfileSettings = () => (
      <div className="space-y-4 sm:space-y-6">
        <h2 className="text-xl sm:text-2xl font-bold mb-4 sm:mb-6">Profile</h2>

        <div className="bg-[#181a20] border border-gray-800 rounded-lg">
          <div className="p-4 sm:p-6 border-b border-gray-800">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <div className="flex items-center gap-3 sm:gap-4">
                <div className="w-12 h-12 bg-[#f0b90b] rounded-full flex items-center justify-center flex-shrink-0">
                  <span className="text-2xl">{getAvatarEmoji(profile?.avatar_url || 'smile')}</span>
                </div>
                <div className="min-w-0">
                  <h3 className="text-base sm:text-lg font-semibold">Nickname & Avatar</h3>
                  <p className="text-sm text-gray-400 mt-1 truncate">
                    {profile?.username || 'User-' + user?.id.slice(0, 5)}
                  </p>
                </div>
              </div>
              <button
                onClick={() => {
                  if (!isEditingProfile && profile) {
                    setProfileFormData({
                      username: profile.username || '',
                      avatar: profile.avatar_url || 'smile',
                    });
                  }
                  setIsEditingProfile(!isEditingProfile);
                }}
                className="px-4 sm:px-6 py-2 bg-[#2b3139] hover:bg-[#3b4149] text-white rounded transition-colors text-sm font-medium flex-shrink-0"
              >
                Edit
              </button>
            </div>

            {isEditingProfile && (
              <div className="mt-6 pt-6 border-t border-gray-800">
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-2">
                      Select Avatar
                    </label>
                    <div className="grid grid-cols-6 gap-2">
                      {AVATAR_OPTIONS.map(avatar => (
                        <button
                          key={avatar.id}
                          onClick={() => handleProfileInputChange('avatar', avatar.id)}
                          className={`w-full aspect-square rounded-lg flex items-center justify-center text-2xl transition-all ${
                            profileFormData.avatar === avatar.id
                              ? 'bg-[#f0b90b]/20 ring-2 ring-[#f0b90b]'
                              : 'bg-[#2b3139] hover:bg-[#3b4149]'
                          }`}
                          title={avatar.label}
                        >
                          {avatar.emoji}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-2">
                      Nickname
                    </label>
                    <input
                      type="text"
                      value={profileFormData.username}
                      onChange={(e) => handleProfileInputChange('username', e.target.value)}
                      placeholder="Enter nickname"
                      className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-2.5 text-white text-sm outline-none focus:border-[#f0b90b] transition-colors"
                    />
                    <p className="text-xs text-gray-500 mt-2">
                      Choose an avatar and nickname. Avoid using real names or social account names.
                    </p>
                  </div>
                  <div className="flex gap-3 justify-end">
                    <button
                      onClick={handleProfileCancel}
                      disabled={isSavingProfile}
                      className="px-6 py-2 bg-[#2b3139] hover:bg-[#3b4149] text-white rounded transition-colors disabled:opacity-50"
                    >
                      Cancel
                    </button>
                    <button
                      onClick={handleProfileSave}
                      disabled={isSavingProfile || !hasProfileChanges}
                      className="px-6 py-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold rounded transition-colors disabled:opacity-50"
                    >
                      {isSavingProfile ? 'Saving...' : 'Save'}
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="bg-[#181a20] border border-gray-800 rounded-lg p-4 sm:p-6">
          <h3 className="text-base sm:text-lg font-semibold mb-4">Account Information</h3>
          <div className="space-y-3">
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-3 border-b border-gray-800 gap-2">
              <span className="text-gray-400 text-sm">Email Address</span>
              <span className="text-white text-sm truncate">{user?.email || 'N/A'}</span>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-3 border-b border-gray-800 gap-2">
              <span className="text-gray-400 text-sm">User ID</span>
              <span className="text-white text-sm font-mono">{user?.id.slice(0, 8) || 'N/A'}</span>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-3 border-b border-gray-800 gap-2">
              <span className="text-gray-400 text-sm">Referral Code</span>
              <div className="flex items-center gap-2">
                <span className="text-white text-sm font-mono">{profile?.referral_code || 'N/A'}</span>
                <button
                  onClick={() => {
                    if (profile?.referral_code) {
                      navigator.clipboard.writeText(profile.referral_code);
                      alert('Referral code copied!');
                    }
                  }}
                  className="p-1.5 hover:bg-[#2b3139] rounded transition-colors"
                >
                  <Copy className="w-4 h-4 text-gray-400" />
                </button>
              </div>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-3 border-b border-gray-800 gap-2">
              <span className="text-gray-400 text-sm">KYC Status</span>
              <div className="flex items-center gap-2">
                <span className={`px-2.5 py-1 rounded text-xs font-medium ${
                  profile?.kyc_status === 'verified' ? 'bg-emerald-500/20 text-emerald-400' :
                  profile?.kyc_status === 'pending' ? 'bg-yellow-500/20 text-yellow-400' :
                  profile?.kyc_status === 'rejected' ? 'bg-red-500/20 text-red-400' :
                  'bg-gray-500/20 text-gray-400'
                }`}>
                  {profile?.kyc_status?.toUpperCase() || 'UNVERIFIED'}
                </span>
                {profile?.kyc_status !== 'verified' && (
                  <button
                    onClick={() => navigateTo('kyc')}
                    className="text-[#f0b90b] hover:text-[#f8d12f] text-xs sm:text-sm font-medium"
                  >
                    Verify
                  </button>
                )}
              </div>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-3 border-b border-gray-800 gap-2">
              <span className="text-gray-400 text-sm">Account Created</span>
              <span className="text-white text-sm">
                {profile?.created_at ? new Date(profile.created_at).toLocaleDateString() : 'N/A'}
              </span>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-3 gap-2">
              <span className="text-gray-400 text-sm">Last Updated</span>
              <span className="text-white text-sm">
                {profile?.updated_at ? new Date(profile.updated_at).toLocaleDateString() : 'N/A'}
              </span>
            </div>
          </div>
        </div>
      </div>
  );

  const renderDashboard = () => (
    <div className="space-y-5">
      <div className="bg-[#181a20] border border-gray-800 rounded-xl p-4 sm:p-6">
        <div className="flex items-center gap-3">
          <div className="w-14 h-14 sm:w-16 sm:h-16 bg-gradient-to-br from-[#f0b90b] to-[#d4a00a] rounded-full flex items-center justify-center flex-shrink-0 shadow-lg">
            <span className="text-2xl sm:text-3xl">{getAvatarEmoji(profile?.avatar_url || 'smile')}</span>
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2 mb-1">
              <h1 className="text-lg sm:text-xl font-bold truncate">{profile?.username || 'DemoTrader'}</h1>
            </div>
            <div className="flex items-center gap-2 text-xs mb-2">
              <span className="text-gray-500">ID:</span>
              <span className="text-gray-300 font-mono">11783922</span>
              <button className="p-1 hover:bg-[#2b3139] rounded transition-colors">
                <Copy className="w-3 h-3 text-gray-400" />
              </button>
            </div>
            <button
              onClick={() => navigateTo('vip')}
              className="inline-flex items-center gap-1.5 px-2.5 py-1 sm:px-3 sm:py-1.5 bg-[#2b3139] hover:bg-[#3b4149] rounded-lg text-xs font-medium text-gray-300 transition-colors"
            >
              <Crown className="w-3 h-3 sm:w-3.5 sm:h-3.5 text-[#f0b90b]" />
              {vipTierName || 'Loading...'}
              <ChevronRight className="w-3 h-3" />
            </button>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-lg sm:text-xl font-bold mb-4">Get Started</h2>
        <div className="space-y-3 sm:grid sm:grid-cols-2 lg:grid-cols-3 sm:gap-4 sm:space-y-0">
          {profile && (profile.kyc_status === 'verified' || ['basic', 'intermediate', 'advanced'].includes(profile.kyc_status)) ? (
            <div className="bg-[#181a20] border-2 border-[#0ecb81] rounded-xl p-4 sm:p-6">
              <div className="flex items-start justify-between mb-3">
                <div className="bg-[#0ecb81] text-white rounded-full w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center shadow-lg">
                  <CheckCircle className="w-5 h-5 sm:w-6 sm:h-6" />
                </div>
              </div>
              <h3 className="text-base sm:text-lg font-bold mb-2 text-[#0ecb81]">Verified</h3>
              <p className="text-gray-400 text-xs sm:text-sm mb-4 leading-relaxed">
                Identity verification completed successfully
              </p>
              <button
                onClick={() => navigateTo('deposit')}
                className="w-full bg-[#0ecb81]/20 hover:bg-[#0ecb81]/30 text-[#0ecb81] font-bold py-3 sm:py-3.5 rounded-lg transition-all transform active:scale-[0.98] text-sm sm:text-base border border-[#0ecb81]/30"
              >
                Completed
              </button>
            </div>
          ) : profile && profile.kyc_status === 'pending' ? (
            <div className="bg-[#181a20] border-2 border-yellow-500/50 rounded-xl p-4 sm:p-6">
              <div className="flex items-start justify-between mb-3">
                <div className="bg-yellow-500/20 text-yellow-400 rounded-full w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center shadow-lg">
                  <Clock className="w-5 h-5 sm:w-6 sm:h-6" />
                </div>
              </div>
              <h3 className="text-base sm:text-lg font-bold mb-2 text-yellow-400">Under Review</h3>
              <p className="text-gray-400 text-xs sm:text-sm mb-4 leading-relaxed">
                Your documents are being reviewed by our team
              </p>
              <button
                onClick={() => navigateTo('kyc')}
                className="w-full bg-yellow-500/20 hover:bg-yellow-500/30 text-yellow-400 font-bold py-3 sm:py-3.5 rounded-lg transition-all transform active:scale-[0.98] text-sm sm:text-base border border-yellow-500/30"
              >
                View Status
              </button>
            </div>
          ) : (
            <div className="bg-[#181a20] border-2 border-[#f0b90b] rounded-xl p-4 sm:p-6">
              <div className="flex items-start justify-between mb-3">
                <div className="bg-[#f0b90b] text-black rounded-full w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center text-base sm:text-lg font-bold shadow-lg">
                  1
                </div>
              </div>
              <h3 className="text-base sm:text-lg font-bold mb-2">Verify Account</h3>
              <p className="text-gray-400 text-xs sm:text-sm mb-4 leading-relaxed">
                Complete identity verification to access all services
              </p>
              <button
                onClick={() => navigateTo('kyc')}
                className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold py-3 sm:py-3.5 rounded-lg transition-all transform active:scale-[0.98] shadow-lg text-sm sm:text-base"
              >
                Verify Now
              </button>
            </div>
          )}

          <div className={`bg-[#181a20] rounded-xl p-4 sm:p-6 ${profile && (profile.kyc_level >= 1 || ['basic', 'intermediate', 'advanced'].includes(profile.kyc_status)) ? 'border-2 border-[#f0b90b]' : 'border border-gray-800'}`}>
            <div className="flex items-start justify-between mb-3">
              <div className={`rounded-full w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center text-base sm:text-lg font-semibold ${profile && (profile.kyc_level >= 1 || ['basic', 'intermediate', 'advanced'].includes(profile.kyc_status)) ? 'bg-[#f0b90b] text-black font-bold shadow-lg' : 'bg-[#2b3139] text-gray-400'}`}>
                2
              </div>
            </div>
            <h3 className="text-base sm:text-lg font-bold mb-2">Deposit</h3>
            <p className="text-gray-400 text-xs sm:text-sm mb-4 leading-relaxed">
              Add funds to your account
            </p>
            <button
              onClick={() => navigateTo('deposit')}
              className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold py-3 sm:py-3.5 rounded-lg transition-all transform active:scale-[0.98] shadow-lg text-sm sm:text-base"
            >
              Deposit Now
            </button>
          </div>

          <div className="bg-[#181a20] border border-gray-800 rounded-xl p-4 sm:p-6">
            <div className="flex items-start justify-between mb-3">
              <div className="bg-[#2b3139] rounded-full w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center text-base sm:text-lg font-semibold text-gray-400">
                3
              </div>
            </div>
            <h3 className="text-base sm:text-lg font-bold mb-2">Trade</h3>
            <p className="text-gray-400 text-xs sm:text-sm mb-4 leading-relaxed">
              Start trading cryptocurrencies
            </p>
            <button
              onClick={() => navigateTo('futures')}
              className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold py-3 sm:py-3.5 rounded-lg transition-all transform active:scale-[0.98] shadow-lg text-sm sm:text-base"
            >
              Start Trading
            </button>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-lg sm:text-xl font-bold mb-4">Shark Card</h2>
        {sharkCard ? (
          <div className="max-w-full lg:max-w-4xl">
            <SharkCardDisplay
              cardNumber={sharkCard.card_number}
              cardholderName={sharkCard.cardholder_name}
              expiryMonth={sharkCard.expiry_month}
              expiryYear={sharkCard.expiry_year}
              cvv={sharkCard.cvv}
              cardType={sharkCard.card_type}
              walletBalance={sharkCard.available_credit}
              cardId={sharkCard.card_id}
              onCopyNumber={() => showSuccess('Card number copied to clipboard')}
            />
          </div>
        ) : sharkCardApplication ? (
          <div className="bg-[#181a20] border border-gray-800 rounded-xl p-4 sm:p-6 lg:p-8">
            <div className="flex flex-col sm:flex-row items-start gap-4 sm:gap-6">
              <div className={`p-3 sm:p-4 rounded-xl flex-shrink-0 ${
                sharkCardApplication.status === 'pending' ? 'bg-yellow-500/20' :
                sharkCardApplication.status === 'approved' ? 'bg-green-500/20' :
                sharkCardApplication.status === 'declined' ? 'bg-red-500/20' :
                'bg-blue-500/20'
              }`}>
                {sharkCardApplication.status === 'pending' ? (
                  <Clock className="w-6 h-6 sm:w-8 sm:h-8 text-yellow-400" />
                ) : sharkCardApplication.status === 'approved' ? (
                  <CheckCircle className="w-6 h-6 sm:w-8 sm:h-8 text-green-400" />
                ) : (
                  <CreditCard className="w-6 h-6 sm:w-8 sm:h-8 text-blue-400" />
                )}
              </div>

              <div className="flex-1 min-w-0">
                <div className="flex flex-wrap items-center gap-2 sm:gap-3 mb-2">
                  <h3 className="text-lg sm:text-xl font-bold text-white">Shark Card Application</h3>
                  <span className={`px-2 sm:px-3 py-1 rounded-full text-xs font-medium border ${
                    sharkCardApplication.status === 'pending' ? 'bg-yellow-500/20 text-yellow-300 border-yellow-500/30' :
                    sharkCardApplication.status === 'approved' ? 'bg-green-500/20 text-green-300 border-green-500/30' :
                    sharkCardApplication.status === 'declined' ? 'bg-red-500/20 text-red-300 border-red-500/30' :
                    'bg-blue-500/20 text-blue-300 border-blue-500/30'
                  }`}>
                    {sharkCardApplication.status.toUpperCase()}
                  </span>
                </div>

                <div className="grid grid-cols-2 gap-3 sm:gap-4 mb-4">
                  <div>
                    <div className="text-gray-400 text-xs sm:text-sm">Requested Limit</div>
                    <div className="text-white font-semibold text-sm sm:text-base">${sharkCardApplication.requested_limit.toLocaleString()} USDT</div>
                  </div>
                  <div>
                    <div className="text-gray-400 text-xs sm:text-sm">Applied On</div>
                    <div className="text-white font-semibold text-sm sm:text-base">
                      {new Date(sharkCardApplication.application_date).toLocaleDateString()}
                    </div>
                  </div>
                </div>

                {sharkCardApplication.status === 'pending' && (
                  <p className="text-gray-400 text-xs sm:text-sm">
                    Your application is being reviewed. We will notify you once a decision has been made.
                  </p>
                )}

                {sharkCardApplication.status === 'approved' && (
                  <p className="text-green-400 text-xs sm:text-sm">
                    Congratulations! Your application has been approved. Your card will be issued shortly.
                  </p>
                )}

                {sharkCardApplication.status === 'declined' && (
                  <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-3 mt-3">
                    <div className="text-red-400 text-xs sm:text-sm font-medium mb-1">Application Declined</div>
                    <div className="text-gray-300 text-xs sm:text-sm">
                      {sharkCardApplication.rejection_reason || 'Please contact support for more information.'}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        ) : (
          <div className="bg-gradient-to-br from-amber-600/20 via-orange-600/20 to-amber-900/20 border border-amber-500/30 rounded-xl p-4 sm:p-6 lg:p-8">
            <div className="flex flex-col sm:flex-row items-start gap-4 sm:gap-6">
              <div className="bg-gradient-to-br from-amber-500 to-orange-600 p-3 sm:p-4 rounded-xl flex-shrink-0">
                <CreditCard className="w-6 h-6 sm:w-8 sm:h-8 text-white" />
              </div>

              <div className="flex-1">
                <h3 className="text-xl sm:text-2xl font-bold text-white mb-2">Apply for Shark Card</h3>
                <p className="text-slate-300 text-sm sm:text-base mb-4">
                  Get instant credit with up to 10% cashback on all crypto purchases. Zero annual fees for selected users.
                </p>

                <div className="flex items-center gap-4 sm:gap-6 mb-4 sm:mb-6">
                  <div>
                    <div className="text-lg sm:text-xl font-bold text-white">$50K</div>
                    <div className="text-slate-400 text-xs sm:text-sm">Max Credit</div>
                  </div>
                  <div className="w-px h-8 sm:h-10 bg-slate-600"></div>
                  <div>
                    <div className="text-lg sm:text-xl font-bold text-white">10%</div>
                    <div className="text-slate-400 text-xs sm:text-sm">Cashback</div>
                  </div>
                  <div className="w-px h-8 sm:h-10 bg-slate-600"></div>
                  <div>
                    <div className="text-lg sm:text-xl font-bold text-white">$0</div>
                    <div className="text-slate-400 text-xs sm:text-sm">Annual Fee</div>
                  </div>
                </div>

                <button
                  onClick={() => setShowSharkCardModal(true)}
                  className="px-5 sm:px-6 py-2.5 sm:py-3 bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-white font-bold rounded-xl transition-all hover:scale-105 hover:shadow-xl hover:shadow-amber-500/20 text-sm sm:text-base"
                >
                  Apply Now
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white overflow-x-hidden">
      <Navbar />

      <div className="lg:hidden sticky top-[60px] z-30 bg-[#181a20]/95 backdrop-blur-sm border-b border-gray-800 px-4 py-3 shadow-lg">
        <button
          onClick={() => setSidebarOpen(!sidebarOpen)}
          className="flex items-center gap-2 text-white hover:text-[#f0b90b] transition-colors font-medium"
        >
          <Menu className="w-5 h-5" />
          <span className="text-sm">Menu</span>
        </button>
      </div>

      {sidebarOpen && (
        <div
          className="lg:hidden fixed inset-0 bg-black/60 z-40 top-[105px]"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      <div className="flex">
        <aside className={`fixed lg:static top-[105px] lg:top-0 bottom-0 left-0 z-40 w-72 sm:w-80 lg:w-60 bg-[#181a20] border-r border-gray-800 transform transition-transform duration-300 ease-in-out overflow-y-auto shadow-2xl lg:shadow-none ${sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}`}>
          <nav className="py-6 lg:py-4">
            <button
              onClick={() => {
                setActiveSection('Dashboard');
                setAssetsExpanded(false);
                setAccountExpanded(false);
                setSidebarOpen(false);
              }}
              className={`w-full flex items-center gap-3 px-6 py-3 text-sm transition-colors ${
                activeSection === 'Dashboard'
                  ? 'bg-[#2b3139] text-white'
                  : 'text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300'
              }`}
            >
              <Home className="w-5 h-5" />
              <span>Dashboard</span>
            </button>

            {profile?.is_admin && (
              <button
                onClick={() => {
                  navigateTo('adminkyc');
                  setSidebarOpen(false);
                }}
                className="w-full flex items-center gap-3 px-6 py-3 text-sm text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300 transition-colors"
              >
                <Shield className="w-5 h-5" />
                <span>KYC Admin</span>
              </button>
            )}

            <button
              onClick={() => {
                setActiveSection('Assets');
                setAssetsExpanded(false);
                setAccountExpanded(false);
                setSidebarOpen(false);
              }}
              className={`w-full flex items-center gap-3 px-6 py-3 text-sm transition-colors ${
                activeSection === 'Assets'
                  ? 'bg-[#2b3139] text-white'
                  : 'text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300'
              }`}
            >
              <Wallet className="w-5 h-5" />
              <span>Assets</span>
            </button>

            <button
              onClick={() => {
                navigateTo('rewardshub');
                setSidebarOpen(false);
              }}
              className="w-full flex items-center gap-3 px-6 py-3 text-sm text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300 transition-colors"
            >
              <Gift className="w-5 h-5" />
              <span>Rewards Hub</span>
            </button>

            <button
              onClick={() => {
                navigateTo('referral');
                setSidebarOpen(false);
              }}
              className="w-full flex items-center gap-3 px-6 py-3 text-sm text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300 transition-colors"
            >
              <Users className="w-5 h-5" />
              <span>Referral</span>
            </button>

            {isExclusiveAffiliate && (
              <button
                onClick={() => {
                  navigateTo('affiliate');
                  setSidebarOpen(false);
                }}
                className="w-full flex items-center gap-3 px-6 py-3 text-sm text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300 transition-colors"
              >
                <Network className="w-5 h-5" />
                <span>Affiliate Program</span>
              </button>
            )}

            <button
              onClick={() => {
                navigateTo('vip');
                setSidebarOpen(false);
              }}
              className="w-full flex items-center gap-3 px-6 py-3 text-sm text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300 transition-colors"
            >
              <Crown className="w-5 h-5" />
              <span>VIP</span>
            </button>

            <button
              onClick={() => {
                setActiveSection('Support');
                setAssetsExpanded(false);
                setAccountExpanded(false);
                setSidebarOpen(false);
              }}
              className={`w-full flex items-center gap-3 px-6 py-3 text-sm transition-colors ${
                activeSection === 'Support'
                  ? 'bg-[#2b3139] text-white'
                  : 'text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300'
              }`}
            >
              <MessageCircle className="w-5 h-5" />
              <span>Support</span>
            </button>

            <div>
              <button
                onClick={handleAccountClick}
                className={`w-full flex items-center justify-between px-6 py-3 text-sm transition-colors ${
                  activeSection === 'Account'
                    ? 'bg-[#2b3139] text-white'
                    : 'text-gray-400 hover:bg-[#2b3139]/50 hover:text-gray-300'
                }`}
              >
                <div className="flex items-center gap-3">
                  <Settings className="w-5 h-5" />
                  <span>Account</span>
                </div>
                <ChevronDown className={`w-4 h-4 transition-transform ${accountExpanded ? 'rotate-180' : ''}`} />
              </button>
              {accountExpanded && (
                <div className="bg-[#0b0e11]">
                  {['Profile Settings', 'Security', 'Notifications'].map((item) => (
                    <button
                      key={item}
                      onClick={() => {
                        setAccountSubSection(item);
                        setSidebarOpen(false);
                      }}
                      className={`w-full px-14 py-2.5 text-sm text-left transition-colors ${
                        accountSubSection === item
                          ? 'bg-[#2b3139] text-white'
                          : 'text-gray-400 hover:text-gray-300'
                      }`}
                    >
                      {item}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </nav>
        </aside>

        <main className="flex-1 py-6 sm:p-6 lg:p-8 pb-24 lg:pb-8 w-full overflow-x-hidden">
          <div className="max-w-7xl mx-auto px-3 sm:px-0">
            {activeSection === 'Dashboard' && renderDashboard()}
            {activeSection === 'Assets' && renderAssetsOverview()}
            {activeSection === 'Support' && <UserSupportTickets />}
            {activeSection === 'Account' && accountSubSection === 'Profile Settings' && renderProfileSettings()}
            {activeSection === 'Account' && accountSubSection === 'Security' && <SecuritySettings />}
            {activeSection === 'Account' && accountSubSection === 'Notifications' && (
              <div className="space-y-8">
                <TelegramLinkingSection />
                <div className="border-t border-gray-800 pt-8">
                  <EmailNotificationSettings />
                </div>
              </div>
            )}
            {activeSection === 'Account' && accountSubSection !== 'Profile Settings' && accountSubSection !== 'Security' && accountSubSection !== 'Notifications' && (
              <div className="text-center py-12 sm:py-20">
                <div className="text-4xl sm:text-6xl mb-3 sm:mb-4">🚧</div>
                <h2 className="text-xl sm:text-2xl font-bold mb-2">{accountSubSection}</h2>
                <p className="text-gray-400 text-sm sm:text-base">This section is under construction</p>
              </div>
            )}
          </div>
        </main>
      </div>
      <ToastContainer toasts={toasts} removeToast={removeToast} />
      <TransferModal
        isOpen={showTransferModal}
        onClose={() => setShowTransferModal(false)}
        onSuccess={() => {
          fetchAssets();
          showSuccess('Transfer completed successfully');
        }}
      />

      {selectedWithdrawAsset && (
        <WithdrawModal
          isOpen={showWithdrawModal}
          onClose={() => {
            setShowWithdrawModal(false);
            setSelectedWithdrawAsset(null);
            fetchAssets();
          }}
          crypto={selectedWithdrawAsset}
        />
      )}

      <SharkCardApplicationModal
        isOpen={showSharkCardModal}
        onClose={() => {
          setShowSharkCardModal(false);
          loadSharkCardData();
        }}
      />

      {showAllCoinsModal && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2026] rounded-xl w-full max-w-2xl max-h-[80vh] overflow-hidden flex flex-col">
            <div className="p-4 sm:p-6 border-b border-gray-800">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg sm:text-xl font-bold">All Available Coins</h2>
                <button
                  onClick={() => {
                    setShowAllCoinsModal(false);
                    setCoinSearchQuery('');
                    setSelectedCoinCategory('All');
                  }}
                  className="p-2 hover:bg-[#2b3139] rounded-lg transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
              <div className="relative mb-4">
                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search coins..."
                  value={coinSearchQuery}
                  onChange={(e) => setCoinSearchQuery(e.target.value)}
                  className="w-full bg-[#2b3139] rounded-lg pl-10 pr-4 py-2.5 text-sm outline-none focus:ring-1 focus:ring-[#f0b90b]"
                />
              </div>
              <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-2">
                {COIN_CATEGORIES.map(category => (
                  <button
                    key={category}
                    onClick={() => setSelectedCoinCategory(category)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition-colors ${
                      selectedCoinCategory === category
                        ? 'bg-[#f0b90b] text-black'
                        : 'bg-[#2b3139] text-gray-300 hover:bg-[#3b4149]'
                    }`}
                  >
                    {category}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex-1 overflow-y-auto p-4 sm:p-6">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {ALL_TRADING_COINS
                  .filter(coin => {
                    const matchesSearch = coin.symbol.toLowerCase().includes(coinSearchQuery.toLowerCase()) ||
                                         coin.name.toLowerCase().includes(coinSearchQuery.toLowerCase());
                    const matchesCategory = selectedCoinCategory === 'All' || coin.category === selectedCoinCategory;
                    return matchesSearch && matchesCategory;
                  })
                  .map(coin => {
                    const priceData = prices.get(`${coin.symbol}/USDT`);
                    const price = priceData?.price || 0;
                    const change = priceData?.change24h || 0;
                    return (
                      <button
                        key={coin.symbol}
                        onClick={() => {
                          navigateTo('futures', { selectedPair: `${coin.symbol}USDT` });
                          setShowAllCoinsModal(false);
                        }}
                        className="flex items-center justify-between p-3 bg-[#2b3139] hover:bg-[#3b4149] rounded-lg transition-colors"
                      >
                        <div className="flex items-center gap-3">
                          <CryptoIcon symbol={coin.symbol} size={32} />
                          <div className="text-left">
                            <div className="font-medium">{coin.symbol}</div>
                            <div className="text-xs text-gray-400">{coin.name}</div>
                          </div>
                        </div>
                        <div className="text-right">
                          <div className="text-sm">${price > 0 ? price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: price < 1 ? 6 : 2 }) : '--'}</div>
                          <div className={`text-xs ${change >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                            {change >= 0 ? '+' : ''}{change.toFixed(2)}%
                          </div>
                        </div>
                      </button>
                    );
                  })}
              </div>
              {ALL_TRADING_COINS.filter(coin => {
                const matchesSearch = coin.symbol.toLowerCase().includes(coinSearchQuery.toLowerCase()) ||
                                     coin.name.toLowerCase().includes(coinSearchQuery.toLowerCase());
                const matchesCategory = selectedCoinCategory === 'All' || coin.category === selectedCoinCategory;
                return matchesSearch && matchesCategory;
              }).length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  No coins found matching your criteria
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default Profile;
