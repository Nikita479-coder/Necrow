import { useState, useEffect, useMemo } from 'react';
import Navbar from '../components/Navbar';
import { ArrowRight, AlertTriangle, Shield, Clock, CheckCircle2, Search, Info, Send, Users, Zap, RefreshCw } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import CryptoIcon from '../components/CryptoIcon';
import { useToast } from '../hooks/useToast';

interface RecentWithdrawal {
  id: string;
  currency: string;
  amount: string;
  network: string;
  status: string;
  created_at: string;
  address?: string;
}

interface UserSearchResult {
  user_id: string;
  email: string;
  username: string;
  full_name: string;
  avatar_url?: string;
}

function Withdraw() {
  const { user } = useAuth();
  const { showToast } = useToast();
  const [withdrawTab, setWithdrawTab] = useState<'external' | 'internal'>('external');
  const [selectedCrypto, setSelectedCrypto] = useState('USDT');
  const [selectedNetwork, setSelectedNetwork] = useState('TRC20');
  const [address, setAddress] = useState('');
  const [amount, setAmount] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [recentWithdrawals, setRecentWithdrawals] = useState<RecentWithdrawal[]>([]);

  // Internal transfer states
  const [recipientSearch, setRecipientSearch] = useState('');
  const [searchResults, setSearchResults] = useState<UserSearchResult[]>([]);
  const [selectedRecipient, setSelectedRecipient] = useState<UserSearchResult | null>(null);
  const [transferAmount, setTransferAmount] = useState('');
  const [transferCurrency, setTransferCurrency] = useState('USDT');
  const [isSearching, setIsSearching] = useState(false);
  const [isTransferring, setIsTransferring] = useState(false);
  const [isWithdrawing, setIsWithdrawing] = useState(false);
  const [walletBalances, setWalletBalances] = useState<Record<string, number>>({});
  const [lockedBalances, setLockedBalances] = useState<Record<string, number>>({});
  const [isLoadingBalances, setIsLoadingBalances] = useState(true);

  const cryptos = [
    { symbol: 'USDT', name: 'Tether', balance: '10000', networks: ['TRC20', 'ERC20', 'BEP20', 'Polygon', 'Solana'], fee: '1', minWithdraw: '10' },
    { symbol: 'BTC', name: 'Bitcoin', balance: '0.05234', networks: ['Bitcoin', 'BEP20', 'ERC20'], fee: '0.0005', minWithdraw: '0.001' },
    { symbol: 'ETH', name: 'Ethereum', balance: '2.5', networks: ['Ethereum', 'BEP20', 'Arbitrum'], fee: '0.003', minWithdraw: '0.01' },
    { symbol: 'USDC', name: 'USD Coin', balance: '5000', networks: ['ERC20', 'TRC20', 'BEP20', 'Polygon', 'Solana'], fee: '1', minWithdraw: '10' },
    { symbol: 'BNB', name: 'BNB', balance: '5.234', networks: ['BEP20', 'BEP2'], fee: '0.0001', minWithdraw: '0.01' },
    { symbol: 'SOL', name: 'Solana', balance: '15.67', networks: ['Solana'], fee: '0.01', minWithdraw: '0.1' },
    { symbol: 'XRP', name: 'Ripple', balance: '1000', networks: ['Ripple'], fee: '0.1', minWithdraw: '10' },
    { symbol: 'LTC', name: 'Litecoin', balance: '8.5', networks: ['Litecoin'], fee: '0.001', minWithdraw: '0.01' },
    { symbol: 'TRX', name: 'TRON', balance: '5000', networks: ['TRC20'], fee: '1', minWithdraw: '10' },
    { symbol: 'DOGE', name: 'Dogecoin', balance: '10000', networks: ['Dogecoin'], fee: '5', minWithdraw: '50' },
    { symbol: 'ADA', name: 'Cardano', balance: '1500', networks: ['Cardano'], fee: '1', minWithdraw: '10' },
    { symbol: 'MATIC', name: 'Polygon', balance: '800', networks: ['Polygon', 'Ethereum'], fee: '0.1', minWithdraw: '1' },
    { symbol: 'BCH', name: 'Bitcoin Cash', balance: '2.5', networks: ['Bitcoin Cash'], fee: '0.001', minWithdraw: '0.01' },
    { symbol: 'XLM', name: 'Stellar', balance: '3000', networks: ['Stellar'], fee: '0.01', minWithdraw: '1' },
    { symbol: 'ETC', name: 'Ethereum Classic', balance: '15', networks: ['Ethereum Classic'], fee: '0.01', minWithdraw: '0.1' },
    { symbol: 'DASH', name: 'Dash', balance: '5', networks: ['Dash'], fee: '0.002', minWithdraw: '0.02' },
    { symbol: 'XMR', name: 'Monero', balance: '3', networks: ['Monero'], fee: '0.0001', minWithdraw: '0.001' },
    { symbol: 'EOS', name: 'EOS', balance: '500', networks: ['EOS'], fee: '0.1', minWithdraw: '1' },
    { symbol: 'LINK', name: 'Chainlink', balance: '100', networks: ['Ethereum', 'BEP20'], fee: '0.1', minWithdraw: '1' },
    { symbol: 'DOT', name: 'Polkadot', balance: '50', networks: ['Polkadot'], fee: '0.01', minWithdraw: '0.1' },
    { symbol: 'AVAX', name: 'Avalanche', balance: '30', networks: ['Avalanche', 'Ethereum'], fee: '0.01', minWithdraw: '0.1' },
    { symbol: 'ATOM', name: 'Cosmos', balance: '100', networks: ['Cosmos'], fee: '0.01', minWithdraw: '0.1' },
    { symbol: 'NEAR', name: 'NEAR Protocol', balance: '200', networks: ['NEAR'], fee: '0.01', minWithdraw: '0.1' },
    { symbol: 'ALGO', name: 'Algorand', balance: '500', networks: ['Algorand'], fee: '0.01', minWithdraw: '1' },
    { symbol: 'VET', name: 'VeChain', balance: '5000', networks: ['VeChain'], fee: '1', minWithdraw: '10' },
    { symbol: 'ICP', name: 'Internet Computer', balance: '20', networks: ['Internet Computer'], fee: '0.0001', minWithdraw: '0.01' },
    { symbol: 'FIL', name: 'Filecoin', balance: '25', networks: ['Filecoin'], fee: '0.001', minWithdraw: '0.01' },
    { symbol: 'APT', name: 'Aptos', balance: '50', networks: ['Aptos'], fee: '0.001', minWithdraw: '0.1' },
    { symbol: 'ARB', name: 'Arbitrum', balance: '100', networks: ['Arbitrum'], fee: '0.0001', minWithdraw: '0.001' },
    { symbol: 'OP', name: 'Optimism', balance: '75', networks: ['Optimism'], fee: '0.0001', minWithdraw: '0.001' },
  ];

  useEffect(() => {
    if (user) {
      loadRecentWithdrawals();
      loadWalletBalances();
    }
  }, [user]);

  const isExternalFormValid = useMemo(() => {
    const addressValid = address.trim().length >= 10;
    const amountValid = parseFloat(amount) > 0;
    return addressValid && amountValid;
  }, [address, amount]);

  const isInternalFormValid = useMemo(() => {
    const recipientValid = !!selectedRecipient;
    const amountValid = parseFloat(transferAmount) > 0;
    return recipientValid && amountValid;
  }, [selectedRecipient, transferAmount]);

  const loadWalletBalances = async () => {
    if (!user) {
      console.log('[Withdraw] No user, skipping wallet load');
      setIsLoadingBalances(false);
      return;
    }

    setIsLoadingBalances(true);
    console.log('[Withdraw] Loading wallets for user:', user.id);

    try {
      const { data, error } = await supabase
        .from('wallets')
        .select('currency, balance, locked_balance')
        .eq('user_id', user.id)
        .eq('wallet_type', 'main');

      console.log('[Withdraw] Wallet query result:', { data, error });

      if (error) throw error;

      if (data && data.length > 0) {
        const balances: Record<string, number> = {};
        const locked: Record<string, number> = {};
        data.forEach(w => {
          const total = parseFloat(w.balance) || 0;
          const lockedAmt = parseFloat(w.locked_balance) || 0;
          balances[w.currency] = Math.max(total - lockedAmt, 0);
          locked[w.currency] = lockedAmt;
          console.log(`[Withdraw] ${w.currency}: balance=${total}, locked=${lockedAmt}, available=${balances[w.currency]}`);
        });
        setWalletBalances(balances);
        setLockedBalances(locked);
      } else {
        console.log('[Withdraw] No wallet data returned');
      }
    } catch (error) {
      console.error('[Withdraw] Error loading wallet balances:', error);
    } finally {
      setIsLoadingBalances(false);
    }
  };

  const loadRecentWithdrawals = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('transactions')
        .select('id, currency, amount, status, created_at, address, network')
        .eq('user_id', user.id)
        .eq('transaction_type', 'withdrawal')
        .order('created_at', { ascending: false })
        .limit(5);

      if (error) throw error;

      if (data) {
        setRecentWithdrawals(data.map(tx => ({
          ...tx,
          network: tx.network || selectedNetwork
        })));
      }
    } catch (error) {
      console.error('Error loading withdrawals:', error);
    }
  };

  const handleWithdraw = async () => {
    console.log('=== WITHDRAW BUTTON CLICKED ===');
    console.log('User:', user?.id);
    console.log('Address:', address);
    console.log('Amount:', amount);
    console.log('Selected Crypto:', selectedCrypto);
    console.log('Selected Network:', selectedNetwork);

    if (!user) {
      console.error('No user logged in');
      showToast('Please sign in to withdraw', 'error');
      return;
    }

    if (!address || address.trim().length < 10) {
      console.error('Invalid address:', address);
      showToast('Please enter a valid wallet address (minimum 10 characters)', 'error');
      return;
    }

    const withdrawAmount = parseFloat(amount);
    if (isNaN(withdrawAmount) || withdrawAmount <= 0) {
      console.error('Invalid amount:', amount);
      showToast('Please enter a valid amount', 'error');
      return;
    }

    const minWithdraw = parseFloat(selectedCryptoData?.minWithdraw || '0');
    if (withdrawAmount < minWithdraw) {
      console.error('Amount below minimum:', withdrawAmount, 'Min:', minWithdraw);
      showToast(`Minimum withdrawal is ${minWithdraw} ${selectedCrypto}`, 'error');
      return;
    }

    const availableBalance = walletBalances[selectedCrypto] || 0;
    const roundedWithdrawAmount = Math.round(withdrawAmount * 1e6) / 1e6;
    const roundedAvailableBalance = Math.round(availableBalance * 1e6) / 1e6;
    console.log('Available balance:', roundedAvailableBalance, 'Requested:', roundedWithdrawAmount);
    if (roundedWithdrawAmount > roundedAvailableBalance + 0.000001) {
      console.error('Insufficient balance');
      showToast(`Insufficient balance. Available: ${roundedAvailableBalance.toFixed(6)} ${selectedCrypto}`, 'error');
      return;
    }

    console.log('✓ All validations passed. Submitting withdrawal...');

    setIsWithdrawing(true);
    try {
      const requestBody = {
        currency: selectedCrypto,
        amount: roundedWithdrawAmount,
        address: address.trim(),
        network: selectedNetwork
      };
      console.log('Request body:', requestBody);

      const { data, error } = await supabase.functions.invoke('submit-withdrawal', {
        body: requestBody
      });

      console.log('=== WITHDRAWAL RESPONSE ===');
      console.log('Data:', data);
      console.log('Error:', error);

      if (error) {
        console.error('Edge function error:', error);
        showToast(error.message || 'Network error occurred', 'error');
        return;
      }

      if (data && data.success) {
        console.log('✓ Withdrawal successful!');
        showToast(`Withdrawal request submitted! ${roundedWithdrawAmount} ${selectedCrypto} is pending approval`, 'success');
        setAmount('');
        setAddress('');
        await loadRecentWithdrawals();
        await loadWalletBalances();
      } else {
        const errorMessage = data?.error || 'Withdrawal request failed';
        console.error('Withdrawal failed:', errorMessage);
        showToast(errorMessage, 'error');
      }
    } catch (error: any) {
      console.error('=== WITHDRAWAL EXCEPTION ===');
      console.error('Error object:', error);
      console.error('Error message:', error?.message);
      console.error('Error description:', error?.error_description);
      const errorMessage = error?.message || error?.error_description || 'Failed to submit withdrawal request. Please try again.';
      showToast(errorMessage, 'error');
    } finally {
      setIsWithdrawing(false);
      console.log('=== WITHDRAWAL PROCESS COMPLETE ===');
    }
  };

  const filteredCryptos = cryptos.filter(crypto =>
    crypto.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    crypto.symbol.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const selectedCryptoData = cryptos.find(c => c.symbol === selectedCrypto);
  const networkFee = selectedCryptoData ? parseFloat(selectedCryptoData.fee) : 0;
  const amountNum = parseFloat(amount) || 0;
  const receiveAmount = amountNum > networkFee ? (amountNum - networkFee).toFixed(6) : '0';

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

  const handlePaste = async () => {
    try {
      const text = await navigator.clipboard.readText();
      setAddress(text);
    } catch (err) {
      console.error('Failed to read clipboard:', err);
    }
  };

  const searchUsers = async (searchTerm: string) => {
    if (!searchTerm || searchTerm.length < 2) {
      setSearchResults([]);
      return;
    }

    setIsSearching(true);
    try {
      const { data, error } = await supabase.rpc('search_users_for_transfer', {
        search_term: searchTerm,
        requesting_user_id: user?.id
      });

      if (error) throw error;
      setSearchResults(data || []);
    } catch (error) {
      console.error('Error searching users:', error);
      showToast('Failed to search users', 'error');
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  };

  const handleTransferToUser = async () => {
    if (!selectedRecipient || !transferAmount || parseFloat(transferAmount) <= 0) {
      showToast('Please select a recipient and enter an amount', 'error');
      return;
    }

    setIsTransferring(true);
    try {
      const { data, error } = await supabase.rpc('transfer_to_user', {
        sender_id: user?.id,
        recipient_email_or_username: selectedRecipient.email,
        transfer_amount: parseFloat(transferAmount),
        transfer_currency: transferCurrency,
        wallet_type_param: 'main'
      });

      if (error) throw error;

      const result = data as { success: boolean; error?: string; recipient_name?: string; amount?: number; currency?: string };

      if (result.success) {
        showToast(`Successfully sent ${result.amount} ${result.currency} to ${result.recipient_name}`, 'success');
        setTransferAmount('');
        setSelectedRecipient(null);
        setRecipientSearch('');
        setSearchResults([]);
        loadRecentWithdrawals();
      } else {
        showToast(result.error || 'Transfer failed', 'error');
      }
    } catch (error: any) {
      console.error('Transfer error:', error);
      showToast(error.message || 'Failed to complete transfer', 'error');
    } finally {
      setIsTransferring(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      if (recipientSearch) {
        searchUsers(recipientSearch);
      }
    }, 300);

    return () => clearTimeout(timer);
  }, [recipientSearch]);

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-white mb-2">Withdraw & Transfer</h1>
          <p className="text-gray-400">Send cryptocurrency to external wallet or transfer to friends</p>
        </div>

        <div className="mb-6 bg-[#181a20] border border-gray-800 rounded-2xl p-2 inline-flex">
          <button
            onClick={() => setWithdrawTab('external')}
            className={`px-6 py-3 rounded-xl font-semibold transition-all flex items-center gap-2 ${
              withdrawTab === 'external'
                ? 'bg-[#f0b90b] text-black shadow-lg'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            <Send className="w-5 h-5" />
            External Withdrawal
          </button>
          <button
            onClick={() => setWithdrawTab('internal')}
            className={`px-6 py-3 rounded-xl font-semibold transition-all flex items-center gap-2 ${
              withdrawTab === 'internal'
                ? 'bg-[#f0b90b] text-black shadow-lg'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            <Users className="w-5 h-5" />
            Send to Friend
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {withdrawTab === 'external' ? (
            <>
          <div className="lg:col-span-2 space-y-6">
            <div className="bg-[#181a20] border border-gray-800 rounded-2xl overflow-hidden">
              <div className="bg-gradient-to-r from-[#f0b90b]/10 to-[#f8d12f]/5 border-b border-gray-800 p-6">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-[#f0b90b] rounded-full flex items-center justify-center text-black font-bold">1</div>
                  <div>
                    <h2 className="text-xl font-bold text-white">Choose Coin to Withdraw</h2>
                    <p className="text-gray-400 text-sm">Select the cryptocurrency you want to withdraw</p>
                  </div>
                </div>
              </div>

              <div className="p-6">
                <div className="relative mb-4">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Search crypto..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl pl-10 pr-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                  />
                </div>

                <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-3 max-h-96 overflow-y-auto">
                  {filteredCryptos.map((crypto) => (
                    <button
                      key={crypto.symbol}
                      onClick={() => {
                        setSelectedCrypto(crypto.symbol);
                        setSelectedNetwork(crypto.networks[0]);
                      }}
                      className={`p-3 rounded-xl border transition-all ${
                        selectedCrypto === crypto.symbol
                          ? 'bg-[#f0b90b]/10 border-[#f0b90b] shadow-lg shadow-[#f0b90b]/20'
                          : 'bg-[#0b0e11] border-gray-700 hover:border-gray-600 hover:bg-[#181a20]'
                      }`}
                    >
                      <div className="flex flex-col items-center gap-2">
                        <CryptoIcon symbol={crypto.symbol} size={32} />
                        <div className="text-center">
                          <div className="font-bold text-white text-sm">{crypto.symbol}</div>
                          <div className="text-gray-400 text-xs truncate max-w-full">{crypto.name}</div>
                        </div>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="bg-[#181a20] border border-gray-800 rounded-2xl overflow-hidden">
              <div className="bg-gradient-to-r from-[#f0b90b]/10 to-[#f8d12f]/5 border-b border-gray-800 p-6">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-[#f0b90b] rounded-full flex items-center justify-center text-black font-bold">2</div>
                  <div>
                    <h2 className="text-xl font-bold text-white">Choose a Chain</h2>
                    <p className="text-gray-400 text-sm">Select the network for your withdrawal</p>
                  </div>
                </div>
              </div>

              <div className="p-6">
                <div className="space-y-2">
                  {selectedCryptoData?.networks.map((network) => (
                    <button
                      key={network}
                      onClick={() => setSelectedNetwork(network)}
                      className={`w-full p-4 rounded-xl border transition-all text-left ${
                        selectedNetwork === network
                          ? 'bg-[#f0b90b]/10 border-[#f0b90b] shadow-lg shadow-[#f0b90b]/20'
                          : 'bg-[#0b0e11] border-gray-700 hover:border-gray-600 hover:bg-[#181a20]'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <div className="font-bold text-white mb-1">{network}</div>
                          <div className="text-gray-400 text-sm">Network fee: {selectedCryptoData.fee} {selectedCrypto}</div>
                        </div>
                        {selectedNetwork === network && (
                          <CheckCircle2 className="w-6 h-6 text-[#f0b90b]" />
                        )}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="bg-[#181a20] border border-gray-800 rounded-2xl overflow-hidden">
              <div className="bg-gradient-to-r from-[#f0b90b]/10 to-[#f8d12f]/5 border-b border-gray-800 p-6">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-[#f0b90b] rounded-full flex items-center justify-center text-black font-bold">3</div>
                  <div>
                    <h2 className="text-xl font-bold text-white">Enter Withdrawal Details</h2>
                    <p className="text-gray-400 text-sm">Provide address and amount</p>
                  </div>
                </div>
              </div>

              <div className="p-6 space-y-4">
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <label className="text-gray-400 text-sm font-medium">Withdrawal Address</label>
                    <button
                      onClick={handlePaste}
                      className="text-[#f0b90b] text-sm hover:text-[#f8d12f] transition-colors font-medium"
                    >
                      Paste
                    </button>
                  </div>
                  <input
                    type="text"
                    placeholder="Enter wallet address"
                    value={address}
                    onChange={(e) => setAddress(e.target.value)}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors font-mono text-sm"
                  />
                </div>

                <div>
                  <div className="flex items-center justify-between mb-2">
                    <label className="text-gray-400 text-sm font-medium">Amount</label>
                    <div className="text-gray-400 text-sm text-right flex items-center gap-2">
                      <div>
                        <div>Available: <span className="text-white font-semibold">
                          {isLoadingBalances ? (
                            <span className="text-gray-500">Loading...</span>
                          ) : (
                            `${(walletBalances[selectedCrypto] || 0).toFixed(6)} ${selectedCrypto}`
                          )}
                        </span></div>
                        {(lockedBalances[selectedCrypto] || 0) > 0 && (
                          <div className="text-yellow-400 text-xs">Locked (pending withdrawal): {(lockedBalances[selectedCrypto] || 0).toFixed(2)} {selectedCrypto}</div>
                        )}
                      </div>
                      <button
                        onClick={loadWalletBalances}
                        disabled={isLoadingBalances}
                        className="p-1 hover:bg-gray-700 rounded transition-colors"
                        title="Refresh balance"
                      >
                        <RefreshCw className={`w-4 h-4 ${isLoadingBalances ? 'animate-spin text-gray-500' : 'text-gray-400 hover:text-white'}`} />
                      </button>
                    </div>
                  </div>
                  <div className="relative">
                    <input
                      type="number"
                      placeholder="0.00"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors pr-24 text-lg font-semibold"
                    />
                    <button
                      onClick={() => {
                        const available = walletBalances[selectedCrypto] || 0;
                        setAmount(available > 0 ? available.toFixed(6) : '0');
                      }}
                      className="absolute right-3 top-1/2 transform -translate-y-1/2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold px-4 py-1.5 rounded-lg text-sm transition-colors"
                    >
                      MAX
                    </button>
                  </div>
                  <div className="flex gap-2 mt-2">
                    {['25%', '50%', '75%'].map((percent) => (
                      <button
                        key={percent}
                        onClick={() => {
                          const percentage = parseInt(percent) / 100;
                          const balance = walletBalances[selectedCrypto] || 0;
                          setAmount((balance * percentage).toFixed(6));
                        }}
                        className="flex-1 px-3 py-2 bg-[#0b0e11] hover:bg-[#2b3139] border border-gray-700 hover:border-[#f0b90b] rounded-lg text-sm text-gray-400 hover:text-white transition-colors"
                      >
                        {percent}
                      </button>
                    ))}
                  </div>
                </div>

                {amount && parseFloat(amount) > 0 && (
                  <div className="bg-gradient-to-r from-[#0b0e11] to-[#181a20] border border-gray-700 rounded-xl p-4 space-y-3">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-gray-400">Network Fee</span>
                      <span className="text-white font-semibold">{selectedCryptoData?.fee} {selectedCrypto}</span>
                    </div>
                    <div className="h-px bg-gradient-to-r from-transparent via-gray-700 to-transparent"></div>
                    <div className="flex items-center justify-between">
                      <span className="text-gray-400">You'll Receive</span>
                      <span className="text-[#f0b90b] font-bold text-lg">{receiveAmount} {selectedCrypto}</span>
                    </div>
                  </div>
                )}

                <div className="bg-gradient-to-r from-yellow-900/20 to-orange-900/10 border border-yellow-700/30 rounded-xl p-4">
                  <div className="flex items-start gap-3">
                    <AlertTriangle className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
                    <div className="text-sm text-gray-300 space-y-2">
                      <p className="font-semibold text-white">Security Notice:</p>
                      <ul className="space-y-1 text-xs">
                        <li className="flex items-start gap-2">
                          <span className="text-yellow-400 mt-0.5">•</span>
                          <span>Double-check the withdrawal address - transactions cannot be reversed</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-yellow-400 mt-0.5">•</span>
                          <span>Ensure you're using the correct network</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-yellow-400 mt-0.5">•</span>
                          <span>Minimum withdrawal: {selectedCryptoData?.minWithdraw} {selectedCrypto}</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-yellow-400 mt-0.5">•</span>
                          <span>Funds will be locked until withdrawal is approved or rejected</span>
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>

                {(!address || !amount || parseFloat(amount) <= 0) && !isWithdrawing && (
                  <div className="bg-blue-900/20 border border-blue-700/30 rounded-xl p-3 text-sm text-blue-300">
                    <div className="flex items-start gap-2">
                      <Info className="w-4 h-4 flex-shrink-0 mt-0.5" />
                      <div>
                        {!address && !amount && "Please enter a wallet address and amount to continue"}
                        {!address && amount && "Please enter a wallet address"}
                        {address && !amount && "Please enter an amount"}
                        {address && amount && parseFloat(amount) <= 0 && "Please enter a valid amount greater than 0"}
                      </div>
                    </div>
                  </div>
                )}

                <button
                  onClick={handleWithdraw}
                  disabled={!isExternalFormValid || isWithdrawing}
                  className="w-full bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] hover:from-[#f8d12f] hover:to-[#f0b90b] disabled:from-gray-700 disabled:to-gray-700 disabled:cursor-not-allowed text-black disabled:text-gray-500 font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2 shadow-lg shadow-[#f0b90b]/20 disabled:shadow-none"
                >
                  {isWithdrawing ? (
                    <>
                      <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-black"></div>
                      Processing Withdrawal...
                    </>
                  ) : (
                    <>
                      <Send className="w-5 h-5" />
                      Withdraw {selectedCrypto}
                    </>
                  )}
                </button>
              </div>
            </div>

            {recentWithdrawals.length > 0 && (
              <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6">
                <h2 className="text-xl font-bold text-white mb-4">Recent Withdrawals</h2>
                <div className="space-y-3">
                  {recentWithdrawals.map((withdrawal) => (
                    <div key={withdrawal.id} className="bg-[#0b0e11] border border-gray-700 rounded-xl p-4 hover:border-gray-600 transition-colors">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-4">
                          <CryptoIcon symbol={withdrawal.currency} size={40} />
                          <div>
                            <div className="font-bold text-white">{withdrawal.amount} {withdrawal.currency}</div>
                            <div className="text-gray-400 text-sm">{withdrawal.network} • {formatTimeAgo(withdrawal.created_at)}</div>
                          </div>
                        </div>
                        <div className="text-right">
                          <div className={`px-3 py-1 rounded-full text-xs font-semibold ${
                            withdrawal.status === 'completed'
                              ? 'bg-emerald-500/20 text-emerald-400'
                              : withdrawal.status === 'failed'
                              ? 'bg-red-500/20 text-red-400'
                              : withdrawal.status === 'pending'
                              ? 'bg-orange-500/20 text-orange-400'
                              : 'bg-blue-500/20 text-blue-400'
                          }`}>
                            {withdrawal.status === 'completed' ? 'Completed' :
                             withdrawal.status === 'failed' ? 'Rejected' :
                             withdrawal.status === 'pending' ? 'Pending (Locked)' : 'Processing'}
                          </div>
                          {withdrawal.address && (
                            <div className="text-gray-400 text-xs mt-1">To: {withdrawal.address.substring(0, 10)}...</div>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div className="space-y-6">
            <div className="bg-gradient-to-br from-emerald-900/20 to-emerald-800/10 border border-emerald-700/30 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                <Shield className="w-5 h-5 text-emerald-400" />
                Security Verification
              </h3>
              <div className="space-y-3">
                <div className="flex items-center gap-3 text-sm">
                  <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                  <span className="text-gray-300">Email Verification Enabled</span>
                </div>
                <div className="flex items-center gap-3 text-sm">
                  <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                  <span className="text-gray-300">2FA Authentication Active</span>
                </div>
                <div className="flex items-center gap-3 text-sm">
                  <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                  <span className="text-gray-300">KYC Verification Complete</span>
                </div>
                <div className="flex items-center gap-3 text-sm">
                  <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                  <span className="text-gray-300">Withdrawal Whitelist Enabled</span>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-[#181a20] to-[#0b0e11] border border-gray-800 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                <Clock className="w-5 h-5 text-[#f0b90b]" />
                Withdrawal Information
              </h3>
              <div className="space-y-3">
                <div className="flex items-center justify-between pb-3 border-b border-gray-700">
                  <span className="text-gray-400 text-sm">Selected Coin</span>
                  <div className="flex items-center gap-2">
                    <CryptoIcon symbol={selectedCrypto} size={20} />
                    <span className="text-white font-semibold">{selectedCrypto}</span>
                  </div>
                </div>
                <div className="flex items-center justify-between pb-3 border-b border-gray-700">
                  <span className="text-gray-400 text-sm">Network</span>
                  <span className="text-white font-semibold">{selectedNetwork}</span>
                </div>
                <div className="flex items-center justify-between pb-3 border-b border-gray-700">
                  <span className="text-gray-400 text-sm">Network Fee</span>
                  <span className="text-white font-semibold">{selectedCryptoData?.fee} {selectedCrypto}</span>
                </div>
                <div className="flex items-center justify-between pb-3 border-b border-gray-700">
                  <span className="text-gray-400 text-sm">Min Withdrawal</span>
                  <span className="text-white font-semibold">{selectedCryptoData?.minWithdraw} {selectedCrypto}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-gray-400 text-sm">Processing Time</span>
                  <span className="text-white font-semibold">~15-30 min</span>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-[#181a20] to-[#0b0e11] border border-gray-800 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-3">Daily Withdrawal Limit</h3>
              <div className="mb-3">
                <div className="flex items-center justify-between text-sm mb-2">
                  <span className="text-gray-400">Used Today</span>
                  <span className="text-white font-semibold">2.5 / 10 BTC</span>
                </div>
                <div className="w-full bg-gray-700 rounded-full h-2.5 overflow-hidden">
                  <div className="bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] h-2.5 rounded-full transition-all" style={{ width: '25%' }}></div>
                </div>
              </div>
              <p className="text-gray-400 text-xs">Increase your limits by completing advanced KYC verification</p>
            </div>
          </div>
          </>
          ) : (
            <>
            <div className="lg:col-span-2 space-y-6">
              <div className="bg-[#181a20] border border-gray-800 rounded-2xl overflow-hidden">
                <div className="bg-gradient-to-r from-[#0ecb81]/10 to-[#0ecb81]/5 border-b border-gray-800 p-6">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-[#0ecb81] rounded-full flex items-center justify-center text-black font-bold">
                      <Zap className="w-6 h-6" />
                    </div>
                    <div>
                      <h2 className="text-xl font-bold text-white">Send to Friend</h2>
                      <p className="text-gray-400 text-sm">Instant transfers • No fees • By email or username</p>
                    </div>
                  </div>
                </div>

                <div className="p-6 space-y-6">
                  <div>
                    <label className="text-gray-400 text-sm font-medium mb-2 block">Find Recipient</label>
                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                      <input
                        type="text"
                        placeholder="Search by email or username..."
                        value={recipientSearch}
                        onChange={(e) => {
                          setRecipientSearch(e.target.value);
                          setSelectedRecipient(null);
                        }}
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl pl-10 pr-4 py-3 text-white outline-none focus:border-[#0ecb81] transition-colors"
                      />
                    </div>

                    {isSearching && (
                      <div className="mt-3 text-center text-gray-400 text-sm">Searching...</div>
                    )}

                    {searchResults.length > 0 && !selectedRecipient && (
                      <div className="mt-3 bg-[#0b0e11] border border-gray-700 rounded-xl overflow-hidden">
                        {searchResults.map((result) => (
                          <button
                            key={result.user_id}
                            onClick={() => {
                              setSelectedRecipient(result);
                              setRecipientSearch('');
                              setSearchResults([]);
                            }}
                            className="w-full p-4 hover:bg-[#181a20] transition-colors text-left border-b border-gray-800 last:border-b-0"
                          >
                            <div className="flex items-center gap-3">
                              <div className="w-10 h-10 bg-gradient-to-br from-[#0ecb81] to-[#0ecb81]/60 rounded-full flex items-center justify-center text-white font-bold">
                                {result.full_name?.[0] || result.username[0] || 'U'}
                              </div>
                              <div>
                                <div className="font-semibold text-white">{result.full_name || result.username}</div>
                                <div className="text-sm text-gray-400">{result.email}</div>
                              </div>
                            </div>
                          </button>
                        ))}
                      </div>
                    )}

                    {selectedRecipient && (
                      <div className="mt-3 bg-gradient-to-br from-[#0ecb81]/10 to-[#0ecb81]/5 border border-[#0ecb81]/30 rounded-xl p-4">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 bg-gradient-to-br from-[#0ecb81] to-[#0ecb81]/60 rounded-full flex items-center justify-center text-white font-bold">
                              {selectedRecipient.full_name?.[0] || selectedRecipient.username[0] || 'U'}
                            </div>
                            <div>
                              <div className="font-semibold text-white">{selectedRecipient.full_name || selectedRecipient.username}</div>
                              <div className="text-sm text-gray-400">{selectedRecipient.email}</div>
                            </div>
                          </div>
                          <button
                            onClick={() => setSelectedRecipient(null)}
                            className="text-gray-400 hover:text-white transition-colors"
                          >
                            <AlertTriangle className="w-5 h-5" />
                          </button>
                        </div>
                      </div>
                    )}
                  </div>

                  <div>
                    <label className="text-gray-400 text-sm font-medium mb-2 block">Select Currency</label>
                    <div className="grid grid-cols-4 gap-2">
                      {['USDT', 'BTC', 'ETH', 'USDC'].map((currency) => (
                        <button
                          key={currency}
                          onClick={() => setTransferCurrency(currency)}
                          className={`p-3 rounded-xl border transition-all ${
                            transferCurrency === currency
                              ? 'bg-[#0ecb81]/10 border-[#0ecb81] shadow-lg shadow-[#0ecb81]/20'
                              : 'bg-[#0b0e11] border-gray-700 hover:border-gray-600'
                          }`}
                        >
                          <div className="flex flex-col items-center gap-1">
                            <CryptoIcon symbol={currency} size={24} />
                            <span className="text-sm font-semibold text-white">{currency}</span>
                          </div>
                        </button>
                      ))}
                    </div>
                  </div>

                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="text-gray-400 text-sm font-medium">Amount to Send</label>
                      <div className="text-gray-400 text-sm">
                        Available: <span className="text-white font-semibold">
                          {cryptos.find(c => c.symbol === transferCurrency)?.balance || '0'} {transferCurrency}
                        </span>
                      </div>
                    </div>
                    <div className="relative">
                      <input
                        type="number"
                        placeholder="0.00"
                        value={transferAmount}
                        onChange={(e) => setTransferAmount(e.target.value)}
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#0ecb81] transition-colors pr-24 text-lg font-semibold"
                      />
                      <button
                        onClick={() => {
                          const balance = cryptos.find(c => c.symbol === transferCurrency)?.balance || '0';
                          setTransferAmount(balance);
                        }}
                        className="absolute right-3 top-1/2 transform -translate-y-1/2 bg-[#0ecb81] hover:bg-[#0ecb81]/80 text-black font-bold px-4 py-1.5 rounded-lg text-sm transition-colors"
                      >
                        MAX
                      </button>
                    </div>
                  </div>

                  {transferAmount && parseFloat(transferAmount) > 0 && selectedRecipient && (
                    <div className="bg-gradient-to-r from-[#0b0e11] to-[#181a20] border border-gray-700 rounded-xl p-4 space-y-3">
                      <div className="flex items-center justify-between text-sm">
                        <span className="text-gray-400">Transfer Fee</span>
                        <span className="text-[#0ecb81] font-semibold">FREE</span>
                      </div>
                      <div className="h-px bg-gradient-to-r from-transparent via-gray-700 to-transparent"></div>
                      <div className="flex items-center justify-between">
                        <span className="text-gray-400">{selectedRecipient.full_name || selectedRecipient.username} will receive</span>
                        <span className="text-[#0ecb81] font-bold text-lg">{transferAmount} {transferCurrency}</span>
                      </div>
                    </div>
                  )}

                  <div className="bg-gradient-to-r from-emerald-900/20 to-emerald-800/10 border border-emerald-700/30 rounded-xl p-4">
                    <div className="flex items-start gap-3">
                      <Zap className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
                      <div className="text-sm text-gray-300 space-y-2">
                        <p className="font-semibold text-white">Instant Transfer Benefits:</p>
                        <ul className="space-y-1 text-xs">
                          <li className="flex items-start gap-2">
                            <span className="text-emerald-400 mt-0.5">•</span>
                            <span>No fees - 100% of your amount goes to the recipient</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="text-emerald-400 mt-0.5">•</span>
                            <span>Instant transfer - funds arrive immediately</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="text-emerald-400 mt-0.5">•</span>
                            <span>Safe & secure - transfers only between verified users</span>
                          </li>
                        </ul>
                      </div>
                    </div>
                  </div>

                  <button
                    onClick={handleTransferToUser}
                    disabled={!isInternalFormValid || isTransferring}
                    className="w-full bg-gradient-to-r from-[#0ecb81] to-[#0ecb81]/80 hover:from-[#0ecb81]/90 hover:to-[#0ecb81]/70 disabled:from-gray-700 disabled:to-gray-700 disabled:cursor-not-allowed text-black disabled:text-gray-500 font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2 shadow-lg shadow-[#0ecb81]/20 disabled:shadow-none"
                  >
                    {isTransferring ? (
                      <>Processing...</>
                    ) : (
                      <>
                        <Zap className="w-5 h-5" />
                        Send {transferCurrency} Instantly
                      </>
                    )}
                  </button>
                </div>
              </div>
            </div>

            <div className="space-y-6">
              <div className="bg-gradient-to-br from-emerald-900/20 to-emerald-800/10 border border-emerald-700/30 rounded-2xl p-6">
                <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                  <Zap className="w-5 h-5 text-emerald-400" />
                  Why Send to Friends?
                </h3>
                <div className="space-y-3">
                  <div className="flex items-center gap-3 text-sm">
                    <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                    <span className="text-gray-300">Zero fees on all transfers</span>
                  </div>
                  <div className="flex items-center gap-3 text-sm">
                    <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                    <span className="text-gray-300">Instant delivery</span>
                  </div>
                  <div className="flex items-center gap-3 text-sm">
                    <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                    <span className="text-gray-300">Send by email or username</span>
                  </div>
                  <div className="flex items-center gap-3 text-sm">
                    <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                    <span className="text-gray-300">Perfect for splitting bills</span>
                  </div>
                </div>
              </div>

              <div className="bg-gradient-to-br from-[#181a20] to-[#0b0e11] border border-gray-800 rounded-2xl p-6">
                <h3 className="text-lg font-bold text-white mb-4">Transfer Limits</h3>
                <div className="space-y-3">
                  <div className="flex items-center justify-between pb-3 border-b border-gray-700">
                    <span className="text-gray-400 text-sm">Daily Limit</span>
                    <span className="text-white font-semibold">Unlimited</span>
                  </div>
                  <div className="flex items-center justify-between pb-3 border-b border-gray-700">
                    <span className="text-gray-400 text-sm">Transfer Fee</span>
                    <span className="text-emerald-400 font-semibold">FREE</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-400 text-sm">Processing Time</span>
                    <span className="text-white font-semibold">Instant</span>
                  </div>
                </div>
              </div>
            </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default Withdraw;
