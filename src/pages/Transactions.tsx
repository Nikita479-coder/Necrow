import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { ArrowUpRight, ArrowDownRight, TrendingUp, Search, Filter, Calendar, Download } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface Transaction {
  id: string;
  transaction_type: string;
  currency: string;
  amount: string;
  status: string;
  created_at: string;
  tx_hash?: string;
  fee?: string;
  address?: string;
  details?: string;
}

function Transactions() {
  const { user } = useAuth();
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all');
  const [filterCurrency, setFilterCurrency] = useState('all');
  const [dateRange, setDateRange] = useState('all');

  useEffect(() => {
    if (user) {
      loadTransactions();
    }
  }, [user]);

  const loadTransactions = async () => {
    if (!user) return;

    try {
      setLoading(true);
      let query = supabase
        .from('transactions')
        .select('id, transaction_type, currency, amount, status, created_at, tx_hash, address, fee, details, network')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      const { data, error } = await query;

      if (error) throw error;

      if (data) {
        setTransactions(data);
      }
    } catch (error) {
      console.error('Error loading transactions:', error);
    } finally {
      setLoading(false);
    }
  };

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

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatDetails = (details: string | undefined, transactionType: string): string | null => {
    if (!details) return null;

    try {
      const parsed = JSON.parse(details);

      if (parsed.source === 'exclusive_affiliate') {
        return 'Affiliate earnings withdrawal';
      }
      if (parsed.wallet_type === 'main' && parsed.normalized_currency) {
        return `Crypto deposit - ${parsed.normalized_currency}`;
      }
      if (parsed.pay_amount && parsed.normalized_currency) {
        return `Deposit of ${parsed.pay_amount} ${parsed.normalized_currency}`;
      }
      if (parsed.destination === 'main_wallet') {
        return 'Transfer to Main Wallet';
      }
      if (parsed.destination === 'futures_wallet') {
        return 'Transfer to Futures Wallet';
      }
      if (parsed.destination === 'copy_wallet') {
        return 'Transfer to Copy Trading Wallet';
      }
      if (parsed.from_wallet && parsed.to_wallet) {
        const fromName = parsed.from_wallet === 'main' ? 'Main' :
                        parsed.from_wallet === 'futures' ? 'Futures' :
                        parsed.from_wallet === 'copy' ? 'Copy Trading' : parsed.from_wallet;
        const toName = parsed.to_wallet === 'main' ? 'Main' :
                      parsed.to_wallet === 'futures' ? 'Futures' :
                      parsed.to_wallet === 'copy' ? 'Copy Trading' : parsed.to_wallet;
        return `Transfer: ${fromName} to ${toName}`;
      }
      if (parsed.trader_name) {
        return `Copy trading with ${parsed.trader_name}`;
      }
      if (parsed.position_id || parsed.symbol) {
        const symbol = parsed.symbol || '';
        const side = parsed.side ? (parsed.side === 'long' ? 'Long' : 'Short') : '';
        return symbol && side ? `${symbol} ${side} position` : symbol || null;
      }
      if (parsed.bonus_type || parsed.bonus_name) {
        return parsed.bonus_name || 'Bonus reward';
      }
      if (parsed.staking_pool || parsed.pool_name) {
        return `Staking: ${parsed.pool_name || parsed.staking_pool}`;
      }
      if (parsed.reason) {
        return parsed.reason;
      }
      if (parsed.message) {
        return parsed.message;
      }

      return null;
    } catch {
      if (details.startsWith('{') || details.startsWith('[')) {
        return null;
      }
      return details;
    }
  };

  const currencies = ['all', ...new Set(transactions.map(tx => tx.currency))];

  const filteredTransactions = transactions.filter(tx => {
    const matchesSearch = tx.currency.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         tx.transaction_type.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         tx.amount.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesType = filterType === 'all' || tx.transaction_type === filterType;
    const matchesStatus = filterStatus === 'all' || tx.status === filterStatus;
    const matchesCurrency = filterCurrency === 'all' || tx.currency === filterCurrency;

    let matchesDate = true;
    if (dateRange !== 'all') {
      const txDate = new Date(tx.created_at);
      const now = new Date();
      const daysDiff = Math.floor((now.getTime() - txDate.getTime()) / (1000 * 60 * 60 * 24));

      if (dateRange === '7d') matchesDate = daysDiff <= 7;
      else if (dateRange === '30d') matchesDate = daysDiff <= 30;
      else if (dateRange === '90d') matchesDate = daysDiff <= 90;
    }

    return matchesSearch && matchesType && matchesStatus && matchesCurrency && matchesDate;
  });

  const totalAmount = filteredTransactions.reduce((sum, tx) => {
    const amount = parseFloat(tx.amount);
    return sum + (tx.transaction_type === 'deposit' || tx.transaction_type === 'transfer' ? amount : 0);
  }, 0);

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 py-6">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">Transaction History</h1>
          <p className="text-gray-400">View and filter all your transactions</p>
        </div>

        <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6 mb-6">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                placeholder="Search transactions..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-[#2b3139] border border-gray-700 rounded-lg pl-10 pr-4 py-2.5 text-white placeholder-gray-500 focus:outline-none focus:border-[#f0b90b]"
              />
            </div>

            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value)}
              className="bg-[#2b3139] border border-gray-700 rounded-lg px-4 py-2.5 text-white focus:outline-none focus:border-[#f0b90b]"
            >
              <option value="all">All Types</option>
              <option value="deposit">Deposit</option>
              <option value="withdrawal">Withdrawal</option>
              <option value="futures_open">Futures Open</option>
              <option value="futures_close">Futures Close</option>
              <option value="transfer">Transfer</option>
              <option value="reward">Reward</option>
              <option value="fee_rebate">Fee Rebate</option>
              <option value="referral_rebate">Referral Rebate</option>
              <option value="referral_commission">Referral Commission</option>
              <option value="admin_credit">Account Credit</option>
              <option value="admin_debit">Balance Adjustment</option>
              <option value="staking">Staking</option>
              <option value="unstaking">Unstaking</option>
            </select>

            <select
              value={filterCurrency}
              onChange={(e) => setFilterCurrency(e.target.value)}
              className="bg-[#2b3139] border border-gray-700 rounded-lg px-4 py-2.5 text-white focus:outline-none focus:border-[#f0b90b]"
            >
              <option value="all">All Currencies</option>
              {currencies.filter(c => c !== 'all').map(currency => (
                <option key={currency} value={currency}>{currency}</option>
              ))}
            </select>

            <select
              value={dateRange}
              onChange={(e) => setDateRange(e.target.value)}
              className="bg-[#2b3139] border border-gray-700 rounded-lg px-4 py-2.5 text-white focus:outline-none focus:border-[#f0b90b]"
            >
              <option value="all">All Time</option>
              <option value="7d">Last 7 Days</option>
              <option value="30d">Last 30 Days</option>
              <option value="90d">Last 90 Days</option>
            </select>
          </div>

          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-4">
              <button
                onClick={() => setFilterStatus('all')}
                className={`px-4 py-2 rounded-lg font-medium transition-all ${
                  filterStatus === 'all'
                    ? 'bg-[#f0b90b] text-black'
                    : 'bg-[#2b3139] text-gray-400 hover:text-white'
                }`}
              >
                All
              </button>
              <button
                onClick={() => setFilterStatus('completed')}
                className={`px-4 py-2 rounded-lg font-medium transition-all ${
                  filterStatus === 'completed'
                    ? 'bg-emerald-500 text-white'
                    : 'bg-[#2b3139] text-gray-400 hover:text-white'
                }`}
              >
                Completed
              </button>
              <button
                onClick={() => setFilterStatus('pending')}
                className={`px-4 py-2 rounded-lg font-medium transition-all ${
                  filterStatus === 'pending'
                    ? 'bg-yellow-500 text-black'
                    : 'bg-[#2b3139] text-gray-400 hover:text-white'
                }`}
              >
                Pending
              </button>
              <button
                onClick={() => setFilterStatus('failed')}
                className={`px-4 py-2 rounded-lg font-medium transition-all ${
                  filterStatus === 'failed'
                    ? 'bg-red-500 text-white'
                    : 'bg-[#2b3139] text-gray-400 hover:text-white'
                }`}
              >
                Failed
              </button>
            </div>

            <div className="flex items-center gap-3">
              <div className="text-sm text-gray-400">
                Total: <span className="text-white font-semibold">{filteredTransactions.length}</span> transactions
              </div>
              <button className="flex items-center gap-2 px-4 py-2 bg-[#2b3139] hover:bg-[#3b4149] text-white rounded-lg transition-all">
                <Download className="w-4 h-4" />
                Export
              </button>
            </div>
          </div>
        </div>

        <div className="bg-[#181a20] border border-gray-800 rounded-2xl p-6">
          {loading ? (
            <div className="text-center py-12 text-gray-400">
              <div className="animate-spin w-8 h-8 border-2 border-[#f0b90b] border-t-transparent rounded-full mx-auto mb-4"></div>
              Loading transactions...
            </div>
          ) : filteredTransactions.length === 0 ? (
            <div className="text-center py-12 text-gray-400">
              <TrendingUp className="w-16 h-16 mx-auto mb-4 text-gray-600" />
              <p className="text-lg">No transactions found</p>
              <p className="text-sm mt-2">Try adjusting your filters</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-800">
                    <th className="text-left py-4 px-4 text-gray-400 font-medium text-sm">Type</th>
                    <th className="text-left py-4 px-4 text-gray-400 font-medium text-sm">Currency</th>
                    <th className="text-right py-4 px-4 text-gray-400 font-medium text-sm">Amount</th>
                    <th className="text-left py-4 px-4 text-gray-400 font-medium text-sm">Status</th>
                    <th className="text-left py-4 px-4 text-gray-400 font-medium text-sm">Description</th>
                    <th className="text-left py-4 px-4 text-gray-400 font-medium text-sm">Date</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTransactions.map((tx) => {
                    const isPositive = ['deposit', 'reward', 'fee_rebate', 'admin_credit', 'referral_rebate', 'referral_commission', 'unstaking', 'futures_close'].includes(tx.transaction_type);
                    const amount = parseFloat(tx.amount);

                    return (
                      <tr key={tx.id} className="border-b border-gray-800 hover:bg-[#0b0e11] transition-colors">
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-3">
                            <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                              isPositive
                                ? 'bg-emerald-500/20'
                                : 'bg-red-500/20'
                            }`}>
                              {isPositive ? (
                                <ArrowDownRight className="w-5 h-5 text-emerald-400" />
                              ) : (
                                <ArrowUpRight className="w-5 h-5 text-red-400" />
                              )}
                            </div>
                            <div>
                              <span className="font-medium text-white capitalize block">
                                {tx.transaction_type === 'fee_rebate' ? 'Fee Rebate' :
                                 tx.transaction_type === 'admin_credit' ? 'Account Credit' :
                                 tx.transaction_type === 'admin_debit' ? 'Balance Adjustment' :
                                 tx.transaction_type === 'futures_open' ? 'Futures Open' :
                                 tx.transaction_type === 'futures_close' ? 'Futures Close' :
                                 tx.transaction_type === 'referral_rebate' ? 'Referral Rebate' :
                                 tx.transaction_type === 'referral_commission' ? 'Referral Commission' :
                                 tx.transaction_type.replace(/_/g, ' ')}
                              </span>
                              {tx.transaction_type === 'reward' && (
                                <span className="text-xs text-gray-400">Rewards Hub</span>
                              )}
                              {tx.transaction_type === 'fee_rebate' && (
                                <span className="text-xs text-gray-400">VIP Benefit</span>
                              )}
                              {(tx.transaction_type === 'referral_rebate' || tx.transaction_type === 'referral_commission') && (
                                <span className="text-xs text-gray-400">Referral Program</span>
                              )}
                              {(tx.transaction_type === 'futures_open' || tx.transaction_type === 'futures_close') && (
                                <span className="text-xs text-gray-400">Futures Trading</span>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="py-4 px-4">
                          <span className="font-semibold text-white">{tx.currency}</span>
                        </td>
                        <td className="py-4 px-4 text-right">
                          <div className={`font-bold text-lg ${
                            isPositive ? 'text-emerald-400' : 'text-red-400'
                          }`}>
                            {isPositive ? '+' : '-'}{amount}
                          </div>
                          <div className="text-gray-400 text-sm">
                            ${(amount * (tx.currency === 'USDT' ? 1 : 50000)).toLocaleString()}
                          </div>
                        </td>
                        <td className="py-4 px-4">
                          <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
                            tx.status === 'completed' ? 'bg-emerald-500/20 text-emerald-400' :
                            tx.status === 'pending' ? 'bg-yellow-500/20 text-yellow-400' :
                            'bg-red-500/20 text-red-400'
                          }`}>
                            {tx.status}
                          </span>
                        </td>
                        <td className="py-4 px-4">
                          <div className="max-w-[300px]">
                            {(() => {
                              const formattedDetails = formatDetails(tx.details, tx.transaction_type);
                              if (formattedDetails) {
                                return <div className="text-white text-sm">{formattedDetails}</div>;
                              } else if (tx.address) {
                                return <div className="text-white text-sm font-mono text-xs truncate">{tx.address}</div>;
                              } else if (tx.tx_hash) {
                                return (
                                  <div className="font-mono text-xs text-gray-400 truncate">
                                    {tx.tx_hash}
                                  </div>
                                );
                              } else {
                                return <span className="text-gray-600 text-xs">-</span>;
                              }
                            })()}
                          </div>
                        </td>
                        <td className="py-4 px-4">
                          <div className="text-white">{formatDate(tx.created_at)}</div>
                          <div className="text-gray-400 text-xs">{formatTimeAgo(tx.created_at)}</div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default Transactions;
