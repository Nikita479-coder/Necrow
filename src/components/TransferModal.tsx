import { useState, useEffect } from 'react';
import { X, ArrowRight } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface TransferModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

interface WalletBalances {
  main_wallet: number;
  futures_available: number;
  futures_locked: number;
  futures_total: number;
}

function TransferModal({ isOpen, onClose, onSuccess }: TransferModalProps) {
  const { user } = useAuth();
  const [direction, setDirection] = useState<'to_futures' | 'from_futures'>('to_futures');
  const [amount, setAmount] = useState('');
  const [balances, setBalances] = useState<WalletBalances | null>(null);
  const [isTransferring, setIsTransferring] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen && user) {
      fetchBalances();
      setAmount('');
      setError('');
    }
  }, [isOpen, user]);

  useEffect(() => {
    if (isOpen) {
      setAmount('');
      setError('');
    }
  }, [direction]);

  const fetchBalances = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase.rpc('get_wallet_balances', {
        p_user_id: user.id
      });

      if (error) throw error;

      // Convert new data structure to old format for compatibility
      const mainWallet = data?.main_wallets?.find((w: any) => w.currency === 'USDT')?.balance || 0;
      const futuresAvailable = parseFloat(data?.futures?.available_balance || 0);
      const futuresLocked = parseFloat(data?.futures?.locked_balance || 0);
      const lockedBonus = parseFloat(data?.locked_bonus?.balance || 0);
      const totalAvailable = parseFloat(data?.total_trading_available || 0);

      setBalances({
        main_wallet: parseFloat(mainWallet),
        futures_available: totalAvailable, // Use total_trading_available which includes locked bonus
        futures_locked: futuresLocked,
        futures_total: parseFloat(data?.futures?.total_equity || 0)
      });
    } catch (err) {
      console.error('Error fetching balances:', err);
    }
  };

  const handleTransfer = async () => {
    if (!user || !amount || parseFloat(amount) <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    setIsTransferring(true);
    setError('');

    try {
      const transferAmount = parseFloat(amount);
      const functionName = direction === 'to_futures'
        ? 'transfer_to_futures_wallet'
        : 'transfer_from_futures_wallet';

      console.log('Transfer request:', {
        user_id: user.id,
        amount: transferAmount,
        function: functionName
      });

      const { data, error } = await supabase.rpc(functionName, {
        p_user_id: user.id,
        p_amount: transferAmount
      });

      if (error) {
        console.error('RPC Error:', error);
        throw error;
      }

      console.log('Transfer response:', data);

      if (data && !data.success) {
        const errorMsg = data.error || 'Transfer failed';
        console.error('Transfer failed:', data);
        setError(errorMsg);
        setIsTransferring(false);
        return;
      }

      if (!data || !data.success) {
        setError('Transfer failed. Please try again.');
        setIsTransferring(false);
        return;
      }

      setAmount('');
      await fetchBalances();
      onSuccess();
      onClose();
    } catch (err: any) {
      console.error('Transfer error:', err);
      setError(err.message || 'Transfer failed');
    } finally {
      setIsTransferring(false);
    }
  };

  const handleMaxAmount = () => {
    if (!balances) return;
    const maxAmount = direction === 'to_futures'
      ? balances.main_wallet
      : balances.futures_available;
    setAmount(maxAmount.toFixed(2));
  };

  if (!isOpen) return null;

  const sourceBalance = direction === 'to_futures'
    ? balances?.main_wallet || 0
    : balances?.futures_available || 0;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-[#1a1d24] rounded-2xl max-w-md w-full border border-gray-800">
        <div className="flex items-center justify-between p-6 border-b border-gray-800">
          <h2 className="text-xl font-bold text-white">Transfer Funds</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div className="flex gap-2">
            <button
              onClick={() => setDirection('to_futures')}
              className={`flex-1 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                direction === 'to_futures'
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
              }`}
            >
              To Futures
            </button>
            <button
              onClick={() => setDirection('from_futures')}
              className={`flex-1 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                direction === 'from_futures'
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
              }`}
            >
              From Futures
            </button>
          </div>

          <div className="bg-gray-800/50 rounded-lg p-4 space-y-3">
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-400">
                {direction === 'to_futures' ? 'Main Wallet' : 'Futures Wallet'}
              </span>
              <span className="text-white font-medium">
                {sourceBalance.toFixed(2)} USDT
              </span>
            </div>
            <div className="flex items-center justify-center">
              <ArrowRight className="w-5 h-5 text-gray-500" />
            </div>
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-400">
                {direction === 'to_futures' ? 'Futures Wallet' : 'Main Wallet'}
              </span>
              <span className="text-white font-medium">
                {direction === 'to_futures'
                  ? (balances?.futures_available || 0).toFixed(2)
                  : (balances?.main_wallet || 0).toFixed(2)
                } USDT
              </span>
            </div>
          </div>

          <div>
            <label className="text-sm text-gray-400 mb-2 block">Amount (USDT)</label>
            <div className="relative">
              <input
                type="text"
                value={amount}
                onChange={(e) => {
                  setAmount(e.target.value);
                  setError('');
                }}
                placeholder="0.00"
                className="w-full bg-gray-900 border border-gray-800 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#f0b90b]/50"
              />
              <button
                onClick={handleMaxAmount}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-[#f0b90b] text-sm font-medium hover:text-[#d9a506]"
              >
                MAX
              </button>
            </div>
          </div>

          {error && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-3">
              <p className="text-red-400 text-sm">{error}</p>
            </div>
          )}

          <button
            onClick={handleTransfer}
            disabled={isTransferring || !amount || parseFloat(amount) <= 0}
            className="w-full bg-[#f0b90b] hover:bg-[#d9a506] disabled:bg-gray-700 disabled:cursor-not-allowed text-black font-semibold py-3 rounded-lg transition-colors"
          >
            {isTransferring ? 'Transferring...' : 'Confirm Transfer'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default TransferModal;
