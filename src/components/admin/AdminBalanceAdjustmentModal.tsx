import { useState } from 'react';
import { X, DollarSign } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useToast } from '../../hooks/useToast';

interface Props {
  isOpen: boolean;
  onClose: () => void;
  userId: string;
  userName: string;
  onSuccess: () => void;
}

export default function AdminBalanceAdjustmentModal({ isOpen, onClose, userId, userName, onSuccess }: Props) {
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);
  const { showToast } = useToast();

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const numAmount = parseFloat(amount);
    if (isNaN(numAmount)) {
      showToast('Invalid amount', 'error');
      return;
    }

    if (numAmount === 0) {
      showToast('Amount cannot be zero', 'error');
      return;
    }

    if (!description.trim()) {
      showToast('Description is required', 'error');
      return;
    }

    setLoading(true);
    try {
      console.log('Making RPC call with:', {
        p_user_id: userId,
        p_currency: 'USDT',
        p_amount: numAmount,
        p_description: description.trim()
      });

      const { data, error } = await supabase.rpc('admin_adjust_user_balance', {
        p_user_id: userId,
        p_currency: 'USDT',
        p_amount: numAmount,
        p_description: description.trim()
      });

      console.log('RPC response:', { data, error });

      if (error) {
        console.error('RPC Error:', error);
        showToast(`Failed to adjust balance: ${error.message}`, 'error');
        return;
      }

      if (!data) {
        showToast('No response from server', 'error');
        return;
      }

      if (typeof data === 'object' && 'success' in data && !data.success) {
        showToast(data.error || 'Failed to adjust balance', 'error');
        return;
      }

      const message = typeof data === 'object' && 'message' in data ? data.message : 'Balance adjusted successfully';
      showToast(message, 'success');
      onSuccess();
      handleClose();
    } catch (error: any) {
      console.error('Caught error:', error);
      showToast(`Error: ${error.message || 'Unknown error'}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    setAmount('');
    setDescription('');
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-[#1a1d24] rounded-2xl border border-gray-800 w-full max-w-md">
        <div className="flex items-center justify-between p-6 border-b border-gray-800">
          <div>
            <h2 className="text-xl font-bold text-white">Adjust Balance</h2>
            <p className="text-sm text-gray-400 mt-1">User: {userName}</p>
          </div>
          <button
            onClick={handleClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Amount (USDT)
            </label>
            <div className="relative">
              <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="number"
                step="0.01"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="Enter amount (+ to add, - to subtract)"
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg pl-10 pr-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-[#f0b90b]"
                disabled={loading}
                required
              />
            </div>
            <p className="text-xs text-gray-400 mt-2">
              Use positive numbers to add funds, negative to subtract
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Description
            </label>
            <input
              type="text"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="e.g., Crypto Deposit Refund, Bonus Award"
              className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-[#f0b90b]"
              disabled={loading}
              required
            />
            <p className="text-xs text-gray-400 mt-2">
              This will appear in the user's transaction history
            </p>
          </div>

          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4">
            <p className="text-sm text-yellow-400">
              This action will directly modify the user's main wallet balance and create a transaction record.
            </p>
          </div>

          <div className="flex gap-3">
            <button
              type="button"
              onClick={handleClose}
              className="flex-1 px-4 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors"
              disabled={loading}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-3 bg-[#f0b90b] hover:bg-[#d9a309] text-black rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={loading}
            >
              {loading ? 'Processing...' : 'Adjust Balance'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
