import { useState, useEffect } from 'react';
import { X, ArrowRight } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface WalletTransferModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  currency?: string;
  fromWalletType?: 'main' | 'assets' | 'copy' | 'futures';
}

export default function WalletTransferModal({
  isOpen,
  onClose,
  onSuccess,
  currency: initialCurrency = 'USDT',
  fromWalletType: initialFromWallet = 'main'
}: WalletTransferModalProps) {
  const { user } = useAuth();
  const [currency, setCurrency] = useState(initialCurrency);
  const [amount, setAmount] = useState('');
  const [fromWallet, setFromWallet] = useState<'main' | 'assets' | 'copy' | 'futures'>(initialFromWallet);
  const [toWallet, setToWallet] = useState<'main' | 'assets' | 'copy' | 'futures'>('assets');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [availableBalance, setAvailableBalance] = useState(0);

  const walletTypes = [
    { value: 'main', label: 'Main Wallet' },
    { value: 'assets', label: 'Assets Wallet' },
    { value: 'copy', label: 'Copy Trading' },
    { value: 'futures', label: 'Futures Wallet' }
  ];

  const cryptoOptions = ['USDT', 'BTC', 'ETH', 'BNB', 'SOL', 'USDC', 'XRP', 'ADA', 'DOGE', 'DOT', 'MATIC', 'LTC'];

  useEffect(() => {
    if (isOpen && user) {
      loadBalance();
    }
  }, [isOpen, user, currency, fromWallet]);

  const loadBalance = async () => {
    if (!user) return;

    try {
      // For futures wallet, we need to get available balance (excluding locked margin)
      if (fromWallet === 'futures') {
        const { data, error } = await supabase.rpc('get_wallet_balances', {
          p_user_id: user.id
        });

        if (error) throw error;

        // Updated to match new data structure: use total_trading_available which includes locked bonus
        setAvailableBalance(parseFloat(data?.total_trading_available || '0'));
      } else {
        // For other wallets, query directly
        const { data, error } = await supabase
          .from('wallets')
          .select('balance, locked_balance')
          .eq('user_id', user.id)
          .eq('currency', currency)
          .eq('wallet_type', fromWallet)
          .maybeSingle();

        if (error) throw error;

        // Available = balance - locked_balance
        const balance = parseFloat(data?.balance || '0');
        const locked = parseFloat(data?.locked_balance || '0');
        setAvailableBalance(balance - locked);
      }
    } catch (err) {
      console.error('Error loading balance:', err);
      setAvailableBalance(0);
    }
  };

  const handleTransfer = async () => {
    if (!user) return;

    setError('');
    const transferAmount = parseFloat(amount);

    if (isNaN(transferAmount) || transferAmount <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    if (transferAmount > availableBalance) {
      setError('Insufficient balance');
      return;
    }

    if (fromWallet === toWallet) {
      setError('Source and destination wallets must be different');
      return;
    }

    setLoading(true);

    try {
      const { data, error: rpcError } = await supabase.rpc('transfer_between_wallets', {
        user_id_param: user.id,
        currency_param: currency,
        amount_param: transferAmount,
        from_wallet_type_param: fromWallet,
        to_wallet_type_param: toWallet
      });

      if (rpcError) throw rpcError;

      if (data && !data.success) {
        setError(data.error || 'Transfer failed');
        return;
      }

      onSuccess();
      onClose();
      setAmount('');
    } catch (err: any) {
      console.error('Transfer error:', err);
      setError(err.message || 'Failed to transfer funds');
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
      <div className="bg-[#181a20] rounded-2xl p-6 max-w-md w-full border border-gray-800">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-xl font-bold text-white">Transfer Between Wallets</h3>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="text-gray-400 text-sm mb-2 block">Currency</label>
            <select
              value={currency}
              onChange={(e) => {
                setCurrency(e.target.value);
                loadBalance();
              }}
              className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
            >
              {cryptoOptions.map(crypto => (
                <option key={crypto} value={crypto}>{crypto}</option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-4">
            <div className="flex-1">
              <label className="text-gray-400 text-sm mb-2 block">From</label>
              <select
                value={fromWallet}
                onChange={(e) => {
                  setFromWallet(e.target.value as any);
                  loadBalance();
                }}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
              >
                {walletTypes.map(type => (
                  <option key={type.value} value={type.value}>{type.label}</option>
                ))}
              </select>
            </div>

            <div className="pt-6">
              <ArrowRight className="w-6 h-6 text-[#f0b90b]" />
            </div>

            <div className="flex-1">
              <label className="text-gray-400 text-sm mb-2 block">To</label>
              <select
                value={toWallet}
                onChange={(e) => setToWallet(e.target.value as any)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
              >
                {walletTypes.filter(t => t.value !== fromWallet).map(type => (
                  <option key={type.value} value={type.value}>{type.label}</option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="text-gray-400 text-sm mb-2 block">Amount</label>
            <div className="relative">
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.00"
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
              />
              <button
                onClick={() => setAmount(availableBalance.toString())}
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-[#f0b90b] text-sm font-medium hover:text-[#f8d12f] transition-colors"
              >
                MAX
              </button>
            </div>
            <div className="flex items-center justify-between mt-2">
              <p className="text-xs text-gray-500">Available: {availableBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 8 })} {currency}</p>
            </div>
          </div>

          {error && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-3 text-red-400 text-sm">
              {error}
            </div>
          )}

          <button
            onClick={handleTransfer}
            disabled={loading || !amount || parseFloat(amount) <= 0}
            className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] disabled:bg-gray-700 disabled:cursor-not-allowed text-black disabled:text-gray-500 font-bold py-3 rounded-xl transition-all"
          >
            {loading ? 'Transferring...' : 'Confirm Transfer'}
          </button>
        </div>
      </div>
    </div>
  );
}
