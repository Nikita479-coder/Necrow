import { useState, useEffect } from 'react';
import { ArrowUpRight, ArrowDownLeft, RefreshCw, TrendingUp, TrendingDown } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Props {
  userId: string;
}

export default function AdminUserTransactions({ userId }: Props) {
  const [transactions, setTransactions] = useState<any[]>([]);
  const [filter, setFilter] = useState<string>('all');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadTransactions();
  }, [userId, filter]);

  const loadTransactions = async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('transactions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(100);

      if (filter !== 'all') {
        query = query.eq('transaction_type', filter);
      }

      const { data } = await query;
      setTransactions(data || []);
    } catch (error) {
      console.error('Error loading transactions:', error);
    } finally {
      setLoading(false);
    }
  };

  const getTransactionIcon = (type: string) => {
    switch (type) {
      case 'deposit':
        return <ArrowDownLeft className="w-4 h-4 text-green-400" />;
      case 'withdraw':
      case 'withdrawal':
        return <ArrowUpRight className="w-4 h-4 text-red-400" />;
      case 'transfer':
        return <RefreshCw className="w-4 h-4 text-blue-400" />;
      case 'swap':
        return <RefreshCw className="w-4 h-4 text-purple-400" />;
      case 'stake':
        return <TrendingUp className="w-4 h-4 text-green-400" />;
      case 'unstake':
        return <TrendingDown className="w-4 h-4 text-yellow-400" />;
      case 'trade':
      case 'futures_trade':
        return <TrendingUp className="w-4 h-4 text-purple-400" />;
      case 'admin_credit':
        return <ArrowDownLeft className="w-4 h-4 text-[#f0b90b]" />;
      case 'admin_debit':
        return <ArrowUpRight className="w-4 h-4 text-orange-400" />;
      default:
        return <RefreshCw className="w-4 h-4 text-gray-400" />;
    }
  };

  const getTransactionColor = (type: string) => {
    switch (type) {
      case 'deposit':
        return 'text-green-400';
      case 'withdraw':
      case 'withdrawal':
        return 'text-red-400';
      case 'transfer':
        return 'text-blue-400';
      case 'swap':
        return 'text-purple-400';
      case 'stake':
        return 'text-green-400';
      case 'unstake':
        return 'text-yellow-400';
      case 'trade':
      case 'futures_trade':
        return 'text-purple-400';
      case 'admin_credit':
        return 'text-[#f0b90b]';
      case 'admin_debit':
        return 'text-orange-400';
      default:
        return 'text-gray-400';
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'completed':
      case 'success':
        return 'bg-green-500/20 text-green-400 border-green-500/30';
      case 'pending':
        return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30';
      case 'failed':
      case 'rejected':
        return 'bg-red-500/20 text-red-400 border-red-500/30';
      default:
        return 'bg-gray-500/20 text-gray-400 border-gray-500/30';
    }
  };

  const getTransactionDescription = (tx: any) => {
    // Prioritize the details field for custom descriptions
    if (tx.details) {
      return tx.details;
    }

    const type = tx.transaction_type;

    switch (type) {
      case 'transfer':
        return 'Wallet transfer';
      case 'swap':
        return `Swapped to ${tx.currency}`;
      case 'stake':
        return `Staked ${tx.currency}`;
      case 'unstake':
        return `Unstaked ${tx.currency}`;
      case 'deposit':
        if (tx.network) return `Deposit via ${tx.network}`;
        return 'Deposit';
      case 'withdraw':
      case 'withdrawal':
        if (tx.network) return `Withdrawal via ${tx.network}`;
        if (tx.address) return `Withdrawal to ${tx.address.substring(0, 10)}...`;
        return 'Withdrawal';
      case 'trade':
      case 'futures_trade':
        return 'Trading fee';
      case 'reward':
        return 'Reward earned';
      case 'referral':
        return 'Referral commission';
      case 'admin_credit':
        return 'Admin credit';
      case 'admin_debit':
        return 'Admin debit';
      default:
        return type || 'Transaction';
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4">
        <h2 className="text-xl font-bold text-white">Transaction History</h2>
        <div className="flex flex-wrap gap-2">
          {['all', 'deposit', 'withdraw', 'transfer', 'swap', 'stake', 'unstake', 'trade'].map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                filter === f
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-[#1a1d24] text-gray-400 hover:bg-[#2a2d34]'
              }`}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {transactions.length === 0 ? (
        <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
          <p className="text-gray-400">
            {filter === 'all' ? 'No transactions found' : `No ${filter} transactions found`}
          </p>
        </div>
      ) : (
        <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-x-auto">
          <table className="w-full">
            <thead className="border-b border-gray-800">
              <tr>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Date</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Type</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Currency</th>
                <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Amount</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Details</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Admin Notes</th>
                <th className="text-center py-3 px-4 text-sm font-medium text-gray-400">Status</th>
              </tr>
            </thead>
            <tbody>
              {transactions.map((tx) => (
                <tr key={tx.id} className="border-b border-gray-800/50 hover:bg-[#1a1d24] transition-colors">
                  <td className="py-3 px-4 text-sm text-gray-400">
                    {new Date(tx.created_at).toLocaleString()}
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      {getTransactionIcon(tx.transaction_type)}
                      <span className={`text-sm font-medium ${getTransactionColor(tx.transaction_type)}`}>
                        {tx.transaction_type}
                      </span>
                    </div>
                  </td>
                  <td className="py-3 px-4 text-white font-medium">{tx.currency || 'N/A'}</td>
                  <td className={`py-3 px-4 text-right font-bold ${
                    tx.transaction_type === 'deposit' ? 'text-green-400' :
                    tx.transaction_type === 'withdraw' || tx.transaction_type === 'withdrawal' ? 'text-red-400' :
                    'text-white'
                  }`}>
                    {tx.transaction_type === 'deposit' ? '+' : tx.transaction_type === 'withdraw' || tx.transaction_type === 'withdrawal' ? '-' : ''}
                    {parseFloat(tx.amount || '0') < 1
                      ? parseFloat(tx.amount || '0').toFixed(8)
                      : Math.abs(parseFloat(tx.amount || '0')).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 8 })
                    }
                  </td>
                  <td className="py-3 px-4 text-sm text-gray-400">
                    {getTransactionDescription(tx)}
                    {tx.fee && parseFloat(tx.fee) > 0 && (
                      <span className="ml-2 text-xs text-gray-500">
                        (Fee: {parseFloat(tx.fee).toFixed(8)} {tx.currency})
                      </span>
                    )}
                  </td>
                  <td className="py-3 px-4 text-sm">
                    {tx.admin_notes ? (
                      <span className="text-orange-400 italic">{tx.admin_notes}</span>
                    ) : (
                      <span className="text-gray-600">-</span>
                    )}
                  </td>
                  <td className="py-3 px-4 text-center">
                    <span className={`inline-flex items-center px-2 py-1 rounded-lg border text-xs font-medium ${getStatusBadge(tx.status)}`}>
                      {tx.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
