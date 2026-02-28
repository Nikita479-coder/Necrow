import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import CryptoIcon from '../components/CryptoIcon';
import { Toast } from '../components/Toast';
import { ArrowDownUp, ChevronDown, X, Search, History, CheckCircle2 } from 'lucide-react';
import { usePrices } from '../hooks/usePrices';
import { useToast } from '../hooks/useToast';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { supabase } from '../lib/supabase';

interface Token {
  symbol: string;
  name: string;
  balance: string;
  availableBalance: string;
}

const SUPPORTED_TOKENS: Token[] = [
  { symbol: 'BTC', name: 'Bitcoin', balance: '0', availableBalance: '0' },
  { symbol: 'ETH', name: 'Ethereum', balance: '0', availableBalance: '0' },
  { symbol: 'BNB', name: 'BNB', balance: '0', availableBalance: '0' },
  { symbol: 'USDT', name: 'Tether', balance: '0', availableBalance: '0' },
  { symbol: 'SOL', name: 'Solana', balance: '0', availableBalance: '0' },
  { symbol: 'XRP', name: 'Ripple', balance: '0', availableBalance: '0' },
  { symbol: 'USDC', name: 'USD Coin', balance: '0', availableBalance: '0' },
  { symbol: 'ADA', name: 'Cardano', balance: '0', availableBalance: '0' },
  { symbol: 'DOGE', name: 'Dogecoin', balance: '0', availableBalance: '0' },
  { symbol: 'DOT', name: 'Polkadot', balance: '0', availableBalance: '0' },
  { symbol: 'MATIC', name: 'Polygon', balance: '0', availableBalance: '0' },
  { symbol: 'LTC', name: 'Litecoin', balance: '0', availableBalance: '0' },
  { symbol: 'AVAX', name: 'Avalanche', balance: '0', availableBalance: '0' },
  { symbol: 'SHIB', name: 'Shiba Inu', balance: '0', availableBalance: '0' },
  { symbol: 'TRX', name: 'TRON', balance: '0', availableBalance: '0' },
  { symbol: 'ATOM', name: 'Cosmos', balance: '0', availableBalance: '0' },
  { symbol: 'UNI', name: 'Uniswap', balance: '0', availableBalance: '0' },
  { symbol: 'LINK', name: 'Chainlink', balance: '0', availableBalance: '0' },
  { symbol: 'ETC', name: 'Ethereum Classic', balance: '0', availableBalance: '0' },
  { symbol: 'BCH', name: 'Bitcoin Cash', balance: '0', availableBalance: '0' },
  { symbol: 'NEAR', name: 'NEAR Protocol', balance: '0', availableBalance: '0' },
  { symbol: 'APT', name: 'Aptos', balance: '0', availableBalance: '0' },
  { symbol: 'ARB', name: 'Arbitrum', balance: '0', availableBalance: '0' },
  { symbol: 'OP', name: 'Optimism', balance: '0', availableBalance: '0' },
  { symbol: 'FTM', name: 'Fantom', balance: '0', availableBalance: '0' },
  { symbol: 'ALGO', name: 'Algorand', balance: '0', availableBalance: '0' },
  { symbol: 'VET', name: 'VeChain', balance: '0', availableBalance: '0' },
  { symbol: 'ICP', name: 'Internet Computer', balance: '0', availableBalance: '0' },
  { symbol: 'FIL', name: 'Filecoin', balance: '0', availableBalance: '0' },
  { symbol: 'HBAR', name: 'Hedera', balance: '0', availableBalance: '0' },
  { symbol: 'AAVE', name: 'Aave', balance: '0', availableBalance: '0' },
  { symbol: 'MKR', name: 'Maker', balance: '0', availableBalance: '0' },
  { symbol: 'PEPE', name: 'Pepe', balance: '0', availableBalance: '0' },
  { symbol: 'WIF', name: 'dogwifhat', balance: '0', availableBalance: '0' },
  { symbol: 'BONK', name: 'Bonk', balance: '0', availableBalance: '0' },
  { symbol: 'FLOKI', name: 'Floki', balance: '0', availableBalance: '0' },
  { symbol: 'SAND', name: 'The Sandbox', balance: '0', availableBalance: '0' },
  { symbol: 'MANA', name: 'Decentraland', balance: '0', availableBalance: '0' },
  { symbol: 'AXS', name: 'Axie Infinity', balance: '0', availableBalance: '0' },
  { symbol: 'GALA', name: 'Gala', balance: '0', availableBalance: '0' },
  { symbol: 'ENJ', name: 'Enjin Coin', balance: '0', availableBalance: '0' },
  { symbol: 'FET', name: 'Fetch.ai', balance: '0', availableBalance: '0' },
  { symbol: 'RENDER', name: 'Render', balance: '0', availableBalance: '0' },
  { symbol: 'AGIX', name: 'SingularityNET', balance: '0', availableBalance: '0' },
  { symbol: 'OCEAN', name: 'Ocean Protocol', balance: '0', availableBalance: '0' },
  { symbol: 'GRT', name: 'The Graph', balance: '0', availableBalance: '0' },
  { symbol: 'XLM', name: 'Stellar', balance: '0', availableBalance: '0' },
  { symbol: 'XMR', name: 'Monero', balance: '0', availableBalance: '0' },
  { symbol: 'DASH', name: 'Dash', balance: '0', availableBalance: '0' },
  { symbol: 'ZEC', name: 'Zcash', balance: '0', availableBalance: '0' },
  { symbol: 'CAKE', name: 'PancakeSwap', balance: '0', availableBalance: '0' },
  { symbol: 'JUP', name: 'Jupiter', balance: '0', availableBalance: '0' },
  { symbol: 'RAY', name: 'Raydium', balance: '0', availableBalance: '0' },
  { symbol: 'ORCA', name: 'Orca', balance: '0', availableBalance: '0' },
  { symbol: 'IMX', name: 'Immutable X', balance: '0', availableBalance: '0' },
  { symbol: 'LRC', name: 'Loopring', balance: '0', availableBalance: '0' },
  { symbol: 'METIS', name: 'Metis', balance: '0', availableBalance: '0' },
  { symbol: 'INJ', name: 'Injective', balance: '0', availableBalance: '0' },
  { symbol: 'SEI', name: 'Sei', balance: '0', availableBalance: '0' },
  { symbol: 'SUI', name: 'Sui', balance: '0', availableBalance: '0' },
  { symbol: 'TIA', name: 'Celestia', balance: '0', availableBalance: '0' },
  { symbol: 'STRK', name: 'Starknet', balance: '0', availableBalance: '0' },
  { symbol: 'RUNE', name: 'THORChain', balance: '0', availableBalance: '0' },
  { symbol: 'KAVA', name: 'Kava', balance: '0', availableBalance: '0' },
  { symbol: 'OSMO', name: 'Osmosis', balance: '0', availableBalance: '0' },
  { symbol: 'JUNO', name: 'Juno', balance: '0', availableBalance: '0' },
  { symbol: 'STX', name: 'Stacks', balance: '0', availableBalance: '0' },
  { symbol: 'FLOW', name: 'Flow', balance: '0', availableBalance: '0' },
  { symbol: 'EGLD', name: 'MultiversX', balance: '0', availableBalance: '0' },
  { symbol: 'THETA', name: 'Theta Network', balance: '0', availableBalance: '0' },
  { symbol: 'CHZ', name: 'Chiliz', balance: '0', availableBalance: '0' },
  { symbol: 'MAGIC', name: 'Magic', balance: '0', availableBalance: '0' },
  { symbol: 'PRIME', name: 'Echelon Prime', balance: '0', availableBalance: '0' },
  { symbol: 'BLUR', name: 'Blur', balance: '0', availableBalance: '0' },
  { symbol: 'CRV', name: 'Curve DAO', balance: '0', availableBalance: '0' },
  { symbol: 'SUSHI', name: 'SushiSwap', balance: '0', availableBalance: '0' },
  { symbol: 'COMP', name: 'Compound', balance: '0', availableBalance: '0' },
  { symbol: 'YFI', name: 'yearn.finance', balance: '0', availableBalance: '0' },
  { symbol: 'SNX', name: 'Synthetix', balance: '0', availableBalance: '0' },
  { symbol: '1INCH', name: '1inch', balance: '0', availableBalance: '0' },
  { symbol: 'BAL', name: 'Balancer', balance: '0', availableBalance: '0' },
  { symbol: 'MINA', name: 'Mina Protocol', balance: '0', availableBalance: '0' },
  { symbol: 'ROSE', name: 'Oasis Network', balance: '0', availableBalance: '0' },
  { symbol: 'ZIL', name: 'Zilliqa', balance: '0', availableBalance: '0' },
  { symbol: 'ONE', name: 'Harmony', balance: '0', availableBalance: '0' },
  { symbol: 'WAVES', name: 'Waves', balance: '0', availableBalance: '0' },
  { symbol: 'KSM', name: 'Kusama', balance: '0', availableBalance: '0' },
  { symbol: 'ZRX', name: '0x Protocol', balance: '0', availableBalance: '0' },
  { symbol: 'BAT', name: 'Basic Attention', balance: '0', availableBalance: '0' },
  { symbol: 'ENS', name: 'Ethereum Name Service', balance: '0', availableBalance: '0' },
  { symbol: 'LDO', name: 'Lido DAO', balance: '0', availableBalance: '0' },
  { symbol: 'RPL', name: 'Rocket Pool', balance: '0', availableBalance: '0' },
  { symbol: 'APE', name: 'ApeCoin', balance: '0', availableBalance: '0' },
  { symbol: 'GMT', name: 'STEPN', balance: '0', availableBalance: '0' },
  { symbol: 'ILV', name: 'Illuvium', balance: '0', availableBalance: '0' },
  { symbol: 'XTZ', name: 'Tezos', balance: '0', availableBalance: '0' },
  { symbol: 'EOS', name: 'EOS', balance: '0', availableBalance: '0' },
  { symbol: 'IOTA', name: 'IOTA', balance: '0', availableBalance: '0' },
  { symbol: 'NEO', name: 'Neo', balance: '0', availableBalance: '0' },
  { symbol: 'QTUM', name: 'Qtum', balance: '0', availableBalance: '0' },
  { symbol: 'ICX', name: 'ICON', balance: '0', availableBalance: '0' },
  { symbol: 'ONT', name: 'Ontology', balance: '0', availableBalance: '0' },
  { symbol: 'ZEN', name: 'Horizen', balance: '0', availableBalance: '0' },
  { symbol: 'IOTX', name: 'IoTeX', balance: '0', availableBalance: '0' },
  { symbol: 'RVN', name: 'Ravencoin', balance: '0', availableBalance: '0' },
  { symbol: 'AR', name: 'Arweave', balance: '0', availableBalance: '0' },
  { symbol: 'ANKR', name: 'Ankr', balance: '0', availableBalance: '0' },
  { symbol: 'CELO', name: 'Celo', balance: '0', availableBalance: '0' },
  { symbol: 'SKL', name: 'SKALE', balance: '0', availableBalance: '0' },
  { symbol: 'MASK', name: 'Mask Network', balance: '0', availableBalance: '0' },
  { symbol: 'AUDIO', name: 'Audius', balance: '0', availableBalance: '0' },
];

function Swap() {
  const { user } = useAuth();
  const { navigateTo } = useNavigation();
  const prices = usePrices();
  const { toasts, removeToast, showSuccess, showError } = useToast();

  const [tokens, setTokens] = useState<Token[]>(SUPPORTED_TOKENS);
  const [fromToken, setFromToken] = useState('USDT');
  const [toToken, setToToken] = useState('BTC');
  const [fromAmount, setFromAmount] = useState('');
  const [showFromDropdown, setShowFromDropdown] = useState(false);
  const [showToDropdown, setShowToDropdown] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [lockedRate, setLockedRate] = useState<number | null>(null);
  const [lockedOutput, setLockedOutput] = useState<string | null>(null);
  const [countdown, setCountdown] = useState(15);
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [swapResult, setSwapResult] = useState<any>(null);

  useEffect(() => {
    if (user) {
      loadWalletBalances();
    }
  }, [user]);

  useEffect(() => {
    let timer: NodeJS.Timeout;
    if (showConfirmModal && countdown > 0) {
      timer = setTimeout(() => setCountdown(countdown - 1), 1000);
    } else if (countdown === 0) {
      setShowConfirmModal(false);
      setCountdown(15);
      showError('Price lock expired. Please try again.');
    }
    return () => clearTimeout(timer);
  }, [showConfirmModal, countdown]);

  const loadWalletBalances = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('wallets')
        .select('currency, balance, locked_balance')
        .eq('user_id', user.id)
        .eq('wallet_type', 'main');

      if (error) {
        console.error('Error loading balances:', error);
        return;
      }

      if (data) {
        setTokens(prevTokens =>
          prevTokens.map(token => {
            const wallet = data.find(w => w.currency === token.symbol);
            if (wallet) {
              const totalBalance = parseFloat(wallet.balance) || 0;
              const lockedBalance = parseFloat(wallet.locked_balance) || 0;
              const available = Math.max(0, totalBalance - lockedBalance);

              return {
                ...token,
                balance: totalBalance.toFixed(8),
                availableBalance: available.toFixed(8)
              };
            }
            return token;
          })
        );
      }
    } catch (error) {
      console.error('Failed to load wallet balances:', error);
    }
  };

  const getTokenPrice = (symbol: string): number => {
    const stablecoins = ['USDT', 'USDC', 'DAI', 'BUSD', 'TUSD', 'USDP', 'GUSD'];

    if (stablecoins.includes(symbol)) {
      return 1;
    }

    const priceData = prices.get(symbol);
    return priceData?.price || 0;
  };

  const calculateEstimatedOutput = () => {
    const amount = parseFloat(fromAmount);
    if (!amount || amount <= 0) return null;

    const fromPrice = getTokenPrice(fromToken);
    const toPrice = getTokenPrice(toToken);

    if (fromPrice === 0 || toPrice === 0) return null;

    const exchangeRate = fromPrice / toPrice;
    return (amount * exchangeRate).toFixed(8);
  };

  const getConversionRate = () => {
    const fromPrice = getTokenPrice(fromToken);
    const toPrice = getTokenPrice(toToken);

    if (fromPrice === 0 || toPrice === 0) return '0';

    const rate = fromPrice / toPrice;
    return rate.toFixed(8);
  };

  const swapTokens = () => {
    const temp = fromToken;
    setFromToken(toToken);
    setToToken(temp);
    setFromAmount('');
  };

  const handleInstantSwap = () => {
    if (!user) {
      showError('Please sign in to swap');
      return;
    }

    const amount = parseFloat(fromAmount);
    if (!fromAmount || amount <= 0) {
      showError('Please enter a valid amount');
      return;
    }

    const token = tokens.find(t => t.symbol === fromToken);
    if (token && amount > parseFloat(token.availableBalance)) {
      showError(`Insufficient ${fromToken} balance`);
      return;
    }

    const fromPrice = getTokenPrice(fromToken);
    const toPrice = getTokenPrice(toToken);
    const rate = fromPrice / toPrice;
    const output = (amount * rate).toFixed(8);

    setLockedRate(rate);
    setLockedOutput(output);
    setCountdown(15);
    setShowConfirmModal(true);
  };

  const executeSwap = async () => {
    if (!user) return;

    setIsProcessing(true);

    try {
      const amount = parseFloat(fromAmount);
      const { data, error } = await supabase.rpc('execute_instant_swap', {
        p_user_id: user.id,
        p_from_currency: fromToken,
        p_to_currency: toToken,
        p_from_amount: amount
      });

      if (error) throw error;

      if (data && data.success) {
        setSwapResult({
          fromAmount: fromAmount,
          fromCurrency: fromToken,
          toAmount: parseFloat(data.to_amount).toFixed(8),
          toCurrency: toToken,
          rate: parseFloat(data.execution_rate).toFixed(8),
          fee: parseFloat(data.fee_amount).toFixed(8)
        });
        setFromAmount('');
        setShowConfirmModal(false);
        setCountdown(15);
        setShowSuccessModal(true);
        await loadWalletBalances();
      } else {
        showError(data?.error || 'Failed to execute swap');
      }
    } catch (error: any) {
      console.error('Swap error:', error);
      showError(error.message || 'Failed to execute swap');
    } finally {
      setIsProcessing(false);
    }
  };

  const fromTokenData = tokens.find(t => t.symbol === fromToken);
  const toTokenData = tokens.find(t => t.symbol === toToken);
  const estimatedOutput = calculateEstimatedOutput();
  const hasAmount = fromAmount && parseFloat(fromAmount) > 0;
  const canExecute = hasAmount && !isProcessing;
  const filteredFromTokens = tokens.filter(t =>
    t.symbol !== toToken &&
    (t.symbol.toLowerCase().includes(searchQuery.toLowerCase()) ||
     t.name.toLowerCase().includes(searchQuery.toLowerCase()))
  );
  const filteredToTokens = tokens.filter(t =>
    t.symbol !== fromToken &&
    (t.symbol.toLowerCase().includes(searchQuery.toLowerCase()) ||
     t.name.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  return (
    <div className="min-h-screen bg-[#0c0d0f] text-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6">
        <div className="py-6 flex items-center justify-between">
          <h1 className="text-2xl font-semibold">Convert</h1>
          <button
            onClick={() => navigateTo('swaphistory')}
            className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors"
          >
            <History className="w-5 h-5" />
            <span className="text-sm font-medium">History</span>
          </button>
        </div>

        <div className="flex items-center justify-center min-h-[calc(100vh-200px)] py-12">
          <div className="max-w-[620px] w-full">
            <div className="bg-[#1e2329] rounded-2xl overflow-hidden">
              <div className="p-8">
              <div className="space-y-1">
                <div className="relative">
                  <div className="flex items-center justify-between mb-3">
                    <label className="text-sm text-gray-400">From</label>
                    <div className="text-sm text-gray-400">
                      Available Balance <span className="text-[#f0b90b]">{parseFloat(fromTokenData?.availableBalance || '0').toFixed(8)} {fromToken}</span>
                    </div>
                  </div>

                  <div className="bg-[#2b3139] rounded-xl p-5">
                    <div className="flex items-center justify-between">
                      <button
                        onClick={() => {
                          setShowFromDropdown(true);
                          setSearchQuery('');
                        }}
                        className="flex items-center gap-3 hover:opacity-80 transition-opacity"
                      >
                        <CryptoIcon symbol={fromToken} size={32} />
                        <span className="font-semibold text-xl text-white">{fromToken}</span>
                        <ChevronDown className="w-5 h-5 text-gray-400" />
                      </button>

                      <div className="flex items-center gap-3">
                        <input
                          type="text"
                          value={fromAmount}
                          onChange={(e) => {
                            const value = e.target.value;
                            if (value === '' || /^\d*\.?\d*$/.test(value)) {
                              setFromAmount(value);
                            }
                          }}
                          placeholder="0"
                          className="bg-transparent text-right text-3xl font-medium outline-none placeholder-gray-600 text-white w-full"
                        />
                        <button
                          onClick={() => {
                            const balance = fromTokenData?.availableBalance || '0';
                            setFromAmount(balance);
                          }}
                          className="px-3 py-1.5 bg-[#f0b90b] text-black text-sm font-medium rounded hover:bg-[#d9a502] transition-colors whitespace-nowrap"
                        >
                          Max
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex justify-center -my-2 relative z-10">
                  <button
                    onClick={swapTokens}
                    className="w-12 h-12 bg-[#2b3139] hover:bg-[#3b4149] rounded-full flex items-center justify-center border-4 border-[#1e2329] transition-colors"
                  >
                    <ArrowDownUp className="w-5 h-5 text-gray-400" />
                  </button>
                </div>

                <div className="relative">
                  <div className="flex items-center justify-between mb-3">
                    <label className="text-sm text-gray-400">To</label>
                    <div className="text-sm text-gray-400">
                      Available Balance <span className="text-[#f0b90b]">{parseFloat(toTokenData?.availableBalance || '0').toFixed(8)} {toToken}</span>
                    </div>
                  </div>

                  <div className="bg-[#2b3139] rounded-xl p-5">
                    <div className="flex items-center justify-between">
                      <button
                        onClick={() => {
                          setShowToDropdown(true);
                          setSearchQuery('');
                        }}
                        className="flex items-center gap-3 hover:opacity-80 transition-opacity"
                      >
                        <CryptoIcon symbol={toToken} size={32} />
                        <span className="font-semibold text-xl text-white">{toToken}</span>
                        <ChevronDown className="w-5 h-5 text-gray-400" />
                      </button>

                      <div className="text-3xl font-medium text-white">
                        {estimatedOutput || '0'}
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {hasAmount && (
                <div className="mt-6 p-4 bg-[#2b3139] rounded-xl">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">Conversion Rate</span>
                    <span className="text-white font-medium">
                      1 {fromToken} = {getConversionRate()} {toToken}
                    </span>
                  </div>
                </div>
              )}

              <button
                onClick={handleInstantSwap}
                disabled={isProcessing || !canExecute}
                className="w-full mt-8 py-4 bg-[#76613c] hover:bg-[#8b7347] text-black font-semibold rounded-xl text-base transition-all disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:bg-[#76613c]"
              >
                {!hasAmount ? 'Enter an amount' : isProcessing ? 'Processing...' : 'Preview Conversion'}
              </button>
            </div>
          </div>

          <div className="mt-12">
            <h3 className="text-base font-semibold text-white mb-2">Convert {fromToken} to other currencies</h3>
            <p className="text-sm text-gray-400 mb-6">Swap your {fromToken} to other currencies easily in one go!</p>

            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
              {filteredToTokens.slice(0, 48).map((token) => (
                <button
                  key={token.symbol}
                  onClick={() => setToToken(token.symbol)}
                  className={`flex items-center gap-2 px-3 py-2.5 rounded-lg transition-all border ${
                    toToken === token.symbol
                      ? 'bg-[#2b3139] border-[#f0b90b]'
                      : 'bg-[#1e2329] border-[#2b2e35] hover:border-[#474d57]'
                  }`}
                >
                  <CryptoIcon symbol={token.symbol} size={20} />
                  <span className="text-sm font-medium text-white">{token.symbol}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
        </div>
      </div>

      {showFromDropdown && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-2xl w-full max-w-md max-h-[80vh] flex flex-col">
            <div className="p-6 border-b border-[#3b4149]">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-xl font-semibold">Select Currency</h3>
                <button
                  onClick={() => setShowFromDropdown(false)}
                  className="text-gray-400 hover:text-white transition-colors"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search"
                  className="w-full bg-[#1e2329] border border-[#3b4149] rounded-lg pl-10 pr-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors"
                  autoFocus
                />
              </div>
            </div>

            <div className="flex-1 overflow-y-auto">
              {filteredFromTokens.map((token) => (
                <button
                  key={token.symbol}
                  onClick={() => {
                    setFromToken(token.symbol);
                    setShowFromDropdown(false);
                    setSearchQuery('');
                  }}
                  className="w-full px-6 py-4 flex items-center justify-between hover:bg-[#3b4149] transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <CryptoIcon symbol={token.symbol} size={32} />
                    <div className="text-left">
                      <div className="font-semibold text-white">{token.symbol}</div>
                      <div className="text-sm text-gray-400">{token.name}</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-white">{parseFloat(token.availableBalance).toFixed(8)}</div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {showToDropdown && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="bg-[#2b3139] rounded-2xl w-full max-w-md max-h-[80vh] flex flex-col">
            <div className="p-6 border-b border-[#3b4149]">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-xl font-semibold">Select Currency</h3>
                <button
                  onClick={() => setShowToDropdown(false)}
                  className="text-gray-400 hover:text-white transition-colors"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search"
                  className="w-full bg-[#1e2329] border border-[#3b4149] rounded-lg pl-10 pr-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors"
                  autoFocus
                />
              </div>
            </div>

            <div className="flex-1 overflow-y-auto">
              {filteredToTokens.map((token) => (
                <button
                  key={token.symbol}
                  onClick={() => {
                    setToToken(token.symbol);
                    setShowToDropdown(false);
                    setSearchQuery('');
                  }}
                  className="w-full px-6 py-4 flex items-center justify-between hover:bg-[#3b4149] transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <CryptoIcon symbol={token.symbol} size={32} />
                    <div className="text-left">
                      <div className="font-semibold text-white">{token.symbol}</div>
                      <div className="text-sm text-gray-400">{token.name}</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-white">{parseFloat(token.availableBalance).toFixed(8)}</div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {showConfirmModal && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2329] rounded-2xl w-full max-w-md">
            <div className="p-6 border-b border-[#3b4149]">
              <div className="flex items-center justify-between">
                <h3 className="text-xl font-semibold text-white">Confirm Conversion</h3>
                <div className="flex items-center gap-3">
                  <div className="flex items-center gap-2 px-3 py-1.5 bg-[#2b3139] rounded-lg">
                    <div className="w-2 h-2 bg-[#f0b90b] rounded-full animate-pulse"></div>
                    <span className="text-sm font-medium text-[#f0b90b]">{countdown}s</span>
                  </div>
                  <button
                    onClick={() => {
                      setShowConfirmModal(false);
                      setCountdown(15);
                    }}
                    className="text-gray-400 hover:text-white transition-colors"
                  >
                    <X className="w-6 h-6" />
                  </button>
                </div>
              </div>
            </div>

            <div className="p-6 space-y-4">
              <div className="space-y-3">
                <div className="flex items-center justify-between p-4 bg-[#2b3139] rounded-xl">
                  <div>
                    <div className="text-sm text-gray-400 mb-1">You Pay</div>
                    <div className="flex items-center gap-2">
                      <CryptoIcon symbol={fromToken} size={24} />
                      <span className="text-xl font-semibold text-white">{fromAmount} {fromToken}</span>
                    </div>
                  </div>
                </div>

                <div className="flex justify-center">
                  <div className="w-10 h-10 bg-[#2b3139] rounded-full flex items-center justify-center">
                    <ArrowDownUp className="w-5 h-5 text-gray-400" />
                  </div>
                </div>

                <div className="flex items-center justify-between p-4 bg-[#2b3139] rounded-xl">
                  <div>
                    <div className="text-sm text-gray-400 mb-1">You Receive</div>
                    <div className="flex items-center gap-2">
                      <CryptoIcon symbol={toToken} size={24} />
                      <span className="text-xl font-semibold text-white">{lockedOutput} {toToken}</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-4 bg-[#2b3139] rounded-xl space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-400">Locked Rate</span>
                  <span className="text-white font-medium">
                    1 {fromToken} = {lockedRate?.toFixed(8)} {toToken}
                  </span>
                </div>
                <div className="text-xs text-gray-500">
                  This rate is locked for {countdown} seconds
                </div>
              </div>

              <div className="flex gap-3">
                <button
                  onClick={() => {
                    setShowConfirmModal(false);
                    setCountdown(15);
                  }}
                  className="flex-1 py-3 bg-[#2b3139] hover:bg-[#3b4149] text-white font-semibold rounded-xl transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={executeSwap}
                  disabled={isProcessing}
                  className="flex-1 py-3 bg-[#f0b90b] hover:bg-[#d9a502] text-black font-semibold rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isProcessing ? 'Processing...' : 'Confirm Swap'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showSuccessModal && swapResult && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2329] rounded-2xl w-full max-w-md overflow-hidden">
            <div className="bg-gradient-to-r from-green-500/10 to-emerald-500/10 border-b border-green-500/20 p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-green-500/20 rounded-full flex items-center justify-center">
                    <CheckCircle2 className="w-7 h-7 text-green-500" />
                  </div>
                  <div>
                    <h3 className="text-xl font-semibold text-white">Swap Successful!</h3>
                    <p className="text-sm text-gray-400 mt-0.5">Your conversion has been completed</p>
                  </div>
                </div>
                <button
                  onClick={() => setShowSuccessModal(false)}
                  className="text-gray-400 hover:text-white transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            <div className="p-6 space-y-4">
              <div className="space-y-3">
                <div className="flex items-center justify-between p-4 bg-[#2b3139] rounded-xl">
                  <div className="flex items-center gap-3">
                    <CryptoIcon symbol={swapResult.fromCurrency} size={32} />
                    <div>
                      <div className="text-xs text-gray-400 mb-1">From</div>
                      <div className="text-lg font-semibold text-white">
                        {swapResult.fromAmount} {swapResult.fromCurrency}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex justify-center">
                  <div className="w-8 h-8 bg-[#2b3139] rounded-full flex items-center justify-center">
                    <ArrowDownUp className="w-4 h-4 text-green-500" />
                  </div>
                </div>

                <div className="flex items-center justify-between p-4 bg-[#2b3139] rounded-xl">
                  <div className="flex items-center gap-3">
                    <CryptoIcon symbol={swapResult.toCurrency} size={32} />
                    <div>
                      <div className="text-xs text-gray-400 mb-1">To</div>
                      <div className="text-lg font-semibold text-green-500">
                        {swapResult.toAmount} {swapResult.toCurrency}
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-4 bg-[#2b3139] rounded-xl space-y-2.5">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-400">Exchange Rate</span>
                  <span className="text-white font-medium">
                    1 {swapResult.fromCurrency} = {swapResult.rate} {swapResult.toCurrency}
                  </span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-400">Trading Fee</span>
                  <span className="text-white font-medium">
                    {swapResult.fee} {swapResult.toCurrency}
                  </span>
                </div>
              </div>

              <button
                onClick={() => setShowSuccessModal(false)}
                className="w-full py-3.5 bg-[#f0b90b] hover:bg-[#d9a502] text-black font-semibold rounded-xl transition-colors"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}

      {toasts.map((toast) => (
        <Toast
          key={toast.id}
          message={toast.message}
          type={toast.type}
          onClose={() => removeToast(toast.id)}
        />
      ))}
    </div>
  );
}

export default Swap;
