import { useState, useEffect } from 'react';
import { Search, RefreshCw, CreditCard, Upload, ChevronLeft, ChevronRight, Calendar, Filter, X } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface Transaction {
  transaction_id: string;
  description: string;
  amount: number;
  transaction_type: string;
  status: string;
  merchant: string | null;
  created_at: string;
  processed_at: string | null;
}

interface CardTransactionsTableProps {
  cardId: string;
  cardNumber: string;
}

export default function CardTransactionsTable({ cardId, cardNumber }: CardTransactionsTableProps) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredTransactions, setFilteredTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string | null>(null);
  const [typeFilter, setTypeFilter] = useState<string | null>(null);
  const [sideFilter, setSideFilter] = useState<'debit' | 'credit' | null>(null);
  const [pageSize, setPageSize] = useState(10);
  const [currentPage, setCurrentPage] = useState(1);
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    loadTransactions();
  }, [cardId]);

  useEffect(() => {
    applyFilters();
  }, [transactions, searchQuery, statusFilter, typeFilter, sideFilter]);

  const loadTransactions = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('shark_card_transactions')
        .select('*')
        .eq('card_id', cardId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setTransactions(data || []);
    } catch (error) {
      console.error('Error loading transactions:', error);
    } finally {
      setLoading(false);
    }
  };

  const applyFilters = () => {
    let filtered = [...transactions];

    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(t =>
        t.description.toLowerCase().includes(query) ||
        (t.merchant && t.merchant.toLowerCase().includes(query))
      );
    }

    if (statusFilter) {
      filtered = filtered.filter(t => t.status === statusFilter);
    }

    if (typeFilter) {
      filtered = filtered.filter(t => t.transaction_type === typeFilter);
    }

    if (sideFilter) {
      if (sideFilter === 'debit') {
        filtered = filtered.filter(t => t.amount < 0);
      } else {
        filtered = filtered.filter(t => t.amount > 0);
      }
    }

    setFilteredTransactions(filtered);
    setCurrentPage(1);
  };

  const clearFilters = () => {
    setSearchQuery('');
    setStatusFilter(null);
    setTypeFilter(null);
    setSideFilter(null);
  };

  const hasActiveFilters = searchQuery || statusFilter || typeFilter || sideFilter;

  const totalPages = Math.ceil(filteredTransactions.length / pageSize);
  const startIndex = (currentPage - 1) * pageSize;
  const paginatedTransactions = filteredTransactions.slice(startIndex, startIndex + pageSize);

  const formatMaskedCard = () => {
    const last4 = cardNumber.slice(-4);
    return `4040 38** **** ${last4}`;
  };

  const exportTransactions = () => {
    const csvContent = [
      ['Date', 'Description', 'Merchant', 'Type', 'Status', 'Amount'].join(','),
      ...filteredTransactions.map(t => [
        new Date(t.created_at).toISOString(),
        `"${t.description}"`,
        `"${t.merchant || ''}"`,
        t.transaction_type,
        t.status,
        t.amount
      ].join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `card-transactions-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  };

  return (
    <div className="bg-[#1a1d24] border border-gray-800 rounded-xl overflow-hidden">
      <div className="p-6 border-b border-gray-800">
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-xl font-bold text-white">Transactions</h3>
          <button
            onClick={exportTransactions}
            className="flex items-center gap-2 px-4 py-2 bg-[#0d0f12] border border-gray-700 hover:border-gray-600 rounded-lg text-gray-300 hover:text-white transition-all"
          >
            <Upload className="w-4 h-4" />
            Export
          </button>
        </div>
        <p className="text-gray-400 text-sm">Keep track of your latest cards transactions</p>
      </div>

      <div className="p-4 border-b border-gray-800 space-y-4">
        <div className="flex items-center gap-3">
          <div className="flex-1 relative">
            <Search className="w-4 h-4 text-gray-500 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search for transactions"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 bg-[#0d0f12] border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b]/50"
            />
          </div>
          <button
            onClick={loadTransactions}
            className="p-2.5 bg-[#0d0f12] border border-gray-700 hover:border-gray-600 rounded-lg text-gray-400 hover:text-white transition-all"
          >
            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>

        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2 flex-wrap">
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-sm transition-all ${
                showFilters ? 'bg-[#f0b90b]/10 border-[#f0b90b]/30 text-[#f0b90b]' : 'border-gray-700 text-gray-400 hover:border-gray-600'
              }`}
            >
              <Calendar className="w-3.5 h-3.5" />
              Date
            </button>

            <button
              onClick={() => setStatusFilter(statusFilter ? null : 'approved')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-sm transition-all ${
                statusFilter ? 'bg-[#f0b90b]/10 border-[#f0b90b]/30 text-[#f0b90b]' : 'border-gray-700 text-gray-400 hover:border-gray-600'
              }`}
            >
              <Filter className="w-3.5 h-3.5" />
              Status
            </button>

            <button
              onClick={() => setSideFilter(sideFilter ? null : 'debit')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-sm transition-all ${
                sideFilter ? 'bg-[#f0b90b]/10 border-[#f0b90b]/30 text-[#f0b90b]' : 'border-gray-700 text-gray-400 hover:border-gray-600'
              }`}
            >
              <Filter className="w-3.5 h-3.5" />
              Side
            </button>

            <button
              onClick={() => setTypeFilter(typeFilter ? null : 'purchase')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-sm transition-all ${
                typeFilter ? 'bg-[#f0b90b]/10 border-[#f0b90b]/30 text-[#f0b90b]' : 'border-gray-700 text-gray-400 hover:border-gray-600'
              }`}
            >
              <Filter className="w-3.5 h-3.5" />
              Deposit/Withdraw
            </button>
          </div>

          {hasActiveFilters && (
            <button
              onClick={clearFilters}
              className="text-sm text-[#f0b90b] hover:text-[#f8d12f] transition-colors"
            >
              Clear filters
            </button>
          )}
        </div>

        {showFilters && (
          <div className="flex flex-wrap gap-2 pt-2">
            <select
              value={statusFilter || ''}
              onChange={(e) => setStatusFilter(e.target.value || null)}
              className="px-3 py-1.5 bg-[#0d0f12] border border-gray-700 rounded-lg text-sm text-white focus:outline-none"
            >
              <option value="">All Statuses</option>
              <option value="approved">Approved</option>
              <option value="pending">Pending</option>
              <option value="declined">Declined</option>
            </select>

            <select
              value={typeFilter || ''}
              onChange={(e) => setTypeFilter(e.target.value || null)}
              className="px-3 py-1.5 bg-[#0d0f12] border border-gray-700 rounded-lg text-sm text-white focus:outline-none"
            >
              <option value="">All Types</option>
              <option value="purchase">Purchase</option>
              <option value="payment">Payment</option>
              <option value="refund">Refund</option>
              <option value="fee">Fee</option>
              <option value="cashback">Cashback</option>
              <option value="adjustment">Adjustment</option>
            </select>

            <select
              value={sideFilter || ''}
              onChange={(e) => setSideFilter(e.target.value as any || null)}
              className="px-3 py-1.5 bg-[#0d0f12] border border-gray-700 rounded-lg text-sm text-white focus:outline-none"
            >
              <option value="">All Transactions</option>
              <option value="debit">Debits Only</option>
              <option value="credit">Credits Only</option>
            </select>
          </div>
        )}
      </div>

      <div className="overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b border-gray-800">
              <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                Date & Description
              </th>
              <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                Payment Method
              </th>
              <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                Type
              </th>
              <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="text-right px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                Amount
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-800">
            {loading ? (
              <tr>
                <td colSpan={5} className="px-6 py-12 text-center text-gray-400">
                  <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2" />
                  Loading transactions...
                </td>
              </tr>
            ) : paginatedTransactions.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-6 py-12 text-center text-gray-400">
                  {hasActiveFilters ? 'No transactions match your filters' : 'No transactions yet'}
                </td>
              </tr>
            ) : (
              paginatedTransactions.map((transaction) => {
                const isNegative = transaction.amount < 0;
                const isDeclined = transaction.status === 'declined';

                return (
                  <tr key={transaction.transaction_id} className="hover:bg-[#0d0f12]/50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-gray-800 rounded-lg flex items-center justify-center flex-shrink-0">
                          <CreditCard className="w-5 h-5 text-gray-400" />
                        </div>
                        <div>
                          <div className="font-semibold text-white truncate max-w-[200px]">
                            {transaction.description}
                          </div>
                          <div className="text-xs text-[#f0b90b]">
                            {new Date(transaction.created_at).toLocaleDateString('en-US', {
                              day: 'numeric',
                              month: 'short',
                              hour: '2-digit',
                              minute: '2-digit'
                            })}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <div className="bg-[#1a1f71] text-white text-[10px] font-bold px-2 py-0.5 rounded">
                          VISA
                        </div>
                        <div>
                          <div className="text-sm text-white flex items-center gap-1">
                            New Card
                            <svg className="w-3 h-3 text-gray-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                              <path d="M7 17L17 7M17 7H7M17 7V17" />
                            </svg>
                          </div>
                          <div className="text-xs text-gray-500">{formatMaskedCard()}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className="inline-flex px-2.5 py-1 rounded border border-gray-700 text-xs text-gray-300 capitalize">
                        {transaction.transaction_type === 'purchase' ? 'Card' : transaction.transaction_type}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded text-xs ${
                        transaction.status === 'approved' ? 'bg-green-500/10 text-green-400 border border-green-500/30' :
                        transaction.status === 'declined' ? 'bg-red-500/10 text-red-400 border border-red-500/30' :
                        'bg-yellow-500/10 text-yellow-400 border border-yellow-500/30'
                      }`}>
                        <span className={`w-1.5 h-1.5 rounded-full ${
                          transaction.status === 'approved' ? 'bg-green-400' :
                          transaction.status === 'declined' ? 'bg-red-400' : 'bg-yellow-400'
                        }`}></span>
                        {transaction.status.charAt(0).toUpperCase() + transaction.status.slice(1)}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <span className={`text-base font-semibold ${
                          isDeclined ? 'text-gray-500' :
                          isNegative ? 'text-red-400' : 'text-green-400'
                        }`}>
                          {isNegative ? '-' : '+'}${Math.abs(transaction.amount).toFixed(2)} USD
                        </span>
                        <svg
                          className={`w-4 h-4 ${isNegative ? 'text-red-400 rotate-180' : 'text-green-400'}`}
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="2"
                        >
                          <path d="M12 19V5M5 12l7-7 7 7" />
                        </svg>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {filteredTransactions.length > 0 && (
        <div className="px-6 py-4 border-t border-gray-800 flex items-center justify-between">
          <div className="flex items-center gap-2">
            {[10, 25, 50].map((size) => (
              <button
                key={size}
                onClick={() => {
                  setPageSize(size);
                  setCurrentPage(1);
                }}
                className={`px-3 py-1 rounded border text-sm transition-all ${
                  pageSize === size
                    ? 'bg-[#f0b90b]/10 border-[#f0b90b]/30 text-[#f0b90b]'
                    : 'border-gray-700 text-gray-400 hover:border-gray-600'
                }`}
              >
                {size}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
              disabled={currentPage === 1}
              className="p-1.5 rounded border border-gray-700 text-gray-400 hover:border-gray-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <span className="text-sm text-gray-400">
              {currentPage}/{totalPages || 1}
            </span>
            <button
              onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
              disabled={currentPage >= totalPages}
              className="p-1.5 rounded border border-gray-700 text-gray-400 hover:border-gray-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}