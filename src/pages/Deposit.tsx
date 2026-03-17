import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { Copy, CheckCircle2, Search, Info, AlertCircle, Loader2, ExternalLink, RefreshCw, ArrowLeft, Clock, ShieldAlert, AlertTriangle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import CryptoIcon from '../components/CryptoIcon';
import { useToast } from '../hooks/useToast';
import { useNavigation } from '../App';

interface CryptoDeposit {
  payment_id: string;
  nowpayments_payment_id?: string;
  pay_address: string;
  pay_amount?: number;
  pay_currency: string;
  price_amount?: number;
  status: string;
  created_at: string;
  expires_at?: string;
  actually_paid?: number;
}

function Deposit() {
  const { user } = useAuth();
  const { showToast } = useToast();
  const { navigateTo } = useNavigation();
  const [selectedCrypto, setSelectedCrypto] = useState<string | null>(null);
  const [selectedNetwork, setSelectedNetwork] = useState<string | null>(null);
  const [showNetworkSelection, setShowNetworkSelection] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [availableCryptos, setAvailableCryptos] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadingCurrencies, setLoadingCurrencies] = useState(true);
  const [depositAddress, setDepositAddress] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [activeDeposit, setActiveDeposit] = useState<CryptoDeposit | null>(null);
  const [depositStatus, setDepositStatus] = useState<string>('waiting');
  const [pendingDeposits, setPendingDeposits] = useState<CryptoDeposit[]>([]);

  const cryptoNames: Record<string, string> = {
    // Major Cryptocurrencies
    btc: 'Bitcoin',
    eth: 'Ethereum',
    ltc: 'Litecoin',
    xrp: 'Ripple',
    bch: 'Bitcoin Cash',

    // Stablecoins
    usdt: 'Tether',
    usdterc20: 'Tether (ERC20)',
    usdttrc20: 'Tether (TRC20)',
    usdtbsc: 'Tether (BSC)',
    usdtsol: 'Tether (SOL)',
    usdc: 'USD Coin',
    usdcerc20: 'USDC (ERC20)',
    usdcbsc: 'USDC (BSC)',
    usdcsol: 'USDC (SOL)',
    dai: 'DAI',
    busd: 'Binance USD',
    tusd: 'TrueUSD',

    // Smart Contract Platforms
    bnb: 'BNB',
    bnbbsc: 'BNB (BSC)',
    sol: 'Solana',
    ada: 'Cardano',
    avax: 'Avalanche',
    avaxc: 'Avalanche C',
    matic: 'Polygon',
    maticpolygon: 'MATIC (Polygon)',
    dot: 'Polkadot',
    atom: 'Cosmos',
    near: 'NEAR',
    ftm: 'Fantom',
    algo: 'Algorand',
    xlm: 'Stellar',
    eos: 'EOS',
    trx: 'TRON',
    etc: 'ETH Classic',
    xtz: 'Tezos',
    hbar: 'Hedera',
    icp: 'Internet Computer',
    fil: 'Filecoin',
    vet: 'VeChain',
    egld: 'MultiversX',
    one: 'Harmony',
    kava: 'Kava',
    celo: 'Celo',

    // Meme & Popular
    doge: 'Dogecoin',
    shib: 'Shiba Inu',
    shibbsc: 'SHIB (BSC)',
    pepe: 'Pepe',
    floki: 'Floki',
    bonk: 'Bonk',

    // DeFi Tokens
    link: 'Chainlink',
    uni: 'Uniswap',
    aave: 'Aave',
    mkr: 'Maker',
    crv: 'Curve',
    snx: 'Synthetix',
    comp: 'Compound',
    ldo: 'Lido',
    grt: 'The Graph',
    '1inch': '1inch',
    sushi: 'SushiSwap',

    // Layer 2 & Scaling
    arb: 'Arbitrum',
    op: 'Optimism',

    // Privacy Coins
    xmr: 'Monero',
    zec: 'Zcash',
    dash: 'Dash',

    // Exchange Tokens
    cro: 'Cronos',
    okb: 'OKB',
    gt: 'Gate Token',

    // Gaming & Metaverse
    sand: 'Sandbox',
    mana: 'Decentraland',
    axs: 'Axie Infinity',
    ape: 'ApeCoin',
    gala: 'Gala',
    enj: 'Enjin',
    imx: 'Immutable X',

    // Other Popular
    apt: 'Aptos',
    sui: 'Sui',
    sei: 'Sei',
    inj: 'Injective',
    rune: 'THORChain',
    ksm: 'Kusama',
    zil: 'Zilliqa',
    waves: 'Waves',
    neo: 'NEO',
    xem: 'NEM',
    qtum: 'Qtum',
    iota: 'IOTA',
    kcs: 'KuCoin',
    cake: 'PancakeSwap',
  };

  // Define networks for multi-chain tokens
  const multiChainNetworks: Record<string, Array<{ code: string; name: string; network: string }>> = {
    usdt: [
      { code: 'usdterc20', name: 'Ethereum (ERC20)', network: 'ERC20' },
      { code: 'usdttrc20', name: 'TRON (TRC20)', network: 'TRC20' },
      { code: 'usdtbsc', name: 'BNB Smart Chain', network: 'BSC' },
      { code: 'usdtsol', name: 'Solana', network: 'Solana' },
    ],
    usdc: [
      { code: 'usdcerc20', name: 'Ethereum (ERC20)', network: 'ERC20' },
      { code: 'usdcbsc', name: 'BNB Smart Chain', network: 'BSC' },
      { code: 'usdcsol', name: 'Solana', network: 'Solana' },
    ],
    bnb: [
      { code: 'bnb', name: 'BNB Beacon Chain', network: 'BEP2' },
      { code: 'bnbbsc', name: 'BNB Smart Chain', network: 'BSC' },
    ],
    matic: [
      { code: 'matic', name: 'Ethereum (ERC20)', network: 'ERC20' },
      { code: 'maticpolygon', name: 'Polygon Network', network: 'Polygon' },
    ],
    avax: [
      { code: 'avax', name: 'Avalanche X-Chain', network: 'X-Chain' },
      { code: 'avaxc', name: 'Avalanche C-Chain', network: 'C-Chain' },
    ],
    shib: [
      { code: 'shib', name: 'Ethereum (ERC20)', network: 'ERC20' },
      { code: 'shibbsc', name: 'BNB Smart Chain', network: 'BSC' },
    ],
  };

  useEffect(() => {
    loadAvailableCurrencies();
    if (user) {
      loadPendingDeposits();
    }
  }, [user]);

  useEffect(() => {
    if (!user || pendingDeposits.length === 0) return;

    const activePendingDeposits = pendingDeposits.filter(d =>
      ['waiting', 'confirming', 'confirmed', 'sending'].includes(d.status)
    );

    if (activePendingDeposits.length === 0) return;

    const checkPaymentStatuses = async () => {
      for (const deposit of activePendingDeposits) {
        if (!deposit.nowpayments_payment_id) continue;

        try {
          const response = await fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/nowpayments-get-status?payment_id=${deposit.nowpayments_payment_id}`
          );

          if (!response.ok) continue;

          const data = await response.json();
          const newStatus = data.payment_status;

          if (newStatus && newStatus !== deposit.status) {
            if (newStatus === 'finished' || newStatus === 'partially_paid') {
              const { data: sessionData } = await supabase.auth.getSession();
              if (sessionData.session) {
                await supabase.rpc('process_crypto_deposit_completion', {
                  p_nowpayments_payment_id: deposit.nowpayments_payment_id,
                  p_status: newStatus,
                  p_actually_paid: parseFloat(data.actually_paid || 0),
                  p_outcome_amount: parseFloat(data.outcome_amount || data.actually_paid || 0)
                });
              }

              showToast(`Deposit Success! Received ${data.actually_paid} ${deposit.pay_currency.toUpperCase()}`, 'success');
              loadPendingDeposits();
            } else if (['confirming', 'confirmed', 'sending'].includes(newStatus)) {
              await supabase
                .from('crypto_deposits')
                .update({
                  status: newStatus,
                  actually_paid: data.actually_paid || 0,
                  updated_at: new Date().toISOString()
                })
                .eq('payment_id', deposit.payment_id);

              loadPendingDeposits();
            }
          }
        } catch (error) {
          console.error('Error checking payment status:', error);
        }
      }
    };

    checkPaymentStatuses();
    const pollInterval = setInterval(checkPaymentStatuses, 5000);

    return () => clearInterval(pollInterval);
  }, [user, pendingDeposits, showToast]);


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
    } catch (error: any) {
      console.error('Error loading pending deposits:', error);
    }
  };

  const loadAvailableCurrencies = async () => {
    try {
      setLoadingCurrencies(true);
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/nowpayments-get-currencies`
      );

      const data = await response.json();

      if (data.success && data.currencies) {
        setAvailableCryptos(data.currencies);
      } else {
        // Fallback to expanded currency list if API fails
        setAvailableCryptos([
          'btc', 'eth', 'usdt', 'usdc', 'bnb', 'ltc', 'trx', 'xrp', 'doge', 'ada',
          'sol', 'matic', 'bch', 'xlm', 'etc', 'dash', 'xmr', 'eos', 'link', 'dot',
          'avax', 'atom', 'near', 'algo', 'vet', 'icp', 'fil', 'apt', 'arb', 'op'
        ]);
      }
    } catch (error: any) {
      console.error('Error loading currencies:', error);
      // Fallback to expanded currency list
      setAvailableCryptos([
        'btc', 'eth', 'usdt', 'usdc', 'bnb', 'ltc', 'trx', 'xrp', 'doge', 'ada',
        'sol', 'matic', 'bch', 'xlm', 'etc', 'dash', 'xmr', 'eos', 'link', 'dot',
        'avax', 'atom', 'near', 'algo', 'vet', 'icp', 'fil', 'apt', 'arb', 'op'
      ]);
    } finally {
      setLoadingCurrencies(false);
    }
  };

  const handleCryptoClick = (crypto: string) => {
    // Check if this crypto has multiple networks
    if (multiChainNetworks[crypto]) {
      setSelectedCrypto(crypto);
      setShowNetworkSelection(true);
    } else {
      generateDepositAddress(crypto);
    }
  };

  const handleNetworkSelect = (networkCode: string) => {
    setSelectedNetwork(networkCode);
    setShowNetworkSelection(false);
    generateDepositAddress(networkCode);
  };

  const generateDepositAddress = async (crypto: string) => {
    if (!user) {
      showToast('Please sign in to generate a deposit address', 'error');
      return;
    }

    try {
      setLoading(true);
      setSelectedCrypto(crypto);

      const { data: sessionData } = await supabase.auth.getSession();
      if (!sessionData.session) {
        throw new Error('No active session');
      }

      console.log('Creating deposit address for:', crypto);

      // Create a payment with default amount of 100 USD - always deposit to spot wallet
      // The actual deposited amount will be credited via IPN callback
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/nowpayments-create-payment`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${sessionData.session.access_token}`,
          },
          body: JSON.stringify({
            price_amount: 100,
            pay_currency: crypto,
            wallet_type: 'spot',
          }),
        }
      );

      console.log('Response status:', response.status);
      const data = await response.json();
      console.log('Response data:', data);

      if (!data.success) {
        throw new Error(data.error || 'Failed to generate deposit address');
      }

      if (!data.payment || !data.payment.pay_address) {
        throw new Error('Invalid response: missing payment address');
      }

      setDepositAddress(data.payment.pay_address);
      showToast('Deposit address generated successfully!', 'success');

      await loadPendingDeposits();
    } catch (error: any) {
      console.error('Error generating address:', error);
      showToast(error.message || 'Failed to generate deposit address', 'error');
      setSelectedCrypto(null);
      setDepositAddress(null);
    } finally {
      setLoading(false);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
    showToast('Copied to clipboard!', 'success');
  };

  const networkVariants = new Set([
    'usdterc20', 'usdttrc20', 'usdtbsc', 'usdtsol',
    'usdcerc20', 'usdcbsc', 'usdcsol',
    'bnbbsc',
    'maticpolygon',
    'avaxc',
    'shibbsc',
  ]);

  const priorityOrder = ['usdt', 'btc', 'usdc', 'eth', 'bnb', 'sol', 'xrp', 'ltc', 'doge', 'matic'];

  const getDisplayCryptos = () => {
    const baseTokens = new Set<string>();
    const seenBaseTokens = new Set<string>();

    availableCryptos.forEach(crypto => {
      const lower = crypto.toLowerCase();
      if (networkVariants.has(lower)) {
        const baseToken = lower.replace(/erc20|trc20|bsc|sol|polygon|c$/i, '').replace(/usdt.*/, 'usdt').replace(/usdc.*/, 'usdc').replace(/bnb.*/, 'bnb').replace(/matic.*/, 'matic').replace(/avax.*/, 'avax').replace(/shib.*/, 'shib');
        seenBaseTokens.add(baseToken);
      } else {
        baseTokens.add(lower);
      }
    });

    seenBaseTokens.forEach(base => baseTokens.add(base));

    const filtered = Array.from(baseTokens).filter(crypto => {
      if (!searchQuery) return true;
      const query = searchQuery.toLowerCase();
      return crypto.includes(query) || (cryptoNames[crypto] || '').toLowerCase().includes(query);
    });

    return filtered.sort((a, b) => {
      const aIndex = priorityOrder.indexOf(a);
      const bIndex = priorityOrder.indexOf(b);
      if (aIndex !== -1 && bIndex !== -1) return aIndex - bIndex;
      if (aIndex !== -1) return -1;
      if (bIndex !== -1) return 1;
      return a.localeCompare(b);
    });
  };

  const filteredCryptos = getDisplayCryptos();

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <h1 className="text-4xl font-bold text-white mb-2">Deposit Crypto</h1>
          <p className="text-gray-400">Fast and secure cryptocurrency deposits</p>
        </div>

        <div className="bg-gradient-to-r from-red-900/20 to-orange-900/10 border border-red-500/30 rounded-xl p-4 mb-6">
          <div className="flex items-start gap-3">
            <ShieldAlert className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
            <div>
              <p className="text-red-200 font-semibold text-sm mb-1">Security Notice - Protect Yourself from Scams</p>
              <ul className="text-gray-300 text-xs space-y-1">
                <li>- Our staff will NEVER ask you to send crypto to any address</li>
                <li>- NEVER share your deposit address with anyone claiming to be support</li>
                <li>- Only deposit directly from your own wallet - verify the address carefully</li>
                <li>- Cryptocurrency transactions are IRREVERSIBLE - double-check all details</li>
              </ul>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            {loading && selectedCrypto && !showNetworkSelection ? (
              <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-12">
                <div className="flex flex-col items-center justify-center gap-4">
                  <Loader2 className="w-12 h-12 animate-spin text-[#f0b90b]" />
                  <div className="text-center">
                    <div className="text-xl font-bold text-white mb-2">Generating Deposit Address</div>
                    <div className="text-gray-400">Creating your {selectedCrypto.toUpperCase()} deposit address...</div>
                  </div>
                </div>
              </div>
            ) : showNetworkSelection && selectedCrypto ? (
              <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6">
                <div className="flex items-center gap-3 mb-6">
                  <button
                    onClick={() => {
                      setShowNetworkSelection(false);
                      setSelectedCrypto(null);
                    }}
                    className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
                  >
                    <ArrowLeft className="w-5 h-5" />
                  </button>
                  <div>
                    <h2 className="text-xl font-bold text-white">Select Network</h2>
                    <p className="text-gray-400 text-sm">Choose the network for {selectedCrypto.toUpperCase()}</p>
                  </div>
                </div>

                <div className="space-y-3">
                  {multiChainNetworks[selectedCrypto]?.map((network) => (
                    <button
                      key={network.code}
                      onClick={() => handleNetworkSelect(network.code)}
                      className="w-full p-4 rounded-xl border border-gray-700 bg-[#0b0e11] hover:border-[#f0b90b] hover:bg-[#181a20] transition-all text-left"
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <div className="font-bold text-white mb-1">{network.name}</div>
                          <div className="text-gray-400 text-sm">{network.network}</div>
                        </div>
                        <CryptoIcon symbol={selectedCrypto.toUpperCase()} size={32} />
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            ) : !depositAddress ? (
              <>
                {/* Pending Deposits */}
                {pendingDeposits.length > 0 && (
                  <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6 mb-6">
                    <h2 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                      <Clock className="w-5 h-5 text-[#f0b90b]" />
                      Pending Deposits
                    </h2>
                    <div className="space-y-3">
                      {pendingDeposits.map((deposit) => {
                        const baseSymbol = deposit.pay_currency.toUpperCase()
                          .replace(/ERC20|TRC20|BSC|SOL|POLYGON$/i, '')
                          .replace(/^USDT.*/, 'USDT')
                          .replace(/^USDC.*/, 'USDC')
                          .replace(/^BNB.*/, 'BNB')
                          .replace(/^MATIC.*/, 'MATIC')
                          .replace(/^AVAX.*/, 'AVAX')
                          .replace(/^SHIB.*/, 'SHIB');

                        return (
                          <div key={deposit.payment_id} className="bg-[#0b0e11] border border-gray-700 rounded-xl p-4">
                            <div className="flex items-center justify-between">
                              <div className="flex items-center gap-3">
                                <CryptoIcon symbol={baseSymbol} size={36} />
                                <div>
                                  <div className="text-white font-medium">{deposit.pay_currency.toUpperCase()}</div>
                                  <div className="text-gray-400 text-sm">
                                    {deposit.status === 'waiting' && 'Waiting for payment'}
                                    {deposit.status === 'confirming' && 'Confirming...'}
                                    {deposit.status === 'confirmed' && 'Confirmed'}
                                    {deposit.status === 'sending' && 'Processing...'}
                                  </div>
                                </div>
                              </div>
                              <div className="text-right">
                                <div className={`px-3 py-1 rounded-full text-xs font-medium ${
                                  deposit.status === 'waiting' ? 'bg-yellow-500/20 text-yellow-400' :
                                  'bg-blue-500/20 text-blue-400'
                                }`}>
                                  {deposit.status.replace('_', ' ').toUpperCase()}
                                </div>
                                {deposit.actually_paid && deposit.actually_paid > 0 && (
                                  <div className="text-green-400 text-sm mt-1">{deposit.actually_paid} {deposit.pay_currency.toUpperCase()}</div>
                                )}
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* Coin Selection */}
                <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6">
                  <h2 className="text-lg font-bold text-white mb-4">Select Coin</h2>

                  {/* Search */}
                  <div className="relative mb-4">
                    <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                    <input
                      type="text"
                      placeholder="Search Coin"
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl pl-12 pr-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors"
                    />
                  </div>

                  {/* Crypto Grid */}
                  {loadingCurrencies ? (
                    <div className="flex items-center justify-center py-12">
                      <Loader2 className="w-8 h-8 animate-spin text-[#f0b90b]" />
                    </div>
                  ) : (
                    <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-3 max-h-96 overflow-y-auto">
                      {filteredCryptos.map((crypto) => {
                        const hasMultipleNetworks = !!multiChainNetworks[crypto];
                        return (
                          <button
                            key={crypto}
                            onClick={() => handleCryptoClick(crypto)}
                            disabled={loading}
                            className="p-3 rounded-xl border border-gray-700 bg-[#0b0e11] hover:border-[#f0b90b] hover:bg-[#181a20] transition-all disabled:opacity-50 disabled:cursor-not-allowed relative"
                          >
                            {hasMultipleNetworks && (
                              <div className="absolute top-1 right-1 bg-[#f0b90b]/20 text-[#f0b90b] text-[9px] px-1.5 py-0.5 rounded font-medium">
                                {multiChainNetworks[crypto].length} Networks
                              </div>
                            )}
                            <div className="flex flex-col items-center gap-2">
                              <CryptoIcon symbol={crypto.toUpperCase()} size={32} />
                              <div className="text-center">
                                <div className="font-bold text-white text-sm uppercase">{crypto}</div>
                                <div className="text-gray-400 text-xs truncate max-w-full">
                                  {cryptoNames[crypto] || crypto}
                                </div>
                              </div>
                            </div>
                          </button>
                        );
                      })}
                    </div>
                  )}
                </div>
              </>
            ) : (
              /* Deposit Address Display */
              <div className="bg-[#181a20] border border-gray-800 rounded-2xl overflow-hidden">
                <div className="bg-gradient-to-r from-green-500/10 to-emerald-500/5 border-b border-gray-800 p-6">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => {
                          setDepositAddress(null);
                          setSelectedCrypto(null);
                        }}
                        className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
                      >
                        <ArrowLeft className="w-5 h-5" />
                      </button>
                      <div>
                        <h2 className="text-xl font-bold text-white mb-1">Deposit {selectedCrypto?.toUpperCase()}</h2>
                        <p className="text-gray-400 text-sm">Send any amount to this address</p>
                      </div>
                    </div>
                    <CryptoIcon symbol={selectedCrypto?.toUpperCase() || 'BTC'} size={48} />
                  </div>
                </div>

                <div className="p-6 space-y-4">
                  <div className="bg-gradient-to-r from-blue-900/20 to-blue-800/10 border border-blue-700/30 rounded-xl p-4">
                    <div className="flex items-start gap-3">
                      <Info className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                      <div className="text-sm text-gray-300">
                        <p className="font-semibold text-white mb-1">Send any amount you want</p>
                        <p>Your deposit will be automatically detected and credited as {selectedCrypto?.toUpperCase()} to your Spot wallet</p>
                      </div>
                    </div>
                  </div>

                  {/* QR Code */}
                  <div className="bg-[#0b0e11] border border-gray-700 rounded-xl p-6">
                    <div className="text-gray-400 text-sm mb-4 text-center">Scan QR Code</div>
                    <div className="flex justify-center">
                      <div className="bg-white p-4 rounded-xl">
                        <img
                          src={`https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(depositAddress || '')}`}
                          alt="Deposit Address QR Code"
                          className="w-[200px] h-[200px]"
                        />
                      </div>
                    </div>
                  </div>

                  <div className="bg-[#0b0e11] border border-gray-700 rounded-xl p-4">
                    <div className="text-gray-400 text-sm mb-3">Deposit Address</div>
                    <div className="bg-[#181a20] border border-gray-700 rounded-xl p-4 flex items-center justify-between gap-3">
                      <div className="text-white font-mono text-sm break-all">{depositAddress}</div>
                      <button
                        onClick={() => copyToClipboard(depositAddress)}
                        className="flex-shrink-0 p-2 bg-[#f0b90b] hover:bg-[#f8d12f] rounded-lg transition-colors"
                      >
                        {copied ? (
                          <CheckCircle2 className="w-5 h-5 text-black" />
                        ) : (
                          <Copy className="w-5 h-5 text-black" />
                        )}
                      </button>
                    </div>
                  </div>

                  <button
                    onClick={() => copyToClipboard(depositAddress)}
                    className="w-full bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] hover:from-[#f8d12f] hover:to-[#f0b90b] text-black font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2 shadow-lg shadow-[#f0b90b]/20"
                  >
                    <Copy className="w-5 h-5" />
                    {copied ? 'Copied!' : 'Copy Address'}
                  </button>

                  <div className="bg-gradient-to-r from-yellow-900/20 to-orange-900/10 border border-yellow-700/30 rounded-xl p-4">
                    <div className="flex items-start gap-3">
                      <AlertCircle className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
                      <div>
                        <h3 className="text-white font-semibold mb-2">Important Notes</h3>
                        <ul className="space-y-2 text-sm text-gray-300">
                          <li className="flex items-start gap-2">
                            <span className="text-yellow-400 mt-0.5">•</span>
                            <span>Send only {selectedCrypto?.toUpperCase()} to this address</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="text-yellow-400 mt-0.5">•</span>
                            <span>Deposits are processed automatically</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="text-yellow-400 mt-0.5">•</span>
                            <span>Minimum deposit: $10 USD equivalent</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="text-yellow-400 mt-0.5">•</span>
                            <span>Credits appear as {selectedCrypto?.toUpperCase()} in your Spot wallet</span>
                          </li>
                        </ul>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            <div className="bg-gradient-to-br from-[#181a20] to-[#0b0e11] border border-gray-800 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-4">How It Works</h3>
              <div className="space-y-4">
                <div className="flex gap-3">
                  <div className="w-8 h-8 bg-[#f0b90b] rounded-full flex items-center justify-center text-black font-bold flex-shrink-0">1</div>
                  <div>
                    <div className="text-white font-semibold">Select Coin</div>
                    <div className="text-gray-400 text-sm">Pick the cryptocurrency to deposit</div>
                  </div>
                </div>
                <div className="flex gap-3">
                  <div className="w-8 h-8 bg-[#f0b90b] rounded-full flex items-center justify-center text-black font-bold flex-shrink-0">2</div>
                  <div>
                    <div className="text-white font-semibold">Get Address</div>
                    <div className="text-gray-400 text-sm">Copy your unique deposit address</div>
                  </div>
                </div>
                <div className="flex gap-3">
                  <div className="w-8 h-8 bg-[#f0b90b] rounded-full flex items-center justify-center text-black font-bold flex-shrink-0">3</div>
                  <div>
                    <div className="text-white font-semibold">Send Crypto</div>
                    <div className="text-gray-400 text-sm">Transfer any amount to the address</div>
                  </div>
                </div>
                <div className="flex gap-3">
                  <div className="w-8 h-8 bg-[#f0b90b] rounded-full flex items-center justify-center text-black font-bold flex-shrink-0">4</div>
                  <div>
                    <div className="text-white font-semibold">Auto Credit</div>
                    <div className="text-gray-400 text-sm">Credited to your Spot wallet</div>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-amber-900/20 to-orange-900/10 border border-amber-500/20 rounded-2xl p-5">
              <div className="flex items-start gap-3 mb-3">
                <AlertTriangle className="w-5 h-5 text-amber-400 flex-shrink-0" />
                <h3 className="text-amber-200 font-semibold text-sm">Risk Warning</h3>
              </div>
              <p className="text-gray-400 text-xs leading-relaxed mb-3">
                Trading cryptocurrencies involves significant risk of loss. Never deposit more than you can afford to lose.
                The value of digital assets can fluctuate significantly.
              </p>
              <button
                onClick={() => navigateTo('legal')}
                className="text-amber-400 hover:text-amber-300 text-xs font-medium transition-colors"
              >
                Read Full Risk Disclosure
              </button>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}

export default Deposit;
