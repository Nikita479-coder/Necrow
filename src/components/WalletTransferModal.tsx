import { useState, useEffect, useCallback } from 'react';
import { X, ArrowRight, RefreshCw, AlertCircle, CheckCircle, Wallet, TrendingUp, Copy } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface WalletTransferModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  initialFromWallet?: 'main' | 'futures' | 'copy';
}

type WalletType = 'main' | 'futures' | 'copy';

interface WalletBalances {
  main_available: number;
  copy_available: number;
  copy_allocated: number;
  copy_wallet: number;
  futures_available: number;
  futures_locked: number;
  futures_transferable: number;
  futures_locked_bonus: number;
}

const WALLET_CONFIG: Record<WalletType, { label: string; icon: typeof Wallet; color: string }> = {
  main: { label: 'Main Wallet', icon: Wallet, color: 'text-blue-400' },
  futures: { label: 'Futures Wallet', icon: TrendingUp, color: 'text-orange-400' },
  copy: { label: 'Copy Trading Wallet', icon: Copy, color: 'text-purple-400' }
};

export default function WalletTransferModal({
  isOpen,
  onClose,
  onSuccess,
  initialFromWallet = 'main'
}: WalletTransferModalProps) {
  const { user } = useAuth();
  const [fromWallet, setFromWallet] = useState<WalletType>(initialFromWallet);
  const [toWallet, setToWallet] = useState<WalletType>('futures');
  const [amount, setAmount] = useState('');
  const [balances, setBalances] = useState<WalletBalances | null>(null);
  const [loading, setLoading] = useState(false);
  const [loadingBalances, setLoadingBalances] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const loadBalances = useCallback(async () => {
    if (!user) return;

    setLoadingBalances(true);
    try {
      const { data, error: rpcError } = await supabase.rpc('get_wallet_balances', {
        p_user_id: user.id
      });

      if (rpcError) throw rpcError;

      setBalances({
        main_available: parseFloat(data?.main_available || '0'),
        copy_available: parseFloat(data?.copy_available || '0'),
        copy_allocated: parseFloat(data?.copy_allocated || '0'),
        copy_wallet: parseFloat(data?.copy_wallet || '0'),
        futures_available: parseFloat(data?.futures_available || '0'),
        futures_locked: parseFloat(data?.futures_locked || '0'),
        futures_transferable: parseFloat(data?.futures_transferable || '0'),
        futures_locked_bonus: parseFloat(data?.futures_locked_bonus || '0')
      });
    } catch (err) {
      console.error('Error loading balances:', err);
      setBalances({
        main_available: 0,
        copy_available: 0,
        copy_allocated: 0,
        copy_wallet: 0,
        futures_available: 0,
        futures_locked: 0,
        futures_transferable: 0,
        futures_locked_bonus: 0
      });
    } finally {
      setLoadingBalances(false);
    }
  }, [user]);

  useEffect(() => {
    if (isOpen && user) {
      loadBalances();
      setError('');
      setSuccess('');
      setAmount('');
    }
  }, [isOpen, user, loadBalances]);

  useEffect(() => {
    if (fromWallet === toWallet) {
      const options: WalletType[] = ['main', 'futures', 'copy'];
      const newTo = options.find(w => w !== fromWallet) || 'futures';
      setToWallet(newTo);
    }
  }, [fromWallet, toWallet]);

  const getAvailableBalance = (walletType: WalletType, forTransfer = false): number => {
    if (!balances) return 0;
    switch (walletType) {
      case 'main':
        return balances.main_available;
      case 'copy':
        return balances.copy_available;
      case 'futures':
        return forTransfer ? balances.futures_transferable : balances.futures_available;
      default:
        return 0;
    }
  };

  const currentAvailable = getAvailableBalance(fromWallet, true);

  const handleTransfer = async () => {
    if (!user) return;

    setError('');
    setSuccess('');

    const transferAmount = parseFloat(amount);

    if (isNaN(transferAmount) || transferAmount <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    if (transferAmount > currentAvailable) {
      setError('Insufficient balance');
      return;
    }

    setLoading(true);

    try {
      const { data, error: rpcError } = await supabase.rpc('transfer_between_wallets', {
        user_id_param: user.id,
        currency_param: 'USDT',
        amount_param: transferAmount,
        from_wallet_type_param: fromWallet,
        to_wallet_type_param: toWallet
      });

      if (rpcError) throw rpcError;

      if (data && !data.success) {
        setError(data.error || 'Transfer failed');
        return;
      }

      setSuccess(data?.message || 'Transfer completed successfully');
      setAmount('');
      await loadBalances();

      setTimeout(() => {
        onSuccess();
        onClose();
      }, 1500);
    } catch (err: any) {
      console.error('Transfer error:', err);
      setError(err.message || 'Failed to transfer funds');
    } finally {
      setLoading(false);
    }
  };

  const handleMaxClick = () => {
    if (currentAvailable > 0) {
      setAmount(currentAvailable.toFixed(8).replace(/\.?0+$/, ''));
    }
  };

  const swapWallets = () => {
    const temp = fromWallet;
    setFromWallet(toWallet);
    setToWallet(temp);
    setAmount('');
    setError('');
  };

  if (!isOpen) return null;

  const FromIcon = WALLET_CONFIG[fromWallet].icon;
  const ToIcon = WALLET_CONFIG[toWallet].icon;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-[#181a20] rounded-2xl w-full max-w-md border border-gray-800 shadow-2xl">
        <div className="flex items-center justify-between p-6 border-b border-gray-800">
          <h3 className="text-xl font-bold text-white">Transfer Between Wallets</h3>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors p-1"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div className="flex items-center gap-3">
            <div className="flex-1">
              <label className="text-gray-400 text-sm mb-2 block">From</label>
              <select
                value={fromWallet}
                onChange={(e) => {
                  setFromWallet(e.target.value as WalletType);
                  setAmount('');
                  setError('');
                }}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors appearance-none cursor-pointer"
              >
                {Object.entries(WALLET_CONFIG).map(([key, config]) => (
                  <option key={key} value={key}>{config.label}</option>
                ))}
              </select>
            </div>

            <button
              onClick={swapWallets}
              className="mt-6 p-2 hover:bg-gray-800 rounded-lg transition-colors group"
              title="Swap wallets"
            >
              <ArrowRight className="w-5 h-5 text-[#f0b90b] group-hover:scale-110 transition-transform" />
            </button>

            <div className="flex-1">
              <label className="text-gray-400 text-sm mb-2 block">To</label>
              <select
                value={toWallet}
                onChange={(e) => setToWallet(e.target.value as WalletType)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors appearance-none cursor-pointer"
              >
                {Object.entries(WALLET_CONFIG)
                  .filter(([key]) => key !== fromWallet)
                  .map(([key, config]) => (
                    <option key={key} value={key}>{config.label}</option>
                  ))}
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="bg-[#0b0e11] border border-gray-700 rounded-xl p-4">
              <div className="flex items-center gap-2 mb-2">
                <FromIcon className={`w-4 h-4 ${WALLET_CONFIG[fromWallet].color}`} />
                <span className="text-gray-400 text-xs">From Balance</span>
              </div>
              {loadingBalances ? (
                <div className="h-6 bg-gray-800 rounded animate-pulse"></div>
              ) : (
                <div className="text-white font-bold">
                  {currentAvailable.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} USDT
                </div>
              )}
              {fromWallet === 'copy' && balances && balances.copy_allocated > 0 && (
                <div className="text-xs text-yellow-500 mt-1">
                  {balances.copy_allocated.toLocaleString(undefined, { minimumFractionDigits: 2 })} USDT allocated to traders
                </div>
              )}
            </div>

            <div className="bg-[#0b0e11] border border-gray-700 rounded-xl p-4">
              <div className="flex items-center gap-2 mb-2">
                <ToIcon className={`w-4 h-4 ${WALLET_CONFIG[toWallet].color}`} />
                <span className="text-gray-400 text-xs">To Balance</span>
              </div>
              {loadingBalances ? (
                <div className="h-6 bg-gray-800 rounded animate-pulse"></div>
              ) : (
                <div className="text-white font-bold">
                  {getAvailableBalance(toWallet, false).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} USDT
                </div>
              )}
            </div>
          </div>

          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="text-gray-400 text-sm">Amount</label>
              <button
                onClick={loadBalances}
                disabled={loadingBalances}
                className="text-xs text-gray-500 hover:text-gray-300 flex items-center gap-1 transition-colors"
              >
                <RefreshCw className={`w-3 h-3 ${loadingBalances ? 'animate-spin' : ''}`} />
                Refresh
              </button>
            </div>
            <div className="relative">
              <input
                type="number"
                value={amount}
                onChange={(e) => {
                  setAmount(e.target.value);
                  setError('');
                }}
                placeholder="0.00"
                step="any"
                min="0"
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-4 text-white text-lg outline-none focus:border-[#f0b90b] transition-colors pr-20"
              />
              <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                <span className="text-gray-500 text-sm">USDT</span>
                <button
                  onClick={handleMaxClick}
                  disabled={currentAvailable <= 0}
                  className="text-[#f0b90b] text-sm font-semibold hover:text-[#f8d12f] transition-colors disabled:opacity-50 disabled:cursor-not-allowed px-2 py-1 bg-[#f0b90b]/10 rounded"
                >
                  MAX
                </button>
              </div>
            </div>
            <p className="text-xs text-gray-500 mt-2">
              Available: {currentAvailable.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 8 })} USDT
            </p>
          </div>

          {error && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
              <p className="text-red-400 text-sm">{error}</p>
            </div>
          )}

          {success && (
            <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-xl p-4 flex items-start gap-3">
              <CheckCircle className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
              <p className="text-emerald-400 text-sm">{success}</p>
            </div>
          )}

          <button
            onClick={handleTransfer}
            disabled={loading || !amount || parseFloat(amount) <= 0 || parseFloat(amount) > currentAvailable || success !== ''}
            className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] disabled:bg-gray-700 disabled:cursor-not-allowed text-black disabled:text-gray-500 font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2"
          >
            {loading ? (
              <>
                <RefreshCw className="w-5 h-5 animate-spin" />
                Processing...
              </>
            ) : success ? (
              <>
                <CheckCircle className="w-5 h-5" />
                Transfer Complete
              </>
            ) : (
              'Confirm Transfer'
            )}
          </button>

          {fromWallet === 'copy' && balances && balances.copy_allocated > 0 && (
            <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-xl p-4">
              <p className="text-sm text-yellow-200">
                <span className="font-semibold">{balances.copy_allocated.toLocaleString(undefined, { minimumFractionDigits: 2 })} USDT</span> is allocated to active traders and cannot be transferred.
              </p>
              <p className="text-xs text-gray-400 mt-1">
                Stop copying traders to withdraw these funds.
              </p>
            </div>
          )}

          {fromWallet === 'futures' && balances && balances.futures_locked_bonus > 0 && (
            <div className="bg-orange-500/10 border border-orange-500/20 rounded-xl p-4">
              <p className="text-sm text-orange-200">
                <span className="font-semibold">${balances.futures_locked_bonus.toLocaleString(undefined, { minimumFractionDigits: 2 })} USDT</span> is locked bonus funds and cannot be transferred.
              </p>
              <p className="text-xs text-gray-400 mt-1">
                Complete the trading volume requirement to unlock bonus funds. Your real deposits can be transferred freely.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
