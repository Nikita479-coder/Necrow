import { useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Receipt, Plus, X } from 'lucide-react';

interface AdminCardTransactionsProps {
  userId: string;
  userName: string;
  cardId?: string;
  onTransactionCreated?: () => void;
}

export default function AdminCardTransactions({ userId, userName, cardId, onTransactionCreated }: AdminCardTransactionsProps) {
  const [showModal, setShowModal] = useState(false);
  const [description, setDescription] = useState('');
  const [amount, setAmount] = useState('');
  const [transactionType, setTransactionType] = useState<'card' | 'fee' | 'refund' | 'adjustment'>('card');
  const [status, setStatus] = useState<'approved' | 'declined' | 'pending'>('approved');
  const [merchant, setMerchant] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(false);

    try {
      const { data, error: rpcError } = await supabase.rpc('create_card_transaction', {
        p_user_id: userId,
        p_description: description,
        p_amount: parseFloat(amount),
        p_transaction_type: transactionType,
        p_status: status,
        p_merchant: merchant || null
      });

      if (rpcError) throw rpcError;

      const result = data as { success: boolean; error?: string };
      if (!result.success) {
        throw new Error(result.error || 'Failed to create transaction');
      }

      setSuccess(true);
      setDescription('');
      setAmount('');
      setTransactionType('card');
      setStatus('approved');
      setMerchant('');

      setTimeout(() => {
        setShowModal(false);
        setSuccess(false);
        if (onTransactionCreated) onTransactionCreated();
      }, 1500);
    } catch (err: any) {
      console.error('Error creating transaction:', err);
      setError(err.message || 'Failed to create transaction');
    } finally {
      setLoading(false);
    }
  };

  if (!cardId) {
    return (
      <div className="bg-gray-800/30 border border-gray-700 rounded-lg p-6 text-center">
        <Receipt className="w-12 h-12 text-gray-600 mx-auto mb-3" />
        <p className="text-gray-400">User does not have an active Shark Card</p>
      </div>
    );
  }

  return (
    <div>
      <button
        onClick={() => setShowModal(true)}
        className="flex items-center gap-2 px-4 py-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg transition-all font-medium"
      >
        <Plus className="w-4 h-4" />
        Add Transaction
      </button>

      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] border border-gray-800 rounded-2xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="text-xl font-bold text-white">Add Card Transaction</h3>
                <p className="text-sm text-gray-400 mt-1">For {userName}</p>
              </div>
              <button
                onClick={() => setShowModal(false)}
                className="text-gray-400 hover:text-white transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Description *
                </label>
                <input
                  type="text"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="e.g., Netflix Subscription"
                  className="w-full px-4 py-2 bg-[#0d0f12] border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-[#f0b90b]"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Merchant (Optional)
                </label>
                <input
                  type="text"
                  value={merchant}
                  onChange={(e) => setMerchant(e.target.value)}
                  placeholder="e.g., NETFLIX.COM"
                  className="w-full px-4 py-2 bg-[#0d0f12] border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-[#f0b90b]"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Amount (USD) *
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="0.00"
                  className="w-full px-4 py-2 bg-[#0d0f12] border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-[#f0b90b]"
                  required
                />
                <p className="text-xs text-gray-500 mt-1">Use negative for debits (e.g., -10.00)</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Type
                </label>
                <select
                  value={transactionType}
                  onChange={(e) => setTransactionType(e.target.value as any)}
                  className="w-full px-4 py-2 bg-[#0d0f12] border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-[#f0b90b]"
                >
                  <option value="card">Card Payment</option>
                  <option value="fee">Fee</option>
                  <option value="refund">Refund</option>
                  <option value="adjustment">Adjustment</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Status
                </label>
                <select
                  value={status}
                  onChange={(e) => setStatus(e.target.value as any)}
                  className="w-full px-4 py-2 bg-[#0d0f12] border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-[#f0b90b]"
                >
                  <option value="approved">Approved</option>
                  <option value="declined">Declined</option>
                  <option value="pending">Pending</option>
                </select>
              </div>

              {error && (
                <div className="bg-red-500/10 border border-red-500/30 text-red-400 px-4 py-3 rounded-lg text-sm">
                  {error}
                </div>
              )}

              {success && (
                <div className="bg-green-500/10 border border-green-500/30 text-green-400 px-4 py-3 rounded-lg text-sm">
                  Transaction created successfully!
                </div>
              )}

              <div className="flex gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
                  disabled={loading}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
                  disabled={loading}
                >
                  {loading ? 'Creating...' : 'Create Transaction'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
